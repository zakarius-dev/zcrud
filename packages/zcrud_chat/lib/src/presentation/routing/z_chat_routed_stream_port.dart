/// Port de streaming **routé** — `ZChatRoutedStreamPort`.
///
/// Il ne résout ni ne gate : il **répartit** une requête déjà routée vers le
/// port qui l'exécute, dans cet ordre :
///
/// 1. le **gestionnaire** nommé par la route de la tâche (`handlerId`) ;
/// 2. le **fournisseur** porté par la requête (`providerId`) ;
/// 3. le **nom de route** (`routeName`) ;
/// 4. le port de **repli**, s'il est déclaré.
///
/// Chaque identité est cherchée dans l'annuaire `ZChatRouteHandlers` ; la
/// première connue l'emporte. Aucune ⇒ un flux d'un seul
/// `Left(ZUnsupportedOperationFailure)`, opération `route:<identité>`. La
/// requête est déléguée **telle quelle** (même instance). Un port interne qui
/// lève rend un flux d'un seul `Left` (invariant AD-10).
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Lit la route déclarée pour une clé de tâche, ou `null`.
typedef ZChatRouteLookup = ZChatRouteSpec? Function(String taskKey);

/// Les identités candidates d'une répartition, dans l'ordre d'essai.
List<String> zChatRouteDispatchIds({
  required ZChatRouteSpec? route,
  required String? providerId,
}) => <String>[?route?.handlerId, ?providerId, ?route?.routeName];

/// Répartit chaque requête vers le port de streaming de sa route.
class ZChatRoutedStreamPort implements ZChatStreamPort {
  /// Construit le port routé sur [routeOf] et [handlers] ; [fallback] reçoit
  /// ce qu'aucun gestionnaire ne prend.
  const ZChatRoutedStreamPort({
    required this.routeOf,
    required this.handlers,
    this.fallback,
  });

  /// La route d'une clé de tâche — typiquement
  /// `(k) => session.routeOf(k).value`.
  final ZChatRouteLookup routeOf;

  /// L'annuaire des ports, par identité opaque.
  final ZChatRouteHandlers handlers;

  /// Port de repli, ou `null` (aucun gestionnaire ⇒ refus typé).
  final ZChatStreamPort? fallback;

  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) {
    final String taskKey = request.style.kind;
    final List<String> ids = zChatRouteDispatchIds(
      route: routeOf(taskKey),
      providerId: request.providerId,
    );
    ZChatStreamPort? port;
    for (final String id in ids) {
      port = handlers.streamPortFor(id);
      if (port != null) break;
    }
    port ??= fallback;
    if (port == null) {
      return Stream<ZResult<ZChatStreamEvent>>.value(
        Left<ZFailure, ZChatStreamEvent>(
          ZUnsupportedOperationFailure(
            'no stream port handles this route',
            operation: 'route:${ids.isEmpty ? taskKey : ids.first}',
          ),
        ),
      );
    }
    try {
      return port.stream(request, token: token);
    } catch (error) {
      return Stream<ZResult<ZChatStreamEvent>>.value(
        Left<ZFailure, ZChatStreamEvent>(
          ZDomainFailure('routed stream port threw ${error.runtimeType}'),
        ),
      );
    }
  }
}
