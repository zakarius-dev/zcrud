# Code Review — E2-9 : Bindings multi-gestionnaire (`zcrud_get` / `zcrud_riverpod` / `zcrud_provider`) + gate de parité AD-15

- **Skill** : `bmad-code-review` (chemin pris : tool `Skill` → `bmad-code-review`, workflow step-file `.claude/skills/bmad-code-review/steps/step-01-gather-context.md`).
- **Story** : `_bmad-output/implementation-artifacts/stories/e2-9-bindings-multi-gestionnaire.md` (statut `review`, 11 ACs).
- **Baseline** : `8f28755` (HEAD). Tout le code produit (`packages/**`, `tool/**`) est **non suivi** (E2 pas encore committée) → l'AC1 « `git diff zcrud_core/lib` vide » n'est **pas vérifiable par diff git** (pas de baseline committée) ; vérifié **autrement** (mtime + grep de pureté, voir ci-dessous).
- **Date** : 2026-07-09.
- **Reviewer** : agent adversarial (Opus 4.8).

## Verdict : **CHANGES REQUESTED**

Le cœur de la story (AD-15 : cœur inchangé, 3 bindings fonctionnels, gate de parité vert ×4, graphe acyclique CORE OUT=0, `melos list`=14) est **réellement atteint et rejoué vert sur disque**. Deux findings **MEDIUM** subsistent, tous deux corrigeables dans le périmètre sans régression (politique projet : MEDIUM corrigés par défaut avant `done`). Aucun HIGH/critique. Aucun binding ne reconstruit globalement par frappe (SM-1 prouvé sous chaque manager).

---

## Résultats RÉELS rejoués sur disque

| Vérification | Commande | Résultat |
|---|---|---|
| Pureté cœur (AC1/AC8) | `grep -rE 'WidgetRef\|Get.find\|Get.put\|Provider.of\|package:get\|package:get_it\|package:provider\|flutter_riverpod' packages/zcrud_core/lib` | **0 match** ✅ |
| Cœur inchangé (AC1) | mtime `zcrud_core/lib/**` = **14:14** (E2-7) vs bindings **15:08–15:10** ; 0 fichier cœur touché par E2-9 | ✅ (diff git impossible — cœur non committé) |
| Graphe (AC2) | `python3 scripts/dev/graph_proof.py` | **CORE OUT=0 OK**, **ACYCLIQUE OK**, 17 arêtes, 14 nœuds ; nouvelles arêtes = `zcrud_{get,riverpod,provider} → zcrud_core` seulement ✅ |
| Gate melos M-1 (AC9) | `dart run scripts/ci/gate_melos_divergence.dart` | **OK** — 13 scripts, blocs identiques ✅ |
| `melos list` (AC10) | `dart run melos list` | **14** (binding_conformance exclu via `melos.ignore` dans les 2 blocs) ✅ |
| Lockfiles parasites (AC9) | `find packages tool -name pubspec.lock` | **aucun** (lockfile racine unique) ✅ |
| Analyze (AC11) | `dart run melos run analyze` | **SUCCESS**, 0 warning ✅ |
| Tests (AC11) | `dart run melos run test` | **SUCCESS** (zcrud_core +96 ; get +9 ; riverpod +7 ; provider +7) ✅ |
| **Gate parité ×4** (AC6) | `flutter test` par binding | **All tests passed** sous `bare ZcrudScope`, `ZcrudGetScope`, `ZcrudRiverpodScope`, `ZcrudProviderScope` — compteurs figés par l'oracle : `buildsA = 1+25`, `buildsB = 1`, `buildsGlobal = 1`, focus/curseur préservés ✅ |
| Verify (AC11) | `dart run melos run verify` | **RC=0** (graph, melos, reflectable, secrets, codegen, compat OK ; `verify:serialization` no-op documenté) ✅ |
| prove_gates | `dart run scripts/ci/prove_gates.dart` | **22 OK, 0 FAIL** ✅ |
| `.g.dart` (AC10) | gate:codegen | 0 modèle annoté, 0 `.g.dart` manquant ✅ |
| Gardes d'idiome (AC8) | tests `purity/idiom_isolation_test.dart` ×3 | verts ; forbidden lists correctes et croisées (get⊥riverpod/provider ; riverpod⊥get/provider ; provider⊥get/riverpod), bornes de mots (pas de faux positif `ProviderScope`⊂`ZcrudProviderScope`) ✅ |

---

## Findings

### MEDIUM-1 — `ZProviderResolver` recréé à CHAQUE build → identité instable → sur-rebuild des consommateurs de `ZcrudScope` (asymétrie inter-binding, AD-2/AD-15)
**Fichier** : `packages/zcrud_provider/lib/src/presentation/zcrud_provider_scope.dart:63`.
`ZcrudProviderScope` est un `StatelessWidget` dont `build()` construit `ZProviderResolver(inner)` **neuf à chaque reconstruction**. Or `ZcrudScope.updateShouldNotify` (`zcrud_core`) compare le resolver par `identical(...)` : à chaque rebuild du scope provider, `updateShouldNotify` renvoie **`true`** et **rebuild TOUS les widgets ayant fait `ZcrudScope.of(context)`** (seams l10n/thème/resolver — consommés dès E2-8+), même sans changement réel.
Les **deux autres bindings** mettent le resolver en cache dans `initState` (`_resolver`), identité **stable** → `updateShouldNotify` `false` → aucun rebuild superflu. Le binding provider **n'est donc PAS à parité** avec get/riverpod sur l'axe « rebuild des consommateurs de seams » — ce qui contredit l'esprit d'AD-15 (« un même controller/scope fonctionne à l'identique sous les quatre »).
**Pourquoi le gate ne l'attrape pas (trou de couverture)** : dans `runZFormGranularRebuildParitySuite`, l'arbre testé (`ZFieldListenableBuilder` + `ListenableBuilder`) n'appelle **jamais** `ZcrudScope.of(context)` ; et le scope ne se reconstruit pas pendant `setValue`×N. Le gate prouve donc la granularité du `ZFormController` (qui vit dans le cœur → identique **par construction**), mais **pas** la stabilité du resolver du scope. Un binding sur-rebuildant les consommateurs de seams passe quand même le gate.
**Scénario d'échec** : app où `ZcrudProviderScope` se reconstruit (parent qui rebuild, changement de config, `MediaQuery`…) → tous les champs/labels résolvant un seam via `ZcrudScope.of` se reconstruisent inutilement sous provider, alors qu'ils restent stables sous get/riverpod.
**Correctif suggéré** : convertir `ZcrudProviderScope` en `StatefulWidget` et mémoïser le `ZProviderResolver` (le `BuildContext` du `Builder` interne est stable), à l'image de `ZcrudGetScope`/`ZcrudRiverpodScope`. **Bonus recommandé** : durcir le gate en ajoutant au harnais un compteur de rebuild d'un widget-consommateur de `ZcrudScope.of(context)` (fermerait définitivement le trou de couverture pour les 4 configs).

### MEDIUM-2 — `ZcrudGetScope` + locator applicatif partagé : le `dispose` peut désenregistrer le `ZFormController` d'autrui (lifecycle, AC3)
**Fichier** : `packages/zcrud_get/lib/src/presentation/zcrud_get_scope.dart:81-99`.
À l'`initState`, si `registerController` est vrai **et** que le locator fourni par l'app contient **déjà** un `ZFormController`, la garde `!_locator.isRegistered<ZFormController>()` empêche d'enregistrer le `_controller` neuf — mais celui-ci est quand même créé et possédé. Au `dispose`, la condition `registerController && isRegistered` déclenche `unregister<ZFormController>()`, qui **désenregistre le controller d'autrui** (jamais celui créé par ce scope). Symétriquement, **deux `ZcrudGetScope` partageant le locator applicatif** (2 formulaires simultanés) se marchent dessus : le second ne (ré)enregistre pas, et le démontage de l'un désenregistre l'enregistrement de l'autre — le controller resté vivant devient irrésoluble via le locator.
**Réalisme** : le défaut `GetIt.asNewInstance()` (isolé) évite le problème, **mais E7-1 (DODLP, consommateur prioritaire) passera précisément son locator applicatif partagé** (`getIt<...>()`) → scénario réaliste dès E7. Aucun test n'exerce le cas locator partagé / double-scope.
**Correctif suggéré** : n'unregister/dispose que si CE scope est bien le propriétaire de l'enregistrement (registrer par instance et vérifier l'identité avant `unregister`), ou scoper l'enregistrement `get_it` (`pushNewScope`/`popScope`) ; à défaut, documenter explicitement l'exigence « un locator par scope de formulaire » et ajouter un test du cas partagé.

### LOW-1 — Bridge `registerInGetX` adossé au singleton **global** `Get`
`zcrud_get_scope.dart:85-101` : même motif de collision que MEDIUM-2 mais sur le singleton **global** GetX (deux scopes ⇒ le second ne réenregistre pas ; un `Get.delete` peut supprimer l'instance de l'autre). Défaut `false` (désactivé), donc hors chemin par défaut. À documenter comme « GetX global = un seul scope actif » ou scoper.

### LOW-2 — `binding_conformance` déclare `flutter_test` en **dependency runtime** (et non dev)
`tool/binding_conformance/pubspec.yaml:39-44` : choix **assumé et documenté** (l'API publique du harnais EST une suite `testWidgets`/`expect`). Acceptable pour un package dev/test-only référencé uniquement en `dev_dependencies` des bindings (non transitif pour les apps hôtes). Consigné pour visibilité, pas d'action requise.

---

## Points adversariaux vérifiés — CONFORMES

- **Parité réellement partagée** : oracle **unique** (`runZFormGranularRebuildParitySuite`, `tool/binding_conformance`) ; corps de test FIGÉ, seul `wrap` varie → aucun binding ne peut « tricher » sur le corps. Les 4 `wrap` montent le **même** arbre (`ZFormController` 2 champs + `ZFieldListenableBuilder` ×2 + `ListenableBuilder` global). Compteurs identiques ×4 (`buildsB==1`, `buildsGlobal==1`) → aucun binding ne notifie globalement par frappe. ✅ (limite : ne couvre pas le rebuild des consommateurs de seams — cf. MEDIUM-1.)
- **Confinement manager** : `zcrud_core/lib` = 0 token manager (grep) ; cœur non modifié (mtime) ; gardes d'idiome croisées vertes par binding. ✅
- **Réutilisation, pas réimplémentation** : les 3 scopes enveloppent `ZcrudScope(resolver: ...)` et réutilisent `ZFormController`/`ZFieldListenableBuilder` tels quels ; aucun `ValueNotifier`/mécanique de tranche recréée. ✅
- **Lifecycle** : get (unregister+dispose au démontage, testé) ; riverpod (`Provider.autoDispose` + `ref.onDispose`, `_container.dispose()` au démontage, testé) ; provider (`ChangeNotifierProvider` `lazy:false`, dispose par `provider`, testé). ✅ (réserve : cas locator partagé get non testé — MEDIUM-2.)
- **Resolvers** : get (`get_it` par `type:`, escape-hatch borne `T` non bornée) ; riverpod (registre `Type→provider` + `container.read`) ; provider (`Provider.of(listen:false)`, `ProviderNotFoundException → ZScopeError`). Chacun lève `ZScopeError` sur seam absent — testé. ✅
- **Isolation harnais dev-only** : hors `packages/**`, membre du `workspace:` pour résolution partagée, nom sans préfixe `zcrud_` (invisible pour `graph_proof.py`), `melos.ignore` dans **les deux** blocs → `melos list`=14, M-1 intact (gate:melos OK). ✅
- **Graphe** : bindings → `zcrud_core` uniquement ; 0 arête `core→binding` ; 0 arête `binding→binding` ; SDK manager non comptés. ✅
- **Hygiène git** : `.gitignore` couvre `build/`, `**/build/`, `*.iml`, `.dart_tool/` → les artefacts `packages/*/build/` et `melos_*.iml` présents sur disque **ne seront pas committés**. `git ls-files '*.g.dart'`=0. ✅

## Trous de couverture détectés

1. **Gate de parité aveugle aux consommateurs de `ZcrudScope`** (cause de la non-détection de MEDIUM-1) : le harnais ne mesure que des widgets écoutant le `ZFormController` du cœur (granularité identique par construction) ; aucun compteur sur un widget qui résout un seam via `ZcrudScope.of(context)`. Recommandation : ajouter ce compteur au harnais pour certifier la stabilité du resolver sous les 4 configs.
2. **`ZcrudGetScope` avec locator partagé / double-scope** : non testé (MEDIUM-2). E7-1 l'exercera en conditions réelles.
3. **Bridge `registerInGetX` en contexte multi-scope global** : non testé (LOW-1).

## Décompte findings

| Sévérité | Nombre |
|---|---|
| HIGH / MAJEUR | 0 |
| MEDIUM | 2 (MEDIUM-1 resolver provider ; MEDIUM-2 lifecycle get locator partagé) |
| LOW | 2 |

**Recommandation** : corriger **MEDIUM-1** (correctif petit et propre, referme l'asymétrie AD-15 + le trou de couverture n°1) et **MEDIUM-2** (réaliste dès E7) avant `done` ; sinon justifier par écrit leur report. LOW documentés.
