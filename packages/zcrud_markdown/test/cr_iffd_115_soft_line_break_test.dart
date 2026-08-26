// CR-IFFD-115 — le retour à la ligne SOUPLE : `ZMarkdownCodec.softBreak`.
//
// Le canal est un réglage de DÉCODAGE. Deux lentilles, parce que la promesse
// porte sur les deux :
//   - les OPS produites (c'est la sortie observable du codec) ;
//   - le RENDU réel — combien de lignes le lecteur peint, et sur quelle
//     hauteur. Un test qui se contenterait de compter les ops resterait vert si
//     le lecteur, lui, recollait tout : c'est exactement le piège dans lequel
//     sept gardes de ce paquet sont déjà tombées.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

const String _kTroisLignes = 'ligne un\nligne deux\nligne trois';

/// Le texte réellement PEINT — Quill peint par `RichText`, pas par `Text`.
String _painted(WidgetTester tester) {
  final StringBuffer b = StringBuffer();
  for (final RichText r in tester.widgetList<RichText>(find.byType(RichText))) {
    b.write(r.text.toPlainText());
  }
  return b.toString();
}

/// Textes réellement peints, ligne par ligne, du haut vers le bas.
List<String> _paintedLines(WidgetTester tester) {
  final List<(double, String)> lignes = <(double, String)>[
    for (final Element e in find.byType(RichText).evaluate())
      (
        tester
            .getRect(find.byElementPredicate((Element x) => identical(x, e)))
            .top,
        (e.widget as RichText).text.toPlainText(),
      ),
  ];
  lignes.sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  return <String>[for (final (double, String) l in lignes) l.$2];
}

/// Rectangles des lignes de texte réellement peintes, du haut vers le bas.
List<Rect> _lineRects(WidgetTester tester) {
  final List<Rect> rects = <Rect>[
    for (final Element e in find.byType(RichText).evaluate())
      tester.getRect(find.byElementPredicate((Element x) => identical(x, e))),
  ];
  rects.sort((Rect a, Rect b) => a.top.compareTo(b.top));
  return rects;
}

Future<void> _pump(WidgetTester tester, ZCodec codec, String source) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          // Assez large pour que le pavé recollé tienne sur UNE ligne visuelle :
          // la comparaison de hauteur porte alors sur le seul effet du canal,
          // et non sur un repli de texte.
          width: 700,
          // Clé DISTINCTE par codec : le lecteur ne re-décode pas sur un simple
          // changement de codec à valeur égale, et un montage réutilisé
          // rendrait la garde MUETTE (elle mesurerait deux fois le même arbre).
          child: ZMarkdownReader(
            key: ValueKey<Object>(codec),
            value: source,
            codec: codec,
            chrome: ZMarkdownReaderChrome.none,
            placeholder: '',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Nombre de lignes Delta d'un jeu d'ops (une ligne = un `\n` inséré).
int _deltaLines(List<Map<String, dynamic>> ops) {
  int n = 0;
  for (final Map<String, dynamic> op in ops) {
    final Object? ins = op['insert'];
    if (ins is String) n += '\n'.allMatches(ins).length;
  }
  return n;
}

void main() {
  group('INERTIE — canal absent ⇒ décodage identique à l\'avant-lot', () {
    test('le défaut du constructeur est bien `space`', () {
      expect(const ZMarkdownCodec().softBreak, ZSoftBreak.space);
    });

    test('trois lignes saisies restent UN paragraphe (recollé par espaces)', () {
      final List<Map<String, dynamic>> ops =
          const ZMarkdownCodec().decode(_kTroisLignes);
      expect(
        jsonEncode(ops),
        '[{"insert":"ligne un ligne deux ligne trois\\n"}]',
        reason: 'octet pour octet le décodage d\'avant l\'ouverture du réglage',
      );
      expect(_deltaLines(ops), 1);
    });

    test('le blockquote garde son recollage par ESPACE et son italique', () {
      expect(
        jsonEncode(const ZMarkdownCodec().decode('> elle est\n> *acquise*')),
        '[{"insert":"elle est "},'
        '{"insert":"acquise","attributes":{"italic":true}},'
        '{"insert":"\\n","attributes":{"blockquote":true}}]',
      );
    });

    testWidgets('le lecteur peint UNE seule ligne, canal absent', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const ZMarkdownCodec(), _kTroisLignes);
      expect(_painted(tester), 'ligne un ligne deux ligne trois');
      expect(_lineRects(tester).length, 1);
    });
  });

  group('EFFET — `lineBreak` ⇒ la quantité promise, et elle seule', () {
    test('trois lignes saisies donnent TROIS lignes Delta (1 → 3)', () {
      const ZMarkdownCodec lb = ZMarkdownCodec(softBreak: ZSoftBreak.lineBreak);
      final List<Map<String, dynamic>> ops = lb.decode(_kTroisLignes);
      expect(
        jsonEncode(ops),
        '[{"insert":"ligne un\\nligne deux\\nligne trois\\n"}]',
      );
      expect(_deltaLines(ops), 3);
      expect(_deltaLines(const ZMarkdownCodec().decode(_kTroisLignes)), 1);
    });

    test('le blockquote aussi — et l\'italique SURVIT', () {
      expect(
        jsonEncode(
          const ZMarkdownCodec(softBreak: ZSoftBreak.lineBreak)
              .decode('> elle est\n> *acquise*'),
        ),
        '[{"insert":"elle est\\n"},'
        '{"insert":"acquise","attributes":{"italic":true}},'
        '{"insert":"\\n","attributes":{"blockquote":true}}]',
      );
    });

    test('l\'angle mort d\'UNE espace (` \\n`) est couvert lui aussi', () {
      expect(jsonEncode(const ZMarkdownCodec().decode('a \nb')),
          '[{"insert":"a b\\n"}]');
      expect(
        jsonEncode(const ZMarkdownCodec(softBreak: ZSoftBreak.lineBreak)
            .decode('a \nb')),
        '[{"insert":"a\\nb\\n"}]',
      );
    });

    testWidgets('le lecteur peint TROIS lignes empilées, et ~3× plus haut', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const ZMarkdownCodec(), _kTroisLignes);
      final List<Rect> une = _lineRects(tester);
      expect(une.length, 1);
      final double hauteurUneLigne = une.single.height;

      await _pump(
        tester,
        const ZMarkdownCodec(softBreak: ZSoftBreak.lineBreak),
        _kTroisLignes,
      );
      final List<Rect> trois = _lineRects(tester);
      expect(trois.length, 3, reason: 'trois lignes peintes, pas un pavé');
      expect(_paintedLines(tester),
          <String>['ligne un', 'ligne deux', 'ligne trois']);
      // EMPILÉES : chaque ligne commence sous la précédente.
      expect(trois[1].top, greaterThanOrEqualTo(trois[0].bottom - 0.5));
      expect(trois[2].top, greaterThanOrEqualTo(trois[1].bottom - 0.5));
      // QUANTITÉ : la hauteur totale peinte vaut ~3 lignes, pas 1.
      final double total = trois.last.bottom - trois.first.top;
      expect(total, greaterThan(hauteurUneLigne * 2.5));
      expect(total, lessThan(hauteurUneLigne * 3.5));
    });
  });

  group('NON-CONTAMINATION — ce que le réglage ne doit PAS toucher', () {
    for (final MapEntry<String, String> cas in <String, String>{
      'retour DUR (deux espaces)': 'a  \nb',
      'bloc de code fencé': '```\nx\ny\n```',
      'liste à puces': '- a\n- b',
      'tableau': '| a | b |\n| --- | --- |\n| 1 | 2 |',
    }.entries) {
      test('${cas.key} : décodage IDENTIQUE dans les deux modes', () {
        expect(
          jsonEncode(const ZMarkdownCodec(softBreak: ZSoftBreak.lineBreak)
              .decode(cas.value)),
          jsonEncode(const ZMarkdownCodec().decode(cas.value)),
        );
      });
    }

    test('l\'ENCODAGE ne dépend pas du réglage (valeur persistée intacte)', () {
      final List<Map<String, dynamic>> ops =
          const ZMarkdownCodec().decode('un **gras** et *italique*');
      expect(
        const ZMarkdownCodec(softBreak: ZSoftBreak.lineBreak).encode(ops),
        const ZMarkdownCodec().encode(ops),
      );
    });
  });
}
