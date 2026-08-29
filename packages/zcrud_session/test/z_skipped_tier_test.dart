/// 🎯 Le 5ᵉ seau — `ZFeedbackTier.skipped` / `ZFlashcardSubmission.skipped`.
///
/// Une carte **passée** (« Je ne sais pas ») et une carte **ratée** portent la
/// même note : la borne basse de l'échelle. Rien ne les distinguait, et le
/// retour pédagogique reprochait donc une erreur à qui n'avait rien tenté.
///
/// Quatre propriétés :
///  1. **INERTIE ABSOLUE** — sans le drapeau, la soumission émise et le seau
///     rendu sont EXACTEMENT ceux d'avant : `ZFlashcardSubmission` reste égal
///     (value-object, `==` profond) à celui construit sans le champ, et
///     `zFeedbackTierFor` rend le même seau sur TOUTE l'échelle ;
///  2. **LE SEAU NE SE DÉDUIT PAS** — aucune note, si basse soit-elle, ne
///     produit `skipped` toute seule ;
///  3. **LES 4 COMPTES EXISTANTS SONT INTACTS** — les agrégats par qualité
///     (`ZSessionQualityBreakdown`) et les quatre seaux historiques ne voient
///     jamais le cinquième ;
///  4. **CÂBLAGE RÉEL** — `markSkippedSubmissions: true` fait bien porter le
///     fait par la soumission de « Je ne sais pas », sans rien changer
///     d'autre (note, verdict, verrou).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

const _config = ZSrsConfig();

ZFeedbackTier _tier(int q, {bool skipped = false}) => zFeedbackTierFor(
      quality: q,
      timeTaken: const Duration(seconds: 30),
      hintsUsed: 0,
      config: _config,
      masteredThreshold: 4,
      skipped: skipped,
    );

void main() {
  group('🔒 INERTIE — sans le drapeau, RIEN ne change', () {
    test('🔴 `zFeedbackTierFor` rend le MÊME seau sur TOUTE l\'échelle, avec '
        'ou sans le paramètre écrit', () {
      for (var q = _config.minQuality; q <= _config.maxQuality; q++) {
        // Le paramètre OMIS (régime historique) et le paramètre à `false`
        // doivent coïncider — et surtout ne JAMAIS valoir `skipped`.
        final omitted = zFeedbackTierFor(
          quality: q,
          timeTaken: const Duration(seconds: 30),
          hintsUsed: 0,
          config: _config,
          masteredThreshold: 4,
        );
        expect(omitted, _tier(q, skipped: false), reason: 'q=$q');
        expect(omitted, isNot(ZFeedbackTier.skipped), reason: 'q=$q');
      }
      // Les seaux historiques, gelés (contre-preuve : la table est bien lue).
      expect(_tier(0), ZFeedbackTier.motivation);
      expect(_tier(2), ZFeedbackTier.motivation);
      expect(_tier(3), ZFeedbackTier.neutral);
      expect(_tier(5), ZFeedbackTier.encouragement);
    });

    test('🔴 `ZFlashcardSubmission` construite sans le champ est ÉGALE à '
        'celle d\'avant (value-object, `==` profond)', () {
      const a = ZFlashcardSubmission(
        quality: 0,
        timeTaken: Duration(seconds: 3),
        hintsUsed: 1,
        isCorrect: false,
      );
      const b = ZFlashcardSubmission(
        quality: 0,
        timeTaken: Duration(seconds: 3),
        hintsUsed: 1,
        isCorrect: false,
        skipped: false,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.skipped, isFalse);

      // 🔴 …et le champ DISCRIMINE réellement : sans cette assertion, un
      // `skipped` absent de `==` passerait la garde ci-dessus.
      const c = ZFlashcardSubmission(
        quality: 0,
        timeTaken: Duration(seconds: 3),
        hintsUsed: 1,
        isCorrect: false,
        skipped: true,
      );
      expect(a == c, isFalse,
          reason: '🔴 `skipped` n\'entre pas dans l\'égalité : deux faits '
              'différents seraient confondus');
    });
  });

  group('🎯 LE SEAU NE SE DÉDUIT PAS D\'UNE NOTE', () {
    test('🔴 aucune note ne produit `skipped` ; le drapeau, lui, l\'emporte '
        'sur TOUTE note', () {
      for (var q = _config.minQuality; q <= _config.maxQuality; q++) {
        expect(_tier(q, skipped: false), isNot(ZFeedbackTier.skipped),
            reason: '🔴 q=$q a produit `skipped` sans que rien ne le déclare');
        expect(_tier(q, skipped: true), ZFeedbackTier.skipped,
            reason: '🔴 le fait déclaré n\'a pas été honoré pour q=$q');
      }
    });

    test('la banque par défaut couvre le 5ᵉ seau, en FR et en EN, avec un '
        'message DISTINCT des quatre autres', () {
      const bank = ZDefaultFeedbackBank();
      final keys = <String>[
        for (final t in ZFeedbackTier.values) zFeedbackKeyFor(t),
      ];
      expect(keys, contains('zcrud.session.feedback.skipped'));

      for (final lang in <String>['fr', 'en']) {
        final texts = keys
            .map((String k) => bank.maybeResolve(k, lang))
            .toList(growable: false);
        expect(texts.any((String? t) => t == null), isFalse,
            reason: '🔴 un seau n\'a pas de message en $lang');
        expect(texts.toSet(), hasLength(ZFeedbackTier.values.length),
            reason: '🔴 deux seaux partagent le même message en $lang');
      }
    });
  });

  group('🔒 LES 4 COMPTES EXISTANTS SONT INTACTS', () {
    testWidgets('🔴 `ZSessionQualityBreakdown` ne connaît que les qualités : '
        'le 5ᵉ seau n\'y ajoute ni ne retire aucun segment', (tester) async {
      // Répartition figée : un segment par clé présente, aucune de plus.
      const byQuality = <String, int>{'0': 4, '3': 2, '5': 1};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSessionQualityBreakdown(
              byQuality: byQuality,
              scale: ZQualityScale.fromConfig(_config),
              passThreshold: _config.passThreshold,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Les comptes rendus sont EXACTEMENT ceux de la map — le 5ᵉ seau n'est
      // pas un compte, il n'a rien à faire ici.
      for (final entry in byQuality.entries) {
        expect(find.textContaining('${entry.value}'), findsWidgets,
            reason: 'compte ${entry.value} (q=${entry.key}) absent');
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('🎯 CÂBLAGE RÉEL — « Je ne sais pas »', () {
    /// Monte la surface de saisie sur une carte à réponse rédigée et capture
    /// la soumission émise.
    /// [seed] force un `State` NEUF entre deux montages successifs : sans
    /// clé distincte, `pumpWidget` réutilise l'`Element` (même type, même
    /// position) et la surface reste sur la correction déjà émise — le bouton
    /// « Je ne sais pas » a alors disparu, et la seconde mesure porterait sur
    /// un arbre mort.
    Future<List<ZFlashcardSubmission>> pump(
      WidgetTester tester, {
      required bool? markSkipped,
      String seed = 'a',
    }) async {
      final got = <ZFlashcardSubmission>[];
      const card = ZFlashcard(
        id: 'c1',
        folderId: 'd1',
        question: 'Q ?',
        answer: 'A',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // 🔒 Le régime par défaut s'obtient en N'ÉCRIVANT PAS le
            // paramètre — jamais en passant `false`.
            body: markSkipped == null
                ? ZFlashcardAnswerInput(
                    key: ValueKey<String>(seed),
                    card: card,
                    mode: ZReviewMode.spaced,
                    onSubmitted: got.add,
                  )
                : ZFlashcardAnswerInput(
                    key: ValueKey<String>(seed),
                    card: card,
                    mode: ZReviewMode.spaced,
                    onSubmitted: got.add,
                    markSkippedSubmissions: markSkipped,
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return got;
    }

    testWidgets('🔴 drapeau OMIS ⇒ soumission strictement historique '
        '(`skipped: false`), drapeau POSÉ ⇒ le fait est porté — même note, '
        'même verdict', (tester) async {
      final historic = await pump(tester, markSkipped: null);
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();
      expect(historic, hasLength(1));
      expect(historic.single.skipped, isFalse,
          reason: '🔴 INERTIE ROMPUE : sans le drapeau, la soumission de « Je '
              'ne sais pas » s\'est mise à porter `skipped`');

      final marked = await pump(tester, markSkipped: true, seed: 'b');
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();
      expect(marked, hasLength(1));
      expect(marked.single.skipped, isTrue,
          reason: '🔴 `markSkippedSubmissions` est un passe-plat inerte');

      // 🔒 RIEN d'autre n'a changé : même note, même verdict, même durée de
      // mesure (les deux soumissions ne diffèrent QUE par `skipped`).
      expect(marked.single.quality, historic.single.quality);
      expect(marked.single.isCorrect, historic.single.isCorrect);
      expect(marked.single.hintsUsed, historic.single.hintsUsed);
      expect(marked.single.quality, _config.minQuality);
      expect(marked.single.isCorrect, isFalse);
    });

    testWidgets('🔒 le drapeau ne touche PAS les autres voies de soumission : '
        'une réponse rédigée reste `skipped: false` même sous le drapeau',
        (tester) async {
      final got = await pump(tester, markSkipped: true);

      await tester.enterText(find.byType(TextFormField), 'A');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
      await tester.pumpAndSettle();

      expect(got, hasLength(1));
      expect(got.single.skipped, isFalse,
          reason: '🔴 une réponse RÉELLEMENT donnée a été marquée « passée » : '
              'le drapeau déborde de « Je ne sais pas »');
    });
  });
}
