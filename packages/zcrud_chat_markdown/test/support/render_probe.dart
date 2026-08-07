// Sondes de RENDU RÉEL — CR-IFFD-73.
//
// 🔴 Ces sondes lisent ce qui est PEINT (les `TextSpan` effectivement produits,
// avec leur graisse), jamais la présence d'un widget. La rétrospective de
// l'epic CHAT a mesuré 1 378 tests verts pendant que la revue établissait
// 3 HIGH / 9 MAJEUR : une garde qui asserte « le widget est monté » reste verte
// quand le rendu est faux.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un fragment de texte réellement peint, avec sa graisse.
class PaintedSpan {
  const PaintedSpan(this.text, this.weight, this.style);

  final String text;
  final FontWeight? weight;
  final FontStyle? style;

  @override
  String toString() => '"$text"(w=$weight,s=$style)';
}

/// Tous les fragments peints de l'arbre courant, dans l'ordre.
List<PaintedSpan> paintedSpans(WidgetTester tester) {
  final List<PaintedSpan> out = <PaintedSpan>[];
  for (final RichText r in tester.widgetList<RichText>(
    find.byType(RichText),
  )) {
    void visit(InlineSpan span) {
      if (span is TextSpan) {
        final String? t = span.text;
        if (t != null && t.isNotEmpty) {
          out.add(
            PaintedSpan(t, span.style?.fontWeight, span.style?.fontStyle),
          );
        }
        for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
          visit(child);
        }
      }
    }

    visit(r.text);
  }
  return out;
}

/// Le texte peint concaténé — ce qu'un œil humain lit à l'écran.
String paintedText(WidgetTester tester) =>
    paintedSpans(tester).map((PaintedSpan s) => s.text).join();

/// `true` si un fragment de texte est peint en GRAS.
bool hasBold(WidgetTester tester, String text) => paintedSpans(tester).any(
  (PaintedSpan s) =>
      s.text.contains(text) &&
      (s.weight == FontWeight.w700 || s.weight == FontWeight.bold),
);
