// ES-1.2 (D1/AC3) — seam `ZColorKeyResolver` + `ZcrudScope.colorKeyResolver`,
// JUMEAU RÉEL d'`iconResolver`/`zResolveAdornmentIcon` (findings M2/M3/M4 du
// code-review) :
//  - M2 : la CHAÎNE existe et est testée (seam hôte prioritaire → repli du cœur
//    dérivé du `ColorScheme` → `null`, puis slot déterministe pour la variante
//    TOTALE) ; les signatures COMPOSENT (le typedef porte le `ColorScheme`).
//  - M3 : le cœur ne connaît AUCUNE clé sémantique study (aucune duplication de
//    la liste de `ZColorPalette` — `zcrud_core` ne peut pas voir le kernel,
//    AD-1) : son vocabulaire est l'enum `ZColorSlot` (rôles Material 3).
//  - M4 : toute résolution rend une PAIRE fond/`on-` (contraste garanti par le
//    `ColorScheme`, AD-13) ; aucun vert/ambre inventé.
//  - Zéro littéral hex dans le cœur : prouvé par `light != dark` (dérivation
//    réelle du `ColorScheme`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  final schemeLight = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  );
  final schemeDark = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  );

  group('ZColorSlot / ZColorPair — contraste garanti (M4, AD-13)', () {
    test('chaque slot rend une paire fond/on- dérivée du ColorScheme', () {
      for (final slot in ZColorSlot.values) {
        final pair = slot.of(schemeLight);
        expect(pair.color, isNotNull);
        expect(pair.onColor, isNotNull);
        // Un fond et son premier plan ne peuvent pas être la même couleur.
        expect(pair.onColor, isNot(equals(pair.color)));
      }
    });

    test('les slots sont des rôles *Container homogènes (fonds)', () {
      expect(
        ZColorSlot.primary.of(schemeLight),
        ZColorPair(
          color: schemeLight.primaryContainer,
          onColor: schemeLight.onPrimaryContainer,
        ),
      );
      expect(
        ZColorSlot.error.of(schemeLight),
        ZColorPair(
          color: schemeLight.errorContainer,
          onColor: schemeLight.onErrorContainer,
        ),
      );
      expect(
        ZColorSlot.neutral.of(schemeLight),
        ZColorPair(
          color: schemeLight.surfaceContainerHighest,
          onColor: schemeLight.onSurfaceVariant,
        ),
      );
    });

    test('dérivation réelle : light != dark (aucun littéral hex)', () {
      for (final slot in ZColorSlot.values) {
        expect(slot.of(schemeDark), isNot(equals(slot.of(schemeLight))));
      }
    });

    test('ZColorPair : égalité structurelle', () {
      const a = ZColorPair(
        color: Color.fromARGB(255, 1, 2, 3),
        onColor: Color.fromARGB(255, 4, 5, 6),
      );
      const b = ZColorPair(
        color: Color.fromARGB(255, 1, 2, 3),
        onColor: Color.fromARGB(255, 4, 5, 6),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('zColorSlotPair — repli TOTAL et défensif (AD-10)', () {
    test('index borné par modulo : négatif / hors-bornes / -1 -> jamais throw',
        () {
      for (final index in <int>[-1, -7, 0, 3, 42, 1 << 20]) {
        final pair = zColorSlotPair(schemeLight, index);
        expect(
          ZColorSlot.values.map((s) => s.of(schemeLight)).contains(pair),
          isTrue,
        );
      }
    });

    test('déterministe : même index -> même paire', () {
      expect(zColorSlotPair(schemeLight, 3), zColorSlotPair(schemeLight, 3));
      expect(
        zColorSlotPair(schemeLight, 3),
        zColorSlotPair(schemeLight, 3 + ZColorSlot.values.length),
      );
    });

    test('indices distincts -> couleurs distinctes (dans les bornes)', () {
      final pairs = <ZColorPair>{
        for (var i = 0; i < ZColorSlot.values.length; i++)
          zColorSlotPair(schemeLight, i),
      };
      expect(pairs.length, ZColorSlot.values.length);
    });
  });

  group('zDefaultColorKeyResolver — vocabulaire M3 UNIQUEMENT (M3/M4)', () {
    test('les noms de rôles Material 3 résolvent (dérivés du ColorScheme)', () {
      for (final slot in ZColorSlot.values) {
        expect(
          zDefaultColorKeyResolver(schemeLight, slot.name),
          slot.of(schemeLight),
        );
      }
    });

    test('AUCUNE clé sémantique study n\'est codée en dur dans le cœur', () {
      // Le cœur ne duplique PAS la liste de `ZColorPalette.defaultStudy()`
      // (M3) et n'invente ni vert « success » ni ambre « warning » (M4,
      // FR-26/NFR-S7) : ces clés relèvent du resolver INJECTÉ par l'app.
      for (final key in <String>['success', 'warning', 'info', 'danger']) {
        expect(zDefaultColorKeyResolver(schemeLight, key), isNull);
      }
    });

    test('clé inconnue / vide -> null (jamais de throw, AD-10)', () {
      expect(
        zDefaultColorKeyResolver(schemeLight, 'clé-totalement-inconnue'),
        isNull,
      );
      expect(zDefaultColorKeyResolver(schemeLight, ''), isNull);
    });

    test('EST un ZColorKeyResolver (les signatures COMPOSENT — M2)', () {
      const ZColorKeyResolver asSeam = zDefaultColorKeyResolver;
      expect(asSeam(schemeLight, 'primary'), ZColorSlot.primary.of(schemeLight));
    });
  });

  group('zResolveColorKey / zResolveColorKeyOrSlot — la CHAÎNE (M2)', () {
    ZColorPair? hostSuccess(ColorScheme scheme, String key) =>
        key == 'success' || key == 'primary'
            ? ZColorPair(color: scheme.inversePrimary, onColor: scheme.onSurface)
            : null;

    Future<T> pumpAndRead<T>(
      WidgetTester tester,
      ZColorKeyResolver? resolver,
      T Function(BuildContext context) read,
    ) async {
      late T value;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: schemeLight),
          home: ZcrudScope(
            colorKeyResolver: resolver,
            child: Builder(
              builder: (context) {
                value = read(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return value;
    }

    testWidgets('1) seam hôte PRIORITAIRE sur le repli du cœur', (tester) async {
      final pair = await pumpAndRead(
        tester,
        hostSuccess,
        (context) => zResolveColorKey(context, 'primary'),
      );
      // L'hôte gagne : ce n'est PAS le slot primaryContainer du cœur.
      expect(pair!.color, schemeLight.inversePrimary);
      expect(pair, isNot(equals(ZColorSlot.primary.of(schemeLight))));
    });

    testWidgets('1bis) l\'hôte fournit la sémantique que le cœur refuse',
        (tester) async {
      final pair = await pumpAndRead(
        tester,
        hostSuccess,
        (context) => zResolveColorKey(context, 'success'),
      );
      expect(pair, isNotNull); // alors que le repli du cœur rend `null`.
    });

    testWidgets('2) hôte muet sur la clé -> repli du cœur (ColorScheme)',
        (tester) async {
      final pair = await pumpAndRead(
        tester,
        hostSuccess,
        (context) => zResolveColorKey(context, 'tertiary'),
      );
      expect(pair, ZColorSlot.tertiary.of(schemeLight));
    });

    testWidgets('2bis) aucun scope du tout -> repli du cœur (non-cassant)',
        (tester) async {
      late ZColorPair? pair;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: schemeLight),
          home: Builder(
            builder: (context) {
              pair = zResolveColorKey(context, 'neutral');
              return const SizedBox();
            },
          ),
        ),
      );
      expect(pair, ZColorSlot.neutral.of(schemeLight));
    });

    testWidgets('3) clé inconnue de tous -> null (AD-10, jamais de throw)',
        (tester) async {
      final pair = await pumpAndRead(
        tester,
        hostSuccess,
        (context) => zResolveColorKey(context, 'warning'),
      );
      expect(pair, isNull);
    });

    testWidgets('4) variante TOTALE : repli sur le slot déterministe',
        (tester) async {
      final pair = await pumpAndRead(
        tester,
        hostSuccess,
        (context) => zResolveColorKeyOrSlot(context, 'warning', slotIndex: 3),
      );
      expect(pair, zColorSlotPair(schemeLight, 3));
      expect(pair, isNotNull);
    });

    testWidgets('4bis) variante TOTALE : la chaîne garde la priorité hôte',
        (tester) async {
      final pair = await pumpAndRead(
        tester,
        hostSuccess,
        (context) => zResolveColorKeyOrSlot(context, 'success', slotIndex: 0),
      );
      expect(pair.color, schemeLight.inversePrimary);
    });
  });

  group('ZcrudScope.colorKeyResolver — câblage (AC3)', () {
    testWidgets('injection lue depuis un widget descendant', (tester) async {
      ZColorPair? fakeResolver(ColorScheme scheme, String key) => key == 'primary'
          ? const ZColorPair(
              color: Color.fromARGB(255, 1, 2, 3),
              onColor: Color.fromARGB(255, 4, 5, 6),
            )
          : null;

      late ZcrudScope scope;
      await tester.pumpWidget(
        ZcrudScope(
          colorKeyResolver: fakeResolver,
          child: Builder(
            builder: (context) {
              scope = ZcrudScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(scope.colorKeyResolver, isNotNull);
      expect(
        scope.colorKeyResolver!(schemeLight, 'primary')!.color,
        const Color.fromARGB(255, 1, 2, 3),
      );
      expect(scope.colorKeyResolver!(schemeLight, 'inconnue'), isNull);
    });

    testWidgets('non-cassant : scope sans colorKeyResolver -> null par défaut',
        (tester) async {
      late ZcrudScope scope;
      await tester.pumpWidget(
        ZcrudScope(
          child: Builder(
            builder: (context) {
              scope = ZcrudScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(scope.colorKeyResolver, isNull);
    });

    testWidgets('updateShouldNotify déclenche sur changement de resolver',
        (tester) async {
      ZColorPair? resolverA(ColorScheme scheme, String key) => null;
      ZColorPair? resolverB(ColorScheme scheme, String key) => null;

      final widgetA = ZcrudScope(
        colorKeyResolver: resolverA,
        child: const SizedBox(),
      );
      final widgetB = ZcrudScope(
        colorKeyResolver: resolverB,
        child: const SizedBox(),
      );
      final widgetASame = ZcrudScope(
        colorKeyResolver: resolverA,
        child: const SizedBox(),
      );

      expect(widgetA.updateShouldNotify(widgetB), isTrue);
      expect(widgetA.updateShouldNotify(widgetASame), isFalse);
    });
  });
}
