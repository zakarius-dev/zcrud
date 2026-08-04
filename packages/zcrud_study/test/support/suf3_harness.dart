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

/// Mode étroit par DÉFAUT **lu sur le socle** (jamais recopié en dur) : si le
/// défaut de production change, ce harnais suit — une garde ne peut donc pas
/// rester verte en mesurant un défaut de test qui aurait divergé.
final ZSubfolderNarrowMode kProductionDefaultNarrowMode = const ZSubfolderNavSpec(
  subfolders: <ZSubfolderRef>[],
  allSubfoldersLabel: '',
).narrowMode;

/// Placement par DÉFAUT **lu sur le socle** (jamais recopié en dur) — même
/// discipline que [kProductionDefaultNarrowMode] : si le défaut de production
/// changeait, la garde « rendu inchangé » suivrait au lieu de rester verte.
final ZSubfolderNavPlacement kProductionDefaultNavPlacement =
    ZStudyFolderDetail(
      title: '',
      materialTabLabel: '',
      notebookTabLabel: '',
      progressionTabLabel: '',
      materialSectionsBuilder: (_) => const <ZStudyToolsSectionSpec>[],
      notebookBuilder: (_) => const SizedBox.shrink(),
      nav: const ZSubfolderNavSpec(
        subfolders: <ZSubfolderRef>[],
        allSubfoldersLabel: '',
      ),
    ).subfolderNavPlacement;

/// Placement de l'affordance d'ajout par DÉFAUT **lu sur le socle** (jamais
/// recopié en dur) — même discipline que [kProductionDefaultNarrowMode].
final ZSubfolderAddPlacement kProductionDefaultAddPlacement =
    const ZSubfolderNavSpec(
      subfolders: <ZSubfolderRef>[],
      allSubfoldersLabel: '',
    ).addPlacement;

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
  // CR-IFFD-40 — `null` ⇒ le DÉFAUT DE PRODUCTION s'applique (barre de
  // sélection). Le harnais ne recopie JAMAIS ce défaut : une garde qui mesure
  // « quel mode par défaut » doit mesurer celui du socle, pas celui du harnais.
  ZSubfolderNarrowMode? narrowMode,
  // CR-IFFD-44 — `null` ⇒ le DÉFAUT DE PRODUCTION s'applique (le harnais ne
  // recopie jamais un défaut).
  ZSubfolderAddPlacement? addPlacement,
  double initialSidebarWidth = 320,
  double minSidebarWidth = 300,
  double maxSidebarWidthFraction = 0.5,
  double collapsedWidth = 56,
  // CR-IFFD-45 — pilotage/observation EXTERNES de la sélection. `null` ⇒
  // capacité absente (défaut de production) : le harnais ne fabrique JAMAIS de
  // contrôleur, sans quoi les gardes de neutralité mesureraient un chemin piloté.
  ZSubfolderSelectionController? selectionController,
  ValueChanged<String?>? onSelectionChanged,
  // CR-IFFD-46 — `null` ⇒ défauts de production (aucun recopiage de défaut).
  String? rootItemLabel,
  IconData? rootItemIcon,
  int? itemMaxLines,
  String? sheetTitle,
  ZSubfolderItemActionBuilder? itemActionBuilder,
}) {
  return ZSubfolderNavSpec(
    subfolders: subfolders ?? refs(),
    allSubfoldersLabel: kAllLabel,
    rootItemLabel: rootItemLabel,
    rootItemIcon: rootItemIcon,
    itemMaxLines: itemMaxLines,
    sheetTitle: sheetTitle,
    itemActionBuilder: itemActionBuilder,
    itemBuilder: itemBuilder,
    narrowMode: narrowMode ?? kProductionDefaultNarrowMode,
    addAction: addAction,
    addLabel: kAddLabel,
    addIcon: Icons.create_new_folder,
    addPlacement: addPlacement ?? kProductionDefaultAddPlacement,
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
    selectionController: selectionController,
    onSelectionChanged: onSelectionChanged,
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
  // CR-IFFD-43 — `null` ⇒ le DÉFAUT DE PRODUCTION s'applique (le harnais ne
  // recopie jamais un défaut : une garde qui mesure « quel placement par
  // défaut » doit mesurer celui du socle).
  ZSubfolderNavPlacement? subfolderNavPlacement,
  Widget? aboveTabViews,
  // CR-IFFD-45 — créneau ENTRE l'app-bar et le `TabBar` + hauteurs DÉCLARÉES.
  // `null` ⇒ défauts de production (le harnais ne recopie aucun défaut : la
  // hauteur de bande est celle que le socle calcule, jamais une constante de
  // test — une garde qui la mesure doit mesurer celle du socle).
  Widget? aboveTabBar,
  double? aboveTabBarHeight,
  double? subfolderNavBandHeight,
  ZPageAppBarMode mode = ZPageAppBarMode.fixed,
  TextDirection textDirection = TextDirection.ltr,
  // CR-IFFD-40 — enveloppe optionnelle posée AUTOUR de la page (p. ex. un
  // `ZSubfolderNavRendererScope`). `null` ⇒ arbre STRICTEMENT inchangé.
  Widget Function(Widget child)? wrap,
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
    subfolderNavPlacement:
        subfolderNavPlacement ?? kProductionDefaultNavPlacement,
    aboveTabViews: aboveTabViews,
    aboveTabBar: aboveTabBar,
    aboveTabBarHeight: aboveTabBarHeight,
    subfolderNavBandHeight: subfolderNavBandHeight,
    mode: mode,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: wrap == null ? widget : wrap(widget),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return widget;
}
