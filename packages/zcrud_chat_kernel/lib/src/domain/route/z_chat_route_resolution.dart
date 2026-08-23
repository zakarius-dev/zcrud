/// Résolution d'une route — `ZChatRouteResolution` (invariants AD-10, AD-12).
///
/// La résolution est la **couche pure** entre un routeur et la requête
/// envoyée à un port : pour une clé de tâche, elle calcule ce que le routeur
/// déclare (route, sinon racine), puis projette ce résultat sur une
/// `ZChatGenerationRequest` de base sans jamais écraser un choix explicite
/// de l'appelant. Aucun membre n'envoie quoi que ce soit.
///
/// ## Règles de repli
///
/// - le couple **(modèle, replis)** est pris **ensemble** : celui de la route
///   dès qu'elle en déclare un élément, celui de la racine sinon — un modèle
///   de route n'hérite jamais des replis de la racine, et inversement ;
/// - le budget de calcul : route, sinon racine ;
/// - les paramètres : racine **puis** route (la route prime clé par clé) ;
/// - nom de route, gestionnaire et jetons d'accès : ceux de la route seule.
library;

import '../ai/z_chat_compute_effort.dart';
import '../ai/z_chat_generation_port.dart';
import '../ai/z_chat_generation_settings.dart';
import 'z_chat_model_ref.dart';
import 'z_chat_route_spec.dart';
import 'z_chat_router.dart';

/// Ce qu'un routeur déclare pour une clé de tâche, replis appliqués.
class ZChatRouteResolution {
  const ZChatRouteResolution._({
    required this.taskKey,
    required this.routerId,
    required this.declared,
    required this.tier,
    required this.routeName,
    required this.handlerId,
    required this.model,
    required this.fallbacks,
    required this.computeEffort,
    required this.params,
    required this.requiredAccessTokens,
  });

  /// Résout [taskKey] sur [router] (voir les règles de repli du fichier).
  factory ZChatRouteResolution.from(ZChatRouter router, String taskKey) {
    final ZChatRouteSpec? route = router.routeOf(taskKey);
    final bool routeOwnsModels =
        route != null && (route.model != null || route.fallbacks.isNotEmpty);
    return ZChatRouteResolution._(
      taskKey: taskKey,
      routerId: router.id,
      declared: route != null,
      tier: router.tier,
      routeName: route?.routeName,
      handlerId: route?.handlerId,
      model: routeOwnsModels ? route.model : router.model,
      fallbacks: routeOwnsModels ? route.fallbacks : router.fallbacks,
      computeEffort: route?.computeEffort ?? router.computeEffort,
      params: Map<String, dynamic>.unmodifiable(<String, dynamic>{
        ...router.params,
        ...?route?.params,
      }),
      requiredAccessTokens: route?.requiredAccessTokens ?? const <String>[],
    );
  }

  /// Clé de tâche résolue.
  final String taskKey;

  /// Identité du routeur, ou `null` s'il est éphémère.
  final String? routerId;

  /// `true` si le routeur déclare une route pour [taskKey] ; `false` si tout
  /// vient de la racine.
  final bool declared;

  /// Palier de gouvernance du routeur (opaque), ou `null`.
  final String? tier;

  /// Nom de route opaque, ou `null`.
  final String? routeName;

  /// Gestionnaire opaque, ou `null`.
  final String? handlerId;

  /// Modèle retenu, ou `null` (l'exécuteur décide).
  final ZChatModelRef? model;

  /// Replis du [model] retenu — du même niveau que lui.
  final List<ZChatModelRef> fallbacks;

  /// Budget de calcul retenu, ou `null`.
  final ZChatComputeEffort? computeEffort;

  /// Paramètres fusionnés (racine puis route), non modifiables.
  final Map<String, dynamic> params;

  /// Jetons d'accès exigés par la route (vide sans route déclarée).
  final List<String> requiredAccessTokens;

  /// `[model, ...fallbacks]` sans doublon — l'ordre d'essai.
  List<ZChatModelRef> get modelCandidates {
    final List<ZChatModelRef> out = <ZChatModelRef>[];
    for (final ZChatModelRef? c in <ZChatModelRef?>[model, ...fallbacks]) {
      if (c != null && !out.contains(c)) out.add(c);
    }
    return List<ZChatModelRef>.unmodifiable(out);
  }

  /// `true` si la résolution n'apporte **rien** à une requête : ni modèle,
  /// ni budget, ni paramètre.
  bool get isEmpty => model == null && computeEffort == null && params.isEmpty;

  /// Projette la résolution sur [base] — une copie (`copyWith`) de [base],
  /// jamais une reconstruction champ par champ.
  ///
  /// - fournisseur et modèle : ceux de la résolution, **sauf** si [base]
  ///   nomme déjà un modèle — le choix explicite de l'appelant prime, avec
  ///   son propre fournisseur ;
  /// - réglages : la feuille **effective** est [settings] s'il est fourni
  ///   (même remplacement que `withSettings` : une feuille vide retire les
  ///   réglages de [base]), sinon `base.settings` ;
  /// - budget de calcul : celui de la feuille effective, **sinon** la
  ///   résolution (route, sinon racine). Sans [settings], c'est donc
  ///   `base.computeEffort ?? route ?? racine` : la route **ne recouvre
  ///   jamais** un budget explicitement demandé par l'appelant, elle ne fait
  ///   que combler son absence ;
  /// - `extra` : les paramètres résolus, **recouverts** par ceux de [base] ;
  /// - tout le reste est conservé tel quel.
  ///
  /// Une résolution vide sans [settings] rend une requête **égale** à [base].
  ZChatGenerationRequest toRequest(
    ZChatGenerationRequest base, {
    ZChatGenerationSettings? settings,
  }) {
    final bool explicitModel = base.modelId != null;
    final ZChatGenerationSettings effective = settings ?? base.settings;
    return base
        .withSettings(effective)
        .copyWith(
          computeEffort: effective.computeEffort ?? computeEffort,
          modelId: explicitModel ? base.modelId : model?.modelId,
          providerId: explicitModel ? base.providerId : model?.providerId,
          extra: <String, dynamic>{...params, ...base.extra},
        );
  }

  @override
  String toString() =>
      'ZChatRouteResolution($taskKey, declared: $declared, model: $model)';
}
