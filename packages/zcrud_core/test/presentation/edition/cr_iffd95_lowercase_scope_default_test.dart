// CR-IFFD-95 — `ZTextCapitalization.lowercase` (formateur DÉTERMINISTE) et
// défauts de configuration à l'échelle du scope
// (`ZcrudScope.defaultTextConfig`), la déclaration du champ gagnant toujours.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _host(Widget child, {ZTextConfig? defaultTextConfig}) => MaterialApp(
      home: Scaffold(
        body: ZcrudScope(defaultTextConfig: defaultTextConfig, child: child),
      ),
    );

void main() {
  testWidgets('🔴 lowercase est DÉTERMINISTE : la saisie programmatique '
      '(même canal que le collage) ressort en minuscules', (tester) async {
    const field = ZFieldSpec(
      name: 'code',
      type: EditionFieldType.text,
      config: ZTextConfig(capitalization: ZTextCapitalization.lowercase),
    );
    final c = ZFormController();
    await tester.pumpWidget(_host(ZFieldWidget(controller: c, field: field)));
    // `enterText` passe par `updateEditingValue` — la voie du collage et de la
    // saisie programmatique, PAS un indice de clavier.
    await tester.enterText(find.byType(TextField), 'ABC Déf-42');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'abc déf-42');
    expect(c.valueOf('code'), 'abc déf-42');
    c.dispose();
  });

  testWidgets('🔴 le défaut du scope s\'applique à un champ SANS config', (
    tester,
  ) async {
    const field = ZFieldSpec(name: 'nom', type: EditionFieldType.text);
    final c = ZFormController();
    await tester.pumpWidget(_host(
      ZFieldWidget(controller: c, field: field),
      defaultTextConfig:
          const ZTextConfig(capitalization: ZTextCapitalization.lowercase),
    ));
    await tester.enterText(find.byType(TextField), 'GRAND');
    await tester.pump();
    expect(c.valueOf('nom'), 'grand');
    c.dispose();
  });

  testWidgets('🔴 la déclaration du CHAMP gagne toujours sur le défaut du '
      'scope', (tester) async {
    const field = ZFieldSpec(
      name: 'sigle',
      type: EditionFieldType.text,
      config: ZTextConfig(capitalization: ZTextCapitalization.characters),
    );
    final c = ZFormController();
    await tester.pumpWidget(_host(
      ZFieldWidget(controller: c, field: field),
      defaultTextConfig:
          const ZTextConfig(capitalization: ZTextCapitalization.lowercase),
    ));
    await tester.enterText(find.byType(TextField), 'omd');
    await tester.pump();
    expect(c.valueOf('sigle'), 'OMD');
    c.dispose();
  });

  testWidgets('sans défaut de scope ni config, rien ne change (aucun '
      'formateur)', (tester) async {
    const field = ZFieldSpec(name: 'libre', type: EditionFieldType.text);
    final c = ZFormController();
    await tester.pumpWidget(_host(ZFieldWidget(controller: c, field: field)));
    await tester.enterText(find.byType(TextField), 'Tel Quel');
    await tester.pump();
    expect(c.valueOf('libre'), 'Tel Quel');
    c.dispose();
  });

  testWidgets('le défaut du scope pilote aussi le CLAVIER d\'un champ sans '
      'config (CR-93 × CR-95)', (tester) async {
    const field = ZFieldSpec(name: 'mail', type: EditionFieldType.text);
    final c = ZFormController();
    await tester.pumpWidget(_host(
      ZFieldWidget(controller: c, field: field),
      defaultTextConfig: const ZTextConfig(keyboardType: 'email'),
    ));
    expect(tester.widget<TextField>(find.byType(TextField)).keyboardType,
        TextInputType.emailAddress);
    c.dispose();
  });
}
