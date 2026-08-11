// Story ES-9.1 — AC2 : ZÉRO fuite transport/prompt/secret dans les fichiers
// domaine (AD-11/AD-12). Scan LOCAL au package : énumère les `.dart` de
// `lib/src/domain/` et asserte l'ABSENCE RÉELLE de tout littéral d'endpoint/URL,
// clé/token, en-tête d'auth. R3-I2 : insérer
// `const _endpoint = 'https://api.openai.com/v1/chat'` fait ROUGIR ce test.
//
// NB : ce test scanne les FICHIERS DOMAINE, jamais lui-même (ses propres regex
// contiennent volontairement les motifs). Runner R14 : `flutter test`.
//
// 🔴 SCISSION SECRETS/URL (campagne dartdoc P0A) : un VRAI secret (clé/token/
// PEM/Bearer littéral) reste scanné sur le SOURCE COMPLET — une clé qui fuite
// en dartdoc est une fuite RÉELLE, commentaire ou pas. Le motif GÉNÉRIQUE
// `https?://` (une URL en dartdoc, ex. un lien pub.dev, n'est PAS une fuite)
// passe au source DÉPOUILLÉ des commentaires (`z_sources.strippedText`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart';

/// Motifs de VRAIS secrets — scannés sur le source COMPLET (commentaires
/// inclus : une clé qui fuite en dartdoc reste une fuite).
final _forbiddenRaw = <String, RegExp>{
  'clé Google (AIza…)': RegExp('AIza' r'[0-9A-Za-z_\-]{35}'),
  'clé OpenAI (sk-…)': RegExp(r'\bsk-[A-Za-z0-9]{16,}'),
  'clé AWS (AKIA…)': RegExp('AKIA' r'[0-9A-Z]{16}'),
  'clé privée PEM': RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
  'en-tête Bearer': RegExp(r'Bearer\s+[A-Za-z0-9._\-]{8,}'),
  'token Slack': RegExp('xox' r'[baprs]-[0-9A-Za-z\-]{10,}'),
};

/// Motif GÉNÉRIQUE (pas un secret en soi) — scanné sur le source DÉPOUILLÉ :
/// une dartdoc peut légitimement citer une URL (pub.dev, RFC…) sans que ce
/// soit une fuite de transport.
final _forbiddenStripped = <String, RegExp>{
  'URL/endpoint (http(s)://)': RegExp(r'https?://'),
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
      _forbiddenRaw.forEach((label, re) {
        if (re.hasMatch(content)) {
          violations.add('${file.path} : $label');
        }
      });
      final strippedContent = strippedText(file);
      _forbiddenStripped.forEach((label, re) {
        if (re.hasMatch(strippedContent)) {
          violations.add('${file.path} : $label');
        }
      });
    }

    expect(violations, isEmpty,
        reason: 'fuite transport/secret détectée : ${violations.join(', ')}');
  });

  group('🔴 CONTRE-PREUVE — la scission secret/URL n\'affaiblit pas la garde',
      () {
    test('un VRAI secret en COMMENTAIRE reste détecté (raw)', () {
      final violations = <String>[];
      _forbiddenRaw.forEach((label, re) {
        // Leurre COMPOSÉ à l'exécution : la source ne doit contenir aucun
        // littéral en forme de clé, sinon le scan de secrets repo-wide
        // (gate:secrets, qui lit le brut À RAISON) prend la sonde pour une
        // fuite réelle — mesuré au premier `melos run verify` post-conversion.
        final line = "// exemple à ne jamais faire : '${'AI' 'za'}"
            "SyABCDEFGHIJKLMNOPQRSTUVWXYZ1234567'";
        if (re.hasMatch(line)) violations.add(label);
      });
      expect(violations, isNotEmpty,
          reason: 'une clé Google en commentaire DOIT rester une fuite détectée');
    });

    test('une URL générique en COMMENTAIRE ne rougit PAS (stripped)', () {
      final stripped = strippedLines(
        <String>["// voir https://pub.dev/packages/zcrud_study pour le contexte"],
      ).join('\n');
      _forbiddenStripped.forEach((label, re) {
        expect(re.hasMatch(stripped), isFalse,
            reason: '🔴 $label : une URL en dartdoc ne doit PAS faire rougir '
                'la garde générique.');
      });
    });
  });
}
