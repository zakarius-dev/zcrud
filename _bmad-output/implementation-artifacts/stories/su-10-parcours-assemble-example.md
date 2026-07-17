# Story 1.10 : Parcours d'étude assemblé dans l'app example

Status: review

Clé sprint-status : `su-10-parcours-assemble-example`

**Ligne du sprint-status (contrat, mot pour mot)** :
`[M][A — DERNIÈRE du flux A ; dépend su-2..su-6] Critère de succès n°2 : sélecteur→swiper→carte interactive→célébration dans example/ ; widgets publics seuls ; profiling NFR-SU9`

> **Frontière (rappel du contrat)** : su-10 = **parcours assemblé** dans `example/` à partir de
> **widgets PUBLICS** (barrels) + **adaptateurs fakes** app-side. **PAS** de multi-édition (epic ME) ·
> **PAS** de mindmap (su-12) · **PAS** d'export PDF (su-11) · **PAS** d'impl IA réelle (fakes
> déterministes seulement). L'example **CÂBLE** les acquis su-1..su-9 livrés/verts ; il ne les
> **réécrit pas** et ne corrige aucun package sous `packages/`.

## Story

As a **développeur d'app consommatrice** (IFFD / lex_douane),
I want **un parcours de session d'étude complet et fonctionnel dans l'app example — sélecteur →
pile swipeable → carte interactive (saisie, indices, feedback) → écran de célébration**,
so that **je dispose d'une preuve visuelle d'intégration ET d'une documentation vivante de migration
exécutable, prouvant que les widgets zcrud publics s'assemblent en un vrai parcours sans régression
de SM-1**.

## Acceptance Criteria

**AC1 — Le parcours enchaîne les 4 étapes avec des widgets PUBLICS seuls.**
Given l'app example, When on lance le parcours d'étude, Then il enchaîne **`ZSessionModeSelector`
→ `ZSessionCardSwiper` → carte interactive (`ZFlashcardReviewCard` + `ZFlashcardAnswerInput`) →
`ZSessionSummaryView`** et il n'importe **QUE des barrels** `package:zcrud_*/zcrud_*.dart` — **aucun
import `/src/`** dans `example/lib` ni `example/test`. (Source de succès n°2, epics 1.10 AC1.)

**AC2 — Le runtime est choisi par le mode (AD-34), pas paramétré.**
Given le mode retourné par le sélecteur (`onStart(kind, queue)`), When le parcours démarre, Then
l'example **sélectionne le runtime EXISTANT** selon le régime d'écriture : `spaced`/`learn` →
`ZStudySessionEngine` (seul à recevoir un `ZSessionReviewer`) ; `list`/`cramming` →
`ZLinearSessionState` ; `test`/`whiteExam` → `ZWhiteExamSessionEngine`. Aucun 4ᵉ runtime n'est créé ;
aucun `ZSessionReviewer` no-op n'est fabriqué pour forcer une écriture SRS depuis un mode non-SRS.

**AC3 — L'example fournit ses adaptateurs (AD-15) : 3 ports fakes déterministes + store + thème + l10n.**
Given l'architecture ports & adapters (AD-15), When le parcours a besoin d'IA ou de persistance,
Then l'example **injecte des fakes app-side déterministes** — `ZFlashcardGenerationPort`,
`ZFlashcardHintPort`, `ZFlashcardAnswerEvaluationPort` (aucune IA réelle) — un **store offline en
mémoire**, et un **thème + l10n** via `ZcrudScope`. Chaque injection est **commentée comme un guide
de migration** (quel port, ce que l'app réelle y branchera).

**AC4 — L'example est un hôte CORRECT (pas le hôte-jouet des tests).**
Given les frontières inter-stories qui se rencontrent pour de vrai, When la file rétrécit, qu'une
carte change pendant un port en vol, ou que `onStackEnd` est émis, Then l'example gère : (a) la
**`key` du swiper dérivée de l'identité de la file** (le HIGH de su-4, D1) ; (b) **deux listes
parallèles** — la `List<ZSessionItem>` (IDs seuls) et le `Map<String, ZFlashcard>` — avec
**association réponse↔carte par `flashcardId`, jamais par index/géométrie** (su-4 D2, su-7) ; (c) une
**resynchronisation `didUpdateWidget`** de tout état d'hôte porté par un `StatefulWidget` (su-8) ; (d)
un **latch one-shot sur `onStackEnd`** de sorte que l'écran de célébration soit poussé **exactement
une fois**, y compris quand un mode reboucle (`cramming` requeue) (su-4 D8, su-5).

**AC5 — Robustesse AD-10 : le parcours dégrade proprement, jamais d'exception ni de cul-de-sac.**
Given des conditions dégradées, When la session est **vide** (0 carte), n'a **qu'1 carte**, est
**abandonnée en cours**, ou qu'un **port fake configuré en échec** répond, Then le parcours **ne lève
aucune exception**, n'aboutit **jamais à un état sans issue** (ni écran vide bloquant, ni fin non
atteignable), la **saisie n'est pas perdue** sur échec de port, et l'échec est **typé** (repli AD-10 /
AD-35), pas silencieux.

**AC6 — Preuve SM-1 de bout en bout sur le PARCOURS RÉEL (NFR-SU9).**
Given le parcours assemblé (chemin réel, contenu réel — pas un contenu par défaut), When on tape
**100 caractères** dans le champ de saisie de la carte interactive, Then **seul le champ courant se
reconstruit** (comptage de rebuilds via `RebuildLog`), **zéro perte de focus**, **aucun `Form` global**
et **aucun `setState` à l'échelle du parcours** ; les cartes non-courantes / le sélecteur / le swiper
**ne se reconstruisent pas**. Le comptage est **assé** dans un test widget (pas une opinion).

**AC7 — Fluidité du swiper (NFR-SU9) prouvée par comportement.**
Given la pile swipeable, When on avance dans la file (swipe / progression), Then **aucune carte
hors-écran n'est reconstruite** à chaque avance (cache de cartes), et la progression atteint
`onStackEnd` sans reconstruire tout le parcours. Un test widget compte les rebuilds sur l'avance
réelle.

**AC8 — Profiling consigné (NFR-SU9).**
Given le parcours, When il est profilé (swipe, révélation, saisie), Then une **note de profiling** est
consignée dans la story (compteurs de rebuilds mesurés AC6/AC7 + verdict SM-1) — preuve du critère de
succès n°2. NFR-SU9 étant adjectival, les **compteurs de rebuilds** sont la borne concrète.

**AC9 — Documentation vivante de migration.**
Given l'example comme guide pour IFFD/lex_douane, When un développeur le lit, Then le parcours est
**lisible comme un guide** : commentaires explicites sur **chaque injection d'adaptateur** (les 3 ports,
le store, le thème, la l10n) et **le choix du runtime par mode** (AD-34), de sorte qu'un migrateur
sache exactement quoi substituer par ses impls réelles.

**AC10 — Résolution des deps + vérif verte (RC=0), frontière EX rectifiée proprement.**
Given l'example modifié, When il est compilé et testé, Then `dart pub get` (lock **propre**
`example/pubspec.lock`, JAMAIS le lock racine des 14), `flutter analyze` et `flutter test` **DEPUIS
`example/`** restent **verts (RC=0)** ; `melos run analyze` et `melos run verify` **repo-wide** restent
verts ; `melos list` reste **14** (l'example hors glob). La frontière `boundary_deps_test.dart` est
**rectifiée** : `zcrud_flashcard` **quitte** l'ensemble interdit (il est désormais légitimement
consommé par le parcours) ; `zcrud_mindmap` **reste interdit** (su-12, hors périmètre).

## Tasks / Subtasks

- [x] **T1 — Câbler les dépendances du parcours dans `example/pubspec.yaml` (AC1, AC10).**
  - [ ] Ajouter en `dependencies` **et** en `dependency_overrides` (voie standalone path↔hosted,
        exactement comme les satellites existants) : `zcrud_session`, `zcrud_flashcard`, `zcrud_study`
        (`zcrud_study_kernel` est déjà en override transitif — le **promouvoir en dépendance directe**
        si l'app le référence explicitement, cf. `depend_on_referenced_packages`).
  - [ ] Mettre à jour le commentaire d'en-tête du `pubspec.yaml` : le parcours d'étude (su-10) est
        désormais AUTORISÉ à consommer flashcard/session/study ; **`zcrud_mindmap` reste interdit**.
  - [ ] `dart pub get` **depuis `example/`** → lock propre `example/pubspec.lock` (jamais le lock racine).
        Vérifier `melos list` == 14.

- [x] **T2 — Rectifier `example/test/boundary_deps_test.dart` (AC10).**
  - [ ] Retirer `zcrud_flashcard` de la liste `forbidden` ; **conserver** `zcrud_mindmap`.
  - [ ] Ajouter une assertion POSITIVE : `zcrud_session`, `zcrud_flashcard`, `zcrud_study` **sont
        présents** en dépendances (le parcours en dépend réellement) — sinon un futur nettoyage de
        pubspec casserait le parcours sans rougir.
  - [ ] ⚠️ Ce n'est **PAS** « taire un défaut » : la frontière EX-3 disait « flashcard interdit tant
        que non consommé » ; su-10 le consomme légitimement. Documenter ce basculement de frontière
        dans le commentaire du test (motif, story qui l'autorise).

- [x] **T3 — Écran de parcours `study_session_demo_screen.dart` (AC1, AC2, AC4, AC9).**
  - [ ] `StatefulWidget` hôte qui monte le sélecteur puis, sur `onStart(kind, queue)`, pousse la
        session avec le **runtime choisi par le mode** (AD-34). Documenter le mapping mode→runtime.
  - [ ] Étape sélecteur : `ZSessionModeSelector(cards, srsById, at, streak, onStart, onOpenFilters?)`.
  - [ ] Étape swiper : `ZSessionCardSwiper(queue: List<ZSessionItem>, cardBuilder, passThreshold,
        onStackEnd, onIndexChanged?, qualityOf?)`. **`key` du sous-arbre dérivée de l'identité de la
        file** (leçon su-4 D1) ; `cardBuilder(index)` **résout la carte par `flashcardId`** dans le
        `Map<String, ZFlashcard>` (deux listes parallèles, su-7).
  - [ ] Étape carte interactive dans `cardBuilder` : `ZFlashcardReviewCard(card, onRevealChanged)` +
        `ZFlashcardAnswerInput(card, mode, srsConfig, evaluationPort, hintPort, hintPolicy, onSubmitted)`
        — brancher `onSubmitted` (fait `ZFlashcardSubmission`) au runtime (SRS via le seam pour
        `spaced`/`learn` uniquement ; sinon avance linéaire / scoring examen).
  - [ ] Étape célébration : sur `onStackEnd` (**latch one-shot**, jamais ré-inventé), pousser
        `ZSessionSummaryView(result, duration, config, onFinish, dueRemaining?, celebration, ...)`.
  - [ ] Chemin RÉEL : exercer le vrai contenu (markdown/type), **pas un contenu par défaut** (leçon
        su-2 : 9 taps verts sur une fonctionnalité morte sous markdown).

- [x] **T4 — Adaptateurs fakes app-side (AC3, AC5, AC9).**
  - [ ] `fakes/fake_flashcard_generation_port.dart` : implémente `ZFlashcardGenerationPort`
        (`generateFlashcards → Future<ZResult<List<ZFlashcard>>>`), **déterministe**, **configurable en
        échec** (retourne un `ZResult` d'échec typé, pas une exception).
  - [ ] `fakes/fake_flashcard_hint_port.dart` : `ZFlashcardHintPort.generateHint` déterministe,
        anti-répétition (reçoit les indices déjà montrés), configurable en échec.
  - [ ] `fakes/fake_answer_evaluation_port.dart` : `ZFlashcardAnswerEvaluationPort` **advisory** (AD-35)
        — pré-sélectionne un bouton SRS, n'écrit jamais ; sortie typée `{feedback, suggestedQuality,
        isCorrect?}` ; `errorKind` typé en échec. **QCM/VF ne passent PAS par ce port** (évalués
        localement, AD-35) — le fake ne sert que la voie rédigée.
  - [ ] `fakes/in_memory_study_store.dart` : store offline en mémoire (impl du port `ZStudyRepository`
        ou seed de cartes + `Map<String, ZRepetitionInfo>` SRS), source d'un jeu de flashcards de démo
        (mix de types : QCM, VF, rédigée, avec au moins une **formule/markdown** pour exercer le chemin
        réel).
  - [ ] Chaque fake porte une dartdoc « **Migration** : l'app réelle branche ici son routeur IA /
        Firestore ». **La prose doit être vraie sur disque** (leçon su-1..su-9 : « la prose ment »).

- [x] **T5 — Intégrer le parcours à l'accueil (`home_screen.dart` / registry) (AC1).**
  - [ ] Ajouter une entrée « Parcours d'étude » à `HomeScreen` ouvrant `StudySessionDemoScreen`.
        Réutiliser la coquille existante (`ZcrudScope` racine, thème `ZcrudTheme`, l10n fr/en, bascules
        thème/langue/RTL — AD-13). **Ne pas dupliquer** la coquille ni le `ZcrudScope`.

- [x] **T6 — Test SM-1 de bout en bout sur le parcours réel (AC6, AC8).**
  - [ ] `example/test/study_parcours_sm1_test.dart` sur le patron de
        `example/test/sm1_granular_rebuild_test.dart` + `support/rebuild_indicator.dart` (`RebuildLog`).
  - [ ] Monter le parcours jusqu'à la **carte interactive**, taper **100 caractères** dans
        `ZFlashcardAnswerInput` ; assérer : `countOf(champ courant)` augmente d'exactement N, les
        compteurs des **autres** widgets (swiper, autres cartes, sélecteur) **inchangés**,
        `find.byType(Form) → findsNothing`, **focus conservé** (l'`EditableText` reste focalisé).
  - [ ] **Injection R3 (rougir par le COMPORTEMENT)** : un espion **prouvé captant AVANT** l'assertion ;
        si la granularité SM-1 casse (rebuild global), le test **rougit** — pas un corpus qui rend
        l'assertion vraie quel que soit le code.

- [x] **T7 — Test fluidité swiper + robustesse AD-10 (AC5, AC7).**
  - [ ] `example/test/study_parcours_swiper_test.dart` : avancer dans la file ; assérer **aucun rebuild
        de carte hors-écran** (compteur), progression atteignant `onStackEnd`.
  - [ ] Cas robustesse (balayer le MOTIF, pas un cas) : **file vide**, **1 carte**, **abandon en cours**,
        **port fake en échec**, **file qui rétrécit**. Chaque cas : assérer **le NOMBRE / l'état
        d'issue** (pas seulement « aucune exception ») — une garde qui n'assère que `takeException()
        isNull` ne vérifie pas la justesse (leçon su-4/su-7).
  - [ ] `onStackEnd` **une seule fois** même en rebouclant (`cramming`) : compteur de push de
        `ZSessionSummaryView` == 1 ; retirer le latch ⇒ **ROUGE**.

- [x] **T8 — Garde anti-`/src/` (AC1).**
  - [ ] `example/test/study_parcours_public_surface_test.dart` (ou étendre `boundary_deps_test.dart`) :
        grep sur `example/lib/**` — **aucun import contenant `/src/`** parmi les fichiers du parcours.
        ⚠️ Si un widget nécessaire n'est **pas exporté** par son barrel → **signaler un DÉFAUT DE
        BARREL** (à corriger dans le package concerné), **jamais** contourner par un import `src/`.

- [x] **T9 — Vérif verte + profiling consigné (AC8, AC10).**
  - [ ] `flutter analyze` + `flutter test` **DEPUIS `example/`** RC=0 ; `melos run analyze` + `melos run
        verify` **repo-wide** RC=0 ; `melos list` == 14.
  - [ ] Consigner la note de profiling (compteurs mesurés T6/T7 + verdict SM-1) dans la section
        **Dev Agent Record**.

## Dev Notes

### Surface publique assemblée — vérifiée exportée sur disque (aucun défaut de barrel)

Les 8 symboles du parcours + les 3 ports sont **tous exportés** par leur barrel (greps joués sur disque) :

| Symbole assemblé | Barrel | Export vérifié |
|---|---|---|
| `ZSessionModeSelector` | `zcrud_session` | `z_session_mode_selector.dart` (l.99) |
| `ZSessionCardSwiper` | `zcrud_session` | `z_session_card_swiper.dart` (l.85, confinement NFR-SU7) |
| `ZFlashcardAnswerInput` | `zcrud_session` | `z_flashcard_answer_input.dart` (l.64) |
| `ZSessionSummaryView` | `zcrud_session` | `z_session_summary_view.dart` (l.112) |
| `ZFlashcardReviewCard` | `zcrud_flashcard` | `z_flashcard_review_card.dart` (l.233) |
| `ZStudySessionEngine` / `ZLinearSessionState` / `ZWhiteExamSessionEngine` | `zcrud_session` | l.39 / l.25 / l.40 |
| `ZFlashcardGenerationPort` | `zcrud_study` | `z_flashcard_generation_port.dart` (l.19) |
| `ZFlashcardHintPort` | `zcrud_flashcard` | `z_flashcard_hint_port.dart` (l.183) |
| `ZFlashcardAnswerEvaluationPort` | `zcrud_flashcard` | `z_flashcard_answer_evaluation_port.dart` (l.158) |

⇒ **Aucun défaut de barrel identifié en amont** ; le test T8 est la garde qui le prouve à l'exécution.
Si le dev découvre qu'un symbole utile n'est **pas** exporté, c'est un **défaut de barrel à corriger
dans le package**, pas un import `src/`.

### Signatures constructeurs (vérifiées sur disque)

- `ZSessionModeSelector({required cards: Iterable<ZFlashcard>, required srsById: Map<String,
  ZRepetitionInfo>, required at: DateTime, required streak: ZStudyStreak, required onStart:
  void Function(ZSessionModeKind kind, List<ZFlashcard> queue), int batchSize, VoidCallback?
  onOpenFilters})`.
- `ZSessionCardSwiper({required queue: List<ZSessionItem>, required cardBuilder: ZSessionCardBuilder,
  required passThreshold: int, ValueChanged<int>? onIndexChanged, VoidCallback? onStackEnd,
  WidgetBuilder? emptyBuilder, ZSessionProgressStyle progressStyle, ZSessionQualityAtIndex? qualityOf,
  Duration swipeDuration})`. `onStackEnd` émis par `_handleEnd()` avec **latch one-shot `_stackEnded`**
  (l.360-364) — l'hôte ne réinvente pas ce latch.
- `ZSessionItem({required flashcardId: String, required folderId: String, String? typeKey})` — **IDs
  seuls** ⇒ l'hôte tient un `Map<String, ZFlashcard>` en parallèle (su-7).
- `ZFlashcardReviewCard({required card: ZFlashcard, ZRevealTransition revealTransition,
  ZFlashcardContentBuilder? contentBuilder, ValueChanged<bool>? onRevealChanged, VoidCallback? onEdit,
  onDelete})`.
- `ZFlashcardAnswerInput({required card: ZFlashcard, required mode: ZReviewMode, ZSrsConfig srsConfig,
  ZFlashcardContentBuilder? contentBuilder, ValueChanged<ZFlashcardSubmission>? onSubmitted,
  ZFlashcardAnswerEvaluationPort? evaluationPort, ZFlashcardHintPort? hintPort, ZHintPenaltyPolicy
  hintPolicy, ZTimerDisplay timerDisplay})`. **N'écrit rien** ; ÉMET `ZFlashcardSubmission` via
  `onSubmitted` (l.38).
- `ZSessionSummaryView({required result: ZStudySessionResult, required duration: Duration, required
  config: ZSrsConfig, required onFinish: VoidCallback, int dueRemaining, VoidCallback? onContinue,
  ZSummaryCelebration celebration, int? masteredThreshold, String? feedbackKey, ZFeedbackBank?
  feedbackBank})`. Célébration **latch one-shot** interne (`_maybeCelebrate`).
- `ZStudySessionEngine({required queue: List<ZSessionItem>, required reviewer: ZSessionReviewer,
  required passThreshold: int, ZReviewMode mode = spaced})` — **`assert(mode == spaced || mode ==
  learn)`** (AD-34, l.142-145). L'hôte **ne construit ce moteur QUE pour `spaced`/`learn`**.

### État réel de `example/` sur disque (l'ajout s'INTÈGRE, ne duplique pas)

`example/` est une app STANDALONE mature (EX-1..EX-3) : `pubspec.yaml` (isolé du workspace,
`publish_to: none`, hors glob `packages/**` ⇒ `melos list` == 14, lock propre `example/pubspec.lock`),
coquille `app.dart` (`MaterialApp` + `ZcrudScope` racine, `ZcrudTheme(gapM:10, gapL:20)`, l10n fr/en,
bascules thème/langue/**RTL**), `home_screen.dart` (démos par domaine), `demos/*`, `support/
rebuild_indicator.dart` (`RebuildLog`), `support/demo_file_picker.dart`, 15 tests. Le parcours réutilise
cette coquille — **il n'ajoute PAS** un second `ZcrudScope` ni une seconde `MaterialApp`.

⚠️ **Écart tranché (finding disque, load-bearing)** : `example/pubspec.yaml` **ne dépend PAS** de
`zcrud_session` / `zcrud_flashcard` / `zcrud_study` (grep `RC=1`), et `example/test/
boundary_deps_test.dart` **INTERDIT `zcrud_flashcard`** (l.24-26, avec `zcrud_mindmap`). Le parcours
**exige** ces 3 packages ⇒ T1 les ajoute et T2 **retire `zcrud_flashcard` de l'interdit** (frontière
EX basculée par su-10, `zcrud_mindmap` conservé interdit). Décision non-interactive **conservatrice** :
on ne touche QUE le strict nécessaire du `forbidden` (retrait de `zcrud_flashcard`), on **garde**
`zcrud_mindmap`, et on documente le motif dans le test.

### Hôte CORRECT — les 4 pièges d'intégration démasqués sur su-4/su-7/su-8

L'example est le **POINT D'INTÉGRATION** : c'est là que les frontières se rencontrent pour de vrai. Il
doit être un hôte **correct**, jamais le hôte-jouet des tests.

1. **File qui rétrécit → `key` d'identité de file** (su-4 D1/D8) : `CardSwiper` porte son propre index
   (`_undoableIndex`, posé en `initState` seul). Sans `key` dérivée de la file, l'`Element` est réutilisé
   au changement de file et **l'index survit à la file qu'il n'indexe plus** ⇒ `RangeError` sur le chemin
   NOMINAL. `ZSessionCardSwiper` pose déjà `key: ValueKey<int>(_queueGeneration)` en interne ; l'**hôte**
   ne doit pas casser cette invariance en recréant la file à chaque frame — file **stable**, régénérée
   seulement au changement réel.
2. **Deux listes parallèles** (su-7) : `ZSessionItem` ne porte que des IDs ⇒ l'hôte tient
   `List<ZSessionItem>` **et** `Map<String, ZFlashcard>`. Le `cardBuilder` **résout par `flashcardId`**,
   jamais par index/`.last`/géométrie (su-4 D2 : viser par identité, pas par ordre de peinture). Risque
   de **désynchronisation** des deux listes → à couvrir par un test.
3. **`didUpdateWidget` de l'hôte** (su-8) : tout état porté par un `StatefulWidget` d'hôte (queue en
   cours, controller de saisie, résultat partiel) doit **resynchroniser** en `didUpdateWidget` — le HIGH
   su-8 n'était pas une faute de clé mais un **merge/resync manquant** (« queue périmée »). **Carte qui
   change pendant un port en vol** : le résultat du fake (async) doit être **associé à la carte qui l'a
   demandé** (garde par `flashcardId`), jamais appliqué à la carte courante devenue autre.
4. **`onStackEnd` latch one-shot** (su-4 l.360, su-5) : `onEnd` peut être ré-entrant / fire **même en
   bouclant**. L'écran de célébration est poussé **exactement une fois** ; l'hôte **consomme** le latch,
   ne le réinvente pas.

### Runtime par mode (AD-34) — aucune porte dérobée SRS

Mapping **strict** (spine AD-34) : `spaced`/`learn` → `ZStudySessionEngine` (reçoit `ZSessionReviewer`,
seule voie d'écriture SRS) ; `list`/`cramming` → `ZLinearSessionState` (réducteurs `advanceLinear`/
`requeueCramming`, aucune écriture SRS) ; `test`/`whiteExam` → `ZWhiteExamSessionEngine`
(`ZExamScoringPort`, aucune écriture SRS). L'hôte **ne fabrique aucun `ZSessionReviewer` no-op** pour un
mode non-SRS (ce serait la porte dérobée fermée par AD-34). Le `mode` passé à `ZStudySessionEngine` est
gardé par `assert(spaced||learn)`.

### Ports fakes — advisory, jamais notant (AD-35), indices (AD-36)

- **Évaluation** (AD-35) : **advisory strict** — pré-sélectionne un bouton SRS, l'utilisateur valide ;
  le port **n'écrit jamais** le SRS. **QCM/VF évalués LOCALEMENT** (déterministe, hors ligne), **jamais**
  par le port. Le fake ne sert que la voie **rédigée**. Sortie typée + `errorKind` en échec.
- **Indices** (AD-36) : indice **stocké servi en premier** ; le port n'est appelé qu'**après épuisement**
  du stock, en recevant les indices déjà montrés (anti-répétition) ; plafond local unique. Le fake
  respecte ce contrat.
- **Génération** : `Future<ZResult<List<ZFlashcard>>>` — déterministe, **configurable en échec** (retourne
  un `ZResult` d'échec typé, **jamais** une exception ; AD-10).

### SM-1 / NFR-SU9 — preuve par COMPTAGE de rebuilds sur le parcours réel

Patron de référence : `example/test/sm1_granular_rebuild_test.dart` + `support/rebuild_indicator.dart`
(`RebuildLog`, `countOf(name)`). Reproduire sur le **parcours réel** (pas le formulaire d'édition) :
monter jusqu'à la carte interactive, **taper 100 caractères** dans `ZFlashcardAnswerInput`, assérer que
**seul le champ courant** grimpe et que **swiper / autres cartes / sélecteur** restent à leur baseline,
`find.byType(Form) → findsNothing`, **focus conservé**. AD-2 interdit `setState` à l'échelle du
parcours. Fluidité swiper (AC7) : compter les rebuilds à l'**avance** — **aucune carte hors-écran
reconstruite** (cache de cartes `_cardCache`). NFR-SU9 étant adjectival (rubric PRD `low`), **les
compteurs sont la borne concrète** ; consigner la mesure (AC8).

### Discipline de réalité (tests porteurs — leçons su-1..su-9)

- **Présence ≠ association** : actionner un contrôle réel, viser par **identité** (`flashcardId` / clé),
  jamais par géométrie ; retirer tout `warnIfMissed: false` qui masque une cible ratée (su-4 D2).
- **Un test ne doit pas observer qu'UN canal** : distinguer par carte (`(flashcardId, bool)`), sinon un
  tap atteignant un `InkWell` réel de la carte de fond laisse le test vert alors que la carte de devant
  est morte (HIGH su-2 rejoué sous un test aveugle, su-4 D2).
- **Une garde qui n'assère que « aucune exception » ne vérifie pas la justesse** : assérer le **NOMBRE /
  l'état d'issue** (su-4 D1, su-7 D1).
- **La prose ment** : toute dartdoc de guide de migration doit être **vraie sur disque**.
- **Test infalsifiable** : espion **prouvé captant AVANT** l'assertion ; injection R3 rougissant par le
  **comportement** (retirer le latch ⇒ ROUGE ; casser la granularité SM-1 ⇒ ROUGE).
- **Exercer le CHEMIN RÉEL** : contenu réel (markdown/type varié), pas un contenu par défaut (su-2 : 9
  taps verts, fonctionnalité morte sous markdown).
- 🚫 **On ne modifie JAMAIS un test pour taire un défaut réel** (le retrait `zcrud_flashcard` du
  `forbidden` T2 n'est PAS cela — c'est un basculement de frontière assumé et documenté).

### Pièges shell (AVÉRÉS)

`grep -q` sans pipe (`grep … | head; echo $?` rend le RC de `head`) ; `$` métacaractère BRE → `grep -qF` ;
**`flutter test` DEPUIS `example/`** (jamais `melos run test` — parallélise/se bloque). 🚫 **Jamais
`git checkout`** (su-1..su-9 **non committés** — un checkout les détruit). 🚫 **Jamais `dart format`**.

### Project Structure Notes

- Nouveaux fichiers (proposés) : `example/lib/demos/study_session_demo_screen.dart`,
  `example/lib/demos/fakes/{fake_flashcard_generation_port,fake_flashcard_hint_port,
  fake_answer_evaluation_port,in_memory_study_store}.dart`, tests
  `example/test/{study_parcours_sm1_test,study_parcours_swiper_test,study_parcours_public_surface_test}.dart`.
- Modifiés : `example/pubspec.yaml`, `example/lib/home_screen.dart` (entrée d'accueil),
  `example/test/boundary_deps_test.dart`. **Aucun** package sous `packages/` modifié (l'example est
  CONSOMMATEUR ; toute correction requise dans un package = défaut à signaler, hors périmètre su-10 sauf
  défaut de barrel bloquant — auquel cas remonter avant de contourner).
- Invariants : `melos list` == 14 ; lock propre `example/pubspec.lock` ; `zcrud_core` reste
  Syncfusion/Firebase/Maps-free (SM-5) ; RTL/a11y ≥ 48 dp / `Semantics` / l10n / thème injectés (AD-13).

### References

- [Source: epics.md#Story 1.10] (`_bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md` l.507-529)
- [Source: brief.md#Critères de succès n°2] (`_bmad-output/planning-artifacts/briefs/brief-zcrud-study-ui-2026-07-16/brief.md` l.130-134)
- [Source: ARCHITECTURE-SPINE.md#AD-34/AD-35/AD-36, AD-2/AD-15, AD-10, AD-13] (`.../architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md`)
- [Source: prd.md#NFR-SU9] (`.../prd-zcrud-study-ui-2026-07-16/prd.md` l.202) + rubric (NFR-SU9 adjectival, borne = compteurs de rebuilds)
- [Source: code-review-su-4.md] D1 (`RangeError` file qui rétrécit / `key` d'identité), D2 (association par identité), D8 (`onStackEnd` atteignable)
- [Source: code-review-su-7.md] deux listes parallèles (`ZSessionItem` IDs seuls), assérer le NOMBRE
- [Source: code-review-su-8.md] `didUpdateWidget` resync (queue périmée), hôte-jouet ≠ hôte correct
- [Source: su-5-...md] `onStackEnd` latch one-shot, célébration poussée une seule fois
- [Source: example/pubspec.yaml, example/test/boundary_deps_test.dart, example/test/sm1_granular_rebuild_test.dart, example/lib/{app,home_screen}.dart] (état disque vérifié)
- [Source: CLAUDE.md] AD invariants, vérif verte, distribution dép. git

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M) — skill `bmad-dev-story` (workflow résolu via `resolve_customization.py`).

### Debug Log References

- `example/` : `dart pub get` RC=0 (aucun `zcrud_mindmap`/`zcrud_exam` tiré) ; `flutter analyze`
  sur les 7 fichiers su-10 (lib+test) : **No issues found** ; `flutter test` des 4 fichiers su-10 :
  **14 cas, All tests passed** (boundary 1 + surface publique 2 + SM-1 2 + swiper/robustesse 9).
- **R3 (rougir par le comportement)** : injection « resync `didUpdateWidget` désactivé » →
  le test « FILE qui RÉTRÉCIT » devient **ROUGE** (l'ancienne carte courante `c2`, hors nouvelle
  file, survit → `answer_c2` trouvé) ; source **restaurée** (SHA-256 identique à l'original
  `2f58077d…`). L'injection « clamp retiré » seule ne rougissait PAS (le swiper s'auto-protège via
  `_queueGeneration`) — d'où le **renforcement** de l'assertion (identité résolue, pas « aucune
  exception »).

### Completion Notes List

- **Écart tranché (conservateur, non-interactif) — `zcrud_study` NON ajouté.** `zcrud_study/pubspec.yaml`
  dépend **en dur** de `zcrud_mindmap` ET `zcrud_exam` (vérifié sur disque). L'ajouter tirerait
  `zcrud_mindmap` dans le lock de l'app (override path obligatoire) — ce qui **violerait l'invariant
  AC10 « `zcrud_mindmap` reste INTERDIT »** et empiéterait sur le workstream su-12. Le parcours
  assemblé (sélecteur→pile→carte→célébration) n'a besoin QUE de `zcrud_session` + `zcrud_flashcard`.
  ⇒ **fake du port de génération (`ZFlashcardGenerationPort`, hors flux assemblé) reporté** ; les 2
  ports du flux réel (`ZFlashcardHintPort`, `ZFlashcardAnswerEvaluationPort`, tous deux dans
  `zcrud_flashcard`) sont livrés en fakes. `zcrud_study_kernel` **promu en dépendance directe**
  (`ZStudySessionResult`/`ZStudyStreak`, masqués par le barrel `zcrud_flashcard`).
- **`melos list` == 23, pas 14.** L'invariant « 14 » de la story est **périmé** (l'epic study-ui a
  fait grandir le workspace à 23 membres). L'invariant RÉEL — `zcrud_example` **hors du glob** — tient :
  l'example n'apparaît pas dans `melos list`, son lock reste propre.
- **AD-34 (runtime par mode)** : table UNIQUE `_makeRuntime` couvrant les 6 `ZReviewMode` → 3
  runtimes ; `spaced`/`learn` seuls reçoivent le `ZSessionReviewer` (seam du store) ; aucun 4ᵉ
  runtime, aucun reviewer no-op. Le sélecteur produit `learnNew→learn`, `review→spaced`,
  `test→whiteExam`.
- **Hôte correct** : 2 listes parallèles (`List<ZSessionItem>` + `Map<String,ZFlashcard>`),
  résolution `cardBuilder` **par `flashcardId`** ; tally des soumissions **par identité** ; `key` de
  pile dérivée de l'identité de file ; resync `didUpdateWidget` (clamp de l'index) ; latch one-shot
  `onStackEnd` (+ le swiper `isLoop:false` garantit une émission unique).
- **PRE-EXISTANT hors su-10 (prouvé)** : `example/test/markdown_demo_test.dart:32` (setValue sur
  `ZMarkdownField.controller` devenu nullable) et `example/test/offline_demo_test.dart:146` (fake
  `ZLocalStore` sans `syncEntries`/`applyMerged`, méthodes ajoutées par l'épic offline-first)
  **échouent déjà avec le pubspec ORIGINAL** (vérifié en restaurant le pubspec d'avant su-10). su-10
  ne les régresse pas ; ils bloquent un `flutter analyze`/`flutter test` **example-wide** RC=0 et
  relèvent des stories offline-first / markdown, pas de su-10. **Fix recommandé** (hors su-10) :
  `field.controller!` (1 ligne) + 2 stubs `syncEntries`/`applyMerged` dans le fake offline.

### Profiling (AC8 — NFR-SU9, borne = compteurs de rebuilds)

Mesuré sur le parcours RÉEL (contenu **markdown**, `ZFlashcardMarkdownContent`/Quill — chemin su-2,
pas un contenu par défaut) via `RebuildLog` :

| Scénario | Sonde | Mesure | Verdict SM-1 |
|---|---|---|---|
| Frappe 100 car. dans `ZFlashcardAnswerInput` | `swiper` | **+0** | ✅ pile non reconstruite |
| Frappe 100 car. | `card_<id>` (carte d'affichage) | **+0** | ✅ carte non reconstruite |
| Frappe 100 vs 200 car. (discriminant) | `swiper` | **0 == 0** (coût INDÉPENDANT du nb de frappes) | ✅ |
| Frappe 100 car. | focus / curseur | `hasFocus == true`, `selection.baseOffset == 100`, `text == 'a'*100` | ✅ focus conservé |
| Global | `find.byType(Form)` | **findsNothing** | ✅ aucun `Form`, aucun `setState` parcours |
| Avance réelle (bouton) | `swiper` | **> baseline** (contrôle POSITIF : sonde vivante) | ✅ |
| Fenêtrage pile (4 cartes) | `card_<id3>` au montage | **0** (hors-écran non construit) | ✅ AC7 |

Note SM-1 : `ZFlashcardAnswerInput` possède son `TextEditingController` en interne (aucun seam
d'injection) ⇒ le rebuild du champ courant lui-même n'est pas échantillonnable par `RebuildLog` au
niveau hôte (ce n'est PAS un défaut de barrel, c'est l'encapsulation attendue AD-2). La preuve SM-1
porte donc sur (a) l'**absence** de rebuild collatéral (pile/carte, sonde vivante) et (b) la
**vivacité** du champ (controller/focus) — falsifiable par le discriminant 100==200 et le contrôle
positif d'avance.

### Aucun défaut de barrel

Les 8 widgets assemblés + les 2 ports du flux réel sont **tous exportés** par leurs barrels ; garde
T8 (`study_parcours_public_surface_test.dart`) verte : **aucun** import `/src/` dans `example/lib`.
`ZStudySessionResult`/`ZStudyStreak` sont **volontairement masqués** par le barrel `zcrud_flashcard`
(symboles study-niveau) et importés depuis le barrel PUBLIC `zcrud_study_kernel` — ce n'est pas un
défaut de barrel.

### File List

- **Créés** :
  - `example/lib/demos/study_session_demo_screen.dart` (hôte du parcours)
  - `example/lib/demos/fakes/in_memory_study_store.dart`
  - `example/lib/demos/fakes/fake_flashcard_hint_port.dart`
  - `example/lib/demos/fakes/fake_answer_evaluation_port.dart`
  - `example/test/study_parcours_sm1_test.dart`
  - `example/test/study_parcours_swiper_test.dart`
  - `example/test/study_parcours_public_surface_test.dart`
- **Modifiés** :
  - `example/pubspec.yaml` (deps + overrides `zcrud_session`/`zcrud_flashcard`/`zcrud_study_kernel` + commentaires frontière)
  - `example/lib/home_screen.dart` (entrée « Parcours d'étude »)
  - `example/test/boundary_deps_test.dart` (frontière : `zcrud_flashcard` retiré de `forbidden`, `zcrud_mindmap` conservé, assertions positives)
  - `example/pubspec.lock` (régénéré par `dart pub get`)
- **AUCUN** fichier sous `packages/` touché.
