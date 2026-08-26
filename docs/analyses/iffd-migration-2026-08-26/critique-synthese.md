# Critique de la synthèse — `etat-des-lieux.md`

**Date** : 2026-08-26 · **Cible** : `docs/analyses/iffd-migration-2026-08-26/etat-des-lieux.md` (517 l).
**Matière opposée** : les 33 `refutation-*.md`, les 11 `confrontation-*.md`, les 11 `carte-*.md` du
même dossier. **Aucun test lancé. Aucune écriture hors de ce dossier.** IFFD non ouvert en écriture.

**Verdict** : la synthèse est honnête sur sa méthode et fausse sur son arithmétique. Trois défauts
sont structurants : (1) son entrée **rang 1** rejoue exactement l'erreur que son propre §6.1
documente comme « le motif dominant » ; (2) **§1.2 annonce 24 manques dont 9 bloquants là où §3 en
liste 57 dont 21** ; (3) **84 % du volume déclaré « migrable aujourd'hui » n'est routé dans aucun
lot**, et **7 des 21 manques que la synthèse marque elle-même « bloque une capacité d'étude ou de
révision » n'apparaissent dans aucun lot non plus** — dont celui qui bloque le plus gros gisement
du domaine matières.

---

## A. Affirmations démenties qui figurent quand même en « migrable aujourd'hui »

### A-1 🔴 Entrée **rang 1** (`ZMenuEntryTile`, ≈ 420 l) — l'arithmétique réfutée, remise en tête

`etat-des-lieux.md:108` classe au **premier rang du classement « par lignes d'hôte économisées »**
un chiffre dont la source dit textuellement qu'il est le seul estimé du document :

- `confrontation-formulaires-crud.md:389-394` : « **Ces 1 586 lignes ne sont PAS le gain.**
  L'essentiel est constitué des **corps de rappel** (`onTap:`) — la logique métier, qui **reste** »,
  puis « ≈ 8 l. par tuile, **≈ 420 l.** […] c'est bien **le seul chiffre estimé de ce document** ».
- La **réfutation** de la même famille de transformation conclut : `refutation-Étude — dossiers
  d'étude (IFFD)-Les-5-menus-contextuels-d-item-popup-me.md:226` → « Lignes hôte supprimées :
  annoncé ~545 · **mesuré ≈ 45-60** », et `:216` demande explicitement de « **réénoncer le gain à
  ~50 lignes** » ; verdict `:13` : « le **gain annoncé est faux d'un facteur ~9** ».
- Deux autres réfutations concluent pareil sur la même mécanique :
  `refutation-Cartes mentales…-Le-menu-d-actions-d-une-carte-crit-deu.md:258` (« ~118 migrées +
  ~216 de code mort », pas 334) et `refutation-Notes intelligentes…-M-2…:159` (« le gain réel sur
  la déclaration du menu est **nul à négatif** […] les 163 lignes comptées comme supprimées sont
  **déplacées** »).

La synthèse **connaît** ce résultat : elle le cite en propre à `etat-des-lieux.md:404-409` et
`:421-423` (« +241 lignes écrites, −0 supprimée, et le portage est mort »). Elle ne l'applique pas
à son entrée 1. Le seul précédent **mesuré** de cette transformation chez l'hôte est **+241 / −0** ;
la synthèse en fait le meilleur gain du dossier sur la foi de « 8 l./tuile ».

**Ce qu'il faut faire** : dégrader l'entrée 1 en « gain de correction, pas de lignes » (c'est la
conclusion littérale de `refutation-…-Les-5-menus…:236-239`), ou remesurer par équilibrage
d'accolades sur l'échafaudage **seul**, fichier par fichier — jamais par tuile-type.

### A-2 🔴 L'assiette de l'entrée 1 recoupe le lot 2 (double compte)

Les 8 dialogues d'actions sont énumérés à `confrontation-formulaires-crud.md:377-387`. Parmi eux :
`smartnote_actions_dialog_widget.dart` — **6 tuiles, 275 l de blocs**.

Or `etat-des-lieux.md:94` (§2.0, lot zéro) supprime `SmartnoteActionsDialogWidget` (**417 l**) comme
code mort, appuyé sur `confrontation-notes-smartnotes.md:258` et
`carte-notes-smartnotes.md:115, :215` (« **417 (mort)** »). **≈ 48 des ≈ 420 lignes de l'entrée 1
portent donc sur un fichier que le lot 2 efface.** La synthèse énonce elle-même la règle qu'elle
viole, à `etat-des-lieux.md:87` : « À faire **avant** tout portage, sous peine de porter du code que
personne n'ouvre. »

### A-3 🟠 Entrée 7 (`zEvaluateLocally`) — la réfutation exige un adaptateur que la synthèse tait

`etat-des-lieux.md:114` classe `zEvaluateLocally` en « migrable aujourd'hui, sans une ligne de
socle », avec pour seule réserve `ZSrsConfig(minQuality: 1)`. La réfutation d'où sortent ces
constats conclut autrement — `refutation-Révision…-Cesser-d-envoyer-les-QCM-et-vrai-faux-.md:231` :
« la migration coûte **trois gestes**, pas zéro : (a) `minQuality: 1` ; (b) **un adaptateur
`ZFlashcardAnswerEvaluationPort`** […] ; (c) une `hintPolicy` neutre ». Et `:144` : sans (b),
« **les questions ouvertes et les exercices perdent leur note IA** et tombent à un 3 plat » —
**deux types sur quatre**. Grep négatif montré par la réfutation (`:151-160`) : 2 occurrences chez
l'hôte, **zéro implémentation**.

**Grep négatif montré sur la synthèse** :
```
$ grep -n "ZFlashcardAnswerEvaluationPort\|evaluationPort\|openQuestion\|exercise" etat-des-lieux.md
$ echo $?
1
```
La synthèse ne mentionne **nulle part** ni le port, ni la perte. Le lot 3 (`:291-300`) embarque
`zEvaluateLocally` en déclarant « **Dépendances : lot 1** » et « paquets : aucun ».

### A-4 🟠 Entrée 4 (`ZFlashcardHintPort`, ≈ 130 l) — même angle mort

Même grep négatif de la même réfutation (`:151-160`) : `hintPort` est **non implémenté** chez
l'hôte, et le legacy appelle `aiRepositoryProvider.generateFlashcardHint`
(`refutation-…:2.4`). Adopter le port suppose donc, comme en A-3, **d'écrire** un adaptateur
repliant un callback en `Future`+`ZResult`. `etat-des-lieux.md:111` chiffre ≈ 130 l gagnées sans
retrancher cette écriture.

### A-5 🟢 Ce qui est correctement traité

Les entrées **21** (`ZSrsConfig(minQuality: 1)`), **22** (`ZHintPenaltyPolicy`) et **23**
(`revealController`) sont fidèles à leurs sources : les deux premières sont les *corrections*
exigées par la réfutation (`refutation-…-Cesser…:126, :219, :2.3`), la troisième est la seule
affirmation tenue (`refutation-Examens…-revealController…:15` « l'affirmation **TIENT** »), et la
synthèse le dit sans l'embellir, y compris en démentant le « ~180 lignes gagnées ».

⚠️ **Portée réelle de la garantie de §2** : le préambule `:79-80` promet que chaque entrée a
« **soit** survécu à une réfutation adversariale, **soit** été remesurée par moi ». Sur 24 entrées,
**une seule** relève de la première branche (l’entrée 23, la synthèse le dit elle-même à `:130`).
Les 23 autres reposent sur une remesure **d'un seul auteur, non contradictoire** — le dispositif
même dont §6 vient d'établir qu'il produit 32 démentis sur 33. La formulation ne le laisse pas voir.

---

## B. Chiffres non traçables ou faux

| Chiffre | Où | Ce que dit le disque |
|---|---|---|
| « **24 manques** dont **9 bloquent** » | `:38` | §3 liste **57** identifiants (`FLA-1`, `SES-1..11`, `MD-1..4`, `STU-1..11`, `DOC-1..4`, `CORE-1..4`, `SCR-1..8`, `UI-1..3`, `FIR-1..5`, `GEN-1..6`) dont **21** marqués `**OUI**`. Facteurs 2,4 et 2,3. Aucun sous-ensemble de 24/9 n'est défini nulle part. |
| « **≈ 6 500 l** immobilisées » | `:38` | **Orphelin absolu** : une seule occurrence dans les 60 fichiers du dossier, aucune dérivation, aucune somme, aucune confrontation citée. |
| « **≈ 2 100 lignes** » (total établi) | `:133` | La somme de la colonne du tableau `:107-130` fait **2 316**. Le total « établi » n'atteint 2 100 qu'en y **laissant** les entrées 17 (≈ 151) et 18 (≈ 220) explicitement marquées **NON ÉPROUVÉE(S)** dans le tableau même. Un « total établi » qui contient 371 l non éprouvées n'est pas établi. |
| « **quatre entrées** sur vingt-quatre » non éprouvées | `:496` | Le tableau n'en marque que **trois** (entrées 3, 17, 18 — `:110, :124, :125`). Les deux autres nommées en `:501-503` (`ZChatNotebookScreen`, feuille d'outils) ne sont **pas** des entrées du tableau. Le compte ne se referme pas. |
| « `ZSessionSummaryView` ≈ 200 » | `:110` **et** `:134` | Comptée **dans** le tableau (donc dans la somme) **et** dans la liste « s'y ajoutent, NON ÉPROUVÉES » qui se veut hors tableau. |
| « **700 à 1 300 l** annoncées » | `:37` | Les trois postes de `:134-136` donnent 330 + (136…600) + 200 = **666 à 1 130**. La fourchette est étirée aux deux bouts sans source. |
| « **19 170 l** (62 fichiers) » | `:35` | Seul chiffre de §1 dont la **commande n'est pas montrée**, alors que ses six voisins de `:20-30` le font. Introuvable dans les 59 autres fichiers du dossier. |
| « les **12 bascules** du domaine, dans `main.dart:201-210` » | `:140` | `carte-etude-dossiers.md:197` : « **Aucune bascule du domaine dossier n'est active à l'exécution** » ; `carte-etude-matieres-corpus.md:222` : `main.dart:201-210` lève **huit** bascules — `notebook`, `aiRouterEdition`, `exam`, `valuationTool`, … La synthèse elle-même écrit « **8** identifiants seulement sont forcés » **à la même ancre** (`:35`). Les 12 bascules du domaine dossier ne sont pas à cette ancre : `:140` et `:35` se contredisent à la ligne près. |

Ce qui **trace** correctement, et mérite d'être dit : `≈ 3 640 l` (`:46`, repris `:142`) → `confrontation-etude-dossiers.md:103`
à l'unité près ; `6 170 l` (`:139`) → `confrontation-etude-dossiers.md:26, :101` ; l'empan `1 586 / 3 554`
(`:108`) → `confrontation-formulaires-crud.md:387` et `carte-etude-matieres-corpus.md:531` ; les
sommes internes de §2.0 (≈ 12 250) et de §1.3 (`:46`) sont recalculables.

---

## C. L'ordre de bataille est bancal

### C-1 🔴 84 % du « migrable aujourd'hui » n'est dans aucun lot

Les neuf lots (`:263-364`) ne routent que **10 des 24 entrées** de §2.1 : lot 1 → entrées 20, 21,
22, 23 ; lot 3 → entrées 7, 8, 10, 11, 12, 14 (`:293`). Les lots 4 à 9 ne portent que du travail **de socle**
(§3), et le lot 2 ne porte que la suppression.

**Non routées** : entrées 1 (420), 2 (200), 3 (200), 4 (130), 5 (150), 6 (131), 9 (77), 13 (40),
15 (36), 16 (30), 17 (151), 18 (220), 19 (150), 24 (0) — soit **≈ 1 935 lignes sur les ≈ 2 316 du
tableau**. Le lot 3 revendique lui-même « ≈ 380 lignes » (`:294`). Un document qui titre « **§4
L'ORDRE DE BATAILLE** » et laisse hors bataille le gros de ce qu'il vient de déclarer migrable
n'est pas un plan : c'est un tableau plus un extrait de tableau.

### C-2 🔴 Le lot 3 a une dépendance de socle non déclarée, et une migration de données

Le lot 3 se déclare « **paquets : aucun ; Dépendances : lot 1** » (`:291`, `:295`) et embarque
`zAdvanceStreak` (entrée 11). Mais `SES-11` (`:171`) dit de la persistance du streak : « c'est la
pièce qui **fait atterrir** §2 entrée 11 » et « ⚠️ La forme stockée diffère : socle `lastGradedDay`
(`yyyy-MM-dd`), hôte `DateTime` ⇒ **migration de données** ». Une migration de données et un port
manquant (`ZStreakStore`) ne sont ni « paquets : aucun » ni « dépendances : lot 1 ». S'y ajoute
A-3 (adaptateur d'évaluation) pour `zEvaluateLocally`, du même lot.

### C-3 🟠 Le classement par danger contredit le classement par lot

La synthèse qualifie **SCR-1** de « **le manque le plus DANGEREUX du dossier** […] **une perte de
données silencieuse** » (`:220`) et **FIR-1** de destructeur du « **filet de rollback** » (`:236`, repris `:355`).
Elle les range en **lot 8** et **lot 9**, c'est-à-dire **derniers**, et gate le lot 8 derrière le
lot 6 (`:346`). Or ces deux défauts mordent **au premier `update` porté**, pas à la fin du
programme : tout portage de formulaire réalisé dans les lots précédents (entrées 6, 13, et tout
`presentFormEdition` du domaine étude) les traverse. Soit ils sont urgents et remontent, soit le
qualificatif « le plus dangereux » ne tient pas ; les deux ne peuvent pas coexister.

### C-4 🟠 « Chaque lot tient en une release » (`:261`) n'est étayé nulle part

Le lot 9 rassemble `FIR-1..5` **plus** `GEN-1`/`GEN-2`/`GEN-3` — dont la synthèse dit elle-même que
c'est « **une refonte d'émission, pas un ajout de paramètre** » (`:358`), avec `GEN-6` (« saut de
**3 majeures** d'`analyzer` à re-résoudre », `:246`) **non tranché**. Le lot 7 est « **entièrement
neuf** : le socle n'a que les ports » (`:339`) et comprend quatre manques dont un contrat de port
progressif. Aucune mesure, aucun précédent de release cité ne soutient l'affirmation de tenue.

---

## D. La priorité étude / révision n'est pas tenue jusqu'au bout

§3 s'ouvre sur « **L'étude et la révision d'abord** » (`:153`) et la colonne « Bloque ? » désigne
**21** manques. **Sept d'entre eux n'apparaissent dans aucun lot** :

| Manque | Ce que la synthèse dit qu'il bloque | Lot |
|---|---|---|
| **DOC-1** (`:202`) | « **le plus gros gisement du domaine matières : la visionneuse (3 348 l)** » ; adopter aujourd'hui = **perdre 3 outils de surlignage** | **aucun** — `grep -n "DOC-1\|zcrud_document"` sur §4 → **RC=1** ; le paquet `zcrud_document` n'est nommé dans aucun périmètre de lot |
| **STU-5** (`:190`) | « pas de groupement par matière, pas de filtre par matière, pas de `SubjectStudyToolsPage` » | aucun (lot 7 = STU-1/2/3/4) |
| **STU-9** (`:194`) | « `ZExamEditor` n'est **pas adoptable en l'état** » et « il **ment** » | aucun |
| **STU-11** (`:196`) | « l'apprenant attend devant un écran figé » | aucun |
| **FLA-1** (`:160`) | « le drapeau `folderFlashcardsFilter` **ne peut pas basculer à parité** » | aucun — dégradé en « réserve à porter au brief » (`:298`) |
| **SES-8** (`:168`) | « le moteur et la vue d'examen blanc existent, **rien ne les propose** » | aucun |
| **SES-10** (`:170`) | « **OUI pour une adoption non destructive** » du carrousel | aucun |

Le cas **DOC-1** est le plus net : un manque à **surface additive** (ajouter trois valeurs en fin
d'enum), qui débloque **3 348 lignes** d'un domaine d'étude, et qui n'a **pas de lot**, quand le
lot 8 (aucun manque bloquant : `SCR-1/4/5/6`, `UI-1` sont tous « Non ») et le lot 9 (`FIR-1..5`,
tous « Non ») en ont un. Le tri par blocage-étude annoncé en `:153` n'a pas été appliqué à §4.

**SES-8** est du même ordre : cinq mots d'enum pour rendre atteignable un moteur d'examen blanc que
le socle possède déjà — pendant que le lot 5, qui le concerne, prend `SES-1..4` et le laisse dehors.

---

## E. Ce que la synthèse promet et que ses sources ne portent pas

1. ** `:133` « Total établi : ≈ 2 100 lignes, dont ≈ 420 estimées (entrée 1) et le reste mesuré ».**
   Faux sur deux comptes : l'entrée 17 (151 l) est « **NON ÉPROUVÉS** » et l'entrée 18 (220 l)
   « **NON ÉPROUVÉES** » — dans le tableau même. **Au moins 791 l sur 2 100 (38 %) ne sont ni
   mesurées ni éprouvées.**
2. **`:277-278` « `revealController` est […] la **seule** affirmation de tout le dossier à avoir
   survécu ».** Exact — mais posé comme argument de solidité d'un lot 1 dont trois entrées sur
   quatre (20, 21, 22) n'ont **jamais** été soumises à réfutation en tant que propositions : 21 et
   22 sont des *corrections dictées par* une réfutation, ce qui est plus solide encore, mais
   `ZcrudScope.derive` (entrée 20) n'a **aucune** contradiction (grep : aucun `refutation-*.md` ne
   contient `ZcrudScope.derive`). Le lot n'est pas homogène en niveau de preuve.
3. **`:295` lot 3 « ≈ 380 lignes, fonctions pures ».** `zApplyTestFilters` n'est pas adoptable à
   parité (FLA-1, `:160`), `zEvaluateLocally` coupe l'IA sur deux types sur quatre sans un
   adaptateur inexistant (A-3), `zAdvanceStreak` demande un port de persistance et une migration
   de données (C-2), et `zAdvanceStreak` porte un **arbitrage propriétaire non tranché**
   (`_gradedModes`, `:118` ; renvoi `:299`). Quatre des six entrées du lot portent une condition que le titre
   « fonctions pures » masque.
4. **`:366` « Ce qui reste à l'hôte DÉFINITIVEMENT ».** Deux lignes du tableau se démentent
   elles-mêmes : l'échafaudage de bascule (**≈ 1 300 l**) est dit « **temporaire par construction.
   Il disparaît avec le legacy** » (`:383`) et les 6 adaptateurs `z_backed_*` (**4 648 l**) « **Ils
   disparaissent quand l'hôte adopte l'entité du socle** » (`:384`). **5 948 lignes déclarées
   définitives par le titre et temporaires par leur propre cellule** — et reprises telles quelles
   dans la quatrième part de `:39`.
5. **`:261` « Les dépendances sont mesurées, pas supposées ».** Le lot 5 déclare dépendre du lot 4
   (`:316`) — juste. Le lot 7 déclare dépendre du lot 6 (`:336`) — plausible. Mais aucune des
   dépendances **manquantes** relevées en C-2 n'a été cherchée, et le lot 8 gate cinq canaux
   derrière `CORE-1` sans montrer où `ZCrudAction` intervient dans `SCR-1`/`SCR-4`/`SCR-5`/`UI-1`.

---

## F. Ce que cette critique n'établit pas

- **Je n'ai rien remesuré chez IFFD ni dans `packages/`.** Toutes les oppositions ci-dessus sont
  internes au dossier d'analyse : synthèse contre réfutation, synthèse contre confrontation,
  synthèse contre elle-même. Une contradiction entre deux documents ne dit pas lequel a raison —
  elle dit qu'un des deux doit être remesuré avant d'être annoncé.
- **Je n'ai pas relu les 33 réfutations en entier** (22 756 l pour l'ensemble du dossier) : j'ai
  lu en entier les cinq qui recouvrent une entrée de §2.1 (`ZMenuEntryTile`, `zEvaluateLocally`,
  `ZFlashcardHintPort`, `ZSrsConfig`, `ZHintPenaltyPolicy`, `revealController`) et les verdicts +
  bilans chiffrés des 28 autres. **Dix-neuf des vingt-quatre entrées de §2.1 ne sont couvertes par
  aucune réfutation** (recherche par symbole sur les 33 fichiers) : leur exactitude reste ouverte,
  et c'est le point le plus important de cette critique après A-1.
- **Aucun test lancé, aucun secret lu, aucun fichier hors de
  `docs/analyses/iffd-migration-2026-08-26/` écrit.**
