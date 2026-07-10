import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/demos/export_demo_screen.dart';

import 'support/pump_helpers.dart';

void main() {
  // AC6 — l'écran Export produit des bytes NON vides pour Excel et un PDF valide
  // (préfixe %PDF-), confirmés à l'utilisateur.
  testWidgets('AC6 — Export : Excel bytes non vides + PDF %PDF-', (tester) async {
    await tester.pumpWidget(wrapForTest(const ExportDemoScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(ExportDemoScreen), findsOneWidget);

    // Export Excel → résultat annonçant des octets (> 0).
    await tester.tap(find.byKey(const ValueKey<String>('exportExcelButton')));
    await tester.pumpAndSettle();
    final excelResult = tester.widget<Text>(
      find.byKey(const ValueKey<String>('exportResult')),
    );
    expect(excelResult.data, contains('Excel'));
    expect(excelResult.data, contains('octets'));
    expect(excelResult.data, isNot(contains('invalide')));

    // Export PDF → résultat valide (le préfixe %PDF- est vérifié dans l'écran ;
    // un PDF invalide afficherait « invalide »).
    await tester.tap(find.byKey(const ValueKey<String>('exportPdfButton')));
    await tester.pumpAndSettle();
    final pdfResult = tester.widget<Text>(
      find.byKey(const ValueKey<String>('exportResult')),
    );
    expect(pdfResult.data, contains('PDF'));
    expect(pdfResult.data, contains('octets'));
    expect(pdfResult.data, isNot(contains('invalide')));
  });
}
