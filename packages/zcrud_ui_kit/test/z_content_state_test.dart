import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

void main() {
  group('ZContentState (enum > booléens)', () {
    test('expose exactement 5 paliers', () {
      expect(ZContentState.values.length, 5);
    });

    test('les 5 valeurs sont en camelCase attendu', () {
      expect(ZContentState.idle.name, 'idle');
      expect(ZContentState.loading.name, 'loading');
      expect(ZContentState.empty.name, 'empty');
      expect(ZContentState.error.name, 'error');
      expect(ZContentState.success.name, 'success');
    });
  });

  group('ZConfirmTone (enum > bool isDestructive)', () {
    test('expose exactement 2 tonalités', () {
      expect(ZConfirmTone.values.length, 2);
    });

    test('les 2 valeurs sont en camelCase attendu', () {
      expect(ZConfirmTone.neutral.name, 'neutral');
      expect(ZConfirmTone.destructive.name, 'destructive');
    });
  });
}
