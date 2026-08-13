/// `ZCrudEditionScope` — **transport du drapeau de lecture** jusqu'au
/// formulaire présenté par un `ZCrudScreen`.
///
/// La chaîne d'une fiche de détail va de la liste au formulaire :
/// `liste → présentation → formulaire`. Le dernier maillon est celui qui
/// compte — une fiche dérivée des **colonnes** ne montre que les quatre ou six
/// champs affichés, là où le formulaire les montre **tous**. Ce scope est ce
/// maillon : posé autour de la surface d'édition, il dit au formulaire, quel
/// qu'il soit, qu'il est rendu en consultation.
///
/// Le formulaire **dérivé** de l'écran le lit tout seul (rien à faire). Un
/// formulaire **fourni par l'application** (`ZCrudScreen.editionBuilder`) le
/// lit depuis le `BuildContext` qu'il reçoit :
///
/// ```dart
/// editionBuilder: (context, initial, save) => MonFormulaire(
///   initial: initial,
///   onSave: save,
///   readOnly: ZCrudEditionScope.readOnlyOf(context),
/// ),
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

/// Contexte d'édition posé par `ZCrudScreen` autour de la surface présentée.
///
/// Porte l'unique information que la surface ne peut pas déduire seule : le
/// formulaire est-il ouvert en **consultation** ([readOnly] `true`, mode
/// `ZScreenMode.details`) ou en **édition** ([readOnly] `false`) ?
class ZCrudEditionScope extends InheritedWidget {
  /// Pose le contexte d'édition autour de [child].
  const ZCrudEditionScope({
    required this.readOnly,
    required super.child,
    super.key,
  });

  /// `true` si la surface est rendue en **lecture seule** (fiche de détail).
  ///
  /// Un formulaire applicatif qui le lit doit rendre ses champs non
  /// modifiables — y compris ceux qu'il dessine lui-même — et masquer ses
  /// actions d'écriture.
  final bool readOnly;

  /// Le contexte d'édition le plus proche, ou `null` hors d'une surface
  /// présentée par un `ZCrudScreen`.
  static ZCrudEditionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZCrudEditionScope>();

  /// Le drapeau de lecture du contexte le plus proche, **`false` par défaut**
  /// (aucun contexte ⇒ édition — repli sûr, invariant AD-10 : un formulaire
  /// monté hors écran assemblé reste ce qu'il a toujours été).
  static bool readOnlyOf(BuildContext context) =>
      maybeOf(context)?.readOnly ?? false;

  @override
  bool updateShouldNotify(ZCrudEditionScope oldWidget) =>
      oldWidget.readOnly != readOnly;
}
