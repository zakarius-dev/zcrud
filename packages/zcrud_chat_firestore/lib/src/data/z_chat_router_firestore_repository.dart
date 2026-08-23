/// Fabrique du dépôt Firestore des routeurs IA du chat.
///
/// Le repository Firestore générique (`FirebaseZRepositoryImpl`) sert
/// l'entité `ZChatRouter` **sans adaptateur spécifique** : son codec est
/// celui du noyau (`ZChatRouter.fromMap`/`toMap`), sa forme sur le fil est la
/// forme canonique (`routes` en liste, clés snake_case). Ce fichier n'apporte
/// que le **point d'accroche** dont un hôte a besoin pour brancher ce dépôt
/// sur une collection qui lui préexiste :
///
/// - un codec legacy optionnel ([ZChatRouterMapCodec]), appliqué **en amont**
///   du décodage et **en aval** de l'encodage — la casse, les renommages et
///   les regroupements propres à l'hôte restent chez l'hôte ;
/// - la sémantique de suppression de la collection, choisie par l'hôte ;
/// - un tri **défensif** des documents : un document dont un champ du schéma
///   porte un type illisible est écarté et journalisé, jamais décodé en
///   routeur vide.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

/// Transformation **pure** d'une map de document vers une autre map.
///
/// Un codec legacy en fournit deux : l'une convertit la forme de l'hôte vers
/// la forme canonique de `ZChatRouter` (lecture), l'autre fait l'inverse
/// (écriture). Une implémentation qui lève n'est jamais fatale : le document
/// est écarté à la lecture, et l'écriture retombe sur la forme canonique.
typedef ZChatRouterMapCodec =
    Map<String, dynamic> Function(Map<String, dynamic> map);

/// Construit un `ZRepository<ZChatRouter>` sur une collection Firestore.
///
/// [collectionPath] est le chemin de la collection ; aucun défaut n'est
/// proposé, le nom appartient à l'hôte.
///
/// ## Collection préexistante
///
/// Sur une collection **legacy** — documents écrits avant l'adoption de ce
/// dépôt, sans `is_deleted` ni `updated_at` — déclarer
/// `deletionSemantics: ZDeletionSemantics.absentMeansAlive`, sinon **aucun
/// routeur n'est lu** : la sémantique [ZDeletionSemantics.strict] exige la
/// présence du drapeau `is_deleted` sur chaque document (filtre serveur).
/// Chaque `save` pose `is_deleted:false` et `updated_at` : la collection
/// converge vers la forme stricte au fil des écritures, et l'hôte peut
/// basculer sur [ZDeletionSemantics.strict] une fois tous les documents
/// réécrits.
///
/// [toCanonical] reçoit la map **brute** du document (identifiant déjà injecté
/// sous `id`, horodatages déjà normalisés en ISO-8601) et rend la map que
/// `ZChatRouter.fromMap` sait lire : clés snake_case, `routes` en liste
/// `{task_key, model_id, …}`, modèle de référence sous `model_provider_id` /
/// `model_id`. [toLegacy] reçoit `ZChatRouter.toMap()` et rend la map écrite
/// sur le fil ; les métadonnées de synchronisation (`is_deleted`,
/// `updated_at`) sont ajoutées **après** lui par le dépôt et ne passent jamais
/// par le codec. Sans codec, la forme canonique est lue et écrite telle
/// quelle.
///
/// [legacyDeletedKey] n'est honorée qu'en [ZDeletionSemantics.absentMeansAlive]
/// (drapeau de suppression historique de l'hôte, lu en plus de `is_deleted`).
///
/// [extensionParser] décode le slot `extension` d'un hôte ; sans lui, une
/// extension persistée reste opaque. [logger] reçoit un message par document
/// écarté.
///
/// ## Documents écartés
///
/// Un document est écarté, et journalisé, dans trois cas : [toCanonical] a
/// levé ; la map canonique ne porte **aucune** clé du schéma du routeur (ce
/// n'est pas un routeur) ; une clé du schéma porte un type que le codec du
/// noyau ne sait pas lire (`routes` ni liste ni map, `is_active` non booléen,
/// `fallbacks` non liste, `params` non map, identifiants non textuels…).
/// Un document écarté n'apparaît dans aucune lecture et `getById` le rend
/// `Left(ZNotFoundFailure)` ; les autres documents ne sont jamais affectés.
ZRepository<ZChatRouter> buildChatRouterFirestoreRepository({
  required FirebaseFirestore firestore,
  required String collectionPath,
  ZChatRouterMapCodec? toCanonical,
  ZChatRouterMapCodec? toLegacy,
  ZDeletionSemantics deletionSemantics = ZDeletionSemantics.strict,
  String? legacyDeletedKey,
  ZChatExtensionParser? extensionParser,
  ZFirestoreLog? logger,
}) {
  ZChatRouter decode(Map<String, dynamic> canonical) =>
      ZChatRouter.fromMap(canonical, extensionParser: extensionParser);

  return FirebaseZRepositoryImpl<ZChatRouter>(
    firestore: firestore,
    collectionPath: collectionPath,
    kind: kZChatRouterKind,
    // Voie du convertisseur typé (relecture après `save`) : ne lève jamais.
    // Un codec qui lève ici retombe sur la map brute — `ZChatRouter.fromMap`
    // absorbe toute forme (AD-10).
    fromMap: (Map<String, dynamic> raw) =>
        decode(_canonicalOrNull(raw, toCanonical) ?? raw),
    toMap: (ZChatRouter router) => _encode(router, toLegacy),
    // Voie des lectures (getAll / watch / getById) : le tri défensif vit ici.
    fromMapSafe: (Map<String, dynamic> raw) {
      final Map<String, dynamic>? canonical = _canonicalOrNull(
        raw,
        toCanonical,
      );
      if (canonical == null) return null;
      if (zChatRouterShapeIssue(canonical) != null) return null;
      return decode(canonical);
    },
    logger: logger,
    deletionSemantics: deletionSemantics,
    legacyDeletedKey: legacyDeletedKey,
  );
}

/// Décrit pourquoi une map canonique **ne peut pas** être un routeur, ou
/// `null` si elle est lisible.
///
/// C'est le prédicat que la fabrique applique avant `ZChatRouter.fromMap` :
/// le codec du noyau ne lève jamais et remplacerait silencieusement un champ
/// illisible par son défaut — un document étranger à la collection
/// deviendrait un routeur vide, actif. Le prédicat est exposé pour qu'un
/// hôte puisse l'appliquer à ses propres fixtures ou outils de migration.
///
/// Règles, dans l'ordre :
/// - aucune clé du schéma du routeur hors `id`, ni `model` (forme imbriquée
///   tolérée en lecture), ni `params`, ni `extension` ⇒ « pas un routeur » ;
/// - `routes` présent et ni liste ni map ; `fallbacks` présent et non liste ;
///   `params` ou `extension` présent et non map ; `is_active` présent et non
///   booléen ; `compute_effort` présent et ni nombre ni texte ; `model`
///   présent et ni texte ni map ; `name`, `description`, `tier`,
///   `model_provider_id`, `model_id` présents et non textuels.
///
/// Une valeur `null` compte comme absente.
String? zChatRouterShapeIssue(Map<String, dynamic> canonical) {
  bool present(String key) => canonical[key] != null;

  final bool anySchemaKey = _kSchemaKeys.any(present) ||
      present('model') ||
      present('params') ||
      present('extension');
  if (!anySchemaKey) return 'aucune clé du schéma du routeur';

  final Object? routes = canonical['routes'];
  if (routes != null && routes is! List && routes is! Map) {
    return '`routes` ni liste ni map (${routes.runtimeType})';
  }
  final Object? fallbacks = canonical['fallbacks'];
  if (fallbacks != null && fallbacks is! List) {
    return '`fallbacks` non liste (${fallbacks.runtimeType})';
  }
  for (final String key in const <String>['params', 'extension']) {
    final Object? v = canonical[key];
    if (v != null && v is! Map) return '`$key` non map (${v.runtimeType})';
  }
  final Object? isActive = canonical['is_active'];
  if (isActive != null && zJsonBoolOrNull(isActive) == null) {
    return '`is_active` non booléen (${isActive.runtimeType})';
  }
  final Object? effort = canonical['compute_effort'];
  if (effort != null && effort is! num && effort is! String) {
    return '`compute_effort` ni nombre ni texte (${effort.runtimeType})';
  }
  final Object? model = canonical['model'];
  if (model != null && model is! String && model is! Map) {
    return '`model` ni texte ni map (${model.runtimeType})';
  }
  for (final String key in _kTextKeys) {
    final Object? v = canonical[key];
    if (v != null && v is! String) return '`$key` non textuel (${v.runtimeType})';
  }
  return null;
}

/// Clés du schéma d'édition du routeur, hors `id`.
final List<String> _kSchemaKeys = <String>[
  for (final ZFieldSpec s in $ZChatRouterFieldSpecs)
    if (s.name != 'id') s.name,
];

/// Clés du schéma dont la valeur est un texte.
const List<String> _kTextKeys = <String>[
  'name',
  'description',
  'tier',
  'model_provider_id',
  'model_id',
];

/// Applique [toCanonical] à [raw] ; `null` si le codec lève (le document est
/// alors écarté par la voie sûre, journalisé par le dépôt).
Map<String, dynamic>? _canonicalOrNull(
  Map<String, dynamic> raw,
  ZChatRouterMapCodec? toCanonical,
) {
  if (toCanonical == null) return raw;
  try {
    return toCanonical(raw);
  } on Object {
    return null;
  }
}

/// Encode [router] ; un [toLegacy] qui lève retombe sur la forme canonique
/// (jamais une écriture perdue).
Map<String, dynamic> _encode(ZChatRouter router, ZChatRouterMapCodec? toLegacy) {
  final Map<String, dynamic> canonical = router.toMap();
  if (toLegacy == null) return canonical;
  try {
    return toLegacy(canonical);
  } on Object {
    return canonical;
  }
}
