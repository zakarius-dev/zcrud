/// Adaptateur de port : le fil textuel encodé selon la convention IFFD vu
/// comme un `ZChatStreamPort`.
///
/// C'est la frontière proprement dite. Au-dessus de ce fichier, un hôte ne
/// voit que le contrat scellé du kernel (`Stream<ZResult<ZChatStreamEvent>>`) ;
/// en dessous, il n'y a que du texte et des sentinelles. Aucune compensation
/// ne traverse.
///
/// ## Ce que ce fichier ne fait pas
///
/// Il ne parle pas au réseau. Le transport (en-têtes, jeton d'annulation,
/// découpage en lignes, retrait de tout préfixe de flux) reste du ressort
/// de l'application (invariants AD-11, AD-12), ce qui rend ce paquet
/// testable sans socket. L'hôte fournit un [ZIffdRawStreamOpener] ; le port
/// fait le reste.
library;

import 'dart:async';
import 'dart:convert';

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_iffd_stream_normalizer.dart';
import 'z_iffd_wire.dart';

/// Ouvre le flux brut : des fragments de texte déjà extraits du transport
/// par l'hôte.
///
/// L'implémentation appartient à l'hôte. Elle doit honorer l'annulation de
/// [token] (`token.whenCancelled`) — le port la traite aussi de son côté,
/// mais un transport qui l'ignore continuerait à consommer du quota serveur.
typedef ZIffdRawStreamOpener =
    Stream<String> Function(
      ZChatGenerationRequest request,
      ZChatRequestToken token,
    );

/// `ZChatStreamPort` adossé au fil textuel encodé selon la convention IFFD.
class ZIffdTextStreamPort implements ZChatStreamPort {
  /// Construit le port sur un ouvreur de flux brut fourni par l'hôte.
  const ZIffdTextStreamPort({required this.open});

  /// Ouvreur du flux brut, fourni par l'hôte (le transport reste côté app).
  final ZIffdRawStreamOpener open;

  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) async* {
    final ZIffdStreamNormalizer normalizer = ZIffdStreamNormalizer();
    int emitted = 0;
    bool completed = false;

    try {
      await for (final String chunk in open(request, token)) {
        if (token.isCancelled) break;
        for (final ZResult<ZChatStreamEvent> e in normalizer.add(chunk)) {
          emitted++;
          yield e;
        }
      }
      completed = !token.isCancelled;
    } on Object catch (error) {
      // Invariant AD-10 : aucune exception du transport ne s'échappe du
      // port. Elle devient un `Left` typé — jamais un message de
      // conversation (invariant AD-5).
      for (final ZResult<ZChatStreamEvent> e in normalizer.close()) {
        emitted++;
        yield e;
      }
      yield Left<ZFailure, ZChatStreamEvent>(
        ZChatStreamInterruptedFailure(
          error.toString(),
          requestId: token.requestId,
          eventsReceived: emitted,
        ),
      );
      return;
    }

    for (final ZResult<ZChatStreamEvent> e in normalizer.close()) {
      emitted++;
      yield e;
    }

    if (completed) {
      yield Right<ZFailure, ZChatStreamEvent>(
        ZChatDoneEvent(conversationId: request.conversationId ?? ''),
      );
    } else {
      // Arrêt voulu : `cancelledByUser` sépare le geste de l'utilisateur
      // d'une coupure subie — les confondre afficherait une erreur sur une
      // simple annulation.
      yield Left<ZFailure, ZChatStreamEvent>(
        ZChatStreamInterruptedFailure(
          'cancelled',
          requestId: token.requestId,
          eventsReceived: emitted,
          cancelledByUser: true,
        ),
      );
    }
  }
}

/// Décode la réponse non-streamée du backend
/// (`{"data": …, "error": …, "reasoning": …, "responseCode": …}`).
///
/// Deux garanties de contrat sur cette forme :
/// 1. `error` devient un `Left` typé, jamais un `data` affiché dans la
///    bulle de réponse comme s'il s'agissait du contenu ;
/// 2. `reasoning` ne se retrouve jamais dans le corps : il reste hors des
///    blocs de contenu, le rendu de la trace étant un canal distinct.
///
/// Invariant AD-10 : aucune entrée ne lève. Une map vide donne un unique
/// bloc de texte vide plutôt qu'une exception.
ZResult<List<ZContentBlock>> zIffdDecodeNonStreamResponse(
  Map<String, dynamic> map,
) {
  final Object? error = map['error'];
  if (error is String && error.trim().isNotEmpty) {
    final Object? code = map['responseCode'];
    return Left<ZFailure, List<ZContentBlock>>(
      ZChatProviderFailure(
        error.trim(),
        code: code == null
            ? ZIffdFailureCodes.plainAgentError
            : code.toString(),
      ),
    );
  }
  final Object? data = map['data'];
  final String text = data is String ? data : '';
  // Le corps est du markdown brut : un unique `ZTextBlock`. Son rendu riche
  // relève d'un `ZChatRenderer` injecté, pas de ce décodeur.
  return Right<ZFailure, List<ZContentBlock>>(<ZContentBlock>[
    ZTextBlock(text: text),
  ]);
}

/// Décode une réponse non-streamée reçue sous forme de texte JSON.
///
/// Invariant AD-10 : un corps illisible devient un `Left` typé, jamais une
/// exception.
ZResult<List<ZContentBlock>> zIffdDecodeNonStreamBody(String body) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    return Left<ZFailure, List<ZContentBlock>>(
      ZChatProviderFailure(e.message, code: ZIffdFailureCodes.taggedError),
    );
  }
  if (decoded is! Map<String, dynamic>) {
    return Left<ZFailure, List<ZContentBlock>>(
      const ZChatProviderFailure(
        'non-object body',
        code: ZIffdFailureCodes.taggedError,
      ),
    );
  }
  return zIffdDecodeNonStreamResponse(decoded);
}
