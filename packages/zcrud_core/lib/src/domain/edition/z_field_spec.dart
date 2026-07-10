/// Projection **runtime** d'un champ du schéma `zcrud` — l'image de
/// `@ZcrudField` (+ `@ZcrudId`) émise par le générateur E2-5 (AD-3).
///
/// origine: table de correspondance `@ZcrudField → ZFieldSpec` (story E2-4,
/// `zcrud_field.dart`). E2-4 a livré la **surface d'autorité** (annotations
/// `const`, lues statiquement par `ConstantReader`) ; E2-5 crée CETTE classe et
/// **émet** un `const List<ZFieldSpec>` par modèle, projetant 1:1 les
/// annotations (`name/label/type/validators/config/choices/condition/searchable/
/// defaultValue/readOnly/showIfNull/multiple/isId`) avec **inférence de `type`**
/// quand `@ZcrudField.type == null`.
///
/// **Pur-données `const`** (couche `domain`, pur-Dart — AD-1, garde
/// `domain_purity_test.dart`) : aucune closure, aucun widget, aucune dépendance
/// Flutter. L'**interprétation** (type→widget, validators→`FormBuilderValidators`,
/// condition→visibilité) est E3/E4 ; ici on ne porte que la **donnée**.
///
/// Égalité de **valeur** (`==`/`hashCode`) : utile aux tests de projection
/// (AC6, E2-5) et à la mémoïsation runtime (E3).
library;

import 'edition_field_type.dart';
import 'z_condition.dart';
import 'z_field_choice.dart';
import 'z_field_config.dart';
import 'z_validator_spec.dart';

/// Spécification `const` d'un champ du schéma `zcrud`, projetée depuis
/// `@ZcrudField`/`@ZcrudId` par le générateur E2-5.
class ZFieldSpec {
  /// Construit la spec `const` d'un champ.
  ///
  /// [name] est la **clé persistée** (dérivée du nom Dart via
  /// `@ZcrudModel.fieldRename`, ou l'override `@ZcrudField.name`). [type] est
  /// fourni par `@ZcrudField.type` ou **inféré** du type Dart statique (E2-5).
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
    this.showIfNull = true,
    this.multiple = false,
    this.isId = false,
  });

  /// Clé persistée du champ (snake_case par défaut — AD-3).
  final String name;

  /// Type déclaratif du champ (fourni ou inféré — E2-5).
  final EditionFieldType type;

  /// Libellé d'affichage (clé l10n ou littéral ; résolu côté UI en E3/E4).
  final String? label;

  /// Validateurs déclaratifs (composés en `FormBuilderValidators` par E3).
  final List<ZValidatorSpec> validators;

  /// Config spécialisée par type (base d'extension `ZFieldConfig`).
  final ZFieldConfig? config;

  /// Options statiques pour `select`/`radio`/`checkbox`.
  final List<ZFieldChoice> choices;

  /// Visibilité conditionnelle déclarative (`displayCondition`) ; évaluée par E3.
  final ZCondition? condition;

  /// Participation à la recherche/filtre de la liste (E4).
  final bool searchable;

  /// Valeur par défaut appliquée par `fromMap`/E3 si la clé est absente.
  final Object? defaultValue;

  /// Champ non éditable (mode lecture).
  final bool readOnly;

  /// En mode lecture, afficher même si la valeur est `null`.
  final bool showIfNull;

  /// Multi-valeur (`List<…>` ou `multiple: true`).
  final bool multiple;

  /// `true` si le champ porte `@ZcrudId` (clé d'identité opaque).
  final bool isId;

  /// Copie la spec en surchargeant les champs fournis (identité de valeur
  /// préservée pour les autres). Additif — sert notamment au **mode lecture
  /// global** d'E3-4 (`spec.copyWith(readOnly: true)`), sans réécrire les
  /// familles qui respectent déjà `field.readOnly`.
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
          _listEquals(validators, other.validators) &&
          _listEquals(choices, other.choices);

  @override
  int get hashCode => Object.hash(
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
        Object.hashAll(validators),
        Object.hashAll(choices),
      );

  @override
  String toString() => 'ZFieldSpec(name: $name, type: ${type.name})';
}

/// Égalité **profonde** de deux listes (pur-Dart — évite `package:collection`,
/// AD-1 out-degree 0).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
