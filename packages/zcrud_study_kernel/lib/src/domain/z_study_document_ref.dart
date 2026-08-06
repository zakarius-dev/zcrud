/// Port neutre `ZStudyDocumentRef` — référence MINIMALE d'un document d'étude
/// consommable par le socle de présentation **sans arête `zcrud_study →
/// zcrud_document`** (option C, arbitrage owner ; AD-1/AD-4/AD-17).
///
/// ## Le problème exact que ce port résout
///
/// `ZStudyToolsSectionSpec` (dans `zcrud_study`) porte des voies TYPÉES
/// `.flashcards(cards:)`, `.mindmaps(maps:)`, `.exams(exams:)` — chacune
/// adossée à une dépendance **déjà déclarée**. Il n'y a **NI `.documents(…)` NI
/// `.notes(…)`**, parce que `zcrud_document`/`zcrud_note` ne sont **pas** des
/// dépendances de `zcrud_study` : les ajouter serait une **arête nouvelle**,
/// interdite (AD-1). Cette absence est **gelée par une garde**
/// (`zcrud_study/test/presentation/cr_iffd48_parity_guard_test.dart`, grep
/// négatif sur le spec **et** sur le `pubspec.yaml`).
///
/// Les cartes par défaut, elles, existent **déjà** et sont **autonomes sur
/// primitives** (`ZDefaultDocumentCard` : `title`, `formatKey`, `formatLabel`…).
/// Ce qui manque n'est donc pas la carte, c'est la **voie typée** — c'est-à-dire
/// un type que le socle puisse nommer sans dépendre du satellite.
///
/// ⇒ Le port est défini **ICI, au kernel**, et sera **implémenté côté
/// satellite**. Précédents EXACTS, reproduits à l'identique :
/// - `ZSessionCandidate` (port au kernel, implémenté par `ZFlashcard` — « évite
///   l'arête retour vers flashcard ») ;
/// - `ZApproachingExam` (« port pur-Dart défini ICI, précédent EXACT
///   `ZSessionCandidate` : port au kernel, implémenté côté satellite »).
///
/// ## Surface MINIMALE — chaque membre est justifié par un usage RÉEL
///
/// Le risque n°1 d'un port est la **sur-spécification** : un port trop large
/// devient un **modèle dupliqué**, exactement ce que l'architecture interdit.
/// La règle appliquée ici : **un membre n'existe que si une carte du socle le
/// consomme ET qu'aucun rappel (callback) de l'hôte ne le fournit déjà**.
///
/// | Membre | Usage réel qui le motive |
/// |---|---|
/// | [id] | clé de widget STABLE (`ValueKey('zDefaultDocumentCard-${…}')`) et identité de réordonnancement (`_zDeriveReorderIds`/`_zGuardReorder`) — patron littéral de `.flashcards`/`.mindmaps`/`.exams` |
/// | [title] | `ZDefaultDocumentCard.title`, **seule** entrée `required` de la carte |
/// | [formatKey] | `ZDefaultDocumentCard.formatKey` — clé **OPAQUE** pilotant glyphe, couleur de format et badge d'extension |
///
/// ### Membres délibérément ABSENTS (et pourquoi)
///
/// - **`updatedAt`** — aucune carte ne consomme un `DateTime` : les deux cartes
///   prennent un `subtitle` **déjà formaté et localisé** par l'hôte, et le socle
///   ne formate JAMAIS une date (FR-26 ; précédent `.exams(dateLabelOf:)`, qui
///   « rend une date déjà formatée et localisée par l'hôte »). Surtout,
///   `ZStudyDocument` **n'a pas** d'`updatedAt` : AD-19/D2 l'a **retiré
///   volontairement** de l'entité (« la clé LWW est hors-entité —
///   `ZSyncMeta.updatedAt` »). L'exiger rendrait le port **non implémentable**,
///   soit l'exact inverse du but.
/// - **`pageCount`** — `ZDefaultDocumentCard` n'a **aucun** créneau de nombre de
///   pages. Le champ existe sur `ZStudyDocument`, mais un port se dimensionne
///   sur ce qui est **consommé**, pas sur ce que le modèle possède : le mettre
///   ici serait le premier pas vers le modèle dupliqué. Une méta-information de
///   ce genre passe par le `subtitle` que l'hôte compose.
/// - **`extension`** (au sens « extension de fichier ») — le nom est **INTERDIT
///   ICI** : `ZStudyDocument.extension` existe déjà et vaut `ZExtension?` (slot
///   d'extensibilité AD-4). Un membre `String? get extension` sur ce port ferait
///   du `ZStudyDocument implements ZStudyDocumentRef` une **erreur de
///   compilation**. La donnée visée est portée par [formatKey], qui est
///   d'ailleurs le nom exact du paramètre de la carte.
///
/// ## AD-4 — [formatKey] est OPAQUE, jamais un enum fermé
///
/// Extension (`'pdf'`), type MIME (`'application/pdf'`, `'image/png'`), ou toute
/// convention de l'hôte : le socle **normalise, ne classifie pas**. Un format
/// nouveau n'exige donc aucune CR (patron `ZSessionCandidate.typeKey` /
/// `ZDailyStudyTask.kind`).
///
/// ## AD-10 — rien ne peut lever
///
/// Le port ne déclare que des accesseurs ; aucune méthode, aucune horloge,
/// aucune validation. Un implémenteur qui n'a pas la donnée rend `null`
/// ([id]/[formatKey]) — jamais une exception.
library;

/// Référence NEUTRE d'un document d'étude (implémentée côté satellite —
/// `ZStudyDocument`, un adaptateur d'hôte, ou tout autre porteur).
///
/// Pur-Dart, zéro import : le kernel reste ignorant de `zcrud_document`
/// (AD-1/AD-17).
abstract interface class ZStudyDocumentRef {
  /// Identité **opaque**, `null` si le document est éphémère (non matérialisé).
  ///
  /// Nullable **par contrat du dépôt** : `ZEntity.id` est `String?` et
  /// `ZStudyDocument.id` l'est aussi. Un port `String get id` serait
  /// **non implémentable** par l'entité réelle (le type de retour d'un
  /// `String?` n'est pas sous-type de `String`).
  String? get id;

  /// Libellé principal affiché, **déjà résolu par le porteur** — alimente
  /// `ZDefaultDocumentCard.title`.
  ///
  /// Non nullable : c'est le contenu principal de la carte, et la carte l'exige
  /// (`required this.title`). Un porteur dont le nom d'affichage est vide rend
  /// `''` — le repli visible (« sans titre ») est un **libellé localisé**, donc
  /// l'affaire de l'hôte (FR-26), jamais du port.
  String get title;

  /// Clé de format **OPAQUE** (`'pdf'`, `'application/pdf'`, `'image/png'`…),
  /// `null` si inconnue — alimente `ZDefaultDocumentCard.formatKey`, qui la
  /// normalise pour résoudre glyphe, couleur et badge d'extension.
  ///
  /// Ce n'est **pas** un enum (AD-4) et ce n'est **pas** un libellé visible : le
  /// texte affiché (« PDF ») reste injecté par l'hôte (`formatLabel`, FR-26).
  String? get formatKey;
}
