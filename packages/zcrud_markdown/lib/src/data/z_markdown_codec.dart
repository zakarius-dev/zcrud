/// `ZMarkdownCodec` — codec Delta ↔ **Markdown** (AD-7). Round-trip **borné** au
/// sous-ensemble Markdown, avec pertes DOCUMENTÉES (AC3, SM-4).
library;

import 'package:flutter/foundation.dart';
// Libs de conversion ISOLÉES (AD-1) — au SEUL pubspec zcrud_markdown. Aucun de
// ces types (`Delta`, `md.Document`, `MarkdownToDelta`, `DeltaToMarkdown`)
// n'apparaît dans la signature publique de `ZCodec`/`ZMarkdownField`.
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

import '../domain/z_codec.dart';
import 'delta_neutral_ops.dart';

/// Codec **Markdown** : le format persisté est une `String` Markdown lisible.
///
/// - [encode] : ops Delta neutres → `Delta` (interne) → `String` Markdown.
///   `encode(const [])` → `''`. Défensif : toute exception de conversion → `''`.
/// - [decode] : `String` Markdown → ops Delta neutres. Défensif (AD-10) :
///   `null`/vide/Markdown mal formé/legacy → `[]`, **jamais** de throw. Une
///   valeur `List` (Delta legacy) est tolérée et normalisée en ops neutres.
///
/// ## Table des pertes (round-trip borné — SM-4 / AC3)
///
/// Le round-trip `decode(encode(ops))` PRÉSERVE la sémantique du **sous-ensemble
/// Markdown** (titres H1–H6, gras, italique, listes imbriquées, liens, `code`
/// inline + blocs, blockquote, texte brut incluant les entités HTML littérales).
/// Il **PERD** — par conception, Markdown ne les exprime pas — :
///
/// | Attribut / contenu Delta        | Sort au round-trip Markdown            |
/// |---------------------------------|----------------------------------------|
/// | Couleur (`color`)               | **perdu** (non exprimable en MD)       |
/// | Police (`font`)                 | **perdu**                              |
/// | Taille (`size`)                 | **perdu**                              |
/// | Fond (`background`)             | **perdu**                              |
/// | Alignement (`align`)            | **perdu**                              |
/// | Souligné (`underline`)          | **perdu** (pas de MD standard)         |
/// | Barré (`strike`)                | conservé si l'app émet `~~` (GFM)      |
/// | Embed LaTeX/tableau (E6-3/E6-4) | dégradé en placeholder `[embed:<type>]`, texte environnant PRÉSERVÉ (perte **BORNÉE** à l'embed — AC9) |
///
/// > PERTE BORNÉE (HIGH-1) : un embed opaque au MILIEU du texte ne fait **jamais**
/// > échouer la conversion ni vider le document — il est remplacé par un
/// > placeholder textuel (`[embed:formula]`, `[embed:z-table]`, …) tandis que
/// > TOUT le texte non-embed survit. La perte est cantonnée à l'embed lui-même.
///
/// Ces pertes sont **assertées explicitement** par le test « table des pertes »
/// (`z_markdown_codec_test.dart`), jamais silencieuses ni fatales. Pour un
/// round-trip **sans perte**, utiliser `ZDeltaCodec` (format persisté = Delta).
final class ZMarkdownCodec implements ZCodec {
  /// Codec `const` (aucun état mutable).
  const ZMarkdownCodec();

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) {
    if (deltaOps.isEmpty) return '';
    try {
      final delta = DeltaNeutralOps.toDeltaForMarkdown(deltaOps);
      if (delta.isEmpty) return '';
      return DeltaToMarkdown().convert(delta);
    } on Object catch (error, stack) {
      // AD-10 : jamais casser le parent — persisté vide + log non-fatal.
      assert(() {
        debugPrint('ZMarkdownCodec.encode: conversion ignorée ($error)\n$stack');
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
    final text = persisted.trim();
    if (text.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final mdDocument = md.Document(encodeHtml: false);
      final delta =
          MarkdownToDelta(markdownDocument: mdDocument).convert(persisted);
      return DeltaNeutralOps.deltaToNeutralOps(delta);
    } on Object catch (error, stack) {
      // AD-10 : Markdown mal formé/legacy → `[]`, jamais de throw.
      assert(() {
        debugPrint('ZMarkdownCodec.decode: Markdown ignoré ($error)\n$stack');
        return true;
      }());
      return const <Map<String, dynamic>>[];
    }
  }
}
