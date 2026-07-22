/// Tableau ↔ Markdown — rendu et relecture **symétriques**, plus un repli
/// **sans perte** (suite de CR-IFFD-24 §2).
///
/// Avant ce module, un embed tableau persisté en Markdown perdait **toutes ses
/// cellules** : `encode` écrivait `[embed:table]` et le contenu disparaissait au
/// premier enregistrement. Ce n'était pas une dégradation documentée, c'était la
/// même destruction que celle de l'image.
///
/// ## Pourquoi ne pas réutiliser `EmbeddableTableSyntax` de `markdown_quill`
///
/// Mesuré : elle ne reconnaît PAS une table dont une cellule contient un `|`
/// échappé — le bloc n'est pas capté et son texte est mutilé. Or c'est
/// exactement ce que produit un rendu correct d'une cellule contenant `|`.
/// Un parseur qui ne sait pas relire ce que notre encodeur écrit rouvre le
/// défaut d'asymétrie que CR-IFFD-24 dénonce. La symétrie prime donc sur la
/// réutilisation : les deux moitiés sont écrites ici, face à face.
///
/// Interne à `zcrud_markdown` (aucun symbole exporté par le barrel).
library;

import 'dart:convert';

/// Info-string du bloc clôturé de repli, porteur de la charge JSON exacte.
const String kZTableFenceInfo = 'zcrud-table';

/// Substitut du saut de ligne dans une cellule : Markdown GFM n'exprime pas de
/// multi-ligne dans une cellule.
const String _kCellBreak = '<br>';

/// Rend [cells] en tableau GFM lisible.
///
/// Le `|` d'une cellule est échappé (`\|`), le saut de ligne devient `<br>`.
/// La première ligne sert d'en-tête — c'est la seule forme qu'un tableau GFM
/// admet, et la charge de l'embed ne distingue pas l'en-tête du corps.
String zRenderMarkdownTable(List<List<String>> cells) {
  if (cells.isEmpty || cells.first.isEmpty) return '';
  final int width = cells.first.length;
  String cell(String raw) =>
      raw.replaceAll('|', r'\|').replaceAll('\n', _kCellBreak);
  String row(List<String> r) {
    final padded = <String>[
      for (var i = 0; i < width; i++) i < r.length ? cell(r[i]) : '',
    ];
    return '| ${padded.join(' | ')} |';
  }

  final buffer = StringBuffer()
    ..writeln(row(cells.first))
    ..writeln('|${List<String>.filled(width, '---').join('|')}|');
  for (final r in cells.skip(1)) {
    buffer.writeln(row(r));
  }
  return buffer.toString();
}

/// Relit un tableau GFM en matrice, ou `null` si [raw] n'en est pas un.
///
/// Pendant EXACT de [zRenderMarkdownTable], y compris pour le `\|` échappé et le
/// `<br>` — c'est cette symétrie qui rend l'auto-vérification concluante.
List<List<String>>? zParseMarkdownTable(String raw) {
  final lines = raw.trim().split('\n');
  if (lines.length < 2) return null;
  final List<String> separator = _splitRow(lines[1]);
  if (separator.isEmpty ||
      !separator.every((s) => RegExp(r'^:?-+:?$').hasMatch(s))) {
    return null;
  }
  final header = _splitRow(lines.first);
  if (header.isEmpty) return null;
  // GFM est normatif là-dessus : l'en-tête et la ligne de délimitation doivent
  // avoir le MÊME nombre de colonnes. Sans cette exigence, un `|` non échappé
  // à l'intérieur d'une cellule — typiquement `$\left| x \right|$` dans un
  // tableau écrit à la main — était lu comme un séparateur et DÉCOUPAIT la
  // ligne (4 colonnes au lieu de 2, contenu mutilé). C'est la mutilation
  // exacte qui avait fait écarter `gitHubFlavored` ; refuser de structurer est
  // toujours préférable à structurer de travers.
  if (header.length != separator.length) return null;
  return <List<String>>[
    header,
    for (final line in lines.skip(2))
      if (line.trim().isNotEmpty) _splitRow(line),
  ];
}

/// Découpe une ligne `| a | b |` en cellules, en respectant `\|`.
List<String> _splitRow(String line) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var started = false;
  var i = 0;
  while (i < line.length) {
    final String c = line[i];
    if (c == r'\' && i + 1 < line.length && line[i + 1] == '|') {
      buffer.write('|');
      i += 2;
      continue;
    }
    if (c == '|') {
      if (started) cells.add(_restore(buffer.toString()));
      buffer.clear();
      started = true;
      i += 1;
      continue;
    }
    buffer.write(c);
    i += 1;
  }
  // Contenu après le dernier `|` : ligne sans pipe fermant (toléré).
  if (started && buffer.toString().trim().isNotEmpty) {
    cells.add(_restore(buffer.toString()));
  }
  return cells;
}

String _restore(String cell) => cell.trim().replaceAll(_kCellBreak, '\n');

/// Bloc clôturé portant la charge JSON EXACTE — repli employé quand le rendu
/// GFM ne se relit pas à l'identique. Lisible, diffable, et sans perte.
String zRenderTableFence(List<List<String>> cells) {
  final String payload = jsonEncode(cells);
  return '```$kZTableFenceInfo\n$payload\n```\n';
}

/// Relit le bloc clôturé de repli, ou `null` si [raw] n'en est pas un.
List<List<String>>? zParseTableFence(String raw) {
  final lines = raw.trim().split('\n');
  if (lines.length < 3) return null;
  if (lines.first.trim() != '```$kZTableFenceInfo') return null;
  if (lines.last.trim() != '```') return null;
  return zDecodeCells(lines.sublist(1, lines.length - 1).join('\n'));
}

/// Décode une matrice depuis du JSON, défensivement (AD-10 : jamais de throw).
List<List<String>>? zDecodeCells(String json) {
  try {
    final Object? decoded = jsonDecode(json);
    if (decoded is! List) return null;
    final cells = <List<String>>[];
    for (final Object? row in decoded) {
      if (row is! List) return null;
      cells.add(<String>[for (final Object? c in row) '$c']);
    }
    return cells.isEmpty ? null : cells;
  } on Object {
    return null;
  }
}

/// Encode une matrice en JSON (attribut d'élément Markdown interne).
String zEncodeCells(List<List<String>> cells) => jsonEncode(cells);

/// Extrait la matrice d'une charge d'embed tableau, défensivement.
///
/// Accepte la structure `{rows, columns, cells}` **gelée** produite par
/// `zTableEmbedOp` aussi bien qu'une `Map` ordinaire : `zUnmodifiableJsonMapList`
/// rend des vues non modifiables typées `Object?`, qu'un cast direct rejetterait.
List<List<String>>? zCellsOfTablePayload(Object? data) {
  if (data is! Map) return null;
  final Object? raw = data['cells'];
  if (raw is! List || raw.isEmpty) return null;
  final cells = <List<String>>[];
  for (final Object? row in raw) {
    if (row is! List) return null;
    cells.add(<String>[for (final Object? c in row) '$c']);
  }
  if (cells.first.isEmpty) return null;
  return cells;
}

/// Deux matrices portent-elles exactement le même contenu ?
///
/// C'est le juge de l'auto-vérification : si le GFM produit ne se relit pas à
/// l'identique, on bascule sur le repli plutôt que d'écrire une forme lisible
/// mais fausse.
bool zSameMatrix(List<List<String>> a, List<List<String>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) return false;
    for (var j = 0; j < a[i].length; j++) {
      if (a[i][j] != b[i][j]) return false;
    }
  }
  return true;
}

/// Rend une matrice en Markdown **en garantissant la relecture** : forme GFM
/// lisible si elle se relit à l'identique, bloc clôturé sinon.
///
/// La garantie n'est pas raisonnée, elle est **exécutée pour chaque tableau
/// écrit** — une relecture par sauvegarde, ce qui transforme « sept cas testés »
/// en « vérifié sur le tableau réel ».
String zRenderTableGuaranteed(List<List<String>> cells) {
  final String gfm = zRenderMarkdownTable(cells);
  if (gfm.isNotEmpty) {
    final List<List<String>>? reread = zParseMarkdownTable(gfm);
    if (reread != null && zSameMatrix(reread, cells)) return gfm;
  }
  return zRenderTableFence(cells);
}
