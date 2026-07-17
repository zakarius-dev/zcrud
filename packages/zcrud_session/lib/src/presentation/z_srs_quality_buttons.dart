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
// AD-46 : les bornes d'échelle sont possédées par le domaine `ZSrsConfig`
// (`zcrud_flashcard`). Arête PRÉEXISTANTE (`zcrud_session → zcrud_flashcard`,
// déjà importée par les 3 runtimes) : la dérivation n'ajoute AUCUNE arête.
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Échelle de qualité **DÉRIVÉE** du domaine (value-object PUR).
///
/// AD-46 : les bornes sont **possédées par `ZSrsConfig`** (`minQuality` /
/// `maxQuality`) ; cette classe en **dérive** via [ZQualityScale.fromConfig],
/// **unique voie de construction publique**. Aucune borne n'est redéclarée ici :
/// une seconde source d'échelle divergerait silencieusement du domaine (l'UI
/// afficherait des crans que le scheduler ne reconnaîtrait pas). La garde de
/// source `z_quality_scale_single_source_test.dart` ROUGIT si un littéral de
/// borne réapparaît dans ce fichier.
///
/// Produit la **liste ordonnée croissante** des qualités ([qualities]). Le
/// mapping cran→qualité de [ZSrsQualityButtons] parcourt cette liste : l'indice
/// visuel `i` rend la qualité `qualities[i]` (jamais une constante en dur).
@immutable
class ZQualityScale {
  /// Dérive l'échelle des bornes **possédées par le domaine** (AD-46).
  ///
  /// Unique voie de construction publique : lit `config.minQuality` /
  /// `config.maxQuality`. Une app qui tronque l'échelle le fait **une seule
  /// fois**, dans sa `ZSrsConfig` — l'UI suit par construction.
  ///
  /// **Non-`const` par nécessité du langage**, pas par choix : un constructeur
  /// `const` ne peut pas lire un champ d'instance de son paramètre
  /// (`config.minQuality` n'est pas une expression constante), et l'alternative
  /// — recopier `0`/`5` en défauts littéraux — serait précisément la SECONDE
  /// SOURCE que l'AD-46 interdit. La dérivation prime sur la constance : le VO
  /// reste `@immutable`, trivial à construire, et l'échelle demeure UNIQUE.
  ZQualityScale.fromConfig(ZSrsConfig config)
      : min = config.minQuality,
        max = config.maxQuality;

  /// Borne basse de l'échelle — **dérivée** de `ZSrsConfig.minQuality`.
  final int min;

  /// Borne haute de l'échelle — **dérivée** de `ZSrsConfig.maxQuality`.
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
  /// - [labelKeyFor]/[colorKeyFor] : seams de libellé/couleur (défauts injectés) ;
  /// - [selectedQuality] : cran **PRÉ-SÉLECTIONNÉ** (SU-3/AC2), ou `null`.
  const ZSrsQualityButtons({
    required this.scale,
    required this.onQualitySelected,
    required this.passThreshold,
    this.previewLabelFor,
    this.labelKeyFor = zDefaultQualityLabelKey,
    this.colorKeyFor,
    this.selectedQuality,
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

  /// Cran **PRÉ-SÉLECTIONNÉ** (SU-3, AC2 — AD-35 « évaluation ADVISORY »), ou
  /// `null`.
  ///
  /// **Retouche ADDITIVE** : le défaut `null` rend le comportement historique
  /// **strictement inchangé** (aucun cran marqué) — zéro régression pour les
  /// appelants existants (`ZSessionQualityBreakdown`, runtimes ES-4).
  ///
  /// 🔒 **Pré-sélectionner n'est PAS noter** : un port d'évaluation *suggère*
  /// une qualité, la rangée la **montre** ; seul le **tap** de l'utilisateur
  /// ([onQualitySelected]) vaut notation. [onQualitySelected] reste l'**UNIQUE**
  /// voie de notation — su-3 n'en ouvre pas une seconde, et n'écrit RIEN
  /// (AD-33 : l'écriture SRS passe par le seam `ZSessionReviewer`, branché en
  /// su-4).
  ///
  /// 🔒 **Canal NON-COLORÉ obligatoire** (AD-13) : la sélection est portée par
  /// `Semantics(selected: true)` **et** une affordance thématisée — jamais par
  /// la seule couleur. Un cran hors échelle est simplement ignoré (AD-10).
  final int? selectedQuality;

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
            // SU-3/AC2 — pré-sélection ADVISORY. `null` ⇒ aucun cran marqué
            // (comportement historique STRICTEMENT inchangé).
            selected: selectedQuality == quality,
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
    required this.previewLabel,
    required this.onTap,
    super.key,
  });

  final int quality;
  final String labelKey;
  final String colorKey;
  final bool passed;

  /// Cran **PRÉ-SÉLECTIONNÉ** (SU-3/AC2) — signalé par un canal NON-COLORÉ.
  final bool selected;
  final String? previewLabel;
  final VoidCallback onTap;

  /// Cible tap minimale Material/AD-13 (dp).
  static const double minTarget = 48;

  /// Clé l10n de l'état **réussite** d'un cran (`Semantics.value`).
  ///
  /// 🔴 **Dette du ledger su-1 soldée** (`code-review-su-1.md`, LOW) : les
  /// libellés `'ok'`/`'lapse'` étaient **codés en dur** dans `Semantics.value` —
  /// un lecteur d'écran les annonçait **en anglais** quelle que soit la locale,
  /// alors même que le libellé visible du cran, lui, était traduit. AD-13 exige
  /// l'inverse : c'est **précisément** le canal non-visuel qui doit être lisible.
  static const String passedLabelKey = 'zcrud.srs.quality.passed';

  /// Clé l10n de l'état **lapse** d'un cran (`Semantics.value`).
  static const String lapsedLabelKey = 'zcrud.srs.quality.lapsed';

  /// Clé l10n de l'état **pré-sélectionné** (SU-3/AC2), annoncé en plus de
  /// `Semantics(selected: true)`.
  static const String selectedLabelKey = 'zcrud.srs.quality.selected';

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, colorKey, slotIndex: quality);
    final text = label(context, labelKey, fallback: '$quality');
    // Couleur JAMAIS seul canal (AD-13) : le texte du cran est toujours présent,
    // et l'état réussite/lapse est aussi porté par le `Semantics.value`.
    final preview = previewLabel;
    // 🔴 Dette du ledger su-1 soldée : état réussite/lapse LOCALISÉ (le
    // `fallback` préserve à l'identique l'ancien texte `'ok'`/`'lapse'` — aucune
    // régression pour une app sans table de traduction).
    final passedText = passed
        ? label(context, passedLabelKey, fallback: 'ok')
        : label(context, lapsedLabelKey, fallback: 'lapse');
    final semanticsValue = <String>[
      passedText,
      // SU-3/AC2 — la pré-sélection est annoncée EN TOUTES LETTRES en plus du
      // flag `selected:` : les lecteurs d'écran ne l'exposent pas tous.
      if (selected) label(context, selectedLabelKey, fallback: 'sélectionné'),
      if (preview != null && preview.isNotEmpty) preview,
    ].join(' · ');

    return Semantics(
      button: true,
      // SU-3/AC2 — canal NON-COLORÉ n°1 : le flag d'accessibilité natif.
      selected: selected,
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
                  // SU-3/AC2 — canal NON-COLORÉ n°2 : une FORME (coche), lisible
                  // sans percevoir la couleur (AD-13 : « jamais la seule
                  // couleur »). Le cran pré-sélectionné reste identifiable en
                  // niveaux de gris comme en daltonisme.
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
                      // 🔴 Dette du ledger su-1 soldée : `fontSize: 12` était
                      // codé en dur — il ignorait le `textScaler` du thème et
                      // l'échelle typographique de l'app. La taille vient
                      // désormais du thème (repli : couleur seule, jamais une
                      // taille inventée).
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
