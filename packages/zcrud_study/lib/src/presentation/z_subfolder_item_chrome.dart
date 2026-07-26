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
    final ZColorPair pair =
        zResolveColorKeyOrSlot(context, colorKey, slotIndex: 0);
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
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.gapS,
        vertical: theme.gapS / 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.all(theme.radiusM),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.start,
        style: TextStyle(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
