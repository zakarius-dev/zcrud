import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/demos/showcase/axis_harness.dart';
import 'package:zcrud_example/demos/showcase/dodlp_forms.dart';
import 'package:zcrud_example/demos/showcase/showcase_data.dart';
import 'package:zcrud_example/demos/showcase/showcase_registry.dart';
import 'package:zcrud_geo/zcrud_geo.dart';
import 'package:zcrud_html/zcrud_html.dart';
import 'package:zcrud_intl/zcrud_intl.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';
import 'package:zcrud_media/zcrud_media.dart';

import 'support/pump_helpers.dart';

Future<void> _pumpForm(WidgetTester tester, AxisForm form) async {
  useTallSurface(tester);
  final registry = buildShowcaseWidgetRegistry(mediaPicker: ZMediaFilePicker());
  await tester.pumpWidget(
    wrapForTestWithRegistry(AxisFormScreen(form: form), registry: registry),
  );
  await tester.pumpAndSettle();
}

void main() {
  // AC5 — l'ossature fp-3-1 a désormais les 6 axes en `mvp` (2/3/4 basculés),
  // chacun peuplé (≥ 6 formulaires au total incl. les 6 DODLP).
  test('AC5 — 6 axes MVP peuplés (2/3/4 basculés upcoming→mvp)', () {
    final mvp = ShowcaseData.axes.where((a) => a.status == AxisStatus.mvp);
    final upcoming =
        ShowcaseData.axes.where((a) => a.status == AxisStatus.upcoming);
    expect(mvp.length, 6);
    expect(upcoming, isEmpty);
    for (final a in ShowcaseData.axes) {
      expect(a.forms, isNotEmpty, reason: '${a.id} doit être peuplé');
    }
    final total = ShowcaseData.axes.fold<int>(0, (n, a) => n + a.forms.length);
    expect(total, greaterThanOrEqualTo(6));
    // Les 6 formulaires DODLP sont branchés dans l'ossature.
    final ids = ShowcaseData.axes
        .expand((a) => a.forms)
        .map((f) => f.id)
        .toSet();
    expect(
      ids,
      containsAll(<String>[
        DodlpForms.cargaison.id,
        DodlpForms.demandeDepotage.id,
        DodlpForms.authProfile.id,
        DodlpForms.articleCotation.id,
        DodlpForms.consignee.id,
        DodlpForms.convocation.id,
      ]),
    );
  });

  // AC5 — chaque formulaire DODLP se rend via le VRAI dispatcher (widgets réels
  // de son axe), données fictives, JAMAIS ZUnsupportedFieldWidget.
  testWidgets('Axe 1 — Cargaison : texte / date / relation / subItems',
      (tester) async {
    await _pumpForm(tester, DodlpForms.cargaison);
    expect(find.byType(ZTextFieldWidget), findsWidgets);
    expect(find.byType(ZRelationFieldWidget), findsOneWidget);
    expect(find.byType(ZSubListFieldWidget), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });

  testWidgets('Axe 2 — Demande de dépotage : select / radio / relation',
      (tester) async {
    await _pumpForm(tester, DodlpForms.demandeDepotage);
    // select + radio → ZSelectFieldWidget ; relation → ZRelationFieldWidget.
    expect(find.byType(ZSelectFieldWidget), findsWidgets);
    expect(find.byType(ZRelationFieldWidget), findsOneWidget);
    expect(find.byType(ZBooleanFieldWidget), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });

  testWidgets('Axe 3 — Profil agent : média image/fichier/vidéo', (tester) async {
    await _pumpForm(tester, DodlpForms.authProfile);
    expect(find.byType(ZMediaFieldWidget), findsNWidgets(3));
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });

  testWidgets('Axe 4 — Article & cotation : markdown + html (lecture)',
      (tester) async {
    await _pumpForm(tester, DodlpForms.articleCotation);
    // markdown (bloc) + inlineMarkdown → 2 ZMarkdownField.
    expect(find.byType(ZMarkdownField), findsNWidgets(2));
    // html + inlineHtml en lecture → 2 ZHtmlView (WYSIWYG runtime — ET-5).
    expect(find.byType(ZHtmlView), findsNWidgets(2));
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });

  testWidgets('Axe 5 — Consignataire : phone / country / address / location',
      (tester) async {
    await _pumpForm(tester, DodlpForms.consignee);
    expect(find.byType(ZPhoneFieldWidget), findsOneWidget);
    expect(find.byType(ZCountryFieldWidget), findsOneWidget);
    expect(find.byType(ZAddressFieldWidget), findsOneWidget);
    expect(find.byType(ZGeoFieldWidget), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });

  testWidgets('Axe 6 — Convocation : dateRange / color multiple / rating / signature',
      (tester) async {
    await _pumpForm(tester, DodlpForms.convocation);
    expect(find.byType(ZDateRangeFieldWidget), findsOneWidget);
    expect(find.byType(ZColorMultiFieldWidget), findsOneWidget);
    expect(find.byType(ZRatingFieldWidget), findsOneWidget);
    expect(find.byType(ZSignatureFieldWidget), findsOneWidget);
    expect(find.byType(ZSubListFieldWidget), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });
}
