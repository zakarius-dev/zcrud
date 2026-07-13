/// Primitive PURE de sélection de session (Story E9-3/ES-1.1, AC6/AC8, FR-18,
/// AD-1/AD-14/AD-17).
///
/// Applique les filtres d'une [ZStudySessionConfig] à une collection de
/// candidats [ZSessionCandidate] (port neutre — flashcards, notes, mindmaps…)
/// et retourne la sélection **déterministe**. Pur-Dart, **sans état, sans I/O ni
/// horloge** : aucune notion de `dues`/`ahead`/mélange (état runtime de
/// session = E9-5). Le passage au port `ZSessionCandidate` (ES-1.1) supprime
/// l'arête retour vers `zcrud_flashcard` et préserve l'acyclicité (AD-1).
///
/// Sémantique (AC8) — les filtres se composent en **ET** (dossier ∧ tags ∧
/// types) puis le plafond `count` s'applique :
/// - `folderId == null` ⇒ pas de filtre dossier ; sinon ne retient que les
///   candidats dont `folderId == config.folderId` **ou** `subFolderId ==
///   config.folderId` (le dossier cible couvre ses sous-dossiers — rattachement
///   inverse 2 niveaux) ;
/// - `tagIds == null` **ou vide** ⇒ pas de filtre étiquettes ; sinon
///   intersection non vide (`candidate.tagIds ∩ config.tagIds ≠ ∅`) ;
/// - `types == null` **ou vide** ⇒ pas de filtre type ; sinon appartenance de la
///   clé opaque (`config.types.contains(candidate.typeKey)`) ;
/// - `count == null` ⇒ illimité ; sinon **troncature** à `count` éléments ;
///   `count <= 0` ⇒ sélection **vide**.
///
/// L'**ordre d'entrée est préservé** (déterministe).
library;

import 'z_session_candidate.dart';
import 'z_study_session_config.dart';

/// Sélecteur pur de candidats de session (enveloppe une [ZStudySessionConfig]).
///
/// Deux surfaces : [matches] (prédicat sur un candidat, filtres seuls, **hors**
/// plafond `count`) et [selectFrom] (sélection complète filtres ∧ `count`).
class ZStudySessionSelector {
  /// Construit un sélecteur pour la [config] donnée.
  const ZStudySessionSelector(this.config);

  /// Config source des filtres.
  final ZStudySessionConfig config;

  /// `true` si [candidate] satisfait **tous** les filtres (dossier ∧ tags ∧
  /// types).
  ///
  /// N'applique **pas** le plafond `count` (c'est un plafond de collection, non
  /// un prédicat par candidat — cf. [selectFrom]).
  bool matches(ZSessionCandidate candidate) =>
      _matchesFolder(candidate) &&
      _matchesTags(candidate) &&
      _matchesTypes(candidate);

  /// Retourne la sélection ordonnée : les [candidates] filtrées par [matches]
  /// puis tronquées à `config.count` (illimité si `null`, vide si `<= 0`).
  ///
  /// Générique sur `T extends ZSessionCandidate` : le type concret d'entrée est
  /// **préservé** en sortie (un satellite récupère ses propres entités, pas des
  /// `ZSessionCandidate` opaques). L'ordre d'entrée est **préservé** ; la
  /// fonction est pure et déterministe.
  List<T> selectFrom<T extends ZSessionCandidate>(Iterable<T> candidates) {
    final count = config.count;
    if (count != null && count <= 0) return const <Never>[];
    final filtered = <T>[
      for (final candidate in candidates)
        if (matches(candidate)) candidate,
    ];
    if (count == null || filtered.length <= count) return filtered;
    return filtered.sublist(0, count);
  }

  bool _matchesFolder(ZSessionCandidate candidate) {
    final folderId = config.folderId;
    if (folderId == null) return true;
    return candidate.folderId == folderId || candidate.subFolderId == folderId;
  }

  bool _matchesTags(ZSessionCandidate candidate) {
    final tagIds = config.tagIds;
    if (tagIds == null || tagIds.isEmpty) return true;
    for (final tag in candidate.tagIds) {
      if (tagIds.contains(tag)) return true;
    }
    return false;
  }

  bool _matchesTypes(ZSessionCandidate candidate) {
    final types = config.types;
    if (types == null || types.isEmpty) return true;
    return types.contains(candidate.typeKey);
  }
}
