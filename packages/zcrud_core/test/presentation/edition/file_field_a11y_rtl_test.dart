// AC11/AC12 (E3-3c) — a11y (Semantics + cibles ≥ 48 dp) et RTL du champ fichier.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/fake_file_picker.dart';

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  ZFilePicker? picker,
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: ZcrudScope(
          filePicker: picker,
          child: Scaffold(
            body: DynamicEdition(
                controller: controller, fields: <ZFieldSpec>[field]),
          ),
        ),
      ),
    );

const _field = ZFieldSpec(
  name: 'img',
  type: EditionFieldType.image,
  label: 'Photo',
);

void main() {
  testWidgets('AC11 : cibles tactiles ≥ 48 dp + labels sémantiques des actions',
      (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller('img',
        value: const AppFile(name: 'p.png', mimeType: 'image/png', localPath: '/p.png'));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
        _app(controller, _field, picker: FakeFilePicker(const <AppFile>[])));
    await tester.pumpAndSettle();

    // (a) Guideline de taille de cible tactile Android (≥ 48 dp).
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

    // (b) Labels sémantiques présents (actions via tooltip + suppression).
    expect(find.byTooltip('Pick from gallery'), findsOneWidget);
    expect(find.byTooltip('Remove file'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('AC11 : état d\'upload (failed) annoncé sémantiquement',
      (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller('img',
        value: const AppFile(
          name: 'p.png',
          mimeType: 'image/png',
          localPath: '/p.png',
          uploadState: ZAppFileUploadState.failed,
        ));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _field));
    await tester.pumpAndSettle();

    // Le message d'échec accessible est rendu + le retry est présent.
    expect(find.text('Upload failed'), findsWidgets);
    expect(find.byTooltip('Retry upload'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('AC12a : rendu RTL sans overflow ni exception', (tester) async {
    final controller = _controller('img',
        value: const AppFile(name: 'p.png', mimeType: 'image/png', localPath: '/p.png'));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _field,
        picker: FakeFilePicker(const <AppFile>[]), dir: TextDirection.rtl));
    await tester.pumpAndSettle();

    expect(find.byType(ZAppFileField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
