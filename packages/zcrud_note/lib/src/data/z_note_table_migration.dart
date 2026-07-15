/// Migration **legacy → contenu canonique** d'une note (ES-6.2, **FR-S25**) :
/// couche d'ADAPTATION `lib/src/data/`.
///
/// ## Ce que fait ce migrateur (portée VOLONTAIREMENT bornée)
///
/// 1. **Sticky-note** (texte plat IFFD, `TextField`) → ops Delta neutres, VERBATIM,
///    en **DÉLÉGUANT** à `normalizeNoteContentOps` (aucune coercition maison).
/// 2. **Tables markdown GFM** (`| … |` + séparateur `|---|`) noyées dans une op
///    texte → op embed **structurée** `{table:{rows,columns,cells}}`, la **prose
///    environnante et l'ordre PRÉSERVÉS**.
///
/// ## Invariants (AD-10 — DÉFENSIF & PRÉSERVANT)
///
/// - **Jamais de throw**, jamais de destruction : un bloc qui *ressemble* à une
///   table mais est **malformé** (séparateur absent/incohérent, comptes de colonnes
///   divergents, ligne isolée) **N'est PAS** structuré — son texte **survit
///   VERBATIM**. La dégradation est **BORNÉE** au bloc invalide.
/// - **Idempotence** : une op embed **déjà présente** (`insert` = `Map`) est
///   réémise VERBATIM ; `zMigrateNoteTables(zMigrateNoteTables(x))` est un NO-OP
///   profond.
///
/// ## Pureté & réutilisation (NFR-S10 / SM-S4 / AD-28)
///
/// - **AUCUN nouveau codec, AUCUNE heuristique textuelle** markdown-vs-Delta
///   (`startsWith('[')`/`contains('"insert"')` — le code d'IFFD banni). La
///   détection de table est **STRUCTURELLE** (forme pipe-table ligne à ligne).
/// - Le contrat table n'est **jamais dupliqué** : `zTableEmbedOp`/`kTableEmbedType`
///   sont **importés** de `package:zcrud_markdown` (couture NEUTRE — comblement
///   ES-6.2). Ce fichier ne connaît QUE cette couture neutre — **jamais** Flutter
///   ni Quill en direct (garde `data/`, `source_policy_test.dart`).
///
/// ## Hors périmètre (rappel)
///
/// **DW-ES22-2** (mapping de PERSISTANCE legacy IFFD : camelCase, `Timestamp`,
/// `audioText`, `subjectId`/`creatorId`…) est dû à l'**adapter `zcrud_firestore`**
/// (ES-3.5/ES-11.2, AD-27) — **jamais** ici. Ce migrateur opère sur des **ops
/// neutres déjà normalisées** (contenu), pas sur la forme de persistance.
library;

import 'package:zcrud_core/domain.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart'
    show kTableEmbedType, zTableEmbedOp;

import '../domain/z_note_content.dart';

/// Upgrade un **sticky-note** (texte plat legacy) vers des ops Delta neutres.
///
/// **DÉLÈGUE** intégralement à [normalizeNoteContentOps] (D5 — préservant) : une
/// `String` non-Delta non vide devient `[{'insert': '<raw>\n'}]` (le texte SURVIT
/// VERBATIM, **jamais `[]`**). Aucune coercition ni heuristique n'est ajoutée ici.
List<Map<String, dynamic>> zMigrateStickyNote(Object? raw) =>
    normalizeNoteContentOps(raw);

/// Upgrade STRUCTUREL des **tables markdown GFM** portées comme TEXTE dans [ops].
///
/// Parcourt les ops : chaque op **texte** (`insert` = `String`) est re-découpée en
/// (prose | table | prose | …), les blocs de table **valides** devenant des ops
/// embed via [zTableEmbedOp] (couture NEUTRE `zcrud_markdown`). Les ops **embed**
/// existantes (`insert` = `Map`) sont **conservées VERBATIM** (idempotence). Le
/// résultat est **gelé** (contrat cohérent avec `ZSmartNote.content`).
List<Map<String, dynamic>> zMigrateNoteTables(List<Map<String, dynamic>> ops) {
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
  for (final Map<String, dynamic> op in ops) {
    final Object? insert = op['insert'];
    if (insert is String) {
      _emitTextWithTables(insert, out);
    } else {
      // Op embed opaque (un tableau DÉJÀ migré porte `insert[kTableEmbedType]` ;
      // un embed LaTeX/média porte un autre type) OU op sans `insert` : réémise
      // VERBATIM (idempotence AC6 / AD-10 — jamais ré-encapsulée ni altérée).
      out.add(op);
    }
  }
  return zUnmodifiableJsonMapList(out);
}

/// Point d'entrée « corpus legacy → contenu canonique upgradé » :
/// `zMigrateNoteTables(normalizeNoteContentOps(raw))`.
///
/// [raw] = valeur `content` persistée quelconque (markdown lex, Delta JSON IFFD,
/// texte plat…). Résultat : ops neutres, tables GFM structurées, prose préservée.
List<Map<String, dynamic>> zUpgradeLegacyNoteContent(Object? raw) =>
    zMigrateNoteTables(normalizeNoteContentOps(raw));

// ─────────────────────────────── Découpage texte ↔ table ────────────────────

/// Découpe [text] en segments (prose | table GFM | prose | …) et pousse les ops
/// correspondantes dans [out], en **préservant chaque caractère de prose** et
/// **l'ordre**. Le texte brut d'un bloc de table VALIDE est le SEUL à disparaître
/// (remplacé par sa structure) ; les newlines qui l'entourent restent en prose.
void _emitTextWithTables(String text, List<Map<String, dynamic>> out) {
  final List<String> lines = text.split('\n');
  // Offset de début de chaque ligne dans [text] (join('\n') reconstruit [text]).
  final List<int> starts = <int>[];
  var offset = 0;
  for (final String line in lines) {
    starts.add(offset);
    offset += line.length + 1; // +1 : le délimiteur '\n'
  }

  var proseStart = 0; // offset où commence la prose courante
  var i = 0;
  while (i < lines.length) {
    final _TableSpan? span = _tableSpanAt(lines, i);
    if (span == null) {
      i++;
      continue;
    }
    // 1) Flush la prose AVANT la table (inclut le '\n' qui précède la table).
    final int tableStart = starts[span.start];
    if (tableStart > proseStart) {
      _addText(out, text.substring(proseStart, tableStart));
    }
    // 2) Émet la table STRUCTURÉE (couture neutre — jamais dupliquée, SM-S4).
    final Map<String, dynamic> embed = zTableEmbedOp(cells: span.cells);
    assert(
      (embed['insert']! as Map).containsKey(kTableEmbedType),
      'zTableEmbedOp doit produire une op de type kTableEmbedType (couture D1).',
    );
    out.add(embed);
    // 3) La prose reprend juste APRÈS la dernière ligne de la table (avant son
    //    '\n' final, qui appartient à la prose suivante).
    proseStart = starts[span.end] + lines[span.end].length;
    i = span.end + 1;
  }
  // Flush la prose finale (verbatim).
  if (proseStart < text.length) {
    _addText(out, text.substring(proseStart));
  }
}

/// Ajoute une op texte `{'insert': <text>}` — SKIP si vide (une op `insert` vide
/// n'a pas de sens et n'est jamais produite).
void _addText(List<Map<String, dynamic>> out, String text) {
  if (text.isEmpty) return;
  out.add(<String, dynamic>{'insert': text});
}

/// Détecte un bloc de table GFM commençant EXACTEMENT à la ligne [i].
///
/// Exigences STRICTES (sinon `null` ⇒ le bloc reste du TEXTE) :
/// - `lines[i]` est une **ligne pipe** (en-tête) ;
/// - `lines[i+1]` est une **ligne séparatrice** (`:?-+:?` par cellule) portant
///   **EXACTEMENT** le même nombre de cellules que l'en-tête ;
/// - les lignes de DONNÉES suivantes sont incluses **tant que** leur nombre de
///   cellules est **identique** (une ligne jagged **arrête** la table — elle
///   reste en prose ; jamais de matrice irrégulière structurée).
///
/// La ligne séparatrice est **consommée comme structure** (jamais une ligne de
/// données) : `end` inclut au minimum en-tête + séparateur.
_TableSpan? _tableSpanAt(List<String> lines, int i) {
  if (i + 1 >= lines.length) return null;
  final List<String>? header = _pipeCells(lines[i]);
  if (header == null) return null;
  final int? sepCount = _separatorCellCount(lines[i + 1]);
  if (sepCount == null || sepCount != header.length) return null;

  final List<List<String>> cells = <List<String>>[header];
  var end = i + 1; // le séparateur est consommé (structure), pas une donnée
  var j = i + 2;
  while (j < lines.length) {
    final List<String>? row = _pipeCells(lines[j]);
    if (row == null || row.length != header.length) break; // jagged → stop
    cells.add(row);
    end = j;
    j++;
  }
  return _TableSpan(i, end, cells);
}

/// Cellules d'une **ligne pipe** GFM (`| a | b |` → `['a', 'b']`), ou `null` si
/// [line] ne contient aucun `|` (donc pas une ligne de table).
List<String>? _pipeCells(String line) {
  final String t = line.trim();
  if (!t.contains('|')) return null;
  var body = t;
  if (body.startsWith('|')) body = body.substring(1);
  if (body.endsWith('|')) body = body.substring(0, body.length - 1);
  return <String>[for (final String c in body.split('|')) c.trim()];
}

/// Nombre de cellules d'une **ligne séparatrice** GFM (chaque cellule = `:?-+:?`),
/// ou `null` si [line] n'est pas une séparatrice valide.
int? _separatorCellCount(String line) {
  final List<String>? cells = _pipeCells(line);
  if (cells == null || cells.isEmpty) return null;
  final RegExp sep = RegExp(r'^:?-+:?$');
  for (final String c in cells) {
    if (!sep.hasMatch(c)) return null;
  }
  return cells.length;
}

/// Étendue d'un bloc de table détecté : lignes `[start, end]` (inclus) et sa
/// matrice `cells` (en-tête en 1re ligne, séparateur EXCLU).
class _TableSpan {
  const _TableSpan(this.start, this.end, this.cells);

  final int start;
  final int end;
  final List<List<String>> cells;
}
