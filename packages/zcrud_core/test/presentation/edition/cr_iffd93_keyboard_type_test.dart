// CR-IFFD-93 — `ZTextConfig.keyboardType` est HONORÉ par la famille texte.
//
// Constat d'origine (vérifié sur disque) : le clavier était dérivé du SEUL
// `maxLines` (`z_text_field_widget.dart`), la déclaration `keyboardType`
// n'était jamais lue — un champ `email` recevait le clavier alphabétique.
//
// Contrat gardé ici :
// - chaque chaîne de la table FERMÉE produit le `TextInputType` documenté ;
// - une chaîne INCONNUE retombe sur le repli antérieur (dérivé du rendu),
//   jamais une exception (AD-10) ;
// - un rendu MULTI-LIGNE garde le clavier multi-ligne, même face à une
//   déclaration contraire (la touche retour est nécessaire à la saisie).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _host(ZFormController c, ZFieldSpec field) => MaterialApp(
      home: Scaffold(body: ZFieldWidget(controller: c, field: field)),
    );

Future<TextField> _pumpField(
  WidgetTester tester,
  ZFormController c,
  ZFieldSpec field,
) async {
  await tester.pumpWidget(_host(c, field));
  return tester.widget<TextField>(find.byType(TextField));
}

void main() {
  testWidgets('🔴 keyboardType: la table fermée est honorée sur un champ '
      'mono-ligne', (tester) async {
    const cases = <String, TextInputType>{
      'email': TextInputType.emailAddress,
      'url': TextInputType.url,
      'phone': TextInputType.phone,
      'name': TextInputType.name,
      'address': TextInputType.streetAddress,
      'datetime': TextInputType.datetime,
      'none': TextInputType.none,
      'text': TextInputType.text,
    };
    for (final entry in cases.entries) {
      final c = ZFormController();
      final tf = await _pumpField(
        tester,
        c,
        ZFieldSpec(
          name: 'f',
          type: EditionFieldType.text,
          config: ZTextConfig(keyboardType: entry.key),
        ),
      );
      expect(tf.keyboardType, entry.value,
          reason: 'keyboardType «${entry.key}» doit produire ${entry.value}');
      c.dispose();
    }
    // Variantes numériques (options, pas d'égalité d'instance triviale).
    final c = ZFormController();
    final tf = await _pumpField(
      tester,
      c,
      const ZFieldSpec(
        name: 'n',
        type: EditionFieldType.text,
        config: ZTextConfig(keyboardType: 'number'),
      ),
    );
    expect(tf.keyboardType, const TextInputType.numberWithOptions(signed: true));
    c.dispose();
  });

  testWidgets('🔴 chaîne INCONNUE ⇒ repli antérieur (clavier texte), aucune '
      'exception', (tester) async {
    final c = ZFormController();
    final tf = await _pumpField(
      tester,
      c,
      const ZFieldSpec(
        name: 'f',
        type: EditionFieldType.text,
        config: ZTextConfig(keyboardType: 'sonar-42'),
      ),
    );
    expect(tf.keyboardType, TextInputType.text);
    expect(tester.takeException(), isNull);
    c.dispose();
  });

  testWidgets('🔴 un rendu multi-ligne GARDE le clavier multi-ligne, '
      'déclaration contraire comprise', (tester) async {
    final c = ZFormController();
    // Champ multiline : la déclaration `email` ne doit pas retirer la touche
    // retour.
    final tf = await _pumpField(
      tester,
      c,
      const ZFieldSpec(
        name: 'f',
        type: EditionFieldType.multiline,
        config: ZTextConfig(keyboardType: 'email'),
      ),
    );
    expect(tf.keyboardType, TextInputType.multiline);
    c.dispose();

    // Et `multiline` DÉCLARÉ sur un champ mono-ligne bascule le clavier.
    final c2 = ZFormController();
    final tf2 = await _pumpField(
      tester,
      c2,
      const ZFieldSpec(
        name: 'g',
        type: EditionFieldType.text,
        config: ZTextConfig(keyboardType: 'multiline'),
      ),
    );
    expect(tf2.keyboardType, TextInputType.multiline);
    c2.dispose();
  });

  testWidgets('sans config, le repli historique est intact (text ⇒ texte, '
      'multiline ⇒ multi-ligne)', (tester) async {
    final c = ZFormController();
    final tf = await _pumpField(
      tester,
      c,
      const ZFieldSpec(name: 'f', type: EditionFieldType.text),
    );
    expect(tf.keyboardType, TextInputType.text);
    c.dispose();

    final c2 = ZFormController();
    final tf2 = await _pumpField(
      tester,
      c2,
      const ZFieldSpec(name: 'g', type: EditionFieldType.multiline),
    );
    expect(tf2.keyboardType, TextInputType.multiline);
    c2.dispose();
  });
}
