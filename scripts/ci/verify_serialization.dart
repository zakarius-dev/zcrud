// Slot CI E2-10 / **ES-3.5** (AD-10) : rétro-compatibilité de sérialisation.
//
// AD-10 (architecture.md) : évolution de schéma ADDITIVE + désérialisation
// DÉFENSIVE (un document historique/tronqué/à champs inconnus ne casse jamais le
// parent). Le SLOT est rattaché au gate de merge depuis E1-3 ; le CORPUS de
// rétro-compat reste un livrable **ES-3.5** (et E2-10 pour le cœur).
//
// Convention de branchement STABLE (ES-3.5 n'aura PAS à toucher ce script ni le
// workflow CI) :
//   - ES-3.5 ajoutera des tests taggés `serialization-compat`
//     (`@Tags(['serialization-compat'])`) dans les packages concernés ;
//   - ce script exécute `<runner> test --tags serialization-compat` dans chaque
//     package possédant un dossier `test/`, où `<runner>` est `flutter` pour un
//     package Flutter (ex. `zcrud_core` depuis E2-7) et `dart` pour un package
//     pur-Dart (`dart test` refuse de tourner dans un package Flutter) ;
//   - il suffira ensuite de poser `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` en CI
//     pour rendre l'ABSENCE de corpus BLOQUANTE.
//
// ## ⚠️ ES-1.4 — le SKIP est désormais BRUYANT (anti-faux-vert)
//
// `exit 79` = « aucun test taggé » était toléré **silencieusement** : un lecteur
// de log pouvait croire la rétro-compat VÉRIFIÉE alors qu'elle n'était même pas
// TESTÉE — le faux vert structurel exact que combat ES-1.4. Le script imprime
// maintenant une BANNIÈRE nommant les packages sans corpus, disant noir sur
// blanc que la rétro-compat n'a PAS été vérifiée, et renvoyant à ES-3.5. Le RC
// reste 0 (le corpus n'est pas encore dû) — SAUF sous l'interrupteur ci-dessous.
//
// Usage : dart run scripts/ci/verify_serialization.dart
//   Variables d'env : ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 → un package sans test
//   `serialization-compat` devient un ÉCHEC (RC≠0). ES-3.5 l'activera en CI.
import 'dart:io';

/// `true` si le package [pkgDir] dépend du SDK Flutter (bloc `dependencies:`
/// contenant `flutter:` avec `sdk: flutter`). Détection textuelle robuste et
/// sans dépendance — **même helper que `scripts/ci/gate_web_determinism.dart`**.
bool _isFlutterPackage(Directory pkgDir) {
  final pubspec = File('${pkgDir.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return false;
  var inDeps = false;
  for (final raw in pubspec.readAsLinesSync()) {
    final line = raw.replaceFirst(RegExp(r'#.*$'), '');
    if (RegExp(r'^dependencies:\s*$').hasMatch(line)) {
      inDeps = true;
      continue;
    }
    // Une clé top-level non indentée ferme le bloc dependencies.
    if (inDeps && RegExp(r'^[A-Za-z_]').hasMatch(line)) inDeps = false;
    if (inDeps && RegExp(r'^\s+flutter:\s*$').hasMatch(line)) return true;
  }
  return false;
}

/// `true` si le package [pkgDir] **déclare** le tag `serialization-compat` dans
/// son `dart_test.yaml` (bloc `tags:` contenant une clé `serialization-compat:`).
///
/// ═══════════════════════ MICRO-AJUSTEMENT SIGNALÉ — ES-3.5 / D7 ═══════════════
/// **Population REDEVABLE = tag-declarers (opt-in par `dart_test.yaml`).**
///
/// Avant ES-3.5, le gate itérait TOUS les packages ayant un dossier `test/` (18
/// mesurés) et les comptait `skipped` faute de test taggé. Sous l'interrupteur
/// `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1`, cela imposerait un corpus dans CHACUN
/// — dont 9 SANS entité persistée (`zcrud_geo`, `zcrud_intl`, `zcrud_list`,
/// `zcrud_mindmap`, `zcrud_export`, `zcrud_get`, `zcrud_riverpod`,
/// `zcrud_provider`, `zcrud_annotations`). Y semer une fixture serait un **corpus
/// POWERLESS** (ne discrimine RIEN) — interdit (R12/DW-ES25-1).
///
/// Le `dart_test.yaml` **EST DÉJÀ** le marqueur d'opt-in de la convention (le
/// kernel l'a posé « prêt pour ES-3.5 »). Ce filtre rend « redevable » ≡ « a
/// DÉCLARÉ le tag », alignant le gate sur sa propre convention. Population
/// résultante après ES-3.5 = {`zcrud_generator`, `zcrud_study_kernel`,
/// `zcrud_firestore`} — toutes portent un corpus.
///
/// ⚠️ POUVOIR DISCRIMINANT PRÉSERVÉ : un package qui **déclare** le tag SANS
/// corpus vert reste `skipped` ⇒ RC=1 sous l'interrupteur (cf. R3-8). Le squelette
/// du gate (itération, runner `flutter`/`dart`, `exit 79`→skip, bannière,
/// interrupteur) est **INCHANGÉ** — seul l'ensemble de départ est restreint.
/// ═════════════════════════════════════════════════════════════════════════════
bool _declaresCompatTag(Directory pkgDir) {
  final cfg = File('${pkgDir.path}/dart_test.yaml');
  if (!cfg.existsSync()) return false;
  var inTags = false;
  for (final raw in cfg.readAsLinesSync()) {
    final line = raw.replaceFirst(RegExp(r'#.*$'), '');
    if (RegExp(r'^tags:\s*$').hasMatch(line)) {
      inTags = true;
      continue;
    }
    // Une clé top-level non indentée ferme le bloc tags:.
    if (inTags && RegExp(r'^[A-Za-z_]').hasMatch(line)) inTags = false;
    if (inTags && RegExp(r'^\s+serialization-compat:').hasMatch(line)) {
      return true;
    }
  }
  return false;
}

/// Bannière BRUYANTE (patron `gate:web`) : la rétro-compat n'a PAS été vérifiée
/// pour [skipped]. RC inchangé (0) — sauf interrupteur ES-3.5.
void _banner(List<String> skipped, {required bool required}) {
  final out = required ? stderr : stdout;
  out.writeln('');
  out.writeln('=' * 78);
  out.writeln(
    required
        ? '[verify:serialization] ❌ ÉCHEC — CORPUS DE RÉTRO-COMPAT MANQUANT'
        : '[verify:serialization] ⚠️  SKIP — RÉTRO-COMPAT DE SÉRIALISATION NON VÉRIFIÉE',
  );
  out.writeln(
    '[verify:serialization] Packages SANS test taggé `serialization-compat` :',
  );
  for (final pkg in skipped) {
    out.writeln('[verify:serialization]     - $pkg');
  }
  out.writeln(
    '[verify:serialization] La désérialisation DÉFENSIVE (AD-10) de ces packages '
    'n\'est donc PAS',
  );
  out.writeln(
    '[verify:serialization] couverte par un corpus de documents HISTORIQUES : une '
    'régression de',
  );
  out.writeln(
    '[verify:serialization] rétro-compat (champ retiré, enum renommé, sous-objet '
    'corrompu) passerait',
  );
  out.writeln('[verify:serialization] INAPERÇUE.');
  out.writeln(
    '[verify:serialization] Corpus dû par ES-3.5 (cœur : E2-10) — brancher des '
    'tests `@Tags([\'serialization-compat\'])`,',
  );
  out.writeln(
    '[verify:serialization] puis poser ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 en CI '
    '(aucune édition de ce',
  );
  out.writeln('[verify:serialization] script ni du workflow requise).');
  out.writeln('=' * 78);
  out.writeln('');
}

void main() {
  final required =
      Platform.environment['ZCRUD_REQUIRE_SERIALIZATION_COMPAT'] == '1';

  final pkgs = Directory('packages');
  if (!pkgs.existsSync()) {
    stdout.writeln(
      'verify:serialization NO-OP — pas de packages/. Slot E2-10/ES-3.5 (AD-10).',
    );
    exit(0);
  }

  final withTests = <Directory>[];
  for (final ent in pkgs.listSync()) {
    // MICRO-AJUSTEMENT ES-3.5/D7 : population redevable = tag-declarers (a un
    // dossier test/ ET déclare `serialization-compat` dans dart_test.yaml).
    if (ent is Directory &&
        Directory('${ent.path}/test').existsSync() &&
        _declaresCompatTag(ent)) {
      withTests.add(ent);
    }
  }
  withTests.sort((Directory a, Directory b) => a.path.compareTo(b.path));

  if (withTests.isEmpty) {
    stdout.writeln(
      'verify:serialization NO-OP — aucun dossier test/. Slot rattaché au gate '
      'de merge ; corpus dû par ES-3.5 (AD-10).',
    );
    exit(0);
  }

  var failed = false;
  final skipped = <String>[];
  for (final pkg in withTests) {
    final runner = _isFlutterPackage(pkg) ? 'flutter' : 'dart';
    final r = Process.runSync(
      runner,
      <String>['test', '--tags', 'serialization-compat'],
      workingDirectory: pkg.path,
    );
    // exit 79 = « no tests ran » (aucun test taggé `serialization-compat`), pour
    // `dart` comme pour `flutter`. On NE RELAIE PAS le stderr brut « ERROR: No
    // tests match the requested tag selectors » : ce « ERROR » est TROMPEUR
    // (LOW-4). On collecte le package pour la BANNIÈRE de fin (ES-1.4) : le SKIP
    // est toléré, mais plus jamais silencieux.
    if (r.exitCode == 79) {
      skipped.add(pkg.path);
      continue;
    }
    stdout.writeln(
      'verify:serialization — ${pkg.path} (tag serialization-compat, runner: $runner)',
    );
    stdout.write(r.stdout);
    stderr.write(r.stderr);
    if (r.exitCode != 0) failed = true;
  }

  if (skipped.isNotEmpty) {
    _banner(skipped, required: required);
    if (required) failed = true; // Interrupteur ES-3.5.
  }

  if (failed) exit(1);
  if (skipped.isEmpty) {
    stdout.writeln(
      'verify:serialization OK — corpus `serialization-compat` vert sur tous les '
      'packages (AD-10).',
    );
  }
  exit(0);
}
