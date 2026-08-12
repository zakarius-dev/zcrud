/// `ZCrudScreen<T>` — écran CRUD **assemblé et déclaratif**.
///
/// La pièce qui prend une déclaration (`title` + `source`) et rend un écran
/// fonctionnel en câblant, une fois pour toutes, les briques publiques
/// existantes : `DynamicList`/`ZTabbedList` (rendu), `ZListController`
/// (recherche/tri/pagination), `ZRowAction` (actions de ligne gouvernées
/// `ZAcl`), `presentEdition`/`ZPresentationPolicy` (présentation du
/// formulaire), `DynamicEdition`/`ZFormController` (édition),
/// `ZRepository`/`ZDataRequest.deletedScope` (données et corbeille).
///
/// **Principe directeur** : tout ce qui est dérivable d'une déclaration
/// existante ne se redemande jamais — les champs et la projection en cellules
/// se dérivent du `ZcrudRegistry` (`kindOf<T>` → `fieldSpecsFor` /
/// `encode`), l'ACL du `ZcrudScope` ambiant, le mode de présentation du
/// breakpoint. Chaque dérivation reste **remplaçable** par un paramètre.
///
/// **Assemblage mince** : aucune logique qui n'existe pas déjà dans les
/// briques ; un consommateur qui a un cas particulier descend d'un cran
/// (utiliser `DynamicList` directement) sans rien perdre.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart'
    show ZFormWeight, ZPresentationPolicy, presentEdition;

import 'z_crud_source.dart';

/// Activation de la **corbeille** d'un [ZCrudScreen].
enum ZTrashMode {
  /// La corbeille est offerte dès que la source la supporte
  /// ([ZCrudSource.supportsTrash]) et que l'ACL l'autorise — défaut.
  auto,

  /// La corbeille n'existe pas : aucune bascule, aucune action de ligne
  /// soft-delete/restore — quel que soit le support de la source (journal
  /// immuable, référentiel en lecture seule).
  none,
}

/// Fabrique du **formulaire d'édition** d'une entité, voie d'échappement de
/// l'édition dérivée.
///
/// `initial == null` ⇒ création ; non-`null` ⇒ édition. [save] persiste via la
/// voie de sauvegarde de l'écran (`onSave` → `source.onSave` →
/// `repository.save`) puis rafraîchit la liste — le formulaire reste
/// responsable de **se fermer** (`Navigator.pop`) après un [save] réussi. En
/// cas d'échec de persistance, [save] lève un [StateError] portant le message
/// de la `ZFailure`.
typedef ZCrudEditionBuilder<T> = Widget Function(
  BuildContext context,
  T? initial,
  ZCrudSave<T> save,
);

/// Rendu d'une tuile de liste, voie d'échappement du rendu par défaut.
typedef ZCrudItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  List<ZListColumn> columns,
);

/// Écran CRUD assemblé : liste + recherche + création + édition + sauvegarde
/// + corbeille, à partir d'une déclaration.
///
/// Déclaration **minimale** (le type `T` est enregistré au `ZcrudRegistry`,
/// champs et cellules sont dérivés du schéma généré) :
///
/// ```dart
/// ZCrudScreen<Consignee>(
///   title: 'Consignataires',
///   source: ZCrudSource.repository(repo),
///   registry: registry,
/// )
/// ```
///
/// Tout est ensuite surchargeable : [listFields]/[formFields] (schémas),
/// [cellsOf] (projection), [acl] (sinon `ZcrudScope.acl` ambiant), [policy]
/// (présentation), [layout]/[itemBuilder] (rendu), [tabs] (onglets),
/// [editionBuilder] (formulaire complet), [onSave] (persistance).
///
/// ## Cas exprimables par déclaration
///
/// * `canCreate: false` — aucun bouton de création ;
/// * `trash: ZTrashMode.none` — aucune corbeille ;
/// * `readOnly: true` — consultation pure (ni création, ni édition, ni
///   corbeille) ;
/// * `ZCrudSource.items(rows)` **sans callbacks** — lecture seule effective.
class ZCrudScreen<T extends ZEntity> extends StatefulWidget {
  /// Construit l'écran assemblé — seuls [title] et [source] sont requis.
  const ZCrudScreen({
    required this.title,
    required this.source,
    this.registry,
    this.kind,
    this.listFields,
    this.formFields,
    this.cellsOf,
    this.acl,
    this.policy = const ZPresentationPolicy(),
    this.formWeight = ZFormWeight.light,
    this.layout,
    this.itemBuilder,
    this.tabs,
    this.header,
    this.canCreate = true,
    this.trash = ZTrashMode.auto,
    this.readOnly = false,
    this.searchEnabled = true,
    this.onSave,
    this.editionBuilder,
    this.defaultItemBuilder,
    this.rowActions,
    this.columnPolicy,
    this.collectionId,
    this.appBarActions = const <Widget>[],
    this.leading,
    this.actionAclMode = ZActionAclMode.hide,
    super.key,
  });

  /// Titre de l'écran — clé l10n ou littéral (résolu via `label(context, …)`,
  /// repli sur le littéral lui-même).
  final String title;

  /// Source de données déclarative (repository ou items + callbacks).
  final ZCrudSource<T> source;

  /// Registre de modèles servant la **dérivation** : champs
  /// (`fieldSpecsFor`), cellules (`encode`) et reconstruction d'entité
  /// (`decode`). `null` ⇒ [listFields] + [cellsOf] deviennent requis, et
  /// l'édition exige [editionBuilder].
  final ZcrudRegistry? registry;

  /// `kind` explicite du modèle — requis seulement quand `T` est enregistré
  /// sous **plusieurs** kinds (sinon `registry.kindOf<T>()` le résout seul).
  final String? kind;

  /// Schéma des colonnes de liste. `null` ⇒ dérivé du registre.
  final List<ZFieldSpec>? listFields;

  /// Schéma des champs du formulaire dérivé. `null` ⇒ dérivé du registre
  /// (champs `isId` exclus). Ignoré si [editionBuilder] est fourni.
  final List<ZFieldSpec>? formFields;

  /// Projection `T → cellules` (indexées par `field.name`). `null` ⇒ dérivée
  /// du registre (`encode`, clés persistées = noms de specs générées).
  final Map<String, Object?> Function(T item)? cellsOf;

  /// ACL de l'écran. `null` ⇒ l'ACL du `ZcrudScope` ambiant s'applique telle
  /// quelle ; non-`null` ⇒ posée par `ZcrudScope.derive` autour de la liste.
  final ZAcl? acl;

  /// Politique de présentation du formulaire (breakpoint → page/sheet/dialog).
  final ZPresentationPolicy policy;

  /// Poids du formulaire, critère de la politique de présentation.
  final ZFormWeight formWeight;

  /// Variante de vue de la liste. `null` ⇒ `ZListBuilderLayout` avec la tuile
  /// générique du paquet (ou [itemBuilder]).
  final ZListLayout? layout;

  /// Rendu d'une tuile (reçoit l'entité `T`). Ignoré si [layout] est fourni.
  final ZCrudItemBuilder<T>? itemBuilder;

  /// Onglets de catégorisation. Non-`null` ⇒ le corps est un `ZTabbedList`
  /// (chaque onglet possède sa vue) ; le bouton de création lit `canCreate`
  /// et `defaultItemBuilder` de l'**onglet actif**.
  final List<ZListTab>? tabs;

  /// Widget partagé posé au-dessus du corps (au-dessus de la barre d'onglets
  /// en mode [tabs]).
  final Widget? header;

  /// Autorise la création (défaut `true`). `false` ⇒ aucun bouton « + »,
  /// quelle que soit l'ACL.
  final bool canCreate;

  /// Activation de la corbeille (défaut [ZTrashMode.auto]).
  final ZTrashMode trash;

  /// Consultation pure (défaut `false`) : ni création, ni édition, ni
  /// corbeille — les actions de ligne fournies via [rowActions] restent
  /// rendues (elles appartiennent à l'app).
  final bool readOnly;

  /// Affiche la barre de recherche (défaut `true`). Sans effet en mode
  /// [tabs] (chaque onglet possède sa propre vue).
  final bool searchEnabled;

  /// Persistance de la sauvegarde, prioritaire sur `source.onSave` puis
  /// `repository.save`.
  final ZCrudSave<T>? onSave;

  /// Formulaire d'édition complet fourni par l'app — voie d'échappement de
  /// l'édition dérivée (`DynamicEdition` sur [formFields]).
  final ZCrudEditionBuilder<T>? editionBuilder;

  /// Fabrique de l'entité initiale d'une **création** (écran sans onglets, ou
  /// repli quand l'onglet actif n'en porte pas). `null` ⇒ le formulaire
  /// dérivé part de valeurs vides.
  final T Function()? defaultItemBuilder;

  /// Actions de ligne **supplémentaires** de l'app, ajoutées après les
  /// actions assemblées (édition, corbeille), filtrées par la même ACL.
  final List<ZRowAction<T>>? rowActions;

  /// Politique de colonnes (force include/exclude par nom).
  final ZColumnPolicy? columnPolicy;

  /// Identifiant de collection passé à `ZAcl.can` et `repository.save`.
  final String? collectionId;

  /// Boutons additionnels de l'`AppBar` (avant les boutons assemblés).
  final List<Widget> appBarActions;

  /// Widget de tête de l'`AppBar` (remplacé par le bouton de sortie en vue
  /// corbeille).
  final Widget? leading;

  /// Mode de filtrage ACL des actions de ligne (défaut : masquer).
  final ZActionAclMode actionAclMode;

  @override
  State<ZCrudScreen<T>> createState() => _ZCrudScreenState<T>();
}

class _ZCrudScreenState<T extends ZEntity> extends State<ZCrudScreen<T>> {
  /// Vue corbeille active.
  bool _trashView = false;

  /// Recherche courante (voie `items` uniquement — la voie repository passe
  /// par `ZListController.setSearch`).
  String _search = '';

  /// Index de l'onglet actif (mode [ZCrudScreen.tabs]) — possédé ici,
  /// synchronisé par `ZTabbedList.activeIndexNotifier`.
  final ValueNotifier<int> _activeTabIndex = ValueNotifier<int>(0);

  /// Index `row.id → entité` alimenté par la projection (source du filtrage
  /// ACL row-level et des handlers d'action).
  final Map<String, T> _entities = <String, T>{};

  ZListController<T>? _liveController;
  ZListController<T>? _trashController;

  @override
  void initState() {
    super.initState();
    final repo = widget.source.repository;
    if (repo != null) _liveController = _createController(repo);
  }

  @override
  void didUpdateWidget(covariant ZCrudScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final repo = widget.source.repository;
    if (!identical(oldWidget.source.repository, repo)) {
      _liveController?.dispose();
      _trashController?.dispose();
      _liveController = repo == null ? null : _createController(repo);
      _trashController = null;
      _entities.clear();
    }
  }

  @override
  void dispose() {
    _liveController?.dispose();
    _trashController?.dispose();
    _activeTabIndex.dispose();
    super.dispose();
  }

  // ── Dérivation registre ───────────────────────────────────────────────────

  /// `kind` effectif : [ZCrudScreen.kind], sinon résolu du registre
  /// (`kindOf<T>` — `StateError` actionnable si l'association est ambiguë).
  String? get _registryKind {
    final registry = widget.registry;
    if (registry == null) return null;
    return widget.kind ?? registry.kindOf<T>();
  }

  /// Schéma dérivé du registre pour le `kind` effectif, ou `null`.
  List<ZFieldSpec>? get _derivedSpecs {
    final registry = widget.registry;
    final kind = _registryKind;
    if (registry == null || kind == null) return null;
    final specs = registry.tryFieldSpecsFor(kind);
    return (specs == null || specs.isEmpty) ? null : specs;
  }

  /// Colonnes effectives de la liste (paramètre > dérivation).
  List<ZFieldSpec> get _listFields {
    final fields = widget.listFields ?? _derivedSpecs;
    if (fields == null) {
      throw ZScopeError(
        'ZCrudScreen<$T> : aucun schéma de liste. Fournissez `listFields`, ou '
        'un `registry` où $T est enregistré avec ses `fieldSpecs` '
        '(annotation @ZcrudModel + registrar généré appelé au bootstrap).',
      );
    }
    return fields;
  }

  /// Champs effectifs du formulaire dérivé (paramètre > dérivation, `isId`
  /// exclus de la dérivation).
  List<ZFieldSpec>? get _formFields {
    final explicit = widget.formFields;
    if (explicit != null) return explicit;
    final derived = _derivedSpecs;
    if (derived == null) return null;
    final editable = <ZFieldSpec>[
      for (final spec in derived)
        if (!spec.isId) spec,
    ];
    return editable.isEmpty ? null : editable;
  }

  /// Projection effective `T → cellules` (paramètre > dérivation `encode`).
  Map<String, Object?> Function(T item) get _cellsOf {
    final explicit = widget.cellsOf;
    if (explicit != null) return explicit;
    final registry = widget.registry;
    final kind = _registryKind;
    if (registry == null || kind == null) {
      throw ZScopeError(
        'ZCrudScreen<$T> : aucune projection en cellules. Fournissez '
        '`cellsOf`, ou un `registry` où $T est enregistré (la projection est '
        'alors dérivée de `registry.encode`).',
      );
    }
    return (T item) => Map<String, Object?>.of(registry.encode(kind, item));
  }

  // ── Capacités dérivées de la déclaration ──────────────────────────────────

  bool get _trashEnabled =>
      widget.trash == ZTrashMode.auto &&
      !widget.readOnly &&
      widget.source.supportsTrash;

  /// `true` si un chemin d'édition existe : formulaire fourni, ou dérivable
  /// (registre + schéma de formulaire) avec une voie de sauvegarde.
  bool get _editionAvailable {
    if (widget.readOnly || !widget.source.canWrite) return false;
    if (widget.editionBuilder != null) return true;
    return widget.registry != null &&
        _registryKind != null &&
        _formFields != null;
  }

  ZAcl _effectiveAcl(BuildContext context) =>
      widget.acl ?? ZcrudScope.maybeOf(context)?.acl ?? const ZAllowAllAcl();

  // ── Persistance ───────────────────────────────────────────────────────────

  /// Persiste [entity] par la voie déclarée (`onSave` → `source.onSave` →
  /// `repository.save`), rend la `ZFailure` en cas d'échec (`null` = succès),
  /// et rafraîchit la liste après un succès. Jamais d'exception (AD-10/AD-11) :
  /// un callback hôte qui lève est replié en `ZDomainFailure`.
  Future<ZFailure?> _persist(T entity) async {
    final custom = widget.onSave ?? widget.source.onSave;
    if (custom != null) {
      try {
        await custom(entity);
      } catch (error) {
        return ZDomainFailure('$error');
      }
      _refresh();
      return null;
    }
    final repo = widget.source.repository;
    if (repo == null) {
      return const ZDomainFailure(
        'ZCrudScreen : aucune voie de sauvegarde (ni onSave, ni repository).',
      );
    }
    final result = await repo.save(entity, collectionId: widget.collectionId);
    return result.fold(
      (failure) => failure,
      (_) {
        _refresh();
        return null;
      },
    );
  }

  /// Relance les requêtes des contrôleurs (voie repository) et re-rend la
  /// partition (voie items).
  void _refresh() {
    unawaited(_liveController?.refresh());
    unawaited(_trashController?.refresh());
    if (mounted) setState(() {});
  }

  // ── Édition ───────────────────────────────────────────────────────────────

  /// Ouvre le formulaire — création si [initial] est `null` ([seedValues]
  /// pré-remplit alors le formulaire dérivé : contexte d'onglet en `Map`).
  Future<void> _openEdition({T? initial, Map<String, Object?>? seedValues}) {
    final builder = widget.editionBuilder;
    if (builder != null) {
      return presentEdition<void>(
        context,
        policy: widget.policy,
        formWeight: widget.formWeight,
        builder: (ctx) => builder(ctx, initial, (T entity) async {
          final failure = await _persist(entity);
          if (failure != null) throw StateError(failure.message);
        }),
      );
    }
    final registry = widget.registry;
    final kind = _registryKind;
    final fields = _formFields;
    if (registry == null || kind == null || fields == null) {
      throw ZScopeError(
        'ZCrudScreen<$T> : aucune voie d\'édition. Fournissez '
        '`editionBuilder`, ou un `registry` où $T est enregistré avec ses '
        '`fieldSpecs` (le formulaire est alors dérivé via DynamicEdition).',
      );
    }
    final baseValues = <String, Object?>{
      if (initial != null) ...registry.encode(kind, initial),
      ...?seedValues,
    };
    return presentEdition<void>(
      context,
      policy: widget.policy,
      formWeight: widget.formWeight,
      builder: (_) => _ZCrudEditionForm(
        fields: fields,
        initialValues: baseValues,
        onSubmit: (values) async {
          final T entity;
          try {
            entity = registry.decode(kind, <String, dynamic>{
              ...baseValues,
              ...values,
            }) as T;
          } catch (error) {
            return ZDomainFailure('$error');
          }
          return _persist(entity);
        },
      ),
    );
  }

  /// Geste de création : hérite du contexte de l'onglet actif
  /// (`defaultItemBuilder` d'onglet : entité `T` ou `Map` de valeurs), sinon
  /// du [ZCrudScreen.defaultItemBuilder] de l'écran.
  Future<void> _create() {
    Object? seed;
    final tabs = widget.tabs;
    if (tabs != null && tabs.isNotEmpty) {
      final index = _activeTabIndex.value;
      if (index >= 0 && index < tabs.length) {
        seed = tabs[index].defaultItemBuilder?.call();
      }
    }
    seed ??= widget.defaultItemBuilder?.call();
    if (seed is T) return _openEdition(initial: seed);
    if (seed is Map<String, Object?>) return _openEdition(seedValues: seed);
    return _openEdition();
  }

  // ── Actions de ligne assemblées ───────────────────────────────────────────

  List<ZRowAction<T>>? _assembledRowActions() {
    final actions = <ZRowAction<T>>[];
    final repo = widget.source.repository;
    if (!_trashView) {
      if (_editionAvailable) {
        actions.add(
          ZRowAction<T>.edit(
            icon: Icons.edit_outlined,
            onInvoke: (context, entity) => _openEdition(initial: entity),
          ),
        );
      }
      if (_trashEnabled) {
        if (repo != null) {
          actions.add(
            ZRowAction<T>.softDelete(
              repo,
              icon: Icons.delete_outline,
              onSuccess: _refresh,
            ),
          );
        } else {
          final onSoftDelete = widget.source.onSoftDelete;
          if (onSoftDelete != null) {
            actions.add(
              ZRowAction<T>.softDeleteWith(
                icon: Icons.delete_outline,
                (context, entity) async {
                  await onSoftDelete(entity);
                  _refresh();
                },
              ),
            );
          }
        }
      }
    } else {
      if (repo != null) {
        actions.add(
          ZRowAction<T>.restore(
            repo,
            icon: Icons.restore_from_trash,
            onSuccess: _refresh,
          ),
        );
      } else {
        final onRestore = widget.source.onRestore;
        if (onRestore != null) {
          actions.add(
            ZRowAction<T>.restoreWith(
              icon: Icons.restore_from_trash,
              (context, entity) async {
                await onRestore(entity);
                _refresh();
              },
            ),
          );
        }
      }
    }
    actions.addAll(widget.rowActions ?? const []);
    return actions.isEmpty ? null : actions;
  }

  // ── Projection et contrôleurs ─────────────────────────────────────────────

  ZListRow _project(T item) {
    final id = item.id ?? ZListRow.ephemeralKey(identityHashCode(item));
    _entities[id] = item;
    return ZListRow(id: id, cells: _cellsOf(item));
  }

  ZListController<T> _createController(ZRepository<T> repo) =>
      ZListController<T>(
        repository: repo,
        toRow: _project,
        schema: _listFields,
        watchMutations: true,
      );

  ZListController<T> _ensureTrashController() {
    final existing = _trashController;
    if (existing != null) return existing;
    final repo = widget.source.repository!;
    final controller = _createController(_ZDeletedScopeRepository<T>(repo));
    _trashController = controller;
    return controller;
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────

  ZListLayout _effectiveLayout() {
    final layout = widget.layout;
    if (layout != null) return layout;
    final itemBuilder = widget.itemBuilder;
    return ZListBuilderLayout(
      itemBuilder: (context, row, columns) {
        if (itemBuilder != null) {
          final entity = _entities[row.id];
          if (entity == null) return const SizedBox.shrink();
          return itemBuilder(context, entity, columns);
        }
        return _ZCrudDefaultTile(row: row, columns: columns);
      },
    );
  }

  Widget _buildList(BuildContext context, ZListViewState state) {
    final list = DynamicList<T>(
      fields: _listFields,
      state: state,
      layout: _effectiveLayout(),
      columnPolicy: widget.columnPolicy,
      rowActions: _assembledRowActions(),
      entityFor: (row) => _entities[row.id],
      actionAclMode: widget.actionAclMode,
      collectionId: widget.collectionId,
    );
    final acl = widget.acl;
    if (acl == null) return list;
    // ACL d'écran : posée par dérivation du scope ambiant (les autres seams
    // sont hérités, jamais recopiés).
    return ZcrudScope.derive(context, acl: acl, child: list);
  }

  /// Corps « voie repository » : contrôleur (vivants ou corbeille) écouté sur
  /// sa seule tranche `state` (rebuild ciblé, AD-2).
  Widget _buildRepositoryBody(BuildContext context) {
    final controller =
        _trashView ? _ensureTrashController() : _liveController!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.searchEnabled)
          _ZCrudSearchBar(
            key: ValueKey<String>(
              _trashView ? 'zCrudSearchTrash' : 'zCrudSearchLive',
            ),
            onChanged: controller.setSearch,
          ),
        Expanded(
          child: ValueListenableBuilder<ZListViewState>(
            valueListenable: controller.state,
            builder: (context, state, _) => _buildList(context, state),
          ),
        ),
      ],
    );
  }

  /// Corps « voie items » : partition vivants/corbeille par le prédicat
  /// déclaré, puis recherche in-memory par le moteur du cœur.
  Widget _buildItemsBody(BuildContext context) {
    final items = widget.source.items ?? const <Never>[];
    final predicate = widget.source.isDeleted;
    final visible = <T>[
      for (final item in items)
        if (predicate == null || predicate(item) == _trashView) item,
    ];
    final rows = <ZListRow>[for (final item in visible) _project(item)];
    final page = zApplyListRequest(
      rows,
      ZDataRequest(search: _search.isEmpty ? null : _search),
      schema: _listFields,
    );
    final ZListViewState state;
    if (rows.isEmpty) {
      state = const ZListEmpty();
    } else if (page.rows.isEmpty) {
      state = const ZListNoResults();
    } else {
      state = ZListReady(page.rows);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.searchEnabled)
          _ZCrudSearchBar(
            key: ValueKey<String>(
              _trashView ? 'zCrudSearchTrash' : 'zCrudSearchLive',
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        Expanded(child: _buildList(context, state)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    // Mode onglets : le corps vivant est le ZTabbedList déclaré (chaque onglet
    // possède sa vue) ; la corbeille reste le listing assemblé de l'écran.
    if (widget.tabs != null && !_trashView) {
      return ZTabbedList(
        tabs: widget.tabs!,
        header: widget.header,
        activeIndexNotifier: _activeTabIndex,
      );
    }
    final body = widget.source.repository != null
        ? _buildRepositoryBody(context)
        : _buildItemsBody(context);
    final header = widget.header;
    if (header == null || _trashView) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[header, Expanded(child: body)],
    );
  }

  bool _createOffered(ZAcl acl, int activeTabIndex) {
    if (!widget.canCreate ||
        widget.readOnly ||
        _trashView ||
        !_editionAvailable) {
      return false;
    }
    final tabs = widget.tabs;
    if (tabs != null &&
        tabs.isNotEmpty &&
        activeTabIndex >= 0 &&
        activeTabIndex < tabs.length &&
        !tabs[activeTabIndex].canCreate) {
      return false;
    }
    return acl.can(ZCrudAction.create, collectionId: widget.collectionId);
  }

  bool _trashToggleOffered(ZAcl acl) =>
      _trashEnabled &&
      !_trashView &&
      (acl.can(ZCrudAction.restore, collectionId: widget.collectionId) ||
          acl.can(ZCrudAction.delete, collectionId: widget.collectionId));

  @override
  Widget build(BuildContext context) {
    final acl = _effectiveAcl(context);
    return Scaffold(
      appBar: AppBar(
        leading: _trashView
            ? IconButton(
                key: const ValueKey('zCrudTrashBack'),
                tooltip: label(context, 'back', fallback: 'Back'),
                onPressed: () => setState(() => _trashView = false),
                icon: const BackButtonIcon(),
              )
            : widget.leading,
        title: Text(
          _trashView
              ? label(context, 'trash', fallback: 'Trash')
              : label(context, widget.title),
        ),
        actions: <Widget>[
          ...widget.appBarActions,
          if (_trashToggleOffered(acl))
            IconButton(
              key: const ValueKey('zCrudTrashToggle'),
              tooltip: label(context, 'trash', fallback: 'Trash'),
              onPressed: () => setState(() => _trashView = true),
              icon: const Icon(Icons.delete),
            ),
          ValueListenableBuilder<int>(
            valueListenable: _activeTabIndex,
            builder: (context, activeTabIndex, _) =>
                _createOffered(acl, activeTabIndex)
                    ? IconButton(
                        key: const ValueKey('zCrudCreate'),
                        tooltip: label(context, 'create'),
                        onPressed: _create,
                        icon: const Icon(Icons.add),
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }
}

/// Décorateur **corbeille** d'un `ZRepository` : force
/// `ZDeletedScope.deletedOnly` sur toutes les lectures porteuses d'un
/// `ZDataRequest` — c'est lui qui fait du `ZListController` (qui ne connaît
/// pas les portées de suppression) un listing de corbeille, avec recherche et
/// pagination inchangées.
///
/// `watchAll` délègue tel quel (il ne sert que de **signal de mutation** à
/// `watchMutations`). Les écritures délèguent. [dispose] est un no-op : le
/// décorateur ne possède pas le dépôt décoré.
class _ZDeletedScopeRepository<T extends ZEntity> implements ZRepository<T> {
  _ZDeletedScopeRepository(this._inner);

  final ZRepository<T> _inner;

  ZDataRequest _scoped(ZDataRequest? request) =>
      (request ?? const ZDataRequest())
          .copyWith(deletedScope: ZDeletedScope.deletedOnly);

  @override
  Future<ZResult<List<T>>> getAll({ZDataRequest? request}) =>
      _inner.getAll(request: _scoped(request));

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) =>
      _inner.count(request: _scoped(request));

  @override
  Stream<List<T>> watch(ZDataRequest request) => _inner.watch(_scoped(request));

  @override
  Stream<List<T>> watchAll() => _inner.watchAll();

  @override
  Future<ZResult<T>> getById(String id) => _inner.getById(id);

  @override
  Future<ZResult<T>> save(T item, {String? collectionId}) =>
      _inner.save(item, collectionId: collectionId);

  @override
  Future<ZResult<Unit>> softDelete(String id) => _inner.softDelete(id);

  @override
  Future<ZResult<Unit>> restore(String id) => _inner.restore(id);

  @override
  void dispose() {
    // No-op : le dépôt décoré appartient à l'appelant.
  }
}

/// Barre de recherche assemblée : `TextField` accessible câblé au contrôleur
/// de la vue courante. Libellé via le seam l10n, primitives directionnelles.
class _ZCrudSearchBar extends StatelessWidget {
  const _ZCrudSearchBar({required this.onChanged, super.key});

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
          key: const ValueKey('zCrudSearch'),
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

/// Tuile générique par défaut : première colonne en titre, colonnes suivantes
/// en sous-titre `en-tête : valeur formatée` (formats du cœur —
/// `ZListColumn.format`).
class _ZCrudDefaultTile extends StatelessWidget {
  const _ZCrudDefaultTile({required this.row, required this.columns});

  final ZListRow row;
  final List<ZListColumn> columns;

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty) return const SizedBox.shrink();
    final first = columns.first;
    final rest = columns.skip(1).toList(growable: false);
    return ListTile(
      key: ValueKey<String>('zCrudTile_${row.id}'),
      title: Text(first.format(row.cells[first.name])),
      subtitle: rest.isEmpty
          ? null
          : Text(
              <String>[
                for (final column in rest)
                  '${column.header} : ${column.format(row.cells[column.name])}',
              ].join(' · '),
            ),
    );
  }
}

/// Formulaire d'édition **dérivé** : possède son `ZFormController` (cycle
/// create/dispose — AD-2), rend un `DynamicEdition` sur les specs dérivées et
/// un pied enregistrer/annuler. L'échec de persistance est affiché **dans**
/// la surface (`Semantics` liveRegion), jamais levé (AD-10).
class _ZCrudEditionForm extends StatefulWidget {
  const _ZCrudEditionForm({
    required this.fields,
    required this.initialValues,
    required this.onSubmit,
  });

  final List<ZFieldSpec> fields;
  final Map<String, Object?> initialValues;
  final Future<ZFailure?> Function(Map<String, Object?> values) onSubmit;

  @override
  State<_ZCrudEditionForm> createState() => _ZCrudEditionFormState();
}

class _ZCrudEditionFormState extends State<_ZCrudEditionForm> {
  late final ZFormController _controller = ZFormController(
    initialValues: widget.initialValues,
    visibleFields: <String>[for (final f in widget.fields) f.name],
  );

  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _controller.dispose();
    _error.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy.value) return;
    _busy.value = true;
    _error.value = null;
    final values = <String, Object?>{
      ...widget.initialValues,
      ..._controller.values,
    };
    final failure = await widget.onSubmit(values);
    if (!mounted) return;
    _busy.value = false;
    if (failure == null) {
      Navigator.of(context).pop();
    } else {
      _error.value = failure.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: DynamicEdition(
              controller: _controller,
              fields: widget.fields,
              shrinkWrap: true,
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _error,
            builder: (context, message, _) => message == null
                ? const SizedBox.shrink()
                : Semantics(
                    liveRegion: true,
                    container: true,
                    label: message,
                    child: Padding(
                      padding:
                          const EdgeInsetsDirectional.only(top: 8, bottom: 8),
                      child: Text(
                        message,
                        key: const ValueKey('zCrudFormError'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                child: TextButton(
                  key: const ValueKey('zCrudFormCancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(label(context, 'cancel')),
                ),
              ),
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _busy,
                  builder: (context, busy, _) => FilledButton(
                    key: const ValueKey('zCrudFormSave'),
                    onPressed: busy ? null : _submit,
                    child: Text(label(context, 'save')),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
