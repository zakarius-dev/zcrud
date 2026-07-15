/// Embed **tableau** (E6-4) de `zcrud_markdown` : embed Quill CUSTOM de type
/// `table`, son `EmbedBuilder` de rendu DÉFENSIF (widget `Table` Flutter NATIF —
/// AUCUNE dépendance ajoutée, AD-1 idéal), et le dialogue de saisie/édition de la
/// grille (lignes / colonnes / cellules texte).
///
/// PATRON : ce fichier MIROITE `z_latex_embed.dart` (E6-3) — même contrat d'embed
/// custom (`Embeddable`), même `EmbedBuilder` défensif, même dialogue, même label
/// a11y, même placeholder thémé.
///
/// ISOLATION (AD-1) : ce fichier vit sous `lib/src/` et consomme `flutter_quill`
/// + le widget `Table` du framework (`package:flutter`, AUCUNE lib tierce). AUCUN
/// de ces types n'est ré-exporté par le barrel (`ZTableEmbed`/`ZTableEmbedBuilder`
/// NE SONT PAS publics). La représentation portée par la tranche `ZFormController`
/// reste une VALEUR NEUTRE : l'op Delta `{"insert": {"table": <structure>}}`
/// (`Map` opaque JSON-safe) — jamais un type Quill.
///
/// DÉFENSIF (AD-10) : le rendu ne throw JAMAIS — structure absente / non-`Map` /
/// `cells` non-`List` / lignes non-`List` ou irrégulières / vide → placeholder
/// d'erreur inline thémé. Les cellules sont coercées en `String` (jamais d'accès
/// typé non gardé). L'éditeur reste fonctionnel.
///
/// A11Y (AD-13) : placeholder porteur d'un [Semantics] (« tableau invalide »),
/// insets DIRECTIONNELS ; bordures/couleurs issues du thème injecté
/// (`ZcrudTheme`/`Theme`), zéro couleur codée en dur. Bouton/dialogue ≥ 48 dp.
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:zcrud_core/zcrud_core.dart';

// SOURCE UNIQUE du contrat table (SM-S4 / COMBLEMENT ES-6.2) : `kTableEmbedType`
// et les clés de structure `rows`/`columns`/`cells` sont DÉFINIS dans la couture
// NEUTRE `../data/z_table_ops.dart` (pur-Dart, réutilisée par le migrateur
// `zcrud_note`). Ce fichier de RENDU les IMPORTE — il ne les re-déclare plus.
import '../data/z_table_ops.dart';

// Alias locaux privés pour préserver le corps E6-4 inchangé (clés importées).
const String _kRowsKey = kTableRowsKey;
const String _kColumnsKey = kTableColumnsKey;
const String _kCellsKey = kTableCellsKey;

/// Libellé a11y (AD-13) du placeholder d'erreur — lisible par lecteur d'écran.
@visibleForTesting
const String kTableInvalidLabel = 'tableau invalide';

/// Embed Quill CUSTOM **bloc** de type `table`.
///
/// `data` = la `Map` de structure JSON-safe
/// (`{"rows": <int>, "columns": <int>, "cells": <List<List<String>>>}`).
/// `toJson()` (hérité d'[Embeddable]) produit exactement `{"table": <structure>}`,
/// d'où l'op Delta `{"insert": {"table": <structure>}}` (JSON-safe, opaque —
/// traverse le round-trip d'E6-2 à l'identique via `ZDeltaCodec`).
class ZTableEmbed extends Embeddable {
  /// Construit l'embed tableau portant la [structure] (grille JSON-safe).
  const ZTableEmbed(Map<String, dynamic> structure)
      : super(kTableEmbedType, structure);
}

/// `EmbedBuilder` de rendu DÉFENSIF (AD-10) de l'embed `table` via le widget
/// `Table` **natif** de Flutter.
///
/// `expanded == true` : le tableau est rendu en **bloc** (occupe sa propre ligne),
/// choix conforme à la décision de conception E6-4 (block par défaut, cohérent
/// avec la nature d'un tableau). Le widget `Table` utilise
/// [IntrinsicColumnWidth] : il se dimensionne à son contenu et reste donc
/// robuste même si l'embed se retrouvait sur une ligne mixte (rendu inline via
/// `WidgetSpan`) — jamais d'assertion de largeur non bornée. Sans état ⇒ instance
/// `const` STABLE (SM-1/AD-2 : aucune allocation par (re)build de tranche ;
/// n'entre jamais dans le flux `document.changes`).
///
/// ÉDITION (AC3) : la RÉ-ÉDITION d'un tableau existant passe par la voie bouton
/// toolbar « Tableau » (`_promptAndInsertTable` détecte l'embed sous le caret,
/// pré-remplit le dialogue et REMPLACE l'op). Aucun geste n'est câblé sur le
/// widget rendu, pour garder l'instance `const` sans état (SM-1) et l'op de
/// tranche opaque.
class ZTableEmbedBuilder extends EmbedBuilder {
  /// Builder `const` (sans état, aucune ressource à disposer).
  const ZTableEmbedBuilder();

  @override
  String get key => kTableEmbedType;

  /// Rendu BLOC : le tableau occupe sa propre ligne (décision de conception E6-4).
  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final Object? data = embedContext.node.value.data;
    // DÉFENSIF (AD-10) : parse AVANT tout accès typé. Structure invalide / vide /
    // lignes irrégulières → placeholder ; on n'appelle JAMAIS `Table(...)` sur une
    // entrée qui ferait échouer son assertion de lignes de longueur égale.
    final List<List<String>>? matrix = _parseTable(data);
    if (matrix == null) {
      return _errorPlaceholder(context);
    }
    return _buildTable(context, matrix, embedContext.textStyle);
  }

  /// Parse DÉFENSIF (AD-10) de la structure d'embed en matrice `List<List<String>>`.
  ///
  /// La **matrice `cells` est la source de vérité** (les champs `rows`/`columns`
  /// éventuels sont ignorés — Dev Notes E6-4). Retourne `null` (⇒ placeholder)
  /// si : [data] non-`Map` ; `cells` absent / non-`List` / vide ; une ligne
  /// non-`List` ; lignes de longueurs IRRÉGULIÈRES ; largeur nulle. Les cellules
  /// sont COERCÉES en `String` (jamais de throw sur une feuille non-`String`).
  static List<List<String>>? _parseTable(Object? data) {
    if (data is! Map) return null;
    final Object? cells = data[_kCellsKey];
    if (cells is! List || cells.isEmpty) return null;
    int? width;
    final List<List<String>> matrix = <List<String>>[];
    for (final Object? row in cells) {
      if (row is! List) return null;
      if (width == null) {
        width = row.length;
        if (width == 0) return null;
      } else if (row.length != width) {
        // Lignes irrégulières (jagged) → placeholder (jamais de throw `Table`).
        return null;
      }
      matrix.add(<String>[for (final Object? cell in row) cell?.toString() ?? '']);
    }
    return matrix;
  }

  /// Rendu du widget `Table` NATIF (bordures/couleurs du thème injecté, padding
  /// directionnel). [IntrinsicColumnWidth] : dimensionnement au contenu (robuste).
  Widget _buildTable(
    BuildContext context,
    List<List<String>> matrix,
    TextStyle textStyle,
  ) {
    final ZcrudTheme zTheme = ZcrudTheme.of(context);
    final Color borderColor =
        zTheme.fieldBorderColor ?? Theme.of(context).colorScheme.outline;
    return Table(
      border: TableBorder.all(color: borderColor),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        for (final List<String> row in matrix)
          TableRow(
            children: <Widget>[
              for (final String cell in row)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    cell,
                    style: textStyle,
                    textAlign: TextAlign.start,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// Placeholder d'erreur INLINE thémé (AD-13/FR-26) : icône `error_outline`
  /// colorée par `ZcrudTheme.errorColor` (repli `Theme.colorScheme.error`),
  /// enveloppée d'un [Semantics] lisible ([kTableInvalidLabel]). Insets
  /// DIRECTIONNELS. Zéro couleur codée en dur.
  Widget _errorPlaceholder(BuildContext context) {
    final Color color =
        ZcrudTheme.of(context).errorColor ?? Theme.of(context).colorScheme.error;
    return Semantics(
      label: kTableInvalidLabel,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
        child: Icon(Icons.error_outline, size: 18, color: color),
      ),
    );
  }
}

/// Ouvre le dialogue de saisie/édition d'un tableau (AC3, AD-13).
///
/// Retourne la **structure JSON-safe** validée
/// (`{"rows": int, "columns": int, "cells": List<List<String>>}`), ou `null` si
/// l'utilisateur annule. [initial] pré-remplit la grille (édition d'un embed
/// existant). Cibles ≥ 48 dp, [Semantics] explicites, insets DIRECTIONNELS.
Future<Map<String, dynamic>?> showZTableDialog(
  BuildContext context, {
  Map<String, dynamic>? initial,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext dialogContext) => _ZTableDialog(initial: initial),
  );
}

class _ZTableDialog extends StatefulWidget {
  const _ZTableDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_ZTableDialog> createState() => _ZTableDialogState();
}

class _ZTableDialogState extends State<_ZTableDialog> {
  /// Cible de tap minimale (AD-13).
  static const double _kMinTapTarget = 48;

  /// Bornes de dimension du tableau (MVP).
  static const int _kMinDim = 1;
  static const int _kMaxDim = 12;

  /// Largeur d'une colonne de saisie dans la grille du dialogue.
  static const double _kCellWidth = 96;

  /// Largeur de la gouttière de menus LIGNE (MIN-1) — cible ≥ 48 dp.
  static const double _kRowMenuWidth = 48;

  late int _rows;
  late int _columns;

  /// Matrice de contrôleurs (un par cellule) — créés/disposés dans ce [State]
  /// (N contrôleurs : anti-fuite E6-1/E6-3).
  late List<List<TextEditingController>> _cells;

  @override
  void initState() {
    super.initState();
    final List<List<String>> seed = _initialCells(widget.initial);
    _rows = seed.length;
    _columns = seed.first.length;
    _cells = <List<TextEditingController>>[
      for (final List<String> row in seed)
        <TextEditingController>[
          for (final String cell in row) TextEditingController(text: cell),
        ],
    ];
  }

  @override
  void dispose() {
    for (final List<TextEditingController> row in _cells) {
      for (final TextEditingController c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  /// Extrait DÉFENSIVEMENT une matrice de texte de [initial] pour pré-remplir la
  /// grille (édition). Normalise les lignes irrégulières en PADDANT à la largeur
  /// max (pour l'ÉDITION on charge un contenu utilisable). Repli 2×2 vide.
  static List<List<String>> _initialCells(Map<String, dynamic>? initial) {
    List<List<String>> fallback() => <List<String>>[
          <String>['', ''],
          <String>['', ''],
        ];
    if (initial == null) return fallback();
    final Object? cells = initial[_kCellsKey];
    if (cells is! List || cells.isEmpty) return fallback();
    final List<List<String>> rows = <List<String>>[];
    var width = 0;
    for (final Object? row in cells) {
      final List<String> cellsRow = row is List
          ? <String>[for (final Object? c in row) c?.toString() ?? '']
          : <String>[];
      rows.add(cellsRow);
      if (cellsRow.length > width) width = cellsRow.length;
    }
    if (width == 0) return fallback();
    // Normalise (padde) à la largeur max — jamais de matrice jagged en édition.
    return <List<String>>[
      for (final List<String> row in rows)
        <String>[
          for (var i = 0; i < width; i++) i < row.length ? row[i] : '',
        ],
    ];
  }

  /// Redimensionne la grille en préservant le texte des cellules conservées et en
  /// disposant les contrôleurs supprimés (anti-fuite).
  void _resize(int rows, int columns) {
    final int newRows = rows.clamp(_kMinDim, _kMaxDim);
    final int newColumns = columns.clamp(_kMinDim, _kMaxDim);
    if (newRows == _rows && newColumns == _columns) return;
    final List<List<TextEditingController>> next = <List<TextEditingController>>[];
    for (var r = 0; r < newRows; r++) {
      final List<TextEditingController> row = <TextEditingController>[];
      for (var c = 0; c < newColumns; c++) {
        if (r < _rows && c < _columns) {
          row.add(_cells[r][c]); // réutilise (préserve le texte)
        } else {
          row.add(TextEditingController());
        }
      }
      next.add(row);
    }
    // Dispose des contrôleurs hors de la nouvelle grille.
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _columns; c++) {
        if (r >= newRows || c >= newColumns) {
          _cells[r][c].dispose();
        }
      }
    }
    setState(() {
      _cells = next;
      _rows = newRows;
      _columns = newColumns;
    });
  }

  /// Insère une ligne VIDE à l'index [at] (0.._rows) — MIN-1 (menu ligne).
  void _insertRowAt(int at) {
    if (_rows >= _kMaxDim) return;
    final int idx = at.clamp(0, _rows);
    final List<TextEditingController> row = <TextEditingController>[
      for (var c = 0; c < _columns; c++) TextEditingController(),
    ];
    setState(() {
      _cells.insert(idx, row);
      _rows += 1;
    });
  }

  /// Supprime la ligne [at] (dispose ses contrôleurs) — MIN-1 (menu ligne).
  /// No-op si on est déjà au minimum de lignes.
  void _deleteRowAt(int at) {
    if (_rows <= _kMinDim || at < 0 || at >= _rows) return;
    setState(() {
      for (final TextEditingController c in _cells[at]) {
        c.dispose();
      }
      _cells.removeAt(at);
      _rows -= 1;
    });
  }

  /// Insère une colonne VIDE à l'index [at] (0.._columns) — MIN-1 (menu colonne).
  void _insertColumnAt(int at) {
    if (_columns >= _kMaxDim) return;
    final int idx = at.clamp(0, _columns);
    setState(() {
      for (final List<TextEditingController> row in _cells) {
        row.insert(idx, TextEditingController());
      }
      _columns += 1;
    });
  }

  /// Supprime la colonne [at] (dispose ses contrôleurs) — MIN-1 (menu colonne).
  /// No-op si on est déjà au minimum de colonnes.
  void _deleteColumnAt(int at) {
    if (_columns <= _kMinDim || at < 0 || at >= _columns) return;
    setState(() {
      for (final List<TextEditingController> row in _cells) {
        row.removeAt(at).dispose();
      }
      _columns -= 1;
    });
  }

  /// Valide la saisie (AC3) : construit la structure JSON-safe depuis la grille.
  void _submit() {
    final List<List<String>> cells = <List<String>>[
      for (final List<TextEditingController> row in _cells)
        <String>[for (final TextEditingController c in row) c.text],
    ];
    Navigator.of(context).pop(<String, dynamic>{
      _kRowsKey: _rows,
      _kColumnsKey: _columns,
      _kCellsKey: cells,
    });
  }

  void _cancel() => Navigator.of(context).pop();

  Widget _stepper({
    required String label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required String decKey,
    required String incKey,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$label : ', textAlign: TextAlign.start),
        IconButton(
          key: ValueKey<String>(decKey),
          tooltip: 'Retirer une $label'.toLowerCase(),
          onPressed: value > _kMinDim ? onDecrement : null,
          icon: const Icon(Icons.remove),
        ),
        Text('$value'),
        IconButton(
          key: ValueKey<String>(incKey),
          tooltip: 'Ajouter une $label'.toLowerCase(),
          onPressed: value < _kMaxDim ? onIncrement : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  /// Menu contextuel d'une **ligne** [r] (MIN-1) : insérer au-dessus / en-dessous
  /// / supprimer. Cible ≥ 48 dp (PopupMenuButton par défaut), `Semantics`.
  Widget _rowMenu(int r) => Semantics(
        button: true,
        label: 'Menu ligne ${r + 1}',
        child: PopupMenuButton<String>(
          key: ValueKey<String>('ztable-row-menu-$r'),
          tooltip: 'Menu ligne ${r + 1}',
          icon: const Icon(Icons.more_vert),
          onSelected: (String action) {
            switch (action) {
              case 'insertAbove':
                _insertRowAt(r);
              case 'insertBelow':
                _insertRowAt(r + 1);
              case 'delete':
                _deleteRowAt(r);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              key: ValueKey<String>('ztable-row-insert-above'),
              value: 'insertAbove',
              child: Text('Insérer une ligne au-dessus'),
            ),
            const PopupMenuItem<String>(
              key: ValueKey<String>('ztable-row-insert-below'),
              value: 'insertBelow',
              child: Text('Insérer une ligne en-dessous'),
            ),
            PopupMenuItem<String>(
              key: const ValueKey<String>('ztable-row-delete'),
              value: 'delete',
              enabled: _rows > _kMinDim,
              child: const Text('Supprimer la ligne'),
            ),
          ],
        ),
      );

  /// Menu contextuel d'une **colonne** [c] (MIN-1) : insérer avant / après /
  /// supprimer. Cible ≥ 48 dp, `Semantics`.
  Widget _columnMenu(int c) => Semantics(
        button: true,
        label: 'Menu colonne ${c + 1}',
        child: PopupMenuButton<String>(
          key: ValueKey<String>('ztable-col-menu-$c'),
          tooltip: 'Menu colonne ${c + 1}',
          icon: const Icon(Icons.more_horiz),
          onSelected: (String action) {
            switch (action) {
              case 'insertBefore':
                _insertColumnAt(c);
              case 'insertAfter':
                _insertColumnAt(c + 1);
              case 'delete':
                _deleteColumnAt(c);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              key: ValueKey<String>('ztable-col-insert-before'),
              value: 'insertBefore',
              child: Text('Insérer une colonne avant'),
            ),
            const PopupMenuItem<String>(
              key: ValueKey<String>('ztable-col-insert-after'),
              value: 'insertAfter',
              child: Text('Insérer une colonne après'),
            ),
            PopupMenuItem<String>(
              key: const ValueKey<String>('ztable-col-delete'),
              value: 'delete',
              enabled: _columns > _kMinDim,
              child: const Text('Supprimer la colonne'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Semantics(
        header: true,
        child: const Text('Tableau'),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: <Widget>[
                  _stepper(
                    label: 'Lignes',
                    value: _rows,
                    onDecrement: () => _resize(_rows - 1, _columns),
                    onIncrement: () => _resize(_rows + 1, _columns),
                    decKey: 'ztable-rows-dec',
                    incKey: 'ztable-rows-inc',
                  ),
                  _stepper(
                    label: 'Colonnes',
                    value: _columns,
                    onDecrement: () => _resize(_rows, _columns - 1),
                    onIncrement: () => _resize(_rows, _columns + 1),
                    decKey: 'ztable-columns-dec',
                    incKey: 'ztable-columns-inc',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // En-tête : coin vide + un menu par COLONNE (MIN-1).
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(width: _kRowMenuWidth),
                        for (var c = 0; c < _columns; c++)
                          SizedBox(
                            width: _kCellWidth,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _columnMenu(c),
                            ),
                          ),
                      ],
                    ),
                    // Lignes : menu LIGNE en tête + cellules texte.
                    for (var r = 0; r < _rows; r++)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: _kRowMenuWidth,
                            child: _rowMenu(r),
                          ),
                          for (var c = 0; c < _columns; c++)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: 8,
                                bottom: 8,
                              ),
                              child: SizedBox(
                                width: _kCellWidth,
                                child: TextField(
                                  key: ValueKey<String>('ztable-cell-$r-$c'),
                                  controller: _cells[r][c],
                                  textAlign: TextAlign.start,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    labelText: 'L${r + 1}C${c + 1}',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsetsDirectional.only(
        end: 12,
        bottom: 8,
        start: 12,
      ),
      actions: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMinTapTarget,
            minHeight: _kMinTapTarget,
          ),
          child: TextButton(
            onPressed: _cancel,
            child: Text(l10n.cancelButtonLabel),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMinTapTarget,
            minHeight: _kMinTapTarget,
          ),
          child: FilledButton(
            onPressed: _submit,
            child: Text(l10n.okButtonLabel),
          ),
        ),
      ],
    );
  }
}
