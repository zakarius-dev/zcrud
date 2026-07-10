// AC9/AC10/AC11 — Gates d'isolation (AD-1/AD-12/AD-13), rejoués comme tests :
//   - `zcrud_core/pubspec.yaml` ne tire AUCUNE lib intl/téléphone ;
//   - la lib téléphone n'est déclarée qu'au `pubspec.yaml` de `zcrud_intl` ;
//   - le barrel principal n'exporte AUCUN symbole de lib tierce (voie confinée) ;
//   - aucun secret/clé/endpoint/`badCertificateCallback` dans `lib/` ;
//   - aucun inset/alignement non directionnel (RTL, AD-13).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _intlLibs = <String>[
  'phone_numbers_parser',
  'libphonenumber_plugin',
  'dlibphonenumber',
  'intl_phone_field',
  'intl_phone_number_input',
  'country_picker',
  'country_code_picker',
];

String _read(String path) {
  final candidates = <String>[path, '../../$path'];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable pour le gate : $path');
}

Directory _libDir() => Directory('packages/zcrud_intl/lib').existsSync()
    ? Directory('packages/zcrud_intl/lib')
    : Directory('lib');

void main() {
  group('AC9 — isolation : zcrud_core ne tire AUCUNE lib intl/téléphone', () {
    test('pubspec de zcrud_core sans dépendance intl/téléphone', () {
      final core = _read('packages/zcrud_core/pubspec.yaml');
      for (final lib in _intlLibs) {
        expect(core.contains('$lib:'), isFalse,
            reason: 'zcrud_core ne doit PAS dépendre de $lib (AD-1)');
      }
    });

    test('la lib téléphone est déclarée dans le pubspec de zcrud_intl', () {
      final intl = _read('packages/zcrud_intl/pubspec.yaml');
      expect(intl.contains('phone_numbers_parser:'), isTrue);
    });

    test('l\'asset countries.json n\'est déclaré qu\'au pubspec de zcrud_intl', () {
      final intl = _read('packages/zcrud_intl/pubspec.yaml');
      expect(intl.contains('assets/countries.json'), isTrue);
      final core = _read('packages/zcrud_core/pubspec.yaml');
      expect(core.contains('countries.json'), isFalse);
    });
  });

  group('AC10 — signature : barrel principal sans symbole de lib tierce', () {
    test('lib/zcrud_intl.dart n\'exporte/n\'importe aucune lib intl', () {
      final barrel = _read('packages/zcrud_intl/lib/zcrud_intl.dart');
      final directives = barrel
          .split('\n')
          .where((l) {
            final t = l.trimLeft();
            return t.startsWith('export ') || t.startsWith('import ');
          })
          .join('\n');
      for (final lib in _intlLibs) {
        expect(directives.contains(lib), isFalse,
            reason: 'le barrel ne doit pas exposer $lib (AD-1)');
      }
      // Le pont confiné ne doit PAS être exporté (reste interne).
      expect(directives.contains('z_phone_codec'), isFalse);
    });

    test('un seul fichier importe phone_numbers_parser (confinement AD-1)', () {
      final importers = <String>[];
      for (final e in _libDir().listSync(recursive: true).whereType<File>()) {
        if (!e.path.endsWith('.dart')) continue;
        final src = e.readAsStringSync();
        if (RegExp(r'''import\s+['"]package:phone_numbers_parser''')
            .hasMatch(src)) {
          importers.add(e.path);
        }
      }
      expect(importers, hasLength(1),
          reason: 'phone_numbers_parser doit être confiné à z_phone_codec.dart '
              '(trouvé: $importers)');
      expect(importers.single.endsWith('z_phone_codec.dart'), isTrue);
    });
  });

  group('AC11 — secrets : aucune clé/endpoint/badCertificate dans lib/', () {
    test('aucun secret ni badCertificateCallback', () {
      final googleKey = RegExp('AIza' r'[0-9A-Za-z_\-]{35}');
      final badCert = RegExp(r'badCertificateCallback\s*(=>|=)');
      final httpUrl = RegExp(r'https?://[a-zA-Z0-9.\-]+');
      for (final e in _libDir().listSync(recursive: true).whereType<File>()) {
        if (!e.path.endsWith('.dart')) continue;
        final src = e.readAsStringSync();
        expect(googleKey.hasMatch(src), isFalse,
            reason: 'clé Google en dur interdite dans ${e.path}');
        expect(badCert.hasMatch(src), isFalse,
            reason: 'badCertificateCallback interdit dans ${e.path}');
        expect(httpUrl.hasMatch(src), isFalse,
            reason: 'endpoint réseau en dur interdit (MVP hors-ligne) dans '
                '${e.path}');
      }
    });
  });

  group('AD-13 — audit statique RTL (aucun inset/alignement non directionnel)',
      () {
    test('lib/ sans EdgeInsets.only(left/right) ni Alignment.centerLeft/Right',
        () {
      final banned = <RegExp>[
        RegExp(r'EdgeInsets\.only\([^)]*\b(left|right)\s*:'),
        RegExp(r'Alignment\.center(Left|Right)\b'),
        RegExp(r'TextAlign\.(left|right)\b'),
        RegExp(r'Positioned\([^)]*\b(left|right)\s*:'),
      ];
      for (final e in _libDir().listSync(recursive: true).whereType<File>()) {
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
