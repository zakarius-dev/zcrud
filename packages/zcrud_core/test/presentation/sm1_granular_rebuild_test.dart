// AC8 — TEST SM-1 (proto au niveau controller) : OBJECTIF PRODUIT N°1.
//
// Prouve la garantie sous-jacente à SM-1 : mettre à jour un champ N fois ne
// reconstruit QUE ce champ (rebuild ciblé via `ValueListenableBuilder` sur la
// tranche), zéro rebuild du champ voisin, zéro rebuild global, focus/curseur
// préservés (pas de ré-injection). La version PLEIN FORMULAIRE (100 caractères
// sur `DynamicEdition`) est portée en E3-1.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  testWidgets('setValue(a) ×N : seul a reconstruit, b et global inchangés (AC8)',
      (tester) async {
    final c = ZFormController(initialValues: {'a': '', 'b': ''});
    var buildsA = 0;
    var buildsB = 0;
    var buildsGlobal = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudScope(
          child: Column(
            children: [
              ZFieldListenableBuilder(
                controller: c,
                name: 'a',
                builder: (context, value, child) {
                  buildsA++;
                  return Text('a=$value');
                },
              ),
              ZFieldListenableBuilder(
                controller: c,
                name: 'b',
                builder: (context, value, child) {
                  buildsB++;
                  return Text('b=$value');
                },
              ),
              ListenableBuilder(
                listenable: c,
                builder: (context, child) {
                  buildsGlobal++;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );

    // Montage initial : chaque builder a construit exactement une fois.
    expect(buildsA, 1);
    expect(buildsB, 1);
    expect(buildsGlobal, 1);

    const n = 25;
    for (var i = 0; i < n; i++) {
      c.setValue('a', 'v$i');
      await tester.pump();
    }

    expect(buildsA, 1 + n, reason: 'a reconstruit à chaque frappe');
    expect(buildsB, 1, reason: 'le champ voisin ne reconstruit JAMAIS');
    expect(buildsGlobal, 1, reason: 'aucun rebuild global (notifyListeners)');
    c.dispose();
  });

  testWidgets('TextField réel : focus conservé, curseur non réinitialisé (AC8)',
      (tester) async {
    final c = ZFormController(initialValues: {'a': '', 'b': ''});
    final focusA = FocusNode();
    final controllerA = TextEditingController();
    var buildsB = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudScope(
          child: Column(
            children: [
              // À sens unique : onChanged → setValue (PAS de ré-injection .text=).
              ZFieldListenableBuilder(
                controller: c,
                name: 'a',
                builder: (context, value, child) => EditableText(
                  controller: controllerA,
                  focusNode: focusA,
                  style: const TextStyle(),
                  cursorColor: const Color(0xFF000000),
                  backgroundCursorColor: const Color(0xFF000000),
                  onChanged: (v) => c.setValue('a', v),
                ),
              ),
              ZFieldListenableBuilder(
                controller: c,
                name: 'b',
                builder: (context, value, child) {
                  buildsB++;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );

    focusA.requestFocus();
    await tester.pump();
    expect(focusA.hasFocus, isTrue);

    // Saisie caractère par caractère.
    const text = 'bonjour';
    for (var i = 1; i <= text.length; i++) {
      await tester.enterText(find.byType(EditableText), text.substring(0, i));
      await tester.pump();
      // Focus jamais perdu pendant la saisie.
      expect(focusA.hasFocus, isTrue);
    }

    // Valeur propagée au controller ; le champ voisin n'a jamais reconstruit.
    expect(c.valueOf('a'), text);
    expect(buildsB, 1, reason: 'le voisin ne reconstruit jamais pendant la saisie');
    // Curseur en fin de texte (non réinitialisé à 0), sélection cohérente.
    expect(controllerA.selection.baseOffset, text.length);
    expect(focusA.hasFocus, isTrue);

    c.dispose();
    focusA.dispose();
    controllerA.dispose();
  });
}
