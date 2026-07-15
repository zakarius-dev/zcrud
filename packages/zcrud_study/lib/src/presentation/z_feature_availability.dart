/// `ZFeatureAvailability` — disponibilité de fonctionnalités INJECTABLE (ES-5.4,
/// AD-25/FR-S24).
///
/// Interface DÉCLARATIVE permettant à l'app hôte de décider *quelles*
/// fonctionnalités « study tools » sont disponibles, SANS modifier `zcrud_study`
/// et sans que deux apps aux roadmaps différentes ne se marchent dessus. Elle se
/// COMPOSE avec le vocabulaire AD-4 déjà livré en ES-5.1/5.2/5.3 :
///
/// * [ZContentHubEntry.enabled] / [ZContentHubEntry.onTap] (`onTap == null` ⇒
///   entrée non actionnable) ;
/// * [ZItemAction.onSelected] (`null` ⇒ action ABSENTE du menu, filtrée par
///   `ZItemActionsMenu`) ;
/// * [ZStudyToolsSectionSpec.addAction] (`null` ⇒ action d'ajout ABSENTE).
///
/// ES-5.4 n'introduit **AUCUN nouveau chemin de rendu** : [gate]/[enabledFor]
/// fabriquent le `null`/`bool` que ces slots consomment DÉJÀ (D3, anti-inertie).
///
/// Invariants (AD-1/AD-2/AD-4/AD-15) : le fichier ne rend AUCUNE UI (pure
/// logique) ; aucun gestionnaire d'état ; injection Flutter-native via
/// [ZFeatureAvailabilityScope] (`InheritedWidget` pur) OU par paramètre ;
/// featureKey `String` OPAQUE extensible (jamais un enum fermé couplé aux
/// satellites) ; import maximal `package:flutter/widgets.dart`.
library;

import 'package:flutter/widgets.dart';

/// Interface INJECTABLE de disponibilité de fonctionnalités (D2, AD-25).
///
/// `abstract interface class` : les décisions de disponibilité vivent dans
/// l'IMPLÉMENTATION injectée par l'app, JAMAIS dans une constante compilée du
/// package partagé. La seule primitive à définir est [isAvailable] ; les points
/// de COMPOSITION [enabledFor] et [gate] sont fournis par défaut et relaient la
/// décision vers les slots AD-4 d'ES-5.3.
///
/// [featureKey] est une `String` OPAQUE extensible (AD-4) : l'app définit ses
/// propres clés (constantes app-side) — aucun enum fermé couplé aux satellites
/// (`zcrud_note`/`zcrud_document`/…).
///
/// Les implémentations de RÉFÉRENCE ([ZAllFeaturesAvailable],
/// [ZMapFeatureAvailability]) `extends` cette interface (autorisé dans la même
/// librairie) afin d'hériter des défauts [enabledFor]/[gate] sans les dupliquer.
abstract interface class ZFeatureAvailability {
  /// Constructeur `const` (interface const-compatible).
  const ZFeatureAvailability();

  /// `true` SSI la fonctionnalité identifiée par [featureKey] est disponible.
  ///
  /// Unique primitive à implémenter ; [featureKey] est OPAQUE (AD-4).
  bool isAvailable(String featureKey);

  /// Point de composition ⇒ [ZContentHubEntry.enabled].
  ///
  /// Relaie [isAvailable] : une entrée du hub dont la feature est indisponible
  /// est rendue DÉSACTIVÉE (tuile non actionnable, AD-4), sans nouveau rendu.
  bool enabledFor(String featureKey) => isAvailable(featureKey);

  /// Point de composition ⇒ `onTap`/`addAction`/`onSelected` (ES-5.1/5.3).
  ///
  /// Retourne [action] SSI la feature est disponible, sinon `null`. Le `null`
  /// rend la surface NON actionnable / ABSENTE **par le mécanisme EXISTANT**
  /// ([ZContentHubEntry.onTap] `null`, [ZItemAction.onSelected] `null` filtrée,
  /// [ZStudyToolsSectionSpec.addAction] `null`) — jamais un no-op silencieux
  /// (AD-4).
  VoidCallback? gate(String featureKey, VoidCallback? action) =>
      isAvailable(featureKey) ? action : null;
}

/// Implémentation de référence FAIL-OPEN : toute fonctionnalité est disponible.
///
/// **DÉFAUT du package** (D1) : en l'absence de toute disponibilité injectée, le
/// package partagé ne masque JAMAIS une fonctionnalité qu'une app a réellement
/// câblée — la restriction est un OPT-IN de l'app, jamais une décision du
/// package par ignorance. Préserve la baseline « tout rendu, tout actionnable »
/// d'ES-5.1/5.2/5.3 (SM-SC2, golden inchangé) et la friction d'adoption inverse
/// de FR-S24. Une politique fail-safe locale reste possible via
/// [ZMapFeatureAvailability.availableWhenUnspecified] `= false`.
@immutable
class ZAllFeaturesAvailable extends ZFeatureAvailability {
  /// Construit le défaut fail-open (const-compatible).
  const ZAllFeaturesAvailable();

  @override
  bool isAvailable(String featureKey) => true;
}

/// Implémentation de référence pilotée par une [flags] `Map<String,bool>`.
///
/// `isAvailable(k) => flags[k] ?? availableWhenUnspecified`. const-compatible :
/// une app déclare `const ZMapFeatureAvailability({'note': true, 'exam': false})`.
///
/// [availableWhenUnspecified] = politique LOCALE opt-in pour une clé absente de
/// [flags] : défaut `true` (fail-open, cohérent D1) ; `false` ⇒ politique
/// fail-safe locale (clé inconnue ⇒ masquée), choix explicite de l'app.
@immutable
class ZMapFeatureAvailability extends ZFeatureAvailability {
  /// Construit la disponibilité à partir de [flags] (const-compatible).
  const ZMapFeatureAvailability(
    this.flags, {
    this.availableWhenUnspecified = true,
  });

  /// Table déclarative des disponibilités par featureKey OPAQUE.
  final Map<String, bool> flags;

  /// Disponibilité d'une clé ABSENTE de [flags] (défaut `true` = fail-open).
  final bool availableWhenUnspecified;

  @override
  bool isAvailable(String featureKey) =>
      flags[featureKey] ?? availableWhenUnspecified;

  /// Égalité PROFONDE (SM-SC2) : deux maps de contenu identique sont égales,
  /// afin que [ZFeatureAvailabilityScope.updateShouldNotify] distingue deux
  /// configs par leur CONTENU, pas leur identité. Comparaison inline (aucun
  /// import au-delà de `package:flutter/widgets.dart`, AD-1/AC4).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZMapFeatureAvailability &&
          other.availableWhenUnspecified == availableWhenUnspecified &&
          _flagsEqual(other.flags, flags);

  /// Égalité profonde de deux tables de flags (clés + valeurs).
  static bool _flagsEqual(Map<String, bool> a, Map<String, bool> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null && !b.containsKey(entry.key)) return false;
      if (other != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        availableWhenUnspecified,
        Object.hashAllUnordered(
          flags.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

/// Injection Flutter-native de [ZFeatureAvailability] (AD-2/AD-15).
///
/// `InheritedWidget` PUR — AUCUN gestionnaire d'état, aucun état mutable. Un
/// sous-arbre lit la disponibilité injectée via [of] (repli fail-open D1) ou
/// [maybeOf]. L'injection peut aussi se faire par simple paramètre (l'app passe
/// directement une [ZFeatureAvailability] au code qui construit entrées/actions).
class ZFeatureAvailabilityScope extends InheritedWidget {
  /// Injecte [availability] dans le sous-arbre [child].
  const ZFeatureAvailabilityScope({
    required this.availability,
    required super.child,
    super.key,
  });

  /// Disponibilité injectée, lue par les descendants.
  final ZFeatureAvailability availability;

  /// Disponibilité injectée par le plus proche ancêtre, ou le DÉFAUT fail-open
  /// [ZAllFeaturesAvailable] si aucun ancêtre n'en fournit (D1). Ne lève JAMAIS.
  static ZFeatureAvailability of(BuildContext context) =>
      maybeOf(context) ?? const ZAllFeaturesAvailable();

  /// Disponibilité injectée par le plus proche ancêtre, ou `null` si aucun.
  static ZFeatureAvailability? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ZFeatureAvailabilityScope>()
      ?.availability;

  @override
  bool updateShouldNotify(ZFeatureAvailabilityScope oldWidget) =>
      availability != oldWidget.availability;
}
