/// Seam IA neutre de **génération de cartes mentales** `ZMindmapGenerationPort`
/// (Story SU-12, FR-SU18, AC5 — aligné sur `ZFlashcardGenerationPort`).
///
/// origine: seam IA neutre du domaine `zcrud_study` (AD-5/AD-11/AD-12/AD-37). Le
/// port est un **contrat pur** (`abstract interface class`) : l'app hôte
/// l'*implements* avec son routeur IA. **Aucune** mécanique de transport ne fuit
/// dans le domaine — prompts, `toWireJson`, SSE, endpoints et clés restent CÔTÉ
/// APP. **Aucune impl de référence** n'est fournie (le port n'a aucun comportement
/// neutre à factoriser ; l'app *implements* librement, AD-15/AD-35).
///
/// ## Résultat ÉPHÉMÈRE (AD-37/AD-43)
///
/// Le port retourne une **forêt de `ZMindmapNode`** — pas un `ZMindmap`. `ZMindmap`
/// porte `id`+`folderId` = **identité de persistance** ; AD-37 exige un résultat
/// « ni id ni source du backend », matérialisé client-side **après revue**.
/// Retourner `ZMindmap` fabriquerait une identité fictive. Le résultat n'est
/// **jamais** persisté par le port.
///
/// ## Alignement STRUCTUREL sur `ZFlashcardGenerationPort` (pas une copie)
///
/// On **omet** `typesDistribution` (aucune notion de « type de nœud » à répartir
/// dans une carte) et `provenance: ZFlashcardSource` (provenance flashcard-
/// spécifique — la coupler au mindmap serait un mésusage). On **conserve** les
/// invariants d'AD-37 : requête d'UNION, `modelId` **opaque**, résultat éphémère.
/// Toute dimension future passe par des propriétés **typées additives** (jamais
/// [ZMindmapGenerationRequest.extra]), comme SU-9.
library;

import 'package:zcrud_core/domain.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart' show ZMindmapNode;

/// Référence **NEUTRE et OPAQUE** vers une source de génération (CR-LEX-22).
///
/// ## Le manque qu'elle comble
///
/// [ZMindmapGenerationRequest] ne portait qu'un `content: String` : elle
/// **supposait un contenu déjà résolu côté client**. Un hôte dont la résolution
/// est **serveur** — parce qu'elle exige de vérifier l'ownership, de lancer un
/// OCR, ou de décompter un quota — n'avait aucun endroit où mettre l'identité
/// de la source, et devait la porter **hors-bande** (canal parallèle, `extra`
/// non typé). `ZFlashcardGenerationPort`, lui, avait son slot typé : l'asymétrie
/// n'avait pas de raison d'être.
///
/// ## Ce qu'elle est, et ce qu'elle n'est PAS
///
/// **Deux champs, aucune sémantique.** [id] identifie la source dans le
/// référentiel de l'hôte ; [selector] borne éventuellement la portion voulue
/// (pages, plage, section). zcrud **ne les interprète jamais** — pas d'`enum`,
/// pas de catalogue, pas de `switch`. Elle ne reprend délibérément **aucune**
/// des valeurs flashcard-spécifiques de `ZFlashcardSource` : la carte mentale
/// n'a pas les mêmes provenances, et les recopier créerait une seconde source
/// de vérité qui divergerait.
// Pas d'`@immutable` : `package:meta` n'est pas une dépendance déclarée de ce
// paquet, s'y appuyer serait compter sur une transitive. La classe est de toute
// façon sans état et son constructeur est `const`.
class ZMindmapSourceRef {
  /// Construit une référence de source opaque.
  const ZMindmapSourceRef({required this.id, this.selector});

  /// Identifiant **opaque** de la source dans le référentiel de l'hôte
  /// (document, note, média…). Transporté VERBATIM, jamais interprété.
  final String id;

  /// Sélecteur **opaque** bornant la portion voulue (`"p.12-30"`, `"§4"`, …),
  /// ou `null` pour la source entière. Jamais parsé par zcrud.
  final String? selector;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZMindmapSourceRef &&
          id == other.id &&
          selector == other.selector;

  @override
  int get hashCode => Object.hash(id, selector);

  @override
  String toString() => 'ZMindmapSourceRef(id: $id, selector: $selector)';
}

/// Requête **immuable** de génération de carte mentale (value-object, `==`/
/// `hashCode` **par valeur**).
///
/// Ne porte que du **contenu source neutre** : aucun prompt, aucun endpoint,
/// aucune clé (AD-12). Aucun champ de persistance (id/folderId) : le résultat est
/// une forêt éphémère (AD-37).
class ZMindmapGenerationRequest {
  /// Construit une requête de génération à partir du [content] source.
  const ZMindmapGenerationRequest({
    required this.content,
    this.source,
    this.count,
    this.maxDepth,
    this.languageTag,
    this.instructions,
    this.modelId,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Contenu source neutre à partir duquel générer la carte (texte, note…).
  final String content;

  /// Référence **opaque** vers la source, ou `null` si [content] se suffit
  /// (CR-LEX-22). Additif : un hôte dont la résolution est CLIENT continue de
  /// ne renseigner que [content].
  ///
  /// ⚠️ [content] reste **requis** : un port qui ne sait pas résoudre une
  /// source doit toujours avoir de quoi travailler. Un hôte à résolution
  /// serveur passe une chaîne vide et s'appuie sur [source] — c'est son
  /// implémentation du port qui décide, zcrud n'arbitre pas.
  final ZMindmapSourceRef? source;

  /// Nombre de **nœuds** souhaité, ou `null` (l'app décide un défaut, borné
  /// app-side). Aucune notion de type de nœud (contraste flashcard).
  ///
  /// ⚠️ **Peut être inhonorable** : un générateur qui raisonne en profondeur
  /// n'a aucun moyen de garantir un nombre de nœuds. Un hôte est **fondé à le
  /// refuser** (`Left`) plutôt qu'à l'ignorer silencieusement — cf. [maxDepth],
  /// complémentaire (CR-LEX-24).
  final int? count;

  /// Profondeur maximale de l'arbre souhaitée, ou `null` (CR-LEX-24).
  ///
  /// **Complémentaire de [count], pas concurrente** : certains générateurs
  /// n'acceptent qu'une borne de profondeur, d'autres qu'un nombre de nœuds.
  /// Un hôte renseigne celle que le sien honore ; zcrud n'en dérive ni n'en
  /// impose aucune.
  final int? maxDepth;

  /// Étiquette de langue BCP-47 souhaitée (ex. `"fr"`), ou `null`.
  final String? languageTag;

  /// Consigne libre optionnelle transmise telle quelle à l'impl app-side (ex.
  /// « une branche par chapitre »), ou `null`. Contenu neutre — aucun prompt
  /// système, aucun endpoint (AD-12).
  final String? instructions;

  /// Identifiant de modèle **OPAQUE**, transporté VERBATIM et **jamais
  /// interprété** par zcrud : aucun `enum`, aucun `switch`, aucun catalogue,
  /// aucun libellé. Le type reste `String?` — le catalogue de modèles (et sa
  /// résolution) vit **entièrement** côté app (AD-15/AD-35). `null` = l'app décide.
  final String? modelId;

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
      other is ZMindmapGenerationRequest &&
          content == other.content &&
          source == other.source &&
          count == other.count &&
          maxDepth == other.maxDepth &&
          languageTag == other.languageTag &&
          instructions == other.instructions &&
          modelId == other.modelId &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        content,
        source,
        count,
        maxDepth,
        languageTag,
        instructions,
        modelId,
        zJsonHash(extra),
      );
}

/// Port neutre de **génération de carte mentale** (AD-5 : `Either<ZFailure,·>`).
///
/// L'app hôte l'*implements* avec son routeur IA. Retourne
/// `ZResult<List<ZMindmapNode>>` (`Either<ZFailure, List<ZMindmapNode>>`) — une
/// forêt **éphémère** de nœuds SANS `id`/`folderId` backend (AD-37 ; la
/// matérialisation en `ZMindmap` est app-side, après revue). **Jamais** une
/// `List<ZMindmapNode>` nue, **jamais** un `Stream` enveloppé (AD-5). En cas
/// d'échec (quota, réseau, parsing) → `Left(ZFailure)` **advisory** (AD-10 : le
/// port ne propage jamais d'exception).
abstract interface class ZMindmapGenerationPort {
  /// Génère une forêt de nœuds éphémères depuis [request]. `Left` en cas
  /// d'échec, `Right` avec la forêt produite en cas de succès.
  Future<ZResult<List<ZMindmapNode>>> generateMindmap(
    ZMindmapGenerationRequest request,
  );
}
