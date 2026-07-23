/// Moteur d'exécution des dérivations déclarées (`ZFieldSpec.derivedFrom`) —
/// CR-IFFD-22.
///
/// origine: la CR ne demande pas la *capacité* (elle existait :
/// `fieldListenable(a).addListener → setValue(b)`) mais le fait qu'elle soit
/// **déclarative** et que les deux pièges soient portés par le socle. Toute la
/// valeur est ici, pas dans la syntaxe :
///
/// 1. **Sérialisation des résolutions asynchrones** — un **jeton de génération
///    PAR CHAMP CIBLE** ([_generation]) : deux sélections rapprochées dont les
///    `Future` se résolvent DANS LE DÉSORDRE ne peuvent plus s'écraser ; la
///    résolution périmée est **jetée**, la dernière sélection gagne toujours.
/// 2. **AD-10** — toute fonction hôte est appelée sous `try/catch` : une
///    dérivation qui lève **n'écrit rien** (la cible garde sa valeur
///    précédente) et ne remonte jamais dans la saisie.
/// 3. **AD-2 / SM-1** — abonnement CIBLÉ aux seules tranches sources, écriture
///    CIBLÉE des seules tranches cibles. Aucun `notifyListeners()` global,
///    aucun `setState` d'échelle formulaire : le moteur ne fait que réutiliser
///    les canaux EXISTANTS du `ZFormController`.
/// 4. **Cycles** — signalés (debug) et **coupés** (toujours) par une garde de
///    réentrance ; jamais une exception : un cycle reste exprimable.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/edition/z_derivation.dart';
import '../../domain/edition/z_field_choice.dart';
import '../../domain/edition/z_field_spec.dart';
import '../z_form_controller.dart';

/// Exécute les [ZDerivation] d'un ensemble de [ZFieldSpec] sur un
/// [ZFormController].
///
/// Cycle de vie **possédé par l'appelant** : `ZDerivationEngine(...)` puis
/// [dispose] (fait par `DynamicEdition`). [dispose] retire **tous** les
/// listeners posés — aucun listener fuité (prouvé par test).
class ZDerivationEngine {
  /// Attache le moteur : pose un abonnement CIBLÉ par tranche source et calcule
  /// immédiatement les cibles **non destructives** (`visible`/`options`/
  /// `bounds`).
  ///
  /// La cible `value` n'est **PAS** calculée à l'attache : le formulaire vient
  /// d'être amorcé avec les valeurs persistées, les écraser à l'ouverture
  /// détruirait la donnée chargée. Une dérivation de valeur ne s'exécute donc
  /// qu'au **changement** d'une source.
  ZDerivationEngine({
    required ZFormController controller,
    required List<ZFieldSpec> fields,
  }) : _controller = controller {
    for (final f in fields) {
      final d = f.derivedFrom;
      if (d == null || !d.hasTarget) continue;
      _derived[f.name] = d;
      for (final s in d.sources) {
        final listenable = controller.fieldListenable(s);
        void listener() => _onSourceChanged(f.name);
        listenable.addListener(listener);
        _subscriptions.add(_Subscription(listenable, listener));
      }
    }
    _warnOnCycles(fields);
    for (final target in _derived.keys) {
      _recompute(target, includeValue: false);
    }
  }

  final ZFormController _controller;

  /// `champ cible → dérivation` (uniquement les cibles réellement déclarées).
  final Map<String, ZDerivation> _derived = <String, ZDerivation>{};

  /// Abonnements posés, conservés pour un retrait EXHAUSTIF au [dispose].
  final List<_Subscription> _subscriptions = <_Subscription>[];

  /// **Jeton de génération par champ cible** (piège n°2 de la CR). Incrémenté à
  /// CHAQUE recalcul de la cible ; une résolution asynchrone n'écrit que si son
  /// jeton capturé est encore le jeton courant.
  final Map<String, int> _generation = <String, int>{};

  /// Visibilité dérivée courante (`champ → visible`). Absent ⇒ aucune contrainte
  /// (le champ n'est jamais masqué par le moteur).
  final Map<String, bool> _visible = <String, bool>{};

  /// Canal **structurel** de révision de la visibilité dérivée : incrémenté
  /// UNIQUEMENT quand un `visible` dérivé **change** de valeur. `DynamicEdition`
  /// l'écoute pour recalculer `visibleFields` (canal EXISTANT). Ce n'est jamais
  /// un canal de saisie (aucun tic par frappe si la visibilité ne bouge pas).
  final ValueNotifier<int> _visibilityRevision = ValueNotifier<int>(0);

  /// Chaîne de propagation courante (garde de **réentrance**, décision 3) :
  /// noms des cibles déjà écrites dans l'épisode de propagation en cours. Non
  /// `null` UNIQUEMENT pendant l'écriture dérivée synchrone, le temps que les
  /// listeners de la tranche écrite s'exécutent.
  Set<String>? _propagatingChain;

  /// Cycles détectés à l'attache (chemins NOMMÉS, cf. [zDerivationCycles]).
  /// Exposé pour qu'un hôte puisse les traiter **programmatiquement**, y compris
  /// en release (même idiome que `ZSyncMeta.collidingReservedKeys`).
  List<List<String>> get cycles => _cycles;
  List<List<String>> _cycles = const <List<String>>[];

  /// Révision de la visibilité dérivée (canal structurel — voir
  /// [_visibilityRevision]).
  ValueListenable<int> get visibilityRevision => _visibilityRevision;

  /// `true` si au moins une dérivation déclare la cible `visible`.
  bool get hasDerivedVisibility =>
      _derived.values.any((d) => d.visible != null);

  /// Visibilité dérivée du champ [name] — `true` par défaut (aucune dérivation
  /// `visible`, ou pas encore calculée). Se compose en **ET** avec
  /// `ZFieldSpec.condition` (cf. `ZDerivation`).
  bool isVisible(String name) => _visible[name] ?? true;

  /// Signale les cycles en **debug** sans jamais lever (un cycle reste
  /// exprimable ; la garde de réentrance le coupe à l'exécution).
  void _warnOnCycles(List<ZFieldSpec> fields) {
    _cycles = zDerivationCycles(fields);
    assert(() {
      for (final c in _cycles) {
        // ignore: avoid_print
        print(
          'ZDerivationEngine — ⚠️ CYCLE DE DÉRIVATION : ${c.join(' → ')}. '
          'La propagation sera COUPÉE à la réentrance (chaque champ du cycle '
          "n'est écrit qu'une fois par épisode) : le résultat dépend du champ "
          "par lequel l'épisode démarre. Cassez le cycle si ce n'est pas "
          'intentionnel.',
        );
      }
      return true;
    }());
  }

  /// Réaction à un changement de source pour la cible [target].
  void _onSourceChanged(String target) {
    final chain = _propagatingChain;
    if (chain != null && chain.contains(target)) {
      // Garde de RÉENTRANCE : cette cible a déjà été écrite dans l'épisode de
      // propagation courant ⇒ on coupe, sans exception (release comme debug).
      return;
    }
    _recompute(target, includeValue: true, chain: chain);
  }

  /// Recalcule les cibles déclarées de [target].
  void _recompute(
    String target, {
    required bool includeValue,
    Set<String>? chain,
  }) {
    final d = _derived[target];
    if (d == null) return;
    final gen = (_generation[target] ?? 0) + 1;
    _generation[target] = gen;
    final sources = <String, Object?>{
      for (final s in d.sources) s: _controller.valueOf(s),
    };
    // Chaîne de l'épisode : celle en cours (propagation en cascade) ou une
    // nouvelle (épisode déclenché par une saisie utilisateur), + cette cible.
    final nextChain = <String>{...?chain, target};

    _applyVisible(target, d, sources);
    _applyBounds(target, d, sources, nextChain);
    _applyOptions(target, d, sources, gen, nextChain);
    if (includeValue) _applyValue(target, d, sources, gen, nextChain);
  }

  /// Cible `visible` (SYNCHRONE) → canal structurel EXISTANT `visibleFields`,
  /// via la révision observée par `DynamicEdition`.
  void _applyVisible(
    String target,
    ZDerivation d,
    Map<String, Object?> sources,
  ) {
    final fn = d.visible;
    if (fn == null) return;
    final bool next;
    try {
      next = fn(sources);
    } catch (e) {
      _reportFailure(target, 'visible', e);
      return; // AD-10 : repli = visibilité PRÉCÉDENTE conservée.
    }
    if (_visible[target] == next) return;
    _visible[target] = next;
    _visibilityRevision.value = _visibilityRevision.value + 1;
  }

  /// Cible `bounds` (SYNCHRONE) → tranches compagnes consommées par les
  /// validateurs inter-champs EXISTANTS (`ZValidatorSpec.minKey`/`maxKey`).
  void _applyBounds(
    String target,
    ZDerivation d,
    Map<String, Object?> sources,
    Set<String> chain,
  ) {
    final fn = d.bounds;
    if (fn == null) return;
    final ZFieldBounds? next;
    try {
      next = fn(sources);
    } catch (e) {
      _reportFailure(target, 'bounds', e);
      return; // AD-10 : repli = bornes PRÉCÉDENTES conservées.
    }
    _write(ZDerivationChannels.minKey(target), next?.min, chain);
    _write(ZDerivationChannels.maxKey(target), next?.max, chain);
  }

  /// Cible `options` (ASYNCHRONE, sérialisée par jeton) → tranche compagne
  /// consommée par `ZSelectConfig.choicesFromKey` (canal EXISTANT).
  void _applyOptions(
    String target,
    ZDerivation d,
    Map<String, Object?> sources,
    int gen,
    Set<String> chain,
  ) {
    final fn = d.options;
    if (fn == null) return;
    unawaited(_resolveOptions(fn, target, sources, gen, chain));
  }

  Future<void> _resolveOptions(
    ZDerivationOptionsFn fn,
    String target,
    Map<String, Object?> sources,
    int gen,
    Set<String> chain,
  ) async {
    final List<ZFieldChoice> options;
    try {
      options = await fn(sources);
    } catch (e) {
      _reportFailure(target, 'options', e);
      return; // AD-10 : repli = options PRÉCÉDENTES conservées.
    }
    // Jeton de génération : une résolution PÉRIMÉE (sélection antérieure
    // résolue APRÈS une plus récente) est jetée — la dernière gagne toujours.
    if (_disposed || _generation[target] != gen) return;
    _write(ZDerivationChannels.optionsKey(target), options, chain);
  }

  /// Cible `value` (ASYNCHRONE, sérialisée par jeton) → tranche du champ, sous
  /// la politique d'écrasement DÉCLARÉE.
  void _applyValue(
    String target,
    ZDerivation d,
    Map<String, Object?> sources,
    int gen,
    Set<String> chain,
  ) {
    final fn = d.value;
    if (fn == null) return;
    unawaited(_resolveValue(fn, d.overwrite, target, sources, gen, chain));
  }

  Future<void> _resolveValue(
    ZDerivationValueFn fn,
    ZDerivationOverwrite overwrite,
    String target,
    Map<String, Object?> sources,
    int gen,
    Set<String> chain,
  ) async {
    final Object? value;
    try {
      value = await fn(sources);
    } catch (e) {
      _reportFailure(target, 'value', e);
      return; // AD-10 : repli = valeur PRÉCÉDENTE conservée, saisie intacte.
    }
    // Jeton de génération PAR CHAMP CIBLE (piège n°2 de CR-IFFD-22).
    if (_disposed || _generation[target] != gen) return;
    if (overwrite == ZDerivationOverwrite.ifPristine &&
        _controller.isTouched(target)) {
      return; // saisie manuelle PRÉSERVÉE.
    }
    // CR-IFFD-26 §2 : la fonction peut S'ABSTENIR. Comparé par IDENTITÉ, donc
    // aucune valeur métier ne peut être confondue avec le marqueur.
    if (identical(value, zUnchanged)) return;
    _write(target, value, chain);
  }

  /// Écrit une tranche **au nom du moteur** (`derived: true` ⇒ ne rend pas le
  /// champ *touché*), en publiant la chaîne de propagation pour la garde de
  /// réentrance : les listeners déclenchés par cette écriture s'exécutent
  /// SYNCHRONEMENT pendant l'appel et la lisent.
  void _write(String name, Object? value, Set<String> chain) {
    if (_disposed) return;
    final previous = _propagatingChain;
    _propagatingChain = chain;
    try {
      _controller.setValue(name, value, derived: true);
    } finally {
      _propagatingChain = previous;
    }
  }

  /// Journalise un échec de dérivation en **debug** uniquement (AD-10 : jamais
  /// de throw, jamais de crash en release).
  void _reportFailure(String target, String slot, Object error) {
    assert(() {
      // ignore: avoid_print
      print(
        'ZDerivationEngine — ⚠️ la dérivation «$slot» du champ «$target» a levé '
        '($error). Repli : AUCUNE écriture (la cible garde sa valeur '
        'précédente) ; la saisie en cours est intacte.',
      );
      return true;
    }());
  }

  bool _disposed = false;

  /// Retire **tous** les listeners posés et neutralise les résolutions
  /// asynchrones encore en vol. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      s.listenable.removeListener(s.listener);
    }
    _subscriptions.clear();
    _derived.clear();
    _visibilityRevision.dispose();
  }
}

/// Couple `listenable + listener` conservé pour un retrait exhaustif.
class _Subscription {
  const _Subscription(this.listenable, this.listener);

  final Listenable listenable;
  final VoidCallback listener;
}
