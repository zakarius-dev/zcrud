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

    // Ajoutées en v0.7.0 : le docstring affirme que CHAQUE ligne de la table
    // est assertée par exécution. C'était faux — 4 lignes sur 8 (police,
    // taille, fond, alignement) n'avaient aucune assertion, alors même que le
    // titre de ce groupe annonce « assertion EXPLICITE de chaque perte ».
    // Reprocher à la v0.6.0 une couverture de 2/8 en en livrant 4/8 aurait
    // reconduit le défaut sanctionné par CR-IFFD-24.
    //
    // NATURE DE CES TESTS, dite franchement : une assertion de PERTE ne rougit
    // que si la perte cesse. Ils documentent donc par exécution plutôt qu'ils
    // ne gardent contre une régression — leur seule morsure réelle serait
    // qu'on dote ces attributs d'un marqueur de survie (comme `<u>` pour le
    // souligné) sans mettre la table des pertes à jour. C'est précisément le
    // scénario qui a produit la ligne fausse sur le barré.
    for (final MapEntry<String, Object> perte in <String, Object>{
      'font': 'Roboto',
      'size': '24',
      'background': '#00ff00',
    }.entries) {
      test('${perte.key} PERDU au round-trip Markdown', () {
        final ops = <Map<String, dynamic>>[
          <String, dynamic>{
            'insert': 'valeur',
            'attributes': <String, dynamic>{perte.key: perte.value},
          },
          <String, dynamic>{'insert': '\n'},
        ];
        final rt = codec.decode(codec.encode(ops));
        expect(_hasAttr(rt, perte.key), isFalse,
            reason: '${perte.key} ne doit PAS survivre au Markdown');
        expect(_plainText(rt), contains('valeur'),
            reason: 'le TEXTE, lui, doit survivre (perte bornée)');
      });
    }

    test('ALIGNEMENT (align) PERDU au round-trip Markdown', () {
      // L'alignement est un attribut de LIGNE (porté par le saut de ligne).
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'centré'},
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'align': 'center'},
        },
      ];
      final rt = codec.decode(codec.encode(ops));
      expect(_hasAttr(rt, 'align'), isFalse);
      expect(_plainText(rt), contains('centré'));
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
