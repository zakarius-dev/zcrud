---
title: "Implementation Readiness Report — zcrud « Formulaire : parité DODLP totale »"
iteration: form-parity-2026-07-18
date: 2026-07-18
assessor: bmad-check-implementation-readiness (mode non-interactif)
verdict: READY (avec corrections mineures recommandées)
stepsCompleted: [step-01, step-02, step-03, step-04, step-05, step-06]
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-zcrud-form-parity-2026-07-18/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md
  - _bmad-output/planning-artifacts/briefs/brief-zcrud-form-parity-2026-07-18/brief.md
  - docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md
---

# Implementation Readiness Assessment Report

**Date :** 2026-07-18
**Projet :** zcrud — itération « Formulaire : parité DODLP totale »
**Mode :** non-interactif (défauts conservateurs consignés)

## Step 1 — Document Discovery (inventaire)

| Type | Fichier (whole) | Statut |
|---|---|---|
| PRD | `prds/prd-zcrud-form-parity-2026-07-18/prd.md` (682 l.) | ✅ trouvé, unique (pas de version shardée) |
| Architecture (spine) | `architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md` (325 l.) | ✅ trouvé, unique |
| Epics & Stories | `epics/epics-zcrud-form-parity-2026-07-18/epics.md` (1096 l.) | ✅ trouvé, unique |
| UX | — | ⚠️ absent (aucun `*ux*.md` pour cette itération — cf. Step 4) |
| Brief | `briefs/brief-zcrud-form-parity-2026-07-18/brief.md` | ✅ trouvé |
| Matrice de reconnaissance | `docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md` | ✅ trouvé (base des FR) |

**Doublons :** aucun (pas de coexistence whole + shardé). **Rapport cible :** le fichier existant à ce chemin est écrit ici pour la première fois (pas d'écrasement).

## Step 2 — PRD Analysis

- **Functional Requirements : 40** — FR-1..FR-40 (comptage réel sur disque, distincts). Aucune lacune de numérotation.
- **Non-Functional Requirements : 9** — NFR-1..NFR-9 (rebuild granulaire/SM-1, CORE OUT=0, RTL/a11y, thème/l10n injectés, désérialisation défensive, codegen/rétro-compat, non-régression visuelle, ETL app-side, poids des deps).
- **Contraintes verrouillées (non re-litigables) :** fork `awesome_select` maintenu par nous ; parité DODLP TOTALE (WYSIWYG HTML inclus) ; séquencement `zcrud_core` sérialisé.
- **Open Questions : 7** (OQ-1..OQ-7) avec défauts conservateurs retenus.
- **Assumptions indexées** en §9, chacune reliée à une OQ.

**Complétude PRD :** élevée. Chaque FR porte une consequence testable, une référence matrice, un marquage de phase (MVP / Média-rich / Finitions), et une ligne de traçabilité §4.14. Les invariants d'architecture sont factorisés en NFR transverses, pas répétés par FR.

## Step 3 — Epic Coverage Validation

### Comptes réels confirmés sur disque (grep)

| Élément | Annoncé | Réel sur disque | Écart |
|---|---|---|---|
| Epics (`## Epic N:`) | 10 | **10** | ✅ aucun |
| Stories (`### Story N.N:`) | **41** (Overview l.19 + l.34) | **37** | ⚠️ **−4 (documentation)** |
| FR distincts référencés | 40 | **40** (FR-1..FR-40) | ✅ aucun |
| NFR référencés | 9 | 9 | ✅ aucun |
| AD-47..56 dans le spine | 10 | 10 | ✅ aucun |

Décompte réel des stories : E1=5, E2=4, E3=3, E4=2, E5=4, E6=5, E7=3, E8=1, E9=8, E10=2 → **37**.

### Coverage matrix FR → Epic.Story (40/40)

Les deux cartes du document (FR Coverage Map §compact + Traçabilité complète §fin) concordent entre elles et couvrent l'intégralité :

FR-1→2.1 · FR-2→2.1 · FR-3→2.1 · FR-4→2.1 · FR-5→**1.1** · FR-6→5.1 · FR-7→5.2 · FR-8→5.2 · FR-9→5.3 · FR-10→2.2 · FR-11→2.2 · FR-12→2.2 · FR-13→**9.6** · FR-14→2.2 · FR-15→6.1 · FR-16→6.2 · FR-17→6.3 · FR-18→6.4 · FR-19→2.4 · FR-20→**8.1** · FR-21→3.1 · FR-22→7.1 · FR-23→7.2 · FR-24→3.2 · FR-25→3.2 · FR-26→3.2 · FR-27→3.3 · FR-28→9.7 · FR-29→2.3 · FR-30→2.3 · FR-31→2.3 · FR-32→2.3 · FR-33→2.4 · FR-34→9.2(+9.1) · FR-35→9.3(+9.1) · FR-36→9.4(+9.1) · FR-37→9.5 · FR-38→**1.2** · FR-39→4.2·5.4·6.5·7.3·**10.2** · FR-40→4.1·5.4·6.5·7.3·8.1·9.8·**10.1**.

### Statistiques de couverture

- Total FR PRD : **40**
- FR couverts dans les epics : **40**
- **Couverture : 100 % — aucun FR orphelin.**
- Seul non-goal assumé (hors périmètre par conception) : LaTeX fallback SVG `flutter_tex` (Matrice #33) → placeholder thémé, cohérent avec le test d'isolation. Documenté PRD §5 + spine « Deferred ».

## Step 4 — UX Alignment

- **Document UX dédié :** absent (aucun `DESIGN.md`/`EXPERIENCE.md` bmad-ux). L'epics.md le constate explicitement (§UX Design Requirements).
- **UX implicite ?** Oui (application front, formulaires). **Verdict : pas de gap bloquant** — les exigences visuelles/UX sont portées par le PRD (FR-38 aération + 3 écarts tranchés ; états transverses read-only/désactivé/erreur/RTL/thème du showcase FR-40) et par les invariants a11y/RTL (NFR-3 : `Semantics`, ≥ 48 dp, variantes directionnelles, `ListView.builder`, Reduce Motion). La nature de l'itération est présentationnelle/d'assemblage sur des widgets déjà natifs et prouvés en conformité.
- **Alignement UX ↔ Architecture :** cohérent. AD-54 (tokens d'aération, couleurs dérivées du `ColorScheme`), AD-13 hérité, FR-26 injecté couvrent les besoins de rendu ; la preuve visuelle est instrumentée par le harnais (AD-56).

## Step 5 — Epic Quality Review

### Valeur utilisateur & indépendance des epics

- Epic 1 « Fondations transverses » est un epic de **substrat** (cœur + squelettes + vendoring). Il porte une étiquette de risque « technique » classique. **Atténué et acceptable** : il livre deux capacités utilisateur réelles (FR-5 `dateRange`, FR-38 aération) en plus du seam/vendoring ; le projet est brownfield-monorepo où la pose du substrat de composition est un préalable structurel légitime (analogue à AD-55 point de composition). Pas un « Setup Database » vide.
- Epics 2..10 sont **centrés capacité/utilisateur** (familles de champ, sélections, média, rich-text, finitions, preuve). Chaque epic déclare ses FR et son package cible.
- **Indépendance / graphe :** graphe explicite fourni (mermaid). E1→E2, E1→E3, {E2,E3}→E4, E1→{E5,E6,E7}, E4→{E5,E6,E7}, E5→E8, E1→E9, {E5,E6,E7,E8,E9}→E10. **Aucune dépendance avant (forward) détectée** ; aucune boucle. Ordre de numérotation compatible avec le graphe.

### Sizing & dépendances des stories

- Toutes les stories portent des ACs en **Given/When/Then testables** (37/37). SM-1 instrumenté (Stories 4.1, 10.2), non-régression visuelle instrumentée (4.2, 10.2).
- **Séquencement `zcrud_core` (verrouillé) correctement matérialisé :** 6 stories marquées **CORE-SÉRIALISÉE** (1.1, 1.2, 1.3, 8.1, 9.1, 9.6) — une seule écrit le cœur à la fois. Epic 2 est signalé comme touchant la *présentation* du cœur (polish, sans ajout structurel), à séquencer hors des écritures cœur. Conforme à la règle de parallélisation `CLAUDE.md`.
- **Satellites disjoints parallélisables (≤ 3 en vol)** correctement identifiés : `zcrud_select` (E5), `zcrud_media` (E6), `zcrud_html` (E7) ; puis `zcrud_field_extras` (9.2-9.5) et `zcrud_geo` (9.7). Fichiers disjoints — parallélisation sûre.
- **Timing de création des types :** additif et au plus juste — `dateRange` (1.1) avant sa showcase ; enum finitions (9.1) avant 9.2-9.4 ; pas de création en bloc anticipée.

### Couverture AD (spine AD-47..56 + invariants hérités critiques)

| AD | Intitulé | Honorée par | Statut |
|---|---|---|---|
| AD-47 | `dateRange` natif au cœur | Story 1.1 (ACs codegen + `end>=start` + `showDateRangePicker` + CORE OUT=0) | ✅ |
| AD-48 | Seam présentateur `ZSelectPresenter` (jamais widget registry) | 1.3 (seam + délégation), 5.1/5.4 | ✅ |
| AD-49 | `awesome_select` vendorisé (membre workspace privé) | 1.5 (`publish_to:none`, gates, MIT, dépendu du seul `zcrud_select`) | ✅ |
| AD-50 | WYSIWYG HTML isolé `zcrud_html`, WebView controller isolé | 7.1 (initState 1×, ValueKey, débounce, sync hors focus), 7.2, 7.3 (exclusivité) | ✅ |
| AD-51 | Média dans `zcrud_media` | 6.1-6.5 (contrat `ZFilePicker`, types neutres) | ✅ |
| AD-52 | Nouvelles valeurs cœur additives/défensives (color multiple, itemsAreTags) | 8.1, 9.6 | ✅ |
| AD-53 | Finitions regroupées `zcrud_field_extras` | 9.1-9.5 | ✅ |
| AD-54 | Tokens d'aération + 3 écarts tranchés | 1.2 | ✅ |
| AD-55 | Binding = point de composition unique | 3.1 (détient LE registry, register 1×, injecté via `ZcrudScope`), AR-4 | ✅ |
| AD-56 | Harnais & showcase dans `example/` | 4.1/4.2, 10.1/10.2 (données fictives, zéro secret) | ✅ |
| AD-1 (hérité) | CORE OUT=0 | ACs NFR-2 dans 1.1/1.4/1.5/5.1/6.1/8.1/9.2 ; SM-6 grep | ✅ |
| AD-2/AD-15 (hérité) | SM-1 rebuild granulaire | 2.1, 4.1, 7.1, 10.2 (banc 100 car., zéro perte de focus) | ✅ |
| AD-13 (hérité) | RTL/a11y | NFR-3 transverse + ACs (≥48 dp, directionnel, `ListView.builder`) | ✅ |
| FR-26 (hérité) | Thème/l10n injectés | 1.2, 2.x (couleurs dérivées `ColorScheme`) | ✅ |
| AD-10 (hérité) | Désérialisation défensive | 1.1, 8.1, 9.1, 9.4 (`fromJsonSafe→null`, parse défensif) | ✅ |

**Couverture AD : 10/10 nouvelles (AD-47..56) + invariants hérités critiques honorés.**

### Findings par sévérité

**🔴 Critiques : 0**
**🟠 Majeurs : 0**

**🟡 Mineurs : 3**
1. **Incohérence de décompte stories (documentation).** L'Overview (l.19) et le texte (l.34) annoncent « 41 stories » ; le disque en contient **37** (grep `^### Story`). Impact : le `bmad-sprint-planning` génère un item de sprint-status *par story* — un décompte faux fausse le suivi. **Correction :** remplacer « 41 » par « 37 » (ou ajouter les 4 stories manquantes si l'intention était 41). *Non bloquant : les 40 FR sont couverts par les 37 stories réelles.*
2. **Figure « 40 EditionFieldType » approximative.** L'enum sur disque (`edition_field_type.dart`) compte **39 membres** aujourd'hui ; `dateRange` (net-new) le porte à 40, puis `pin`/`autocomplete`/`editableTable` (Story 9.1) à **43**. Le libellé « 40 types » du showcase (FR-40 / Story 10.1) est donc un instantané post-FR-5, pas le total final. **Correction :** préciser « 40+ (base + net-new) » dans FR-40/Story 10.1 pour éviter un critère d'acceptation numérique trompeur.
3. **UX sans artefact dédié.** Acceptable ici (Step 4), mais consigné : toute future exigence visuelle stricte (OQ-1 boîte grise) devra passer par le PRD/spine, pas s'improviser en dev.

## Open Questions résiduelles — classement bloquant / différable

| OQ | Sujet | Défaut retenu | Classement |
|---|---|---|---|
| OQ-1 | Parité pixel/visuelle stricte des sections (boîte grise) | Header sobre thémé (AD-54) | **Différable** (owner ; déclenche stories cœur additionnelles si exigé) |
| OQ-2 | `color` multiple native vs satellite | Native `ZColorConfig.multiple` (AD-52) | **Résolue** (tranchée par le spine) |
| OQ-3 | Sélecteur pays téléphone inline vs dialog | Inline (Story 3.2) | **Différable** (câblage `zcrud_intl`, sans impact structurel) |
| OQ-4 | Validateur Togo `length:8` vs `length:11` | Chiffres nus `length:8` (Story 3.2) | **Différable** (câblage) |
| OQ-5 | WYSIWYG HTML oui/non | Oui (FR-22/23, AD-50) | **Résolue** (contrainte owner verrouillée) |
| OQ-6 | Déclenchement FR-13 (`itemsAreTags`) & FR-37 (`icon`) sans call-site | Repli `ZUnsupportedFieldWidget` étiqueté ABSENT | **Différable** (placement déjà tranché AD-52/53 ; seul le déclenchement attend IFFD/DLCFTI) |
| OQ-7 | Shortlist finale des 6 formulaires du harnais | À figer sur « couverture max types × axes » | **Différable** (PM, à l'ouverture d'Epic 4/10 — AD-56) |
| NFR-8 | ETL app-side (`signature` PNG→strokes non réversible ; `phoneNumber`→E.164) | Hors packages zcrud | **Différable côté epics zcrud / BLOQUANT côté migration DODLP** — correctement exclu du périmètre des epics, à planifier côté app |

**Aucune OQ bloquante à l'intérieur du périmètre zcrud.** Les défauts conservateurs sont en place et documentés. Le seul risque bloquant identifié (NFR-8) est **externe** aux packages zcrud et correctement fléché comme travail app-side.

## Summary and Recommendations

### Overall Readiness Status

**READY** (avec 3 corrections mineures recommandées, non bloquantes).

Comptes vérifiés sur disque : **10 epics**, **37 stories** (≠ 41 annoncés), **40/40 FR couverts** (0 orphelin), **9/9 NFR**, **10/10 AD-47..56** + invariants hérités critiques honorés. **0 critique, 0 majeur, 3 mineurs.** Séquencement cohérent (fondation → dépendants ; écritures cœur sérialisées ; satellites disjoints parallélisables ; aucune dépendance avant). Testabilité forte (ACs Given/When/Then partout ; banc SM-1 et harnais de non-régression spécifiés).

### Critical Issues Requiring Immediate Action

Aucune. Rien ne bloque le démarrage de l'implémentation ni le `bmad-sprint-planning`.

### Recommended Next Steps

1. **Corriger le décompte de stories** dans l'Overview d'`epics.md` (« 41 » → « 37 »), pour que le sprint-planning génère un sprint-status fidèle.
2. **Préciser la figure « 40 types »** de FR-40 / Story 10.1 en « 40+ (base 39 + net-new dateRange/pin/autocomplete/editableTable) », afin que le critère d'acceptation du showcase ne repose pas sur un nombre trompeur.
3. **Consigner NFR-8 (ETL DODLP)** comme dépendance externe bloquante pour la *migration* (pas pour la livraison des packages) dans le futur plan de migration app-side — déjà correctement hors epics.
4. **Figer OQ-7** (shortlist des 6 formulaires) à l'ouverture d'Epic 4, sur le critère « couverture max types × axes ».
5. Procéder au **`bmad-sprint-planning`** puis au cycle strict `create-story → dev-story → code-review` par story, en respectant les 6 stories CORE-SÉRIALISÉES.

### Final Note

Cette évaluation a identifié **3 problèmes mineurs** répartis sur 2 catégories (documentation/décompte, précision de critère), **aucun critique ni majeur**. Le triptyque PRD / spine / epics est aligné, tracé à 100 %, et prêt pour l'implémentation. Les corrections mineures peuvent être appliquées avant ou en parallèle du sprint-planning sans retarder le démarrage.
