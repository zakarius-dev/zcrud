// CR-LEX-45 (MAJEUR) — REPRODUCTION.
//
// Affirmation à MESURER (registre lex_douane, §CR-45) : un tableau PRÉCÉDÉ de
// contenu DÉCALE l'attribut du bloc SUIVANT — le titre qui suit le tableau est
// DÉTRUIT (`## ` vide AVANT le tableau, texte nu APRÈS).
//
// Cible : `z_markdown_codec.dart` → `customEmbedHandlers['table']`
// (coupure forcée `out..write('\n\n')..write(zRenderTableGuaranteed(...))`).
//
// Discipline R3 : ce fichier ne corrige RIEN. Il épingle l'invariant réclamé et
// doit ROUGIR sur le code actuel si la CR est exacte. Il restera comme garde
// après correction (ré-injecter la régression doit le refaire rougir).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Round-trip Markdown → Delta neutre → Markdown, tel que l'exerce lex_douane.
String _roundTrip(String source) {
  final codec = ZMarkdownCodec(bridges: ZMarkdownBridges.latex);
  final ops = codec.decode(source);
  return (codec.encode(ops) as String?) ?? '';
}

void main() {
  group('CR-LEX-45 — attribut de bloc décalé par un tableau non initial', () {
    test('paragraphe → tableau → titre : le titre survit', () {
      const source = '''
Un paragraphe introductif avant le tableau.

| Régime | Taux |
| --- | --- |
| Transit | 0 % |

## Conséquences de la mainlevée
''';

      final out = _roundTrip(source);
      // ignore: avoid_print
      print('--- CR-45 heading round-trip ---\n$out\n--- fin ---');

      // 1) Le titre doit rester un titre PORTANT son texte.
      expect(
        out,
        contains('## Conséquences de la mainlevée'),
        reason: 'Le titre `## …` doit survivre au round-trip avec son texte.',
      );
      // 2) Aucun marqueur de titre VIDE ne doit être émis.
      expect(
        RegExp(r'^#{1,6}\s*$', multiLine: true).hasMatch(out),
        isFalse,
        reason: 'Un `##` sur une ligne vide trahit un attribut de bloc décalé.',
      );
      // 3) Le titre doit venir APRÈS le tableau, pas avant.
      final idxTable = out.indexOf('| Régime');
      final idxHeading = out.indexOf('## Conséquences');
      expect(idxTable, greaterThanOrEqualTo(0));
      expect(
        idxHeading,
        greaterThan(idxTable),
        reason: 'Le titre suit le tableau dans la source ; il doit le suivre '
            'aussi dans la sortie.',
      );
    });

    test('paragraphe → tableau → blockquote : la citation survit', () {
      const source = '''
Un paragraphe introductif avant le tableau.

| Régime | Taux |
| --- | --- |
| Transit | 0 % |

> Une citation après le tableau.
''';

      final out = _roundTrip(source);
      // ignore: avoid_print
      print('--- CR-45 blockquote round-trip ---\n$out\n--- fin ---');

      expect(
        out,
        contains('> Une citation après le tableau.'),
        reason: 'Le blockquote doit survivre avec son texte.',
      );
      expect(
        RegExp(r'^>\s*$', multiLine: true).hasMatch(out),
        isFalse,
        reason: 'Un `>` vide trahit un attribut de bloc décalé.',
      );
    });

    test('paragraphe → tableau → puce : la puce survit', () {
      const source = '''
Un paragraphe introductif avant le tableau.

| Régime | Taux |
| --- | --- |
| Transit | 0 % |

- Un point de liste après le tableau.
''';

      final out = _roundTrip(source);
      // ignore: avoid_print
      print('--- CR-45 bullet round-trip ---\n$out\n--- fin ---');

      expect(
        out,
        contains('- Un point de liste après le tableau.'),
        reason: 'La puce doit survivre avec son texte.',
      );
      expect(
        RegExp(r'^-\s*$', multiLine: true).hasMatch(out),
        isFalse,
        reason: 'Un `-` vide trahit un attribut de bloc décalé.',
      );
    });

    // CONTRÔLE NÉGATIF annoncé VERT par la CR : un tableau EN TÊTE de document
    // n'a aucun `\n` antérieur à décaler. Ce cas doit passer AVANT comme APRÈS
    // correction — s'il rougissait, la cause racine décrite serait fausse.
    test('contrôle négatif — tableau en tête puis blockquote : sans perte', () {
      const source = '''
| Régime | Taux |
| --- | --- |
| Transit | 0 % |

> Une citation après le tableau initial.
''';

      final out = _roundTrip(source);
      // ignore: avoid_print
      print('--- CR-45 contrôle négatif ---\n$out\n--- fin ---');

      expect(out, contains('> Une citation après le tableau initial.'));
    });
  });
}
