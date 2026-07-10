// AC4 — sélection/injection du `ZCodec` par l'app : précédence
// `paramètre du champ > ZMarkdownCodecScope > ZDeltaCodec()`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

List<Map<String, dynamic>> _boldDelta() => <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': 'gras',
        'attributes': <String, dynamic>{'bold': true},
      },
      <String, dynamic>{'insert': '\n'},
    ];

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

ZMarkdownFieldDebug _debugOf(WidgetTester tester) =>
    tester.state<State<ZMarkdownField>>(find.byType(ZMarkdownField))
        as ZMarkdownFieldDebug;

void main() {
  const field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

  /// Monte un champ avec [codec]/[scopeCodec] optionnels, seedé d'un Delta gras,
  /// et retourne la valeur PERSISTÉE résolue (`codec.encode`) pour discriminer
  /// le codec effectivement utilisé (Markdown vs Delta JSON).
  Future<Object?> persistedWith(
    WidgetTester tester, {
    ZCodec? codec,
    ZCodec? scopeCodec,
  }) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'notes': _boldDelta()},
    );
    addTearDown(controller.dispose);

    Widget field0 = ZMarkdownField(
      key: ValueKey(field.name),
      controller: controller,
      field: field,
      codec: codec,
    );
    if (scopeCodec != null) {
      field0 = ZMarkdownCodecScope(codec: scopeCodec, child: field0);
    }
    await tester.pumpWidget(_host(field0));
    final persisted = _debugOf(tester).debugPersistedValue;
    await _settle(tester);
    return persisted;
  }

  test('précédence documentée', () {
    // Sanity : les deux codecs produisent des formats distincts et
    // discriminables sur le même contenu.
    expect(const ZDeltaCodec().encode(_boldDelta()), isA<String>());
    expect(const ZMarkdownCodec().encode(_boldDelta()), contains('**gras**'));
  });

  testWidgets('défaut (ni param ni scope) → ZDeltaCodec (JSON)', (tester) async {
    final persisted = await persistedWith(tester);
    expect(persisted, isA<String>());
    expect(persisted! as String, contains('"bold":true'));
  });

  testWidgets('paramètre du champ seul → ZMarkdownCodec (Markdown)',
      (tester) async {
    final persisted =
        await persistedWith(tester, codec: const ZMarkdownCodec());
    expect(persisted! as String, contains('**gras**'));
  });

  testWidgets('scope seul → ZMarkdownCodec hérité (Markdown)', (tester) async {
    final persisted =
        await persistedWith(tester, scopeCodec: const ZMarkdownCodec());
    expect(persisted! as String, contains('**gras**'));
  });

  testWidgets('paramètre GAGNE sur scope (param=Markdown, scope=Delta)',
      (tester) async {
    final persisted = await persistedWith(
      tester,
      codec: const ZMarkdownCodec(),
      scopeCodec: const ZDeltaCodec(),
    );
    // Le paramètre (Markdown) prime : format Markdown, pas JSON.
    expect(persisted! as String, contains('**gras**'));
    expect(persisted, isNot(contains('"bold"')));
  });

  testWidgets('ZMarkdownCodecScope.maybeOf : null hors scope, codec sous scope',
      (tester) async {
    ZCodec? captured;
    var sawNull = false;
    await tester.pumpWidget(_host(
      Builder(
        builder: (outer) {
          sawNull = ZMarkdownCodecScope.maybeOf(outer) == null;
          return ZMarkdownCodecScope(
            codec: const ZMarkdownCodec(),
            child: Builder(
              builder: (inner) {
                captured = ZMarkdownCodecScope.maybeOf(inner);
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    ));
    expect(sawNull, isTrue);
    expect(captured, isA<ZMarkdownCodec>());
  });
}
