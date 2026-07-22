// CR-IFFD-23 §3 / CR-IFFD-24 §2 — ponts Markdown ↔ embed, OPT-IN (AD-57).
//
// Le paquet savait RENDRE une formule qu'il ne savait pas PRODUIRE depuis du
// Markdown : l'embed était un aller simple. On insérait une formule, on
// enregistrait, on rouvrait — on trouvait `[embed:latex]`.
//
// L'invariant le plus important de ce fichier n'est pas que le pont marche :
// c'est que SANS déclaration, RIEN ne change.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

const ZMarkdownCodec sansPont = ZMarkdownCodec();
final ZMarkdownCodec avecLatex = ZMarkdownCodec(bridges: ZMarkdownBridges.latex);

Map<String, dynamic> _embed(String type, String data) => <String, dynamic>{
      'insert': <String, dynamic>{type: data},
    };

Object? _embedData(List<Map<String, dynamic>> ops, String type) {
  for (final op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map && insert.containsKey(type)) return insert[type];
  }
  return null;
}

String _plain(List<Map<String, dynamic>> ops) =>
    ops.map((op) => op['insert']).whereType<String>().join();

void main() {
  group('AD-57 — le DÉFAUT reste zéro-extension', () {
    test('🔴 sans pont déclaré, une formule dégrade EXACTEMENT comme avant', () {
      final md = sansPont.encode(<Map<String, dynamic>>[
        <String, dynamic>{'insert': 'avant '},
        _embed('latex', 'E=mc^2'),
        <String, dynamic>{'insert': ' après\n'},
      ])! as String;
      expect(md, contains('embed:latex'));
      expect(_embedData(sansPont.decode(md), 'latex'), isNull);
    });

    test('sans pont, `\$x\$` reste du TEXTE — aucune syntaxe implicite', () {
      // Contrat décisif : déclarer un pont change le sens d'un texte ordinaire.
      // Tant que l'hôte ne l'a pas demandé, deux `$` restent deux `$`.
      final ops = sansPont.decode(r'prix de 5$ à 9$ environ');
      expect(_embedData(ops, 'latex'), isNull);
      expect(_plain(ops), contains(r'5$'));
    });

    test('le codec par défaut reste `const`', () {
      expect(const ZMarkdownCodec().bridges, isEmpty);
    });
  });

  group('Pont LaTeX déclaré — aller ET retour', () {
    test('🔴 une formule inline SURVIT au round-trip', () {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'soit '},
        _embed('latex', 'E=mc^2'),
        <String, dynamic>{'insert': ' donc\n'},
      ];
      final md = avecLatex.encode(ops)! as String;
      expect(md, contains(r'$E=mc^2$'));
      expect(md, isNot(contains('embed:latex')),
          reason: 'le placeholder ne doit plus apparaître');

      final rt = avecLatex.decode(md);
      expect(_embedData(rt, 'latex'), 'E=mc^2');
      expect(_plain(rt), contains('soit'));
      expect(_plain(rt), contains('donc'));
    });

    test('une formule BLOC `\$\$…\$\$` est distinguée de l\'inline', () {
      // L'ordre de déclaration compte : `$$x$$` doit être essayé avant `$x$`,
      // sinon la forme bloc serait vue comme deux formules inline vides.
      final rt = avecLatex.decode(r'$$\int_0^1 x\,dx$$');
      expect(_embedData(rt, 'latexBlock'), r'\int_0^1 x\,dx');
      expect(_embedData(rt, 'latex'), isNull);
    });

    test('la forme `\\(…\\)` est reconnue comme inline', () {
      expect(_embedData(avecLatex.decode(r'soit \(a+b\) fin'), 'latex'), 'a+b');
    });

    test('la notation chimique `\\ce{}` traverse sans traitement dédié', () {
      // C'est une commande LaTeX comme une autre : rien de spécifique requis.
      final rt = avecLatex.decode(r'$\ce{H2O}$');
      expect(_embedData(rt, 'latex'), r'\ce{H2O}');
    });

    test('deux formules dans la même ligne', () {
      final rt = avecLatex.decode(r'$a$ et $b$');
      final formules = rt
          .map((op) => op['insert'])
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => m['latex'])
          .toList();
      expect(formules, <String>['a', 'b']);
    });

    test('AD-10 : une donnée d\'embed non-String ne casse pas l\'encodage', () {
      expect(
        () => avecLatex.encode(<Map<String, dynamic>>[
          <String, dynamic>{
            'insert': <String, dynamic>{'latex': 42},
          },
          <String, dynamic>{'insert': '\n'},
        ]),
        returnsNormally,
      );
    });

    test('un embed NON ponté dégrade toujours en placeholder (AC9)', () {
      // La préservation ne vaut que pour ce que l'encodeur sait écrire. Sans
      // cette borne, `DeltaToMarkdown` throwerait et viderait TOUT le document.
      final md = avecLatex.encode(<Map<String, dynamic>>[
        <String, dynamic>{'insert': 'avant '},
        _embed('table', 'peu importe'),
        <String, dynamic>{'insert': ' après\n'},
      ])! as String;
      expect(md, contains('embed:table'));
      expect(md, contains('avant'));
      expect(md, contains('après'));
    });
  });

  group('Pont sur mesure déclaré par l\'hôte', () {
    test('un hôte peut ponter sa PROPRE syntaxe vers son PROPRE embed', () {
      final codec = ZMarkdownCodec(
        bridges: <ZMarkdownEmbedBridge>[
          ZMarkdownEmbedBridge(
            embedType: 'mention',
            pattern: RegExp(r'@\{([^}]+)\}'),
            toMarkdown: (data) => '@{$data}',
          ),
        ],
      );
      final rt = codec.decode('salut @{zakarius} !');
      expect(_embedData(rt, 'mention'), 'zakarius');
      expect(codec.encode(rt), contains('@{zakarius}'));
    });

    test('`dataFromMatch` permet de composer plusieurs groupes', () {
      final codec = ZMarkdownCodec(
        bridges: <ZMarkdownEmbedBridge>[
          ZMarkdownEmbedBridge(
            embedType: 'ref',
            pattern: RegExp(r'\{\{(\w+):(\w+)\}\}'),
            dataFromMatch: (m) => '${m.group(1)}/${m.group(2)}',
            toMarkdown: (data) => '{{${data.toString().replaceAll('/', ':')}}}',
          ),
        ],
      );
      expect(_embedData(codec.decode('voir {{art:12}} ici'), 'ref'), 'art/12');
    });

    test('un motif SANS groupe de capture ne throw pas (AD-10)', () {
      final codec = ZMarkdownCodec(
        bridges: <ZMarkdownEmbedBridge>[
          ZMarkdownEmbedBridge(
            embedType: 'hr',
            pattern: RegExp('@@@'),
            toMarkdown: (data) => '@@@',
          ),
        ],
      );
      expect(() => codec.decode('a @@@ b'), returnsNormally);
      expect(_embedData(codec.decode('a @@@ b'), 'hr'), '');
    });
  });

  group('Trouvé EN REVUE — un pont ne doit pas piéger le texte ordinaire', () {
    test('🔴 une somme d\'argent survit quand le pont LaTeX est actif', () {
      // La règle « échapper ce que le décodeur sait relire » avait été posée
      // pour `~` puis oubliée pour les ponts : les deux corrections avaient été
      // conçues séparément. Un prix `5$ … 9$` devenait une formule.
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'prix de 5\$ à 9\$ environ\n'},
      ];
      final rt = avecLatex.decode(avecLatex.encode(ops));
      expect(_embedData(rt, 'latex'), isNull,
          reason: 'un prix ne doit pas devenir une formule');
      expect(_plain(rt), contains('5\$'));
      expect(_plain(rt), contains('9\$'));
    });

    test('une VRAIE formule reste reconnue malgré cet échappement', () {
      final rt = avecLatex.decode(r'soit $E=mc^2$ donc');
      expect(_embedData(rt, 'latex'), 'E=mc^2');
    });

    test('un délimiteur ÉCHAPPÉ n\'ouvre pas de formule', () {
      expect(_embedData(avecLatex.decode(r'a \$b\$ c'), 'latex'), isNull);
    });

    test('🔴 deux ponts du même type : décodage et encodage désignent le MÊME',
        () {
      // Une Map littérale laissait gagner le DERNIER à l'encodage, alors que le
      // décodage retient la PREMIÈRE syntaxe qui correspond : les deux sens
      // désignaient deux ponts différents.
      final codec = ZMarkdownCodec(
        bridges: <ZMarkdownEmbedBridge>[
          ZMarkdownEmbedBridge(
            embedType: 'x',
            pattern: RegExp(r'@@(\w+)@@'),
            toMarkdown: (data) => '@@$data@@',
          ),
          ZMarkdownEmbedBridge(
            embedType: 'x',
            pattern: RegExp(r'%%(\w+)%%'),
            toMarkdown: (data) => '%%$data%%',
          ),
        ],
      );
      final rt = codec.decode('a @@val@@ b');
      expect(_embedData(rt, 'x'), 'val');
      expect(codec.encode(rt), contains('@@val@@'),
          reason: 'le PREMIER pont déclaré doit gagner des DEUX côtés');
    });
  });

  group('Défauts trouvés HORS CR pendant la mesure', () {
    test('🔴 une définition de lien de référence ne VIDE plus le document', () {
      // `[ref]: http://…` est une syntaxe Markdown standard : le parseur la
      // consomme comme métadonnée et ne rend aucun nœud. Tout le contenu
      // disparaissait, silencieusement. Sans rapport avec les CR — trouvé en
      // mesurant le corpus piège de CR-IFFD-23 §1.
      final ops = sansPont.decode('[ref]: http://exemple.test');
      expect(ops, isNotEmpty);
      expect(_plain(ops), contains('exemple.test'));
    });

    test('un texte non vide ne produit JAMAIS un document vide', () {
      for (final source in <String>[
        '[ref]: http://exemple.test',
        '[a]: /b "titre"',
        '<!-- commentaire seul -->',
      ]) {
        expect(sansPont.decode(source), isNotEmpty, reason: source);
      }
    });

    test('un document réellement vide reste vide (pas de faux contenu)', () {
      expect(sansPont.decode(''), isEmpty);
      expect(sansPont.decode('   \n  '), isEmpty);
    });
  });
}
