/// Widget de la **famille sous-liste** (`subItems`) — E3-3b-2 : **mini-CRUD
/// imbriqué** (POINT DE VIGILANCE AD-2 N°1).
///
/// Édite une `List<Map<String, dynamic>>` d'items : **ajouter**, **supprimer**,
/// **réordonner**. Chaque item est édité par un **sous-formulaire imbriqué** —
/// un `ZFormController` PROPRE à l'item (slice imbriqué) réutilisant le
/// dispatcher `ZFieldWidget`.
///
/// **SM-1 IMBRIQUÉ (AD-2, OBJECTIF PRODUIT N°1)** — invariants NON-NÉGOCIABLES :
/// - **Le conteneur écoute un canal STRUCTUREL** (add/remove/reorder — géré par
///   `setState` local), **jamais la valeur des sous-champs**. Taper dans un champ
///   d'un item ne reconstruit QUE ce champ (via le `ZFieldListenableBuilder` du
///   `ZFieldWidget` imbriqué) — **PAS** le conteneur, **PAS** les autres items,
///   **PAS** le formulaire racine.
/// - **La tranche parente est agrégée hors de la voie de rebuild** : ce widget
///   est monté par `ZFieldWidget` **AVANT** la souscription à la tranche parente
///   (comme `hidden`/`unsupported`) → écrire la `List` agrégée via `onChanged`
///   (→ `setValue` parent) **ne reconstruit pas** ce conteneur. L'agrégation est
///   déclenchée par un listener sur chaque slice imbriqué (canal de valeur), qui
///   écrit la `List` sans jamais reconstruire le conteneur.
/// - **Place stable par item** : chaque item est enveloppé dans
///   `KeyedSubtree(ValueKey(itemId))` (identité stable) → un réordonnancement ou
///   un retrait **ne vole/ne perd pas** l'état/focus des voisins. Le
///   `ZFormController` d'un item retiré est **`dispose`** (aucune fuite).
/// - **Aucun `setState` de niveau formulaire, aucun `Form`/`FormBuilder`
///   global** : la granularité imbriquée réutilise INTÉGRALEMENT la machinerie
///   E3 (dispatcher + tranches).
///
/// **Frontière E4-5** : ce widget est le **champ d'édition imbriqué** (dans un
/// formulaire) ; l'**écran de sous-liste autonome** (mini-CRUD plein écran,
/// `ZSubListScreen`) reste **E4-5** — non dupliqué ici. Le sous-schéma `const`
/// ([ZSubListConfig.itemFields]) est la brique commune réutilisable.
///
/// a11y/RTL (AD-13) : boutons add/remove/monter/descendre = `IconButton`
/// (cibles ≥ 48 dp) + `Semantics`/tooltips ; insets **directionnels** ; aucune
/// couleur codée en dur (bordure dérivée du `ZcrudTheme` — FR-26).
///
/// **DP-6 (parité DODLP, gap B8)** — mode **compact** additif : lorsque
/// `config.displayMode == ZSubListDisplayMode.compact`, le widget rend une
/// **liste résumé** (une ligne/valeurs de résumé par item, jamais les sous-champs
/// éditables inline) + un **dialog d'édition PAR ITEM** (ajouter/consulter/
/// modifier/supprimer), chaque action **filtrée par `ZAcl`**. Le mode `inline`
/// (défaut) est **strictement préservé**. SM-1 dans le dialog : `ZFormController`
/// PROPRE, `ZFieldWidget` réutilisé, aucun `Form` global.
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../../domain/edition/z_sub_list_config.dart';
import '../../../domain/ports/z_acl.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import '../../z_form_controller.dart';
import '../z_field_widget.dart';

/// Seam (usage de test) : construit le widget d'édition d'un **sous-champ**
/// d'item, avec le contexte de l'item (`itemId`) pour instrumenter les compteurs
/// de rebuild imbriqués (preuve SM-1 imbriqué). À défaut : dispatcher
/// `ZFieldWidget`. Le type est public ; le **paramètre** qui le porte est
/// `@visibleForTesting` (production : toujours `null`).
typedef ZSubItemFieldBuilder = Widget Function(
  BuildContext context,
  ZFormController itemController,
  ZFieldSpec field,
  String itemId,
);

/// Seam de **présentation** (DP-6, AC12) : dérive un **titre/résumé** lisible
/// d'un item (`Map`) — titre du dialog d'édition et repli de résumé de ligne en
/// mode compact. Équivalent présentation de l'`itemTitleBuilder` DODLP. Vit en
/// couche widget (JAMAIS dans la config domaine — garde `domain_purity_test`).
typedef ZSubItemTitleBuilder = String Function(Map<String, dynamic> item);

/// Champ d'édition d'une **sous-liste** d'items (`List<Map>` en tranche parente).
class ZSubListFieldWidget extends StatefulWidget {
  /// Construit le champ sous-liste pour [field], valeur initiale [initialValue]
  /// (`List<Map>` ou `null`), agrégeant vers la tranche parente via [onChanged].
  ///
  /// DP-6 (additifs, rétro-compat) : [acl] filtre les actions du mode compact
  /// (défaut `const ZAllowAllAcl()` = permissif → zéro régression) ;
  /// [collectionId] est transmis à `ZAcl.can(..., collectionId:)` ;
  /// [itemTitleBuilder] dérive le titre du dialog / résumé de ligne. Ces
  /// paramètres sont **ignorés** en mode `inline` (comportement E3-3b-2 inchangé).
  const ZSubListFieldWidget({
    required this.field,
    required this.initialValue,
    required this.onChanged,
    this.itemFieldBuilder,
    this.acl = const ZAllowAllAcl(),
    this.collectionId,
    this.itemTitleBuilder,
    super.key,
  });

  /// Spécification `const` du champ rendu (`config` = [ZSubListConfig]).
  final ZFieldSpec field;

  /// Valeur INITIALE de la tranche parente (`List<Map>` ou `null`) — lue **une
  /// fois** pour amorcer les sous-contrôleurs. La suite est gouvernée par l'état
  /// imbriqué (le conteneur ne re-souscrit PAS à la tranche parente).
  final Object? initialValue;

  /// Notifié avec la `List<Map<String, dynamic>>` agrégée à chaque mutation
  /// (structurelle OU valeur d'un sous-champ) — branché sur `setValue` parent.
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  /// Seam de test (voir [ZSubItemFieldBuilder]) ; `null` en production.
  @visibleForTesting
  final ZSubItemFieldBuilder? itemFieldBuilder;

  /// Port d'autorisation (DP-6) consommé **uniquement** en mode compact pour
  /// filtrer add/view/edit/delete. Défaut permissif (`const ZAllowAllAcl()`).
  final ZAcl acl;

  /// Discriminant de collection transmis à [ZAcl.can] (DP-6). `null` par défaut.
  final String? collectionId;

  /// Seam de titre d'item (DP-6, AC12), mode compact. `null` → titre dérivé des
  /// `summaryFields`/champs + libellé du champ.
  final ZSubItemTitleBuilder? itemTitleBuilder;

  @override
  State<ZSubListFieldWidget> createState() => _ZSubListFieldWidgetState();
}

/// Item imbriqué : identité **stable** ([id]) + sous-contrôleur imbriqué.
class _SubItem {
  _SubItem(this.id, this.controller);

  final String id;
  final ZFormController controller;

  /// DP-19 (M18) — soft-delete : `true` ⇒ item **marqué supprimé** (exclu de
  /// l'agrégation parent) mais conservé pour **restauration** en session.
  bool deleted = false;
}

class _ZSubListFieldWidgetState extends State<ZSubListFieldWidget> {
  /// Items imbriqués (source de vérité en édition ; agrégés vers le parent).
  final List<_SubItem> _items = <_SubItem>[];

  /// Compteur monotone d'identités d'items (clés stables, jamais réutilisées).
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    for (final data in _readList(widget.initialValue)) {
      _items.add(_makeItem(data));
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      _detach(item);
      item.controller.dispose();
    }
    super.dispose();
  }

  /// Sous-schéma `const` de l'item (vide si config absente/non conforme).
  List<ZFieldSpec> get _itemFields {
    final config = widget.field.config;
    return config is ZSubListConfig ? config.itemFields : const <ZFieldSpec>[];
  }

  bool get _reorderable {
    final config = widget.field.config;
    return config is ZSubListConfig ? config.reorderable : true;
  }

  /// Mode de rendu (DP-6) — `inline` (défaut) si config absente/non conforme.
  ZSubListDisplayMode get _displayMode {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.displayMode
        : ZSubListDisplayMode.inline;
  }

  /// Champs résumé du mode compact (DP-6) — vide si config absente/non conforme.
  List<String> get _summaryFields {
    final config = widget.field.config;
    return config is ZSubListConfig ? config.summaryFields : const <String>[];
  }

  /// DP-19 (M18) — soft-delete actif ? (défaut `false`, config absente/non conf.)
  bool get _softDelete {
    final config = widget.field.config;
    return config is ZSubListConfig && config.softDelete;
  }

  /// DP-19 (M18) — gabarits de création (vide si config absente/non conforme).
  List<ZSubListItemTemplate> get _creationTemplates {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.creationTemplates
        : const <ZSubListItemTemplate>[];
  }

  /// DP-19 (M19) — valeurs par défaut d'un nouvel item (vide si config absente).
  Map<String, Object?> get _defaultNewItem {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.defaultNewItem
        : const <String, Object?>{};
  }

  /// DP-19 (M19) — libellé du bouton de création (repli `addItem`).
  String _addLabel(BuildContext context) {
    final config = widget.field.config;
    final key = config is ZSubListConfig ? config.createNewTextKey : null;
    return label(context, key ?? 'addItem', fallback: label(context, 'addItem'));
  }

  /// Lecture **défensive** de la liste courante (`null`/type inattendu → `[]`).
  List<Map<String, dynamic>> _readList(Object? value) {
    if (value is List) {
      return <Map<String, dynamic>>[
        for (final e in value)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    }
    return const <Map<String, dynamic>>[];
  }

  _SubItem _makeItem(Map<String, dynamic> data) {
    final id = 'item_${_seq++}';
    final controller = ZFormController(
      initialValues: <String, Object?>{
        for (final f in _itemFields) f.name: data[f.name],
      },
      visibleFields: <String>[for (final f in _itemFields) f.name],
    );
    final item = _SubItem(id, controller);
    _attach(item);
    return item;
  }

  /// Attache le listener d'agrégation sur CHAQUE slice imbriqué. Un changement
  /// de valeur d'un sous-champ ne reconstruit PAS le conteneur (non souscrit à
  /// la tranche parente) — il se contente d'agréger vers le parent (SM-1
  /// imbriqué préservé).
  void _attach(_SubItem item) {
    for (final f in _itemFields) {
      item.controller.fieldListenable(f.name).addListener(_syncToParent);
    }
  }

  void _detach(_SubItem item) {
    for (final f in _itemFields) {
      item.controller.fieldListenable(f.name).removeListener(_syncToParent);
    }
  }

  /// Agrège l'état imbriqué en `List<Map>` et écrit la tranche parente. Appelé
  /// depuis un handler d'évènement (listener/bouton), JAMAIS pendant un `build`.
  void _syncToParent() {
    widget.onChanged(<Map<String, dynamic>>[
      // DP-19 (M18) : un item soft-deleted est EXCLU de l'agrégation parent
      // (retiré des données) mais conservé localement pour restauration.
      for (final item in _items)
        if (!item.deleted)
          <String, dynamic>{
            for (final f in _itemFields) f.name: item.controller.valueOf(f.name),
          },
    ]);
  }

  void _addItem() {
    setState(() {
      // DP-19 (M19) : amorce le nouvel item avec `defaultNewItem` (défensif).
      _items.add(_makeItem(Map<String, dynamic>.from(_defaultNewItem)));
    });
    _syncToParent();
  }

  void _removeAt(int index) {
    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
    });
    _detach(removed);
    removed.controller.dispose();
    _syncToParent();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
    });
    _syncToParent();
  }

  Widget _buildItemField(_SubItem item, ZFieldSpec field) {
    final custom = widget.itemFieldBuilder;
    if (custom != null) return custom(context, item.controller, field, item.id);
    return ZFieldWidget(controller: item.controller, field: field);
  }

  @override
  Widget build(BuildContext context) {
    // DP-6 / fp-5-1 : dispatch EXPLICITE par mode de rendu, décidé UNE FOIS au
    // build du conteneur (l'édition vit dans le dialog → pas de rebuild par
    // frappe). `switch` exhaustif SANS `default:` : un futur mode casse la
    // compilation → JAMAIS un repli silencieux vers `inline` (AC-B2).
    switch (_displayMode) {
      case ZSubListDisplayMode.compact:
        return _buildCompact(context);
      case ZSubListDisplayMode.tags:
        return _buildTags(context);
      case ZSubListDisplayMode.inline:
        return _buildInline(context);
    }
  }

  /// Rendu **inline** historique (E3-3b-2) — STRICTEMENT préservé (AC4/AC19).
  Widget _buildInline(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final removeLabel = label(context, 'removeItem');
    final upLabel = label(context, 'moveItemUp');
    final downLabel = label(context, 'moveItemDown');
    final readOnly = widget.field.readOnly;

    // fp-5-1 MED-1 (a11y) : le conteneur ne porte PAS `label:` — le `Text`
    // visible ci-dessous fournit déjà le nom accessible de la section. Un
    // `label:` sur le `Semantics(container:)` DOUBLERAIT l'annonce du lecteur
    // d'écran (deux nœuds « Items »). Le `container: true` conserve la frontière
    // sémantique (groupement) sans redoublement.
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(
              resolvedLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (var i = 0; i < _items.length; i++)
            KeyedSubtree(
              key: ValueKey<String>(_items[i].id),
              child: _SubItemCard(
                borderColor: theme.fieldBorderColor,
                radius: theme.radiusM,
                index: i,
                count: _items.length,
                reorderable: _reorderable && !readOnly,
                removable: !readOnly,
                removeLabel: removeLabel,
                upLabel: upLabel,
                downLabel: downLabel,
                onRemove: () => _removeAt(i),
                onMoveUp: () => _move(i, -1),
                onMoveDown: () => _move(i, 1),
                fields: <Widget>[
                  for (final f in _itemFields)
                    KeyedSubtree(
                      key: ValueKey<String>('${_items[i].id}/${f.name}'),
                      child: _buildItemField(_items[i], f),
                    ),
                ],
              ),
            ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: Text(_addLabel(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── DP-6 : mode compact (liste résumé + dialog par item) ──────────────────

  /// Représentation textuelle stable d'une valeur (`null`/vide → `''`, AD-10).
  static String _stringOf(Object? value) => value == null ? '' : '$value';

  /// Snapshot `Map` des valeurs courantes d'un item (lecture des tranches).
  Map<String, dynamic> _itemData(_SubItem item) => <String, dynamic>{
        for (final f in _itemFields) f.name: item.controller.valueOf(f.name),
      };

  /// Applique **défensivement** le seam de titre (AD-10 : un builder hôte qui
  /// throw ne fait jamais échouer le parent → repli `null`).
  String? _safeTitle(ZSubItemTitleBuilder builder, Map<String, dynamic> data) {
    try {
      return builder(data);
    } catch (_) {
      return null;
    }
  }

  /// Titre de résumé d'une ligne quand aucun `summaryFields` (AC8/AC12) :
  /// `itemTitleBuilder` s'il est fourni, sinon **concaténation lisible** des
  /// valeurs non nulles des `itemFields` (jamais un déballage éditable).
  String _defaultTitle(_SubItem item) {
    final data = _itemData(item);
    final builder = widget.itemTitleBuilder;
    if (builder != null) {
      final t = _safeTitle(builder, data);
      if (t != null && t.isNotEmpty) return t;
    }
    return <String>[
      for (final f in _itemFields)
        if (data[f.name] != null && _stringOf(data[f.name]).isNotEmpty)
          _stringOf(data[f.name]),
    ].join(' — ');
  }

  /// Titre du dialog d'édition (AC12) : `itemTitleBuilder(data)` s'il est fourni
  /// et non vide, sinon le libellé du champ.
  String _dialogTitle(BuildContext context, Map<String, dynamic> data) {
    final builder = widget.itemTitleBuilder;
    if (builder != null) {
      final t = _safeTitle(builder, data);
      if (t != null && t.isNotEmpty) return t;
    }
    return label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
  }

  /// Contenu résumé d'une ligne (mode compact) : les `summaryFields` en lecture
  /// (défilement horizontal encapsulé — AC6a) ou le titre dérivé (AC8).
  Widget _summaryCells(_SubItem item) {
    final summaryFields = _summaryFields;
    if (summaryFields.isNotEmpty) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final name in summaryFields)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 16, 0),
                child: Text(
                  _stringOf(item.controller.valueOf(name)),
                  textAlign: TextAlign.start,
                ),
              ),
          ],
        ),
      );
    }
    return Text(
      _defaultTitle(item),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
    );
  }

  /// Ouvre le dialog d'édition d'un item. `initial` amorce le `ZFormController`
  /// propre du dialog ; retourne le `Map` agrégé à la validation, `null` à
  /// l'annulation/consultation.
  Future<Map<String, dynamic>?> _showItemDialog(
    Map<String, dynamic> initial, {
    required bool readOnly,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _ZSubItemEditDialog(
        title: _dialogTitle(dialogContext, initial),
        itemFields: _itemFields,
        initial: initial,
        readOnly: readOnly,
        itemFieldBuilder: widget.itemFieldBuilder,
      ),
    );
  }

  /// AC9 : ajout via dialog. DP-19 (M19) : l'item est amorcé de `defaultNewItem`
  /// **fusionné** avec les [templateDefaults] d'un gabarit de création (M18) —
  /// les valeurs du gabarit priment. Item vide par défaut (rétro-compat DP-6).
  Future<void> _openAddDialog({
    Map<String, Object?> templateDefaults = const <String, Object?>{},
  }) async {
    final seed = <String, dynamic>{
      ..._defaultNewItem,
      ...templateDefaults,
    };
    final result = await _showItemDialog(seed, readOnly: false);
    if (!mounted || result == null) return;
    setState(() => _items.add(_makeItem(result)));
    _syncToParent();
  }

  /// AC10 : édition via dialog (remplace **à sa place** — identité stable
  /// conservée en réécrivant les tranches du contrôleur de l'item).
  Future<void> _openEditDialog(_SubItem item) async {
    final result = await _showItemDialog(_itemData(item), readOnly: false);
    if (!mounted || result == null) return;
    for (final f in _itemFields) {
      item.controller.setValue(f.name, result[f.name]);
    }
    setState(() {});
    _syncToParent();
  }

  /// AC11 : consultation (dialog `readOnly`, sans Enregistrer).
  Future<void> _openViewDialog(_SubItem item) async {
    await _showItemDialog(_itemData(item), readOnly: true);
  }

  /// AC13 : suppression avec **dialog de confirmation** puis retrait. DP-19
  /// (M18) : en mode `softDelete`, l'item est **marqué supprimé** (restaurable)
  /// au lieu d'être retiré définitivement.
  Future<void> _confirmDelete(_SubItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(label(dialogContext, 'confirmDeleteItem')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(label(dialogContext, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(label(dialogContext, 'delete')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (_softDelete) {
      setState(() => item.deleted = true);
      _syncToParent();
      return;
    }
    final index = _items.indexOf(item);
    if (index >= 0) _removeAt(index);
  }

  /// DP-19 (M18) : restaure un item soft-deleted (réintègre l'agrégation parent).
  void _restore(_SubItem item) {
    setState(() => item.deleted = false);
    _syncToParent();
  }

  /// DP-19 (M18) : contrôle d'ajout — **menu** de gabarits de création si
  /// `creationTemplates` non vide (parité `popUpMenuOptions` DODLP), sinon simple
  /// bouton `+` (rétro-compat DP-6). Chaque gabarit pré-remplit le dialog.
  Widget _buildAddControl(BuildContext context) {
    final templates = _creationTemplates;
    if (templates.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.add),
        tooltip: _addLabel(context),
        onPressed: () => _openAddDialog(),
      );
    }
    return PopupMenuButton<int>(
      icon: const Icon(Icons.add),
      tooltip: _addLabel(context),
      onSelected: (i) =>
          _openAddDialog(templateDefaults: templates[i].defaults),
      itemBuilder: (context) => <PopupMenuEntry<int>>[
        for (var i = 0; i < templates.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(label(context, templates[i].labelKey,
                fallback: templates[i].labelKey)),
          ),
      ],
    );
  }

  /// Rendu **compact** (DP-6) : en-tête + liste résumé keyée + actions gated ACL.
  Widget _buildCompact(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final readOnly = widget.field.readOnly;
    final cid = widget.collectionId;
    final canCreate =
        !readOnly && widget.acl.can(ZCrudAction.create, collectionId: cid);
    final canView = widget.acl.can(ZCrudAction.view, collectionId: cid);
    final canUpdate =
        !readOnly && widget.acl.can(ZCrudAction.update, collectionId: cid);
    final canDelete =
        !readOnly && widget.acl.can(ZCrudAction.delete, collectionId: cid);

    // fp-5-1 MED-1 (a11y) : pas de `label:` sur le conteneur — le `Text` visible
    // (en-tête) porte déjà le nom de section ; un `label:` doublerait l'annonce.
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    resolvedLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.start,
                  ),
                ),
                if (canCreate) _buildAddControl(context),
              ],
            ),
          ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
              child: Text(
                label(context, 'noItems'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.start,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return KeyedSubtree(
                  key: ValueKey<String>(item.id),
                  child: _CompactRow(
                    borderColor: theme.fieldBorderColor,
                    radius: theme.radiusM,
                    summary: _summaryCells(item),
                    deleted: item.deleted,
                    canView: canView,
                    canUpdate: canUpdate,
                    canDelete: canDelete,
                    viewLabel: label(context, 'viewItem'),
                    editLabel: label(context, 'editItem'),
                    deleteLabel: label(context, 'deleteItem'),
                    restoreLabel: label(context, 'restoreItem'),
                    deletedBadge: label(context, 'deletedItemBadge'),
                    onView: () => _openViewDialog(item),
                    onEdit: () => _openEditDialog(item),
                    onDelete: () => _confirmDelete(item),
                    onRestore: () => _restore(item),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── fp-5-1 (AD-52) : mode tags (rangée de puces `InputChip`, minimal) ──────

  /// Rendu **tags** (fp-5-1) : rendu natif **MINIMAL** zéro-dépendance — une
  /// rangée `Wrap` de `InputChip` présentant le **résumé** de chaque item
  /// (`summaryFields`/repli titre), plus un bouton d'ajout (≥ 48 dp) réutilisant
  /// la machinerie de dialog existante (`_buildAddControl` → `_openAddDialog`).
  /// Tapoter une puce ouvre le dialog d'édition (consultation si `readOnly`) ;
  /// la puce est supprimable (`onDeleted` → `_confirmDelete`, gère softDelete).
  /// Directionnel (`Wrap` suit `Directionality`, `EdgeInsetsDirectional`),
  /// `Semantics` explicites, aucune couleur codée en dur (thème hérité, FR-26).
  /// Les **tags riches** (toggle/icône par tag, réordonnancement drag) = fp-5-2.
  Widget _buildTags(BuildContext context) {
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final readOnly = widget.field.readOnly;
    final removeLabel = label(context, 'removeItem');
    // Items visibles : les items soft-deleted sont EXCLUS (cohérent avec
    // l'agrégation parent) ; le rendu minimal ne porte pas la restauration
    // (offerte par le mode compact / fp-5-2).
    final visible = <_SubItem>[
      for (final item in _items)
        if (!item.deleted) item,
    ];

    // fp-5-1 MED-1 (a11y) : pas de `label:` sur le conteneur — le `Text` visible
    // (en-tête) porte déjà le nom de section ; un `label:` doublerait l'annonce.
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    resolvedLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.start,
                  ),
                ),
                if (!readOnly) _buildAddControl(context),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final item in visible)
                  InputChip(
                    key: ValueKey<String>('tag_${item.id}'),
                    label: Text(_chipLabel(item)),
                    // fp-5-1 MED-2 (AD-13) : épingle la cible tactile à `padded`
                    // (≥ 48 dp) INDÉPENDAMMENT du thème ambiant — sinon un thème
                    // `materialTapTargetSize: shrinkWrap` ferait tomber la puce
                    // (et son `onDeleted`) sous 48 dp.
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: readOnly
                        ? () => _openViewDialog(item)
                        : () => _openEditDialog(item),
                    onDeleted: readOnly ? null : () => _confirmDelete(item),
                    deleteButtonTooltipMessage: readOnly ? null : removeLabel,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Libellé lisible d'une puce (fp-5-1) : résumé dérivé (`summaryFields`/titre)
  /// ou, à défaut, le libellé du champ (jamais une puce vide/illisible).
  String _chipLabel(_SubItem item) {
    final summaryFields = _summaryFields;
    if (summaryFields.isNotEmpty) {
      final parts = <String>[
        for (final name in summaryFields)
          if (_stringOf(item.controller.valueOf(name)).isNotEmpty)
            _stringOf(item.controller.valueOf(name)),
      ];
      if (parts.isNotEmpty) return parts.join(' — ');
    }
    final title = _defaultTitle(item);
    if (title.isNotEmpty) return title;
    return label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
  }
}

/// Ligne résumé d'un item en mode **compact** (DP-6) : résumé + actions de fin
/// de ligne accessibles (`IconButton` ≥ 48 dp, tooltips l10n), gated ACL en
/// amont (rendues conditionnellement). Bordure dérivée du thème (FR-26).
class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.borderColor,
    required this.radius,
    required this.summary,
    required this.deleted,
    required this.canView,
    required this.canUpdate,
    required this.canDelete,
    required this.viewLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.restoreLabel,
    required this.deletedBadge,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final Color? borderColor;
  final Radius radius;
  final Widget summary;

  /// DP-19 (M18) : item soft-deleted → résumé barré + badge + action restaurer.
  final bool deleted;
  final bool canView;
  final bool canUpdate;
  final bool canDelete;
  final String viewLabel;
  final String editLabel;
  final String deleteLabel;
  final String restoreLabel;
  final String deletedBadge;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    // Résumé barré en état soft-deleted (a11y : badge textuel explicite).
    final summaryContent = deleted
        ? Row(
            children: <Widget>[
              Flexible(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                      decoration: TextDecoration.lineThrough),
                  child: summary,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                child: Text(deletedBadge,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.start),
              ),
            ],
          )
        : summary;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: borderColor == null ? null : Border.all(color: borderColor!),
          borderRadius: BorderRadius.all(radius),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
          child: Row(
            children: <Widget>[
              Expanded(child: summaryContent),
              // Item soft-deleted : seule l'action **restaurer** est offerte.
              if (deleted)
                IconButton(
                  icon: const Icon(Icons.restore_from_trash),
                  tooltip: restoreLabel,
                  onPressed: onRestore,
                )
              else ...<Widget>[
                if (canView)
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    tooltip: viewLabel,
                    onPressed: onView,
                  ),
                if (canUpdate)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: editLabel,
                    onPressed: onEdit,
                  ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: deleteLabel,
                    onPressed: onDelete,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog d'édition PAR ITEM (DP-6, AC10/AC11) — héberge un `ZFormController`
/// **PROPRE** amorcé du `Map` de l'item et rend les sous-champs via le
/// dispatcher `ZFieldWidget` (réutilisation intégrale d'E3). **Aucun `Form`
/// global** (AD-2). Le contrôleur est `dispose` à la fermeture (aucune fuite).
/// SM-1 : taper dans un sous-champ ne reconstruit QUE ce champ (`ZFieldWidget`/
/// `ZFieldListenableBuilder`), jamais le dialog ni la liste résumé. En lecture
/// (`readOnly`) : chaque spec `copyWith(readOnly: true)`, pas de bouton
/// Enregistrer (seul **Fermer**).
class _ZSubItemEditDialog extends StatefulWidget {
  const _ZSubItemEditDialog({
    required this.title,
    required this.itemFields,
    required this.initial,
    required this.readOnly,
    this.itemFieldBuilder,
  });

  final String title;
  final List<ZFieldSpec> itemFields;
  final Map<String, dynamic> initial;
  final bool readOnly;
  final ZSubItemFieldBuilder? itemFieldBuilder;

  @override
  State<_ZSubItemEditDialog> createState() => _ZSubItemEditDialogState();
}

class _ZSubItemEditDialogState extends State<_ZSubItemEditDialog> {
  /// Contrôleur PROPRE au dialog (create/dispose) — jamais partagé avec le
  /// conteneur : taper ici n'affecte le parent qu'à **Enregistrer**.
  late final ZFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ZFormController(
      initialValues: <String, Object?>{
        for (final f in widget.itemFields) f.name: widget.initial[f.name],
      },
      visibleFields: <String>[for (final f in widget.itemFields) f.name],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildField(ZFieldSpec field) {
    final spec = widget.readOnly ? field.copyWith(readOnly: true) : field;
    final custom = widget.itemFieldBuilder;
    if (custom != null) {
      return custom(context, _controller, spec, 'dialog');
    }
    return ZFieldWidget(controller: _controller, field: spec);
  }

  void _save() {
    Navigator.of(context).pop(<String, dynamic>{
      for (final f in widget.itemFields) f.name: _controller.valueOf(f.name),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final f in widget.itemFields)
              KeyedSubtree(
                key: ValueKey<String>('dialog/${f.name}'),
                child: _buildField(f),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(label(context, widget.readOnly ? 'close' : 'cancel')),
        ),
        if (!widget.readOnly)
          TextButton(
            onPressed: _save,
            child: Text(label(context, 'save')),
          ),
      ],
    );
  }
}

/// Carte d'un item imbriqué : sous-formulaire + contrôles (retrait/réordo)
/// accessibles (`IconButton` ≥ 48 dp), bordure dérivée du thème (FR-26).
class _SubItemCard extends StatelessWidget {
  const _SubItemCard({
    required this.borderColor,
    required this.radius,
    required this.index,
    required this.count,
    required this.reorderable,
    required this.removable,
    required this.removeLabel,
    required this.upLabel,
    required this.downLabel,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.fields,
  });

  final Color? borderColor;
  final Radius radius;
  final int index;
  final int count;
  final bool reorderable;
  final bool removable;
  final String removeLabel;
  final String upLabel;
  final String downLabel;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: borderColor == null ? null : Border.all(color: borderColor!),
          borderRadius: BorderRadius.all(radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Column(children: fields)),
                if (reorderable)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: upLabel,
                    onPressed: index > 0 ? onMoveUp : null,
                  ),
                if (reorderable)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    tooltip: downLabel,
                    onPressed: index < count - 1 ? onMoveDown : null,
                  ),
                if (removable)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: removeLabel,
                    onPressed: onRemove,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
