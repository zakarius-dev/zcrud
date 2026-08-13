/// Gouvernance **par ligne** : les droits effectifs d'UNE entité, et la
/// résolution des actions qui en découle.
///
/// ## Le besoin
///
/// Une autorisation utile n'est pas seulement « cet utilisateur peut-il
/// supprimer dans cette collection ? », mais « peut-il supprimer **cette**
/// ligne-là ? ». Un dossier clôturé ne se modifie plus, une pièce déjà validée
/// ne se valide pas deux fois, une cargaison datée d'un exercice fermé se
/// consulte sans s'écrire — trois refus qui portent sur l'élément, pas sur la
/// collection.
///
/// ## Le concept : UN résolveur, jamais une liste de dérogations
///
/// Tout cela se déclare par un **seul** point d'extension, [ZRowAclResolver] :
/// une fonction pure qui, pour une entité donnée, rend les [ZRowPermissions]
/// de cette ligne. Ajouter un besoin n'ajoute donc jamais un paramètre à
/// l'écran : c'est le même résolveur qui l'exprime.
///
/// Le complément, quand la distinction ne porte pas sur un droit mais sur le
/// **sens métier** d'une action précise, est `ZRowAction.enabledFor` :
/// « restaurer » n'a rien à faire sur un élément vivant, quels que soient les
/// droits de qui regarde.
///
/// ## 🔒 La règle qui rend l'ensemble sûr : on RESTREINT, on n'ÉLARGIT JAMAIS
///
/// [ZRowPermissions] n'a **aucun vocabulaire d'autorisation** : on y déclare ce
/// que la ligne **refuse**, jamais ce qu'elle accorde. Un résolveur ne peut
/// donc pas — même par erreur, même volontairement — rouvrir un geste que
/// l'ACL de l'écran ou du scope a fermé. La composition est une
/// **intersection** : une action est offerte si l'ACL **et** la ligne
/// l'admettent.
///
/// C'est ce qui permet de confier le résolveur à du code métier sans en faire
/// une surface de contournement des droits.
///
/// ## Droit refusé ≠ action inapplicable
///
/// Deux refus de nature différente, deux traitements distincts :
///
/// | Nature | Origine | Rendu |
/// |---|---|---|
/// | **Droit refusé** | ACL d'écran/scope, ou [ZRowPermissions] | gouverné par le mode `ZActionAclMode` déclaré : `hide` masque, `disable` montre inerte |
/// | **Action inapplicable** | `ZRowAction.enabledFor` | **toujours** rendue inerte, avec son motif — l'action existe, elle ne s'applique pas ici |
///
/// Masquer une action inapplicable ferait clignoter les lignes d'une liste au
/// gré de leur état ; l'application, elle, garde la souveraineté sur ce qu'elle
/// veut faire des refus de **droit**.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;

import '../../domain/contracts/z_entity.dart';
import '../../domain/ports/z_acl.dart';
import 'z_row_action.dart';

/// Droits effectifs d'**une ligne**, exprimés en **restrictions**.
///
/// Une instance ne dit jamais « cette ligne autorise X » : elle dit « cette
/// ligne refuse X », ou « cette ligne est en lecture seule ». Les droits
/// réellement offerts restent ceux de l'ACL de l'application, **moins** ce que
/// la ligne retire.
///
/// ```dart
/// // Un dossier clôturé ne s'écrit plus.
/// ZCrudScreen<Dossier>(
///   rowAcl: (dossier) => dossier.cloture
///       ? const ZRowPermissions.locked(reasonKey: 'dossierClosed')
///       : const ZRowPermissions.unrestricted(),
///   // …
/// );
/// ```
@immutable
class ZRowPermissions {
  /// Construit les restrictions d'une ligne.
  ///
  /// [denied] : actions expressément refusées sur cette ligne.
  ///
  /// [readOnly] : `true` retire **toutes** les actions qui écrivent (au sens de
  /// `ZCrudActionMutation.mutatesData`), en laissant la consultation et
  /// l'historique.
  ///
  /// [reasonKey] : clé de libellé annonçant le motif du refus (résolue comme
  /// tout libellé du socle : surcharge du scope, delegate, repli). Annoncée aux
  /// lecteurs d'écran quand l'action est montrée inerte.
  const ZRowPermissions({
    this.denied = const <ZCrudAction>{},
    this.readOnly = false,
    this.reasonKey,
  });

  /// La ligne ne retire **rien** : les droits sont exactement ceux de l'ACL.
  ///
  /// C'est la valeur à rendre pour les lignes ordinaires — elle est `const`,
  /// donc sans coût d'allocation dans une liste longue.
  const ZRowPermissions.unrestricted()
      : denied = const <ZCrudAction>{},
        readOnly = false,
        reasonKey = null;

  /// La ligne est en **lecture seule** : toute action qui écrit lui est
  /// retirée, la consultation reste ouverte.
  const ZRowPermissions.locked({this.reasonKey})
      : denied = const <ZCrudAction>{},
        readOnly = true;

  /// La ligne refuse les [actions] nommées, et rien d'autre.
  const ZRowPermissions.denying(Set<ZCrudAction> actions, {this.reasonKey})
      : denied = actions,
        readOnly = false;

  /// Actions expressément refusées sur cette ligne.
  final Set<ZCrudAction> denied;

  /// `true` si la ligne interdit toute action qui écrit.
  final bool readOnly;

  /// Clé de libellé du motif de refus, annoncée quand l'action est montrée
  /// inerte ; `null` = motif générique.
  final String? reasonKey;

  /// `true` si cette instance ne retire aucun droit (cas de la très grande
  /// majorité des lignes) — permet de court-circuiter toute la résolution.
  bool get restrictsNothing => !readOnly && denied.isEmpty;

  /// `true` si la ligne **admet** [action] — c'est-à-dire si elle ne la retire
  /// pas. Ce n'est jamais une autorisation : le droit reste celui de l'ACL.
  bool admits(ZCrudAction action) {
    if (denied.contains(action)) return false;
    return !(readOnly && action.mutatesData);
  }

  /// Motif du refus de [action] sur cette ligne, ou `null` si la ligne
  /// l'admet.
  String? reasonFor(ZCrudAction action) => admits(action) ? null : reasonKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRowPermissions &&
          other.readOnly == readOnly &&
          other.reasonKey == reasonKey &&
          setEquals(other.denied, denied);

  @override
  int get hashCode => Object.hash(
        readOnly,
        reasonKey,
        Object.hashAllUnordered(denied),
      );

  @override
  String toString() => 'ZRowPermissions(readOnly: $readOnly, denied: $denied)';
}

/// Résolveur des droits d'**une ligne** : fonction **pure** rendant les
/// restrictions applicables à [entity].
///
/// Appelé une fois par ligne rendue (et par passe de résolution d'actions) :
/// il doit être **bon marché** et sans effet de bord — pas de lecture de
/// dépôt, pas d'allocation inutile. Retourner la constante
/// `ZRowPermissions.unrestricted()` pour les lignes ordinaires ne coûte rien.
typedef ZRowAclResolver<T extends ZEntity> = ZRowPermissions Function(T entity);

/// Résout les actions offertes sur **une ligne**, en composant l'ACL de
/// l'application, les restrictions de la ligne et l'éligibilité métier de
/// chaque action.
///
/// Voie **unique** de résolution du socle : la liste et l'écran assemblé
/// passent tous deux par ici, pour qu'aucune des deux présentations ne puisse
/// dériver de l'autre sur une question de droits.
///
/// Composition, dans l'ordre :
///
/// 1. **Droit** — `acl.can(...)` **ET** [rowAcl] admettent l'action. C'est une
///    intersection : la ligne peut retirer un droit, jamais en ajouter un.
///    Une action sans `requiredPermission` (action libre de l'application) n'a
///    pas de droit à évaluer : elle reste offerte, comme elle l'est déjà
///    vis-à-vis de l'ACL, et se gouverne par `enabledFor`.
/// 2. **Présentation du refus** — [mode] `hide` retire l'action de la liste
///    rendue ; `disable` la garde, inerte et motivée.
/// 3. **Éligibilité** — `ZRowAction.enabledFor` : l'action existe mais ne
///    s'applique pas à cette ligne. Elle est **toujours** rendue, inerte.
///
/// [entity] est liée aux effets ; [collectionId] est transmis à l'ACL.
List<ZResolvedRowAction> zResolveRowActions<T extends ZEntity>(
  BuildContext context, {
  required List<ZRowAction<T>> actions,
  required T entity,
  required ZAcl acl,
  ZActionAclMode mode = ZActionAclMode.hide,
  ZRowAclResolver<T>? rowAcl,
  String? collectionId,
}) {
  final ZRowPermissions permissions =
      rowAcl?.call(entity) ?? const ZRowPermissions.unrestricted();
  final List<ZResolvedRowAction> resolved = <ZResolvedRowAction>[];
  for (final ZRowAction<T> action in actions) {
    final ZCrudAction? permission = action.requiredPermission;
    // Intersection stricte : l'ACL ET la ligne doivent admettre l'action.
    // Aucun `||` ici, jamais — un résolveur permissif ne rouvre rien.
    final bool granted = permission == null ||
        (acl.can(permission, target: entity, collectionId: collectionId) &&
            permissions.admits(permission));
    if (!granted && mode == ZActionAclMode.hide) continue;
    final bool eligible = action.enabledFor?.call(entity) ?? true;
    final String? reasonKey = switch ((granted, eligible)) {
      (false, _) => (permission == null
              ? null
              : permissions.reasonFor(permission)) ??
          'actionNotAllowed',
      (true, false) => action.ineligibleReasonKey ?? 'actionNotApplicable',
      (true, true) => null,
    };
    resolved.add(
      action.resolve(
        context,
        entity,
        enabled: granted && eligible,
        disabledReasonKey: reasonKey,
      ),
    );
  }
  return resolved;
}
