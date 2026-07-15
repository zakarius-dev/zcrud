# Rétrospective — Epic ES-5 : Layout « study tools », apparence IFFD

- **Skill** : `bmad-retrospective` (effort medium, fallback disque `.claude/skills/bmad-retrospective/SKILL.md`).
- **Date** : 2026-07-15.
- **Package cible** : `zcrud_study` (présentation, NEUF — créé en ES-5.1).
- **Stories** : ES-5.1, ES-5.2, ES-5.3, ES-5.4 — **toutes `done`**.
- **Contexte process** : Epic exécuté en **workstream B**, PARALLÈLE au workstream A (ES-4 / `zcrud_session` / `scripts/ci` / `zcrud_flashcard`). Packages disjoints, seul point de contact possible = `zcrud_core` (jamais écrit par ES-5). Rétro READ-ONLY (n'écrit QUE ce fichier).

---

## 1. Résultats livrés (vérifiés sur les story-files + code-reviews)

| Story | Livrable | Preuve verte (dernier état des CR) |
|---|---|---|
| **ES-5.1** | Package NEUF `zcrud_study` ; `ZStudyToolsSectionSpec` (`id`/`title`/`itemCount`/`itemBuilder`/`emptyState`/`addAction?`) + `ZSectionedStudyLayout` (frontière keyée `ValueKey('section:$id')`, `ListView.builder`, ordre d'entrée préservé) ; **golden discriminant** (byte-diff m1/m2/m3 + comptage structurel N→N-1). Décomposabilité IFFD (Deferred AD-25) **CONFIRMÉE par écrit** (mapping 4 sections IFFD→4 specs + fichier:ligne). | `flutter test` 6/6 RC=0 ; `dart analyze` RC=0 ; `graph_proof` ACYCLIQUE + CORE OUT=0 ; `melos list` 18→19. APPROUVÉ (1 MEDIUM + 3 LOW → **DW-ES51-1**, reportés/justifiés). |
| **ES-5.2** | `ZStudyToolsPage` (composition de `ZSectionedStudyLayout`, `ZFormController` STABLE, `_ZStudyFormScope`) ; **SM-1 (objectif produit n°1) PROUVÉ** : 100 frappes ⇒ `buildsA=101`, `buildsB=1`, `buildsPage=1`, focus jamais perdu, `selection.baseOffset==100` ; slots injectables `addActionIcon`/`addActionSemanticLabel`/`axis` ; **DW-ES51-1 SOLDÉE**. | `flutter test` 19/19 RC=0 ; `dart analyze` RC=0 ; graphe inchangé. APPROVED (0 MEDIUM+, 3 LOW justifiés). |
| **ES-5.3** | Sections réordonnables (`ReorderableListView.builder` **SDK Flutter**, aucun `reorderable_grid_view`), hub d'ajout (`ZContentHubSheet`), menu d'actions (`ZItemActionsMenu`) ; réutilise `ZFolderContentsOrder` (lecture + `copyWith`) ; helper pur `zReorderIds`. SM-1 non régressé. | `flutter test` 37→**38** RC=0 après remédiation ; `graph_proof` inchangé ; `melos list` 20. **MEDIUM-1 (trou de couverture ordre optimiste local) REMÉDIÉ + verrouillé** (test `rebuildOnReorder:false`). |
| **ES-5.4** | `ZFeatureAvailability` (`abstract interface class`, `featureKey` String OPAQUE), `ZFeatureAvailabilityScope` (`InheritedWidget` pur), défaut **fail-open** `ZAllFeaturesAvailable` + opt-in fail-safe `ZMapFeatureAvailability` ; compose les slots ES-5.3 (`gate ⇒ onTap/addAction/onSelected null`). Golden INCHANGÉ. | `flutter test` **51** RC=0 ; `dart analyze` RC=0 ; graphe inchangé, CORE OUT=0, `melos list` 20. APPROVED (0 MEDIUM+, 2 LOW justifiés). |

**Trajectoire de la suite de tests** : 6 (ES-5.1) → 19 (ES-5.2) → 38 (ES-5.3) → 51 (ES-5.4), tous verts, non-régression cumulée à chaque story.

---

## 2. Ce qui a marché

- **Composition AD-4 systématique sur `zcrud_study`.** Tout l'epic bâtit par COMPOSITION, jamais par héritage de vues — contraste direct avec l'anti-pattern IFFD `SubjectStudyToolsPage extends FolderStudyToolsPage`. `ZStudyToolsPage` COMPOSE `ZSectionedStudyLayout` (`find.byType == 1`, jamais réimplémenté inline) ; ES-5.4 gate les slots existants d'ES-5.3 SANS nouveau chemin de rendu (golden inchangé). La décomposition d'un monolithe de 1753 lignes en specs paramétriques est la démonstration vivante que « le modèle/le contrat = source unique, l'apparence = injectée ».

- **Golden DISCRIMINANT comme patron anti-golden-powerless.** ES-5.1 a établi un patron réutilisé tout l'epic : `matchesGoldenFile` SEUL est insuffisant (un layout monolithique produisant les mêmes pixels passerait). Le harnais combine (a) **byte-diff** `RepaintBoundary→toImage→bytes` sur 3 mutations (fusion/permutation/altération d'état vide), chacune `isNot(equals(canonique))`, et (b) **comptage structurel** par `Key('section:*')` (N→N-1). Les injections I1–I4 (dont le guard powerless « surface 1×1 ») prouvent que le harnais RÉGRESSE réellement. Ce patron a résisté à la régénération du golden (ES-5.2 : badge `radiusM` + rail horizontal) sans perdre son pouvoir.

- **SM-1 (objectif produit n°1) PROUVÉ load-bearing, puis non régressé.** ES-5.2 a démontré le rebuild granulaire par champ (100 frappes ⇒ seul le champ courant se reconstruit, zéro perte de focus, curseur préservé) en réutilisant le pattern éprouvé `sm1_granular_rebuild_test.dart` de `zcrud_core`. Le pouvoir discriminant est établi par une injection qui MORD réellement (`ListenableBuilder(listenable: fieldListenable('a'))` — variante non-inerte, car `setValue` ne déclenche jamais `notifyListeners` global). ES-5.3 a re-vérifié SM-1 APRÈS ajout du réordonnancement (ordre optimiste sous `ValueNotifier`, pas `setState`).

- **Parallélisation ES-4 ∥ ES-5 sans collision.** Packages strictement disjoints (`zcrud_session` vs `zcrud_study`), aucun contact `zcrud_core`, aucune écriture concurrente du sprint-status (sérialisées par l'orchestrateur). Les vérifs ont été CIBLÉES par package (`dart analyze` + `flutter test` du seul `zcrud_study`, jamais `melos verify/analyze` repo-wide en dev actif), la restauration des injections R3 par ÉDITION CIBLÉE (jamais `git checkout/restore/stash` — working-tree partagé). Isolation tenue de bout en bout.

- **Le spot-check orchestrateur a attrapé ce que le rapport d'agent masquait.** Sur ES-5.3, le code-review a rejoué une **COVERAGE-PROBE** (neutraliser `_ids.value = zReorderIds(...)`, callback INTACT) et constaté que les 37 tests restaient VERTS — trou de couverture confirmé sur le mécanisme d'ordre optimiste LOCAL (la raison d'être même du `_ReorderableItemList`/`ValueNotifier`). Remédié dans le périmètre, verrouillé par un test dédié.

---

## 3. Ce qui est à améliorer / incidents

- **Course bootstrap-vs-flutter-test lors de la création d'un package.** ES-5.1 crée un package NEUF et modifie le `pubspec.yaml` racine (bloc `workspace:`) — opération qui réécrit la résolution du workspace. Pendant ce bootstrap ponctuel, un `flutter test` du workstream parallèle peut voir un workspace transitoirement incohérent. La contrainte a été gérée (sérialisation ponctuelle du dev au niveau workspace), mais elle n'était pas explicitement codifiée en règle. → **R17**.

- **Deux incidents d'agents de code-review (morts silencieux).** Deux sessions `bmad-code-review` sont mortes (« Connection closed » / poll figé). Gérés SANS confiance aveugle : l'orchestrateur a vérifié l'état réel sur disque (working-tree propre, tests rejoués) avant de relancer — jamais enchaîné sur la foi d'un `review`/`done` laissé par un agent mort. Confirme la valeur du health-check et de la vérif disque (CLAUDE.md « Surveillance des sous-agents »).

- **Le motif dominant persiste : « mécanisme central existe, mais aucun test ne prouve son POUVOIR discriminant ».** MEDIUM-1 d'ES-5.3 en est l'incarnation : un mécanisme optimiste LOCAL non testé indépendamment de son callback (le test AC1 utilisait `rebuildOnReorder:true`, masquant le chemin local via le re-render de l'appelant). Le rapport d'agent le déclarait couvert ; seul le spot-check l'a démasqué. → **R18** (généralisation de R12/R13).

- **`IconData` de repli codé en dur (tension FR-26).** `_kAddActionFallbackIcon = Icons.add` reste un `IconData` en dur dans le package (repli CONDITIONNEL, prime perdue dès injection). Lecture stricte de FR-26 = « aucun `IconData` codé en dur ». Sanctionné explicitement par la story (repli documenté, jamais inconditionnel) et le glyphe « + » est universel/neutre — mais la piste « `addActionIcon` requis, ou défaut via `ZcrudTheme` » reste ouverte (LOW, non bloquant).

---

## 4. Nouvelles règles (suite R1..R16)

### R17 — Sérialiser le dev au niveau WORKSPACE quand un workstream crée un package ou bootstrape
Quand une story crée un package NEUF, modifie le `pubspec.yaml`/`melos.yaml` racine (`workspace:`), ou lance un `dart pub get`/`melos bootstrap` qui réécrit la résolution du workspace, l'orchestrateur **sérialise ponctuellement** les workstreams parallèles le temps du bootstrap : aucun `flutter test`/`dart analyze` d'un autre workstream ne tourne pendant la fenêtre où la résolution est transitoirement incohérente. La parallélisation à fichiers disjoints redémarre une fois le bootstrap stabilisé (résolution verte confirmée). Motive : évite la course bootstrap-vs-flutter-test (faux RED d'un workstream innocent).

### R18 — Le spot-check orchestrateur prouve le POUVOIR d'un mécanisme, indépendamment de son callback
Généralise R12/R13. Un rapport d'agent qui déclare un mécanisme « couvert » ne suffit pas : l'orchestrateur rejoue une **COVERAGE-PROBE** ciblée — neutraliser la ligne PORTEUSE du mécanisme (ex. l'écriture d'état optimiste LOCAL) en laissant INTACT tout le reste (callback, re-render de l'appelant) — et vérifie qu'AU MOINS un test ROUGIT. Si la suite reste VERTE, c'est un **trou de couverture** (le mécanisme est prouvé par un chemin tiers qui le masque, pas par lui-même) → finding MEDIUM à remédier avant `done`. Cas typique : un mécanisme optimiste local dont l'effet visuel n'est jamais exercé parce que le test déclenche aussi le re-render de l'appelant (`rebuildOnReorder:true`). Remédiation = un test qui exerce le chemin ISOLÉ (`rebuildOnReorder:false`) et assert l'effet POSITIF.

### R19 — Golden discriminant = byte-diff + comptage structurel, JAMAIS `matchesGoldenFile` seul
Un golden qui repose uniquement sur `matchesGoldenFile` prouve « ça ressemble à la référence », pas la propriété structurelle voulue (décomposition, ordre, frontières de rebuild) — un monolithe produisant les mêmes pixels passerait. Tout golden structurel DOIT être doublé de : (a) un **byte-diff** `RepaintBoundary→toImage→toByteData(png)` comparant les octets du canonique à ≥1 mutation ciblée (`isNot(equals(...))`), et (b) un **comptage structurel** par `Key` stable (ex. N sections → N sous-arbres ; fusion → N-1). Interdits POWERLESS explicitement exclus par construction : surface triviale (1×1), tolérance de diff non nulle, rendu d'un widget constant. Un guard « surface 1×1 » (injection I4) prouve que le harnais N'EST PAS permissif. La capture doit rester déterministe (police Ahem, `physicalSize`/`devicePixelRatio`/`textScaleFactor` figés, animations off, `toImage` sous `tester.runAsync`).

---

## 5. État des dettes après ES-5

| Dette | État | Détail |
|---|---|---|
| **DW-ES51-1** (ES-5.1 : `Icon(Icons.add)` hardcodé + `Semantics(label: spec.title)` ambigu + tokens badge en dur + LOW-3 doc) | ✅ **SOLDÉE en ES-5.2** | Icône/label INJECTÉS (`addActionIcon`/`addActionSemanticLabel`), badge via `theme.radiusM`/`gapS`/`gapM`, Semantics redondants supprimés, commentaire `fusedSections()` corrigé. Atterrit dans le MÊME commit d'epic → aucun code livré ne porte le smell. |
| **MEDIUM-1 ES-5.3** (trou de couverture ordre optimiste local) | ✅ **REMÉDIÉ + verrouillé** | Test `rebuildOnReorder:false` ajouté (38 tests) ; rougit si `_ids.value = zReorderIds(...)` neutralisé. Plus un trou. |
| LOW ES-5.2 (repli `_kAddActionFallbackIcon`, items intra-section eager, durcissement test négatif label) | 🟡 consignés, non bloquants | Justifiés dans le CR. Pistes : `addActionIcon` requis / défaut via `ZcrudTheme` ; `ListView.builder(scrollDirection:)` si gros volumes intra-section. |
| LOW ES-5.3 (`_listEquals` réimplémente `listEquals` SDK ; métadonnée `melos list=19` périmée→20) | 🟡 consignés | Triviaux, cosmétiques. |
| LOW ES-5.4 (branche morte `_flagsEqual` ; `flags` Map mutable dans `@immutable`) | 🟡 consignés | `Map.unmodifiable` casserait la const-compatibilité AC4 → volontairement non fait. |

**Aucune dette bloquante.** Aucun HIGH/MAJEUR sur tout l'epic ; le seul MEDIUM (ES-5.3) est remédié. Les LOW sont justifiés/consignés.

---

## 6. Recommandations de séquencement

- **`zcrud_study` prêt pour l'intégration.** La couche présentation study-tools est complète et prouvée : décomposabilité IFFD confirmée, SM-1 (objectif produit n°1) load-bearing, sections réordonnables + hub + menu d'actions, disponibilité de features injectable. Apparence de référence IFFD reproduite par composition, thématisée/localisée par injection.
- **ES-4 (∥) toujours en cours** — workstream A actif (`zcrud_session`). Maintenir l'isolation (packages disjoints, vérifs ciblées) jusqu'au repos des deux workstreams. **NON-NÉGOCIABLE au gate de commit d'epic** (workstreams au repos) : rejouer `melos run analyze` ET `melos run verify` REPO-WIDE — la vérif ciblée par package ne détecte pas une régression cross-package.
- **E7 (intégration DODLP) reste bloqué par E11a** (graphe de dépendances, pas numérotation). La présentation `zcrud_study` n'est pas sur le chemin critique de DODLP (GetX) mais sert directement IFFD/lex_douane (Riverpod) ; son intégration réelle viendra quand l'app consommatrice câble les `itemBuilder`/données réelles (satellites lourds tirés par l'app, jamais par `zcrud_study`).
- **Ordre suggéré à la reprise** : finaliser ES-4 → gate de commit d'epic ES-4 ∥ ES-5 (analyze + verify repo-wide, working-tree propre, `*.g.dart` régénérés committés, `pubspec.lock` exclus) → poursuivre le séquencement MVP (E11a précède E7).

---

## Transition sprint-status
`epic-es-5-retrospective` → `done` et report des dettes : **ressort de l'orchestrateur** (écriture ciblée et sérialisée). Cette rétro NE touche NI le code NI le `sprint-status.yaml`.
