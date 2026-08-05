/// Seam IA neutre de **génération de flashcards** `ZFlashcardGenerationPort`
/// (Story ES-9.1, AC1/AC5).
///
/// origine: seam IA neutre du domaine `zcrud_study` (AD-5/AD-11/AD-12). Le port
/// est un **contrat pur** (`abstract interface class`) : l'app hôte l'*implements*
/// avec son routeur IA. **Aucune** mécanique de transport ne fuit dans le
/// domaine — prompts, `toWireJson`, SSE, endpoints et clés restent CÔTÉ APP.
///
/// **`abstract interface class` (AD-4)** : frontière inter-package ⇒ **jamais
/// `sealed`** (pas d'exhaustivité imposée, l'app *implements* librement). Aucune
/// impl de référence n'est fournie dans le package : le port n'a aucun
/// comportement neutre à factoriser (contraste avec un repository Template
/// Method).
///
/// **Provenance registre-pluggable (AC5)** : la requête porte une
/// [ZFlashcardSource] optionnelle (variant IFFD/lex `article`/`subject`/
/// `hsSection`/`chatConversationId` enregistré par l'app via `ZSourceRegistry`,
/// AD-4). L'impl app-side **estampille** `request.provenance` dans
/// [ZFlashcard.source] des cartes produites, de sorte que la provenance
/// round-trippe **exactement** via `ZFlashcard.toMap`/`fromMap(sourceRegistry:)`.
/// `zcrud_study` ne code **aucun** `kind` de provenance en dur.
library;

import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Source de génération **RÉSOLUE** (CR-IFFD-70) — value-object immuable.
///
/// La feuille de génération permet de **choisir** des sources du contexte
/// courant (documents, notes) et d'en **acquérir** sur place ; leur contenu est
/// résolu **à la demande** par l'hôte (le socle ne sait ni lire un PDF ni
/// scanner — l'extraction appartient à l'hôte, comme la génération appartient à
/// [ZFlashcardGenerationPort]). Une source résolue prend l'une de TROIS formes,
/// toutes légitimes :
///
/// * **texte composé** — [text] non nul ;
/// * **contenu PAGINÉ, éventuellement PARTIEL** — [pagesContents] non nul :
///   index de page → contenu, pour les **seules pages choisies** (une source
///   volumineuse — PDF de 300 pages — n'oblige jamais à tout résoudre ; le
///   legacy IFFD passe exactement cette forme,
///   `generateFlashcardsFromDocumentPagesContents(pagesContents: Map<int,String>)`) ;
/// * **PAR RÉFÉRENCE** — [text] et [pagesContents] nuls : la [provenance]
///   (variant `ZSourceRegistry`, ex. `documentId`) porte la référence et l'impl
///   app-side du port extrait côté serveur — couvre l'appel legacy
///   `generateFlashcardsFromWholeDocument(documentId)` (commenté chez IFFD).
///
/// Le contrat n'impose **ni** que la source acquise soit conservée dans le
/// dossier **ni** qu'elle reste éphémère : question de PRODUIT, tranchée par
/// l'hôte hors de ce type (AD-4).
class ZResolvedGenerationSource {
  /// Construit une source résolue (toutes formes optionnelles — cf. classe).
  const ZResolvedGenerationSource({this.text, this.pagesContents, this.provenance});

  /// Contenu texte composé, ou `null` (forme paginée ou par référence).
  final String? text;

  /// Contenu paginé PARTIEL (index de page → contenu des pages **choisies**),
  /// ou `null`.
  final Map<int, String>? pagesContents;

  /// Provenance de CETTE source (variant `ZSourceRegistry`), ou `null`.
  /// Porte la référence dans la forme « par référence ».
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

  /// Égalité PROFONDE de deux contenus paginés, `null`-safe.
  static bool _pagesEquals(Map<int, String>? a, Map<int, String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Hash indépendant de l'ordre d'un contenu paginé (`null` → `0`).
  static int _pagesHash(Map<int, String>? m) => m == null
      ? 0
      : Object.hashAllUnordered(
          m.entries.map((e) => Object.hash(e.key, e.value)),
        );
}

/// Résolveur **À LA DEMANDE** du contenu d'une source (CR-IFFD-70 — AD-5/AD-10).
///
/// Fourni par l'hôte, invoqué par le flux de génération **au moment de la
/// soumission seulement** (jamais à l'ouverture de la feuille — un dossier peut
/// porter 50 documents, SM-1). Tout échec (fichier illisible, OCR raté) revient
/// en `Left(ZFailure)` — **jamais** un throw exigé ; un throw est néanmoins
/// capté par le contrôleur (AD-10) et converti en échec affiché.
typedef ZGenerationSourceResolver = Future<ZResult<ZResolvedGenerationSource>>
    Function();

/// Requête **immuable** de génération de flashcards (value-object, `==`/`hashCode`
/// par valeur).
///
/// Ne porte que du **contenu source neutre** : aucun prompt, aucun endpoint,
/// aucune clé (AC2/AD-12). Le [provenance] optionnel est apposé aux cartes
/// produites (AC5).
///
/// ## Requête d'UNION canonique (AD-37, SU-9/AC1)
///
/// Porte les **6 dimensions** de la demande : `{source (content+provenance),
/// count, typesDistribution, languageTag, instructions, modelId}`. Les trois
/// derniers champs ([typesDistribution]/[instructions]/[modelId]) ont été
/// **ajoutés en SU-9** de façon **OPTIONNELLE et ADDITIVE** : le DTO n'est PAS
/// codegen (aucune annotation, aucune (dé)sérialisation générée) ⇒ l'extension
/// n'a **aucun** impact rétro-compat pour l'unique consommateur (le port), dont
/// la signature reste inchangée. Ces champs canoniques passent par des propriétés
/// TYPÉES, **jamais** par [extra] (l'échappatoire non typée n'est pas le lieu
/// d'un champ canonique — sinon on masquerait le contrat de [modelId] et on
/// violerait « source unique » d'AD-37).
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

  /// Contenu source neutre à partir duquel générer les cartes (texte, note…).
  final String content;

  /// Nombre de cartes souhaité, ou `null` (l'app décide un défaut).
  final int? count;

  /// Étiquette de langue BCP-47 souhaitée (ex. `"fr"`), ou `null`.
  final String? languageTag;

  /// Provenance **ouverte** à estampiller dans `ZFlashcard.source` des cartes
  /// produites (variant IFFD/lex enregistré via `ZSourceRegistry`, AC5). `null`
  /// = pas de provenance imposée.
  final ZFlashcardSource? provenance;

  /// Répartition souhaitée du lot par type de carte (`{multipleChoice: 3, …}`),
  /// ou `null` (l'app/le module de défauts calcule une répartition équitable).
  ///
  /// SU-9/AC1 : porté PAR VALEUR (deux requêtes qui n'en diffèrent que par cette
  /// map ne sont PAS égales). La normalisation (négatifs → 0, types inconnus
  /// écartés, somme bornée) est faite par `zNormalizeTypesDistribution`
  /// (`z_flashcard_generation_defaults.dart`), source UNIQUE — jamais ici.
  final Map<ZFlashcardType, int>? typesDistribution;

  /// Consigne libre optionnelle transmise telle quelle à l'impl app-side (ex.
  /// « insiste sur les définitions »), ou `null`. Contenu neutre — aucun prompt
  /// système, aucun endpoint (AD-12).
  final String? instructions;

  /// Identifiant de modèle **OPAQUE** (SU-9/AC2), transporté VERBATIM et **jamais
  /// interprété** par zcrud : aucun `enum`, aucun `switch`, aucun catalogue,
  /// aucun libellé. Le type reste `String?` — le catalogue de modèles (et sa
  /// résolution) vit **entièrement** côté app (AD-15/AD-35). `null` = l'app
  /// décide.
  final String? modelId;

  /// Sources du contexte **résolues à la demande** (CR-IFFD-70), ou `null`.
  ///
  /// Champ **ADDITIF et OPTIONNEL** (même discipline que l'extension SU-9) :
  /// tout hôte existant construit sa requête sans y toucher — `null` = flux
  /// historique inchangé, le contenu vient de [content]. Quand la feuille porte
  /// des sources sélectionnées, chacune arrive ici **dans l'ordre de
  /// présentation**, sous sa forme résolue (texte, pages CHOISIES, ou par
  /// référence — cf. [ZResolvedGenerationSource]). Les sources sont COMPOSITES :
  /// la liste peut en porter plusieurs, l'impl app-side du port compose.
  ///
  /// [content] et [provenance] gardent leur sémantique historique (champ de
  /// texte libre de la feuille ; provenance du sélecteur single-select) — les
  /// provenances PAR SOURCE voyagent dans chaque élément de cette liste.
  final List<ZResolvedGenerationSource>? resolvedSources;

  /// Copie de la requête portant [resolvedSources] (tout le reste inchangé).
  ///
  /// Utilisée par le contrôleur pour apposer les sources résolues au moment de
  /// la soumission — la requête reste un value-object immuable.
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

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (paramètres app-specific neutres). Défaut `const {}`.
  /// **Normalisée à la LECTURE (AD-19.1)** : les clés de sync réservées
  /// (`updated_at`/`is_deleted`) sont écartées — jamais réémises. Ce DTO n'est
  /// pas persisté, mais la garde machine reste uniforme sur tout porteur d'`extra`.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra] (AD-19.1, `...ZSyncMeta.reservedKeys`).
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

  /// Égalité PROFONDE et ORDONNÉE de deux listes de sources résolues (CR-70),
  /// `null`-safe — deux requêtes qui n'en diffèrent que par ces sources ne sont
  /// PAS égales (value-object).
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

  /// Hash ORDONNÉ des sources résolues (`null` → `0`).
  static int _sourcesHash(List<ZResolvedGenerationSource>? s) =>
      s == null ? 0 : Object.hashAll(s);

  /// Égalité PROFONDE de deux répartitions (clés + valeurs), `null`-safe (AC1).
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

  /// Hash indépendant de l'ordre d'une répartition (`null` → `0`).
  static int _typesDistHash(Map<ZFlashcardType, int>? m) => m == null
      ? 0
      : Object.hashAllUnordered(
          m.entries.map((e) => Object.hash(e.key, e.value)),
        );
}

/// Port neutre de **génération de flashcards** (AD-5 : `Either<ZFailure,·>`).
///
/// L'app hôte l'*implements* avec son routeur IA. Retourne
/// `ZResult<List<ZFlashcard>>` (`Either<ZFailure, List<ZFlashcard>>`) — **jamais**
/// une `List<ZFlashcard>` nue, **jamais** un `Stream` enveloppé (AD-5).
abstract interface class ZFlashcardGenerationPort {
  /// Génère des flashcards depuis [request]. `Left` en cas d'échec (quota,
  /// réseau, parsing), `Right` avec les cartes produites en cas de succès.
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
    ZFlashcardGenerationRequest request,
  );
}
