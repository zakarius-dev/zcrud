# Rétrospective — Epic `epic-suf` (E-STUDY-UI : Folders & Page-shell)

- **Skill** : `bmad-retrospective` (tool `Skill`, invocation réelle — mode non-interactif, options conservatrices, choix consignés).
- **Date** : 2026-07-26 · **Facilitation** : Amelia (Developer). Participants simulés : Alice (PO), Charlie (Senior Dev), Dana (QA), Elena (Junior Dev), Zakarius (Project Lead).
- **Périmètre** : SUF-1 → SUF-4, **4/4 stories `done`**, livrées au tag **v0.19.0** (commit `f6b2df6`).
- **Clé sprint-status** : `epic-suf-retrospective` (`backlog → done` — **transition appliquée par l'orchestrateur**, hors périmètre de ce fichier ; cette rétro n'a modifié AUCUN autre fichier).
- **Source de plan** : `/home/zakarius/.claude/plans/tingly-brewing-cake.md`.

---

## 1. Ce que l'epic a livré

Mandat : combler deux trous prouvés par grep négatif au cadrage — **aucune carte de dossier d'étude**, **aucune ossature de page-détail**, et **aucune abstraction de page/app-bar** dans tout zcrud (alors qu'IFFD a `DynamicSearcheableAppBar` et que lex duplique `SliverAppBar` sur **11** écrans — chiffre corrigé sur disque par SUF-1, la consigne disait ~6).

| Story | Livrable | Package |
|---|---|---|
| SUF-1 | `ZPageScaffold` / `ZSearchableAppBar` : page-shell déclaratif (titre/leading/`actions[]` en données/recherche à état détenu/tabs/4 modes sliver), 6 types publics | `zcrud_ui_kit` |
| SUF-2 | `ZFolderCard` : carte de dossier neutre à props primitives, accent par `colorKey`, slots counts/menu, badge archivé injecté, golden neutre | `zcrud_study` |
| SUF-3 | `ZStudyFolderDetail` : header + 3 onglets composés (Matériel/Notebook/Progression) + **navigation de sous-dossiers adaptative** (sidebar redimensionnable/repliable ↔ sélecteur compact) | `zcrud_study` |
| SUF-4 | Audit de parité session (4 paires, `docs/parity-session-widgets-2026-07-26.md`), **3 écarts réels fermés par slots injectables** (`ZSessionProgressStyle.linear`, `ZSrsQualityEmphasis`, `ZQualityBreakdownCoverage`) + **1 écart réfuté par preuve négative**, démo assemblée bout-en-bout | `zcrud_session` (+ démo `zcrud_study/test/`) |

**Vérité de clôture (rejouée par l'orchestrateur, pas sur la foi des agents)** : `melos run analyze` **RC=0** · `melos run verify` **RC=0** (10 gates) · `graph_proof` **ACYCLIQUE / CORE OUT=0**, **69 arêtes** (une seule neuve : `zcrud_study → zcrud_session`, consommée réellement) · tests **ui_kit 120 · study 620 · session 543 · example 97**. **Zéro écriture `zcrud_core`** sur tout l'epic, conformément au plan.

---

## 2. Qualité — code-review multi-lentilles (7 lentilles, opt-in permanent du owner)

| Lentille | Verdict | Signature dominante |
|---|---|---|
| Conformité AD | **BLOQUANT** | 2 HIGH reproduits empiriquement, tous deux dans le shell SUF-1 |
| Adversariale | **BLOQUANT** | 4 findings **tous aux coutures entre stories** (SUF-1↔SUF-3, SUF-2↔SUF-3) |
| SM-1 / perf | RÉSERVES | 1 HIGH + 1 MAJEUR + 2 MEDIUM (rebuilds contredisant la dartdoc) |
| Tests porteurs | RÉSERVES | 2 MAJEUR + 2 MEDIUM : **trous de falsifiabilité**, pas de bugs |
| A11y / RTL | RÉSERVES | 2 MAJEUR (poignée de resize inaccessible ; carte non-interactive à arbre sémantique vide) |
| L10n / thème | RÉSERVES | 4 MEDIUM : 2 points d'injection manquants, 2 libellés |
| Réalité du code | RÉSERVES | 3 chiffres/affirmations de rapport ne résistant pas au rejeu |

**Bilan** : **2 HIGH + 7 MAJEUR corrigés, 0 refus**, MEDIUM traités ou justifiés, vérif verte rejouée avant `done`.

Fait notable de méthode : la lentille « réalité du code » a **rejoué 8/8 des greps négatifs** du livrable d'audit SUF-4 et les a trouvés conformes, tout en **durcissant** l'un d'eux (`selected:` → `selected`, absence plus forte que revendiquée). C'est le meilleur résultat d'audit de la série d'epics : l'exigence « chemin + n° de ligne des deux côtés » a produit un document rejouable.

---

## 3. Les cinq prises de la rétro

### 3.1 Deux gardes non falsifiables ont failli passer — et une seule chose les a arrêtées

**Les faits.** SUF-3 a livré `z_study_folder_detail_sm1_test.dart:25` sous le titre *« changer la sélection 10× reconstruit le corps Matériel, **PAS Progression** »* avec, ligne 57, `expect(progBuilds, progBaseline)`. Cette assertion est **vraie par construction** : `TabBarView` → `PageView` avec `allowImplicitScrolling = false` ⇒ cache extent 0 ⇒ l'onglet Progression n'est **jamais monté**. Son « contrôle de falsifiabilité » contrôlait la sonde, pas l'assertion. La story **avouait** la nuance en Dev Notes… mais **le test est resté dans le fichier avec un titre qui promet le contraire**. SUF-4, lui, a découvert seul qu'une de ses gardes ne mordait pas (corpus symétrique `4/1` ⇒ fraction `0,5` ⇒ `1 - value == value`) et a durci le corpus en `2/5`.

**Le diagnostic.** Les deux cas ont la **même racine** : *la valeur de vérité de l'oracle a été supposée, pas mesurée*. Le rituel R3 (« ré-injecter la régression, constater le rouge ») est exactement l'antidote — mais il n'a été appliqué qu'à **7 des 16 ACs** de SUF-3 (table `suf-3…md:210-218`), et jamais sur l'AC concernée. Là où il a été appliqué (SUF-4 : 13 injections, 13 rouges ; SUF-2 : 14 gardes ; SUF-1 : 15 ACs), **aucune garde tautologique n'a survécu**.

**Charlie (Senior Dev)** : « On n'a pas un problème de discipline R3, on a un problème de *couverture* de la discipline R3. Elle marche à 100 % là où on l'exécute. Le trou, c'est qu'on la déclare par AC et qu'on l'exécute par échantillon. »

**Réponse à la question posée — quel garde-fou empêche une garde tautologique d'être *écrite* ?** Trois leviers, du moins cher au plus cher :

1. **Ratio d'injection = AC, mesurable et exigible.** La table R3 du Dev Agent Record doit compter **autant de lignes que d'ACs porteuses de garde**. Une AC sans ligne d'injection = **AC non prouvée**, à traiter comme un AC non satisfait. C'est un contrôle *mécanique* que l'orchestrateur peut appliquer en lisant la story, sans relire le code (SUF-3 : 7 lignes / 16 ACs aurait rougi immédiatement).
2. **Règle du montage explicite pour toute garde « tranche figée ».** Toute assertion de la forme « X n'a PAS rebâti » doit d'abord **prouver que X est monté et rebuildable** dans le harnais — sinon elle mesure l'absence, pas la granularité. Formulation opérationnelle : *le contrôle de falsifiabilité doit porter sur l'assertion elle-même (faire monter le compteur de X par un `setState` global), jamais sur la sonde générique.*
3. **Ce que la revue ne peut pas remplacer.** Il faut acter que la lentille « tests porteurs » **a fonctionné** (elle a produit la preuve SDK, ligne à ligne, jusqu'à `page_view.dart:693`). Elle reste le filet ; l'objectif des points 1-2 est de **réduire ce qui lui arrive**, pas de la supprimer.

### 3.2 « État figé à `initState` face à des props déclaratives » — motif générique, mérite une règle

**Les faits.** Les **2 HIGH** de l'epic sont le même bug sous deux formes, tous deux dans SUF-1 :

- `ZPageScaffold` : `_controller` créé conditionnellement (`if (_isSliver)`, `z_page_scaffold.dart:75`) puis déréférencé `_controller!` (`:146`). Or `mode` est une **prop déclarative d'un widget immuable** — un shell adaptatif la change naturellement. Passer `fixed → floating` sur le même élément ⇒ **crash `Null check operator used on a null value`** (reproduit).
- `ZSearchableAppBar` : `ZAppBarSearchConfig` capturée à `initState` ⇒ une config remplacée est **silencieusement ignorée**, la frappe part vers un **callback mort**.
- Même famille, moindre gravité : `initialSelectedSubfolderId` snapshotté en SUF-3 (`:182-184`) ⇒ réutiliser la page pour un autre dossier à la même position d'arbre conserve la sélection périmée. `grep didUpdateWidget` sur les trois fichiers du shell → **RC=1**.

**Alice (PO)** : « C'est la troisième fois que ce motif nous coûte un HIGH — su-3 avait déjà le minuteur figé après changement de carte. »

**Verdict de la rétro : OUI, cela mérite une règle explicite**, formulée comme un invariant de revue plutôt que comme une AD nouvelle (aucune écriture d'architecture n'est nécessaire) :

> **Règle « prop déclarative ⇒ `didUpdateWidget` ou contrat de `Key` écrit ».** Tout `StatefulWidget` public dont une prop (a) décide de la **création** d'un objet d'état, (b) est **capturée** dans un champ/closure, ou (c) porte le préfixe `initial*`, doit **soit** implémenter `didUpdateWidget` qui la re-synchronise, **soit** documenter dans sa dartdoc que l'hôte doit fournir une `Key` distincte — et **porter un test qui change la prop sur le même élément**. Le troisième cas (`initial*`) est le plus traître : le nom *suggère* la sémantique sans que rien ne l'impose.

Le test associé est trivial et générique : `pumpWidget(page(A)); pumpWidget(page(B)); expect(takeException(), isNull)` + assertion sur l'effet de B. Il a démasqué les deux HIGH en trois lignes.

### 3.3 `melos analyze` rouge repo-wide, non détecté — **3ᵉ occurrence du même mode de défaillance**

**Les faits.** Une erreur d'analyse **pré-existante**, introduite par le commit `1e4ba5e` (CR-LEX-10/11, ajout de `ZLocalStore.purge`/`putMerged`), laissait `example/test/offline_demo_test.dart:146` non compilable (« Missing concrete implementations »). Elle a survécu **plusieurs commits** avant d'être découverte pendant SUF-4 — puis corrigée dans le périmètre de l'epic.

**La racine, prouvée sur disque.** `example/` est **délibérément hors du bloc `workspace:`** du `pubspec.yaml` racine (frontière EX-1 : lock propre, résolution locale isolée). Donc :

```
$ dart run melos list | grep -c example   →  0
```

⇒ `melos run analyze:packages` (`melos exec -- dart analyze .`) **ne peut structurellement pas voir `example/`**. Ce n'est pas un oubli d'exécution, c'est un **trou de portée du gate**.

**Ce qui rend cette leçon coûteuse : c'est la troisième fois.**

| # | Zone aveugle | Symptôme | Rustine appliquée |
|---|---|---|---|
| 1 | Cross-package (E11a-3) | `ZExportApi` supprimé, `zcrud_flashcard` cassé ; `melos analyze` RED plusieurs commits | Règle CLAUDE.md : rejouer `analyze` **repo-wide** au gate de commit d'epic |
| 2 | `scripts/` hors vue melos | `gate_reserved_keys.dart` cassé par analyzer 12 **sous un analyze VERT** | Script `analyze:scripts` ajouté à la chaîne `analyze` |
| 3 | **`example/` hors workspace** (cet epic) | `offline_demo_test.dart` non compilable, invisible de tous les gates | *(à faire — AI-SUF-1)* |

Le cas n°2 est la preuve que **la rustine correcte est connue** : quand une zone échappe à `melos exec`, on l'ajoute **explicitement** à la chaîne `analyze`. Elle n'a simplement jamais été appliquée à `example/`.

**Dana (QA)** : « On a répété deux fois "rejouer analyze repo-wide". Le problème n'est pas la fréquence, c'est que `analyze` **ment sur son propre périmètre**. Une commande nommée "analyse complète" qui ignore un répertoire de 97 tests, c'est un gate qui se trompe lui-même. »

**Ce qu'il faut changer pour qu'il n'y ait pas de 4ᵉ fois** — deux actions, la seconde étant la vraie :

1. **Fermer le trou connu** : `analyze:example` (`cd example && flutter analyze`) ajouté à `analyze` **et** à `verify`. Coût : deux lignes de `pubspec.yaml`/`melos.yaml`. (AI-SUF-1)
2. **Fermer la *classe* de trou** : un gate **`analyze:coverage-proof`** qui énumère les répertoires contenant un `pubspec.yaml` sous la racine et **échoue si l'un d'eux n'est couvert ni par `melos list`, ni par une entrée explicite de la chaîne `analyze`**. C'est le seul dispositif qui rend l'apparition d'une 4ᵉ zone aveugle **impossible en silence** — les trois occurrences auraient été attrapées à leur naissance, pas des commits plus tard. (AI-SUF-2)

Sans le point 2, la 4ᵉ occurrence n'est qu'une question de prochain répertoire ajouté hors workspace.

### 3.4 Code-review unique consolidée en fin d'epic : le bilan est **positif**, avec une réserve nette

**Ce que ça a rapporté — mesurable.** La lentille adversariale l'écrit noir sur blanc : ses **4 findings sont tous aux coutures entre stories** (SUF-1 fournit le shell / SUF-3 le consomme ; SUF-2 fournit une carte / SUF-3 un `itemBuilder`) et *« aucun n'est visible en lisant une story isolément, ce qui explique qu'ils aient traversé les revues par story »*. Concrètement :

- **F1 (HIGH, crash `fixed→sliver`)** : invisible depuis SUF-1 seule — aucun test SUF-1 n'exerce le mode sliver **avec** recherche (`grep search test/z_page_scaffold_sliver_test.dart` → RC=1) ; c'est l'idée d'un *shell adaptatif consommé par une page réelle* (SUF-3) qui rend la transition de mode évidente.
- **F3 (MAJEUR)** : `ZSubfolderNavSpec.itemBuilder` honoré par la sidebar, **ignoré** par le sélecteur compact — un écart **entre deux fichiers de la même story**, mais que seule une lecture transversale du seam révèle.
- **F2 (HIGH, callback mort)** : celui-ci, une revue SUF-1 par story aurait pu l'attraper — c'est un défaut intra-widget.

**Réponse honnête à la question posée** : **un seul des deux HIGH** (F2, config gelée) était raisonnablement trouvable par une revue SUF-1 isolée. F1 exigeait la vue d'ensemble. Le solde net est donc **favorable à la consolidation**, d'autant que les 7 lentilles ont couvert *les 4 stories à la fois* — la couverture est venue du **nombre de lentilles**, exactement comme le postule la règle CLAUDE.md.

**La réserve, réelle.** Le coût s'est payé en **contexte d'exécution dégradé** : au moment des revues, `zcrud_markdown` était laissé non compilable par un **workstream parallèle**, ce qui a empêché **4 des 7 lentilles** de jouer les tests de `zcrud_study`/`zcrud_session`. Plusieurs findings (F3/F4/F5 SM-1, F3/F4 adversariale) sont établis **structurellement** (lecture + greps + source du SDK) et non empiriquement — les lentilles l'ont consigné honnêtement, mais c'est une dette de preuve. **Une revue en fin d'epic doit être ordonnancée à un moment où l'arbre compile** — c'est-à-dire **workstreams au repos**, la même condition que le gate de commit.

**Elena (Junior Dev)** : « Et les deux HIGH ont été trouvés *après* que les 4 stories soient passées `review`. Si l'epic avait été plus long, on aurait empilé du code sur un shell qui crashe. »
**Charlie** : « D'où la nuance : consolidé **oui**, mais borné à un epic court. Au-delà de ~4-5 stories, il faut une revue intermédiaire. »

### 3.5 Parallélisation : gain réel mais **modeste**, et une externalité qui a coûté

Réalité obtenue : **SUF-1 ∥ SUF-2** seulement (packages disjoints, `zcrud_ui_kit` vs `zcrud_study`), puis **séquentiel imposé** — SUF-3 dépend de SUF-1 **et** SUF-2 ; SUF-4 est explicitement « DERNIÈRE ». La règle de garde-fou « jamais deux stories en vol sur le même package » a par ailleurs interdit SUF-2 ∥ SUF-3 (même `zcrud_study`), à raison.

**Gain** : 1 paire sur 6 possibles, sur la story **L** et la story **M** — le gain porte donc sur la partie légère de l'epic, pas sur la XL (SUF-3) qui est le chemin critique.

**Coût, non anticipé** : le workstream **parallèle hors epic** (`zcrud_markdown`, commit `9819ed9`) a laissé l'arbre non compilable pendant la fenêtre de revue, dégradant 4 lentilles sur 7 (§3.4). C'est une externalité de la parallélisation **inter-epics**, pas intra-epic — et elle n'est couverte par aucun garde-fou existant : les cinq garde-fous CLAUDE.md portent sur les *stories en vol*, aucun n'exige qu'un workstream **laisse l'arbre compilable** à ses points de pause.

**Conclusion** : la parallélisation intra-epic a été correctement bornée par le graphe de dépendances et n'a rien cassé. Le vrai enseignement est ailleurs : **un workstream parallèle doit garantir la compilabilité de l'arbre**, sinon il taxe silencieusement toutes les vérifications des autres.

---

## 4. Ce qui a bien marché (à reproduire)

- **Décisions tranchées AVANT dev, avec preuve disque** (SUF-1 D1/D2/D3, SUF-4 T0) : deux affirmations de consigne **corrigées** par grep (« ~6 écrans » → **11** ; arêtes `zcrud_mindmap`/`zcrud_exam` **re-prouvées dures**). Le conflit structurel de la démo a été détecté **au create-story**, pas au dev — et résolu sans dégrader l'invariant AC10 de su-10 (voie (b) : démo assemblée dans `zcrud_study/test/`, `example/pubspec.yaml` et `boundary_deps_test.dart` **inchangés**).
- **Fermeture d'écart par slot injectable, jamais par look codé en dur** (SUF-4) : les 3 slots ont un **défaut = rendu historique exact**, prouvé ligne à ligne par la lentille l10n/thème (dont l'équivalence byte-à-byte `borderRadius:` → `shape:` via `material.dart:498-499`). **Zéro régression** sur 543 tests session.
- **Preuve négative assumée** (paire 3) : refuser d'écrire du code là où l'écart n'est pas réel, et le **prouver** (`FilterChip` absent RC=1 ; stepper en fait **présent et plus configurable** que lex ; `inMutuallyExclusiveGroup` absent **et correct**, avec contre-preuve d'usage ailleurs dans le même package). C'est le contraire d'un écart enterré.
- **Deux défauts réels attrapés par des gardes neuves** en SUF-4, mesurés et non anticipés : `semanticsValue: null` ne tait pas un `LinearProgressIndicator` (double annonce `['2/4','50']`) ; `ZcrudScope` sous le `MaterialApp` invisible des écrans poussés.
- **Composition plutôt que réimplémentation** (SUF-3) : aucune app-bar, recherche, layout study-tools ni mécanique responsive réécrits — `ZPageScaffold` + `ZSectionedStudyLayout` + `ZStudyProgressRings` + `ZResponsiveLayout` assemblés. Une seule arête de graphe ajoutée, réellement consommée.

---

## 5. Dette ouverte à l'issue de l'epic

| Objet | Sévérité résiduelle | Où |
|---|---|---|
| Trous de falsifiabilité SUF-3 : `addAction` jamais exercé, `initialSelectedSubfolderId` jamais exercé, garde SM-1 Progression tautologique | MAJEUR/MEDIUM (traités ou justifiés au gate) | `code-review-epic-suf-tests-porteurs.md` F1-F3 |
| `tabController` non ré-exposé par `ZStudyFolderDetail` ; `ZSubfolderRef(id: '')` sentinelle racine non documentée ; parité pastille 12 vs 14 dp | MEDIUM/LOW | `code-review-epic-suf-adversariale.md` F4 |
| Points d'injection manquants : `centerTitle` en dur ; `linearThickness` non propagé par le swiper | MEDIUM | `code-review-epic-suf-l10n-theme.md` F1-F2 |
| `'hors échelle: '` en dur (pré-existant) ; replis a11y `?? allSubfoldersLabel` sur 3-4 contrôles distincts | MEDIUM | `…-l10n-theme.md` F3-F4, `…-a11y-rtl.md` F3 |
| `ZSubfolderCompactSelector` non virtualisé sur liste injectée non bornée | LOW | `code-review-epic-suf-sm1-perf.md` F5 |
| Findings SUF-3 établis **structurellement** (non rejoués empiriquement, `zcrud_markdown` cassé au moment de la revue) | dette de **preuve** | F3 adversariale, F3-F5 SM-1 |

---

## 6. Action items — `AI-SUF-*`

| # | Action | Priorité | Owner | Critère de complétion |
|---|---|---|---|---|
| **AI-SUF-1** | Ajouter **`analyze:example`** (`cd example && flutter analyze`) à la chaîne `analyze` **et** à `verify` (`pubspec.yaml` racine + `melos.yaml`) | **Haute** | Orchestrateur | `melos run analyze` rougit sur une erreur volontairement injectée dans `example/test/` ; RC=0 après retrait |
| **AI-SUF-2** | Gate **`analyze:coverage-proof`** : énumérer tout répertoire portant un `pubspec.yaml` et **échouer** s'il n'est couvert ni par `melos list` ni par une entrée explicite de `analyze` — ferme la **classe** de trou (3 occurrences : cross-package E11a-3, `scripts/`, `example/`) | **Haute** | Orchestrateur / Dev | Script de gate committé ; retirer `analyze:example` de la chaîne fait **rougir** le gate |
| **AI-SUF-3** | **Ratio d'injection R3 = nombre d'ACs porteuses de garde.** Un Dev Agent Record dont la table R3 compte moins de lignes que d'ACs gardées est traité comme **AC non satisfaite** — contrôle appliqué par l'orchestrateur à la lecture de la story, avant `review` | **Haute** | Orchestrateur | Appliqué dès la prochaine story ; SUF-3 (7/16) aurait été refusé |
| **AI-SUF-4** | **Règle « garde tranche figée »** : toute assertion « X n'a PAS rebâti » doit d'abord prouver que **X est monté** dans le harnais, et son contrôle de falsifiabilité doit porter sur **l'assertion**, pas sur une sonde générique. Inscrire dans la convention R3 des `bmad-create-story` | **Haute** | Orchestrateur / SM | Convention citée dans la prochaine story ; lentille « tests porteurs » ne remonte plus de garde non montée |
| **AI-SUF-5** | **Règle « prop déclarative ⇒ `didUpdateWidget` ou contrat de `Key` écrit »** (cf. §3.2), + test générique obligatoire « changer la prop sur le même élément » pour tout `StatefulWidget` public dont une prop décide d'une création d'état, est capturée, ou est nommée `initial*` | **Haute** | Dev / lentille Conformité AD | Règle citée dans la prochaine story UI ; lentille AD la vérifie explicitement |
| **AI-SUF-6** | **Un workstream parallèle doit laisser l'arbre compilable à ses points de pause** ; corollaire : la code-review consolidée d'epic est ordonnancée **workstreams au repos** (même condition que le gate de commit) | **Haute** | Orchestrateur | Prochaine revue consolidée : 7/7 lentilles peuvent jouer les tests réels, 0 finding « établi structurellement faute de compilation » |
| **AI-SUF-7** | **Revue intermédiaire au-delà de ~4-5 stories** : conserver la revue consolidée en fin d'epic (bénéfice prouvé sur les coutures) mais insérer une revue à mi-parcours dès qu'un epic dépasse ce seuil, pour ne pas empiler du code sur une fondation non revue | Moyenne | Orchestrateur | Seuil appliqué au découpage du prochain epic long |
| **AI-SUF-8** | **Solder la dette de preuve SUF-3** : rejouer empiriquement F3 adversariale (`itemBuilder` ignoré par le sélecteur compact) et F3-F5 SM-1 maintenant que `zcrud_markdown` est vert | Moyenne | Dev / QA | Repro exécuté sur `zcrud_study` ; findings confirmés ou infirmés par exécution |
| **AI-SUF-9** | Solder les MEDIUM résiduels §5 : `centerTitle` injectable, `linearThickness` propagé par le swiper, `'hors échelle: '` externalisé, replis a11y distincts, `tabController` ré-exposé, `ZSubfolderRef` racine (`null` ou `isRoot`) documentée | Moyenne | Dev | Chaque MEDIUM fermé ou justifié par écrit ; suite verte |
| **AI-SUF-10** | Exiger un **marqueur d'élision** dans toute sortie de commande citée en livrable d'audit (finding « réalité du code » F3 : sorties tronquées sans `…`), et une **note de variance au niveau de l'AC** quand une clause d'AC est délibérément non tenue (AC9 SUF-4) | Basse | SM / tech-writer | Prochain livrable d'audit conforme |

---

## 7. Prochaines étapes

1. L'orchestrateur applique la transition sprint-status `epic-suf-retrospective: backlog → done` (**hors périmètre de cette rétro**).
2. **AI-SUF-1 puis AI-SUF-2 avant tout nouveau dev** : tant que `analyze` ment sur son périmètre, aucune vérif verte n'est fiable — c'est le seul action item qui invalide les autres s'il n'est pas fait.
3. **AI-SUF-3/4/5** sont des règles de rédaction/revue : elles ne coûtent rien à appliquer et s'activent dès le prochain `bmad-create-story`.
4. La cible **lex_douane** est désormais servie : page-shell, carte de dossier, page-détail adaptative et parité session sont livrés en widgets publics neutres, bridgeables app-side sans écrire dans zcrud.

**Amelia (Developer)** : « SUF a livré son mandat — les deux trous d'UI d'étude sont comblés et l'audit session ne laisse aucun écart non instruit. Mais l'epic nous rend deux vérités inconfortables : nos gardes ne mordent que là où on les mord, et notre commande d'analyse ne regarde pas tout ce qu'elle prétend regarder. Les deux se corrigent par des règles mécaniques, pas par plus de vigilance. »
