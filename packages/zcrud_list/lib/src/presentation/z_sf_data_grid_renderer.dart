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
/// **CR-LIST-PARITY (Lot 5 + réserves §2, 2026-08-11)** — additif, opt-in,
/// **zéro changement de défaut** (AD-10) :
/// - [ZSfDataGridRenderer.onLoadMore] : auto-`loadMore` au scroll (infinite
///   scrolling natif Syncfusion, `SfDataGrid.loadMoreViewBuilder` — déclenché
///   quand le scroll vertical atteint la fin). `null` (défaut) ⇒ AUCUN
///   `loadMoreViewBuilder` posé, widget-tree strictement identique à avant. Le
///   câblage à `ZListController.loadMore()` (chemin `backendCursor`) est
///   **hôte** : ce package ne connaît pas le contrôleur (SM-5, `DynamicList` ne
///   le porte pas non plus jusqu'au renderer).
/// - [ZSfDataGridRenderer.headerRowHeight] / [ZSfDataGridRenderer.columnWidthMode]
///   / [ZSfDataGridRenderer.withOrderNumber] / [ZSfDataGridRenderer.orderColumnHeader]
///   / [ZSfDataGridRenderer.cellColorBuilder] : réglages Syncfusion aujourd'hui
///   figés (§2 du CR), désormais des paramètres nommés **optionnels** à défaut
///   strictement identique au rendu actuel (48 dp / `fill` / pas de colonne
///   d'ordre / pas de couleur de cellule).
///
/// `setCellColor`/`withOrderNumber` légataires opèrent sur des types Syncfusion
/// bruts (`DataGridRow`/`DataGridCell`) ; ici, [cellColorBuilder] est reçu sur les
/// types **neutres** [ZListRow]/[ZListColumn] déjà publics de `zcrud_core` — AUCUN
/// nouveau champ ni AUCUNE nouvelle arête n'est ajoutée à `zcrud_core` (ce
/// package les consomme tels quels).
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

/// Nom interne de la colonne de numéro d'ordre (jamais un `field.name` réel).
const String _kOrderColumnName = '__zOrder';

/// Backend concret rendant un [ZListRenderRequest] neutre en `SfDataGrid`.
///
/// `const`-constructible : injectable tel quel via
/// `ZcrudScope(listRenderer: const ZSfDataGridRenderer(), child: ...)`.
///
/// Tous les paramètres sont **additifs et opt-in** (CR-LIST-PARITY, Lot 5 + §2) :
/// omis, le rendu produit est **strictement identique** à la version antérieure
/// (mêmes valeurs Syncfusion codées en dur qu'avant ce correctif).
class ZSfDataGridRenderer implements ZListRenderer {
  /// Construit le renderer (sans état ; immuable).
  const ZSfDataGridRenderer({
    this.onLoadMore,
    this.headerRowHeight = _kMinRowHeight,
    this.columnWidthMode = ColumnWidthMode.fill,
    this.withOrderNumber = false,
    this.orderColumnHeader = '#',
    this.cellColorBuilder,
  });

  /// Auto-`loadMore` au scroll (Lot 5, MINEUR). `null` (défaut) : AUCUN
  /// `loadMoreViewBuilder` n'est posé sur le `SfDataGrid` — comportement
  /// STRICTEMENT identique à avant (aucun chemin n'appelait `loadMore()`).
  ///
  /// Non-`null` : Syncfusion déclenche ce callback quand le scroll vertical
  /// atteint la fin de la grille (infinite scrolling natif, pas de bouton) ; un
  /// indicateur de progression est affiché pendant l'attente. L'hôte le câble
  /// typiquement sur `ZListController.loadMore()`, **seulement** quand
  /// `controller.mode == ZListPaginationMode.backendCursor` (le contrôleur
  /// lui-même est un no-op sûr si aucune page suivante n'existe).
  final Future<void> Function()? onLoadMore;

  /// Hauteur de la ligne d'en-tête (§2 du CR : figée à 48 dp jusqu'ici).
  /// Défaut [_kMinRowHeight] (48 dp, AD-13) : valeur strictement inchangée.
  /// L'en-tête n'étant pas une cible tactile dans ce renderer (aucun tri par
  /// tap câblé), l'appelant reste libre d'y descendre sous 48 dp (parité
  /// legacy, ex. `headerRowHeight: 40`) sous sa propre responsabilité.
  final double headerRowHeight;

  /// Mode de répartition des largeurs de colonnes (§2 du CR : figé à `fill`
  /// jusqu'ici). Défaut [ColumnWidthMode.fill] : valeur strictement inchangée.
  final ColumnWidthMode columnWidthMode;

  /// Ajoute une colonne de numéro d'ordre (`#`) en tête de grille, parité
  /// `withOrderNumber` legacy (§2 du CR). Défaut `false` : aucune colonne
  /// ajoutée, comportement inchangé. Le numéro est le rang **d'affichage**
  /// (1-based, position dans `request.rows`) — identique à la sémantique
  /// legacy (`ids.indexOf(item) + 1`, elle aussi purement positionnelle).
  final bool withOrderNumber;

  /// En-tête de la colonne de numéro d'ordre quand [withOrderNumber] est actif.
  /// Défaut `'#'` (symbole ordinal universel, non language-dependent — parité
  /// littérale du legacy). Personnalisable par l'hôte (sa propre l10n) sans
  /// toucher `zcrud_core`.
  final String orderColumnHeader;

  /// Couleur de fond par cellule, résolue depuis les types **neutres** déjà
  /// publics de `zcrud_core` ([ZListRow] complet de la ligne + [ZListColumn]
  /// courante) — parité `setCellColor(DataGridRow, DataGridCell)` legacy (§2 du
  /// CR), SANS exposer de type Syncfusion à l'appelant ni ajouter de champ à
  /// `ZListColumn`/`ZListRow` (`zcrud_core` intact). Défaut `null` : aucune
  /// coloration, comportement inchangé. Ne doit jamais lever (AD-10) ; une
  /// exception de l'appelant est **propagée telle quelle** (pas de `try/catch`
  /// silencieux ici — l'appelant reste responsable de son builder).
  final Color? Function(ZListRow row, ZListColumn column)? cellColorBuilder;

  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) {
    return _ZSfDataGrid(
      request: request,
      interaction: interaction,
      onLoadMore: onLoadMore,
      headerRowHeight: headerRowHeight,
      columnWidthMode: columnWidthMode,
      withOrderNumber: withOrderNumber,
      orderColumnHeader: orderColumnHeader,
      cellColorBuilder: cellColorBuilder,
    );
  }
}

/// Widget stateful portant la source **mémoïsée** + le `DataGridController`
/// **persistant** (L2, AC5). C'est lui qui immunise scroll/sélection contre les
/// rebuilds.
class _ZSfDataGrid extends StatefulWidget {
  const _ZSfDataGrid({
    required this.request,
    this.interaction,
    this.onLoadMore,
    this.headerRowHeight = _kMinRowHeight,
    this.columnWidthMode = ColumnWidthMode.fill,
    this.withOrderNumber = false,
    this.orderColumnHeader = '#',
    this.cellColorBuilder,
  });

  final ZListRenderRequest request;
  final ZListInteraction? interaction;
  final Future<void> Function()? onLoadMore;
  final double headerRowHeight;
  final ColumnWidthMode columnWidthMode;
  final bool withOrderNumber;
  final String orderColumnHeader;
  final Color? Function(ZListRow row, ZListColumn column)? cellColorBuilder;

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
      withOrderNumber: widget.withOrderNumber,
      cellColorBuilder: widget.cellColorBuilder,
      onLoadMore: widget.onLoadMore,
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
    // La colonne d'ordre modifie elle aussi le nombre de cellules par ligne.
    final orderNumberChanged = widget.withOrderNumber != old.withOrderNumber;

    if (widget.request != old.request ||
        actionsPresenceChanged ||
        orderNumberChanged) {
      // MISE À JOUR EN PLACE de la source mémoïsée (jamais recréée) quand les
      // DONNÉES (lignes/colonnes) — ou la présence d'actions/colonne d'ordre —
      // changent : reconstruit les `DataGridRow` puis notifie la grille (AC5).
      _source.update(
        widget.request.columns,
        widget.request.rows,
        newActionsFor,
        withOrderNumber: widget.withOrderNumber,
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
    // `cellColorBuilder`/`onLoadMore` ne touchent ni le nombre ni l'identité des
    // `DataGridRow` : rafraîchi paresseusement, comme `actionsFor` (MEDIUM-1).
    if (!identical(widget.cellColorBuilder, old.cellColorBuilder)) {
      _source.refreshCellColorBuilder(widget.cellColorBuilder);
    }
    if (!identical(widget.onLoadMore, old.onLoadMore)) {
      _source.refreshOnLoadMore(widget.onLoadMore);
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
      if (widget.withOrderNumber)
        GridColumn(
          columnName: _kOrderColumnName,
          allowSorting: false,
          width: 56,
          label: Container(
            alignment: Alignment.center,
            child: Text(
              widget.orderColumnHeader,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
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
      headerRowHeight: widget.headerRowHeight,
      columnWidthMode: widget.columnWidthMode,
      gridLinesVisibility: GridLinesVisibility.horizontal,
      headerGridLinesVisibility: GridLinesVisibility.horizontal,
      selectionMode: _selectionMode,
      navigationMode: GridNavigationMode.row,
      onSelectionChanged: _handleSelectionChanged,
      loadMoreViewBuilder:
          widget.onLoadMore == null ? null : _buildLoadMoreView,
    );
  }

  /// `SfDataGrid.loadMoreViewBuilder` (Lot 5) : rendu quand le scroll vertical
  /// atteint la fin ET que [ZSfDataGridRenderer.onLoadMore] est fourni. Ne
  /// posé sur `SfDataGrid` QUE dans ce cas (`build`, ci-dessus) — un renderer
  /// par défaut (`onLoadMore == null`) ne voit jamais ce builder appelé.
  Widget? _buildLoadMoreView(BuildContext context, LoadMoreRows loadMoreRows) {
    return _ZAutoLoadMoreView(loadMoreRows: loadMoreRows);
  }
}

/// Vue "infinite scrolling" (Lot 5, CR-LIST-PARITY) : déclenche IMMÉDIATEMENT
/// [loadMoreRows] (pas de bouton — auto-`loadMore`, parité "seuil proche de
/// fin" via le seuil natif Syncfusion = fin de l'extent de scroll) et affiche un
/// indicateur de progression accessible pendant l'attente ; se réduit à une
/// hauteur nulle une fois la page intégrée. Réutilise la clé l10n `list.loading`
/// déjà enregistrée dans `zcrud_core` (AUCUNE nouvelle clé, ce package n'écrit
/// pas dans `zcrud_core`).
class _ZAutoLoadMoreView extends StatefulWidget {
  const _ZAutoLoadMoreView({required this.loadMoreRows});

  final LoadMoreRows loadMoreRows;

  @override
  State<_ZAutoLoadMoreView> createState() => _ZAutoLoadMoreViewState();
}

class _ZAutoLoadMoreViewState extends State<_ZAutoLoadMoreView> {
  // Capturé UNE FOIS à la création de l'état : Syncfusion recrée ce widget à
  // chaque déclenchement de fin de scroll (`_isLoadMoreViewLoaded` remis à
  // `false` par la source amont), jamais pendant l'attente d'un même appel.
  late final Future<void> _future = widget.loadMoreRows();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Semantics(
            liveRegion: true,
            container: true,
            label: label(context, 'list.loading'),
            child: const SizedBox(
              height: _kMinRowHeight,
              width: double.infinity,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return const SizedBox.shrink();
      },
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
    bool withOrderNumber = false,
    Color? Function(ZListRow row, ZListColumn column)? cellColorBuilder,
    Future<void> Function()? onLoadMore,
  }) {
    _cellColorBuilder = cellColorBuilder;
    _onLoadMore = onLoadMore;
    update(columns, rows, actionsFor, withOrderNumber: withOrderNumber);
  }

  List<ZListColumn> _columns = const <ZListColumn>[];
  List<ZResolvedRowAction> Function(ZListRow row)? _actionsFor;
  bool _withOrderNumber = false;
  Color? Function(ZListRow row, ZListColumn column)? _cellColorBuilder;
  Future<void> Function()? _onLoadMore;

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
  ///
  /// [withOrderNumber] `null` conserve la valeur courante (appel interne depuis
  /// le constructeur) ; non-`null` la remplace (Lot 5, colonne d'ordre).
  void update(
    List<ZListColumn> columns,
    List<ZListRow> rows,
    List<ZResolvedRowAction> Function(ZListRow row)? actionsFor, {
    bool? withOrderNumber,
  }) {
    _columns = columns;
    _actionsFor = actionsFor;
    if (withOrderNumber != null) _withOrderNumber = withOrderNumber;
    _dataRows.clear();
    _rowByData.clear();
    var index = 0;
    for (final row in rows) {
      final data = DataGridRow(
        cells: <DataGridCell>[
          if (_withOrderNumber)
            DataGridCell<String>(
              columnName: _kOrderColumnName,
              value: '${index + 1}',
            ),
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
      index++;
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

  /// Rafraîchit SEULEMENT la référence du résolveur de couleur de cellule (Lot
  /// 5/§2, même discipline que [refreshActions]) : la couleur est résolue
  /// paresseusement dans [buildRow], aucune reconstruction requise (elle
  /// n'affecte ni le nombre ni l'identité des `DataGridRow`).
  void refreshCellColorBuilder(
    Color? Function(ZListRow row, ZListColumn column)? cellColorBuilder,
  ) {
    _cellColorBuilder = cellColorBuilder;
  }

  /// Rafraîchit SEULEMENT la référence du callback `loadMore` (Lot 5) : appelé
  /// paresseusement par [handleLoadMoreRows], aucune reconstruction requise.
  void refreshOnLoadMore(Future<void> Function()? onLoadMore) {
    _onLoadMore = onLoadMore;
  }

  /// Override du hook Syncfusion invoqué par `LoadMoreRows` (le callback passé
  /// à `loadMoreViewBuilder`) : délègue à [_onLoadMore] s'il est fourni ; no-op
  /// sinon (défaut `DataGridSource.handleLoadMoreRows`, AD-10 — hôte passif
  /// strictement immobile).
  @override
  Future<void> handleLoadMoreRows() async {
    await _onLoadMore?.call();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final source = _rowByData[row];
    final cells = <Widget>[
      if (_withOrderNumber)
        Container(
          alignment: Alignment.center,
          child: Text(_cellString(row, _kOrderColumnName)),
        ),
      for (final col in _columns)
        Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          alignment: AlignmentDirectional.centerStart,
          color: source == null ? null : _cellColorBuilder?.call(source, col),
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
