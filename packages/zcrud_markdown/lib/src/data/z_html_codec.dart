/// `ZHtmlCodec` — codec Delta ↔ **HTML** (AD-7, DP-4 / gap B5). Round-trip
/// **borné** au sous-ensemble exprimable en Delta, avec pertes DOCUMENTÉES.
library;

import 'package:flutter/foundation.dart';
// Libs de conversion ISOLÉES (AD-1) — au SEUL pubspec zcrud_markdown. Aucun de
// ces types (`QuillDeltaToHtmlConverter`, `HtmlToDelta`, `Delta`) n'apparaît
// dans la signature publique de `ZCodec`/`registerZHtmlFields`. Ce sont les
// MÊMES libs qu'utilise DODLP (`rich_text_editor_screen.dart:12-13`).
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart'
    as html_from;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart'
    as html_to;

import '../domain/z_codec.dart';
import 'delta_neutral_ops.dart';

/// Codec **HTML** : le format persisté est une `String` HTML (DP-4 / B5).
///
/// ## Décision de conception (B5) — extension `zcrud_markdown` via `ZCodec`
///
/// Le type de champ `html`/`inlineHtml` de DODLP est un **FORMAT DE PERSISTANCE
/// au-dessus d'un contenu Delta** (`HtmlToDelta` à l'ouverture,
/// `QuillDeltaToHtmlConverter` à la sauvegarde). C'est EXACTEMENT le rôle d'un
/// [ZCodec] (AD-7) : `ZHtmlCodec` réutilise l'éditeur/lecteur rich-text isolé
/// (`ZMarkdownField.fromContext` / `ZMarkdownReader` / dialog plein-écran de
/// DP-3) plutôt qu'un WYSIWYG HTML tiers (`html_editor_enhanced` + WebView).
/// Cela respecte AD-7 (Delta interne + `ZCodec` pluggable), AD-1 (aucun SDK
/// d'éditeur ni type de contenu HTML natif exposé) et SM-1/AD-2 (le codec opère
/// HORS du chemin chaud de frappe). Un futur besoin WYSIWYG HTML natif resterait
/// un **satellite distinct** (`zcrud_html`) enregistrant son propre builder sur
/// les mêmes kinds — **hors périmètre** DP-4.
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
/// ## Table des pertes (round-trip borné — DP-4 / AC1)
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
/// | Embed LaTeX/tableau (E6-3/E6-4) | dégradé en placeholder **textuel**     |
/// |                                 | `[embed:<type>]`, texte environnant    |
/// |                                 | PRÉSERVÉ (perte **BORNÉE** à l'embed)  |
/// | Attributs non standard / styles | non ré-exprimés → **perdus**           |
/// | exotiques hors sous-ensemble    |                                        |
///
/// > PERTE BORNÉE (HIGH-1) : un embed opaque au MILIEU du texte ne fait **jamais**
/// > échouer la conversion ni vider le document — il est remplacé AVANT
/// > conversion par un placeholder textuel (`[embed:latex]`, `[embed:table]`, …)
/// > tandis que TOUT le texte non-embed survit. La perte est cantonnée à l'embed.
///
/// Ces pertes sont **assertées explicitement** par `z_html_codec_test.dart`,
/// jamais silencieuses ni fatales. Pour un round-trip **sans perte**, utiliser
/// `ZDeltaCodec` (format persisté = Delta).
///
/// NOTE embeds LaTeX HTML : DODLP mappe des fragments LaTeX HTML ↔ embeds via un
/// `CustomHtmlPart` (`latex_html_part.dart`). Ce mapping fin est **hors périmètre
/// DP-4** (non requis pour la migration de base) : un fragment HTML non
/// convertible dégrade proprement en texte (AD-10), jamais de throw.
final class ZHtmlCodec implements ZCodec {
  /// Codec `const` (aucun état mutable).
  const ZHtmlCodec();

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) {
    if (deltaOps.isEmpty) return '';
    try {
      // PERTE BORNÉE (HIGH-1) : les `insert` embed opaques (Map) — non
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
      final delta = html_from.HtmlToDelta().convert(html);
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
