# Code-review — su-5 « Écran de fin + feedback pédagogique »

**Story** : `su-5-ecran-fin-feedback-pedagogique.md` (11 ACs) · **Package** : `zcrud_session` (SEUL)
**Spine** : AD-46 (échelle 0..5, seau « mauvais » = q0-2) · AD-10 · AD-13 · AD-8 · hérités AD-1..32 · `CLAUDE.md`
**Revue** : Workflow MULTI-AGENT à 6 lentilles (AD/données · dép. tierce · a11y/motion · adversariale · robustesse/SM-1 · tests porteurs)

## VERDICT : **CHANGEMENTS APPLIQUÉS — story VERTE, prête pour `done`**

**2 MAJEURS + 5 MEDIUM corrigés** (aucun reporté), **4 LOW corrigés**, **4 LOW consignés**.
**Aucun HIGH.** Aucun MEDIUM justifié en report : **tous ont été corrigés dans le périmètre**.

Le code livré par le dev était **correct sur le fond** : les 6 pièges du paquet `confetti` réellement
neutralisés, les deux animations réelles, le VO persisté intact, les chiffres affichés vrais. Les
défauts corrigés ci-dessous sont **un défaut a11y réel** (D1) et **six trous de garde** — dont deux
rendaient une garde **falsifiable** (D2, D4).

---

## RC RÉELS — vérif verte rejouée sur disque

| Commande | RC | Résultat |
|---|---|---|
| `dart run melos run analyze` (**repo-wide**) | **0** | `SUCCESS` |
| `dart run melos run verify` | **0** | incl. gate `serialization-compat` (VO intact) |
| `flutter test` **par package, séquentiel** (`zcrud_generator` = `dart test`) | **0** | **23/23 packages verts — 4097 tests** |

**Compteurs** : référence **4076** → **4097** (**+21 tests**). `zcrud_session` **397 → 418** (+21) ·
`zcrud_flashcard` **399 → 399** (**inchangé — aucune régression**).
Ventilation des +21 : confinement +3 · quality-scale +5 · summary-view +9 · feedback (domaine) +4.

**Intégrité de l'arbre** : `git status --short` = **94** (inchangé, aucun fichier nouveau non prévu) ·
**0 sonde résiduelle** · `grep -c confetti packages/zcrud_flashcard/pubspec.yaml` = **0** ·
`zcrud_core` et `z_study_session_result.dart` (**VO persisté**) : `git status` **vide = INTACTS**.
🚫 Aucun `git checkout`/`restore` · aucun `melos run test` · aucun `dart format` · aucun
`pumpAndSettle` autour du confetti.

---

## Findings & dispositions

### 🔴 D1 — MAJEUR — `_StatTile` : le motif « Terminer\nTerminer » **récidivait sur les 3 tuiles** — ✅ CORRIGÉ

**Fichier** : `z_session_summary_view.dart` (`_StatTile.build`)
**Scénario d'échec** : un apprenant sous TalkBack/VoiceOver ouvre le bilan et balaie les stats. Il
entend **« Cartes, 8, Cartes — valeur : 8 »** (libellé ×2, valeur ×2) — et de même sur « Maîtrisées »
et « Durée ». Le `Semantics(label:/value:)` **fusionnait** avec ses 2 `Text` enfants. La **fonction
centrale de FR-SU8** était annoncée en bégayant sur **toute sa surface**. Viole AC10/AD-13.

**Pourquoi c'était invisible** : les **17** assertions de stats passaient **toutes** par `_valueOf`,
qui lit le **`Text` VISUEL** ; le seul `getSemantics` de la story portait sur le bouton — le seul
endroit que le dev avait corrigé. C'est la leçon su-4 : **un défaut est un MOTIF, pas un cas isolé.**

**Correction** : `ExcludeSemantics` autour du `Column` (patron déjà retenu sur `_ActionButton`).
**Test porteur** : assertion sur l'**arbre SÉMANTIQUE** (`getSemantics` → `label`/`value` sur les 3
tuiles), + une contre-preuve que le **canal visuel reste intact** (AD-13 : `ExcludeSemantics` ne doit
pas effacer les textes rendus — une correction qui les effacerait serait pire que le défaut).

#### 🔍 Balayage EXHAUSTIF du motif (exigé par D1) — **4 sites `Semantics` dans le code su-5**

| # | Site | État | Verdict |
|---|---|---|---|
| 1 | `_StatTile` (`Semantics(label:/value:)` + **2 `Text`**) — rendu **×3** | fusionnait | 🔴 **CORRIGÉ** |
| 2 | `_ActionButton` (`Semantics(button:, label:)` + `Text`) | `ExcludeSemantics` déjà présent | ✅ déjà sain |
| 3 | `_buildCelebrationHeader` (`Semantics(label:)` + `Container`>`Icon`) | **aucun `Text` enfant** ⇒ **pas de fusion** (un `Icon` sans `semanticLabel` ne produit aucun nœud) | ✅ non concerné (mais cf. LOW-1) |
| 4 | `_ConfettiBurst` (`ExcludeSemantics` + `ConfettiWidget`) | correct | ✅ déjà sain |
| 5 | `ZSessionFeedbackText` — `Text` **nu, sans `Semantics`** | **correct et délibéré** : un `Semantics` explicite ici **provoquerait justement la fusion** | ✅ le code a raison |

⇒ **1 seule classe défectueuse** (`_StatTile`, rendue 3×). Le motif est désormais **balayé et clos**
sur l'intégralité du diff su-5.

---

### 🔴 D2 — MAJEUR — la garde de confinement était **falsifiable ET déclenchable par un commentaire** — ✅ CORRIGÉ

**Fichier** : `test/z_third_party_confinement_test.dart` (`_stripComments`, consommé sur du **YAML**)
**Gravité** : `graph_proof.py` ne détecte **aucune** fuite tierce ⇒ **cette garde est la SEULE
protection de NFR-SU7**.

`_stripComments` retire `//`, `*`, `/*` — des commentaires **Dart** — mais **jamais `#`**, les
commentaires **YAML**. Appliqué à des `pubspec.yaml`, le contenu commenté était scanné **comme du
code**. La revue l'a prouvé **dans les deux sens** :

- **faux NÉGATIF** : contrainte réelle desserrée à `'>=0.8.0 <0.9.0'` + `# Epingle : confetti: ^0.8.0`
  ⇒ le test « ÉPINGLÉE à `^0.8.0` » restait **15/15 VERT** ⇒ un `confetti 0.9.x` (assert /
  `_continueAnimation` changés) passait **sans rouge** ;
- **faux POSITIF** : `# ne jamais declarer confetti: ici` dans `zcrud_flashcard/pubspec.yaml` ⇒
  **ROUGE** sans aucune déclaration réelle (E10 : *une garde qui crie au loup finit désactivée*).

**Correction** : `_stripYamlComments` (dé-commentateur du **bon langage**) + motifs **ANCRÉS**
(`_yamlDeclares` : `^\s+<pkg>:` ; `_yamlPinned` : ligne entière) au lieu d'un `contains` libre.
`_stripComments` (Dart) reste pour le barrel.
**Test porteur** : 3 contre-preuves R12 — les **deux mutations** ci-dessus doivent rendre le **BON**
verdict, plus une preuve que le `#` est bien retiré et que le `//` n'a rien à y faire.

**Preuve R3 sur les fichiers RÉELS** (mutations rejouées, restaurées, SHA-256 OK) :

| Mutation RÉELLE | Avant D2 | Après D2 |
|---|---|---|
| contrainte → `'>=0.8.0 <0.9.0'` + commentaire citant l'épinglage | ⚪ **15/15 VERT** | 🔴 **ROUGE** sur « la version est ÉPINGLÉE à `^0.8.0` » — la **bonne** raison |
| `# ne jamais declarer confetti: ici` dans `zcrud_flashcard/pubspec.yaml` | 🔴 **ROUGE** (faux) | ⚪ **18/18 VERT** — verdict correct |

---

### 🟠 D3 — MEDIUM — « Maîtrisées : **-1** » pouvait s'afficher — ✅ CORRIGÉ

**Fichier** : `z_session_summary_view.dart` (`zMasteredCount`)
**Scénario d'échec** : `ZStudySessionResult._decodeByQuality` ne filtre que le **type** (`is int`) —
un `-3` d'un document Firestore corrompu traverse **verbatim**. `zMasteredCount` sommait sans
plancher ⇒ `{'5': -3, '4': 2}` rend **-1** ⇒ l'écran affiche « Maîtrisées : **-1** » et le lecteur
d'écran annonce « **moins un** ». Aucun throw, aucun test rouge : **bug silencieux**.

**L'incohérence était interne au repo** : le même VO clampe déjà `total`/`correct` à `>= 0`
(`_decodeCount` : « négatif → 0 ») — la norme est explicite : *un compteur n'est jamais négatif*. Et
su-5 gardait déjà cette classe d'aberration **pour la durée** (`_formatDuration` : jamais `-1:-30`)
mais **pas pour le nombre qu'il dérive lui-même**.

**Correction** : plancher défensif sur le **CRAN** (et non la somme) — le cran aberrant est **ignoré**,
sans laisser un cran valide « compenser » une valeur absurde. `{'5': -3, '4': 2}` ⇒ **2**.
Le **VO reste INTACT** (hors périmètre, gate de rétro-compat non touché). **Test** : fonction pure +
rendu.

---

### 🟠 D4 — MEDIUM — la garde citée pour `scale.max - 1` **ne scannait pas les fichiers de su-5** — ✅ CORRIGÉ

**Fichiers** : dartdocs de `z_session_summary_view.dart` et `z_session_feedback.dart` ; garde
`test/z_quality_scale_single_source_test.dart`

Les deux fichiers neufs **citaient** la garde (« jamais le littéral `4` ; …rougit sur un littéral de
borne ») alors qu'elle n'ouvrait **qu'un seul fichier en dur** (`z_srs_quality_buttons.dart`, grep
RC=1). **La garde citée était un FANTÔME.**

**Scénario d'échec** : `maxQuality` étant **épinglé à 5**, écrire `masteredThreshold ?? 4` est
**strictement iso-comportemental** ⇒ **toute la suite reste verte**, et la citation du dartdoc
rassure le reviewer suivant. C'est la **régression exacte qui a produit le HIGH de su-1**, redevenue
possible **sans filet**.

**Correction** (portée **étendue**, jamais de garde parallèle — E10) : le chemin en dur devient une
**liste** `_scannedSources` (les 3 fichiers), + un motif **régex ancré** pour la vraie régression
(`masteredThreshold\s*\?\?\s*-?\d`). `_ScalePattern` accepte désormais littéral **ou** régex.
**Tests porteurs** : contre-preuve R12 de la **liste** (une liste amputée redeviendrait un fantôme) +
le scanner **détecte** `?? 4` + **contre-preuve de faux positif** : le `?? 0` légitime d'un compteur
(`byQuality['$quality'] ?? 0`) et la forme dérivée correcte restent **verts**.

**Preuve R3** : injection `scale.max - 1` → `4` **dans le fichier de prod réel** ⇒ 🔴 **ROUGE**, avec
diagnostic exact (`:354 → « masteredThreshold ?? <littéral> »`). **Avant D4, cette garde ne lisait
même pas ce fichier.**

---

### 🟠 D5 — MEDIUM — les réglages « imposés » du `ConfettiWidget` n'avaient **aucune garde** — ✅ CORRIGÉ

**Fichier** : `z_session_summary_view.dart` (`_ConfettiBurst`)
`grep "widget<ConfettiWidget>" test/` → **RC=1** ; les 2 hits de
`pauseEmissionOnLowFrameRate|shouldLoop|colors` étaient de la **PROSE**. Le code était **correct**,
mais **rien ne le tenait** — le test d'épinglage garde la **version**, pas les **réglages**.

**Scénario d'échec** : quelqu'un simplifie `_ConfettiBurst` et supprime `colors:` ⇒ le confetti tire
des couleurs **ALÉATOIRES**, hors thème ⇒ **NFR-SU5 violée, suite VERTE**. La garde de couleurs en
dur **ne peut pas** le voir : elle cherche un `Colors.*`, or il n'y a **rien du tout** — elle ne voit
pas une **absence**.

**Correction** : test lisant le `ConfettiWidget` **réellement monté** — `shouldLoop == false`,
`pauseEmissionOnLowFrameRate == false`, `colors` non-nul **et égal aux 3 couleurs résolues du thème
dans ce contexte**, `burstDuration` lue sur le **controller réel** (`< 2 s`, `> 0` — jamais une
constante du code : ce serait tautologique, défaut su-4), et `ExcludeSemantics` ancêtre (T6).
🚫 Aucun `pumpAndSettle` (T2) ; démontage explicite ; lire des propriétés ne pompe aucune frame.

> **Note de confinement** : importer `confetti` **dans un test** ne viole pas AC8/NFR-SU7 — la garde
> scanne `lib/` (`_ownerLib()`). C'est d'ailleurs le correctif que la lentille recommandait.

---

### 🟠 D6 — MEDIUM — le slot de feedback (`feedbackKey`) n'était couvert par **aucun** test — ✅ CORRIGÉ

**Fichier** : `z_session_summary_view.dart`
`grep "feedbackKey|feedbackBank|ZSessionFeedbackText"` sur les 3 suites → **RC=1**. Preuve par
mutation : `bank: → null` **et** `if (feedbackKey != null) → if (false)` laissaient **397 VERT**.

**Scénario d'échec** : un hôte (su-10) monte `ZSessionSummaryView(feedbackKey:…, feedbackBank:…)`. Une
refonte casse le câblage : le message n'est plus rendu **du tout**, ou la banque de l'app est
**ignorée** au profit de la banque par défaut (**mauvais ton**) — et **rien ne rougit**. C'est le
**titre même de la story** (FR-SU9) et l'**AC5** (« surcharge INTÉGRALE »), prouvée jusqu'ici sur
`ZSessionFeedbackText` **isolé**, jamais **à travers le slot**. Motif **« présence ≠ association »**.

**Correction** : 4 tests via un harnais `Localizations(fr)` **direct** — la primitive EXACTE que lit
`zFeedbackText` (`MaterialApp(locale:'fr')` est inopérant : `DefaultMaterialLocalizations` = `en`
seul — aveu ③ de la story, vérifié). Attendus **littéraux** : texte FR de la banque par défaut ·
banque témoin `TÉMOIN-SURCHARGE` **seule** à parler (et le défaut **absent** ⇒ jamais une fusion) ·
`feedbackKey: null` ⇒ rien · clé inconnue ⇒ jamais la clé technique (AD-10).

---

### 🟠 D7 — MEDIUM — `zFeedbackTierFor` : `timeTaken` / `hintsUsed` aberrants — ✅ CORRIGÉ (les 2)

**Fichier** : `z_session_feedback.dart`
**Scénario d'échec** : `zFeedbackTierFor` est une **API publique** dont l'**hôte** fournit
`timeTaken` — et su-5 force déjà l'hôte à mesurer le temps **au mur** (le VO ne porte aucune durée),
patron naturel `end.difference(start)`. Sur une correction NTP ou un changement d'heure système entre
les deux relevés, `timeTaken` est **négatif** ⇒ un apprenant qui a peiné 5 minutes sur une carte `q5`
lit « **Exceptionnel — juste, sans indice et en un éclair !** ». **Même classe** sur `hintsUsed` :
`-1 <= exceptionalMaxHints (0)` était **vrai** ⇒ un compte d'indices absurde valait « sans aide ».

**Asymétrie interne** : la fonction **clampait déjà** `quality` (et son dartdoc pose la doctrine), et
le fichier **frère** garde déjà la durée négative côté présentation (`_formatDuration` ⇒ `00:00`,
testé). Les **deux autres** entrées aberrantes de la **même signature** ne recevaient **aucun**
traitement — là où AD-10 mord le plus.

**Correction** : `!timeTaken.isNegative && …` et `hintsUsed >= 0 && …`.
🔒 **On ne clampe PAS à zéro** — ce serait *exactement* le bug : `0 s` = « instantané » et `0` indice
= « sans aide », soit les valeurs les **plus flatteuses**. Une entrée aberrante **refuse le PALIER**
et se replie sur `encouragement` (la carte **est** maîtrisée : message juste et positif), **jamais**
une exception, **jamais** une perte de fonction.
**Tests** (4) : les 2 cas négatifs · une **contre-preuve** que le chemin **nominal** est intact
(`Duration.zero` **reste** `exceptional` — sans quoi la correction aurait cassé le nominal) · le
refus porte sur le **palier**, jamais sur le seau de base.

> ⚠️ **Écart de brief signalé** : le brief annonçait « **les 2 MEDIUM** » de
> `review-su5-robustesse-sm1.md`, or ce rapport ne porte **qu'un seul MEDIUM** (F1, `timeTaken`) — ses
> 3 autres findings sont des LOW. J'ai traité F1 **et** la seconde entrée aberrante de la même
> signature (`hintsUsed`), que F1 nomme explicitement comme non traitée. Les 3 LOW du rapport sont
> consignés ci-dessous.

---

## LOW

### ✅ Corrigés (triviaux)

| # | Finding | Disposition |
|---|---|---|
| **LOW-1** | **Double annonce** : « Session terminée, bravo » (trophée) puis « Session terminée » (titre) — deux nœuds quasi identiques, consécutifs | ✅ **CORRIGÉ** — repli du trophée → « **Bravo** » : il porte la **célébration**, le titre porte le **fait**. **Clé l10n inchangée** (un hôte qui la surcharge n'est pas impacté) ; aucun test ne l'épinglait (grep vérifié) |
| **LOW-2** | **Doc T3 périmée** : « zéro particule en test » est **inversé par le correctif lui-même** — `pauseEmissionOnLowFrameRate: false` **RÉACTIVE** l'émission (`particle.dart:165`) | ✅ **CORRIGÉ** (prose) — la consigne tient, pour une raison **meilleure** : on n'assère pas sur les internes non déterministes d'un paquet tiers |
| **LOW-3** | Dartdoc de `z_session_feedback_bank.dart` promettant un `Semantics` **absent** du `build` | ✅ **CORRIGÉ** (prose) — **le code a raison, la prose avait tort** : un `Semantics` explicite ici **provoquerait la fusion** de D1. Le dartdoc explique désormais *pourquoi* le `Text` est nu |
| **LOW-4** | **Story** : « `strokeColor = Colors.black` viole NFR-SU5 » | ✅ **CORRIGÉ (prose de la STORY)** — `strokeWidth = 0` par défaut, jamais surchargé ⇒ **jamais peint**. **La story avait tort, le code avait raison** : le code n'a **pas** été touché |

### 📋 Consignés (non corrigés — hors périmètre ou coût disproportionné)

| # | Finding | Justification du report |
|---|---|---|
| **LOW-5** | **AD-8** : `confetti` en `dependencies:` **dure** ⇒ tiré même à `celebration: none` | **Conforme à AC8** (confinement **à `zcrud_session`**, tenu et prouvé). Coût **proportionné** : 636 K de Dart pur, MIT, sans plateforme ni codegen, **une** dep transitive (`vector_math`) déjà tirée par Flutter. Un satellite `zcrud_session_celebration` serait disproportionné |
| **LOW-6** | Le `ConfettiWidget` reste **monté à vie** après le tir (`build` ne teste que `_confetti == null`, jamais `widget.celebration`) | **Inerte** (controller arrêté, particules vidées), sous `ExcludeSemantics`, 0×0 en layout. Aucun crash, aucun coût de frame mesurable. **Cosmétique** |
| **LOW-7** | Angle mort **non consigné** de la garde de libellés : `semanticsLabel:` (param. de `Text`) ≠ `semanticLabel:` (param. d'`Icon`) — la regex ne matche pas le premier | **Aucun défaut livré** : `grep semanticsLabel lib/` → **RC=1**. Garde **héritée** (su-1/su-2), **hors périmètre en écriture** de su-5, et AC10 **interdit** de créer une garde parallèle. **→ ledger d'epic** |
| **LOW-8** | 2 gardes de source à **chemin relatif nu** (`z_session_summary_reduce_motion_test.dart`, `z_session_summary_view_test.dart`) là où la garde de confinement utilise `_repoRoot()` | **Impact nul aujourd'hui** (`flutter test` fixe la cwd au package ⇒ verts). Fragilité, pas faux-vert. **→ ledger d'epic** |
| **LOW-9** | Reduce Motion activé **PENDANT** un tir ⇒ le confetti continue (latch consommé avant le test RM) ; le dartdoc affirme l'inverse | Fenêtre bornée (~1-2 s), déclencheur rare (bascule d'un réglage OS pendant le burst). **Conforme à AC7** (qui régit RM **actif au montage**) |
| **LOW-10** | `_entrance.forward()` inconditionnel ⇒ ~600 ms de ticker **sans listener** sur le défaut `none` | ~36 frames inutiles sur un écran terminal. Négligeable ; claim de **flux de contrôle**, non mesuré |
| **LOW-11** | `_confetti` `null → non-null` bascule la racine `SingleChildScrollView` → `Stack` ⇒ sous-arbre recréé (scroll remis à 0) | **Le chemin NOMINAL ne la subit pas** (`_maybeCelebrate` court dans `didChangeDependencies`, **avant** le 1ᵉʳ `build` ⇒ `Stack` en place dès la frame 1). N'arrive que sur `subtle → confetti` après coup |
| **LOW-12** | **Dette l10n** : le **chrome** (titre/Cartes/Maîtrisées/Durée/Terminer) n'a qu'un repli **FR**, alors que le feedback est bilingue ⇒ un anglophone **sans** `ZcrudScope(labels:)` voit un écran **mixte** | **Choix contraint, pas un oubli** : `zcrud_core` est **interdit** à la story (les tables `_frLabels`/`_enLabels` y sont fermées). su-5 **triple la surface** de la dette su-4 ⇒ **→ ledger d'epic** |

---

## Preuves R3 — 11 injections rejouées, **11/11 ROUGES pour la BONNE raison**

Toute correction est adossée à un test qui **sait rougir**. Chaque injection : sauvegarde `cp` +
**SHA-256**, mutation du fichier de **prod RÉEL**, run **ciblé**, restauration **vérifiée**.

| # | Injection (fichier de prod réel) | Verdict | Message d'échec — cause RÉELLE |
|---|---|---|---|
| D1 | `_StatTile` : `ExcludeSemantics` → `Builder` (neutre) | 🔴 ROUGE | `Expected: 'Cartes' / Actual: 'Cartes\n…'` — **la fusion elle-même** |
| D2-a | contrainte → `'>=0.8.0 <0.9.0'` + commentaire citant l'épinglage | 🔴 ROUGE | « la version est ÉPINGLÉE à `^0.8.0` » *(était **VERT** avant D2)* |
| D2-b | `# …declarer confetti: ici` dans `zcrud_flashcard/pubspec.yaml` | ⚪ **VERT** (attendu) | verdict **correct** *(était **ROUGE faux** avant D2)* |
| D3 | retrait du plancher négatif | 🔴 ROUGE | `Expected: <2> / Actual: <-1>` — **le « -1 » mesuré** |
| D4 | `scale.max - 1` → `4` | 🔴 ROUGE | `:354 → « masteredThreshold ?? <littéral> »` *(garde **aveugle** à ce fichier avant D4)* |
| D5-a | `colors: colors` → `colors: null` | 🔴 ROUGE | `Expected: not null / Actual: <null>` |
| D5-b | `shouldLoop: false` → `true` | 🔴 ROUGE | `Expected: false / Actual: <true>` |
| D5-c | `pauseEmissionOnLowFrameRate: false` → `true` | 🔴 ROUGE | `Expected: false / Actual: <true>` |
| D5-d | confetti : `ExcludeSemantics` → `Semantics(label:)` | 🔴 ROUGE | `_AncestorWidgetFinder: Found 0 widgets` |
| D6-a | `bank: widget.feedbackBank` → `bank: null` | 🔴 ROUGE | `Found 0` sur `TÉMOIN-SURCHARGE` *(était **VERT à 397**)* |
| D6-b | `if (feedbackKey != null)` → `if (false)` | 🔴 ROUGE | `Found 0` sur `ZSessionFeedbackText` *(était **VERT à 397**)* |
| D7-a | retrait de `!timeTaken.isNegative` | 🔴 ROUGE | `exceptional` obtenu / `encouragement` attendu |
| D7-b | retrait de `hintsUsed >= 0` | 🔴 ROUGE | `exceptional` obtenu / `encouragement` attendu |

> ⚠️ **Incident d'outillage auto-signalé, pour la traçabilité** : ma **1ʳᵉ** injection D1 (`child: (`)
> était du **Dart invalide** ⇒ rouge par **cassure de compilation** — soit *exactement* le vice (b)
> (« rouge pour la MAUVAISE raison ») que la revue traque. **Détecté et rejoué** avec une injection
> **valide et neutre** (`ExcludeSemantics` → `Builder`, parenthèses équilibrées) : le rouge obtenu est
> alors **causé par la fusion sémantique**. J'ai vérifié l'**absence de `Error:`/`Failed to load`**
> sur les **13** lignes du tableau — **aucune** autre n'était une cassure de compilation. Un second
> incident (`cd` persistant faisant échouer une restauration) a été détecté et corrigé par des
> **chemins absolus**, puis l'intégrité re-prouvée par SHA-256. Ces deux incidents confirment le
> constat de la lentille : **le vice (b) est un piège d'OUTILLAGE**, pas un défaut de conception des
> tests de su-5.

---

## ✅ Points CONFIRMÉS au crédit du dev (vérifiés, non « corrigés »)

- **La discipline R3 est RÉELLE** : la lentille tests-porteurs a rejoué les **21/21 injections** du
  dev — **toutes rouges POUR LA BONNE RAISON**, avec le bon nombre de tests et le bon message. Le vice
  de quoting que le dev avait lui-même signalé était un **incident ISOLÉ, pas un motif**. Les **3
  aveux** du dev sont **exacts sur le fond**, y compris l'aveu ① (AC4-(d) resté vert : diagnostic
  juste, portée réduite **déclarée honnêtement**) et l'aveu ③ (harnais `Localizations` : **test non
  affaibli**, et **durci au-delà du contrat** — `toSet().hasLength(4)` interdit qu'un message soit
  recopié d'un seau à l'autre).
- **Les chiffres affichés sont VRAIS** : corpus AC2 **recalculé à la main** (total=8, **correct=6 ≠
  mastered=3**) ⇒ la distinction est réellement **imposée** et le test **sait rougir**. AD-46 **tenu**
  (échelle **dérivée**, `clampQuality` **voie unique**), seau q0-2 **exhaustif** sur les 6 valeurs.
- **`ZStudySessionResult` (VO persisté) INTACT** · **`zcrud_core` INTACT** — vérifié `git status`.
- **Reduce Motion : AUTHENTIQUE** — les 2 animations sont **réelles** (`Tween(0.6→1)` elasticOut,
  `Tween(0→1)` easeIn, consommées par `Transform.scale`/`Opacity`), mesurées sur la **géométrie
  peinte** (jamais le champ `transform` — faux négatif de su-4), le test **rougit vraiment**, les
  cercles ont été **retirés** plutôt que simulés, zéro ticker / zéro confetti / zéro `Duration.zero`
  sous RM. **La leçon su-3 est TENUE.**
- **Les 6 pièges de `confetti` réellement neutralisés** ; paquet **sain** pour une dép. git (MIT,
  636 K, Dart pur, seule dep transitive `vector_math`).
- **Démontage pendant un tir (T5) : réellement traité** — burst **réellement vivant** au démontage,
  ordre de `dispose` correct **par construction du paquet**, `takeException() isNull`.
- **SM-1 propre** : `AnimatedBuilder` utilise `child:` ⇒ le piège de su-2 (contenu rebâti à chaque
  frame) **n'est pas rejoué** ; controllers **stables** ; banques `const` (aucune allocation par build).

### 🔁 Les 2 réfutations de la revue **en faveur du code** (ne pas « corriger »)

1. **`strokeColor = Colors.black`** : `strokeWidth = 0` ⇒ **jamais peint**. **La story avait tort, le
   code avait raison** ⇒ c'est la **prose de la story** qui a été corrigée (LOW-4).
2. **`arrow_path`** dans le lock vient de **`graphite`** (`zcrud_mindmap`), **pas** de `confetti` : la
   claim de la story (« seule dep transitive : `vector_math` ») est **EXACTE**.

Également **écartés faute de scénario d'échec** (consignés pour que la revue suivante ne les
re-lève pas) : le `>=` au lieu du `==` de la spec (**durcissement**, correct sur toute config — aucune
config trouvée où il est faux) · `q9` compté dans `correct` (**préexistant au moteur**, hors périmètre)
· `ZSessionQualityBreakdown`/`ZStudyProgressRings` annonçant `label="0\n0\n1"` (**widgets hérités**
su-1/su-2, montés verbatim conformément à AC1 — **même classe que D1 mais hors périmètre** ⇒ ledger).

---

## Transition proposée

**`review` → `done`** — les **2 MAJEURS** et les **5 MEDIUM** sont **corrigés** (aucun reporté), les
LOW triviaux corrigés et les autres **consignés avec justification**. Vérif verte **rejouée
réellement** : `melos run analyze` **RC=0 repo-wide** · `melos run verify` **RC=0** · **23/23 packages,
4097 tests** · `zcrud_flashcard` **399 inchangé** · arbre **intact** (94, 0 sonde, VO et cœur non
touchés).

**À porter au ledger d'epic E-STUDY-UI** : LOW-5, LOW-7, LOW-8, LOW-12, + la classe D1 sur les widgets
**hérités** (`ZSessionQualityBreakdown`, `ZStudyProgressRings`) — même motif, hors périmètre su-5.
