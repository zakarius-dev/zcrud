import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

void main() {
  test('ZToastSeverity expose exactement 4 valeurs', () {
    expect(ZToastSeverity.values.length, 4);
  });

  test('les valeurs sont nommées en camelCase (enums > booléens)', () {
    expect(
      ZToastSeverity.values.map((s) => s.name).toList(),
      <String>['info', 'success', 'warning', 'error'],
    );
  });

  test('ordre de sévérité croissante info < success < warning < error', () {
    expect(ZToastSeverity.info.index, lessThan(ZToastSeverity.success.index));
    expect(ZToastSeverity.success.index, lessThan(ZToastSeverity.warning.index));
    expect(ZToastSeverity.warning.index, lessThan(ZToastSeverity.error.index));
  });
}
