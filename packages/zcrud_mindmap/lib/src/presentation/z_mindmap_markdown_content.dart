/// `ZMindmapMarkdownContent` — seam rich-text **opt-in** du contenu d'un nœud de
/// carte mentale (Story ES-7.2, OQ-S5 / AD-28 / AD-4 / AD-7 / AD-10).
///
/// ⚠️ **ADAPTATEUR MINCE** (R20/R21, patron ES-6.1 `ZSmartNoteReader`) : il
/// compose `ZMarkdownReader` + `const ZDeltaCodec()` (codec **IDENTITÉ**) de
/// `zcrud_markdown` **TELS QUELS**. **AUCUN** nouveau codec, **AUCUNE** heuristique
/// markdown-vs-Delta, **AUCUN** `QuillController`/`Delta` construit à la main.
/// L'arête `zcrud_mindmap → zcrud_markdown` **préexiste** (aucune nouvelle arête,
/// AD-1).
///
/// **OQ-S5 (AD-28)** : `ZMindmapNode.content` **reste texte brut** ; le payload
/// rich vit dans le **slot AD-4** (`extra[<clé applicative>]` ou `extension`). Ce
/// builder :
/// 1. **résout** les ops Delta depuis le slot AD-4 (clé applicative **paramétrée**
///    — `zcrud_mindmap` n'impose aucune clé réservée) ;
/// 2. les rend en rich-text via `ZMarkdownReader` (**identité** du codec : le
///    payload stocké EST la valeur neutre rendue — round-trip R22) ;
/// 3. **retombe en texte brut** (`content`/`label`) si le slot est absent ou mal
///    formé (défensif AD-10, **jamais** de throw).
///
/// Le `nodeContentBuilder` **par défaut** de `ZMindmapView` reste texte brut : ce
/// builder est un **choix explicite de l'app** (IFFD) ⇒ les autres apps ne sont
/// **pas** forcées de tirer un rendu riche.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import '../domain/z_mindmap_node.dart';
import 'z_mindmap_node_card.dart' show ZMindmapDefaultNodeContent;
import 'z_mindmap_view_config.dart' show ZMindmapNodeContentBuilder;

/// Rendu rich-text **opt-in** du contenu d'un nœud, adossé au slot AD-4.
///
/// À passer en `nodeContentBuilder` de `ZMindmapView` via [builder] (ou à rendre
/// directement comme widget). Le payload rich est lu dans `node.extra[slotKey]`
/// (ops Delta neutres) ; à défaut, repli texte brut.
class ZMindmapMarkdownContent extends StatelessWidget {
  /// Construit le rendu rich-text pour [node].
  ///
  /// [slotKey] est la **clé applicative** du slot AD-4 (`extra`) portant les ops
  /// Delta neutres (`List<Map<String, dynamic>>`). [placeholder] est passé au
  /// lecteur pour un contenu rich **vide** (défaut du lecteur si `null`).
  const ZMindmapMarkdownContent({
    required this.node,
    required this.slotKey,
    this.placeholder,
    super.key,
  });

  /// Nœud immuable rendu (son `content` reste **texte brut**, OQ-S5).
  final ZMindmapNode node;

  /// Clé applicative du slot AD-4 (`extra`) portant le payload rich (ops Delta).
  final String slotKey;

  /// Texte affiché quand le payload rich est **vide** (repli lecteur si `null`).
  final String? placeholder;

  /// Fabrique un `nodeContentBuilder` opt-in liant [slotKey] (et [placeholder]).
  ///
  /// C'est la voie d'usage app : `ZMindmapView(nodeContentBuilder:
  /// ZMindmapMarkdownContent.builder(slotKey: 'rich_delta'))`. Le défaut de la
  /// vue reste texte brut si ce builder n'est pas passé.
  static ZMindmapNodeContentBuilder builder({
    required String slotKey,
    String? placeholder,
  }) =>
      (BuildContext context, ZMindmapNode node) => ZMindmapMarkdownContent(
            node: node,
            slotKey: slotKey,
            placeholder: placeholder,
          );

  /// Résout les ops Delta neutres depuis le slot AD-4, ou `null` si absent/mal
  /// formé (repli plain-text). **Défensif** (AD-10) : n'exige que la forme
  /// minimale `List<Map<String, dynamic>>` ; toute autre forme ⇒ `null`.
  ///
  /// ⚠️ **AUCUNE heuristique** de contenu (pas de `startsWith('[')` ni de
  /// `contains('"insert"')`) : on ne devine pas un format, on lit un slot typé.
  List<Map<String, dynamic>>? _resolveRichOps() {
    final raw = node.extra[slotKey];
    if (raw is! List) return null;
    final ops = <Map<String, dynamic>>[];
    for (final op in raw) {
      if (op is Map<String, dynamic>) {
        ops.add(op);
      } else if (op is Map) {
        ops.add(op.map((k, v) => MapEntry(k.toString(), v)));
      } else {
        // Élément non conforme ⇒ payload rejeté, repli plain-text (AD-10).
        return null;
      }
    }
    return ops;
  }

  @override
  Widget build(BuildContext context) {
    final ops = _resolveRichOps();

    // Repli plain-text (AD-10) : slot absent/mal formé ⇒ défaut sûr texte brut
    // (le MÊME que la vue sans builder rich), jamais un rendu vide ni un throw.
    if (ops == null) {
      return ZMindmapDefaultNodeContent(node: node);
    }

    // Rendu rich-text via le lecteur RÉUTILISÉ + codec IDENTITÉ : le payload
    // stocké EST la valeur neutre rendue (round-trip R22, aucune ré-encodage).
    // `label` alimente la sémantique ; `content` reste texte brut, hors du rich.
    return ZMarkdownReader(
      value: ops,
      codec: const ZDeltaCodec(),
      label: node.label.isNotEmpty ? node.label : null,
      placeholder: placeholder ?? _kDefaultPlaceholder,
    );
  }
}

/// Placeholder par défaut d'un contenu rich vide (parité `ZMarkdownReader`).
const String _kDefaultPlaceholder = 'Aucun contenu';
