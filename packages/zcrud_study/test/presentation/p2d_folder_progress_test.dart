/// **Lot P2-D** — progression pure d'un dossier : agrégat `ZFolderProgressSummary`
/// (`zSummarizeFolderProgress`) et sa barre segmentée `ZFolderProgressBar`.
///
/// Ce que ces gardes défendent, et pourquoi :
/// - le legacy recalculait `learned/toReview/toLearn` À CHAQUE BUILD depuis les
///   flux — l'anti-patron exact d'AD-2. La barre ne voit donc QUE la valeur, et
///   une garde compte les appels du calculateur pendant N reconstructions ;
/// - une SECONDE formule de partition divergerait silencieusement de celle du
///   sélecteur de session : une garde de source prouve la délégation à
///   `zCategorize` et l'absence de toute condition SRS réécrite ici.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

ZFlashcard _card(String id) => ZFlashcard(id: id, question: 'q$id');

ZRepetitionInfo _srs(
  String id, {
  int repetitions = 0,
  DateTime? next,
}) =>
    ZRepetitionInfo(
      flashcardId: id,
      folderId: 'f1',
      repetitions: repetitions,
      nextReviewDate: next,
    );

final DateTime kNow = DateTime.utc(2026, 3, 15, 12);

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: 320, child: child),
        ),
      ),
    );

/// Racine du dépôt (dossier portant `melos.yaml`) — jamais un `../` relatif :
/// la garde doit être ancrée au dépôt, pas au répertoire courant.
Directory _repoRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/melos.yaml').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('melos.yaml introuvable en remontant depuis ${Directory.current}');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  group('P2-D — zSummarizeFolderProgress : valeur PURE', () {
    test('mêmes entrées ⇒ valeur ÉGALE (déterminisme, `==` porteur)', () {
      final List<ZFlashcard> cards = <ZFlashcard>[
        for (int i = 0; i < 7; i++) _card('c$i'),
      ];
      final List<ZRepetitionInfo> infos = <ZRepetitionInfo>[
        _srs('c0', repetitions: 3, next: kNow.subtract(const Duration(days: 2))),
        _srs('c1', repetitions: 5, next: kNow.add(const Duration(days: 4))),
        _srs('c2'),
      ];

      final ZFolderProgressSummary a =
          zSummarizeFolderProgress(cards, infos, now: kNow);
      final ZFolderProgressSummary b =
          zSummarizeFolderProgress(cards, infos, now: kNow);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      // Contre-preuve : un instant DIFFÉRENT change la valeur — la fonction lit
      // bien `now`, elle ne rend pas une constante.
      expect(
        zSummarizeFolderProgress(
          cards,
          infos,
          now: kNow.add(const Duration(days: 10)),
        ),
        isNot(equals(a)),
      );
    });

    test('vecteur FIGÉ : 20 cartes ⇒ comptes exacts 8 / 5 / 7', () {
      final List<ZFlashcard> cards = <ZFlashcard>[
        for (int i = 0; i < 20; i++) _card('c$i'),
      ];
      final List<ZRepetitionInfo> infos = <ZRepetitionInfo>[
        // c0..c4 : apprises et DUES (échéance atteinte) ⇒ toReview = 5.
        for (int i = 0; i < 5; i++)
          _srs('c$i',
              repetitions: 2, next: kNow.subtract(Duration(days: i + 1))),
        // c5..c11 : apprises, échéance FUTURE ⇒ learned = 7.
        for (int i = 5; i < 12; i++)
          _srs('c$i', repetitions: 4, next: kNow.add(Duration(days: i))),
        // c12..c14 : état SRS présent mais `repetitions == 0` ⇒ à apprendre.
        for (int i = 12; i < 15; i++) _srs('c$i'),
        // c15..c19 : AUCUN état SRS ⇒ à apprendre. Total à apprendre = 8.
      ];

      final ZFolderProgressSummary s =
          zSummarizeFolderProgress(cards, infos, now: kNow);

      expect(s.total, 20);
      expect(s.toReview, 5);
      expect(s.learned, 7);
      expect(s.toLearn, 8);
      expect(s.learned + s.toReview + s.toLearn, s.total);
      expect(s.ratio, closeTo(7 / 20, 1e-12));
    });

    test('échéance PILE à `now` : due (frontière figée)', () {
      final ZFolderProgressSummary s = zSummarizeFolderProgress(
        <ZFlashcard>[_card('c0')],
        <ZRepetitionInfo>[_srs('c0', repetitions: 1, next: kNow)],
        now: kNow,
      );
      expect(s.toReview, 1);
      expect(s.learned, 0);
    });

    test('apprise SANS échéance ⇒ « apprise », jamais « à apprendre »', () {
      final ZFolderProgressSummary s = zSummarizeFolderProgress(
        <ZFlashcard>[_card('c0')],
        <ZRepetitionInfo>[_srs('c0', repetitions: 9)],
        now: kNow,
      );
      expect(s.learned, 1);
      expect(s.toLearn, 0);
      expect(s.toReview, 0);
    });

    test('dossier vide ⇒ `empty`, ratio 0 (aucune division par zéro)', () {
      expect(
        zSummarizeFolderProgress(
          const <ZFlashcard>[],
          const <ZRepetitionInfo>[],
          now: kNow,
        ),
        same(ZFolderProgressSummary.empty),
      );
      expect(ZFolderProgressSummary.empty.ratio, 0);
    });

    test(
      'identité avec la partition du domaine : les seaux SONT ceux de '
      '`zCategorize` (contre-preuve d\'une seconde formule)',
      () {
        final List<ZFlashcard> cards = <ZFlashcard>[
          for (int i = 0; i < 13; i++) _card('c$i'),
        ];
        final List<ZRepetitionInfo> infos = <ZRepetitionInfo>[
          _srs('c0', repetitions: 1, next: kNow.subtract(const Duration(days: 1))),
          _srs('c1', repetitions: 1, next: kNow),
          _srs('c2', repetitions: 0),
          _srs('c3', repetitions: 6, next: kNow.add(const Duration(days: 3))),
          _srs('c4', repetitions: 2),
        ];

        final ZSessionCategories ref = zCategorize(
          cards,
          srsById: zIndexSrsById(infos),
          at: kNow,
        );
        final ZFolderProgressSummary s =
            zSummarizeFolderProgress(cards, infos, now: kNow);

        expect(s.toLearn, ref.neverLearned.length);
        expect(s.toReview, ref.due.length);
        expect(s.learned, cards.length - ref.neverLearned.length - ref.due.length);
      },
    );
  });

  group('P2-D — garde de SOURCE : une seule formule de partition', () {
    test(
      'le calculateur DÉLÈGUE à `zCategorize` et ne réécrit AUCUNE condition '
      'SRS (grep négatif MONTRÉ)',
      () {
        final File source = File(
          '${_repoRoot().path}/packages/zcrud_study/lib/src/domain/'
          'z_folder_progress_summary.dart',
        );
        expect(source.existsSync(), isTrue, reason: source.path);
        final String code = source.readAsStringSync();
        // Le corps seul : les dartdoc CITENT légitimement `repetitions` et
        // `nextReviewDate` pour documenter la règle déléguée.
        final String body = code
            .split('\n')
            .where((String l) => !l.trimLeft().startsWith('///'))
            .join('\n');

        expect(body, contains('zCategorize('));
        expect(body, contains('zIndexSrsById('));
        // Aucune condition SRS recalculée ici : ni `repetitions`, ni
        // `nextReviewDate`, ni comparaison d'échéance.
        expect(body, isNot(contains('repetitions')));
        expect(body, isNot(contains('nextReviewDate')));
        expect(body, isNot(contains('isAfter')));
        expect(body, isNot(contains('isBefore')));
        // Pureté : aucune horloge implicite, aucune E/S.
        expect(body, isNot(contains('DateTime.now')));
        expect(body, isNot(contains('dart:io')));
      },
    );

    test('la BARRE ne voit ni cartes, ni états SRS, ni calculateur', () {
      final File source = File(
        '${_repoRoot().path}/packages/zcrud_study/lib/src/presentation/'
        'z_folder_progress_bar.dart',
      );
      expect(source.existsSync(), isTrue, reason: source.path);
      final String body = source
          .readAsStringSync()
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('///'))
          .join('\n');

      expect(body, isNot(contains('zSummarizeFolderProgress')));
      expect(body, isNot(contains('ZFlashcard')));
      expect(body, isNot(contains('ZRepetitionInfo')));
      expect(body, isNot(contains('Stream')));
      // FR-26 : aucune couleur littérale.
      expect(body, isNot(contains('Colors.')));
      expect(body, isNot(contains('Color(0x')));
      // AD-13 : aucune variante directionnellement fautive.
      expect(body, isNot(contains('EdgeInsets.only(left')));
      expect(body, isNot(contains('Alignment.centerLeft')));
      expect(body, isNot(contains('TextAlign.left')));
      expect(body, isNot(contains('TextAlign.right')));
    });
  });

  group('P2-D — ZFolderProgressBar : la VALEUR, jamais le flux', () {
    testWidgets(
      'N reconstructions ⇒ le calculateur est appelé EXACTEMENT 1 fois',
      (WidgetTester tester) async {
        int calls = 0;
        final List<ZFlashcard> cards = <ZFlashcard>[
          for (int i = 0; i < 6; i++) _card('c$i'),
        ];
        const List<ZRepetitionInfo> infos = <ZRepetitionInfo>[];

        // L'hôte calcule UNE fois, hors `build` — c'est le contrat.
        ZFolderProgressSummary summarize() {
          calls++;
          return zSummarizeFolderProgress(cards, infos, now: kNow);
        }

        final ZFolderProgressSummary summary = summarize();
        final ValueNotifier<int> tick = ValueNotifier<int>(0);
        addTearDown(tick.dispose);

        await tester.pumpWidget(
          _host(
            ValueListenableBuilder<int>(
              valueListenable: tick,
              builder: (BuildContext context, int value, _) =>
                  ZFolderProgressBar(
                summary: summary,
                learnedLabel: 'apprises $value',
              ),
            ),
          ),
        );

        for (int i = 1; i <= 25; i++) {
          tick.value = i;
          await tester.pump();
        }

        expect(find.text('apprises 25'), findsOneWidget);
        expect(calls, 1);
      },
    );

    testWidgets('trois seaux ⇒ trois segments, largeurs proportionnelles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ZFolderProgressBar(
            summary: ZFolderProgressSummary(
              learned: 2,
              toReview: 1,
              toLearn: 1,
              total: 4,
              ratio: 0.5,
            ),
          ),
        ),
      );

      final double learned = tester
          .getSize(find.byKey(ZFolderProgressBar.learnedSegmentKey))
          .width;
      final double toReview = tester
          .getSize(find.byKey(ZFolderProgressBar.toReviewSegmentKey))
          .width;
      final double toLearn = tester
          .getSize(find.byKey(ZFolderProgressBar.toLearnSegmentKey))
          .width;

      expect(learned, closeTo(160, 0.01));
      expect(toReview, closeTo(80, 0.01));
      expect(toLearn, closeTo(80, 0.01));
      expect(learned + toReview + toLearn, closeTo(320, 0.01));
    });

    testWidgets('seau VIDE ⇒ segment ABSENT de l\'arbre (AD-4)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ZFolderProgressBar(
            summary: ZFolderProgressSummary(
              learned: 3,
              toReview: 0,
              toLearn: 0,
              total: 3,
              ratio: 1,
            ),
          ),
        ),
      );

      expect(find.byKey(ZFolderProgressBar.learnedSegmentKey), findsOneWidget);
      expect(find.byKey(ZFolderProgressBar.toReviewSegmentKey), findsNothing);
      expect(find.byKey(ZFolderProgressBar.toLearnSegmentKey), findsNothing);
    });

    testWidgets('dossier vide ⇒ piste seule, aucune exception',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ZFolderProgressBar(summary: ZFolderProgressSummary.empty),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(ZFolderProgressBar.trackKey), findsOneWidget);
      expect(find.byKey(ZFolderProgressBar.learnedSegmentKey), findsNothing);
    });

    testWidgets(
        'aucun libellé ⇒ légende ABSENTE ; libellés ⇒ légende TEXTUELLE (AD-13)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ZFolderProgressBar(
            summary: ZFolderProgressSummary(
              learned: 1,
              toReview: 1,
              toLearn: 1,
              total: 3,
              ratio: 1 / 3,
            ),
          ),
        ),
      );
      expect(find.byKey(ZFolderProgressBar.legendKey), findsNothing);

      await tester.pumpWidget(
        _host(
          const ZFolderProgressBar(
            summary: ZFolderProgressSummary(
              learned: 1,
              toReview: 1,
              toLearn: 1,
              total: 3,
              ratio: 1 / 3,
            ),
            learnedLabel: '1 apprise',
            toReviewLabel: '1 à réviser',
            toLearnLabel: '1 à apprendre',
          ),
        ),
      );
      expect(find.byKey(ZFolderProgressBar.legendKey), findsOneWidget);
      expect(find.text('1 apprise'), findsOneWidget);
      expect(find.text('1 à réviser'), findsOneWidget);
      expect(find.text('1 à apprendre'), findsOneWidget);
    });
  });
}
