/// Tests PORTEURS du gabarit PDF flashcards PUR (su-11, AC1/AC2/AC9).
///
/// Discipline R3 (leçons su-1..9) : chaque test rougit **par le COMPORTEMENT**
/// (masquer les réponses cesse de masquer → la réponse ré-apparaît dans le texte
/// extrait ; un badge mal mappé → le badge attendu disparaît). Aucun test ne se
/// contente d'un `takeException() isNull`. La robustesse AD-10 balaye un MOTIF de
/// défauts (vide, malformé, LaTeX nul, throw du port, explication longue,
/// Unicode/RTL), jamais un cas unique.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_export/zcrud_export.dart';

import 'support/pdf_flashcard_support.dart';

void main() {
  group('AC1 — sortie neutre {bytes, fileName, mimeType}', () {
    test('mimeType application/pdf, bytes préfixés %PDF-, fileName par défaut',
        () async {
      final res = await const ZFlashcardPdfTemplate().build(
        const ZFlashcardPdfInput(
          title: 'Révisions',
          cards: <ZFlashcardPdfCard>[ZFlashcardPdfCard(question: 'Bonjour ?')],
        ),
      );
      expect(res.mimeType, 'application/pdf');
      expect(res.fileName, 'flashcards.pdf');
      // Préfixe magic-number PDF (bytes réels d'un document valide).
      expect(String.fromCharCodes(res.bytes.take(5)), '%PDF-');
      expect(pdfPageCount(res.bytes), greaterThanOrEqualTo(1));
    });

    test('fileName personnalisable', () async {
      final res = await const ZFlashcardPdfTemplate().build(
        const ZFlashcardPdfInput(cards: <ZFlashcardPdfCard>[]),
        fileName: 'dossier-42.pdf',
      );
      expect(res.fileName, 'dossier-42.pdf');
    });
  });

  group('AC1 — badge d\'instruction PAR TYPE (motif balayé, table unique)', () {
    // MOTIF : les 6 types + une clé INCONNUE (repli openQuestion). Un mapping
    // cassé (ex. toujours openQuestion) ferait rougir les 5 autres lignes.
    const cases = <(String, String)>[
      (kFlashcardPdfTypeMultipleChoice, 'QCM'),
      (kFlashcardPdfTypeTrueOrFalse, 'Vrai ou faux'),
      (kFlashcardPdfTypeOpenQuestion, 'Question ouverte'),
      (kFlashcardPdfTypeExercise, 'Exercice'),
      (kFlashcardPdfTypeFillBlank, 'trous'),
      (kFlashcardPdfTypeShortAnswer, 'Réponse courte'),
      ('typeInconnuXYZ', 'Question ouverte'), // repli défensif AD-10
    ];
    for (final (typeKey, expectedBadge) in cases) {
      test('type "$typeKey" → badge « $expectedBadge »', () async {
        final res = await const ZFlashcardPdfTemplate().build(
          ZFlashcardPdfInput(
            cards: <ZFlashcardPdfCard>[
              ZFlashcardPdfCard(typeKey: typeKey, question: 'Q ?'),
            ],
          ),
        );
        final text = extractPdfText(res.bytes);
        expect(text, contains(expectedBadge),
            reason: 'le badge du type "$typeKey" doit apparaître dans le PDF');
      });
    }
  });

  group('AC2 — withAnswers vs withoutAnswers (enum, jamais booléen)', () {
    ZFlashcardPdfInput inputWith(String secretAnswer, String secretExpl) =>
        ZFlashcardPdfInput(
          cards: <ZFlashcardPdfCard>[
            ZFlashcardPdfCard(
              question: 'Quelle est la capitale ?',
              answer: secretAnswer,
              explanation: secretExpl,
            ),
          ],
        );

    test('withAnswers rend réponse ET explication (texte extrait)', () async {
      final res = await const ZFlashcardPdfTemplate().build(
        inputWith('ZREPONSESECRETE', 'ZEXPLICATIONSECRETE'),
        answerVisibility: ZAnswerVisibility.withAnswers,
      );
      final text = extractPdfText(res.bytes);
      expect(text, contains('ZREPONSESECRETE'));
      expect(text, contains('ZEXPLICATIONSECRETE'));
    });

    test('withoutAnswers MASQUE réponse ET explication (R3 : cessent d\'être là)',
        () async {
      final res = await const ZFlashcardPdfTemplate().build(
        inputWith('ZREPONSESECRETE', 'ZEXPLICATIONSECRETE'),
        answerVisibility: ZAnswerVisibility.withoutAnswers,
      );
      final text = extractPdfText(res.bytes);
      // Si le masquage casse, ces mots ré-apparaissent → le test rougit.
      expect(text, isNot(contains('ZREPONSESECRETE')));
      expect(text, isNot(contains('ZEXPLICATIONSECRETE')));
      // L'énoncé, lui, reste présent (on ne masque QUE les réponses).
      expect(text, contains('capitale'));
    });

    test('les deux modes produisent des documents DISTINCTS (bytes)', () async {
      final tmpl = const ZFlashcardPdfTemplate();
      final withA = await tmpl.build(inputWith('AAA', 'BBB'),
          answerVisibility: ZAnswerVisibility.withAnswers);
      final without = await tmpl.build(inputWith('AAA', 'BBB'),
          answerVisibility: ZAnswerVisibility.withoutAnswers);
      expect(withA.bytes, isNot(equals(without.bytes)));
    });

    test('V/F : isTrue masqué en withoutAnswers, présent en withAnswers',
        () async {
      const input = ZFlashcardPdfInput(
        cards: <ZFlashcardPdfCard>[
          ZFlashcardPdfCard(
            typeKey: kFlashcardPdfTypeTrueOrFalse,
            question: 'La Terre est plate.',
            isTrue: false,
          ),
        ],
      );
      final tmpl = const ZFlashcardPdfTemplate();
      final withA = await tmpl.build(input,
          answerVisibility: ZAnswerVisibility.withAnswers);
      final without = await tmpl.build(input,
          answerVisibility: ZAnswerVisibility.withoutAnswers);
      expect(extractPdfText(withA.bytes), contains('Faux'));
      expect(extractPdfText(without.bytes), isNot(contains('Faux')));
    });
  });

  group('AC1 — choix QCM : libellés présents ; marques discriminantes', () {
    const qcm = ZFlashcardPdfInput(
      cards: <ZFlashcardPdfCard>[
        ZFlashcardPdfCard(
          typeKey: kFlashcardPdfTypeMultipleChoice,
          question: 'Lequel est premier ?',
          choices: <ZFlashcardPdfChoice>[
            ZFlashcardPdfChoice(content: 'CHOIXpremier', isCorrect: true),
            ZFlashcardPdfChoice(content: 'CHOIXsecond', isCorrect: false),
          ],
        ),
      ],
    );

    test('libellés de choix présents dans les DEUX modes (non marqués inclus)',
        () async {
      final tmpl = const ZFlashcardPdfTemplate();
      for (final v in ZAnswerVisibility.values) {
        final res = await tmpl.build(qcm, answerVisibility: v);
        final text = extractPdfText(res.bytes);
        expect(text, contains('CHOIXpremier'), reason: 'mode $v');
        expect(text, contains('CHOIXsecond'), reason: 'mode $v');
      }
    });

    test('la position de la bonne réponse change les BYTES (✓ vs ✗ discriminant)',
        () async {
      const flipped = ZFlashcardPdfInput(
        cards: <ZFlashcardPdfCard>[
          ZFlashcardPdfCard(
            typeKey: kFlashcardPdfTypeMultipleChoice,
            question: 'Lequel est premier ?',
            choices: <ZFlashcardPdfChoice>[
              ZFlashcardPdfChoice(content: 'CHOIXpremier', isCorrect: false),
              ZFlashcardPdfChoice(content: 'CHOIXsecond', isCorrect: true),
            ],
          ),
        ],
      );
      final tmpl = const ZFlashcardPdfTemplate();
      final a = await tmpl.build(qcm, answerVisibility: ZAnswerVisibility.withAnswers);
      final b = await tmpl.build(flipped, answerVisibility: ZAnswerVisibility.withAnswers);
      // Les marques ✓/✗ suivent isCorrect : permuter la bonne réponse change le rendu.
      expect(a.bytes, isNot(equals(b.bytes)));
    });
  });

  group('AC9 — robustesse AD-10 : jamais de throw du parent (MOTIF)', () {
    test('dossier VIDE → PDF valide 1 page (titre seul), jamais 0-page',
        () async {
      final res = await const ZFlashcardPdfTemplate().build(
        const ZFlashcardPdfInput(title: 'Vide', cards: <ZFlashcardPdfCard>[]),
      );
      expect(String.fromCharCodes(res.bytes.take(5)), '%PDF-');
      expect(pdfPageCount(res.bytes), greaterThanOrEqualTo(1));
    });

    test('carte MALFORMÉE (question vide, choices null, type inconnu) → OK',
        () async {
      final res = await const ZFlashcardPdfTemplate().build(
        const ZFlashcardPdfInput(
          cards: <ZFlashcardPdfCard>[
            ZFlashcardPdfCard(typeKey: '???', question: ''),
          ],
        ),
      );
      expect(String.fromCharCodes(res.bytes.take(5)), '%PDF-');
    });

    test('LaTeX invalide (rasterizer NULL) → repli TEXTE brut de la formule',
        () async {
      final res = await ZFlashcardPdfTemplate(rasterizer: NullLatexRasterizer())
          .build(
        const ZFlashcardPdfInput(
          cards: <ZFlashcardPdfCard>[
            ZFlashcardPdfCard(question: r'Soit $FORMULEBRUTE$ la valeur.'),
          ],
        ),
      );
      final text = extractPdfText(res.bytes);
      // Repli AC9 : la source LaTeX est dessinée EN TEXTE (extractible).
      expect(text, contains('FORMULEBRUTE'));
      expect(text, contains('Soit'));
    });

    test('rasterizer qui LÈVE → absorbé, repli texte, pas de throw parent',
        () async {
      final res =
          await ZFlashcardPdfTemplate(rasterizer: ThrowingLatexRasterizer())
              .build(
        const ZFlashcardPdfInput(
          cards: <ZFlashcardPdfCard>[
            ZFlashcardPdfCard(question: r'$BOOM$ après.'),
          ],
        ),
      );
      expect(extractPdfText(res.bytes), contains('BOOM'));
    });

    test('explication TRÈS LONGUE → pagination (> 1 page), pas de rognage',
        () async {
      final longExpl = List.filled(2500, 'lorem').join(' ');
      final res = await const ZFlashcardPdfTemplate().build(
        ZFlashcardPdfInput(
          cards: <ZFlashcardPdfCard>[
            ZFlashcardPdfCard(question: 'Q ?', explanation: longExpl),
          ],
        ),
      );
      expect(pdfPageCount(res.bytes), greaterThan(1),
          reason: 'une explication de 2500 mots doit déborder sur >1 page');
    });

    test('Unicode / RTL dans le texte → rendu sans exception', () async {
      final res = await const ZFlashcardPdfTemplate().build(
        const ZFlashcardPdfInput(
          title: 'اختبار 🎓 δοκιμή',
          cards: <ZFlashcardPdfCard>[
            ZFlashcardPdfCard(
              question: 'مرحبا — Καλημέρα — 你好 — 🚀',
              answer: 'réponse ✅',
            ),
          ],
        ),
      );
      expect(String.fromCharCodes(res.bytes.take(5)), '%PDF-');
    });
  });
}
