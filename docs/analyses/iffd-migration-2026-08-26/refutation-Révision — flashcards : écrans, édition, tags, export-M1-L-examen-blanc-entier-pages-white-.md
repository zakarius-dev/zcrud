# Réfutation — M1 « L'examen blanc entier » (Révision / flashcards)

**Date** : 2026-08-26 · **Rôle** : réfutateur · **Verdict** : 🔴 **RÉFUTÉE**
(couverture **partielle** présentée comme **totale**)

## Affirmation attaquée

> « Le socle sait déjà le faire, par **ZListSessionView (+ ZExamViewPhase, ZExamAnswerCallback)
> piloté par ZWhiteExamSessionEngine / ZWhiteExamSessionController** » — gain annoncé
> **~600 lignes d'hôte supprimées** sur `white_exam_page.dart` (779 l.).

---

## 0. Ce qui TIENT (à ne pas rejeter avec le reste)

| Point | Mesure sur disque |
|---|---|
| Les symboles **existent** | `ZExamViewPhase` `z_list_session_view.dart:105` ; `ZExamAnswerCallback` `:124` ; `class ZListSessionView` `:128` (ctor `:135`) ; `ZWhiteExamSessionEngine` `z_white_exam_session_engine.dart:274` ; `scoreWhiteExam` `:249` ; `ZWhiteExamSessionController` `z_white_exam_session_controller.dart:53` |
| **Exportés** par le barrel | `zcrud_session/lib/zcrud_session.dart` — `:26` submission, `:40` controller, `:41` engine, `:61` correction-visibility, `:65` answer-input, `:75` list-session-view |
| **Atteignable** depuis l'hôte | `iffd/pubspec.yaml:412-416` (`zcrud_session`, dép. déclarée) + override `:677-681`. Déjà importé en 3 fichiers (`ZFlashcardSubmission`, `ZFlashcardAnswerInput`) |
| Le corps fait bien ce qu'on lui prête (partie liste) | `ListView.builder` sur **toutes** les cartes `:315-324` ; `submissions` clé = **position** `:177` + garde de bornes `:250-256` ; `IgnorePointer` par phase `:381-382` ; `correctionVisibility: deferred` `:408` ; écran de fin à l'index 0 sous `Semantics(liveRegion: true)` `:346-355` ; `_submitBar` `:427-472` |
| La critique de `ZWhiteExamSessionView` est **juste** | `recordAnswer` `z_white_exam_session_engine.dart:232-236` : `answers: [...state.answers, quality], cursor: cursor + 1` — strictement linéaire, confirmé |
| Le besoin hôte est bien non-linéaire | `white_exam_page.dart:46` `Map<String, ExamAnswer> _answers` ; `ListView.builder :157-312` |
| Un mapper modèle existe | `iffd/lib/src/data/repositories/z_backed_flashcard_repository.dart:201` (`ZFlashcard(`) |

**Aucune de ces vérifications n'est en cause.** La réfutation porte sur *ce que le canal ne fait pas*
et sur *ce que l'hôte fait et perdrait*.

---

## R1 — Le défaut reproché à la mauvaise vue est dans le MOTEUR, pas dans la vue

La preuve écarte `ZWhiteExamSessionView` pour son « curseur strictement linéaire
(`recordAnswer`, `:231-235`) » — puis propose `ZListSessionView` **piloté par le même moteur**.
Or `recordAnswer` **est** le moteur. Changer de vue ne change rien à la linéarité.

Mesuré : `ZWhiteExamSessionEngine.answer(int quality)` (`z_white_exam_session_engine.dart:382`)
**ne porte aucun index**. Son propre dartdoc `:351-381` le dit sans ambiguïté :

> « `ZListSessionView` rend les cartes simultanément et toutes saisissables : son hôte est donc
> **non linéaire par conception**. Il n'exploite en conséquence que l'agrégat commutatif
> ([result]) et sa propre correspondance indexée par position — **jamais
> `answers`/`current`/`cursor`**. »

Conséquence directe sur le pilote annoncé : `ZWhiteExamSessionController` projette **cinq**
champs (`z_white_exam_session_controller.dart:37-49`) — `phase`, `current`, `answered`,
`remaining`, `result`. Sous `ZListSessionView`, **trois sur cinq (`current`, `answered`,
`remaining`) sont corrompus par construction**. Ce qui reste utilisable : `phase` (qu'il faut
encore convertir, cf. R8), `result`, et trois délégations d'une ligne (`:69`, `:72`, `:75`).
« Piloté par `ZWhiteExamSessionController` » est donc une surévaluation : le contrôleur, ses
97 lignes, ne pilote presque rien ici.

Aggravant : `answer()` **n'a aucune garde** contre `answers.length > queue.length`
(`:382-390` — seul le contrôle de phase existe). Rien côté domaine n'empêche une note
surnuméraire de gonfler `total` dans `scoreWhiteExam` (`:264`). Ce qui protège aujourd'hui
l'agrégat est **le verrou de la vue** — c'est-à-dire précisément ce qui casse l'hôte (R2).

---

## R2 — 🔴 « Une réponse par carte, DÉFINITIVE » : incompatible avec le modèle IFFD

C'est la réfutation décisive : les deux modèles d'interaction s'excluent.

**Socle — réponse verrouillée dès la première soumission :**
- `_submitLocked` (`z_flashcard_answer_input.dart:334`) n'est remis à `false` **que** sur
  changement de carte (`:379` `if (oldWidget.card != widget.card) _resetForNewCard();` → `:388`).
  Dans `ZListSessionView` les cartes ont une **identité stable par slot** (`:396-398`,
  `ValueKey('zExamQuestion_id:…')`) : la carte ne change jamais, donc **le verrou ne retombe jamais**.
- Les choix deviennent morts : `:983-984` `onTap: corrected != null ? null : …`.
- « Je ne sais pas » **disparaît** : `:1445-1446` `corrected != null ? const SizedBox.shrink() : …`.
- Le dartdoc de la vue l'énonce lui-même, `z_list_session_view.dart:76-82` :
  « L'apprenant peut sauter une question … mais **jamais changer une réponse donnée**. »

**IFFD — édition libre jusqu'à la soumission globale :**
- QCM : `white_exam_question_card.dart:725` `enabled: !widget.isSubmitted` ; **désélection
  supportée** `:737` `_selectedChoices.remove(index)`.
- Vrai/Faux : `:826-831` reste tappable tant que `!isSubmitted`.
- Rédigé : `:886` `readOnly: widget.isSubmitted`.
- Chaque changement remonte : `:156` `widget.onAnswerChanged?.call(answer)`.
- La page **ajoute ET retire** : `white_exam_page.dart:296-306`
  (`_answers[id] = newAnswer` / `_answers.remove(id)`).
- « Je ne sais pas » écrase une réponse existante à tout moment : `:226-230`.

⇒ Après migration, **un apprenant ne peut plus corriger une faute de frappe ni changer une
sélection de QCM**. Sur la surface où cela compte le plus. Ce n'est pas un écart cosmétique.

---

## R3 — 🔴 Un geste de soumission PAR CARTE, absent chez IFFD — et des réponses perdues sans exception

Dans le socle, une réponse rédigée ne devient une soumission **que** si le bouton
`_SubmitButton` **de la carte** est pressé (`z_flashcard_answer_input.dart:998`,
`:812 onSubmit: _submitWritten`). Le Vrai/Faux, lui, s'auto-soumet au **premier tap**
(`:802 onAnswer: (value) => _submitLocal(answeredTrue: value)`).

IFFD n'a **aucun** bouton de soumission par carte : on remplit, puis on presse **le** bouton
global (`white_exam_page.dart:346-360`).

Scénario mesurable après migration : un apprenant remplit les N champs et n'appuie sur aucun
bouton par carte. Alors `submissions == {}` → `_unanswered == cards.length`
(`z_list_session_view.dart:250`) → `engine.submit()` produit `total: 0`
(`scoreWhiteExam :249-268`). **Le texte saisi est jeté, silencieusement, sans aucune exception.**

---

## R4 — L'évaluation IA change de moment et perd son indicateur de charge

| | IFFD (réel) | Socle |
|---|---|---|
| Moment | **À la soumission**, en lot (`white_exam_page.dart:481-489`, boucle `:493-519`) | **Au tap de la carte**, une par une (`z_flashcard_answer_input.dart:583-597`) |
| Indicateur | Bandeau explicite « Évaluation des réponses en cours… » (`:406-435`) | **Aucun** — grep négatif montré ci-dessous ; le code le dit : « le bouton n'a aucun indicateur de charge » (`:570-571`) |
| Facteur temps | `timeTakenSeconds: 0` — délibéré, « No time factor for exam mode » (`:599`) | `timeTaken: _stopwatch.elapsed`, toujours réel (`:592`) |
| Routage | `aiRouter: widget.aiRouter` passé par appel (`:601`) | `ZFlashcardAnswerEvaluationRequest` ne porte pas de routeur (`z_flashcard_answer_evaluation_port.dart:225-227`) — à capturer dans l'implémentation du port |

Grep négatif :
```
$ grep -in "CircularProgressIndicator\|LinearProgressIndicator\|isLoading\|_inFlight\b\|busy" \
    packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart
(aucun résultat)
$ grep -in "CircularProgressIndicator\|LinearProgressIndicator\|isLoading\|evaluating" \
    packages/zcrud_session/lib/src/presentation/z_list_session_view.dart
(aucun résultat)
```
⇒ N attentes IA muettes réparties dans l'examen, au lieu d'une attente annoncée à la fin.

---

## R5 — La distinction « Je ne sais pas » (0) vs « mauvaise réponse » (1) n'est pas représentable

IFFD note **différemment** l'aveu d'ignorance et l'erreur :
- `white_exam_page.dart:594-596` : `if (answer.isIDontKnow) { return 0; }`
- `:572` (QCM) et `:576` (V/F) : `return isCorrect ? 5.0 : 1.0;`

Socle : **les deux chemins atterrissent sur la même valeur**.
- `_submitDontKnow` → `_finalQuality(widget.srsConfig.minQuality)` (`z_flashcard_answer_input.dart:660`)
- QCM/VF faux → `_qualityFor(exact: false)` → `config.minQuality`
  (`z_flashcard_local_evaluation.dart:130-131`)

Et l'échappatoire est fermée : `ZSrsConfig` **asserte** `minQuality == 0 || minQuality == 1`
(`z_srs_config.dart:60-65`). Un seul bouton de réglage pour deux sémantiques hôtes distinctes :
la distinction est **perdue**, pas déplacée. (Le repli neutre, lui, concorde : socle
`passThreshold` = 3 par défaut `z_srs_config.dart:26` vs IFFD `return 3.0` `:660`.)

---

## R6 — Fonctions d'hôte absentes du socle (greps négatifs MONTRÉS)

### a) Marquage / drapeau de question — **absent de tout le dépôt**
IFFD : `_flaggedQuestions` (`white_exam_page.dart:47`), chrome complet `:178-236` (~60 l.),
`tooltip: "Marquer cette question"` `:277`.
```
$ grep -rin "flagged\|bookmark\|Icons.flag" packages/zcrud_session/lib/
(aucun résultat)
$ grep -rln "flagged\|Icons.flag" packages/*/lib/
(aucun résultat)
```
**Aucun paquet zcrud ne porte cette fonction.**

### b) Minuteur d'examen vivant — absent
IFFD : `Timer.periodic` + `_elapsedTime` (`:77-85`), affiché dans l'AppBar (`:111-119`),
arrêté à la soumission (`:670`), plus deux formateurs (`:87-92`, `:787-792`).
```
$ grep -in "timer\|ticker\|elapsed\|ZTimerDisplay\|Stopwatch" z_list_session_view.dart
62:/// Portée exacte de cette mitigation, à ne pas surestimer : la clé est une   ← commentaire
```
`duration` est un paramètre **injecté** (`:188`) : l'hôte garde son ticker intégralement.

### c) `Scaffold` / `AppBar` — absents
IFFD : AppBar avec titre de dossier, minuteur, et action `${_answers.length}/${flashcards.length}`
ouvrant le dialog (`:99-132`).
```
$ grep -in "AppBar\|Scaffold" z_list_session_view.dart
(aucun résultat)
```
`ZListSessionView` est une `Column` (`:302`) — l'hôte fournit tout le chrome.

### d) « Soumettre Incomplet » vs « Soumettre » — absent
IFFD : deux boutons distincts, le second **désactivé** tant que `_answers.length != flashcards.length`
(`:346-360`), et une troisième action dans le dialog (`:461-468`).
```
$ grep -in "incomplet\|partial\|allAnswered\|enabled:" z_list_session_view.dart
(aucun résultat)
```
Le socle a **un** bouton, **toujours actif** (`:460-468`, aucun `onPressed: null`).

### e) Le dialog du socle est plus pauvre
`_confirmSubmit` (`:509-532`) ne porte **ni titre ni phrase** : son `content` est
`Text('$unanswered')` — un nombre nu. IFFD porte un titre (`:450`), une phrase explicative
(`:452-456`) et trois actions (`:457-475`).

---

## R7 — L'écran de résultats n'affiche pas les mêmes nombres, ni au même endroit

| | IFFD | Socle |
|---|---|---|
| Placement | Bandeau **fixe au-dessus** de la liste (`:143-145`, `_buildStatsHeader :680-785`) | Item **0 de la `ListView`** (`z_list_session_view.dart:320`) → **défile hors écran** |
| Nombre principal | **% de score cumulé** : `_cumulativeScore / (_totalAnswered * 5) * 100` (`:682-684`) | Anneaux `correct/total` (`z_session_summary_view.dart:491-492`) |
| Autres | Correctes, temps total, **moyenne/question** (`:685-687`, `:734-753`) | Total, « maîtrisées » (q4-5), durée (`:597-633`) |
| Sémantique de « correct » | `score >= 3` (`:515-517`) | `ZSessionSummaryView` affiche **« maîtrisées » = q4-5**, explicitement ≠ `result.correct` (dartdoc `:12-21`) |

```
$ grep -in "%\|percent\|pourcent\|cumulat" z_session_summary_view.dart
448:    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');   ← modulo de durée
```
⇒ **Ni pourcentage cumulé, ni moyenne par question.** Le nombre le plus visible de l'écran IFFD
n'existe pas dans le socle. (Le confetti, lui, est opt-in — `ZSummaryCelebration.none` par défaut,
`:59` — donc pas de régression de ce côté.)

---

## R8 — Les références de la preuve sont approximatives

| Cité | Mesuré |
|---|---|
| `z_list_session_view.dart:128 (ctor)` | `:128` = **déclaration de classe** ; le ctor est `:135` |
| `:295 (submissions Map…)` | `:295` = commentaire ; le champ est déclaré `:177` |
| `:373 (IgnorePointer)` | `:373` = commentaire ; `IgnorePointer` est `:381` |
| `:404 (correctionVisibility deferred)` | `:404` = commentaire ; l'argument est `:408` |
| `…/presentation/z_white_exam_session_controller.dart:53` | Le fichier vit sous **`lib/src/domain/`** — `lib/src/presentation/` ne le contient pas |
| `pages/white_exam_page.dart, 779 l.` | Chemin réel `lib/src/presentation/features/flashcards/pages/white_exam_page.dart` ; **779 l. exact** |
| `:105`, `:124`, `:53`, `:274`, `:231-235`, `:243`, `white_exam_page.dart:46`, `:157-303` | **exacts** |

Aucun symbole n'est inventé — mais quatre ancres sur dix pointent un commentaire au lieu du
construit, et un chemin de paquet est faux. À corriger avant de servir de plan de lot.

---

## R9 — Le gain de ~600 lignes est très surévalué

Décompte du fichier hôte (779 l., ligne à ligne) :

| Catégorie | Blocs | ~Lignes |
|---|---|---|
| ✅ **Réellement supprimable** | `ExamAnswer` `:753-779` (27) · `LinearProgressIndicator` `:144-153` (10) · `_showResultsDialog` `:663-678` (16) · scoring local QCM/VF `:590-625` (36) · `_showSubmitDialog` `:445-479` (35, **avec régression** R6e) | **~124** |
| 🟡 **Remplaçable au prix d'autres nombres** | `_buildStatsHeader` + `_buildHeaderStat` `:680-785` (R7) | ~106 |
| 🔁 **Déplacé, pas supprimé** | `_evaluateOpenAnswer` `:627-661` (35) + banques de messages `:533-588` (56) → dans l'implémentation du port | ~91 |
| ❌ **À conserver intégralement** | minuteur+formats (~37) · `Scaffold`/`AppBar` (~34) · flag (~60) · soumission incomplète (~40) · bandeau d'évaluation (~30) | **~201** |
| ➕ **À écrire EN PLUS** | conversion `ZWhiteExamSessionViewPhase → ZExamViewPhase` (miroir imposé à l'hôte, dartdoc `:100-104`) · maintien des **deux listes parallèles** `items`/`cards` (dartdoc `:46-60`) · purge de la `Map<int,…>` au changement de file (`:62-69`) · mapper `FlashcardModel → ZFlashcard` · implémentation du port IA | non nul |

**Plafond crédible du gain net : ~230 lignes**, dont ~106 au prix d'un changement de métriques
affichées — et à condition d'accepter R2, R3, R5 et R6, qui sont des **pertes de fonction**.
Le chiffre de ~600 n'est atteignable qu'en comptant comme « supprimé » ce qui est en réalité
déplacé (~91 l.) ou simplement **perdu** (~200 l. de fonctions sans équivalent).

> Note de périmètre : le vrai volume de ce domaine est `white_exam_question_card.dart`
> (**1 139 l.**), que `ZFlashcardAnswerInput` (65 Ko) remplacerait pour l'essentiel.
> L'affirmation ne le mentionne pas. Une M1 recentrée sur **la carte** serait bien plus
> défendable que celle-ci — mais ce n'est pas l'affirmation attaquée.

---

## Verdict

🔴 **RÉFUTÉE.** Le canal est **réel, exporté et atteignable** ; il **ne couvre pas le besoin réel
de l'hôte**, seulement sa version simplifiée.

Trois obstacles sont **structurels**, pas des finitions :
1. **R2** — le socle verrouille une réponse dès sa soumission ; IFFD la laisse éditable jusqu'à
   la soumission globale. Modèles d'interaction **mutuellement exclusifs**.
2. **R3** — le socle exige un geste de soumission **par carte** qu'IFFD n'a pas ; sans lui, les
   réponses saisies sont **jetées sans exception** et l'examen est noté `total: 0`.
3. **R1** — le moteur nommé comme pilote est **positionnel** et rend trois de ses cinq champs de
   projection inexploitables sous cette vue ; c'est le verrou de R2 qui tient son agrégat.

Et quatre pertes de fonction mesurées : marquage de question (absent de **tout** le dépôt, R6a),
distinction IDK/erreur (non représentable, R5), soumission incomplète (R6d), métriques de
résultat (R7).

Conduite recommandée : **ne pas classer M1 comme « déjà couvert »**. Soit la CR décrit un
**ajout de contrat** au socle (`answer({index, quality})`, mode « brouillon éditable jusqu'à
soumission », drapeau de question, double affordance de soumission, évaluation différée en lot),
soit M1 est **redécoupée** sur la cible réellement couverte : la **carte de question**
(`white_exam_question_card.dart`, 1 139 l. ↔ `ZFlashcardAnswerInput`), et non la page.
