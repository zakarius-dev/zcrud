---
title: "PRD — E-STUDY-UI + E-MULTI-EDIT : parité UI d'étude zcrud avant migration IFFD & lex_douane"
status: final
created: 2026-07-16
updated: 2026-07-16
---

# PRD — E-STUDY-UI + E-MULTI-EDIT

> Entrées : brief final `briefs/brief-zcrud-study-ui-2026-07-16/` (brief.md + addendum.md) ·
> rapport `docs/parity-study-ui-2026-07-16/rapport.md` (+ 6 annexes).

## 1. Vision

Compléter zcrud avec la couche présentation d'étude **best-of-breed** (structure de session de
`lex_ui` + saisie interactive et gamification d'IFFD), pour que la migration des deux apps se fasse
**sans aucune perte fonctionnelle**. Pur-Flutter (AD-2/AD-15), thème/l10n injectés (AD-13),
**enums > booléens**, toute IA derrière des ports. Deux epics : **E-STUDY-UI** (additif,
satellites uniquement) et **E-MULTI-EDIT** (seul à écrire dans `zcrud_core`/`zcrud_list`).

Deux intentions qualitatives guident toutes les exigences : **chaque app garde son identité
visuelle** à la migration (d'où les variantes par enum plutôt qu'un style unique imposé), et
l'API est calibrée **bi-consommateur** (IFFD + lex_douane) — généricité au juste besoin, pas de
sur-ingénierie multi-futur.

## 2. Exigences fonctionnelles

Numérotation `FR-SU<n>` (IDs stables). Quatre groupes : **A. Révision**, **B. Gestion** et
**C. Mindmap** (epic E-STUDY-UI) ; **D. Multi-édition** (epic E-MULTI-EDIT).

### Groupe A — Révision (epic E-STUDY-UI ; zcrud_flashcard, zcrud_session, zcrud_study_kernel)

- **FR-SU1 — Carte de révision adaptative** (`ZFlashcardReviewCard`). Affiche une flashcard selon
  son type (6 types canoniques) ; révélation question→réponse via `ZRevealTransition { flip3d,
  fade }` (flip 3D maison, pas de dépendance `flip_card` — l'enum permet à chaque app de conserver son
  identité visuelle) ; Reduce Motion → révélation instantanée ou fondu court. Contenus
  question/réponse/choix rendus en texte riche (markdown/LaTeX) via le mécanisme de rendu
  injectable, jamais un rendu codé en dur.
- **FR-SU2 — Saisie interactive notée**. QCM : cases à cocher, mode simple/multiple déduit du
  nombre de bonnes réponses, correction visuelle après soumission ; V/F : deux boutons à
  auto-soumission ; ouverte/exercice : rédaction de la réponse. Évaluation locale exacte pour
  QCM/VF ; port `ZFlashcardAnswerEvaluationPort` pour les réponses rédigées (score 0-5, **repli
  qualité neutre 3** si échec du port — jamais d'exception, AD-10). Bouton « Je ne sais pas » =
  soumission directe qualité 1.
- **FR-SU3 — Indices**. Bouton « Indice » : montre l'indice stocké (`hint`), puis obtient des
  indices supplémentaires via `ZFlashcardHintPort` (IA app-side) quand épuisé. Règle canonique :
  **chaque indice utilisé abaisse d'un cran la qualité maximale attribuable (plancher 2)**,
  configurable via la config de session ; le nombre d'indices est aussi transmis au port d'évaluation.
- **FR-SU4 — Minuteur de réponse**. Temps mesuré par carte (toujours) ; affichage via
  `ZTimerDisplay { hidden, elapsed, countdown }`, défaut `hidden`. Alimente le feedback
  pédagogique et les stats de fin de session.
- **FR-SU5 — Avance post-soumission**. `ZCardAdvanceBehavior { auto, manual }` avec défaut par
  mode de session : `auto` en test/examen blanc (délai court, à la façon d'IFFD), `manual` en
  apprentissage/consultation (l'utilisateur lit la correction puis avance).
- **FR-SU6 — Pile de session swipeable** (`ZSessionCardSwiper`, `flutter_card_swiper ^7.2.0`).
  Swipe = navigation uniquement ; la **notation reste aux `ZSrsQualityButtons`**. Indicateurs :
  points colorés par qualité de dernière révision (mode lot N), barre segmentée (mode complet),
  indicateurs émotionnels pendant le drag.
- **FR-SU7 — Modes de session**. Enum couvrant : apprentissage lot N, apprentissage complet,
  consultation (sans SRS), test, examen blanc, cramming (sans écriture SRS) — chacun mappé sur
  les **trois runtimes existants** — `ZStudySessionEngine` (spaced/learn), `ZLinearSessionState`
  (list/cramming), `ZWhiteExamSessionEngine` (test/examen blanc) — **aucun nouveau moteur**
  (AD-34).
- **FR-SU8 — Écran de fin de session** (`ZSessionSummaryView`). Trophée animé (scale élastique +
  glow), titre en dégradé, cercles de fond animés (tous soumis à Reduce Motion), stats (cartes
  totales / maîtrisées / durée), assemble `ZSessionQualityBreakdown` + `ZStudyProgressRings`,
  confetti **opt-in** (`confetti ^0.8.0`, un seul tir, **jamais si Reduce Motion**), boutons
  « Terminer » / « Encore N dues » (callbacks injectés).
- **FR-SU9 — Feedback pédagogique**. Après chaque soumission en mode apprentissage : message
  sélectionné selon qualité (4-5 / 3 / 1-2), temps de réponse et indices utilisés — palier
  « exceptionnel » par défaut : réponse < 10 s sans indice (seuil configurable) ; banques de
  messages par défaut FR/EN via l10n zcrud, surchargeables par l'app (slot).
- **FR-SU10 — Sélecteur de session** (`ZSessionModeSelector`). Options calculées dynamiquement :
  « Apprendre +N » (jamais apprises, taille de lot configurable — défaut 30, avec anneau de
  progression), « À réviser » (dues triées par urgence, visible si > 0), « Test » (ouvre les
  filtres FR-SU12) ; badge streak (FR-SU11) ; catégorisation en O(1).
- **FR-SU11 — Streak quotidien canonique**. Entité domaine (zcrud_study_kernel) : calcul **pur
  et paramétré par l'horloge** (l'instant courant est un paramètre — testable) sur le **jour
  civil local de l'appareil** (frontière à minuit local) : incrément à la première répétition
  notée du jour, **remise à 1** (la répétition du jour compte) après un jour civil complet sans
  répétition notée ; persistance
  via les ports existants ; mis à jour après répétition **hors mode consultation**, avec
  confirmation discrète (snackbar/toast via le toaster zcrud existant) ; primitive UI badge
  flamme.
- **FR-SU12 — Filtres test/examen**. Fonction **pure** : nombre de questions (défaut 10, tirage
  aléatoire si excédent), types de questions, niveaux de maîtrise (mauvais = q0-2/jamais vu,
  bon = q3, maîtrisé = q4-5), tags, sources ; + dialog de configuration ; mélange des choix QCM
  avant session. Étend/consomme `ZStudySessionSelector`.
- **FR-SU13 — UI d'examen blanc** (`ZListSessionView`). Vue liste au-dessus de
  `ZWhiteExamSessionEngine` (absence confirmée dans zcrud) : saisie interactive par question
  (FR-SU2), correction en fin d'examen, sans écriture SRS.

### Groupe B — Gestion (epic E-STUDY-UI ; zcrud_flashcard, zcrud_export)

- **FR-SU14 — Liste de flashcards + filtres** (`ZFlashcardListView`). Liste/grille responsive
  (réutilise `ZAdaptiveGrid`) ; carte compacte (question riche tronquée, badge type, tags, source,
  aperçu réponse en grille) ; **recherche normalisée** (insensible accents/espaces) sur question +
  réponse/choix + tags, champs cherchés configurables ; **tris** : date, titre, **ordre manuel
  persisté** ; filtres sous-dossier + tags (OU composables) + **sources** (documents, notes… —
  les types de source enregistrés au registre) ; actions par item (menu existant) ; **point
  d'entrée de création** proposant saisie manuelle ou génération IA (cette dernière visible
  seulement si un port de génération est fourni) ; sélection multiple branchée sur la capacité
  FR-SU19.
- **FR-SU15 — Flux UI de génération IA**. Sheet de génération (au-dessus du port existant
  `ZFlashcardGenerationPort`, implémentation app-side) exposant la **configuration de la requête** :
  source (document/pages, sujets suggérés, texte libre), répartition du nombre de questions par
  type, instructions complémentaires — portée par le contrat du port (OA-5) ; + feuille de
  **confirmation de tags** post-génération ; les cartes générées ne sont jamais sauvegardées
  silencieusement : elles sont remises à l'appelant pour revue (typiquement dans le
  multi-éditeur FR-SU20).
- **FR-SU16 — Gabarit PDF flashcards** (`ZFlashcardPdfTemplate`, zcrud_export, Syncfusion local).
  Mise en page typée : titre, numérotation, badge d'instruction par type, ✓/✗ colorés (QCM/VF),
  réponses distinguées, **explication** ; options : avec/sans réponses ; portée : dossier entier
  ou sélection ; rendu markdown (gras/italique/souligné/listes) **et rendu LaTeX des formules dès
  la v1** (technique de rendu — rasterisation hors écran — à valider par spike à l'architecture).
  Sortie : document typé (octets + nom de fichier + type MIME) ; la prévisualisation, l'impression
  et le partage vivent dans le **satellite optionnel `zcrud_export_ui`** (`printing`, AD-42) —
  `zcrud_export` reste sans dépendance de plateforme. La voie d'export côté serveur reste un port
  app-side.
- **FR-SU21 — Carte en lecture seule**. Une flashcard `isReadOnly` (ex. curée depuis un
  référentiel) s'ouvre en **aperçu lecture seule** (rendu de révision, édition/suppression
  masquées) avec l'action « **Dupliquer pour modifier** » qui crée une copie éditable
  (l'original reste intact).

### Groupe C — Mindmap (epic E-STUDY-UI ; zcrud_mindmap, zcrud_markdown, zcrud_study)

- **FR-SU17 — Édition riche de nœud**. Le **label et le contenu** d'un nœud deviennent éditables
  en markdown/LaTeX via un **slot d'éditeur injectable** dans l'outline editor ; l'adaptateur
  prêt à injecter vit **dans `zcrud_mindmap`** (au-dessus de sa dépendance existante à
  `zcrud_markdown` — jamais l'inverse, qui créerait un cycle ; AD-40), aucun type Quill dans une
  signature publique ; sans injection, repli sur l'édition texte brut actuelle. Dans le graphe, le
  label riche est **borné à la cellule de taille fixe** (troncature propre, sans mesure
  intrinsèque — AD-41) ; le rendu riche complet est garanti dans l'outline et la liste a11y.
- **FR-SU18 — Port de génération de mindmap** (`ZMindmapGenerationPort`, zcrud_study). Contrat
  aligné sur `ZFlashcardGenerationPort` ; implémentations app+backend-side.

### Groupe D — Multi-édition (epic E-MULTI-EDIT ; zcrud_core, zcrud_list, zcrud_flashcard)

- **FR-SU19 — Capacité moteur de sélection et d'actions de lot**. Sur toute liste zcrud :
  mode sélection multiple (long-press / cases à cocher, « tout sélectionner », badge compteur) ;
  actions intégrées **Supprimer** (par lots, confirmation, hooks de cascade app-side) et
  **Déplacer** ; **slot d'actions de lot personnalisées** enregistrables par l'app ; et
  **édition de champ commun** — « appliquer la valeur X au champ Y des N éléments » — générée
  depuis le `ZFieldSpec` du modèle, avec validation par lot et rapport d'échecs par élément
  (jamais de lot silencieusement partiel — AD-10). « Déplacer » = réaffectation du champ de
  rattachement défini par le modèle (dossier/parent), destination choisie via un sélecteur
  injecté par l'app ; les suppressions passent par des **hooks de cascade** app-side (ex. purge
  des données SRS associées) dont le contrat est spécifié en OA-5.
- **FR-SU20 — Multi-éditeur de flashcards** (`ZMultiFlashcardEditor`, premier consommateur).
  Split-view responsive (sidebar liste + formulaire ; mobile : navigation liste ↔ formulaire).
  **Cycle de vie du brouillon** : toutes les modifications (édition par carte, ajouts,
  suppressions, applications groupées) s'appliquent immédiatement à une **liste de travail en
  mémoire** — rien n'est persisté avant la **sauvegarde finale groupée explicite**, qui remet la
  liste complète à l'appelant ; quitter sans sauvegarder passe par le garde-fou d'abandon
  existant (`ZDiscardChangesGuard`). Ajout/suppression/sélection multiple ; aperçu lecture via
  `ZFlashcardReviewCard` ; intégration du flux de génération IA (FR-SU15, résultats ajoutés à la
  liste de travail pour revue) ; **panneau « appliquer à la sélection »** (tags, dossier, type —
  s'appuie sur FR-SU19).

## 3. Hors périmètre (non-goals — fermés, ne pas rouvrir aux epics)

- **Implémentations concrètes d'IA** (génération, évaluation, indices) — app-side (AD-15) ;
  zcrud ne livre que les ports et leurs replis.
- **Mode flowchart formes libres** (IFFD `flutter_flow_chart`) — legacy, non porté.
- **Extras visuels de nœud IFFD** (couleur d'arête, taille, redimensionnement) — app-side,
  logeables via les slots `extension`/`extra` (AD-4). FR-SU17 couvre le riche **label+contenu**,
  rien de plus.
- **Voie d'export PDF côté serveur** — port app-side (seul le gabarit local est canonique).
- **La migration app-side elle-même** — sessions dédiées par app, hors de ce repo.

## 4. Glossaire

- **Qualité (0-5)** : note SRS d'une répétition — 0 blackout, 1 fail, 2 hard, 3 good, 4 easy, 5 perfect
  (échelle SM-2 existante de `ZSrsConfig`/`ZSm2Scheduler`).
- **Due** : carte dont la date de prochaine révision (`nextReviewDate`) est atteinte ou dépassée.
- **Jamais vue / apprise** : carte sans aucune répétition enregistrée / avec au moins une.
- **Maîtrisée** : dernière répétition de qualité 4-5 (« bon » = 3 ; « mauvais » = 0-2 ou jamais
  vue) — définitions utilisées par FR-SU10/FR-SU12 et les stats FR-SU8.
- **Lot (d'apprentissage)** : sous-ensemble de cartes jamais vues proposé par « Apprendre +N »
  (taille configurable, défaut 30).

## 5. Exigences non fonctionnelles

- **NFR-SU1 — Pur-Flutter (AD-2/AD-15)** : aucun gestionnaire d'état dans les packages de l'epic ;
  tout code manager-spécifique dans les bindings existants.
- **NFR-SU2 — Rebuilds granulaires (esprit SM-1)** : pendant la rédaction d'une réponse, seul le
  champ de saisie se reconstruit ; le swipe d'une carte ne reconstruit pas la pile ; controllers
  stables (create/dispose), jamais recréés au rebuild.
- **NFR-SU3 — Accessibilité (AD-13)** : variantes directionnelles (RTL), `Semantics` explicites,
  cibles ≥ 48 dp, **Reduce Motion** respecté partout (flip → fondu/instantané, confetti supprimé,
  indicateurs de drag statiques).
- **NFR-SU4 — L10n** : aucun libellé en dur ; tous les textes (y compris banques de feedback
  pédagogique) via l'infra l10n zcrud, FR/EN fournis, surchargeables.
- **NFR-SU5 — Thème** : aucune couleur codée en dur ; `ColorScheme`/`ZcrudTheme` (repli
  `Theme.of(context)`), y compris couleurs de qualité SRS et confetti.
- **NFR-SU6 — Robustesse (AD-10)** : l'échec d'un port (éval, indices, génération) ne casse
  jamais la session — replis définis par FR (qualité neutre, indice indisponible, etc.).
- **NFR-SU7 — Isolation des dépendances (AD-1)** : `flutter_card_swiper`/`confetti` confinés à
  `zcrud_session` ; graphe acyclique, CORE OUT=0 ; aucun nouveau package tiers dans `zcrud_core`.
- **NFR-SU8 — Hors-ligne** : une session de révision complète (hors appels de ports IA)
  fonctionne sans réseau ; les ports en échec déclenchent les replis NFR-SU6.
- **NFR-SU9 — Performance** : swipe et révélation fluides sur le parcours de l'app example
  (profiling au titre du critère de succès) ; listes virtualisées (`.builder`).
- **NFR-SU10 — Distribution** : code généré committé (`packages/*/lib`), gates CI verts
  (anti-reflectable, secrets, codegen-distribution, rétro-compat sérialisation).

## 6. Critères de succès & métriques

1. **Matrice de parité toute verte** — chaque ligne ❌/⚠️ des matrices §2/§3 du rapport passe à
   ✅ avec **test porteur** (métrique : 0 ligne non couverte).
2. **Parcours assemblé dans l'app example** — sélecteur → swiper → carte interactive (saisie,
   indices, feedback) → célébration ; sert de preuve visuelle et de doc de migration.
3. **Vérif verte repo-wide** — generate + analyze RC=0 + tests RC=0 + gates.
4. **Feu vert migration** — IFFD et lex_douane peuvent démarrer en parallèle, zéro perte
   identifiée.
- **Contre-métriques** : pas d'explosion de l'API publique (chaque nouveau widget justifié par
  une ligne de la matrice) ; pas de nouvelle dépendance tierce au-delà des **trois** décidées
  (`flutter_card_swiper`, `confetti`, et `printing` **confinée au satellite optionnel
  `zcrud_export_ui`** — AD-42) ; `zcrud_core`
  modifié uniquement par E-MULTI-EDIT.

## 7. Points ouverts (pour l'architecture)

- OA-1 : technique de rendu **LaTeX dans le PDF** (rasterisation hors écran → image) — spike.
- OA-2 : rendu du **label riche** dans le graphe graphite (mesure du texte, taille des nœuds).
- OA-3 : mécanisme de persistance de l'**ordre manuel** (champ d'ordre — lire le code lex).
- OA-4 : mapping exact **cramming** sur les moteurs existants (session sans écriture SRS).
- OA-5 : contrats précis des ports et hooks (`ZFlashcardAnswerEvaluationPort`,
  `ZFlashcardHintPort`, `ZMindmapGenerationPort`, requête de génération FR-SU15 — sources/
  répartition par type/instructions —, hooks de cascade de suppression FR-SU19) validés contre
  les implémentations réelles lex/IFFD (lecture seule).
- OA-6 : prévisualisation/impression/partage du PDF (FR-SU16) — vérifier ce que zcrud_export
  fournit déjà ; sinon rester app-side (pas de nouvelle dépendance type `printing` sans décision).
