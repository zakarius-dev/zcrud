// Gardes de la NORMALISATION du fil textuel d'IFFD (CHAT-6, AD-5/AD-10).
//
// 🔴 Ces gardes portent sur du COMPORTEMENT, pas sur la présence de symboles :
// chacune décrit une régression réelle observée chez IFFD et vérifie que le
// décodeur ne la reproduit pas. Une garde qui se contenterait d'appeler
// `add('x')` sans asserter le canal ne rougirait sur aucune inversion.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_syncfusion/zcrud_chat_syncfusion.dart';
import 'package:zcrud_core/domain.dart';

/// Pousse [chunks] puis ferme, et rend tous les résultats.
List<ZResult<ZChatStreamEvent>> run(List<String> chunks) {
  final ZIffdStreamNormalizer n = ZIffdStreamNormalizer();
  final List<ZResult<ZChatStreamEvent>> out = <ZResult<ZChatStreamEvent>>[];
  for (final String c in chunks) {
    out.addAll(n.add(c));
  }
  out.addAll(n.close());
  return out;
}

/// Le texte de tous les `ZChatTokenEvent` — le CORPS effectivement affiché.
String answerOf(List<ZResult<ZChatStreamEvent>> events) {
  final StringBuffer b = StringBuffer();
  for (final ZResult<ZChatStreamEvent> e in events) {
    e.forEach((ZChatStreamEvent ev) {
      if (ev is ZChatTokenEvent) b.write(ev.content);
    });
  }
  return b.toString();
}

/// Le texte de tous les `ZChatThinkingEvent` — la TRACE.
String thinkingOf(List<ZResult<ZChatStreamEvent>> events) {
  final StringBuffer b = StringBuffer();
  for (final ZResult<ZChatStreamEvent> e in events) {
    e.forEach((ZChatStreamEvent ev) {
      if (ev is ZChatThinkingEvent) b.writeln(ev.step.content);
    });
  }
  return b.toString();
}

/// Toutes les `ZFailure` émises en `Left`.
List<ZFailure> failuresOf(List<ZResult<ZChatStreamEvent>> events) => <ZFailure>[
  for (final ZResult<ZChatStreamEvent> e in events)
    ...e.fold((ZFailure f) => <ZFailure>[f], (_) => const <ZFailure>[]),
];

void main() {
  group('G1 · `###LINE###` est décodé, y compris COUPÉ entre deux fragments',
      () {
    test('décodage nominal', () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        'une ligne###LINE###deux lignes',
      ]);
      expect(answerOf(out), 'une ligne\ndeux lignes');
      expect(answerOf(out), isNot(contains('###LINE###')));
    });

    test('marqueur coupé en deux fragments SSE', () {
      // 🔴 Le cas que `replaceAll` par fragment ne peut PAS traiter : IFFD
      // laisserait `###LI` visible dans la réponse.
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        'avant###LI',
        'NE###après',
      ]);
      expect(answerOf(out), 'avant\naprès');
      expect(answerOf(out), isNot(contains('#')));
    });

    test('marqueur INCOMPLET en fin de flux : rendu tel quel, jamais perdu',
        () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>['fin###LI']);
      expect(answerOf(out), 'fin###LI');
    });
  });

  group('G2 · une erreur textuelle devient un `Left` typé, JAMAIS un message',
      () {
    test('`⚠️ Erreur <Agent> : …` n\'apparaît dans AUCUN token', () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        'Réponse utile.###LINE###',
        '⚠️ Erreur AnalysisAgent : boom###LINE###',
        'suite de la réponse',
      ]);
      // Le corps affiché ne contient pas l'erreur…
      expect(answerOf(out), isNot(contains('Erreur AnalysisAgent')));
      expect(answerOf(out), contains('Réponse utile.'));
      expect(answerOf(out), contains('suite de la réponse'));
      // …et l'erreur est un Left typé, code conservé.
      final List<ZFailure> f = failuresOf(out);
      expect(f, hasLength(1));
      expect(f.single, isA<ZChatProviderFailure>());
      expect(
        (f.single as ZChatProviderFailure).code,
        ZIffdFailureCodes.plainAgentError,
      );
      expect(f.single.message, contains('AnalysisAgent'));
    });

    test('erreur en clair émise CARACTÈRE PAR CARACTÈRE reste un Left', () {
      // Le fil SSE fragmente arbitrairement : la détection ne doit pas dépendre
      // d'un découpage favorable.
      final String line = '⚠️ Erreur QualityAgent : timeout\n';
      final List<String> chunks = <String>[
        for (int i = 0; i < line.length; i++) line[i],
      ];
      final List<ZResult<ZChatStreamEvent>> out = run(chunks);
      expect(answerOf(out), isEmpty);
      expect(failuresOf(out), hasLength(1));
    });

    test('un `⚠️` QUI N\'EST PAS une erreur reste du contenu', () {
      // Contrôle négatif : sans lui, la garde passerait avec un décodeur qui
      // jetterait tout ce qui commence par `⚠️`.
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        '⚠️ ATTENTION : sous-évaluation probable',
      ]);
      expect(answerOf(out), contains('ATTENTION'));
      expect(failuresOf(out), isEmpty);
    });

    test('une balise d\'erreur (`<RAG_ERROR_2>`) devient un Left typé', () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        '<RAG_THINKING><RAG_ERROR_2> Erreur de décodage JSON'
            '</RAG_ERROR_2></RAG_THINKING>corps',
      ]);
      expect(answerOf(out), 'corps');
      final List<ZFailure> f = failuresOf(out);
      expect(f, hasLength(1));
      expect(
        (f.single as ZChatProviderFailure).code,
        ZIffdFailureCodes.taggedError,
      );
    });
  });

  group('G3 · une sentinelle NON REFERMÉE ne perd pas le contenu utile', () {
    test('le contenu postérieur est émis, pas jeté', () {
      // 🔴 Régression IFFD : `reasoning` reste `true` pour toujours
      // (`iffd_ai_repository_impl.dart:140-155`) et TOUT le reste du tour est
      // publié comme `data: ""`. Ici rien n'attend le `</RAG_THINKING>`.
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        '<RAG_THINKING>je réfléchis###LINE###',
        'contenu utile jamais refermé',
      ]);
      final String all = answerOf(out) + thinkingOf(out);
      expect(all, contains('contenu utile jamais refermé'));
      expect(all, contains('je réfléchis'));
    });

    test('aucune exception, et la balise elle-même n\'est jamais rendue', () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        '<RAG_THINKING>trace',
      ]);
      expect(answerOf(out) + thinkingOf(out), isNot(contains('RAG_THINKING')));
    });
  });

  group('G4 · une balise INCONNUE ne lève pas et ne pollue pas la réponse', ()
  {
    test('balise jamais vue : trace, pas réponse, pas de throw', () {
      late List<ZResult<ZChatStreamEvent>> out;
      expect(
        () => out = run(<String>[
          'début###LINE###<AGENT_INCONNU_42>bruit</AGENT_INCONNU_42>###LINE###fin',
        ]),
        returnsNormally,
      );
      expect(answerOf(out), contains('début'));
      expect(answerOf(out), contains('fin'));
      expect(answerOf(out), isNot(contains('bruit')));
      expect(thinkingOf(out), contains('bruit'));
      expect(answerOf(out), isNot(contains('AGENT_INCONNU_42')));
    });

    test('fermante ORPHELINE : ignorée, jamais rendue comme texte', () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        'a</RAG_THINKING>b',
      ]);
      expect(answerOf(out), 'ab');
      expect(failuresOf(out), isEmpty);
    });

    test('un `<` littéral du texte n\'est PAS pris pour une balise', () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        'si a < b alors <div>html</div>',
      ]);
      expect(answerOf(out), 'si a < b alors <div>html</div>');
    });

    test('balise PARAMÉTRÉE `<ROUND n>` appariée sur son argument', () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        'A<ROUND 1>tour un</ROUND 1>B',
      ]);
      expect(answerOf(out), 'AB');
      expect(thinkingOf(out), contains('tour un'));
    });
  });

  group('G5 · charge utile structurée et préfixe `\$` du serveur', () {
    test('`<FINAL_ANSWER_PAYLOAD>` devient un variant OUVERT', () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        'corps<FINAL_ANSWER_PAYLOAD>{"a":1}</FINAL_ANSWER_PAYLOAD>',
      ]);
      expect(answerOf(out), 'corps');
      final ZChatCustomStreamEvent ev = out
          .expand(
            (ZResult<ZChatStreamEvent> e) =>
                e.fold((_) => const <ZChatStreamEvent>[], (ZChatStreamEvent v) => <ZChatStreamEvent>[v]),
          )
          .whereType<ZChatCustomStreamEvent>()
          .single;
      expect(ev.kind, kZIffdFinalAnswerPayloadKind);
      expect(ev.payload['a'], 1);
    });

    test('JSON ILLISIBLE : conservé sous `raw`, aucune exception (AD-10)', () {
      late List<ZResult<ZChatStreamEvent>> out;
      expect(
        () => out = run(<String>[
          '<FINAL_ANSWER_PAYLOAD>{ceci n\'est pas du json'
              '</FINAL_ANSWER_PAYLOAD>',
        ]),
        returnsNormally,
      );
      final ZChatCustomStreamEvent ev = out
          .expand(
            (ZResult<ZChatStreamEvent> e) =>
                e.fold((_) => const <ZChatStreamEvent>[], (ZChatStreamEvent v) => <ZChatStreamEvent>[v]),
          )
          .whereType<ZChatCustomStreamEvent>()
          .single;
      expect(ev.payload['raw'], contains('pas du json'));
    });

    test('payload NON REFERMÉ : vidé à la fermeture, jamais perdu', () {
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        '<FINAL_ANSWER_PAYLOAD>{"a":2}',
      ]);
      final ZChatCustomStreamEvent ev = out
          .expand(
            (ZResult<ZChatStreamEvent> e) =>
                e.fold((_) => const <ZChatStreamEvent>[], (ZChatStreamEvent v) => <ZChatStreamEvent>[v]),
          )
          .whereType<ZChatCustomStreamEvent>()
          .single;
      expect(ev.payload['a'], 2);
    });

    test('le `\$` collé devant une balise est retiré, ailleurs conservé', () {
      // `vector_store_service.py:394` : `f"${event} ###LINE###"`.
      final List<ZResult<ZChatStreamEvent>> out = run(<String>[
        r'$<CACHE_HIT>depuis le cache</CACHE_HIT>',
      ]);
      expect(answerOf(out), isEmpty);
      expect(thinkingOf(out), contains('depuis le cache'));

      final List<ZResult<ZChatStreamEvent>> latex = run(<String>[
        r'le prix est de 5$ hors taxes',
      ]);
      expect(answerOf(latex), contains(r'5$'));
    });
  });

  group('G6 · aucun `sequenceId` n\'est FABRIQUÉ', () {
    test('les événements sortent sans identité de reprise', () {
      // Numéroter ici ferait croire que `ZChatRequestToken.resumeFrom` est
      // honoré alors qu\'IFFD rejouerait le tour entier.
      final List<ZResult<ZChatStreamEvent>> out = run(<String>['a###LINE###b']);
      for (final ZResult<ZChatStreamEvent> e in out) {
        e.forEach((ZChatStreamEvent ev) => expect(ev.sequenceId, isNull));
      }
    });
  });

  group('G7 · la réponse est rendue AU FIL DE L\'EAU (SM-1)', () {
    test('un fragment sans saut de ligne est émis sans attendre le `\\n`', () {
      final ZIffdStreamNormalizer n = ZIffdStreamNormalizer();
      final List<ZResult<ZChatStreamEvent>> first = n.add(
        'Voici une réponse longue',
      );
      // 🔴 Si la garde n\'assertait que le CUMUL final, un décodeur qui
      // bufferise tout jusqu\'à `close()` passerait au vert.
      expect(answerOf(first), 'Voici une réponse longue');
    });
  });

  group('G8 · réponse NON streamée : `error` devient un Left', () {
    test('`{"error": …}` n\'est jamais un bloc de contenu', () {
      final ZResult<List<ZContentBlock>> r = zIffdDecodeNonStreamResponse(
        <String, dynamic>{'error': 'boom', 'responseCode': 500},
      );
      expect(r.isLeft(), isTrue);
      r.leftMap((ZFailure f) {
        expect((f as ZChatProviderFailure).code, '500');
        return f;
      });
    });

    test('`{"data": …}` devient un bloc de texte', () {
      final ZResult<List<ZContentBlock>> r = zIffdDecodeNonStreamResponse(
        <String, dynamic>{'data': '# titre'},
      );
      expect(r.isRight(), isTrue);
      expect(
        r.getOrElse(() => const <ZContentBlock>[]).single,
        isA<ZTextBlock>(),
      );
    });

    test('corps illisible ⇒ Left, jamais une exception (AD-10)', () {
      late ZResult<List<ZContentBlock>> r;
      expect(() => r = zIffdDecodeNonStreamBody('<html>502'), returnsNormally);
      expect(r.isLeft(), isTrue);
    });

    test('map VIDE ⇒ bloc vide, jamais une exception', () {
      final ZResult<List<ZContentBlock>> r = zIffdDecodeNonStreamResponse(
        const <String, dynamic>{},
      );
      expect(r.isRight(), isTrue);
    });
  });
}
