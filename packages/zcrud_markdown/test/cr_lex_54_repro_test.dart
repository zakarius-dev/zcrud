// CR-54 — les espaces de bordure ne sont pas un test sémantique de LaTeX.
//
// L'oracle inspecte les charges d'embed : un round-trip de chaîne seul ne voit
// ni la formule perdue, ni le montant indûment transformé en formule.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

final ZMarkdownCodec _avecLatex =
    ZMarkdownCodec(bridges: ZMarkdownBridges.latex);

Match _payloadMatch(String payload) =>
    RegExp(r'\$([^$]+)\$').firstMatch(r'$' + payload + r'$')!;

List<Object?> _latexCharges(List<Map<String, dynamic>> ops) => <Object?>[
      for (final Map<String, dynamic> op in ops)
        if (op['insert'] case final Map<dynamic, dynamic> insert)
          if (insert.containsKey('latex')) insert['latex'],
    ];

void main() {
  group('CR-54 — table mesurée de la garde LaTeX', () {
    for (final ({String payload, bool expected}) sample
        in <({String payload, bool expected})>[
      (payload: 'x^2', expected: true),
      (payload: ' x^2 ', expected: true),
      (payload: 'à9', expected: true),
      (payload: ' à 9 ', expected: false),
      (payload: ' CAD à 250 ', expected: false),
    ]) {
      test('`${sample.payload}` → ${sample.expected}', () {
        expect(zLatexPayloadLooksLikeFormula(_payloadMatch(sample.payload)),
            sample.expected);
      });
    }
  });

  group('CR-54 — régressions observables dans le Delta', () {
    test(r"§A : `$ V = P + F $` produit sa charge d'embed malgré les bords", () {
      const source =
          r'La formule retenue est $ V = P + F $ pour la valeur en douane.';

      expect(_latexCharges(_avecLatex.decode(source)), <Object?>[' V = P + F ']);
    });

    test(r'§B : `5$à9$` ne produit jamais la charge monétaire `à9`', () {
      const source = r'La redevance varie de 5$à9$ selon le tonnage.';

      expect(_latexCharges(_avecLatex.decode(source)), isEmpty);
    });
  });
}
