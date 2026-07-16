# Code Review — Story ES-10.1 (Providers Riverpod + égalité profonde `ZSessionConfigKey` au binding)

- **Skill réel invoqué** : `bmad-code-review` (tool `Skill`, préfixe `bmad-*`) — chargé, workflow step-file suivi. Pas de fallback disque nécessaire.
- **Mode** : revue ADVERSARIALE (méfiance maximale — validation sur POUVOIR DISCRIMINANT, pas sur EXISTENCE).
- **Périmètre** : `packages/zcrud_riverpod/` uniquement. `zcrud_core`/`zcrud_study_kernel` CONSOMMÉS (non modifiés). Toutes les injections R3 restaurées par édition ciblée (R13) — résidu `INJECT` = 0.
- **Date** : 2026-07-16.
- **Verdict** : ✅ **APPROVED (vert)** — 0 HIGH, 0 MAJEUR, 0 MEDIUM. 3 findings LOW (optionnels). Chaque AC load-bearing est prouvé POWERFUL par mutation réelle.

---

## 1. Preuves de vérification rejouées réellement (RC hors pipe, R14/R15)

| Gate | Commande | Résultat |
|------|----------|----------|
| Tests study (R14, Flutter) | `flutter test packages/zcrud_riverpod/test/study` | **+15 All tests passed!** |
| Tests riverpod complets | `flutter test packages/zcrud_riverpod` | **+23 All tests passed!** (E2-9 parité/scope/idiom + 3 suites study) |
| Analyze | `dart analyze packages/zcrud_riverpod` | **No issues found!** (RC=0) |
| Graphe (AC6) | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK**, **CORE OUT=0 OK**, **total arêtes = 45**, 20 nœuds. Arête `zcrud_riverpod → zcrud_study_kernel` SORTANTE présente ; aucun package study → binding. |
| Sanity | `dart run melos list` | **20** packages. |
| gate:secrets | `dart run scripts/ci/gate_secret_scan.dart` | **OK — aucun secret** (RC=0). |
| gate:reserved-keys | `dart run scripts/ci/gate_reserved_keys.dart` | **OK — volets (A)+(B)+couverture** (RC=0). |
| Intégrité git | `git status --short` | Seuls `pubspec.yaml`+barrel modifiés, `lib/src/study/`+`test/study/` untracked. **Aucun** fichier `zcrud_core`/`zcrud_study_kernel` touché. |

---

## 2. Mutation testing adversarial (R3 / R27) — chaque garde prouvée LOAD-BEARING

Chaque ligne porteuse a été **neutralisée réellement sur disque**, le test attendu a **rougi**, puis la ligne a été **restaurée** (R13). Résidu final `grep INJECT lib/src/study` = **CLEAN**.

| Injection | Cible | Test attendu ROUGE | Observé |
|-----------|-------|--------------------|---------|
| **R3-I3 (SM-1, AC3, OBJECTIF N°1)** | `ZSessionConfigKey.==` dégradé en `identical(config, other.config)` | `z_session_family_rebuild_test` | 🔴 **RED** — compteur builds **1 → 2** (`Expected <1> / Actual <2>`). La family cesse de déduppliquer deux configs égales-mais-distinctes. **Le test SM-1 est PUISSANT**, pas un vœu. |
| **R3-I2 (count, AC2)** | `a.count == b.count` neutralisé (`true`) | cas mono-champ `count` | 🔴 **RED** sur le SEUL cas `count` (les 6 autres restent verts) — contribution par champ prouvée. |
| **R3-I2 (extra, AC2)** | `zJsonEquals(a.extra,b.extra)` neutralisé (`|| true`) | cas mono-champ `extra` **+** cas extra imbriqué divergent | 🔴 **RED** sur les deux (profondeur `zJsonEquals` prouvée). |
| **R3-I4 (seam throw, AC4)** | `throw ZScopeError` → `throw StateError` | `z_study_providers_test` AC4 | 🔴 **RED** — le test discrimine le **TYPE** `ZScopeError` (pas juste « throws »), message contenant le `Type` (`_FakeEntity`). |
| **R3-I5 (auto-dispose, AC5)** | `StreamProvider.autoDispose` → `StreamProvider` | `z_study_providers_test` AC5 | 🔴 **RED** — `onCancel` non appelé (`Expected true / Actual false`) : fuite de souscription détectée. |
| **AC1 (flux nu exact)** | `watchAll()` → `watchAll().map((l)=>l.reversed…)` | `z_study_providers_test` AC1 | 🔴 **RED** — `Expected [[a],[a,b]] / Actual [[a],[b,a]]` : ré-émission exacte (ordre/contenu) prouvée. |

**Égalité par champ (AC2, leçon ES-9.3 MEDIUM-1)** : le test `z_session_config_key_equality_test` varie bien **les 7 champs un à un** (`mode`, `folderId`, `tagIds`, `types`, `count`, `extension`, `extra`) via `copyWith`, plus un cas `extra` imbriqué égal (dedup) et un cas `extra` imbriqué divergent — **jamais « tous à la fois »**. `zJsonEquals`/`zJsonHash` (`zcrud_core`) sont utilisés pour `tagIds`/`types`/`extra` (jamais l'égalité d'identité d'une `Map`/`List`), et sont **mutuellement cohérents** (`a==b ⇒ hash(a)==hash(b)` — vérifié dans le source `z_json_equality.dart`, listes ordre-signifiant, maps commutatives).

---

## 3. Conformité AD (invariants NON-NÉGOCIABLES)

- **AD-24 (égalité de clé AU BINDING)** ✅ — `ZSessionConfigKey` vit dans `zcrud_riverpod` et réimplémente l'égalité profonde ; le kernel garde son unique `ZStudySessionConfig` persistable INCHANGÉE (aucune 2ᵉ forme ajoutée — `git status` confirme kernel non touché). Le contrat de caching Riverpod ne fuit pas dans le domaine.
- **AD-1 (graphe acyclique, CORE OUT=0)** ✅ — 45 arêtes (44 → 45, delta +1 = `zcrud_riverpod → zcrud_study_kernel` SORTANTE), 20 nœuds, ACYCLIQUE, CORE OUT=0. Aucun package study ne dépend du binding (fan-in SORTANT, binding = puits). Aucun package d'entité (`zcrud_document`/`note`/`exam`) tiré (réservé ES-10.2). `flutter_riverpod` n'est pas un `zcrud_*` → n'entre pas dans le compte.
- **AD-2 / AD-15 / NFR-S5 (Riverpod confiné)** ✅ — `flutter_riverpod` importé UNIQUEMENT dans `lib/src/study/z_study_providers.dart` (binding). `z_session_config_key.dart` n'importe même PAS Riverpod (pur binding-value). Garanti STRUCTURELLEMENT : le graphe interdit à `zcrud_core`/`zcrud_study*` de référencer un symbole `zcrud_riverpod`.
- **AD-5 / AD-11** ✅ — `zStudyWatchAllProvider` enveloppe le `Stream<List<T>>` NU du port sans transformation ; le seam retourne le port `ZStudyRepository<T>` (écritures `ZResult` inchangées, non ré-enveloppées).
- **AD-6 / AD-10 (seams throw)** ✅ — `zStudyRepositoryProvider<T>` throw `ZScopeError` actionnable (message nomme le `Type`) tant que non surchargé ; jamais de `null`/repli silencieux.
- **AD-4** ✅ — port générique `ZStudyRepository<T>` (generics pour un PORT, pas pour la sérialisation) ; slots `extension`/`extra` couverts par la clé.

---

## 4. Findings

### HIGH / MAJEUR / MEDIUM : **AUCUN**

Cas rare : toutes les injections adversariales prévues confirment le pouvoir des gardes. Le test SM-1 (AC3) — point critique de la story (objectif produit n°1) — n'est **PAS** powerless : il rougit 1→2 sous keying par identité. Aucune faille de l'objectif n°1.

### LOW (optionnels — corrigés si triviaux, sinon consignés)

- **LOW-1 — `zStudySessionSelectorProvider` `.autoDispose` non co-testé.**
  `z_study_providers.dart:85` — la family de sélection porte `.autoDispose` mais aucune assertion ne la couvre (seul le `StreamProvider` d'AC5 a un test `onCancel`). Risque réel ~nul (provider PUR dérivé, sans souscription ni ressource), mais la garde `.autoDispose` y est « vœu » (non load-bearing par test). Correctif possible : un test lisant/relâchant la family et asservant `didDisposeProvider`, OU retirer `.autoDispose` (inutile sur un provider pur sans ressource). Non bloquant.

- **LOW-2 — Test AC5 dépendant du timing (`Duration(milliseconds: 20)`).**
  `z_study_providers_test.dart:137` — l'attente de propagation de l'auto-dispose repose sur un délai fixe de 20 ms ; sous CI chargée cela peut flaker. Le Debug Log dev l'assume. Correctif possible : sonder `onCancel` via `pump`/retry borné plutôt qu'un délai fixe. Non bloquant.

- **LOW-3 (informational — pas un défaut de code) — injection R3-I2h non réalisable telle qu'écrite.**
  La story annonce que « retirer un champ de `hashCode` » fait rougir un test. En Dart le contrat `==`/`hashCode` n'exige que `a==b ⇒ hash(a)==hash(b)` (pas la réciproque) : retirer un champ du `hashCode` (tout en le gardant dans `==`) n'invalide PAS le contrat et ne rougit AUCUN test (les cas mono-champ utilisent le matcher `equals`, adossé à `==` seul). **Le `hashCode` livré est correct et cohérent** ; la direction DANGEREUSE (`==` couvre plus de champs que `hashCode` ⇒ dedup family cassé) EST couverte — par l'assertion `hashCode ==` du cas « égales mais distinctes » ET par le compteur de builds SM-1. Aucun changement de code requis ; note pour ne pas revendiquer R3-I2h comme prouvé (le Dev Agent Record ne le revendique d'ailleurs pas — seuls I2 count+extra, I3, I4, I5 sont déclarés).

---

## 5. Conclusion

Story **ES-10.1 APPROVED** — la story reste **VERTE** après revue. Aucun finding HIGH/MAJEUR/MEDIUM. Les 3 LOW sont optionnels et non bloquants ; ils peuvent être consignés/reportés sans justification lourde (LOW-1/LOW-2 = durcissement de test ; LOW-3 = simple note de non-revendication). Objectif produit n°1 (SM-1) matérialisé et **prouvé exécutablement** au binding. Prêt pour transition `done` (édition ciblée du sprint-status par l'orchestrateur).

---

## Remédiation orchestrateur (2026-07-16) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| LOW-1 (autoDispose selector non co-testé) | 🟡 LOW | 🟡 **CONSIGNÉ** | `zStudySessionSelectorProvider` `.autoDispose` non exercé par un test dédié. Risque ~nul (provider PUR, sans ressource à libérer autre que le cache). Consigné. |
| LOW-2 (test AC5 à délai fixe 20ms) | 🟡 LOW | 🟡 **CONSIGNÉ** | Le test auto-dispose dépend d'un `await Future.delayed(20ms)` → flakiness CI possible sous charge. Non-bloquant (la garde `onCancel` est prouvée). À rendre déterministe (pump/completer) si un flake réel est observé en CI. Consigné. |
| LOW-3 (I2h hashCode non réalisable) | 🟡 informational | 🟡 **CONSIGNÉ** | L'injection R3-I2h de la story (« retirer un champ du hashCode ») n'est pas réalisable sans violer le contrat `==`/`hashCode` ; le `hashCode` livré est correct, la direction dangereuse est couverte. Le Dev Agent Record ne revendique pas I2h. Aucun défaut. |

**Spot-check orchestrateur (R3 SM-1, objectif produit n°1)** : `ZSessionConfigKey.==` dégradé en `identical(a,b)` → deux configs égales-mais-distinctes ne sont plus dédupliquées → le test compteur de builds ROUGIT (1→2, RC=1) ; restauré → RC=0. **L'objectif produit n°1 (zéro rebuild inutile) est verrouillé au binding.**

**Vérif verte (RC hors pipe — R15)** : `flutter test` zcrud_riverpod (R14) → RC=0, **+23** · `melos run verify` repo-wide → RC=0 (tous gates) · graph_proof RC=0 (45 arêtes, ACYCLIQUE, CORE OUT=0) · analyze RC=0. Arbre propre après injections du reviewer (R13). Seul `zcrud_riverpod` touché — aucun autre repo.

**Verdict final** : ✅ **PRÊT POUR `done`** — 0 finding bloquant ; 3 LOW consignés. Toutes les gardes (SM-1, égalité profonde 7 champs, seam type, autoDispose) prouvées non-powerless.
