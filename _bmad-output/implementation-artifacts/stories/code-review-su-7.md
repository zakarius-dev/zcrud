# Code-review su-7 — UI d'examen blanc (`ZListSessionView`)

**Story** : `su-7-ui-examen-blanc.md` (9 ACs, 10 décisions) · **Spine** : AD-34 · AD-33 · AD-43 ·
AD-46 · AD-10 · AD-13 · hérités AD-1..32
**Lentilles** : désynchronisation · zéro-SRS · correction différée · a11y/l10n · adversariale ·
tests porteurs (6 rapports)

---

## Verdict

**CHANGES REQUESTED → CORRIGÉ.** Le code de prod de su-7 était **structurellement bon** (vue pure,
gate par la phase réel, zéro `try-catch`, thème et RTL irréprochables) et ses tests **d'un niveau
nettement supérieur à la moyenne**. Les défauts réels se répartissaient en trois familles :

1. **un défaut utilisateur-visible** (D1 — « **-2 questions sans réponse** ») ;
2. **une prose qui affirmait des garanties que le disque contredisait** (D2, D3, D5) — l'anti-patron
   n°6 que la story liste elle-même ;
3. **des angles morts de FIXTURE** : `examCard()` ne produisait que du Vrai/Faux, et **aucun test
   n'empruntait le canal sémantique pour ACTIVER un contrôle** ⇒ 2 gates sur 3 et les 3 boutons
   n'étaient gardés par personne.

**Tous les HIGH/MAJEUR/MEDIUM sont corrigés et prouvés par mutation.** **Un point reste ouvert et
exige une décision OWNER** : l'AC9 sur le canal `hôte → moteur` (cf. D2) — consigné dans la story,
**bloquant pour su-10**.

| Vérification (rejouée réellement) | RC | Résultat |
|---|---|---|
| `dart run melos run analyze` (repo-wide) | **0** | **0 error, 0 warning** (30 `info` préexistants : `deprecated_member_use`) |
| `dart run melos run verify` (10 gates) | **0** | tous verts (`codegen-distribution`, `secrets`, `serialization`, …) |
| `flutter test` — `zcrud_session` (depuis le package) | **0** | **521** (référence **506** → **+15**) |
| `flutter test` — `zcrud_flashcard` | **0** | **464** (inchangé ✅) |
| `flutter test` — `zcrud_study_kernel` | **0** | **361** (inchangé ✅) |

**Total : 4298 → 4313.** Aucune sonde résiduelle (`find -name 'zz_probe*'` ⇒ vide), aucun résidu de
mutation (7 marqueurs re-vérifiés un à un), **aucun `git checkout`**, sprint-status **non touché**.

---

## Findings — disposition

### 🔴 D1 — HIGH — « **-2 questions sans réponse** » affiché à l'apprenant — **CORRIGÉ**

**`z_list_session_view.dart:219`** — `_unanswered => cards.length - submissions.keys.length`
comptait les clés **sans vérifier qu'elles sont dans `[0, cards.length)`**, alors que la `Map` est
indexée par **POSITION** (sa dartdoc prétendait « par carte »).

**Scénario d'échec** : 3 cartes répondues → file rétrécie à 1 carte vierge (le chemin **qu'AC6
exige**) ⇒ `1 - 3 = -2` ⇒ **« -2 »** affiché, `Semantics(value:'-2')` annoncé, et **répété dans le
dialog de confirmation** — au moment le plus irréversible du parcours, **sans aucune exception**.

**Correctif** : filtre de bornes (AD-10) + dartdoc rectifiée (« par POSITION », portée exacte de la
mitigation, ce qu'elle ne ferme **pas**).

**Preuve R3** : mutation (retrait du filtre) ⇒ garde **ROUGE**, `Actual: <-2>` — **le défaut
utilisateur-visible lui-même**, pas un proxy.

> **Pourquoi c'était passé** : la garde AC6 « la file rétrécit » n'assérait que
> `takeException() isNull` — **le motif exact du HIGH de su-4**. Elle assère désormais le **NOMBRE**,
> sur les **DEUX canaux** (leçon su-6).

### 🟠 D2 — MAJEUR — AC9 littéralement fausse sur le canal moteur — **VOIE (c) : DOCUMENTÉ + GARDÉ ; DÉCISION OWNER OUVERTE**

`ZWhiteExamSessionEngine.answer(int quality)` est **positionnel** (enregistre pour `queue[cursor]`,
avance d'un cran) ; sa signature **ne porte pas d'index**. Or la vue rend les N cartes **toutes
saisissables** — l'ordre libre est son mode **nominal**, exigé par AC9/AC6. Sonde : Q3 juste, Q1
faux, Q2 sautée ⇒ `answers == [5,0]` contre `queue == [Q1,Q2,Q3]` ⇒ **3 attributions fausses, zéro
exception**.

**Voie retenue : (c) — documenter honnêtement + garder le seam public.** Justification écrite :

| Voie | Écartée pourquoi |
|---|---|
| (a) `answer({index, quality})` | **Changement de contrat du DOMAINE**, consommé par **20+ tests** d'une story antérieure (`z_white_exam_session_test.dart`). **D10 met explicitement le moteur hors périmètre de su-7.** ⇒ story dédiée. |
| (b) contraindre l'ordre dans la vue | **Contredit AC9 et AC6 tels qu'ÉCRITS** (« ordre quelconque », « sauter une question »). Amender une AC est une **décision OWNER**, pas un correctif de revue. |
| **(c) documenter + garder** ✅ | La prose cesse de mentir, la limite devient **visible et FIGÉE**, et la seule précondition qui rend le système correct (**commutativité**) est **testée** au lieu d'être espérée. **Aucune AC contredite, aucun contrat de domaine cassé.** |

**Correctifs** : contrat d'hôte sur `answer` ; `answers` redocumenté « ordre d'**ARRIVÉE** /
multi-ensemble, positionnellement **ININTERPRÉTABLE** » ; **commutativité déclarée précondition** de
`ZExamScoringPort` ; harnais : l'affirmation « le plus simple qui soit **correct** » **retirée**.

**Nouveau fichier porteur** : `z_white_exam_scoring_contract_test.dart` (4 tests) — fige `answers`
sous désordre, prouve `scoreWhiteExam` commutatif (5 permutations, contre-preuve de non-vacuité), et
**démontre la note fausse** d'un scorer positionnel (`2` vs `1` pour la **même copie**).

🚫 Le test qui traverse le désordre **n'a pas été supprimé** — il a été **complété** par l'axe moteur.

> 🔴 **RESTE OUVERT — OWNER** : amender AC9, **ou** ouvrir la story `answer({index, quality})`.
> **Bloquant pour su-10** (qui lira `engine.current` — lequel pointe la **mauvaise carte**).
> Consigné dans `su-7-ui-examen-blanc.md` (encadré sous AC9).

### 🟠 D3 — MAJEUR — la dartdoc d'honnêteté décrivait une assertion inexistante — **CORRIGÉ**

Le code assère **`hasLength(1)`** ; la prose (`:19`, `:24`, `:157`), l'intitulé (`:182`), la story
(T6 `:509`, AC3(b) `:223`, Completion Notes `:693`) disaient **`isEmpty`/« zéro »**.

**La déviation du code est BONNE ; c'est la prose qui n'avait pas suivi.** Scénario : un mainteneur
aligne le code sur le contrat documenté (`isEmpty`) → rouge à cause du témoin → **supprime le
témoin** ⇒ `isEmpty` sur un espion branché sur **rien** = **régression su-4 restaurée, VERTE, à
l'endroit même écrit pour la tuer**.

**Correctif (purement textuel)** : les 6 sites alignés sur `hasLength(1)`, avec le **pourquoi**
(« le témoin compte déjà `1` ; toute écriture ferait `2` ⇒ **strictement plus fort** qu'`isEmpty` »)
et un **🚫 explicite** contre le « réalignement ». La déviation est désormais **déclarée dans l'AC
elle-même**.

### 🟠 D4 — MEDIUM — champ rédigé sans verrou one-shot — **CORRIGÉ**

`z_flashcard_answer_input.dart:1210` — seul contrôle de su-3 sans verrou (`grep -qF readOnly` ⇒
RC=1). En `deferred`, **rien n'est peint** ⇒ le seul signal de soumission est la **disparition
silencieuse du bouton** : l'apprenant réécrivait sa copie déjà notée, et la révélation affichait un
verdict portant sur un texte **qui n'existait plus nulle part** (`ZFlashcardSubmission` ne porte pas
le texte). Rendait **D10 faux pour 4 des 6 `ZFlashcardType`**.

**Correctif** : `readOnly: corrected != null` (et non `enabled: false` — le texte noté doit rester
**lisible**). **R3** : retrait ⇒ **ROUGE**, `Found 1 widget with text "JE REECRIS APRES COUP"`.

### 🟠 D5 — MEDIUM — l'hôte de référence n'était pas « le plus simple qui soit CORRECT » — **CORRIGÉ**

`engine` en `late final` **sans `didUpdateWidget`** ⇒ **file périmée** ; `submissions` **jamais
purgée** ⇒ source directe du « -2 ». **C'est le modèle que su-10 recopiera.**

**Correctif** : `didUpdateWidget` (rebuild moteur + purge **totale** — jamais un remappage : une
position ne porte aucune identité) + dartdoc honnête (ce qu'il est, ce qu'il **n'est pas**, et sa
non-linéarité **assumée**).

**R3** (garde dédiée « l'HÔTE PURGE ») : purge retirée ⇒ **ROUGE** (`submissions` non vide) ;
rebuild retiré ⇒ **ROUGE**, `Actual: ['Q1','Q2']` — **la file périmée exhibée**.

> ⚠️ **Écart de méthode consigné** : ma première version de cette garde **ne testait rien** — la
> défense de la vue (D1) couvrait déjà le cas (clé **hors** bornes). Seule une clé **DANS** les
> bornes (carte neuve en position déjà répondue) discrimine. **Trouvé par mutation, pas par
> lecture.**

### 🔴 D6 — a11y/l10n — **1 HIGH + 2 MAJEUR + 2 MEDIUM — TOUS CORRIGÉS**

| # | Sév. | Défaut | Correctif | R3 |
|---|---|---|---|---|
| H1 | **HIGH** | `_ExamButton` : `ExcludeSemantics` engloutissait le `TextButton` ⇒ **`hasTapAction=false`** sur les **3** boutons. Annoncés « bouton », **inactivables** : l'apprenant non-voyant **ne pouvait ni soumettre son examen, ni sortir de la modale** (`confirm` ET `cancel` morts). | `onTap: onPressed` sur le nœud qui porte le rôle | retrait ⇒ **ROUGE** `<false>` |
| H2 | **MAJEUR** | `_ProgressHeader` publiait un **2ᵉ nœud de progression**, **contradictoire** (`0/2` vs `1/2`) ⇒ violation frontale d'**AC1** (« aucun compteur parallèle ») | relais pur (0 `Semantics`) | mutation ⇒ **ROUGE** `['0/2','1/2']` |
| H3 | **MAJEUR** | `_CorrectionReveal` : verdict **BÉGAYÉ** (`label="correct\nBIEN" value="correct"`) — le D1 de su-5 rejoué sur **le nœud le plus important de la story** | `ExcludeSemantics` sur le `Text` du verdict **seul** (le `feedback` reste annoncé — contenu distinct) | mutation ⇒ **ROUGE** `'L10N_CORRECT\n'` |
| M1 | MEDIUM | Trous de garde : 48 dp **omettait le dialog** (motif su-6 **re-commis**) ; phase `submitted` montée par **aucune** garde | dialog ajouté ; `pumpExam` accepte `submissions`/`result` | — |
| M2 | MEDIUM | Résultat de fin **jamais annoncé** (aucun `liveRegion`) : inséré **au-dessus** du focus ⇒ l'apprenant devait **deviner** puis remonter à l'aveugle | `resultKey` + `liveRegion: true` | retrait ⇒ **ROUGE** `<false>` |

> **Cause de non-détection commune** : la garde mesurait la **présence** (`label`, `size`) là où l'AC
> exige l'**association** et l'**ACTIVATION**. `tester.tap()` frappe des **coordonnées** — il passe
> **sous** l'`ExcludeSemantics`. **Aucun test n'empruntait le canal sémantique.** Leçon su-4.

### 🟠 D7 — adversariale / tests porteurs — **2 MAJEUR + 2 MEDIUM — TOUS CORRIGÉS**

- **MAJEUR — gate QCM (`:933`) gardé par RIEN** : contourné ⇒ **507/507 VERTS** pendant que les ✓/✗
  de vérité se peignaient sur chaque choix **en plein examen**. → `examQcmCard()` + garde.
  **R3** : bypass ⇒ **ROUGE** (`check_circle` peint).
- **MAJEUR — gate feedback (`:1398`) gardé par RIEN** : supprimé ⇒ **506/506 VERTS** pendant que le
  **corrigé du barème** s'affichait sous la question. → `examWrittenCard()` + garde.
  **R3** : retrait ⇒ **ROUGE** (`zFeedback` trouvé).
  **Cause racine des deux** : `examCard()` ne fabriquait que du **Vrai/Faux** ⇒ 1 canal sur 3 testé.
- **MEDIUM — test « qualité hors échelle » VACUE, prose mensongère** (« le port rend 99 » — **aucun
  port n'était branché** ; `ExamHost` n'en acceptait pas) : le clamp **entièrement supprimé** de la
  prod laissait le test **VERT**. → `evaluationPort` sur `ExamHost` + `SpyEvaluationPort` de su-3
  **réutilisé**.
  🔴 **Découverte de méthode** : `99` **ne discrimine RIEN** — `zApplyHintCeiling` fait déjà
  `min(raw, maxQuality)` et **plafonne tout seul**. Ma première correction aurait été **une seconde
  garde vacue**. Seule la **borne BASSE** est portée par `clampQuality` ⇒ l'aberration est **`-7`**.
  **R3** : clamp retiré ⇒ **ROUGE**, `Actual: <-7>` (**qualité hors échelle atteignant le moteur**).
- **MEDIUM — `zcrud.study.exam.noAnswer` gardée par rien** (7ᵉ clé, ajoutée au-delà d'AC7) → ajoutée
  à l'énumération + chemin « question sautée » exercé en `submitted`.
  ✅ **Vérifié : les 6 clés `exam.*` restantes sont TOUTES gardées** (boucle de vérification jouée).
- **MEDIUM — polarité inverse des 3 gates**, aucun `switch` : une 3ᵉ valeur (`onDemand`) aurait
  compilé **sans avertissement** puis fait **fuiter le feedback** (canal `liveRegion`, **annoncé au
  lecteur d'écran**) pendant que les icônes se taisaient. → `ZCorrectionVisibilityX.paintsCorrection`
  — **`switch` exhaustif sans `default`** (idiome maison de `viewPhaseOf`) : **polarité unique**, et
  une 3ᵉ valeur **casse la compilation au bon endroit**. *Garantie désormais **structurelle**, plus
  « par coïncidence ».*

### 🔵 LOW

| Point | Disposition |
|---|---|
| « L'hôte est **capable** de vérifier l'alignement » — affordance jamais exercée | **CORRIGÉ** — phrase supprimée, remplacée par la portée **exacte** de la mitigation |
| Collision `ValueKey` (`id=='3'` + carte éphémère d'index 3) ⇒ **throw** « Duplicate keys » (AD-10) | **CORRIGÉ** — espaces de noms disjoints (`id:` / `ix:`) |
| `queueKey` : `join` **O(N)** à chaque `build`, 3 lignes sous « seules les visibles sont construites » | **PROSE CORRIGÉE, non optimisé** — coût réel négligeable, **SM-1 non menacé** (`build` ne tourne pas à la frappe). Consigné. |
| « Je ne sais pas » sans garde en `deferred` | **CORRIGÉ** — 3ᵉ branche du motif ajoutée |
| `_ExamButton.minTarget` privé ⇒ inassertable | **CONTOURNÉ** — les 48 dp sont assérés sur la **taille rendue** des 3 clés **publiques** (`submit`/`confirm`/`cancel`). AC7 gardée. |
| Duplication des 6 symboles (`no_srs` vs `purity`) | **CONSERVÉE** — **exigée par AC3(a) tiret 2** (défense en profondeur) ; non wrap-vulnérable |
| **Révélation n'affiche jamais la bonne réponse** (`:339` `deferred` en dur) | **REPORTÉ — ARBITRAGE OWNER.** Déclaré par D4, AC2(3) satisfaite à la lettre. Un « examen blanc » qui n'enseigne pas la bonne réponse est un **choix produit**, pas un défaut : hors mandat d'une revue. Levier bon marché si l'owner le veut : `submitted ? immediate : deferred`. |

---

## Balayages systématiques (motifs, pas points)

**1. Gardes n'assérant QUE `takeException() isNull`** — script sur tous les `testWidgets` du diff :
**2 restantes**, toutes deux dans `z_list_session_view_lifecycle_test.dart` (AC5 démontage /
démontage à mi-`pump`). **HONNÊTES, laissées telles quelles** : leur intitulé revendique
**exactement** « aucune exception (AD-10) » — l'assertion **couvre la totalité de la prose**. Ce
n'est **pas** le motif su-4 (un titre qui promet la justesse en ne mesurant que le non-crash) ; le
remontage, lui, assère bien le comportement (`phase == setup`, `answered == 0`).

**2. Tests observant un canal INEXISTANT (vacuité — aveu ③)** — croisement automatique
`find.text(…)+findsNothing` × source de prod : **1 confirmé** (le test de clamp, D7) ⇒ **corrigé et
prouvé**. **0 restant.** Les 2 « suspects » signalés par l'heuristique sont mes propres gardes sur
des **données injectées par le test** (feedback du spy, texte saisi) — **non vacuës, prouvées par
mutation**. *La mutation tranche là où le grep se trompe : c'est elle qui a démasqué le clamp — et
mes **deux propres** gardes tautologiques.*

---

## Points CONFIRMÉS — au crédit du diff (non « corrigés »)

- ✅ **AC3 « zéro écriture SRS » : RÉELLEMENT SATISFAITE, prouvée par MUTATION** (`.apply(` injecté
  ⇒ étages (a) **et** (c) rougissent). Scan **non vide** (`existsSync`+`isNotEmpty`), contre-preuve
  **EXERCÉE** (pas de défaut D6), espion **prouvé captant DANS la portée de l'assertion**
  (**durcissement réel vs su-4**). **`ZExamScoringPort` ne transporte NI store NI scheduler ⇒ ne
  peut PAS rouvrir la voie SRS.**
- ✅ **La double soumission n'est PAS rouverte** — rejouée en **tapant réellement** les **3 chemins**
  en **double/triple-tap RAPIDE sans pump** (l'attaque de la fenêtre `await` que seul `_submitLocked`
  couvre) ⇒ `submissions == 1` partout. La thèse centrale (différer le **rendu seul**, laisser
  `_correction` posé) est **la bonne conception**.
- ✅ **su-3 STRICTEMENT intact** — ses **8 fichiers de test non touchés** (mtimes antérieurs
  re-vérifiés), **verts sur le fichier de prod modifié**. Meilleure preuve de non-régression
  disponible ici. `zcrud_flashcard` **464** inchangé.
- ✅ **`deferred` muet sur TOUS les canaux** (scan récursif de l'arbre sémantique ⇒ `[]`).
- ✅ **AD-43 vrai sur disque** (`store|persist|save|repository|reviewer|scheduler` ⇒ **100 %
  dartdoc, zéro code**) ; remontage ⇒ `phase == setup`, `answered == 0`.
- ✅ **Zéro `try-catch`** ; la vue n'importe pas le moteur ; `onAnswered` capture l'index dans la
  closure de `_question`.
- ✅ **Les 3 aveux de l'agent sont HONNÊTES et VÉRIFIÉS** — ① `captured==[0,5,0]` reste vert sous
  décalage (**vrai**, et l'axe « rendu par carte » rougit bien) ; ② la garde de contraste énumère
  les **écrans** (**vrai**, trou non repo-wide) ; ③ AC2(4) observait un canal inexistant (**vrai**,
  corrigé, motif clos **sur son fichier**). *Les trois ont été déclarés **spontanément** — c'est ce
  qui a permis de chercher au bon endroit.*

---

## Fichiers touchés

**Prod** (4) — `zcrud_session/lib/src/` :
`presentation/z_list_session_view.dart` · `presentation/z_flashcard_answer_input.dart` ·
`presentation/z_correction_visibility.dart` · `domain/z_white_exam_session_engine.dart` *(dartdoc de
contrat uniquement — **aucun changement de comportement ni de signature**)*

**Tests** (5) : `z_exam_harness.dart` (purge + `didUpdateWidget` + `evaluationPort` + fabriques
QCM/rédigée) · `z_list_session_view_robustness_test.dart` · `z_list_session_view_correction_test.dart` ·
`z_list_session_view_no_srs_test.dart` *(prose)* · `z_session_mode_selector_test.dart` ·
**NOUVEAU** `z_white_exam_scoring_contract_test.dart`

**Story** : `su-7-ui-examen-blanc.md` (T6, AC3(b), AC9 + encadré d'arbitrage, Completion Notes)

🚫 **Non touchés** : `sprint-status.yaml` · `zcrud_core` · les 8 fichiers de test de su-3 · aucun
commit.
