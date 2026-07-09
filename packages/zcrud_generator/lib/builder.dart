/// Fabrique de `Builder` `build_runner` de `zcrud_generator` (E2-5, AD-3).
///
/// Point d'entrée référencé par `build.yaml` (`builder_factories`). Assemble un
/// `SharedPartBuilder` `source_gen` autour de [ZcrudModelGenerator] : chaque
/// bibliothèque annotée `@ZcrudModel` produit un fragment `.zcrud.g.part`,
/// agrégé par `source_gen|combining_builder` dans le `part '<file>.g.dart'`
/// (en-tête `// GENERATED CODE - DO NOT MODIFY BY HAND`, `.g.dart` **gitignoré**,
/// régénéré). Toolchain codegen (`build`/`source_gen`/`analyzer`) confinée à ce
/// package (dev_dependency — AD-1) : elle ne fuit jamais chez les consommateurs.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/zcrud_model_generator.dart';

/// Construit le `Builder` `zcrud_model` (partie partagée `zcrud`).
Builder zcrudModelBuilder(BuilderOptions options) =>
    SharedPartBuilder(<Generator>[const ZcrudModelGenerator()], 'zcrud');
