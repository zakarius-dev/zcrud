/// 🎯 fp-1-2 (AC1/AC5) — garde de CONFINEMENT du squelette `zcrud_select`.
///
/// 🔴 **CE TEST EST LA SEULE PROTECTION** de l'arête vendor `zcrud_select ->
/// awesome_select` et de l'allowlist de dépendances du squelette.
/// `scripts/dev/graph_proof.py` ne connaît QUE les arêtes inter-`zcrud_*` : il
/// ne verra JAMAIS `awesome_select` (tiers) ni une dépendance interdite non
/// `zcrud_*`. Sans ce fichier, le confinement est déclaratif.
///
/// Patron : `zcrud_export_ui/test/z_export_ui_confinement_test.dart` (su-11) —
/// dé-commentateur **YAML** (`#`) correct, motifs **ANCRÉS**, allowlist
/// **DÉRIVÉE**, contre-preuves **R12 mutantes**.
///
/// ## Trois volets FALSIFIABLES (leçon su-5/su-11 : prouver que la garde ROUGIT)
///  1. **Allowlist pubspec** : les clés du bloc `dependencies:` de `zcrud_select`
///     ⊆ `{flutter, zcrud_core, awesome_select}`. Un intrus (`image_cropper`)
///     DOIT rougir.
///  2. **Allowlist import** : aucun `import 'package:<X>/'` dans `lib/**` hors
///     `{flutter, zcrud_core, awesome_select, zcrud_select}`. Une fuite témoin
///     DOIT être vue ; un import légitime NE DOIT PAS l'être.
///  3. **Déclarer vendor (AD-49)** : `awesome_select` déclaré EXACTEMENT par
///     `zcrud_select` parmi TOUS les `packages/*/pubspec.yaml` ; le barrel ne
///     l'exporte pas.
///
/// ⚠️ PORTÉE HONNÊTE (leçon E10) : scanne (a) le `pubspec.yaml` de `zcrud_select`
/// (allowlist), (b) les `pubspec.yaml` de tous `packages/*` (déclarer vendor),
/// (c) les sources `lib/**` de `zcrud_select` (imports + barrel). Un import non
/// déclaré ne compilerait pas (`melos run analyze` repo-wide le couvre).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nom du satellite gardé.
const String _self = 'zcrud_select';

/// Le fork privé vendorisé (AD-49) — dépendu du SEUL `zcrud_select`.
const String _vendor = 'awesome_select';

/// Allowlist des dépendances déclarables (bloc `dependencies:` du pubspec).
/// `flutter` = SDK ; `zcrud_core` = unique arête `zcrud_*` (AD-1) ; `awesome_select`
/// = fork privé (ET-1). TOUT autre paquet est une fuite.
const Set<String> _allowedDeps = <String>{'flutter', 'zcrud_core', _vendor};

/// Allowlist des préfixes d'import autorisés dans `lib/**` (+ le paquet lui-même).
const Set<String> _allowedImportPkgs = <String>{
  'flutter',
  'zcrud_core',
  _vendor,
  _self,
};

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

/// Retire les commentaires **YAML** (`#`). 🔴 dé-commentateur du bon langage
/// (leçon su-5 D2 : appliquer `_stripDart` à un pubspec le rendait falsifiable).
String _stripYaml(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('#');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

/// Retire les commentaires **DART** (`//`) — ils citent légitimement des paquets.
/// 🔴 NE JAMAIS appliquer à un pubspec (YAML).
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

/// VRAIE déclaration `<pkg>:` en début de ligne (jamais au fil d'une phrase).
RegExp _yamlDeclares(String pkg) =>
    RegExp('^\\s+${RegExp.escape(pkg)}:', multiLine: true);

/// Extrait les clés de PREMIER niveau du bloc `dependencies:` d'un pubspec
/// (dé-commenté). Les lignes plus indentées (`sdk: flutter`) sont ignorées :
/// seule la clé `flutter:` (indent du 1er enfant) est retenue.
Set<String> _dependencyKeys(String rawYaml) {
  final src = _stripYaml(rawYaml);
  final lines = src.split('\n');
  final keys = <String>{};
  var inBlock = false;
  int? childIndent;
  final blockOpen = RegExp(r'^dependencies:\s*$');
  final topLevel = RegExp(r'^[A-Za-z_]');
  final keyLine = RegExp(r'^(\s+)([A-Za-z0-9_]+)\s*:');
  for (final raw in lines) {
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

/// Préfixes de paquets importés (`import 'package:<X>/...'`) dans du code Dart.
Set<String> _importedPackages(String rawDart) {
  final src = _stripDart(rawDart);
  final re = RegExp(r'''import\s+['"]package:([A-Za-z0-9_]+)/''');
  return re.allMatches(src).map((m) => m.group(1)!).toSet();
}

/// Identifiants **effectivement ré-exportés** par les clauses `export ... show`
/// d'un barrel (dé-commenté). Sans `show`, un export re-expose TOUT : on renvoie
/// alors le marqueur `*` pour forcer le volet à rougir (fuite non maîtrisée).
Set<String> _exportedShownIds(String rawDart) {
  final src = _stripDart(rawDart);
  final withShow =
      RegExp(r'''export\s+['"][^'"]+['"]\s+show\s+([^;]+);''');
  final bareExport = RegExp(r'''export\s+['"][^'"]+['"]\s*;''');
  final ids = <String>{};
  for (final m in withShow.allMatches(src)) {
    for (final part in m.group(1)!.split(',')) {
      // LOW-3 : conserver l'identifiant SOURCE (AVANT `as`), pas l'alias. Un
      // `show S2Choice as ZFoo` ré-exporte le TYPE FORK `S2Choice` sous un alias
      // `Z*` : prendre `.last` (`ZFoo`) échapperait à `_isS2Leak` ; `.first`
      // (`S2Choice`) le fait rougir. Un identifiant simple reste inchangé.
      final id = part.trim().split(RegExp(r'\s+')).first; // gère `X as Y` (garde X).
      if (id.isNotEmpty) ids.add(id);
    }
  }
  if (bareExport.hasMatch(src)) ids.add('*');
  return ids;
}

/// Un identifiant exporté est-il un type S2/`SmartSelect` (fuite AD-40) ? Le
/// préfixe `Z` légitime (`ZSmartSelectPresenter`) N'EST PAS une fuite : seuls les
/// identifiants qui SONT des types du fork (`SmartSelect*`, `S2*`) ou un export
/// nu (`*`) rougissent.
bool _isS2Leak(String id) =>
    id == '*' ||
    id.startsWith('SmartSelect') ||
    RegExp(r'^S2[A-Z0-9]').hasMatch(id);

void main() {
  group('🎯 volet 1 — allowlist des dépendances (pubspec, YAML ANCRÉ)', () {
    test('🔴 `dependencies:` de `$_self` ⊆ $_allowedDeps', () {
      final raw =
          File('${_repoRoot().path}/packages/$_self/pubspec.yaml').readAsStringSync();
      final keys = _dependencyKeys(raw);
      expect(keys, contains('zcrud_core'),
          reason: 'le satellite DOIT dépendre de zcrud_core (AD-1)');
      expect(keys, contains(_vendor),
          reason: 'l\'arête vendor ET-1 DOIT être posée ici (fp-1-2)');
      final intrus = keys.difference(_allowedDeps);
      expect(intrus, isEmpty,
          reason: '🔴 dépendance(s) hors allowlist : $intrus');
    });

    test('🔬 R12 — la règle SAIT détecter une dépendance interdite', () {
      const falsified = '''
name: zcrud_select
dependencies:
  zcrud_core: ^0.2.1
  awesome_select: ^6.0.0
  image_cropper: ^12.2.1
  flutter:
    sdk: flutter
''';
      final keys = _dependencyKeys(falsified);
      expect(keys, contains('image_cropper'),
          reason: 'témoin : le parseur voit bien l\'intrus');
      expect(keys.difference(_allowedDeps), <String>{'image_cropper'},
          reason: '🔴 un intrus DOIT ressortir de la différence à l\'allowlist');
      // Et le vrai pubspec, lui, ne contient PAS d'intrus.
      const legit = '''
name: zcrud_select
dependencies:
  zcrud_core: ^0.2.1
  awesome_select: ^6.0.0
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
      expect(leaks, isEmpty, reason: '🔴 import(s) hors allowlist :\n${leaks.join('\n')}');
    });

    test('🔬 R12 — le scan voit une VRAIE fuite et IGNORE un import légitime', () {
      const probeLeak = "import 'package:image_cropper/image_cropper.dart';";
      const probeOwn = "import 'package:zcrud_core/zcrud_core.dart';";
      expect(_importedPackages(probeLeak).difference(_allowedImportPkgs),
          <String>{'image_cropper'},
          reason: '🔴 une fuite `image_cropper` DOIT être vue');
      expect(_importedPackages(probeOwn).difference(_allowedImportPkgs), isEmpty,
          reason: '🔴 un import légitime NE DOIT PAS être compté comme fuite');
      // Le dé-commentateur DART neutralise un import cité en commentaire.
      expect(_importedPackages('// import "package:image_cropper/x.dart";'),
          isEmpty,
          reason: '🔴 un import commenté ne déclare rien');
    });
  });

  group('🎯 volet 3 — `$_vendor` DÉCLARÉ exactement par `$_self` (AD-49)', () {
    test('🔴 déclarants(`$_vendor`) == [`$_self`] parmi packages/*', () {
      final packagesDir = Directory('${_repoRoot().path}/packages');
      final pubspecs = packagesDir
          .listSync()
          .whereType<Directory>()
          .map((d) => File('${d.path}/pubspec.yaml'))
          .where((f) => f.existsSync())
          .toList();
      expect(pubspecs.length, greaterThan(5),
          reason: 'le scan ne voit que ${pubspecs.length} pubspec — vacant');

      final declaring = <String>[
        for (final f in pubspecs)
          if (_yamlDeclares(_vendor).hasMatch(_stripYaml(f.readAsStringSync())))
            f.parent.path.split(Platform.pathSeparator).last,
      ]..sort();

      expect(declaring, <String>[_self],
          reason: '🔴 AD-49 : `$_vendor` doit être dépendu du SEUL `$_self` '
              '(le paquet vendorisé lui-même ne se déclare pas). Trouvé : $declaring');
    });

    test('🔴 le barrel de `$_self` n\'exporte pas `$_vendor`', () {
      final barrel = _stripDart(
        File('${_selfLib().path}/$_self.dart').readAsStringSync(),
      );
      expect(barrel.contains(_vendor), isFalse,
          reason: '🔴 le barrel exposerait `$_vendor` à tout consommateur (AD-40)');
    });

    test('🔬 R12 — le dé-commentateur YAML n\'est pas falsifiable par un commentaire',
        () {
      const documenting = '''
name: zcrud_html
dependencies:
  # NOTE: ne jamais declarer awesome_select ici (confine a zcrud_select).
  zcrud_core: ^0.2.1
  flutter:
    sdk: flutter
''';
      expect(_yamlDeclares(_vendor).hasMatch(_stripYaml(documenting)), isFalse,
          reason: '🔴 accuser un paquet sur un commentaire = diagnostic FAUX');
      expect(
        _yamlDeclares(_vendor)
            .hasMatch(_stripYaml('dependencies:\n  awesome_select: ^6.0.0\n')),
        isTrue,
        reason: 'témoin : une VRAIE déclaration DOIT être vue',
      );
    });
  });

  group('🎯 volet 4 — ZÉRO fuite `SmartSelect`/`S2*` dans les exports (AD-40)',
      () {
    test('🔴 aucun identifiant `SmartSelect`/`S2*` (ni export nu) au barrel', () {
      final barrel =
          File('${_selfLib().path}/$_self.dart').readAsStringSync();
      final ids = _exportedShownIds(barrel);
      // Anti-vacuité : le barrel DOIT ré-exporter au moins un symbole réel
      // (sinon le scan passe trivialement).
      expect(ids, isNotEmpty,
          reason: '🔴 anti-vacuité : le barrel n\'exporte AUCUN identifiant '
              '— la garde de fuite serait inopérante');
      final leaks = ids.where(_isS2Leak).toList();
      expect(leaks, isEmpty,
          reason: '🔴 le barrel exposerait un type S2/SmartSelect : $leaks');
      // Le présentateur légitime (préfixe `Z`) EST bien exporté.
      expect(ids, contains('ZSmartSelectPresenter'),
          reason: 'le présentateur riche DOIT être exposé au barrel (fp-4-1)');
    });

    test('🔬 R12 — un export S2 témoin ROUGIT ; un `Z*` légitime NE rougit PAS',
        () {
      const mutantShow =
          "export 'src/presentation/z_smart_select_presenter.dart' "
          'show ZSmartSelectPresenter, S2Choice;';
      final mutantIds = _exportedShownIds(mutantShow);
      expect(mutantIds.where(_isS2Leak), <String>{'S2Choice'},
          reason: '🔴 un export `S2Choice` DOIT être détecté comme fuite');

      const mutantBare = "export 'package:awesome_select/awesome_select.dart';";
      expect(_exportedShownIds(mutantBare).where(_isS2Leak), <String>{'*'},
          reason: '🔴 un export NU (re-expose tout le fork) DOIT rougir');

      // LOW-3 : un ALIAS `Z*` sur un type fork ne DOIT PAS masquer la fuite —
      // l'analyse porte sur l'identifiant SOURCE (`S2Choice`), pas l'alias.
      const mutantAlias =
          "export 'src/presentation/z_smart_select_presenter.dart' "
          'show S2Choice as ZFoo;';
      expect(_exportedShownIds(mutantAlias).where(_isS2Leak), <String>{'S2Choice'},
          reason: '🔴 `S2Choice as ZFoo` ré-exporte le type fork : DOIT rougir');

      const legit =
          "export 'src/presentation/z_smart_select_presenter.dart' "
          'show ZSmartSelectPresenter;';
      expect(_exportedShownIds(legit).where(_isS2Leak), isEmpty,
          reason: '🔴 `ZSmartSelectPresenter` (préfixe Z) N\'EST PAS une fuite');

      // Le dé-commentateur DART neutralise un export cité en commentaire.
      expect(_exportedShownIds("// export 'x.dart' show S2Choice;"), isEmpty,
          reason: '🔴 un export commenté n\'expose rien');
    });
  });
}
