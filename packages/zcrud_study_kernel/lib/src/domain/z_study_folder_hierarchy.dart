/// Primitive pure de validation de hiérarchie 2 niveaux.
///
/// Encode l'invariant « 2 niveaux max » qu'un repository appelle dans sa
/// méthode de sauvegarde de dossier (jamais l'entité — invariant AD-14 :
/// `ZStudyFolder` reste données + `copyWith`, sans assert ni throw).
/// Retourne un `ZResult<Unit>` (invariant AD-11) : `Right(unit)` si le
/// placement est valide, `Left(ZDomainFailure)` sinon. Pure, sans I/O ni
/// horloge : testable en isolation, sans backend.
///
/// Réutilise intégralement les types du cœur (`ZResult`, `Unit`, `unit`,
/// `ZDomainFailure`) — aucun nouveau type de failure (invariant AD-1).
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_folder.dart';

/// Valide le placement d'un dossier dans la hiérarchie 2 niveaux max.
///
/// Profondeur 1-indexée (racine = niveau 1) : niveaux 1 et 2 autorisés,
/// niveau ≥ 3 rejeté.
///
/// Paramètres :
/// - [parentId] : parent visé (`null` = racine) ;
/// - [parent] : le dossier parent déjà résolu par le repository (requis dès
///   que [parentId] est non nul — le contrat est que le repository résout
///   le parent avant d'appeler ; un parent non résolu est un rattachement
///   refusé) ;
/// - [selfId] : identité du dossier validé (garde d'auto-parent).
///
/// Sémantique exacte (retourne au premier échec) :
/// - `selfId != null && parentId == selfId` (dossier son propre parent) ⇒
///   `Left(ZDomainFailure)` ;
/// - `parentId == null` (racine, niveau 1) ⇒ `Right(unit)` ;
/// - `parentId != null && parent == null` (parent introuvable/non résolu) ⇒
///   `Left(ZDomainFailure)` ;
/// - `parentId != null && parent.parentId == null` (parent = racine, enfant
///   niveau 2) ⇒ `Right(unit)` ;
/// - `parentId != null && parent.parentId != null` (placer sous un enfant ⇒
///   niveau 3) ⇒ `Left(ZDomainFailure)`.
ZResult<Unit> validatePlacement({
  required String? parentId,
  ZStudyFolder? parent,
  String? selfId,
}) {
  // Garde d'intégrité : un dossier ne peut être son propre parent.
  if (selfId != null && parentId == selfId) {
    return const Left<ZFailure, Unit>(
      ZDomainFailure('Un dossier ne peut pas être son propre parent.'),
    );
  }
  // Racine (niveau 1) : toujours valide.
  if (parentId == null) {
    return const Right<ZFailure, Unit>(unit);
  }
  // Rattachement à un parent inexistant/non résolu : refusé (le repo résout le
  // parent avant d'appeler — cf. contrat).
  if (parent == null) {
    return const Left<ZFailure, Unit>(
      ZDomainFailure('Parent introuvable : rattachement refusé.'),
    );
  }
  // Le parent a lui-même un parent ⇒ placer ici créerait un niveau 3 : refusé.
  if (parent.parentId != null) {
    return const Left<ZFailure, Unit>(
      ZDomainFailure('Hiérarchie limitée à 2 niveaux (racine + sous-dossier).'),
    );
  }
  // Parent = racine ⇒ l'enfant est niveau 2 : valide.
  return const Right<ZFailure, Unit>(unit);
}
