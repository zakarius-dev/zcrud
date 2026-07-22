/// Échappement Markdown **contextuel** et normalisation des marqueurs
/// d'emphase — réponse à CR-IFFD-23 §2 et CR-IFFD-24 §3.
///
/// Interne à `zcrud_markdown` (aucun symbole exporté par le barrel).
library;

import 'package:flutter_quill/flutter_quill.dart';

/// Caractères dangereux **en toute position** : ils réouvriraient une emphase,
/// un lien, du code ou une balise au décodage, où qu'ils se trouvent dans la
/// ligne. `~` en fait partie depuis que le décodeur sait lire `~~` (GFM) : sans
/// lui, un texte contenant littéralement `~~mot~~` ressortirait BARRÉ.
const String _kInlineDangerous = r'\\`*_[]<~';

/// Ouvreurs de **bloc**. Ils ne sont ambigus qu'en **tête de ligne** — c'est
/// tout le grief de CR-IFFD-23 §2.
///
/// Deux formes distinctes, et la distinction compte :
/// - `<chiffres>.` ou `<chiffres>)` — liste ordonnée. CommonMark accepte les
///   DEUX délimiteurs ; oublier `)` détruisait `1) premier` (la numérotation
///   usuelle en français administratif), qui survivait en v0.6.0 parce que
///   l'ancien échappement traitait `(` et `)` en toute position.
/// - `-`/`+`/`*` (puce), `>` (citation), `#` (titre) — seuls en tête de ligne.
///
/// Le délimiteur est échappé APRÈS les chiffres, car Markdown n'admet pas
/// l'échappement d'un chiffre : `\1. item` ressort littéralement `\1. item`,
/// alors que `1\. item` ressort `1. item`. Mesuré.
///
/// `)` n'est PAS échappé seul : hors d'une numérotation il n'ouvre aucun bloc,
/// et l'échapper partout ramènerait le bruit que la CR dénonce.
///
/// Une **espace** (ou une fin de ligne) est exigée après le délimiteur, comme
/// CommonMark l'exige lui-même : `12.05.2024` et `#hashtag` n'ouvrent aucun
/// bloc et n'ont donc pas à être échappés — c'était du sur-échappement résiduel,
/// exactement le grief de la CR. Le `>` fait exception : `>cite` est une
/// citation valide sans espace.
final RegExp _kBlockOpener =
    RegExp(r'^(\s*)(?:(\d+)([.)])(?=\s|$)|([-+*#])(?=\s|$)|(>))');

/// Échappement **contextuel** : remplace `DeltaToMarkdown.escapeSpecialCharacters`
/// (qui échappe 18 caractères sans regarder leur position, d'où le
/// `Qu'est\-ce que` dénoncé par IFFD).
///
/// Règle : les caractères ambigus *inline* sont échappés partout ; les ouvreurs
/// de **bloc** ne le sont qu'en tête de ligne (`text.offset == 0`, position
/// mesurée DANS la ligne, pas dans le document). Le contenu de code (inline ou
/// bloc) n'est jamais échappé — parité avec le handler d'origine.
///
/// [extraDangerous] — caractères que les **ponts déclarés** rendent
/// significatifs. C'est l'application de la règle « échapper ce que le décodeur
/// sait relire » : sans elle, déclarer un pont `$…$` transformerait un prix
/// `5$ … 9$` en formule. La règle a été posée pour `~` puis oubliée pour les
/// ponts — les deux corrections avaient été conçues séparément.
void Function(QuillText, StringSink) zMarkdownContentEscaper({
  Set<String> extraDangerous = const <String>{},
}) {
  final chars = <String>{
    ..._kInlineDangerous.split(''),
    ...extraDangerous.expand((s) => s.split('')),
  };
  final inline = RegExp('[${RegExp.escape(chars.join())}]');
  return (QuillText text, StringSink out) {
    final style = text.style;
    final bool inCode = style.containsKey(Attribute.codeBlock.key) ||
        style.containsKey(Attribute.inlineCode.key) ||
        (text.parent?.style.containsKey(Attribute.codeBlock.key) ?? false);
    var content = text.value;
    if (!inCode) {
      content = content.replaceAllMapped(inline, (match) => '\\${match[0]}');
      if (text.offset == 0) {
        content = content.replaceFirstMapped(_kBlockOpener, (match) {
          final String indent = match[1] ?? '';
          // Liste ordonnée : `1.` / `1)` → `1\.` / `1\)`.
          if (match[2] != null) return '$indent${match[2]}\\${match[3]}';
          return '$indent\\${match[4] ?? match[5]}';
        });
      }
    }
    out.write(content);
  };
}

/// Attributs dont le marqueur Markdown **encadre** le contenu et n'admet donc
/// pas d'espace collé au marqueur (`** gras **` n'est pas du gras ; pire,
/// `a_ ital _b` n'est pas de l'italique du tout — un `_` intra-mot n'ouvre
/// aucune emphase). CR-IFFD-24 §3.
///
/// `underline` est ABSENT à dessein : il est porté par `<u>…</u>`, où l'espace
/// interne est parfaitement licite.
const Set<String> _kSpaceSensitiveAttrs = <String>{
  'bold',
  'italic',
  'strike',
  'code',
};

/// Sort les espaces de **bord** hors des marqueurs d'emphase, en les reportant
/// dans des ops non stylées adjacentes (CR-IFFD-24 §3).
///
/// `[{' gras ', bold}]` devient `[{' '}, {'gras', bold}, {' '}]`, ce qui encode
/// en `** gras **` → ` **gras** `. Une op entièrement blanche perd simplement
/// son style (aucun marqueur à poser autour de rien). Les ops embed et les ops
/// sans attribut sensible traversent **à l'identique**.
List<Map<String, dynamic>> zMoveSpacesOutOfMarkers(
  List<Map<String, dynamic>> ops,
) {
  var touched = false;
  final result = <Map<String, dynamic>>[];
  for (final op in ops) {
    final Object? insert = op['insert'];
    final Object? rawAttrs = op['attributes'];
    if (insert is! String ||
        insert.isEmpty ||
        rawAttrs is! Map<String, dynamic> ||
        !rawAttrs.keys.any(_kSpaceSensitiveAttrs.contains)) {
      result.add(op);
      continue;
    }
    final String trimmed = insert.trim();
    if (trimmed.length == insert.length) {
      result.add(op);
      continue;
    }
    touched = true;
    // Bornes calculées explicitement : `indexOf(trimmed)` marcherait mais
    // deviendrait faux au moindre changement de `trim()`.
    final int start = insert.length - insert.trimLeft().length;
    final String lead = insert.substring(0, start);
    final String tail = insert.substring(start + trimmed.length);
    if (lead.isNotEmpty) {
      result.add(<String, dynamic>{'insert': lead});
    }
    if (trimmed.isNotEmpty) {
      result.add(<String, dynamic>{'insert': trimmed, 'attributes': rawAttrs});
    }
    if (tail.isNotEmpty) {
      result.add(<String, dynamic>{'insert': tail});
    }
  }
  // Identité si rien n'a bougé (perf + non-régression d'identité des ops).
  return touched ? result : ops;
}
