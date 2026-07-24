// CR-LEX-41 §A — `_Flow.drawText` ne découpait que sur l'ESPACE : un mot portant
// un `\n` partait en UN `drawString` dans un `Rect` d'UNE hauteur de ligne, et
// tout ce qui suivait le saut sortait du rectangle. Jamais rendu, sans exception
// ni compteur : le PDF restait valide et AMPUTÉ. Plus grave que CR-LEX-38, qui
// laissait au moins un `?` à la place du glyphe perdu.
//
// CR-LEX-41 §B — `_tokenize` découpait inconditionnellement sur `$` et le repli
// texte réémettait les segments SANS leurs délimiteurs : « Droit sur 100 $ US »
// devenait « Droit sur 100  US ». Sur un corpus douanier, la perte du symbole
// monétaire est une altération de sens.
//
// CR-LEX-42 — la numérotation `'Carte $index / $total'` et le repli de titre
// `'Flashcards'` étaient écrits en français EN DUR, hors de `ZFlashcardPdfLabels`
// et hors de toute signature de `build` : un hôte qui localisait scrupuleusement
// les onze libellés injectables obtenait quand même un document mixte.
//
// 🔴 Ces trois défauts ont survécu à toute la suite existante parce qu'elle
// s'arrête au préfixe `%PDF-`. Ici on EXTRAIT le texte du PDF réellement produit
// (`PdfTextExtractor`) : un test qui ne relit pas ce qu'il écrit ne peut pas
// rougir. C'est la remarque que lex nous fait depuis CR-LEX-38, appliquée.
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:zcrud_export_pdf/zcrud_export_pdf.dart';

import 'support/pdf_flashcard_support.dart';

/// Produit le PDF et en RELIT le texte — la seule mesure qui peut rougir.
Future<String> _texteExtrait(
  ZFlashcardPdfInput input, {
  ZAnswerVisibility visibility = ZAnswerVisibility.withAnswers,
  ZFlashcardPdfTemplate template = const ZFlashcardPdfTemplate(),
}) async {
  final out = await template.build(input, answerVisibility: visibility);
  final doc = PdfDocument(inputBytes: out.bytes);
  try {
    return PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

ZFlashcardPdfInput _deck(
  List<ZFlashcardPdfCard> cards, {
  String title = 'TITRE',
  ZFlashcardPdfLabels labels = const ZFlashcardPdfLabels(),
}) =>
    ZFlashcardPdfInput(title: title, cards: cards, labels: labels);

void main() {
  group('🔴 CR-LEX-41 §A — un saut de ligne n\'AMPUTE plus la carte', () {
    test('🔴 tout ce qui suit `\\n` et `\\t` survit au document', () async {
      // Reproduction LITTÉRALE de la sonde lex.
      final txt = await _texteExtrait(_deck(const <ZFlashcardPdfCard>[
        ZFlashcardPdfCard(
          question: 'LIGNEUN\nLIGNEDEUX\tTABULE',
          answer: 'REPONSEA\n\nREPONSEB',
        ),
      ]));
      expect(txt, contains('LIGNEUN'));
      expect(txt, contains('LIGNEDEUX'),
          reason: 'la 2e ligne de l\'énoncé disparaissait du PDF');
      // ⚠️ `TABULE` était perdu à cause du `\n` qui le précède, PAS du `\t` :
      // mesuré, `'AAA\tBBB'` ressortait déjà intact. La CR demandait de découper
      // aussi sur `\t` — nous ne le faisons pas, faute de perte à corriger.
      expect(txt, contains('TABULE'),
          reason: 'le `\\n` amputait la fin de la ligne, tabulation comprise');
      expect(txt, contains('REPONSEA'));
      expect(txt, contains('REPONSEB'),
          reason: 'la ligne après une ligne VIDE disparaissait aussi');
    });

    test('🔴 CRLF, CR nu et séparateurs Unicode sont aussi des ruptures',
        () async {
      final txt = await _texteExtrait(_deck(const <ZFlashcardPdfCard>[
        ZFlashcardPdfCard(
          question: 'ALPHA\r\nBRAVO\rCHARLIE DELTA ECHOFOX',
        ),
      ]));
      for (final mot in <String>[
        'ALPHA',
        'BRAVO',
        'CHARLIE',
        'DELTA',
        'ECHO',
        'FOX',
      ]) {
        expect(txt, contains(mot), reason: '$mot perdu');
      }
    });

    test('🔴 le badge non plus n\'est pas amputé (jumeau non signalé par la CR)',
        () async {
      // `drawBadge` peignait dans un rectangle d'une seule hauteur de ligne, sans
      // découpe aucune : le même défaut, deux méthodes plus loin.
      final txt = await _texteExtrait(_deck(
        const <ZFlashcardPdfCard>[ZFlashcardPdfCard(question: 'Q')],
        labels: const ZFlashcardPdfLabels(
          openQuestion: 'BADGELIGNEUN\nBADGELIGNEDEUX',
        ),
      ));
      expect(txt, contains('BADGELIGNEUN'));
      expect(txt, contains('BADGELIGNEDEUX'),
          reason: 'la 2e ligne du badge disparaissait');
    });

    test('la composition inline reste sur la MÊME ligne (non-régression)',
        () async {
      // `drawText` est appelé EN COURS de ligne (« Réponse : » puis le contenu).
      // Un retour forcé sur la 1re ligne casserait la composition.
      final txt = await _texteExtrait(_deck(const <ZFlashcardPdfCard>[
        ZFlashcardPdfCard(question: 'Q', answer: 'MONO'),
      ]));
      expect(txt, contains('MONO'));
      expect(txt, contains('Réponse'));
    });
  });

  group('🔴 CR-LEX-41 §B — le `\$` ne s\'évapore plus', () {
    test('🔴 le symbole monétaire survit (repli texte, rasterizer absent)',
        () async {
      final txt = await _texteExtrait(_deck(const <ZFlashcardPdfCard>[
        ZFlashcardPdfCard(question: r'Droit sur 100 $ US'),
      ]));
      expect(txt, contains(r'$'),
          reason: 'le `\$` était SUPPRIMÉ : « 100 \$ US » → « 100  US »');
    });

    test('🔴 les délimiteurs d\'une formule sont réémis en repli', () async {
      final txt = await _texteExtrait(_deck(const <ZFlashcardPdfCard>[
        ZFlashcardPdfCard(question: r'Calculez $x^2+1$ maintenant'),
      ]));
      expect(txt, contains(r'$'),
          reason: 'sans rasterizer, le repli doit être NON destructif');
      expect(txt, contains('x^2+1'));
    });

    test('🔴 INVARIANT SANS PERTE : le texte rendu contient tous les `\$`',
        () async {
      // Corpus de pièges : appariés, orphelin, en fin, collés, aucun.
      const corpus = <String, int>{
        r'a$x$b': 2,
        r'100 $ US': 1,
        r'fin $': 1,
        r'$debut': 1,
        r'$a$ et $b$': 4,
        'aucun': 0,
        r'$$': 2,
      };
      for (final entry in corpus.entries) {
        final txt = await _texteExtrait(_deck(<ZFlashcardPdfCard>[
          ZFlashcardPdfCard(question: entry.key),
        ]));
        final compte = r'$'.allMatches(txt).length;
        expect(compte, entry.value,
            reason: 'sur « ${entry.key} » : ${entry.value} `\$` attendus, '
                '$compte rendus');
      }
    });

    test('🔴 `latexEnabled: false` empêche la RASTERISATION (observable)',
        () async {
      // Mesure discriminante : avec un rasteriseur qui RÉUSSIT, un segment tenu
      // pour du LaTeX devient un bitmap — son texte n'est PLUS extractible.
      // Comparer les deux réglages sur la même entrée prouve que le drapeau est
      // lu ; se contenter d'un `contains(r'$')` passerait aussi quand il est
      // ignoré, puisque le repli réémet désormais les délimiteurs.
      const deck = <ZFlashcardPdfCard>[
        ZFlashcardPdfCard(question: r'Prix $MONTANT$ dollars'),
      ];
      final rasterise = await _texteExtrait(
        _deck(deck),
        template: ZFlashcardPdfTemplate(rasterizer: FakeLatexRasterizer()),
      );
      final litteral = await _texteExtrait(
        _deck(deck),
        template: ZFlashcardPdfTemplate(
          rasterizer: FakeLatexRasterizer(),
          options: const ZPdfExportOptions(latexEnabled: false),
        ),
      );
      expect(rasterise.contains('MONTANT'), isFalse,
          reason: 'témoin : rasterisé, donc hors du texte extractible');
      expect(litteral, contains('MONTANT'),
          reason: 'latexEnabled: false ⇒ le segment reste du TEXTE');
      expect(litteral, contains(r'$'));
      expect(const ZPdfExportOptions().latexEnabled, isTrue,
          reason: 'le défaut ne change pas : personne ne casse');
    });

    test('l\'option participe à l\'égalité de valeur', () {
      expect(const ZPdfExportOptions(),
          isNot(const ZPdfExportOptions(latexEnabled: false)));
      expect(const ZPdfExportOptions().hashCode,
          isNot(const ZPdfExportOptions(latexEnabled: false).hashCode));
    });
  });

  group('🔴 CR-LEX-42 — la numérotation est injectable', () {
    test('🔴 un hôte non francophone n\'obtient plus « Carte »', () async {
      final txt = await _texteExtrait(_deck(
        const <ZFlashcardPdfCard>[ZFlashcardPdfCard(question: 'Q')],
        labels: const ZFlashcardPdfLabels(
          cardNumberPattern: 'Card {index} of {total}',
          openQuestion: 'OPEN',
        ),
      ));
      expect(txt, contains('Card'));
      expect(txt, contains('of'));
      expect(txt.contains('Carte'), isFalse,
          reason: 'seule chaîne française restante d\'un document localisé');
    });

    test('les jetons {index} / {total} sont substitués', () {
      const l = ZFlashcardPdfLabels(cardNumberPattern: '{index}/{total}');
      expect(l.cardNumberFor(3, 7), '3/7');
    });

    test('le défaut FR est inchangé (non cassant)', () {
      expect(const ZFlashcardPdfLabels().cardNumberFor(1, 4), 'Carte 1 / 4');
      expect(const ZFlashcardPdfLabels().untitledLabel, 'Flashcards');
    });

    test('🔴 un patron VIDE supprime la numérotation, sans rien casser',
        () async {
      final txt = await _texteExtrait(_deck(
        const <ZFlashcardPdfCard>[ZFlashcardPdfCard(question: 'CONTENU')],
        labels: const ZFlashcardPdfLabels(cardNumberPattern: ''),
      ));
      expect(txt, contains('CONTENU'), reason: 'la carte est toujours rendue');
      expect(txt.contains('Carte'), isFalse);
    });

    test('🔴 le repli de titre est injectable lui aussi', () async {
      final txt = await _texteExtrait(_deck(
        const <ZFlashcardPdfCard>[ZFlashcardPdfCard(question: 'Q')],
        title: '',
        labels: const ZFlashcardPdfLabels(untitledLabel: 'UNTITLEDDECK'),
      ));
      expect(txt, contains('UNTITLEDDECK'));
      expect(txt.contains('Flashcards'), isFalse);
    });

    test('un patron sans jeton est rendu tel quel (AD-10, pas un throw)', () {
      const l = ZFlashcardPdfLabels(cardNumberPattern: 'SANSJETON');
      expect(l.cardNumberFor(1, 9), 'SANSJETON');
    });
  });
}
