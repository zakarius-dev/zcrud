// Gate AD-12 : scan de secrets committés (repli LOCAL de gitleaks).
//
// AD-12 (architecture.md) : ZÉRO secret dans le dépôt ; `badCertificateCallback
// => true` interdit. En CI, l'AUTORITÉ est gitleaks (couvre l'historique git).
// Ce script est le REPLI LOCAL reproductible (hors réseau) : il prouve le gate
// par fixture et permet `melos run verify` hors CI.
//
// Périmètre (M-2) : TOUS les fichiers texte, quelle que soit l'extension — un
// secret `AIza…`/PEM/token dans `.txt`, `.properties`, `Dockerfile`, `.pem` ou
// un fichier SANS extension doit être attrapé (aligné sur la couverture gitleaks).
// On ne filtre PLUS par extension d'inclusion : on saute les binaires par lecture
// défensive (octet NUL) et on exclut `.git`/`.dart_tool`/`build`/caches.
// La prose Markdown (docs, story, CLAUDE.md) reste HORS périmètre du repli local
// (elle cite légitimement `AIza…`/`badCertificateCallback` comme contre-exemples) ;
// gitleaks en CI couvre l'ensemble, y compris le Markdown. Auto-exclusion : ce
// fichier (définitions de motifs), `.git`, code généré, caches, et
// `scripts/ci/fixtures/**` sur l'arbre réel.
//
// Usage : dart run scripts/ci/gate_secret_scan.dart [--root <dir>]
//   --root : dossier à scanner (défaut : dépôt courant). Sert aux fixtures.
import 'dart:convert';
import 'dart:io';

class _Pattern {
  final String label;
  final RegExp re;
  const _Pattern(this.label, this.re);
}

// NB : motifs construits pour ne PAS s'auto-détecter (ce fichier est aussi exclu).
final _patterns = <_Pattern>[
  _Pattern('cle Google (AIza...)', RegExp('AIza' r'[0-9A-Za-z_\-]{35}')),
  _Pattern('cle AWS (AKIA...)', RegExp('AKIA' r'[0-9A-Z]{16}')),
  _Pattern('cle privee PEM', RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----')),
  // H-1 : la SEULE forme réelle en Dart est une AFFECTATION du callback, pas le
  // littéral impossible `badCertificateCallback => true`. On couvre :
  //   client.badCertificateCallback = (X509Certificate c, String h, int p) => true;
  //   client.badCertificateCallback = (c, h, p) { return true; };
  //   badCertificateCallback => true            (forme directe / override)
  _Pattern(
    'badCertificateCallback = (...) => true',
    RegExp(r'badCertificateCallback\s*(=>\s*true|=\s*\([^)]*\)\s*(=>\s*true|\{\s*return\s+true))'),
  ),
  _Pattern('token Slack', RegExp('xox' r'[baprs]-[0-9A-Za-z\-]{10,}')),
];

// M-2 : la prose Markdown reste hors périmètre du repli local (contre-exemples
// documentés). Tout AUTRE fichier texte est scanné, sans allowlist d'extension.
const _proseExtensions = {'.md', '.markdown'};

bool _excludedDir(String norm) {
  return norm.contains('/.git/') ||
      norm.contains('/.dart_tool/') ||
      norm.contains('/.pub-cache/') ||
      norm.contains('/build/') ||
      norm.startsWith('.git/') ||
      norm.startsWith('.dart_tool/') ||
      norm.startsWith('build/');
}

bool _isProse(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return _proseExtensions.contains(path.substring(dot).toLowerCase());
}

// Détection défensive de binaire : un octet NUL dans le préfixe => on saute.
bool _looksBinary(List<int> bytes) {
  final n = bytes.length < 8192 ? bytes.length : 8192;
  for (var i = 0; i < n; i++) {
    if (bytes[i] == 0) return true;
  }
  return false;
}

void main(List<String> args) {
  var root = '.';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--root' && i + 1 < args.length) root = args[i + 1];
  }
  final scanningFixture = root != '.';
  final self = Platform.script.toFilePath().replaceAll('\\', '/');

  final dir = Directory(root);
  if (!dir.existsSync()) {
    stderr.writeln('gate:secrets — dossier introuvable: $root');
    exit(2);
  }

  final findings = <String>[];
  for (final ent in dir.listSync(recursive: true, followLinks: false)) {
    if (ent is! File) continue;
    final norm = ent.path.replaceAll('\\', '/');
    if (_excludedDir(norm)) continue;
    // Auto-exclusion des définitions de motifs ET du harnais de preuve qui
    // fabrique des tokens factices (scripts/ci/prove_gates.dart).
    if (norm.endsWith('scripts/ci/gate_secret_scan.dart') ||
        norm.endsWith('scripts/ci/prove_gates.dart') ||
        norm == self) continue;
    // Sur l'arbre réel, exclure les fixtures (elles contiennent des secrets factices).
    if (!scanningFixture && norm.contains('scripts/ci/fixtures/')) continue;
    // M-2 : prose Markdown hors périmètre (contre-exemples documentés) ; tout
    // autre fichier texte est scanné (plus d'allowlist d'extension).
    if (_isProse(norm)) continue;

    List<int> bytes;
    try {
      bytes = ent.readAsBytesSync();
    } on FileSystemException {
      continue; // illisible
    }
    if (_looksBinary(bytes)) continue; // saut défensif des binaires
    final content = utf8.decode(bytes, allowMalformed: true);
    for (final p in _patterns) {
      if (p.re.hasMatch(content)) {
        findings.add('$norm :: ${p.label}');
      }
    }
  }

  if (findings.isEmpty) {
    stdout.writeln('gate:secrets OK — aucun secret detecte (AD-12, repli local).');
    exit(0);
  }
  stderr.writeln('gate:secrets VIOLATION AD-12 — secret(s) potentiel(s) committe(s):');
  for (final f in findings) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
