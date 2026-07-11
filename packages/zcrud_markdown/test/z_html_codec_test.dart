// DP-4 / B5 (AC1) — `ZHtmlCodec` : round-trip Delta↔HTML sur corpus réel
// (préservation sémantique du sous-ensemble commun), TABLE DES PERTES assertée
// (inline `code`, embeds → placeholder), décodage DÉFENSIF (AD-10), perte
// BORNÉE à l'embed (jamais de document vidé, jamais de throw).
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

/// `true` si une op porte un `insert` EMBED opaque (Map).
bool _hasOpaqueEmbed(List<Map<String, dynamic>> ops) =>
    ops.any((op) => op['insert'] is Map);

void main() {
  const codec = ZHtmlCodec();

  group('AC1 — encode produit du HTML', () {
    test('gras + italique → <strong>/<em>', () {
      final html = codec.encode(boldItalicOps)! as String;
      expect(html, contains('<strong>gras</strong>'));
      expect(html, contains('<em>italique</em>'));
    });
    test('titres → <h1>/<h2>/<h3>', () {
      final html = codec.encode(headingsOps)! as String;
      expect(html, contains('<h1>Titre 1</h1>'));
      expect(html, contains('<h2>Titre 2</h2>'));
      expect(html, contains('<h3>Titre 3</h3>'));
    });
    test('liste imbriquée → <ul> imbriqué', () {
      final html = codec.encode(nestedListOps)! as String;
      expect(html, contains('<ul>'));
      expect(html, contains('niveau 1'));
      expect(html, contains('niveau 2'));
      // Le niveau 2 est un <ul> imbriqué DANS le <li> du niveau 1.
      expect(html, contains('<li>niveau 1<ul>'));
    });
    test('lien → <a href>', () {
      final html = codec.encode(linkOps)! as String;
      expect(html, contains('href="https://example.com"'));
      expect(html, contains('>zcrud</a>'));
    });
    test('bloc de code → <pre>', () {
      final html = codec.encode(codeBlockOps)! as String;
      expect(html, contains('<pre>'));
      expect(html, contains('var x = 1;'));
    });
    test('blockquote → <blockquote>', () {
      expect(codec.encode(blockquoteOps), contains('<blockquote>citation'));
    });
  });

  group('AC1 — round-trip PRÉSERVE la sémantique du sous-ensemble commun', () {
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
    test('bloc de code conservé', () {
      final rt = codec.decode(codec.encode(codeBlockOps));
      expect(_hasAttr(rt, 'code-block', true), isTrue);
      expect(_plainText(rt), contains('var x = 1;'));
    });
    test('blockquote conservé', () {
      final rt = codec.decode(codec.encode(blockquoteOps));
      expect(_hasAttr(rt, 'blockquote', true), isTrue);
    });
    test('COULEUR conservée (HTML exprime les styles inline — vs Markdown)', () {
      final rt = codec.decode(codec.encode(colorOps));
      expect(_hasAttr(rt, 'color', '#ff0000'), isTrue,
          reason: 'la couleur survit au round-trip HTML (style inline)');
      expect(_plainText(rt), contains('rouge'));
    });
    test('souligné conservé', () {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': 'sous',
          'attributes': <String, dynamic>{'underline': true},
        },
        <String, dynamic>{'insert': '\n'},
      ];
      expect(_hasAttr(codec.decode(codec.encode(ops)), 'underline', true),
          isTrue);
    });
    test('barré conservé', () {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': 'barre',
          'attributes': <String, dynamic>{'strike': true},
        },
        <String, dynamic>{'insert': '\n'},
      ];
      expect(
          _hasAttr(codec.decode(codec.encode(ops)), 'strike', true), isTrue);
    });
    test('entités HTML (< et &) survivent en TEXTE, sans throw', () {
      late Object? html;
      expect(() => html = codec.encode(htmlEntitiesOps), returnsNormally);
      final rt = codec.decode(html);
      final text = _plainText(rt);
      expect(text, contains('<'));
      expect(text, contains('&'));
    });
  });

  group('AC1 — TABLE DES PERTES (assertion EXPLICITE de chaque perte)', () {
    test('code INLINE perdu au round-trip HTML (texte préservé)', () {
      final html = codec.encode(inlineCodeOps)! as String;
      // La balise <code> EST émise à l'encode…
      expect(html, contains('<code>ident</code>'));
      // …mais l'attribut n'est PAS re-parsé au décode (perte assertée, pas throw).
      final rt = codec.decode(html);
      expect(_hasAttr(rt, 'code'), isFalse,
          reason: 'le `code` inline ne survit PAS au round-trip HTML');
      expect(_plainText(rt), contains('ident'),
          reason: 'le TEXTE du code inline survit (perte bornée à l\'attribut)');
    });

    test('EMBED LaTeX (E6-3) → placeholder [embed:latex], jamais ressuscité', () {
      late Object? html;
      expect(() => html = codec.encode(latexEmbedOps), returnsNormally);
      final rt = codec.decode(html);
      final resurrected = rt.any((op) {
        final ins = op['insert'];
        return ins is Map && ins.containsKey('formula');
      });
      expect(resurrected, isFalse,
          reason: 'la formule LaTeX ne doit PAS survivre au HTML (perte AC1)');
    });

    test('EMBED tableau opaque (E6-4) → placeholder, jamais ressuscité', () {
      late Object? html;
      expect(() => html = codec.encode(opaqueEmbedOps), returnsNormally);
      final rt = codec.decode(html);
      final resurrected = rt.any((op) {
        final ins = op['insert'];
        return ins is Map && ins.containsKey('z-table');
      });
      expect(resurrected, isFalse);
    });

    test(
        'E6-3 — embed `latex` → placeholder [embed:latex] via HTML, texte '
        'environnant préservé, jamais ressuscité', () {
      final html = codec.encode(mixedTextAndLatexEmbedOps)! as String;
      expect(html, isNotEmpty);
      expect(html, contains('avant'));
      expect(html, contains('apres'));
      // Le TYPE `latex` est capté génériquement (1re clé de la Map insert).
      expect(html, contains('embed:latex'));
      final rt = codec.decode(html);
      final text = _plainText(rt);
      expect(text, contains('avant'));
      expect(text, contains('apres'));
      expect(text, contains('[embed:latex]'));
      expect(_hasOpaqueEmbed(rt), isFalse);
    });

    test(
        'E6-4 — embed `table` → placeholder [embed:table] via HTML, texte '
        'environnant préservé, jamais ressuscité', () {
      final html = codec.encode(mixedTextAndTableEmbedOps)! as String;
      expect(html, contains('avant'));
      expect(html, contains('apres'));
      expect(html, contains('embed:table'));
      final rt = codec.decode(html);
      final text = _plainText(rt);
      expect(text, contains('avant'));
      expect(text, contains('apres'));
      expect(text, contains('[embed:table]'));
      expect(_hasOpaqueEmbed(rt), isFalse);
    });

    test(
        'HIGH-1 — texte + embed LaTeX + texte + embed tableau : perte BORNÉE à '
        'l\'embed (texte préservé, JAMAIS de doc vide, JAMAIS de throw)', () {
      late Object? htmlValue;
      expect(() => htmlValue = codec.encode(mixedTextAndEmbedsOps),
          returnsNormally);
      final html = htmlValue! as String;
      // Le document N'EST PAS vidé par un embed au milieu du texte (HIGH-1).
      expect(html, isNotEmpty);
      expect(html, contains('avant'));
      expect(html, contains('milieu'));
      expect(html, contains('apres'));
      expect(html, contains('embed:formula'));
      expect(html, contains('embed:z-table'));
      final rt = codec.decode(html);
      final text = _plainText(rt);
      expect(text, contains('avant'));
      expect(text, contains('milieu'));
      expect(text, contains('apres'));
      expect(text, contains('[embed:formula]'));
      expect(text, contains('[embed:z-table]'));
      expect(_hasOpaqueEmbed(rt), isFalse,
          reason: 'aucun embed opaque ne doit survivre au HTML');
    });
  });

  group('AC1 — décodage DÉFENSIF (AD-10) : jamais de throw', () {
    final defensive = <String, Object?>{
      'null': null,
      'chaîne vide': '',
      'espaces': '   ',
      'type inattendu (int)': 42,
      'HTML malformé (balise non close)': '<not/valid',
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

    test('HTML tronqué (`<p>texte`) : récupéré en TEXTE, JAMAIS de throw', () {
      // Le parseur HTML5 est LENIENT : il auto-ferme la balise et récupère le
      // texte (dégradation propre, AD-10) plutôt que de throw ou vider.
      late List<Map<String, dynamic>> out;
      expect(() => out = codec.decode('<p>texte'), returnsNormally);
      expect(_plainText(out), contains('texte'));
    });

    test('valeur `List` legacy (Delta déjà neutre) tolérée', () {
      // Une valeur `List` d'ops Delta est normalisée en ops neutres (comme
      // ZMarkdownCodec) — rétro-compat legacy.
      final out = codec.decode(boldItalicOps);
      expect(out, isNotEmpty);
      expect(_hasAttr(out, 'bold', true), isTrue);
    });

    test('encode(const []) → "" sans throw', () {
      expect(codec.encode(const <Map<String, dynamic>>[]), '');
    });
  });
}
