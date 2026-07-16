// Story ES-9.4 — AC7 : ZÉRO fuite transport/secret/endpoint/crypto dans les
// fichiers domaine de partage (AD-11/AD-12). Scan LOCAL au package.
//
// 🔴 R3-SECRET : insérer `const _ep = 'https://…'` ou une clé `AIzaSy…` /
// `sk-…` dans un fichier domaine fait ROUGIR ce test (et `gate:secrets`).
// NB : ce fichier scanne les FICHIERS DOMAINE, jamais lui-même. Runner R14.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _forbidden = <String, RegExp>{
  'URL/endpoint (http(s)://)': RegExp(r'https?://'),
  'clé Google (AIza…)': RegExp('AIza' r'[0-9A-Za-z_\-]{35}'),
  'clé OpenAI (sk-…)': RegExp(r'\bsk-[A-Za-z0-9]{16,}'),
  'clé AWS (AKIA…)': RegExp('AKIA' r'[0-9A-Z]{16}'),
  'clé privée PEM': RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
  'en-tête Bearer': RegExp(r'Bearer\s+[A-Za-z0-9._\-]{8,}'),
  // Import RÉEL de crypto (SHA côté domaine INTERDIT) — on ne scanne PAS les
  // mentions de prose en dartdoc (contre-exemples légitimes), seulement un
  // `import '…package:crypto…'`.
  'import crypto (SHA côté domaine INTERDIT)':
      RegExp('''import\\s+['"][^'"]*package:crypto'''),
};

// Les 8 fichiers domaine de partage ES-9.4 — le scan DOIT les couvrir.
const _sharingFiles = <String>{
  'z_study_membership.dart',
  'z_share_link.dart',
  'z_public_study_folder.dart',
  'z_study_folder_report.dart',
  'z_study_sharing_extension.dart',
  'z_study_sharing_acl.dart',
  'z_study_sharing_port.dart',
  'z_study_moderation_port.dart',
};

void main() {
  test('AC7 — aucun endpoint/clé/token/crypto dans lib/src/domain/*.dart', () {
    final dir = Directory('lib/src/domain');
    expect(dir.existsSync(), isTrue);

    final dartFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // Garde anti-scan-vacue : les 8 fichiers de partage doivent être présents.
    final names = dartFiles.map((f) => f.uri.pathSegments.last).toSet();
    for (final f in _sharingFiles) {
      expect(names.contains(f), isTrue,
          reason: 'le fichier domaine de partage $f doit être scanné');
    }

    final violations = <String>[];
    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      _forbidden.forEach((label, re) {
        if (re.hasMatch(content)) {
          violations.add('${file.path} : $label');
        }
      });
    }

    expect(violations, isEmpty,
        reason: 'fuite transport/secret détectée : ${violations.join(', ')}');
  });
}
