// AC4/AC5 (E4-2, AD-8/SM-5) : sur le chemin `dataGrid` (défaut) en état `ready`,
// `DynamicList` DÉLÈGUE au `ZListRenderer` injecté (paramètre explicite ou seam
// `ZcrudScope.listRenderer`) en lui passant un `ZListRenderRequest` à colonnes
// **DÉRIVÉES** (`ZListColumn`), et lève une `ZScopeError` actionnable si AUCUN
// renderer n'est disponible.
//
// CRUCIAL (SM-5) : ce test définit un FAUX `ZListRenderer` inline et n'importe
// JAMAIS `zcrud_list` ni Syncfusion — démonstration exécutable que le cœur se
// rend derrière l'abstraction seule.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Faux renderer capturant la dernière `ZListRenderRequest` reçue (zéro
/// Syncfusion, défini dans le test — pilier SM-5).
class _CapturingRenderer extends ZListRenderer {
  _CapturingRenderer();

  ZListRenderRequest? captured;

  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) {
    captured = request;
    return const SizedBox(key: ValueKey('rendered'));
  }
}

void main() {
  const fields = [
    ZFieldSpec(name: 'name', type: EditionFieldType.text),
    ZFieldSpec(name: 'age', type: EditionFieldType.number),
  ];
  const rows = [
    ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30}),
    ZListRow(id: '2', cells: {'name': 'Bob', 'age': 25}),
  ];

  testWidgets('délègue au renderer PASSÉ en paramètre avec colonnes dérivées '
      '(AC4)', (tester) async {
    final fake = _CapturingRenderer();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DynamicList.rows(fields, rows, renderer: fake),
      ),
    );

    expect(find.byKey(const ValueKey('rendered')), findsOneWidget);
    expect(fake.captured, isNotNull);
    // columns == colonnes DÉRIVÉES (plus des ZFieldSpec bruts) ; rows transmis.
    expect(fake.captured!.columns, equals(deriveColumns(fields)));
    expect(fake.captured!.columns.map((c) => c.name), equals(['name', 'age']));
    expect(fake.captured!.rows, equals(rows));
  });

  testWidgets('délègue au renderer injecté via ZcrudScope.listRenderer (AC4)',
      (tester) async {
    final fake = _CapturingRenderer();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudScope(
          listRenderer: fake,
          child: DynamicList.rows(fields, rows),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('rendered')), findsOneWidget);
    expect(fake.captured!.columns, equals(deriveColumns(fields)));
    expect(fake.captured!.rows, equals(rows));
  });

  testWidgets('paramètre renderer prioritaire sur le seam de scope (AC4)',
      (tester) async {
    final scopeRenderer = _CapturingRenderer();
    final paramRenderer = _CapturingRenderer();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudScope(
          listRenderer: scopeRenderer,
          child: DynamicList.rows(fields, rows, renderer: paramRenderer),
        ),
      ),
    );

    expect(paramRenderer.captured, isNotNull);
    expect(scopeRenderer.captured, isNull);
  });

  testWidgets('aucun renderer (ni param ni seam) sur dataGrid ⇒ ZScopeError '
      'actionnable (AC4)', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudScope(
          child: DynamicList.rows(fields, rows),
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isA<ZScopeError>());
    expect((error as ZScopeError).message, contains('zcrud_list'));
    expect(error.message, contains('ZSfDataGridRenderer'));
  });

  test('const : DynamicList (constructeur primaire + état) est '
      'const-constructible (AC4)', () {
    const widget = DynamicList(fields: fields, state: ZListReady(rows));
    expect(widget.fields, equals(fields));
    expect(widget.state, isA<ZListReady>());
    expect(widget.renderer, isNull);
    expect(widget.layout, isA<ZListDataGridLayout>());
  });

  // ─────────────────── L3 (code-review E4-1) : bords ────────────────────────

  testWidgets('L1 : sans ancêtre ZcrudScope NI renderer ⇒ ZScopeError '
      'LIST-SPÉCIFIQUE (pas générique)', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DynamicList.rows(fields, rows),
      ),
    );
    final error = tester.takeException();
    expect(error, isA<ZScopeError>());
    expect((error as ZScopeError).message, contains('zcrud_list'));
    expect(error.message, contains('ZSfDataGridRenderer'));
  });

  testWidgets('L3 : schéma vide (fields == []) délègue sans crash (0 colonne)',
      (tester) async {
    final fake = _CapturingRenderer();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DynamicList.rows(
          const <ZFieldSpec>[],
          rows,
          renderer: fake,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('rendered')), findsOneWidget);
    expect(fake.captured!.columns, isEmpty);
    expect(fake.captured!.rows, equals(rows));
  });

  testWidgets('L3 : lignes vides (rows == []) délègue sans crash',
      (tester) async {
    final fake = _CapturingRenderer();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DynamicList.rows(
          fields,
          const <ZListRow>[],
          renderer: fake,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('rendered')), findsOneWidget);
    expect(fake.captured!.columns, equals(deriveColumns(fields)));
    expect(fake.captured!.rows, isEmpty);
  });

  testWidgets('L3 : noms de colonnes DUPLIQUÉS ⇒ 2 colonnes dérivées '
      '(délégation sans crash)', (tester) async {
    // Deux ZFieldSpec de même `name`, tous deux tabulaires : la dérivation
    // conserve les 2 (pas de dédoublonnage) — comportement défini.
    const dupFields = [
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'A'),
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'B'),
    ];
    final fake = _CapturingRenderer();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DynamicList.rows(dupFields, rows, renderer: fake),
      ),
    );
    expect(find.byKey(const ValueKey('rendered')), findsOneWidget);
    expect(fake.captured!.columns.length, equals(2));
    expect(fake.captured!.columns.every((c) => c.name == 'name'), isTrue);
  });
}
