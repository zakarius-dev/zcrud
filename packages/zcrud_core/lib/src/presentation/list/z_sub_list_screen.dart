/// `ZSubListScreen<T>` — sous-liste d'entités **reliées à un parent** du cœur
/// `zcrud_core` (E4-5, étend FR-6 · AD-8/AD-16/AD-2/AD-15/SM-5).
///
/// origine: capacité « **sous-listes / relations** » du §4.2 du PRD (rattachée à
/// FR-6), dernière brique d'E4. Un **assembleur MINCE** : à partir d'un parent
/// (`parentField` + `parentId`) et d'un `ZRepository<T>` d'enfants, il construit
/// **UN** [ZListController] seedé d'un **filtre de relation PERSISTANT**
/// (`ZFilter(parentField, ZFilterOp.eq, parentId)` en `baseFilters`) et rend une
/// [DynamicList] **complète** — recherche / tri / pagination (E4-3) + actions de
/// ligne filtrées `ZAcl` / sélection / corbeille soft-delete-restore (E4-4). La
/// relation est **toujours ANDée** à toute recherche/tri/filtre utilisateur :
/// elle ne fuit JAMAIS vers d'autres parents (garantie `baseFilters`, E4-5).
///
/// **RÉUTILISE, ne réinvente pas** : toute la mécanique de liste vit déjà dans
/// `ZListController` (E4-3) + `DynamicList` (E4-2) + actions/`ZAcl`/sélection/
/// corbeille (E4-4) + renderer injecté (E4-1). Ce widget ne réimplémente NI
/// pagination, NI recherche, NI mapping, NI actions.
///
/// **Distinction E3-3b-2 (NE PAS confondre)** : E3-3b-2 est un **CHAMP d'édition
/// inline** (`ZSubListField`/`z_sub_list_field_widget.dart`, `ZSubListConfig`) qui
/// édite des **value-objects EMBARQUÉS** dans le document parent (add/remove/
/// reorder), vivant sous `presentation/edition/families/`. E4-5 est un
/// **ÉCRAN-LISTE** d'**entités DISTINCTES reliées** (`ZRepository` propre) filtrées
/// par une relation neutre — il ne l'importe ni ne le duplique.
///
/// **Frontière (STOP)** : l'implémentation Firestore réelle de la relation/
/// pagination/soft-delete = **E5** ; l'intégration dans un écran applicatif
/// (DODLP/lex_douane, navigation) = **E7/E8**. Ici : composition NEUTRE prouvée
/// via fakes.
///
/// **Neutre (SM-5/AD-2/AD-15)** : imports limités à `package:flutter/material.dart`
/// + types `zcrud_core`. AUCUN `package:syncfusion`, AUCUN `cloud_firestore`/
/// `firebase`/`hive`, AUCUN gestionnaire d'état. Le contrôleur est possédé dans le
/// `State` (create/dispose propre, AD-2).
library;

import 'package:flutter/material.dart';

import '../../domain/contracts/z_entity.dart';
import '../../domain/data/z_data_request.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/ports/z_repository.dart';
import '../l10n/z_localizations.dart';
import 'dynamic_list.dart';
import 'z_list_controller.dart';
import 'z_list_layout.dart';
import 'z_list_render_request.dart';
import 'z_list_renderer.dart';
import 'z_list_selection.dart';
import 'z_list_view_state.dart';
import 'z_row_action.dart';

/// Écran-liste d'entités `T` **reliées à un parent**, filtré en permanence par la
/// relation `parentField == parentId` (E4-5).
///
/// Construit et possède **un** [ZListController] (dans son `State`, cycle
/// create/dispose — AD-2) seedé de `baseFilters: [ZFilter(parentField, eq,
/// parentId)]`, écoute sa **seule** tranche `state` via `ValueListenableBuilder`
/// (rebuild ciblé) et rend une [DynamicList] complète. Un changement de
/// `parentField`/`parentId` (`didUpdateWidget`) recrée le contrôleur (nouvelle
/// relation = nouvelles données) **et vide la sélection** (collection différente,
/// AC8).
class ZSubListScreen<T extends ZEntity> extends StatefulWidget {
  /// Construit la sous-liste reliée.
  ///
  /// [repository] fournit les enfants (port neutre) ; [parentField] est le nom
  /// logique du champ de relation et [parentId] la valeur du parent (`Object`
  /// **opaque** — id composite possible) ; [toRow] projette `T → ZListRow` ;
  /// [schema] porte les champs (`searchable` + colonnes). [columns] restreint les
  /// colonnes affichées (défaut : [schema]). [layout] choisit la variante de vue
  /// (défaut `dataGrid` = renderer injecté ; `builder`/`custom` = rendu cœur, SM-5).
  /// [renderer] force un renderer explicite (sinon `ZcrudScope.listRenderer`).
  /// [pageSize] active la pagination curseur (défaut `null` = non paginé).
  /// [rowActions]/[entityFor]/[actionAclMode]/[collectionId] pilotent les actions
  /// de ligne filtrées `ZAcl` (E4-4) ; [selection] active la sélection multiple.
  /// [showSearch] (défaut `true`) affiche une barre de recherche câblée à
  /// `controller.setSearch`. [watchMutations] relance la requête à chaque mutation
  /// du repository.
  const ZSubListScreen({
    required this.repository,
    required this.parentField,
    required this.parentId,
    required this.toRow,
    required this.schema,
    this.columns,
    this.layout = const ZListDataGridLayout(),
    this.renderer,
    this.pageSize,
    this.rowActions,
    this.entityFor,
    this.actionAclMode = ZActionAclMode.hide,
    this.collectionId,
    this.selection,
    this.showSearch = true,
    this.watchMutations = false,
    super.key,
  });

  /// Source des enfants (port neutre, backend-agnostique).
  final ZRepository<T> repository;

  /// Nom logique du champ de relation parent→enfants (opaque).
  final String parentField;

  /// Valeur du parent (opaque, `Object` — id composite possible).
  final Object parentId;

  /// Projection `T → ZListRow` (via `toMap`/`ZFieldSpec`).
  final ZListRow Function(T entity) toRow;

  /// Schéma des champs (source de `searchable` + colonnes dérivées).
  final List<ZFieldSpec> schema;

  /// Colonnes affichées (défaut : [schema]).
  final List<ZFieldSpec>? columns;

  /// Variante de vue (défaut `ZListDataGridLayout`).
  final ZListLayout layout;

  /// Renderer explicite (sinon seam `ZcrudScope.listRenderer`).
  final ZListRenderer? renderer;

  /// Taille de page (curseur), ou `null` (non paginé).
  final int? pageSize;

  /// Actions de ligne génériques filtrées `ZAcl` (E4-4). Requiert [entityFor].
  final List<ZRowAction<T>>? rowActions;

  /// Résolveur `ZListRow → T?` (source du filtrage ACL row-level + `onInvoke`).
  final T? Function(ZListRow row)? entityFor;

  /// Mode de filtrage ACL des actions (défaut `hide`).
  final ZActionAclMode actionAclMode;

  /// Identifiant de collection optionnel passé à `ZAcl.can`.
  final String? collectionId;

  /// Contrôleur de sélection multiple neutre (E4-4). `null` = pas de sélection.
  final ZListSelectionController? selection;

  /// Affiche une barre de recherche câblée à `controller.setSearch` (défaut `true`).
  final bool showSearch;

  /// S'abonne aux mutations du repository pour relancer la requête (défaut `false`).
  final bool watchMutations;

  @override
  State<ZSubListScreen<T>> createState() => _ZSubListScreenState<T>();
}

class _ZSubListScreenState<T extends ZEntity> extends State<ZSubListScreen<T>> {
  late ZListController<T> _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  ZListController<T> _createController() => ZListController<T>(
        repository: widget.repository,
        toRow: widget.toRow,
        schema: widget.schema,
        pageSize: widget.pageSize,
        baseFilters: <ZFilter>[
          ZFilter(widget.parentField, ZFilterOp.eq, widget.parentId),
        ],
        watchMutations: widget.watchMutations,
      );

  @override
  void didUpdateWidget(covariant ZSubListScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changement de relation (nouveau parent) = collection DIFFÉRENTE (AC8) :
    // recréer le contrôleur (nouvelles données) ET vider la sélection persistante
    // par `id` (qui n'a plus de sens sur une autre collection). Un simple filtre/
    // recherche utilisateur (même relation) NE réinitialise PAS la sélection —
    // elle persiste par `id` (cohérent E4-4 ; résolution du report LOW-3).
    final relationChanged = oldWidget.parentField != widget.parentField ||
        oldWidget.parentId != widget.parentId;
    final repositoryChanged = !identical(oldWidget.repository, widget.repository);
    if (relationChanged || repositoryChanged) {
      _controller.dispose();
      _controller = _createController();
      widget.selection?.clearSelection();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ValueListenableBuilder<ZListViewState>(
      valueListenable: _controller.state,
      builder: (context, state, _) => DynamicList<T>(
        fields: widget.columns ?? widget.schema,
        state: state,
        layout: widget.layout,
        renderer: widget.renderer,
        rowActions: widget.rowActions,
        entityFor: widget.entityFor,
        actionAclMode: widget.actionAclMode,
        selection: widget.selection,
        collectionId: widget.collectionId,
      ),
    );
    if (!widget.showSearch) return list;
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SubListSearchBar(onChanged: _controller.setSearch),
        Expanded(child: list),
      ],
    );
  }
}

/// Barre de recherche neutre de la sous-liste : `TextField` accessible câblé à
/// `controller.setSearch`. Libellé/placeholder via le seam l10n `label` (aucune
/// chaîne codée en dur) ; primitives directionnelles (AD-13).
class _SubListSearchBar extends StatelessWidget {
  const _SubListSearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hint = label(context, 'search');
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Semantics(
        textField: true,
        label: hint,
        child: TextField(
          key: const ValueKey('zSubListSearch'),
          textAlign: TextAlign.start,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
      ),
    );
  }
}
