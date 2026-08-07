// CR-IFFD-73 — LE STREAMING, la seule question difficile de cette CR.
//
// La CR la pose sans savoir y répondre, et le dit. Ce fichier y répond par la
// MESURE, et garde les mesures REJOUABLES : chaque chiffre du dartdoc de
// `ZChatMarkdownRenderer` a son banc ici. Les bancs impriment ; les gardes
// assertent le COMPORTEMENT qui en découle.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_markdown/zcrud_chat_markdown.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'support/render_probe.dart';

/// Message d'allure réaliste — la forme que produit un modèle de langage.
const String kRealisticMessage = '''
**Introduction**

Le commerce international est essentiel pour la croissance économique des
nations. Il repose sur des règles négociées au sein d'organisations dédiées.

**PREMIERE PARTIE : LES ORGANISATIONS INTERNATIONALES ET REGIONALES**

1. L'Organisation Mondiale du Commerce (OMC)
2. La Conférence des Nations Unies sur le Commerce et le Développement
3. L'Organisation Mondiale des Douanes (OMD)

Les principes fondamentaux sont :

- la clause de la nation la plus favorisée ;
- le traitement national ;
- la transparence des mesures.

> « Le commerce doit être libre, équitable et prévisible. »

---

*Conclusion* : le cadre multilatéral reste **déterminant**.
''';

String _plain(List<Map<String, dynamic>> ops) {
  final StringBuffer b = StringBuffer();
  for (final Map<String, dynamic> op in ops) {
    final Object? ins = op['insert'];
    if (ins is String) {
      b.write(ins);
    } else if (ins is Map) {
      b.write('<<${ins.keys.first}>>');
    }
  }
  return b.toString();
}

String _attrs(List<Map<String, dynamic>> ops) {
  final Set<String> seen = <String>{};
  for (final Map<String, dynamic> op in ops) {
    final Object? a = op['attributes'];
    if (a is Map) {
      seen.addAll(a.keys.map((Object? k) => '$k'));
    }
  }
  final List<String> l = seen.toList()..sort();
  return l.join(',');
}

ZChatBlockRenderRequest _streamingReq(ValueListenable<String> live) =>
    ZChatBlockRenderRequest(
      block: const ZTextBlock(),
      message: const ZChatMessage(
        id: 'r1',
        conversationId: 'c1',
        role: ZChatRole.assistant,
      ),
      isStreaming: true,
      streamingText: live,
    );

Future<void> _mount(
  WidgetTester tester,
  ZChatBlockRenderRequest request, {
  ZChatMarkdownRenderer? renderer,
}) async {
  final Widget view = ZChatBlockView(request: request);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: renderer == null
              ? view
              : ZChatRendererScope(renderer: renderer, child: view),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const ZMarkdownCodec codec = ZMarkdownCodec();

  // ══════════════════════════════════════════════════════════════════════════
  // MESURE 1 — un fragment INCOMPLET dégrade-t-il, ou casse-t-il ?
  // ══════════════════════════════════════════════════════════════════════════
  group('MESURE 1 — dégradation d\'un Markdown INCOMPLET', () {
    // Tronqué exactement là où ça fait mal.
    const Map<String, String> fragments = <String, String>{
      'gras non fermé': 'Voici **Introduction',
      'italique non fermé': 'Voici *un',
      'titre en cours': '## Premi',
      'table à une ligne': '| a | b |',
      'table entête+séparateur': '| a | b |\n|---|---|',
      'fence non refermée': '```dart\nfinal x = 1;',
      'lien coupé': 'voir [OMC](https://',
      'formule ouverte': r'valeur $$V = P',
      'liste en cours': '- premier\n- deux',
      'filet en cours': '**',
    };

    test('AUCUN fragment ne fait lever le décodeur (AD-10)', () {
      final ZMarkdownCodec withLatex = ZMarkdownCodec(
        bridges: ZMarkdownBridges.latex,
      );
      for (final MapEntry<String, String> e in fragments.entries) {
        for (final ZMarkdownCodec c in <ZMarkdownCodec>[codec, withLatex]) {
          expect(
            () => c.decode(e.value),
            returnsNormally,
            reason: '🔴 « ${e.key} » fait lever le décodeur — pendant un flux, '
                'c\'est l\'état NORMAL du texte.',
          );
        }
      }
    });

    test('BANC (trace) : ce que rend chaque fragment', () {
      for (final MapEntry<String, String> e in fragments.entries) {
        final List<Map<String, dynamic>> ops = codec.decode(e.value);
        // ignore: avoid_print
        print('${e.key.padRight(24)} -> ${_plain(ops).trim()} '
            '| attrs=[${_attrs(ops)}]');
      }
    });

    test(
      '🔴 le texte n\'est jamais MANGÉ : la syntaxe non close reste littérale',
      () {
        // C'est la propriété qui rend la dégradation ACCEPTABLE plutôt que
        // destructrice : rien ne disparaît, le `**` attend simplement sa
        // fermeture.
        expect(
          _plain(codec.decode('Voici **Introduction')),
          contains('**Introduction'),
        );
        expect(_plain(codec.decode('voir [OMC](https://')), contains('OMC'));
        expect(_plain(codec.decode(r'valeur $$V = P')), contains(r'$$V = P'));
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // MESURE 2 — l'ARTEFACT : le rendu change-t-il de FORME jeton à jeton ?
  // ══════════════════════════════════════════════════════════════════════════
  group('MESURE 2 — le clignotement, mesuré', () {
    const String src = 'Le **commerce** est *libre*';

    test('BANC (trace) : chaque changement de forme, préfixe par préfixe', () {
      String? prev;
      for (int i = 1; i <= src.length; i++) {
        final String a = _attrs(codec.decode(src.substring(0, i)));
        if (a != prev) {
          // ignore: avoid_print
          print('i=${i.toString().padLeft(3)} attrs=[$a] '
              'texte=${_plain(codec.decode(src.substring(0, i))).trim()}');
          prev = a;
        }
      }
    });

    test(
      '🔴 L\'ARTEFACT EST RÉEL : à 14 caractères, le futur GRAS est en ITALIQUE',
      () {
        // `Le **commerce*` — l'état du flux quand le TROISIÈME astérisque vient
        // d'arriver et que le quatrième n'est pas encore là. Un `*` reste
        // orphelin, la paire restante ouvre et ferme l'emphase : l'utilisateur
        // voit « Le *commerce » EN ITALIQUE, astérisque parasite compris — puis,
        // UN caractère plus loin, « Le commerce » EN GRAS et l'astérisque
        // disparaît. C'est la raison pour laquelle le défaut est le rendu
        // NEUTRE pendant le flux.
        const String partial = 'Le **commerce*';
        final List<Map<String, dynamic>> mid = codec.decode(partial);
        expect(
          _attrs(mid),
          equals('italic'),
          reason: 'Si cette assertion tombe, le parseur a changé de '
              'comportement et l\'arbitrage « neutre pendant le flux » doit '
              'être re-mesuré, pas re-supposé. Rendu: ${_plain(mid)}',
        );
        expect(
          _plain(mid),
          contains('*commerce'),
          reason: 'l\'astérisque orphelin est PEINT à l\'écran',
        );

        // Un seul caractère plus loin, la forme bascule.
        final List<Map<String, dynamic>> full = codec.decode('$partial*');
        expect(_attrs(full), equals('bold'));
        expect(_plain(full), isNot(contains('*')));
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // MESURE 3 — le COÛT d'un re-parse par fragment.
  // ══════════════════════════════════════════════════════════════════════════
  group('MESURE 3 — le coût, chiffré', () {
    test('BANC (trace) : parse seul, et sa croissance avec la longueur', () {
      for (final int repeat in <int>[1, 2, 4, 8]) {
        final String src = List<String>.filled(
          repeat,
          kRealisticMessage,
        ).join();
        final Stopwatch sw = Stopwatch()..start();
        const int n = 50;
        for (int i = 0; i < n; i++) {
          codec.decode(src);
        }
        sw.stop();
        // ignore: avoid_print
        print('len=${src.length.toString().padLeft(5)} '
            '=> ${(sw.elapsedMicroseconds / n).toStringAsFixed(0)} us/parse');
      }
    });

    testWidgets(
      'BANC (trace) : cycle WIDGET complet, par fragment de ~40 caractères',
      (WidgetTester tester) async {
        String current = '';
        late StateSetter setter;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (BuildContext c, StateSetter s) {
                  setter = s;
                  return SingleChildScrollView(
                    child: ZMarkdownReader(
                      value: current,
                      codec: codec,
                      chrome: ZMarkdownReaderChrome.none,
                      semanticsEnabled: false,
                      placeholder: '',
                    ),
                  );
                },
              ),
            ),
          ),
        );
        const int step = 40;
        final Stopwatch sw = Stopwatch()..start();
        int frames = 0;
        for (int i = step; i <= kRealisticMessage.length; i += step) {
          current = kRealisticMessage.substring(0, i);
          setter(() {});
          await tester.pump();
          frames++;
        }
        sw.stop();
        // ignore: avoid_print
        print('$frames ré-hydratations = ${sw.elapsedMilliseconds} ms '
            '=> ${(sw.elapsedMicroseconds / frames).toStringAsFixed(0)} '
            'us/fragment (parse + Document + dédup + layout Quill)');
        expect(frames, greaterThan(0));
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // LA DÉCISION QUI EN DÉCOULE, et sa garde de comportement.
  // ══════════════════════════════════════════════════════════════════════════
  group('🔴 DÉCISION — neutre pendant le flux, riche à la complétion', () {
    testWidgets(
      'MODE DÉFAUT : pendant le flux, le rendu est celui du SOCLE '
      '(indiscernable de l\'absence de satellite)',
      (WidgetTester tester) async {
        final ValueNotifier<String> live = ValueNotifier<String>(
          'Le **commerce',
        );
        addTearDown(live.dispose);

        await _mount(tester, _streamingReq(live));
        final String neutral = paintedText(tester);

        await _mount(
          tester,
          _streamingReq(live),
          renderer: const ZChatMarkdownRenderer(),
        );
        final String withSatellite = paintedText(tester);

        expect(
          withSatellite,
          equals(neutral),
          reason: '🔴 En mode défaut le satellite doit DÉCLINER pendant le '
              'flux : le socle porte déjà l\'abonnement granulaire (SM-1), la '
              'contrainte de 48 dp et le `Semantics`. Écrire une tuile de '
              'streaming parallèle est le motif CR-LEX-78.',
        );
        // Et le texte source EST peint tel quel — pas d'artefact d'italique.
        expect(withSatellite, contains('**commerce'));
      },
    );

    testWidgets(
      'MODE DÉFAUT : un JETON de plus ne fait pas basculer en riche',
      (WidgetTester tester) async {
        final ValueNotifier<String> live = ValueNotifier<String>('Le **comm');
        addTearDown(live.dispose);
        await _mount(
          tester,
          _streamingReq(live),
          renderer: const ZChatMarkdownRenderer(),
        );
        live.value = 'Le **commerce** est';
        await tester.pumpAndSettle();
        expect(
          paintedText(tester),
          contains('**commerce**'),
          reason: 'pendant le flux, le texte reste SOURCE — c\'est ce qui '
              'supprime le clignotement mesuré en MESURE 2.',
        );
        expect(hasBold(tester, 'commerce'), isFalse);
      },
    );

    testWidgets(
      '🔴 À LA COMPLÉTION, le riche prend le relais sur le MÊME contenu',
      (WidgetTester tester) async {
        // C'est le vrai basculement : le socle remplace la tuile synthétique de
        // streaming par les `contentBlocks` réels (isStreaming: false,
        // streamingText: null). Ici on rejoue exactement cette transition.
        final ValueNotifier<String> live = ValueNotifier<String>(
          'Le **commerce** est libre',
        );
        addTearDown(live.dispose);
        await _mount(
          tester,
          _streamingReq(live),
          renderer: const ZChatMarkdownRenderer(),
        );
        expect(paintedText(tester), contains('**'));
        expect(hasBold(tester, 'commerce'), isFalse);

        await _mount(
          tester,
          const ZChatBlockRenderRequest(
            block: ZTextBlock(text: 'Le **commerce** est libre'),
            message: ZChatMessage(
              id: 'r1',
              conversationId: 'c1',
              role: ZChatRole.assistant,
            ),
          ),
          renderer: const ZChatMarkdownRenderer(),
        );
        expect(
          paintedText(tester),
          isNot(contains('**')),
          reason: '🔴 le relais n\'a pas eu lieu : peint = '
              '"${paintedText(tester)}"',
        );
        expect(hasBold(tester, 'commerce'), isTrue);
      },
    );

    testWidgets(
      'MODE RICHE-PENDANT-LE-FLUX : le drapeau a un effet OBSERVABLE',
      (WidgetTester tester) async {
        // Sans cette garde, `richWhileStreaming` pourrait être un drapeau mort.
        final ValueNotifier<String> live = ValueNotifier<String>(
          'Le **commerce** est libre',
        );
        addTearDown(live.dispose);
        await _mount(
          tester,
          _streamingReq(live),
          renderer: const ZChatMarkdownRenderer(
            streamingMode: ZChatMarkdownStreamingMode.richWhileStreaming,
          ),
        );
        expect(paintedText(tester), isNot(contains('**')));
        expect(hasBold(tester, 'commerce'), isTrue);
      },
    );

    testWidgets(
      'MODE RICHE-PENDANT-LE-FLUX : un jeton met à jour le rendu, sans lever',
      (WidgetTester tester) async {
        final ValueNotifier<String> live = ValueNotifier<String>('Le **comm');
        addTearDown(live.dispose);
        await _mount(
          tester,
          _streamingReq(live),
          renderer: const ZChatMarkdownRenderer(
            streamingMode: ZChatMarkdownStreamingMode.richWhileStreaming,
          ),
        );
        for (final String v in <String>[
          'Le **commerce',
          'Le **commerce*',
          'Le **commerce** est',
          'Le **commerce** est *libre',
          'Le **commerce** est *libre*\n\n---\n\n| a |',
        ]) {
          live.value = v;
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '🔴 AD-10 : le fragment «$v» a fait lever le rendu riche.',
          );
        }
        expect(hasBold(tester, 'commerce'), isTrue);
      },
    );
  });
}
