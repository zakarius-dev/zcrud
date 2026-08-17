/// `ZAppBarActionsBuilder` — les actions d'app-bar **dépendantes de l'état**,
/// toujours déclarées en **données**.
///
/// ## Le besoin, nommé
///
/// `ZCrudScreen.actions` prend une liste **figée** de `ZAppBarAction`. C'est le
/// bon défaut : une action déclarée en données porte son `semanticLabel`, sa
/// cible tactile et son débordement — là où le chemin déprécié
/// `ZCrudScreen.appBarActions` transmet des widgets déjà construits, muets pour
/// un lecteur d'écran (leur sémantique propre est masquée par
/// l'`ExcludeSemantics` du socle et n'est **pas** remplaçable : aucun libellé
/// n'est dérivable d'un widget opaque).
///
/// Mais une liste figée ne sait exprimer qu'une action **constante**. Or une
/// barre utile dépend de ce que l'écran seul connaît : l'**ACL résolue**,
/// l'**onglet actif** et l'**état courant du listing**. Un bouton « Filtres »
/// n'a aucun sens tant qu'aucune donnée n'est chargée ; déclaré en constante il
/// resterait offert — et cliquable — sur une liste vide.
///
/// ## Ce que ce seam ajoute, et ce qu'il n'ajoute pas
///
/// Il **complète** `actions`, il ne le remplace pas : le builder rend des
/// `ZAppBarAction`, jamais des widgets. La conditionnalité est donc obtenue
/// **sans** perdre ce que la déclaration en données a gagné. Les deux voies
/// sont **exclusives** (assertion de construction) : deux sources d'actions
/// additionnelles à la même place rendraient l'ordre de l'app-bar indécidable.
///
/// Il n'ouvre **aucun** accès à l'état interne de l'écran : le contexte porte
/// des lectures dérivées ([ZAppBarActionsContext.itemCount],
/// [ZAppBarActionsContext.isEmpty]), jamais les contrôleurs de listing.
///
/// ## Granularité de reconstruction (AD-2)
///
/// Le builder est réévalué quand l'**onglet actif**, le **comptage** de la vue
/// ou la **portée** (vivants ⇄ corbeille) changent — et **seule la coquille**
/// est rebâtie : le corps de l'écran est construit une fois, au-dessus des
/// abonnements, et transmis tel quel. Un changement de comptage ne reconstruit
/// donc ni la liste, ni les tuiles.
///
/// Le comptage vient de la lecture notifiée déjà livrée
/// (`ZCrudScreenActions.entitiesInViewListenable`) : publication en **fin de
/// trame**, comparaison par **contenu**. Son notifieur n'est créé qu'au premier
/// accès — un écran sans builder ne l'accède jamais, donc ne relève rien, ne
/// compare rien et ne pose aucun rappel de fin de trame.
library;

import 'package:zcrud_core/zcrud_core.dart' show ZAcl;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZAppBarAction;

/// Fabrique des actions d'app-bar **additionnelles**, réévaluée à chaque
/// changement de l'état que porte [ZAppBarActionsContext].
///
/// Rend des [ZAppBarAction] — donc chaque geste garde son libellé accessible,
/// son info-bulle et son éventuel débordement (`isOverflow: true`).
typedef ZAppBarActionsBuilder = List<ZAppBarAction> Function(
  ZAppBarActionsContext context,
);

/// État de l'écran offert à un [ZAppBarActionsBuilder] — les seules lectures
/// dont une action de barre a besoin, sans couplage à l'état interne.
///
/// ```dart
/// ZCrudScreen<Bep>(
///   title: 'beps',
///   source: source,
///   actionsBuilder: (state) => <ZAppBarAction>[
///     if (!state.isEmpty)
///       ZAppBarAction(
///         icon: Icons.filter_alt_off_outlined,
///         semanticLabel: label(context, 'filters'),
///         tooltip: label(context, 'filters'),
///         onPressed: _showFilterDialog,
///       ),
///     if (state.acl.can(ZCrudAction.validate))
///       ZAppBarAction(
///         icon: Icons.verified_outlined,
///         semanticLabel: label(context, 'validate'),
///         onPressed: _validate,
///       ),
///   ],
/// );
/// ```
class ZAppBarActionsContext {
  /// Construit le contexte. [isEmpty] est **dérivé** d'[itemCount] : les deux
  /// lectures ne peuvent pas se contredire.
  const ZAppBarActionsContext({
    required this.acl,
    required this.tabIndex,
    required this.itemCount,
    required this.isTrashView,
  });

  /// ACL **résolue** de l'écran : paramètre `acl` s'il est déclaré, sinon celle
  /// du `ZcrudScope` ambiant, sinon le refus par défaut.
  ///
  /// C'est exactement l'ACL que l'écran interroge pour ses propres gestes —
  /// jamais une seconde résolution. En mode onglets, la restriction de l'onglet
  /// actif y est **déjà** composée en conjonction (cascade
  /// `onglet ∩ écran ∩ scope`) : une action gouvernée par cette ACL suit donc
  /// le segment courant sans que l'appelant ne recompose quoi que ce soit.
  final ZAcl acl;

  /// Index de l'onglet **actif** (`0` hors mode onglets).
  final int tabIndex;

  /// Nombre d'éléments **de la vue courante** — la taille exacte de ce qui est
  /// peint (portée, filtres, recherche, tri et pages chargées compris), pas la
  /// taille de la source.
  ///
  /// En mode onglets, c'est le compte de l'onglet **actif**.
  final int itemCount;

  /// `true` en **vue corbeille**.
  final bool isTrashView;

  /// La vue courante ne montre **rien** — strictement `itemCount == 0`.
  bool get isEmpty => itemCount == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZAppBarActionsContext &&
          runtimeType == other.runtimeType &&
          acl == other.acl &&
          tabIndex == other.tabIndex &&
          itemCount == other.itemCount &&
          isTrashView == other.isTrashView;

  @override
  int get hashCode => Object.hash(acl, tabIndex, itemCount, isTrashView);

  @override
  String toString() => 'ZAppBarActionsContext(tabIndex: $tabIndex, '
      'itemCount: $itemCount, isTrashView: $isTrashView)';
}
