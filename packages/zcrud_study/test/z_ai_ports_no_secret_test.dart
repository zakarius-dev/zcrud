// Story ES-9.1 — AC2 : ZÉRO fuite transport/prompt/secret dans les fichiers
// domaine (AD-11/AD-12). Scan LOCAL au package : énumère les `.dart` de
// `lib/src/domain/` et asserte l'ABSENCE RÉELLE de tout littéral d'endpoint/URL,
// clé/token, en-tête d'auth. R3-I2 : insérer
// `const _endpoint = 'https://api.openai.com/v1/chat'` fait ROUGIR ce test.
//
// NB : ce test scanne les FICHIERS DOMAINE, jamais lui-même (ses propres regex
// contiennent volontairement les motifs). Runner R14 : `flutter test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Motifs STRUCTURELS de fuite (endpoints/clés/tokens/PEM/auth). On ne scanne
/// PAS des mots de prose (`prompt`, `endpoint`, `SSE`) — ils apparaissent
/// légitimement en dartdoc comme contre-exemples ; on scanne des LITTÉRAUX.
final _forbidden = <String, RegExp>{
  'URL/endpoint (http(s)://)': RegExp(r'https?://'),
  'clé Google (AIza…)': RegExp('AIza' r'[0-9A-Za-z_\-]{35}'),
  'clé OpenAI (sk-…)': RegExp(r'\bsk-[A-Za-z0-9]{16,}'),
  'clé AWS (AKIA…)': RegExp('AKIA' r'[0-9A-Z]{16}'),
  'clé privée PEM': RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
  'en-tête Bearer': RegExp(r'Bearer\s+[A-Za-z0-9._\-]{8,}'),
  'token Slack': RegExp('xox' r'[baprs]-[0-9A-Za-z\-]{10,}'),
};

void main() {
  test('AC2 — aucun endpoint/clé/token dans lib/src/domain/*.dart', () {
    final dir = Directory('lib/src/domain');
    expect(dir.existsSync(), isTrue,
        reason: 'lib/src/domain/ doit exister (premier dossier domaine ES-9.1)');

    final dartFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // Au moins les 4 fichiers ES-9.1 + le seam podcast ES-9.3 (garde contre un
    // scan vacue à 0 fichier).
    expect(dartFiles.length, greaterThanOrEqualTo(5),
        reason: 'les 4 fichiers domaine ES-9.1 + le seam podcast ES-9.3 '
            'doivent être scannés');

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
