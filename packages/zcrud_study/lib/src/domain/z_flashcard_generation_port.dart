/// Seam IA neutre de génération de flashcards à partir d'un contenu
/// d'étude.
///
/// Le port est un contrat pur (`abstract interface class`, jamais `sealed`
/// — invariant AD-4, l'application hôte l'implémente librement) : elle le
/// branche sur son propre routeur IA. Aucune mécanique de transport ne fuit
/// dans le domaine (invariant AD-12) — prompts, format de transport, flux
/// serveur, endpoints et clés restent côté application. Aucune
/// implémentation de référence n'est fournie dans ce paquet : le port n'a
/// aucun comportement neutre à factoriser.
///
/// La requête porte une [ZFlashcardSource] optionnelle — une provenance
/// ouverte enregistrée par l'application via `ZSourceRegistry` (invariant
/// AD-4). L'implémentation côté application estampille `request.provenance`
/// dans [ZFlashcard.source] des cartes produites, de sorte que la provenance
/// fait l'aller-retour exactement via `ZFlashcard.toMap`/`fromMap(sourceRegistry:)`.
/// Ce paquet ne code aucun type de provenance en dur.
library;

import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Source de génération résolue — value-object immuable.
///
/// La feuille de génération permet de choisir des sources du contexte
/// courant (documents, notes) et d'en acquérir sur place ; leur contenu est
/// résolu à la demande par l'hôte (ce paquet ne sait ni lire un PDF ni
/// scanner — l'extraction appartient à l'hôte, comme la génération
/// appartient à [ZFlashcardGenerationPort]). Une source résolue prend l'une
/// de trois formes, toutes légitimes :
///
/// * **texte composé** — [text] non nul ;
/// * **contenu paginé, éventuellement partiel** — [pagesContents] non nul :
///   index de page vers contenu, pour les seules pages choisies (une source
///   volumineuse — un PDF de 300 pages — n'oblige jamais à tout résoudre) ;
/// * **par référence** — [text] et [pagesContents] nuls : la [provenance]
///   porte la référence et l'implémentation côté application du port
///   extrait le contenu côté serveur.
///
/// Le contrat n'impose ni que la source acquise soit conservée dans le
/// dossier ni qu'elle reste éphémère : c'est une question de produit,
/// tranchée par l'hôte hors de ce type.
class ZResolvedGenerationSource {
  /// Construit une source résolue (toutes les formes sont optionnelles —
  /// voir la documentation de la classe).
  const ZResolvedGenerationSource({this.text, this.pagesContents, this.provenance});

  /// Contenu texte composé, ou `null` (forme paginée ou par référence).
  final String? text;

  /// Contenu paginé partiel (index de page vers contenu des pages
  /// choisies), ou `null`.
  final Map<int, String>? pagesContents;

  /// Provenance de cette source, ou `null`. Porte la référence dans la
  /// forme « par référence ».
  final ZFlashcardSource? provenance;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZResolvedGenerationSource &&
          text == other.text &&
          provenance == other.provenance &&
          _pagesEquals(pagesContents, other.pagesContents);

  @override
  int get hashCode => Object.hash(text, provenance, _pagesHash(pagesContents));

  /// Égalité profonde de deux contenus paginés, `null`-safe.
  static bool _pagesEquals(Map<int, String>? a, Map<int, String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Hash indépendant de l'ordre d'un contenu paginé (`null` retourne `0`).
  static int _pagesHash(Map<int, String>? m) => m == null
      ? 0
      : Object.hashAllUnordered(
          m.entries.map((e) => Object.hash(e.key, e.value)),
        );
}

/// Résolveur à la demande du contenu d'une source (invariant AD-5 : domaine
/// backend-agnostique).
///
/// Fourni par l'hôte, invoqué par le flux de génération au moment de la
/// soumission seulement — jamais à l'ouverture de la feuille, pour ne pas
/// résoudre en une fois le contenu de dizaines de documents. Tout échec
/// (fichier illisible, OCR manqué) revient en `Left(ZFailure)` — un throw
/// n'est pas exigé, mais s'il survient il est capté par le contrôleur
/// (invariant AD-10) et converti en échec affiché.
typedef ZGenerationSourceResolver = Future<ZResult<ZResolvedGenerationSource>>
    Function();

/// Requête immuable de génération de flashcards (value-object,
/// `==`/`hashCode` par valeur).
///
/// Ne porte que du contenu source neutre : aucun prompt, aucun endpoint,
/// aucune clé (invariant AD-12). Le [provenance] optionnel est apposé aux
/// cartes produites.
///
/// Cette requête est la forme canonique d'union de la demande : elle porte
/// six dimensions — source (contenu et provenance), nombre de cartes,
/// répartition par type, langue, consignes et identifiant de modèle. Ces
/// champs canoniques passent par des propriétés typées, jamais par [extra]
/// — l'échappatoire non typée n'est pas le lieu d'un champ canonique.
class ZFlashcardGenerationRequest {
  /// Construit une requête de génération à partir du [content] source.
  const ZFlashcardGenerationRequest({
    required this.content,
    this.count,
    this.languageTag,
    this.provenance,
    this.typesDistribution,
    this.instructions,
    this.modelId,
    this.resolvedSources,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Contenu source neutre à partir duquel générer les cartes (texte,
  /// note…).
  final String content;

  /// Nombre de cartes souhaité, ou `null` (l'application décide d'un
  /// défaut).
  final int? count;

  /// Étiquette de langue BCP-47 souhaitée (ex. `"fr"`), ou `null`.
  final String? languageTag;

  /// Provenance ouverte à estampiller dans `ZFlashcard.source` des cartes
  /// produites. `null` signifie qu'aucune provenance n'est imposée.
  final ZFlashcardSource? provenance;

  /// Répartition souhaitée du lot par type de carte (`{multipleChoice: 3,
  /// …}`), ou `null` (l'application ou le module de défauts calcule une
  /// répartition équitable).
  ///
  /// Portée par valeur : deux requêtes qui n'en diffèrent que par cette map
  /// ne sont pas égales. La normalisation (négatifs ramenés à `0`, types
  /// inconnus écartés, somme bornée) est faite par
  /// `zNormalizeTypesDistribution` (`z_flashcard_generation_defaults.dart`),
  /// source unique — jamais ici.
  final Map<ZFlashcardType, int>? typesDistribution;

  /// Consigne libre optionnelle transmise telle quelle à l'implémentation
  /// côté application (ex. « insiste sur les définitions »), ou `null`.
  /// Contenu neutre — aucun prompt système, aucun endpoint (invariant
  /// AD-12).
  final String? instructions;

  /// Identifiant de modèle opaque, transporté tel quel et jamais interprété
  /// par ce paquet : aucun `enum`, aucun `switch`, aucun catalogue. Le
  /// catalogue de modèles et sa résolution vivent entièrement côté
  /// application. `null` signifie que l'application décide.
  final String? modelId;

  /// Sources du contexte résolues à la demande, ou `null`.
  ///
  /// Champ additif et optionnel : tout hôte existant construit sa requête
  /// sans y toucher — `null` signifie que le contenu vient uniquement de
  /// [content]. Quand la feuille porte des sources sélectionnées, chacune
  /// arrive ici dans l'ordre de présentation, sous sa forme résolue (texte,
  /// pages choisies, ou par référence — voir [ZResolvedGenerationSource]).
  /// Les sources sont composites : la liste peut en porter plusieurs,
  /// l'implémentation côté application du port les compose.
  ///
  /// [content] et [provenance] gardent leur sémantique historique (champ de
  /// texte libre de la feuille ; provenance du sélecteur à choix unique) —
  /// les provenances par source voyagent dans chaque élément de cette
  /// liste.
  final List<ZResolvedGenerationSource>? resolvedSources;

  /// Copie de la requête portant [resolvedSources] (tout le reste
  /// inchangé).
  ///
  /// Utilisée par le contrôleur pour apposer les sources résolues au moment
  /// de la soumission — la requête reste un value-object immuable.
  ZFlashcardGenerationRequest withResolvedSources(
    List<ZResolvedGenerationSource> sources,
  ) =>
      ZFlashcardGenerationRequest(
        content: content,
        count: count,
        languageTag: languageTag,
        provenance: provenance,
        typesDistribution: typesDistribution,
        instructions: instructions,
        modelId: modelId,
        resolvedSources: List<ZResolvedGenerationSource>.unmodifiable(sources),
        extra: _extra,
      );

  /// Slot brut de l'échappatoire (normalisé à la lecture via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée pour des paramètres spécifiques à
  /// l'application, normalisée à la lecture : les clés de synchronisation
  /// réservées (`updated_at`, `is_deleted`) sont toujours écartées. Ce DTO
  /// n'est pas persisté, mais cette normalisation garde un comportement
  /// uniforme sur tout porteur d'`extra` du domaine. Défaut `const {}`.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra] à la lecture.
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardGenerationRequest &&
          content == other.content &&
          count == other.count &&
          languageTag == other.languageTag &&
          provenance == other.provenance &&
          instructions == other.instructions &&
          modelId == other.modelId &&
          _typesDistEquals(typesDistribution, other.typesDistribution) &&
          _sourcesEquals(resolvedSources, other.resolvedSources) &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        content,
        count,
        languageTag,
        provenance,
        instructions,
        modelId,
        _typesDistHash(typesDistribution),
        _sourcesHash(resolvedSources),
        zJsonHash(extra),
      );

  /// Égalité profonde et ordonnée de deux listes de sources résolues,
  /// `null`-safe — deux requêtes qui n'en diffèrent que par ces sources ne
  /// sont pas égales (value-object).
  static bool _sourcesEquals(
    List<ZResolvedGenerationSource>? a,
    List<ZResolvedGenerationSource>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Hash ordonné des sources résolues (`null` retourne `0`).
  static int _sourcesHash(List<ZResolvedGenerationSource>? s) =>
      s == null ? 0 : Object.hashAll(s);

  /// Égalité profonde de deux répartitions (clés et valeurs), `null`-safe.
  static bool _typesDistEquals(
    Map<ZFlashcardType, int>? a,
    Map<ZFlashcardType, int>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Hash indépendant de l'ordre d'une répartition (`null` retourne `0`).
  static int _typesDistHash(Map<ZFlashcardType, int>? m) => m == null
      ? 0
      : Object.hashAllUnordered(
          m.entries.map((e) => Object.hash(e.key, e.value)),
        );
}

/// Port neutre de génération de flashcards (invariant AD-5 : domaine
/// backend-agnostique).
///
/// L'application hôte l'implémente avec son propre routeur IA. Retourne
/// `ZResult<List<ZFlashcard>>` (`Either<ZFailure, List<ZFlashcard>>`) —
/// jamais une `List<ZFlashcard>` nue.
abstract interface class ZFlashcardGenerationPort {
  /// Génère des flashcards depuis [request]. `Left` en cas d'échec (quota,
  /// réseau, analyse), `Right` avec les cartes produites en cas de succès.
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
    ZFlashcardGenerationRequest request,
  );
}
