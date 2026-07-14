/// Tests de [normalizeNoteContentOps] — **le cœur d'ES-2.2** (AC3, AC4, D5).
///
/// La matrice D5 est reproduite **ligne par ligne**. Le cas capital : une `String`
/// markdown legacy (lex) **NE DOIT JAMAIS** décoder sur `[]` — le premier `put`
/// persisterait le vide et **détruirait irréversiblement le corps de la note**.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zcrud_note/zcrud_note.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // AC4 — LA MATRICE D5, cas par cas.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC4 / D5 — matrice de coercition du contenu', () {
    test('absente / `null` ⇒ []', () {
      expect(normalizeNoteContentOps(null), isEmpty);
    });

    test('`List` native d\'ops valides ⇒ IDENTITÉ (ops verbatim)', () {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'a\n'},
      ];
      expect(normalizeNoteContentOps(ops), equals(ops));
    });

    test('ops avec ATTRIBUTS ⇒ identité (attributs préservés)', () {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': 'gras',
          'attributes': <String, dynamic>{'bold': true},
        },
        <String, dynamic>{'insert': '\n'},
      ];
      expect(normalizeNoteContentOps(ops), equals(ops));
    });

    test('🔴 EMBED OPAQUE (formule LaTeX) ⇒ IDENTITÉ — l\'embed SURVIT', () {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'formula': 'x^2'},
        },
      ];
      final out = normalizeNoteContentOps(ops);
      expect(out, hasLength(1));
      expect(out.first['insert'], <String, dynamic>{'formula': 'x^2'});
    });

    test('`String` JSON de Delta (ZDeltaCodec.encode / corpus IFFD) ⇒ ops', () {
      const raw = '[{"insert":"a\\n"}]';
      expect(
        normalizeNoteContentOps(raw),
        equals(<Map<String, dynamic>>[
          <String, dynamic>{'insert': 'a\n'},
        ]),
      );
    });

    test(
        '🔴 `String` MARKDOWN (lex) ⇒ TEXTE VERBATIM, JAMAIS [] — le cas '
        'DESTRUCTEUR que D5 ferme', () {
      const raw = '# Titre\n**gras**';
      final out = normalizeNoteContentOps(raw);

      expect(
        out,
        equals(<Map<String, dynamic>>[
          <String, dynamic>{'insert': '# Titre\n**gras**\n'},
        ]),
        reason:
            'lex persiste `content` en `String` MARKDOWN. Le repli « naturel » '
            'de `DeltaNeutralOps.asDeltaOps` (`null` ⇒ `[]`) ferait décoder LE '
            'VIDE, et le premier `put` persisterait ce vide : PERTE '
            'IRRÉVERSIBLE du corps de la note.',
      );
      // Anti-vacuité : le texte source est INTÉGRALEMENT retrouvable.
      expect(out.single['insert'] as String, contains('# Titre'));
      expect(out.single['insert'] as String, contains('**gras**'));
    });

    test('🔴 `String` texte plat (sticky-note IFFD) ⇒ texte verbatim', () {
      expect(
        normalizeNoteContentOps('note collante'),
        equals(<Map<String, dynamic>>[
          <String, dynamic>{'insert': 'note collante\n'},
        ]),
      );
    });

    test('`\\n` final GARANTI (et jamais doublé)', () {
      expect(normalizeNoteContentOps('a').single['insert'], 'a\n');
      expect(normalizeNoteContentOps('a\n').single['insert'], 'a\n');
    });

    test('`String` vide / blanche ⇒ []', () {
      expect(normalizeNoteContentOps(''), isEmpty);
      expect(normalizeNoteContentOps('   '), isEmpty);
      expect(normalizeNoteContentOps('\n\t '), isEmpty);
    });

    test('types non interprétables (`int`, `Map`, `bool`) ⇒ []', () {
      expect(normalizeNoteContentOps(42), isEmpty);
      expect(normalizeNoteContentOps(<String, dynamic>{'a': 1}), isEmpty);
      expect(normalizeNoteContentOps(true), isEmpty);
    });

    test('`List` SANS AUCUN CONTENU ⇒ [] (rien à préserver : aucun `insert`)',
        () {
      // ⚠️ CES DEUX LIGNES SEULEMENT sont légitimement `[]` : la liste ne porte
      // NI op `insert`, NI texte. C'est le SEUL cas où la prémisse « une liste
      // n'est pas du texte » est vraie (HIGH-1 : elle était généralisée à TORT).
      expect(normalizeNoteContentOps(<Object?>[]), isEmpty);
      expect(normalizeNoteContentOps(<Object?>[1, 2]), isEmpty);
      expect(
        normalizeNoteContentOps(<Object?>[
          <String, dynamic>{'retain': 1},
        ]),
        isEmpty,
        reason: 'une op sans `insert` est une op de DIFF : elle ne porte AUCUN '
            'contenu dans un document au repos.',
      );
    });

    // ═════════════════════════════════════════════════════════════════════════
    // 🔴 HIGH-1 (code-review ES-2.2) — LA LIGNE MANQUANTE DE LA MATRICE, celle
    // qui PERDAIT LA DONNÉE. Le test de la v1 ASSERTAIT la destruction :
    //
    //     expect(normalizeNoteContentOps([{'insert': 'ok\n'}, 'pas une op']),
    //            isEmpty);   // ⛔ « vert » = le corps de la note est DÉTRUIT
    //
    // La matrice censée fermer le piège de perte de données en CERTIFIAIT une.
    // ═════════════════════════════════════════════════════════════════════════
    group('🔴 HIGH-1 — `List` PARTIELLEMENT valide : les `insert` SURVIVENT', () {
      test('une op parasite (`retain`) n\'emporte PLUS le corps de la note', () {
        const corps = 'Le corps entier de la note, 5000 mots...\n';
        final out = normalizeNoteContentOps(<Object?>[
          <String, dynamic>{'insert': corps}, // ← contenu RÉEL
          <String, dynamic>{'retain': 1}, // ← 1 élément parasite
        ]);
        expect(
          out,
          equals(<Map<String, dynamic>>[
            <String, dynamic>{'insert': corps},
          ]),
          reason: '🔴 la v1 rendait `[]` — PERTE TOTALE du corps à cause d\'UNE '
              'op de diff. L\'ASYMÉTRIE le prouvait : le MÊME contenu présenté '
              'en `String` était, lui, intégralement préservé.',
        );
      });

      test('un `null` en queue de tableau (écriture partielle) ⇒ corps préservé',
          () {
        final out = normalizeNoteContentOps(<Object?>[
          <String, dynamic>{'insert': 'corps preservé ?\n'},
          null,
        ]);
        expect(out.single['insert'], 'corps preservé ?\n');
      });

      test('un fragment TEXTE dans la liste est PRÉSERVÉ (D5 vaut aussi ici)',
          () {
        final out = normalizeNoteContentOps(<Object?>[
          <String, dynamic>{'insert': 'ok\n'},
          'pas une op', // ← du TEXTE : on ne détruit JAMAIS du texte (D5)
        ]);
        expect(out, hasLength(2));
        expect(out.first['insert'], 'ok\n');
        expect(out.last['insert'], 'pas une op\n');
      });

      test('les EMBEDS opaques survivent au voisinage d\'une op parasite', () {
        final out = normalizeNoteContentOps(<Object?>[
          <String, dynamic>{
            'insert': <String, dynamic>{'formula': 'x^2'},
          },
          <String, dynamic>{'delete': 3},
          <String, dynamic>{'insert': '\n'},
        ]);
        expect(out, hasLength(2));
        expect(out.first['insert'], <String, dynamic>{'formula': 'x^2'});
        expect(out.last['insert'], '\n');
      });

      test('IDEMPOTENCE sur une liste partiellement valide', () {
        final raw = <Object?>[
          <String, dynamic>{'insert': 'a\n'},
          <String, dynamic>{'retain': 1},
          'texte',
          42,
        ];
        final une = normalizeNoteContentOps(raw);
        final deux = normalizeNoteContentOps(une);
        expect(deux, equals(une));
        expect(noteContentEquals(deux, une), isTrue);
      });

      test('🔴 INVARIANT ABSOLU : aucune forme portant du CONTENU ne rend `[]`',
          () {
        final formesAvecContenu = <Object?>[
          'texte plat',
          '# markdown',
          '[1,2]',
          '{}',
          '[ceci "insert" n\'est pas du JSON',
          '[{"insert":"a\\n"}]',
          <Object?>[
            <String, dynamic>{'insert': 'a\n'},
          ],
          <Object?>[
            <String, dynamic>{'insert': 'a\n'},
            <String, dynamic>{'retain': 1},
          ],
          <Object?>[
            <String, dynamic>{'insert': 'a\n'},
            null,
          ],
          <Object?>[
            <String, dynamic>{'insert': 'a\n'},
            'fragment',
          ],
          <Object?>[
            <Object?, Object?>{'insert': 'clés Hive'},
          ],
          <Object?>[
            <String, dynamic>{
              'insert': <String, dynamic>{'formula': 'x^2'},
            },
            <String, dynamic>{'delete': 1},
          ],
          <Object?>['fragment seul'],
        ];
        for (final forme in formesAvecContenu) {
          expect(
            normalizeNoteContentOps(forme),
            isNotEmpty,
            reason: '⛔ PERTE DE DONNÉES : `$forme` porte du contenu et a été '
                'coercée en `[]`.',
          );
        }
      });
    });

    test('🔵 L1 — le résultat est NON MODIFIABLE (vide COMME plein)', () {
      final vide = normalizeNoteContentOps(null);
      final plein = normalizeNoteContentOps('# T');
      expect(
        () => vide.add(<String, dynamic>{'insert': 'x'}),
        throwsUnsupportedError,
      );
      expect(
        () => plein.add(<String, dynamic>{'insert': 'x'}),
        throwsUnsupportedError,
        reason: 'L1 : la v1 rendait une liste GROWABLE sur la branche pleine et '
            'une `const []` sur la branche vide — une note vide et une note '
            'pleine n\'avaient pas le même contrat.',
      );
    });

    test('clés d\'op coercées en `String` (Map relue de Hive/JSON)', () {
      final hiveLike = <Object?>[
        <Object?, Object?>{'insert': 'a\n'},
      ];
      expect(
        normalizeNoteContentOps(hiveLike),
        equals(<Map<String, dynamic>>[
          <String, dynamic>{'insert': 'a\n'},
        ]),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC4 / AD-10 — AUCUNE entrée ne fait THROW. Jamais.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC4 / AD-10 — la fonction est TOTALE : aucune entrée ne throw', () {
    final entrees = <Object?>[
      null,
      '',
      '   ',
      42,
      -1,
      3.14,
      true,
      'texte',
      '# markdown',
      '[',
      '[}',
      '{"insert":"a"}',
      '[{"insert":"a\\n"}]',
      '[1,2]',
      '"just a json string"',
      'null',
      <Object?>[],
      <Object?>[1, 2],
      <Object?>[
        <String, dynamic>{'retain': 1},
      ],
      <String, dynamic>{'a': 1},
      <Object?>[
        <String, dynamic>{'insert': 'ok\n'},
      ],
      <Object?>[null],
      <Object?>[
        <Object?, Object?>{1: 'clé non-String', 'insert': 'x'},
      ],
    ];

    for (var i = 0; i < entrees.length; i++) {
      final e = entrees[i];
      test('[$i] `${_label(e)}` ne throw pas et rend des ops valides', () {
        late final List<Map<String, dynamic>> out;
        expect(() => out = normalizeNoteContentOps(e), returnsNormally);
        // Post-condition : le résultat est TOUJOURS une liste d'ops valides.
        for (final op in out) {
          expect(op.containsKey('insert'), isTrue);
        }
      });
    }

    test('un JSON valide mais NON-Delta (`\'[1,2]\'`) reste du TEXTE (préservé)',
        () {
      // Ce n'est pas du Delta ⇒ c'est du texte. La règle est TOTALE : on ne
      // détruit JAMAIS une `String`.
      expect(
        normalizeNoteContentOps('[1,2]'),
        equals(<Map<String, dynamic>>[
          <String, dynamic>{'insert': '[1,2]\n'},
        ]),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC4 — IDEMPOTENCE : normaliser deux fois == normaliser une fois.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC4 — normalisation IDEMPOTENTE (sur CHAQUE ligne de la matrice)', () {
    final matrice = <String, Object?>{
      'null': null,
      'ops natives': <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'a\n'},
      ],
      'embed opaque': <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'formula': 'x^2'},
        },
      ],
      'String JSON Delta': '[{"insert":"a\\n"}]',
      'markdown lex': '# Titre\n**gras**',
      'sticky IFFD': 'note collante',
      'String vide': '',
      'String blanche': '   ',
      'int': 42,
      'Map': <String, dynamic>{'a': 1},
      'List sans contenu': <Object?>[1, 2],
      'op sans insert': <Object?>[
        <String, dynamic>{'retain': 1},
      ],
      // 🔴 HIGH-1 — la ligne qui manquait à la matrice : elle DOIT être
      // idempotente ET préservante (la v1 la « passait » en rendant `[]`).
      'List PARTIELLEMENT valide': <Object?>[
        <String, dynamic>{'insert': 'a\n'},
        <String, dynamic>{'retain': 1},
      ],
      'List avec fragment texte': <Object?>[
        <String, dynamic>{'insert': 'a\n'},
        'fragment',
      ],
      'List avec null': <Object?>[
        <String, dynamic>{'insert': 'a\n'},
        null,
      ],
    };

    matrice.forEach((label, raw) {
      test('$label : normalize(normalize(x)) == normalize(x)', () {
        final une = normalizeNoteContentOps(raw);
        final deux = normalizeNoteContentOps(une);
        expect(noteContentEquals(deux, une), isTrue);
        expect(deux, equals(une));
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC4 / R5 — La détection est STRUCTURELLE. JAMAIS textuelle.
  //
  // C'est LITTÉRALEMENT le code d'IFFD que zcrud refuse — répété VERBATIM en
  // 4 sites (`rich_text_editor_screen.dart:206` / `:607` /
  // `delta_to_markdown_helper.dart:39` / `editors/markdown_edition_field.dart:68`) :
  //     if (trimmedValue.startsWith('[') && trimmedValue.contains('"insert"'))
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC4 / R5 — détection STRUCTURELLE, aucune heuristique textuelle', () {
    // (Le contrôle de SOURCE — « aucun `startsWith('[')` dans lib/ » — vit dans
    // `source_policy_test.dart`, taggé `@TestOn('vm')` : il lit le disque. CE
    // fichier reste LIBRE de `dart:io` pour que la matrice D5 soit rejouée EN JS
    // par `gate:web` — `normalizeNoteContentOps` repose sur `jsonDecode`.)

    test('une String qui RESSEMBLE à du Delta mais n\'en est pas ⇒ TEXTE', () {
      // Passe l'heuristique d'IFFD (`[` + `"insert"`), mais N'EST PAS du JSON.
      const piege = '[ceci "insert" n\'est pas du JSON';
      final out = normalizeNoteContentOps(piege);
      expect(out.single['insert'], '$piege\n',
          reason: 'l\'heuristique d\'IFFD l\'aurait pris pour du Delta ; le '
              'décodage structurel le reconnaît comme du TEXTE et le préserve.');
    });

    test('une String Delta SANS crochet en tête (espaces) est reconnue', () {
      // L'heuristique d'IFFD (`startsWith('[')` sur `trim()`) marche ici, mais
      // une VRAIE preuve : on décode par la STRUCTURE, pas par le 1er caractère.
      const ops = '  [{"insert":"a\\n"}]  ';
      expect(normalizeNoteContentOps(ops), hasLength(1));
      expect(normalizeNoteContentOps(ops).single['insert'], 'a\n');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC3 — IDENTITÉ de type avec la valeur neutre de `ZCodec`/`ZMarkdownField`.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC3 / D3(3) — pont ES-6.1 : IDENTITÉ, aucune conversion', () {
    test('le contenu EST une `List<Map<String, dynamic>>` (valeur neutre)', () {
      final note = ZSmartNote.fromMap(<String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'a\n'},
        ],
      });
      // C'est EXACTEMENT le type de la « valeur neutre » de `ZCodec` /
      // `ZMarkdownField` (`List<Map<String, dynamic>>` d'ops Delta) : ES-6.1
      // branchera `note.content` sur l'éditeur SANS transformer quoi que ce soit.
      expect(note.content, isA<List<Map<String, dynamic>>>());
      // Et il est JSON-safe (aucun type Quill/Flutter n'a fuité dans le domaine).
      expect(() => jsonEncode(note.content), returnsNormally);
    });

  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Égalité / hash PROFONDS (sans eux, `==` casse entre mémoire et store).
  // ═══════════════════════════════════════════════════════════════════════════
  group('noteContentEquals / noteContentHash — profondeur', () {
    test('deux contenus structurellement égaux mais NON identiques sont ==', () {
      final a = normalizeNoteContentOps('[{"insert":"a\\n"}]');
      final b = normalizeNoteContentOps(<Map<String, dynamic>>[
        <String, dynamic>{'insert': 'a\n'},
      ]);
      expect(identical(a, b), isFalse);
      expect(noteContentEquals(a, b), isTrue);
      expect(noteContentHash(a), noteContentHash(b));
    });

    test('un embed imbriqué différent casse l\'égalité', () {
      final a = normalizeNoteContentOps(<Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'formula': 'x^2'},
        },
      ]);
      final b = normalizeNoteContentOps(<Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'formula': 'y^2'},
        },
      ]);
      expect(noteContentEquals(a, b), isFalse);
    });

    test('l\'ORDRE des ops est signifiant', () {
      final a = normalizeNoteContentOps(<Map<String, dynamic>>[
        <String, dynamic>{'insert': 'a'},
        <String, dynamic>{'insert': 'b\n'},
      ]);
      final b = normalizeNoteContentOps(<Map<String, dynamic>>[
        <String, dynamic>{'insert': 'b'},
        <String, dynamic>{'insert': 'a\n'},
      ]);
      expect(noteContentEquals(a, b), isFalse);
    });
  });
}

String _label(Object? v) {
  final s = v is String ? "'$v'" : '$v';
  return s.length > 40 ? '${s.substring(0, 40)}…' : s;
}
