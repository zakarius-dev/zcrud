import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/src/presentation/z_folder_card.dart';
import 'package:zcrud_study/src/presentation/z_folder_card_chrome.dart';
import 'package:zcrud_study/src/presentation/z_subfolder_item_chrome.dart'
    show ZCountBadge, ZCountBadgeRow, ZCountBadgeSpec, ZSubfolderCountPill;

import '../support/z_sources.dart';

/// Clés RÉELLEMENT reçues par le résolveur, dans l'ordre des appels.
///
/// 🔴 Sans ce journal, la garde G5 était **tautologique** (CR epic VIS,
/// MEDIUM-2) : le témoin rendait `_first` pour `folder-a` et `_second` pour
/// **toute autre clé**. Si la production transmettait un index d'affichage au
/// lieu de l'identité, `folder-a` recevait `_second` avant ET après permutation
/// — les assertions d'égalité restaient donc vertes alors que la règle D3 était
/// violée. Une garde qui ne peut pas voir son propre défaut n'en est pas une.
final List<String> _clesRecues = <String>[];

/// Témoin **bijectif** : une couleur distincte par identité, dérivée du hash de
/// la clé. Deux identités différentes ne peuvent pas collisionner sur le même
/// dégradé, et une clé inattendue (un index, par exemple) est immédiatement
/// visible dans [_clesRecues].
ZGradientSpec? _stableGradient(ColorScheme _, String key) {
  _clesRecues.add(key);
  if (key.isEmpty) return null;
  final Color color = Color(0xFF000000 | (key.hashCode & 0x00FFFFFF));
  return ZGradientSpec(
    gradient: LinearGradient(
      colors: <Color>[color, color.withValues(alpha: .5)],
    ),
    onGradient: const Color(0xFFFFFFFF),
  );
}

ZcrudTheme _completeTheme() => const ZcrudTheme(
  accentBarHeight: 4,
  gradientBegin: AlignmentDirectional.centerStart,
  gradientEnd: AlignmentDirectional.centerEnd,
  countPillPadding: EdgeInsetsDirectional.symmetric(horizontal: 9),
  countPillRadius: Radius.circular(11),
  countPillIconSize: 18,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ZcrudTheme? theme,
  ZGradientResolver? resolver,
  TextDirection direction = TextDirection.ltr,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: ZcrudScope(
        theme: theme,
        gradientResolver: resolver,
        child: Directionality(
          textDirection: direction,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
}

Finder _gradientBars() => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).gradient != null,
);

Finder _pastilles() => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
);

LinearGradient _gradientFor(WidgetTester tester, String id) {
  final Container bar = tester.widget<Container>(
    find.descendant(
      of: find.byKey(ValueKey<String>(id)),
      matching: _gradientBars(),
    ),
  );
  return (bar.decoration! as BoxDecoration).gradient! as LinearGradient;
}

void main() {
  group('VIS-2 — barre d’accent opt-in', () {
    testWidgets('G3 — aucune configuration partielle ne construit la barre', (
      WidgetTester tester,
    ) async {
      const accent = ZFolderCardGradientAccent(gradientKey: 'folder-a');

      await _pump(tester, accent, resolver: _stableGradient);
      expect(_gradientBars(), findsNothing);

      await _pump(tester, accent, theme: _completeTheme());
      expect(_gradientBars(), findsNothing);

      await _pump(
        tester,
        accent,
        theme: const ZcrudTheme(
          accentBarHeight: 4,
          gradientBegin: AlignmentDirectional.centerStart,
        ),
        resolver: _stableGradient,
      );
      expect(_gradientBars(), findsNothing);

      await _pump(
        tester,
        const ZFolderCardGradientAccent(gradientKey: ''),
        theme: _completeTheme(),
        resolver: _stableGradient,
      );
      expect(_gradientBars(), findsNothing);

      await _pump(
        tester,
        accent,
        theme: _completeTheme(),
        resolver: _stableGradient,
      );
      expect(_gradientBars(), findsOneWidget);
      expect(tester.getSize(_gradientBars()).height, 4);
    });

    testWidgets('G4 — slot remplace seulement la pastille historique', (
      WidgetTester tester,
    ) async {
      const replacement = ValueKey<String>('replacement');
      const counts = ValueKey<String>('counts');
      const menu = ValueKey<String>('menu');
      await _pump(
        tester,
        const SizedBox(
          width: 220,
          height: 160,
          child: ZFolderCard(
            title: 'Titre',
            colorKey: 'folder-a',
            headerDecoration: SizedBox(key: replacement, width: 20, height: 4),
            counts: SizedBox(key: counts),
            menu: SizedBox(key: menu),
          ),
        ),
      );
      expect(find.byKey(replacement), findsOneWidget);
      expect(_pastilles(), findsNothing);
      expect(find.byKey(counts), findsOneWidget);
      expect(find.byKey(menu), findsOneWidget);

      await _pump(
        tester,
        const SizedBox(
          width: 220,
          height: 160,
          child: ZFolderCard(title: 'Titre', colorKey: 'folder-a'),
        ),
      );
      expect(_pastilles(), findsOneWidget);
      expect(tester.getSize(_pastilles()), const Size(14, 14));
    });

    testWidgets('G5 — identité persistante stable sous permutation et filtre', (
      WidgetTester tester,
    ) async {
      Widget cards(List<String> displayOrder) => Column(
        children: <Widget>[
          for (final String id in displayOrder)
            ZFolderCardGradientAccent(
              key: ValueKey<String>(id),
              gradientKey: id,
            ),
        ],
      );

      _clesRecues.clear();
      await _pump(
        tester,
        cards(<String>['folder-a', 'folder-b']),
        theme: _completeTheme(),
        resolver: _stableGradient,
      );
      final LinearGradient firstBefore = _gradientFor(tester, 'folder-a');
      final LinearGradient secondBefore = _gradientFor(tester, 'folder-b');

      // 🔴 CŒUR DE LA RÈGLE D3 : le résolveur reçoit l'IDENTITÉ PERSISTANTE,
      // jamais une position d'affichage. Sans cette assertion, transmettre
      // `displayIndex.toString()` ('0', '1') passerait inaperçu.
      expect(
        _clesRecues.toSet(),
        <String>{'folder-a', 'folder-b'},
        reason:
            'seules les identités persistantes doivent atteindre le résolveur ; '
            'clés observées : $_clesRecues',
      );
      for (final String cle in _clesRecues) {
        expect(
          int.tryParse(cle),
          isNull,
          reason: 'une clé purement numérique trahit un index d\'affichage',
        );
      }

      await _pump(
        tester,
        cards(<String>['folder-b', 'folder-a']),
        theme: _completeTheme(),
        resolver: _stableGradient,
      );
      expect(_gradientFor(tester, 'folder-a'), firstBefore);
      expect(_gradientFor(tester, 'folder-b'), secondBefore);
      expect(firstBefore, isNot(secondBefore));

      await _pump(
        tester,
        cards(<String>['folder-a']),
        theme: _completeTheme(),
        resolver: _stableGradient,
      );
      expect(_gradientFor(tester, 'folder-a'), firstBefore);
    });

    testWidgets('G9 — RTL conserve les extrémités directionnelles injectées', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZFolderCardGradientAccent(gradientKey: 'folder-a'),
        theme: _completeTheme(),
        resolver: _stableGradient,
        direction: TextDirection.rtl,
      );
      final LinearGradient gradient =
          (tester.widget<Container>(_gradientBars()).decoration!
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(gradient.begin, AlignmentDirectional.centerStart);
      expect(gradient.end, AlignmentDirectional.centerEnd);
    });
  });

  group('VIS-2 — badges de compte', () {
    const zero = ValueKey<String>('zero');
    const positive = ValueKey<String>('positive');

    List<ZCountBadgeSpec> specs() => const <ZCountBadgeSpec>[
      ZCountBadgeSpec(
        key: zero,
        count: 0,
        icon: Icon(Icons.folder),
        semanticLabel: 'Zéro dossiers',
      ),
      ZCountBadgeSpec(
        key: positive,
        count: 3,
        icon: Icon(Icons.folder),
        semanticLabel: 'Trois dossiers',
      ),
    ];

    testWidgets('G6 — zéro est absent structurellement avant construction', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZCountBadgeRow(badges: specs()));
      expect(find.byType(ZCountBadge), findsOneWidget);
      expect(find.byKey(zero), findsNothing);
      expect(find.byKey(positive), findsOneWidget);

      await _pump(
        tester,
        const ZCountBadgeRow(
          badges: <ZCountBadgeSpec>[
            ZCountBadgeSpec(
              key: zero,
              count: 0,
              icon: Icon(Icons.folder),
              semanticLabel: 'Zéro dossiers',
            ),
          ],
        ),
      );
      expect(find.byType(ZCountBadge), findsNothing);
      expect(find.byKey(zero), findsNothing);
    });

    testWidgets('G7 — chrome partagé suit les tokens de pill', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const Column(
          children: <Widget>[
            ZSubfolderCountPill(count: 3),
            ZCountBadge(
              count: 3,
              icon: Icon(Icons.folder),
              semanticLabel: 'Trois dossiers',
            ),
          ],
        ),
        theme: _completeTheme(),
      );
      final List<Container> pills = tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (Container container) =>
                container.decoration is BoxDecoration &&
                (container.decoration! as BoxDecoration).color ==
                    Theme.of(
                      tester.element(find.byType(ZCountBadge)),
                    ).colorScheme.secondaryContainer,
          )
          .toList();
      expect(pills, hasLength(2));
      for (final Container pill in pills) {
        expect(
          pill.padding,
          const EdgeInsetsDirectional.symmetric(horizontal: 9),
        );
        expect(
          (pill.decoration! as BoxDecoration).borderRadius,
          const BorderRadius.all(Radius.circular(11)),
        );
      }
      final SizedBox iconBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(ZCountBadge),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(iconBox.width, 18);
      expect(iconBox.height, 18);
    });

    testWidgets('G8 — une seule annonce et cible badge au moins 48 dp', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, ZCountBadgeRow(badges: specs()));
      expect(find.bySemanticsLabel('Trois dossiers'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(positive)).width,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(positive)).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.byKey(zero), findsNothing);
      handle.dispose();
    });
  });

  group('VIS-2 — frontières et direction', () {
    test(
      'G9/G10 — sources sans anti-modèle physique, métier ou dépendance',
      () {
        final String source =
            strippedOf('lib/src/presentation/z_folder_card_chrome.dart');
        final String badges =
            strippedOf('lib/src/presentation/z_subfolder_item_chrome.dart');
        for (final String forbidden in <String>[
          'Alignment.centerLeft',
          'Alignment.centerRight',
          'EdgeInsets.left',
          'EdgeInsets.right',
          'TextAlign.left',
          'TextAlign.right',
          'Colors.',
          'Color(0x',
          'flutter_riverpod',
          'package:get/',
          'package:provider/',
          'ZStudyFolder',
          'displayIndex',
        ]) {
          expect(
            '$source$badges'.contains(forbidden),
            isFalse,
            reason: forbidden,
          );
        }
      },
    );
  });
}
