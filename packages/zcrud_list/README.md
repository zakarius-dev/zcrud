# zcrud_list

Ce paquet **n'est pas « l'écran de liste »** : il est le **backend de rendu
Syncfusion** du port `ZListRenderer` — la seule arête Syncfusion du graphe,
invariant [AD-8](../../docs/site/concepts/invariants.md#ad-8). Pour un écran
CRUD complet et assemblé (liste + création + édition + corbeille), voir
[`zcrud_screen`](../zcrud_screen/README.md) ; `zcrud_list` est ce que l'on
**injecte** derrière lui pour que ses tableaux soient rendus par
`SfDataGrid`.

## Aperçu {#apercu}

`DynamicList` (déclaré dans `zcrud_core`) ne connaît que l'abstraction
`ZListRenderer` et des modèles neutres, sans dépendance Flutter tierce. Ce
paquet fournit le rendu concret `ZSfDataGridRenderer`, adossé à Syncfusion
`SfDataGrid` : c'est la **seule** arête Syncfusion du graphe zcrud pour la
liste. Un consommateur qui n'importe pas `zcrud_list` (par exemple
`zcrud_markdown` seul) ne tire donc aucune dépendance Syncfusion.

Le paquet dépend de `zcrud_core` (modèles neutres, port, localisation) et de
`zcrud_ui_kit` (toaster injecté servant le retour visuel de la copie de
cellule) ; ces deux arêtes laissent le graphe acyclique et `zcrud_core` sans
dépendance sortante.

Le renderer mémoïse sa `DataGridSource` et son `DataGridController` : ni le
scroll ni la sélection ne sont perdus au rebuild, au scroll ou au changement
de page — la source est mise à jour **en place**, jamais reconstruite par
`build`.

**Utilisez ce paquet** pour rendre les tableaux de `DynamicList` (ou de
`zcrud_screen` en layout tableau) avec la grille Syncfusion.
**N'utilisez pas ce paquet** si votre application n'a pas besoin de liste
tabulaire (évitez la dépendance Syncfusion), si vous cherchez l'écran CRUD
assemblé (c'est `zcrud_screen`), ou si vous fournissez votre propre
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

Tous les réglages ci-dessous sont **des paramètres nommés optionnels** du même
constructeur `const` : omis, ils rendent exactement la grille par défaut.

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';

const ZListRenderer richRenderer = ZSfDataGridRenderer(
  rowsPerPage: 25, // pager numéroté sous la grille
  copyCellOnLongPress: true, // long-press = copie de la valeur affichée
  swipeToRevealActions: true, // swipe = actions de ligne déjà résolues
  allowColumnResizing: true, // l'utilisateur ajuste les largeurs
  adaptiveRowHeight: true, // les lignes grandissent avec leur contenu
  maxRowHeight: 160,
);
```

## Concepts clés {#concepts-cles}

- **Backend de rendu, pas écran** — ce paquet ne porte ni barre d'application,
  ni recherche, ni navigation vers l'édition : il transforme un
  `ZListRenderRequest` neutre en widget de grille. L'écran est
  [`zcrud_screen`](../zcrud_screen/README.md), la liste déclarative est
  `DynamicList` dans `zcrud_core`.
- **Parité écran/fichier** — chaque cellule est rendue avec le même
  formateur pur que l'export (`col.format(row.cells[col.name])`), une seule
  source de vérité de mise en forme. C'est aussi ce texte formaté — jamais la
  valeur brute — qui part au presse-papiers lors d'une copie.
- **Sélection bidirectionnelle keyée par `id`** — la sélection Syncfusion est
  synchronisée depuis `ZListInteraction.selectedIds` et remontée via
  `onSelectionChanged`, toujours par l'identifiant stable de la ligne, jamais
  par sa position affichée.
- **Réglages additifs à défaut inchangé** — hormis la largeur de colonnes
  (ci-dessous), chaque paramètre a un défaut qui reproduit exactement le rendu
  d'origine : l'arbre de widgets d'un hôte qui n'active rien est strictement
  identique.

### Largeur de colonnes responsive {#largeur-responsive}

`columnWidthMode` est **nullable**. Laissé à `null` (défaut), le mode est
**dérivé** de la plateforme et du nombre de colonnes de données :

| Cible | Règle |
|---|---|
| Web et bureau | plus de 3 colonnes : `auto` ; sinon `fill` |
| Mobile | plus de 1 colonne : `auto` ; sinon `fill` |

Intuition : `fill` répartit la largeur disponible (agréable tant que les
colonnes sont peu nombreuses) ; au-delà du seuil il écrase les contenus, et
`auto` dimensionne alors chaque colonne sur son contenu en laissant le
défilement horizontal faire le reste.

Une valeur explicite **écrase** la dérivation. Pour figer la répartition en
`fill` quel que soit le nombre de colonnes :

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';

const ZListRenderer filled = ZSfDataGridRenderer(
  columnWidthMode: ColumnWidthMode.fill,
);
```

`ColumnWidthMode` est **ré-exporté par le barrel** du paquet : figer la
largeur — ou régler `ZSfColumnSizing.widthMode` — ne demande donc **aucune
dépendance Syncfusion** dans votre application. C'est le seul type Syncfusion
ré-exporté, parce que c'est le seul qui apparaisse dans la signature publique
du renderer ; les types de rendu (`SfDataGrid`, `GridColumn`, `DataGridRow`…)
restent internes au paquet.

La règle est aussi exposée comme fonction **pure** —
`ZSfDataGridRenderer.responsiveColumnWidthMode(visibleColumnCount:,
platform:, isWeb:)` — pour la rejouer ou la tester sans monter de widget.

### Pagination : deux mécanismes orthogonaux {#pagination}

- `onLoadMore` (`null` par défaut) branche le défilement infini natif de
  Syncfusion : le callback est déclenché quand le scroll vertical atteint la
  fin, un indicateur accessible s'affiche pendant l'attente. C'est le chemin
  d'une pagination **backend par curseur** ; l'hôte le câble typiquement sur
  `ZListController.loadMore()`.
- `rowsPerPage` (`null` par défaut) ajoute un **pager numéroté** sous la
  grille et ne rend que la tranche de la page courante. Il pagine **côté
  client** l'instantané déjà en mémoire. La virtualisation Syncfusion est
  conservée.

Les deux peuvent coexister, mais un hôte qui pagine côté backend n'a
normalement pas besoin du pager numéroté.

### En-têtes empilés et dimensionnement par colonne {#entetes-colonnes}

`stackedHeaders` (liste de lignes, de haut en bas ; vide par défaut) ajoute
des lignes d'en-tête au-dessus de l'en-tête normal, chaque groupe couvrant
plusieurs colonnes désignées par leur `name`. Les libellés sont des **clés
l10n** résolues au rendu, jamais du texte codé en dur.

`columnSizing` (map vide par défaut) applique un dimensionnement **par
colonne** : largeur fixe, minimum, maximum, mode de largeur spécifique, marge
d'auto-ajustement. Chaque champ est indépendant : une entrée partielle laisse
les autres réglages à leur valeur d'origine.

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';

const ZListRenderer grouped = ZSfDataGridRenderer(
  stackedHeaders: <List<ZSfStackedHeader>>[
    <ZSfStackedHeader>[
      ZSfStackedHeader(
        labelKey: 'invoice.amounts',
        columnNames: <String>['unitPrice', 'total'],
      ),
    ],
  ],
  columnSizing: <String, ZSfColumnSizing>{
    'label': ZSfColumnSizing(minimumWidth: 180),
    'total': ZSfColumnSizing(width: 120),
  },
);
```

### Style conditionnel de cellule {#style-cellule}

`cellStyleBuilder` (`null` par défaut) résout, pour chaque couple ligne ×
colonne, un `ZSfCellStyle` optionnel : fond, style de texte, alignement,
marge, alignement du texte, nombre maximal de lignes. Tous les champs sont
nullables — un style partiel ne touche que ce qu'il déclare, et rendre `null`
laisse la cellule au rendu par défaut. L'appelant dérive ses couleurs de son
thème ; ce paquet n'en code aucune.

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';

ZListRenderer emphasized(ColorScheme scheme) => ZSfDataGridRenderer(
      cellStyleBuilder: (ZListRow row, ZListColumn column) {
        if (column.name != 'total') return null;
        return ZSfCellStyle(
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          backgroundColor: scheme.errorContainer,
          textAlign: TextAlign.end,
        );
      },
    );
```

`cellColorBuilder` reste disponible et rétro-compatible : si les deux sont
fournis, le fond de `cellStyleBuilder` est prioritaire et retombe sur celui de
`cellColorBuilder` quand il n'en déclare pas.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZSfDataGridRenderer` | Implémentation concrète de `ZListRenderer`, injectable via `ZcrudScope.listRenderer`. |
| `ZSfCellStyle` | Style conditionnel d'une cellule (fond, texte, alignement, marge, `maxLines`). |
| `ZSfStackedHeader` | Groupe d'en-tête empilé : une clé l10n couvrant plusieurs colonnes. |
| `ZSfColumnSizing` | Dimensionnement d'une colonne (largeur, min, max, mode, marge d'auto-ajustement). |

Paramètres de `ZSfDataGridRenderer`, avec leur défaut :

| Paramètre | Défaut | Effet |
|---|---|---|
| `onLoadMore` | `null` (opt-in) | Défilement infini natif : aucun builder posé au défaut. |
| `headerRowHeight` | `48` | Hauteur de la ligne d'en-tête. |
| `columnWidthMode` | `null` (dérivé) | Mode de largeur ; `null` déclenche la dérivation responsive. |
| `withOrderNumber` | `false` (opt-in) | Raccourci de la colonne de numéro d'ordre, quand la requête n'en déclare pas (cf. ci-dessous). |
| `orderColumnHeader` | `'#'` | En-tête de la colonne de numéro d'ordre, pour ce raccourci. |
| `cellColorBuilder` | `null` (opt-in) | Couleur de fond par cellule, sur les types neutres. |
| `rowsPerPage` | `null` (opt-in) | Pager numéroté côté client ; aucun pager au défaut. |
| `copyCellOnLongPress` | `false` (opt-in) | Long-press d'une cellule : copie de la valeur formatée + toast. |
| `copiedMessageKey` | `'list.valueCopied'` | Clé l10n du message de copie ; repli sur la clé générique `copy`. |
| `swipeToRevealActions` | `false` (opt-in) | Swipe début→fin révélant les actions de ligne déjà résolues. |
| `swipeMaxOffset` | `null` (dérivé) | Offset maximal de swipe ; dérivé du nombre d'actions sinon. |
| `stackedHeaders` | `[]` (opt-in) | Lignes d'en-tête empilées, de haut en bas. |
| `columnSizing` | `{}` (opt-in) | Dimensionnement par nom de colonne. |
| `allowColumnResizing` | `false` (opt-in) | Redimensionnement des colonnes par l'utilisateur, largeurs persistées. |
| `adaptiveRowHeight` | `false` (opt-in) | Hauteur de ligne suivant le contenu, passage à la ligne des cellules. |
| `maxRowHeight` | `null` (opt-in) | Plafond de hauteur quand la hauteur adaptative est active. |
| `cellStyleBuilder` | `null` (opt-in) | Style conditionnel complet par cellule. |

### La colonne de numéro d'ordre suit l'écran {#colonne-ordre}

Le numéro d'ordre décrit une **position à l'écran**, pas une propriété de la
donnée : la première ligne affichée porte `1`, la deuxième `2`. Trier la grille
**renumérote** donc la colonne au lieu de promener les anciens numéros avec
leurs lignes.

Elle se déclare avec le reste du schéma, ce qui la rend disponible partout où la
requête voyage :

```dart
final request = ZListRenderRequest.fromSchema(
  fields,
  rows,
  policy: const ZColumnPolicy(
    ordinal: ZListOrdinal(enabled: true, header: 'N°', width: 64),
  ),
);
```

`withOrderNumber: true` reste le raccourci équivalent pour l'hôte qui construit
sa requête sans politique de colonnes ; la déclaration de la requête l'emporte
dès qu'elle est active, car elle porte aussi l'en-tête, la largeur et le
décalage de page.

**Avec un pager** (`rowsPerPage`), chaque page est numérotée à partir de `1` :
c'est le sens du décalage par défaut (`ZListOrdinal.pageOffset` à `0`), qui
numérote la page rendue. Pour une numérotation **continue** — la deuxième page
d'un pager de 20 lignes commençant à `21` — déclarez :

```dart
const ZListOrdinal(enabled: true, continuousAcrossPages: true);
```

C'est le rendu qui transmet alors la page qu'il peint à la règle du cœur. Le
détour par `pageOffset` ne pouvait pas y suffire : l'index de page du pager est
**privé au rendu**, l'hôte n'apprenait jamais qu'il avait changé. `pageOffset`
reste la voie de l'hôte qui découpe **lui-même** ses pages (pagination
applicative ou backend) : il connaît alors son index et déclare
`pageOffset: pageIndex * pageSize`. Les deux se composent.

## Cas limites et invariants {#cas-limites}

- **Un seul changement de défaut** dans ce paquet : `columnWidthMode`. Un hôte
  qui ne le passait pas obtenait `fill` en toute circonstance et obtient
  désormais `fill` en deçà du seuil, `auto` au-delà. L'échappatoire exacte est
  `columnWidthMode: ColumnWidthMode.fill`. Tous les autres réglages sont
  strictement additifs.
- `ColumnWidthMode` — le seul type Syncfusion présent dans la signature
  publique (`columnWidthMode`, `ZSfColumnSizing.widthMode`,
  `responsiveColumnWidthMode`) — est **ré-exporté par le barrel** : tout ce
  qui s'écrit sur le renderer s'écrit avec le seul import
  `package:zcrud_list/zcrud_list.dart`, sans déclarer de dépendance
  Syncfusion. Rien d'autre n'est ré-exporté : le paquet reste la seule arête
  Syncfusion du graphe
  ([AD-8](../../docs/site/concepts/invariants.md#ad-8)).
- L'offset de swipe **dérivé** suit la page courante quand un pager numéroté
  est monté : deux pages dont les lignes portent un nombre d'actions
  différent obtiennent chacune l'offset correspondant à ce qu'elles révèlent.
  Un `swipeMaxOffset` explicite reste, lui, appliqué tel quel.
- Cible tactile minimale de 48 dp sur les cellules, les boutons d'action et
  les actions révélées au swipe (invariant
  [AD-13](../../docs/site/concepts/invariants.md#ad-13)) ; la hauteur
  adaptative respecte ce plancher avant tout plafond.
- Le swipe **n'ouvre aucun second canal d'actions** : ce sont exactement les
  actions déjà résolues par l'ACL en amont, mêmes libellés, même état activé,
  mêmes callbacks. Sans résolveur d'actions, le swipe reste désactivé même
  demandé.
- La copie au long-press ne concerne ni la ligne d'en-tête ni les colonnes
  techniques (numéro d'ordre, actions) ; un échec du presse-papiers est
  absorbé sans toast de succès mensonger.
- Le message de copie utilise une clé qui n'est **pas** enregistrée dans
  `zcrud_core` : sans surcharge de libellés par l'hôte, le toast affiche le
  libellé générique « Copier ». Fournissez votre propre traduction pour un
  message dédié.
- `cellColorBuilder` et `cellStyleBuilder` ne doivent jamais lever ; une
  exception de l'appelant est propagée telle quelle, sans absorption
  silencieuse.
- Le redimensionnement interactif persiste les largeurs sans reconstruire la
  liste : la source mémoïsée et le contrôleur sont préservés, donc le scroll
  et la sélection aussi.
- Une closure de résolution d'actions recréée à chaque `build` (par exemple à
  chaque changement de sélection) est rafraîchie sans reconstruire les lignes
  de la grille : cocher une case ne reconstruit jamais toute la source.
- Aucune clé ni licence Syncfusion n'est enregistrée par ce paquet :
  `SyncfusionLicense.registerLicense` reste une configuration de
  l'application hôte.

## Voir aussi {#voir-aussi}

- [zcrud_screen](../zcrud_screen/README.md) — l'écran CRUD assemblé, à ne pas
  confondre avec ce backend de rendu.
- [zcrud_export](../zcrud_export/README.md) — export tabulaire partageant le
  même formateur de colonne.
- [Fiche du paquet](../../docs/site/paquets/zcrud_list.md) — résumé côté site.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
