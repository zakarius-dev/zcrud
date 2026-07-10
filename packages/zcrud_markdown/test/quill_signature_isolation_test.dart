// AC8 (E6-1, AD-1/AD-7) : AUCUN type Quill ne fuit dans la signature publique
// de `ZMarkdownField` ni dans la VALEUR exposée au `ZFormController`.
//
// Deux angles complémentaires :
//   1. RUNTIME : après édition, `valueOf(name)` est une valeur NEUTRE
//      (`List<Map<String, dynamic>>`, JSON-safe) — jamais un type Quill.
//   2. STATIQUE : le barrel n'exporte AUCUN symbole `flutter_quill`, et la
//      surface PUBLIQUE de `z_markdown_field.dart` (avant la classe `State`
//      privée) ne mentionne AUCUN nom de type Quill.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

QuillController _quillOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

File _srcFile(String relative) {
  for (final base in <String>['.', '../zcrud_markdown', 'packages/zcrud_markdown']) {
    final f = File('$base/$relative');
    if (f.existsSync()) return f;
  }
  fail('Introuvable: $relative (cwd ${Directory.current.path})');
}

void main() {
  const field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

  group('AC8 — runtime : valeur du form NEUTRE (aucun type Quill)', () {
    testWidgets('valueOf après édition = List<Map<String,dynamic>> JSON-safe',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: ValueKey(field.name),
          controller: controller,
          field: field,
        ),
      ));

      _quillOf(tester).replaceText(
        0,
        0,
        'Neutre',
        const TextSelection.collapsed(offset: 6),
      );
      await tester.pump();

      final value = controller.valueOf('notes');
      expect(value, isA<List<Map<String, dynamic>>>());
      // Aucun type Quill : ni Document, ni Delta, ni Attribute.
      expect(value, isNot(isA<Document>()));
      // JSON-safe (round-trip sans perte) — preuve de neutralité.
      final roundTrip = jsonDecode(jsonEncode(value));
      expect(roundTrip, equals(value));

      // Draine le Timer.run(0) de la toolbar Quill avant démontage.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('AC8 — statique : surface publique sans type Quill', () {
    test('le barrel n\'exporte / n\'importe aucun symbole flutter_quill', () {
      // Ignore les commentaires (qui peuvent LÉGITIMEMENT nommer flutter_quill
      // pour documenter l'isolation) : seules les DIRECTIVES comptent.
      final directives = _srcFile('lib/zcrud_markdown.dart')
          .readAsLinesSync()
          .map((l) => l.trimLeft())
          .where((l) => l.startsWith('export ') || l.startsWith('import '));
      for (final d in directives) {
        expect(d.contains('flutter_quill'), isFalse,
            reason: 'Le barrel public ne doit ni exporter ni importer '
                'flutter_quill (fuite AD-1). Ligne: $d');
      }
    });

    test('la signature publique de ZMarkdownField ne cite aucun type Quill', () {
      final src =
          _srcFile('lib/src/presentation/z_markdown_field.dart').readAsStringSync();

      // Portion PUBLIQUE = tout ce qui précède la classe State privée.
      final marker = src.indexOf('class _ZMarkdownFieldState');
      expect(marker, greaterThan(0), reason: 'classe State privée introuvable');
      final publicRegion = src
          .substring(0, marker)
          .split('\n')
          // Exclut les lignes d'import et de commentaire (non signature).
          .where((l) {
            final t = l.trimLeft();
            return !t.startsWith('import ') &&
                !t.startsWith('//') &&
                !t.startsWith('/// ') &&
                !t.startsWith('///') &&
                !t.startsWith('*') &&
                !t.startsWith('/*');
          })
          .join('\n');

      const quillTypes = <String>[
        'QuillController',
        'Document',
        'Delta',
        'Attribute',
        'QuillEditor',
        'QuillSimpleToolbar',
        // E6-3 (AC7) : aucun type de rendu math ne fuit non plus.
        'Math',
        'SelectableMath',
        'MathStyle',
        'FlutterMathException',
      ];
      for (final t in quillTypes) {
        expect(publicRegion.contains(t), isFalse,
            reason: 'Type Quill/math "$t" présent dans la signature publique de '
                'ZMarkdownField (fuite AD-1/AD-8).');
      }
    });
  });

  // ─── E6-3 : extension AC7 — isolation de `flutter_math_fork` (rendu LaTeX) ──
  group('AC7 (E6-3) — surface publique sans type flutter_math_fork', () {
    test('le barrel n\'importe/n\'exporte aucun symbole flutter_math_fork', () {
      final directives = _srcFile('lib/zcrud_markdown.dart')
          .readAsLinesSync()
          .map((l) => l.trimLeft())
          .where((l) => l.startsWith('export ') || l.startsWith('import '));
      for (final d in directives) {
        expect(d.contains('flutter_math'), isFalse,
            reason: 'Le barrel ne doit ni exporter ni importer flutter_math_fork '
                '(fuite AD-1). Ligne: $d');
      }
    });

    test('l\'embed LaTeX + son builder ne sont PAS exportés par le barrel', () {
      final barrel = _srcFile('lib/zcrud_markdown.dart').readAsStringSync();
      for (final symbol in const <String>['z_latex_embed', 'ZLatexEmbed']) {
        expect(barrel.contains(symbol), isFalse,
            reason: 'Le barrel ne doit PAS exposer "$symbol" (impl. interne, '
                'consomme flutter_quill/flutter_math_fork — AD-1).');
      }
    });
  });

  // ─── E6-4 : extension AC7 — isolation de l'embed TABLEAU (widget Table natif) ─
  group('AC7 (E6-4) — embed tableau non exporté ; zéro dépendance ajoutée', () {
    test('l\'embed tableau + son builder ne sont PAS exportés par le barrel', () {
      final barrel = _srcFile('lib/zcrud_markdown.dart').readAsStringSync();
      for (final symbol
          in const <String>['z_table_embed', 'ZTableEmbed', 'ZTableEmbedBuilder']) {
        expect(barrel.contains(symbol), isFalse,
            reason: 'Le barrel ne doit PAS exposer "$symbol" (impl. interne, '
                'consomme flutter_quill + widget Table natif — AD-1).');
      }
    });

    test('le pubspec.yaml n\'acquiert AUCUNE dépendance table lourde (AD-1)', () {
      // AC6 : le rendu utilise le widget `Table` du framework Flutter ⇒ ZÉRO
      // dépendance ajoutée. On assère l'ABSENCE de toute lib de tableau/rich
      // lourde (WebView / grille tierce) dans le pubspec du package.
      final pubspec = _srcFile('pubspec.yaml').readAsStringSync();
      for (final banned in const <String>[
        'flutter_tex',
        'html_editor_enhanced',
        'pluto_grid',
        'data_table_2',
        'syncfusion_flutter_datagrid',
        'webview_flutter',
      ]) {
        expect(pubspec.contains(banned), isFalse,
            reason: 'Dépendance lourde "$banned" ajoutée (viole AD-1/AC6 : le '
                'tableau se rend via le widget `Table` natif de Flutter).');
      }
    });
  });

  // ─── E6-2 : extension AC8 aux codecs `ZCodec` (Quill + libs de conversion) ──
  group('AC8 (E6-2) — surface publique ZCodec sans type Quill/conversion', () {
    test('le barrel n\'importe/n\'exporte aucune lib de conversion ni Quill', () {
      final directives = _srcFile('lib/zcrud_markdown.dart')
          .readAsLinesSync()
          .map((l) => l.trimLeft())
          .where((l) => l.startsWith('export ') || l.startsWith('import '));
      for (final d in directives) {
        for (final banned in const <String>[
          'flutter_quill',
          'markdown_quill',
          'package:markdown/',
        ]) {
          expect(d.contains(banned), isFalse,
              reason: 'Le barrel ne doit pas exposer "$banned" (fuite AD-1). '
                  'Ligne: $d');
        }
      }
    });

    test('la définition publique de ZCodec ne cite aucun type Quill/conversion',
        () {
      final src = _srcFile('lib/src/domain/z_codec.dart').readAsStringSync();
      const banned = <String>[
        'QuillController',
        'Document',
        'Delta',
        'Attribute',
        'md.Document',
        'MarkdownToDelta',
        'DeltaToMarkdown',
      ];
      // On ignore les commentaires (peuvent nommer légitimement ces types).
      final codeOnly = src
          .split('\n')
          .where((l) {
            final t = l.trimLeft();
            return !t.startsWith('//') &&
                !t.startsWith('///') &&
                !t.startsWith('*') &&
                !t.startsWith('/*');
          })
          .join('\n');
      for (final t in banned) {
        expect(codeOnly.contains(t), isFalse,
            reason: 'Type "$t" dans la signature publique de ZCodec (fuite).');
      }
    });
  });

  group('AC8 (E6-2) — runtime : valeur PERSISTÉE neutre (jamais un type Quill)',
      () {
    test('ZDeltaCodec : encode → String, decode → List<Map> neutre', () {
      const codec = ZDeltaCodec();
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'x\n'},
      ];
      final persisted = codec.encode(ops);
      expect(persisted, isA<String>());
      expect(persisted, isNot(isA<Document>()));
      final decoded = codec.decode(persisted);
      expect(decoded, isA<List<Map<String, dynamic>>>());
    });

    test('ZMarkdownCodec : encode → String, decode → List<Map> neutre', () {
      const codec = ZMarkdownCodec();
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': 'g',
          'attributes': <String, dynamic>{'bold': true},
        },
        <String, dynamic>{'insert': '\n'},
      ];
      final persisted = codec.encode(ops);
      expect(persisted, isA<String>());
      expect(persisted, isNot(isA<Document>()));
      final decoded = codec.decode(persisted);
      expect(decoded, isA<List<Map<String, dynamic>>>());
      expect(decoded, isNot(isA<Delta>()));
    });
  });
}
