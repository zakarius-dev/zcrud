# Code-review — `su-4-pile-swipeable-modes`

**Story** : `_bmad-output/implementation-artifacts/stories/su-4-pile-swipeable-modes.md` (12 ACs, arbitrages A1..A7)
**Package en écriture** : `zcrud_session` (seul) · **Spine** : AD-34 · AD-33 · AD-46 · AD-10 · AD-13 · AD-8 · hérités AD-1..32
**Dispositif de revue** : Workflow **multi-agent, 7 lentilles** (conformité AD · dépendance tierce · arène des gestes · a11y/SM-1 · adversariale · robustesse · tests porteurs R3)
**Rapports complets** : `/home/zakarius/.claude/jobs/39909dce/tmp/review-su4-*.md`

---

## Verdict

✅ **CORRIGÉE — prête pour `done`.**

Les 7 lentilles convergent sur un constat inhabituel : **le cœur de la story est solide et tenu par construction** — AD-34, AD-33, AD-46, AD-1/AD-8 sont **toutes vérifiées sur disque**, l'hygiène de la dépendance tierce est **exemplaire**, et **10 injections R3 sur 10 rejouées sont ROUGES**. Les défauts trouvés sont **concentrés sur deux angles morts précis** :

1. **ce qui se passe quand la file MUTE sous la pile** (D1/D8) — un **crash mesuré sur le chemin NOMINAL** ;
2. **ce que le code AFFIRME vs ce qu'il FAIT** (D2/D5) et **ce que les tests PRÉTENDENT mesurer vs ce qu'ils mesurent** (D3/D4/D6).

**8 findings traités : 2 HIGH corrigés · 4 MAJEURS corrigés · 2 MEDIUM corrigés · 3 LOW corrigés · 1 LOW consigné.** **Aucun MEDIUM reporté.**

| # | Sév. | Finding | Disposition |
|---|---|---|---|
| **D1** | **HIGH** | La pile **CRASHE** (`RangeError`) dès que la file rétrécit — chemin **NOMINAL** | ✅ **CORRIGÉ** |
| **D2** | **HIGH** | Le bouton « carte **précédente** » **AVANCE** (4 lentilles /7) | ✅ **CORRIGÉ — bouton RETIRÉ** |
| **D3** | MAJEUR | Le test « PRÉDICTION 2 MESURÉE » ne mesure **rien** (vacueux ×3) | ✅ **CORRIGÉ** |
| **D4** | MAJEUR | AC4 (« l'AC centrale ») : assertion **infalsifiable** | ✅ **CORRIGÉ** |
| **D5** | MAJEUR | 😀/🙁 réintroduisent la sémantique « gauche = raté » qu'A2 interdit | ✅ **CORRIGÉ** |
| **D6** | MAJEUR | Le **câblage** Reduce Motion n'est **pas gardé** | ✅ **CORRIGÉ** |
| **D7** | MEDIUM | Les 3 défauts de tests sont des **MOTIFS** | ✅ **TRAITÉ** (liste R3 épuisée) |
| **D8** | MEDIUM | `index == cardsCount` · file qui rétrécit · `onStackEnd` | ✅ **CORRIGÉ** (racine de D1) |
| — | LOW | Fallbacks `'<'`/`'>'`/`'—'` · alignement inversé · dartdocs fausses | ✅ **CORRIGÉS** |
| — | LOW | Clés l10n `zcrud.session.*` non définies | 🟡 **CONSIGNÉ pour l'epic** |

---

## D1 — HIGH — La pile CRASHE (`RangeError`) sur le parcours NORMAL · ✅ CORRIGÉ

**Fichier** : `packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart` — `didUpdateWidget` (`:209-219` avant correction) + `CardSwiper(` construit **sans `key`** (`:310`).

### Racine (lue sur disque, pas déduite)

`CardSwiper` porte **sa propre source de vérité d'index** (`_undoableIndex`), posée **uniquement en `initState`** (`card_swiper_state.dart:32`) et que **son** `didUpdateWidget` **ne réinitialise jamais** (`:54-60` — il ne fait que ré-abonner le contrôleur). Sans `key`, l'`Element` est **réutilisé** au changement de file : **l'index du paquet survit à la file qu'il n'indexe plus**, pendant que le `didUpdateWidget` de zcrud remet `_index = 0` de son côté. **Trois index coexistaient** : `cursor` (moteur), `_index` (zcrud), `_undoableIndex` (paquet).

### Scénario d'échec — le chemin NOMINAL, pas un cas limite

`ZStudySessionEngine.reduceGrade` (`z_study_session_engine.dart:79`) fait `queue.removeAt(cursor)` et **ne réinsère PAS sur une réussite** ⇒ **toute réussite RÉTRÉCIT la file**. `numberOfCardsOnScreen()` rend `min(displayed, cardsCount - index)` (`card_swiper_state.dart:338-350`), **négatif** dès que `index > cardsCount` ⇒ `List.generate(-1, …)` ⇒ **`RangeError` en plein `build`** — **écran rouge**, là même où la file vide est correctement traitée. **Une session SRS qui se passe BIEN est exactement ce scénario.** Violation AD-10.

### Correction

`key: ValueKey<int>(_queueGeneration)` sur le `CardSwiper`, `_queueGeneration` incrémenté dans `didUpdateWidget` au **changement réel** de file. Le remontage rejoue `initState` ⇒ `_undoableIndex` revient à `0`, **aligné** sur le `_index = 0` que le State s'impose déjà. **Les trois défauts (D1, D2-silencieux, D8) ont une racine UNIQUE et se ferment d'un seul geste.** Le contrôleur (broadcast `StreamController`) survit au remontage : le nouveau `initState` se ré-abonne — vérifié sur disque.

### Preuve R3 (rejouée par l'orchestrateur)

| Injection | Résultat |
|---|---|
| Retrait de la `key` | 🔴 **3 tests ROUGES**, dont le **`RangeError` VERBATIM** que la lentille robustesse avait mesuré (`Invalid value: Not in inclusive range … -1`) |

### Tests porteurs ajoutés (`z_session_card_swiper_fallback_test.dart`)

1. **file 5 → 2 en cours de session** ⇒ aucun crash, la pile repart sur la nouvelle file ;
2. **file remplacée à chaud (même longueur)** ⇒ indicateur **juste** (`'1/3'` sur la 1ʳᵉ carte, `Semantics.value` compris), **aucune carte sautée**, `onIndexChanged` non décalé ;
3. **(D8)** `index == cardsCount` ⇒ ni écran vide, ni cul-de-sac, `onStackEnd` **atteignable**.

---

## D2 — HIGH — Le bouton « carte PRÉCÉDENTE » AVANCE · ✅ CORRIGÉ — **bouton RETIRÉ**

**Fichier** : `z_session_card_swiper.dart:286` (`_navigate`), consommé `:362` (`previous`) et `:378` (`next`).

**4 lentilles sur 7** l'ont trouvé indépendamment (AD/F1, a11y/F1, adversariale/A1, dép-tierce/D1).

### Le fait, mesuré

`swipe(dir)` **n'est pas directionnel** : `_handleCompleteSwipe` fait `_undoableIndex.state = _nextIndex` = **toujours +1** (`card_swiper_state.dart:295-300`) ; `direction` n'est lue que par `_isValidDirection` (validation de **fin de geste**). La seule voie de retour, `undo()`, **n'était câblée nulle part** (grep RC=1). Mesuré : tap next puis prev ⇒ `indices=[1,2]`, carte `f2`.

**Gravité** : cette alternative existe **précisément parce que le paquet n'expose aucun `Semantics`** (`grep -rn "Semantics" flutter_card_swiper-7.2.0/lib/` → RC=1) et que le swipe est **inaccessible**. C'est donc **l'utilisateur de lecteur d'écran** — le seul public qu'AC9 sert — qui **sautait une carte en avant en croyant reculer**, **irrémédiablement** (chaque tentative de correction avançait encore).

### 🔑 DÉCISION ARBITRÉE : **bouton RETIRÉ**, `undo()` NON câblé — justification

La disposition laissait le choix « câbler `undo()` **ou** retirer le bouton », à trancher **selon ce qui sert l'utilisateur**. **J'ai retiré le bouton**, sur quatre faits vérifiés sur disque :

1. **AUCUN runtime ne recule** — fait décisif, vérifié : dans les **trois** moteurs (`z_study_session_engine`, `z_linear_session_state`, `z_white_exam_session_engine`), `cursor` ne fait que **croître** (`cursor + 1`) ou se recaler après un retrait. **Aucun n'expose de retour arrière.** Câbler `undo()` reculerait l'index **du widget** en laissant le `cursor` **du moteur** sur place : cela **FABRIQUERAIT** la désynchronisation à deux sources de vérité que **D1 existe précisément pour fermer**. Corriger un finding en manufacturant sa jumelle n'est pas une correction.
2. **AC9 n'exige aucun retour** — texte : « **When** l'apprenant veut **avancer** dans la pile », test porteur : « navigation par bouton ⇒ index **avance** ». Le bouton « précédent » n'a **jamais** été demandé.
3. **A2 dissout le retour** — les deux directions de swipe avancent : **il n'y a pas de « back » dans ce modèle**. Retirer le bouton donne la **PARITÉ** entre l'utilisateur du geste et l'utilisateur du lecteur d'écran — ce qu'exige AD-13. Câbler `undo()` aurait donné au lecteur d'écran une capacité que **personne d'autre n'a**, sans contrat côté hôte (su-5 n'a aucune sémantique d'index **décroissant**).
4. **`undo()` passe par `onUndo`, pas `onSwipe`** ⇒ une **2ᵉ voie d'émission**, contraire à **A6** (« une seule voie — deux voies = deux comptages divergents »).

> ⚠️ **A2 ne couvrait PAS ce cas** — arbitrage confirmé : A2 tranche **le geste**, pas un **bouton qui ment sur son action**. Le finding est réel et hors A2.

**Un contrôle absent vaut mieux qu'un contrôle qui annonce l'inverse de ce qu'il fait.** L'utilisateur de lecteur d'écran ne **perd** rien : il n'a jamais eu de « précédent » fonctionnel — il avait un piège.

### Pourquoi c'était passé (récidive exacte du HIGH de su-2)

`z_session_card_swiper_a11y_test.dart:102` n'assérait que `expect(node.label, isNotEmpty)` — **la présence, pas l'association** —, et **aucun test ne TAPAIT** `previousButtonKey` (2 occurrences, aucune dans un tap). Le dev avait refermé ce motif sur la **taille** (I14) mais **pas sur le libellé**, à 7 lignes de sa propre correction.

### Tests porteurs ajoutés + preuves R3

| Garde | Injection R3 (défaut réintroduit **verbatim**) | Résultat |
|---|---|---|
| **Rendu — association libellé↔action** : vise le nœud **par sa clé**, lit ce qu'il **annonce** (`'carte suivante'`), **TAPE**, et exige que l'effet **concorde** | bouton « précédent » câblé sur `swipe(left)` | 🔴 **ROUGE** |
| **Rendu — aucun contrôle n'annonce un retour** : scanne l'arbre `Semantics` réel (+ contre-preuve « le scan voit bien des libellés ») | idem | 🔴 **ROUGE** |
| **Source — `CardSwiperDirection.left` / `.undo()` bannis** du code exécutable (commentaires dépouillés : la dartdoc explique la règle et se dénoncerait) | idem | 🔴 **ROUGE** |

---

## D3 — MAJEUR — Le test « PRÉDICTION 2 MESURÉE » ne mesure RIEN · ✅ CORRIGÉ

**Fichier** : `z_flashcard_gesture_arena_test.dart:331-362`.

⚠️ **Le CODE est bon** : la lentille arène a **re-mesuré les 2 prédictions elle-même — elles sont VRAIES** (`SONDE H : pixels=100.0 et indices=[]`). **C'est la PREUVE qui était creuse**, sur **trois axes indépendants, chacun suffisant** :

| Axe | Fait mesuré |
|---|---|
| **(a)** face `_qcm()` ⇒ `maxScrollExtent = 0.0` | `shouldAcceptUserOffset` faux ⇒ `setCanDrag(false)` ⇒ **le `Scrollable` décline : le duel n'a JAMAIS lieu** |
| **(b)** finder `.first` = carte de **FOND** | `build` fait `.reversed` ⇒ `.first` = le dos, **sans `GestureDetector`**. Décisif : `of:.first` ⇒ `0.0→0.0` vs `of:.last` ⇒ `0.0→100.0` |
| **(c)** `indices isEmpty` **vrai quoi qu'il arrive** | `symmetric(horizontal:true)` ⇒ `_isValidDirection(top)` faux ⇒ `onSwipe` jamais appelé, **même si le pan gagne**. Drag de **-400 px** (8× le seuil) ⇒ `indices=[]` |

Et **AC6 exige « la face DÉFILE »** — jamais asserté (`grep "position.pixels|maxScrollExtent" test/` → **0 hit**).

### Correction

Carte **`_long()`** (réellement défilable) + cible = carte **de DEVANT** + les assertions qu'AC6 demande :
- **témoin anti-vacuité (a)** : `expect(position.maxScrollExtent, greaterThan(0))` ;
- **l'assertion d'AC6** : `expect(position.pixels, greaterThan(0))` — « la face défile » ;
- `indices isEmpty` conservé, mais **il ne porte plus la preuve**.

🔑 **Amélioration sur la disposition** : plutôt que `.last` (prescrit), la carte de devant est visée **par identité** (`ValueKey('reviewcard_f0')`, posée par le harnais). `.last` dépend de l'**ordre de peinture du paquet** — il redeviendrait faux à un bump 7.x. La pile rend `cardBuilder(_currentIndex)` en devant : viser `f0` par sa clé est **indépendant de la géométrie**. Cela ferme **(b) et le MEDIUM M1 d'un seul geste**.

### Preuves R3 (2 injections, chacune rejouant une vacuité d'origine)

| Injection | Résultat |
|---|---|
| carte **courte** (`_qcm`) — vacuité **(a)** | 🔴 **ROUGE** — `Expected: greater than <0> / Actual: <0.0>` (= `maxScrollExtent` mesuré par la lentille) |
| cible `.first` = carte de **FOND** — vacuité **(b)** | 🔴 **ROUGE** — `pixels Actual: <0.0>` (= la mesure `SONDE F` de la lentille) |

### MEDIUM lié (tests (4) et (5)) — ✅ CORRIGÉ

Même cible erronée, **masquée par `warnIfMissed: false`** — le drapeau qui **éteint** l'avertissement disant que le geste n'atteint pas le widget nommé. Ils ne passaient que parce que le centre du dos tombait, **par la géométrie du moment**, dans la carte de devant qui le recouvre : **coïncidence, pas conception**. Corrigé : cible par identité, **`warnIfMissed: false` retiré**, et `reveals` **distingués par carte** (`(flashcardId, bool)`) — sans quoi un tap atteignant l'`InkWell` **bien réel** de la carte de fond laissait le test vert alors que la révélation de la carte de devant était morte (**HIGH D1 de su-2 rejoué sous un test incapable de le voir**).

---

## D4 — MAJEUR — AC4 : assertion structurellement INFALSIFIABLE · ✅ CORRIGÉ

**Fichier** : `z_no_srs_write_in_non_srs_modes_test.dart:77-123`.

`expect(spy.calls, isEmpty)` portait sur un espion **jamais branché** — ni `ZLinearSessionState` ni `ZWhiteExamSessionEngine` n'ont de paramètre pour le passer. L'assertion se lisait : « *une liste fraîche, que rien au monde ne peut alimenter, est vide* ». **Preuve décisive de la lentille R3** : supprimer **l'INTÉGRALITÉ** de l'exécution de session laissait les **4 tests « parcours INTÉGRAL » VERTS**. Et la dartdoc (`:20-26`) affirmait « le **MÊME** espion, dans le **MÊME** test » — **faux** (autre instance, autre test, autre runtime). **C'est l'AC centrale d'AD-34**, et c'est le **D8 de su-3** que le dev avait correctement appliqué au jeton `_generation` sans le retourner contre cet espion.

### Correction — deux axes séparés et **nommés honnêtement**

1. **axe STRUCTURE** (neuf, **le seul falsifiable**) : l'absence d'écriture SRS est une propriété du **TYPE** (AD-34) — un espion ne peut pas la mesurer. On la prouve **sur la source des ctors RÉELS** (patron du test (4) de `z_session_runtime_mapping`) : `reviewer` **absent** des deux runtimes non-SRS, **+ contre-témoin** : le moteur SRS, **lui**, en a un — sans quoi un simple **renommage** rendrait les deux `isFalse` verts sans rien prouver.
2. **axe COMPORTEMENT** (conservé, **renommé**) : « parcours INTÉGRAL **jusqu'à complétion** » — les reducers terminent sur les **deux branches**. C'est vrai, c'est utile, et c'est **tout** ce que l'exécution prouve.

L'`expect(spy.calls, isEmpty)` décoratif est **retiré** : retirer une preuve vide vaut mieux que l'afficher — **exactement le traitement du jeton `_generation`**. Dartdoc réécrite : elle décrit désormais ce que le fichier prouve, **et ce qu'il ne prouve pas**. Témoin positif **conservé** (il est réel, il rougit sur I4).

### Preuve R3

| Injection | Résultat |
|---|---|
| **R3-I6 verbatim** — paramètre `reviewer` ajouté au ctor de `ZLinearSessionState` (runtime **non-SRS**) | 🔴 **ROUGE** — « un `reviewer` est apparu au ctor du runtime linéaire ⇒ `list`/`cramming` peuvent désormais écrire du SRS » |

⇒ **l'axe que l'espion ne pouvait pas porter est désormais porté.**

---

## D5 — MAJEUR — L'icône réintroduit « gauche = raté » · ✅ CORRIGÉ

**Fichier** : `z_session_progress_indicator.dart:363-369`.

`Icons.sentiment_very_satisfied` (fin) vs `sentiment_dissatisfied` (début) — alors que la dartdoc **du même fichier** (`:246-249`, `:334-336`) affirme **verbatim** « il ne dit ni réussi ni raté » et « les deux sens sont **NEUTRES** ». **Origine tracée** : IFFD, où **la direction EST la note** (`quality < 3 ? left : right`) — les émojis y signifient littéralement *réussi/raté*. Portés ici, ils réintroduisent la sémantique que **FR-SU6 interdit nommément**.

**Le raisonnement était auto-réfutant** : le dev a écarté `primary`/`error` **pour rester neutre**, puis a choisi un **visage satisfait vs insatisfait** — un signal de jugement **strictement plus fort** que les couleurs refusées.

**Scénario** : l'apprenant tire vers la gauche, voit un visage mécontent **suivre son doigt** (retour continu), lâche — et **croit avoir noté**. **Rien n'est écrit** (le swipe ne note pas : c'est l'AC centrale), et le geste inverse aurait produit le **même** effet. Il peut « noter » une session entière **sans une seule écriture SRS**. C'est le **pire des deux mondes** : l'affordance Tinder interdite, **sans** l'effet qu'elle promet.

### Correction

Glyphe **neutre et directionnel** : `Icons.arrow_back` / `arrow_forward`. **Fait vérifié sur disque** (`flutter/lib/src/material/icons.dart:2290,2482`) : les deux portent **`matchTextDirection: true`** ⇒ ils **se retournent** en RTL — `towardsEnd` pointe vers la fin dans **les deux** directions (un émoji n'aurait rien retourné). Aucun test à toucher (AC8 lit `resolvedOpacity`/`resolvedScale`) — **conforme à la disposition**. Dartdoc de `ZSwipeEmotion` complétée : la neutralité est une **contrainte de RENDU**, pas une intention.

### LOW lié — ✅ CORRIGÉ

L'indicateur s'affichait **du côté opposé** au geste (`:352-355`) alors que la dartdoc dit « du **bon** côté ». `switch` inversé (même bloc que D5).

---

## D6 — MAJEUR — Le câblage Reduce Motion n'est pas gardé · ✅ CORRIGÉ

**Fichier** : `z_session_card_swiper.dart:338-341`.

L'animation est **réelle** (I12 rouge — **`zReduceMotionOf` conservé à juste titre, D8 de su-3 évité** : `resolvedOpacity` continue vs binaire au seuil, `resolvedScale` interpolée vs fixe). **Mais le CÂBLAGE lui-même n'était pas gardé** : les tests RM montent `ZSwipeEmotionIndicator` **isolément** et lui **injectent le booléen** ⇒ ils prouvent que l'indicateur **SAIT** dégrader, jamais que le swiper **le lui DEMANDE**. **Le même motif que D2 : présence au lieu d'ASSOCIATION.** Mesuré : `reduceMotion: false` en dur ⇒ **304/304 VERTS**.

### Correction

Test au niveau de l'**ASSEMBLAGE**, traversant `MediaQuery → zReduceMotionOf → cardBuilder → ZSwipeEmotionIndicator` : drag à **deux offsets** (20 % / 60 %), lecture de l'opacité **résolue** ⇒ **identiques** sous RM, **différentes** sans. **+ témoin positif** (sans RM, l'opacité suit le doigt) — sans quoi le test serait vert **parce que rien n'anime**.

> 🔬 **Écart technique consigné** : le drag doit d'abord franchir `kTouchSlop` (18 dp) — en-deçà, le `PanGestureRecognizer` n'accepte pas le geste, `onPanUpdate` n'est jamais appelé, l'indicateur n'est même pas monté et le test échouerait sur « No element » **sans rien mesurer**. `DragStartBehavior.start` (défaut du paquet) **écarte** ce delta de franchissement — vérifié empiriquement.

### Preuve R3

| Injection | Résultat |
|---|---|
| `reduceMotion: false` en dur (câblage rompu — **le défaut qui laissait 304/304 verts**) | 🔴 **ROUGE** — « l'opacité varie encore avec l'offset SOUS Reduce Motion ⇒ le swiper ne relaie PAS `zReduceMotionOf` » |

---

## D7 — MEDIUM — Les 3 défauts sont des MOTIFS · ✅ TRAITÉ

**Au crédit du dev** : il a démasqué **3 de ses propres tests** (I1 **casse-sensible**, I14 **tautologique**, I16c **faux motif**). Les 3 corrections **tiennent** (rejouées ROUGES par la lentille R3). Chasse au **motif** (pas à l'occurrence), liste R3 épuisée :

| Motif | Recherche menée | Verdict |
|---|---|---|
| **Comparaison à une constante du code** | `grep expect(.*Z*.\(minTarget\|appearThreshold\|_minScale\|threshold\))` | ✅ **1 seul hit** : `minTarget`, **correctement traité** (le `48` d'AD-13 est écrit **en dur** — exigence externe ; `minTarget` n'est vérifié qu'**en plus**, contre un relâchement). Les clés (`opacityKey`, `progressKey`…) sont des **cibles**, pas des valeurs assertées : patron correct. `appearThreshold` **non utilisé** par les tests RM (offsets en dur). |
| **Dépendance à la casse** | `grep toLowerCase\|caseSensitive` sur les gardes de source | ✅ **Fermé** — seul `z_swipe_never_grades` compare des identifiants (à raison, en `toLowerCase`) ; les autres comparent des **chemins/imports**. Les 3 gardes neuves (D2-source, D4-structure) sont **insensibles à la casse**. |
| **Motif approximatif / faux discriminant** | `warnIfMissed` (8 sites) ; `isNotEmpty` sur libellé | ✅ **Traité** — les 2 sites masquant une **mauvaise cible** (tests (4)/(5)) sont corrigés (D3) ; les 6 restants sont Actes I/II (**une seule carte**, pas d'ambiguïté fond/devant) et visent chacun une clé asserée `findsOneWidget` **avant** le geste : **légitimes**. `expect(node.label, isNotEmpty)` — **le motif qui masquait D2** — est **éliminé**. |

---

## D8 — MEDIUM — `index == cardsCount`, file qui rétrécit, `onStackEnd` · ✅ CORRIGÉ

Même racine que D1 (`CardSwiper` sans `key`), **fermé par la même correction** — comme la lentille robustesse l'avait prévu (« une seule correction les ferme toutes les trois »).

- **`index == cardsCount`** : `min(2, 3-3) = 0` ⇒ `Stack` **vide**, **sans repli** (`emptyBuilder` **hors d'atteinte** : la file n'est pas vide) et **`onStackEnd` jamais émis** ⇒ **cul-de-sac** : apprenant bloqué devant un vide, sans fin de session ni recours. AD-10 demande de **dégrader**, pas d'aboutir à un état sans issue. ⇒ test porteur (3), **ROUGE** sans la `key`.
- **File de 2 exactement** : ✅ **aucun problème** — `min(2,2) = 2 == cardsCount`, l'assert passe (PROBE C de la lentille). Confirmé, rien à corriger.

---

## LOW

| Finding | Disposition |
|---|---|
| Fallbacks a11y `'<'` / `'>'` / `'—'` — le lecteur d'écran annonce « **less than** », « **greater than** », « **tiret** » ; **su-4 était le seul écart du repo** (tous les widgets frères ont un repli lisible) | ✅ **CORRIGÉ** — `'carte suivante'`, `'Aucune carte'` (alignés sur `z_srs_quality_buttons`, `z_flashcard_review_card`) |
| Indicateur de drag affiché **du côté opposé** au geste | ✅ **CORRIGÉ** (avec D5) |
| Dartdoc **fausse** : « `allowedSwipeDirection` ne filtre QUE la fin de geste — n'empêche pas le pan de revendiquer le vertical ». **Mesuré faux** : `CardAnimation.update` (`card_animation.dart:79-96`) n'applique `dy` **que si** `up`/`down` autorisé ⇒ avec `symmetric(horizontal:true)`, `top` **n'est JAMAIS modifié** (`topLeft` (8,8)→(8,8), delta 0). Un dev de su-5..su-8 en aurait conclu que le réglage est « cosmétique pendant le drag » et l'aurait remplacé par `all()` — **rendant réelle** la translation qu'il croyait déjà exister | ✅ **CORRIGÉ** — la dartdoc décrit les **deux** rôles du réglage + l'avertissement explicite |
| Dartdoc **techniquement fausse** : « en retournant `bool` … **aucune fenêtre ne s'ouvre** ». En Dart, `await <non-Future>` **suspend quand même** (microtâche) : le paquet cède **inconditionnellement**. Ce qui est vrai — et suffit — est que **notre handler a fini** quand la fenêtre s'ouvre | ✅ **CORRIGÉ** — la propriété est attribuée à **notre handler**, pas au paquet |
| Dartdoc : chemin du paquet tronqué (`card_swiper_state.dart` est sous `lib/src/widget/`) | ✅ **CORRIGÉ** |
| Portée `lib/src/domain/**` de la garde « 3 runtimes » non déclarée (`z_session_runtime_mapping_test.dart:174`) | 🟡 **CONSIGNÉ** — le grep est **négatif** aujourd'hui (3 hits, tous dans `lib/src/domain/`), la portée est **correcte** (un runtime **appartient** au domaine) et un runtime hors domaine violerait déjà AD-1 **et** serait pris par `z_widgets_purity_test`. Aucun changement de code. |
| **Clés l10n `zcrud.session.next` / `.empty` définies dans AUCUN `ZcrudLabels`** | 🟡 **CONSIGNÉ POUR L'EPIC** — le mécanisme (`scope → locale → _enLabels → fallback`) est **conforme FR-26** ; le repli est désormais **lisible** (cf. ci-dessus). L'enregistrement des libellés relève du lot l10n de l'epic, pas de su-4. |

---

## Points CONFIRMÉS — au crédit du dev (vérifiés sur disque, **non touchés**)

- **AD-34 / AD-33 / AD-46 / AD-1 / AD-8 : toutes TENUES, et tenues *par construction*** — mapping `switch` **exhaustif sans `default`** (une 7ᵉ valeur **casse la compilation**), **aucun moteur créé** (exactement **3** `ChangeNotifier`), **A1 respecté** (garde de su-1 **intacte**, attribution prouvée par les artefacts de su-1 — su-4 n'y a ajouté **que** le clamp), clamp par la **seule** voie `config.clampQuality` (la **même** valeur clampée alimente le seam **et** le reducer), **`zcrud_core` INTACT** (`git status` vide), **barrel additif seul**, **aucune porte dérobée** (`ZSessionReviewer` no-op : RC=1).
- **Hygiène de la dépendance tierce : EXCELLENTE et prouvée** — licence **MIT**, **zéro dep transitive** hors Flutter, `^7.2.0` **aligné sur `lex_ui`**, **1 seul** point de déclaration, **1 seul** import, aucun type tiers en signature publique. Le garde d'AC10 est **solide** : allowlist **DÉRIVÉE**, **mutation prouvée**, portée **honnêtement déclarée**. **Non touché.**
- **Les 2 prédictions d'arène sont VRAIES** (re-mesurées par la lentille) · l'**`IgnorePointer` de su-2 est intact** avec sa garde porteuse · la **géométrie A5 est confirmée** (source **et** arbre) — la garde de composition **dépouille les commentaires** avant de scanner : elle ne peut pas être bernée par les 5 hits de dartdoc. **Seule la preuve (D3) était à refaire.**
- **10 injections R3 sur 10 rejouées sont ROUGES** — **0 revendication fausse** sur l'échantillon (historique opposable : su-1 → 1 fausse ; su-2 → 3/15 vertes). **Le socle de tests est réel.**
- **Le retrait du jeton `_generation` est JUSTIFIÉ** — instruit à fond par **deux** lentilles (robustesse §4, adversariale §4) : `_handleSwipe` est `bool`, **sans point de suspension** ⇒ le jeton était **structurellement inatteignable**. **Conclusion vérifiée avant d'être laissée : NON rétabli.** La garde de remplacement (synchronicité) est **porteuse** — elle rougit sur `async` **et** sur un type de retour ≠ `bool`, avec garde-fou anti-scan-aveugle.
- **3 auto-démasquages sincères** (I1 casse / I14 tautologie / I16c faux motif) — **rejoués, tous confirmés corrigés et porteurs**.
- **AC2 offre un témoin positif VÉRITABLEMENT câblé** (le **même** espion, dans le **même** test) — **le modèle** que D4 applique désormais à AC4.
- **Écarts déclarés : tous EXACTS** après vérification (`maxQuality:4` inconstructible ⇒ divergence par `minQuality:1`, **équivalente en pouvoir de falsification** ; I7 non falsifiable tel quel ⇒ **intention réelle jouée** ; dérive des locks **antérieure** à su-4).
- **SM-1/AC7** : mémoïsation réelle, sonde **DANS** le sous-arbre mémoïsé (défaut su-3 non rejoué), contre-témoin présent, contrôleur **possédé**.

---

## Vérif verte — REJOUÉE RÉELLEMENT sur disque

| Gate | Commande | RC |
|---|---|---|
| **Analyze repo-wide** | `dart run melos run analyze` | ✅ **RC=0** — **0 error, 0 warning** |
| **Verify repo-wide** | `dart run melos run verify` | ✅ **RC=0** |
| **Tests par package** (séquentiel ; `zcrud_generator` = `dart test`) | 23/23 packages | ✅ **verts** |

**`zcrud_session` : 314** (référence 304 → **+10**, tous **porteurs**, chacun **prouvé ROUGE** sur son injection)
**`zcrud_flashcard` : 399** (référence **399** — inchangé) · **`zcrud_core` : 931** · **TOTAL : 3993** (référence 3983 → +10)

> `melos run analyze` **ET** `melos run verify` rejoués **REPO-WIDE** (CLAUDE.md, non négociable) — indispensables ici : la correction D2 **supprime deux symboles publics** (`previousButtonKey`, `previousLabelKey`). Une vérif ciblée n'aurait **pas** détecté une référence cross-package (cf. `ZExportApi` en E11a-3). **Grep confirmé** : aucune référence hors la dartdoc qui documente le retrait.

### Discipline de réalité

- **Aucun `git checkout` / `git restore`** (su-1..su-4 non committés). Sauvegarde `cp` + **SHA-256** (54 fichiers) avant toute écriture ; chaque injection R3 sauvegardée puis **restaurée et re-vérifiée verte**.
- **Aucun `melos run test`** (parallélise/bloque) — `flutter test` **par package, séquentiel**. **Aucun `dart format`** (repo en style *short*).
- **Aucune sonde laissée** : `find packages/zcrud_session -name "zz_*" -o -name "*probe*"` → **RC=1**. Les sondes des lentilles avaient déjà été purgées par l'orchestrateur (arbre vérifié **avant** correction).
- `sprint-status.yaml` **non touché** · **aucun commit** · **`zcrud_core` non touché** (`git status --porcelain packages/zcrud_core/` → **vide**).

---

## Fichiers modifiés

**Prod (2)**
- `packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart` — D1/D8 (`key` + `_queueGeneration`), D2 (bouton retiré, `_navigate` → `_advance`), LOW (fallbacks lisibles, 3 dartdocs rectifiées)
- `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart` — D5 (glyphe neutre directionnel), LOW (alignement)

**Tests (5)**
- `test/presentation/z_session_card_swiper_a11y_test.dart` — D2 (association + anti-retour + garde de source)
- `test/presentation/z_session_card_swiper_fallback_test.dart` — D1/D8 (3 tests + hôte mutable)
- `test/presentation/z_session_swipe_reduce_motion_test.dart` — D6 (câblage à l'assemblage)
- `test/presentation/z_flashcard_gesture_arena_test.dart` — D3 (+ MEDIUM M1)
- `test/z_no_srs_write_in_non_srs_modes_test.dart` — D4 (axe structure + dartdoc)

---

## Synthèse

su-4 est, sur l'axe R3, **nettement au-dessus de su-1..su-3** : 0 revendication d'injection fausse, 3 auto-démasquages sincères, du code décoratif **retiré** plutôt qu'un test tautologique conservé, des écarts de sonde **documentés**. Le cœur — AD-34/AD-33/AD-46/AD-8 — **tient par construction**.

Les défauts trouvés relèvent de **deux familles**, et elles sont **la même erreur appliquée là où la vigilance s'est relâchée** :

1. **« prouver la présence au lieu de l'ASSOCIATION »** (D2, D3, D6) — un motif que le dev **cite lui-même trois fois** et qu'il a refermé sur la **taille** (I14) sans le poursuivre sur le **libellé**, à 7 lignes de sa propre correction. C'est ce reste de motif qui laissait passer **le HIGH D2**.
2. **« affirmer une conformité que le code/le test ne détient pas »** (D4, D5, dartdocs) — le **D8 de su-3**, que le dev a correctement appliqué au jeton `_generation` **sans le retourner** contre l'espion d'AC4 ni contre l'icône.

Les deux HIGH étaient **structurellement invisibles** à la suite verte de 304 tests — la spécialité de cet epic (su-2 : HIGH réel sous 328/328 verts). **Tous deux sont désormais gardés par des tests prouvés ROUGES sur le défaut exact.**

**Story VERTE — prête pour `done`.**
