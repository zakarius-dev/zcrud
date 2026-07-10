# Code Review — Story E10-1 : ZMindmapNode/ZMindmap + ZMindmapTreeOps

- **Skill** : `bmad-code-review` (invoqué via le tool Skill, mode Skill — pas de fallback disque).
- **Story** : `_bmad-output/implementation-artifacts/stories/e10-1-zmindmapnode-treeops.md` (status `review`).
- **Baseline** : `04aaaf09` (frontmatter). Périmètre = fichiers `packages/zcrud_mindmap/` uniquement (aucune revue des workstreams en vol zcrud_core/zcrud_firestore/zcrud_flashcard).
- **Reviewer** : agent adversarial (Blind Hunter + Edge Case Hunter + Acceptance Auditor).
- **Date** : 2026-07-10.

## Vérif verte rejouée (réelle, sur disque)

| Gate | Commande | RC réel |
|------|----------|---------|
| Analyze | `dart analyze packages/zcrud_mindmap` | **0** (« No issues found! ») |
| Test | `flutter test` (package) | **0** — **55 tests** passés (conforme au Dev Agent Record) |

## Synthèse de conformité (ACs / AD)

- **AC1** OK — `ZMindmapNode extends ZNode with ZExtensible` ; champs `final` ; `children` en `List.unmodifiable` (copie défensive testée, mutation externe rejetée) ; aucun `copyWith` public (mutation via TreeOps).
- **AC2** OK — slots AD-4 `extension` (versionné, défaut null) + `extra` (jamais null) ; réutilise `ZExtension.guard` ; clés inconnues → `extra` round-trip (testé).
- **AC3** OK — `ZMindmap` forêt multi-racine, `folder_id` snake_case ; invariant AD-16 (ni `updated_at` ni `is_deleted`) testé sur node ET map — **voir MEDIUM-1 (angle non couvert)**.
- **AC4** OK — `updateNode` (`''` efface / `null` non touché), `addChild`, `deleteNode`, `findNode`, factories ; structural sharing `identical` sur branches intactes (testé).
- **AC5** OK — `moveNode`/`indentNode`/`outdentNode`/`reorderChild` avec recalcul `level` cascade (profondeur ≥3 testée) ; anti-cycle soi + descendants (testé) ; no-op → `identical` ; clamp d'index.
- **AC6** OK — `fromJson` défensif, ne throw jamais (map vide, children non-liste, enfant corrompu, level non-int, extension version/decoder throw/non-map) ; round-trip snake_case stable.
- **AC7** OK — barrel exporte les 3 fichiers, `ZMindmapApi` conservé ; **zéro édition `zcrud_core`** (contrainte WS-C respectée) ; aucun import de gestionnaire d'état/Firebase/Syncfusion. AD-13 RTL/a11y : sans objet (domaine pur, pas d'UI).

Réutilisation du cœur **exemplaire** (AD-1) : aucun contrat de nœud/extension réinventé, `ZExtension.guard` employé, aucune dépendance runtime nouvelle.

---

## Findings

### MEDIUM-1 — Le slot `extra` absorbe et ré-émet les clés de sync réservées AD-16 (`updated_at`/`is_deleted`)

- **Fichiers** : `lib/src/domain/z_mindmap.dart:59-66` (`_knownKeys`), `:96-101` (capture extra), `:133` (`...extra` dans `toJson`) ; symétriquement `lib/src/domain/z_mindmap_node.dart:74-81`, `:111-116`, `:146`.
- **Constat** : `_knownKeys` ne liste que les clés métier. Toute clé absente de cet ensemble — **y compris `updated_at` et `is_deleted`** — est capturée dans `extra` par `fromJson`, puis **ré-émise telle quelle** par `toJson` (`...extra`). L'invariant AD-16 « sync HORS-ENTITÉ » n'est donc garanti que pour une entité **fraîchement construite** (ce que testent `z_mindmap_test.dart:55` et `z_mindmap_node_test.dart:89`), mais **pas sur le chemin de désérialisation** : `ZMindmap.fromJson({...,'updated_at':X,'is_deleted':true}).toJson()` ré-écrit ces deux champs.
- **Impact** : latent tant que E5 n'est pas livré (aucun appelant actuel ne fournit une map mêlant entité + méta). Mais dès qu'un adaptateur store (offline-first LWW sur `updated_at` + soft-delete `is_deleted` — précisément les deux clés interdites) relira/réécrira un document où la méta a fui, l'entité **re-persistera** les champs de sync, contournant silencieusement la séparation hors-entité que la story qualifie d'« INVARIANT DUR ».
- **Recommandation** : défense en profondeur — exclure une denylist de clés réservées (`updated_at`, `is_deleted`, éventuellement `created_at`) de la capture `extra`, OU documenter explicitement que le store DOIT stripper la méta avant `fromJson`. Ajouter un test `fromJson(map avec updated_at/is_deleted) → toJson()` n'émet aucune des deux. Correctif trivial, dans le périmètre de la story.

### LOW-1 — Perte de l'`extension` au round-trip en l'absence de décodeur

- **Fichier** : `lib/src/domain/z_mindmap_node.dart:124-129` (et `z_mindmap.dart:112-117`).
- **Constat** : `fromJson` sans `extensionDecoder` **abandonne** la sous-map `extension` (elle est dans `_knownKeys`, donc pas conservée dans `extra` — cf. test `z_mindmap_node_test.dart:193-200`). Un `toJson` ultérieur perd donc totalement la charge utile d'extension.
- **Impact** : un adaptateur (E5 firestore) qui désérialise sans décodeur enregistré **efface silencieusement** les données d'extension à la ré-écriture. Comportement assumé (responsabilité du décodeur, AD-10) mais risque de fidélité pour la persistance.
- **Recommandation** : documenter le contrat de fidélité dans le docstring `fromJson`, ou conserver la map `extension` brute dans `extra` quand aucun décodeur n'est fourni (à re-injecter en `toJson`).

### LOW-2 — `ZMindmapNode.fromJson` autonome ne renormalise pas les `level` des enfants

- **Fichier** : `lib/src/domain/z_mindmap_node.dart:118-132`.
- **Constat** : le node-level `fromJson` fixe `level` à la valeur JSON (ou 0) mais **ne cascade pas** sur les enfants ; la renormalisation n'a lieu qu'au niveau forêt (`ZMindmap.fromJson` → `normalizeLevels`). Un `ZMindmapNode.fromJson` d'un sous-arbre aux `level` incohérents conserve ces valeurs jusqu'à la prochaine op TreeOps.
- **Impact** : nul dans l'usage canonique (nœuds toujours dans un `ZMindmap`), mais surprenant pour un consommateur désérialisant un nœud isolé. Comportement documenté dans le docstring (`normalisé au niveau forêt`).
- **Recommandation** : conserver tel quel (design assumé) ou ajouter une note d'usage. Pas de correctif requis.

### LOW-3 — Couverture de test : `reorderChild` avec `newIndex` hors bornes non exercé

- **Fichier** : `test/z_mindmap_tree_ops_test.dart:257-263`.
- **Constat** : le `_reorderList` clampe `newIndex` (`z_mindmap_tree_ops.dart:388`), mais les tests n'exercent que `oldIndex` hors bornes ; le clamp de `newIndex` n'est pas asserté.
- **Recommandation** : ajouter un cas `reorderChild(f,'A',0,999)` → dernier position. Non bloquant.

### Informationnel (NIT) — Sémantique d'`index` de `moveNode` en même-parent

`moveNode` détecte le no-op même-emplacement en clampant sur `destLenBefore - 1` (liste **avec** le nœud), tandis que `_insertAt` clampe sur la liste **après** retrait — les deux références sont cohérentes en même-parent (longueur après retrait = `destLenBefore - 1`), donc pas de bug, mais le référentiel d'index « après retrait » mériterait une ligne de docstring (AC5 le qualifie déjà de « clamp ou no-op documenté »). Aucune action requise.

---

## Verdict

**PRÊT POUR `done` après traitement du MEDIUM-1** (correction recommandée — denylist des clés de sync réservées + test ; sinon justification écrite conforme à la politique MEDIUM). Aucun finding HIGH/MAJEUR. Réutilisation du cœur, immuabilité, structural sharing, anti-cycle et désérialisation défensive sont corrects et solidement testés (55 tests, bornes couvertes). Analyze RC=0, test RC=0.

---

## Résolution (orchestrateur)

- **MEDIUM-1 — CORRIGÉ.** Ajout d'un denylist `_reservedSyncKeys = {updated_at, is_deleted}` exclu de la capture `extra` dans `z_mindmap_node.dart` ET `z_mindmap.dart` (garantit l'invariant AD-16 sur le chemin `fromJson→toJson`, même sur une map d'entrée mêlant des métadonnées de sync). Test dédié ajouté (`z_mindmap_test.dart`, groupe round-trip) assertant que `updated_at`/`is_deleted` en entrée ne survivent ni dans `extra` (carte + nœud) ni dans la sortie `toJson`. **Re-vérif verte : analyze RC=0, 56 tests (+1).**
- **LOW-1, LOW-2, LOW-3 — CONSIGNÉS** (politique LOW = optionnels) : LOW-1 (perte de `extension` sans décodeur) et LOW-2 (renormalisation de `level` au niveau forêt seulement) sont des designs **assumés et documentés** dans le code ; LOW-3 (cas de test clamp `newIndex` hors bornes) reste une amélioration de couverture non bloquante. À reprendre si besoin en E10-2/E10-3.
- **Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert.
