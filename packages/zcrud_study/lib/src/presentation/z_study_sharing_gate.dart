/// Portail d'accès **fail-closed** des surfaces de partage et de galerie.
///
/// Une surface de partage n'est pas une surface comme les autres : elle
/// gouverne qui voit quoi. Elle naît donc fermée, et trois conditions
/// INDÉPENDANTES doivent être réunies pour qu'elle s'ouvre :
///
/// 1. un **port** est fourni par l'application (sans lui, aucune surface
///    n'est montée — la décision se prend chez l'appelant, avant même
///    d'atteindre ce portail) ;
/// 2. la **fonctionnalité** est disponible ([ZFeatureAvailability]) ;
/// 3. l'**autorisation** est accordée par le port `ZAcl` du socle.
///
/// La troisième est délibérément stricte : l'ACL est lue sur le
/// `ZcrudScope` le plus proche, et **l'absence de scope refuse**. Le défaut
/// du socle est déjà `ZDenyAllAcl` ; ce portail ne l'assouplit pas, et
/// n'offre aucun repli permissif. Les clés d'action sont **libres**
/// (hors `ZCrudAction`) : une ACL qui n'implémente pas `ZKeyedAcl` les
/// refuse toutes, ce qui est la posture voulue.
///
/// Un refus ne masque jamais silencieusement : les surfaces de ce paquet
/// rendent un état « accès refusé » annoncé, distinct d'une liste vide.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZAcl, ZAclActionKey, ZActionKey, ZcrudScope;

import 'z_feature_availability.dart';

/// Clé de fonctionnalité de la feuille de partage d'un dossier.
///
/// Clé OPAQUE : l'application décide de sa valeur dans sa propre table de
/// disponibilité ; le socle ne l'interprète jamais.
const String zFeatureKeyFolderSharing = 'study.sharing';

/// Clé de fonctionnalité de la galerie publique.
const String zFeatureKeyPublicGallery = 'study.gallery';

/// Clés d'action **libres** consommées par les surfaces de partage.
///
/// Aucune n'a d'équivalent canonique dans `ZCrudAction` : elles passent donc
/// par `ZKeyedAcl.canKey`, et une ACL fermée les refuse toutes.
abstract final class ZStudySharingActions {
  /// Gérer le partage d'un dossier (lien, adhésions, publication).
  static const ZActionKey manageSharing = ZActionKey('study.sharing.manage');

  /// Consulter la galerie publique.
  static const ZActionKey browseGallery = ZActionKey('study.gallery.browse');
}

/// `true` SSI la fonctionnalité [featureKey] est disponible **et** l'action
/// [action] est autorisée pour [collectionId].
///
/// [availability] `null` ⇒ la disponibilité est lue sur
/// [ZFeatureAvailabilityScope] (défaut fail-open du socle : la disponibilité
/// est une restriction opt-in de l'application). [acl] `null` ⇒ l'ACL est
/// lue sur le `ZcrudScope` le plus proche ; **aucun scope ⇒ `false`**.
///
/// Ne lève jamais.
bool zSharingAccessGranted(
  BuildContext context, {
  required ZActionKey action,
  required String featureKey,
  String? collectionId,
  ZFeatureAvailability? availability,
  ZAcl? acl,
}) {
  final ZFeatureAvailability resolved =
      availability ?? ZFeatureAvailabilityScope.of(context);
  if (!resolved.isAvailable(featureKey)) return false;
  // Fail-closed : sans ACL explicite ET sans ZcrudScope, rien n'est accordé.
  final ZAcl? effective = acl ?? ZcrudScope.maybeOf(context)?.acl;
  if (effective == null) return false;
  return effective.canAction(action, collectionId: collectionId);
}
