/// 🎯 AC5 (SU-4) — la notation reste aux `ZSrsQualityButtons`, **branchée sur le
/// seam** `ZSessionReviewer` (AD-33/AD-46/AD-5/AD-10).
///
/// Prouve, sur l'assemblage réel (rangée de notation **frère** de la pile) :
///  - le seam est invoqué **exactement une fois**, avec l'identité de la carte
///    **COURANTE** ;
///  - la qualité passe par `ZSrsConfig.clampQuality` — **unique voie de clamp** ;
///  - sur `Left`, la file **n'avance pas** et l'échec est **exposé**.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show ZDomainFailure, Left;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

List<ZSessionItem> _queue() => const <ZSessionItem>[
      ZSessionItem(flashcardId: 'f0', folderId: 'd0'),
      ZSessionItem(flashcardId: 'f1', folderId: 'd1'),
    ];

Finder _qualityButton(int q) =>
    find.byKey(ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q'));

/// Hôte : la rangée de notation est **FRÈRE** de la pile et écrit via le moteur
/// (voie de prod). La pile, elle, n'a aucun accès au seam (AC1).
Future<void> _pumpHost(
  WidgetTester tester, {
  required ZStudySessionEngine engine,
  required ZSrsConfig config,
}) async {
  await tester.pumpWidget(
    wrapApp(
      Column(
        children: <Widget>[
          Expanded(
            child: ZSessionCardSwiper(
              queue: _queue(),
              cardBuilder: (context, item) => Center(child: Text(item.flashcardId)),
              passThreshold: config.passThreshold,
            ),
          ),
          ZSrsQualityButtons(
            scale: ZQualityScale.fromConfig(config),
            passThreshold: config.passThreshold,
            onQualitySelected: engine.grade,
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('🎯 AC5 — la notation atteint le seam, 1× et sur la carte COURANTE', () {
    testWidgets('un tap de qualité ⇒ 1 appel, identité de la carte courante',
        (tester) async {
      const config = ZSrsConfig();
      final spy = SpyReviewer();
      final engine = ZStudySessionEngine(queue: _queue(), reviewer: spy.call);
      addTearDown(engine.dispose);

      await _pumpHost(tester, engine: engine, config: config);
      await tester.tap(_qualityButton(4));
      await tester.pumpAndSettle();

      expect(spy.count, 1, reason: 'exactement une écriture par notation');
      expect(spy.calls.single.flashcardId, 'f0');
      expect(spy.calls.single.folderId, 'd0');
      expect(spy.calls.single.quality, 4);

      // …et la carte COURANTE a bien progressé (4 >= passThreshold ⇒ consommée).
      expect(engine.current?.flashcardId, 'f1');

      // Noter la carte suivante vise bien f1 — jamais f0 (identité recapturée).
      await tester.tap(_qualityButton(5));
      await tester.pumpAndSettle();
      expect(spy.calls.last.flashcardId, 'f1');
      expect(spy.count, 2);
    });
  });

  group('🎯 AC5 — `clampQuality` est l\'UNIQUE voie de clamp (AD-46)', () {
    testWidgets(
        '🔴 sur une échelle NON standard, la note écrite suit `ZSrsConfig` — '
        'un `.clamp(0, 5)` littéral serait démasqué', (tester) async {
      // 🔴 **Écart ASSUMÉ vs la story** (consigné au Dev Agent Record) : l'AC5
      // propose `maxQuality: 4` comme échelle divergente. C'est **impossible à
      // construire** — `ZSrsConfig` porte `assert(maxQuality == 5)` (vérifié :
      // `z_srs_config.dart:43-58`, SM-2 est intrinsèquement 0..5 et sa formule
      // est gelée). La SEULE borne réellement paramétrable est `minQuality`, qui
      // n'admet que `0` ou `1`. On diverge donc par le BAS — et cela suffit
      // pleinement à démasquer le clamp littéral :
      //   • `config.clampQuality(0)` → **1** (échelle de l'app)
      //   • `0.clamp(0, 5)`          → **0** (borne recopiée en dur)
      const config = ZSrsConfig(minQuality: 1);
      final spy = SpyReviewer();
      final engine = ZStudySessionEngine(
        queue: _queue(),
        reviewer: spy.call,
        config: config,
      );
      addTearDown(engine.dispose);

      // Contre-preuve : les deux voies DIVERGENT réellement sur cette entrée.
      // Sans cela, le test serait vert quelle que soit la voie employée.
      expect(config.clampQuality(0), 1);
      expect(0.clamp(config.minQuality, config.maxQuality), 1);
      expect(0.clamp(0, 5), 0,
          reason: 'le clamp LITTÉRAL rendrait 0 — hors de l\'échelle de l\'app');

      // On note par la voie légitime, avec une note SOUS la borne de l'app.
      // (La rangée ne rend pas de cran `0` sur cette échelle : on passe donc par
      // le moteur, exactement comme le ferait un port d'évaluation aberrant —
      // le cas que `clampQuality` existe pour absorber, AD-10.)
      await engine.grade(0);

      expect(
        spy.calls.single.quality,
        1,
        reason: '🔴 AD-46 : la note écrite (${spy.calls.single.quality}) n\'est '
            'pas passée par `config.clampQuality` — une borne `0`/`5` a été '
            'recopiée en littéral, et le SRS reçoit une note HORS de l\'échelle '
            'que l\'app a définie',
      );
    });

    testWidgets('une note aberrante est CLAMPÉE, jamais rejetée (AD-10)',
        (tester) async {
      const config = ZSrsConfig();
      final spy = SpyReviewer();
      final engine = ZStudySessionEngine(
        queue: _queue(),
        reviewer: spy.call,
        config: config,
      );
      addTearDown(engine.dispose);

      await expectLater(engine.grade(99), completes);
      expect(spy.calls.single.quality, 5, reason: 'sur-borne ⇒ clampée à max');
      expect(tester.takeException(), isNull);
    });
  });

  group('🎯 AC5 — sur `Left`, la file N\'AVANCE PAS et l\'échec est EXPOSÉ', () {
    testWidgets('🔴 échec du seam ⇒ file figée, erreur exposée (jamais avalée)',
        (tester) async {
      const config = ZSrsConfig();
      final spy = SpyReviewer(failure: const ZDomainFailure('seam KO'));
      final engine = ZStudySessionEngine(
        queue: _queue(),
        reviewer: spy.call,
        config: config,
      );
      addTearDown(engine.dispose);

      await _pumpHost(tester, engine: engine, config: config);
      final before = engine.current;

      final result = await engine.grade(5);
      await tester.pumpAndSettle();

      expect(spy.count, 1, reason: 'le seam a bien été tenté');
      // (1) la file N'AVANCE PAS.
      expect(
        engine.current,
        before,
        reason: '🔴 la file a avancé malgré l\'échec du seam : l\'apprenant '
            'perdrait la carte, et le SRS n\'aurait rien enregistré',
      );
      expect(engine.reviewed, 0);
      // (2) l'échec est EXPOSÉ — jamais avalé (AD-5).
      expect(result, isA<Left<Object, Object>>());
      expect(engine.state.error, isNotNull);
      expect(tester.takeException(), isNull,
          reason: 'un échec de seam ne doit JAMAIS remonter en exception');
    });
  });
}
