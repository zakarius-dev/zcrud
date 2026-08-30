// Cas d'or : une extension générée ne doit JAMAIS pouvoir être sémantiquement
// morte sans que rien ne le dise.
//
// Le défaut mesuré sur le terrain : une sous-classe adopte le codegen alors que
// sa base déclare `toMap()` en MEMBRE D'INSTANCE. Le générateur émet le
// `toMap()` de la sous-classe dans une EXTENSION — et un membre d'extension ne
// surcharge jamais un membre d'instance hérité. L'extension est syntaxiquement
// présente et sémantiquement morte : build vert, `analyze` vert, objet en
// mémoire correct, et les champs propres JAMAIS écrits au document. Le premier
// symptôme serait une donnée utilisateur disparue.
//
// Ce que ces gardes tiennent :
//   1. ROUGE — héritage d'un `toMap()`/`copyWith()` d'instance (concret OU
//      abstrait) sans application du mixin `_$XxxZcrud` ⇒ échec de build, avec
//      la classe, le membre, son fichier:ligne et le geste correctif ;
//   2. CONTRE-PREUVES — un membre hérité d'une EXTENSION ne déclenche rien (une
//      extension ne se transmet pas par héritage) ; une classe qui déclare le
//      membre elle-même non plus (choix écrit dans sa propre source) ;
//   3. VERT + POLYMORPHISME — avec le mixin, `toMap()` répond À TRAVERS le type
//      de base, AVEC les champs propres. C'est la propriété que le défaut
//      détruisait ;
//   4. ACCESSEUR MASQUANT — un getter qui rétrécit un champ hérité annoté ne
//      fait plus disparaître sa spec en silence.
@TestOn('vm')
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_generator/src/zcrud_model_generator.dart';

import 'models/archive_record.dart';

const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

// Interpolés : ces sources n'existent qu'en mémoire (`gate:codegen` ne doit pas
// les prendre pour de vrais modèles réclamant un `.g.dart`).
const _model = '@ZcrudModel';
const _field = '@ZcrudField';

/// Résout [source] et émet le premier modèle `@ZcrudModel`.
Future<void> _emit(String source) => resolveSource(
      source,
      (resolver) async {
        final lib = await resolver
            .libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart'));
        final annotated = LibraryReader(lib).annotatedWith(_modelChecker).first;
        const ZcrudModelGenerator()
            .generateForModel(annotated.element, annotated.annotation)
            .toList();
      },
      readAllSourcesFromFilesystem: true,
    );

/// Message de l'`InvalidGenerationSourceError` levé par [source].
Future<String> _failureMessage(String source) async {
  try {
    await _emit(source);
  } on InvalidGenerationSourceError catch (error) {
    return error.message;
  }
  fail('le build a été ACCEPTÉ alors qu\'un échec était attendu.');
}

/// Base à `toMap()` **concret** d'instance + sous-classe SANS mixin.
const _concreteInherited = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

abstract class Ledger {
  const Ledger({this.id});
  @ZcrudId()
  final String? id;
  Map<String, dynamic> toMap() => <String, dynamic>{'id': id};
}

$_model()
class LedgerLine extends Ledger {
  const LedgerLine({super.id, required this.amount});
  factory LedgerLine.fromMap(Map<String, dynamic> map) =>
      _\$LedgerLineFromMap(map);
  $_field()
  final int amount;
}
''';

void main() {
  group('CR-84 — héritage d\'un membre d\'INSTANCE sans mixin ⇒ BUILD ROUGE',
      () {
    test('`toMap()` CONCRET hérité : échec nommant la classe, le membre, son '
        'fichier:ligne et le geste', () async {
      final message = await _failureMessage(_concreteInherited);
      expect(message, contains('LedgerLine'));
      expect(message, contains('toMap()'));
      expect(message, contains('Ledger'));
      // fichier:ligne de la DÉCLARATION héritée — la ligne 7 de la source.
      expect(message, contains(':7'));
      expect(message, contains('with _\$LedgerLineZcrud'));
      expect(message, contains('SÉMANTIQUEMENT MORTE'));
    });

    test('`copyWith()` ABSTRAIT hérité : échec aussi — un membre d\'extension '
        'ne satisfait pas davantage un abstrait', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

abstract class Slip {
  const Slip({this.id});
  @ZcrudId()
  final String? id;
  Slip copyWith();
}

$_model()
class SlipLine extends Slip {
  const SlipLine({super.id, required this.amount});
  factory SlipLine.fromMap(Map<String, dynamic> map) => _\$SlipLineFromMap(map);
  $_field()
  final int amount;
}
''';
      final message = await _failureMessage(src);
      expect(message, contains('copyWith()'));
      expect(message, contains('with _\$SlipLineZcrud'));
    });

    test('membre hérité d\'un MIXIN de la hiérarchie : échec également',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

mixin Serializable {
  Map<String, dynamic> toMap() => const <String, dynamic>{};
}

class Bare {
  const Bare();
}

$_model()
class Voucher extends Bare with Serializable {
  const Voucher({required this.amount});
  factory Voucher.fromMap(Map<String, dynamic> map) => _\$VoucherFromMap(map);
  $_field()
  final int amount;
}
''';
      final message = await _failureMessage(src);
      expect(message, contains('Serializable'));
      expect(message, contains('with _\$VoucherZcrud'));
    });
  });

  group('CR-84 — CONTRE-PREUVES : ce qui ne doit RIEN déclencher', () {
    test('membre hérité d\'une EXTENSION : ACCEPTÉ (une extension ne se '
        'transmet pas par héritage)', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

class Slipcase {
  const Slipcase({this.id});
  @ZcrudId()
  final String? id;
}

extension SlipcaseSer on Slipcase {
  Map<String, dynamic> toMap() => <String, dynamic>{'id': id};
}

$_model()
class SlipcaseLine extends Slipcase {
  const SlipcaseLine({super.id, required this.amount});
  factory SlipcaseLine.fromMap(Map<String, dynamic> map) =>
      _\$SlipcaseLineFromMap(map);
  $_field()
  final int amount;
}
''';
      await expectLater(_emit(src), completes);
    });

    test('la classe annotée déclare `toMap()` ELLE-MÊME : ACCEPTÉ (choix écrit '
        'dans sa propre source)', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

abstract class Tally {
  const Tally({this.id});
  @ZcrudId()
  final String? id;
  Map<String, dynamic> toMap() => <String, dynamic>{'id': id};
}

$_model()
class TallyLine extends Tally {
  const TallyLine({super.id, required this.amount});
  factory TallyLine.fromMap(Map<String, dynamic> map) =>
      _\$TallyLineFromMap(map);
  $_field()
  final int amount;
  @override
  Map<String, dynamic> toMap() => <String, dynamic>{'id': id, 'n': amount};
}
''';
      await expectLater(_emit(src), completes);
    });

    test('AUCUN héritage de membre d\'instance : ACCEPTÉ', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class Plain {
  const Plain({required this.amount});
  factory Plain.fromMap(Map<String, dynamic> map) => _\$PlainFromMap(map);
  $_field()
  final int amount;
}
''';
      await expectLater(_emit(src), completes);
    });
  });

  group('CR-84 — avec le mixin : VERT et toMap() POLYMORPHE (fixture '
      'compilée)', () {
    // `ArchiveRecord extends ArchiveBase with _$ArchiveRecordZcrud`, où
    // `ArchiveBase` déclare un `toMap()` CONCRET d'instance ne connaissant que
    // ses propres champs.
    final record = ArchiveRecord(
      id: 'a-1',
      label: 'Dossier',
      volume: 7,
      sealedAt: DateTime.utc(2026, 8, 30, 9),
    );

    test('appelé À TRAVERS le type de base, `toMap()` rend les champs PROPRES',
        () {
      final ArchiveBase base = record;
      final map = base.toMap();
      // C'est EXACTEMENT ce que le défaut détruisait : sans le mixin, ces deux
      // clés seraient absentes et le corps de la base répondrait.
      expect(map['volume'], 7);
      expect(map['sealed_at'], '2026-08-30T09:00:00.000Z');
      expect(map['label'], 'Dossier');
    });

    test('les clés du `toMap()` de la BASE ne suffisaient pas : la base seule '
        'n\'en produit que deux', () {
      final ArchiveBase plain = _PlainArchive();
      expect(plain.toMap().keys.toList(), <String>['id', 'label']);
    });

    test('`copyWith()` répond aussi en instance et rend le type concret', () {
      expect(record.copyWith(volume: 9).volume, 9);
      expect(record.copyWith(sealedAt: null).sealedAt, isNull);
    });
  });

  group('CR-84 — accesseur qui RÉTRÉCIT un champ hérité (fixture compilée)',
      () {
    test('la spec du champ hérité est CONSERVÉE — trois entrées, pas deux', () {
      expect(
        $ArchiveDigestFieldSpecs.map((s) => s.name).toList(),
        <String>['id', 'stamp', 'title'],
      );
    });

    test('la clé du champ rétréci est ÉCRITE, avec la valeur de repli de '
        'l\'accesseur', () {
      const digest = ArchiveDigest(id: 'd-1', title: 'Condensé');
      final map = digest.toMap();
      expect(map.containsKey('stamp'), isTrue);
      expect(map['stamp'], ArchiveDigest.epoch.toIso8601String());
    });

    test('une valeur réelle traverse l\'accesseur sans être remplacée', () {
      final digest = ArchiveDigest(
        id: 'd-2',
        stamp: DateTime.utc(2026, 1, 2),
        title: 'Condensé',
      );
      expect(digest.toMap()['stamp'], '2026-01-02T00:00:00.000Z');
    });

    test('round-trip par la factory de domaine : la clé rétrécie survit', () {
      final digest = ArchiveDigest(
        id: 'd-3',
        stamp: DateTime.utc(2026, 3, 4),
        title: 'Condensé',
      );
      final back = ArchiveDigest.fromMap(digest.toMap());
      expect(back.stamp, DateTime.utc(2026, 3, 4));
      expect(back.title, 'Condensé');
    });
  });
}

/// Sous-classe MINIMALE de la base : elle n'ajoute rien, donc son `toMap()` est
/// celui de la base — le témoin de ce que l'extension morte aurait rendu.
class _PlainArchive extends ArchiveBase {
  _PlainArchive() : super(id: 'a-0', label: 'Nu');
}
