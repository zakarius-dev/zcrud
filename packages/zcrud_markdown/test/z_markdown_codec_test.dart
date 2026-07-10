// AC3 / AC5 / AC9 — `ZMarkdownCodec` : round-trip Markdown sur corpus réel
// (préservation sémantique du sous-ensemble MD), TABLE DES PERTES assertée,
// décodage DÉFENSIF (AD-10), et frontière embeds (perte bornée + documentée).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'fixtures/rich_corpus.dart';

/// Concatène le texte inséré (parties `String`) des ops — proxy sémantique
/// robuste (indépendant des micro-variations de structure du convertisseur).
String _plainText(List<Map<String, dynamic>> ops) => ops
    .map((op) => op['insert'])
    .whereType<String>()
    .join();

/// `true` si une op porte l'attribut [attr] (valeur == [value] si fournie).
bool _hasAttr(List<Map<String, dynamic>> ops, String attr, [Object? value]) =>
    ops.any((op) {
      final a = op['attributes'];
      if (a is! Map || !a.containsKey(attr)) return false;
      return value == null || a[attr] == value;
    });

void main() {
  const codec = ZMarkdownCodec();

  group('AC3 — encode produit le Markdown attendu', () {
    test('gras + italique → **/_', () {
      final md = codec.encode(boldItalicOps)! as String;
      expect(md, contains('**gras**'));
      expect(md, contains('italique'));
      expect(md, anyOf(contains('_italique_'), contains('*italique*')));
    });
    test('titres → #, ##, ###', () {
      final md = codec.encode(headingsOps)! as String;
      expect(md, contains('# Titre 1'));
      expect(md, contains('## Titre 2'));
      expect(md, contains('### Titre 3'));
    });
    test('liste imbriquée → indentation à 2 niveaux', () {
      final md = codec.encode(nestedListOps)! as String;
      expect(md, contains('- niveau 1'));
      expect(md, contains('niveau 2'));
      // Le niveau 2 est indenté (préfixe d'espaces avant le marqueur).
      expect(md, matches(RegExp(r'\n\s+-? *niveau 2')));
    });
    test('lien → [texte](url)', () {
      expect(codec.encode(linkOps), contains('[zcrud](https://example.com)'));
    });
    test('code inline → backticks', () {
      expect(codec.encode(inlineCodeOps), contains('`ident`'));
    });
    test('bloc de code → clôture ```', () {
      final md = codec.encode(codeBlockOps)! as String;
      expect(md, contains('```'));
      expect(md, contains('var x = 1;'));
    });
    test('blockquote → >', () {
      expect(codec.encode(blockquoteOps), contains('> citation'));
    });
  });

  group('AC3 — round-trip PRÉSERVE la sémantique du sous-ensemble MD', () {
    test('gras/italique conservés', () {
      final rt = codec.decode(codec.encode(boldItalicOps));
      expect(_hasAttr(rt, 'bold', true), isTrue);
      expect(_hasAttr(rt, 'italic', true), isTrue);
      expect(_plainText(rt), contains('gras'));
    });
    test('titre H1 conservé', () {
      final rt = codec.decode(codec.encode(headingsOps));
      expect(_hasAttr(rt, 'header', 1), isTrue);
    });
    test('liste imbriquée : 2 niveaux conservés (indent:1)', () {
      final rt = codec.decode(codec.encode(nestedListOps));
      expect(_hasAttr(rt, 'list', 'bullet'), isTrue);
      expect(_hasAttr(rt, 'indent', 1), isTrue,
          reason: 'niveau 2 (indent:1) perdu — imbrication non préservée');
    });
    test('lien conservé', () {
      final rt = codec.decode(codec.encode(linkOps));
      expect(_hasAttr(rt, 'link', 'https://example.com'), isTrue);
    });
    test('code inline conservé', () {
      final rt = codec.decode(codec.encode(inlineCodeOps));
      expect(_hasAttr(rt, 'code', true), isTrue);
    });
    test('blockquote conservé', () {
      final rt = codec.decode(codec.encode(blockquoteOps));
      expect(_hasAttr(rt, 'blockquote', true), isTrue);
    });
    test('entités HTML conservées en TEXTE (< et &)', () {
      final rt = codec.decode(codec.encode(htmlEntitiesOps));
      final text = _plainText(rt);
      expect(text, contains('<'));
      expect(text, contains('&'));
    });
  });

  group('AC3 / AC9 — TABLE DES PERTES (assertion EXPLICITE de chaque perte)', () {
    test('COULEUR perdue au round-trip Markdown', () {
      final md = codec.encode(colorOps)! as String;
      // Le texte survit, mais l'attribut couleur DISPARAÎT du Markdown…
      expect(md, contains('rouge'));
      final rt = codec.decode(md);
      // …et n'est pas restauré (perte assertée, pas un throw).
      expect(_hasAttr(rt, 'color'), isFalse,
          reason: 'la couleur ne doit PAS survivre au round-trip Markdown');
      expect(_plainText(rt), contains('rouge'));
    });

    test('EMBED LaTeX (E6-3) perdu via Markdown, sans throw (AC9)', () {
      // L'embed opaque n'est pas exprimable en MD : encode dégrade (défensif),
      // le round-trip NE restaure PAS la formule.
      late Object? md;
      expect(() => md = codec.encode(latexEmbedOps), returnsNormally);
      final rt = codec.decode(md);
      final containsFormula = rt.any((op) {
        final ins = op['insert'];
        return ins is Map && ins.containsKey('formula');
      });
      expect(containsFormula, isFalse,
          reason: 'la formule LaTeX ne doit PAS survivre au Markdown (perte AC9)');
    });

    test(
        'E6-3 — EMBED latex (type CANONIQUE `latex`) → placeholder [embed:latex] '
        'via Markdown, texte environnant préservé, jamais ressuscité (AC5)', () {
      // Corpus RÉEL E6-3 : texte + {insert:{latex:...}} + texte.
      final md = codec.encode(mixedTextAndLatexEmbedOps)! as String;
      expect(md, isNotEmpty);
      // Les DEUX segments de texte autour de l'embed survivent (perte bornée).
      expect(md, contains('avant'));
      expect(md, contains('apres'));
      // Le TYPE `latex` est capté génériquement par `_embedPlaceholder`
      // (1re clé de la Map insert) SANS modification du codec (AC5/AC10).
      expect(md, contains('embed:latex'));
      // Round-trip : le texte + le marqueur reviennent, mais AUCUN embed opaque
      // (Map insert) ne ressuscite.
      final rt = codec.decode(md);
      final text = _plainText(rt);
      expect(text, contains('avant'));
      expect(text, contains('apres'));
      expect(text, contains('[embed:latex]'));
      final resurrected = rt.any((op) {
        final ins = op['insert'];
        return ins is Map && ins.containsKey('latex');
      });
      expect(resurrected, isFalse,
          reason: 'la formule LaTeX ne doit PAS survivre au Markdown (AC5)');
    });

    test('EMBED tableau opaque (E6-4) perdu via Markdown, sans throw', () {
      late Object? md;
      expect(() => md = codec.encode(opaqueEmbedOps), returnsNormally);
      final rt = codec.decode(md);
      final containsTable = rt.any((op) {
        final ins = op['insert'];
        return ins is Map && ins.containsKey('z-table');
      });
      expect(containsTable, isFalse);
    });

    test(
        'E6-4 — EMBED table (type CANONIQUE `table`) → placeholder [embed:table] '
        'via Markdown, texte environnant préservé, jamais ressuscité (AC5)', () {
      // Corpus RÉEL E6-4 : texte + {insert:{table:...}} + texte.
      final md = codec.encode(mixedTextAndTableEmbedOps)! as String;
      expect(md, isNotEmpty);
      // Les DEUX segments de texte autour de l'embed survivent (perte bornée).
      expect(md, contains('avant'));
      expect(md, contains('apres'));
      // Le TYPE `table` est capté génériquement par `_embedPlaceholder`
      // (1re clé de la Map insert) SANS modification du codec (AC5/AC10).
      expect(md, contains('embed:table'));
      // Round-trip : le texte + le marqueur reviennent, mais AUCUN embed opaque
      // (Map insert) ne ressuscite.
      final rt = codec.decode(md);
      final text = _plainText(rt);
      expect(text, contains('avant'));
      expect(text, contains('apres'));
      expect(text, contains('[embed:table]'));
      final resurrected = rt.any((op) {
        final ins = op['insert'];
        return ins is Map && ins.containsKey('table');
      });
      expect(resurrected, isFalse,
          reason: 'le tableau ne doit PAS survivre au Markdown (AC5)');
    });

    test(
        'HIGH-1 — texte + embed LaTeX + texte + embed tableau : perte BORNÉE à '
        'l\'embed (texte préservé, un placeholder/embed, JAMAIS de doc vide)',
        () {
      final md = codec.encode(mixedTextAndEmbedsOps)! as String;
      // Le document N'EST PAS vidé par un embed au milieu du texte (HIGH-1).
      expect(md, isNotEmpty);
      // Les DEUX segments de texte autour des embeds SURVIVENT.
      expect(md, contains('avant'));
      expect(md, contains('milieu'));
      expect(md, contains('apres'));
      // Un marqueur par embed (perte cantonnée à l'embed, TYPE tracé). Les
      // crochets sont échappés par le sérialiseur Markdown (`\[embed:formula\]`,
      // rendu littéral), mais le marqueur de type reste présent en clair.
      expect(md, contains('embed:formula'));
      expect(md, contains('embed:z'));
      // Round-trip : le texte + les marqueurs (dés-échappés) reviennent, mais
      // AUCUN embed opaque (Map insert) ne ressuscite.
      final rt = codec.decode(md);
      final text = _plainText(rt);
      expect(text, contains('avant'));
      expect(text, contains('milieu'));
      expect(text, contains('apres'));
      expect(text, contains('[embed:formula]'));
      expect(text, contains('[embed:z-table]'));
      final hasEmbed = rt.any((op) => op['insert'] is Map);
      expect(hasEmbed, isFalse,
          reason: 'aucun embed opaque ne doit survivre au Markdown');
    });
  });

  group('AC5 — décodage DÉFENSIF : jamais de throw', () {
    final defensive = <String, Object?>{
      'null': null,
      'chaîne vide': '',
      'espaces': '   ',
      'type inattendu (int)': 42,
      'liste vide native': <Object?>[],
      'op non-Map': <Object?>['x'],
    };
    defensive.forEach((label, input) {
      test('decode($label) → [] sans throw', () {
        late List<Map<String, dynamic>> out;
        expect(() => out = codec.decode(input), returnsNormally);
        expect(out, isEmpty);
      });
    });

    test('Markdown mal formé → PAS de throw (dégrade en texte, AD-10)', () {
      expect(() => codec.decode('**non clos [lien('), returnsNormally);
    });

    test('encode(const []) → "" sans throw', () {
      expect(codec.encode(const <Map<String, dynamic>>[]), '');
    });
  });
}
