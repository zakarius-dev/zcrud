# Réfutation — Révision (IFFD) / « Cesser d'envoyer les QCM et vrai/faux à l'IA »

**Date** : 2026-08-26  
**Rôle** : réfutateur (défaut sur le doute = réfutation)  
**Tag épinglé par IFFD** : `v3.21.0` (`iffd/pubspec.yaml:307-309, 413-416`)  
**Verdict** : ❌ **DÉMENTIE** — le canal existe et fait ce qu'on lui prête, mais **deux des trois
promesses opérationnelles sont fausses** (« = exactement maxQuality/minQuality » et « aucune ligne
nouvelle »), et un **troisième écart non déclaré** (plafond d'indices) est actif dès la bascule.

---

## 1. Ce qui RÉSISTE (vérifié à l'octet, au tag épinglé)

### 1.1 Le canal existe, aux lignes citées

`packages/zcrud_flashcard/lib/src/domain/z_flashcard_local_evaluation.dart` (135 lignes) :

| Symbole | Ligne annoncée | Ligne mesurée | ✔ |
|---|---|---|---|
| `zIsLocallyEvaluatedType` | :36 | **:36** | ✅ |
| `zIsSingleChoiceQcm` | :56 | **:56** | ✅ |
| `zCorrectChoiceIndexes` | :66 | **:66** | ✅ |
| `zEvaluateLocally` | :96 | **:96** | ✅ |

`packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart` (1 645 lignes) :

| Site | Ligne annoncée | Ligne mesurée | ✔ |
|---|---|---|---|
| routage par le type | :564 | **:564** `if (zIsLocallyEvaluatedType(widget.card.type)) { _submitLocal(); return; }` | ✅ |
| évaluation locale | :539 | **:539** `final raw = zEvaluateLocally(` | ✅ |
| garde de rendu QCM | — | :949 `zCorrectChoiceIndexes(card).isEmpty` | ✅ |
| choix unique | — | :955 `final single = zIsSingleChoiceQcm(card);` | ✅ |
| V/F auto-soumis | — | :802 `onAnswer: (value) => _submitLocal(answeredTrue: value)` | ✅ |

**Présence au tag réellement consommé** (pas seulement dans l'arbre de travail) :
`git show v3.21.0:…z_flashcard_local_evaluation.dart` → mêmes lignes 36/56/66/96 ;
`git show v3.21.0:…z_flashcard_answer_input.dart` → `:564` identique.

### 1.2 Le CORPS fait bien ce qu'on lui prête (lu, pas déduit de la dartdoc)

- **Routage par le type, avant tout réseau** : `_submitWritten` (:558) commence par le `switch` du
  domaine ; le port n'est atteignable qu'**après** ce `return` (`:583 if (port != null)`). Le
  routage ne dépend pas du résultat de l'évaluation — il est structurellement impossible qu'un QCM
  atteigne le port.
- **Égalité ensembliste STRICTE** : `_setEquals` (:134) = `a.length == b.length && a.containsAll(b)`.
  Pas une inclusion.
- **Garde « QCM sans choix correct ⇒ `null` »** : :106-110, `if (correct.isEmpty) return null;` —
  et `_submitLocal` (:547) `if (raw == null) return;` avant de poser le verrou.
- **Bornes lues sur la config** : `_qualityFor` (:130) `exact ? config.maxQuality : config.minQuality`.

### 1.3 Atteignable depuis l'hôte

- Barrel : `packages/zcrud_flashcard/lib/zcrud_flashcard.dart:170` →
  `export 'src/domain/z_flashcard_local_evaluation.dart';` (présent aussi au tag).
- `iffd/pubspec.yaml` : section `dependencies:` (l. 10-532) déclare `zcrud_flashcard` (l. 328-333)
  **et** `zcrud_session` (l. 412-416), tous deux `ref: v3.21.0`.

### 1.4 Le constat porté sur l'hôte est exact

`iffd/lib/src/presentation/features/flashcards/widgets/interactive_flashcard_repetition_card.dart`
(1 205 lignes) :

- `:142` `quality = await _evaluateAnswer();` — appelé dès que `quality == null`, **sans aucun test
  de type**.
- `:206` `Future<int> _evaluateAnswer()` ; `:219` appel réel à
  `…read(aiRepositoryProvider).evaluateFlashcardAnswer(…)`, passant `questionType:` en simple
  paramètre informatif.
- `:246` `return _manualEvaluateAnswer();` — atteint **uniquement** après le `try/catch` (:215-244)
  ou si le score IA sort de `[1,5]`. Définition réelle du repli : **:287** (l'affirmation cite :246,
  qui est le site de retombée — exact sémantiquement, imprécis comme référence).
- `QuestionType` n'a **que quatre** valeurs (`multipleChoice`, `trueOrFalse`, `openQuestion`,
  `exercise` — cf. les quatre `case` de :249-268) : « les quatre types » est juste.
- Repli manuel : `:301` `return isCorrect ? 5 : 1;` (QCM), `:305` idem (V/F), `:310` `return 3;`
  (ouvertes/exercice).
- **La garde « QCM sans choix correct » est bien une NOUVEAUTÉ** : à :293-301, si
  `correctChoicesIndices` est vide et `_selectedChoices` vide, alors `0 == 0` et `every` sur vide
  vaut `true` ⇒ `isCorrect == true` ⇒ **5 pour qui ne coche rien**. Le socle rend `null`.

### 1.5 Le jumeau est réellement câblé

- `interactive_flashcard_repetition_card.dart:411-414` : premier geste de `build()`,
  `if (widget.useZcrud ?? zcrudFlagValue(reviewSessionUseZcrudProvider, …)) { return ReviewAnswerZcrudView(…); }`.
  Le `return` anticipé rend **tout** l'arbre legacy (l. 460-1205) et donc `_handleSubmit` /
  `_evaluateAnswer` **inatteignables**. La bascule coupe bien l'appel IA.
- `review_session_zcrud.dart:118-130` consomme `ZFlashcardAnswerInput` en lui passant
  `srsConfig: kIffdSrsConfig`.
- Bonus en faveur du besoin : chez l'un des deux appelants
  (`flashcard_repetition_widgets.dart:123-126`), `onSubmit` est un **placeholder vide**
  (« For now just a placeholder ») — en modes `test`/`whiteExam`, le score IA est calculé **puis
  jeté**. Une partie du trafic IA que la CR veut supprimer est déjà du pur gaspillage.

---

## 2. Ce qui est DÉMENTI

### 2.1 ❌ « `isCorrect ? 5 : 1` = exactement maxQuality/minQuality de `zEvaluateLocally` »

**La moitié basse de l'égalité est fausse sous la configuration réellement utilisée par IFFD.**

- `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart:27` → `this.minQuality = 0` (défaut).
- `iffd/lib/src/domain/models/flashcard_repetition_info.dart:57` →
  `const ZSrsConfig kIffdSrsConfig = ZSrsConfig(overdueBonusFactor: 0.5);` — **`minQuality` n'est pas
  redéfini**, il vaut donc **0**.
- `review_session_zcrud.dart:124` passe explicitement `srsConfig: kIffdSrsConfig`.

⇒ Une mauvaise réponse à un QCM/V/F passe de **1 (legacy)** à **0 (socle)**. Trois conséquences
mesurées, aucune mentionnée par l'affirmation :

1. **0 n'existe pas dans l'échelle d'IFFD.** `FlashcardRepetitionQuality` commence à
   `fail(1, 'Compliqué', …)` (`flashcard_repetition_info.dart:181-188`). Aucune valeur 0.
2. **Perte silencieuse de la note d'échec.** `flashcard_repetition_info.dart:356-358` :
   `quality: FlashcardRepetitionQuality.values.firstWhereOrNull((el) => el.value == quality) ?? this.quality`.
   Avec `quality == 0`, `firstWhereOrNull` rend `null` et le `??` **conserve la note précédente** au
   lieu d'enregistrer l'échec. Pas de crash (tous les sites sont en `firstWhereOrNull` —
   `folder_document_learning_info.dart:35,59`, `flashcard_repetition_info.dart:314,357`), donc une
   dérive **muette**.
3. **Pénalité SM-2 48 % plus lourde.** `z_sm2_scheduler.dart:78` :
   `ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))`
   - q = 1 → `0.1 - 4 × 0.16` = **−0,54**
   - q = 0 → `0.1 - 5 × 0.18` = **−0,80**

🔴 **IFFD a documenté ce piège exact, puis ne l'a pas appliqué ici** :
`srs_quality_zcrud.dart:70-80` — « l'échelle SM-2 du socle commence à **0**, pas à 1. Un clamp à 1
aurait donc **remonté un 0 silencieusement** […] et aucun écran ne l'aurait montré. »

**Correction requise** : `ZSrsConfig(overdueBonusFactor: 0.5, minQuality: 1)`. Une ligne — que
l'affirmation ne mentionne pas, et sans laquelle la bascule n'est pas une parité.

### 2.2 ❌ « Aucune ligne nouvelle : il suffit de basculer le drapeau `reviewSession` »

Le besoin énoncé est de cesser d'envoyer **les QCM et vrai/faux**. La bascule cesse d'envoyer
**tout**.

`review_session_zcrud.dart` ne transmet **aucun** `evaluationPort` (build l. 118-130), et c'est
délibéré et gelé :
- `:27` — table de négociation : `| evaluationPort | null | l'évaluation reste app-side |`
- `iffd/test/w8g/review_session_routing_test.dart:164` — `expect(input.evaluationPort, isNull);`

Conséquence lue dans le socle (`z_flashcard_answer_input.dart:583, 632-640`) : avec `port == null`,
aucun appel n'a lieu, `evaluation` reste `null`, donc
`raw = widget.srsConfig.passThreshold` (**3**) + libellé « Évaluation indisponible — note neutre
proposée. »

⇒ **Les questions ouvertes et les exercices perdent leur note IA** et tombent à un 3 plat. Or c'est
précisément la moitié des types que la CR veut **conserver** sur l'IA.

**GREP NÉGATIF MONTRÉ** — aucun port d'évaluation ni d'indice n'est implémenté par IFFD :

```
$ cd /home/zakarius/DEV/iffd
$ grep -rn "ZFlashcardAnswerEvaluationPort\|ZFlashcardHintPort\|evaluationPort\|hintPort" \
        --include='*.dart' lib/ test/
lib/src/presentation/features/flashcards/zcrud/review_session_zcrud.dart:27:// | `evaluationPort` | `null` | l'évaluation reste app-side |
test/w8g/review_session_routing_test.dart:164:      expect(input.evaluationPort, isNull);
```

**2 occurrences, zéro implémentation** : un commentaire et une assertion de nullité.

Pour tenir le besoin réel, l'hôte doit **écrire** un adaptateur
`ZFlashcardAnswerEvaluationPort` (`z_flashcard_answer_evaluation_port.dart:218-226`,
`Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(…)`) au-dessus de
`aiRepositoryProvider.evaluateFlashcardAnswer`, dont la forme actuelle est un **callback**
(`onComplete(result, completed, {hasError = false})`, `:227-234`) à replier en `Future` + `ZResult`,
avec construction d'un `ZFlashcardAnswerEvaluation(feedback, suggestedQuality, isCorrect)`.
Ce n'est pas « aucune ligne nouvelle ».

### 2.3 ❌ Écart NON DÉCLARÉ, actif dès la bascule : le plafond d'indices pénalise

`review_session_zcrud.dart:26` affirme : `| hintPolicy | défaut socle | le legacy compte les indices
sans les pénaliser |`. **Le défaut du socle n'est pas neutre.**

- `z_flashcard_answer_input.dart:113` → `this.hintPolicy = const ZHintPenaltyPolicy()`
- `:502` → toute émission passe par `_finalQuality` → `zApplyHintCeiling`
- `z_hint_penalty.dart:110-122` → `ceiling = max(config.maxQuality - used, floor)` puis
  `min(rawQuality, ceiling)`
- `z_hint_penalty.dart:45` → `floor: null` ⇒ plancher dérivé `passThreshold - 1` = **2**

⇒ Avec `maxQuality = 5` : 1 indice ⇒ plafond **4**, 2 indices ⇒ **3**, ≥ 3 ⇒ **2**.
Le legacy rend **5** quel que soit le nombre d'indices (`_manualEvaluateAnswer:301`, aucune lecture
de `_currentHintIndex`).

Et le chemin est **atteignable** : `_hintsUsed` (:480) compte `_shownHints`, alimenté par l'indice
**stocké** (:366-368) même sans `hintPort` ; or `indice` **est** mappé vers `hint` —
`iffd/lib/src/data/repositories/z_backed_flashcard_repository.dart:211` `hint: card.indice` (table de
correspondance :116). Une carte IFFD portant un `indice` fait donc réellement passer un QCM parfait
de **5 à 4**.

### 2.4 ⚠️ Pertes collatérales du même drapeau (non mentionnées)

| Perte | Preuve |
|---|---|
| **Indices générés par IA** | aucun `hintPort` passé (grep § 2.2) ⇒ `_requestHint` (`z_flashcard_answer_input.dart:678-682`) sert l'indice stocké puis `return`. Le legacy appelle `aiRepositoryProvider.generateFlashcardHint` (`:349`). |
| **Feuille de confirmation SRS à 5 paliers** | `srsQualityUseZcrudProvider` vit dans `_handleSubmit` (`:163-181`), c.-à-d. sur la **branche legacy seule**. Les deux drapeaux sont **mutuellement exclusifs** : basculer `reviewSession` rend W8f inatteignable. (Sans régression *au défaut*, les deux étant `false`.) |
| **Toute la chrome de carte** | `ReviewAnswerZcrudView.build` (`:116-130`) rend **uniquement** `ZFlashcardAnswerInput`. Le legacy rendait en plus `_buildHeader` (:580), `_buildInstructionBadge` (:609), `_buildHintSection` (:912), `_buildAnswerFeedback` (:963), `_buildActionButtons` (:998), `_buildFooter` (:1130). |

### 2.5 ⚠️ Une « nouveauté » qui n'en est pas

L'affirmation présente « l'ÉGALITÉ ENSEMBLISTE STRICTE » comme un apport. Elle existe **déjà** côté
hôte : `_manualEvaluateAnswer:296-301` fait `length ==` + `every(contains)`. Le gain est réel vis-à-vis
du **chemin IA**, nul vis-à-vis du **repli**. Seule la garde « QCM sans choix correct ⇒ `null` »
(§ 1.4) est un apport authentique.

### 2.6 Le chiffre de ~894 lignes : plausible, non réfuté

Surface legacy réellement supprimable : `:128-392` (≈ 265 l. — `_handleSubmit`, `_handleIDontKnow`,
`_evaluateAnswer`, `_getCorrectAnswerText`, `_getUserAnswerText`, `_manualEvaluateAnswer`,
`initState`/`dispose`, `_requestHint`) + `:460-1205` (≈ 746 l. — arbre legacy et ses dix `_build*`),
soit ≈ 1 011 lignes brutes sur 1 205. **~894 est du bon ordre de grandeur** ; je ne réfute pas sur ce
point. Il faut en retrancher les lignes nouvelles des § 2.1-2.2.

---

## 3. Verdict

**DÉMENTIE.** Le canal socle est **réel, exact, exporté, atteignable au tag épinglé, et déjà
consommé par le jumeau** — l'ossature de l'affirmation tient (§ 1). Ce qui ne tient pas, ce sont ses
**deux promesses opérationnelles** :

1. **« = exactement maxQuality/minQuality »** est faux : sous `kIffdSrsConfig`, `minQuality = 0` et
   non 1 — dérive silencieuse de la note d'échec (note précédente conservée) et pénalité d'EF
   passant de −0,54 à −0,80.
2. **« Aucune ligne nouvelle »** est faux : la bascule coupe l'IA pour **les quatre** types, pas
   pour deux. Rétablir l'évaluation IA des questions ouvertes/exercices exige un adaptateur
   `ZFlashcardAnswerEvaluationPort` **qui n'existe pas** (grep négatif montré, 2 occurrences, zéro
   implémentation).
3. Bonus non déclaré : le **plafond d'indices par défaut** pénalise (5 → 4 dès un indice) alors que
   la note de portage affirme le contraire.

**Ce qui est vrai à la place** : le socle sait déjà router par le type et évaluer localement QCM/V/F
— strictement mieux que l'hôte (garde « aucun choix correct »). Mais la migration coûte **trois
gestes**, pas zéro : (a) `ZSrsConfig(overdueBonusFactor: 0.5, minQuality: 1)` ; (b) un adaptateur
`ZFlashcardAnswerEvaluationPort` sur `aiRepositoryProvider.evaluateFlashcardAnswer` pour conserver
l'IA sur `openQuestion`/`exercise` ; (c) une `hintPolicy` neutre — ou l'acceptation explicite du
plafond. Sans (b), la CR ne fait pas « cesser d'envoyer les QCM et vrai/faux à l'IA », elle fait
« cesser d'utiliser l'IA ».
