/// Contenu VISUEL d'un item de navigation de sous-dossier, partagé par TOUTES
/// les surfaces étroites (CR-IFFD-40).
///
/// **Pourquoi une fabrique unique** : le sélecteur en puces
/// (`ZSubfolderCompactSelector`) et la barre de sélection
/// (`ZSubfolderSelectorBar`) doivent honorer le MÊME
/// [ZSubfolderNavSpec.itemBuilder] et, à défaut, rendre le MÊME chrome neutre
/// (pastille d'accent + libellé + compteur). Dupliquer cette logique les ferait
/// diverger en silence — exactement l'écart de capacités que la parité R-SUF2
/// interdit, et que ce dépôt combat sous le nom de « seconde source ».
///
/// C'est aussi la fabrique remise à une **coquille d'hôte** via
/// `ZSubfolderNavRenderRequest.itemContentBuilder` : une surface tierce ne peut
/// donc PAS perdre le seam d'item — elle ne peut que le rappeler.
///
/// Interne au package (pas ré-exporté par le barrel).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

import 'z_subfolder_item_chrome.dart';
import 'z_subfolder_nav_spec.dart';
import 'z_subfolder_ref.dart';

/// Construit le contenu d'un item : [ZSubfolderNavSpec.itemBuilder] injecté
/// s'il existe, sinon le chrome neutre par défaut.
///
/// [refOrNull] `null` ⇒ item racine : le builder de l'hôte reçoit alors la MÊME
/// sentinelle que partout ailleurs (`ZSubfolderRef(id: '', label: label)`) —
/// aucune divergence de contrat entre les surfaces.
Widget zBuildSubfolderItemContent(
  BuildContext context, {
  required ZSubfolderNavSpec spec,
  required ZSubfolderRef? refOrNull,
  required String label,
  required bool selected,
}) {
  final Widget? custom = spec.itemBuilder?.call(
    context,
    refOrNull ?? ZSubfolderRef(id: '', label: label),
    selected,
  );
  if (custom != null) return custom;
  return zBuildSubfolderDefaultItemContent(context, refOrNull, label);
}

/// Chrome neutre par défaut : pastille d'accent (si `colorKey`) + libellé +
/// badge de compteur (si `count`) — MÊMES informations que la rangée de la
/// sidebar (parité R-SUF2). Aucune couleur ni libellé en dur (FR-26).
///
/// 🔴 **Fonction (et non widget)** : le sélecteur en puces rendait déjà ce `Row`
/// SANS élément intermédiaire. En faire une classe insérerait un élément dans
/// l'arbre du mode `compact`, dont CR-IFFD-40 promet le rendu **strictement
/// inchangé**.
Widget zBuildSubfolderDefaultItemContent(
  BuildContext context,
  ZSubfolderRef? ref,
  String label,
) {
  final ZcrudTheme theme = ZcrudTheme.of(context);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      if (ref?.colorKey != null) ...<Widget>[
        ZSubfolderAccentPastille(colorKey: ref!.colorKey!),
        SizedBox(width: theme.gapS),
      ],
      Text(label, textAlign: TextAlign.start),
      if (ref?.count != null) ...<Widget>[
        SizedBox(width: theme.gapS),
        ZSubfolderCountPill(count: ref!.count!),
      ],
    ],
  );
}
