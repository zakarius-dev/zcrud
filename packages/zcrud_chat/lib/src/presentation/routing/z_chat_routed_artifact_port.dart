/// Port de génération d'artefact **routé** —
/// `ZChatRoutedArtifactGenerationPort`.
///
/// Pendant de `ZChatRoutedStreamPort` pour les artefacts : même ordre de
/// répartition (gestionnaire de la route → fournisseur de la requête → nom
/// de route → repli), même refus typé, même délégation de la requête telle
/// quelle. La clé de tâche est le `kind` du style, sinon la clé de l'artefact ;
/// le fournisseur est le champ typé `ZChatArtifactGenerationRequest.providerId`
/// — jamais une clé d'`extra`.
///
/// Un `ZChatGenerationPort` de l'annuaire est **adapté** : le texte de ses
/// blocs de texte, concaténé, devient le `ZChatArtifactContent` (`extra`
/// vide) — la même projection que `ZChatMessage.content`. Un hôte dont les
/// artefacts exigent un port dédié déclare un `ZChatArtifactGenerationPort`
/// par [ZChatRoutedArtifactGenerationPort.artifactPorts].
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_route_session.dart';
import 'z_chat_routed_stream_port.dart';

/// Répartit chaque génération d'artefact vers le port de sa route.
class ZChatRoutedArtifactGenerationPort implements ZChatArtifactGenerationPort {
  /// Construit le port routé. [artifactPorts] est consulté **avant**
  /// [handlers] pour une même identité ; [fallback] reçoit ce qu'aucune
  /// identité ne prend.
  const ZChatRoutedArtifactGenerationPort({
    required this.routeOf,
    required this.handlers,
    this.artifactPorts = const <String, ZChatArtifactGenerationPort>{},
    this.fallback,
  });

  /// La route d'une clé de tâche.
  final ZChatRouteLookup routeOf;

  /// L'annuaire des ports de génération, par identité opaque.
  final ZChatRouteHandlers handlers;

  /// Ports d'artefact dédiés, par identité opaque.
  final Map<String, ZChatArtifactGenerationPort> artifactPorts;

  /// Port de repli, ou `null`.
  final ZChatArtifactGenerationPort? fallback;

  @override
  Future<ZResult<ZChatArtifactContent>> generate(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
  }) async {
    final String taskKey = zChatArtifactTaskKeyOf(request);
    final List<String> ids = zChatRouteDispatchIds(
      route: routeOf(taskKey),
      providerId: request.providerId,
    );
    ZChatArtifactGenerationPort? port;
    for (final String id in ids) {
      port = artifactPorts[id] ?? _adapt(handlers.generationPortFor(id));
      if (port != null) break;
    }
    port ??= fallback;
    if (port == null) {
      return Left<ZFailure, ZChatArtifactContent>(
        ZUnsupportedOperationFailure(
          'no generation port handles this route',
          operation: 'route:${ids.isEmpty ? taskKey : ids.first}',
        ),
      );
    }
    try {
      return await port.generate(request, token: token);
    } catch (error) {
      return Left<ZFailure, ZChatArtifactContent>(
        ZDomainFailure('routed generation port threw ${error.runtimeType}'),
      );
    }
  }

  static ZChatArtifactGenerationPort? _adapt(ZChatGenerationPort? inner) =>
      inner == null ? null : _ZGenerationPortAdapter(inner);
}

/// Adapte un port de génération de texte en port d'artefact.
class _ZGenerationPortAdapter implements ZChatArtifactGenerationPort {
  const _ZGenerationPortAdapter(this.inner);

  final ZChatGenerationPort inner;

  @override
  Future<ZResult<ZChatArtifactContent>> generate(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
  }) async {
    final ZResult<List<ZContentBlock>> produced = await inner.generate(
      ZChatGenerationRequest(
        style: request.style ?? ZChatGenerationStyle(request.artifactKey),
        subject: request.subject,
        notes: request.notes,
        conversationId: request.conversationId,
        sourceMessageId: request.messageId,
        languageTag: request.languageTag,
        instructions: request.instructions,
        modelId: request.modelId,
        providerId: request.providerId,
        extra: request.extra,
      ),
      token: token,
    );
    // Même projection que `ZChatMessage.content` : le texte des seuls blocs
    // de texte, concaténé — aucun autre bloc n'est interprété.
    return produced.map(
      (List<ZContentBlock> blocks) => ZChatArtifactContent(
        blocks.whereType<ZTextBlock>().map((ZTextBlock b) => b.text).join(),
      ),
    );
  }
}
