/// 🎯 fp-4-3 (AC1) — garde de CONFINEMENT de l'adaptateur `zcrud_html`.
///
/// 🔴 **CE TEST EST LA SEULE PROTECTION** de l'allowlist de dépendances du
/// satellite. `scripts/dev/graph_proof.py` ne connaît QUE les arêtes
/// inter-`zcrud_*` : il ne verra JAMAIS une dépendance lourde interdite non
/// `zcrud_*`. fp-4-3 ADMET `html_editor_enhanced`/`flutter_html` (confinées à
/// `lib/src/`) dans l'allowlist ; le témoin R12 est donc DÉPLACÉ vers un intrus
/// ENCORE interdit (`get`) pour que la garde continue de MORDRE (contre-preuve
/// mutante toujours verte).
///
/// Patron : `zcrud_export_ui/test/z_export_ui_confinement_test.dart` (su-11) —
/// dé-commentateur **YAML** (`#`), motifs **ANCRÉS**, allowlist **DÉRIVÉE**,
/// contre-preuves **R12 mutantes**.
///
/// ## Deux volets FALSIFIABLES :
///  1. **Allowlist pubspec** : clés de `dependencies:` ⊆
///     `{flutter, zcrud_core, html_editor_enhanced, flutter_html}`.
///  2. **Allowlist import** : aucun `import 'package:<X>/'` dans `lib/**` hors
///     `{flutter, zcrud_core, zcrud_html, html_editor_enhanced, flutter_html}`.
///
/// 🔴 **AD-1 en négatif** : `zcrud_markdown` (l'AUTRE voie du `kind` `html`) est
/// HORS allowlist — une arête vers lui casserait l'acyclicité ET l'exclusivité
/// prouvée par le contrat cœur (jamais par une dépendance directe).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _self = 'zcrud_html';

/// Allowlist des dépendances déclarables (bloc `dependencies:`). fp-4-3 ajoute
/// les deux tierces lourdes CONFINÉES à `lib/src/` (aucun type public — AD-40).
const Set<String> _allowedDeps = <String>{
  'flutter',
  'zcrud_core',
  'html_editor_enhanced',
  'flutter_html',
};

/// Allowlist des préfixes d'import autorisés dans `lib/**` (+ le paquet lui-même).
const Set<String> _allowedImportPkgs = <String>{
  'flutter',
  'zcrud_core',
  _self,
  'html_editor_enhanced',
  'flutter_html',
};

/// Un intrus témoin ENCORE interdit (gestionnaire d'état banni du cœur/satellite
/// — AD-1). Remplace l'ancien témoin `html_editor_enhanced` désormais AUTORISÉ,
/// pour que la contre-preuve R12 continue de mordre.
const String _probeIntruder = 'get';

Directory _repoRoot() {
  for (final p in <String>['.', '../..']) {
    if (Directory('$p/packages').existsSync()) return Directory(p);
  }
  fail('racine du monorepo introuvable depuis ${Directory.current.path}');
}

Directory _selfLib() {
  final d = Directory('${_repoRoot().path}/packages/$_self/lib');
  if (!d.existsSync()) fail('lib/ de $_self introuvable : ${d.path}');
  return d;
}

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Retire les commentaires **YAML** (`#`). 🔴 dé-commentateur du bon langage.
String _stripYaml(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('#');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

/// Retire les commentaires **DART** (`//`). 🔴 jamais sur un pubspec.
String _stripDart(String src) => src
    .split('\n')
    .where((l) {
      final t = l.trim();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .map((l) {
      final i = l.indexOf('//');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

/// Clés de PREMIER niveau du bloc `dependencies:` (dé-commenté). `sdk: flutter`
/// (plus indenté) est ignoré : seule `flutter:` est retenue.
Set<String> _dependencyKeys(String rawYaml) {
  final src = _stripYaml(rawYaml);
  final keys = <String>{};
  var inBlock = false;
  int? childIndent;
  final blockOpen = RegExp(r'^dependencies:\s*$');
  final topLevel = RegExp(r'^[A-Za-z_]');
  final keyLine = RegExp(r'^(\s+)([A-Za-z0-9_]+)\s*:');
  for (final raw in src.split('\n')) {
    if (raw.trim().isEmpty) continue;
    if (blockOpen.hasMatch(raw)) {
      inBlock = true;
      childIndent = null;
      continue;
    }
    if (inBlock && topLevel.hasMatch(raw)) {
      inBlock = false;
      continue;
    }
    if (!inBlock) continue;
    final m = keyLine.firstMatch(raw);
    if (m == null) continue;
    final indent = m.group(1)!.length;
    childIndent ??= indent;
    if (indent == childIndent) keys.add(m.group(2)!);
  }
  return keys;
}

/// Préfixes de paquets importés (`import 'package:<X>/...'`).
Set<String> _importedPackages(String rawDart) {
  final src = _stripDart(rawDart);
  final re = RegExp(r'''import\s+['"]package:([A-Za-z0-9_]+)/''');
  return re.allMatches(src).map((m) => m.group(1)!).toSet();
}

/// Cibles de `export` du barrel (chaîne entre quotes de chaque directive).
Set<String> _exportTargets(String rawDart) {
  final src = _stripDart(rawDart);
  final re = RegExp(r'''export\s+['"]([^'"]+)['"]''');
  return re.allMatches(src).map((m) => m.group(1)!).toSet();
}

/// Symboles listés dans les clauses `show` des `export` du barrel.
Set<String> _shownSymbols(String rawDart) {
  final src = _stripDart(rawDart);
  final re = RegExp(r'''export\s+['"][^'"]+['"][^;]*?\bshow\b([^;]+);''');
  final out = <String>{};
  for (final m in re.allMatches(src)) {
    for (final s in m.group(1)!.split(',')) {
      final t = s.trim();
      if (t.isNotEmpty) out.add(t);
    }
  }
  return out;
}

/// Types TIERS lourds bannis de la surface publique (AD-40) — aucun ne doit
/// apparaître comme symbole `show`é ni via un ré-export direct du barrel.
const Set<String> _forbiddenPublicTypes = <String>{
  // html_editor_enhanced
  'HtmlEditor',
  'HtmlEditorController',
  'HtmlEditorOptions',
  'OtherOptions',
  'Callbacks',
  'Toolbar',
  // flutter_html
  'Html',
  'Style',
  'Margins',
  'Margin',
};

/// Préfixes de paquets TIERS interdits en ré-export DIRECT du barrel (AD-40 :
/// aucun type tiers ne fuit en surface — ils restent confinés à `lib/src/`).
const Set<String> _forbiddenExportPkgs = <String>{
  'html_editor_enhanced',
  'flutter_html',
};

/// Détecte les fuites d'AD-40 dans un barrel : (a) ré-export direct d'un paquet
/// tiers, (b) symbole `show`é qui EST un type tiers banni.
List<String> _barrelSurfaceLeaks(String rawDart) {
  final leaks = <String>[];
  for (final t in _exportTargets(rawDart)) {
    final m = RegExp(r'^package:([A-Za-z0-9_]+)/').firstMatch(t);
    if (m != null && _forbiddenExportPkgs.contains(m.group(1))) {
      leaks.add('ré-export direct package:${m.group(1)}');
    }
  }
  for (final s in _shownSymbols(rawDart).intersection(_forbiddenPublicTypes)) {
    leaks.add('type tiers exposé en show: $s');
  }
  return leaks;
}

void main() {
  group('🎯 volet 1 — allowlist des dépendances (pubspec, YAML ANCRÉ)', () {
    test('🔴 `dependencies:` de `$_self` ⊆ $_allowedDeps', () {
      final raw = File('${_repoRoot().path}/packages/$_self/pubspec.yaml')
          .readAsStringSync();
      final keys = _dependencyKeys(raw);
      expect(keys, contains('zcrud_core'),
          reason: 'le satellite DOIT dépendre de zcrud_core (AD-1)');
      final intrus = keys.difference(_allowedDeps);
      expect(intrus, isEmpty, reason: '🔴 dépendance(s) hors allowlist : $intrus');
    });

    test('🔬 R12 — la règle SAIT détecter une dépendance lourde interdite', () {
      final falsified = '''
name: $_self
dependencies:
  zcrud_core: ^0.2.1
  $_probeIntruder: ^2.6.0
  flutter:
    sdk: flutter
''';
      final keys = _dependencyKeys(falsified);
      expect(keys, contains(_probeIntruder),
          reason: 'témoin : le parseur voit bien l\'intrus');
      expect(keys.difference(_allowedDeps), <String>{_probeIntruder},
          reason: '🔴 un intrus DOIT ressortir de la différence à l\'allowlist');
      const legit = '''
name: zcrud_html
dependencies:
  zcrud_core: ^0.2.1
  flutter:
    sdk: flutter
''';
      expect(_dependencyKeys(legit).difference(_allowedDeps), isEmpty);
    });
  });

  group('🎯 volet 2 — allowlist des imports (lib/**, DART dé-commenté)', () {
    test('🔴 aucun `import package:<X>` hors $_allowedImportPkgs', () {
      final leaks = <String>[];
      final files = _dartFiles(_selfLib()).toList();
      expect(files, isNotEmpty,
          reason: '🔴 anti-vacuité : le scan lib/** ne voit AUCUN fichier .dart '
              '— un refactor hors du glob rendrait cette garde inopérante');
      for (final f in files) {
        final pkgs = _importedPackages(f.readAsStringSync());
        for (final p in pkgs.difference(_allowedImportPkgs)) {
          leaks.add('${f.path} -> package:$p');
        }
      }
      expect(leaks, isEmpty,
          reason: '🔴 import(s) hors allowlist :\n${leaks.join('\n')}');
    });

    test('🔬 R12 — le scan voit une VRAIE fuite et IGNORE un import légitime', () {
      final probeLeak = "import 'package:$_probeIntruder/$_probeIntruder.dart';";
      const probeOwn = "import 'package:zcrud_core/zcrud_core.dart';";
      expect(_importedPackages(probeLeak).difference(_allowedImportPkgs),
          <String>{_probeIntruder},
          reason: '🔴 une fuite `$_probeIntruder` DOIT être vue');
      expect(_importedPackages(probeOwn).difference(_allowedImportPkgs), isEmpty,
          reason: '🔴 un import légitime NE DOIT PAS être compté comme fuite');
      expect(_importedPackages('// import "package:$_probeIntruder/x.dart";'),
          isEmpty,
          reason: '🔴 un import commenté ne déclare rien');
    });
  });

  group('🎯 volet 3 — surface publique du barrel SANS type tiers (AD-40)', () {
    test('🔴 aucun export du barrel n\'expose un type tiers', () {
      final raw =
          File('${_repoRoot().path}/packages/$_self/lib/$_self.dart')
              .readAsStringSync();
      // Anti-vacuité : le barrel exporte bien quelque chose (sinon la garde
      // deviendrait triviale — un refactor qui vide le barrel serait invisible).
      expect(_exportTargets(raw), isNotEmpty,
          reason: '🔴 anti-vacuité : le barrel ne déclare AUCUN export');
      final leaks = _barrelSurfaceLeaks(raw);
      expect(leaks, isEmpty,
          reason: '🔴 type(s) tiers en surface publique :\n${leaks.join('\n')}');
    });

    test('🔬 R12 — la garde voit un type tiers exposé et IGNORE la surface saine',
        () {
      // Fuite (a) : ré-export DIRECT d'un paquet tiers.
      const leakReexport =
          "export 'package:html_editor_enhanced/html_editor.dart';";
      expect(_barrelSurfaceLeaks(leakReexport), isNotEmpty,
          reason: '🔴 un ré-export direct de type tiers DOIT être vu');

      // Fuite (b) : symbole tiers listé en `show` (le témoin de la story).
      const leakShow =
          "export 'src/x.dart' show ZHtmlView, HtmlEditorController;";
      expect(_barrelSurfaceLeaks(leakShow),
          contains('type tiers exposé en show: HtmlEditorController'),
          reason: '🔴 un type tiers `show`é DOIT ressortir');

      // Surface SAINE (l\'actuelle) : aucun faux positif.
      const sane = '''
export 'src/presentation/z_html_view.dart' show ZHtmlView;
export 'src/presentation/z_html_wysiwyg_registration.dart'
    show registerZHtmlFields;
''';
      expect(_barrelSurfaceLeaks(sane), isEmpty,
          reason: '🔴 une surface publique neutre NE DOIT PAS rougir');

      // Un export tiers COMMENTÉ ne déclare rien (dé-commentateur Dart).
      expect(
        _barrelSurfaceLeaks(
            "// export 'package:flutter_html/flutter_html.dart';"),
        isEmpty,
        reason: '🔴 un export commenté n\'expose rien',
      );
    });
  });
}
