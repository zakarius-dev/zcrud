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

/// **Colonne de numéro d'ordre** (« # ») déclarée dans le cœur, donc disponible
/// pour **tous** les rendus (tableau, cartes, grille, export) et non plus pour
/// un seul backend.
///
/// ## La règle de numérotation, une seule fois
///
/// La numérotation est **1-based sur la séquence RENDUE** : la première ligne
/// affichée porte `1`, la deuxième `2`, quel que soit l'ordre d'origine des
/// données. C'est [textAt] qui porte cette règle, et c'est la seule : un
/// backend ne recalcule pas « son » ordinal, il appelle [textAt] (ou
/// [textsFor]) avec la **position d'affichage**.
///
/// ## Pourquoi le numéro n'est pas une donnée de la ligne
///
/// Le numéro n'est **jamais** rangé dans `ZListRow.cells` : ce serait le figer
/// au moment où les lignes sont construites, et un tri le ferait voyager avec
/// sa ligne — l'utilisateur verrait alors `3, 1, 2` après avoir trié. En le
/// dérivant de la **position d'affichage** au moment du rendu, la colonne reste
/// une numérotation de l'écran, pas une propriété de la donnée.
///
/// ## Pagination
///
/// Deux réglages, pour deux situations qui n'ont pas le même propriétaire.
///
/// | Réglage | Qui connaît la page | Effet |
/// |---|---|---|
/// | [pageOffset] | l'**application** tranche elle-même ses pages | décalage FIXE, déclaré une fois |
/// | [continuousAcrossPages] | le **rendu** pagine (pager interne) | le rendu ajoute lui-même le décalage de la page qu'il peint |
///
/// `0` / `false` (défauts) numérotent la **page rendue** à partir de `1` —
/// chaque page repart de 1.
///
/// [pageOffset] suppose que l'hôte sache dans quelle page il se trouve : c'est
/// vrai d'une pagination faite par l'application ou par le backend, faux dès
/// que le rendu pagine lui-même (l'index de page vit alors chez lui, et l'hôte
/// n'apprend jamais qu'il a changé — la numérotation continue y était
/// simplement inatteignable). [continuousAcrossPages] renverse la charge : la
/// **règle** reste ici, seule la **position** vient du rendu, qui appelle
/// [textAt] avec la page qu'il est en train de peindre.
///
/// Les deux se composent : [pageOffset] reste ajouté en tête (une liste qui
/// démarre à un rang connu, paginée par le rendu).
///
/// ```dart
/// const ZColumnPolicy(ordinal: ZListOrdinal(enabled: true));
/// // Numérotation continue sous un pager de rendu :
/// const ZListOrdinal(enabled: true, continuousAcrossPages: true);
/// ```
@immutable
class ZListOrdinal {
  /// Construit la déclaration de la colonne d'ordre. Désactivée par défaut :
  /// omettre ce réglage laisse le rendu **strictement** inchangé.
  const ZListOrdinal({
    this.enabled = false,
    this.header = '#',
    this.width = 56,
    this.pageOffset = 0,
    this.continuousAcrossPages = false,
  });

  /// Nom de colonne **réservé** de la numérotation.
  ///
  /// Sert aux backends et aux exports à reconnaître (et, pour un export, à
  /// exclure) la colonne technique sans la confondre avec un champ du schéma.
  /// Le préfixe `__` le met hors d'atteinte d'un `field.name` réel.
  static const String columnName = '__z_ordinal';

  /// `true` pour afficher la colonne de numéro d'ordre.
  final bool enabled;

  /// En-tête de la colonne. Défaut `'#'` : un symbole ordinal universel, qui
  /// ne se traduit pas et n'introduit donc aucune clé de libellé.
  final String header;

  /// Largeur indicative de la colonne, en pixels logiques.
  final double width;

  /// Décalage FIXE ajouté à la numérotation (cf. la section *Pagination*).
  final int pageOffset;

  /// `true` ⇒ la numérotation est **continue d'une page à l'autre** quand
  /// c'est le rendu qui pagine : la deuxième page d'un pager de 20 lignes
  /// commence à `21`, et non à `1`.
  ///
  /// N'a d'effet que si le rendu renseigne [textAt] avec la page qu'il peint
  /// ([pageIndex]/[pageSize]) — un rendu non paginé, ou qui ne transmet pas sa
  /// page, numérote comme avant. Défaut `false` ⇒ chaque page repart de `1`.
  final bool continuousAcrossPages;

  /// Numéro affiché pour la ligne rendue en position [displayIndex]
  /// (**0-based**) de la page [pageIndex] (**0-based**), sur des pages de
  /// [pageSize] lignes.
  ///
  /// [displayIndex] est la position **à l'écran**, après tri et filtrage —
  /// jamais l'index de la ligne dans les données d'origine.
  ///
  /// [pageIndex]/[pageSize] ne sont lus que si [continuousAcrossPages] est
  /// `true` ; un rendu non paginé les omet (défauts `0`), et le numéro vaut
  /// alors `pageOffset + displayIndex + 1` — la règle historique, à
  /// l'identique.
  String textAt(int displayIndex, {int pageIndex = 0, int pageSize = 0}) {
    final paged = continuousAcrossPages ? pageIndex * pageSize : 0;
    return '${pageOffset + paged + displayIndex + 1}';
  }

  /// Numéros de [displayedRowCount] lignes consécutives, dans l'ordre
  /// d'affichage : `['1', '2', '3', …]`. [pageIndex]/[pageSize] : voir [textAt].
  List<String> textsFor(
    int displayedRowCount, {
    int pageIndex = 0,
    int pageSize = 0,
  }) =>
      <String>[
        for (var i = 0; i < displayedRowCount; i++)
          textAt(i, pageIndex: pageIndex, pageSize: pageSize),
      ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListOrdinal &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          header == other.header &&
          width == other.width &&
          pageOffset == other.pageOffset &&
          continuousAcrossPages == other.continuousAcrossPages;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        enabled,
        header,
        width,
        pageOffset,
        continuousAcrossPages,
      );

  @override
  String toString() => 'ZListOrdinal(enabled: $enabled, header: $header, '
      'width: $width, pageOffset: $pageOffset, '
      'continuousAcrossPages: $continuousAcrossPages)';
}

/// Place du code monétaire par rapport au montant.
enum ZCurrencyPlacement {
  /// Le code précède le montant : `XOF 1 500`.
  prefix,

  /// Le code suit le montant : `1 500 XOF`.
  suffix,
}

/// **Format monétaire d'une colonne, dont la devise peut venir de la LIGNE.**
///
/// Un tableau de factures peut mêler des montants en euros, en francs CFA et en
/// dollars : la devise n'est alors pas un réglage de la colonne mais une
/// **valeur portée par chaque ligne** ([codeField] désigne le champ qui la
/// porte). Une colonne à devise fixe afficherait des montants parfaitement
/// formatés et **faux**, sans la moindre alerte.
///
/// ## La règle du repli, sans mémoire
///
/// La devise est résolue **ligne par ligne, sans aucun état conservé d'une
/// ligne à l'autre** : une ligne dont le champ [codeField] est absent, `null`
/// ou vide retombe sur [fallbackCode] — **jamais** sur la devise d'une autre
/// ligne. C'est la garantie centrale de ce format : mieux vaut un repli visible
/// et déclaré qu'un montant plausible attribué à la mauvaise monnaie.
///
/// [fallbackCode] est donc **obligatoire** : il n'existe pas de configuration
/// où le repli serait indéterminé.
///
/// ```dart
/// const ZCurrencyFormat(codeField: 'currency', fallbackCode: 'XOF');
/// // ligne {amount: 1500, currency: 'EUR'} → « 1500 EUR »
/// // ligne {amount: 1500}                  → « 1500 XOF »  (repli déclaré)
/// ```
///
/// **Locale-neutre** : aucun séparateur de milliers, aucun symbole localisé.
/// Comme le reste de la dérivation, ce format est pur et sans `BuildContext` —
/// une application qui veut un rendu localisé passe par [ZListColumn.formatWithRow].
@immutable
class ZCurrencyFormat {
  /// Construit le format monétaire. [fallbackCode] est requis : c'est le code
  /// affiché quand la ligne n'en porte pas.
  const ZCurrencyFormat({
    required this.fallbackCode,
    this.codeField,
    this.decimalDigits,
    this.placement = ZCurrencyPlacement.suffix,
    this.separator = ' ',
  });

  /// Nom du champ de la ligne portant le **code devise** (ex. `'currency'`).
  ///
  /// `null` ⇒ la colonne est à devise fixe : toutes les lignes affichent
  /// [fallbackCode].
  final String? codeField;

  /// Code affiché quand la ligne ne porte pas de devise exploitable (champ
  /// absent, `null`, ou chaîne vide). **Jamais** la devise d'une autre ligne.
  final String fallbackCode;

  /// Nombre de décimales imposé au montant. `null` ⇒ le montant est rendu tel
  /// quel, sans arrondi ni complétion.
  final int? decimalDigits;

  /// Place du code par rapport au montant (défaut : après).
  final ZCurrencyPlacement placement;

  /// Séparateur inséré entre le montant et le code (défaut : une espace).
  final String separator;

  /// Code devise **de cette ligne** : la valeur de [codeField] si elle est
  /// exploitable, sinon [fallbackCode].
  ///
  /// Fonction **pure** : le résultat ne dépend que de [row]. Deux appels
  /// successifs sur deux lignes différentes ne partagent rien.
  String codeFor(Map<String, Object?> row) {
    final field = codeField;
    if (field == null) return fallbackCode;
    final raw = row[field];
    if (raw == null) return fallbackCode;
    final code = raw.toString().trim();
    if (code.isEmpty) return fallbackCode;
    return code;
  }

  /// Rend le montant [raw] de la ligne [row] avec **sa** devise.
  ///
  /// Ne lève jamais (AD-10) : un montant `null` rend la chaîne vide (et non un
  /// code devise esseulé) ; un montant non numérique est rendu tel quel, avec
  /// sa devise.
  String textFor(Object? raw, Map<String, Object?> row) {
    if (raw == null) return '';
    final digits = decimalDigits;
    final number = raw is num ? raw : num.tryParse(raw.toString());
    final amount = (number != null && digits != null)
        ? number.toStringAsFixed(digits)
        : raw.toString();
    final code = codeFor(row);
    return placement == ZCurrencyPlacement.prefix
        ? '$code$separator$amount'
        : '$amount$separator$code';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZCurrencyFormat &&
          runtimeType == other.runtimeType &&
          codeField == other.codeField &&
          fallbackCode == other.fallbackCode &&
          decimalDigits == other.decimalDigits &&
          placement == other.placement &&
          separator == other.separator;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        codeField,
        fallbackCode,
        decimalDigits,
        placement,
        separator,
      );

  @override
  String toString() => 'ZCurrencyFormat(codeField: $codeField, '
      'fallbackCode: $fallbackCode, decimalDigits: $decimalDigits, '
      'placement: ${placement.name}, separator: "$separator")';
}

/// **Réglages d'une colonne précise**, appliqués par [deriveColumns] par-dessus
/// ce que le schéma dicte.
///
/// Le schéma reste la source de vérité : cet objet ne sert qu'à ce qui **n'est
/// pas dérivable** d'une déclaration de champ — l'encombrement voulu à l'écran,
/// une devise portée par une autre colonne, un format qui a besoin de toute la
/// ligne. Tout champ omis laisse la valeur dérivée intacte.
///
/// ```dart
/// ZColumnPolicy(
///   overrides: {
///     'amount': const ZColumnOverride(
///       minWidth: 120,
///       currency: ZCurrencyFormat(codeField: 'currency', fallbackCode: 'XOF'),
///     ),
///   },
/// );
/// ```
@immutable
class ZColumnOverride {
  /// Construit des réglages de colonne. Tout champ omis ⇒ valeur dérivée.
  const ZColumnOverride({
    this.header,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.currency,
    this.formatWithRow,
  });

  /// Remplace le libellé/clé d'en-tête dérivé (`field.label ?? field.name`).
  final String? header;

  /// Remplace la largeur indicative dérivée du type.
  final double? width;

  /// Largeur **minimale** de la colonne, en pixels logiques (cf.
  /// [ZListColumn.minWidth]).
  final double? minWidth;

  /// Largeur **maximale** de la colonne, en pixels logiques (cf.
  /// [ZListColumn.maxWidth]).
  final double? maxWidth;

  /// Format monétaire, éventuellement à devise portée par la ligne.
  final ZCurrencyFormat? currency;

  /// Format recevant **toute la ligne** (cf. [ZListColumn.formatWithRow]).
  final String Function(Object? raw, Map<String, Object?> row)? formatWithRow;

  /// Égalité de **valeur** sur les réglages déclaratifs uniquement.
  ///
  /// [formatWithRow] est une **fonction** : deux closures écrites à l'identique
  /// ne sont jamais égales en Dart, et deux instances créées dans un `build`
  /// le seraient encore moins. La faire entrer dans l'égalité rendrait toute
  /// politique perpétuellement différente d'elle-même et priverait le rendu de
  /// sa mémoïsation. Elle en est donc exclue — même règle que
  /// [ZListColumn.format] et `ZFieldSpec`.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZColumnOverride &&
          runtimeType == other.runtimeType &&
          header == other.header &&
          width == other.width &&
          minWidth == other.minWidth &&
          maxWidth == other.maxWidth &&
          currency == other.currency;

  @override
  int get hashCode =>
      Object.hash(runtimeType, header, width, minWidth, maxWidth, currency);

  @override
  String toString() => 'ZColumnOverride(header: $header, width: $width, '
      'minWidth: $minWidth, maxWidth: $maxWidth, currency: $currency)';
}

/// **Politique de colonnes** additive (AD-4) : permet à l'appelant de forcer
/// l'inclusion/exclusion d'un champ par `name`, de régler une colonne précise
/// ([overrides]) et de demander la colonne de numéro d'ordre ([ordinal]), SANS
/// modifier `ZFieldSpec` ni les annotations `@ZcrudField` (gelées). Point
/// d'extension `const`-compatible.
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
    this.overrides = const <String, ZColumnOverride>{},
    this.ordinal = const ZListOrdinal(),
  });

  /// Noms de champs à **inclure** même si leur type ne serait pas tabulaire
  /// (ou s'ils sont `isId`). Prioritaire sur la visibilité par défaut.
  final Set<String> forceInclude;

  /// Noms de champs à **exclure** quoi qu'il arrive. Prioritaire sur tout.
  final Set<String> forceExclude;

  /// Réglages par nom de colonne (largeurs, devise, format sur la ligne).
  /// Une clé qui ne correspond à aucune colonne affichée est simplement sans
  /// effet — jamais une erreur (AD-10).
  final Map<String, ZColumnOverride> overrides;

  /// Colonne de **numéro d'ordre**. Désactivée par défaut : la déclaration ne
  /// change rien tant que `enabled` n'est pas vrai.
  final ZListOrdinal ordinal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZColumnPolicy &&
          runtimeType == other.runtimeType &&
          setEquals(forceInclude, other.forceInclude) &&
          setEquals(forceExclude, other.forceExclude) &&
          mapEquals(overrides, other.overrides) &&
          ordinal == other.ordinal;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAllUnordered(forceInclude),
        Object.hashAllUnordered(forceExclude),
        Object.hashAllUnordered(
          overrides.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        ordinal,
      );

  @override
  String toString() =>
      'ZColumnPolicy(forceInclude: $forceInclude, forceExclude: $forceExclude, '
      'overrides: ${overrides.keys.toList()}, ordinal: $ordinal)';
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
    this.minWidth,
    this.maxWidth,
    this.currency,
    this.formatWithRow,
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

  /// Largeur **minimale** de la colonne, en pixels logiques, ou `null`
  /// (aucune borne).
  ///
  /// C'est une contrainte d'**encombrement à l'écran**, pas une borne sur la
  /// valeur affichée ni un filtre : elle empêche la colonne de se réduire en
  /// deçà de cette largeur quand le backend répartit l'espace disponible. Un
  /// backend qui ne sait pas contraindre ses colonnes ignore simplement ce
  /// réglage.
  final double? minWidth;

  /// Largeur **maximale** de la colonne, en pixels logiques, ou `null` (aucune
  /// borne). Même nature que [minWidth] : de l'encombrement, pas de la valeur.
  final double? maxWidth;

  /// Format monétaire de la colonne, éventuellement à **devise portée par la
  /// ligne** (cf. [ZCurrencyFormat]). `null` ⇒ colonne non monétaire.
  ///
  /// N'a d'effet qu'à travers [formatRow], qui seul dispose de la ligne.
  final ZCurrencyFormat? currency;

  /// Format recevant, en plus de la valeur de la cellule, **toute la ligne** —
  /// pour les affichages dérivés d'un autre champ (un suffixe d'unité rangé
  /// dans une colonne voisine, un montant et sa devise, un libellé composé).
  ///
  /// `null` ⇒ le rendu reste celui de [format]. Déclaré, il **prime** sur
  /// [currency] et sur [format] dans [formatRow] : c'est l'échappatoire de
  /// dernier ressort, celle qui peut tout.
  ///
  /// Comme [format], il ne doit **jamais lever** (AD-10) et est **exclu de
  /// l'égalité de valeur** (cf. `operator ==`).
  final String Function(Object? raw, Map<String, Object?> row)? formatWithRow;

  /// Seams d'affichage capturés dont [format] dépend (cf. [ZListFormat]).
  /// Par défaut vide ⇒ rendu locale-neutre non enrichi.
  final ZListFormat formatting;

  /// Texte de la cellule de cette colonne pour la ligne [row], **en connaissant
  /// toute la ligne**.
  ///
  /// C'est le point d'entrée que les backends doivent appeler quand la ligne
  /// leur est accessible : il fait exactement ce que fait [format] tant
  /// qu'aucune capacité dépendant de la ligne n'est déclarée, et l'honore
  /// sinon. Précédence : [formatWithRow] > [currency] > [format].
  ///
  /// [raw] est la valeur de la cellule (`row[name]` par convention) ; elle est
  /// passée explicitement pour qu'un backend disposant déjà de la valeur
  /// n'ait pas à la ré-extraire.
  ///
  /// **Sans mémoire d'un appel à l'autre** : le résultat ne dépend que de
  /// [raw] et de [row]. C'est ce qui garantit qu'une ligne sans devise retombe
  /// sur le repli déclaré et jamais sur la devise de la ligne précédente.
  String formatRow(Object? raw, Map<String, Object?> row) {
    final withRow = formatWithRow;
    if (withRow != null) return withRow(raw, row);
    final money = currency;
    if (money != null) return money.textFor(raw, row);
    return format(raw);
  }

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
          minWidth == other.minWidth &&
          maxWidth == other.maxWidth &&
          // Réglage déclaratif pur : deux colonnes de devises différentes
          // rendent des textes différents, elles doivent être distinguées.
          currency == other.currency &&
          // [formatWithRow] est ABSENT de l'égalité : c'est une fonction, et
          // deux fonctions écrites à l'identique ne sont jamais égales en Dart.
          // L'y faire entrer rendrait chaque requête de rendu différente de la
          // précédente et casserait la mémoïsation du backend — même règle que
          // [format], que `ZFieldSpec.derivedFrom`/`choicesResolver` et que
          // `DynamicList.entityFor`.
          // Deux colonnes de mêmes métadonnées mais de seams DIFFÉRENTS rendent
          // des textes différents : les égaler ferait manquer au backend la
          // reconstruction de ses cellules (cf. dartdoc de [ZListFormat]).
          formatting == other.formatting;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        name,
        header,
        type,
        order,
        width,
        minWidth,
        maxWidth,
        currency,
        formatting,
      );

  @override
  String toString() =>
      'ZListColumn(name: $name, header: $header, type: ${type.name}, '
      'order: $order, width: $width, minWidth: $minWidth, '
      'maxWidth: $maxWidth, currency: $currency, formatting: $formatting)';
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
///
/// `policy.overrides` applique, colonne par colonne, ce que le schéma ne peut
/// pas dire : largeurs `minWidth`/`maxWidth`, format monétaire à devise portée
/// par la ligne, format recevant la ligne entière (cf. [ZColumnOverride]). Une
/// entrée sans colonne correspondante est sans effet.
///
/// La colonne de **numéro d'ordre** (`policy.ordinal`) n'apparaît PAS dans le
/// résultat : elle n'est pas dérivée d'un champ et son contenu dépend de la
/// position d'affichage. Elle est portée par `ZListRenderRequest.ordinal` et
/// rendue par le backend (cf. [ZListOrdinal]).
List<ZListColumn> deriveColumns(
  List<ZFieldSpec> schema, {
  ZColumnPolicy? policy,
  ZListFormat formatting = const ZListFormat(),
}) {
  final columns = <ZListColumn>[];
  for (var index = 0; index < schema.length; index++) {
    final field = schema[index];
    if (!_isVisible(field, policy)) continue;
    final override = policy?.overrides[field.name];
    columns.add(
      ZListColumn(
        name: field.name,
        header: override?.header ?? field.label ?? field.name,
        type: field.type,
        order: index,
        width: override?.width ?? _widthFor(field.type),
        minWidth: override?.minWidth,
        maxWidth: override?.maxWidth,
        currency: override?.currency,
        formatWithRow: override?.formatWithRow,
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
