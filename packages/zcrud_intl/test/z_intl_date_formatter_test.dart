// CR-DODLP-GAP3BIS — gardes de `ZIntlDateDisplayFormatter`, impl `intl` du port
// `ZDateDisplayFormatter` de `zcrud_core`.
//
// Ce FICHIER de test tourne dans son propre isolat (convention `package:test`) :
// c'est ce qui rend mordante la garde d'auto-initialisation des données de
// locale — aucun autre fichier n'a pu initialiser `intl` avant lui.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_intl/date_formatter.dart';

import 'support/z_sources.dart' show stripComments;

/// Dimanche 9 août 2026, 14:30 — la date de l'exemple DODLP.
final _sunday = DateTime(2026, 8, 9, 14, 30);

/// Lecture cwd-robuste (même convention que `isolation_gates_test.dart`).
String _read(String repoPath) {
  const prefix = 'packages/zcrud_intl/';
  final candidates = <String>[
    repoPath,
    '../../$repoPath',
    repoPath.startsWith(prefix) ? repoPath.substring(prefix.length) : repoPath,
  ];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable : $repoPath');
}

Directory _libDir() => Directory('packages/zcrud_intl/lib').existsSync()
    ? Directory('packages/zcrud_intl/lib')
    : Directory('lib');

Iterable<File> _dartFiles() => _libDir()
    .listSync(recursive: true)
    .whereType<File>()
    .where((e) => e.path.endsWith('.dart'));

/// Supprime les commentaires Dart : un exemple cité en dartdoc ne doit PAS
/// déclencher la garde FR-26 (le dartdoc de l'impl contient « dim. 9 août »).
///
/// 🔴 P0D2 : déléguée à `support/z_sources.dart` (scanner caractère par
/// caractère) — l'ancienne regex bloc locale pouvait avaler tout le fichier
/// sur une citation de chemin du type `packages/*/lib`.
String _stripComments(String src) => stripComments(src);

void main() {
  setUp(zDebugResetIntlDateFormatterCache);

  group('G-A — rendu localisé (données de locale, jamais des littéraux)', () {
    test(
        'G1 — mode date : `fr` et `en` rendent DEUX libellés localisés '
        'DIFFÉRENTS, sans que l\'hôte ait rien initialisé', () {
      const f = ZIntlDateDisplayFormatter();
      // Premier appel du fichier ⇒ prouve l'auto-initialisation des données de
      // locale (sans elle, `intl` lève `LocaleDataException` et l'impl décline).
      expect(
        f.format(_sunday, mode: ZDateMode.date, localeTag: 'fr'),
        'dimanche 9 août 2026',
      );
      expect(
        f.format(_sunday, mode: ZDateMode.date, localeTag: 'en-US'),
        'Sunday, August 9, 2026',
      );
    });

    test('G2 — mode dateTime : l\'heure est ajoutée, la date ne la porte pas',
        () {
      const f = ZIntlDateDisplayFormatter();
      expect(
        f.format(_sunday, mode: ZDateMode.dateTime, localeTag: 'fr'),
        'dimanche 9 août 2026 14:30',
      );
      expect(
        f.format(_sunday, mode: ZDateMode.date, localeTag: 'fr'),
        isNot(contains('14:30')),
      );
    });

    test('G3 — parité legacy DODLP : le patron explicite PRIME sur le défaut',
        () {
      const legacy = ZIntlDateDisplayFormatter(
        datePattern: 'EEE d MMM y',
        dateTimePattern: 'EEE d MMM y HH:mm',
      );
      expect(
        legacy.format(_sunday, mode: ZDateMode.date, localeTag: 'fr'),
        'dim. 9 août 2026',
      );
      expect(
        legacy.format(_sunday, mode: ZDateMode.dateTime, localeTag: 'fr'),
        'dim. 9 août 2026 14:30',
      );
      // ...et le patron de date NE contamine PAS le mode date+heure, ni
      // l'inverse : deux entrées de cache distinctes.
      const dateOnly = ZIntlDateDisplayFormatter(datePattern: 'y');
      expect(dateOnly.format(_sunday, mode: ZDateMode.date, localeTag: 'fr'),
          '2026');
      expect(
        dateOnly.format(_sunday, mode: ZDateMode.dateTime, localeTag: 'fr'),
        'dimanche 9 août 2026 14:30',
        reason: 'dateTimePattern absent ⇒ patron localisé par défaut',
      );
    });

    test(
        'G4 — étiquette à TIRETS et variantes acceptées, sans normalisation '
        'maison (`intl` canonicalise déjà)', () {
      const f = ZIntlDateDisplayFormatter();
      const expected = 'dimanche 9 août 2026';
      for (final tag in <String>['fr', 'fr-FR', 'fr_FR', 'fr-Latn-FR', 'FR']) {
        expect(f.format(_sunday, mode: ZDateMode.date, localeTag: tag), expected,
            reason: 'étiquette $tag');
      }
    });
  });

  group('G-B — AD-10 : DÉCLINER (`null`), jamais lever', () {
    test('G5 — locale INCONNUE ⇒ null (et non un `ArgumentError` qui remonte)',
        () {
      const f = ZIntlDateDisplayFormatter();
      for (final tag in <String>['zz', 'zz-ZZ', 'xx-YY-ZZ-WW']) {
        expect(f.format(_sunday, mode: ZDateMode.date, localeTag: tag), isNull,
            reason: 'étiquette $tag');
      }
    });

    test(
        'G6 — étiquette VIDE ⇒ null : elle ne doit PAS être confondue avec '
        '« pas d\'étiquette » (sentinelle de clé de cache)', () {
      const f = ZIntlDateDisplayFormatter();
      // On amorce d'abord le cache avec l'ABSENCE d'étiquette...
      final withoutTag = f.format(_sunday, mode: ZDateMode.date);
      expect(withoutTag, isNotNull);
      // ...puis on demande l'étiquette VIDE : invalide pour `intl`, elle doit
      // décliner et NON récupérer l'entrée de la locale par défaut.
      expect(f.format(_sunday, mode: ZDateMode.date, localeTag: ''), isNull);
    });

    test('G7 — patron VIDE ⇒ null (chaîne vide = canal « je ne sais pas »)', () {
      const f = ZIntlDateDisplayFormatter(datePattern: '');
      expect(f.format(_sunday, mode: ZDateMode.date, localeTag: 'fr'), isNull);
    });

    test('G8 — mode `time` ⇒ null : l\'impl DÉCLINE ce mode', () {
      const f = ZIntlDateDisplayFormatter();
      expect(f.format(_sunday, mode: ZDateMode.time, localeTag: 'fr'), isNull);
      expect(f.format(_sunday, mode: ZDateMode.time), isNull);
      // ...et le refus ne coûte AUCUN formateur (aucune construction).
      expect(zDebugIntlDateFormatterCreations, 0);
    });

    test(
        'G9 — le repli couvre les DEUX familles : `Error` (locale inconnue) '
        'ET `Exception`. Aucun appel ne lève, quelle que soit l\'entrée.', () {
      const f = ZIntlDateDisplayFormatter();
      for (final mode in ZDateMode.values) {
        for (final tag in <String?>[null, '', 'fr', 'zz', 'C', 'invalid']) {
          expect(
            () => f.format(_sunday, mode: mode, localeTag: tag),
            returnsNormally,
            reason: 'mode=$mode tag=$tag',
          );
        }
      }
    });
  });

  group('G-C — le cache MORD (mesuré par INSTANCE, pas par sortie)', () {
    test(
        'G10 — deux appels identiques ne construisent qu\'UN formateur, et '
        'c\'est la MÊME instance qui sert', () {
      const f = ZIntlDateDisplayFormatter();
      expect(zDebugIntlDateFormatterCreations, 0);

      f.format(_sunday, mode: ZDateMode.date, localeTag: 'fr-FR');
      expect(zDebugIntlDateFormatterCreations, 1);
      expect(zDebugIntlDateFormatterCacheEntries, hasLength(1));
      final first = zDebugIntlDateFormatterCacheEntries.single;

      f.format(_sunday, mode: ZDateMode.date, localeTag: 'fr-FR');
      expect(zDebugIntlDateFormatterCreations, 1,
          reason: 'aucun NOUVEAU DateFormat ne doit être construit');
      expect(zDebugIntlDateFormatterCacheEntries, hasLength(1));
      expect(zDebugIntlDateFormatterCacheEntries.single, same(first),
          reason: 'la MÊME instance doit resservir (identité, pas égalité de '
              'sortie)');
    });

    test(
        'G11 — le cache DISCRIMINE : locale, mode et patron donnent des '
        'instances DISTINCTES', () {
      const f = ZIntlDateDisplayFormatter();
      const other = ZIntlDateDisplayFormatter(datePattern: 'y');

      f.format(_sunday, mode: ZDateMode.date, localeTag: 'fr');
      final frDate = zDebugIntlDateFormatterCacheEntries.single;

      f.format(_sunday, mode: ZDateMode.date, localeTag: 'en');
      f.format(_sunday, mode: ZDateMode.dateTime, localeTag: 'fr');
      other.format(_sunday, mode: ZDateMode.date, localeTag: 'fr');

      expect(zDebugIntlDateFormatterCreations, 4);
      expect(zDebugIntlDateFormatterCacheEntries, hasLength(4));
      // Aucune des trois nouvelles n'est l'instance `fr`/date/défaut.
      final others = zDebugIntlDateFormatterCacheEntries
          .where((e) => !identical(e, frDate))
          .toList();
      expect(others, hasLength(3));
      // ...et toutes les instances mémoïsées sont deux à deux distinctes.
      for (var i = 0; i < zDebugIntlDateFormatterCacheEntries.length; i++) {
        for (var j = i + 1;
            j < zDebugIntlDateFormatterCacheEntries.length;
            j++) {
          expect(
            identical(zDebugIntlDateFormatterCacheEntries[i],
                zDebugIntlDateFormatterCacheEntries[j]),
            isFalse,
          );
        }
      }
    });

    test('G12 — une locale INVALIDE n\'empoisonne pas le cache', () {
      const f = ZIntlDateDisplayFormatter();
      f.format(_sunday, mode: ZDateMode.date, localeTag: 'zz');
      expect(zDebugIntlDateFormatterCacheEntries, isEmpty,
          reason: 'rien ne doit être mémoïsé pour une locale qui lève');
      // ...et une locale valide fonctionne toujours après coup.
      expect(f.format(_sunday, mode: ZDateMode.date, localeTag: 'fr'),
          'dimanche 9 août 2026');
    });

    test('G13 — le cache est BORNÉ (pas de fuite sur patrons dynamiques)', () {
      for (var i = 0; i < 200; i++) {
        ZIntlDateDisplayFormatter(datePattern: "y'#$i'")
            .format(_sunday, mode: ZDateMode.date, localeTag: 'fr');
      }
      expect(zDebugIntlDateFormatterCreations, 200);
      expect(zDebugIntlDateFormatterCacheEntries.length, lessThanOrEqualTo(64));
    });
  });

  group('G-D — contrat, `const` et isolation (AD-1 / AD-2 / FR-26)', () {
    test('G14 — l\'impl SATISFAIT le port du cœur', () {
      const f = ZIntlDateDisplayFormatter();
      expect(f, isA<ZDateDisplayFormatter>());
    });

    test(
        'G15 — `const`-constructible : deux littéraux `const` identiques sont '
        'la MÊME instance (canonicalisation ⇒ injection en `const`, AD-2)', () {
      const a = ZIntlDateDisplayFormatter(datePattern: 'EEE d MMM y');
      const b = ZIntlDateDisplayFormatter(datePattern: 'EEE d MMM y');
      expect(identical(a, b), isTrue);
    });

    test(
        'G16 — FR-26 : AUCUN nom de mois/jour n\'est écrit dans le code du '
        'paquet (hors commentaires) — ce sont des données de locale', () {
      // Noms français ET anglais rendus par les gardes ci-dessus : s'ils
      // apparaissaient dans `lib/`, c'est qu'ils y auraient été RECOPIÉS.
      final labels = <String>[
        'janvier', 'février', 'mars', 'avril', 'juin', 'juillet',
        'août', 'septembre', 'octobre', 'novembre', 'décembre', //
        'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi',
        'dimanche', //
        'January', 'February', 'August', 'December', //
        'Monday', 'Sunday',
      ];
      for (final e in _dartFiles()) {
        final src = _stripComments(e.readAsStringSync());
        for (final label in labels) {
          expect(src.contains(label), isFalse,
              reason: 'libellé de date codé en dur ($label) dans ${e.path} — '
                  'FR-26 : la locale les fournit');
        }
      }
    });

    test(
        'G17 — confinement AD-1 : UN SEUL fichier de `lib/` importe '
        '`package:intl` (patron `phone_numbers_parser`)', () {
      final importers = <String>[];
      for (final e in _dartFiles()) {
        final src = _stripComments(e.readAsStringSync());
        if (RegExp(r'''import\s+['"]package:intl/''').hasMatch(src)) {
          importers.add(e.path);
        }
      }
      expect(importers, hasLength(1), reason: 'trouvé: $importers');
      expect(importers.single.endsWith('z_intl_date_formatter.dart'), isTrue);
    });

    test(
        'G18 — payload : le formateur est servi par un point d\'entrée SÉPARÉ, '
        'le barrel principal ne le tire PAS', () {
      final barrel = _read('packages/zcrud_intl/lib/zcrud_intl.dart');
      expect(barrel.contains('z_intl_date_formatter'), isFalse,
          reason: 'le barrel principal ne doit pas rendre atteignable la table '
              'CLDR complète pour les hôtes qui ne veulent que '
              'téléphone/pays/adresse');
      final entry = _read('packages/zcrud_intl/lib/date_formatter.dart');
      expect(entry.contains('z_intl_date_formatter'), isTrue);
    });

    test('G19 — `intl` est bien DÉCLARÉ au pubspec de `zcrud_intl`', () {
      final pubspec = _read('packages/zcrud_intl/pubspec.yaml');
      expect(RegExp(r'^\s+intl:', multiLine: true).hasMatch(pubspec), isTrue);
      // ...et TOUJOURS PAS à celui du cœur (AD-1).
      final core = _read('packages/zcrud_core/pubspec.yaml');
      expect(RegExp(r'^\s+intl:', multiLine: true).hasMatch(core), isFalse);
    });
  });
}
