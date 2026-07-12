---
title: "Rapport de préparation à l'implémentation — zcrud_study (extension éducative)"
date: 2026-07-12
project: zcrud
phase: "Extension — famille de packages éducatifs (zcrud_study)"
assessor: "bmad-check-implementation-readiness (mode skill, exécution autonome non-interactive)"
owner: Zakarius
language: fr
verdict: READY
stepsCompleted: [document-discovery, prd-analysis, epic-coverage-validation, ux-alignment, epic-quality-review, final-assessment]
inputs:
  - _bmad-output/planning-artifacts/prds/prd-zcrud-study-2026-07-12/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md
  - _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md
  - _bmad-output/planning-artifacts/briefs/brief-zcrud-study-2026-07-12/brief.md
  - docs/study-integration-inventory.md
counters:
  fr_s_couvertes: "34/34"
  nfr_s_couvertes: "11/11"
  ad_extension_couverts: "12/12 (AD-17..AD-28)"
  ad_produit_herites: "16/16 (AD-1..AD-16, appliqués transversalement)"
  oq_s_bloquantes: 0
  epics: 11
  stories: 41
  findings_critiques: 0
  findings_majeurs: 0
  findings_mineurs: 4
---

# Rapport de préparation à l'implémentation — zcrud_study

**Date :** 2026-07-12
**Projet :** zcrud — extension éducative `zcrud_study`
**Évaluateur :** skill `bmad-check-implementation-readiness` (chargé via le tool `Skill` ; exécution autonome non-interactive — les menus interactifs du skill sont exécutés comme étapes analytiques, aucun humain présent).

---

## 0. Mode d'exécution & découverte documentaire (Step 1)

**Mode : SKILL** — `bmad-check-implementation-readiness` chargé et suivi (steps 01→06). Le skill est nativement conversationnel (halte sur menu `[C] Continue`) ; en contexte de sous-agent autonome sans utilisateur interactif, chaque étape est exécutée pour sa **valeur analytique** (extraction, traçabilité, revue de qualité) et le rapport est produit directement. Aucune étape n'a été simulée de mémoire : les trois documents cœur ont été lus **intégralement** sur disque (PRD 517 l., architecture 255 l., epics 1123 l.).

**Inventaire documentaire (aucun doublon whole/sharded détecté) :**

| Type | Fichier retenu | État |
|---|---|---|
| PRD | `prds/prd-zcrud-study-2026-07-12/prd.md` (34 FR-S, 11 NFR-S, 6 OQ-S) | ✅ unique |
| Architecture | `architecture/architecture-zcrud-study-2026-07-12/architecture.md` (AD-17..AD-28 + 16 AD hérités) | ✅ unique |
| Epics & Stories | `epics/epics-zcrud-study-2026-07-12/epics.md` (11 epics, 41 stories) | ✅ unique |
| Brief | `briefs/brief-zcrud-study-2026-07-12/brief.md` | ✅ grounding |
| Inventaire (source of truth factuelle) | `docs/study-integration-inventory.md` | ✅ grounding |
| UX (bmad-ux dédié) | — | ⚠️ absent (attendu — voir §4) |

---

## 1. Analyse du PRD (Step 2)

**Exigences fonctionnelles extraites : 34** — `FR-S1..FR-S34`, préfixe `-S-` verrouillé pour éviter la collision avec les 26 FR produit. Groupées par fonctionnalité §4.1..§4.10 : squelette kernel (FR-S1..S3), domaine canonique (FR-S4..S11), ports & data offline-first (FR-S12..S16), SRS + runtimes (FR-S17..S21), layout study-tools (FR-S22..S24), notes/markdown (FR-S25), mindmap (FR-S26), tags & annotations (FR-S27..S28), seams IA/communauté/examens (FR-S29..S32), bindings & migration (FR-S33..S34).

**Exigences non-fonctionnelles extraites : 11** — `NFR-S1..NFR-S11` (rebuilds granulaires SM-1, acyclicité repo-wide, domaine backend-agnostique, désérialisation défensive, réactivité Flutter-native, a11y/RTL, thème/l10n injectés, codegen sans réflexion, offline-first, modularité prouvée, sécurité). Chaque NFR-S est adossée à un ou plusieurs AD hérités.

**Exigences additionnelles / contraintes structurantes :** squelette étagé (AD-17), story de tête bloquante (AD-18), aucun nouveau paquet lourd (réutilisation stack produit), adapters bi-topologie (AD-20/AD-27), bindings confinés (AD-15/AD-24), résolutions de tête déférées (SM-2 chiffré, golden de décomposition), gates CI étendus.

**Questions ouvertes : 6** — `OQ-S1..OQ-S6` (dont OQ-S1/OQ-S2 explicitement tranchées dans le PRD).

**Complétude du PRD :** ÉLEVÉE. Chaque FR-S porte des « conséquences testables », une matrice FR→ES (Annexe A) croisant UJ-S et SM-S, un index d'hypothèses (§10), des non-goals explicites (§6). Vocabulaire ancré par un glossaire verbatim (§3). Continuité de numérotation non-négociable respectée.

---

## 2. Validation de couverture des épics (Step 3)

### 2.1 Traçabilité FR-S → epics/stories

| FR-S | Epic(s) | Story(ies) | Statut |
|---|---|---|---|
| FR-S1 | ES-1 | ES-1.1 | ✅ |
| FR-S2 | ES-1 | ES-1.2 | ✅ |
| FR-S3 | ES-1 | ES-1.3 | ✅ |
| FR-S4 | ES-2 | ES-2.1 | ✅ |
| FR-S5 | ES-2 | ES-2.2 | ✅ |
| FR-S6 | ES-2 | ES-2.3 | ✅ |
| FR-S7 | ES-2 | ES-2.4 | ✅ |
| FR-S8 | ES-2 | ES-2.5 | ✅ |
| FR-S9 | ES-2 | ES-2.6 | ✅ |
| FR-S10 | ES-2 | ES-2.7 | ✅ |
| FR-S11 | ES-2 | ES-2.8 | ✅ |
| FR-S12 | ES-3 | ES-3.1 | ✅ |
| FR-S13 | ES-3 | ES-3.2 | ✅ |
| FR-S14 | ES-3 | ES-3.3 | ✅ |
| FR-S15 | ES-3 | ES-3.4 | ✅ |
| FR-S16 | ES-3 | ES-3.5 | ✅ |
| FR-S17 | ES-4 | ES-4.1 | ✅ |
| FR-S18 | ES-4 | ES-4.2 | ✅ |
| FR-S19 | ES-4 | ES-4.3 | ✅ |
| FR-S20 | ES-4 | ES-4.4 | ✅ |
| FR-S21 | ES-4 | ES-4.5 | ✅ |
| FR-S22 | ES-5 | ES-5.1, ES-5.2 | ✅ |
| FR-S23 | ES-5 | ES-5.3 | ✅ |
| FR-S24 | ES-5 | ES-5.4 | ✅ |
| FR-S25 | ES-6 | ES-6.1, ES-6.2 | ✅ |
| FR-S26 | ES-7 | ES-7.1, ES-7.2 | ✅ |
| FR-S27 | ES-8 | ES-8.1 | ✅ |
| FR-S28 | ES-8 | ES-8.2 | ✅ |
| FR-S29 | ES-9 | ES-9.1 | ✅ |
| FR-S30 | ES-9 | ES-9.2 | ✅ |
| FR-S31 | ES-9 | ES-9.3 | ✅ |
| FR-S32 | ES-9 | ES-9.4 | ✅ |
| FR-S33 | ES-10 | ES-10.1, ES-10.2 | ✅ |
| FR-S34 | ES-11 | ES-11.1, ES-11.2, ES-11.3 | ✅ |

**Statistiques de couverture :** 34 FR-S PRD ; 34 couvertes ; **couverture = 100 %**. Aucun FR-S orphelin, aucune story sans FR-S de rattachement, aucune FR fantôme (présente dans les epics, absente du PRD).

### 2.2 Traçabilité NFR-S (portées transversalement en AC)

11/11 traçables : NFR-S1/SM-1 → ES-5.2 (test widget + profiling) ; NFR-S2 (acyclicité) → gate repo-wide à chaque commit d'epic + ES-1.1 ; NFR-S3 (backend-agnostique) → ES-3.1 + scan CI ES-1.4 ; NFR-S4 (désérialisation défensive) → ES-3.5 (gate corpus IFFD) + ES-1.4 ; NFR-S5 (Flutter-native) → ES-4.2/4.3 + bindings ES-10/ES-11 ; NFR-S6/NFR-S7 (a11y/thème) → ES-4.5, ES-5.2, ES-8.2 ; NFR-S8 (codegen) → ES-1.4 + ES-3.2 ; NFR-S9 (offline-first) → ES-3.3/ES-3.4 ; NFR-S10 (modularité) → ES-1.1 (test de résolution) ; NFR-S11 (sécurité) → ES-1.4 (secrets) + ES-9.4 (dette lex).

### 2.3 Traçabilité AD-17..AD-28 (12 décisions d'extension)

| AD | Règle | Appliqué dans | Statut |
|---|---|---|---|
| AD-17 | Décomposition multi-packages sur kernel study | ES-1.1 (+ NFR-S10 test résolution) | ✅ |
| AD-18 | Remontée `ZStudyFolder` option A, refactor non-régressif | ES-1.1 (tête bloquante) | ✅ |
| AD-19 | `ZSyncMeta` hors-entité universel (tranche OQ #3) | ES-1.3, ES-2.1/2.2/2.5/2.6/2.8, ES-8.2 | ✅ |
| AD-20 | Dépôt générique + helper offline-first + resolver bi-topologie | ES-3.1, ES-3.2, ES-3.4 | ✅ |
| AD-21 | Cascade déclarative bornée ≤ 450, anti two-owners | ES-3.3 | ✅ |
| AD-22 | Convergence SM-2 → `ZSm2Scheduler` source unique | ES-4.1 | ✅ |
| AD-23 | Runtimes de session purs, zéro écriture SM-2 par construction | ES-4.2/4.3/4.4 | ✅ |
| AD-24 | `ZStudySessionConfig` forme unique, égalité au binding | ES-10.1 | ✅ |
| AD-25 | Apparence IFFD sectionnée à scoping isolé + `ZFeatureAvailability` | ES-5.1/5.2/5.3/5.4 | ✅ |
| AD-26 | Communauté/partage = extension optionnelle, état personnel jamais partagé | ES-9.4 | ✅ |
| AD-27 | Migration IFFD flat→canonique, mapping de casse côté adapter | ES-3.5, ES-11.2 | ✅ |
| AD-28 | Contenus rich-text typés (tranche OQ-S5) | ES-2.2, ES-6.1/6.2, ES-7.2 | ✅ |

**12/12 AD d'extension appliqués.** Les 16 AD produit hérités (AD-1..AD-16) sont déclarés `binds` dans l'architecture d'extension et rappelés en AC par story (§« Inherited Invariants »).

---

## 3. Traçabilité inverse & qualité des stories (Step 5)

- **41 stories, 100 % avec ACs Given/When/Then testables.** Aucune story « d'un paragraphe » sans critère vérifiable. Les invariants durs sont exprimés comme ACs mesurables (acyclicité `melos analyze`+`verify` RC=0 ; non-régression E9 « nb tests ≥ avant » ; 100 % du corpus legacy désérialisé sans throw ; « seul le champ courant se reconstruit, zéro perte de focus »).
- **Métadonnées de parallélisation présentes sur chaque story** (taille S/M/L/XL, statut `backlog`, packages/fichiers touchés, verdict séquentiel/parallélisable) — condition de la règle « ≤ 3 stories à fichiers disjoints » du processus BMAD.
- **Résolutions de tête déférées portées comme stories explicites** : ES-4.1 (comparaison SM-2 chiffrée + tests de contrat + doc divergence overdue), ES-5.1 (golden de décomposabilité du layout IFFD ~1750 l.), ES-7.2 (décision rich-text du `content` de nœud → OQ-S5 documentée).
- **Gates CI outillées** : ES-1.4 (anti-`reflectable`, secrets, codegen, repo-wide), ES-3.5 (gate compat sérialisation sur corpus IFFD legacy), ES-5.2 (non-régression SM-1).

### 3.1 Cohérence du graphe de packages

Graphe d'extension **acyclique** vérifié : `zcrud_study_kernel → zcrud_core` (seul) ; `zcrud_flashcard → {core, kernel}` ; `zcrud_session → {kernel, flashcard}` ; `zcrud_study → {kernel, flashcard, mindmap, markdown, note, document, session, exam}` ; `zcrud_firestore → {kernel, core}` ; `zcrud_riverpod/zcrud_get → study`. **Point non-trivial correctement traité :** `zcrud_mindmap` ne dépend **pas** du kernel (référence les dossiers par `folderId : String` neutre) — évite le cycle ; `zcrud_firestore` dépend du kernel mais jamais l'inverse. **Ownership des entités kernel** : le kernel est l'unique source de vérité study (`ZStudyFolder`, utilitaires, ports, registre de cascade) ; écritures **sérialisées** par l'orchestrateur (seul point de contact partagé). **Anti two-owners de la cascade** (AD-21) : chaque arête déclarée par le package enfant, composition unique par `zcrud_study` — pas de propriétaire ambigu.

### 3.2 Risques de séquencement

- **Têtes bloquantes bien positionnées en premier** : ES-1.1 (bloque tout ES-1..ES-11), ES-4.1 (tête d'ES-4), ES-5.1 (tête d'ES-5). Aucune dépendance avant (forward) intra-epic détectée.
- **Fenêtres de parallélisation à fichiers disjoints** correctement identifiées (après ES-3 : ES-4 `zcrud_session` ∥ ES-5 `zcrud_study` ; vague UI : ES-6 `zcrud_note` ∥ ES-7.2 `zcrud_mindmap` ∥ ES-8.2 `zcrud_document`). **Garde-fou explicite** : ES-7.1/ES-8.1/ES-9.* écrivent tous `zcrud_study` → jamais en vol ensemble (re-séquencés).
- **Fan-in de ES-10** (dépend d'ES-4..ES-9) et chaîne finale ES-10→ES-11 : lourds mais légitimes (binding = agrégation ; migration = chantier terminal).

---

## 4. Alignement UX (Step 4)

**Aucun document `bmad-ux` dédié n'existe pour cette phase** — attendu et **non bloquant**. L'apparence de référence est l'existant IFFD (`folder_study_tools_page.dart`), factuellement décrit dans l'inventaire §5 et gouverné par AD-25. Les exigences visuelles/interaction sont portées par les FR-S UI (FR-S21..FR-S28) et les NFR d'a11y (NFR-S6/NFR-S7), couvertes par ES-4/ES-5/ES-7/ES-8. La fidélité d'apparence est validée par un **golden test** (ES-5.1) plutôt que par une spec UX amont — approche adaptée à un portage à apparence préservée.

---

## 5. État des questions ouvertes (OQ-S1..OQ-S6)

| OQ | Sujet | Tranchée par | Résiduel |
|---|---|---|---|
| OQ-S1 | Placement `ZStudyFolder` | **Verrouillée** (option A, PRD §9 + AD-18) | Aucun — story de tête ES-1.1 |
| OQ-S2 | Convention métadonnées de sync (canonique #3) | **Tranchée** (AD-19 : `ZSyncMeta` hors-entité universel) | Aucun — consignée en ES-1.3 |
| OQ-S3 | Source SM-2 unique | **Tranchée en architecture** (AD-22 : `ZSm2Scheduler` canonique) | Vérification de tête d'epic ES-4.1 (tests de contrat + doc divergence) — critère de résolution défini, non bloquant |
| OQ-S4 | Forme unique `ZStudySessionConfig` | **Tranchée** (AD-24 : une forme kernel, égalité au binding) | Aucun — appliquée en ES-10.1 |
| OQ-S5 | Rich-text du `content` de nœud mindmap | **Tranchée** (AD-28 : texte brut + slot `ZExtension`/`ZCodec` opt-in) | Documentation formelle en ES-7.2 — non bloquant |
| OQ-S6 | Portée du registre de cascade | **Tranchée** (AD-21 : registre neutre au kernel, résolution en adapter) | Aucun — appliquée en ES-3.3 |

**OQ bloquantes = 0.** Les résiduels OQ-S3/OQ-S5 sont des **critères de vérification de tête d'epic** (résolution déjà décidée en architecture), pas des décisions ouvertes.

---

## 6. Tableau des findings

| # | Sévérité | Domaine | Description | Statut / Recommandation |
|---|---|---|---|---|
| F1 | MINEUR | Cohérence graphe de séquencement | Le graphe mermaid de séquencement (epics §« Séquencement ») ne trace **que** `ES-2 → ES-8`, alors que l'en-tête d'ES-8 déclare « Dépend de : ES-2 (**et ES-3** pour la persistance des annotations) ». L'arête ES-3→ES-8 est implicite dans le diagramme. | Non bloquant. Aligner le mermaid en ajoutant `ES3 --> ES8` ; ES-8.2 (annotations) ne doit démarrer qu'après ES-3 (couche data). À corriger en tête d'ES-8. |
| F2 | MINEUR | Décision différée résiduelle | `applyOrder<T>` est marqué « candidat à remonter dans `zcrud_core` » (ES-1.2) sans décision figée. Une promotion vers `zcrud_core` en ferait une écriture du **kernel produit** (point de contention sérialisé, CLAUDE.md). | Non bloquant. Trancher en tête d'ES-1.2 (rester dans `zcrud_study_kernel` par défaut, sauf réutilisation produit avérée) et consigner ; si promu à `zcrud_core`, sérialiser l'écriture. |
| F3 | MINEUR | Faisabilité de vérification (ES-4.1) | L'AC d'ES-4.1 exige une comparaison **numérique** des trois SM-2, dont `Sm2` (lex) et `Sm` (IFFD) qui vivent dans des **apps externes non présentes dans ce monorepo** (cf. « Deferred » architecture : « non rejouable ici sans le code lex »). | Non bloquant. AD-22 a déjà élu `ZSm2Scheduler` canonique ; le critère de résolution exécutable in-repo = tests de contrat figeant `ZSm2Scheduler.apply` + divergence overdue documentée. La non-régression comportementale réelle est validée en aval à ES-10.2/ES-11.2 (données réelles). Rendre explicite dans ES-4.1 que la comparaison aux impls externes est documentaire, pas un test CI. |
| F4 | MINEUR | Explicite-ness des dépendances | L'en-tête d'ES-9 déclare « Dépend de : ES-3 » ; ES-9.2 (UI examens) consomme `ZExam`/`ZReminderTime` (ES-2.6). La dépendance est satisfaite transitivement (ES-3 dépend d'ES-2) mais non explicitée au niveau story. | Non bloquant. Cosmétique : noter la dépendance entité ES-2.6 dans ES-9.2 pour la lisibilité de séquencement. |

**Findings critiques : 0. Findings majeurs : 0. Findings mineurs : 4** (tous non bloquants, corrigeables en tête d'epic concernée sans re-planification).

---

## 7. Préparation des gates CI

| Gate | Story porteuse | Couverture |
|---|---|---|
| Lint anti-`reflectable` (étendu aux packages study) | ES-1.4 | ✅ repo-wide, sauf adaptateur autorisé |
| Scan de secrets | ES-1.4 | ✅ échec si clé/token committé |
| Contrôle codegen (`@ZcrudModel` → `.g.dart`) | ES-1.4 | ✅ codegen avant analyze/test |
| Compat de sérialisation défensive (corpus IFFD legacy) | ES-3.5 (rattachée à ES-1.4) | ✅ 100 % du corpus sans throw (SM-S6/NFR-S4) |
| Acyclicité repo-wide (`melos analyze` **ET** `verify`) | ES-1.1 + chaque gate de commit d'epic | ✅ NFR-S2 (leçon `ZExportApi` E11a-3 intégrée) |
| SM-1 / rebuilds granulaires | ES-5.2 | ✅ test widget + profiling, zéro perte de focus |

Les gates sont **outillées et rattachées** au processus de merge/commit d'epic. Aucune gate déclarée sans story porteuse.

---

## 8. Synthèse & recommandations (Step 6)

### Statut global de préparation

**READY** ✅ (0 critique, 0 majeur, 0 OQ bloquante).

### Compteurs

- **FR-S couvertes : 34/34** (100 %)
- **NFR-S traçables : 11/11**
- **AD d'extension appliqués : 12/12** (AD-17..AD-28) ; **16/16** AD produit hérités appliqués transversalement
- **OQ bloquantes : 0/6** (OQ-S1/S2/S4/S6 tranchées ; OQ-S3/S5 = critères de vérification de tête d'epic, décision architecturale déjà prise)
- **Epics : 11 · Stories : 41** (toutes `backlog`, toutes avec ACs testables)
- **Findings : 0 critique · 0 majeur · 4 mineurs** (non bloquants)

### Justification du verdict

Le backlog atteint une **traçabilité complète** FR-S → NFR-S → AD-17..AD-28 → epics/stories, un **graphe de packages acyclique** avec ownership du kernel clair et point de contact unique sérialisé, des **têtes bloquantes correctement séquencées** (ES-1.1/ES-4.1/ES-5.1), des **fenêtres de parallélisation à fichiers disjoints** explicitement gardées, des **gates CI outillées** et **0 question ouverte bloquante**. Les 4 findings sont des ajustements de cohérence documentaire et de décisions de tête d'epic, corrigeables au fil de l'eau sans re-planification. Ce niveau de préparation dépasse le précédent produit (« NEEDS WORK », qui portait des OQ ouvertes) : ici les OQ sont tranchées et la couverture est intégrale.

### Actions recommandées (non bloquantes, au fil de l'eau)

1. **F1** — Aligner le graphe mermaid de séquencement : ajouter l'arête `ES3 → ES8` (persistance des annotations). À traiter en tête d'ES-8.
2. **F2** — Figer la décision `applyOrder<T>` (rester `zcrud_study_kernel` par défaut). À traiter en tête d'ES-1.2.
3. **F3** — Préciser dans l'AC d'ES-4.1 que la comparaison aux impls SM-2 externes (lex/IFFD) est **documentaire** ; le gate CI exécutable = tests de contrat `ZSm2Scheduler` in-repo + validation comportementale en aval (ES-10.2/ES-11.2).
4. **F4** — Expliciter la dépendance entité ES-2.6 dans ES-9.2 (lisibilité).

### Enchaînement recommandé

**Procéder à `bmad-sprint-planning`** pour générer le `sprint-status.yaml` à partir des 11 epics / 41 stories, puis démarrer le cycle strict `bmad-create-story` → `bmad-dev-story` → `bmad-code-review` en commençant par la **tête bloquante ES-1.1**. Les 4 findings mineurs sont traités en tête de leur epic respective, sans prérequis au lancement du sprint.

### Note finale

Cette évaluation a identifié **4 findings mineurs** répartis sur 2 catégories (cohérence documentaire, décisions de tête d'epic), **aucun critique ni majeur**. Les artefacts sont prêts pour l'implémentation ; les findings peuvent être absorbés en tête d'epic ou corrigés dès maintenant, au choix de Zakarius.

---
*Rapport généré par le skill `bmad-check-implementation-readiness` (exécution autonome non-interactive), 2026-07-12.*
