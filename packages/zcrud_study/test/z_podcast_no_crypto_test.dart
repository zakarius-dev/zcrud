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
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

    final content = file.readAsStringSync();
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
}
