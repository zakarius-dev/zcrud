// DP-7 (AC6) — `ZGeoMapType` + `ZGeoMapOptions` : enum neutre, état `const`,
// copyWith / == / hashCode.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  group('ZGeoMapType — enum neutre camelCase', () {
    test('valeurs canoniques', () {
      expect(ZGeoMapType.values, <ZGeoMapType>[
        ZGeoMapType.normal,
        ZGeoMapType.hybrid,
        ZGeoMapType.satellite,
        ZGeoMapType.terrain,
      ]);
      expect(ZGeoMapType.normal.name, 'normal');
      expect(ZGeoMapType.hybrid.name, 'hybrid');
      expect(ZGeoMapType.satellite.name, 'satellite');
      expect(ZGeoMapType.terrain.name, 'terrain');
    });
  });

  group('ZGeoMapOptions — état neutre const', () {
    test('défauts alignés sur le defaultState DODLP (MEDIUM-1 DP-7)', () {
      const o = ZGeoMapOptions();
      expect(o.mapType, ZGeoMapType.hybrid);
      expect(o.trafficEnabled, isFalse);
      expect(o.buildingsEnabled, isTrue);
      expect(o.indoorViewEnabled, isFalse);
      expect(o.rotateGesturesEnabled, isTrue);
      expect(o.tiltGesturesEnabled, isTrue);
      expect(o.zoomControlsEnabled, isTrue);
      expect(o.compassEnabled, isTrue);
      expect(o.mapToolbarEnabled, isTrue);
    });

    test('copyWith couvre tous les champs', () {
      const base = ZGeoMapOptions();
      final o = base.copyWith(
        mapType: ZGeoMapType.satellite,
        trafficEnabled: true,
        buildingsEnabled: true,
        indoorViewEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        zoomControlsEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: true,
      );
      expect(o.mapType, ZGeoMapType.satellite);
      expect(o.trafficEnabled, isTrue);
      expect(o.buildingsEnabled, isTrue);
      expect(o.indoorViewEnabled, isTrue);
      expect(o.rotateGesturesEnabled, isTrue);
      expect(o.tiltGesturesEnabled, isTrue);
      expect(o.zoomControlsEnabled, isTrue);
      expect(o.compassEnabled, isTrue);
      expect(o.mapToolbarEnabled, isTrue);
      expect(base.copyWith(), equals(base));
    });

    test('== et hashCode', () {
      const a = ZGeoMapOptions();
      const b = ZGeoMapOptions();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      final c = a.copyWith(mapType: ZGeoMapType.terrain);
      expect(a, isNot(equals(c)));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });
  });
}
