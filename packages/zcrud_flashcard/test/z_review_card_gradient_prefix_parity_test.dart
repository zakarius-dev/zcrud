/// ÉGALITÉ STRICTE entre le préfixe de clé de dégradé RECOPIÉ par ce paquet
/// (`kZFlashcardReviewTypeGradientKeyPrefix`) et celui que déclare la carte de
/// flashcard de liste (`kZFlashcardTypeGradientKeyPrefix`, `zcrud_study`).
///
/// Pourquoi une garde de SOURCE et non un import : l'arête va de
/// `zcrud_study` vers `zcrud_flashcard`, jamais l'inverse (AD-1) — importer la
/// constante d'en face créerait un cycle. Le préfixe est donc RECOPIÉ, et une
/// valeur recopiée n'a de sens que tant qu'une garde la compare à l'originale.
/// Patron repris de `zcrud_themes/test/z_socle_gradient_parity_test.dart`.
///
/// 🔴 Ce qu'une valeur figée dans ce test ne prouverait PAS : elle comparerait
/// ce paquet à une COPIE, et resterait verte le jour où le socle change. La
/// source réelle est donc lue à chaque exécution, et l'extraction est
/// FAILLIBLE À VOIX HAUTE : `_parsePrefix` lève plutôt que de rendre une chaîne
/// vide, pour qu'un renommage fasse rougir au lieu de rendre la garde creuse.
///
/// La morsure est prouvée DES DEUX CÔTÉS : le diff est une fonction pure de
/// (valeur recopiée, texte de la source d'en face), et les contre-preuves
/// altèrent tantôt l'une, tantôt l'autre. Muter le texte en mémoire évite
/// d'écrire dans `zcrud_study`, dont ce paquet n'est pas le rédacteur.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

import 'support/z_sources.dart' as zsrc;

/// Chemin, relatif à la racine du monorepo, du fichier qui déclare le préfixe
/// faisant foi.
const String kZListCardSeamPath =
    'packages/zcrud_study/lib/src/presentation/z_default_flashcard_card.dart';

/// Le texte de la carte de liste, lu sur disque.
///
/// Lève si le fichier a été déplacé : une garde qui ne trouve plus sa source
/// doit rougir, jamais se taire.
String _readListCardSource() {
  final File file = File('${zsrc.repoRoot().path}/$kZListCardSeamPath');
  if (!file.existsSync()) {
    throw StateError(
      'Carte de liste introuvable : ${file.path}. La garde ne mesure plus '
      'rien — corrigez kZListCardSeamPath.',
    );
  }
  return file.readAsStringSync();
}

/// Le préfixe déclaré par la carte de liste, extrait de [source].
String _parsePrefix(String source) {
  final RegExpMatch? m = RegExp(
    r"const\s+String\s+kZFlashcardTypeGradientKeyPrefix\s*=\s*'([^']*)'\s*;",
  ).firstMatch(zsrc.stripLines(source.split('\n')).join('\n'));
  if (m == null) {
    throw StateError(
      'Déclaration `kZFlashcardTypeGradientKeyPrefix` introuvable : la garde '
      'ne mesure plus rien.',
    );
  }
  return m.group(1)!;
}

/// La clé que la carte de liste COMPOSE réellement, extraite de [source].
///
/// Sans elle, la garde comparerait deux constantes que plus personne
/// n'interpole : le préfixe pourrait rester égal pendant que la carte de liste
/// forme sa clé autrement.
String _parseComposedKeyExpression(String source) {
  final RegExpMatch? m = RegExp(
    r"'\$kZFlashcardTypeGradientKeyPrefix(\$\w+)'",
  ).firstMatch(zsrc.stripLines(source.split('\n')).join('\n'));
  if (m == null) {
    throw StateError(
      'La carte de liste ne compose plus sa clé par interpolation du préfixe : '
      'la garde ne mesure plus rien.',
    );
  }
  return m.group(1)!;
}

/// Les divergences entre [copied] et le préfixe déclaré dans [listCardSource].
/// Liste vide ⇔ **égalité stricte**.
List<String> zPrefixParityDiff(String copied, String listCardSource) {
  final String reference = _parsePrefix(listCardSource);
  return <String>[
    if (copied != reference)
      "préfixe recopié '$copied' ≠ préfixe déclaré '$reference'",
  ];
}

void main() {
  group('préfixe de clé de dégradé — parité de SOURCE avec la carte de liste',
      () {
    test("l'extraction aboutit, et le préfixe lu est non vide", () {
      // Non-vacuité : sans cette assertion, un renommage côté carte de liste
      // rendrait la garde suivante muette au lieu de la faire rougir.
      expect(_parsePrefix(_readListCardSource()), isNotEmpty);
    });

    test('le préfixe RECOPIÉ par ce paquet EST celui de la carte de liste', () {
      expect(
        zPrefixParityDiff(
          kZFlashcardReviewTypeGradientKeyPrefix,
          _readListCardSource(),
        ),
        isEmpty,
        reason: 'Les deux cartes doivent se piloter avec un seul résolveur : '
            'toute divergence rend le format documenté inopérant en session.',
      );
    });

    test('la carte de liste compose bien sa clé PAR interpolation du préfixe',
        () {
      expect(_parseComposedKeyExpression(_readListCardSource()), '\$typeName');
    });
  });

  group('la garde mord DU CÔTÉ DE LA CARTE DE LISTE (source mutée en mémoire)',
      () {
    test('une valeur de préfixe changée', () {
      final String mute = _readListCardSource().replaceFirst(
        "kZFlashcardTypeGradientKeyPrefix = 'flashcard.type.'",
        "kZFlashcardTypeGradientKeyPrefix = 'carte.type.'",
      );
      expect(mute, isNot(_readListCardSource()), reason: 'mutation non appliquée');
      expect(
        zPrefixParityDiff(kZFlashcardReviewTypeGradientKeyPrefix, mute),
        isNotEmpty,
      );
    });

    test('une déclaration renommée LÈVE, au lieu de rendre la garde creuse',
        () {
      final String mute = _readListCardSource().replaceAll(
        'kZFlashcardTypeGradientKeyPrefix',
        'kZFlashcardTypeGradientKeyPrefixRenomme',
      );
      expect(mute, isNot(_readListCardSource()), reason: 'mutation non appliquée');
      expect(() => _parsePrefix(mute), throwsStateError);
      expect(() => _parseComposedKeyExpression(mute), throwsStateError);
    });

    test('une interpolation défaite LÈVE', () {
      final String mute = _readListCardSource().replaceFirst(
        r"'$kZFlashcardTypeGradientKeyPrefix$typeName'",
        "'flashcard.type.' + typeName",
      );
      expect(mute, isNot(_readListCardSource()), reason: 'mutation non appliquée');
      expect(() => _parseComposedKeyExpression(mute), throwsStateError);
    });
  });

  group('la garde mord DU CÔTÉ DE CE PAQUET (valeur recopiée mutée)', () {
    test('un préfixe recopié divergent', () {
      expect(
        zPrefixParityDiff('flashcard.kind.', _readListCardSource()),
        isNotEmpty,
      );
    });

    test('un préfixe recopié VIDE — le piège du « plus de préfixe du tout »',
        () {
      expect(zPrefixParityDiff('', _readListCardSource()), isNotEmpty);
    });

    test('un préfixe recopié sans son point final', () {
      expect(
        zPrefixParityDiff('flashcard.type', _readListCardSource()),
        isNotEmpty,
      );
    });
  });
}
