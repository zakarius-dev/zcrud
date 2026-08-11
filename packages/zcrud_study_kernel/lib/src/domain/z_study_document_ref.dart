/// Port neutre `ZStudyDocumentRef` — référence minimale d'un document
/// d'étude consommable par le socle de présentation sans arête directe vers
/// le paquet de documents (invariant AD-1/AD-4).
///
/// ## Le problème que ce port résout
///
/// Un socle de présentation d'étude porte des voies typées pour les
/// contenus dont le paquet dépend déjà (flashcards, mindmaps, examens). Il
/// n'a pas de voie typée équivalente pour les documents, parce qu'ajouter
/// une dépendance vers le paquet de documents depuis ce socle serait une
/// arête nouvelle interdite (invariant AD-1). Les cartes par défaut, elles,
/// existent déjà et sont autonomes sur primitives : ce qui manque n'est donc
/// pas la carte, c'est la voie typée — un type que le socle puisse nommer
/// sans dépendre du satellite.
///
/// Le port est donc défini ici, au kernel, et implémenté côté satellite —
/// sur le même patron que [ZSessionCandidate] et le port neutre d'examen
/// approchant.
///
/// ## Surface minimale — chaque membre est justifié par un usage réel
///
/// Le risque n°1 d'un port est la sur-spécification : un port trop large
/// devient un modèle dupliqué. La règle appliquée ici : un membre n'existe
/// que si une carte du socle le consomme et qu'aucun rappel (callback) de
/// l'hôte ne le fournit déjà.
///
/// | Membre | Usage réel qui le motive |
/// |---|---|
/// | [id] | clé de widget stable et identité de réordonnancement |
/// | [title] | seule entrée obligatoire de la carte de document par défaut |
/// | [formatKey] | clé opaque pilotant glyphe, couleur de format et badge d'extension |
///
/// ### Membres délibérément absents (et pourquoi)
///
/// - **une date de mise à jour** — aucune carte ne consomme un `DateTime` :
///   le rendu par défaut prend un sous-titre déjà formaté et localisé par
///   l'hôte, et le socle ne formate jamais une date. Une entité de document
///   réelle peut d'ailleurs ne pas exposer de date de mise à jour du tout :
///   cette clé appartient à la métadonnée de synchronisation hors-entité
///   (invariant AD-9), pas à l'entité. L'exiger rendrait le port non
///   implémentable.
/// - **un nombre de pages** — le rendu par défaut n'a aucun créneau dédié.
///   Le champ peut exister sur l'entité réelle, mais un port se dimensionne
///   sur ce qui est consommé, pas sur ce que le modèle possède : le mettre
///   ici serait le premier pas vers le modèle dupliqué. Une méta-information
///   de ce genre passe par le sous-titre que l'hôte compose.
/// - **une extension de fichier nommée `extension`** — le nom est réservé :
///   une entité de document réelle porte déjà un slot d'extensibilité de ce
///   nom (invariant AD-4). La donnée visée est portée par [formatKey], qui
///   est d'ailleurs le nom exact du paramètre de la carte.
///
/// ## [formatKey] est opaque, jamais un enum fermé (invariant AD-4)
///
/// Extension (`'pdf'`), type MIME (`'application/pdf'`, `'image/png'`), ou
/// toute convention de l'hôte : le socle normalise, ne classifie pas. Un
/// format nouveau n'exige donc aucune modification de ce port.
///
/// ## Rien ne peut lever (invariant AD-10)
///
/// Le port ne déclare que des accesseurs ; aucune méthode, aucune horloge,
/// aucune validation. Un implémenteur qui n'a pas la donnée rend `null`
/// ([id]/[formatKey]) — jamais une exception.
library;

/// Référence neutre d'un document d'étude (implémentée côté satellite — par
/// exemple une entité de document, un adaptateur d'hôte, ou tout autre
/// porteur).
///
/// Pur-Dart, zéro import : le kernel reste ignorant du paquet de documents
/// (invariant AD-1).
abstract interface class ZStudyDocumentRef {
  /// Identité opaque, `null` si le document est éphémère (non matérialisé).
  ///
  /// Nullable par contrat du dépôt : l'identité d'une entité est `String?`
  /// dans tout le kernel — un port `String get id` serait non implémentable
  /// par l'entité réelle.
  String? get id;

  /// Libellé principal affiché, déjà résolu par le porteur.
  ///
  /// Non nullable : c'est le contenu principal de la carte, et le rendu par
  /// défaut l'exige. Un porteur dont le nom d'affichage est vide rend `''`
  /// — le repli visible pour un document sans titre est un libellé
  /// localisé, donc l'affaire de l'hôte, jamais du port.
  String get title;

  /// Clé de format opaque (`'pdf'`, `'application/pdf'`, `'image/png'`…),
  /// `null` si inconnue — normalisée par le rendu par défaut pour résoudre
  /// glyphe, couleur et badge d'extension.
  ///
  /// Ce n'est pas un enum (invariant AD-4) et ce n'est pas un libellé
  /// visible : le texte affiché (« PDF ») reste injecté par l'hôte.
  String? get formatKey;
}
