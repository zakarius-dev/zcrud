/// Primitive PURE de sélection de session (Story E9-3, AC8, FR-18, AD-14).
///
/// Applique les filtres d'une [ZStudySessionConfig] à une collection de
/// [ZFlashcard] candidates et retourne la sélection **déterministe**. Pur-Dart,
/// **sans état, sans I/O ni horloge** : aucune notion de `dues`/`ahead`/mélange
/// (état runtime de session = E9-5).
///
/// Sémantique (AC8) — les filtres se composent en **ET** (dossier ∧ tags ∧
/// types) puis le plafond `count` s'applique :
/// - `folderId == null` ⇒ pas de filtre dossier ; sinon ne retient que les
///   cartes dont `folderId == config.folderId` **ou** `subFolderId ==
///   config.folderId` (le dossier cible couvre ses sous-dossiers — rattachement
///   inverse 2 niveaux) ;
/// - `tagIds == null` **ou vide** ⇒ pas de filtre étiquettes ; sinon
///   intersection non vide (`card.tagIds ∩ config.tagIds ≠ ∅`) ;
/// - `types == null` **ou vide** ⇒ pas de filtre type ; sinon appartenance
///   (`config.types.contains(card.type)`) ;
/// - `count == null` ⇒ illimité ; sinon **troncature** à `count` éléments ;
///   `count <= 0` ⇒ sélection **vide**.
///
/// L'**ordre d'entrée est préservé** (déterministe).
library;

import 'z_flashcard.dart';
import 'z_study_session_config.dart';

/// Sélecteur pur de cartes de session (enveloppe une [ZStudySessionConfig]).
///
/// Deux surfaces : [matches] (prédicat sur une carte, filtres seuls, **hors**
/// plafond `count`) et [selectFrom] (sélection complète filtres ∧ `count`).
class ZStudySessionSelector {
  /// Construit un sélecteur pour la [config] donnée.
  const ZStudySessionSelector(this.config);

  /// Config source des filtres.
  final ZStudySessionConfig config;

  /// `true` si [card] satisfait **tous** les filtres (dossier ∧ tags ∧ types).
  ///
  /// N'applique **pas** le plafond `count` (c'est un plafond de collection, non
  /// un prédicat par carte — cf. [selectFrom]).
  bool matches(ZFlashcard card) =>
      _matchesFolder(card) && _matchesTags(card) && _matchesTypes(card);

  /// Retourne la sélection ordonnée : les [candidates] filtrées par [matches]
  /// puis tronquées à `config.count` (illimité si `null`, vide si `<= 0`).
  ///
  /// L'ordre d'entrée est **préservé** ; la fonction est pure et déterministe.
  List<ZFlashcard> selectFrom(Iterable<ZFlashcard> candidates) {
    final count = config.count;
    if (count != null && count <= 0) return const <ZFlashcard>[];
    final filtered = <ZFlashcard>[
      for (final card in candidates)
        if (matches(card)) card,
    ];
    if (count == null || filtered.length <= count) return filtered;
    return filtered.sublist(0, count);
  }

  bool _matchesFolder(ZFlashcard card) {
    final folderId = config.folderId;
    if (folderId == null) return true;
    return card.folderId == folderId || card.subFolderId == folderId;
  }

  bool _matchesTags(ZFlashcard card) {
    final tagIds = config.tagIds;
    if (tagIds == null || tagIds.isEmpty) return true;
    for (final tag in card.tagIds) {
      if (tagIds.contains(tag)) return true;
    }
    return false;
  }

  bool _matchesTypes(ZFlashcard card) {
    final types = config.types;
    if (types == null || types.isEmpty) return true;
    return types.contains(card.type);
  }
}
