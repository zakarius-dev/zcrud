/// `ZSubfolderRef` — descripteur de PRÉSENTATION OPAQUE d'un sous-dossier
/// d'étude (SUF-3, D3).
///
/// Comme `z_study_mindmap_section.dart` prend un `folderId` opaque et jamais
/// `ZStudyFolder`, et comme `ZFolderCard`/`ZStudyToolsSectionSpec` ne reçoivent
/// que des primitives, la navigation de sous-dossiers de `ZStudyFolderDetail`
/// consomme **exclusivement** ce value-object neutre — **jamais** l'entité
/// domaine/kernel `ZStudyFolder`. Il ne porte :
///
/// - **aucune** `Color`/`IconData` (l'accent dérive de [colorKey] via
///   `zResolveColorKeyOrSlot`, seam total du cœur — AD-10) ;
/// - **aucun** libellé non localisé ([label] est **déjà localisé** par
///   l'appelant, cohérent avec `ZStudyToolsSectionSpec.title`) ;
/// - **aucune** règle métier (pas de permissions, pas d'ordre, pas d'état SRS).
///
/// Un besoin de savoir « quel dossier kernel » serait le signe d'une frontière
/// mal placée (D3).
library;

import 'package:flutter/foundation.dart';

/// Référence OPAQUE d'un sous-dossier pour la navigation (props primitives).
@immutable
class ZSubfolderRef {
  /// Construit une référence. [id] et [label] sont requis ; [colorKey] (accent)
  /// et [count] (compteur affiché) sont optionnels.
  const ZSubfolderRef({
    required this.id,
    required this.label,
    this.colorKey,
    this.count,
  });

  /// Identifiant STABLE et OPAQUE du sous-dossier (`String`). Sert de valeur de
  /// sélection ET de clé de réordonnancement — jamais interprété par le widget.
  final String id;

  /// Libellé **déjà localisé** par l'appelant (AD-13/FR-23) — rendu tel quel.
  final String label;

  /// Clé de couleur d'accent **opaque** (`String?`) résolue par
  /// `zResolveColorKeyOrSlot` (repli total, jamais `null`/throw — AD-10).
  /// `null` ⇒ aucune pastille d'accent (AD-4 : absence structurelle).
  final String? colorKey;

  /// Compteur optionnel (ex. nombre de cartes/notes). `null` ⇒ aucun badge
  /// (AD-4). Le widget n'affiche qu'un **nombre** (jamais un libellé en dur).
  final int? count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSubfolderRef &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          colorKey == other.colorKey &&
          count == other.count;

  @override
  int get hashCode => Object.hash(id, label, colorKey, count);
}
