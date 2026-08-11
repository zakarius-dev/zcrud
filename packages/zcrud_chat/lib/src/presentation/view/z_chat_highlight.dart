/// Surlignage de recherche partagé.
///
/// ## Pourquoi ceci est un seul fichier
///
/// Une implémentation de surlignage dupliquée entre le titre et le
/// sous-titre d'une conversation diverge tôt ou tard — typiquement, l'une des
/// deux copies finit par ne surligner que l'une des deux surfaces, laissant
/// l'autre sans retour visuel alors qu'elle correspond bien à la recherche.
/// Le socle n'expose donc pas « un widget qui surligne » : il expose le
/// calcul des plages ([zChatHighlightRanges], pur et testable) et le seul
/// widget qui les rend. Titre et sous-titre passent tous les deux par lui.
///
/// ## Aucun style codé en dur
///
/// La portion surlignée ne prend ni couleur ni graisse fixe : elle prend la
/// graisse d'emphase du thème injecté (`ZcrudTheme.floatingLabelWeight`),
/// appliquée par `copyWith` sur le style hérité. Le socle ne fabrique aucun
/// `TextStyle`, donc aucune couleur.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Une plage `[start, end)` de [ZChatHighlightRange.start] à
/// [ZChatHighlightRange.end] dans le texte source.
@immutable
class ZChatHighlightRange {
  /// Construit une plage.
  const ZChatHighlightRange(this.start, this.end);

  /// Premier index inclus.
  final int start;

  /// Premier index exclu.
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatHighlightRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ZChatHighlightRange($start, $end)';
}

/// Plages de [text] correspondant à [term] — insensible à la casse, sans
/// chevauchement, dans l'ordre.
///
/// Défensif (invariant AD-10) : un [term] vide ou plus long que [text] donne
/// une liste vide ; jamais d'exception, jamais de boucle infinie (le curseur
/// avance toujours d'au moins la longueur du terme).
List<ZChatHighlightRange> zChatHighlightRanges(String text, String term) {
  final String needle = term.trim().toLowerCase();
  if (needle.isEmpty || needle.length > text.length) {
    return const <ZChatHighlightRange>[];
  }
  final String haystack = text.toLowerCase();
  final List<ZChatHighlightRange> out = <ZChatHighlightRange>[];
  int cursor = 0;
  while (cursor <= haystack.length - needle.length) {
    final int hit = haystack.indexOf(needle, cursor);
    if (hit < 0) break;
    out.add(ZChatHighlightRange(hit, hit + needle.length));
    cursor = hit + needle.length;
  }
  return out;
}

/// Rend [text] en mettant [term] en évidence — **le seul** site de surlignage.
///
/// Sans [term] (ou sans correspondance), rend un `Text` ordinaire : le
/// surlignage est une **décoration additive**, jamais une seconde tuile.
class ZChatHighlightedText extends StatelessWidget {
  /// Construit un texte surligné.
  const ZChatHighlightedText({
    required this.text,
    this.term = '',
    this.maxLines,
    this.strong = false,
    super.key,
  });

  /// Le texte rendu — une **donnée** de l'utilisateur, jamais un libellé
  /// d'interface (il n'a donc rien à faire dans `ZcrudLabels`).
  final String text;

  /// Le terme cherché, ou `''` (aucun surlignage).
  final String term;

  /// Nombre maximal de lignes, ou `null` (illimité).
  final int? maxLines;

  /// `true` ⇒ tout le texte prend la graisse d'emphase du thème.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final TextStyle base = DefaultTextStyle.of(context).style;
    final TextStyle style = strong
        ? base.copyWith(fontWeight: theme.floatingLabelWeight)
        : base;
    final List<ZChatHighlightRange> ranges = zChatHighlightRanges(text, term);
    if (ranges.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        // AD-13 : jamais `TextAlign.left`.
        textAlign: TextAlign.start,
      );
    }
    final TextStyle hit = style.copyWith(
      fontWeight: theme.floatingLabelWeight,
    );
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final ZChatHighlightRange r in ranges) {
      if (r.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, r.start)));
      }
      spans.add(TextSpan(text: text.substring(r.start, r.end), style: hit));
      cursor = r.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: TextAlign.start,
      // Le lecteur d'écran doit entendre la phrase entière, pas une suite de
      // fragments découpés par le surlignage : le découpage est visuel.
      semanticsLabel: text,
    );
  }
}
