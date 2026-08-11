// Tests du resolver « ma position » (G10, parité legacy gff:219-265).
//
// Le plugin geolocator ne tourne pas en test : TOUTES les branches passent par
// un fake du port neutre ZGeoLocationGateway. Chaque cause d'échec est
// affirmée DISTINCTE, le contrat AD-10 (jamais de throw) est prouvé sur
// chaque étage du cycle, et l'ordre des appels plateforme est mesuré.

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';
import 'package:zcrud_geo_location/zcrud_geo_location.dart';

/// Fake scriptable du port plugin : chaque étage est soit une valeur, soit un
/// throw ; le journal [calls] permet d'affirmer l'ordre et les non-appels.
class _FakeGateway implements ZGeoLocationGateway {
  _FakeGateway({
    this.serviceEnabled = true,
    this.checkResult = ZGeoLocationPermission.granted,
    this.requestResult = ZGeoLocationPermission.granted,
    this.position,
    this.serviceThrows = false,
    this.checkThrows = false,
    this.requestThrows = false,
    this.positionThrows = false,
  });

  bool serviceEnabled;
  ZGeoLocationPermission checkResult;
  ZGeoLocationPermission requestResult;
  ZGeoPoint? position;
  bool serviceThrows;
  bool checkThrows;
  bool requestThrows;
  bool positionThrows;

  final List<String> calls = <String>[];

  @override
  Future<bool> isServiceEnabled() async {
    calls.add('service');
    if (serviceThrows) throw StateError('service check failed');
    return serviceEnabled;
  }

  @override
  Future<ZGeoLocationPermission> checkPermission() async {
    calls.add('check');
    if (checkThrows) throw StateError('check failed');
    return checkResult;
  }

  @override
  Future<ZGeoLocationPermission> requestPermission() async {
    calls.add('request');
    if (requestThrows) throw StateError('request failed');
    return requestResult;
  }

  @override
  Future<ZGeoPoint> currentPosition() async {
    calls.add('position');
    if (positionThrows) throw StateError('position read failed');
    return position ?? const ZGeoPoint(lat: 13.51, lng: 2.11);
  }
}

/// Exécute le resolver sur [gateway] et capture les causes notifiées.
Future<(ZGeoPoint?, List<ZGeoLocationFailureCause>)> _run(
  _FakeGateway gateway,
) async {
  final causes = <ZGeoLocationFailureCause>[];
  final resolver = zcrudGeolocatorResolver(
    onFailure: causes.add,
    gateway: gateway,
  );
  final point = await resolver();
  return (point, causes);
}

void main() {
  group('succès', () {
    test('permission accordée directement → point rendu, aucune cause, '
        'aucune redemande', () async {
      final gateway = _FakeGateway(
        position: const ZGeoPoint(lat: 13.5127, lng: 2.1126),
      );
      final (point, causes) = await _run(gateway);
      expect(point, isNotNull);
      expect(point!.lat, 13.5127);
      expect(point.lng, 2.1126);
      expect(causes, isEmpty, reason: 'onFailure ne fire jamais en succès');
      expect(
        gateway.calls,
        ['service', 'check', 'position'],
        reason: 'permission accordée → PAS de requestPermission (gff:233)',
      );
    });

    test('denied puis redemande accordée → succès (parité gff:234-237)',
        () async {
      final gateway = _FakeGateway(
        checkResult: ZGeoLocationPermission.denied,
        requestResult: ZGeoLocationPermission.granted,
      );
      final (point, causes) = await _run(gateway);
      expect(point, isNotNull);
      expect(causes, isEmpty);
      expect(gateway.calls, ['service', 'check', 'request', 'position']);
    });
  });

  group('service désactivé', () {
    test('→ null + cause serviceDisabled, permission JAMAIS consultée '
        '(ordre legacy gff:221-231)', () async {
      final gateway = _FakeGateway(serviceEnabled: false);
      final (point, causes) = await _run(gateway);
      expect(point, isNull);
      expect(causes, [ZGeoLocationFailureCause.serviceDisabled]);
      expect(
        gateway.calls,
        ['service'],
        reason: 'le legacy sort AVANT tout contrôle de permission',
      );
    });
  });

  group('permission', () {
    test('denied puis denied à la redemande → cause permissionDenied, UNE '
        'seule redemande, pas de lecture', () async {
      final gateway = _FakeGateway(
        checkResult: ZGeoLocationPermission.denied,
        requestResult: ZGeoLocationPermission.denied,
      );
      final (point, causes) = await _run(gateway);
      expect(point, isNull);
      expect(causes, [ZGeoLocationFailureCause.permissionDenied]);
      expect(gateway.calls, ['service', 'check', 'request']);
    });

    test('deniedForever au contrôle → cause permissionDeniedForever SANS '
        'redemande (parité gff:240 : denied seul déclenche la redemande)',
        () async {
      final gateway = _FakeGateway(
        checkResult: ZGeoLocationPermission.deniedForever,
      );
      final (point, causes) = await _run(gateway);
      expect(point, isNull);
      expect(causes, [ZGeoLocationFailureCause.permissionDeniedForever]);
      expect(
        gateway.calls,
        ['service', 'check'],
        reason: 'deniedForever ne doit JAMAIS redemander',
      );
    });

    test('denied puis deniedForever à la redemande → cause '
        'permissionDeniedForever (pas permissionDenied)', () async {
      final gateway = _FakeGateway(
        checkResult: ZGeoLocationPermission.denied,
        requestResult: ZGeoLocationPermission.deniedForever,
      );
      final (point, causes) = await _run(gateway);
      expect(point, isNull);
      expect(causes, [ZGeoLocationFailureCause.permissionDeniedForever]);
      expect(gateway.calls, ['service', 'check', 'request']);
    });
  });

  group('AD-10 — jamais de throw, cause error', () {
    for (final (label, gateway) in <(String, _FakeGateway)>[
      ('throw au contrôle de service', _FakeGateway(serviceThrows: true)),
      ('throw au contrôle de permission', _FakeGateway(checkThrows: true)),
      (
        'throw à la redemande',
        _FakeGateway(
          checkResult: ZGeoLocationPermission.denied,
          requestThrows: true,
        ),
      ),
      ('throw à la lecture de position', _FakeGateway(positionThrows: true)),
    ]) {
      test('$label → null + cause error, aucune exception', () async {
        final (point, causes) = await _run(gateway);
        expect(point, isNull);
        expect(causes, [ZGeoLocationFailureCause.error]);
      });
    }

    test('position hors-bornes (lat 91) → null + cause error, jamais '
        'réinjectée dans le champ', () async {
      final gateway = _FakeGateway(
        position: const ZGeoPoint(lat: 91, lng: 0),
      );
      final (point, causes) = await _run(gateway);
      expect(point, isNull);
      expect(causes, [ZGeoLocationFailureCause.error]);
    });

    test('position non finie (lat NaN) → null + cause error', () async {
      final gateway = _FakeGateway(
        position: const ZGeoPoint(lat: double.nan, lng: 0),
      );
      final (point, causes) = await _run(gateway);
      expect(point, isNull);
      expect(causes, [ZGeoLocationFailureCause.error]);
    });

    test('sans onFailure, chaque branche d\'échec rend null sans crasher',
        () async {
      for (final gateway in <_FakeGateway>[
        _FakeGateway(serviceEnabled: false),
        _FakeGateway(
          checkResult: ZGeoLocationPermission.denied,
          requestResult: ZGeoLocationPermission.denied,
        ),
        _FakeGateway(checkResult: ZGeoLocationPermission.deniedForever),
        _FakeGateway(positionThrows: true),
      ]) {
        final resolver = zcrudGeolocatorResolver(gateway: gateway);
        expect(await resolver(), isNull);
      }
    });

    test('un onFailure hôte qui THROW est avalé — le resolver rend null '
        '(AD-10 : aucune exception ne s\'échappe)', () async {
      final gateway = _FakeGateway(serviceEnabled: false);
      final resolver = zcrudGeolocatorResolver(
        onFailure: (_) => throw StateError('listener hôte défaillant'),
        gateway: gateway,
      );
      expect(await resolver(), isNull);
    });
  });

  group('conformité au port zcrud_geo', () {
    test('la fabrique produit bien un ZGeoLocationResolver assignable au '
        'seam du champ (types zcrud_geo uniquement)', () {
      final ZGeoLocationResolver resolver =
          zcrudGeolocatorResolver(gateway: _FakeGateway());
      expect(resolver, isA<Future<ZGeoPoint?> Function()>());
    });

    test('chaque appel du resolver rejoue le cycle COMPLET (service '
        're-vérifié — l\'utilisateur peut l\'avoir désactivé entre-temps)',
        () async {
      final gateway = _FakeGateway();
      final resolver = zcrudGeolocatorResolver(gateway: gateway);
      await resolver();
      gateway.serviceEnabled = false;
      expect(await resolver(), isNull);
      expect(gateway.calls, [
        'service', 'check', 'position', // 1er appel
        'service', // 2e appel : re-vérifié et court-circuité
      ]);
    });
  });
}
