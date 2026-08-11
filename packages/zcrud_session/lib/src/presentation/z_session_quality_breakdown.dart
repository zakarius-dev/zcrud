/// `ZSessionQualityBreakdown` — répartition fidèle des qualités d'une
/// session (présentation pure).
///
/// Rend le `byQuality` d'un `ZStudySessionResult` injecté : un et un seul
/// segment par clé présente, valeur = compte exact, ordonné par qualité
/// croissante (ordre de l'échelle, jamais l'ordre d'insertion de la map).
/// Aucune catégorie omise, aucune inversée. Une clé hors échelle (corpus
/// corrompu, par exemple `"9"`) est rendue à part et signalée, jamais
/// silencieusement fusionnée dans un cran connu.
///
/// Widget pur (invariants AD-2/AD-15) : `StatelessWidget`, aucun
/// gestionnaire d'état. Couleurs via `ZColorKeyResolver` (repli
/// `Theme.of`), labels via l10n `zcrud_core`, compte affiché en texte
/// (couleur jamais seul canal, invariant AD-13), directionnel, `Semantics`
/// par segment. Jamais `ListView(children: [...])`.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_srs_quality_buttons.dart';

/// Couverture des crans rendus par [ZSessionQualityBreakdown] — un enum
/// plutôt qu'un booléen, chaque variante étant un choix nommé explicite.
enum ZQualityBreakdownCoverage {
  /// Un segment par clé présente dans `byQuality` (comportement historique,
  /// défaut). Un cran jamais utilisé n'apparaît pas, donc la répartition
  /// change de longueur d'une session à l'autre.
  presentKeysOnly,

  /// Un segment par cran de l'échelle, y compris ceux absents de
  /// `byQuality` (rendus à `0`) — répartition de longueur stable.
  ///
  /// N'affecte que les crans de l'échelle : les clés hors échelle (corpus
  /// corrompu) restent rendues à part et signalées, jamais fusionnées ni
  /// inventées.
  wholeScale,
}

/// Répartition des qualités d'une session (présentation pure).
class ZSessionQualityBreakdown extends StatelessWidget {
  /// Construit le breakdown.
  ///
  /// - [byQuality] : répartition injectée (typiquement `result.byQuality`) —
  ///   clés qualité opaques `"0".."5"`, valeur = compte (consommé tel quel,
  ///   aucun recomptage) ;
  /// - [scale] : échelle de référence (ordre + appartenance) ;
  /// - [passThreshold] : frontière réussite/lapse injectée ;
  /// - [labelKeyFor]/[colorKeyFor] : seams de libellé/couleur (défauts injectés).
  const ZSessionQualityBreakdown({
    required this.byQuality,
    required this.scale,
    required this.passThreshold,
    this.labelKeyFor = zDefaultQualityLabelKey,
    this.colorKeyFor,
    this.coverage = ZQualityBreakdownCoverage.presentKeysOnly,
    super.key,
  });

  /// Répartition `qualité "0".."5" → compte` injectée (consommée verbatim).
  final Map<String, int> byQuality;

  /// Échelle de référence (ordre croissant + appartenance).
  final ZQualityScale scale;

  /// Frontière réussite/lapse injectée (`quality >= passThreshold`).
  final int passThreshold;

  /// Seam de clé de libellé l10n (défaut [zDefaultQualityLabelKey]).
  final ZQualityLabelKeyResolver labelKeyFor;

  /// Seam de clé de couleur (défaut : réussite/lapse via [passThreshold]).
  final ZQualityColorKeyResolver? colorKeyFor;

  /// Couverture des crans rendus — défaut historique
  /// [ZQualityBreakdownCoverage.presentKeysOnly].
  final ZQualityBreakdownCoverage coverage;

  /// Préfixe de [ValueKey] d'un segment dans l'échelle, pour la testabilité.
  static const String segmentKeyPrefix = 'zBreakdownSegment_';

  /// Préfixe de [ValueKey] d'un segment hors échelle.
  static const String unknownKeyPrefix = 'zBreakdownUnknown_';

  String _colorKeyOf(int quality) {
    final resolver = colorKeyFor;
    if (resolver != null) return resolver(quality);
    return quality >= passThreshold ? 'primary' : 'error';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);

    // Segments dans l'échelle : parcours de l'échelle en ordre croissant, ne
    // gardant que les clés réellement présentes (un segment par clé présente).
    //
    // La couverture est injectée : `presentKeysOnly` (défaut) conserve le
    // filtre historique `containsKey`, `wholeScale` rend tout cran de
    // l'échelle (absent => `0`), pour une répartition de longueur stable. Le
    // compte reste consommé verbatim (aucun recomptage).
    final wholeScale = coverage == ZQualityBreakdownCoverage.wholeScale;
    final inScale = <Widget>[
      for (final quality in scale.qualities)
        if (wholeScale || byQuality.containsKey('$quality'))
          _Segment(
            key: ValueKey<String>('$segmentKeyPrefix$quality'),
            colorKey: _colorKeyOf(quality),
            slotIndex: quality,
            labelText: label(context, labelKeyFor(quality),
                fallback: '$quality'),
            count: byQuality['$quality'] ?? 0,
            unknown: false,
          ),
    ];

    // Clés hors échelle : jamais fusionnées, rendues à part et signalées.
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

  /// Vrai si [rawKey] est la représentation canonique d'un cran de l'échelle.
  ///
  /// Comparaison de chaîne exacte (jamais `int.tryParse`) : une clé
  /// « connue » est exactement `'$p'` pour un `p` de l'échelle. Ainsi une
  /// clé non-canonique mais qui parserait dans l'échelle (`"03"`, `"+3"`,
  /// `" 3"`, `"005"`) est jugée hors échelle et rendue dans la section
  /// hors-échelle (signalée), jamais droppée silencieusement. Le rendu
  /// in-scale teste lui aussi `byQuality.containsKey('$quality')` (chaîne
  /// exacte) : les deux faces partagent le même critère canonique, donc
  /// aucune clé ne peut tomber entre les deux sections.
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
