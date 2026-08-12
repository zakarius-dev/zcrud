// Contrat de `@ZcrudModel.fieldRename` : les QUATRE stratégies de renommage
// sont exercées de bout en bout SUR LA SORTIE ÉMISE (toMap, décodeur, schéma
// déclaratif, inventaire des clés persistées).
//
// Ce contrat n'était couvert par aucun test : la lecture de l'enum d'annotation
// retombait sur `snake` quelle que soit la valeur déclarée, et rien ne le
// signalait. Un modèle demandant `none` voyait donc toutes ses clés renommées —
// documents déjà écrits devenus illisibles, dans les deux sens.
//
// Le cœur d'émission (`generateForModel`) est piloté DIRECTEMENT sur une source
// résolue en mémoire (`resolveSource`), sans pipeline build_runner ni fichier
// disque (donc invisible pour `gate:codegen`).
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';
import 'package:zcrud_generator/src/zcrud_model_generator.dart';

const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

// Les annotations sont interpolées (jamais `@ZcrudModel` en début de ligne dans
// CE fichier) : ces sources n'existent qu'en mémoire, `gate:codegen` ne doit
// donc pas les prendre pour de vrais modèles réclamant un `.g.dart`.
const _model = '@ZcrudModel';
const _field = '@ZcrudField';

/// Résout [source] et retourne le TEXTE émis pour le premier `@ZcrudModel`.
Future<String> _emit(String source) => resolveSource(
      source,
      (resolver) async {
        final lib = await resolver
            .libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart'));
        final annotated =
            LibraryReader(lib).annotatedWith(_modelChecker).first;
        return const ZcrudModelGenerator()
            .generateForModel(annotated.element, annotated.annotation)
            .join('\n');
      },
      readAllSourcesFromFilesystem: true,
    );

/// Modèle de preuve portant un nom de champ dont les QUATRE stratégies
/// produisent quatre clés DISTINCTES (`canBeDeleted`) — sans quoi un test vert
/// ne prouverait rien.
String _source(String renameArg) => '''
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

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

/// Les quatre clés candidates : celle attendue doit apparaître, les trois
/// autres doivent être ABSENTES de la sortie.
const _allKeys = <String>[
  'canBeDeleted',
  'can_be_deleted',
  'can-be-deleted',
  'CanBeDeleted',
];

/// Exige que [expected] soit la clé persistée émise PARTOUT, et qu'aucune des
/// trois autres formes n'apparaisse nulle part.
void _expectKey(String out, String expected) {
  expect(out, contains("'$expected': this.canBeDeleted,"),
      reason: 'toMap doit émettre la clé $expected');
  expect(out, contains("map['$expected']"),
      reason: 'le décodeur doit lire la clé $expected');
  expect(out, contains("ZFieldSpec(name: '$expected'"),
      reason: 'le schéma déclaratif doit porter la clé $expected');
  expect(out, contains("  '$expected',\n"),
      reason: "l'inventaire des clés persistées doit porter $expected");
  for (final other in _allKeys.where((k) => k != expected)) {
    expect(out, isNot(contains("'$other'")),
        reason: 'aucune autre forme que $expected ne doit être émise');
  }
}

void main() {
  group('@ZcrudModel.fieldRename — les quatre stratégies, sur la sortie émise',
      () {
    test('none : la clé persistée est le nom Dart, tel quel', () async {
      _expectKey(
        await _emit(_source(', fieldRename: ZFieldRename.none')),
        'canBeDeleted',
      );
    });

    test('snake : la clé persistée est snake_case', () async {
      _expectKey(
        await _emit(_source(', fieldRename: ZFieldRename.snake')),
        'can_be_deleted',
      );
    });

    test('kebab : la clé persistée est kebab-case', () async {
      _expectKey(
        await _emit(_source(', fieldRename: ZFieldRename.kebab')),
        'can-be-deleted',
      );
    });

    test('pascal : la clé persistée est PascalCase', () async {
      _expectKey(
        await _emit(_source(', fieldRename: ZFieldRename.pascal')),
        'CanBeDeleted',
      );
    });

    test('annotation sans `fieldRename` : défaut snake_case (inchangé)',
        () async {
      _expectKey(await _emit(_source('')), 'can_be_deleted');
    });

    test('`@ZcrudField(name:)` prime sur la stratégie du modèle', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

$_model(kind: 'berth', fieldRename: ZFieldRename.snake)
class Berth {
  const Berth({required this.canBeDeleted});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field(name: 'canBeDeleted')
  final bool canBeDeleted;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(canBeDeleted: map['x'] == true);
''';
      _expectKey(await _emit(src), 'canBeDeleted');
    });

    // Un `const` intermédiaire est une écriture parfaitement légale. La lecture
    // par le nom de la VARIABLE porteuse rendrait ici `legacyKeys` — pas
    // `none` — et renommerait toutes les clés du modèle.
    test('la valeur passée par un alias `const` est lue comme la constante',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

const legacyKeys = ZFieldRename.none;

$_model(kind: 'berth', fieldRename: legacyKeys)
class Berth {
  const Berth({required this.canBeDeleted});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final bool canBeDeleted;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(canBeDeleted: map['x'] == true);
''';
      _expectKey(await _emit(src), 'canBeDeleted');
    });
  });

  // La même lecture d'enum sert le hint de format de persistance : elle est
  // exercée ici sur la sortie, y compris derrière un alias `const`.
  group('@ZcrudField.persistAs — même lecture d\'enum, même exigence', () {
    Future<String> emitPersistAs(String arg) => _emit('''
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

const natif = ZPersistAs.timestamp;

$_model(kind: 'berth', fieldRename: ZFieldRename.none)
class Berth {
  const Berth({required this.createdAt});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field($arg)
  final DateTime? createdAt;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) => const Berth(createdAt: null);
''');

    test('timestamp : la clé entre dans l\'inventaire des champs Timestamp',
        () async {
      expect(
        await emitPersistAs('persistAs: ZPersistAs.timestamp'),
        contains("\$BerthTimestampFields = <String>{\n  'createdAt',\n}"),
      );
    });

    test('timestamp via un alias `const` : même inventaire', () async {
      expect(
        await emitPersistAs('persistAs: natif'),
        contains("\$BerthTimestampFields = <String>{\n  'createdAt',\n}"),
      );
    });

    test('iso8601 (défaut) : inventaire VIDE', () async {
      expect(
        await emitPersistAs(''),
        contains(r'$BerthTimestampFields = <String>{};'),
      );
    });
  });

  // ===========================================================================
  // DOCUMENTATION — trois branches d'échec DÉFENSIVES ne sont pas déclenchables
  // depuis une source Dart valide ; elles ne sont donc pas exercées ici, et
  // c'est un choix consigné (pas un oubli) :
  //
  //   1. « Lecture de fieldRename impossible : constante nulle » — l'annotation
  //      porte un défaut non nul (`ZFieldRename.snake`) que l'analyzer
  //      matérialise même quand l'argument est omis ; le test « annotation sans
  //      fieldRename » ci-dessus le prouve sur la sortie émise.
  //   2. « Valeur de fieldRename non reconnue » — la lecture rend le dernier
  //      segment de l'accesseur qualifié (`ZFieldRename.xxx`), y compris
  //      derrière un alias `const` (tests ci-dessus) ; toute constante existante
  //      de l'enum est donc reconnue, et l'enum n'en a pas d'autres (tripwire
  //      ci-dessous).
  //   3. « Constante d'enum illisible » (accesseur vide) — jamais observé sur
  //      une source valide : `revive()` qualifie toujours une constante d'enum.
  //
  // Ces branches n'ont qu'un rôle : échouer BRUYAMMENT si une résolution
  // dégradée y menait, au lieu de reproduire la corruption muette de clés du
  // bug d'origine (repli silencieux sur `snake`).
  // ===========================================================================
  test('tripwire : les stratégies testées ci-dessus couvrent TOUTES les '
      'constantes de ZFieldRename', () {
    expect(
      ZFieldRename.values.map((v) => v.name),
      unorderedEquals(<String>['none', 'snake', 'kebab', 'pascal']),
      reason: 'Une constante ajoutée à ZFieldRename doit recevoir son test de '
          'stratégie sur la sortie émise, sinon la branche « non reconnue » '
          'cesserait d\'être théorique.',
    );
  });
}
