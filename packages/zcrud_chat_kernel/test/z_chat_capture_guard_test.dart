// CHAT-10 — gardes **SOURCE** de la saisie assistée.
//
// 🔴 Volet le plus important du lot : rendre l'envoi direct d'une transcription
// **inexprimable**, et le PROUVER autrement qu'en le promettant en dartdoc.
// Une garde de comportement ne peut pas le faire : elle exerce le chemin qui
// passe par le contrat, elle est aveugle à celui qui le contourne. C'est donc
// un grep négatif OUTILLÉ, exécuté par une machine à chaque `dart test`.
//
// ⚠️ `@TestOn('vm')` OBLIGATOIRE (`dart:io`) — gate `web-determinism` :
// `dart test -p node` rejoue TOUTE la suite de ce paquet pur-Dart, et un test
// qui lit les sources est incompilable en JavaScript.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

/// Le fichier des ports de capture.
File _captureFile() => File(
  '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/capture/'
  'z_chat_capture_port.dart',
);

/// Le corps d'une classe/enum déclarée au premier niveau, dé-commenté.
List<String> _bodyOf(String declaration) {
  final List<String> lines = strippedLines(_captureFile());
  final int start = lines.indexWhere(
    (String l) => RegExp('^$declaration\\b').hasMatch(l),
  );
  expect(start, greaterThanOrEqualTo(0),
      reason: '🔴 `$declaration` introuvable — la garde serait VACUELLE');
  final List<String> body = <String>[];
  for (int i = start + 1; i < lines.length; i++) {
    if (RegExp(r'^\}').hasMatch(lines[i])) break;
    body.add(lines[i]);
  }
  expect(body, isNotEmpty, reason: '🔴 corps vide : découpeur cassé');
  return body;
}

/// Les **déclarations de membres publics** au premier niveau d'une classe :
/// `(type, nom)`.
///
/// 🔴 Le type de RETOUR est capturé, parce que c'est LUI que la garde juge : la
/// question n'est pas « combien de membres » mais « lequel rend une `String` ».
List<({String type, String name})> _publicMembers(List<String> body) {
  final List<({String type, String name})> out =
      <({String type, String name})>[];
  final RegExp getter = RegExp(r'^\s{2}([\w<>?,\s.]+?)\s+get\s+(\w+)\b');
  final RegExp method = RegExp(r'^\s{2}([\w<>?,\s.]+?)\s+(\w+)\s*\(');
  final RegExp field = RegExp(r'^\s{2}final\s+([\w<>?,\s.]+?)\s+(\w+)\s*[;=]');
  for (final String l in body) {
    if (!RegExp(r'^\s{2}\S').hasMatch(l)) continue;
    final RegExpMatch? m =
        getter.firstMatch(l) ?? field.firstMatch(l) ?? method.firstMatch(l);
    if (m == null) continue;
    final String name = m.group(2)!;
    if (name.startsWith('_')) continue;
    out.add((type: m.group(1)!.trim(), name: name));
  }
  return out;
}

/// `true` si [type] est — ou contient — une `String` qui SORT.
bool _yieldsString(String type) =>
    RegExp(r'\bString\b').hasMatch(type) && !type.startsWith('void');

void main() {
  group('🔴 G10-S1 — L\'ENVOI DIRECT EST INEXPRIMABLE', () {
    test('`ZUnreviewedText` ne déclare AUCUN membre public rendant une '
        '`String`', () {
      final List<({String type, String name})> members =
          _publicMembers(_bodyOf('final class ZUnreviewedText'));
      expect(members, isNotEmpty,
          reason: '🔴 GARDE VACUELLE : aucun membre extrait');
      final List<String> leaks = <String>[
        for (final ({String type, String name}) m in members)
          // 🔴 `toString` est la SEULE dérogation, et elle est NOMMÉE
          // exactement (pas `toStringDeep`, pas `toStringShort`) : sa signature
          // est imposée par `Object`, on ne peut pas la refuser. Elle n'est pas
          // pour autant blanchie — le volet COMPORTEMENTAL
          // (`z_chat_capture_test.dart`, « `toString()` ne FUIT pas le
          // contenu ») asserte qu'elle ne rend PAS le texte. Une dérogation
          // sans garde jumelle serait un trou, pas une exception.
          if (m.name != 'toString' && _yieldsString(m.type))
            '${m.type} ${m.name}',
      ];
      expect(
        leaks,
        isEmpty,
        reason: '🔴 UN MEMBRE PUBLIC REND LE TEXTE CAPTURÉ. C\'est l\'unique '
            'invariant du lot : une transcription vocale et une extraction OCR '
            'sont FAILLIBLES par nature, elles se déposent dans une surface '
            'éditable pour être CORRIGÉES, et ne partent jamais telles quelles. '
            'Chez lex, `DictationResult.text` est un `String` public : la '
            'relecture y tient à la discipline de l\'appelant '
            '(`chat_input.dart` l\'ouvre — un second appelant pourrait ne pas '
            'le faire). Ici elle tient au TYPE. Membres fautifs : $leaks',
      );
      // Volet POSITIF : la sortie unique existe, et elle rend `void`.
      final Iterable<({String type, String name})> deposit =
          members.where((({String type, String name}) m) =>
              m.name == 'depositInto');
      expect(deposit, hasLength(1),
          reason: '🔴 la sortie unique a DISPARU : plus rien ne peut être relu');
      expect(deposit.single.type, 'void',
          reason: '🔴 `depositInto` rend autre chose que `void` : quelque '
              'chose s\'échappe vers l\'appelant');
    });

    test('la surface publique de `ZUnreviewedText`, en ÉGALITÉ d\'ENSEMBLE', () {
      final Set<String> names = _publicMembers(
        _bodyOf('final class ZUnreviewedText'),
      ).map((({String type, String name}) m) => m.name).toSet();
      expect(
        names,
        <String>{'length', 'isBlank', 'isLarge', 'depositInto', 'toString'},
        reason: '🔴 ÉGALITÉ D\'ENSEMBLE, pas « contient » : un membre ajouté '
            'qui rendrait le contenu sous un autre type (`List<int> get '
            'codeUnits`, `Iterable<String> get words`, `Object get value`) '
            'échapperait à la règle « aucune `String` » tout en rouvrant '
            'exactement le même trou.',
      );
    });

    test('le champ porteur est PRIVÉ — la portée du privé est la BIBLIOTHÈQUE',
        () {
      final List<String> body = _bodyOf('final class ZUnreviewedText');
      final Iterable<String> raws =
          body.where((String l) => RegExp(r'\bfinal\s+String\s+_raw\b').hasMatch(l));
      expect(raws, hasLength(1),
          reason: '🔴 le champ porteur a changé de nom ou de visibilité — '
              'toute la garde repose sur le fait qu\'AUCUN autre fichier, '
              'aucun autre paquet, ne peut le lire');
    });

    test('🔬 contre-preuve R3 — l\'extracteur VOIT une fuite et ne confond pas '
        'un type avec un nom', () {
      const List<String> witness = <String>[
        '  final String _raw;',
        '  String get text => _raw;',
        '  int get length => _raw.length;',
        '  void depositInto(ZChatReviewSink sink) {',
        '  Future<String> get later async => _raw;',
        '    if (isBlank) return;',
      ];
      final List<({String type, String name})> got = _publicMembers(witness);
      expect(
        got.map((({String type, String name}) m) => m.name).toList(),
        <String>['text', 'length', 'depositInto', 'later'],
        reason: '🔴 soit l\'extracteur rate un membre public, soit il capture '
            'le champ PRIVÉ ou une ligne de corps — les deux le rendent '
            'inutilisable',
      );
      expect(
        got
            .where((({String type, String name}) m) => _yieldsString(m.type))
            .map((({String type, String name}) m) => m.name)
            .toSet(),
        <String>{'text', 'later'},
        reason: '🔴 la règle doit voir la fuite DIRECTE **et** la fuite '
            'ENVELOPPÉE (`Future<String>`), et épargner `int`/`void`',
      );
    });
  });

  group('🔴 G10-S2 — AD-57 : aucun moteur, aucune dépendance tierce', () {
    /// Les moteurs réels branchés par lex — ils restent CHEZ LUI.
    const List<String> engines = <String>[
      'speech_to_text',
      'google_mlkit',
      'mlkit',
      'image_picker',
      'path_provider',
      'permission_handler',
      'camera',
      'tesseract',
    ];

    test('0 occurrence dans TOUT `packages/zcrud_chat_kernel/lib`', () {
      final List<String> offenders = <String>[];
      final List<File> files = chatDartFiles();
      for (final File f in files) {
        final List<String> lines = strippedLines(f);
        for (int i = 0; i < lines.length; i++) {
          for (final String bad in engines) {
            if (lines[i].contains(bad)) {
              offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 AD-57 : ni moteur de reconnaissance vocale, ni moteur OCR '
            'dans ce paquet — des PORTS, l\'hôte fournit le moteur. Un hôte qui '
            'ne dicte jamais tirerait sinon deux plugins natifs ET leurs '
            'permissions de manifeste.\n${offenders.join('\n')}',
      );
    });

    test('le pubspec ne gagne AUCUNE dépendance', () {
      final File pubspec = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/pubspec.yaml',
      );
      final String src = pubspec.readAsStringSync();
      final int start = src.indexOf('\ndependencies:');
      expect(start, greaterThanOrEqualTo(0), reason: 'bloc introuvable');
      final int end = src.indexOf('\ndev_dependencies:', start);
      final List<String> deps = <String>[
        for (final String l in src.substring(start, end).split('\n'))
          if (RegExp(r'^  (\w+):').hasMatch(l))
            RegExp(r'^  (\w+):').firstMatch(l)!.group(1)!,
      ];
      expect(deps, <String>['zcrud_core'],
          reason: '🔴 le kernel garde UNE seule arête sortante. Vu : $deps');
    });

    test('🔬 contre-preuve — le motif voit son témoin', () {
      expect(
        engines.any(
          (String e) => "import 'package:speech_to_text/speech_to_text.dart';"
              .contains(e),
        ),
        isTrue,
      );
    });
  });

  group('🔴 G10-S3 — l\'origine LEX est CITÉE nommément', () {
    test('les deux services et les deux feuilles de relecture', () {
      final String src = _captureFile().readAsStringSync();
      for (final String cite in <String>[
        'speech_recognition_service.dart',
        'ocr_service.dart',
        'chat_dictation_review_sheet.dart',
        'chat_ocr_review_sheet.dart',
        'dictation_number_normalizer.dart',
      ]) {
        expect(src, contains(cite),
            reason: '🔴 « ne modélise que ce que tu as LU » : le fichier '
                'd\'origine `$cite` doit être NOMMÉ, pour qu\'un relecteur '
                'puisse aller vérifier');
      }
    });

    test('le port est EXPORTÉ par le barrel (sinon il est INATTEIGNABLE)', () {
      final File barrel = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/'
        'zcrud_chat_kernel.dart',
      );
      expect(barrel.readAsStringSync(),
          contains("export 'src/domain/capture/z_chat_capture_port.dart';"));
    });
  });
}
