// Tests DISCRIMINANTS ES-5.4 — `ZFeatureAvailability` (AC1..AC4).
//
// AC1 [CENTRAL] : composition AD-4 — une feature indisponible n'est ni
//   actionnable ni rendue (via gate ⇒ onTap:null / enabledFor ⇒ enabled:false,
//   sur les surfaces ES-5.3 EXISTANTES). Discriminant R3-I1.
// AC2 [CENTRAL] : défaut fail-open (D1) sans injection. Discriminant R3-I2.
// AC3 : interface INJECTABLE — deux apps roadmaps différentes, ZÉRO modif de
//   zcrud_study (SM-SC2). Discriminants R3-I3 (scope) et R3-I4 (config honorée).
// AC4 : invariants (const-compatibilité, @immutable, updateShouldNotify).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

const IconData kNoteIcon = Icons.note_add;
const IconData kExamIcon = Icons.quiz;
const String kNoteKey = 'note';
const String kExamKey = 'exam';
const String kNoteLabel = 'NOTE-XYZ';
const String kExamLabel = 'EXAM-XYZ';

Widget _wrap(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: dir,
      child: ZcrudScope(child: Scaffold(body: Center(child: child))),
    ),
  );
}

void main() {
  // ── AC1 [CENTRAL] — composition gating (unité) ──────────────────────────
  group('AC1 — gate/enabledFor relaient isAvailable (composition AD-4)', () {
    const fa = ZMapFeatureAvailability({kNoteKey: true, kExamKey: false});

    test('feature DISPONIBLE : gate renvoie le callback (identité), enabledFor true', () {
      void cb() {}
      expect(fa.gate(kNoteKey, cb), same(cb),
          reason: 'disponible ⇒ gate relaie le callback tel quel');
      expect(fa.enabledFor(kNoteKey), isTrue);
    });

    test('feature INDISPONIBLE : gate renvoie null, enabledFor false', () {
      void cb() {}
      expect(fa.gate(kExamKey, cb), isNull,
          reason: 'indisponible ⇒ gate ⇒ null (surface non actionnable/absente)');
      expect(fa.enabledFor(kExamKey), isFalse);
    });

    test('gate préserve un callback null (rien à relayer)', () {
      expect(fa.gate(kNoteKey, null), isNull);
    });
  });

  // ── AC1 [CENTRAL] — composition sur ZContentHubSheet (rendu ES-5.3) ──────
  testWidgets(
      'AC1 : hub composé via gate/enabledFor — note actionnable (tap=1), exam désactivée (tap=0)',
      (tester) async {
    const fa = ZMapFeatureAvailability({kNoteKey: true, kExamKey: false});
    var noteTaps = 0;
    var examTaps = 0;

    await tester.pumpWidget(_wrap(ZContentHubSheet(
      entries: [
        ZContentHubEntry(
          icon: kNoteIcon,
          label: kNoteLabel,
          enabled: fa.enabledFor(kNoteKey),
          onTap: fa.gate(kNoteKey, () => noteTaps++),
        ),
        ZContentHubEntry(
          icon: kExamIcon,
          label: kExamLabel,
          enabled: fa.enabledFor(kExamKey),
          onTap: fa.gate(kExamKey, () => examTaps++),
        ),
      ],
    )));

    // Les deux tuiles sont rendues (aucun nouveau chemin de rendu) ...
    expect(find.text(kNoteLabel), findsOneWidget);
    expect(find.text(kExamLabel), findsOneWidget);

    // ... mais seule 'note' est actionnable.
    await tester.tap(find.text(kNoteLabel));
    await tester.pump();
    await tester.tap(find.text(kExamLabel));
    await tester.pump();

    expect(noteTaps, 1, reason: 'feature disponible : tuile actionnable');
    // R3-I1 : si gate/enabledFor ignoraient isAvailable, examTaps deviendrait 1.
    expect(examTaps, 0,
        reason: 'feature indisponible : tuile désactivée (onTap null, AD-4)');
  });

  // ── AC1 [CENTRAL] — composition sur ZItemActionsMenu (action absente) ────
  testWidgets(
      'AC1 : menu composé via gate — action exam ABSENTE (onSelected null filtrée), note PRÉSENTE',
      (tester) async {
    const fa = ZMapFeatureAvailability({kNoteKey: true, kExamKey: false});

    await tester.pumpWidget(_wrap(ZItemActionsMenu(
      tooltip: 'MENU-XYZ',
      actions: [
        ZItemAction(
          kind: ZItemActionKind.open,
          label: kNoteLabel,
          icon: kNoteIcon,
          onSelected: fa.gate(kNoteKey, () {}),
        ),
        ZItemAction(
          kind: ZItemActionKind.delete,
          label: kExamLabel,
          icon: kExamIcon,
          onSelected: fa.gate(kExamKey, () {}),
        ),
      ],
    )));

    await tester.tap(find.byType(ZItemActionsMenu));
    await tester.pumpAndSettle();

    expect(find.text(kNoteLabel), findsOneWidget,
        reason: 'feature disponible : action présente au menu');
    // R3-I1 : si gate renvoyait le callback pour exam, l'action réapparaîtrait.
    expect(find.text(kExamLabel), findsNothing,
        reason: 'feature indisponible : onSelected null ⇒ action ABSENTE (AD-4)');
  });

  // ── AC2 [CENTRAL] — défaut fail-open (D1) ───────────────────────────────
  group('AC2 — défaut fail-open (D1)', () {
    test('ZAllFeaturesAvailable : toute clé disponible', () {
      const fa = ZAllFeaturesAvailable();
      expect(fa.isAvailable('anything'), isTrue);
      expect(fa.isAvailable(''), isTrue);
      expect(fa.enabledFor('x'), isTrue);
      void cb() {}
      expect(fa.gate('x', cb), same(cb));
    });

    testWidgets('of(context) SANS ancêtre ⇒ ZAllFeaturesAvailable (fail-open), maybeOf null',
        (tester) async {
      late ZFeatureAvailability resolved;
      late ZFeatureAvailability? resolvedMaybe;
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        resolved = ZFeatureAvailabilityScope.of(context);
        resolvedMaybe = ZFeatureAvailabilityScope.maybeOf(context);
        return const SizedBox.shrink();
      })));

      // R3-I2/R3-I3 : un repli fail-safe (tout masqué) ferait rougir ceci.
      expect(resolved.isAvailable('whatever'), isTrue,
          reason: 'aucune injection ⇒ fail-open (D1), jamais fail-safe');
      expect(resolved, isA<ZAllFeaturesAvailable>());
      expect(resolvedMaybe, isNull,
          reason: 'maybeOf distingue « aucune injection » du repli de of()');
    });

    test('ZMapFeatureAvailability : clé absente ⇒ availableWhenUnspecified', () {
      const failOpen = ZMapFeatureAvailability({'x': true});
      // R3-I2 : un défaut `?? false` ferait rougir ceci.
      expect(failOpen.isAvailable('y'), isTrue,
          reason: 'clé absente ⇒ défaut availableWhenUnspecified=true (fail-open)');

      const failSafe =
          ZMapFeatureAvailability({'x': true}, availableWhenUnspecified: false);
      expect(failSafe.isAvailable('y'), isFalse,
          reason: 'politique fail-safe LOCALE opt-in (availableWhenUnspecified:false)');
      expect(failSafe.isAvailable('x'), isTrue,
          reason: 'clé présente : la valeur explicite prime sur le défaut local');
    });
  });

  // ── AC3 — interface INJECTABLE, SM-SC2 (deux roadmaps, zéro modif) ───────
  group('AC3 — injectabilité SM-SC2', () {
    const appA = ZMapFeatureAvailability({kNoteKey: true, kExamKey: false});
    const appB = ZMapFeatureAvailability({kNoteKey: false, kExamKey: true});

    // MÊME logique de lecture, réutilisée sous chaque scope (aucune duplication).
    Map<String, bool> read(ZFeatureAvailability fa) => {
          kNoteKey: fa.isAvailable(kNoteKey),
          kExamKey: fa.isAvailable(kExamKey),
        };

    test('deux configs distinctes ⇒ résultats OPPOSÉS (unité)', () {
      final resA = read(appA);
      final resB = read(appB);
      // R3-I4 : si isAvailable ignorait flags, resA == resB ⇒ rougit.
      expect(resA, isNot(resB));
      expect(resA, {kNoteKey: true, kExamKey: false});
      expect(resB, {kNoteKey: false, kExamKey: true});
    });

    testWidgets('MÊME code de lecture sous scope A vs scope B ⇒ résultats opposés',
        (tester) async {
      late Map<String, bool> underA;
      late Map<String, bool> underB;

      Widget reader(void Function(Map<String, bool>) sink) => Builder(
            builder: (context) {
              sink(read(ZFeatureAvailabilityScope.of(context)));
              return const SizedBox.shrink();
            },
          );

      await tester.pumpWidget(_wrap(Column(children: [
        ZFeatureAvailabilityScope(
          availability: appA,
          child: reader((r) => underA = r),
        ),
        ZFeatureAvailabilityScope(
          availability: appB,
          child: reader((r) => underB = r),
        ),
      ])));

      // R3-I3 : si of() ignorait l'ancêtre injecté, underA == underB ⇒ rougit.
      expect(underA, {kNoteKey: true, kExamKey: false});
      expect(underB, {kNoteKey: false, kExamKey: true});
      expect(underA, isNot(underB));
    });
  });

  // ── AC4 — invariants (const-compatibilité, égalité, updateShouldNotify) ──
  group('AC4 — invariants', () {
    test('const-compatibilité : instances const identiques canonicalisées', () {
      const a1 = ZAllFeaturesAvailable();
      const a2 = ZAllFeaturesAvailable();
      expect(identical(a1, a2), isTrue);
      const m1 = ZMapFeatureAvailability({'k': true});
      const m2 = ZMapFeatureAvailability({'k': true});
      expect(identical(m1, m2), isTrue);
    });

    test('ZMapFeatureAvailability : égalité PROFONDE (SM-SC2, mapEquals)', () {
      // Deux maps de contenu identique mais instances distinctes ⇒ égales.
      final flagsA = {'k': true, 'j': false};
      final flagsB = {'k': true, 'j': false};
      expect(identical(flagsA, flagsB), isFalse);
      final a = ZMapFeatureAvailability(flagsA);
      final b = ZMapFeatureAvailability(flagsB);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      // Contenus différents ⇒ inégaux.
      expect(a, isNot(const ZMapFeatureAvailability({'k': false, 'j': false})));
      expect(
        a,
        isNot(ZMapFeatureAvailability(flagsA, availableWhenUnspecified: false)),
      );
    });

    testWidgets('updateShouldNotify : true SSI la config injectée change',
        (tester) async {
      const a = ZFeatureAvailabilityScope(
        availability: ZMapFeatureAvailability({'k': true}),
        child: SizedBox.shrink(),
      );
      const bSame = ZFeatureAvailabilityScope(
        availability: ZMapFeatureAvailability({'k': true}),
        child: SizedBox.shrink(),
      );
      const bDiff = ZFeatureAvailabilityScope(
        availability: ZMapFeatureAvailability({'k': false}),
        child: SizedBox.shrink(),
      );
      expect(a.updateShouldNotify(bSame), isFalse,
          reason: 'même config (égalité profonde) ⇒ pas de notification');
      expect(a.updateShouldNotify(bDiff), isTrue,
          reason: 'config différente ⇒ notification');
    });
  });
}
