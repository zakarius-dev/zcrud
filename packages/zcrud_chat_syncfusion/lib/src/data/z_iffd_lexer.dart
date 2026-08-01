/// Lexeur **incrémental** du fil textuel d'IFFD — CHAT-6.
///
/// Transforme un flux de fragments `String` (déjà décadrés du SSE par le
/// transport de l'hôte) en une suite de **segments** : du texte décodé, ou une
/// balise ouvrante/fermante. C'est le seul endroit du dépôt qui connaît
/// `###LINE###` et les sentinelles pseudo-XML.
///
/// ## Les trois pièges d'un flux fragmenté, et leur traitement
///
/// 1. **Un marqueur coupé en deux.** `###LI` puis `NE###` : un `replaceAll`
///    par fragment laisserait `###LI` dans la réponse affichée. Le lexeur
///    **retient** la plus longue queue qui est un préfixe de [kZIffdLineMarker].
/// 2. **Une balise coupée en deux.** `<RAG_THIN` puis `KING>` : idem, le lexeur
///    retient la queue à partir du `<` tant qu'aucun `>` ne l'a fermée — mais
///    **jamais au-delà de [_maxTagHold] caractères**, sinon un `<` littéral du
///    texte (« a < b ») bloquerait le flux pour toujours. Passé ce seuil, la
///    queue est relâchée **comme du texte** : rien n'est perdu, AD-10.
/// 3. **Le préfixe `$` du serveur.** `vector_store_service.py:394` émet
///    `f"${event} ###LINE###"` : la balise arrive collée derrière un `$`. Ce `$`
///    est retiré quand il précède immédiatement une balise, et **conservé**
///    partout ailleurs (un `$` de LaTeX dans une réponse est du contenu).
///
/// ## Ce que le lexeur ne décide PAS
///
/// Il ne classe rien en canal et ne produit aucun événement : il ne fait que
/// **découper**. Le classement (réponse / trace / échec / charge utile) est la
/// responsabilité de `ZIffdStreamNormalizer`, pour que la forme du fil et la
/// sémantique du kernel restent testables séparément.
library;

import 'z_iffd_wire.dart';

/// Un morceau reconnu du fil.
sealed class ZIffdSegment {
  const ZIffdSegment();
}

/// Du texte, `###LINE###` déjà décodé en `\n`.
final class ZIffdTextSegment extends ZIffdSegment {
  /// Construit un segment de texte.
  const ZIffdTextSegment(this.text);

  /// Le texte décodé (jamais vide : le lexeur n'émet pas de segment vide).
  final String text;

  @override
  String toString() => 'ZIffdTextSegment(${text.length} car.)';
}

/// Une balise `<NOM>` / `</NOM>` / `<NOM 3>` / `</NOM 3>`.
final class ZIffdTagSegment extends ZIffdSegment {
  /// Construit un segment de balise.
  const ZIffdTagSegment({
    required this.name,
    required this.closing,
    this.argument,
  });

  /// Nom SCREAMING_SNAKE (`RAG_THINKING`, `RAG_ITERATION_2`, `ROUND`).
  final String name;

  /// `true` pour une balise fermante.
  final bool closing;

  /// Argument numérique éventuel (`<ROUND 3>` ⇒ `'3'`).
  final String? argument;

  /// Identité d'appariement ouvrante/fermante (nom + argument).
  String get identity => argument == null ? name : '$name $argument';

  @override
  String toString() => 'ZIffdTagSegment(${closing ? '/' : ''}$identity)';
}

/// Forme **mesurée** d'une sentinelle IFFD : SCREAMING_SNAKE, argument
/// numérique optionnel séparé par des espaces.
///
/// 🔴 Volontairement **restrictive**. Elle ne reconnaît ni `<b>`, ni `<div>`,
/// ni `<T>` d'un extrait de code : du HTML ou du Dart cité dans une réponse
/// reste du **texte**. Un lexeur qui avalerait tout `<…>` détruirait des
/// réponses légitimes — le prix à payer serait plus lourd que la fuite qu'il
/// prétend fermer.
final RegExp _tagPattern = RegExp(r'<(/?)([A-Z][A-Z0-9_]*)(?: +([0-9]+))?>');

/// Un `<` non fermé au-delà de cette longueur est du texte, pas une balise en
/// cours. Borne la mémoire du lexeur **et** garantit qu'un `<` littéral ne gèle
/// jamais le flux.
const int _maxTagHold = 64;

/// Découpe incrémentale du fil.
///
/// Instance **par requête** : l'état (queue retenue) n'est jamais partagé entre
/// deux tours.
class ZIffdLexer {
  String _buffer = '';

  /// Consomme [chunk] et rend les segments **complets** disponibles.
  ///
  /// Ne lève jamais (AD-10) : une entrée arbitraire produit au pire un unique
  /// segment de texte.
  List<ZIffdSegment> feed(String chunk) => _run(chunk, eof: false);

  /// Vide la queue retenue en fin de flux : ce qui restait devient du **texte**.
  ///
  /// C'est la garantie « aucune perte » : un fragment final `###LI` ou
  /// `<RAG_THIN` est rendu tel quel plutôt que disparaître silencieusement.
  List<ZIffdSegment> close() => _run('', eof: true);

  List<ZIffdSegment> _run(String chunk, {required bool eof}) {
    _buffer += chunk;
    final int safe = eof ? _buffer.length : _safeLength(_buffer);
    if (safe <= 0) return const <ZIffdSegment>[];
    final String head = _buffer.substring(0, safe);
    _buffer = _buffer.substring(safe);
    return _segment(head);
  }

  /// Longueur de préfixe qu'on peut traiter **sans risque de coupure**.
  int _safeLength(String buf) {
    int safe = buf.length;

    // (1) Queue qui est un préfixe strict du marqueur de saut de ligne.
    for (int k = kZIffdLineMarker.length - 1; k >= 1; k--) {
      if (buf.length >= k &&
          buf.endsWith(kZIffdLineMarker.substring(0, k)) &&
          !buf.endsWith(kZIffdLineMarker)) {
        safe = buf.length - k;
        break;
      }
    }

    // (2) Balise ouverte mais non fermée, dans la limite de _maxTagHold.
    final int lt = buf.lastIndexOf('<');
    if (lt >= 0 && !buf.substring(lt).contains('>')) {
      final String tail = buf.substring(lt);
      final bool plausible =
          tail.length <= _maxTagHold &&
          RegExp(r'^</?[A-Z0-9_ ]*$').hasMatch(tail);
      if (plausible && lt < safe) safe = lt;
    }
    return safe;
  }

  List<ZIffdSegment> _segment(String head) {
    final List<ZIffdSegment> out = <ZIffdSegment>[];
    int cursor = 0;
    for (final RegExpMatch m in _tagPattern.allMatches(head)) {
      if (m.start > cursor) {
        _emitText(out, head.substring(cursor, m.start), beforeTag: true);
      }
      out.add(
        ZIffdTagSegment(
          name: m.group(2)!,
          closing: m.group(1) == '/',
          argument: m.group(3),
        ),
      );
      cursor = m.end;
    }
    if (cursor < head.length) {
      _emitText(out, head.substring(cursor), beforeTag: false);
    }
    return out;
  }

  void _emitText(List<ZIffdSegment> out, String raw, {required bool beforeTag}) {
    String text = raw.replaceAll(kZIffdLineMarker, '\n');
    // `$` collé devant une balise (vector_store_service.py:394) : marqueur de
    // transport, pas du contenu. Ailleurs, un `$` est du contenu (LaTeX…).
    if (beforeTag && text.endsWith(r'$')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.isEmpty) return;
    out.add(ZIffdTextSegment(text));
  }
}
