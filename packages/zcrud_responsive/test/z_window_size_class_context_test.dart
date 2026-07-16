// Widget test de `ZWindowSizeClass.of(context)` (AC5) : dérive la classe depuis
// une MediaQuery simulée (500/700/1000 → compact/medium/expanded) et reste
// correct sous `Directionality.rtl` (mesure directionnellement neutre — AD-13).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

/// Monte [child] sous une `MediaQuery` de largeur [width] et une
/// [textDirection] données.
Widget _harness({
  required double width,
  required TextDirection textDirection,
  required Widget child,
}) {
  return Directionality(
    textDirection: textDirection,
    child: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: child,
    ),
  );
}

void main() {
  group('ZWindowSizeClass.of(context) — MediaQuery.sizeOf', () {
    for (final (width, expected) in <(double, ZWindowSizeClass)>[
      (500, ZWindowSizeClass.compact),
      (700, ZWindowSizeClass.medium),
      (1000, ZWindowSizeClass.expanded),
    ]) {
      testWidgets('largeur $width → $expected', (tester) async {
        late ZWindowSizeClass captured;
        await tester.pumpWidget(
          _harness(
            width: width,
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                captured = ZWindowSizeClass.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(captured, expected);
      });
    }
  });

  group('RTL-safe (AD-13/NFR-U4) — mesure directionnellement neutre', () {
    for (final (width, expected) in <(double, ZWindowSizeClass)>[
      (500, ZWindowSizeClass.compact),
      (700, ZWindowSizeClass.medium),
      (1000, ZWindowSizeClass.expanded),
    ]) {
      testWidgets('rtl largeur $width → $expected (inchangé)', (tester) async {
        late ZWindowSizeClass captured;
        await tester.pumpWidget(
          _harness(
            width: width,
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) {
                captured = ZWindowSizeClass.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(captured, expected);
      });
    }
  });
}
