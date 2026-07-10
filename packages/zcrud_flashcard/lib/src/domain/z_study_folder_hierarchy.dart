/// Primitive PURE de validation de hiérarchie 2 niveaux (Story E9-3, AC9,
/// canonique §2.3, AD-5/AD-11/AD-14).
///
/// Encode l'invariant « **2 niveaux max** » que le repository E9-4 appellera
/// dans `saveFolder` (jamais l'entité — AD-14 : `ZStudyFolder` reste données +
/// `copyWith`, sans assert ni throw). Retourne un `ZResult<Unit>`
/// (`Either<ZFailure, Unit>` — AD-11) : `Right(unit)` si le placement est
/// valide, `Left(DomainFailure)` sinon. Pure, **sans I/O** ni horloge :
/// unit-testable dès E9-3 (sans Firebase).
///
/// Réutilise **intégralement** les types du cœur (`ZResult`, `Unit`, `unit`,
/// `DomainFailure`) — aucun nouveau type de failure (AD-1).
library;

import 'package:zcrud_core/zcrud_core.dart';

import 'z_study_folder.dart';

/// Valide le placement d'un dossier dans la hiérarchie **2 niveaux max** (AC9).
///
/// Profondeur **1-indexée** (racine = niveau 1) : niveaux 1 et 2 autorisés,
/// niveau ≥ 3 rejeté.
///
/// Paramètres :
/// - [parentId] : parent visé (`null` = racine) ;
/// - [parent] : le dossier parent **déjà résolu** par le repo (requis dès que
///   [parentId] est non nul — le contrat est que le repo résout le parent avant
///   d'appeler ; un parent non résolu est un rattachement refusé) ;
/// - [selfId] : identité du dossier validé (garde d'auto-parent).
///
/// Sémantique **exacte** (retourne au **premier** échec) :
/// - `selfId != null && parentId == selfId` (dossier son propre parent) ⇒
///   `Left(DomainFailure)` ;
/// - `parentId == null` (racine, niveau 1) ⇒ `Right(unit)` ;
/// - `parentId != null && parent == null` (parent introuvable/non résolu) ⇒
///   `Left(DomainFailure)` ;
/// - `parentId != null && parent.parentId == null` (parent = racine, enfant
///   niveau 2) ⇒ `Right(unit)` ;
/// - `parentId != null && parent.parentId != null` (placer sous un enfant ⇒
///   niveau 3) ⇒ `Left(DomainFailure)`.
ZResult<Unit> validatePlacement({
  required String? parentId,
  ZStudyFolder? parent,
  String? selfId,
}) {
  // Garde d'intégrité : un dossier ne peut être son propre parent.
  if (selfId != null && parentId == selfId) {
    return const Left<ZFailure, Unit>(
      DomainFailure('Un dossier ne peut pas être son propre parent.'),
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
      DomainFailure('Parent introuvable : rattachement refusé.'),
    );
  }
  // Le parent a lui-même un parent ⇒ placer ici créerait un niveau 3 : refusé.
  if (parent.parentId != null) {
    return const Left<ZFailure, Unit>(
      DomainFailure('Hiérarchie limitée à 2 niveaux (racine + sous-dossier).'),
    );
  }
  // Parent = racine ⇒ l'enfant est niveau 2 : valide.
  return const Right<ZFailure, Unit>(unit);
}
