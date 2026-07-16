# PRD Quality Review — PRD E-STUDY-UI + E-MULTI-EDIT (parité UI d'étude zcrud)

> Rubrique : `.claude/skills/bmad-prd/assets/prd-validation-checklist.md` ·
> PRD : `_bmad-output/planning-artifacts/prds/prd-zcrud-study-ui-2026-07-16/prd.md` ·
> Calibration : PRD interne **tête de chaîne** (architecture → epics → implémentation stricte),
> produit = bibliothèque Flutter bi-consommateur (IFFD + lex_douane) ; périmètre tranché dans le
> brief amont `briefs/brief-zcrud-study-ui-2026-07-16/` — le marché n'a pas à être re-justifié ici.
> Les User Journeys sont volontairement remplacés par le parcours assemblé de l'app example (SM-2).

## Overall verdict

PRD dense et honnêtement décisionnel : les vraies décisions produit sont posées comme décisions
(plafond d'indices « plancher 2 », repli « qualité neutre 3 », défauts par enum `ZTimerDisplay`/
`ZCardAdvanceBehavior`, LaTeX PDF « dès la v1 » avec spike assumé), les références brownfield sont
exactes (tous les symboles cités — `ZStudySessionEngine`, `ZSrsQualityButtons`,
`ZStudySessionSelector`, `ZFlashcardGenerationPort`, `ZAdaptiveGrid` — vérifiés présents dans
`packages/*/lib`), et les critères de succès valident la thèse (matrice verte à tests porteurs +
contre-métriques). Ce qui est à risque : la **franchise de périmètre vit hors du document** — aucune
section Non-Goals, aucun tag `[ASSUMPTION]`, tout repose sur un renvoi au brief — ce qui, pour un
PRD tête de chaîne dont les epics seront extraits, laisse des exclusions (mode flowchart, extras
visuels de nœud, migration app-side) silencieusement inférables ; et une poignée de FR laissent des
sémantiques non bornées (double sauvegarde de FR-SU20, « jour » du streak FR-SU11, « Déplacer » et
hooks de cascade FR-SU19) que le create-story devra deviner.

## Decision-readiness — strong

Les choix sont tranchés et datés, pas « équilibrés » : FR-SU3 fixe une règle canonique chiffrée
(« chaque indice utilisé abaisse d'un cran la qualité maximale attribuable (plancher 2) ») ; FR-SU2
fixe le repli d'échec de port (« repli qualité neutre 3 … jamais d'exception, AD-10 ») ; FR-SU4 et
FR-SU5 posent des défauts explicites par enum et par mode ; FR-SU16 assume un choix au-delà de la
parité (« rendu LaTeX des formules dès la v1 ») en nommant le risque technique et le spike. Les
Points ouverts §5 (OA-1..OA-5) sont réellement ouverts — questions d'architecture sans réponse
cachée dans la phrase suivante — avec un owner clair (« pour l'architecture »). Les alternatives
écartées (flip_card, streak app-side, goldens…) sont documentées dans l'addendum du brief, que le
PRD référence comme normatif dès §1 — acceptable vu la calibration.

Une réserve mineure : la profondeur de FR-SU19 (« édition de champ commun … générée depuis le
`ZFieldSpec` ») est une option lourde assumée dans le memlog (« option profonde assumée ») mais le
PRD ne porte pas cette tension — aucun signal qu'il s'agit du chantier le plus risqué de l'epic,
seul à écrire dans `zcrud_core`.

### Findings
- **low** Tension FR-SU19 non signalée (§2 Groupe D) — le caractère « option profonde assumée »
  (memlog) et le statut de seul chantier `zcrud_core` méritent un mot de justification/risque dans
  le PRD lui-même, pas seulement l'isolement en epic dédié. *Fix :* une phrase de rationale/risque
  sur FR-SU19 (portée transverse toutes apps CRUD, complexité de génération depuis `ZFieldSpec`).

## Substance over theater — strong

Zéro meuble : pas de personas (justifié — produit dev bi-consommateur, servi par le brief), pas de
section différenciation, une Vision (§1) spécifique au produit (« best-of-breed … structure de
session de lex_ui + saisie interactive et gamification d'IFFD … sans aucune perte fonctionnelle »)
qui ne pourrait pas s'échanger avec un autre PRD. Les NFR sont majoritairement spécifiques et
outillés : NFR-SU3 chiffre (« cibles ≥ 48 dp », comportements Reduce Motion énumérés), NFR-SU7
nomme le gate (« graphe acyclique, CORE OUT=0 »), NFR-SU10 liste les gates CI réels. Seule
exception : NFR-SU9 reste adjectival (voir Done-ness).

## Strategic coherence — strong

La thèse est nette et tout en découle : *aucune migration tant que la parité UI n'est pas prouvée
verte* — les 20 FR sont adossés aux lignes ❌/⚠️ des matrices §2/§3 du rapport (vérifiées
existantes dans `docs/parity-study-ui-2026-07-16/rapport.md`), les critères de succès §4 mesurent
exactement cette thèse (« 0 ligne non couverte », « Feu vert migration ») et non de l'activité. Les
**contre-métriques sont présentes et mordantes** (« pas d'explosion de l'API publique (chaque
nouveau widget justifié par une ligne de la matrice) ; pas de nouvelle dep tierce au-delà des deux
décidées ; `zcrud_core` modifié uniquement par E-MULTI-EDIT ») — c'est rare et c'est exactement le
bon garde-fou pour un epic de parité. Le découpage en deux epics suit la logique d'architecture
(règle « une seule story à la fois dans core »), pas la facilité.

## Done-ness clarity — adequate

La dimension la plus sollicitée en aval, et elle tient globalement : la plupart des FR portent des
conséquences testables chiffrées (FR-SU3 plancher 2 ; FR-SU10 « défaut 30 », « catégorisation en
O(1) » ; FR-SU12 « défaut 10 », mapping maîtrise « mauvais = q1-2/jamais vu, bon = q3, maîtrisé =
q4-5 » ; FR-SU8 « un seul tir, jamais si Reduce Motion » ; FR-SU19 « jamais de lot silencieusement
partiel »). Mais plusieurs sémantiques restent à deviner, précisément là où le create-story n'aura
pas d'autre source :

### Findings
- **medium** Double sauvegarde ambiguë (FR-SU20) — « édition individuelle à sauvegarde locale
  automatique » vs « sauvegarde finale groupée explicite » : la sémantique de « locale » n'est pas
  définie (brouillon en mémoire ? persistance repo ? que perd-on si on quitte sans sauvegarde
  finale ?). Deux lectures opposées donnent deux implémentations incompatibles. *Fix :* une phrase
  définissant le cycle de vie du brouillon (état local non persisté jusqu'à la sauvegarde groupée,
  ou auto-persist par carte + rollback).
- **medium** Sémantique du « jour » du streak non bornée (FR-SU11) — « incrément si ≥ 1 répétition
  notée le jour, remise à zéro sinon » : fuseau horaire (local ? UTC ?), frontière de journée,
  moment d'évaluation de la remise à zéro (à la lecture ? à la répétition suivante ?) non
  spécifiés — pour un « calcul pur » canonique de domaine, c'est la définition même du testable.
  *Fix :* fixer la référence temporelle (ex. date locale de l'appareil, comparaison sur des dates
  calendaire) dans le FR.
- **medium** « Déplacer » et hooks de cascade sous-spécifiés (FR-SU19) — destination du déplacement
  (dossier ? entité parente générique ?), comportement sans cible valide, et contrat des « hooks de
  cascade app-side » de la suppression ne sont ni définis ni couverts par OA-5 (qui ne liste que
  les trois ports IA). *Fix :* préciser la cible du déplacement et ajouter le contrat des hooks de
  lot à OA-5.
- **low** « délai court à la IFFD » (FR-SU5) — la valeur (~200 ms) existe dans l'addendum du brief
  (§A.1) mais pas dans le PRD ; « court » n'est pas testable. *Fix :* « délai ~200 ms
  (configurable) » ou renvoi explicite à l'addendum.
- **low** Seuils du feedback pédagogique absents (FR-SU9) — les bandes de qualité sont là
  (« 4-5 / 3 / 1-2 ») mais la modulation par « temps de réponse et indices utilisés » n'a aucun
  seuil dans le PRD (le « <10 s sans indice = exceptionnel » vit dans l'addendum §A.3). *Fix :*
  porter les seuils par défaut ou les déclarer configurables avec défauts à fixer à l'archi.
- **low** NFR-SU9 adjectival — « swipe et révélation fluides » sans borne (pas de budget de frames
  jankées ni de cible ms/frame) ; le profiling est exigé mais sans critère de réussite chiffré.
  *Fix :* un seuil (ex. 0 frame > 32 ms sur le parcours example en profile, ou aligner sur le
  protocole SM-1 existant).

## Scope honesty — thin

C'est le point faible du document. Le brief contient un « Hors périmètre (explicite) » de qualité
(impls IA app-side, mode flowchart et extras visuels de nœud, voie PDF serveur, migration
app-side) — mais le PRD **ne le restitue ni ne le référence en tant que tel** : aucune section
Non-Goals, aucun callout `[NON-GOAL for MVP]`, et le seul renvoi est générique (« Détail des
décisions déjà tranchées : brief final », §1). Certaines exclusions réapparaissent inline (FR-SU16
« La voie d'export côté serveur reste un port app-side » ; FR-SU15/FR-SU18 « impl app-side ») mais
d'autres non : rien dans le PRD n'exclut le mode flowchart ni les extras couleur/taille de nœud
IFFD — un auteur d'epics qui n'ouvre pas le brief peut les supposer inclus dans FR-SU17. Pour un
PRD feu-vert tête de chaîne, l'omission doit être écrite là où on extrait.

Aucun tag `[ASSUMPTION]` ni index — plausiblement honnête (mode coaching, décisions confirmées une
à une d'après le memlog), mais au moins une inférence non confirmée par le user mériterait le tag :
le mapping cramming ≈ `ZWhiteExamSessionEngine` (« candidat » dans l'addendum, OA-4 ici). La
densité de points ouverts (5 OA pour 20 FR, tous adressés à l'architecture) est saine pour ces
stakes ; en revanche la condition de reprise décidée (« résolution exigée AVANT create-story des
stories concernées », memlog) n'apparaît pas dans §5 — c'est pourtant un garde-fou de pilotage que
l'orchestrateur d'implémentation lira dans le PRD, pas dans le memlog.

### Findings
- **high** Non-Goals absents du PRD (§ absent) — les exclusions du brief (« mode flowchart formes
  libres, extras visuels de nœud IFFD (couleur/taille) », « migration app-side elle-même », impls
  IA) ne sont ni restituées ni citées comme non-goals ; risque de scope creep silencieux au
  découpage en stories, notamment sur FR-SU17. *Fix :* section « Non-objectifs (v1) » de 4-5
  lignes reprenant le hors-périmètre du brief, ou callouts `[NON-GOAL]` sur FR-SU17/FR-SU16.
- **low** Condition de reprise des OA non écrite (§5) — « owner : architecture » est implicite mais
  le PRD ne dit pas que OA-1..OA-5 doivent être résolus **avant le create-story** des stories
  concernées (décision memlog). *Fix :* une phrase d'en-tête en §5.

## Downstream usability — adequate

IDs impeccables : FR-SU1..FR-SU20 et NFR-SU1..NFR-SU10 contigus, uniques ; les renvois croisés
résolvent tous (FR-SU10 → « filtres FR-SU12 » ; FR-SU14 → « capacité FR-SU19 » ; FR-SU20 →
FR-SU15/FR-SU19 ; SM-1 → matrices §2/§3 du rapport, vérifiées). Chaque groupe de FR nomme ses
packages cibles et son epic — l'extraction vers epics/stories est quasi mécanique. Les entrées
(brief, rapport + annexes) sont citées en tête avec chemins réels.

Pas de glossaire : les noms de domaine (« qualité » 1-5, « dues », « maîtrisées », « test
porteur », modes de session) sont employés de façon cohérente et « maîtrisé = q4-5 » est défini au
détour de FR-SU12, mais un lecteur d'architecture qui prend le PRD seul doit savoir que « qualité »
est l'échelle SM-2 du SRS existant. Pour un produit interne dont ces termes vivent déjà dans
`zcrud_flashcard`/`zcrud_session`, c'est tolérable — d'où adequate et non thin.

### Findings
- **medium** Pas de glossaire (§ absent) — « qualité (1-5) », « dues », « maîtrisées », « carte
  jamais apprise », « test porteur » ne sont définis nulle part de façon centrale ; la définition
  de « maîtrisé » n'existe qu'en incise de FR-SU12 alors que FR-SU8 l'utilise pour une stat.
  *Fix :* mini-glossaire de 6-8 termes (ou renvoi vers le canonique du PRD étude existant).

## Shape fit — strong

La forme est exactement celle du produit : capability spec par groupes de packages, UJs remplacés
par le parcours assemblé de l'app example (SM-2) — substitution annoncée et adaptée à un produit
dev bi-consommateur ; SMs opérationnels (matrice, vérif verte, feu vert) plutôt qu'user-facing,
ce qui est correct ici. Brownfield exact : tous les symboles existants cités (`ZStudySessionEngine`,
`ZWhiteExamSessionEngine` dans `zcrud_session`, `ZStudySessionSelector` dans `zcrud_study_kernel`,
`ZFlashcardGenerationPort` dans `zcrud_study`, `ZAdaptiveGrid` dans `zcrud_responsive`,
`ZcrudTheme` dans `zcrud_core`) ont été vérifiés présents sur disque, et le nouveau vs l'existant
est systématiquement distingué (« absence confirmée dans zcrud », « étend/consomme », « port
existant »). Ni sur-formalisé ni sous-formalisé ; la compression (12 Ko pour 20 FR) est un choix
assumé qui fonctionne parce que le brief+addendum portent le détail — avec la réserve de scope
honesty ci-dessus.

## Mechanical notes

- IDs : FR-SU1..FR-SU20 et NFR-SU1..NFR-SU10 contigus, sans doublon ; OA-1..OA-5 contigus.
- Renvois : FR-SU10→FR-SU12, FR-SU14→FR-SU19, FR-SU20→FR-SU15/FR-SU19, §4→matrices §2/§3 du
  rapport — tous résolvent. Renvoi générique au brief en §1 (chemin valide).
- Index d'assumptions : aucun tag `[ASSUMPTION]` inline et aucun index — roundtrip vide (cohérent,
  mais voir Scope honesty pour OA-4/cramming).
- Glossaire absent (voir Downstream usability).
- §4 : liste numérotée 1-4 puis un item à puce « Contre-métriques » — légère rupture de forme,
  sans impact.
- `zcrud_session`, `zcrud_study`, `zcrud_study_kernel`, `zcrud_responsive` cités par le PRD
  existent sur disque mais ne figurent pas dans la liste des 14 packages du CLAUDE.md (obsolète) —
  signal pour la doc racine, pas pour le PRD.
- Statut front-matter `draft` alors que le memlog indique FINALIZE exécuté — à passer à `final`
  si la revue est absorbée.

---

**Comptes** : critical 0 · high 1 · medium 4 · low 5.
**Verdicts** : Decision-readiness strong · Substance strong · Coherence strong · Done-ness
adequate · Scope honesty thin · Downstream usability adequate · Shape fit strong.
