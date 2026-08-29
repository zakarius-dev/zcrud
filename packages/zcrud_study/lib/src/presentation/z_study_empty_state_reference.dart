/// Le RENDU DE RÉFÉRENCE des états vides d'étude, par NATURE de contenu,
/// centralisé en un seul endroit (même patron que `ZStudyCardReference` et
/// `ZFolderCardReference`).
///
/// ## Ce que ce fichier est
///
/// Une **table figée** : à chaque nature de contenu d'un dossier d'étude
/// correspond une spécification d'état vide — glyphe, taille de glyphe, clés de
/// libellé. Rien d'autre. Le rendu, lui, appartient à `ZEmptyState`
/// (`zcrud_ui_kit`), qui sait déjà lire une [ZEmptyStateSpec] par
/// `ZEmptyState.fromSpec`.
///
/// ## FR-26 — aucune couleur ici
///
/// Ce fichier ne contient **AUCUNE couleur** : uniquement des `IconData`, des
/// dimensions et des clés opaques. Il n'est donc **pas** inscrit dans
/// l'exemption nominative de la garde de source anti-couleurs, et l'y inscrire
/// serait une exemption inutile.
///
/// ## Les clés sont OPAQUES, les libellés viennent de l'hôte
///
/// `zcrud_study` ne porte aucun catalogue de libellés : toute chaîne visible
/// est injectée par l'appelant. Les `titleKey`/`messageKey`/`actionLabelKey` de
/// cette table sont donc des **identifiants stables du paquet**, que l'hôte
/// associe à ses propres traductions. Ils ne sont jamais affichés tels quels.
///
/// ## Nature INCONNUE ⇒ aucune spécification
///
/// [zStudyEmptyStateSpecFor] rend `null` pour une clé qu'elle ne connaît pas.
/// C'est une valeur fonctionnelle : « cet écran n'a pas de nature déclarée,
/// garde le rendu que tu avais ». Aucune spécification n'est inventée, aucun
/// glyphe par défaut n'est imposé.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZEmptyStateSpec;

/// Les NATURES de contenu d'étude reconnues — clés opaques et **stables** du
/// paquet, jamais des libellés.
abstract final class ZStudyContentNature {
  /// Un dossier d'étude entier, toutes natures confondues.
  static const String folder = 'zcrud.study.nature.folder';

  /// Les cartes mémoire d'un dossier.
  static const String flashcards = 'zcrud.study.nature.flashcards';

  /// Les notes d'un dossier.
  static const String notes = 'zcrud.study.nature.notes';

  /// Les cartes mentales d'un dossier.
  static const String mindmaps = 'zcrud.study.nature.mindmaps';

  /// Les documents d'un dossier.
  static const String documents = 'zcrud.study.nature.documents';

  /// Les examens d'un dossier.
  static const String exams = 'zcrud.study.nature.exams';

  /// Les natures reconnues, dans l'ordre de la table de référence.
  static const List<String> values = <String>[
    folder,
    flashcards,
    notes,
    mindmaps,
    documents,
    exams,
  ];
}

/// Les valeurs de RÉFÉRENCE des états vides d'étude — le point d'audit unique.
abstract final class ZStudyEmptyStateReference {
  /// Taille du glyphe de l'état vide d'un dossier ENTIER (**200**).
  ///
  /// Nettement au-dessus de la taille d'un glyphe d'état vide par nature : cet
  /// état-là occupe la page entière, les autres une section.
  static const double folderGlyphSize = 200;

  /// Taille du glyphe d'un état vide PAR NATURE (**24** — la taille ambiante
  /// d'une icône Material, celle du rendu de référence).
  static const double natureGlyphSize = 24;

  /// La table de référence, figée : une spécification par nature de contenu.
  ///
  /// Les glyphes sont ceux du rendu de référence, nature par nature. Aucun
  /// n'est déduit d'un autre : ce sont des valeurs mesurées, pas une famille
  /// cohérente qu'on pourrait dériver.
  static const Map<String, ZEmptyStateSpec> byNature =
      <String, ZEmptyStateSpec>{
    ZStudyContentNature.folder: ZEmptyStateSpec(
      // `folder_open` — le pendant Material du glyphe de référence.
      iconData: Icons.folder_open,
      titleKey: 'zcrud.study.empty.folder.title',
      messageKey: 'zcrud.study.empty.folder.message',
      actionLabelKey: 'zcrud.study.empty.folder.action',
    ),
    ZStudyContentNature.flashcards: ZEmptyStateSpec(
      iconData: Icons.card_membership_outlined,
      titleKey: 'zcrud.study.empty.flashcards.title',
      messageKey: 'zcrud.study.empty.flashcards.message',
      actionLabelKey: 'zcrud.study.empty.flashcards.action',
    ),
    ZStudyContentNature.notes: ZEmptyStateSpec(
      iconData: Icons.note_outlined,
      titleKey: 'zcrud.study.empty.notes.title',
      messageKey: 'zcrud.study.empty.notes.message',
      actionLabelKey: 'zcrud.study.empty.notes.action',
    ),
    ZStudyContentNature.mindmaps: ZEmptyStateSpec(
      iconData: Icons.device_hub_outlined,
      titleKey: 'zcrud.study.empty.mindmaps.title',
      messageKey: 'zcrud.study.empty.mindmaps.message',
      actionLabelKey: 'zcrud.study.empty.mindmaps.action',
    ),
    ZStudyContentNature.documents: ZEmptyStateSpec(
      iconData: Icons.insert_drive_file_outlined,
      titleKey: 'zcrud.study.empty.documents.title',
      messageKey: 'zcrud.study.empty.documents.message',
      actionLabelKey: 'zcrud.study.empty.documents.action',
    ),
    // L'examen n'a AUCUN état vide dans le rendu de référence : sa
    // spécification est une EXTRAPOLATION assumée, alignée sur le glyphe de la
    // carte d'examen du paquet — la seule des six dans ce cas.
    ZStudyContentNature.exams: ZEmptyStateSpec(
      iconData: Icons.assignment_outlined,
      titleKey: 'zcrud.study.empty.exams.title',
      messageKey: 'zcrud.study.empty.exams.message',
      actionLabelKey: 'zcrud.study.empty.exams.action',
    ),
  };

  /// Taille de glyphe de référence pour [nature], ou `null` si la nature est
  /// inconnue.
  static double? glyphSizeFor(String nature) {
    if (!byNature.containsKey(nature)) return null;
    return nature == ZStudyContentNature.folder
        ? folderGlyphSize
        : natureGlyphSize;
  }
}

/// Spécification d'état vide de la nature [nature], ou `null` si cette nature
/// n'est pas reconnue — l'appelant garde alors le rendu qu'il avait.
ZEmptyStateSpec? zStudyEmptyStateSpecFor(String nature) =>
    ZStudyEmptyStateReference.byNature[nature];
