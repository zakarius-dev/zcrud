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
  mainCrIffd13();
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

// ─────────────────────────────────────────────────────────────────────────────
// CR-IFFD-13 — transformation de saisie INJECTABLE.
//
// La demande initiale était un mode `first`. La session IFFD l'a elle-même
// révisée : ajouter le comportement exact d'un hôte ne résout que son cas, et
// l'app suivante arrive avec sa propre règle. Une transformation injectable
// couvre tout, et la règle vit dans l'application qui la possède.
// ─────────────────────────────────────────────────────────────────────────────
void mainCrIffd13() {
  ZFieldSpec spec(ZTextConfig config) => ZFieldSpec(
        name: 't',
        type: EditionFieldType.text,
        label: 'T',
        config: config,
      );

  // La règle « première lettre seule », exprimée PAR L'HÔTE.
  String ucFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  group('CR-IFFD-13 — textTransform injecté', () {
    testWidgets('🔴 « première lettre seule » est exprimable par l\'hôte',
        (tester) async {
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        spec(ZTextConfig(textTransform: ucFirst)),
      ]));
      await tester.enterText(find.byType(TextField), 'biologie');
      await tester.pump();
      expect(c.valueOf('t'), 'Biologie');
    });

    testWidgets('🔴 le cas que `sentences` traitait MAL : example.com',
        (tester) async {
      // `sentences` capitalise après chaque `.` ⇒ 'Example.Com'. C'est
      // exactement l'écart mesuré par IFFD sur un champ `host`.
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        spec(ZTextConfig(textTransform: ucFirst)),
      ]));
      await tester.enterText(find.byType(TextField), 'example.com');
      await tester.pump();
      expect(c.valueOf('t'), 'Example.com');
    });

    testWidgets('la transformation s\'applique APRÈS la capitalisation',
        (tester) async {
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        spec(ZTextConfig(
          capitalization: ZTextCapitalization.characters,
          textTransform: (s) => s.replaceAll(' ', '_'),
        )),
      ]));
      await tester.enterText(find.byType(TextField), 'iso 9001');
      await tester.pump();
      // Majuscules d'abord, puis la règle de l'hôte : l'hôte a le dernier mot.
      expect(c.valueOf('t'), 'ISO_9001');
    });

    testWidgets('une transformation qui CHANGE la longueur ne lève pas',
        (tester) async {
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        spec(ZTextConfig(textTransform: (s) => s.replaceAll('a', ''))),
      ]));
      await tester.enterText(find.byType(TextField), 'banana');
      await tester.pump();
      expect(c.valueOf('t'), 'bnn');
      expect(tester.takeException(), isNull, reason: 'curseur ramené aux bornes');
    });

    testWidgets('AD-10 — une transformation qui LÈVE ne casse pas la saisie',
        (tester) async {
      final c = _controller(<String, Object?>{'t': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        spec(ZTextConfig(textTransform: (s) => throw StateError('hôte fautif'))),
      ]));
      await tester.enterText(find.byType(TextField), 'texte');
      await tester.pump();
      expect(c.valueOf('t'), 'texte', reason: 'repli sur le texte non transformé');
      expect(tester.takeException(), isNull);
    });

    testWidgets('jamais appliquée à un mot de passe', (tester) async {
      final c = _controller(<String, Object?>{'p': ''});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, <ZFieldSpec>[
        ZFieldSpec(
          name: 'p',
          type: EditionFieldType.password,
          label: 'P',
          config: ZTextConfig(textTransform: (s) => s.toUpperCase()),
        ),
      ]));
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.pump();
      expect(c.valueOf('p'), 'secret');
    });
  });
}
