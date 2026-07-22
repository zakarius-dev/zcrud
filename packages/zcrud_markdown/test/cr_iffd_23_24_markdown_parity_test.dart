// CR-IFFD-23 / CR-IFFD-24 — parité Markdown : `encode` était plus riche que
// `decode`, et le codec émettait un Markdown qu'il ne savait pas relire.
//
// Chaque groupe verrouille une capacité qui était MESURABLEMENT cassée en
// v0.6.0. Les valeurs attendues ne sont pas déduites : elles proviennent d'un
// banc de mesure exécuté avant correction (cf. handoff v0.7.0).
//
// DISCIPLINE R3 : chaque garde a été prouvée MORDANTE en réinjectant la
// régression qu'elle prétend attraper (retrait de la syntaxe, du mapping h4-h6,
// de la préservation d'embed, du handler d'échappement) — test rouge, puis
// restauré.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

const ZMarkdownCodec codec = ZMarkdownCodec();

List<Map<String, dynamic>> _rt(List<Map<String, dynamic>> ops) =>
    codec.decode(codec.encode(ops));

String _md(List<Map<String, dynamic>> ops) => codec.encode(ops)! as String;

String _plain(List<Map<String, dynamic>> ops) => ops
    .map((op) => op['insert'])
    .whereType<String>()
    .join();

Object? _attr(List<Map<String, dynamic>> ops, String key) {
  for (final op in ops) {
    final Object? attrs = op['attributes'];
    if (attrs is Map && attrs.containsKey(key)) return attrs[key];
  }
  return null;
}

bool _hasEmbed(List<Map<String, dynamic>> ops, String type) => ops.any((op) {
      final Object? insert = op['insert'];
      return insert is Map && insert.containsKey(type);
    });

List<Map<String, dynamic>> sansPontDecode(String md) => codec.decode(md);

Map<String, dynamic> _text(String value, [Map<String, dynamic>? attrs]) {
  // Forme impérative volontaire : `if (attrs != null) 'attributes': attrs`
  // déclenche `use_null_aware_elements`, et la « correction » `...?attrs`
  // APLATIT les attributs dans l'op au lieu de les imbriquer — une op sans
  // `attributes`, silencieusement acceptée par le codec.
  final op = <String, dynamic>{'insert': value};
  if (attrs != null) op['attributes'] = attrs;
  return op;
}

void main() {
  group('CR-IFFD-24 §1 — IMAGE : la perte la plus grave, elle DÉTRUISAIT', () {
    // Mesuré en v0.6.0 : `decode` savait lire `![](url)` et construire l'embed,
    // mais `encode` le remplaçait par `[embed:image]` — URL comprise. Une image
    // disparaissait donc au PREMIER enregistrement, irrécupérablement.
    const String url = 'https://exemple.test/photo.png';

    test('🔴 une image SURVIT à un aller-retour complet', () {
      final ops = codec.decode('![légende]($url)');
      expect(_hasEmbed(ops, 'image'), isTrue,
          reason: 'decode savait déjà lire une image Markdown');

      final md = _md(ops);
      expect(md, contains(url),
          reason: "l'URL doit rester dans le Markdown persisté");
      expect(md, isNot(contains('embed:image')),
          reason: 'le placeholder destructeur ne doit plus apparaître');

      final rt = codec.decode(md);
      expect(_hasEmbed(rt, 'image'), isTrue,
          reason: "l'embed image doit renaître du Markdown");
    });

    test('🔴 stable sur DEUX cycles (la v0.6.0 détruisait dès le premier)', () {
      var ops = codec.decode('![]($url)');
      for (var cycle = 0; cycle < 2; cycle++) {
        ops = codec.decode(_md(ops));
        expect(_hasEmbed(ops, 'image'), isTrue, reason: 'cycle $cycle');
      }
    });

    test('image entourée de texte : le texte ET l\'image survivent', () {
      final ops = <Map<String, dynamic>>[
        _text('avant '),
        <String, dynamic>{
          'insert': <String, dynamic>{'image': url},
        },
        _text(' après\n'),
      ];
      final rt = _rt(ops);
      expect(_plain(rt), contains('avant'));
      expect(_plain(rt), contains('après'));
      expect(_hasEmbed(rt, 'image'), isTrue);
    });

    test('VIDÉO : dégradée en lien, mais la SOURCE survit', () {
      // Markdown n'a pas de forme native pour la vidéo. On assume la
      // dégradation en lien — ce qui reste très supérieur à `[embed:video]`,
      // qui perdait l'adresse.
      const String src = 'https://exemple.test/clip.mp4';
      final md = _md(<Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'video': src},
        },
        _text('\n'),
      ]);
      expect(md, contains(src));
      expect(_attr(codec.decode(md), 'link'), src);
    });

    test('AC9 non régressé : un embed SANS forme Markdown reste borné', () {
      // La préservation ne doit valoir que pour les types réellement gérés en
      // aval. Un embed préservé sans handler ferait throw et VIDERAIT tout le
      // document — c'est la régression HIGH-1 que le placeholder évite.
      final md = _md(<Map<String, dynamic>>[
        _text('avant '),
        <String, dynamic>{
          'insert': <String, dynamic>{'latex': 'E=mc^2'},
        },
        _text(' après\n'),
      ]);
      expect(md, contains('embed:latex'));
      expect(md, contains('avant'));
      expect(md, contains('après'));
    });
  });

  group('CR-IFFD-24 §1 — titres H4 à H6', () {
    // Le docstring promettait « H1–H6 » ; mesuré, H4-H6 revenaient en texte nu.
    // La limite venait de `markdown_quill` (il ne mappe que h1..h3), PAS de
    // `flutter_quill` qui expose bien `Attribute.h4/h5/h6`.
    for (var level = 1; level <= 6; level++) {
      test('titre H$level conservé au round-trip', () {
        final ops = <Map<String, dynamic>>[
          _text('Titre $level'),
          _text('\n', <String, dynamic>{'header': level}),
        ];
        expect(_md(ops), startsWith('${'#' * level} '));
        expect(_attr(_rt(ops), 'header'), level,
            reason: 'H$level doit revenir avec son niveau exact');
      });
    }
  });

  group('CR-IFFD-24 §1 — barré `~~`', () {
    test('🔴 le barré survit au round-trip (le docstring le PROMETTAIT)', () {
      final ops = <Map<String, dynamic>>[
        _text('avant '),
        _text('barré', <String, dynamic>{'strike': true}),
        _text(' après\n'),
      ];
      expect(_md(ops), contains('~~barré~~'));
      final rt = _rt(ops);
      expect(_attr(rt, 'strike'), isTrue);
      expect(_plain(rt), isNot(contains('~~')),
          reason: 'les tildes ne doivent plus polluer le texte affiché');
    });

    test('du Markdown EXTERNE contenant `~~` est relu comme barré', () {
      expect(_attr(codec.decode('texte ~~barré~~ fin'), 'strike'), isTrue);
    });

    test('un `~~` LITTÉRAL saisi par l\'utilisateur reste littéral', () {
      // Contrepartie du point précédent : maintenant que `~~` a un sens, il faut
      // l'échapper à l'encodage, sinon un texte ordinaire deviendrait barré.
      final ops = <Map<String, dynamic>>[_text('vague ~~ici~~ fin\n')];
      final rt = _rt(ops);
      expect(_attr(rt, 'strike'), isNull);
      expect(_plain(rt), contains('~~ici~~'));
    });
  });

  group('CR-IFFD-24 §1 — cases à cocher', () {
    test('🔴 `checked` survit, et `[x]` ne pollue plus le texte', () {
      final ops = <Map<String, dynamic>>[
        _text('fait'),
        _text('\n', <String, dynamic>{'list': 'checked'}),
      ];
      expect(_md(ops), contains('- [x] fait'));
      final rt = _rt(ops);
      expect(_attr(rt, 'list'), 'checked');
      expect(_plain(rt), isNot(contains('[x]')),
          reason: 'le marqueur était RÉINJECTÉ dans le texte de la puce');
    });

    test('`unchecked` survit', () {
      final rt = _rt(<Map<String, dynamic>>[
        _text('à faire'),
        _text('\n', <String, dynamic>{'list': 'unchecked'}),
      ]);
      expect(_attr(rt, 'list'), 'unchecked');
    });

    test('une case sur liste ORDONNÉE fonctionne aussi', () {
      // Prouve qu'une seule `…WithCheckboxSyntax` couvre les deux sortes de
      // liste : sans elle, ce cas retomberait en `ordered` + `[x]` dans le
      // texte. C'est ce qui rend la seconde classe inutile.
      final rt = codec.decode('1. [x] ordonné');
      expect(_attr(rt, 'list'), 'checked');
      expect(_plain(rt), isNot(contains('[x]')));
    });

    test('une puce ORDINAIRE reste une puce (non-régression)', () {
      final rt = _rt(<Map<String, dynamic>>[
        _text('simple'),
        _text('\n', <String, dynamic>{'list': 'bullet'}),
      ]);
      expect(_attr(rt, 'list'), 'bullet');
    });
  });

  group('CR-IFFD-24 §2 — exposant / indice', () {
    // Non demandé explicitement par la CR, mais les DEUX boutons sont actifs par
    // défaut dans la barre d'outils : leur effet était perdu en silence, et
    // cette perte n'était même pas documentée.
    test('exposant conservé', () {
      final ops = <Map<String, dynamic>>[
        _text('x'),
        _text('2', <String, dynamic>{'script': 'super'}),
        _text('\n'),
      ];
      final rt = _rt(ops);
      expect(_attr(rt, 'script'), 'super');
      expect(_plain(rt), contains('x2'));
    });

    test('indice conservé', () {
      final rt = _rt(<Map<String, dynamic>>[
        _text('H'),
        _text('2', <String, dynamic>{'script': 'sub'}),
        _text('O\n'),
      ]);
      expect(_attr(rt, 'script'), 'sub');
    });

    test('souligné NON régressé par la généralisation des marqueurs', () {
      final rt = _rt(<Map<String, dynamic>>[
        _text('soul', <String, dynamic>{'underline': true}),
        _text('\n'),
      ]);
      expect(_attr(rt, 'underline'), isTrue);
    });

    test('souligné ET exposant imbriqués', () {
      final rt = _rt(<Map<String, dynamic>>[
        _text('a'),
        _text('b', <String, dynamic>{'underline': true, 'script': 'super'}),
        _text('c\n'),
      ]);
      expect(_attr(rt, 'underline'), isTrue);
      expect(_attr(rt, 'script'), 'super');
    });
  });

  group('CR-IFFD-23 §1 — un Delta sérialisé en chaîne JSON', () {
    // Forme sous laquelle un corpus Quill legacy est RÉELLEMENT stocké :
    // `jsonEncode(document.toDelta().toJson())` rend une String, pas une List.
    // Elle empruntait la branche Markdown et s'affichait littéralement.
    test('🔴 un Delta JSON en String est décodé, pas rendu littéralement', () {
      final String persisted = jsonEncode(<Map<String, dynamic>>[
        _text('gras', <String, dynamic>{'bold': true}),
        _text('\n'),
      ]);
      final ops = codec.decode(persisted);
      expect(_plain(ops), 'gras\n');
      expect(_attr(ops, 'bold'), isTrue);
      expect(_plain(ops), isNot(contains('insert')),
          reason: 'le JSON ne doit plus apparaître à l\'écran');
    });

    test('les embeds d\'un Delta sérialisé survivent', () {
      final String persisted = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'latex': 'x^2'},
        },
        _text('\n'),
      ]);
      expect(_hasEmbed(codec.decode(persisted), 'latex'), isTrue);
    });

    test('String et List donnent le MÊME résultat (asymétrie corrigée)', () {
      final ops = <Map<String, dynamic>>[_text('Bonjour'), _text('\n')];
      expect(codec.decode(jsonEncode(ops)), codec.decode(ops));
    });

    group('AUCUN faux positif — corpus piège mesuré', () {
      // Une détection naïve par `jsonDecode` aurait détourné six de ces entrées
      // et throwé sur cinq autres, que le try/catch global aurait transformées
      // en document VIDE. Chacune doit rester du Markdown.
      const Map<String, String> pieges = <String, String>{
        'lien Markdown': '[Un lien](http://exemple.test)',
        'liste JSON de nombres': '[1, 2, 3]',
        'liste JSON vide': '[]',
        'liste JSON de chaînes': '["a","b"]',
        'objet JSON': '{"insert":"x"}',
        'texte commençant par un crochet': '[NOTE] ceci est un texte.',
        'case à cocher GFM': '- [x] fait',
        'JSON tronqué': '[{"insert":"x"}',
        'ops sans insert': '[{"retain":3}]',
        'Delta encapsulé': '{"ops":[{"insert":"x"}]}',
      };
      pieges.forEach((nom, source) {
        test('$nom → reste du Markdown, jamais un document vidé', () {
          final ops = codec.decode(source);
          expect(ops, isNotEmpty,
              reason: '« $source » ne doit pas produire un document vide');
        });
      });
    });
  });

  group('CR-IFFD-23 §2 — le sur-échappement', () {
    test('🔴 un tiret et un point EN MILIEU ne sont plus échappés', () {
      // Les deux chaînes citées par la CR, mot pour mot.
      expect(_md(<Map<String, dynamic>>[
        _text("Qu'est-ce que la valeur en douane ?\n"),
      ]), startsWith("Qu'est-ce que la valeur en douane ?"));
      expect(_md(<Map<String, dynamic>>[_text('a-b-c. 1. un\n')]),
          startsWith('a-b-c. 1. un'));
    });

    test('mais un ouvreur de bloc en TÊTE DE LIGNE reste échappé', () {
      // Sans quoi le décodage transformerait le texte en puce/titre/citation.
      for (final source in <String>['- item', '1. item', '# titre', '> cite']) {
        final ops = <Map<String, dynamic>>[_text('$source\n')];
        final rt = _rt(ops);
        expect(_plain(rt).trim(), source,
            reason: '« $source » doit revenir tel quel, pas devenir un bloc');
        expect(_attr(rt, 'list'), isNull, reason: source);
        expect(_attr(rt, 'header'), isNull, reason: source);
        expect(_attr(rt, 'blockquote'), isNull, reason: source);
      }
    });

    test('les caractères ambigus INLINE restent échappés', () {
      for (final source in <String>[
        'snake_case_ici',
        'étoile * au milieu',
        'crochet [x] milieu',
        'balise <b> littérale',
      ]) {
        expect(_plain(_rt(<Map<String, dynamic>>[_text('$source\n')])).trim(),
            source);
      }
    });

    test('idempotence : cinq passes ne dégradent pas le texte', () {
      var ops = <Map<String, dynamic>>[
        _text("Qu'est-ce que la valeur en douane ? a-b-c. 1. un\n"),
      ];
      final String premier = _md(ops);
      for (var passe = 0; passe < 5; passe++) {
        ops = codec.decode(_md(ops));
      }
      expect(_md(ops), premier, reason: 'le Markdown doit être un point fixe');
    });

    test('le contenu de code n\'est JAMAIS échappé', () {
      final md = _md(<Map<String, dynamic>>[
        _text('a_b-c', <String, dynamic>{'code': true}),
        _text('\n'),
      ]);
      expect(md, contains('a_b-c'));
      expect(md, isNot(contains(r'\_')));
    });
  });

  group('CR-IFFD-24 §3 — les espaces sortent des marqueurs', () {
    test('🔴 `** gras **` devient ` **gras** `', () {
      final md = _md(<Map<String, dynamic>>[
        _text(' gras ', <String, dynamic>{'bold': true}),
        _text('\n'),
      ]);
      expect(md, contains('**gras**'));
      expect(md, isNot(contains('** gras **')));
    });

    test('🔴 un `_` intra-mot n\'ouvrait AUCUNE emphase — corrigé', () {
      // `a_ ital _b` n'est pas de l'italique : le round-trip perdait l'attribut.
      final rt = _rt(<Map<String, dynamic>>[
        _text('a'),
        _text(' ital ', <String, dynamic>{'italic': true}),
        _text('b\n'),
      ]);
      expect(_attr(rt, 'italic'), isTrue);
      expect(_plain(rt), contains('ital'));
    });

    test('une op entièrement blanche perd son style sans casser', () {
      final rt = _rt(<Map<String, dynamic>>[
        _text('a'),
        _text('   ', <String, dynamic>{'bold': true}),
        _text('b\n'),
      ]);
      expect(_plain(rt), contains('a'));
      expect(_plain(rt), contains('b'));
    });

    test('le souligné garde ses espaces (`<u>` les admet)', () {
      final ops = <Map<String, dynamic>>[
        _text('a'),
        _text(' soul ', <String, dynamic>{'underline': true}),
        _text('b\n'),
      ];
      // Assertion RENFORCÉE : le nom promet que les ESPACES sont gardés — il
      // faut donc les asserter, pas seulement l'attribut.
      expect(_md(ops), contains('<u> soul </u>'));
      final rt = _rt(ops);
      expect(_attr(rt, 'underline'), isTrue);
      expect(_plain(rt), contains(' soul '));
    });
  });

  group('Trouvé EN REVUE — destructions que la première version introduisait', () {
    test('🔴 `1) premier` survit — le délimiteur de liste à parenthèse', () {
      // CommonMark accepte `)` comme délimiteur ordonné au même titre que `.`.
      // L'ancien échappement traitait `(`/`)` en toute position ; l'échappement
      // contextuel les avait retirés sans les rattraper en tête de ligne, et
      // `1) premier` devenait `premier`. Forme usuelle en français administratif.
      for (final source in <String>['1) premier', '10) dixième', '99) dernier']) {
        final rt = _rt(<Map<String, dynamic>>[_text('$source\n')]);
        expect(_plain(rt).trim(), source, reason: source);
        expect(_attr(rt, 'list'), isNull, reason: source);
      }
    });

    test('🔴 `---` survit — le JUMEAU de la destruction de l\'image', () {
      // `MarkdownToDelta` construit l'embed depuis `hr`, `DeltaToMarkdown` sait
      // écrire `- - -` : le pont existait des deux côtés, exactement comme pour
      // l'image, et il était neutralisé au même endroit.
      final ops = sansPontDecode('avant\n\n---\n\naprès\n');
      expect(_hasEmbed(ops, 'divider'), isTrue);
      final md = _md(ops);
      expect(md, isNot(contains('embed:divider')));
      expect(_hasEmbed(codec.decode(md), 'divider'), isTrue);
    });

    test('🔴 un tilde SIMPLE ne barre pas — `H~2~O`, `CO~2~`', () {
      // `md.StrikethroughSyntax` accepte le tilde simple (DelimiterTag('del',1)).
      // Un corpus legacy scientifique aurait été muté en `H~~2~~O`.
      for (final source in <String>['H~2~O', 'CO~2~', 'plage ~5~10 kg']) {
        final ops = codec.decode(source);
        expect(_attr(ops, 'strike'), isNull, reason: source);
        expect(_plain(ops).trim(), source, reason: source);
      }
    });

    test('le tilde DOUBLE barre toujours (la capacité demandée est intacte)', () {
      expect(_attr(codec.decode('texte ~~barré~~ fin'), 'strike'), isTrue);
    });

    test('🔴 un marqueur non fermé ne déborde pas sur tout le document', () {
      // Un `<u>` orphelin soulignait TOUS les paragraphes suivants.
      final ops = codec.decode('<u>ouvert sans fin\n\nparagraphe suivant\n');
      final suite = ops.where(
        (op) => (op['insert'] as Object?).toString().contains('suivant'),
      );
      expect(suite, isNotEmpty);
      for (final op in suite) {
        final Object? attrs = op['attributes'];
        expect(attrs is Map && attrs.containsKey('underline'), isFalse,
            reason: 'le soulignement ne doit pas franchir le bloc');
      }
    });

    test('🔴 une date ou un décimal en tête de ligne n\'est plus échappé', () {
      // Sur-échappement résiduel : CommonMark exige une espace après le
      // délimiteur, donc `12.05.2024` n'ouvre aucune liste.
      for (final source in <String>['12.05.2024', '3.14 environ', '#hashtag']) {
        expect(_md(<Map<String, dynamic>>[_text('$source\n')]),
            startsWith(source),
            reason: source);
      }
    });

    test('mais un VRAI ouvreur de bloc reste échappé (espace exigée)', () {
      for (final source in <String>['1. item', '1) item', '- item', '# titre']) {
        final rt = _rt(<Map<String, dynamic>>[_text('$source\n')]);
        expect(_plain(rt).trim(), source, reason: source);
      }
    });

    test('`>cite` reste échappé même SANS espace (citation valide)', () {
      expect(_plain(_rt(<Map<String, dynamic>>[_text('>cite\n')])).trim(),
          '>cite');
    });
  });

  group('Non-régression du sous-ensemble déjà acquis', () {
    test('une TABLE Markdown n\'est JAMAIS mutilée en `ab12`', () {
      // Point décisif, et il tient toujours : `gitHubFlavored` aplatissait la
      // table en `ab12`. Depuis la v0.8.0 elle devient un vrai tableau, mais le
      // refus de la MUTILER est inchangé — c'est ce que ce test verrouille.
      final ops = codec.decode('| a | b |\n|---|---|\n| 1 | 2 |');
      expect(_plain(ops), isNot(contains('ab12')));
      final Map<dynamic, dynamic> insert = ops
          .map((op) => op['insert'])
          .whereType<Map<dynamic, dynamic>>()
          .firstWhere((m) => m.containsKey('table'),
              orElse: () => <String, dynamic>{});
      expect(insert['table'], isNotNull,
          reason: 'un tableau bien formé devient un tableau');
    });

    test('un bloc de pipes SANS séparateur reste du texte intact', () {
      final texte = _plain(codec.decode('| juste | des pipes |\n| encore |'));
      expect(texte, contains('|'), reason: 'les séparateurs doivent survivre');
      expect(texte, contains('juste'));
    });

    test('une URL nue n\'est PAS transformée en lien (autolink non activé)', () {
      expect(_attr(codec.decode('voir https://exemple.test/page'), 'link'),
          isNull);
    });

    for (final cas in <String, Map<String, dynamic>>{
      'gras': <String, dynamic>{'bold': true},
      'italique': <String, dynamic>{'italic': true},
      'code inline': <String, dynamic>{'code': true},
      'lien': <String, dynamic>{'link': 'https://exemple.test'},
    }.entries) {
      test('${cas.key} conservé', () {
        final rt = _rt(<Map<String, dynamic>>[
          _text('valeur', cas.value),
          _text('\n'),
        ]);
        expect(_attr(rt, cas.value.keys.first), cas.value.values.first);
      });
    }

    test('bloc de code et citation conservés', () {
      expect(
        _attr(
          _rt(<Map<String, dynamic>>[
            _text('var x = 1;'),
            _text('\n', <String, dynamic>{'code-block': true}),
          ]),
          'code-block',
        ),
        isTrue,
      );
      expect(
        _attr(
          _rt(<Map<String, dynamic>>[
            _text('citation'),
            _text('\n', <String, dynamic>{'blockquote': true}),
          ]),
          'blockquote',
        ),
        isTrue,
      );
    });

    test('AD-10 : entrées corrompues → jamais de throw', () {
      for (final Object? entree in <Object?>[
        null,
        '',
        '   ',
        42,
        <Object?>[1, 2],
        <String, dynamic>{'pas': 'un delta'},
      ]) {
        expect(() => codec.decode(entree), returnsNormally,
            reason: 'entrée $entree');
      }
      expect(codec.encode(const <Map<String, dynamic>>[]), '');
    });
  });
}
