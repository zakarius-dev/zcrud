// AC9/AC10/AC11/AC12 — Gates d'isolation (AD-1/AD-12/AD-13), rejoués comme
// tests. Étendus E11b-2 (AI-E10-2 : garde grep cwd-robuste + strip-comment,
// denylist complète, couverture des nouveaux fichiers `z_currency_*`/`z_state_*`/
// `z_subdivision_*`/`z_money*`/`z_option_picker_*`) :
//   - `zcrud_core/pubspec.yaml` ne tire AUCUNE lib intl/téléphone/devise ;
//   - la lib téléphone n'est déclarée qu'au `pubspec.yaml` de `zcrud_intl` et
//     reste CONFINÉE à `z_phone_codec.dart` ;
//   - AUCUNE nouvelle lib intl/devise lourde ajoutée (`intl`/`money2`/
//     `currency_picker`…) ;
//   - le barrel n'exporte AUCUN symbole de lib tierce (voie confinée) ;
//   - aucun secret/clé/endpoint/`badCertificateCallback` dans `lib/` ;
//   - aucun inset/alignement/couleur non directionnel ou codé en dur (AD-13),
//     comparé sur du source **dé-commenté** (strip-comment : un motif en
//     commentaire ne déclenche PAS de faux positif).
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

/// Libs lourdes intl/devise/formatage à NE PAS ajouter (E11b-2, AD-1/AD-12) :
/// devise/états sont servis par des assets JSON bundlés, pas par une dép runtime.
const _bannedHeavyLibs = <String>[
  'intl',
  'money2',
  'currency_picker',
  'currency_text_input_formatter',
  'flutter_money_formatter',
  'world_countries',
];

/// DP-8 (gap B10) : libs réseau/géocodage à NE PAS ajouter — le seam
/// [ZPlaceSearchProvider] est **vide de tout réseau** (l'implémentation vit hors
/// package, AD-12 : ZÉRO clé/endpoint/réseau dans `zcrud_intl`).
const _bannedNetworkLibs = <String>[
  'http',
  'dio',
  'google_maps_webservice',
  'flutter_google_places',
  'google_places_flutter',
  'google_maps_flutter',
  'geocoding',
];

/// DP-8 : fichiers domaine **pur-Dart** (codec + seam) — aucune lib lourde,
/// aucun Flutter (AD-14).
const _pureDartDomainFiles = <String>[
  'z_address_codec.dart',
  'z_place_search_provider.dart',
];

/// Lecture **cwd-robuste** : le gate doit passer que `flutter test` soit lancé à
/// la racine du workspace OU dans le dossier du package.
String _read(String path) {
  final candidates = <String>[path, '../../$path', _underPackage(path)];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable pour le gate : $path');
}

/// Traduit un chemin repo-relatif en chemin package-relatif (cwd = package).
String _underPackage(String repoPath) {
  const prefix = 'packages/zcrud_intl/';
  return repoPath.startsWith(prefix) ? repoPath.substring(prefix.length) : repoPath;
}

Directory _libDir() => Directory('packages/zcrud_intl/lib').existsSync()
    ? Directory('packages/zcrud_intl/lib')
    : Directory('lib');

/// Supprime les commentaires Dart (`// …` et `/* … */`) pour que les gardes de
/// motifs ne matchent PAS un exemple cité en commentaire (AI-E10-2).
String _stripComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
  final buffer = StringBuffer();
  for (final line in noBlock.split('\n')) {
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}

Iterable<File> _dartFiles() =>
    _libDir().listSync(recursive: true).whereType<File>().where(
          (e) => e.path.endsWith('.dart'),
        );

void main() {
  group('AC11 — isolation : zcrud_core ne tire AUCUNE lib intl/téléphone/devise',
      () {
    test('pubspec de zcrud_core sans dépendance intl/téléphone', () {
      final core = _read('packages/zcrud_core/pubspec.yaml');
      for (final lib in <String>[..._intlLibs, ..._bannedHeavyLibs]) {
        expect(core.contains('$lib:'), isFalse,
            reason: 'zcrud_core ne doit PAS dépendre de $lib (AD-1)');
      }
    });

    test('la lib téléphone est déclarée dans le pubspec de zcrud_intl', () {
      final intl = _read('packages/zcrud_intl/pubspec.yaml');
      expect(intl.contains('phone_numbers_parser:'), isTrue);
    });

    test('AUCUNE nouvelle lib intl/devise lourde ajoutée à zcrud_intl (E11b-2)',
        () {
      final intl = _read('packages/zcrud_intl/pubspec.yaml');
      for (final lib in _bannedHeavyLibs) {
        expect(RegExp('^\\s+$lib:', multiLine: true).hasMatch(intl), isFalse,
            reason: 'zcrud_intl ne doit PAS ajouter $lib (assets JSON bundlés — '
                'AD-1/AD-12)');
      }
    });

    test('les assets intl ne sont déclarés qu\'au pubspec de zcrud_intl', () {
      final intl = _read('packages/zcrud_intl/pubspec.yaml');
      expect(intl.contains('assets/countries.json'), isTrue);
      expect(intl.contains('assets/currencies.json'), isTrue);
      expect(intl.contains('assets/subdivisions.json'), isTrue);
      final core = _read('packages/zcrud_core/pubspec.yaml');
      expect(core.contains('countries.json'), isFalse);
      expect(core.contains('currencies.json'), isFalse);
      expect(core.contains('subdivisions.json'), isFalse);
    });
  });

  group('AC11 — signature : barrel principal sans symbole de lib tierce', () {
    test('lib/zcrud_intl.dart n\'exporte/n\'importe aucune lib intl/devise', () {
      final barrel = _read('packages/zcrud_intl/lib/zcrud_intl.dart');
      final directives = barrel
          .split('\n')
          .where((l) {
            final t = l.trimLeft();
            return t.startsWith('export ') || t.startsWith('import ');
          })
          .join('\n');
      for (final lib in <String>[..._intlLibs, ..._bannedHeavyLibs]) {
        expect(directives.contains('package:$lib'), isFalse,
            reason: 'le barrel ne doit pas exposer $lib (AD-1)');
      }
      // Le pont confiné + le picker inline interne ne sont PAS exportés.
      expect(directives.contains('z_phone_codec'), isFalse);
      expect(directives.contains('z_country_picker_field'), isFalse);
      expect(directives.contains('z_option_picker_field'), isFalse);
    });

    test('un seul fichier importe phone_numbers_parser (confinement AD-1)', () {
      final importers = <String>[];
      for (final e in _dartFiles()) {
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

  group('AC12 — secrets : aucune clé/endpoint/badCertificate dans lib/', () {
    test('aucun secret ni badCertificateCallback', () {
      final googleKey = RegExp('AIza' r'[0-9A-Za-z_\-]{35}');
      final badCert = RegExp(r'badCertificateCallback\s*(=>|=)');
      final httpUrl = RegExp(r'https?://[a-zA-Z0-9.\-]+');
      for (final e in _dartFiles()) {
        final src = _stripComments(e.readAsStringSync());
        expect(googleKey.hasMatch(src), isFalse,
            reason: 'clé Google en dur interdite dans ${e.path}');
        expect(badCert.hasMatch(src), isFalse,
            reason: 'badCertificateCallback interdit dans ${e.path}');
        expect(httpUrl.hasMatch(src), isFalse,
            reason: 'endpoint réseau en dur interdit (hors-ligne) dans '
                '${e.path}');
      }
    });
  });

  group('DP-8 — seam recherche géo : ZÉRO clé/endpoint/réseau (AD-12)', () {
    test('pubspec de zcrud_intl ne déclare AUCUNE lib réseau/géocodage', () {
      final intl = _read('packages/zcrud_intl/pubspec.yaml');
      for (final lib in _bannedNetworkLibs) {
        expect(RegExp('^\\s+$lib:', multiLine: true).hasMatch(intl), isFalse,
            reason: 'zcrud_intl ne doit PAS ajouter $lib (le seam est vide de '
                'tout réseau — AD-12)');
      }
    });

    test('aucun fichier lib/ n\'importe une lib réseau/géocodage', () {
      for (final e in _dartFiles()) {
        final src = _stripComments(e.readAsStringSync());
        for (final lib in _bannedNetworkLibs) {
          expect(src.contains('package:$lib/'), isFalse,
              reason: 'import réseau interdit ($lib) dans ${e.path} — le seam '
                  'DP-8 reste agnostique (AD-12)');
        }
      }
    });

    test('le barrel n\'expose AUCUNE lib réseau/géocodage', () {
      final barrel = _read('packages/zcrud_intl/lib/zcrud_intl.dart');
      for (final lib in _bannedNetworkLibs) {
        expect(barrel.contains('package:$lib'), isFalse,
            reason: 'le barrel ne doit pas exposer $lib (AD-1/AD-12)');
      }
    });

    test('codec + seam sont pur-Dart (aucun Flutter, AD-14)', () {
      for (final name in _pureDartDomainFiles) {
        final matches =
            _dartFiles().where((e) => e.path.endsWith(name)).toList();
        expect(matches, hasLength(1),
            reason: 'fichier domaine DP-8 manquant : $name');
        final src = _stripComments(matches.single.readAsStringSync());
        expect(src.contains('package:flutter/'), isFalse,
            reason: '$name (couche domaine) ne doit importer AUCUN Flutter '
                '(AD-14)');
        for (final lib in <String>[..._bannedNetworkLibs, ..._bannedHeavyLibs]) {
          expect(src.contains('package:$lib/'), isFalse,
              reason: '$name ne doit importer aucune lib lourde ($lib)');
        }
      }
    });
  });

  group('AD-13 — audit statique RTL/couleur (strip-comment, cwd-robuste)', () {
    test('lib/ sans motif non directionnel ni couleur codée en dur', () {
      final banned = <RegExp>[
        RegExp(r'EdgeInsets\.only\([^)]*\b(left|right)\s*:'),
        RegExp(r'Alignment\.center(Left|Right)\b'),
        RegExp(r'TextAlign\.(left|right)\b'),
        RegExp(r'Positioned\([^)]*\b(left|right)\s*:'),
        RegExp(r'\bColors\.'),
        RegExp(r'Color\(0x'),
      ];
      for (final e in _dartFiles()) {
        // strip-comment (AI-E10-2) : un motif cité en commentaire ne compte pas.
        final src = _stripComments(e.readAsStringSync());
        for (final re in banned) {
          expect(re.hasMatch(src), isFalse,
              reason: 'motif interdit (AD-13) dans ${e.path} : ${re.pattern}');
        }
      }
    });

    test('lib/ n\'importe aucun gestionnaire d\'état (AD-2/AD-15)', () {
      final managers = <String>[
        'package:flutter_riverpod',
        'package:riverpod',
        'package:get/',
        'package:provider/',
      ];
      for (final e in _dartFiles()) {
        final src = _stripComments(e.readAsStringSync());
        for (final m in managers) {
          expect(src.contains(m), isFalse,
              reason: 'gestionnaire d\'état interdit dans ${e.path} : $m');
        }
      }
    });
  });
}
