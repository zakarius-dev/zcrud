// CHAT-9 — gardes qui LISENT LES SOURCES du dépôt.
//
// ⚠️ `@TestOn('vm')` + `library;` OBLIGATOIRES : `dart:io` est incompilable en
// JavaScript, et le gate `web-determinism` rejoue `dart test -p node` sur
// CHAQUE package pur-Dart. Sans l'annotation, TOUTE la suite du paquet devient
// non exécutable en JS.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

File _portsFile() => File(
  '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/conversation/'
  'z_chat_conversation_ports.dart',
);

File _speechFile() => File(
  '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/diffusion/'
  'z_chat_speech_port.dart',
);

/// Le CODE seul (commentaires retirés) : les dartdoc de ce lot CITENT
/// légitimement les routes HTTP de lex pour documenter qu'on ne les porte pas.
String _code(File f) {
  expect(f.existsSync(), isTrue, reason: '🔴 GARDE VACUELLE : ${f.path}');
  final List<String> lines = strippedLines(f);
  expect(lines.length, greaterThan(50),
      reason: '🔴 GARDE VACUELLE : ${lines.length} ligne(s) de code lues.');
  return lines.join('\n');
}

void main() {
  group('G9-P4 — AD-11 : aucun TRANSPORT dans les ports de conversation', () {
    // Vocabulaire de transport réellement présent chez lex (`conversations.py`)
    // et qu'un portage paresseux aurait recopié.
    const List<String> forbidden = <String>[
      'http', 'Http', 'HTTP',
      'Uri', 'Dio', 'dio',
      'StatusCode', 'statusCode',
      'endpoint', 'Endpoint',
      'GET ', 'POST ', 'PATCH ', 'DELETE ',
      '/conversations', '/shared/',
      'Firestore', 'firestore', 'FieldFilter',
      'EventSource', 'SseClient',
    ];

    test('le fichier de ports ne contient aucun terme de transport (CODE seul)',
        () {
      final String code = _code(_portsFile());
      final List<String> hits = <String>[
        for (final String term in forbidden)
          if (code.contains(term)) term,
      ];
      expect(hits, isEmpty,
          reason: '🔴 AD-11 VIOLÉ : le transport a fui dans le domaine. '
              'Termes trouvés : $hits');
    });

    test('🔬 CONTRE-PREUVE — le motif VOIT un terme interdit', () {
      const String sample = "  final Uri endpoint = Uri.parse('/conversations');";
      expect(forbidden.any(sample.contains), isTrue,
          reason: '🔴 la garde est décorative : elle ne verrait pas une '
              'régression réelle.');
    });

    test('les ports sont bien des INTERFACES (aucune implémentation cachée)',
        () {
      final String code = _code(_portsFile());
      for (final String port in <String>[
        'ZChatConversationSearchPort',
        'ZChatConversationPinPort',
        'ZChatConversationSharePort',
        'ZChatConversationLifecyclePort',
      ]) {
        expect(code, contains('abstract interface class $port'),
            reason: '🔴 `$port` n\'est plus un port : un satellite ne peut '
                'plus le remplacer.');
      }
    });
  });

  group('G9-P5 — AD-9 : AUCUN hard-delete dans le kernel de chat', () {
    // 🔴 Le `delete_messages_after` de lex fait `batch.delete(...)`. Ces verbes
    // sont ceux par lesquels la même chose reviendrait ici.
    final RegExp purge = RegExp(
      r'\b(purge|hardDelete|erase|wipe|destroy|deleteForever|permanentlyDelete)\b',
      caseSensitive: false,
    );

    test('0 verbe de purge dans zcrud_chat_kernel/lib (CODE seul)', () {
      final List<String> offenders = <String>[];
      final List<File> files = chatDartFiles();
      for (final File f in files) {
        final List<String> lines = strippedLines(f);
        for (int i = 0; i < lines.length; i++) {
          if (purge.hasMatch(lines[i])) {
            offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 AD-9 : le retrait est un SOFT-DELETE (`is_deleted` de '
              '`ZSyncMeta`). Une purge empêche le merge Last-Write-Wins de '
              'propager le retrait — le distant réhydrate ce que le local a '
              'effacé.\n${offenders.join('\n')}');
    });

    test('🔬 CONTRE-PREUVE — le motif VOIT une purge', () {
      expect(purge.hasMatch('  Future<void> hardDelete(String id);'), isTrue);
      expect(purge.hasMatch('  Future<void> purge(String id);'), isTrue);
      // …et NE voit pas un mot ordinaire qui contient « delete ».
      expect(purge.hasMatch('  Future<ZResult<Unit>> retire(String id);'),
          isFalse);
    });

    test('le port de cycle de vie porte bien `restore` — la contrepartie que '
        'seul un soft-delete rend possible', () {
      expect(_code(_portsFile()), contains('restore('),
          reason: '🔴 sans restauration, le soft-delete n\'est qu\'un '
              'hard-delete plus lent : la garde ci-dessus deviendrait '
              'purement lexicale.');
    });
  });

  group('G9-D1 — la voix RÉUTILISE le résumé annonçable, elle ne le refait pas',
      () {
    test('`z_chat_speech_port.dart` APPELLE `zChatAccessibleTextOf`', () {
      expect(_code(_speechFile()), contains('zChatAccessibleTextOf('),
          reason: '🔴 le câblage a disparu : un second aplatissement de blocs '
              'est en train de naître.');
    });

    test('…et n\'écrit AUCUN `switch` sur la famille de blocs', () {
      final String code = _code(_speechFile());
      for (final String term in <String>[
        'ZTextBlock',
        'ZTableBlock',
        'ZSourcesBlock',
        'ZCustomContentBlock',
      ]) {
        expect(code.contains(term), isFalse,
            reason: '🔴 `$term` est nommé dans la diffusion vocale : c\'est '
                'la signature d\'un aplatissement DUPLIQUÉ, donc d\'un '
                'variant futur qui ne sera pas lu à voix haute.');
      }
    });

    test('aucune langue par défaut codée en dur (le `\'fr\'` de lex)', () {
      final String code = _code(_speechFile());
      expect(RegExp("""languageTag\\s*[:=]\\s*['"]""").hasMatch(code), isFalse,
          reason: '🔴 le socle choisit la langue de lecture à la place de '
              'l\'hôte — exactement ce que `null` existe pour éviter.');
    });
  });
}
