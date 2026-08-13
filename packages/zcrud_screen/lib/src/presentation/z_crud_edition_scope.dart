/// `ZCrudEditionScope` — **transport du drapeau de lecture et du retour vers
/// l'édition** jusqu'au formulaire présenté par un `ZCrudScreen`.
///
/// La chaîne d'une fiche de détail va de la liste au formulaire :
/// `liste → présentation → formulaire`. Le dernier maillon est celui qui
/// compte — une fiche dérivée des **colonnes** ne montre que les quatre ou six
/// champs affichés, là où le formulaire les montre **tous**. Ce scope est ce
/// maillon : posé autour de la surface d'édition, il dit au formulaire, quel
/// qu'il soit, qu'il est rendu en consultation — et **comment en sortir**.
///
/// Le formulaire **dérivé** de l'écran le lit tout seul (rien à faire). Un
/// formulaire **fourni par l'application** (`ZCrudScreen.editionBuilder`) le
/// lit depuis le `BuildContext` qu'il reçoit :
///
/// ```dart
/// editionBuilder: (context, initial, save) {
///   final modifier = ZCrudEditionScope.onEditOf(context);
///   return MonFormulaire(
///     initial: initial,
///     onSave: save,
///     readOnly: ZCrudEditionScope.readOnlyOf(context),
///     // `null` ⇒ l'édition n'est pas permise : on ne dessine pas le bouton,
///     // plutôt que d'en dessiner un mort.
///     onEdit: modifier,
///   );
/// },
/// ```
///
/// **Pourquoi un scope plutôt qu'un paramètre de plus** : `ZCrudEditionBuilder`
/// est déjà consommé par les applications ; lui ajouter un paramètre —
/// positionnel ou nommé — rendrait **toutes** les lambdas existantes
/// inassignables au typedef, donc casserait chaque hôte à la compilation. Le
/// scope est strictement additif : le code écrit hier compile inchangé, et
/// celui qui veut le drapeau le lit.
library;

import 'package:flutter/widgets.dart';

import 'z_crud_screen_actions.dart' show ZCrudOpener;

/// Contexte d'édition posé par `ZCrudScreen` autour de la surface présentée.
///
/// Porte les deux informations que la surface ne peut pas déduire seule : le
/// formulaire est-il ouvert en **consultation** ([readOnly] `true`, fiche de
/// détail) ou en **édition** ([readOnly] `false`) — et, en consultation, le
/// **retour vers l'édition** est-il offert ([onEdit]) ?
class ZCrudEditionScope extends InheritedWidget {
  /// Pose le contexte d'édition autour de [child].
  const ZCrudEditionScope({
    required this.readOnly,
    required super.child,
    this.onEdit,
    super.key,
  });

  /// `true` si la surface est rendue en **lecture seule** (fiche de détail).
  ///
  /// Un formulaire applicatif qui le lit doit rendre ses champs non
  /// modifiables — y compris ceux qu'il dessine lui-même — et masquer ses
  /// actions d'écriture.
  final bool readOnly;

  /// Bascule la surface **courante** vers l'édition, ou `null` si le geste
  /// n'est pas offert.
  ///
  /// C'est le « Modifier » **de la fiche**, symétrique du `zCrudEditionOpener`
  /// des cartes de liste : l'action « modifier » existe sur la **ligne**, elle
  /// manquait **dans** la fiche. L'appeler ne referme rien — la surface reste
  /// ouverte, à sa place, et redevient éditable : les valeurs déjà chargées, la
  /// position de défilement et l'état du formulaire sont conservés.
  ///
  /// **`null` veut dire « ne dessinez pas le bouton »** — même contrat que
  /// [ZCrudScreenActions.editionOpener]. Il est `null` dans tous les cas où le
  /// geste n'a pas de sens ou n'est pas permis :
  ///
  /// * la surface est déjà **en édition** ([readOnly] `false`) ;
  /// * l'ACL refuse `ZCrudAction.update` sur cette entité (filtrage par ligne) ;
  /// * l'écran est en `ZScreenMode.locked`, en vue corbeille, ou sa source ne
  ///   sait pas écrire ;
  /// * la surface a été ouverte hors d'un `ZCrudScreen`.
  ///
  /// Le `Future` rendu se complète dès que la bascule est faite (aucune
  /// nouvelle surface n'est présentée) ; un second appel est sans effet.
  final ZCrudOpener? onEdit;

  /// Le contexte d'édition le plus proche, ou `null` hors d'une surface
  /// présentée par un `ZCrudScreen`.
  static ZCrudEditionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZCrudEditionScope>();

  /// Le drapeau de lecture du contexte le plus proche, **`false` par défaut**
  /// (aucun contexte ⇒ édition — repli sûr, invariant AD-10 : un formulaire
  /// monté hors écran assemblé reste ce qu'il a toujours été).
  static bool readOnlyOf(BuildContext context) =>
      maybeOf(context)?.readOnly ?? false;

  /// Le retour vers l'édition du contexte le plus proche, ou `null` — hors
  /// écran assemblé, hors consultation, ou droit de modification refusé.
  ///
  /// À lire **avant de rendre** : un formulaire de consultation ne dessine son
  /// bouton « Modifier » que si ce rappel existe.
  static ZCrudOpener? onEditOf(BuildContext context) => maybeOf(context)?.onEdit;

  @override
  bool updateShouldNotify(ZCrudEditionScope oldWidget) =>
      oldWidget.readOnly != readOnly ||
      !identical(oldWidget.onEdit, onEdit);
}
