/// Port neutre `ZStudyNoteRef` — référence minimale d'une note d'étude
/// consommable par le socle de présentation sans arête directe vers le
/// paquet de notes (invariant AD-1/AD-4).
///
/// Pendant exact de `ZStudyDocumentRef` : la motivation et le patron (port au
/// kernel, implémenté côté satellite, sur le modèle de `ZSessionCandidate`)
/// sont communs — voir la dartdoc de `z_study_document_ref.dart` pour
/// l'exposé complet.
///
/// ## Surface minimale — chaque membre est justifié par un usage réel
///
/// | Membre | Usage réel qui le motive |
/// |---|---|
/// | [id] | clé de widget stable et identité de réordonnancement |
/// | [title] | seule entrée obligatoire d'une carte de note affichée par défaut |
///
/// ### Membres délibérément absents (et pourquoi)
///
/// - **une date de mise à jour** — le rendu par défaut consomme un sous-titre
///   déjà localisé, jamais un `DateTime` brut à formater : le socle ne
///   formate jamais une date. Une entité de note réelle peut d'ailleurs ne
///   pas exposer de date de mise à jour du tout : cette clé appartient à la
///   métadonnée de synchronisation hors-entité (invariant AD-9), pas à
///   l'entité. L'exiger rendrait le port non implémentable.
/// - **un extrait de contenu** — un extrait textuel existe côté rendu, mais
///   c'est une option dont la source est un texte brut fourni par l'hôte :
///   le socle ne parse aucun rich-text ici. Le contenu d'une note réelle est
///   typiquement une liste d'opérations de rich-text structurées, pas un
///   texte brut ; l'extrait entre donc par un rappel fourni par la voie
///   typée, jamais par le modèle neutre.
/// - **des identifiants de tag** — les balises affichées sont déjà résolues
///   (objets tag complets), fournies par un rappel de la voie typée. Rien à
///   porter dans le modèle neutre.
///
/// ## Rien ne peut lever (invariant AD-10)
///
/// Deux accesseurs, aucune méthode, aucune horloge, aucune validation.
library;

/// Référence neutre d'une note d'étude (implémentée côté satellite — par
/// exemple une entité de note, un adaptateur d'hôte, ou tout autre porteur).
///
/// Pur-Dart, zéro import : le kernel reste ignorant du paquet de notes
/// (invariant AD-1).
abstract interface class ZStudyNoteRef {
  /// Identité opaque, `null` si la note est éphémère (non matérialisée).
  ///
  /// Nullable par contrat du dépôt : l'identité d'une entité est `String?`
  /// dans tout le kernel — un port `String get id` serait non implémentable
  /// par l'entité réelle.
  String? get id;

  /// Titre de la note, déjà résolu par le porteur.
  ///
  /// Non nullable : c'est le contenu principal de la carte, et le rendu par
  /// défaut l'exige. Le repli visible pour une note sans titre est un
  /// libellé localisé, donc l'affaire de l'hôte, jamais du port.
  String get title;
}
