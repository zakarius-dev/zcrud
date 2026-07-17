# Code-review su-10 — parcours d'étude assemblé (`example/`) — CORRECTIONS APPLIQUÉES

Story : `su-10-parcours-assemble-example`. Périmètre écrit : **`example/` SEUL** (aucun
`packages/` touché — les modifications `packages/` du `git status` sont le travail non committé
su-1..su-12 + l'autre workstream de revue parallèle). Écritures sérialisées, aucun `git checkout`,
aucun `dart format`.

## Verdict

**CHANGES REQUESTED → corrigé.** Le MAJEUR D1 (perte SRS silencieuse) est corrigé **par conception**
(voie (b) : une seule source de séquence) avec un **test porteur multi-cartes + lapse** falsifiable ;
les 4 MEDIUM (D2..D5) sont corrigés ; les écarts LOW/architecturaux sont consignés (aucune action).

## Vérif verte rejouée (scopée `example/`)

- `cd example && flutter analyze` → **RC=0 sur tous les fichiers su-10** (« no issues on su-10 files »).
  Restent SEULEMENT les 2 erreurs **pré-existantes** hors su-10 (`markdown_demo_test.dart`,
  `offline_demo_test.dart`, committées d83882e — dette epic EX, cf. consignation).
- `cd example && flutter test` des 7 fichiers su-10 (3 porteurs d'origine + 4 neufs/retouchés +
  boundary) → **RC=0, 23 tests, All tests passed** (srs 1 + modes 4 + ports 3 + sm1 2 + swiper 9 +
  surface 3 [+1 neuf] + boundary 1 ; total 23).

---

## D1 — MAJEUR — Perte SRS silencieuse (moteur cyclique ↔ swiper linéaire) — **CORRIGÉ**

**Mécanisme confirmé sur disque** : `ZStudySessionEngine` (spaced/learn) réinsère les lapses dans sa
file (`reduceGrade`) ⇒ curseur **dynamique** ; `ZSessionCardSwiper` (`isLoop:false`) a une file. Deux
curseurs indépendants ⇒ dès le 1ᵉʳ lapse `engine.current` ≠ carte affichée ⇒ le garde
`engine.current == cardId` sautait **silencieusement** toutes les notes suivantes.

**Voie retenue : (b) « une seule source de séquence » — et pourquoi.** La voie (a) (positionner le
curseur du moteur sur la carte du swiper avant de noter) exige une **API de positionnement que le
moteur n'expose pas** (`grade()` n'opère que sur `_state.current`, aucun `moveTo`) — l'implémenter
toucherait `packages/` (interdit ici, et défaut de conception d'API à porter par une story dédiée).
La voie (b) est donc la seule réalisable côté `example/` **et** c'est le patron « hôte correct » que
la dartdoc du swiper décrit déjà (« toute réussite rétrécit la file… c'était le chemin NOMINAL » ⇒ le
swiper est **fait** pour suivre la file du moteur).

**Implémentation** (`study_session_demo_screen.dart`) :
- `_currentStudyItem()` : en mode SRS, la carte **affichée ET notée** est **toujours** `engine.current`.
- `_gradeAndAdvance()` : sur `grade` réussi, `_queue = engine.state.queue` (le lapse y réapparaît en
  aval) et le swiper **remonte** sur son nouveau front (= `engine.current`) ; à l'épuisement du
  moteur, `_onStackEnd()` (latch) pousse la célébration.
- **Le garde est CONSERVÉ** (`engine.current == cardId`) : il tient désormais **par construction**
  (la carte affichée EST le front) — il protège encore contre la note sur la mauvaise carte (su-8)
  sans jamais diverger.

**Preuve que CHAQUE note atteint le SRS** — `study_parcours_srs_test.dart` (neuf) : session **learn de
3 cartes avec 1 lapse** (« Je ne sais pas » sur c0 → réinsertion → front=c1 ; puis 3 réussites) ⇒
**4 soumissions ⇒ `store.srsWrites == 4`** ET `store.srsById.keys ⊇ {c0,c1,c2}` (les 3 cartes
distinctes, dont c2 — précisément celle que l'ancien garde perdait) ⇒ célébration.
**R3 (rougir par comportement, joué sur disque)** : hôte pré-fix ré-injecté (SHA original
`2f58077d…`) ⇒ test **ROUGE** (après le lapse la carte reste figée « corrigée », la 2ᵉ soumission ne
trouve plus `zSubmit` ; `srsWrites` resterait à 1) ; hôte corrigé **restauré** (SHA `cf605d63…`).

---

## D2 — MEDIUM — Transition RÉELLE sélecteur→session jamais exercée — **CORRIGÉ**

`study_parcours_modes_test.dart` (neuf, groupe D2) : montage **SANS `autoStart`** (phase sélecteur,
comme un vrai utilisateur), on **tape** `ZSessionModeSelector.learnKey` ⇒ `_onStart` /
`zReviewModeForKind` s'exécutent ⇒ bascule en phase `studying` (le swiper apparaît, le sélecteur
disparaît). Le 1ᵉʳ arc d'AC1 est désormais prouvé par comportement (une dérive de câblage rougirait —
leçon su-2).

## D3 — MEDIUM — Seul `learn` exécuté ; whiteExam/list/cramming — **CORRIGÉ**

`study_parcours_modes_test.dart` (groupe D3) :
- **whiteExam BOUT-EN-BOUT** : `start → answer(×2) → submit → result` — score lu sur
  `ZSessionSummaryView.result` (`total==2`, `correct==1`), zéro exception. Le cycle de vie hôte de
  l'examen (seed+`start()`, `answer()` à la soumission, `submit()` sur `onStackEnd`, `state.result` au
  résumé) est réellement exercé.
- **`list`** (runtime linéaire) via le seam `autoStart` : atteint la fin, **`srsWrites == 0`** (AD-34,
  aucune porte dérobée SRS).
- **`cramming`** via `autoStart` : se déroule sans exception, **`srsWrites == 0`**.

**Justification list/cramming** (consignée) : `ZSessionModeKind` n'a que 3 valeurs
(learnNew/review/test → learn/spaced/whiteExam) ⇒ le **sélecteur** n'émet jamais list/cramming. Les
rendre sélecteur-atteignables changerait `ZSessionModeKind` (un `packages/`, interdit). La table
`_makeRuntime` doit rester **exhaustive** sur les 6 `ZReviewMode` (contrainte Dart) : on ne peut pas
« retirer » ces branches. Elles ne sont donc **pas mortes** mais **atteignables par le seam
`autoStart`** — et désormais **couvertes** par les 2 tests ci-dessus (dead-branch → test-seam-covered).

## D4 — MEDIUM — Garde anti-`/src/` ne scannait que `lib/` — **CORRIGÉ**

`study_parcours_public_surface_test.dart` : le scan itère désormais **`['lib','test']`** (AC1 nomme
les deux). Ajout d'un **test de falsifiabilité du détecteur** (`srcImportOf`) : il flaggue une ligne
`import 'package:zcrud_session/src/...'` synthétique (isNotNull), n'est pas déclenché par un barrel
public ni par un commentaire — preuve que la garde attraperait une vraie violation en `test/`.

## D5 — MEDIUM (doc) — Témoins `callCount` promis mais jamais assérés — **CORRIGÉ**

`study_parcours_ports_test.dart` (neuf) rend la dartdoc VRAIE sur disque (les invariants spine sont
désormais exercés au niveau du parcours) :
- **AD-35** : carte QCM et carte Vrai/Faux poussées dans le parcours ⇒ `evaluationPort.callCount == 0`
  (évaluées LOCALEMENT, le port advisory n'est jamais sollicité).
- **AD-36** : carte à indice stocké ⇒ 1ᵉʳ « Indice » sert le stock (`hintPort.callCount == 0`,
  texte affiché), 2ᵉ « Indice » appelle le port (`callCount == 1`) après épuisement.
Bonus (doc lens LOW) : la dartdoc de migration du screen mentionne désormais le seam
`ZFlashcardGenerationPort` (foyer `zcrud_study`, hors flux, fake reporté par couplage mindmap).

---

## Consignations (écarts CONFIRMÉS — aucune action, conformes à la disposition)

- **AC3 — fake `ZFlashcardGenerationPort` OMIS** : blocage architectural réel (le port ne vit que dans
  `zcrud_study/src`, dont le barrel refuse l'export = cycle ; `zcrud_study` hard-dep `zcrud_mindmap`
  interdit par AC10). Le parcours est **complet sans lui** (génération = flux su-9, amont). **Consigné**,
  aucune correction. Doc de migration du screen mise à jour pour pointer le seam (LOW doc).
- **SM-1 : PASS** (falsifiable, chemin markdown réel) — non touché ; les tests SM-1 restent verts sous
  la correction D1 (la frappe ne déclenche aucun `setState` d'hôte ; contrôle positif d'avance intact).
- **2 tests example pré-cassés** (`markdown_demo_test.dart`, `offline_demo_test.dart`, committés
  d83882e, hors su-10, hors périmètre) : **dette de l'epic EX** — fix trivial hors su-10
  (`field.controller!` + 2 stubs `syncEntries`/`applyMerged`). **Non corrigés** (hors périmètre,
  autre workstream possible).
- **Latch `onStackEnd` (tests-porteurs F1)** : tient **par construction** (`isLoop:false` ⇒ émission
  unique) ; la ré-émission/`cramming`-reboucle n'est atteignable que par seam de test. Hors des
  dispositions arbitrées D1..D5 — **consigné**, non traité dans ce périmètre.

## Fichiers touchés (tous `example/`)

- `example/lib/demos/study_session_demo_screen.dart` (D1 : `_currentStudyItem`, `_gradeAndAdvance`,
  `_onSubmitted` SRS, dartdocs migration/hôte).
- `example/test/study_parcours_swiper_test.dart` (resync test ré-outillé, falsifiable sous D1).
- `example/test/study_parcours_public_surface_test.dart` (D4 : scan lib+test + détecteur testé).
- `example/test/study_parcours_srs_test.dart` (**neuf**, D1 porteur).
- `example/test/study_parcours_modes_test.dart` (**neuf**, D2 + D3).
- `example/test/study_parcours_ports_test.dart` (**neuf**, D5).

**AUCUN fichier `packages/` écrit.**
