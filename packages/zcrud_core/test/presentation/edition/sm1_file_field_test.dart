// AC14 (E3-3c) — SM-1 préservé avec un champ FICHIER présent : taper 100
// caractères dans un champ TEXTE ne reconstruit QUE ce champ ; le compteur de
// build du champ fichier (et des voisins) reste inchangé ; 0 rebuild global
// (structurel == 1) ; aucun `Form` global monté (AD-2, objectif produit n°1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  testWidgets('SM-1 : 100 frappes texte ne reconstruisent pas le champ fichier '
      '(structurel == 1, aucun Form global)', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fields = <ZFieldSpec>[
      const ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Nom'),
      const ZFieldSpec(name: 'note', type: EditionFieldType.text, label: 'Note'),
      const ZFieldSpec(
          name: 'piece', type: EditionFieldType.file, label: 'Pièce'),
    ];
    final controller = ZFormController(
      initialValues: <String, Object?>{for (final f in fields) f.name: ''},
      visibleFields: <String>[for (final f in fields) f.name],
    );
    addTearDown(controller.dispose);

    final builds = <String, int>{};
    var structural = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZcrudScope(
            child: DynamicEdition(
              controller: controller,
              fields: fields,
              onStructuralBuild: () => structural++,
              fieldBuilder: (context, ctrl, field) => ZFieldWidget(
                controller: ctrl,
                field: field,
                onBuild: () =>
                    builds[field.name] = (builds[field.name] ?? 0) + 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ZAppFileField), findsOneWidget);
    // Aucun `Form`/`FormBuilder` global (AD-2) : chaque champ porte sa propre
    // frontière de rebuild.
    expect(find.byType(Form), findsNothing);

    final base = Map<String, int>.from(builds);
    expect(structural, 1, reason: 'builder structurel monté une seule fois');
    final pieceBase = base['piece'];
    expect(pieceBase, isNotNull);

    final target = editableOf('nom');
    await tester.tap(target);
    await tester.pump();

    const total = 100;
    final buffer = StringBuffer();
    for (var i = 1; i <= total; i++) {
      buffer.write(String.fromCharCode(97 + (i % 26)));
      await tester.enterText(target, buffer.toString());
      await tester.pump();
    }

    // Le champ fichier + le voisin texte : compteur STRICTEMENT inchangé.
    expect(builds['piece'], pieceBase,
        reason: 'le champ fichier ne reconstruit JAMAIS sur une frappe texte');
    expect(builds['note'], base['note'],
        reason: 'le voisin texte ne reconstruit jamais');
    // Aucun rebuild global.
    expect(structural, 1, reason: '0 rebuild global (notifyListeners) sur frappe');
    expect(controller.valueOf('nom'), buffer.toString());
  });
}

Finder editableOf(String name) => find.descendant(
      of: find.byKey(ValueKey<String>(name)),
      matching: find.byType(EditableText),
    );
