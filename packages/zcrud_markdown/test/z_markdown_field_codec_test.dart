// AC6 / AC10 — couture codec du `ZMarkdownField` : seed via `codec.decode`,
// tranche TOUJOURS Delta neutre (chemin chaud intact), persistance via
// `codec.encode` ; SM-1 / AD-2 NON régressés avec un codec non-défaut.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

QuillController _quillOf(WidgetTester tester, {Key? ofKey}) {
  final finder = ofKey == null
      ? find.byType(QuillEditor)
      : find.descendant(
          of: find.byKey(ofKey),
          matching: find.byType(QuillEditor),
        );
  return tester.widget<QuillEditor>(finder).controller;
}

FocusNode _focusOf(WidgetTester tester, {Key? ofKey}) {
  final finder = ofKey == null
      ? find.byType(QuillEditor)
      : find.descendant(
          of: find.byKey(ofKey),
          matching: find.byType(QuillEditor),
        );
  return tester.widget<QuillEditor>(finder).focusNode;
}

ZMarkdownFieldDebug _debugOf(WidgetTester tester, {Key? ofKey}) {
  final finder = ofKey == null
      ? find.byType(ZMarkdownField)
      : find.byKey(ofKey);
  return tester.state<State<ZMarkdownField>>(finder) as ZMarkdownFieldDebug;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  const fieldA = ZFieldSpec(name: 'notes', type: EditionFieldType.text);
  const fieldB = ZFieldSpec(name: 'autre', type: EditionFieldType.text);

  group('AC6 — seed via codec + tranche NEUTRE', () {
    testWidgets(
        'seed depuis String Markdown (ZMarkdownCodec) → éditeur contient le '
        'contenu décodé en Delta', (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': '**salut** monde\n'},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
          codec: const ZMarkdownCodec(),
        ),
      ));

      // Le seed a normalisé la String Markdown en Delta via codec.decode :
      // le document Quill contient bien le texte (gras appliqué).
      final doc = _quillOf(tester).document;
      expect(doc.toPlainText(), contains('salut'));
      expect(doc.toPlainText(), contains('monde'));
      final ops = doc.toDelta().toJson();
      final hasBold = ops.any((op) {
        final o = op as Map;
        final a = o['attributes'];
        return a is Map && a['bold'] == true;
      });
      expect(hasBold, isTrue, reason: 'le gras Markdown doit être décodé');
      await _settle(tester);
    });

    testWidgets('seed depuis Delta JSON (ZDeltaCodec défaut) = rétrocompat E6-1',
        (tester) async {
      final delta = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'brut\n'},
      ];
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': delta},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
        ),
      ));
      expect(_quillOf(tester).document.toPlainText(), contains('brut'));
      await _settle(tester);
    });

    testWidgets(
        'contrat: pendant l\'édition la TRANCHE reste Delta neutre (List<Map>), '
        'pas le format persisté — même avec ZMarkdownCodec', (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
          codec: const ZMarkdownCodec(),
        ),
      ));

      _quillOf(tester).replaceText(
        0,
        0,
        'texte',
        const TextSelection.collapsed(offset: 5),
      );
      await tester.pump();

      final slice = controller.valueOf('notes');
      // La tranche est du Delta NEUTRE (List<Map>), JAMAIS une String Markdown.
      expect(slice, isA<List<Map<String, dynamic>>>());
      expect(slice, isNot(isA<String>()));

      // La voie de persistance (codec.encode) expose bien le format Markdown.
      final persisted = _debugOf(tester).debugPersistedValue;
      expect(persisted, isA<String>());
      expect(persisted! as String, contains('texte'));
      await _settle(tester);
    });

    testWidgets(
        'MEDIUM-1 — SANS frappe : la tranche est NEUTRE (List<Map>) dès le '
        'montage et la voie de persistance PUBLIQUE (non-debug) encode le format '
        'attendu', (tester) async {
      const codec = ZMarkdownCodec();
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': '**salut** monde\n'},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(fieldA.name),
          controller: controller,
          field: fieldA,
          codec: codec,
        ),
      ));

      // La tranche seedée en String Markdown a été NORMALISÉE en Delta neutre
      // (List<Map>) dès le montage — type INVARIANT avant toute frappe.
      final slice = controller.valueOf('notes');
      expect(slice, isA<List<Map<String, dynamic>>>(),
          reason: 'tranche non normalisée (encore String) au montage');
      expect(slice, isNot(isA<String>()));

      // Voie de persistance PUBLIQUE (aucun membre @visibleForTesting) : encode
      // la tranche juste après montage, SANS frappe, sans TypeError.
      final persisted =
          ZMarkdownField.persistedValueOf(controller, 'notes', codec: codec);
      expect(persisted, isA<String>());
      final md = persisted! as String;
      expect(md, contains('salut'));
      expect(md, contains('monde'));
      expect(md, contains('**salut**'),
          reason: 'le gras doit être re-sérialisé en Markdown');

      await _settle(tester);
    });

    testWidgets(
        'MEDIUM-1 — la voie de persistance publique est ROBUSTE à un seed '
        'String non normalisé (aucun TypeError)', (tester) async {
      // Cas défensif : on lit la persistance AVANT que le post-frame de
      // normalisation ne s'exécute — la tranche est encore la String seed brute.
      const codec = ZMarkdownCodec();
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': '# Titre\n'},
      );
      addTearDown(controller.dispose);

      // La tranche vaut la String brute tant qu'aucun frame n'a été pompé.
      expect(controller.valueOf('notes'), isA<String>());
      late Object? persisted;
      expect(
        () => persisted = ZMarkdownField.persistedValueOf(
          controller,
          'notes',
          codec: codec,
        ),
        returnsNormally,
        reason: 'encode naïf d\'une String seed crasherait (MEDIUM-1)',
      );
      expect(persisted, isA<String>());
      expect(persisted! as String, contains('Titre'));
    });
  });

  group('AC10 — SM-1 / AD-2 NON régressés avec ZMarkdownCodec', () {
    testWidgets(
        'taper 100 caractères avec un codec non-défaut : seul le champ courant '
        'rebâtit, controller stable, focus/curseur préservés, codec HORS chemin '
        'chaud (tranche reste Delta)', (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'AC\n'},
        ]},
      );
      addTearDown(controller.dispose);

      var initA = 0;
      var buildB = 0;

      await tester.pumpWidget(_host(
        Column(
          children: <Widget>[
            ZMarkdownField(
              key: ValueKey(fieldA.name),
              controller: controller,
              field: fieldA,
              codec: const ZMarkdownCodec(),
              onInit: () => initA++,
            ),
            ZMarkdownField(
              key: ValueKey(fieldB.name),
              controller: controller,
              field: fieldB,
              codec: const ZMarkdownCodec(),
              onBuild: () => buildB++,
            ),
          ],
        ),
      ));

      final quill = _quillOf(tester, ofKey: const ValueKey('notes'));
      final focus = _focusOf(tester, ofKey: const ValueKey('notes'));
      focus.requestFocus();
      await tester.pump();
      quill.updateSelection(
        const TextSelection.collapsed(offset: 1),
        ChangeSource.local,
      );
      await tester.pump();

      final buildBBefore = buildB;

      for (var i = 0; i < 100; i++) {
        final at = quill.selection.baseOffset;
        quill.replaceText(at, 0, 'x', TextSelection.collapsed(offset: at + 1));
        await tester.pump();
      }

      // Controller JAMAIS recréé.
      expect(initA, 1, reason: 'QuillController/State recréé (AD-2 violé)');
      expect(identical(_quillOf(tester, ofKey: const ValueKey('notes')), quill),
          isTrue);
      // Voisin figé.
      expect(buildB, buildBBefore, reason: 'rebuild du voisin (SM-1 violé)');
      // Focus + curseur préservés.
      expect(focus.hasFocus, isTrue);
      expect(quill.selection.baseOffset, 101);

      // Codec HORS chemin chaud : la tranche pushée par la frappe est du Delta
      // NEUTRE (List<Map>), pas le format persisté du codec (String Markdown).
      final slice = controller.valueOf('notes');
      expect(slice, isA<List<Map<String, dynamic>>>());
      expect(slice, isNot(isA<String>()));

      await _settle(tester);
    });
  });
}
