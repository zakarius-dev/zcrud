/// Colonne de liste **dérivée du schéma** + helper de dérivation PUR, neutres du
/// cœur `zcrud_core`.
///
/// origine: E4-2 (moteur `DynamicList`, FR-6..FR-8 · AD-8/SM-5). E4-1 avait posé
/// le port neutre `ZListRenderer` + un contrat `columns: List<ZFieldSpec>` en
/// projection **brute** 1:1 ; E4-2 introduit la **dérivation FINE** : à partir du
/// `ZFieldSpec[]`, décider **quels champs** sont affichés en liste (visibilité),
/// **comment formater** chaque cellule par `EditionFieldType`, le **libellé**,
/// l'**ordre** et une **largeur** indicative.
///
/// **Neutre, Material-free, `const`-compatible** : ce fichier n'importe QUE
/// `package:flutter/foundation.dart` (`@immutable`) + types `zcrud_core`. AUCUN
/// widget, AUCUN `BuildContext`, AUCUN `package:syncfusion`, aucune dépendance
/// lourde (gardes `presentation_purity_test`/`no_heavy_file_dep_test` — SM-5). Le
/// **formatage vit ici une seule fois** (pur, locale-neutre) ; le backend
/// (`SfDataGrid` dans `zcrud_list`, ou tout autre) consomme les `ZListColumn`
/// sans re-dériver ni dupliquer de logique de format.
///
/// **Frontière E4-2** : le formatage **locale-aware** des nombres/dates/booléens
/// est **déféré E4-3** (hook injecté / labels) ; recherche/tri/pagination E4-3 ;
/// actions/`ZAcl` E4-4. On ne porte ici QUE la dérivation pure.
library;

import 'package:flutter/foundation.dart';

import '../../domain/edition/edition_field_type.dart';
import '../../domain/edition/z_field_choice.dart';
import '../../domain/edition/z_field_spec.dart';

/// Types **scalaires/affichables** en tableau (whitelist de visibilité, AC3).
///
/// Tout `EditionFieldType` ABSENT de cet ensemble est **exclu par défaut** de la
/// liste : soit lourd/non-tabulaire (`subItems`, `dynamicItem`, `file`, `image`,
/// `document`, `location`, `geoArea`, `address`, `signature`, `markdown`/
/// `richText`/`html`…), soit non rendu (`hidden`), soit nécessitant une
/// résolution runtime (`relation`, `widget`, `custom`, `stepper`, `password`,
/// `icon`). L'appelant peut forcer l'inclusion d'un tel champ via
/// [ZColumnPolicy.forceInclude] (point d'extension additif, AD-4), sans toucher
/// aux annotations E2-4.
const Set<EditionFieldType> _tabularTypes = <EditionFieldType>{
  EditionFieldType.text,
  EditionFieldType.multiline,
  EditionFieldType.number,
  EditionFieldType.integer,
  EditionFieldType.float,
  EditionFieldType.boolean,
  EditionFieldType.dateTime,
  EditionFieldType.time,
  EditionFieldType.select,
  EditionFieldType.radio,
  EditionFieldType.checkbox,
  EditionFieldType.tags,
  EditionFieldType.rowChips,
  EditionFieldType.country,
  EditionFieldType.phoneNumber,
  EditionFieldType.rating,
  EditionFieldType.slider,
  EditionFieldType.color,
};

/// **Politique de colonnes** additive (AD-4) : permet à l'appelant de forcer
/// l'inclusion/exclusion d'un champ par `name`, SANS modifier `ZFieldSpec` ni les
/// annotations E2-4 (gelées). Point d'extension `const`-compatible.
///
/// Précédence (cf. [deriveColumns]) : [forceExclude] l'emporte sur [forceInclude]
/// (l'exclusion explicite gagne en cas de conflit), qui l'emporte sur la
/// visibilité par défaut fondée sur le type/`isId`.
@immutable
class ZColumnPolicy {
  /// Construit une politique. Ensembles vides par défaut (aucun override).
  const ZColumnPolicy({
    this.forceInclude = const <String>{},
    this.forceExclude = const <String>{},
  });

  /// Noms de champs à **inclure** même si leur type ne serait pas tabulaire
  /// (ou s'ils sont `isId`). Prioritaire sur la visibilité par défaut.
  final Set<String> forceInclude;

  /// Noms de champs à **exclure** quoi qu'il arrive. Prioritaire sur tout.
  final Set<String> forceExclude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZColumnPolicy &&
          runtimeType == other.runtimeType &&
          setEquals(forceInclude, other.forceInclude) &&
          setEquals(forceExclude, other.forceExclude);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAllUnordered(forceInclude),
        Object.hashAllUnordered(forceExclude),
      );

  @override
  String toString() =>
      'ZColumnPolicy(forceInclude: $forceInclude, forceExclude: $forceExclude)';
}

/// Colonne de liste **neutre, immuable, `const`-compatible, Material-free**,
/// dérivée d'un `ZFieldSpec` par [deriveColumns] (E4-2).
///
/// Porte le minimum pour qu'un backend rende une colonne SANS re-dériver :
/// - [name] : clé de mapping = `field.name` (indexe `ZListRow.cells`) ;
/// - [header] : libellé/clé **non résolu** = `field.label ?? field.name` (la
///   résolution l10n est faite au **rendu** via `label(context, header)`) ;
/// - [type] : `EditionFieldType` source (info de rendu/alignement au backend) ;
/// - [order] : rang stable (index dans le schéma) ;
/// - [width] : largeur indicative (`null` = laissé au backend) ;
/// - [format] : fonction de **format PURE** `raw → String` (locale-neutre).
///
/// **Égalité de valeur** sur `name/header/type/order/width` UNIQUEMENT : la
/// closure [format] est **dérivée du `type`** (deux colonnes de mêmes champs de
/// données formatent identiquement), donc l'exclure de `==`/`hashCode` garde
/// l'égalité déterministe (cohérent avec `ZFieldSpec`, dont les closures ne sont
/// pas comparées).
@immutable
class ZListColumn {
  /// Construit une colonne `const`.
  const ZListColumn({
    required this.name,
    required this.header,
    required this.type,
    required this.order,
    required this.format,
    this.width,
  });

  /// Clé de mapping (`field.name`) : indexe `ZListRow.cells[name]`.
  final String name;

  /// Libellé/clé **non résolu** (`field.label ?? field.name`). Résolu au rendu.
  final String header;

  /// Type déclaratif source (piste d'alignement/format pour le backend).
  final EditionFieldType type;

  /// Rang de la colonne (index stable dans le schéma).
  final int order;

  /// Largeur indicative (px logiques), ou `null` (laissé au backend).
  final double? width;

  /// Fonction de format **PURE** `raw → String` (locale-neutre, ne lève jamais).
  final String Function(Object? raw) format;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListColumn &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          header == other.header &&
          type == other.type &&
          order == other.order &&
          width == other.width;

  @override
  int get hashCode => Object.hash(runtimeType, name, header, type, order, width);

  @override
  String toString() =>
      'ZListColumn(name: $name, header: $header, type: ${type.name}, '
      'order: $order, width: $width)';
}

/// Projette un `ZFieldSpec[]` en une **liste ordonnée** de [ZListColumn]
/// (E4-2, AC1/AC2/AC3). **PUR** : aucun `BuildContext`, aucun widget, aucun I/O,
/// **déterministe** (même entrée → même sortie).
///
/// Règles de visibilité (AC3) — un champ est INCLUS ssi :
/// 1. il n'est PAS dans `policy.forceExclude` ; ET
/// 2. il est dans `policy.forceInclude` **OU** (`!field.isId` ET son `type` est
///    dans [_tabularTypes]).
///
/// L'**ordre** suit l'ordre du schéma (l'`order` = index d'origine dans `schema`,
/// stable, indépendant du filtrage). Le [header] = `field.label ?? field.name`
/// (clé non résolue). Le [ZListColumn.format] est dérivé PUR du `type` (AC2).
List<ZListColumn> deriveColumns(
  List<ZFieldSpec> schema, {
  ZColumnPolicy? policy,
}) {
  final columns = <ZListColumn>[];
  for (var index = 0; index < schema.length; index++) {
    final field = schema[index];
    if (!_isVisible(field, policy)) continue;
    columns.add(
      ZListColumn(
        name: field.name,
        header: field.label ?? field.name,
        type: field.type,
        order: index,
        width: _widthFor(field.type),
        format: _formatterFor(field),
      ),
    );
  }
  return columns;
}

/// Décide de la visibilité d'un champ selon la [policy] et sa nature (AC3).
bool _isVisible(ZFieldSpec field, ZColumnPolicy? policy) {
  if (policy != null && policy.forceExclude.contains(field.name)) return false;
  if (policy != null && policy.forceInclude.contains(field.name)) return true;
  if (field.isId) return false;
  return _tabularTypes.contains(field.type);
}

/// Largeur indicative **déterministe** par type (`null` = laissé au backend).
///
/// Heuristique compacte : champs booléens/notes/curseurs/couleurs étroits,
/// nombres médians, dates plus larges ; texte et le reste → `null` (le backend
/// répartit, ex. `ColumnWidthMode.fill`).
double? _widthFor(EditionFieldType type) {
  switch (type) {
    case EditionFieldType.boolean:
    case EditionFieldType.rating:
    case EditionFieldType.slider:
    case EditionFieldType.color:
      return 96;
    case EditionFieldType.number:
    case EditionFieldType.integer:
    case EditionFieldType.float:
      return 120;
    case EditionFieldType.dateTime:
    case EditionFieldType.time:
      return 180;
    // ignore: no_default_cases
    default:
      return null;
  }
}

/// Fabrique une fonction de format **PURE** `raw → String` pour [field] (AC2).
///
/// Locale-neutre, **ne lève jamais** (désérialisation défensive, AD-10) :
/// - `null` → `''` ;
/// - `select`/`radio`/`checkbox` → libellé de choix résolu depuis
///   `field.choices` (`raw == choice.value` → `choice.label`), repli
///   `raw.toString()` ;
/// - champ `multiple` / `tags` / `rowChips` ou valeur `Iterable` → éléments
///   joints par `', '` (chacun formaté récursivement de façon neutre) ;
/// - `dateTime`/`time` → ISO-8601 si `raw is DateTime`, sinon `raw.toString()` ;
/// - `number`/`integer`/`float`/`boolean` → `raw.toString()` (formatage
///   locale-aware **déféré E4-3**) ;
/// - défaut → `raw?.toString() ?? ''`.
String Function(Object? raw) _formatterFor(ZFieldSpec field) {
  final type = field.type;
  final choices = field.choices;

  // Format d'un élément SCALAIRE (résolution de choix / date), jamais d'Iterable.
  String scalar(Object? value) {
    if (value == null) return '';
    switch (type) {
      case EditionFieldType.select:
      case EditionFieldType.radio:
      case EditionFieldType.checkbox:
        return _resolveChoice(choices, value);
      case EditionFieldType.dateTime:
      case EditionFieldType.time:
        return value is DateTime ? value.toIso8601String() : value.toString();
      // ignore: no_default_cases
      default:
        return value.toString();
    }
  }

  final isMultiple = field.multiple ||
      type == EditionFieldType.tags ||
      type == EditionFieldType.rowChips;

  return (Object? raw) {
    if (raw == null) return '';
    if (isMultiple || raw is Iterable) {
      final iterable = raw is Iterable ? raw : <Object?>[raw];
      return iterable.map(scalar).join(', ');
    }
    return scalar(raw);
  };
}

/// Résout le libellé d'un choix statique (`raw == choice.value` → `label`),
/// repli `raw.toString()` si aucune option ne correspond.
String _resolveChoice(List<ZFieldChoice> choices, Object? raw) {
  for (final choice in choices) {
    if (choice.value == raw) return choice.label;
  }
  return raw.toString();
}
