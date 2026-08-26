# État des lieux v2 — migration d'IFFD vers zcrud

**Date** : 2026-08-26. **Remplace `etat-des-lieux.md` (v1, 517 l), qui ne doit plus être cité.**
**Hôte** : `/home/zakarius/DEV/iffd` @ `65d1af9` (`feat/migration-zcrud`) pour tout le relevé ;
**revérifié ce jour à `c329439`**, arbre **non propre** (3 modifications, celles du propriétaire —
cf. §2.2). Lecture seule stricte de mon côté. **Socle** : `/home/zakarius/DEV/zcrud` @ `cc276c154` = **v3.21.0**, 41 paquets.
**Matière** : 11 cartes, 11 confrontations, 5 catalogues, 33 réfutations, plus **quatre
réconciliations** écrites après la v1 : `reconciliation-decisions-hote.md` (273 l),
`reconciliation-chiffres.md` (339 l), `reconciliation-transverse.md` (324 l),
`critique-synthese.md` (234 l).

> **Ordre d'autorité appliqué ici** : (1) les arbitrages du propriétaire d'IFFD, (2) les chiffres
> dédupliqués, (3) le transverse, (4) la critique de la v1, (5) le reste du relevé. Une
> recommandation qui contredit une décision prise a été **retirée**, ou porte en toutes lettres
> qu'elle demande de revenir sur cette décision.

---

## 1. Ce qui a changé depuis la v1, et pourquoi elle est inutilisable

### 1.1 Le relevé avait été écrit sans connaître les décisions de l'hôte

Grep négatif fondateur (`reconciliation-decisions-hote.md:9-19`) : aucun fichier du relevé, hors
`critique-completude.md`, ne cite `decisions-adoption-zcrud.md`, `plan-modeles-zentity-codegen.md`,
`chiffrage-migration-chat.md` ni `dette-bugs-preexistants.md` (RC=1) ; aucun ne mentionne
RACINE-1/2/3, DEC-9, DEC-14 ni DEC-16 (RC=1). **35 arbitrages** contraignaient la migration ; le
relevé en contredisait **six** et en refacturait **au moins sept** déjà planifiés.

### 1.2 Six recommandations retirées parce qu'une décision les a déjà tranchées contre

| Recommandation v1 | Décision qui prime | Effet |
|---|---|---|
| Annoter `@ZcrudModel` les 6 modèles de dossier, **639 l** (`confrontation-etude-dossiers.md:173-182`) | **DEC-9** (`decisions-adoption-zcrud.md:271-274`) : « ne pas annoter » — une seconde entité canonique concurrente de `ZStudyFolder`, déjà tranché par CR-IFFD-9 | **−562 l** ; seul `folder_invitation.dart` (77 l, groupe 🅱️, déjà planifié N3-e) survit |
| Codegen des 2 modèles de chat, **≈ 677 l**, « 16 `Timestamp` retirés » (`confrontation-ia-chat-generation.md:165-180`) | **Option B** (`chiffrage-migration-chat.md:290-313`) : zéro migration Firestore, projection unidirectionnelle gardée par deux tests de `test/w9a/` | **−677 l** ; la proposition **fait rougir la garde par construction** et déclenche le §4.2 (date ISO relue `null`, conversation dans le désordre, sans erreur ni journal) |
| `ZPersistAs.timestamp` + `$XxxTimestampFields` présentés comme **le** canal | **DEC-14 / D6** : conversion **au repository** ; aucune des 17 entités du socle n'emploie le mécanisme | retiré ; le canal n'agit que via `FirebaseZRepositoryImpl`, qu'IFFD n'utilise pas |
| « **Lot 2 — la suppression, à faire avant tout portage** » (v1 `:281-290`) | **M9** (`plan-migration-zcrud-v2.md:544-546`) : ne pas commencer avant M3/M4/M5 closes — le retrait est irréversible | le lot passe **en dernier** (§6) |
| « **Lot 1** : `ZSrsConfig(minQuality: 1)` et `ZHintPenaltyPolicy(floor: 5)` en premier » | **Capturer avant de corriger** (`dette-bugs-preexistants.md:7-21`) + **DEC-16** (story dédiée **M1-3b**, famille données) | les deux entrées **changent une donnée persistée** : elles sortent du premier lot |
| Tout chiffrage de codegen sans `fieldRename: ZFieldRename.none` | **RACINE-3** : une seule migration de schéma, dans M7 ; clés fautives `accademicYear`/`folderExplaination` **préservées** | omission de sûreté : le défaut `ZFieldRename.snake` écrirait `subject_id` là où la base contient `subjectId` — **perte silencieuse à la première écriture** |

Correction rédactionnelle (C7) : les « 16 paquets non déclarés » de la v1 `:28` comptent **six
paquets écartés avec motif** par DEC-4 (`zcrud_html`, `zcrud_geo`, `zcrud_geo_location`,
`zcrud_reorder`, `zcrud_provider`, `zcrud_get`) et un « sur besoin » (`zcrud_dnd`). Ce n'est pas
un écart : c'est une décision fermée.

### 1.3 Les chiffres de la v1 qui sont faux

| ❌ Ne plus citer | ✅ Remplaçant | Source |
|---|---|---|
| « **12 250 l** de code mort » | **≈ 4 717 l** certifiées + ≈ 7 595 l en attente d'une passe de joignabilité transitive | `reconciliation-chiffres.md:§1.5` |
| « `appointment_editor.dart` = 7 858 l mortes » / « 2 500 l migrables » / « manque au socle, 3 200 l » | **0 l certifiée** : le fichier est un `part of '../workspace.dart'` (`:2`, déclaré `workspace.dart:95`) ; ≈ 263 l sont **vivantes par ses frères** (`_EndRule` ×20 dans `recurrence_picker.dart`) | `reconciliation-chiffres.md:§1.2` |
| « **1 753 l** migrables vers `zcrud_list` » (`confrontation-formulaires-crud.md:656`) | **1 753 l de code MORT** — `DynamicListScreen` a **un** site de construction, `agents_screens.dart:176`, dans `AgentsScreen` qui en a **zéro**. Migration sans objet, **`zcrud_list` sans justification** | `reconciliation-chiffres.md:§4.3` |
| « **175 l** de `showZConfirmDialog` » ×5 confrontations (≈ 590 l sommées) | **175 l, une seule fois** (`forms_utils.dart:480-662`), propriétaire `socle-app` ; les **36 sites d'appel** à réécrire sont un **coût** | `reconciliation-chiffres.md:§4.1` |
| « **191 l** de coquille sur 4 formulaires » | **582 l** (convention *Screen → EOF*, remesurée à la ligne : 250+117+91+124) ; 191 est un sous-ensemble strict | `reconciliation-chiffres.md:§2` |
| « ≈ 160 conservés (**4 fonctions `presentXEdition`**) » | ces fonctions **n'existent pas** (grep négatif ×4, 0 appel à `presentFormEdition` dans les 4 fichiers) ; ce sont ≈ 160 l **à réécrire** aux sites d'appel `*_dialogs.dart` | `reconciliation-chiffres.md:§2` |
| « **24 manques dont 9 bloquent** » (v1 `:38`) | **57 manques dont 21 bloquent** (recomptés à la ligne sur §3 de la v1) | `critique-synthese.md:B-1` |
| « ≈ **6 500 l** immobilisées » (v1 `:38`) | **orphelin** : une seule occurrence dans les 60 fichiers du dossier, aucune dérivation. Retiré | `critique-synthese.md:B-2` |
| « **Total établi : ≈ 2 100 l** » (v1 `:133`) | la colonne somme à **2 316**, dont **371 l** explicitement NON ÉPROUVÉES. Voir §2.3 | `critique-synthese.md:B-3` |
| « `ZMenuEntryTile`, ≈ **420 l**, rang 1 » | **≈ 45-60 l** — trois réfutations démolissent l'arithmétique « 8 l./tuile × 53 » ; le seul essai réel de l'hôte a coûté **+241 l écrites, −0 supprimée** (v1 `:421-423`) | `critique-synthese.md:A-1` |
| « allumer les 12 bascules du domaine dossiers dans `main.dart:201-210` » | **aucune bascule dossier n'est active à cette ancre**, qui en lève huit d'autres domaines (`carte-etude-dossiers.md:197`) | `critique-synthese.md:B-4` |
| « `agents_screens.dart` dans `lib/data_crud/` » · « `ExamAnswer` importé par 2 fichiers » · « `lib/data_crud/` = 19 fichiers » | `lib/agents_screens.dart` (649 l) · **3** fichiers · **24** fichiers / 14 980 l | `reconciliation-chiffres.md:§1.3, §3` |
| 249 sites non directionnels · 2 225 couleurs · 122 tiers · 13 deps sans import | **321** / 68 f. · **2 601** / 157 f. · **123** · **17** | `reconciliation-transverse.md:§1` |

### 1.4 Trois défauts de méthode de la v1, non reconduits ici

1. **Une affirmation démentie survivait en tête** de la liste « migrable » (rang 1). Ici, toute
   entrée est accompagnée de son statut de preuve, et les non-éprouvées sont **hors du total**.
2. **L'ordre de bataille ne routait que 10 des 24 entrées** — 84 % du volume n'appartenait à aucun
   lot — et **7 des 21 manques bloquants** (DOC-1, STU-5, STU-9, STU-11, FLA-1, SES-8, SES-10)
   n'apparaissaient nulle part, pendant que les lots 8 et 9, sans aucun manque bloquant, existaient.
3. **Le transverse était absent** : la découpe par domaine le rendait structurellement invisible.

---

## 2. Le verdict, dédupliqué

### 2.1 Les volumes (inchangés, mesurés)

`iffd/lib` : **549 fichiers**, **179 222 l** (531 f. / 171 835 l hors généré). **110 fichiers**
portent `import 'package:zcrud_` (196 imports). **23 paquets zcrud** en `dependencies:`, **2** en
`dependency_overrides:` seulement (`zcrud_annotations:577`, `zcrud_responsive:682`), **48** entrées
épinglées `ref: v3.21.0`.

### 2.2 Les quatre parts

| Part | Volume | Nature |
|---|---:|---|
| **Déjà migré — écrit, compilé, et NON VALIDÉ** | **19 170 l** (62 fichiers `*zcrud*.dart`), **à requalifier à la baisse** | **52 bascules** déclarées (`z_qa_flags.dart`), **55 constantes `k…UseZcrudDefault` dont 54 à `false`** ; plan QA : **198 cases `[ ]`, 0 case `[x]`** (`critique-completude.md:373-381`). Et le seau **recoupe le code mort** : `agents_filter_zcrud_edition.dart` (246 l) est un jumeau dont le seul appelant est un écran mort. Recouvrement établi sur 2 fichiers, **non balayé sur les 62** |
| **Migrable aujourd'hui, sans une ligne de socle** | **≈ 1 084 l** (§3) | dérivation en §2.3 |
| **Suppression de code mort** (ni socle, ni migration) | **≈ 4 717 l** certifiées | `reconciliation-chiffres.md:§1.5` ; + ≈ 7 595 l en attente de mesure |
| **Nécessite du travail au socle** | **57 manques, dont 21 bloquent** une capacité d'étude ou de révision ; **≈ 995 l** d'hôte immobilisées par trois d'entre eux (§4.3) | §4 |
| **Reste à l'hôte définitivement** | ≈ 12 000 l de règle métier — **et non les 5 948 l d'échafaudage**, qui sont temporaires par construction (§7) | §7 |

> 🔬 **Mesuré le 2026-08-26, postérieurement au relevé** : le fil A **a commencé**, et son premier
> résultat est un refus. `iffd` est passé de `65d1af9` à **`c329439`** (un seul commit, **docs
> seulement — 0 ligne de `lib/` modifiée**, `git diff --stat 65d1af9..HEAD -- lib` → sortie vide :
> tous les chiffres de §3 et §4 tiennent). Mais l'arbre de travail porte **3 modifications non
> commitées**, dont `lib/main.dart` : les **trois bascules du chat du lot 1 de QA ont été allumées,
> comparées au legacy, puis RÉÉTEINTES le jour même** — *« la séance a trouvé DEUX écarts non
> documentés (le dossier perd son pli et son « + », la date passe à droite du titre) […] la bascule
> attend l'arbitrage du propriétaire »* (`lib/main.dart:210-215`, non commité). Et le compte de
> cases n'a pas bougé : `grep -o "\[ \]" docs/qa-plan-comparaison-legacy-zcrud.md | wc -l` → **198**,
> `[x]` → **0**, **sur l'arbre de travail modifié**. ⇒ **Le premier lot de QA réel a produit deux
> écarts sur trois bascules et zéro bascule retenue.** C'est la mesure la plus dure du dossier sur
> ce que vaut « déjà migré », et elle est arrivée après que les 60 fichiers du relevé ont été écrits.

⚠️ **Les deux totaux ne s'additionnent pas dans le même budget** : ≈ 4 717 l est une **suppression**
(aucun paquet, aucune API) ; ≈ 1 084 l est une **migration** (adoption de canaux existants).

### 2.3 Comment on passe de « ≈ 2 100 l » à « ≈ 1 084 l »

| Poste | l. |
|---|---:|
| Somme réelle de la colonne « Lignes » du tableau v1 §2.1 (recomptée) | **2 316** |
| − entrées 17 (mindmap) et 18 (chat), marquées NON ÉPROUVÉES dans le tableau même | −371 |
| − entrée 3 `ZSessionSummaryView`, non éprouvée **et** comptée deux fois (tableau + liste « s'y ajoutent ») | −200 |
| − entrée 1 `ZMenuEntryTile` ramenée de 420 à ≈ 50 par trois réfutations concordantes | −370 |
| − entrées 4 (`ZFlashcardHintPort`, 130) et 7 (`zEvaluateLocally`, 100) : **subordonnées à un port absent du socle** → §4 | −230 |
| − entrées 11 (`zAdvanceStreak`, 59) et 16 (`ZCascadeRegistry`, 30) : elles **corrigent des défauts livrés**, donc soumises à « capturer avant de corriger » → lot H2 (§6) | −89 |
| + entrée 5 remesurée : la définition réelle de `buildConfirmDialog` fait **175 l**, non 150 | +25 |
| + les 3 commentaires périmés qui gèlent deux paquets | +3 |
| **= migrable aujourd'hui, sans une ligne de socle** | **≈ 1 084** |

*(Cette somme est celle du tableau §3, entrée par entrée : 131+150+175+77+80+60+42+40+40+36+50+0+0+200+3.)*

Une addition naïve des dix totaux de confrontation rendrait **≈ 27 325 l**
(`reconciliation-chiffres.md:§5.1`) : elle compte `showZConfirmDialog` jusqu'à cinq fois, la
coquille de formulaire deux fois, `dynamic_list_screen.dart` en gain alors qu'elle est morte, et
additionne des périmètres qui se recouvrent sur 17 417 + 18 178 + 14 980 l. **Ce chiffre n'a
jamais été écrit — c'est précisément celui que produit un lecteur pressé.**

---

## 3. MIGRABLE AUJOURD'HUI — la liste courte

> **Règle** : n'apparaît ici que ce qui a **survécu à une réfutation** ou a été **remesuré sur
> disque**, et qui **ne demande aucune ligne de socle**. Les non-éprouvées sont en §3.2, hors total.

| # | Canal du socle (`fichier:ligne`) | Cible hôte | Lignes | Preuve / réserve |
|---:|---|---|---:|---|
| 1 | **`revealController` (`ZToggleController`)** `zcrud_flashcard/…/z_flashcard_review_card.dart:110, :175` ; `zcrud_core/…/state/z_display_state.dart:254` | débloque `ReviewCardZcrudView` (`review_card_zcrud.dart`, 180 l écrites, jamais raccordées) | non chiffré | 🟢 **La SEULE affirmation du dossier passée à la réfutation adversariale et TENUE** — 5 ancres sur 5 exactes |
| 2 | **`ZFolderContentsOrder`** `zcrud_study_kernel/…/z_folder_contents_order.dart:115` + `zSectionKey` `:52` + `applyOrder<T>` `apply_order.dart:41` | `folder_study_tools_page.dart:227-310` + `:311-357` | **131** | corrige un **shadowing vérifié** dans `getSortedIterms` |
| 3 | **`ZAdaptiveGrid`** `zcrud_responsive/…/z_adaptive_grid.dart:63, :89` | `exams_page.dart:123-180`, `folder_progress_page.dart:87-140`, 4 `GridView.count` | **≈ 150** | ⚠️ **précondition** : `zcrud_responsive` n'est **pas** une dépendance déclarée (override `:682` seulement). Un override ne confère aucun droit d'import |
| 4 | **`showZConfirmDialog`** `zcrud_ui_kit/…/z_confirm_dialog.dart:129` | `buildConfirmDialog` (`forms_utils.dart:480-662`) **une fois** | **175** | 36 sites d'appel à réécrire = **coût**. Borné par **UI-1** (aucun jeton de thème, aucun slot d'ornement) |
| 5 | **`ZEmptyState`** `zcrud_ui_kit/…/z_state_widgets.dart:31` | `EmptyTasksWidget`, `daily_tasks_page.dart:560-636` | **77** | ⚠️ le rendu **change** (`Container(borderRadius: 24, α 0.5)` → état neutre) ; borné par **UI-3** |
| 6 | **`ZFeedbackTier`/`zFeedbackTierFor`** `zcrud_session/…/z_session_feedback.dart:32, :104` + `ZDefaultFeedbackBank` `:51` | `learning_mode_question_card.dart:99-190` | **≈ 80** | seuils **identiques des deux côtés**, vérifiés (`exceptionalUnder = 10 s`, `exceptionalMaxHints = 0`) |
| 7 | **`zApplyTestFilters`** `zcrud_flashcard/…/z_flashcard_filters.dart:206` + `ZFlashcardTestFilters` `:107` + `zMasteryLevelOf` `:75` + `zDrawQuestions` `:461` | `lib/src/utils/flashcard_filters.dart` (90 l) | **≈ 60** | seuils identiques borne pour borne. ⚠️ **FLA-1 manque** : deux axes de filtre sur cinq restent à la main |
| 8 | **`zCategorize`** `zcrud_flashcard/…/z_session_categorization.dart:91` + `zIndexSrsById` `:56` | `flashcard_widgets.dart:837-878` | **≈ 42** | supprime un quadratique ; tri **décoré par index** (l'hôte ne stabilise pas) |
| 9 | **`ZFlashcardEditionFields.type()/.choices()/.trueFalse()`** `zcrud_flashcard/…/z_flashcard_editors.dart:89, :100, :109` | `flashcard_edition_zcrud.dart:187-193` | **≈ 40** | `registerZFlashcardEditors` **est déjà appelé** (`z_iffd_field_registry.dart:171`) ; sans `editorKind`, les trois widgets sont du code mort |
| 10 | **`zFoldDiacritics`** `zcrud_core/…/z_search_text.dart:115` + `ZSearchFolding.diacriticsAndSpaces` `:49` | `normalizedText`/`unaccentedText` (`data_functions.dart:55, :118`), **22 sites** | **≈ 40** | couvre **strictement plus** (`œ→oe`, `æ→ae`, `ß→ss`, `ĳ→ij`) |
| 11 | **`ZDiscardChangesGuard`** `zcrud_ui_kit/…/z_discard_changes_guard.dart:50` (`canPop: !dirty` `:104`) | **13 `canPop: true` sur 16 `PopScope(`** | **≈ 36** | le vrai gain est une **capacité absente** : aucune garde anti-perte de saisie n'existe aujourd'hui |
| 12 | **`ZMenuEntryTile`** `zcrud_menu/…/z_menu_entry_tile.dart:31` + `ZItemAction.toMenuEntry()` + `zVisibleMenuEntries` `:194` | les dialogues d'actions | **≈ 50** | 🔴 **ramené de 420 à ≈ 50** ; l'assiette recoupait `smartnote_actions_dialog_widget.dart`, **supprimé comme code mort** (≈ 48 l comptées deux fois) |
| 13 | **`ZcrudScope.derive`** `zcrud_core/…/zcrud_scope.dart:478` | `z_iffd_field_registry.dart:345` — **1 ligne** | **0** | **28 `ZcrudScope(`** contre **0 `.derive`** : chaque scope local **masque** les 12 seams racine. ✅ compatible **DEC-24** (« les scopes locaux restent légitimes ») |
| 14 | **`ZSubListConfig.summaryColumns`** `z_sub_list_config.dart:294` + `.itemFormPresentation` `:427` | 0 site hôte | **0** | deux paramètres `const`. ✅ conforme **DEC-15** (adopter le nouveau défaut compact) |
| 15 | **`ZIffdTextStreamPort`** `zcrud_chat_syncfusion/…/z_iffd_stream_port.dart:40` + `ZIffdLexer` `:98` + `zIffdChannelOfTag` `z_iffd_wire.dart:53` | table fermée de 4 balises recopiée : `discovry_ai_page.dart:100-135` + `iffd_ai_repository_impl.dart:130-300` | **≈ 200** | le port est **déjà adopté par l'hôte ailleurs**. ✅ compatible **option B** : c'est de la présentation, aucune écriture Firestore |
| — | *(hors migration)* correction de **3 commentaires périmés** qui gèlent deux paquets | `pubspec.yaml:292`, `:326`, `study_tools_zcrud_adapter.dart:69` | 3 | faux : IFFD est en Syncfusion `^34.1.31` (`:141-149`) ; `grep -n zcrud_export packages/zcrud_flashcard/pubspec.yaml` → **RC=1** |

**Total ≈ 1 084 l**, dont ≈ 50 estimées (entrée 12) et le reste mesuré. La réconciliation des
chiffres publie une enveloppe économisable dédupliquée de **≈ 2 450 l**
(`reconciliation-chiffres.md:§5.3`) : l'écart est **entièrement** constitué de la coquille
`presentFormEdition` (≈ 765 l), que je classe ici **non migrable aujourd'hui** parce que **SCR-1**
la rend destructrice, et des entrées déplacées ci-dessus. Aucune ligne n'est perdue : elles
changent de seau.

### 3.1 Deux entrées de la v1 déplacées, pas retirées

`ZSrsConfig(minQuality: 1)` et `ZHintPenaltyPolicy(floor: 5)` (v1 entrées 21-22, 0 l) sont des
**défauts latents réels**, mesurés : `ZQualityScale.fromConfig` rend `[0..5]` — six paliers dont un
« Ok » à note 0 ; et `zApplyHintCeiling` est appliqué **inconditionnellement**, alors que le jumeau
porté affirme l'inverse. Mais **ce sont des bascules de famille C** (elles changent une donnée
persistée) : **DEC-16** leur donne la story **M1-3b**, et la règle « capturer avant de corriger »
(`dette-bugs-preexistants.md:7-21`) impose le test de caractérisation d'abord. Elles vont au §6, lot 2.

### 3.2 Non éprouvé — à remesurer avant d'être promis (hors total)

`ZSessionSummaryView` (≈ 200 l annoncées ; `ZCelebrationSpec` a 11 champs et **aucun `colors`** →
perte des 6 couleurs de confetti) · `ZChatNotebookScreen` (≈ 330 l) · `ZChatToolCatalog` + feuille
d'outils (136 l mesurées, ≈ 600 l annoncées) · les petits lots mindmap (≈ 151 l) ·
`zChatConversationActions` / `ZChatExportService` (≈ 220 l).

---

## 4. MANQUE AU SOCLE — l'étude et la révision d'abord

**57 manques recensés, 21 bloquants.** La colonne « bloque » dit si le manque empêche une capacité
d'étude ou de révision, pas s'il est gênant. La colonne « décisions » dit si le manque est
compatible avec les arbitrages déjà pris.

### 4.1 Les 21 bloquants, par paquet

| # | Manque | Paquet | Décisions |
|---|---|---|---|
| **MD-1** | Retour à la ligne souple non déclarable (`softLineBreak`, CR-IFFD-115, `zcrud-change-requests.md:7675`) — **le seul manque qui fausse la lecture d'un corpus de production** : chaque note, explication IA et question est recollée en pavé | `zcrud_markdown` | ✅ CR ouverte du pilote, additive, rendu inchangé par défaut |
| **MD-2** | Géométrie fermée du tableau rendu (CR-IFFD-114, `:7589`) | `zcrud_markdown` | ✅ |
| **DOC-1** | Trois natures d'annotation (`underline`, `strikethrough`, `squiggly`) — valeurs d'enum **additives** ; débloque la visionneuse de **3 348 l**, le plus gros gisement du domaine matières | `zcrud_document` | ✅ additif. 🔴 **Absent de tout lot de la v1** |
| **SCR-1** | Aucun mode « fusionner sur `initialValues` » sur `presentFormEdition` | `zcrud_screen` | ⚠️ **doit être opt-in** : changer le défaut casserait les hôtes existants |
| **CORE-1** | `ZCrudAction` fermé à 11 valeurs ; IFFD en gouverne **17** (chez IFFD, générer avec l'IA **est** un droit CRUD) | `zcrud_core` | ✅ apport propre du relevé, non planifié côté hôte |
| **SES-1** | Mode **contrôlé** de la saisie de réponse (`initialAnswer`/`onAnswerChanged`/`isSubmitted`) | `zcrud_session` | à articuler avec **M1-3** / DEC-16 |
| **SES-2** | Slot de rendu riche pour les **libellés de choix** (les choix sortent en `Text(choice.content)` nu, `:1090`) | `zcrud_session` | dépend de MD-1 |
| **SES-3** | Champ de réponse rédigée pluggable (aujourd'hui `TextFormField` nu, `:1246-1291`) | `zcrud_session` | dépend de MD-1 |
| **SES-4** | « Je ne sais pas » distinct d'une réponse fausse (5ᵉ seau, **drapeau explicite**, jamais une note-sentinelle) | `zcrud_session` | ✅ |
| **SES-8** | `ZSessionModeKind.whiteExam` absent du sélecteur — le moteur et la vue existent, **rien ne les propose** | `zcrud_session` | 🔴 absent de tout lot v1 |
| **SES-10** | Le swipe ne peut pas noter ; la file ne peut pas muter sans reset d'index (`didUpdateWidget:365-388`) | `zcrud_session` | 🔴 absent de tout lot v1 |
| **FLA-1** | Filtrer par **identifiant** de source (`documentId`, `noteId`), pas seulement par `kind` | `zcrud_flashcard` | 🔴 absent de tout lot v1 ; borne l'entrée 7 de §3 |
| **STU-1** | Aucun assemblage « génération IA → revue → matérialisation » pour la carte mentale (332 l recopiées 7 fois, **déjà divergentes**) | `zcrud_study` | ✅ |
| **STU-2** | `ZNoteSummaryPort` n'a **aucun consommateur** | `zcrud_study` | ✅ |
| **STU-3** | Aucun chemin « one-tap » note → cartes persistées (409 l sur 5 sites) | `zcrud_study` | ✅ |
| **STU-4** | Port de génération à contrat **progressif** — tous les ports du socle sont one-shot, l'hôte est progressif | `zcrud_study` | ✅ ; à concevoir **par route** (décision d'owner du 2026-08-23) |
| **STU-5** | Aucun rattachement typé d'un dossier à une **matière** (`subjectId` sur `ZStudyFolder`) | `zcrud_study_kernel` | 🔴 absent de tout lot v1 |
| **STU-9** | `ZExamEditor` n'a pas le rappel **hebdomadaire** — l'entité sait déjà porter les deux modèles, seul l'éditeur manque | `zcrud_study` | 🔴 absent de tout lot v1 |
| **STU-11** | Aucun port d'explication **en flux** | `zcrud_study` | ✅ ; **par route** |
| **GEN-1/2/3** | Émission en `extension` (jamais en membres) ; champs hérités **non collectés**, perte **silencieuse** ; `_classify` sans branche `Map` — **49 champs** non classifiables chez IFFD, dont 36 `Map<…>` | `zcrud_generator` | ⚠️ conditionnés par **RACINE-3** (`ZFieldRename.none`) et par les 5 obstacles de `plan-modeles-zentity-codegen.md:139-224` |

### 4.2 Les non-bloquants qui portent le plus de risque

**FIR-1** (`zcrud_firestore`) — aucune voie d'écriture **fusionnante**. `save` écrit en `batch.set`
**nu** (`:1020`) là où le `put` de l'hôte fusionne. En cutover strangler-fig, où les deux moteurs
co-écrivent le même document, **un seul `save` détruit le filet de rollback par bascule de
drapeau**. Ce n'est pas un confort : c'est la condition de réversibilité de toute la migration.

**SCR-3** (`maxWidth`/`maxHeight`/`sheetFrame` absents de `presentFormEdition`, alors que
`presentEdition` qu'il appelle les porte), **SCR-4** (état vide injectable), **SCR-5** (passe-plat
FAB vers `ZPageScaffold`, **qui les a déjà** `:67-68`), **SCR-6** (liste groupée), **UI-1**
(`ZConfirmDialog` sans jeton de thème), **UI-3** (`ZEmptyState`, `size: 48` codé en dur) : chacun
borne l'adoption d'un canal déjà listé en §3.

### 4.3 Ce que trois manques immobilisent, chiffré

| Manque | Immobilise | l. |
|---|---|---:|
| **SCR-1** (+ SCR-3) | la coquille `presentFormEdition` sur **12 fichiers** — 925 l brutes, **≈ 765 l nettes** (`reconciliation-chiffres.md:§2`). Sans le mode fusionnant, un `update` porté réécrit `folder_document` **amputé de `id`, `folderId`, `subFolderId`**, et l'examen **perd 5 clés sur 9, dont `id`** — une mise à jour devient une création | **≈ 765** |
| **port d'évaluation absent** (`ZFlashcardAnswerEvaluationPort` — grep négatif : zéro implémentation) | v1 entrées 4 et 7 : sans lui, questions ouvertes et exercices **perdent leur note IA et tombent à un 3 plat** | **≈ 230** |
| **Total immobilisé par le socle** | | **≈ 995** |

---

## 5. LE TRANSVERSE — ce que la v1 ne voyait pas

Mesuré avec les **sept regex de la garde du socle elle-même**
(`packages/zcrud_core/test/purity/style_purity_test.dart:42-49`), appliquées à `iffd/lib`.

| Sujet | Hôte | Ce que la bascule rachète |
|---|---|---|
| **Directionnel (AD-13)** | **321** occ / **68** f. (dont `EdgeInsets.only(left\|right` 107, `Alignment.*Left/Right` 104, `Positioned(left\|right` 46, `BorderRadius.only(` 27, `fromLTRB(` 24, `TextAlign.left/right` 13) | tout widget du socle est déjà directionnel. **Aucun risque visuel en `fr` (LTR)** — le gain est théorique tant que l'app est monolingue |
| **A11y** | 🔴 **26 `Semantics(` — TOUS dans les 110 fichiers qui importent déjà `package:zcrud_*` ; les 439 fichiers non portés en contiennent ZÉRO** (grep négatif montré, sortie vide). Densité : socle 0,66/f. (542/825), hôte 0,047/f. — **facteur 14** | toute l'accessibilité de l'hôte est arrivée **avec** l'adoption du socle. Elle ne se propage pas par osmose aux 439 autres |
| **Thème (FR-26)** | **2 601** couleurs en dur dédupliquées / **157** f. (`Colors.<nom>` 1 964, `Color(0x…)` 601, `fromARGB` 19, `fromRGBO` 17) | 🔴 **le seul risque de régression réel.** L'hôte passe déjà `theme:` et `colorKeyResolver:` **calibrés pour compenser** ; toute correction du socle rendant une couleur native **s'additionne** à sa compensation (motif CR-LEX-76). La bascule efface au mieux **24 %** (432 dans `data_crud/`, 197 si `workflow/` suivait) |
| **L10n** | **0** `.arb`, **pas de `l10n.yaml`**, **0** `AppLocalizations`, `supportedLocales = [Locale("fr")]` (`main.dart:51`), **332** littéraux dans un `Text(`. `ZcrudLocalizationsDelegate` **est monté** (`main.dart:312`) mais **`ZcrudScope.labels` n'est jamais passé** (3 sites `labels:`, tous des paramètres de widget) | le socle localise **ses** libellés. Il n'y a pas de dette de traduction : il n'y a **aucune infrastructure** |
| **Hors-ligne (AD-9)** | **0** import de `hive`, **0** occurrence de `connectivity`, aucun store local, aucune persistance Firestore configurée. Nuance : la **convention** `ZSyncMeta` est adoptée (85 occ., LWW sur `updated_at` documenté `z_backed_flashcard_repository.dart:74`) sans la **machinerie** (5 fichiers importent `zcrud_firestore`) | **rien.** Aucun écran porté ne devient offline-first : il faut *choisir* d'instancier `ZOfflineFirstRepository`/`HiveZLocalStore` |
| **Objectif produit n°1** | **420 `setState`** / 54 f. — mais **0 dans les 27 fichiers `*_zcrud_edition.dart`** (le moteur tient sa promesse là où il est adopté). Répartition : `src/features` 186, `workflow/` **158**, `data_crud/` 62, divers 14. **66 `setState(() {})` VIDES** (16 dans `data_crud/edition_screen.dart`, 4 073 l ; 6 dans `dynamic_list_screen.dart`) ; **40** déclenchés depuis un `onChanged:`, dont 4 vides — *le jank à la frappe, à la lettre* | 🔴 **au mieux 31 %** : 62 (`data_crud/`, meurt avec le moteur) + ~68 (dialogues portables, plafond optimiste). **≈ 290 restent** à la charge de l'hôte, dont les 158 de `workflow/` qui **ne sont pas un problème de formulaire** |
| **Binding** | 🔴 **`zcrud_riverpod` est déclaré au `pubspec` et JAMAIS importé** (unique occurrence : un commentaire, `z_backed_folder_repository.dart:17`) pendant que **136 fichiers** importent `flutter_riverpod` directement | le binding officiel est payé en résolution et contourné en pratique. ✅ **DEC-5** demandait de monter `ZcrudRiverpodScope` **et de réinjecter les seams** — la première moitié n'est pas faite |
| **Seams non alimentés** | 5 seams de `ZcrudScope` jamais passés (grep négatif, sortie vide) : `listRenderer`, `filePicker`, `cloudStorage`, `richTextRenderer`, `resolver` | le `listRenderer` manquant **explique la survie** de `dynamic_list_screen.dart` |
| **Filet** | 25 gardes de source côté hôte (parité, tripwires, anti-GetX), **aucune** sur le directionnel, les couleurs ou la sémantique. **0 golden**, 10 avec `Directionality`, 8 testant le mode sombre | — |

**Le geste transverse le moins cher, et il n'est pas dans le socle** : recopier les sept regex de
`style_purity_test.dart:42-49` dans une garde de source côté hôte, ancrée sur `lib/`, avec une
**liste d'exemption nominative des 68 fichiers actuels**. C'est un **cliquet** : le stock reste,
rien ne s'y ajoute, chaque fichier porté sort de la liste. C'est exactement le patron que l'hôte
pratique déjà (`test/s2/l10n_extraite_test.dart`, `test/m0/formulaires_socle_tripwires_test.dart`)
— appliqué aux domaines, jamais au transverse.

---

## 6. L'ORDRE DE BATAILLE

**Deux fils en parallèle**, conformément à **RACINE-2** (③ : les deux de front) : le **fil A** est
la mise en service des bascules (M1, propriété de l'hôte) ; le **fil B** est le travail de socle.
Ce document n'a rien à ajouter au fil A **sauf une mesure** : 52 bascules, 54 constantes sur 55 à
`false`, **198 cases de QA à `[ ]`, zéro à `[x]`**. Tant que ce compte ne bouge pas, « déjà migré »
veut dire « écrit », pas « validé ». Et la première séance réelle (chat, 2026-08-26) a **rendu deux
écarts sur trois bascules et n'en a retenu aucune** (§2.2) : le fil A n'est pas une formalité de QA,
c'est là que le portage se fait démentir.

| Lot | Périmètre | Paquets | Dépend de |
|---|---|---|---|
| **S1** 🔴 **premier lot de socle** | **SCR-1** (fusion sur `initialValues`) + **FIR-1** (écriture fusionnante `SetOptions(merge:)`) — les deux **opt-in**, jamais par changement de défaut | `zcrud_screen`, `zcrud_firestore` | — |
| **S2** *(parallèle à S1, paquet disjoint)* | **MD-1**, **MD-2**, **MD-3** — trois CR ouvertes du pilote, additives, rendu inchangé par défaut | `zcrud_markdown` | — |
| **S3** *(parallèle, paquet disjoint)* | **DOC-1** — trois valeurs d'enum additives, `highlight` reste le repli | `zcrud_document` | — |
| **H1** *(hôte, parallèle)* | `ZcrudScope.derive` (**1 ligne**, `z_iffd_field_registry.dart:345`) · raccorder `revealController` · les 3 commentaires périmés | aucun | — |
| **H2** *(hôte)* | **Caractériser avant de corriger** : `minQuality`, `floor`, la flamme au changement d'heure (`folder_flashcards_repetitions_page.dart:148`), la cascade sans `await` (`folders_repository.dart:137-142`) | aucun | H1 |
| **S4** | **CORE-1** (`ZCrudAction` ouvert ou additif : `move` + les 6 droits IA) | `zcrud_core` | — |
| **S5** | **SES-1..SES-4**, **SES-8**, **SES-10**, **FLA-1** + le **port d'évaluation** manquant | `zcrud_session`, `zcrud_flashcard` | S2 (SES-2/SES-3 n'ont d'intérêt que si le markdown se lit droit) |
| **H3** *(hôte)* | Le domaine pur de la révision : `zApplyTestFilters`, `zCategorize`, `zFeedbackTierFor`, `zFoldDiacritics`, `ZFlashcardEditionFields`, `ZFolderContentsOrder`, `ZEmptyState`, `showZConfirmDialog`, `ZDiscardChangesGuard`, `ZAdaptiveGrid` (**+ 1 entrée de `pubspec.yaml`**) | aucun | H2 pour ce qui touche une donnée ; S5 pour `zEvaluateLocally` |
| **S6** | **STU-1..STU-5**, **STU-9**, **STU-11** — assemblages de génération et d'étude. Contrat **par route** (décision d'owner, 2026-08-23) | `zcrud_study`, `zcrud_study_kernel`, `zcrud_mindmap` | S4 (les gestes de génération sont gouvernés par les droits IA) |
| **S7** | **SCR-3..SCR-6**, **UI-1**, **UI-3** — ce sans quoi le portage d'écran de liste est une perte nette (les réfutations mesurent **24 % à 30 %** du gain annoncé) | `zcrud_screen`, `zcrud_ui_kit` | S4 |
| **H4** *(hôte)* | La coquille `presentFormEdition`, 12 fichiers, **≈ 765 l nettes** | aucun | **S1** (sans SCR-1, l'`update` détruit des champs) |
| **S8** | **N0** (les 3 verrous de l'hôte) → **N1** (pilote d'un seul modèle) → **GEN-1/2/3**, **GEN-6** (fenêtre `analyzer`) → **N3-a** (Valuation, 581 l) et **N3-b** (CGI, ~810 l), **groupe 🅱️ uniquement**, `ZFieldRename.none` | `zcrud_generator`, `zcrud_firestore` | tout le reste. 🚫 **jamais le groupe 🅰️** (DEC-9), 🚫 **jamais les modèles de chat** (option B) |
| **H5** *(hôte, EN DERNIER)* | Suppression du code mort, **≈ 4 717 l** certifiées | aucun | **M3, M4 et M5 closes** (`plan-migration-zcrud-v2.md:544-546`) |

### 6.1 Lequel lancer en premier, et ce qui peut le faire échouer

**Côté socle : S1.** Deux hôtes en cutover strangler-fig co-écrivent les mêmes documents ; tant que
`save` écrase totalement et que `presentFormEdition` rend `zNormalizeFormValues` (champs
**déclarés** seulement) là où l'hôte émet `controller.values` (**toutes** les tranches semées),
**chaque écran porté qui écrit peut détruire des données et le filet de rollback**. C'est le seul
lot dont l'absence rend les autres dangereux.

**Ce qui peut le faire échouer, nommément** :
1. **Changer le défaut au lieu d'ajouter un opt-in.** `merge: true` par défaut modifierait la
   sémantique de suppression de champ pour les **17 entités** et pour lex_douane et DODLP. Le
   handoff devra distinguer **hôte passif** et **hôte ayant compensé** — les hôtes qui fusionnaient
   à la main doivent **retirer** leur compensation.
2. **Un tripwire d'hôte qui rougit par conception.** IFFD garde des tests qui *affirment la perte*
   (`test/w6/study_tools_zcrud_test.dart:1561-1586`). Corriger l'amont les fait rougir : c'est le
   comportement voulu, mais il faut le prévoir dans le handoff, pas le découvrir.
3. **Aucun test n'a été lancé pour établir SCR-1.** Le constat vient de la lecture de
   `present_form_edition.dart` et de `zNormalizeFormValues`, pas d'un rouge. À reproduire par un
   test avant d'écrire le correctif.
4. **Le volume en base est illisible depuis les dépôts** (documents sans `is_deleted`, corps sans
   `id`) : l'ampleur de la perte n'est pas mesurable ici, seulement son existence.

**Côté hôte : H1**, parce qu'il ne peut pas se tromper — une ligne, et le raccordement d'un portage
déjà écrit. Son risque n'est pas technique : les 28 scopes locaux cessent de masquer les 12 seams
racine, ce qui **change le rendu** de tout ce qui en dépendait ; et le vrai coût reste la QA, dont
les 198 cases sont à zéro.

---

## 7. Ce qui reste à l'hôte — définitivement, et temporairement

**Définitivement** (le socle ne porte pas de règle métier ; ce sont les paramètres que ses seams
attendent) : la matrice d'autorisations CRUD par ressource (`lib/src/domain/security/`, 4 f.,
**902 l**) et l'année académique en suffixe de clé (`"FolderModel$accademicYear"`) · la nomenclature
`FiliereEtCycleIFFD`/`NiveauIFFD`/`CycleIFFD` · les **29 prompts pédagogiques** et **6 corpus
juridiques** · le Système Harmonisé douanier (`ZFlashcard.extra` + `ZExtension` sont faits pour ça,
AD-4) · `IffdRichTextCodec` (193 l — le corpus est du markdown, jamais du Delta ; le défaut
`ZDeltaCodec` viderait ~11 400 valeurs) · le double format `content` et les orthographes fautives
**contractuelles** `accademicYear`/`folderExplaination` (préservées jusqu'à M7, RACINE-3) · la
génération PDF **distante** des flashcards (la substituer serait un changement de produit) ·
`Task extends google_api.Task` / `Event extends google_api.Event` — frontière d'intégration Google,
et motif explicite de **DEC-11** (`workflow` hors codegen) · le routage (26 routes, `app_router.dart`
270 l + 2 601 l générées ; `zcrud_navigation/pubspec.yaml:16` déclare n'en pas vouloir) · le chrome
de marque des écrans d'authentification (grep négatif : `class Z.*Login|Z.*Auth|Z.*Splash` → RC=1) ·
le plan comptable SYSCOHADA, la cotation, l'agenda `lib/workflow/`.

🔴 **Correction de la v1** : elle rangeait **5 948 l** sous « définitivement » que ses propres
cellules déclaraient temporaires — l'échafaudage de bascule (55 `const bool k*Default`, 67
`Provider<bool>`, `z_qa_flags.dart` 985 l, ≈ **1 300 l**), *« temporaire par construction, il
disparaît avec le legacy »*, et les **6 adaptateurs `z_backed_*`** (**4 648 l**), *« ils
disparaissent quand l'hôte adopte l'entité du socle »*. Ce sont le **prix de la transition**, pas
la part définitive.

**À propager, et c'est une pratique d'hôte** : le **tripwire** — un test qui *affirme la perte* sur
chaque défaut amont contourné. Quand l'amont corrige, il rougit et désigne le doublon, au lieu de
croire un handoff sur parole. C'est le pendant exact de la discipline R3 côté socle.

---

## 8. Les limites de ce document

1. **Aucun test lancé, aucune compilation, aucun `pub get`**, dans aucun dépôt. Rien ici n'atteste
   qu'un canal *fonctionne* — seulement qu'il *existe*, à telle ligne, avec tel corps.
2. **Tout verdict de mort repose sur des greps de symboles** avec filtre homonyme : un usage par
   réflexion, par chaîne de route ou par `build_runner` n'apparaîtrait pas.
3. **La passe de joignabilité transitive dans `appointment_editor.dart` n'a pas été menée** — c'est
   pourquoi son gain est **0** et non ≈ 7 595 l. L'unité de suppression y est le **type**, pas le
   fichier.
4. **Le recouvrement « déjà migré » ∩ « code mort » est établi sur deux fichiers seulement**, non
   balayé sur les 62 jumeaux `*zcrud*.dart` : **les 19 170 l sont à requalifier**, et le chiffre de
   la première ligne du tableau §2.2 est un plafond.
5. **≈ 765 l (coquille) sont un plancher** : les 8 fichiers hors des 4 communs n'ont pas été
   remesurés en convention *Screen → EOF*.
6. **19 des 24 entrées de la v1 §2.1 n'étaient couvertes par aucune réfutation.** Les cinq que
   j'ai reclassées ou retirées l'ont été sur preuve ; les autres reposent sur une remesure d'auteur
   unique, non contradictoire — exactement le dispositif qui a produit **32 démentis sur 33**.
7. **Les volumes en base de production sont illisibles depuis les dépôts** (documents sans
   `is_deleted`, part de cartes `flowchart`, corps sans `id`). Trois verdicts de perte de données
   en dépendent pour leur **ampleur**, pas pour leur **existence**.
8. **GEN-6 (fenêtre `analyzer`) est le point le plus incertain** : `zcrud_generator` exige
   `analyzer >= 12.0.0 < 14.0.0`, `iffd/pubspec.lock` résout **9.0.0**. Non résolu, non compilé.
9. **`smartnote_ai_instructions_zcrud_edition.dart` (≤ 311 l)** est hors total tant que l'import de
   `z_qa_flags.dart:82` n'est pas qualifié.
10. **Le transverse n'a pas été profilé** : la classification des 420 `setState` est structurelle
    (motif + site d'appel), pas mesurée en performance ; le rendu RTL n'a pas été observé.
11. **Aucun secret n'a été lu.** Aucune écriture hors de
    `docs/analyses/iffd-migration-2026-08-26/`.

### Date de péremption

Ce document mesure `iffd @ 65d1af9` et `zcrud @ cc276c154` (**v3.21.0**). Il **périme** :
- **déjà, partiellement** : au moment où j'écris, `iffd` est à `c329439` (docs seulement) avec **3
  modifications non commitées** dont `lib/main.dart`. Les chiffres de code tiennent (0 ligne de
  `lib/` modifiée depuis `65d1af9`) ; l'état des bascules, lui, **change d'heure en heure** ;
- au **prochain commit** de `feat/migration-zcrud` — l'hôte réécrit ses registres de CR en place ;
- à la **prochaine version publiée du socle** — **DEC-23** engage l'hôte à adopter
  **automatiquement** toute version, donc §3 et §4 peuvent devenir faux sans qu'aucune décision
  soit prise. Sur les sept CR ouvertes le 2026-08-25, **quatre ont été retirées avant émission
  parce que le canal existait déjà** (`zcrud-change-requests.md:7787, :7825, :7859, :7879`) : le
  motif dominant de ce dossier n'est pas un écart de version, c'est un **écart de connaissance**.

Conduite à tenir avant de se servir de §3 ou §4 : **rejouer les greps cités**. Un chiffre de ce
document qui ne se retrouve pas sur disque doit être remesuré, jamais reconduit.
