/// Port neutre `ZStudyNoteRef` — référence MINIMALE d'une note d'étude
/// consommable par le socle de présentation **sans arête `zcrud_study →
/// zcrud_note`** (option C, arbitrage owner ; AD-1/AD-4/AD-17).
///
/// Pendant exact de `ZStudyDocumentRef` : la motivation, le patron
/// (`ZSessionCandidate` / `ZApproachingExam` — port au kernel, implémenté côté
/// satellite) et la garde qui gèle l'absence de l'arête sont **communs** ; voir
/// la dartdoc de `z_study_document_ref.dart` pour l'exposé complet.
///
/// ## Surface MINIMALE — chaque membre est justifié par un usage RÉEL
///
/// | Membre | Usage réel qui le motive |
/// |---|---|
/// | [id] | clé de widget STABLE (`ValueKey('zDefaultNoteCard-${…}')`) et identité de réordonnancement (`_zDeriveReorderIds`/`_zGuardReorder`) — patron littéral de `.flashcards`/`.mindmaps`/`.exams` |
/// | [title] | `ZDefaultNoteCard.title`, **seule** entrée `required` de la carte |
///
/// ### Membres délibérément ABSENTS (et pourquoi)
///
/// - **`updatedAt`** — `ZDefaultNoteCard` ne consomme pas un `DateTime` mais un
///   `subtitle` **déjà localisé** (« la méta-information, déjà localisée »). Le
///   socle ne formate jamais une date (FR-26 ; précédent `.exams(dateLabelOf:)`).
///   Et `ZSmartNote` **n'a pas** d'`updatedAt` : AD-19/D2 l'a retiré
///   volontairement (« la clé LWW est hors-entité — `ZSyncMeta.updatedAt` »).
///   L'exiger rendrait le port **non implémentable**.
/// - **`excerpt`** — `ZDefaultNoteCard.excerpt` existe bel et bien, mais c'est
///   une **OPTION** dont la source est un **texte brut fourni par l'hôte** (« le
///   socle ne parse aucun rich-text ici »). `ZSmartNote` ne porte aucun aperçu :
///   son contenu est une liste d'opérations Delta
///   (`List<Map<String, dynamic>> content`). Le `note.plainTextPreview` cité en
///   exemple dans la carte est une **expression d'hôte**, pas un membre du
///   modèle. Il entrera donc par un rappel `excerptOf` de la voie typée —
///   précédent littéral `dateLabelOf`/`semanticLabelOf`/`tagsOf`.
/// - **`tagIds`** — `ZDefaultNoteCard.tags` reçoit des balises **déjà résolues**
///   (`List<ZFlashcardTag>`), fournies par le rappel `tagsOf` de la voie typée
///   (patron `.flashcards`). Rien à porter dans le modèle neutre.
///
/// ## AD-10 — rien ne peut lever
///
/// Deux accesseurs, aucune méthode, aucune horloge, aucune validation.
library;

/// Référence NEUTRE d'une note d'étude (implémentée côté satellite —
/// `ZSmartNote`, un adaptateur d'hôte, ou tout autre porteur).
///
/// Pur-Dart, zéro import : le kernel reste ignorant de `zcrud_note`
/// (AD-1/AD-17).
abstract interface class ZStudyNoteRef {
  /// Identité **opaque**, `null` si la note est éphémère (non matérialisée).
  ///
  /// Nullable **par contrat du dépôt** : `ZEntity.id` est `String?` et
  /// `ZSmartNote.id` l'est aussi. Un port `String get id` serait
  /// **non implémentable** par l'entité réelle.
  String? get id;

  /// Titre de la note, **déjà résolu par le porteur** — alimente
  /// `ZDefaultNoteCard.title`.
  ///
  /// Non nullable : c'est le contenu principal de la carte, et la carte l'exige
  /// (`required this.title`). Le repli visible (« sans titre ») est un libellé
  /// localisé, donc l'affaire de l'hôte (FR-26), jamais du port.
  String get title;
}
