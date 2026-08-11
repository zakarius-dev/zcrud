/// Normalisation du fil textuel encodé selon la convention IFFD vers les
/// événements typés du kernel.
///
/// `ZIffdLexer` découpe ; ce fichier décide. Il transforme des segments en
/// `ZResult<ZChatStreamEvent>` : un événement de jeton pour la réponse, un
/// événement de raisonnement pour la trace, un événement personnalisé pour
/// une charge utile structurée, et un échec typé pour tout diagnostic
/// d'erreur — jamais un message de conversation (invariant AD-5).
///
/// ## Les décisions face à un flux malformé
///
/// | Cas | Décision |
/// |---|---|
/// | sentinelle jamais refermée | le contenu est émis au fil de l'eau, aucun événement n'attend une fermeture qui n'arrivera pas |
/// | balise fermante orpheline | ignorée, jamais rendue comme texte, jamais traitée comme ouvrante |
/// | balise inconnue | canal de raisonnement par défaut, aucune exception — le repli vers la réponse ferait réapparaître du raisonnement dans le corps affiché |
/// | JSON illisible dans la charge utile finale | événement ouvert portant le texte brut, invariant AD-10 : un payload corrompu ne fait jamais échouer le tour |
/// | flux tronqué en plein milieu | `close()` vide la ligne partielle et la charge utile partielle : rien ne reste captif du décodeur |
///
/// ## Pourquoi aucun identifiant de séquence n'est fabriqué
///
/// `ZChatStreamEvent.sequenceId` sert à reprendre un flux coupé sans rejouer
/// le tour. Ce fil n'en transporte aucun et son serveur n'a aucun point de
/// reprise : numéroter les événements ici ferait croire à l'hôte qu'une
/// reprise est honorée, alors qu'une reconnexion rejouerait le tour entier
/// (message dupliqué, quota consommé deux fois). Les événements sortent donc
/// avec `sequenceId == null` — l'aveu exact de ce que le transport sait
/// faire.
library;

import 'dart:convert';

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_iffd_lexer.dart';
import 'z_iffd_wire.dart';

/// Une portée de balise ouverte.
class _ZIffdScope {
  _ZIffdScope(this.identity, this.agent, this.channel);

  final String identity;
  final String agent;
  final ZIffdChannel channel;
}

/// Décodeur incrémental et sans état partagé : une instance par requête.
///
/// Pur-Dart, aucune dépendance de transport : l'hôte lui pousse les
/// fragments qu'il a lui-même extraits de son flux (invariants AD-11,
/// AD-12).
class ZIffdStreamNormalizer {
  /// Construit un décodeur pour un tour.
  ZIffdStreamNormalizer();

  final ZIffdLexer _lexer = ZIffdLexer();
  final List<_ZIffdScope> _stack = <_ZIffdScope>[];
  final StringBuffer _payload = StringBuffer();

  /// Ligne en cours de constitution sur le canal courant.
  String _pending = '';

  /// `true` quand la ligne courante du canal `answer` est déjà acquittée
  /// comme n'étant pas une erreur en clair : le reste part sans retenue
  /// supplémentaire.
  bool _lineReleased = false;

  ZIffdChannel get _channel =>
      _stack.isEmpty ? ZIffdChannel.answer : _stack.last.channel;

  String get _agent => _stack.isEmpty ? 'iffd' : _stack.last.agent;

  /// Consomme un fragment brut et rend les événements devenus certains.
  List<ZResult<ZChatStreamEvent>> add(String chunk) =>
      _consume(_lexer.feed(chunk));

  /// Termine le décodage : vide la ligne et la charge utile partielles.
  ///
  /// N'émet **pas** d'événement terminal : c'est au port de décider si le flux
  /// s'est achevé (`ZChatDoneEvent`) ou a été coupé
  /// (`ZChatStreamInterruptedFailure`).
  List<ZResult<ZChatStreamEvent>> close() {
    final List<ZResult<ZChatStreamEvent>> out = _consume(_lexer.close());
    _flushLine(out);
    _flushPayload(out);
    _stack.clear();
    return out;
  }

  List<ZResult<ZChatStreamEvent>> _consume(List<ZIffdSegment> segments) {
    final List<ZResult<ZChatStreamEvent>> out = <ZResult<ZChatStreamEvent>>[];
    for (final ZIffdSegment seg in segments) {
      switch (seg) {
        case ZIffdTextSegment(text: final String text):
          _onText(out, text);
        case final ZIffdTagSegment tag when !tag.closing:
          _onOpen(out, tag);
        case final ZIffdTagSegment tag:
          _onClose(out, tag);
      }
    }
    return out;
  }

  void _onOpen(List<ZResult<ZChatStreamEvent>> out, ZIffdTagSegment tag) {
    // Une bascule de canal ferme la ligne en cours : elle appartient au canal
    // qu'on quitte, jamais à celui qu'on ouvre.
    _flushLine(out);
    _stack.add(
      _ZIffdScope(
        tag.identity,
        zIffdAgentOfTag(tag.identity),
        zIffdChannelOfTag(tag.name),
      ),
    );
  }

  void _onClose(List<ZResult<ZChatStreamEvent>> out, ZIffdTagSegment tag) {
    _flushLine(out);
    if (zIffdChannelOfTag(tag.name) == ZIffdChannel.payload) {
      _flushPayload(out);
    }
    // Dépilage jusqu'à l'ouvrante correspondante. Aucune correspondance ⇒
    // fermante ORPHELINE : ignorée, jamais rendue comme texte.
    final int at = _stack.lastIndexWhere(
      (_ZIffdScope s) => s.identity == tag.identity,
    );
    if (at < 0) return;
    _stack.removeRange(at, _stack.length);
  }

  void _onText(List<ZResult<ZChatStreamEvent>> out, String text) {
    int start = 0;
    while (start < text.length) {
      final int nl = text.indexOf('\n', start);
      if (nl < 0) {
        _pending += text.substring(start);
        _maybeReleaseAnswerPrefix(out);
        return;
      }
      _pending += text.substring(start, nl + 1);
      _flushLine(out);
      start = nl + 1;
    }
  }

  /// Sur le canal `answer`, relâche le début de ligne dès qu'il est certain
  /// qu'il ne s'agit pas d'une erreur en clair.
  ///
  /// Sans cela, chaque ligne de la réponse attendrait son `\n` avant d'être
  /// affichée — le contraire d'un rendu au fil de l'eau. Avec cela, la
  /// retenue ne dure que le temps de comparer les premiers caractères au
  /// préfixe [kZIffdPlainErrorPrefix].
  void _maybeReleaseAnswerPrefix(List<ZResult<ZChatStreamEvent>> out) {
    if (_channel != ZIffdChannel.answer || _pending.isEmpty) return;
    if (!_lineReleased && _isErrorPrefixCandidate(_pending)) return;
    out.add(
      Right<ZFailure, ZChatStreamEvent>(ZChatTokenEvent(content: _pending)),
    );
    _pending = '';
    _lineReleased = true;
  }

  /// `true` si [s] peut encore devenir une ligne d'erreur en clair — c'est-à-dire
  /// si l'un est préfixe de l'autre.
  bool _isErrorPrefixCandidate(String s) {
    final String trimmed = s.trimLeft();
    if (trimmed.isEmpty) return true;
    final int n = trimmed.length < kZIffdPlainErrorPrefix.length
        ? trimmed.length
        : kZIffdPlainErrorPrefix.length;
    return trimmed.substring(0, n) == kZIffdPlainErrorPrefix.substring(0, n);
  }

  void _flushLine(List<ZResult<ZChatStreamEvent>> out) {
    final String line = _pending;
    final bool released = _lineReleased;
    _pending = '';
    _lineReleased = false;
    if (line.isEmpty) return;

    // Une erreur en clair est un `Left` typé sur tous les canaux : le
    // serveur peut écrire son préfixe d'erreur via le même canal que la
    // réponse, sans garantie d'être sous une balise.
    if (!released && line.trimLeft().startsWith(kZIffdPlainErrorPrefix)) {
      out.add(
        Left<ZFailure, ZChatStreamEvent>(
          ZChatProviderFailure(
            line.trim(),
            code: ZIffdFailureCodes.plainAgentError,
          ),
        ),
      );
      return;
    }

    switch (_channel) {
      case ZIffdChannel.answer:
        out.add(
          Right<ZFailure, ZChatStreamEvent>(ZChatTokenEvent(content: line)),
        );
      case ZIffdChannel.thinking:
        final String content = line.trim();
        if (content.isEmpty) return;
        out.add(
          Right<ZFailure, ZChatStreamEvent>(
            ZChatThinkingEvent(
              step: ZChatThinkingStep(agent: _agent, content: content),
            ),
          ),
        );
      case ZIffdChannel.failure:
        final String content = line.trim();
        if (content.isEmpty) return;
        out.add(
          Left<ZFailure, ZChatStreamEvent>(
            ZChatProviderFailure(
              content,
              code: ZIffdFailureCodes.taggedError,
            ),
          ),
        );
      case ZIffdChannel.payload:
        _payload.write(line);
    }
  }

  void _flushPayload(List<ZResult<ZChatStreamEvent>> out) {
    final String raw = _payload.toString().trim();
    _payload.clear();
    if (raw.isEmpty) return;
    // AD-10 : un JSON illisible n'échoue pas et n'est pas perdu — il traverse
    // sous `raw` dans le variant OUVERT (AD-4).
    Map<String, dynamic> body;
    try {
      final Object? decoded = jsonDecode(raw);
      body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'raw': raw};
    } on FormatException {
      body = <String, dynamic>{'raw': raw};
    }
    out.add(
      Right<ZFailure, ZChatStreamEvent>(
        ZChatCustomStreamEvent(kZIffdFinalAnswerPayloadKind, body),
      ),
    );
  }
}
