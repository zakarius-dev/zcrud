/// `ZSrsQualityButtons` — rangée de boutons de **notation qualité SM-2**
/// (présentation PURE, ES-4.5, AC1).
///
/// Le **mapping bouton→qualité vit ICI** (ES-4.1 D6) : chaque bouton rend un
/// cran de l'échelle [ZQualityScale] et, au tap, invoque
/// [ZSrsQualityButtons.onQualitySelected] avec la **qualité EXACTE du cran**.
/// Aucun calcul SM-2, aucune écriture SRS : l'intervalle prévisionnel éventuel
/// vient d'un **seam** [ZSrsQualityButtons.previewLabelFor] injecté par
/// l'appelant (= `ZSm2Scheduler.simulate` en prod — projection PURE, AD-23).
///
/// **Widget PUR** (AD-2/AD-15) : `StatelessWidget`, AUCUN gestionnaire d'état,
/// AUCUN `setState`, AUCUN `ChangeNotifier` détenu. Thème/labels/couleurs
/// INJECTÉS (FR-26/AD-6/AD-13) : couleur via `ZColorKeyResolver`/`ZcrudTheme`
/// (repli `Theme.of`), label via l10n `zcrud_core` (`label(context, key)`),
/// jamais de `Colors.*`/`Color(0x…)`/string utilisateur en dur. Directionnel
/// (AD-13), `Semantics` explicites, cibles tap ≥ 48 dp.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Échelle de qualité configurable (value-object PUR).
///
/// `min ∈ {0, 1}` (échelle SM-2 pleine `0..5` ou tronquée `1..5`), `max = 5`.
/// Produit la **liste ordonnée croissante** des qualités ([qualities]). Le
/// mapping cran→qualité de [ZSrsQualityButtons] parcourt cette liste : l'indice
/// visuel `i` rend la qualité `qualities[i]` (jamais une constante en dur).
@immutable
class ZQualityScale {
  /// Construit une échelle. Défaut : pleine `0..5` (SuperMemo-2).
  const ZQualityScale({this.min = 0, this.max = 5})
      : assert(min == 0 || min == 1, 'min doit valoir 0 ou 1 (échelle SM-2)'),
        assert(max == 5, 'max doit valoir 5 (échelle SM-2)');

  /// Borne basse (`0` = échelle pleine, `1` = sans « blackout total »).
  final int min;

  /// Borne haute (toujours `5` — plafond SuperMemo-2).
  final int max;

  /// Liste **ordonnée croissante** des qualités de l'échelle (`[min..max]`).
  List<int> get qualities =>
      <int>[for (var q = min; q <= max; q++) q];

  /// Vrai si [quality] appartient à l'échelle (`min <= quality <= max`).
  bool contains(int quality) => quality >= min && quality <= max;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZQualityScale && min == other.min && max == other.max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'ZQualityScale($min..$max)';
}

/// Résout la **clé de libellé** l10n d'un cran de qualité (seam injecté).
///
/// Retourne une **clé** (jamais un libellé utilisateur littéral) résolue par
/// `label(context, key)` côté widget. Défaut : [zDefaultQualityLabelKey].
typedef ZQualityLabelKeyResolver = String Function(int quality);

/// Résout la **clé de couleur** (`colorKey`) d'un cran de qualité (seam injecté).
///
/// Retourne une clé neutre résolue par `zResolveColorKeyOrSlot` (jamais un
/// `Color` en dur). Défaut : [ZSrsQualityButtons] dérive réussite/lapse depuis
/// `passThreshold` injecté (`quality >= passThreshold`).
typedef ZQualityColorKeyResolver = String Function(int quality);

/// Clé l10n par défaut d'un cran de qualité (`zcrud.srs.quality.<q>`).
///
/// Résolue par `label(context, key, fallback: '<q>')` : à défaut de traduction,
/// le cran affiche son numéro de qualité — **jamais** un libellé en dur.
String zDefaultQualityLabelKey(int quality) => 'zcrud.srs.quality.$quality';

/// Boutons de notation qualité SM-2 (présentation PURE).
class ZSrsQualityButtons extends StatelessWidget {
  /// Construit la rangée de boutons.
  ///
  /// - [scale] : échelle de qualité (mapping cran→qualité) ;
  /// - [onQualitySelected] : callback invoqué avec la **qualité exacte** du cran
  ///   tapé (voie de notation, découplée du moteur — AD-2/D8) ;
  /// - [passThreshold] : frontière réussite/lapse INJECTÉE (`ZSrsConfig`,
  ///   jamais `3` en dur — D5/AC6) ;
  /// - [previewLabelFor] : seam d'intervalle prévisionnel (= `simulate` en prod ;
  ///   `null` → aucun aperçu affiché — AC1) ;
  /// - [labelKeyFor]/[colorKeyFor] : seams de libellé/couleur (défauts injectés).
  const ZSrsQualityButtons({
    required this.scale,
    required this.onQualitySelected,
    required this.passThreshold,
    this.previewLabelFor,
    this.labelKeyFor = zDefaultQualityLabelKey,
    this.colorKeyFor,
    super.key,
  });

  /// Échelle de qualité (mapping cran→qualité, ordre croissant).
  final ZQualityScale scale;

  /// Callback de notation : reçoit la qualité EXACTE du cran tapé.
  final ValueChanged<int> onQualitySelected;

  /// Frontière réussite/lapse INJECTÉE (`quality >= passThreshold`).
  final int passThreshold;

  /// Seam d'intervalle prévisionnel (= `simulate` en prod), ou `null`.
  final String Function(int quality)? previewLabelFor;

  /// Seam de clé de libellé l10n (défaut [zDefaultQualityLabelKey]).
  final ZQualityLabelKeyResolver labelKeyFor;

  /// Seam de clé de couleur (défaut : réussite/lapse via [passThreshold]).
  final ZQualityColorKeyResolver? colorKeyFor;

  /// Préfixe de [ValueKey] d'un bouton de cran (testabilité, AC1).
  static const String buttonKeyPrefix = 'zSrsQuality_';

  /// Clé de couleur par défaut d'un cran : réussite vs lapse via [passThreshold].
  String _colorKeyOf(int quality) {
    final resolver = colorKeyFor;
    if (resolver != null) return resolver(quality);
    // Réussite = rôle `primary` ; lapse = rôle `error` (rôles Material 3
    // résolus par le repli du cœur — jamais un `Color` en dur).
    return quality >= passThreshold ? 'primary' : 'error';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Wrap(
      spacing: theme.gapM,
      runSpacing: theme.gapM,
      alignment: WrapAlignment.start,
      children: <Widget>[
        for (final quality in scale.qualities)
          _QualityButton(
            key: ValueKey<String>('$buttonKeyPrefix$quality'),
            quality: quality,
            labelKey: labelKeyFor(quality),
            colorKey: _colorKeyOf(quality),
            passed: quality >= passThreshold,
            previewLabel: previewLabelFor?.call(quality),
            onTap: () => onQualitySelected(quality),
          ),
      ],
    );
  }
}

/// Bouton d'un unique cran de qualité (privé). Cible ≥ 48 dp, `Semantics`,
/// couleur/label injectés, directionnel.
class _QualityButton extends StatelessWidget {
  const _QualityButton({
    required this.quality,
    required this.labelKey,
    required this.colorKey,
    required this.passed,
    required this.previewLabel,
    required this.onTap,
    super.key,
  });

  final int quality;
  final String labelKey;
  final String colorKey;
  final bool passed;
  final String? previewLabel;
  final VoidCallback onTap;

  /// Cible tap minimale Material/AD-13 (dp).
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, colorKey, slotIndex: quality);
    final text = label(context, labelKey, fallback: '$quality');
    // Couleur JAMAIS seul canal (AD-13) : le texte du cran est toujours présent,
    // et l'état réussite/lapse est aussi porté par le `Semantics.value`.
    final preview = previewLabel;
    final semanticsValue = <String>[
      passed ? 'ok' : 'lapse',
      if (preview != null && preview.isNotEmpty) preview,
    ].join(' · ');

    return Semantics(
      button: true,
      label: text,
      value: semanticsValue,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: minTarget,
          minHeight: minTarget,
        ),
        child: Material(
          color: pair.color,
          borderRadius: BorderRadius.all(theme.radiusM),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.all(theme.radiusM),
            child: Padding(
              padding: theme.fieldPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: pair.onColor),
                  ),
                  if (preview != null && preview.isNotEmpty) ...<Widget>[
                    SizedBox(height: theme.gapS),
                    Text(
                      preview,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: pair.onColor, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
