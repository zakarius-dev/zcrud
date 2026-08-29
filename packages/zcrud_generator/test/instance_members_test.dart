// Cas d'or GEN-1 : le codegen émis en MEMBRES D'INSTANCE (mixin `_$XxxZcrud`),
// et pas seulement en membres d'extension.
//
// Ce que ces gardes tiennent, et pourquoi :
//   1. ATTEIGNABILITÉ — une hiérarchie dont la racine déclare `toMap()` /
//      `copyWith()` ABSTRAITS ne peut rien faire d'un membre d'extension : il
//      ne satisfait jamais un membre abstrait hérité et reste invisible à un
//      appel fait à travers le type de base. La fixture `dispatch_note.dart`
//      NE COMPILERAIT PAS si le mixin n'était pas émis — sa seule présence dans
//      les imports est déjà une assertion.
//   2. IDENTITÉ DE SÉRIALISATION — les corps émis dans l'extension et dans le
//      mixin proviennent d'UNE SEULE source de texte. La garde compare les deux
//      blocs émis caractère par caractère : appliquer le mixin ne peut donc pas
//      changer la map produite. C'est la garde maîtresse de non-rupture des
//      contrats de données.
//   3. TÉMOIN À LA MAIN — la map produite par la classe qui applique le mixin
//      est comparée à une map écrite à la main (mêmes clés, même ORDRE, même
//      encodage JSON).
@TestOn('vm')
library;

import 'dart:convert';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_generator/src/zcrud_model_generator.dart';

import 'models/dispatch_note.dart';

const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

// Interpolés : ces sources n'existent qu'en mémoire (`gate:codegen` ne doit pas
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

/// Source minimale à deux champs — un scalaire, un enum nullable.
const _source = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

enum Grade { low, high }

$_model(kind: 'probe')
class Probe {
  const Probe({this.id, required this.title, this.grade});
  factory Probe.fromMap(Map<String, dynamic> map) => _\$ProbeFromMap(map);
  @ZcrudId()
  final String? id;
  $_field()
  final String title;
  $_field()
  final Grade? grade;
}
''';

/// Extrait le corps `{ … }` du premier bloc dont l'en-tête commence par
/// [header], en équilibrant les accolades. Retourne le texte SANS la ligne
/// d'en-tête ni l'accolade fermante.
String _bodyOf(String emitted, String header) {
  final start = emitted.indexOf(header);
  expect(start, isNot(-1), reason: 'bloc absent de l\'émission : $header');
  final open = emitted.indexOf('{', start);
  var depth = 0;
  for (var i = open; i < emitted.length; i++) {
    if (emitted[i] == '{') depth++;
    if (emitted[i] == '}') {
      depth--;
      if (depth == 0) return emitted.substring(open + 1, i);
    }
  }
  fail('bloc non fermé : $header');
}

void main() {
  group('GEN-1 — le mixin d\'instance est émis', () {
    test('le bloc `mixin _\$XxxZcrud` existe, avec un getter abstrait par '
        'champ persisté, dans l\'ordre des champs', () async {
      final emitted = await _emitText(_source);
      expect(emitted, contains('mixin _\$ProbeZcrud {'));
      final body = _bodyOf(emitted, 'mixin _\$ProbeZcrud');
      final getters = body
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('String?') ||
              l.startsWith('String ') ||
              l.startsWith('Grade?'))
          .toList();
      // Égalité STRICTE : ni `containsAll`, ni `length >=`. Un getter manquant
      // rend le mixin inapplicable, un getter en trop le rend non satisfiable.
      expect(getters, <String>[
        'String? get id;',
        'String get title;',
        'Grade? get grade;',
      ]);
    });

    test('l\'extension publique `XxxZcrud` est CONSERVÉE — le mixin s\'ajoute, '
        'il ne remplace pas', () async {
      final emitted = await _emitText(_source);
      expect(emitted, contains('extension ProbeZcrud on Probe {'));
    });
  });

  group('GEN-1 — identité de sérialisation extension ↔ mixin', () {
    test('les corps `toMap`/`copyWith` des deux blocs sont IDENTIQUES '
        'caractère par caractère', () async {
      final emitted = await _emitText(_source);
      final ext = _bodyOf(emitted, 'extension ProbeZcrud on Probe');
      final mix = _bodyOf(emitted, 'mixin _\$ProbeZcrud');
      // Le mixin porte en tête ses getters abstraits ; le reste doit être le
      // corps de l'extension, à l'octet.
      expect(mix.endsWith(ext), isTrue,
          reason: 'le corps du mixin diverge de celui de l\'extension.\n'
              '--- extension ---\n$ext\n--- mixin ---\n$mix');
      expect(ext.trim(), isNotEmpty);
      expect(ext, contains('Map<String, dynamic> toMap()'));
      expect(ext, contains('Probe copyWith('));
    });
  });

  group('GEN-1 — atteignabilité réelle (fixture compilée)', () {
    // `DispatchNote extends DispatchModel with _$DispatchNoteZcrud`, où
    // `DispatchModel` déclare `toMap()`/`copyWith()` ABSTRAITS. Sans membres
    // d'instance générés, cette fixture ne compile pas.
    final note = DispatchNote(
      id: 'd-1',
      subject: 'Envoi',
      status: DispatchStatus.sent,
      attempts: 2,
      sentAt: DateTime.utc(2026, 8, 29, 10, 30),
      tags: const <String>['urgent', 'nord'],
    );

    test('`toMap()` répond À TRAVERS le type de base (appel polymorphe)', () {
      final DispatchModel base = note;
      expect(base.toMap()['subject'], 'Envoi');
      expect(base.toMap()['status'], 'sent');
    });

    test('`copyWith()` répond à travers le type de base et rend le type '
        'concret', () {
      final DispatchModel base = note;
      final copy = base.copyWith();
      expect(copy, isA<DispatchNote>());
      expect((copy as DispatchNote).attempts, 2);
    });

    test('la sentinelle `copyWith` survit aux membres d\'instance : omis '
        'préserve, `null` explicite remet à null', () {
      expect(note.copyWith().sentAt, DateTime.utc(2026, 8, 29, 10, 30));
      expect(note.copyWith(sentAt: null).sentAt, isNull);
      expect(note.copyWith(attempts: 5).attempts, 5);
    });

    test('la map produite est identique — clés, ORDRE et encodage JSON — à '
        'celle du témoin écrit à la main', () {
      final witness = DispatchEcho(
        id: 'd-1',
        subject: 'Envoi',
        status: DispatchStatus.sent,
        attempts: 2,
        sentAt: DateTime.utc(2026, 8, 29, 10, 30),
        tags: const <String>['urgent', 'nord'],
      ).toMap();
      final produced = note.toMap();
      expect(produced.keys.toList(), witness.keys.toList());
      expect(jsonEncode(produced), jsonEncode(witness));
    });

    test('round-trip par la factory de domaine : fromMap(toMap(x)) fidèle', () {
      final back = DispatchNote.fromMap(note.toMap());
      expect(jsonEncode(back.toMap()), jsonEncode(note.toMap()));
    });
  });
}
