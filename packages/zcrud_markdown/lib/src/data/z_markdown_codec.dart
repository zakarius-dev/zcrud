/// `ZMarkdownCodec` — codec Delta ↔ **Markdown** (AD-7). Round-trip **borné** au
/// sous-ensemble Markdown, avec pertes DOCUMENTÉES.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
// Libs de conversion ISOLÉES (AD-1) — au SEUL pubspec zcrud_markdown. Aucun de
// ces types (`Delta`, `md.Document`, `MarkdownToDelta`, `DeltaToMarkdown`,
// `CustomAttributeHandler`) n'apparaît dans la signature publique de
// `ZCodec`/`ZMarkdownField`.
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

import '../domain/z_codec.dart';
import '../domain/z_markdown_bridge.dart';
import 'delta_neutral_ops.dart';
import 'z_markdown_block_layout.dart';
import 'z_markdown_escaping.dart';
import 'z_table_markdown.dart';

/// Attribut d'élément portant la donnée d'un pont entre le parseur Markdown et
/// la construction de l'embed. Interne : jamais visible d'un hôte.
const String _kBridgeDataAttr = 'data';

/// Nom d'élément Markdown interne portant un tableau reconnu.
const String _kTableTag = 'z-table';

/// Nom d'élément Markdown interne portant une liste ordonnée dont le **numéro de
/// départ** n'est pas 1 (B).
///
/// Un tag DISTINCT est nécessaire : la fusion de `MarkdownToDelta` est
/// `{...custom, ...builtin}`, donc la clé `ol` — déjà définie nativement — n'est
/// **pas** surchargeable. On ne peut qu'AJOUTER une clé absente.
const String _kOrderedListTag = 'z-ol-start';

/// Liste ordonnée dont le numéro de départ diffère de 1 (B).
///
/// `md.ListSyntax` pose déjà `start` en attribut d'élément quand la liste ne
/// démarre pas à 1 : l'information EXISTE dans l'AST Markdown, elle était
/// simplement jetée au passage en Delta. On se contente donc de RENOMMER
/// l'élément pour le rendre atteignable par `customElementToBlockAttribute`.
///
/// La sous-classe conserve `UnorderedListWithCheckboxSyntax` comme base : c'est
/// la syntaxe déjà déclarée par le codec, et elle couvre AUSSI les listes
/// ordonnées (le `listPattern` de `ListSyntax` distingue ordonné/non-ordonné par
/// son groupe 1). En changer romprait la prise en charge de `- [x]`.
final class _ZOrderedListStartSyntax extends md.UnorderedListWithCheckboxSyntax {
  const _ZOrderedListStartSyntax();

  @override
  md.Node parse(md.BlockParser parser) {
    final md.Node node = super.parse(parser);
    if (node is! md.Element || node.tag != 'ol') return node;
    if (!node.attributes.containsKey('start')) return node;
    return md.Element(_kOrderedListTag, node.children)
      ..attributes.addAll(node.attributes);
  }
}

/// Charge d'embed tableau `{rows, columns, cells}` depuis la matrice JSON
/// transportée par l'attribut d'élément. Défensif (AD-10) : une charge illisible
/// rend une structure vide plutôt que de casser le décodage.
Map<String, dynamic> _tablePayload(String encodedCells) {
  final List<List<String>> cells =
      zDecodeCells(encodedCells) ?? const <List<String>>[];
  var width = 0;
  for (final List<String> row in cells) {
    if (row.length > width) width = row.length;
  }
  return <String, dynamic>{
    'rows': cells.length,
    'columns': width,
    // Rectangulaire par construction, comme `zTableEmbedOp` le garantit : le
    // builder de rendu REJETTE une matrice irrégulière.
    'cells': <List<String>>[
      for (final List<String> row in cells)
        <String>[
          for (var i = 0; i < width; i++) i < row.length ? row[i] : '',
        ],
    ],
  };
}

/// Bloc clôturé de repli — porte la charge JSON EXACTE d'un tableau que la forme
/// GFM ne saurait pas restituer (une cellule contenant `|`, par exemple).
final class _ZTableFenceSyntax extends md.BlockSyntax {
  const _ZTableFenceSyntax();

  @override
  RegExp get pattern => RegExp('^```$kZTableFenceInfo\\s*\$');

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[parser.current.content];
    parser.advance();
    while (!parser.isDone) {
      final String line = parser.current.content;
      lines.add(line);
      parser.advance();
      if (line.trim() == '```') break;
    }
    final List<List<String>>? cells = zParseTableFence(lines.join('\n'));
    if (cells == null) return md.Text(lines.join('\n'));
    return md.Element.empty(_kTableTag)
      ..attributes[_kBridgeDataAttr] = zEncodeCells(cells);
  }
}

/// Tableau GFM `| a | b |`.
///
/// Écrit ici plutôt que réutilisé de `markdown_quill` : mesuré, son
/// `EmbeddableTableSyntax` NE reconnaît PAS une cellule contenant un `|` échappé
/// — or c'est exactement ce que notre encodeur produit. Un parseur incapable de
/// relire notre propre écriture rouvrirait l'asymétrie que dénonce.
final class _ZTablePipeSyntax extends md.BlockSyntax {
  const _ZTablePipeSyntax();

  @override
  RegExp get pattern => RegExp(r'^\s*\|');

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[];
    while (!parser.isDone && pattern.hasMatch(parser.current.content)) {
      lines.add(parser.current.content);
      parser.advance();
    }
    final String raw = lines.join('\n');
    final List<List<String>>? cells = zParseMarkdownTable(raw);
    // Pas un tableau (ligne de séparation absente ou mal formée) : on rend le
    // texte TEL QUEL. Ne jamais mutiler ce qu'on n'a pas su structurer — c'est
    // ce reproche exact qui a fait écarter `gitHubFlavored`.
    if (cells == null) return md.Text(raw);
    return md.Element.empty(_kTableTag)
      ..attributes[_kBridgeDataAttr] = zEncodeCells(cells);
  }
}

/// Barré GFM restreint au tilde **DOUBLE**.
///
/// `md.StrikethroughSyntax` déclare `tags: [DelimiterTag('del', 1),
/// DelimiterTag('del', 2)]` : un tilde SIMPLE apparié suffit à barrer. Un corpus
/// legacy contenant `H~2~O` ou `CO~2~` (convention Pandoc d'indice) aurait donc
/// été muté irréversiblement en `H~~2~~O` au premier enregistrement.
///
/// C'est exactement la mécanique refusée pour les tables sous `gitHubFlavored`
/// (`| a | b |` aplati en `ab12`) : une syntaxe qui transforme du texte en
/// attribut et mute le contenu. La refuser d'un côté et l'accepter de l'autre
/// n'aurait pas tenu — trouvé en revue.
final class _ZDoubleTildeStrikethroughSyntax extends md.DelimiterSyntax {
  _ZDoubleTildeStrikethroughSyntax()
      : super(
          '~{2,}',
          requiresDelimiterRun: true,
          allowIntraWord: true,
          startCharacter: 0x7E, // '~'
          tags: <md.DelimiterTag>[md.DelimiterTag('del', 2)],
        );
}

/// Syntaxe Markdown inline SYNTHÉTISÉE depuis un [ZMarkdownEmbedBridge].
///
/// C'est le seul endroit où un pont — décrit par l'hôte en pur Dart (`RegExp`) —
/// devient un type de la lib de conversion. L'isolation AD-1 tient donc : la
/// description reste neutre, la traduction est confinée ici.
final class _ZBridgeInlineSyntax extends md.InlineSyntax {
  _ZBridgeInlineSyntax(this.bridge, this.tag) : super(bridge.pattern.pattern);

  final ZMarkdownEmbedBridge bridge;
  final String tag;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    // garde au DÉCODAGE. Un pont était TOUT ou RIEN — rien ne
    // refusait `de 5 $ à 9 $`, qui devenait un embed `latex` de charge « à 9 ».
    if (!bridge.acceptsMatch(match)) {
      // Rendre `false` NE SUFFIT PAS : `InlineSyntax.tryMatch` ne consomme
      // rien dans ce cas mais rend quand même `true`, et `InlineParser.parse`
      // reboucle à la MÊME position — BOUCLE INFINIE (mesuré sur la lib, pas
      // supposé). On réémet donc le premier caractère du délimiteur en texte
      // LITTÉRAL et on avance d'un caractère : le texte refusé est intégralement
      // préservé, jamais mangé.
      final String matched = match[0] ?? '';
      if (matched.isEmpty) return false;
      parser.addNode(md.Text(matched.substring(0, 1)));
      parser.consume(1);
      return false;
    }
    final element = md.Element.empty(tag)
      ..attributes[_kBridgeDataAttr] = bridge.dataOf(match).toString();
    parser.addNode(element);
    return true;
  }
}

/// Bouclier littéral LaTeX du **chemin sans pont** — moitié
/// DÉCODAGE.
///
/// Reconnaît les mêmes régions que le pont correspondant (même motif, même
/// garde `acceptsMatch`) mais les émet en **texte LITTÉRAL**, jamais en embed :
/// le contenu d'une formule échappe ainsi à la résolution des échappements
/// CommonMark (`\,` → `,`, perte IRRÉVERSIBLE mesurée) sans qu'aucune
/// sémantique nouvelle n'apparaisse — sans pont, `$$x$$` reste du texte, comme
/// le contrat AD-57 le fige.
final class _ZLatexShieldSyntax extends md.InlineSyntax {
  _ZLatexShieldSyntax(this.bridge) : super(bridge.pattern.pattern);

  final ZMarkdownEmbedBridge bridge;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String matched = match[0] ?? '';
    if (matched.isEmpty) return false;
    if (!bridge.acceptsMatch(match)) {
      // Même mécanique de refus que `_ZBridgeInlineSyntax` : réémettre le
      // premier caractère en littéral et avancer d'UN, sans quoi
      // `InlineParser.parse` reboucle à la même position (boucle infinie,
      // mesurée sur la lib).
      parser.addNode(md.Text(matched.substring(0, 1)));
      parser.consume(1);
      return false;
    }
    parser.addNode(md.Text(matched));
    return true;
  }
}

/// Nom d'élément Markdown interne portant une **image avec son texte ALT**.
const String _kImageTag = 'z-image';

/// Clé d'attribut d'op portant le texte ALT d'une image.
const String _kAltAttr = 'alt';

/// Image `![alt](src)` — relue AVEC son texte ALT.
///
/// Le ALT était détruit dès le PREMIER enregistrement, des deux côtés à la fois :
/// `markdown_quill` construit l'embed par `BlockEmbed.image(elAttrs['src'])`
/// (ALT jeté à la lecture) et le réécrit par `out.write('![](${data})')` (ALT
/// toujours vide à l'écriture). Or la clé native `img` n'est PAS surchargeable
/// (fusion `{...custom, ...builtin}` côté décodage) : il faut donc une syntaxe
/// inline PRIORITAIRE, qui capte l'image avant que la syntaxe native ne la voie.
///
/// Formes non couvertes (URL entre `<>`, titre `"…"`, URL à parenthèses) : la
/// syntaxe native reprend la main et le ALT dégrade comme avant — jamais de
/// destruction NOUVELLE.
final class _ZImageSyntax extends md.InlineSyntax {
  _ZImageSyntax()
      : super(
          r'!\[((?:[^\]\\\n]|\\.)*)\]\(([^()\s]*)(?:\s+"[^"\n]*")?\)',
          startCharacter: 0x21, // '!'
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.empty(_kImageTag)
        ..attributes['src'] = match[2] ?? ''
        ..attributes[_kAltAttr] = _unescape(match[1] ?? ''),
    );
    return true;
  }

  /// Défait l'échappement posé par l'encodeur (`\\` et `\[`).
  static String _unescape(String alt) =>
      alt.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1] ?? '');
}

/// Fusionne un retour souple (`\n` de continuation) en **espace**, comme le
/// prescrit CommonMark.
///
/// `MarkdownToDelta` le fait déjà (`_trimTextToMdSpec`, motif ` ?\n *`), MAIS
/// court-circuite cette normalisation dès que `_isInBlockQuote` : le retour
/// souple TERMINAL d'un nœud texte est alors retiré **sans insérer aucun
/// séparateur**. Mesuré : `> …elle est\n> *acquise*…` rendait `elle estacquise`,
/// et le cycle suivant réécrivait `est_acquise_` — un `_` intra-mot n'ouvrant
/// aucune emphase, l'italique était DÉTRUITE en plus du mot recollé.
///
/// Normaliser au niveau INLINE traite les deux contextes de la même façon, ce
/// qui est précisément ce qui manquait. Les retours DURS sont hors d'atteinte :
/// la garde `(?<![ \\])` refuse un `\n` précédé d'une espace ou d'un backslash,
/// c'est-à-dire exactement les deux formes de saut de ligne forcé de CommonMark
/// (`  \n` et `\\\n`), qui restent traitées par `LineBreakSyntax`.
final class _ZSoftLineBreakSyntax extends md.InlineSyntax {
  _ZSoftLineBreakSyntax(this._softBreak)
      : super(
          r'(?<![ \\])\n *',
          startCharacter: 0x0A, // '\n'
        );

  /// Sort du retour souple, déclaré par le codec appelant.
  final ZSoftBreak _softBreak;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    // `br` est EXACTEMENT le noeud qu'émet `LineBreakSyntax` pour un retour
    // DUR : le mode `lineBreak` ne fabrique donc pas une forme nouvelle, il
    // réutilise celle que le convertisseur sait déjà traduire (`_delta.insert
    // ('\n')`). Le mode `space` reste inchangé, jusqu'au noeud produit.
    final md.Node node = _softBreak == ZSoftBreak.lineBreak
        ? md.Element.empty('br')
        : md.Text(' ');
    parser.addNode(node);
    return true;
  }
}

/// Un attribut Delta porté à travers le Markdown par une paire de marqueurs
/// HTML littéraux (Markdown standard ne l'exprime pas). Préservés tels quels par
/// `markdown` avec `encodeHtml:false`, puis RÉ-ABSORBÉS en attribut au décodage.
///
/// Ce mécanisme existait pour le seul souligné (parité legacy `<u>`); il
/// est GÉNÉRALISÉ à l'exposant/indice, dont les deux boutons
/// sont actifs par défaut dans la barre d'outils alors que leur effet était
/// silencieusement perdu à la persistance.
@immutable
class _ZMarkerAttr {
  const _ZMarkerAttr(this.open, this.close, this.attribute, this.value);

  final String open;
  final String close;
  final String attribute;
  final Object value;
}

const List<_ZMarkerAttr> _kMarkerAttrs = <_ZMarkerAttr>[
  _ZMarkerAttr('<u>', '</u>', 'underline', true),
  _ZMarkerAttr('<sup>', '</sup>', 'script', 'super'),
  _ZMarkerAttr('<sub>', '</sub>', 'script', 'sub'),
];

/// Types d'embed que l'encodeur Markdown sait exprimer NATIVEMENT et qui ne
/// doivent donc PAS être dégradés en placeholder.
///
/// - `image` : l'URL et le **texte ALT** font l'aller-retour (`![alt](src)`).
///   Le pont natif ne portait QUE l'URL — `BlockEmbed.image(elAttrs['src'])` à
///   la lecture, `out.write('![](…)')` à l'écriture : le ALT était détruit dès
///   le premier enregistrement, silencieusement, et rien ne le documentait
/// . Il est désormais capté par une syntaxe inline prioritaire et
///   reversé en attribut d'op `alt`. Reste PERDU : un ALT contenant `]` ou un
///   saut de ligne (cf. table des pertes) — jamais l'URL.
/// - `divider` (`---`) : `MarkdownToDelta` construit l'embed depuis `hr` et
///   `DeltaToMarkdown` écrit `- - -`. Le pont existe des DEUX côtés, comme pour
///   l'image.
/// - `table` : rendu en TABLEAU GFM lisible quand ce rendu se relit à
///   l'identique, en bloc clôturé `\`\`\`zcrud-table` sinon (charge JSON exacte)
///   — jamais une perte de cellules.
/// - `video` : pas de forme Markdown native ; encodé en lien `[src](src)`
///   (parité des hôtes). Le round-trip le rend donc comme un LIEN, pas comme une
///   vidéo — dégradation ASSUMÉE, mais la source survit, ce qui n'était pas le
///   cas avec `[embed:video]`.
const Set<String> _kNativeEmbedTypes = <String>{
  'image',
  'video',
  'divider',
  'table',
};

/// Sort d'un retour à la ligne **souple** au DÉCODAGE d'un document Markdown.
///
/// Un retour souple est un simple `\n` de continuation, sans les deux espaces
/// (ou l'antislash) qui font un retour **dur**. CommonMark laisse au moteur de
/// rendu le choix de ce qu'il en fait ; ce réglage expose ce choix.
///
/// Il porte sur le **décodage seulement** : la valeur persistée n'en dépend pas,
/// et un même document se relit à l'identique sous l'autre valeur.
enum ZSoftBreak {
  /// Le retour souple est fusionné en **espace** — le défaut, et ce que
  /// prescrit CommonMark. Trois lignes saisies forment un paragraphe continu.
  space,

  /// Le retour souple produit un **saut de ligne** : le texte s'affiche sur
  /// autant de lignes qu'il en portait à la saisie.
  ///
  /// À réserver aux corpus qui ne sont pas écrits en Markdown — des contenus
  /// saisis dans un champ de texte (ou produits par un modèle), où l'auteur
  /// sépare ses lignes avec la touche Entrée.
  ///
  /// ⚠️ **Aller-retour** : le saut de ligne obtenu est une ligne Delta à part
  /// entière ; ré-encodé en Markdown, il ressort en **changement de
  /// paragraphe**, pas en retour souple. Sur une surface qui ÉDITE et
  /// ré-enregistre, la structure du document se stabilise donc après le premier
  /// cycle. Sur une surface de LECTURE, la valeur persistée n'est jamais
  /// réécrite et la question ne se pose pas.
  lineBreak,
}

/// Codec **Markdown** : le format persisté est une `String` Markdown lisible.
///
/// - [encode] : ops Delta neutres → `Delta` (interne) → `String` Markdown.
///   `encode(const [])` → `''`. Défensif : toute exception de conversion → `''`.
/// - [decode] : `String` Markdown → ops Delta neutres. Défensif (AD-10) :
///   `null`/vide/Markdown mal formé/legacy → `[]`, **jamais** de throw. Une
///   valeur `List` (Delta legacy) **ou une `String` contenant un Delta JSON
/// sérialisé** est tolérée et normalisée en ops neutres.
///
/// ## Table des pertes (round-trip borné)
///
/// > **Cette table est la SPÉCIFICATION du round-trip, pas un commentaire** :
/// > chaque ligne ci-dessous est assertée par exécution. Une perte qui n'y
/// > figure pas est un défaut, pas une dégradation tolérée.
///
/// Le round-trip `decode(encode(ops))` PRÉSERVE la sémantique du **sous-ensemble
/// Markdown** : titres **H1–H6**, gras, italique, **souligné** via `<u>`,
/// **barré** via `~~` (GFM), **cases à cocher** `- [x]`/`- [ ]`, **tableaux**
/// (`| a | b |`, avec repli sans perte), **exposant /
/// indice** via `<sup>`/`<sub>`, listes imbriquées (y compris le **numéro de
/// départ** d'une liste ordonnée non indentée), liens, **images avec leur texte
/// ALT** via `![alt](src)`, `code` inline + blocs (contenu **opaque**),
/// blockquote, texte brut. Il **PERD** :
///
/// | Attribut / contenu Delta        | Sort au round-trip Markdown            |
/// |---------------------------------|----------------------------------------|
/// | Couleur (`color`)               | **perdu** (non exprimable en MD)       |
/// | Police (`font`)                 | **perdu**                              |
/// | Taille (`size`)                 | **perdu**                              |
/// | Fond (`background`)             | **perdu**                              |
/// | Alignement (`align`)            | **perdu**                              |
/// | Texte **ALT** d'image contenant `]` ou un saut de ligne | **perdu** — l'ALT est omis (`!(src)`), l'URL SURVIT. Écrire `\]` rouvrirait (l'encodeur fabriquerait un délimiteur de bloc LaTeX) : la perte est préférée à la corruption du texte voisin |
/// | Numéro de départ d'une liste ordonnée **indentée** | **perdu** (renumérotée depuis 1) — la correspondance run Delta ↔ run Markdown n'est pas triviale pour une liste imbriquée, et renuméroter de travers serait pire |
/// | Retour **souple** (`\n` de continuation) | **fusionné en espace**, conformément à CommonMark — hors blockquote c'était déjà le cas ; dans un blockquote il RECOLLAIT les mots. Déclarer `softBreak: ZSoftBreak.lineBreak` le rend visible au décodage (cf. [ZSoftBreak]) |
/// | Vidéo (`video`)                 | **dégradé en LIEN** `[src](src)` — la source SURVIT, le type d'embed non |
/// | Entité HTML littérale (`&amp;`) | **résolue** en son caractère (`&`) dès le premier round-trip — la forme entité n'est pas restituée |
/// | Embed LaTeX/tableau | dégradé en placeholder `\[embed:<type>]` (crochet ouvrant échappé), texte environnant PRÉSERVÉ (perte **BORNÉE** à l'embed) |
/// | Tableau **inline** (au milieu d'une ligne) | promu en BLOC à part : la mise en page bouge, le CONTENU est intégralement préservé |
///
/// > LIMITE : un texte brut contenant littéralement `<u>`/`</u>`,
/// > `<sup>`/`<sub>` saisi par l'utilisateur serait interprété comme l'attribut
/// > correspondant au décodage. Cas marginal assumé, non fatal.
///
/// > PERTE BORNÉE : un embed opaque au MILIEU du texte ne fait **jamais**
/// > échouer la conversion ni vider le document — il est remplacé par un
/// > placeholder textuel (`[embed:latex]`, `[embed:table]`, …) tandis que TOUT le
/// > texte non-embed survit. La perte est cantonnée à l'embed lui-même.
///
/// Pour un round-trip **sans perte**, utiliser `ZDeltaCodec` (persisté = Delta).
final class ZMarkdownCodec implements ZCodec {
  /// Codec `const` (aucun état mutable).
  ///
  /// [bridges] — ponts Markdown ↔ embed **opt-in** (
  /// ). Vide par défaut : sans déclaration, le comportement est
  /// EXACTEMENT celui d'avant, et les embeds continuent de dégrader en
  /// placeholder. Cf. `ZMarkdownBridges.latex` pour un jeu prêt à l'emploi.
  const ZMarkdownCodec({
    this.bridges = const <ZMarkdownEmbedBridge>[],
    this.softBreak = ZSoftBreak.space,
  });

  /// Ponts Markdown ↔ embed déclarés par l'hôte. L'ordre compte : le premier
  /// motif qui correspond gagne (d'où `$$…$$` avant `$…$`).
  final List<ZMarkdownEmbedBridge> bridges;

  /// Sort d'un retour à la ligne **souple** au décodage.
  ///
  /// [ZSoftBreak.space] par défaut : le comportement CommonMark, strictement
  /// celui d'avant l'ouverture du réglage. [ZSoftBreak.lineBreak] rend chaque
  /// retour souple visible, dans un blockquote comme au fil du texte.
  ///
  /// Sans effet sur [encode] : la valeur persistée ne dépend pas de ce réglage.
  final ZSoftBreak softBreak;

  /// Types d'embed exprimables : natifs + ceux qu'un pont sait réémettre.
  Set<String> get _expressibleEmbedTypes => <String>{
        ..._kNativeEmbedTypes,
        for (final bridge in bridges) bridge.embedType,
      };

  /// Bouclier littéral LaTeX : ponts LaTeX de référence rejoués en
  /// mode **texte littéral** sur le chemin SANS pont, et sur lui seul.
  ///
  /// Mesuré avant correction : `ZMarkdownCodec()` (la construction par défaut,
  /// donc le chemin EXPOSÉ) altérait `$$\int_0^1 x\,dx$$` en
  /// `$$\\int\_0^1 x,dx$$` au premier cycle — antislash doublé par
  /// l'échappement, `\,` détruit par la résolution CommonMark. Altération de
  /// DONNÉE, irréversible.
  ///
  /// - Actif UNIQUEMENT quand [bridges] est vide : un hôte qui a déclaré des
  ///   ponts — quels qu'ils soient — a arbitré lui-même le sens de `$…$`, et
  ///   son comportement ne bouge pas d'un octet (les deux moitiés du bouclier
  ///   sont court-circuitées structurellement).
  /// - N'émet JAMAIS d'embed : sans pont, `$$x$$` reste du texte (AD-57), il
  ///   est simplement soustrait à l'échappement (encodage) et à la résolution
  ///   des échappements (décodage). Un hôte sans `EmbedBuilder` LaTeX ne voit
  ///   donc aucun type d'insert nouveau.
  /// - Les régions sont désignées par les MÊMES motifs et la MÊME garde
  ///   (`zLatexPayloadLooksLikeFormula`) que `ZMarkdownBridges.latex` : un
  ///   prix `5$ … 9$` ou `100$$ … 200$$` n'est pas une région, et ses octets
  ///   persistés sont STRICTEMENT inchangés.
  /// - Limite documentée : une formule dont le texte est fragmenté sur
  ///   plusieurs ops STYLÉES (gras au milieu d'un `$$…$$`) n'est pas
  ///   reconnaissable comme région à l'encodage et dégrade comme avant.
  List<ZMarkdownEmbedBridge> get _latexShield => bridges.isEmpty
      ? ZMarkdownBridges.latex
      : const <ZMarkdownEmbedBridge>[];

  /// Nom d'élément Markdown interne porteur d'un pont. Préfixé pour ne jamais
  /// entrer en collision avec une balise réelle ni avec les clés natives de
  /// `MarkdownToDelta` (qui, elles, ne sont pas surchargeables).
  static String _bridgeTag(int index) => 'z-bridge-$index';

  /// Document Markdown de décodage.
  ///
  /// Les trois syntaxes ajoutées le sont **en supplément** du défaut
  /// `ExtensionSet.commonMark` (`FencedCodeBlockSyntax` + `InlineHtmlSyntax`) :
  /// le jeu est donc un SURENSEMBLE strict de ce qui était reconnu jusqu'ici,
  /// et rien de ce qui fonctionnait ne peut régresser.
  ///
  /// **`ExtensionSet.gitHubFlavored` n'est PAS utilisé, délibérément.** Il
  /// embarque `TableSyntax`, et `MarkdownToDelta` APLATIT une table en
  /// concaténant ses cellules — mesuré : `| a | b |…` devient `ab12`, séparateurs
  /// et structure détruits. Aujourd'hui une table survit en texte littéral, donc
  /// l'activer serait échanger une perte contre une DESTRUCTION. Le pont
  /// table↔embed reste hors de ce codec.
  md.Document _markdownDocument() => md.Document(
        encodeHtml: false,
        // Les syntaxes des ponts passent AVANT les syntaxes par défaut
        // (`md.Document` insère `inlineSyntaxes` en tête) : un hôte peut donc
        // faire primer `$…$` sur l'interprétation ordinaire du texte.
        blockSyntaxes: const <md.BlockSyntax>[
          // `- [x]` / `1. [x]` → `{list: checked|unchecked}`.
          // Sans elle, le marqueur `[x]` était RÉINJECTÉ dans le texte de la
          // puce et polluait le contenu à chaque cycle.
          //
          // UNE SEULE suffit, et elle couvre AUSSI les listes ordonnées : les
          // deux classes `…WithCheckboxSyntax` sont des sous-classes VIDES qui
          // partagent le `listPattern` de `ListSyntax` (lequel distingue
          // ordonné/non-ordonné par son groupe 1) et servent uniquement de
          // drapeau `taskListParserEnabled` (`list_syntax.dart:78-80`). Ajouter
          // `OrderedListWithCheckboxSyntax` ne changeait RIEN — vérifié par
          // exécution, la retirer laissait `1. [x]` fonctionner.
          //
          // B : la variante `_ZOrderedListStartSyntax` REMPLACE la
          // syntaxe d'origine (elle en hérite) et se borne à renommer l'élément
          // quand `start != 1`, pour rendre le numéro de départ atteignable.
          _ZOrderedListStartSyntax(),
          // Tableau ↔ embed. Placées AVANT les syntaxes par défaut, donc avant
          // `FencedCodeBlockSyntax` (sans quoi le bloc de repli serait lu comme
          // un simple bloc de code).
          _ZTableFenceSyntax(),
          _ZTablePipeSyntax(),
        ],
        inlineSyntaxes: <md.InlineSyntax>[
          // Les ponts passent AVANT tout le reste : `md.Document` insère
          // `inlineSyntaxes` en tête de sa liste, donc un hôte peut faire primer
          // `$…$` sur l'interprétation ordinaire du texte.
          for (var i = 0; i < bridges.length; i++)
            _ZBridgeInlineSyntax(bridges[i], _bridgeTag(i)),
          // bouclier littéral LaTeX du chemin SANS pont, à la
          // place exacte qu'occuperaient les ponts (vide dès qu'un pont est
          // déclaré — les deux listes sont exclusives par construction).
          for (final bridge in _latexShield) _ZLatexShieldSyntax(bridge),
          // image AVEC son texte ALT (la clé native `img` n'est pas
          // surchargeable — seule une syntaxe prioritaire y donne accès).
          _ZImageSyntax(),
          // `~~x~~` → `{strike: true}`. L'encodeur émettait déjà
          // du `~~` que le décodeur ne savait pas relire.
          _ZDoubleTildeStrikethroughSyntax(),
          // retour souple, y compris DANS un blockquote : espace par défaut,
          // saut de ligne si le codec le déclare.
          _ZSoftLineBreakSyntax(softBreak),
        ],
      );

  /// Convertisseur Markdown → Delta.
  ///
  /// `customElementToBlockAttribute` restaure **H4–H6** :
  /// `markdown_quill` ne mappe nativement que `h1`–`h3`, alors que
  /// `flutter_quill` expose bien `Attribute.h4`/`h5`/`h6`. La limite n'était donc
  /// pas dans le modèle mais dans le convertisseur.
  ///
  /// La fusion interne de `MarkdownToDelta` est `{...custom, ...builtin}` :
  /// une clé DÉJÀ définie nativement (`h1`, `img`, `em`…) ne peut PAS être
  /// surchargée par ce chemin. On n'y AJOUTE que des clés absentes.
  MarkdownToDelta _markdownToDelta() => MarkdownToDelta(
        markdownDocument: _markdownDocument(),
        // Le retour souple précédé d'UNE seule espace (` \n`) n'est pas capté
        // par `_ZSoftLineBreakSyntax` — sa garde `(?<![ \\])` l'exclut, parce
        // qu'elle vise les retours durs. Ce reliquat est traité par le
        // convertisseur lui-même, dont la normalisation ` ?\n *` → espace doit
        // donc être désactivée dans le même mode, sans quoi le réglage aurait
        // un angle mort d'une espace de large.
        softLineBreak: softBreak == ZSoftBreak.lineBreak,
        customElementToBlockAttribute: <String, ElementToAttributeConvertor>{
          'h4': (_) => <Attribute<dynamic>>[Attribute.h4],
          'h5': (_) => <Attribute<dynamic>>[Attribute.h5],
          'h6': (_) => <Attribute<dynamic>>[Attribute.h6],
          // B — numéro de départ d'une liste ordonnée. La clé
          // `start` n'est pas au registre `flutter_quill` : `Style.fromJson` la
          // conserve en `AttributeScope.ignore`, ce qui la rend inoffensive pour
          // le rendu tout en la faisant survivre au Delta persisté.
          _kOrderedListTag: (element) => <Attribute<dynamic>>[
                Attribute.ol,
                if (int.tryParse(element.attributes['start'] ?? '')
                    case final int start)
                  Attribute<int>('start', AttributeScope.block, start),
              ],
        },
        // Chaque pont déclaré devient un élément Markdown interne, remonté en
        // embed Delta du type annoncé par l'hôte.
        customElementToEmbeddable: <String, ElementToEmbeddableConvertor>{
          // `Embeddable` et non `BlockEmbed` : la charge d'un tableau est une
          // STRUCTURE (`{rows, columns, cells}`), et `BlockEmbed` contraint sa
          // donnée à une `String`.
          _kTableTag: (attrs) => Embeddable(
                'table',
                _tablePayload(attrs[_kBridgeDataAttr] ?? ''),
              ),
          // porteur INTERNE `{src, alt}` : `_delta.insert` d'un
          // embed n'accepte AUCUN attribut d'op côté `MarkdownToDelta`, donc le
          // ALT doit transiter DANS la charge, puis être reversé en attribut par
          // `_restoreImageAlt`. Le type reste privé jusque-là : un `image` à
          // charge `Map` casserait tout `EmbedBuilder` d'hôte.
          _kImageTag: (attrs) => Embeddable(_kImageTag, <String, String>{
                'src': attrs['src'] ?? '',
                _kAltAttr: attrs[_kAltAttr] ?? '',
              }),
          for (var i = 0; i < bridges.length; i++)
            _bridgeTag(i): (attrs) =>
                BlockEmbed(bridges[i].embedType, attrs[_kBridgeDataAttr] ?? ''),
        },
      );

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) {
    if (deltaOps.isEmpty) return '';
    try {
      return _layout(_convertToMarkdown(deltaOps), deltaOps);
    } on Object catch (error, stack) {
      // AD-10 : jamais casser le parent — persisté vide + log non-fatal.
      assert(() {
        debugPrint('ZMarkdownCodec.encode: conversion ignorée ($error)\n$stack');
        return true;
      }());
      return '';
    }
  }

  /// Passes de **mise en page de bloc** appliquées au Markdown émis
  /// ( : frontière après une citation; §B : numéro de départ
  /// d'une liste ordonnée). Chacune rend son entrée à l'IDENTIQUE quand elle n'a
  /// rien à corriger — cf. `z_markdown_block_layout.dart`.
  static String _layout(String markdown, List<Map<String, dynamic>> ops) {
    if (markdown.isEmpty) return markdown;
    return zRestoreOrderedListStart(
      zSeparateBlocksAfterQuote(markdown),
      ops,
    );
  }

  String _convertToMarkdown(List<Map<String, dynamic>> deltaOps) {
    {
      final delta = DeltaNeutralOps.toDeltaForMarkdown(
        // `** gras **` n'est pas du gras, et `a_ ital _b` n'est
        // pas de l'italique du tout — un `_` intra-mot n'ouvre aucune emphase.
        zMoveSpacesOutOfMarkers(deltaOps),
        // Un embed n'est préservé que si l'encodeur sait l'écrire : natif
        // (image/vidéo) ou porté par un pont déclaré. Les autres dégradent en
        // placeholder — sans quoi `DeltaToMarkdown` throwerait et VIDERAIT le
        // document entier.
        preserveEmbedTypes: _expressibleEmbedTypes,
      );
      if (delta.isEmpty) return '';
      return DeltaToMarkdown(
        // n'échappe les ouvreurs de bloc qu'en tête de ligne,
        // ET les caractères que les ponts déclarés rendent significatifs.
        // sur le chemin SANS pont, les régions LaTeX reconnues
        // passent VERBATIM (moitié encodage du bouclier littéral).
        customContentHandler: zMarkdownContentEscaper(
          extraDangerous: <String>{
            for (final bridge in bridges) ...bridge.escapedCharacters,
          },
          latexShield: _latexShield,
        ),
        customTextAttrsHandlers: <String, CustomAttributeHandler>{
          for (final marker in _kMarkerAttrs)
            marker.attribute: CustomAttributeHandler(
              beforeContent: (attribute, node, output) =>
                  output.write(_openMarkerFor(attribute)),
              afterContent: (attribute, node, output) =>
                  output.write(_closeMarkerFor(attribute)),
            ),
        },
        customEmbedHandlers: <String, EmbedToMarkdown>{
          // le handler natif écrit `!(${data})`, ALT TOUJOURS
          // VIDE. Contrairement au décodage, la fusion est ici
          // `_embedHandlers.addAll(custom)` : la clé `image` EST surchargeable
          // (mesuré — le commentaire qui l'en dissuadait était faux).
          'image': (embed, out) {
            final Object? src = embed.value.data;
            final String href = src is String ? src : '';
            out.write('![${_altOf(embed)}]($href)');
          },
          // Pas de forme Markdown native pour la vidéo : lien vers la source.
          // Auto-vérification : la forme lisible n'est retenue que si elle se
          // relit à l'identique. La garantie s'EXÉCUTE à chaque écriture.
          'table': (embed, out) {
            final List<List<String>>? cells =
                zCellsOfTablePayload(embed.value.data);
            if (cells == null) {
              out.write('[embed:table]');
              return;
            }
            // Un tableau Markdown occupe FORCÉMENT son propre bloc : écrit au
            // milieu d'une ligne (`avant | x | apres`), il ne serait pas relu
            // comme un tableau. On force donc la coupure. Conséquence assumée
            // et documentée : un tableau INLINE devient un bloc à part — la
            // mise en page bouge, le CONTENU est intégralement préservé.
            out
              ..write('\n\n')
              ..write(zRenderTableGuaranteed(cells))
              ..write('\n');
          },
          'video': (embed, out) {
            final Object? src = embed.value.data;
            final String href = src is String ? src : '';
            out.write('[$href]($href)');
          },
          // Ponts déclarés : la moitié qui manquait. Un pont
          // déclaré APRÈS un autre sur le même type d'embed l'emporte — dernier
          // déclaré gagne, comme pour toute Map littérale.
          // PREMIER déclaré gagne, pour coïncider avec le décodage (où la
          // première syntaxe qui correspond l'emporte). Une Map littérale
          // laisserait gagner le DERNIER : encodage et décodage auraient alors
          // désigné deux ponts différents pour un même type d'embed.
          for (final bridge in bridges.reversed)
            bridge.embedType: (embed, out) =>
                out.write(bridge.toMarkdown(embed.value.data)),
        },
      ).convert(delta);
    }
  }

  /// Texte ALT d'un embed image, ÉCHAPPÉ pour la forme `![alt](src)`.
  ///
  /// Un ALT contenant `]` rend la chaîne **vide** plutôt que d'écrire `\]` :
  /// écrire `\]` rouvrirait par la bande (un `\[` échappé plus haut
  /// dans la même ligne trouverait là son délimiteur fermant, et toute la phrase
  /// intermédiaire deviendrait une formule). Perte BORNÉE et documentée dans la
  /// table des pertes — jamais une corruption du texte voisin.
  static String _altOf(Embed embed) {
    final Object? raw = embed.style.attributes[_kAltAttr]?.value;
    final String alt = raw is String ? raw : '';
    if (alt.isEmpty || alt.contains(']') || alt.contains('\n')) return '';
    return alt.replaceAll(r'\', r'\\').replaceAll('[', r'\[');
  }

  /// Marqueur ouvrant correspondant à [attribute] (clé + valeur), ou `''` si
  /// aucune correspondance — un `script` de valeur inattendue n'écrit alors
  /// AUCUN marqueur plutôt qu'un marqueur faux (AD-10).
  static String _openMarkerFor(Attribute<dynamic> attribute) =>
      _markerFor(attribute)?.open ?? '';

  static String _closeMarkerFor(Attribute<dynamic> attribute) =>
      _markerFor(attribute)?.close ?? '';

  static _ZMarkerAttr? _markerFor(Attribute<dynamic> attribute) {
    for (final marker in _kMarkerAttrs) {
      if (marker.attribute != attribute.key) continue;
      // `underline` est booléen (valeur `true`), `script` porte 'super'/'sub'.
      if (marker.value == true && attribute.value != false) return marker;
      if (marker.value == attribute.value) return marker;
    }
    return null;
  }

  @override
  List<Map<String, dynamic>> decode(Object? persisted) {
    // Tolérance legacy : une valeur non-`String` (ex. `List` Delta déjà décodé)
    // est normalisée défensivement en ops neutres.
    if (persisted is! String) {
      return DeltaNeutralOps.decodeDefensiveOps(persisted);
    }
    final text = persisted.trim();
    if (text.isEmpty) return const <Map<String, dynamic>>[];
    // un corpus Quill legacy est stocké sous la forme
    // `jsonEncode(document.toDelta().toJson())` — donc une `String`, pas une
    // `List`. Elle empruntait la branche Markdown et s'affichait LITTÉRALEMENT
    // (`[{"insert":"…"}]` à l'écran), en perdant au passage TOUT le document,
    // attributs et embeds compris.
    final List<Map<String, dynamic>>? serializedDelta = _asSerializedDelta(text);
    if (serializedDelta != null) return serializedDelta;
    try {
      final delta = _markdownToDelta().convert(persisted);
      final ops = _absorbMarkerAttrs(
        _ensureOwnLineEmbeds(
          _restoreImageAlt(DeltaNeutralOps.deltaToNeutralOps(delta)),
        ),
      );
      // Un texte NON VIDE ne doit jamais produire un document vide : trouvé
      // hors CR pendant la mesure — `[ref]: http://exemple.test` (définition de
      // lien de référence, syntaxe Markdown standard) est consommée comme
      // métadonnée par le parseur et ne rend AUCUN nœud. Tout le contenu
      // disparaissait silencieusement. Repli : le texte brut, qui est toujours
      // préférable à rien.
      if (ops.isEmpty || _isBlank(ops)) {
        return <Map<String, dynamic>>[
          <String, dynamic>{'insert': '$text\n'},
        ];
      }
      return ops;
    } on Object catch (error, stack) {
      // AD-10 : Markdown mal formé/legacy → `[]`, jamais de throw.
      assert(() {
        debugPrint('ZMarkdownCodec.decode: Markdown ignoré ($error)\n$stack');
        return true;
      }());
      return const <Map<String, dynamic>>[];
    }
  }

  /// Reverse le porteur interne `z-image` en embed `image` NORMAL + attribut
  /// d'op `alt`.
  ///
  /// La charge de l'embed reste une `String` (l'URL), comme l'attend tout
  /// `EmbedBuilder` d'hôte : le ALT voyage en ATTRIBUT, clé inconnue du registre
  /// `flutter_quill` (donc `AttributeScope.ignore`, inoffensive au rendu) mais
  /// parfaitement sérialisable.
  static List<Map<String, dynamic>> _restoreImageAlt(
    List<Map<String, dynamic>> ops,
  ) {
    var touched = false;
    final out = <Map<String, dynamic>>[];
    for (final op in ops) {
      final Object? insert = op['insert'];
      if (insert is! Map || !insert.containsKey(_kImageTag)) {
        out.add(op);
        continue;
      }
      touched = true;
      final Object? payload = insert[_kImageTag];
      final String src =
          payload is Map ? '${payload['src'] ?? ''}' : '${payload ?? ''}';
      final String alt = payload is Map ? '${payload[_kAltAttr] ?? ''}' : '';
      final Map<String, dynamic> attrs = <String, dynamic>{
        ...?(op['attributes'] is Map<String, dynamic>
            ? op['attributes'] as Map<String, dynamic>
            : null),
        if (alt.isNotEmpty) _kAltAttr: alt,
      };
      out.add(<String, dynamic>{
        'insert': <String, dynamic>{'image': src},
        if (attrs.isNotEmpty) 'attributes': attrs,
      });
    }
    return touched ? out : ops;
  }

  /// Types d'embed qui occupent NÉCESSAIREMENT leur propre ligne Delta.
  ///
  /// Un tableau n'est pas un caractère : il ne peut pas partager une ligne avec
  /// du texte, sous peine de partager aussi ses **attributs de bloc**.
  static const Set<String> _kOwnLineEmbedTypes = <String>{'table'};

  static bool _isOwnLineEmbed(Map<String, dynamic> op) {
    final Object? insert = op['insert'];
    if (insert is! Map || insert.keys.isEmpty) return false;
    return _kOwnLineEmbedTypes.contains(insert.keys.first.toString());
  }

  /// Garantit qu'un embed de bloc TERMINE sa ligne Delta.
  ///
  /// CAUSE RACINE MESURÉE, dans `MarkdownToDelta` : son
  /// `_insertNewLineAfterElementIfNeeded` n'insère le `\n` de sortie de bloc que
  /// si `_justPreviousBlockExit` est `false`, et ce drapeau n'est remis à `false`
  /// que par `visitText`. Or notre élément de tableau (`z-table`) est un
  /// `Element.empty` — **aucun texte à visiter**. Quand un paragraphe le précède,
  /// le drapeau est resté `true` depuis la sortie de ce paragraphe : AUCUN `\n`
  /// n'est émis après le tableau, et l'embed partage alors UNE SEULE ligne Delta
  /// avec le bloc suivant, dont il hérite l'attribut.
  ///
  /// Conséquence à l'écriture : `DeltaToMarkdown` pose le préfixe de bloc
  /// (`## `, `> `, `- `) en TÊTE de ligne — donc AVANT l'embed —, puis la coupure
  /// forcée du handler `table` scinde la ligne en deux et **orpheline le texte** :
  /// `## ` vide avant le tableau, titre nu après. Un tableau en TÊTE de document
  /// n'est pas touché (le drapeau démarre à `false`) : un contrôle qui ne
  /// testerait que ce cas-là passerait sans rien voir.
  ///
  /// On répare donc à la SOURCE, sur la ligne Delta, plutôt qu'à l'écriture :
  /// c'est la structure qui était fausse, pas son rendu.
  static List<Map<String, dynamic>> _ensureOwnLineEmbeds(
    List<Map<String, dynamic>> ops,
  ) {
    if (!ops.any(_isOwnLineEmbed)) return ops; // identité : aucun tableau
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < ops.length; i++) {
      final Map<String, dynamic> op = ops[i];
      if (!_isOwnLineEmbed(op)) {
        out.add(op);
        continue;
      }
      final Object? previous = out.isEmpty ? null : out.last['insert'];
      if (out.isNotEmpty && !(previous is String && previous.endsWith('\n'))) {
        out.add(<String, dynamic>{'insert': '\n'});
      }
      out.add(op);
      final Object? next = i + 1 < ops.length ? ops[i + 1]['insert'] : null;
      if (!(next is String && next.startsWith('\n'))) {
        out.add(<String, dynamic>{'insert': '\n'});
      }
    }
    return out;
  }

  /// Vrai si les ops décodées ne portent AUCUN contenu (que des sauts de ligne
  /// et des blancs, aucun embed) — un document visuellement vide.
  static bool _isBlank(List<Map<String, dynamic>> ops) {
    for (final op in ops) {
      final Object? insert = op['insert'];
      if (insert is! String) return false; // un embed est du contenu
      if (insert.trim().isNotEmpty) return false;
    }
    return true;
  }

  /// Reconnaît un **Delta JSON sérialisé** dans une chaîne, ou `null` si le
  /// texte doit être traité comme du Markdown.
  ///
  /// La règle est délibérément ÉTROITE, parce qu'un faux positif viderait un
  /// document Markdown légitime. Trois conditions cumulatives, mesurées sur un
  /// corpus piège (`[Un lien](url)`, `[1, 2, 3]`, `[]`, `["a","b"]`,
  /// `{"insert":"x"}`, `- [x] fait`, `[ref]: http://…`, JSON tronqué) :
  ///
  /// 1. le texte commence par `[` — un Delta est une LISTE ;
  /// 2. `asDeltaOps` rend une liste non nulle (toute op porte un `insert`) ;
  /// 3. cette liste est NON VIDE — `asDeltaOps('[]')` rend `[]`, pas `null`,
  ///    et `[]` est un texte Markdown parfaitement licite.
  ///
  /// Une détection naïve par `jsonDecode` aurait détourné six de ces entrées et
  /// **throwé** sur cinq autres — le `try/catch` global de [decode] les aurait
  /// alors transformées en document VIDE. Le remède aurait été pire que le mal.
  static List<Map<String, dynamic>>? _asSerializedDelta(String text) {
    if (!text.startsWith('[')) return null;
    try {
      final ops = DeltaNeutralOps.asDeltaOps(text);
      if (ops == null || ops.isEmpty) return null;
      return ops;
    } on Object {
      // JSON invalide → ce n'est pas un Delta, c'est du Markdown. Pas de log :
      // ce chemin est NOMINAL (tout Markdown commençant par `[` y passe).
      return null;
    }
  }

  /// Ré-absorbe les marqueurs littéraux `<u>`, `<sup>`, `<sub>` (issus de
  /// l'encodage) en attributs Delta sur les inserts texte concernés.
  ///
  /// Machine à états DÉFENSIVE : l'état « attribut actif » est maintenu à travers
  /// les ops (un marqueur peut ouvrir dans une op et se fermer dans une autre).
  /// Les ops embed (`insert` non-`String`) sont conservées à l'identique et ne
  /// modifient pas l'état. Les autres attributs d'un insert texte sont préservés
  /// (les attributs de marqueur sont simplement AJOUTÉS). Jamais de throw.
  /// Une op dont le contenu est OPAQUE aux marqueurs littéraux : `code` inline
  /// et bloc de code (A).
  static bool _isOpaqueToMarkers(Object? attributes) {
    if (attributes is! Map) return false;
    return attributes.containsKey(Attribute.inlineCode.key) ||
        attributes.containsKey(Attribute.codeBlock.key);
  }

  static List<Map<String, dynamic>> _absorbMarkerAttrs(
    List<Map<String, dynamic>> ops,
  ) {
    // Court-circuit : aucun marqueur → renvoi tel quel (perf + identité).
    final bool hasMarker = ops.any((op) {
      final Object? insert = op['insert'];
      if (insert is! String) return false;
      return _kMarkerAttrs.any(
        (m) => insert.contains(m.open) || insert.contains(m.close),
      );
    });
    if (!hasMarker) return ops;

    final result = <Map<String, dynamic>>[];
    final active = <String, Object>{};
    for (final op in ops) {
      final Object? insert = op['insert'];
      if (insert is! String) {
        result.add(op);
        continue;
      }
      final Map<String, dynamic>? baseAttrs =
          op['attributes'] is Map<String, dynamic>
              ? op['attributes'] as Map<String, dynamic>
              : null;
      // A — le contenu d'un span `code` est OPAQUE : il n'est pas du
      // Markdown, donc pas davantage du HTML. `` `<u>` `` était consommé comme
      // marqueur ouvrant : le span devenait VIDE (`flush()` abandonne un buffer
      // vide) et `underline` restait armé jusqu'à la fin du bloc — le
      // soulignement avalait la fin de la phrase et une balise fermante
      // apparaissait au cycle suivant. Un code inline SANS HTML survivait :
      // ce n'était pas « le code » qui cassait, c'était le HTML qu'il porte.
      if (_isOpaqueToMarkers(op['attributes'])) {
        final Map<String, dynamic> attrs = <String, dynamic>{
          ...?baseAttrs,
          ...active,
        };
        result.add(<String, dynamic>{
          'insert': insert,
          if (attrs.isNotEmpty) 'attributes': attrs,
        });
        // Un bloc de code porte ses propres `\n` : l'état de marqueur reste
        // borné au BLOC, comme sur le chemin ordinaire.
        if (insert.contains('\n')) active.clear();
        continue;
      }
      // Découpe le texte aux frontières de marqueurs en préservant l'ordre.
      var buffer = StringBuffer();
      void flush() {
        if (buffer.isEmpty) return;
        final Map<String, dynamic> attrs = <String, dynamic>{
          ...?baseAttrs,
          ...active,
        };
        result.add(<String, dynamic>{
          'insert': buffer.toString(),
          if (attrs.isNotEmpty) 'attributes': attrs,
        });
        buffer = StringBuffer();
      }

      var i = 0;
      while (i < insert.length) {
        // Un marqueur NON FERMÉ ne doit pas déborder sur tout le reste du
        // document : un `<u>` orphelin soulignait tous les paragraphes
        // suivants. L'état est donc borné au BLOC — trouvé en revue.
        if (insert.startsWith('\n', i)) {
          flush();
          active.clear();
          result.add(<String, dynamic>{
            'insert': '\n',
            ...?(op['attributes'] is Map<String, dynamic>
                ? <String, dynamic>{'attributes': op['attributes']}
                : null),
          });
          i += 1;
          continue;
        }
        _ZMarkerAttr? opened;
        _ZMarkerAttr? closed;
        for (final marker in _kMarkerAttrs) {
          if (insert.startsWith(marker.open, i)) {
            opened = marker;
            break;
          }
          if (insert.startsWith(marker.close, i)) {
            closed = marker;
            break;
          }
        }
        if (opened != null) {
          flush();
          active[opened.attribute] = opened.value;
          i += opened.open.length;
        } else if (closed != null) {
          flush();
          active.remove(closed.attribute);
          i += closed.close.length;
        } else {
          buffer.write(insert[i]);
          i += 1;
        }
      }
      flush();
    }
    return result;
  }
}
