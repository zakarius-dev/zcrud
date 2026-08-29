/// Seam IA neutre de génération de carte mentale à partir d'un contenu
/// d'étude.
///
/// Le port est un contrat pur (`abstract interface class`) : l'application
/// hôte l'implémente avec son propre routeur IA. Aucune mécanique de
/// transport ne fuit dans le domaine (invariant AD-12) — prompts, format de
/// transport, flux serveur, endpoints et clés restent côté application.
/// Aucune implémentation de référence n'est fournie : le port n'a aucun
/// comportement neutre à factoriser, l'application implémente librement.
///
/// Le port retourne une **forêt de `ZMindmapNode` éphémère** — pas un
/// `ZMindmap`. `ZMindmap` porte `id` et `folderId`, qui sont une identité de
/// persistance ; un résultat de génération n'a ni identifiant ni source de
/// backend avant d'être matérialisé côté application, après revue.
/// Retourner un `ZMindmap` directement fabriquerait une identité fictive :
/// le résultat de génération n'est jamais persisté par ce port lui-même.
///
/// Ce contrat s'aligne structurellement sur `ZFlashcardGenerationPort`, sans
/// en être une copie : il omet `typesDistribution` (aucune notion de « type
/// de nœud » à répartir dans une carte mentale) et la provenance
/// spécifique aux flashcards (la coupler à une carte mentale serait un
/// mésusage). Il conserve en revanche la requête d'union et l'identifiant de
/// modèle opaque. Toute dimension future passe par des propriétés typées
/// additives, jamais par [ZMindmapGenerationRequest.extra].
library;

import 'package:zcrud_core/domain.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart' show ZMindmapNode;

/// Référence neutre et opaque vers une source de génération.
///
/// Comble un manque structurel : une requête qui ne porte qu'un
/// `content: String` suppose un contenu déjà résolu côté client. Un hôte
/// dont la résolution est côté serveur — parce qu'elle exige de vérifier la
/// propriété, de lancer un OCR, ou de décompter un quota — a besoin d'un
/// endroit où placer l'identité de la source plutôt que de la faire
/// transiter hors-bande.
///
/// Deux champs, aucune sémantique interprétée par ce paquet : [id] identifie
/// la source dans le référentiel de l'hôte ; [selector] borne éventuellement
/// la portion voulue (pages, plage, section). Ni `enum`, ni catalogue, ni
/// `switch` — cette classe ne reprend délibérément aucune des valeurs
/// spécifiques aux flashcards, car une carte mentale n'a pas les mêmes
/// provenances et les recopier créerait une seconde source de vérité
/// divergente.
// Pas d'`@immutable` : `package:meta` n'est pas une dépendance déclarée de ce
// paquet, s'y appuyer serait compter sur une transitive. La classe est de toute
// façon sans état et son constructeur est `const`.
class ZMindmapSourceRef {
  /// Construit une référence de source opaque.
  const ZMindmapSourceRef({required this.id, this.selector});

  /// Identifiant opaque de la source dans le référentiel de l'hôte
  /// (document, note, média…). Transporté tel quel, jamais interprété.
  final String id;

  /// Sélecteur opaque bornant la portion voulue (`"p.12-30"`, `"§4"`, …), ou
  /// `null` pour la source entière. Jamais analysé par ce paquet.
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

/// Requête immuable de génération de carte mentale (value-object,
/// `==`/`hashCode` par valeur).
///
/// Ne porte que du contenu source neutre : aucun prompt, aucun endpoint,
/// aucune clé (invariant AD-12). Aucun champ de persistance (`id`,
/// `folderId`) : le résultat de génération est une forêt éphémère.
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
    this.summarize = false,
    this.routeId,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Contenu source neutre à partir duquel générer la carte (texte, note…).
  final String content;

  /// Référence opaque vers la source, ou `null` si [content] se suffit à
  /// lui-même. Additif : un hôte dont la résolution est côté client continue
  /// de ne renseigner que [content].
  ///
  /// [content] reste requis : un port qui ne sait pas résoudre une source
  /// doit toujours avoir de quoi travailler. Un hôte à résolution serveur
  /// passe une chaîne vide et s'appuie sur [source] — c'est son
  /// implémentation du port qui en décide, ce paquet n'arbitre pas.
  final ZMindmapSourceRef? source;

  /// Nombre de nœuds souhaité, ou `null` (l'application décide d'un défaut,
  /// borné côté application). Aucune notion de type de nœud, contrairement à
  /// une génération de flashcards.
  ///
  /// Peut être inhonorable : un générateur qui raisonne en profondeur n'a
  /// aucun moyen de garantir un nombre de nœuds exact. Un hôte est fondé à
  /// le refuser (`Left`) plutôt qu'à l'ignorer silencieusement — voir
  /// [maxDepth], complémentaire.
  final int? count;

  /// Profondeur maximale de l'arbre souhaitée, ou `null`.
  ///
  /// Complémentaire de [count], pas concurrente : certains générateurs
  /// n'acceptent qu'une borne de profondeur, d'autres qu'un nombre de nœuds.
  /// Un hôte renseigne celle que le sien honore ; ce paquet n'en dérive ni
  /// n'en impose aucune.
  final int? maxDepth;

  /// Étiquette de langue BCP-47 souhaitée (ex. `"fr"`), ou `null`.
  final String? languageTag;

  /// Consigne libre optionnelle transmise telle quelle à l'implémentation
  /// côté application (ex. « une branche par chapitre »), ou `null`.
  /// Contenu neutre — aucun prompt système, aucun endpoint (invariant
  /// AD-12).
  final String? instructions;

  /// Identifiant de modèle opaque, transporté tel quel et jamais interprété
  /// par ce paquet : aucun `enum`, aucun `switch`, aucun catalogue. Le
  /// catalogue de modèles et sa résolution vivent entièrement côté
  /// application. `null` signifie que l'application décide.
  final String? modelId;

  /// Demande de **condensation** de la source plutôt que son développement
  /// (`false` par défaut : comportement inchangé pour tout appelant existant).
  ///
  /// Deux intentions distinctes se disputent la même source : *cartographier*
  /// ce qu'elle contient, ou en *résumer* la substance en un arbre court. Une
  /// consigne libre ne suffit pas à les distinguer de façon fiable côté
  /// implémentation ; ce drapeau porte l'intention explicitement. Comme
  /// [count] et [maxDepth], il peut être **inhonorable** : un générateur est
  /// fondé à le refuser (`Left`) plutôt qu'à l'ignorer silencieusement.
  final bool summarize;

  /// Identifiant de **route** opaque, transporté tel quel et jamais interprété
  /// par ce paquet : aucun `enum`, aucun `switch`, aucun catalogue, et
  /// **jamais une URL** — le contrat reste sans transport (invariant AD-12).
  ///
  /// Deux modes de transport coexistent chez les applications hôtes : un
  /// endpoint unique à corps riche, et **une route par intention de
  /// génération** — mode qui porte la gouvernance (une route et ses accès
  /// associés à un plan d'abonnement) et permet de déclarer par tâche le
  /// modèle par défaut. Ce champ est l'endroit où l'intention de route voyage
  /// avec la requête ; sa résolution en transport réel appartient
  /// entièrement à l'implémentation du port. `null` signifie que
  /// l'application décide.
  final String? routeId;

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

  /// Copie de cette requête portant [routeId], tous les autres champs
  /// **inchangés** (l'`extra` d'origine est reconduit tel quel).
  ///
  /// Permet à une surface d'assemblage d'apposer la route juste avant l'appel
  /// du port, sans que l'appelant ait à reconstruire la requête champ par
  /// champ — et sans qu'aucune valeur saisie ne soit réécrite au passage.
  ZMindmapGenerationRequest withRouteId(String? routeId) =>
      ZMindmapGenerationRequest(
        content: content,
        source: source,
        count: count,
        maxDepth: maxDepth,
        languageTag: languageTag,
        instructions: instructions,
        modelId: modelId,
        summarize: summarize,
        routeId: routeId,
        extra: _extra,
      );

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
          summarize == other.summarize &&
          routeId == other.routeId &&
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
        summarize,
        routeId,
        zJsonHash(extra),
      );
}

/// Port neutre de génération de carte mentale (invariant AD-5 : domaine
/// backend-agnostique).
///
/// L'application hôte l'implémente avec son propre routeur IA. Retourne
/// `ZResult<List<ZMindmapNode>>` (`Either<ZFailure, List<ZMindmapNode>>`) —
/// une forêt éphémère de nœuds sans `id` ni `folderId` de backend (la
/// matérialisation en `ZMindmap` se fait côté application, après revue).
/// Jamais une `List<ZMindmapNode>` nue. En cas d'échec (quota, réseau,
/// analyse) : `Left(ZFailure)` — le port ne propage jamais d'exception
/// (invariant AD-10).
abstract interface class ZMindmapGenerationPort {
  /// Génère une forêt de nœuds éphémères depuis [request]. `Left` en cas
  /// d'échec, `Right` avec la forêt produite en cas de succès.
  Future<ZResult<List<ZMindmapNode>>> generateMindmap(
    ZMindmapGenerationRequest request,
  );
}
