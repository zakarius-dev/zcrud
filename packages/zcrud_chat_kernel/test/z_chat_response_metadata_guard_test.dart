// CHAT-7 — gardes de SOURCE de la carte de fin de réponse.
//
// 🔴 G-C7a : `ZChatResponseConfidence` / `ZChatSourceFreshness` sont livrés par
// CHAT-0 et étaient RESTÉS SANS CONSOMMATEUR. Le réflexe qui a déjà coûté deux
// fois dans ce dépôt (CR-LEX-78) est d'en re-déclarer une variante « locale au
// lot » plutôt que de câbler l'existant. Cette garde est le **grep négatif**
// qui rougit à la seconde déclaration — une absence non prouvée par un grep
// n'est pas une preuve.
//
// 🔴 G-C7b : la carte ne modélise QUE ce qui a été lu dans le code du serveur.
// Cinq des sept codes d'erreur reconnus par ce paquet n'existent dans AUCUN
// backend ; la garde vérifie que la carte n'a pas reproduit le motif en
// inventant des clés, et qu'elle reste une carte OUVERTE (slot `extra`).
//
// ⚠️ `@TestOn('vm')` + `library;` OBLIGATOIRES : ce fichier lit les SOURCES du
// dépôt (`dart:io`) via `support/z_repo_sources.dart` et serait incompilable
// sous `dart test -p node` (gate `web-determinism`).
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

/// Sites de déclaration d'une classe [name] dans `packages/*/lib`.
List<String> declarationSites(String name) {
  final RegExp decl = RegExp('^\\s*(abstract\\s+|sealed\\s+|final\\s+|base\\s+|'
      'interface\\s+|mixin\\s+)*class\\s+$name\\b');
  final List<String> sites = <String>[];
  final List<File> files = packageLibDartFiles();
  expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
  for (final File f in files) {
    final List<String> lines = strippedLines(f);
    for (int i = 0; i < lines.length; i++) {
      if (decl.hasMatch(lines[i])) sites.add('${f.path}:${i + 1}');
    }
  }
  return sites;
}

void main() {
  group('G-C7a — AUCUN doublon des types de verdict de CHAT-0', () {
    for (final String name in <String>[
      'ZChatResponseConfidence',
      'ZChatSourceFreshness',
      'ZChatConfidenceFactor',
      'ZChatConfidenceThresholds',
    ]) {
      test('`$name` est déclaré EXACTEMENT une fois dans packages/*/lib', () {
        final List<String> sites = declarationSites(name);
        expect(sites, hasLength(1),
            reason: sites.isEmpty
                ? '🔴 `$name` a DISPARU : la garde ne prouve plus rien et le '
                    'câblage de CHAT-7 est cassé.'
                : '🔴 DOUBLON de `$name` (classe de défaut CR-LEX-78, déjà '
                    'payée DEUX fois ici). CHAT-7 doit CÂBLER le type livré '
                    'par CHAT-0, jamais en redéclarer une variante :\n'
                    '${sites.join('\n')}');
      });
    }

    test('la carte de fin de réponse IMPORTE les deux types existants '
        '(preuve POSITIVE du câblage)', () {
      final String src = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/ai/'
        'z_chat_response_metadata.dart',
      ).readAsStringSync();
      expect(src, contains("import '../z_chat_response_confidence.dart';"));
      expect(src, contains("import '../z_chat_source_freshness.dart';"));
      expect(src, contains('ZChatResponseConfidence.fromJson'),
          reason: 'le décodage de confiance doit DÉLÉGUER à CHAT-0');
      expect(src, contains('ZChatSourceFreshness.fromJson'));
    });
  });

  group('G-C7b — la carte reste OUVERTE et ne modélise QUE le mesuré', () {
    late String src;
    late List<String> code;

    setUp(() {
      final File f = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/ai/'
        'z_chat_response_metadata.dart',
      );
      expect(f.existsSync(), isTrue, reason: 'garde VACUELLE : fichier absent');
      src = f.readAsStringSync();
      code = strippedLines(f);
    });

    test('un slot `extra` OUVERT existe (aucune clé inconnue jetée)', () {
      expect(code.any((String l) => l.contains('Map<String, dynamic> extra')),
          isTrue,
          reason: '🔴 sans slot ouvert, la carte est un enregistrement FIGÉ : '
              'une API publique zcrud est irréversible, et le backend de lex '
              'évolue.');
    });

    test('les clés typées sont EXACTEMENT celles lues dans routes.py', () {
      // Mesuré : `_build_confidence_metadata` (routes.py:85-97) + la base du
      // `done_metadata` (routes.py:1292-1315) + `source_freshness`
      // (routes.py:1311). Rien de plus n'est deviné.
      const List<String> attendues = <String>[
        'duration_ms',
        'agents_called',
        'cost_total_usd',
        'tokens_total',
        'source_freshness',
        'faithfulness_score',
        'completeness_score',
        'quality_grade',
        'citation_guard_status',
        'citations_verified',
        'citations_rejected',
        'coverage_status',
      ];
      for (final String k in attendues) {
        expect(src, contains("'$k'"), reason: 'clé mesurée absente : $k');
      }
      // Clés JAMAIS observées dans les deux backends : les modéliser
      // reproduirait le motif des cinq codes d'erreur fantômes.
      for (final String interdite in <String>[
        'confidence_level',
        'hallucination_score',
        'clarification_needed',
        'rag_score',
        'trust_score',
      ]) {
        expect(src.contains("'$interdite'"), isFalse,
            reason: '🔴 clé INVENTÉE `$interdite` : aucun backend ne l\'émet.');
      }
    });

    test('aucun codegen (AD-3) : ni `part`, ni annotation de sérialisation', () {
      for (final String l in code) {
        expect(RegExp(r'^\s*part\s').hasMatch(l), isFalse, reason: l);
        expect(l.contains('@JsonSerializable'), isFalse, reason: l);
        expect(l.contains('@ZcrudModel'), isFalse, reason: l);
      }
    });

    test('la carte est exportée par le barrel (sinon elle est INATTEIGNABLE)',
        () {
      final String barrel = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/'
        'zcrud_chat_kernel.dart',
      ).readAsStringSync();
      expect(barrel, contains('src/domain/ai/z_chat_response_metadata.dart'));
    });
  });
}
