---
title: "Réconciliation PRD ↔ brief — E-STUDY-UI / E-MULTI-EDIT"
status: final
created: 2026-07-16
sources:
  prd: prds/prd-zcrud-study-ui-2026-07-16/prd.md
  brief: briefs/brief-zcrud-study-ui-2026-07-16/brief.md
  addendum: briefs/brief-zcrud-study-ui-2026-07-16/addendum.md
  memlog_brief: briefs/brief-zcrud-study-ui-2026-07-16/.memlog.md
  memlog_prd: prds/prd-zcrud-study-ui-2026-07-16/.memlog.md
---

# Réconciliation PRD ↔ brief (E-STUDY-UI + E-MULTI-EDIT)

Méthode : les 16 entrants du brief + les 8 pièces IFFD de l'addendum (§A) + les décisions du
`.memlog` du brief sont tracés un à un vers les FR-SU1..20 / NFR-SU1..10 du PRD. Les dépassements
du PRD sont contrôlés contre le `.memlog` du PRD (décisions d'élicitation postérieures = légitimes).

## 1. Matrice de traçabilité brief → PRD

| Entrant brief | FR/NFR PRD | Statut |
|---|---|---|
| 1. `ZFlashcardReviewCard` (types, `ZRevealTransition`, flip maison, Reduce Motion) | FR-SU1, NFR-SU3 | ✅ Couvert (+ rendu riche injectable, au-delà) |
| 2. Saisie interactive notée (QCM/VF/ouverte, éval locale + port, repli neutre 3, « Je ne sais pas », minuteur, indices) | FR-SU2, FR-SU3, FR-SU4 | ✅ Couvert (+ plafond d'indices configurable, `ZTimerDisplay` — memlog PRD) |
| — auto-passage ~200 ms (addendum A.1) | FR-SU5 | ✅ Reformulé en `ZCardAdvanceBehavior` défaut par mode (décision memlog PRD — pas une contradiction) |
| 3. `ZSessionCardSwiper` (^7.2.0, notation aux boutons, indicateurs, émojis drag) | FR-SU6 | ✅ Couvert |
| 4. Modes de session (6, dont cramming inclus, aucun nouveau moteur) | FR-SU7, OA-4 | ✅ Couvert |
| 5. `ZSessionSummaryView` (trophée, stats, breakdown+rings, confetti 1×, boutons) | FR-SU8 | ⚠️ Couvert, détails visuels IFFD perdus (voir §3.1) |
| 6. Feedback pédagogique (banques FR/EN l10n, slot) | FR-SU9, NFR-SU4 | ⚠️ Couvert, seuil « exceptionnel » perdu (voir §3.2) |
| 7. `ZSessionModeSelector` (Apprendre +N / À réviser / Test, O(1), badge streak) | FR-SU10 | ✅ Couvert (lot « 30 max » → « configurable, défaut 30 » : au-delà, cohérent) |
| 8. Streak quotidien canonique (kernel, calcul pur, badge flamme) | FR-SU11 | ⚠️ Couvert, snackbar de confirmation perdue (voir §3.3) |
| 9. Filtres test/examen (fonction pure, mélange QCM, dialog) | FR-SU12 | ✅ Couvert |
| 10. `ZListSessionView` (examen blanc, absence confirmée) | FR-SU13 | ✅ Couvert |
| 11. `ZFlashcardListView` + filtres | FR-SU14 | ✅ Couvert (+ recherche élargie/configurable, tri ordre manuel — memlog PRD, OA-3) |
| 12. Multi-édition 2 étages (moteur + `ZMultiFlashcardEditor`), epic dédié | FR-SU19, FR-SU20, Vision §1 | ✅ Couvert (+ édition de champ commun via `ZFieldSpec` — memlog PRD) |
| 13. Flux UI génération IA (sheet + confirmation tags) | FR-SU15 | ✅ Couvert (+ « jamais sauvegardé silencieusement », au-delà) |
| 14. `ZFlashcardPdfTemplate` (typé question/réponse/choix/**explication**) | FR-SU16, OA-1 | ⚠️ Couvert, champ « explication » non cité (voir §3.4) (+ LaTeX v1 — memlog PRD) |
| 15. Édition riche de nœud (slot injectable, impl zcrud_markdown, repli texte brut) | FR-SU17, OA-2 | ✅ Couvert (+ label riche — memlog PRD) |
| 16. `ZMindmapGenerationPort` | FR-SU18, OA-5 | ✅ Couvert |
| Hors-périmètre explicite (impls IA, flowchart, extras visuels nœud, export serveur, migration) | partiel (Vision, FR-SU16) | ❌ Pas de section « hors périmètre » (voir §2.1) |
| Découpage 2 epics, E-MULTI-EDIT seul à écrire core/list | Vision §1 | ✅ Couvert |
| Critères de succès 1-4 | §4 | ✅ Couvert (+ contre-métriques, au-delà) |
| Risques (table brief) | NFR + §5 (OA-1..5) | ⚠️ Absorbés partiellement (voir §2.2, §3.5) |
| Conventions AD (pur-Flutter, thème/l10n, enums > booléens, ports IA) | Vision, NFR-SU1..7 | ✅ Couvert |
| Deps confinées zcrud_session, versions lex | FR-SU6, FR-SU8, NFR-SU7 | ✅ Couvert (« opt-in » du confetti non explicite — mineur) |
| Sources lecture seule (addendum §B) | OA-5 (« lecture seule ») | ✅ Couvert pour les ports ; règle générale implicite |
| Bi-consommateur IFFD+lex, généricité au juste besoin | contre-métriques §4 | ⚠️ Implicite seulement (voir §3.6) |
| Hors-ligne (implicite brief : offline-first écosystème) | NFR-SU8 | ✅ Au-delà du brief, cohérent |

## 2. Absences ou affaiblissements structurels

### 2.1 (MOYEN) Le « Hors périmètre (explicite) » du brief n'a pas de section homologue dans le PRD
Le brief ferme explicitement quatre portes : impls IA concrètes, mode flowchart formes libres +
extras visuels de nœud IFFD (couleur/taille → `extension`/`extra` AD-4), voie d'export PDF serveur,
migration app-side. Le PRD n'en reprend que des fragments dispersés (ports IA dans la Vision, voie
serveur dans FR-SU16). **Le mode flowchart, les extras visuels de nœud et l'exclusion de la
migration app-side ne sont nulle part dans le PRD.** Risque : dérive de périmètre à l'étape epics
(ex. une story « couleur de nœud » paraîtrait légitime au vu du seul PRD).
→ Recommandation : ajouter une courte section « Hors périmètre » au PRD (4 puces du brief).

### 2.2 (FAIBLE) La table des risques du brief n'est que partiellement absorbée
Cramming sans référence prod → OA-4 ✅ ; contrats de ports figés trop tard → OA-5 ✅ ; perf →
NFR-SU9 ✅ ; deps → NFR-SU7 ✅. Restent sans trace : le risque **volume/enlisement** (mitigation :
périmètre v1 fermé — lié au §2.1) et le risque **« fusion visuelle ni l'un ni l'autre »** (voir
§3.6). Acceptable pour un PRD (les risques ne sont pas des FR), mais la mitigation du second
mérite d'être portée comme intention.

## 3. Idées qualitatives perdues ou affaiblies (détail)

### 3.1 (FAIBLE) Célébration — identité visuelle IFFD amincie
Addendum A.5 : « trophée animé (**scale élastique + glow**), **titre dégradé**, stats, confettis,
**cercles de fond animés** ». FR-SU8 ne garde que « trophée animé » + stats + confetti. Le glow,
le titre dégradé et les cercles de fond animés — la « texture » gamifiée d'IFFD — ont disparu.
Conséquence possible : une célébration techniquement conforme mais fade, alors que la cible de
parité est « tout le meilleur d'IFFD ». (Corollaire : le comportement Reduce Motion des cercles
de fond animés n'est défini nulle part — NFR-SU3 le couvrirait par généralité.)

### 3.2 (FAIBLE) Feedback pédagogique — seuil « exceptionnel » perdu
Addendum A.3 : « modulées par temps de réponse (**<10 s sans indice = “exceptionnel”**) ».
FR-SU9 garde la modulation par qualité/temps/indices mais pas ce palier concret, qui est le seul
exemple chiffré du comportement attendu. À réintroduire au moins comme exemple normatif dans la
story.

### 3.3 (FAIBLE) Streak — snackbar de confirmation perdue
Addendum A.7 : badge flamme **+ snackbar de confirmation** après mise à jour du streak. FR-SU11
ne retient que le badge. Micro-feedback de gamification IFFD silencieusement éliminé.

### 3.4 (FAIBLE) Gabarit PDF — champ « explication » non cité
Brief entrant 14 : gabarit « typé question/réponse/choix/**explication** ». FR-SU16 énumère titre,
numérotation, badges, ✓/✗, « réponses distinguées » — l'explication n'apparaît pas. Probablement
implicite dans « mise en page typée », mais une ligne de matrice de parité pourrait passer entre
les mailles.

### 3.5 (FAIBLE) Confetti « opt-in » non explicite
Addendum C : confetti « **opt-in**, 1 tir, jamais si Reduce Motion ». FR-SU8 garde 1 tir + Reduce
Motion mais pas le caractère opt-in (l'app peut le désactiver indépendamment de Reduce Motion).

### 3.6 (FAIBLE) Deux intentions de calibrage devenues implicites
- **« Chaque app garde son identité visuelle »** (risque brief + addendum D — rationale même de
  `ZRevealTransition` et du thème injecté). Le PRD livre les mécanismes (enum FR-SU1, NFR-SU5)
  mais pas l'intention ; un implémenteur pourrait choisir un défaut visuel unique « zcrud » au
  lieu de préserver flip-lex / fade-IFFD (ou l'inverse) à la migration.
- **« API calibrée bi-consommateur, généricité au juste besoin, pas de sur-ingénierie
  multi-futur »** (brief, Qui est servi — sauf multi-édition, transverse). Les contre-métriques §4
  (pas d'explosion d'API) en portent l'esprit, mais le principe de calibrage IFFD+lex uniquement
  (DODLP/DLCFTI sans étude) n'est pas énoncé.

## 4. Contradictions PRD ↔ brief

**Aucune contradiction détectée.** Points vérifiés comme dépassements légitimes (tous tracés dans
`.memlog.md` du PRD, décisions d'élicitation postérieures) :
- LaTeX dans le PDF dès la v1 (contre reco « markdown simple ») → memlog PRD + OA-1.
- Label riche du nœud mindmap (au-delà du contenu seul) → memlog PRD + OA-2.
- Édition de champ commun générée depuis `ZFieldSpec` (au-delà de « suppression, déplacement,
  tags… ») → memlog PRD.
- `ZTimerDisplay {hidden, elapsed, countdown}` et `ZCardAdvanceBehavior {auto, manual}` défaut
  par mode (reformule l'auto-passage ~200 ms d'IFFD sans le contredire : conservé en test/examen).
- Recherche élargie (question+réponse/choix+tags, champs configurables) et tri « ordre manuel
  persisté » → memlog PRD + OA-3.
- Panneau « appliquer à la sélection » (tags, dossier, type) dans FR-SU20 → memlog PRD.
- « Lot 30 max » IFFD → « taille de lot configurable, défaut 30 » (généralisation compatible).
- NFR-SU8 hors-ligne et contre-métriques §4 : additions cohérentes avec l'écosystème.

## 5. Verdict

**PRD fidèle au brief sur le fond : 16/16 entrants tracés, 0 contradiction.** Écarts à corriger
avant/pendant epics, par priorité :
1. (MOYEN) Réintroduire la section **« Hors périmètre »** (flowchart, extras visuels de nœud,
   impls IA, export serveur, migration app-side) — §2.1.
2. (FAIBLE) Rehausser les détails de gamification IFFD perdus : glow/titre dégradé/cercles animés
   (FR-SU8), seuil « exceptionnel » (FR-SU9), snackbar streak (FR-SU11), confetti opt-in — §3.1-3.5.
3. (FAIBLE) Citer « explication » dans FR-SU16 — §3.4.
4. (FAIBLE) Énoncer les deux intentions de calibrage (identité visuelle par app ; API
   bi-consommateur) en une phrase chacune dans la Vision — §3.6.
