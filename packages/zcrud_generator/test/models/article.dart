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
    this.tags = const <String>[],
    this.author,
    this.coauthors = const <Author>[],
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

  /// Date de création (ISO-8601).
  @ZcrudField()
  final DateTime? createdAt;

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
          author == other.author &&
          _listEq(tags, other.tags) &&
          _authorListEq(coauthors, other.coauthors);

  @override
  int get hashCode => Object.hash(id, title, subtitle, views, rating, published,
      status, createdAt, author, Object.hashAll(tags),
      Object.hashAll(coauthors));
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
