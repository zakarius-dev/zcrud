/// Répartition **par route** des ports de génération d'étude — la mécanique
/// commune aux six adaptateurs de ce dossier.
///
/// ## Ce que la répartition fait, dans cet ordre
///
/// 1. le **routeur** d'identité `routerId` est lu dans le catalogue ; s'il
///    est absent ou inactif, le refus typé du catalogue est rendu **tel
///    quel** et aucun port n'est appelé ;
/// 2. la **résolution** de la clé de tâche est calculée sur ce routeur
///    (route déclarée, sinon racine) ;
/// 3. le **gate** est consulté avec le palier et les jetons d'accès de la
///    résolution ; un refus est rendu tel quel et aucun port n'est appelé ;
/// 4. la **route effective** est celle que porte déjà la requête, sinon le
///    nom de route résolu — le choix explicite de l'appelant prime toujours ;
/// 5. le **port** est cherché par identité, dans l'ordre : gestionnaire de la
///    route, route effective, nom de route. La première identité connue de
///    l'annuaire l'emporte ;
/// 6. à défaut, le port de **repli**, s'il est déclaré ;
/// 7. sans repli, un `ZNotFoundFailure` **unique** — le port par défaut n'est
///    jamais inventé.
///
/// ## Ce que la répartition ne fait pas
///
/// Elle n'interprète aucune clé : identité de tâche, nom de route,
/// gestionnaire et route sont des chaînes opaques du vocabulaire de l'hôte.
/// Elle ne connaît ni transport, ni URL, ni endpoint : une route est une
/// **donnée** de la requête, sa traduction en appel réseau appartient au port
/// que l'hôte branche.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Nom logique d'entité porté par le refus « aucun port pour cette route ».
const String kZRoutedStudyPortKind = 'study_route_handler';

/// L'échec porté par [result], ou `null` s'il a réussi.
///
/// Évite le `fold` à deux branches là où une seule des deux est asynchrone :
/// un `fold` dont les branches ne rendent pas le même type retombe sur
/// `Object` et fait perdre le typage du résultat.
ZFailure? zRoutedStudyFailureOf<T>(ZResult<T> result) =>
    result.fold((ZFailure f) => f, (T _) => null);

/// La valeur portée par [result], ou `null` s'il a échoué.
T? zRoutedStudyValueOf<T extends Object>(ZResult<T> result) =>
    result.fold((ZFailure _) => null, (T v) => v);

/// Ce qu'une répartition réussie a retenu : le port à appeler et la route
/// effective à faire porter à la requête.
class ZRoutedStudyTarget<P extends Object> {
  /// Construit une cible de répartition.
  const ZRoutedStudyTarget({required this.port, required this.routeId});

  /// Le port retenu — jamais `null`, jamais inventé.
  final P port;

  /// Route effective retenue, ou `null` si ni la requête ni la résolution
  /// n'en nomment une. Les adaptateurs dont la requête porte un `routeId`
  /// l'y estampillent **verbatim** avant de déléguer.
  final String? routeId;
}

/// Résout la route de [taskKey] puis désigne le port qui l'exécute.
///
/// Rend un `Left` typé — et **n'appelle aucun port** — dans trois cas : le
/// routeur est introuvable ou inactif (refus du catalogue, rendu tel quel),
/// le gate refuse (refus du gate, rendu tel quel), aucune identité ne
/// désigne de port et aucun repli n'est déclaré (`ZNotFoundFailure`).
///
/// [requestRouteId] est la route que porte déjà la requête, ou `null` pour
/// un contrat qui n'en transporte pas — la route vient alors entièrement de
/// la configuration (clé de tâche + catalogue).
Future<ZResult<ZRoutedStudyTarget<P>>> zResolveRoutedStudyPort<P extends Object>({
  required ZChatRouteCatalogPort catalog,
  required String routerId,
  required ZChatRouteGate gate,
  required Map<String, P> handlers,
  required String taskKey,
  required String? requestRouteId,
  P? fallback,
}) async {
  final ZResult<ZChatRouter> router = await catalog.resolveRouter(routerId);
  return router.fold(
    (ZFailure failure) => Left<ZFailure, ZRoutedStudyTarget<P>>(failure),
    (ZChatRouter r) {
      final ZChatRouteResolution resolution =
          ZChatRouteResolution.from(r, taskKey);
      final ZResult<Unit> allowed = gate.canRoute(
        taskKey,
        tier: resolution.tier,
        requiredAccessTokens: resolution.requiredAccessTokens,
      );
      final ZFailure? denied = zRoutedStudyFailureOf<Unit>(allowed);
      if (denied != null) {
        return Left<ZFailure, ZRoutedStudyTarget<P>>(denied);
      }
      // Le choix explicite de l'appelant prime sur la configuration : une
      // requête qui nomme déjà sa route n'est jamais réécrite par le
      // catalogue (même règle que la projection de résolution du kernel).
      final String? routeId = requestRouteId ?? resolution.routeName;
      final List<String> ids = <String>[];
      for (final String? candidate in <String?>[
        resolution.handlerId,
        routeId,
        resolution.routeName,
      ]) {
        if (candidate != null && !ids.contains(candidate)) ids.add(candidate);
      }
      P? port;
      for (final String id in ids) {
        port = handlers[id];
        if (port != null) break;
      }
      port ??= fallback;
      if (port == null) {
        return Left<ZFailure, ZRoutedStudyTarget<P>>(
          ZNotFoundFailure(
            'no study port handles this route',
            id: ids.isEmpty ? taskKey : ids.first,
            entity: kZRoutedStudyPortKind,
          ),
        );
      }
      return Right<ZFailure, ZRoutedStudyTarget<P>>(
        ZRoutedStudyTarget<P>(port: port, routeId: routeId),
      );
    },
  );
}

/// Enveloppe une exception d'un port d'hôte en `Left(ZDomainFailure)`.
///
/// Un port qui lève au lieu de rendre un `Left` ne doit jamais traverser
/// jusqu'à l'appelant (invariant AD-10).
ZFailure zRoutedStudyThrowFailure(Object error) =>
    ZDomainFailure('routed study port threw ${error.runtimeType}');
