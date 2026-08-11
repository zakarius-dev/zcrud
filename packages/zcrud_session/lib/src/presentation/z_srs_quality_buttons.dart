/// `ZSrsQualityButtons` — rangée de boutons de notation qualité SM-2
/// (présentation pure).
///
/// Le mapping bouton → qualité vit ici : chaque bouton rend un cran de
/// l'échelle [ZQualityScale] et, au tap, invoque
/// [ZSrsQualityButtons.onQualitySelected] avec la qualité exacte du cran.
/// Aucun calcul SM-2, aucune écriture SRS : l'intervalle prévisionnel
/// éventuel vient d'un seam [ZSrsQualityButtons.previewLabelFor] injecté
/// par l'appelant (typiquement une projection pure de type `simulate`, sans
/// écriture).
///
/// Widget pur (invariants AD-2/AD-15) : `StatelessWidget`, aucun
/// gestionnaire d'état, aucun `setState`, aucun `ChangeNotifier` détenu.
/// Thème/labels/couleurs injectés (invariants AD-6/AD-13) : couleur via
/// `ZColorKeyResolver`/`ZcrudTheme` (repli `Theme.of`), label via l10n
/// `zcrud_core` (`label(context, key)`), jamais de
/// `Colors.*`/`Color(0x…)`/chaîne utilisateur en dur. Directionnel,
/// `Semantics` explicites, cibles tap ≥ 48 dp.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Échelle de qualité dérivée du domaine (value-object pur).
///
/// Les bornes sont possédées par `ZSrsConfig` (`minQuality` / `maxQuality`) ;
/// cette classe en dérive via [ZQualityScale.fromConfig], unique voie de
/// construction publique. Aucune borne n'est redéclarée ici : une seconde
/// source d'échelle divergerait silencieusement du domaine (l'UI
/// afficherait des crans que le scheduler ne reconnaîtrait pas).
///
/// Produit la liste ordonnée croissante des qualités ([qualities]). Le
/// mapping cran → qualité de [ZSrsQualityButtons] parcourt cette liste :
/// l'indice visuel `i` rend la qualité `qualities[i]` (jamais une constante
/// en dur).
@immutable
class ZQualityScale {
  /// Dérive l'échelle des bornes possédées par le domaine.
  ///
  /// Unique voie de construction publique : lit `config.minQuality` /
  /// `config.maxQuality`. Une application qui tronque l'échelle le fait une
  /// seule fois, dans sa `ZSrsConfig` — l'UI suit par construction.
  ///
  /// Non-`const` par nécessité du langage, pas par choix : un constructeur
  /// `const` ne peut pas lire un champ d'instance de son paramètre
  /// (`config.minQuality` n'est pas une expression constante), et
  /// l'alternative — recopier des bornes en défauts littéraux — serait
  /// précisément la seconde source d'échelle à éviter. La dérivation prime
  /// donc sur la constance : le value-object reste `@immutable`, trivial à
  /// construire, et l'échelle demeure unique.
  ZQualityScale.fromConfig(ZSrsConfig config)
      : min = config.minQuality,
        max = config.maxQuality;

  /// Borne basse de l'échelle — dérivée de `ZSrsConfig.minQuality`.
  final int min;

  /// Borne haute de l'échelle — dérivée de `ZSrsConfig.maxQuality`.
  final int max;

  /// Liste ordonnée croissante des qualités de l'échelle (`[min..max]`).
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

/// Résout la clé de libellé l10n d'un cran de qualité (seam injecté).
///
/// Retourne une clé (jamais un libellé utilisateur littéral) résolue par
/// `label(context, key)` côté widget. Défaut : [zDefaultQualityLabelKey].
typedef ZQualityLabelKeyResolver = String Function(int quality);

/// Résout la clé de couleur (`colorKey`) d'un cran de qualité (seam injecté).
///
/// Retourne une clé neutre résolue par `zResolveColorKeyOrSlot` (jamais un
/// `Color` en dur). Défaut : [ZSrsQualityButtons] dérive réussite/lapse
/// depuis `passThreshold` injecté (`quality >= passThreshold`).
typedef ZQualityColorKeyResolver = String Function(int quality);

/// Affordance d'emphase d'un cran de qualité — injectée par l'appelant.
///
/// Cette classe ne porte aucune couleur, seulement des dimensions (opacité,
/// épaisseur de bord) appliquées à la couleur déjà résolue par les seams
/// (`colorKeyFor`/`ZColorKeyResolver`). Elle permet à une application de
/// peindre chaque cran en fond teinté avec un bord, et d'exprimer un cran
/// mis en avant en accentuant ces deux dimensions, sans que ce widget code
/// une couleur en dur.
///
/// Défaut = [none] = rendu historique strictement inchangé (fond plein,
/// zéro bord) : aucun appelant existant ne change de rendu.
///
/// Le canal couleur n'est jamais seul (invariant AD-13) : l'emphase du cran
/// sélectionné reste portée, indépendamment de cette classe, par
/// `Semantics(selected:)`, l'annonce en toutes lettres et l'icône de coche.
/// Cette affordance s'ajoute à ces canaux, elle ne les remplace pas.
@immutable
class ZSrsQualityEmphasis {
  /// Construit une affordance. Tous les paramètres sont des dimensions.
  ///
  /// - [fillOpacity] : opacité du fond d'un cran ordinaire — `null` : couleur
  ///   inchangée (fond plein, comportement historique) ;
  /// - [selectedFillOpacity] : opacité du fond du cran sélectionné — `null` :
  ///   retombe sur [fillOpacity] ;
  /// - [borderWidth] / [selectedBorderWidth] : épaisseur du bord (`<= 0` :
  ///   aucun bord, comportement historique).
  const ZSrsQualityEmphasis({
    this.fillOpacity,
    this.selectedFillOpacity,
    this.borderWidth = 0,
    this.selectedBorderWidth = 0,
  });

  /// Affordance neutre : rendu historique exact (fond plein, aucun bord).
  static const ZSrsQualityEmphasis none = ZSrsQualityEmphasis();

  /// Opacité du fond d'un cran ordinaire (`null` : couleur inchangée).
  final double? fillOpacity;

  /// Opacité du fond du cran sélectionné (`null` : retombe sur [fillOpacity]).
  final double? selectedFillOpacity;

  /// Épaisseur du bord d'un cran ordinaire (`<= 0` : aucun bord).
  final double borderWidth;

  /// Épaisseur du bord du cran sélectionné (`<= 0` : aucun bord).
  final double selectedBorderWidth;

  /// Opacité résolue pour l'état [selected], ou `null` (couleur inchangée).
  ///
  /// Défensif (invariant AD-10) : une valeur non finie ou hors `[0, 1]` est
  /// bornée, jamais propagée telle quelle (`Color.withValues` asserte sur
  /// `0..1`).
  double? opacityFor({required bool selected}) {
    final raw = selected ? (selectedFillOpacity ?? fillOpacity) : fillOpacity;
    if (raw == null || !raw.isFinite) return null;
    return raw.clamp(0.0, 1.0).toDouble();
  }

  /// Épaisseur résolue du bord pour l'état [selected] (`0` : aucun bord).
  ///
  /// Défensif (invariant AD-10) : une valeur négative ou non finie vaut `0`.
  double borderWidthFor({required bool selected}) {
    final raw = selected ? selectedBorderWidth : borderWidth;
    if (!raw.isFinite || raw <= 0) return 0;
    return raw;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSrsQualityEmphasis &&
          fillOpacity == other.fillOpacity &&
          selectedFillOpacity == other.selectedFillOpacity &&
          borderWidth == other.borderWidth &&
          selectedBorderWidth == other.selectedBorderWidth;

  @override
  int get hashCode => Object.hash(
        fillOpacity,
        selectedFillOpacity,
        borderWidth,
        selectedBorderWidth,
      );
}

/// Clé l10n par défaut d'un cran de qualité (`zcrud.srs.quality.<q>`).
///
/// Résolue par `label(context, key, fallback: '<q>')` : à défaut de traduction,
/// le cran affiche son numéro de qualité — **jamais** un libellé en dur.
String zDefaultQualityLabelKey(int quality) => 'zcrud.srs.quality.$quality';

/// Boutons de notation qualité SM-2 (présentation pure).
class ZSrsQualityButtons extends StatelessWidget {
  /// Construit la rangée de boutons.
  ///
  /// - [scale] : échelle de qualité (mapping cran → qualité) ;
  /// - [onQualitySelected] : callback invoqué avec la qualité exacte du cran
  ///   tapé (voie de notation, découplée du moteur) ;
  /// - [passThreshold] : frontière réussite/lapse injectée (`ZSrsConfig`,
  ///   jamais un littéral en dur) ;
  /// - [previewLabelFor] : seam d'intervalle prévisionnel (typiquement une
  ///   projection pure du planificateur) ; `null` : aucun aperçu affiché ;
  /// - [labelKeyFor]/[colorKeyFor] : seams de libellé/couleur (défauts injectés) ;
  /// - [selectedQuality] : cran pré-sélectionné, ou `null`.
  const ZSrsQualityButtons({
    required this.scale,
    required this.onQualitySelected,
    required this.passThreshold,
    this.previewLabelFor,
    this.labelKeyFor = zDefaultQualityLabelKey,
    this.colorKeyFor,
    this.selectedQuality,
    this.emphasis = ZSrsQualityEmphasis.none,
    super.key,
  });

  /// Échelle de qualité (mapping cran→qualité, ordre croissant).
  final ZQualityScale scale;

  /// Callback de notation : reçoit la qualité exacte du cran tapé.
  final ValueChanged<int> onQualitySelected;

  /// Frontière réussite/lapse injectée (`quality >= passThreshold`).
  final int passThreshold;

  /// Seam d'intervalle prévisionnel, ou `null`.
  final String Function(int quality)? previewLabelFor;

  /// Seam de clé de libellé l10n (défaut [zDefaultQualityLabelKey]).
  final ZQualityLabelKeyResolver labelKeyFor;

  /// Seam de clé de couleur (défaut : réussite/lapse via [passThreshold]).
  final ZQualityColorKeyResolver? colorKeyFor;

  /// Cran pré-sélectionné, ou `null`.
  ///
  /// Retouche additive : le défaut `null` rend le comportement historique
  /// strictement inchangé (aucun cran marqué) — zéro régression pour les
  /// appelants existants.
  ///
  /// Pré-sélectionner n'est pas noter : un port d'évaluation suggère une
  /// qualité, la rangée la montre ; seul le tap de l'utilisateur
  /// ([onQualitySelected]) vaut notation. [onQualitySelected] reste l'unique
  /// voie de notation, et cette pré-sélection n'écrit rien : l'écriture SRS
  /// passe exclusivement par le seam `ZSessionReviewer` du moteur.
  ///
  /// Canal non-coloré obligatoire (invariant AD-13) : la sélection est
  /// portée par `Semantics(selected: true)` et une affordance thématisée —
  /// jamais par la seule couleur. Un cran hors échelle est simplement
  /// ignoré (invariant AD-10).
  final int? selectedQuality;

  /// Affordance d'emphase injectée — défaut [ZSrsQualityEmphasis.none],
  /// rendu historique strictement inchangé.
  final ZSrsQualityEmphasis emphasis;

  /// Préfixe de [ValueKey] d'un bouton de cran, pour la testabilité.
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
            // Pré-sélection advisory. `null` : aucun cran marqué
            // (comportement historique strictement inchangé).
            selected: selectedQuality == quality,
            emphasis: emphasis,
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
    required this.selected,
    required this.emphasis,
    required this.previewLabel,
    required this.onTap,
    super.key,
  });

  final int quality;
  final String labelKey;
  final String colorKey;
  final bool passed;

  /// Cran pré-sélectionné — signalé par un canal non-coloré.
  final bool selected;

  /// Affordance d'emphase injectée — dimensions seules, aucune couleur.
  final ZSrsQualityEmphasis emphasis;
  final String? previewLabel;
  final VoidCallback onTap;

  /// Cible tap minimale (dp), invariant AD-13.
  static const double minTarget = 48;

  /// Clé l10n de l'état réussite d'un cran (`Semantics.value`).
  ///
  /// C'est précisément le canal non-visuel qui doit rester lisible dans la
  /// locale de l'utilisateur, au même titre que le libellé visible du cran.
  static const String passedLabelKey = 'zcrud.srs.quality.passed';

  /// Clé l10n de l'état lapse d'un cran (`Semantics.value`).
  static const String lapsedLabelKey = 'zcrud.srs.quality.lapsed';

  /// Clé l10n de l'état pré-sélectionné, annoncé en plus de
  /// `Semantics(selected: true)`.
  static const String selectedLabelKey = 'zcrud.srs.quality.selected';

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, colorKey, slotIndex: quality);
    // Dimensions d'emphase résolues (déjà bornées, invariant AD-10).
    final fillOpacity = emphasis.opacityFor(selected: selected);
    final borderWidth = emphasis.borderWidthFor(selected: selected);
    final text = label(context, labelKey, fallback: '$quality');
    // Couleur jamais seul canal (invariant AD-13) : le texte du cran est
    // toujours présent, et l'état réussite/lapse est aussi porté par le
    // `Semantics.value`.
    final preview = previewLabel;
    // État réussite/lapse localisé ; le `fallback` préserve un texte lisible
    // même sans table de traduction fournie par l'hôte.
    final passedText = passed
        ? label(context, passedLabelKey, fallback: 'ok')
        : label(context, lapsedLabelKey, fallback: 'lapse');
    final semanticsValue = <String>[
      passedText,
      // La pré-sélection est annoncée en toutes lettres en plus du flag
      // `selected:` : les lecteurs d'écran ne l'exposent pas tous.
      if (selected) label(context, selectedLabelKey, fallback: 'sélectionné'),
      if (preview != null && preview.isNotEmpty) preview,
    ].join(' · ');

    return Semantics(
      button: true,
      // Premier canal non-coloré : le flag d'accessibilité natif.
      selected: selected,
      label: text,
      value: semanticsValue,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: minTarget,
          minHeight: minTarget,
        ),
        child: Material(
          // L'opacité vient de l'affordance injectée ; `null` (défaut) donne
          // la couleur résolue telle quelle (aucun `withValues`, donc aucune
          // dérive de rendu pour l'existant).
          color: fillOpacity == null
              ? pair.color
              : pair.color.withValues(alpha: fillOpacity),
          // `shape` remplace `borderRadius` (Material interdit les deux) :
          // même rayon, et un bord dont l'épaisseur est injectée.
          // `borderWidth == 0` donne `BorderSide.none`, le rendu historique.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(theme.radiusM),
            side: borderWidth <= 0
                ? BorderSide.none
                : BorderSide(color: pair.color, width: borderWidth),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.all(theme.radiusM),
            child: Padding(
              padding: theme.fieldPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Second canal non-coloré : une forme (coche), lisible sans
                  // percevoir la couleur (invariant AD-13). Le cran
                  // pré-sélectionné reste identifiable en niveaux de gris
                  // comme en daltonisme.
                  if (selected) ...<Widget>[
                    Icon(Icons.check, size: theme.gapL, color: pair.onColor),
                    SizedBox(height: theme.gapS),
                  ],
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
                      // La taille vient du thème plutôt que d'un littéral en
                      // dur, pour respecter le `textScaler` et l'échelle
                      // typographique de l'application (repli : couleur
                      // seule, jamais une taille inventée).
                      style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: pair.onColor) ??
                          TextStyle(color: pair.onColor),
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
