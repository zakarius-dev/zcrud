/// 🎯 AC4 (SU-5) — feedback pédagogique : **fonction PURE, testable hors
/// widget** (FR-SU9).
///
/// `test`, **jamais `testWidgets`** : c'est l'exigence même de FR-SU9 — la règle
/// de seau ne doit dépendre d'aucun `BuildContext`. Si ce fichier devait un jour
/// monter un widget pour tester la sélection, c'est que la fonction aurait cessé
/// d'être pure.
///
/// 🔴 **Interdit ici** (défaut su-4, « test tautologique ») : une fonction locale
/// qui **recalcule** l'attendu — le test s'appellerait lui-même et serait vert
/// quoi que fasse le code. Tous les attendus sont des **valeurs littérales
/// écrites à la main**, dérivées du corpus par raisonnement, jamais lues du code.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';

/// Config canonique du repo : `minQuality=0`, `maxQuality=5`, `passThreshold=3`.
const ZSrsConfig _config = ZSrsConfig();

/// Seuil de maîtrise **écrit à la main** (`4`) — ce test est le SEUL endroit où
/// le littéral est légitime : il est l'**attendu**, dérivé du corpus par
/// raisonnement (`scale.max - 1` avec `max = 5`). Le CODE, lui, ne doit jamais
/// le porter en dur (AD-46) — c'est `z_session_summary_view_test.dart` qui garde
/// la **dérivation**.
const int _mastered = 4;

ZFeedbackTier _tierOf(
  int quality, {
  Duration timeTaken = const Duration(seconds: 30),
  int hintsUsed = 0,
  ZFeedbackThresholds thresholds = const ZFeedbackThresholds(),
}) =>
    zFeedbackTierFor(
      quality: quality,
      timeTaken: timeTaken,
      hintsUsed: hintsUsed,
      config: _config,
      masteredThreshold: _mastered,
      thresholds: thresholds,
    );

void main() {
  group('🎯 AC4 — table des seaux (attendus LITTÉRAUX, jamais recalculés)', () {
    test('q5 / 5 s / 0 indice → exceptionnel', () {
      expect(
        _tierOf(5, timeTaken: const Duration(seconds: 5)),
        ZFeedbackTier.exceptional,
      );
    });

    test('🔴 q5 / 30 s / 0 indice → encouragement (PAS exceptionnel)', () {
      expect(
        _tierOf(5, timeTaken: const Duration(seconds: 30)),
        ZFeedbackTier.encouragement,
        reason: 'le palier exige la VITESSE : 30 s ne peut pas être '
            '« exceptionnel »',
      );
    });

    test('🔴 q5 / 5 s / 1 indice → encouragement — l\'INDICE TUE le palier', () {
      expect(
        _tierOf(5, timeTaken: const Duration(seconds: 5), hintsUsed: 1),
        ZFeedbackTier.encouragement,
        reason: '🔴 R3-(b) : si la condition `hintsUsed == 0` disparaît, ce cas '
            'devient `exceptional` et ce test ROUGIT',
      );
    });

    test('q4 / 5 s / 0 indice → exceptionnel (le seau maîtrisé est q4-5)', () {
      expect(
        _tierOf(4, timeTaken: const Duration(seconds: 5)),
        ZFeedbackTier.exceptional,
      );
    });

    test('q4 / 30 s → encouragement', () {
      expect(_tierOf(4), ZFeedbackTier.encouragement);
    });

    test('q3 → neutre (quel que soit le temps ou les indices)', () {
      expect(_tierOf(3), ZFeedbackTier.neutral);
      expect(
        _tierOf(3, timeTaken: const Duration(seconds: 1)),
        ZFeedbackTier.neutral,
        reason: 'une réponse « bonne » ne devient pas maîtrisée en étant rapide',
      );
      expect(_tierOf(3, hintsUsed: 3), ZFeedbackTier.neutral);
    });

    test('🔴 q0, q1, q2 → motivation — le seau « mauvais » est q0-2', () {
      // 🔴 R3-(c) : si le seau devient `q1-2` (le résidu PRD de l'échelle 1-5),
      // `q0` tombe dans un TROU et ce test ROUGIT. AD-46 : « aucune note n'est
      // hors seau » — c'est l'apprenant en blackout total qui, sinon, ne
      // recevrait AUCUN message.
      expect(_tierOf(0), ZFeedbackTier.motivation, reason: '🔴 q0 : AD-46');
      expect(_tierOf(1), ZFeedbackTier.motivation);
      expect(_tierOf(2), ZFeedbackTier.motivation);
    });

    test('🔒 TOTALITÉ — chaque cran de l\'échelle reçoit un seau, aucun trou', () {
      // Contre-preuve de couverture : on n'affirme pas « aucune note hors seau »,
      // on l'EXERCE sur toute l'échelle.
      for (var q = _config.minQuality; q <= _config.maxQuality; q++) {
        expect(
          () => _tierOf(q),
          returnsNormally,
          reason: 'q$q doit tomber dans un seau (AD-46)',
        );
      }
    });
  });

  // 🔴 D7 — AD-10 : une mesure ABERRANTE ne peut pas MÉRITER le palier.
  //
  // Asymétrie interne corrigée : la fonction CLAMPAIT déjà `quality` (et son
  // dartdoc posait la doctrine « une note aberrante est ramenée, jamais
  // rejetée »), et le fichier frère gardait déjà la durée négative côté
  // présentation (`_formatDuration` ⇒ `00:00`, testé) — mais les DEUX autres
  // entrées aberrantes de cette même signature ne recevaient aucun traitement.
  group('🎯 AD-10 (D7) — une mesure ABERRANTE refuse le palier exceptionnel', () {
    test('🔴 `timeTaken` NÉGATIF ⇒ encouragement, JAMAIS exceptionnel', () {
      expect(
        _tierOf(5, timeTaken: const Duration(seconds: -300)),
        ZFeedbackTier.encouragement,
        reason: '🔴 R3-D7 : sans `!timeTaken.isNegative`, ce cas rend '
            '`exceptional` et ce test ROUGIT. `zFeedbackTierFor` est une API '
            'PUBLIQUE dont l\'hôte fournit `timeTaken` (su-5 le force à mesurer '
            'le temps AU MUR : `end.difference(start)`) — sur une correction NTP '
            'ou un changement d\'heure système entre les deux relevés, la durée '
            'est NÉGATIVE. Un apprenant qui a peiné 5 minutes lirait alors '
            '« Exceptionnel — juste, sans indice et EN UN ÉCLAIR ! »',
      );
    });

    test('🔴 `hintsUsed` NÉGATIF ⇒ encouragement, JAMAIS exceptionnel', () {
      expect(
        _tierOf(5, timeTaken: const Duration(seconds: 1), hintsUsed: -1),
        ZFeedbackTier.encouragement,
        reason: '🔴 même classe : `-1 <= exceptionalMaxHints (0)` était VRAI ⇒ '
            'un compte d\'indices absurde valait « sans aide »',
      );
    });

    test(
        '🔬 contre-preuve — on ne CLAMPE PAS à zéro (ce serait la valeur la plus '
        'FLATTEUSE), et le chemin NOMINAL reste intact', () {
      // Si la correction clampait `timeTaken` à `Duration.zero`, le cas négatif
      // deviendrait « instantané » ⇒ `exceptional` : exactement le bug. Le repli
      // est donc un REFUS de palier, jamais une normalisation.
      expect(_tierOf(5, timeTaken: Duration.zero), ZFeedbackTier.exceptional,
          reason: '0 s est légitime et DOIT rester exceptionnel — sans quoi la '
              'correction aurait cassé le chemin nominal');
      expect(_tierOf(5, timeTaken: const Duration(seconds: 1), hintsUsed: 0),
          ZFeedbackTier.exceptional);
      // Aucune exception, jamais (AD-10) : le repli est une DÉGRADATION, pas un
      // rejet — la carte EST maîtrisée, le message reste juste et positif.
      expect(
        () => _tierOf(5, timeTaken: const Duration(days: -9999), hintsUsed: -99),
        returnsNormally,
      );
    });

    test('🔴 une mesure aberrante ne PROMEUT ni ne RÉTROGRADE le seau de base',
        () {
      // Le refus porte sur le PALIER, jamais sur le seau : une note mauvaise
      // reste `motivation`, une note passable reste `neutral`.
      expect(_tierOf(0, timeTaken: const Duration(seconds: -5)),
          ZFeedbackTier.motivation);
      expect(_tierOf(3, timeTaken: const Duration(seconds: -5)),
          ZFeedbackTier.neutral);
    });
  });

  group('🎯 AC4 — la BORNE `< 10 s` est stricte (R3-(a))', () {
    test('🔴 exactement 10 s → PAS exceptionnel (la borne est EXCLUE)', () {
      expect(
        _tierOf(5, timeTaken: const Duration(seconds: 10)),
        ZFeedbackTier.encouragement,
        reason: '🔴 R3-(a) : si `< 10 s` devient `<= 10 s`, ce cas EXACT à la '
            'borne devient `exceptional` et ce test ROUGIT. Une borne non '
            'testée est une borne non spécifiée',
      );
    });

    test('9,999 s → exceptionnel (juste SOUS la borne)', () {
      expect(
        _tierOf(5, timeTaken: const Duration(milliseconds: 9999)),
        ZFeedbackTier.exceptional,
      );
    });

    test('le seuil est CONFIGURABLE (jamais un `10` en dur)', () {
      // À 15 s, le défaut (`< 10 s`) refuse le palier…
      expect(
        _tierOf(5, timeTaken: const Duration(seconds: 15)),
        ZFeedbackTier.encouragement,
      );
      // …mais un seuil injecté à 20 s l'accorde : la valeur vient bien du
      // paramètre, pas d'une constante enfouie.
      expect(
        _tierOf(
          5,
          timeTaken: const Duration(seconds: 15),
          thresholds: const ZFeedbackThresholds(
            exceptionalUnder: Duration(seconds: 20),
          ),
        ),
        ZFeedbackTier.exceptional,
      );
    });

    test('le nombre d\'indices toléré est CONFIGURABLE', () {
      expect(
        _tierOf(
          5,
          timeTaken: const Duration(seconds: 5),
          hintsUsed: 1,
          thresholds: const ZFeedbackThresholds(exceptionalMaxHints: 1),
        ),
        ZFeedbackTier.exceptional,
      );
    });
  });

  group('🎯 AC4 — clamp : `config.clampQuality` est la VOIE UNIQUE (AD-46/AD-10)',
      () {
    // ⚠️ 🔴 **PORTÉE DÉCLARÉE HONNÊTEMENT — MESURÉE, pas supposée.**
    //
    // La story annonçait l'injection R3-(d) « retirer `clampQuality` ⇒ ROUGE ».
    // **Rejouée sur disque, elle est restée VERTE (19/19)** — et c'est le TEST
    // qui avait tort, pas le code. Démonstration (mesurée, cf. Completion Notes) :
    // sur toute config PERMISE, le seau est **invariant par clamp** —
    //  · clamp vers le HAUT (`q < min` → `min`) : `assert(minQuality <
    //    passThreshold)` ⇒ `min` est TOUJOURS dans le seau `motivation`, et un
    //    `q` sous `min` aussi ⇒ jamais de différence ;
    //  · clamp vers le BAS (`q > max` → `max`) : `max = 5 >= masteredThreshold
    //    (4, dérivé `scale.max - 1`)` ⇒ `encouragement`, et un `q9` brut aussi.
    // Les cas `q-3`/`q9` étaient donc verts **par accident arithmétique** : ils
    // prouvaient la TOTALITÉ (AD-10, aucun throw), jamais le clamp.
    //
    // Le clamp n'est OBSERVABLE sur le seau que si `masteredThreshold > max` —
    // entrée LÉGITIME (le paramètre est injecté et sans `assert` ; un hôte peut
    // vouloir « rien n'est maîtrisé »). C'est ce cas, et lui seul, qui garde
    // réellement AD-46 ci-dessous. On ne prétend donc pas prouver plus que ce
    // qui est mesuré (leçon E10 : « une garde ne prouve QUE ce qu'elle scanne »).

    test('🔴 R3-(d) — `q9` avec `masteredThreshold: 6` → neutral : la note '
        'ABERRANTE a bien été RAMENÉE à `5` (le SEUL cas qui démasque le clamp)',
        () {
      // Sans `clampQuality`, `9 >= 6` est VRAI ⇒ `encouragement` : la note
      // aberrante `9` serait honorée TELLE QUELLE, hors de l'échelle que le
      // scheduler sait servir. C'est exactement ce qu'AD-46 interdit.
      expect(
        zFeedbackTierFor(
          quality: 9,
          timeTaken: const Duration(seconds: 30),
          hintsUsed: 0,
          config: _config,
          masteredThreshold: 6,
        ),
        ZFeedbackTier.neutral,
        reason: '🔴 R3-(d) RÉEL : si `config.clampQuality` disparaît, `q9` est '
            'jugé « maîtrisé » alors que l\'échelle plafonne à 5 ⇒ ce test '
            'ROUGIT (encouragement != neutral)',
      );
    });

    test('🔴 R3-(d) bis — `q999` / 5 s / 0 indice avec `masteredThreshold: 6` : '
        'clampé à 5 ⇒ neutral, jamais « exceptionnel »', () {
      expect(
        zFeedbackTierFor(
          quality: 999,
          timeTaken: const Duration(seconds: 5),
          hintsUsed: 0,
          config: _config,
          masteredThreshold: 6,
        ),
        ZFeedbackTier.neutral,
        reason: 'sans clamp, `999 >= 6` ⇒ `exceptional` : une note corrompue '
            'décrocherait le palier le plus élevé',
      );
    });

    test('q-3 → motivation et q9 → encouragement (TOTALITÉ, AD-10 — ces cas ne '
        'prouvent PAS le clamp, cf. dartdoc du groupe)', () {
      expect(_tierOf(-3), ZFeedbackTier.motivation);
      expect(_tierOf(9), ZFeedbackTier.encouragement);
      expect(
        _tierOf(9, timeTaken: const Duration(seconds: 5)),
        ZFeedbackTier.exceptional,
      );
    });

    test('aucune note aberrante ne lève d\'exception (AD-10)', () {
      for (final q in <int>[-100, -3, -1, 6, 9, 999]) {
        expect(() => _tierOf(q), returnsNormally, reason: 'q$q : AD-10');
      }
    });

    test('🔒 les bornes viennent de la CONFIG, jamais de la fonction '
        '(échelle tronquée `minQuality: 1`)', () {
      // `ZSrsConfig(minQuality: 1)` = échelle « sans blackout ». Le clamp y
      // ramène `q0` à `1` — invisible sur le seau (les deux sont `motivation`,
      // cf. dartdoc), mais la config DOIT être celle qui parle : on vérifie donc
      // la borne par le canal où elle est observable, `clampQuality` lui-même.
      const truncated = ZSrsConfig(minQuality: 1);
      expect(truncated.clampQuality(0), 1,
          reason: 'la voie unique de clamp suit bien la config tronquée');
      expect(
        zFeedbackTierFor(
          quality: 0,
          timeTaken: const Duration(seconds: 30),
          hintsUsed: 0,
          config: truncated,
          masteredThreshold: _mastered,
        ),
        ZFeedbackTier.motivation,
      );
    });
  });

  group('🎯 AC4 — `zFeedbackKeyFor` rend une CLÉ, jamais un texte', () {
    test('la clé de chaque seau est littérale et stable', () {
      // Attendus LITTÉRAUX : si l'espace de clés bouge, les banques FR/EN
      // cessent de résoudre — ce test est leur contrat.
      expect(
        zFeedbackKeyFor(ZFeedbackTier.motivation),
        'zcrud.session.feedback.motivation',
      );
      expect(
        zFeedbackKeyFor(ZFeedbackTier.neutral),
        'zcrud.session.feedback.neutral',
      );
      expect(
        zFeedbackKeyFor(ZFeedbackTier.encouragement),
        'zcrud.session.feedback.encouragement',
      );
      expect(
        zFeedbackKeyFor(ZFeedbackTier.exceptional),
        'zcrud.session.feedback.exceptional',
      );
    });

    test('🔒 TOUS les seaux ont une clé (aucun `tier` sans message)', () {
      for (final tier in ZFeedbackTier.values) {
        expect(zFeedbackKeyFor(tier), startsWith('zcrud.session.feedback.'));
      }
    });
  });
}
