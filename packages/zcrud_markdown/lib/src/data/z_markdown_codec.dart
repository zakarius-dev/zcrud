/// `ZMarkdownCodec` — codec Delta ↔ **Markdown** (AD-7). Round-trip **borné** au
/// sous-ensemble Markdown, avec pertes DOCUMENTÉES (AC3, SM-4).
library;

import 'package:flutter/foundation.dart';
// Libs de conversion ISOLÉES (AD-1) — au SEUL pubspec zcrud_markdown. Aucun de
// ces types (`Delta`, `md.Document`, `MarkdownToDelta`, `DeltaToMarkdown`,
// `CustomAttributeHandler`) n'apparaît dans la signature publique de
// `ZCodec`/`ZMarkdownField`.
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

import '../domain/z_codec.dart';
import 'delta_neutral_ops.dart';

/// Clé d'attribut Delta du **souligné** (parité `Attribute.underline.key` de
/// flutter_quill — chaîne stable, gardée locale pour ne pas importer Quill ici).
const String _kUnderlineAttr = 'underline';

/// Marqueurs HTML littéraux portant le souligné à travers le round-trip Markdown
/// (MIN-1, parité DODLP `<u>`). Markdown standard n'exprime pas le souligné : on
/// le SÉRIALISE en `<u>…</u>` (préservé littéralement par `markdown` avec
/// `encodeHtml:false`), puis on le ré-ABSORBE en attribut au décodage.
const String _kUnderlineOpen = '<u>';
const String _kUnderlineClose = '</u>';

/// Codec **Markdown** : le format persisté est une `String` Markdown lisible.
///
/// - [encode] : ops Delta neutres → `Delta` (interne) → `String` Markdown.
///   `encode(const [])` → `''`. Défensif : toute exception de conversion → `''`.
///   Le **souligné** (attribut `underline`) est sérialisé en `<u>…</u>` (MIN-1).
/// - [decode] : `String` Markdown → ops Delta neutres. Défensif (AD-10) :
///   `null`/vide/Markdown mal formé/legacy → `[]`, **jamais** de throw. Une
///   valeur `List` (Delta legacy) est tolérée et normalisée en ops neutres. Les
///   marqueurs `<u>…</u>` sont ré-absorbés en attribut `underline` (MIN-1).
///
/// ## Table des pertes (round-trip borné — SM-4 / AC3)
///
/// Le round-trip `decode(encode(ops))` PRÉSERVE la sémantique du **sous-ensemble
/// Markdown** (titres H1–H6, gras, italique, **souligné** via `<u>`, listes
/// imbriquées, liens, `code` inline + blocs, blockquote, texte brut incluant les
/// entités HTML littérales). Il **PERD** — par conception, Markdown ne les
/// exprime pas — :
///
/// | Attribut / contenu Delta        | Sort au round-trip Markdown            |
/// |---------------------------------|----------------------------------------|
/// | Couleur (`color`)               | **perdu** (non exprimable en MD)       |
/// | Police (`font`)                 | **perdu**                              |
/// | Taille (`size`)                 | **perdu**                              |
/// | Fond (`background`)             | **perdu**                              |
/// | Alignement (`align`)            | **perdu**                              |
/// | Souligné (`underline`)          | **conservé** via `<u>…</u>` (MIN-1)    |
/// | Barré (`strike`)                | conservé si l'app émet `~~` (GFM)      |
/// | Embed LaTeX/tableau (E6-3/E6-4) | dégradé en placeholder `[embed:<type>]`, texte environnant PRÉSERVÉ (perte **BORNÉE** à l'embed — AC9) |
///
/// > LIMITE (MIN-1) : un texte brut contenant littéralement `<u>`/`</u>` saisi
/// > par l'utilisateur serait interprété comme du souligné au décodage (parité
/// > du comportement DODLP : `<u>` est le sentinel du souligné). Cas marginal
/// > assumé, non fatal.
///
/// > PERTE BORNÉE (HIGH-1) : un embed opaque au MILIEU du texte ne fait **jamais**
/// > échouer la conversion ni vider le document — il est remplacé par un
/// > placeholder textuel (`[embed:latex]`, `[embed:table]`, …) tandis que TOUT le
/// > texte non-embed survit. La perte est cantonnée à l'embed lui-même.
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
      return DeltaToMarkdown(
        // MIN-1 : le souligné (non exprimable en Markdown standard) est
        // sérialisé en `<u>…</u>` littéral, préservé au round-trip.
        customTextAttrsHandlers: <String, CustomAttributeHandler>{
          _kUnderlineAttr: CustomAttributeHandler(
            beforeContent: (attribute, node, output) =>
                output.write(_kUnderlineOpen),
            afterContent: (attribute, node, output) =>
                output.write(_kUnderlineClose),
          ),
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
      // MIN-1 : ré-absorbe les marqueurs `<u>…</u>` en attribut `underline`.
      return _absorbUnderlineMarkers(DeltaNeutralOps.deltaToNeutralOps(delta));
    } on Object catch (error, stack) {
      // AD-10 : Markdown mal formé/legacy → `[]`, jamais de throw.
      assert(() {
        debugPrint('ZMarkdownCodec.decode: Markdown ignoré ($error)\n$stack');
        return true;
      }());
      return const <Map<String, dynamic>>[];
    }
  }

  /// Ré-absorbe les marqueurs littéraux `<u>`/`</u>` (issus de l'encodage) en
  /// attribut `underline:true` sur les inserts texte concernés (MIN-1).
  ///
  /// Machine à états DÉFENSIVE : l'état « souligné actif » est maintenu à travers
  /// les ops (un `<u>` peut ouvrir dans une op et se fermer dans une autre). Les
  /// ops embed (`insert` non-`String`) sont conservées à l'identique et ne
  /// modifient pas l'état. Les autres attributs d'un insert texte sont préservés
  /// (le souligné est simplement AJOUTÉ). Jamais de throw.
  static List<Map<String, dynamic>> _absorbUnderlineMarkers(
    List<Map<String, dynamic>> ops,
  ) {
    // Court-circuit : aucun marqueur → renvoi tel quel (perf + identité).
    final bool hasMarker = ops.any((op) {
      final Object? insert = op['insert'];
      return insert is String &&
          (insert.contains(_kUnderlineOpen) ||
              insert.contains(_kUnderlineClose));
    });
    if (!hasMarker) return ops;

    final result = <Map<String, dynamic>>[];
    var underlineActive = false;
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
          if (baseAttrs != null) ...baseAttrs,
          if (underlineActive) _kUnderlineAttr: true,
        };
        result.add(<String, dynamic>{
          'insert': buffer.toString(),
          if (attrs.isNotEmpty) 'attributes': attrs,
        });
        buffer = StringBuffer();
      }

      var i = 0;
      while (i < insert.length) {
        if (insert.startsWith(_kUnderlineOpen, i)) {
          flush();
          underlineActive = true;
          i += _kUnderlineOpen.length;
        } else if (insert.startsWith(_kUnderlineClose, i)) {
          flush();
          underlineActive = false;
          i += _kUnderlineClose.length;
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
