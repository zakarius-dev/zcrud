/// Port de **présentation d'un formulaire d'édition** (EX-UI.6, AD-30) —
/// abstraction **pluggable, jamais `sealed`**.
///
/// [ZFormPresenter] est le contrat qui **exécute** un [ZEditionPresentation]
/// (mode calculé en amont par `ZPresentationPolicy`, EX-UI.5) sur la **bonne
/// surface modale** (page pleine / bottom-sheet / dialog). Il est
/// **form-agnostique** : il reçoit un [WidgetBuilder] opaque et un mode — il
/// **n'inspecte jamais** le type du formulaire (l'heuristique historique
/// `builder.runtimeType.endsWith("EditionScreen")` des apps GetX est
/// **abandonnée**).
///
/// **Pluggable, jamais `sealed` (AD-4/NFR-U9)** : une implémentation définie
/// **hors de ce package** (le présentateur GetX `ZGetFormPresenter` d'EX-UI.11,
/// un présentateur `go_router`, ou un fake de test) **compile et se substitue**
/// au défaut [ZAdaptivePresenter] via le seam `ZFormPresenterScope`.
///
/// **Couche présentation (D1/AD-5/AD-14)** : ce port importe
/// `package:flutter/widgets.dart` (il exige un [BuildContext] et un
/// [WidgetBuilder]) — il **ne peut donc PAS** vivre sous `domain/`, qui reste
/// **100 % pur-Dart** (enums + politique EX-UI.5). Il vit donc sous
/// `presentation/`.
///
/// **Aucun gestionnaire d'état ni routeur (AD-2/AD-15)** : le contrat n'impose
/// **aucun** `get`/`go_router`/`flutter_riverpod`/`provider` ; le défaut
/// [ZAdaptivePresenter] l'honore en **Flutter vanilla**.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_edition_presentation.dart';

/// Contrat **pluggable** de présentation d'un formulaire d'édition.
///
/// `abstract interface class` (Dart 3) : contrat d'implémentation **pur**,
/// **jamais `sealed`** ni `final` — implémentable **hors package** (AD-4). Le
/// présentateur par défaut est [ZAdaptivePresenter] ; les variantes manager
/// (GetX / go_router) sont livrées par les **bindings** (EX-UI.11) comme impls
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
  ///   `bool fullscreenDialog`/`dialog` (NFR-U7).
  /// - [maxWidth] / [maxHeight] : tailles max **explicites** (dp) pour `sheet`
  ///   et `dialog` ; `null` ⇒ défaut dérivé de `MediaQuery.sizeOf(context)`. En
  ///   mode `page` (route pleine) elles sont **ignorées**.
  /// - [useSafeArea] : encapsule la surface dans une `SafeArea` (a11y).
  /// - [barrierDismissible] : autorise la fermeture au tap sur la barrière
  ///   (mode `dialog`).
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
