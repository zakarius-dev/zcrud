/// R3 — preuve du dé-commentateur PARTAGÉ (`stripped`/`libDartFiles`,
/// `support/z_sources.dart`) exercé par TOUTES les gardes converties P0b de
/// `zcrud_firestore`. Une régression ici casserait silencieusement chaque
/// garde qui en dépend — ce fichier est donc la contre-preuve CENTRALE.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'z_sources.dart';

void main() {
  group('🔬 stripped() — robustesse anti-dartdoc (P0b)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('z_sources_probe'));
    tearDown(() => tmp.deleteSync(recursive: true));

    File probe(String content) =>
        File('${tmp.path}/probe.dart')..writeAsStringSync(content);

    test('retire un commentaire de LIGNE `//` en fin de code', () {
      final lines = stripped(probe('final x = 1; // FirebaseException\n'));
      expect(lines.join('\n').contains('FirebaseException'), isFalse);
      expect(lines.join('\n').contains('final x = 1;'), isTrue);
    });

    test('retire un commentaire de BLOC `/* … */` sur une seule ligne', () {
      final lines = stripped(
        probe('final z = 3; /* WriteBatch cité en bloc */ final w = 4;\n'),
      );
      final joined = lines.join('\n');
      expect(joined.contains('WriteBatch'), isFalse);
      expect(joined.contains('final z = 3;'), isTrue);
      expect(joined.contains('final w = 4;'), isTrue);
    });

    test('retire un commentaire de BLOC multi-lignes SANS `*` de continuation '
        '(forme que les scanners ad hoc ligne-à-ligne ratent)', () {
      final lines = stripped(probe(
        '/* Ce bloc mentionne Timestamp\n'
        'et continue sur plusieurs lignes sans prefixe\n'
        'avant de se refermer */\n'
        'final ok = true;\n',
      ));
      final joined = lines.join('\n');
      expect(joined.contains('Timestamp'), isFalse);
      expect(joined.contains('final ok = true;'), isTrue);
    });

    test(
        '🔴 ORDRE : un `/*` littéral CITÉ dans un commentaire `//` ne doit PAS '
        'ouvrir un faux bloc qui avale le code réel qui suit — c\'est '
        'EXACTEMENT le bug mesuré dans l\'ancien `_stripComments` (regex '
        r'/\*[\s\S]*?\*/ appliquée AVANT le retrait des lignes `//`) de '
        '`z_study_migrator_isolation_test.dart`', () {
      final lines = stripped(probe(
        '// exemple de commentaire de bloc : /* comme ceci */\n'
        'final vraiCode = FirebaseFirestore.instance; // ceci DOIT être vu\n',
      ));
      final joined = lines.join('\n');
      expect(joined.contains('exemple de commentaire'), isFalse);
      expect(joined.contains('FirebaseFirestore.instance'), isTrue,
          reason: '🔴 le VRAI code a été avalé par un faux bloc ouvert dans '
              'un commentaire de ligne : régression de l\'ordre `//` avant `/*`');
    });

    test('un littéral de chaîne contenant `//` n\'ouvre pas de commentaire',
        () {
      final lines = stripped(probe(
        "final uri = 'https://pub.dev/packages/cloud_firestore'; // Timestamp\n",
      ));
      final joined = lines.join('\n');
      expect(joined.contains('https://pub.dev'), isTrue,
          reason: 'l\'URL, dans la chaîne, doit SURVIVRE au strip');
      expect(joined.contains('Timestamp'), isFalse,
          reason: 'le VRAI commentaire de fin de ligne, lui, doit disparaître');
    });

    test('un littéral de chaîne contenant `/*` n\'ouvre pas de bloc', () {
      final lines = stripped(probe(
        "final s = 'motif /* pas un vrai bloc */ litteral';\n"
        'final apres = WriteBatch;\n',
      ));
      final joined = lines.join('\n');
      expect(joined.contains('litteral'), isTrue);
      expect(joined.contains('WriteBatch'), isTrue,
          reason: 'le `/*` dans la CHAÎNE ne doit pas avaler la ligne suivante');
    });

    test('préserve le NOMBRE de lignes (les numéros signalés restent exacts)',
        () {
      final File f = probe(
        'line1;\n'
        '/* bloc\n'
        'sur plusieurs\n'
        'lignes */\n'
        'line5;\n',
      );
      expect(stripped(f), hasLength(5));
    });

    test('(I2) une violation en dartdoc/commentaire ne survit PAS au strip '
        '— la garde doit rester VERTE sur ce motif', () {
      final lines = stripped(probe(
        '/// Interdit ici : `FirebaseException` — voir AD-5.\n'
        '// ni `cloud_firestore` sur cette ligne\n'
        '/* ni WriteBatch ici */\n'
        'final licite = 1;\n',
      ));
      final joined = lines.join('\n');
      for (final banned in <String>[
        'FirebaseException',
        'cloud_firestore',
        'WriteBatch',
      ]) {
        expect(joined.contains(banned), isFalse,
            reason: '🔴 motif "$banned" cité en COMMENTAIRE a survécu au '
                'strip : une garde convertie rougirait sur de la PROSE');
      }
    });

    test('(I1) une violation en CODE réel survit au strip — la garde doit '
        'pouvoir rougir dessus', () {
      final lines = stripped(probe('final b = WriteBatch();\n'));
      expect(lines.join('\n').contains('WriteBatch'), isTrue,
          reason: '🔴 une vraie violation de CODE a disparu du strip : la '
              'garde deviendrait aveugle à une régression réelle');
    });
  });

  group('🔬 libDartFiles() — non-vacuité (I3)', () {
    test('le balayage RÉEL de zcrud_firestore/lib est non-vide (borne basse '
        'de plausibilité)', () {
      final files = libDartFiles();
      expect(files.length, greaterThan(10),
          reason: '🔴 GARDE VACUELLE : ${files.length} fichier(s) — trop peu '
              'pour être un balayage réel de zcrud_firestore/lib');
    });

    test('🔴 (I3) un balayage sur un répertoire VIDE doit ROUGIR — c\'est la '
        'même primitive `expect(files, isNotEmpty)` que `libDartFiles()` '
        'applique ; on la met ici en échec CONTRÔLÉ pour prouver qu\'elle sait '
        'rougir', () {
      final Directory empty =
          Directory.systemTemp.createTempSync('z_sources_vacuous');
      addTearDown(() => empty.deleteSync(recursive: true));
      final List<File> nothing = empty
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList();
      expect(nothing, isEmpty, reason: 'témoin : le dossier est bien vide');
      expect(
        () => expect(nothing, isNotEmpty, reason: 'aucun fichier scanné'),
        throwsA(isA<TestFailure>()),
        reason: '🔴 la primitive de non-vacuité ne rougit plus sur un '
            'balayage vide : `libDartFiles()` serait VERTE pour de mauvaises '
            'raisons si `lib/` disparaissait',
      );
    });
  });
}
