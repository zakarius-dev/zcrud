// Garde-fou PUR-DART : fige la forme des enums de présentation (AC2/AC3) —
// tout ajout/retrait non intentionnel d'une valeur casse ce test.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

void main() {
  test('ZEditionPresentation.values == {page, sheet, dialog}', () {
    expect(ZEditionPresentation.values, <ZEditionPresentation>[
      ZEditionPresentation.page,
      ZEditionPresentation.sheet,
      ZEditionPresentation.dialog,
    ]);
  });

  test('ZFormWeight.values == {light, heavy}', () {
    expect(ZFormWeight.values, <ZFormWeight>[
      ZFormWeight.light,
      ZFormWeight.heavy,
    ]);
  });
}
