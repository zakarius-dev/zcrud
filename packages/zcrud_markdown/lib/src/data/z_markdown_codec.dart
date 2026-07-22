/// `ZMarkdownCodec` — codec Delta ↔ **Markdown** (AD-7). Round-trip **borné** au
/// sous-ensemble Markdown, avec pertes DOCUMENTÉES (AC3, SM-4).
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
import 'z_markdown_escaping.dart';
import 'z_table_markdown.dart';

/// Attribut d'élément portant la donnée d'un pont entre le parseur Markdown et
/// la construction de l'embed. Interne : jamais visible d'un hôte.
const String _kBridgeDataAttr = 'data';

/// Nom d'élément Markdown interne portant un tableau reconnu.
const String _kTableTag = 'z-table';

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
/// relire notre propre écriture rouvrirait l'asymétrie que CR-IFFD-24 dénonce.
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
    final element = md.Element.empty(tag)
      ..attributes[_kBridgeDataAttr] = bridge.dataOf(match).toString();
    parser.addNode(element);
    return true;
  }
}

/// Un attribut Delta porté à travers le Markdown par une paire de marqueurs
/// HTML littéraux (Markdown standard ne l'exprime pas). Préservés tels quels par
/// `markdown` avec `encodeHtml:false`, puis RÉ-ABSORBÉS en attribut au décodage.
///
/// Ce mécanisme existait pour le seul souligné (MIN-1, parité DODLP `<u>`) ; il
/// est GÉNÉRALISÉ (CR-IFFD-24 §2) à l'exposant/indice, dont les deux boutons
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
/// doivent donc PAS être dégradés en placeholder (CR-IFFD-24 §1).
///
/// - `image` : `DeltaToMarkdown` émet `![](src)` et `MarkdownToDelta` relit
///   `![alt](src)` — le pont existait des deux côtés, il était neutralisé en
///   amont. C'est la perte la plus grave corrigée par ce tag : une image
///   disparaissait au PREMIER enregistrement, URL comprise.
/// - `divider` (`---`) : `MarkdownToDelta` construit l'embed depuis `hr` et
///   `DeltaToMarkdown` écrit `- - -`. Le pont existait des DEUX côtés, comme
///   pour l'image — et il était neutralisé au même endroit. Corriger l'image
///   sans chercher son jumeau, c'était traiter un symptôme : trouvé en revue.
/// - `table` : rendu en TABLEAU GFM lisible quand ce rendu se relit à
///   l'identique, en bloc clôturé `\`\`\`zcrud-table` sinon (charge JSON exacte).
///   Avant la v0.8.0 un tableau perdait **toutes ses cellules** au premier
///   enregistrement — ce n'était pas une dégradation documentée, c'était la même
///   destruction que celle de l'image.
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

/// Codec **Markdown** : le format persisté est une `String` Markdown lisible.
///
/// - [encode] : ops Delta neutres → `Delta` (interne) → `String` Markdown.
///   `encode(const [])` → `''`. Défensif : toute exception de conversion → `''`.
/// - [decode] : `String` Markdown → ops Delta neutres. Défensif (AD-10) :
///   `null`/vide/Markdown mal formé/legacy → `[]`, **jamais** de throw. Une
///   valeur `List` (Delta legacy) **ou une `String` contenant un Delta JSON
///   sérialisé** est tolérée et normalisée en ops neutres (CR-IFFD-23 §1).
///
/// ## Table des pertes (round-trip borné — SM-4 / AC3)
///
/// > ⚠️ **Cette table a été FAUSSE de la v0.1.0 à la v0.6.0 incluse** sur deux
/// > lignes, et INCOMPLÈTE sur trois pertes. Elle annonçait « titres H1–H6 »
/// > alors que H4–H6 étaient écrasés, et « barré conservé » alors que le
/// > décodeur ne savait pas relire `~~`. Aucun test ne l'exécutait : le groupe
/// > « assertion EXPLICITE de chaque perte » n'en couvrait que 2 sur 8. Les deux
/// > défauts sont CORRIGÉS depuis la v0.7.0 (CR-IFFD-24 §1), et chaque ligne
/// > ci-dessous est désormais assertée par exécution.
///
/// Le round-trip `decode(encode(ops))` PRÉSERVE la sémantique du **sous-ensemble
/// Markdown** : titres **H1–H6**, gras, italique, **souligné** via `<u>`,
/// **barré** via `~~` (GFM), **cases à cocher** `- [x]`/`- [ ]`, **tableaux**
/// (`| a | b |`, avec repli sans perte), **exposant /
/// indice** via `<sup>`/`<sub>`, listes imbriquées, liens, **images** via
/// `![](src)`, `code` inline + blocs, blockquote, texte brut. Il **PERD** :
///
/// | Attribut / contenu Delta        | Sort au round-trip Markdown            |
/// |---------------------------------|----------------------------------------|
/// | Couleur (`color`)               | **perdu** (non exprimable en MD)       |
/// | Police (`font`)                 | **perdu**                              |
/// | Taille (`size`)                 | **perdu**                              |
/// | Fond (`background`)             | **perdu**                              |
/// | Alignement (`align`)            | **perdu**                              |
/// | Vidéo (`video`)                 | **dégradé en LIEN** `[src](src)` — la source SURVIT, le type d'embed non |
/// | Entité HTML littérale (`&amp;`) | **résolue** en son caractère (`&`) dès le premier round-trip — la forme entité n'est pas restituée |
/// | Embed LaTeX/tableau (E6-3/E6-4) | dégradé en placeholder `\[embed:<type>\]` (échappé), texte environnant PRÉSERVÉ (perte **BORNÉE** à l'embed — AC9) |
///
/// > LIMITE (MIN-1) : un texte brut contenant littéralement `<u>`/`</u>`,
/// > `<sup>`/`<sub>` saisi par l'utilisateur serait interprété comme l'attribut
/// > correspondant au décodage. Cas marginal assumé, non fatal.
///
/// > PERTE BORNÉE (HIGH-1) : un embed opaque au MILIEU du texte ne fait **jamais**
/// > échouer la conversion ni vider le document — il est remplacé par un
/// > placeholder textuel (`[embed:latex]`, `[embed:table]`, …) tandis que TOUT le
/// > texte non-embed survit. La perte est cantonnée à l'embed lui-même.
///
/// Pour un round-trip **sans perte**, utiliser `ZDeltaCodec` (persisté = Delta).
final class ZMarkdownCodec implements ZCodec {
  /// Codec `const` (aucun état mutable).
  ///
  /// [bridges] — ponts Markdown ↔ embed **opt-in** (CR-IFFD-23 §3 /
  /// CR-IFFD-24 §2). Vide par défaut : sans déclaration, le comportement est
  /// EXACTEMENT celui d'avant, et les embeds continuent de dégrader en
  /// placeholder. Cf. `ZMarkdownBridges.latex` pour un jeu prêt à l'emploi.
  const ZMarkdownCodec({
    this.bridges = const <ZMarkdownEmbedBridge>[],
  });

  /// Ponts Markdown ↔ embed déclarés par l'hôte. L'ordre compte : le premier
  /// motif qui correspond gagne (d'où `$$…$$` avant `$…$`).
  final List<ZMarkdownEmbedBridge> bridges;

  /// Types d'embed exprimables : natifs + ceux qu'un pont sait réémettre.
  Set<String> get _expressibleEmbedTypes => <String>{
        ..._kNativeEmbedTypes,
        for (final bridge in bridges) bridge.embedType,
      };

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
  /// ⚠️ **`ExtensionSet.gitHubFlavored` n'est PAS utilisé, délibérément.** Il
  /// embarque `TableSyntax`, et `MarkdownToDelta` APLATIT une table en
  /// concaténant ses cellules — mesuré : `| a | b |…` devient `ab12`, séparateurs
  /// et structure détruits. Aujourd'hui une table survit en texte littéral, donc
  /// l'activer serait échanger une perte contre une DESTRUCTION. Le pont
  /// table↔embed est un chantier à part.
  md.Document _markdownDocument() => md.Document(
        encodeHtml: false,
        // Les syntaxes des ponts passent AVANT les syntaxes par défaut
        // (`md.Document` insère `inlineSyntaxes` en tête) : un hôte peut donc
        // faire primer `$…$` sur l'interprétation ordinaire du texte.
        blockSyntaxes: const <md.BlockSyntax>[
          // CR-IFFD-24 §1 : `- [x]` / `1. [x]` → `{list: checked|unchecked}`.
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
          md.UnorderedListWithCheckboxSyntax(),
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
          // CR-IFFD-24 §1 : `~~x~~` → `{strike: true}`. L'encodeur émettait déjà
          // du `~~` que le décodeur ne savait pas relire.
          _ZDoubleTildeStrikethroughSyntax(),
        ],
      );

  /// Convertisseur Markdown → Delta.
  ///
  /// `customElementToBlockAttribute` restaure **H4–H6** (CR-IFFD-24 §1) :
  /// `markdown_quill` ne mappe nativement que `h1`–`h3`, alors que
  /// `flutter_quill` expose bien `Attribute.h4`/`h5`/`h6`. La limite n'était donc
  /// pas dans le modèle mais dans le convertisseur.
  ///
  /// ⚠️ La fusion interne de `MarkdownToDelta` est `{...custom, ...builtin}` :
  /// une clé DÉJÀ définie nativement (`h1`, `img`, `em`…) ne peut PAS être
  /// surchargée par ce chemin. On n'y AJOUTE que des clés absentes.
  MarkdownToDelta _markdownToDelta() => MarkdownToDelta(
        markdownDocument: _markdownDocument(),
        customElementToBlockAttribute: <String, ElementToAttributeConvertor>{
          'h4': (_) => <Attribute<dynamic>>[Attribute.h4],
          'h5': (_) => <Attribute<dynamic>>[Attribute.h5],
          'h6': (_) => <Attribute<dynamic>>[Attribute.h6],
        },
        // Chaque pont déclaré devient un élément Markdown interne, remonté en
        // embed Delta du type annoncé par l'hôte (CR-IFFD-23 §3).
        customElementToEmbeddable: <String, ElementToEmbeddableConvertor>{
          // `Embeddable` et non `BlockEmbed` : la charge d'un tableau est une
          // STRUCTURE (`{rows, columns, cells}`), et `BlockEmbed` contraint sa
          // donnée à une `String`.
          _kTableTag: (attrs) => Embeddable(
                'table',
                _tablePayload(attrs[_kBridgeDataAttr] ?? ''),
              ),
          for (var i = 0; i < bridges.length; i++)
            _bridgeTag(i): (attrs) =>
                BlockEmbed(bridges[i].embedType, attrs[_kBridgeDataAttr] ?? ''),
        },
      );

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) {
    if (deltaOps.isEmpty) return '';
    try {
      final delta = DeltaNeutralOps.toDeltaForMarkdown(
        // CR-IFFD-24 §3 : `** gras **` n'est pas du gras, et `a_ ital _b` n'est
        // pas de l'italique du tout — un `_` intra-mot n'ouvre aucune emphase.
        zMoveSpacesOutOfMarkers(deltaOps),
        // Un embed n'est préservé que si l'encodeur sait l'écrire : natif
        // (image/vidéo) ou porté par un pont déclaré. Les autres dégradent en
        // placeholder — sans quoi `DeltaToMarkdown` throwerait et VIDERAIT le
        // document entier (HIGH-1).
        preserveEmbedTypes: _expressibleEmbedTypes,
      );
      if (delta.isEmpty) return '';
      return DeltaToMarkdown(
        // CR-IFFD-23 §2 : n'échappe les ouvreurs de bloc qu'en tête de ligne,
        // ET les caractères que les ponts déclarés rendent significatifs.
        customContentHandler: zMarkdownContentEscaper(
          extraDangerous: <String>{
            for (final bridge in bridges) ...bridge.escapedCharacters,
          },
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
          // Pas de forme Markdown native pour la vidéo : lien vers la source.
          // `image` n'est PAS listé ici — `DeltaToMarkdown` sait déjà l'écrire,
          // et un handler custom masquerait le built-in.
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
          // Ponts déclarés : la moitié qui manquait (CR-IFFD-23 §3). Un pont
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
    } on Object catch (error, stack) {
      // AD-10 : jamais casser le parent — persisté vide + log non-fatal.
      assert(() {
        debugPrint('ZMarkdownCodec.encode: conversion ignorée ($error)\n$stack');
        return true;
      }());
      return '';
    }
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
    // CR-IFFD-23 §1 : un corpus Quill legacy est stocké sous la forme
    // `jsonEncode(document.toDelta().toJson())` — donc une `String`, pas une
    // `List`. Elle empruntait la branche Markdown et s'affichait LITTÉRALEMENT
    // (`[{"insert":"…"}]` à l'écran), en perdant au passage TOUT le document,
    // attributs et embeds compris.
    final List<Map<String, dynamic>>? serializedDelta = _asSerializedDelta(text);
    if (serializedDelta != null) return serializedDelta;
    try {
      final delta = _markdownToDelta().convert(persisted);
      final ops = _absorbMarkerAttrs(DeltaNeutralOps.deltaToNeutralOps(delta));
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
  /// texte doit être traité comme du Markdown (CR-IFFD-23 §1).
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
