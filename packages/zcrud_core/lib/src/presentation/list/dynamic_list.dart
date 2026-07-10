/// `DynamicList` — hôte de rendu de liste du cœur `zcrud_core` (E4-1 → E4-4).
///
/// origine: E4-1 (hôte mince délégant au `ZListRenderer` injecté). E4-2 recâble
/// l'hôte autour de trois briques neutres (dérivation de colonnes, variantes de
/// vue `ZListLayout`, quatre états UI). **E4-4** rend la liste **ACTIONNABLE** —
/// toujours dans le cœur, toujours neutre :
/// 1. **actions de ligne** filtrées par `ZAcl` (AD-16) — résolues par ligne en
///    `ZResolvedRowAction` (sans `T`) ;
/// 2. **sélection multiple** stable via `ZListSelectionController` (état keyé par
///    `id` hors renderer — bug historique corrigé, AC4) ;
/// 3. **corbeille** soft-delete/restore via les fabriques `ZRowAction`.
///
/// `DynamicList` devient **générique `<T extends ZEntity>`** (défaut `ZEntity`,
/// seams `null` ⇒ non-régression stricte des sites E4-1/E4-2) : l'entité `T` est
/// nécessaire au filtrage ACL row-level (`acl.can(action, target: entity)`) et
/// au handler `onInvoke(context, entity)`. Le renderer, lui, ne voit **jamais**
/// `T` ni `ZAcl` : il reçoit un `ZListInteraction` neutre (actions déjà résolues,
/// sélection déjà keyée par `id`). SM-5 : `DynamicList` n'importe JAMAIS
/// `zcrud_list` ni Syncfusion — la statefulness de grille vit dans `zcrud_list`.
///
/// Sous-listes/onglets (E4-5) et **listing** de la corbeille (déféré E5) restent
/// hors périmètre.
library;

import 'package:flutter/material.dart';

import '../../domain/contracts/z_entity.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/ports/z_acl.dart';
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
///   - `builder`/`custom` → rendu **dans le cœur**, aucun renderer requis.
/// - En présence d'une [selection] et/ou de [rowActions] (E4-4), un
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
    this.rowActions,
    this.entityFor,
    this.actionAclMode = ZActionAclMode.hide,
    this.onSelectionChanged,
    this.collectionId,
    super.key,
  });

  /// Fabrique de commodité : enveloppe des [rows] prêtes dans un
  /// [ZListReady] (migration douce des sites E4-1 `DynamicList(fields, rows)`).
  DynamicList.rows(
    this.fields,
    List<ZListRow> rows, {
    this.layout = const ZListDataGridLayout(),
    this.renderer,
    this.columnPolicy,
    this.selection,
    this.rowActions,
    this.entityFor,
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

  /// Contrôleur de **sélection multiple** neutre (E4-4). `null` = pas de
  /// sélection (non-régression E4-1/E4-2). L'état vit dans le contrôleur (keyé
  /// par `id`), jamais dans le renderer (bug de sélection corrigé, AC4).
  final ZListSelectionController? selection;

  /// Actions de ligne **génériques** (E4-4), filtrées par `ZAcl`. `null` = aucune
  /// action. **Requiert** [entityFor] (le handler et l'ACL row-level ont besoin
  /// de l'entité `T`).
  final List<ZRowAction<T>>? rowActions;

  /// Résolveur `ZListRow → T?` fournissant l'entité d'une ligne (source du
  /// filtrage ACL row-level et du binding `onInvoke`). Requis si [rowActions] est
  /// non nul. Une ligne dont l'entité est `null` voit ses actions **omises**.
  final T? Function(ZListRow row)? entityFor;

  /// Mode de filtrage ACL des actions (défaut `hide`, cf. [ZActionAclMode]).
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

  /// Rend l'état `ready` : dérive les colonnes puis dispatch sur [layout]. En
  /// présence d'une sélection, écoute sa tranche `selectedIds` (rebuild ciblé,
  /// AD-2) et reconstruit l'interaction ; sinon rendu direct (chemin E4-1/E4-2).
  Widget _buildReady(BuildContext context, List<ZListRow> rows) {
    final request =
        ZListRenderRequest.fromSchema(fields, rows, policy: columnPolicy);
    if (!_interactive) {
      return _dispatch(context, request, null, const <String>{});
    }
    final sel = selection;
    if (sel == null) {
      // Actions sans sélection : interaction figée (aucune tranche à écouter).
      return _dispatch(
        context,
        request,
        _buildInteraction(context, const <String>{}),
        const <String>{},
      );
    }
    return ValueListenableBuilder<Set<String>>(
      valueListenable: sel.selectedIds,
      builder: (context, selectedIds, _) => _dispatch(
        context,
        request,
        _buildInteraction(context, selectedIds),
        selectedIds,
      ),
    );
  }

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
    final ZAcl acl = ZcrudScope.maybeOf(context)?.acl ?? const ZAllowAllAcl();
    final resolved = <ZResolvedRowAction>[];
    for (final action in actions) {
      final permission = action.requiredPermission;
      final allowed = permission == null ||
          acl.can(permission, target: entity, collectionId: collectionId);
      if (!allowed && actionAclMode == ZActionAclMode.hide) continue;
      resolved.add(action.resolve(context, entity, enabled: allowed));
    }
    return resolved;
  }

  /// Dispatch sur la variante de vue en propageant l'[interaction] neutre.
  Widget _dispatch(
    BuildContext context,
    ZListRenderRequest request,
    ZListInteraction? interaction,
    Set<String> selectedIds,
  ) {
    return switch (layout) {
      ZListDataGridLayout() =>
        _renderViaBackend(context, request, interaction),
      ZListBuilderLayout(:final itemBuilder) => _interactive
          ? _ZListInteractiveBuilderView(
              request: request,
              itemBuilder: itemBuilder,
              mode: selection?.mode ?? ZListSelectionMode.none,
              selectedIds: selectedIds,
              onToggle: selection == null
                  ? null
                  : (id) {
                      selection!.toggle(id);
                      onSelectionChanged?.call(selection!.selectedIds.value);
                    },
              actionsFor: interaction?.actionsFor,
            )
          : _ZListBuilderView(request: request, itemBuilder: itemBuilder),
      ZListCustomLayout(:final customView) => customView(context, request),
    };
  }

  /// Résout le renderer (paramètre → seam) et lui délègue ; [ZScopeError]
  /// actionnable list-spécifique si aucun backend n'est disponible.
  Widget _renderViaBackend(
    BuildContext context,
    ZListRenderRequest request,
    ZListInteraction? interaction,
  ) {
    // L1 (code-review E4-1) : `maybeOf` (et non `of`) pour que le message reste
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

/// Vue **liste ACTIONNABLE** (layout `builder` + interaction E4-4) : rend, DANS
/// le cœur (aucun Syncfusion, SM-5), une case de sélection keyée par `id` +
/// l'entrée [itemBuilder] + les actions résolues, chacune accessible (AC9).
class _ZListInteractiveBuilderView extends StatelessWidget {
  const _ZListInteractiveBuilderView({
    required this.request,
    required this.itemBuilder,
    required this.mode,
    required this.selectedIds,
    required this.onToggle,
    required this.actionsFor,
  });

  final ZListRenderRequest request;
  final Widget Function(BuildContext, ZListRow, List<ZListColumn>) itemBuilder;
  final ZListSelectionMode mode;
  final Set<String> selectedIds;
  final void Function(String id)? onToggle;
  final List<ZResolvedRowAction> Function(ZListRow row)? actionsFor;

  @override
  Widget build(BuildContext context) {
    final rows = request.rows;
    final columns = request.columns;
    return ListView.builder(
      key: const ValueKey('zListBuilder'),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final isSelected = selectedIds.contains(row.id);
        final actions = actionsFor?.call(row) ?? const <ZResolvedRowAction>[];
        return Row(
          key: ValueKey('zListRow_${row.id}'),
          children: <Widget>[
            if (mode != ZListSelectionMode.none)
              _SelectionCheckbox(
                selected: isSelected,
                onToggle: onToggle == null ? null : () => onToggle!(row.id),
              ),
            Expanded(child: itemBuilder(context, row, columns)),
            for (final action in actions) _RowActionButton(action: action),
          ],
        );
      },
    );
  }
}

/// Case de sélection accessible (AC9) : `Semantics(selected:)`, cible ≥ 48 dp.
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

/// Bouton d'action de ligne accessible (AC9) : `Semantics(button:true,
/// enabled:, label:)`, cible ≥ 48 dp, libellé l10n. Rend une icône si fournie,
/// sinon le libellé textuel.
class _RowActionButton extends StatelessWidget {
  const _RowActionButton({required this.action});

  final ZResolvedRowAction action;

  @override
  Widget build(BuildContext context) {
    final text = label(context, action.labelKey);
    final onPressed = action.enabled ? action.onInvoke : null;
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
      container: true,
      child: control,
    );
  }
}
