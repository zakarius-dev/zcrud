# zcrud_responsive

Infrastructure UI responsive transverse de zcrud — deux échelles de mesure
qui coexistent délibérément (invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1)) : classe de fenêtre Material 3 et
valeur par breakpoint Bootstrap réutilisant le cœur.

## Aperçu {#apercu}

`zcrud_responsive` fournit les briques dont le reste de la couche
responsive a besoin : une **classe de fenêtre** ([ZWindowSizeClass], 3
paliers Material 3) pour un choix de présentation, une **valeur par
breakpoint** ([ZBreakpointValue]) bâtie sur l'enum `ZBreakpoint` déjà
fourni par `zcrud_core`, et deux widgets qui consomment ces primitives :
[ZResponsiveLayout] (aiguilleur de disposition) et [ZAdaptiveGrid] /
[ZReorderableAdaptiveGrid] (grille adaptative, éventuellement
réordonnable par glisser-déposer).

Ce paquet **dépend de `zcrud_core`** et **réutilise** ses primitives
responsives (`ZBreakpoint`, `ZResponsiveBreakpoints`, `ZResponsiveSpan`) —
il ne les redéclare jamais ; elles sont ré-exportées par confort. Il
n'importe aucun gestionnaire d'état, aucun routeur, aucun paquet
responsive tiers : la grille réordonnable est bâtie uniquement sur le SDK
Flutter (invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1)).

**Utilisez ce paquet** pour classer une largeur de fenêtre ou de
conteneur, porter une valeur d'authoring par palier fin (padding, span,
nombre de colonnes…), ou construire une grille d'items adaptative — avec
ou sans réordonnancement. **N'utilisez pas ce paquet** si vous cherchez la
grille 12 colonnes de formulaire (`ZResponsiveGrid`, dans `zcrud_core`) :
ce paquet-ci dispose des **cartes d'items**, pas des champs d'un
formulaire.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

// Résolution pure — sans BuildContext.
final cls = ZWindowSizeClass.fromWidth(700); // → ZWindowSizeClass.medium

// Helper contextuel (MediaQuery.sizeOf, jamais Get.width).
Widget windowLabel(BuildContext context) {
  final windowClass = ZWindowSizeClass.of(context);
  return Text('$windowClass');
}

// Valeur par breakpoint (cascade mobile-first) avec l'enum ZBreakpoint du cœur.
const padding = ZBreakpointValue<double>(xs: 8, md: 16, xl: 24);

// Aiguilleur de disposition, mesure LOCALE via LayoutBuilder.
Widget adaptiveLayout() => ZResponsiveLayout(
      compact: (context) => const Text('Compact'),
      expanded: (context) => const Text('Expanded'),
    );

// Grille adaptative : nombre de colonnes borné (≥ 1 garanti).
Widget cardsGrid(List<Widget> cards) => ZAdaptiveGrid(
      minItemWidth: 220,
      children: cards,
    );
```

## Concepts clés {#concepts-cles}

- **Deux échelles orthogonales, aucune ne remplace l'autre** —
  [ZWindowSizeClass] (M3, 600/840, 3 paliers) **classe la fenêtre** pour un
  choix de présentation ; [ZBreakpointValue] (Bootstrap,
  576/768/992/1200, 5 paliers, réutilisé de `zcrud_core`) porte une
  **valeur d'authoring par palier fin**. Les fusionner forcerait soit une
  perte de granularité, soit une politique à cinq branches.
- **Mesure locale, jamais globale** — [ZResponsiveLayout] et
  [ZAdaptiveGrid] mesurent la largeur **du conteneur** (`LayoutBuilder`),
  jamais `MediaQuery.sizeOf`/`Get.width` : la bonne disposition est
  obtenue en split-view, master-detail ou colonne d'une `Row`, où la
  largeur du widget diffère de la largeur écran.
- **Rebuild ciblé (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** — [ZReorderableAdaptiveGrid] tient son
  ordre optimiste dans un `ValueNotifier` **local** ; réordonner ne
  reconstruit ni le parent ni la page. Aucun gestionnaire d'état.
- **Grille réordonnable sans paquet tiers (invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1))** — le glisser-déposer
  multi-colonnes est bâti uniquement sur `LongPressDraggable`/
  `DragTarget`/`Scrollable` du SDK ; une alternative accessible (actions
  sémantiques « déplacer avant »/« déplacer après ») couvre le lecteur
  d'écran, qui ne peut pas déclencher un appui long.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZWindowSizeClass` | Classe de fenêtre Material 3 en enum (`compact`/`medium`/`expanded`) ; résolution pure et helper `of(context)`. |
| `ZWindowSizeThresholds` | Seuils de largeur (dp) des paliers M3 : `mediumMinWidth` (600), `expandedMinWidth` (840). |
| `ZBreakpointValue<T>` | Valeur générique par breakpoint (cascade mobile-first), bâtie sur l'enum `ZBreakpoint` de `zcrud_core`. |
| `ZBreakpoint` / `ZResponsiveBreakpoints` / `ZResponsiveSpan` | Ré-exportés par confort depuis `zcrud_core` — jamais redéclarés ici. |
| `computeCrossAxisCount` | Fonction pure : nombre de colonnes borné (`≥ 1` garanti) à partir d'une largeur disponible. |
| `ZResponsiveLayout` | Aiguilleur à 3 builders (compact/medium/expanded) en cascade descendante. |
| `ZAdaptiveGrid` | Grille d'items adaptative — constructeur historique (`children:`) et constructeur virtualisé (`.builder`). |
| `ZReorderableAdaptiveGrid` | La même grille, réordonnable par appui long, avec alternative sémantique accessible. |
| `ZDefaultReorderRenderer` | Implémentation de repli, zéro-dépendance, du port `ZReorderRenderer` de `zcrud_core`. |

## Cas limites et invariants {#cas-limites}

- **Défauts sûrs, jamais de throw (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** — `computeCrossAxisCount` absorbe
  toute entrée dégénérée (largeur/espacement négatifs, `NaN`, infini,
  `minColumns` incohérent) et retombe toujours sur un plancher `≥ 1`.
  `ZWindowSizeClass.fromWidth` ne lève jamais : `0`, une largeur négative ou
  `double.nan` retombent sur `compact`.
- **Grille vide** — `ZAdaptiveGrid` avec `children` vide ou `.builder` avec
  `itemCount <= 0` rend `SizedBox.shrink()` avant tout `LayoutBuilder` /
  `GridView` : jamais de grille fantôme ni de division par zéro.
- **Échec de `onReorder` (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** — si le callback lève de façon
  synchrone, `ZReorderableAdaptiveGrid` restaure l'ordre affiché à
  l'identique ; un échec asynchrone (persistance) doit être signalé par
  l'hôte en repoussant l'ancien `itemIds`, ce qui resynchronise la grille.
- **RTL (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** — le nombre de colonnes est identique sous
  `Directionality.ltr` et `.rtl` à largeur égale ; `padding` accepte
  `EdgeInsetsDirectional`.
- **Non combiné avec la virtualisation** — `ZReorderableAdaptiveGrid` est
  **eager** (comme le constructeur historique de `ZAdaptiveGrid`) : une
  cellule non construite ne peut pas être une cible de dépôt. Réordonner et
  virtualiser sont donc exclusifs.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_responsive.md`](../../docs/site/paquets/zcrud_responsive.md)
- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_core` — `ZBreakpoint`/`ZResponsiveBreakpoints`, la grille 12 colonnes `ZResponsiveGrid`, le port `ZReorderRenderer`.
- `zcrud_ui_kit` — kit de widgets UI transverses complémentaire (états de contenu, confirmation, page-shell).

## Licence {#licence}

MIT — voir la racine du dépôt.
