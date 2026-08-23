/// Décodage d'un catalogue reçu du dehors — `ZChatRouteCatalogDecoder` et
/// `ZChatRouteCatalogShape` (invariants AD-4, AD-10).
///
/// Un backend ne parle pas forcément la forme canonique de `ZChatRouter`
/// (`routes: [{task_key, …}]`). Le décodeur **normalise** d'abord chaque
/// élément reçu vers cette forme, selon une **forme** déclarée
/// ([ZChatRouteCatalogShape] — une donnée, pas du code), puis le lit par
/// `ZChatRouter.fromMap`. Un élément illisible est **rejeté et signalé**
/// ([ZChatRouteCatalogDecodeReport.rejected]) : il n'entraîne jamais la liste
/// avec lui.
///
/// ## Deux mécanismes de forme, composables
///
/// - **Objet de routes** ([ZChatRouteCatalogShape.routeMapKeys]) : une clé
///   racine porte un objet `{clé de tâche: {…}}` dont chaque entrée devient
///   une route ; les clés de l'entrée sont traduites par
///   [ZChatRouteCatalogShape.routeAliases], les clés restées inconnues vont
///   dans les `params` de la route.
/// - **Paires à suffixe** ([ZChatRouteCatalogShape.suffixPairs]) : les clés
///   racine `<tâche><modelSuffix>` et `<tâche><fallbackSuffix>` deviennent
///   chacune une route ; l'hôte nomme ses suffixes et ses clés racine — le
///   socle n'en code aucune.
///
/// Dans les deux cas, une clé racine traduite par
/// [ZChatRouteCatalogShape.rootAliases] rejoint le schéma du routeur ; une clé
/// restée inconnue rejoint `extra` (hors clés de synchronisation réservées,
/// que `ZChatRouter.fromMap` retire).
library;

import 'package:zcrud_core/domain.dart';

import '../../z_chat_extension_parser.dart';
import '../z_chat_model_ref.dart';
import '../z_chat_route_spec.dart';
import '../z_chat_router.dart';

/// Forme d'un catalogue reçu : **une donnée** qui dit comment traduire les
/// clés d'un backend vers le schéma canonique du routeur.
///
/// Construire une forme, c'est nommer des clés — jamais écrire du code
/// d'adaptation. Les presets ([canonical], [lex]) et la fabrique
/// [suffixPairs] couvrent les dispositions connues ; une disposition inédite
/// se déclare avec le constructeur.
class ZChatRouteCatalogShape {
  /// Construit une forme.
  const ZChatRouteCatalogShape({
    this.envelopeKeys = const <String>['routers'],
    this.rootAliases = const <String, String>{},
    this.routeMapKeys = const <String>[],
    this.routeAliases = const <String, String>{},
    this.modelSuffix,
    this.fallbackSuffix,
    this.rootModelKey,
    this.rootFallbackKey,
    this.tierKey,
    this.providerKey,
  });

  /// Forme **canonique** : la forme écrite par `ZChatRouter.toMap`, avec une
  /// enveloppe `routers` tolérée autour de la liste.
  static const ZChatRouteCatalogShape canonical = ZChatRouteCatalogShape();

  /// Forme d'un backend qui expose ses routeurs sous une enveloppe `routers`,
  /// en clés **camelCase sur le fil et snake_case en base**, avec un objet
  /// `agentModels` par clé de tâche (`{provider, model, fallbackModels,
  /// temperature}`), des `pipelineParams` et un `workflowEffort`.
  ///
  /// Traduction : `agentModels[clé]` → route de `task_key = clé`, son
  /// `temperature` → `params` de la route ; `pipelineParams` → `params` du
  /// routeur ; `workflowEffort` → `tier` ; `isActive` → `is_active` ;
  /// `updatedAt`/`createdAt` → clés de synchronisation (retirées).
  static const ZChatRouteCatalogShape lex = ZChatRouteCatalogShape(
    rootAliases: <String, String>{
      'isActive': 'is_active',
      'workflowEffort': 'tier',
      'workflow_effort': 'tier',
      'pipelineParams': 'params',
      'pipeline_params': 'params',
      'updatedAt': ZSyncMeta.kUpdatedAt,
      'isDeleted': ZSyncMeta.kIsDeleted,
    },
    routeMapKeys: <String>['agentModels', 'agent_models'],
    routeAliases: <String, String>{
      'provider': 'model_provider_id',
      'model': 'model_id',
      'fallbackModels': 'fallbacks',
      'fallback_models': 'fallbacks',
    },
  );

  /// Forme d'un document qui déclare **une paire de clés par tâche** —
  /// `<tâche><modelSuffix>` (un jeton de modèle) et
  /// `<tâche><fallbackSuffix>` (une liste de jetons, ou un jeton seul).
  ///
  /// [rootModel] / [rootFallback] nomment les clés du modèle de référence et
  /// de ses replis ; [tierKey] celle du palier ; [providerKey] celle d'un
  /// fournisseur **appliqué à toute référence de modèle sans fournisseur**
  /// (racine, routes, replis). Les quatre sont optionnelles. Les autres clés
  /// racine passent par [rootAliases] puis rejoignent `extra`.
  factory ZChatRouteCatalogShape.suffixPairs({
    required String modelSuffix,
    required String fallbackSuffix,
    String? rootModel,
    String? rootFallback,
    String? tierKey,
    String? providerKey,
    List<String> envelopeKeys = const <String>['routers'],
    Map<String, String> rootAliases = const <String, String>{},
  }) => ZChatRouteCatalogShape(
    envelopeKeys: envelopeKeys,
    rootAliases: rootAliases,
    modelSuffix: modelSuffix,
    fallbackSuffix: fallbackSuffix,
    rootModelKey: rootModel,
    rootFallbackKey: rootFallback,
    tierKey: tierKey,
    providerKey: providerKey,
  );

  /// Clés d'enveloppe acceptées autour d'une liste (`{routers: [...]}`).
  final List<String> envelopeKeys;

  /// Traduction des clés **racine** : clé reçue → clé canonique.
  final Map<String, String> rootAliases;

  /// Clés racine portant un objet `{clé de tâche: {…}}` de routes.
  final List<String> routeMapKeys;

  /// Traduction des clés **d'une entrée de route** : clé reçue → clé
  /// canonique (`model_provider_id`, `model_id`, `fallbacks`, …).
  final Map<String, String> routeAliases;

  /// Suffixe des clés racine portant le modèle d'une tâche, ou `null`.
  final String? modelSuffix;

  /// Suffixe des clés racine portant les replis d'une tâche, ou `null`.
  final String? fallbackSuffix;

  /// Clé racine du modèle de référence, ou `null`.
  final String? rootModelKey;

  /// Clé racine des replis de référence, ou `null`.
  final String? rootFallbackKey;

  /// Clé racine du palier (`tier`), ou `null`.
  final String? tierKey;

  /// Clé racine d'un fournisseur appliqué aux références sans fournisseur,
  /// ou `null`.
  final String? providerKey;

  /// `true` si la forme déclare des paires à suffixe.
  bool get hasSuffixPairs =>
      modelSuffix != null &&
      modelSuffix!.isNotEmpty &&
      fallbackSuffix != null &&
      fallbackSuffix!.isNotEmpty;
}

/// Un élément du catalogue **refusé** par le décodeur, avec sa position et
/// la raison.
class ZChatRouteCatalogRejection {
  /// Construit le rejet.
  const ZChatRouteCatalogRejection({
    required this.index,
    required this.reason,
    this.raw,
  });

  /// Position de l'élément dans la liste reçue.
  final int index;

  /// Raison technique (`notAMap`, `missingId`, `threw`).
  final String reason;

  /// L'élément tel que reçu, pour le journal de l'hôte.
  final Object? raw;

  @override
  String toString() => 'ZChatRouteCatalogRejection(#$index: $reason)';
}

/// Résultat d'un décodage : les routeurs lus et les éléments refusés.
class ZChatRouteCatalogDecodeReport {
  /// Construit le rapport.
  ZChatRouteCatalogDecodeReport({
    required List<ZChatRouter> routers,
    required List<ZChatRouteCatalogRejection> rejected,
  }) : routers = List<ZChatRouter>.unmodifiable(routers),
       rejected = List<ZChatRouteCatalogRejection>.unmodifiable(rejected);

  /// Routeurs lus, actifs ou non, dans l'ordre reçu.
  final List<ZChatRouter> routers;

  /// Éléments refusés — jamais silencieux.
  final List<ZChatRouteCatalogRejection> rejected;

  /// Le routeur d'identité [id], ou `null`.
  ZChatRouter? byId(String id) {
    for (final ZChatRouter r in routers) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// Décodeur d'un catalogue reçu, paramétré par une [ZChatRouteCatalogShape].
///
/// **Ne lève jamais** (AD-10) : toute forme reçue produit un rapport.
class ZChatRouteCatalogDecoder {
  /// Construit le décodeur. [extensionParser] décode le slot `extension`
  /// d'un hôte, comme pour `ZChatRouter.fromMap`.
  const ZChatRouteCatalogDecoder({
    this.shape = ZChatRouteCatalogShape.canonical,
    this.extensionParser,
  });

  /// La forme attendue.
  final ZChatRouteCatalogShape shape;

  /// Décodeur du slot `extension`, ou `null` (extension conservée opaque).
  final ZChatExtensionParser? extensionParser;

  /// Clés canoniques d'une route : tout le reste rejoint ses `params`.
  static final Set<String> _routeKeys = <String>{
    for (final ZFieldSpec s in $ZChatRouteSpecFieldSpecs) s.name,
    'model',
    'params',
  };

  /// Décode une **liste** reçue : une liste nue, une enveloppe
  /// (`{routers: [...]}`) ou un **seul** routeur (map sans enveloppe).
  /// `null` ou une forme méconnaissable donnent un rapport vide.
  ///
  /// [fallbackId] est l'identité **supposée** d'un élément qui n'en porte
  /// pas — celle qu'on a demandée à un backend qui répond par l'objet seul.
  /// Sans lui, un élément sans identité est rejeté (`missingId`).
  ZChatRouteCatalogDecodeReport decodeList(Object? raw, {String? fallbackId}) {
    final List<Object?> items = _items(raw);
    final List<ZChatRouter> routers = <ZChatRouter>[];
    final List<ZChatRouteCatalogRejection> rejected =
        <ZChatRouteCatalogRejection>[];
    for (int i = 0; i < items.length; i++) {
      final Object? item = items[i];
      final ZChatRouter? router;
      try {
        final Map<String, dynamic>? map = zJsonMap(item);
        if (map == null) {
          rejected.add(
            ZChatRouteCatalogRejection(index: i, reason: 'notAMap', raw: item),
          );
          continue;
        }
        router = decodeRouter(map, fallbackId: fallbackId);
      } on Object {
        rejected.add(
          ZChatRouteCatalogRejection(index: i, reason: 'threw', raw: item),
        );
        continue;
      }
      if (router == null) {
        rejected.add(
          ZChatRouteCatalogRejection(index: i, reason: 'missingId', raw: item),
        );
        continue;
      }
      routers.add(router);
    }
    return ZChatRouteCatalogDecodeReport(routers: routers, rejected: rejected);
  }

  /// Décode **un** routeur reçu, ou `null` s'il n'a pas d'identité lisible.
  ///
  /// Peut lever si une valeur reçue est d'un type inattendu au point de
  /// casser la normalisation ; [decodeList] l'absorbe en rejet.
  ZChatRouter? decodeRouter(Map<String, dynamic> raw, {String? fallbackId}) {
    final ZChatRouter router = ZChatRouter.fromMap(
      normalize(raw),
      extensionParser: extensionParser,
    );
    final String? id = _blank(router.id);
    if (id != null) return router;
    final String? assumed = _blank(fallbackId);
    if (assumed == null) return null;
    return router.copyWith(id: assumed);
  }

  /// Traduit une map reçue vers la forme canonique de `ZChatRouter.fromMap`,
  /// selon [shape]. Pure : [raw] n'est jamais mutée.
  Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    final Map<String, dynamic> out = <String, dynamic>{};
    final Map<String, Map<String, dynamic>> derived =
        <String, Map<String, dynamic>>{};
    final List<Object?> listedRoutes = <Object?>[];
    String? provider;
    if (shape.providerKey != null) {
      provider = _blank(zJsonStringOrNull(raw[shape.providerKey!]));
    }

    for (final MapEntry<String, dynamic> e in raw.entries) {
      final String key = e.key;
      final Object? value = e.value;

      if (key == shape.providerKey) continue;
      if (shape.routeMapKeys.contains(key)) {
        final Map<String, dynamic>? byTask = zJsonMap(value);
        if (byTask == null) continue;
        for (final MapEntry<String, dynamic> t in byTask.entries) {
          final Map<String, dynamic>? body = zJsonMap(t.value);
          if (body == null) continue;
          _mergeRoute(derived, t.key, _normalizeRouteEntry(body, provider));
        }
        continue;
      }
      if (key == 'routes') {
        if (value is List) {
          for (final Object? item in value) {
            final Map<String, dynamic>? body = zJsonMap(item);
            listedRoutes.add(
              body == null ? item : _normalizeRouteEntry(body, provider),
            );
          }
        } else if (zJsonMap(value) case final Map<String, dynamic> asObject) {
          for (final MapEntry<String, dynamic> t in asObject.entries) {
            if (zJsonMap(t.value) case final Map<String, dynamic> body) {
              listedRoutes.add(<String, dynamic>{
                ..._normalizeRouteEntry(body, provider),
                'task_key': t.key,
              });
            }
          }
        }
        continue;
      }
      if (shape.hasSuffixPairs) {
        if (key == shape.rootModelKey) {
          out['model'] = value;
          continue;
        }
        if (key == shape.rootFallbackKey) {
          out['fallbacks'] = _fallbackList(value, provider);
          continue;
        }
        if (key == shape.tierKey) {
          out['tier'] = zJsonStringOrNull(value);
          continue;
        }
        final String fs = shape.fallbackSuffix!;
        final String ms = shape.modelSuffix!;
        if (key.endsWith(fs) && key.length > fs.length) {
          final String task = key.substring(0, key.length - fs.length);
          _mergeRoute(derived, task, <String, dynamic>{
            'fallbacks': _fallbackList(value, provider),
          });
          continue;
        }
        if (key.endsWith(ms) && key.length > ms.length) {
          final String task = key.substring(0, key.length - ms.length);
          if (ZChatModelRef.fromJson(value) != null) {
            _mergeRoute(derived, task, <String, dynamic>{'model': value});
          }
          continue;
        }
      }
      final String canonical = shape.rootAliases[key] ?? key;
      if (canonical == 'fallbacks') {
        out[canonical] = _fallbackList(value, provider);
      } else if (canonical == 'params') {
        out[canonical] = <String, dynamic>{
          ...?zJsonMap(out[canonical]),
          ...?zJsonMap(value),
        };
      } else {
        out[canonical] = value;
      }
    }

    _flattenModel(out, provider);
    if (listedRoutes.isNotEmpty || derived.isNotEmpty) {
      out['routes'] = <Object?>[
        ...listedRoutes,
        for (final MapEntry<String, Map<String, dynamic>> d in derived.entries)
          _derivedRoute(d.key, d.value, provider),
      ];
    }
    return out;
  }

  /// Traduit une entrée de route : alias, replis en liste, clés inconnues
  /// dans `params`.
  Map<String, dynamic> _normalizeRouteEntry(
    Map<String, dynamic> body,
    String? provider,
  ) {
    final Map<String, dynamic> out = <String, dynamic>{};
    final Map<String, dynamic> params = <String, dynamic>{};
    for (final MapEntry<String, dynamic> e in body.entries) {
      final String key = shape.routeAliases[e.key] ?? e.key;
      if (key == 'fallbacks') {
        out[key] = _fallbackList(e.value, provider);
      } else if (key == 'params') {
        params.addAll(zJsonMap(e.value) ?? const <String, dynamic>{});
      } else if (_routeKeys.contains(key)) {
        out[key] = e.value;
      } else {
        params[key] = e.value;
      }
    }
    _flattenModel(out, provider);
    if (params.isNotEmpty) out['params'] = params;
    return out;
  }

  /// Écrit la référence de modèle **à plat** (`model_provider_id`,
  /// `model_id`), quelle que soit la disposition reçue, en la complétant
  /// par [provider] si elle n'en porte pas — c'est le **seul** endroit où le
  /// fournisseur de la forme est appliqué à un modèle (les replis passent
  /// par la liste). Une clé `model` ne survit pas : elle rejoindrait `extra`
  /// sans cela.
  static void _flattenModel(Map<String, dynamic> out, String? provider) {
    final ZChatModelRef? read = ZChatModelRef.readEmbedded(out);
    out.remove('model');
    if (read == null) return;
    out.remove('model_provider_id');
    out.remove('model_id');
    final ZChatModelRef ref = read.providerId == null && provider != null
        ? ZChatModelRef(providerId: provider, modelId: read.modelId)
        : read;
    ZChatModelRef.writeEmbedded(out, ref);
  }

  /// Une route dérivée (objet de routes ou paires à suffixe), modèle à plat.
  static Map<String, dynamic> _derivedRoute(
    String task,
    Map<String, dynamic> body,
    String? provider,
  ) {
    final Map<String, dynamic> out = <String, dynamic>{
      ...body,
      'task_key': task,
    };
    _flattenModel(out, provider);
    return out;
  }

  static void _mergeRoute(
    Map<String, Map<String, dynamic>> derived,
    String task,
    Map<String, dynamic> body,
  ) {
    final String key = task.trim();
    if (key.isEmpty) return;
    derived[key] = <String, dynamic>{...?derived[key], ...body};
  }

  /// Une liste de replis : liste reçue telle quelle, ou un jeton seul
  /// enveloppé en liste.
  static List<Object?> _fallbackList(Object? value, String? provider) {
    final List<Object?> list = value is List
        ? List<Object?>.of(value)
        : value is String
        ? <Object?>[value]
        : const <Object?>[];
    if (provider == null) return list;
    return <Object?>[for (final Object? v in list) _withProvider(v, provider)];
  }

  /// Complète une référence de modèle sans fournisseur par [provider].
  static Object? _withProvider(Object? value, String? provider) {
    if (provider == null) return value;
    final ZChatModelRef? ref = ZChatModelRef.fromJson(value);
    if (ref == null) return value;
    if (ref.providerId != null) return ref.toJson();
    return ZChatModelRef(providerId: provider, modelId: ref.modelId).toJson();
  }

  List<Object?> _items(Object? raw) {
    if (raw is List) return raw;
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return const <Object?>[];
    for (final String key in shape.envelopeKeys) {
      final Object? inner = map[key];
      if (inner is List) return inner;
    }
    return <Object?>[map];
  }

  static String? _blank(String? s) {
    if (s == null) return null;
    final String t = s.trim();
    return t.isEmpty ? null : t;
  }
}
