---
baseline_commit: 1cb21070d907b864a9605d2d280b9e1750a44cd0
---

# Story SUF-3 : `ZStudyFolderDetail` — ossature page-détail + study-tools + sous-dossiers adaptatifs

Status: review

<!-- Source : plan approuvé /home/zakarius/.claude/plans/tingly-brewing-cake.md § Stories › SUF-3 (lignes 83-110) -->
<!-- Epic : epic-suf (Study UI — Folders & Page-shell) — sprint-status.yaml:508-513 -->

## Story

As a **développeur d'une appli hôte d'étude de zcrud (lex_douane cible, IFFD référence)**,
I want **une ossature de page-détail de dossier d'étude — en-tête + onglets Matériel / Notebook / Progression + navigation de sous-dossiers à présentation adaptative (sidebar redimensionnable/repliable sur grand écran ↔ sélecteur compact sur petit écran) — qui COMPOSE les briques existantes (`ZPageScaffold`/`ZSearchableAppBar`, `ZSectionedStudyLayout`, `ZStudyProgressRings`) sans réimplémenter d'app-bar, de recherche, de layout study-tools ni de mécanique responsive**,
so that **une appli hôte obtient, en injectant seulement des données/slots neutres, une page-détail cohérente, RTL-safe, à rebuilds granulaires (AD-2) et thémable — au lieu de re-dupliquer la page `folder_study_tools` + la navigation de sous-dossiers d'IFFD écran par écran**.

**Couvre :** exigence user n°1 du plan (« la page-détail doit embarquer la page study-tools ET une navigation de sous-dossiers à affichage adaptatif, comme IFFD ») · **Taille :** XL · **Package :** `zcrud_study` · **Dépend de :** **SUF-1** (`ZPageScaffold`/`ZSearchableAppBar`/`ZPageTab`/`ZAppBarAction`/`ZAppBarSearchConfig`, `zcrud_ui_kit`) **ET SUF-2** (`ZFolderCard`, `zcrud_study`) · **Débloque :** SUF-4 (démo assemblée grille → détail → session).

---

## 🔴 Décisions tranchées AVANT dev (vérifiées sur disque, pas sur la prose)

Chaque verdict porte sa preuve disque. La consigne nomme des briques « à composer » — chacune a été localisée et sa signature réelle relevée.

### D1 — La page-détail vit dans `zcrud_study` (presentation), COMPOSE et ne réimplémente rien

Nouveaux fichiers sous `packages/zcrud_study/lib/src/presentation/` + `test/`, exportés par le barrel `packages/zcrud_study/lib/zcrud_study.dart`. **Aucune écriture `zcrud_core`** (l'epic SUF n'en écrit aucun — plan §37, §135). Les briques réutilisées sont toutes **déjà accessibles** depuis `zcrud_study` (ou le deviennent via D2) :

- `ZSectionedStudyLayout` + `ZStudyToolsSectionSpec` — **même package** (`packages/zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart:54`, `.../z_study_tools_section_spec.dart:21`), déjà exportés (`zcrud_study.dart:122,129`). Composition directe, zéro nouvelle arête.
- `ZPageScaffold`/`ZSearchableAppBar`/`ZPageTab`/`ZAppBarAction`/`ZAppBarSearchConfig`/`ZPageAppBarMode` — `zcrud_ui_kit`, **déjà en dépendance** (`packages/zcrud_study/pubspec.yaml` → `zcrud_ui_kit: ^0.18.0`). Fournis par SUF-1 (statut `ready-for-dev`).
- `ZResponsiveLayout`/`ZWindowSizeClass`/`ZWindowSizeThresholds`/`ZReorderableAdaptiveGrid` — `zcrud_responsive`, **déjà en dépendance** (`pubspec.yaml` → `zcrud_responsive: ^0.18.0`). Bascule adaptative sans nouvelle mécanique responsive.
- `zResolveColorKeyOrSlot(context, colorKey, slotIndex:)` — `zcrud_core` (`packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart:218`), repli total garanti (jamais `null`, jamais throw — AD-10). Résout l'accent du dossier.

### D2 — Onglet Progression = `ZStudyProgressRings` RÉUTILISÉ ⇒ ajouter l'arête `zcrud_study → zcrud_session` (ACYCLIQUE, prouvé)

`ZStudyProgressRings` + son DTO `ZProgressRingsData` vivent dans **`zcrud_session`** (`packages/zcrud_session/lib/src/presentation/z_study_progress_rings.dart:78,29`, exportés `zcrud_session.dart:120`), PAS dans `zcrud_study`. La consigne exige de **composer** (« NE PAS réimplémenter ») ⇒ il faut **ajouter `zcrud_session: ^0.18.0`** aux `dependencies` de `packages/zcrud_study/pubspec.yaml`.

**Preuve d'acyclicité (vérifiée sur disque)** — arêtes sortantes de `zcrud_session` (`packages/zcrud_session/pubspec.yaml`) : `zcrud_core`, `zcrud_flashcard`, `zcrud_study_kernel`, `zcrud_ui_kit`. **Aucune** n'est `zcrud_study` (`grep zcrud_study packages/zcrud_session/pubspec.yaml` → seulement des commentaires citant `zcrud_study_kernel`, jamais `zcrud_study`). Donc l'arête `zcrud_study → zcrud_session` **ne referme aucun cycle** ; `CORE OUT=0` inchangé (aucune arête ne sort de `zcrud_core`). `melos run verify` / `graph_proof` doivent rester **ACYCLIQUE**.

**Frontière de responsabilité (aucune logique métier dans le widget, AD-2/ES-4.5).** `ZStudyFolderDetail` ne CALCULE aucun ratio : il reçoit un `ZProgressRingsData` **pré-calculé** (l'hôte l'obtient via `ZProgressRingsData.fromResult(...)`, `z_study_progress_rings.dart:44`) et le passe tel quel à `ZStudyProgressRings`. Les « cartes de stats » sont des `Widget` **injectés** (slot `List<Widget>`), jamais un look codé en dur. `progressData == null` ⇒ état vide neutre (jamais de throw).

_Alternative écartée :_ injecter tout le contenu de l'onglet Progression en pur slot `Widget` (zéro arête session). Rejetée car la consigne nomme explicitement `ZStudyProgressRings` comme brique **embarquée** par SUF-3 (« Onglet Progression = ZStudyProgressRings + cartes de stats »), et l'arête est prouvée sûre. La lentille « Isolation deps » du code-review DOIT reconfirmer l'acyclicité (§ Risques).

### D3 — Navigation de sous-dossiers : descripteurs OPAQUES, jamais l'entité `ZStudyFolder` (cohérent avec le reste de `zcrud_study`)

Les briques présentation de `zcrud_study` prennent des **props primitives/opaques**, jamais l'entité domaine (cf. `z_study_mindmap_section.dart` prend un `folderId` opaque ; `ZStudyToolsSectionSpec` « n'est PAS l'entité domaine », `z_study_tools_section_spec.dart:9`). SUF-3 suit la même règle : un nouveau value-object **présentation** `ZSubfolderRef` (props : `id` String opaque, `label` déjà localisé, `colorKey` String? optionnel, `count` int? optionnel) — **aucune** référence à `ZStudyFolder`/kernel, aucune couleur/`IconData` en dur.

**Réutilisation de `ZFolderCard` (SUF-2) — insulée d'une API non finalisée.** L'item de sous-dossier dans la sidebar est une **rangée sélectionnable** (surbrillance + poignée de drag), visuellement distincte d'une carte de grille. SUF-3 rend l'item via un `subfolderItemBuilder` **injectable** (défaut = rangée neutre thémée) : l'hôte peut brancher un rendu basé `ZFolderCard` s'il le souhaite, sans que SUF-3 ne se couple à la signature exacte de SUF-2 (encore inexistante sur disque au moment de l'écriture — `grep 'class ZFolderCard' packages/` = 0 hit). Voir § Risques (R-SUF2).

### D4 — Bascule adaptative via `ZResponsiveLayout`, seuil `600 dp` = `ZWindowSizeThresholds.mediumMinWidth` (déjà défini, jamais redéclaré)

Le breakpoint « ~600 dp » de la consigne EST exactement `ZWindowSizeThresholds.mediumMinWidth = 600` (`packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart:38`). On **n'introduit aucune constante 600 en dur** : on délègue à `ZResponsiveLayout` (`compact` = sélecteur compact ; `medium`/`expanded` = sidebar, par cascade descendante). `ZResponsiveLayout` mesure la largeur **locale** via `LayoutBuilder` (`z_responsive_layout.dart:73`) ⇒ testable à deux tailles d'écran sans manipuler `MediaQuery` global.

---

## Acceptance Criteria

> Convention de test R3 (**NON-NÉGOCIABLE**) : chaque AC est vérifiée par une garde **prouvée mordante** — le dev doit, pour chaque garde, **ré-injecter la régression correspondante** (fichier:ligne exacte + effet), constater le **rouge**, restaurer, et consigner l'injection (chemin:ligne + symptôme observé) dans le Dev Agent Record. Une garde qui ne rougit pas quand on casse la logique est **tautologique et rejetée** (discipline R3). Piège documenté (SU-8 / SUF-1 AC6) : pour les gardes de rebuild granulaire, compter les rebuilds de la **tranche qui NE doit PAS bouger** et prouver qu'ils restent constants ET que l'injection d'un rebuild global les fait monter.

### En-tête & onglets (composés via SUF-1 — aucune app-bar réimplémentée)

**AC1 — En-tête via `ZPageScaffold`/`ZSearchableAppBar`, titre + accent dossier.** `ZStudyFolderDetail` rend son en-tête **exclusivement** via `ZPageScaffold`/`ZSearchableAppBar` (SUF-1) : le `title` (String → `Text`, ou `Widget`) est rendu ; l'accent du dossier est dérivé de `colorKey` via `zResolveColorKeyOrSlot(context, colorKey, slotIndex:)` (jamais un `Color` en dur). **Aucune** app-bar/recherche n'est réimplémentée dans les fichiers de la story.
_R3 :_ (a) garde runtime : `find.byType(ZPageScaffold)` (ou `ZSearchableAppBar`) `findsOneWidget` ; le titre injecté est visible ; l'accent affiché suit le `colorKey` injecté (deux `colorKey` distincts ⇒ deux couleurs distinctes mesurées). (b) garde statique : `grep -nE '\b(AppBar|SliverAppBar)\s*\(' ` sur les fichiers de la story ⇒ **0 hit** (le shell est délégué à SUF-1). Régression ré-injectée : rendre un `AppBar(...)` local au lieu de déléguer à `ZPageScaffold` → la garde statique rougit ; coder l'accent en `Colors.blue` → la garde « accent suit colorKey » rougit.

**AC2 — Trois onglets Matériel / Notebook / Progression via les `tabs` de SUF-1.** Les 3 onglets sont portés par `ZPageScaffold.tabs: List<ZPageTab>` (labels **injectés/localisés**, jamais codés en dur). Basculer d'onglet affiche le contenu de l'onglet cible et masque les autres.
_R3 :_ contenu Matériel visible à l'index 0 ; tap onglet « Progression » ⇒ contenu Progression visible, Matériel absent. Régression ré-injectée : câbler les 3 `contentBuilder` sur celui de l'onglet 0 → le tap sur Progression laisse Matériel → rouge.

**AC3 — Slots d'action (tri / ajout / menu ⋮) injectés, absents si non fournis.** Les actions d'en-tête (`sortAction`, `addAction`, `menuActions`) sont projetées en `List<ZAppBarAction>` passée à SUF-1. Une action **non fournie (`null`) est structurellement absente** (pas de bouton fantôme, jamais de no-op silencieux — AD-4) ; une action fournie invoque **son** callback au tap.
_R3 :_ avec `sortAction != null, addAction == null` ⇒ l'icône de tri est présente, l'icône d'ajout absente ; taper le tri invoque `sortAction` (et pas une autre). Régression ré-injectée : rendre l'icône d'ajout inconditionnellement → la garde « ajout absent si null » rougit ; câbler toutes les actions sur la première → le tap sur le menu déclenche le mauvais callback → rouge.

**AC4 — Recherche déléguée à SUF-1, absente si non configurée.** `search: ZAppBarSearchConfig?` est passé tel quel à `ZSearchableAppBar` : `null` ⇒ aucune icône/champ de recherche possible ; fourni ⇒ la bascule loupe morphe l'app-bar (comportement porté par SUF-1, non re-testé ici sauf le pass-through). Aucune mécanique de recherche n'est réimplémentée.
_R3 :_ `search: null` ⇒ `find.byIcon(Icons.search)` (ou finder loupe) `findsNothing` ; `search: <config>` ⇒ la loupe est présente. Régression ré-injectée : rendre la loupe indépendamment de `search` → la garde « absente si null » rougit.

### Onglet Matériel = `ZSectionedStudyLayout` composé (jamais réimplémenté)

**AC5 — L'onglet Matériel COMPOSE `ZSectionedStudyLayout`.** Le contenu de l'onglet Matériel est rendu par `ZSectionedStudyLayout(sections: materialSectionsBuilder(selectedSubfolderId))` — rail flashcards + grilles réordonnables notes/mindmaps/documents portés par le layout existant. SUF-3 **ne recrée pas** le `ListView.builder` de sections ni les en-têtes/compteurs/états vides.
_R3 :_ (a) `find.byType(ZSectionedStudyLayout)` `findsOneWidget` dans l'onglet Matériel ; les sections rendues sont exactement celles fournies par le builder. (b) garde statique : les fichiers de la story ne contiennent **pas** un second `ListView.builder` itérant des `ZStudyToolsSectionSpec`. Régression ré-injectée : remplacer la composition par un `Column`/`ListView` local de sections → `find.byType(ZSectionedStudyLayout)` = `findsNothing` → rouge.

### Onglet Progression = `ZStudyProgressRings` réutilisé + cartes de stats injectées

**AC6 — L'onglet Progression rend `ZStudyProgressRings` + les cartes de stats injectées.** Le contenu Progression rend `ZStudyProgressRings(data: progressData)` (DTO **pré-calculé** injecté) suivi des `progressStatCards` (slot `List<Widget>`, défaut `const []`). `progressData == null` ⇒ **état vide neutre** (message via label injecté), **jamais** de throw ni de division par zéro (le DTO gère déjà `total == 0`).
_R3 :_ avec un `ZProgressRingsData(total: 10, correct: 7, ratio: .7)` ⇒ `find.byType(ZStudyProgressRings)` `findsOneWidget` et la sémantique `value == '7/10'` ; 3 `progressStatCards` ⇒ les 3 sont présentes ; `progressData: null` ⇒ pas de `ZStudyProgressRings`, pas d'exception, l'état vide s'affiche. Régression ré-injectée : ne pas rendre `ZStudyProgressRings` quand `progressData != null` → rouge ; rendre les rings sans garde `null` → l'arbre `progressData:null` lève → rouge (prouve le repli).

### Navigation de sous-dossiers ADAPTATIVE (exigence user, comme IFFD)

**AC7 — Bascule sidebar ↔ sélecteur compact au franchissement du breakpoint (`ZResponsiveLayout`, seuil 600 dp).** Sous une largeur **< 600 dp** : la navigation de sous-dossiers est un **sélecteur compact** (rangée de chips scrollable **ou** dropdown dans le sous-titre) et **aucune** sidebar n'est dans l'arbre. Sous une largeur **≥ 600 dp** : une **sidebar** de sous-dossiers est présente et **aucun** sélecteur compact n'est dans l'arbre. Le seuil provient de `ZWindowSizeThresholds.mediumMinWidth` (aucune constante 600 codée en dur).
_R3 (test à deux tailles d'écran, largeur locale pilotée) :_ à 500 dp ⇒ `find.byKey(ZSubfolderSidebar) == findsNothing` ET `find.byKey(ZSubfolderCompactSelector) == findsOneWidget` ; à 900 dp ⇒ l'inverse. Régression ré-injectée : rendre la sidebar dans le builder `compact` de `ZResponsiveLayout` → l'assertion « pas de sidebar à 500 dp » rougit ; rendre le sélecteur compact dans le builder `expanded` → l'assertion « pas de chips à 900 dp » rougit.

**AC8 — Item racine « Tous les sous-dossiers » + item sélectionné mis en évidence.** La navigation (sidebar comme sélecteur compact) expose toujours un **item racine** (label `allSubfoldersLabel` injecté, `id` de sélection = `null`) en tête, suivi des `subfolders`. L'item **sélectionné** est visuellement mis en évidence (fond/contour dérivé du thème, jamais couleur en dur) ET porte `Semantics(selected: true)`.
_R3 :_ sélection initiale = racine ⇒ l'item racine porte `selected:true`, les autres `selected:false` ; sélectionner le sous-dossier d'index 1 ⇒ lui seul `selected:true`. Régression ré-injectée : figer la surbrillance sur l'item racine → sélectionner un autre item ne déplace pas le `selected:true` → rouge.

**AC9 — La sélection de sous-dossier FILTRE le contenu de l'onglet Matériel.** Choisir un sous-dossier met à jour la `ValueListenable<String?>` de sélection **détenue par le widget** et **ré-invoque** `materialSectionsBuilder(selectedSubfolderId)` ⇒ le contenu de l'onglet Matériel change. Le widget ne filtre **aucune donnée lui-même** (pas de logique métier) : il re-fournit l'id sélectionné au builder injecté.
_R3 :_ un `materialSectionsBuilder` de test renvoie des sections différentes selon l'id ; sélectionner le sous-dossier X ⇒ le builder est appelé avec `X` ET les sections affichées sont celles de X (une section « marqueur:X » apparaît, « marqueur:null » disparaît). Régression ré-injectée : ignorer l'id sélectionné et toujours appeler `materialSectionsBuilder(null)` → le contenu ne change pas à la sélection → rouge. (garde AD-2 : voir aussi AC14)

**AC10 — Sidebar redimensionnable par drag, bornée (min ~300 dp, max ~50 % écran), largeur persistée sans I/O.** La largeur de la sidebar est une `ValueListenable<double>` **détenue par le widget**, ajustée par un drag-handle et **clampée** dans `[minSidebarWidth (~300), maxSidebarWidthFraction × largeurÉcran (~0.5)]`. Chaque changement stabilisé émet `onSidebarWidthChanged(width)` (callback injecté) — **aucune** I/O (SharedPreferences/fichier/repo) dans le widget.
_R3 :_ drag de +10000 dp ⇒ largeur finale = borne max (≤ 50 % écran) ; drag de −10000 dp ⇒ largeur finale = `minSidebarWidth` ; `onSidebarWidthChanged` reçoit la valeur clampée. Régression ré-injectée : retirer le `clamp` → la largeur dépasse la borne → rouge ; garde statique : `grep` de `SharedPreferences`/`dart:io`/`File(` dans les fichiers de la story ⇒ 0 hit (régression : écrire la largeur en direct → rouge).

**AC11 — Repli / déploiement de la sidebar (~56 dp repliée, icône + badge count).** Un contrôle de repli bascule une `ValueListenable<bool>` **détenue par le widget** : repliée, la sidebar occupe ~56 dp et n'affiche qu'une icône (+ badge du nombre de sous-dossiers) ; déployée, elle affiche la liste complète à sa largeur de drag. La bascule ne reconstruit **que** la sidebar (voir AC14).
_R3 :_ état déployé ⇒ liste des items visible ET largeur == largeur de drag ; tap repli ⇒ liste masquée ET largeur ≈ 56 dp ; tap déploi ⇒ restaurée. Régression ré-injectée : figer `_collapsed=false` → le tap repli ne masque jamais → rouge.

**AC12 — Sidebar réordonnable si `onSubfolderReorder` fourni, non réordonnable sinon (AD-4).** Quand `onSubfolderReorder: void Function(int oldIndex, int newIndex)?` est **non nul**, les items de sous-dossier portent une poignée de drag (a11y : actions sémantiques « déplacer avant/après » via labels injectés) et un dépôt invoque `onSubfolderReorder(old, new)` en convention `removeAt(old)/insert(new)` (indices **linéaires**). `null` ⇒ capacité **absente**, aucune poignée.
_R3 :_ `onSubfolderReorder != null` ⇒ poignées présentes, un déplacement émet `(old, new)` attendus ; `onSubfolderReorder == null` ⇒ aucune poignée trouvable. Régression ré-injectée : rendre les poignées inconditionnellement → la garde « absente si null » rougit ; inverser `old`/`new` dans l'émission → la garde d'indices rougit. _(Réutiliser la convention/labels de `ZReorderableAdaptiveGrid` si une grille réordonnable est retenue ; sinon `ReorderableListView` avec la même convention — ne PAS réinventer la mécanique d'autoscroll/actions sémantiques.)_

**AC13 — Bouton « Ajouter » un sous-dossier via slot, absent si non fourni.** `addSubfolderAction: VoidCallback?` : fourni ⇒ un bouton « Ajouter » (label/icône injectés) est rendu dans la navigation (sidebar ET sélecteur compact) et invoque le callback ; `null` ⇒ bouton **structurellement absent** (AD-4).
_R3 :_ `addSubfolderAction != null` ⇒ bouton présent, tap invoque le callback ; `null` ⇒ `findsNothing`. Régression ré-injectée : rendre le bouton inconditionnellement → rouge.

### AD-2 / a11y-RTL / thème / isolation

**AC14 — Rebuilds GRANULAIRES par tranche (AD-2/AD-44/SM-1), propriétaire unique, aucun gestionnaire d'état.** Les états `selectedSubfolderId` (`ValueNotifier<String?>`), `collapsed` (`ValueNotifier<bool>`), `sidebarWidth` (`ValueNotifier<double>`) sont **détenus par le widget** (créés en `initState`, `dispose`és), rendus via `ValueListenableBuilder` sur la **seule** tranche concernée — **aucun** `flutter_riverpod`/`get`/`provider`, **aucun** `setState` à l'échelle de la page, **aucun** `TabController`/controller recréé au rebuild. Changer la **sélection** ne reconstruit **que** le corps Matériel (pas Notebook/Progression, pas la sidebar) ; **replier** ne reconstruit **que** la sidebar (pas les onglets) ; la **largeur** ne reconstruit que le chrome de la sidebar.
_R3 (compteurs sur les tranches qui NE doivent PAS bouger) :_ compteur de build du corps Progression inchangé pendant qu'on change 10× la sélection ; compteur de build d'un onglet inchangé pendant qu'on replie/déplie 10× ; ET injection inverse : remonter la sélection dans un `setState` de la page → le compteur Progression s'incrémente → rouge. Régression ré-injectée : rendre l'état via un `setState` global → les compteurs des tranches figées montent → rouge. (garde SM-1)

**AC15 — Neutre thémable + AD-13 (RTL / Semantics / ≥48 dp / const / l10n injectée).** Toutes les couleurs/typo dérivent de `ZcrudTheme.of(context)` / `ColorScheme` / `zResolveColorKeyOrSlot` (repli `Theme.of`) — **aucun** `Color(0x…)`/`Colors.<x>` (hors `Colors.transparent`). Tous les libellés (onglets, « Tous les sous-dossiers », « Ajouter », tooltips, actions sémantiques de reorder) sont **injectés** (paramètres l10n de l'appelant), jamais codés en dur. Sous `Directionality.rtl` la sidebar s'ancre côté **start** (insets/positions **directionnels** : `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional`/`TextAlign.start-end` — **jamais** les formes `left/right`). Toutes les cibles interactives (items, repli, drag-handle, boutons) ≥ 48 dp ; `Semantics` explicites ; `const` où l'immuabilité le permet.
_R3 :_ (a) gardes **statiques** (scan source du dossier de la story) : 0 hit de `Color(0x`/`Colors.` (sauf `transparent`), 0 hit des formes non-directionnelles interdites (`EdgeInsets.only(left|right`, `Alignment.centerLeft|centerRight`, `Positioned(left|right`, `TextAlign.left|right`), 0 chaîne de libellé UI codée en dur. (b) garde **runtime RTL** : sous `rtl`, le bord d'ancrage de la sidebar est côté droit visuel (position mesurée) ; sous `ltr`, côté gauche. Régression ré-injectée : remplacer un `EdgeInsetsDirectional.only(start:)` par `EdgeInsets.only(left:)` → la garde statique + la garde de position RTL rougissent ; coder un label « Tous les sous-dossiers » en dur → la garde « libellé injecté » rougit.

**AC16 — Isolation deps (AD-1/AD-29) : arête `session` ajoutée ACYCLIQUE, barrel, zéro manager.** `packages/zcrud_study/pubspec.yaml` gagne **exactement une** arête (`zcrud_session: ^0.18.0`, D2) ; **aucun** import de gestionnaire d'état (`flutter_riverpod`/`get`/`provider`), routeur, ou tiers UI dans les nouveaux fichiers ; les nouveaux types publics (`ZStudyFolderDetail`, `ZSubfolderRef`, et le(s) descripteur(s) de nav retenus) sont exportés par `lib/zcrud_study.dart` ; `graph_proof`/`melos run verify` restent **ACYCLIQUE** et `CORE OUT=0`.
_R3 :_ garde d'import (scan des nouveaux fichiers) ⇒ 0 hit de `package:get/`, `flutter_riverpod`, `provider`, `go_router` ; `dart run melos run verify` / `graph_proof` verts (ACYCLIQUE, `CORE OUT=0`). Régression ré-injectée : `import 'package:get/get.dart';` dans un fichier de la story → la garde d'import rougit ET `analyze` casse ; (contrôle négatif d'acyclicité) ajouter `zcrud_study` aux deps de `zcrud_session` créerait un cycle → `graph_proof` rougirait (ne PAS committer — vérification mentale documentée).

---

## Tasks / Subtasks

- [x] **T0 — Dépendance & barrel** (AC6, AC16) — `zcrud_session: ^0.18.0` ajouté aux `dependencies` (D2), `dart pub get` OK, `graph_proof` ACYCLIQUE `CORE OUT=0` (68→69 arêtes) rejoué AVANT d'écrire du code.
- [x] **T1 — Value objects de navigation** (AC7, AC8, AC12, AC3) — `z_subfolder_ref.dart` (`ZSubfolderRef`, props primitives + `==`/`hashCode`) ET descripteur agrégé retenu `z_subfolder_nav_spec.dart` (`ZSubfolderNavSpec` + `ZSubfolderItemBuilder`).
- [x] **T2 — Sidebar (grand écran)** (AC8, AC10–AC13, AC15) — `z_subfolder_sidebar.dart` (`ZSubfolderSidebar`, clés `resizeHandleKey`/`collapseToggleKey`) : racine + `ReorderableListView.builder`/`ListView.builder`, surbrillance par item scopée, drag-resize borné directionnel (RTL-flip), repli ~56 dp, actions sémantiques de reorder.
- [x] **T3 — Sélecteur compact (petit écran)** (AC7, AC8, AC13, AC15) — `z_subfolder_compact_selector.dart` (`ZSubfolderCompactSelector`, `compactKey`) : rangée de `ChoiceChip` scrollable (`SingleChildScrollView`+`Row`, hauteur bornée), racine en tête, bouton « Ajouter » slot.
- [x] **T4 — Assemblage `ZStudyFolderDetail`** (AC1–AC6, AC9, AC14) — `z_study_folder_detail.dart` : `StatefulWidget` propriétaire des 3 `ValueNotifier` (initState/dispose), en-tête+actions+recherche+tabs via SUF-1, accent `zResolveColorKeyOrSlot`, Matériel via `ZSectionedStudyLayout`, Progression via `ZStudyProgressRings` (état vide sûr si null), nav via `ZResponsiveLayout`.
- [x] **T5 — Barrel & exports** (AC16) — 5 nouveaux types publics exportés (ordre alpha respecté, 0 nouvel info `directives_ordering`).
- [x] **T6 — Tests R3** (toutes ACs) — 8 fichiers de tests + harnais partagé ; chaque garde prouvée mordante (injections consignées ci-dessous).
- [x] **T7 — Vérif verte rejouée** : pas de codegen (aucun `@ZcrudModel`) → `dart analyze packages/zcrud_study` RC=0 → `flutter test` package RC=0 (593 tests) → `graph_proof` **ACYCLIQUE**, `CORE OUT=0`.

---

## Dev Notes

### Briques EXISTANTES à composer (signatures relevées sur disque — ne rien réinventer)

- **`ZSectionedStudyLayout`** (`packages/zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart:54`) : `const ZSectionedStudyLayout({required List<ZStudyToolsSectionSpec> sections})`. Rend un `ListView.builder`, ordre visuel = ordre d'entrée, chaque section keyée `ValueKey('section:$id')`. **Même package** ⇒ import direct, déjà exporté (`zcrud_study.dart:122`).
- **`ZStudyToolsSectionSpec`** (`.../z_study_tools_section_spec.dart:21`) : descripteur paramétrique (id, title, itemCount, itemBuilder, emptyState, addAction?, axis, itemIds?, onReorder?, collapsible, `crossAxisMinItemWidth`…). L'hôte construit les sections dans `materialSectionsBuilder` — SUF-3 ne les fabrique pas.
- **`ZStudyProgressRings`** (`packages/zcrud_session/lib/src/presentation/z_study_progress_rings.dart:78`) : `const ZStudyProgressRings({required ZProgressRingsData data, double diameter = 96, double strokeWidth = 10, String trackColorKey = 'neutral', String progressColorKey = 'primary'})`. `Semantics(value: 'correct/total')`. Le DTO `ZProgressRingsData` (`:29`) est **pré-calculé** (`fromResult(...)`, `:44`, gère `total==0`). **Package `zcrud_session`** ⇒ arête à ajouter (D2/T0).
- **SUF-1 (`zcrud_ui_kit`)** — signatures **de référence** (susceptibles d'évoluer, cf. R-SUF1) d'après `_bmad-output/implementation-artifacts/stories/suf-1-page-shell-searchable-appbar.md` : `ZPageScaffold({title, leading?, actions: List<ZAppBarAction> = const [], search: ZAppBarSearchConfig?, tabs: List<ZPageTab>?, mode: ZPageAppBarMode})` ; `ZAppBarAction(icon, semanticLabel, onPressed?, tooltip?, isOverflow)` ; `ZAppBarSearchConfig(onQueryChanged, hintLabel?, initialQuery)` ; `ZPageTab(label, icon?, contentBuilder)`.
- **Responsive (`zcrud_responsive`)** : `ZResponsiveLayout({required WidgetBuilder compact, WidgetBuilder? medium, WidgetBuilder? expanded})` (mesure locale `LayoutBuilder`, cascade descendante — `z_responsive_layout.dart:35`) ; seuils `ZWindowSizeThresholds.mediumMinWidth = 600` / `expandedMinWidth = 840` (`z_window_size_class.dart:38`) ; `ZReorderableAdaptiveGrid({required List<String> itemIds, required itemBuilder, required onReorder(oldIndex,newIndex), required double minItemWidth, required String moveBeforeSemanticLabel, required String moveAfterSemanticLabel, …})` (`z_reorderable_adaptive_grid.dart:89`) — autoscroll + actions sémantiques déjà fournis.
- **Accent couleur** : `zResolveColorKeyOrSlot(context, colorKey, slotIndex:)` (`packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart:218`) — rend **toujours** une `ZColorPair` contrastée (jamais `null`, jamais throw, AD-10). `pair.color` = fond, `pair.onColor` = premier plan lisible.
- **Tokens thème** : `ZcrudTheme.of(context)` → `gapS=4/gapM=8/gapL=16`, `radiusS/radiusM` (`packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:32-36,100-112`). Repli `Theme.of(context)`.
- **Résolution de label** (patron `z_state_widgets.dart:88-91`, cf. SUF-1) : `ZcrudScope.maybeOf(context)?.labels?.maybeResolve(<clé>) ?? ZcrudLocalizations.maybeOf(context)?.maybeResolve(<clé>) ?? <repli>`. Mais SUF-3 privilégie l'**injection directe** des libellés (onglets, « Tous les sous-dossiers », « Ajouter »…) en paramètres — cohérent avec `ZStudyToolsSectionSpec.title` « déjà localisé par l'appelant ».

### Référence IFFD (LECTURE SEULE ABSOLUE — /home/zakarius/DEV/iffd)

La page-détail + sidebar de sous-dossiers d'IFFD est la **source d'inspiration fonctionnelle** (folder study-tools + navigation adaptative). **Garder l'idée** : sidebar redimensionnable/épinglable/repliable sur grand écran, sélecteur compact sur petit écran, item racine « Tous », réordonnabilité, bouton d'ajout. **Refuser** (AD-2/AD-15) : tout état porté par un contrôleur/gestionnaire d'état externe ⇒ **détenir l'état dans le widget** (propriétaire unique) ; tout tiers responsive (`responsive_builder`) ⇒ `ZResponsiveLayout`/`LayoutBuilder` ; toute couleur/label codé en dur ⇒ thème/labels injectés. **Aucune écriture** iffd/lex — grep/read only.

### Référence lex_douane (LECTURE SEULE ABSOLUE — cible d'adoption)

lex est la **cible** : la page-détail doit être bridgeable sans écart visuel notable côté lex. L'adoption (bridge) est **app-side**, hors périmètre SUF-3 (plan § Hors périmètre). **Aucune écriture** lex.

### Contraintes AD (rappels NON-NÉGOCIABLES applicables ici)

- **AD-2/AD-15/AD-44** : aucun gestionnaire d'état dans le widget ; sélection/repli/largeur = propriétaire **unique** (le widget, `ValueNotifier`) ; rebuilds **granulaires** (`ValueListenableBuilder` par tranche) ; `TabController`/`ValueNotifier`/handles créés une fois (create/dispose), jamais recréés au rebuild ; `ValueKey` stables (sidebar/compact/onglets). **Aucune I/O dans le widget** — la persistance de largeur passe par le callback injecté.
- **AD-13** : `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional`/`TextAlign.start-end` uniquement ; `Semantics` explicites (items `selected:`, reorder « déplacer avant/après », repli/déploi) ; cibles ≥ 48 dp ; `const` où possible.
- **AD-4** : callback `null` = capacité **absente** (tri/ajout/menu/reorder/ajout-sous-dossier), jamais un no-op silencieux ni un widget fantôme.
- **AD-10** : replis sûrs — `progressData == null` ⇒ état vide (jamais throw) ; accent toujours résolu (`zResolveColorKeyOrSlot`) ; clé de couleur inconnue ⇒ slot de repli.
- **AD-1/AD-29** : `zcrud_study` reste satellite ; l'unique nouvelle arête `→ zcrud_session` est prouvée acyclique (D2) ; aucun manager/routeur/tiers UI ; ne redéclare aucun symbole `zcrud_core`.

### Discipline de test R3 (falsifiabilité)

Un test qui ne rougit pas quand la logique casse est **rejeté**. Pièges spécifiques SUF-3 : (a) AC7 — tester à **deux largeurs locales réelles** (500 dp et 900 dp, via un parent contraint / `LayoutBuilder`), pas via un flag ; prouver que forcer la sidebar dans le builder `compact` rougit. (b) AC9/AC14 — prouver que la sélection **re-invoque** le builder ET que le corps Progression **ne** rebuild pas (compteur figé) ; injection inverse `setState` global → compteur monte → rouge. (c) AC10 — le clamp doit rougir si retiré (drag hors bornes). Chaque injection consignée : chemin:ligne modifié + symptôme rouge observé.

### Project Structure Notes

- Nouveaux fichiers **uniquement** sous `packages/zcrud_study/lib/src/presentation/` + `test/`. **Aucune** écriture `zcrud_core` (epic SUF, plan §37/§135). Aucun `*.g.dart` attendu (widgets Flutter purs, pas d'annotation `@ZcrudModel`) ⇒ `melos run generate` ne change rien pour `zcrud_study`.
- **Seule mutation `pubspec`** : `+ zcrud_session: ^0.18.0` (D2). Bump de version restreint aux `zcrud_*` en fin d'epic — géré par l'orchestrateur, PAS dans cette story.
- SUF-2 et SUF-3 = même package `zcrud_study` ⇒ **jamais en vol simultané** (plan §134) : SUF-3 démarre SUF-2 `done`.

### Risques (à surveiller)

- **R-SUF1 — Signatures SUF-1 non finalisées.** SUF-1 est `ready-for-dev`, pas `done` : les noms/paramètres exacts de `ZPageScaffold`/`ZAppBarAction`/`ZAppBarSearchConfig`/`ZPageTab` peuvent évoluer au dev. Mitigation : consommer ces types **via le barrel `zcrud_ui_kit`** et adapter aux signatures réelles au moment du dev SUF-3 (SUF-1 sera `done` avant, cf. séquencement plan §132-134). Toute divergence relevée doit être notée, pas devinée.
- **R-SUF2 — `ZFolderCard` (SUF-2) inexistant sur disque à l'écriture** (`grep 'class ZFolderCard' packages/` = 0 hit). Mitigation D3 : l'item de sous-dossier passe par un `subfolderItemBuilder` **injectable** (défaut = rangée neutre) ⇒ SUF-3 ne se couple pas à la signature exacte de SUF-2 ; l'hôte/la démo (SUF-4) peut brancher `ZFolderCard`. SUF-2 sera `done` avant SUF-3.
- **R-DEP — Acyclicité de l'arête `zcrud_study → zcrud_session`.** Prouvée sûre aujourd'hui (D2) ; la lentille « Isolation deps » du code-review DOIT reconfirmer `graph_proof` ACYCLIQUE + `CORE OUT=0` sur disque (jamais sur la seule prose de cette story).
- **R-SM1 — Test de rebuild infalsifiable** (piège SU-8 / SUF-1 AC6). Mitigation : compteurs sur les tranches figées + injection inverse obligatoire (AC14).

### References

- [Source: /home/zakarius/.claude/plans/tingly-brewing-cake.md#SUF-3] — spec (lignes 83-110), briques à réutiliser (§39-49), séquencement (§132-135).
- [Source: packages/zcrud_study/lib/src/presentation/z_sectioned_study_layout.dart:54] — `ZSectionedStudyLayout` (onglet Matériel, composition directe).
- [Source: packages/zcrud_study/lib/src/presentation/z_study_tools_section_spec.dart:21] — `ZStudyToolsSectionSpec` (descripteur injecté, jamais l'entité).
- [Source: packages/zcrud_session/lib/src/presentation/z_study_progress_rings.dart:29,44,78] — `ZProgressRingsData`/`fromResult`/`ZStudyProgressRings` (onglet Progression, arête D2).
- [Source: packages/zcrud_session/pubspec.yaml] — arêtes sortantes (preuve d'acyclicité D2 : pas de `zcrud_study`).
- [Source: packages/zcrud_study/pubspec.yaml] — deps actuelles (`zcrud_ui_kit`/`zcrud_responsive` déjà présents ; `zcrud_session` à ajouter).
- [Source: _bmad-output/implementation-artifacts/stories/suf-1-page-shell-searchable-appbar.md] — API du page-shell consommée (référence, R-SUF1).
- [Source: packages/zcrud_responsive/lib/src/presentation/z_responsive_layout.dart:35] — `ZResponsiveLayout` (bascule adaptative).
- [Source: packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart:38] — `ZWindowSizeThresholds.mediumMinWidth = 600` (breakpoint, jamais redéclaré).
- [Source: packages/zcrud_responsive/lib/src/presentation/z_reorderable_adaptive_grid.dart:89] — convention reorder + actions sémantiques (AC12).
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart:218] — `zResolveColorKeyOrSlot` (accent, repli total AD-10).
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:32-36,100-112] — tokens `gap*`/`radius*`.
- [Source: /home/zakarius/DEV/iffd] — référence fonctionnelle folder study-tools + sidebar sous-dossiers (LECTURE SEULE).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (agent BMAD `bmad-dev-story`).

### Debug Log References

**Vérif verte rejouée sur disque (finale) :**
- `dart analyze packages/zcrud_study` → **RC=0** (0 error, 0 warning ; seuls des infos PRÉ-EXISTANTS hors story).
- `flutter test` (package `zcrud_study` complet) → **RC=0, 593 tests OK** (dont 36 nouveaux SUF-3).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK, CORE OUT=0 OK** (68→69 arêtes ; nouvelle arête `zcrud_study → zcrud_session` prouvée acyclique — `zcrud_session` ne dépend pas de `zcrud_study`).
- Scanner récursif `z_widgets_hardcode_scan_test.dart` (toute la présentation, mes 5 fichiers inclus) → **VERT** (0 couleur/label/API non-directionnelle/`fontSize` en dur).

**Injections de régression R3 (chacune : injectée → ROUGE observé → restaurée) :**
| AC | Injection exacte | Symptôme ROUGE |
|----|------------------|----------------|
| AC1 | accent `pair.color` → `Color(0xFF2196F3)` fixe (`z_study_folder_detail.dart` `_titleWidget`) | « deux colorKey distincts » : `c1==c2` ⇒ rouge |
| AC7 | `_sidebarRegion(context)` → `ZSubfolderCompactSelector(...)` dans le builder `medium` | « ≥600 : sidebar » : sidebar absente / compact présent à 900 dp ⇒ rouge |
| AC9 | `materialSectionsBuilder(id)` → `materialSectionsBuilder(null)` (corps Matériel) | sélection sf1 : `empty:sf1` jamais rendu ⇒ rouge |
| AC10 | retrait du `.clamp(minWidth, maxWidth)` dans `_resizeHandle` | drag +10000 : largeur `1200 > 450` ⇒ rouge |
| AC11 | `? _buildCollapsed` → `? _buildExpanded` (repli sans effet) | tap repli : liste jamais masquée ⇒ rouge |
| AC12 | émission `onReorder!(oldIndex, newIndex)` → `(newIndex, oldIndex)` | `onReorderItem(0,2)` : émet `[2,0]` au lieu de `[0,2]` ⇒ rouge |
| AC14 | `_toggleCollapsed` + `setState(() {})` global | « replier NE reconstruit PAS le corps Matériel » : `matCalls` monte ⇒ rouge |

Falsifiabilité SM-1 (AC14) : le test `CONTRÔLE — le probe DÉTECTE un rebuild` prouve que la sonde `_Probe` s'incrémente sous un rebuild réel ⇒ les gardes « tranche figée » ne sont pas tautologiques.

### Completion Notes List

- **16/16 ACs satisfaits.** Aucune écriture `zcrud_core` (epic SUF). Aucune app-bar/recherche/layout study-tools/mécanique responsive réimplémentés — tout est COMPOSÉ (SUF-1 `ZPageScaffold`, `ZSectionedStudyLayout`, `ZStudyProgressRings`, `ZResponsiveLayout`).
- **D2 (arête session) confirmée acyclique sur disque** (R-DEP levé) : `graph_proof` ACYCLIQUE, `CORE OUT=0`. Seule mutation `pubspec` : `+ zcrud_session: ^0.18.0`.
- **D3 (VO opaque)** : `ZSubfolderRef` (jamais `ZStudyFolder`) + `subfolderItemBuilder` injectable (`ZSubfolderNavSpec.itemBuilder`) — R-SUF2 neutralisé (aucun couplage à la signature de `ZFolderCard`).
- **R-SUF1 levé** : signatures SUF-1 relevées sur disque (`ZPageScaffold(title, leading, actions, search, tabs, mode)` ; `ZAppBarAction(icon, semanticLabel, onPressed?, tooltip?, isOverflow)` ; `ZAppBarSearchConfig(onQueryChanged, hintLabel?, initialQuery)` ; `ZPageTab(label, icon?, contentBuilder)`) — consommées telles quelles via le barrel.
- **AD-2/SM-1** : état DÉTENU par `ZStudyFolderDetail` (3 `ValueNotifier`, initState/dispose) ; sélection ⇒ seul le corps Matériel rebâtit ; repli/largeur ⇒ seule la sidebar rebâtit ; surbrillance scopée par item. Aucune I/O (largeur persistée par `onSidebarWidthChanged` injecté).
- **Nuance SM-1 honnête** : la garde « sélection ne rebâtit pas Progression » n'est pas falsifiable par un `setState` global (l'onglet Progression est hors-écran / non monté par `TabBarView`) — la garde SM-1 **mordante** retenue est « repli ne rebâtit pas le corps Matériel » (matCalls figé), prouvée rouge sous `setState` global. Documenté pour le code-review.
- **AD-13** : sidebar ancrée côté start (RTL prouvé runtime : bord droit à 900 en RTL, gauche en LTR), cibles ≥ 48 dp, `Semantics(selected:)`, actions sémantiques reorder « déplacer avant/après », libellés & thème injectés.
- **AD-4** : callbacks `null` = capacité absente (tri/ajout/menu/reorder/ajout-sous-dossier). **AD-10** : `progressData == null` ⇒ état vide neutre (jamais de throw), accent toujours résolu.
- Correctifs de dev notables : sélecteur compact en `SingleChildScrollView`+`Row` (un `ListView` horizontal en hauteur non bornée dans une `Column` levait « viewport not laid out ») ; `InkWell(excludeFromSemantics: true)` sous le `Semantics` de l'item (sinon les `customSemanticsActions` atterrissaient sur le mauvais nœud) ; `setScreen` de test via `view.physicalSize` (pour aligner `MediaQuery.sizeOf` avec la largeur locale).

### File List

**Créés (lib) :**
- `packages/zcrud_study/lib/src/presentation/z_subfolder_ref.dart`
- `packages/zcrud_study/lib/src/presentation/z_subfolder_nav_spec.dart`
- `packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart`
- `packages/zcrud_study/lib/src/presentation/z_subfolder_compact_selector.dart`
- `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart`

**Modifiés (lib/pubspec) :**
- `packages/zcrud_study/lib/zcrud_study.dart` (exports SUF-3)
- `packages/zcrud_study/pubspec.yaml` (`+ zcrud_session: ^0.18.0`)

**Créés (test) :**
- `packages/zcrud_study/test/support/suf3_harness.dart`
- `packages/zcrud_study/test/z_study_folder_detail_tabs_test.dart` (AC1–AC4)
- `packages/zcrud_study/test/z_study_folder_detail_material_progression_test.dart` (AC5, AC6)
- `packages/zcrud_study/test/z_subfolder_nav_adaptive_test.dart` (AC7)
- `packages/zcrud_study/test/z_subfolder_nav_selection_test.dart` (AC8, AC9)
- `packages/zcrud_study/test/z_subfolder_sidebar_test.dart` (AC10–AC13)
- `packages/zcrud_study/test/z_study_folder_detail_sm1_test.dart` (AC14)
- `packages/zcrud_study/test/z_study_folder_detail_rtl_a11y_test.dart` (AC15 runtime)
- `packages/zcrud_study/test/suf3_source_guard_test.dart` (AC1 statique, AC16 imports)

### Change Log

- SUF-3 : ossature de page-détail `ZStudyFolderDetail` + navigation de sous-dossiers adaptative (sidebar redimensionnable/repliable ↔ sélecteur compact) composant SUF-1/SUF-2/`ZSectionedStudyLayout`/`ZStudyProgressRings`/`ZResponsiveLayout` ; arête `zcrud_study → zcrud_session` (acyclique). Statut `ready-for-dev → review`.
