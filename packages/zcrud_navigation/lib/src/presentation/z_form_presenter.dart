/// Port de **présentation d'un formulaire d'édition** —
/// abstraction **pluggable, jamais `sealed`**.
///
/// [ZFormPresenter] est le contrat qui **exécute** un [ZEditionPresentation]
/// (mode calculé en amont par `ZPresentationPolicy`) sur la **bonne
/// surface modale** (page pleine / bottom-sheet / dialog). Il est
/// **form-agnostique** : il reçoit un [WidgetBuilder] opaque et un mode — il
/// **n'inspecte jamais** le type du formulaire par une heuristique de nom de
/// classe.
///
/// **Pluggable, jamais `sealed` (invariant AD-4)** : une implémentation
/// définie **hors de ce package** (le présentateur GetX `ZGetFormPresenter`
/// de `zcrud_get`, un présentateur `go_router`, ou un fake de test) **compile
/// et se substitue** au défaut [ZAdaptivePresenter] via le seam
/// `ZFormPresenterScope`.
///
/// **Couche présentation (invariants AD-5/AD-14)** : ce port importe
/// `package:flutter/widgets.dart` (il exige un [BuildContext] et un
/// [WidgetBuilder]) — il **ne peut donc PAS** vivre sous `domain/`, qui reste
/// **100 % pur-Dart** (enums + politique de présentation). Il vit donc sous
/// `presentation/`.
///
/// **Aucun gestionnaire d'état ni routeur (invariants AD-2/AD-15)** : le
/// contrat n'impose **aucun** `get`/`go_router`/`flutter_riverpod`/`provider` ;
/// le défaut [ZAdaptivePresenter] l'honore en **Flutter vanilla**.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_edition_presentation.dart';

/// Contrat **pluggable** de présentation d'un formulaire d'édition.
///
/// `abstract interface class` (Dart 3) : contrat d'implémentation **pur**,
/// **jamais `sealed`** ni `final` — implémentable **hors package** (invariant
/// AD-4). Le présentateur par défaut est [ZAdaptivePresenter] ; les variantes
/// manager (GetX / go_router) sont livrées par les **bindings** comme impls
/// de **ce même port**.
abstract interface class ZFormPresenter {
  /// Présente le formulaire construit par [builder] sur la surface dictée par
  /// [mode] (page / sheet / dialog), et complète le `Future` avec la valeur
  /// éventuellement remontée par `Navigator.pop(value)` / la fermeture de la
  /// modale.
  ///
  /// - [context] : contexte de présentation (mesure via `MediaQuery.sizeOf`,
  ///   **jamais** `Get.context!`/`Get.width`).
  /// - [builder] : contenu **opaque** (form-agnostique) — le port ne l'inspecte
  ///   pas.
  /// - [mode] : **toujours** l'`enum` [ZEditionPresentation] — **aucun**
  ///   `bool fullscreenDialog`/`dialog`.
  /// - [maxWidth] / [maxHeight] : tailles max **explicites** (dp) pour `sheet`
  ///   et `dialog` ; `null` ⇒ défaut dérivé de `MediaQuery.sizeOf(context)`. En
  ///   mode `page` (route pleine) elles sont **ignorées**.
  /// - [useSafeArea] : encapsule la surface dans une `SafeArea` (a11y) pour
  ///   `sheet` et `dialog`. En mode `page` (route pleine) il est **ignoré**
  ///   — cf. « inertie déclarée » ci-dessous.
  /// - [barrierDismissible] : autorise la fermeture au tap sur la barrière
  ///   (mode `dialog`). En `sheet`, la barrière se règle par `isDismissible`
  ///   (port `ZImplicitDismissControl`) ; en `page` il n'y a pas de barrière.
  ///
  /// ## Inertie DÉCLARÉE
  ///
  /// **Règle du port : tout paramètre est soit honoré sur une surface, soit
  /// déclaré inerte sur elle.** Jamais « passé, jamais lu, jamais dit ».
  ///
  /// La table complète — paramètre × mode — n'est pas recopiée ici : elle est
  /// **mesurée**, implémentation par implémentation, par une garde qui présente
  /// deux fois la même surface avec deux valeurs contraires et compare
  /// l'empreinte rendue. Un paramètre n'y est « honoré » que si les deux
  /// empreintes **diffèrent** ; il n'existe nulle part où écrire un statut.
  ///
  /// * `ZAdaptivePresenter` → `doc/parameter-matrix-z-adaptive-presenter.md`
  ///   (garde : `test/z_presenter_parameter_matrix_test.dart`) ;
  /// * `ZGetFormPresenter` (`zcrud_get`) →
  ///   `packages/zcrud_get/doc/parameter-matrix-z-get-form-presenter.md`.
  ///
  /// Une implémentation **tierce** du port n'est tenue par aucune de ces deux
  /// gardes : elle doit publier sa propre matrice si elle veut la même
  /// garantie.
  ///
  /// `useSafeArea` en mode `page` : l'inertie est **mesurée**, pas supposée.
  /// Une route pleine n'insère aujourd'hui **aucune** `SafeArea` — ni avec
  /// `true` (le défaut) ni avec `false` : le contenu brut peint sous l'encoche
  /// dans les deux cas. Honorer la promesse déplacerait donc l'arbre **par
  /// défaut** de tout hôte passif ; la promesse est retirée à la place. Un hôte
  /// qui veut l'encart en `page` place sa propre `SafeArea` (ou fournit un
  /// `ZEditionChrome` : la voie chrome monte un `Scaffold` + `SliverAppBar`,
  /// qui consomme l'encart haut, et une `SafeArea(top: false)` sous les
  /// actions).
  Future<T?> present<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required ZEditionPresentation mode,
    double? maxWidth,
    double? maxHeight,
    bool useSafeArea = true,
    bool barrierDismissible = true,
  });
}
