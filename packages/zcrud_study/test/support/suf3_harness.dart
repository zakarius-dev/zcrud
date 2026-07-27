/// Harnais de test PARTAGÉ pour SUF-3 (`ZStudyFolderDetail`).
///
/// Fournit des libellés/builders neutres et un `pump` paramétrable (taille
/// d'écran locale, direction). Les tests injectent des marqueurs (`ValueKey`)
/// pour observer le contenu réellement rendu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

// Libellés INJECTÉS de référence (tests only — non scannés).
const String kAllLabel = 'ALL_SUBFOLDERS';
const String kMatTab = 'MATERIEL';
const String kNoteTab = 'NOTEBOOK';
const String kProgTab = 'PROGRESSION';
const String kAddLabel = 'ADD_SUB';
const String kHandleLabel = 'DRAG_SUB';
const String kMoveBefore = 'MOVE_BEFORE';
const String kMoveAfter = 'MOVE_AFTER';
const String kCollapseLabel = 'COLLAPSE_SB';
const String kExpandLabel = 'EXPAND_SB';
const String kResizeLabel = 'RESIZE_SB';

/// Sections « Matériel » ENCODANT l'id sélectionné : un marqueur `empty:<id>`
/// apparaît/disparaît selon la sélection (AC9).
List<ZStudyToolsSectionSpec> defaultSections(String? id) {
  final tag = id ?? 'null';
  return <ZStudyToolsSectionSpec>[
    ZStudyToolsSectionSpec(
      id: 'sec:$tag',
      title: 'title:$tag',
      itemCount: 0,
      itemBuilder: (_, __) => const SizedBox.shrink(),
      emptyState: Text('empty:$tag', key: ValueKey<String>('empty:$tag')),
    ),
  ];
}

/// Quelques sous-dossiers de référence.
List<ZSubfolderRef> refs({int n = 3}) => <ZSubfolderRef>[
  for (var i = 0; i < n; i++)
    ZSubfolderRef(
      id: 'sf$i',
      label: 'Sous-dossier $i',
      colorKey: i.isEven ? 'primary' : 'secondary',
      count: i,
    ),
];

/// Construit un `ZSubfolderNavSpec` neutre paramétrable.
ZSubfolderNavSpec navSpec({
  List<ZSubfolderRef>? subfolders,
  VoidCallback? addAction,
  void Function(int, int)? onReorder,
  ValueChanged<double>? onSidebarWidthChanged,
  ZSubfolderItemBuilder? itemBuilder,
  double initialSidebarWidth = 320,
  double minSidebarWidth = 300,
  double maxSidebarWidthFraction = 0.5,
  double collapsedWidth = 56,
}) {
  return ZSubfolderNavSpec(
    subfolders: subfolders ?? refs(),
    allSubfoldersLabel: kAllLabel,
    itemBuilder: itemBuilder,
    addAction: addAction,
    addLabel: kAddLabel,
    addIcon: Icons.create_new_folder,
    onReorder: onReorder,
    reorderHandleLabel: kHandleLabel,
    moveBeforeLabel: kMoveBefore,
    moveAfterLabel: kMoveAfter,
    collapseLabel: kCollapseLabel,
    expandLabel: kExpandLabel,
    resizeLabel: kResizeLabel,
    initialSidebarWidth: initialSidebarWidth,
    minSidebarWidth: minSidebarWidth,
    maxSidebarWidthFraction: maxSidebarWidthFraction,
    collapsedWidth: collapsedWidth,
    onSidebarWidthChanged: onSidebarWidthChanged,
  );
}

/// Fixe la taille d'écran de sorte que la largeur locale (`ZResponsiveLayout`)
/// ET `MediaQuery.sizeOf` (clamp de largeur de sidebar) valent toutes deux [w].
Future<void> setScreen(WidgetTester tester, double w, double h) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pompe une `ZStudyFolderDetail` neutre. Tous les slots sont surchargeables.
Future<ZStudyFolderDetail> pumpDetail(
  WidgetTester tester, {
  Object title = 'Dossier',
  String? colorKey,
  int colorSlotIndex = 0,
  ZMaterialSectionsBuilder? materialSectionsBuilder,
  // CR-53 — slots libres de l'onglet Matériel (`null` ⇒ absents, défaut).
  ZMaterialSlotBuilder? materialHeaderBuilder,
  ZMaterialSlotBuilder? materialFooterBuilder,
  WidgetBuilder? notebookBuilder,
  ZProgressRingsData? progressData,
  List<Widget> progressStatCards = const <Widget>[],
  Widget? progressEmptyState,
  ZSubfolderNavSpec? nav,
  ZAppBarAction? sortAction,
  ZAppBarAction? addAction,
  List<ZAppBarAction> menuActions = const <ZAppBarAction>[],
  ZAppBarSearchConfig? search,
  Widget? floatingActionButton,
  FloatingActionButtonLocation? floatingActionButtonLocation,
  List<Widget>? persistentFooterButtons,
  Widget? drawer,
  Widget? endDrawer,
  Widget? bottomNavigationBar,
  Widget? bottomSheet,
  Color? backgroundColor,
  bool? resizeToAvoidBottomInset,
  bool extendBody = false,
  bool extendBodyBehindAppBar = false,
  String? initialSelectedSubfolderId,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  final widget = ZStudyFolderDetail(
    title: title,
    colorKey: colorKey,
    colorSlotIndex: colorSlotIndex,
    materialTabLabel: kMatTab,
    notebookTabLabel: kNoteTab,
    progressionTabLabel: kProgTab,
    materialSectionsBuilder: materialSectionsBuilder ?? defaultSections,
    materialHeaderBuilder: materialHeaderBuilder,
    materialFooterBuilder: materialFooterBuilder,
    notebookBuilder:
        notebookBuilder ??
        (context) =>
            const Text('NOTE_BODY', key: ValueKey<String>('notebook-marker')),
    progressData: progressData,
    progressStatCards: progressStatCards,
    progressEmptyState: progressEmptyState,
    nav: nav ?? navSpec(),
    sortAction: sortAction,
    addAction: addAction,
    menuActions: menuActions,
    search: search,
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: floatingActionButtonLocation,
    persistentFooterButtons: persistentFooterButtons,
    drawer: drawer,
    endDrawer: endDrawer,
    bottomNavigationBar: bottomNavigationBar,
    bottomSheet: bottomSheet,
    backgroundColor: backgroundColor,
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    extendBody: extendBody,
    extendBodyBehindAppBar: extendBodyBehindAppBar,
    initialSelectedSubfolderId: initialSelectedSubfolderId,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(textDirection: textDirection, child: widget),
    ),
  );
  await tester.pumpAndSettle();
  return widget;
}
