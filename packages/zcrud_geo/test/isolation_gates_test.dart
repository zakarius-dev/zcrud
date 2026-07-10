// AC9/AC10/AC11 — Gates d'isolation (AD-1/AD-12), rejoués comme tests :
//   - `zcrud_core/pubspec.yaml` ne tire AUCUNE lib carte ;
//   - la lib carte n'est déclarée qu'au `pubspec.yaml` de `zcrud_geo` ;
//   - aucun secret/clé/`badCertificateCallback` dans `lib/` de `zcrud_geo` ;
//   - le barrel principal n'exporte AUCUN symbole SDK carte (voie confinée).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _mapLibs = <String>[
  'google_maps_flutter',
  'flutter_map',
  'flutter_osm_plugin',
  'latlong2',
];

String _read(String path) {
  // Les tests s'exécutent depuis la racine du package `zcrud_geo`.
  final candidates = <String>[path, '../../$path'];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable pour le gate : $path');
}

void main() {
  group('AC9 — isolation : zcrud_core ne tire AUCUNE lib carte', () {
    test('pubspec de zcrud_core sans dépendance carte', () {
      final core = _read('packages/zcrud_core/pubspec.yaml');
      for (final lib in _mapLibs) {
        expect(core.contains('$lib:'), isFalse,
            reason: 'zcrud_core ne doit PAS dépendre de $lib (AD-1)');
      }
    });

    test('la lib carte est déclarée dans le pubspec de zcrud_geo', () {
      final geo = _read('packages/zcrud_geo/pubspec.yaml');
      expect(geo.contains('flutter_map:'), isTrue);
      expect(geo.contains('latlong2:'), isTrue);
    });
  });

  group('AC10 — secrets : aucune clé/endpoint privé dans zcrud_geo/lib', () {
    test('aucun secret ni badCertificateCallback', () {
      final dir = Directory('packages/zcrud_geo/lib').existsSync()
          ? Directory('packages/zcrud_geo/lib')
          : Directory('lib');
      final googleKey = RegExp('AIza' r'[0-9A-Za-z_\-]{35}');
      final badCert = RegExp(r'badCertificateCallback\s*(=>|=)');
      for (final e in dir.listSync(recursive: true).whereType<File>()) {
        if (!e.path.endsWith('.dart')) continue;
        final src = e.readAsStringSync();
        expect(googleKey.hasMatch(src), isFalse,
            reason: 'clé Google en dur interdite dans ${e.path}');
        expect(badCert.hasMatch(src), isFalse,
            reason: 'badCertificateCallback interdit dans ${e.path}');
      }
    });
  });

  group('AC11 — signature : barrel principal sans symbole SDK carte', () {
    test('lib/zcrud_geo.dart n\'exporte ni flutter_map ni latlong2', () {
      final barrel = _read('packages/zcrud_geo/lib/zcrud_geo.dart');
      // On inspecte UNIQUEMENT les directives export/import (la prose des
      // doc-comments cite légitimement les libs comme contre-exemples).
      final directives = barrel
          .split('\n')
          .where((l) {
            final t = l.trimLeft();
            return t.startsWith('export ') || t.startsWith('import ');
          })
          .join('\n');
      expect(directives.contains('flutter_map'), isFalse);
      expect(directives.contains('latlong2'), isFalse);
      expect(directives.contains('adapters/'), isFalse,
          reason: 'l\'adaptateur OSM (SDK confiné) est atteint par une entrée '
              'dédiée, jamais par le barrel principal');
    });
  });

  group('AD-13 — audit statique RTL (aucun inset/alignement non directionnel)',
      () {
    test('lib/ sans EdgeInsets.only(left/right) ni Alignment.centerLeft/Right',
        () {
      final dir = Directory('packages/zcrud_geo/lib').existsSync()
          ? Directory('packages/zcrud_geo/lib')
          : Directory('lib');
      final banned = <RegExp>[
        RegExp(r'EdgeInsets\.only\([^)]*\b(left|right)\s*:'),
        RegExp(r'Alignment\.center(Left|Right)\b'),
        RegExp(r'TextAlign\.(left|right)\b'),
        RegExp(r'Positioned\([^)]*\b(left|right)\s*:'),
      ];
      for (final e in dir.listSync(recursive: true).whereType<File>()) {
        if (!e.path.endsWith('.dart')) continue;
        final src = e.readAsStringSync();
        for (final re in banned) {
          expect(re.hasMatch(src), isFalse,
              reason: 'motif non directionnel (AD-13) dans ${e.path} : '
                  '${re.pattern}');
        }
      }
    });
  });
}
