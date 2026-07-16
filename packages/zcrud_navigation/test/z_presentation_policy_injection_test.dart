// Tests PUR-DART (sans `BuildContext`) de la SUBSTITUABILITÉ de la politique :
// une politique custom (fabrique `.from` ET sous-classe) est respectée par
// `resolve()` — prouve AD-6 (injectable) et AD-4 (non-`sealed`, extensible hors
// du package).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

/// Politique custom définie **hors** du package (prouve le non-`sealed`, AD-4) :
/// tout est présenté en `page` pleine, quel que soit le breakpoint.
class _AlwaysPagePolicy extends ZPresentationPolicy {
  const _AlwaysPagePolicy();

  @override
  ZEditionPresentation resolve(
    ZWindowSizeClass sizeClass, {
    ZFormWeight formWeight = ZFormWeight.light,
  }) =>
      ZEditionPresentation.page;
}

void main() {
  group('ZPresentationPolicy.from — injection par fonction (AD-6)', () {
    test('un resolver custom (compact → dialog) est respecté', () {
      final policy = ZPresentationPolicy.from(
        (sizeClass, {formWeight = ZFormWeight.light}) =>
            sizeClass == ZWindowSizeClass.compact
                ? ZEditionPresentation.dialog
                : ZEditionPresentation.page,
      );

      // La règle custom PRIME sur le défaut M3 (qui donnerait `sheet`).
      expect(
        policy.resolve(ZWindowSizeClass.compact),
        ZEditionPresentation.dialog,
      );
      expect(
        policy.resolve(ZWindowSizeClass.medium),
        ZEditionPresentation.page,
      );
    });

    test('le resolver custom reçoit bien le `formWeight`', () {
      final policy = ZPresentationPolicy.from(
        (sizeClass, {formWeight = ZFormWeight.light}) =>
            formWeight == ZFormWeight.heavy
                ? ZEditionPresentation.page
                : ZEditionPresentation.sheet,
      );

      expect(
        policy.resolve(ZWindowSizeClass.medium, formWeight: ZFormWeight.heavy),
        ZEditionPresentation.page,
      );
      expect(
        policy.resolve(ZWindowSizeClass.medium, formWeight: ZFormWeight.light),
        ZEditionPresentation.sheet,
      );
    });
  });

  group('ZPresentationPolicy — sous-classe (AD-4, non-sealed)', () {
    test('une sous-classe hors package substitue le mapping', () {
      const ZPresentationPolicy policy = _AlwaysPagePolicy();

      for (final sizeClass in ZWindowSizeClass.values) {
        for (final weight in ZFormWeight.values) {
          expect(
            policy.resolve(sizeClass, formWeight: weight),
            ZEditionPresentation.page,
          );
        }
      }
    });

    test('la sous-classe reste polymorphe via le type de base', () {
      // Prouve la substituabilité : consommée derrière le type `ZPresentationPolicy`.
      final ZPresentationPolicy injected = const _AlwaysPagePolicy();
      expect(
        injected.resolve(ZWindowSizeClass.compact),
        isNot(const ZPresentationPolicy().resolve(ZWindowSizeClass.compact)),
      );
    });
  });
}
