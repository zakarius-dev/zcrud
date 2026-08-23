/// Gouvernance d'une route — `ZChatRouteGate` (invariants AD-5, AD-12).
///
/// Le gate répond à une seule question : **cette tâche peut-elle emprunter
/// cette route** pour ce palier et ces jetons d'accès ? Il ne connaît ni
/// plan, ni tarif, ni libellé : le palier et les jetons sont opaques, c'est
/// l'hôte qui les confronte à son abonnement.
///
/// Le socle fournit deux gates : **refus** (le défaut dès qu'un catalogue est
/// déclaré — un hôte qui gouverne doit le dire) et **autorisation** totale.
/// Un refus est un `ZChatProviderFailure` de code
/// `ZChatFailureCodes.upgradeRequired`, le même qu'un backend émettrait.
library;

import 'package:zcrud_core/domain.dart';

import '../ai/z_chat_ai_failure.dart';

/// Décide si une tâche peut emprunter une route.
abstract interface class ZChatRouteGate {
  /// `Right(unit)` si [taskKey] peut être routée pour [tier] avec
  /// [requiredAccessTokens] ; `Left` typé sinon.
  ZResult<Unit> canRoute(
    String taskKey, {
    String? tier,
    List<String> requiredAccessTokens = const <String>[],
  });
}

/// Gate qui **refuse** tout — le défaut quand un catalogue est déclaré sans
/// gate explicite.
class ZDenyAllChatRouteGate implements ZChatRouteGate {
  /// Construit le gate de refus.
  const ZDenyAllChatRouteGate();

  @override
  ZResult<Unit> canRoute(
    String taskKey, {
    String? tier,
    List<String> requiredAccessTokens = const <String>[],
  }) => Left<ZFailure, Unit>(
    ZChatProviderFailure(
      'route denied: $taskKey',
      code: ZChatFailureCodes.upgradeRequired,
    ),
  );
}

/// Gate qui **autorise** tout.
class ZAllowAllChatRouteGate implements ZChatRouteGate {
  /// Construit le gate d'autorisation.
  const ZAllowAllChatRouteGate();

  @override
  ZResult<Unit> canRoute(
    String taskKey, {
    String? tier,
    List<String> requiredAccessTokens = const <String>[],
  }) => const Right<ZFailure, Unit>(unit);
}
