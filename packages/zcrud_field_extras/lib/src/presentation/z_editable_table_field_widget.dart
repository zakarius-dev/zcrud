/// `ZEditableTableFieldWidget` — **table éditable virtualisée** servie via
/// `ZWidgetRegistry` sous le `kind` [editableTableFieldKind] (aligné sur
/// `EditionFieldType.editableTable.name`).
///
/// **Zéro dépendance lourde** : `ListView.builder` (jamais
/// `ListView(children:)` — invariant AD-13). Aucune arête supplémentaire
/// n'est ajoutée au graphe de dépendances.
///
/// **Limite de persistance — exécution uniquement.** La valeur est
/// `List<Map<String, dynamic>>`. Ce widget l'édite pleinement **en mémoire**
/// (value-in-slice). Mais **la persistance via `@ZcrudModel` d'un champ
/// `List<Map<String, dynamic>>` typé `editableTable` N'EST PAS supportée par
/// le générateur** actuel : il lève une erreur de génération sur un élément
/// `Map`, faute de branche de classification dédiée. La persistance
/// nécessiterait un **type de valeur dédié avec son propre codec** — ne pas
/// tenter de la contourner ici (le domaine du cœur reste disjoint de ce
/// paquet).
///
/// **Dispatch cœur** : `EditionFieldType.editableTable` → famille
/// `registryOrFallback` → `registry.tryBuilderFor('editableTable')`. Repli
/// `ZUnsupportedFieldWidget` tant que non enregistré (invariant AD-10).
///
/// **Invariant AD-2** : value-in-slice — lit `ctx.value`, écrit `ctx.onChanged` ;
/// aucun `ZFormController` capturé. **Invariant AD-10** :
/// `null`/non-`List`/éléments non-`Map` ⇒ table vide, jamais un crash.
/// **Invariant AD-13** : actions ajouter/supprimer ligne ≥ 48 dp,
/// `Semantics`/tooltip localisables, bordures dérivées du thème injecté.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// `kind` du champ **table éditable**, ALIGNÉ sur
/// `EditionFieldType.editableTable.name == 'editableTable'`.
final String editableTableFieldKind = EditionFieldType.editableTable.name;

/// Colonne par défaut amorcée quand on ajoute une ligne à une table vierge
/// (aucune colonne dérivable des lignes existantes).
const String kZTableDefaultColumn = 'value';

/// Parse **défensif** (invariant AD-10) d'une valeur de tranche en
/// `List<Map<String, dynamic>>` : `null`/non-`List`/éléments non-`Map` ⇒ ignorés.
/// Jamais un throw traversant.
List<Map<String, dynamic>> zParseTableRows(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  final out = <Map<String, dynamic>>[];
  for (final row in value) {
    if (row is Map) {
      out.add(<String, dynamic>{
        for (final entry in row.entries) '${entry.key}': entry.value,
      });
    }
  }
  return out;
}

/// Colonnes = **union ordonnée** des clés de toutes les lignes.
List<String> zTableColumns(List<Map<String, dynamic>> rows) {
  final cols = <String>[];
  final seen = <String>{};
  for (final row in rows) {
    for (final key in row.keys) {
      if (seen.add(key)) cols.add(key);
    }
  }
  return cols;
}

/// Table éditable virtualisée (value-in-slice, patron AD-2).
class ZEditableTableFieldWidget extends StatefulWidget {
  /// Construit la table pour [ctx].
  const ZEditableTableFieldWidget({required this.ctx, this.onBuild, super.key});

  /// Contexte du champ (`ctx.value` = `List<Map<String, dynamic>>` courant,
  /// `ctx.onChanged` = écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Hook de test : appelé à chaque (re)build (mesure de la granularité des
  /// rebuilds).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous [editableTableFieldKind].
  static ZFieldWidgetBuilder builder({VoidCallback? onBuild}) =>
      (BuildContext context, ZFieldWidgetContext ctx) =>
          ZEditableTableFieldWidget(ctx: ctx, onBuild: onBuild);

  @override
  State<ZEditableTableFieldWidget> createState() =>
      _ZEditableTableFieldWidgetState();
}

class _ZEditableTableFieldWidgetState extends State<ZEditableTableFieldWidget> {
  /// Clés stables par ligne (identité des `TextFormField` à travers les
  /// rebuilds — invariant AD-2 : leur contrôleur interne survit tant que la
  /// clé est stable). Une ligne ajoutée reçoit une nouvelle clé ; une ligne
  /// retirée la perd.
  final List<int> _rowKeys = <int>[];
  int _nextKey = 0;

  /// Contrôleurs de cellule **gérés** (invariant AD-2), indexés par
  /// `cell-<rowKey>-<col>`. Alloués une seule fois par cellule (jamais
  /// recréés au rebuild) et disposés quand la ligne/colonne disparaît ou au
  /// démontage. Le patron mirroir du champ PIN
  /// (`z_pin_field_widget.dart`) : une ré-injection externe (reset /
  /// rechargement d'entité) qui change une cellule EXISTANTE est
  /// re-synchronisée via [didUpdateWidget] — `initialValue` ne s'appliquant
  /// qu'à la création, il ne suffisait pas.
  final Map<String, TextEditingController> _cellControllers =
      <String, TextEditingController>{};

  /// Retourne le contrôleur de la cellule [key], en le créant (avec [text])
  /// s'il n'existe pas encore. Jamais recréé si présent.
  TextEditingController _cellController(String key, String text) =>
      _cellControllers.putIfAbsent(
        key,
        () => TextEditingController(text: text),
      );

  /// Réconcilie [_rowKeys] avec le nombre de lignes courant [n] (repli si une
  /// ré-injection externe modifie la longueur hors édition locale).
  void _syncKeys(int n) {
    while (_rowKeys.length < n) {
      _rowKeys.add(_nextKey++);
    }
    if (_rowKeys.length > n) {
      _rowKeys.removeRange(n, _rowKeys.length);
    }
  }

  @override
  void didUpdateWidget(covariant ZEditableTableFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ré-injection externe : aligner le texte de chaque cellule EXISTANTE sur la
    // tranche SANS écraser la sélection (n'écrit que si le texte diffère
    // réellement — jamais à chaque frappe). Positionnel (row i ↔ _rowKeys[i]),
    // borné ; les lignes/colonnes nouvelles sont créées à jour au prochain build.
    final rows = zParseTableRows(widget.ctx.value);
    for (var i = 0; i < rows.length && i < _rowKeys.length; i++) {
      final rowKey = _rowKeys[i];
      for (final entry in rows[i].entries) {
        final ctrl = _cellControllers['cell-$rowKey-${entry.key}'];
        if (ctrl == null) continue;
        final text = '${entry.value ?? ''}';
        if (ctrl.text != text) {
          ctrl.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _cellControllers.values) {
      ctrl.dispose();
    }
    _cellControllers.clear();
    super.dispose();
  }

  void _emit(List<Map<String, dynamic>> rows) {
    widget.ctx.onChanged(
      List<Map<String, dynamic>>.unmodifiable(
        rows.map((r) => Map<String, dynamic>.unmodifiable(r)),
      ),
    );
  }

  void _setCell(
    List<Map<String, dynamic>> rows,
    int rowIndex,
    String col,
    String text,
  ) {
    final next = <Map<String, dynamic>>[
      for (var i = 0; i < rows.length; i++)
        if (i == rowIndex)
          <String, dynamic>{...rows[i], col: text}
        else
          <String, dynamic>{...rows[i]},
    ];
    _emit(next);
  }

  void _addRow(List<Map<String, dynamic>> rows, List<String> cols) {
    _rowKeys.add(_nextKey++);
    // Table vierge (aucune colonne dérivable) : amorce une colonne par défaut
    // pour que la ligne soit éditable (le libellé de colonne reste éditable via
    // la clé). Sinon reprend les colonnes existantes.
    final effectiveCols =
        cols.isEmpty ? const <String>[kZTableDefaultColumn] : cols;
    final blank = <String, dynamic>{for (final c in effectiveCols) c: ''};
    _emit(<Map<String, dynamic>>[...rows, blank]);
  }

  void _removeRow(List<Map<String, dynamic>> rows, int rowIndex) {
    if (rowIndex >= 0 && rowIndex < _rowKeys.length) {
      _rowKeys.removeAt(rowIndex);
    }
    _emit(<Map<String, dynamic>>[
      for (var i = 0; i < rows.length; i++)
        if (i != rowIndex) rows[i],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final readOnly = field.readOnly;

    final rows = zParseTableRows(widget.ctx.value);
    final cols = zTableColumns(rows);
    _syncKeys(rows.length);

    // Élague les contrôleurs orphelins (ligne supprimée / colonne disparue) pour
    // éviter la fuite, en les disposant. Chaque cellule rendue = un `(rowKey,c)`.
    final validCellKeys = <String>{
      for (var i = 0; i < rows.length; i++)
        for (final c in cols) 'cell-${_rowKeys[i]}-$c',
    };
    _cellControllers.removeWhere((key, ctrl) {
      if (validCellKeys.contains(key)) return false;
      ctrl.dispose();
      return true;
    });

    final addLabel =
        label(context, 'fieldExtras.table.addRow', fallback: 'Ajouter une ligne');
    final removeLabel = label(
      context,
      'fieldExtras.table.removeRow',
      fallback: 'Supprimer la ligne',
    );

    return Padding(
      padding: theme.fieldPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(resolvedLabel, style: TextStyle(color: theme.labelColor)),
          SizedBox(height: theme.gapS),
          if (cols.isNotEmpty)
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
              child: Row(
                children: <Widget>[
                  for (final c in cols)
                    Expanded(
                      child: Text(
                        c,
                        textAlign: TextAlign.start,
                        style: (theme.labelTextStyle ?? const TextStyle())
                            .copyWith(
                          color: theme.labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (!readOnly) const SizedBox(width: 48),
                ],
              ),
            ),
          // VIRTUALISÉ (invariant AD-13) : ListView.builder — jamais
          // ListView(children:).
          ListView.builder(
            key: const Key('z-editable-table-rows'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              final rowKey = _rowKeys[i];
              return Padding(
                padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    for (final c in cols)
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsetsDirectional.only(end: 8),
                          child: TextFormField(
                            key: ValueKey<String>('cell-$rowKey-$c'),
                            controller: _cellController(
                              'cell-$rowKey-$c',
                              '${row[c] ?? ''}',
                            ),
                            enabled: !readOnly,
                            textDirection: Directionality.of(context),
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(theme.radiusS),
                                borderSide:
                                    BorderSide(color: scheme.outline),
                              ),
                            ),
                            onChanged: (text) => _setCell(rows, i, c, text),
                          ),
                        ),
                      ),
                    if (!readOnly)
                      Semantics(
                        button: true,
                        label: removeLabel,
                        child: IconButton(
                          key: ValueKey<String>('z-table-remove-$rowKey'),
                          icon: const Icon(Icons.close),
                          tooltip: removeLabel,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: () => _removeRow(rows, i),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (!readOnly)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                button: true,
                label: addLabel,
                child: TextButton.icon(
                  key: const Key('z-table-add-row'),
                  icon: const Icon(Icons.add),
                  label: Text(addLabel),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _addRow(rows, cols),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
