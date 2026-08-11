/// Barrel d'API publique de `zcrud_generator`.
///
/// Générateur `build_runner` : (dé)sérialisation, `ZFieldSpec[]` et
/// enregistrement au `ZcrudRegistry`, projetés depuis `@ZcrudModel` /
/// `@ZcrudField` (`zcrud_annotations`). Le point d'entrée référencé par
/// `build.yaml` est `package:zcrud_generator/builder.dart`, séparé de ce
/// barrel.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/z_generator_api.dart';
