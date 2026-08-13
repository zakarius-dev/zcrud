/// Projection **runtime** d'un champ du schéma `zcrud` — l'image de
/// `@ZcrudField` (+ `@ZcrudId`) émise par le générateur (invariant AD-3).
///
/// Le générateur `zcrud_generator` lit les annotations `const` du modèle
/// (lues statiquement par `ConstantReader`) et **émet** une `const
/// List` de [ZFieldSpec] par modèle, projetant 1:1 les annotations
/// (`name/label/type/validators/config/choices/condition/searchable/
/// defaultValue/readOnly/showIfNull/multiple/isId`) avec **inférence de `type`**
/// quand `@ZcrudField.type == null`.
///
/// **Pur-données `const`** (couche `domain`, pur-Dart — invariant AD-1) :
/// aucune closure, aucun widget, aucune dépendance Flutter. L'**interprétation**
/// (type→widget, validators→`FormBuilderValidators`, condition→visibilité)
/// vit dans le moteur d'édition ; ici on ne porte que la **donnée**.
///
/// Égalité de **valeur** (`==`/`hashCode`) : utile aux tests de projection et
/// à la mémoïsation runtime du moteur d'édition.
library;

import 'edition_field_type.dart';
import 'z_condition.dart';
import 'z_derivation.dart';
import 'z_field_adornment.dart';
import 'z_field_choice.dart';
import 'z_field_config.dart';
import 'z_field_size.dart';
import 'z_validator_spec.dart';

/// Résolveur de **choix conscients de l'état** d'un champ à choix
/// (`select`/`radio`/`checkbox`/`rowChips`).
///
/// Appelé **au rendu** du champ avec un lecteur [valueOf] donnant accès aux
/// valeurs courantes des autres tranches du formulaire (`valueOf('date')`,
/// `valueOf('pays')`, …). Le résultat remplace les options du champ ;
/// prioritaire sur [ZFieldSpec.choices] quand non-`null`.
///
/// Le moteur d'édition s'abonne de façon **granulaire** aux tranches lues par
/// le résolveur : changer la valeur d'un champ dont il dépend ne reconstruit
/// **que** le champ à choix concerné — jamais le formulaire entier.
typedef ZChoicesResolver = List<ZFieldChoice> Function(
  Object? Function(String name) valueOf,
);

/// Spécification `const` d'un champ du schéma `zcrud`, projetée depuis
/// `@ZcrudField`/`@ZcrudId` par le générateur `zcrud_generator`.
class ZFieldSpec {
  /// Construit la spec `const` d'un champ.
  ///
  /// [name] est la **clé persistée** (dérivée du nom Dart via
  /// `@ZcrudModel.fieldRename`, ou l'override `@ZcrudField.name`). [type] est
  /// fourni par `@ZcrudField.type` ou **inféré** du type Dart statique.
  const ZFieldSpec({
    required this.name,
    required this.type,
    this.label,
    this.validators = const <ZValidatorSpec>[],
    this.config,
    this.choices = const <ZFieldChoice>[],
    this.condition,
    this.searchable = false,
    this.defaultValue,
    this.readOnly = false,
    this.showIfNull = false,
    this.multiple = false,
    this.isId = false,
    this.fieldSize = ZFieldSize.normal,
    this.leading,
    this.prefix,
    this.suffix,
    this.hintText,
    this.helperText,
    this.derivedFrom,
    this.widgetKind,
    this.choicesResolver,
  });

  /// Clé persistée du champ (snake_case par défaut — invariant AD-3).
  ///
  /// Un **nom pointé** (`'vido.chef_equipe_poste_id'`) est admis et signifie un
  /// champ **imbriqué** du modèle. Le socle d'édition le traite comme une clé
  /// **plate** (une tranche par nom, point compris) : l'aplatissement à
  /// l'ouverture et le regroupement à la soumission se font **à la frontière**,
  /// via les utilitaires symétriques `zFlattenPaths`/`zRegroupPaths`
  /// (`z_path_values.dart`). L'écran CRUD assemblé (`zcrud_screen`) câble cette
  /// paire d'office.
  final String name;

  /// Type déclaratif du champ (fourni ou inféré).
  final EditionFieldType type;

  /// Libellé d'affichage (clé l10n ou littéral ; résolu côté UI par le moteur
  /// d'édition/de liste).
  final String? label;

  /// Validateurs déclaratifs (composés en `FormBuilderValidators` par le
  /// moteur d'édition).
  final List<ZValidatorSpec> validators;

  /// Config spécialisée par type (base d'extension `ZFieldConfig`).
  final ZFieldConfig? config;

  /// Options statiques pour `select`/`radio`/`checkbox`.
  final List<ZFieldChoice> choices;

  /// Visibilité conditionnelle déclarative (`displayCondition`) ; évaluée par
  /// le moteur d'édition.
  final ZCondition? condition;

  /// Participation à la recherche/filtre de la liste.
  final bool searchable;

  /// Valeur par défaut appliquée par `fromMap`/le moteur d'édition si la clé
  /// est absente.
  final Object? defaultValue;

  /// Champ non éditable (mode lecture).
  final bool readOnly;

  /// En **mode lecture global** (`DynamicEdition(readOnly: true)`), afficher le
  /// champ **même si sa valeur est vide/nulle**.
  ///
  /// **Défaut `false`** : un champ à valeur vide est **masqué** en lecture,
  /// sauf déclaration explicite `showIfNull: true`. Le flag est **inerte hors
  /// mode lecture** (édition/liste non affectées) — c'est une **donnée** de
  /// présentation, jamais une logique. Pour forcer l'affichage d'un champ vide
  /// en lecture, déclarer `showIfNull: true` (ou `@ZcrudField(showIfNull:
  /// true)`).
  final bool showIfNull;

  /// Multi-valeur (`List<…>` ou `multiple: true`).
  final bool multiple;

  /// `true` si le champ porte `@ZcrudId` (clé d'identité opaque).
  final bool isId;

  /// Variante de taille/layout du champ (défaut [ZFieldSize.normal]). `large`
  /// ⇒ rendu en Card (label au-dessus, champ interne bare). Ajout **additif**
  /// rétro-compatible : une spec sans `fieldSize` conserve le rendu inline
  /// par défaut.
  final ZFieldSize fieldSize;

  /// Ornement de **tête** — rendu hors bordure (`InputDecoration.icon` en
  /// normal, slot `ZLargeFieldCard.leading` en large). `null` par défaut
  /// (aucun slot). Pur-données.
  final ZFieldAdornment? leading;

  /// Ornement **préfixe interne** — `InputDecoration.prefix`/`prefixIcon`.
  /// `null` par défaut.
  final ZFieldAdornment? prefix;

  /// Ornement **suffixe interne** — `InputDecoration.suffix`/`suffixIcon` en
  /// normal, slot `ZLargeFieldCard.suffix` en large. Un suffixe dynamique
  /// (dépendant de l'état du formulaire) passe par
  /// `ZFieldAdornment.widget(kind)` (seam registre). `null` par défaut.
  final ZFieldAdornment? suffix;

  /// Texte indicatif — clé l10n ou littéral, injecté dans
  /// `InputDecoration.hintText`. `null` par défaut.
  final String? hintText;

  /// Texte d'aide sous le champ — clé l10n ou littéral, injecté dans
  /// `InputDecoration.helperText`. `null` par défaut.
  final String? helperText;

  /// **Dérivation déclarative** « ce champ dérive de ces champs-là ». `null`
  /// par défaut ⇒ comportement **strictement inchangé**.
  ///
  /// Seul membre de [ZFieldSpec] à porter des **closures** : il n'est donc PAS
  /// émis par le générateur (le schéma statique reste pur-données, lisible par
  /// `ConstantReader` — invariant AD-3) ; c'est une **surcharge runtime** posée
  /// par l'hôte (`spec.copyWith(derivedFrom: ...)`). Il est volontairement
  /// **exclu de `==`/`hashCode`** : deux specs ne diffèrent jamais par
  /// l'identité d'une closure (la mémoïsation runtime et les tests de
  /// projection restent valides).
  final ZDerivation? derivedFrom;

  /// **Discriminant de builder** pour les familles servies par le
  /// `ZWidgetRegistry` (`widget`, `custom`, markdown/géo/tél…, et la famille
  /// `boolean` quand un builder est enregistré).
  ///
  /// `null` par défaut ⇒ comportement **strictement inchangé** : le `kind`
  /// résolu reste `type.name` (`'widget'`, `'custom'`, …). Non-`null`, il est
  /// consulté **avant** le repli sur `type.name` : deux champs `widget` d'un
  /// même formulaire peuvent ainsi porter deux builders distincts
  /// (`widgetKind: 'aclMatrix'` / `widgetKind: 'planning'`), enregistrés sous
  /// leur `kind` respectif. Si aucun builder n'est enregistré sous
  /// [widgetKind], la résolution **retombe** sur `type.name` (défensif,
  /// invariant AD-10), puis sur le repli habituel.
  ///
  /// **Déclaration manuelle** : ce champ n'est pas émis par le générateur
  /// `zcrud_generator` — il se pose à la main dans la spec (ou via
  /// `copyWith(widgetKind: …)`). Le porter sur `@ZcrudField` serait une
  /// évolution séparée.
  final String? widgetKind;

  /// **Choix dérivés d'autres champs** — résolveur consulté au rendu,
  /// prioritaire sur [choices] quand non-`null` (cf. [ZChoicesResolver]).
  ///
  /// `null` par défaut ⇒ comportement **strictement inchangé** (options
  /// statiques [choices] et canaux `ZSelectConfig` existants).
  ///
  /// Comme [derivedFrom], ce membre porte une **closure** : il n'est pas émis
  /// par le générateur (le schéma statique reste pur-données — invariant AD-3),
  /// c'est une surcharge runtime posée par l'hôte
  /// (`spec.copyWith(choicesResolver: …)`). Il est volontairement **exclu de
  /// `==`/`hashCode`** : deux specs ne diffèrent jamais par l'identité d'une
  /// closure (mémoïsation runtime et tests de projection restent valides).
  final ZChoicesResolver? choicesResolver;

  /// `true` ssi ce champ porte un validateur [ZValidatorKind.required].
  /// Alimente l'astérisque « requis » du label enrichi (`ZFieldLabel`), sans
  /// dépendance Flutter.
  bool get isRequired =>
      validators.any((v) => v.kind == ZValidatorKind.required);

  /// Copie la spec en surchargeant les champs fournis (identité de valeur
  /// préservée pour les autres). Additif — sert notamment au **mode lecture
  /// global** (`spec.copyWith(readOnly: true)`), sans réécrire les familles qui
  /// respectent déjà `field.readOnly`.
  ZFieldSpec copyWith({
    String? name,
    EditionFieldType? type,
    String? label,
    List<ZValidatorSpec>? validators,
    ZFieldConfig? config,
    List<ZFieldChoice>? choices,
    ZCondition? condition,
    bool? searchable,
    Object? defaultValue,
    bool? readOnly,
    bool? showIfNull,
    bool? multiple,
    bool? isId,
    ZFieldSize? fieldSize,
    ZFieldAdornment? leading,
    ZFieldAdornment? prefix,
    ZFieldAdornment? suffix,
    String? hintText,
    String? helperText,
    ZDerivation? derivedFrom,
    String? widgetKind,
    ZChoicesResolver? choicesResolver,
  }) =>
      ZFieldSpec(
        name: name ?? this.name,
        type: type ?? this.type,
        label: label ?? this.label,
        validators: validators ?? this.validators,
        config: config ?? this.config,
        choices: choices ?? this.choices,
        condition: condition ?? this.condition,
        searchable: searchable ?? this.searchable,
        defaultValue: defaultValue ?? this.defaultValue,
        readOnly: readOnly ?? this.readOnly,
        showIfNull: showIfNull ?? this.showIfNull,
        multiple: multiple ?? this.multiple,
        isId: isId ?? this.isId,
        fieldSize: fieldSize ?? this.fieldSize,
        leading: leading ?? this.leading,
        prefix: prefix ?? this.prefix,
        suffix: suffix ?? this.suffix,
        hintText: hintText ?? this.hintText,
        helperText: helperText ?? this.helperText,
        derivedFrom: derivedFrom ?? this.derivedFrom,
        widgetKind: widgetKind ?? this.widgetKind,
        choicesResolver: choicesResolver ?? this.choicesResolver,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFieldSpec &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type &&
          label == other.label &&
          config == other.config &&
          condition == other.condition &&
          searchable == other.searchable &&
          defaultValue == other.defaultValue &&
          readOnly == other.readOnly &&
          showIfNull == other.showIfNull &&
          multiple == other.multiple &&
          isId == other.isId &&
          fieldSize == other.fieldSize &&
          leading == other.leading &&
          prefix == other.prefix &&
          suffix == other.suffix &&
          hintText == other.hintText &&
          helperText == other.helperText &&
          widgetKind == other.widgetKind &&
          _listEquals(validators, other.validators) &&
          _listEquals(choices, other.choices);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        runtimeType,
        name,
        type,
        label,
        config,
        condition,
        searchable,
        defaultValue,
        readOnly,
        showIfNull,
        multiple,
        isId,
        fieldSize,
        leading,
        prefix,
        suffix,
        hintText,
        helperText,
        widgetKind,
        Object.hashAll(validators),
        Object.hashAll(choices),
      ]);

  @override
  String toString() => 'ZFieldSpec(name: $name, type: ${type.name})';
}

/// Égalité **profonde** de deux listes (pur-Dart — évite `package:collection`,
/// invariant AD-1).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
