# Code Review — Story ES-1.1 : Remontée de `ZStudyFolder` vers `zcrud_study_kernel`

- **Story** : `es-1-1-remontee-zstudyfolder-kernel.md` (statut `review`)
- **Mode de revue** : skill BMAD `bmad-code-review` réellement invoqué (step-file architecture) — pas de fallback disque nécessaire.
- **Reviewer** : revue adversariale (Blind Hunter + Edge Case Hunter + Acceptance Auditor).
- **Date** : 2026-07-12
- **Périmètre du diff** : nouveau package `packages/zcrud_study_kernel/` (barrel, port `ZSessionCandidate`, 5 types domaine déplacés/découplés, 5 fichiers de test) + refactor `packages/zcrud_flashcard/` (pubspec, barrel, `z_flashcard.dart`, extension typée, 2 tests) + `pubspec.yaml` racine.

---

## Verdict : **APPROVED** (0 HIGH · 0 MEDIUM · 3 LOW)

L'implémentation satisfait les 8 ACs, respecte les AD héritées (AD-1/AD-3/AD-4/AD-10) et les AD study (AD-17/AD-18/AD-26), et ne présente **aucun défaut de correction**. Les trois déviations relevées (re-export en bloc, changement de comportement défensif, générique `selectFrom<T>`) sont **additives/non-cassantes**, documentées dans les Completion Notes, et couvertes par les tests. Elles sont consignées ci-dessous comme LOW pour décision de l'orchestrateur/architecte, aucune ne bloque le `done`.

### Vérif verte rejouée réellement sur disque (indépendante du rapport dev)

| Contrôle | Commande | Résultat |
|---|---|---|
| Analyse kernel | `dart analyze --fatal-infos` (zcrud_study_kernel) | **No issues found** (RC=0) |
| Analyse flashcard | `dart analyze --fatal-infos` (zcrud_flashcard) | **No issues found** (RC=0) |
| Acyclicité | `scripts/dev/graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK** ; arête `zcrud_flashcard → zcrud_study_kernel → zcrud_core` ; aucune arête retour `study_kernel → flashcard` (RC=0) |
| Tests kernel | `dart test` (zcrud_study_kernel) | **38/38 passed** (RC=0), dont round-trip byte-identique + défensif |
| Résolution NFR-S10 | test `z_kernel_resolution_test.dart` | fermeture transitive = `{zcrud_core, zcrud_annotations}` (aucun Firebase/flashcard/satellite lourd) |
| Imports orphelins | `grep` relative-imports moved files dans flashcard/lib | **0** (aucun chemin cassé) |

> Baseline E9 (165 tests flashcard) non rejouée intégralement dans cette revue (suite Flutter longue) ; l'analyse statique + les 2 diffs de test confirment l'absence de suppression/affaiblissement (cf. AC4 ci-dessous). Décompte 165→165 rapporté par le dev, cohérent avec les diffs inspectés.

---

## Vérification des Acceptance Criteria

| AC | Verdict | Preuve |
|---|---|---|
| **AC1** — kernel source unique, barrel, deps `core`+`annotations` seules | ✅ | `pubspec.yaml` kernel : `dependencies: {zcrud_core, zcrud_annotations}` uniquement ; barrel `lib/zcrud_study_kernel.dart` exporte les 6 symboles ; aucune dép lourde/état. |
| **AC2** — refactor non-régressif, réexport transitoire, `hide` préservés | ✅ (voir LOW-1) | Kernel masque `ZStudyFolderZcrud`/`ZStudySessionConfigZcrud` ; flashcard re-exporte le barrel kernel (hides propagés). `z_study_folder_hierarchy.dart` **importe** `z_study_folder` sans le ré-exporter → aucune fuite de l'extension générée. |
| **AC3** — acyclicité prouvée repo-wide | ✅ | `graph_proof.py` RC=0, ACYCLIQUE, 23 arêtes, 15 nœuds ; re-joué dans cette revue. |
| **AC4** — non-régression E9 (tests ≥ baseline, rien retiré) | ✅ | Diffs des 2 tests flashcard : assertions **renforcées** (double vérif neutre + typée), aucun `test(...)` supprimé. `z_study_folder_test`/`z_study_folder_hierarchy_test` inchangés (réexport via barrel). |
| **AC5** — pas de symbole public supprimé référencé | ✅ | `grep` repo-wide : 0 consommateur externe des types déplacés ; surface = ancienne + `ZSessionCandidate` (addition, pas suppression). |
| **AC6** — découplage acyclique config/selector | ✅ | `types: List<String>?` (nom `types` conservé) ; port neutre `ZSessionCandidate` (4 getters) ; `ZFlashcard implements ZSessionCandidate` (`typeKey => type.name`, `type` non-nullable → pas de NPE) ; `config.types.contains(candidate.typeKey)`. Aucun generic de sérialisation. |
| **AC7** — `zcrud_mindmap` inchangé | ✅ | Aucune arête `mindmap → study_kernel` dans `graph_proof` ; mindmap reste sur `folderId` neutre. |
| **AC8** — test de résolution/modularité | ✅ | `z_kernel_resolution_test.dart` : assertion outillée, closure = `{core, annotations}`, exclut explicitement firestore/flashcard/satellites lourds. |

---

## Findings

### LOW-1 — Réexport en bloc du barrel kernel (élargit la surface flashcard au-delà du ciblage prescrit)
- **Fichier** : `packages/zcrud_flashcard/lib/zcrud_flashcard.dart:36` (`export 'package:zcrud_study_kernel/zcrud_study_kernel.dart';`)
- **Catégorie** : surface publique / future-proofing (AC2, T4).
- **Description** : T4 prescrivait un **export ciblé** (« via `show`/`hide` équivalents » — objectif « surface publique de `zcrud_flashcard` inchangée »). Le dev a retenu un réexport **en bloc** de tout le barrel kernel. Délta réel de surface aujourd'hui = **un seul** nouveau symbole public (`ZSessionCandidate`, port légitime que `ZFlashcard` implémente) — les `hide` restent effectifs (appliqués par le barrel kernel), donc **aucune régression ni fuite d'extension générée**.
- **Impact AD** : bénin à date (AD-18 respecté, hides préservés). Risque résiduel : tout symbole **futur** ajouté au barrel kernel deviendra automatiquement public via `zcrud_flashcard` — c'est exactement le type de dérive de surface cross-package que la leçon `ZExportApi` (E11a-3) invite à cadrer.
- **Recommandation** : optionnel — remplacer par un `export ... show ZStudyFolder, ZReviewMode, ZStudySessionConfig, ZStudySessionSelector, ZSessionCandidate, validatePlacement, ZStudyFolderHierarchy;` (liste explicite) pour figer la surface. Non bloquant.

### LOW-2 — Changement de comportement du round-trip pour les clés de type inconnues (déplacement du drop défensif)
- **Fichier** : `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart` (champ `types`) + `packages/zcrud_flashcard/lib/src/domain/z_study_session_config_flashcard_x.dart:24` (`flashcardTypes`)
- **Catégorie** : compat de sérialisation (AD-10).
- **Description** : en E9, `types: List<ZFlashcardType>?` **droppait** toute valeur d'enum inconnue **à la désérialisation** (`_$enumFromName → null`, filtré). Désormais `types: List<String>?` **conserve** les clés inconnues au niveau du noyau ; le drop des inconnues a migré dans le getter `flashcardTypes` (côté flashcard). Conséquence testée (`z_study_session_config_test.dart` kernel L.93-104) : `fromMap({'types':['multipleChoice','futureUnknownType','exercise']}).toMap()['types']` rend **les 3 clés** (E9 en aurait rendu 2). Les éléments **non-`String`** (int/null) restent, eux, filtrés (L.149-152).
- **Impact AD** : **conforme AD-10** (jamais de throw) et **byte-identique pour toute donnée valide** ; c'est en réalité un gain de forward-compat (round-trip zéro-perte des clés futures). Le filtrage de sélection reste correct (une clé inconnue dans `config.types` ne matche simplement aucun candidat). Aucune régression fonctionnelle de sélection.
- **Recommandation** : aucune action code requise ; **acter** avec l'architecte que les documents persistés portant d'anciennes clés inconnues/legacy seront désormais **restitués** (au lieu d'être nettoyés au round-trip). Documenté et testé.

### LOW-3 — `selectFrom<T extends ZSessionCandidate>` : déviation (justifiée) du littéral T3
- **Fichier** : `packages/zcrud_study_kernel/lib/src/domain/z_study_session_selector.dart:47`
- **Catégorie** : conformité de contrat (AD-3, T3).
- **Description** : T3 prescrivait `selectFrom(Iterable<ZSessionCandidate>)`. Le dev a retenu `selectFrom<T extends ZSessionCandidate>(Iterable<T>) → List<T>` pour **préserver le type concret d'entrée** en sortie (un satellite récupère ses propres entités ; les tests E9 accèdent à `card.question`).
- **Impact AD** : **AD-3 respecté** — il s'agit d'un générique de **collection**, pas d'un générique de (dé)sérialisation (aucun `ZStudySessionConfig<T>`, aucun `toMap<T>`). Strict sur-ensemble du contrat, opère toujours via le port neutre `ZSessionCandidate`. `return const <Never>[];` (count ≤ 0) est un sous-type valide de `List<T>`.
- **Recommandation** : aucune — déviation saine et documentée (Completion Notes). Consignée pour traçabilité.

---

## Points positifs (adversarial clean)
- **Acyclicité réelle** : le kernel n'importe jamais `zcrud_flashcard` (ni transitivement) ; `ZSessionCandidate` est un port pur-Dart minimal (4 getters), `ZFlashcard.tagIds` est bien `List<String>` non-nullable (conforme au port), `type` non-nullable (pas de NPE sur `typeKey`).
- **Wire byte-identique** prouvé par test kernel (`{'types':['multipleChoice','trueOrFalse']}`), gate `verify:serialization` préservé.
- **Défensif AD-10** intact : `mode` inconnu → `spaced`, `types` non-liste → `null`, éléments non-`String` filtrés, `extra`/`extension` round-trip, aucun throw.
- **`hide` non fuités** : l'extension générée `ZStudyFolderZcrud`/`ZStudySessionConfigZcrud` n'est pas ré-exposée via `z_study_folder_hierarchy.dart` (import seul, pas d'export).
- **Runner `dart test`** cohérent (surface pur-Dart, aucune fuite du SDK Flutter), même convention que `zcrud_annotations`.
- **AD-19 hors-périmètre respecté** : aucune conversion `ZSyncMeta` amorcée (déférée ES-1.3).
- **Ergonomie typée** `flashcardTypes`/`withFlashcardTypes` restitue fidèlement le comportement typé E9 (drop défensif des inconnues) **côté flashcard**, sans polluer le noyau (AD-17).

---

## Synthèse
Refactor de tête bloquante **propre et conforme**. La neutralisation `types → List<String>` + port `ZSessionCandidate` est la seule voie compatible AD-1/AD-3/AD-17 et non-régressive au niveau wire ; elle est correctement implémentée, testée (38 tests kernel + 2 tests flashcard renforcés) et prouvée acyclique. Aucun finding HIGH/MEDIUM. Les 3 LOW sont additifs/documentés — **LOW-1** mérite une décision (ciblage du réexport) mais ne bloque pas le `done`. **Recommandation : passage à `done`** après ratification des LOW par l'orchestrateur, avec correction optionnelle de LOW-1 dans le périmètre de la story (édition d'une seule ligne du barrel flashcard, non-cassante).

---

## Disposition orchestrateur (2026-07-12)

Verdict revue **APPROVED** (0 HIGH / 0 MEDIUM / 3 LOW). Vérif verte **rejouée sur disque par l'orchestrateur** (indépendamment de l'agent) : `melos run analyze` repo-wide SUCCESS · `graph_proof.py` ACYCLIQUE OK / CORE OUT=0 (arête `flashcard → study_kernel → core`, aucune arête retour) · `flutter test zcrud_flashcard` = **165** (= baseline, zéro régression) · `dart/flutter test zcrud_study_kernel` = **38** · `melos run verify` repo-wide **RC=0**.

Disposition des 3 LOW (politique CLAUDE.md — LOW = optionnels, corrigés si triviaux sinon consignés avec justification) :

- **LOW-1 (réexport en bloc du kernel depuis le barrel `zcrud_flashcard`)** — **REPORTÉ avec justification** (à ES-1.2). Après énumération exhaustive de la surface publique du kernel, celle-ci inclut des **symboles générés** (`registerZStudyFolder`, `registerZStudySessionConfig`, field-specs via `part '*.g.dart'`) en plus des 8 symboles déclarés. Un `show` explicite devrait tous les lister → **fragile** (un oubli casserait un consommateur externe lors de la migration DODLP). Le réexport en bloc est au contraire le comportement correct d'un **shim de compat transitoire** : il préserve la surface historique E9 *complète*. Contrepartie (fuite des symboles futurs du kernel) documentée par un commentaire dans `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` et **revisitée à ES-1.2** (quand le kernel gagnera `ZColorPalette`/`applyOrder`, hors surface flashcard) → bascule vers un ciblage `show`/`hide` à ce moment.
- **LOW-2 (drop défensif des clés de type inconnues migré de la désérialisation vers le getter `flashcardTypes`)** — **ACCEPTÉ**. Round-trip JSON byte-identique pour toute donnée valide (AD-10 respecté, gain forward-compat), documenté et testé, aucune régression de sélection. Aucune action.
- **LOW-3 (`selectFrom<T extends ZSessionCandidate>` générique de collection)** — **ACCEPTÉ**. Générique de collection (pas de sérialisation) → AD-3 respecté ; sur-ensemble strict opérant via le port neutre, justifié (préserve le type concret d'entrée en sortie pour l'ergonomie satellite). Aucune action.

**Conclusion : story ES-1.1 → `done`.** Story verte, acyclicité prouvée, non-régression E9 confirmée, 0 finding bloquant, LOW soldés (2 acceptés, 1 reporté justifié).
