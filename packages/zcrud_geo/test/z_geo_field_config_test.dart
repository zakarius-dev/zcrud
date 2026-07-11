// AC3 — `ZGeoFieldConfig` : sous-classe additive `const` de `ZFieldConfig`
// (AD-4), vit dans zcrud_geo, portée par `ZFieldSpec.config` et lue via
// `ctx.field.config`. Aucune modification de zcrud_core. Défauts neutres
// surchargeables (AD-12). ==/hashCode corrects.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  group('AC3 — nature & égalité', () {
    test('ZGeoFieldConfig est un ZFieldConfig (base cœur, AD-4)', () {
      const cfg = ZGeoFieldConfig(geometry: ZGeoGeometry.circle);
      expect(cfg, isA<ZFieldConfig>());
    });

    test('const : deux configs identiques sont canonicalisées', () {
      const a = ZGeoFieldConfig(geometry: ZGeoGeometry.circle);
      const b = ZGeoFieldConfig(geometry: ZGeoGeometry.circle);
      expect(identical(a, b), isTrue);
    });

    test('défauts neutres (AD-12) : tout null / interactive true', () {
      const cfg = ZGeoFieldConfig();
      expect(cfg.geometry, isNull);
      expect(cfg.defaultCenter, isNull);
      expect(cfg.defaultZoom, isNull);
      expect(cfg.mapHeight, isNull);
      expect(cfg.tileUrlTemplate, isNull);
      expect(cfg.mapStyleJson, isNull);
      expect(cfg.interactive, isTrue);
      // DP-7 : toolbarConfig additif, défaut null (rétro-compat stricte).
      expect(cfg.toolbarConfig, isNull);
    });

    test('== et hashCode par valeur', () {
      const a = ZGeoFieldConfig(
        geometry: ZGeoGeometry.circle,
        defaultCenter: ZGeoPoint(lat: 1, lng: 2),
        defaultZoom: 10,
        mapHeight: 300,
      );
      const b = ZGeoFieldConfig(
        geometry: ZGeoGeometry.circle,
        defaultCenter: ZGeoPoint(lat: 1, lng: 2),
        defaultZoom: 10,
        mapHeight: 300,
      );
      const c = ZGeoFieldConfig(geometry: ZGeoGeometry.point);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('DP-7 (AC3) — toolbarConfig additif, rétro-compat stricte', () {
    test('config sans toolbarConfig == config E11b-1 équivalente', () {
      // Une config construite AVANT DP-7 (sans toolbarConfig) reste == à une
      // config identique : l\'ajout du champ n\'a pas cassé l\'égalité.
      const before = ZGeoFieldConfig(
        geometry: ZGeoGeometry.circle,
        defaultZoom: 10,
      );
      const after = ZGeoFieldConfig(
        geometry: ZGeoGeometry.circle,
        defaultZoom: 10,
      );
      expect(before, equals(after));
      expect(before.hashCode, equals(after.hashCode));
      expect(before.toolbarConfig, isNull);
    });

    test('toolbarConfig différencie l\'égalité', () {
      const a = ZGeoFieldConfig();
      const b = ZGeoFieldConfig(
        toolbarConfig: ZGeoEditorToolbarConfig.standard,
      );
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('copyWith propage toolbarConfig', () {
      const base = ZGeoFieldConfig();
      final withBar = base.copyWith(
        toolbarConfig: ZGeoEditorToolbarConfig.full,
      );
      expect(withBar.toolbarConfig, ZGeoEditorToolbarConfig.full);
      // Les autres champs restent intacts.
      expect(withBar.interactive, isTrue);
      // copyWith sans argument → identique.
      expect(base.copyWith(), equals(base));
    });
  });

  group('AC3 — portée par ZFieldSpec.config, lue sans toucher le cœur', () {
    test('ZFieldSpec.config accepte une ZGeoFieldConfig', () {
      const spec = ZFieldSpec(
        name: 'zone',
        type: EditionFieldType.location,
        config: ZGeoFieldConfig(geometry: ZGeoGeometry.circle),
      );
      expect(spec.config, isA<ZGeoFieldConfig>());
      expect(
        (spec.config! as ZGeoFieldConfig).geometry,
        ZGeoGeometry.circle,
      );
    });

    test('copyWith préserve la config géo', () {
      const spec = ZFieldSpec(
        name: 'zone',
        type: EditionFieldType.location,
        config: ZGeoFieldConfig(geometry: ZGeoGeometry.circle),
      );
      final ro = spec.copyWith(readOnly: true);
      expect((ro.config! as ZGeoFieldConfig).geometry, ZGeoGeometry.circle);
    });
  });
}
