// Garde de la NOTE ÉCRITE par la borne basse d'échelle (`ZSrsConfig.minQuality`).
//
// Pourquoi cette garde existe. `minQuality` est lu par les consommateurs comme
// une simple borne de clamp. C'en est une, mais c'est AUSSI la note que le
// geste le plus bas d'une session (« je ne sais pas ») fait réellement écrire :
// c'est la voie unique décrite par `z_hint_penalty.dart`. Un hôte dont
// l'échelle PERSISTÉE ne comporte pas de `0` (énumération démarrant à 1)
// reçoit alors une note parfaitement légale au regard de la `ZSrsConfig` qu'il
// a lui-même fournie, mais NON REPRÉSENTABLE chez lui — sa propre conversion
// la perd, sans exception ni test rouge, et la perte est invisible à la
// relecture de données (une note absente est une valeur plausible).
//
// Ce que ce fichier fige, et pourquoi ces trois propriétés-là :
//
//  1. le socle NE PERD PAS la note : `apply` la reporte dans
//     `ZRepetitionInfo.lastQuality`, sur les deux échelles admises. Sans
//     cette garde, une régression du report ferait porter au socle une perte
//     qui aujourd'hui n'est pas la sienne — et le diagnostic d'un hôte
//     repartirait au mauvais endroit ;
//  2. `ZSrsConfig(minQuality: 1)` — l'échelle « sans blackout » — reste
//     constructible et clampe `0` vers `1`. C'est la porte de sortie offerte
//     à un hôte dont l'échelle n'a pas de `0` ; si elle se refermait, la
//     documentation de `minQuality` renverrait vers un remède inexistant ;
//  3. passer de `0` à `1` N'EST PAS neutre pour l'échéancier. C'est le point
//     coûteux et contre-intuitif : les deux valeurs sont sous `passThreshold`,
//     donc `interval`/`repetitions` sont identiques — d'où la conclusion
//     naturelle, et fausse, que le changement est gratuit. Le facteur de
//     facilité, lui, diffère (formule SM-2 gelée `(5 - q)`), et il commande
//     TOUTES les échéances ultérieures. Un hôte qui bascule doit le savoir ;
//     s'il l'ignore, il n'a aucun signal.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Échelle canonique SM-2 complète (défaut du paquet) : borne basse `0`.
const ZSrsConfig _full = ZSrsConfig();

/// Échelle « sans blackout » : borne basse `1`.
const ZSrsConfig _noBlackout = ZSrsConfig(minQuality: 1);

/// État de départ neuf, identique des deux côtés (aucune histoire à porter).
ZRepetitionInfo _fresh() => const ZSm2Scheduler().initial(
      flashcardId: 'card-1',
      folderId: 'folder-1',
    );

void main() {
  group('borne basse = note ÉCRITE', () {
    test('le socle REPORTE la note dans lastQuality (échelle complète)', () {
      final applied = const ZSm2Scheduler(config: _full)
          .apply(_fresh(), _full.minQuality, now: DateTime.utc(2026));
      expect(applied.lastQuality, 0);
      expect(applied.lastQuality, _full.minQuality);
    });

    test('le socle REPORTE la note dans lastQuality (échelle sans blackout)',
        () {
      final applied = const ZSm2Scheduler(config: _noBlackout)
          .apply(_fresh(), _noBlackout.minQuality, now: DateTime.utc(2026));
      expect(applied.lastQuality, 1);
      expect(applied.lastQuality, _noBlackout.minQuality);
    });

    test('un 0 soumis sur une échelle sans blackout est CLAMPÉ à 1, pas perdu',
        () {
      expect(_noBlackout.clampQuality(0), 1);
      final applied = const ZSm2Scheduler(config: _noBlackout)
          .apply(_fresh(), 0, now: DateTime.utc(2026));
      expect(applied.lastQuality, 1);
    });
  });

  group('coût de la bascule 0 → 1', () {
    test('interval et repetitions sont IDENTIQUES (deux lapses)', () {
      final now = DateTime.utc(2026);
      final low =
          const ZSm2Scheduler(config: _full).apply(_fresh(), 0, now: now);
      final one =
          const ZSm2Scheduler(config: _noBlackout).apply(_fresh(), 1, now: now);
      expect(low.repetitions, 0);
      expect(one.repetitions, low.repetitions);
      expect(low.interval, 1);
      expect(one.interval, low.interval);
      expect(one.nextReviewDate, low.nextReviewDate);
    });

    test('le FACTEUR DE FACILITÉ diffère — la bascule n\'est PAS gratuite',
        () {
      final now = DateTime.utc(2026);
      final low =
          const ZSm2Scheduler(config: _full).apply(_fresh(), 0, now: now);
      final one =
          const ZSm2Scheduler(config: _noBlackout).apply(_fresh(), 1, now: now);
      // Formule SM-2 gelée : EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)).
      // q=0 ⇒ -0.80 ; q=1 ⇒ -0.54. Départ 2.5, aucune borne atteinte.
      expect(low.easeFactor, closeTo(1.70, 1e-9));
      expect(one.easeFactor, closeTo(1.96, 1e-9));
      expect(one.easeFactor, greaterThan(low.easeFactor));
      // L'écart n'est pas un arrondi : il vaut un quart de point de facteur,
      // qui multiplie chaque intervalle ultérieur.
      expect(one.easeFactor - low.easeFactor, closeTo(0.26, 1e-9));
    });
  });
}
