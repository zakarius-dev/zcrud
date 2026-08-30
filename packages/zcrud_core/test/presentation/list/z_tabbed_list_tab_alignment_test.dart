// Relais de `ZTabbedList.tabAlignment` vers le `TabBar` rendu.
//
// Contexte du défaut : une barre d'onglets défilante fait résoudre par Flutter
// `TabAlignment.startOffset`, qui réserve un décrochage de tête de 52 dp avant
// le premier onglet. Sur une fenêtre étroite (600 dp) avec des libellés longs,
// ce décrochage suffit à pousser le dernier onglet HORS du viewport. Le seam
// `tabAlignment` permet de déclarer `TabAlignment.start` et de récupérer ces
// 52 dp — mais seulement s'il atteint réellement le `TabBar`.
//
// Gardes :
// 1. INERTIE — sans le paramètre, l'arbre rendu est STRICTEMENT égal à la
//    signature figée AVANT la modification du widget, et `tabAlignment` est
//    `null` sur le `TabBar` rendu.
// 2. RELAIS — la valeur déclarée est lue SUR LE WIDGET `TabBar` RENDU (pas sur
//    une clé), pour `start` (barre défilante) et `center` (barre fixe).
// 3. `isScrollable` n'est pas altéré par la déclaration d'un alignement.
// 4. NON-DÉBORDEMENT — trois libellés longs à 600 dp : par défaut le troisième
//    onglet déborde du viewport ; sous `TabAlignment.start` il y rentre.
//    Bornes figées, mesurées.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Largeur du viewport des gardes de débordement (fenêtre étroite du défaut).
const double _kViewport = 600;

ZListTab _tab(String key) =>
    ZListTab(labelKey: key, builder: (context) => Text('page-$key'));

Widget _host(Widget child, {Map<String, String> labels = const {}}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _kViewport,
            height: 800,
            child: ZcrudScope(labels: ZcrudLabels(labels), child: child),
          ),
        ),
      ),
    );

/// Trois libellés longs : la barre défilante déborde du viewport dès que le
/// décrochage de tête de `startOffset` s'y ajoute.
const Map<String, String> _longLabels = <String, String>{
  'tab.a': 'Justificatifs',
  'tab.b': 'Réceptions',
  'tab.c': 'Documentation',
};

/// Signature structurelle de l'arbre rendu sous `ZTabbedList` : types de
/// widgets en parcours profondeur d'abord, puis rectangles des onglets. C'est
/// cette chaîne qui est figée pour l'inertie (égalité stricte).
String _signature(WidgetTester tester) {
  final types = tester
      .widgetList(
        find.descendant(
          of: find.byType(ZTabbedList),
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

/// Rectangle du n-ième onglet rendu.
Rect _tabRect(WidgetTester tester, int index) =>
    tester.getRect(find.byType(Tab).at(index));

void main() {
  group('inertie (garde 1)', () {
    testWidgets('sans le paramètre : signature identique à l\'avant-modif', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            isScrollable: true,
            tabs: <ZListTab>[_tab('tab.a'), _tab('tab.b'), _tab('tab.c')],
          ),
          labels: _longLabels,
        ),
      );
      await tester.pumpAndSettle();

      // Signature capturée sur le fichier source AVANT l'ajout de
      // `tabAlignment` (copie de sauvegarde remise en place le temps de la
      // mesure), puis rejouée après. Égalité STRICTE.
      expect(_signature(tester), _frozenScrollableSignature);
    });

    testWidgets('sans le paramètre : `tabAlignment` nul sur le TabBar rendu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            tabs: <ZListTab>[_tab('tab.a'), _tab('tab.b')],
          ),
          labels: _longLabels,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<TabBar>(find.byType(TabBar)).tabAlignment, isNull);
    });
  });

  group('relais (gardes 2 et 3)', () {
    testWidgets('`start` atteint le TabBar rendu (barre défilante)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <ZListTab>[_tab('tab.a'), _tab('tab.b')],
          ),
          labels: _longLabels,
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.tabAlignment, TabAlignment.start);
      // `isScrollable` n'est pas altéré par la déclaration d'un alignement.
      expect(bar.isScrollable, isTrue);
    });

    testWidgets('`center` atteint le TabBar rendu (barre fixe)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            tabAlignment: TabAlignment.center,
            tabs: <ZListTab>[_tab('tab.a'), _tab('tab.b')],
          ),
          labels: _longLabels,
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.tabAlignment, TabAlignment.center);
      expect(bar.isScrollable, isFalse);
    });
  });

  group('non-débordement (garde 4)', () {
    testWidgets('défaut : le troisième onglet SORT du viewport de 600 dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            isScrollable: true,
            tabs: <ZListTab>[_tab('tab.a'), _tab('tab.b'), _tab('tab.c')],
          ),
          labels: _longLabels,
        ),
      );
      await tester.pumpAndSettle();

      final viewportRight = tester.getRect(find.byType(TabBar)).right;
      final third = _tabRect(tester, 2);
      expect(
        third.right,
        greaterThan(viewportRight),
        reason: 'sans alignement déclaré, `startOffset` pousse le troisième '
            'onglet hors du viewport',
      );
      // Borne figée du débordement mesuré (le décrochage de tête vaut 52 dp).
      expect(third.right - viewportRight, closeTo(_frozenOverflow, 0.5));
    });

    testWidgets('`start` : le troisième onglet RENTRE dans le viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <ZListTab>[_tab('tab.a'), _tab('tab.b'), _tab('tab.c')],
          ),
          labels: _longLabels,
        ),
      );
      await tester.pumpAndSettle();

      final barRect = tester.getRect(find.byType(TabBar));
      final third = _tabRect(tester, 2);
      expect(
        third.right,
        lessThanOrEqualTo(barRect.right),
        reason: '`TabAlignment.start` récupère les 52 dp du décrochage de '
            'tête : les trois onglets tiennent dans 600 dp',
      );
      // Le décrochage de tête a disparu : le premier onglet ne laisse plus que
      // le padding de libellé (16 dp) au lieu des 16 + 52 dp du `startOffset`.
      expect(_tabRect(tester, 0).left - barRect.left, closeTo(16, 0.5));
      // Marge restante figée : le gain vaut bien le décrochage supprimé.
      expect(barRect.right - third.right, closeTo(_frozenHeadroom, 0.5));
    });
  });
}

/// Signature de l'arbre figée AVANT l'ajout de `tabAlignment` (mesurée sur la
/// copie de sauvegarde du fichier source).
const String _frozenScrollableSignature =
    r'Column,TabBar,Material,ClipPath,_ShapeBorderPaint,CustomPaint,NotificationListener<LayoutChangedNotification>,_InkFeatures,AnimatedDefaultTextStyle,DefaultTextStyle,MediaQuery,CustomPaint,Align,ScrollConfiguration,SingleChildScrollView,Scrollable,NotificationListener<ScrollMetricsNotification>,_ScrollSemantics,_ScrollableScope,Listener,RawGestureDetector,_GestureSemantics,Listener,Semantics,IgnorePointer,_SingleChildViewport,Padding,Semantics,CustomPaint,_TabStyle,DefaultTextStyle,Builder,IconTheme,_TabLabelBar,MergeSemantics,InkWell,_InkResponseStateWidget,_ParentInkResponseProvider,Actions,_ActionsScope,Focus,_FocusInheritedScope,Semantics,MouseRegion,Builder,DefaultSelectionStyle,Semantics,GestureDetector,RawGestureDetector,Listener,Padding,Semantics,Stack,_TabStyle,DefaultTextStyle,Builder,IconTheme,Center,Padding,KeyedSubtree,Tab,SizedBox,Center,_ZTabLabel,Text,RichText,Semantics,MergeSemantics,InkWell,_InkResponseStateWidget,_ParentInkResponseProvider,Actions,_ActionsScope,Focus,_FocusInheritedScope,Semantics,MouseRegion,Builder,DefaultSelectionStyle,Semantics,GestureDetector,RawGestureDetector,Listener,Padding,Semantics,Stack,_TabStyle,DefaultTextStyle,Builder,IconTheme,Center,Padding,KeyedSubtree,Tab,SizedBox,Center,_ZTabLabel,Text,RichText,Semantics,MergeSemantics,InkWell,_InkResponseStateWidget,_ParentInkResponseProvider,Actions,_ActionsScope,Focus,_FocusInheritedScope,Semantics,MouseRegion,Builder,DefaultSelectionStyle,Semantics,GestureDetector,RawGestureDetector,Listener,Padding,Semantics,Stack,Center,Padding,KeyedSubtree,Tab,SizedBox,Center,_ZTabLabel,Text,RichText,Semantics,Expanded,TabBarView,NotificationListener<ScrollNotification>,PageView,NotificationListener<ScrollNotification>,Scrollable,StretchingOverscrollIndicator,NotificationListener<ScrollNotification>,AnimatedBuilder,ClipRect,StretchEffect,Transform,NotificationListener<ScrollMetricsNotification>,_ScrollSemantics,_ScrollableScope,Listener,RawGestureDetector,_GestureSemantics,Listener,Semantics,IgnorePointer,Viewport,SliverFillViewport,_SliverFractionalPadding,_SliverFillViewportRenderObjectWidget,KeyedSubtree,AutomaticKeepAlive,KeepAlive,NotificationListener<KeepAliveNotification>,_SelectionKeepAlive,IndexedSemantics,RepaintBoundary,KeyedSubtree,Semantics,_KeepAliveTabPage,Text,RichText|168.0:351.3 383.3:524.3 556.3:739.6';

/// Débordement mesuré du troisième onglet, sans alignement déclaré (dp).
const double _frozenOverflow = 39.6;

/// Marge restante du troisième onglet sous `TabAlignment.start` (dp).
const double _frozenHeadroom = 12.4;
