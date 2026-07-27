/// `ZStudyFolderDetail` — ossature de page-détail d'un dossier d'étude (SUF-3).
///
/// COMPOSE les briques existantes SANS rien réimplémenter :
/// - en-tête + actions (tri/ajout/menu) + recherche + 3 onglets → `ZPageScaffold`
///   / `ZSearchableAppBar` / `ZPageTab` / `ZAppBarAction` / `ZAppBarSearchConfig`
///   (SUF-1, `zcrud_ui_kit`) — **aucune** app-bar/recherche réimplémentée ;
/// - onglet **Matériel** → `ZSectionedStudyLayout` (même package), avec deux
///   slots LIBRES optionnels au-dessus/en-dessous des sections, dans le MÊME
///   défilement (`materialHeaderBuilder`/`materialFooterBuilder`, CR-53) ;
/// - onglet **Progression** → `ZStudyProgressRings` (+ DTO PRÉ-CALCULÉ
///   `ZProgressRingsData`, `zcrud_session`) + cartes de stats INJECTÉES ;
/// - navigation de sous-dossiers ADAPTATIVE (sidebar redimensionnable/repliable
///   grand écran ↔ sélecteur compact petit écran) via `ZResponsiveLayout`
///   (seuil `ZWindowSizeThresholds.mediumMinWidth` = 600, jamais codé en dur).
///
/// **AD-2/AD-15/SM-1** — état DÉTENU par ce widget (propriétaire UNIQUE), rendu
/// par tranche via `ValueListenableBuilder` :
/// - `_selected` (`ValueNotifier<String?>`) : la sélection re-invoque
///   `materialSectionsBuilder(id)` ⇒ ne reconstruit QUE le corps Matériel (pas
///   Notebook/Progression, pas la structure de sidebar) ;
/// - `_collapsed` (`ValueNotifier<bool>`) : le repli ne reconstruit QUE la
///   sidebar ;
/// - `_sidebarWidth` (`ValueNotifier<double>`) : la largeur ne reconstruit QUE
///   le chrome de la sidebar.
///
/// **AUCUN** gestionnaire d'état (`flutter_riverpod`/`get`/`provider`), **aucun**
/// `setState` à l'échelle de la page, **aucun** `TabController`/controller recréé
/// au rebuild, **aucune** I/O (la persistance de largeur passe par le callback
/// injecté `ZSubfolderNavSpec.onSidebarWidthChanged`).
///
/// **AD-13** : `Semantics`, cibles ≥ 48 dp, insets/alignements DIRECTIONNELS
/// (sidebar ancrée côté start), libellés & thème INJECTÉS (repli `Theme.of`).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_responsive/zcrud_responsive.dart' show ZResponsiveLayout;
import 'package:zcrud_session/zcrud_session.dart'
    show ZProgressRingsData, ZStudyProgressRings;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart'
    show
        ZAppBarAction,
        ZAppBarSearchConfig,
        ZPageAppBarMode,
        ZPageScaffold,
        ZPageTab;

import 'z_sectioned_study_layout.dart';
import 'z_study_tools_section_spec.dart';
import 'z_subfolder_compact_selector.dart';
import 'z_subfolder_nav_spec.dart';
import 'z_subfolder_sidebar.dart';

/// Diamètre de la pastille d'accent de l'en-tête (dimension de layout).
const double _kHeaderAccentSize = 12.0;

/// Construit les sections « Matériel » pour le sous-dossier [selectedSubfolderId]
/// (`null` = tous). Le widget ne filtre AUCUNE donnée lui-même (AD-2) : il
/// re-fournit l'id sélectionné à ce builder INJECTÉ.
typedef ZMaterialSectionsBuilder =
    List<ZStudyToolsSectionSpec> Function(String? selectedSubfolderId);

/// CR-53 — construit un slot LIBRE (en-tête ou pied) de l'onglet « Matériel »
/// pour le sous-dossier [selectedSubfolderId] (`null` = tous).
///
/// **Typedef NOUVEAU, COEXISTANT** : [ZMaterialSectionsBuilder] n'est ni changé
/// ni déprécié (il est PUBLIC et déjà exporté — toute retouche de sa signature
/// serait cassante). Les slots sont une capacité ORTHOGONALE (AD-4), pas une
/// extension du contrat « sections » : les fusionner dans un builder unique
/// rendant un agrégat aurait forcé TOUS les hôtes existants à migrer, ou imposé
/// deux paramètres mutuellement exclusifs gardés par un `assert` (mode d'échec
/// à l'exécution). Ici, un hôte qui n'utilise pas les slots ne bouge pas d'une
/// ligne.
///
/// Retourner `null` ⇒ slot ABSENT pour cette sélection (AD-4/AD-10) : aucun
/// item n'est réservé dans la liste des sections.
///
/// C'est un BUILDER (et non un `Widget`) parce que le contenu dépend de la
/// sélection de sous-dossier, état DÉTENU par [ZStudyFolderDetail] : l'hôte ne
/// peut pas le pré-construire. Il est invoqué DANS le `ValueListenableBuilder`
/// de la sélection — donc exactement dans la même tranche que
/// [ZMaterialSectionsBuilder], jamais au-dessus (AD-2/SM-1 : un changement de
/// sélection ne reconstruit que le corps Matériel, pas les onglets ni la
/// sidebar).
typedef ZMaterialSlotBuilder =
    Widget? Function(BuildContext context, String? selectedSubfolderId);

/// Page-détail d'un dossier d'étude (ossature composée).
class ZStudyFolderDetail extends StatefulWidget {
  /// Construit la page-détail. Les libellés d'onglets et la navigation
  /// ([nav]) sont INJECTÉS ; les slots absents (`null`) sont structurellement
  /// absents (AD-4).
  const ZStudyFolderDetail({
    required this.title,
    required this.materialTabLabel,
    required this.notebookTabLabel,
    required this.progressionTabLabel,
    required this.materialSectionsBuilder,
    required this.notebookBuilder,
    required this.nav,
    this.materialHeaderBuilder,
    this.materialFooterBuilder,
    this.colorKey,
    this.colorSlotIndex = 0,
    this.materialTabIcon,
    this.notebookTabIcon,
    this.progressionTabIcon,
    this.leading,
    this.sortAction,
    this.addAction,
    this.menuActions = const <ZAppBarAction>[],
    this.search,
    this.mode = ZPageAppBarMode.fixed,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.progressData,
    this.progressStatCards = const <Widget>[],
    this.progressEmptyState,
    this.initialSelectedSubfolderId,
    super.key,
  }) : assert(
         title is Widget || title is String,
         'title doit être un Widget ou un String',
       );

  /// Clé stable de la pastille d'accent d'en-tête (exposée pour les tests).
  static const Key accentKey = ValueKey<String>('suf3:accent');

  /// Titre : `Widget` rendu tel quel, ou `String` emballé dans un `Text`.
  final Object title;

  /// Clé de couleur **opaque** de l'accent du dossier (`null` ⇒ slot de repli).
  final String? colorKey;

  /// Index de repli déterministe passé à `zResolveColorKeyOrSlot`.
  final int colorSlotIndex;

  /// Libellé INJECTÉ de l'onglet Matériel.
  final String materialTabLabel;

  /// Libellé INJECTÉ de l'onglet Notebook.
  final String notebookTabLabel;

  /// Libellé INJECTÉ de l'onglet Progression.
  final String progressionTabLabel;

  /// Icône optionnelle de l'onglet Matériel.
  final IconData? materialTabIcon;

  /// Icône optionnelle de l'onglet Notebook.
  final IconData? notebookTabIcon;

  /// Icône optionnelle de l'onglet Progression.
  final IconData? progressionTabIcon;

  /// Leading optionnel de l'app-bar (rendu ssi fourni — délégué à SUF-1).
  final Widget? leading;

  /// Action de tri (`null` ⇒ absente — AD-4).
  final ZAppBarAction? sortAction;

  /// Action d'ajout (`null` ⇒ absente — AD-4).
  final ZAppBarAction? addAction;

  /// Actions supplémentaires (menu ⋮) — projetées telles quelles.
  final List<ZAppBarAction> menuActions;

  /// Configuration de recherche (`null` ⇒ pas de recherche — SUF-1/AC4).
  final ZAppBarSearchConfig? search;

  /// Mode d'app-bar (fixe vs sliver repliable) — délégué à SUF-1.
  final ZPageAppBarMode mode;

  /// Slots de `Scaffold` relayés au shell (CR-56). Tous restent optionnels.
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? persistentFooterButtons;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  /// Constructeur des sections Matériel selon le sous-dossier sélectionné.
  final ZMaterialSectionsBuilder materialSectionsBuilder;

  /// CR-53 — slot LIBRE rendu **au-dessus des sections** de l'onglet Matériel,
  /// dans le MÊME défilement (câblé sur `ZSectionedStudyLayout.header`).
  ///
  /// `null` (défaut) ⇒ capacité absente : le rendu est STRICTEMENT celui d'avant
  /// CR-53. Un builder qui rend `null` ⇒ slot absent pour cette sélection.
  final ZMaterialSlotBuilder? materialHeaderBuilder;

  /// Symétrique de [materialHeaderBuilder], rendu **sous la dernière section**
  /// (câblé sur `ZSectionedStudyLayout.footer`). `null` ⇒ absent.
  final ZMaterialSlotBuilder? materialFooterBuilder;

  /// Constructeur du corps de l'onglet Notebook (slot).
  final WidgetBuilder notebookBuilder;

  /// DTO d'affichage PRÉ-CALCULÉ de progression (`null` ⇒ état vide neutre).
  final ZProgressRingsData? progressData;

  /// Cartes de stats INJECTÉES sous l'anneau (slot, défaut `const []`).
  final List<Widget> progressStatCards;

  /// État vide INJECTÉ de l'onglet Progression quand [progressData] est `null`
  /// (message via label injecté). `null` ⇒ `SizedBox.shrink()` (jamais de throw).
  final Widget? progressEmptyState;

  /// Navigation de sous-dossiers (données + labels + bornes, tout injecté).
  final ZSubfolderNavSpec nav;

  /// Sélection initiale (`null` = item racine « Tous les sous-dossiers »).
  final String? initialSelectedSubfolderId;

  @override
  State<ZStudyFolderDetail> createState() => _ZStudyFolderDetailState();
}

class _ZStudyFolderDetailState extends State<ZStudyFolderDetail> {
  // État DÉTENU (propriétaire unique) — créé une fois, disposé une fois (AD-2).
  late final ValueNotifier<String?> _selected;
  late final ValueNotifier<bool> _collapsed;
  late final ValueNotifier<double> _sidebarWidth;

  @override
  void initState() {
    super.initState();
    _selected = ValueNotifier<String?>(widget.initialSelectedSubfolderId);
    _collapsed = ValueNotifier<bool>(false);
    _sidebarWidth = ValueNotifier<double>(widget.nav.initialSidebarWidth);
  }

  @override
  void dispose() {
    _selected.dispose();
    _collapsed.dispose();
    _sidebarWidth.dispose();
    super.dispose();
  }

  void _select(String? id) => _selected.value = id;

  void _toggleCollapsed() => _collapsed.value = !_collapsed.value;

  void _emitWidth() =>
      widget.nav.onSidebarWidthChanged?.call(_sidebarWidth.value);

  @override
  Widget build(BuildContext context) {
    final actions = <ZAppBarAction>[
      if (widget.sortAction != null) widget.sortAction!,
      if (widget.addAction != null) widget.addAction!,
      ...widget.menuActions,
    ];

    return ZPageScaffold(
      title: _titleWidget(context),
      leading: widget.leading,
      actions: actions,
      search: widget.search,
      mode: widget.mode,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      persistentFooterButtons: widget.persistentFooterButtons,
      drawer: widget.drawer,
      endDrawer: widget.endDrawer,
      bottomNavigationBar: widget.bottomNavigationBar,
      bottomSheet: widget.bottomSheet,
      backgroundColor: widget.backgroundColor,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      extendBody: widget.extendBody,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      tabs: <ZPageTab>[
        ZPageTab(
          label: widget.materialTabLabel,
          icon: widget.materialTabIcon,
          contentBuilder: _materialTab,
        ),
        ZPageTab(
          label: widget.notebookTabLabel,
          icon: widget.notebookTabIcon,
          contentBuilder: widget.notebookBuilder,
        ),
        ZPageTab(
          label: widget.progressionTabLabel,
          icon: widget.progressionTabIcon,
          contentBuilder: _progressionTab,
        ),
      ],
    );
  }

  // --- En-tête (accent dérivé, jamais codé en dur) ---------------------------

  Widget _titleWidget(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final ZColorPair pair = zResolveColorKeyOrSlot(
      context,
      widget.colorKey ?? '',
      slotIndex: widget.colorSlotIndex,
    );
    final Widget titleChild = widget.title is Widget
        ? widget.title as Widget
        : Text(widget.title as String, textAlign: TextAlign.start);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          key: ZStudyFolderDetail.accentKey,
          width: _kHeaderAccentSize,
          height: _kHeaderAccentSize,
          decoration: BoxDecoration(color: pair.color, shape: BoxShape.circle),
        ),
        SizedBox(width: theme.gapS),
        Flexible(child: titleChild),
      ],
    );
  }

  // --- Onglet Matériel : nav adaptative + corps filtré -----------------------

  Widget _materialTab(BuildContext context) {
    return ZResponsiveLayout(
      // < 600 dp : sélecteur compact, AUCUNE sidebar dans l'arbre (AC7).
      compact: (context) => Column(
        children: <Widget>[
          ZSubfolderCompactSelector(
            spec: widget.nav,
            selected: _selected,
            onSelect: _select,
          ),
          Expanded(child: _materialBody()),
        ],
      ),
      // ≥ 600 dp : sidebar, AUCUN sélecteur compact (expanded cascade → medium).
      medium: (context) => Row(
        children: <Widget>[
          _sidebarRegion(context),
          Expanded(child: _materialBody()),
        ],
      ),
    );
  }

  /// Corps Matériel : la SEULE tranche reconstruite au changement de sélection
  /// (AD-2/SM-1). Re-invoque `materialSectionsBuilder(id)` — jamais de filtrage
  /// métier ici.
  Widget _materialBody() {
    return ValueListenableBuilder<String?>(
      valueListenable: _selected,
      builder: (context, id, _) => ZSectionedStudyLayout(
        sections: widget.materialSectionsBuilder(id),
        // CR-53 — slots par sous-dossier SÉLECTIONNÉ. Builder absent OU rendant
        // `null` ⇒ slot absent structurellement (AD-4/AD-10) : le layout ne
        // réserve alors AUCUN item.
        header: widget.materialHeaderBuilder?.call(context, id),
        footer: widget.materialFooterBuilder?.call(context, id),
      ),
    );
  }

  /// Région sidebar : le repli (`VLB<bool>`) et la largeur (`VLB<double>`) sont
  /// scopés ICI — replier/redimensionner ne reconstruit QUE la sidebar, jamais
  /// le corps Matériel (sibling `Expanded`) ni les onglets (AC14).
  Widget _sidebarRegion(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _collapsed,
      builder: (context, collapsed, _) {
        if (collapsed) {
          return SizedBox(
            width: widget.nav.collapsedWidth,
            child: ZSubfolderSidebar(
              spec: widget.nav,
              collapsed: true,
              width: widget.nav.collapsedWidth,
              minWidth: widget.nav.minSidebarWidth,
              maxWidth: widget.nav.minSidebarWidth,
              selected: _selected,
              onSelect: _select,
              onToggleCollapsed: _toggleCollapsed,
              onWidthChanged: (_) {},
              onWidthChangeEnd: () {},
            ),
          );
        }
        final screenWidth = MediaQuery.sizeOf(context).width;
        final maxWidth = math.max(
          widget.nav.minSidebarWidth,
          screenWidth * widget.nav.maxSidebarWidthFraction,
        );
        return ValueListenableBuilder<double>(
          valueListenable: _sidebarWidth,
          builder: (context, width, _) {
            final clamped = width
                .clamp(widget.nav.minSidebarWidth, maxWidth)
                .toDouble();
            return SizedBox(
              width: clamped,
              child: ZSubfolderSidebar(
                spec: widget.nav,
                collapsed: false,
                width: clamped,
                minWidth: widget.nav.minSidebarWidth,
                maxWidth: maxWidth,
                selected: _selected,
                onSelect: _select,
                onToggleCollapsed: _toggleCollapsed,
                onWidthChanged: (w) => _sidebarWidth.value = w,
                onWidthChangeEnd: _emitWidth,
              ),
            );
          },
        );
      },
    );
  }

  // --- Onglet Progression : anneau RÉUTILISÉ + cartes de stats injectées -----

  Widget _progressionTab(BuildContext context) {
    final data = widget.progressData;
    if (data == null) {
      // AD-10 — état vide neutre, jamais de throw ni de division par zéro.
      return widget.progressEmptyState ?? const SizedBox.shrink();
    }
    final theme = ZcrudTheme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsetsDirectional.all(theme.gapL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ZStudyProgressRings(data: data),
            if (widget.progressStatCards.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.gapL),
              ...widget.progressStatCards,
            ],
          ],
        ),
      ),
    );
  }
}
