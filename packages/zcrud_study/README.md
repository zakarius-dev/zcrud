# zcrud_study

Orchestration de présentation du domaine étude de zcrud — sections d'outils
composables (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))
sur le domaine pur exposé par `zcrud_study_kernel`.

## Aperçu {#apercu}

`zcrud_study` est le paquet **satellite Flutter** de la capacité étude, au
sens du patron [kernel/satellite](../../docs/site/concepts/architecture-hexagonale.md#le-patron-kernel-satellite) :
`zcrud_study_kernel` porte le domaine pur (agrégation des tâches du jour,
calcul de proximité des examens, registre de cascade), ce paquet porte la
**présentation** — hub de contenu, page-détail de dossier, sections d'outils
composables, génération de flashcards par IA, session de révision, partage
et modération.

Le patron structurant du paquet est celui des **sections composables** :
`ZStudyToolsSectionSpec` décrit *quoi* rendre (titre, compteur, items paginés
par `itemBuilder`, état vide, action d'ajout) sans jamais référencer un
modèle d'application ni une couleur codée en dur ; `ZSectionedStudyLayout`
rend une liste de ces descripteurs comme des sections **indépendantes**,
chacune dans son propre sous-arbre isolé (une frontière de widget par
section). Un dossier d'étude complet — rail de flashcards, grille de
documents, grille de notes, grille de cartes mentales — se compose en
assemblant des `ZStudyToolsSectionSpec`, jamais en réimplémentant un layout.

Ce paquet fournit aussi :

- des **cartes de rendu par défaut**, une par type de contenu (document,
  examen, flashcard, dossier, carte mentale, note), toutes composées à
  partir des mêmes primitives à slots (`ZStudyToolsItemCard`, `ZFolderCard`) ;
- la **génération de flashcards par IA** — contrôleur, feuille de
  génération, aperçu et confirmation de tags — dont l'option est
  structurellement absente sans port fourni par l'hôte ;
- l'**édition en lot de flashcards** en régime de brouillon déclaré, avec un
  commit unique injecté comme seul franchissement de la frontière de
  persistance ;
- une **page-détail de dossier** assemblant un page-shell, l'onglet
  Matériel, l'onglet Progression et une navigation de sous-dossiers
  adaptative ;
- un **écran de session de révision** assemblé au-dessus du moteur porté par
  `zcrud_session` ;
- le **partage communautaire optionnel** — liens révocables, adhésions,
  galerie publique, modération — protégé par une garde d'autorisation pure ;
- des **seams IA neutres** (explication, résumé, génération de carte
  mentale, génération de podcast) : ports purs que l'application hôte
  implémente avec son propre routeur IA, sans qu'aucun prompt, endpoint ou
  clé ne fuie dans ce paquet.

**Utilisez ce paquet** pour construire l'interface d'une application
d'étude — hub d'ajout, page de dossier, session de révision, génération de
flashcards — en assemblant des sections plutôt qu'en réécrivant un layout
monolithique. **N'utilisez pas ce paquet** si vous n'avez besoin que du
domaine pur (agrégation de tâches, calcul de proximité, cascade
kernel→satellite) sans aucune UI : passez directement par
`zcrud_study_kernel`, qui n'a aucune dépendance Flutter.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Assemble une page « study tools » à partir de trois sections
/// indépendantes — chacune dans son propre sous-arbre de rebuild.
Widget buildStudyToolsPage({
  required List<ZStudyToolsSectionSpec> sections,
}) {
  return ZSectionedStudyLayout(sections: sections);
}

/// Un descripteur de section minimal : titre, compteur, items paginés.
ZStudyToolsSectionSpec buildEmptySection() {
  return ZStudyToolsSectionSpec(
    id: 'documents',
    title: 'Documents',
    itemCount: 0,
    itemBuilder: (context, index) => const SizedBox.shrink(),
    emptyState: const Text('Aucun document'),
  );
}
```

## Concepts clés {#concepts-cles}

- **Sections composables et rebuilds granulaires (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  chaque `ZStudyToolsSectionSpec` obtient sa propre frontière de widget
  (`ValueKey('section:$id')`) dans `ZSectionedStudyLayout` : ajouter,
  réordonner ou faire évoluer une section ne reconstruit jamais les autres.
  La même discipline s'applique à `ZStudyToolsPage` et à
  `ZStudyFolderDetail` : taper dans un champ scopé, changer la sélection de
  sous-dossier ou plier la sidebar ne reconstruit que la tranche concernée.
- **Composition par slots, jamais par héritage (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4))** —
  les cartes par défaut, la page-détail et les feuilles composables exposent
  des slots nullables : absent, l'emplacement est rendu par défaut ; fourni
  et rendant `null`, il est structurellement retiré de l'arbre — jamais un
  espace réservé vide ni une capacité grisée.
- **Rendu par défaut à props primitives, jamais l'entité domaine** —
  `ZFolderCard`, `ZDefaultFlashcardCard` et les autres cartes ne reçoivent
  que des primitives (titre, clé de couleur) et des slots : elles ne
  connaissent aucun type métier ni règle de permissions, pour rester
  réutilisables par n'importe quel hôte.
- **Seams IA neutres (invariant [AD-12](../../docs/site/concepts/invariants.md#ad-12))** —
  les ports de génération et d'explication ne portent que du contenu source
  neutre ; prompts, endpoints et clés restent entièrement côté application.
  Une capacité IA sans port fourni est absente de l'interface, jamais un
  bouton désactivé.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **Sections et layout** | |
| `ZStudyToolsSectionSpec` | Descripteur immuable d'une section de la page « study tools ». |
| `ZSectionedStudyLayout` / `ZSectionedStudySliver` | Rend une liste de sections indépendantes, en boîte ou en sliver, depuis la même source de contenu. |
| `ZStudyToolsPage` | Page qui assemble des sections via `ZSectionedStudyLayout`. |
| `ZStudyToolsItemCard` | Carte d'item de base à slots, partagée par les cartes par défaut. |
| **Page-détail et navigation** | |
| `ZStudyFolderDetail` | Page-détail d'un dossier : onglets Matériel/Progression, navigation de sous-dossiers adaptative. |
| `ZSubfolderRef` / `ZSubfolderNavSpec` | Référence opaque et descripteur agrégé de la navigation de sous-dossiers. |
| `ZSubfolderSidebar` / `ZSubfolderCompactSelector` | Les deux briques de navigation adaptative (grand écran / petit écran). |
| **Cartes par défaut** | |
| `ZDefaultDocumentCard` / `ZDefaultNoteCard` / `ZDefaultFlashcardCard` / `ZDefaultExamCard` / `ZDefaultMindmapCard` / `ZDefaultFolderCard` | Rendu par défaut d'un item, un par type de contenu. |
| **Flashcards** | |
| `ZFlashcardListView` | Liste de flashcards : recherche, filtres, tri, ordre manuel, sélection multiple opt-in. |
| `zReorderFlashcards` / `zReorderIds` | Voie unique de réordonnancement manuel. |
| `ZFlashcardGenerationController` / `ZFlashcardGenerationSheet` | Flux de génération de flashcards par IA. |
| `ZMultiFlashcardEditor` / `ZMultiFlashcardEditorController` | Édition en lot en régime de brouillon déclaré. |
| `zFlashcardCascadeDeleteRoot` | Seam de suppression cascadée (carte puis purge de répétition espacée). |
| **Hub de contenu** | |
| `ZContentHubLauncher` / `ZContentHubScope` | Configuration et portée du hub d'ajout de contenu, partagées entre plusieurs `+`. |
| `ZContentHubSheet` | Rendu de la feuille du hub. |
| **Session de révision** | |
| `ZStudySessionView` / `ZStudySessionHost` / `ZStudySessionScaffold` | Corps composable, détenteur du runtime, enveloppe de page de la session de révision. |
| **Examens et tâches du jour** | |
| `ZExamEditor` / `ZExamRemindersSection` | Édition d'examen et rappels approchants dérivés, exposés à l'application pour la planification. |
| `ZDailyTasksView` | Vue agrégée des tâches du jour (cartes dues, examens). |
| **Partage et modération** | |
| `ZStudySharingPort` / `ZStudyModerationPort` | Ports neutres de partage et de modération. |
| `ZStudySharingAcl` | Garde d'autorisation pure des champs de contrôle d'un dossier partagé. |
| `ZShareLink` / `ZStudyMembership` / `ZPublicStudyFolder` / `ZStudyFolderReport` | Entités de partage contrôlées par le propriétaire. |
| **Seams IA neutres** | |
| `ZAiExplanationPort` / `ZNoteSummaryPort` / `ZMindmapGenerationPort` / `ZPodcastGenerationPort` | Ports d'explication, de résumé, de génération de carte mentale et de podcast. |
| `ZFlashcardGenerationPort` | Port de génération de flashcards ; `z_flashcard_generation_defaults` porte le bornage et la répartition par type. |

## Cas limites et invariants {#cas-limites}

- **Un champ absent reste absent, jamais un espace réservé** — un slot,
  une action ou une capacité IA sans port fourni est retirée de l'arbre par
  composition, jamais rendue grisée ni remplacée par un espace vide
  (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4)).
- **La révocation d'un lien de partage est monotone** — un contributeur ne
  peut jamais dé-révoquer un lien ni muter un champ de contrôle
  (propriété, listing public, rôle) : seul le propriétaire le peut, via
  `ZStudySharingAcl.canMutateControl`. L'application hôte doit répliquer
  cette même règle dans ses propres règles de sécurité serveur — la garde
  locale ne protège pas seule un store distant.
- **Aucun état personnel dans les entités de partage** — répétition
  espacée, ordre personnel et position de lecture ne voyagent jamais dans
  `ZShareLink`, `ZStudyMembership` ni `ZPublicStudyFolder`.
- **Désérialisation défensive (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  toutes les entités de ce paquet sont écrites à la main et ne lèvent
  jamais à la lecture : un champ absent, corrompu ou d'un type inattendu
  retombe sur un défaut sûr, jamais une exception qui ferait échouer le
  dossier parent.
- **Accessibilité et RTL (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** —
  toute cible tactile fait ≥ 48 dp en géométrie rendue, tout est
  directionnel (`EdgeInsetsDirectional`, `TextAlign.start`), et l'absence
  d'activation d'une carte est structurelle (aucun `InkWell` inerte, aucun
  rôle `button` annoncé) sans jamais rendre le contenu muet.
- **Zéro couleur codée en dur** — les rendus de référence
  (`ZFlashcardCardReference`, `ZStudyCardReference`, `ZContentHubReference`,
  `ZDailyTasksReference`, `ZStudySessionReference`, `ZFolderCardReference`)
  centralisent les valeurs visuelles dérivées de `ZcrudTheme`/`ColorScheme`
  ; aucun widget de ce paquet n'écrit de littéral de couleur.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_study.md`](../../docs/site/paquets/zcrud_study.md)
- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Architecture hexagonale](../../docs/site/concepts/architecture-hexagonale.md) — couches, ports et patron kernel/satellite.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_study_kernel` — le domaine pur d'étude dont ce paquet porte la présentation.
- `zcrud_session` — le moteur de révision (runtimes, glisseur, notation) que ce paquet assemble en écran.
- `zcrud_flashcard` / `zcrud_exam` / `zcrud_mindmap` — les modèles de contenu que les voies typées de ce paquet consomment.

## Licence {#licence}

MIT — voir la racine du dépôt.
