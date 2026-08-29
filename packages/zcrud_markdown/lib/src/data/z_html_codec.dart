/// `ZHtmlCodec` — codec Delta ↔ **HTML** (AD-7, gap B5). Round-trip
/// **borné** au sous-ensemble exprimable en Delta, avec pertes DOCUMENTÉES.
library;

import 'package:flutter/foundation.dart';
// Libs de conversion ISOLÉES (AD-1) — au SEUL pubspec zcrud_markdown. Aucun de
// ces types (`QuillDeltaToHtmlConverter`, `HtmlToDelta`, `Delta`) n'apparaît
// dans la signature publique de `ZCodec`/`registerZHtmlFields`. Ce sont les
// MÊMES libs qu'utilise l'éditeur historique (`rich_text_editor_screen.dart:12-13`).
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart'
    as html_from;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart'
    as html_to;

import '../domain/z_codec.dart';
import 'delta_neutral_ops.dart';

/// Codec **HTML** : le format persisté est une `String` HTML (B5).
///
/// ## Décision de conception (B5) — extension `zcrud_markdown` via `ZCodec`
///
/// Le type de champ `html`/`inlineHtml` de l'éditeur historique est un **FORMAT DE PERSISTANCE
/// au-dessus d'un contenu Delta** (`HtmlToDelta` à l'ouverture,
/// `QuillDeltaToHtmlConverter` à la sauvegarde). C'est EXACTEMENT le rôle d'un
/// [ZCodec] (AD-7) : `ZHtmlCodec` réutilise l'éditeur/lecteur rich-text isolé
/// (`ZMarkdownField.fromContext` / `ZMarkdownReader` / dialog plein-écran)
/// plutôt qu'un WYSIWYG HTML tiers (`html_editor_enhanced` + WebView).
/// Cela respecte AD-7 (Delta interne + `ZCodec` pluggable), AD-1 (aucun SDK
/// d'éditeur ni type de contenu HTML natif exposé) et /AD-2 (le codec opère
/// HORS du chemin chaud de frappe). Un futur besoin WYSIWYG HTML natif resterait
/// un **satellite distinct** (`zcrud_html`) enregistrant son propre builder sur
/// les mêmes kinds — **hors périmètre**.
///
/// - [encode] : ops Delta neutres → **`String` HTML** (via
///   `vsc_quill_delta_to_html`, isolée). `encode(const [])` → `''`. Défensif :
///   toute exception de conversion → `''` + `debugPrint` non-fatal (AD-10).
/// - [decode] : `String` HTML → ops Delta neutres (via
///   `flutter_quill_delta_from_html`, isolée). Défensif (AD-10) :
///   `null`/vide/HTML malformé/valeur non-`String`/legacy → `[]`, **jamais** de
///   throw. Une valeur `List` (Delta legacy déjà neutre) est tolérée et
///   normalisée en ops neutres (via [DeltaNeutralOps]), comme `ZMarkdownCodec`.
///
/// ## Table des pertes (round-trip borné)
///
/// Le round-trip `decode(encode(ops))` PRÉSERVE la sémantique du **sous-ensemble
/// commun HTML↔Delta** (vérifié par test) : paragraphes, titres H1–H6, gras,
/// italique, souligné, barré, **couleur** (HTML exprime les styles inline —
/// contrairement à Markdown), listes ordonnées/non-ordonnées imbriquées, liens,
/// **blocs** de code (`code-block`), blockquote, texte brut. Il **PERD** — par
/// conception, la conversion HTML↔Delta ne les ré-exprime pas de façon stable — :
///
/// | Attribut / contenu Delta        | Sort au round-trip HTML                |
/// |---------------------------------|----------------------------------------|
/// | `code` **inline**               | balise `<code>` émise à l'encode, mais |
/// |                                 | non re-parsée au décode → l'attribut   |
/// |                                 | est **perdu**, le TEXTE survit         |
/// | Embed LaTeX/tableau | dégradé en placeholder **textuel** |
/// |                                 | `[embed:<type>]`, texte environnant    |
/// |                                 | PRÉSERVÉ (perte **BORNÉE** à l'embed)  |
/// | Attributs non standard / styles | non ré-exprimés → **perdus**           |
/// | exotiques hors sous-ensemble    |                                        |
///
/// > PERTE BORNÉE : un embed opaque au MILIEU du texte ne fait **jamais**
/// > échouer la conversion ni vider le document — il est remplacé AVANT
/// > conversion par un placeholder textuel (`[embed:latex]`, `[embed:table]`, …)
/// > tandis que TOUT le texte non-embed survit. La perte est cantonnée à l'embed.
///
/// Ces pertes sont **assertées explicitement** par `z_html_codec_test.dart`,
/// jamais silencieuses ni fatales. Pour un round-trip **sans perte**, utiliser
/// `ZDeltaCodec` (format persisté = Delta).
///
/// ## Règles de conversion supplémentaires ([customBlocks])
///
/// Le décodage accepte des **règles de conversion HTML → Delta fournies par
/// l'appelant**, relayées telles quelles au convertisseur sous-jacent. Elles
/// permettent de mapper un balisage propre à l'appelant (par exemple des
/// fragments porteurs de LaTeX — `data-formula`, `$$…$$`, `\[…\]`, spans
/// `katex`) vers des ops Delta **natives**, plutôt que de le laisser dégrader
/// en texte.
///
/// La liste est **vide par défaut ⇒ décodage strictement inchangé**. Ce sont
/// des règles de **conversion**, jamais de rendu : le rendu reste celui des
/// embeds Delta (AD-12 intact — aucune WebView, aucun moteur HTML).
///
/// Le type d'une règle appartient à la bibliothèque de conversion
/// (`flutter_quill_delta_from_html`) ; l'appelant qui en fournit une l'importe
/// donc lui-même. Un appelant qui n'en fournit pas ne la voit jamais.
final class ZHtmlCodec implements ZCodec {
  /// Codec `const` (aucun état mutable) ; [customBlocks] vide ⇒ inchangé.
  const ZHtmlCodec({this.customBlocks = const <html_from.CustomHtmlPart>[]});

  // AD-1 : `CustomHtmlPart` est le SEUL type de la lib de conversion qui
  // apparaisse dans une signature publique de ce paquet, et c'est délibéré —
  // il n'existe pas d'équivalent neutre : une règle de conversion se DÉFINIT
  // contre l'arbre DOM de la lib (`dom.Element` → `List<Operation>`). La
  // ré-envelopper derrière un type maison n'isolerait rien (l'implémenteur
  // manipulerait les mêmes types dans le corps) et coûterait une couche
  // d'indirection. Le défaut vide garde l'appelant qui ne s'en sert pas
  // totalement à l'écart de la dépendance.
  /// Règles de conversion HTML → Delta supplémentaires (vide ⇒ inchangé).
  final List<html_from.CustomHtmlPart> customBlocks;

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) {
    if (deltaOps.isEmpty) return '';
    try {
      // PERTE BORNÉE : les `insert` embed opaques (Map) — non
      // exprimables en HTML de façon stable — sont remplacés par un placeholder
      // textuel AVANT conversion ; seul l'embed dégrade, le texte environnant
      // survit. Le convertisseur reçoit des ops NEUTRES (`List<Map>`) — aucun
      // type Quill n'est impliqué côté encode.
      final sanitized = DeltaNeutralOps.sanitizeEmbedsToPlaceholders(deltaOps);
      final html = html_to.QuillDeltaToHtmlConverter(sanitized).convert();
      return html;
    } on Object catch (error, stack) {
      // AD-10 : jamais casser le parent — persisté vide + log non-fatal.
      assert(() {
        debugPrint('ZHtmlCodec.encode: conversion ignorée ($error)\n$stack');
        return true;
      }());
      return '';
    }
  }

  @override
  List<Map<String, dynamic>> decode(Object? persisted) {
    // Tolérance legacy : une valeur non-`String` (ex. `List` Delta déjà décodé)
    // est normalisée défensivement en ops neutres.
    if (persisted is! String) {
      return DeltaNeutralOps.decodeDefensiveOps(persisted);
    }
    final html = persisted.trim();
    if (html.isEmpty) return const <Map<String, dynamic>>[];
    try {
      // `HtmlToDelta().convert` retourne une `Delta` (dart_quill_delta, le même
      // type que `flutter_quill/quill_delta.dart` re-exporte) → ops NEUTRES via
      // le convertisseur partagé (aucun type de conversion ne fuit).
      // Liste vide ⇒ `HtmlToDelta` reçoit `[]`, exactement ce que fait son
      // repli interne quand le paramètre est omis (`customBlocks ?? []`) :
      // le décodage est donc IDENTIQUE à l'appel sans paramètre.
      final delta =
          html_from.HtmlToDelta(customBlocks: customBlocks).convert(html);
      return DeltaNeutralOps.deltaToNeutralOps(delta);
    } on Object catch (error, stack) {
      // AD-10 : HTML malformé/legacy → `[]`, jamais de throw.
      assert(() {
        debugPrint('ZHtmlCodec.decode: HTML ignoré ($error)\n$stack');
        return true;
      }());
      return const <Map<String, dynamic>>[];
    }
  }
}
