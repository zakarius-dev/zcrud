/// CR-LEX-88 — relais de `tabAlignment` par les conteneurs de page du paquet.
///
/// Trois gardes, chacune sur une propriété distincte :
///
/// 1. **Inertie absolue** — sans le paramètre, la signature structurelle de
///    l'app-bar (dont vit le `TabBar`) est celle RELEVÉE AVANT l'ajout du
///    relais, à l'octet près.
/// 2. **Relais effectif** — la valeur déclarée est lue SUR LE WIDGET `TabBar`
///    rendu (pas sur une clé, pas sur un type de conteneur).
/// 3. **Non-débordement** — reproduction du symptôme mesuré chez l'hôte : trois
///    libellés, viewport de 600 dp, le troisième onglet sort du viewport sous
///    la résolution Flutter par défaut (`startOffset`) et rentre entièrement
///    dedans dès que `TabAlignment.start` est déclaré.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_session/zcrud_session.dart'
    show ZProgressRingsData, ZStudyProgressRings;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

import 'support/suf3_harness.dart';

/// Largeur du viewport des gardes de débordement (dp) — celle du relevé hôte.
const double _kViewportWidth = 600.0;

/// Libellés CALIBRÉS pour que le CENTRE du troisième onglet franchisse la
/// bordure du viewport de peu (4,35 dp) : c'est le régime dans lequel les
/// 52 dp de décrochage de `TabAlignment.startOffset` font toute la différence,
/// et c'est celui du relevé hôte.
const String _kMat = 'Matériel';
const String _kNote = 'Carnet de notes';
const String _kProg = 'Progression détaillée';

/// Signature STRUCTURELLE du sous-arbre d'app-bar : `runtimeType` par nœud,
/// préfixé de sa profondeur, plus les deux propriétés du `TabBar` en jeu.
/// Sans hash ni adresse — reproductible d'un run à l'autre, donc figeable.
String _appBarSignature(WidgetTester tester) {
  final buffer = StringBuffer();
  void visit(Element element, int depth) {
    final Widget w = element.widget;
    buffer.write('$depth ');
    buffer.write(w.runtimeType);
    if (w is TabBar) {
      buffer.write('(align=${w.tabAlignment},scroll=${w.isScrollable})');
    }
    buffer.writeln();
    element.visitChildren((child) => visit(child, depth + 1));
  }

  visit(
    tester.element(
      find
          .ancestor(of: find.byType(TabBar), matching: find.byType(AppBar))
          .first,
    ),
    0,
  );
  return buffer.toString();
}

/// Rectangle du troisième onglet (le `Tab` lui-même, cible de tap réelle).
Rect _thirdTabRect(WidgetTester tester) =>
    tester.getRect(find.byType(Tab).at(2));

/// Pompe la page avec les trois libellés longs CALIBRÉS.
Future<void> pumpLongLabels(
  WidgetTester tester, {
  TabAlignment? tabAlignment,
  ZProgressRingsData? progressData,
}) => pumpDetail(
  tester,
  materialTabLabel: _kMat,
  notebookTabLabel: _kNote,
  progressionTabLabel: _kProg,
  tabAlignment: tabAlignment,
  progressData: progressData,
);

/// Relevé sur l'arbre AVANT l'ajout du relais (sha256 du fichier source du
/// relevé : bd77757ce28f6fe92c9868b57ab81bc1031353caf089c97d88721a30b30b75ee).
const String _kFrozenAppBarSignature = r'''
0 AppBar
1 Semantics
2 AnnotatedRegion<SystemUiOverlayStyle>
3 Material
4 AnimatedPhysicalModel
5 PhysicalModel
6 NotificationListener<LayoutChangedNotification>
7 _InkFeatures
8 AnimatedDefaultTextStyle
9 DefaultTextStyle
10 Semantics
11 Align
12 SafeArea
13 Padding
14 MediaQuery
15 Column
16 Flexible
17 ConstrainedBox
18 ClipRect
19 CustomSingleChildLayout
20 Builder
21 IconTheme
22 DefaultTextStyle
23 NavigationToolbar
24 CustomMultiChildLayout
25 LayoutId
26 Builder
27 MediaQuery
28 DefaultTextStyle
29 Semantics
30 _AppBarTitleBox
31 Row
32 Container
33 ConstrainedBox
34 DecoratedBox
35 Padding
32 SizedBox
32 Flexible
33 Text
34 RichText
16 TabBar(align=null,scroll=true)
17 Material
18 ClipPath
19 _ShapeBorderPaint
20 CustomPaint
21 NotificationListener<LayoutChangedNotification>
22 _InkFeatures
23 AnimatedDefaultTextStyle
24 DefaultTextStyle
25 MediaQuery
26 CustomPaint
27 Align
28 ScrollConfiguration
29 SingleChildScrollView
30 Scrollable
31 NotificationListener<ScrollMetricsNotification>
32 _ScrollSemantics
33 _ScrollableScope
34 Listener
35 RawGestureDetector
36 _GestureSemantics
37 Listener
38 Semantics
39 IgnorePointer
40 _SingleChildViewport
41 Padding
42 Semantics
43 CustomPaint
44 _TabStyle
45 DefaultTextStyle
46 Builder
47 IconTheme
48 _TabLabelBar
49 MergeSemantics
50 InkWell
51 _InkResponseStateWidget
52 _ParentInkResponseProvider
53 Actions
54 _ActionsScope
55 Focus
56 _FocusInheritedScope
57 Semantics
58 MouseRegion
59 Builder
60 DefaultSelectionStyle
61 Semantics
62 GestureDetector
63 RawGestureDetector
64 Listener
65 Padding
66 Semantics
67 Stack
68 _TabStyle
69 DefaultTextStyle
70 Builder
71 IconTheme
72 Center
73 Padding
74 KeyedSubtree
75 Tab
76 SizedBox
77 Center
78 Text
79 RichText
68 Semantics
49 MergeSemantics
50 InkWell
51 _InkResponseStateWidget
52 _ParentInkResponseProvider
53 Actions
54 _ActionsScope
55 Focus
56 _FocusInheritedScope
57 Semantics
58 MouseRegion
59 Builder
60 DefaultSelectionStyle
61 Semantics
62 GestureDetector
63 RawGestureDetector
64 Listener
65 Padding
66 Semantics
67 Stack
68 _TabStyle
69 DefaultTextStyle
70 Builder
71 IconTheme
72 Center
73 Padding
74 KeyedSubtree
75 Tab
76 SizedBox
77 Center
78 Text
79 RichText
68 Semantics
49 MergeSemantics
50 InkWell
51 _InkResponseStateWidget
52 _ParentInkResponseProvider
53 Actions
54 _ActionsScope
55 Focus
56 _FocusInheritedScope
57 Semantics
58 MouseRegion
59 Builder
60 DefaultSelectionStyle
61 Semantics
62 GestureDetector
63 RawGestureDetector
64 Listener
65 Padding
66 Semantics
67 Stack
68 Center
69 Padding
70 KeyedSubtree
71 Tab
72 SizedBox
73 Center
74 Text
75 RichText
68 Semantics
''';

void main() {
  group('ZStudyFolderDetail — inertie sans tabAlignment', () {
    testWidgets('signature d\'app-bar identique au relevé pré-relais',
        (tester) async {
      await setScreen(tester, _kViewportWidth, 1200);
      await pumpDetail(tester);

      // GARDE MORDANTE : donner au relais un défaut non nul (p. ex.
      // `tabAlignment ?? TabAlignment.start`) fait diverger la ligne du
      // `TabBar` de la signature figée.
      expect(_appBarSignature(tester), _kFrozenAppBarSignature);
    });

    testWidgets('tabAlignment omis ⇒ TabBar.tabAlignment nul', (tester) async {
      await setScreen(tester, _kViewportWidth, 1200);
      await pumpDetail(tester);
      expect(tester.widget<TabBar>(find.byType(TabBar)).tabAlignment, isNull);
    });
  });

  group('ZStudyFolderDetail — relais de tabAlignment', () {
    for (final align in <TabAlignment>[
      TabAlignment.start,
      TabAlignment.center,
      TabAlignment.startOffset,
    ]) {
      testWidgets('$align déclaré ⇒ porté par le TabBar rendu', (tester) async {
        await setScreen(tester, _kViewportWidth, 1200);
        await pumpDetail(tester, tabAlignment: align);

        // GARDE MORDANTE : avaler le paramètre (ne pas le passer au shell)
        // laisse `null` sur le `TabBar`.
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).tabAlignment,
          align,
        );
      });
    }

    testWidgets('la barre reste défilante (isScrollable non altéré)',
        (tester) async {
      await setScreen(tester, _kViewportWidth, 1200);
      await pumpDetail(tester, tabAlignment: TabAlignment.start);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
    });
  });

  group('ZStudyFolderDetail — débordement du 3e onglet à 600 dp', () {
    testWidgets('par défaut ⇒ le centre du 3e onglet SORT du viewport',
        (tester) async {
      await setScreen(tester, _kViewportWidth, 1200);
      await pumpLongLabels(tester);

      final Rect rect = _thirdTabRect(tester);
      // Bornes EXACTES relevées : le 3e onglet occupe 456,3 → 752,4 dp, son
      // centre tombe à 604,35 dp — 4,35 dp au-delà du viewport. C'est le
      // symptôme mesuré : un geste visant ce centre porte hors des bornes.
      expect(rect.left, moreOrLessEquals(456.3, epsilon: 0.05));
      expect(rect.right, moreOrLessEquals(752.4, epsilon: 0.05));
      expect(rect.center.dx, moreOrLessEquals(604.35, epsilon: 0.05));
      expect(rect.center.dx, greaterThan(_kViewportWidth));
    });

    testWidgets('par défaut ⇒ taper le 3e onglet LÈVE hors des bornes',
        (tester) async {
      await setScreen(tester, _kViewportWidth, 1200);
      await pumpLongLabels(tester);

      // Reproduction de l'échec relevé chez l'hôte : le geste ne touche pas
      // sa cible. `flutter_test` le signale par un avertissement de hit-test ;
      // rendu FATAL ici, il redevient l'exception que l'hôte a vue.
      final bool previous = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
      await expectLater(
        () => tester.tap(find.byType(Tab).at(2)),
        throwsA(isA<FlutterError>()),
      );
    });

    testWidgets('TabAlignment.start ⇒ le centre RENTRE dans le viewport',
        (tester) async {
      await setScreen(tester, _kViewportWidth, 1200);
      await pumpLongLabels(tester, tabAlignment: TabAlignment.start);

      final Rect rect = _thirdTabRect(tester);
      // Bornes EXACTES relevées : les 52 dp de décrochage de `startOffset`
      // récupérés, le centre repasse à 552,35 dp.
      expect(rect.left, moreOrLessEquals(404.3, epsilon: 0.05));
      expect(rect.center.dx, moreOrLessEquals(552.35, epsilon: 0.05));
      // GARDE MORDANTE : avaler le paramètre restaure 604,35 dp — la garde
      // rougit exactement là où l'hôte échouait.
      expect(rect.center.dx, lessThanOrEqualTo(_kViewportWidth));
    });

    testWidgets('TabAlignment.start ⇒ le 3e onglet est réellement tapable',
        (tester) async {
      await setScreen(tester, _kViewportWidth, 1200);
      await pumpLongLabels(
        tester,
        tabAlignment: TabAlignment.start,
        progressData:
            const ZProgressRingsData(total: 10, correct: 7, ratio: .7),
      );

      await tester.tap(find.byType(Tab).at(2));
      await tester.pumpAndSettle();
      expect(find.byType(ZStudyProgressRings), findsOneWidget);
    });
  });

  group('ZStudySessionScaffold — même relais', () {
    Future<void> pumpSession(
      WidgetTester tester, {
      TabAlignment? tabAlignment,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZStudySessionScaffold(
            title: 'Session',
            mode: ZReviewMode.list,
            queue: const <ZFlashcard>[],
            tabAlignment: tabAlignment,
            tabs: <ZPageTab>[
              for (final label in <String>[_kMat, _kNote, _kProg])
                ZPageTab(
                  label: label,
                  contentBuilder: (_) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('omis ⇒ TabBar.tabAlignment nul', (tester) async {
      await setScreen(tester, _kViewportWidth, 1200);
      await pumpSession(tester);
      expect(tester.widget<TabBar>(find.byType(TabBar)).tabAlignment, isNull);
    });

    testWidgets('déclaré ⇒ porté par le TabBar rendu', (tester) async {
      await setScreen(tester, _kViewportWidth, 1200);
      await pumpSession(tester, tabAlignment: TabAlignment.start);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).tabAlignment,
        TabAlignment.start,
      );
    });
  });
}
