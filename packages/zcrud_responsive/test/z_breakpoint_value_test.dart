// Tests PURS de `ZBreakpointValue<T>` (AC4, D2) : `valueAt` par palier, cascade
// mobile-first, `resolve(width)` aux bornes Bootstrap (réutilisées de zcrud_core),
// défauts sûrs (NaN/négatif → xs) et égalité par valeur.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

void main() {
  group('valueAt — palier exact', () {
    const v = ZBreakpointValue<String>(
      xs: 'xs',
      sm: 'sm',
      md: 'md',
      lg: 'lg',
      xl: 'xl',
    );

    test('chaque palier renseigné retourne sa valeur', () {
      expect(v.valueAt(ZBreakpoint.xs), 'xs');
      expect(v.valueAt(ZBreakpoint.sm), 'sm');
      expect(v.valueAt(ZBreakpoint.md), 'md');
      expect(v.valueAt(ZBreakpoint.lg), 'lg');
      expect(v.valueAt(ZBreakpoint.xl), 'xl');
    });
  });

  group('valueAt — cascade mobile-first (repli vers le palier inférieur)', () {
    test('sm/lg absents → héritent de xs/md', () {
      const v = ZBreakpointValue<String>(xs: 'xs', md: 'md');
      expect(v.valueAt(ZBreakpoint.xs), 'xs');
      expect(v.valueAt(ZBreakpoint.sm), 'xs'); // sm absent → xs
      expect(v.valueAt(ZBreakpoint.md), 'md');
      expect(v.valueAt(ZBreakpoint.lg), 'md'); // lg absent → md
      expect(v.valueAt(ZBreakpoint.xl), 'md'); // xl absent → md
    });

    test('seul xs renseigné → tous les paliers héritent de xs', () {
      const v = ZBreakpointValue<int>(xs: 7);
      for (final bp in ZBreakpoint.values) {
        expect(v.valueAt(bp), 7);
      }
    });

    test('xl renseigné seul au-dessus → md hérite de sm', () {
      const v = ZBreakpointValue<int>(xs: 1, sm: 2, xl: 5);
      expect(v.valueAt(ZBreakpoint.md), 2); // md absent → sm
      expect(v.valueAt(ZBreakpoint.lg), 2); // lg absent → sm
      expect(v.valueAt(ZBreakpoint.xl), 5);
    });

    test('constructeur .all applique la valeur uniformément', () {
      const v = ZBreakpointValue<double>.all(4);
      for (final bp in ZBreakpoint.values) {
        expect(v.valueAt(bp), 4);
      }
    });
  });

  group('resolve(width) — bornes Bootstrap réutilisées de zcrud_core', () {
    const v = ZBreakpointValue<String>(
      xs: 'xs',
      sm: 'sm',
      md: 'md',
      lg: 'lg',
      xl: 'xl',
    );

    test('575 → xs, 576 → sm (seuil sm)', () {
      expect(v.resolve(575), 'xs');
      expect(v.resolve(576), 'sm');
    });

    test('1199 → lg, 1200 → xl (seuil xl)', () {
      expect(v.resolve(1199), 'lg');
      expect(v.resolve(1200), 'xl');
    });

    test('resolve applique la cascade (md absent → sm)', () {
      const w = ZBreakpointValue<String>(xs: 'xs', sm: 'sm');
      expect(w.resolve(800), 'sm'); // 800 → md → hérite sm
    });
  });

  group('resolve — défauts sûrs (AD-10/D4, jamais de throw)', () {
    const v = ZBreakpointValue<String>(xs: 'base', xl: 'xl');

    test('NaN → xs (via ZResponsiveBreakpoints.of du cœur)', () {
      expect(v.resolve(double.nan), 'base');
    });

    test('négatif → xs', () {
      expect(v.resolve(-100), 'base');
    });

    test('0 → xs', () {
      expect(v.resolve(0), 'base');
    });

    test('infinity → xl', () {
      expect(v.resolve(double.infinity), 'xl');
    });

    test('ne lève jamais', () {
      for (final w in <double>[double.nan, -1, 0, double.infinity, 576, 1200]) {
        expect(() => v.resolve(w), returnsNormally);
      }
    });
  });

  group('== / hashCode par valeur (@immutable)', () {
    test('deux instances de mêmes champs sont égales', () {
      const a = ZBreakpointValue<int>(xs: 1, md: 3);
      const b = ZBreakpointValue<int>(xs: 1, md: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('un champ différent brise l’égalité', () {
      const a = ZBreakpointValue<int>(xs: 1, md: 3);
      const c = ZBreakpointValue<int>(xs: 1, md: 4);
      expect(a, isNot(c));
    });

    test('types génériques distincts ne sont pas égaux', () {
      const a = ZBreakpointValue<int>(xs: 1);
      const b = ZBreakpointValue<num>(xs: 1);
      expect(a, isNot(b));
    });
  });
}
