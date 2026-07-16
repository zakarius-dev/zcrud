---
title: "Brief — E-STUDY-UI : parité UI d'étude (flashcards/mindmaps) avant migration IFFD & lex_douane"
status: final
created: 2026-07-16
updated: 2026-07-16
---

# Brief produit — E-STUDY-UI

> Source d'entrée : `docs/parity-study-ui-2026-07-16/rapport.md` (+ 6 annexes d'inventaire).

## Résumé exécutif

zcrud a porté **le cerveau de l'étude, pas son visage**. Le domaine flashcard (6 types), l'édition,
le SRS SM-2 et les moteurs de session sont à parité avec les apps sources — mais la **couche de
révision** que voient réellement les utilisateurs (carte flip adaptative, saisie interactive notée,
pile swipeable, écran de célébration, liste filtrable, export PDF, examen blanc) n'existe que dans
`lex_ui` (lex_douane) et IFFD. Migrer aujourd'hui livrerait une app d'étude **décapitée** : le moteur
tourne, l'écran de révision régresse visiblement.

L'epic **E-STUDY-UI** comble cet écart dans zcrud, en pur-Flutter (AD-2/AD-15), **avant** toute
migration app-side. La cible de parité n'est pas lex seul : c'est **lex + tout le meilleur d'IFFD**
(saisie interactive notée, système d'indices, modes de session, sélecteur de session, gamification).
S'y ajoutent deux capacités promues au rang canonique par décision produit : la **multi-édition
générique** (moteur + premier consommateur flashcard) et l'**édition riche de nœud mindmap**
(slot injectable).

**Pourquoi maintenant** : la migration IFFD/lex_douane est la prochaine étape du plan zcrud ; cet
epic en est le **dernier verrou** pour les flashcards (les mindmaps sont déjà migrables, IA à câbler
app-side).

## Le problème

- Trois implémentations divergentes de la même UI d'étude (IFFD, lex_ui, feu DLCFTI) ; zcrud n'en a
  porté que le socle non visuel.
- Une migration « à l'aveugle » ferait perdre des fonctionnalités **réellement en production** :
  carte flip, swiper, célébration, liste+filtres, PDF (matrice §2 du rapport de parité).
- Les pièces best-of-breed existent, mais éparpillées entre `lex_ui` et IFFD — aucune base de
  code ne les réunit.

## Qui est servi

- **Consommateurs directs (exhaustifs)** : IFFD et lex_douane — DODLP et DLCFTI n'ont **pas** de
  fonctionnalité d'étude. L'API est donc calibrée **bi-consommateur** : généricité au juste besoin,
  pas de sur-ingénierie multi-futur.
- **Exception** : la multi-édition **générique moteur** sert potentiellement toutes les apps CRUD
  (DODLP inclus) — c'est la seule pièce de l'epic à vocation transverse.

## La solution

Compléter zcrud avec la couche présentation d'étude **best-of-breed** : la structure de session la
plus aboutie vient de `lex_ui`, la saisie interactive et la gamification les plus riches viennent
d'IFFD — fusionnées sous les conventions zcrud (pur-Flutter AD-2/AD-15, thème/l10n injectés AD-13,
**enums > booléens**, ports pour toute IA). Aucun gestionnaire d'état, aucune impl IA embarquée :
les apps injectent leurs adaptateurs à la migration.

## Périmètre (v1)

**A. Révision (zcrud_flashcard / zcrud_session)**
1. `ZFlashcardReviewCard` — carte de révision adaptative par type ; révélation via
   `ZRevealTransition { flip3d, fade }` (flip 3D maison `Transform.rotateY`, **pas** de dep
   `flip_card` ; Reduce Motion → fondu/instantané).
2. **Saisie interactive notée** — QCM cochable (simple/multiple) avec correction visuelle, V/F
   auto-soumis, réponse ouverte rédigée ; évaluation locale (QCM/VF) et port
   `ZFlashcardAnswerEvaluationPort` (ouverte, repli qualité neutre) ; minuteur ; « Je ne sais
   pas » (qualité 1) ; **indices** : indice stocké + port `ZFlashcardHintPort` (génération IA),
   nb d'indices module la qualité.
3. `ZSessionCardSwiper` — pile swipeable (`flutter_card_swiper ^7.2.0`), notation réservée aux
   `ZSrsQualityButtons` ; indicateurs de progression (points colorés par qualité, barre
   segmentée, émojis pendant le drag).
4. **Modes de session** — enum couvrant : apprentissage lot N, apprentissage complet,
   consultation (listOnly), test, examen blanc, **cramming (inclus)** — mappés sur les moteurs
   existants (`ZStudySessionEngine`/`ZWhiteExamSessionEngine`).
5. `ZSessionSummaryView` — écran de fin fusion lex+IFFD : trophée animé, stats (total /
   maîtrisées / durée), `ZSessionQualityBreakdown` + `ZStudyProgressRings`, confetti
   (`confetti ^0.8.0`, 1×, jamais si Reduce Motion), boutons « Terminer / Encore N dues ».
6. **Feedback pédagogique** — sélection de message selon qualité/temps/indices, banques par
   défaut FR/EN via l10n zcrud, surchargeables (slot).
7. `ZSessionModeSelector` — point d'entrée type IFFD : « Apprendre +N » / « À réviser
   (urgence) » / « Test » avec calcul dynamique des lots ; badge streak.
8. **Streak quotidien canonique** — entité domaine (zcrud_study_kernel, calcul pur, persistance
   via ports existants) + primitive UI badge flamme.
9. **Filtres test/examen** — fonction pure (nb questions, types, niveaux de maîtrise, tags,
   sources) + dialog de configuration ; étend/consomme `ZStudySessionSelector`.
10. `ZListSessionView` — UI d'examen blanc (absence confirmée dans le code) au-dessus de
    `ZWhiteExamSessionEngine`.

**B. Gestion (zcrud_flashcard / zcrud_list / zcrud_export)**
11. `ZFlashcardListView` + filtres UI — liste/grille (réutilise `ZAdaptiveGrid`), recherche
    normalisée (insensible accents), tri, filtre sous-dossier + tags (OU composables), actions
    par item ; sélection multiple branchée sur (12).
12. **Multi-édition générique** — deux étages : (a) capacité **moteur** (sélection multiple +
    actions de lot : suppression, déplacement, tags…) dans `zcrud_list`/`zcrud_core` ;
    (b) `ZMultiFlashcardEditor` premier consommateur (split-view responsive, ajout, suppression
    groupée, aperçu, intégration du flux de génération IA).
13. **Flux UI de génération IA** — sheet de génération + confirmation de tags post-génération
    (portés de lex), au-dessus du port existant `ZFlashcardGenerationPort` (impl app-side).
14. `ZFlashcardPdfTemplate` (zcrud_export) — gabarit PDF local Syncfusion typé
    question/réponse/choix/explication (badges d'instruction, ✓/✗ colorés, options avec/sans
    réponses ; dossier entier ou sélection). La voie serveur reste un port app-side.

**C. Mindmap (zcrud_mindmap / zcrud_markdown / zcrud_study)**
15. **Édition riche de nœud** — slot d'éditeur **injectable** dans l'outline editor ; l'impl
    markdown/LaTeX vit dans `zcrud_markdown` (zcrud_mindmap ne dépend jamais de Quill).
16. `ZMindmapGenerationPort` (zcrud_study) — port dédié pour homogénéiser la génération IA
    (impl app+backend-side).

**Hors périmètre (explicite)**
- Impls concrètes d'IA (génération, évaluation, indices) — app-side (AD-15).
- Mode flowchart formes libres, extras visuels de nœud IFFD (couleur/taille) — legacy/app-side
  (logeables via `extension`/`extra` AD-4).
- Voie d'export PDF côté serveur — port app-side.
- Migration app-side elle-même (sessions dédiées par app, hors de ce repo).

## Découpage

Deux epics planifiés dans la même vague :
- **E-STUDY-UI** — entrants 1-11 et 13-16 : purement **additif dans les packages satellites**
  (zcrud_flashcard, zcrud_session, zcrud_study_kernel, zcrud_export, zcrud_mindmap,
  zcrud_markdown, zcrud_study). Ne touche pas zcrud_core.
- **E-MULTI-EDIT** — entrant 12 : le seul chantier qui écrit dans `zcrud_core`/`zcrud_list`
  (capacité générique de sélection multiple + actions de lot) + son premier consommateur
  `ZMultiFlashcardEditor`. Isolé pour respecter la règle « une seule story à la fois dans core »
  et parce que sa portée dépasse l'étude (toutes les apps CRUD, DODLP inclus).

## Critères de succès

1. **Matrice de parité toute verte** : chaque ligne ❌/⚠️ des matrices §2/§3 du rapport passe à
   ✅, chacune adossée à un **test porteur** (le test échoue si la fonctionnalité casse).
2. **Parcours assemblé dans l'app example** : sélecteur de session → pile swipeable → carte
   interactive (saisie, indices, feedback) → écran de célébration — preuve visuelle
   d'intégration et **documentation vivante de migration** pour les deux apps.
3. **Vérif verte repo-wide** : `melos run generate` + `analyze` RC=0 + tests RC=0 + gates CI
   (graph acyclique, CORE OUT=0, secrets, codegen-distribution).
4. **Feu vert migration** : à la clôture des deux epics, les migrations IFFD **et** lex_douane
   peuvent démarrer **en parallèle** (sessions dédiées par app) sans perte identifiée.

## Risques

| Risque | Mitigation |
|---|---|
| Volume (16 entrants, 2 epics) → enlisement | Cycle BMAD strict, périmètre v1 fermé, hors-périmètre explicite |
| Fusion visuelle lex+IFFD → « ni l'un ni l'autre » | Variantes par **enum** (`ZRevealTransition`…), thème injecté — chaque app garde son identité |
| Nouvelles deps (`flutter_card_swiper`, `confetti`) | Confinées à zcrud_session (jamais core), versions alignées lex, gates CI |
| Cramming inclus sans référence prod (UI désactivée chez IFFD) | Mapping sur `ZWhiteExamSessionEngine` (session sans écriture SRS) vérifié à l'architecture |
| Perf de l'écran de session (swiper + markdown/LaTeX) | Esprit SM-1 : rebuilds granulaires, controllers stables, à profiler sur le parcours example |
| Contrats des ports IA figés trop tard (breaking post-migration) | Ports (`ZFlashcardAnswerEvaluationPort`, `ZFlashcardHintPort`, `ZMindmapGenerationPort`) conçus à l'architecture, revue croisée contre les impls réelles lex/IFFD (lecture seule) |

## Vision

zcrud devient la **plateforme d'étude complète** de l'écosystème : n'importe quelle future app
(ou module d'app) obtient flashcards, sessions SRS gamifiées, mindmaps et exports en assemblant
des widgets zcrud et en injectant ses adaptateurs (backend, IA, thème). IFFD et lex_douane ne
sont plus des forks divergents mais deux consommateurs du même moteur — chaque amélioration
d'étude se fait une fois, dans zcrud.
