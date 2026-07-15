/// `ZStudyMindmapSection` — section « carte mentale » de la page study-tools
/// (Story ES-7.1, AD-25/AD-4/AD-28). ADAPTATEUR MINCE de COMPOSITION : elle
/// assemble, dans le layout sectionné (`ZStudyToolsSectionSpec`), la surface
/// publique DÉJÀ LIVRÉE de `zcrud_mindmap` — [ZMindmapView] (lecture, graphe
/// graphite E10-2) et [ZMindmapOutlineEditor]/[ZMindmapOutlineController]
/// (édition outline E10-3) — SANS jamais réimplémenter le moteur graphite ni
/// porter le flowchart legacy IFFD.
///
/// Invariants (NON-NÉGOCIABLES) :
/// - **AD-1** : la seule arête introduite est `zcrud_study → zcrud_mindmap`
///   (graphe acyclique, CORE OUT=0). `graphite` reste **transitif** via
///   `zcrud_mindmap` — JAMAIS en dépendance directe. AUCUN import
///   `flutter_flow_chart`/`graphview`/`graphite` ici (verrou-source AC2).
/// - **AD-2/AD-15** : réactivité Flutter-native pure. Aucun gestionnaire d'état,
///   aucun `WidgetRef`/`Get.`/`Provider.of`. Le [ZMindmapOutlineController]
///   POSSÉDÉ est créé en `initState` (jamais dans `build`) et disposé au
///   `dispose` — un controller INJECTÉ est utilisé tel quel et JAMAIS disposé
///   (patron owned/injected de `ZStudyToolsPage`/`ZFormController`, ES-5.2). La
///   bascule lecture ⇄ édition vit dans un `ValueNotifier` **LOCAL** ⇒ seul le
///   sous-arbre de la section se reconstruit (frontière SM-1 préservée).
/// - **AD-4** : `folderId` = `String` opaque ; clé de sous-arbre NEUTRE
///   `ValueKey('mindmap:<folderId>')` (jamais l'entité `ZStudyFolder`) ;
///   `addAction` `null` = action ABSENTE (jamais un no-op) ; réutilise
///   `ZStudyToolsSectionSpec`.
/// - **AD-28** : le `content` de nœud reste **texte brut** — la section n'ajoute
///   AUCUN champ rich-text, n'importe PAS `zcrud_markdown` : le rendu riche
///   éventuel est un slot opt-in câblé CÔTÉ APP via [nodeContentBuilder].
/// - **AD-13/FR-26** : chrome directionnel (`EdgeInsetsDirectional`,
///   `TextAlign.start`), `Semantics` explicites, cible de bascule ≥ 48 dp,
///   couleurs/labels INJECTÉS via `ZcrudTheme.of` (repli `Theme.of`).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

import 'z_study_tools_section_spec.dart';

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Hauteur de repli du viewport mindmap (bornes de contraintes requises par le
/// graphe graphite et par le `ListView` interne de l'éditeur — tous deux imbriqués
/// dans le `ListView.builder` du layout sectionné, donc hauteur non bornée sinon).
/// Dimension de LAYOUT admissible (comme `ZMindmapViewConfig.cellSize`) — jamais
/// une couleur/un label codé en dur ; surchargeable par l'appelant.
const double _kDefaultViewportHeight = 320.0;

/// Glyphe de REPLI de la bascule « passer en édition » (défaut neutre documenté,
/// même patron justifié que les replis d'icône d'`ZSectionedStudyLayout`). Dès
/// qu'une icône est injectée, elle prime. La SÉMANTIQUE (label a11y) reste, elle,
/// toujours injectée (aucun libellé jamais codé en dur, AD-13/FR-26).
const IconData _kEnterEditFallbackIcon = Icons.edit_outlined;

/// Glyphe de REPLI de la bascule « revenir en lecture » (même patron).
const IconData _kEnterReadFallbackIcon = Icons.visibility_outlined;

/// Mode d'affichage de [ZStudyMindmapSection], **local au package** (AD-4). Il ne
/// se confond PAS avec [ZMindmapViewMode] (graphe ⇄ liste, interne à la lecture) :
/// il choisit entre la surface LECTURE ([ZMindmapView]) et la surface ÉDITION
/// ([ZMindmapOutlineEditor]).
enum ZStudyMindmapMode {
  /// Lecture seule : composition de [ZMindmapView] (graphe/liste a11y).
  read,

  /// Édition : composition de [ZMindmapOutlineEditor] (outline éditable).
  edit,
}

/// Section « carte mentale » composée par `folderId` dans la page study-tools.
///
/// `StatefulWidget` **uniquement** pour (a) le cycle de vie du
/// [ZMindmapOutlineController] POSSÉDÉ (créé `initState` ssi non injecté, disposé
/// `dispose` ssi possédé) et (b) le `ValueNotifier<ZStudyMindmapMode>` **local**
/// de la bascule lecture ⇄ édition. JAMAIS pour l'état de la carte (qui vit dans
/// le controller / la donnée immuable passée en entrée).
class ZStudyMindmapSection extends StatefulWidget {
  /// Construit la section pour un dossier identifié par [folderId] (clé neutre).
  ///
  /// Fournir la forêt via [mindmap] (prioritaire) OU [roots]. [outlineController]
  /// injecté est UTILISÉ tel quel et JAMAIS disposé par la section (propriété de
  /// l'appelant) ; s'il est `null`, la section en crée/possède un (seedé depuis
  /// la forêt fournie) et le dispose. Tous les libellés/icônes sont INJECTÉS
  /// (repli neutre documenté) — AD-13/FR-26.
  const ZStudyMindmapSection({
    required this.folderId,
    this.mindmap,
    this.roots,
    this.initialMode = ZStudyMindmapMode.read,
    this.viewMode = ZMindmapViewMode.graph,
    this.nodeContentBuilder,
    this.outlineController,
    this.viewConfig = const ZMindmapViewConfig(),
    this.outlineLabels = const ZMindmapOutlineLabels(),
    this.emptyLabel,
    this.onSave,
    this.onChanged,
    this.editContentField = true,
    this.viewportHeight = _kDefaultViewportHeight,
    this.enterEditSemanticLabel = 'Modifier la carte mentale',
    this.enterReadSemanticLabel = 'Afficher la carte mentale',
    this.enterEditIcon,
    this.enterReadIcon,
    super.key,
  }) : assert(mindmap != null || roots != null,
            'Fournir `mindmap` ou `roots`.');

  /// Identifiant OPAQUE (`String`) du dossier porteur de la carte (clé neutre du
  /// sous-arbre : `ValueKey('mindmap:$folderId')`). JAMAIS l'entité kernel —
  /// préserve AD-1 (aucune arête réintroduite vers `zcrud_study_kernel`).
  final String folderId;

  /// Carte mentale immuable (forêt titrée). Prioritaire sur [roots].
  final ZMindmap? mindmap;

  /// Racines de la forêt (alternative à [mindmap]).
  final List<ZMindmapNode>? roots;

  /// Mode initial de la section (lecture par défaut).
  final ZStudyMindmapMode initialMode;

  /// Sous-mode de la surface LECTURE ([ZMindmapView]) : graphe (défaut) ⇄ liste.
  final ZMindmapViewMode viewMode;

  /// Constructeur de contenu de nœud INJECTÉ, FORWARDÉ à [ZMindmapView] (AD-28 —
  /// slot opt-in du rich-text CÔTÉ APP ; défaut sûr texte brut si `null`).
  final ZMindmapNodeContentBuilder? nodeContentBuilder;

  /// Controller d'édition INJECTÉ (optionnel). `null` ⇒ la section en crée/possède
  /// un (disposé au `dispose`). Non-`null` ⇒ UTILISÉ tel quel, JAMAIS disposé.
  final ZMindmapOutlineController? outlineController;

  /// Configuration de layout structurel transmise aux widgets composés.
  final ZMindmapViewConfig viewConfig;

  /// Libellés a11y externalisés de l'éditeur outline (transmis tels quels).
  final ZMindmapOutlineLabels outlineLabels;

  /// Libellé externalisé de l'état vide de [ZMindmapView] (repli neutre si `null`).
  final String? emptyLabel;

  /// Émis (forêt mutée) au tap « enregistrer » de l'éditeur (transmis).
  final ZMindmapForestCallback? onSave;

  /// Émis à chaque modification de l'éditeur (mode auto-save ; transmis).
  final ZMindmapForestCallback? onChanged;

  /// Affiche le champ `content` (texte brut) dans l'éditeur (transmis).
  final bool editContentField;

  /// Hauteur bornée du viewport mindmap (contrainte requise ; surchargeable).
  final double viewportHeight;

  /// Libellé sémantique INJECTÉ de la bascule quand elle fait passer EN ÉDITION
  /// (annonce l'ACTION au lecteur d'écran, i18n — jamais un littéral métier dans
  /// le rendu). Sert aussi de `tooltip`.
  final String enterEditSemanticLabel;

  /// Libellé sémantique INJECTÉ de la bascule quand elle fait revenir EN LECTURE.
  final String enterReadSemanticLabel;

  /// Icône INJECTÉE de la bascule « passer en édition » (repli neutre documenté).
  final IconData? enterEditIcon;

  /// Icône INJECTÉE de la bascule « revenir en lecture » (repli neutre documenté).
  final IconData? enterReadIcon;

  /// Fabrique un [ZStudyToolsSectionSpec] rendant CETTE section comme UNE section
  /// (singleton) de `ZStudyToolsPage` (AD-4/AD-25) — RÉUTILISE le vocabulaire de
  /// sections d'ES-5, jamais une réimplémentation inline du layout.
  ///
  /// `itemCount` vaut TOUJOURS `1` (la mindmap = section singleton, non triée, non
  /// réordonnable) ; l'état vide d'une carte SANS nœud est porté par
  /// [ZMindmapView.emptyLabel], pas par `spec.emptyState`. [addAction] `null` =
  /// action d'ajout ABSENTE (AD-4 — jamais un no-op).
  static ZStudyToolsSectionSpec sectionSpec({
    required String id,
    required String title,
    required String folderId,
    required Widget emptyState,
    ZMindmap? mindmap,
    List<ZMindmapNode>? roots,
    ZStudyMindmapMode initialMode = ZStudyMindmapMode.read,
    ZMindmapViewMode viewMode = ZMindmapViewMode.graph,
    ZMindmapNodeContentBuilder? nodeContentBuilder,
    ZMindmapOutlineController? outlineController,
    ZMindmapViewConfig viewConfig = const ZMindmapViewConfig(),
    ZMindmapOutlineLabels outlineLabels = const ZMindmapOutlineLabels(),
    String? emptyLabel,
    ZMindmapForestCallback? onSave,
    ZMindmapForestCallback? onChanged,
    bool editContentField = true,
    double viewportHeight = _kDefaultViewportHeight,
    String enterEditSemanticLabel = 'Modifier la carte mentale',
    String enterReadSemanticLabel = 'Afficher la carte mentale',
    IconData? enterEditIcon,
    IconData? enterReadIcon,
    VoidCallback? addAction,
    IconData? addActionIcon,
    String? addActionSemanticLabel,
  }) {
    return ZStudyToolsSectionSpec(
      id: id,
      title: title,
      itemCount: 1,
      emptyState: emptyState,
      addAction: addAction,
      addActionIcon: addActionIcon,
      addActionSemanticLabel: addActionSemanticLabel,
      itemBuilder: (context, index) => ZStudyMindmapSection(
        folderId: folderId,
        mindmap: mindmap,
        roots: roots,
        initialMode: initialMode,
        viewMode: viewMode,
        nodeContentBuilder: nodeContentBuilder,
        outlineController: outlineController,
        viewConfig: viewConfig,
        outlineLabels: outlineLabels,
        emptyLabel: emptyLabel,
        onSave: onSave,
        onChanged: onChanged,
        editContentField: editContentField,
        viewportHeight: viewportHeight,
        enterEditSemanticLabel: enterEditSemanticLabel,
        enterReadSemanticLabel: enterReadSemanticLabel,
        enterEditIcon: enterEditIcon,
        enterReadIcon: enterReadIcon,
      ),
    );
  }

  @override
  State<ZStudyMindmapSection> createState() => _ZStudyMindmapSectionState();
}

class _ZStudyMindmapSectionState extends State<ZStudyMindmapSection> {
  /// Controller d'édition POSSÉDÉ (créé ici) — `null` si l'appelant en a injecté
  /// un. Miroir du patron owned/injected de `ZStudyToolsPage`.
  ZMindmapOutlineController? _owned;

  /// Controller effectif : injecté prioritaire, sinon le controller possédé.
  ZMindmapOutlineController get _controller =>
      widget.outlineController ?? _owned!;

  /// Mode COURANT de la section (lecture ⇄ édition), piloté LOCALEMENT (AD-2/AD-15).
  /// La mutation ne reconstruit QUE le [ValueListenableBuilder] du sous-arbre de
  /// la section — aucune propagation à la page ni aux autres sections (SM-1/AC4).
  late final ValueNotifier<ZStudyMindmapMode> _mode;

  /// Racines effectives (priorité à `mindmap`) — seed du controller possédé.
  List<ZMindmapNode> get _effectiveRoots =>
      widget.mindmap?.nodes ?? widget.roots ?? const <ZMindmapNode>[];

  @override
  void initState() {
    super.initState();
    _mode = ValueNotifier<ZStudyMindmapMode>(widget.initialMode);
    // Controller STABLE créé UNE fois (jamais dans build()) — AD-2. Seedé depuis
    // la forêt fournie ; source de vérité unique de l'édition ensuite.
    if (widget.outlineController == null) {
      _owned = ZMindmapOutlineController(initialForest: _effectiveRoots);
    }
  }

  @override
  void didUpdateWidget(covariant ZStudyMindmapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Transition possédé ↔ injecté (défensif ; jamais recréé pour un rebuild
    // ordinaire — seule une bascule de propriété reconstruit le controller).
    if (widget.outlineController != null && _owned != null) {
      // L'appelant fournit désormais son propre controller : libérer le nôtre.
      _owned!.dispose();
      _owned = null;
    } else if (widget.outlineController == null && _owned == null) {
      // L'appelant retire son controller : redevenir propriétaire (seed courant).
      _owned = ZMindmapOutlineController(initialForest: _effectiveRoots);
    }
  }

  @override
  void dispose() {
    // Ne disposer QUE le controller possédé (jamais un controller injecté).
    _owned?.dispose();
    _mode.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _mode.value = _mode.value == ZStudyMindmapMode.read
        ? ZStudyMindmapMode.edit
        : ZStudyMindmapMode.read;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // Clé NEUTRE dérivée du `folderId` (AD-4/AD-1) — identifie le sous-arbre de la
    // section, jamais par l'entité kernel. Deux `folderId` distincts ⇒ deux clés.
    return KeyedSubtree(
      key: ValueKey<String>('mindmap:${widget.folderId}'),
      // Bascule pilotée par le notifier LOCAL (AD-2/SM-1) : SEUL ce sous-arbre se
      // reconstruit — aucun `setState` page/section, aucun gestionnaire d'état.
      child: ValueListenableBuilder<ZStudyMindmapMode>(
        valueListenable: _mode,
        builder: (context, mode, _) {
          final isEdit = mode == ZStudyMindmapMode.edit;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildToggleChrome(context, theme, isEdit: isEdit),
              SizedBox(height: theme.gapS),
              // Contrainte de hauteur bornée requise (graphe graphite / ListView
              // interne de l'éditeur, tous deux imbriqués dans un ListView).
              SizedBox(
                height: widget.viewportHeight,
                child: isEdit ? _buildEditor(theme) : _buildView(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Surface LECTURE : composition de [ZMindmapView] (E10-2), zéro réimplémentation
  /// graphite. `nodeContentBuilder` FORWARDÉ tel quel (AD-28/AC6).
  Widget _buildView() {
    return ZMindmapView(
      mindmap: widget.mindmap,
      roots: widget.roots,
      mode: widget.viewMode,
      nodeContentBuilder: widget.nodeContentBuilder,
      config: widget.viewConfig,
      emptyLabel: widget.emptyLabel,
    );
  }

  /// Surface ÉDITION : composition de [ZMindmapOutlineEditor] (E10-3) sur le
  /// controller DÉTENU par la section (possédé OU injecté). AUCUN
  /// `ListenableBuilder(listenable: controller)` enveloppant global (SM-1).
  Widget _buildEditor(ZcrudTheme theme) {
    return ZMindmapOutlineEditor(
      controller: _controller,
      labels: widget.outlineLabels,
      config: widget.viewConfig,
      onSave: widget.onSave,
      onChanged: widget.onChanged,
      editContentField: widget.editContentField,
      padding: EdgeInsetsDirectional.only(top: theme.gapS),
    );
  }

  /// Chrome de bascule lecture ⇄ édition : cible ≥ 48 dp, `Semantics` label
  /// INJECTÉ (= `tooltip`), padding directionnel, icône INJECTÉE (repli neutre),
  /// couleurs du thème injecté (aucune couleur/label codé en dur — AD-13/FR-26).
  Widget _buildToggleChrome(
    BuildContext context,
    ZcrudTheme theme, {
    required bool isEdit,
  }) {
    // Le label décrit l'ACTION à venir : en lecture → « passer en édition » ; en
    // édition → « revenir en lecture » (INJECTÉ, jamais un littéral dans le rendu).
    final semanticLabel =
        isEdit ? widget.enterReadSemanticLabel : widget.enterEditSemanticLabel;
    final icon = isEdit
        ? (widget.enterReadIcon ?? _kEnterReadFallbackIcon)
        : (widget.enterEditIcon ?? _kEnterEditFallbackIcon);
    final iconColor =
        theme.labelColor ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: theme.gapS),
      child: Row(
        children: <Widget>[
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _kMinTapTarget,
              minHeight: _kMinTapTarget,
            ),
            child: IconButton(
              onPressed: _toggleMode,
              tooltip: semanticLabel,
              icon: Icon(icon, color: iconColor, semanticLabel: semanticLabel),
            ),
          ),
        ],
      ),
    );
  }
}
