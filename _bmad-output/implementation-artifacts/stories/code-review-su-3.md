# Code-review — Story `su-3` (saisie notée, indices, minuteur, avance)

**Story** : `su-3-saisie-notee-indices-minuteur-avance.md` (11 ACs, 14 arbitrages)
**Spine** : AD-35 (éval ADVISORY, QCM/VF locaux) · AD-36 (indice stocké → port → plafond LOCAL en
dernier) · AD-33 (SRS via `ZSessionReviewer` seul) · AD-10 (jamais de throw) · AD-13 · AD-46 ·
hérités AD-1..32
**Revue** : Workflow multi-agent à 7 lentilles (conformité AD · SM-1/perf · a11y-l10n · adversariale ·
robustesse · isolation-surface · tests porteurs).
**Mode de correction** : `cp` + SHA-256 pour toute sauvegarde. **Aucun `git checkout`/`git restore`**
(su-1/su-2/su-3 sont non committés — un checkout les DÉTRUIRAIT ; c'est arrivé pendant su-3).
**Aucun `melos run test`** (il parallélise les `flutter test` et se bloque) : `flutter test` **par
package, séquentiellement**.

---

## VERDICT

**CORRIGÉE — prête pour `done`.** 4 MAJEURS, 8 MEDIUM, 3 LOW et 2 findings R3 (1 MAJEUR, 1 MEDIUM)
traités : **15 corrigés**, **3 justifiés/reportés par écrit**.

Le socle de la story était **solide et l'est resté** : logique pure sans horloge ni I/O, cas dégradés
de la carte tous traités, ports hostiles muselés sur les deux seams, isolation **PASS (0 finding)**,
et **SM-1/AC10 — l'objectif produit n°1 — CONFIRMÉ par mesure indépendante** (0 reconstruction du
contenu pour 100 frappes, focus conservé, minuteur tickant). Les défauts se concentraient sur trois
axes que la story n'arbitrait **nulle part** — donc des **trous**, pas des écarts assumés : la
**concurrence**, le **canal de correction** de la moitié des types locaux, et une série de
**verrous factices** (code ou prose qui *prétendait* garantir ce qu'il ne garantissait pas).

> **Fil rouge de cette revue** — trois findings distincts (D8, D11, D12) et deux R3 ont la **même
> forme** : *une affirmation de conformité sans réalité derrière*. Un `zReduceMotionOf` qui n'anime
> rien, une fonction de routage jamais appelée mais documentée comme « la voie de routage », une
> dartdoc qui invoque un test inexistant, un test qui compare deux constantes de son cru. **Un verrou
> factice est pire qu'un verrou absent : il se donne pour une preuve.** Chaque correction ci-dessous
> a donc été validée par **injection rejouée** — le rouge est mesuré, jamais raisonné.

---

## Vérif verte — RC RÉELS, rejoués sur disque

| Gate | Commande | Résultat |
|---|---|---|
| Analyse repo-wide | `dart run melos run analyze` | **RC=0** ✅ |
| Verify | `dart run melos run verify` | **RC=0** ✅ (graphe acyclique, CORE OUT=0, secrets, codegen-distribution) |
| Tests | `flutter test` **par package**, séquentiel (`dart test` pour les purs Dart) | **23/23 packages verts — 3923 tests** ✅ |

**Delta vs la référence orchestrateur (23/23, 3876)** : **+47** — `zcrud_session` **198 → 244**
(+46), `zcrud_flashcard` **398 → 399** (+1). Aucun test supprimé sauf **un test tautologique** (D8),
remplacé par une consignation écrite.

Les 21 `info` de `zcrud_session` et 8 de `zcrud_study` sont **pré-existantes** (`hasFlag` déprécié
dans les tests du dev, `${callCount}` dans son `SpyHintPort`) — aucune n'est introduite ici, et
`melos analyze` rend **RC=0**.

**Hygiène** : `find packages -name 'zz_probe*'` ⇒ **0** · `packages/zcrud_core` ⇒ **0 modification** ·
`*pubspec.yaml` ⇒ **0 modification** · `sprint-status.yaml` **jamais écrit** par cette passe (il était
déjà ` M` à l'entrée, du fait de l'orchestrateur).

---

## Findings — disposition

### 🔴 D1 — MAJEUR — carte changée pendant un appel de port EN VOL → **CORRIGÉ**

`z_flashcard_answer_input.dart` — `_ZFlashcardAnswerInputState`

**Scénario d'échec** : carte A (rédigée), l'apprenant soumet ; le port met 2 s ; la session avance sur
la carte B ; le port répond. **Le `then` écrit sur la carte B** — le feedback de A s'affiche sur B et
la soumission de A part au `onSubmitted` de B. En su-4, `onSubmitted` sera branché sur
`ZSessionReviewer.reviewCard` : c'est un **SRS faux écrit sur la mauvaise carte, par la voie
légitime** — AD-33 n'attrape rien, la garde de pureté non plus. Reproduit par la lentille robustesse
(`P4 subsA=0 subsB=1`).

**Racine** : `mounted` **ne suffit pas** — quand la carte change, seul le *widget* est remplacé ;
l'`Element` et le `State` survivent, `mounted` reste `true`. Absence prouvée : `grep -n
"didUpdateWidget"` ⇒ **RC=1**.

**Deux dégâts AD-36 supplémentaires, même racine** (sondes P3/P3b) : l'indice de A restait affiché sur
B **et comptait comme `hintsUsed=1`** (B plafonnée à tort) ; et `_hasUnservedStoredHint` (`_hasStoredHint
&& _shownHints.value.isEmpty`) était **court-circuité à jamais** ⇒ l'indice **stocké de B n'était jamais
servi**, **le port ÉTAIT appelé** (l'« appel IA superflu » qu'AD-36 existe pour empêcher), et
`shownHints` **transportait le contenu de la carte A dans le prompt de B**.

**Correctif** : jeton de fraîcheur `_generation` capturé **avant** chaque `await`, re-comparé au retour
(`if (!mounted || generation != _generation) return;`) sur **les deux seams** (évaluation + indice) ;
`didUpdateWidget` + `_resetForNewCard()` (sélection, indices, erreur, correction, controller,
stopwatch, ticker, verrous, `_advanceTimer`).

### 🔴 D2 — MAJEUR — soumission RÉ-ENTRANTE sur **2 chemins sur 3** → **CORRIGÉ**

**Scénario 1** : carte rédigée, port lent, **aucun indicateur de charge** ⇒ l'apprenant retape.
`P1: callCount=2, submissions=2` — **deux appels IA facturés** pour une réponse, deux `onSubmitted`.
**Scénario 2** : QCM répondu **juste** ⇒ correction affichée, cran **5** pré-sélectionné ; « Je ne sais
pas » **toujours actif** ; un tap (curiosité, tap parasite — cible ≥ 48 dp, juste sous la correction)
⇒ `P2: [5, 0]` — **un `lapse` fabriqué sur une réponse exacte**. Aucun AC ne prévoit que ce bouton
reste offert après la révélation.

L'intention one-shot était **explicite et implémentée** sur QCM (`if (corrected == null)
_SubmitButton`) et V/F (`onPressed: corrected != null ? null : …`) : ce n'était pas un arbitrage, mais
un **oubli contredit par ses deux frères**.

**Correctif — les TROIS chemins** : verrou `_submitLocked` à l'entrée de `_submitWritten`,
`_submitLocal` (V/F auto-soumis) et `_submitDontKnow` — posé **avant l'`await`**, il ferme la fenêtre
que le gating par `_correction` ne ferme pas ; **plus** le gating UI (`_WrittenInput` et
`_DontKnowButton` reçoivent enfin `correction` et disparaissent après correction, comme leurs frères).
Dans `_submitLocal`, le verrou n'est posé qu'**après** le `raw == null` : ne rien soumettre ne
consomme pas la soumission unique de la carte.

### 🔴 D3 + D4 + D13 — MAJEUR/MEDIUM — `didUpdateWidget` absent : minuteur figé, ticker fantôme, deux horloges → **CORRIGÉ (même racine, corrigés ENSEMBLE)**

**D3** : basculer `timerDisplay` `hidden→elapsed` à chaud fige l'affichage à **`00:00` POUR TOUJOURS**
pendant que le `Stopwatch` compte et que `timeTaken` part au barème ⇒ **l'apprenant est chronométré
sans le voir** — l'inverse exact de FR-SU4, sans exception ni test rouge. `hidden` étant le **défaut**,
tout hôte au minuteur optionnel tombe dessus, et su-4 (pile swipeable) recyclera le `State`.
**D4** : le ticker **survit au masquage** — mesuré `01:02` après 60 s masqué ⇒ **60 réveils sans
abonné**, contredisant frontalement le commentaire `:224-225` qui revendiquait l'invariant inverse.
**D13** : l'affiché (compteur synthétique) et le mesuré (`Stopwatch`) **divergent**.

⚠️ La revue prévenait qu'un correctif **naïf** de D3 rendrait l'affichage **faux**. Le correctif
retenu en tient compte : `_syncTicker({required bool resync})`, **voie unique**, appelée au montage et
à chaque `didUpdateWidget` — annule en `hidden`, annule sur `countdown` **épuisé** (LOW F3), et
**resynchronise `_elapsed` sur `_stopwatch` au (RÉ)ARMEMENT**. `_stopwatch` redevient la **source de
mesure unique**, l'affichage en dérive (D13).

**Arbitrage technique consigné** : l'affichage **continue de cumuler les ticks entre deux armements**
plutôt que de lire `_stopwatch` à chaque tick — le dev avait raison sur ce point et sa dartdoc est
conservée : un `Stopwatch` n'est **pas *fakeable*** (`tester.pump(1s)` avance les `Timer`, pas
l'horloge réelle) ⇒ lier l'affichage à `_stopwatch` à chaque tick rendrait **invérifiable** qu'`elapsed`
croît et que `countdown` décroît. La resynchro **à l'armement** capture l'essentiel de D13 sans
sacrifier le déterminisme.

**Angle mort structurel comblé** : `z_flashcard_timer_test.dart` montait chaque config **à froid**
(`key` distinctes ⇒ `State` neuf) — **aucun** test ne faisait varier `timerDisplay` sur un `State`
**vivant**. Nouveau groupe de 4 tests à **`key` stable**, dont un garde-fou du correctif lui-même
(« un rebuild sans changement ne resynchronise PAS » — sinon le minuteur n'avancerait jamais).

### 🔴 D5 — MAJEUR — `'required'` codé en dur, non localisé, AFFICHÉ → **CORRIGÉ (+ trou de garde fermé)**

**Scénario** : un apprenant francophone tape une lettre puis l'efface (hésitation, correction de
frappe — geste banal). Sous le champ apparaît **« required »**, en anglais, dans une UI entièrement
française. En arabe (RTL), idem. Sonde : `Found 1 widget with text "required"`.

C'était **exactement la dette su-1 (`'ok'`/`'lapse'`) que su-3 venait de solder dix lignes plus haut
dans le même diff** : remboursée d'une main, recontractée de l'autre.

**Correctif** : `_requiredValidator(context)` dans le `State` — `label(context,
'zcrud.flashcard.answerRequired', fallback: 'Réponse requise')`. La **mémoïsation d'AC10 est
préservée** (closure reconstruite **uniquement** si le libellé résolu change ⇒ changement de locale) ;
un test dédié pinne `identical()` du validateur entre builds.

**Trou de garde fermé** — le point important : `z_widgets_hardcode_scan_test.dart` ne bannissait que
les **couleurs** et les **API non-directionnelles**. **Aucun motif ne visait les chaînes
utilisateur** ⇒ l'AC11 « zéro libellé en dur » n'avait **AUCUN exécuteur**. Ajout d'un scan des
**puits réellement rendus à l'écran** : `Text('…')`, `errorText:`/`labelText:`/`hintText:`/… et
**validateur rendant un littéral**.

> 🔴 **Ma propre garde a d'abord échoué, et je l'ai mesuré.** Ma première version n'ancrait que la
> signature `String? _validate(…)` — la forme livrée par su-3. Rejouer l'injection `'required'` sur le
> code **corrigé** (`_cachedValidator = (value) => … ? 'required' : null;`) laissait le scan **VERT** :
> une garde qui n'attrape que le défaut d'hier laissera passer celui de demain. **Deux formes** sont
> désormais couvertes, avec une contre-preuve dédiée pour chacune.

**Portée déclarée honnêtement** (et volontairement étroite — une garde qui crie au loup est une garde
qu'on désactive) : les **interpolations pures** (`Text('$count')`, `Text('${a}/${b}')` — formes
**réelles** de `z_session_quality_breakdown.dart` et `z_study_progress_rings.dart`) sont **exclues** :
elles rendent un **nombre**, pas de la prose. Non couvert, consigné : un littéral passé par variable
intermédiaire, et `Semantics(label: '…')` (cf. LOW-3).

### 🔴 D6 — MAJEUR — Vrai/Faux : AUCUN canal de correction → **CORRIGÉ**

**Scénario** : carte V/F, `isTrue: true`, hôte sans `onQualitySelected` (cas **légitime et documenté**).
L'apprenant tape « Faux » (**mauvaise réponse**). À l'écran : **deux boutons grisés**. **Il n'apprend
jamais qu'il s'est trompé.** Au lecteur d'écran : « Faux, bouton, désactivé », `value` **vide**. La
carte est **pédagogiquement muette**. Sonde : `label=Faux value=<vide> checkIcons=0 cancelIcons=0`.

Ce n'était pas « la seule couleur » (ce qu'AD-13 interdit) : c'était **rien du tout**. **AC1 nomme V/F
explicitement** et exige un canal non-coloré obligatoire. Le seul test de canal non-coloré ne montait
**qu'un QCM** ⇒ la garde n'existait pas **pour la moitié des types locaux**.

**Correctif** : `_Correction.answeredTrue` + marqueurs par bouton, alignés sur `_ChoiceRow` — et
conformes à la **leçon HIGH de su-2** (prouver l'**association**, pas la présence) : `Semantics(value:)`
porté par la **MÊME node** que le libellé. 3 tests neufs **exercent V/F**, dont un qui part de la
**clé structurelle** et vérifie que le marqueur du bon bouton n'est pas attaché au voisin.

### 🟠 D7 — MEDIUM — QCM : le choix de l'utilisateur EFFACÉ après correction → **CORRIGÉ**

QCM « Capitale du Togo ? » [Accra, **Lomé**, Cotonou]. L'apprenant coche **Accra**, valide. Il voit
`Accra ✗ · Lomé ✓ · Cotonou ✗` : **rien ne distingue « Accra », son propre choix, de « Cotonou »,
qu'il n'a jamais coché** — mesuré **pixel-identiques** (même `IconData`, même couleur). Or
`Semantics(checked:)` survivait ⇒ **un utilisateur non-voyant était MIEUX informé qu'un voyant**.
AD-13 demande la **parité** des canaux, pas leur **inversion**.

**Correctif** : **deux axes de FORME** (aucune couleur sollicitée) — ✓/✗ = la **vérité** ; **plein** =
« vous l'aviez coché », **contour** = « vous ne l'aviez pas coché ». Appliqué **identiquement** au QCM
et au V/F (D6). Test porteur : `iconOf(0) != iconOf(2)` sur deux choix **tous deux faux**, dont un
seul coché — le défaut exact.

### 🟠 D8 — MEDIUM — Reduce Motion DÉCORATIF : `zReduceMotionOf` était du CODE MORT → **CORRIGÉ (retrait + consignation)**

`AnimatedOpacity(opacity: 1, duration: zReduceMotionOf(…) ? …)` : une animation implicite ne se
déclenche que sur un **changement** de valeur. `opacity` étant la **constante 1** et le sous-arbre
n'étant **créé** qu'à la correction, elle **n'animait JAMAIS** (mesuré : `FadeTransition.opacity.value
== 1.0` à chaque pump, dans **les deux** branches). Le résultat de `zReduceMotionOf` était donc
**inobservable**, et son test **restait vert si la ligne était supprimée** — un test qui **ne peut pas
rougir** (motif su-2 D12 / su-1 D7, que la story interdisait explicitement de rejouer).

**Arbitrage — tranché sur ce qui sert l'utilisateur.** AC11 dit exactement : « **toute affordance
ANIMÉE** de su-3 passe par `zReduceMotionOf` ». **Aucune affordance de su-3 n'est animée**, et la story
n'en réclame nulle part ⇒ la clause est satisfaite **par vacuité**. Fabriquer une animation pour donner
un objet à la garde aurait été inventer un besoin ; garder les trois (appel mort + cérémonie + test
tautologique) aurait laissé une surface qui **SIMULE la conformité AD-13**.
⇒ `AnimatedOpacity` **retiré**, appel à `zReduceMotionOf` **retiré**, test tautologique **supprimé**,
le tout **consigné** en clair dans la prod et dans le test (avec la mesure qui le justifie).
🔒 Le **second** test du groupe (« l'auto-passage n'est PAS supprimé par Reduce Motion ») est **sain et
discriminant** — il exerce la règle « dégrader l'ANIMATION, jamais la FONCTION » sur une fonction
réelle : **conservé**. `zReduceMotionOf` reste la primitive unique du repo, utilisée par su-2.

### 🟠 D9 — MEDIUM — feedback et erreur d'indice SILENCIEUX pour un lecteur d'écran → **CORRIGÉ**

Sonde : `ancêtres Semantics liveRegion=true : 0`. **Scénario** : utilisateur de lecteur d'écran, port
d'indices hors ligne. Il active « Indice ». Le focus reste sur le bouton ; « Indice indisponible. »
**apparaît** plus bas dans l'arbre — **aucune annonce**. Rien ne se produit de son point de vue : **il
ré-appuie, en boucle**. Idem pour le `feedback`, **contenu pédagogique central** de la carte, qui
apparaît de façon **asynchrone**. Le commentaire de prod « un échec n'est **jamais silencieux** » était
vrai pour un voyant, **faux** pour un non-voyant — alors qu'AC5 exige que l'échec soit perceptible.

**Correctif** : `Semantics(liveRegion: true)` sur les deux nœuds (contenu asynchrone hors focus = cas
d'école). 🔒 Le minuteur **reste sans `liveRegion`** (une annonce par seconde noierait le lecteur
d'écran) — bon point du dev, **pinné par un test** pour qu'il le reste.

### 🟠 D10 — MEDIUM — indice RÉ-ENTRANT : un indice PAYÉ puis JETÉ → **CORRIGÉ**

Deux demandes concurrentes capturaient le **même** `shown` (copie pré-`await`) ⇒ la seconde réponse
**écrasait** la première. `P5: callCount=2, indices affichés: généré1=0 généré2=1` — **2 appels IA
facturés, 1 indice affiché, `hintsUsed == 1`** ⇒ **le plafond d'AD-36 faussé**, et l'anti-répétition
**aveugle** (le second appel recevait `shownHints: []` alors qu'un indice était en vol).

**Correctif** : verrou `_hintInFlight` (même discipline que D2) **et** cumul lu **au dernier moment**
(`_shownHints.value`, jamais la copie pré-`await`). 🔒 Le verrou est **libéré sur échec** — un indice
**non obtenu** doit pouvoir être redemandé (un verrou jamais libéré condamnerait l'apprenant après une
panne réseau) ; le compteur, lui, reste inchangé. Test dédié pour **chacune** des deux propriétés.

### 🟠 D11 — MEDIUM — `zIsLocallyEvaluatedType` : seconde source de routage, JAMAIS appelée → **CORRIGÉ (voie (a) + (b))**

Le trou AD-35 **était fermé** — mais par le `switch` d'affordance de `_buildInput`, **pas** par
`zIsLocallyEvaluatedType`, qui n'avait **aucun site d'appel** (grep prod = déclaration + 1 commentaire ;
grep tests = **RC=1**). **Deux tables décidaient la même chose, sans rien qui les lie**, et le barrel
`:147` **affirmait faussement** qu'elle « est la voie de ROUTAGE ».

**Scénario d'échec** : une 7ᵉ valeur `ZFlashcardType.cloze` (localement vérifiable). Les deux `switch`
étant exhaustifs sans `default`, le compilateur **force** à remplir les deux : `cloze => true` dans le
domaine (lecture naturelle) et `cloze ||` dans la chaîne des types rédigés de `_buildInput` (point
d'atterrissage naturel d'un type textuel) ⇒ **le port IA reçoit un type déclaré LOCAL**, silencieusement,
**compilation verte, aucun test rouge**.

**Correctif — la voie qui SUPPRIME la seconde source (leçon AD-46), conformément à la préférence
exprimée** : `_submitWritten` — **seul point du code d'où le port est atteignable** — commence par
`if (zIsLocallyEvaluatedType(widget.card.type)) { _submitLocal(); return; }`. La fonction du domaine
**décide réellement**, et elle seule. **Plus** (b) : un test **auto-énumérant** sur
`ZFlashcardType.values` liant les deux tables (`spy.callCount == 0 ⟺ zIsLocallyEvaluatedType(type)`) —
un 7ᵉ type est couvert **sans édition du test**. Commentaire du barrel et dartdoc **corrigés** pour
décrire le mécanisme réel.

### 🟠 D12 — MEDIUM — dartdoc de prod AUTO-RÉFUTANTE → **CORRIGÉ**

`z_hint_penalty.dart:13,23-29` affirmait « **non commutatif** » **et** « verrouillé par un **test
dédié** » : **les deux faux**, et le contre-exemple construit démontrait en réalité l'**égalité** des
deux ordres. Le dev avait **lui-même mesuré** la commutativité (1144 combinaisons, 0 divergence) et
l'avait consignée **dans le test** — mais la dartdoc de prod était restée sur le premier jet. Un
futur mainteneur de su-4/su-7 aurait lu le **propriétaire unique** de la pénalité, cru qu'un test
verrouillait l'ordre, et refactoré en confiance — ou serait parti chercher un test fantôme.

**Correctif** : dartdoc réécrite pour dire **ce qui est vrai et par quoi** — preuve algébrique
(`A == B` dès que `c >= minQuality`), garantie **structurelle** par l'`assert(minQuality <
passThreshold)` de `ZSrsConfig` (AD-46) ⇒ **l'invariant porteur n'est pas l'ordre, c'est
`ceiling >= minQuality`**, et c'est **lui** qui est pinné. L'ordre reste imposé **par mandat AD-36 et
par robustesse** (il cesserait d'être équivalent si AD-46 relâchait ses asserts), **pas** parce qu'un
test le verrouille — un tel test ne pourrait jamais rougir, et l'écrire aurait été **fabriquer une
preuve**. Référence au test fantôme **supprimée**.

### 🟠 (adversariale D4) — MEDIUM — l'« invariant porteur » de remplacement était à MOITIÉ TAUTOLOGIQUE → **CORRIGÉ**

Corollaire direct de D12, et il fallait le traiter pour que la dartdoc corrigée dise vrai.
`z_hint_penalty_test.dart` pinnait `inInclusiveRange(minQuality, maxQuality)` en revendiquant rougir
« le jour où le plafond dépasserait `maxQuality` ». **Les deux moitiés étaient fausses** : (1)
`zApplyHintCeiling` termine par `math.min(rawQuality, ceiling)` et le test passe `rawQuality:
c.maxQuality` ⇒ le résultat est `<= maxQuality` **par construction du `min`** — la borne haute ne peut
**jamais** échouer ; (2) un plafond **au-dessus** de `maxQuality` (atteignable :
`ZHintPenaltyPolicy(floor: 100)`, que le test ne passait **jamais**) **ne casse pas** la commutativité.

**Correctif** : pin de la **seule** moitié load-bearing — `ceiling >= config.minQuality` — assortie de
sa vraie raison, **plus** un test neuf balayant `policy.floor: 100` (hors échelle) qui documente
honnêtement que le `min` final borne la note quoi qu'annonce le plafond. **Discriminant prouvé** :
retirer la remontée du plancher dans `zHintCeilingFloor` ⇒ **ROUGE**.

### 🔴 R3-MAJEUR — `R3-I10c` n'était PAS porteur → **CORRIGÉ**

Le test revendiqué « joué réellement, rouge obtenu » était **VERT** sous l'injection (mesuré :
**198/198**). Il faisait `const a = ZFlashcardDefaultContent.builder; const b = …;
expect(identical(a, b), isTrue)` sur **deux tear-offs déclarés dans le test lui-même** : il testait la
**canonicalisation de Dart** — vraie que `ZFlashcardAnswerInput` existe ou non — puis
`find.byType(...)` prouvait la **PRÉSENCE**, pas l'**ASSOCIATION** (défauts su-1 D5 + su-2 D2 sous une
forme neuve). **Le builder résolu (`_contentBuilder`) n'était jamais lu.**

**Scénario d'échec** : un dev applique `?? (c,s) => …` (forme naturelle, que l'AC10 interdit
nommément) ⇒ le builder est **réalloué à chaque build**, le slot AD-40 perd sa stabilité de rebuild.
**Zéro test ne rougit.** *(Sévérité honnête, reprise de la lentille : l'impact SM-1 réel est
aujourd'hui **nul** — la frappe ne rebuild pas la surface. Le trou est **latent** : il s'ouvrira dès
que la surface se reconstruira pour une autre raison — et `didUpdateWidget`, ajouté par D1/D3,
**crée précisément** cette raison. Le verrou devait donc devenir réel maintenant.)*

**Correctif** : la résolution est extraite dans `ZFlashcardAnswerInput.resolveContentBuilder`
(`@visibleForTesting`) — **voie unique**, et **seul siège lisible** du « builder résolu » qu'AC10
prescrit. `_contentBuilder` y délègue. 4 tests la **traversent réellement** : identité stable entre deux
résolutions, identité **attendue** (le tear-off statique — une closure mémoïsée passerait le premier
test, pas celui-ci), pass-through verbatim d'un builder injecté, et atteinte réelle du défaut.
**Rouge prouvé** sous l'injection tear-off → closure.

### 🟠 R3-MEDIUM — plafond sur le chemin de REPLI (AC3) : AUCUN test → **CORRIGÉ**

Injection mesurée : neutraliser le plafond **uniquement** quand `evaluation == null` laissait
**198/198 VERTS**. Les 4 cas de repli asseraient tous `quality == passThreshold` **avec 0 indice** — le
plafond n'y était **jamais sollicité**. Or AC6 exige « **jamais un chemin qui l'oublie** ».

**Scénario d'échec** : l'apprenant demande **3 indices**, rédige, le routeur IA est **hors ligne**
(`Left`) ⇒ repli `raw = 3`. Attendu `min(3, max(5-3,2)) = **2**` (lapse) ; plafond oublié ⇒ **3**
(réussite). **L'apprenant valide sa carte grâce à une panne réseau** — AD-36 contourné par le chemin
le plus fréquent en mobilité (NFR-SU8).

**Correctif** : 3 tests (`Left` / absent / `throw`) **+ 3 indices ⇒ qualité 2**. ⚠️ **Valeur
discriminante** choisie conformément à la lentille : **3** indices, jamais 2 (`min(3, max(5-2,2)) = 3`
serait **identique** au repli sans plafond ⇒ ne discriminerait rien — leçon D7).

### 🟠 R3-MEDIUM — `R3-I11b` (`MergeSemantics`) : 4ᵉ prescription FAUSSE → **CONSIGNÉ (test conservé)**

Injection rejouée (retrait du `MergeSemantics`) : `..._a11y_test.dart` **+12 VERTS**, package
**198/198 VERTS**. **Cause** : sans lui, le `Semantics(inMutuallyExclusiveGroup:, checked:, value:)`
**absorbe déjà** les fragments compatibles de ses descendants — le `MergeSemantics` est **redondant**,
la propriété d'association tient **sans lui**.

**Disposition** : conformément à la recommandation de la lentille — **le test n'est PAS en cause, il
est PORTEUR** (il part de la **clé structurelle**, asserte `label`+`value` sur la **même node**, correct
en **position 2**) : **conservé tel quel**. C'est la **revendication** qui était fausse. Elle est
**consignée** en tête du groupe, avec la mesure et la cause, au même titre que les 3 écarts que le dev
avait lui-même consignés. Le `MergeSemantics` de prod est **conservé en défense en profondeur** (il
redeviendrait load-bearing si un descendant posait une frontière explicite).

### 🔵 LOW — dispositions

| # | Finding | Disposition |
|---|---|---|
| **F3** | `countdown` épuisé ⇒ reconstruction perpétuelle d'un `00:00` immuable, `_elapsed` croît sans borne | ✅ **CORRIGÉ** — trivial, greffé sur `_syncTicker` (D3/D4). Test dédié. |
| **L2** | Bouton « Indice » actif **après** correction (appel IA facturé pour une carte déjà corrigée) | ✅ **CORRIGÉ** — gaté sur `correction`, cohérent avec les 3 autres contrôles (D2). |
| **LOW-6** | Le minuteur ne dit pas **dans quel sens** il va (« Minuteur » pour `elapsed` ET `countdown`) | ✅ **CORRIGÉ** — 2 clés l10n (`timer.elapsed` / `timer.countdown`). Information décisive en examen blanc (su-7). |
| **L1** | Réponse **vide** ⇒ `passThreshold` (une réussite), quand « Je ne sais pas » — aveu honnête — vaut 0 | 🟡 **REPORTÉ — justifié** (ci-dessous) |
| **LOW-7** | `Semantics(label:)` sans `excludeSemantics` au-dessus d'un `Text` homonyme | 🟡 **REPORTÉ — justifié** (ci-dessous) |
| **LOW-2** | `timeTaken` dépend de l'horloge réelle (marge mesurée **×220**, variance ≈ 5 %) | 🟡 **CONSIGNÉ, aucun changement** — la lentille ne demandait pas de correction. La **conception est bonne** : mesure exacte (`Stopwatch`) séparée de l'affichage déterministe (ticker). |
| **LOW-3** | *(nouveau — découvert par ma garde D5)* `z_session_quality_breakdown.dart:171` : `Semantics(label: 'hors échelle: $labelText')` — libellé **français en dur** | 🟡 **REPORTÉ — justifié** (ci-dessous) |

**Justifications écrites des LOW reportés**

- **L1 (réponse vide ⇒ `passThreshold`)** — **Pas une violation** : c'est l'interaction de **deux
  règles correctes** (repli neutre d'AC3 + validateur non gatant), qui produit une incitation
  perverse. Gater la soumission sur `_validate` **changerait la sémantique d'AC3** (le repli neutre
  est prescrit **quel que soit** le contenu) et introduirait un `Form`/`GlobalKey<FormState>` absent
  de la conception — un choix de produit, pas une correction de revue. **Hors périmètre de su-3 ;
  à arbitrer par le owner** (au ledger su-4).
- **LOW-7 (`excludeSemantics`)** — **Patron pré-existant, hérité de su-1** (`_QualityButton:265-270`),
  présent hors du diff de su-3. La lentille elle-même conclut « à traiter **globalement**, pas dans
  su-3 seul » : le corriger ici créerait une **divergence** entre deux boutons du même repo. **Ledger
  su-4**, en une passe.
- **LOW-3 (`Semantics(label:)` en dur)** — Défaut **réel** mais dans du code **su-1/su-2**, hors du
  diff de su-3, qu'**aucune lentille n'avait relevé** (ma garde neuve l'a découvert). Ajouter
  `Semantics(label:` aux puits scannés rendrait la garde **ROUGE sur du code hérité** et forcerait une
  correction hors périmètre, avec un risque de régression sur les tests d'une autre story. La **portée
  de la garde le déclare explicitement** dans sa dartdoc plutôt que de le taire. **Ledger su-4** :
  corriger le libellé **puis** étendre le puits.

---

## Points CONFIRMÉS — au crédit du dev

Cette revue **confirme** et porte au crédit du dev, vérifié empiriquement par plusieurs lentilles
indépendantes :

1. **Les 3 prescriptions que le dev déclarait fausses sont EXACTES** — il a **mesuré au lieu de
   fabriquer un test complaisant**, et il l'a écrit :
   - **R3-I6 (plafond avant clamp) est INATTEIGNABLE** : les deux ordres sont **commutatifs** (1144
     combinaisons, 0 divergence), et ce n'est pas un accident empirique — c'est **verrouillé par les
     `assert` de `ZSrsConfig`** ; les configs pathologiques sont **inconstructibles**. Un test
     « prouvant l'ordre » **ne pourrait jamais rougir**. Son substitut (pinner l'invariant porteur)
     était **le bon réflexe** — même si l'invariant choisi n'était pas encore le bon (corrigé
     ci-dessus).
   - **Le discriminant « 9 ⇒ 5 » est MASQUÉ par le plafond** : mesuré — sans `clampQuality`, **1 seul
     test échoue**, et c'est bien le **cas bas**. Il a **correctement remplacé** le discriminant d'AC2
     et **nommé** les tests porteurs pour empêcher leur suppression. C'est le défaut D12 de su-2
     correctement traité.
   - **D4 ne mord pas sur `.apply(`/`.reviewCard(`** : exact — `dart format` coupe **avant** le `.`, et
     les schedulers sont des identifiants **insécables**. Le dev **refuse de prétendre** avoir comblé
     un trou qu'il n'a pas comblé et déclare le durcissement **prophylactique**, tout en identifiant
     l'angle mort **authentique** (`Nom(arg:`) là où il est **réel** et **réellement fermé**.
2. **Honnêteté de discipline exemplaire** : `z_widgets_purity_test.dart:228-270` **consigne que son
   premier jet mentait et que sa propre contre-preuve l'a démasqué** — et il a corrigé **le
   commentaire, pas le test**. Idem sur AC9(3) : *le code était juste, le test était faux* — il a
   renforcé **le test**. C'est exactement la discipline attendue. *(Le seul manquement est D12 : la
   même rigueur n'a pas été appliquée à la dartdoc de `z_hint_penalty.dart`, alors que sa mesure
   était déjà faite.)*
3. **SM-1 / AC10 — l'objectif produit n°1 — TENU et PROUVÉ par mesure indépendante** : **0
   reconstruction du contenu pour 100 frappes** (borné, indépendant de N), **focus conservé**, curseur
   en fin de texte (`baseOffset == 100`), **y compris avec le minuteur VISIBLE et tickant** — scénario
   plus hostile que celui du test livré. **La sonde n'est pas aveugle** : reproduire hors prod la
   surface fautive rend **100 + 1 = 101** — le chiffre du dev est **exact**. **N'y a pas été touché.**
4. **Isolation : PASS, 0 finding.** Le placement forcé par le graphe est respecté (loger les ports
   près de `ZFlashcardGenerationPort` créerait un **cycle**), les gardes sont **durcies** au lieu
   d'être dupliquées, barrels **strictement additifs** (52 insertions, **0 suppression**), aucun
   `pubspec` touché. **Rien changé.**
5. **La dette su-1 est soldée sans régression** : `'ok'`/`'lapse'` → l10n (`fallback:` restitue le
   texte à l'identique — les tests historiques `contains('lapse')` passent toujours) ; `fontSize: 12`
   → `textTheme.labelSmall` (respecte enfin le `textScaler`) ; `selectedQuality` **additif**.
6. **Deux diagnostics de code justes** : le bouton « Indice » recalculé **DANS** le
   `ValueListenableBuilder` (et non dans le `build()` de la surface, qui ne se rejoue pas — c'est
   tout l'objet de SM-1) ; et la séparation mesure/affichage du minuteur, **bonne réponse** à un
   `Stopwatch` non *fakeable* (conservée par le correctif D3/D4/D13).
7. **Sous-arbitrage « QCM sans aucun `isCorrect` » : RÉEL et en défense en profondeur** — le `{}=={}`
   qui aurait récompensé `maxQuality` à qui ne coche rien est **inatteignable par les deux bouts**.

### Incident `git checkout` — RIEN N'A ÉTÉ PERDU (consigné, rien « réparé »)

Vérification **exhaustive** par la lentille adversariale (confrontation de `git diff HEAD --
z_srs_config.dart` à la story su-1 et à `code-review-su-1.md`) **et** par l'orchestrateur : **tous** les
livrables su-1 sont présents après restauration — bornes `const`, les 3 asserts (dont `maxQuality == 5`
et `minQuality ∈ {0,1}`, D1 de su-1), `clampQuality` + dartdoc, `==`/`hashCode` étendus. Le seul absent
(`toString`) **n'a jamais été livré** par su-1 — **pas une perte**. Correctif D2 de su-1
(`z_sm2_scheduler.dart:60`) **intact** (autre fichier) ; `z_srs_config_test.dart` **non suivi** ⇒
structurellement **hors d'atteinte** d'un checkout.
⇒ **Aucune perte silencieuse. Rien n'a été « réparé ».** La leçon transverse (**jamais `git checkout`
dans cet arbre**) est appliquée : cette passe n'a utilisé **que** `cp` + SHA-256, vérifié après
**chaque** injection.

---

## Preuves R3 — injections REJOUÉES sur disque (rouge MESURÉ, jamais raisonné)

Protocole : sauvegarde `cp` + `SHASUMS.txt`, injection appliquée par script **avec `assert` de présence
du motif** (une injection qui ne s'applique pas produirait un « vert » **mensonger** — ce garde-fou a
effectivement attrapé **2 patterns manqués** après un reformatage), test ciblé, restauration `cp`,
**`sha256sum -c` vérifié OK après chaque injection**.

| # | Injection (le défaut EXACT, réintroduit) | Cible | Résultat |
|---|---|---|---|
| D1a | garde de fraîcheur retirée de `_submitWritten` | concurrency | 🔴 **ROUGE** (+11 **-1**) |
| D1b | `_resetForNewCard()` retiré de `didUpdateWidget` | concurrency | 🔴 **ROUGE** (+8 **-4**) |
| D2a | verrou one-shot retiré de `_submitWritten` | concurrency | 🔴 **ROUGE** (+11 **-1**) |
| D2b | « Je ne sais pas » : verrou **et** gating retirés | concurrency | 🔴 **ROUGE** (+6 **-1**) |
| D2c | V/F auto-soumis non one-shot | concurrency | 🔴 **ROUGE** (+11 **-1**) |
| D3 | `didUpdateWidget` ne ré-arme plus le ticker | timer | 🔴 **ROUGE** (+9 **-2**) |
| D5 | validateur rend `'required'` (défaut verbatim) | a11y | 🔴 **ROUGE** (+17 **-1**) |
| D5-bis | idem, **sur la forme corrigée** (closure) | hardcode scan | 🔴 **ROUGE** — *le trou de ma propre garde, mesuré puis fermé* |
| D6 | V/F : icône de correction retirée | qcm_vf | 🔴 **ROUGE** (+22 **-2**) |
| D6b | V/F : `Semantics.value` retiré | qcm_vf | 🔴 **ROUGE** (+23 **-1**) |
| D7 | QCM : retour à 2 icônes (choix effacé) | qcm_vf | 🔴 **ROUGE** (+22 **-2**) |
| D9 | `liveRegion` retiré de l'erreur d'indice | a11y | 🔴 **ROUGE** (+17 **-1**) |
| D10 | verrou d'indice retiré | concurrency | 🔴 **ROUGE** (+11 **-1**) |
| D11 | **divergence des 2 tables** (`multipleChoice => false`) | qcm_vf | 🔴 **ROUGE** (+23 **-1**) |
| **R3-I10c** | **tear-off → closure** — *l'injection qui restait VERTE (198/198)* | sm1 | 🔴 **ROUGE** (+6 **-2**) ✅ |
| plancher | remontée du plancher retirée de `zHintCeilingFloor` | hint_penalty | 🔴 **ROUGE** (+13 **-1**) |

**16/16 injections rouges.** Le MAJEUR R3 (**I10c**) est le seul dont l'inversion vert → rouge
**prouve** que le verrou est passé de **factice** à **réel**.

**Note sur D11** : avec le garde de routage en place, flipper `cloze`/`openQuestion` vers `true`
**n'échoue pas** — et c'est **correct** : le garde route alors vers `_submitLocal`, le port **n'est
pas appelé**, **AD-35 tient**. La protection est **composite** : le garde rend la 7ᵉ valeur **sûre**,
le test rend la **divergence des tables** détectable (prouvé par le flip `multipleChoice => false`).

---

## ⚠️ Écart introduit par cette passe — à arbitrer par l'orchestrateur (formatage)

**Transparence** : j'ai lancé `dart format` sur `packages/zcrud_session` et `packages/zcrud_flashcard`.
Le repo est **entièrement écrit à la main en style « short »** ; le SDK étant `^3.12.2`, `dart format`
applique le **style « tall »** et a reformaté **81 fichiers sur 103** — preuve que le projet **ne
gate pas** le formatage (`melos run verify` ne le vérifie pas, et 79 % du repo n'y est pas conforme).

- ✅ **Dommage collatéral ANNULÉ** : les **71 fichiers** appartenant à su-1/su-2 (et à d'autres
  stories) que je n'avais aucune raison de toucher ont été **restaurés à l'octet près** depuis la
  sauvegarde d'entrée (`cp`, jamais `git checkout`). Vérifié : seuls les **13 fichiers réellement
  visés** par cette passe diffèrent encore de la sauvegarde.
- 🟡 **Reste** : ces **13 fichiers** — que cette passe a de toute façon largement réécrits — sont en
  style **tall**, donc **incohérents** avec le reste du repo et avec un diff de revue plus bruyant.
  **Je ne les ai pas reformatés à la main** : rétro-convertir un fichier de prod de 1300 lignes à la
  main pour un gain **purement cosmétique** ferait courir un **risque de correctness** disproportionné,
  et les tests ne l'attraperaient pas s'il n'était que cosmétique. **Décision au owner** : soit
  laisser en l'état, soit `dart format` **repo-wide** (rend tout uniforme, mais c'est un changement
  large et non demandé), soit me demander une reconstruction fichier par fichier.

Fichiers concernés : `z_flashcard_answer_input.dart` · `z_answer_input_harness.dart` ·
`z_flashcard_answer_input_{a11y,fallback,qcm_vf,sm1,concurrency}_test.dart` ·
`z_flashcard_timer_test.dart` · `z_widgets_hardcode_scan_test.dart` · `z_hint_penalty.dart` ·
`z_hint_penalty_test.dart` · `z_flashcard_local_evaluation.dart` · `zcrud_flashcard.dart`.

---

## Fichiers touchés

**Prod (4)**
`packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart` (D1, D2, D3, D4, D5, D6,
D7, D8, D9, D10, D11, D13, F3, L2, LOW-6, R3-I10c) ·
`packages/zcrud_flashcard/lib/src/domain/z_hint_penalty.dart` (D12) ·
`packages/zcrud_flashcard/lib/src/domain/z_flashcard_local_evaluation.dart` (D11) ·
`packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (D11 — commentaire de barrel)

**Tests (9, dont 1 neuf)**
`z_flashcard_answer_input_concurrency_test.dart` **(neuf — 12 tests : D1, D2, D10)** ·
`z_answer_input_harness.dart` (`SlowEvaluationPort`/`SlowHintPort` — la fenêtre `await` est le seul
endroit où les défauts de concurrence existent) · `z_flashcard_answer_input_a11y_test.dart` (D5, D8,
D9, LOW-6, R3-I11b) · `z_flashcard_answer_input_qcm_vf_test.dart` (D6, D7, D11) ·
`z_flashcard_timer_test.dart` (D3, D4, D13, F3) · `z_flashcard_answer_input_sm1_test.dart`
(R3-I10c) · `z_flashcard_answer_input_fallback_test.dart` (R3 MEDIUM — plafond au repli) ·
`z_widgets_hardcode_scan_test.dart` (D5 — trou de garde) · `z_hint_penalty_test.dart` (D12 /
adversariale D4)

**Non touchés (et c'est délibéré)** : `zcrud_core` (**interdit**) · tout `pubspec.yaml` ·
`sprint-status.yaml` (**interdit** — propriété de l'orchestrateur) · la sonde SM-1 (**confirmée**) ·
les gardes d'isolation (**PASS**).
