/// Tests de la flamme d'assiduité (SU-6 — AC1/AC2/AC3/AC4).
///
/// **Assertions EXACTES partout** (`equals(1)`, jamais `isNotNull`/
/// `greaterThan(0)`) : sur le cas `resetToOne`, un `greaterThan(0)` resterait
/// VERT si la série repartait à… `0` — le défaut EXACT que le spine nomme.
///
/// Pur-Dart (`dart test`) : le kernel n'importe AUCUN Flutter.
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Calendrier **SIMULÉ** — mappe un instant sur un jour civil arbitraire.
///
/// 🔴 C'est le seul moyen d'éprouver un jour de **23 h / 25 h** (DST) sans
/// dépendre du `TZ` de la machine de CI (AC3) : on ne peut pas demander à la CI
/// d'être à Paris. On injecte donc le calendrier au lieu de le subir.
///
/// 🔴 Un instant NON CARTOGRAPHIÉ est une **erreur bruyante**, jamais une valeur
/// (code-review su-6, LOW-5). Le repli était `'<inconnu>'` : une chaîne
/// illisible ⇒ `zParseCivilDayNumber` rend `null` ⇒ `zAdvanceStreak` prend la
/// branche AD-10 « horloge folle » et rend `alreadyCountedToday` + streak
/// inchangé — c'est-à-dire **exactement** ce qu'assertent les cas « même jour »,
/// « 25 h intra-jour », « date future », « idempotence » et « désordre ». Le
/// repli se **déguisait donc en résultat attendu** : ajouter des millisecondes à
/// un `at:` sans toucher la clé du map faisait rater le lookup, et le test
/// restait VERT en ne testant plus rien du jour civil. Un faux témoin silencieux.
ZCivilDayOf _calendar(Map<DateTime, String> days) => (at) {
      final day = days[at];
      if (day == null) {
        throw StateError(
          '🔴 instant NON CARTOGRAPHIÉ par le calendrier du test : $at — '
          'ajoute-le au map (un repli rendrait le test vert en testant le '
          'repli AD-10 « horloge folle » à la place du jour civil)',
        );
      }
      return day;
    };

/// 🔬 **CONTRE-PREUVE R3 (AC3) — l'implémentation NAÏVE, dans le fichier de test.**
///
/// Calcule l'écart en jours par **temps écoulé** (`at.difference(...).inDays`) —
/// ce que la story INTERDIT. Elle est soumise **aux mêmes** assertions DST que
/// l'implémentation réelle et **doit ÉCHOUER** : sans cette contre-preuve, les
/// cas DST prouveraient seulement que `zAdvanceStreak` rend `incremented`, jamais
/// que l'arithmétique civile y est POUR QUELQUE CHOSE.
ZStreakOutcome _naiveOutcomeByElapsed({
  required DateTime lastInstant,
  required DateTime at,
}) {
  final elapsedDays = at.difference(lastInstant).inDays;
  if (elapsedDays == 0) return ZStreakOutcome.alreadyCountedToday;
  if (elapsedDays == 1) return ZStreakOutcome.incremented;
  return ZStreakOutcome.resetToOne;
}

void main() {
  group('AC1 — ZStudyStreak : entité domaine, fromMap DÉFENSIF', () {
    test('round-trip toMap/fromMap préserve TOUS les champs (valeurs exactes)',
        () {
      const streak = ZStudyStreak(
        id: 'streak-1',
        current: 7,
        best: 12,
        lastGradedDay: '2026-03-28',
      );

      final restored = ZStudyStreak.fromMap(streak.toMap());

      expect(restored, equals(streak));
      expect(restored.current, equals(7));
      expect(restored.best, equals(12));
      expect(restored.lastGradedDay, equals('2026-03-28'));
      expect(restored.id, equals('streak-1'));
    });

    test('les clés persistées sont en snake_case (last_graded_day)', () {
      const streak = ZStudyStreak(current: 3, best: 4, lastGradedDay: '2026-01-02');
      final map = streak.toMap();

      expect(map['last_graded_day'], equals('2026-01-02'));
      expect(map['current'], equals(3));
      expect(map['best'], equals(4));
      // Le champ Dart camelCase ne fuit JAMAIS en persistance.
      expect(map.containsKey('lastGradedDay'), isFalse);
    });

    test('map VIDE ⇒ streak neutre, jamais de throw (AD-10)', () {
      final streak = ZStudyStreak.fromMap(const <String, dynamic>{});

      expect(streak.current, equals(0));
      expect(streak.best, equals(0));
      expect(streak.lastGradedDay, isNull);
      expect(streak.id, isNull);
      expect(streak.isEphemeral, isTrue);
    });

    test('🔴 map CORROMPUE {current: "x", best: -4} ⇒ 0 / 0 (jamais négatif)',
        () {
      final streak = ZStudyStreak.fromMap(const <String, dynamic>{
        'current': 'x',
        'best': -4,
      });

      // 🔴 L'injection R3 de l'AC1 : remplacer le défaut `-4 → 0` par `-4` fait
      // rougir CETTE assertion — par le COMPORTEMENT, pas par la compilation.
      expect(streak.current, equals(0));
      expect(streak.best, equals(0));
    });

    test('current NÉGATIF persisté ⇒ planché à 0', () {
      final streak =
          ZStudyStreak.fromMap(const <String, dynamic>{'current': -9, 'best': 3});

      expect(streak.current, equals(0));
      expect(streak.best, equals(3));
    });

    test('lastGradedDay ILLISIBLE ⇒ null (format libre, date impossible)', () {
      for (final raw in <Object?>[
        '28/03/2026', // format libre
        '2026-02-31', // date IMPOSSIBLE (février n'a pas 31 jours)
        '2026-13-01', // mois impossible
        '2026-00-10', // mois 0
        '2026-03-00', // jour 0
        '2026-3-8', // non zéro-padé
        '', // vide
        42, // pas une String
        <String>['2026-03-28'], // structure absurde
      ]) {
        final streak =
            ZStudyStreak.fromMap(<String, dynamic>{'last_graded_day': raw});
        expect(
          streak.lastGradedDay,
          isNull,
          reason: 'jour illisible « $raw » ⇒ null (AC1), jamais de throw',
        );
      }
    });

    test('une date civile VALIDE est préservée (y compris un 29 février)', () {
      final streak = ZStudyStreak.fromMap(
        const <String, dynamic>{'last_graded_day': '2028-02-29'},
      );
      expect(streak.lastGradedDay, equals('2028-02-29'));
    });

    test('2026-02-29 (année NON bissextile) est illisible ⇒ null', () {
      final streak = ZStudyStreak.fromMap(
        const <String, dynamic>{'last_graded_day': '2026-02-29'},
      );
      expect(streak.lastGradedDay, isNull);
    });

    test('copyWith GÉNÉRÉ : sentinelle (omis = préservé, null = remis à null)',
        () {
      const streak = ZStudyStreak(
        id: 'a',
        current: 5,
        best: 9,
        lastGradedDay: '2026-03-28',
      );

      // Omis ⇒ préservé.
      expect(streak.copyWith(current: 6).lastGradedDay, equals('2026-03-28'));
      expect(streak.copyWith(current: 6).best, equals(9));
      // `null` EXPLICITE ⇒ remis à null (ce que la sentinelle rend possible).
      expect(streak.copyWith(lastGradedDay: null).lastGradedDay, isNull);
      expect(streak.copyWith(id: null).id, isNull);
    });
  });

  group('AC3 — jour civil : arithmétique CALENDAIRE (zCivilDayNumber)', () {
    test('deux jours consécutifs sont à EXACTEMENT 1 de distance', () {
      expect(
        zCivilDayNumber(2026, 3, 29) - zCivilDayNumber(2026, 3, 28),
        equals(1),
      );
    });

    test('bascule de mois / d\'année / bissextile : distance exacte de 1', () {
      expect(zCivilDayNumber(2026, 4, 1) - zCivilDayNumber(2026, 3, 31), equals(1));
      expect(zCivilDayNumber(2027, 1, 1) - zCivilDayNumber(2026, 12, 31), equals(1));
      expect(zCivilDayNumber(2028, 3, 1) - zCivilDayNumber(2028, 2, 29), equals(1));
      // 2026 n'est PAS bissextile : le 1ᵉʳ mars suit le 28 février.
      expect(zCivilDayNumber(2026, 3, 1) - zCivilDayNumber(2026, 2, 28), equals(1));
    });

    test('zLocalCivilDay lit les champs LOCAUX et formate yyyy-MM-dd', () {
      expect(zLocalCivilDay(DateTime(2026, 3, 8, 23, 59, 59)), equals('2026-03-08'));
      expect(zLocalCivilDay(DateTime(2026, 12, 31)), equals('2026-12-31'));
    });

    test('🔴 même instant : le jour retenu est le LOCAL, jamais l\'UTC', () {
      // Un instant proche de minuit tombe sur DEUX jours civils différents selon
      // qu'on lise le calendrier local ou UTC. `zLocalCivilDay` doit suivre le
      // calendrier de l'APPRENANT (AC3).
      final at = DateTime(2026, 3, 28, 0, 30); // 00:30 LOCAL
      expect(zLocalCivilDay(at), equals('2026-03-28'));
      expect(
        zLocalCivilDay(at),
        equals(zFormatCivilDay(at.year, at.month, at.day)),
        reason: 'la dérivation lit at.year/month/day — les champs LOCAUX',
      );

      // Contre-preuve du DISCRIMINANT : sur une machine dont le fuseau n'est pas
      // UTC, l'instant ci-dessus n'a PAS le même jour civil en UTC. Le test ne
      // l'exige pas (la CI peut être en UTC) — il prouve que SI les deux
      // divergent, c'est bien le LOCAL qui est rendu.
      final utc = at.toUtc();
      if (utc.day != at.day || utc.month != at.month || utc.year != at.year) {
        expect(
          zLocalCivilDay(at),
          isNot(equals(zFormatCivilDay(utc.year, utc.month, utc.day))),
          reason: '🔴 le jour UTC a été retenu au lieu du jour LOCAL',
        );
      }
    });
  });

  group('AC2 — zAdvanceStreak : le tableau, valeur par valeur', () {
    const day = '2026-03-28';
    final at = DateTime(2026, 3, 28, 10);
    final civilDayOf = _calendar(<DateTime, String>{at: day});

    test('toute PREMIÈRE répétition notée ⇒ current = 1, started', () {
      const streak = ZStudyStreak();

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.started));
      expect(result.streak.current, equals(1));
      expect(result.streak.best, equals(1));
      expect(result.streak.lastGradedDay, equals(day));
    });

    test('MÊME jour civil ⇒ INCHANGÉ (idempotent), alreadyCountedToday', () {
      const streak =
          ZStudyStreak(current: 4, best: 9, lastGradedDay: '2026-03-28');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.alreadyCountedToday));
      // Assertion sur l'OBJET ENTIER : rien n'a bougé, pas même `best`.
      expect(result.streak, equals(streak));
      expect(result.streak.current, equals(4));
    });

    test('jour civil SUIVANT ⇒ current + 1, incremented', () {
      const streak =
          ZStudyStreak(current: 4, best: 9, lastGradedDay: '2026-03-27');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.incremented));
      expect(result.streak.current, equals(5));
      expect(result.streak.best, equals(9), reason: 'best inchangé (5 < 9)');
      expect(result.streak.lastGradedDay, equals(day));
    });

    test('🔴 TROU >= 1 jour civil ⇒ current = **1**, resetToOne — JAMAIS 0', () {
      const streak =
          ZStudyStreak(current: 12, best: 12, lastGradedDay: '2026-03-25');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.resetToOne));
      // 🔴 L'ASSERTION QUI COMPTE (injection R3 de l'AC2 : passer `1` à `0` la
      // fait rougir). Un `greaterThan(0)` resterait VERT sur `0` — d'où
      // `equals(1)`, et rien d'autre.
      expect(result.streak.current, equals(1));
      expect(result.streak.best, equals(12), reason: 'le RECORD survit au reset');
      expect(result.streak.lastGradedDay, equals(day));
    });

    test('trou d\'EXACTEMENT 2 jours civils ⇒ resetToOne (la borne)', () {
      const streak =
          ZStudyStreak(current: 8, best: 8, lastGradedDay: '2026-03-26');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.resetToOne));
      expect(result.streak.current, equals(1));
    });

    test('best = max(best, current) après application', () {
      const streak =
          ZStudyStreak(current: 9, best: 9, lastGradedDay: '2026-03-27');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.streak.current, equals(10));
      expect(result.streak.best, equals(10), reason: 'nouveau RECORD');
    });

    test('un lastGradedDay ILLISIBLE est traité comme « jamais noté » ⇒ started',
        () {
      // Défense en profondeur : `fromMap` nettoie déjà, mais une instance
      // construite en mémoire peut porter n'importe quoi (constructeur `const`).
      const streak =
          ZStudyStreak(current: 5, best: 5, lastGradedDay: 'pas-une-date');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.started));
      expect(result.streak.current, equals(1));
    });

    test('un civilDayOf FOU (jour illisible) ⇒ streak INCHANGÉ, aucun throw', () {
      const streak =
          ZStudyStreak(current: 6, best: 6, lastGradedDay: '2026-03-27');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: (_) => 'n/importe/quoi',
      );

      expect(result.outcome, equals(ZStreakOutcome.alreadyCountedToday));
      expect(result.streak, equals(streak));
    });

    test('l\'horloge par DÉFAUT est zLocalCivilDay (AD-14 : paramétrée, '
        'jamais capturée)', () {
      // On n'injecte PAS civilDayOf : le défaut doit être le jour civil LOCAL de
      // `at` — et `at` reste un PARAMÈTRE (aucun DateTime.now() dans le corps).
      final now = DateTime(2026, 5, 4, 8, 15);
      const streak = ZStudyStreak();

      final result =
          zAdvanceStreak(streak, at: now, mode: ZReviewMode.learn);

      expect(result.streak.lastGradedDay, equals('2026-05-04'));
      expect(result.outcome, equals(ZStreakOutcome.started));
    });
  });

  group('🔴 AC3 — les cas AUX BORNES du jour civil', () {
    test('23:59:59 → 00:00:01 le lendemain (2 s réelles) ⇒ jours DIFFÉRENTS '
        '⇒ incremented', () {
      final lastInstant = DateTime(2026, 3, 28, 23, 59, 59);
      final at = DateTime(2026, 3, 29, 0, 0, 1);
      final civilDayOf = _calendar(<DateTime, String>{
        lastInstant: '2026-03-28',
        at: '2026-03-29',
      });
      const streak =
          ZStudyStreak(current: 3, best: 3, lastGradedDay: '2026-03-28');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.incremented));
      expect(result.streak.current, equals(4));

      // 🔬 CONTRE-PREUVE : l'implémentation naïve (temps écoulé) voit 2 SECONDES
      // ⇒ 0 jour ⇒ elle croirait que c'est le MÊME jour. Elle DOIT diverger.
      expect(
        _naiveOutcomeByElapsed(lastInstant: lastInstant, at: at),
        equals(ZStreakOutcome.alreadyCountedToday),
        reason: '🔴 si la naïve rendait « incremented », ce cas ne prouverait '
            'RIEN sur l\'arithmétique civile',
      );
      expect(
        result.outcome,
        isNot(equals(_naiveOutcomeByElapsed(lastInstant: lastInstant, at: at))),
        reason: 'l\'arithmétique CIVILE et le TEMPS ÉCOULÉ divergent ici — '
            'c\'est exactement ce que la story exige de prouver',
      );
    });

    test('00:00:00 → 23:59:59 le MÊME jour (24 h réelles) ⇒ MÊME jour '
        '⇒ alreadyCountedToday', () {
      final lastInstant = DateTime(2026, 3, 28);
      final at = DateTime(2026, 3, 28, 23, 59, 59);
      final civilDayOf = _calendar(<DateTime, String>{
        lastInstant: '2026-03-28',
        at: '2026-03-28',
      });
      const streak =
          ZStudyStreak(current: 3, best: 5, lastGradedDay: '2026-03-28');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.alreadyCountedToday));
      expect(result.streak, equals(streak));
    });

    test('🔴 DST PRINTEMPS — un jour de 23 h : veille → lendemain ⇒ incremented '
        '(PAS resetToOne, PAS alreadyCountedToday)', () {
      // 🔴 JOURS CIVILS **MESURÉS**, pas choisis au hasard (rejoué sur disque
      // sous `TZ=Europe/Paris`, cf. Completion Notes) :
      //
      //   2026-03-28 -> 2026-03-29 : 24 h  (inDays=1)  ← NE discrimine PAS
      //   2026-03-29 -> 2026-03-30 : 23 h  (inDays=0)  ← LE jour de 23 h
      //
      // La bascule d'heure d'été a lieu à 02:00 le **dimanche 29 mars 2026** :
      // c'est donc le **29** qui ne dure que 23 h (00:00 CET → 00:00 le 30 CEST),
      // pas le 28. Mon premier jet visait 03-28 → 03-29 — deux minuits tous deux
      // à +1, soit **24 h** : l'injection R3 n'y rougissait PAS, et le test se
      // serait contenté d'AVOIR L'AIR de couvrir le DST.
      final lastInstant = DateTime(2026, 3, 29, 23, 30);
      final at = lastInstant.add(const Duration(hours: 23));
      final civilDayOf = _calendar(<DateTime, String>{
        lastInstant: '2026-03-29',
        at: '2026-03-30',
      });
      const streak =
          ZStudyStreak(current: 6, best: 6, lastGradedDay: '2026-03-29');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.incremented));
      expect(result.streak.current, equals(7));

      // 🔬 CONTRE-PREUVE R3 — l'implémentation INTERDITE, soumise au MÊME cas :
      // 23 h écoulées ⇒ `inDays == 0` ⇒ elle FIGERAIT la flamme. C'est LE bug que
      // `at.difference(...).inDays` introduit, et il est ici DÉMONTRÉ, pas
      // supposé.
      expect(
        _naiveOutcomeByElapsed(lastInstant: lastInstant, at: at),
        equals(ZStreakOutcome.alreadyCountedToday),
        reason: '🔴 `at.difference(o).inDays` rend 0 sur un jour de 23 h : la '
            'flamme cesserait d\'avancer, SANS exception ni test rouge ailleurs',
      );

      // 🔒 TZ-INDÉPENDANCE : cette assertion tient sous `TZ=UTC` comme sous
      // `TZ=Europe/Paris` (les deux REJOUÉS) — le calendrier est INJECTÉ, jamais
      // subi. Mais les jours choisis ci-dessus sont les VRAIS jours de bascule de
      // Paris : c'est ce qui rend l'injection R3 (`zCivilDayNumber` remplacé par
      // `difference().inDays`) RÉELLEMENT rouge sous `TZ=Europe/Paris` — vérifié.
    });

    test('🔴 DST AUTOMNE — un jour de 25 h : veille → lendemain ⇒ incremented '
        '(PAS alreadyCountedToday)', () {
      // 🔴 MESURÉ sous `TZ=Europe/Paris` : `2026-10-25 -> 2026-10-26` = **25 h**
      // (recul d'une heure à 03:00 le dimanche 25). C'est le jour de 25 h.
      //
      // ⚠️ **HONNÊTETÉ DE PORTÉE** : sur « veille → lendemain », `inDays` rend
      // `1` sur 25 h — donc l'implémentation naïve tombe JUSTE **par chance** ici.
      // Ce cas ne discrimine PAS à lui seul : c'est le test SUIVANT (25 h DANS le
      // même jour civil) qui attrape le jour de 25 h. Le prétendre discriminant
      // serait le genre d'affirmation jamais vérifiée que cet epic traque.
      final lastInstant = DateTime(2026, 10, 25, 23, 30);
      final at = lastInstant.add(const Duration(hours: 2));
      final civilDayOf = _calendar(<DateTime, String>{
        lastInstant: '2026-10-25',
        at: '2026-10-26',
      });
      const streak =
          ZStudyStreak(current: 2, best: 4, lastGradedDay: '2026-10-25');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.incremented));
      expect(result.streak.current, equals(3));
      expect(result.streak.best, equals(4));

      // 🔬 CONTRE-PREUVE : 2 h écoulées ⇒ `inDays == 0` ⇒ « déjà compté ».
      expect(
        _naiveOutcomeByElapsed(lastInstant: lastInstant, at: at),
        equals(ZStreakOutcome.alreadyCountedToday),
      );
    });

    test('🔴 un jour de 25 h ne fabrique PAS un faux « 1 jour » (25 h écoulées '
        'DANS le même jour civil ⇒ alreadyCountedToday)', () {
      // Le miroir du cas précédent : sur un jour de 25 h, 00:15 → 23:45 fait
      // **25 h RÉELLES** mais reste le MÊME jour civil. Le naïf rendrait
      // `inDays == 1` ⇒ « incremented » : il DOUBLERAIT la flamme en un jour.
      final lastInstant = DateTime(2026, 10, 25, 0, 15);
      final at = lastInstant.add(const Duration(hours: 25));
      final civilDayOf = _calendar(<DateTime, String>{
        lastInstant: '2026-10-25',
        at: '2026-10-25',
      });
      const streak =
          ZStudyStreak(current: 5, best: 5, lastGradedDay: '2026-10-25');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.alreadyCountedToday));
      expect(result.streak.current, equals(5), reason: 'aucun double-compte');

      // 🔬 CONTRE-PREUVE : 25 h ⇒ `inDays == 1` ⇒ la naïve incrémenterait.
      expect(
        _naiveOutcomeByElapsed(lastInstant: lastInstant, at: at),
        equals(ZStreakOutcome.incremented),
        reason: '🔴 `inDays` rend 1 sur 25 h : la flamme avancerait DEUX fois le '
            'même jour civil',
      );
    });

    test('🔴 date FUTURE persistée (horloge reculée) ⇒ aucun throw, aucun '
        'current négatif, repli alreadyCountedToday', () {
      final at = DateTime(2026, 3, 28, 10);
      final civilDayOf = _calendar(<DateTime, String>{at: '2026-03-28'});
      const streak =
          ZStudyStreak(current: 3, best: 7, lastGradedDay: '2026-04-15');

      final result = zAdvanceStreak(
        streak,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.alreadyCountedToday));
      expect(result.streak, equals(streak));
      expect(result.streak.current, greaterThanOrEqualTo(0));
      expect(result.streak.current, equals(3));
    });

    test('🔴 IDEMPOTENCE — rejouer N fois le MÊME instant rend STRICTEMENT le '
        'même streak (doublons / désordre)', () {
      final at = DateTime(2026, 3, 29, 9);
      final civilDayOf = _calendar(<DateTime, String>{at: '2026-03-29'});
      const initial =
          ZStudyStreak(current: 3, best: 3, lastGradedDay: '2026-03-28');

      final first = zAdvanceStreak(
        initial,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );
      expect(first.outcome, equals(ZStreakOutcome.incremented));
      expect(first.streak.current, equals(4));

      // Rejoué 5 fois : le streak ne bouge PLUS d'un cran.
      var streak = first.streak;
      for (var i = 0; i < 5; i++) {
        final again = zAdvanceStreak(
          streak,
          at: at,
          mode: ZReviewMode.spaced,
          civilDayOf: civilDayOf,
        );
        expect(again.outcome, equals(ZStreakOutcome.alreadyCountedToday));
        expect(again.streak, equals(first.streak));
        streak = again.streak;
      }
      expect(streak.current, equals(4), reason: '🔴 jamais 9 : idempotent');
    });

    test('séquence DÉSORDONNÉE (hier rejoué APRÈS aujourd\'hui) ⇒ jamais de '
        'régression ni de throw', () {
      final today = DateTime(2026, 3, 29, 9);
      final yesterday = DateTime(2026, 3, 28, 9);
      final civilDayOf = _calendar(<DateTime, String>{
        today: '2026-03-29',
        yesterday: '2026-03-28',
      });
      const initial =
          ZStudyStreak(current: 3, best: 3, lastGradedDay: '2026-03-28');

      final advanced = zAdvanceStreak(
        initial,
        at: today,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );
      expect(advanced.streak.current, equals(4));

      // Un événement d'HIER arrive en retard : le jour persisté est « futur ».
      final late = zAdvanceStreak(
        advanced.streak,
        at: yesterday,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(late.outcome, equals(ZStreakOutcome.alreadyCountedToday));
      expect(late.streak, equals(advanced.streak));
      expect(late.streak.current, equals(4));
    });
  });

  group('🔴 AC2/LOW-3 — « current jamais négatif » vaut pour TOUTES les voies', () {
    final at = DateTime(2026, 3, 29, 9);
    final civilDayOf = _calendar(<DateTime, String>{at: '2026-03-29'});

    test('🔴 la branche `incremented` PLANCHE une entrée négative à 1 (elle '
        'faisait `current + 1` NU)', () {
      // Le constructeur est `const` SANS assert (AD-10) et le `copyWith` généré
      // est public : un négatif est CONSTRUCTIBLE en mémoire. La dartdoc de
      // `ZStudyStreak.current` promet « Jamais négatif — garanti par
      // `zAdvanceStreak` » ; sans plancher, J+1 rendait **-4**, que
      // `ZStreakBadge` AFFICHE et annonce (`Semantics(value: '-4')`).
      const corrupted =
          ZStudyStreak(current: -5, best: 0, lastGradedDay: '2026-03-28');

      final result = zAdvanceStreak(
        corrupted,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.incremented));
      expect(result.streak.current, equals(1),
          reason: '🔴 -5 + 1 = -4 : une série NÉGATIVE affichée par le badge');
      expect(result.streak.current, isNonNegative);
    });

    test('🔒 le plancher ne touche PAS le chemin nominal (il ne fait que '
        'planchers)', () {
      // Anti-vacuité : un plancher écrit `next = 1` inconditionnellement
      // passerait le test ci-dessus ET casserait toute progression. Ici la
      // série DOIT bien avancer.
      const healthy =
          ZStudyStreak(current: 3, best: 7, lastGradedDay: '2026-03-28');

      final result = zAdvanceStreak(
        healthy,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: civilDayOf,
      );

      expect(result.streak.current, equals(4));
      expect(result.streak.best, equals(7));
    });

    test('🔒 le calendrier du test est BRUYANT sur un instant non cartographié '
        '(jamais un faux vert — LOW-5)', () {
      // Contre-preuve R3 du HARNAIS : le repli `'<inconnu>'` d'origine rendait
      // `alreadyCountedToday` — soit l'issue attendue de 5 tests. Un lookup raté
      // les laissait VERTS en ne testant plus rien.
      expect(
        () => _calendar(<DateTime, String>{at: '2026-03-29'})(
          DateTime(2026, 3, 29, 9, 0, 0, 500),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('AC4 — le streak n\'avance QUE sur une répétition NOTÉE', () {
    final at = DateTime(2026, 3, 29, 9);
    final civilDayOf = _calendar(<DateTime, String>{at: '2026-03-29'});
    const before = ZStudyStreak(current: 3, best: 7, lastGradedDay: '2026-03-28');

    test('🔴 ZReviewMode.values est ÉNUMÉRÉ — un 7ᵉ mode CASSERA ce test tant '
        'qu\'il n\'est pas classé', () {
      // La liste n'est JAMAIS recopiée : elle est dérivée de l'enum RÉEL.
      const graded = <ZReviewMode>{ZReviewMode.spaced, ZReviewMode.learn};

      // Méta-garde : l'enum réel a bien 6 valeurs, et `listOnly` N'EXISTE PAS
      // (c'est une coquille du sprint-status — écart E1).
      expect(ZReviewMode.values, hasLength(6));
      expect(
        ZReviewMode.values.map((m) => m.name),
        containsAll(<String>[
          'spaced',
          'learn',
          'list',
          'test',
          'whiteExam',
          'cramming',
        ]),
      );

      for (final mode in ZReviewMode.values) {
        final result = zAdvanceStreak(
          before,
          at: at,
          mode: mode,
          civilDayOf: civilDayOf,
        );

        if (graded.contains(mode)) {
          expect(
            result.outcome,
            equals(ZStreakOutcome.incremented),
            reason: '$mode écrit du SRS ⇒ la flamme DOIT avancer (AD-34)',
          );
          expect(result.streak.current, equals(4));
        } else {
          expect(
            result.outcome,
            equals(ZStreakOutcome.skippedNotGraded),
            reason: '$mode n\'écrit AUCUN SRS ⇒ la flamme NE DOIT PAS avancer',
          );
          // 🔴 Assertion sur l'OBJET ENTIER (pas seulement `current`) :
          // l'injection R3 « faire avancer le streak en `list` » rougit ici.
          expect(
            result.streak,
            equals(before),
            reason: '$mode : le streak doit être STRICTEMENT inchangé',
          );
        }
      }
    });

    test('la CONSULTATION (ZReviewMode.list) ne fait PAS avancer la flamme', () {
      final result = zAdvanceStreak(
        before,
        at: at,
        mode: ZReviewMode.list,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.skippedNotGraded));
      expect(result.streak, equals(before));
      expect(result.streak.current, equals(3), reason: 'jamais 4');
    });

    test('zIsGradedMode classe les 6 modes réels (D6)', () {
      expect(zIsGradedMode(ZReviewMode.spaced), isTrue);
      expect(zIsGradedMode(ZReviewMode.learn), isTrue);
      expect(zIsGradedMode(ZReviewMode.list), isFalse);
      expect(zIsGradedMode(ZReviewMode.test), isFalse);
      expect(zIsGradedMode(ZReviewMode.whiteExam), isFalse);
      expect(zIsGradedMode(ZReviewMode.cramming), isFalse);
    });

    test('un mode non noté sur un streak VIERGE ne le démarre pas', () {
      const vierge = ZStudyStreak();

      final result = zAdvanceStreak(
        vierge,
        at: at,
        mode: ZReviewMode.list,
        civilDayOf: civilDayOf,
      );

      expect(result.outcome, equals(ZStreakOutcome.skippedNotGraded));
      expect(result.streak.current, equals(0));
      expect(result.streak.lastGradedDay, isNull);
    });
  });

  group('AC15 — enums, jamais de booléens', () {
    test('ZStreakOutcome porte les 5 issues nommées', () {
      expect(ZStreakOutcome.values, hasLength(5));
      expect(
        ZStreakOutcome.values.map((o) => o.name),
        containsAll(<String>[
          'started',
          'incremented',
          'alreadyCountedToday',
          'resetToOne',
          'skippedNotGraded',
        ]),
      );
    });

    test('ZStreakAdvance : égalité de valeur', () {
      const a = ZStreakAdvance(
        streak: ZStudyStreak(current: 1, best: 1, lastGradedDay: '2026-03-28'),
        outcome: ZStreakOutcome.started,
      );
      const b = ZStreakAdvance(
        streak: ZStudyStreak(current: 1, best: 1, lastGradedDay: '2026-03-28'),
        outcome: ZStreakOutcome.started,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
