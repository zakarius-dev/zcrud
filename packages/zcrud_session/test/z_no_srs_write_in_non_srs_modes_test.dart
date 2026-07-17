/// 🎯 AC4 (SU-4) — **AUCUN mode non-SRS n'atteint `reviewCard`** (AD-33/AD-34).
///
/// L'AC **centrale** de la story, prouvée par une **EXÉCUTION COMPLÈTE** : pour
/// chaque mode non-SRS (`list`, `cramming`, `test`, `whiteExam`), la session est
/// pilotée **jusqu'à `isComplete`/`submitted`** — pas un seul tour de boucle — et
/// l'espion `ZSessionReviewer` doit enregistrer **0 appel**.
///
/// 🔴 **COMPLÉMENTARITÉ — à ne PAS confondre (et surtout à ne pas dupliquer).**
/// - `z_linear_no_srs_test.dart` / `z_white_exam_no_srs_test.dart` (su-1) sont
///   des gardes de **SOURCE** : le fichier ne mentionne aucun symbole SRS.
/// - **Ce fichier** est une garde de **COMPORTEMENT** : une exécution complète
///   n'appelle rien.
///
/// Les deux sont nécessaires et **aucun ne remplace l'autre** : une garde de
/// source ne prouve pas une exécution (un appel pourrait transiter par un
/// helper) ; une exécution ne prouve pas l'absence d'une porte dérobée sur un
/// chemin non emprunté par le test. su-4 **n'y touche pas** — il ajoute l'axe
/// manquant.
///
/// 🔴 **CE QUE CE FICHIER PROUVE — exactement, et rien de plus.**
///
/// Une version antérieure de ce fichier construisait un `_SpyReviewer`, pilotait
/// la session, puis assérait `expect(spy.calls, isEmpty)` — et **affirmait en
/// dartdoc** « le **MÊME** espion, dans le **MÊME** test ». **C'était faux, et
/// l'assertion était STRUCTURELLEMENT INFALSIFIABLE** (mesuré) :
/// - l'espion n'était **jamais branché** — ni `ZLinearSessionState` ni
///   `ZWhiteExamSessionEngine` n'ont de paramètre par lequel le passer ;
/// - `expect(spy.calls, isEmpty)` se lisait donc : « *une liste fraîche, que rien
///   au monde ne peut alimenter, est vide* » — **aucune** modification du code de
///   prod ne pouvait la faire rougir ;
/// - **preuve décisive** : supprimer l'INTÉGRALITÉ de l'exécution de session
///   laissait les 4 tests « parcours INTÉGRAL » **VERTS**. Le parcours ne
///   contribuait en rien à l'assertion qu'il était censé fonder ;
/// - le témoin positif invoqué était une **autre instance**, dans un **autre
///   test**, sur un **autre runtime**.
///
/// C'était le défaut **D8 de su-3** (code décoratif adossé à un test incapable de
/// rougir) — celui-là même que su-4 a correctement diagnostiqué et corrigé pour
/// le jeton `_generation`, sans le retourner contre cet espion-ci.
///
/// Les **deux axes réellement porteurs**, désormais séparés et nommés :
/// 1. **COMPORTEMENT** — les runtimes non-SRS **terminent** leur session, sur les
///    **deux branches** du reducer. C'est vrai, c'est utile, et c'est **tout** ce
///    que l'exécution prouve.
/// 2. **STRUCTURE** — l'absence d'écriture SRS est prouvée là où elle est réelle :
///    **aucun runtime non-SRS n'a de seam par lequel écrire**. Une « absence » se
///    prouve sur la source ; elle ne s'affirme pas. Ce test lit les **ctors
///    RÉELS** sur disque (patron du test (4) de `z_session_runtime_mapping_test`)
///    ⇒ il **ROUGIT** si un `reviewer` apparaît — l'injection R3-I6 exactement.
///
/// 🔴 **Le témoin positif reste OBLIGATOIRE** : sans lui, « 0 appel » resterait
/// vert même si tout le câblage SRS avait disparu. Il est réel et il est mesuré
/// (il rougit sur R3-I4) — c'est lui qui prouve que la classe d'espion **SAIT**
/// être appelée par la voie légitime (`spaced`/`learn` →
/// `ZStudySessionEngine.grade`).
///
/// ⚠️ **Portée déclarée honnêtement** : ce test pilote les **runtimes** (couche
/// domaine). Le fait qu'aucun *widget* n'atteigne le seam est gardé ailleurs
/// (`z_widgets_purity_test.dart` bannit `ZSessionReviewer`/`.reviewCard(` de
/// `lib/src/presentation/**` ; `z_swipe_never_grades_test.dart` pour le swipe).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show Right, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZRepetitionInfo;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

/// Espion d'écriture SRS — il **ENREGISTRE**.
///
/// 🚫 Ce n'est **PAS** un `ZSessionReviewer` no-op offert à la prod : ce serait
/// la porte dérobée qu'AD-34 interdit nommément (un mode non-SRS servi par le
/// moteur SRS sous couvert d'un reviewer inerte). C'est un instrument de test,
/// dont on prouve *dans le même fichier* qu'il SAIT être appelé.
class _SpyReviewer {
  final List<({String flashcardId, int quality})> calls =
      <({String flashcardId, int quality})>[];

  Future<ZResult<ZRepetitionInfo>> call({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    calls.add((flashcardId: flashcardId, quality: quality));
    return Right<Never, ZRepetitionInfo>(
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
    );
  }
}

List<ZSessionItem> _queue() => const <ZSessionItem>[
      ZSessionItem(flashcardId: 'f1', folderId: 'd1'),
      ZSessionItem(flashcardId: 'f2', folderId: 'd1'),
      ZSessionItem(flashcardId: 'f3', folderId: 'd1'),
    ];

void main() {
  group(
      '🎯 AC4 (axe STRUCTURE) — aucun runtime non-SRS n\'a de seam par lequel '
      'écrire (AD-33/AD-34)', () {
    // 🎯 **L'AC CENTRALE, et le SEUL axe qui puisse la falsifier.**
    //
    // L'absence d'écriture SRS en mode non-SRS n'est pas un comportement : c'est
    // une propriété du **TYPE** (AD-34 — « le régime d'écriture est une propriété
    // du type »). Un espion ne peut donc pas la mesurer : il n'y a rien où le
    // brancher. C'est **précisément ce qui rendait `expect(spy.calls, isEmpty)`
    // infalsifiable** (cf. dartdoc de librairie).
    //
    // On prouve donc l'absence là où elle vit — **sur la source des ctors
    // RÉELS** —, comme le fait déjà le test (4) de `z_session_runtime_mapping`.
    // 🔴 Ce test ROUGIT sur l'injection R3-I6 (ajouter un paramètre `reviewer` à
    // un runtime non-SRS), là où l'espion restait vert.

    /// Lit le ctor RÉEL sur disque, entre [from] et [to].
    String ctorOf(String path, String from, String to) {
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'introuvable: $path (cwd=${Directory.current.path}) — cette '
              'garde ne scanne plus rien et serait verte pour de mauvaises '
              'raisons');
      final src = file.readAsStringSync();
      final start = src.indexOf(from);
      final end = src.indexOf(to);
      expect(start, greaterThanOrEqualTo(0), reason: 'ctor introuvable: $from');
      expect(end, greaterThan(start), reason: 'fin de ctor introuvable: $to');
      return src.substring(start, end);
    }

    test(
        '🔴 `ZLinearSessionState` : son ctor n\'accepte AUCUN `reviewer` '
        '(list/cramming)', () {
      final ctor = ctorOf(
        'lib/src/domain/z_linear_session_state.dart',
        'ZLinearSessionState({',
        '_state = ',
      );
      // Contre-preuve : le scan voit bien un vrai ctor.
      expect(ctor.contains('queue'), isTrue,
          reason: 'le scan ne voit pas le ctor réel');
      expect(ctor.toLowerCase().contains('reviewer'), isFalse,
          reason: '🔴 AD-34 : un `reviewer` est apparu au ctor du runtime '
              'linéaire ⇒ `list`/`cramming` peuvent désormais écrire du SRS. Le '
              'régime « aucune écriture » cesse d\'être STRUCTUREL.');
    });

    test(
        '🔴 `ZWhiteExamSessionEngine` : son ctor n\'accepte AUCUN `reviewer` '
        '(test/whiteExam)', () {
      final ctor = ctorOf(
        'lib/src/domain/z_white_exam_session_engine.dart',
        'ZWhiteExamSessionEngine({',
        '_state = ZWhiteExamState(',
      );
      expect(ctor.contains('queue'), isTrue,
          reason: 'le scan ne voit pas le ctor réel');
      expect(ctor.toLowerCase().contains('reviewer'), isFalse,
          reason: '🔴 AD-34 : un `reviewer` est apparu au ctor de l\'examen '
              'blanc ⇒ `test`/`whiteExam` peuvent désormais écrire du SRS.');
    });

    test(
        '🔴 …et le moteur SRS, LUI, en a un — sans quoi les deux gardes '
        'ci-dessus seraient vertes pour de mauvaises raisons', () {
      // 🎯 **Contre-témoin de la garde STRUCTURELLE** : si `reviewer` avait été
      // renommé partout, les deux `isFalse` ci-dessus passeraient sans rien
      // prouver. Ce test ancre le vocabulaire sur le seul runtime qui écrit.
      final ctor = ctorOf(
        'lib/src/domain/z_study_session_engine.dart',
        'ZStudySessionEngine({',
        '_state = ',
      );
      expect(ctor.toLowerCase().contains('reviewer'), isTrue,
          reason: '🔴 le moteur SRS n\'a plus de `reviewer` : soit le seam a été '
              'renommé (⇒ les gardes non-SRS ne prouvent plus rien), soit '
              'l\'écriture SRS a disparu (AD-33)');
    });
  });

  group(
      '🎯 AC4 (axe COMPORTEMENT) — les runtimes non-SRS TERMINENT leur session, '
      'sur les DEUX branches du reducer', () {
    // ⚠️ **Portée déclarée honnêtement** : ces tests prouvent que les reducers
    // terminent — **PAS** « reviewCard n'est jamais atteint » (aucun espion n'est
    // branchable : c'est l'axe STRUCTURE ci-dessus qui porte cette preuve). Une
    // version antérieure les intitulait « reviewCard JAMAIS atteint » et
    // assérait un espion incâblable : **fausse affirmation de conformité**.
    for (final mode in ZReviewMode.values.where(
      (m) => zSessionRuntimeForMode(m) != ZSessionRuntimeKind.srsEngine,
    )) {
      test('🔴 mode `${mode.name}` : parcours INTÉGRAL jusqu\'à complétion', () {
        switch (zSessionRuntimeForMode(mode)) {
          case ZSessionRuntimeKind.linear:
            final runtime = ZLinearSessionState(queue: _queue(), mode: mode);
            addTearDown(runtime.dispose);
            // 🔒 Session pilotée JUSQU'À COMPLÉTION (jamais un seul tour). Le
            // garde-fou de boucle empêche un test de tourner à l'infini si un
            // reducer régressait — il n'est pas la condition d'arrêt.
            var guard = 0;
            while (!runtime.isComplete) {
              // Alterne réussite (consomme) et lapse (re-boucle en cramming) :
              // on emprunte les DEUX branches réelles du reducer.
              runtime.answer(guard.isEven ? 5 : 0);
              expect(guard++, lessThan(100),
                  reason: 'la session `${mode.name}` ne se termine pas');
            }
            expect(runtime.isComplete, isTrue);

          case ZSessionRuntimeKind.whiteExam:
            final runtime = ZWhiteExamSessionEngine(queue: _queue());
            addTearDown(runtime.dispose);
            runtime.start();
            var guard = 0;
            while (runtime.current != null) {
              runtime.answer(guard.isEven ? 5 : 0);
              expect(guard++, lessThan(100),
                  reason: 'la session `${mode.name}` ne se termine pas');
            }
            // Jusqu'au BOUT : la soumission est la phase où un scoring a lieu —
            // c'est le moment le plus « tentant » pour écrire du SRS.
            runtime.submit();
            expect(runtime.phase, ZWhiteExamPhase.submitted);
            expect(runtime.result, isNotNull);

          case ZSessionRuntimeKind.srsEngine:
            fail('mode non-SRS `${mode.name}` routé vers le moteur SRS');
        }
        // 🚫 **Aucun `expect(spy.calls, isEmpty)` ici** — et c'est délibéré :
        // l'espion n'est branchable à RIEN (les ctors n'ont pas de `reviewer`),
        // donc l'assertion serait vraie quoi qu'il arrive. Retirer une preuve
        // vide vaut mieux que l'afficher : c'est le traitement que su-4 a
        // lui-même appliqué, à raison, au jeton `_generation`.
        // L'absence d'écriture est prouvée par l'axe STRUCTURE ci-dessus.
      });
    }

    test(
        '🔴 TÉMOIN POSITIF — sans lui, les tests ci-dessus sont VIDES : '
        '`spaced`/`learn` atteignent bien le seam, 1× par carte notée', () async {
      for (final mode in ZReviewMode.values.where(
        (m) => zSessionRuntimeForMode(m) == ZSessionRuntimeKind.srsEngine,
      )) {
        // ⚠️ Le MÊME espion que ci-dessus (même classe, même voie d'appel) :
        // c'est ce qui prouve qu'un `isEmpty` là-haut MESURE quelque chose.
        // ⚠️ **La MÊME CLASSE d'espion, par la MÊME voie d'appel** — ce qui est
        // exactement ce que ce témoin prouve, ni plus ni moins. (Une version
        // antérieure de la dartdoc affirmait « le MÊME espion, dans le MÊME
        // test » : c'était faux — autre instance, autre test, autre runtime.)
        final spy = _SpyReviewer();
        final engine = ZStudySessionEngine(
          queue: _queue(),
          reviewer: spy.call,
          mode: mode,
        );
        addTearDown(engine.dispose);

        // Trois notations réussies ⇒ trois cartes consommées, trois écritures.
        await engine.grade(5);
        await engine.grade(5);
        await engine.grade(5);

        expect(engine.isComplete, isTrue);
        expect(
          spy.calls.map((c) => c.flashcardId).toList(),
          <String>['f1', 'f2', 'f3'],
          reason: '🔴 mode `${mode.name}` : le seam doit être atteint EXACTEMENT '
              'une fois par carte notée, sur la carte COURANTE. Si ceci ne '
              'passe pas, l\'espion ne sait pas être appelé ⇒ les preuves '
              '« 0 appel » ci-dessus ne valent RIEN',
        );
      }
    });
  });
}
