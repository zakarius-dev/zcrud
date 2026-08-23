/// Routeur IA — `ZChatRouter` (invariants AD-4, AD-9, AD-10, AD-12).
///
/// Un routeur est l'entité qui déclare, **par tâche**, le fournisseur, le
/// modèle, ses replis et les paramètres d'une génération — et, à sa racine,
/// les valeurs sur lesquelles une tâche non déclarée se replie. Il porte le
/// palier de gouvernance ([ZChatRouter.tier], opaque) et un drapeau
/// d'activation. Entité `ZEntity` **extensible** : un hôte y loge ses
/// spécificités par [ZChatRouter.extension] ou [ZChatRouter.extra], jamais en
/// étendant le schéma partagé.
///
/// ## Persistance
///
/// (Dé)sérialisation **écrite à la main**, défensive (AD-10) : aucune forme
/// reçue ne lève, pas même `ZChatRouter.fromMap(const {})`. Les routes sont
/// persistées en **liste** (`routes: [{task_key, …}]`) ; une forme objet
/// `{clé: {…}}` est tolérée en lecture, la clé d'objet devenant `task_key`.
/// Une route illisible est sautée, jamais le routeur.
///
/// `updated_at` et `is_deleted` appartiennent à `ZSyncMeta` (AD-9) :
/// [ZChatRouter.toMap] ne les émet **jamais**, et [ZChatRouter.extra] comme
/// [ZChatRouter.params] ne peuvent pas les porter.
///
/// ## Édition
///
/// [$ZChatRouterFieldSpecs] est le schéma d'édition complet du routeur ; les
/// routes s'y éditent comme une sous-liste d'items décrits par
/// [$ZChatRouteSpecFieldSpecs]. [registerZChatRouter] câble le codec et ce
/// schéma sur un `ZcrudRegistry` : un écran CRUD zcrud rend alors le
/// formulaire sans code d'hôte.
///
/// ```dart
/// final registry = ZcrudRegistry();
/// registerZChatRouter(registry);
/// final ZChatRouter router = ZChatRouter.fromMap(persisted);
/// ```
library;

import 'package:zcrud_core/domain.dart';

import '../ai/z_chat_compute_effort.dart';
import '../z_chat_extension_parser.dart';
import 'z_chat_model_ref.dart';
import 'z_chat_route_spec.dart';

/// `kind` sous lequel [registerZChatRouter] enregistre le routeur par défaut.
const String kZChatRouterKind = 'chat_router';

/// Sentinelle de `copyWith` : distingue « argument omis » de « remis à `null` ».
const Object _unset = Object();

/// Un routeur IA — entité canonique **extensible**.
class ZChatRouter extends ZEntity with ZExtensible {
  /// Construit un routeur (primitif `const`).
  ///
  /// **Aucun `assert`** (AD-10) et **aucun filtrage** possible : le
  /// constructeur est `const`. Ce sont les **accesseurs** [extra] et [params]
  /// qui portent la garde ; [routes] est lue telle quelle.
  const ZChatRouter({
    this.id,
    this.name,
    this.description,
    this.isActive = true,
    this.tier,
    this.model,
    this.fallbacks = const <ZChatModelRef>[],
    this.computeEffort,
    this.routes = const <String, ZChatRouteSpec>{},
    Map<String, dynamic> params = const <String, dynamic>{},
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _params = params,
       // ignore: prefer_initializing_formals
       _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10) — aucun
  /// cas ne lève.
  ///
  /// `routes` est lue en liste ; une forme objet `{clé: {…}}` est acceptée,
  /// la clé d'objet devenant `task_key`. Deux routes de même clé : la
  /// **dernière** déclarée gagne. Un item illisible est sauté.
  factory ZChatRouter.fromMap(
    Map<String, dynamic> map, {
    ZChatExtensionParser? extensionParser,
  }) => ZChatRouter(
    id: zJsonStringOrNull(map['id']),
    name: zJsonStringOrNull(map['name']),
    description: zJsonStringOrNull(map['description']),
    isActive: zJsonBool(map['is_active'], true),
    tier: zJsonStringOrNull(map['tier']),
    model: ZChatModelRef.readEmbedded(map),
    fallbacks:
        zJsonDecodeList<ZChatModelRef>(
          map['fallbacks'],
          ZChatModelRef.fromJson,
        ) ??
        const <ZChatModelRef>[],
    computeEffort: ZChatComputeEffort.fromJson(map['compute_effort']),
    routes: _readRoutes(map['routes']),
    params: zSanitizeExtra(
      zJsonMap(map['params']) ?? const <String, dynamic>{},
      ZSyncMeta.reservedKeys,
    ),
    extension: zDecodeExtension(map['extension'], extensionParser),
    // Normalisation EAGER à l'entrée.
    extra: zSanitizeExtra(map, _reservedKeys),
  );

  /// Identité opaque, `null` si le routeur est éphémère.
  @override
  final String? id;

  /// Nom **technique** du routeur, ou `null` (aucun libellé : l'hôte nomme).
  final String? name;

  /// Description technique, ou `null`.
  final String? description;

  /// `false` ⇒ le routeur n'est ni listé ni résolu par un catalogue.
  final bool isActive;

  /// Palier de gouvernance **opaque** (plan, niveau d'abonnement…), ou
  /// `null`. Transporté verbatim vers `ZChatRouteGate.canRoute`, jamais
  /// interprété par le socle.
  final String? tier;

  /// Modèle de référence du routeur, ou `null`.
  final ZChatModelRef? model;

  /// Replis ordonnés du [model] de référence.
  final List<ZChatModelRef> fallbacks;

  /// Budget de calcul de référence, ou `null`.
  final ZChatComputeEffort? computeEffort;

  /// Routes par clé de tâche. Une tâche absente se replie sur la racine.
  final Map<String, ZChatRouteSpec> routes;

  /// Paramètres **verbatim** de la racine, normalisés à la lecture (jamais
  /// une clé de synchronisation réservée).
  Map<String, dynamic> get params =>
      zNormalizeExtra(_params, ZSyncMeta.reservedKeys);

  /// Slot `params` **BRUT** tel que reçu par le constructeur.
  final Map<String, dynamic> _params;

  /// Slot type additif **versionné** (invariant AD-4, mécanisme 1).
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (invariant AD-4, mécanisme 2) — l'accesseur
  /// **normalise**.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Slot `extra` **BRUT** tel que reçu par le constructeur.
  final Map<String, dynamic> _extra;

  /// Clés persistées **réservées** : schéma ∪ `extension` ∪ `params` ∪
  /// **`ZSyncMeta.reservedKeys`** (invariant AD-9).
  static final Set<String> _reservedKeys = <String>{
    for (final ZFieldSpec s in $ZChatRouterFieldSpecs) s.name,
    'extension',
    'params',
    ...ZSyncMeta.reservedKeys,
  };

  /// Route déclarée pour [taskKey], ou `null`.
  ZChatRouteSpec? routeOf(String taskKey) => routes[taskKey];

  /// Sérialise vers la map persistée (clés snake_case), [extra] étalé
  /// d'abord, routes en **liste**, replis en **liste de maps**
  /// `{provider_id?, model_id}` ([ZChatModelRef.toJson]).
  ///
  /// **N'émet NI `updated_at` NI `is_deleted`** — sans exception.
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> out = <String, dynamic>{...extra};
    if (id != null) out['id'] = id;
    if (name != null) out['name'] = name;
    if (description != null) out['description'] = description;
    out['is_active'] = isActive;
    if (tier != null) out['tier'] = tier;
    ZChatModelRef.writeEmbedded(out, model);
    if (fallbacks.isNotEmpty) {
      out['fallbacks'] = <Map<String, dynamic>>[
        for (final ZChatModelRef f in fallbacks) f.toJson(),
      ];
    }
    if (computeEffort != null) out['compute_effort'] = computeEffort!.toJson();
    if (routes.isNotEmpty) {
      out['routes'] = <Map<String, dynamic>>[
        for (final ZChatRouteSpec r in routes.values) r.toJson(),
      ];
    }
    final Map<String, dynamic> p = params;
    if (p.isNotEmpty) out['params'] = p;
    if (extension != null) out['extension'] = extension!.toJson();
    return out;
  }

  /// Copie **à sentinelle** — un argument omis conserve la valeur, `null`
  /// explicite la remet à `null`. `extra` et `params` sont **sanitisés
  /// eager** ; `routes` est re-clé par `taskKey`.
  ZChatRouter copyWith({
    Object? id = _unset,
    Object? name = _unset,
    Object? description = _unset,
    Object? isActive = _unset,
    Object? tier = _unset,
    Object? model = _unset,
    Object? fallbacks = _unset,
    Object? computeEffort = _unset,
    Object? routes = _unset,
    Object? params = _unset,
    Object? extension = _unset,
    Object? extra = _unset,
  }) => ZChatRouter(
    id: identical(id, _unset) ? this.id : id as String?,
    name: identical(name, _unset) ? this.name : name as String?,
    description: identical(description, _unset)
        ? this.description
        : description as String?,
    isActive: identical(isActive, _unset) ? this.isActive : isActive as bool,
    tier: identical(tier, _unset) ? this.tier : tier as String?,
    model: identical(model, _unset) ? this.model : model as ZChatModelRef?,
    fallbacks: identical(fallbacks, _unset)
        ? this.fallbacks
        : List<ZChatModelRef>.unmodifiable(fallbacks as List<ZChatModelRef>),
    computeEffort: identical(computeEffort, _unset)
        ? this.computeEffort
        : computeEffort as ZChatComputeEffort?,
    routes: identical(routes, _unset)
        ? this.routes
        : indexRoutes(routes as Iterable<ZChatRouteSpec>),
    params: identical(params, _unset)
        ? this.params
        : zSanitizeExtra(
            params as Map<String, dynamic>,
            ZSyncMeta.reservedKeys,
          ),
    extension: identical(extension, _unset)
        ? this.extension
        : extension as ZExtension?,
    extra: identical(extra, _unset)
        ? this.extra
        : zSanitizeExtra(extra as Map<String, dynamic>, _reservedKeys),
  );

  /// Indexe des routes par clé de tâche — la **dernière** déclaration gagne.
  static Map<String, ZChatRouteSpec> indexRoutes(
    Iterable<ZChatRouteSpec> routes,
  ) => Map<String, ZChatRouteSpec>.unmodifiable(<String, ZChatRouteSpec>{
    for (final ZChatRouteSpec r in routes) r.taskKey: r,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatRouter &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          isActive == other.isActive &&
          tier == other.tier &&
          model == other.model &&
          zListEquals(fallbacks, other.fallbacks) &&
          computeEffort == other.computeEffort &&
          _routesEqual(routes, other.routes) &&
          zJsonEquals(params, other.params) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    isActive,
    tier,
    model,
    zListHash(fallbacks),
    computeEffort,
    Object.hashAllUnordered(routes.values),
    zJsonHash(params),
    extension,
    zJsonHash(extra),
  );

  @override
  String toString() =>
      'ZChatRouter(id: $id, tier: $tier, routes: ${routes.keys.toList()})';
}

/// Lit `routes` en liste, ou en objet `{clé: {…}}` dont la clé devient
/// `task_key`. Tout item illisible est sauté.
Map<String, ZChatRouteSpec> _readRoutes(Object? raw) {
  final List<ZChatRouteSpec> decoded;
  if (raw is List) {
    decoded =
        zJsonDecodeList<ZChatRouteSpec>(raw, ZChatRouteSpec.fromJson) ??
        const <ZChatRouteSpec>[];
  } else {
    final Map<String, dynamic>? asMap = zJsonMap(raw);
    if (asMap == null) return const <String, ZChatRouteSpec>{};
    decoded = <ZChatRouteSpec>[
      for (final MapEntry<String, dynamic> e in asMap.entries)
        if (zJsonMap(e.value) case final Map<String, dynamic> body)
          if (ZChatRouteSpec.fromJson(<String, dynamic>{
                ...body,
                'task_key': e.key,
              })
              case final ZChatRouteSpec r)
            r,
    ];
  }
  return ZChatRouter.indexRoutes(decoded);
}

bool _routesEqual(
  Map<String, ZChatRouteSpec> a,
  Map<String, ZChatRouteSpec> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final MapEntry<String, ZChatRouteSpec> e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

/// Schéma d'édition **complet** du routeur — consommé par le moteur
/// d'édition et le moteur de liste via [registerZChatRouter]. Aucun libellé.
///
/// Les routes s'éditent en sous-liste (`subItems`) d'items décrits par
/// [$ZChatRouteSpecFieldSpecs] ; le résumé d'un item montre sa clé de tâche,
/// son modèle et le **compte** de ses replis. Les replis — de la racine comme
/// d'une route — s'éditent en sous-liste d'items décrits par
/// [$ZChatModelRefFieldSpecs]. `params`, `extension` et `extra` ne sont pas
/// des champs : ils traversent l'édition tels quels.
const List<ZFieldSpec> $ZChatRouterFieldSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'description', type: EditionFieldType.multiline),
  ZFieldSpec(
    name: 'is_active',
    type: EditionFieldType.boolean,
    defaultValue: true,
  ),
  ZFieldSpec(name: 'tier', type: EditionFieldType.text),
  ZFieldSpec(name: 'model_provider_id', type: EditionFieldType.text),
  ZFieldSpec(name: 'model_id', type: EditionFieldType.text),
  ZFieldSpec(
    name: 'fallbacks',
    type: EditionFieldType.subItems,
    multiple: true,
    config: ZSubListConfig(
      itemFields: $ZChatModelRefFieldSpecs,
      summaryFields: <String>['provider_id', 'model_id'],
    ),
  ),
  ZFieldSpec(
    name: 'compute_effort',
    type: EditionFieldType.integer,
    validators: <ZValidatorSpec>[
      ZValidatorSpec.min(ZChatComputeEffort.min),
      ZValidatorSpec.max(ZChatComputeEffort.max),
    ],
  ),
  ZFieldSpec(
    name: 'routes',
    type: EditionFieldType.subItems,
    multiple: true,
    config: ZSubListConfig(
      itemFields: $ZChatRouteSpecFieldSpecs,
      summaryFields: <String>['task_key', 'model_id', 'fallbacks'],
    ),
  ),
];

/// Enregistre le codec **et** le schéma du routeur sur [registry], sous
/// [kind] (défaut [kZChatRouterKind]).
///
/// [extensionParser] décode le slot `extension` d'un hôte ; sans lui, une
/// extension persistée est conservée opaque.
void registerZChatRouter(
  ZcrudRegistry registry, {
  String kind = kZChatRouterKind,
  ZChatExtensionParser? extensionParser,
}) {
  registry.register<ZChatRouter>(
    kind,
    fromMap: (Map<String, dynamic> map) =>
        ZChatRouter.fromMap(map, extensionParser: extensionParser),
    toMap: (ZChatRouter router) => router.toMap(),
    fieldSpecs: $ZChatRouterFieldSpecs,
  );
}
