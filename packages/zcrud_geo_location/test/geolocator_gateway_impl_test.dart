// Tests de la passerelle geolocator RÉELLE — uniquement sa partie PUR-DART
// (mapping de permission + constantes de lecture). Le canal natif du plugin
// n'est pas atteignable en test : les branches de comportement vivent dans
// zcrud_geolocator_resolver_test.dart via le fake du port.

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zcrud_geo_location/src/geolocator_gateway_impl.dart';
import 'package:zcrud_geo_location/zcrud_geo_location.dart';

void main() {
  group('mapLocationPermission — projection des 5 valeurs plugin', () {
    test('denied → denied (redemande possible)', () {
      expect(
        GeolocatorGateway.mapLocationPermission(LocationPermission.denied),
        ZGeoLocationPermission.denied,
      );
    });

    test('deniedForever → deniedForever (jamais de redemande)', () {
      expect(
        GeolocatorGateway.mapLocationPermission(
          LocationPermission.deniedForever,
        ),
        ZGeoLocationPermission.deniedForever,
      );
    });

    test('whileInUse et always → granted', () {
      expect(
        GeolocatorGateway.mapLocationPermission(LocationPermission.whileInUse),
        ZGeoLocationPermission.granted,
      );
      expect(
        GeolocatorGateway.mapLocationPermission(LocationPermission.always),
        ZGeoLocationPermission.granted,
      );
    });

    test('unableToDetermine → granted (parité gff:232-241 : le legacy tente '
        'la lecture — un échec réel devient la cause error)', () {
      expect(
        GeolocatorGateway.mapLocationPermission(
          LocationPermission.unableToDetermine,
        ),
        ZGeoLocationPermission.granted,
      );
    });
  });

  group('réglages de lecture — parité legacy gff:242-246', () {
    test('LocationAccuracy.high', () {
      expect(
        GeolocatorGateway.locationSettings.accuracy,
        LocationAccuracy.high,
      );
    });

    test('distanceFilter 10, timeLimit 10 s', () {
      expect(GeolocatorGateway.locationSettings.distanceFilter, 10);
      expect(
        GeolocatorGateway.locationSettings.timeLimit,
        const Duration(seconds: 10),
      );
    });
  });
}
