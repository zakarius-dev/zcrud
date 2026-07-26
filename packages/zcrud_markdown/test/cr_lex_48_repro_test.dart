// CR-LEX-48 — GARDE (issue du fichier de REPRODUCTION, corrigé le 2026-07-26).
//
// Affirmation de la CR : `ZMarkdownEmbedBridge` n'a AUCUNE garde au DÉCODAGE.
// `escapedCharacters` protège l'ÉCRITURE (un texte ordinaire est réécrit `\$`),
// mais un markdown SOURCE — écrit à la main ou produit par un générateur — ne
// contient pas de `$` échappé. Au décodage, rien ne refusait la correspondance :
// `de 5 $ à 9 $` devenait un embed `latex` de charge `" à 9 "`. MESURÉ, CONFIRMÉ.
//
// ⚠️ CONVERSION REPRO → GARDE (à consigner) : le fichier de reproduction
// asseyait, DANS LE MÊME test, la MESURE du défaut (`expect(charge, ' à 9 ')`)
// ET l'invariant réclamé (`expect(charge, isNull)`). Les deux sont mutuellement
// exclusifs : ce fichier ne POUVAIT pas devenir vert. Les mesures qui épinglent
// le comportement FAUTIF ont donc été remplacées par les oracles CORRIGÉS ; les
// invariants réclamés par la CR, eux, sont conservés MOT POUR MOT. Chacun d'eux
// rougissait avant correction (mesuré) et rougit encore si l'on retire
// `accepts` des ponts de `ZMarkdownBridges` (mordant prouvé).
//
// L'oracle décisif n'est PAS une comparaison de chaînes : la CR souligne que le
// round-trip `markdown → Delta → markdown` restituait la phrase octet pour
// octet. Seule l'inspection du Delta intermédiaire — celui que consomme
// `ZMarkdownField` — exposait la corruption. Ce fichier asserte donc sur le
// Delta.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

final ZMarkdownCodec avecLatex =
    ZMarkdownCodec(bridges: ZMarkdownBridges.latex);

/// Charge du PREMIER embed de [type] rencontré, ou `null`.
Object? _embedData(List<Map<String, dynamic>> ops, String type) {
  for (final op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map && insert.containsKey(type)) return insert[type];
  }
  return null;
}

/// Toutes les charges d'embed de [type] (pour compter vraies/fausses formules).
List<Object?> _allEmbedData(List<Map<String, dynamic>> ops, String type) {
  final out = <Object?>[];
  for (final op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map && insert.containsKey(type)) out.add(insert[type]);
  }
  return out;
}

String _plain(List<Map<String, dynamic>> ops) =>
    ops.map((op) => op['insert']).whereType<String>().join();

/// Heuristique « ressemble à du LaTeX » utilisée comme ORACLE de la CR : une
/// charge sans commande `\…`, sans opérateur ni exposant/indice, encadrée
/// d'espaces, n'est pas une formule — c'est un fragment de phrase.
bool _ressembleADuLatex(Object? data) {
  final s = data is String ? data : '$data';
  if (s.trim().isEmpty) return false;
  return RegExp(r'\\[a-zA-Z]+|[\^_{}=+*/<>]').hasMatch(s);
}

void main() {
  group('CR-LEX-48 — garde au DÉCODAGE (`accepts`)', () {
    test('`de 5 \$ à 9 \$` : un MONTANT ne devient PAS un embed `latex`', () {
      const source = 'La redevance varie de 5 \$ à 9 \$ selon le tonnage.';

      final ops = avecLatex.decode(source);

      // INVARIANT RÉCLAMÉ par la CR (conservé mot pour mot) : un markdown source
      // sans `$` échappé ne doit pas fabriquer de formule à partir d'un montant.
      expect(
        _embedData(ops, 'latex'),
        isNull,
        reason: 'CR-LEX-48 : aucune garde au décodage ne refuse la '
            'correspondance ; un montant devient une formule',
      );

      // Et le REFUS préserve le texte LITTÉRAL — il ne mange rien. C'est la
      // seconde moitié de la garde : `InlineSyntax.tryMatch` ne consomme rien
      // quand `onMatch` rend `false`, et `InlineParser.parse` reboucle à la même
      // position (boucle infinie) si le refus n'avance pas lui-même.
      expect(_plain(ops).trim(), source);
    });

    test('`de 100 \$CAD à 250 \$` : même refus, charge « CAD à 250 »', () {
      const source =
          'La caution passe de 100 \$CAD à 250 \$ pour un entrepôt.';

      final ops = avecLatex.decode(source);

      expect(
        _embedData(ops, 'latex'),
        isNull,
        reason: 'CR-LEX-48 : la charge « CAD à 250 » ne ressemble en rien à '
            'du LaTeX, rien ne permettait de la refuser',
      );
      expect(_plain(ops).trim(), source);
    });

    test(
        'la corruption N\'EST PLUS là — et le texte survit au round-trip '
        '(l\'oracle de chaîne, lui, était AVEUGLE)', () {
      const source = 'La redevance varie de 5 \$ à 9 \$ selon le tonnage.';

      final ops = avecLatex.decode(source);
      final retour = avecLatex.encode(ops)! as String;

      // C'est CE point qui rendait la CR dangereuse : un hôte qui valide sa
      // migration par comparaison de chaînes concluait « aucune perte » alors
      // que le Delta portait un embed. Le Delta est désormais propre…
      expect(
        _embedData(ops, 'latex'),
        isNull,
        reason: 'seule l\'inspection du Delta exposait la corruption',
      );
      // …et le texte revient intact au cycle suivant. Le markdown intermédiaire
      // porte `\$` (échappement dû à `escapedCharacters`), ce qui est la forme
      // CORRECTE : c'est elle qui empêche le pont de relire un montant.
      expect(retour, contains(r'\$'));
      expect(_plain(avecLatex.decode(retour)).trim(), source);
    });

    test('`note_ia_mixte` : les 4 VRAIES formules survivent, la FAUSSE non', () {
      const source = '''
La valeur en douane suit \$V = P + F + A\$ pour une importation.
On note \$\\frac{a}{b}\$ et \$x^2\$ dans le barème.
La redevance varie de 5 \$ à 9 \$ selon le tonnage.
Enfin \$\\alpha + \\beta\$ clôt le calcul.
''';

      final ops = avecLatex.decode(source);
      final charges = _allEmbedData(ops, 'latex');

      // INVARIANT RÉCLAMÉ : tout embed `latex` produit depuis un markdown
      // source doit ressembler à du LaTeX.
      expect(
        charges.where(_ressembleADuLatex).length,
        charges.length,
        reason: 'CR-LEX-48 : le pont était TOUT ou RIEN — aucune garde ne '
            'permettait de refuser la charge qui n\'est pas une formule',
      );
      // Les VRAIES formules ne doivent pas être sacrifiées au passage.
      expect(charges, hasLength(4));
      expect(charges, contains('V = P + F + A'));
      expect(charges, contains(r'\frac{a}{b}'));
      expect(charges, contains('x^2'));
      expect(charges, contains(r'\alpha + \beta'));
      // Et le montant reste du TEXTE.
      expect(_plain(ops), contains('de 5 \$ à 9 \$ selon le tonnage.'));
    });

    test('AD-10 — un prédicat hôte qui LÈVE vaut REFUS, jamais un crash', () {
      final codec = ZMarkdownCodec(
        bridges: <ZMarkdownEmbedBridge>[
          ZMarkdownEmbedBridge(
            embedType: 'latex',
            pattern: RegExp(r'(?<!\\)\$([^$\n]+?)(?<!\\)\$'),
            toMarkdown: (data) => '\$$data\$',
            escapedCharacters: const <String>{r'$'},
            accepts: (_) => throw StateError('prédicat hôte défaillant'),
          ),
        ],
      );

      const source = 'Soit \$x^2\$ le carré.';
      final ops = codec.decode(source);
      expect(_embedData(ops, 'latex'), isNull,
          reason: 'une exception du prédicat doit valoir REFUS');
      expect(_plain(ops).trim(), source,
          reason: 'le texte littéral est PRÉSERVÉ — perte bornée (AD-10)');
    });

    test('`accepts` non déclaré ⇒ comportement INCHANGÉ (AD-57, opt-in)', () {
      final codec = ZMarkdownCodec(
        bridges: <ZMarkdownEmbedBridge>[
          ZMarkdownEmbedBridge(
            embedType: 'latex',
            pattern: RegExp(r'(?<!\\)\$([^$\n]+?)(?<!\\)\$'),
            toMarkdown: (data) => '\$$data\$',
            escapedCharacters: const <String>{r'$'},
          ),
        ],
      );

      // Sans garde déclarée, le pont reste TOUT ou RIEN : c'est le défaut
      // historique, et il ne change PAS pour un hôte qui n'a rien demandé.
      final ops = codec.decode('La redevance varie de 5 \$ à 9 \$ selon.');
      expect(_embedData(ops, 'latex'), ' à 9 ');
    });
  });

  group('CR-LEX-48 — le réglage INVERSE ne sauve rien (pas de pont)', () {
    test('sans pont, le montant est intact — mais le LaTeX est détruit', () {
      const sansPont = ZMarkdownCodec();

      // Le montant survit : c'est le seul réglage correct pour lui.
      final montant = sansPont.decode(
        'La redevance varie de 5 \$ à 9 \$ selon le tonnage.',
      );
      expect(_embedData(montant, 'latex'), isNull);
      expect(_plain(montant), contains('5 \$'));

      // Mais la formule, elle, n'est plus une formule : elle reste du TEXTE, et
      // l'échappement de l'encodeur la déforme au premier cycle.
      final formule = sansPont.decode('Soit \$\\frac{a}{b}\$ le rapport.');
      expect(_embedData(formule, 'latex'), isNull,
          reason: 'sans pont, aucune formule n\'est reconnue');

      final cycle = sansPont.encode(formule)! as String;
      expect(
        cycle,
        contains(r'\frac'),
        reason: 'CR-LEX-48 : sans pont, `\\frac` est ré-échappé en `\\\\frac` '
            '— aucun réglage du pont n\'est correct pour un corpus mixte',
      );
    });
  });
}
