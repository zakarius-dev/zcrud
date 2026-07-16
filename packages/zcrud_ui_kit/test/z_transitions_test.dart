import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

void main() {
  group('zSlideBeginOffset (fonction pure, sans BuildContext) — AC5 PIVOT', () {
    test('LTR entre depuis la fin (droite) → Offset(1, 0)', () {
      expect(zSlideBeginOffset(TextDirection.ltr), const Offset(1.0, 0.0));
    });

    test('RTL entre depuis la fin (gauche) → Offset(-1, 0)', () {
      expect(zSlideBeginOffset(TextDirection.rtl), const Offset(-1.0, 0.0));
    });

    test('l\'offset horizontal change de SIGNE entre LTR et RTL (inversion)',
        () {
      final ltr = zSlideBeginOffset(TextDirection.ltr);
      final rtl = zSlideBeginOffset(TextDirection.rtl);
      expect(ltr.dx, -rtl.dx);
      expect(ltr.dy, 0.0);
      expect(rtl.dy, 0.0);
    });
  });

  group('ZRouteTransition (enum > bool) — AC6', () {
    test('expose exactement slide et fade', () {
      expect(ZRouteTransition.values, [
        ZRouteTransition.slide,
        ZRouteTransition.fade,
      ]);
    });
  });

  group('zPageRoute → PageRouteBuilder neutre — AC6', () {
    test('transition slide (défaut) retourne un PageRouteBuilder', () {
      final route = zPageRoute<void>(builder: (_) => const SizedBox());
      expect(route, isA<PageRouteBuilder<void>>());
      expect(route, isA<PageRoute<void>>());
    });

    test('transition fade retourne un PageRouteBuilder', () {
      final route = zPageRoute<int>(
        builder: (_) => const SizedBox(),
        transition: ZRouteTransition.fade,
      );
      expect(route, isA<PageRouteBuilder<int>>());
    });

    test('durée/courbe injectées sont appliquées à la route', () {
      final route = zPageRoute<void>(
        builder: (_) => const SizedBox(),
        duration: const Duration(milliseconds: 500),
      );
      expect(route.transitionDuration, const Duration(milliseconds: 500));
    });
  });

  group('ZPageTransitionsBuilder — AC6', () {
    test('est un PageTransitionsBuilder natif enregistrable', () {
      const builder = ZPageTransitionsBuilder();
      expect(builder, isA<PageTransitionsBuilder>());
      // Enregistrable dans un PageTransitionsTheme sans lever.
      final theme = PageTransitionsTheme(
        builders: const {TargetPlatform.android: ZPageTransitionsBuilder()},
      );
      expect(theme, isNotNull);
    });
  });
}
