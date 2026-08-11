# zcrud_reorder

Implémentation opt-in du port `ZReorderRenderer` de `zcrud_core`, adossée au
paquet `reorderable_grid_view`, pour le réordonnancement **interne** d'une
collection par glisser-déposer.

## Aperçu {#apercu}

`zcrud_reorder` est un satellite **opt-in** : il ne contient qu'un adaptateur
du port `ZReorderRenderer` déclaré dans `zcrud_core`. « Réordonner » désigne
ici le déplacement d'un élément **au sein** d'une collection déjà affichée
(glisser une carte dans une grille) — à ne pas confondre avec le dépôt
**natif** de contenu venu du système ou d'une autre application, qui est le
rôle de `zcrud_dnd`. Les deux capacités sont délibérément séparées : elles
n'ont ni le même geste, ni le même coût de build.

Le port a un défaut zéro-dépendance (`ZDefaultReorderRenderer`, dans
`zcrud_responsive`) : ne pas installer ce paquet laisse le réordonnancement
**fonctionnel**, seulement rendu par une implémentation plus simple. Les deux
implémentations sont interchangeables — même convention d'index linéaires,
même voie accessible non gestuelle, même repli défensif.

**Utilisez ce paquet** si vous préférez le rendu de `reorderable_grid_view`
au repli par défaut de `zcrud_responsive`. **N'utilisez pas ce paquet** pour
recevoir des dépôts venus du système (`zcrud_dnd`) ni si le repli par défaut
vous suffit déjà.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_reorder/zcrud_reorder.dart';

Widget buildApp(Widget child) {
  return ZcrudScope(
    reorderRenderer: const ZPackageReorderRenderer(),
    child: child,
  );
}
```

## Concepts clés {#concepts-cles}

- **Convention d'index linéaire** — le port attend un couple
  `(oldIndex, newIndex)` déjà en convention `removeAt`/`insert`. La convention
  brute émise par `reorderable_grid_view` est **déjà** dans cette forme (à la
  différence de `ReorderableListView`, qu'il ne faut surtout pas ré-ajuster) :
  la normalisation ne fait donc que clamper les index et éliminer les
  déplacements sur place.
- **Voie non gestuelle obligatoire (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** —
  `reorderable_grid_view` n'offre que l'appui long, inatteignable au lecteur
  d'écran. Ce paquet ajoute deux `CustomSemanticsAction` (« déplacer avant »
  / « déplacer après ») autour de chaque cellule, avec un libellé localisé de
  repli si l'hôte n'en fournit pas.
- **Ordre optimiste et source de vérité côté appelant** — l'ordre affiché est
  mis à jour immédiatement au geste, puis restauré si `onReorder` lève
  (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10)) ; il se
  resynchronise sur `request.itemIds` dès que l'hôte repousse un nouvel ordre.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZPackageReorderRenderer` | Renderer réordonnable adossé à `reorderable_grid_view`, injecté via `ZcrudScope.reorderRenderer`. |
| `kDefaultMoveBeforeLabel` / `kDefaultMoveAfterLabel` | Libellés localisés de repli des actions sémantiques, si l'hôte n'en fournit pas. |

## Cas limites et invariants {#cas-limites}

- Une liste vide rend un espace nul (`SizedBox.shrink()`), jamais une grille
  fantôme ni une division par zéro dans le calcul de colonnes.
- Un `onReorder` qui lève restaure l'ordre affiché précédent — aucun crash de
  rendu au milieu d'un geste, aucun ordre incohérent laissé à l'écran.
- Le padding est résolu directionnellement (`Directionality.of(context)`),
  correct en RTL.
- Ce paquet et `ZDefaultReorderRenderer` (`zcrud_responsive`) sont
  interchangeables : un test d'interchangeabilité verrouille leur convention
  commune.

## Voir aussi {#voir-aussi}

- [zcrud_dnd](../zcrud_dnd/README.md) — dépôt natif (système / autre
  application), capacité distincte de ce paquet.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
