# zcrud_list

Backend `SfDataGrid` du port `ZListRenderer` de zcrud, seule arête Syncfusion
du graphe — invariant [AD-8](../../docs/site/concepts/invariants.md#ad-8).

## Aperçu {#apercu}

`DynamicList` (déclaré dans `zcrud_core`) ne connaît que l'abstraction
`ZListRenderer` et des modèles neutres, sans dépendance Flutter tierce. Ce
paquet fournit le rendu concret `ZSfDataGridRenderer`, adossé à Syncfusion
`SfDataGrid` : c'est la **seule** arête Syncfusion du graphe zcrud pour la
liste. Un consommateur qui n'importe pas `zcrud_list` (par exemple
`zcrud_markdown` seul) ne tire donc aucune dépendance Syncfusion.

Le renderer mémoïse sa `DataGridSource` et son `DataGridController` : ni le
scroll ni la sélection ne sont perdus au rebuild, au scroll ou au changement
de page — la source est mise à jour **en place**, jamais reconstruite par
`build`.

**Utilisez ce paquet** pour rendre `DynamicList` avec la grille Syncfusion.
**N'utilisez pas ce paquet** si votre application n'a pas besoin de liste
(évitez la dépendance Syncfusion), ou si vous fournissez votre propre
implémentation de `ZListRenderer`.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';

// Branche le renderer Syncfusion derrière le port neutre ZListRenderer.
const ZListRenderer renderer = ZSfDataGridRenderer();
```

## Concepts clés {#concepts-cles}

- **Parité écran/fichier** — chaque cellule est rendue avec le même
  formateur pur que l'export (`col.format(row.cells[col.name])`), une seule
  source de vérité de mise en forme.
- **Sélection bidirectionnelle keyée par `id`** — la sélection Syncfusion est
  synchronisée depuis `ZListInteraction.selectedIds` et remontée via
  `onSelectionChanged`, toujours par l'identifiant stable de la ligne, jamais
  par sa position affichée.
- **Pagination automatique opt-in** — `onLoadMore` déclenche le
  `loadMoreViewBuilder` natif de Syncfusion quand le scroll atteint la fin ;
  `null` (défaut) ne pose aucun builder, comportement strictement inchangé
  pour un hôte qui ne l'utilise pas.
- **Réglages additifs à défaut inchangé** — `headerRowHeight`,
  `columnWidthMode`, `withOrderNumber`, `orderColumnHeader` et
  `cellColorBuilder` sont tous des paramètres optionnels dont le défaut
  reproduit exactement le rendu historique.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZSfDataGridRenderer` | Implémentation concrète de `ZListRenderer`, injectable via `ZcrudScope.listRenderer`. |

## Cas limites et invariants {#cas-limites}

- Cible tactile minimale de 48 dp sur les cellules et les boutons d'action
  (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13)).
- `cellColorBuilder` ne doit jamais lever ; une exception de l'appelant est
  propagée telle quelle, sans absorption silencieuse.
- Une closure `actionsFor` recréée à chaque `build` (ex. à chaque changement
  de sélection) est rafraîchie sans reconstruire les lignes de la grille :
  cocher une case ne reconstruit jamais toute la source.
- Aucune clé ni licence Syncfusion n'est enregistrée par ce paquet :
  `SyncfusionLicense.registerLicense` reste une configuration de
  l'application hôte.

## Voir aussi {#voir-aussi}

- [zcrud_export](../zcrud_export/README.md) — export tabulaire partageant le
  même formateur de colonne.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
