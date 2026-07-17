/// `ZMindmapMarkdownEditField` — seam **d'ÉDITION** rich-text opt-in d'un champ de
/// nœud de carte mentale (Story SU-12, AD-40 / AD-28 / AD-7 / AD-10).
///
/// ⚠️ **ADAPTATEUR MINCE** (patron `ZMindmapMarkdownContent`, pendant ÉDITION du
/// rendu) : il compose `ZMarkdownField.fromContext` (voie `ctx` value-in-slice) +
/// `const ZDeltaCodec()` (codec **IDENTITÉ**) de `zcrud_markdown` **TELS QUELS**.
/// **AUCUN** `QuillController`/`Delta`/`flutter_math_fork` dans une signature
/// publique (AD-7) : la valeur portée est **neutre** (ops Delta JSON). L'arête
/// `zcrud_mindmap → zcrud_markdown` **préexiste** (aucune arête nouvelle, AD-1) ;
/// l'adaptateur vit CHEZ LE CONSOMMATEUR (`zcrud_mindmap`), **jamais** dans
/// `zcrud_markdown` (test de graphe anti-cycle).
///
/// **OQ-S5 / AD-28** : `ZMindmapNode.label`/`content` restent **texte brut** ; le
/// payload rich vit dans le **slot AD-4** `extra[slotKey]` — **le MÊME** slot que
/// `ZMindmapMarkdownContent` LIT (symétrie round-trip R22, écriture ⇄ lecture).
/// Les deux fabriques sont symétriques :
/// `ZMindmapMarkdownContent.builder(slotKey:)` (rendu) ⇄
/// `ZMindmapMarkdownEditField.builder(slotKey:)` (édition).
///
/// **Slot par KIND** (SU-12) : le slot `content` écrit `extra[slotKey]` (symétrie
/// EXACTE avec le rendu) ; le slot `label` écrit `extra['${slotKey}__label']`
/// (payload distinct — jamais de collision content⇄label, `node.label` reste
/// plain). Voir [slotKeyFor].
///
/// **AD-2/SM-1** : place stable (`ValueKey(node.id + kind)`) ⇒ le `State`/le
/// `QuillController` isolé ne sont **jamais** recréés au rebuild structurel de
/// l'outline (zéro perte de focus/curseur). **AD-7 borné (AC7)** : mode `inline`
/// + `maxLines` ⇒ hauteur **bornée**, défilement interne — l'éditeur ne vole pas
/// le scroll de l'outline (`ListView.builder`).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'z_mindmap_view_config.dart';

/// Adaptateur d'édition rich-text d'un champ de nœud, adossé au slot AD-4.
///
/// Usage app : `ZMindmapOutlineEditor(editFieldBuilder:
/// ZMindmapMarkdownEditField.builder(slotKey: 'rich_delta'))`. Sans injection,
/// l'outline retombe sur son `TextField` texte brut (aucune régression).
class ZMindmapMarkdownEditField extends StatelessWidget {
  /// Construit l'éditeur rich-text pour le champ décrit par [ctx], stockant le
  /// payload dans `extra[`[slotKeyFor]`(baseSlotKey, ctx.kind)]`.
  const ZMindmapMarkdownEditField({
    required this.ctx,
    required this.baseSlotKey,
    this.maxLines,
    super.key,
  });

  /// Contexte du slot d'édition (nœud, kind, voie d'écriture du slot AD-4…).
  final ZMindmapEditFieldContext ctx;

  /// Clé applicative **de base** du slot AD-4 (`extra`). Le slot effectif est
  /// dérivé par [slotKeyFor] selon `ctx.kind` (content = base, label = `__label`).
  final String baseSlotKey;

  /// Hauteur MAX (en lignes) de l'éditeur compact borné (AC7). `null` ⇒ défaut
  /// par kind (`label` → 2, `content` → 4).
  final int? maxLines;

  /// Fabrique un [ZMindmapEditFieldBuilder] liant [slotKey] — **symétrique** de
  /// `ZMindmapMarkdownContent.builder(slotKey:)`. C'est la voie d'usage app.
  static ZMindmapEditFieldBuilder builder({
    required String slotKey,
    int? maxLines,
  }) =>
      (BuildContext context, ZMindmapEditFieldContext ctx) =>
          ZMindmapMarkdownEditField(
            // Place STABLE (SM-1/AD-2) : le State/QuillController isolé persiste
            // à travers les rebuilds structurels de l'outline.
            key: ValueKey<String>(
              'zmindmap-rich-edit-${ctx.node.id}-${ctx.kind.name}',
            ),
            ctx: ctx,
            baseSlotKey: slotKey,
            maxLines: maxLines,
          );

  /// Slot AD-4 **effectif** selon [kind] : `content` → [baseSlotKey] (symétrie
  /// EXACTE avec le rendu `ZMindmapMarkdownContent`) ; `label` → un slot voisin
  /// distinct (`'${baseSlotKey}__label'`) pour ne jamais entrer en collision avec
  /// le payload content. `node.label`/`content` restent plain quoi qu'il arrive.
  static String slotKeyFor(String baseSlotKey, ZMindmapEditFieldKind kind) =>
      kind == ZMindmapEditFieldKind.content
          ? baseSlotKey
          : '${baseSlotKey}__label';

  /// Résout les ops Delta neutres COURANTES depuis le slot AD-4, défensivement
  /// (AD-10) : toute forme autre que `List<Map<String, dynamic>>` ⇒ liste vide
  /// (jamais de throw). Réutilise l'invariant du rendu (lecture d'un slot typé).
  List<Map<String, dynamic>> _currentOps(String slotKey) {
    final raw = ctx.node.extra[slotKey];
    return _coerceOps(raw);
  }

  /// Coercition défensive d'une valeur brute en ops Delta neutres (AD-10).
  static List<Map<String, dynamic>> _coerceOps(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    final ops = <Map<String, dynamic>>[];
    for (final op in raw) {
      if (op is Map<String, dynamic>) {
        ops.add(op);
      } else if (op is Map) {
        ops.add(op.map((k, v) => MapEntry(k.toString(), v)));
      } else {
        // Élément non conforme ⇒ payload rejeté (repli liste vide, AD-10).
        return const <Map<String, dynamic>>[];
      }
    }
    return ops;
  }

  @override
  Widget build(BuildContext context) {
    final slotKey = slotKeyFor(baseSlotKey, ctx.kind);
    final int boundedMaxLines = maxLines ??
        (ctx.kind == ZMindmapEditFieldKind.content ? 4 : 2);
    // AD-13 (a11y) : la zone éditable (contrôle FOCUSABLE `Semantics(textField)`)
    // est la cible d'interaction — elle doit atteindre la cible tactile minimale
    // `ctx.config.minTapTarget` (≥ 48 dp), à parité avec le `TextField` défaut qui
    // pose `minHeight: config.minTapTarget`. En mode `inline`, la hauteur de
    // l'éditeur ≈ `minLines × lineHeight` : on plancher `minLines` pour franchir
    // la cible (sinon `minLines: 1` ⇒ ~37 dp < 48 dp, régression sous le défaut).
    final double lineHeight =
        (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 16) * 1.5;
    final int tapTargetLines = (ctx.config.minTapTarget / lineHeight).ceil();
    final int minLines = tapTargetLines < 1 ? 1 : tapTargetLines;
    // La borne max ne peut jamais rogner le plancher a11y (min ≤ max toujours) :
    // la cible tactile AD-13 prime sur une borne max trop basse.
    final int effectiveMaxLines =
        boundedMaxLines < minLines ? minLines : boundedMaxLines;
    // Spec `ZFieldSpec` NEUTRE du champ (voie `ctx` : `field.name` sert seulement
    // à la sémantique, PAS à résoudre la valeur — celle-ci vient de `ctx.value`).
    final fieldSpec = ZFieldSpec(
      name: 'zmindmap-${ctx.node.id}-${ctx.kind.name}',
      type: EditionFieldType.markdown,
      label: ctx.hint,
    );
    return ZMarkdownField.fromContext(
      ctx: ZFieldWidgetContext(
        field: fieldSpec,
        // Valeur neutre courante (ops Delta) lue dans le slot AD-4.
        value: _currentOps(slotKey),
        // Écriture : pousse les ops NEUTRES dans le slot AD-4 via la voie du
        // contexte (→ `controller.editRichSlot`, SANS notifier — SM-1). `label`/
        // `content` restent plain (OQ-S5/AD-28).
        onChanged: (value) => ctx.writeRichSlot(slotKey, _coerceOps(value)),
      ),
      // Éditeur compact BORNÉ (AC7) : hauteur plafonnée ⇒ défilement interne, ne
      // vole pas le scroll de l'outline.
      mode: ZMarkdownFieldMode.inline,
      minLines: minLines,
      maxLines: effectiveMaxLines,
      // Codec IDENTITÉ : le payload stocké EST la valeur neutre (round-trip R22).
      codec: const ZDeltaCodec(),
    );
  }
}
