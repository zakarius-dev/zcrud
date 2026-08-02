/// Surlignage de recherche **partagé** — `ZChatHighlightedText` (CR-IFFD-39).
///
/// ## 🔴 Pourquoi ceci est UN SEUL fichier
///
/// Mesuré chez lex : **trois** implémentations différentes du même surlignage
/// cohabitent — l'utilitaire partagé
/// `presentation/utils/search_highlight.dart:38-103`, la boucle `indexOf`
/// recopiée dans `widgets/chat/search_result_tile.dart:95-116` (qui **n'utilise
/// pas** l'utilitaire), et une troisième dans `widgets/search_content.dart:325`.
/// Elles ont déjà divergé : celle de la tuile de recherche ne surligne que le
/// **snippet**, jamais le titre (`search_result_tile.dart:39-46`) — alors que la
/// moitié des résultats vient d'un filtre client-side **sur le titre**
/// (`conversations_screen.dart:159-168`), qui ne produit aucun `matching_messages`
/// et donc **aucun surlignage du tout**.
///
/// Le socle n'expose donc pas « un widget qui surligne » : il expose **le calcul
/// des plages** ([zChatHighlightRanges], pur et testable) et **le seul widget qui
/// les rend**. Titre et sous-titre passent tous les deux par lui.
///
/// ## Aucun style codé en dur (FR-26)
///
/// La portion surlignée n'est pas « en jaune » ni « en gras 700 » : elle prend
/// la graisse d'emphase du thème injecté (`ZcrudTheme.floatingLabelWeight`),
/// appliquée par `copyWith` sur le style **hérité**. Le socle ne fabrique aucun
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

/// Plages de [text] correspondant à [term] — **insensible à la casse**, sans
/// chevauchement, dans l'ordre.
///
/// Défensif (AD-10) : [term] vide ou plus long que [text] ⇒ liste vide ; jamais
/// d'exception, jamais de boucle infinie (le curseur avance **toujours** d'au
/// moins la longueur du terme).
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
      // 🔴 Le lecteur d'écran doit entendre la phrase ENTIÈRE, pas une suite de
      // fragments découpés par le surlignage : le découpage est VISUEL.
      semanticsLabel: text,
    );
  }
}
