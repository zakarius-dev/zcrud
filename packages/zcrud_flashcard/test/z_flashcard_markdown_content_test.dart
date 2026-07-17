/// AC6 — adaptateur markdown/LaTeX **opt-in**, DANS `zcrud_flashcard` (SU-2,
/// AD-40 / AD-7 / AD-10 / AD-1).
///
/// Le discriminant central est le cas **(2)** : **sans** injection, le rendu
/// riche ne doit **jamais** apparaître. C'est lui qui prouve que le riche est
/// bien une **injection** et non un défaut — sans ce cas, un widget qui rendrait
/// le markdown en dur passerait tous les autres tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Future<void> _pump(
  WidgetTester tester, {
  required ZFlashcard card,
  ZFlashcardContentBuilder? contentBuilder,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ZFlashcardReviewCard(
                card: card,
                contentBuilder: contentBuilder,
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  group('AC6 — (1) AVEC injection : le contenu est rendu en RICHE', () {
    testWidgets('« **gras** » rend un ZMarkdownReader, pas le texte littéral',
        (tester) async {
      await _pump(
        tester,
        card: const ZFlashcard(question: '**gras**'),
        contentBuilder: ZFlashcardMarkdownContent.builder(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ZMarkdownReader), findsOneWidget,
          reason: 'l\'adaptateur n\'a pas composé le lecteur riche');
      expect(find.text('**gras**'), findsNothing,
          reason: 'le markdown s\'affiche VERBATIM malgré l\'injection : le '
              'codec n\'est pas appliqué');
    });

    testWidgets('la fabrique `builder()` est conforme au slot su-1 (typedef)',
        (tester) async {
      // Voie d'usage app documentée : `ZFlashcardReviewCard(contentBuilder:
      // ZFlashcardMarkdownContent.builder())`. Si le typedef divergeait, cette
      // affectation ne compilerait pas.
      final ZFlashcardContentBuilder builder =
          ZFlashcardMarkdownContent.builder();
      await _pump(
        tester,
        card: const ZFlashcard(question: 'Q', answer: '**A**'),
        contentBuilder: builder,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ZMarkdownReader), findsOneWidget);
    });

    testWidgets('TOUS les chemins de contenu passent par l\'adaptateur',
        (tester) async {
      await _pump(
        tester,
        card: const ZFlashcard(
          question: 'Q',
          type: ZFlashcardType.multipleChoice,
          choices: <ZChoice>[ZChoice(content: 'C1'), ZChoice(content: 'C2')],
        ),
        contentBuilder: ZFlashcardMarkdownContent.builder(),
      );
      await tester.pumpAndSettle();

      // 1 question + 2 choix = 3 lecteurs riches.
      expect(find.byType(ZMarkdownReader), findsNWidgets(3));
    });
  });

  group('AC6 — (2) SANS injection : AUCUN rendu riche (le défaut reste su-1)', () {
    testWidgets(
      '« **gras** » s\'affiche VERBATIM et AUCUN ZMarkdownReader n\'apparaît',
      (tester) async {
        // ⚠️ LE discriminant d'AD-40 : une app qui n'injecte rien ne paie pas
        // Quill. Si `ZFlashcardReviewCard` rendait le riche en dur, ce cas — et
        // lui seul — rougirait.
        await _pump(tester, card: const ZFlashcard(question: '**gras**'));
        await tester.pumpAndSettle();

        expect(find.byType(ZMarkdownReader), findsNothing,
            reason: 'le rendu riche est atteint SANS injection : AD-40 est '
                'violé (le consommateur paierait Quill sans l\'avoir demandé)');
        expect(find.text('**gras**'), findsOneWidget,
            reason: 'le défaut doit rendre le contenu VERBATIM (texte brut)');
        expect(find.byType(ZFlashcardDefaultContent), findsOneWidget);
      },
    );
  });

  group('AC6 — (3) AD-10 : un markdown mal formé ne casse JAMAIS le rendu', () {
    // ⚠️ Chaque source est nommée : `''` ne peut pas être décrite par un extrait
    // d'elle-même, et c'est précisément le cas qui avait été NEUTRALISÉ (rendu
    // comme `'Q'` par un `malformed.isEmpty ? 'Q' : malformed`) — le cas
    // attestait donc une propriété qu'il n'exerçait pas.
    final sources = <String, String>{
      'gras jamais fermé': '**gras non fermé',
      'lien tronqué': '[lien(sans-fin',
      'LaTeX tronqué': r'$$\frac{1}{',
      'fence jamais fermée': '```dart\nfence jamais fermée',
      'tableau tronqué': '| a | b |\n|--',
      'source VIDE': '',
      // 🔴 Cas RESTAURÉ : il avait été remplacé par des sources compactes au
      // motif d'un « artefact de harnais ». L'exécution a réfuté ce diagnostic
      // — le débordement était RÉEL (cf. D3, groupe « face défilable »). On ne
      // modifie jamais un test pour faire taire un défaut : les sources
      // compactes ci-dessus sont un bon AJOUT, elles ne REMPLACENT rien.
      'source LONGUE (500 titres)': '# ' * 500,
    };

    sources.forEach((String nom, String malformed) {
      testWidgets('source mal formée — $nom ⇒ aucune exception', (tester) async {
        await _pump(
          tester,
          card: ZFlashcard(question: malformed),
          contentBuilder: ZFlashcardMarkdownContent.builder(),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'ZMarkdownCodec.decode doit retomber sur [] (AD-10), '
                'jamais lever');
      });
    });

    testWidgets('contenu vide ⇒ placeholder l10n, jamais un throw',
        (tester) async {
      await _pump(
        tester,
        card: const ZFlashcard(question: 'Q', answer: ' '),
        contentBuilder: ZFlashcardMarkdownContent.builder(),
      );
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ZMarkdownReader), findsWidgets);
    });

    testWidgets('le placeholder est PARAMÉTRABLE (jamais un libellé en dur)',
        (tester) async {
      await _pump(
        tester,
        card: const ZFlashcard(question: ''),
        contentBuilder:
            ZFlashcardMarkdownContent.builder(placeholder: 'VIDE PERSO'),
      );
      await tester.pumpAndSettle();

      expect(find.text('VIDE PERSO'), findsOneWidget,
          reason: 'le placeholder injecté est IGNORÉ');
    });
  });

  group('🔴 D1 — AC2 × AC6 : la révélation par tap SURVIT à l\'adaptateur '
      'markdown', () {
    // ⚠️ LE trou exact : les 9 taps d'AC2 n'exercent QUE le contentBuilder par
    // DÉFAUT. Or l'usage que la story documente VERBATIM est
    // `contentBuilder: ZFlashcardMarkdownContent.builder()` — et sur ce
    // chemin-là, le `QuillEditor` (qui autorise la sélection) GAGNE l'arène des
    // gestes contre l'`InkWell` de la carte : `onRevealChanged` ne recevait
    // rien et la réponse n'apparaissait JAMAIS. Mesuré : défaut ⇒ [true] ;
    // markdown ⇒ []. La fonction centrale de su-2 était morte sur son chemin
    // d'usage documenté, avec 328/328 verts.

    testWidgets(
      'un tap sur une carte à contenu MARKDOWN révèle bien la réponse',
      (tester) async {
        final events = <bool>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: ZFlashcardReviewCard(
                    card: const ZFlashcard(question: '**Q**', answer: '**A**'),
                    contentBuilder: ZFlashcardMarkdownContent.builder(),
                    onRevealChanged: events.add,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pumpAndSettle();

        expect(events, <bool>[true],
            reason: 'le contenu injecté CAPTE le tap : la carte ne le reçoit '
                'jamais et la réponse n\'apparaît pas. Le contenu de su-2 est '
                'un AFFICHAGE — il ne doit consommer aucun geste.');

        // La face RÉPONSE est bien montée : sur le chemin markdown la réponse
        // est rendue par un `ZMarkdownReader` (jamais un `Text` brut) — c'est
        // donc sa SOURCE qu'on interroge, pas un texte rendu par Quill.
        final sources = tester
            .widgetList<ZMarkdownReader>(find.byType(ZMarkdownReader))
            .map((ZMarkdownReader r) => r.value)
            .toList();
        expect(sources, contains('**A**'),
            reason: 'la face RÉPONSE n\'est pas rendue après la révélation '
                '(sources montées : $sources)');
        expect(sources, isNot(contains('**Q**')),
            reason: 'la face QUESTION est encore montée : la bascule n\'a pas '
                'eu lieu');
      },
    );

    testWidgets(
      'un tap AU CENTRE du contenu markdown (et non sur une marge) révèle '
      'aussi',
      (tester) async {
        // Discriminant : taper la carte « quelque part » pourrait tomber sur le
        // padding, hors du contenu — le défaut resterait invisible. Ici on vise
        // le lecteur riche lui-même, là où le QuillEditor gagnait l'arène.
        final events = <bool>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: ZFlashcardReviewCard(
                    card: const ZFlashcard(
                      question: 'Une question assez longue pour occuper la '
                          'largeur de la carte',
                      answer: '**A**',
                    ),
                    contentBuilder: ZFlashcardMarkdownContent.builder(),
                    onRevealChanged: events.add,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ZMarkdownReader));
        await tester.pumpAndSettle();

        expect(events, <bool>[true],
            reason: 'un tap SUR le contenu riche n\'atteint pas la carte : le '
                'sous-arbre du slot n\'est pas inerte aux gestes');
      },
    );

    testWidgets(
      'AC4 tenu sous markdown : les actions restent ABSENTES, jamais grisées',
      (tester) async {
        // Garde-fou du fix D1 : neutraliser les gestes ne doit pas déborder sur
        // la rangée d'actions (AD-45 : absence STRUCTURELLE, jamais un contrôle
        // désactivé). Une action présente mais inerte serait le pire des deux.
        var edits = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: ZFlashcardReviewCard(
                    card: const ZFlashcard(question: '**Q**', answer: '**A**'),
                    contentBuilder: ZFlashcardMarkdownContent.builder(),
                    onEdit: () => edits++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ZFlashcardReviewCard.editActionKey));
        await tester.pumpAndSettle();

        expect(edits, 1,
            reason: 'l\'action d\'édition est devenue INERTE : la neutralisation '
                'des gestes du contenu a débordé sur les actions');
      },
    );
  });

  group('AC6 — l\'adaptateur est MINCE (il compose, il n\'invente pas)', () {
    testWidgets('il rend directement un ZMarkdownReader (aucune couche maison)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: ZFlashcardMarkdownContent(content: '**gras**'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ZMarkdownReader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
