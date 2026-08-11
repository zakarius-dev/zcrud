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

/// Libellé de la **ligne racine** d'une surface de LISTE (CR-IFFD-46, point 1).
///
/// **Source UNIQUE de ce repli.** Les trois surfaces de liste (feuille,
/// sidebar, rangée de puces) doivent répondre la même chose ; le déclencheur de
/// la barre, lui, doit répondre AUTRE CHOSE — il lit `allSubfoldersLabel`
/// directement et n'appelle **jamais** cette fonction. Recopier `?? ` sur
/// chaque site aurait rejoué la « seconde source » que ce fichier existe pour
/// interdire, et rien n'aurait rougi le jour où l'un des trois aurait dérivé.
String zSubfolderRootItemLabel(ZSubfolderNavSpec spec) =>
    spec.rootItemLabel ?? spec.allSubfoldersLabel;

/// Construit le contenu d'un item : [ZSubfolderNavSpec.itemBuilder] injecté
/// s'il existe, sinon le chrome neutre par défaut.
///
/// [refOrNull] `null` ⇒ item racine : le builder de l'hôte reçoit alors la MÊME
/// sentinelle que partout ailleurs (`ZSubfolderRef(id: '', label: label)`) —
/// aucune divergence de contrat entre les surfaces. Le [label] transmis est
/// celui que l'appelant a résolu : la sentinelle porte donc
/// [ZSubfolderNavSpec.rootItemLabel] dans une liste et
/// [ZSubfolderNavSpec.allSubfoldersLabel] sur le déclencheur — un `itemBuilder`
/// existant rend le bon libellé **sans être modifié**.
///
/// [rootIcon] : glyphe de tête de la ligne racine (CR-IFFD-46, point 1).
/// **Paramètre EXPLICITE et non `spec.rootItemIcon` lu ici** : `refOrNull`
/// est `null` sur la ligne racine COMME sur le déclencheur sans sélection. Le
/// lire depuis la spec l'aurait donc posé sur le déclencheur aussi — soit
/// exactement le défaut « les deux surfaces sont indiscernables » que
/// CR-IFFD-46 corrige. Ce sont les sites de LISTE qui le passent.
Widget zBuildSubfolderItemContent(
  BuildContext context, {
  required ZSubfolderNavSpec spec,
  required ZSubfolderRef? refOrNull,
  required String label,
  required bool selected,
  IconData? rootIcon,
}) {
  final Widget? custom = spec.itemBuilder?.call(
    context,
    refOrNull ?? ZSubfolderRef(id: '', label: label),
    selected,
  );
  if (custom != null) return custom;
  return zBuildSubfolderDefaultItemContent(
    context,
    refOrNull,
    label,
    rootIcon: rootIcon,
    maxLines: spec.itemMaxLines,
  );
}

/// Chrome neutre par défaut : pastille d'accent (si `colorKey`) + libellé +
/// badge de compteur (si `count`) — MÊMES informations que la rangée de la
/// sidebar (parité R-SUF2). Aucune couleur ni libellé en dur (FR-26).
///
/// **Fonction (et non widget)** : le sélecteur en puces rendait déjà ce `Row`
/// SANS élément intermédiaire. En faire une classe insérerait un élément dans
/// l'arbre du mode `compact`, dont CR-IFFD-40 promet le rendu **strictement
/// inchangé**.
Widget zBuildSubfolderDefaultItemContent(
  BuildContext context,
  ZSubfolderRef? ref,
  String label, {
  IconData? rootIcon,
  int? maxLines,
}) {
  final ZcrudTheme theme = ZcrudTheme.of(context);
  // CR-IFFD-46, point 3 — `maxLines` n'a de sens que si la largeur est BORNÉE :
  // le retour à la ligne exige un `Flexible`, et un `Flexible` sous contrainte
  // de largeur non bornée lève « RenderFlex children have non-zero flex but
  // incoming width constraints are unbounded ». La rangée de puces défile
  // horizontalement ⇒ non bornée ⇒ on n'y pose RIEN (cf. `boundsWidth`).
  // Surface inconnue (`null` : hors surface zcrud, ou coquille d'hôte) ⇒ même
  // prudence : le socle ne suppose pas une contrainte qu'il n'a pas posée.
  final bool bounded = ZSubfolderSurface.maybeOf(context)?.boundsWidth ?? false;
  final bool wrap = maxLines != null && bounded;
  // `null` ⇒ arbre STRICTEMENT inchangé : ni `Flexible`, ni `maxLines`, ni
  // `overflow` — la neutralité est littérale, pas seulement visuelle.
  final Widget text = Text(
    label,
    textAlign: TextAlign.start,
    maxLines: wrap ? maxLines : null,
    overflow: wrap ? TextOverflow.ellipsis : null,
  );
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      // Glyphe de tête de la RACINE (point 1) — `null` ⇒ absent de l'arbre
      // (AD-4). Il occupe la place que la pastille d'accent tient sur un
      // sous-dossier ; les deux ne coexistent jamais (la racine n'a pas de
      // `colorKey`).
      if (ref == null && rootIcon != null) ...<Widget>[
        // Aucune taille ni couleur littérale : le glyphe suit l'`IconTheme`
        // ambiant (donc l'inversion posée par `ZInvertedSurface` quand la
        // racine est l'élément courant) — FR-26/CR-IFFD-42.
        Icon(rootIcon),
        SizedBox(width: theme.gapS),
      ],
      if (ref?.colorKey != null) ...<Widget>[
        ZSubfolderAccentPastille(colorKey: ref!.colorKey!),
        SizedBox(width: theme.gapS),
      ],
      if (wrap) Flexible(child: text) else text,
      if (ref?.count != null) ...<Widget>[
        SizedBox(width: theme.gapS),
        ZSubfolderCountPill(count: ref!.count!),
      ],
    ],
  );
}
