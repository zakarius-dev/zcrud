/// `ZSectionedStudyLayout` — échafaudage de composition qui rend une
/// `List<ZStudyToolsSectionSpec>` comme une **liste de sections INDÉPENDANTES**
/// (AD-25). Matérialise la décomposition du monolithe IFFD
/// `folder_study_tools_page.dart` (~1753 l., `build` unique 350→~1739) : chaque
/// section obtient sa PROPRE frontière de widget (`ValueKey('section:$id')`) —
/// pré-requis du rebuild ciblé SM-1 (ES-5.2) et de la réordonnabilité (ES-5.3).
///
/// Invariants (AD-2/AD-13/AD-15) : AUCUN gestionnaire d'état (réactivité
/// Flutter-native pure) ; directionnel (`EdgeInsetsDirectional`/
/// `AlignmentDirectional`/`TextAlign.start`) ; `Semantics` explicites ; cibles
/// interactives ≥ 48 dp ; thème injecté via `ZcrudTheme.of` (`ZcrudScope` →
/// `Theme.of` repli, aucune couleur codée en dur) ; `ListView.builder`.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_responsive/zcrud_responsive.dart' show ZAdaptiveGrid;

import 'z_reorder_ids.dart';
import 'z_study_tools_section_spec.dart';

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Glyphe « add » de REPLI, appliqué UNIQUEMENT quand l'appelant n'injecte pas
/// `addActionIcon`. Ce n'est PAS un hardcode inconditionnel (solde DW-ES51-1
/// MEDIUM-1) : dès qu'une icône est injectée, elle prime ([_ZStudySection]). Le
/// glyphe conventionnel « + » est le défaut neutre justifié d'une action d'ajout.
const IconData _kAddActionFallbackIcon = Icons.add;

/// Glyphe de poignée de drag de REPLI (défaut neutre conventionnel documenté,
/// même patron justifié que [_kAddActionFallbackIcon]). La sémantique (label
/// a11y) reste, elle, TOUJOURS injectée (`reorderHandleSemanticLabel`, i18n) :
/// aucun libellé n'est jamais codé en dur (AD-13/FR-26).
const IconData _kDragHandleFallbackIcon = Icons.drag_handle;

/// Rend une liste de sections « study tools » décomposée.
///
/// Chaque entrée de [sections] devient un sous-arbre `_ZStudySection` distinct,
/// keyé par `ValueKey('section:$id')`, assemblé par un `ListView.builder`
/// (jamais `ListView(children:)`). L'ordre visuel vertical SUIT l'ordre de
/// [sections] — aucun tri implicite (pré-requis ES-5.3).
class ZSectionedStudyLayout extends StatelessWidget {
  /// Construit le layout à partir des descripteurs de section (ordre préservé).
  const ZSectionedStudyLayout({required this.sections, super.key});

  /// Descripteurs de section, dans l'ordre visuel vertical voulu.
  final List<ZStudyToolsSectionSpec> sections;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // Pas de tri : l'ordre d'entrée EST l'ordre de rendu (AC3, ES-5.3).
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final spec = sections[index];
        return _ZStudySection(
          // Frontière de widget STABLE par section — décomposition comptable
          // (AC5) et frontière rebuild (SM-1/ES-5.2).
          key: ValueKey('section:${spec.id}'),
          spec: spec,
        );
      },
    );
  }
}

/// Sous-arbre isolé d'UNE section. `StatelessWidget` (aucun état local) — la
/// réactivité par champ sera branchée en ES-5.2 via `ValueListenable` sans
/// casser cette frontière.
class _ZStudySection extends StatelessWidget {
  const _ZStudySection({required this.spec, super.key});

  final ZStudyToolsSectionSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final isEmpty = spec.itemCount == 0;

    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.gapM,
        vertical: theme.gapS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, theme),
          // CR-IFFD-10 §1 — le corps est masqué quand la section est repliée.
          // L'état vit LOCALEMENT (`_CollapsibleBody`, sous la frontière keyée
          // de la section) : replier ne reconstruit NI les autres sections NI la
          // page (SM-1/AD-2).
          if (spec.collapsible)
            _CollapsibleBody(
              spec: spec,
              theme: theme,
              body: _body(context, theme, isEmpty),
            )
          else ...[
            SizedBox(height: theme.gapS),
            _body(context, theme, isEmpty),
          ],
        ],
      ),
    );
  }

  /// Corps de la section : `emptyState` si vide, items sinon (jamais l'inverse,
  /// AC3). Extrait pour être partagé entre le rendu direct et le rendu repliable.
  Widget _body(BuildContext context, ZcrudTheme theme, bool isEmpty) => isEmpty
      ? Semantics(container: true, label: spec.title, child: spec.emptyState)
      : _buildItems(context, theme);

  /// Items de la section selon [ZStudyToolsSectionSpec.axis] :
  /// - [Axis.vertical] réordonnable ([onReorder] non-null) → grille
  ///   `ReorderableListView` (ES-5.3, sous-arbre local isolé) ;
  /// - [Axis.vertical] (défaut) → empilement (grille) ;
  /// - [Axis.horizontal] → **rail** défilant horizontalement (flashcards).
  Widget _buildItems(BuildContext context, ZcrudTheme theme) {
    // ES-5.3 — réordonnabilité UNIQUEMENT sur les grilles verticales. `null` =
    // capacité absente (AD-4) ⇒ rendu ES-5.2 inchangé (non-régression).
    if (spec.axis == Axis.vertical && spec.onReorder != null) {
      return _ReorderableItemList(spec: spec, theme: theme);
    }
    if (spec.axis == Axis.horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < spec.itemCount; i++)
              Padding(
                padding: EdgeInsetsDirectional.only(end: theme.gapS),
                child: spec.itemBuilder(context, i),
              ),
          ],
        ),
      );
    }
    // CR-IFFD-10 §2 — grille MULTI-COLONNES via `ZAdaptiveGrid` (zcrud_responsive),
    // DÉJÀ dépendu par ce package et déjà utilisé par `z_flashcard_list_view` /
    // `z_multi_flashcard_editor`. On NE réimplémente PAS le calcul de colonnes :
    // `computeCrossAxisCount` gère déjà gouttière, padding, plancher/plafond et
    // les replis AD-10 (NaN/infini/négatif). `null` ⇒ une colonne (rendu antérieur).
    final minWidth = spec.crossAxisMinItemWidth;
    if (minWidth != null && minWidth > 0) {
      return ZAdaptiveGrid(
        minItemWidth: minWidth,
        spacing: theme.gapS,
        children: <Widget>[
          for (var i = 0; i < spec.itemCount; i++) spec.itemBuilder(context, i),
        ],
      );
    }
    return _singleColumn(context, theme);
  }

  /// Empilement mono-colonne — rendu historique, préservé à l'identique.
  Widget _singleColumn(BuildContext context, ZcrudTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < spec.itemCount; i++)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
            child: spec.itemBuilder(context, i),
          ),
      ],
    );
  }

  /// En-tête : titre + badge compteur + (optionnel) action d'ajout ≥ 48 dp.
  Widget _buildHeader(BuildContext context, ZcrudTheme theme) {
    final addAction = spec.addAction;
    return Semantics(
      header: true,
      child: Row(
        children: [
          Expanded(
            child: Text(
              spec.title,
              textAlign: TextAlign.start,
              style: theme.labelTextStyle ??
                  Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SizedBox(width: theme.gapS),
          _CountBadge(count: spec.headerCount ?? spec.itemCount, theme: theme),
          // CR-IFFD-10 §3 — action secondaire (ex. « Afficher tout »), rendue
          // AVANT l'ajout : consultation avant création. `null` ⇒ ABSENTE (AD-4).
          if (spec.secondaryAction != null) ...[
            SizedBox(width: theme.gapS),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: IconButton(
                key: ValueKey<String>('section:${spec.id}:secondaryAction'),
                onPressed: spec.secondaryAction,
                tooltip: spec.secondaryActionSemanticLabel ?? spec.title,
                icon: Icon(
                  spec.secondaryActionIcon ?? Icons.arrow_forward,
                  semanticLabel:
                      spec.secondaryActionSemanticLabel ?? spec.title,
                ),
              ),
            ),
          ],
          // Callback `null` = action ABSENTE (AD-4) : aucun bouton rendu.
          if (addAction != null) ...[
            SizedBox(width: theme.gapS),
            // Solde DW-ES51-1 MEDIUM-1 + LOW-2 : UNE seule source de sémantique
            // de bouton — le label INJECTÉ (qui prime sur `spec.title`) porté
            // par `Icon.semanticLabel` et fusionné dans le nœud bouton de
            // l'`IconButton` ; plus de `Semantics(button:true)` enveloppant
            // redondant. Icône INJECTÉE (repli neutre documenté). Le `tooltip`
            // rend le MÊME label visible au survol (desktop) sans dupliquer le
            // nœud bouton.
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: IconButton(
                onPressed: addAction,
                tooltip: spec.addActionSemanticLabel ?? spec.title,
                icon: Icon(
                  spec.addActionIcon ?? _kAddActionFallbackIcon,
                  semanticLabel: spec.addActionSemanticLabel ?? spec.title,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Liste d'items RÉORDONNABLE d'une section (ES-5.3) — sous-arbre LOCAL isolé.
///
/// `StatefulWidget` **délibéré** (SM-1/AD-2) : l'ordre optimiste vit ICI, sous la
/// frontière keyée `ValueKey('section:$id')` — réordonner ne déclenche donc
/// AUCUN `setState` au niveau page/section et ne reconstruit NI les autres
/// sections NI la page (invariant AC2). Le rendu se fait via
/// `ReorderableListView.builder` du **SDK Flutter** (jamais le paquet tiers
/// `reorderable_grid_view` — AD-1), `shrinkWrap: true` +
/// `NeverScrollableScrollPhysics` (imbriqué dans le `ListView.builder` du
/// layout), enfants keyés `ValueKey(id)` (clé STABLE requise), poignée
/// directionnelle a11y ≥ 48 dp.
class _ReorderableItemList extends StatefulWidget {
  const _ReorderableItemList({required this.spec, required this.theme});

  final ZStudyToolsSectionSpec spec;
  final ZcrudTheme theme;

  @override
  State<_ReorderableItemList> createState() => _ReorderableItemListState();
}

class _ReorderableItemListState extends State<_ReorderableItemList> {
  /// Ordre OPTIMISTE local des ids (permutation de `spec.itemIds`), porté par un
  /// `ValueNotifier` — réactivité Flutter-native pure (AD-2/AD-15, **aucun
  /// `setState`** : le rebuild est confiné au seul [ValueListenableBuilder] du
  /// sous-arbre de la section, jamais propagé à la page ni aux autres sections —
  /// invariant SM-1/AC2). Muté au drop pour un retour visuel immédiat, puis
  /// persisté par l'appelant via `spec.onReorder` (AD-26). Resynchronisé si
  /// l'appelant repousse un nouvel ordre persisté (didUpdateWidget).
  late final ValueNotifier<List<String>> _ids;

  @override
  void initState() {
    super.initState();
    _ids = ValueNotifier<List<String>>(List<String>.of(widget.spec.itemIds!));
  }

  @override
  void didUpdateWidget(covariant _ReorderableItemList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'appelant a persisté puis repoussé un nouvel ordre (ou la section a
    // changé d'items) : réaligner l'ordre local sur la source de vérité.
    if (!_listEquals(widget.spec.itemIds!, oldWidget.spec.itemIds!)) {
      _ids.value = List<String>.of(widget.spec.itemIds!);
    }
  }

  @override
  void dispose() {
    _ids.dispose();
    super.dispose();
  }

  void _handleReorder(int oldIndex, int newIndex) {
    // `onReorderItem` (SDK ≥ v3.41) fournit un `newIndex` DÉJÀ ajusté pour le
    // retrait de l'item à `oldIndex` — c.-à-d. déjà en convention
    // `removeAt(oldIndex)`/`insert(newIndex)` (aucun `-1` manuel à appliquer).
    // Mutation de la tranche ⇒ rebuild ciblé du seul ValueListenableBuilder.
    _ids.value = zReorderIds(_ids.value, oldIndex, newIndex);
    // Notifie l'appelant (persistance ZFolderContentsOrder, AD-26) avec les
    // MÊMES indices normalisés que ceux appliqués localement (symétrie).
    widget.spec.onReorder!(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final theme = widget.theme;
    return ValueListenableBuilder<List<String>>(
      valueListenable: _ids,
      builder: (context, ids, _) => ReorderableListView.builder(
        // Imbriqué dans le ListView.builder du layout (GOTCHA R14).
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // Poignée FOURNIE (directionnelle + a11y ≥ 48 dp) plutôt que la poignée
        // par défaut du SDK (non directionnelle, sans label injecté).
        buildDefaultDragHandles: false,
        itemCount: ids.length,
        // `onReorderItem` (remplace `onReorder`, obsolète) : `newIndex` ajusté.
        onReorderItem: _handleReorder,
        itemBuilder: (context, index) {
          final id = ids[index];
          // Index d'origine (côté appelant) de l'item courant : `itemBuilder`
          // rend par l'index de `spec.itemIds`, or l'ordre local a pu permuter.
          final originalIndex = spec.itemIds!.indexOf(id);
          return _ReorderableItemRow(
            // Clé STABLE requise par ReorderableListView (« every item must have
            // a key ») — l'id opaque de l'item, jamais l'index.
            key: ValueKey(id),
            index: index,
            handleSemanticLabel: spec.reorderHandleSemanticLabel ?? spec.title,
            theme: theme,
            child: spec.itemBuilder(
                context, originalIndex < 0 ? index : originalIndex),
          );
        },
      ),
    );
  }
}

/// Une ligne réordonnable : l'item de l'appelant + une poignée de drag
/// DIRECTIONNELLE, a11y (`Semantics` label INJECTÉ) et cible ≥ 48 dp.
class _ReorderableItemRow extends StatelessWidget {
  const _ReorderableItemRow({
    required this.index,
    required this.handleSemanticLabel,
    required this.theme,
    required this.child,
    super.key,
  });

  final int index;
  final String handleSemanticLabel;
  final ZcrudTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: child),
          SizedBox(width: theme.gapS),
          // Poignée : label a11y INJECTÉ, cible ≥ 48 dp, déclencheur de drag SDK.
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              container: true,
              label: handleSemanticLabel,
              button: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: _kMinTapTarget,
                  minHeight: _kMinTapTarget,
                ),
                // Le glyphe est décoratif ; l'annonce a11y vient du Semantics
                // parent (label INJECTÉ) — pas de label sur l'icône.
                child: const Icon(_kDragHandleFallbackIcon),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Comparaison positionnelle de deux listes d'ids (ordre-sensible).
bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Badge de compteur d'items (chrome thémé, aucune couleur codée en dur).
///
/// Solde DW-ES51-1 LOW-1/LOW-2 : rayon/paddings tirés des tokens
/// [ZcrudTheme.radiusM]/[ZcrudTheme.gapS]/[ZcrudTheme.gapM] (plus de
/// `circular(10)`/`8`/`2` en dur) ; `Semantics(label:)` redondant supprimé (le
/// `Text('$count')` porte déjà l'annonce — une seule source de sémantique).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.theme});

  final int count;
  final ZcrudTheme theme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.gapM,
        vertical: theme.gapS,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.all(theme.radiusM),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.start,
        style: TextStyle(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

/// Corps repliable d'une section (CR-IFFD-10 §1) — **état LOCAL délibéré**.
///
/// `StatefulWidget` sous la frontière keyée `ValueKey('section:$id')` : basculer
/// le repli ne déclenche AUCUN `setState` au niveau page/section et ne
/// reconstruit NI les autres sections NI la page (SM-1/AD-2), exactement comme
/// l'ordre optimiste de `_ReorderableItems`.
class _CollapsibleBody extends StatefulWidget {
  const _CollapsibleBody({
    required this.spec,
    required this.theme,
    required this.body,
  });

  final ZStudyToolsSectionSpec spec;
  final ZcrudTheme theme;
  final Widget body;

  @override
  State<_CollapsibleBody> createState() => _CollapsibleBodyState();
}

class _CollapsibleBodyState extends State<_CollapsibleBody> {
  late bool _expanded = widget.spec.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final label = _expanded ? 'Replier' : 'Déplier';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _kMinTapTarget,
              minHeight: _kMinTapTarget,
            ),
            child: IconButton(
              key: ValueKey<String>('section:${widget.spec.id}:collapse'),
              onPressed: () => setState(() => _expanded = !_expanded),
              tooltip: label,
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                semanticLabel: '$label ${widget.spec.title}',
              ),
            ),
          ),
        ),
        if (_expanded) ...<Widget>[
          SizedBox(height: widget.theme.gapS),
          widget.body,
        ],
      ],
    );
  }
}
