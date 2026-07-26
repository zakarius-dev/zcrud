// CR-LEX-47 (MAJEUR) — REPRO : un retour souple DANS un blockquote recolle les
// mots SANS espace et détruit l'emphase qui ouvre la ligne suivante.
//
// Discipline R3 : ce fichier doit ROUGIR sur le code actuel pour la raison
// décrite par la CR, et rester en garde après correction.
//
// Contrôle NÉGATIF inclus : le MÊME retour souple HORS blockquote doit rester
// VERT — c'est lui qui isole la cause au blockquote.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Concatène le texte inséré (parties `String`) des ops.
String _plainText(List<Map<String, dynamic>> ops) =>
    ops.map((op) => op['insert']).whereType<String>().join();

void main() {
  const codec = ZMarkdownCodec();

  // Exemple EXACT de la CR (apostrophe typographique comprise).
  const String horsCitation = 'La remise est déductible seulement si elle est\n'
      '*acquise* au moment de l’évaluation.';
  const String dansCitation = '> Une remise n’est déductible que si elle est\n'
      '> *acquise* au moment de l’évaluation.';

  group('CR-LEX-47 — retour souple + emphase', () {
    test('CONTRÔLE NÉGATIF (hors blockquote) — l’espace survit', () {
      final ops = codec.decode(horsCitation);
      final String plain = _plainText(ops);
      expect(
        plain,
        isNot(contains('estacquise')),
        reason: 'les deux mots ne doivent jamais être recollés',
      );
      expect(
        plain,
        anyOf(contains('est acquise'), contains('est\nacquise')),
        reason: 'le retour souple doit laisser une séparation',
      );

      final String md = codec.encode(ops)! as String;
      expect(
        md,
        isNot(contains('est_acquise_')),
        reason: 'un `_` intra-mot n’ouvre aucune emphase en CommonMark',
      );
    });

    test('DANS un blockquote — l’espace doit survivre IDENTIQUEMENT', () {
      final ops = codec.decode(dansCitation);
      final String plain = _plainText(ops);
      expect(
        plain,
        isNot(contains('estacquise')),
        reason: 'CR-47 §1 : le mot est recollé (est + acquise → estacquise)',
      );
      expect(
        plain,
        anyOf(contains('est acquise'), contains('est\nacquise')),
        reason: 'CR-47 : la fusion du retour souple doit insérer la séparation',
      );
    });

    test('DANS un blockquote — l’italique survit au round-trip', () {
      final ops = codec.decode(dansCitation);
      expect(
        ops.any((op) {
          final Object? a = op['attributes'];
          return a is Map && a['italic'] == true;
        }),
        isTrue,
        reason: 'l’emphase ouvrant la 2e ligne du blockquote doit être décodée',
      );

      final String md = codec.encode(ops)! as String;
      expect(
        md,
        isNot(contains('est_acquise_')),
        reason: 'CR-47 §2 : `_` intra-mot → italique DÉTRUITE, sans retour',
      );
      expect(
        md,
        anyOf(contains('_acquise_'), contains('*acquise*')),
        reason: 'l’emphase doit être ré-émise en délimiteur ouvrant',
      );
    });
  });
}
