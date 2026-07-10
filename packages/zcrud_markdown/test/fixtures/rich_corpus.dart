// Corpus rich-text RÉEL partagé par les tests de codecs E6-2 (AC2/AC3/AC9).
//
// Chaque cas est une VALEUR NEUTRE (ops Delta JSON = `List<Map<String,dynamic>>`)
// telle que `ZMarkdownField` la porte sur sa tranche. Couvre : texte simple,
// gras/italique, titres, listes IMBRIQUÉES (≥2 niveaux), liens, code inline +
// bloc, blockquote, entités HTML dans le texte, et ops embed OPAQUES (LaTeX /
// tableau futurs — E6-3/E6-4) traversant comme ops Delta opaques.

/// Un cas de corpus : ops neutres + drapeaux de couverture Markdown.
class RichCase {
  const RichCase(
    this.name,
    this.ops, {
    this.markdownSupported = true,
  });

  /// Nom lisible du cas (diagnostic de test).
  final String name;

  /// Ops Delta neutres (JSON-safe).
  final List<Map<String, dynamic>> ops;

  /// `true` si le round-trip Markdown PRÉSERVE la sémantique du cas ; `false`
  /// si le cas est PERDU par `ZMarkdownCodec` (table des pertes — AC3/AC9).
  final bool markdownSupported;
}

/// Texte simple (une ligne).
const simpleOps = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'Bonjour le monde\n'},
];

/// Gras + italique inline.
const boldItalicOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': 'gras',
    'attributes': <String, dynamic>{'bold': true},
  },
  <String, dynamic>{'insert': ' et '},
  <String, dynamic>{
    'insert': 'italique',
    'attributes': <String, dynamic>{'italic': true},
  },
  <String, dynamic>{'insert': '\n'},
];

/// Titres H1–H3.
const headingsOps = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'Titre 1'},
  <String, dynamic>{
    'insert': '\n',
    'attributes': <String, dynamic>{'header': 1},
  },
  <String, dynamic>{'insert': 'Titre 2'},
  <String, dynamic>{
    'insert': '\n',
    'attributes': <String, dynamic>{'header': 2},
  },
  <String, dynamic>{'insert': 'Titre 3'},
  <String, dynamic>{
    'insert': '\n',
    'attributes': <String, dynamic>{'header': 3},
  },
];

/// Liste à puces IMBRIQUÉE (2 niveaux — `indent:1` au niveau 2).
const nestedListOps = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'niveau 1'},
  <String, dynamic>{
    'insert': '\n',
    'attributes': <String, dynamic>{'list': 'bullet'},
  },
  <String, dynamic>{'insert': 'niveau 2'},
  <String, dynamic>{
    'insert': '\n',
    'attributes': <String, dynamic>{'list': 'bullet', 'indent': 1},
  },
];

/// Lien inline.
const linkOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': 'zcrud',
    'attributes': <String, dynamic>{'link': 'https://example.com'},
  },
  <String, dynamic>{'insert': '\n'},
];

/// Code inline.
const inlineCodeOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': 'ident',
    'attributes': <String, dynamic>{'code': true},
  },
  <String, dynamic>{'insert': '\n'},
];

/// Bloc de code.
const codeBlockOps = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'var x = 1;'},
  <String, dynamic>{
    'insert': '\n',
    'attributes': <String, dynamic>{'code-block': true},
  },
];

/// Citation (blockquote).
const blockquoteOps = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'citation'},
  <String, dynamic>{
    'insert': '\n',
    'attributes': <String, dynamic>{'blockquote': true},
  },
];

/// Entités HTML LITTÉRALES dans le texte (round-trippées en tant que TEXTE).
const htmlEntitiesOps = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'a < b & c > d\n'},
];

/// Attribut de COULEUR — non exprimable en Markdown ⇒ PERDU (table des pertes).
const colorOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': 'rouge',
    'attributes': <String, dynamic>{'color': '#ff0000'},
  },
  <String, dynamic>{'insert': '\n'},
];

/// Op embed OPAQUE (formule LaTeX — E6-3). Traverse `ZDeltaCodec` à l'identique ;
/// PERDU par `ZMarkdownCodec` (non exprimable en MD — AC9).
const latexEmbedOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': <String, dynamic>{'formula': 'E = mc^2'},
  },
  <String, dynamic>{'insert': '\n'},
];

/// Op embed OPAQUE arbitraire (tableau futur — E6-4), attribut custom simulé.
const opaqueEmbedOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': <String, dynamic>{
      'z-table': <String, dynamic>{
        'rows': 2,
        'cols': 2,
        'cells': <String>['a', 'b', 'c', 'd'],
      },
    },
  },
  <String, dynamic>{'insert': '\n'},
];

/// Document MIXTE (HIGH-1) : texte + embed LaTeX + texte + embed tableau + texte.
/// Prouve la PERTE BORNÉE — le texte environnant DOIT survivre à l'encode
/// Markdown, chaque embed devenant un placeholder ; JAMAIS un document vide.
const mixedTextAndEmbedsOps = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'avant '},
  <String, dynamic>{
    'insert': <String, dynamic>{'formula': 'E = mc^2'},
  },
  <String, dynamic>{'insert': ' milieu '},
  <String, dynamic>{
    'insert': <String, dynamic>{
      'z-table': <String, dynamic>{'rows': 1, 'cols': 1},
    },
  },
  <String, dynamic>{'insert': ' apres\n'},
];

/// Op embed LaTeX de type CANONIQUE E6-3 — op `{"insert": {"latex": "<source>"}}`.
/// C'est la représentation RÉELLE produite par `ZLatexEmbed` (E6-3), distincte du
/// `formula` d'anticipation E6-2 ci-dessus. Traverse `ZDeltaCodec` à l'identité ;
/// dégradée en `[embed:latex]` par `ZMarkdownCodec` (placeholder générique).
const latexTypeEmbedOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': <String, dynamic>{'latex': 'E = mc^2'},
  },
  <String, dynamic>{'insert': '\n'},
];

/// Document MIXTE E6-3 (HIGH-1) : texte + embed `latex` + texte. Prouve la PERTE
/// BORNÉE côté `ZMarkdownCodec` (le texte survit, l'embed devient `[embed:latex]`)
/// ET l'identité côté `ZDeltaCodec` (op opaque préservée).
const mixedTextAndLatexEmbedOps = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'avant '},
  <String, dynamic>{
    'insert': <String, dynamic>{'latex': 'E = mc^2'},
  },
  <String, dynamic>{'insert': ' apres\n'},
];

/// Op embed tableau de type CANONIQUE E6-4 — op `{"insert": {"table": <struct>}}`.
/// C'est la représentation RÉELLE produite par `ZTableEmbed` (E6-4), distincte du
/// `z-table` d'anticipation E6-2 ci-dessus. Structure IMBRIQUÉE (matrice de
/// cellules). Traverse `ZDeltaCodec` à l'identité ; dégradée en `[embed:table]`
/// par `ZMarkdownCodec` (placeholder générique, type capté par la 1re clé).
const tableTypeEmbedOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': <String, dynamic>{
      'table': <String, dynamic>{
        'rows': 2,
        'columns': 2,
        'cells': <List<String>>[
          <String>['a', 'b'],
          <String>['c', 'd'],
        ],
      },
    },
  },
  <String, dynamic>{'insert': '\n'},
];

/// Document MIXTE E6-4 (HIGH-1) : texte + embed `table` + texte. Prouve la PERTE
/// BORNÉE côté `ZMarkdownCodec` (le texte survit, l'embed devient `[embed:table]`)
/// ET l'identité côté `ZDeltaCodec` (op opaque, structure imbriquée préservée).
const mixedTextAndTableEmbedOps = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'avant '},
  <String, dynamic>{
    'insert': <String, dynamic>{
      'table': <String, dynamic>{
        'rows': 1,
        'columns': 1,
        'cells': <List<String>>[
          <String>['x'],
        ],
      },
    },
  },
  <String, dynamic>{'insert': ' apres\n'},
];

/// Corpus complet pour le round-trip IDENTITÉ `ZDeltaCodec` (tout préservé).
const deltaIdentityCorpus = <RichCase>[
  RichCase('simple', simpleOps),
  RichCase('bold+italic', boldItalicOps),
  RichCase('headings', headingsOps),
  RichCase('nested-list', nestedListOps),
  RichCase('link', linkOps),
  RichCase('inline-code', inlineCodeOps),
  RichCase('code-block', codeBlockOps),
  RichCase('blockquote', blockquoteOps),
  RichCase('html-entities', htmlEntitiesOps),
  RichCase('color', colorOps),
  RichCase('latex-embed', latexEmbedOps),
  RichCase('latex-type-embed', latexTypeEmbedOps),
  RichCase('mixed-text+latex', mixedTextAndLatexEmbedOps),
  RichCase('opaque-embed', opaqueEmbedOps),
  RichCase('table-type-embed', tableTypeEmbedOps),
  RichCase('mixed-text+table', mixedTextAndTableEmbedOps),
];
