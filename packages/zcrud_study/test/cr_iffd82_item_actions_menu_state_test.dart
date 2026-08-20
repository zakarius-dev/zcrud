// CR-IFFD-82 — le défaut de ZItemActionsMenu est une grille déclarable et
// ZItemAction porte l'état de l'artefact sans faire de la couleur son seul
// canal. Les gardes de géométrie lisent les positions RÉELLES ; la garde de
// cible lit le delegate DÉCLARÉ (jamais le plancher implicite de Material).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

const List<String> _labels = <String>[
  'ACTION-0',
  'ACTION-1',
  'ACTION-2',
  'ACTION-3',
  'ACTION-4',
  'ACTION-5',
];

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: theme,
  home: ZcrudScope(
    child: Scaffold(body: Center(child: child)),
  ),
);

List<ZItemAction> _actions({int length = 6}) => <ZItemAction>[
  for (int index = 0; index < length; index++)
    ZItemAction(
      kind: ZItemActionKind.custom,
      id: 'action-$index',
      label: _labels[index],
      icon: Icons.circle_outlined,
      onSelected: () {},
    ),
];

Future<void> _open(
  WidgetTester tester, {
  int? crossAxisCount,
  List<ZItemAction>? actions,
  ThemeData? theme,
}) async {
  final List<ZItemAction> resolvedActions = actions ?? _actions();
  await tester.pumpWidget(
    _app(
      crossAxisCount == null
          ? ZItemActionsMenu(actions: resolvedActions)
          : ZItemActionsMenu(
              crossAxisCount: crossAxisCount,
              actions: resolvedActions,
            ),
      theme: theme,
    ),
  );
  await tester.tap(find.byType(ZItemActionsMenu));
  await tester.pumpAndSettle();
}

Offset _positionOf(WidgetTester tester, String label) =>
    tester.getTopLeft(find.text(label));

void main() {
  group('CR-IFFD-82 A — géométrie déclarée', () {
    testWidgets('🔴 défaut sans menuBuilder ⇒ grille de TROIS colonnes', (
      tester,
    ) async {
      await _open(tester);

      final Offset p0 = _positionOf(tester, _labels[0]);
      final Offset p1 = _positionOf(tester, _labels[1]);
      final Offset p2 = _positionOf(tester, _labels[2]);
      final Offset p3 = _positionOf(tester, _labels[3]);
      expect(p0.dy, closeTo(p1.dy, 0.5));
      expect(p1.dy, closeTo(p2.dy, 0.5));
      expect(
        p3.dy,
        greaterThan(p0.dy),
        reason: 'la quatrième cellule doit commencer la deuxième ligne',
      );

      final GridView grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(
        delegate.mainAxisExtent,
        greaterThanOrEqualTo(kZMenuMinTapTarget),
        reason:
            'la garde lit le plancher DÉCLARÉ par gridDelegate, jamais les '
            '48 dp que PopupMenuItem imposerait de toute façon',
      );
      final SizedBox declaredGridBox = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(GridView),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(
        declaredGridBox.width! / delegate.crossAxisCount,
        greaterThanOrEqualTo(kZMenuMinTapTarget),
        reason:
            'la largeur déclarée de la grille doit réserver au moins 48 dp '
            'par colonne, indépendamment du plancher Material',
      );
      final String source = File(
        'lib/src/presentation/z_item_actions_menu.dart',
      ).readAsStringSync();
      expect(
        source,
        contains(RegExp(r'gridDelegate:\s*ZMenuEntryTile\.gridDelegate\(')),
        reason:
            'le plancher doit venir du mécanisme structurel partagé de '
            'zcrud_menu, jamais d’un second delegate local',
      );
    });

    testWidgets('🔴 crossAxisCount: 2 est respecté au point d’appel', (
      tester,
    ) async {
      await _open(tester, crossAxisCount: 2);

      final Offset p0 = _positionOf(tester, _labels[0]);
      final Offset p1 = _positionOf(tester, _labels[1]);
      final Offset p2 = _positionOf(tester, _labels[2]);
      expect(p0.dy, closeTo(p1.dy, 0.5));
      expect(p2.dy, greaterThan(p0.dy));
      final GridView grid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
    });

    testWidgets(
      '🔴 crossAxisCount: 1 garde la voie de retour vers la colonne',
      (tester) async {
        await _open(tester, crossAxisCount: 1, actions: _actions(length: 3));

        final Offset p0 = _positionOf(tester, _labels[0]);
        final Offset p1 = _positionOf(tester, _labels[1]);
        final Offset p2 = _positionOf(tester, _labels[2]);
        expect(p0.dx, closeTo(p1.dx, 0.5));
        expect(p1.dx, closeTo(p2.dx, 0.5));
        expect(p1.dy, greaterThan(p0.dy));
        expect(p2.dy, greaterThan(p1.dy));
      },
    );

    testWidgets('toutes les actions absentes ⇒ déclencheur toujours inerte', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ZItemActionsMenu(
            actions: <ZItemAction>[
              ZItemAction(
                kind: ZItemActionKind.custom,
                label: 'ABSENTE',
                icon: Icons.block,
              ),
            ],
          ),
        ),
      );

      final PopupMenuButton<ZMenuEntry> trigger = tester.widget(
        find.byType(PopupMenuButton<ZMenuEntry>),
      );
      expect(trigger.enabled, isFalse);
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing);
    });
  });

  group('CR-IFFD-82 B — état et compte', () {
    testWidgets('🔴 présent ⇒ teinte lisible ; absent ⇒ teinte de repos', (
      tester,
    ) async {
      const String present = 'PRESENT-ACTION';
      const String absent = 'ABSENT-ACTION';
      final ThemeData baseTheme = ThemeData.light(useMaterial3: true);
      await _open(
        tester,
        theme: baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(
            // Cas discriminant : la teinte brute se confond avec la surface ;
            // seul zReadableTintOn peut tenir le plancher.
            primary: baseTheme.colorScheme.surfaceContainer,
          ),
        ),
        actions: <ZItemAction>[
          ZItemAction(
            kind: ZItemActionKind.custom,
            id: 'present',
            label: present,
            icon: Icons.auto_awesome,
            state: ZItemActionState.present,
            stateSemanticLabel: 'EXISTE-DEJA',
            onSelected: () {},
          ),
          ZItemAction(
            kind: ZItemActionKind.custom,
            id: 'absent',
            label: absent,
            icon: Icons.add_box_outlined,
            state: ZItemActionState.absent,
            stateSemanticLabel: 'RESTE-A-CREER',
            onSelected: () {},
          ),
        ],
      );

      final BuildContext presentContext = tester.element(
        find.byIcon(Icons.auto_awesome),
      );
      final BuildContext absentContext = tester.element(
        find.byIcon(Icons.add_box_outlined),
      );
      final Color presentTint = IconTheme.of(presentContext).color!;
      final Color restTint = IconTheme.of(absentContext).color!;
      expect(
        presentTint,
        isNot(restTint),
        reason:
            'Expected: teinte de présence distincte\n'
            'Actual: même teinte que l’état absent',
      );
      final ThemeData material = Theme.of(presentContext);
      final Color surface =
          PopupMenuTheme.of(presentContext).color ??
          material.colorScheme.surfaceContainer;
      expect(
        zContrastRatio(presentTint, surface),
        greaterThanOrEqualTo(kZNonTextMinContrast),
      );

      final String source = File(
        'lib/src/presentation/z_item_actions_menu.dart',
      ).readAsStringSync();
      expect(source, isNot(contains(RegExp(r'\bColors\.'))));
      expect(source, isNot(contains(RegExp(r'\bColor(?:\.|\s*\()'))));
      expect(source, contains('zReadableTintOn('));
    });

    testWidgets('🔴 compte positif ⇒ badge exact ; 0/null ⇒ aucun badge', (
      tester,
    ) async {
      await _open(
        tester,
        actions: <ZItemAction>[
          ZItemAction(
            kind: ZItemActionKind.custom,
            id: 'seven',
            label: 'SEPT',
            icon: Icons.filter_7,
            count: 7,
            onSelected: () {},
          ),
          ZItemAction(
            kind: ZItemActionKind.custom,
            id: 'thousand',
            label: 'MILLE',
            icon: Icons.numbers,
            count: 1000,
            onSelected: () {},
          ),
          ZItemAction(
            kind: ZItemActionKind.custom,
            id: 'zero',
            label: 'ZERO',
            icon: Icons.filter_none,
            count: 0,
            onSelected: () {},
          ),
          ZItemAction(
            kind: ZItemActionKind.custom,
            id: 'null',
            label: 'SANS-COMPTE',
            icon: Icons.remove,
            onSelected: () {},
          ),
        ],
      );

      Finder badgeFor(String label) =>
          find.ancestor(of: find.text(label), matching: find.byType(Badge));
      expect(badgeFor('SEPT'), findsOneWidget);
      expect(badgeFor('MILLE'), findsOneWidget);
      expect(badgeFor('ZERO'), findsNothing);
      expect(badgeFor('SANS-COMPTE'), findsNothing);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('999+'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('🔴 état annoncé pour absent, en cours et présent', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      const states = <(ZItemActionState, String)>[
        (ZItemActionState.absent, 'RESTE-A-CREER'),
        (ZItemActionState.inProgress, 'CREATION-EN-COURS'),
        (ZItemActionState.present, 'EXISTE-DEJA'),
      ];
      await _open(
        tester,
        actions: <ZItemAction>[
          for (int index = 0; index < states.length; index++)
            ZItemAction(
              kind: ZItemActionKind.custom,
              id: 'state-$index',
              label: 'ETAT-$index',
              icon: Icons.info_outline,
              state: states[index].$1,
              stateSemanticLabel: states[index].$2,
              onSelected: () {},
            ),
        ],
      );

      for (int index = 0; index < states.length; index++) {
        final Finder merge = find
            .ancestor(
              of: find.text('ETAT-$index'),
              matching: find.byType(MergeSemantics),
            )
            .first;
        final data = tester.getSemantics(merge).getSemanticsData();
        expect(
          data.value,
          contains(states[index].$2),
          reason: 'l’état doit être annoncé, pas seulement peint',
        );
        expect(data.label, contains('ETAT-$index'));
      }
      handle.dispose();
    });

    testWidgets('🔴 sans état ni compte ⇒ aucun ajout au rendu historique', (
      tester,
    ) async {
      await _open(tester, actions: _actions(length: 1));

      final Finder grid = find.byType(GridView);
      expect(
        find.descendant(of: grid, matching: find.byType(MergeSemantics)),
        findsNothing,
      );
      expect(
        find.descendant(of: grid, matching: find.byType(Badge)),
        findsNothing,
      );
      final BuildContext iconContext = tester.element(
        find.byIcon(Icons.circle_outlined),
      );
      final BuildContext gridContext = tester.element(grid);
      expect(
        IconTheme.of(iconContext).color,
        IconTheme.of(gridContext).color,
        reason: 'une action sans état ne reçoit aucune teinte additionnelle',
      );
    });
  });
}
