# Rétrospective — Epic E4 : Moteur DynamicList (zcrud_list, Syncfusion par défaut)

- **Date** : 2026-07-10
- **Projet** : zcrud
- **Skill** : `bmad-retrospective` (VRAI skill invoqué via le tool `Skill`, args `retro epic 4`). Chemin pris : **Skill tool** — workflow chargé et exécuté depuis `.claude/skills/bmad-retrospective/SKILL.md`.
- **Couvre** : FR-6..FR-8 · AD-8 (isolation Syncfusion / SM-5), AD-11 (`Either`/état dérivé), AD-16 (pagination curseur neutre + ACL). **Dépend de** : E2. **Débloque** : E7 (intégration DODLP). **Phase** : MVP.
- **Format** : exécution non-interactive (subagent orchestré). Le dialogue party-mode est **synthétisé à partir des artefacts réels** (5 stories, 5 code-reviews, sprint-status, epics.md, architecture.md) — aucune vérification n'a été « jouée de mémoire ». Les résultats de gates cités proviennent des code-reviews qui les ont **rejoués sur disque**.

---

## 1. Résumé de livraison

| Métrique | Valeur |
|---|---|
| Stories `done` | **5 / 5** (e4-1, e4-2, e4-3, e4-4, e4-5) — epic **complet** |
| Verdicts code-review | 4× **APPROVED** (e4-1, e4-2, e4-4, e4-5) · 1× **CHANGES REQUESTED** (e4-3, corrigé puis vert) |
| Findings HIGH / MAJEUR | **0** sur toute l'epic |
| Findings MEDIUM | **3** — e4-1 M1 (preuve SM-5 sur-vendue), e4-3 M-1 (réponse async obsolète), e4-4 MEDIUM-1 (source reconstruite à chaque rebuild) — **tous corrigés** |
| Findings LOW | ~13 (nits/défensifs/documentés) — triviaux corrigés, reste consigné et rattaché (voir §5) |
| Objectif d'isolation (SM-5 / AD-8) | ✅ **PROUVÉ ET DURCI** — `zcrud_core` ne tire jamais Syncfusion ; `ZSfDataGridRenderer` seule arête Syncfusion (voir §2) |
| Bug historique 3 apps | ✅ **Sélection multiple corrigée** (état keyé par `id` hors renderer + grille stateful) |
| Gates CI | Anti-`reflectable`, scan secrets, codegen, graphe CORE OUT=0, pureté présentation/RTL : **verts** à chaque `done` |
| Vérif verte finale (e4-5) | analyze RC=0 · `flutter test` zcrud_list **20 tests** RC=0 · `melos run verify` : `out-degree(zcrud_core)=0`, `ACYCLIQUE OK`, `CORE OUT=0 OK` · 14 pkgs · 0 `.g.dart` committé |

---

## 2. Enjeu headline — SM-5 (isolation Syncfusion) prouvé **et durci**

Le risque n°1 de l'epic n'était pas fonctionnel mais **architectural** : un « faux vert » de la preuve d'isolation. AD-8/SM-5 exige qu'un consommateur qui ne dépend pas de `zcrud_list` ne tire **jamais** Syncfusion. E4 le prouve sur 3 plans, avec un **contrôle positif auto-validant** :

- **(a)** fermeture de `zcrud_core` **sans** `syncfusion*` ;
- **(b)** `zcrud_markdown` **sans** `syncfusion*` (ancrage PRD) ;
- **(c)** **contrôle positif** : `zcrud_list` **contient bien** `syncfusion_flutter_datagrid` (garantit que le détecteur détecte réellement) ;
- **(d)** acyclicité ciblée `zcrud_list → zcrud_core`, `out-degree(zcrud_core)` sur `zcrud_*` = 0.

Le durcissement clé vient de **e4-1 M1** : la preuve initiale reposait sur `_directDeps` qui renvoyait `null` (feuille) pour tout package **externe**, donc ne traversait pas les transitifs externes — et le commentaire d'en-tête **sur-vendait** la garantie (« suit TOUTES les dépendances »). Corrigé en fondant la preuve sur la **résolution réelle** (`dart pub deps --json` → vrai graphe transitif résolu, externe inclus). La preuve est passée de *« vraie pour les intermédiaires locaux »* à *« transitive-réelle »*. `ZSfDataGridRenderer` reste la **seule** arête Syncfusion de tout le graphe.

Complément de conception (e4-4) : `ZListInteraction` (callbacks non comparables) vit **hors** `ZListRenderRequest` — la statefulness Syncfusion est cantonnée à `_ZSfDataGrid`/`_ZListDataGridSource` dans `zcrud_list` et ne pollue pas le value object du cœur (préserve l'égalité de valeur E4-1/E4-2, aucune fuite de statefulness L2 dans le cœur).

---

## 3. Discussion d'équipe (synthèse party-mode)

Amelia (Developer) : « E4 avait deux promesses : dériver liste **et** formulaire du même `ZFieldSpec[]`, et **isoler une dépendance lourde** (Syncfusion) derrière un port. Ce qui m'a marquée, c'est que le vrai travail dur n'était pas d'afficher une grille — c'était de **prouver honnêtement** qu'on ne contamine pas le cœur. »

Charlie (Senior Dev) : « Et le premier jet de cette preuve était piégeux. Sur e4-1, le "vert" passait, mais la fermeture ne traversait pas les transitifs des paquets **externes** — un tiers qui aurait tiré syncfusion serait passé inaperçu. Le contrôle positif ne couvrait que la détection *directe*. Le finding M1 n'était pas "ça casse aujourd'hui" (impact pratique nul), c'était "**la preuve affirme plus qu'elle ne démontre**". On l'a refondée sur `dart pub deps --json`. »

Dana (QA Engineer) : « Le pattern se répète depuis E2/E3 : le "vert" prouve ce qu'on a pensé à tester ; le code-review adversarial capte l'invariant qu'on n'a pas pensé à exercer. Sur **e4-3**, c'était la concurrence async : `search-as-you-type` peut faire revenir une réponse **obsolète** après une plus récente et corrompre l'accumulation "sans doublon ni trou". Les tests ne l'attrapaient pas parce que `pumpAndSettle` **linéarise** les futures — la concurrence réelle était masquée. »

Charlie (Senior Dev) : « Corrigé avec un compteur monotone `_generation` : on capture `gen` au lancement de la requête et on **rejette tout commit/emit si `gen != _generation`** (en plus du `_disposed`). Dix lignes, mais c'est l'invariant central de la story. »

Alice (Product Owner) : « Le gain produit le plus visible, c'est **e4-4** : le bug de **sélection multiple** que les trois apps (DODLP, IFFD, DLCFTI) traînaient depuis toujours. La cause était structurelle — la sélection était keyée sur les **instances** `DataGridRow`, recréées au rebuild. »

Amelia (Developer) : « On l'a résolu par conception : l'état de sélection est keyé par **`id`** et vit **hors** du renderer ; la grille est **stateful** avec `source`/`controller` d'identité stable (`didUpdateWidget → _source.update()`, jamais recréée par `build`) ; `_syncControllerFromInteraction` reconstruit `selectedRows` **à partir des id**, donc les instances fraîches sont re-mappées. Plus de perte de sélection au rebuild/scroll/loadMore/tap. »

Charlie (Senior Dev) : « Ce qui a introduit **MEDIUM-1** e4-4 : dès qu'il y a des actions, la source Syncfusion était `update()`-ée à **chaque** rebuild → la mémoïsation était partiellement défaite (perf). Corrigé par mémoïsation ciblée. Aucun AC testé invalidé, mais une régression de perf réelle qu'on ne voulait pas laisser filer. »

Dana (QA Engineer) : « Et un enseignement d'infra : sur e4-4, l'agrégat `melos run verify` **ne renvoyait pas RC=0** parce que le sous-gate `verify:serialization` échouait sur `zcrud_riverpod` (`No tests match tag selectors: serialization-compat`) — **pré-existant, hors diff E4-4**. Ce faux ERROR avait failli induire un reviewer en erreur. Tranché en **LOW-4** : le gate SKIP au lieu d'ERROR quand aucun test ne matche, pour ne plus mentir sur l'état. »

Alice (Product Owner) : « e4-5 a bien clôturé : `ZSubListScreen` et `ZTabbedList` sont des **assembleurs minces** qui réutilisent E4-1..E4-4 sans réinventer de machinerie. La garantie critique — **la relation parent ne peut jamais fuiter** — est un socle immuable ANDé sur tous les chemins (backend + in-memory + loadMore), avec `baseFilters` persistant. Et la distinction est nette : `ZSubListScreen` = **liste** reliée (E4-5) vs champ **inline** `subList` = **édition** (E3-3b-2), documentée dans la docstring, prouvée par `git status` (familles édition non touchées). »

{user_name} (Project Lead) : [participation — voir décisions et inflexions §4]

---

## 4. Ce qui a bien marché / ce qui a coincé / leçons

### 4.1 Bien marché

- **Isolation d'une dépendance lourde par port** : `ZListRenderer` dans le cœur, `ZSfDataGridRenderer` seule arête Syncfusion. Un consommateur sans `zcrud_list` ne tire pas Syncfusion — vérifié par graphe résolu, pas par convention.
- **Dérivation schéma-unique** : colonnes issues du `ZFieldSpec[]` (`deriveColumns` qui **ne lève jamais**), `ZListLayout` (liste/DataGrid/custom), **4 états UI accessibles et distincts** (`loading`, `empty`, `no-results-après-filtre`, `error`) — `empty ≠ noResults` (clés + textes distincts).
- **Bug historique 3 apps enfin corrigé par conception** (sélection keyée `id` hors renderer + grille stateful) — pas un rustine, une frontière.
- **`DynamicList` rendu générique `<T>`** au fil de l'epic **sans casser** l'égalité de valeur d'E4-1/E4-2.
- **0 HIGH / 0 MAJEUR** sur les 5 stories : la conception amont (ports, value objects, socle immuable de relation) a payé.

### 4.2 Coincé

- **Preuve d'isolation sur-vendue** (e4-1 M1) : le premier jet affirmait une fermeture transitive complète qu'il ne réalisait pas pour l'externe. Symptôme classique de « garde de test qui rassure plus qu'elle ne prouve ».
- **Concurrence async masquée par les tests** (e4-3 M-1) : `pumpAndSettle` linéarise les futures ⇒ la vraie course search-as-you-type restait non exercée. Verdict PLAUSIBLE, non couvert avant correctif.
- **Régression de perf introduite par le correctif fonctionnel** (e4-4 MEDIUM-1) : la stabilité de sélection a d'abord été payée par un `update()` à chaque rebuild.
- **Gate agrégat trompeur** (e4-4 LOW-4) : un ERROR pré-existant hors périmètre a rendu l'assertion « `verify` RC=0 » des Dev Notes non reproductible et a failli induire un reviewer en erreur.

### 4.3 Leçons (transposables)

1. **Valeur du durcissement de preuve.** Pour un invariant architectural (isolation d'une dep lourde), une preuve doit se fonder sur la **résolution réelle du graphe** (`dart pub deps --json`), jamais sur une heuristique de fermeture maison qui traite l'externe comme une feuille. Une preuve « verte mais sur-vendue » est un risque, pas une garantie — le commentaire doit dire **exactement** ce que le test démontre.
2. **La concurrence async doit être testée avec de la vraie concurrence.** `pumpAndSettle` masque les courses ; un compteur `_generation` (garde anti-stale) est le pattern canonique pour rejeter les réponses obsolètes. À généraliser à tout chemin async à saisie rapprochée.
3. **Isoler une dépendance lourde = discipline de value object.** Les callbacks non comparables (`ZListInteraction`) doivent vivre **hors** du value object partagé ; la statefulness du backend reste cantonnée à son package. C'est ce qui permet à la fois l'égalité de valeur du cœur ET la richesse d'interaction du renderer.
4. **Un correctif fonctionnel peut introduire une régression non-fonctionnelle.** Corriger la sélection sans surveiller la mémoïsation a coûté un MEDIUM perf — le code-review doit couvrir l'axe perf, pas seulement l'AC.
5. **Un gate qui ment est pire qu'un gate absent.** SKIP explicite > ERROR trompeur quand aucun test ne matche ; sinon il pollue tous les runs et érode la confiance dans le "vert".

---

## 5. Reports & findings différés (rattachement)

| Origine | Finding | Décision | Rattaché à |
|---|---|---|---|
| e4-3 | LOW-2 (normalisation NFD des diacritiques) | Différé | **E5** |
| e4-3 | LOW-3 (tie-break stable par `id`) | Différé | **E5** |
| e4-4 | LOW-3 (élagage de la sélection sur lignes réellement visibles, edge filtre/refresh) | **Tranché** | **E4-5** (`didUpdateWidget` + `clearSelection` sur changement de relation) |
| e4-2 | LOW-2 (en-têtes de colonnes résolus dans l'espace de noms générique `label()`) | Différé (seam l10n systémique) | Seam l10n (hors E4) |
| e4-4 | LOW-4 (`verify:serialization` ERROR pré-existant) | **Corrigé** (SKIP au lieu d'ERROR) | Infra CI / traité |
| — | Distinction `ZSubListScreen` (liste, E4-5) vs champ inline `subList` (édition, E3-3b-2) | **Documentée & prouvée** | E4-5 / E3-3b-2 |

---

## 6. Préparation de la suite (E7 — intégration DODLP)

E4 **débloque E7** (chemin critique MVP : E1 → E2 → (E3 ∥ **E4** ∥ E5 ∥ E6 ∥ E11a) → **E7** → E8). E7 dépend de E3, E4, E5, E6 **et E11a**.

- **Prérequis pour E7 encore ouverts** : E5 (firestore/offline), E6 (markdown), **E11a** (lot parité DODLP) doivent être `done` avant E7. E4 est prêt côté liste.
- **Décision de séquencement** : E7/E8 sont **différés** (migration d'app réelle, session dédiée) — cohérent avec le sprint-status et le CLAUDE.md. Aucune découverte E4 n'invalide le plan E7 : la surface `DynamicList<T>` + `ZListRenderer` + `ZAcl` + corbeille est stable et testée.
- **Vigilance héritée** : sur DODLP (GetX/reflectable/Firebase), vérifier que le débounce de saisie (recherche) est bien assuré par le binding — e4-3 a explicitement laissé la déduplication/débounce **au binding/app** au-delà de la garde `_generation` interne.
- **App exemple `EX-1`** (story EX, hors E4, `in-progress` en parallèle) : sert de harnais de validation SM-1/SM-5 et de parité bindings ; y brancher la démo `DynamicList` complète.

---

## 7. Action items (avec rattachement)

| ID | Action | Owner | Statut | Rattachement |
|---|---|---|---|---|
| **AI-E4-1** | Appliquer LOW-2/LOW-3 e4-3 (normalisation NFD + tie-break `id`) lors de la couche recherche/tri persistée | Équipe dev | open | **E5** |
| **AI-E4-2** | Résoudre le seam l10n systémique des en-têtes de colonnes (LOW-2 e4-2) hors namespace générique `label()` | Équipe dev | open | Seam l10n global |
| **AI-E4-3** | Vérifier, à l'intégration E7 (DODLP/GetX), que le débounce de saisie recherche est fourni par le binding (au-delà de la garde `_generation`) | Zakarius / dev | open | **E7** |
| **AI-E4-4** | Brancher la démo `DynamicList` complète (états, filtres, sélection, corbeille, sous-listes/onglets) dans l'app exemple EX-1 | Équipe dev | open | **EX / EX-1** |
| **AI-E4-5** | Généraliser le pattern « garde `_generation` anti-réponse-obsolète » à tout futur chemin async search-as-you-type | Équipe dev | open | Standard transverse |
| **AI-E4-6** | Débloquer E1-5 groupe B (révocation clé Google Maps) — item ouvert global | **Zakarius (Owner)** | open | **E1-5 / global** |
| **AI-E4-7** | Publication pub.dev (REL) : différée après packages MVP (E4/E5/E6/E11a complets) — action Owner | **Zakarius (Owner)** | open | **REL (différé)** |

---

## 8. Readiness — Epic E4

| Axe | État |
|---|---|
| Stories | ✅ 5/5 `done` |
| Qualité / tests | ✅ analyze RC=0 · `flutter test` zcrud_list 20 · gates verts |
| Isolation SM-5 / AD-8 | ✅ prouvée (résolution réelle) et durcie ; `ZSfDataGridRenderer` seule arête Syncfusion |
| Findings bloquants | ✅ 0 HIGH / 0 MAJEUR ; 3 MEDIUM tous corrigés |
| Dette / LOW | 🟡 consignés et rattachés (§5, §7) — aucun bloquant |
| Débloque | E7 (conditionné à E5/E6/E11a `done`) |
| Découverte significative imposant une révision de plan | ❌ Aucune — plan E7 intact |

**Verdict rétro** : Epic E4 **complet et solide**. Prêt à contribuer au chemin critique MVP. Clôture recommandée : `epic-4-retrospective: optional → done` (transition **appliquée par l'orchestrateur**, pas par cette rétro).

---

## 9. Note de conformité

- ⚠️ **`sprint-status.yaml` NON modifié par cette rétro** (contrainte de mission respectée). La transition `epic-4-retrospective → done` et le maintien de `epic-4` restent à la charge de l'orchestrateur (édition ciblée sérialisée).
- Aucun code modifié, aucun commit effectué par cette étape.
- Les gates et compteurs de tests cités sont **repris des code-reviews qui les ont rejoués sur disque**, non recalculés par cette rétro.
