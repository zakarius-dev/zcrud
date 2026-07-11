/// Entrée publique **pure-Dart** de la surface d'autorité du moteur déclaratif
/// (E2-4) : catalogue `EditionFieldType` + types-valeur `const`
/// (`ZValidatorSpec`/`ZFieldChoice`/`ZCondition`/`ZFieldConfig`/`ZFieldRename`)
/// + marqueur `ZCoreApi`.
///
/// **Pourquoi une entrée dédiée** (en plus du barrel principal `zcrud_core.dart`,
/// qui exporte aussi ces types — AC9) : le barrel principal ré-exporte la couche
/// `presentation` (E2-7, `ChangeNotifier`/`ValueListenable`, qui tire le SDK
/// Flutter → `dart:ui`). Les consommateurs **pur-Dart** de la seule surface
/// d'autorité — au premier chef `zcrud_annotations` (annotations `const`) et le
/// générateur E2-5 — importent CE point d'entrée pour référencer le catalogue et
/// les types-valeur **sans** charger transitivement Flutter, et rester
/// exécutables sous `dart test`. L'arête AD-1 `zcrud_annotations → zcrud_core`
/// (pubspec) est inchangée ; seule la granularité d'import l'est.
library;

export 'src/domain/edition/edition_field_type.dart';
export 'src/domain/edition/z_condition.dart';
export 'src/domain/edition/z_field_adornment.dart';
export 'src/domain/edition/z_field_choice.dart';
export 'src/domain/edition/z_field_config.dart';
export 'src/domain/edition/z_field_rename.dart';
export 'src/domain/edition/z_field_spec.dart';
export 'src/domain/edition/z_validator_spec.dart';
export 'src/domain/registry/z_registry_error.dart';
export 'src/domain/registry/zcrud_registry.dart';
export 'src/domain/z_core_api.dart';
