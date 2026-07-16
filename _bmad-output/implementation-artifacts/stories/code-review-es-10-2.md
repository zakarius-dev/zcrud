# Code Review — Story ES-10.2 (RE-REVUE après révision d'architecture Option B)

- **Skill réel invoqué** : `bmad-code-review` (tool `Skill`) — chargé OK (step-file architecture). Exécution autonome (subagent orchestré) : pas de HALT interactif, périmètre imposé = `packages/zcrud_riverpod/` + `packages/zcrud_firestore/`.
- **Date** : 2026-07-16
- **Baseline** : `3adf49dbec2d04e00d45c871d38544d2696756a3`
- **Statut story revu** : `review` (après RÉVISION ORCHESTRATEUR — binding générique)
- **Verdict** : ✅ **APPROUVÉ pour `done`** — révision VALIDÉE ; 0 HIGH, 0 MAJEUR, 1 MEDIUM (test-gap corrigeable/justifiable), 2 LOW.

---

## 1. Validation de la RÉVISION (axe 1 — mistrust max) — ✅ CONFORME

| Contrôle | Attendu | Mesuré sur disque | Verdict |
|---|---|---|---|
| **(a)** deps `zcrud_*` de `zcrud_riverpod` | `zcrud_core` + `zcrud_study_kernel` UNIQUEMENT | pubspec : `zcrud_core` + `zcrud_study_kernel` ; AUCUN `zcrud_document/_note/_exam/_flashcard/_firestore` en dépendance (les noms d'entités n'apparaissent QUE dans des commentaires explicatifs) | ✅ |
| **(b)** graphe | 45 arêtes, ACYCLIQUE, CORE OUT=0, aucune arête `zcrud_riverpod → {document,note,exam,flashcard,firestore}` | `graph_proof.py` RC=0 : **45 arêtes**, ACYCLIQUE OK, CORE OUT=0 OK, 20 nœuds ; arêtes du binding = `→ zcrud_core`, `→ zcrud_study_kernel` seulement | ✅ |
| **(c)** `melos run verify` REPO-WIDE | VERT (EX-3 respectée, `example` résout) | **RC=0** — reserved-keys / secrets / web / serialization-compat OK sur tous les packages | ✅ |
| Fichier supprimé | `z_study_entity_providers.dart` + son test = absents | Absents (grep + `ls`) | ✅ |
| ES-10.1 intacts | `z_session_config_key.dart` + `z_study_providers.dart` inchangés | Présents, génériques, aucun couplage entité | ✅ |

**Conclusion axe 1** : la révision Option B est réellement appliquée. Le binding est redevenu **thin/générique** (AD-15). Le conflit EX-3 (`zcrud_flashcard` v1.x) est structurellement éliminé (aucune arête binding→entité). **Aucun HIGH.**

---

## 2. Adapter firestore (B) — pouvoir discriminant R12 — ✅ VÉRIFIÉ PAR MUTATION

`buildFolderScopedStudyRepository<T>` (retour `ZStudyRepository<T>` neutre) compose `buildFolderScopedResolver` (`@visibleForTesting`) → `ZFirestorePathRule.nestedUnderParent(collection, parentCollection)` + `ZOfflineFirstBoxRepository<T>(parentId: folderId)`.

Injections R3 rejouées **réellement** (mutation → RED → restauration R13, diffs post-restauration vides) :

| Inj. | Mutation | Résultat | Verdict |
|---|---|---|---|
| **R3-I6** (AC3) | swap `collection`/`parentCollection` dans `buildFolderScopedResolver` | AC3 **RED** : `Actual: users/u1/study_documents/f1/study_folders` ≠ attendu | ✅ discriminant |
| **R3-I4** (AC4) | règle `flatTopLevel` de repli (parentId non exigé) | AC4 **RED** : `folderId=''` → `Expected: true, Actual: <false>` (le `Left` n'est plus produit) ; AC3 RED aussi | ✅ discriminant |
| **Retour neutre** | inspection barrel | `export … show buildFolderScopedStudyRepository` UNIQUEMENT (`buildFolderScopedResolver` NON réexporté) ; signature publique = `ZStudyRepository<T>` ; seul `FirebaseFirestore` en paramètre (couture AD-5 voulue) | ✅ |

`ZFirestorePathResolver.resolveCollection` (relu) : `nestedUnderParent` sans `parentId` → `Left(DomainFailure)` explicite nommant `kind`+`parentId` ; user-scopé sans `userId` → `Left`. Anti-réflexion (aucun `T.toString()`/`runtimeType`). Propagation du `Left` = **l'apport propre** d'ES-10.2, correctement prouvé (R20 déclaré honnêtement dans le test).

---

## 3. Isolation backend (AC2, `zcrud_riverpod`) — ✅ POWERFUL, strippe les commentaires

| Inj. | Mutation | Résultat | Verdict |
|---|---|---|---|
| **R3-I3** | `import 'package:cloud_firestore/...'` ajouté dans `lib/src/study/z_study_providers.dart` | AC2 **RED** : `offender = lib/src/study/z_study_providers.dart:31 → "cloud_firestore"` ; le sous-test pubspec reste VERT (non muté) | ✅ discriminant |

Le test **strippe les commentaires** (`_stripDartComment` / `_stripYamlComment`) : les nombreuses mentions `cloud_firestore` en dartdoc (documentant la frontière AD-5) ne le déclenchent PAS — seule la LIGNE DE CODE injectée est détectée. Détection `Box` bornée-mot (évite `Toolbox`/`checkbox`). **Non powerless.**

---

## 4. Conformité AD — ✅

- **AD-1** : acyclique, CORE OUT=0, binding = PUITS (aucun package ne dépend de `zcrud_riverpod`), 45 arêtes, `melos list` = **20 packages**. ✅
- **AD-5** : `zStudyWatchAllProvider` ré-émet `watchAll()` **NU** (aucune transformation) ; adapter retourne le port NEUTRE `ZStudyRepository<T>` ; aucun `cloud_firestore` en signature publique hors le paramètre `firestore`. ✅
- **AD-9 / AD-11** : `cloud_firestore` confiné à `zcrud_firestore` ; merge LWW / listener / `hasPendingWrites` NON redéclarés (portés par `ZOfflineFirstBoxRepository`). Aucun secret. ✅
- **AD-6 / AD-10** : seam `zStudyRepositoryProvider<T>` *throw* `ZScopeError` nommant le `Type` ; `folderId` vide → `Left` explicite. ✅
- **AD-15** : binding générique/thin, deps minimales. ✅
- **R20** : apport propre = composition nested + propagation du `Left` (pas la mécanique offline-first d'ES-3), honnêtement borné dans les ACs et commentaires de test. ✅

---

## FINDINGS

### 🟠 MEDIUM-1 — Le câblage de la fabrique publique `buildFolderScopedStudyRepository` → `buildFolderScopedResolver` n'est PAS couvert de façon discriminante (test-gap)
- **Fichier** : `packages/zcrud_firestore/test/z_folder_scoped_study_repository_test.dart` (couverture) / `lib/src/data/z_folder_scoped_study_repository.dart:131-136`.
- **Constat** : AC3 (chemin nested exact) et AC4 (`Left`) testent `buildFolderScopedResolver` **en isolation**. Le 3ᵉ test qui instancie réellement la **fabrique publique** `buildFolderScopedStudyRepository` n'asserte que le **TYPE de retour** (`isA<ZStudyRepository>`/`isA<ZOfflineFirstBoxRepository>`), jamais un chemin résolu à travers le dépôt construit.
- **Preuve par mutation (CONFIRMÉ)** : intervertir `collection`/`parentCollection` **au site d'appel interne de la fabrique** (`resolver: buildFolderScopedResolver(collection: parentCollection, parentCollection: collection, …)`, lignes 133-134) laisse **les 3 tests VERTS** (`All tests passed!`). Un mauvais câblage de la fabrique publiée — le symbole que lex consommera — **shipperait au vert**.
- **Nuance R20** : le risque réel est faible (pass-through d'une ligne, paramètres nommés identiques `collection: collection`), et le fichier de test **déclare honnêtement** cette frontière (« testé via le seam de composition `buildFolderScopedResolver` que la fabrique utilise EN INTERNE »). Mais l'AC3 revendique textuellement « un test **compose la fabrique** … et asserte que le resolver interne rend `users/u1/...` » — ce que le test ne fait PAS (il compose le seam extrait, pas la fabrique).
- **Correctif suggéré (faible coût, sans régression)** : ajouter un cas où la **fabrique** `buildFolderScopedStudyRepository` est exercée jusqu'à une résolution de chemin observable (p.ex. via un `ZLocalStore`/écriture pilotée sur `FakeFirebaseFirestore`, ou en asservant la lecture du resolver effectif du dépôt). À défaut, **justifier par écrit** le report (R20 : pass-through trivial, le nœud de composition réel est `buildFolderScopedResolver`, déjà couvert). Décision laissée à l'orchestrateur (règle MEDIUM).

### 🟡 LOW-1 — Le corps de la story (ACs/Tasks) contredit la réalité implémentée (hygiène doc)
- **Fichier** : `_bmad-output/implementation-artifacts/stories/es-10-2-integration-lex-douane-repo-par-repo.md`.
- **Constat** : seule la section finale « DÉCISION D'ARCHITECTURE — RÉVISION » reflète l'implémenté. Le reste décrit encore l'ancien design : AC1/AC5 (providers TYPÉS par entité), **AC7 « total arêtes = 49 » / « delta = +4 »** (réel = **45 / delta 0**), AC2 « gagne exactement les 4 dépendances … », T1 « Ajouter `zcrud_document`…`zcrud_flashcard` », T2/T6 `z_study_entity_providers(.dart/_test.dart)` (fichiers inexistants). Un lecteur (rétro, session lex, futur mainteneur) peut se fier à un AC caduc.
- **Correctif suggéré** : annoter les ACs/Tasks obsolètes d'un renvoi explicite « SUPERSEDED par la RÉVISION Option B (45 arêtes, binding générique) », ou aligner AC7 sur 45. Non bloquant (la section RÉVISION est marquée PRIME).

### 🟡 LOW-2 (nit, HORS PÉRIMÈTRE ES-10.2) — `z_study_legacy_codec_test.dart` charge ses fixtures par chemin CWD-relatif
- **Fichier** : `packages/zcrud_firestore/test/z_study_legacy_codec_test.dart:36` (`File('test/fixtures/iffd_legacy/$name.json')`).
- **Constat** : VERT sous `melos` (CWD = dossier du package) mais **RED (20 échecs `PathNotFoundException`)** si on lance `flutter test packages/zcrud_firestore` depuis la **racine du repo**. Peut faire croire à tort à une régression lors d'une re-vérification. Fixtures présentes et git-trackées ; **pré-existant ES-3, non introduit par ES-10.2**. Signalé uniquement pour éviter un faux positif de re-vérif.

---

## Preuves R3 (RC HORS pipe, R15)

| Gate | Commande | RC / résultat |
|------|----------|---------------|
| Analyze | `dart analyze packages/zcrud_riverpod packages/zcrud_firestore` | **RC=0** — No issues found |
| Tests riverpod (R14) | `flutter test` (CWD = package) | **RC=0 — 25/25** |
| Tests firestore (R14) | `flutter test` (CWD = package) | **RC=0 — 176/176** |
| Graphe (AC7 révisé) | `python3 scripts/dev/graph_proof.py` | **RC=0 — 45 arêtes, ACYCLIQUE OK, CORE OUT=0 OK, 20 nœuds** |
| Sanity | `dart run melos list` | **20 packages** |
| Gates repo-wide (AC8) | `dart run melos run verify` | **RC=0 — VERT repo-wide** (reserved-keys/secrets/web/serialization-compat) |

**Injections adversariales rejouées (toutes restaurées, R13 — diffs post-restauration vides)** :
`R3-I6` swap resolver → AC3 RED ✅ · `R3-I4` flatTopLevel repli → AC4 RED ✅ · `R3-I3` import `cloud_firestore` binding → AC2 RED ✅ (commentaires strippés) · **[extra]** swap au site d'appel de la fabrique → **tous verts** (⇒ MEDIUM-1).

---

## Décision

✅ **`review` → prêt pour `done`.** La RÉVISION Option B est réellement appliquée et prouvée : binding générique (45 arêtes, CORE OUT=0, acyclique), frontière EX-3 respectée, `melos run verify` VERT repo-wide, adapter (B) neutre et discriminant. **Aucun HIGH/MAJEUR.** MEDIUM-1 (test-gap sur le câblage de la fabrique publique) à corriger dans le périmètre **ou** justifier par écrit (R20) avant `done`, par décision de l'orchestrateur. LOW-1/LOW-2 optionnels.

---

## Remédiation orchestrateur (2026-07-16) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| MEDIUM-1 (câblage fabrique publique non discriminant) | 🟠 MEDIUM | ✅ **CORRIGÉ** | La fabrique PUBLIQUE `buildFolderScopedStudyRepository` (symbole que lex consommera) inlinait `buildFolderScopedResolver(collection, parentCollection)` sans test discriminant — un swap au SITE D'APPEL passait vert. Correctif : (1) getter `@visibleForTesting ZFirestorePathResolver get resolver` ajouté à `ZOfflineFirstBoxRepository` (additif, dans `zcrud_firestore`) ; (2) le test AC3-fabrique assère désormais que le resolver du repo produit résout `users/u1/users_folders/f1/study_folders`. **Prouvé par l'orchestrateur** : swap `collection`/`parentCollection` au site d'appel de la fabrique → le test AC3-fabrique ROUGIT (`Actual: users/u1/study_folders/f1/users_folders`, RC=1) **tandis que le test du helper en isolation reste VERT** (exactement le trou signalé) ; restauré → RC=0. |
| LOW-1 (corps de story contredit l'implémenté) | 🟡 LOW | ✅ **CORRIGÉ** | Bandeau « CORPS PARTIELLEMENT SUPERSEDED » ajouté en tête de la story, pointant vers la section de décision Option B (faisant foi) et marquant AC1/AC5/AC7/T1/T2/T6 comme caducs. |
| LOW-2 (fixtures CWD-relatives z_study_legacy_codec) | 🟡 LOW | 🟡 **CONSIGNÉ (hors périmètre)** | Pré-existant ES-3 : `z_study_legacy_codec_test.dart` charge ses fixtures en chemin CWD-relatif → RED si lancé `flutter test packages/zcrud_firestore` depuis la racine, VERT sous melos/CWD-package. Fixtures présentes+trackées. Non introduit ni aggravé par ES-10.2 ; à corriger dans une passe ES-3 dédiée. Consigné. |

**Re-vérif verte post-remédiation (RC hors pipe — R15)** : `flutter test` zcrud_firestore (R14) → RC=0, **176 tests** · zcrud_riverpod → RC=0, 25 · `melos run verify` REPO-WIDE → RC=0 (reserved-keys/secrets/web/serialization OK) · graph_proof RC=0 (**45 arêtes**, ACYCLIQUE, CORE OUT=0, aucune arête binding→entité/firestore) · analyze RC=0.

**Verdict final** : ✅ **PRÊT POUR `done`** — révision Option B validée ; MEDIUM-1 (câblage fabrique) corrigé et prouvé ; LOW-1 corrigé ; LOW-2 consigné. Binding générique confirmé, frontière EX-3 respectée, adapter firestore (B) discriminant.
