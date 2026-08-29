/// 🎯 `ZLapseRequeuePolicy` — offsets de réinsertion PARAMÉTRABLES.
///
/// Quatre propriétés, toutes mesurées sur des **positions de file gelées**
/// (jamais un `contains`/`<=` : l'ordre complet est asserté en égalité
/// stricte) :
///  1. **INERTIE** — sans politique injectée, les positions sont EXACTEMENT
///     celles d'avant l'existence du type, sur les deux reducers ET les deux
///     runtimes ;
///  2. **PASSE-PLAT INTERDIT** — une politique injectée au CONSTRUCTEUR d'un
///     runtime change réellement les positions de la file. Sans ce témoin, un
///     paramètre stocké et jamais lu passerait la garde d'inertie ;
///  3. **SÉMANTIQUE** — un lapse SÉVÈRE revient STRICTEMENT AVANT un lapse
///     léger (c'est la règle du paquet : plus l'échec est franc, plus tôt la
///     carte revient) ;
///  4. **FRONTIÈRE** — `severeMaxQuality` déplace réellement la frontière,
///     donc la comparaison n'est pas restée codée en dur dans les reducers.
///
/// 🔴 Anti-tautologie : chaque assertion sur une politique CUSTOM est
/// accompagnée de la position obtenue avec la politique PAR DÉFAUT sur le
/// MÊME scénario, et les deux sont exigées DIFFÉRENTES. Une garde qui
/// n'assertait que la position custom resterait verte si les reducers
/// ignoraient la politique et que la valeur custom coïncidait avec le défaut.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

ZSessionItem _item(String id) => ZSessionItem(flashcardId: id, folderId: 'F');

List<ZSessionItem> _queueOf(String ids) =>
    ids.split('').map(_item).toList(growable: false);

String _order(ZSessionState s) =>
    s.queue.map((ZSessionItem i) => i.flashcardId).join();

/// Seam de review toujours en succès — la politique n'a rien à voir avec la
/// voie d'écriture SRS, ce spy ne sert qu'à faire avancer le moteur.
Future<ZResult<ZRepetitionInfo>> _ok({
  required String flashcardId,
  required String folderId,
  required int quality,
  DateTime? now,
}) async =>
    Right<ZFailure, ZRepetitionInfo>(
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
    );

ZSessionState _fresh(String ids, ZReviewMode mode) => ZSessionState(
      queue: _queueOf(ids),
      cursor: 0,
      reviewed: 0,
      lapses: 0,
      mode: mode,
      error: null,
    );

void main() {
  // Politique custom délibérément ÉLOIGNÉE du défaut sur les trois axes :
  // offset sévère raccourci (1 au lieu de 2), offset léger allongé (6 au lieu
  // de 4), frontière abaissée (0 au lieu de 1 ⇒ q=1 devient LÉGER).
  const custom = ZLapseRequeuePolicy(
    offsetSevere: 1,
    offsetLight: 6,
    severeMaxQuality: 0,
  );

  group('🎯 value-object', () {
    test('les défauts SONT les constantes historiques (aucune recopie)', () {
      const p = ZLapseRequeuePolicy();
      expect(p.offsetSevere, kLapseOffsetSoft);
      expect(p.offsetLight, kLapseOffsetHard);
      expect(p.severeMaxQuality, kLapseSoftMaxQuality);
    });

    test('offsetFor : sévère ⇒ offset COURT, léger ⇒ offset LONG', () {
      const p = ZLapseRequeuePolicy();
      expect(p.offsetFor(0), 2);
      expect(p.offsetFor(1), 2);
      expect(p.offsetFor(2), 4);
      // 🔴 La règle du paquet, assertée en toutes lettres : l'échec SÉVÈRE
      // obtient l'offset le PLUS COURT — la carte revient plus tôt.
      expect(p.offsetFor(0), lessThan(p.offsetFor(2)));
    });

    test('égalité par valeur', () {
      expect(const ZLapseRequeuePolicy(), const ZLapseRequeuePolicy());
      expect(custom == const ZLapseRequeuePolicy(), isFalse);
      expect(
        custom.hashCode == const ZLapseRequeuePolicy().hashCode,
        isFalse,
      );
    });
  });

  group('🔒 INERTIE — sans politique, positions IDENTIQUES à l\'historique', () {
    test('reduceGrade : q=0 ⇒ BACDEFGH ; q=2 ⇒ BCDAEFGH (ordre GELÉ)', () {
      expect(
        _order(
          reduceGrade(_fresh('ABCDEFGH', ZReviewMode.spaced), 0,
              passThreshold: 3),
        ),
        'BACDEFGH',
      );
      expect(
        _order(
          reduceGrade(_fresh('ABCDEFGH', ZReviewMode.spaced), 2,
              passThreshold: 3),
        ),
        'BCDAEFGH',
      );
    });

    test('requeueCramming : q=0 ⇒ BACDEFGH ; q=2 ⇒ BCDAEFGH (ordre GELÉ)', () {
      expect(
        _order(
          requeueCramming(_fresh('ABCDEFGH', ZReviewMode.cramming), 0,
              passThreshold: 3),
        ),
        'BACDEFGH',
      );
      expect(
        _order(
          requeueCramming(_fresh('ABCDEFGH', ZReviewMode.cramming), 2,
              passThreshold: 3),
        ),
        'BCDAEFGH',
      );
    });

    test('les DEUX runtimes, construits sans politique, rendent ces MÊMES '
        'positions', () async {
      final linear = ZLinearSessionState(
        queue: _queueOf('ABCDEFGH'),
        mode: ZReviewMode.cramming,
      );
      addTearDown(linear.dispose);
      linear.answer(0);
      expect(_order(linear.state), 'BACDEFGH');

      final srs = ZStudySessionEngine(queue: _queueOf('ABCDEFGH'), reviewer: _ok);
      addTearDown(srs.dispose);
      await srs.grade(2);
      expect(_order(srs.state), 'BCDAEFGH');
    });
  });

  group('🎯 politique CUSTOM — les positions CHANGENT réellement', () {
    test('reduceGrade : custom ≠ défaut sur le MÊME scénario (q=0 et q=1)', () {
      // q=0 : sévère dans les deux politiques, mais offset 1 au lieu de 2 ⇒
      // la carte revient EN TÊTE.
      final q0Default =
          _order(reduceGrade(_fresh('ABCDEFGH', ZReviewMode.spaced), 0,
              passThreshold: 3));
      final q0Custom = _order(
        reduceGrade(_fresh('ABCDEFGH', ZReviewMode.spaced), 0,
            passThreshold: 3, policy: custom),
      );
      expect(q0Custom, 'ABCDEFGH');
      // 🔴 Témoin discriminant : si la politique était ignorée, les deux
      // chaînes seraient égales et l'assertion ci-dessus serait fausse — mais
      // on l'exige AUSSI explicitement, pour que l'intention reste lisible.
      expect(q0Custom == q0Default, isFalse,
          reason: '🔴 la politique injectée n\'a rien changé : `policy` est '
              'un passe-plat inerte dans `reduceGrade`');

      // q=1 : la FRONTIÈRE bascule (severeMaxQuality 1 → 0), donc q=1 passe de
      // sévère (+2) à léger (+6).
      final q1Custom = _order(
        reduceGrade(_fresh('ABCDEFGH', ZReviewMode.spaced), 1,
            passThreshold: 3, policy: custom),
      );
      expect(q1Custom, 'BCDEFAGH');
      expect(q1Custom == 'BACDEFGH', isFalse,
          reason: '🔴 `severeMaxQuality` n\'est pas consommé : q=1 a gardé '
              'l\'offset sévère du défaut');
    });

    test('requeueCramming : custom ≠ défaut sur le MÊME scénario', () {
      final defaultOrder =
          _order(requeueCramming(_fresh('ABCDEFGH', ZReviewMode.cramming), 1,
              passThreshold: 3));
      final customOrder = _order(
        requeueCramming(_fresh('ABCDEFGH', ZReviewMode.cramming), 1,
            passThreshold: 3, policy: custom),
      );
      expect(defaultOrder, 'BACDEFGH');
      expect(customOrder, 'BCDEFAGH');
      expect(customOrder == defaultOrder, isFalse);
    });

    test('🔴 PASSE-PLAT INTERDIT — la politique du CONSTRUCTEUR atteint bien '
        'le reducer (les deux runtimes)', () async {
      final linear = ZLinearSessionState(
        queue: _queueOf('ABCDEFGH'),
        mode: ZReviewMode.cramming,
        lapsePolicy: custom,
      );
      addTearDown(linear.dispose);
      linear.answer(1);
      expect(_order(linear.state), 'BCDEFAGH',
          reason: '🔴 `lapsePolicy` est stockée mais jamais lue par '
              '`ZLinearSessionState.answer`');

      final srs = ZStudySessionEngine(
        queue: _queueOf('ABCDEFGH'),
        reviewer: _ok,
        lapsePolicy: custom,
      );
      addTearDown(srs.dispose);
      await srs.grade(1);
      expect(_order(srs.state), 'BCDEFAGH',
          reason: '🔴 `lapsePolicy` est stockée mais jamais lue par '
              '`ZStudySessionEngine.grade`');
    });
  });

  group('🎯 SÉMANTIQUE — le sévère revient AVANT le léger', () {
    test('défaut : position(q=0) < position(q=2) dans la file résultante', () {
      int positionOf(int quality, ZLapseRequeuePolicy policy) {
        final next = reduceGrade(
          _fresh('ABCDEFGH', ZReviewMode.spaced),
          quality,
          passThreshold: 3,
          policy: policy,
        );
        return _order(next).indexOf('A');
      }

      const p = ZLapseRequeuePolicy();
      expect(positionOf(0, p), lessThan(positionOf(2, p)),
          reason: '🔴 un blackout complet (q=0) doit revenir PLUS TÔT qu\'une '
              'carte presque sue (q=2) — la sémantique est inversée');
    });

    test('custom : la propriété tient encore après re-paramétrage', () {
      int positionOf(int quality) => _order(
            requeueCramming(
              _fresh('ABCDEFGH', ZReviewMode.cramming),
              quality,
              passThreshold: 3,
              policy: custom,
            ),
          ).indexOf('A');

      // q=0 sévère (offset 1) vs q=1 léger (offset 6) sous `custom`.
      expect(positionOf(0), lessThan(positionOf(1)));
    });
  });
}
