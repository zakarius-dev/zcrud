/// Barrel d'API publique de `zcrud_annotations`.
///
/// Annotations `@ZcrudModel` / `@ZcrudField` / `@ZcrudId` (pur-Dart).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Les 3 annotations d'autorité `const` du moteur codegen (E2-4, AD-3) : classes
// pur-données lues STATIQUEMENT par le générateur E2-5 (`ConstantReader`, jamais
// exécutées ni réfléchies — `reflectable` banni). Elles référencent la surface
// `EditionFieldType` + types-valeur via l'unique arête AD-1
// `zcrud_annotations → zcrud_core` (cœur OUT=0). Ordre alphabétique
// (directives_ordering).
export 'src/domain/annotations/z_persist_as.dart';
export 'src/domain/annotations/zcrud_field.dart';
export 'src/domain/annotations/zcrud_id.dart';
export 'src/domain/annotations/zcrud_model.dart';
// Marqueur de version de l'API publique (conservé — arrime aussi tangiblement
// l'arête AD-1 vers `zcrud_core`).
export 'src/domain/z_annotations_api.dart';
