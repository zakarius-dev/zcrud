/// Exécuteur d'actions **par défaut** — `ZChatUnsupportedActionExecutor`.
///
/// Implémente `ZChatActionExecutor` **et** `ZChatSettingsAwareActionExecutor`
/// en refusant **nommément** chacun des neuf membres par
/// `Left(ZUnsupportedOperationFailure(operation: '<membre>'))`. Un hôte
/// **étend** cette classe et ne redéfinit que les verbes qu'il sait
/// exécuter ; tout verbe non redéfini reste refusé proprement — jamais un
/// succès factice, jamais un abandon silencieux, jamais un `throw`.
///
/// ```dart
/// class MonExecutor extends ZChatUnsupportedActionExecutor {
///   const MonExecutor();
///   @override
///   Future<ZResult<Unit>> cancelRequest(String requestId) async => …;
/// }
/// ```
///
/// Le refus est un **type** existant du cœur : l'appelant masque ou
/// désactive l'action sans parser de chaîne.
library;

import 'package:zcrud_core/domain.dart';

import '../action/z_chat_action.dart';
import '../action/z_chat_action_executor.dart';
import '../action/z_chat_action_plan.dart';

/// Exécuteur qui refuse tout, membre par membre, sous-classable.
class ZChatUnsupportedActionExecutor
    implements ZChatActionExecutor, ZChatSettingsAwareActionExecutor {
  /// Construit l'exécuteur.
  const ZChatUnsupportedActionExecutor();

  /// Le refus nommé d'[operation], réutilisable par une sous-classe pour
  /// ses propres verbes. [reason] est un diagnostic technique, pas un
  /// libellé.
  ZResult<T> refuse<T>(String operation, [String? reason]) =>
      Left<ZFailure, T>(ZUnsupportedOperationFailure(
        reason ?? 'operation not supported by this executor',
        operation: operation,
      ));

  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(
    ZChatAction action,
  ) async =>
      refuse<ZChatActionImpact>('estimateImpact');

  @override
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  }) async =>
      refuse<List<String>>('editAndResend');

  @override
  Future<ZResult<List<String>>> regenerate({
    required String messageId,
  }) async =>
      refuse<List<String>>('regenerate');

  @override
  Future<ZResult<List<String>>> regenerateWithSettings(
    ZChatRegenerateAction action,
  ) async =>
      refuse<List<String>>('regenerateWithSettings');

  @override
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  }) async =>
      refuse<List<String>>('softDeleteMessages');

  @override
  Future<ZResult<Unit>> cancelRequest(String requestId) async =>
      refuse<Unit>('cancelRequest');

  @override
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  }) async =>
      refuse<String>('renderForCopy');

  @override
  Future<ZResult<List<String>>> executeCustom(
    ZChatCustomAction action,
  ) async =>
      refuse<List<String>>('executeCustom');
}
