// CR-IFFD-130 — normalisation de sources LaTeX héritées.
//
// Quatre angles :
//   1. INERTIE — un corpus de formules DÉJÀ valides traverse les trois
//      réparations OCTET POUR OCTET (`identical` sur la valeur retournée quand
//      rien n'est réparé, sinon égalité stricte).
//   2. EFFET — les trois réparations sur des vecteurs réels du corpus hérité.
//   3. ANCRAGE — la normalisation est ACTIVE sur le chemin de LECTURE hérité
//      (clés `formula`/`formula_inline`) et INACTIVE sur nos propres clés.
//      Prouvé en capturant la source EFFECTIVEMENT soumise au moteur, via le
//      `sourceNormalizer` de la spec (qui s'applique après la normalisation
//      héritée).
//   4. NIVEAUX — l'auto-délimitation est une réparation de TEXTE, pas de source
//      de formule : elle n'est jamais appliquée à une source nue.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Formules déjà correctes : aucune des réparations ne doit les toucher.
const List<String> _corpusValide = <String>[
  'E = mc^2',
  r'\frac{a}{b}',
  r'\sqrt{x^2 + y^2}',
  r'\sum_{i=1}^{n} i',
  r'\int_0^1 x\,dx',
  r'\begin{cases} x = 1 \\ y = 2 \end{cases}',
  r'\alpha + \beta \le \gamma',
  r'\text{vitesse} = \frac{d}{t}',
  '  espaces en bord  ',
];

List<Map<String, dynamic>> _seed(String type, String source) =>
    <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': <String, dynamic>{type: source},
      },
      <String, dynamic>{'insert': '\n'},
    ];

/// Monte un lecteur sur [seed] et retourne la source soumise au moteur.
Future<String?> _sourceSoumise(
  WidgetTester tester,
  List<Map<String, dynamic>> seed,
) async {
  String? capturee;
  await tester.pumpWidget(_host(
    ZMarkdownReader(
      value: seed,
      formulaSpec: ZRichTextFormulaSpec(
        sourceNormalizer: (String s) {
          capturee = s;
          return s;
        },
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 50));
  return capturee;
}

void main() {
  group('CR-IFFD-130 — inertie : une formule valide traverse à l\'identique',
      () {
    for (final String formule in _corpusValide) {
      test('inchangée : ${formule.trim()}', () {
        expect(zFixLatexLineBreaks(formule), formule);
        expect(zUnescapeLatexCommands(formule), formule);
        expect(zNormalizeLegacyLatexSource(formule), formule);
      });
    }

    test('un texte dont les formules sont déjà délimitées est inchangé', () {
      const List<String> textes = <String>[
        r'Le rapport $\frac{a}{b}$ vaut un demi.',
        r'Bloc : $$\sum_{i=1}^{n} i$$ fin.',
        r'Crochets : \[\int_0^1 x\,dx\] fin.',
        'Aucune formule ici, juste du texte.',
        r'| colonne | \frac{a}{b} | autre |',
      ];
      for (final String texte in textes) {
        expect(zAutoDelimitLatex(texte), texte, reason: texte);
      }
    });
  });

  group('CR-IFFD-130 — effet : les trois réparations', () {
    test('1. `\\` isolé en fin de ligne ⇒ `\\\\`, puis enveloppe `cases`', () {
      const String source = 'a = 1\\\nb = 2';
      final String repare = zFixLatexLineBreaks(source);
      expect(repare, startsWith(r'\begin{cases}'));
      expect(repare, endsWith(r'\end{cases}'));
      expect(repare, contains('a = 1\\\\\n'),
          reason: 'le `\\` isolé doit être doublé');
    });

    test('1bis. une formule DÉJÀ dans un environnement n\'est pas enveloppée',
        () {
      const String source = r'\begin{aligned} x &= 1 \\ y &= 2 \end{aligned}';
      expect(zFixLatexLineBreaks(source), source);
    });

    test('2. `\\\\frac` ⇒ `\\frac` (dictionnaire de commandes)', () {
      expect(zUnescapeLatexCommands(r'\\frac{a}{b}'), r'\frac{a}{b}');
      expect(zUnescapeLatexCommands(r'\\sum_{i=1}^{n} \\alpha_i'),
          r'\sum_{i=1}^{n} \alpha_i');
      // Une commande HORS dictionnaire n'est pas touchée : la liste borne ce
      // que la réparation ose faire.
      expect(zUnescapeLatexCommands(r'\\notacommand'), r'\\notacommand');
    });

    test('2bis. le dictionnaire couvre les familles annoncées', () {
      for (final String commande in const <String>[
        'frac', 'sqrt', 'int', 'sum', 'lim', 'alpha', 'omega', 'infty',
        'le', 'times', 'rightarrow', 'text', 'begin', 'left', 'vec', 'ce',
      ]) {
        expect(kZLatexCommands, contains(commande));
      }
    });

    test('3. LaTeX nu ⇒ délimité, régions délimitées EXCLUES', () {
      final String out = zAutoDelimitLatex(r'La valeur \frac{1}{2} ici.');
      expect(out, contains(r'$\frac{1}{2}$'));
      expect(out, startsWith('La valeur '));
      expect(out, endsWith(' ici.'));

      // Jamais de doublement sur une région déjà délimitée.
      const String deja = r'Deja : $\frac{1}{2}$ et nu \sqrt{x} ensuite.';
      final String out2 = zAutoDelimitLatex(deja);
      expect(out2, contains(r'$\frac{1}{2}$'));
      expect(out2.contains(r'$$\frac{1}{2}$$'), isFalse,
          reason: 'les délimiteurs ne doivent JAMAIS être doublés');
      expect(out2, contains(r'$\sqrt{x}$'));
    });

    test('pipeline de TEXTE : les trois réparations composent', () {
      const String texte = r'Voir \\frac{a}{b} dans le texte.';
      final String out = zNormalizeLatexInText(texte);
      expect(out, contains(r'$\frac{a}{b}$'));
    });
  });

  group('CR-IFFD-130 — ancrage : ACTIF sur le chemin hérité, INACTIF ailleurs',
      () {
    testWidgets('clé héritée `formula` : la source est réparée avant rendu',
        (tester) async {
      final String? soumise =
          await _sourceSoumise(tester, _seed('formula', r'\\frac{a}{b}'));
      expect(soumise, r'\frac{a}{b}',
          reason: 'le chemin hérité normalise la source avant de la rendre');
    });

    testWidgets('clé héritée `formula_inline` : réparée elle aussi',
        (tester) async {
      final String? soumise = await _sourceSoumise(
          tester, _seed('formula_inline', 'a = 1\\\nb = 2'));
      expect(soumise, startsWith(r'\begin{cases}'));
    });

    testWidgets('NOS clés (`latex`) : la source traverse NUE', (tester) async {
      final String? soumise =
          await _sourceSoumise(tester, _seed('latex', r'\\frac{a}{b}'));
      expect(soumise, r'\\frac{a}{b}',
          reason: 'ce que nous écrivons, nous n\'avons pas à le réparer');
    });

    testWidgets('`latexBlock` : la source traverse NUE aussi', (tester) async {
      final String? soumise =
          await _sourceSoumise(tester, _seed('latexBlock', r'\\sum_{i}'));
      expect(soumise, r'\\sum_{i}');
    });
  });

  group('CR-IFFD-130 — niveaux : la délimitation ne touche PAS une source nue',
      () {
    test('la normalisation de source n\'ajoute jamais de `\$`', () {
      for (final String formule in <String>[
        r'\frac{a}{b}',
        r'\sqrt{x}',
        r'\\frac{a}{b}',
      ]) {
        expect(zNormalizeLegacyLatexSource(formule).contains(r'$'), isFalse,
            reason: 'un `\$` dans une source nue la rendrait illisible');
      }
    });

    testWidgets('le rendu hérité ne reçoit jamais de source délimitée',
        (tester) async {
      final String? soumise =
          await _sourceSoumise(tester, _seed('formula', r'\frac{a}{b}'));
      expect(soumise, isNotNull);
      expect(soumise!.contains(r'$'), isFalse);
    });
  });
}
