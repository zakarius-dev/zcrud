// DP-12 (M1/M5/M6) + DP-13 (showIfNull) : projection `@ZcrudField → ZFieldSpec`
// des nouveaux slots. On pilote `generateForModel` DIRECTEMENT sur une source
// résolue en mémoire (`resolveSource`) et on asserte le TEXTE émis (mêmes const
// AST re-émis 1:1 via `_emitConst`).
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_generator/src/zcrud_model_generator.dart';

const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

// Annotations interpolées (jamais `@ZcrudModel` en tête de ligne — source en
// mémoire, invisible pour `gate:codegen`).
const _model = '@ZcrudModel';
const _field = '@ZcrudField';

/// Résout [source], émet le premier modèle et retourne le TEXTE généré complet.
Future<String> _emit(String source) => resolveSource(
      source,
      (resolver) async {
        final lib = await resolver
            .libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart'));
        final annotated = LibraryReader(lib).annotatedWith(_modelChecker).first;
        return const ZcrudModelGenerator()
            .generateForModel(annotated.element, annotated.annotation)
            .join('\n');
      },
      readAllSourcesFromFilesystem: true,
    );

void main() {
  test('DP-12 : leading/prefix/suffix/hintText/helperText projetés 1:1', () async {
    const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

$_model()
class Decorated {
  const Decorated({required this.amount});

  $_field(
    leading: ZFieldAdornment.icon('search'),
    prefix: ZFieldAdornment.text('EUR'),
    suffix: ZFieldAdornment.widget('clear'),
    hintText: 'hint.key',
    helperText: 'helper.key',
  )
  final String amount;
}
''';
    final out = await _emit(src);
    expect(out, contains("leading: ZFieldAdornment.icon('search')"));
    expect(out, contains("prefix: ZFieldAdornment.text('EUR')"));
    expect(out, contains("suffix: ZFieldAdornment.widget('clear')"));
    expect(out, contains("hintText: 'hint.key'"));
    expect(out, contains("helperText: 'helper.key'"));
  });

  test('DP-13 : showIfNull émis SEULEMENT si `true` (opt-in) ; défaut false '
      'non émis', () async {
    const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class Flags {
  const Flags({required this.a, required this.b});

  // Opt-in de rétention explicite → `showIfNull: true` émis.
  $_field(showIfNull: true)
  final String a;

  // Défaut (false) → AUCUNE émission de showIfNull (le flip du défaut
  // ZFieldSpec s'applique, parité DODLP).
  $_field()
  final String b;
}
''';
    final out = await _emit(src);
    expect(out, contains('showIfNull: true'));
    // Le champ `b` (défaut) ne doit PAS forcer `showIfNull: false` ni `true`.
    expect(out, isNot(contains('showIfNull: false')));
    // Une seule occurrence de `showIfNull` (celle du champ `a`).
    expect('showIfNull'.allMatches(out).length, 1);
  });

  test('DP-12/DP-13 : un champ SANS slot ni showIfNull → spec inchangée '
      '(rétro-compat additive)', () async {
    const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class Plain {
  const Plain({required this.name});

  $_field(label: 'Name')
  final String name;
}
''';
    final out = await _emit(src);
    // La spec ne porte que name/type/label — aucun slot DP-12, aucun showIfNull.
    expect(out, contains("ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Name')"));
    expect(out, isNot(contains('leading:')));
    expect(out, isNot(contains('showIfNull')));
  });
}
