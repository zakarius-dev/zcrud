// Gardes de SOURCE de la couche SSE : le noyau reste pur-Dart et sans
// bibliothèque HTTP ; le décodeur UTF-8 est tolérant ; le fil n'est plus un
// générateur `async*`.
//
// `@TestOn('vm')` + `library;` : ces gardes lisent le dépôt via `dart:io`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

File _kernelFile(String relative) => File(
      '${repoRoot().path}/packages/zcrud_chat_kernel/lib/$relative',
    );

void main() {
  group('SSE-G — aucune dépendance Flutter ni HTTP dans TOUT `lib/`', () {
    test('0 import `flutter`, `http`, `dio`, `dart:io` sur les lignes de code',
        () {
      const List<String> interdits = <String>[
        'package:flutter/',
        'package:flutter_',
        'package:http/',
        'package:http_',
        'package:dio/',
        'dart:io',
        'dart:html',
      ];
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final File f in chatDartFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          scanned++;
          final String t = line.trimLeft();
          if (!t.startsWith('import ') && !t.startsWith('export ')) continue;
          for (final String bad in interdits) {
            if (t.contains(bad)) offenders.add('${f.path}:$no: $t');
          }
        }
      }
      expect(scanned, greaterThan(1000), reason: 'garde VACUELLE');
      expect(offenders, isEmpty,
          reason: '🔴 le noyau est pur-Dart et ne parle pas au réseau : '
              'l\'ouverture du POST reste à l\'hôte.\n${offenders.join('\n')}');
    });

    test('le `pubspec.yaml` ne gagne aucune dépendance', () {
      final String pubspec = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/pubspec.yaml',
      ).readAsStringSync();
      final List<String> deps = <String>[];
      String section = '';
      for (final String raw in pubspec.split('\n')) {
        final String l = raw.replaceFirst(RegExp(r'#.*$'), '').trimRight();
        if (RegExp(r'^[a-z_]+:').hasMatch(l)) section = l.split(':').first;
        if (!section.endsWith('dependencies')) continue;
        if (RegExp(r'^  [a-z_]+:').hasMatch(l)) deps.add(l.trim().split(':').first);
      }
      expect(deps, <String>['zcrud_core', 'test'],
          reason: 'une seule arête sortante + le runner de test');
    });
  });

  group('SSE-G — forme de l\'ouvreur', () {
    test('le décodeur UTF-8 est TOLÉRANT (`allowMalformed: true`)', () {
      final String src =
          strippedLines(_kernelFile('src/data/sse/z_chat_sse_line.dart'))
              .join('\n');
      expect(src, contains('Utf8Decoder(allowMalformed: true)'),
          reason: '🔴 un octet invalide tuerait le flux entier');
      expect(src, contains('LineSplitter()'));
    });

    test('l\'ouvreur et le port n\'exposent AUCUN `async*` : l\'annulation '
        'doit atteindre la source sans attendre un événement', () {
      for (final String rel in <String>[
        'src/data/sse/z_chat_sse_line.dart',
        'src/data/sse/z_chat_sse_stream_port.dart',
        'src/domain/notebook/z_chat_transcript_port.dart',
      ]) {
        final List<String> lines = strippedLines(_kernelFile(rel));
        final List<String> offenders = <String>[
          for (int i = 0; i < lines.length; i++)
            if (lines[i].contains('async*') &&
                !lines[i].contains('messages(String conversationId) async*'))
              '$rel:${i + 1}: ${lines[i].trim()}',
        ];
        expect(offenders, isEmpty,
            reason: '🔴 un générateur suspendu dans `await for` ne propage '
                'le cancel qu\'au prochain événement.\n${offenders.join('\n')}');
      }
    });

    test('`zChatTranscriptOrEmpty` annule l\'abonnement dans `onCancel`', () {
      final String src = strippedLines(
        _kernelFile('src/domain/notebook/z_chat_transcript_port.dart'),
      ).join('\n');
      final int start = src.indexOf('zChatTranscriptOrEmpty(');
      expect(start, greaterThan(0), reason: 'garde VACUELLE');
      final String body = src.substring(start, src.indexOf('class ZChatInMemory'));
      expect(body, contains('onCancel:'));
      expect(body, contains('.cancel()'));
    });
  });
}
