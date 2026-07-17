/// SU-7 / AC3 — 🔴🔴 **ZÉRO écriture SRS, garanti par le TYPE** (AD-23/AD-33).
///
/// # 🔴 Honnêteté du test — à lire AVANT les assertions
///
/// Ce fichier prouve une **absence**. Une absence ne se prouve pas en regardant
/// un espion rester à zéro : **un espion qu'on ne peut pas brancher reste à zéro
/// même quand tout est cassé**. C'est exactement ce qui rendait
/// `expect(spy.calls, isEmpty)` **infalsifiable** en su-4, et c'est le mensonge
/// d'intitulé que `z_no_srs_write_in_non_srs_modes_test.dart:187` a dû corriger.
///
/// La preuve est donc à **DEUX étages ici** (le troisième est automatique) :
///
/// - **(a) STRUCTURELLE — c'est elle qui PORTE la garantie.** `ZListSessionView`
///   n'a **aucun seam d'écriture** : ni au constructeur (`reviewer`/`scheduler`/
///   `store`), ni dans le corps (`ZSessionReviewer`, `.reviewCard(`,
///   `ZSrsScheduler`, `ZSm2Scheduler`, `ZRepetitionStore`). L'absence d'écriture
///   n'est **pas un comportement** : c'est une propriété du **TYPE**.
/// - **(b) COMPORTEMENTALE — elle mesure le CHEMIN RÉEL de bout en bout**, et
///   **ne porte pas** la garantie. ⚠️ **Ce que le `hasLength(1)` final signifie
///   VRAIMENT** : l'espion est **inatteignable par construction** — il n'existe
///   aucun paramètre où le passer à `ZListSessionView`. Ce compte n'est donc
///   **pas** « un espion branché qui n'a pas été appelé ». C'est pourquoi le
///   **témoin positif vient D'ABORD** : il prouve que **cet espion-là SAIT
///   capter** (sur le seul runtime qui écrit, `ZStudySessionEngine`).
///
///   🔴 **Le compte final est `1`, PAS `0` — et c'est PLUS FORT.** Le témoin est
///   **rejoué dans la portée même** du test (2) : l'espion vaut donc déjà `1`
///   **avant** que l'examen ne commence. Le `1` final se lit « **le SEUL appel
///   est celui du témoin ; l'examen n'en a ajouté AUCUN** » — toute écriture SRS
///   de l'examen ferait **2**. Un `isEmpty` exigerait un espion **vierge**,
///   c'est-à-dire **non prouvé captant dans cette portée** : précisément le
///   défaut su-4. **La déviation vis-à-vis du croquis de la story (« puis
///   `isEmpty` ») est DÉLIBÉRÉE et RENFORCE l'AC.**
///
///   🚫 **N'« alignez » PAS `hasLength(1)` sur `isEmpty`.** Le test rougirait (à
///   cause du témoin), et le « corriger » en supprimant le témoin rendrait
///   l'assertion **infalsifiable** — un `isEmpty` sur un espion branché sur
///   **rien** : la régression su-4 restaurée, **verte**, à l'endroit même écrit
///   pour la tuer.
///
/// 🚫 **Aucun de ces tests ne s'intitule « `reviewCard` jamais atteint »** : ce
/// serait affirmer ce qu'ils ne mesurent pas.
///
/// - **(c) AUTOMATIQUE** : `z_widgets_purity_test.dart` scanne
///   `lib/src/presentation/**` **récursivement** et capte donc
///   `z_list_session_view.dart` **sans édition**. 🚫 **Aucune garde parallèle
///   n'est créée ici** — on étend/consomme les gardes existantes.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_exam_harness.dart';

/// Espion d'écriture SRS — 🔒 `ZSessionReviewer` est un **typedef de FONCTION** :
/// l'espion EST le callback.
class SpyReviewer {
  final List<int> calls = <int>[];

  Future<ZResult<ZRepetitionInfo>> call({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    calls.add(quality);
    return Right<ZFailure, ZRepetitionInfo>(
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
    );
  }
}

/// Symboles d'ÉCRITURE SRS interdits dans la vue.
///
/// La ponctuation d'appel (`.reviewCard(`) est incluse pour ne PAS faux-positiver
/// sur de la prose de dartdoc qui doit pouvoir **nommer** ces concepts : on
/// interdit l'**APPEL**, pas le mot.
const List<String> _bannedSrsSymbols = <String>[
  'ZSessionReviewer',
  'ZSrsScheduler',
  'ZSm2Scheduler',
  'ZRepetitionStore',
  '.reviewCard(',
  '.apply(',
];

const String _viewPath = 'lib/src/presentation/z_list_session_view.dart';

void main() {
  group('🔴 AC3 (a) — axe STRUCTURE : la vue n\'a AUCUN seam d\'écriture', () {
    test('🔴 le ctor de `ZListSessionView` n\'accepte NI reviewer, NI '
        'scheduler, NI store', () {
      final file = File(_viewPath);
      // ⚠️ **Contre-preuve R12, NON NÉGOCIABLE** : sans `existsSync`, un fichier
      // renommé rendrait ce scan **VIDE et VERT** — une preuve d'absence
      // **FAUSSE**, la pire espèce.
      expect(
        file.existsSync(),
        isTrue,
        reason: 'source introuvable: $_viewPath (cwd=${Directory.current.path}) '
            '— cette garde ne scannerait plus rien et serait verte pour de '
            'mauvaises raisons',
      );
      final src = file.readAsStringSync();
      expect(src, isNotEmpty, reason: 'source vide — rien scanné');

      final start = src.indexOf('const ZListSessionView({');
      expect(start, greaterThanOrEqualTo(0), reason: 'ctor introuvable');
      final end = src.indexOf('});', start);
      expect(end, greaterThan(start), reason: 'fin de ctor introuvable');
      final ctor = src.substring(start, end);

      // Contre-preuve : le scan voit bien le VRAI ctor.
      expect(
        ctor.contains('this.cards'),
        isTrue,
        reason: 'le scan ne voit pas le ctor réel',
      );

      // 🔒 Insensible à la CASSE (patron `z_no_srs_write_in_non_srs_modes`) :
      // `Reviewer`/`srsStore` ne doivent pas passer sous le radar.
      final lower = ctor.toLowerCase();
      for (final banned in <String>['reviewer', 'scheduler', 'store']) {
        expect(
          lower.contains(banned),
          isFalse,
          reason: '🔴 AD-23/AD-33 : un `$banned` est apparu au ctor de '
              '`ZListSessionView` ⇒ l\'examen blanc peut désormais écrire du '
              'SRS. Le régime « aucune écriture » cesse d\'être STRUCTUREL.',
        );
      }
    });

    test('🔴 le CORPS de la vue ne contient AUCUN symbole d\'écriture SRS', () {
      final file = File(_viewPath);
      expect(file.existsSync(), isTrue, reason: 'source introuvable: $_viewPath');
      final lines = file.readAsLinesSync();
      expect(lines, isNotEmpty, reason: 'source vide — rien scanné');

      final violations = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        // La doc doit pouvoir NOMMER les concepts SRS (contraste AD-23).
        if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
        for (final symbol in _bannedSrsSymbols) {
          if (lines[i].contains(symbol)) {
            violations.add('$_viewPath:${i + 1} → $symbol :: ${lines[i].trim()}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '🔴 symbole(s) d\'écriture SRS dans l\'UI d\'examen blanc :\n'
            '${violations.join('\n')}',
      );
    });
  });

  group('🔴 AC3 (b) — axe COMPORTEMENT : le chemin RÉEL, avec témoin positif', () {
    testWidgets(
      '🔴 (1) TÉMOIN POSITIF — cet espion SAIT capter : branché sur '
      '`ZStudySessionEngine(spaced)`, une révision l\'appelle EXACTEMENT 1 fois',
      (tester) async {
        // 🎯 **Sans ce test, le `hasLength(1)` du test (2) ne vaut RIEN** :
        // c'est la leçon su-4 (espion jamais branché ⇒ assertion
        // infalsifiable). C'est CE témoin qui fait valoir « 1 » au compteur —
        // d'où un final à `1`, et non à `0`.
        final spy = SpyReviewer();
        final engine = ZStudySessionEngine(
          queue: const <ZSessionItem>[
            ZSessionItem(flashcardId: 'a', folderId: 'f'),
          ],
          reviewer: spy.call,
          mode: ZReviewMode.spaced,
        );
        addTearDown(engine.dispose);

        await engine.grade(5);

        expect(
          spy.calls,
          hasLength(1),
          reason: '🔴 l\'espion ne capte plus : le seam `ZSessionReviewer` a été '
              'renommé ou l\'écriture SRS a disparu du moteur SRS. Tant que ce '
              'test ne passe pas, l\'assertion à ZÉRO ci-dessous ne prouve RIEN.',
        );
      },
    );

    testWidgets(
      '🔴 (2) un examen blanc JOUÉ DE BOUT EN BOUT via `ZListSessionView` '
      'laisse ce MÊME espion à SON COMPTE DE TÉMOIN (1) : l\'examen n\'ajoute '
      'AUCUN appel — et il n\'existe AUCUN paramètre où le brancher (c\'est '
      '(a) qui porte la garantie)',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // 🔒 Le MÊME espion, dans la MÊME portée, dont (1) vient de prouver
        // qu'il CAPTE. S'il reste vide ici, ce n'est pas parce qu'il est sourd.
        final spy = SpyReviewer();
        final witness = ZStudySessionEngine(
          queue: const <ZSessionItem>[
            ZSessionItem(flashcardId: 'a', folderId: 'f'),
          ],
          reviewer: spy.call,
          mode: ZReviewMode.spaced,
        );
        addTearDown(witness.dispose);
        await witness.grade(5);
        expect(spy.calls, hasLength(1), reason: 'témoin positif préalable');

        // ⚠️ `ZListSessionView` n'accepte AUCUN `reviewer` : il n'y a
        // littéralement AUCUNE ligne à écrire pour brancher `spy` sur l'examen.
        // Cette impossibilité EST l'AC3(a).
        final cards = <ZFlashcard>[examCard('Q1'), examCard('Q2')];
        await tester.pumpWidget(ExamHost(cards: cards));

        for (final q in cards) {
          await tester.tap(
            find.descendant(
              of: find.ancestor(
                of: find.text(q.question),
                matching: find.byType(ZFlashcardAnswerInput),
              ),
              matching: find.byKey(EK.answerTrue),
            ),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(ZListSessionView.submitKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ZListSessionView.confirmKey));
        await tester.pumpAndSettle();

        final host = tester.state<ExamHostState>(find.byType(ExamHost));
        // Contre-preuve : l'examen a RÉELLEMENT été joué (sinon « zéro écriture »
        // serait vrai par vacuité — un examen jamais commencé n'écrit rien).
        expect(host.engine.isSubmitted, isTrue, reason: 'examen non soumis');
        expect(host.engine.result!.total, 2, reason: 'les 2 réponses comptées');

        expect(
          spy.calls,
          hasLength(1),
          reason: '🔴 l\'examen blanc a fait progresser le SRS : le seul appel '
              'attendu est celui du TÉMOIN (`ZStudySessionEngine`). Tout appel '
              'supplémentaire vient de l\'examen ⇒ AD-23 violé.',
        );
      },
    );
  });
}
