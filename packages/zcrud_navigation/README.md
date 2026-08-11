# zcrud_navigation

Infrastructure UI de navigation transverse pour zcrud : dérive la
présentation d'un formulaire d'édition du breakpoint courant, puis l'exécute
sur une surface adaptée (page pleine, feuille modale, dialog).

## Aperçu {#apercu}

`zcrud_navigation` pose le maillon manquant entre la largeur d'écran et la
surface de présentation d'un formulaire :

- **`ZEditionPresentation`** — le mode d'édition en **enum**
  (`page`/`sheet`/`dialog`), l'unique type de mode exposé.
- **`ZFormWeight`** — le poids d'un formulaire en **enum** (`light`/`heavy`),
  critère qui départage `expanded → dialog|page`.
- **`ZPresentationPolicy`** — dérive **purement** (sans `BuildContext`) un
  `ZEditionPresentation` d'un `ZWindowSizeClass` (fourni par
  `zcrud_responsive`), injectable/surchargeable, jamais `sealed`.
- **`ZFormPresenter`** / **`ZAdaptivePresenter`** — le port pluggable qui
  **exécute** le mode résolu (`Navigator.push`/`showModalBottomSheet`/
  `showDialog`), avec un défaut pur-Flutter, substituable par un binding
  (`ZGetFormPresenter` de `zcrud_get`, par exemple).
- **`presentEdition`** — le helper qui câble la chaîne complète, du
  breakpoint à la surface, en un seul appel.
- **`ZEditionChrome`** / **`ZEditionScaffold`** — un chrome interne opt-in
  (titre, actions, comportement d'en-tête adapté au mode).

Ce paquet dépend de `zcrud_core` et de `zcrud_responsive`. Il n'importe aucun
gestionnaire d'état ni routeur ; la politique de présentation elle-même est
pur-Dart (aucun `import 'package:flutter/...'`).

**Utilisez ce paquet** pour présenter un formulaire d'édition de façon
adaptative, sans écrire vous-même la règle breakpoint → surface.
**N'utilisez pas ce paquet** si votre application a déjà sa propre politique
de présentation figée et ne souhaite pas la dériver du breakpoint — le port
`ZFormPresenter` reste substituable dans tous les cas.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

Future<T?> openForm<T>(BuildContext context, WidgetBuilder builder) {
  return presentEdition<T>(
    context,
    builder: builder,
    formWeight: ZFormWeight.light,
  );
}
```

## Concepts clés {#concepts-cles}

- **Politique pure, exécution injectable (invariant [AD-6](../../docs/site/concepts/invariants.md#ad-6))** —
  `ZPresentationPolicy.resolve` ne lit jamais `BuildContext` ; l'exécution du
  mode résolu passe par le port `ZFormPresenter`, substituable via
  `ZFormPresenterScope` sans modifier `ZcrudScope` du cœur.
- **`forcedMode` court-circuite la chaîne** — quand il est fourni, ni la
  politique ni `ZWindowSizeClass.of(context)` ne sont consultés : aucune
  dépendance `MediaQuery` n'est enregistrée sur le call-site.
- **Feuille contrainte et encadrée** — en mode `sheet`, la largeur est
  bornée (`min(largeur × 0,9, 640 dp)`, le plafond M3 par défaut) et un cadre
  optionnel est peint, résolus par la chaîne **paramètre > jeton
  `ZcrudTheme.editionSheet*` > référence auditée**.
- **Chrome opt-in, garde d'identité d'arbre** — `presentEdition(chrome: null)`
  (le défaut) rend l'arbre strictement inchangé ; fournir un `ZEditionChrome`
  ajoute titre, actions et comportement d'en-tête propre au mode.
- **Inertie déclarée, jamais silencieuse** — chaque paramètre du port
  `ZFormPresenter` est soit honoré sur une surface, soit explicitement
  déclaré inerte ; la matrice complète est mesurée par une garde dédiée (voir
  ci-dessous), jamais recopiée à la main dans la dartdoc.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `presentEdition` | Helper de câblage complet : breakpoint → politique → mode → surface. |
| `ZEditionPresentation` / `ZFormWeight` | Enums purs de domaine : mode de présentation, poids de formulaire. |
| `ZPresentationPolicy` | Politique pure dérivant le mode d'un `ZWindowSizeClass`. |
| `ZFormPresenter` / `ZAdaptivePresenter` | Port pluggable d'exécution du mode, et son implémentation par défaut pur-Flutter. |
| `ZFormPresenterScope` | Seam d'injection du présentateur effectif. |
| `ZImplicitDismissControl` | Capacité optionnelle de contrôle des fermetures implicites d'une feuille. |
| `ZEditionChrome` / `ZEditionScaffold` | Descripteur et rendu du chrome interne opt-in (titre, actions, en-tête). |
| `ZEditionBodyFit` | Déclare si le corps du chrome défile lui-même ou a une hauteur intrinsèque. |
| `ZSheetFrameSpec` / `ZSheetFrameMode` | Surcharge et mode de la feuille contrainte et encadrée. |

## Cas limites et invariants {#cas-limites}

- Un presenter tiers qui n'implémente pas `ZImplicitDismissControl` est
  appelé tel quel par `present` : il n'aura ni marge de feuille contrainte,
  ni cadre, jamais d'exception (invariant AD-10).
- `useSafeArea` est inerte en mode `page` (aucune `SafeArea` insérée, mesuré
  et déclaré plutôt que supposé) ; `isDismissible` est inerte en `page` et
  `dialog`.
- Un mode ajouté un jour à `ZEditionPresentation` sans mise à jour de
  `ZEditionScaffold` retombe sur la forme `dialog`, la plus neutre, plutôt
  que de lever.
- `allowImplicitDismiss: false` et `isDismissible: false` sont orthogonaux :
  le premier neutralise le glissement, le second la barrière ; ils se
  composent sans se contredire.

## Voir aussi {#voir-aussi}

- Matrice de paramètres de `ZAdaptivePresenter` :
  [`doc/parameter-matrix-z-adaptive-presenter.md`](doc/parameter-matrix-z-adaptive-presenter.md).
- [zcrud_get](../zcrud_get/README.md) — implémentation manager du port
  `ZFormPresenter` (`ZGetFormPresenter`).
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
