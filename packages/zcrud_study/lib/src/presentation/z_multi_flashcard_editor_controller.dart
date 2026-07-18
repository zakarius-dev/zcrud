/// Contrôleur de BROUILLON du multi-éditeur de flashcards (me-2, FR-SU20 —
/// AD-43/AD-2/AD-15/AD-10/AD-39).
///
/// ## Régime DÉCLARÉ, liste de travail EN MÉMOIRE (AD-43 — LE point dur)
///
/// Le régime d'édition est **DÉCLARÉ** ([ZEditingMode.draft]), jamais implicite.
/// La liste de travail vit **entièrement en mémoire** : éditer / ajouter /
/// supprimer / appliquer un champ commun / recevoir un lot généré **mute cette
/// liste et RIEN d'autre**. Aucune persistance n'est possible depuis ce
/// contrôleur : il **n'importe AUCUN** store/repository/adaptateur (la garde de
/// pureté récursive `z_widgets_purity_test.dart` le verrouille — aucune ligne de
/// code ne matche `Repository`/`LocalStore`/`RemoteStore`/`.save(`/`.persist(`).
/// La **seule** frontière de persistance est le callback [commit] injecté — un
/// **unique** franchissement portant l'intégralité de la liste (jamais une
/// écriture par-carte).
///
/// ## Réactivité Flutter-native PURE (AD-2/AD-15, SM-1)
///
/// `ChangeNotifier` pur-Flutter exposant deux tranches `ValueListenable`
/// **disjointes** :
/// * [orderKeys] — tranche **STRUCTURELLE** (clés de travail ordonnées) : émise
///   UNIQUEMENT sur ajout / suppression / lot généré / champ commun. Éditer un
///   champ d'une carte **ne l'émet PAS** — la liste ne se reconstruit donc pas à
///   la frappe (objectif produit n°1).
/// * [isDirty] — canal `bool` dédié (divergence vs snapshot initial) : il ne
///   notifie que le garde `ZDiscardChangesGuard`, jamais les tranches de champ.
///
/// L'identité d'une entrée de travail est une **clé LOCALE stable** ([ZDraftEntry.key],
/// ex. `draft-3`) — **jamais** l'`id` persisté de la carte (qui reste `null` pour
/// une carte éphémère, AD-37). La sélection multiple (`ZListSelectionController`)
/// et les `ValueKey` de widget sont keyées par cette clé de travail : immunisées
/// contre l'absence d'`id`.
library;

import 'package:flutter/foundation.dart';
// `Right`/`Unit`/`unit` sont RÉ-EXPORTÉS par `zcrud_core/domain.dart` (qui
// re-export dartz) : aucune dépendance directe à `dartz` n'est ajoutée à
// `zcrud_study` (arête pubspec unique = `zcrud_ui_kit`).
import 'package:zcrud_core/domain.dart'
    show Left, Right, ServerFailure, Unit, ZFailure, ZResult, unit;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;

/// Régime d'édition **DÉCLARÉ** (AD-43) — jamais implicite (enum, pas un `bool`).
///
/// Un seul membre aujourd'hui ([draft]) : l'énumération rend le régime
/// **explicite et falsifiable** (une surface qui persisterait ne serait pas
/// `draft`), et laisse la porte ouverte à un futur régime (ex. édition directe)
/// **sans** transformer un booléen implicite en état impossible.
enum ZEditingMode {
  /// Brouillon : liste de travail EN MÉMOIRE, rien persisté avant [commit].
  draft,
}

/// Une entrée de la liste de travail : une clé LOCALE stable + la carte courante.
///
/// [key] est l'identité de travail (jamais persistée, jamais l'`id` de la carte) :
/// elle keye la sélection et les `ValueKey` de widget, restant valide même quand
/// `card.id == null` (carte éphémère AD-37).
@immutable
class ZDraftEntry {
  /// Construit une entrée de brouillon.
  const ZDraftEntry({required this.key, required this.card});

  /// Identité de travail LOCALE stable (ex. `draft-3`) — jamais persistée.
  final String key;

  /// Carte courante (immuable ; une édition produit un nouveau [ZFlashcard]).
  final ZFlashcard card;
}

/// Contrôleur de brouillon EN MÉMOIRE (aucun store — AD-43).
class ZMultiFlashcardDraftController extends ChangeNotifier {
  /// Construit le contrôleur autour d'un lot initial (souvent vide, ou un lot
  /// rentré pour édition). Le lot initial devient le **snapshot** de référence
  /// du calcul de divergence ([isDirty]).
  ZMultiFlashcardDraftController({
    List<ZFlashcard> initialCards = const <ZFlashcard>[],
  }) {
    for (final card in initialCards) {
      final key = _nextKey();
      _order.add(key);
      _cards[key] = card;
    }
    _snapshot = _computeWorkingList();
    _orderKeys = ValueNotifier<List<String>>(List<String>.unmodifiable(_order));
    _isDirty = ValueNotifier<bool>(false);
  }

  /// Régime d'édition **DÉCLARÉ** (AD-43) — toujours [ZEditingMode.draft] ici.
  ZEditingMode get mode => ZEditingMode.draft;

  final List<String> _order = <String>[];
  final Map<String, ZFlashcard> _cards = <String, ZFlashcard>{};
  int _keySeq = 0;
  late List<ZFlashcard> _snapshot;
  bool _disposed = false;

  /// Nombre de POSITIONS de la liste de travail qui divergent (par valeur) de leur
  /// contrepartie du [_snapshot] — maintenu **incrémentalement** (FIX-9/SM-1). Vaut
  /// `-1` (sentinelle) quand la longueur diverge (dirty structurel) : dans ce cas
  /// le décompte positionnel n'a pas de sens, le brouillon est dirty d'office.
  int _divergentCount = 0;

  late final ValueNotifier<List<String>> _orderKeys;

  /// Tranche **STRUCTURELLE** : clés de travail ordonnées. Émise UNIQUEMENT sur
  /// changement de composition (ajout / suppression / lot généré / champ commun)
  /// — **jamais** sur une édition de champ (SM-1 : la liste ne se reconstruit
  /// pas à la frappe).
  ValueListenable<List<String>> get orderKeys => _orderKeys;

  late final ValueNotifier<bool> _isDirty;

  /// Canal `bool` de divergence vs snapshot initial (AC3). Ne notifie que le
  /// garde anti-perte de saisie, jamais les tranches de champ.
  ValueListenable<bool> get isDirty => _isDirty;

  /// Nombre de cartes de la liste de travail.
  int get length => _order.length;

  /// Clés de travail ordonnées (copie non modifiable).
  List<String> get keys => List<String>.unmodifiable(_order);

  /// Carte courante pour la clé de travail [key], ou `null` si absente.
  ZFlashcard? cardOf(String key) => _cards[key];

  /// Instantané ORDONNÉ de la liste de travail (copie non modifiable).
  List<ZFlashcard> get workingList =>
      List<ZFlashcard>.unmodifiable(_computeWorkingList());

  String _nextKey() => 'draft-${_keySeq++}';

  List<ZFlashcard> _computeWorkingList() =>
      <ZFlashcard>[for (final k in _order) _cards[k]!];

  /// Ajoute une carte **vierge/éphémère** (`card.id == null` attendu) à la fin de
  /// la liste de travail (AC8). Retourne sa clé de travail. **Aucune écriture** —
  /// mutation en mémoire uniquement.
  String addBlank(ZFlashcard blank) {
    if (_disposed) return '';
    final key = _nextKey();
    _order.add(key);
    _cards[key] = blank;
    _emitStructure();
    return key;
  }

  /// **Ajoute** un lot généré (su-9) à la liste de travail pour revue (AC5). Les
  /// cartes sont **éphémères** (`id == null`) et **jamais persistées** ici. No-op
  /// si le lot est vide (échec/`Right([])` de génération ⇒ liste intacte, AC9).
  void addGenerated(List<ZFlashcard> cards) {
    if (_disposed || cards.isEmpty) return;
    for (final card in cards) {
      final key = _nextKey();
      _order.add(key);
      _cards[key] = card;
    }
    _emitStructure();
  }

  /// Retire en **lot** les entrées de [keys] de la liste de travail (AC8). Le
  /// retrait est purement en mémoire : **aucune cascade AD-39**, **aucune
  /// suppression persistée** (une carte déjà persistée rentrée pour édition n'est
  /// matérialisée qu'au [commit] par l'appelant). Les échouées n'existent pas :
  /// tout retrait mémoire réussit (AD-10 : résultat défini).
  void removeKeys(Iterable<String> keys) {
    if (_disposed) return;
    var changed = false;
    for (final key in keys.toSet()) {
      if (_cards.remove(key) != null) {
        _order.remove(key);
        changed = true;
      }
    }
    if (changed) _emitStructure();
  }

  /// Remplace la carte de la clé [key] par [card] — **édition IN MEMORY** (AC2).
  ///
  /// ⚠️ **SM-1** : ne notifie **PAS** la tranche structurelle [orderKeys] (la
  /// liste ne se reconstruit pas à la frappe) — il ne recalcule que [isDirty].
  /// C'est la voie unique par laquelle l'éditeur de carte pousse ses édits.
  void updateCard(String key, ZFlashcard card) {
    if (_disposed || !_cards.containsKey(key)) return;
    // 🔴 FIX-9/SM-1 — chemin CHAUD (une frappe) : la composition ne change pas
    // (même longueur, même ordre). On ajuste la divergence de façon INCRÉMENTALE
    // (une seule comparaison de valeur : la carte modifiée vs sa contrepartie de
    // snapshot) au lieu de reconstruire toute la liste de travail et de la
    // comparer élément par élément (O(N) par frappe = jank sur brouillon
    // volumineux). L'ordre est figé entre deux changements structurels (qui, eux,
    // recalculent le décompte en entier via `_recomputeDirtyFull`).
    if (_divergentCount >= 0 && _order.length == _snapshot.length) {
      final pos = _order.indexOf(key);
      final snap = _snapshot[pos];
      final wasDivergent = _cards[key] != snap;
      final nowDivergent = card != snap;
      if (wasDivergent != nowDivergent) {
        _divergentCount += nowDivergent ? 1 : -1;
      }
      _cards[key] = card;
      _setDirty(_divergentCount > 0);
      return;
    }
    _cards[key] = card;
    _recomputeDirtyFull();
  }

  /// Seam d'écriture **IN MEMORY** passé à `applyCommonField` (AC7). L'appelant
  /// capture le mapping champ→carte dans [apply] (dérivé de sa déclaration de
  /// champ commun) ; ce seam se contente de **muter la liste de travail**, jamais
  /// un store. Retourne toujours `Right(unit)` (AD-10 : une écriture mémoire ne
  /// peut pas échouer) — les échecs éventuels de validation sont produits **en
  /// amont** par `applyCommonField` (validateurs du `ZFieldSpec`, AD-44).
  Future<ZResult<Unit>> writeRootInMemory(
    String key,
    ZFlashcard Function(ZFlashcard card) apply,
  ) async {
    final current = _cards[key];
    if (current != null) {
      _cards[key] = apply(current);
      _emitStructure();
    }
    return Right<ZFailure, Unit>(unit);
  }

  /// **UNIQUE** franchissement de la frontière de persistance (AD-43/AC4) : remet
  /// l'**intégralité** de la liste de travail à [onCommit] en **une seule**
  /// invocation. En cas de succès (`Right`), le brouillon devient la nouvelle
  /// base (plus *dirty*). En cas d'échec (`Left`), le brouillon est **préservé
  /// tel quel** et reste *dirty* — **aucune perte, aucun vidage optimiste** (AC9).
  Future<ZResult<Unit>> commit(
    Future<ZResult<Unit>> Function(List<ZFlashcard> cards) onCommit,
  ) async {
    final list = _computeWorkingList();
    // 🔴 BUG-2/AD-10 — un `onCommit` injecté qui `throw` NE DOIT PAS traverser la
    // surface : on le capte et on le convertit en `Left(ServerFailure)` (même
    // patron que `ZListSelectionController.batchApply`). Le brouillon reste alors
    // *dirty* intact (aucune mise à jour du snapshot) — aucune perte (AC9).
    ZResult<Unit> result;
    try {
      result = await onCommit(List<ZFlashcard>.unmodifiable(list));
    } catch (error, stack) {
      return Left<ZFailure, Unit>(
        ServerFailure('commit threw: $error\n$stack'),
      );
    }
    if (_disposed) return result;
    return result.map((_) {
      _snapshot = list; // succès ⇒ nouvelle base ⇒ plus dirty.
      _recomputeDirtyFull();
      return unit;
    });
  }

  /// Restaure la liste de travail sur le snapshot de référence et nettoie le
  /// *dirty* (utilisé par `onDiscard` du garde). Purement en mémoire.
  void discardToSnapshot() {
    if (_disposed) return;
    _order.clear();
    _cards.clear();
    _keySeq = 0;
    for (final card in _snapshot) {
      final key = _nextKey();
      _order.add(key);
      _cards[key] = card;
    }
    _emitStructure();
  }

  void _emitStructure() {
    _orderKeys.value = List<String>.unmodifiable(_order);
    _recomputeDirtyFull();
  }

  /// Recalcul COMPLET de la divergence (positions × valeur) — emprunté seulement
  /// sur les chemins FROIDS (changement de composition / commit / abandon), jamais
  /// à la frappe (cf. `updateCard`). Rafraîchit le décompte incrémental
  /// [_divergentCount] ET le canal [isDirty]. Sémantique IDENTIQUE à l'ancien
  /// `_listEquals` (comparaison positionnelle par valeur, robuste aux clés).
  void _recomputeDirtyFull() {
    if (_order.length != _snapshot.length) {
      _divergentCount = -1; // longueur divergente ⇒ dirty structurel.
      _setDirty(true);
      return;
    }
    var count = 0;
    for (var i = 0; i < _order.length; i++) {
      // `==` de ZFlashcard est par valeur.
      if (_cards[_order[i]] != _snapshot[i]) count++;
    }
    _divergentCount = count;
    _setDirty(count > 0);
  }

  void _setDirty(bool dirty) {
    if (_isDirty.value != dirty) _isDirty.value = dirty;
  }

  @override
  void dispose() {
    _disposed = true;
    _orderKeys.dispose();
    _isDirty.dispose();
    super.dispose();
  }
}
