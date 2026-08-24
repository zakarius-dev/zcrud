---
title: zcrud_reorder
description: Réordonnancement interne opt-in par glisser-déposer pour zcrud, adossé à reorderable_grid_view.
---

# zcrud_reorder

## Rôle

`zcrud_reorder` est l'implémentation opt-in du port `ZReorderRenderer` de
`zcrud_core` : il réordonne une collection **interne** à l'application par
glisser-déposer, adossé au paquet tiers `reorderable_grid_view`. Le port a un
défaut zéro-dépendance dans `zcrud_responsive` ; les deux implémentations
sont interchangeables.

## Quand l'utiliser

- Pour réordonner une grille d'éléments par glisser-déposer, avec une voie
  accessible non gestuelle intégrée.
- Quand le rendu de `reorderable_grid_view` est préféré au repli par défaut
  de `zcrud_responsive`.
- Pour **enrichir le réordonnancement des sous-listes du moteur d'édition**
  sans toucher au schéma : l'injection au scope suffit (voir ci-dessous).

## Quand ne pas l'utiliser

- Pour recevoir un dépôt venu du système ou d'une autre application : c'est
  le rôle de `zcrud_dnd`, une capacité distincte.
- Si le repli zéro-dépendance de `zcrud_responsive` suffit déjà : ce paquet
  reste un choix, jamais une obligation.

## Le port a un consommateur de premier plan : la sous-liste {#sous-liste}

Le champ `subItems` du moteur d'édition réordonne ses lignes par
**glisser-déposer** — poignée de tête ≥ 48 dp, doublée d'**actions sémantiques
de déplacement** par ligne, qui restent la voie non gestuelle. C'est le port
`ZReorderRenderer` qui rend cette liste, donc **votre implémentation** dès
qu'elle est injectée :

```dart
ZcrudScope(
  reorderRenderer: const ZPackageReorderRenderer(),
  child: monFormulaire,
);
```

Sans injection, rien ne manque : `zcrud_core` porte un **repli interne**
zéro-configuration qui tient le contrat du port — index linéaires, actions
sémantiques, réconciliation par clé (l'état et le focus d'une ligne déplacée
survivent), échec de persistance signalé et non fatal. C'est le **plancher
fonctionnel**, pas l'idéal : une seule colonne, aucun autoscroll.

Ce que l'injection apporte, implémentation par implémentation :

| | Repli interne du cœur | `ZDefaultReorderRenderer` (`zcrud_responsive`) | `ZPackageReorderRenderer` (ce paquet) |
|---|---|---|---|
| Dépendance tirée | aucune | aucune (SDK seul) | `reorderable_grid_view` |
| Disposition | une colonne | colonnes adaptatives | colonnes adaptatives |
| Geste de glissement | dès le contact de la poignée | appui long | appui long, délai réglable (`dragStartDelay`), voie gestuelle débrayable (`dragEnabled`) |
| Autoscroll pendant le glissement | non | oui, sur le `Scrollable` englobant, seuils réglables | assuré par le paquet tiers |
| Ordre optimiste, restauré si l'écriture échoue | non — l'ordre affiché reste celui de l'appelant | oui | oui |
| Animations de déplacement des cellules | non | non | oui |

Autrement dit : **quitter le repli interne** se paie surtout en autoscroll et en
disposition adaptative, et les deux satellites y répondent. **Choisir celui-ci
plutôt que le défaut zéro-dépendance** s'achète en animations de déplacement et
en réglages de geste, contre une dépendance tierce de plus — un arbitrage, pas
une montée en gamme automatique.

**Le geste change avec le renderer, la voie accessible non.** Le repli interne
démarre le glissement au contact de la poignée ; les deux satellites apportent
leur propre châssis, dont le geste est l'**appui long sur la ligne** — la
poignée y reste l'affordance visible. Les **actions sémantiques de déplacement**,
elles, sont exigées par le contrat du port : elles sont présentes dans les trois
cas, et c'est ce qui rend les implémentations interchangeables sans régression
d'accessibilité.

Le réordonnancement d'une sous-liste se déclare par ailleurs sur le schéma
(`ZSubListConfig.reorderable`), et une déclaration à `false` ferme la capacité
**même avec un renderer injecté**. Le détail de la sous-liste est documenté avec
le moteur d'édition : voir [zcrud_core](zcrud_core.md).

## Types clés

| Type | Rôle |
|---|---|
| `ZPackageReorderRenderer` | Seul point d'entrée du paquet, injecté via `ZcrudScope.reorderRenderer`. |
| `kDefaultMoveBeforeLabel` / `kDefaultMoveAfterLabel` | Repli des libellés des actions sémantiques de déplacement quand l'hôte n'en fournit pas — deux littéraux **français** (`'Déplacer avant'` / `'Déplacer après'`), pas des clés résolues par la l10n. Une application non francophone déclare les siens plutôt que de subir ce repli. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_reorder/README.md) — installation, démarrage rapide, API complète.
- [zcrud_responsive](zcrud_responsive.md) — `ZDefaultReorderRenderer`, le défaut zéro-dépendance du même port.
- [zcrud_core](zcrud_core.md) — le port `ZReorderRenderer` et la sous-liste du moteur d'édition.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
