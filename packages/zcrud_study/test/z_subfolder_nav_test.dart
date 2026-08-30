/// Gardes de la bascule responsive de navigation de sous-dossiers
/// (`ZSubfolderNav`) et de son INERTIE côté `ZStudyFolderDetail`.
///
/// La signature d'arbre utilisée ici est volontairement SANS hash d'élément :
/// elle ne dépend que des `runtimeType` et de quelques propriétés de layout,
/// donc elle est reproductible d'un run à l'autre et peut être figée en dur.
///
/// Les deux goldens `_kNarrowAssembly`/`_kWideAssembly` ont été RELEVÉS sur la
/// version antérieure à l'extraction (assemblage rendu par `ZResponsiveLayout`
/// à l'intérieur de `ZStudyFolderDetail`) puis figés : ils rougissent si
/// l'extraction déplace, ajoute ou retire quoi que ce soit dans l'assemblage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart'
    show ZWindowSizeThresholds;
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

/// Signature STRUCTURELLE du sous-arbre enraciné en [root], bornée à [maxDepth].
///
/// Sans hash ni adresse : `runtimeType` + largeur des `SizedBox` + `flex` des
/// `Expanded` + géométrie déclarée de la barre latérale. C'est ce qui rend
/// l'égalité stricte tenable entre deux versions du code.
String treeSignature(WidgetTester tester, Finder root, {int maxDepth = 5}) {
  final buffer = StringBuffer();
  void visit(Element element, int depth) {
    if (depth > maxDepth) return;
    final Widget w = element.widget;
    buffer.write('  ' * depth);
    buffer.write(w.runtimeType);
    if (w is SizedBox) {
      buffer.write('(w=${w.width}, h=${w.height})');
    } else if (w is Expanded) {
      buffer.write('(flex=${w.flex})');
    } else if (w is ZSubfolderSidebar) {
      buffer.write(
        '(collapsed=${w.collapsed}, width=${w.width}, '
        'min=${w.minWidth}, max=${w.maxWidth})',
      );
    }
    buffer.writeln();
    element.visitChildren((child) => visit(child, depth + 1));
  }

  visit(tester.element(root), 0);
  return buffer.toString();
}

/// Racine de l'ASSEMBLAGE étroit : la `Column` la plus proche au-dessus de la
/// surface étroite.
Finder get narrowAssembly => find
    .ancestor(
      of: find.byType(ZSubfolderNarrowNav),
      matching: find.byType(Column),
    )
    .first;

/// Racine de l'ASSEMBLAGE large : la `Row` la plus proche au-dessus de la barre
/// latérale.
Finder get wideAssembly => find
    .ancestor(of: find.byType(ZSubfolderSidebar), matching: find.byType(Row))
    .first;

/// Golden relevé AVANT extraction — assemblage étroit.
const String _kNarrowAssembly = '''
Column
  ZSubfolderNarrowNav
    ZSubfolderSelectorBar
      ZSubfolderLayoutScope
        Column
          Row
  Expanded(flex=1)
    ValueListenableBuilder<String?>
      ZSectionedStudyLayout
        ListView
          PrimaryScrollController
''';

/// Golden relevé AVANT extraction — assemblage large.
const String _kWideAssembly = '''
Row
  ValueListenableBuilder<bool>
    ValueListenableBuilder<double>
      SizedBox(w=300.0, h=null)
        ZSubfolderSidebar(collapsed=false, width=300.0, min=300.0, max=300.0)
          ZSubfolderLayoutScope
  Expanded(flex=1)
    ValueListenableBuilder<String?>
      ZSectionedStudyLayout
        ListView
          PrimaryScrollController
''';

void main() {
  group("CR-87 — inertie d'arbre de ZStudyFolderDetail", () {
    testWidgets('assemblage ÉTROIT (599 dp) — signature STRICTEMENT figée', (
      tester,
    ) async {
      await setScreen(tester, 599, 900);
      await pumpDetail(tester);
      expect(treeSignature(tester, narrowAssembly), _kNarrowAssembly);
    });

    testWidgets('assemblage LARGE (600 dp) — signature STRICTEMENT figée', (
      tester,
    ) async {
      await setScreen(tester, 600, 900);
      await pumpDetail(tester);
      expect(treeSignature(tester, wideAssembly), _kWideAssembly);
    });

    testWidgets('borne EXACTE : 599 ⇒ étroit, 600 et 601 ⇒ large', (
      tester,
    ) async {
      await setScreen(tester, 599, 900);
      await pumpDetail(tester);
      expect(find.byType(ZSubfolderNarrowNav), findsOneWidget);
      expect(find.byType(ZSubfolderSidebar), findsNothing);

      for (final double w in <double>[600, 601]) {
        await setScreen(tester, w, 900);
        await pumpDetail(tester);
        expect(find.byType(ZSubfolderSidebar), findsOneWidget);
        expect(find.byType(ZSubfolderNarrowNav), findsNothing);
      }
    });
  });

  group('CR-87 — ZSubfolderNav utilisé SEUL (hors ZStudyFolderDetail)', () {
    testWidgets(
      'EXCLUSIVITÉ : exactement une variante montée de part et d\'autre du '
      'seuil, et la variante écartée n\'est jamais CONSTRUITE',
      (tester) async {
        for (final (double w, bool wide) in <(double, bool)>[
          (599, false),
          (600, true),
          (601, true),
        ]) {
          var narrowBuilds = 0;
          var sidebarBuilds = 0;
          await pumpStandalone(
            tester,
            width: w,
            onNarrowBuild: () => narrowBuilds++,
            onSidebarBuild: () => sidebarBuilds++,
          );
          expect(
            find.byKey(kSidebarKey),
            wide ? findsOneWidget : findsNothing,
            reason: 'largeur $w',
          );
          expect(
            find.byKey(kNarrowKey),
            wide ? findsNothing : findsOneWidget,
            reason: 'largeur $w',
          );
          // Paresse des builders : la variante écartée n'est pas seulement
          // absente de l'arbre, elle n'a pas été construite — donc aucun état
          // ne peut être porté en double.
          expect(sidebarBuilds, wide ? 1 : 0, reason: 'largeur $w');
          expect(narrowBuilds, wide ? 0 : 1, reason: 'largeur $w');
        }
      },
    );

    testWidgets('seuil PERSONNALISÉ honoré (399 ⇒ étroit, 400 ⇒ large)', (
      tester,
    ) async {
      await pumpStandalone(tester, width: 399, breakpoint: 400);
      expect(find.byKey(kNarrowKey), findsOneWidget);
      expect(find.byKey(kSidebarKey), findsNothing);

      await pumpStandalone(tester, width: 400, breakpoint: 400);
      expect(find.byKey(kSidebarKey), findsOneWidget);
      expect(find.byKey(kNarrowKey), findsNothing);

      // CONTRE-PREUVE : au seuil PAR DÉFAUT, 400 dp rendrait la surface
      // étroite — le paramètre est donc bien lu, et non ignoré.
      await pumpStandalone(tester, width: 400);
      expect(find.byKey(kNarrowKey), findsOneWidget);
      expect(find.byKey(kSidebarKey), findsNothing);
    });

    testWidgets('sans corps : la variante est rendue SEULE (ni Row ni Column)', (
      tester,
    ) async {
      await pumpStandalone(tester, width: 800, withBody: false);
      expect(find.byKey(kSidebarKey), findsOneWidget);
      expect(find.byKey(kBodyKey), findsNothing);
      expect(
        find
            .descendant(
              of: find.byType(ZSubfolderNav),
              matching: find.byType(Row),
            )
            .evaluate(),
        isEmpty,
      );

      await pumpStandalone(tester, width: 400, withBody: false);
      expect(find.byKey(kNarrowKey), findsOneWidget);
      expect(
        find
            .descendant(
              of: find.byType(ZSubfolderNav),
              matching: find.byType(Column),
            )
            .evaluate(),
        isEmpty,
      );
    });

    testWidgets('avec corps : le corps est monté à côté/au-dessous, une fois', (
      tester,
    ) async {
      for (final double w in <double>[400, 800]) {
        await pumpStandalone(tester, width: w);
        expect(find.byKey(kBodyKey), findsOneWidget, reason: 'largeur $w');
      }
    });

    testWidgets('AD-13 — RTL et LTR basculent à la MÊME largeur', (
      tester,
    ) async {
      for (final TextDirection d in TextDirection.values) {
        await pumpStandalone(tester, width: 599, direction: d);
        expect(find.byKey(kNarrowKey), findsOneWidget, reason: '$d');
        await pumpStandalone(tester, width: 600, direction: d);
        expect(find.byKey(kSidebarKey), findsOneWidget, reason: '$d');
      }
    });

    test('la règle PURE est la seule source, et elle est INCLUSIVE au seuil', () {
      expect(kZSubfolderSidebarBreakpoint, ZWindowSizeThresholds.mediumMinWidth);
      expect(zSubfolderNavPrefersSidebar(kZSubfolderSidebarBreakpoint), isTrue);
      expect(
        zSubfolderNavPrefersSidebar(kZSubfolderSidebarBreakpoint - 1),
        isFalse,
      );
      expect(zSubfolderNavPrefersSidebar(400, breakpoint: 400), isTrue);
      expect(zSubfolderNavPrefersSidebar(399, breakpoint: 400), isFalse);
    });
  });
}

/// Clé de la barre latérale FACTICE de l'appelant.
const Key kSidebarKey = ValueKey<String>('cr87-sidebar');

/// Clé de la surface étroite FACTICE de l'appelant.
const Key kNarrowKey = ValueKey<String>('cr87-narrow');

/// Clé du corps FACTICE de l'appelant.
const Key kBodyKey = ValueKey<String>('cr87-body');

/// Monte `ZSubfolderNav` SEUL, dans une boîte de largeur [width].
Future<void> pumpStandalone(
  WidgetTester tester, {
  required double width,
  double? breakpoint,
  bool withBody = true,
  TextDirection direction = TextDirection.ltr,
  VoidCallback? onNarrowBuild,
  VoidCallback? onSidebarBuild,
}) async {
  final ValueNotifier<String?> selected = ValueNotifier<String?>(null);
  addTearDown(selected.dispose);
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          width: width,
          height: 600,
          child: ZSubfolderNav(
            spec: navSpec(),
            selected: selected,
            onSelect: (_) {},
            sidebarBreakpoint: breakpoint,
            sidebarBuilder: (context) {
              onSidebarBuild?.call();
              return const SizedBox(key: kSidebarKey, width: 200);
            },
            narrowBuilder: (context) {
              onNarrowBuild?.call();
              return const SizedBox(key: kNarrowKey, height: 48);
            },
            bodyBuilder: withBody
                ? (context) => const SizedBox(key: kBodyKey)
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
