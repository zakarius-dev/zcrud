// CHAT-1 — gardes MACHINE des ports IA (G-C1 … G-C7).
//
// 🔴 « Une absence non prouvée par un grep négatif n'est pas une preuve. »
// Ce fichier est ce grep, rejoué à chaque `dart test`.
//
// ⚠️ `@TestOn('vm')` OBLIGATOIRE : ces gardes lisent les SOURCES du dépôt
// (`dart:io`) ⇒ incompilables en JavaScript. Sans l'annotation, le gate
// `web-determinism` (`dart test -p node` sur chaque package pur-Dart) rend
// TOUTE la suite du package non exécutable. Même patron que
// `z_chat_naming_guard_test.dart` et `z_chat_action_contract_guard_test.dart`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

/// Le dossier des ports IA (CHAT-1).
Directory _aiDir() => Directory(
      '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/ai',
    );

/// Les `.dart` des ports IA — jamais vide (sinon toute garde serait VACUELLE).
List<File> _aiFiles() {
  final Directory dir = _aiDir();
  expect(dir.existsSync(), isTrue, reason: '${dir.path} introuvable');
  final List<File> files = dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
  expect(files, isNotEmpty, reason: 'aucun fichier IA scanné : garde VACUELLE');
  return files;
}

File _aiFile(String name) => File('${_aiDir().path}/$name');

/// Déclaration de CHAMP : une ligne, hors commentaire, se terminant par `;`,
/// de la forme `[modificateurs] Type nom [= …];` — et **rien d'autre**.
///
/// 🟢 Leçon du lot précédent (garde anti-champ-mutable défaillante) : une
/// détection qui n'accepte que `final|late|static|var` **laisse passer**
/// `String? currentRequestId;`, qui est exactement la forme du bug d'IFFD.
/// Le groupe de modificateurs est donc **optionnel**.
final RegExp _fieldDecl = RegExp(
  r'^\s{2,}((?:static\s+|late\s+|final\s+|const\s+|covariant\s+)*)'
  r'([A-Za-z_][\w<>,?\s\.]*?)\s+'
  r'(_?[a-zA-Z]\w*)\s*(=[^;]*)?;\s*$',
);

/// Les déclarations de CHAMP du fichier : `(numéro de ligne, ligne, match)`.
///
/// ⚠️ Les **getters** (`T get x => …;`) matchent la forme d'un champ ; ils sont
/// écartés ici, et NULLE PART ailleurs — un champ mutable ne s'écrit jamais
/// avec `=>`, l'exclusion n'affaiblit donc aucune des deux gardes.
List<({int line, String text, RegExpMatch match})> _fieldDecls(File f) {
  final List<({int line, String text, RegExpMatch match})> out =
      <({int line, String text, RegExpMatch match})>[];
  int no = 0;
  for (final String line in strippedLines(f)) {
    no++;
    if (line.contains('=>') || RegExp(r'\bget\s').hasMatch(line)) continue;
    // Une INSTRUCTION (`return … ;`) n'est pas une déclaration de champ.
    if (RegExp(r'^\s*(return|yield|throw|assert|await|if|for|while|switch)\b')
        .hasMatch(line)) {
      continue;
    }
    final RegExpMatch? m = _fieldDecl.firstMatch(line);
    if (m == null) continue;
    out.add((line: no, text: line, match: m));
  }
  return out;
}

void main() {
  group('G-C1 — le jeton d\'annulation est PAR REQUÊTE, jamais partagé', () {
    test('G-C1a — aucun CHAMP de type `ZChatRequestToken` (forme IFFD)', () {
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final File f in _aiFiles()) {
        for (final ({int line, String text, RegExpMatch match}) d
            in _fieldDecls(f)) {
          scanned++;
          if (d.match.group(2)!.replaceAll('?', '').trim() ==
              'ZChatRequestToken') {
            offenders.add('${f.path}:${d.line}: ${d.text.trim()}');
          }
        }
      }
      expect(scanned, greaterThan(10),
          reason: 'aucun champ détecté : garde VACUELLE');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 JETON D\'INSTANCE RÉINTRODUIT. IFFD porte '
            '`CancelToken cancel = CancelToken();` comme CHAMP de son dépôt IA '
            '(`iffd/lib/src/data/repositories/iffd_ai_repository_impl.dart:29`, '
            'même forme `openai_ai_repository_impl.dart:18`) : « stop » y annule '
            'la DERNIÈRE requête lancée, pas celle que l\'utilisateur désigne. '
            'Le jeton doit rester un PARAMÈTRE de l\'appel.\n'
            '${offenders.join('\n')}',
      );
    });

    test('G-C1b — aucun CHAMP MUTABLE (la forme `String? currentRequestId;`)',
        () {
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final File f in _aiFiles()) {
        for (final ({int line, String text, RegExpMatch match}) d
            in _fieldDecls(f)) {
          scanned++;
          final String modifiers = d.match.group(1)!;
          if (modifiers.contains('final') || modifiers.contains('const')) {
            continue;
          }
          offenders.add('${f.path}:${d.line}: ${d.text.trim()}');
        }
      }
      expect(scanned, greaterThan(10),
          reason: 'aucun champ détecté : garde VACUELLE');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 ÉTAT MUTABLE dans un contrat de port. Un identifiant de '
            'requête « courante » stocké sur l\'instance est le jeton partagé '
            'd\'IFFD sous un autre type. Une garde du lot précédent ne '
            'cherchait que `final|late|static|var` et laissait passer '
            'exactement cette forme.\n${offenders.join('\n')}',
      );
    });

    test('G-C1c — les deux ports exigent le jeton EN PARAMÈTRE', () {
      final String src = _aiFile('z_chat_generation_port.dart').readAsStringSync();
      for (final String signature in <String>[
        'required ZChatRequestToken token,',
      ]) {
        expect(
          RegExp(RegExp.escape(signature)).allMatches(src).length,
          2,
          reason: 'les DEUX ports (one-shot + streaming) doivent exiger le '
              'jeton en paramètre requis',
        );
      }
      expect(src, contains('abstract interface class ZChatGenerationPort'));
      expect(src, contains('abstract interface class ZChatStreamPort'));
    });
  });

  group('G-C2 — la forme de lex, portée telle quelle (AD-5)', () {
    test('le streaming est `Stream<ZResult<ZChatStreamEvent>>`', () {
      final String src =
          _aiFile('z_chat_generation_port.dart').readAsStringSync();
      expect(
        src,
        contains('Stream<ZResult<ZChatStreamEvent>> stream('),
        reason: 'signature de `lex_core/lib/domain/repositories/'
            'chat_repository.dart:24` — `Stream<Either<Failure, '
            'ChatStreamEvent>>`',
      );
      // Le fichier d'origine LEX doit être cité nommément (traçabilité).
      expect(src, contains('lex_core/lib/domain/repositories/chat_repository.dart'));
    });

    test('AUCUN variant d\'ERREUR dans la famille scellée — l\'échec est le '
        '`Left`, et lui seul', () {
      final List<String> offenders = <String>[];
      int no = 0;
      for (final String line
          in strippedLines(_aiFile('z_chat_stream_event.dart'))) {
        no++;
        final RegExpMatch? m =
            RegExp(r'^class\s+(\w+)\s+extends\s+ZChatStreamEvent').firstMatch(line);
        if (m == null) continue;
        final String name = m.group(1)!;
        if (name.contains('Error') || name.contains('Failure')) {
          offenders.add('${_aiFile('z_chat_stream_event.dart').path}:$no: $name');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 DEUX canaux d\'échec pour un flux. lex porte '
            '`ChatErrorEvent` DANS le `Right` en plus du `Left(Failure)` : un '
            'échec y passe pour un succès. AD-5 : le `Left` est le seul canal.'
            '\n${offenders.join('\n')}',
      );
    });

    test('la famille est bien SCELLÉE + variant OUVERT (AD-4)', () {
      final String src = _aiFile('z_chat_stream_event.dart').readAsStringSync();
      expect(src, contains('sealed class ZChatStreamEvent'));
      expect(src, contains('class ZChatCustomStreamEvent extends ZChatStreamEvent'));
      expect(src, contains('tryCodecFor'),
          reason: 'l\'ouverture passe par ZTypeRegistry, jamais par héritage '
              'externe');
    });
  });

  group('G-C3 — aucune SENTINELLE TEXTUELLE dans le modèle de chat', () {
    test('grep négatif sur les balises d\'IFFD, dans TOUT `lib/src/domain/`',
        () {
      const List<String> sentinelles = <String>[
        'RAG_THINKING',
        'RAG_ITERATION',
        'AI_MODEL_REASONING',
        'RAG_REQUESTS',
      ];
      final List<String> offenders = <String>[];
      for (final File f in chatDartFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          for (final String s in sentinelles) {
            if (line.contains(s)) offenders.add('${f.path}:$no: ${line.trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 SENTINELLE TEXTUELLE. IFFD insère `<RAG_THINKING>` dans le '
            'CORPS du message (`iffd_ai_repository_impl.dart:140` et `:154`) '
            'puis la retire par une regex recopiée dans CINQ fichiers de '
            'présentation. La réflexion est ici un VARIANT '
            '(`ZChatThinkingEvent`).\n${offenders.join('\n')}',
      );
    });

    test('la réflexion est STRUCTURÉE : `ZChatThinkingEvent` porte le '
        '`ZChatThinkingStep` EXISTANT', () {
      final String src = _aiFile('z_chat_stream_event.dart').readAsStringSync();
      expect(src, contains('class ZChatThinkingEvent extends ZChatStreamEvent'));
      expect(src, contains('final ZChatThinkingStep step;'));
      expect(src, contains("import '../z_chat_thinking_step.dart';"),
          reason: 'le type EXISTANT est importé, pas redéclaré');
    });
  });

  group('G-C4 — `ZQuotaExceededFailure` est CÂBLÉE, pas redéclarée', () {
    test('grep NÉGATIF : aucune failure de quota déclarée hors du cœur', () {
      final RegExp decl =
          RegExp(r'^\s*(?:abstract\s+)?class\s+(\w*Quota\w*Failure)\b');
      const String seulSite =
          'packages/zcrud_core/lib/src/domain/failures/z_failure.dart';
      final List<String> offenders = <String>[];
      final List<File> files = packageLibDartFiles();
      expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
      for (final File f in files) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          final RegExpMatch? m = decl.firstMatch(line);
          if (m == null) continue;
          if (f.path.endsWith(seulSite)) continue;
          offenders.add('${f.path}:$no: ${m.group(1)}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 DOUBLON de `ZQuotaExceededFailure`, qui existe déjà dans '
            '$seulSite (avec son `retryAfter`). Motif CR-LEX-78.\n'
            '${offenders.join('\n')}',
      );
    });

    test('grep POSITIF : le type EXISTANT est réellement CONSTRUIT par les '
        'ports IA (premier consommateur)', () {
      // 🔴 CHAT-1b — DEUX défauts de cette garde, corrigés ensemble.
      //
      // (1) Elle lisait la source BRUTE (`readAsStringSync`) alors que sa
      //     propre raison dit « du CODE, pas une dartdoc » : une ligne
      //     `/// return ZQuotaExceededFailure(` l'aurait satisfaite. Elle lit
      //     désormais les lignes DÉCOMMENTÉES, ce que sa raison affirmait déjà.
      // (2) Elle exigeait le littéral `return ZServerFailure(`, forme que le
      //     code n'a plus : le repli est devenu TERNAIRE pour conserver le code
      //     du fournisseur (`ZChatProviderFailure`) au lieu de le jeter. La
      //     garde rougissait sur une AMÉLIORATION. Ce qu'elle doit vraiment
      //     interdire, c'est qu'un code inconnu cesse d'être TYPÉ — donc les
      //     DEUX branches du repli sont désormais exigées nommément.
      final String code = strippedLines(_aiFile('z_chat_ai_failure.dart'))
          .join('\n');
      expect(code, isNotEmpty, reason: 'garde VACUELLE : source vide');
      expect(
        RegExp(r'return ZQuotaExceededFailure\(').hasMatch(code),
        isTrue,
        reason: 'le câblage doit être du CODE, pas une dartdoc : '
            '`ZQuotaExceededFailure` n\'avait AUCUN consommateur avant CHAT-1',
      );
      expect(code, contains('return ZUnsupportedOperationFailure('),
          reason: 'type EXISTANT (CHAT-0b/D9) réutilisé, jamais redéclaré');
      expect(
        RegExp(r'ZServerFailure\(\s*message\s*\)').hasMatch(code),
        isTrue,
        reason: 'repli TYPÉ quand il n\'y a AUCUN code — jamais le texte brut',
      );
      expect(
        RegExp(r'ZChatProviderFailure\(\s*message,\s*code:').hasMatch(code),
        isTrue,
        reason: '🔴 un code de fournisseur NON catalogué doit être CONSERVÉ '
            'dans une failure typée (`AGENT_TIMEOUT`, `LLM_ERROR`…), pas '
            'écrasé en `ZServerFailure` : c\'est ce que le client Dart de lex '
            'jette, et ce que ce socle corrige',
      );
    });

    test('les trois familles créées étendent `ZFailure` DIRECTEMENT '
        '(hiérarchie PLATE)', () {
      final String src = _aiFile('z_chat_ai_failure.dart').readAsStringSync();
      for (final String name in <String>[
        'ZChatModerationFailure',
        'ZChatContextLimitFailure',
        'ZChatStreamInterruptedFailure',
      ]) {
        expect(src, contains('class $name extends ZFailure {'),
            reason: '$name doit être un FRÈRE, pas un héritier d\'un autre '
                'sous-type');
      }
    });
  });

  group('G-C5 — le style est EXTENSIBLE sans modifier le socle (AD-4)', () {
    test('`ZChatGenerationStyle` n\'est PAS un enum fermé', () {
      final String src =
          _aiFile('z_chat_generation_style.dart').readAsStringSync();
      expect(src.contains('enum ZChatGenerationStyle'), isFalse);
      expect(src, contains('class ZChatGenerationStyle'));
      expect(src, contains('final String kind;'));
      expect(src, contains('tryCodecFor'),
          reason: 'l\'extension passe par le ZTypeRegistry EXISTANT');
    });

    test('AUCUN second registre n\'est créé (le motif CR-LEX-78)', () {
      final RegExp decl = RegExp(r'^\s*class\s+\w*Registry\b');
      final List<String> offenders = <String>[];
      for (final File f in _aiFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          if (decl.hasMatch(line)) {
            offenders.add('${f.path}:$no: ${line.trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 `ZTypeRegistry`/`ZSourceRegistry` existent déjà '
            '(`zcrud_core/lib/src/domain/registry/`) et servent ces axes.\n'
            '${offenders.join('\n')}',
      );
    });

    test('la GAMIFICATION d\'IFFD n\'entre PAS au catalogue du socle', () {
      final RegExp styleConst =
          RegExp(r"ZChatGenerationStyle\('([a-zA-Z_]+)'\)");
      final String src =
          _aiFile('z_chat_generation_style.dart').readAsStringSync();
      final Set<String> declares = <String>{
        for (final RegExpMatch m
            in styleConst.allMatches(strippedLines(_aiFile(
          'z_chat_generation_style.dart',
        )).join('\n')))
          m.group(1)!,
      };
      expect(declares, isNotEmpty, reason: 'garde VACUELLE : rien de détecté');
      expect(
        declares.intersection(<String>{
          'poem',
          'poemes',
          'story',
          'history',
          'humor',
          'humour',
          'classroom',
          'creatif',
          'inspirational',
        }),
        isEmpty,
        reason: '🔴 « poème / histoire / humour / séance de cours » sont de la '
            'GAMIFICATION propre à IFFD (`iffd/lib/src/domain/models/ai/'
            'ai_models.dart:9-19`, où l\'enum porte en plus un libellé français '
            'et une icône Material). Un hôte les déclare par '
            "`ZChatGenerationStyle('poem')` — le socle ne les impose ni à lex "
            'ni à DODLP.',
      );
      expect(src, contains('ai_models.dart:9-19'),
          reason: 'l\'origine IFFD doit être citée nommément');
    });
  });

  group('G-C6 — aucune chaîne d\'INTERFACE en dur (AD-13/FR-26)', () {
    test('aucun libellé/titre/icône exposé par les ports IA', () {
      const List<String> interdits = <String>[
        'displayName',
        'iconName',
        'colorValue',
        'Icons.',
        'Colors.',
      ];
      final List<String> offenders = <String>[];
      for (final File f in _aiFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          for (final String bad in interdits) {
            if (line.contains(bad)) {
              offenders.add('${f.path}:$no: ${line.trim()}');
            }
          }
          // Un champ/getter `title`/`label` sur un port serait un libellé
          // d'affichage dans le domaine.
          if (RegExp(r'\b(String|String\?)\s+(title|label)\s*[;=]')
              .hasMatch(line)) {
            offenders.add('${f.path}:$no: ${line.trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'présentation dans le domaine — le libellé et l\'icône '
              'appartiennent à l\'hôte (i18n `ZcrudLabels`, thème) :\n'
              '${offenders.join('\n')}');
    });

    test('aucun littéral de chaîne ACCENTUÉ (donc destiné à un humain) dans '
        'le CODE des ports', () {
      final RegExp accentue = RegExp(r"'[^']*[àâäéèêëîïôöùûüçÀÉÈÊÎÔÛÇ][^']*'");
      final List<String> offenders = <String>[];
      for (final File f in _aiFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          if (accentue.hasMatch(line)) {
            offenders.add('${f.path}:$no: ${line.trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'chaîne destinée à un humain, codée en dur dans un package '
              '(FR-26) :\n${offenders.join('\n')}');
    });
  });

  group('G-C7 — les ports d\'ARTEFACTS EXISTANTS sont câblés, pas dupliqués',
      () {
    test('aucun membre de génération de flashcards/mindmap dans les ports IA',
        () {
      const List<String> interdits = <String>[
        'generateFlashcards',
        'generateMindmap',
        'ZFlashcardGenerationPort',
        'ZMindmapGenerationPort',
        'ZFlashcardGenerationRequest',
        'ZMindmapGenerationRequest',
      ];
      final List<String> offenders = <String>[];
      for (final File f in _aiFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          for (final String bad in interdits) {
            if (line.contains(bad)) {
              offenders.add('${f.path}:$no: ${line.trim()}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 DOUBLON PLUS PAUVRE (motif CR-LEX-78). '
            '`ZFlashcardGenerationPort` et `ZMindmapGenerationPort` existent '
            'déjà dans `packages/zcrud_study/lib/src/domain/` — avec '
            '`typesDistribution`, `maxDepth`, `provenance`. Le noyau de chat '
            'ne peut de toute façon pas en dépendre (AD-1).\n'
            '${offenders.join('\n')}',
      );
    });

    test('les ports EXISTANTS sont NOMMÉS par leur chemin dans la dartdoc, et '
        'ces chemins EXISTENT sur disque', () {
      final String src =
          _aiFile('z_chat_generation_port.dart').readAsStringSync();
      for (final String chemin in <String>[
        'packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart',
        'packages/zcrud_study/lib/src/domain/z_mindmap_generation_port.dart',
      ]) {
        expect(src, contains(chemin),
            reason: 'le port EXISTANT à câbler doit être nommé, sinon un hôte '
                'ne peut pas savoir qu\'il existe');
        expect(File('${repoRoot().path}/$chemin').existsSync(), isTrue,
            reason: '🔴 chemin cité mais INEXISTANT : la dartdoc mentirait');
      }
    });

    test('AUCUN style `flashcards`/`mindmap` au catalogue du socle', () {
      final String src = strippedLines(_aiFile('z_chat_generation_style.dart'))
          .join('\n');
      for (final String bad in <String>[
        "ZChatGenerationStyle('flashcards')",
        "ZChatGenerationStyle('mindmap')",
      ]) {
        expect(src.contains(bad), isFalse,
            reason: '🔴 $bad détournerait la génération d\'artefacts vers un '
                'port de TEXTE, alors que le port dédié existe');
      }
    });
  });

  group('G-C9 — UNE identité de requête, ZÉRO nom de transport', () {
    test('G-C9a — aucun SECOND identifiant de requête déclaré', () {
      // Un champ parallèle ferait diverger « ce que j'annule » de « ce que je
      // reprends » : c'est le défaut d'IFFD un cran plus haut.
      const List<String> interdits = <String>[
        'idempotencyKey',
        'idempotency_key',
        'idempotencyToken',
        'turnId',
        'turn_id',
        'correlationId',
        'correlation_id',
        'currentRequestId',
        'activeRequestId',
        'requestUuid',
        // 🔴 CHAT-1b — `lastEventId` nommait la POSITION d'après l'en-tête qui
        // la transporte, pas d'après la donnée du domaine
        // (`ZChatStreamEvent.sequenceId`). Le nom canonique est
        // `lastSequenceId` ; l'ancien est désormais interdit, sans quoi les
        // deux orthographes cohabiteraient et l'une des deux serait morte.
        'lastEventId',
        'last_event_id',
      ];
      final List<String> offenders = <String>[];
      // 🔴 CHAT-1b — le balayage porte sur TOUT `lib/src/domain/`, pas sur le
      // seul `ai/` : un second identifiant déclaré dans `action/` ou sur
      // `ZChatMessage` serait exactement la même divergence, et la garde ne
      // l'aurait pas vu.
      int scanned = 0;
      for (final File f in chatDartFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          scanned++;
          for (final String bad in interdits) {
            if (line.contains(bad)) {
              offenders.add('${f.path}:$no: ${line.trim()}');
            }
          }
        }
      }
      // 🔴 Sans ce contrôle, un `strippedLines` cassé (ou un dossier renommé)
      // rendrait `offenders` vide et la garde SILENCIEUSEMENT VACUELLE — le
      // faux vert exact que ce lot chasse.
      expect(scanned, greaterThan(1000),
          reason: 'trop peu de lignes scannées : garde VACUELLE');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 SECOND IDENTIFIANT. `requestId` est déjà celui que '
            '`ZChatActionExecutor.cancelRequest(String)` annule (CHAT-0b/D4) '
            'ET celui qui rend la reprise idempotente. Deux champs = deux '
            'vérités.\n${offenders.join('\n')}',
      );
    });

    test('G-C9b — aucun nom d\'EN-TÊTE HTTP dans le code du domaine', () {
      // Le domaine modélise le BESOIN, pas le transport (AD-11/AD-12). Les
      // dartdoc peuvent nommer les en-têtes ; le CODE, jamais.
      const List<String> entetes = <String>[
        'last-event-id',
        'idempotency-key',
        'retry-after',
        'x-chat-quota',
        'x-prepaid',
        'x-request-id',
        'x-ratelimit',
        'www-authenticate',
        'content-type',
        'authorization',
      ];
      final List<String> offenders = <String>[];
      // 🔴 CHAT-1b — TOUT `lib/src/domain/` : une fuite de transport dans
      // `action/` ou dans une entité serait la même violation d'AD-11.
      int scanned = 0;
      for (final File f in chatDartFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          scanned++;
          final String lower = line.toLowerCase();
          for (final String bad in entetes) {
            if (lower.contains(bad)) {
              offenders.add('${f.path}:$no: ${line.trim()}');
            }
          }
        }
      }
      expect(scanned, greaterThan(1000),
          reason: 'trop peu de lignes scannées : garde VACUELLE');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 NOM DE TRANSPORT dans le domaine. Les clés par défaut de '
            '`ZChatQuotaKeys` sont LOGIQUES (`limit`, `remaining`…) : c\'est '
            'l\'adaptateur de l\'hôte qui projette ses en-têtes dessus. Figer '
            'un en-tête ici rendrait le socle faux pour tout hôte qui n\'est '
            'pas lex.\n${offenders.join('\n')}',
      );
    });

    test('G-C9c — le jeton expose la REPRISE, et `resumeFrom` préserve '
        'l\'identité', () {
      // 🔴 CHAT-1b — sur les lignes DÉCOMMENTÉES : la dartdoc de ce fichier
      // cite abondamment ses propres signatures, et une garde qui lit la
      // source brute se serait satisfaite d'un exemple en commentaire.
      final String src =
          strippedLines(_aiFile('z_chat_request_token.dart')).join('\n');
      expect(src, contains('final String? lastSequenceId;'));
      expect(src, contains('ZChatRequestToken resumeFrom('));
      // 🔴 L'identité DOIT être reconduite telle quelle dans la reprise.
      expect(
        src,
        contains('ZChatRequestToken(requestId, lastSequenceId: lastSequenceId)'),
        reason: 'un `requestId` renouvelé à la reprise ferait rejouer le tour',
      );
      // 🔴 …et AUCUN appelant ne doit pouvoir le renouveler : un paramètre
      // `requestId` optionnel sur `resumeFrom` rouvrirait exactement la
      // divergence « ce que j'annule » ≠ « ce que je reprends ».
      final RegExpMatch? sig =
          RegExp(r'ZChatRequestToken\s+resumeFrom\(([^)]*)\)').firstMatch(src);
      expect(sig, isNotNull, reason: 'signature introuvable : garde VACUELLE');
      expect(
        sig!.group(1),
        isNot(contains('requestId')),
        reason: '🔴 `resumeFrom` laisse renouveler l\'identité : on reprendrait '
            'un tour sous une identité que `cancelRequest` ne connaît plus.',
      );
    });

    test('G-C9d — les clés de quota par DÉFAUT sont logiques, pas des '
        'en-têtes', () {
      // 🔴 CHAT-1b — forme POSITIVE, complémentaire du grep négatif G-C9b :
      // celui-ci ne connaît que les en-têtes de lex, et laisserait passer
      // `'quota-limit'` ou `'X-Foo-Quota'` d'un autre transport. Ici, c'est
      // l'ORTHOGRAPHE d'en-tête elle-même (tirets, préfixe `x-`) qui est
      // interdite comme défaut du socle.
      final String code =
          strippedLines(_aiFile('z_chat_quota_metadata.dart')).join('\n');
      final List<RegExpMatch> defauts =
          RegExp(r"this\.(\w+)\s*=\s*'([^']*)'").allMatches(code).toList();
      expect(defauts.length, 5,
          reason: 'les CINQ clés de quota doivent porter un défaut : garde '
              'VACUELLE si la forme change (détecté : '
              '${defauts.map((RegExpMatch m) => m.group(1)).toList()})');
      for (final RegExpMatch m in defauts) {
        final String cle = m.group(2)!;
        expect(cle, isNotEmpty, reason: 'clé vide pour `${m.group(1)}`');
        expect(cle, isNot(contains('-')),
            reason: '🔴 `$cle` (clé `${m.group(1)}`) est une orthographe '
                'D\'EN-TÊTE. Le défaut du socle doit être une clé LOGIQUE '
                'neutre (`limit`, `remaining`, `reset_epoch`…) que '
                'l\'adaptateur alimente depuis là où le quota se trouve CHEZ '
                'LUI — en-tête HTTP, métadonnée gRPC ou champ de corps.');
        expect(cle.toLowerCase().startsWith('x'), isFalse,
            reason: '🔴 `$cle` porte un préfixe d\'en-tête propriétaire');
      }
    });
  });

  group('G-C10 — la position de reprise est portée par TOUS les événements',
      () {
    test('le type scellé déclare `sequenceId`, et chaque variant le relaie',
        () {
      final File f = _aiFile('z_chat_stream_event.dart');
      final String src = f.readAsStringSync();
      expect(src, contains('final String? sequenceId;'),
          reason: 'sans position, le protocole reprenable est inapplicable');
      final List<String> variants = <String>[
        for (final RegExpMatch m
            in RegExp(r'class (ZChat\w+Event) extends ZChatStreamEvent')
                .allMatches(strippedLines(f).join('\n')))
          m.group(1)!,
      ];
      expect(variants.length, 9, reason: 'variants détectés : $variants');
      final int relais = RegExp('super.sequenceId')
          .allMatches(strippedLines(f).join('\n'))
          .length;
      expect(
        relais,
        variants.length,
        reason: '🔴 un variant ne relaie PAS la position : à la reprise, un '
            'événement de ce type ne pourra jamais servir de point de reprise.',
      );
    });

    test('la position est ÉMISE par chaque `toJson`', () {
      final List<String> lines =
          strippedLines(_aiFile('z_chat_stream_event.dart'));
      final int emis = lines
          .where((String l) => l.contains("'sequence_id': sequenceId"))
          .length;
      expect(emis, 9,
          reason: 'un variant n\'émet pas sa position : elle serait perdue au '
              'premier aller-retour de sérialisation');
    });
  });

  group('G-C8 — le barrel expose la surface CHAT-1', () {
    test('TOUS les fichiers de ports sont exportés (liste DÉRIVÉE du disque)',
        () {
      // 🔴 CHAT-1b — la liste était écrite À LA MAIN (« les six fichiers »).
      // Elle a dû être rallongée à la main quand CHAT-1b a ajouté
      // `z_chat_compute_effort.dart` et `z_chat_quota_metadata.dart` : jusque
      // -là, un fichier de port NON exporté — donc un type INATTEIGNABLE pour
      // l'hôte — ne faisait rougir aucune garde. La liste vient désormais du
      // DISQUE : le prochain fichier ajouté est couvert sans qu'on y pense.
      final String barrel = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/'
        'zcrud_chat_kernel.dart',
      ).readAsStringSync();
      final List<File> files = _aiFiles();
      expect(files.length, greaterThanOrEqualTo(8),
          reason: 'trop peu de fichiers de ports scannés : garde VACUELLE');
      for (final File f in files) {
        final String name = f.uri.pathSegments.last;
        expect(barrel, contains('src/domain/ai/$name'),
            reason: '🔴 `$name` n\'est PAS exporté par le barrel : son type '
                'est INATTEIGNABLE depuis un hôte, quoi qu\'en dise la story.');
      }
    });
  });
}
