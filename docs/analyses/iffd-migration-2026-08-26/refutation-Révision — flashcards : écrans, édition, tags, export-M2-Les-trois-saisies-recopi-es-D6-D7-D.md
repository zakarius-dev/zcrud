# Réfutation — Révision / flashcards · M2 « Les trois saisies recopiées D6/D7/D8 »

**Date** : 2026-08-26 · **Rôle** : réfutateur · **Verdict : ❌ DÉMENTIE**

**Affirmation attaquée** — « le socle sait déjà le faire, par `ZFlashcardAnswerInput`
(17 params) — `_buildInput` switch exhaustif sur `ZFlashcardType` », avec pour cibles
`white_exam_question_card.dart:679-775 / :776-863 / :864-904` et
`flashcard_repetition_widgets.dart:484-632`, **gain annoncé ~375 lignes d'hôte supprimées**.

---

## 1. Ce qui TIENT (vérifié à l'octet)

| Élément avancé | Mesure sur disque | Verdict |
|---|---|---|
| Fichier socle | `packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart`, **1 645 lignes** | ✅ existe |
| Constructeur | `:104` (annoncé `:102` — **décalage de 2**) | ⚠️ quasi |
| 17 paramètres | `card, mode, srsConfig, contentBuilder, evaluationPort, allowSkipEvaluation, hintPort, revealStoredHint, hintPolicy, timerDisplay, timeLimit, advanceBehavior, autoAdvanceDelay, correctionVisibility, onSubmitted, onQualitySelected, onAdvance` = **17** (hors `super.key`) | ✅ |
| `_buildInput` switch exhaustif | `:789` → `:812`, sans `default` : `multipleChoice→_ChoicesInput :790`, `trueOrFalse→_TrueFalseInput :797`, `openQuestion‖exercise‖fillBlank‖shortAnswer→_WrittenInput :807` | ✅ exact |
| « Je ne sais pas » natif | `class _DontKnowButton :1430`, monté `:771`, clé `'zcrud.flashcard.dontKnow'` **:1449** | ✅ exact |
| Exporté par le barrel | `packages/zcrud_session/lib/zcrud_session.dart:65: export 'src/presentation/z_flashcard_answer_input.dart';` | ✅ |
| Atteignable depuis IFFD | `iffd/pubspec.yaml:412` `zcrud_session` en **dépendance déclarée**, `ref: v3.21.0` (+ override `:677`) ; `git show v3.21.0:…z_flashcard_answer_input.dart` = **1 645 l.**, barrel du tag : 1 occurrence | ✅ |
| Règle QCM simple/multiple | socle `zIsSingleChoiceQcm` (`zcrud_flashcard/lib/src/domain/z_flashcard_local_evaluation.dart:56`) = `zCorrectChoiceIndexes(card).length == 1` ; hôte `white_exam_question_card.dart:681-682` = `rightAnswersCount == 1` | ✅ règle identique |

Le canal **existe**, **fait ce qu'on lui prête** au niveau de la table d'affordance, et est
**atteignable**. C'est tout ce qui tient.

---

## 2. RÉFUTATION A — le 4ᵉ site cité N'EST PAS UNE SAISIE (148 l. sur 356 mal qualifiées)

`flashcard_repetition_widgets.dart:484-631` = `_buildChoicesSection`. Lecture du **corps** :

- QCM : `ListTile(contentPadding:…, title: <lecteur riche>, leading: <pastille numéro>)` — **pas de `onTap`**.
- Vrai/Faux : deux `ListTile(title: Text("Vrai"/"Faux"), trailing: Icon)` — **pas de `onTap`**.
- `openQuestion`/`exercise` : `default: return const SizedBox();` (`:628-629`) — **aucune saisie texte**.

**Grep négatif montré** :

```
$ sed -n '484,632p' lib/src/presentation/features/flashcards/widgets/flashcard_repetition_widgets.dart \
  | grep -n "onTap\|onChanged\|onPressed\|setState\|selected\|Checkbox\|Radio\|InkWell\|GestureDetector"
NEG: aucun capteur de geste ni etat de selection dans 484-632 de flashcard_repetition_widgets.dart
```

C'est un **affichage en lecture seule** des choix (face avant d'une carte de révision
classique). Preuve structurelle : `FlashcardRepetitionCard.build` (`:111`) **délègue** à
`InteractiveFlashcardRepetitionCard` dès que `_isInteractiveMode` (`:96-99` : `test` ou
`whiteExam`) ; `_buildChoicesSection` n'est atteint que sur le chemin **non interactif**.

⇒ Remplacer ces 148 lignes par `ZFlashcardAnswerInput` n'est pas une migration : cela
**AJOUTE** une surface de soumission (bouton « Soumettre », « Je ne sais pas », section
correction) là où l'écran n'en offre aucune. Ce n'est pas « le socle sait déjà le faire »,
c'est un changement de comportement.

---

## 3. RÉFUTATION B — les 3 sites de `white_exam_question_card.dart` sont un widget CONTRÔLÉ ; le socle est NON CONTRÔLÉ

`WhiteExamQuestionCard` (doc `:18` : *« no hints, no immediate validation »*) hisse tout son
état chez le parent :

| Canal hôte | Ligne | Rôle |
|---|---|---|
| `final ExamAnswer? initialAnswer` | `:26` | **restauration** d'une réponse déjà saisie |
| `final bool isSubmitted` | `:27` | soumission **pilotée de l'extérieur** |
| `final Function(ExamAnswer)? onAnswerChanged` | `:28` | notification **continue** à chaque frappe/tap |
| `didUpdateWidget` → `_syncFromInitialAnswer()` | `:117-124`, `:128-148` | ré-hydratation quand le parent change de réponse |
| `_notifyAnswerChanged()` | `:150-157` | pousse `ExamAnswer(selectedChoices, selectedTrueFalse, textAnswer)` |

Le socle n'a **aucun** de ces quatre canaux. **Grep négatif montré** :

```
$ grep -n "initialAnswer\|initialValue\|onAnswerChanged\|onChanged\|isSubmitted\|restore" \
      packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart
NEG: aucun canal de valeur initiale / de changement continu dans le socle
```

Le socle détient son état en interne (`_selected` `ValueNotifier`, `_answerController`,
`_correction`) et se **verrouille one-shot** à la première soumission :
`_ChoicesInput` `onTap: corrected != null ? null : …` (`:825-826`), `_WrittenInput`
`readOnly: corrected != null` (`:1281`), `_DontKnowButton` disparaît (`:1445-1446`).

Or l'examen blanc **exige** la ré-éditabilité : le candidat navigue entre questions et
revient modifier sa réponse (c'est la raison d'être de `initialAnswer` + `didUpdateWidget`),
et la correction n'arrive qu'à la fin. `correctionVisibility: deferred` ne règle que la
**peinture** (`showCorrection: corrected != null && visibility.paintsCorrection`, `:815`) —
le **verrou** reste posé, commenté explicitement `:822-824` (« Ne jamais mêler `visibility`
à ce gate : il porte le verrou d'interaction »).

⇒ Incompatibilité **structurelle**, pas cosmétique. Le socle est un formulaire à soumission
propre ; le site hôte est un champ contrôlé d'un formulaire d'examen.

### Conflits d'affordance qui s'ajouteraient

- **« Je ne sais pas » en double.** Le socle le monte inconditionnellement (`:771`) ;
  aucun paramètre ne le retire (les 17 params ne comportent rien de tel). Côté hôte, cette
  affordance est **au niveau page** : `white_exam_page.dart:228` → `ExamAnswer.iDontKnow`
  (`:778`), consommée par `_evaluateAnswer` (`:552 : if (answer.isIDontKnow) return 0;`).
- **Bouton « Soumettre » en double.** `_SubmitButton` est monté par `_ChoicesInput` (`:996`)
  et `_WrittenInput` (`:1300`) ; l'examen soumet depuis la barre de la page.
- **Notation.** Le socle émet la qualité lui-même (`onQualitySelected`, `_CorrectionSection`) ;
  l'hôte l'évalue côté page (`white_exam_page.dart:548-583`, retour `double`) puis alimente
  une génération d'explication IA (`white_exam_question_card.dart:304-347`).

---

## 4. RÉFUTATION C — perte de contenu riche sur DEUX des trois saisies

**D6 (QCM)** — le socle rend le libellé d'un choix en **texte brut** :
`_ChoiceRow` → `Expanded(child: Text(choice.content, textAlign: TextAlign.start))`
(`z_flashcard_answer_input.dart:1090`). Le `contentBuilder` n'a **qu'un seul site d'appel**,
et c'est la **question** :

```
$ grep -n "_contentBuilder\|contentBuilder" packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart
5:   (dartdoc)      108: (param)      136: (champ)
466-467: getter      746:  IgnorePointer(child: _contentBuilder(context, widget.card.question)),
```

Aucun slot pour les choix. **Grep négatif montré** :

```
$ grep -rn "choiceBuilder\|choicesBuilder\|ZChoiceBuilder" packages/zcrud_session/lib/
NEG: aucun slot de rendu riche pour les CHOIX dans zcrud_session (grep -> 0)
```

Or l'hôte rend **chaque choix** par un lecteur markdown/LaTeX :
`white_exam_question_card.dart:747-763` (`reviewRichReaderZcrud` ou `RichTextReaderScreen`,
facteurs 1.0), et `flashcard_repetition_widgets.dart:517-542` (facteur 1.2). Le corpus IFFD
contient des formules — migrer en l'état les afficherait **en source**. C'est exactement
l'écart déjà consigné côté hôte pour la carte (« R2 — le contenu riche est INJECTÉ »,
`zcrud/review_card_zcrud.dart:121-124`), mais ici **aucun point d'extension n'existe**.

**D8 (texte libre)** — le socle offre un `TextFormField` nu (`_WrittenInput`, `:1246-1291`,
`maxLines: null`, pas de valeur initiale). L'hôte offre un **éditeur Quill markdown** :
`MarkdownEditionField` (`:872-887`) — `fieldName`, `markdownValue` (valeur initiale
restaurée), `fieldLabel: "Votre réponse"`, `minLines: 5`, `maxLines: 15`, `isInline: true`,
`readOnly: widget.isSubmitted`. Sa classe est bien un éditeur riche :
`lib/data_crud/rich_text_editor/editors/markdown_edition_field.dart:50` →
`quill.QuillController? _quillController;`. Le socle documente d'ailleurs son refus
(`:1206-1213` : « `TextField` nu … Le patron est imité, pas le widget »).

⇒ Sur D6 et D8, la couverture est **partielle** et présentée comme totale.

---

## 5. RÉFUTATION D — les VRAIS sites sont AILLEURS, et ils sont DÉJÀ MIGRÉS

Le besoin « les trois saisies du flux de révision » a son site réel dans
`interactive_flashcard_repetition_card.dart` (1 205 l.), qui porte lui aussi ses trois
builders — `_buildQCMInput :686`, `_buildTrueFalseInput :788`, `_buildTextInput :891` —
**non cités par l'affirmation**. Or ce site est **déjà porté sur le socle**, derrière un
drapeau strangler :

```
:21   import 'package:zcrud_session/zcrud_session.dart' show ZFlashcardSubmission;
:412  zcrudFlagValue(reviewSessionUseZcrudProvider, fallback: kReviewSessionUseZcrudDefault, …)
:414  return ReviewAnswerZcrudView(…)
```

`ReviewAnswerZcrudView` (`zcrud/review_session_zcrud.dart:80-131`) monte bien
`ZFlashcardAnswerInput` (`:118`) avec `srsConfig: kIffdSrsConfig`, `contentBuilder`,
`onSubmitted`, `onAdvance`, et traduit `isLearningMode → ZReviewMode` (`:77-78`).
Drapeau `kReviewSessionUseZcrudDefault = false` (`:64`), bascule runtime par
`reviewSessionUseZcrudProvider` (`:73-76`), exposé en QA (`shared/zcrud/z_qa_flags.dart:289`).

⇒ L'affirmation « **sites hôte NON migrés (ils ne portent QUE le drapeau
reviewRichReader)** » est **fausse pour les sites qui comptent** et **exacte mais non
concluante pour ceux qu'elle cite** : le travail de portage de la saisie a déjà eu lieu en
W8g ; ce qui reste est une **bascule de flag + QA**, pas ~375 lignes à supprimer.

---

## 6. RÉFUTATION E — le décompte de lignes est faux

Extents mesurés (`awk` sur les bornes réelles de chaque méthode) :

| Site | Annoncé | Mesuré | Écart |
|---|---|---|---|
| `white_exam_question_card.dart` `_buildQCMInput` | 679-775 → 97 l. | **679-774 → 96 l.** | −1 |
| `white_exam_question_card.dart` `_buildTrueFalseInput` | 776-863 → 88 l. | **776-862 → 87 l.** | −1 |
| `white_exam_question_card.dart` `_buildTextInput` | 864-904 → 41 l. | **864-888 → 25 l.** | **−16** |
| `flashcard_repetition_widgets.dart` `_buildChoicesSection` | 484-632 → 149 l. | **484-631 → 148 l.** | −1 |
| **Total** | **~375 l.** | **356 l.** | −19 |

`:864-904` déborde de 16 lignes sur la dartdoc de `_explicationNettoyee()` (`:890-899`) et
sur son corps (`:900-…`), qui n'ont rien à voir avec la saisie.

Et sur ces **356 l.**, **148** (41 %) sont l'affichage en lecture seule de la §2, donc hors
sujet. Le gisement « saisie » réellement visé par la citation est de **208 lignes**, dont
aucune n'est migrable en l'état pour les motifs §3 et §4.

---

## 7. Verdict

**DÉMENTIE.** Le canal existe, tient sa dartdoc sur la table d'affordance, est exporté et
atteignable depuis IFFD au tag `v3.21.0`. Mais l'affirmation échoue sur quatre points
indépendants, dont trois suffisent seuls :

1. **Un quart des lignes citées n'est pas une saisie** (affichage lecture seule, grep négatif
   fourni) — migrer y ajouterait des affordances absentes.
2. **Contrôlé vs non contrôlé** : le socle n'a ni `initialAnswer`, ni `onChanged`, ni
   `isSubmitted` externe (grep négatif fourni), et se verrouille one-shot ; l'examen blanc
   exige la ré-éditabilité et une correction différée pilotée par la page.
3. **Couverture partielle du rendu** : pas de slot riche pour les libellés de choix (grep
   négatif fourni) ; `TextFormField` nu là où l'hôte a un éditeur Quill markdown restauré.
4. **Cible mal désignée + décompte gonflé** : les vrais sites
   (`interactive_flashcard_repetition_card.dart:686/788/891`) sont **déjà portés** derrière
   `reviewSessionUseZcrudProvider` ; le total réel est 356 l., pas ~375.

## Ce qui est vrai à la place

`ZFlashcardAnswerInput` couvre déjà — et est **déjà branché** dans IFFD, drapeau à `false` —
les trois saisies du **flux de répétition SRS interactif**
(`interactive_flashcard_repetition_card.dart`, ~226 l. legacy en `_buildQCMInput` /
`_buildTrueFalseInput` / `_buildTextInput`). L'action utile n'est pas une migration mais la
**bascule de `kReviewSessionUseZcrudDefault` + QA**, et deux CR socle pour lever les écarts
restants : **(a) un slot de rendu riche pour les libellés de choix** (le `contentBuilder`
n'atteint que la question, `:746`) ; **(b) un mode contrôlé** (`initialAnswer` /
`onAnswerChanged` / `isSubmitted` externe, et suppression optionnelle des boutons
« Soumettre » / « Je ne sais pas ») sans lequel `white_exam_question_card.dart` restera
non migrable.
