// AC3 : réactivité granulaire par tranche du `ZFormController` (cœur de SM-1).
// `flutter_test` : le package est désormais Flutter.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZFormController — tranches stables & réactivité ciblée', () {
    test('fieldListenable(name) renvoie TOUJOURS la même instance (AC3)', () {
      final c = ZFormController();
      final a1 = c.fieldListenable('a');
      final a2 = c.fieldListenable('a');
      expect(identical(a1, a2), isTrue);
      c.dispose();
    });

    test('setValue notifie SEULEMENT la tranche ciblée (AC3)', () {
      final c = ZFormController(initialValues: {'a': null, 'b': null});
      var aNotified = 0;
      var bNotified = 0;
      c.fieldListenable('a').addListener(() => aNotified++);
      c.fieldListenable('b').addListener(() => bNotified++);

      c.setValue('a', 'x');
      expect(aNotified, 1);
      expect(bNotified, 0, reason: 'la tranche voisine ne doit pas être notifiée');
      expect(c.valueOf('a'), 'x');
      expect(c.valueOf('b'), isNull);
      c.dispose();
    });

    test('poser la même valeur (==) est un no-op (AC3)', () {
      final c = ZFormController(initialValues: {'a': 'x'});
      var aNotified = 0;
      c.fieldListenable('a').addListener(() => aNotified++);
      c.setValue('a', 'x'); // identique → no-op ValueNotifier
      expect(aNotified, 0);
      c.setValue('a', 'y');
      expect(aNotified, 1);
      c.dispose();
    });

    test('setValue ne déclenche JAMAIS le notifyListeners global (AC3/SM-1)', () {
      final c = ZFormController(initialValues: {'a': null});
      var globalNotified = 0;
      c.addListener(() => globalNotified++);
      for (var i = 0; i < 25; i++) {
        c.setValue('a', 'v$i');
      }
      expect(globalNotified, 0,
          reason: 'aucun rebuild global sur un changement de valeur');
      c.dispose();
    });

    test('visibleFields est le SEUL canal du notifyListeners global (AC3)', () {
      final c = ZFormController(
        initialValues: {'a': null},
        visibleFields: ['a'],
      );
      var globalNotified = 0;
      var structuralNotified = 0;
      c.addListener(() => globalNotified++);
      c.visibleFields.addListener(() => structuralNotified++);

      expect(c.visibleFields.value, ['a']);
      c.setVisibleFields(['a', 'b']);
      expect(globalNotified, 1);
      expect(structuralNotified, 1);
      expect(c.visibleFields.value, ['a', 'b']);

      // Même ensemble → no-op (ni global ni structurel).
      c.setVisibleFields(['a', 'b']);
      expect(globalNotified, 1);
      expect(structuralNotified, 1);
      c.dispose();
    });

    test('fieldListenable(nameInconnu) crée paresseusement et mémoïse (AC3)', () {
      final c = ZFormController();
      final l = c.fieldListenable('nouveau');
      expect(l, isA<ValueListenable<Object?>>());
      expect(c.valueOf('nouveau'), isNull);
      expect(identical(c.fieldListenable('nouveau'), l), isTrue);
      c.dispose();
    });

    test('dispose libère toutes les tranches (AC3)', () {
      final c = ZFormController(initialValues: {'a': null, 'b': null});
      final a = c.fieldListenable('a') as ValueNotifier<Object?>;
      c.dispose();
      // Un ValueNotifier disposé lève sur addListener (en debug/assert).
      expect(() => a.addListener(() {}), throwsA(isA<Object>()));
    });
  });
}
