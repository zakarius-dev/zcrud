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

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZDisplayStateBinding, ZcrudTheme, zResolveColorKeyOrSlot;
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

import 'z_content_hub_launcher.dart';
import 'z_sectioned_study_layout.dart';
import 'z_study_tools_section_spec.dart';
import 'z_subfolder_narrow_nav.dart';
import 'z_subfolder_nav_spec.dart';
import 'z_subfolder_sidebar.dart';

/// Diamètre de la pastille d'accent de l'en-tête (dimension de layout).
const double _kHeaderAccentSize = 12.0;

/// Hauteur **mesurée** de la bande `ZSubfolderNarrowNav` du socle.
///
/// Ce n'est pas un littéral choisi : c'est le résultat d'une mesure sur
/// disque des **deux** variantes, à 360 / 500 / 800 dp de large et avec le
/// bouton d'ajout présent :
///
/// | surface                                | hauteur rendue |
/// |----------------------------------------|----------------|
/// | `ZSubfolderSelectorBar` (défaut)       | 48 dp          |
/// | `ZSubfolderCompactSelector` (`compact`)| 48 dp          |
///
/// Les deux convergent parce qu'elles sont toutes deux gouvernées par la
/// **cible tactile minimale AD-13** (`ConstrainedBox(minHeight: 48)` autour de
/// la rangée), et par rien d'autre : une constante unique convient donc aux
/// deux, et il n'y a **pas** à tronquer l'une pour servir l'autre.
///
/// Ce qui peut la dépasser, et qui se déclare alors explicitement via
/// [ZStudyFolderDetail.subfolderNavBandHeight] : une coquille d'hôte
/// (`ZSubfolderNavRendererScope`), un `itemBuilder` plus haut que 48 dp, un
/// facteur d'échelle de texte élevé. La marge de thème
/// `ZcrudTheme.subfolderBarPadding`, elle, est ajoutée **automatiquement**
/// (cf. `_navBandHeight`) : c'est un token de ce socle, il serait absurde de
/// demander à l'hôte de refaire l'addition.
const double kZSubfolderNavBandHeight = 48.0;

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
    this.subtitle,
    this.gradientKey,
    this.progressionBuilder,
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
    this.aboveTabViews,
    this.aboveTabBar,
    this.aboveTabBarHeight,
    this.subfolderNavBandHeight,
    this.subfolderNavPlacement = ZSubfolderNavPlacement.withinTab,
    this.contentHubLauncher,
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

  /// Sous-titre d'app-bar, **propagé tel quel** à `ZPageScaffold.subtitle`.
  /// `null` (défaut) ⇒ absent de l'arbre : le rendu est strictement celui
  /// sans ce slot.
  final Widget? subtitle;

  /// Identité **opaque et persistante** du dossier ouvert (son id),
  /// propagée à `ZPageScaffold.gradientKey` pour teinter l'en-tête de sa propre
  /// page comme `ZFolderCardGradientAccent` teinte sa carte — **même couture**
  /// (`zResolveGradient`), même clé.
  ///
  /// Sans `ZcrudScope.gradientResolver` injecté par l'hôte, **aucun** dégradé
  /// n'apparaît (chaîne `seam hôte → null`, aucun repli dérivé) : le rendu par
  /// défaut reste inchangé.
  final String? gradientKey;

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

  /// Bouton d'action flottant relayé au `Scaffold` du shell, ou `null`.
  final Widget? floatingActionButton;

  /// Position du bouton d'action flottant, ou `null` pour la position par
  /// défaut du `Scaffold`.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Boutons de pied persistants relayés au `Scaffold`, ou `null`.
  final List<Widget>? persistentFooterButtons;

  /// Tiroir de navigation relayé au `Scaffold`, ou `null`.
  final Widget? drawer;

  /// Tiroir de navigation de fin relayé au `Scaffold`, ou `null`.
  final Widget? endDrawer;

  /// Barre de navigation basse relayée au `Scaffold`, ou `null`.
  final Widget? bottomNavigationBar;

  /// Feuille basse persistante relayée au `Scaffold`, ou `null`.
  final Widget? bottomSheet;

  /// Couleur de fond relayée au `Scaffold`, ou `null` pour la couleur de
  /// thème par défaut.
  final Color? backgroundColor;

  /// Redimensionnement au clavier relayé au `Scaffold`, ou `null` pour le
  /// comportement par défaut.
  final bool? resizeToAvoidBottomInset;

  /// Étend le corps derrière la navigation basse, relayé au `Scaffold`.
  final bool extendBody;

  /// Étend le corps derrière l'app-bar, relayé au `Scaffold`.
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

  /// Constructeur LIBRE du corps de l'onglet Progression, **au même
  /// contrat que [notebookBuilder]** : un `WidgetBuilder` branché directement
  /// sur `ZPageTab.contentBuilder`, qui possède donc tout l'onglet.
  ///
  /// `null` (défaut) ⇒ comportement HISTORIQUE **strictement** conservé :
  /// [ZStudyProgressRings] + [progressStatCards] quand [progressData] est
  /// fourni, [progressEmptyState] sinon. Aucune rupture pour un hôte existant.
  ///
  /// Fourni ⇒ il **prime** sur l'anneau : une progression n'a pas
  /// nécessairement la forme d'un ratio global (des barres linéaires par
  /// catégorie, par exemple, ne se réduisent pas à un anneau).
  ///
  /// **Pourquoi pas [progressEmptyState]** : ce slot signifie « aucune
  /// donnée » ; y injecter un onglet PLEIN inverserait le sens du paramètre et
  /// piégerait le prochain lecteur. [progressEmptyState] conserve donc son sens
  /// exact — il n'est rendu que lorsque [progressData] est `null` **et** qu'aucun
  /// [progressionBuilder] n'est fourni.
  final WidgetBuilder? progressionBuilder;

  /// DTO d'affichage PRÉ-CALCULÉ de progression (`null` ⇒ état vide neutre).
  final ZProgressRingsData? progressData;

  /// Cartes de stats INJECTÉES sous l'anneau (slot, défaut `const []`).
  final List<Widget> progressStatCards;

  /// État vide INJECTÉ de l'onglet Progression quand [progressData] est `null`
  /// (message via label injecté). `null` ⇒ `SizedBox.shrink()` (jamais de throw).
  final Widget? progressEmptyState;

  /// Créneau persistant rendu **sous le `TabBar` et au-dessus du
  /// `TabBarView`**, donc commun à tous les onglets.
  ///
  /// **Chaînon CÂBLÉ, pas créé** : le créneau existe déjà côté socle
  /// (`ZPageScaffold.aboveTabViews`, lui-même délégué à `ZPageShellBody` en mode
  /// sliver) ; cette façade se contente de le relever — comme
  /// [persistentFooterButtons] et [bottomNavigationBar], déjà relayés.
  ///
  /// `null` (défaut) ⇒ slot ABSENT côté shell : aucun wrapper ajouté, rendu
  /// strictement inchangé.
  ///
  /// **Conflit avec [ZSubfolderNavPlacement.aboveTabs] — résolu par
  /// COMPOSITION, jamais par priorité ni par `assert`.** Si l'hôte fournit ce
  /// slot *et* demande `aboveTabs`, les deux sont rendus dans une `Column` :
  /// **la navigation d'abord** (directement sous le `TabBar`), puis ce slot.
  ///
  /// Justification du choix : une **priorité** ferait disparaître silencieusement
  /// l'un des deux contenus demandés (le pire mode d'échec — un slot fourni qui
  /// n'apparaît pas) ; un **`assert`** transformerait une composition légitime en
  /// panne d'exécution en debug et en divergence debug/release (contraire à
  /// AD-10). L'ordre retenu place la navigation au plus près des onglets parce
  /// qu'elle **désigne le sujet** dont tout ce qui suit — le slot de l'hôte comme
  /// les vues d'onglets — parle.
  final Widget? aboveTabViews;

  /// Créneau rendu **entre l'app-bar et la barre d'onglets**
  /// (`ZPageScaffold.aboveTabBar`), donc **dans** l'app-bar, qui grandit
  /// réellement de la hauteur déclarée.
  ///
  /// **Chaînon CÂBLÉ, pas créé** : le créneau est ouvert côté socle (site
  /// unique `_zAppBarBottom`, partagé par le mode fixe et les modes sliver) ;
  /// cette façade ne fait que le relever, comme [aboveTabViews].
  ///
  /// `null` (défaut) ⇒ slot ABSENT côté shell — et la neutralité y est stricte
  /// : sans créneau, le socle rend le `TabBar` **tel quel**, sans `PreferredSize`
  /// interposée. Rendu strictement inchangé.
  ///
  /// **Conflit avec [ZSubfolderNavPlacement.aboveTabBar] — résolu par
  /// COMPOSITION**, exactement comme [aboveTabViews] vs `aboveTabs` : si l'hôte
  /// fournit ce slot *et* demande `aboveTabBar`, les deux sont rendus dans une
  /// `Column` — **la navigation d'abord** (au plus près du titre, dont elle
  /// précise le sujet), puis ce slot. Une priorité ferait disparaître
  /// silencieusement un contenu demandé ; un `assert` transformerait une
  /// composition légitime en panne d'exécution en debug (contraire à AD-10).
  final Widget? aboveTabBar;

  /// Hauteur **déclarée** du slot [aboveTabBar] de l'hôte.
  ///
  /// `null` (défaut) ⇒ repli du socle : `preferredSize` du slot s'il est un
  /// `PreferredSizeWidget`, sinon `kToolbarHeight`.
  ///
  /// **Elle décrit le slot de l'hôte, PAS la bande de navigation** : sous
  /// [ZSubfolderNavPlacement.aboveTabBar] avec un slot d'hôte, la hauteur
  /// transmise au socle est la **somme** `bande + slot` (cf.
  /// [subfolderNavBandHeight]). Les deux réglages restent donc indépendants :
  /// déclarer l'un ne force jamais à redéclarer l'autre.
  final double? aboveTabBarHeight;

  /// Hauteur **déclarée** de la bande de navigation hissée sous
  /// [ZSubfolderNavPlacement.aboveTabBar].
  ///
  /// `null` (défaut) ⇒ [kZSubfolderNavBandHeight] (48 dp, **mesuré** sur les
  /// deux surfaces du socle) **plus** la marge verticale de
  /// `ZcrudTheme.subfolderBarPadding` quand elle s'applique (barre de sélection
  /// uniquement — la rangée de puces n'en pose pas).
  ///
  /// **Pourquoi une hauteur DÉCLARÉE et non mesurée** : le créneau vit dans
  /// le `bottom:` de l'app-bar, dont la `preferredSize` doit être connue
  /// **avant** la mise en page — le `Scaffold` a déjà réservé la hauteur de
  /// l'app-bar quand une mesure a posteriori arriverait. C'est la contrainte du
  /// socle, pas un raccourci.
  ///
  /// À renseigner quand la bande rendue n'est **pas** celle du socle ou n'a pas
  /// sa hauteur : coquille d'hôte injectée via `ZSubfolderNavRendererScope`,
  /// `ZSubfolderNavSpec.itemBuilder` plus haut que 48 dp, facteur d'échelle de
  /// texte élevé. Sous-déclarer produit un **overflow signalé par Flutter** —
  /// bruyant, jamais un recouvrement muet du `TabBar` (c'est précisément ce que
  /// la voie `subtitle`, elle, aurait fait en silence).
  ///
  /// Sans effet hors de [ZSubfolderNavPlacement.aboveTabBar].
  final double? subfolderNavBandHeight;

  /// **Où** vit la navigation de fratrie. Défaut
  /// [ZSubfolderNavPlacement.withinTab] ⇒ rendu strictement inchangé pour tout
  /// hôte existant. Voir [ZSubfolderNavPlacement.aboveTabs] pour l'arbitrage
  /// **mesuré** sur la forme large (aucune sidebar hissée).
  final ZSubfolderNavPlacement subfolderNavPlacement;

  /// Navigation de sous-dossiers (données + labels + bornes, tout injecté).
  final ZSubfolderNavSpec nav;

  /// Le hub d'ajout de contenu partagé par tous les `+` de la page.
  ///
  /// `null` (défaut) ⇒ capacité ABSENTE et **arbre STRICTEMENT identique** à
  /// sans ce slot : aucun `ZContentHubScope` n'est inséré, [addAction] est
  /// projetée telle quelle, aucune section ne peut résoudre de hub. Garde
  /// dédiée (comparaison d'arbre, pas de simple absence d'exception).
  ///
  /// Non-null ⇒ **deux** effets, tous deux additifs :
  ///
  /// 1. un [ZContentHubScope] enveloppe la page — c'est ce qui fait que le `+`
  ///    d'app-bar et le `+` d'une section
  ///    (`ZStudyToolsSectionSpec.addOpensContentHub`) ouvrent **le même** hub,
  ///    configuré **une seule fois** ;
  /// 2. si (et seulement si) [addAction] est fournie **avec un `onPressed`
  ///    nul**, sa commande est complétée par l'ouverture du hub.
  ///
  /// **Le paramètre de l'hôte PRIME, toujours.** Une [addAction] qui porte
  /// déjà un `onPressed` n'est **jamais** réécrite : le hub ne peut pas
  /// détourner silencieusement une commande que l'hôte a explicitement câblée.
  /// C'est la même priorité que partout ailleurs dans ce package (paramètre >
  /// jeton > référence), appliquée ici au comportement.
  ///
  /// **Le socle n'invente ni glyphe ni libellé** : sans [addAction], aucun
  /// bouton n'apparaît — `ZAppBarAction` exige un `icon` **et** un
  /// `semanticLabel`, que seul l'hôte peut fournir (FR-26/AD-13). Le launcher
  /// apporte la *commande*, jamais l'*apparence*.
  final ZContentHubLauncher? contentHubLauncher;

  /// Sélection initiale (`null` = item racine « Tous les sous-dossiers »).
  ///
  /// **IGNORÉ quand `nav.selectionController` est fourni** : le
  /// contrôleur est alors le **propriétaire** de l'état, donc de son amorce
  /// (`initialValue`). Recopier cette valeur dedans au montage ferait écrire le
  /// socle dans l'état de l'hôte — et écraserait une sélection que l'hôte a pu
  /// restaurer d'un lien profond. Même arbitrage que
  /// `ZStudyToolsSectionSpec.expandController` vs `initiallyExpanded`.
  final String? initialSelectedSubfolderId;

  @override
  State<ZStudyFolderDetail> createState() => _ZStudyFolderDetailState();
}

class _ZStudyFolderDetailState extends State<ZStudyFolderDetail> {
  /// Liaison de sélection : **état interne par défaut**,
  /// contrôleur de l'hôte quand `nav.selectionController` est fourni.
  ///
  /// Ce n'est PAS un miroir (patron `ZDisplayState`, clause 2) : quand l'hôte
  /// pilote, lecture **et** écriture le traversent — la page ne garde aucune
  /// copie, donc rien ne peut diverger entre la barre, la sidebar, le corps
  /// filtré et le second chemin de l'hôte.
  late final ZDisplayStateBinding<String?> _selection;

  // État DÉTENU (propriétaire unique) — créé une fois, disposé une fois (AD-2).
  late final ValueNotifier<bool> _collapsed;
  late final ValueNotifier<double> _sidebarWidth;

  /// Écoute **STABLE** de la sélection, y compris au travers d'un changement de
  /// contrôleur : c'est un relais d'écoute, jamais un relais de valeur. Sans
  /// cette stabilité, un changement de contrôleur exigerait un `setState` à
  /// l'échelle de la page — ce qu'AD-2 interdit.
  ValueListenable<String?> get _selected => _selection.listenable;

  @override
  void initState() {
    super.initState();
    _selection = ZDisplayStateBinding<String?>(
      consumer: this,
      // Amorce de l'état INTERNE. Sans contrôleur c'est la sélection initiale ;
      // avec contrôleur, `bind` bascule la source et cette valeur n'est jamais
      // lue (précédence documentée : le contrôleur prime).
      initialValue: widget.initialSelectedSubfolderId,
    )..bind(widget.nav.selectionController);
    // `bind(null)` au montage est un NO-OP (early-return sur `identical`) —
    // vérifié dans `ZDisplayStateBinding.bind`. C'est exactement ce qu'il faut
    // ici : la liaison naît déjà repliée sur son état interne, amorcé
    // ci-dessus. Aucune notification ne part donc au montage.
    if (widget.nav.onSelectionChanged != null) {
      _selection.listenable.addListener(_emitSelection);
    }
    _collapsed = ValueNotifier<bool>(false);
    _sidebarWidth = ValueNotifier<double>(widget.nav.initialSidebarWidth);
  }

  @override
  void didUpdateWidget(covariant ZStudyFolderDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'hôte a le droit de changer (ou de retirer) son pilote : sans cela la
    // page resterait branchée sur l'ancien, muette pour le nouveau.
    _selection.bind(widget.nav.selectionController);
    // Le listener est installé selon la PRÉSENCE du callback, jamais selon son
    // identité : une closure recréée à chaque build ne doit pas provoquer un
    // désabonnement/réabonnement (elle est relue à l'émission).
    final bool had = oldWidget.nav.onSelectionChanged != null;
    final bool has = widget.nav.onSelectionChanged != null;
    if (had == has) return;
    if (has) {
      _selection.listenable.addListener(_emitSelection);
    } else {
      _selection.listenable.removeListener(_emitSelection);
    }
  }

  @override
  void dispose() {
    _selection.listenable.removeListener(_emitSelection);
    // Ne dispose JAMAIS le contrôleur de l'hôte : il ne nous appartient pas
    // (son propriétaire est un `State` de l'hôte, via `ZDisplayStateOwnerMixin`).
    _selection.dispose();
    _collapsed.dispose();
    _sidebarWidth.dispose();
    super.dispose();
  }

  /// Constate le changement de sélection vers l'hôte (clause 3 du patron).
  /// Le callback est relu à l'émission — jamais capturé au moment de l'abonnement.
  void _emitSelection() =>
      widget.nav.onSelectionChanged?.call(_selection.value);

  /// Écrit À LA SOURCE : avec un contrôleur, un tap dans la barre ou la sidebar
  /// commande l'état de l'hôte — les deux chemins n'en font qu'un.
  void _select(String? id) => _selection.value = id;

  void _toggleCollapsed() => _collapsed.value = !_collapsed.value;

  void _emitWidth() =>
      widget.nav.onSidebarWidthChanged?.call(_sidebarWidth.value);

  @override
  Widget build(BuildContext context) {
    // Lot 2 — `null` (défaut) ⇒ TOUT ce qui suit est le chemin d'avant : aucune
    // action réécrite, aucun nœud ajouté.
    final ZContentHubLauncher? hub = widget.contentHubLauncher;
    final ZAppBarAction? addAction = widget.addAction;
    final actions = <ZAppBarAction>[
      if (widget.sortAction != null) widget.sortAction!,
      if (addAction != null)
        hub == null ? addAction : _hubBoundAddAction(addAction, hub),
      ...widget.menuActions,
    ];

    final Widget scaffold = ZPageScaffold(
      title: _titleWidget(context),
      // Pass-through pur : `null` ⇒ slots absents côté shell.
      subtitle: widget.subtitle,
      gradientKey: widget.gradientKey,
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
      // Relève du chaînon (+ composition avec la navigation hissée). `null`
      // ⇒ créneau structurellement absent.
      aboveTabViews: _aboveTabViews(context),
      // Créneau ENTRE l'app-bar et le `TabBar`. `null` ⇒ créneau
      // structurellement absent côté shell (neutralité stricte du socle).
      aboveTabBar: _aboveTabBar(context),
      aboveTabBarHeight: _aboveTabBarHeight(context),
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
          // Même câblage que l'onglet Notebook : le builder INJECTÉ possède
          // l'onglet ; absent ⇒ anneau historique (`_progressionTab`).
          contentBuilder: widget.progressionBuilder ?? _progressionTab,
        ),
      ],
    );

    // Invariant AD-4 — sans hub, AUCUN nœud n'est ajouté au-dessus du shell :
    // l'arbre rendu est celui sans ce slot, à l'identique (garde de
    // comparaison d'arbre, pas une simple absence d'exception).
    if (hub == null) return scaffold;
    return ZContentHubScope(launcher: hub, child: scaffold);
  }

  /// Complète la commande d'une action d'ajout par l'ouverture du hub — **et
  /// seulement si l'hôte ne l'a pas câblée lui-même**.
  ///
  /// Priorité **paramètre de l'hôte > hub** : une action qui porte déjà un
  /// `onPressed` est rendue TELLE QUELLE (`identical`, aucun `ZAppBarAction`
  /// neuf). Réécrire une commande explicite serait un détournement silencieux —
  /// le pire mode d'échec pour un hôte qui a fourni son propre callback.
  ///
  /// Ne touche **que** l'action d'ajout : `sortAction` et `menuActions` sont
  /// projetées inchangées. Un `+` qui ouvre le hub est un contrat nommé ; un
  /// menu de débordement dont les entrées changeraient de commande n'en serait
  /// pas un.
  ZAppBarAction _hubBoundAddAction(
    ZAppBarAction action,
    ZContentHubLauncher hub,
  ) {
    if (action.onPressed != null) return action;
    void open() => hub.open(context);
    final Widget? child = action.child;
    // Les deux constructeurs de `ZAppBarAction` sont distincts (icône vs
    // widget) : reconstruire par le mauvais perdrait le widget porté.
    return child == null
        ? ZAppBarAction(
            icon: action.icon,
            semanticLabel: action.semanticLabel,
            onPressed: open,
            tooltip: action.tooltip,
            isOverflow: action.isOverflow,
          )
        : ZAppBarAction.widget(
            child: child,
            semanticLabel: action.semanticLabel,
            onPressed: open,
            tooltip: action.tooltip,
            isOverflow: action.isOverflow,
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

  // --- Créneau AU-DESSUS des onglets -----------------------------------------

  /// Contenu du créneau `aboveTabViews` du shell.
  ///
  /// Trois cas, dans cet ordre :
  /// 1. placement ≠ [ZSubfolderNavPlacement.aboveTabs] ⇒ **pass-through pur**
  ///    du slot de l'hôte (`null` ⇒ créneau absent) : sous `withinTab` (défaut)
  ///    la navigation reste dans l'onglet Matériel, sous `aboveTabBar` elle est
  ///    hissée dans l'app-bar — dans les deux cas ce créneau-ci est inchangé ;
  /// 2. `aboveTabs` sans slot d'hôte ⇒ la **bande** de navigation seule ;
  /// 3. `aboveTabs` **et** slot d'hôte ⇒ COMPOSITION (cf. doc de
  ///    [ZStudyFolderDetail.aboveTabViews]) : navigation d'abord, slot ensuite.
  ///
  /// La bande est construite **hors** de l'arbre des onglets et n'écoute que la
  /// tranche `_selected` en son sein (`ValueListenableBuilder` interne à la
  /// surface) : changer de fratrie ne reconstruit ni les onglets ni la structure
  /// de page (AD-2/SM-1).
  Widget? _aboveTabViews(BuildContext context) {
    final Widget? hostSlot = widget.aboveTabViews;
    // Ce créneau n'accueille la navigation QUE sous `aboveTabs` :
    // `withinTab` la laisse dans l'onglet, `aboveTabBar` la hisse dans
    // l'app-bar. Dans les deux cas, pass-through pur du slot de l'hôte.
    if (widget.subfolderNavPlacement != ZSubfolderNavPlacement.aboveTabs) {
      return hostSlot;
    }
    final Widget nav = _navBand();
    // **Aucun étirement explicite** : un `SizedBox(width: double.infinity)`
    // a été écrit, puis MESURÉ INERTE (les deux surfaces du socle rendent déjà
    // 500 dp sur 500 dp de large sans lui — leur `Row` interne est en
    // `mainAxisSize.max`) et retiré. Une garde le confirmait verte avec ET sans
    // le wrapper : c'était une boîte vide, pas une propriété.
    if (hostSlot == null) return nav;
    // **Aucun `crossAxisAlignment` non plus** — et c'est LOAD-BEARING :
    // `ZPageScaffold` pose déjà son créneau dans une `Column` en alignement
    // transversal PAR DÉFAUT. En étirant ici, le slot de l'hôte serait mis en
    // page **différemment** selon qu'il demande ou non `aboveTabs` — un widget
    // sans largeur propre passerait de 0 dp à pleine largeur pour une raison
    // qui n'a rien à voir avec lui. Le défaut préserve l'équivalence.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[nav, hostSlot],
    );
  }

  // --- Créneau ENTRE l'app-bar et la barre d'onglets -------------------------

  /// La bande de navigation hissée — **une seule** construction, partagée par
  /// les deux créneaux (`aboveTabViews` et `aboveTabBar`), donc **une seule**
  /// source de sélection (`_selected`) et une seule surface possible.
  ///
  /// Elle n'écoute la tranche `_selected` qu'en son sein
  /// (`ValueListenableBuilder` interne aux surfaces) : changer de fratrie ne
  /// reconstruit ni les onglets ni la structure de page (AD-2/SM-1).
  Widget _navBand() => ZSubfolderNarrowNav(
    spec: widget.nav,
    selected: _selected,
    onSelect: _select,
  );

  /// Contenu du créneau `aboveTabBar` du shell.
  ///
  /// Trois cas, symétriques de [_aboveTabViews] :
  /// 1. placement ≠ [ZSubfolderNavPlacement.aboveTabBar] ⇒ **pass-through pur**
  ///    du slot de l'hôte (`null` ⇒ créneau absent, arbre inchangé) ;
  /// 2. `aboveTabBar` sans slot d'hôte ⇒ la **bande** seule ;
  /// 3. `aboveTabBar` **et** slot d'hôte ⇒ COMPOSITION : navigation d'abord,
  ///    slot ensuite.
  Widget? _aboveTabBar(BuildContext context) {
    final Widget? hostSlot = widget.aboveTabBar;
    if (widget.subfolderNavPlacement != ZSubfolderNavPlacement.aboveTabBar) {
      return hostSlot;
    }
    final Widget nav = _navBand();
    if (hostSlot == null) return nav;
    // `crossAxisAlignment: stretch` — et c'est LOAD-BEARING, **à l'inverse**
    // du site `aboveTabViews` juste au-dessus. La règle est la même (« composer
    // ne doit pas changer la mise en page du slot de l'hôte »), la réponse est
    // opposée parce que le socle n'aligne pas pareil des deux côtés :
    // * `aboveTabViews` est posé dans une `Column` en alignement transversal
    //   PAR DÉFAUT ⇒ y étirer changerait la largeur du slot de l'hôte ;
    // * `aboveTabBar` est posé, lui, dans une `Column`
    //   `CrossAxisAlignment.stretch` (site `_zAppBarBottom` du socle) ⇒ un slot
    //   d'hôte SEUL y reçoit la largeur pleine. Sans `stretch` ici, il passerait
    //   de pleine largeur à sa largeur intrinsèque du seul fait qu'on lui a
    //   adjoint la navigation. C'est la même exigence d'équivalence, pas une
    //   incohérence : elle se lit sur le site réel, jamais par recopie.
    // `stretch` n'introduit par ailleurs aucune notion de left/right (AD-13).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[nav, hostSlot],
    );
  }

  /// Hauteur **déclarée** transmise au créneau `aboveTabBar`.
  ///
  /// Hors [ZSubfolderNavPlacement.aboveTabBar] : pass-through pur de
  /// [ZStudyFolderDetail.aboveTabBarHeight] — le repli du socle (`preferredSize`
  /// puis `kToolbarHeight`) s'applique alors intact.
  ///
  /// Sous `aboveTabBar` : hauteur de la bande, **plus** celle du slot de l'hôte
  /// quand il y en a un (le créneau porte alors les deux).
  double? _aboveTabBarHeight(BuildContext context) {
    if (widget.subfolderNavPlacement != ZSubfolderNavPlacement.aboveTabBar) {
      return widget.aboveTabBarHeight;
    }
    final double band = _navBandHeight(context);
    final Widget? hostSlot = widget.aboveTabBar;
    if (hostSlot == null) return band;
    // Même chaîne de repli que le socle pour la part de l'hôte — elle doit être
    // rejouée ici parce qu'on additionne : le socle ne peut plus l'appliquer sur
    // un composé dont il ignore la décomposition. `kToolbarHeight` est une
    // métrique de la plateforme, pas un littéral inventé (FR-26).
    final double host =
        widget.aboveTabBarHeight ??
        (hostSlot is PreferredSizeWidget
            ? hostSlot.preferredSize.height
            : kToolbarHeight);
    return band + host;
  }

  /// Hauteur déclarée de la BANDE seule.
  ///
  /// Ordre : réglage explicite de l'hôte → [kZSubfolderNavBandHeight] (mesuré)
  /// augmenté de la marge verticale de thème quand elle s'applique.
  ///
  /// La marge n'est ajoutée que pour [ZSubfolderNarrowMode.selector] : c'est la
  /// seule surface qui pose `ZcrudTheme.subfolderBarPadding` — la rangée de
  /// puces n'en pose aucune, l'y compter réserverait du vide.
  double _navBandHeight(BuildContext context) {
    final double? declared = widget.subfolderNavBandHeight;
    if (declared != null) return declared;
    if (widget.nav.narrowMode != ZSubfolderNarrowMode.selector) {
      return kZSubfolderNavBandHeight;
    }
    final EdgeInsetsGeometry? padding = ZcrudTheme.of(
      context,
    ).subfolderBarPadding;
    if (padding == null) return kZSubfolderNavBandHeight;
    return kZSubfolderNavBandHeight +
        padding.resolve(Directionality.of(context)).vertical;
  }

  // --- Onglet Matériel : nav adaptative + corps filtré -----------------------

  Widget _materialTab(BuildContext context) {
    // Navigation hissée (dans l'un OU l'autre créneau) :
    // l'onglet ne rend QUE son corps filtré. C'est ce qui garantit qu'elle est
    // rendue **une seule fois** (pas de duplication bande + sidebar), et donc
    // que la sélection n'a qu'une source.
    if (widget.subfolderNavPlacement != ZSubfolderNavPlacement.withinTab) {
      return _materialBody();
    }
    return ZResponsiveLayout(
      // < 600 dp : sélecteur compact, AUCUNE sidebar dans l'arbre (AC7).
      compact: (context) => Column(
        children: <Widget>[
          // Aiguillage : coquille de l'hôte (seam de SURFACE) → barre de
          // sélection (DÉFAUT) → rangée de puces (`narrowMode: compact`,
          // historique).
          ZSubfolderNarrowNav(
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
