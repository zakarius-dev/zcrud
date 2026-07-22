// CR-IFFD-17 — le canonique ne portait qu'UN des deux modèles de récurrence.
//
// `reminderDaysBefore` exprime « N jours AVANT l'échéance » (relatif). Le modèle
// « ces jours de la SEMAINE » (absolu-hebdomadaire) n'était pas exprimable, et
// les deux ne sont pas inter-convertibles : un lundi n'est pas « k jours avant »
// quelque chose. Une app hebdomadaire logeait sa donnée dans `extra`, où elle
// survivait mais devenait INVISIBLE à `isApproaching` — muette vis-à-vis d'une
// fonction que le socle est censé porter.
import 'package:test/test.dart';
import 'package:zcrud_exam/zcrud_exam.dart';

/// Mercredi 15 juillet 2026, 10 h — horloge INJECTÉE (D5), jamais `DateTime.now()`.
final DateTime _mercredi = DateTime(2026, 7, 15, 10);

void main() {
  group('CR-IFFD-17 — les deux familles sont exprimables', () {
    test('🔴 hebdomadaire : « tous les mercredis » déclenche SANS échéance', () {
      // Discriminant : c'est le cas que le socle ne savait pas représenter. Sans
      // `dueDate`, l'ancien modèle rendait toujours `false`.
      const r = ZReminderRecurrence.weekly(<int>{DateTime.wednesday});
      expect(r.matches(now: _mercredi, dueDate: null), isTrue);
    });

    test('hebdomadaire : un autre jour ne déclenche pas', () {
      const r = ZReminderRecurrence.weekly(<int>{DateTime.monday});
      expect(r.matches(now: _mercredi, dueDate: null), isFalse);
    });

    test('relatif : « 7 jours avant » déclenche dans la fenêtre', () {
      const r = ZReminderRecurrence.relative(<int>[7]);
      expect(
        r.matches(now: _mercredi, dueDate: DateTime(2026, 7, 20)),
        isTrue,
      );
      expect(
        r.matches(now: _mercredi, dueDate: DateTime(2026, 8, 30)),
        isFalse,
      );
    });

    test('relatif SANS échéance est inévaluable — jamais un faux positif', () {
      const r = ZReminderRecurrence.relative(<int>[7]);
      expect(r.matches(now: _mercredi, dueDate: null), isFalse);
    });

    test('🔴 les deux familles se COMBINENT en OU', () {
      // « tous les lundis ET la veille » : deux demandes distinctes, satisfaites
      // dès que l'une correspond.
      const r = ZReminderRecurrence(
        daysBefore: <int>[1],
        weekdays: <int>{DateTime.monday},
      );
      // Mercredi, échéance dans 5 jours : ni lundi, ni la veille.
      expect(r.matches(now: _mercredi, dueDate: DateTime(2026, 7, 20)), isFalse);
      // Mercredi, échéance demain : la branche relative mord.
      expect(r.matches(now: _mercredi, dueDate: DateTime(2026, 7, 16)), isTrue);
    });

    test('une échéance PASSÉE n\'arme aucune des deux familles', () {
      // Décision explicite : rappeler chaque mercredi un examen déjà passé n'a
      // pas de sens, et cela préserve le comportement historique.
      const r = ZReminderRecurrence(
        daysBefore: <int>[7],
        weekdays: <int>{DateTime.wednesday},
      );
      expect(r.matches(now: _mercredi, dueDate: DateTime(2026, 7, 1)), isFalse);
    });

    test('une récurrence VIDE ne déclenche jamais', () {
      const r = ZReminderRecurrence();
      expect(r.isEmpty, isTrue);
      expect(r.matches(now: _mercredi, dueDate: DateTime(2026, 7, 16)), isFalse);
    });

    test('🔴 le seuil compte en jours CALENDAIRES, pas en durée', () {
      // Sans normalisation à minuit, « demain 8 h » vu depuis « aujourd'hui 20 h »
      // ferait 0 jour (moins de 24 h) et un seuil « la veille » raterait sa cible.
      const r = ZReminderRecurrence.relative(<int>[1]);
      expect(
        r.matches(
          now: DateTime(2026, 7, 15, 20),
          dueDate: DateTime(2026, 7, 16, 8),
        ),
        isTrue,
      );
    });
  });

  group('CR-IFFD-17 — `ZExam` voit désormais le modèle hebdomadaire', () {
    test('🔴 isApproaching mord sur une récurrence hebdomadaire', () {
      // LE cas de la CR : avant, cette donnée vivait dans `extra` et
      // `isApproaching` rendait TOUJOURS false.
      const exam = ZExam(
        title: 'Révision',
        reminderEnabled: true,
        reminderRecurrence:
            ZReminderRecurrence.weekly(<int>{DateTime.wednesday}),
      );
      expect(exam.isApproaching(_mercredi), isTrue);
    });

    test('🔴 RÉTRO-COMPATIBLE : sans le nouveau slot, rien ne change', () {
      final exam = ZExam(
        title: 'Partiel',
        date: DateTime(2026, 7, 20),
        reminderEnabled: true,
        reminderDaysBefore: const <int>[7],
      );
      expect(exam.reminderRecurrence, isNull);
      expect(exam.isApproaching(_mercredi), isTrue);
      expect(exam.isApproaching(DateTime(2026, 6, 1)), isFalse);
    });

    test('`reminderEnabled: false` neutralise TOUT', () {
      const exam = ZExam(
        reminderEnabled: false,
        reminderRecurrence:
            ZReminderRecurrence.weekly(<int>{DateTime.wednesday}),
      );
      expect(exam.isApproaching(_mercredi), isFalse);
    });

    test('🔴 la récurrence explicite REMPLACE les seuils bruts', () {
      // Décision documentée : additionner les deux sources ferait déclencher des
      // rappels que l'hôte n'a pas demandés au moment où il migre.
      final exam = ZExam(
        date: DateTime(2026, 7, 20),
        reminderEnabled: true,
        reminderDaysBefore: const <int>[30], // large : mordrait seul
        reminderRecurrence:
            const ZReminderRecurrence.weekly(<int>{DateTime.monday}),
      );
      expect(exam.isApproaching(_mercredi), isFalse,
          reason: 'les seuils bruts ne doivent plus être consultés');
      expect(exam.effectiveReminderRecurrence.daysBefore, isEmpty);
    });
  });

  group('CR-IFFD-17 — persistance (AD-10, round-trip)', () {
    test('round-trip toMap/fromMap préserve la récurrence', () {
      const exam = ZExam(
        title: 'Oral',
        reminderEnabled: true,
        reminderRecurrence: ZReminderRecurrence(
          daysBefore: <int>[1, 7],
          weekdays: <int>{DateTime.monday, DateTime.friday},
        ),
      );
      final back = ZExam.fromMap(exam.toMap());
      expect(back.reminderRecurrence, exam.reminderRecurrence);
    });

    test('🔴 la clé RÉSERVÉE ne pollue jamais `extra`', () {
      // Sans l'ajout à `_reservedKeys`, elle atterrirait dans `extra` ET serait
      // réémise en double par `toMap` — le défaut exact que `reminder_time`
      // avait déjà rencontré.
      final back = ZExam.fromMap(<String, dynamic>{
        'title': 'x',
        kReminderRecurrenceKey: <String, dynamic>{
          'weekdays': <int>[1],
        },
      });
      expect(back.extra.containsKey(kReminderRecurrenceKey), isFalse);
      expect(back.reminderRecurrence, isNotNull);
    });

    test('un slot VIDE n\'est pas persisté (round-trip idempotent)', () {
      const exam = ZExam(reminderRecurrence: ZReminderRecurrence());
      expect(exam.toMap().containsKey(kReminderRecurrenceKey), isFalse);
      expect(ZExam.fromMap(exam.toMap()).reminderRecurrence, isNull);
    });

    test('🔴 AD-10 — une récurrence CORROMPUE ne fait jamais échouer le parent',
        () {
      for (final corrupt in <Object?>[
        'pas une map',
        42,
        <String, dynamic>{'weekdays': 'lundi'},
        <String, dynamic>{'days_before': <Object?>[null, 'x', -3]},
        <String, dynamic>{'weekdays': <Object?>[0, 8, 99]},
      ]) {
        final back = ZExam.fromMap(<String, dynamic>{
          'title': 'survivant',
          kReminderRecurrenceKey: corrupt,
        });
        expect(back.title, 'survivant');
        expect(back.reminderRecurrence, isNull,
            reason: 'rien d\'exploitable ⇒ slot absent, jamais un throw');
      }
    });

    test('les valeurs valides SURVIVENT à côté des corrompues', () {
      // Un seuil corrompu ne doit pas effacer les autres.
      final back = ZExam.fromMap(<String, dynamic>{
        kReminderRecurrenceKey: <String, dynamic>{
          'days_before': <Object?>[7, 'x', null, 1],
          'weekdays': <Object?>[3, 99],
        },
      });
      expect(back.reminderRecurrence!.daysBefore, <int>[7, 1]);
      expect(back.reminderRecurrence!.weekdays, <int>{3});
    });

    test('sortie DÉTERMINISTE : les jours sont triés', () {
      const r = ZReminderRecurrence.weekly(<int>{5, 1, 3});
      expect(r.toJson()['weekdays'], <int>[1, 3, 5]);
    });
  });

  group('CR-IFFD-17 — égalité et copie', () {
    test('copyWith PRÉSERVE la récurrence quand elle est omise', () {
      // Perte silencieuse classique (finding H3 de ce fichier) : un paramètre
      // déclaré mais non câblé remettrait le champ à son défaut.
      const exam = ZExam(
        reminderRecurrence:
            ZReminderRecurrence.weekly(<int>{DateTime.tuesday}),
      );
      expect(exam.copyWith(title: 'autre').reminderRecurrence,
          exam.reminderRecurrence);
    });

    test('copyWith(null) remet bien à `null` (sentinelle)', () {
      const exam = ZExam(
        reminderRecurrence:
            ZReminderRecurrence.weekly(<int>{DateTime.tuesday}),
      );
      expect(exam.copyWith(reminderRecurrence: null).reminderRecurrence, isNull);
    });

    test('l\'égalité de ZExam tient compte de la récurrence', () {
      const a = ZExam(
        reminderRecurrence: ZReminderRecurrence.weekly(<int>{1}),
      );
      const b = ZExam(
        reminderRecurrence: ZReminderRecurrence.weekly(<int>{2}),
      );
      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('les jours de semaine sont NON ordonnés pour l\'égalité', () {
      const a = ZReminderRecurrence.weekly(<int>{1, 3});
      const b = ZReminderRecurrence.weekly(<int>{3, 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
