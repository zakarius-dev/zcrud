/// Génération d'un artefact de portée, sans contrôleur de fil.
///
/// Un hôte dont le fil est écrit par le serveur n'a pas à fabriquer un
/// transcript pour obtenir une génération de dossier. Une seule génération
/// est en vol par [scopeId] ; l'ensemble occupé est observable.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Refus d'une génération déjà en vol pour la même portée.
class ZChatScopeBusyFailure extends ZDomainFailure {
  /// [scopeId] est la portée occupée.
  const ZChatScopeBusyFailure(this.scopeId)
    : super('a generation is already running for this scope');

  /// Portée dont une génération n'est pas terminée.
  final String scopeId;

  @override
  bool operator ==(Object other) =>
      other is ZChatScopeBusyFailure && scopeId == other.scopeId;

  @override
  int get hashCode => Object.hash(runtimeType, scopeId);
}

/// Service de génération borné à une portée.
class ZChatScopeGeneration {
  /// Construit le service. [store] reçoit le texte lorsque [onGenerated]
  /// n'est pas fourni à [generate].
  ZChatScopeGeneration({
    required ZChatArtifactGenerationPort port,
    ZChatArtifactStorePort? store,
  }) : _port = port,
       _store = store ?? ZChatInMemoryArtifactStore();

  // Champ privé assigné dans l'initialiseur : le paramètre public reste
  // `port` pour l'appelant.
  // ignore: prefer_initializing_formals
  final ZChatArtifactGenerationPort _port;
  final ZChatArtifactStorePort _store;
  final Set<String> _inFlight = <String>{};

  /// Portées dont une génération est en cours.
  final ValueNotifier<Set<String>> busy = ValueNotifier<Set<String>>(
    const <String>{},
  );

  bool _disposed = false;

  /// Produit [artifactKey] pour [scopeId].
  ///
  /// Une seconde demande sur la même portée, tant que la première n'est pas
  /// terminée, est refusée sans appeler le port : l'échec est un
  /// [ZChatScopeBusyFailure]. [modelId], [providerId], [languageTag] et
  /// [extra] sont portés tels quels par la requête.
  ///
  /// [onGenerated] enregistre le contenu à la place du magasin (qui, lui,
  /// remplace). Le rappel est tout-ou-rien : une reprise partielle
  /// (réécrire seulement les échecs, sans relancer la génération) reste à
  /// l'hôte, qui détient les identifiants.
  Future<ZResult<ZChatArtifactContent>> generate({
    required String scopeId,
    required String artifactKey,
    required String notes,
    String subject = '',
    String? modelId,
    String? providerId,
    String? languageTag,
    Map<String, dynamic> extra = const <String, dynamic>{},
    Future<ZResult<Unit>> Function(ZChatArtifactContent content)? onGenerated,
  }) async {
    if (_disposed) {
      return const Left<ZFailure, ZChatArtifactContent>(
        ZDomainFailure('scope generation is disposed'),
      );
    }
    if (_inFlight.contains(scopeId)) {
      return Left<ZFailure, ZChatArtifactContent>(
        ZChatScopeBusyFailure(scopeId),
      );
    }
    _inFlight.add(scopeId);
    busy.value = Set<String>.unmodifiable(_inFlight);
    final ZChatArtifactGenerationRequest request =
        ZChatArtifactGenerationRequest(
          scopeId: scopeId,
          artifactKey: artifactKey,
          notes: notes,
          subject: subject,
          allowEmptyNotes: true,
          modelId: modelId,
          providerId: providerId,
          languageTag: languageTag,
          extra: extra,
        );
    final ZChatRequestToken token = ZChatRequestToken('scope-$scopeId');
    try {
      return await ZChatArtifactGenerationRunner(
        port: _port,
        store: _store,
      ).run(
        request,
        token: token,
        mark: (String messageId, String key, {required bool busy}) {},
        record: onGenerated,
      );
    } finally {
      _inFlight.remove(scopeId);
      if (!_disposed) {
        busy.value = Set<String>.unmodifiable(_inFlight);
      }
    }
  }

  /// Libère la tranche [busy]. N'atteint pas le port.
  void dispose() {
    _disposed = true;
    busy.dispose();
  }
}
