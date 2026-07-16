/// Politique de **présentation d'édition** (EX-UI.5, AD-30) — le « maillon
/// manquant » : dérive PUREMENT un [ZEditionPresentation] d'un `ZWindowSizeClass`.
///
/// Aucune des apps historiques ne **dérive** le mode de présentation du
/// breakpoint : chacune le fige au call-site (`showPushedDialog(dialog:
/// isWebOrDesktop)` — couplage à une largeur globale). [ZPresentationPolicy] pose
/// la règle `breakpoint → mode` qui n'existe nulle part, **surchargeable par app
/// sans modifier le package** (AD-6), **non-`sealed`** (AD-4).
///
/// **Pureté (AD-5/AD-14/D7)** : ce fichier n'importe **que** `zcrud_responsive`
/// (pour l'enum `ZWindowSizeClass`, l'ENTRÉE de [resolve]) — **aucun**
/// `import 'package:flutter/...'`, **aucun** `BuildContext`. La liaison
/// `context → largeur → ZWindowSizeClass` est faite **en amont** par l'appelant
/// (via `ZWindowSizeClass.of(context)` d'EX-UI.1 — le présentateur EX-UI.6),
/// jamais par la politique.
library;

import 'package:zcrud_responsive/zcrud_responsive.dart' show ZWindowSizeClass;

import 'z_edition_presentation.dart';
import 'z_form_weight.dart';

/// Signature d'une règle de dérivation `ZWindowSizeClass (+ ZFormWeight) →
/// ZEditionPresentation`, injectable via [ZPresentationPolicy.from].
typedef ZPresentationResolver = ZEditionPresentation Function(
  ZWindowSizeClass sizeClass, {
  ZFormWeight formWeight,
});

/// Politique dérivant un [ZEditionPresentation] d'un `ZWindowSizeClass`.
///
/// **Injectable / surchargeable (AD-6/AD-4)** — trois voies, sans jamais figer
/// une constante ni une fonction top-level non substituable :
/// 1. le **défaut** prêt à l'emploi (`ZPresentationPolicy()` /
///    `const ZPresentationPolicy.material()`) portant le mapping Material 3 ;
/// 2. une **fabrique fonction** [ZPresentationPolicy.from] (règle custom **sans**
///    sous-classer) ;
/// 3. la **sous-classe** ([resolve] non-`final`, la classe n'est **jamais**
///    `sealed`).
///
/// **Mapping Material 3 par défaut** (AD-30) :
///
/// | `ZWindowSizeClass` | `ZFormWeight`   | → `ZEditionPresentation` |
/// |--------------------|-----------------|--------------------------|
/// | `compact`          | (indifférent)   | `sheet`                  |
/// | `medium`           | (indifférent)   | `dialog`                 |
/// | `expanded`         | `light` (défaut)| `dialog`                 |
/// | `expanded`         | `heavy`         | `page`                   |
///
/// Petit écran → **bottom-sheet** (ergonomie tactile) ; écran moyen → **dialog**
/// centrée ; grand écran → **dialog** pour un formulaire léger, **page** pleine
/// pour un formulaire lourd.
class ZPresentationPolicy {
  /// Politique **par défaut** (mapping Material 3 ci-dessus). `const`.
  const ZPresentationPolicy();

  /// Alias nommé `const` de la politique [ZPresentationPolicy] par défaut
  /// (mapping Material 3), pour un call-site explicite.
  const factory ZPresentationPolicy.material() = ZPresentationPolicy;

  /// Politique **custom** déléguant à [resolver] — permet à une app de fournir sa
  /// règle **sans** sous-classer (AD-6). Ex. `ZPresentationPolicy.from((c, {formWeight = ZFormWeight.light}) => ...)`.
  factory ZPresentationPolicy.from(ZPresentationResolver resolver) =
      _FnPresentationPolicy;

  /// Dérive le mode de présentation — **PURE**, **déterministe**, **sans
  /// `BuildContext`**, via **switch exhaustif** (les enums bornent le domaine,
  /// **jamais de `throw`** — AD-10/D5). `formWeight` par défaut = [ZFormWeight.light].
  ///
  /// Surchargeable (non-`final`) : une sous-classe peut fournir un autre mapping.
  ZEditionPresentation resolve(
    ZWindowSizeClass sizeClass, {
    ZFormWeight formWeight = ZFormWeight.light,
  }) =>
      switch (sizeClass) {
        ZWindowSizeClass.compact => ZEditionPresentation.sheet,
        ZWindowSizeClass.medium => ZEditionPresentation.dialog,
        ZWindowSizeClass.expanded => switch (formWeight) {
            ZFormWeight.light => ZEditionPresentation.dialog,
            ZFormWeight.heavy => ZEditionPresentation.page,
          },
      };
}

/// Implémentation d'injection légère : délègue [resolve] à un [ZPresentationResolver]
/// fourni (fabrique [ZPresentationPolicy.from]). Non exposée — c'est un détail.
class _FnPresentationPolicy extends ZPresentationPolicy {
  const _FnPresentationPolicy(this._resolver) : super();

  final ZPresentationResolver _resolver;

  @override
  ZEditionPresentation resolve(
    ZWindowSizeClass sizeClass, {
    ZFormWeight formWeight = ZFormWeight.light,
  }) =>
      _resolver(sizeClass, formWeight: formWeight);
}
