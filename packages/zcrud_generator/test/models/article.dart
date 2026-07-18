/// Modèle de PREUVE du générateur E2-5 (test-only — PAS un 15e package produit).
///
/// Annoté `@ZcrudModel`/`@ZcrudField`/`@ZcrudId`, il couvre : `@ZcrudId`
/// nullable, scalaires (`String` requis + `String?` nullable + `int`/`double`/
/// `bool`), enum ouvert avec `defaultValue`, `DateTime?`, `List<String>`
/// (multiple inféré), et un sous-modèle `@ZcrudModel` imbriqué (`Author?`).
///
/// Le `part 'article.g.dart'` est produit par **build_runner réel**
/// (`melos run generate`) — gitignoré, jamais édité/committé (Key Don'ts).
/// Importe la surface **pure** `edition.dart` (jamais le barrel principal, qui
/// tire Flutter via la couche présentation) : les tests tournent sous
/// `dart test`.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'article.g.dart';

/// Enum ouvert de statut (discipline `unknownEnumValue`/repli AD-10 : valeur
/// inconnue → `defaultValue` déclaré sur le champ).
enum ArticleStatus { draft, published, archived }

/// Article de démonstration du contrat de (dé)sérialisation E2-5.
@ZcrudModel(kind: 'article')
class Article {
  /// Construit un article (constructeur nommé — source du `copyWith` généré).
  const Article({
    this.id,
    required this.title,
    this.subtitle,
    this.views = 0,
    this.rating = 0,
    this.published = false,
    this.status = ArticleStatus.draft,
    this.createdAt,
    this.period,
    this.tags = const <String>[],
    this.author,
    this.coauthors = const <Author>[],
    this.pinValue,
    this.autoValue,
  });

  /// Reconstruit depuis une map persistée (délègue au `fromMap` généré défensif).
  factory Article.fromMap(Map<String, dynamic> map) => _$ArticleFromMap(map);

  /// Identité opaque (nullable pour l'éphémère).
  @ZcrudId()
  final String? id;

  /// Titre (requis + validateur déclaratif).
  @ZcrudField(label: 'Titre', validators: <ZValidatorSpec>[
    ZValidatorSpec.required(),
    ZValidatorSpec.minLength(3),
  ])
  final String title;

  /// Sous-titre facultatif (cible du test reset-`null` du `copyWith`).
  @ZcrudField()
  final String? subtitle;

  /// Nombre de vues.
  @ZcrudField()
  final int views;

  /// Note moyenne.
  @ZcrudField()
  final double rating;

  /// Publié ? (searchable).
  @ZcrudField(searchable: true)
  final bool published;

  /// Statut (enum ouvert, repli `defaultValue` si valeur inconnue).
  @ZcrudField(defaultValue: ArticleStatus.draft)
  final ArticleStatus status;

  /// Date de création. Hint B14 `persistAs: timestamp` : persistée en `Timestamp`
  /// Firestore natif (via `$ArticleTimestampFields`) ; reste ISO-8601 dans
  /// `toMap` (la conversion `Timestamp` est exclusive au chemin Firestore).
  @ZcrudField(persistAs: ZPersistAs.timestamp)
  final DateTime? createdAt;

  /// Plage de dates `ZDateRange` (AD-47) : (dé)sérialisation DÉFENSIVE via le
  /// helper généré `_$asDateRange` (une plage corrompue → `null`, parent survit).
  @ZcrudField()
  final ZDateRange? period;

  /// Étiquettes (multiple inféré depuis `List<String>`).
  @ZcrudField()
  final List<String> tags;

  /// Auteur imbriqué (sous-modèle défensif : corruption → parent survit).
  @ZcrudField()
  final Author? author;

  /// Co-auteurs (liste de sous-modèles `List<@ZcrudModel>` — chemin `listModel` :
  /// round-trip + décodage défensif par élément, cf. M2 code-review E2-5).
  @ZcrudField()
  final List<Author> coauthors;

  /// fp-5-1 (AD-52/AD-53) — type NOMMÉ `pin`, valeur **neutre** `String` :
  /// (dé)sérialisée par la catégorie EXISTANTE `_Cat.stringType` (aucune
  /// nouvelle catégorie générée). Le `type:` explicite ne change QUE le
  /// `EditionFieldType` émis, jamais le chemin de (dé)sérialisation.
  @ZcrudField(type: EditionFieldType.pin)
  final String? pinValue;

  /// fp-5-1 (AD-53) — type NOMMÉ `autocomplete`, valeur **neutre** `String`
  /// (chemin `_Cat.stringType` existant, défensif : non-`String` → `null`).
  @ZcrudField(type: EditionFieldType.autocomplete)
  final String? autoValue;

  // fp-5-1 (D1, découverte SUR DISQUE) — le 3e type NOMMÉ `editableTable` a
  // pour valeur neutre `List<Map<String, dynamic>>`. CE TYPE DART N'EST PAS
  // (dé)sérialisable par le générateur EXISTANT : `_classify` récurse sur
  // l'élément `Map<String, dynamic>`, qui ne correspond à AUCUNE branche
  // (scalaire/enum/DateTime/ZDateRange/@ZcrudModel) → `InvalidGenerationSourceError`.
  // C'est une LIMITE PRÉEXISTANTE du générateur (bare `Map` jamais supporté),
  // INDÉPENDANTE de fp-5-1. D1 impose de NE PAS toucher le générateur → aucun
  // champ `List<Map>` n'est ajouté ici (l'ajouter cassait la génération). Le
  // routage/neutralité d'`editableTable` est prouvé au niveau CŒUR (dispatch
  // → registryOrFallback → repli), cf. z_field_dispatch_test. Le `type:`
  // explicite n'influe QUE sur l'`EditionFieldType` émis, jamais sur le chemin
  // de (dé)sérialisation — prouvé par `pinValue`/`autoValue` (String neutre).

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article &&
          id == other.id &&
          title == other.title &&
          subtitle == other.subtitle &&
          views == other.views &&
          rating == other.rating &&
          published == other.published &&
          status == other.status &&
          createdAt == other.createdAt &&
          period == other.period &&
          author == other.author &&
          pinValue == other.pinValue &&
          autoValue == other.autoValue &&
          _listEq(tags, other.tags) &&
          _authorListEq(coauthors, other.coauthors);

  @override
  int get hashCode => Object.hash(id, title, subtitle, views, rating, published,
      status, createdAt, period, author, Object.hashAll(tags),
      Object.hashAll(coauthors), pinValue, autoValue);
}

/// Sous-modèle imbriqué.
@ZcrudModel(kind: 'author')
class Author {
  /// Construit un auteur.
  const Author({required this.name, this.email});

  /// Reconstruit depuis une map persistée (généré, défensif).
  factory Author.fromMap(Map<String, dynamic> map) => _$AuthorFromMap(map);

  /// Nom affiché.
  @ZcrudField()
  final String name;

  /// E-mail facultatif.
  @ZcrudField(validators: <ZValidatorSpec>[ZValidatorSpec.email()])
  final String? email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Author && name == other.name && email == other.email;

  @override
  int get hashCode => Object.hash(name, email);
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _authorListEq(List<Author> a, List<Author> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
