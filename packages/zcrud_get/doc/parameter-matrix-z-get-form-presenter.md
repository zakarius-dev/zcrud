<!-- GÉNÉRÉ — NE PAS ÉDITER À LA MAIN. -->
<!-- Source : packages/zcrud_get/test/support/z_get_presenter_parameter_matrix.dart -->
<!-- Garde de synchronisation : packages/zcrud_get/test/z_get_presenter_parameter_matrix_test.dart -->

# Matrice paramètre × mode — `ZGetFormPresenter`

Répond à la question posée par CR-IFFD-78 : **« ce paramètre agit-il sur ce mode ? »**, sans ouvrir le `switch`.

🔴 **Aucun statut n'est écrit ici, ni nulle part.** Chaque cellule est le résultat d'une **mesure différentielle** : la même surface est présentée deux fois — une fois avec tous les défauts du port, une fois en ne changeant **que** ce paramètre — et l'on compare la même empreinte dans les deux cas (contraintes reçues par le contenu, encart de sécurité restant, rectangle rendu, `enableDrag` et `shape` du `BottomSheet`, effet d'un tap hors surface).

> `honoré` ⇔ les deux empreintes **diffèrent**. `inerte` ⇔ elles sont **identiques**.

Annoncer « honoré » un paramètre que la branche ne lit pas est donc **inexprimable** — il n'y a pas de déclaration à falsifier. Et la garde exige qu'aucun paramètre ne soit inerte sur les trois modes : un couple de valeurs incapable de produire une différence se ferait remarquer au lieu de se déguiser en « inerte ».

| Paramètre | Valeur contraire sondée | `page` | `sheet` | `dialog` |
|---|---|---|---|---|
| `maxWidth` | `160.0` (défaut : `null`) | inerte | honoré | honoré |
| `maxHeight` | `120.0` (défaut : `null`) | inerte | honoré | honoré |
| `useSafeArea` | `false` (défaut : `true`) | inerte | honoré | honoré |
| `barrierDismissible` | `false` (défaut : `true`) | inerte | inerte | honoré |
| `allowImplicitDismiss` | `false` (défaut : `true`) | inerte | honoré | inerte |
| `isDismissible` | `false` (défaut : `true`) | inerte | honoré | inerte |
| `sheetFrame` | `ZSheetFrameSpec(mode: never, widthRatio: 1, maxWidth: infinity)` (défaut : `null`) | inerte | honoré | inerte |

## Portée

Ce document couvre **`ZGetFormPresenter`** (`packages/zcrud_get/lib/src/presentation/z_get_form_presenter.dart`), et lui seul. L'autre implémentation du port livrée par le dépôt a sa propre matrice, mesurée par sa propre garde :

* `ZAdaptivePresenter` → `packages/zcrud_navigation/doc/parameter-matrix-z-adaptive-presenter.md` ;
* `ZGetFormPresenter` → `packages/zcrud_get/doc/parameter-matrix-z-get-form-presenter.md`.

Recensement (grep sur `packages/` et `example/`, 2026-08-09) : **deux** implémentations en `lib/` dans tout le dépôt, celles ci-dessus. `zcrud_riverpod` et `zcrud_provider` n'en portent aucune (grep négatif, `rc=1`, sur `ZFormPresenter|ZImplicitDismissControl|zcrud_navigation`). Une implémentation **tierce** du port n'est tenue par aucune de ces gardes : elle doit publier sa propre matrice.

## Comment lire une case « inerte »

« Inerte » ne veut pas dire « bug ». Trois inerties sont **structurelles** et le resteront : une route pleine n'a pas de barrière, un dialogue ne se glisse pas, et `sheetFrame` ne décrit qu'une feuille. Ce que la règle interdit, c'est l'inertie **silencieuse** : chaque case de ce tableau est mesurée, et le dartdoc du port ne promet rien qu'une case dise inerte.

🔴 `useSafeArea` en mode `page` est le cas signalé par CR-IFFD-78 ①. Mesuré : une route pleine n'insère **aucune** `SafeArea`, ni avec `true` (le défaut) ni avec `false` — le contenu brut peint sous l'encoche dans les deux cas. Honorer la promesse déplacerait donc l'arbre **par défaut** de tout hôte passif ; la promesse a été **retirée du dartdoc** à la place, et cette case l'atteste. Un hôte qui veut l'encart en `page` place sa propre `SafeArea`, ou fournit un `ZEditionChrome` (la voie chrome monte un `Scaffold` + `SliverAppBar`, qui consomme l'encart haut, et une `SafeArea(top: false)` sous les actions).
