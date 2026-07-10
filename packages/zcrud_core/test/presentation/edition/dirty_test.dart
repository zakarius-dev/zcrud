// E3-6 — Détection dirty (AC7, AC8).
//
// isDirty dérivé d'une baseline : propre → dirty → propre ; markPristine/reset ;
// toggle UNIQUE au flip ; jamais de notification globale (SM-1 côté contrôleur).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('AC7 — propre → dirty → propre (retour baseline)', () {
    final c = ZFormController(initialValues: <String, Object?>{'a': 1});
    addTearDown(c.dispose);

    expect(c.isDirty.value, isFalse);
    c.setValue('a', 2);
    expect(c.isDirty.value, isTrue);
    c.setValue('a', 1); // retour à la baseline
    expect(c.isDirty.value, isFalse);
  });

  test('AC7 — markPristine re-capture la baseline (dirty=false)', () {
    final c = ZFormController(initialValues: <String, Object?>{'a': 1});
    addTearDown(c.dispose);

    c.setValue('a', 2);
    expect(c.isDirty.value, isTrue);
    c.markPristine();
    expect(c.isDirty.value, isFalse);
    // La nouvelle baseline est 2 : y revenir n'est plus dirty.
    c.setValue('a', 3);
    expect(c.isDirty.value, isTrue);
    c.setValue('a', 2);
    expect(c.isDirty.value, isFalse);
  });

  test('AC7 — reset restaure la baseline et efface dirty', () {
    final c = ZFormController(initialValues: <String, Object?>{'a': 1, 'b': 'x'});
    addTearDown(c.dispose);

    c.setValue('a', 99);
    c.setValue('b', 'y');
    expect(c.isDirty.value, isTrue);

    c.reset();
    expect(c.isDirty.value, isFalse);
    expect(c.valueOf('a'), 1);
    expect(c.valueOf('b'), 'x');
  });

  test('AC7 — multi-champs : dirty tant qu\'un champ diverge', () {
    final c = ZFormController(initialValues: <String, Object?>{'a': 1, 'b': 2});
    addTearDown(c.dispose);

    c.setValue('a', 10);
    c.setValue('b', 20);
    expect(c.isDirty.value, isTrue);
    c.setValue('a', 1); // a revient ; b diverge encore
    expect(c.isDirty.value, isTrue);
    c.setValue('b', 2); // tous revenus
    expect(c.isDirty.value, isFalse);
  });

  test('AC8 — isDirty ne bascule qu\'UNE fois (au 1er écart) sur écritures successives', () {
    final c = ZFormController(initialValues: <String, Object?>{'a': ''});
    addTearDown(c.dispose);

    var toggles = 0;
    c.isDirty.addListener(() => toggles++);

    c.setValue('a', 'x');
    c.setValue('a', 'xy');
    c.setValue('a', 'xyz'); // 100 frappes simulées : 3 écarts, 1 seul flip
    expect(toggles, 1);
    expect(c.isDirty.value, isTrue);
  });

  test('AC8 — la mise à jour de dirty ne notifie JAMAIS le canal global', () {
    final c = ZFormController(initialValues: <String, Object?>{'a': ''});
    addTearDown(c.dispose);

    var global = 0;
    c.addListener(() => global++); // ChangeNotifier global (structurel only)

    c.setValue('a', 'x');
    c.setValue('a', 'y');
    expect(global, 0, reason: 'aucun notifyListeners() global sur setValue/dirty');
  });

  test('reseed re-baseline ⇒ non-dirty (donnée autoritaire externe)', () {
    final c = ZFormController(initialValues: <String, Object?>{'a': 1});
    addTearDown(c.dispose);

    c.setValue('a', 2);
    expect(c.isDirty.value, isTrue);
    c.reseed(<String, Object?>{'a': 7});
    expect(c.isDirty.value, isFalse);
    expect(c.valueOf('a'), 7);
    // La baseline est 7 : y revenir n'est pas dirty ; s'en écarter l'est.
    c.setValue('a', 8);
    expect(c.isDirty.value, isTrue);
  });
}
