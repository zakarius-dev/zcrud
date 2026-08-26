# Réfutation — Révision (IFFD) : « écran de session assemblé » par `ZStudySessionHost`

**Date** : 2026-08-26 · **Rôle** : réfutateur · **Dépôts hôtes lus en LECTURE SEULE**
**zcrud lu au commit `cc276c154` (= tag `v3.21.0`, HEAD, `git status` propre sur les fichiers cités)**

---

## Verdict : **RÉFUTÉE**

Le canal existe, sa signature est **exactement** celle annoncée, il est exporté et atteignable
depuis IFFD. Ce qui ne tient pas, c'est la **couverture** : la correspondance « 1:1 » des six modes
est une correspondance d'**énumération**, pas de **comportement**. Migrer aujourd'hui
`folder_flashcards_repetitions_page.dart` vers `ZStudySessionHost` **supprimerait silencieusement
l'écriture SRS dans trois des six modes** et **rendrait la notation inatteignable dans deux d'entre
eux**. Le gain de ~1605 lignes n'est pas atteignable non plus.

---

## 1. Ce qui RÉSISTE (vérifié ligne à ligne, aucune dartdoc prise pour argent comptant)

| Affirmation | Vérification sur disque | Verdict |
|---|---|---|
| `ZStudySessionHost` à `z_study_session_host.dart:120`, 674 l. | `wc -l` = **674** ; `class ZStudySessionHost extends StatefulWidget` **ligne 120** | ✅ |
| « 27 params, 2 requis : `mode`, `queue` » | ctor lignes **127-156** : 28 lignes à virgule dont `super.key` ⇒ **27 params** ; `required` sur `mode` (128) et `queue` (129) **uniquement** | ✅ **exact** |
| `zSessionRuntimeForMode` à `z_session_runtime.dart:64` | `switch` d'expression **lignes 64-70**, **aucun `default`** ⇒ un 7ᵉ `ZReviewMode` casse la compilation | ✅ |
| `ZStudySessionEngine` à `z_study_session_engine.dart:116` porte `assert(mode == spaced ‖ learn)` et détient seul le reviewer | `assert` **lignes 142-149** ; `required ZSessionReviewer reviewer` **ligne 139** ; champ `_review` **ligne 159** | ✅ |
| `ZWhiteExamSessionEngine` n'a **aucun** paramètre reviewer | ctor **lignes 283-286** : `queue`, `config`, `scorer` — et rien d'autre. Absence **structurelle** confirmée | ✅ |
| (non revendiqué mais vérifié) `ZLinearSessionState` porte l'assert symétrique | `z_linear_session_state.dart:146-147` : `mode == list ‖ mode == cramming` | ✅ |
| Exporté par les barrels | `zcrud_study.dart:201` (host), `:204` (scaffold), `:205` (slices), `:206` (view) ; `zcrud_session.dart:37` (`z_session_runtime.dart`) | ✅ |
| Atteignable depuis IFFD | `iffd/pubspec.yaml` : `zcrud_study` **l. 391-395**, `zcrud_session` **l. 412-416**, `zcrud_study_kernel` **l. 421-425**, tous `ref: v3.21.0` = HEAD de zcrud | ✅ |
| Les six valeurs de `FlashcardRepetitionPageType` | `folder_flashcards_repetitions_page.dart:30-37` | ✅ |

**Le canal n'est donc ni fantôme ni inerte** : il est couvert par 6 fichiers de tests dans
`packages/zcrud_study/test/presentation/` (`…_mode_table_test.dart` : 20 `expect(` ;
`…_parcours_test.dart` : 17). Ce n'est pas là que ça casse.

---

## 2. R1 — **Trois modes sur six perdent leur écriture SRS.** Réfutation principale

### Ce que fait IFFD aujourd'hui

`folder_flashcards_repetitions_page.dart`, handler `onSwipe` **lignes 614-656** :

- garde d'entrée **l. 616-625** : sort tôt **uniquement** si `direction == none`, `buttonSpinning`,
  `flashcardRepetitionPageType == listOnly`, ou `readOnly` ;
- **l. 651** : `final quality = isCorrect ? 5 : 1;`
- **l. 655-656** : `ref.read(flashcardRepetitionRepositoryProvider).update(updatedRepetition);`

⇒ **le geste de swipe écrit du SRS dans `nFlashcardsLearningCycle`, `allFlashcardsLearningCycle`,
`test`, `whiteExam` ET `cramming`.** Seuls `listOnly` et `readOnly` en sont exclus.

Second chemin, `flashcards_learing_controller.dart` :
- `processRepetition` **l. 77-87** reçoit `isTestMode` et `isCramming` ;
- **l. 91-107** : `if (isCramming) { … return; }` — pas d'écriture ;
- **l. 110-147** : hors cramming, `await onSave(updatedRepetition)` aux **deux** branches
  (échec l. 125, réussite l. 142). `isTestMode` ne supprime pas l'écriture : il ne commande que le
  retrait de la carte (**l. 147**).
- Site d'appel (page **l. 837-852**) : `isTestMode: … == FlashcardRepetitionPageType.test`,
  `onSave: (r) async { await …update(r); _checkAndUpdateStreak(); }`.

### Ce que le socle rend impossible

`z_session_runtime.dart:64-70` : `test`/`whiteExam` → `whiteExam`, `cramming` → `linear`.
`z_study_session_host.dart:389-409` (`_makeRuntime`) : le `reviewer` n'est passé **qu'au** cas
`srsEngine` (l. 392-399) ; `ZLinearSessionState` (l. 400-405) et `ZWhiteExamSessionEngine`
(l. 406-407) sont construits **sans aucun seam**. Et il n'y a **aucun paramètre** sur
`ZStudySessionHost` pour en décider autrement — c'est l'invariant AD-34 revendiqué par la dartdoc
elle-même (« Aucun `ZSessionReviewer` no-op n'est fourni », `z_session_runtime.dart:22-25`).

### Conséquence

La correspondance annoncée `test→test`, `whiteExam→whiteExam`, `cramming→cramming` **transporte le
nom du mode et jette son régime d'écriture**. C'est une régression fonctionnelle silencieuse
(historique SRS et calendrier de révision non mis à jour après un test ou un examen blanc), pas un
gain de lignes. Elle emporte aussi la **gamification** : `_checkAndUpdateStreak()` (page **l. 113-172**,
60 l., flamme/`currentStreak`/`lastStudyDate`) est appelé **depuis `onSave`** — sans reviewer, il
devient injoignable dans ces modes.

---

## 3. R2 — Dans `test` et `whiteExam`, la notation deviendrait **inatteignable**

- `z_session_card_swiper.dart:85` (tableau des réglages du paquet) : « `onSwipe` | **navigation
  seule** → `onIndexChanged` » ; l. 429 : « `onSwipe` du paquet — **navigation seule**, et synchrone ».
- `z_study_session_host.dart:469-472` : `_onIndexChanged` ne fait que `_index = index; _sync();`.
  `_onSubmitted` (l. 478) n'est atteint **que** depuis le `submit` de `_buildGrading` (l. 617-618).
  ⇒ **dans le socle, un swipe ne note jamais.**
- Or IFFD **masque la barre de notation** dans ces modes : page **l. 736-742**,
  `if (… != listOnly && … != test && … != whiteExam && …) CardSwiperButtons(…)`.

⇒ En `test`/`whiteExam`, la **seule** entrée de notation d'IFFD est le geste. Migré tel quel, l'écran
n'a plus aucune commande de notation : il faut réécrire un `gradingBuilder` — c'est-à-dire
réintroduire chez l'hôte le code que la migration prétendait supprimer.

Perdus au passage, sans équivalent socle vérifié : les deux surcouches animées de retour de geste
pilotées par `percentThresholdX/Y` (page **l. 561-610** : visages vert/rouge et bleu/jaune, alpha
proportionnel à l'amplitude du drag).

---

## 4. R3 — `qualityOf` existe dans la **vue** et n'est **pas** câblé par le **host**

```
grep -n "qualityOf" packages/zcrud_study/lib/src/presentation/z_study_session_view.dart
  164:    this.qualityOf,      259:  final ZSessionQualityAtIndex? qualityOf;      349: qualityOf: qualityOf,
  468/478/501 (_StackSlice → ZSessionCardSwiper)
grep -n "qualityOf" packages/zcrud_study/lib/src/presentation/z_study_session_host.dart
  → RC=1, AUCUNE occurrence
```

Le `build()` du host (**l. 645-673**) énumère 20 arguments ; `qualityOf` n'y est pas. Le seam
`ZSessionQualityAtIndex` (`z_session_progress_indicator.dart:74`) est donc **inaccessible par le
canal revendiqué**.

Or c'est exactement ce qu'IFFD affiche : la couleur de chaque point est dérivée de la
`FlashcardRepetitionInfo` **persistée** de la carte (page **l. 310-341** : `segmentsColors` ←
`repetition.quality.color`, gris si non notée), rendue en `DotsIndicator` coloré (**l. 430-462**) ou
en `SegmentedProgressBar` pour `allFlashcardsLearningCycle` (**l. 462-482**).

L'échappatoire (« descendre d'un cran vers `ZStudySessionView` ») **coûte précisément l'objet de
l'affirmation** : c'est le host qui détient le runtime (`_makeRuntime`, `_seed`, `_gradeAndAdvance`,
l. 329-536). Descendre à la vue, c'est réécrire l'assemblage.

---

## 5. R4 — `readOnly` est **inexprimable** dans le canal

```
grep -n "readOnly" packages/zcrud_study/lib/src/presentation/z_study_session_host.dart  → RC=1 (0 occurrence)
grep -n "readOnly" packages/zcrud_study/lib/src/presentation/z_study_session_view.dart  → RC=1 (0 occurrence)
```

Chez IFFD, `readOnly` est **orthogonal au mode** et commande quatre choses : la souscription au flux
de répétitions (**l. 201-211**), le bloc de progression (**l. 358-361**), l'écriture au swipe
(**l. 622**) et la barre de notation (**l. 744**). Dans le socle, le seul levier est `mode` — et
`mode` **détermine le runtime**. « `spaced` mais en lecture seule » n'a pas de forme.

---

## 6. R5 — Condition cachée : `indexController` **rouvre** le piège su-10 D1 dans le mode où IFFD offre « précédent »

`ZIndexController` expose bien `previous()` (`zcrud_core/.../z_display_state.dart:292`), et le swiper
l'honore réellement (`z_session_card_swiper.dart:407-427` : `moveTo(clamped)` + `onIndexChanged`).
Mais dans le host, `_sync()` (**l. 425-438**) **ignore délibérément `_index` en régime SRS** :

```dart
if (rt is ZStudySessionEngine) { item = rt.current; }        // host:431-432
else { item = queue[_index.clamp(0, queue.length - 1)]; }    // host:436
```

et la tranche de notation n'écoute **que** `current` (`z_study_session_view.dart:509`).
⇒ un « précédent » en `spaced`/`learn` fait **reculer la carte affichée** (le swiper rend
`queue[index]`) pendant que la surface de notation reste **collée au front du moteur**. La note
tombe alors sur une carte qui n'est pas celle qu'on regarde — la classe de bug que la dartdoc du
host (l. 46) affirme avoir fermée, refermée seulement pour le chemin automatique.

C'est exactement le mode concerné : IFFD active `onPrevious` pour tous les modes **sauf**
`nFlashcardsLearningCycle` (page **l. 783-790**), donc y compris `allFlashcardsLearningCycle` →
`spaced`.

---

## 7. R6 — Le gain de **~1605 lignes** n'est pas atteignable

| Élément | Lignes | Sort réel |
|---|---|---|
| `flashcards_learning_celebration_page.dart` | **403** | **SURVIT.** `ZStudySessionCelebrationBuilder = Widget Function(BuildContext)` (`z_study_session_view.dart:104`) est un slot **vide** : le host doit fournir le widget. Le fichier est un `StatefulWidget` à confetti + 2 `AnimationController` (l. 26-71), stats et boutons d'action. |
| `enum FlashcardRepetitionPageType` (page l. 30-37) | 8 | **SURVIT.** Référencé par **9 autres fichiers** d'IFFD : `interactive_flashcard_repetition_card.dart:32,61,855`, `flashcard_repetition_widgets.dart:28,41,100-108`, `daily_tasks_page.dart:886`, `notebook_artifact_actions_iffd.dart:172`, `learning_mode_question_card.dart:8,16,30`, `flashcard_widgets.dart:990,1036,1119`, `multi_flashcard_editor_page.dart:27,699`, `chatbot_conversation_screen.dart:999`, `app_router.gr.dart:1430-1520`. |
| `class CardSwiperButtons` (page **l. 922-1202**) | **281** | Supprimable en théorie — `grep -rn "CardSwiperButtons" lib` hors du fichier → **RC=1, 0 occurrence**. Mais elle affiche, par bouton de qualité, `currentRepetitionInfo.getNextIntervalString(quality.value)` (l. ~1003-1008) : un aperçu d'intervalle par qualité, dont je **n'ai pas vérifié** l'équivalent socle — je ne le compte donc ni comme couvert ni comme perdu. |

Un écran de célébration existe bien au socle — `ZSessionSummaryView`
(`packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart`, **846 l.**, seul fichier
de `lib/` à importer `confetti`, l. 44) — mais il vit dans **`zcrud_session`** et **ne fait pas partie
des cinq canaux nommés** par l'affirmation. Le revendiquer, c'est changer l'affirmation.

---

## 8. R7 — Deux constats de contexte, mesurés

- **Le mode `cramming` est mort chez IFFD.** Son unique site de navigation est **commenté** :
  `flashcard_widgets.dart:1230-1245` (`// flashcardRepetitionPageType: // FlashcardRepetitionPageType.cramming,`).
  Les deux seules occurrences vivantes sont *internes* à la page (l. 866, 1018). La « correspondance
  1:1 des SIX modes » décrit donc un enum, pas six comportements atteignables.
- **IFFD n'a jamais envisagé ce canal, et sa migration révision n'est pas allumée.**
  `grep -rn "ZStudySessionHost" /home/zakarius/DEV/iffd/docs/` → **RC=1, 0 occurrence** ;
  `grep -rn "ZStudySessionHost|ZStudySessionView|ZStudySessionScaffold|zSessionRuntimeForMode" lib`
  → **0 occurrence** (seul `ZReviewMode` apparaît, `review_session_zcrud.dart:38,73-74`).
  Le périmètre de portage d'IFFD (`docs/perimetre-portage-apprentissage.md`, 806 l.) planifie la
  révision **au niveau des briques** (`ZFlashcardReviewCard`, `ZSessionCardSwiper`,
  `ZSrsQualityButtons` — l. 175, 290) et route l'examen blanc vers une **page séparée**
  (`ZWhiteExamSessionView` + moteur — l. 176, 289). Et les briques déjà portées sont derrière un flag
  **à `false`** : `review_session_zcrud.dart:55`, `kReviewSessionUseZcrudDefault = false`.
- **Aucun consommateur hors paquet.** Les 12 fichiers citant `ZStudySessionHost` sont tous dans
  `packages/zcrud_study/` (barrel, 4 fichiers `lib/`, README, 6 tests). Le canal est testé, jamais
  éprouvé par un hôte.

---

## 9. Point mineur, signalé sans le compter comme réfutation

`ZSessionReviewer` (`z_session_reviewer.dart:26-31`) ne transporte que
`flashcardId`, `folderId`, `quality`, `now?`. La clé de répétition d'IFFD en porte davantage :
`subFolderId`, `userId`, `chatConversationId`, `chatMessageId`, `accademicYear`
(page **l. 638-649** et **l. 751-766**). Refermable par capture dans la closure du reviewer — ce
n'est pas un blocage, mais ce n'est pas gratuit non plus.

---

## Ce qui est vrai à la place

`ZStudySessionHost` est un assemblage **réel, exporté, testé et atteignable au tag consommé par
IFFD**, et il couvre **honnêtement deux des six modes** : `nFlashcardsLearningCycle → learn` et
`allFlashcardsLearningCycle → spaced` — les deux seuls dont IFFD attend effectivement une écriture
SRS **par la voie du reviewer**, et les deux seuls où sa barre de notation est montée. Pour ces
deux-là, il reste à combler : `qualityOf` non câblé (R3), `readOnly` inexistant (R4), le geste qui
ne note plus (R2), le « précédent » qui désaligne carte et notation (R5), et la célébration à
fournir soi-même (R6).

Pour `listOnly`, `test`, `whiteExam` et `cramming`, la migration telle qu'annoncée **change le
comportement** : plus d'écriture SRS (R1), et plus de commande de notation du tout en
`test`/`whiteExam` (R2).

Le gain défendable n'est pas ~1605 lignes. Il est, au mieux, le corps de session des **deux modes
d'apprentissage** — et il se paie d'une CR au socle pour `qualityOf`, `readOnly` et une décision
explicite sur le régime d'écriture de `test`/`whiteExam` chez IFFD.
