/// **Filet d'audit de seams** — `ZStudySeam` / `ZStudySeamReport` /
/// `ZStudySeamAuditPolicy` / `auditSeams`.
///
/// ## Le défaut visé
///
/// Le montage énuméré (`.wired`) ferme la classe « un seam oublié en silence »
/// pour les hôtes qui l'adoptent. Ceux qui restent au **montage à plat** — la
/// majorité — n'ont toujours aucun signal : l'écran s'affiche, simplement ce
/// n'est pas celui qu'on voulait.
///
/// ## Ce que ces gardes mesurent
///
/// * **G6** — l'audit ne ment pas : montage vide ⇒ 24 manquants ; chaque seam
///   posé **individuellement** (24 cas, pas un échantillon) apparaît dans
///   `provided` et disparaît de `missing` ; une renonciation qui nomme un seam
///   POSÉ est une erreur du rapport (`invalidWaivers`).
/// * **G6b** — sous `.wired`, `missing` est vide **par construction**, y
///   compris avec `ZStudySessionWiring.none()` : un `null` énuméré est une
///   décision écrite.
/// * **G6c** — cohérence enum ↔ wiring, mesurée sur la SOURCE : un 25ᵉ seam
///   sans valeur d'enum fait rougir.
/// * **G7** — AD-10 : sans politique, zéro `FlutterError.reportError` ; avec
///   politique et montage incomplet, **exactement un** rapport nommant les
///   seams manquants, **et la session s'affiche quand même** (arbre identique,
///   nœud pour nœud) ; avec politique et montage complet, zéro rapport ; le
///   site d'appel vit sous `assert` (debug seul).
@TestOn('vm')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/lotw1_seams.dart';
import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';
import 'lotw1_session_wiring_test.dart' show lotW1Wiring, wiringFields;

String hostSource() =>
    zsrc.strippedOf('lib/src/presentation/z_study_session_host.dart');

String auditSource() =>
    zsrc.strippedOf('lib/src/presentation/z_study_session_seam_audit.dart');

Widget _wrap(Widget child) =>
    MaterialApp(home: ZcrudScope(child: Scaffold(body: child)));

/// Arbre RÉELLEMENT monté, nœud pour nœud.
List<String> treeDump(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// Le montage **vide** : deux paramètres requis, aucun seam.
ZStudySessionHost emptyHost({ZStudySeamAuditPolicy? seamAudit}) =>
    ZStudySessionHost(
      mode: ZReviewMode.list,
      queue: writtenCards(2),
      seamAudit: seamAudit,
    );

/// Un montage à plat qui pose **exactement un** seam — celui demandé.
///
/// Les sentinelles viennent du jeu partagé du montage énuméré : une seconde
/// famille de valeurs prouverait l'audit contre elle-même.
ZStudySessionHost hostWithOnly(
  ZStudySeam seam, {
  ZStudySeamAuditPolicy? seamAudit,
}) {
  // `optIn` porte les seams retombés par défaut dans le harnais : « posé
  // SEUL » ne peut pas signifier « posé, sauf ceux-là ».
  final LotW1Seams s =
      LotW1Seams(scene: W1Scene.hote, optIn: LotW1Seams.optional);
  return ZStudySessionHost(
    mode: ZReviewMode.list,
    queue: writtenCards(2),
    seamAudit: seamAudit,
    reviewer: seam == ZStudySeam.reviewer ? s.reviewer : null,
    cardBuilder: seam == ZStudySeam.cardBuilder ? s.cardBuilder : null,
    cardSlotBuilder:
        seam == ZStudySeam.cardSlotBuilder ? s.cardSlotBuilder : null,
    contentBuilder: seam == ZStudySeam.contentBuilder ? s.contentBuilder : null,
    questionTypeBadgeBuilder: seam == ZStudySeam.questionTypeBadgeBuilder
        ? s.questionTypeBadgeBuilder
        : null,
    instructionBanner:
        seam == ZStudySeam.instructionBanner ? s.instructionBanner : null,
    evaluationPort:
        seam == ZStudySeam.evaluationPort ? s.evaluationPort : null,
    hintPort: seam == ZStudySeam.hintPort ? s.hintPort : null,
    onQualitySelected:
        seam == ZStudySeam.onQualitySelected ? s.onQualitySelected : null,
    qualityColorKeyFor:
        seam == ZStudySeam.qualityColorKeyFor ? s.qualityColorKeyFor : null,
    qualityPreviewLabelFor: seam == ZStudySeam.qualityPreviewLabelFor
        ? s.qualityPreviewLabelFor
        : null,
    qualityPreviewLabelForCard:
        seam == ZStudySeam.qualityPreviewLabelForCard
            ? s.qualityPreviewLabelForCard
            : null,
    onSource: seam == ZStudySeam.onSource ? s.onSource : null,
    headerBuilder: seam == ZStudySeam.headerBuilder ? s.headerBuilder : null,
    counterBuilder: seam == ZStudySeam.counterBuilder ? s.counterBuilder : null,
    gradingBuilder: seam == ZStudySeam.gradingBuilder ? s.gradingBuilder : null,
    summaryBuilder: seam == ZStudySeam.summaryBuilder ? s.summaryBuilder : null,
    emptyBuilder: seam == ZStudySeam.emptyBuilder ? s.emptyBuilder : null,
    celebrationBuilder:
        seam == ZStudySeam.celebrationBuilder ? s.celebrationBuilder : null,
    labels: seam == ZStudySeam.labels ? s.labels : null,
    onSessionEnd: seam == ZStudySeam.onSessionEnd ? s.onSessionEnd : null,
    onExit: seam == ZStudySeam.onExit ? s.onExit : null,
    indexController:
        seam == ZStudySeam.indexController ? s.indexController : null,
    preset: seam == ZStudySeam.preset ? s.preset : null,
  );
}

/// Capture les rapports d'erreur émis pendant [body] — et **eux seuls**.
Future<List<FlutterErrorDetails>> captureErrors(
  Future<void> Function() body,
) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // G6 — l'audit ne ment pas
  // ═════════════════════════════════════════════════════════════════════════
  group('🧾 G6 — l\'audit dit EXACTEMENT ce que le montage porte', () {
    test('l\'énumération porte les 24 seams du montage', () {
      expect(ZStudySeam.values, hasLength(24));
    });

    test('🔴 montage VIDE : les 24 seams manquent, aucun n\'est fourni', () {
      final ZStudySeamReport r = emptyHost().auditSeams();
      expect(r.missing, hasLength(24),
          reason: '🔴 un audit qui ne voit pas les 24 trous ne mesure rien');
      expect(r.missing, ZStudySeam.values.toSet());
      expect(r.provided, isEmpty);
      expect(r.waived, isEmpty);
      expect(r.invalidWaivers, isEmpty);
      expect(r.isComplete, isFalse);
    });

    test('🔴 une renonciation NOMINATIVE retire son seam des manquants', () {
      final ZStudySeamReport r =
          emptyHost().auditSeams(waived: const <ZStudySeam>{
        ZStudySeam.hintPort,
      });
      expect(r.missing, hasLength(23));
      expect(r.missing, isNot(contains(ZStudySeam.hintPort)));
      expect(r.waived, contains(ZStudySeam.hintPort));
      expect(r.isComplete, isFalse,
          reason: 'renoncer à UN seam ne rend pas le montage complet');
    });

    for (final ZStudySeam seam in ZStudySeam.values) {
      test('`${seam.name}` posé SEUL : fourni, et retiré des manquants', () {
        final ZStudySeamReport r = hostWithOnly(seam).auditSeams();
        expect(r.provided, contains(seam),
            reason: '🔴 le seam posé n\'est pas vu — l\'audit lit à côté');
        expect(r.provided, hasLength(1),
            reason: '🔴 un seam NON posé est compté comme fourni');
        expect(r.missing, isNot(contains(seam)));
        expect(r.missing, hasLength(23));
      });
    }

    test('🔴 une renonciation qui nomme un seam POSÉ est une ERREUR', () {
      final ZStudySeamReport r = hostWithOnly(ZStudySeam.hintPort)
          .auditSeams(waived: const <ZStudySeam>{ZStudySeam.hintPort});
      expect(r.invalidWaivers, contains(ZStudySeam.hintPort),
          reason: '🔴 une exemption INUTILE passe inaperçue : la déclaration '
              'ne décrit plus le montage');
      expect(r.provided, contains(ZStudySeam.hintPort));
      expect(r.waived, isNot(contains(ZStudySeam.hintPort)),
          reason: 'une renonciation inutile n\'est pas une renonciation');
      expect(r.isComplete, isFalse,
          reason: '🔴 un rapport qui se déclare complet malgré une exemption '
              'inutile ne signale rien');
    });

    test('le rendu nomme chaque seam manquant ET son défaut', () {
      final String text = emptyHost().auditSeams().toString();
      for (final ZStudySeam seam in ZStudySeam.values) {
        expect(text, contains(seam.name),
            reason: '🔴 `${seam.name}` manquant mais non nommé : le message '
                'n\'aide personne');
        expect(text, contains(seam.fallback),
            reason: '🔴 le défaut de `${seam.name}` n\'est pas dit — l\'hôte '
                'ne sait pas ce que le socle fait à sa place');
      }
    });

    test('le rendu nomme les renonciations INUTILES', () {
      final String text = hostWithOnly(ZStudySeam.hintPort)
          .auditSeams(waived: const <ZStudySeam>{ZStudySeam.hintPort})
          .toString();
      expect(text, contains('hintPort'));
      expect(text.toLowerCase(), contains('inutile'));
    });

    test('un rapport SANS trou se déclare complet', () {
      const ZStudySeamReport r = ZStudySeamReport(
        provided: <ZStudySeam>{ZStudySeam.reviewer},
        waived: <ZStudySeam>{ZStudySeam.hintPort},
        missing: <ZStudySeam>{},
      );
      expect(r.isComplete, isTrue);
      expect(r.toString(), isNotEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // G6b — `.wired` ⇒ `missing` vide par construction
  // ═════════════════════════════════════════════════════════════════════════
  group('🚚 G6b — sous `.wired`, un `null` est une DÉCISION, jamais un trou',
      () {
    test('🔴 `.none()` : tout est renoncé, RIEN ne manque', () {
      final ZStudySeamReport r = ZStudySessionHost.wired(
        wiring: const ZStudySessionWiring.none(),
        mode: ZReviewMode.list,
        queue: writtenCards(2),
      ).auditSeams();
      expect(r.missing, isEmpty,
          reason: '🔴 le montage énuméré a NOMMÉ chaque seam, `null` compris : '
              'l\'audit ne peut pas le traiter comme un oubli');
      expect(r.waived, ZStudySeam.values.toSet());
      expect(r.provided, isEmpty);
      expect(r.isComplete, isTrue);
    });

    test('🔴 wiring COMPLET : tout est fourni, rien n\'est renoncé', () {
      final ZStudySeamReport r = ZStudySessionHost.wired(
        // `optIn` porte les seams que le harnais laisse retombés par défaut :
        // « COMPLET » veut dire les 24, sans exception.
        wiring: lotW1Wiring(
          LotW1Seams(scene: W1Scene.hote, optIn: LotW1Seams.optional),
        ),
        mode: ZReviewMode.list,
        queue: writtenCards(2),
      ).auditSeams();
      expect(r.provided, ZStudySeam.values.toSet(),
          reason: '🔴 un seam du wiring n\'atteint pas l\'audit');
      expect(r.missing, isEmpty);
      expect(r.waived, isEmpty);
      expect(r.isComplete, isTrue);
    });

    test('wiring PARTIEL : les seams nuls sont renoncés, aucun ne manque', () {
      final ZStudySeamReport r = ZStudySessionHost.wired(
        wiring: lotW1Wiring(
          LotW1Seams(
            scene: W1Scene.hote,
            omit: <String>{'hintPort', 'labels'},
            optIn: LotW1Seams.optional,
          ),
        ),
        mode: ZReviewMode.list,
        queue: writtenCards(2),
      ).auditSeams();
      expect(r.missing, isEmpty);
      expect(r.waived,
          <ZStudySeam>{ZStudySeam.hintPort, ZStudySeam.labels});
      expect(r.provided, hasLength(22));
    });

    test('🔴 le montage À PLAT, lui, N\'est PAS exempté (non-vacuité)', () {
      expect(emptyHost().auditSeams().missing, hasLength(24),
          reason: '🔴 si le régime à plat était traité comme énuméré, G6b '
              'serait vert sans rien mesurer');
    });

    test('une renonciation inutile reste une erreur SOUS `.wired`', () {
      final ZStudySeamReport r = ZStudySessionHost.wired(
        wiring: lotW1Wiring(LotW1Seams(scene: W1Scene.hote)),
        mode: ZReviewMode.list,
        queue: writtenCards(2),
      ).auditSeams(waived: const <ZStudySeam>{ZStudySeam.hintPort});
      expect(r.invalidWaivers, contains(ZStudySeam.hintPort));
      expect(r.isComplete, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // G6c — cohérence enum ↔ wiring, mesurée sur la SOURCE
  // ═════════════════════════════════════════════════════════════════════════
  group('🧮 G6c — une valeur d\'enum par champ du wiring, mêmes noms', () {
    test('l\'extraction aboutit', () {
      expect(wiringFields(hostSource()), hasLength(24));
    });

    test('🔴 l\'ensemble des valeurs EST l\'ensemble des champs', () {
      final Set<String> fields = wiringFields(hostSource()).toSet();
      final Set<String> values =
          ZStudySeam.values.map((ZStudySeam s) => s.name).toSet();
      expect(values.difference(fields), isEmpty,
          reason: '🔴 valeur d\'enum sans champ de montage : l\'audit réclame '
              'un seam qui n\'existe pas');
      expect(fields.difference(values), isEmpty,
          reason: '🔴 seam du montage SANS valeur d\'enum : il ne sera jamais '
              'audité, et son oubli restera invisible');
    });

    test('🔴 le scanner MORD : un 25ᵉ champ de wiring est signalé', () {
      final Set<String> fields = wiringFields(
        hostSource().replaceFirst(
          'final ZSessionReviewer? reviewer;',
          'final ZSessionReviewer? reviewer;\n  final ZSomePort? newSeam;',
        ),
      ).toSet();
      expect(fields, contains('newSeam'), reason: 'mutation non appliquée');
      expect(
          fields.difference(
              ZStudySeam.values.map((ZStudySeam s) => s.name).toSet()),
          contains('newSeam'),
          reason: 'sans cela, G6c resterait verte sur un seam non audité');
    });

    test('chaque valeur porte un défaut NON VIDE et distinct de son nom', () {
      for (final ZStudySeam seam in ZStudySeam.values) {
        expect(seam.fallback, isNotEmpty);
        expect(seam.fallback, isNot(seam.name));
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // G7 — AD-10 : un signal, jamais une chute ; et le silence par défaut
  // ═════════════════════════════════════════════════════════════════════════
  group('🛟 G7 — le filet SIGNALE, il ne fait jamais tomber l\'écran', () {
    testWidgets('🔴 SANS politique : ZÉRO rapport, montage vide compris',
        (tester) async {
      useTallSurface(tester);
      final List<FlutterErrorDetails> caught = await captureErrors(() async {
        await tester.pumpWidget(_wrap(emptyHost()));
        await tester.pumpAndSettle();
      });
      expect(caught, isEmpty,
          reason: '🔴 un hôte qui n\'a rien demandé est averti quand même');
      expect(find.byType(ZStudySessionHost), findsOneWidget);
    });

    testWidgets('🔴 AVEC politique et montage incomplet : EXACTEMENT un rapport',
        (tester) async {
      useTallSurface(tester);
      final List<FlutterErrorDetails> caught = await captureErrors(() async {
        await tester.pumpWidget(_wrap(
          emptyHost(seamAudit: const ZStudySeamAuditPolicy()),
        ));
        await tester.pumpAndSettle();
      });
      expect(caught, hasLength(1),
          reason: '🔴 zéro rapport (le filet est mort) ou plusieurs (l\'hôte '
              'est noyé à chaque rebuild)');
      final String text = caught.single.exception.toString();
      for (final ZStudySeam seam in ZStudySeam.values) {
        expect(text, contains(seam.name),
            reason: '🔴 `${seam.name}` manque et n\'est pas nommé');
      }
      expect(caught.single.library, 'zcrud_study');
    });

    testWidgets('🔴 …et la session s\'affiche QUAND MÊME, nœud pour nœud',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(emptyHost()));
      await tester.pumpAndSettle();
      final List<String> sansAudit = treeDump(tester);

      // Démontage explicite : sans lui, le second montage RÉUTILISE l'`State`
      // du premier, `initState` ne rejoue pas, et la garde mesurerait un
      // silence qui ne prouve rien.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      late List<String> avecAudit;
      final List<FlutterErrorDetails> caught = await captureErrors(() async {
        await tester.pumpWidget(_wrap(
          emptyHost(seamAudit: const ZStudySeamAuditPolicy()),
        ));
        await tester.pumpAndSettle();
        avecAudit = treeDump(tester);
      });
      expect(caught, hasLength(1), reason: 'le filet a bien parlé');
      expect(avecAudit, sansAudit,
          reason: '🔴 le filet a changé l\'arbre : ce n\'est plus un '
              'diagnostic, c\'est un effet de bord');
      expect(sansAudit, isNotEmpty);
    });

    testWidgets('AVEC politique et renonciation TOTALE : zéro rapport',
        (tester) async {
      useTallSurface(tester);
      final List<FlutterErrorDetails> caught = await captureErrors(() async {
        await tester.pumpWidget(_wrap(emptyHost(
          seamAudit: ZStudySeamAuditPolicy(waived: ZStudySeam.values.toSet()),
        )));
        await tester.pumpAndSettle();
      });
      expect(caught, isEmpty,
          reason: '🔴 un hôte qui a DÉCLARÉ renoncer est averti quand même');
    });

    test('🔴 le montage ÉNUMÉRÉ n\'expose AUCUNE politique d\'audit', () {
      // Il n'y a pas de filet à poser sur un constructeur que le compilateur
      // garde déjà : `seamAudit` n'y est pas un paramètre, et le champ est
      // fermé dans la liste d'initialisation.
      final String src = hostSource();
      final int wired = src.indexOf('ZStudySessionHost.wired({');
      expect(wired, greaterThan(-1), reason: 'garde aveugle');
      final int close = src.indexOf('\n  })', wired);
      expect(src.substring(wired, close), isNot(contains('this.seamAudit')),
          reason: '🔴 une politique posable sur `.wired` promettrait un audit '
              'sur un montage qui ne peut rien oublier');
      expect(src.substring(close), contains('seamAudit = null'),
          reason: '🔴 le champ n\'est plus fermé par le montage énuméré');
    });

    testWidgets('sous `.wired`, la page ne rapporte RIEN, même `.none()`',
        (tester) async {
      useTallSurface(tester);
      final List<FlutterErrorDetails> caught = await captureErrors(() async {
        await tester.pumpWidget(_wrap(ZStudySessionScaffold.wired(
          wiring: const ZStudySessionWiring.none(),
          title: 'W3',
          mode: ZReviewMode.list,
          queue: writtenCards(2),
        )));
        await tester.pumpAndSettle();
      });
      expect(caught, isEmpty);
    });

    testWidgets('🔴 un seul rapport, même après plusieurs rebuilds',
        (tester) async {
      useTallSurface(tester);
      final List<FlutterErrorDetails> caught = await captureErrors(() async {
        for (int i = 0; i < 3; i++) {
          await tester.pumpWidget(_wrap(
            emptyHost(seamAudit: const ZStudySeamAuditPolicy()),
          ));
          await tester.pumpAndSettle();
        }
      });
      expect(caught, hasLength(1),
          reason: '🔴 l\'audit est rejoué à chaque build : la console se '
              'remplit et le signal se noie');
    });

    test('🔴 le site d\'appel vit sous `assert` — debug SEUL', () {
      // `kReleaseMode` n'est pas simulable : `flutter test` compile toujours en
      // debug, et la constante est résolue à la compilation. La preuve est
      // donc STRUCTURELLE — le seul appel du socle est dans un `assert`, que
      // le compilateur retire en release.
      final String src = hostSource();
      final int calls = 'zStudyReportSeamGap('.allMatches(src).length;
      expect(calls, 1,
          reason: '🔴 $calls appel(s) : la preuve structurelle ne porte plus');
      final int at = src.indexOf('zStudyReportSeamGap(');
      final int assertAt = src.lastIndexOf('assert(() {', at);
      expect(assertAt, greaterThan(-1),
          reason: '🔴 aucun `assert(() {` n\'ouvre avant l\'appel : le filet '
              'coûterait en release');
      expect(src.substring(assertAt, at), isNot(contains('return true;')),
          reason: '🔴 l\'`assert` trouvé s\'est refermé avant l\'appel');
    });

    test('🔴 le socle ne LÈVE jamais depuis le filet (AD-10)', () {
      expect(auditSource(), isNot(contains('throw ')),
          reason: '🔴 un `throw` dans le filet ferait tomber l\'écran que '
              'l\'audit devait seulement décrire');
      expect(auditSource(), contains('FlutterError.reportError'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Pureté — l'audit s'appelle dans un test UNITAIRE, sans `pump`
  // ═════════════════════════════════════════════════════════════════════════
  group('🧪 pureté — `auditSeams` est une fonction, pas un montage', () {
    test('l\'audit d\'un widget JAMAIS monté aboutit', () {
      // C'est exactement le code que l'hôte écrit dans sa suite : il construit
      // son widget, il audite, il n'a ni `WidgetTester` ni `BuildContext`.
      final ZStudySeamReport r = emptyHost().auditSeams();
      expect(r.isComplete, isFalse);
      expect(r.missing, hasLength(24));
    });

    test('deux audits du même montage rendent le même rapport', () {
      final ZStudySessionHost host = hostWithOnly(ZStudySeam.labels);
      expect(host.auditSeams().missing, host.auditSeams().missing);
    });
  });
}
