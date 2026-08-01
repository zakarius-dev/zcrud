// AD-57 — Syncfusion **chat** vit ICI et NULLE PART AILLEURS.
//
// 🔴 ÉNONCÉ EXACT DE L'INVARIANT, ET POURQUOI IL EST BORNÉ
// Le dépôt porte DÉJÀ trois arêtes Syncfusion légitimes et antérieures :
// `syncfusion_flutter_datagrid` (zcrud_list), `syncfusion_flutter_xlsio` et
// `syncfusion_flutter_pdf` (zcrud_export / zcrud_export_pdf). Écrire « aucun
// Syncfusion nulle part » serait FAUX au premier `grep`, et une garde fausse se
// désactive. L'invariant que CE lot introduit est donc précis :
//
//   (I1) `syncfusion_flutter_chat` — et tout symbole de sa surface publique
//        (`SfAIAssistView`, `Assist*`, `assist_view.dart`) — n'apparaît QUE
//        dans `packages/zcrud_chat_syncfusion/lib`.
//   (I2) les trois paquets du SOCLE du chat (`zcrud_chat`, `zcrud_chat_kernel`)
//        et le CŒUR (`zcrud_core`) ne contiennent AUCUN `syncfusion`, de
//        quelque famille que ce soit.
//
// 🔴 CONTRÔLE POSITIF — le point qui distingue une garde d'un décor
// Un scanner de sources peut être vert parce qu'il ne regarde RIEN (mauvais
// chemin, glob vide, extension filtrée). Le scanner est donc écrit comme une
// FONCTION PURE sur `chemin -> source`, ce qui permet de le faire ROUGIR sur un
// témoin synthétique, dans le même run, sans écrire un octet sur disque et sans
// jamais injecter de violation dans le dépôt réel. La garde prouve ainsi
// qu'elle SAIT rougir avant d'affirmer qu'elle est verte — et elle vérifie en
// plus qu'elle a bien balayé un nombre PLAUSIBLE de fichiers réels.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le paquet — et le seul — autorisé à porter Syncfusion chat.
const String kOwner = 'zcrud_chat_syncfusion';

/// Paquets qui ne doivent porter AUCUN Syncfusion (I2).
const List<String> kSyncfusionFreePackages = <String>[
  'zcrud_chat',
  'zcrud_chat_kernel',
  'zcrud_core',
];

/// Motifs de la surface publique de `syncfusion_flutter_chat` (I1).
final List<RegExp> _chatSyncfusionPatterns = <RegExp>[
  RegExp('syncfusion_flutter_chat'),
  RegExp('assist_view'),
  RegExp(r'\bSfAIAssistView\b'),
  RegExp(r'\bAssist(Message|Composer|ActionButton|Placeholder|Suggestion|Toolbar|WidgetBuilder)\w*\b'),
];

/// Toute famille Syncfusion (I2).
final RegExp _anySyncfusion = RegExp('syncfusion', caseSensitive: false);

/// Une violation trouvée par le scanner.
class Violation {
  Violation(this.path, this.rule);

  final String path;
  final String rule;

  @override
  String toString() => '$path [$rule]';
}

/// Retire commentaires de ligne et de bloc, en respectant les littéraux de
/// chaîne (`'https://…'` n'est PAS un commentaire).
///
/// 🔴 SANS CE FILTRE, LA GARDE EST FAUSSE — et mesuré : `zcrud_core` et
/// `zcrud_chat` **documentent** l'isolation Syncfusion (« Syncfusion isolé dans
/// `zcrud_list` », « vue `SfAIAssistView` du lot C6 »). Une garde qui grep le
/// mot dans la prose rougirait sur les commentaires qui expliquent l'invariant
/// qu'elle défend — l'archétype de la garde qu'on finit par désactiver.
/// L'invariant porte sur le CODE : imports, types, symboles.
String stripDartComments(String src) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < src.length) {
    final String c = src[i];
    final String next = i + 1 < src.length ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i = i + 2 <= src.length ? i + 2 : src.length;
      continue;
    }
    if (c == "'" || c == '"') {
      final String quote = c;
      out.write(c);
      i++;
      while (i < src.length) {
        if (src[i] == r'\') {
          out.write(src.substring(i, i + 2 <= src.length ? i + 2 : i + 1));
          i += 2;
          continue;
        }
        out.write(src[i]);
        if (src[i] == quote || src[i] == '\n') {
          i++;
          break;
        }
        i++;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// 🔴 LE SCANNER — fonction PURE sur `chemin relatif -> source`.
///
/// Aucune E/S ici : c'est ce qui la rend exécutable sur un témoin synthétique.
/// [sources] est indexé par un chemin de la forme `packages/<pkg>/lib/...`.
List<Violation> scan(Map<String, String> sources) {
  final List<Violation> out = <Violation>[];
  for (final MapEntry<String, String> e in sources.entries) {
    final String path = e.key;
    final String src = stripDartComments(e.value);
    final List<String> parts = path.split('/');
    final String pkg = parts.length > 1 ? parts[1] : '';

    if (pkg != kOwner) {
      for (final RegExp p in _chatSyncfusionPatterns) {
        if (p.hasMatch(src)) {
          out.add(Violation(path, 'I1:${p.pattern}'));
          break;
        }
      }
    }
    if (kSyncfusionFreePackages.contains(pkg) && _anySyncfusion.hasMatch(src)) {
      out.add(Violation(path, 'I2:syncfusion'));
    }
  }
  return out;
}

/// Racine du dépôt : remontée jusqu'au dossier portant `melos.yaml`.
///
/// ⚠️ JAMAIS un `../..` relatif : `flutter test` s'exécute depuis le dossier du
/// paquet, mais un `melos exec` ou un IDE peuvent l'ancrer ailleurs.
Directory repoRoot() {
  Directory d = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${d.path}/melos.yaml').existsSync()) return d;
    final Directory parent = d.parent;
    if (parent.path == d.path) break;
    d = parent;
  }
  fail('Racine du dépôt introuvable depuis ${Directory.current.path}');
}

/// Toutes les sources `packages/*/lib/**/*.dart` du dépôt, indexées par chemin
/// relatif à la racine.
Map<String, String> realSources() {
  final Directory root = repoRoot();
  final Directory packages = Directory('${root.path}/packages');
  final Map<String, String> out = <String, String>{};
  for (final FileSystemEntity pkg in packages.listSync()) {
    if (pkg is! Directory) continue;
    final String name = pkg.uri.pathSegments
        .where((String s) => s.isNotEmpty)
        .last;
    final Directory lib = Directory('${pkg.path}/lib');
    if (!lib.existsSync()) continue;
    for (final FileSystemEntity f in lib.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final String rel = f.path.substring(pkg.path.length + 1);
      out['packages/$name/$rel'] = f.readAsStringSync();
    }
  }
  return out;
}

// ───────────────── Preuve de GRAPHE (fermeture de dépendances) ──────────────

Map<String, Set<String>>? resolvedGraph(Directory root) {
  ProcessResult res;
  try {
    res = Process.runSync(
      'dart',
      const <String>['pub', 'deps', '--json'],
      workingDirectory: '${root.path}/packages/zcrud_core',
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException {
    return null;
  }
  if (res.exitCode != 0) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(res.stdout as String);
  } on FormatException {
    return null;
  }
  if (decoded is! Map || decoded['packages'] is! List) return null;
  final Map<String, Set<String>> graph = <String, Set<String>>{};
  for (final Object? p in decoded['packages'] as List) {
    if (p is! Map) continue;
    final Object? name = p['name'];
    if (name is! String) continue;
    final Set<String> deps = <String>{};
    final Object? raw = p['dependencies'];
    if (raw is List) {
      for (final Object? d in raw) {
        if (d is String) deps.add(d);
      }
    }
    graph[name] = deps;
  }
  return graph.isEmpty ? null : graph;
}

Set<String> closure(Map<String, Set<String>> graph, String root) {
  final Set<String> seen = <String>{};
  final List<String> stack = <String>[root];
  while (stack.isNotEmpty) {
    final String cur = stack.removeLast();
    if (!seen.add(cur)) continue;
    stack.addAll(graph[cur] ?? const <String>{});
  }
  seen.remove(root);
  return seen;
}

void main() {
  group('AD-57 · scanner de SOURCES', () {
    test('CONTRÔLE POSITIF : le scanner rougit sur un témoin synthétique', () {
      // 🔴 Sans ce test, un scanner qui ne lirait aucun fichier serait vert.
      final List<Violation> v1 = scan(<String, String>{
        'packages/zcrud_chat/lib/src/faux.dart':
            "import 'package:syncfusion_flutter_chat/assist_view.dart';",
      });
      expect(v1, isNotEmpty, reason: 'I1 doit rougir sur un import interdit');

      final List<Violation> v2 = scan(<String, String>{
        'packages/zcrud_study/lib/src/faux.dart':
            'Widget b() => SfAIAssistView(messages: const <AssistMessage>[]);',
      });
      expect(
        v2,
        isNotEmpty,
        reason: 'I1 doit rougir sur un TYPE Syncfusion chat, pas seulement sur '
            'un import — un satellite peut y accéder par ré-export.',
      );

      final List<Violation> v3 = scan(<String, String>{
        'packages/zcrud_core/lib/src/faux.dart':
            "import 'package:syncfusion_flutter_datagrid/datagrid.dart';",
      });
      expect(
        v3,
        isNotEmpty,
        reason: 'I2 doit rougir sur TOUTE famille Syncfusion dans le cœur',
      );

      // 🔴 Le filtre de commentaires est LUI-MÊME sous contrôle : il doit
      // masquer la PROSE et laisser passer le CODE. Sans ces deux assertions,
      // un stripper trop gourmand (qui avalerait aussi le code) rendrait toute
      // la garde silencieuse.
      expect(
        scan(<String, String>{
          'packages/zcrud_core/lib/src/doc.dart':
              '/// Syncfusion est isolé dans `zcrud_list` (SfAIAssistView : lot C6).\n'
              '// syncfusion_flutter_chat\n'
              '/* SfAIAssistView */\n'
              'int x = 1;',
        }),
        isEmpty,
        reason: 'La PROSE qui explique l\'invariant ne doit pas le violer.',
      );
      expect(
        scan(<String, String>{
          'packages/zcrud_core/lib/src/code.dart':
              "const String u = 'https://example.com'; // pas un commentaire\n"
              "import 'package:syncfusion_flutter_chat/assist_view.dart';",
        }),
        isNotEmpty,
        reason: 'Une URL dans une chaîne ne doit pas faire dérailler le '
            'stripper et masquer le code qui suit.',
      );

      // …et il reste SILENCIEUX là où c'est légitime (contrôle négatif : sans
      // lui, un scanner qui rougirait sur tout passerait aussi les trois tests
      // ci-dessus).
      expect(
        scan(<String, String>{
          'packages/$kOwner/lib/src/ok.dart':
              "import 'package:syncfusion_flutter_chat/assist_view.dart';",
          'packages/zcrud_list/lib/src/ok.dart':
              "import 'package:syncfusion_flutter_datagrid/datagrid.dart';",
        }),
        isEmpty,
      );
    });

    test('le scanner a réellement BALAYÉ les sources du dépôt', () {
      final Map<String, String> sources = realSources();
      // Borne basse volontairement grossière : elle ne certifie pas un compte,
      // elle interdit le faux vert « zéro fichier lu ».
      expect(
        sources.length,
        greaterThan(300),
        reason: 'Balayage vide ou tronqué : la garde ne prouverait rien.',
      );
      expect(
        sources.keys.any((String k) => k.startsWith('packages/$kOwner/lib/')),
        isTrue,
        reason: 'Le paquet propriétaire doit faire partie du balayage.',
      );
      expect(
        sources.keys.any((String k) => k.startsWith('packages/zcrud_core/lib/')),
        isTrue,
      );
    });

    test('(I1) Syncfusion chat n\'apparaît hors de $kOwner NULLE PART', () {
      final List<Violation> v = scan(realSources())
          .where((Violation x) => x.rule.startsWith('I1'))
          .toList();
      expect(v, isEmpty, reason: 'Violations AD-57 (I1) : ${v.join(', ')}');
    });

    test('(I2) le socle du chat et le cœur sont SANS Syncfusion', () {
      final List<Violation> v = scan(realSources())
          .where((Violation x) => x.rule.startsWith('I2'))
          .toList();
      expect(v, isEmpty, reason: 'Violations AD-57 (I2) : ${v.join(', ')}');
    });
  });

  group('AD-57 · preuve de GRAPHE (fermeture de dépendances)', () {
    final Directory root = repoRoot();
    final Map<String, Set<String>>? graph = resolvedGraph(root);

    test('(a) aucun paquet du socle du chat ne tire syncfusion_flutter_chat',
        () {
      if (graph == null) {
        markTestSkipped(
          '`dart pub deps --json` indisponible : preuve de graphe non rejouée. '
          'Le scanner de sources reste, lui, exécuté.',
        );
        return;
      }
      for (final String pkg in <String>[
        'zcrud_core',
        'zcrud_chat_kernel',
        'zcrud_chat',
      ]) {
        final Set<String> c = closure(graph, pkg);
        expect(
          c.where((String p) => p.startsWith('syncfusion')).toList(),
          isEmpty,
          reason: '$pkg ne doit tirer AUCUN syncfusion*.',
        );
      }
    });

    test('(b) CONTRÔLE POSITIF externe-transitif sur $kOwner', () {
      if (graph == null) {
        markTestSkipped('`dart pub deps --json` indisponible.');
        return;
      }
      final Set<String> c = closure(graph, kOwner);
      expect(
        c.contains('syncfusion_flutter_chat'),
        isTrue,
        reason: 'Sans cette arête, (a) serait un FAUX VERT.',
      );
      // `syncfusion_flutter_core` n'est PAS une dépendance directe de ce
      // paquet : sa présence prouve que la fermeture suit les arêtes EXTERNES
      // transitives, donc qu'une contamination indirecte de zcrud_core SERAIT
      // détectée par (a).
      expect(
        c.contains('syncfusion_flutter_core'),
        isTrue,
        reason: 'La fermeture doit traverser les arêtes externe→externe.',
      );
    });

    test('(c) AD-1 : arêtes SORTANTES seules, CORE OUT = 0', () {
      final File core = File('${root.path}/packages/zcrud_core/pubspec.yaml');
      expect(
        RegExp(r'^\s{2}zcrud_\w+\s*:', multiLine: true)
            .hasMatch(core.readAsStringSync()),
        isFalse,
        reason: 'zcrud_core ne dépend d\'AUCUN zcrud_* (puits AD-1).',
      );
      final String mine = File(
        '${root.path}/packages/$kOwner/pubspec.yaml',
      ).readAsStringSync();
      for (final String dep in <String>[
        'zcrud_chat',
        'zcrud_chat_kernel',
        'zcrud_core',
      ]) {
        expect(mine.contains('  $dep:'), isTrue, reason: 'arête $dep manquante');
      }
      // PUITS : personne ne dépend de ce paquet.
      for (final FileSystemEntity p
          in Directory('${root.path}/packages').listSync()) {
        if (p is! Directory) continue;
        final String name = p.uri.pathSegments
            .where((String s) => s.isNotEmpty)
            .last;
        if (name == kOwner) continue;
        final File f = File('${p.path}/pubspec.yaml');
        if (!f.existsSync()) continue;
        expect(
          RegExp('^  $kOwner\\s*:', multiLine: true)
              .hasMatch(f.readAsStringSync()),
          isFalse,
          reason: '$name ne doit PAS dépendre de $kOwner (puits du graphe).',
        );
      }
    });
  });
}
