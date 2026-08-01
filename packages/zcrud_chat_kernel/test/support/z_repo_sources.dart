// Squelette PARTAGÉ des gardes qui LISENT LES SOURCES du dépôt.
//
// 🔴 Extrait de `test/z_chat_naming_guard_test.dart` (CHAT-0) par CHAT-0b :
// la garde **G-U1** (« un verbe = un seul site d'appel ») a besoin exactement
// des mêmes primitives (`_repoRoot`, `_stripComment`, balayage de
// `packages/*/lib`). Les RECOPIER aurait créé deux définitions divergentes de
// « source du dépôt » — la classe de défaut que zcrud combat partout ailleurs
// (DW-ES22-4). Ce fichier est donc la source UNIQUE, et `z_chat_naming_guard_test.dart`
// comme `z_chat_action_contract_guard_test.dart` l'importent.
//
// ⚠️ `dart:io` : tout `*_test.dart` qui importe ce fichier DOIT porter
// `@TestOn('vm')` + `library;` — sinon le gate `web-determinism`
// (`dart test -p node` sur chaque package pur-Dart) rend TOUTE la suite du
// package non compilable en JS. Ce fichier n'est PAS un `*_test.dart` : le
// runner ne l'exécute jamais seul, il ne porte donc pas l'annotation.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Racine du dépôt, quel que soit le CWD (racine du workspace ou package).
Directory repoRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}');
}

/// Tous les `.dart` **sources** de `packages/*/lib` (hors code généré).
List<File> packageLibDartFiles() {
  final Directory packages = Directory('${repoRoot().path}/packages');
  expect(packages.existsSync(), isTrue, reason: 'packages/ introuvable');
  return packages
      .listSync()
      .whereType<Directory>()
      .map((Directory d) => Directory('${d.path}/lib'))
      .where((Directory d) => d.existsSync())
      .expand((Directory d) => d.listSync(recursive: true, followLinks: false))
      .whereType<File>()
      .where((File f) =>
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'))
      .toList();
}

/// Les `.dart` du kernel de chat — **tout `lib/`**, barrel compris.
///
/// 🔴 **Périmètre ÉLARGI en fin d'epic (MEDIUM).** Ce scanner ne lisait que
/// `lib/src/domain/`. Toutes les gardes qui s'appuient dessus — nommage,
/// absence de codegen, absence de dépendance interdite — étaient donc
/// **aveugles à `lib/zcrud_chat_kernel.dart`** (le barrel, où passent tous les
/// `export`) et à n'importe quel dossier ajouté à côté de `domain/` : un
/// `lib/src/data/` créé demain n'aurait été scanné par personne, et la garde
/// serait restée verte. Le périmètre est désormais **tout `lib/`**, avec une
/// borne basse de non-vacuité qui rougit si le paquet est vidé ou déplacé.
List<File> chatDartFiles() {
  final Directory dir = Directory(
    '${repoRoot().path}/packages/zcrud_chat_kernel/lib',
  );
  expect(dir.existsSync(), isTrue,
      reason: 'zcrud_chat_kernel/lib/ introuvable — la garde serait VACUELLE');
  final List<File> files = dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
  expect(files.length, greaterThanOrEqualTo(20),
      reason: '🔴 GARDE VACUELLE : ${files.length} fichier(s) scanné(s) dans '
          'zcrud_chat_kernel/lib. Le kernel en porte plusieurs dizaines ; un '
          'balayage quasi vide signale un chemin cassé, pas un paquet propre.');
  // Volet ANTI-RÉGRESSION du périmètre : le barrel DOIT être vu.
  expect(
    files.map((File f) => f.uri.pathSegments.last),
    contains('zcrud_chat_kernel.dart'),
    reason: '🔴 le barrel n\'est pas scanné : c\'est exactement le trou que '
        'l\'élargissement de fin d\'epic a fermé.',
  );
  return files;
}

/// Le dossier du contrat d'action (CHAT-0b).
Directory actionDir() => Directory(
      '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/action',
    );

/// Un fichier du contrat d'action, par nom.
File actionFile(String name) => File('${actionDir().path}/$name');

/// Retire la partie commentaire d'une ligne (le grep vise le CODE, pas la
/// prose : les dartdoc citent légitimement les symboles interdits pour
/// documenter qu'ils le sont).
String stripComment(String line) {
  final int i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

/// Retire les commentaires (de LIGNE **et** de BLOC) d'une SOURCE entière, en
/// préservant le nombre de lignes (pour que les numéros signalés par une garde
/// restent exacts).
///
/// 🔴 L'ordre compte : le commentaire de LIGNE est reconnu AVANT `/*`. Une
/// dartdoc de ce dépôt écrit littéralement `packages/*/lib`
/// (`z_chat_action_executor.dart:13`) — une passe « bloc d'abord » y verrait
/// l'ouverture d'un commentaire jamais refermé et AVALERAIT LA FIN DU FICHIER,
/// rendant toute garde en aval silencieusement VACUELLE. Les littéraux de
/// chaîne sont sautés pour la même raison (une URL contient `//`).
List<String> strippedLines(File f) {
  final List<String> out = <String>[];
  bool inBlock = false;
  for (final String raw in f.readAsLinesSync()) {
    final StringBuffer buf = StringBuffer();
    int i = 0;
    while (i < raw.length) {
      final String c = raw[i];
      final String next = i + 1 < raw.length ? raw[i + 1] : '';
      if (inBlock) {
        if (c == '*' && next == '/') {
          inBlock = false;
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      if (c == '/' && next == '/') break;
      if (c == '/' && next == '*') {
        inBlock = true;
        i += 2;
        continue;
      }
      if (c == "'" || c == '"') {
        final String quote = c;
        buf.write(c);
        i++;
        while (i < raw.length) {
          if (raw[i] == r'\') {
            buf.write(raw[i]);
            i++;
            if (i < raw.length) {
              buf.write(raw[i]);
              i++;
            }
            continue;
          }
          buf.write(raw[i]);
          final bool end = raw[i] == quote;
          i++;
          if (end) break;
        }
        continue;
      }
      buf.write(c);
      i++;
    }
    out.add(buf.toString());
  }
  return out;
}
