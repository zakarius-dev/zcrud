// CR-IFFD-135 — INERTIE du widget porté, et IDENTITÉ des deux voies.
//
// `ZItemActionsMenu` et `showZItemActionsMenu` partagent désormais une seule
// composition (`_composeItemActions`). Deux risques en découlent, gardés ici :
//
//   1. la FACTORISATION a changé l'arbre rendu par le widget existant ;
//   2. la voie IMPÉRATIVE rend autre chose que la voie du déclencheur.
//
// Les deux signatures figées ci-dessous ont été capturées sur le code ANTÉRIEUR
// à la factorisation (base v3.45.0, d42529f1d) et sont comparées en ÉGALITÉ
// STRICTE — jamais `contains`, jamais `<=`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_menu/zcrud_menu.dart' show ZMenuPanelEntry;
import 'package:zcrud_study/zcrud_study.dart';

const List<String> _kTriggerFige = <String>[
  'ZActionMenu',
  'ConstrainedBox',
  'PopupMenuButton<ZMenuEntry>',
  'Semantics',
  'IconButton',
  '_SelectableIconButton',
  '_IconButtonM3',
  'Semantics',
  '_InputPadding',
  'ConstrainedBox',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'Tooltip',
  'RawTooltip',
  'OverlayPortal',
  '_OverlayPortal',
  'Semantics',
  '_ExclusiveMouseRegion',
  'Listener',
  'Semantics',
  'MouseRegion',
  'AnimatedTheme',
  'Theme',
  '_InheritedTheme',
  'CupertinoTheme',
  'InheritedCupertinoTheme',
  'IconTheme',
  'IconTheme',
  'DefaultSelectionStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Align',
  'Semantics',
  'Semantics',
  'Icon',
  'Semantics',
  'ExcludeSemantics',
  'SizedBox',
  'Center',
  'RichText',
];

const List<String> _kSurfaceFige = <String>[
  '_ZDefaultItemActionGrid',
  'SizedBox',
  'GridView',
  'Scrollable',
  'StretchingOverscrollIndicator',
  'NotificationListener<ScrollNotification>',
  'AnimatedBuilder',
  'ClipRect',
  'StretchEffect',
  'Transform',
  'NotificationListener<ScrollMetricsNotification>',
  '_ScrollSemantics',
  '_ScrollableScope',
  'Listener',
  'RawGestureDetector',
  '_GestureSemantics',
  'Listener',
  'Semantics',
  'IgnorePointer',
  'ShrinkWrappingViewport',
  'SliverPadding',
  'SliverGrid',
  'KeyedSubtree',
  'AutomaticKeepAlive',
  'KeepAlive',
  'NotificationListener<KeepAliveNotification>',
  '_SelectionKeepAlive',
  'IndexedSemantics',
  'RepaintBoundary',
  '_ZItemActionGridTile',
  'Builder',
  'DefaultTextStyle',
  'ZMenuEntryTile',
  '_ZMinTapTargetGuard',
  'Semantics',
  'ConstrainedBox',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Column',
  'Icon',
  'Semantics',
  'ExcludeSemantics',
  'SizedBox',
  'Center',
  'RichText',
  'SizedBox',
  'Text',
  'RichText',
  'KeyedSubtree',
  'AutomaticKeepAlive',
  'KeepAlive',
  'NotificationListener<KeepAliveNotification>',
  '_SelectionKeepAlive',
  'IndexedSemantics',
  'RepaintBoundary',
  '_ZItemActionGridTile',
  'Builder',
  'DefaultTextStyle',
  'ZMenuEntryTile',
  '_ZMinTapTargetGuard',
  'Semantics',
  'ConstrainedBox',
  'Column',
  'Icon',
  'Semantics',
  'ExcludeSemantics',
  'SizedBox',
  'Center',
  'RichText',
  'SizedBox',
  'Text',
  'RichText',
  'Text',
  'RichText',
  'KeyedSubtree',
  'AutomaticKeepAlive',
  'KeepAlive',
  'NotificationListener<KeepAliveNotification>',
  '_SelectionKeepAlive',
  'IndexedSemantics',
  'RepaintBoundary',
  '_ZItemActionGridTile',
  'MergeSemantics',
  'Semantics',
  'Stack',
  'ZForegroundOverride',
  'Theme',
  '_InheritedTheme',
  'CupertinoTheme',
  'InheritedCupertinoTheme',
  'IconTheme',
  'IconTheme',
  'DefaultSelectionStyle',
  'Builder',
  'IconTheme',
  'Builder',
  'DefaultTextStyle',
  'Builder',
  'DefaultTextStyle',
  'ZMenuEntryTile',
  '_ZMinTapTargetGuard',
  'Semantics',
  'ConstrainedBox',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Column',
  'Icon',
  'Semantics',
  'ExcludeSemantics',
  'SizedBox',
  'Center',
  'RichText',
  'SizedBox',
  'Text',
  'RichText',
  'Positioned',
  'IgnorePointer',
  'Badge',
  'Stack',
  'SizedBox',
  'Positioned',
  '_Badge',
  'DefaultTextStyle',
  '_IntrinsicHorizontalStadium',
  'Container',
  'DecoratedBox',
  'ClipPath',
  'Padding',
  'Align',
  'Text',
  'RichText',
];

/// Signature = types des widgets du sous-arbre, en parcours de l'arbre.
List<String> _signature(Finder root) => find
    .descendant(
      of: root,
      matching: find.byWidgetPredicate((_) => true),
      skipOffstage: false,
    )
    .evaluate()
    .map((Element e) => e.widget.runtimeType.toString())
    .toList(growable: false);

List<ZItemAction> _actions(List<String> journal) => <ZItemAction>[
      ZItemAction(
        kind: ZItemActionKind.open,
        label: 'OUVRIR',
        icon: Icons.folder_open,
        onSelected: () => journal.add('open'),
      ),
      const ZItemAction(
        kind: ZItemActionKind.rename,
        label: 'RENOMMER',
        icon: Icons.edit,
        disabledReason: 'INDISPONIBLE',
      ),
      ZItemAction(
        kind: ZItemActionKind.share,
        label: 'PARTAGER',
        icon: Icons.share,
        onSelected: () => journal.add('share'),
        state: ZItemActionState.present,
        stateSemanticLabel: 'PRÊT',
        count: 4,
      ),
      // Ni actionnable ni motivée ⇒ ABSENTE (AD-4).
      const ZItemAction(
        kind: ZItemActionKind.delete,
        label: 'SUPPRIMER',
        icon: Icons.delete,
      ),
    ];

/// Bouton de l'HÔTE : il reste dans SON arbre, le socle ne le remplace pas.
class _HostAnchor extends StatelessWidget {
  const _HostAnchor({required this.actions});

  final List<ZItemAction> actions;

  static final GlobalKey anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) => IconButton(
        key: anchorKey,
        icon: const Icon(Icons.more_horiz),
        tooltip: 'PLUS-HÔTE',
        onPressed: () => showZItemActionsMenu(
          context,
          actions: actions,
          anchorKey: anchorKey,
        ),
      );
}

void main() {
  testWidgets(
      'INERTIE : le déclencheur porté rend EXACTEMENT le même arbre qu\'avant',
      (tester) async {
    final journal = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: ZItemActionsMenu(actions: _actions(journal))),
      ),
    ));
    expect(_signature(find.byType(ZItemActionsMenu)), equals(_kTriggerFige));
  });

  testWidgets(
      'INERTIE : la surface ouverte par le déclencheur est EXACTEMENT la même',
      (tester) async {
    final journal = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: ZItemActionsMenu(actions: _actions(journal))),
      ),
    ));
    await tester.tap(find.byType(ZItemActionsMenu));
    await tester.pumpAndSettle();
    expect(_signature(find.byType(ZMenuPanelEntry)), equals(_kSurfaceFige));
  });

  testWidgets(
      'la voie IMPÉRATIVE rend la MÊME surface, au widget près',
      (tester) async {
    final journal = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: _HostAnchor(actions: _actions(journal))),
      ),
    ));
    // Le bouton de l'hôte est TOUJOURS là : le socle n'en pose aucun.
    expect(find.byTooltip('PLUS-HÔTE'), findsOneWidget);
    expect(find.byType(ZItemActionsMenu), findsNothing);
    await tester.tap(find.byKey(_HostAnchor.anchorKey));
    await tester.pumpAndSettle();
    expect(_signature(find.byType(ZMenuPanelEntry)), equals(_kSurfaceFige));

    // Et la sélection passe par la MÊME voie unique : une seule invocation.
    await tester.tap(find.text('PARTAGER'));
    await tester.pumpAndSettle();
    expect(journal, equals(<String>['share']));
  });
}
