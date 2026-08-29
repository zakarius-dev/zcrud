/// Entrées de menu des surfaces de partage — montées SEULEMENT si tout est
/// câblé.
///
/// Le menu d'item ne fabrique aucune entrée : il rend celles que l'hôte
/// compose. Ces deux fabriques sont la voie par laquelle « partager ce
/// dossier » et « ouvrir la galerie » acquièrent une identité stable, sans
/// qu'aucun hôte n'ait à la réécrire.
///
/// Une entrée n'est rendue que si les quatre conditions sont réunies :
/// un glyphe, un libellé, un geste, **et** l'accord du portail
/// [zSharingAccessGranted] (fonctionnalité disponible et ACL accordante ;
/// l'absence de `ZcrudScope` refuse). Il en manque une ⇒ `null`, donc
/// **rien** dans l'arbre — jamais une entrée morte (invariant AD-4).
library;

import 'package:flutter/widgets.dart' show BuildContext, IconData, VoidCallback;
import 'package:zcrud_core/zcrud_core.dart' show ZAcl;

import 'z_feature_availability.dart';
import 'z_item_actions_menu.dart';
import 'z_study_sharing_gate.dart';

/// Construit l'entrée « partager ce dossier », ou `null` si elle n'est pas
/// câblée ou pas autorisée.
///
/// [folderId] est soumis au portail comme `collectionId` : une ACL peut
/// donc décider dossier par dossier.
ZItemAction? zFolderSharingItemAction(
  BuildContext context, {
  IconData? icon,
  String? label,
  VoidCallback? onSelected,
  String? folderId,
  ZFeatureAvailability? availability,
  ZAcl? acl,
  String featureKey = zFeatureKeyFolderSharing,
}) {
  if (icon == null || label == null || onSelected == null) return null;
  if (!zSharingAccessGranted(
    context,
    action: ZStudySharingActions.manageSharing,
    featureKey: featureKey,
    collectionId: folderId,
    availability: availability,
    acl: acl,
  )) {
    return null;
  }
  return ZItemAction(
    kind: ZItemActionKind.custom,
    id: ZStudySharingActions.manageSharing.key,
    label: label,
    icon: icon,
    onSelected: onSelected,
  );
}

/// Construit l'entrée « galerie publique », ou `null` si elle n'est pas
/// câblée ou pas autorisée.
ZItemAction? zPublicGalleryItemAction(
  BuildContext context, {
  IconData? icon,
  String? label,
  VoidCallback? onSelected,
  ZFeatureAvailability? availability,
  ZAcl? acl,
  String featureKey = zFeatureKeyPublicGallery,
}) {
  if (icon == null || label == null || onSelected == null) return null;
  if (!zSharingAccessGranted(
    context,
    action: ZStudySharingActions.browseGallery,
    featureKey: featureKey,
    availability: availability,
    acl: acl,
  )) {
    return null;
  }
  return ZItemAction(
    kind: ZItemActionKind.custom,
    id: ZStudySharingActions.browseGallery.key,
    label: label,
    icon: icon,
    onSelected: onSelected,
  );
}
