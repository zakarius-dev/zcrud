// CR-IFFD-8 — capitalisation déclarative du champ `text`.
//
// IFFD applique un `ucFirstFormatter` d'office à tout champ texte : `"biologie"`
// est persisté `"Biologie"`. `ZTextFieldWidget` n'appliquait AUCUNE capitalisation.
// Reproduire ce comportement via une option DÉCLARATIVE (pas des inputFormatters
// bruts qui feraient fuiter Flutter dans le domaine), et — point clé — de façon
// DÉTERMINISTE : `TextCapitalization` de Flutter n'est qu'un indice clavier
// logiciel, il ne couvre ni le collage ni la saisie programmatique.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

Widget _app(ZFormController controller, List<ZFieldSpec> fields) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          body: DynamicEdition(controller: controller, fields: fields),
        ),
      ),
    );

ZFieldSpec _text(ZTextCapitalization cap) => ZFieldSpec(
      name: 't',
      type: EditionFieldType.text,
      label: 'T',
      config: ZTextConfig(capitalization: cap),
    );

void main() {
  group('CR-IFFD-8 — capitalisation appliquée à la valeur du formulaire', () {
    testWidgets('sentences : "biologie" ⇒ "Biologie" (ucFirst d\'IFFD)',
        (tester) async {
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        _text(ZTextCapitalization.sentences),
      ]));

      await tester.enterText(find.byType(TextField), 'biologie');
      await tester.pump();
      // Discriminant : sans le formateur, la valeur resterait "biologie".
      expect(c.valueOf('t'), 'Biologie');
    });

    testWidgets('characters : tout en majuscules', (tester) async {
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        _text(ZTextCapitalization.characters),
      ]));
      await tester.enterText(find.byType(TextField), 'iso 9001');
      await tester.pump();
      expect(c.valueOf('t'), 'ISO 9001');
    });

    testWidgets('words : première lettre de chaque mot', (tester) async {
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        _text(ZTextCapitalization.words),
      ]));
      await tester.enterText(find.byType(TextField), 'chimie organique');
      await tester.pump();
      expect(c.valueOf('t'), 'Chimie Organique');
    });

    testWidgets('none (défaut) : aucune transformation — rétro-compatible',
        (tester) async {
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      // Champ SANS config : conserve exactement le rendu antérieur.
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        const ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'T'),
      ]));
      await tester.enterText(find.byType(TextField), 'biologie');
      await tester.pump();
      expect(c.valueOf('t'), 'biologie');
    });

    testWidgets('le COLLAGE est couvert (déterminisme, pas juste indice clavier)',
        (tester) async {
      // `enterText` simule une insertion programmatique, exactement le cas que
      // `textCapitalization` seul NE couvre PAS. C'est le cœur de la CR.
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        _text(ZTextCapitalization.sentences),
      ]));
      await tester.enterText(find.byType(TextField), 'texte collé en minuscule.');
      await tester.pump();
      expect(c.valueOf('t'), 'Texte collé en minuscule.');
    });
  });

  group('CR-IFFD-8 — invariants', () {
    testWidgets('un mot de passe n\'est JAMAIS capitalisé', (tester) async {
      final c = _controller(<String, Object?>{'p': ''});
      addTearDown(c.dispose);
      // Même si une config le demandait, le secret ne doit pas être altéré.
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        const ZFieldSpec(
          name: 'p',
          type: EditionFieldType.password,
          label: 'P',
          config: ZTextConfig(capitalization: ZTextCapitalization.characters),
        ),
      ]));
      await tester.enterText(find.byType(TextField), 'mDp secret');
      await tester.pump();
      expect(c.valueOf('p'), 'mDp secret');
    });

    testWidgets('SM-1 : le curseur reste en place au milieu du texte',
        (tester) async {
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        _text(ZTextCapitalization.characters),
      ]));

      final field = find.byType(TextField);
      await tester.enterText(field, 'abcdef');
      await tester.pump();
      // Positionne le curseur au milieu, puis insère.
      final state = tester.widget<TextField>(field);
      state.controller!.selection =
          const TextSelection.collapsed(offset: 3);
      await tester.pump();
      // La casse ne change PAS la longueur : l'offset reste valide.
      expect(state.controller!.text, 'ABCDEF');
      expect(state.controller!.selection.baseOffset, 3);
    });
  });
}
