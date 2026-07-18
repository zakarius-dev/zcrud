// FP-4.4 (AD-52) — `ZColorConfig.multiple` : variante native additive.
//
// Tests porteurs (R3) : égalité/hash couvrent le champ `multiple`. Retirer
// `multiple` de `operator ==`/`hashCode` fait ROUGIR le test qui distingue
// simple ↔ multiple.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('défaut : ZColorConfig() est mono (multiple == false)', () {
    const cfg = ZColorConfig();
    expect(cfg.multiple, isFalse);
  });

  test('ZColorConfig.multiple() pose multiple == true', () {
    const cfg = ZColorConfig.multiple();
    expect(cfg.multiple, isTrue);
  });

  test('deux ZColorConfig() simples restent égaux + hash cohérent', () {
    const a = ZColorConfig();
    const b = ZColorConfig();
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('R3 : un ZColorConfig() mono DIFFÈRE d\'un ZColorConfig.multiple()', () {
    const mono = ZColorConfig();
    const multi = ZColorConfig.multiple();
    // Rougit si `multiple` est retiré de operator == (les deux deviendraient
    // égaux car tous les autres champs sont à leurs défauts identiques).
    expect(mono, isNot(equals(multi)));
    expect(mono.hashCode, isNot(equals(multi.hashCode)));
  });

  test('deux ZColorConfig.multiple() aux mêmes champs sont égaux', () {
    const a = ZColorConfig.multiple(enableAlpha: true, recentColors: <int>[1]);
    const b = ZColorConfig.multiple(enableAlpha: true, recentColors: <int>[1]);
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('les autres champs restent additifs (défauts préservés)', () {
    const cfg = ZColorConfig.multiple();
    expect(cfg.enableAlpha, isFalse);
    expect(cfg.showPalette, isTrue);
    expect(cfg.showRecent, isTrue);
    expect(cfg.recentColors, isEmpty);
  });
}
