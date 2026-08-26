# Réfutation — Examen blanc complet (IFFD)

**Domaine** : Révision — moteur de répétition espacée, sessions, gamification (IFFD)
**Besoin hôte** : remplacer `white_exam_page.dart` (779 l.) + `white_exam_question_card.dart` (1 139 l.)
**Affirmation attaquée** : « le socle sait déjà le faire, par `ZWhiteExamSessionEngine` + `ZWhiteExamState` + `ZWhiteExamPhase{setup,running,submitted}` + `ZExamScoringPort` + `scoreWhiteExam` + `ZWhiteExamSessionController` + `ZWhiteExamSessionView` + `ZCorrectionVisibility.deferred` + `ZListSessionView` », gain annoncé **~1918 lignes d'hôte supprimées**.

**VERDICT : RÉFUTÉE.** Les canaux existent et sont atteignables — mais le gain annoncé est faux d'un facteur ~2,5, et la couverture fonctionnelle est partielle sur **six** axes, dont deux régressions de comportement (réponse non modifiable, IA déplacée dans l'examen) que la dartdoc du socle assume explicitement comme des choix de conception.

Date : 2026-08-26. Dépôts hôtes lus en **lecture seule**. Aucun test lancé.

---

## 1. Ce qui résiste (vérifié ligne à ligne, corps lus)

### 1.1 Les neuf symboles existent, aux lignes citées

| Symbole | Fichier | Ligne réelle | Citation |
|---|---|---|---|
| `ZWhiteExamSessionEngine` | `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart` | **274** | :274 ✅ |
| `ZWhiteExamState` | idem | **90** (`@immutable` :89) | :90 ✅ |
| `ZWhiteExamPhase{setup,running,submitted}` | idem | **64-76** | :64 ✅ |
| `ZExamScoringPort` (typedef) | idem | **218-221** | :218 ✅ |
| `scoreWhiteExam` | idem | **249-268** (dartdoc dès :238) | « :239-269 » ⚠️ pointe dans la dartdoc, la fonction est à :249 |
| `ZWhiteExamSessionController` | `.../domain/z_white_exam_session_controller.dart` | **53** | :53 ✅ |
| `ZWhiteExamSessionView` | `.../presentation/z_white_exam_session_view.dart` | **79** | :79 ✅ |
| `ZCorrectionVisibility` / `.deferred` | `.../presentation/z_correction_visibility.dart` | **29** / **41** | :29,41 ✅ |
| `_submitDontKnow` / `_DontKnowButton` | `.../presentation/z_flashcard_answer_input.dart` | **652** / **1430** (dartdoc :1429) | :652,1429 ✅ |

### 1.2 Ils sont atteignables depuis IFFD

- Les six fichiers sont **exportés** par le barrel `packages/zcrud_session/lib/zcrud_session.dart` (6 lignes `export`, vérifiées).
- `zcrud_session` est une dépendance **directe déclarée** d'IFFD : `pubspec.yaml:412-416` (`ref: v3.21.0`, `path: packages/zcrud_session`) et `pubspec.lock:3475-3482` (`dependency: "direct main"`, `resolved-ref: cc276c15417919bb2f76b87feb8144724d7d37af`).
- Les six fichiers existent **au tag épinglé** : `git ls-tree --name-only v3.21.0 …` en rend 6/6, et `git rev-parse v3.21.0^{commit}` == `cc276c154…` == le ref résolu du lock. `git status --porcelain packages/zcrud_session` est **vide** : l'arbre de travail lu est bien celui du tag.
- Le mapper `FlashcardModel → ZFlashcard` **existe déjà** chez l'hôte : `iffdCardToZ` (`lib/src/presentation/features/flashcards/zcrud/review_card_zcrud.dart:85`). Ce n'est donc pas un blocage.

### 1.3 Les corps font ce qu'on leur prête (lus, pas seulement leur dartdoc)

- `scoreWhiteExam` (`:249-268`) : `byQuality[quality.toString()]++` (:256-257), `correct += 1` si `quality >= passThreshold` (:258-260), retour `ZStudySessionResult(mode: ZReviewMode.whiteExam, total: qualities.length, …)` (:262-267). **Agrégat pur, aucune écriture SRS** : le constructeur du moteur (:283-302) n'accepte que `queue`/`config`/`scorer`, et le fichier ne contient aucun symbole `reviewer`/`scheduler`/`store`.
- Machine à états réelle : `StateError` sur transition illégale à `start` (:336-341), `answer` (:383-388), `submit` (:400-406). Ce ne sont pas des no-op silencieux.
- `ZCorrectionVisibility.deferred` → `paintsCorrection == false` (`z_correction_visibility.dart:68-71`, `switch` exhaustif) tandis que le verrou reste posé : `_submitLocked = true` (`z_flashcard_answer_input.dart:549` QCM/VF, `:573` rédigé), `readOnly: corrected != null` (:1282), `onTap` neutralisé (:983). « Pose la correction sans la peindre » est **vrai**.
- `_submitDontKnow` (:652-664) émet `_finalQuality(widget.srsConfig.minQuality)` ; `minQuality` vaut **0** par défaut (`zcrud_flashcard/lib/src/domain/z_srs_config.dart:27`), et `passThreshold` **3** (:26) — ce qui **coïncide** avec l'hôte (`if (answer.isIDontKnow) return 0;` `white_exam_page.dart:552-553` ; `if (score >= 3) correct++;` :473). Le bouton est monté **inconditionnellement** (:771).

Jusqu'ici l'affirmation tient. C'est ensuite qu'elle casse.

---

## 2. Ce qui la dément

### R1 — Le gain de 1 918 lignes est faux : **aucun des deux fichiers n'est supprimable**

`white_exam_question_card.dart` (1 139 l.) n'est **pas** un fichier d'examen blanc : il est aussi monté par une autre feature.

```
$ grep -rn "WhiteExamQuestionCard" lib/ | grep -v "widgets/white_exam_question_card.dart:"
lib/.../widgets/learning_mode_question_card.dart:87:    // Store feedback data in state to pass to WhiteExamQuestionCard
lib/.../widgets/learning_mode_question_card.dart:234:    return WhiteExamQuestionCard(
lib/.../pages/white_exam_page.dart:283:                              WhiteExamQuestionCard(
```

`learning_mode_question_card.dart:234-249` le monte en **mode apprentissage** (`isSubmitted: true, isLearningMode: true, noDecoration: true, onQualitySubmit: widget.onSubmit`) — hors examen blanc. Migrer l'examen n'en retire **pas une ligne**.

`ExamAnswer` (`white_exam_page.dart:754-779`, **26 l.**) est un type partagé, importé par deux autres fichiers :

```
$ grep -rl "ExamAnswer" lib/
lib/.../widgets/white_exam_question_card.dart
lib/.../widgets/learning_mode_question_card.dart      (import ligne 9)
lib/.../widgets/interactive_flashcard_repetition_card.dart  (:17 import … show ExamAnswer)
lib/.../pages/white_exam_page.dart
```

**Plafond réel du gain : 779 − 26 = 753 lignes**, soit **39 %** des 1 918 annoncées — et encore, avant de soustraire l'adaptateur à écrire (cf. R3) et sans compter que, sous la discipline strangler-fig d'IFFD (`kReviewSessionUseZcrudDefault = false`, `review_session_zcrud.dart:56`), le legacy est **conservé** à côté du portage : **0 ligne retirée au cutover**.

### R2 — La sémantique de `deferred` n'est **pas** celle de `_isSubmitted` : le verrou tombe à un autre moment

L'affirmation dit « sémantique exacte du bool `_isSubmitted` de l'hôte (`:50,290-291`), en trois phases au lieu de deux ». Les lignes sont exactes (`:50 bool _isSubmitted = false;`, `:290-291 isSubmitted: _isSubmitted, isLearningMode: _isSubmitted,`) — la **sémantique**, non.

| Moment | Hôte (`_isSubmitted`) | Socle (`deferred` + `ZListSessionView`) |
|---|---|---|
| Pendant l'examen, carte non répondue | pas de correction, saisie **ouverte** | pas de correction, saisie ouverte |
| Pendant l'examen, **carte déjà répondue** | pas de correction, saisie **toujours ouverte** | pas de correction, saisie **VERROUILLÉE** |
| Après soumission | correction **peinte par la carte** (mode apprentissage) | carte muette ; `_CorrectionReveal` peint une ligne à part |

Preuves côté hôte : `CheckboxListTile.onChanged` (`white_exam_question_card.dart:726-742`) rappelle `_notifyAnswerChanged()` à chaque changement, `MarkdownEditionField.onSubmit` (:879-885) idem, et `readOnly: widget.isSubmitted` (:886) ⇒ l'édition reste ouverte tant que `_isSubmitted == false`. Preuves côté socle : `_submitLocked` posé dès la réponse (:549, :573), `readOnly: corrected != null` (:1282).

Ce n'est pas un détail d'implémentation, c'est un **choix revendiqué** du socle, écrit dans sa propre dartdoc (`z_list_session_view.dart`, en-tête, section « Une réponse par carte, définitive ») : « l'apprenant peut sauter une question … mais **jamais changer une réponse donnée** ». Migrer, c'est retirer à l'apprenant IFFD le droit de revenir sur une réponse pendant l'examen. Régression non demandée par le besoin.

Même écart sur « Je ne sais pas » : l'hôte le pose dans `_answers` (`:226-229`) et il reste **remplaçable** par une vraie réponse ; `_DontKnowButton` du socle **disparaît** dès la correction posée (:1445-1446) — irréversible.

### R3 — L'évaluation IA change de moment, perd son écran d'attente, et son port n'existe pas chez l'hôte

Hôte : **aucun** appel IA pendant l'examen. À `_submitExam` (`:439`), `_isEvaluating = true` (:442), boucle `await _evaluateAnswer(...)` sur toutes les réponses (:451-477), bannière « Évaluation des réponses en cours… » (:365-392, texte :388), puis `_isEvaluating = false` (:481).

Socle : `evaluationPort.evaluateAnswer(...)` est appelé **à la soumission de chaque carte**, pendant `running` (`z_flashcard_answer_input.dart:583-612`) — et le code note lui-même, en commentaire, que « le bouton n'a **aucun indicateur de charge** » (:570-571).

Grep négatif montré, canal de lot absent :
```
$ grep -n "evaluating\|Evaluating\|isEvaluating" z_list_session_view.dart z_flashcard_answer_input.dart
(aucune sortie)  rc=1
```

Et l'hôte n'a **aucune** implémentation de `ZFlashcardAnswerEvaluationPort` :
```
$ grep -rn "ZFlashcardAnswerEvaluationPort\|evaluationPort" iffd/lib/
lib/.../zcrud/review_session_zcrud.dart:27:// | `evaluationPort` | `null` | l'évaluation reste app-side |
```
Une seule occurrence, dans un **commentaire** disant l'inverse. L'adaptateur qui enveloppe `aiRepositoryProvider.evaluateFlashcardAnswer` + `IffdAiRouterModel` (`white_exam_page.dart:591-611`) est du code hôte **à écrire**, pas du code retiré.

Il n'existe pas non plus de canal pour la **régénération d'explication IA** post-correction (`_regenerateExplanation`, `white_exam_question_card.dart:226`, boutons :1014 et :1121) : dans `z_flashcard_answer_input.dart`, `explanation` n'apparaît qu'**une** fois (:591), en lecture, dans la requête d'évaluation.

### R4 — La saisie rédigée régresse d'un éditeur Markdown à un `TextFormField` nu

Hôte : `MarkdownEditionField(fieldName:, markdownValue:, fieldLabel: "Votre réponse", minLines: 5, maxLines: 15, isInline: true, readOnly:)` — `white_exam_question_card.dart:872-887`.
Socle : `TextFormField` (`z_flashcard_answer_input.dart:1261`), `maxLines: null`.

Aucun slot d'injection pour la saisie — grep négatif montré :
```
$ grep -n "answerBuilder\|inputBuilder\|writtenBuilder" z_flashcard_answer_input.dart
(aucune sortie)  rc=1
```
`contentBuilder` n'est consommé qu'à **un seul site** (:746) et porte la **question**, jamais la réponse.

### R5 — Trois affordances de la page n'ont aucun canal dans `ZListSessionView`

Grep négatif montré sur `z_list_session_view.dart` (704 l.) :
```
$ grep -n "flag\|Flag\|questionNumber\|headerBuilder\|leadingBuilder\|questionBuilder" z_list_session_view.dart
(aucune sortie)  rc=1
```
Et sur les trois paquets concernés :
```
$ grep -rln "flagged\|Flagged\|bookmark\|Bookmark\|marquer" zcrud_session/lib zcrud_exam/lib zcrud_flashcard/lib
(aucune sortie)  rc=1
```

Ne sont donc pas couverts :
1. **Marquage de question** — `_flaggedQuestions` (`white_exam_page.dart:48`), icône `Icons.flag`/`flag_outlined` (:265-266), bordure et libellé orange (:203-217), tooltip « Marquer cette question » (:277).
2. **Numérotation « Question N »** (:210) — `ZListSessionView._question` (à partir de :359) n'expose aucun slot d'en-tête par question ; il ne compose que `IgnorePointer(ZFlashcardAnswerInput(...))` + `_CorrectionReveal`.
3. **Deux boutons de soumission** — « Soumettre Incomplet » toujours actif (:334) vs « Soumettre » actif seulement si `_answers.length == widget.flashcards.length` (:347), plus un dialog à **trois** actions (:425). `ZListSessionView._submitBar` n'offre **qu'un** bouton et un dialog à **deux** actions (Annuler/Confirmer).

### R6 — Le score affiché n'est pas reproductible, et un cas de comptage diverge silencieusement

L'hôte agrège des **doubles** : `cumulativeScore += score` (`:460`) où `score` vient de `_evaluateOpenAnswer` (`double.tryParse` d’une réponse IA, :605). L'en-tête de résultats affiche **« Score Global » = `cumulative / (total × 5)`** (:640-641, rendu :674) et **« Moy./Quest. »** (:643-645, rendu :708).

Le socle ne transporte que des **entiers** : `ZExamScoringPort` prend `List<int>` (`z_white_exam_session_engine.dart:218-221`), `ZStudySessionResult` porte `{total, correct, byQuality}`. `ZSessionSummaryView` affiche Cartes / Maîtrisées / Durée (`z_session_summary_view.dart:605-634`) — **ni** pourcentage cumulé, **ni** temps moyen par question.

Divergence de comptage mesurable, sans aucune exception pour la signaler : une note IA de **2,5** est comptée **fausse** par l'hôte (`if (score >= 3)`, :473, sur le double) et **juste** par `scoreWhiteExam` (`quality = score.round().clamp(0, 5)` :463 donne 3 — `2.5.round() == 3` en Dart — puis `3 >= passThreshold(3)` :258). Un examen peut donc rendre deux nombres de bonnes réponses différents selon le chemin.

Ajout : l'écran de fin du socle est inséré **à l'index 0 de la `ListView`** (`z_list_session_view.dart:289-291, 320`), donc il défile ; l'en-tête de stats de l'hôte est un bandeau **fixe** au-dessus de la liste (`white_exam_page.dart:144`).

### R7 — `ZWhiteExamSessionView` est hors sujet pour ce besoin

Elle rend **une** question à la fois : `if (state.current case final item?)` (`z_white_exam_session_view.dart:211-223`), et son minuteur est un **rebours** injecté (`final ValueListenable<Duration> remaining`, :95 ; `_TimerRegion` :162-177).

L'hôte rend les **N** questions simultanément (`ListView.builder`, `white_exam_page.dart:157`) et son minuteur **compte en avant** (`_elapsedTime += const Duration(seconds: 1)`, :81, démarré à `initState` :68).

Le seul canal utilisable est `ZListSessionView`. Le citer conjointement avec `ZWhiteExamSessionView` **surestime la couverture** en faisant croire à deux surfaces disponibles là où l'une est inapplicable. S'y ajoute un coût d'adaptation réel : trois énumérations de phase parallèles à convertir (`ZWhiteExamPhase` → `ZWhiteExamSessionViewPhase` → `ZExamViewPhase`), le miroir `ZExamViewPhase` étant assumé comme « le prix de la pureté » par la dartdoc du fichier.

### R8 — Aucun de ces canaux n'est atteint par IFFD aujourd'hui

```
$ grep -rn "ZListSessionView\|ZWhiteExam\|ZExamViewPhase\|ZCorrectionVisibility\|ZFlashcardAnswerInput" iffd/lib/
lib/.../zcrud/review_card_zcrud.dart:31      (commentaire)
lib/.../zcrud/review_card_zcrud.dart:43      (commentaire)
lib/.../zcrud/review_session_zcrud.dart:17   (commentaire)
lib/.../zcrud/review_session_zcrud.dart:37   (import  show ZFlashcardAnswerInput, ZFlashcardSubmission)
lib/.../zcrud/review_session_zcrud.dart:118  (montage)
```
**5 occurrences, toutes `ZFlashcardAnswerInput`** (dont 3 en commentaire), et **zéro** pour `ZListSessionView`, `ZWhiteExamSessionEngine`, `ZWhiteExamSessionController`, `ZWhiteExamSessionView`, `ZExamViewPhase`, `ZCorrectionVisibility`. Le seul précédent d'adoption comparable (`review_session_zcrud.dart`) coûte **131 lignes** d'adaptateur pour envelopper **un seul** widget — l'ordre de grandeur du code hôte **ajouté** par cette migration n'est pas nul.

---

## 3. Ce qui est vrai à la place

Le socle porte un **moteur d'examen blanc réel et exportable** (machine à trois phases, scoring pur commutatif, zéro écriture SRS garantie par la structure du type) et une **surface en liste** (`ZListSessionView`) dont la forme générale — liste virtualisée de questions, barre de soumission, dialog de confirmation, révélation post-soumission, écran de fin — correspond à celle de l'examen IFFD. `zcrud_session` est déjà une dépendance directe au tag `v3.21.0` et le mapper `FlashcardModel → ZFlashcard` existe.

Mais :
- le gain plafonne à **~753 lignes** (39 % des 1 918 annoncées), parce que `white_exam_question_card.dart` sert aussi le **mode apprentissage** (`learning_mode_question_card.dart:234`) et que `ExamAnswer` est importé par **deux** autres fichiers ;
- la migration **change le comportement** sur deux points revendiqués comme des choix par le socle : réponse **définitive par carte** (au lieu de modifiable jusqu'à la soumission) et **appel IA pendant l'examen** (au lieu d'un lot après soumission, avec sa bannière d'attente) ;
- elle **perd** six éléments sans canal : marquage de question, numérotation, double bouton de soumission, éditeur Markdown de réponse, « Score Global » cumulé en double, temps moyen par question ;
- elle **ajoute** du code hôte : adaptateur `ZFlashcardAnswerEvaluationPort` (inexistant, `review_session_zcrud.dart:27` dit explicitement `null`), conversion entre trois énumérations de phase, restitution des affordances perdues.

Formulation honnête : *« le socle couvre le **noyau** de l'examen blanc — machine à états, scoring, liste de questions, correction différée, "je ne sais pas". Il ne couvre ni le marquage de questions, ni la saisie Markdown, ni l'évaluation IA en lot post-soumission, ni le score cumulé en virgule. Le portage retire au plus ~753 lignes, en ajoute une centaine d'adaptateur, et impose deux changements de comportement à arbitrer avec le pilote. »*

---

## Méthode

- Dépôts hôtes (`/home/zakarius/DEV/iffd`) lus en **lecture seule** (`cat`/`grep`/`awk`/`wc`). Aucune écriture, aucun test lancé, dans aucun dépôt.
- Toute affirmation d'absence porte son **grep négatif montré** avec `rc=1` (R3, R4, R5).
- Fichiers du socle lus **en entier** : `z_white_exam_session_engine.dart` (420 l.), `z_white_exam_session_controller.dart` (97 l.), `z_white_exam_session_view.dart` (283 l.), `z_correction_visibility.dart` (72 l.), `z_list_session_view.dart` (704 l.) ; `z_flashcard_answer_input.dart` (1 645 l.) lu par sections (:306-820, :1207-1470).
- Fichiers hôtes lus **en entier** : `white_exam_page.dart` (779 l.) ; `white_exam_question_card.dart` (1 139 l.) lu par sections (:1-260, :660-900).
