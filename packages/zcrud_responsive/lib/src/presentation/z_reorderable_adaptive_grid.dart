import 'dart:async';

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';

import 'z_adaptive_grid.dart';

/// Fraction d'opacité de la cellule laissée en place pendant qu'on la glisse.
const double _kDraggingOpacity = 0.3;

/// Fraction d'opacité de l'aperçu qui suit le doigt/curseur.
const double _kFeedbackOpacity = 0.9;

/// Réduction d'échelle de la cellule SURVOLÉE (cible de dépôt candidate).
/// Affordance PUREMENT géométrique — aucune couleur codée en dur (FR-26/AD-13).
const double _kCandidateScale = 0.94;

/// Grille **adaptative RÉORDONNABLE** — multi-colonnes ET drag-and-drop, sans
/// aucun paquet tiers (CR-IFFD-15, voie A/C).
///
/// ## Pourquoi une primitive maison (AD-1)
///
/// `ReorderableListView` (SDK) ne dispose **pas** en grille, et
/// `reorderable_grid_view` (paquet tiers) est **refusé par AD-1**. Cette grille
/// est donc bâtie **uniquement** sur le SDK : [LongPressDraggable] +
/// [DragTarget] pour le geste, [Scrollable] pour l'autoscroll.
///
/// ## Ce qu'elle NE réimplémente PAS
///
/// Le nombre de colonnes, la gouttière, la largeur d'item, le ratio et les replis
/// AD-10 sont **délégués à [ZAdaptiveGrid]** (elle-même bâtie sur
/// `computeCrossAxisCount`). Il n'existe **aucun second calcul de colonnes** dans
/// ce fichier : cette grille est [ZAdaptiveGrid] **plus** une couche de geste.
///
/// ## Modèle d'ordre : LINÉAIRE, la grille n'est qu'une projection
///
/// L'ordre est une permutation linéaire `0..n-1` de [itemIds] ; la disposition en
/// `n` colonnes n'en est qu'une **projection**. Déposer sur la cellule de
/// position `k` signifie donc « **index `k`** », **quelle que soit la ligne** —
/// le déplacement franchit librement les lignes. La transformation appliquée est
/// exactement `removeAt(oldIndex)` puis `insert(newIndex)` : la **même
/// convention** que `onReorderItem` du SDK et que `zReorderIds` côté
/// `zcrud_study` (symétrie hôte/primitive). Cette convention est ré-implémentée
/// ici en privé ([_moveId]) car `zcrud_study` **ne peut pas** être une dépendance
/// de `zcrud_responsive` (AD-1 : l'arête irait dans le mauvais sens) — la
/// duplication est de **7 lignes**, imposée par la frontière de paquets, et
/// verrouillée par un test de symétrie.
///
/// ## Geste + alternative accessible (AD-13)
///
/// * **Appui long** sur la cellule ENTIÈRE (pas de poignée : les cartes d'items
///   sont déjà denses) ;
/// * **Alternative obligatoire au lecteur d'écran** : un appui long n'est pas
///   atteignable en navigation assistée, donc chaque cellule expose deux
///   **actions sémantiques** ([CustomSemanticsAction]) « déplacer avant » /
///   « déplacer après », dont les libellés sont **INJECTÉS**
///   ([moveBeforeSemanticLabel]/[moveAfterSemanticLabel]) — jamais codés en dur.
///   La première cellule n'expose pas « avant », la dernière pas « après ».
///
/// ## Autoscroll vertical
///
/// Pendant le glissement, quand le pointeur approche à moins de
/// [autoScrollEdgeExtent] d'un bord vertical du [Scrollable] englobant, la vue
/// défile de [autoScrollStep] par frame, **bornée** par
/// `min/maxScrollExtent`. Sans `Scrollable` vertical englobant, l'autoscroll est
/// simplement inactif (jamais de throw — AD-10).
///
/// ## SM-1 / AD-2 — ordre optimiste LOCAL
///
/// L'ordre optimiste vit dans un `ValueNotifier` **local** à cette grille et
/// n'est consommé que par un [ValueListenableBuilder] : réordonner ne
/// reconstruit **ni** le parent **ni** la page. Aucun gestionnaire d'état.
/// L'ordre est resynchronisé sur [itemIds] dans `didUpdateWidget` dès que
/// l'hôte repousse un ordre persisté.
///
/// ## AD-10 — repli si [onReorder] échoue
///
/// Si [onReorder] lève **de façon synchrone**, l'ordre affiché est **restauré**
/// à l'identique et l'exception est **absorbée** (jamais de crash de rendu,
/// jamais d'état incohérent). ⚠️ Un échec **asynchrone** (persistance) est hors
/// de portée d'un callback `void` : l'hôte le signale en repoussant l'ancien
/// [itemIds], ce qui resynchronise la grille par `didUpdateWidget`.
///
/// ## Non combiné avec la virtualisation
///
/// Cette grille est **eager** (comme le ctor historique de [ZAdaptiveGrid]) :
/// une cellule non construite ne peut pas être une cible de dépôt. Réordonner et
/// virtualiser sont donc exclusifs — documenté, jamais dégradé en silence.
class ZReorderableAdaptiveGrid extends StatefulWidget {
  /// Construit une grille adaptative réordonnable.
  const ZReorderableAdaptiveGrid({
    required this.itemIds,
    required this.itemBuilder,
    required this.onReorder,
    required this.minItemWidth,
    required this.moveBeforeSemanticLabel,
    required this.moveAfterSemanticLabel,
    this.spacing = 8.0,
    this.runSpacing,
    this.itemHeight,
    this.aspectRatio,
    this.minColumns = 1,
    this.maxColumns,
    this.padding,
    this.autoScrollEdgeExtent = 64.0,
    this.autoScrollStep = 24.0,
    super.key,
  });

  /// Ordre COURANT des ids d'items (clés STABLES). `itemIds[i]` identifie l'item
  /// rendu par `itemBuilder(context, i)`. Vide ⇒ `SizedBox.shrink()` (AD-10).
  final List<String> itemIds;

  /// Construit l'item d'**index SOURCE** (index dans [itemIds], jamais la
  /// position visuelle courante) : l'ordre optimiste local peut avoir permuté
  /// l'affichage sans que l'hôte ait encore repoussé un nouvel [itemIds].
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Notifié après un dépôt, en convention `removeAt(oldIndex)` /
  /// `insert(newIndex)` — **indices linéaires**, jamais des coordonnées de
  /// grille. Peut lever : l'ordre affiché est alors restauré (AD-10).
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Largeur minimale d'un item (dp) — pilote le nombre de colonnes via
  /// [ZAdaptiveGrid] / `computeCrossAxisCount`.
  final double minItemWidth;

  /// Libellé LOCALISÉ de l'action sémantique « déplacer avant » (AD-13).
  final String moveBeforeSemanticLabel;

  /// Libellé LOCALISÉ de l'action sémantique « déplacer après » (AD-13).
  final String moveAfterSemanticLabel;

  /// Espacement inter-colonnes (dp), défaut de l'inter-lignes si [runSpacing]
  /// est `null`.
  final double spacing;

  /// Espacement inter-lignes (dp). `null` → reprend [spacing].
  final double? runSpacing;

  /// Hauteur cible d'une cellule (dp). Prime sur [aspectRatio].
  final double? itemHeight;

  /// Ratio largeur/hauteur d'une cellule. Ignoré si [itemHeight] est fourni.
  final double? aspectRatio;

  /// Plancher de colonnes (remonté à 1 si `< 1`, AD-10).
  final int minColumns;

  /// Plafond de colonnes. `null` → illimité.
  final int? maxColumns;

  /// Marge interne — `EdgeInsetsGeometry?` (accepte `EdgeInsetsDirectional`).
  final EdgeInsetsGeometry? padding;

  /// Distance (dp) à un bord vertical du `Scrollable` englobant en deçà de
  /// laquelle l'autoscroll s'enclenche pendant le glissement.
  final double autoScrollEdgeExtent;

  /// Pas de défilement (dp) appliqué par frame pendant l'autoscroll.
  final double autoScrollStep;

  @override
  State<ZReorderableAdaptiveGrid> createState() =>
      _ZReorderableAdaptiveGridState();
}

class _ZReorderableAdaptiveGridState extends State<ZReorderableAdaptiveGrid> {
  /// Ordre OPTIMISTE local (permutation de `widget.itemIds`). `ValueNotifier`
  /// et non `setState` : le rebuild reste confiné au [ValueListenableBuilder]
  /// de cette grille (SM-1/AD-2).
  late final ValueNotifier<List<String>> _order;

  /// Minuterie d'autoscroll (active UNIQUEMENT pendant un glissement de bord).
  Timer? _autoScrollTimer;

  /// Pas signé courant de l'autoscroll (dp/frame ; `< 0` = vers le haut).
  double _autoScrollDelta = 0;

  @override
  void initState() {
    super.initState();
    _order = ValueNotifier<List<String>>(List<String>.of(widget.itemIds));
  }

  @override
  void didUpdateWidget(covariant ZReorderableAdaptiveGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'hôte a persisté puis repoussé un ordre (ou les items ont changé) :
    // réaligner l'ordre local sur la source de vérité. Si l'hôte ne repousse
    // rien, l'ordre optimiste local est PRÉSERVÉ (retour visuel immédiat).
    if (!_listEquals(widget.itemIds, oldWidget.itemIds)) {
      _order.value = List<String>.of(widget.itemIds);
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _order.dispose();
    super.dispose();
  }

  /// Applique un déplacement LINÉAIRE `from → to` (convention removeAt/insert),
  /// notifie l'hôte, et RESTAURE l'ordre affiché si l'hôte lève (AD-10).
  void _move(int from, int to) {
    final previous = _order.value;
    final next = _moveId(previous, from, to);
    if (_listEquals(previous, next)) return;
    _order.value = next;
    try {
      widget.onReorder(from, to);
    } catch (_) {
      // AD-10 : jamais d'état incohérent — l'affichage revient à l'ordre
      // d'avant le dépôt. L'exception est ABSORBÉE par conception (une grille
      // ne doit pas casser le rendu de la page parce qu'une persistance a
      // échoué) ; c'est à l'hôte de remonter son erreur dans `onReorder`.
      _order.value = previous;
    }
  }

  // ── Autoscroll (SDK pur : `Scrollable.maybeOf` + `ScrollPosition.jumpTo`) ──

  void _handleDragUpdate(DragUpdateDetails details) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null || scrollable.position.axis != Axis.vertical) {
      _stopAutoScroll();
      return;
    }
    final renderObject = scrollable.context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _stopAutoScroll();
      return;
    }
    final double top = renderObject.localToGlobal(Offset.zero).dy;
    final double bottom = top + renderObject.size.height;
    final double y = details.globalPosition.dy;
    final double edge = widget.autoScrollEdgeExtent;

    double delta = 0;
    if (y < top + edge) {
      delta = -widget.autoScrollStep;
    } else if (y > bottom - edge) {
      delta = widget.autoScrollStep;
    }
    if (delta == 0) {
      _stopAutoScroll();
      return;
    }
    _autoScrollDelta = delta;
    // Une seule minuterie, réutilisée tant que le pointeur reste au bord.
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _stepAutoScroll(),
    );
  }

  void _stepAutoScroll() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) {
      _stopAutoScroll();
      return;
    }
    final position = scrollable.position;
    final double target = (position.pixels + _autoScrollDelta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) {
      // Butée atteinte : inutile de continuer à battre.
      _stopAutoScroll();
      return;
    }
    position.jumpTo(target);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollDelta = 0;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: _order,
      builder: (context, ids, _) {
        // Garde vide AD-10 (ZAdaptiveGrid la porte aussi ; on évite en plus de
        // construire des cellules pour rien).
        if (ids.isEmpty) return const SizedBox.shrink();
        return ZAdaptiveGrid(
          minItemWidth: widget.minItemWidth,
          spacing: widget.spacing,
          runSpacing: widget.runSpacing,
          itemHeight: widget.itemHeight,
          aspectRatio: widget.aspectRatio,
          minColumns: widget.minColumns,
          maxColumns: widget.maxColumns,
          padding: widget.padding,
          children: <Widget>[
            for (var position = 0; position < ids.length; position++)
              _cell(context, ids, position),
          ],
        );
      },
    );
  }

  Widget _cell(BuildContext context, List<String> ids, int position) {
    final String id = ids[position];
    // Index SOURCE : l'ordre local a pu permuter l'affichage sans que l'hôte
    // ait repoussé un nouvel `itemIds` (même mapping que le mode liste).
    final int sourceIndex = widget.itemIds.indexOf(id);
    return _ZReorderableCell(
      // Clé STABLE = id opaque, jamais la position (sinon l'état des cellules
      // suivrait la case et non l'item).
      key: ValueKey<String>(id),
      position: position,
      lastPosition: ids.length - 1,
      moveBeforeSemanticLabel: widget.moveBeforeSemanticLabel,
      moveAfterSemanticLabel: widget.moveAfterSemanticLabel,
      onMove: _move,
      onDragUpdate: _handleDragUpdate,
      onDragStopped: _stopAutoScroll,
      child: widget.itemBuilder(context, sourceIndex < 0 ? position : sourceIndex),
    );
  }
}

/// Une cellule réordonnable : appui long pour glisser, cible de dépôt, et deux
/// actions sémantiques (alternative a11y obligatoire à l'appui long, AD-13).
class _ZReorderableCell extends StatelessWidget {
  const _ZReorderableCell({
    required this.position,
    required this.lastPosition,
    required this.moveBeforeSemanticLabel,
    required this.moveAfterSemanticLabel,
    required this.onMove,
    required this.onDragUpdate,
    required this.onDragStopped,
    required this.child,
    super.key,
  });

  final int position;
  final int lastPosition;
  final String moveBeforeSemanticLabel;
  final String moveAfterSemanticLabel;
  final void Function(int from, int to) onMove;
  final void Function(DragUpdateDetails details) onDragUpdate;
  final VoidCallback onDragStopped;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Actions sémantiques : le lecteur d'écran ne peut pas faire d'appui long,
    // donc le déplacement DOIT être atteignable autrement (AD-13). Libellés
    // INJECTÉS (jamais de littéral ici — FR-26).
    final semanticChild = Semantics(
      container: true,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (position > 0)
          CustomSemanticsAction(label: moveBeforeSemanticLabel): () =>
              onMove(position, position - 1),
        if (position < lastPosition)
          CustomSemanticsAction(label: moveAfterSemanticLabel): () =>
              onMove(position, position + 1),
      },
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return DragTarget<int>(
          // Une cellule n'est jamais sa propre cible.
          onWillAcceptWithDetails: (details) => details.data != position,
          // Dépôt sur la position `position` ⇒ index LINÉAIRE `position`,
          // quelle que soit la ligne d'origine (inter-lignes, CR-IFFD-15).
          onAcceptWithDetails: (details) => onMove(details.data, position),
          builder: (context, candidateData, rejectedData) {
            final bool isCandidate = candidateData.isNotEmpty;
            return LongPressDraggable<int>(
              data: position,
              onDragUpdate: onDragUpdate,
              onDragEnd: (_) => onDragStopped(),
              onDraggableCanceled: (_, _) => onDragStopped(),
              onDragCompleted: onDragStopped,
              // Aperçu à la TAILLE RÉELLE de la cellule (mesurée localement) :
              // un aperçu non contraint prendrait une taille intrinsèque et
              // sauterait visuellement.
              feedback: SizedBox(
                width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
                height:
                    constraints.maxHeight.isFinite ? constraints.maxHeight : null,
                child: Opacity(opacity: _kFeedbackOpacity, child: child),
              ),
              childWhenDragging:
                  Opacity(opacity: _kDraggingOpacity, child: semanticChild),
              child: isCandidate
                  // Affordance de survol PUREMENT géométrique et RTL-neutre :
                  // aucune couleur codée en dur (FR-26/AD-13).
                  ? Transform.scale(
                      scale: _kCandidateScale,
                      alignment: AlignmentDirectional.center
                          .resolve(Directionality.of(context)),
                      child: semanticChild,
                    )
                  : semanticChild,
            );
          },
        );
      },
    );
  }
}

/// Déplacement LINÉAIRE pur : `removeAt(from)` puis `insert(to)`. Total (indices
/// clampés, jamais de throw — AD-10), ne mute pas [ids].
///
/// Même convention que `onReorderItem` (SDK) et `zReorderIds` (`zcrud_study`) —
/// duplication imposée par la frontière de paquets (AD-1 : `zcrud_responsive`
/// ne peut pas dépendre de `zcrud_study`).
List<String> _moveId(List<String> ids, int from, int to) {
  final list = List<String>.of(ids);
  if (list.isEmpty) return list;
  final int source = from.clamp(0, list.length - 1);
  final String moved = list.removeAt(source);
  final int target = to.clamp(0, list.length);
  list.insert(target, moved);
  return list;
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
