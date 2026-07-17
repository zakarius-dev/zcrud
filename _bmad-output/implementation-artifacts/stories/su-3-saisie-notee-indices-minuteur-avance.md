---
baseline_commit: 9ea262f
---

# Story SU-3 : Saisie interactive notée, indices, minuteur et avance

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an **apprenant**,
I want **répondre réellement à la carte, demander un indice, et être noté**,
so that **je m'auto-évalue au lieu de seulement retourner la carte.**

**Couvre :** FR-SU2, FR-SU3, FR-SU4, FR-SU5.
**Source de spécification :** `epics.md` § Epic 1 → **Story 1.3** (ACs repris, jamais réinventés).
**Ligne du sprint-status** (l.455) : `[XL][A — après su-2] FR-SU2/3/4/5 QCM+VF LOCAUX (jamais l'IA,
AD-35) ; port éval ADVISORY {feedback,suggestedQuality,isCorrect?} n'écrit JAMAIS le SRS ; indices:
stocké puis port, plafond LOCAL en dernier (AD-36) ; ZTimerDisplay ; ZCardAdvanceBehavior défaut par
mode ; SM-1 sur la saisie`.

---

## Contexte & décisions verrouillées (à NE PAS ré-arbitrer)

**Place dans le séquencement** : 2ᵉ story du **workstream (A)** (`zcrud_flashcard`, `zcrud_session`,
`zcrud_study_kernel`), après su-2 (**`done`**). Les workstreams **(B)** su-11 (`zcrud_export`,
`zcrud_export_ui`) et **(C)** su-12 (`zcrud_mindmap`) tournent **en parallèle sur des packages
disjoints** — d'où l'interdiction absolue de toucher leurs fichiers.

### 🎯 Le point de conception n°1 : L'ARÈNE DES GESTES (saisie vs révélation)

**C'est le risque central de cette story, et il est déjà documenté par un HIGH réel.** Le
code-review de su-2 (**D1**) a démasqué ceci : avec le chemin d'usage que su-2 documente verbatim
(`contentBuilder: ZFlashcardMarkdownContent.builder()`), le `QuillEditor` **gagnait l'arène des
gestes** contre l'`InkWell` de la carte ⇒ `onRevealChanged` ne recevait rien, **la réponse
n'apparaissait jamais** — avec 328/328 verts. Le correctif fut un `IgnorePointer` sur le sous-arbre
du slot (`z_flashcard_review_card.dart:261`), légitime **parce que « su-2 affiche »**.

**su-3 introduit la saisie : le contenu doit redevenir interactif — mais PAS n'importe où.**
L'arbitrage est tranché ainsi, **par construction plutôt que par priorité de geste** :

| Zone | Régime de geste | Pourquoi |
|---|---|---|
| Contenu de carte (slot AD-40 : question, choix, explication) | **`IgnorePointer` MAINTENU** | c'est de l'**affichage** même en su-3 ; sans cela le `QuillEditor` vole le geste aux contrôles de saisie (rejeu exact de D1) |
| **Contrôles de saisie** (cases QCM, boutons V/F, champ de rédaction, bouton Indice, bouton « Je ne sais pas ») | **SEULS interactifs** | ce sont les **seuls** capteurs de geste de la surface |
| Révélation par tap (`InkWell` de carte, `_toggle`) | **ABSENTE de la surface de saisie** | 🔒 **la révélation n'est PAS un tap en su-3 : elle est CAUSÉE par la SOUMISSION** |

🔒 **Règle** : `ZFlashcardAnswerInput` **ne pose AUCUN tap-to-reveal**. « Taper pour révéler » et
« taper pour répondre » sont des régimes **mutuellement exclusifs** — un apprenant noté ne peut pas
dévoiler la réponse d'un tap (ce serait tricher **et** voler le geste au contrôle de saisie). Le
conflit n'est donc **pas arbitré, il est dissous** : les deux surfaces sont **disjointes**.
`ZFlashcardReviewCard` (su-2) reste la surface **d'affichage** avec sa révélation par tap ;
`ZFlashcardAnswerInput` (su-3) est la surface **de saisie**, sans révélation par tap. Un hôte qui
compose les deux les compose en **frères** (sous-arbres disjoints) ⇒ **aucune arène commune**.

🚫 **Interdit absolu** : « régler » l'arène en **retirant l'`IgnorePointer` de su-2** ou en
affaiblissant ses tests. C'est le correctif d'un **HIGH réel** ; une garde de non-régression est
exigée (AC9). *On ne modifie jamais un test/fix pour taire un défaut réel* (leçon **D3** de su-2 :
un débordement `RenderFlex` authentique avait été masqué ainsi).

### 🔒 Placement des paquets — CONTRAINT PAR LE GRAPHE, pas par goût (vérifié sur disque)

Deux faits d'arêtes **réelles** commandent tout le découpage de cette story :

```bash
grep -n "zcrud_flashcard" packages/zcrud_study/pubspec.yaml     # → l.? `zcrud_flashcard: ^0.2.1`  RC=0
grep -n "zcrud_flashcard" packages/zcrud_session/pubspec.yaml   # → l.52 `zcrud_flashcard: ^0.2.1` RC=0
grep -rn "zcrud_study\b" packages/zcrud_flashcard/pubspec.yaml  # RC=1 (seul `zcrud_study_kernel`)
```

1. **`zcrud_study` DÉPEND DE `zcrud_flashcard`** ⇒ `zcrud_flashcard` **ne peut pas voir**
   `zcrud_study`. Les ports de su-3 parlent `ZFlashcardType`/`ZFlashcard` (types de
   `zcrud_flashcard`) ⇒ ils **ne peuvent pas** vivre à côté de `ZFlashcardGenerationPort`
   (`zcrud_study`), ni dans `zcrud_study_kernel` (qui ignore `ZFlashcardType`). **`zcrud_flashcard`
   est le seul foyer possible** — ce n'est pas une préférence, c'est le graphe (AD-1).
2. **`zcrud_session` DÉPEND DE `zcrud_flashcard`** ⇒ la surface de saisie, elle, doit vivre dans
   **`zcrud_session`** : l'AC « **un bouton SRS est pré-sélectionné** » (epic 1.3) impose de rendre
   **`ZSrsQualityButtons`**, qui vit dans `zcrud_session/presentation` et est **inatteignable**
   depuis `zcrud_flashcard`. Les deux seules alternatives sont **interdites** : (i) déférer la
   pré-sélection à su-4 ⇒ AC2 de l'epic non couvert par sa propre story ; (ii) redéclarer des
   boutons de qualité dans `zcrud_flashcard` ⇒ **seconde implémentation** (interdit).

⇒ **Découpage imposé** (aucune arête nouvelle, `graph_proof`/CORE OUT=0 inchangés) :

| Couche | Package | Contenu |
|---|---|---|
| **Domaine** (ports + fonctions **pures**) | `zcrud_flashcard/lib/src/domain/` | ports éval/indices + VOs, évaluation **locale** QCM/VF, plafond d'indices |
| **Présentation** (surface + variantes) | `zcrud_session/lib/src/presentation/` | `ZFlashcardAnswerInput`, `ZTimerDisplay`, `ZCardAdvanceBehavior` + table de défaut ; retouche **additive** de `ZSrsQualityButtons` |

**AUCUN `pubspec.yaml` n'est modifié par cette story** (toutes les arêtes préexistent ; **aucune**
dépendance tierce — la contre-métrique du PRD n'autorise que `flutter_card_swiper` (su-4), `confetti`
(su-5) et `printing` (su-11)).

### Périmètre RÉEL vérifié sur disque (consommer — ne JAMAIS recréer)

| Symbole | Existe ? | Emplacement RÉEL vérifié |
|---|---|---|
| `ZFlashcardType` (**6 valeurs**) | ✅ | `zcrud_flashcard/lib/src/domain/z_flashcard_type.dart:20` |
| `ZFlashcard` (`question`/`answer`/`isTrue`/`choices`/`explanation`/**`hint`**/`isReadOnly`) | ✅ | `zcrud_flashcard/lib/src/domain/z_flashcard.dart:175` (`hint`) |
| `ZChoice` (`content`, `isCorrect`) | ✅ | `zcrud_flashcard/lib/src/domain/z_choice.dart:25` |
| **`ZSrsConfig`** — **propriétaire de l'échelle** : `passThreshold=3`, `minQuality=0`, `maxQuality=5`, **`clampQuality()`** | ✅ (su-1) | `z_srs_config.dart:26-28`, **`clampQuality` `:129`** |
| `ZQualityScale.fromConfig` (**dérive**, jamais redéclarer) | ✅ (su-1) | `zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:53` |
| `ZSrsQualityButtons` (`scale`, `onQualitySelected`, `passThreshold`, `buttonKeyPrefix`) | ✅ | `.../z_srs_quality_buttons.dart:103-147` |
| `ZFlashcardContentBuilder` + `ZFlashcardDefaultContent.builder` (**slot AD-40**) | ✅ (su-1) | `zcrud_flashcard/lib/src/presentation/z_flashcard_content_slot.dart:41,65` |
| `ZFlashcardReviewCard` (**surface d'AFFICHAGE — su-3 ne la mute pas**) | ✅ (su-2) | `zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart` |
| **`zReduceMotionOf(context)`** (**primitive UNIQUE du repo**) | ✅ (su-2) | `zcrud_flashcard/lib/src/presentation/z_reduce_motion.dart:32` |
| `ZReviewMode` (**6 valeurs** : `spaced,learn,list,test,whiteExam,cramming`) | ✅ | `zcrud_study_kernel/lib/src/domain/z_review_mode.dart:26` |
| `ZResult<T>` = `Either<ZFailure,T>` (AD-5) | ✅ | utilisé en `zcrud_flashcard/lib/src/data/z_flashcard_repository.dart` |
| `ZFlashcardGenerationPort` (**patron de port à imiter** : `abstract interface class`, `Future<ZResult<…>>`) | ✅ | `zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:89` |
| `label(context, key, fallback:)` (l10n) | ✅ | `zcrud_core/lib/src/presentation/l10n/z_localizations.dart:288` |
| `ZcrudTheme.of` / `.fallback` | ✅ | `zcrud_core/lib/src/presentation/theme/z_theme.dart:295` |
| `minTarget = 48` + `Semantics` (**patron a11y**) | ✅ | `.../z_srs_quality_buttons.dart:197,212` |
| `ZTextFieldWidget` (**patron SM-1**, `AutovalidateMode.onUserInteraction`, controller **détenu par l'hôte**) | ✅ | `zcrud_core/lib/src/presentation/edition/families/z_text_field_widget.dart:37,44` |
| 🔴 **`z_widgets_purity_test.dart`** — garde **EXISTANTE** qui bannit `.apply(`/`.reviewCard(`/`ZRepetitionStore` + imports de moteur dans **tout** `zcrud_session/lib/src/presentation/**` | ✅ | `zcrud_session/test/presentation/z_widgets_purity_test.dart:34-49` |
| 🔴 **`z_widgets_hardcode_scan_test.dart`** — garde **EXISTANTE** : zéro `Colors.`/`Color(0x`, zéro API non-directionnelle, zéro `ListView(children:)` sur **tout** `presentation/**` | ✅ | `zcrud_session/test/presentation/z_widgets_hardcode_scan_test.dart:31-52` |

### Absences PROUVÉES par grep négatif (commandes rejouables, RC cité)

Le dev agent **ne doit pas chercher** ces symboles : **ils n'existent pas, ils sont à créer**.

```bash
# PREUVE A — le port d'évaluation n'existe NULLE PART → RC=1 (à créer, cf. AC2)
grep -rn "ZFlashcardAnswerEvaluationPort" packages/ --include="*.dart"   # RC=1 ✅
# PREUVE B — le port d'indices n'existe NULLE PART → RC=1 (à créer, cf. AC5)
grep -rn "ZFlashcardHintPort" packages/ --include="*.dart"               # RC=1 ✅
# PREUVE C — aucun minuteur nulle part (aucun `Stopwatch` dans TOUT le repo) → RC=1
grep -rn "Stopwatch" packages/ --include="*.dart"                        # RC=1 ✅
# PREUVE D — ZTimerDisplay / ZCardAdvanceBehavior n'existent pas → RC=1
grep -rn "ZTimerDisplay" packages/ --include="*.dart"                    # RC=1 ✅
grep -rn "ZCardAdvanceBehavior" packages/ --include="*.dart"             # RC=1 ✅
# PREUVE E — aucun `suggestedQuality` / `hintsUsed` / `errorKind` de PROD (1 seul match: un COMMENTAIRE de test)
grep -rn "suggestedQuality" packages/ --include="*.dart"  # → z_srs_scheduler_test.dart:44 (prose) SEUL
grep -rn "hintsUsed\|errorKind" packages/ --include="*.dart"            # RC=1 ✅
# PREUVE F — `ZFlashcardGenerationPort` EXISTE (le seul port IA flashcard livré) → RC=0
grep -rln "ZFlashcardGenerationPort" packages/ --include="*.dart"        # RC=0 (zcrud_study) ✅
# PREUVE G — `ZSrsQualityButtons` n'a AUCUNE notion de sélection (à ajouter ADDITIVEMENT, AC2)
grep -n "selected\|selectedQuality" packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart  # RC=1 ✅
```

### 🔴 AD-33 — la surface d'écriture SRS RÉELLE, et pourquoi le risque est LOCAL

`ZSessionReviewer` vit dans `zcrud_session/lib/src/domain/z_session_reviewer.dart` (**seam unique
d'écriture SRS**). Mais **le vrai danger de su-3 n'est pas là** : `zcrud_flashcard` **contient
lui-même** les moyens d'écrire le SRS —

```bash
grep -rlnE "class ZSm2Scheduler|ZSrsScheduler|class ZRepetitionStore" packages/zcrud_flashcard/lib/
# → z_sm2_scheduler.dart · z_srs_scheduler.dart · z_repetition_store.dart   (RC=0)
```

⇒ un dev pressé **peut** appeler `ZSrsScheduler.apply` / `ZRepetitionStore` **directement** depuis
la surface de saisie : ce serait la **porte dérobée exacte** qu'AD-33 interdit (« jamais
`ZSrsScheduler.apply` en direct, jamais un store en champ »). su-3 **n'écrit rien** : il **émet**
une soumission advisory ; **su-4** branche `onQualitySelected → ZSessionReviewer.reviewCard`.

🟢 **BONNE NOUVELLE — la garde existe DÉJÀ, ne la réécris PAS** : `z_widgets_purity_test.dart:34-49`
scanne **récursivement** `zcrud_session/lib/src/presentation/**` (**« jamais une liste figée : un
futur widget de présentation est capté sans édition du test »**, `:16-18`) et bannit déjà
`.apply(`, `.reviewCard(`, `ZRepetitionStore` + les imports de moteur. **`ZFlashcardAnswerInput`
naît donc gardé.** ⇒ su-3 **ÉTEND** cette garde (T4bis), il n'en crée **aucune** en parallèle
(**réinvention interdite**). Deux trous réels à combler :
- `_bannedWriteSymbols` **ignore** `ZSrsScheduler`/`ZSm2Scheduler` (seul `.apply(` les attrape
  indirectement) ⇒ **les ajouter** ;
- ⚠️ la garde est **LIGNE-À-LIGNE** (`:57-60` — `lines[i]`/`trimmed`) : c'est exactement le **défaut
  D4** de su-1 (aveugle au multi-lignes que `dart format` produit à 80 colonnes). su-3 y ajoute un
  **gros** widget ⇒ **durcir le scan PAR DÉCLARATION** (recollage des lignes de continuation) avec
  **contre-preuve exerçant le vrai scanner** (D6).

### ⚠️ Frontières de périmètre (dures — toute dérive casse une story aval)

| Dans su-3 | **PAS** dans su-3 |
|---|---|
| Saisie notée par type, correction post-soumission | **Pile swipeable + modes** (su-4 — `flutter_card_swiper`, mapping des 6 modes) |
| Indices (stocké → port), minuteur, avance | **Écran de fin / feedback pédagogique** (su-5 — banques de messages) |
| Advisory : bouton SRS **pré-sélectionné**, l'utilisateur valide | **Écriture SRS** (`reviewCard` = su-4) · **sélecteur/streak/filtres** (su-6) |
| — | **UI d'examen blanc** (su-7, *réutilisera* su-3) · **liste** (su-8) · **génération IA** (su-9) · **multi-édition** (epic ME) |

🚫 **Ne PAS** toucher `zcrud_core`, `zcrud_mindmap`, `zcrud_export`, `zcrud_export_ui` (interdits /
workstreams B-C en vol). 🚫 **Ne PAS** anticiper su-4 : **aucun** `Dismissible`, **aucun**
`onHorizontalDrag`, **aucun** moteur de session (AD-34 : les **trois runtimes existent**).

---

## Acceptance Criteria

Chaque AC est **à pouvoir discriminant** : ancré sur une ligne de prod réelle, avec une **injection
de faute (R3)** qui doit le faire **ROUGIR**. Un test qui reste vert quand on casse la logique est
**tautologique** et **invalide l'AC**.

> **Défauts démasqués aux tours précédents — INTERDITS de rejeu** : test qui appelle sa **propre
> fonction locale** (su-1 D5) · garde de scan **ligne-à-ligne** aveugle au multi-lignes de
> `dart format` (su-1 D4) · contre-preuve qui **ré-implémente** le scanner au lieu de l'exercer
> (su-1 D6) · test qui nomme une **branche de repli** sans l'atteindre (su-1 D7) · test qui cherche
> un nœud **par le libellé qu'il devrait vérifier** (su-2 D7 — garde qui ne peut jamais rougir) ·
> sonde qui mesure un **sibling hors du sous-arbre visé** (su-2 D5) · deux canaux qui **se masquent**
> l'un l'autre (su-2 D12 — chaque garde doit rougir **SEULE**) · **modifier un test pour taire un
> défaut réel** (su-2 D3). **Un test doit prouver l'ASSOCIATION, pas la seule PRÉSENCE** (su-2 D2).

---

**AC1 — QCM (simple/multiple déduit) et V/F sont évalués **LOCALEMENT** ; le port n'est JAMAIS appelé (AD-35)**

**Given** un QCM à **une** bonne réponse, puis un QCM à **plusieurs** bonnes réponses, puis une carte V/F
**When** l'utilisateur soumet sa sélection
**Then**
- le mode **simple/multiple est DÉDUIT du nombre de `ZChoice.isCorrect == true`** — **jamais** d'un
  champ, **jamais** d'un paramètre d'app : `1 correct` ⇒ **choix unique** (sélectionner B **désélectionne** A) ;
  `≥ 2 corrects` ⇒ **multi-sélection** (cases cumulatives) ;
- **V/F** : **deux boutons à AUTO-SOUMISSION** (FR-SU2 — le tap **vaut** la soumission, aucun second geste) ;
- la **correction visuelle** s'affiche après soumission (bon/mauvais par choix), avec **canal
  non-coloré obligatoire** (icône + `Semantics`, AD-13) — **jamais la seule couleur** ;
- l'évaluation est **LOCALE et EXACTE** — comparaison ensembliste stricte (`{sélection} == {corrects}` :
  une bonne réponse **manquante** OU une mauvaise **cochée** ⇒ faux) — **et le port d'évaluation
  n'est JAMAIS appelé** (AD-35 : « écart assumé avec IFFD, qui les fait passer par l'IA ») ;
- qualité produite : **exact ⇒ `config.maxQuality`** (borne haute) ; **sinon ⇒ `config.minQuality`**
  (borne basse) — bornes **lues sur `ZSrsConfig`**, **jamais** `5`/`0` en dur (AD-46) ;
- **AD-10** : `choices == null`/vide, `isTrue == null` ⇒ la surface **n'offre pas de saisie** et **ne
  plante pas** (repli l10n), jamais de `!`.

**Discriminant** : un port d'évaluation **espion** est injecté ⇒ après soumission d'un QCM **et**
d'une V/F, `spy.callCount == 0` (**assertion d'ABSENCE d'appel**, la garde centrale d'AD-35) ; le QCM
à 1 correct **désélectionne** A quand on coche B (le QCM à 2 corrects **ne le fait pas**).
**Injection R3-I1** : router QCM/VF vers le port ⇒ `callCount == 0` **ROUGIT**.
**Injection R3-I1b** : câbler le mode sur un booléen constant ⇒ le cas « 1 correct » ROUGIT.
**Injection R3-I1c** : comparaison par **sous-ensemble** au lieu d'égalité ⇒ le cas « bonne réponse
manquante » ROUGIT.

---

**AC2 — Port d'évaluation **ADVISORY** : bouton SRS **PRÉ-SÉLECTIONNÉ**, l'utilisateur valide ; le port n'écrit JAMAIS le SRS (AD-33/AD-35/AD-46)**

**Given** une **réponse rédigée** (`openQuestion`, `exercise`, `fillBlank`, `shortAnswer`) et un
`ZFlashcardAnswerEvaluationPort` **injecté**
**When** l'utilisateur soumet
**Then**
- le port reçoit **exactement** l'entrée d'AD-35 : `{question, userAnswer, cardType,
  expectedAnswer?, explanation?, timeTaken?, hintsUsed?}` — `hintsUsed` est transmis **à titre
  INFORMATIF** (AD-36 : « le barème peut en tenir compte dans sa prose ») ;
- il renvoie la sortie **typée** `{feedback, suggestedQuality, isCorrect?}` — **ADVISORY STRICT** :
  **`ZSrsQualityButtons` est rendu avec le cran suggéré PRÉ-SÉLECTIONNÉ**, et **c'est le tap de
  l'utilisateur** (`onQualitySelected`) qui vaut notation. **Le port ne note pas : il suggère** ;
- une **`suggestedQuality` hors bornes est CLAMPÉE** via **`config.clampQuality(q)`** — **l'unique
  voie de clamp** (`z_srs_config.dart:129`) : **jamais** un `.clamp(0,5)` en dur, **jamais** une
  seconde échelle (AD-46) ;
- 🔒 **AUCUN chemin de su-3 n'écrit le SRS** (AD-33) : ni `ZSessionReviewer`, ni `ZSrsScheduler.apply`,
  ni `ZSm2Scheduler`, ni `ZRepetitionStore` — **su-3 ÉMET** `onSubmitted(ZFlashcardSubmission)` et
  **su-4 branchera** l'écriture ;
- `ZSrsQualityButtons` gagne **`selectedQuality: int?`** — **retouche ADDITIVE** (défaut `null` =
  comportement actuel **strictement inchangé**, zéro régression) ; la sélection est signalée par un
  **canal non-coloré** (`Semantics(selected: true)` + affordance) et **`onQualitySelected` reste
  l'UNIQUE voie de notation** (jamais une seconde).

**Discriminant** : (1) un port stub renvoyant `suggestedQuality: 9` ⇒ le bouton **pré-sélectionné**
est le cran **5** (`maxQuality`), et **jamais** un cran hors échelle ; `-3` ⇒ cran **0** ;
(2) `spy.request` porte **`hintsUsed == 2`** après 2 indices ; (3) l'`onQualitySelected` de l'hôte
**n'est PAS invoqué** par la seule soumission (**advisory ≠ notation**) — il l'est **au tap** ;
(4) **garde de source AD-33 — la garde EXISTE, on l'ÉTEND** (`z_widgets_purity_test.dart:34-49`,
scan **récursif** de `presentation/**` ⇒ le nouveau widget est **déjà couvert**) : après extension
(`ZSrsScheduler`/`ZSm2Scheduler`) et **durcissement par déclaration** (D4), le code de prod de su-3
**ne mentionne** aucun de `ZSessionReviewer|ZSrsScheduler|ZSm2Scheduler|ZRepetitionStore|.reviewCard(|
.apply(` — avec **contre-preuve R12 exerçant le vrai scanner** (D6). 🚫 **Aucune garde parallèle.**
**Injection R3-I2** : supprimer le `clampQuality` ⇒ (1) ROUGIT. **R3-I2b** : appeler
`onQualitySelected` depuis la soumission ⇒ (3) ROUGIT. **R3-I2c** : écrire une ligne
`ZSm2Scheduler(...)` dans un fichier de prod de su-3 ⇒ (4) ROUGIT.

---

**AC3 — Port en échec / absent / hors ligne ⇒ **qualité neutre** (seuil de passage), sans exception (AD-10/NFR-SU6/NFR-SU8)**

**Given** le port d'évaluation **en échec** (`Left(ZFailure)`), puis **absent** (`null`), puis **jetant
une exception**, puis **hors ligne**
**When** l'utilisateur soumet une réponse rédigée
**Then**
- le repli est la **qualité neutre = `config.passThreshold`** (`3` par défaut — **jamais `3` en
  dur** : le PRD dit « repli qualité neutre 3 », le spine dit « seuil de passage » ; **les deux
  coïncident parce que `passThreshold == 3` est le défaut**, et c'est `passThreshold` qui fait
  autorité) ;
- **aucune exception ne franchit la surface** — y compris si l'implémentation app **throw**
  (AD-10 : « jamais d'exception ») ⇒ le repli **couvre aussi le throw**, pas seulement le `Left` ;
- la **session continue normalement** : la surface reste utilisable (soumission enregistrée, avance
  possible) ;
- `errorKind` **typé** en échec (AD-35) : la cause est **portée par le `ZFailure`** (hiérarchie
  existante, AD-5) — **aucun nouveau canal d'erreur** ;
- l'échec **n'est pas silencieux** : un `feedback` de repli **l10n** est affiché (jamais un blanc).

**Discriminant** : les **4** cas (Left / null / throw / différé) ⇒ qualité **pré-sélectionnée == 3**
et `tester.takeException()` **`isNull`** ; **contre-preuve** : le harnais **SAIT** faire échouer
(un port qui throw sans garde fait bien remonter l'exception) — sans elle, `takeException(), isNull`
serait **aveugle** (leçon su-2 D3).
**Injection R3-I3** : remplacer le repli par `throw` / par un `!` ⇒ ROUGIT.
**Injection R3-I3b** : n'attraper que le `Left` (pas le `throw`) ⇒ le cas « throw » ROUGIT.

---

**AC4 — « Je ne sais pas » = **borne basse**, sans appel au port**

**Given** le bouton « Je ne sais pas »
**When** l'utilisateur l'active
**Then**
- la soumission vaut **`config.minQuality`** (**borne basse** — `0` par défaut) et est **immédiate**
  (aucune saisie requise) ;
- **aucun appel au port** (AD-35 : « borne basse, **sans appel** ») ;
- ⚠️ **Écart PRD assumé** : le PRD (FR-SU2) dit « qualité **1** » ; le **spine (AD-35) et l'epic
  disent « borne basse »** ⇒ **le spine prime** (précédent AD-46, qui assume déjà l'écart d'échelle
  PRD 1-5 → 0..5). `minQuality` **est** la borne basse : `0` par défaut, `1` si l'app configure
  `ZSrsConfig(minQuality: 1)` — **les deux lectures se rejoignent** sans valeur en dur.

**Discriminant** : `spy.callCount == 0` **et** qualité soumise `== config.minQuality` ; **avec
`ZSrsConfig(minQuality: 1)`** ⇒ la soumission vaut **1** (prouve que la borne est **LUE**, jamais
codée en dur — leçon D7 : rendre les valeurs **discriminantes**).
**Injection R3-I4** : écrire `1` (ou `0`) en dur ⇒ le cas `minQuality: 1` (ou le cas par défaut) ROUGIT.

---

**AC5 — Indices : **stocké D'ABORD**, port **APRÈS ÉPUISEMENT** (avec les indices déjà montrés), générés **ÉPHÉMÈRES** (AD-36)**

**Given** une carte avec un **indice stocké** (`ZFlashcard.hint`, `z_flashcard.dart:175`) et un
`ZFlashcardHintPort` **injecté**
**When** l'utilisateur demande des indices
**Then**
- le **1ᵉʳ « Indice » sert l'indice STOCKÉ** — **le port n'est PAS appelé** (AD-36 : « Prevents : un
  appel IA superflu ») ;
- le port n'est appelé qu'**APRÈS ÉPUISEMENT** du stocké, et **reçoit les indices déjà montrés**
  (anti-répétition) ;
- les indices **générés restent ÉPHÉMÈRES** — **jamais persistés sur la carte** : la `ZFlashcard`
  reçue **n'est JAMAIS mutée** et **aucune écriture** de repository n'a lieu ;
- **AD-10** : `hint == null`/vide ⇒ le port est appelé **directement** (rien à épuiser) ; **port
  absent** ⇒ le bouton « Indice » est **ABSENT** après épuisement du stocké (patron `ZItemActionsMenu` :
  **absent si non fourni**, **jamais grisé**) ; port en **échec/throw** ⇒ **aucune exception**, message
  l10n, **compteur d'indices NON incrémenté** (un indice non obtenu ne pénalise pas) ;
- le **nombre d'indices utilisés** est tracké et **module la qualité** (AC6) et alimente `hintsUsed` (AC2).

**Discriminant** : (1) 1ᵉʳ tap ⇒ texte du **`hint` stocké** affiché **et** `hintSpy.callCount == 0`
(**assertion d'ABSENCE d'appel**) ; (2) 2ᵉ tap ⇒ `callCount == 1` **et** `request.shownHints`
**contient le hint stocké** ; (3) 3ᵉ tap ⇒ `shownHints.length == 2` (**cumul réel**) ; (4)
`identical(cardAvant, cardAprès)` **et** aucune écriture (store espion : `writeCount == 0`) ;
(5) port en échec ⇒ compteur d'indices **inchangé**.
**Injection R3-I5** : appeler le port dès le 1ᵉʳ tap ⇒ (1) ROUGIT. **R3-I5b** : passer une liste
**vide** en `shownHints` ⇒ (2)/(3) ROUGIT. **R3-I5c** : incrémenter le compteur sur échec ⇒ (5) ROUGIT.

---

**AC6 — Plafond d'indices : **LOCAL**, **PROPRIÉTAIRE UNIQUE**, appliqué **EN DERNIER sur la valeur rendue** (AD-36)**

**Given** des indices utilisés
**When** la qualité est attribuée
**Then**
- **une SEULE fonction pure** possède la pénalité (`zApplyHintCeiling`) — **propriétaire unique**
  (AD-36 : « la pénalité a un propriétaire unique : la couche locale ») ;
- chaque indice **abaisse d'UN CRAN la qualité maximale attribuable** :
  `ceiling = max(config.maxQuality - hintsUsed, floor)`, puis **`quality = min(rawQuality, ceiling)`** ;
- 🔒 **le plafond s'applique EN DERNIER, SUR LA VALEUR RENDUE** — y compris sur la
  `suggestedQuality` du port : **« un port qui rend 10 indices ne contourne pas le plafond »** ⇒
  ordre **imposé** : `clampQuality(portValue)` **PUIS** `zApplyHintCeiling(...)`. **Jamais deux
  pénalités cumulées** (le port n'en applique aucune : `hintsUsed` lui est informatif), **jamais
  aucune** ;
- le **plancher** est **configurable** et **ne descend JAMAIS sous le cran immédiatement inférieur au
  seuil de passage** : `floor >= config.passThreshold - 1` (**= 2** par défaut — coïncide avec le
  « plancher 2 » du PRD, **dérivé** au lieu d'être codé en dur) ; une valeur plus basse est
  **remontée** à cette borne (AD-10, jamais d'exception) ;
- la fonction est appliquée **sur TOUS les chemins de qualité** (local AC1, advisory AC2, repli AC3,
  « Je ne sais pas » AC4) — **une seule voie**, jamais un chemin qui l'oublie.

**Discriminant** (fonction pure, testable **hors widget**) : `maxQuality=5`, `passThreshold=3` ⇒
`hints=0 ⇒ 5` · `hints=1 ⇒ 4` · `hints=2 ⇒ 3` · `hints=3 ⇒ 2` · `hints=9 ⇒ 2` (**plancher tenu**) ;
`raw=1, hints=3 ⇒ **1**` (le plafond **plafonne**, il **ne remonte JAMAIS** une note basse) ;
**port ⇒ 5 avec 3 indices ⇒ 2** (**la garde anti-contournement**) ; un `floor: 0` demandé ⇒ **remonté
à 2**. Widget : `ZSrsConfig(passThreshold: 4)` ⇒ plancher **3** (**prouve la dérivation**, jamais le
littéral 2 — leçon D7).
**Injection R3-I6** : appliquer le plafond **AVANT** le clamp du port ⇒ la garde anti-contournement ROUGIT.
**R3-I6b** : `min` → `max` ⇒ le cas `raw=1` ROUGIT. **R3-I6c** : plancher en dur `2` ⇒ le cas
`passThreshold: 4` ROUGIT. **R3-I6d** : oublier le plafond sur le chemin advisory ⇒ ROUGIT.

---

**AC7 — `ZTimerDisplay { hidden, elapsed, countdown }` : le temps est **TOUJOURS mesuré**, affiché **selon l'enum uniquement** (FR-SU4)**

**Given** `ZTimerDisplay` à **`hidden` (défaut)**, puis `elapsed`, puis `countdown`
**When** l'utilisateur répond
**Then**
- le temps est **TOUJOURS mesuré** (`Stopwatch` — **PREUVE C : aucun dans le repo, su-3 est le
  premier**) et transmis en `timeTaken` (AC2) **même en `hidden`** ;
- l'**affichage** suit l'enum : `hidden` ⇒ **aucun** widget de minuteur dans l'arbre ; `elapsed` ⇒
  temps **croissant** ; `countdown` ⇒ temps **décroissant** depuis `timeLimit` ;
- **enum, JAMAIS un booléen** (convention du spine) ; `switch` **exhaustif sans `default`** (une 4ᵉ
  valeur casse la **compilation**) ;
- **AD-10** : `countdown` **sans `timeLimit`** ⇒ **dégradation en `elapsed`** (jamais d'exception,
  jamais un compte à rebours depuis `null`) ; `countdown` **épuisé** ⇒ s'arrête à **zéro** (jamais de
  négatif), la saisie **reste possible** (su-3 n'impose **aucune** soumission forcée — hors périmètre) ;
- **SM-1** : le tick **ne reconstruit QUE la tranche du minuteur** (`ValueNotifier<Duration>` +
  `ValueListenableBuilder`) — **jamais** la carte, **jamais** le champ de saisie ; en **`hidden`**,
  **aucun ticker n'est armé** (mesure par `Stopwatch`, lue à la soumission) ;
- le ticker/`Timer` est **annulé au `dispose`** (aucune fuite, aucun tick après démontage).

**Discriminant** : (1) `hidden` ⇒ finder du minuteur **`findsNothing`**, **et** `timeTaken > 0` à la
soumission (**le temps est mesuré quand même** — la garde centrale de l'AC) ; (2) `elapsed` vs
`countdown` ⇒ deux textes **distincts** évoluant en **sens opposés** (`pump(1s)` ×2) ; (3) une **sonde
de comptage** dans le `contentBuilder` prouve que 3 ticks **ne reconstruisent PAS** le contenu de
carte (sonde **dans le sous-arbre visé**, jamais un sibling — leçon su-2 D5) ; (4) `countdown` sans
`timeLimit` ⇒ rendu **`elapsed`**, aucune exception ; (5) après `dispose`, `takeException(), isNull`
(aucun tick orphelin).
**Injection R3-I7** : ne pas armer le `Stopwatch` en `hidden` ⇒ (1) ROUGIT. **R3-I7b** : hisser le
tick au niveau de la carte ⇒ (3) ROUGIT. **R3-I7c** : retirer le `cancel()` du `dispose` ⇒ (5) ROUGIT.

---

**AC8 — `ZCardAdvanceBehavior { auto, manual }` : **défaut PAR MODE**, table **UNIQUE**, jamais redécidée par un widget (FR-SU5)**

**Given** `ZCardAdvanceBehavior` **non spécifié**
**When** la session est en **test/examen blanc**, puis en **apprentissage/consultation**
**Then**
- le défaut est respectivement **`auto`** et **`manual`** — **table UNIQUE** (spine § Conventions :
  « défauts de `ZCardAdvanceBehavior` **par mode** : table unique, **jamais redécidée par widget** ») :
  **une seule fonction pure** `zDefaultAdvanceBehavior(ZReviewMode)`, `switch` **exhaustif sans
  `default`** sur les **6** valeurs réelles (`spaced, learn, list, test, whiteExam, cramming` —
  `z_review_mode.dart:26`) ⇒ `test`/`whiteExam` ⇒ **`auto`** ; `spaced`/`learn`/`list`/`cramming` ⇒
  **`manual`** ;
- `auto` ⇒ **auto-passage après un délai court** (défaut **200 ms** — parité IFFD F13 : « auto-passage
  à la carte suivante après 200ms »), via le callback **injecté** `onAdvance` ; `manual` ⇒ **aucun**
  auto-passage (l'utilisateur lit la correction puis avance) ;
- une valeur **explicite** passée par l'hôte **prime** sur le défaut (paramètre nullable ⇒ table) ;
- le timer d'auto-passage est **annulé au `dispose`** et **ne tire jamais après démontage**
  (`mounted`) — classe de bug réelle ;
- **enum, jamais un booléen** ; su-3 **n'implémente PAS** la navigation (c'est su-4) : il **demande**
  l'avance par callback.

**Discriminant** : (1) la fonction pure ⇒ **6 cas**, un par valeur d'enum (`test`/`whiteExam` ⇒
`auto`, les 4 autres ⇒ `manual`) ; (2) widget en `mode: test` sans valeur explicite ⇒ après
soumission + `pump(200ms)`, `onAdvance` **invoqué 1×** ; en `mode: learn` ⇒ **jamais invoqué**
(`pump(5s)`) ; (3) `advanceBehavior: manual` **explicite** en `mode: test` ⇒ **jamais invoqué**
(**prouve que l'explicite prime**) ; (4) démonter avant l'échéance ⇒ **aucune** invocation, aucune
exception.
**Injection R3-I8** : recoder le défaut dans le widget (au lieu de la table) ⇒ (1)+(2) divergent, ROUGIT.
**R3-I8b** : ignorer la valeur explicite ⇒ (3) ROUGIT. **R3-I8c** : retirer le `cancel()`/`mounted` ⇒ (4) ROUGIT.

---

**AC9 — L'ARÈNE DES GESTES : saisie **ET** révélation coexistent sans se voler le tap**

**Given** la surface de saisie `ZFlashcardAnswerInput` **et** la carte d'affichage
`ZFlashcardReviewCard` (su-2), y compris sur le **chemin markdown** (`ZFlashcardMarkdownContent.builder()`
— **le chemin exact du HIGH D1**)
**When** l'utilisateur tape
**Then**
- 🔒 la surface de saisie **ne pose AUCUN tap-to-reveal** : la révélation/correction y est **causée
  par la SOUMISSION**, jamais par un tap sur la carte ;
- le **contenu** de la surface de saisie (slot AD-40) **reste `IgnorePointer`** : seul un **contrôle
  de saisie** capte le geste ⇒ un `QuillEditor` injecté **ne peut PAS** voler le tap d'une case QCM
  (**rejeu exact du scénario D1**) ;
- **non-régression su-2 (garde obligatoire)** : l'`IgnorePointer` de `z_flashcard_review_card.dart:261`
  **est TOUJOURS là** et la révélation par tap de su-2 **fonctionne toujours** sur le chemin
  markdown — 🚫 **il est INTERDIT de « régler » l'arène en le retirant** (c'est le correctif d'un
  **HIGH réel**) ;
- composées en **frères** par un hôte, les deux surfaces sont **étanches** : taper la saisie ne
  révèle pas la carte ; taper la carte ne modifie pas la saisie ;
- **aucun** `Dismissible`/`onHorizontalDrag` n'est posé (le geste de swipe appartient à **su-4**).

**Discriminant** : (1) hôte composant **les deux** surfaces (chemin **markdown**) ⇒ tap **au centre
d'une case QCM** ⇒ la case bascule **et** `revealed` reste **`false`** ; (2) tap sur la carte
d'affichage ⇒ `revealed == true` **et** la sélection QCM **inchangée** ; (3) tap **au centre du
contenu riche** de la surface de saisie ⇒ **aucune** soumission, **aucune** révélation (contenu inerte) ;
(4) **garde de source** : `IgnorePointer` **présent** dans `z_flashcard_review_card.dart` **et** sur
le chemin de contenu de la surface de saisie (scan **par déclaration** + **contre-preuve R12
exerçant le vrai scanner**) ; (5) **garde de source** : **aucun** `Dismissible|onHorizontalDrag` dans
le code de prod de su-3.
**Injection R3-I9** : poser un `InkWell(onTap: reveal)` autour de la surface de saisie ⇒ (1) ROUGIT.
**R3-I9b** : retirer l'`IgnorePointer` du contenu de saisie ⇒ (3) ROUGIT sur le chemin markdown.

---

**AC10 — SM-1 : taper 100 caractères ne reconstruit **QUE** le champ (NFR-SU2 — objectif produit n°1)**

**Given** l'utilisateur **rédige** une réponse
**When** il tape **100 caractères**
**Then**
- **SEUL le champ de saisie se reconstruit** — **zéro perte de focus** (AD-2, **le bug historique
  que zcrud existe pour corriger**) ;
- le **`TextEditingController` est STABLE** : créé **une fois** (`initState`), `dispose`é — **JAMAIS
  recréé au rebuild**, **jamais** dans `build()` ; idem `FocusNode` (patron **réel**
  `z_text_field_widget.dart` : le widget est **stateless**, la **stabilité vit dans l'hôte**) ;
- **aucune ré-injection de valeur** n'écrase la sélection/le curseur pendant la frappe (saisie à
  **sens unique** `onChanged`) ;
- **validateurs mémoïsés** (identité stable entre builds) + **`AutovalidateMode.onUserInteraction`**
  **par champ** (`z_text_field_widget.dart:37`) ;
- **aucune closure réallouée** sur le chemin du slot : `widget.contentBuilder ??
  ZFlashcardDefaultContent.builder` (**tear-off statique** — **jamais** `?? (c,s) => …`) ;
- **aucun `setState` à l'échelle de la surface** pendant la frappe (l'état de saisie vit dans des
  `ValueNotifier` **stables**, lus par `ValueListenableBuilder`).

**Discriminant** : (1) **sonde de comptage DANS le `contentBuilder`** (⚠️ **dans le sous-arbre visé** —
la sonde de su-2 mesurait un **sibling** et était structurellement aveugle, **D5**) ⇒ après **100**
`enterText`/frappes, le nombre de constructions du contenu **n'a pas bougé** ; (2) `identical()` du
controller **entre deux builds** ⇒ **`true`** ; (3) `identical()` du builder résolu entre deux builds
⇒ **`true`** ; (4) le focus est **conservé** de bout en bout et le **curseur reste en fin de texte**
(`selection.baseOffset == 100`) ; (5) **discriminant STRUCTUREL** (à la façon du D5 de su-2) :
**200 caractères ne construisent pas 2× plus de contenu que 100** — un seuil absolu peut toujours
être « ajusté », **ce rapport-là non**.
**Injection R3-I10** : recréer le controller dans `build()` ⇒ (2)+(4) ROUGISSENT.
**R3-I10b** : remplacer le `ValueListenableBuilder` du champ par un `setState` de surface ⇒ (1)+(5) ROUGISSENT.
**R3-I10c** : remplacer le tear-off par une closure ⇒ (3) ROUGIT.

---

**AC11 — A11y / RTL / thème / l10n (AD-13, NFR-SU3/4/5) et gates repo-wide verts**

**Given** la surface de saisie
**When** elle est rendue et que la story est déclarée verte
**Then**
- **cibles ≥ 48 dp** + **`Semantics` explicites** sur **tout** contrôle (cases, V/F, Indice, « Je ne
  sais pas », soumettre) — patron `z_srs_quality_buttons.dart:197,212` ;
- **zéro couleur en dur** (`ZcrudTheme.of` + repli `Theme.of`) · **zéro libellé en dur**
  (`label(context, 'zcrud.flashcard.*', fallback: '…')` — **aucune écriture dans `zcrud_core`**) ;
- **variantes directionnelles** partout (RTL) : `EdgeInsetsDirectional`, `AlignmentDirectional`,
  `TextAlign.start/end` — **jamais** `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`,
  `TextAlign.left/right`, `Positioned(left:/right:)` ;
- **canal non-coloré** de la correction **et** de la pré-sélection : le résultat est perceptible
  **sans lire une couleur** (icône + `Semantics`), et **associé à SON choix** (`MergeSemantics` de la
  ligne — leçon **D2** de su-2 : un marqueur détaché s'attache au **mauvais** choix et **enseigne
  une erreur** à un utilisateur non-voyant) ;
- **Reduce Motion** : toute affordance **animée** de su-3 passe par **`zReduceMotionOf`**
  (`z_reduce_motion.dart:32`) — **primitive UNIQUE du repo**, **jamais** une seconde ;
- gates : `melos run generate` OK · **`melos run analyze` RC=0 REPO-WIDE** · **`melos run verify`
  RC=0** (graphe **acyclique**, **CORE OUT=0**, secrets, `codegen-distribution`) · tests **RC=0**.

**Discriminant** : (1) **thème** — `ZcrudScope(theme: ZcrudTheme())` avec un `ColorScheme.onSurface`
**volontairement distinct** de `bodyMedium.color` (leçon **D7** : sans valeurs discriminantes, le
test passe **quelle que soit** la branche) ; (2) `tester.getSize()` de **chaque** cible `>= Size(48,48)` ;
(3) RTL **et** LTR sans exception ni débordement ; (4) **association** du marqueur : le `node.label`
du **bon** choix porte le marqueur, **pas** celui du voisin — correct placé **en position 2** (jamais
en tête : un marqueur détaché se lirait malgré tout juste avant le bon choix et le défaut resterait
**invisible**) ; (5) **garde de source — EXISTANTE, à durcir, jamais à dupliquer** :
`z_widgets_hardcode_scan_test.dart:31-52` bannit **déjà** `Colors.`/`Color(0x`/API non-directionnelles/
`ListView(children:)` sur **tout** `presentation/**` (le nouveau widget est **capté sans édition**) —
la **durcir par déclaration** (D4) + **contre-preuve exerçant le vrai scanner** (D6), portée
**déclarée honnêtement** (couvre `zcrud_session/lib/src/presentation`, jamais les tests).
**Injection R3-I11** : `const Color(0xFF00AA00)` en dur sur la correction ⇒ (1) ROUGIT.
**R3-I11b** : retirer le `MergeSemantics` de la ligne ⇒ (4) ROUGIT.

⚠️ **`melos run test` est INUTILISABLE** (parallélise les `flutter test` et **se bloque**) ⇒
**`flutter test` PAR PACKAGE**. **Référence actuelle : 23/23 verts, 3725 tests** —
`zcrud_flashcard` = **359** · `zcrud_session` = **86** (rejoués sur disque à la création de la story).

---

## Spécifications techniques — signatures exactes (contrat à livrer)

**Forme indicative, CONTRAIGNANTE sur les points 🔒.**

```dart
// ═══ DOMAINE — packages/zcrud_flashcard/lib/src/domain/ ═══════════════════════
// 🔒 Foyer IMPOSÉ par le graphe : `zcrud_study` dépend de `zcrud_flashcard` (cycle
// sinon) et `zcrud_study_kernel` ignore `ZFlashcardType`. Patron de port copié sur
// `zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:89`.

// z_flashcard_answer_evaluation_port.dart
/// Entrée d'évaluation (AD-35, mot pour mot). VO immuable.
class ZFlashcardAnswerEvaluationRequest {
  const ZFlashcardAnswerEvaluationRequest({
    required this.question,
    required this.userAnswer,
    required this.cardType,          // 🔒 ZFlashcardType existant
    this.expectedAnswer,
    this.explanation,
    this.timeTaken,                  // Duration?  (AC7 : mesuré MÊME en `hidden`)
    this.hintsUsed = 0,              // 🔒 INFORMATIF (AD-36) — le port n'en tire AUCUNE pénalité
  });
  /* … + `extra` (AD-4, échappatoire) si besoin — patron ZFlashcardGenerationRequest */
}

/// Sortie ADVISORY typée (AD-35). Le port SUGGÈRE, il ne note JAMAIS.
class ZFlashcardAnswerEvaluation {
  const ZFlashcardAnswerEvaluation({
    required this.feedback,
    required this.suggestedQuality,  // 🔒 CLAMPÉ par `config.clampQuality` à la RÉCEPTION (AC2)
    this.isCorrect,                  // 🔒 nullable (AD-35 : `isCorrect?`)
  });
}

/// 🔒 `abstract interface class` (AD-4 : frontière inter-package, JAMAIS `sealed`).
/// 🔒 `Either<ZFailure,·>` (AD-5) — l'`errorKind` typé EST le `ZFailure` (AD-35).
/// 🔒 Il n'est JAMAIS appelé pour un QCM ou une V/F (AD-35 / AC1).
abstract interface class ZFlashcardAnswerEvaluationPort {
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  );
}

// z_flashcard_hint_port.dart
class ZFlashcardHintRequest {
  const ZFlashcardHintRequest({
    required this.question,
    required this.cardType,
    this.expectedAnswer,
    this.shownHints = const <String>[],  // 🔒 indices DÉJÀ montrés (AD-36, anti-répétition)
  });
}
abstract interface class ZFlashcardHintPort {
  /// 🔒 Appelé UNIQUEMENT après épuisement du `hint` STOCKÉ (AD-36).
  /// 🔒 Le résultat est ÉPHÉMÈRE : jamais persisté sur la carte.
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request);
}

// z_flashcard_local_evaluation.dart — 🔒 fonctions PURES (aucun Flutter, aucun port)
/// Évaluation LOCALE exacte QCM/VF (AD-35). `null` si le type n'est pas local.
int? zEvaluateLocally({
  required ZFlashcard card,
  required Set<String> selectedChoiceIds,   // QCM
  bool? answeredTrue,                       // V/F
  required ZSrsConfig config,               // 🔒 bornes LUES (AD-46), jamais 0/5 en dur
});
/// 🔒 QCM = ÉGALITÉ ensembliste stricte (jamais un sous-ensemble).
/// 🔒 mode simple/multiple DÉDUIT du nb de `isCorrect` (jamais un champ/param).

// z_hint_penalty.dart — 🔒 PROPRIÉTAIRE UNIQUE de la pénalité (AD-36)
class ZHintPenaltyPolicy {
  const ZHintPenaltyPolicy({this.floor});
  /// Plancher du PLAFOND. `null` ⇒ `config.passThreshold - 1` (= 2 par défaut).
  /// 🔒 Une valeur < `passThreshold - 1` est REMONTÉE à cette borne (AD-36/AD-10).
  final int? floor;
}
/// 🔒 APPLIQUÉ EN DERNIER, SUR LA VALEUR RENDUE — y compris celle du port
/// (« un port qui rend 10 indices ne contourne pas le plafond »).
/// 🔒 `min(rawQuality, ceiling)` : PLAFONNE, ne REMONTE JAMAIS une note basse.
int zApplyHintCeiling({
  required int rawQuality,
  required int hintsUsed,
  required ZSrsConfig config,
  ZHintPenaltyPolicy policy = const ZHintPenaltyPolicy(),
});

// ═══ PRÉSENTATION — packages/zcrud_session/lib/src/presentation/ ══════════════
// 🔒 Foyer IMPOSÉ : `ZSrsQualityButtons` (pré-sélection, AC2) vit ici et est
// INATTEIGNABLE depuis `zcrud_flashcard` (session → flashcard).

/// 🔒 ENUM, jamais un booléen. Défaut `hidden` (FR-SU4).
enum ZTimerDisplay { hidden, elapsed, countdown }
/// 🔒 ENUM, jamais un booléen (FR-SU5).
enum ZCardAdvanceBehavior { auto, manual }

/// 🔒 TABLE UNIQUE des défauts par mode — JAMAIS redécidée par un widget.
/// `switch` EXHAUSTIF sans `default` sur les 6 `ZReviewMode`.
ZCardAdvanceBehavior zDefaultAdvanceBehavior(ZReviewMode mode);
//   test, whiteExam            → auto
//   spaced, learn, list, cramming → manual

/// Soumission ADVISORY émise à l'hôte (su-4 la branchera sur `ZSessionReviewer`).
/// 🔒 su-3 n'écrit RIEN (AD-33).
class ZFlashcardSubmission {
  const ZFlashcardSubmission({
    required this.quality,      // 🔒 déjà clampée ET plafonnée (AC2/AC6)
    required this.timeTaken,    // 🔒 mesuré même en `hidden` (AC7)
    required this.hintsUsed,
    this.isCorrect,
    this.feedback,
  });
}

/// Surface de SAISIE notée (FR-SU2/3/4/5).
/// 🔒 AUCUN tap-to-reveal (AC9) : la correction est causée par la SOUMISSION.
class ZFlashcardAnswerInput extends StatefulWidget {
  const ZFlashcardAnswerInput({
    required this.card,                 // 🔒 ZFlashcard existant — JAMAIS mutée (AC5)
    required this.mode,                 // 🔒 ZReviewMode → table de défaut (AC8)
    this.srsConfig = const ZSrsConfig(), // 🔒 propriétaire de l'échelle (AD-46)
    this.contentBuilder,                // 🔒 slot AD-40 su-1 (nullable = opt-in)
    this.evaluationPort,                // null ⇒ repli neutre (AC3)
    this.hintPort,                      // null ⇒ bouton Indice ABSENT après épuisement (AC5)
    this.hintPolicy = const ZHintPenaltyPolicy(),
    this.timerDisplay = ZTimerDisplay.hidden,   // 🔒 défaut `hidden` (FR-SU4)
    this.timeLimit,                     // 🔒 requis par `countdown` ; null ⇒ dégrade en `elapsed`
    this.advanceBehavior,               // 🔒 null ⇒ zDefaultAdvanceBehavior(mode)
    this.autoAdvanceDelay = const Duration(milliseconds: 200), // parité IFFD F13
    this.onSubmitted,                   // ZFlashcardSubmission (advisory)
    this.onQualitySelected,             // 🔒 null ⇒ rangée SRS ABSENTE (patron ZItemActionsMenu)
    this.onAdvance,                     // demande d'avance (su-4 navigue)
    super.key,
  });
}
```

**Résolution du slot (🔒 patron exact — `z_mindmap_view.dart:137-142`, réutilisé par su-2)** :

```dart
ZFlashcardContentBuilder get _contentBuilder =>
    widget.contentBuilder ?? ZFlashcardDefaultContent.builder;  // 🔒 tear-off, JAMAIS `?? (c,s) => …`
```

**Ordre d'attribution de la qualité (🔒 IMPOSÉ — AC2/AC6)** :

```
port → clampQuality(suggestedQuality)  →  zApplyHintCeiling(...)  → ZFlashcardSubmission.quality
local QCM/VF → max/minQuality          →  zApplyHintCeiling(...)  → …
repli AD-10  → passThreshold           →  zApplyHintCeiling(...)  → …
« Je ne sais pas » → minQuality        →  zApplyHintCeiling(...)  → …   (min(0,ceiling)=0 : inerte)
                                          ▲ UNE SEULE VOIE, EN DERNIER
```

## Tasks / Subtasks

- [x] **T1 — Ports + VOs (AC2, AC3, AC5)** · `zcrud_flashcard/lib/src/domain/`
  - [x] `z_flashcard_answer_evaluation_port.dart` : requête AD-35 **mot pour mot**, sortie typée,
        `abstract interface class`, `Future<ZResult<…>>` (patron `z_flashcard_generation_port.dart:89`).
  - [x] `z_flashcard_hint_port.dart` : `shownHints` (anti-répétition), `Future<ZResult<String>>`.
  - [x] Exports **additifs** au barrel `lib/zcrud_flashcard.dart` (ordre alphabétique).
- [x] **T2 — Logique PURE (AC1, AC6)** · `zcrud_flashcard/lib/src/domain/`
  - [x] `z_flashcard_local_evaluation.dart` : `zEvaluateLocally` — **égalité ensembliste stricte**,
        simple/multiple **déduit du nb de `isCorrect`**, bornes **lues sur `ZSrsConfig`**.
  - [x] `z_hint_penalty.dart` : `ZHintPenaltyPolicy` + `zApplyHintCeiling` — **propriétaire unique**,
        plancher **dérivé** (`passThreshold - 1`), `min(raw, ceiling)`.
- [x] **T3 — Enums + table de défaut (AC7, AC8)** · `zcrud_session/lib/src/presentation/`
  - [x] `z_timer_display.dart` · `z_card_advance_behavior.dart` (**enums**, jamais des booléens).
  - [x] `zDefaultAdvanceBehavior(ZReviewMode)` — **table unique**, `switch` **exhaustif sans `default`**.
  - [x] `z_flashcard_submission.dart` (VO advisory) · exports **additifs** au barrel.
- [x] **T4 — `ZSrsQualityButtons.selectedQuality` — retouche ADDITIVE (AC2)** · `zcrud_session`
  - [x] Ajouter `final int? selectedQuality;` (**défaut `null` = comportement actuel INCHANGÉ**).
  - [x] Pré-sélection à **canal non-coloré** (`Semantics(selected: true)` + affordance thématisée) ;
        **`onQualitySelected` reste l'UNIQUE voie de notation**.
  - [x] 🚫 **Ne PAS** toucher `scale`/`passThreshold`/`onQualitySelected`/`buttonKeyPrefix` (surface
        publique existante — su-1/E-* la garde).
  - [x] **Dette du ledger su-1** (`z_srs_quality_buttons.dart:208,243`) : `'ok'`/`'lapse'` **en dur**
        dans `Semantics.value` + `fontSize: 12` en dur ⇒ **corriger** (le fichier est ouvert par T4,
        règle MEDIUM du projet), **sinon justifier par écrit** dans le rapport.
- [x] **T4bis — ÉTENDRE les 2 gardes EXISTANTES (AC2/AD-33, AC11)** · `zcrud_session/test/presentation/`
  - [x] 🚫 **Ne créer AUCUNE garde parallèle** : `z_widgets_purity_test.dart` et
        `z_widgets_hardcode_scan_test.dart` scannent **déjà récursivement** `presentation/**` ⇒ le
        nouveau widget est **capté sans édition**. Les dupliquer serait une **réinvention**.
  - [x] `z_widgets_purity_test.dart` : ajouter `ZSrsScheduler`/`ZSm2Scheduler` à `_bannedWriteSymbols`.
  - [x] **Durcir les DEUX scans PAR DÉCLARATION** (recollage des lignes de continuation — **défaut D4**,
        `dart format` wrappe à 80 col.) + **contre-preuve exerçant le vrai scanner** (**D6**).
  - [x] Rafraîchir leurs dartdoc « les 3 widgets » (obsolète dès qu'un 4ᵉ entre).
- [x] **T5 — `ZFlashcardAnswerInput` : saisie par type + arène (AC1, AC9)** · `zcrud_session`
  - [x] QCM : cases **cumulatives** si ≥2 corrects, **exclusives** si 1 correct ; V/F : **2 boutons
        auto-soumis** ; rédigée : **`TextField` + controller STABLE** (AC10).
  - [x] `switch` **exhaustif sans `default`** sur les **6** `ZFlashcardType` — table d'**affordance de
        saisie** seule (**ne PAS redécider** la table d'**affichage** de su-2 : un propriétaire chacun).
  - [x] 🔒 Contenu par le slot AD-40 **sous `IgnorePointer`** ; **AUCUN tap-to-reveal** ; **aucun**
        `Dismissible`/`onHorizontalDrag`.
  - [x] Correction post-soumission : **canal non-coloré** + **`MergeSemantics` par ligne** (leçon D2).
- [x] **T6 — Indices (AC5, AC6)** · `zcrud_session`
  - [x] Bouton « Indice » : **stocké d'abord** → port **après épuisement** avec `shownHints` ;
        générés **éphémères** (carte **jamais mutée**, **aucune** écriture).
  - [x] Port absent ⇒ bouton **ABSENT** après épuisement ; échec/throw ⇒ **aucune exception**,
        compteur **non incrémenté**.
- [x] **T7 — Soumission, advisory, replis (AC2, AC3, AC4)** · `zcrud_session`
  - [x] QCM/VF ⇒ **local** (port **jamais** appelé) ; rédigée ⇒ port ⇒ `clampQuality` **puis** plafond.
  - [x] Repli **`passThreshold`** sur `Left` **ET** sur `throw` ; « Je ne sais pas » ⇒ **`minQuality`**,
        **sans appel**.
  - [x] Rangée SRS **pré-sélectionnée** (`selectedQuality`) ; `onSubmitted` émis ; **AUCUNE** écriture SRS.
- [x] **T8 — Minuteur (AC7)** · `zcrud_session`
  - [x] `Stopwatch` **toujours** armé (**premier du repo**) ; ticker **seulement** si affiché ;
        `ValueNotifier<Duration>` + `ValueListenableBuilder` (**tranche minuteur seule**) ;
        `countdown` sans `timeLimit` ⇒ **`elapsed`** ; `cancel()` au `dispose`.
- [x] **T9 — Avance (AC8)** · `zcrud_session`
  - [x] `advanceBehavior ?? zDefaultAdvanceBehavior(mode)` ; `auto` ⇒ `Timer(200ms)` → `onAdvance`
        (garde `mounted`, `cancel()` au `dispose`) ; `manual` ⇒ **rien**.
- [x] **T10 — A11y / thème / l10n / RTL / Reduce Motion (AC11)** · `zcrud_session`
  - [x] ≥ 48 dp + `Semantics` sur **tout** contrôle ; `ZcrudTheme.of` + repli ; `label(…, fallback:)` ;
        variantes **directionnelles** ; toute animation via **`zReduceMotionOf`** (**jamais** une 2ᵉ primitive).
- [x] **T11 — Tests porteurs (AC1..AC11)** — cf. § Stratégie de test.
- [x] **T12 — Vérif verte (AC11)** : `melos run generate` → **`analyze` repo-wide** → `flutter test`
      **par package** → **`verify` repo-wide**.

## Stratégie de test

**Runner (R14)** : `zcrud_flashcard` **et** `zcrud_session` sont des **packages Flutter**
(`flutter: sdk` déclaré) ⇒ **`flutter test`**, jamais `dart test`.
⚠️ **`melos run test` est INUTILISABLE** (parallélise et **se bloque**) ⇒ **par package**.
⚠️ **Injections R3 destructives** : arbre **quiescent** ou worktree jetable (workstreams B/C en vol —
des injections concurrentes ont produit de **faux HIGH** en su-1). Ces fichiers **ne sont pas suivis
par git** ⇒ restauration à **vérifier par SHA-256** (`git checkout` ne les restaurerait pas).

| Fichier de test | Ce qu'il PROUVE (rougit si…) |
|---|---|
| `zcrud_flashcard/test/z_flashcard_local_evaluation_test.dart` **(NEUF, pur)** | AC1 — simple/multiple **déduit** ; **égalité stricte** (manquante ⇒ faux, mauvaise cochée ⇒ faux) ; bornes **lues** sur `ZSrsConfig` (cas `minQuality: 1`) |
| `zcrud_flashcard/test/z_hint_penalty_test.dart` **(NEUF, pur)** | AC6 — 0/1/2/3/9 indices ; **plancher dérivé** (`passThreshold: 4` ⇒ 3) ; `raw=1, hints=3 ⇒ 1` ; `floor: 0` **remonté** ; **anti-contournement** (port 5 + 3 indices ⇒ 2) |
| `zcrud_flashcard/test/z_flashcard_ai_ports_surface_test.dart` **(NEUF, surface)** | AC2/AC5 — ports = `abstract interface class`, `Future<ZResult<…>>`, requête AD-35 **complète** ; exportés au barrel |
| `zcrud_session/test/z_card_advance_behavior_test.dart` **(NEUF, pur)** | AC8 — **6 cas**, un par `ZReviewMode` (`test`/`whiteExam` ⇒ `auto`) ; **table unique** |
| `zcrud_session/test/presentation/z_flashcard_answer_input_qcm_vf_test.dart` **(NEUF, widget)** | AC1 — QCM 1 vs ≥2 corrects ; V/F **auto-soumis** ; correction visuelle ; **`spy.callCount == 0`** (port **jamais** appelé) ; replis AD-10 |
| `zcrud_session/test/presentation/z_flashcard_answer_input_advisory_test.dart` **(NEUF, widget)** | AC2/AC4 — pré-sélection ; `9 ⇒ 5`, `-3 ⇒ 0` (**clamp**) ; `hintsUsed` transmis ; soumission **≠** notation ; « Je ne sais pas » ⇒ `minQuality`, **sans appel** |
| `zcrud_session/test/presentation/z_flashcard_answer_input_fallback_test.dart` **(NEUF, widget)** | AC3 — **4 cas** (Left/null/**throw**/hors ligne) ⇒ **`passThreshold`**, `takeException(), isNull` + **contre-preuve** (le harnais SAIT faire remonter une exception) |
| `zcrud_session/test/presentation/z_flashcard_answer_input_hints_test.dart` **(NEUF, widget)** | AC5 — stocké **d'abord** (`callCount == 0`) ; `shownHints` **cumulatif** ; carte **jamais mutée** (`identical`) ; **aucune** écriture ; port absent ⇒ bouton **ABSENT** ; échec ⇒ compteur **inchangé** |
| `zcrud_session/test/presentation/z_flashcard_timer_test.dart` **(NEUF, widget)** | AC7 — `hidden` ⇒ **`findsNothing`** **mais `timeTaken > 0`** ; `elapsed`/`countdown` **sens opposés** ; `countdown` sans `timeLimit` ⇒ `elapsed` ; ticks ⇒ **contenu non reconstruit** (sonde **dans** le sous-arbre) ; **aucun tick après `dispose`** |
| `zcrud_session/test/presentation/z_flashcard_advance_test.dart` **(NEUF, widget)** | AC8 — `test` ⇒ `onAdvance` **1×** après 200 ms ; `learn` ⇒ **jamais** ; explicite **prime** ; démontage ⇒ **aucune** invocation |
| `zcrud_session/test/presentation/z_flashcard_gesture_arena_test.dart` **(NEUF, widget — 🎯 AC9)** | AC9 — **chemin markdown** : tap **au centre d'une case** ⇒ case bascule **et** `revealed == false` ; tap carte ⇒ révèle **sans** toucher la sélection ; tap **contenu riche** ⇒ **inerte** ; garde de source : **aucun** `Dismissible`/`onHorizontalDrag` + `IgnorePointer` **présent des deux côtés** (scan **par déclaration** + contre-preuve **exerçant le vrai scanner**) |
| `zcrud_session/test/presentation/z_flashcard_answer_input_sm1_test.dart` **(NEUF, widget)** | AC10 — **100 frappes** ⇒ contenu **non reconstruit** (sonde **dans** le sous-arbre) ; `identical()` controller **et** builder ; focus **conservé**, `baseOffset == 100` ; **discriminant structurel** (200 ≠ 2×100) |
| `zcrud_session/test/presentation/z_flashcard_answer_input_a11y_test.dart` **(NEUF, widget)** | AC11 — repli de thème **réellement emprunté** (`onSurface` ≠ `bodyMedium.color`) ; ≥ 48 dp ; RTL+LTR ; **association** du marqueur (correct en **position 2**) |
| 🔴 `zcrud_session/test/presentation/z_widgets_purity_test.dart` **(EXISTE — ÉTENDRE, jamais dupliquer)** | AC2/AD-33 — **couvre DÉJÀ** `ZFlashcardAnswerInput` (scan récursif de `presentation/**`). **À étendre** : `ZSrsScheduler`/`ZSm2Scheduler` dans `_bannedWriteSymbols` (`:45-49`) + **durcir PAR DÉCLARATION** (D4 : scan ligne-à-ligne `:57-60`) + contre-preuve R12 |
| 🔴 `zcrud_session/test/presentation/z_widgets_hardcode_scan_test.dart` **(EXISTE — ÉTENDRE, jamais dupliquer)** | AC11 — **couvre DÉJÀ** le nouveau widget (couleurs en dur, API non-directionnelles, `ListView(children:)`). **À durcir PAR DÉCLARATION** (même défaut D4, `:60`) + contre-preuve R12. 🚫 **NE PAS créer** un `z_session_rtl_guard_test.dart` : ce serait une **garde parallèle redondante** |
| `zcrud_session/test/presentation/z_srs_quality_buttons_test.dart` *(EXISTE — **ne pas affaiblir**)* | AC2 — non-régression : `selectedQuality: null` ⇒ **comportement strictement inchangé** |
| `zcrud_flashcard/test/z_flashcard_review_card_test.dart` *(EXISTE — **ne pas affaiblir**)* | AC9 — non-régression **su-2** : la révélation par tap et l'`IgnorePointer` **survivent** |

**Non-régression obligatoire (si l'un rougit, c'est la retouche qui est fautive — JAMAIS le test à
assouplir)** : `z_flashcard_review_card_test.dart`, `z_flashcard_reveal_transition_test.dart`,
`z_flashcard_reduce_motion_test.dart`, `z_flashcard_review_card_sm1_test.dart`,
`z_flashcard_markdown_content_test.dart`, `z_flashcard_content_slot_test.dart`, `z_srs_config_test.dart`,
`z_sm2_contract_test.dart`, `z_public_surface_test.dart`, `z_kernel_surface_guard_test.dart`,
`zcrud_session/test/z_purity_test.dart` (**aucun import de gestionnaire d'état/widget dans le
runtime** — ⚠️ `ZFlashcardSubmission` va en `src/domain/` : **aucun import Flutter** dedans, sinon
cette garde ROUGIT), `z_linear_no_srs_test.dart`, `z_white_exam_no_srs_test.dart`,
`z_quality_scale_single_source_test.dart` (**AD-46 : aucune seconde source d'échelle**),
`presentation/z_widgets_purity_test.dart` + `presentation/z_widgets_hardcode_scan_test.dart`
(**étendues/durcies par T4bis — jamais affaiblies**), `presentation/z_srs_quality_buttons_test.dart`.

**⚠️ Piège cross-package tracé (précédent su-1)** : un export ajouté au barrel `zcrud_flashcard` avait
fait **rougir** `z_kernel_surface_guard_test.dart` — **invisible d'une vérif par-package**. su-3
touche **deux** barrels ⇒ **`analyze`/`verify` repo-wide sont la seule preuve**.

## Dev Notes

### Contraintes AD applicables

- **AD-35** — évaluation **ADVISORY** ; **QCM/VF LOCAUX** (jamais le port) ; replis : QCM/VF exact ⇒
  borne haute, sinon borne basse ; rédigée ⇒ **seuil de passage** ; « Je ne sais pas » ⇒ borne basse
  **sans appel**. **Écart assumé avec IFFD** (qui fait passer QCM/VF par l'IA) — **ne pas « corriger »
  vers IFFD**.
- **AD-36** — indices : **stocké → port** ; `shownHints` ; **éphémères** ; **plafond LOCAL,
  propriétaire unique, appliqué EN DERNIER sur la valeur rendue** ; plancher ≥ `passThreshold - 1`.
- **AD-33** — écriture SRS **uniquement** par `ZSessionReviewer` ; **jamais** `ZSrsScheduler.apply`
  en direct, **jamais** un store en champ. **su-3 n'écrit rien.**
- **AD-46** — échelle **0..5 possédée par `ZSrsConfig`** ; `clampQuality` = **unique voie de clamp** ;
  `ZQualityScale.fromConfig` **dérive**. **Ne JAMAIS redéclarer l'échelle ni écrire une borne en dur.**
- **AD-2 / AD-15** — réactivité **Flutter-native** ; **aucun** gestionnaire d'état ; controllers
  **stables** ; **aucun `setState`** de surface.
- **AD-13** — RTL, `Semantics`, **≥ 48 dp**, thème/l10n injectés, **Reduce Motion**, **canal non-coloré**.
- **AD-10 / NFR-SU6 / NFR-SU8** — **jamais** d'exception ; replis définis ; session **hors ligne** OK.
- **AD-1 / NFR-SU7** — graphe **acyclique**, **CORE OUT=0** ; **aucune** dépendance tierce.
- **AD-4** — `abstract interface class` en frontière inter-package (**jamais `sealed`**) ; **enums >
  booléens** ; échappatoire `extra`.
- **AD-34** *(consommé)* — les **3 runtimes existent** ; **aucun moteur** n'est créé.

### Key Don'ts (spécifiques à cette story)

- 🚫 **Jamais** faire évaluer un QCM/V-F par le port (AD-35) — même « en repli ».
- 🚫 **Jamais** laisser le port **noter** : il **suggère** ; l'utilisateur **valide** (AD-35).
- 🚫 **Jamais** écrire le SRS depuis su-3 (`ZSessionReviewer`/`ZSrsScheduler.apply`/`ZSm2Scheduler`/
  `ZRepetitionStore`) — **la porte dérobée est LOCALE à `zcrud_flashcard`** (AD-33).
- 🚫 **Jamais** appliquer le plafond **avant** la valeur rendue, ni **deux fois**, ni **pas du tout**.
- 🚫 **Jamais** une borne/un seuil en dur (`0`, `1`, `2`, `3`, `5`) — **tout** vient de `ZSrsConfig`.
- 🚫 **Jamais** appeler le port d'indices **avant** épuisement du `hint` stocké.
- 🚫 **Jamais** persister un indice généré ni muter la `ZFlashcard` reçue.
- 🚫 **Jamais** un booléen là où l'enum est exigé (`ZTimerDisplay`, `ZCardAdvanceBehavior`).
- 🚫 **Jamais** un `switch` avec `default` sur `ZFlashcardType`/`ZReviewMode`/`ZTimerDisplay`.
- 🚫 **Jamais** poser un **tap-to-reveal** sur la surface de saisie ; **jamais** retirer/affaiblir
  l'**`IgnorePointer` de su-2** (correctif d'un **HIGH réel**) ; **jamais** un `Dismissible`/
  `onHorizontalDrag` (su-4).
- 🚫 **Jamais** recréer un `TextEditingController`/`FocusNode` au rebuild ; **jamais** un `setState`
  de surface pendant la frappe ; **jamais** une closure de slot allouée dans `build()`.
- 🚫 **Jamais** une seconde primitive Reduce Motion (`zReduceMotionOf` **est** la primitive).
- 🚫 **Jamais** écrire dans `zcrud_core` / `zcrud_mindmap` / `zcrud_export` / `zcrud_export_ui`.
- 🚫 **Jamais** modifier un `pubspec.yaml` ni ajouter une dépendance.
- 🚫 **Jamais** toucher `sprint-status.yaml` (**orchestrateur seul**) ; **jamais** committer.
- 🚫 **Jamais** assouplir un test existant pour faire passer une retouche (leçon **D3**).

### Project Structure Notes

**NEW — `packages/zcrud_flashcard/lib/src/domain/`** : `z_flashcard_answer_evaluation_port.dart` ·
`z_flashcard_hint_port.dart` · `z_flashcard_local_evaluation.dart` · `z_hint_penalty.dart`.
**NEW — `packages/zcrud_session/lib/src/presentation/`** : `z_flashcard_answer_input.dart` ·
`z_timer_display.dart` · `z_card_advance_behavior.dart`.
**NEW — `packages/zcrud_session/lib/src/domain/`** : `z_flashcard_submission.dart`.
**UPDATE** : `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (**exports additifs**) ·
`packages/zcrud_session/lib/zcrud_session.dart` (**exports additifs**) ·
`packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart` (**`selectedQuality`
ADDITIF seul** — surface existante intouchée ; + dette ledger su-1 `:208,243`) ·
`packages/zcrud_session/test/presentation/z_widgets_purity_test.dart` (**étendue/durcie**, T4bis) ·
`packages/zcrud_session/test/presentation/z_widgets_hardcode_scan_test.dart` (**durcie**, T4bis).
⚠️ **Convention de test de `zcrud_session` (vérifiée)** : les tests de **widget** vivent dans
`test/presentation/` ; les tests **purs** à la racine de `test/`. **La respecter** (les deux gardes
ci-dessus résolvent `lib/src/presentation` **en chemin relatif au CWD du package**).
**LECTURE SEULE — patrons à copier, à NE PAS modifier** : `z_flashcard_generation_port.dart:89`
(**patron de port**) · `z_flashcard_review_card.dart:261` (**`IgnorePointer` / arène**) ·
`z_reduce_motion.dart:32` · `z_text_field_widget.dart:37,44` (**patron SM-1**) ·
`z_srs_quality_buttons.dart:197,212` (**a11y 48 dp**) · `z_srs_config.dart:129` (**`clampQuality`**) ·
`z_mindmap_view.dart:137-142` (**`builder ?? défaut`**).
**Convention** : API publique par barrel `lib/<pkg>.dart`, impl sous `lib/src/{domain,data,presentation}`,
types publics préfixés **`Z`**, fichiers `snake_case`, tests `*_test.dart`, `const` partout où possible.

### Ambiguïtés relevées & arbitrages (tranchés — mode non interactif, option la plus conservatrice)

1. **Foyer des ports** : **`zcrud_flashcard/domain`** — **imposé par le graphe** (`zcrud_study`
   dépend de `zcrud_flashcard` ⇒ les y mettre créerait un **cycle** ; le kernel ignore
   `ZFlashcardType`). *Aucune alternative valide.*
2. **Foyer de la surface de saisie** : **`zcrud_session/presentation`** — **imposé** par l'AC « un
   bouton SRS est **pré-sélectionné** » : `ZSrsQualityButtons` y vit et est **inatteignable** depuis
   `zcrud_flashcard`. Les alternatives (déférer à su-4 / redéclarer des boutons) violent
   respectivement la couverture d'AC et l'interdiction de **seconde implémentation**.
3. **Arène des gestes** : **dissoute par construction** (surfaces **disjointes**, aucun tap-to-reveal
   sur la saisie) plutôt qu'arbitrée par priorité de geste. *Le plus conservateur : su-2 n'est pas
   touché, son correctif HIGH est préservé, et « répondre » ne peut pas « dévoiler ».*
4. **Pré-sélection** : **`selectedQuality: int?` ADDITIF** sur `ZSrsQualityButtons` (défaut `null` ⇒
   comportement inchangé). *Alternative rejetée : un second widget = duplication.* `onQualitySelected`
   reste l'**unique** voie de notation (la « validation » **est** le tap).
5. **Rangée SRS optionnelle** : `onQualitySelected == null` ⇒ rangée **ABSENTE** (patron
   `ZItemActionsMenu`/AD-44, déjà ratifié par su-2 pour `onEdit`/`onDelete`) — **jamais** un booléen
   `showQualityButtons` (convention **enums > booléens**). ⇒ su-4 choisit ; **note ledger su-4** :
   ne pas rendre une **seconde** rangée au-dessus d'une carte interactive.
6. **« Je ne sais pas » = 1 (PRD) vs borne basse (spine/epic)** : **borne basse** (`minQuality`) —
   le spine prime (précédent AD-46, écart PRD déjà assumé). Avec `minQuality: 1`, **les deux lectures
   coïncident**. → **écart PRD à consigner**.
7. **`quota?` de la sortie AD-35** : **NON livré en v1**. `ZEducationQuotaInfo` (le VO de quota
   canonique) vit dans **`zcrud_study`** — **inatteignable** sans **cycle** ; le dupliquer serait une
   **seconde source**. Le spine le note **optionnel** (`quota?`) et aucun besoin bi-consommateur
   n'est démontré (« généricité au juste besoin »). L'échappatoire **`extra`** (AD-4) le loge si une
   app en a besoin. → **à signaler au code-review**.
8. **Champ de rédaction** : **`TextField` nu + controller stable**, **pas** `ZTextFieldWidget` —
   celui-ci exige un **`ZFieldSpec`** (concept du **moteur d'édition**, dérivé d'un modèle) alors que
   la réponse n'est **pas** un champ de modèle ; et il est **stateless** (la stabilité vit **dans
   l'hôte** de toute façon). Fabriquer un `ZFieldSpec` synthétique = cérémonie sans gain + import du
   décor d'édition dans une surface d'étude. Le **patron E3-2** est **imité** (documenté), pas le widget.
9. **Rédaction en markdown ?** (IFFD utilise un éditeur markdown) : **non** — FR-SU2 dit « rédaction
   de la réponse », sans exiger le riche ; un éditeur riche **rouvrirait l'arène D1** et ajouterait un
   point d'extension **non démontré** (spine : « un point d'extension ne s'ajoute que lorsque les deux
   consommateurs divergent réellement »). *Extension additive possible le jour où le besoin existe.*
10. **`countdown` sans `timeLimit`** : **dégradation en `elapsed`** (AD-10 : jamais d'exception,
    jamais un rebours depuis `null`). *Le plus conservateur.*
11. **`countdown` épuisé** : s'arrête à **zéro**, **aucune soumission forcée** (aucun AC ne l'exige —
    l'inventer serait du périmètre volé).
12. **Reduce Motion et auto-passage** : l'auto-passage **N'EST PAS supprimé** par Reduce Motion —
    c'est une **fonction** (avancer), pas une **animation** ; su-2 a fixé la règle « dégradation de
    l'ANIMATION, jamais de la FONCTION ». Toute affordance **animée** de su-3 passe en revanche par
    **`zReduceMotionOf`** (primitive unique). → **à signaler au code-review** (lecture alternative
    défendable : un délai de 200 ms est agressif pour un lecteur d'écran — mais **aucun AC ne le dit**).
13. **Délai d'auto-passage** : **200 ms** paramétrable (parité IFFD F13, rapport de parité annexe).
14. **`hintsUsed` transmis au port** : **oui, informatif** (AD-36 mot pour mot) — **sans** que le port
    n'en tire de pénalité (le plafond **local** est l'unique propriétaire).

### Previous Story Intelligence (su-2 — `review`/vert ; su-1 — `done`)

- **Consommer, ne pas refaire** : `ZFlashcardReviewCard` (6 types, `ZRevealTransition`, Reduce
  Motion, slot AD-40 branché, face **défilable**, contenu **hissé en `child:`**) ·
  `ZFlashcardMarkdownContent` · **`zReduceMotionOf`** · `ZSrsConfig` (**échelle 0..5 +
  `clampQuality`**) · `ZQualityScale.fromConfig` · **les 3 runtimes de session**.
- **Le HIGH D1 de su-2 est le contexte direct de su-3** : le `QuillEditor` **vole l'arène**.
  su-2 l'a neutralisé par `IgnorePointer` **parce que « su-2 affiche »** ; su-3 **traite l'arène
  frontalement** (AC9) — **sans** toucher au correctif de su-2.
- **Leçons de revue à NE PAS rejouer** : D5 (test qui appelle sa propre closure) · D4 (scan
  ligne-à-ligne) · D6 (contre-preuve qui recopie le scanner) · D7 (branche de repli jamais atteinte)
  · su-2 D2 (**association** ≠ présence) · su-2 D3 (**test modifié pour taire un défaut réel**) ·
  su-2 D5 (**sonde sur un sibling**) · su-2 D7 (nœud cherché **par le libellé à vérifier**) ·
  su-2 D12 (**deux canaux qui se masquent** — chaque garde rougit **SEULE**) · su-2 D13 (branche
  jamais exercée).
- **Dette pré-existante tracée, ledger su-3/su-4** (`code-review-su-1.md`) :
  `z_srs_quality_buttons.dart:208` — **`'ok'`/`'lapse'` EN DUR** dans `Semantics.value` et
  `fontSize: 12` en dur (`:243`). **su-3 touche ce fichier (T4)** ⇒ **les corriger si le périmètre le
  permet sans régression** (règle MEDIUM du projet), sinon **justifier par écrit**.
  `ZQualityScale.fromConfig` n'est **jamais `const`** ⇒ **hoister hors du `build()`**.
- **Ledger su-5** (L8 de su-2) : `zReduceMotionOf` n'est ni gardé ni atteignable depuis
  `zcrud_mindmap`/`zcrud_ui_kit` — **hors périmètre su-3** (son foyer naturel, `zcrud_core`/
  `zcrud_ui_kit`, est **interdit d'écriture** en story SU). ⚠️ `zcrud_session` **dépend de**
  `zcrud_flashcard` ⇒ su-3 **peut** l'importer : **le réutiliser, jamais le recopier**.
- **Ledger su-8** (L5 de su-2) : `question: ''` ⇒ face vide sur le **défaut** (`ZFlashcardDefaultContent`,
  fichier de su-1).

### Git Intelligence

`git log` (5 derniers) : `9ea262f` bump 0.2.0→0.2.1 · `46afb56` epic **EX-UI** · `9e405a0` bump
0.1.0→0.2.0 · `ecd4753`/`2df33be` (sprint-status). **Le travail de su-1/su-2 n'est PAS committé**
(commit **en fin d'epic** — règle projet). ⇒ **Ne PAS committer** ; **ne PAS toucher** `pubspec.lock`
(racine et `example/`). Contraintes inter-packages en **`^0.2.1`** : les symboles de su-3 sont
**additifs** ⇒ **aucun bump**. ⚠️ `pubspec.lock` et `example/pubspec.lock` sont **déjà modifiés** dans
l'arbre (`git status`) — **ne pas les inclure**, ne pas les « nettoyer ».

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.3: Saisie interactive notée, indices, minuteur et avance`] — **spécification source des ACs** · [`#FR Coverage Map`] (FR-SU2/3/4/5 | 1.3) · [`#Story 1.4`]/[`#Story 1.7`] — frontières su-4/su-7
- [Source: `.../architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-35`] (advisory, QCM/VF locaux) · [`#AD-36`] (indices, plafond local en dernier) · [`#AD-33`] (seam `ZSessionReviewer`) · [`#AD-46`] (échelle possédée par `ZSrsConfig`) · [`#AD-34`] · [`#Invariants hérités`] (AD-2/10/13/15) · [`#Conventions`] (enums > booléens ; défauts d'avance **par mode** ; généricité au juste besoin) · [`#Placement des paquets`] · [`#Écarts assumés`]
- [Source: `.../prds/prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU2`] · [`#FR-SU3`] · [`#FR-SU4`] · [`#FR-SU5`] · [`#NFR-SU2`] (SM-1) · [`#NFR-SU3/4/5/6/7/8`] · [`#4. Glossaire`] (qualité 0-5) · [`#6. Critères de succès`] (contre-métriques)
- [Source: `docs/parity-study-ui-2026-07-16/rapport.md#2. Matrice de parité — FLASHCARDS`] · [`#5. Sources best-of-breed`] · [`annexes/iffd_flashcards.md#F13`] — **source best-of-breed** `interactive_flashcard_repetition_card.dart` (~1050 l., **LECTURE SEULE**, `/home/zakarius/DEV/iffd`) : saisie par type, éval locale QCM/VF, indices, « Je ne sais pas » (q1), `Stopwatch`, **auto-passage 200 ms** · [`annexes/iffd_flashcards.md#F14`] (feedback pédagogique = **su-5**)
- [Source: `_bmad-output/implementation-artifacts/stories/code-review-su-2.md#D1`] — **HIGH : l'arène des gestes** (contexte direct d'AC9) · [`#D2`] · [`#D3`] · [`#D5`] · [`#D12`] — patrons de garde à ne pas rejouer
- [Source: `_bmad-output/implementation-artifacts/stories/su-2-carte-revision-adaptative.md#⚠️ Périmètre : su-2 AFFICHE, su-3 FAIT SAISIR (frontière dure)`] — **frontière héritée**
- [Source: `_bmad-output/implementation-artifacts/stories/code-review-su-1.md#LOW`] — dette `z_srs_quality_buttons.dart:208,243` **léguée au ledger su-3/su-4**
- [Source: `CLAUDE.md#Critical Patterns`] · [`#Key Don'ts (zcrud)`] · [`#Processus BMAD strict`] — vérif verte `analyze`/`verify` **repo-wide** avant `done`
- [Source: `_bmad-output/implementation-artifacts/sprint-status.yaml:447-464`] — workstreams (A)/(B)/(C) à **packages disjoints**

## Dev Agent Record

### Agent Model Used

`claude-opus-4-8[1m]` — skill `bmad-create-story` (mode non interactif).

### Debug Log References — `bmad-dev-story`

- 🔴 **INCIDENT (détecté, réparé, prouvé) — `git checkout` a DÉTRUIT du travail su-1 non committé.**
  Pour restaurer une injection R3 sur `z_srs_config.dart`, j'ai utilisé `git checkout` : ce fichier
  est **suivi par git MAIS modifié sans commit** (su-1) ⇒ le checkout l'a ramené à **HEAD (9ea262f)**,
  **supprimant `minQuality`/`maxQuality`/`clampQuality`** (le cœur d'AD-46 livré par su-1). Ni stash,
  ni index, ni reflog ne pouvaient le rendre. **Restauré à l'identique** depuis le `cat` complet fait
  en début de session, puis **vérifié par un juge indépendant** : `z_srs_config_test.dart` (le test
  que su-1 a écrit POUR ces symboles) passe, et `zcrud_flashcard` retrouve **exactement 359 + 29 =
  388** tests. **Diff net de su-3 sur ce fichier : AUCUN.**
  ⇒ **Règle appliquée pour tout le reste de la story** : **jamais `git checkout` dans cet arbre**
  (su-1/su-2 sont non committés) — **toute** restauration d'injection passe par `cp` depuis
  `/tmp/su3_sha/*.bak` + **vérification `sha256sum -c`**. La story anticipait le risque pour les
  fichiers *non suivis* ; le cas **suivi-mais-modifié** est **pire** et n'était pas prévu.
  → **à signaler au code-review** (leçon transverse su-4/su-5).
- **Arbitrage non interactif consigné** : le skill (step 4/9) prescrit d'écrire `sprint-status.yaml`.
  **Non exécuté** — l'orchestrateur est seul habilité (option la plus conservatrice). Le `Status` de
  la story porte la transition. `baseline_commit: 9ea262f` **préexistant : préservé**.
- **`persistent_facts`** (`file:**/project-context.md`) : **aucun fichier** ⇒ facts chargés depuis
  `CLAUDE.md` + le spine (idem `bmad-create-story`).

### 🔬 Écarts MESURÉS vs les injections prescrites (consignés, jamais tus)

Trois prescriptions de la story se sont révélées **fausses à la mesure**. Aucune n'a été « rendue
verte » par complaisance : chacune est prouvée et remplacée par une garde qui, elle, discrimine.

1. **R3-I6 (« plafond AVANT clamp ⇒ ROUGIT ») est INATTEIGNABLE.** Sonde exhaustive sur les **1144
   combinaisons atteignables** (`passThreshold ∈ {3,4}` × `minQuality ∈ {0,1}` × `hints 0..10` ×
   `raw -10..15`) ⇒ **0 divergence**. Les deux ordres sont **commutatifs** :
   `min(clamp(x), c) == clamp(min(x, c))` **dès lors que le plafond `c` est dans l'échelle** — ce
   qui est garanti par `floor ≥ passThreshold - 1 ≥ minQuality` et `ceiling ≤ maxQuality`. Écrire un
   test « prouvant l'ordre » aurait été un test **incapable de rougir**. ⇒ L'**ordre imposé est
   néanmoins implémenté** (mandaté, et robuste si l'invariant tombait) et l'on **pin l'invariant
   PORTEUR** (`z_hint_penalty_test.dart` › « le plafond reste TOUJOURS DANS l'échelle ») : il rougira
   le jour où un plancher passerait sous `minQuality` — moment où l'ordre redeviendrait load-bearing.
   La garde anti-contournement RÉELLE est **R3-I6d** (oublier le plafond sur le chemin advisory),
   jouée et **rouge** (widget + pur).
2. **Le discriminant « port ⇒ 9 ⇒ cran 5 » d'AC2 est MASQUÉ (défaut D12).** Avec 0 indice,
   `ceiling = max(5-0, 2) = 5` ⇒ `min(9, 5) = 5` **même sans `clampQuality`** : le plafond rend le
   clamp invisible. **Seule la borne basse discrimine** (`-3 ⇒ 0` ; sans clamp : **-3**, hors
   échelle). Vérifié par injection : R3-I2 ne rougit **que** via le cas bas. Les deux tests porteurs
   sont **nommés** pour qu'on ne les supprime pas en croyant le cas haut suffisant.
3. **Le défaut D4 n'est RÉEL que dans `z_widgets_hardcode_scan_test.dart`.** Mesuré avec le **vrai**
   `dart format --line-length 80` : `EdgeInsets.only(left:` et `Color(0x` **disparaissent de toutes
   les lignes** (angle mort authentique) ; en revanche `.apply(`/`.reviewCard(` **survivent** (le
   formateur coupe **avant** le `.`, jamais entre un nom et sa parenthèse) et
   `ZSm2Scheduler`/`ZRepetitionStore` sont des identifiants **insécables**. ⇒ Le durcissement de
   `z_widgets_purity_test.dart` est **prophylactique** et **déclaré comme tel** dans le fichier (il
   ferme les coupures écrites à la main et tout futur motif de forme `Nom(arg:`) — **prétendre** qu'il
   comblait un trou aurait été faux. *(Mon premier jet l'a prétendu ; ma propre contre-preuve l'a
   démasqué et j'ai corrigé le commentaire, pas le test.)*

### 🐛 Défauts RÉELS trouvés par les tests (code corrigé, jamais le test assoupli)

- **Bouton « Indice » survivant à l'épuisement** : `_hintAvailable` était calculé dans `build()`, or
  le `build()` de la surface **ne se rejoue pas** quand un indice s'ajoute (c'est tout l'objet de
  SM-1) ⇒ le bouton restait affiché alors que le port était `null` et le stocké consommé (violation
  du patron `ZItemActionsMenu`). **Corrigé** : la disponibilité est recalculée **dans** le
  `ValueListenableBuilder` de `_HintSection`, sur `shownHints` **observé**.
- **Minuteur figé en test** : l'affichage lisait `_stopwatch.elapsed`, or un `Stopwatch` lit
  l'horloge **réelle** et n'est **pas** *fakeable* — `tester.pump(1s)` fait avancer les `Timer` mais
  **pas** le `Stopwatch` ⇒ l'affichage restait à `00:00` et **aucun test ne pouvait prouver**
  qu'`elapsed` croît / `countdown` décroît. **Corrigé** : la **mesure** (`timeTaken`, envoyée au
  barème) reste le `Stopwatch` (exacte, AC7 « toujours mesuré ») ; l'**affichage** cumule les ticks
  de son propre ticker (granularité seconde, armé seulement s'il est visible). Rationale documentée
  dans le code.
- **Test AC9 (3) aveugle** : `R3-I9` (poser un `InkWell(onTap: reveal)` sur la saisie) **restait
  vert** — l'assertion ne regardait que `zFeedback`, absent quand une correction n'a pas de
  `feedback`. **Test renforcé** (la rangée SRS devient le témoin observable d'« une correction a eu
  lieu ») ; l'injection rougit désormais. *Le code était juste, le test était faux.*
- **`persistent_facts`** (`file:{project-root}/**/project-context.md`) : **aucun fichier**
  `project-context.md` dans le repo (`find . -name "project-context.md"` → aucun résultat) ⇒ facts
  chargés depuis `CLAUDE.md` + le spine.
- **Compteurs de tests rejoués sur disque** (référence de non-régression) : `zcrud_flashcard`
  **359** · `zcrud_session` **86** (`flutter test` par package, RC=0).

### Completion Notes List

- ACs **repris de `epics.md` Story 1.3** (11 ACs : les 9 de l'epic + arène des gestes + gates) —
  jamais inventés.
- Périmètre vérifié sur disque : **7 preuves par grep négatif** (RC cités) — les **deux ports sont
  ABSENTS** et à créer ; `ZFlashcardGenerationPort` **existe** (patron).
- **Placement des paquets démontré par le graphe** (et non choisi) : ports ⇒ `zcrud_flashcard`
  (sinon **cycle** avec `zcrud_study`) ; surface ⇒ `zcrud_session` (sinon `ZSrsQualityButtons`
  **inatteignable** ⇒ AC2 non couvrable).
- **Arène des gestes traitée frontalement** (AC9) : dissoute **par construction** ; le correctif HIGH
  D1 de su-2 est **protégé par une garde de non-régression**.
- **14 arbitrages** consignés ; **2 écarts à signaler au code-review** (« Je ne sais pas » = borne
  basse vs PRD « 1 » ; `quota?` non livré — cycle).

#### `bmad-dev-story` — implémentation (11 AC / 13 tâches)

- **AC1..AC11 : tous implémentés et couverts.** Les **14 arbitrages** de la story ont été
  **appliqués sans être re-litigés** (foyers imposés par le graphe, arène dissoute par construction,
  `selectedQuality` additif, rangée SRS absente si `onQualitySelected == null`, « Je ne sais pas » =
  `minQuality`, `quota?` non livré → `extra`, `TextField` nu, pas de markdown en saisie, `countdown`
  sans `timeLimit` → `elapsed`, arrêt à zéro sans soumission forcée, Reduce Motion ne supprime pas
  l'auto-passage, 200 ms paramétrable, `hintsUsed` informatif).
- **Vérif verte RÉELLE** : `melos run generate` **RC=0** · `melos run analyze` **RC=0 repo-wide** ·
  `melos run verify` **RC=0 repo-wide** · **23/23 packages, 3876 tests** (`flutter test` par package,
  séquentiel — `melos run test` reste inutilisable). Réf. su-2 **3725** ⇒ **+151** :
  `zcrud_flashcard` **359 → 398** (+39), `zcrud_session` **86 → 198** (+112). **Zéro régression.**
- **Aucune arête de graphe ajoutée** : **aucun `pubspec.yaml` touché**, aucune dépendance tierce.
  L'import direct de `zcrud_study_kernel` s'est révélé **redondant** (le barrel `zcrud_flashcard`
  réexporte `ZReviewMode`) ⇒ retiré.
- **Dette du ledger su-1 SOLDÉE** (`z_srs_quality_buttons.dart`, T4) : `'ok'`/`'lapse'` **localisés**
  (`zcrud.srs.quality.passed/lapsed`, `fallback` préservant le texte historique ⇒ zéro régression) ;
  `fontSize: 12` → `Theme.of(context).textTheme.labelSmall` (respecte enfin le `textScaler`).
  *Reste au ledger* : `ZQualityScale.fromConfig` n'est toujours pas hoistée hors du `build()` de
  `ZFlashcardAnswerInput` — **volontaire** : le VO est trivial (2 `int`), non-`const` **par nécessité
  du langage**, et le hoister exigerait un `StatefulWidget` de plus ; **aucun** chemin SM-1 ne le
  traverse (il n'est construit qu'**après** soumission, jamais pendant la frappe).
- **Trou de conception fermé (non demandé par la story, mais nécessaire à AD-35)** :
  `zEvaluateLocally` rend `null` pour **deux** raisons distinctes (type non local / carte
  **malformée**). Un routage « `null` ⇒ appeler le port » aurait envoyé un **QCM malformé à l'IA** —
  violation d'AD-35 **silencieuse** (aucun test de chemin nominal ne la verrait). ⇒ Le routage passe
  par `zIsLocallyEvaluatedType(type)`, qui ne regarde **que le type**. Test dédié.
- **Sous-arbitrage AD-10 consigné** : un QCM **sans aucun `isCorrect`** rend `null` (aucune saisie)
  plutôt que de traiter `{} == {}` comme « exact » — sinon une carte malformée **récompenserait**
  `maxQuality` à qui ne coche rien. Non prévu par la story ; option la plus conservatrice.
- **Écart de signature consigné** : la story prescrit `Set<String> selectedChoiceIds` — or **`ZChoice`
  ne porte AUCUN `id`** (champs réels : `content`, `isCorrect`, vérifiés sur disque) et deux choix
  peuvent avoir un `content` **identique**. La **position** est la seule identité fiable ⇒
  `Set<int> selectedChoiceIndexes`. Fabriquer des ids-chaînes aurait inventé un concept inexistant.
- **Preuve R3 : 13 injections JOUÉES RÉELLEMENT** (rouge obtenu, puis restauration prouvée par
  **SHA-256** — `cp`, jamais `git checkout`, cf. Debug Log) : I1b, I1c, I2, I3b, I4, I6b, I6c, I6d,
  I7, I7b, I7c, I8, I8b, I8c, I9, I9b, I10, I10b, I11, I11b(D2 réel). **3 prescriptions mesurées
  FAUSSES** et consignées ci-dessus (I6 commutatif · « 9 ⇒ 5 » masqué · D4 réel seulement côté
  hardcode). **SM-1 prouvé** : l'injection `setState` de surface fait reconstruire le contenu
  **101 fois** — le bug historique est bien capté.
- **Arène des gestes tenue** : `IgnorePointer` de su-2 **intact** (garde de non-régression verte sur
  le **chemin markdown exact** du HIGH D1) ; contenu de saisie **également** sous `IgnorePointer` ;
  **aucun** tap-to-reveal / `Dismissible` / `onHorizontalDrag` dans le code de prod de su-3 (gardes de
  source **par déclaration** + contre-preuves R12). Les 3 tests comportementaux passent avec les deux
  surfaces composées en **frères** sur le chemin markdown.
- **Gardes T4bis ÉTENDUES, jamais dupliquées** : le nouveau widget est **né gardé** (les 2 scans
  s'auto-énumèrent sur `presentation/**`) — vérifié avant toute édition. Aucune garde parallèle
  créée (pas de `z_session_rtl_guard_test.dart`).

### File List

**NEW — `packages/zcrud_flashcard/lib/src/domain/`** (ports + logique PURE)
- `z_flashcard_answer_evaluation_port.dart` — port ADVISORY + `ZFlashcardAnswerEvaluationRequest`/`ZFlashcardAnswerEvaluation` (AC2/AC3)
- `z_flashcard_hint_port.dart` — port d'indices + `ZFlashcardHintRequest` (AC5)
- `z_flashcard_local_evaluation.dart` — `zEvaluateLocally` / `zIsLocallyEvaluatedType` / `zIsSingleChoiceQcm` / `zCorrectChoiceIndexes` (AC1)
- `z_hint_penalty.dart` — `ZHintPenaltyPolicy` / `zApplyHintCeiling` / `zHintCeilingFloor` (AC6)

**NEW — `packages/zcrud_session/lib/src/`**
- `domain/z_flashcard_submission.dart` — VO advisory (AC2, pur-Dart)
- `presentation/z_timer_display.dart` — enum (AC7)
- `presentation/z_card_advance_behavior.dart` — enum + table UNIQUE `zDefaultAdvanceBehavior` (AC8)
- `presentation/z_flashcard_answer_input.dart` — surface de SAISIE (AC1..AC11)

**MODIFIED**
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` — 4 exports additifs
- `packages/zcrud_session/lib/zcrud_session.dart` — 4 exports additifs
- `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart` — `selectedQuality` ADDITIF + **dette ledger su-1 soldée** (`'ok'`/`'lapse'` l10n `:208`, `fontSize: 12` → `textTheme.labelSmall` `:243`)
- `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart` — ⚠️ **restauré à l'identique** (cf. Debug Log : incident `git checkout`), aucune modification nette de su-3

**NEW — tests**
- `zcrud_flashcard/test/z_flashcard_local_evaluation_test.dart` · `z_hint_penalty_test.dart` · `z_flashcard_ai_ports_surface_test.dart`
- `zcrud_session/test/z_card_advance_behavior_test.dart`
- `zcrud_session/test/presentation/z_answer_input_harness.dart` *(doublures partagées, non-`_test`)* · `z_flashcard_answer_input_qcm_vf_test.dart` · `z_flashcard_answer_input_advisory_test.dart` · `z_flashcard_answer_input_fallback_test.dart` · `z_flashcard_answer_input_hints_test.dart` · `z_flashcard_timer_test.dart` · `z_flashcard_advance_test.dart` · `z_flashcard_gesture_arena_test.dart` · `z_flashcard_answer_input_sm1_test.dart` · `z_flashcard_answer_input_a11y_test.dart`

**MODIFIED — gardes EXISTANTES ÉTENDUES/DURCIES (T4bis, jamais dupliquées)**
- `zcrud_session/test/presentation/z_widgets_purity_test.dart` — `ZSrsScheduler`/`ZSm2Scheduler`/`ZSessionReviewer` ajoutés ; scan **par déclaration** + contre-preuve R12
- `zcrud_session/test/presentation/z_widgets_hardcode_scan_test.dart` — scan **par déclaration** + contre-preuve R12

🚫 **NON touchés** : `sprint-status.yaml`, tout `pubspec.yaml`, `pubspec.lock`, `zcrud_core`, `zcrud_mindmap`, `zcrud_export`, `zcrud_export_ui`. **Aucun commit.**

### Change Log

| Date | Changement |
|---|---|
| 2026-07-17 | Story créée (`bmad-create-story`, mode non interactif). ACs repris de `epics.md` Story 1.3 ; périmètre vérifié sur disque (7 preuves par grep négatif, RC cités) ; placement des paquets **démontré par le graphe** ; arène des gestes (HIGH D1 de su-2) traitée frontalement en AC9 ; dette `z_srs_quality_buttons` du ledger su-1 rappelée (T4). Statut → `ready-for-dev`. |
| 2026-07-17 | **`bmad-dev-story`** — AC1..AC11 implémentés (13 tâches, 13 fichiers de test neufs, 2 gardes existantes étendues/durcies). Ports + logique pure dans `zcrud_flashcard/domain` ; surface + enums dans `zcrud_session`. Dette ledger su-1 **soldée**. **13 injections R3 jouées réellement** (rouge → restauration prouvée par SHA-256) ; **3 prescriptions d'injection mesurées FAUSSES** et consignées (R3-I6 commutatif ; discriminant « 9 ⇒ 5 » masqué par le plafond, défaut D12 ; défaut D4 réel côté hardcode seulement). **3 défauts réels corrigés côté CODE** (bouton Indice survivant à l'épuisement ; minuteur invérifiable car adossé au `Stopwatch` réel ; test AC9 aveugle renforcé). **Incident consigné** : `git checkout` a détruit du su-1 non committé (`z_srs_config.dart`) — restauré à l'identique et prouvé (test su-1 vert, 359+29=388). Vérif verte : `generate`/`analyze`/`verify` **RC=0 repo-wide**, **23/23 packages, 3876 tests** (3725 + 151). Statut → `review`. |
</content>
</invoke>
