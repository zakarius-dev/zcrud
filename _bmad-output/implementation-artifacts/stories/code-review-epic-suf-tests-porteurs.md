# Code-review epic SUF — lentille « Tests porteurs » (discipline R3)

**Date** : 2026-07-26 · **Périmètre** : SUF-1 (`zcrud_ui_kit`), SUF-2/SUF-3 (`zcrud_study`),
SUF-4 (`zcrud_session` + démo assemblée + `example/test/offline_demo_test.dart`).
**Hors périmètre** (non lu, non jugé) : `packages/zcrud_markdown/`.
**Mode** : LECTURE SEULE — aucun fichier de `lib/` ni de `test/` modifié.

**Verdict global : RÉSERVES.**
La discipline R3 est réellement pratiquée (injections consignées, corpus durcis, deux défauts
RÉELS attrapés par les gardes neuves en SUF-4). Mais **trois trous de falsifiabilité prouvés**
subsistent : une assertion SM-1 structurellement incapable de rougir accompagnée d'un
« contrôle de falsifiabilité » qui ne contrôle rien ; un slot public (`addAction`) dont la
seule garde est vacuité pure ; une prop publique (`initialSelectedSubfolderId`) jamais
exercée. Aucun de ces trous n'invalide le code livré — ils invalident la **preuve** que le
code est verrouillé.

---

## 0. Vérif rejouée sur disque (par ce reviewer, pas sur la foi des rapports)

| Commande | Résultat |
|---|---|
| `cd packages/zcrud_ui_kit && flutter test test/z_page_shell_*.dart test/z_page_scaffold_*.dart test/z_searchable_app_bar_test.dart` | **22 tests, All tests passed** |
| `cd packages/zcrud_study && flutter test` (11 fichiers SUF-2/3/4) | **60 tests, All tests passed** |
| `cd packages/zcrud_session && flutter test test/presentation/suf4_parity_closures_test.dart` | **14 tests, All tests passed** |

_(Note : un premier lancement groupé côté `zcrud_study` a échoué en « loading » — pub get
concurrent du workstream parallèle ; relancé, 60/60 verts. Non imputable à l'epic SUF.)_

---

## 1. Instruction des DEUX aveux annoncés

### Aveu (1) — SUF-3 : « la garde SM-1 *la sélection ne rebâtit PAS Progression* n'est pas falsifiable »

**Aveu confirmé, et plus grave que ce que la story reconnaît.**

Source de l'aveu : `_bmad-output/implementation-artifacts/stories/suf-3-page-detail-dossier-sous-dossiers-adaptatifs.md:230`.

Ce que la story ne dit pas : **l'assertion tautologique est restée dans le fichier de test**,
sous un titre et un commentaire qui affirment le contraire de la réalité.

`packages/zcrud_study/test/z_study_folder_detail_sm1_test.dart`
```
25:  testWidgets('changer la sélection 10× reconstruit le corps Matériel, PAS Progression',
…
56:    // Tranche FIGÉE : Progression n'a pas rebâti (compteur constant).
57:    expect(progBuilds, progBaseline);
```

**Preuve de non-falsifiabilité (SDK, pas raisonnement) :**
- `packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:104-111` — le corps des
  onglets est un `TabBarView(children: [ … Builder(builder: tab.contentBuilder) … ])`.
- `/home/zakarius/flutter/packages/flutter/lib/src/material/tabs.dart:2524` — `_TabBarViewState.build`
  rend un **`PageView(children: _childrenWithKey)`** (aucun `allowImplicitScrolling`).
- `/home/zakarius/flutter/packages/flutter/lib/src/widgets/page_view.dart:693,707` —
  `this.allowImplicitScrolling = false` et
  `scrollCacheExtent ?? ScrollCacheExtent.viewport(allowImplicitScrolling ? 1.0 : 0.0)`
  ⇒ **cache extent 0** ⇒ seule la page COURANTE est construite/montée.

Conséquence : après le retour sur l'onglet Matériel (ligne 45-46), le sous-arbre Progression —
donc le `_Probe` qui incrémente `progBuilds` — **n'est plus dans l'arbre**. `progBuilds` ne peut
plus bouger, quelle que soit la réactivité de `ZStudyFolderDetail` : un `setState` de page, un
`ValueNotifier` global, une reconstruction totale à chaque frappe laisseraient l'assertion 57
**verte**. L'assertion n'exprime pas une propriété du code sous test, elle exprime une
propriété de `TabBarView`.

**Le « contrôle de falsifiabilité » ne contrôle pas cette garde.**
`z_study_folder_detail_sm1_test.dart:85-109` monte un `_Probe` dans un `StatefulBuilder`
**totalement étranger** à `ZStudyFolderDetail` et vérifie que `n` passe de 1 à 2. Cela prouve
que la classe `_Probe` compte ses `build` — jamais que le probe de la ligne 38 est **atteignable**
dans l'arbre du détail. C'est un oracle qui ne discrimine pas l'hypothèse en cause. La story en
tire pourtant l'inférence invalide (`suf-3-…md:221`) :
> « le test CONTRÔLE … prouve que la sonde `_Probe` s'incrémente sous un rebuild réel ⇒ les
> gardes « tranche figée » ne sont pas tautologiques. »

**La substitution annoncée, elle, EST réelle et mordante.** Vérifié sur disque :
- garde retenue : `z_study_folder_detail_sm1_test.dart:62-83` (« replier/déplier 10× NE
  reconstruit PAS le corps Matériel », `matCalls` figé) ;
- mécanique : `_collapsed` est consommé par un `ValueListenableBuilder` **imbriqué sous** la
  `Row` (`z_study_folder_detail.dart:303-353`), tandis que `_materialBody()` est un frère
  `Expanded` (`:279-284`). Porter le repli par un `setState` de page reconstruirait
  `ZPageScaffold` → nouvelle instance de `Builder` (`z_page_scaffold.dart:108`, non `const`)
  → `_materialTab` → `_materialBody()` → nouveau `ValueListenableBuilder` → `materialSectionsBuilder(id)`
  ré-invoqué ⇒ `matCalls` monte ⇒ ROUGE. Injection consignée par la story (`suf-3…md:216`,
  ligne AC14) et cohérente avec le code.
- la seconde assertion du test 1 (`:59 expect(matCalls, greaterThan(matBaseline))`) est elle
  aussi mordante (elle prouve que la sélection re-fournit bien le corps).

**Conclusion aveu (1)** : la garde de remplacement est suffisante pour l'AC ; **l'assertion
tautologique et son faux contrôle doivent partir ou être requalifiés** (cf. finding F1), sans
quoi le fichier ment sur sa propre couverture — exactement ce que R3 interdit.

### Aveu (2) — SUF-4 : « corpus 4/1 ⇒ fraction 0,5 symétrique, corrigé en 2/5 »

**Correctif RÉEL et SUFFISANT.** Vérifié sur disque.

`packages/zcrud_session/test/presentation/suf4_parity_closures_test.dart:114-144`
```
123:        await _pumpScoped(… total: 5, currentIndex: 1, style: linear …)
137:        expect(semantics.value, '2/5');
143:        expect(_linearOf(tester).value, closeTo(2 / 5, 1e-9));
```
- `position = (currentIndex+1).clamp(1,total) = 2`, `resolvedLinearValue = 2/5 = 0,4`
  (`z_session_progress_indicator.dart`, getters `position` / `resolvedLinearValue`).
- Discrimination effective : inversion `1 - v` = **0,6** ≠ 0,4 ; décalage `currentIndex/total`
  = **0,2** ≠ 0,4 ; constante quelconque ≠ 0,4 sauf collision fortuite. Les deux canaux
  (sémantique `'2/5'` / géométrie `value`) sont lus **sur des nœuds distincts et clés**
  (`progressKey` vs `linearKey`, helper `_linearOf` ligne 54) — pas de `find.byType` au hasard.
- Le cas symétrique 4/1 subsiste ailleurs (`:87-93`, `:255-260`) mais **aucune de ces deux
  assertions ne porte sur une fraction** (elles portent sur la présence/absence de nœuds et sur
  l'énumération des valeurs sémantiques `['2/4']`) : pas de rechute.

Le reste du fichier SUF-4 est, sur cette lentille, le plus solide de l'epic : ancrage sur des
**valeurs de tokens** et pas seulement sur des différences (`:168-172 expect(thin,4); expect(thick,11)`),
énumération **récursive** de l'arbre sémantique au lieu d'une sonde ponctuelle (`:270-284`),
contre-attentes systématiques avant l'action (`suf4_assembly_demo_test.dart:89-90,125`),
défaut historique verrouillé cran par cran (`:314-322`).

---

## 2. Findings

### F1 — MAJEUR — assertion SM-1 structurellement incapable de rougir + « contrôle » non-séquitur
**Fichier** : `packages/zcrud_study/test/z_study_folder_detail_sm1_test.dart:26,56-57` (et `:85-109`).

Détail et preuve SDK : §1 aveu (1). Ce que l'assertion laisse passer : **toute** régression de
granularité sur l'onglet Progression (état remonté en `setState` de page, notifier global,
reconstruction totale) — l'onglet n'étant pas monté, le compteur ne peut pas bouger.
Le titre du test (« …, PAS Progression ») et le commentaire `:56` affirment une couverture
inexistante ; le test `:85-109` s'annonce « CONTRÔLE de falsifiabilité » alors qu'il valide la
classe `_Probe`, pas l'atteignabilité du probe de la ligne 38.

**Correction attendue (au choix)** : (a) supprimer l'assertion `:57` et retitrer le test sur ce
qu'il prouve réellement (« la sélection re-fournit le corps Matériel ») ; (b) la rendre
falsifiable — injecter un `TabController` (`ZPageScaffold.tabController`, `z_page_scaffold.dart:56`)
et compter les rebuilds d'une tranche **restant montée** (structure de sidebar) plutôt que d'un
onglet hors-écran ; (c) a minima, remplacer le faux contrôle par une assertion prouvant que la
tranche observée est bien dans l'arbre au moment de la mesure
(`expect(find.byType(_Probe), findsOneWidget)` — qui **rougirait** aujourd'hui).

### F2 — MAJEUR — `ZStudyFolderDetail.addAction` : slot public jamais exercé, unique garde vacuité pure
**Fichiers** : `packages/zcrud_study/test/z_study_folder_detail_tabs_test.dart:92,103-105` ;
`packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart:204-208`.

La seule assertion existante sur ce slot est :
```
104:      // GARDE MORDANTE : rendre l'ajout inconditionnellement ferait apparaître
105:      expect(find.byIcon(Icons.add_circle), findsNothing);
```
**Preuves :**
- `grep -rn "add_circle" packages/zcrud_study/lib packages/zcrud_study/test` → **1 seul hit :
  la ligne 105 elle-même**. Aucune ligne de `lib/` ne peut produire cette icône : le widget ne
  rend que les icônes fournies par l'appelant. L'assertion est donc vraie **par construction**.
- `grep -rn "addAction:" packages/zcrud_study/test/z_study_folder_detail_*.dart
  packages/zcrud_study/test/z_subfolder_*.dart packages/zcrud_study/test/support/suf3_harness.dart`
  → hits uniquement sur `navSpec(addAction: …)` (le bouton « + » de la **sidebar**, AC13) et sur
  la plomberie du harnais. **Aucun test ne passe `addAction:` au widget.**
- `grep -n "addAction\|initialSelected\|sortAction\|menuActions\|search:" packages/zcrud_study/test/support/suf4_assembly_demo.dart` → **RC=1** (la démo ne l'utilise pas non plus).
- `grep -rn "ZStudyFolderDetail(" packages example | grep -v packages/zcrud_study/` → **RC=1**
  (aucun autre consommateur).

**Ce que ça laisse passer** : supprimer `if (widget.addAction != null) widget.addAction!`
(`z_study_folder_detail.dart:206`) — donc **perdre entièrement le slot d'ajout de l'app-bar** —
laisse les **60 tests verts**. L'AC3 (« slots d'action : absents si null, bon callback ») n'est
prouvée que pour `sortAction` et `menuActions`.

**Correction attendue** : un cas positif (`addAction` fourni ⇒ son icône présente + tap invoque
SON callback, et pas celui du tri), et une garde d'absence portant sur **l'icône réellement
injectée** dans le cas positif (pas une icône fantôme).

### F3 — MEDIUM — `initialSelectedSubfolderId` jamais exercé : la prop peut être ignorée sans rougir
**Fichiers** : `packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart:92,167,182` ;
`packages/zcrud_study/test/support/suf3_harness.dart:110,132`.

**Preuve** : `grep -rn "initialSelectedSubfolderId" packages/zcrud_study/test/` → 2 hits, tous
deux dans le **harnais** (déclaration du paramètre + passe-plat). Aucun test ne lui donne de
valeur non nulle ; `suf4_assembly_demo.dart` non plus (grep RC=1 ci-dessus).

**Ce que ça laisse passer** : remplacer `_selected = ValueNotifier<String?>(widget.initialSelectedSubfolderId)`
(`:182`) par `ValueNotifier<String?>(null)` — la prop devient décorative — laisse toute la suite
verte. C'est le défaut « paramètre déclaré mais jamais consommé » que SUF-4 traque explicitement
chez lui (`suf4_parity_closures_test.dart:193-195, 552-555`) et que SUF-3 ne traque pas chez lui.

### F4 — MEDIUM — migration `borderRadius:` → `shape:` non gardée sur le rayon (SUF-4, paire 1)
**Fichier** : `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart` —
`Material(color:…, borderRadius: BorderRadius.all(theme.radiusM))` devient
`Material(color:…, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(theme.radiusM), side: …))`.

**Preuve** : `grep -rn "borderRadius\|radiusM" packages/zcrud_session/test/` → **RC=1** (zéro hit
dans TOUT le répertoire de tests du package).

Le test « DÉFAUT = rendu HISTORIQUE » (`suf4_parity_closures_test.dart:309-323`) mesure
l'**alpha** (`material.color!.a == 1.0`) et le **côté** (`_sideOf(material) == BorderSide.none`)
— soit 2 des 3 dimensions touchées par le refactor. Le **rayon**, qui a changé de porteur
(`borderRadius:` → `shape:`), n'est vérifié nulle part : le recoder en dur
(`BorderRadius.circular(4)`) ou le perdre laisserait tout vert, alors que la story revendique un
défaut « STRICTEMENT inchangé ». `_sideOf` (`:71-75`) lit déjà le `RoundedRectangleBorder` : la
garde manquante coûte une ligne (`expect(shape.borderRadius, BorderRadius.all(theme.radiusM))`
avec un `gapS`/`radiusM` injecté distinct pour rester discriminante).

### F5 — LOW — deux oracles plus faibles que le titre qu'ils portent
1. `packages/zcrud_study/test/presentation/z_folder_card_test.dart:298,332-333` — le test
   s'appelle « **grille ≥ 2 colonnes**, itemHeight=…, no overflow » mais assert
   `expect(find.byType(ZFolderCard), findsWidgets)` : `findsWidgets` = « **au moins un** ».
   Une grille dégénérée à 1 colonne reste verte. (Le volet « no overflow » est, lui, réel :
   porté par `takeException()` + le mécanisme de pending-exception du binding.)
2. `packages/zcrud_ui_kit/test/z_page_shell_rtl_a11y_test.dart:39-57` — le test s'appelle
   « **Semantics** bascule + cible ≥ 48 dp » et le commentaire `:52` affirme « la bascule loupe
   porte un label a11y » : **aucune assertion sémantique n'existe**, le `handle =
   tester.ensureSemantics()` (`:40`) n'est jamais interrogé, seule la taille est mesurée.
   Retirer le label de la bascule ne rougirait pas.

---

## 3. Observations non retenues comme findings (traçabilité)

- **Périmètre du scanner statique SUF-3.** `suf3_source_guard_test.dart` ne couvre que AC1
  (0 `AppBar(`) et AC16 (imports bannis), alors que l'AC15 promettait aussi « 0 `Colors.` /
  0 forme non-directionnelle / 0 libellé en dur ». **Pas un trou** : vérifié que
  `test/presentation/z_widgets_hardcode_scan_test.dart` scanne **récursivement**
  `Directory('lib/src/presentation')` (`:37-50`) — donc les 5 fichiers SUF-3 et
  `z_folder_card.dart` — sans liste figée (`grep -rn "z_study_folder_detail\|z_subfolder\|z_folder_card"`
  sur les deux scanners → **RC=1**, aucune énumération à maintenir). Le renvoi est d'ailleurs
  documenté en tête de `z_study_folder_detail_rtl_a11y_test.dart:3-5`.
- **Garde RTL de position de la sidebar** (`z_study_folder_detail_rtl_a11y_test.dart:15-30`) :
  elle discrimine bien l'ancrage **end** (inverser l'ordre des enfants de la `Row`), mais **pas**
  l'injection annoncée dans la story (`suf-3…md:114` : « remplacer un `EdgeInsetsDirectional.only(start:)`
  par `EdgeInsets.only(left:)` → la garde de position RTL rougit ») — un inset interne ne
  déplace pas le bord droit d'un `SizedBox` posé par une `Row`. Seule la garde **statique**
  attraperait cette injection-là. Claim de story imprécis, garde utile : non retenu.
- **Consignation R3 incomplète en SUF-3** : la table d'injections (`suf-3…md:210-218`) compte
  **7 lignes pour 16 ACs** (AC2, AC3, AC4, AC5, AC6, AC8, AC13, AC15, AC16 sans injection
  consignée), alors que la convention de la story (`:59`) exige une ré-injection **par garde**.
  Les gardes correspondantes existent et sont, à la lecture, mordantes — sauf celles des
  findings F2/F3. Signalé comme dette de preuve, pas comme finding autonome.
- **`example/test/offline_demo_test.dart`** (ajout `purge`/`putMerged` au fake `ZLocalStore`) :
  correction d'une erreur de compilation pré-existante ; le fake retourne un `Left(ZCacheFailure)`
  **explicite** sur `putMerged` plutôt qu'un faux merge silencieux — choix conforme à la lentille
  (pas de repli muet qui ferait passer une perte de clés pour un succès). RAS.
- **SUF-1 AC6 (SM-1 app-bar)** (`z_page_shell_sm1_test.dart`) : garde **mordante**, contrairement
  au cas F1 — le corps d'onglet mesuré est celui de l'onglet **courant** (donc monté), et
  l'injection consignée (`suf-1…md:220` : envelopper `onQueryChanged` d'un `setState` du
  scaffold) le reconstruirait effectivement (même chaîne `ZPageScaffold` → `Builder` non-`const`
  → `contentBuilder`). Non retenu.

---

## 4. Synthèse

| # | Sévérité | Objet | Effet si non corrigé |
|---|---|---|---|
| F1 | MAJEUR | assertion SM-1 non falsifiable + faux contrôle de falsifiabilité | la granularité de l'onglet Progression n'est verrouillée par rien, et le fichier prétend le contraire |
| F2 | MAJEUR | `addAction` (app-bar) jamais exercé ; garde sur icône fantôme | suppression complète du slot ⇒ suite verte |
| F3 | MEDIUM | `initialSelectedSubfolderId` jamais exercé | prop publique réductible à une décoration ⇒ suite verte |
| F4 | MEDIUM | rayon non gardé après `borderRadius:` → `shape:` | régression visuelle du défaut « historique inchangé » invisible |
| F5 | LOW | 2 oracles plus faibles que leur titre (`findsWidgets`, a11y non asserté) | fausse confiance de couverture |

Aucun HIGH : aucune garde de l'epic ne masque un défaut fonctionnel **actuel** — les trous sont
des trous de **falsifiabilité**, pas des bugs livrés.
