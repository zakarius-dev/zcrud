// CR-IFFD-69 — la corruption du LaTeX bloc vivait sur le chemin SANS pont.
//
// Mesuré avant correction (reproduction de la mesure de l'hôte, au caractère
// près) : `ZMarkdownCodec()` — la construction PAR DÉFAUT, donc le chemin
// exposé au sens de CR-56 — altérait `$$\int_0^1 x\,dx$$` en
// `$$\\int\_0^1 x,dx$$` au premier cycle `decode → encode` :
//   - au DÉCODAGE, la résolution des échappements CommonMark détruisait `\,`
//     (virgule = ponctuation ASCII) — perte IRRÉVERSIBLE ;
//   - à l'ENCODAGE, l'échappement inline doublait `\` et échappait `_`.
// Avec `ZMarkdownBridges.latex`, rien de tout cela : le pont met la formule
// hors de portée des deux mécanismes.
//
// FORME RETENUE : bouclier littéral LaTeX sur le chemin sans pont — les MÊMES
// motifs et la MÊME garde que `ZMarkdownBridges.latex`, rejoués en mode texte
// LITTÉRAL (jamais d'embed), des DEUX côtés (échappement et résolution).
// Actif uniquement quand `bridges` est vide : un hôte qui déclare des ponts ne
// bouge pas d'un octet (IFFD a un tripwire sur la présence du pont).
//
// Formes écartées, chiffres à l'appui (cf. rapport du lot) :
//   - pont par défaut : 8/9 textes à `$` non mathématiques voyaient leurs
//     octets persistés changer (`$` → `\$`) et `total $x$ affiché` devenait un
//     EMBED — cassant le rendu d'un hôte sans `EmbedBuilder` LaTeX ;
//   - refus/throw : contraire à AD-10 (gardes « jamais de throw » au décodage)
//     et sans effet sur la donnée en release.
//
// DISCIPLINE R3 : chaque garde 🔴 a été prouvée MORDANTE en réinjectant la
// régression EXACTE (bouclier court-circuité : `_latexShield` rendu vide) —
// rouge d'ASSERTION, puis restauration par copie et re-vert.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

const ZMarkdownCodec sansPont = ZMarkdownCodec();
final ZMarkdownCodec avecLatex = ZMarkdownCodec(bridges: ZMarkdownBridges.latex);

/// Le cycle de persistance réel d'un hôte : Markdown → ops (éditeur) →
/// Markdown. Le `\n` final ajouté par l'encodeur est hors sujet (l'hôte de la
/// CR comparait de même) : on compare TRIMMÉ, mais uniquement à droite du
/// contenu.
String _cycle(ZMarkdownCodec codec, String markdown) =>
    (codec.encode(codec.decode(markdown))! as String).trimRight();

String _plain(List<Map<String, dynamic>> ops) =>
    ops.map((op) => op['insert']).whereType<String>().join();

bool _hasAnyEmbed(List<Map<String, dynamic>> ops) =>
    ops.any((op) => op['insert'] is Map);

void main() {
  group('CR-IFFD-69 🔴 — le chemin SANS pont ne corrompt plus une formule', () {
    // Le corpus de la CR, mot pour mot, plus les formes jumelles.
    const List<String> formules = <String>[
      r'$$\int_0^1 x\,dx$$',
      r'$$E = mc^2$$',
      r'$$\frac{a}{b}$$',
      r'$$\sum_{i=1}^{n} x_i$$',
      r'formule $x^2$ ici',
      r'$\ce{H2O}$',
      r'soit \(a+b\) fin',
      r'\[\frac{1}{2}\]',
    ];

    for (final source in formules) {
      test('cycle sans pont — « $source » intact', () {
        expect(_cycle(sansPont, source), source,
            reason: 'CR-IFFD-69 : le chemin exposé altérait la formule '
                '(antislash doublé, `\\,` détruit)');
      });
    }

    test('🔴 la mesure de la CR, au caractère près : la corruption a disparu',
        () {
      final String sortie = _cycle(sansPont, r'$$\int_0^1 x\,dx$$');
      expect(sortie, isNot(r'$$\\int\_0^1 x,dx$$'),
          reason: 'la sortie corrompue EXACTE mesurée par IFFD');
      expect(sortie, r'$$\int_0^1 x\,dx$$');
    });

    test('🔴 la perte IRRÉVERSIBLE est stoppée au DÉCODAGE déjà : '
        '`\\,` survit dans les ops', () {
      // La moitié décodage seule : avant correction, `\,` était résolu en `,`
      // par le parseur (perte de donnée AVANT même l\'encodage).
      final ops = sansPont.decode(r'$$\int_0^1 x\,dx$$');
      expect(_plain(ops), contains(r'\,'),
          reason: 'l\'espace fine LaTeX `\\,` doit survivre au décodage');
    });

    test('AD-57 tenu : le bouclier n\'émet JAMAIS d\'embed', () {
      for (final source in formules) {
        expect(_hasAnyEmbed(sansPont.decode(source)), isFalse,
            reason: 'sans pont, « $source » doit rester du TEXTE — un hôte '
                'sans EmbedBuilder LaTeX ne doit voir aucun insert nouveau');
      }
    });

    test('idempotence : cinq cycles sont un point fixe', () {
      for (final source in formules) {
        var md = source;
        for (var i = 0; i < 5; i++) {
          md = _cycle(sansPont, md);
        }
        expect(md, source, reason: source);
      }
    });
  });

  group('CR-IFFD-69 — un `\$` NON mathématique ne bouge pas d\'un octet', () {
    // Le risque de régression le plus sournois : le bouclier partage la garde
    // `zLatexPayloadLooksLikeFormula` avec les ponts — un prix n'est pas une
    // région, et ses octets persistés restent STRICTEMENT ceux d'avant.
    const List<String> prix = <String>[
      r'prix de 5$ à 9$ environ',
      r'5$ et 10$',
      r'de 100$$ à 200$$',
      r'montant en $ US',
      r'$5 et $9',
      r'USD $100.50 payable',
      r'le symbole $ seul',
    ];

    for (final source in prix) {
      test('« $source » : cycle identique, aucun embed, aucun `\\\$`', () {
        final ops = sansPont.decode(source);
        expect(_hasAnyEmbed(ops), isFalse, reason: source);
        final String sortie = _cycle(sansPont, source);
        expect(sortie, source,
            reason: 'les octets persistés d\'un texte à `\$` ordinaire ne '
                'doivent PAS changer');
        expect(sortie, isNot(contains(r'\$')),
            reason: 'aucun échappement nouveau du dollar sans pont déclaré');
      });
    }

    test('une région REFUSÉE par la garde ne mange aucun texte (mécanique de '
        'refus du parseur)', () {
      // `de 100$$ à 200$$` matche le motif bloc mais la garde le refuse : le
      // parseur doit réémettre le délimiteur et reprendre SANS boucler ni
      // avaler un caractère.
      expect(_plain(sansPont.decode(r'de 100$$ à 200$$')).trimRight(),
          r'de 100$$ à 200$$');
    });
  });

  group('CR-IFFD-69 — le comportement AVEC pont est INCHANGÉ (tripwire IFFD)',
      () {
    test('🔴 formule bloc : embed `latexBlock`, donnée exacte, cycle intact',
        () {
      // Ces valeurs sont celles mesurées AVANT la correction : si le bouclier
      // fuyait dans le chemin avec pont, l\'une d\'elles bougerait.
      final ops = avecLatex.decode(r'$$\int_0^1 x\,dx$$');
      final Object? data = ops
          .map((op) => op['insert'])
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => m['latexBlock'])
          .firstWhere((d) => d != null, orElse: () => null);
      expect(data, r'\int_0^1 x\,dx');
      expect(_cycle(avecLatex, r'$$\int_0^1 x\,dx$$'), r'$$\int_0^1 x\,dx$$');
    });

    test('🔴 avec pont, un prix est TOUJOURS échappé `\\\$` à l\'encodage '
        '(le bouclier ne doit pas soustraire le texte à cet échappement)', () {
      final String md = avecLatex.encode(<Map<String, dynamic>>[
        <String, dynamic>{'insert': 'prix de 5\$ à 9\$ environ\n'},
      ])! as String;
      expect(md.trimRight(), r'prix de 5\$ à 9\$ environ',
          reason: 'octets mesurés avant correction — ils ne doivent pas bouger');
    });
  });

  group('CR-IFFD-69 — un `\$\$` DANS du code n\'est JAMAIS une région', () {
    test('bloc de code clôturé : contenu opaque, intact, sans pont ET avec',
        () {
      const String source = '```\n\$\$x^2\$\$\n```';
      for (final codec in <ZMarkdownCodec>[sansPont, avecLatex]) {
        final ops = codec.decode(source);
        expect(_hasAnyEmbed(ops), isFalse);
        final Map<String, dynamic> ligne = ops.firstWhere((op) {
          final Object? attrs = op['attributes'];
          return attrs is Map && attrs.containsKey('code-block');
        });
        expect(ligne, isNotNull);
        expect(_plain(ops), contains(r'$$x^2$$'),
            reason: 'le contenu du bloc de code est du CODE, pas une formule');
      }
    });

    test('code inline : `\$\$x^2\$\$` reste du code, contenu intact', () {
      const String source = 'du `\$\$x^2\$\$` inline';
      for (final codec in <ZMarkdownCodec>[sansPont, avecLatex]) {
        final ops = codec.decode(source);
        final Map<String, dynamic> code = ops.firstWhere((op) {
          final Object? attrs = op['attributes'];
          return attrs is Map && attrs.containsKey('code');
        });
        expect(code['insert'], r'$$x^2$$');
      }
      // Et le cycle complet n\'introduit aucun échappement dans le code.
      expect(_cycle(sansPont, source), source);
    });
  });

  group('CR-IFFD-69 — AD-10 : un document DÉJÀ corrompu continue de se décoder',
      () {
    const String corrompu = r'$$\\int\_0^1 x,dx$$';

    test('jamais de throw, jamais de document vide', () {
      expect(() => sansPont.decode(corrompu), returnsNormally);
      expect(sansPont.decode(corrompu), isNotEmpty);
    });

    test('le corrompu est un point fixe : il ne se REcorrompt pas', () {
      // La donnée perdue (`\,`) est irrécupérable ; ce qui est dû est la
      // STABILITÉ : plus aucune altération à chaque cycle. Le bouclier fige la
      // région verbatim (un `\\` de charge peut être un saut de ligne de
      // matrice LaTeX légitime — le « dés-échapper » recorromprait ces
      // formules-là).
      expect(_cycle(sansPont, corrompu), corrompu);
      expect(_cycle(sansPont, _cycle(sansPont, corrompu)), corrompu);
    });
  });

  group('CR-IFFD-69 — le bouclier est BORNÉ à la région LaTeX', () {
    test('le texte AUTOUR d\'une formule reste échappé normalement', () {
      // `_` hors région doit rester échappé (sinon `a_b` deviendrait de
      // l\'emphase au cycle suivant) pendant que `_` EN région reste verbatim.
      const String source = r'a_b $$x_1$$ c_d';
      final String md =
          (sansPont.encode(sansPont.decode(source))! as String).trimRight();
      expect(md, r'a\_b $$x_1$$ c\_d');
      // Et le cycle sémantique est stable.
      expect(_plain(sansPont.decode(md)).trimRight(), source);
    });

    test('les 7 AUTRES constructions cassées du banc v0.49.0 sont inchangées',
        () {
      // Le bouclier ne prétend pas les réparer — et ne doit pas les déplacer.
      // Valeurs = sorties actuelles mesurées (normalisations assumées du
      // codec), verrouillées pour prouver que la correction est bornée.
      const Map<String, String> attendu = <String, String>{
        'a\nb': 'a b',
        '> ligne une\n> ligne deux': '> ligne une ligne deux',
        'elle est\nacquise': 'elle est acquise',
        'fin de ligne   \nsuite': 'fin de ligne\n\nsuite',
        'a\n\n\n\nb': 'a\n\nb',
        'a &amp; b': 'a & b',
        '   ': '',
      };
      attendu.forEach((source, sortie) {
        expect(_cycle(sansPont, source), sortie,
            reason: 'construction « ${source.replaceAll('\n', r'\n')} »');
      });
    });
  });
}
