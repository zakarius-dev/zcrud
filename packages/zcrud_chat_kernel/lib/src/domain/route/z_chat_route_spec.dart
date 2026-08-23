/// Route d'un routeur — `ZChatRouteSpec` (invariants AD-4, AD-10, AD-12).
///
/// Une route décrit **ce qu'un routeur déclare pour une tâche** : le modèle,
/// ses replis, le budget de calcul, des paramètres verbatim, les jetons
/// d'accès requis et, le cas échéant, l'identité du gestionnaire qui exécute
/// la requête. La clé de tâche est le `kind` d'un style de génération
/// (`ZChatGenerationStyle.kind`) : ouverte, jamais cataloguée par le socle.
///
/// Ce fichier porte aussi le **sous-schéma d'édition** de la route
/// ([$ZChatRouteSpecFieldSpecs]) : c'est lui qu'un formulaire zcrud rend pour
/// chaque item de la sous-liste `routes` d'un routeur.
library;

import 'package:zcrud_core/domain.dart';

import '../ai/z_chat_compute_effort.dart';
import 'z_chat_model_ref.dart';

/// Déclaration d'une **route** pour une clé de tâche.
class ZChatRouteSpec {
  /// Construit une route. [requiredAccessTokens] est dédupliqué et trié ;
  /// [params] est conservé verbatim, hors clés de synchronisation réservées.
  ZChatRouteSpec({
    required this.taskKey,
    this.routeName,
    this.model,
    List<ZChatModelRef> fallbacks = const <ZChatModelRef>[],
    this.computeEffort,
    Map<String, dynamic> params = const <String, dynamic>{},
    List<String> requiredAccessTokens = const <String>[],
    this.handlerId,
  }) : fallbacks = List<ZChatModelRef>.unmodifiable(fallbacks),
       params = zSanitizeExtra(params, ZSyncMeta.reservedKeys),
       requiredAccessTokens = List<String>.unmodifiable(
         normalizeAccessTokens(requiredAccessTokens),
       );

  /// Lecture **défensive** (AD-10) : `null` si [raw] n'est pas une map ou si
  /// `task_key` est absent/vide — jamais d'exception. Un repli illisible est
  /// sauté, un budget de calcul illisible vaut `null`.
  static ZChatRouteSpec? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String taskKey = zJsonString(map['task_key']).trim();
    if (taskKey.isEmpty) return null;
    return ZChatRouteSpec(
      taskKey: taskKey,
      routeName: zJsonStringOrNull(map['route_name']),
      model: ZChatModelRef.readEmbedded(map),
      fallbacks:
          zJsonDecodeList<ZChatModelRef>(
            map['fallbacks'],
            ZChatModelRef.fromJson,
          ) ??
          const <ZChatModelRef>[],
      computeEffort: ZChatComputeEffort.fromJson(map['compute_effort']),
      params: zJsonMap(map['params']) ?? const <String, dynamic>{},
      requiredAccessTokens:
          zJsonStringList(map['required_access_tokens']) ?? const <String>[],
      handlerId: zJsonStringOrNull(map['handler_id']),
    );
  }

  /// Clé de tâche (`ZChatGenerationStyle.kind`), jamais vide.
  final String taskKey;

  /// Nom de route **opaque** côté transport, ou `null`.
  final String? routeName;

  /// Modèle de la route, ou `null` (repli sur celui du routeur).
  final ZChatModelRef? model;

  /// Replis ordonnés du [model] — solidaires de lui à la résolution.
  final List<ZChatModelRef> fallbacks;

  /// Budget de calcul de la route, ou `null` (repli sur celui du routeur).
  final ZChatComputeEffort? computeEffort;

  /// Paramètres **verbatim** de la route, non modifiables. Ils rejoignent
  /// `ZChatGenerationRequest.extra` à la résolution, sous les clés de l'hôte.
  final Map<String, dynamic> params;

  /// Jetons d'accès **opaques** exigés pour emprunter la route (dédupliqués,
  /// triés). C'est la donnée qu'un `ZChatRouteGate` confronte au plan.
  final List<String> requiredAccessTokens;

  /// Identité **opaque** du gestionnaire qui exécute la route, ou `null`.
  final String? handlerId;

  /// Dédoublonne, rogne et trie des jetons d'accès (les vides sont écartés).
  static List<String> normalizeAccessTokens(Iterable<String> tokens) {
    final Set<String> out = <String>{};
    for (final String t in tokens) {
      final String trimmed = t.trim();
      if (trimmed.isNotEmpty) out.add(trimmed);
    }
    return out.toList()..sort();
  }

  /// Forme persistée (clés snake_case) : les valeurs vides sont omises, le
  /// modèle est écrit à plat (`model_provider_id`, `model_id`), les replis en
  /// forme compacte.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{'task_key': taskKey};
    if (routeName != null) out['route_name'] = routeName;
    ZChatModelRef.writeEmbedded(out, model);
    if (fallbacks.isNotEmpty) {
      out['fallbacks'] = <Object>[
        for (final ZChatModelRef f in fallbacks) f.toCompactJson(),
      ];
    }
    if (computeEffort != null) out['compute_effort'] = computeEffort!.toJson();
    if (params.isNotEmpty) out['params'] = params;
    if (requiredAccessTokens.isNotEmpty) {
      out['required_access_tokens'] = requiredAccessTokens;
    }
    if (handlerId != null) out['handler_id'] = handlerId;
    return out;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatRouteSpec &&
          taskKey == other.taskKey &&
          routeName == other.routeName &&
          model == other.model &&
          zListEquals(fallbacks, other.fallbacks) &&
          computeEffort == other.computeEffort &&
          zJsonEquals(params, other.params) &&
          zListEquals(requiredAccessTokens, other.requiredAccessTokens) &&
          handlerId == other.handlerId;

  @override
  int get hashCode => Object.hash(
    taskKey,
    routeName,
    model,
    zListHash(fallbacks),
    computeEffort,
    zJsonHash(params),
    zListHash(requiredAccessTokens),
    handlerId,
  );

  @override
  String toString() => 'ZChatRouteSpec($taskKey, model: $model)';
}

/// Sous-schéma d'édition d'une route — items de la sous-liste `routes` d'un
/// routeur. Aucun libellé : les textes viennent de l'hôte.
///
/// Les replis s'éditent comme une liste de jetons `fournisseur:modèle`
/// (lecture tolérante par [ZChatModelRef.fromJson]). Les `params` ne sont
/// pas un champ : ils sont conservés tels quels par le sous-formulaire.
const List<ZFieldSpec> $ZChatRouteSpecFieldSpecs = <ZFieldSpec>[
  ZFieldSpec(
    name: 'task_key',
    type: EditionFieldType.text,
    validators: <ZValidatorSpec>[ZValidatorSpec.required()],
  ),
  ZFieldSpec(name: 'route_name', type: EditionFieldType.text),
  ZFieldSpec(name: 'model_provider_id', type: EditionFieldType.text),
  ZFieldSpec(name: 'model_id', type: EditionFieldType.text),
  ZFieldSpec(name: 'fallbacks', type: EditionFieldType.tags, multiple: true),
  ZFieldSpec(
    name: 'compute_effort',
    type: EditionFieldType.integer,
    validators: <ZValidatorSpec>[
      ZValidatorSpec.min(ZChatComputeEffort.min),
      ZValidatorSpec.max(ZChatComputeEffort.max),
    ],
  ),
  ZFieldSpec(
    name: 'required_access_tokens',
    type: EditionFieldType.tags,
    multiple: true,
  ),
  ZFieldSpec(name: 'handler_id', type: EditionFieldType.text),
];
