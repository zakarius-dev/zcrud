# Rétrospective — Epic EX-UI : Infrastructure UI transverse (responsive / navigation / ui-kit)

- **Skill** : `bmad-retrospective` (invoqué via le tool `Skill`). Chemin pris : **skill réel** (SKILL.md chargé, workflow party-mode). Exécution non-interactive (sous-agent) : le document est produit directement à partir des artefacts sur disque, sans dialogue party-mode simulé. Le nom de sortie est fixé par la consigne orchestrateur (`epic-ex-ui-retrospective.md`, non le nom horodaté par défaut du skill) ; **`sprint-status.yaml` n'est PAS modifié** par cette rétro (écriture ciblée réservée à l'orchestrateur).
- **Date** : 2026-07-16
- **Périmètre** : externalisation de **3 capacités UI dupliquées** dans les 4 apps (dodlp/iffd/lex_douane/dlcfti) — responsivité, grille dynamique, présentation CRUD adaptative — **et** câblage du maillon manquant responsivité↔présentation, en **3 nouveaux packages** (`zcrud_responsive`, `zcrud_navigation`, `zcrud_ui_kit`) + un binding (`zcrud_get`). AD ajoutés : **AD-29..AD-32**.
- **Statut des stories** (sprint-status) : **10 `done`** (EX-UI.1, .2, .3, .5, .6, .7, .8, .9, .10, .11) + **EX-UI.4 `superseded-core-e34`** (supprimée par réconciliation). Toutes les remédiations MEDIUM sont verrouillées par test (spot-check R3 orchestrateur).

---

## 1. Livré

Trois packages UI purs neufs, étagés sur `zcrud_core`, hexagonaux, **sans aucun gestionnaire d'état** (AD-2/AD-15), plus les impls GetX des ports dans le binding :

- **`zcrud_responsive`** (EX-UI.1/.2/.3) : `ZWindowSizeClass` M3 (compact/medium/expanded, seuils 600/840), `ZBreakpointValue<T>` générique multi-paliers, `ZResponsiveLayout` (3 builders), **`ZAdaptiveGrid` + `computeCrossAxisCount`** (clamp ≥ 1, largeur locale via `LayoutBuilder`, +AC9 padding/spacing). **Réutilise** les primitives `ZBreakpoint`/`ZResponsiveSpan`/`ZResponsiveGrid` déjà présentes dans `zcrud_core` (E3-4) — aucune redéclaration.
- **`zcrud_navigation`** (EX-UI.5/.6) : `ZEditionPresentation { page, sheet, dialog }`, `ZFormWeight`, `ZPresentationPolicy` (dérive le mode du breakpoint — **le maillon manquant**), port `ZFormPresenter` (jamais `sealed`), `ZAdaptivePresenter` (Flutter vanilla : `Navigator`/`showModalBottomSheet`/`showDialog`), `ZFormPresenterScope` (seam), fonction de câblage `presentEdition`.
- **`zcrud_ui_kit`** (EX-UI.7/.8/.9/.10) : `ZContentState` + `ZContentStateView` (aiguilleur exhaustif) + `ZEmptyState`/`ZLoadingState`/`ZErrorState`, `ZConfirmDialog` + `ZConfirmTone`, **port `ZToaster` + `ZToastSeverity`** + `ZScaffoldMessengerToaster` + `ZToasterScope`, `ZDiscardChangesGuard` (`PopScope` lié au `isDirty` du `ZFormController` via `ValueListenable<bool>`, lecture seule), `ZAlphabetIndexBar`, transitions **RTL-aware** (`zSlideBeginOffset`/`zPageRoute`).
- **`zcrud_get`** (EX-UI.11) : `ZGetFormPresenter` (impl GetX de `ZFormPresenter`) + `ZGetToaster` (impl GetX de `ZToaster`), avec overrides path dans `example/`.

**Métriques réelles (mesurées sur disque, code-reviews R3) :**

| Métrique | Valeur |
|---|---|
| `dart analyze` (chaque package) | **RC=0** (No issues found) sur les 4 packages |
| Tests par package (progression) | responsive 35→49→99 · navigation 14→33 · ui_kit 30→53→62→87 · zcrud_get 54/55 |
| `graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK** à chaque story (arêtes ENTRANTES au cœur uniquement) |
| `melos list` | **21 → 24** (N+3 : les 3 packages neufs ; `zcrud_get` préexistant) |
| Codegen | **no-op** confirmé (aucun `@ZcrudModel`/`build_runner` ⇒ 0 `.g.dart`, gate `codegen-distribution` non concerné) |
| `git status packages/zcrud_core` | **vide** — aucune story n'écrit le cœur (réutilisation seule) |

---

## 2. Ce qui a bien marché

**(a) Réutilisation du cœur plutôt que duplication.** La réconciliation E3-4 (voir §3-R-EXUI-1) a transformé un recouvrement raté en force : `zcrud_responsive` **dépend** de `zcrud_core` et réutilise `ZBreakpoint`/`ZResponsiveSpan`/`ZResponsiveGrid` sans les redéclarer ; EX-UI.4 supprimée (grille 12-col déjà dans le cœur) ; la grille d'items renommée `ZAdaptiveGrid` (jamais `ZResponsiveGrid`). Résultat : zéro collision de nom, `CORE OUT=0` intact.

**(b) Pureté et testabilité du domaine.** `ZPresentationPolicy.resolve`, `computeCrossAxisCount`, `zSlideBeginOffset` sont des fonctions **pures testables sans `BuildContext`**. Le câblage largeur→breakpoint→policy→mode→surface est matérialisé et testé bout-en-bout (`presentEdition`, 4 cas). Le bug latent iffd (`W ~/ minW` sans clamp → 0 colonne) est corrigé par conception (clamp `≥ 1` garanti, garde `children.isEmpty → SizedBox.shrink()`).

**(c) Discipline des invariants AD.** Aucun gestionnaire d'état dans les 3 packages purs ; ports `abstract interface class` **jamais `sealed`** (substituabilité prouvée par des fakes externes) ; couleur toujours dérivée du `ColorScheme` (aucun hex/`Colors.x`, grep NONE) ; switches exhaustifs sans `default` (ajout d'une valeur = erreur de compilation) ; RTL/a11y/≥48dp/`Semantics` sur toute surface ; consigne « enums > booléens » appliquée (`ZEditionPresentation`, `ZWindowSizeClass`, `ZContentState`, `ZToastSeverity`).

**(d) Parallélisation encadrée réussie.** P1 (`zcrud_responsive`, séquentiel intra-package après la tête EX-UI.1) ∥ P2 (`zcrud_navigation`) ∥ P3 (`zcrud_ui_kit`) sur **packages disjoints**, sans qu'aucune story n'écrive `zcrud_core`. Aucune collision, vérifs vertes par package ciblé, gate repo-wide au commit d'epic.

---

## 3. Incidents & leçons

**R-EXUI-1 — Réconciliation E3-4 : l'architecture delta avait manqué l'existant du cœur.**
Le spine EX-UI initial ignorait que `zcrud_core` possédait **déjà** un système responsive (E3-4) : `ZBreakpoint` 5-paliers Bootstrap, `ZResponsiveGrid` 12-col, `ZResponsiveSpan`. Détecté **par la vérif orchestrateur en `create-story` EX-UI.1**, pas par l'architecte. Résolution (décision user, Option A) : dépendre de core et réutiliser, supprimer EX-UI.4, renommer la grille d'items `ZAdaptiveGrid`. **Leçon** : *une architecture d'extension (delta) doit inventorier l'existant du cœur AVANT de planifier une externalisation ; sinon on redéclare/on entre en collision. La vérif-sur-disque de l'orchestrateur au démarrage de chaque story est le dernier rempart.*

**R-EXUI-2 — Change-request AC9 absorbé sans dette grâce au commit d'epic différé.**
En cours d'epic, l'utilisateur a demandé que `computeCrossAxisCount` prenne en compte `padding` + `spacing`. Story EX-UI.3 déjà `done` mais **non committée** → rouverte proprement : AC9 ajouté, delta re-développé, re-vérif + code-review dédié (`code-review-ex-ui-3-ac9.md`, HIGH0/MED0/LOW2 dont LOW-2 renforcé), rétro-compat prouvée (appel sans params == appel avec 0). **Leçon** : *le commit d'epic différé (jamais de commit intra-story) permet d'absorber un change-request sur une story « terminée » sans dette ni historique sale — la story reste malléable jusqu'au gate d'epic.*

**R-EXUI-3 — Discipline de test porteur : 6 MEDIUM contre des tests tautologiques.**
Le code de production était correct, mais plusieurs tests ne **rougissaient pas** quand la logique cassait :
- EX-UI.6 M1 : `maxHeight` du mode `sheet` non réellement couvert (contraste avec `maxWidth`/dialog porteur).
- EX-UI.7 M1 : annonce a11y du loading par défaut non couverte (fallback libellé absent).
- EX-UI.8 M1 : override `errorColor` du toast non couvert.
- EX-UI.9 M1 : test SM-1 « child non reconstruit » **tautologique** — remédié en portant l'assertion porteuse sur la bascule de `canPop` (re-sortie directe après flip).
- EX-UI.10 M1 : tap en config par défaut + scrub non couverts.
- EX-UI.11 M1 : confinement `get` non exhaustif (durcissement de couverture).

**Tous remédiés** (rendus porteurs) et confirmés par spot-check R3 orchestrateur. **Leçon** : *un test vert ne prouve rien ; il doit ROUGIR quand la logique casse. Un test « SM-1 » ou « couleur/rôle » qui coïncide avec le comportement par défaut ne détecte aucun oubli — dupliquer indépendamment le mapping attendu, ou casser volontairement l'invariant pour vérifier le rouge.*

**R-EXUI-4 — Échec API transitoire : agent mort, disque source de vérité.**
Le `create-story` EX-UI.6 est mort (connexion coupée) **sans écrire**. La vérif-sur-disque de l'orchestrateur a confirmé l'état propre (`git status`, absence de fichier story partiel) **avant** de relancer, sans faire confiance au rapport de l'agent mort. **Leçon** : *ne jamais enchaîner sur la foi du rapport d'un agent planté ; vérifier l'état git/disque réel puis relancer un agent de reprise (cf. consigne de surveillance des sous-agents).*

**R-EXUI-5 — Gate repo-wide : une régression cwd invisible en par-package.**
Un test d'EX-UI.9 utilisait un **chemin relatif** dépendant du cwd : vert lancé depuis le package, **rouge depuis la racine**. Détecté par le code-review EX-UI.10 (suite repo-wide) et remédié (L-1). Par ailleurs, l'ajout des 2 arêtes de `zcrud_get` (→ `zcrud_navigation`/`zcrud_ui_kit`) a nécessité des **overrides path** dans `example/pubspec.yaml`. **Leçon** : *la vérif ciblée par-package ne suffit pas ; le gate repo-wide (`melos analyze` + `melos verify` + suite complète depuis la racine) reste NON-NÉGOCIABLE au commit d'epic — il attrape cwd, arêtes cross-package et symboles cassés.*

*(LOW consignés, non bloquants : LICENSE/README systémiques au niveau monorepo, nits dartdoc, dette a11y assumée sur transitions, code défensif mort documenté dans `computeCrossAxisCount`.)*

---

## 4. Action items

| ID | Libellé | Owner |
|---|---|---|
| **AI-EXUI-1** | **Inventorier l'existant du cœur avant tout spine d'extension.** Ajouter au workflow d'architecture delta une étape explicite « recensement des symboles/capacités déjà exportés par `zcrud_core` » pour éviter un nouveau recouvrement type E3-4. | Architecte |
| **AI-EXUI-2** | **Critère d'AC « test porteur » systématique.** Poser en gabarit d'AC : tout test de mapping/aiguillage/invariant doit démontrer qu'il rougit sur cassure (mapping dupliqué indépendamment, ou mutation volontaire vérifiée). | SM / auteur de story |
| **AI-EXUI-3** | **Gate repo-wide anti-cwd.** Interdire les chemins relatifs cwd-dépendants dans les tests ; exécuter au moins une passe de suite complète depuis la racine à chaque commit d'epic. | Mainteneur CI |
| **AI-EXUI-4** | **Câbler `presentEdition`/`ZFormPresenter` dans le binding `zcrud_riverpod` (go_router)** lorsque `go_router` sera pinné — symétrie avec `zcrud_get` (cf. DW-EXUI-2). | Mainteneur bindings |

---

## 5. Dette / suite actée

- 🟡 **DW-EXUI-1 — Adoption in-place dans les apps = sessions dédiées.** Remplacer les ~24 grilles dupliquées par `ZAdaptiveGrid`, les ~79 call-sites `showPushedDialog` par `ZFormPresenter` + `ZPresentationPolicy`, consolider les 4 impls de breakpoints — **app par app, hors monorepo** (aucun fichier dodlp/iffd/lex_douane/dlcfti touché depuis cette phase).
- 🟡 **DW-EXUI-2 — Présentateur go_router dans `zcrud_riverpod`.** L'impl du port `ZFormPresenter` côté Riverpod reste à livrer ; requiert de **confirmer/pinner `go_router`** (pas encore dépendance du binding). Le binding GetX (`zcrud_get`) est fait (EX-UI.11).
- 🟢 **Info-lints `zcrud_study`** : lints informatifs préexistants hors périmètre EX-UI, à traiter dans une passe dédiée (aucun impact sur les 4 packages EX-UI, analyze RC=0 sur ceux-ci).
- 🟢 **LICENSE/README systémiques** : ajout des fichiers LICENSE manquants à traiter au niveau monorepo (LOW récurrent EX-UI.1/.5), hors périmètre story.
- 🟢 **Dette a11y transitions** (EX-UI.10 L-2) et libellé de repli loading (durci en EX-UI.7) : assumées/consignées, sans blocage.

---

*Contrainte respectée : `sprint-status.yaml` non modifié par cette rétro (l'entrée `epic-ex-ui-retrospective` reste sous contrôle de l'orchestrateur).*
