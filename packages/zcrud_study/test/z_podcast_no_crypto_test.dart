// Story ES-9.3 — AC4 : verrou ANTI-CRYPTO du seam podcast (D4, NFR-S10/SM-S7).
//
// `sourceHash` est une empreinte OPAQUE FOURNIE : le domaine ne hashe RIEN. Ce
// scan LOCAL au fichier asserte l'ABSENCE de tout hashing (`package:crypto`,
// `sha256`, `Digest`, `Hmac`, `zFnv1a32`). R3-I4 : ajouter
// `import 'package:crypto/crypto.dart';` + `sha256.convert(...)` dans le fichier
// domaine fait ROUGIR ce test (et ferait acquérir `crypto` au pubspec ⇒ arête,
// AC5 RED).
//
// NB : ce test scanne le FICHIER DOMAINE, jamais lui-même (ses propres regex
// contiennent volontairement les motifs). Runner R14 : `flutter test`.
//
// 🔴 STRIPPÉ (campagne dartdoc P0A) : AUCUN de ces motifs (`sha256`, `Digest`,
// `import package:crypto`…) n'est un VRAI secret — ce sont des identifiants de
// CODE dont la garde interdit l'usage réel, pas la mention en prose. Une
// dartdoc légitime doit pouvoir NOMMER ces symboles (« ne jamais faire
// `sha256.convert(...)` ici ») sans faire rougir la garde : tout le scan passe
// donc au source DÉPOUILLÉ des commentaires (`z_sources.strippedText`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart';

/// Motifs LITTÉRAUX de hashing interdits dans le seam (D4 : le domaine ne hashe
/// rien — l'empreinte est OPAQUE FOURNIE).
final _forbidden = <String, RegExp>{
  // La DIRECTIVE d'import (ce qu'injecte R3-I4), pas la prose : le dartdoc cite
  // `package:crypto` en backticks comme contre-exemple INTERDIT — motif légitime.
  'import package:crypto': RegExp('''import[ ]+['"]package:crypto'''),
  'sha256': RegExp(r'\bsha256\b'),
  'sha1/sha512/md5': RegExp(r'\b(?:sha1|sha512|md5)\b'),
  'Digest': RegExp(r'\bDigest\b'),
  'Hmac': RegExp(r'\bHmac\b'),
  'zFnv1a32': RegExp(r'\bzFnv1a32\b'),
};

void main() {
  test('AC4 — aucun hashing/crypto dans z_podcast_generation_port.dart', () {
    final file = File('lib/src/domain/z_podcast_generation_port.dart');
    expect(file.existsSync(), isTrue,
        reason: 'le fichier domaine ES-9.3 doit exister');

    final content = strippedText(file);
    final violations = <String>[];
    _forbidden.forEach((label, re) {
      if (re.hasMatch(content)) {
        violations.add(label);
      }
    });

    expect(violations, isEmpty,
        reason: 'crypto/hashing détecté dans le seam (D4 violé) : '
            '${violations.join(', ')}');
  });

  group('🔴 CONTRE-PREUVE — dépouillé ne rend pas la garde aveugle', () {
    test('un VRAI `sha256.convert(` en CODE reste détecté', () {
      final stripped = strippedLines(
        <String>['    final h = sha256.convert(bytes);'],
      ).join('\n');
      expect(_forbidden['sha256']!.hasMatch(stripped), isTrue);
    });

    test('la MÊME mention en COMMENTAIRE ne rougit PAS', () {
      final stripped = strippedLines(
        <String>['// jamais `sha256.convert(...)` ici (D4).'],
      ).join('\n');
      _forbidden.forEach((label, re) {
        expect(re.hasMatch(stripped), isFalse,
            reason: '🔴 $label : une mention en dartdoc ne doit PAS faire '
                'rougir la garde.');
      });
    });
  });
}
