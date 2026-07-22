/// Implémentation **opt-in** du port `ZReorderRenderer` adossée au paquet
/// `reorderable_grid_view` de l'écosystème pub.dev (AD-57).
///
/// **Le tiers est CONFINÉ à ce fichier.** Aucun type de `reorderable_grid_view`
/// n'apparaît dans une signature publique de ce paquet : l'hôte ne manipule que
/// `ZReorderRenderer` / `ZReorderRenderRequest` (types `zcrud_core`) et, au plus,
/// le constructeur ci-dessous. C'est la condition 2 d'AD-57.
///
/// **Le repli reste garanti** : un consommateur qui n'installe pas
/// `zcrud_reorder` garde `ZDefaultReorderRenderer` (`zcrud_responsive`,
/// zéro-dépendance). Les deux sont **interchangeables** — même convention
/// d'index, même voie accessible, même repli AD-10 — et un test le prouve.
library;

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart' show computeCrossAxisCount;

import 'package_reorder_index.dart';

/// Repli LOCALISÉ du libellé « déplacer avant » quand l'hôte n'en fournit pas.
///
/// Une action sémantique sans libellé est **inutilisable** au lecteur d'écran :
/// mieux vaut un défaut que rien (AD-13). Identique au repli du renderer par
/// défaut — l'interchangeabilité vaut aussi pour l'a11y.
const String kDefaultMoveBeforeLabel = 'Déplacer avant';

/// Repli LOCALISÉ du libellé « déplacer après ». Cf. [kDefaultMoveBeforeLabel].
const String kDefaultMoveAfterLabel = 'Déplacer après';

/// Renderer réordonnable adossé à `reorderable_grid_view`.
///
/// Injecté via `ZcrudScope.reorderRenderer` :
///
/// ```dart
/// ZcrudScope(
///   reorderRenderer: const ZPackageReorderRenderer(),
///   child: ...,
/// )
/// ```
///
/// Tient les **quatre points** du contrat du port :
/// 1. **index LINÉAIRES** — le couple brut du paquet est normalisé par
///    `normalizePackageReorder` (le paquet fournit un index déjà ajusté ; on se
///    garde d'appliquer l'ajustement `ReorderableListView`) ;
/// 2. **voie non-gestuelle** — le paquet n'offre QUE l'appui long ; deux
///    `CustomSemanticsAction` sont donc ajoutées **par ce paquet-ci** autour de
///    chaque cellule ;
/// 3. **l'appelant est la source de vérité** — ordre optimiste local, resynchronisé
///    sur `request.itemIds` dès que l'hôte en repousse un nouveau ;
/// 4. **AD-10** — un `onReorder` qui lève restaure l'ordre affiché et n'est pas
///    propagé (jamais de crash de rendu au milieu d'un geste).
class ZPackageReorderRenderer extends ZReorderRenderer {
  /// Construit le renderer. `const` : il peut être injecté tel quel.
  const ZPackageReorderRenderer({this.dragStartDelay, this.dragEnabled = true});

  /// Délai d'appui avant le démarrage du glissement. `null` ⇒ défaut du paquet
  /// (`kLongPressTimeout`). Type `Duration` : **aucun** type tiers ici.
  final Duration? dragStartDelay;

  /// Active/désactive la voie **gestuelle**. Même à `false`, la voie
  /// **sémantique** reste offerte : désactiver le glisser ne doit jamais retirer
  /// la capacité au lecteur d'écran (AD-13).
  final bool dragEnabled;

  @override
  Widget build(BuildContext context, ZReorderRenderRequest request) {
    return _ZPackageReorderGrid(
      request: request,
      dragStartDelay: dragStartDelay,
      dragEnabled: dragEnabled,
    );
  }
}

/// Grille interne — **jamais exportée** (le paquet tiers ne doit pas fuiter).
class _ZPackageReorderGrid extends StatefulWidget {
  const _ZPackageReorderGrid({
    required this.request,
    required this.dragStartDelay,
    required this.dragEnabled,
  });

  final ZReorderRenderRequest request;
  final Duration? dragStartDelay;
  final bool dragEnabled;

  @override
  State<_ZPackageReorderGrid> createState() => _ZPackageReorderGridState();
}

class _ZPackageReorderGridState extends State<_ZPackageReorderGrid> {
  /// Ordre OPTIMISTE local (permutation de `request.itemIds`).
  ///
  /// `ValueNotifier` + `ValueListenableBuilder` et non `setState` : réordonner
  /// ne reconstruit ni le parent ni la page (SM-1/AD-2). Aucun gestionnaire
  /// d'état.
  late final ValueNotifier<List<String>> _order;

  @override
  void initState() {
    super.initState();
    _order = ValueNotifier<List<String>>(List<String>.of(widget.request.itemIds));
  }

  @override
  void didUpdateWidget(covariant _ZPackageReorderGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Point 3 du contrat : l'appelant est la source de vérité. Dès qu'il
    // repousse un ordre (persisté, ou refusé), l'ordre local s'y réaligne.
    // S'il ne repousse rien, l'ordre optimiste est PRÉSERVÉ (retour immédiat).
    if (!listOrderEquals(widget.request.itemIds, oldWidget.request.itemIds)) {
      _order.value = List<String>.of(widget.request.itemIds);
    }
  }

  @override
  void dispose() {
    _order.dispose();
    super.dispose();
  }

  /// Applique un mouvement **déjà normalisé** (index linéaires) : ordre
  /// optimiste, notification de l'hôte, et RESTAURATION si l'hôte lève (AD-10).
  void _move(int from, int to) {
    final List<String> previous = _order.value;
    final List<String> next = applyLinearMove(previous, from, to);
    if (listOrderEquals(previous, next)) return;
    _order.value = next;
    try {
      widget.request.onReorder(from, to);
    } catch (_) {
      // AD-10 : une persistance qui échoue ne doit pas casser le rendu ni
      // laisser un ordre affiché incohérent. L'exception est ABSORBÉE par
      // conception ; c'est à l'hôte de la remonter dans son `onReorder`.
      _order.value = previous;
    }
  }

  /// Adaptateur du callback BRUT du paquet tiers → convention du port.
  void _handlePackageReorder(int rawOldIndex, int rawNewIndex) {
    final ZLinearMove? move = normalizePackageReorder(
      rawOldIndex: rawOldIndex,
      rawNewIndex: rawNewIndex,
      length: _order.value.length,
    );
    if (move == null) return;
    _move(move.oldIndex, move.newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final ZReorderRenderRequest request = widget.request;
    return ValueListenableBuilder<List<String>>(
      valueListenable: _order,
      builder: (context, ids, _) {
        // Garde vide AD-10 : jamais de grille fantôme, jamais de division par 0.
        if (ids.isEmpty) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            // Padding résolu DIRECTIONNELLEMENT (AD-13) : retranché du calcul
            // de largeur, mais appliqué visuellement à la grille (jamais
            // double-compté).
            final double horizontalPadding = request.padding
                    ?.resolve(Directionality.of(context))
                    .horizontal ??
                0;
            // MÊME primitive de colonnes que `ZAdaptiveGrid`/le repli : aucun
            // second calcul de colonnes dans le socle.
            final int columns = computeCrossAxisCount(
              availableWidth: constraints.maxWidth,
              minItemWidth: request.minItemWidth,
              minColumns: request.minColumns,
              maxColumns: request.maxColumns,
              spacing: request.spacing,
              horizontalPadding: horizontalPadding,
            );
            return ReorderableGridView.builder(
              // Le parent scrolle (grille embarquable), comme le repli.
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: request.padding,
              dragEnabled: widget.dragEnabled,
              dragStartDelay: widget.dragStartDelay,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: request.runSpacing ?? request.spacing,
                crossAxisSpacing: request.spacing,
                childAspectRatio: _aspectRatio(
                  availableWidth: constraints.maxWidth - horizontalPadding,
                  columns: columns,
                  request: request,
                ),
              ),
              itemCount: ids.length,
              onReorder: _handlePackageReorder,
              itemBuilder: (context, position) =>
                  _cell(context, ids, position, request),
            );
          },
        );
      },
    );
  }

  /// Ratio largeur/hauteur de cellule — `itemHeight` prime sur `aspectRatio`
  /// (plus déterministe), avec plancher défensif `> 0` fini (AD-10 : le
  /// delegate lèverait sur un ratio dégénéré).
  double _aspectRatio({
    required double availableWidth,
    required int columns,
    required ZReorderRenderRequest request,
  }) {
    final double rawItemWidth =
        (availableWidth - request.spacing * (columns - 1)) / columns;
    final double itemWidth = (rawItemWidth.isFinite && rawItemWidth > 0)
        ? rawItemWidth
        : request.minItemWidth;
    final double? height = request.itemHeight;
    double ratio = (height != null && height > 0)
        ? itemWidth / height
        : (request.aspectRatio ?? 1.0);
    if (!ratio.isFinite || ratio <= 0) ratio = 1.0;
    return ratio;
  }

  /// Une cellule : contenu de l'hôte + **voie non-gestuelle** (AD-13).
  ///
  /// La clé est portée par le widget racine retourné — `reorderable_grid_view`
  /// l'EXIGE (`assert` : « Every item of ReorderableGridView must have a key »)
  /// et s'en sert comme identité de l'item. Clé = **id opaque**, jamais la
  /// position (sinon l'état de cellule suivrait la case, pas l'item).
  Widget _cell(
    BuildContext context,
    List<String> ids,
    int position,
    ZReorderRenderRequest request,
  ) {
    final String id = ids[position];
    // Index SOURCE (position dans `request.itemIds`) : l'ordre optimiste local
    // a pu permuter l'affichage sans que l'hôte ait repoussé un nouvel ordre.
    // Même mapping que le repli — c'est une condition d'interchangeabilité.
    final int sourceIndex = request.itemIds.indexOf(id);
    final int lastPosition = ids.length - 1;

    // 🔴 Voie NON-GESTUELLE — ajoutée PAR CE PAQUET : `reorderable_grid_view`
    // n'offre que l'appui long, inatteignable au lecteur d'écran. Sans ces
    // actions, la capacité n'existerait tout simplement pas en navigation
    // assistée (AD-13). Libellés injectés par l'hôte, repli localisé sinon.
    final String moveBefore =
        request.moveBeforeSemanticLabel ?? kDefaultMoveBeforeLabel;
    final String moveAfter =
        request.moveAfterSemanticLabel ?? kDefaultMoveAfterLabel;

    return Semantics(
      key: ValueKey<String>(id),
      container: true,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (position > 0)
          CustomSemanticsAction(label: moveBefore): () =>
              _move(position, position - 1),
        if (position < lastPosition)
          CustomSemanticsAction(label: moveAfter): () =>
              _move(position, position + 1),
      },
      child: request.itemBuilder(
        context,
        sourceIndex < 0 ? position : sourceIndex,
      ),
    );
  }
}
