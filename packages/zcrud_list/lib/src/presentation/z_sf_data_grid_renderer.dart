/// Backend `SfDataGrid` du port [ZListRenderer] — **SEULE arête Syncfusion** du
/// graphe zcrud (E4-1 → E4-4, AD-8/SM-5).
///
/// origine: E4-1. `zcrud_core` n'expose que l'abstraction `ZListRenderer` + les
/// modèles neutres Material-free ; le rendu concret Syncfusion vit
/// **exclusivement** ici, dans `zcrud_list`. Un consommateur qui n'importe pas
/// `zcrud_list` (ex. `zcrud_markdown` seul) ne tire donc AUCUNE dépendance
/// Syncfusion (SM-5, prouvé par les tests de graphe).
///
/// **Consomme les colonnes dérivées** (E4-2) : une `GridColumn` par `ZListColumn`
/// du `ZListRenderRequest`, en-tête résolu au rendu (`label(context, col.header)`),
/// largeur `col.width` (si non nulle), cellule via le **format neutre partagé**
/// `col.format(row.cells[col.name])`.
///
/// **L2 CORRIGÉ (E4-4, AC5)** : le renderer délègue à un `StatefulWidget`
/// (`_ZSfDataGrid`) qui **mémoïse** la `DataGridSource` (construite une fois,
/// **mise à jour en place** via `didUpdateWidget` — plus jamais recréée par
/// `build`) et détient un `DataGridController` **persistant**. La sélection
/// Syncfusion est liée **bidirectionnellement** à `ZListInteraction`
/// (init/sync depuis `selectedIds`, remontée via `onSelectionChanged`) et keyée
/// par l'`id` STABLE de `ZListRow`. Résultat : scroll & sélection **persistants**
/// au rebuild/scroll/pagination (bug historique des 3 apps corrigé). Les actions
/// de ligne **déjà résolues** (`interaction.actionsFor`) sont rendues dans une
/// colonne dédiée (le renderer ne voit ni `T` ni `ZAcl`).
///
/// **Aucune clé/licence Syncfusion committée** : l'enregistrement de licence
/// (`SyncfusionLicense.registerLicense`) est une **config plateforme de l'app**
/// hôte, jamais du package (Key Don'ts « never de secret dans un package »).
library;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Hauteur de ligne minimale (cible tactile ≥ 48 dp — AD-13).
const double _kMinRowHeight = 48;

/// Nom interne de la colonne d'actions (jamais un `field.name` réel).
const String _kActionsColumnName = '__zActions';

/// Backend concret rendant un [ZListRenderRequest] neutre en `SfDataGrid`.
///
/// `const`-constructible : injectable tel quel via
/// `ZcrudScope(listRenderer: const ZSfDataGridRenderer(), child: ...)`.
class ZSfDataGridRenderer implements ZListRenderer {
  /// Construit le renderer (sans état ; immuable).
  const ZSfDataGridRenderer();

  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) {
    return _ZSfDataGrid(request: request, interaction: interaction);
  }
}

/// Widget stateful portant la source **mémoïsée** + le `DataGridController`
/// **persistant** (L2, AC5). C'est lui qui immunise scroll/sélection contre les
/// rebuilds.
class _ZSfDataGrid extends StatefulWidget {
  const _ZSfDataGrid({required this.request, this.interaction});

  final ZListRenderRequest request;
  final ZListInteraction? interaction;

  @override
  State<_ZSfDataGrid> createState() => _ZSfDataGridState();
}

class _ZSfDataGridState extends State<_ZSfDataGrid> {
  late _ZListDataGridSource _source;
  final DataGridController _controller = DataGridController();
  bool _syncingSelection = false;

  bool get _hasActions => widget.interaction?.actionsFor != null;

  @override
  void initState() {
    super.initState();
    _source = _ZListDataGridSource(
      widget.request.columns,
      widget.request.rows,
      actionsFor: widget.interaction?.actionsFor,
    );
    _syncControllerFromInteraction();
  }

  @override
  void didUpdateWidget(_ZSfDataGrid old) {
    super.didUpdateWidget(old);
    final newActionsFor = widget.interaction?.actionsFor;
    final oldActionsFor = old.interaction?.actionsFor;
    // La PRÉSENCE d'actions (null ↔ non-null) modifie le nombre de cellules par
    // ligne (colonne d'actions) → reconstruction nécessaire.
    final actionsPresenceChanged =
        (newActionsFor != null) != (oldActionsFor != null);

    if (widget.request != old.request || actionsPresenceChanged) {
      // MISE À JOUR EN PLACE de la source mémoïsée (jamais recréée) quand les
      // DONNÉES (lignes/colonnes) — ou la présence d'actions — changent :
      // reconstruit les `DataGridRow` puis notifie la grille (AC5).
      _source.update(
        widget.request.columns,
        widget.request.rows,
        newActionsFor,
      );
    } else if (!identical(newActionsFor, oldActionsFor)) {
      // MEDIUM-1 (perf) : SEULE la closure `actionsFor` a changé d'identité
      // (recréée à chaque `build` de `DynamicList._buildInteraction`, ex. à
      // chaque changement de sélection) alors que les DONNÉES sont inchangées.
      // On RAFRAÎCHIT uniquement la référence de résolution SANS effacer /
      // reconstruire les `DataGridRow` (l'actions-cell est résolue
      // paresseusement dans `buildRow`) : cocher une case ne reconstruit plus
      // toute la source de grille (mémoïsation L2 préservée).
      _source.refreshActions(newActionsFor);
    }
    // Re-synchronise la sélection Syncfusion depuis l'état neutre (source de
    // vérité = `ZListInteraction.selectedIds`, keyé par `id`).
    _syncControllerFromInteraction();
  }

  SelectionMode get _selectionMode {
    switch (widget.interaction?.mode ?? ZListSelectionMode.none) {
      case ZListSelectionMode.none:
        return SelectionMode.none;
      case ZListSelectionMode.single:
        return SelectionMode.single;
      case ZListSelectionMode.multiple:
        return SelectionMode.multiple;
    }
  }

  /// Aligne `controller.selectedRows` sur `interaction.selectedIds` (keyé par
  /// `id`). Marqué `_syncingSelection` pour ne pas re-remonter ce changement
  /// programmatique comme une sélection utilisateur.
  void _syncControllerFromInteraction() {
    final interaction = widget.interaction;
    if (interaction == null || interaction.mode == ZListSelectionMode.none) {
      return;
    }
    final wanted = interaction.selectedIds;
    final rows = <DataGridRow>[
      for (final entry in _source.indexedRows)
        if (wanted.contains(entry.value.id)) entry.key,
    ];
    _syncingSelection = true;
    _controller.selectedRows = rows;
    _syncingSelection = false;
  }

  /// Remonte la sélection utilisateur (mappée `DataGridRow → id` stable) vers
  /// l'état neutre via `interaction.onSelectionChanged`.
  void _handleSelectionChanged(
    List<DataGridRow> addedRows,
    List<DataGridRow> removedRows,
  ) {
    if (_syncingSelection) return;
    final onChanged = widget.interaction?.onSelectionChanged;
    if (onChanged == null) return;
    final ids = <String>{
      for (final row in _controller.selectedRows)
        if (_source.idOf(row) case final String id) id,
    };
    onChanged(ids);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = <GridColumn>[
      for (final col in widget.request.columns)
        GridColumn(
          columnName: col.name,
          width: col.width ?? double.nan,
          label: Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label(context, col.header),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      if (_hasActions)
        GridColumn(
          columnName: _kActionsColumnName,
          label: const SizedBox.shrink(),
        ),
    ];

    return SfDataGrid(
      source: _source,
      controller: _controller,
      columns: columns,
      rowHeight: _kMinRowHeight,
      headerRowHeight: _kMinRowHeight,
      columnWidthMode: ColumnWidthMode.fill,
      gridLinesVisibility: GridLinesVisibility.horizontal,
      headerGridLinesVisibility: GridLinesVisibility.horizontal,
      selectionMode: _selectionMode,
      navigationMode: GridNavigationMode.row,
      onSelectionChanged: _handleSelectionChanged,
    );
  }
}

/// Source de données `SfDataGrid` **mémoïsée** (E4-4) mappant chaque [ZListRow]
/// vers une `DataGridRow` de cellules texte via le **format neutre partagé**
/// `col.format(row.cells[col.name])`. Une cellule d'actions (widgets déjà
/// résolus) est ajoutée si [_actionsFor] est fourni. Mise à jour **en place** via
/// [update] (jamais recréée par `build`, AC5).
class _ZListDataGridSource extends DataGridSource {
  _ZListDataGridSource(
    List<ZListColumn> columns,
    List<ZListRow> rows, {
    List<ZResolvedRowAction> Function(ZListRow row)? actionsFor,
  }) {
    update(columns, rows, actionsFor);
  }

  List<ZListColumn> _columns = const <ZListColumn>[];
  List<ZResolvedRowAction> Function(ZListRow row)? _actionsFor;

  final List<DataGridRow> _dataRows = <DataGridRow>[];
  // Association DataGridRow → ZListRow (identité) pour retrouver l'`id` stable et
  // l'entité d'origine sans encoder l'`id` dans une cellule visible.
  final Map<DataGridRow, ZListRow> _rowByData = <DataGridRow, ZListRow>{};

  bool get _hasActions => _actionsFor != null;

  @override
  List<DataGridRow> get rows => _dataRows;

  /// Paires (DataGridRow, ZListRow) dans l'ordre, pour la synchronisation de
  /// sélection keyée par `id`.
  Iterable<MapEntry<DataGridRow, ZListRow>> get indexedRows =>
      _rowByData.entries;

  /// Retrouve l'`id` stable d'une [row] Syncfusion (ou `null` si inconnue).
  String? idOf(DataGridRow row) => _rowByData[row]?.id;

  /// **Met à jour en place** la source (jamais recréée) : reconstruit les
  /// `DataGridRow` puis notifie la grille. Préserve l'instance (L2/AC5).
  void update(
    List<ZListColumn> columns,
    List<ZListRow> rows,
    List<ZResolvedRowAction> Function(ZListRow row)? actionsFor,
  ) {
    _columns = columns;
    _actionsFor = actionsFor;
    _dataRows.clear();
    _rowByData.clear();
    for (final row in rows) {
      final data = DataGridRow(
        cells: <DataGridCell>[
          for (final col in columns)
            DataGridCell<String>(
              columnName: col.name,
              value: col.format(row.cells[col.name]),
            ),
          if (_hasActions)
            const DataGridCell<String>(
              columnName: _kActionsColumnName,
              value: '',
            ),
        ],
      );
      _dataRows.add(data);
      _rowByData[data] = row;
    }
    notifyListeners();
  }

  /// MEDIUM-1 (perf) : met à jour SEULEMENT la closure de résolution d'actions,
  /// SANS reconstruire les `DataGridRow` ni notifier la grille. L'actions-cell
  /// est résolue paresseusement dans [buildRow] via [_actionsFor] : rafraîchir
  /// la référence suffit à ce que le prochain rendu naturel de ligne utilise la
  /// closure courante (contexte/ACL frais), sans effacer/reconstruire la source
  /// (préserve l'identité des lignes → aucun rebuild lourd sur un simple
  /// changement de sélection). PRÉCONDITION : la PRÉSENCE d'actions est
  /// inchangée (null ↔ non-null gérée par [update], car elle modifie le nombre
  /// de cellules par ligne).
  void refreshActions(
    List<ZResolvedRowAction> Function(ZListRow row)? actionsFor,
  ) {
    _actionsFor = actionsFor;
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final cells = <Widget>[
      for (final col in _columns)
        Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            _cellString(row, col.name),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
        ),
      if (_hasActions) _actionsCell(row),
    ];
    return DataGridRowAdapter(cells: cells);
  }

  Widget _actionsCell(DataGridRow row) {
    final source = _rowByData[row];
    final actions = source == null
        ? const <ZResolvedRowAction>[]
        : (_actionsFor?.call(source) ?? const <ZResolvedRowAction>[]);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        for (final action in actions) _ZSfRowActionButton(action: action),
      ],
    );
  }

  String _cellString(DataGridRow row, String columnName) {
    for (final cell in row.getCells()) {
      if (cell.columnName == columnName) return cell.value?.toString() ?? '';
    }
    return '';
  }
}

/// Bouton d'action accessible (AC9) rendu dans la colonne d'actions de la grille.
class _ZSfRowActionButton extends StatelessWidget {
  const _ZSfRowActionButton({required this.action});

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
