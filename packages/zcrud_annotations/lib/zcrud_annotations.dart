/// Barrel d'API publique de `zcrud_annotations`.
///
/// Annotations `@ZcrudModel` / `@ZcrudField` / `@ZcrudId` / `@ZcrudIgnore`
/// (pur-Dart).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Les 4 annotations d'autorité `const` du moteur codegen (invariant AD-3) :
// classes pur-données lues STATIQUEMENT par `zcrud_generator`
// (`ConstantReader`, jamais exécutées ni réfléchies — `reflectable` banni).
// Elles référencent la surface `EditionFieldType` + types-valeur via l'unique
// arête (invariant AD-1) `zcrud_annotations → zcrud_core` (cœur OUT=0). Ordre
// alphabétique (directives_ordering).
// `ZFieldRename` TYPE un paramètre de `@ZcrudModel` : sans cette ré-exportation,
// l'énumération n'est pas nommable depuis ce barrel, et `fieldRename:` est un
// paramètre qu'on ne peut pas renseigner sans importer AUSSI un barrel de
// `zcrud_core`. Le générateur lit l'argument STATIQUEMENT : un identifiant non
// résolu n'y devient pas une erreur d'analyse lisible, il devient une constante
// nulle — donc un échec de build sur la lecture de l'annotation.
export 'package:zcrud_core/edition.dart' show ZFieldRename;
export 'src/domain/annotations/z_persist_as.dart';
export 'src/domain/annotations/zcrud_field.dart';
export 'src/domain/annotations/zcrud_id.dart';
export 'src/domain/annotations/zcrud_ignore.dart';
export 'src/domain/annotations/zcrud_model.dart';
// Marqueur de version de l'API publique (conservé — arrime aussi tangiblement
// l'arête AD-1 vers `zcrud_core`).
export 'src/domain/z_annotations_api.dart';
