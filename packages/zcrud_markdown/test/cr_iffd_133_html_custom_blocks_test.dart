// CR-IFFD-133 — `ZHtmlCodec.customBlocks` : règles de conversion HTML → Delta
// fournies par l'appelant.
//
// Deux angles :
//   1. INERTIE — sans `customBlocks`, le décodage est IDENTIQUE (égalité
//      stricte des ops) à celui d'un codec construit avec une liste vide, et
//      un fragment porteur de LaTeX dégrade en TEXTE, comme avant.
//   2. EFFET — une règle fournie convertit son balisage en op CUSTOM native,
//      et le texte environnant survit.
//
// AD-12 : c'est de la CONVERSION, jamais du rendu — aucune WebView, aucun
// moteur HTML n'entre dans le paquet.
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Règle de test : `<span data-formula="…">` devient une op custom `latex`.
class _FormulaSpanPart implements CustomHtmlPart {
  @override
  bool matches(dom.Element element) =>
      element.localName == 'span' &&
      element.attributes.containsKey('data-formula');

  @override
  List<Operation> convert(
    dom.Element element, {
    Map<String, dynamic>? currentAttributes,
  }) =>
      <Operation>[
        Operation.insert(<String, dynamic>{
          'latex': element.attributes['data-formula'],
        }),
      ];
}

void main() {
  const String html =
      '<p>avant <span data-formula="\\frac{a}{b}">f</span> apres</p>';

  group('CR-IFFD-133 — inertie : sans règle, décodage inchangé', () {
    test('liste vide ≡ paramètre omis (égalité stricte des ops)', () {
      final sansParametre = const ZHtmlCodec().decode(html);
      final listeVide =
          const ZHtmlCodec(customBlocks: <CustomHtmlPart>[]).decode(html);
      expect(listeVide, equals(sansParametre));
    });

    test('un fragment porteur de LaTeX dégrade en TEXTE, comme avant', () {
      final ops = const ZHtmlCodec().decode(html);
      // Aucune op embed : tout est du texte.
      expect(
        ops.every((op) => op['insert'] is String),
        isTrue,
        reason: 'sans règle déclarée, aucun embed ne doit apparaître',
      );
      final String texte =
          ops.map((op) => op['insert']).whereType<String>().join();
      expect(texte, contains('avant '));
      expect(texte, contains(' apres'));
    });
  });

  group('CR-IFFD-133 — effet : une règle produit une op custom', () {
    test('le balisage reconnu devient une op `latex`, le texte survit', () {
      final ops = ZHtmlCodec(
        customBlocks: <CustomHtmlPart>[_FormulaSpanPart()],
      ).decode(html);

      final embeds = ops
          .map((op) => op['insert'])
          .whereType<Map<dynamic, dynamic>>()
          .toList();
      expect(embeds, hasLength(1),
          reason: 'la règle déclarée doit produire exactement une op embed');
      expect(embeds.single['latex'], r'\frac{a}{b}');

      final String texte =
          ops.map((op) => op['insert']).whereType<String>().join();
      expect(texte, contains('avant '));
      expect(texte, contains(' apres'),
          reason: 'le texte environnant ne doit pas être perdu');
    });

    test('la valeur reste NEUTRE (JSON-safe, aucun type de conversion)', () {
      final ops = ZHtmlCodec(
        customBlocks: <CustomHtmlPart>[_FormulaSpanPart()],
      ).decode(html);
      expect(ops, isA<List<Map<String, dynamic>>>());
      expect(ops, isNot(isA<Delta>()));
    });
  });
}
