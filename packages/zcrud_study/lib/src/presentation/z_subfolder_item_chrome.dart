/// Chrome VISUEL PARTAGÉ des items de sous-dossier (SUF-3) — pastille d'accent
/// et badge de compteur.
///
/// **Pourquoi un fichier dédié** : ces deux primitives sont rendues par la
/// sidebar **et** par le sélecteur compact. Les dupliquer ferait diverger en
/// silence les deux côtés du seuil `mediumMinWidth` (600 dp) — exactement l'écart
/// de capacités que la couture SUF-2 ↔ SUF-3 (R-SUF2) doit interdire : une même
/// `ZSubfolderNavSpec` doit rendre les MÊMES informations (`colorKey`, `count`)
/// quelle que soit la taille d'écran.
///
/// Interne au package (pas ré-exporté par le barrel `zcrud_study.dart`).
///
/// **AD-13/FR-26** : aucune couleur ni libellé en dur — accent DÉRIVÉ de la
/// `colorKey` opaque via `zResolveColorKeyOrSlot`, chrome depuis `ColorScheme` /
/// `ZcrudTheme`. Le compteur est une **interpolation d'entier**, jamais un
/// libellé traduisible.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;

/// Diamètre de la pastille d'accent d'un item (dimension de layout — parité
/// `ZFolderCard`).
const double kZSubfolderPastilleSize = 12.0;

/// Pastille d'accent d'un item — couleur DÉRIVÉE de `colorKey` (jamais en dur).
class ZSubfolderAccentPastille extends StatelessWidget {
  /// Construit la pastille pour la clé de couleur **opaque** [colorKey].
  const ZSubfolderAccentPastille({required this.colorKey, super.key});

  /// Clé de couleur opaque résolue par le cœur (seam total — AD-10).
  final String colorKey;

  @override
  Widget build(BuildContext context) {
    final ZColorPair pair = zResolveColorKeyOrSlot(
      context,
      colorKey,
      slotIndex: 0,
    );
    return Container(
      width: kZSubfolderPastilleSize,
      height: kZSubfolderPastilleSize,
      decoration: BoxDecoration(color: pair.color, shape: BoxShape.circle),
    );
  }
}

/// Petit badge de compteur (chrome thémé, aucune couleur en dur).
class ZSubfolderCountPill extends StatelessWidget {
  /// Construit le badge du nombre [count].
  const ZSubfolderCountPill({required this.count, super.key});

  /// Nombre affiché (interpolation d'entier — jamais un libellé traduisible).
  final int count;

  @override
  Widget build(BuildContext context) => _CountPillChrome(
    child: Text(
      '$count',
      textAlign: TextAlign.start,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    ),
  );
}

/// Données de présentation immuables d'un [ZCountBadge].
class ZCountBadgeSpec {
  /// Décrit un badge de compte injecté dans une [ZCountBadgeRow].
  const ZCountBadgeSpec({
    required this.count,
    required this.icon,
    required this.semanticLabel,
    this.key,
  });

  /// Clé optionnelle du badge rendu.
  final Key? key;

  /// Compte à afficher. Les valeurs non positives sont absentes de l'arbre.
  final int count;

  /// Icône fournie par l'hôte.
  final Widget icon;

  /// Annonce accessible unique du badge.
  final String semanticLabel;
}

/// Badge de compte accessible, construit uniquement pour un compte positif.
class ZCountBadge extends StatelessWidget {
  /// Construit un badge de compte à partir de données de présentation.
  /// 🔴 `count` doit être **strictement positif** (CR epic VIS, MEDIUM-3).
  /// [ZCountBadgeRow] filtre déjà les comptes nuls — un badge à zéro est
  /// ABSENT DE L'ARBRE, il n'est pas masqué. Mais rien n'empêchait d'instancier
  /// `ZCountBadge` directement avec `0` ou une valeur négative, ce qui affichait
  /// « 0 » et contredisait en silence la règle que la rangée fait respecter.
  /// L'assertion place l'invariant sur le widget lui-même, où que l'hôte le
  /// construise.
  const ZCountBadge({
    required this.count,
    required this.icon,
    required this.semanticLabel,
    super.key,
  }) : assert(
         count > 0,
         'Un badge de compteur ne se rend que pour un compte > 0 : un compte '
         'nul doit être ABSENT de l\'arbre (cf. ZCountBadgeRow), jamais rendu.',
       );

  /// Compte affiché — toujours strictement positif (cf. assertion ci-dessus).
  final int count;

  /// Icône injectée.
  final Widget icon;

  /// Annonce accessible unique.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final double iconSize =
        theme.countPillIconSize ??
        IconTheme.of(context).size ??
        Theme.of(context).iconTheme.size ??
        kMinInteractiveDimension;
    final Color iconColor = Theme.of(context).colorScheme.onSecondaryContainer;

    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: kMinInteractiveDimension,
          minHeight: kMinInteractiveDimension,
        ),
        child: _CountPillChrome(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: IconTheme.merge(
                  data: IconThemeData(size: iconSize, color: iconColor),
                  child: icon,
                ),
              ),
              SizedBox(width: theme.gapS),
              Text(
                '$count',
                textAlign: TextAlign.start,
                style: TextStyle(color: iconColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rangée de badges qui retire structurellement les comptes non positifs.
class ZCountBadgeRow extends StatelessWidget {
  /// Construit une rangée de descripteurs de badges injectés.
  const ZCountBadgeRow({required this.badges, super.key});

  /// Descripteurs à rendre ; les comptes `<= 0` ne créent aucun widget badge.
  final List<ZCountBadgeSpec> badges;

  @override
  Widget build(BuildContext context) {
    final List<ZCountBadgeSpec> positiveBadges = badges
        .where((ZCountBadgeSpec badge) => badge.count > 0)
        .toList(growable: false);
    if (positiveBadges.isEmpty) return const SizedBox.shrink();

    final double gap = ZcrudTheme.of(context).gapS;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < positiveBadges.length; index++) ...<Widget>[
          if (index > 0) SizedBox(width: gap),
          ZCountBadge(
            key: positiveBadges[index].key,
            count: positiveBadges[index].count,
            icon: positiveBadges[index].icon,
            semanticLabel: positiveBadges[index].semanticLabel,
          ),
        ],
      ],
    );
  }
}

/// Chrome unique partagé par les pills de sous-dossier et les badges de compte.
class _CountPillChrome extends StatelessWidget {
  const _CountPillChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding:
          theme.countPillPadding ??
          EdgeInsetsDirectional.symmetric(
            horizontal: theme.gapS,
            vertical: theme.gapS / 2,
          ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.all(theme.countPillRadius ?? theme.radiusM),
      ),
      child: child,
    );
  }
}
