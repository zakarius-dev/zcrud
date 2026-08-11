/// Modèles de **requête de rendu de liste** neutres du cœur `zcrud_core`.
///
/// Ces value objects sont **Material-free**, purs-données-présentation : ils ne
/// portent AUCUN widget, AUCUNE dépendance lourde, AUCUN `package:syncfusion`.
/// Ils constituent le **contrat neutre** que le port [ZListRenderer] consomme,
/// de sorte qu'un backend `SfDataGrid` (dans `zcrud_list`) ou un backend
/// Material `DataTable` s'implémente sur le MÊME contrat sans que Syncfusion ne
/// contamine le cœur.
///
/// **Frontière** : le contrat porte des `ZListColumn` **dérivées**
/// (`deriveColumns`, visibilité/formatage/largeur/ordre) via la fabrique
/// [ZListRenderRequest.fromSchema] — le backend consomme le format neutre partagé
/// sans re-dériver. Les **états UI**
/// (`loading`/`empty`/`noResults`/`error`) NE sont PAS portés ici : ils vivent
/// dans le wrapper `DynamicList` (`ZListViewState`). Vues alternatives, recherche/
/// tri/pagination et actions/`ZAcl` restent hors de ce contrat.
///
/// Égalité de **valeur profonde** (`==`/`hashCode`), cohérente avec
/// `ZFieldSpec`/`ZDataRequest` (helpers pur-Dart, aucun `package:collection` —
/// AD-1 out-degree 0).
library;

import '../../domain/edition/z_field_spec.dart';
import 'z_list_column.dart';

/// Ligne neutre d'une liste : une **identité opaque** + un sac de cellules.
///
/// [cells] mappe `field.name → valeur brute` (`Object?`, **opaque** : aucune
/// contrainte de type, aucun formatage). La projection `T → ZListRow` (via
/// `toMap`/`ZFieldSpec`) est l'affaire de l'appelant ;
/// le port n'impose AUCUNE générécité `T`.
class ZListRow {
  /// Construit une ligne. [id] est l'identité opaque (clé stable) ; [cells]
  /// porte les valeurs brutes indexées par `field.name`.
  const ZListRow({required this.id, required this.cells});

  /// Identité opaque de la ligne (clé stable, non affichée par défaut).
  final String id;

  /// Valeurs brutes de la ligne indexées par `field.name` (opaques).
  final Map<String, Object?> cells;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListRow &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _mapEquals(cells, other.cells);

  @override
  int get hashCode => Object.hash(runtimeType, id, _mapHash(cells));

  @override
  String toString() => 'ZListRow(id: $id, cells: $cells)';
}

/// Requête de rendu **neutre et immuable** consommée par [ZListRenderer].
///
/// Porte les [columns] **dérivées** (`ZListColumn` : en-tête non résolu,
/// largeur, format pur — cf. [ZListRenderRequest.fromSchema]) et les [rows]. Le
/// backend consomme le format neutre partagé (`col.format(row.cells[col.name])`)
/// sans re-dériver ni dupliquer de logique de format. Aucun état
/// `loading`/`empty`/`noResults`/`error` (dans `DynamicList`/`ZListViewState`),
/// aucun tri/filtre.
///
/// Immuable (`const` + champs `final`) ; égalité de **valeur profonde** (listes
/// et cellules comparées élément par élément).
class ZListRenderRequest {
  /// Construit une requête de rendu à partir des [columns] **dérivées** et
  /// [rows]. Pour dériver les colonnes depuis un `ZFieldSpec[]`, préférer la
  /// fabrique [ZListRenderRequest.fromSchema].
  const ZListRenderRequest({required this.columns, required this.rows});

  /// Fabrique dérivant les [columns] d'un `ZFieldSpec[]` via `deriveColumns`
  /// (visibilité/format/ordre/largeur), en appliquant la [policy] optionnelle.
  ///
  /// Centralise la dérivation dans le cœur (format neutre partagé) : le backend
  /// n'a plus qu'à rendre les `ZListColumn` produites.
  /// [formatting] porte les **seams d'affichage capturés** (libellé d'orphelin
  /// localisé, port de dates, locale) — cf. `ZListFormat`. Omis ⇒ rendu
  /// locale-neutre d'origine (appel headless : `zcrud_export`).
  ZListRenderRequest.fromSchema(
    List<ZFieldSpec> fields,
    this.rows, {
    ZColumnPolicy? policy,
    ZListFormat formatting = const ZListFormat(),
  }) : columns = deriveColumns(fields, policy: policy, formatting: formatting);

  /// Colonnes **dérivées** du schéma (`ZListColumn` : en-tête non résolu, clé de
  /// mapping `name`, largeur indicative, format pur par type).
  final List<ZListColumn> columns;

  /// Lignes à afficher (identité opaque + cellules brutes).
  final List<ZListRow> rows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListRenderRequest &&
          runtimeType == other.runtimeType &&
          _listEquals(columns, other.columns) &&
          _listEquals(rows, other.rows);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAll(columns),
        Object.hashAll(rows),
      );

  @override
  String toString() =>
      'ZListRenderRequest(columns: ${columns.length}, rows: ${rows.length})';
}

/// Égalité **profonde** de deux listes (élément par élément), pur-Dart
/// (évite `package:collection` — AD-1 out-degree 0).
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Égalité **profonde** de deux maps (clé + valeur), pur-Dart.
bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Hash **indépendant de l'ordre** d'insertion, cohérent avec [_mapEquals].
int _mapHash(Map<String, Object?> map) {
  var hash = 0;
  for (final entry in map.entries) {
    // XOR : commutatif → l'ordre des clés n'altère pas le hash.
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}
