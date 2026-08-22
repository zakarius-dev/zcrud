---
title: zcrud_study
description: Orchestration de présentation du domaine étude — sections composables, cartes par défaut, génération de flashcards par IA, session de révision, partage.
---

# zcrud_study

## Rôle

`zcrud_study` est le paquet **satellite Flutter** de la capacité étude : il
porte la **présentation** — hub d'ajout de contenu, page-détail de dossier,
sections d'outils composables, cartes de rendu par défaut, génération de
flashcards par IA, édition en lot, session de révision assemblée, examens et
rappels, partage communautaire optionnel — sur le domaine pur exposé par
`zcrud_study_kernel`. Le patron structurant est celui des **sections
composables** : `ZStudyToolsSectionSpec` décrit *quoi* rendre, et
`ZSectionedStudyLayout` compose une liste de ces descripteurs en sections
indépendantes, chacune dans son propre sous-arbre de rebuild.

## Quand l'utiliser

- Pour construire l'**interface d'une application d'étude** — page de
  dossier, hub d'ajout, session de révision, génération de flashcards — en
  assemblant des sections plutôt qu'en réécrivant un layout monolithique,
  sans risquer le rafraîchissement global du bug historique (invariant
  [AD-2](../concepts/invariants.md#ad-2)).
- Pour brancher une **capacité IA** (génération de flashcards, de carte
  mentale, de podcast, résumé, explication) via un port neutre que votre
  application implémente avec son propre routeur, sans qu'aucun prompt ni
  clé ne transite par ce paquet.
- Pour activer le **partage communautaire optionnel** d'un dossier d'étude
  — liens révocables, adhésions, galerie publique, modération — protégé par
  une garde d'autorisation pure que votre backend doit répliquer.

## Quand ne pas l'utiliser

- Pour du **domaine pur d'étude** sans aucune UI (agrégation des tâches du
  jour, calcul de proximité d'un examen, registre de cascade) : passez
  directement par `zcrud_study_kernel`, qui n'a aucune dépendance Flutter.
- Pour le **moteur de révision** lui-même (runtimes, glisseur, notation,
  résumé) : c'est le rôle de `zcrud_session`, que ce paquet assemble en
  écran mais ne réimplémente pas.

## Navigation de sous-dossiers {#navigation-sous-dossiers}

`ZStudyFolderDetail` rend une navigation de fratrie **adaptative** : sidebar
redimensionnable au-delà de 600 dp de large, surface étroite en deçà. Tout y
passe par un **value-object opaque** (`ZSubfolderRef`) et un descripteur
(`ZSubfolderNavSpec`) : l'entité du kernel n'entre jamais dans la présentation,
et aucun libellé n'est composé par le paquet — ils sont tous **injectés, déjà
localisés**.

| Symbole | Rôle |
|---|---|
| `ZSubfolderRef` | Référence **opaque** d'un sous-dossier : `id` (valeur de sélection **et** clé de réordonnancement), `label` déjà localisé, `colorKey` opaque, `count`. Aucune `Color`, aucun `IconData`, aucune règle métier. |
| `ZSubfolderNavSpec` | Descripteur immuable de la navigation : la liste, les libellés, les seams d'item (`itemBuilder`, `itemActionBuilder`), le mode étroit, le placement de l'ajout, le réordonnancement, les bornes de largeur de la sidebar. |
| `ZSubfolderSidebar` | Surface **grand écran** : colonne, surbrillance par item, repli/déploiement, redimensionnement **borné** au drag, au clavier **et** par action sémantique, réordonnancement optionnel. Ne détient aucun état. |
| `ZSubfolderSelectorBar` | Surface **étroite par défaut** : une ligne pleine largeur ≥ 48 dp annonçant l'élément **courant**, dont la fratrie se déploie en **feuille modale** bornée à 80 % de la hauteur d'écran. |
| `ZSubfolderCompactSelector` | Surface étroite **historique** : rangée de puces défilant horizontalement. Même `itemBuilder` que la sidebar — une même spec a les mêmes capacités des deux côtés du seuil. |
| `ZSubfolderNarrowNav` | L'aiguillage sous le seuil : coquille de l'hôte, puis la surface du mode demandé. |
| `ZSubfolderSelectionController` | Pilotage **externe et optionnel** de la sélection (fil d'Ariane, recherche, lien profond). `null` ⇒ la page détient l'état comme avant. |
| `ZSubfolderNavRenderer` / `ZSubfolderNavRendererScope` / `ZSubfolderNavRenderRequest` | Port de rendu de **surface** et son injection — le patron de `ZListRenderer` : `null` est une réponse valide, le renderer est `const` et comparé par identité. |
| `zResolveSubfolderNav` | La chaîne de résolution **totale** : absence de scope, `renderer` nul, coquille qui décline ou coquille qui **lève** rendent tous la surface du socle. |

Trois points de contrat à connaître avant de déclarer une navigation.

**Le mode étroit par défaut est la barre de sélection**, pas la rangée de
puces. La raison est un défaut d'usage : dans une rangée défilante, un seul
balayage sort la sélection du champ visible et l'utilisateur perd le « où
suis-je ». La question posée est « lequel est actif ? » **avant** « lesquels
existent ? ». La rangée de puces reste déclarable
(`narrowMode: ZSubfolderNarrowMode.compact`), à l'identique de son rendu
historique. Conséquence de la feuille modale : la fratrie **flotte** au lieu
d'être poussée dans le flux — un hôte qui compensait un déploiement en ligne
(réserve de hauteur, défilement piloté, fermeture à la sélection) doit
**retirer sa compensation**.

**Un `itemBuilder` subit des contraintes différentes selon la surface.** Deux
axes orthogonaux voyagent jusqu'à lui, sans changer sa signature à trois
paramètres :

- `ZSubfolderLayoutMode` (`sidebar` / `compact`) dit quelles **contraintes de
  layout** l'item subit — en `compact`, la largeur n'est pas bornée : ni
  `Expanded`, ni `ListTile`, ni `Row` pleine largeur. Hors d'une surface zcrud,
  `ZSubfolderLayoutMode.of` replie sur `compact`, le seul mode dont les
  contraintes sont satisfaites partout ;
- `ZSubfolderSurface` (`sidebar` / `chips` / `selectorTrigger` /
  `selectorSheet`) dit **quelle surface** demande l'item — le déclencheur
  annonce l'élément courant et ne se sélectionne pas ; la feuille liste les
  choix. `boundsWidth` distingue la seule surface à largeur non bornée
  (`chips`). Les deux se lisent par `ZSubfolderLayoutScope`.

**Le placement dans une page à onglets est un axe indépendant du point de
rupture.** `ZSubfolderNavPlacement.withinTab` (défaut) construit la navigation
**dans** l'onglet Matériel — elle disparaît donc sur les autres onglets, comme
historiquement. `aboveTabs` la hisse au-dessus de la zone d'onglets : elle
devient le contexte de la page entière, et n'est pas dupliquée dans l'onglet.
Sous `aboveTabs`, **aucune sidebar n'est rendue, à aucune largeur** : le
créneau hissé reçoit une hauteur non bornée, dans laquelle la sidebar déployée
ne peut pas se rendre. La surface hissée est la bande étroite, et sa hauteur
mesurée est exposée en `kZSubfolderNavBandHeight` pour que l'hôte compose sa
déclaration à partir d'elle plutôt que de la recopier.

## Types clés

| Type | Rôle |
|---|---|
| `ZStudyToolsSectionSpec` / `ZSectionedStudyLayout` | Descripteur de section et échafaudage qui les rend comme des sous-arbres indépendants. |
| `ZStudyFolderDetail` | Page-détail d'un dossier : trois onglets — Matériel, Carnet (`notebookBuilder`, fourni par l'hôte), Progression — et navigation de sous-dossiers adaptative. |
| `ZFlashcardListView` / `ZFlashcardGenerationController` | Liste de flashcards à réordonnancement manuel, et flux de génération par IA. |
| `ZStudySessionView` / `ZStudySessionHost` | Corps composable et détenteur du runtime de la session de révision assemblée. |
| `ZItemActionsMenu` / `ZItemActionState` | Menu d'actions d'un élément d'étude — **grille de 3 colonnes par défaut** (`crossAxisCount`, `1` pour retrouver la colonne unique), rendu délégué au `ZMenuRenderer` du `ZMenuScope` ambiant. Une action porte son état (`absent` / `inProgress` / `present`) et un compte optionnel : la teinte signale l'existence de ce que l'action produit, le badge dit combien. |
| `ZStudySharingAcl` / `ZStudySharingPort` | Garde d'autorisation pure du partage, et le port neutre que l'application implémente. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_study/README.md) — installation, démarrage rapide, API complète.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — le patron kernel/satellite.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
