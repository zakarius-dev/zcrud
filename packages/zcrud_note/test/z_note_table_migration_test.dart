// Migrateur legacy → contenu canonique (ES-6.2, FR-S25). Priorité au POUVOIR
// DISCRIMINANT (R12) : AC2 (préservation table), AC3 (prose/ordre), AC5
// (DÉFENSIF malformé), puis AC4 (sticky verbatim), AC6 (idempotence), AC7 (no-dup).
import 'package:test/test.dart';
// kTableEmbedType : lu pour inspecter la structure produite (source unique).
import 'package:zcrud_markdown/zcrud_markdown.dart' show kTableEmbedType;
import 'package:zcrud_note/zcrud_note.dart';

/// Vrai si [op] est une op EMBED (`insert` = `Map`).
bool _isEmbed(Map<String, dynamic> op) => op['insert'] is Map;

/// Ops embed d'un contenu.
List<Map<String, dynamic>> _embeds(List<Map<String, dynamic>> ops) =>
    ops.where(_isEmbed).toList();

/// Concaténation VERBATIM de tout le texte (ops `insert` = `String`).
String _allText(List<Map<String, dynamic>> ops) => ops
    .where((op) => op['insert'] is String)
    .map((op) => op['insert'] as String)
    .join();

/// Matrice `cells` d'une op embed tableau.
List<List<String>> _cellsOf(Map<String, dynamic> embed) {
  final table = (embed['insert'] as Map)[kTableEmbedType] as Map;
  return <List<String>>[
    for (final row in table['cells'] as List)
      <String>[for (final c in row as List) c as String],
  ];
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // AC2 — table GFM `String` → structure {rows,columns,cells} SANS PERTE.
  // ══════════════════════════════════════════════════════════════════════════
  group('AC2 — migration table GFM sans perte', () {
    test('une table simple devient EXACTEMENT une op embed, header conservé, '
        'séparateur NON compté comme donnée', () {
      final ops = zUpgradeLegacyNoteContent('| a | b |\n|---|---|\n| 1 | 2 |');
      final embeds = _embeds(ops);
      expect(embeds, hasLength(1),
          reason: 'exactement UNE op embed table.');
      expect(
        _cellsOf(embeds.single),
        equals(<List<String>>[
          <String>['a', 'b'], // en-tête = 1re ligne
          <String>['1', '2'], // le séparateur |---| n'est PAS une donnée
        ]),
        reason: 'aucune cellule perdue/dupliquée ; jamais la ligne "---".',
      );
    });

    test('table à 3 colonnes / 2 lignes de données : toutes les cellules', () {
      final ops = zUpgradeLegacyNoteContent(
          '| a | b | c |\n|---|---|---|\n| 1 | 2 | 3 |\n| 4 | 5 | 6 |');
      expect(
        _cellsOf(_embeds(ops).single),
        equals(<List<String>>[
          <String>['a', 'b', 'c'],
          <String>['1', '2', '3'],
          <String>['4', '5', '6'],
        ]),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AC3 — prose environnante + ORDRE préservés.
  // ══════════════════════════════════════════════════════════════════════════
  group('AC3 — prose & ordre préservés', () {
    test('Intro avant, Outro après l\'embed, texte VERBATIM, ordre intact', () {
      final ops = zUpgradeLegacyNoteContent(
          'Intro\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nOutro');
      // Un seul embed.
      final embedIndex = ops.indexWhere(_isEmbed);
      expect(embedIndex, greaterThan(-1), reason: 'la table doit être structurée.');
      expect(_embeds(ops), hasLength(1));

      // Prose AVANT porte Intro ; prose APRÈS porte Outro.
      final before = ops.sublist(0, embedIndex);
      final after = ops.sublist(embedIndex + 1);
      expect(_allText(before), contains('Intro'),
          reason: 'Intro doit précéder l\'embed.');
      expect(_allText(after), contains('Outro'),
          reason: 'Outro doit suivre l\'embed.');

      // Verbatim global + ordre Intro < Outro.
      final all = _allText(ops);
      expect(all, contains('Intro'));
      expect(all, contains('Outro'));
      expect(all.indexOf('Intro'), lessThan(all.indexOf('Outro')));
    });

    test('deux tables séparées par de la prose : ordre & structure préservés', () {
      final ops = zUpgradeLegacyNoteContent(
          'A\n| x |\n|---|\nB\n| y |\n|---|\nC');
      expect(_embeds(ops), hasLength(2));
      final txt = _allText(ops);
      expect(txt.indexOf('A'), lessThan(txt.indexOf('B')));
      expect(txt.indexOf('B'), lessThan(txt.indexOf('C')));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AC5 — DÉFENSIF (AD-10) : malformé → TEXTE verbatim, jamais throw/embed jagged.
  // ══════════════════════════════════════════════════════════════════════════
  group('AC5 — table malformée PRÉSERVÉE comme texte (DÉFENSIF)', () {
    test('largeurs incohérentes (header 3 / sep 2) → AUCUN embed, texte verbatim',
        () {
      const raw = '| a | b | c |\n|---|---|\n| 1 | 2 |';
      final ops = zUpgradeLegacyNoteContent(raw);
      expect(_embeds(ops), isEmpty,
          reason: 'header/sep divergents ⇒ jamais structuré.');
      expect(_allText(ops), contains(raw),
          reason: 'le bloc malformé SURVIT VERBATIM (aucun caractère perdu).');
    });

    test('pas de séparateur (`| seul |`) → AUCUN embed, texte verbatim', () {
      const raw = '| seul |';
      final ops = zUpgradeLegacyNoteContent(raw);
      expect(_embeds(ops), isEmpty);
      expect(_allText(ops), contains(raw));
    });

    test('AUCUN throw sur des entrées limites (vide, pipes nus, séparateur seul)',
        () {
      for (final raw in const <String>[
        '',
        '|',
        '|---|',
        '||',
        '| a |\n| b |', // deux lignes pipe SANS séparateur
      ]) {
        expect(() => zUpgradeLegacyNoteContent(raw), returnsNormally,
            reason: 'entrée "$raw" ne doit jamais lever.');
        // Aucune de ces entrées n'est une table VALIDE ⇒ aucun embed.
        expect(_embeds(zUpgradeLegacyNoteContent(raw)), isEmpty);
      }
    });

    test('ligne de données jagged : la table s\'arrête, la ligne reste en TEXTE '
        '(jamais paddée dans l\'embed)', () {
      // header 2 / sep 2 / data 2 OK / data "| 3 |" (1 cellule) → hors table.
      final ops = zUpgradeLegacyNoteContent(
          'Intro\n| a | b |\n|---|---|\n| 1 | 2 |\n| 3 |\nOutro');
      expect(_embeds(ops), hasLength(1));
      expect(
        _cellsOf(_embeds(ops).single),
        equals(<List<String>>[
          <String>['a', 'b'],
          <String>['1', '2'],
        ]),
        reason: 'la ligne jagged "| 3 |" n\'est JAMAIS paddée dans l\'embed.',
      );
      expect(_allText(ops), contains('| 3 |'),
          reason: 'la ligne jagged SURVIT en texte (préservation AD-10).');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AC4 — sticky-note texte plat → Delta neutre VERBATIM (délègue à normalize).
  // ══════════════════════════════════════════════════════════════════════════
  group('AC4 — sticky-note upgrade verbatim', () {
    test('texte plat → [{insert: "<raw>\\n"}], jamais []', () {
      final ops = zMigrateStickyNote('Rappel: réviser le chapitre');
      expect(ops, hasLength(1));
      expect(ops.single['insert'], 'Rappel: réviser le chapitre\n');
    });

    test('DÉLÈGUE à normalizeNoteContentOps (identité de comportement)', () {
      for (final raw in <Object?>[
        'Rappel: réviser le chapitre',
        '# Titre markdown',
        '[1,2]', // NON-Delta : préservé verbatim, jamais interprété
        '',
        null,
      ]) {
        expect(
          noteContentEquals(
              zMigrateStickyNote(raw), normalizeNoteContentOps(raw)),
          isTrue,
          reason: 'zMigrateStickyNote doit être une DÉLÉGATION pure ($raw).',
        );
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AC6 — idempotence : re-migrer un contenu déjà upgradé = NO-OP profond.
  // ══════════════════════════════════════════════════════════════════════════
  group('AC6 — idempotence', () {
    test('zMigrateNoteTables(once) == once (deep) pour du contenu mixte', () {
      final once = zUpgradeLegacyNoteContent(
          'Intro\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nOutro');
      final twice = zMigrateNoteTables(once);
      expect(noteContentEquals(once, twice), isTrue,
          reason: 'un embed déjà présent est réémis VERBATIM, jamais re-migré.');
    });

    test('un embed existant n\'est jamais ré-encapsulé ni altéré', () {
      final once = zUpgradeLegacyNoteContent('| a | b |\n|---|---|\n| 1 | 2 |');
      final twice = zMigrateNoteTables(once);
      expect(_embeds(twice), hasLength(1));
      expect(_cellsOf(_embeds(twice).single), _cellsOf(_embeds(once).single));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AC7 — pas de nouveau codec / pas de double-migration (complément au scan
  // machine de source_policy_test.dart).
  // ══════════════════════════════════════════════════════════════════════════
  group('AC7 — réutilisation, jamais de double structuration', () {
    test('un contenu déjà structuré (List<Map> avec embed) n\'est PAS re-scanné',
        () {
      // Op embed opaque déjà présente + texte SANS table : passthrough + texte.
      final input = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{
            'table': <String, dynamic>{
              'rows': 1,
              'columns': 1,
              'cells': <List<String>>[
                <String>['keep'],
              ],
            },
          },
        },
        <String, dynamic>{'insert': 'texte simple\n'},
      ];
      final out = zMigrateNoteTables(input);
      expect(_embeds(out), hasLength(1),
          reason: 'aucune nouvelle op embed créée (le texte n\'a pas de table).');
      expect(_cellsOf(_embeds(out).single), equals(<List<String>>[
        <String>['keep'],
      ]));
      expect(_allText(out), 'texte simple\n');
    });
  });
}
