# Réfutation — saisies de réponse (QCM / vrai-faux / texte), quartier « épreuve »

**Date** : 2026-08-26 · **Rôle** : réfutateur · **Verdict : AFFIRMATION DÉMENTIE**

> ⚠️ Nom de fichier **tronqué** : le nom demandé faisait **339 octets**, au-delà de la
> limite ext4 de 255. Les deux extrémités demandées sont préservées. Nom complet visé :
> `refutation-Examens et évaluations (IFFD) — 3 quartiers : examen-échéance (administration + ExamModel + ZBackedExamRepository), épreuve (features/flashcards, runtime test/examen blanc), correction (notation IA 1-5). 26 fichiers de production, 9 913 lignes ; 12 fichiers de tests, 3 364 lignes.-Les-trois-saisies-de-r-ponse-QCM-vrai.md`

Affirmation attaquée : « le socle sait déjà le faire, par `ZFlashcardAnswerInput`
(17 params) » — gain annoncé **~452 lignes d'hôte supprimées**.

---

## 1. Ce qui RÉSISTE (vérifié, à ne pas rejouer)

| Point | Preuve sur disque | État |
|---|---|---|
| La classe existe à la ligne citée | `packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart:102` | ✅ |
| Ctor 17 paramètres | `:104-123` — `card, mode, srsConfig, contentBuilder, evaluationPort, allowSkipEvaluation, hintPort, revealStoredHint, hintPolicy, timerDisplay, timeLimit, advanceBehavior, autoAdvanceDelay, correctionVisibility, onSubmitted, onQualitySelected, onAdvance` = **17** (hors `super.key`) | ✅ |
| Routage par type **dans le corps** | `:789-816` — `switch (widget.card.type)` exhaustif **sans `default`**, 6 `ZFlashcardType` → `_ChoicesInput` / `_TrueFalseInput` / `_WrittenInput` (4 types écrits regroupés) | ✅ |
| Exporté par le barrel | `packages/zcrud_session/lib/zcrud_session.dart:65` | ✅ |
| Dépendance déclarée d'IFFD | `iffd/pubspec.yaml:412-416` (`zcrud_session`, `ref: v3.21.0`) et `:421-425` (`zcrud_study_kernel`, pour `ZReviewMode`) | ✅ |
| QCM **multi-sélection** modélisé | `:286` `ValueNotifier<Set<int>>` — ce n'est **pas** un choix unique | ✅ |
| `ZCorrectionVisibility.deferred` vise explicitement l'examen blanc | `z_correction_visibility.dart:35-42` | ✅ |
| Gain a11y réel | 8 `Semantics(` dans le socle **vs 0** dans `white_exam_question_card.dart` et `interactive_flashcard_repetition_card.dart` (grep `-c` : `0` et `0`) | ✅ |

Le canal est donc **réel, atteignable et non inerte**. La réfutation ne porte pas sur son existence.

---

## 2. Ce qui DÉMENT l'affirmation

### 2.1 🔴 Les libellés de CHOIX perdent le LaTeX — aucun slot pour l'éviter

Le socle rend chaque choix en **`Text` brut**, dans `_ChoiceRow` :

```dart
Expanded(
  child: Text(choice.content, textAlign: TextAlign.start),
)
```

Et `_ChoicesInput` **ne reçoit aucun `contentBuilder`** — ses cinq paramètres sont
`card, selected, correction, visibility, onSubmit` (`:920-935`). Grep négatif sur le
fichier entier (1 645 l.) :

```
answerBuilder    -> 0
inputBuilder     -> 0
writtenBuilder   -> 0
editorBuilder    -> 0
answerEditor     -> 0
```

`contentBuilder` n'est **pas** une échappatoire : il est consommé à **un seul site**,
`:746`, `IgnorePointer(child: _contentBuilder(context, widget.card.question))` — il
rend la **question**, et sous `IgnorePointer` (non interactif). Le typedef le confirme
(`zcrud_flashcard/lib/src/presentation/z_flashcard_content_slot.dart:41-44`), et la
dartdoc du défaut admet la limite : *« Ne rend jamais de markdown/LaTeX : un contenu
riche s'affiche tel quel, en texte. »*

Or **les deux fichiers hôtes rendent leurs choix richement** :

| Fichier | Rendu du libellé de choix | Échelle |
|---|---|---|
| `white_exam_question_card.dart:747-765` | `reviewRichReaderZcrud` / `RichTextReaderScreen` + `formula*ScaleFactor` | 1.0 |
| `interactive_flashcard_repetition_card.dart:686-787` | idem | 1.1 |

L'hôte déclare lui-même que le corpus porte des formules
(`review_session_zcrud.dart:95-96` : *« le défaut du socle est du texte brut, et le
corpus contient des formules LaTeX »*). Migrer le QCM afficherait donc la **source
LaTeX brute** dans chaque choix. C'est une régression fonctionnelle, pas un détail de style.

### 2.2 🔴 La saisie écrite perd l'éditeur Quill — non déclaré

Les deux hôtes utilisent `MarkdownEditionField` (`minLines: 5, maxLines: 15, isInline`) :
`white_exam_question_card.dart:872-887`, `interactive_flashcard_repetition_card.dart:892-909`.
C'est un **éditeur Quill** — `lib/data_crud/rich_text_editor/editors/markdown_edition_field.dart:6-10`
(`flutter_quill`, `QuillController`, `Document`, `quill.Delta`), `:51,63,72,83,119`.

Le socle oppose un **`TextFormField` nu** sur un `TextEditingController` (`_WrittenInput`).
Grep négatif : `initialAnswer 0 · initialText 0 · initialValue 0 · onChanged 0`.

⚠️ La table « négociation de surface » de l'hôte (`review_session_zcrud.dart:21-28`)
énumère **six** capacités laissées à leur défaut — elle **ne mentionne pas** cette perte.
La bascule du flag remplacerait donc silencieusement un éditeur riche par un champ texte.

### 2.3 🔴 `white_exam` est structurellement INVERSE du socle

Contrat de l'hôte (`white_exam_question_card.dart:26-28`) : **état piloté par le parent**.

```dart
final ExamAnswer? initialAnswer;              // réponse restaurée à la navigation
final bool isSubmitted;                        // soumission possédée par le PARENT
final Function(ExamAnswer)? onAnswerChanged;   // CHAQUE changement remonte
```

- Les choix restent **modifiables jusqu'à la fin de l'épreuve** : `enabled: !widget.isSubmitted` (`:724`), bascule libre add/remove (`:726-741`), puis `_notifyAnswerChanged()` (`:150-157`).
- **Aucune soumission par carte.** Grep négatif : l'unique `ElevatedButton` (`:602`) est *« Question suivante »* ; l'unique `onSubmit` (`:879`) est celui de l'éditeur markdown.

Le socle inverse les trois :

| Propriété | `white_exam` | `ZFlashcardAnswerInput` |
|---|---|---|
| Soumission | globale, par le parent | **par carte, one-shot** — `_submitLocked` `:334,549,573,657` |
| Après soumission | reste éditable | **verrouillé** — `onTap: corrected != null ? null : …` `:983-984` |
| Réponse initiale | `initialAnswer` restaurée | **aucun paramètre** (grep : `initialAnswer 0`) |
| Flux de changement | `onAnswerChanged` continu | `onSubmitted` **à la soumission seule** |
| Propriétaire de la correction | parent (`widget.isSubmitted`) | interne (`_correction.value = …` `:515`) |

Grep négatif décisif sur le socle : `isSubmitted -> 0`, `submitted -> 0`.

**`deferred` ne comble pas l'écart** — sa propre dartdoc le dit
(`z_correction_visibility.dart:5-14, 37-42`) : il gate *« le rendu seul »*, et
*« La soumission est bien enregistrée (et **la saisie verrouillée, une réponse par
carte**) »*. Il diffère la **peinture**, explicitement **pas le verrou**.

Pire pour le gain annoncé : en `deferred` *« la carte ne rend **jamais** la correction …
c'est l'hôte qui révèle la correction en fin d'examen »*. Or `white_exam` **peint** sa
correction par carte (fonds vert/rouge `:694-703`, `Icons.check_circle` `:767-769`).
L'hôte devrait donc **ré-implémenter** ce qu'il est censé supprimer — une part
substantielle des 97 lignes du QCM.

### 2.4 ⚠️ La moitié du gain est déjà encaissée, et bloquée

Le portage de la carte de révision **existe déjà** : `review_session_zcrud.dart`
(131 l., `ReviewAnswerZcrudView` `:77-131`, montage `ZFlashcardAnswerInput` `:118-129`),
branché à `interactive_flashcard_repetition_card.dart:414`.

Le triplet legacy n'est encore sur disque que parce que le flag vaut `false`
(`kReviewSessionUseZcrudDefault`, `:55`). Ces ~225 lignes relèvent donc d'un
**basculement + suppression**, pas d'un travail de socle à faire — et le basculement
est retenu par §2.1 et §2.2.

`white_exam_question_card.dart`, lui, **n'est pas porté**. Grep : ses seules
occurrences `zcrud` (`:6,7,484-486,747-750,1071-1074`) concernent le **lecteur riche**
(`reviewRichReaderZcrud`), jamais la saisie.

### 2.5 ⚠️ Le décompte de lignes est surévalué (~4 %)

| Bloc | Plage réelle | Lignes | Annoncé |
|---|---|---|---|
| `white_exam._buildQCMInput` | 679-775 | 97 | 97 ✅ |
| `white_exam._buildTrueFalseInput` | 776-863 | 88 | 88 ✅ |
| `white_exam._buildTextInput` | **864-888** | **25** | 41 ❌ |
| `interactive._buildQCMInput` | 686-787 | 102 | 102 ✅ |
| `interactive._buildTrueFalseInput` | 788-890 | 103 | 103 ✅ |
| `interactive._buildTextInput` | **891-910** | **20** | 21 ≈ |
| **Total** | | **435** | 452 |

La borne haute annoncée pour `white_exam` (904) tombe **à l'intérieur de la dartdoc**
de `_explicationNettoyee()` : la fonction se ferme à `:888` (vérifié `:886-892`).

---

## 3. Verdict

**DÉMENTIE.** Le canal est réel, exporté, atteignable et fait ce que sa dartdoc annonce
— mais il **ne couvre pas le besoin réel de l'hôte** :

1. il rend les **libellés de choix en `Text` brut**, sans slot d'injection, alors que les deux hôtes y rendent du LaTeX ;
2. il rend la **saisie écrite en `TextFormField` nu**, là où les deux hôtes montent un **éditeur Quill** ;
3. il est **structurellement inverse** du modèle `white_exam` (soumission par carte et verrou one-shot contre soumission globale, révision libre et état piloté par le parent) — et `deferred` gate le rendu, **pas** le verrou ;
4. la moitié du gain est **déjà portée** (flag `false`), l'autre moitié (`white_exam`) exigerait de **ré-implémenter la correction** que la migration prétend supprimer ;
5. le décompte annoncé est **435 l., pas 452**.

**Le gain net migrable aujourd'hui est nul** tant que le socle n'expose pas (a) un slot
de rendu des libellés de choix, (b) un slot d'éditeur de réponse, (c) un mode d'état
piloté par l'hôte (`initialAnswer` / `isSubmitted` externe / `onAnswerChanged`).
Ce sont trois évolutions du socle, pas une migration d'hôte.

---

## 4. Ce qui reste NON VÉRIFIÉ (dit, pas deviné)

- Le quartier **examen-échéance** (`ExamModel`, `ZBackedExamRepository`) et le quartier **correction (notation IA 1-5)** n'ont pas été instruits : l'affirmation attaquée ne portait que sur les trois saisies.
- Les volumes globaux du domaine (26 fichiers / 9 913 l. ; 12 tests / 3 364 l.) n'ont pas été recomptés.
- **Aucun test n'a été lancé**, dans aucun dépôt (consigne).
