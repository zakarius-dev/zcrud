/// `ZReadModeScope` — **le mode de présentation d'une surface d'édition**,
/// posé dans le contexte et lu par chaque champ.
///
/// Un formulaire ouvert en consultation doit rendre des **fiches** (libellé
/// au-dessus de la valeur, ni bordure ni libellé flottant ni ornement), et non
/// un formulaire de saisie grisé. Cette information appartient à la **surface**
/// — c'est elle qui sait pourquoi elle est ouverte — mais elle est consommée
/// tout en bas, par chaque champ, à quelque profondeur qu'il soit.
///
/// Elle descend donc **par le contexte**, jamais de main en main : un
/// formulaire qui remplace le rendu de ses champs (`fieldBuilder`), une fenêtre
/// à étapes, une sous-liste, un item dynamique n'ont **rien à recopier**. Un
/// drapeau qui voyage par un paramètre de constructeur se perd au premier
/// intermédiaire qui n'a aucune raison de le connaître ; celui-ci ne se perd
/// pas.
///
/// ## Qui pose, qui lit
///
/// **Posent** : `DynamicEdition` et `ZStepperEdition`, avec leur propre
/// `readOnly` ; le dialogue d'item d'une sous-liste, qui vit dans une autre
/// branche de l'arbre (une route) et repose donc le mode explicitement.
///
/// **Lit** : `ZFieldWidget`, quand son paramètre `readMode` n'est pas donné.
/// **Le paramètre prime toujours** : un appelant qui le passe garde la main, y
/// compris pour aller à contre-courant de la surface (forcer un champ en
/// saisie dans une fiche, ou l'inverse).
///
/// ## Ce que ce scope n'est pas
///
/// * Ce n'est pas `ZcrudScope` : celui-là porte les **seams d'injection** de
///   l'application (résolveur, ACL, thème, registres) — des dépendances, pas
///   l'état d'une surface. Le mode de lecture change d'une surface à l'autre,
///   parfois deux fois dans le même arbre ; il n'a pas sa place dans le bundle
///   d'injection.
/// * Ce n'est pas `ZCrudEditionScope` (paquet `zcrud_screen`) : celui-là est le
///   maillon **au-dessus**, entre l'écran assemblé et le formulaire hôte — il
///   dit à une surface applicative qu'elle est présentée en consultation, et
///   comment revenir à l'édition. Cette surface transmet ensuite son `readOnly`
///   au formulaire, qui pose *ce* scope-ci pour ses champs. La chaîne complète
///   est donc : écran → `ZCrudEditionScope` → surface → `DynamicEdition.readOnly`
///   → `ZReadModeScope` → champs.
/// * Ce n'est pas `ZFieldSpec.readOnly`, qui reste le signal **par champ** (ce
///   champ-ci n'est pas modifiable, même en édition) — jamais un mode de
///   présentation.
///
/// ## Le mode est arrêté au MONTAGE du champ
///
/// Un champ rendu en fiche n'alloue ni contrôleur de texte ni clavier : son
/// mode est donc décidé une fois, quand il est monté. Changer le mode d'une
/// surface déjà affichée suppose de **remonter ses champs** — ce que fait
/// l'écran assemblé en keyant la place du formulaire sur le mode. La lecture
/// de ce scope ne prend, en conséquence, aucun abonnement : elle n'entraîne
/// aucune reconstruction et ne modifie en rien la frontière de rebuild d'un
/// champ.
library;

import 'package:flutter/widgets.dart';

import '../../domain/edition/z_read_field_layout.dart';

/// Mode de présentation de la surface d'édition environnante.
class ZReadModeScope extends InheritedWidget {
  /// Pose le mode [readMode] — et, si elle est donnée, la forme [layout] —
  /// pour tous les champs rendus sous [child].
  ///
  /// Un scope plus proche **remplace** un scope plus haut : un formulaire
  /// d'édition monté à l'intérieur d'une fiche rend bien des champs de saisie.
  const ZReadModeScope({
    required this.readMode,
    required super.child,
    this.layout,
    super.key,
  });

  /// `true` si la surface est rendue en **consultation** : les champs dont la
  /// famille sait se présenter en fiche le font.
  final bool readMode;

  /// **Forme** des champs consultés sous cette surface. `null` ⇒ la surface ne
  /// se prononce pas : la forme vient du jeton `readLayout` du thème, à défaut
  /// [ZReadFieldLayout.card].
  ///
  /// Le même canal porte donc les deux informations : *qu'*on consulte, et
  /// *comment* on présente. Un second mécanisme aurait pu se désynchroniser du
  /// premier — c'est exactement le défaut qui avait fait perdre le mode de
  /// consultation aux builders de remplacement.
  final ZReadFieldLayout? layout;

  /// Le scope le plus proche, ou `null` hors de toute surface d'édition.
  ///
  /// Lecture **sans abonnement** : le mode d'un champ est arrêté à son montage
  /// (voir la documentation de la bibliothèque), et cette lecture est faite
  /// depuis `State.initState`, où prendre une dépendance est interdit.
  static ZReadModeScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ZReadModeScope>();

  /// Le mode de la surface environnante, **`false` par défaut** : hors de toute
  /// surface, un champ reste ce qu'il a toujours été — un champ de saisie
  /// (repli sûr).
  static bool of(BuildContext context) => maybeOf(context)?.readMode ?? false;

  /// La **forme** demandée par la surface environnante, ou `null` si elle ne se
  /// prononce pas.
  ///
  /// Lecture **abonnée** (`dependOnInheritedWidgetOfExactType`) : elle est
  /// faite depuis un `build`, où la dépendance est légale, et une surface qui
  /// change de forme sans changer de mode voit donc ses champs se redessiner.
  /// Aucune reconstruction n'est ajoutée pour autant : ce scope ne change
  /// jamais pendant une frappe (invariant AD-2).
  static ZReadFieldLayout? layoutOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZReadModeScope>()?.layout;

  @override
  bool updateShouldNotify(ZReadModeScope oldWidget) =>
      oldWidget.readMode != readMode || oldWidget.layout != layout;
}
