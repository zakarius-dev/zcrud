/// `DynamicList` — hôte de rendu de liste du cœur `zcrud_core`.
///
/// Hôte mince délégant au `ZListRenderer` injecté, câblé autour de trois
/// briques neutres (dérivation de colonnes, variantes de vue `ZListLayout`,
/// quatre états UI). La liste est **ACTIONNABLE** — toujours dans le cœur,
/// toujours neutre :
/// 1. **actions de ligne** filtrées par `ZAcl` (AD-16) — résolues par ligne en
///    `ZResolvedRowAction` (sans `T`) ;
/// 2. **sélection multiple** stable via `ZListSelectionController` (état keyé par
///    `id` hors renderer, immunisé contre un rebuild/scroll/pagination) ;
/// 3. **corbeille** soft-delete/restore via les fabriques `ZRowAction`.
///
/// `DynamicList` est **générique `<T extends ZEntity>`** (défaut `ZEntity`,
/// seams `null` ⇒ non-régression stricte pour un consommateur qui ne les
/// fournit pas) : l'entité `T` est nécessaire au filtrage ACL row-level
/// (`acl.can(action, target: entity)`) et au handler `onInvoke(context,
/// entity)`. Le renderer, lui, ne voit **jamais** `T` ni `ZAcl` : il reçoit un
/// `ZListInteraction` neutre (actions déjà résolues, sélection déjà keyée par
/// `id`). `DynamicList` n'importe JAMAIS `zcrud_list` ni Syncfusion — la
/// statefulness de grille vit dans `zcrud_list`.
///
/// Sous-listes/onglets et **listing** de la corbeille restent hors périmètre
/// de ce fichier (voir `ZSubListScreen`/`ZTabbedList`).
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../domain/contracts/z_entity.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/ports/z_acl.dart';
import '../edition/z_orphan_choice.dart';
import '../l10n/z_localizations.dart';
import '../z_scope_error.dart';
import '../zcrud_scope.dart';
import 'z_list_column.dart';
import 'z_list_interaction.dart';
import 'z_list_layout.dart';
import 'z_list_render_request.dart';
import 'z_list_renderer.dart';
import 'z_list_selection.dart';
import 'z_list_view_state.dart';
import 'z_row_action.dart';
import 'z_row_governance.dart';

/// Widget public affichant une liste, piloté par un [ZListViewState] et une
/// variante de vue [ZListLayout].
///
/// - Les états `loading`/`empty`/`noResults`/`error` sont rendus par CE wrapper
///   (accessibles, `Semantics`/`liveRegion`) SANS invoquer le renderer.
/// - En état `ready`, les colonnes sont **dérivées** ([columnPolicy] appliquée)
///   puis le rendu dispatch sur [layout] :
///   - `dataGrid` (défaut) → délègue au [renderer] injecté (paramètre) ou au seam
///     `ZcrudScope.listRenderer` ; si AUCUN → [ZScopeError] actionnable orientée
///     `zcrud_list` (chemin `dataGrid` **uniquement**) ;
///   - `builder`/`grid`/`custom` → rendu **dans le cœur**, aucun renderer
///     requis (`grid` = grille de cartes responsive, sans Syncfusion).
/// - En présence d'une [selection] et/ou de [rowActions], un
///   [ZListInteraction] neutre est construit (sélection keyée par `id`, actions
///   filtrées par `ZcrudScope.acl`) et passé au renderer / rendu dans le cœur.
class DynamicList<T extends ZEntity> extends StatelessWidget {
  /// Construit l'hôte de liste piloté par [state] et [layout].
  const DynamicList({
    required this.fields,
    required this.state,
    this.layout = const ZListDataGridLayout(),
    this.renderer,
    this.columnPolicy,
    this.selection,
    this.selectionActivation = ZListSelectionActivation.always,
    this.rowActions,
    this.entityFor,
    this.rowAcl,
    this.actionAclMode = ZActionAclMode.hide,
    this.onSelectionChanged,
    this.collectionId,
    super.key,
  });

  /// Fabrique de commodité : enveloppe des [rows] prêtes dans un
  /// [ZListReady] (migration douce depuis un simple `DynamicList(fields,
  /// rows)`).
  DynamicList.rows(
    this.fields,
    List<ZListRow> rows, {
    this.layout = const ZListDataGridLayout(),
    this.renderer,
    this.columnPolicy,
    this.selection,
    this.selectionActivation = ZListSelectionActivation.always,
    this.rowActions,
    this.entityFor,
    this.rowAcl,
    this.actionAclMode = ZActionAclMode.hide,
    this.onSelectionChanged,
    this.collectionId,
    super.key,
  }) : state = ZListReady(rows);

  /// Schéma source des colonnes (`ZFieldSpec[]`), dérivé en `ready`.
  final List<ZFieldSpec> fields;

  /// État de vue courant (loading/empty/noResults/error/ready).
  final ZListViewState state;

  /// Variante de vue (défaut `ZListDataGridLayout`).
  final ZListLayout layout;

  /// Renderer explicite (priorité sur le seam `ZcrudScope.listRenderer`) — n'est
  /// consulté que sur le chemin `dataGrid` en état `ready`.
  final ZListRenderer? renderer;

  /// Politique de colonnes optionnelle (force include/exclude, AD-4).
  final ZColumnPolicy? columnPolicy;

  /// Contrôleur de **sélection multiple** neutre. `null` = pas de
  /// sélection. L'état vit dans le contrôleur (keyé
  /// par `id`), jamais dans le renderer — immunisé contre un rebuild/scroll.
  final ZListSelectionController? selection;

  /// **Comment la sélection s'ouvre** (défaut
  /// [ZListSelectionActivation.always], comportement inchangé).
  ///
  /// [ZListSelectionActivation.longPress] n'affiche les cases qu'une fois la
  /// sélection non vide, et fait de l'appui long sur une ligne le geste qui
  /// l'ouvre. Sans effet si [selection] est `null`, et sans effet sur le
  /// chemin `dataGrid` (les gestes de ligne y appartiennent au backend de
  /// grille) : le réglage porte sur les vues rendues **dans le cœur**
  /// (`builder`, `grid`).
  final ZListSelectionActivation selectionActivation;

  /// Actions de ligne **génériques**, filtrées par `ZAcl`. `null` = aucune
  /// action. **Requiert** [entityFor] (le handler et l'ACL row-level ont besoin
  /// de l'entité `T`).
  final List<ZRowAction<T>>? rowActions;

  /// Résolveur `ZListRow → T?` fournissant l'entité d'une ligne.
  ///
  /// **Une seule déclaration, tous les usages** : le filtrage ACL row-level,
  /// le binding `onInvoke` des actions de ligne, le rendu des **tuiles
  /// typées** (`ZEntityTileBuilder`, cf. `ZListLayout.withEntityTiles`) et la
  /// vue personnalisée typée (`ZListCustomLayout.forEntity`, qui reçoit ce
  /// résolveur tel quel). Requis si [rowActions] est non nul, et si le
  /// [layout] porte une tuile ou une vue d'entité.
  ///
  /// Une ligne dont l'entité est `null` voit ses actions **omises** et sa
  /// tuile retomber sur le builder de ligne du layout (s'il en porte un).
  ///
  /// L'index attendu est keyé par `ZListRow.id` ; pour produire cette clé
  /// depuis une entité — `id` réel, ou clé éphémère si l'entité n'est pas
  /// encore persistée — utiliser `ZListRow.keyOf(entity)` plutôt que de
  /// réinventer la convention (`entityFor: (row) => index[row.id]`).
  final T? Function(ZListRow row)? entityFor;

  /// Gouvernance **par ligne** : restrictions propres à chaque entité, en
  /// **intersection** avec l'ACL ambiante (cf. [ZRowAclResolver]).
  ///
  /// `null` (défaut) = aucune restriction de ligne, comportement inchangé. Un
  /// résolveur ne peut que **retirer** un droit : il n'existe aucune manière
  /// d'y rouvrir un geste que l'ACL refuse.
  final ZRowAclResolver<T>? rowAcl;

  /// Mode de filtrage ACL des actions (défaut `hide`, cf. [ZActionAclMode]).
  ///
  /// L'ACL consultée est celle du `ZcrudScope` ambiant. **En son absence, le
  /// repli est refusant** (`ZDenyAllAcl`) : aucune action portant une
  /// `requiredPermission` n'est offerte. Déclarez votre ACL —
  /// `ZcrudScope(acl: MonAcl())` — ou, en développement,
  /// `ZcrudScope(acl: const ZAllowAllAcl())`. Les actions sans
  /// `requiredPermission` (custom) restent toujours offertes.
  final ZActionAclMode actionAclMode;

  /// Callback optionnel notifié à chaque changement de sélection (ensemble d'`id`).
  final void Function(Set<String> selectedIds)? onSelectionChanged;

  /// Identifiant de collection optionnel passé à `ZAcl.can` (filtrage
  /// collection-level quand l'entité ne suffit pas).
  final String? collectionId;

  bool get _interactive => selection != null || rowActions != null;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ZListLoading() => const _ZListLoadingView(),
      ZListEmpty() => const _ZListMessageView(
          messageKey: 'list.empty',
          viewKey: ValueKey('zListEmpty'),
        ),
      ZListNoResults() => const _ZListMessageView(
          messageKey: 'list.noResults',
          viewKey: ValueKey('zListNoResults'),
        ),
      ZListError(:final failure) => _ZListErrorView(message: failure.message),
      ZListReady(:final rows) => _buildReady(context, rows),
    };
  }

  /// Rend l'état `ready` : dérive les colonnes puis dispatch sur [layout].
  ///
  /// **Où la tranche de sélection est écoutée dépend de qui peint** (AD-2) :
  ///
  /// * vues rendues **dans le cœur** (`builder`, `grid`) — l'abonnement descend
  ///   jusqu'à la **case** de chaque ligne. Cocher une case ne reconstruit donc
  ///   que des cases : la tuile d'une ligne ne dépend pas de l'ensemble
  ///   sélectionné, il n'y a aucune raison de la refaire. Mesuré avant ce
  ///   partage : un `toggle` reconstruisait **toutes** les tuiles visibles ;
  /// * chemin `dataGrid` — le backend reçoit un `ZListInteraction` **complet**
  ///   (la sélection y est une donnée du modèle de rendu, pas un widget que
  ///   l'on pourrait isoler) : l'abonnement reste au niveau de la liste, et la
  ///   granularité fine relève du backend lui-même.
  Widget _buildReady(BuildContext context, List<ZListRow> rows) {
    final request = ZListRenderRequest.fromSchema(
      fields,
      rows,
      policy: columnPolicy,
      formatting: _formattingOf(context),
    );
    if (!_interactive) {
      return _dispatch(context, request, null, null);
    }
    final sel = selection;
    if (sel == null) {
      // Actions sans sélection : interaction figée (aucune tranche à écouter).
      return _dispatch(
        context,
        request,
        _buildInteraction(context, const <String>{}),
        null,
      );
    }
    if (layout is! ZListDataGridLayout) {
      return _dispatch(
        context,
        request,
        _buildInteraction(context, sel.selectedIds.value),
        sel.selectedIds,
      );
    }
    return ValueListenableBuilder<Set<String>>(
      valueListenable: sel.selectedIds,
      builder: (context, selectedIds, _) => _dispatch(
        context,
        request,
        _buildInteraction(context, selectedIds),
        sel.selectedIds,
      ),
    );
  }

  /// **Capture** les seams d'affichage que `ZListColumn.format` ne peut pas
  /// atteindre lui-même.
  ///
  /// C'est ICI — et nulle part ailleurs dans la chaîne de liste — qu'un
  /// `BuildContext` existe encore : le backend appelle `col.format(...)` depuis
  /// une `DataGridSource`, et `zcrud_export` l'appelle sans arbre de widgets. On
  /// résout donc le libellé d'orphelin (`zOrphanChoiceLabel`, MÊME clé l10n
  /// `choiceUnresolved` que toute autre voie de résolution — aucune seconde clé)
  /// et on lit le port de dates du scope, puis on les **transporte** dans la
  /// closure.
  ///
  /// AD-2 : aucune allocation coûteuse (une `String` déjà en table + deux
  /// références) ; l'objet a une égalité de **valeur**, donc deux builds
  /// successifs produisent des requêtes égales et ne font rien reconstruire.
  ZListFormat _formattingOf(BuildContext context) => zListFormatOf(context);

  /// Construit le pont d'interaction **neutre** consommé par le renderer.
  ZListInteraction _buildInteraction(
    BuildContext context,
    Set<String> selectedIds,
  ) {
    final sel = selection;
    return ZListInteraction(
      mode: sel?.mode ?? ZListSelectionMode.none,
      selectedIds: selectedIds,
      onSelectionChanged: sel == null
          ? null
          : (ids) {
              sel.setSelection(ids);
              onSelectionChanged?.call(sel.selectedIds.value);
            },
      actionsFor:
          rowActions == null ? null : (row) => _resolveActions(context, row),
    );
  }

  /// Résout les actions d'une ligne : filtre/désactive via `ZcrudScope.acl`
  /// (AD-16) et lie l'entité `T` (via [entityFor]). Une action `requiredPermission
  /// == null` (custom) est toujours incluse ; une ligne sans entité voit ses
  /// actions omises (impossible de lier `onInvoke`).
  List<ZResolvedRowAction> _resolveActions(
    BuildContext context,
    ZListRow row,
  ) {
    final actions = rowActions;
    if (actions == null) return const <ZResolvedRowAction>[];
    final entity = entityFor?.call(row);
    if (entity == null) return const <ZResolvedRowAction>[];
    // Refus par défaut (fail-closed) : sans `ZcrudScope` ambiant, aucune
    // action de ligne gouvernée par une permission n'est offerte. Une
    // application déclare son ACL — ou, en développement, déclare
    // explicitement `ZcrudScope(acl: const ZAllowAllAcl())`.
    final ZAcl acl = ZcrudScope.maybeOf(context)?.acl ?? const ZDenyAllAcl();
    return zResolveRowActions<T>(
      context,
      actions: actions,
      entity: entity,
      acl: acl,
      mode: actionAclMode,
      rowAcl: rowAcl,
      collectionId: collectionId,
    );
  }

  /// Résout la tuile effective d'un layout à tuiles : la tuile **typée**
  /// ([entityBuilder]) l'emporte dès que [entityFor] rend l'entité de la
  /// ligne ; sinon on retombe sur la tuile de ligne ([rowBuilder]) ; sinon la
  /// tuile est vide (aucun builder déclaré — cas d'un layout que l'application
  /// destine à un assembleur, cf. `ZListLayout.withEntityTiles`).
  ///
  /// La résolution est faite **ici**, une fois par rendu de ligne, pour que le
  /// seam `ZListRow → T?` déjà déclaré pour les actions de ligne serve aussi
  /// au rendu des cartes : l'application ne redéclare jamais son index.
  ///
  /// Ni le résolveur ni les builders n'entrent dans la `ZListRenderRequest`
  /// (value object à égalité de valeur) : ce sont des **closures**, dont
  /// l'identité change à chaque build. Les y faire entrer casserait la
  /// mémoïsation du rendu — même raison que l'exclusion de
  /// `ZFieldSpec.derivedFrom`/`choicesResolver` de `==`/`hashCode`.
  ZRowTileBuilder _tileBuilderOf(
    ZRowTileBuilder? rowBuilder,
    ZEntityTileBuilder<ZEntity>? entityBuilder,
  ) {
    return (BuildContext context, ZListRow row, List<ZListColumn> columns) {
      if (entityBuilder != null) {
        final entity = entityFor?.call(row);
        if (entity != null) return entityBuilder(context, entity, columns);
      }
      if (rowBuilder != null) return rowBuilder(context, row, columns);
      return const SizedBox.shrink();
    };
  }

  /// Dispatch sur la variante de vue en propageant l'[interaction] neutre.
  ///
  /// [selectedIds] est la **tranche** de sélection elle-même (jamais sa valeur
  /// figée) : les vues rendues dans le cœur s'y abonnent au grain de la ligne.
  Widget _dispatch(
    BuildContext context,
    ZListRenderRequest request,
    ZListInteraction? interaction,
    ValueListenable<Set<String>>? selectedIds,
  ) {
    return switch (layout) {
      ZListDataGridLayout() =>
        _renderViaBackend(context, request, interaction),
      final ZListBuilderLayout list => _interactive
          ? _ZListInteractiveBuilderView(
              request: request,
              itemBuilder: _tileBuilderOf(list.itemBuilder, list.entityBuilder),
              mode: selection?.mode ?? ZListSelectionMode.none,
              activation: selectionActivation,
              selectedIds: selectedIds,
              onToggle: selection == null
                  ? null
                  : (id) {
                      selection!.toggle(id);
                      onSelectionChanged?.call(selection!.selectedIds.value);
                    },
              actionsFor: interaction?.actionsFor,
            )
          : _ZListBuilderView(
              request: request,
              itemBuilder: _tileBuilderOf(list.itemBuilder, list.entityBuilder),
            ),
      final ZListGridLayout grid => _ZListGridView(
          request: request,
          layout: grid,
          tileBuilder: _tileBuilderOf(grid.itemBuilder, grid.entityBuilder),
          mode: selection?.mode ?? ZListSelectionMode.none,
          activation: selectionActivation,
          selectedIds: selectedIds,
          onToggle: selection == null
              ? null
              : (id) {
                  selection!.toggle(id);
                  onSelectionChanged?.call(selection!.selectedIds.value);
                },
          actionsFor: interaction?.actionsFor,
        ),
      // Vue entière : le résolveur descend tel quel (le cast vers `T` est
      // l'affaire de `forEntity`). `entityFor` absent ⇒ résolveur nul partout.
      ZListCustomLayout(:final customView, :final entityView) =>
        entityView != null
            ? entityView(context, request, (row) => entityFor?.call(row))
            : customView!(context, request),
    };
  }

  /// Résout le renderer (paramètre → seam) et lui délègue ; [ZScopeError]
  /// actionnable list-spécifique si aucun backend n'est disponible.
  Widget _renderViaBackend(
    BuildContext context,
    ZListRenderRequest request,
    ZListInteraction? interaction,
  ) {
    // `maybeOf` (et non `of`) pour que le message reste
    // LIST-SPÉCIFIQUE même en l'ABSENCE d'un ancêtre `ZcrudScope`.
    final resolved = renderer ?? ZcrudScope.maybeOf(context)?.listRenderer;
    if (resolved == null) {
      throw ZScopeError(
        'Aucun ZListRenderer fourni. Ajoutez le package zcrud_list et injectez '
        'ZSfDataGridRenderer via ZcrudScope(listRenderer: const '
        'ZSfDataGridRenderer(), child: ...), passez-le à '
        'DynamicList(renderer: ...), ou fournissez votre propre backend '
        'implémentant ZListRenderer.',
      );
    }
    return resolved.build(context, request, interaction: interaction);
  }
}

/// Vue d'état **chargement** : indicateur de progression centré + `Semantics`
/// `liveRegion` (annonce). Aucune chaîne/couleur codée en dur.
class _ZListLoadingView extends StatelessWidget {
  const _ZListLoadingView();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('zListLoading'),
      liveRegion: true,
      container: true,
      label: label(context, 'list.loading'),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Vue d'état **message neutre** (vide / aucun résultat), centrée et annoncée.
/// La [messageKey] distingue `list.empty` de `list.noResults` (textes distincts).
class _ZListMessageView extends StatelessWidget {
  const _ZListMessageView({required this.messageKey, required this.viewKey});

  final String messageKey;
  final ValueKey<String> viewKey;

  @override
  Widget build(BuildContext context) {
    final text = label(context, messageKey);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: text,
      child: Center(
        key: viewKey,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

/// Vue d'état **erreur** : préfixe l10n `list.error` + message de la `ZFailure`,
/// annoncé (`Semantics(liveRegion: true)`, AD-11). Couleur d'erreur du thème.
class _ZListErrorView extends StatelessWidget {
  const _ZListErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final prefix = label(context, 'list.error');
    final theme = Theme.of(context);
    return Semantics(
      key: const ValueKey('zListError'),
      liveRegion: true,
      container: true,
      excludeSemantics: true,
      label: '$prefix $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                prefix,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vue **liste** (layout `builder`) : `ListView.builder` **dans le cœur**,
/// Material-free, une entrée par ligne via [itemBuilder]. Aucun renderer requis.
class _ZListBuilderView extends StatelessWidget {
  const _ZListBuilderView({required this.request, required this.itemBuilder});

  final ZListRenderRequest request;
  final Widget Function(BuildContext, ZListRow, List<ZListColumn>) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final rows = request.rows;
    final columns = request.columns;
    return ListView.builder(
      key: const ValueKey('zListBuilder'),
      itemCount: rows.length,
      itemBuilder: (context, index) =>
          itemBuilder(context, rows[index], columns),
    );
  }
}

/// Vue **liste ACTIONNABLE** (layout `builder` + interaction) : rend, DANS
/// le cœur (aucun Syncfusion), une case de sélection keyée par `id` +
/// l'entrée [itemBuilder] + les actions résolues, chacune accessible.
class _ZListInteractiveBuilderView extends StatelessWidget {
  const _ZListInteractiveBuilderView({
    required this.request,
    required this.itemBuilder,
    required this.mode,
    required this.activation,
    required this.selectedIds,
    required this.onToggle,
    required this.actionsFor,
  });

  final ZListRenderRequest request;
  final Widget Function(BuildContext, ZListRow, List<ZListColumn>) itemBuilder;
  final ZListSelectionMode mode;
  final ZListSelectionActivation activation;
  final ValueListenable<Set<String>>? selectedIds;
  final void Function(String id)? onToggle;
  final List<ZResolvedRowAction> Function(ZListRow row)? actionsFor;

  @override
  Widget build(BuildContext context) {
    final rows = request.rows;
    final columns = request.columns;
    final selected = selectedIds;
    return ListView.builder(
      key: const ValueKey('zListBuilder'),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final actions = actionsFor?.call(row) ?? const <ZResolvedRowAction>[];
        final Widget line = Row(
          key: ValueKey('zListRow_${row.id}'),
          children: <Widget>[
            if (mode != ZListSelectionMode.none && selected != null)
              _SelectionCheckboxSlot(
                selectedIds: selected,
                id: row.id,
                activation: activation,
                onToggle: onToggle == null ? null : () => onToggle!(row.id),
              ),
            Expanded(child: itemBuilder(context, row, columns)),
            for (final action in actions) _RowActionButton(action: action),
          ],
        );
        return _maybeLongPressToSelect(
          line,
          rowId: row.id,
          mode: mode,
          activation: activation,
          onToggle: onToggle,
        );
      },
    );
  }
}

/// Vue **grille** (layout `grid`) : `GridView.builder` **dans le cœur**,
/// virtualisée, colonnes responsives (`SliverGridDelegateWithMaxCrossAxisExtent`
/// — directionnel, RTL natif), une carte par ligne via `itemBuilder`. Aucune
/// couleur ici : la carte est l'affaire de l'app (thème via
/// `ZcrudScope`/`Theme.of`). En présence d'une sélection et/ou d'actions, la
/// tuile porte un pied accessible (case ≥ 48 dp + boutons d'actions résolues,
/// mêmes briques que la vue `builder`). Aucun renderer requis.
class _ZListGridView extends StatelessWidget {
  const _ZListGridView({
    required this.request,
    required this.layout,
    required this.tileBuilder,
    required this.mode,
    required this.activation,
    required this.selectedIds,
    required this.onToggle,
    required this.actionsFor,
  });

  final ZListRenderRequest request;
  final ZListGridLayout layout;

  /// Tuile effective de la grille (entité résolue si le layout en porte une,
  /// sinon ligne neutre) — résolue par `DynamicList._tileBuilderOf`.
  final ZRowTileBuilder tileBuilder;
  final ZListSelectionMode mode;
  final ZListSelectionActivation activation;
  final ValueListenable<Set<String>>? selectedIds;
  final void Function(String id)? onToggle;
  final List<ZResolvedRowAction> Function(ZListRow row)? actionsFor;

  @override
  Widget build(BuildContext context) {
    final maxColumns = layout.maxColumns;
    if (maxColumns == null) {
      // Sans plafond : délégué responsive natif, comportement inchangé.
      return _buildGrid(
        SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: layout.maxCrossAxisExtent,
          mainAxisSpacing: layout.mainAxisSpacing,
          crossAxisSpacing: layout.crossAxisSpacing,
          childAspectRatio: layout.childAspectRatio,
          mainAxisExtent: layout.mainAxisExtent,
        ),
      );
    }
    // Plafond de colonnes : reproduit la dérivation de
    // `SliverGridDelegateWithMaxCrossAxisExtent` (colonnes = largeur ÷
    // (extent + espacement), arrondi au supérieur, ≥ 1) puis la plafonne à
    // `maxColumns` via un délégué à nombre de colonnes fixe.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth - (layout.padding?.horizontal ?? 0.0);
        var count = width <= 0
            ? 1
            : (width / (layout.maxCrossAxisExtent + layout.crossAxisSpacing))
                .ceil();
        if (count < 1) count = 1;
        if (count > maxColumns) count = maxColumns;
        return _buildGrid(
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: layout.mainAxisSpacing,
            crossAxisSpacing: layout.crossAxisSpacing,
            childAspectRatio: layout.childAspectRatio,
            mainAxisExtent: layout.mainAxisExtent,
          ),
        );
      },
    );
  }

  /// Rend la grille virtualisée avec le [gridDelegate] résolu (plafonné ou
  /// non) — corps commun aux deux chemins de [build].
  Widget _buildGrid(SliverGridDelegate gridDelegate) {
    final rows = request.rows;
    final columns = request.columns;
    return GridView.builder(
      key: const ValueKey('zListGrid'),
      padding: layout.padding,
      gridDelegate: gridDelegate,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final tile = tileBuilder(context, row, columns);
        final actions = actionsFor?.call(row) ?? const <ZResolvedRowAction>[];
        final selected = selectedIds;
        final selectable = mode != ZListSelectionMode.none && selected != null;
        if (!selectable && actions.isEmpty) {
          return _maybeLongPressToSelect(
            KeyedSubtree(
              key: ValueKey('zListGridTile_${row.id}'),
              child: tile,
            ),
            rowId: row.id,
            mode: mode,
            activation: activation,
            onToggle: onToggle,
          );
        }
        // Tuile interactive : carte + pied (case de sélection / actions),
        // mêmes briques accessibles que la vue `builder` (≥ 48 dp, Semantics).
        return _maybeLongPressToSelect(
          Column(
            key: ValueKey('zListGridTile_${row.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: tile),
              Row(
                children: <Widget>[
                  if (selectable)
                    _SelectionCheckboxSlot(
                      selectedIds: selected,
                      id: row.id,
                      activation: activation,
                      onToggle:
                          onToggle == null ? null : () => onToggle!(row.id),
                    ),
                  const Spacer(),
                  for (final action in actions)
                    _RowActionButton(action: action),
                ],
              ),
            ],
          ),
          rowId: row.id,
          mode: mode,
          activation: activation,
          onToggle: onToggle,
        );
      },
    );
  }
}

/// Enveloppe [child] d'un appui long qui **ouvre la sélection**, quand c'est le
/// geste déclaré ([ZListSelectionActivation.longPress]) et que la liste est
/// sélectionnable. Rend [child] tel quel dans tous les autres cas — aucun
/// détecteur de gestes n'est posé, l'arbre reste identique au précédent.
///
/// a11y (AD-13) : `GestureDetector.onLongPress` publie
/// `SemanticsAction.longPress`, si bien que le geste est annoncé et
/// déclenchable par un lecteur d'écran — l'ouverture de la sélection n'est pas
/// réservée au doigt.
Widget _maybeLongPressToSelect(
  Widget child, {
  required String rowId,
  required ZListSelectionMode mode,
  required ZListSelectionActivation activation,
  required void Function(String id)? onToggle,
}) {
  if (activation != ZListSelectionActivation.longPress ||
      mode == ZListSelectionMode.none ||
      onToggle == null) {
    return child;
  }
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onLongPress: () => onToggle(rowId),
    child: child,
  );
}

/// Case de sélection **abonnée** à la tranche de sélection de la liste.
///
/// C'est le plus petit sous-arbre qui dépende réellement de l'ensemble
/// sélectionné : en y logeant l'abonnement, un `toggle` ne reconstruit que des
/// cases — la tuile de la ligne, elle, ne change pas parce qu'une autre ligne a
/// été cochée, et n'a donc aucune raison d'être refaite (AD-2).
class _SelectionCheckboxSlot extends StatelessWidget {
  const _SelectionCheckboxSlot({
    required this.selectedIds,
    required this.id,
    required this.activation,
    required this.onToggle,
  });

  final ValueListenable<Set<String>> selectedIds;
  final String id;
  final ZListSelectionActivation activation;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedIds,
      builder: (context, ids, _) {
        // Sélection ouverte à l'appui long : tant que rien n'est sélectionné,
        // la sélection est FERMÉE et aucune case n'occupe la ligne. « Ouverte »
        // n'est pas un état conservé à part — c'est « la sélection n'est pas
        // vide », donc rien ne peut s'en désynchroniser.
        if (activation == ZListSelectionActivation.longPress && ids.isEmpty) {
          return const SizedBox.shrink();
        }
        return _SelectionCheckbox(
          selected: ids.contains(id),
          onToggle: onToggle,
        );
      },
    );
  }
}

/// Case de sélection accessible : `Semantics(selected:)`, cible ≥ 48 dp.
class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({required this.selected, required this.onToggle});

  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: label(context, 'select'),
      container: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Checkbox(
          value: selected,
          onChanged: onToggle == null ? null : (_) => onToggle!(),
        ),
      ),
    );
  }
}

/// Bouton d'action de ligne accessible : `Semantics(button:true,
/// enabled:, label:)`, cible ≥ 48 dp, libellé l10n. Rend une icône si fournie,
/// sinon le libellé textuel.
///
/// Une action fermée reste **rendue et inerte** : elle garde sa place, son
/// libellé et annonce son motif (`Semantics.hint`) plutôt que de disparaître —
/// masquer relève, lui, du mode d'ACL déclaré, décidé bien en amont.
class _RowActionButton extends StatelessWidget {
  const _RowActionButton({required this.action});

  final ZResolvedRowAction action;

  @override
  Widget build(BuildContext context) {
    final text = label(context, action.labelKey);
    final onPressed = action.enabled ? action.onInvoke : null;
    final reasonKey = action.enabled ? null : action.disabledReasonKey;
    final reason = reasonKey == null ? null : label(context, reasonKey);
    final Widget control = action.icon != null
        ? SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(action.icon),
              tooltip: text,
              onPressed: onPressed,
            ),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: TextButton(
              onPressed: onPressed,
              child: Text(text, textAlign: TextAlign.center),
            ),
          );
    return Semantics(
      button: true,
      enabled: action.enabled,
      label: text,
      hint: reason,
      container: true,
      child: control,
    );
  }
}

/// **Capture** les seams d'affichage que `ZListColumn.format` ne peut pas
/// atteindre lui-même : le libellé d'une option orpheline, le port de formatage
/// des dates du `ZcrudScope`, et l'étiquette de locale.
///
/// C'est la **voie unique** par laquelle un rendu de liste — la liste elle-même
/// comme un export lancé depuis un écran — se procure son [ZListFormat]. Deux
/// appelants qui la partagent produisent, par construction, les mêmes textes de
/// cellule : ce que l'utilisateur lit à l'écran est ce que son fichier contient.
/// Reconstruire cet objet à la main ailleurs rouvrirait l'écart, sans erreur ni
/// signe visible.
///
/// L'appel exige un `BuildContext` — les seams ne vivent nulle part ailleurs.
/// Un export *headless*, sans arbre de widgets, s'en passe et rend alors un
/// texte locale-neutre.
///
/// **Pas cher (invariant AD-2)** : une `String` déjà en table et deux
/// références ; l'objet a une égalité de **valeur**, donc deux builds successifs
/// produisent des requêtes égales et ne reconstruisent rien.
ZListFormat zListFormatOf(BuildContext context) => ZListFormat(
      orphanChoiceLabel: zOrphanChoiceLabel(context),
      dateFormatter: ZcrudScope.maybeOf(context)?.dateDisplayFormatter,
      localeTag: Localizations.maybeLocaleOf(context)?.toLanguageTag(),
    );
