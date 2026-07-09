// AC9 (AD-3) : échec de build EXPLICITE (`InvalidGenerationSourceError`, message
// actionnable) — jamais un cast `null` silencieux. Le cœur d'émission
// (`generateForModel`) est piloté DIRECTEMENT sur une source résolue en mémoire
// (`resolveSource`), sans pipeline build_runner ni fichier disque (donc
// invisible pour `gate:codegen`).
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_generator/src/zcrud_model_generator.dart';

const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

// Les annotations sont interpolées (jamais `@ZcrudModel` en début de ligne dans
// CE fichier) : ces sources n'existent qu'en mémoire, `gate:codegen` ne doit
// donc pas les prendre pour de vrais modèles réclamant un `.g.dart`.
const _model = '@ZcrudModel';
const _field = '@ZcrudField';

/// Résout [source] et émet le premier modèle `@ZcrudModel` via le générateur
/// (lève si le type de champ / la clé est invalide).
Future<void> _emitFirstModel(String source) => resolveSource(
      source,
      (resolver) async {
        final lib = await resolver
            .libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart'));
        final annotated =
            LibraryReader(lib).annotatedWith(_modelChecker).first;
        const ZcrudModelGenerator()
            .generateForModel(annotated.element, annotated.annotation)
            // Force l'évaluation (Iterable paresseux).
            .toList();
      },
      readAllSourcesFromFilesystem: true,
    );

void main() {
  test('type de champ non (dé)sérialisable → InvalidGenerationSourceError', () {
    const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class BadType {
  const BadType({required this.link});

  $_field()
  final Uri link;
}
''';
    expect(
      () => _emitFirstModel(src),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });

  test('collision de clé persistée → InvalidGenerationSourceError', () {
    const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class DupKey {
  const DupKey({required this.a, required this.b});

  $_field(name: 'k')
  final String a;

  $_field(name: 'k')
  final String b;
}
''';
    expect(
      () => _emitFirstModel(src),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });
}
