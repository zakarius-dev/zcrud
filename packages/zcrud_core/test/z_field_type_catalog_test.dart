/// Gardes du **catalogue des types de champ** (CR d'exploration DODLP §7).
///
/// Le livrable est un document `docs/zcrud-field-type-catalog.md` **dérivé du
/// code**. Ce fichier est ce qui le rend *incapable de mentir* :
///
/// * **P1 — exhaustivité** : tenue à la **COMPILATION** par le `switch` sans
///   `default` de `entryFor` (`test/support/z_field_type_catalog.dart`).
///   [_testCouverture] n'est qu'un filet redondant, pas la garde principale.
/// * **P2 — synchronisation** : [_testSynchronisation] lit le fichier **tel
///   qu'il est sur disque** et le compare octet à octet au rendu. Elle ne
///   régénère jamais avant de comparer, et ne compare jamais le fichier à
///   lui-même : un caractère édité dans `docs/` la fait rougir.
/// * **P3 — statut mesuré** : [_testCoherenceStatut] interdit qu'une entrée
///   annonce un satellite ou un chemin alternatif incompatible avec la famille
///   que le dispatcher associe réellement au type. Les autres gardes vérifient
///   que chaque chemin, chaque paquet et chaque config **existent sur disque**.
///
/// 🔴 Ancrage par remontée jusqu'à `melos.yaml` — jamais un `../` relatif : la
/// convention `melos exec` lance chaque suite depuis le dossier de SON package.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_field_type_catalog.dart';
import 'support/z_sources.dart' as zsrc;

/// Racine du dépôt, quel que soit le CWD (racine du workspace ou package).
Directory _repoRoot() => zsrc.repoRoot();

/// Concaténation des sources `lib/` d'un paquet du monorepo (lecture seule),
/// **STRIPPÉES de leurs commentaires** (`support/z_sources.dart`).
///
/// 🔴 Les vérifications de ce fichier sont des contrôles de PRÉSENCE
/// (`contains('class $c ')`, `contains('.register(')`…) : sans dépouillement,
/// une dartdoc citant le motif suffirait à les satisfaire alors même que le
/// CODE l'aurait perdu — la garde serait AVEUGLÉE par la prose, pas déviée.
String _libSources(String package) {
  final Directory lib = Directory('${_repoRoot().path}/packages/$package/lib');
  if (!lib.existsSync()) return '';
  final StringBuffer b = StringBuffer();
  for (final FileSystemEntity e in lib.listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) {
      b.writeln(zsrc.strippedSource(e));
    }
  }
  return b.toString();
}

void main() {
  group('Catalogue des types de champ — docs/zcrud-field-type-catalog.md', () {
    _testCouverture();
    _testCoherenceStatut();
    _testChemins();
    _testSatellites();
    _testConfigs();
    _testSeams();
    _testSynchronisation();
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// P1 (filet redondant — la vraie garde est la compilation de `entryFor`)
// ─────────────────────────────────────────────────────────────────────────────
void _testCouverture() {
  test('couvre chaque EditionFieldType exactement une fois', () {
    expect(kZFieldTypeCatalog.length, EditionFieldType.values.length);
    expect(
      kZFieldTypeCatalog.map((ZFieldTypeEntry e) => e.type).toSet(),
      EditionFieldType.values.toSet(),
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// P3 — un statut ne peut pas contredire le dispatcher
// ─────────────────────────────────────────────────────────────────────────────
void _testCoherenceStatut() {
  test('aucune entrée n\'annonce plus que ce que le dispatcher route', () {
    for (final ZFieldTypeEntry e in kZFieldTypeCatalog) {
      final EditionFamily f = familyOf(e.type);

      // Un satellite ne se déclare que là où le dispatcher passe VRAIMENT par
      // le registre. Sinon l'hôte ajouterait une dépendance pour rien.
      if (e.satellite != null) {
        expect(
          f,
          anyOf(EditionFamily.registryOrFallback, EditionFamily.freeWidget),
          reason: '`${e.type.name}` annonce le satellite `${e.satellite}` '
              'alors que le dispatcher le route en `${f.name}`.',
        );
      }

      // Un chemin alternatif ne se déclare que là où il n'y a PAS de
      // widget-feuille — c'est le cas `stepper`, et il doit le rester.
      if (e.alternates.isNotEmpty) {
        expect(
          f,
          EditionFamily.unsupported,
          reason: '`${e.type.name}` annonce un chemin alternatif alors que le '
              'dispatcher lui donne déjà un widget (`${f.name}`).',
        );
      }

      // Le `kind` de registre est la convention réelle du dispatcher.
      if (e.registryKind != null) {
        expect(e.registryKind, e.type.name);
      }

      // Le statut « cœur » n'est atteignable que hors repli.
      if (e.support == ZFieldTypeSupport.core) {
        expect(
          f,
          isNot(anyOf(
            EditionFamily.unsupported,
            EditionFamily.registryOrFallback,
            EditionFamily.freeWidget,
            EditionFamily.hidden,
          )),
          reason: '`${e.type.name}` sort en statut « cœur » alors que le '
              'dispatcher le route en `${f.name}`.',
        );
      }
    }
  });

  test('stepper reste servi par un chemin alternatif du cœur', () {
    final ZFieldTypeEntry e = entryFor(EditionFieldType.stepper);
    expect(familyOf(EditionFieldType.stepper), EditionFamily.unsupported,
        reason: 'invariant DP-9/AC13 : un stepper est un regroupement, pas un '
            'widget-feuille.');
    expect(e.support, ZFieldTypeSupport.coreAlternatePath,
        reason: 'le catalogue ne doit JAMAIS faire fuir un hôte d\'une '
            'fonctionnalité qui existe.');
    expect(e.alternates, isNotEmpty);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Le défaut historique — un document citant un fichier inexistant
// ─────────────────────────────────────────────────────────────────────────────
void _testChemins() {
  test('chaque chemin cité existe sur disque', () {
    final String root = _repoRoot().path;
    for (final ZFieldTypeEntry e in kZFieldTypeCatalog) {
      for (final String p in <String>[
        if (e.source != null) e.source!,
        ...e.alternates,
      ]) {
        expect(File('$root/$p').existsSync(), isTrue,
            reason: '`${e.type.name}` cite `$p`, absent du dépôt.');
      }
    }
  });
}

void _testSatellites() {
  test('chaque satellite existe et sert le kind annoncé', () {
    final String root = _repoRoot().path;
    for (final ZFieldTypeEntry e in kZFieldTypeCatalog) {
      final String? sat = e.satellite;
      if (sat == null) continue;

      expect(Directory('$root/packages/$sat').existsSync(), isTrue,
          reason: '`${e.type.name}` cite le paquet `$sat`, absent du dépôt.');

      final String sources = _libSources(sat);
      // Condition NÉCESSAIRE, mesurée sur le CODE STRIPPÉ. Deux câblages réels
      // existent dans le monorepo :
      // (a) le satellite se câble LUI-MÊME : il mentionne le `kind` (littéral
      //     `register('markdown', …)` ou constante `EditionFieldType.pin.name`)
      //     ET appelle `.register(` ;
      // (b) le satellite fournit une fabrique compatible registre et c'est
      //     L'HÔTE qui enregistre : son fichier `source` cité expose
      //     `static ZFieldWidgetBuilder builder(` — cas MESURÉ de `zcrud_geo`,
      //     dont le kind `'location'` et `.register(` ne vivent QUE dans la
      //     dartdoc (l'ancienne version de cette garde, non strippée, était
      //     satisfaite par cette prose seule).
      final bool selfWired = (sources.contains("'${e.type.name}'") ||
              sources.contains('EditionFieldType.${e.type.name}')) &&
          sources.contains('.register(');
      final bool hostWired = e.source != null &&
          zsrc
              .strippedSource(File('$root/${e.source}'))
              .contains('static ZFieldWidgetBuilder builder(');
      expect(
        selfWired || hostWired,
        isTrue,
        reason: '`$sat` ne mentionne le kind `${e.type.name}` dans AUCUN code '
            '(ni auto-enregistrement au `ZWidgetRegistry`, ni fabrique '
            '`static ZFieldWidgetBuilder builder(` que l\'hôte pourrait '
            'enregistrer) : le catalogue enverrait l\'hôte ajouter une '
            'dépendance qui ne sert pas ce type.',
      );

      if (e.registrar != null) {
        expect(sources.contains('${e.registrar}('), isTrue,
            reason: '`$sat` n\'expose pas `${e.registrar}`.');
      }
    }
  });

  test('icon et custom ne sont servis par AUCUN paquet du monorepo', () {
    // Grep négatif MONTRÉ : le seul fichier du monorepo qui mentionne
    // `EditionFieldType.icon` est la classification du cœur elle-même.
    for (final EditionFieldType t
        in <EditionFieldType>[EditionFieldType.icon, EditionFieldType.custom]) {
      expect(entryFor(t).satellite, isNull);
      expect(entryFor(t).support, ZFieldTypeSupport.hostRegistry,
          reason: 'le catalogue doit dire à l\'hôte qu\'il doit fournir '
              'lui-même le builder de `${t.name}`.');
    }
  });
}

void _testConfigs() {
  test('chaque classe de config citée est VIVANTE dans lib/', () {
    final String sources = _libSources('zcrud_core');
    for (final ZFieldTypeEntry e in kZFieldTypeCatalog) {
      final Type? c = e.config;
      if (c == null) continue;
      expect(sources.contains('class $c '), isTrue,
          reason: '`$c` (cité par `${e.type.name}`) n\'est pas déclarée.');
      expect(sources.contains('is $c'), isTrue,
          reason: '`$c` (cité par `${e.type.name}`) n\'est consultée nulle '
              'part : une config décorative n\'a rien à faire au catalogue.');
    }
  });

  test('dateRange n\'a PAS de config — mesuré, pas supposé', () {
    // Le dispatcher (`z_field_widget.dart`, branche `EditionFamily.dateRange`)
    // ne lit aucune config : pas de bornes `firstDate`/`lastDate` comme pour
    // `date`. Si cela change, cette garde rougit et le document doit suivre.
    expect(entryFor(EditionFieldType.dateRange).config, isNull);
    expect(entryFor(EditionFieldType.dateTime).config, ZDateConfig);
  });
}

void _testSeams() {
  test('chaque seam cité est un vrai point d\'injection de ZcrudScope', () {
    final String sources = _libSources('zcrud_core');
    // STRIPPÉ : une dartdoc citant `final ZDateDisplayFormatter? …` ne doit
    // pas pouvoir satisfaire (ni un jour dévier) le contrôle de présence.
    final String scope = zsrc.strippedSource(
      File('${_repoRoot().path}/packages/zcrud_core/lib/src/'
          'presentation/zcrud_scope.dart'),
    );
    for (final ZFieldTypeEntry e in kZFieldTypeCatalog) {
      for (final String s in e.seams) {
        expect(
          sources.contains('class $s ') || sources.contains('typedef $s '),
          isTrue,
          reason: '`$s` (cité par `${e.type.name}`) n\'est déclaré nulle part '
              'dans zcrud_core.',
        );
        expect(scope.contains('final $s? ') || scope.contains('final $s '),
            isTrue,
            reason: '`$s` (cité par `${e.type.name}`) n\'est pas un champ de '
                '`ZcrudScope` : le catalogue enverrait l\'hôte injecter une '
                'dépendance sur un seam qui n\'existe pas.');
      }
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// P2 — synchronisation prouvée
// ─────────────────────────────────────────────────────────────────────────────
void _testSynchronisation() {
  test('le document publié est identique au rendu du code', () {
    final String root = _repoRoot().path;
    final File doc = File('$root/$kZFieldTypeCatalogDocPath');

    expect(doc.existsSync(), isTrue,
        reason: '$kZFieldTypeCatalogDocPath est absent du dépôt.');

    // 🔴 Lecture du fichier TEL QU'IL EST : aucune régénération préalable.
    final String surDisque = doc.readAsStringSync();
    final String attendu = renderZFieldTypeCatalogMarkdown();

    if (surDisque != attendu) {
      final File dump = File('${Directory.systemTemp.path}/'
          'zcrud-field-type-catalog.attendu.md')
        ..writeAsStringSync(attendu);
      fail('$kZFieldTypeCatalogDocPath a divergé du code. '
          'Contenu attendu écrit dans ${dump.path} — '
          'copiez-le sur $kZFieldTypeCatalogDocPath.');
    }
  });
}
