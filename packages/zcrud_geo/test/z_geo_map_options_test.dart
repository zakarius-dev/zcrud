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
      // G22 — GARDE DE CHANGEMENT DE DÉFAUT (parité legacy gec:293-294) :
      // rotation/tilt désormais INACTIFS par défaut. Un hôte qui comptait sur
      // `true` doit opter explicitement (cf. note handoff du constructeur).
      expect(o.rotateGesturesEnabled, isFalse,
          reason: 'G22 : défaut legacy rotateGesturesEnabled=false');
      expect(o.tiltGesturesEnabled, isFalse,
          reason: 'G22 : défaut legacy tiltGesturesEnabled=false');
      expect(o.zoomControlsEnabled, isTrue);
      expect(o.compassEnabled, isTrue);
      expect(o.mapToolbarEnabled, isTrue);
      // G21 — point bleu natif : opt-in (`false` — la permission appartient à
      // l'hôte, divergence documentée vs legacy gec:298) ; bouton natif au
      // défaut SDK (`true`, inerte tant que myLocationEnabled est false).
      expect(o.myLocationEnabled, isFalse,
          reason: 'G21 : opt-in, jamais un défaut qui exige une permission');
      expect(o.myLocationButtonEnabled, isTrue);
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
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
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
      expect(o.myLocationEnabled, isTrue);
      expect(o.myLocationButtonEnabled, isFalse);
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
