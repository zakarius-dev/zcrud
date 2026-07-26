// CR-LEX-50 (🔴 BLOQUANT) — REPRODUCTION.
//
// L'échappement `[` → `\[` de l'ENCODEUR fabrique un délimiteur de bloc LaTeX
// (`\[…\]`, déclaré par `ZMarkdownBridges.latexBlock`) que le DÉCODEUR du MÊME
// codec consomme : `[1]` → `\[1\]` → embed `latexBlock` → `$$1$$`.
//
// La séquence corruptrice N'EXISTE PAS dans la source : elle est PRODUITE par
// le codec. C'est une incohérence interne encode/decode, pas une ambiguïté de
// source (ce qui distingue CR-50 de CR-48).
//
// ⚠️ Ces tests DOIVENT ROUGIR sur le code actuel. Ils deviendront les gardes
// mordantes après correction.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Concatène le texte inséré des ops (proxy sémantique).
String _plainText(List<Map<String, dynamic>> ops) =>
    ops.map((op) => op['insert']).whereType<String>().join();

/// Types d'embed présents dans [ops].
List<String> _embedTypes(List<Map<String, dynamic>> ops) => <String>[
      for (final op in ops)
        if (op['insert'] is Map<String, dynamic>)
          ...(op['insert'] as Map<String, dynamic>).keys,
    ];

void main() {
  // Le pont LaTeX est OBLIGATOIRE dès qu'un contenu porte une formule : c'est
  // la configuration réelle du consommateur lex.
  final codec = ZMarkdownCodec(bridges: ZMarkdownBridges.latex);

  group('CR-LEX-50 — l\'encodeur fabrique un délimiteur que le décodeur mange',
      () {
    test('§1 — `Texte [1] texte` : round-trip stable, zéro embed fabriqué', () {
      const source =
          'Voir la référence [1] du barème et le texte [art. 32] pour la '
          'valeur en douane.';

      // Étape 1 — le décodage de la SOURCE est propre : aucun embed.
      final ops1 = codec.decode(source);
      expect(
        _embedTypes(ops1),
        isEmpty,
        reason: 'la source ne contient aucun backslash : rien à ponter',
      );
      expect(_plainText(ops1), contains('[1]'));
      expect(_plainText(ops1), contains('[art. 32]'));

      // Étape 2 — l'encodeur échappe les crochets : `\[1\]`.
      final md1 = codec.encode(ops1)! as String;

      // Étape 3 — LE CŒUR DE LA CR : relire ce que l'on vient d'écrire ne doit
      // PAS fabriquer d'embed. `encode` et `decode` du MÊME codec doivent être
      // mutuellement cohérents.
      final ops2 = codec.decode(md1);
      expect(
        _embedTypes(ops2),
        isEmpty,
        reason: 'CR-50 : `\\[1\\]` produit par l\'encodeur est relu comme un '
            'latexBlock — la référence juridique devient une formule. '
            'Markdown intermédiaire : $md1',
      );

      // Étape 4 — le texte survit au second cycle (pas de `$$1$$`).
      final md2 = codec.encode(ops2)! as String;
      expect(md2, isNot(contains(r'$$')));
      final ops3 = codec.decode(md2);
      expect(_plainText(ops3), contains('[1]'));
      expect(_plainText(ops3), contains('[art. 32]'));
    });

    test('§2 — deux paires sur une même ligne : aucun embed fabriqué', () {
      const source = 'Cas [a] et cas [b] sur la même ligne.';
      final md1 = codec.encode(codec.decode(source))! as String;
      final ops2 = codec.decode(md1);
      expect(
        _embedTypes(ops2),
        isEmpty,
        reason: 'deux paires ⇒ deux latexBlock fabriqués. Markdown : $md1',
      );
    });

    test('§3 — note de bas de page `[^1]` : aucun embed fabriqué', () {
      const source = 'Une note de bas de page [^1] dans la phrase.';
      final md1 = codec.encode(codec.decode(source))! as String;
      expect(_embedTypes(codec.decode(md1)), isEmpty,
          reason: 'Markdown : $md1');
    });

    test('§4 — directive `:::lexia[Sources]` : aucun embed fabriqué', () {
      const source = ':::lexia[Sources]';
      final md1 = codec.encode(codec.decode(source))! as String;
      expect(_embedTypes(codec.decode(md1)), isEmpty,
          reason: 'Markdown : $md1');
    });

    test(
        '§5 — le placeholder `\\[embed:<type>\\]` est SA PROPRE victime : '
        'la dégradation ne doit PAS se composer', () {
      // Un embed non exprimable (aucun pont déclaré pour `chart`) dégrade en
      // placeholder textuel — perte BORNÉE et réputée STABLE.
      final ops0 = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'chart': 'donnee'},
        },
        <String, dynamic>{'insert': '\n'},
      ];
      final md1 = codec.encode(ops0)! as String;
      expect(md1, contains('embed:chart'));

      // Relu avec le pont LaTeX déclaré, le placeholder devient un latexBlock.
      final ops1 = codec.decode(md1);
      expect(
        _embedTypes(ops1),
        isEmpty,
        reason: 'CR-50 : le placeholder du codec est relu comme un latexBlock '
            '⇒ la dégradation SE COMPOSE. Markdown : $md1',
      );

      // Et le cycle suivant ne doit pas produire `$$embed:chart$$`.
      final md2 = codec.encode(ops1)! as String;
      expect(md2, isNot(contains(r'$$embed:chart$$')));
      expect(md2, contains('embed:chart'),
          reason: 'le placeholder doit rester STABLE (point fixe)');
    });

    test(
        '§7 — un BACKSLASH littéral ne referme pas un crochet échappé '
        '(garde `(?<!\\\\)` des délimiteurs de pont)', () {
      // Ajouté à la correction : ne plus échapper `]` supprime la source
      // PRINCIPALE de `\]`, mais pas la SEULE — un backslash littéral est doublé
      // par l'encodeur (`a\]` → `a\\]`), et `\]` réapparaît alors à l'intérieur.
      // Sans la garde `(?<!\\)` posée sur le délimiteur fermant, CR-50 se
      // rejouerait à l'identique par ce chemin.
      final ops0 = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'Voir [1] puis a\\] la fin.\n'},
      ];
      final md1 = codec.encode(ops0)! as String;
      final ops2 = codec.decode(md1);
      expect(
        _embedTypes(ops2),
        isEmpty,
        reason: 'CR-50 (voie backslash) : `\\[1] … a\\\\]` fabrique un '
            'latexBlock si le délimiteur fermant n\'est pas gardé. '
            'Markdown : $md1',
      );
      expect(_plainText(ops2), contains('[1]'));
      expect(_plainText(ops2), contains('a\\]'));
    });

    test('§6 — contrôle NÉGATIF : une vraie formule LaTeX reste pontée', () {
      // La correction ne doit PAS détruire le pont : `$$…$$` (et une source
      // portant réellement `\[…\]` écrite par un humain) restent du LaTeX.
      final ops = codec.decode(r'Formule $$E=mc^2$$ dans le texte.');
      expect(_embedTypes(ops), contains('latexBlock'),
          reason: 'le pont LaTeX bloc doit rester fonctionnel');
      final md = codec.encode(ops)! as String;
      expect(md, contains(r'$$E=mc^2$$'));
    });
  });
}
