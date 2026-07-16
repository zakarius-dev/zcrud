---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-zcrud-study-ui-2026-07-16/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md
  - _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md
  - docs/parity-study-ui-2026-07-16/rapport.md
---

# zcrud — Epic Breakdown : E-STUDY-UI + E-MULTI-EDIT

## Overview

Découpage des deux epics comblant les écarts de parité UI d'étude avant migration IFFD et
lex_douane. Granularité **par livrable** (15 stories). Toute story respecte les invariants hérités
(AD-1..32) et les décisions du spine (**AD-33..46**).

**Rappels structurants du spine — à ne jamais rouvrir en story :**
- Les **trois runtimes de session existent déjà** (`ZStudySessionEngine`, `ZLinearSessionState`,
  `ZWhiteExamSessionEngine`) : **aucun moteur n'est créé** (AD-34).
- **`ZFolderContentsOrder` + `applyOrder<T>` existent déjà** : aucune seconde entité d'ordre (AD-38).
- L'**adaptateur de rendu riche vit chez le consommateur** (`zcrud_flashcard`, `zcrud_mindmap`) —
  jamais dans `zcrud_markdown` (cycle, AD-40).
- **E-MULTI-EDIT est le seul epic autorisé à écrire dans `zcrud_core`**, une story à la fois.

## Note de processus — granularité et revue multi-agent (décision owner, 2026-07-16)

Les stories sont volontairement **grosses (par livrable)** et non découpées par AC. Cette
granularité est tenable parce que le **`bmad-code-review` de chaque story s'exécute comme un
Workflow multi-agent** dont les lentilles couvrent **toutes les facettes** de la story, en
parallèle — typiquement :

| Lentille | Ce qu'elle traque |
|---|---|
| Conformité AD | violations des invariants hérités (AD-1..32) et du spine (AD-33..46) |
| Tests porteurs | tout test tautologique (qui ne rougit pas quand la logique casse) — discipline R3 |
| A11y / RTL | `Semantics`, ≥ 48 dp, variantes directionnelles, **Reduce Motion** |
| L10n / thème | libellé ou couleur codés en dur (NFR-SU4/NFR-SU5) |
| SM-1 / perf | rebuilds non granulaires, controllers recréés, listes non virtualisées |
| Isolation deps | dépendance qui fuit hors de son satellite ; CORE OUT ≠ 0 |
| Robustesse | chemin d'exception là où un repli est exigé (AD-10) |
| Adversariale | deux lectures conformes mais incompatibles d'une même règle |

La couverture vient donc du **nombre de lentilles**, pas de la finesse du découpage. Les findings
restent triés selon la règle du projet (HIGH/MAJEUR obligatoires, MEDIUM par défaut, LOW
consignés), et l'orchestrateur **rejoue lui-même la vérif verte** avant tout `done`.

✅ **Répercuté dans `CLAUDE.md`** (section « Code-review = Workflow MULTI-AGENT à lentilles ») :
le mono-agent reste la règle pour `create-story` / `dev-story` / `retrospective` ; `code-review`
est multi-agent. **L'orchestrateur est autonome** sur le nombre et la nature des agents de revue
adversariale — il calibre sur la story réelle (surface, packages, invariants en jeu, densité
d'ACs) **sans demander l'autorisation**.

## Requirements Inventory

### Functional Requirements

- **FR-SU1** — Carte de révision adaptative (`ZFlashcardReviewCard`) ; `ZRevealTransition { flip3d, fade }`.
- **FR-SU2** — Saisie interactive notée (QCM/VF locaux, rédigée par port, « Je ne sais pas »).
- **FR-SU3** — Indices (stocké puis port ; plafond local de qualité).
- **FR-SU4** — Minuteur de réponse (`ZTimerDisplay { hidden, elapsed, countdown }`).
- **FR-SU5** — Avance post-soumission (`ZCardAdvanceBehavior { auto, manual }`, défaut par mode).
- **FR-SU6** — Pile de session swipeable (`ZSessionCardSwiper`) ; swipe = navigation seule.
- **FR-SU7** — Modes de session mappés sur les trois runtimes existants.
- **FR-SU8** — Écran de fin de session (`ZSessionSummaryView`) : trophée, stats, confetti opt-in.
- **FR-SU9** — Feedback pédagogique (qualité/temps/indices ; banques l10n surchargeables).
- **FR-SU10** — Sélecteur de session (`ZSessionModeSelector`) : Apprendre +N / À réviser / Test.
- **FR-SU11** — Streak quotidien canonique (jour civil local, reset à 1, horloge paramétrée).
- **FR-SU12** — Filtres test/examen (fonction pure + dialog).
- **FR-SU13** — UI d'examen blanc (`ZListSessionView`).
- **FR-SU14** — Liste de flashcards + filtres, recherche, tris (dont ordre manuel).
- **FR-SU15** — Flux UI de génération IA (sheet + confirmation de tags).
- **FR-SU16** — Gabarit PDF flashcards (`ZFlashcardPdfTemplate`) + LaTeX rendu.
- **FR-SU17** — Édition riche de nœud mindmap (label + contenu).
- **FR-SU18** — Port de génération de mindmap (`ZMindmapGenerationPort`).
- **FR-SU19** — Capacité moteur de sélection et d'actions de lot.
- **FR-SU20** — Multi-éditeur de flashcards (`ZMultiFlashcardEditor`).
- **FR-SU21** — Carte en lecture seule + « Dupliquer pour modifier ».

### NonFunctional Requirements

- **NFR-SU1** Pur-Flutter · **NFR-SU2** Rebuilds granulaires (SM-1) · **NFR-SU3** A11y/RTL/Reduce
  Motion · **NFR-SU4** L10n · **NFR-SU5** Thème · **NFR-SU6** Robustesse (jamais d'exception) ·
  **NFR-SU7** Isolation des dépendances (CORE OUT=0) · **NFR-SU8** Hors-ligne · **NFR-SU9**
  Performance · **NFR-SU10** Distribution (codegen committé, gates CI).

### Additional Requirements (Architecture — AD-33..46)

- Sélection amont / runtime aval ; écriture SRS par seam unique (AD-33).
- Un runtime par régime d'écriture ; **garde de mode symétrique** à ajouter sur
  `ZStudySessionEngine` (AD-34).
- Évaluation advisory, QCM/VF locaux (AD-35) · Indices à pénalité locale unique (AD-36).
- Génération : requête d'union, `modelId` opaque, résultat éphémère (AD-37).
- Ordre manuel : entité livrée ratifiée + **constructeur canonique de `sectionKey`** (AD-38).
- Suppression persistée : cascade AD-21 awaited, rapport à l'élément racine (AD-39).
- Rendu riche par slot ; adaptateur chez le consommateur (AD-40) · Label borné à la cellule (AD-41).
- `zcrud_export` pur ; port de rasterisation LaTeX ; **nouveau satellite `zcrud_export_ui`**
  (`printing ^5.15.0`) (AD-42).
- Frontière brouillon / persistance déclarée (AD-43).
- Multi-édition : sélection à propriétaire unique, actions déclarées, lot dérivé du `ZFieldSpec`
  (AD-44).
- Lecture seule : duplication explicite, état personnel jamais copié (AD-45).
- **Échelle de qualité 0..5 possédée par `ZSrsConfig`** ; `ZQualityScale` en dérive ; seau
  « mauvais » = q0-2 (AD-46).

### UX Design Requirements

Sans objet — bibliothèque de widgets sans document UX. La preuve visuelle et la documentation de
migration sont portées par le **parcours assemblé dans l'app example** (critère de succès n°2),
livré par la story 1.10.

## FR Coverage Map

| FR | Story |
|---|---|
| FR-SU1, FR-SU21 (aperçu) | 1.2 |
| FR-SU2, FR-SU3, FR-SU4, FR-SU5 | 1.3 |
| FR-SU6, FR-SU7 | 1.4 |
| FR-SU8, FR-SU9 | 1.5 |
| FR-SU10, FR-SU11, FR-SU12 | 1.6 |
| FR-SU13 | 1.7 |
| FR-SU14, FR-SU21 (duplication) | 1.8 |
| FR-SU15 | 1.9 |
| FR-SU16 | 1.11 |
| FR-SU17, FR-SU18 | 1.12 |
| FR-SU19 | 2.1 (capacité) · 2.3 (branchement sur la liste) |
| FR-SU20 | 2.2 |
| (socle transverse : AD-34/38/46) | 1.1 |
| (preuve d'intégration) | 1.10 |

**Couverture : 21/21 FR.** Chaque ligne ❌/⚠️ des matrices §2/§3 du rapport de parité est adossée
à une story (critère de succès n°1).

## Epic List

### Epic 1: E-STUDY-UI — Réviser, gérer et enrichir ses cartes
Un apprenant peut mener une session d'étude complète (choisir sa session, réviser en pile,
répondre et être noté, être félicité), gérer son dossier (rechercher, trier, ordonner, générer,
exporter en PDF) et rédiger ses cartes mentales en markdown/LaTeX. **Standalone** : ne dépend
d'aucun epic futur ; additif dans les satellites, ne touche jamais `zcrud_core`.
**FRs covered:** FR-SU1, FR-SU2, FR-SU3, FR-SU4, FR-SU5, FR-SU6, FR-SU7, FR-SU8, FR-SU9, FR-SU10,
FR-SU11, FR-SU12, FR-SU13, FR-SU14, FR-SU15, FR-SU16, FR-SU17, FR-SU18, FR-SU21 (12 stories)

### Epic 2: E-MULTI-EDIT — Gérer ses contenus par paquets
Un utilisateur peut sélectionner plusieurs éléments de n'importe quelle liste zcrud et leur
appliquer une action en lot, et relire un lot entier de flashcards avant de l'enregistrer.
**Standalone** : s'appuie sur l'Epic 1 (aperçu, génération) sans que l'Epic 1 n'ait besoin de lui.
**Seul epic autorisé à écrire dans `zcrud_core`/`zcrud_list`**, une story à la fois.
**FRs covered:** FR-SU19, FR-SU20 (3 stories)

**Séquencement** : Epic 1 en entier, puis Epic 2 — le multi-éditeur consomme la carte de révision
(1.2) et le flux de génération (1.9). La sélection multiple n'est **pas** un prérequis de la
liste 1.8 : elle s'y branche a posteriori (story 2.3).

## Epic 1: E-STUDY-UI

Doter zcrud de la couche présentation d'étude best-of-breed (session lex + saisie et gamification
IFFD) pour que la migration des deux apps se fasse sans perte fonctionnelle.

### Story 1.1: Socle — types partagés, gardes et slots

**Couvre :** AD-34, AD-38, AD-46 (socle transverse — aucun FR direct)

As a mainteneur de zcrud,
I want que les retouches des types partagés existants (échelle, garde de mode, clé de section)
soient faites une seule fois, en amont,
So that les stories livrables ne se marchent pas dessus et héritent d'invariants déjà garantis.

**Acceptance Criteria:**

**Given** `ZSrsConfig` (zcrud_flashcard/domain) ne porte aujourd'hui que `passThreshold`
**When** la story est livrée
**Then** `ZSrsConfig` porte les **bornes de l'échelle de qualité (0..5)** aux côtés de `passThreshold`
**And** `ZQualityScale` (présentation zcrud_session) **en dérive** au lieu de la redéclarer (AD-46)
**And** un test échoue si une seconde source d'échelle réapparaît.

**Given** `ZStudySessionEngine` accepte aujourd'hui n'importe quel `ZReviewMode` avec un vrai reviewer
**When** on tente de construire `(mode: cramming | list | test | whiteExam, reviewer: réel)`
**Then** la construction est **refusée** (garde symétrique de `ZLinearSessionState`, AD-34)
**And** un test porteur couvre chaque mode non-SRS refusé.

**Given** `sectionKey` n'a aucun constructeur canonique et `applyOrder` est total (divergence silencieuse)
**When** une section est composée, en lecture comme en écriture
**Then** elle passe par l'**unique constructeur canonique** du kernel (type de contenu × sous-dossier, AD-38)
**And** un test échoue si une clé est composée à la main ailleurs.

**Given** les widgets de carte et de nœud doivent accepter un rendu injectable (AD-40)
**When** aucun rendu n'est injecté
**Then** le défaut est un **texte brut thématisé**, sans dépendance de rendu riche
**And** aucun type Quill/`flutter_math_fork` n'apparaît dans une signature publique.

**Given** les gates repo-wide
**When** la story est déclarée verte
**Then** `melos run generate` + `analyze` RC=0 + tests RC=0 + graphe acyclique/CORE OUT=0.

### Story 1.2: Carte de révision adaptative

**Couvre :** FR-SU1, FR-SU21 (aperçu)

As an apprenant,
I want voir une flashcard rendue selon son type et révéler la réponse d'un geste,
So that je puisse réviser avec la même expérience que dans mon app actuelle.

**Acceptance Criteria:**

**Given** une flashcard de chacun des 6 types canoniques
**When** `ZFlashcardReviewCard` l'affiche
**Then** le rendu est adapté au type (question, choix, V/F, réponse rédigée)
**And** le contenu riche passe par le **slot de rendu injectable** (défaut texte brut, AD-40)
**And** l'adaptateur markdown/LaTeX prêt à injecter est fourni **dans `zcrud_flashcard`** (jamais dans `zcrud_markdown`).

**Given** `ZRevealTransition.flip3d` puis `ZRevealTransition.fade`
**When** l'utilisateur révèle la réponse
**Then** la transition correspond à l'enum (flip 3D **maison**, aucune dépendance `flip_card`)
**And** un test couvre chaque valeur de l'enum.

**Given** Reduce Motion actif
**When** l'utilisateur révèle la réponse
**Then** la révélation est **instantanée ou en fondu court**, jamais un flip animé (NFR-SU3).

**Given** une flashcard `isReadOnly`
**When** la carte s'ouvre
**Then** elle est en **aperçu lecture seule** : actions d'édition/suppression **absentes** (jamais grisées, AD-45).

**Given** la révision d'une carte
**When** l'utilisateur interagit
**Then** aucune couleur ni libellé n'est codé en dur (NFR-SU4/NFR-SU5)
**And** les cibles tactiles sont ≥ 48 dp avec `Semantics` explicites (NFR-SU3).

### Story 1.3: Saisie interactive notée, indices, minuteur et avance

**Couvre :** FR-SU2, FR-SU3, FR-SU4, FR-SU5

As an apprenant,
I want répondre réellement à la carte, demander un indice, et être noté,
So that je m'auto-évalue au lieu de seulement retourner la carte.

**Acceptance Criteria:**

**Given** un QCM à une ou plusieurs bonnes réponses
**When** l'utilisateur soumet sa sélection
**Then** le mode simple/multiple est **déduit du nombre de bonnes réponses**
**And** la correction visuelle s'affiche
**And** l'évaluation est **locale et exacte** — le port d'évaluation n'est **jamais** appelé (AD-35).

**Given** une réponse rédigée et un `ZFlashcardAnswerEvaluationPort` injecté
**When** l'utilisateur soumet
**Then** le port renvoie `{feedback, suggestedQuality, isCorrect?}` **advisory** : un bouton SRS est
**pré-sélectionné**, l'utilisateur valide — le port n'écrit **jamais** le SRS (AD-33/AD-35)
**And** une `suggestedQuality` hors bornes est **clampée** (AD-46).

**Given** le port d'évaluation en échec (ou absent, ou hors ligne)
**When** l'utilisateur soumet une réponse rédigée
**Then** le repli est la **qualité neutre** (seuil de passage), sans exception (AD-10/NFR-SU6/NFR-SU8)
**And** la session continue normalement.

**Given** « Je ne sais pas »
**When** l'utilisateur l'active
**Then** la soumission vaut **borne basse** de l'échelle, sans appel au port.

**Given** une carte avec un indice stocké et un `ZFlashcardHintPort` injecté
**When** l'utilisateur demande des indices
**Then** l'**indice stocké est servi en premier** ; le port n'est appelé qu'**après épuisement**,
en recevant les indices déjà montrés
**And** les indices générés restent **éphémères** (jamais persistés sur la carte, AD-36).

**Given** des indices utilisés
**When** la qualité est attribuée
**Then** le **plafond local s'applique en dernier, sur la valeur rendue** — jamais deux pénalités
cumulées, jamais aucune (AD-36)
**And** le plancher ne descend jamais sous le cran inférieur au seuil de passage.

**Given** `ZTimerDisplay` à `hidden` (défaut), `elapsed`, puis `countdown`
**When** l'utilisateur répond
**Then** le temps est **toujours mesuré**, et affiché selon l'enum uniquement.

**Given** `ZCardAdvanceBehavior` non spécifié
**When** la session est en test/examen blanc puis en apprentissage/consultation
**Then** le défaut est respectivement `auto` et `manual` (table unique, jamais redécidée par widget).

**Given** l'utilisateur rédige une réponse
**When** il tape 100 caractères
**Then** **seul le champ de saisie se reconstruit** (NFR-SU2, esprit SM-1), sans perte de focus.

### Story 1.4: Pile de session swipeable et modes

**Couvre :** FR-SU6, FR-SU7

As an apprenant,
I want parcourir mes cartes en pile et noter avec les boutons de qualité,
So that j'enchaîne mes révisions au rythme de mon app actuelle.

**Acceptance Criteria:**

**Given** une session en cours
**When** l'utilisateur swipe une carte
**Then** le swipe **navigue uniquement** — la note reste aux `ZSrsQualityButtons` (FR-SU6)
**And** aucune notation n'est déclenchée par un geste de swipe.

**Given** les six modes de session
**When** une session est construite
**Then** chaque mode est servi par son **runtime existant** (spaced/learn → `ZStudySessionEngine` ;
list/cramming → `ZLinearSessionState` ; test/whiteExam → `ZWhiteExamSessionEngine`)
**And** **aucun nouveau moteur n'est créé** (AD-34).

**Given** un mode non-SRS (list, cramming, test, whiteExam)
**When** la session s'exécute entièrement
**Then** **`reviewCard` n'est jamais atteint** — test d'invariant porteur (AD-33/AD-34).

**Given** une session en mode lot N puis en mode complet
**When** la progression avance
**Then** l'indicateur est respectivement **points colorés par qualité** et **barre segmentée**
**And** les indicateurs émotionnels apparaissent pendant le drag — **statiques si Reduce Motion** (NFR-SU3).

**Given** une pile de cartes
**When** l'utilisateur swipe
**Then** la pile **ne se reconstruit pas entièrement** (NFR-SU2)
**And** `flutter_card_swiper` reste **confiné à `zcrud_session`** (NFR-SU7).

### Story 1.5: Écran de fin de session et feedback pédagogique

**Couvre :** FR-SU8, FR-SU9

As an apprenant,
I want être félicité et voir mon bilan à la fin d'une session,
So that je reste motivé et je sais quoi réviser ensuite.

**Acceptance Criteria:**

**Given** une session terminée
**When** `ZSessionSummaryView` s'affiche
**Then** il assemble `ZSessionQualityBreakdown` + `ZStudyProgressRings` (jamais de réimplémentation)
**And** affiche les stats **cartes totales / maîtrisées / durée** (maîtrisée = q4-5, glossaire)
**And** propose « Terminer » et « Encore N dues » via **callbacks injectés**.

**Given** le confetti opt-in activé
**When** l'écran s'affiche
**Then** il part **une seule fois**
**And** `confetti` reste confiné à `zcrud_session` (NFR-SU7).

**Given** Reduce Motion actif
**When** l'écran de fin s'affiche
**Then** **aucun confetti**, et trophée/dégradé/cercles ne sont pas animés (NFR-SU3).

**Given** une soumission en mode apprentissage
**When** le feedback est calculé
**Then** le message dépend de la **qualité (4-5 / 3 / 0-2)**, du temps et des indices
**And** le palier « exceptionnel » par défaut est **< 10 s sans indice** (seuil configurable).

**Given** aucune banque de messages injectée
**When** le feedback s'affiche
**Then** les banques **FR/EN par défaut** de l'infra l10n zcrud sont utilisées (NFR-SU4)
**And** une banque injectée par l'app les **surcharge** intégralement.

### Story 1.6: Sélecteur de session, streak et filtres test/examen

**Couvre :** FR-SU10, FR-SU11, FR-SU12

As an apprenant,
I want choisir quoi réviser et voir ma flamme,
So that je démarre la bonne session en un geste et je tiens mon rythme.

**Acceptance Criteria:**

**Given** un ensemble de cartes et leur état SRS
**When** `ZSessionModeSelector` s'affiche
**Then** il propose « Apprendre +N » (jamais vues, lot **configurable, défaut 30**, anneau de
progression), « À réviser » (dues **triées par urgence**, visible seulement si > 0) et « Test »
**And** la catégorisation est en **O(1)** par carte (lookup sets).

**Given** une première répétition notée du jour
**When** le streak est calculé
**Then** il **s'incrémente**, sur le **jour civil local** (frontière minuit local), **idempotent
par jour**
**And** l'instant courant est un **paramètre** (calcul pur testable, AD-11 du spine).

**Given** un jour civil complet sans répétition notée
**When** l'utilisateur révise à nouveau
**Then** le streak est **remis à 1** (la répétition du jour compte), jamais à 0.

**Given** une session en **mode consultation**
**When** elle se termine
**Then** le streak **n'est pas mis à jour**.

**Given** un streak mis à jour
**When** la confirmation s'affiche
**Then** elle passe par le **toaster zcrud existant** (`ZToaster`), jamais un SnackBar en dur.

**Given** les filtres test/examen
**When** ils s'appliquent
**Then** la fonction est **pure** : nombre (défaut 10, **tirage aléatoire si excédent**), types,
maîtrise (**mauvais = q0-2/jamais vue**, bon = q3, maîtrisé = q4-5), tags, sources
**And** les choix QCM sont **mélangés** avant la session
**And** elle **étend/consomme `ZStudySessionSelector`** sans le dupliquer.

### Story 1.7: UI d'examen blanc

**Couvre :** FR-SU13

As an apprenant,
I want passer un examen blanc en liste et voir ma correction à la fin,
So that je m'entraîne en conditions sans polluer ma répétition espacée.

**Acceptance Criteria:**

**Given** `ZWhiteExamSessionEngine` et une file de cartes
**When** `ZListSessionView` s'affiche
**Then** chaque question offre la **saisie interactive** de la story 1.3
**And** la correction n'apparaît **qu'à la soumission finale**.

**Given** un examen blanc complet
**When** il est soumis
**Then** **aucune écriture SRS** n'a lieu (garanti par le type, test porteur)
**And** le résultat agrégé provient du moteur existant, sans recalcul parallèle.

### Story 1.8: Liste de flashcards, filtres et ordre manuel

**Couvre :** FR-SU14, FR-SU21 (duplication)

As an utilisateur,
I want retrouver, trier et organiser mes flashcards,
So that je gère mon dossier sans quitter zcrud.

**Acceptance Criteria:**

**Given** une liste de flashcards
**When** `ZFlashcardListView` s'affiche
**Then** elle est responsive via **`ZAdaptiveGrid`** (jamais une grille réécrite)
**And** la carte compacte montre question tronquée, badge type, tags, source, aperçu réponse en grille
**And** la liste est **virtualisée** (`.builder`, NFR-SU9).

**Given** une recherche « eleve » sur une carte contenant « élève »
**When** la recherche s'exécute
**Then** elle **normalise accents et espaces** et trouve la carte
**And** elle porte sur **question + réponse/choix + tags**, champs configurables.

**Given** les tris date, titre et ordre manuel
**When** l'utilisateur choisit l'ordre manuel
**Then** l'ordre provient de **`ZFolderContentsOrder` + `applyOrder<T>` existants** — **aucune
nouvelle entité, aucun `kind` persisté** (AD-38)
**And** la `sectionKey` passe par le **constructeur canonique** de la story 1.1.

**Given** un réordonnancement par drag **puis** par les boutons Monter/Descendre
**When** il est persisté
**Then** les deux gestes empruntent **la même voie d'écriture**
**And** les nouveaux éléments sont **appendés de façon stable**, les orphelins ignorés.

**Given** des filtres sous-dossier, tags (OU composables) et sources
**When** ils sont combinés
**Then** le résultat est cohérent, et les types de source viennent du **registre** (AD-4).

**Given** que la capacité de sélection multiple appartient à l'Epic 2 (FR-SU19)
**When** cette story est livrée
**Then** la liste est **pleinement fonctionnelle sans elle** (consultation, recherche, tris,
filtres, actions par item) — **aucune dépendance à un epic futur**
**And** le branchement de la sélection multiple sur la liste est livré par la **story 2.3**.

**Given** aucun port de génération injecté
**When** le point d'entrée de création s'affiche
**Then** l'option « Générer avec l'IA » est **absente** (jamais grisée)
**And** la saisie manuelle reste disponible.

**Given** une carte `isReadOnly`
**When** l'utilisateur choisit « Dupliquer pour modifier »
**Then** une **copie éphémère** est produite (sans id, `isReadOnly` remis à faux, **aucun état
personnel copié** — ni SRS ni ordre, AD-45)
**And** l'original **n'est jamais muté**.

### Story 1.9: Flux UI de génération IA

**Couvre :** FR-SU15

As an utilisateur,
I want générer un lot de flashcards depuis un document, des sujets ou un texte,
So that je crée mes cartes sans tout saisir à la main.

**Acceptance Criteria:**

**Given** le sheet de génération
**When** l'utilisateur configure sa demande
**Then** la requête canonique est `{source, count borné, typesDistribution, language,
instructions?, modelId?}` (AD-37)
**And** la `source` vient du **registre AD-4** (document+pages, sujets, texte libre, article, note,
conversation…), extensible sans toucher zcrud.

**Given** un `modelId` fourni par l'app
**When** la requête est construite et transmise
**Then** zcrud le **transporte sans jamais l'interpréter** — aucun nom de modèle, aucun catalogue
dans zcrud (AD-37).

**Given** aucune `typesDistribution` fournie
**When** la requête est construite
**Then** le défaut est une **répartition équitable pure** calculée depuis `count` × types
**And** c'est la **source unique** de ce défaut (aucune divergence).

**Given** un lot généré
**When** le port répond
**Then** les cartes sont **éphémères** (ni id ni source du backend) et **jamais persistées
silencieusement** — elles sont remises à l'appelant pour revue (AD-37/AD-43)
**And** la feuille de **confirmation de tags** est proposée.

**Given** le port de génération en échec ou hors ligne
**When** l'utilisateur lance la génération
**Then** l'échec est **typé et affiché**, sans exception ni perte de la saisie (AD-10/NFR-SU6).

### Story 1.10: Parcours assemblé dans l'app example

**Couvre :** Critère de succès n°2 (preuve d’intégration — aucun FR direct)

As a développeur d'app consommatrice,
I want un parcours de session complet et fonctionnel dans l'example,
So that je dispose d'une preuve visuelle et d'une documentation de migration exécutable.

**Acceptance Criteria:**

**Given** l'app example
**When** on lance le parcours d'étude
**Then** il enchaîne **sélecteur → pile swipeable → carte interactive (saisie, indices, feedback)
→ écran de célébration**
**And** il n'utilise que des widgets zcrud publics (aucun import de `src/`).

**Given** ce parcours
**When** on le profile (swipe, révélation, saisie)
**Then** il sert de **preuve du critère de succès n°2** et le profiling est consigné (NFR-SU9).

**Given** l'example
**When** il est compilé et testé
**Then** la résolution des dépendances et les tests restent verts (RC=0).

### Story 1.11: Gabarit PDF flashcards et satellite d'export UI

**Couvre :** FR-SU16

As an utilisateur,
I want exporter mes flashcards en PDF imprimable,
So that je révise sur papier comme aujourd'hui.

**Acceptance Criteria:**

**Given** un dossier entier ou une sélection
**When** `ZFlashcardPdfTemplate` produit le document
**Then** la mise en page typée comprend titre, numérotation, **badge d'instruction par type**,
✓/✗ colorés (QCM/VF), réponses distinguées et **explication**
**And** l'option **avec/sans réponses** est respectée
**And** la sortie est `{bytes, fileName, mimeType}` — `zcrud_export` reste **sans dépendance de
plateforme** (AD-42).

**Given** une question contenant une formule LaTeX
**When** le PDF est généré
**Then** la formule est **rendue** via le **port de rasterisation** (`flutter_math_fork` → capture
hors écran → `PdfBitmap`), avec polices chargées
**And** un test porteur (golden) couvre au moins deux formules de référence.

**Given** le gabarit
**When** il compose une page
**Then** il compose **texte + bitmap en ligne** (au-delà de `buildFromImages`, qui ne fait qu'une
image par page).

**Given** le nouveau satellite `zcrud_export_ui`
**When** il est livré
**Then** il offre **prévisualisation, impression et partage** de bytes PDF via `printing ^5.15.0`
**And** `printing`/`pdf` **ne franchissent jamais** ce package, dont l'API publique reste en
`Uint8List` (`PdfPageFormat` absorbé)
**And** il est membre du **workspace melos**, versionné et soumis aux **mêmes gates CI** (NFR-SU10)
**And** `zcrud_export` ne gagne **aucune** dépendance.

### Story 1.12: Édition riche de nœud mindmap et port de génération

**Couvre :** FR-SU17, FR-SU18

As an utilisateur de cartes mentales,
I want rédiger mes nœuds en markdown/LaTeX,
So that mes cartes portent des formules et de la mise en forme.

**Acceptance Criteria:**

**Given** `ZMindmapOutlineEditor`, dont les `TextField` sont aujourd'hui construits en dur
**When** un **slot de champ d'édition** est injecté
**Then** **label et contenu** s'éditent en markdown/LaTeX
**And** **sans injection**, le repli est l'édition texte brut actuelle (aucune régression).

**Given** l'adaptateur d'édition riche
**When** il est livré
**Then** il vit **dans `zcrud_mindmap`** (au-dessus de sa dépendance existante), **jamais** dans
`zcrud_markdown` — un test de graphe échoue si l'arête inverse apparaît (cycle, AD-40).

**Given** un label riche dans le graphe
**When** il s'affiche
**Then** il est **borné à la cellule de taille fixe**, **tronqué/clippé proprement**, sans mesure
intrinsèque ni re-layout (AD-41)
**And** le mode compact conserve le label brut
**And** le rendu riche **complet** reste garanti dans l'outline et la liste a11y.

**Given** `ZMindmapGenerationPort`
**When** il est défini dans `zcrud_study`
**Then** son contrat est **aligné sur `ZFlashcardGenerationPort`** (AD-37)
**And** aucune implémentation n'est fournie (app+backend-side, hors périmètre).

## Epic 2: E-MULTI-EDIT

Doter le moteur CRUD d'une capacité générique de sélection multiple et d'actions de lot, dont les
flashcards sont le premier consommateur. **Seul epic autorisé à écrire dans `zcrud_core`** — une
story à la fois. Séquence : 2.1 (capacité moteur) → 2.2 (multi-éditeur) → 2.3 (branchement sur la
liste de 1.8).

### Story 2.1: Capacité moteur de sélection et d'actions de lot

**Couvre :** FR-SU19

As a développeur d'app CRUD,
I want sélectionner plusieurs éléments et leur appliquer une action en lot,
So that mes utilisateurs gèrent leurs données par paquets, sur n'importe quel modèle.

**Acceptance Criteria:**

**Given** une liste zcrud
**When** l'utilisateur active la sélection multiple (long-press / cases à cocher)
**Then** « tout sélectionner » et un **badge compteur** sont disponibles
**And** l'état de sélection a **un seul propriétaire** : un contrôleur pur (`Listenable`) détenu
par la liste et **passé** aux barres/menus — jamais redéclaré par un widget d'action (AD-44).

**Given** des actions de lot
**When** elles sont configurées
**Then** elles sont **déclarées en données** (patron `ZItemActionsMenu` : action **absente** si non
fournie), avec `delete`/`move` intégrées et un **slot d'actions personnalisées** (AD-44).

**Given** une suppression par lot
**When** elle s'exécute
**Then** elle passe par la **cascade déclarative AD-21, awaited**
**And** chaque élément racine est une **unité de rapport** (réussi/échoué + cause) — jamais de lot
silencieusement partiel (AD-39/AD-10).

**Given** « Déplacer »
**When** l'utilisateur choisit une destination
**Then** l'action réaffecte le **champ de rattachement déclaré par le modèle** (jamais un
`folderId` codé en dur)
**And** la destination vient d'un **sélecteur injecté** par l'app.

**Given** une édition de champ commun
**When** l'utilisateur applique une valeur à N éléments
**Then** l'éditeur et les validateurs sont **dérivés du `ZFieldSpec`** — les **mêmes** que le
formulaire unitaire, jamais une seconde implémentation (AD-44)
**And** l'application est **par élément**, avec rapport d'échecs.

**Given** cette story touche `zcrud_core`
**When** elle est en cours
**Then** **aucune autre story n'écrit dans `zcrud_core`** en parallèle
**And** `melos run analyze` **et** `melos run verify` **repo-wide** sont verts avant `done`.

### Story 2.2: Multi-éditeur de flashcards

**Couvre :** FR-SU20

As an utilisateur,
I want éditer un lot de flashcards (souvent issues de l'IA) avant de les enregistrer,
So that je relis et corrige tout d'un coup, sans rien persister par accident.

**Acceptance Criteria:**

**Given** un lot de flashcards
**When** `ZMultiFlashcardEditor` s'affiche
**Then** il est en **split-view** sur grand écran (sidebar liste + formulaire) et en **navigation
liste ↔ formulaire** sur mobile (réutilise l'infra responsive existante).

**Given** le régime **brouillon** (AD-43)
**When** l'utilisateur édite, ajoute, supprime ou applique une action groupée
**Then** tout mute une **liste de travail en mémoire** et **rien n'est persisté**
**And** la surface **déclare** son régime (jamais implicite)
**And** aucune cascade de suppression n'est déclenchée sur une carte jamais persistée (AD-39).

**Given** des modifications non enregistrées
**When** l'utilisateur quitte
**Then** le garde-fou **`ZDiscardChangesGuard` existant** intervient (jamais une garde réécrite).

**Given** la sauvegarde finale groupée
**When** l'utilisateur la déclenche
**Then** c'est le **seul** franchissement de la frontière de persistance, et la **liste complète**
est remise à l'appelant.

**Given** le flux de génération IA (story 1.9)
**When** un lot est généré
**Then** les résultats sont **ajoutés à la liste de travail** pour revue (jamais persistés).

**Given** l'aperçu d'une carte
**When** l'utilisateur le demande
**Then** il réutilise **`ZFlashcardReviewCard`** (story 1.2), jamais un rendu parallèle.

**Given** le panneau « appliquer à la sélection » (tags, dossier, type)
**When** il s'exécute
**Then** il s'appuie sur la capacité de la story 2.1, sans la dupliquer.

### Story 2.3: Branchement de la sélection multiple sur la liste de flashcards

**Couvre :** FR-SU19 (branchement sur la liste)

As an utilisateur,
I want sélectionner plusieurs flashcards directement dans ma liste,
So that je les supprime, déplace ou retague sans ouvrir un éditeur.

**Acceptance Criteria:**

**Given** `ZFlashcardListView` (story 1.8) et la capacité moteur (story 2.1)
**When** l'utilisateur active la sélection multiple depuis la liste
**Then** la liste **consomme** le contrôleur de sélection de 2.1 — elle n'en redéclare aucun
(propriétaire unique, AD-44)
**And** les actions `delete`/`move` et le slot d'actions personnalisées y sont disponibles.

**Given** une suppression de flashcards par lot depuis la liste
**When** elle s'exécute
**Then** elle passe par la **cascade AD-21 awaited** avec rapport par élément racine (AD-39) —
l'état SRS associé est purgé, aucun orphelin (dette lex corrigée).

**Given** cette story
**When** elle est livrée
**Then** la liste reste **fonctionnelle sans sélection** si la capacité n'est pas câblée
(dégradation propre, aucune régression de 1.8).
