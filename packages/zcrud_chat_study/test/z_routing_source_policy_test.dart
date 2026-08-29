@TestOn('vm')
/// 🔴 Gardes de SOURCE des adaptateurs de route (`lib/src/domain/routing/`).
///
/// Trois propriétés qu'aucun test de comportement ne peut atteindre :
///
/// 1. **AD-1** — le domaine d'étude n'acquiert AUCUNE arête vers le domaine
///    du chat : c'est la raison d'être de ce paquet-pont, et c'est mesuré sur
///    le `pubspec.yaml` RÉEL de `zcrud_study`, pas supposé ;
/// 2. **frontière de couche** — le domaine de ce paquet n'importe rien de la
///    `presentation/` de `zcrud_chat` (ni le paquet lui-même) ;
/// 3. **pureté** — les adaptateurs ne portent ni transport (URL, endpoint,
///    client HTTP), ni vocabulaire de tâche en dur (une constante de clé de
///    tâche imposerait aux hôtes le vocabulaire du socle).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _repoRoot() {
  Directory dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('melos.yaml introuvable depuis ${Directory.current.path}');
    }
    dir = parent;
  }
}

void main() {
  final Directory root = _repoRoot();
  final Directory routing = Directory(
    '${root.path}/packages/zcrud_chat_study/lib/src/domain/routing',
  );
  final List<File> routingFiles = routing
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  test('contrôle positif — la garde lit bien les sources de routing', () {
    // Sans ce contrôle, un dossier renommé rendrait toutes les assertions
    // suivantes vraies par vacuité.
    expect(routingFiles, hasLength(8));
    for (final File f in routingFiles) {
      expect(f.readAsStringSync().length, greaterThan(500), reason: f.path);
    }
  });

  test('AD-1 — zcrud_study n\'acquiert AUCUNE arête vers le domaine du chat',
      () {
    final File pubspec =
        File('${root.path}/packages/zcrud_study/pubspec.yaml');
    expect(pubspec.existsSync(), isTrue, reason: pubspec.path);
    final List<String> declared = <String>[
      for (final String raw in pubspec.readAsLinesSync())
        if (RegExp(r'^\s{2}zcrud_\w+\s*:').hasMatch(raw.split('#').first))
          raw.split('#').first.trim(),
    ];
    // Contrôle positif : la lecture voit bien des arêtes réelles.
    expect(declared, isNotEmpty);
    // Contrôle DISCRIMINANT : le même extracteur, appliqué au pubspec de CE
    // paquet, VOIT une arête chat. La garde ci-dessous est donc capable de
    // mordre — son vert n'est pas l'aveuglement de l'extracteur.
    final List<String> own = <String>[
      for (final String raw
          in File('${root.path}/packages/zcrud_chat_study/pubspec.yaml')
              .readAsLinesSync())
        if (RegExp(r'^\s{2}zcrud_\w+\s*:').hasMatch(raw.split('#').first))
          raw.split('#').first.trim(),
    ];
    expect(
      own.where((String d) => d.startsWith('zcrud_chat')),
      isNotEmpty,
      reason: 'extracteur aveugle aux arêtes chat',
    );
    expect(
      declared.where((String d) => d.startsWith('zcrud_chat')),
      isEmpty,
      reason: 'arête chat déclarée par zcrud_study : $declared',
    );
  });

  test('le domaine de ce paquet n\'importe RIEN de zcrud_chat', () {
    // `zcrud_chat` est la couche PRÉSENTATION du chat. Ce paquet ne doit
    // connaître que le KERNEL (`zcrud_chat_kernel`) : importer la
    // présentation ferait entrer des widgets dans un domaine pur, et
    // ajouterait au pont un poids qu'aucun hôte d'étude n'a demandé.
    final Directory lib =
        Directory('${root.path}/packages/zcrud_chat_study/lib');
    final List<File> all = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(all, isNotEmpty);
    final RegExp forbidden = RegExp(r'''package:zcrud_chat/''');
    for (final File f in all) {
      expect(
        forbidden.hasMatch(f.readAsStringSync()),
        isFalse,
        reason: 'import de zcrud_chat dans ${f.path}',
      );
    }
  });

  test('pureté — aucun transport dans les adaptateurs de route', () {
    // Une route est une DONNÉE, jamais une URL : si un endpoint apparaît ici,
    // le contrat neutre a cessé de l'être (invariant AD-12).
    final Map<String, RegExp> forbidden = <String, RegExp>{
      'une URL': RegExp(r'https?://'),
      'un client HTTP': RegExp(r'''package:(http|dio)/'''),
      'dart:io': RegExp(r'''dart:io'''),
      'un widget Flutter': RegExp(r'''package:flutter/'''),
    };
    for (final File f in routingFiles) {
      final String src = f.readAsStringSync();
      for (final MapEntry<String, RegExp> e in forbidden.entries) {
        expect(
          e.value.hasMatch(src),
          isFalse,
          reason: '${e.key} dans ${f.path}',
        );
      }
    }
  });

  test('AUCUNE constante de clé de tâche n\'est publiée par le socle', () {
    // Un défaut de clé de tâche deviendrait le vocabulaire imposé aux hôtes :
    // le paramètre `taskKey` est REQUIS partout, et aucune constante de
    // premier niveau ne nomme une tâche.
    final RegExp taskConst = RegExp(
      r'''^const\s+String\s+k\w*Task\w*\s*=''',
      multiLine: true,
    );
    for (final File f in routingFiles) {
      expect(taskConst.hasMatch(f.readAsStringSync()), isFalse,
          reason: f.path);
    }
    // Contrepartie POSITIVE : chaque adaptateur exige bien `required this.taskKey`.
    final List<File> adapters = routingFiles
        .where((File f) => f.path.contains('z_chat_routed_'))
        .toList();
    expect(adapters, hasLength(6));
    for (final File f in adapters) {
      expect(
        f.readAsStringSync().contains('required this.taskKey'),
        isTrue,
        reason: f.path,
      );
    }
  });
}
