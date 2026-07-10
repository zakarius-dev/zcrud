import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../binding/binding_selector.dart';
import 'list_demo_data.dart';

/// Taille de page (curseur) partagée par la liste principale et les onglets
/// (AC4(d)) — pilote la pagination `ZListController.loadMore` ET l'affordance
/// « Charger plus » (`_LoadMoreBar`).
const int _demoPageSize = 15;

/// Écran de démo LISTE (EX-2, AC3→AC8). Monte [DynamicList] en layout
/// `dataGrid` (backend Syncfusion `ZSfDataGridRenderer` injecté au scope RACINE,
/// AC5/SM-5) sur une source de données **in-memory** ([DemoStore]/[DemoRepository]),
/// avec :
///  - un [ZListController] **stable** (créé dans `initState`, `dispose`é) écouté
///    via sa **seule** tranche `state` (`ValueListenableBuilder`, AD-2) ;
///  - colonnes **dérivées** du schéma (`deriveColumns`/`ZColumnPolicy`, AC3) ;
///  - recherche / filtre catégorie / tri / pagination curseur (AC4) ;
///  - actions de ligne (`edit` + `softDelete`) filtrées par un [ZAcl] de démo
///    (`actionAclMode.disable`) + sélection multiple + corbeille (AC5) ;
///  - une vue à onglets `ZTabbedList` catégorisant via `baseFilters` (AC6) et une
///    corbeille (restore, AC5) ;
///  - un sélecteur de binding re-montant la MÊME liste sous chaque mécanisme
///    d'injection (parité AD-15, AC8) — un NOUVEAU controller/selection par wrap.
class ListDemoScreen extends StatefulWidget {
  /// Construit l'écran de démo LISTE.
  const ListDemoScreen({this.initialBinding = DemoBinding.scope, super.key});

  /// Binding initial (permet aux tests de cibler un wrap donné).
  final DemoBinding initialBinding;

  @override
  State<ListDemoScreen> createState() => _ListDemoScreenState();
}

class _ListDemoScreenState extends State<ListDemoScreen> {
  late DemoBinding _binding;
  late final DemoStore _store;
  late DemoRepository _repo;
  late ZListController<DemoRecord> _controller;
  late ZListSelectionController _selection;

  String? _category;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _binding = widget.initialBinding;
    _store = DemoStore();
    _buildControllers();
  }

  void _buildControllers() {
    _repo = DemoRepository(_store);
    _controller = ZListController<DemoRecord>(
      repository: _repo,
      toRow: toDemoRow,
      schema: demoSchema,
      pageSize: _demoPageSize,
      // `watchMutations` : un soft-delete (corbeille) relance la requête → la
      // ligne disparaît de la liste active sans intervention manuelle (AD-9).
      watchMutations: true,
    );
    _selection = ZListSelectionController();
    // Réapplique l'état d'UI courant (filtre/tri) au nouveau controller (switch).
    _applyFilters();
    _applySort();
  }

  void _changeBinding(DemoBinding next) {
    if (next == _binding) return;
    // AC8 : un NOUVEAU controller/selection par wrap ; on dispose proprement les
    // anciens. MAJEUR-1 (EX-1) : disposer le contrôleur DÉPENDANT (sélection,
    // keyée par `id`) AVANT le `ZListController` source des lignes.
    final oldSelection = _selection;
    final oldController = _controller;
    setState(() {
      _binding = next;
      _buildControllers();
    });
    oldSelection.dispose();
    oldController.dispose();
  }

  void _applyFilters() {
    _controller.setFilters(
      _category == null
          ? const <ZFilter>[]
          : <ZFilter>[ZFilter('category', ZFilterOp.eq, _category)],
    );
  }

  void _applySort() {
    _controller.setSort(<ZSort>[
      ZSort('name', _sortAsc ? ZSortDirection.asc : ZSortDirection.desc),
    ]);
  }

  void _onCategoryChanged(String? value) {
    setState(() => _category = value);
    _applyFilters();
  }

  void _toggleSort() {
    setState(() => _sortAsc = !_sortAsc);
    _applySort();
  }

  DemoRecord? _entityFor(ZListRow row) {
    for (final r in _store.visible(includeDeleted: false)) {
      if (r.recordId == row.id) return r;
    }
    return null;
  }

  List<ZRowAction<DemoRecord>> _rowActions() => <ZRowAction<DemoRecord>>[
        ZRowAction<DemoRecord>.edit(
          icon: Icons.edit,
          onInvoke: (context, entity) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Édition de « ${entity.name} » (démo)')),
            );
          },
        ),
        ZRowAction<DemoRecord>.softDelete(
          _repo,
          icon: Icons.delete_outline,
          onSuccess: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Déplacé vers la corbeille')),
            );
          },
        ),
      ];

  @override
  void dispose() {
    // MAJEUR-1 : sélection (dépendante) avant le controller, puis le magasin
    // partagé qu'ils exploitent.
    _selection.dispose();
    _controller.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Démo Liste (E4)'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Onglets par catégorie',
            icon: const Icon(Icons.tab),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CategoryTabsScreen(store: _store),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Corbeille',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TrashScreen(store: _store),
              ),
            ),
          ),
        ],
      ),
      // Sous-arbre IDENTIQUE sous chaque binding (AD-15) : seul le `wrap`
      // d'injection change. Clé sur le binding → remontage propre (AC8).
      body: KeyedSubtree(
        key: ValueKey<DemoBinding>(_binding),
        // MEDIUM-1 (EX-1) : capte le scope RACINE (dont `listRenderer`) pour le
        // re-propager SOUS le scope du binding (sinon le renderer serait masqué
        // sous get/riverpod/provider → `ZScopeError` sur 3 des 4 voies).
        child: wrapWithBinding(
          _binding,
          _buildBody(),
          rootScope: ZcrudScope.maybeOf(context),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BindingSelector(value: _binding, onChanged: _changeBinding),
        _ListToolbar(
          category: _category,
          sortAsc: _sortAsc,
          onSearch: _controller.setSearch,
          onCategoryChanged: _onCategoryChanged,
          onToggleSort: _toggleSort,
        ),
        _SelectionBanner(selection: _selection, repository: _repo),
        Expanded(
          // Builder : le contexte est SOUS le scope du binding → `ZcrudScope.of`
          // résout le `listRenderer` déjà re-propagé. On enveloppe la liste d'un
          // `ZcrudScope` qui injecte un [ZAcl] de démo tout en PRÉSERVANT les
          // autres seams (dont le renderer) — le filtrage d'actions (AC5) est
          // ainsi actif sous les 4 bindings sans casser la parité.
          child: Builder(
            builder: (listContext) {
              final base = ZcrudScope.of(listContext);
              return ZcrudScope(
                resolver: base.resolver,
                acl: const _DemoAcl(),
                labels: base.labels,
                theme: base.theme,
                widgetRegistry: base.widgetRegistry,
                filePicker: base.filePicker,
                cloudStorage: base.cloudStorage,
                listRenderer: base.listRenderer,
                child: ValueListenableBuilder<ZListViewState>(
                  valueListenable: _controller.state,
                  builder: (context, state, _) => DynamicList<DemoRecord>(
                    fields: demoSchema,
                    state: state,
                    columnPolicy: const ZColumnPolicy(),
                    selection: _selection,
                    rowActions: _rowActions(),
                    entityFor: _entityFor,
                    // `disable` : une action non autorisée (éditer un
                    // enregistrement inactif) est rendue GRISÉE (découvrabilité).
                    actionAclMode: ZActionAclMode.disable,
                  ),
                ),
              );
            },
          ),
        ),
        // AC4(d) : contrôle de pagination câblé à `ZListController.loadMore` —
        // exerce le curseur end-to-end dans l'UI (ni `DynamicList` ni le renderer
        // Syncfusion n'exposent de hook scroll-end dans l'API publique).
        _LoadMoreBar(controller: _controller),
      ],
    );
  }
}

/// Contrôle de pagination (AC4(d)) : bouton « Charger plus » câblé à
/// [ZListController.loadMore]. Comme ni `DynamicList` ni le `ZListRenderer`
/// Syncfusion n'exposent de hook scroll-end / `loadMoreViewBuilder` dans l'API
/// publique de `zcrud_list`, la pagination **curseur** est exercée end-to-end
/// par ce bouton. Il n'écoute QUE la tranche `state` du controller (rebuild
/// ciblé, AD-2). Visibilité : une **dernière page pleine** (`rows.length`
/// multiple de `pageSize`) signale qu'il reste probablement une page — miroir
/// exact de la dérivation `hasMore` du controller (`rows.length >= limit`) ;
/// dès qu'une page **partielle** est atteinte (plus de page), le bouton
/// disparaît. Un `loadMore` sans page suivante reste un no-op côté controller.
class _LoadMoreBar extends StatelessWidget {
  const _LoadMoreBar({required this.controller});

  final ZListController<DemoRecord> controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZListViewState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        final count = state is ZListReady ? state.rows.length : 0;
        final maybeMore = count > 0 && count % _demoPageSize == 0;
        if (!maybeMore) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
          child: Center(
            child: OutlinedButton.icon(
              key: const ValueKey<String>('listDemoLoadMore'),
              // Cible tactile ≥ 48 dp (AD-13).
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.expand_more),
              label: Text('Charger plus ($count)'),
              onPressed: () => unawaited(controller.loadMore()),
            ),
          ),
        );
      },
    );
  }
}

/// Barre d'outils : recherche + filtre catégorie + bascule de tri (AC4).
class _ListToolbar extends StatelessWidget {
  const _ListToolbar({
    required this.category,
    required this.sortAsc,
    required this.onSearch,
    required this.onCategoryChanged,
    required this.onToggleSort,
  });

  final String? category;
  final bool sortAsc;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onToggleSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              textField: true,
              label: 'Rechercher',
              child: TextField(
                key: const ValueKey<String>('listDemoSearch'),
                textAlign: TextAlign.start,
                onChanged: onSearch,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Rechercher…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String?>(
            key: const ValueKey<String>('listDemoCategoryFilter'),
            value: category,
            hint: const Text('Catégorie'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(child: Text('Toutes')),
              for (final c in demoCategories)
                DropdownMenuItem<String?>(
                  value: c.value as String,
                  child: Text(c.label),
                ),
            ],
            onChanged: onCategoryChanged,
          ),
          IconButton(
            tooltip: sortAsc ? 'Tri : Désignation ↑' : 'Tri : Désignation ↓',
            icon: Icon(sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: onToggleSort,
          ),
        ],
      ),
    );
  }
}

/// Bannière de sélection : n'écoute QUE la tranche `selectedIds` (rebuild ciblé,
/// AD-2). Affiche le nombre sélectionné + une action de suppression en lot (AC5).
class _SelectionBanner extends StatelessWidget {
  const _SelectionBanner({required this.selection, required this.repository});

  final ZListSelectionController selection;
  final DemoRepository repository;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: selection.selectedIds,
      builder: (context, ids, _) {
        if (ids.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Container(
          width: double.infinity,
          color: theme.colorScheme.secondaryContainer,
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${ids.length} sélectionné(s)',
                  textAlign: TextAlign.start,
                  style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
                onPressed: () => selection.softDeleteSelected<DemoRecord>(
                  repository,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ACL de démo (AC5) : refuse `update` (édition) sur un enregistrement **inactif**
/// (`active == false`) — l'action `edit` apparaît alors GRISÉE (`actionAclMode.
/// disable`). Toutes les autres actions/permissions sont autorisées.
class _DemoAcl implements ZAcl {
  const _DemoAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) {
    if (action == ZCrudAction.update && target is DemoRecord) {
      return target.active;
    }
    return true;
  }
}

/// Écran **corbeille** (AC5) : liste les enregistrements soft-deleted (vue
/// `DemoRepository(includeDeleted: true)` sur le MÊME magasin) avec une action
/// `restore` par ligne. Restaurer rétablit l'enregistrement → il réapparaît dans
/// la liste active (les deux vues observent le même flux de mutations).
class TrashScreen extends StatefulWidget {
  /// Construit la corbeille sur le [store] partagé.
  const TrashScreen({required this.store, super.key});

  /// Magasin partagé (source de vérité).
  final DemoStore store;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late final DemoRepository _repo;
  late final ZListController<DemoRecord> _controller;

  @override
  void initState() {
    super.initState();
    _repo = DemoRepository(widget.store, includeDeleted: true);
    _controller = ZListController<DemoRecord>(
      repository: _repo,
      toRow: toDemoRow,
      schema: demoSchema,
      watchMutations: true,
    );
  }

  DemoRecord? _entityFor(ZListRow row) {
    for (final r in widget.store.visible(includeDeleted: true)) {
      if (r.recordId == row.id) return r;
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Corbeille')),
      body: ValueListenableBuilder<ZListViewState>(
        valueListenable: _controller.state,
        builder: (context, state, _) => DynamicList<DemoRecord>(
          fields: demoSchema,
          state: state,
          columnPolicy: const ZColumnPolicy(),
          entityFor: _entityFor,
          rowActions: <ZRowAction<DemoRecord>>[
            ZRowAction<DemoRecord>.restore(
              _repo,
              icon: Icons.restore_from_trash,
              onSuccess: () {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restauré')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Écran **onglets par catégorie** (AC6) : un `ZTabbedList` où chaque onglet est
/// une liste indépendante keep-alive, catégorisée via `baseFilters` (la catégorie
/// ne peut JAMAIS être écrasée par une recherche/un filtre utilisateur). L'état
/// de chaque onglet (recherche/tri/sélection/scroll) est préservé au switch.
class CategoryTabsScreen extends StatelessWidget {
  /// Construit les onglets sur le [store] partagé.
  const CategoryTabsScreen({required this.store, super.key});

  /// Magasin partagé.
  final DemoStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liste par catégorie')),
      body: ZTabbedList(
        isScrollable: true,
        tabs: <ZListTab>[
          ZListTab.category(
            labelKey: 'Toutes',
            filters: const <ZFilter>[],
            buildList: (context, filters) =>
                _CategoryList(store: store, categoryFilters: filters),
          ),
          for (final c in demoCategories)
            ZListTab.category(
              labelKey: c.label,
              filters: <ZFilter>[ZFilter('category', ZFilterOp.eq, c.value)],
              buildList: (context, filters) =>
                  _CategoryList(store: store, categoryFilters: filters),
            ),
        ],
      ),
    );
  }
}

/// Vue d'un onglet : possède SON [ZListController] (seedé de `baseFilters` de
/// catégorie) et SA sélection — état préservé par le keep-alive de `ZTabbedList`.
class _CategoryList extends StatefulWidget {
  const _CategoryList({required this.store, required this.categoryFilters});

  final DemoStore store;
  final List<ZFilter> categoryFilters;

  @override
  State<_CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<_CategoryList> {
  late final DemoRepository _repo;
  late final ZListController<DemoRecord> _controller;
  late final ZListSelectionController _selection;

  @override
  void initState() {
    super.initState();
    _repo = DemoRepository(widget.store);
    _controller = ZListController<DemoRecord>(
      repository: _repo,
      toRow: toDemoRow,
      schema: demoSchema,
      pageSize: _demoPageSize,
      baseFilters: widget.categoryFilters,
      watchMutations: true,
    );
    _selection = ZListSelectionController();
  }

  @override
  void dispose() {
    _selection.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ValueListenableBuilder<ZListViewState>(
            valueListenable: _controller.state,
            builder: (context, state, _) => DynamicList<DemoRecord>(
              fields: demoSchema,
              state: state,
              columnPolicy: const ZColumnPolicy(),
              selection: _selection,
            ),
          ),
        ),
        // AC4(d) : pagination curseur navigable aussi dans l'onglet « Toutes ».
        _LoadMoreBar(controller: _controller),
      ],
    );
  }
}
