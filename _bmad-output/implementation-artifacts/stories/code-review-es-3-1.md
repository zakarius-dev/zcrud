# Code-review ES-3.1 — Dépôt d'étude générique (`ZStudyRepository<T>`)

Revue adversariale (effort high) · skill `bmad-code-review` invoqué (workflow step-file). Verdict : **APPROUVÉ SOUS RÉSERVE de M1 (MEDIUM)** — noyau discriminant solide, 1 MEDIUM actionnable qui renforce le cœur de la story, 1 LOW informationnel.

## Périmètre revu
- `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart` (NEW, port Template Method)
- `packages/zcrud_study_kernel/test/z_study_repository_test.dart` (NEW, test discriminant)
- `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (export du port)
- `packages/zcrud_study_kernel/pubspec.yaml` (dép `meta: ^1.15.0`)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (`hide ZStudyRepository` propagé — D7)

## Vérif verte réelle rejouée sur disque
| Vérif | Résultat |
|---|---|
| `dart analyze` kernel (lib+test) | **No issues found** |
| `dart test` port (VM) | **+10 All tests passed** |
| `dart test -p node` port (JS, AC11) | **+10 All tests passed** |
| `flutter test` surface guard flashcard (AC10, D7) | **+5 All tests passed** |
| `dart test` purity kernel (AC7) | **+7 All tests passed** |
| `dart test` resolution kernel (AC8) | **+4 All tests passed** — fermeture ⊆ {zcrud_core, zcrud_annotations} |
| `gate_reserved_keys.dart` (AC9) | **OK** — gate INCHANGÉ |
| `gate_web_determinism.dart` (AC11) | **OK** — +269 (inclut le port) |
| `graph_proof.py` (AC8) | **ACYCLIQUE OK · CORE OUT=0 OK** |
| `gate_secret_scan.dart` | **OK** |
| `flutter analyze` barrel flashcard (cross-package D7) | **No issues found** |
| `git status` | aucun `.g.dart` kernel, `tool/reserved_keys_gate/**` INTOUCHÉ (D6/AC9) |

> Note d'exécution : le guard de surface (`z_kernel_surface_guard_test.dart`) importe `flutter_test` → il DOIT tourner sous `flutter test` (un `dart test` crashe le compilateur FFI — non lié à ES-3.1). Vert sous `flutter test`.

## Pouvoir discriminant PROUVÉ (injections R3 + restauration R13)
1. **AC2 — Template Method (cœur).** Neutralisation de `validate(item)` dans `save` (→ `persist` inconditionnel) : **ROUGIT** AC2 + AC4-violant + AC5-cible-manquante (`persistCount` 0→1, `Right` au lieu de `Left`). Le test passe bien PAR `save` en observant l'espion `persistCount` — **pas** un chemin powerless (il n'appelle pas `validate` hors de `save`). Restauré par édition ciblée, byte-identique (`diff` == 0), re-vert +10.
2. **AC7 — pureté backend.** Injection `Color(0xFF000000)` dans le port : `z_kernel_purity_test.dart` **ROUGIT** en nommant le fichier exact. Restauré byte-identique, purity re-vert +7, analyze clean.

## Axes adversariaux — constats
- **Template Method contraignant (axe 1) :** ✅ `save` concret appelle `validate` PUIS `persist` seulement sur `Right` ; `validate→Left` bloque mécaniquement `persist`. Signature `save(T,{String? collectionId})` matche exactement `ZRepository.save` (override légal, confirmé par analyze). **Réserve → M1.**
- **AD-1/AD-17 CORE OUT=0 (axe 2) :** ✅ le kernel ne gagne AUCUNE arête sortante (`graph_proof` : `zcrud_study_kernel -> {zcrud_annotations, zcrud_core, zcrud_generator(dev)}` inchangé). `meta` est pur-Dart, non-`zcrud_*` → invisible au gate résolution ; fermeture transitive `zcrud_*` reste `{zcrud_core, zcrud_annotations}`.
- **AD-5/AD-11 backend-agnostique (axe 3) :** ✅ import unique `package:zcrud_core/domain.dart` + `package:meta`. Aucun `Timestamp/Filter/Box/WriteBatch/Color`. `Either<ZFailure,·>` partout, `ZResult<Unit>` pour `validate`, flux `Stream<List<T>>` NUS hérités (jamais `Stream<Either>`).
- **AD-4 composer-pas-dupliquer (axe 4) :** ✅ le port n'ajoute QUE `validate` + `persist` + l'override `save` ; **aucun** getter `dataChanges`/`foldersStream` redéclaré (D4 respecté) ; `abstract class` (jamais `sealed`) ; generics licites (PORT, pas sérialisation).
- **AD-10 défensif (axe 5) :** ✅ `validate` défaut = `const Right<ZFailure,Unit>(unit)` — PUR/TOTAL/déterministe, aucune I/O, aucune exception. **Voir L1** sur la propagation d'une exception d'un override fautif.
- **D6 anti-inertie (axe 6) :** ✅ aucun `@ZcrudModel`, aucun `.g.dart` neuf, `registrars.dart`/`tool/reserved_keys_gate/**` intouchés.
- **D7 surface (axe 7) :** ✅ `ZStudyRepository` ajouté au `hide` de `zcrud_flashcard` (précédent `ZFolderContentsOrder`/ES-2.7/ES-2.8) ; guard vert ; barrel flashcard analyze clean.
- **Web-safe (axe 8) :** ✅ test port pur Dart, pas de `dart:io`, pas de `@TestOn('vm')` ; node vert.
- **Couverture 12 ACs (axe 9) :** chaque AC a un test à pouvoir discriminant réel ; AC2/AC4/AC5(rejet)/AC7 prouvés ROUGES par retrait de leur garde. AC3-déterminisme et AC5-matérialisation testent des propriétés (pureté / admission) légitimement, pas des gardes → non powerless.

---

## Findings

### 🟠 M1 (MEDIUM) — `save` n'est pas `@nonVirtual` : le Template Method reste ré-overridable en silence
**Fichier :** `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart:109-114`
**Constat :** D2 énonce que `save` est « non overridable par contrat », mais cette garantie ne vit QUE dans la dartdoc. Rien au niveau langage/analyzer n'empêche l'adapter ES-3.2 (ou toute sous-classe) de **ré-override `save`** et de **bypasser `validate`** — réintroduisant exactement le « hook décoratif ignorable » que la story (R12/DW-ES25-1) veut éradiquer, sans qu'aucun gate ne l'attrape.
**Scénario d'échec concret (prouvé) :** j'ai écrit un `_Bypass extends ZStudyRepository` dont `save` = `persist(...)` sans appeler `validate`. `dart analyze` = **AUCUN warning** (le bypass passe). Après ajout de `@nonVirtual` sur `save`, `dart analyze` **flague** : `invalid_override_of_non_virtual_member — The member 'save' is declared non-virtual in 'ZStudyRepository' and can't be overridden in subclasses`.
**Correction proposée (zéro coût, `meta` déjà dép directe) :** annoter `save` avec `@nonVirtual` (au-dessus de `@override`). Cela transforme la convention dartdoc « non overridable par contrat » en **garantie vérifiée par l'analyzer** — c'est précisément le durcissement machine que le cœur discriminant de la story appelle. Portée strictement dans le fichier port ; aucune régression (le `_SpyRepo` de test n'override PAS `save`, seulement `persist`/`validate`).
**Justification classement MEDIUM :** dans le périmètre, trivial, sans régression, et renforce l'invariant central (D1/D2) — corrigeable par défaut selon la politique MEDIUM. Non-HIGH car le chemin par défaut EST correct et testé, et ES-3.2 est censé implémenter `persist` (pas re-override `save`).

### 🟡 L1 (LOW, informationnel) — propagation synchrone d'une exception d'un override `validate` fautif
**Fichier :** `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart:110-114`
**Constat :** `save` n'est pas `async` ; `validate(item).fold(...)` s'exécute de façon synchrone. Si une sous-classe **viole** le contrat AD-10 (« `validate` ne throw jamais ») en lançant une exception, `save` propage cette exception **synchronement** au lieu de retourner un `Left`/`Future` échoué.
**Pourquoi LOW :** le `validate` par défaut du port respecte le contrat (`const Right`, jamais d'exception) — AD-10 est satisfait POUR le port. Défendre le port contre un override contractuellement fautif (envelopper `validate` dans un `try-catch`) masquerait des bugs et n'est pas attendu d'un port. **Consigné, non bloquant, aucune action requise** ; à garder à l'esprit pour la robustesse de l'adapter ES-3.2 (qui, lui, enveloppe `persist` en `Either`).

---

## Synthèse
- **HIGH/MAJEUR :** 0
- **MEDIUM :** 1 (M1 — `@nonVirtual` sur `save`) → **à corriger par défaut** (trivial, dans le périmètre, renforce le cœur).
- **LOW :** 1 (L1 — informationnel, aucune action).
- **Vérif verte réelle :** analyze RC=0, tests VM+node RC=0, guard/purity/resolution/reserved-keys/web/graph/secrets **tous VERTS**, working-tree propre (aucun résidu d'injection, port restauré byte-identique, aucun `.g.dart`, gate reserved-keys intouché).
- **12/12 ACs** couverts à pouvoir discriminant réel (AC2/AC4/AC5-rejet/AC7 prouvés ROUGES par retrait de garde).

La story est **verte**. Après application de M1 (une ligne `@nonVirtual`) et re-vérif verte, elle est prête pour `done`.
