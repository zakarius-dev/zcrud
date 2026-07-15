/// `ZSessionQualityBreakdown` — répartition fidèle des **qualités d'une session**
/// (présentation PURE, ES-4.5, AC2).
///
/// Rend le `byQuality` d'un `ZStudySessionResult` INJECTÉ : **un et un seul
/// segment par clé présente**, valeur = compte EXACT, **ordonné par qualité
/// croissante** (ordre de l'échelle, jamais l'ordre d'insertion de la map).
/// AUCUNE catégorie omise, AUCUNE inversée (AC2 discriminant). Une clé HORS
/// échelle (corpus corrompu, ex. `"9"`) est **rendue à part / signalée**, jamais
/// silencieusement fusionnée dans un cran connu (R6 — jamais de dégradation
/// silencieuse).
///
/// **Widget PUR** (AD-2/AD-15) : `StatelessWidget`, aucun gestionnaire d'état.
/// Couleurs via `ZColorKeyResolver` (repli `Theme.of`), labels via l10n
/// `zcrud_core`, **compte affiché en texte** (couleur jamais seul canal, AD-13),
/// directionnel, `Semantics` par segment. Jamais `ListView(children: [...])`.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_srs_quality_buttons.dart';

/// Répartition des qualités d'une session (présentation PURE).
class ZSessionQualityBreakdown extends StatelessWidget {
  /// Construit le breakdown.
  ///
  /// - [byQuality] : répartition INJECTÉE (typiquement `result.byQuality`) —
  ///   clés qualité opaques `"0".."5"`, valeur = compte (AC7 : consommé tel
  ///   quel, aucun recomptage) ;
  /// - [scale] : échelle de référence (ordre + appartenance) ;
  /// - [passThreshold] : frontière réussite/lapse INJECTÉE (D5/AC6) ;
  /// - [labelKeyFor]/[colorKeyFor] : seams de libellé/couleur (défauts injectés).
  const ZSessionQualityBreakdown({
    required this.byQuality,
    required this.scale,
    required this.passThreshold,
    this.labelKeyFor = zDefaultQualityLabelKey,
    this.colorKeyFor,
    super.key,
  });

  /// Répartition `qualité "0".."5" → compte` INJECTÉE (consommée verbatim).
  final Map<String, int> byQuality;

  /// Échelle de référence (ordre croissant + appartenance).
  final ZQualityScale scale;

  /// Frontière réussite/lapse INJECTÉE (`quality >= passThreshold`).
  final int passThreshold;

  /// Seam de clé de libellé l10n (défaut [zDefaultQualityLabelKey]).
  final ZQualityLabelKeyResolver labelKeyFor;

  /// Seam de clé de couleur (défaut : réussite/lapse via [passThreshold]).
  final ZQualityColorKeyResolver? colorKeyFor;

  /// Préfixe de [ValueKey] d'un segment **dans** l'échelle (testabilité, AC2).
  static const String segmentKeyPrefix = 'zBreakdownSegment_';

  /// Préfixe de [ValueKey] d'un segment **hors** échelle (R6, AC2).
  static const String unknownKeyPrefix = 'zBreakdownUnknown_';

  String _colorKeyOf(int quality) {
    final resolver = colorKeyFor;
    if (resolver != null) return resolver(quality);
    return quality >= passThreshold ? 'primary' : 'error';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);

    // Segments DANS l'échelle : parcours de l'échelle en ordre CROISSANT, ne
    // gardant que les clés réellement présentes (un segment par clé présente).
    final inScale = <Widget>[
      for (final quality in scale.qualities)
        if (byQuality.containsKey('$quality'))
          _Segment(
            key: ValueKey<String>('$segmentKeyPrefix$quality'),
            colorKey: _colorKeyOf(quality),
            slotIndex: quality,
            labelText: label(context, labelKeyFor(quality),
                fallback: '$quality'),
            count: byQuality['$quality']!,
            unknown: false,
          ),
    ];

    // Clés HORS échelle : jamais fusionnées — rendues À PART, signalées (R6).
    // Tri déterministe par clé pour un rendu stable.
    final unknownKeys = byQuality.keys
        .where((k) => !_isInScale(k))
        .toList()
      ..sort();
    final outOfScale = <Widget>[
      for (final rawKey in unknownKeys)
        _Segment(
          key: ValueKey<String>('$unknownKeyPrefix$rawKey'),
          colorKey: 'neutral',
          slotIndex: rawKey.hashCode,
          labelText: label(context, 'zcrud.srs.quality.unknown',
              fallback: '? ($rawKey)'),
          count: byQuality[rawKey]!,
          unknown: true,
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: theme.gapM,
          runSpacing: theme.gapS,
          children: inScale,
        ),
        if (outOfScale.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.gapM),
          Wrap(
            spacing: theme.gapM,
            runSpacing: theme.gapS,
            children: outOfScale,
          ),
        ],
      ],
    );
  }

  /// Vrai si [rawKey] est la représentation CANONIQUE d'un cran de l'échelle.
  ///
  /// Comparaison de STRING EXACTE (jamais `int.tryParse`) : une clé « connue »
  /// est *exactement* `'$p'` pour un `p` de l'échelle. Ainsi une clé
  /// non-canonique mais parsant en-échelle (`"03"`, `"+3"`, `" 3"`, `"005"`)
  /// est jugée HORS échelle ⇒ rendue dans la section hors-échelle (signalée),
  /// JAMAIS droppée silencieusement (R6/D3). Le rendu in-scale teste lui aussi
  /// `byQuality.containsKey('$quality')` (string exacte) : les deux faces
  /// partagent le MÊME critère canonique, donc aucune clé ne peut tomber entre
  /// les deux sections.
  bool _isInScale(String rawKey) {
    for (final quality in scale.qualities) {
      if (rawKey == '$quality') return true;
    }
    return false;
  }
}

/// Un segment unique de répartition (privé). Couleur injectée + compte en texte
/// (couleur jamais seul canal) + `Semantics` label/valeur.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.colorKey,
    required this.slotIndex,
    required this.labelText,
    required this.count,
    required this.unknown,
    super.key,
  });

  final String colorKey;
  final int slotIndex;
  final String labelText;
  final int count;
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, colorKey, slotIndex: slotIndex);
    // Le compte est TOUJOURS rendu en texte (couleur jamais seul canal, AD-13)
    // et exposé dans `Semantics.value`.
    return Semantics(
      label: unknown ? 'hors échelle: $labelText' : labelText,
      value: '$count',
      child: Container(
        padding: theme.fieldPadding,
        decoration: BoxDecoration(
          color: pair.color,
          borderRadius: BorderRadius.all(theme.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(labelText, style: TextStyle(color: pair.onColor)),
            SizedBox(width: theme.gapS),
            Text(
              '$count',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: pair.onColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
