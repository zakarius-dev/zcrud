// Relais BOUT EN BOUT de `ZCrudScreen.tabsAlignment` jusqu'au `TabBar` rendu.
//
// L'écran construit sa barre d'onglets via `ZTabbedList` : le seam n'a de
// valeur que s'il traverse les deux étages. Ces gardes montent l'écran complet
// et lisent le widget `TabBar` FINAL — jamais une clé, jamais le `ZTabbedList`
// intermédiaire.
//
// Gardes :
// 1. INERTIE — sans `tabsAlignment`, la signature du sous-arbre de la barre
//    d'onglets est STRICTEMENT égale à celle figée avant la modification de
//    l'écran, et `tabAlignment` est `null` sur le `TabBar` rendu.
// 2. RELAIS — `start` (barre défilante) et `center` (barre fixe) atteignent le
//    `TabBar` final.
// 3. `tabsScrollable` n'est pas altéré par la déclaration d'un alignement.
//
// La garde de NON-DÉBORDEMENT (trois libellés longs à 600 dp) vit dans
// `zcrud_core` (`z_tabbed_list_tab_alignment_test.dart`), là où la barre est
// mesurable sans le reste de l'écran.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

const _seed = <Item>[
  Item(id: 'a1', name: 'Alpha', qty: 1),
  Item(id: 'b1', name: 'Beta', qty: 2),
];

List<ZListTab> _tabs() => <ZListTab>[
      const ZListTab(
        labelKey: 'Un',
        baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.eq, 1)],
      ),
      const ZListTab(
        labelKey: 'Deux',
        baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.eq, 2)],
      ),
    ];

Widget _screen(
  FakeItemRepo repo, {
  bool tabsScrollable = false,
  TabAlignment? tabsAlignment,
}) =>
    ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      tabsScrollable: tabsScrollable,
      tabsAlignment: tabsAlignment,
      tabs: _tabs(),
    );

/// Signature structurelle du sous-arbre de la barre d'onglets : types de
/// widgets en parcours profondeur d'abord, puis rectangles des onglets.
String _tabBarSignature(WidgetTester tester) {
  final types = tester
      .widgetList(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.byWidgetPredicate((_) => true),
        ),
      )
      .map((Widget w) => w.runtimeType.toString())
      .join(',');
  final rects = tester
      .widgetList(find.byType(Tab))
      .map((Widget w) => tester.getRect(find.byWidget(w)))
      .map(
        (Rect r) =>
            '${r.left.toStringAsFixed(1)}:${r.right.toStringAsFixed(1)}',
      )
      .join(' ');
  return '$types|$rects';
}

void main() {
  group('inertie (garde 1)', () {
    testWidgets('sans `tabsAlignment` : signature identique à l\'avant-modif',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo, tabsScrollable: true));

      expect(_tabBarSignature(tester), _frozenScrollableSignature);
    });

    testWidgets('sans `tabsAlignment` : `tabAlignment` nul sur le TabBar rendu',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo));

      expect(tester.widget<TabBar>(find.byType(TabBar)).tabAlignment, isNull);
    });
  });

  group('relais bout en bout (gardes 2 et 3)', () {
    testWidgets('`start` traverse l\'écran jusqu\'au TabBar (barre défilante)',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          tabsScrollable: true,
          tabsAlignment: TabAlignment.start,
        ),
      );

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.tabAlignment, TabAlignment.start);
      // `tabsScrollable` n'est pas altéré par la déclaration d'un alignement.
      expect(bar.isScrollable, isTrue);
    });

    testWidgets('`center` traverse l\'écran jusqu\'au TabBar (barre fixe)',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo, tabsAlignment: TabAlignment.center),
      );

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.tabAlignment, TabAlignment.center);
      expect(bar.isScrollable, isFalse);
    });
  });
}

/// Signature du sous-arbre de la barre d'onglets, figée AVANT l'ajout de
/// `tabsAlignment` (mesurée sur la copie de sauvegarde du fichier source).
const String _frozenScrollableSignature =
    r'Material,ClipPath,_ShapeBorderPaint,CustomPaint,NotificationListener<LayoutChangedNotification>,_InkFeatures,AnimatedDefaultTextStyle,DefaultTextStyle,MediaQuery,CustomPaint,Align,ScrollConfiguration,SingleChildScrollView,Scrollable,NotificationListener<ScrollMetricsNotification>,_ScrollSemantics,_ScrollableScope,Listener,RawGestureDetector,_GestureSemantics,Listener,Semantics,IgnorePointer,_SingleChildViewport,Padding,Semantics,CustomPaint,_TabStyle,DefaultTextStyle,Builder,IconTheme,_TabLabelBar,MergeSemantics,InkWell,_InkResponseStateWidget,_ParentInkResponseProvider,Actions,_ActionsScope,Focus,_FocusInheritedScope,Semantics,MouseRegion,Builder,DefaultSelectionStyle,Semantics,GestureDetector,RawGestureDetector,Listener,Padding,Semantics,Stack,_TabStyle,DefaultTextStyle,Builder,IconTheme,Center,Padding,KeyedSubtree,Tab,SizedBox,Center,_ZTabLabel,Text,RichText,Semantics,MergeSemantics,InkWell,_InkResponseStateWidget,_ParentInkResponseProvider,Actions,_ActionsScope,Focus,_FocusInheritedScope,Semantics,MouseRegion,Builder,DefaultSelectionStyle,Semantics,GestureDetector,RawGestureDetector,Listener,Padding,Semantics,Stack,_TabStyle,DefaultTextStyle,Builder,IconTheme,Center,Padding,KeyedSubtree,Tab,SizedBox,Center,_ZTabLabel,Text,RichText,Semantics|68.0:96.2 128.2:184.6';
