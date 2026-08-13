// Garde GÉNÉRIQUE : toute clé de libellé consommée par `label(context, '…')`
// doit exister dans les DEUX tables du delegate (`_enLabels` ET `_frLabels`).
//
// 🔴 MOTIF (2026-08-13) — cette garde naît d'un défaut réel, pas d'une
// précaution. `zcrud_screen` consommait `label(context, 'trash')` alors que la
// clé `'trash'` était absente des deux tables : le repli `fallback:` masquait
// le trou, l'écran affichait « Trash » en français comme en anglais, et rien ne
// rougissait. Le même trou existait sur `'back'`, `'selectDateRange'` et les
// trois clés du stepper (`z.stepper.previous/next/finish`) — six libellés que
// la traduction française n'atteignait jamais.
//
// Une clé absente ne lève JAMAIS : `label()` retombe sur la table `en`, puis
// sur `fallback`, puis sur la clé brute. Le défaut est donc structurellement
// invisible à un test de rendu qui se contenterait de vérifier « un texte est
// affiché ». Seule une garde de SOURCE le voit.
//
// 🔴 Les tables sont LUES DANS LA SOURCE, jamais recopiées ici : une liste
// recopiée dériverait avec le fichier qu'elle prétend garder, et la garde
// deviendrait verte pour la mauvaise raison.
//
// Ancrage : remontée jusqu'au dossier portant `melos.yaml` — jamais un `../`
// relatif (`flutter test` se lance depuis le dossier du paquet).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/z_sources.dart' as sources;

/// Paquets balayés : tout `lib/` où le patron `label(context, '…')` s'applique.
const List<String> _scannedPackages = <String>['zcrud_core', 'zcrud_screen'];

/// Fichiers `.dart` de `lib/` d'un paquet du dépôt (hors code généré).
List<File> _libFilesOf(String package) {
  final Directory lib =
      Directory('${sources.repoRoot().path}/packages/$package/lib');
  expect(lib.existsSync(), isTrue, reason: 'lib/ introuvable pour $package');
  final List<File> files = lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) =>
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'))
      .toList();
  expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
  return files;
}

/// Clés littérales passées à `label(context, '…')`, avec leur provenance.
///
/// Les appels à clé **dynamique** (`label(context, widget.title)`) sont
/// ignorés : la clé n'est pas connue à la lecture de la source, et c'est
/// l'appelant qui garantit alors sa propre couverture.
Map<String, Set<String>> _usedKeys() {
  final RegExp pattern =
      RegExp(r"""label\(\s*context\s*,\s*'([A-Za-z0-9_.]+)'""");
  final Map<String, Set<String>> used = <String, Set<String>>{};
  for (final String package in _scannedPackages) {
    for (final File file in _libFilesOf(package)) {
      final String source = sources.strippedSource(file);
      for (final RegExpMatch m in pattern.allMatches(source)) {
        used
            .putIfAbsent(m.group(1)!, () => <String>{})
            .add(file.path.replaceAll(r'\', '/').split('/lib/').last);
      }
    }
  }
  return used;
}

/// Clés déclarées dans une table `const <name> = <String, String>{ … };` de la
/// source du delegate.
Set<String> _tableKeys(String source, String name) {
  final int start = source.indexOf('const $name = <String, String>{');
  expect(start, isNot(-1), reason: 'table $name introuvable dans la source');
  final int end = source.indexOf('\n};', start);
  expect(end, isNot(-1), reason: 'fin de la table $name introuvable');
  final Set<String> keys = RegExp(r"""^\s*'([^']+)'\s*:""", multiLine: true)
      .allMatches(source.substring(start, end))
      .map((RegExpMatch m) => m.group(1)!)
      .toSet();
  expect(keys, isNotEmpty, reason: 'table $name vide : garde VACUELLE');
  return keys;
}

void main() {
  late Set<String> en;
  late Set<String> fr;
  late Map<String, Set<String>> used;

  setUpAll(() {
    final File delegate = File(
      '${sources.repoRoot().path}/packages/zcrud_core/lib/src/presentation/'
      'l10n/z_localizations.dart',
    );
    expect(delegate.existsSync(), isTrue, reason: 'delegate introuvable');
    final String source = sources.strippedSource(delegate);
    en = _tableKeys(source, '_enLabels');
    fr = _tableKeys(source, '_frLabels');
    used = _usedKeys();
  });

  test('🔴 chaque clé consommée par `label(context, …)` existe dans _enLabels',
      () {
    final List<String> missing = <String>[
      for (final MapEntry<String, Set<String>> e in used.entries)
        if (!en.contains(e.key)) '${e.key} (${e.value.join(', ')})',
    ]..sort();
    expect(
      missing,
      isEmpty,
      reason: 'clés consommées mais absentes de _enLabels — le repli silencieux '
          'de `label()` rendrait la clé brute ou le `fallback:` codé en dur',
    );
  });

  test('🔴 chaque clé consommée par `label(context, …)` existe dans _frLabels',
      () {
    final List<String> missing = <String>[
      for (final MapEntry<String, Set<String>> e in used.entries)
        if (!fr.contains(e.key)) '${e.key} (${e.value.join(', ')})',
    ]..sort();
    expect(
      missing,
      isEmpty,
      reason: 'clés consommées mais absentes de _frLabels — un utilisateur '
          'francophone verrait le libellé ANGLAIS sans aucun signal',
    );
  });

  test('🔴 les deux tables couvrent exactement les mêmes clés', () {
    expect(en.difference(fr), isEmpty, reason: 'clés présentes en `en` seul');
    expect(fr.difference(en), isEmpty, reason: 'clés présentes en `fr` seul');
  });

  test('🔴 anti-vacuité : le balayage trouve bien des clés consommées', () {
    expect(used.length, greaterThan(30),
        reason: 'balayage quasi vide : le motif ou le chemin est cassé');
  });
}
