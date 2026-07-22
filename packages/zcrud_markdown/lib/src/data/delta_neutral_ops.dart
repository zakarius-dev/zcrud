/// Utilitaires de conversion **neutre** + décodage **défensif** (AD-10) Delta,
/// factorisés depuis `ZMarkdownField` (E6-1) pour être PARTAGÉS par le champ et
/// les codecs (E6-2), **sans changer** le comportement prouvé d'E6-1.
///
/// ISOLATION (AD-1) : ce fichier vit sous `lib/src/` de `zcrud_markdown` et peut
/// donc consommer `flutter_quill`. AUCUN type Quill/lib de conversion n'est
/// exposé par le barrel : la surface publique (`ZCodec`, `ZMarkdownField`) reste
/// NEUTRE (`List<Map<String, dynamic>>`, `Object?`, `String`).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// Conversions NEUTRE ↔ Delta + décodage défensif partagées (E6-1/E6-2).
///
/// La « valeur neutre » est une `List<Map<String, dynamic>>` d'ops Delta JSON-safe
/// (jamais un `Document`/`Delta`). Le décodage défensif ne throw **JAMAIS**
/// (AD-10) : toute entrée `null`/vide/corrompue/legacy → `Document` vide / `[]`.
abstract final class DeltaNeutralOps {
  const DeltaNeutralOps._();

  /// Normalise une valeur de tranche en `List<Map<String, dynamic>>` (ops Delta)
  /// ou `null` si non convertible. Accepte une `List` (Delta JSON déjà décodé)
  /// ou une `String` JSON (tolérance). Peut throw sur JSON invalide → capté par
  /// l'appelant (AD-10). Comportement IDENTIQUE à `_asDeltaOps` d'E6-1.
  static List<Map<String, dynamic>>? asDeltaOps(Object? value) {
    Object? raw = value;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      raw = jsonDecode(trimmed); // peut throw → capté par l'appelant (AD-10)
    }
    if (raw is! List) return null;
    final ops = <Map<String, dynamic>>[];
    for (final op in raw) {
      if (op is! Map) return null; // opération malformée → défensif
      // DÉGEL PROFOND. `zTableEmbedOp` gèle sa charge (`zUnmodifiableJsonMapList`)
      // et rend des `UnmodifiableMapView<Object?, Object?>` ; `Document.fromJson`
      // les caste en `Map<String, dynamic>` et LÈVE. Le filet AD-10 attrapait
      // alors l'exception et rendait un document VIDE : une op de tableau
      // parfaitement valide faisait DISPARAÎTRE tout le contenu, sans erreur
      // visible. Défaut préexistant, trouvé en câblant le rendu de cellule.
      final map = _thawMap(op);
      // Une op Delta valide porte `insert` (édition) ; `retain`/`delete` n'ont
      // pas de sens dans un document persisté. `insert` absent ⇒ malformé.
      if (!map.containsKey('insert')) return null;
      ops.add(map);
    }
    return ops;
  }

  /// Dégèle en profondeur une `Map` d'op en structures ordinaires.
  static Map<String, dynamic> _thawMap(Map<Object?, dynamic> map) =>
      <String, dynamic>{
        for (final MapEntry<Object?, dynamic> e in map.entries)
          e.key.toString(): _thawValue(e.value),
      };

  static Object? _thawValue(Object? value) {
    if (value is Map) return _thawMap(value);
    if (value is List) return <dynamic>[for (final Object? v in value) _thawValue(v)];
    return value;
  }

  /// Décode DÉFENSIVEMENT (AD-10) une valeur de tranche en [Document].
  ///
  /// `null` / vide / JSON invalide / structure inattendue / opération malformée
  /// (`insert` manquant, type non-`List`, …) → [Document] VIDE utilisable,
  /// **jamais** de throw (log non-fatal en debug). Parité stricte avec
  /// `_decodeDefensive` d'E6-1.
  static Document decodeDefensiveDocument(Object? sliceValue) {
    if (sliceValue == null) return Document();
    try {
      final ops = asDeltaOps(sliceValue);
      if (ops == null || ops.isEmpty) return Document();
      return Document.fromJson(ops);
    } on Object catch (error, stack) {
      // AD-10 : ne JAMAIS casser le parent — document vide + log non-fatal.
      assert(() {
        debugPrint('DeltaNeutralOps: Delta corrompu ignoré ($error)\n$stack');
        return true;
      }());
      return Document();
    }
  }

  /// Décode DÉFENSIVEMENT une valeur en ops Delta NEUTRES **sans** normaliser
  /// via [Document] (préserve l'IDENTITÉ des ops, y.c. embeds opaques — AC2/AC9).
  ///
  /// `null` / vide / corrompu / legacy → `[]`, **jamais** de throw (AD-10).
  static List<Map<String, dynamic>> decodeDefensiveOps(Object? value) {
    if (value == null) return const <Map<String, dynamic>>[];
    try {
      final ops = asDeltaOps(value);
      if (ops == null) return const <Map<String, dynamic>>[];
      return ops;
    } on Object catch (error, stack) {
      assert(() {
        debugPrint('DeltaNeutralOps: ops corrompues ignorées ($error)\n$stack');
        return true;
      }());
      return const <Map<String, dynamic>>[];
    }
  }

  /// Encode un [Document] en **valeur neutre** JSON-safe
  /// (`List<Map<String, dynamic>>`) — JAMAIS un type Quill exposé (AD-1/AD-8).
  /// Parité stricte avec `_encodeNeutral` d'E6-1.
  static List<Map<String, dynamic>> encodeNeutral(Document document) {
    final json = document.toDelta().toJson();
    return <Map<String, dynamic>>[
      for (final Object? op in json)
        if (op is Map)
          op.map<String, dynamic>(
            (key, dynamic v) => MapEntry(key.toString(), v),
          ),
    ];
  }

  /// Convertit des ops neutres en [Delta] prête pour `DeltaToMarkdown` :
  ///
  /// - PERTE BORNÉE À L'EMBED (AC9, HIGH-1) : un `insert` **embed** (Map opaque —
  ///   formule LaTeX E6-3, tableau E6-4) n'est pas exprimable en Markdown et
  ///   ferait **throw** `DeltaToMarkdown` (aucun handler d'embed inconnu) → la
  ///   conversion échouerait et le document ENTIER serait persisté vide (perte
  ///   TOTALE). On remplace donc chaque embed par un **placeholder TEXTUEL**
  ///   (`[embed:<type>]`) AVANT conversion : seul l'embed dégrade, le texte
  ///   environnant SURVIT (perte bornée, jamais totale).
  /// - garantit le `'\n'` final requis par un document Delta (sinon
  ///   `Document.fromDelta` interne à la conversion throw).
  ///
  /// Interne au package.
  static Delta toDeltaForMarkdown(
    List<Map<String, dynamic>> ops, {
    Set<String> preserveEmbedTypes = const <String>{},
  }) {
    final sanitized = <Map<String, dynamic>>[
      for (final op in ops)
        if (op['insert'] is Map &&
            !_isPreserved(op['insert'] as Map, preserveEmbedTypes))
          <String, dynamic>{'insert': _embedPlaceholder(op['insert'] as Map)}
        else if (op['insert'] is Map)
          <String, dynamic>{...op, 'insert': _thaw(op['insert'])}
        else
          op,
    ];
    final delta = Delta.fromJson(sanitized);
    if (delta.isEmpty) return delta;
    final Object? lastValue = delta.last.value;
    final endsWithNewline = lastValue is String && lastValue.endsWith('\n');
    if (!endsWithNewline) {
      delta.insert('\n');
    }
    return delta;
  }

  /// Remplace chaque `insert` **embed** opaque (Map) par un **placeholder
  /// TEXTUEL** `[embed:<type>]` (perte BORNÉE — HIGH-1 / DP-4 AC1), sur des ops
  /// NEUTRES (`List<Map>`), sans passer par [Delta]. Réutilisé par les codecs
  /// non-Delta (HTML) qui ne savent pas exprimer un embed opaque : seul l'embed
  /// dégrade, le texte environnant SURVIT (jamais un document vidé). Les `insert`
  /// texte sont conservés à l'identique (attributs inclus).
  static List<Map<String, dynamic>> sanitizeEmbedsToPlaceholders(
    List<Map<String, dynamic>> ops,
  ) {
    return <Map<String, dynamic>>[
      for (final op in ops)
        if (op['insert'] is Map)
          <String, dynamic>{'insert': _embedPlaceholder(op['insert'] as Map)}
        else
          op,
    ];
  }

  /// DÉGÈLE une valeur d'embed en structures ordinaires `Map<String, dynamic>` /
  /// `List<dynamic>`.
  ///
  /// PIÈGE MESURÉ, et il est mortel : `zTableEmbedOp` gèle sa charge en
  /// profondeur (`zUnmodifiableJsonMapList`), ce qui rend des
  /// `UnmodifiableMapView<Object?, Object?>`. `Document.fromDelta`, en aval, les
  /// caste en `Map<String, dynamic>` et **lève**. Le filet AD-10 attrape alors
  /// l'exception et persiste `''` : préserver un embed gelé sans le dégeler ne
  /// dégraderait pas ce tableau, cela **viderait le document entier**.
  static Object? _thaw(Object? value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final MapEntry<Object?, Object?> e in value.entries)
          e.key.toString(): _thaw(e.value),
      };
    }
    if (value is List) {
      return <dynamic>[for (final Object? v in value) _thaw(v)];
    }
    return value;
  }

  /// Un embed est PRÉSERVÉ (non dégradé en placeholder) si son type figure dans
  /// [preserveEmbedTypes] — c'est-à-dire si l'encodeur aval sait l'exprimer
  /// nativement (CR-IFFD-24 §1 : l'image et la vidéo s'écrivent en Markdown, les
  /// remplacer par `[embed:image]` DÉTRUISAIT une donnée exprimable).
  ///
  /// N'accorder cette préservation qu'aux types réellement gérés en aval : un
  /// embed préservé SANS handler ferait throw `DeltaToMarkdown` et viderait le
  /// document ENTIER (la régression HIGH-1 que le placeholder évite).
  static bool _isPreserved(Map<Object?, dynamic> insert, Set<String> preserved) {
    if (preserved.isEmpty || insert.keys.isEmpty) return false;
    return preserved.contains(insert.keys.first.toString());
  }

  /// Placeholder textuel d'un `insert` embed opaque (perte bornée — AC9). Le
  /// **type** de l'embed (1re clé de la Map, ex. `formula`/`z-table`) est conservé
  /// pour tracer QUELLE donnée a dégradé, sans jamais casser la conversion.
  static String _embedPlaceholder(Map<Object?, dynamic> insert) {
    final kind = insert.keys.isEmpty ? '' : insert.keys.first.toString();
    return kind.isEmpty ? '[embed]' : '[embed:$kind]';
  }

  /// Convertit une [Delta] en ops neutres JSON-safe (`List<Map>`), via son JSON.
  static List<Map<String, dynamic>> deltaToNeutralOps(Delta delta) {
    return <Map<String, dynamic>>[
      for (final Object? op in delta.toJson())
        if (op is Map)
          op.map<String, dynamic>(
            (key, dynamic v) => MapEntry(key.toString(), v),
          ),
    ];
  }
}
