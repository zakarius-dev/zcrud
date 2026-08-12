/// Colonne de liste **dérivée du schéma** + helper de dérivation PUR, neutres du
/// cœur `zcrud_core`.
///
/// Le port neutre `ZListRenderer` pourrait recevoir une projection **brute**
/// `columns: List<ZFieldSpec>` 1:1, mais ce fichier introduit la **dérivation
/// FINE** : à partir du `ZFieldSpec[]`, décider **quels champs** sont affichés
/// en liste (visibilité), **comment formater** chaque cellule par
/// `EditionFieldType`, le **libellé**, l'**ordre** et une **largeur**
/// indicative.
///
/// **Neutre, Material-free, `const`-compatible** : ce fichier n'importe QUE
/// `package:flutter/foundation.dart` (`@immutable`) + types `zcrud_core`. AUCUN
/// widget, AUCUN `BuildContext`, AUCUN `package:syncfusion`, aucune dépendance
/// lourde (gardes `presentation_purity_test`/`no_heavy_file_dep_test`). Le
/// **formatage vit ici une seule fois** (pur, locale-neutre) ; le backend
/// (`SfDataGrid` dans `zcrud_list`, ou tout autre) consomme les `ZListColumn`
/// sans re-dériver ni dupliquer de logique de format.
///
/// **Frontière** : le formatage **locale-aware** des nombres/dates/booléens
/// est **déféré** au contrôleur de liste (hook injecté / labels) ; recherche/
/// tri/pagination et actions/`ZAcl` de même. On ne porte ici QUE la dérivation
/// pure.
library;

import 'package:flutter/foundation.dart';

import '../../domain/edition/edition_field_type.dart';
import '../../domain/edition/z_field_choice.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/ports/z_date_display_formatter.dart';

/// Types **scalaires/affichables** en tableau (whitelist de visibilité).
///
/// Tout `EditionFieldType` ABSENT de cet ensemble est **exclu par défaut** de la
/// liste : soit lourd/non-tabulaire (`subItems`, `dynamicItem`, `file`, `image`,
/// `document`, `location`, `geoArea`, `address`, `signature`, `markdown`/
/// `richText`/`html`…), soit non rendu (`hidden`), soit nécessitant une
/// résolution runtime (`relation`, `widget`, `custom`, `stepper`, `password`,
/// `icon`). L'appelant peut forcer l'inclusion d'un tel champ via
/// [ZColumnPolicy.forceInclude] (point d'extension additif, AD-4), sans toucher
/// aux annotations `@ZcrudField` (gelées).
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
/// annotations `@ZcrudField` (gelées). Point d'extension `const`-compatible.
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

/// **Seams d'affichage** d'une colonne de liste : le petit sac
/// de valeurs que la closure [ZListColumn.format] ne peut PAS aller chercher
/// elle-même, faute de `BuildContext`.
///
/// ## Pourquoi un sac de valeurs et pas un `BuildContext`
///
/// [ZListColumn.format] est une closure `String Function(Object? raw)` invoquée
/// **hors de tout `build`** : le backend `SfDataGrid` l'appelle depuis
/// `DataGridSource.update`, et `zcrud_export` l'appelle **headless** (aucun
/// arbre de widgets n'existe). Lui passer un `BuildContext` casserait la
/// signature publique du port de liste ET serait impossible à honorer côté
/// export. La projection **capture** donc, au moment de la dérivation (qui, elle,
/// a un contexte : `DynamicList._buildReady`), les seules valeurs dont elle a
/// besoin. Cf. `ZListFormat.of` (fabrique contextuelle, dans `dynamic_list.dart`).
///
/// ## Hôte passif immobile (AD-10)
///
/// Chaque champ est **nullable**, et `null` ⇒ **exactement** le rendu d'avant :
/// - [orphanChoiceLabel] `null` ⇒ une valeur orpheline retombe sur `raw.toString()` ;
/// - [dateFormatter] `null` ⇒ la date reste rendue en ISO/brut.
///
/// ## Égalité de valeur — NON décorative
///
/// `ZListColumn`/`ZListRenderRequest` ont une égalité de **valeur** dont le
/// backend se sert pour décider s'il doit reconstruire ses cellules
/// (`widget.request != old.request` dans `zcrud_list`). Comme deux colonnes
/// identiques rendues sous des seams différents produisent des **textes
/// différents**, [ZListFormat] participe à `==`/`hashCode` de [ZListColumn] :
/// sans cela, un changement de locale ou d'injection du port laisserait la
/// grille afficher ses anciennes chaînes.
///
/// Corollaire (AD-2) : l'instance de [dateFormatter] doit être **stable**
/// (`const` ou mémoïsée hors `build`) — une instance recréée à chaque build
/// rendrait les requêtes perpétuellement inégales.
@immutable
class ZListFormat {
  /// Construit les seams d'affichage. Tout champ omis ⇒ rendu d'origine.
  const ZListFormat({
    this.orphanChoiceLabel,
    this.dateFormatter,
    this.localeTag,
  });

  /// Libellé **déjà résolu** (jamais une clé) d'une valeur de choix
  /// **orpheline** — présente dans la donnée mais absente des options.
  ///
  /// Règle propagée à `DynamicList` : *une identité non résolue est
  /// rendue sous un libellé localisé ; la clé technique n'apparaît jamais*. La
  /// résolution l10n (`ZcrudScope.labels` > delegate > table `en`) est faite par
  /// l'appelant qui a le contexte — le cœur ne code aucun texte en dur.
  final String? orphanChoiceLabel;

  /// Port d'affichage des dates (`ZcrudScope.dateDisplayFormatter`), capturé.
  /// `null` ⇒ ISO/brut, comme avant le port.
  final ZDateDisplayFormatter? dateFormatter;

  /// BCP-47 de la locale ambiante transmise au port (`null` ⇒ locale par défaut
  /// de l'implémentation).
  final String? localeTag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListFormat &&
          runtimeType == other.runtimeType &&
          orphanChoiceLabel == other.orphanChoiceLabel &&
          dateFormatter == other.dateFormatter &&
          localeTag == other.localeTag;

  @override
  int get hashCode =>
      Object.hash(runtimeType, orphanChoiceLabel, dateFormatter, localeTag);

  @override
  String toString() => 'ZListFormat(orphanChoiceLabel: $orphanChoiceLabel, '
      'dateFormatter: ${dateFormatter?.runtimeType}, localeTag: $localeTag)';
}

/// Colonne de liste **neutre, immuable, `const`-compatible, Material-free**,
/// dérivée d'un `ZFieldSpec` par [deriveColumns].
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
    this.formatting = const ZListFormat(),
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

  /// Fonction de format `raw → String` (ne lève jamais, AD-10). **Déterministe
  /// à [formatting] donné** : elle ne lit aucun état ambiant, elle a *capturé*
  /// ses seams.
  final String Function(Object? raw) format;

  /// Seams d'affichage capturés dont [format] dépend (cf. [ZListFormat]).
  /// Par défaut vide ⇒ rendu locale-neutre non enrichi.
  final ZListFormat formatting;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListColumn &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          header == other.header &&
          type == other.type &&
          order == other.order &&
          width == other.width &&
          // Deux colonnes de mêmes métadonnées mais de seams DIFFÉRENTS rendent
          // des textes différents : les égaler ferait manquer au backend la
          // reconstruction de ses cellules (cf. dartdoc de [ZListFormat]).
          formatting == other.formatting;

  @override
  int get hashCode =>
      Object.hash(runtimeType, name, header, type, order, width, formatting);

  @override
  String toString() =>
      'ZListColumn(name: $name, header: $header, type: ${type.name}, '
      'order: $order, width: $width, formatting: $formatting)';
}

/// Projette un `ZFieldSpec[]` en une **liste ordonnée** de [ZListColumn].
/// **PUR** : aucun `BuildContext`, aucun widget, aucun I/O,
/// **déterministe** (même entrée → même sortie).
///
/// Règles de visibilité — un champ est INCLUS ssi :
/// 1. il n'est PAS dans `policy.forceExclude` ; ET
/// 2. il est dans `policy.forceInclude` **OU** (`!field.isId` ET son `type` est
///    dans [_tabularTypes]).
///
/// ⚠️ **Escamotage silencieux** : un champ dont le type n'est PAS dans la liste
/// blanche tabulaire (ou qui est `isId`) est **omis sans erreur ni log** — un
/// consommateur qui déclare une colonne et ne la voit pas apparaître doit
/// chercher ici. Pour le **constater**, comparer le résultat au schéma
/// (`columns.length` vs `schema.length`, ou l'absence du `name` attendu) ;
/// pour l'**inclure malgré tout**, passer
/// `ZColumnPolicy(forceInclude: {'monChamp'})`.
///
/// L'**ordre** suit l'ordre du schéma (l'`order` = index d'origine dans `schema`,
/// stable, indépendant du filtrage). Le [header] = `field.label ?? field.name`
/// (clé non résolue). Le [ZListColumn.format] est dérivé PUR du `type`.
List<ZListColumn> deriveColumns(
  List<ZFieldSpec> schema, {
  ZColumnPolicy? policy,
  ZListFormat formatting = const ZListFormat(),
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
        format: _formatterFor(field, formatting),
        formatting: formatting,
      ),
    );
  }
  return columns;
}

/// Décide de la visibilité d'un champ selon la [policy] et sa nature.
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

/// Fabrique la fonction de format `raw → String` pour [field], sous les
/// seams [formatting] **capturés** (cf. [ZListFormat]).
///
/// **Ne lève jamais** (désérialisation défensive, AD-10) :
/// - `null` → `''` ;
/// - `select`/`radio`/`checkbox` → libellé de choix résolu depuis
///   `field.choices` (`raw == choice.value` → `choice.label`) ; valeur
///   **orpheline** → `formatting.orphanChoiceLabel` s'il est
///   fourni, sinon repli `raw.toString()` ;
/// - champ `multiple` / `tags` / `rowChips` ou valeur `Iterable` → éléments
///   joints par `', '` (chacun formaté récursivement de façon neutre) ;
/// - `dateTime`/`time` → `formatting.dateFormatter` s'il est fourni (règle de
///   repli partagée `zDateDisplayTextOf`), sinon ISO-8601 si `raw is DateTime`,
///   sinon `raw.toString()` ;
/// - `number`/`integer`/`float`/`boolean` → `raw.toString()` (formatage
///   locale-aware **déféré** — le rendre ici déplacerait tout hôte passif) ;
/// - défaut → `raw?.toString() ?? ''`.
String Function(Object? raw) _formatterFor(
  ZFieldSpec field,
  ZListFormat formatting,
) {
  final type = field.type;
  final choices = field.choices;
  final dateMode = zDateModeOf(
    field.config,
    isTimeType: type == EditionFieldType.time,
  );

  // Format d'un élément SCALAIRE (résolution de choix / date), jamais d'Iterable.
  String scalar(Object? value) {
    if (value == null) return '';
    switch (type) {
      case EditionFieldType.select:
      case EditionFieldType.radio:
      case EditionFieldType.checkbox:
        return _resolveChoice(choices, value, formatting.orphanChoiceLabel);
      case EditionFieldType.dateTime:
      case EditionFieldType.time:
        // Un `DateTime` est NORMALISÉ en ISO **avant** d'entrer dans la règle
        // partagée : son repli est `'$value'`, et `DateTime.toString()` n'est
        // PAS l'ISO. Sans cette normalisation, un port absent/en échec ferait
        // basculer la cellule de `2026-07-10T08:30:00.000Z` à
        // `2026-07-10 08:30:00.000Z` — un hôte passif déplacé. L'ISO se reparse
        // à l'identique (`DateTime.tryParse`), le port reçoit donc la même date.
        return zDateDisplayTextOf(
          formatting.dateFormatter,
          value is DateTime ? value.toIso8601String() : value,
          mode: dateMode,
          localeTag: formatting.localeTag,
        );
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

/// Résout le libellé d'un choix statique (`raw == choice.value` → `label`).
///
/// Valeur **orpheline** (aucune option ne correspond) : rend [orphanLabel] — le
/// libellé localisé, *déjà résolu* par l'appelant qui a le
/// contexte. **La clé technique n'est jamais montrée à l'utilisateur.**
///
/// [orphanLabel] `null` ⇒ repli `raw.toString()` : c'est le cas des
/// appelants **headless** (`zcrud_export`) et de tout appel direct à
/// `deriveColumns` sans seams, pour lesquels aucune l10n n'est atteignable — et
/// où coder un texte en dur serait interdit.
String _resolveChoice(
  List<ZFieldChoice> choices,
  Object? raw,
  String? orphanLabel,
) {
  for (final choice in choices) {
    if (choice.value == raw) return choice.label;
  }
  return orphanLabel ?? raw.toString();
}
