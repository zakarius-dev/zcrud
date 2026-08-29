// Cas d'or des deux capacités N0+N1 du chantier S8 :
//   - **héritage collecté** (GEN-2) : un champ annoté déclaré sur une
//     super-classe entre dans `toMap`/décodeur/`$FieldSpecs` de la sous-classe,
//     dans un ordre STABLE (linéarisation Dart : ancêtre le plus lointain
//     d'abord). Avant ce lot, `_collectFields` n'itérait que `element.fields` :
//     le build restait VERT et le champ disparaissait sans signal ;
//   - **Map<K, V>** (GEN-3) : `_classify` n'avait aucune branche `Map`, ce qui
//     rendait 49 champs d'un hôte non classifiables (36 `Map<…>`).
//
// Deux niveaux de preuve, complémentaires :
//   1. COMPORTEMENT — sur la fixture `test/models/ledger_entry.dart` compilée
//      par build_runner réel (round-trip, décodage défensif) ;
//   2. TEXTE ÉMIS — via `resolveSource`, pour les cas qu'aucune fixture
//      compilable ne peut porter (masquage, refus de build).
@TestOn('vm')
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';
import 'package:zcrud_generator/src/zcrud_model_generator.dart';

import 'models/ledger_entry.dart';

const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

// Interpolées : ces sources n'existent qu'en mémoire (`gate:codegen` ne doit pas
// les prendre pour de vrais modèles réclamant un `.g.dart`).
const _model = '@ZcrudModel';
const _field = '@ZcrudField';

Future<String> _emitText(String source) => resolveSource(
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

Future<Object?> _emitError(String source) async {
  try {
    await _emitText(source);
  } catch (error) {
    return error;
  }
  return null;
}

void main() {
  group('GEN-2 — champs annotés HÉRITÉS collectés', () {
    test('ordre de linéarisation : racine, base, puis champs locaux', () {
      // `id` est annoté sur `LedgerRoot`, `label`/`archived` sur `LedgerBase`,
      // le reste sur `LedgerEntry`. L'ordre est EXACT, pas un `containsAll` :
      // il pilote l'ordre des champs du formulaire généré.
      expect(
        $LedgerEntryFieldSpecs.map((s) => s.name).toList(),
        <String>[
          'id',
          'label',
          'archived',
          'amount',
          'tally',
          'meta',
          'zones',
          'stamps',
          'notes',
        ],
      );
      expect($LedgerEntryPersistedKeys, <String>{
        'id',
        'label',
        'archived',
        'amount',
        'tally',
        'meta',
        'zones',
        'stamps',
        'notes',
      });
    });

    test('les métadonnées de l\'annotation héritée sont projetées', () {
      final id = $LedgerEntryFieldSpecs.firstWhere((s) => s.name == 'id');
      expect(id.isId, isTrue);
      final label = $LedgerEntryFieldSpecs.firstWhere((s) => s.name == 'label');
      expect(label.label, 'Libellé');
      expect(label.type, EditionFieldType.text);
      final archived =
          $LedgerEntryFieldSpecs.firstWhere((s) => s.name == 'archived');
      expect(archived.type, EditionFieldType.boolean);
    });

    test('toMap ÉMET les champs hérités, fromMap les RELIT', () {
      const entry = LedgerEntry(
        id: 'e-1',
        label: 'Écriture',
        archived: true,
        amount: 12.5,
      );
      final map = entry.toMap();
      expect(map['id'], 'e-1');
      expect(map['label'], 'Écriture');
      expect(map['archived'], isTrue);

      final back = LedgerEntry.fromMap(map);
      expect(back.id, 'e-1');
      expect(back.label, 'Écriture');
      expect(back.archived, isTrue);
    });

    test('champ hérité annoté que le constructeur n\'expose pas → BUILD ROUGE',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

abstract class Base {
  const Base();
  $_field()
  final String tag = '';
}

$_model()
class Leaf extends Base {
  const Leaf({required this.title});
  factory Leaf.fromMap(Map<String, dynamic> map) => _\$LeafFromMap(map);
  $_field()
  final String title;
}
''';
      final error = await _emitError(src);
      expect(error, isA<InvalidGenerationSourceError>());
      expect(
        '$error',
        allOf(
          contains('HÉRITÉ'),
          contains('tag'),
          contains('super.tag'),
        ),
      );
    });

    test('un champ redéclaré plus PRÈS masque la déclaration de base',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

abstract class Root {
  const Root({this.tag = 'r'});
  $_field(label: 'racine')
  final String tag;
}

abstract class Mid extends Root {
  const Mid({this.tag = 'm'});
  @override
  $_field(label: 'milieu')
  final String tag;
}

$_model()
class Leaf extends Mid {
  const Leaf({super.tag});
  factory Leaf.fromMap(Map<String, dynamic> map) => _\$LeafFromMap(map);
}
''';
      final text = await _emitText(src);
      // Un seul `ZFieldSpec` pour `tag`, et c'est le libellé du MILIEU.
      expect("'milieu'".allMatches(text).length, 1);
      expect(text, isNot(contains("'racine'")));
    });

    test('un champ NON annoté sur la base reste hors du code émis', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

abstract class Base {
  const Base();
  final String hidden = '';
  $_field()
  final String shown = '';
}

$_model()
class Leaf extends Base {
  const Leaf({String? shown});
  factory Leaf.fromMap(Map<String, dynamic> map) => _\$LeafFromMap(map);
}
''';
      final text = await _emitText(src);
      expect(text, contains("name: 'shown'"));
      expect(text, isNot(contains('hidden')));
    });
  });

  group('GEN-3 — champs Map<K, V>', () {
    test('round-trip fidèle des cinq formes de map', () {
      final entry = LedgerEntry(
        label: 'l',
        amount: 1,
        tally: const <String, int>{'a': 1, 'b': 2},
        meta: const <String, dynamic>{
          'flag': true,
          'nested': <String, dynamic>{'k': 1},
        },
        zones: const <LedgerZone, String>{
          LedgerZone.alpha: 'A',
          LedgerZone.gamma: 'G',
        },
        stamps: <String, DateTime>{'at': DateTime.utc(2026, 8, 29, 10)},
        notes: const <String, String?>{'x': 'y', 'empty': null},
      );
      final map = entry.toMap();

      // Le document persisté est à clés `String` : la clé enum sort en `.name`.
      expect(map['zones'], <String, String>{'alpha': 'A', 'gamma': 'G'});
      expect(map['stamps'], <String, String>{'at': '2026-08-29T10:00:00.000Z'});
      expect(map['tally'], <String, int>{'a': 1, 'b': 2});
      expect(map['notes'], <String, String?>{'x': 'y', 'empty': null});

      final back = LedgerEntry.fromMap(map);
      expect(back.tally, entry.tally);
      expect(back.meta, entry.meta);
      expect(back.zones, entry.zones);
      expect(back.stamps, entry.stamps);
      // Le `null` DÉCLARÉ survit au round-trip (il n'est pas confondu avec une
      // entrée corrompue).
      expect(back.notes, <String, String?>{'x': 'y', 'empty': null});
    });

    test('décodage DÉFENSIF (AD-10) : entrée corrompue ignorée, reste survivant',
        () {
      LedgerEntry decode() => LedgerEntry.fromMap(<String, dynamic>{
            'label': 'l',
            'amount': 1,
            'tally': <dynamic, dynamic>{'a': 1, 'b': <int>[], 3: 4},
            'zones': <String, dynamic>{'alpha': 'A', 'omega': 'O', 'beta': 7},
            'stamps': <String, dynamic>{
              'at': 'pas-une-date',
              'ok': '2026-01-02',
            },
            'meta': 'pas-une-map',
          });
      // Le PARENT ne lève JAMAIS, quelle que soit la corruption des entrées.
      expect(decode, returnsNormally);

      final back = LedgerEntry.fromMap(<String, dynamic>{
        'label': 'l',
        'amount': 1,
        // Valeur illisible sur `b`, clé non-`String` sur `3`.
        'tally': <dynamic, dynamic>{'a': 1, 'b': <int>[], 3: 4},
        // Clé enum inconnue : l'entrée disparaît, les autres restent.
        'zones': <String, dynamic>{'alpha': 'A', 'omega': 'O', 'beta': 7},
        'stamps': <String, dynamic>{'at': 'pas-une-date', 'ok': '2026-01-02'},
        // Type entièrement faux : repli sur le défaut, jamais de throw.
        'meta': 'pas-une-map',
      });
      expect(back.tally, <String, int>{'a': 1});
      expect(back.zones, <LedgerZone, String>{LedgerZone.alpha: 'A'});
      expect(back.stamps.keys, <String>['ok']);
      expect(back.meta, isEmpty);
      // Champ absent → défaut, le parent ne lève jamais.
      expect(back.notes, isEmpty);
    });

    test('une map n\'est pas `multiple` (ce n\'est pas une multi-valeur)', () {
      for (final name in <String>['tally', 'meta', 'zones', 'stamps', 'notes']) {
        final spec = $LedgerEntryFieldSpecs.firstWhere((s) => s.name == name);
        expect(spec.multiple, isFalse, reason: name);
        expect(spec.type, EditionFieldType.dynamicItem, reason: name);
      }
    });

    test('clé de map non supportée → BUILD ROUGE', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class Leaf {
  const Leaf({this.byIndex = const <int, String>{}});
  factory Leaf.fromMap(Map<String, dynamic> map) => _\$LeafFromMap(map);
  $_field()
  final Map<int, String> byIndex;
}
''';
      final error = await _emitError(src);
      expect(error, isA<InvalidGenerationSourceError>());
      expect('$error', contains('Clé de Map non supportée'));
    });

    test('valeur de map non (dé)sérialisable → BUILD ROUGE', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

class Opaque {
  const Opaque();
}

$_model()
class Leaf {
  const Leaf({this.blobs = const <String, Opaque>{}});
  factory Leaf.fromMap(Map<String, dynamic> map) => _\$LeafFromMap(map);
  $_field()
  final Map<String, Opaque> blobs;
}
''';
      final error = await _emitError(src);
      expect(error, isA<InvalidGenerationSourceError>());
      expect('$error', contains('Valeur de Map non (dé)sérialisable'));
    });

    test('liste de maps : refus EXPLICITE, pas une émission approximative',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class Leaf {
  const Leaf({this.rows = const <Map<String, dynamic>>[]});
  factory Leaf.fromMap(Map<String, dynamic> map) => _\$LeafFromMap(map);
  $_field()
  final List<Map<String, dynamic>> rows;
}
''';
      final error = await _emitError(src);
      expect(error, isA<InvalidGenerationSourceError>());
      expect('$error', contains('Liste de maps non supportée'));
    });

    test('valeur `List<T>` dans une map : émise, et défensive', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class Leaf {
  const Leaf({this.groups = const <String, List<String>>{}});
  factory Leaf.fromMap(Map<String, dynamic> map) => _\$LeafFromMap(map);
  $_field()
  final Map<String, List<String>> groups;
}
''';
      final text = await _emitText(src);
      expect(text, contains('<String, List<String>>{'));
      expect(text, contains('.whereType<String>().toList()'));
    });

    test('un champ Map NON annoté n\'échoue plus le build (type sérialisable)',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class Leaf {
  const Leaf({this.title = '', this.scratch = const <String, dynamic>{}});
  factory Leaf.fromMap(Map<String, dynamic> map) => _\$LeafFromMap(map);
  $_field()
  final String title;
  final Map<String, dynamic> scratch;
}
''';
      final text = await _emitText(src);
      // Non annoté ⇒ hors persistance, comme tout autre type sérialisable.
      expect(text, isNot(contains('scratch')));
    });
  });
}
