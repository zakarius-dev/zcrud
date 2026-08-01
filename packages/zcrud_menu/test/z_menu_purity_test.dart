/// Gardes de **PURETÉ** de `zcrud_menu` :
/// * AD-57 — AUCUNE dépendance TIERCE (grep NÉGATIF prouvé) ;
/// * AD-2/AD-15 — AUCUN gestionnaire d'état ;
/// * AD-1 — arête sortante UNIQUE vers `zcrud_core`, CORE OUT = 0 préservé ;
/// * FR-26/NFR-S7 — aucune couleur ni chaîne d'interface codées en dur.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_menu/zcrud_menu.dart';

import 'menu_test_support.dart';

/// Dépendances AUTORISÉES — toute autre entrée fait rougir.
const Set<String> _depsAutorisees = <String>{'flutter', 'zcrud_core'};
const Set<String> _devDepsAutorisees = <String>{'flutter_test'};

/// Préfixes de `package:` autorisés dans `lib/`.
const Set<String> _importsAutorises = <String>{
  'package:flutter/',
  'package:zcrud_core/',
  'package:zcrud_menu/',
};

/// Gestionnaires d'état PROSCRITS dans tout le socle (AD-2/AD-15).
const List<String> _managers = <String>[
  'flutter_riverpod',
  'riverpod',
  'package:get/',
  'package:provider/',
  'get_it',
  'WidgetRef',
  'Get.find',
  'Get.put',
  'Provider.of',
];

List<String> _blocDeps(List<String> lignes, String cle) {
  final noms = <String>[];
  var dans = false;
  for (final ligne in lignes) {
    if (ligne.startsWith('$cle:')) {
      dans = true;
      continue;
    }
    if (dans) {
      if (ligne.isNotEmpty && !ligne.startsWith(' ') && !ligne.startsWith('#')) {
        break;
      }
      final m = RegExp(r'^  ([a-z_0-9]+):').firstMatch(ligne);
      if (m != null) noms.add(m.group(1)!);
    }
  }
  return noms;
}

void main() {
  group('AD-57 — aucune dépendance tierce', () {
    final lignes = File('${repoRoot().path}/packages/zcrud_menu/pubspec.yaml')
        .readAsLinesSync();

    test('contrôle positif : le pubspec est bien lu', () {
      expect(
        lignes.any((l) => l.startsWith('name: zcrud_menu')),
        isTrue,
        reason: 'pubspec de zcrud_menu introuvable ou illisible — la garde se '
            'serait déclarée verte sans rien vérifier',
      );
    });

    test('`dependencies` ⊆ {flutter, zcrud_core}', () {
      final deps = _blocDeps(lignes, 'dependencies').toSet();
      expect(deps, isNotEmpty, reason: 'bloc dependencies non détecté');
      expect(deps.difference(_depsAutorisees), isEmpty);
    });

    test('`dev_dependencies` ⊆ {flutter_test}', () {
      final deps = _blocDeps(lignes, 'dev_dependencies').toSet();
      expect(deps, isNotEmpty, reason: 'bloc dev_dependencies non détecté');
      expect(deps.difference(_devDepsAutorisees), isEmpty);
    });

    test('aucun `import package:` hors flutter/zcrud_core/zcrud_menu', () {
      final fautes = <String>[];
      for (final entry in libCode('zcrud_menu').entries) {
        for (final m in RegExp("import '(package:[^']+)'")
            .allMatches(entry.value)) {
          final uri = m.group(1)!;
          if (!_importsAutorises.any(uri.startsWith)) {
            fautes.add('${entry.key} : $uri');
          }
        }
      }
      expect(fautes, isEmpty, reason: fautes.join('\n'));
    });
  });

  test('AD-2/AD-15 — aucun gestionnaire d\'état dans lib/', () {
    final fautes = <String>[];
    for (final entry in libCode('zcrud_menu').entries) {
      for (final manager in _managers) {
        if (entry.value.contains(manager)) fautes.add('${entry.key} : $manager');
      }
    }
    expect(fautes, isEmpty, reason: fautes.join('\n'));
  });

  test('AD-1 — CORE OUT = 0 : zcrud_core ne dépend PAS de zcrud_menu', () {
    final pubspec =
        File('${repoRoot().path}/packages/zcrud_core/pubspec.yaml');
    expect(pubspec.existsSync(), isTrue, reason: 'contrôle positif');
    expect(pubspec.readAsStringSync().contains('zcrud_menu'), isFalse);
  });

  group('FR-26/NFR-S7 — rien de codé en dur', () {
    test('aucune couleur littérale dans lib/', () {
      const interdits = <String>[
        'Color(0x',
        'Color.fromARGB',
        'Color.fromRGBO',
        'Colors.',
      ];
      final fautes = <String>[];
      for (final entry in libCode('zcrud_menu').entries) {
        for (final motif in interdits) {
          if (entry.value.contains(motif)) fautes.add('${entry.key} : $motif');
        }
      }
      expect(fautes, isEmpty, reason: fautes.join('\n'));
    });

    testWidgets('aucune chaîne d\'interface qui ne vienne de l\'appelant',
        (tester) async {
      // Toutes les chaînes injectées portent un préfixe sentinelle. Tout texte
      // rendu qui n'en porte pas est une chaîne fabriquée par le socle.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ZActionMenu(
                trigger: const ZMenuTrigger(
                  icon: Icons.circle,
                  semanticLabel: 'SENTINELLE-TRIG',
                ),
                entries: [
                  ZMenuEntry(
                    id: ZMenuEntryIds.open,
                    label: 'SENTINELLE-A',
                    onSelected: () {},
                  ),
                  const ZMenuEntry(
                    id: ZMenuEntryIds.edit,
                    label: 'SENTINELLE-B',
                    disabledReason: 'SENTINELLE-MOTIF',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.circle));
      await tester.pumpAndSettle();

      final textes = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(textes, isNotEmpty, reason: 'contrôle positif : rien rendu');
      expect(
        textes.where((t) => !t.startsWith('SENTINELLE-')),
        isEmpty,
        reason: 'chaîne d\'interface CODÉE EN DUR rendue par le socle : '
            '${textes.where((t) => !t.startsWith('SENTINELLE-'))}',
      );
    });
  });
}
