# Story SU.7 : UI d'examen blanc

Status: review

Clé sprint-status : `su-7-ui-examen-blanc`
Ligne du sprint-status (mot pour mot, contrat de périmètre) :
> `[M][A — après su-6 ; réutilise su-3] FR-SU13 ZListSessionView sur ZWhiteExamSessionEngine ; correction en fin d'examen ; ZÉRO écriture SRS (garanti par le type)`

## Story

As an **apprenant**,
I want **passer un examen blanc en liste et voir ma correction à la fin**,
so that **je m'entraîne en conditions réelles sans polluer ma répétition espacée**.

---

## 🔬 Vérité de disque établie AVANT rédaction (aucune affirmation de mémoire)

> ⚠️ **Discipline** : toute **absence** ci-dessous est prouvée par un **grep négatif sans pipe**
> (`grep -q` ; RC de `head` interdit) et en **`-qF`** dès qu'un `$` est en jeu (métacaractère BRE).
> Le dev **rejoue** ces greps avant d'écrire une ligne : s'ils ne rendent plus le même RC, la
> prémisse de la story a bougé → **STOP et signalement**, jamais un contournement.

### G1 — `ZListSessionView` et ses approchants sont ABSENTS (le widget est bien NEUF)

```bash
cd /home/zakarius/DEV/zcrud
grep -rqF "ZListSessionView" packages/ example/ ; echo "RC=$?"   # RC=1 → ABSENT ✅
for s in ZListSession ZExamView ZWhiteExamView ZExamSessionView ZListSessionScreen ZExamDraft; do
  grep -rqF "$s" packages/ example/ ; echo "$s RC=$?"            # tous RC=1 → ABSENTS ✅
done
```

**Verdict** : aucun widget d'examen n'existe. Le brief est confirmé sur disque — **seul le moteur
existe**, l'UI d'examen blanc est le trou de parité que su-7 comble. Il n'y a **rien à réutiliser
ni à renommer** : `ZListSessionView` est une **création**, pas une reprise.

### G2 — Contrat RÉEL de `ZWhiteExamSessionEngine` (LU, pas supposé)

Fichier : `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart` (354 lignes),
exporté au barrel (`packages/zcrud_session/lib/zcrud_session.dart:40`).

```dart
// :249 — le constructeur, VERBATIM
ZWhiteExamSessionEngine({
  required List<ZSessionItem> queue,
  ZSrsConfig config = const ZSrsConfig(),
  ZExamScoringPort scorer = scoreWhiteExam,
})
```

| Question posée par l'orchestrateur | Réponse **vérifiée sur disque** |
|---|---|
| A-t-il un paramètre `mode` ? | **NON** — le constructeur n'accepte que `queue`/`config`/`scorer`. Le mode est une **propriété du type** : `scoreWhiteExam` (`:228`) code en dur `mode: ZReviewMode.whiteExam`. |
| A-t-il un paramètre `reviewer` ? | **NON** — aucun `ZSessionReviewer`, aucun scheduler, aucun store. |
| Peut-il écrire le SRS ? | **NON, par CONSTRUCTION** : aucun seam à atteindre. Ses seuls imports sont `ZSrsConfig` (`:53`, pour le **seuil** seul) et `ZReviewMode`/`ZStudySessionResult` (`:54`). |
| Le `scorer` rouvre-t-il la voie SRS ? | **NON** : `typedef ZExamScoringPort = ZStudySessionResult Function(List<int>, {required int passThreshold})` (`:184`) — entrées = qualités + seuil, sortie = un agrégat. **Aucun store/scheduler dans la signature** ⇒ un scorer tiers ne peut pas écrire. |

⇒ **La ligne du sprint-status (« garanti par le type ») est EXACTE.** L'AC centrale de su-7 est
donc **structurelle**, et l'unique risque résiduel n'est **pas** dans le moteur : il est dans le
**widget neuf**, seul objet capable d'importer un `ZSessionReviewer` de son propre chef.

**API publique consommable** (LUE) :
`state`/`phase`/`current`/`answered`/`remaining`/`result`/`isSubmitted` (getters) ;
`start()` (`:301`), `answer(int quality)` (`:316`), `submit()` (`:333`) ; `extends ChangeNotifier`,
`notifyListeners()` **granulaire** (`_setState` `:349` ne notifie que si `==` profond diffère).
Producteur de résultat **unique** : `scoreWhiteExam` (`:215`, `return` `:228`).

### G3 — ⚠️ PIÈGE MAJEUR : le moteur **LÈVE `StateError`**, il ne se tait jamais

`start()` hors `setup`, `answer()` hors `running`, `submit()` hors `running` (**double submit**)
⇒ **`StateError`** (`:303`, `:318`, `:335`). C'est **voulu** (R6 : « no-op muet interdit ») et
**hors périmètre de su-7** : on ne touche pas au moteur.

**Conséquence NON NÉGOCIABLE pour su-7** : AD-10 interdit à l'UI de lancer une exception. La vue
ne « rattrape » **pas** ces `StateError` en `try-catch` — elle **rend structurellement
impossible** de les provoquer : **toute affordance est gatée par la phase**, jamais par un
booléen local dérivé (un booléen se désynchronise, la phase est la vérité). Un `catch` sur ces
`StateError` serait un **finding majeur** : il masquerait un bug de gating au lieu de le révéler.

### G4 — `ZFlashcardAnswerInput` (su-3) : ce qu'il offre RÉELLEMENT

Fichier : `packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart` (1515 lignes).

Constructeur (`:103`) : `card`, `mode`, `srsConfig`, `contentBuilder`, `evaluationPort`,
`hintPort`, `hintPolicy`, `timerDisplay`, `timeLimit`, `advanceBehavior`, `autoAdvanceDelay`,
`onSubmitted`, `onQualitySelected`, `onAdvance`.

- `onSubmitted` émet un **`ZFlashcardSubmission`** (`:162`) = `{quality (déjà clampée ET
  plafonnée), timeTaken, hintsUsed, isCorrect?, feedback?}` — **su-3 n'écrit RIEN** (AD-33), il
  **émet un fait**.
- L'évaluation **QCM/VF est LOCALE** et déterministe (`zIsLocallyEvaluatedType`, `:509`), jamais
  l'IA (AD-35). **su-7 ne réimplémente aucune évaluation.**

🔴 **Le point dur, mesuré sur disque** : su-3 affiche la correction **immédiatement**. L'état
`_correction` (`ValueNotifier<_Correction?>`, `:255`) est posé par `_emit` (`:454`) et pilote
`_CorrectionSection` (`:719`), `_ChoiceRow(showCorrection: corrected != null)` (`:910`), les
icônes de vérité (`:975`) et le `statusText` (`:984`). **Il n'existe AUCUN paramètre public
permettant de différer cet affichage** :

```bash
grep -qF "correctionVisibility" packages/zcrud_session/lib/ ; echo "RC=$?"   # RC=1 → ABSENT
grep -qE "showCorrection|revealCorrection" packages/zcrud_session/lib/zcrud_session.dart ; echo "RC=$?"  # RC=1 → rien de public
```

⇒ **su-7 doit ouvrir ce gate dans su-3** (cf. D2). Reconstruire une saisie parallèle serait la
**duplication exacte** que la ligne du sprint-status (« réutilise su-3 ») interdit.

🔴 **Sous-piège dérivé (à ne PAS rater)** : `corrected != null` gate **deux choses distinctes**
au même endroit — (1) l'**affichage** de la correction et (2) le **verrouillage d'interaction**
(`onTap: corrected != null ? null : …`, `:912`). Naïvement « différer » en laissant
`_correction.value` à `null` **casserait le verrou** : les choix redeviendraient tapables après
soumission, et le QCM auto-soumis pourrait ré-émettre. **Le gate de su-7 porte sur le RENDU
SEUL** ; `_correction` **reste posé** (le verrou d'interaction et le `_submitLocked` one-shot
(`:288`) restent intacts).

### G5 — Acquis su-4/su-5/su-6 réutilisés tels quels

| Acquis | État disque | Usage en su-7 |
|---|---|---|
| `ZSessionSummaryView` (`:129`, ctor `:149`) | livré ; `result`/`duration`/`config`/`onFinish` requis ; `onStackEnd` à **latch one-shot** | **réutilisé** pour l'agrégat de fin |
| `ZSessionProgressIndicator` (ctor `:69` : `total`, `currentIndex`, `passThreshold`) | livré | **réutilisé** pour la progression (jamais un compteur réécrit) |
| `ZSessionCardSwiper` — `key` dérivée de l'identité de file (`_queueGeneration`) | livré | **patron emprunté** (D8), le swiper lui-même **n'est pas** utilisé (l'examen est une **liste**, pas une pile) |
| `ZQualityScale.fromConfig` / `config.clampQuality` / `masteredThreshold` (getter dérivé) | livrés (AD-46) | **consommés**, **JAMAIS redéclarés** |
| `ZFlashcardTestFilters` / `zApplyTestFilters` / `zShuffleChoices` (su-6) | livrés, **NON câblés** | **NON câblés ici non plus** — cf. **D6**, tranché et justifié |

### G6 — Gardes auto-énumérantes : le widget naît gardé (ne rien paralléliser)

- `packages/zcrud_session/test/presentation/z_widgets_purity_test.dart` : scanne
  **`lib/src/presentation/**` récursivement** (« n'énumère JAMAIS une liste figée », R16) et
  **bannit** `z_study_session_engine` / `z_white_exam_session_engine` / `z_linear_session_state` /
  `ZRepetitionStore` / un gestionnaire d'état / `ZSessionReviewer` / `.reviewCard(`.
  ⇒ **`ZListSessionView` est capté automatiquement, sans éditer le test.**
  🔴 **Contrainte d'architecture qui en découle, à lire deux fois** : la vue **ne peut pas
  importer le moteur**. `ZListSessionView` **reçoit** donc son `ZWhiteExamSessionEngine`… ce qui
  serait *aussi* un import interdit. **Résolution imposée : la vue ne connaît PAS le moteur** —
  cf. **D3**, c'est la décision structurante de cette story.
- `z_widgets_hardcode_scan_test.dart` : bannit couleurs/libellés en dur → **étendu, jamais dupliqué**.
- 🔴 **Contraste WCAG** (`z_session_mode_selector_test.dart:1069`) : énumère **tous les `RichText`**
  et exige **≥ 4,5:1**. Elle **couvrira automatiquement** les nouveaux widgets. **NE PAS la dupliquer.**
- 🔴 **Énumération a11y AC14** (`z_session_mode_selector_test.dart:306`, 11 clés `:335-344`) :
  **À ÉTENDRE** avec les clés de su-7. ⚠️ **Leçon su-6** : cette énumération avait **omis un dialog
  entier** du même diff ⇒ 4 tuiles non gardées, **4/4 défectueuses**. **Balayer tout le diff de su-7**,
  dialog de confirmation **inclus**.
- ⚠️ **Les gardes utilisent `Directory('lib')` RELATIF** ⇒ `flutter test` depuis la racine = **26 faux
  échecs**. **Lancer depuis `packages/zcrud_session/`.** `melos run test` est **INUTILISABLE**
  (parallélise, se bloque).

---

## Acceptance Criteria

> Chaque AC porte : **fichier réel**, **test porteur**, **injection R3** qui doit le faire rougir
> **par le COMPORTEMENT**. Une injection qui casse la **compilation** rougit tout et ne prouve **RIEN**.

### AC1 — `ZListSessionView` affiche l'examen en liste, chaque question offrant la saisie de su-3

**Given** une file de cartes déjà sélectionnée
**When** `ZListSessionView` s'affiche
**Then** chaque question offre la **saisie interactive de su-3** (`ZFlashcardAnswerInput`, jamais
une saisie réécrite) **And** la liste est **virtualisée** (`ListView.builder` — `ListView(children:)`
est interdit) **And** la progression vient de `ZSessionProgressIndicator` (aucun compteur parallèle).

- **Fichier** : `packages/zcrud_session/lib/src/presentation/z_list_session_view.dart` (NEUF)
- **Test porteur** : `test/presentation/z_list_session_view_test.dart` — monte 3 cartes, vérifie
  **3 `ZFlashcardAnswerInput`** (`find.byType`), et un **grep de source** interdisant
  `ListView(` non-`.builder` dans le fichier.
- **Injection R3** : remplacer `ListView.builder` par `ListView(children: …)` → le grep de source
  rougit **sans casser la compilation**.

### AC2 — 🔴 La correction n'apparaît QU'À la soumission finale (jamais carte par carte)

**Given** un examen en cours
**When** l'apprenant répond à une question
**Then** **aucune correction** n'est affichée : ni ✓/✗ de vérité sur les choix, ni
`_CorrectionSection`, ni `statusText` correct/incorrect **And** la saisie reste **verrouillée**
après soumission (une réponse par carte — le verrou de su-3 est **préservé**, cf. G4)
**And** à la **soumission finale**, la correction de **chaque** question devient visible.

- **Fichiers** : `z_flashcard_answer_input.dart` (**UPDATE**, ajout du gate D2) +
  `z_list_session_view.dart` (NEUF)
- **Tests porteurs** (`z_list_session_view_correction_test.dart`) :
  1. `deferred` + réponse → `find.text('correct')`/`'incorrect'` **absents**, aucune icône
     `Icons.check_circle`/`Icons.cancel`.
  2. 🔴 **Le verrou survit au report** : en `deferred`, après soumission, **re-taper un autre
     choix** → `onSubmitted` a été appelé **exactement 1 fois** (et non 2). *C'est l'AC qui
     démasque le sous-piège de G4 — sans elle, « différer » rouvre la double soumission.*
  3. Après soumission finale → corrections **visibles** pour **toutes** les cartes.
  4. **Non-régression su-3** : en `immediate` (défaut), la correction apparaît **toujours**
     immédiatement (les tests existants de su-3 doivent rester **verts sans être touchés**).
- **Injection R3** : forcer `showCorrection: corrected != null` (ignorer la visibilité) → les
  tests 1 et 3 rougissent, la compilation tient. ⚠️ **Injection interdite** : supprimer le
  paramètre (casse la compilation → ne prouve rien).

### AC3 — 🔴🔴 ZÉRO écriture SRS, **garanti par le type** — l'AC centrale

**Given** un examen blanc complet
**When** il est soumis
**Then** **aucune écriture SRS** n'a lieu — **garanti structurellement**, pas par une assertion
comportementale seule.

**Preuve à TROIS étages, aucun ne suffisant seul** :

**(a) STRUCTURELLE — la vue n'a aucun seam d'écriture** (`z_list_session_view_no_srs_test.dart`,
sur le modèle **existant** de `z_white_exam_no_srs_test.dart:47` et de la discipline de
`z_no_srs_write_in_non_srs_modes_test.dart:110`) :
- scan du **constructeur** de `ZListSessionView` : ne contient **ni `reviewer`, ni `scheduler`,
  ni `store`** (assertion **insensible à la casse**, comme `:144`) ;
- scan du **corps** du fichier : aucun `ZSessionReviewer`, `.reviewCard(`, `ZSrsScheduler`,
  `ZSm2Scheduler`, `.apply(`, `ZRepetitionStore` ;
- ⚠️ le test **DOIT** asserter `source.existsSync()` **et** `lines.isNotEmpty` (`:48`, `:53`) —
  sans quoi un fichier renommé rendrait le scan **vide et vert** (preuve d'absence **fausse**).

**(b) COMPORTEMENTALE AVEC TÉMOIN POSITIF** (`z_list_session_view_no_srs_test.dart`) — 🔴 **la
leçon su-4 : l'espion `expect(spy.calls, isEmpty)` n'était JAMAIS branché ⇒ infalsifiable.**
L'ordre des assertions est **imposé** :

1. **TÉMOIN POSITIF D'ABORD — prouver que l'espion CAPTE** : un `_SpyReviewer`
   (`ZSessionReviewer` = **typedef de fonction**, `z_session_reviewer.dart:25`) est branché sur
   `ZStudySessionEngine(mode: spaced, reviewer: spy)` ; une session est pilotée jusqu'à une
   review ; **`expect(spy.calls, hasLength(1))`**. ✅ *Sans ce `1`, le `0` qui suit ne vaut rien.*
2. **PUIS L'ABSENCE D'APPEL SUPPLÉMENTAIRE** : le **même** `_SpyReviewer` est en portée ; un examen
   **complet** est joué de bout en bout via `ZListSessionView`.
   ⚠️ **ÉCART ASSUMÉ vs le croquis initial de cette AC** (qui disait `expect(spy.calls, isEmpty)`) :
   l'implémentation assère **`hasLength(1)`**, et c'est **STRICTEMENT PLUS FORT**. Le témoin de
   l'étape 1 est **rejoué dans la portée du test (2)** ⇒ l'espion vaut déjà `1` **avant** l'examen ;
   le `1` final se lit « **le SEUL appel est celui du témoin — l'examen n'en a ajouté AUCUN** », et
   toute écriture SRS de l'examen ferait **`2`**. Exiger `isEmpty` imposerait un espion **vierge**,
   donc **non prouvé captant dans cette portée** — précisément le défaut su-4 que cette AC existe
   pour tuer. 🚫 **Ne pas « réaligner » le code sur `isEmpty`.**
3. 🔴 **Honnêteté du test — à écrire dans le dartdoc du fichier** : ce compte n'est **pas** un
   « espion branché qui n'a pas été appelé » — l'espion est **inatteignable par construction**
   (aucun paramètre où le passer). Le test documente donc que **(b) mesure le chemin réel de
   bout en bout, et (a) porte la garantie**. ⚠️ **Ne PAS intituler ce test « reviewCard jamais
   atteint »** : `z_no_srs_write_in_non_srs_modes_test.dart:187` a déjà corrigé exactement ce
   mensonge d'intitulé. **La prose ment → l'intitulé doit dire ce que le test mesure vraiment.**

**(c) AUTOMATIQUE** : `z_widgets_purity_test.dart` capte `z_list_session_view.dart` **sans
édition** (G6). **Aucune garde parallèle.**

- **Injection R3** : ajouter dans la vue un appel `reviewer(...)`/`ZSrsScheduler.apply(...)` →
  (a) et (c) rougissent. *(Le témoin positif de (b) rougit, lui, si l'espion cesse de capter —
  c'est sa raison d'être.)*

### AC4 — Le résultat agrégé provient du MOTEUR, sans recalcul parallèle

**Given** un examen soumis
**When** l'écran de fin s'affiche
**Then** l'agrégat `{total, correct, byQuality}` provient de **`engine.result`** (produit par
`scoreWhiteExam`, `:228`) **And** **aucun** recomptage n'est fait dans la présentation
**And** le détail par question (`isCorrect`/`feedback`) vient des `ZFlashcardSubmission`
**mémorisées** (su-3) — ce n'est **pas** un recalcul de l'agrégat, mais un canal **distinct**
(AD-4) **And** l'écran de fin est **`ZSessionSummaryView`** (su-5), jamais un écran réécrit.

- **Test porteur** : `z_list_session_view_result_test.dart` — un `scorer` **sentinelle** injecté
  (`ZExamScoringPort` retournant `total: 999, correct: 42`) ⇒ l'UI affiche **999/42**. *Si l'UI
  recomptait, elle afficherait les vrais chiffres et le test rougirait.* + grep de source : la
  vue ne contient **ni** `+= 1` **ni** `passThreshold` (elle ne juge pas le correct/incorrect).
- **Injection R3** : recompter `correct` dans la vue au lieu de lire `engine.result` → la
  sentinelle rougit **par le comportement**.

### AC5 — Rien n'est jamais persisté ; l'abandon n'écrit RIEN (frontière DÉCLARÉE)

**Given** un examen en cours
**When** l'apprenant **abandonne** (retour, démontage) **ou** que l'app est **tuée**
**Then** **rien n'est persisté** — ni SRS, ni brouillon, ni réponse **And** l'examen est
**perdu** : au retour, un examen **neuf** repart en phase `setup` **And** **aucune exception**
n'est levée au démontage (AD-10).

**Régime DÉCLARÉ (AD-43)** — décision **D5**, à recopier en dartdoc de la classe :
> `ZListSessionView` n'est **pas une surface d'édition** : AD-43 (« brouillon » vs « direct »)
> **ne la gouverne pas**, car elle **ne persiste RIEN, jamais, par aucun chemin**. Son état vit en
> mémoire pour la durée du montage. **Il n'y a pas de brouillon** (aucune reprise après abandon) —
> et c'est un **choix explicite**, pas un oubli : un examen repris est un examen faussé (conditions
> d'examen). *Aucune écriture SRS à l'abandon : il n'existe aucun chemin d'écriture (AC3).*

- **Test porteur** : `z_list_session_view_lifecycle_test.dart` — répondre à 2/3 cartes → démonter
  (`pumpWidget(SizedBox())`) → **aucune exception** (`tester.takeException()` **`isNull`**) ;
  remonter → phase `setup`, `answered == 0`. + **démontage pendant une animation** (démonter à
  mi-`pump` d'une transition) → `takeException()` **`isNull`**.
- **Injection R3** : retirer le `dispose()` du contrôleur d'examen → fuite/`setState after
  dispose` → rougit au comportement.

### AC6 — Robustesse AD-10 : jamais de throw sur les chemins hostiles

**Given** chacun des cas ci-dessous
**When** il survient
**Then** l'UI **ne lève aucune exception** et dégrade proprement.

| Cas hostile | Comportement EXIGÉ |
|---|---|
| Examen **vide** (`queue: []`) | état vide **l10n**, action « soumettre » **ABSENTE** (jamais grisée) ; ⚠️ `submit()` sur file vide serait **légal** côté moteur et produirait `total: 0` — l'UI **ne le propose pas** |
| **1 seule** question | l'unique carte est la **dernière** : l'affordance de soumission est offerte immédiatement après sa réponse ; aucun `RangeError` |
| **Abandon** en cours | AC5 — rien écrit, aucune exception |
| File qui **rétrécit** | 🔴 **patron su-4** : `key` dérivée de l'**identité de la file** (D8) — c'est ce qui a évité le `RangeError` en su-4 |
| Réponses **partielles** | soumission possible ; les cartes non répondues **ne sont pas** comptées comme fausses (elles ne sont **pas** dans `answers` ⇒ `total` = **répondues**, cf. `:207`) — l'UI **dit** combien restent sans réponse, elle **n'invente** aucune qualité |
| `byQuality` **corrompu** (clé non-numérique, compte négatif) | la lecture **ignore** l'entrée illisible, aucun throw (`ZSessionSummaryView:121` lit déjà `byQuality['$quality'] ?? 0` — ⚠️ **`grep -qF`** obligatoire pour ce symbole `$`) |
| Qualité **hors échelle** (`-3`, `99`) | **`config.clampQuality`** — **voie UNIQUE** (AD-46). **JAMAIS** un clamp réécrit, **jamais** une échelle redéclarée |
| **Double soumission** finale | l'affordance est **gatée par la phase** (`submitted` ⇒ absente) ⇒ `submit()` n'est **jamais** appelé deux fois ⇒ le `StateError` du moteur (G3) **n'est jamais provoqué**. 🚫 **Aucun `try-catch`** autour de `submit()` |
| **Démontage pendant une animation** | AC5 — `takeException()` `isNull` |

- **Test porteur** : `z_list_session_view_robustness_test.dart` — un `test` par ligne du tableau.
- 🔴 **Leçon su-4 — « présence ≠ association »** : le test de double soumission **DOIT TAPER**
  sur le bouton (`tester.tap`), pas seulement constater son absence via `find`. Un contrôle non
  **ACTIONNÉ** est un contrôle non testé (su-4 : bouton « précédent » qui **avançait**, vert car
  jamais tapé).
- **Injection R3** : gater la soumission sur un `bool _submitted` local au lieu de la phase →
  le test de double soumission rougit (`StateError`) **par le comportement**.

### AC7 — A11y / RTL / l10n / thème (AD-13, FR-26)

**Then** toute cible tactile ≥ **48 dp** **And** chaque contrôle porte un `Semantics` **dont le
label vient de `ZcrudLabels`** (`label(context, key, fallback:)`,
`z_localizations.dart:288`) **And** l'arbre se construit en **RTL** sans exception **And**
**aucune** couleur ni libellé en dur **And** **Reduce Motion** est respecté.

- **Tests porteurs** : **ÉTENDRE** l'énumération AC14 existante
  (`z_session_mode_selector_test.dart:335`) avec les clés de su-7 —
  `zcrud.study.exam.submit`, `zcrud.study.exam.submit.confirm`, `zcrud.study.exam.submit.cancel`,
  `zcrud.study.exam.empty`, `zcrud.study.exam.unanswered`, `zcrud.study.exam.progress`.
  🔴 **Leçon su-6 (à ne PAS reproduire) : l'énumération avait OMIS un DIALOG ENTIER du même diff
  ⇒ 4 tuiles non gardées, 4/4 défectueuses.** Le **dialog de confirmation** de su-7 (D7) **DOIT**
  y figurer. **Balayer tout le diff.**
- 🚫 **NE PAS dupliquer** la garde de contraste WCAG (`:1069`) : elle énumère **tous les
  `RichText`** et couvrira su-7 **automatiquement**.
- 🔴 **Leçon su-6 — un test ne doit pas observer qu'UN canal** : le nombre du streak n'existait
  **que** dans `Semantics(value:)`, invisible à l'œil, et le test était **vert**. Ici : le nombre
  de questions **sans réponse** doit être asserté **à la fois** en **texte visible** (`find.text`)
  **et** en `Semantics` — **jamais** l'un des deux seul.
- **Injection R3** : remplacer un `label(context, …)` par un littéral `'Soumettre'` →
  `z_widgets_hardcode_scan_test.dart` + l'énumération AC14 rougissent, compilation intacte.

### AC8 — SM-1 : granularité des rebuilds (objectif produit n°1)

**Then** taper dans une question ne reconstruit **que** le champ courant : **zéro** rebuild des
autres questions, **zéro** perte de focus, `TextEditingController` **jamais recréé**.

- **Test porteur** : `z_list_session_view_sm1_test.dart` sur le modèle **existant** de
  `z_flashcard_answer_input_sm1_test.dart` — compteur de builds par carte ; 100 caractères dans la
  carte 1 ⇒ builds des cartes 2..N **inchangés** ; `FocusNode.hasFocus` reste `true`.
- **Injection R3** : remonter l'état de saisie dans un `setState` de `ZListSessionView` → le
  compteur des autres cartes explose → rougit au comportement.

### AC9 — 🔴 Correspondance carte ↔ réponse : la Nᵉ qualité atterrit sur la Nᵉ carte

**Given** un examen dont les cartes ont des réponses **distinctes et identifiables**
**When** l'apprenant répond aux questions **dans un ordre quelconque** (y compris en sautant des
questions, puis en revenant)
**Then** chaque qualité est enregistrée sur **SA** carte — jamais décalée d'un cran
**And** l'ordre de `cards` (vue) et celui de la file du moteur sont **le même**, dérivés d'une
**source unique** (l'hôte construit `items` **et** `cards` du **même** parcours, dans le **même**
ordre — jamais deux tris indépendants).

> ### 🔴 ARBITRAGE DE REVUE (code-review su-7) — portée RÉELLE d'AC9, et ce qui reste OUVERT
>
> La clause *Then* est **satisfaite sur le canal que su-7 possède**, et **littéralement fausse sur
> un canal que su-7 ne possède pas**. Le distinguo est **mesuré**, pas théorique :
>
> | Canal | AC9 tenue ? | Porté par |
> |---|---|---|
> | vue → hôte (`onAnswered(index, …)` + `Map` indexée par position) | ✅ **OUI** | `z_list_session_view_mapping_test.dart` (axe « la correction de CHAQUE carte est peinte SUR SA carte ») |
> | hôte → **moteur** (`engine.answer(quality)`) | ❌ **NON — INSATISFIABLE** | `z_white_exam_scoring_contract_test.dart` (limite **FIGÉE**) |
>
> **Pourquoi c'est insatisfiable** : `ZWhiteExamSessionEngine.answer(int quality)` est
> **positionnel** — il enregistre pour `queue[cursor]` et avance d'un cran. Sa signature **ne porte
> pas d'index** : aucun hôte ne peut dire « cette qualité appartient à la carte #2 ». Or cette AC
> **exige** l'ordre libre et le saut, que la vue offre bien. Sonde : Q3 juste, Q1 faux, Q2 sautée ⇒
> `answers == [5, 0]` contre `queue == [Q1,Q2,Q3]` ⇒ **les 3 attributions fausses, zéro exception**.
>
> **Impact AUJOURD'HUI : nul pour l'apprenant** — `scoreWhiteExam` est **commutatif** (l'agrégat
> reste juste) et l'affichage lit la `Map`, jamais `answers`. **Mais atteignable** :
> `ZExamScoringPort` est un **seam PUBLIC** ⇒ un scorer **positionnel** noterait la mauvaise
> question (**note fausse**).
>
> **Disposition retenue** (voie *c* — cf. `code-review-su-7.md`) : **documenter honnêtement +
> garder le seam**. `answers` est déclaré **positionnel-par-arrivée / multi-ensemble**, la
> **commutativité** devient une **précondition testée** de `ZExamScoringPort`, et la limite est
> **assérée** pour qu'une future story la fasse rougir en la levant. Les deux autres voies sont
> **écartées et pourquoi** : (a) `answer({index, quality})` = **changement de contrat du DOMAINE**,
> que **D10 met hors périmètre** ; (b) contraindre l'ordre dans la vue = **contredit AC9/AC6 tels
> qu'écrits** ⇒ amender une AC est une **décision OWNER**, pas un correctif de revue.
>
> 🔴 **RESTE OUVERT — décision owner requise** : soit **amender AC9** (« la correspondance est
> garantie sur le canal d'affichage ; `engine.answers` est un agrégat commutatif »), soit ouvrir la
> **story dédiée** `answer({index, quality})`. **Bloquant pour su-10**, qui rendra « question
> courante » et lira `engine.current` — lequel pointe la **mauvaise carte** sous saisie libre.

- **Test porteur** : `z_list_session_view_mapping_test.dart` — 3 cartes dont **une seule** est
  répondue correctement (qualité 5), les deux autres à 0. Un `scorer` sentinelle **capture la liste
  `qualities` reçue** ⇒ `expect(captured, [0, 5, 0])` (et **non** `[5, 0, 0]` ni `[0, 0, 5]`).
  *C'est l'assertion qui démasque un décalage d'un cran — un test qui ne vérifierait que le
  **nombre** de réponses resterait **vert** sur un examen entièrement faux.*
- 🔴 **Un test « 3 réponses enregistrées » ne prouve RIEN** sur la correspondance : c'est
  exactement le motif « présence ≠ association » (su-4). L'assertion **doit porter sur le contenu
  ordonné**, pas sur la longueur.
- **Injection R3** : dans l'hôte, inverser `cards` **sans** inverser `items` (ou enregistrer la
  qualité à `cursor + 1`) → `captured` devient `[5, 0, 0]` → rougit **par le comportement**,
  compilation intacte.
- **Conséquence de conception** : ⚠️ le moteur est **strictement linéaire** (`recordAnswer` `:198`
  avance le curseur d'un cran, **aucune ré-insertion, aucune révision**). Si l'UI autorisait de
  **revenir modifier** une réponse, `engine.answer()` enregistrerait une **réponse
  supplémentaire** au lieu de corriger la précédente ⇒ `total` **faux**. **Décision D10.**

---

## Décisions tranchées (mode NON-INTERACTIF → option la plus CONSERVATRICE, consignée)

### D1 — Emplacement et forme
`ZListSessionView` (`StatefulWidget`) → `packages/zcrud_session/lib/src/presentation/z_list_session_view.dart`,
exporté au barrel. **Justification** : `zcrud_session` porte déjà le moteur (`:40`) et toute la
présentation de session. Aucun paquet neuf (le patron `zcrud_export_ui` d'AD-8 ne s'applique pas :
**aucune dépendance lourde** ici).

### D2 — 🔴 Différer la correction = un **enum de VISIBILITÉ** sur su-3 (jamais une saisie parallèle)

```dart
/// Régime d'apparition de la correction dans `ZFlashcardAnswerInput`.
/// **enum > booléen** : un `bool deferCorrection` ne dirait pas *quand* elle apparaît.
enum ZCorrectionVisibility {
  /// Défaut — révision/apprentissage : la correction apparaît dès la soumission de la carte.
  immediate,
  /// Examen blanc (FR-SU13) : la carte NE REND JAMAIS la correction ; l'hôte la révèle en fin d'examen.
  deferred,
}
```

- Ajouté à `ZFlashcardAnswerInput` : `this.correctionVisibility = ZCorrectionVisibility.immediate`
  ⇒ **su-3 inchangé par défaut** (aucune régression ; ses tests restent verts **sans édition** —
  AC2.4).
- 🔴 **Le gate porte sur le RENDU SEUL** — `_correction.value` **reste posé** par `_emit` (`:454`) :
  - `showCorrection:` (`:910`) devient `corrected != null && widget.correctionVisibility == ZCorrectionVisibility.immediate` ;
  - `_CorrectionSection` (`:719`) et le `statusText` (`:984`) suivent le **même** gate ;
  - 🚫 **`onTap: corrected != null ? null : …` (`:912`) NE CHANGE PAS** — le **verrou
    d'interaction** et `_submitLocked` (`:288`) restent **intacts** (cf. G4). *C'est exactement ce
    que l'AC2.2 vérifie.*
- **Alternative REJETÉE** : reconstruire une saisie d'examen ⇒ duplication de l'évaluation locale
  QCM/VF, des indices (AD-36) et du minuteur — la ligne du sprint-status dit **« réutilise su-3 »**.

### D3 — 🔴 La vue ne connaît PAS le moteur : le moteur est piloté par l'HÔTE (contrainte G6)

`z_widgets_purity_test.dart` **interdit** à tout widget de `lib/src/presentation/**` d'importer
`z_white_exam_session_engine`. **`ZListSessionView` ne construit ni ne détient donc AUCUN moteur.**
Elle est **pure** et reçoit **en données** :

🔴 **Écart de type DÉMASQUÉ SUR DISQUE (à ne pas découvrir en cours de dev)** :

```bash
grep -n "final " packages/zcrud_session/lib/src/domain/z_session_item.dart
#  :25  final String flashcardId;   :28  final String folderId;   :32  final String? typeKey;
```

**`ZSessionItem` ne porte AUCUN `ZFlashcard`** — que des **identifiants**. Or
`ZFlashcardAnswerInput` exige `card: ZFlashcard` (`:123`). ⇒ **La file du moteur
(`List<ZSessionItem>`) n'est PAS rendable telle quelle.** La vue prend donc `List<ZFlashcard>`, et
l'hôte détient **deux listes parallèles** (`items` pour le moteur, `cards` pour la vue).

⚠️ **Ce parallélisme est le risque n°1 de su-7** : si les deux listes se désynchronisent (ordre ou
longueur), la qualité de la carte **A** est enregistrée sur la carte **B** — un examen **faux**, par
la voie **légitime**, **sans aucune exception**. C'est la **même classe de défaut** que le jeton de
fraîcheur `_generation` de su-3 (`:280`) a dû fermer. **Mitigation IMPOSÉE (AC9)**.

```dart
const ZListSessionView({
  required this.cards,            // List<ZFlashcard> — file DÉJÀ sélectionnée (AD-33 : aucun re-filtrage ici)
  required this.phase,            // ZWhiteExamPhase — l'UNIQUE gate des affordances (G3/AC6)
  required this.onAnswered,       // ValueChanged<ZFlashcardSubmission> — l'hôte fait engine.answer(sub.quality)
  required this.onSubmit,         // VoidCallback — l'hôte fait engine.submit()
  this.result,                    // ZStudySessionResult? — engine.result, JAMAIS recalculé (AC4)
  this.submissions = const [],    // corrections mémorisées, révélées en phase submitted
  …
});
// 🚫 AUCUN paramètre `reviewer`/`scheduler`/`store` — c'est l'AC3(a), et c'est structurel.
```

**Ce que cela achète** : la vue **ne peut pas** provoquer le `StateError` du moteur (G3), **ne peut
pas** écrire le SRS (aucun seam), et reste testable **sans** moteur. **La qualité transite vers le
moteur immédiatement** (`onAnswered` → `engine.answer(q)`) — **sans danger, le moteur n'écrit aucun
SRS (G2)** — tandis que **seul l'AFFICHAGE** de la correction est différé (D2). ⇒ **Le report est
un fait de PRÉSENTATION, jamais un second circuit de données** : aucune duplication de su-3.

### D4 — Deux canaux, jamais deux calculs (AD-4)
**Agrégat** `{total, correct, byQuality}` ⇐ **`engine.result`** (`scoreWhiteExam`, **producteur
unique**). **Détail par question** (`isCorrect`/`feedback`) ⇐ les `ZFlashcardSubmission` mémorisées.
🚫 La vue **ne recompte jamais** `correct` (AC4 le prouve par une **sentinelle**).

### D5 — Aucune persistance, aucun brouillon (frontière **déclarée**, AD-43) — cf. AC5.

### D6 — 🔴 su-6 : les filtres **NE SONT PAS CÂBLÉS** ici. **Tranché : NON — et c'est structurel**

**AD-33 est explicite** : « une session se construit **sur une file déjà sélectionnée**
(`List<ZSessionItem>`), produite **en amont** par `ZStudySessionConfig` → `ZStudySessionSelector`.
**Aucun moteur ne sélectionne.** » `zApplyTestFilters` et `zShuffleChoices` relèvent de la
**sélection AMONT** ; `ZListSessionView` est **AVAL**. Les y câbler ferait de la vue un **second
sélecteur** — exactement ce qu'AD-33 *prevents*. Le **parcours assemblé est su-10**, et la ligne
du sprint-status de su-8/su-10 le confirme. ⇒ **su-7 consomme une file déjà filtrée et déjà
mélangée.** *(Que su-6 soit « livré non câblé » n'est donc pas une dette de su-7 : c'en est le
contrat d'entrée.)*

### D7 — Soumission finale : **dialog de confirmation** (option conservatrice)
Un examen soumis est **irréversible** (`submitted` n'a **aucune** transition sortante, `:74`) ⇒
confirmation explicite, **mentionnant le nombre de questions sans réponse**.
🔴 **Ce dialog est dans le diff : il DOIT figurer dans l'énumération a11y AC14** (leçon su-6 : un
dialog entier avait été omis).

### D8 — `key` dérivée de l'identité de la file (patron **su-4**, `_queueGeneration`)
Protège du `RangeError` quand la file rétrécit (AC6). Patron **emprunté**, pas réécrit.

### D9 — enums > booléens
`ZCorrectionVisibility` (D2) ; la phase est un `ZWhiteExamPhase` **existant**, jamais un
`bool isSubmitted` local.

### D10 — 🔴 **Une réponse par carte, DÉFINITIVE** (imposé par le moteur, pas par goût)

`recordAnswer` (`:198`) **ajoute** une réponse et avance le curseur : le moteur **ne sait pas
réviser**. ⇒ **su-7 n'offre AUCUNE révision de réponse** : une carte répondue est **verrouillée**
(ce que le verrou de su-3 fait **déjà**, `:912` — cf. D2, qu'on préserve **exactement** pour cette
raison). L'apprenant peut **sauter** une question (elle reste sans réponse, AC6) mais **jamais
changer** une réponse donnée.

**Alternative REJETÉE** — une liste de travail (« brouillon ») en mémoire autorisant la révision,
rejouée dans le moteur au moment du `submit()` :
- ✅ *pour* : révision libre, plus proche d'un vrai examen ;
- ❌ *contre* : le moteur deviendrait un **simple additionneur** appelé en fin de course, sa machine
  à états (`setup`/`running`/`submitted`, sa progression, son curseur) **court-circuitée** ; su-7
  détiendrait alors un **second circuit de données** parallèle à su-3 — précisément ce que la ligne
  du sprint-status (« réutilise su-3 ») et AD-34 (« aucun runtime dupliqué ») interdisent.
- ⇒ **Option la plus conservatrice retenue** : consommer le moteur **tel qu'il est**. Une révision
  de réponse serait un **changement de contrat du DOMAINE** (`ZWhiteExamSessionEngine`) — **hors
  périmètre de su-7**, et à porter par une story dédiée si le besoin est confirmé.
- 📌 **Question pour l'owner** (consignée, **non bloquante** — le défaut conservateur s'applique) :
  un examen blanc sans révision de réponse est-il acceptable en conditions réelles ? Si non, la
  story qui l'ouvrira devra modifier le **moteur**, pas la vue.

---

## Tasks / Subtasks

- [x] **T1 — Rejouer les greps G1/G4 sur disque** (AC1, AC2). Si un RC diffère → **STOP**, signaler.
- [x] **T2 — `ZCorrectionVisibility` + gate de RENDU dans `ZFlashcardAnswerInput`** (AC2, D2)
  - [x] enum + dartdoc ; paramètre `correctionVisibility` (défaut `immediate`)
  - [x] gate sur `showCorrection` (`:910`), `_CorrectionSection` (`:719`), `statusText` (`:984`)
  - [x] 🚫 **NE PAS toucher** `onTap: corrected != null ? null : …` (`:912`) ni `_submitLocked`
  - [x] export au barrel
- [x] **T3 — `ZListSessionView`** (AC1, AC6, D1/D3/D8) : `ListView.builder`, affordances **gatées
      par la phase**, `key` dérivée de la file, état vide, `ZSessionProgressIndicator` réutilisé
- [x] **T4 — Révélation de fin + agrégat** (AC4, D4) : `ZSessionSummaryView` (su-5) sur
      `engine.result` ; corrections par question depuis les `submissions` ; **zéro recomptage**
- [x] **T5 — Dialog de confirmation de soumission** (D7, AC6) + son entrée dans l'énumération AC14
- [x] **T6 — Tests AC3 (a)+(b)** : scan structurel (+ `existsSync`/`isNotEmpty`) ; espion **témoin
      positif d'abord** (`hasLength(1)`) **puis assertion finale à `hasLength(1)`** — **PAS**
      `isEmpty` : le témoin est **rejoué dans la portée du test (2)**, donc l'espion vaut déjà `1`
      avant l'examen ; le `1` final se lit « le SEUL appel est celui du témoin ⇒ l'examen n'en a
      ajouté AUCUN » (toute écriture ferait `2`). **Écart DÉLIBÉRÉ vs le croquis d'AC3(b)-2 : il
      RENFORCE l'AC** — un `isEmpty` exigerait un espion **vierge**, c.-à-d. **non prouvé captant
      dans cette portée** (le défaut su-4). Dartdoc d'honnêteté ; **intitulé qui ne ment pas**
- [x] **T7 — Tests AC1/AC2/AC4/AC5/AC6/AC8** ; **taper** réellement sur les contrôles
- [x] **T7bis — Test AC9 (correspondance carte ↔ réponse)** : sentinelle capturant `qualities`,
      assertion sur le **contenu ordonné** (`[0, 5, 0]`), jamais sur la longueur ; une carte
      répondue est **verrouillée** (D10)
- [x] **T8 — ÉTENDRE** l'énumération a11y AC14 (`z_session_mode_selector_test.dart:335`) —
      **dialog inclus** ; 🚫 **ne dupliquer NI** la garde de contraste **NI** les gardes de pureté
- [x] **T9 — Vérif verte DEPUIS LE PACKAGE** :
      `cd packages/zcrud_session && flutter test` (🚫 jamais depuis la racine : **26 faux
      échecs** ; 🚫 jamais `melos run test` : se bloque) ; puis `zcrud_flashcard`.
      Référence : **zcrud_session 464**, `zcrud_flashcard` 464 — su-7 **ajoute**, ne retranche pas.
- [x] **T10 — R3** : rejouer **chaque** injection ; vérifier qu'elle rougit **par le
      COMPORTEMENT** (une injection qui casse la compilation ne prouve **RIEN**)

---

## Dev Notes

### Fichiers UPDATE — état actuel LU, à préserver
- **`z_flashcard_answer_input.dart` (1515 l.)** — *aujourd'hui* : correction immédiate via
  `_correction` (`:255`, posé en `:454`) ; **trois** chemins de soumission (rédigée / QCM-VF
  auto-soumis / « Je ne sais pas »), tous couverts par `_submitLocked` (`:288`) et le jeton de
  fraîcheur `_generation` (`:280` — ⚠️ `mounted` **ne suffit pas** : l'`Element`/`State` survit au
  changement de carte). *Ce que su-7 change* : **le RENDU** de la correction, rien d'autre. *Ce
  qui doit être préservé* : les **deux** verrous, le jeton de fraîcheur, l'émission **advisory**
  (`onSubmitted` ≠ noter), la parité des canaux a11y (`:965` : ✓/✗ = la vérité, plein/contour = le
  choix de l'utilisateur — **deux informations, deux axes de FORME**, aucune couleur).
- **`z_session_mode_selector_test.dart`** — *aujourd'hui* : énumération AC14 (11 clés) + garde de
  contraste WCAG (`:1069`). *Ce que su-7 change* : **ajoute** des clés. *Préserver* : les 11 clés
  et la garde de contraste **intactes**.

### Anti-patrons — défauts RÉELS démasqués sur su-1..su-6, à ne pas reproduire
1. **Espion jamais branché** (su-4) ⇒ `expect(spy.calls, isEmpty)` **infalsifiable** → AC3(b) : le
   **témoin positif à 1 appel VIENT D'ABORD**.
2. **Présence ≠ association** (su-4 : bouton « précédent » qui **avançait**, vert car jamais tapé)
   → **TAPER** sur chaque contrôle.
3. **Un défaut est un MOTIF** (su-5 : 1 tuile corrigée sur 4 ; su-6 : un **dialog entier** omis) →
   **balayer tout le diff**.
4. **Un seul canal observé** (su-6 : le streak n'existait que dans `Semantics(value:)`) →
   asserter **visible ET sémantique**.
5. **Gardes qui ne voient pas / se contredisent** (su-5 : dé-commentateur **Dart** sur du **YAML**)
   → **étendre** les gardes existantes, **jamais** en créer de parallèles.
6. **La prose ment** (`clampQuality` « unique propriétaire » **sans appelant** ; « non commutatif »
   alors qu'il l'est ; « jamais `Colors.*` » au-dessus d'un `Colors.red`) → **toute affirmation de
   dartdoc doit être VRAIE sur disque**, y compris les intitulés de tests.
7. 🚫 **On ne modifie JAMAIS un test pour taire un défaut réel.**

### Outillage — pièges AVÉRÉS (une preuve d'absence obtenue ainsi est **FAUSSE**)
- `grep … | head; echo $?` rend le RC de **`head`** ⇒ **`grep -q` SANS pipe**.
- **`$` est un métacaractère BRE** ⇒ `grep -q '_$Foo'` dit « absent » alors que le symbole
  **existe** ⇒ **`grep -qF`** pour tout symbole `$`/codegen (ex. `byQuality['$quality']`).
- Gardes en `Directory('lib')` **relatif** ⇒ `flutter test` **depuis le package**.
- 🚫 **Jamais `git checkout`** (su-1..su-6 **non committés** — un checkout les **détruit** ; c'est
  déjà arrivé). 🚫 **Jamais `dart format`**. 🚫 **Jamais `melos run test`**.

### Contraintes héritées (AD-1..32) applicables
AD-1 (acyclique : `zcrud_session` → `zcrud_flashcard`/`zcrud_study_kernel`, **jamais** l'inverse) ·
AD-2/AD-15 (`ChangeNotifier`/`ValueListenable`, **aucun** gestionnaire d'état) · AD-10 (défensif,
**jamais** de throw en UI) · AD-13 (48 dp, `Semantics`, **directionnel** : `EdgeInsetsDirectional`,
`AlignmentDirectional`, `TextAlign.start/end`) · AD-29/AD-32 · FR-26 (thème injecté, **zéro**
couleur en dur) · `ListView.builder` **obligatoire**.

### Project Structure Notes
`z_list_session_view.dart` sous `lib/src/presentation/` — **capté automatiquement** par les gardes
auto-énumérantes (G6). Tests sous `test/presentation/`. **Aucun** paquet neuf, **aucune** dépendance
neuve. **Frontières** : 🚫 pas de liste de flashcards (**su-8**), 🚫 pas de génération IA (**su-9**),
🚫 pas de parcours `example/` (**su-10**), 🚫 pas de multi-édition (**epic ME**).

### References
- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.7` (`:397-418`)]
- [Source: `.../architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-33` (`:51`), `#AD-34` (`:59`), `#AD-35` (`:80`), `#AD-36` (`:91`), `#AD-43` (`:188`), `#AD-46` (`:225`)]
- [Source: `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart` — ctor `:249`, `scoreWhiteExam` `:215`/`:228`, `ZExamScoringPort` `:184`, `StateError` `:303`/`:318`/`:335`]
- [Source: `packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart` — ctor `:103`, `_emit` `:454`, `_submitLocked` `:288`, `_generation` `:280`, `showCorrection` `:910`, `onTap` `:912`]
- [Source: `packages/zcrud_session/test/z_white_exam_no_srs_test.dart:47` ; `test/z_no_srs_write_in_non_srs_modes_test.dart:110`/`:144`/`:187`]
- [Source: `packages/zcrud_session/test/presentation/z_widgets_purity_test.dart` ; `z_session_mode_selector_test.dart:306`/`:335`/`:1069`]
- [Source: `CLAUDE.md` — invariants, Key Don'ts, vérif verte]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M) — skill `bmad-dev-story`.

### Debug Log References

**Vérif verte RÉELLE** (jouée depuis les packages, jamais `melos run test`) :

| Commande | RC / résultat |
|---|---|
| `dart run melos run analyze` (repo-wide) | **RC=0** (0 `error`/`warning` ; seuls des `info` de `deprecated_member_use` préexistants) |
| `dart run melos run verify` (10 gates) | **RC=0** |
| `cd packages/zcrud_session && flutter test` | **506/506** (référence su-6 : 464 ⇒ **+42**) |
| `cd packages/zcrud_flashcard && flutter test` | **464/464** (inchangé) |

**T1 — greps G1/G4 rejoués** : tous les RC de la story tiennent (`ZListSessionView`/`ZListSession`/
`ZExamView`/`ZWhiteExamView`/`ZExamSessionView`/`ZListSessionScreen`/`ZExamDraft` → **RC=1** ;
`correctionVisibility` → **RC=1** ; `showCorrection|revealCorrection` au barrel → **RC=1**).
Prémisses **intactes** ⇒ aucun signalement de dérive.

**T10 — injections R3 RÉELLEMENT jouées** (chaque rouge **causé par le COMPORTEMENT** : aucun
`Error:`/`Failed to load` ; restauration vérifiée par **SHA-256**) :

| Injection | Rouge ? | Preuve |
|---|---|---|
| AC1 — `ListView.builder` → `ListView(children:)` | ✅ | le **scan de source** rougit ; **les 2 tests widget restent VERTS** ⇒ seule une garde de source peut voir la non-virtualisation |
| AC2 — ignorer `visibility` (`showCorrection: corrected != null`) | ✅ | test (1) rougit : la correction est peinte pendant l'examen |
| AC3 — `ZSrsScheduler` dans la vue | ✅ | (a) **et** (c) `z_widgets_purity_test` rougissent |
| AC6 — soumission gatée par un `bool` local | ✅ | **`StateError` RÉEL** levé par le moteur (exactement la prédiction de la story) |
| AC7 — `label(context, …)` → littéral `'Confirmer'` | ✅ | l'**énumération a11y AC14** rougit. ⚠️ le **scan de libellés ne le voit PAS** — angle mort **DÉJÀ DÉCLARÉ** dans su-6 (« la garde de libellés ne couvre pas `Semantics(label:)` : seul CE test le tient ») ⇒ l'énumération est bien le **seul** filet |
| AC9 — `onAnswered((index + 1) % n, …)` | ✅ | l'axe **DÉCISIF** (rendu par carte) + l'axe index rougissent |

🔬 **Résultat d'injection le plus instructif (AC9)** : sous le décalage d'un cran,
`expect(captured, [0,5,0])` est **RESTÉ VERT**. C'est **conforme à la portée déclarée** dans le
dartdoc du test : `scoreWhiteExam` est un **COMPTAGE commutatif** ⇒ l'agrégat est **insensible à
l'ordre** et **ne peut pas** voir une attribution croisée. Seul l'axe **rendu par carte** l'a
attrapée. La prose du test disait vrai **avant** la mesure, et la mesure l'a confirmée.

### Completion Notes List

**Statut par AC** — AC1 ✅ · AC2 ✅ · AC3 ✅ · AC4 ✅ · AC5 ✅ · AC6 ✅ · AC7 ✅ · AC8 ✅ · AC9 ✅.

#### 🔴 Deux DÉFAUTS RÉELS trouvés **dans mon propre diff** par l'énumération a11y étendue (T8)

Le motif su-6 s'est **rejoué à l'identique** — et la garde étendue l'a attrapé :

1. **Le dialog de confirmation ignorait `ZcrudScope(labels:)`** — il rendait `'Confirmer'` au lieu
   du libellé injecté. **Cause** : `showDialog` monte son contenu sur une **nouvelle route**, dont
   le contexte est enraciné au `Navigator`, **AU-DESSUS** du `ZcrudScope` de l'app ⇒
   `label(dialogContext, …)` ne voit **aucun** `ZcrudLabels` et retombe **toujours** sur son
   `fallback` **français**. Une app anglophone aurait affiché « Confirmer »/« Annuler », **en
   silence** — et **aucune garde de libellés en dur n'aurait bronché** (le fallback *est* du
   français légitime côté source). **Correctif** : libellés résolus dans le contexte de la **vue**
   et passés déjà localisés — patron **déjà sanctionné** de `_StatTile` (su-5).
2. **Fusion sémantique** (`'L10N_EXAM_UNANSWERED\n'`) : le `Text` enfant fusionnait avec le
   `Semantics` parent ⇒ le lecteur d'écran **bégayait**. Rejeu exact du **D1 de su-5**.
   **Correctif** : `ExcludeSemantics` — **balayé sur tout le diff** (compte sans réponse, dialog,
   `_ExamButton`), pas seulement sur l'occurrence trouvée (« un défaut est un MOTIF »).

#### 🔴 Prémisse de la story **FAUSSE sur disque** — corrigée (et c'est structurant)

La story affirmait : *« la garde de contraste WCAG énumère tous les `RichText` et couvrira
**automatiquement** tes widgets — NE PAS la dupliquer »*. **C'est faux, et vérifiable** :
`z_session_mode_selector_test.dart` énumère **les ÉCRANS** (map `screens`) et ne balaye les
`RichText` qu'**À L'INTÉRIEUR** de chacun. Son propre commentaire le dit : *« ajouter un écran ici
est le SEUL geste nécessaire »*. **S'en remettre à l'automatisme aurait laissé su-7 entièrement
NON GARDÉ en contraste** — le trou exact de su-6. ⇒ `ZListSessionView` **ajouté à `screens`** (vert
en clair **et** sombre). La consigne « ne pas dupliquer » est respectée : la garde est **étendue**,
jamais copiée.

#### Écarts assumés (option la plus conservatrice, mode non-interactif)

- **`StatelessWidget` plutôt que `StatefulWidget` (D1)** : la vue ne détient **aucun** état — la
  rendre `Stateful` sans état serait une coquille vide. D1 justifie **l'emplacement** (paquet
  `zcrud_session`), qui est respecté à la lettre. **Conséquence honnête** : l'injection R3 d'AC5
  (« retirer le `dispose()` du contrôleur d'examen ») **ne s'applique pas à la vue** — il n'y a
  rien à disposer ; elle vise l'**hôte** (qui détient le moteur), ce que teste
  `z_list_session_view_lifecycle_test.dart`. **Consigné dans le dartdoc du test**, jamais tu.
- **`submissions: Map<int, ZFlashcardSubmission>`** (au lieu de la `List` du croquis de D3) et
  **`onAnswered(int index, …)`** (au lieu d'une qualité anonyme) : c'est **la mitigation du risque
  n°1** (AC9). Une soumission **rangée sous SA carte** ne peut pas « glisser » d'un cran ; une
  liste `add()`-ée le peut. Le croquis de D3 se terminait par `…` (extensible) — l'esprit (vue pure,
  aucun seam SRS) est **strictement** respecté, et l'API est **plus sûre**, pas plus permissive.
- **Grep AC4 `passThreshold` non littéral** : `ZSessionProgressIndicator` **exige**
  `passThreshold` à son ctor (AD-46 : le **relayer** est un relais, pas un jugement). Un grep
  littéral rougirait sur du code **conforme** et finirait désactivé. La garde interdit ce qui doit
  l'être : **JUGER** (`>= passThreshold`) et **RECOMPTER** (`+= 1`, `correct++`). Portée déclarée
  dans le test.
- **D6 respecté** : les filtres de su-6 ne sont **PAS** câblés (AD-33 — la sélection est **amont**).
- **D10 respecté** : aucune révision de réponse ; la question de l'owner reste **consignée et non
  bloquante**.

#### Défaut de test corrigé en cours de route (le code avait raison)

Mon premier jet d'AC2(4) assertait `find.text('correct')` sur une carte **Vrai/Faux** et rougissait
sur du **code sain**. Vérification **sur la source** (`_ControlButton`) : le verdict V/F est une
**ICÔNE + un `Semantics(value:)`**, **jamais** un `Text`. ⇒ c'était le **test** qui observait un
canal inexistant. Pire : l'assertion d'**ABSENCE** correspondante (AC2 test 1) était donc vraie
**PAR VACUITÉ** — verte quoi qu'il arrive. Les deux ont été réécrits sur les canaux **réels**
(icône **ET** sémantique). 🚫 **Aucun test n'a été modifié pour taire un défaut** : la conclusion
« le test a tort » est **prouvée par la source**, et consignée dans le dartdoc du test.

#### Preuves d'honnêteté ajoutées (contre-preuves R12)

- **AC3** : témoin positif `hasLength(1)` **AVANT** l'assertion finale — elle-même à
  **`hasLength(1)`** (et non `isEmpty` : le témoin compte déjà pour `1` dans cette portée ; tout
  appel de l'examen ferait `2`) ; dartdoc disant que ce compte **n'est pas** « un espion branché non
  appelé » mais une **inatteignabilité par construction** ;
  aucun test intitulé « `reviewCard` jamais atteint ». Contre-preuve que l'examen a **réellement**
  été joué (`isSubmitted`, `total == 2`) — sinon « zéro écriture » serait vrai **par vacuité**.
- **AC8/SM-1** : les assertions sont des **immobilités** (un compteur mort les passerait toutes) ⇒
  contre-preuve ajoutée que **la sonde SAIT bouger** sur un rebuild réel.
- Tous les scans de source assertent `existsSync()` **et** `isNotEmpty` (**+** une contre-preuve
  qu'ils voient le **vrai** contenu) — sans quoi un fichier renommé rendrait le scan **vide et
  VERT**.

### File List

**Créés**
- `packages/zcrud_session/lib/src/presentation/z_correction_visibility.dart`
- `packages/zcrud_session/lib/src/presentation/z_list_session_view.dart`
- `packages/zcrud_session/test/presentation/z_exam_harness.dart`
- `packages/zcrud_session/test/presentation/z_list_session_view_test.dart`
- `packages/zcrud_session/test/presentation/z_list_session_view_correction_test.dart`
- `packages/zcrud_session/test/presentation/z_list_session_view_no_srs_test.dart`
- `packages/zcrud_session/test/presentation/z_list_session_view_result_test.dart`
- `packages/zcrud_session/test/presentation/z_list_session_view_lifecycle_test.dart`
- `packages/zcrud_session/test/presentation/z_list_session_view_robustness_test.dart`
- `packages/zcrud_session/test/presentation/z_list_session_view_sm1_test.dart`
- `packages/zcrud_session/test/presentation/z_list_session_view_mapping_test.dart`

**Modifiés**
- `packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart` (gate de **RENDU**
  D2 ; 🚫 `onTap`/`_submitLocked`/`_generation` **INTACTS**)
- `packages/zcrud_session/lib/zcrud_session.dart` (exports su-7)
- `packages/zcrud_session/test/presentation/z_session_mode_selector_test.dart` (**ÉTEND**
  l'énumération a11y AC14 — **dialog inclus** — et la map `screens` de la garde de contraste ; les
  11 clés et la garde de contraste **préservées intactes**)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-07-17 | 1.0 | Story créée (`bmad-create-story`) — contrat du moteur, gate de correction et preuve « zéro SRS » vérifiés sur disque |
| 2026-07-17 | 1.1 | `dev-story` — `ZListSessionView` + `ZCorrectionVisibility` ; 9/9 ACs ; 506 tests `zcrud_session` (+42), 464 `zcrud_flashcard` ; analyze/verify RC=0 ; 6 injections R3 jouées et restaurées (SHA-256) ; **2 défauts réels corrigés dans le diff** (dialog aveugle à `ZcrudScope` ; fusion sémantique) ; **prémisse de la story corrigée** (la garde de contraste énumère les ÉCRANS, elle ne couvre RIEN automatiquement) |
