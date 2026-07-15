# Rétrospective — Epic ES-4 : SRS convergé + runtimes de session

Facilitation : bmad-retrospective (effort medium), READ-ONLY. Synthèse dérivée des story-files et code-reviews ES-4.0..ES-4.5 réellement lus sur disque, du sprint-status, et des rétros ES-3/ES-5 pour la continuité des règles Rn.

Périmètre : 6 stories, TOUTES `done`. Packages : `zcrud_flashcard` (SM-2), `zcrud_session` (NEUF — runtimes + widgets), `scripts/ci` (plancher gate). Parallélisé avec ES-5 (`zcrud_study`) sur toute la durée, packages disjoints.

---

## 1. Résultats livrés (vérifiés sur les story-files + code-reviews)

| Story | Livrable | Verdict CR | Findings | Dette |
|-------|----------|-----------|----------|-------|
| **ES-4.0** | Plancher constant `{firestore, generator, study_kernel}` non-optable dans `verify_serialization.dart` (sortie de population ⇒ RC=1 inconditionnel) ; `prove_gates` 41→43. | APPROVED | 0 H/MAJ/MED · 2 LOW justifiés | **DW-ES35-1 SOLDÉE** (R16) |
| **ES-4.1** | Verrou de contrat SM-2 (`ZSm2Scheduler` + tests golden numériques, 22 vecteurs gelés). ZÉRO changement de comportement (prod inchangé) ; formule déjà canonique = parité lex ; prémisse épic corrigée (dodlp = 0 module SRS) ; AD-22 documenté. | APPROUVÉ | 0 H/MAJ/MED · 1 LOW (nit doc) | — |
| **ES-4.2** | Package `zcrud_session` NEUF · `ZStudySessionEngine` (cycle SRS, offsets +2/+4, zéro-apply PAR CONSTRUCTION via seam injecté). | APPROVED | 0 H/MAJ/MED · 3 LOW | — |
| **ES-4.3** | `ZLinearSessionState` (modes list/cramming, zéro-SM2 PAR CONSTRUCTION = garantie de TYPE, aucun champ reviewer). | APPROUVÉ | 0 H/MAJ/MED · 1 LOW | — |
| **ES-4.4** | `ZWhiteExamSessionEngine` (machine à états `StateError`, scoring golden composant `ZStudySessionResult`, zéro-SM2 par type + scan de source). | APPROUVÉ | 0 H/MAJ/MED · 1 LOW | — |
| **ES-4.5** | 3 widgets présentation `ZSrsQualityButtons` / `QualityBreakdown` / `ProgressRings` (mapping qualité dans le widget, DTO rings pur). | APPROUVÉ avec réserves | **1 MEDIUM (R6 silent-drop) + 1 LOW (garde figée)** — **REMÉDIÉS + verrouillés** | — |

Bilan : 6/6 vertes. Zéro finding HIGH/MAJEUR sur toute l'épopée. Un seul MEDIUM (ES-4.5), corrigé dans le périmètre de la story avant `done` (scan presentation rendu récursif). Toutes les gardes-cœur prouvées LOAD-BEARING par injections rejouées réellement (R3 orchestrateur).

---

## 2. Ce qui a marché

- **AD-23 « zéro écriture SM-2 PAR CONSTRUCTION » décliné 3 fois, chaque fois plus fort.** ES-4.2 injecte un seam (l'apply n'est pas atteignable sans le fournir) ; ES-4.3 et ES-4.4 vont plus loin — **absence totale de champ/paramètre reviewer ⇒ garantie de TYPE** (le code qui écrirait SM-2 ne compile pas), doublée d'un scan de source. Le patron « invariant garanti par la forme du code, pas par une garde runtime » s'est révélé nettement plus robuste qu'un `if` défensif. Patron à généraliser (→ R20).
- **Contrat SM-2 comme golden numérique à littéraux figés, jamais dérivé de l'algo.** ES-4.1 gèle 22 vecteurs en dur : le test ne peut pas « bouger avec » un changement de formule. Deux injections rejouées sur le code de prod (rouge → restauré) ont prouvé le pouvoir discriminant. Verrou exécutable exemplaire.
- **Prémisse d'épic corrigée à froid.** ES-4.1 a établi que la formule zcrud était déjà canonique (parité lex) et que dodlp n'a aucun module SRS — la « convergence » attendue était en réalité un verrou de non-régression. Corriger la prémisse plutôt que fabriquer un faux travail de convergence a évité une modification gratuite d'un algorithme correct. AD-22 documenté au passage.
- **Parallélisation ES-4 ∥ ES-5 propre.** Packages strictement disjoints (`zcrud_session` vs `zcrud_study`), seul point de contact possible `zcrud_core` non touché. La seule vraie contrainte — bootstrap du package NEUF `zcrud_session` — a été gérée par sérialisation ponctuelle du dev (R17, cristallisé côté ES-5). Aucun faux-vert cross-package.
- **DW-ES35-1 soldée en TÊTE d'ES-4 (ES-4.0).** Le faux-vert résiduel du gate à population self-déclarée, cristallisé en R16 lors de la rétro ES-3, a été fermé immédiatement par un plancher constant non-optable, avec preuve NON-POWERLESS committée (`prove_gates` rougit quand la garde saute). La dette de tête n'a pas traîné.
- **Résilience opérationnelle.** 3 incidents d'agents morts (Connection closed / poll figé) sur la session, TOUS gérés sans confiance aveugle : working-tree vérifié sur disque, story-status/tests re-constatés, relance d'agent de reprise. Aucun enchaînement sur la foi du rapport d'un agent mort.

---

## 3. Ce qui est à améliorer / incidents

- **Le motif dominant reste vivant : la dégradation silencieuse (R6).** ES-4.5 MEDIUM en est l'incarnation exacte : dans le breakdown de qualité, le critère d'**appartenance** à l'échelle était LAXISTE (`int.tryParse("03") → 3 ∈ scale`) alors que le critère de **rendu** était STRICT (`containsKey('3')` sur le segment canonique). Une clé `"03"` passait le filtre d'appartenance, ne matchait aucun segment au rendu, et ses réponses étaient purement supprimées — sans signalement. Détecté au code-review, remédié (les deux faces partagent désormais le MÊME critère canonique), mais le motif se re-présente épic après épic. → **R22**.
- **Les gardes à population énumérée (liste figée) se re-rencontrent.** ES-4.5 LOW : la compensation du scan de pureté sur `presentation/` énumérait 3 fichiers en dur — un 4ᵉ widget important `provider`/`get` passait entre les mailles des deux gardes. C'est exactement la classe R10/R16 (population self-déclarée). Rendu récursif (dérivé du disque) au code-review. → **R21** (généralisation explicite de R10/R16 au-delà des gates de sérialisation, appliquée cette fois à un scan de pureté).
- **Le scope-out du scan de pureté sur `presentation/` était un choix assumé, pas un faux-vert.** Le reviewer a vérifié RÉELLEMENT (par injection) que les 3 fichiers étaient gardés et que le dragnet domaine restait intact — compensation constatée, pas déclarée. Bon réflexe ; la leçon est de rendre la compensation durable (récursive) dès sa conception, pas au code-review.
- **Petits LOW « invariant tenu par construction, non testé indépendamment ».** ES-4.2 LOW-2 (« zéro apply parasite » repose sur la construction, pas un test), ES-4.3/4.4 LOW (bornes de curseur `over-answer`/`advance()` non mode-conscient). Non bloquants, non atteignables par les chemins/ACs actuels. À arbitrer par les bindings consommateurs (ES-9/ES-10). Cohérent avec R20 : quand l'invariant est garanti par le type, un test discriminant devient difficile — le durcissement se fait par `assert` de contrat, pas par test de valeur.

---

## 4. Nouvelles règles (suite R1..R19)

### R20 — « Zéro écriture X PAR CONSTRUCTION » : préférer l'absence de champ/seam (garantie de type + scan de source) à une garde runtime
Quand un runtime doit garantir qu'il n'exécute JAMAIS une opération X (écriture SM-2, mutation d'un store, side-effect interdit), le moyen le plus fort n'est pas un `if`/garde runtime — c'est de rendre X **inatteignable par la forme du code** : (a) aucun champ/paramètre/dépendance permettant X (le code qui l'appellerait ne compile pas — garantie de TYPE), ou à défaut (b) un seam injecté dont l'absence rend X inatteignable. Doubler d'un **scan de source** qui échoue si un symbole interdit réapparaît (le scan MORD, prouvé par injection). *(ES-4.2 seam ; ES-4.3/4.4 absence de champ reviewer = type + scan.)* Corollaire : un invariant garanti par le type ne se teste pas par une valeur — on le durcit par un `assert` de contrat sur les chemins voisins (cf. LOW `advance()`/`over-answer`).

### R21 — Une garde/scan à population énumérée doit être RÉCURSIVE, dérivée du disque — jamais une liste figée (généralise R10 et R16)
Toute garde qui surveille un **ensemble** (fichiers, canaux, entités, exports, membres d'un dossier) DÉRIVE cet ensemble du disque (`listSync(recursive:true)` / AST), symétriquement au dragnet qu'elle compense ; un nouveau membre est couvert AUTOMATIQUEMENT, un membre sans observateur est ROUGE par couverture. Une liste figée (allowlist énumérée) rejoue le faux-vert structurel : elle ne couvre que les cas pensés par son auteur et devient powerless silencieusement à la prochaine addition. R10 l'a posé pour les gates AST, R16 pour les gates à population self-déclarée ; **R21 l'étend à TOUT scan de compensation** (ES-4.5 : scan de pureté `presentation/` figé à 3 fichiers → rendu récursif).

### R22 — Une dégradation silencieuse naît d'un critère d'appartenance LAXISTE face à un critère de rendu STRICT : les deux faces partagent le MÊME critère canonique
Quand un code partitionne des données en « connu / inconnu » (pour rendre les uns et signaler les autres), le critère qui décide l'**appartenance** (parse tolérant, coercition) et le critère qui décide le **rendu/matching** (clé canonique exacte) DOIVENT être le même prédicat canonique. Sinon une valeur peut être jugée « connue » (donc ni rendue à part, ni signalée) tout en ne matchant aucun segment au rendu ⇒ elle est **silencieusement supprimée** — pire que la fusion silencieuse que R6/D3 interdisent. Test discriminant obligatoire sur le chemin « in-scale-non-canonique » (ES-4.5 : `"03"` vs `"9"`). Un parse tolérant côté appartenance sans normalisation canonique préalable est un smell R6.

---

## 5. État des dettes après ES-4

| Dette | État | Suite |
|-------|------|-------|
| **DW-ES35-1** (faux-vert gate sérialisation, R16) | ✅ **SOLDÉE** par ES-4.0 (plancher constant non-optable + preuve non-powerless) | Close |
| **DW-E54-1** (bug pré-existant E5-4 : `failures` incomplet sur throw dans l'orchestrateur de sync) | ⚠️ **TOUJOURS OUVERTE** — hors périmètre additif d'ES-3/ES-4 ; invariant best-effort tenu, seul le rapport de failures est incomplet | Story future touchant l'orchestrateur E5 (candidat ES-6+ / binding) |
| MEDIUM R6 silent-drop ES-4.5 | ✅ Remédié + verrouillé (scan presentation récursif, critère canonique partagé) dans le commit d'epic ES-4 | Close |
| LOW gardes figées ES-4.5 | ✅ Rendues récursives (R21) | Close |
| LOW consignés (ES-4.2 `cursor` mort ; ES-4.3 `advance()` non mode-conscient ; ES-4.4 `over-answer`) | 🟡 Consignés, non bloquants, non atteignables par ACs | Arbitrage bindings ES-9/ES-10 (durcir par `assert` de contrat, R20) |

**Rien de bloquant.** Aucune découverte ES-4 ne remet en cause le plan aval. La seule dette de fond restante (DW-E54-1) est pré-existante et hors périmètre de l'épopée « étude ».

---

## 6. Recommandations de séquencement

- **ES-4 + ES-5 forment la base « étude » consommable.** ES-4 livre le noyau SRS convergé (contrat verrouillé) + 3 runtimes de session (cycle SRS, list/cramming, examen blanc) + widgets de qualité/progression ; ES-5 livre le layout « study tools » apparence IFFD. Ensemble : le socle domaine + présentation du module étude est désormais disponible en dépendance git.
- **Prochaine vague (respecter le graphe, pas la numérotation)** :
  - **ES-6** (Notes & markdown, réutilisation `zcrud_markdown`) — dépend d'ES-2 + ES-5 : dépendances satisfaites, candidat immédiat.
  - **ES-7** (intégration mindmap) — dépend d'ES-5 (satisfait) ; écrit `zcrud_study`, donc NON parallélisable avec d'autres stories touchant `zcrud_study`.
  - **E7 (intégration DODLP)** reste **bloqué par E11a** (parité DODLP) — ne pas engager avant.
  - **ES-9 (flashcards runtime/binding)** consommera les runtimes ES-4 ; c'est là que les LOW `over-answer`/`advance()`/`cursor` doivent être tranchés (durcissement `assert` R20).
  - **ES-10 (binding Riverpod)** est un fan-in (dépend d'ES-4/5/6/7/8/9) — dernier.
- **Continuité process à porter** : maintenir R3 orchestrateur (preuve load-bearing par injection réelle, jamais sur la foi du rapport d'agent), le gate REPO-WIDE `melos analyze` + `melos verify` à chaque commit d'epic (une vérif ciblée par package NE détecte PAS une régression cross-package), et la sérialisation du dev au bootstrap d'un package neuf (R17) si une prochaine vague crée encore un package.

---

## 7. Verdict

Epic ES-4 : **COMPLET et SOLIDE.** 6/6 stories vertes, zéro finding HIGH/MAJEUR, un seul MEDIUM (corrigé avant `done`). Le contrat SM-2 est un verrou exécutable prouvé, la garantie « zéro-SM2 » est montée en robustesse de la garde runtime vers la garantie de type (patron R20), et la dette de tête DW-ES35-1 est soldée. Trois faces récurrentes du même défaut structurel (population figée, dégradation silencieuse, invariant non testé) cristallisées en R20/R21/R22. Aucune découverte ne remet en cause le plan aval. Base « étude » (ES-4 + ES-5) prête à être consommée par ES-6/ES-9.

## Transition sprint-status (déléguée à l'orchestrateur — NON effectuée par cette rétro READ-ONLY)
`epic-es-4-retrospective : optional → done` (édition ciblée par l'orchestrateur). Cette rétro n'écrit AUCUN autre fichier que le présent document.
