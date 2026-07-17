# Code-review — su-6 « sélecteur, streak, filtres »

**Story** : `_bmad-output/implementation-artifacts/stories/su-6-selecteur-streak-filtres.md` (16 ACs)
**Spine** : AD-46 · AD-14 · AD-10 · AD-13 · AD-34 · hérités AD-1..32 · `CLAUDE.md`
**Revue** : Workflow multi-agent à **7 lentilles** (prose-vs-code · AC5/AC12 · streak/temps · perf/aléa ·
a11y/l10n · adversariale · tests porteurs) + application des dispositions arbitrées par l'orchestrateur.
**Date** : 2026-07-17

---

## Verdict

**APPROUVÉ après corrections.** 0 HIGH. **2 MAJEUR** (D1, D2) + **1 MAJEUR découvert en cours de
correction** (ÉCART-1, cf. infra) + **4 MEDIUM** (D3, D4, D5, D6) : **tous corrigés**, chacun avec un
**test porteur prouvé rouge par injection**. **5 LOW + 1 LOW hors-liste** : corrigés (tous triviaux).
**1 MAJEUR reporté à décision owner** (ÉCART-2 : contraste 1,23:1 — hors dispositions, exige un
arbitrage de design).

Le fond de su-6 tient : le streak canonique, l'arithmétique de jour civil, les filtres purs, l'aléa
injecté, la source unique du seuil et l'arête `zcrud_session → zcrud_ui_kit` **résistent à l'attaque**.
Ce que la revue a mordu, c'est **ce que personne ne regardait** — et la corrélation « non testé ⇔
défectueux » s'est vérifiée à la lettre.

---

## 🔴 INCIDENT — pourquoi cette revue était le seul filet

L'agent `dev-story` est **mort sur une erreur API** en cours d'implémentation. L'agent de reprise a
déclaré **ne PAS avoir audité les 16 ACs** : **AC5** (persistance par le port existant) et **AC12**
(association QCM) n'étaient vérifiés **par personne**, ni les cas « date future » / « doublons-désordre »
(présents dans les *noms* de tests, jamais lus).

**Rattrapage effectué par la revue** : AC5 et AC12 ont été audités **ligne à ligne par 3 lentilles
indépendantes** ⇒ **CONFORMES** (détail au crédit, plus bas). Mais l'incident a laissé un angle mort
que personne n'avait couvert : **`ZTestFiltersDialog` — 240 lignes publiques exportées, ZÉRO test** —
et c'est précisément là que dormaient les deux MAJEUR. **L'absence de couverture n'était pas un risque
théorique : elle avait déjà laissé passer un défaut réel** (D2).

---

## RC RÉELS — vérif verte rejouée sur disque par le correcteur

| Commande | RC | Résultat |
|---|---|---|
| `dart run melos run analyze` (**repo-wide**) | **0** | `SUCCESS` — **0 error, 0 warning** |
| `dart run melos run verify` | **0** | **10 gates** verts (incl. `reserved-keys` A+B, `codegen-distribution`, `web`, `secrets`) |
| `flutter test` **par package, DEPUIS le package** (séquentiel ; `zcrud_generator` = `dart test`) | **0** | **23/23 packages verts** |

**Compteurs** — référence **4228** → **4248** (**+20**) :

| Package | Réf. | Après | Δ |
|---|---|---|---|
| `zcrud_session` | 441 | **456** | **+15** |
| `zcrud_study_kernel` | 358 | **361** | **+3** |
| `zcrud_flashcard` | 462 | **464** | **+2** |
| 20 autres | inchangés | inchangés | 0 |

*(+ `tool/reserved_keys_gate` : 120, hors compte des 23 packages.)* La ventilation **+15/+3/+2 = +20**
correspond exactement aux tests ajoutés : aucune régression, aucun test perdu.

**Intégrité de l'arbre** : `git status --porcelain` = **112** (valeur d'entrée, **inchangée**) ·
**0 sonde résiduelle** (`grep -rl zz_probe packages/ tool/` → **RC=1**) · `sprint-status.yaml`
**non touché** par la revue (son diff de 7 lignes est **antérieur**) · `packages/zcrud_core/`
**INTACT** (`git status --porcelain packages/zcrud_core/` → **vide**).
🚫 Aucun `git checkout`/`git restore` · aucun `melos run test` · aucun `dart format`.

---

# FINDINGS & DISPOSITIONS

## 🔴 D1 — MAJEUR — Deux gardes du seuil rendaient des verdicts **OPPOSÉS** — ✅ CORRIGÉ

**Fichiers** : `packages/zcrud_flashcard/test/z_mastered_threshold_single_source_test.dart:27-29,:60`
(**Garde A**) ↔ `packages/zcrud_session/test/z_quality_scale_single_source_test.dart:247-250`
(**Garde B**)

**Le défaut** : Garde A **INTERDIT** le motif `scale.max - 1` (« dérivation du seuil RECOPIÉE depuis
l'échelle — AD-46 ») ; Garde B le listait dans sa `const legitimate` et le **verrouillait VERT**
(`isEmpty`). Les deux se déclaraient pourtant « **le même critère**. Aucune ne duplique l'autre. »

**Scénario d'échec (JOUÉ, pas supposé)** : écrire `?? scale.max - 1` dans `z_session_summary_view.dart:374`
— `scale` **est en scope** (`:366`) — recrée **exactement** la seconde source que su-6/D2 déclare avoir
**REFUSÉE**. Alors : **Garde B verte** (sa contre-preuve l'**exigeait** — la corriger cassait son propre
test), **Garde A aveugle** (`Directory('lib')` est relatif à `zcrud_flashcard`), **zéro test de
comportement rouge** (`maxQuality` épinglé à `5` ⇒ `scale.max - 1 == config.masteredThreshold == 4`,
**ISO-COMPORTEMENTAL**). *Deux gardes qui se neutralisent sont pires qu'aucune garde : elles rassurent.*
Aggravant : la prose **clôt l'enquête** — elle dit au lecteur suivant qu'il n'a rien à vérifier.

**Correction** :
1. Garde B interdit désormais `scale.max - 1` **et** `maxQuality - 1` (les **régex identiques** à celles
   de Garde A ⇒ « le même critère » devient **vrai et vérifiable**) ;
2. sa contre-preuve `legitimate` porte la forme **sanctionnée** (`?? widget.config.masteredThreshold`),
   plus un `length - 1` d'index (anti-faux-positif) ;
3. **nouvelle contre-preuve** : `?? scale.max - 1` et `maxQuality - 1` **DOIVENT** être captés ;
4. les **portées réelles sont DÉCLARÉES des deux côtés** (tableau), différences comprises : Garde A =
   `lib/**` récursif auto-énumérant + recollage **par déclaration** ; Garde B = **liste figée** de 3
   fichiers + scan **ligne à ligne** (angle mort déclaré) ;
5. la prose fausse de Garde A (« le même critère ») est **remplacée par le récit du défaut**, et
   `z_srs_config.dart` (qui cite les deux gardes) est aligné.

**🔬 Test porteur (R3 — JOUÉ)** : injection `?? scale.max - 1` dans `z_session_summary_view.dart` :

| Garde | Avant correction | **Après** |
|---|---|---|
| Garde B (structurelle) | 🟢 **verte** (verrouillée à l'accepter) | 🔴 **ROUGE** — `SECONDE SOURCE D'ÉCHELLE détectée` |
| `z_session_summary_view_test.dart` (26 tests **comportementaux**) | 🟢 verte | 🟢 **verte** (26/26) |

⇒ La démonstration est **complète** : le défaut est bien **iso-comportemental** (les 26 tests de
comportement ne peuvent pas le voir), et la garde structurelle est **la seule** qui le voit. Elle a
désormais ce pouvoir ; elle ne l'avait pas.

---

## 🔴 D2 — MAJEUR — `ZTestFiltersDialog` : 240 lignes publiques, ZÉRO test, et le MAJEUR D1 de su-5 **RÉTABLI** — ✅ CORRIGÉ

**Fichiers** : `packages/zcrud_session/lib/src/presentation/z_test_filters_dialog.dart:180,:225` ·
`packages/zcrud_session/test/presentation/z_session_mode_selector_test.dart:317-334`

**3 lentilles sur 7 convergent.** Preuve d'absence (orchestrateur, `grep -rqF` sans pipe) :
`grep -rqF "ZTestFiltersDialog" packages/zcrud_session/test/` → **RC=1** — **aucun test**.

**Le défaut, PROUVÉ PAR SONDE** (arbre sémantique réel) : `label="Maîtrisées"` porté par le
`Semantics(label:)` **parent ET** par le nœud propre du `CheckboxListTile` (`title: Text(text)`) — sur
les **3 seaux** `ZMasteryLevel.values` **et chaque** source. TalkBack annonçait **« Maîtrisées,
sélectionné » puis « Maîtrisées »** : **chaque** filtre bégayait, sur **toute** la surface du dialog.
**Aggravant** : l'état coché ne vivait **que** sur le nœud parent — l'enfant, *celui qui a l'air d'être
la case*, n'exposait **aucun** état (`hasCheckedState=false`). C'est **littéralement le MAJEUR D1 de
su-5** (« Cartes, 8, Cartes — valeur : 8 »), re-commis dans un diff **dont la story cite la leçon**.

**Cause racine (deux verrous manquants, pas un oubli)** :
1. l'énumération AC14 couvrait les **4 tuiles du sélecteur** et **OMETTAIT celles du dialog — dans le
   MÊME diff** ;
2. son assertion `expect(node.label, isNotEmpty)` **ne peut pas voir** une fusion (un libellé doublé
   reste non vide) **ni** un littéral en dur (`label(context, key, fallback:)` rend le fallback non vide
   dans les deux cas). *Mesuré* : `label: 'Apprendre les cartes'` (français EN DUR) laissait le groupe
   **23/23 vert**, le scan de libellés **14/14 vert**, la suite **441/441 verte**.

**Correction** :
- **(a)** `_FilterToggle` (patron **unique** — les deux classes quasi-jumelles `_MasteryToggle`/
  `_SourceToggle` sont **fusionnées** : deux copies = deux endroits où corriger, et su-5 a démontré
  qu'on n'en corrige qu'un) porte `excludeSemantics: true` + **re-déclare tout ce que l'exclusion
  masque** : `checked:` (l'état — `checked`, pas `selected` : c'est une **case à cocher**) et `onTap:`
  (l'action — *exclure sans re-déclarer aurait été pire que le défaut*) ;
- **(b)** l'énumération AC14 est **étendue au dialog** dans **le même test** (AC14 interdit la garde
  parallèle) : `ZMasteryLevel.values` **énuméré**, sources, + les 3 contrôles de comptage ;
- **(c)** l'assertion est une **ÉGALITÉ EXACTE** contre des **libellés injectés par `ZcrudScope`**
  (sentinelles `L10N_*` qu'aucun fallback ne peut produire) ⇒ un littéral en dur **et** une fusion-dans-
  le-label rougissent ; **plus** un test R3 dédié qui **énumère les nœuds ENFANTS** ;
- **+** une suite de **comportement** (11 tests) : chaque bascule **TAPÉE** avec assertion du
  `ZFlashcardTestFilters` **REÇU par l'hôte** (payload entier), « Annuler » ⇒ `null`, ≥ 48 dp **énumérés**,
  RTL, `availableSources` vide.

**🔬 Tests porteurs (R3 — 4 injections JOUÉES)** :

| Injection dans le code de PROD | Résultat |
|---|---|
| `excludeSemantics` **retiré** du dialog | 🔴 **ROUGE** — *« annonce le filtre DEUX fois (su-5/D1 re-commis) »* |
| `_levels.add` ↔ `_levels.remove` **inversés** | 🔴 **3 ROUGES** (état coché + payload ×2) |
| « Valider » pope `widget.initial` au lieu du composé | 🔴 **4+ ROUGES** |
| *(réf. avant correction : chacune de ces mutations = **441/441 VERT**)* | — |

> **🔬 Nuance MESURÉE, importante** : sous l'injection « `excludeSemantics` retiré », **le test
> d'égalité exacte est resté VERT** — la double annonce du dialog se matérialise en **nœud ENFANT**, pas
> en label fusionné (contrairement au sélecteur, cf. ÉCART-1). **Seul** le test R3 qui énumère les
> enfants l'attrape. Les deux assertions sont donc **toutes deux porteuses, et non redondantes** : sans
> la seconde, la correction (b)/(c) aurait été un faux filet.

### Balayage EXHAUSTIF du motif (exigé par D2) — **7 sites `Semantics` dans le diff su-6**

| # | Site | État | Verdict |
|---|---|---|---|
| 1 | `_MasteryToggle` ×3 seaux | fusionnait + état muet | 🔴 **CORRIGÉ** (fusionné dans `_FilterToggle`) |
| 2 | `_SourceToggle` ×N sources | idem | 🔴 **CORRIGÉ** (idem) |
| 3 | `_ModeTile` ×3 options | **fusionnait** (mesuré) | 🔴 **CORRIGÉ** — cf. **ÉCART-1** |
| 4 | `ZStreakBadge` | **fusionnait** (mesuré) | 🔴 **CORRIGÉ** — cf. **ÉCART-1** |
| 5 | `_QuestionCountStepper` (neuf) | — | ✅ né gardé (`excludeSemantics` + `value:`) |
| 6 | `_CountAction` ×2 (neuf) | — | ✅ né gardé (`excludeSemantics` + `onTap:` + `enabled:`) |
| 7 | `Icon(semanticLabel: null)` (badge) | correct et délibéré | ✅ déjà sain |

**Tuiles/dialogs omis par l'énumération AC14 — total trouvé : 1 dialog entier = 4 tuiles omises**
(3 seaux + 1 source ; **N+3** en général), **+ 4 tuiles ÉNUMÉRÉES mais NON GARDÉES** (assertion
`isNotEmpty` aveugle) — dont **4/4 réellement défectueuses**. L'énumération couvre désormais **11 clés**
(4 sélecteur + 7 dialog), toutes à l'**égalité exacte**.

---

## 🔴 D3 — MEDIUM — `_questionCount` : état mutable **MORT** ⇒ FR-SU12 non configurable — ✅ CORRIGÉ

**Fichier** : `z_test_filters_dialog.dart:74,:82,:146`

**Le défaut** : `late int _questionCount` écrit **une fois** dans `initState`, relu au `pop`, **jamais
réassigné** ; `grep -qE "Slider|TextField|Stepper|DropdownButton"` → **RC=1** : **aucun contrôle de
saisie**. Le PRD FR-SU12 exige mot pour mot « **nombre de questions** (défaut 10, tirage aléatoire si
excédent) … **+ dialog de configuration** » — le dialog de configuration ne configurait donc **pas** ce
que FR-SU12 nomme **en premier**.

**Scénario d'échec** : l'apprenant ouvre « Test », veut **20** questions ⇒ **impossible**. Le dialog rend
**toujours** `initial.questionCount`. La fonction pure `zDrawQuestions` **sait** tirer 20 (prouvé,
`z_flashcard_filters_test.dart:311-378`) — **seul le chemin d'accès utilisateur manquait**. Un `late int`
mutable dont l'unique rôle est le pass-through **donne l'apparence** de la configurabilité : une
fonctionnalité morte sur son chemin documenté. **D2 garantissait que rien ne la voyait.**

**Correction** — le **contrôle est ajouté** (plutôt que rendre le champ `final` et consigner l'écart :
`zDrawQuestions` existait déjà, seule l'affordance manquait) : `_QuestionCountStepper` borné, **bornes
INJECTÉES** (`minQuestionCount: 1` / `maxQuestionCount: 100` — jamais des littéraux enfouis dans le
`build`), valeur portée par `Semantics(value:)`, boutons **désactivés aux bornes et annoncés comme tels**
(`enabled:`), cibles ≥ 48 dp, libellés d'**action** distincts du libellé du champ. `_clampCount` borne
**dès `initState`** ⇒ un `initial` hors bornes (AD-10) ne throw ni ne piège le stepper.

**🔬 Test porteur (R3 — JOUÉ)** : `_setCount` neutralisé en `void _setCount(int value) {}` (le
pass-through mort restauré) ⇒ 🔴 **2 ROUGES** (« le stepper change le payload REÇU », « le stepper est
BORNÉ »). Le test assert le `questionCount` **reçu par l'hôte** (12), jamais la présence d'un widget.

---

## 🔴 D4 — MEDIUM — Le compteur de série **ne survit pas à la localisation** — ✅ CORRIGÉ

**Fichier** : `z_streak_toast.dart:88-92` (`z_localizations.dart:288-296`)

**Le défaut** : `label(BuildContext, String key, {String? fallback})` résout
`scope → locale → _enLabels → fallback` et **rend la chaîne telle quelle** — **aucune** substitution de
paramètre, **aucune** pluralisation. Le `$current` n'existait donc que dans le **fallback EN DUR**,
c'est-à-dire **uniquement quand la localisation échoue**.

**Scénario d'échec** : une app fournit `zcrud.study.streak.incremented` via `ZcrudScope.labels` — **la
raison d'être de la clé** — p. ex. `'Streak'`. `label()` rend `'Streak'` et **le nombre disparaît
silencieusement** : aucune exception, aucun test rouge. L'apprenant d'une app localisée **ne voit jamais
sa série**, alors que **FR-SU11 fait du compteur *le* contenu du toast**. Défaut **latent** aujourd'hui
(`_enLabels` ne porte pas la clé) et **non gardé** (`expect(message, isNotEmpty)`, test `:443` — un
message réduit à `'Série en cours'`, à `''`, ou à la clé brute restait vert).

**Correction** — le patron correct existait **dans la même story** (`z_streak_badge.dart:63-66,106` :
libellé **statique localisable** + nombre dans un **canal séparé**). Un toast n'ayant qu'un canal, la
décomposition équivalente est : libellé **statique** issu de `ZcrudLabels` (`fallback: 'Série en cours'`)
**+** nombre **concaténé HORS de `label()`** (`_withCount`, séparateur sans lettre ⇒ rien à traduire).
Le compteur survit désormais à **toute** traduction.

**🔬 Tests porteurs (R3 — JOUÉ)** : `isNotEmpty` → `contains('4')` sur le test existant, **+ un test neuf**
qui **injecte une traduction réelle** (`'Streak'`) et exige `contains('Streak')` **ET** `contains('4')`.
Injection : retour au `fallback: 'Série de $current jours'` ⇒ 🔴 **ROUGE** (« le compteur ne survit pas
à la localisation »).

---

## 🔴 D5 — MEDIUM — AC12 : le test compare des `Set`, l'AC exige un **MULTISET** — ✅ CORRIGÉ

**Fichier** : `z_flashcard_filters_test.dart:389-390`

**Le défaut** : `Set<String> pairs(...) => cs.map(...).toSet();` — nommé « **Multiset** des PAIRES »,
mais `toSet()` **écrase les doublons**.

**Scénario d'échec** : soit `[A|false, A|false, B|true]`. Une implémentation rendant
`[A|false, B|true, B|true]` (un choix **perdu**, un **dupliqué**, **deux** bonnes réponses là où il n'y
en avait qu'une) passait **`hasLength(3)` ET** l'assertion de paires. Le QCM aurait affiché **deux**
bonnes réponses, et `ZEvaluation` (égalité ensembliste stricte, `z_flashcard_local_evaluation.dart:124`)
aurait noté **faux** l'apprenant n'en cochant qu'une. Le cas « **deux choix partageant un `content`** »
— **nommément signalé par la story** (`ZChoice` n'a **aucun `id`**) — n'était **jamais** testé.

**Défaut LATENT** (le Fisher-Yates échange sur une copie : il ne peut ni perdre ni dupliquer) ⇒
**correction du TEST seul, pas du code** — conforme à la disposition.

**Correction** : `pairs()` rend une `List..sort()` (**vrai multiset**) ; **+ un cas à `content`
dupliqué** (celui que la story exige) ; **+ une contre-preuve R3** qui exhibe la perte+duplication
compensée et démontre qu'un `Set` **et** `hasLength` la laissent passer.

**🔬 Test porteur (R3 — JOUÉ)** : `pairs()` remis en `toSet()` ⇒ 🔴 **ROUGE** (« une PERTE + une
DUPLICATION simultanées rougissent — un `Set` les laisserait passer »).

---

## 🔴 D6 — MEDIUM — a11y / l10n : les 2 points — ✅ CORRIGÉS

### (a) Namespace l10n **orphelin** `zcrud.action.*`

**Fichier** : `z_test_filters_dialog.dart:139,:152`. `grep -rln "zcrud\.action\."` → **ce fichier, et lui
seul** : le namespace était **inventé par su-6**.

**Scénario d'échec** : `_enLabels` porte **déjà** `'cancel': 'Cancel'` / `'confirm': 'Confirm'`, et le
patron du dépôt est la **clé nue** (`z_color_field_widget.dart:478`). Une app **anglaise** n'ayant pas
injecté de `ZcrudLabels` study : `'zcrud.action.cancel'` **rate** `_enLabels` ⇒ retourne le fallback
**FRANÇAIS**. Le dialog affichait **« Annuler »/« Valider »** au milieu d'une UI en
**« Cancel »/« Confirm »**. Avec la clé nue, l'anglais tombe juste **gratuitement**.

**Correction** : `label(context, 'cancel')` / `label(context, 'confirm')`.
**Preuve** : `grep -rn "zcrud\.action\." packages/ --include="*.dart"` rend 2 hits — **tous deux dans
ma propre PROSE** (le commentaire qui explique l'interdit) ; le grep **discriminant** (hors lignes de
commentaire) rend **RC=1**. *(Le piège LOW-2 reproduit : je le signale au lieu de citer un « RC=1 » qui
ne se reproduirait pas.)*

> **Faux positif écarté (honnêteté)** : les clés `zcrud.study.*` ne sont enregistrées nulle part — ce
> **n'est PAS un finding** : c'est la **norme établie** de su-1..su-5 (le package embarque un `fallback:`
> français, l'app injecte ses `ZcrudLabels`). Seul `zcrud.action.*` était fautif, **parce qu'un
> équivalent anglais existait déjà sous une autre clé**.

### (b) `excludeSemantics: true` — **instruit** : que masque-t-il ?

La question posée par la disposition est la bonne, et la réponse est **« pas rien »** — d'où une
re-déclaration **explicite** partout, jamais une exclusion nue :

| Site | Ce que l'exclusion MASQUE | Traitement |
|---|---|---|
| `_FilterToggle` | l'**état coché** + l'**action de tap** du `CheckboxListTile` | **RE-DÉCLARÉS** (`checked:` + `onTap:`) — sinon le filtre serait annoncé mais **inactionnable** au lecteur d'écran |
| `_ModeTile` | le `onTap` de l'`InkWell` + le nœud de l'**anneau** (« progression, 30/60 ») | `onTap:` **RE-DÉCLARÉ**. L'anneau est une **redite décorative** des nombres que la tuile annonce déjà (`correct` = la file = le `value`) ; seul le **total du backlog** quitte le canal a11y — hors contrat d'AC7 (« Apprendre +N » annonce N), **visible à l'œil**, et porté par le bilan de session. En contrepartie, le nœud cesse d'être le charabia mesuré (cf. ÉCART-1). **Arbitrage assumé et consigné dans le code.** |
| `ZStreakBadge` | le `Text('7')` (redondant) | **rien de nécessaire** : le nombre reste dans `value:` (a11y) **et** dans le `Text` (visuel) |
| `_QuestionCountStepper` / `_CountAction` | le `Text` redondant / l'action du bouton | `value:` + `onTap:` + `enabled:` **RE-DÉCLARÉS** |

> ⚠️ **Une correction a11y qui casse l'a11y serait pire que le défaut.** C'est le patron du cœur
> (`z_date_field_widget.dart:100-105` : `excludeSemantics: true` **avec** `button:`/`label:`/`value:`/
> `onTap:`) et de su-5 — appliqué ici sans raccourci.

---

## 🟡 LOW — tous corrigés (triviaux)

| # | Fichier | Défaut | Disposition |
|---|---|---|---|
| **LOW-1** | `z_srs_config.dart:140-142` | Citation de grep **auto-réfutante** : « aucun codegen — **grep RC=1** » rend **RC=0**, la prose contenant elle-même le motif. **Le fond est vrai** ; c'est la preuve qui ne se reproduit pas — un agent qui la rejoue conclut l'inverse. | ✅ **Prose corrigée** : commandes **discriminantes** ancrées hors prose (`grep -E "^\s*@ZcrudModel"` → RC=1 ; `^part ` → RC=1 ; aucun `.g.dart`). |
| **LOW-2** | `z_study_streak.dart:196-197` ↔ `z_advance_streak.dart:190` | « `current` **jamais négatif** — garanti par `zAdvanceStreak` » **FAUX** : la branche `incremented` fait `current.current + 1` **sans plancher**. Ctor `const` **sans assert** (délibéré, AD-10) + `copyWith` public ⇒ `copyWith(current: -5)` + J+1 → **`-4`**, **affiché par le badge** et annoncé (`Semantics(value: '-4')`). | ✅ **Plancher AJOUTÉ** (pas seulement la prose) : l'invariant devient **VRAI sur tous les chemins**. Portée honnête déclarée (un négatif reste *constructible* en mémoire ; il ne peut ni **naître** d'une désérialisation ni **survivre** à un `zAdvanceStreak`). |
| **LOW-3** | `z_session_mode_selector.dart:178-188` | « elle ne démarre rien » **deux lignes au-dessus** de `onStart(test, [])`. Comportement **correct et verrouillé** par test (`:136`) — c'est la **prose** qui est ambiguë (un hôte câblant `onStart` sur « naviguer » recevrait dialog **ET** démarrage). | ✅ **Reformulé** : « elle ne produit **aucune file** — l'hôte reçoit `onStart(test, [])` **et** l'ouverture du dialog ». |
| **LOW-4** | `z_flashcard_filters.dart:286` | `zShuffleChoices` sans appelant de prod (**assumé par D7/AD-33** — su-10 câble) mais le **contrat `copyWith(choices:)`** que l'hôte doit respecter n'était documenté **nulle part** (`grep -rq "copyWith(choices" packages/` → RC=1). | ✅ **Contrat documenté** (avec l'exemple de couture) + **⚠️ porté au ledger su-10** : si le mélange n'est jamais câblé, **aucun test ne rougira** et le QCM présentera éternellement la bonne réponse à la même position — su-2 *par omission*. |
| **LOW-5** | `z_study_streak_test.dart:19-20` | Repli de test qui **se déguise en résultat attendu** : `days[at] ?? '<inconnu>'` ⇒ `null` ⇒ branche AD-10 « horloge folle » ⇒ `alreadyCountedToday` — soit **exactement** l'issue qu'assertent 5 tests (même jour, 25 h intra-jour, **date future**, **idempotence**, **désordre**). Un `at:` à qui l'on ajoute des millisecondes fait rater le lookup : le test **reste VERT en ne testant plus rien** du jour civil. | ✅ **Repli rendu BRUYANT** (`StateError`) + **contre-preuve R3** du harnais lui-même. |
| **LOW-6** *(hors liste — adversariale LOW-1)* | `tool/reserved_keys_gate/lib/src/registrars.dart:241-271` | La justification « sonde NON MUETTE … un `toMap()` qui les écraserait **ROUGIRAIT** » **sur-promet** : sur un kind de `kNonExtensibleKinds`, `assertExtraClean` et `assertUnknownKeyRoundTrip` font **early-return** ; seule `assertEncodedClean` tourne, et elle n'inspecte **que** les clés réservées. `{'current': 0, 'best': 0}` laisserait le gate **tout aussi vert**. Impact réel **nul** (la sonde est correcte) — mais c'est le « dartdoc rassurant » **dans le fichier du gate anti-vacuité**. | ✅ **Portée ramenée au vrai** (le round-trip est prouvé par `z_study_streak_test.dart`, **pas ici**). |

---

# ⚠️ ÉCARTS aux dispositions arbitrées

## 🔴 ÉCART-1 — MAJEUR — « Le sélecteur, lui, est sain » est **FAUX** (mesuré)

Les dispositions portaient au crédit : « *Contre-vérifié loyalement : le sélecteur, lui, est **sain** ⇒
« non testé ⇔ défectueux » est **exact** ici.* » **Cette contre-vérification était erronée** — et je ne
l'ai découvert que parce que la correction D2(c) (assertion d'**égalité exacte**) a **rougi sur le
sélecteur**. Sonde de l'arbre sémantique **réel** (déposée, mesurée, **supprimée** — preuve infra) :

```
zModeLearnNew -> label=L10N_LEARN  value=1  childCount=1
   CHILD label=progression⏎1/1⏎L10N_LEARN⏎1
zModeReview   -> label=L10N_REVIEW⏎L10N_REVIEW⏎1   childCount=0
zModeTest     -> label=L10N_TEST⏎L10N_TEST         childCount=0
zStreakBadge  -> label=L10N_STREAK⏎3   value=3     childCount=0
```

**Les 4 tuiles du sélecteur étaient défectueuses** — pas 0 :
- « À réviser » annonçait **« À réviser, À réviser, 12 — valeur : 12 »** : libellé **DOUBLÉ** *et*
  **compte CONCATÉNÉ AU LABEL** — c'est-à-dire **exactement** ce que le commentaire du code déclarait
  impossible (« *Le NOMBRE passe par `value` : **jamais concaténé dans le label*** »). Une prose qui dit
  le contraire du code, sur le puits que la garde ne voit pas ;
- le badge annonçait **« série en cours 3, 3 »** ;
- « Apprendre » — **la seule tuile à porter un `leading`** — avait un nœud **parent propre** : la
  duplication s'était déplacée dans son **nœud ENFANT**.

**Pourquoi la lentille s'est trompée** : sa sonde n'a lu que **le parent** de la **seule** tuile dont le
parent est propre. **Méthode** : une sonde qui ne lit qu'un nœud d'un seul cas ne prouve rien d'un motif.
La lentille a11y (F5), qui annonçait la double annonce **sur les 3 widgets**, avait **raison** ; c'est la
contre-vérification qui l'a écartée à tort.

**Disposition** : **CORRIGÉ** dans le même geste que D2 (balayage du motif exigé par la disposition
elle-même) — `_ModeTile` et `ZStreakBadge` reçoivent `excludeSemantics: true` + `onTap:` re-déclaré.
**Test porteur** : c'est l'assertion d'égalité exacte de D2(c) qui l'a **fait rougir** (`Expected:
'L10N_REVIEW'` / `Actual: 'L10N_REVIEW\n'`), et qui le garde. Re-sondé après correction : **4 nœuds
propres, `childCount=0`, label = le libellé injecté, valeur dans `value:`**.

## 🟠 ÉCART-2 — MAJEUR **NON corrigé** — contraste **1,23:1** : décision de design requise

**Hors dispositions** (la lentille a11y le classait **F1/MAJEUR** ; il n'a pas été arbitré). **Je ne l'ai
pas corrigé** : le remède est un **changement de design visuel** que l'orchestrateur n'a pas sanctionné,
et le corriger en silence serait un dépassement de périmètre.

**Fichiers** : `z_streak_badge.dart:93` (flamme) · `:117` (**le nombre du streak**) ·
`z_session_mode_selector.dart:271` (le compte des 3 tuiles) — **MOTIF ×3**.

**Le défaut** : `pair.color` est un rôle de **FOND** (`z_color_key_resolver.dart:61-65` : « *Couleur de
**fond** (rôle `*Container`/surface)* » ; `onColor` = « *premier plan lisible sur [color]* »). Les 3 sites
le peignent en **PREMIER PLAN**, sur une surface **non peinte** (`grep -qE "Container|DecoratedBox|
ColoredBox|BoxDecoration|Material\("` sur les 2 fichiers → **RC=1** : **aucun fond**). Mesuré sous le
harnais des tests : **1,23:1** (`primaryContainer` `#EADDFF` sur `surface` `#FEF7FF`) — WCAG exige
**4,5:1**. **1,23:1 = invisible.**

**Scénario d'échec** : **AC7 est mis en échec une SECONDE fois.** Le premier jet annonçait le nombre sans
le dessiner ; celui-ci le dessine **dans une couleur qu'on ne voit pas**. *Résultat à l'écran :
identique.* Et la garde qui avait attrapé le `Colors.red` est **structurellement incapable** de voir son
remplaçant (elle ne rejette que les **littéraux** `Colors.*`/`Color(0x` — `pair.color` la satisfait) ;
`find.text('7')` non plus (il observe l'**arbre de widgets**, pas les **pixels**).

**Recommandation** (au choix owner) : peindre un fond `pair.color` + contenu en `pair.onColor` (patron
**établi** : `z_session_quality_breakdown.dart:174-177`, `z_tag_chips.dart:136-141`,
`z_annotation_panel.dart:146-148`) — **ou** un rôle de premier plan (`onSurface`). 🚫 **Ne pas** basculer
sur `pair.onColor` **sans fond** : ça marcherait (8,87:1) **par coïncidence**, pas par contrat.
**Garde à ajouter** : une assertion sur la couleur **rendue** (`tester.widget<Text>(...).style?.color`)
comparée au rôle attendu — le puits « rôle de couleur **mal employé** » n'est couvert par **rien**
aujourd'hui. *(Contre-argument consigné : `z_study_progress_rings.dart:127` peint aussi avec
`pair.color`, mais un anneau est une **forme pleine** — et le fichier est **committé, hors diff su-6**.)*

## 🟡 ÉCART-3 — MEDIUM `FINDING 2` (tests porteurs) **non corrigé**

`z_session_mode_selector.dart:147-159` — l'**anneau de progression** d'AC7 n'est prouvé par **aucun**
test (`grep -q "ZStudyProgressRings\|ZProgressRingsData"` sur le test du sélecteur → **RC=1** ; sa
suppression intégrale laissait **441/441 VERT**). **Hors dispositions** ; **et la correction D6(b)
change le sujet** : l'anneau est désormais **hors du canal a11y** de la tuile (arbitrage consigné
ci-dessus). **Justification du report** : asserter le `ZProgressRingsData` **exact** (60 cartes, lot 30 ⇒
`total: 60, correct: 30, ratio: 0.5`) reste souhaitable, mais la **sémantique du ratio** est elle-même
non arbitrée (`learnBatch.length / neverLearned.length` = la **part du backlog couverte par le lot**,
pas une « progression d'apprentissage ») — la fixer par test **graverait une intention que personne n'a
tranchée**. ⇒ **À porter au ledger** avec la décision de design d'ÉCART-2, qui touche le même widget.

---

# ✅ Points CONFIRMÉS — portés au crédit de la story

Consignés parce qu'un rapport qui ne liste que ses trouvailles laisse croire que le reste n'a pas été regardé.

- **AC5 — CONFORME** (vérifié ligne à ligne par **3 lentilles**) : port **EXISTANT**
  `ZStudyRepository<ZStudyStreak>` **étendu** (jamais une copie ⇒ garde **structurelle** : le fichier ne
  compilerait plus si le port cessait de servir `ZStudyStreak`), **aucun port neuf**, `Left(ZFailure)`
  sur les 3 familles **jamais un throw**, `save` `@nonVirtual` **non contourné**, AD-10 **démontré**
  (`current == 7` survit à l'échec de persistance). 🔴 **Espion prouvé branché** : **1 appel** sur le
  chemin nominal (`:143`) **AVANT** d'asserter **0** (`:221`) — le « 0 » n'est pas infalsifiable.
- **AC12 — CONFORME sur l'association** : Fisher-Yates sur les **objets `ZChoice` entiers** ⇒ la paire
  `(content, isCorrect)` est **soudée par construction** ; **aucun index de bonne réponse séparé** à
  désynchroniser. Chaîne vérifiée de bout en bout : affichage (`z_flashcard_answer_input.dart:881-906`)
  et correction (`z_flashcard_local_evaluation.dart:78-84`) lisent **la même liste** ; le widget n'accepte
  pas de `List<ZChoice>` séparée (`:123`) ⇒ la désynchronisation est **structurellement impossible via
  l'API publique**. **Le piège du mélange d'index est ÉVITÉ.**
- **Jour civil / DST — PASS** : la classe de bug est **structurellement hors d'atteinte** (aucune
  `Duration`, aucun `difference`, aucun `DateTime.now()` — arithmétique entière de **Hinnant**). Les
  tests DST embarquent l'implémentation **INTERDITE** en **contre-preuve** (`_naiveOutcomeByElapsed`,
  soumise aux **mêmes** assertions) : le bug est **exhibé**, pas supposé. Une lentille a **rejoué la
  transcription en Python sur 70 000 jours (1887→2079) : 0 divergence**, bornes séculaires comprises
  (2100-02-28→03-01). « Date future » et « doublons/désordre » sont **porteurs**.
- **AC8 O(1) — PASS, exemplaire** : compte d'**opérations** (aucun `Stopwatch`), N=200 **et** N=1600,
  `k`/`N` **littéraux du test**, sonde prouvée **branchée** (`reads > 0`), **plus** une référence
  délibérément **O(n²)** soumise à la **MÊME** assertion et qui **DOIT échouer**, **plus** un test
  d'équivalence qui lui interdit d'être lente « parce qu'elle fait n'importe quoi ».
- **AC9 — la meilleure garde de l'epic** : le seul défaut **iso-comportemental** de la story est attrapé
  par la **seule** garde qui pouvait l'attraper — **mesuré** (su-5 reste 26/26 vert sous l'injection).
- **Aléa, filtres purs, AD-46, robustesse AD-10 — PASS** (0 finding). `zApplyTestFilters` **délègue** à
  `matches` (jamais `selectFrom` : le plafond doublonné est évité) ; « deux graines ⇒ deux sous-ensembles »
  est **le seul** test que `take(count)` casse.
- **Arête `zcrud_session → zcrud_ui_kit` — JUSTIFIÉE** sur les 4 axes attaqués : le spine exige le seam
  réutilisé (`ZToaster`/`ZToasterScope`) — **un port local aurait été la violation** ; `zcrud_ui_kit` =
  `zcrud_core` + Flutter SDK (**zéro tiers**) ; `graph_proof.py` **RC=0** (53 arêtes, 23 nœuds,
  **ACYCLIQUE**, **CORE OUT=0**).
- **AD-34 respecté** : **aucun moteur touché** (mtimes vérifiés — `z_study_session_engine.dart` et
  `z_srs_quality_buttons.dart` sont **antérieurs** ⇒ su-4/su-5). **su-7/su-8/su-9/su-10 : rien.**
- Le motif d'origine de `z_streak_badge.dart` est **réellement soldé** (le `Colors.red`, le renvoi mort
  vers un fichier **jamais existé**, le `toMap`/`copyWith` manuels = seconde source). **Le HIGH de su-1
  est soldé** : `clampQuality` a **5 sites d'appel réels**.
- **Auto-critique consignée dans le code : exacte, pas décorative** — su-6 utilise la prose pour
  **s'accuser** là où su-1..su-3 l'utilisaient pour **couvrir**. Les 2 citations de lignes testées
  (`z_choice.dart:25-40`, `z_study_session_selector.dart:41-49`) sont **exactes au numéro près**.
- **La suite de tests est jugée la plus rigoureuse de la série** (lentille R3 : **12 injections sur 14
  rougissent pour la BONNE raison** — su-2 : 3/15 vertes). **Aucun espion débranché.** AC3 **nomme ses
  limites** au lieu de les masquer.
- `zShuffleChoices`/`zApplyTestFilters` **non câblés** = **conforme au périmètre** (D7/AD-33 : le parcours
  assemblé est **su-10**). **Non câblés par cette revue.**

---

## Hygiène de la correction

- **Sonde** : `packages/zcrud_session/test/presentation/zz_probe_su6_tree_test.dart` — créée, exécutée
  **seule**, **supprimée**. Preuves : `ls … | grep -c zz_probe` → **0** ; `grep -rl "zz_probe"
  packages/ tool/` → **RC=1** ; `git status --porcelain | grep zz_probe` → **RC=1**.
  *(La sonde d'une lentille voisine, `zz_probe_semantics_test.dart`, signalée comme résiduelle par
  2 rapports, était **déjà absente** à ma prise en main — vérifié.)*
- **Injections R3** : **8**, chacune `cp` → mutation → test ciblé → constat → restauration.
  **`sha256sum -c` → 6/6 OK** après restauration. **Aucune** n'a produit d'erreur de compilation (les
  rouges sont **comportementaux**, pas des `Error:`/`Failed to load`).
- 🚫 Aucun `git checkout`/`git restore` (su-1..su-6 **non committés**) · aucun `melos run test` · aucun
  `dart format` · **`sprint-status.yaml` non touché** · **`zcrud_core` non touché** (`git status` vide).
- Toute preuve d'absence par `grep -q` **sans pipe** ; `grep -F` sur tout symbole `$`/codegen ;
  `flutter test` **DEPUIS le répertoire du package** (les gardes utilisent `Directory('lib')` **relatif** :
  lancer depuis la racine produit **26 faux échecs**).

## Fichiers modifiés par la correction — 14

**Production (8)** : `zcrud_session/lib/src/presentation/{z_test_filters_dialog, z_session_mode_selector,
z_streak_badge, z_streak_toast}.dart` · `zcrud_flashcard/lib/src/domain/{z_srs_config,
z_flashcard_filters}.dart` · `zcrud_study_kernel/lib/src/domain/{z_advance_streak, z_study_streak}.dart`
**Tests/outillage (6)** : `zcrud_session/test/z_quality_scale_single_source_test.dart` ·
`zcrud_session/test/presentation/z_session_mode_selector_test.dart` ·
`zcrud_flashcard/test/{z_mastered_threshold_single_source_test, z_flashcard_filters_test}.dart` ·
`zcrud_study_kernel/test/z_study_streak_test.dart` · `tool/reserved_keys_gate/lib/src/registrars.dart`

## Ledger — à porter à su-10 / décision owner

1. **ÉCART-2 (MAJEUR)** — contraste **1,23:1** sur 3 sites : décision de design + garde de couleur rendue.
2. **ÉCART-3 (MEDIUM)** — anneau de progression non gardé + **sémantique du ratio non arbitrée** (même widget qu'ÉCART-2).
3. **LOW-4** — câbler `zShuffleChoices` en su-10 : **aucun test existant ne rougira** s'il est oublié (su-2 *par omission*).
