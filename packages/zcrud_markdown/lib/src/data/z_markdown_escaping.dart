/// Échappement Markdown **contextuel** et normalisation des marqueurs
/// d'emphase.
///
/// Interne à `zcrud_markdown` (aucun symbole exporté par le barrel).
library;

import 'package:flutter_quill/flutter_quill.dart';

import '../domain/z_markdown_bridge.dart';

/// Caractères dangereux **en toute position** : ils réouvriraient une emphase,
/// un lien, du code ou une balise au décodage, où qu'ils se trouvent dans la
/// ligne. `~` en fait partie depuis que le décodeur sait lire `~~` (GFM) : sans
/// lui, un texte contenant littéralement `~~mot~~` ressortirait BARRÉ.
///
/// **`]` en est ABSENT, et ce n'est pas un oubli — c'est délibéré.**
/// L'encodeur écrivait `[1]` → `\[1\]`, or `\[…\]` est le délimiteur de **bloc
/// LaTeX** déclaré par `ZMarkdownBridges.latexBlock` : le décodeur du MÊME codec
/// relisait donc `\[1\]` en formule, puis le cycle suivant écrivait `$$1$$`. Une
/// référence juridique `[1]` devenait une formule mathématique, et la
/// dégradation **se composait** (le placeholder `\[embed:chart\]` était sa propre
/// victime). Ce n'était pas une ambiguïté de source : la séquence corruptrice
/// était **fabriquée par le codec**.
///
/// `]` seul n'ouvre RIEN en Markdown : un lien, une image ou une référence
/// exigent un `[` ouvrant — et celui-là reste échappé. Ne plus échapper `]` est
/// donc l'échappement **juste** (moins de bruit, cf.) ET la
/// garantie que l'encodeur ne peut plus fabriquer de `\[…\]`. La garde
/// symétrique côté motifs (`(?<!\\)` sur les délimiteurs `\[`/`\]`/`\(`/`\)` de
/// `ZMarkdownBridges`) couvre le seul `\]` résiduel possible, celui né d'un
/// backslash littéral doublé (`a\]` → `a\\]`).
const String _kInlineDangerous = r'\\`*_[<~';

/// Ouvreurs de **bloc**. Ils ne sont ambigus qu'en **tête de ligne** : les
/// échapper ailleurs serait du bruit inutile.
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
/// `Qu'est\-ce que` dénoncé par un consommateur legacy).
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
///
/// [latexShield] — ponts dont les régions reconnues (et acceptées par leur
/// garde) sont écrites **verbatim**, sans aucun échappement.
/// C'est la moitié ENCODAGE du bouclier littéral du chemin sans pont : sans
/// elle, `$$\int_0^1 x\,dx$$` devenait `$$\\int\_0^1 x\\,dx$$` au premier
/// enregistrement. Vide par défaut — et DOIT rester vide quand des ponts sont
/// déclarés, sinon un texte littéral `$$x$$` échapperait à l'échappement `\$`
/// qui le distingue d'une formule.
void Function(QuillText, StringSink) zMarkdownContentEscaper({
  Set<String> extraDangerous = const <String>{},
  List<ZMarkdownEmbedBridge> latexShield = const <ZMarkdownEmbedBridge>[],
}) {
  final chars = <String>{
    ..._kInlineDangerous.split(''),
    ...extraDangerous.expand((s) => s.split('')),
  };
  final inline = RegExp('[${RegExp.escape(chars.join())}]');

  String escapeSegment(String segment, {required bool atLineStart}) {
    var content =
        segment.replaceAllMapped(inline, (match) => '\\${match[0]}');
    if (atLineStart) {
      content = content.replaceFirstMapped(_kBlockOpener, (match) {
        final String indent = match[1] ?? '';
        // Liste ordonnée : `1.` / `1)` → `1\.` / `1\)`.
        if (match[2] != null) return '$indent${match[2]}\\${match[3]}';
        return '$indent\\${match[4] ?? match[5]}';
      });
    }
    return content;
  }

  return (QuillText text, StringSink out) {
    final style = text.style;
    final bool inCode = style.containsKey(Attribute.codeBlock.key) ||
        style.containsKey(Attribute.inlineCode.key) ||
        (text.parent?.style.containsKey(Attribute.codeBlock.key) ?? false);
    var content = text.value;
    if (!inCode) {
      final List<_ZShieldSpan> spans =
          _zLatexShieldSpans(content, latexShield);
      if (spans.isEmpty) {
        content = escapeSegment(content, atLineStart: text.offset == 0);
      } else {
        // Échappe SEGMENT PAR SEGMENT, les régions bouclier passant verbatim.
        // Les bornes sont mesurées sur le contenu ORIGINAL : l'échappement des
        // segments ne peut donc pas décaler les régions.
        final out2 = StringBuffer();
        var pos = 0;
        for (final span in spans) {
          if (span.start > pos) {
            out2.write(escapeSegment(
              content.substring(pos, span.start),
              atLineStart: text.offset == 0 && pos == 0,
            ));
          }
          out2.write(content.substring(span.start, span.end));
          pos = span.end;
        }
        if (pos < content.length) {
          out2.write(escapeSegment(content.substring(pos), atLineStart: false));
        }
        content = out2.toString();
      }
    }
    out.write(content);
  };
}

/// Région `[start, end)` d'un contenu textuel reconnue comme LaTeX par le
/// bouclier littéral.
final class _ZShieldSpan {
  const _ZShieldSpan(this.start, this.end);

  final int start;
  final int end;
}

/// Régions LaTeX d'un [content], mesurées avec les MÊMES motifs et la MÊME
/// garde (`acceptsMatch`) que le décodage : c'est cette symétrie qui garantit
/// que ce que l'encodeur laisse verbatim est exactement ce que le décodeur
/// relira verbatim. Priorité au PREMIER pont déclaré en cas de chevauchement —
/// même règle que la résolution des syntaxes inline au décodage.
List<_ZShieldSpan> _zLatexShieldSpans(
  String content,
  List<ZMarkdownEmbedBridge> shield,
) {
  if (shield.isEmpty) return const <_ZShieldSpan>[];
  final spans = <_ZShieldSpan>[];
  for (final bridge in shield) {
    for (final Match m in bridge.pattern.allMatches(content)) {
      if (m.end == m.start) continue;
      if (!bridge.acceptsMatch(m)) continue;
      final bool overlaps =
          spans.any((s) => m.start < s.end && m.end > s.start);
      if (!overlaps) spans.add(_ZShieldSpan(m.start, m.end));
    }
  }
  spans.sort((a, b) => a.start - b.start);
  return spans;
}

/// Attributs dont le marqueur Markdown **encadre** le contenu et n'admet donc
/// pas d'espace collé au marqueur (`** gras **` n'est pas du gras ; pire,
/// `a_ ital _b` n'est pas de l'italique du tout — un `_` intra-mot n'ouvre
/// aucune emphase)..
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
/// dans des ops non stylées adjacentes.
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
