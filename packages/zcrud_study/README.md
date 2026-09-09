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
| `ZStudySessionWiring` | Montage énuméré de la session : les 22 seams en champs `required` de type nullable, consommé par `ZStudySessionHost.wired`. |
| `ZStudySessionPreset` | Formes de référence de la session — en-tête, chrome de carte, style de progression — interprétées par l'écran lui-même. |
| `ZSessionHeaderSpec` / `ZCardChromeSpec` | Descripteurs de l'en-tête et de l'habillage de carte que le preset pose. |
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

### Preset de session {#preset}

Une session complète — en-tête à trois places, carte à liseré, progression
compacte — se déclare d'un seul objet, que l'écran interprète lui-même :

```dart
ZStudySessionScaffold(
  title: l10n.sessionTitle,
  mode: ZReviewMode.spaced,
  queue: cards,
  reviewer: reviewer,
  preset: ZStudySessionPreset.classic(
    title: l10n.sessionTitle,
    counter: (ZStudySessionProgress p) => l10n.reviewedOf(p.reviewed, p.total),
    streak: streak,                       // ZStudyStreak, jamais un pourcentage
    accentHeight: 4,
    cardTypeGradientKey: 'session.card',  // une CLÉ, résolue par votre seam
    cardBackgroundColorKey: 'session.surface',
  ),
)
```

Trois règles tiennent tout le contrat :

- **Un paramètre explicite gagne toujours sur le preset**, maillon par maillon.
  Poser `cardAccentHeight:` à côté d'un preset qui décrit une autre hauteur
  garde la vôtre, sans rien perdre du reste du chrome.
- **`preset: null` ne prend aucune branche** : l'arbre rendu et les couleurs
  peintes sont ceux d'avant que ce paramètre n'existe.
- **Les couleurs entrent par clé, les textes déjà localisés.** Le compteur est
  composé par vous : en régime SRS `remaining + reviewed != total` (une carte
  ratée est réinsérée dans la file), et aucune formule ne convient à tous.

L'**ombre de la carte suit son type** sous `classic` : sa teinte est la première
couleur du dégradé qui identifie ce type, résolue carte par carte, par la même
chaîne que le liseré et la pastille (`flashcard.type.<type>` soumis à votre
résolveur, puis le nom de type nu, puis le jeton `flashcardTypeGradients`). Un
thème ne peut pas décrire cette forme : il n'a qu'une teinte d'ombre, quand un
écran montre plusieurs types côte à côte.

```dart
preset: ZStudySessionPreset.classic(
  cardShadowColor: theme.shadowColor,   // …ou une teinte UNIQUE, qui gagne
),
```

Un type dont aucun dégradé n'est résoluble ne reçoit **pas** de teinte : le jeton
de thème `flashcardCardShadowColor` garde alors la main, et sans lui la carte ne
porte aucune ombre. Sans preset, aucune ombre n'entre dans l'arbre. La fonction
qui résout la teinte, `zFlashcardTypeShadowColor`, est publique : elle se pose
telle quelle sur `ZCardChromeSpec.shadowColorResolver`, ou s'enrobe pour n'agir
que sur certains types.

La **forme** de la progression se décrit au même endroit : `classic` pose la
géométrie de sa direction de design — pastilles `14 × 10`, point courant allongé
`2,4 ×`, écart `12`, file centrée sur une seule rangée — et l'épaisseur `8` de la
barre segmentée à marqueur. Chaque réglage n'a d'effet que **sous son style** :

```dart
preset: ZStudySessionPreset.classic(
  progressStyle: ZSessionProgressStyle.dots,   // la géométrie devient visible
),
// …ou votre propre forme, qui bat celle du preset :
progressDotsGeometry: const ZSessionDotsGeometry(
  inactiveSize: Size(14, 10),
  activeScale: 2.4,
  gap: 12,
  alignment: WrapAlignment.center,
  scrollable: true,        // une seule rangée qui défile, hauteur stable
),
progressSegmentedMarkerThickness: 8,
progressLinearThickness: 6,
```

Aucune de ces valeurs n'est imposée : laissées nulles, l'indicateur garde le
rendu qu'il avait — point carré de `gapM`, point courant à `1,5 ×`, écart
`gapS`, file alignée au bord de lecture qui passe à la ligne.

La **forme de la surface de saisie** se décrit au même endroit — quatre réglages,
tous nullables, résolus par la chaîne `paramètre de l'écran > preset > jeton
`ZcrudTheme.answerInput*` > référence` :

| Réglage | Valeur de référence | Ce que `classic` pose |
|---|---|---|
| `answerChoiceLayout` | `compact` — ligne de choix nue | `tile` — fond, liseré, coins arrondis |
| `answerActionsLayout` | `stacked` — « indice » et « je ne sais pas » empilés | `sideBySide` — même ligne, pourtour tracé |
| `answerSubmitWidth` | `content` — soumission à la largeur du contenu | `full` — largeur entière |
| `answerGradingVisibility` | `afterSubmit` — rangée de paliers après la réponse | `always` — rangée montée d'emblée |

```dart
ZStudySessionScaffold(
  title: l10n.sessionTitle,
  mode: ZReviewMode.spaced,
  queue: cards,
  reviewer: reviewer,
  onQualitySelected: onQuality,          // sans lui, aucune rangée de paliers
  preset: ZStudySessionPreset.classic(),
  // …et le paramètre de l'écran bat le preset, forme par forme :
  answerGradingVisibility: ZAnswerGradingVisibility.afterSubmit,
)
```

> ⚠️ **`always` change l'ORDRE DES GESTES.** La rangée de paliers est montée et
> **active avant la réponse**, et un palier tapé alors **est une notation
> manuelle** : elle part par `onQualitySelected` — la voie de notation
> habituelle, aucune autre — et **verrouille** la surface (saisie inerte,
> soumission et contrôles d'aide retirés). Une carte notée à la main produit
> **exactement une** notation, jamais deux, et aucune `ZFlashcardSubmission`
> n'est fabriquée. Sans `onQualitySelected`, aucune rangée n'est montée et le
> réglage n'a aucun effet. Pour garder l'ordre habituel — répondre, puis noter —
> posez `answerGradingVisibility: ZAnswerGradingVisibility.afterSubmit`.

Ces quatre réglages n'ont d'effet que sur la surface **du socle** : un écran qui
remplace la saisie entière par `gradingBuilder` en devient responsable.

Pour un besoin plus fin, `ZStudySessionPreset` se construit champ par champ
(`header`, `cardChrome`, `progressStyle`, `progressDotsGeometry`,
`progressLinearThickness`, `progressSegmentedMarkerThickness`,
`cardBackgroundColorKey`, `answerChoiceLayout`, `answerActionsLayout`,
`answerSubmitWidth`, `answerGradingVisibility`) — et `ZSessionHeaderSpec
.buildRow` rend la rangée d'en-tête seule, réutilisable dans un en-tête à vous.

### Trois façons de monter une session {#trois-facons}

Le même écran se monte de trois manières. Elles ne diffèrent pas par ce
qu'elles rendent — l'arbre est le même, nœud pour nœud — mais par **ce qui
arrive à un seam oublié**.

**1. `.wired` — pour un écran d'application.** Chaque seam est un champ
`required` : en oublier un ne compile pas. Le prix est symétrique — ajouter un
seam au socle vous oblige à vous prononcer.

```dart
ZStudySessionHost.wired(
  mode: ZReviewMode.spaced,
  queue: cards,
  wiring: ZStudySessionWiring(
    reviewer: reviewer,
    hintPort: null,   // …et les vingt autres, `null` compris
    // …
  ),
)
```

**2. À plat + `seamAudit` — pour un montage existant qu'on ne réécrit pas.**
Rien ne change au code appelant : les renonciations se déclarent nominativement,
et tout seam ni posé ni cité est signalé une fois, en debug, dans la console et
les rapports de plantage.

```dart
ZStudySessionHost(
  mode: ZReviewMode.spaced,
  queue: cards,
  reviewer: reviewer,
  seamAudit: const ZStudySeamAuditPolicy(waived: <ZStudySeam>{ZStudySeam.hintPort}),
)
```

**3. À plat, sans rien — pour un banc d'essai ou un prototype.** Aucun audit,
aucun message, aucun coût. Le silence est complet, et c'est ce qu'on veut d'un
montage jetable — jamais d'un écran destiné à un utilisateur.

```dart
ZStudySessionHost(mode: ZReviewMode.list, queue: cards)
```

En cas de doute : **(1) pour ce que vous livrez, (2) pour ce que vous reprenez,
(3) pour ce que vous jetez.** Passer de (3) à (2) ne coûte qu'une ligne, et de
(2) à (1) ne change aucun comportement.

Le preset n'entre dans aucun de ces choix : les **formes** viennent de
`ZStudySessionPreset`, les **seams** du wiring — deux objets, deux
responsabilités, aucun recouvrement, et un preset se pose de la même façon dans
les trois régimes.

### Montage complet {#montage-complet}

`ZStudySessionHost` porte des dizaines de paramètres nommés, presque tous
optionnels et à défaut silencieux. Un seam oublié ne produit **ni erreur de
compilation, ni test rouge** : l'écran s'affiche, ce n'est simplement plus
celui que vous vouliez — libellés du socle, bouton d'indice disparu, sortie
sans issue.

`ZStudySessionWiring` ferme ce trou. Ses champs sont `required` **et**
nullables : Dart vous oblige à *nommer* chaque seam, `null` compris.

```dart
ZStudySessionHost.wired(
  mode: ZReviewMode.spaced,
  queue: cards,
  wiring: ZStudySessionWiring(
    reviewer: reviewer,                       // voie d'écriture SRS
    cardBuilder: null,                        // on garde la carte du socle…
    cardSlotBuilder: null,
    contentBuilder: markdownContentBuilder,    // …avec VOTRE rendu de contenu
    questionTypeBadgeBuilder: null,
    instructionBanner: null,
    evaluationPort: aiEvaluationPort,
    hintPort: aiHintPort,
    onQualitySelected: null,
    qualityColorKeyFor: null,
    qualityPreviewLabelFor: null,
    headerBuilder: null,
    counterBuilder: null,
    gradingBuilder: null,
    summaryBuilder: null,
    emptyBuilder: null,
    celebrationBuilder: null,
    labels: ZStudySessionLabels(exitAction: l10n.close),
    onSessionEnd: (result, duration) => _persist(result),
    onExit: Navigator.of(context).pop,
    indexController: null,
    preset: ZStudySessionPreset.classic(title: l10n.sessionTitle),
  ),
  // Les cosmétiques restent à plat, sur le constructeur.
  cardAccentHeight: 4,
  progressStyle: ZSessionProgressStyle.pill,
)
```

- **`null` veut toujours dire « absent »** — le socle prend son défaut, aucune
  branche n'est prise. Seule la *nomination* devient obligatoire.
- **Aucun seam ne se pose à plat sur `.wired`** : pas de règle de fusion, pas
  de conflit possible entre deux façons de dire la même chose.
- **`ZStudySessionWiring.none()`** renonce à tout d'un coup : banc d'essai,
  capture d'arbre, démonstration — jamais un écran destiné à un utilisateur.
- **Rien n'est requis sur `ZStudySessionHost`** : un montage à plat existant
  compile et rend exactement le même arbre. L'opt-in est le constructeur nommé.
- ⚠️ **Ajouter un seam à `ZStudySessionWiring` est cassant** pour ses
  utilisateurs — le champ neuf est `required`. C'est ce qui interdit qu'une
  capacité neuve rejoigne l'écran sans qu'un montage existant ait à se
  prononcer.

La **page** offre la même garantie, sans descendre d'un cran : le même wiring,
les mêmes cosmétiques à plat, et tous les slots de page en pass-through.

```dart
ZStudySessionScaffold.wired(
  title: l10n.sessionTitle,
  mode: ZReviewMode.spaced,
  queue: cards,
  wiring: wiring,                 // le MÊME objet que ci-dessus
  // Cosmétiques et slots de page restent à plat.
  cardAccentHeight: 4,
  progressStyle: ZSessionProgressStyle.dots,
  actions: <ZAppBarAction>[ZAppBarAction(icon: Icons.close, onPressed: _close)],
)
```

L'enveloppe **ne lit aucun champ** du wiring : elle le remet entier au porteur.
Un seam qui rejoindra le montage demain traverse donc la page sans qu'une ligne
n'y soit écrite — et sans pouvoir y être oublié.

#### Le filet d'audit, pour rester au montage à plat {#audit-de-seams}

Le montage énuméré n'est pas toujours souhaitable : il est cassant par
construction, et un écran qui pose trois seams sur vingt-deux n'a pas envie
d'en nommer dix-neuf. Pour ce cas — le plus courant — `auditSeams` donne le
même signal **sans changer le montage**.

C'est une fonction **pure** : aucun `BuildContext`, aucun `pump`. Elle
s'appelle donc dans un test unitaire, sur le widget que vous construisez :

```dart
test('mon écran de session pose tout ce qu\'il annonce', () {
  final ZStudySeamReport report = maSessionWidget().auditSeams(
    // Renonciations NOMMÉES : l'écran n'a ni indices, ni célébration.
    waived: const <ZStudySeam>{ZStudySeam.hintPort, ZStudySeam.celebrationBuilder},
  );
  expect(report.isComplete, isTrue, reason: report.toString());
});
```

Le rapport nomme chaque seam non posé **et ce que le socle fait à sa place** —
`onExit → aucune issue de sortie dans les replis`, `labels → libellés du socle,
résolus par clé de traduction`. Citer dans `waived` un seam pourtant **posé**
est signalé en retour (`invalidWaivers`) : une déclaration doit décrire le
montage dans les deux sens, sinon elle absorbera en silence la perte du jour où
ce seam disparaîtra.

Le même filet peut vivre **à la construction de l'écran**, en debug seulement :

```dart
ZStudySessionHost(
  mode: ZReviewMode.spaced,
  queue: cards,
  reviewer: reviewer,
  onExit: Navigator.of(context).pop,
  seamAudit: const ZStudySeamAuditPolicy(
    waived: <ZStudySeam>{ZStudySeam.hintPort},
  ),
)
```

Posée, la politique fait relever **une seule fois**, dans la console et dans
vos rapports de plantage, les seams que le montage n'a ni posés ni cités.
L'écran s'affiche exactement pareil, nœud pour nœud : rien n'est levé, rien
n'est ajouté à l'arbre, et le compilateur retire tout en release.

Trois régimes, tous **déclarés** — rien n'est deviné :

| Montage | Ce qui vaut décision | Ce qui vaut oubli |
|---|---|---|
| `.wired` | le `null` écrit dans le wiring | rien : le compilateur l'exige déjà |
| à plat **avec** `seamAudit` | les seams cités dans `waived` | tous les autres seams non posés |
| à plat **sans** `seamAudit` | — | — : aucun audit, aucun message, aucun coût |

Un écran qui ne veut pas d'indices n'en reçoit donc jamais : ne rien poser
**est** la déclaration par défaut.

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
