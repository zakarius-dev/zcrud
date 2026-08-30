@TestOn('vm')
library;

// `@ZcrudModel.fieldRename` doit être déclarable depuis un paquet CONSOMMATEUR,
// c'est-à-dire depuis une bibliothèque qui n'importe que le barrel des
// annotations. Deux propriétés distinctes sont gardées ici :
//
//  1. l'énumération `ZFieldRename` est NOMMABLE depuis
//     `package:zcrud_annotations/zcrud_annotations.dart` — sans quoi l'argument
//     écrit ne se résout pas, et l'annotation rend une constante NULLE (pas une
//     erreur de compilation que le générateur verrait) ;
//  2. quand la constante est illisible malgré tout, la valeur LITTÉRALEMENT
//     écrite est relue sur l'AST — et RIEN d'autre n'est accepté : un alias
//     `const` ou une expression calculée font échouer le build, jamais un repli
//     muet sur `snake` qui renommerait les clés persistées.
//
// Le cœur d'émission est piloté directement sur une source résolue en mémoire
// (`resolveSource`) : ces sources n'existent pas sur disque, `gate:codegen` ne
// doit donc pas les prendre pour de vrais modèles.
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_generator/src/zcrud_model_generator.dart';

const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

// Annotations interpolées : jamais `@ZcrudModel` en début de ligne dans CE
// fichier.
const _model = '@ZcrudModel';
const _field = '@ZcrudField';

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

/// Modèle de preuve dont le champ produit quatre clés DISTINCTES selon la
/// stratégie — un test vert ne prouve rien sans cela.
String _source({
  required String imports,
  required String renameArg,
  String prelude = '',
}) =>
    '''
$imports
$prelude

$_model(kind: 'berth'$renameArg)
class Berth {
  const Berth({required this.canBeDeleted});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final bool canBeDeleted;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(canBeDeleted: map['x'] == true);
''';

const _allKeys = <String>[
  'canBeDeleted',
  'can_be_deleted',
  'can-be-deleted',
  'CanBeDeleted',
];

void _expectKey(String out, String expected) {
  expect(out, contains("'$expected': this.canBeDeleted,"),
      reason: 'toMap doit émettre la clé $expected');
  for (final other in _allKeys.where((k) => k != expected)) {
    expect(out, isNot(contains("'$other'")),
        reason: 'aucune autre forme de clé ne doit apparaître ($other)');
  }
}

void main() {
  group('déclaration depuis un paquet consommateur', () {
    // Le barrel des annotations est le SEUL import d'un modèle consommateur :
    // c'est la situation dans laquelle `fieldRename:` était inutilisable.
    const consumerImports =
        "import 'package:zcrud_annotations/zcrud_annotations.dart';";

    test('`ZFieldRename` est nommable depuis le seul barrel des annotations',
        () async {
      final out = await _emit(_source(
        imports: consumerImports,
        renameArg: ', fieldRename: ZFieldRename.kebab',
      ));
      _expectKey(out, 'can-be-deleted');
    });

    test('`none` déclaré par un consommateur n\'est pas renommé', () async {
      final out = await _emit(_source(
        imports: consumerImports,
        renameArg: ', fieldRename: ZFieldRename.none',
      ));
      _expectKey(out, 'canBeDeleted');
    });

    test('argument omis : le défaut `snake` de l\'annotation s\'applique',
        () async {
      final out = await _emit(_source(
        imports: consumerImports,
        renameArg: '',
      ));
      _expectKey(out, 'can_be_deleted');
    });
  });

  group('constante illisible — la valeur écrite fait foi, ou rien', () {
    // `hide ZFieldRename` reproduit EXACTEMENT la position d'une bibliothèque où
    // l'énumération n'est pas résoluble : l'argument est écrit, la constante de
    // l'annotation rend `null`. C'est la panne signalée depuis un hôte.
    const hiddenEnum = "import 'package:zcrud_annotations/zcrud_annotations.dart'"
        ' hide ZFieldRename;';

    test('valeur littérale écrite : relue sur l\'AST, appliquée', () async {
      final out = await _emit(_source(
        imports: hiddenEnum,
        renameArg: ', fieldRename: ZFieldRename.kebab',
      ));
      _expectKey(out, 'can-be-deleted');
    });

    test('valeur littérale `none` : relue, et surtout PAS repliée sur snake',
        () async {
      final out = await _emit(_source(
        imports: hiddenEnum,
        renameArg: ', fieldRename: ZFieldRename.none',
      ));
      _expectKey(out, 'canBeDeleted');
    });

    test('alias `const` : échec de build, jamais de repli muet', () async {
      await expectLater(
        _emit(_source(
          imports: hiddenEnum,
          prelude: 'const zAlias = ZFieldRename.kebab;',
          renameArg: ', fieldRename: zAlias',
        )),
        throwsA(isA<InvalidGenerationSourceError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('Aucun repli'),
            contains('`zAlias`'),
          ),
        )),
      );
    });

    test('énumération HOMONYME par sa constante : AUCUNE émission', () async {
      // `_Autre.kebab` porte le même dernier segment qu'une stratégie valide.
      // Mesuré : ce cas n'atteint jamais la lecture de secours — `source_gen`
      // refuse l'annotation en amont (type incompatible). La propriété gardée
      // ici n'est donc pas le TYPE de l'échec mais son existence : rien ne doit
      // être émis, un repli sur `snake` serait un renommage muet.
      String? emitted;
      try {
        emitted = await _emit(_source(
          imports: hiddenEnum,
          prelude: 'enum _Autre { kebab }',
          renameArg: ', fieldRename: _Autre.kebab',
        ));
      } on Object {
        emitted = null;
      }
      expect(emitted, isNull);
    });

    test('le message d\'échec est ACTIONNABLE', () async {
      await expectLater(
        _emit(_source(
          imports: hiddenEnum,
          prelude: 'const zAlias = ZFieldRename.kebab;',
          renameArg: ', fieldRename: zAlias',
        )),
        throwsA(isA<InvalidGenerationSourceError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('zcrud_annotations'),
            contains('LITTÉRALEMENT'),
            contains('MÊME'),
          ),
        )),
      );
    });
  });
}
