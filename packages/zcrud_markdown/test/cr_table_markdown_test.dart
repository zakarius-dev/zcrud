// Pont TABLEAU ↔ Markdown (suite de CR-IFFD-24 §2).
//
// AVANT ce module, `encode` écrivait `[embed:table]` et TOUTES les cellules
// disparaissaient au premier enregistrement. Mesuré :
//   encode(table) = "avant \[embed:table\] après"
//   contient "Bénin" ? false     contient "20 %" ? false
// Ce n'était pas une dégradation documentée, c'était la même destruction que
// celle de l'image — et elle avait été rangée dans les « limites déclarées ».
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

const ZMarkdownCodec codec = ZMarkdownCodec();

String _md(List<Map<String, dynamic>> ops) => codec.encode(ops)! as String;

List<List<String>>? _cellsOf(List<Map<String, dynamic>> ops) {
  for (final op in ops) {
    final Object? insert = op['insert'];
    if (insert is! Map) continue;
    final Object? table = insert['table'];
    if (table is! Map) continue;
    final Object? cells = table['cells'];
    if (cells is! List) continue;
    return <List<String>>[
      for (final Object? row in cells)
        <String>[for (final Object? c in (row! as List)) '$c'],
    ];
  }
  return null;
}

String _plain(List<Map<String, dynamic>> ops) =>
    ops.map((op) => op['insert']).whereType<String>().join();

void main() {
  group('🔴 Le contenu des cellules SURVIT (il était détruit)', () {
    final Map<String, List<List<String>>> corpus =
        <String, List<List<String>>>{
      'ordinaire': <List<String>>[
        <String>['Pays', 'Taux'],
        <String>['Bénin', '20 %'],
      ],
      'cellule contenant un pipe': <List<String>>[
        <String>['a|b', 'c'],
        <String>['d', 'e'],
      ],
      'cellule multi-ligne': <List<String>>[
        <String>['multi\nligne', 'x'],
        <String>['y', 'z'],
      ],
      'cellules vides': <List<String>>[
        <String>['a', ''],
        <String>['', 'd'],
      ],
      'une seule colonne': <List<String>>[
        <String>['seul'],
        <String>['x'],
      ],
      'RTL et emoji': <List<String>>[
        <String>['مرحبا', '🇧🇯'],
        <String>['x', 'y'],
      ],
      'tirets dans une cellule': <List<String>>[
        <String>['---', 'b'],
        <String>['c', 'd'],
      ],
      'ligne unique': <List<String>>[
        <String>['seule', 'ligne'],
      ],
    };

    corpus.forEach((nom, cells) {
      test('$nom — aller-retour FIDÈLE', () {
        final ops = <Map<String, dynamic>>[
          zTableEmbedOp(cells: cells),
          <String, dynamic>{'insert': '\n'},
        ];
        final md = _md(ops);
        expect(md, isNot(contains('embed:table')),
            reason: 'le placeholder destructeur ne doit plus apparaître');
        expect(_cellsOf(codec.decode(md)), cells,
            reason: 'la matrice doit revenir à l\'identique');
      });
    });

    test('🔴 le texte des cellules est bien dans le Markdown persisté', () {
      final md = _md(<Map<String, dynamic>>[
        zTableEmbedOp(cells: <List<String>>[
          <String>['Pays', 'Taux'],
          <String>['Bénin', '20 %'],
        ]),
        <String, dynamic>{'insert': '\n'},
      ]);
      expect(md, contains('Bénin'));
      expect(md, contains('20 %'));
    });

    test('un tableau entouré de texte : les trois survivent', () {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'avant\n'},
        zTableEmbedOp(cells: <List<String>>[
          <String>['a', 'b'],
          <String>['1', '2'],
        ]),
        <String, dynamic>{'insert': 'après\n'},
      ];
      final rt = codec.decode(_md(ops));
      expect(_plain(rt), contains('avant'));
      expect(_plain(rt), contains('après'));
      expect(_cellsOf(rt), isNotNull);
    });

    test('stable sur TROIS cycles', () {
      final cells = <List<String>>[
        <String>['a|b', 'c'],
        <String>['d\ne', 'f'],
      ];
      var ops = <Map<String, dynamic>>[
        zTableEmbedOp(cells: cells),
        <String, dynamic>{'insert': '\n'},
      ];
      for (var cycle = 0; cycle < 3; cycle++) {
        ops = codec.decode(_md(ops));
        expect(_cellsOf(ops), cells, reason: 'cycle $cycle');
      }
    });
  });

  group('Auto-vérification : lisible quand c\'est fidèle, sûr sinon', () {
    test('un tableau ordinaire est persisté en GFM LISIBLE', () {
      final md = _md(<Map<String, dynamic>>[
        zTableEmbedOp(cells: <List<String>>[
          <String>['Pays', 'Taux'],
          <String>['Bénin', '20 %'],
        ]),
        <String, dynamic>{'insert': '\n'},
      ]);
      expect(md, contains('| Pays | Taux |'));
      expect(md, isNot(contains(kZTableFenceInfoForTest)),
          reason: 'pas de repli quand la forme lisible suffit');
    });

    test('une cellule à `|` reste LISIBLE grâce à l\'échappement', () {
      // Sans échappement, ce cas resterait FIDÈLE — l'auto-vérification
      // basculerait sur le repli. L'échappement n'est donc pas une exigence de
      // correction mais de LISIBILITÉ : c'est cette propriété-là qu'on asserte,
      // sans quoi retirer l'échappement ne ferait rougir aucun test.
      final md = _md(<Map<String, dynamic>>[
        zTableEmbedOp(cells: <List<String>>[
          <String>['a|b', 'c'],
        ]),
        <String, dynamic>{'insert': '\n'},
      ]);
      expect(md, contains(r'a\|b'));
      expect(md, isNot(contains(kZTableFenceInfoForTest)),
          reason: 'un pipe échappé ne doit PAS coûter la forme lisible');
    });

    test('🔴 un `<br>` LITTÉRAL force le repli SANS PERTE', () {
      // C'est le cas qui justifie le repli : rendu en GFM, `<br>` littéral
      // serait relu comme un saut de ligne. L'auto-vérification le détecte et
      // bascule sur le bloc clôturé. Sans elle, la cellule serait FAUSSÉE
      // silencieusement — une donnée plausible mais fausse, ce qui est pire
      // qu'une donnée manquante.
      final cells = <List<String>>[
        <String>['texte <br> littéral', 'x'],
      ];
      final md = _md(<Map<String, dynamic>>[
        zTableEmbedOp(cells: cells),
        <String, dynamic>{'insert': '\n'},
      ]);
      expect(md, contains(kZTableFenceInfoForTest),
          reason: 'la forme lisible est infidèle ici : repli attendu');
      expect(_cellsOf(codec.decode(md)), cells,
          reason: 'le repli doit être FIDÈLE, c\'est sa seule raison d\'être');
    });

    test('🔴 un tableau INLINE devient un bloc, sans rien perdre', () {
      // Un tableau Markdown occupe forcément son propre bloc : écrit au milieu
      // d'une ligne, il ne serait pas relu comme un tableau. La mise en page
      // bouge, le contenu est intégralement préservé.
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'avant '},
        zTableEmbedOp(cells: <List<String>>[
          <String>['x'],
        ]),
        <String, dynamic>{'insert': ' après\n'},
      ];
      final rt = codec.decode(_md(ops));
      expect(_plain(rt), contains('avant'));
      expect(_plain(rt), contains('après'));
      expect(_cellsOf(rt), <List<String>>[
        <String>['x'],
      ]);
    });

    test('une cellule multi-ligne reste LISIBLE (via `<br>`)', () {
      final md = _md(<Map<String, dynamic>>[
        zTableEmbedOp(cells: <List<String>>[
          <String>['multi\nligne', 'x'],
        ]),
        <String, dynamic>{'insert': '\n'},
      ]);
      expect(md, contains('multi<br>ligne'));
    });
  });

  group('Le décodage n\'invente rien', () {
    test('🔴 un bloc de pipes qui n\'est PAS un tableau reste du texte', () {
      // Refus de mutiler ce qu'on n'a pas su structurer — c'est le reproche
      // exact qui avait fait écarter `ExtensionSet.gitHubFlavored` (`ab12`).
      final ops = codec.decode('| juste | des pipes |\n| sans separateur |');
      expect(_cellsOf(ops), isNull);
      expect(_plain(ops), contains('|'),
          reason: 'les séparateurs doivent survivre');
      expect(_plain(ops), contains('juste'));
    });

    test('🔴 un `|` NON échappé dans une cellule ne DÉCOUPE pas la ligne', () {
      // Régression introduite par le pont tableau et trouvée en mesurant le
      // LaTeX en cellule : `$\left| x \right|$` écrit à la main était lu comme
      // deux séparateurs de plus, et la ligne devenait 4 colonnes au lieu de 2.
      // GFM est normatif : en-tête et délimiteur doivent avoir le même nombre
      // de colonnes. Refuser de structurer vaut mieux que structurer de travers
      // — c'est exactement ce qui avait fait écarter `gitHubFlavored`.
      const String src =
          r'| $\left| x \right|$ | val |' '\n' r'|---|---|' '\n' r'| a | b |';
      final ops = codec.decode(src);
      expect(_cellsOf(ops), isNull);
      expect(_plain(ops), contains(r'\left'),
          reason: 'le contenu LaTeX doit survivre en texte, pas être découpé');
      expect(_plain(ops), contains('val'));
    });

    test('du LaTeX en cellule survit à l\'aller-retour, pont actif ou non', () {
      // Le TEXTE survit intégralement — y compris `\ce{}`, `\pu{}` et un `|`
      // interne échappé par notre propre rendu. Il reste du TEXTE : la charge
      // de l'embed est `List<List<String>>`, elle ne porte pas de rich-text.
      final cells = <List<String>>[
        <String>[r'$E=mc^2$', r'$\ce{H2O}$'],
        <String>[r'$\left| x \right|$', r'$\pu{3 mol}$'],
      ];
      for (final c in <ZMarkdownCodec>[
        codec,
        ZMarkdownCodec(bridges: ZMarkdownBridges.latex),
      ]) {
        final md = c.encode(<Map<String, dynamic>>[
          zTableEmbedOp(cells: cells),
          <String, dynamic>{'insert': '\n'},
        ])! as String;
        expect(_cellsOf(c.decode(md)), cells,
            reason: 'pont ${c.bridges.isEmpty ? "inactif" : "actif"}');
      }
    });

    test('une formule HORS tableau reste un embed (pont actif)', () {
      final avecLatex = ZMarkdownCodec(bridges: ZMarkdownBridges.latex);
      final ops = avecLatex.decode(r'avant $E=mc^2$ après');
      final formules = ops
          .map((op) => op['insert'])
          .whereType<Map<dynamic, dynamic>>()
          .where((m) => m.containsKey('latex'));
      expect(formules, isNotEmpty,
          reason: 'le pont doit continuer de fonctionner hors tableau');
    });

    test('un tableau EXTERNE bien formé devient un tableau', () {
      final ops = codec.decode('| a | b |\n|---|---|\n| 1 | 2 |');
      expect(_cellsOf(ops), <List<String>>[
        <String>['a', 'b'],
        <String>['1', '2'],
      ]);
    });

    test('l\'alignement d\'un tableau externe est PERDU (limite assumée)', () {
      // La charge de l'embed ne porte pas l'alignement : rien à faire au codec.
      final ops = codec.decode('| a | b |\n|:--|--:|\n| 1 | 2 |');
      expect(_cellsOf(ops), <List<String>>[
        <String>['a', 'b'],
        <String>['1', '2'],
      ]);
      expect(_md(ops), isNot(contains(':--')));
    });

    test('AD-10 : charges de tableau corrompues → jamais de throw', () {
      for (final Object? charge in <Object?>[
        <String, dynamic>{'cells': 'pas une liste'},
        <String, dynamic>{'cells': <Object?>[]},
        <String, dynamic>{'cells': <Object?>[42]},
        <String, dynamic>{},
      ]) {
        final ops = <Map<String, dynamic>>[
          <String, dynamic>{
            'insert': <String, dynamic>{'table': charge},
          },
          <String, dynamic>{'insert': '\n'},
        ];
        expect(() => codec.encode(ops), returnsNormally, reason: '$charge');
        expect(codec.encode(ops), isNot(''),
            reason: 'une charge illisible ne doit pas VIDER le document');
      }
    });

    test('🔴 une charge GELÉE ne vide pas le document', () {
      // PIÈGE MESURÉ : `zTableEmbedOp` gèle sa charge en profondeur ;
      // `Document.fromDelta` la caste et LÈVE ; le filet AD-10 aurait persisté
      // `''`. Préserver un embed gelé sans le dégeler ne dégradait pas le
      // tableau — cela détruisait TOUT le document.
      final md = _md(<Map<String, dynamic>>[
        <String, dynamic>{'insert': 'texte important\n'},
        zTableEmbedOp(cells: <List<String>>[
          <String>['a', 'b'],
        ]),
        <String, dynamic>{'insert': '\n'},
      ]);
      expect(md, contains('texte important'));
      expect(md, isNot(''));
    });
  });
}

/// Info-string du bloc de repli, dupliquée ici volontairement : le test ne doit
/// pas dépendre d'un symbole interne au paquet.
const String kZTableFenceInfoForTest = 'zcrud-table';
