# Réconciliation des chiffres — relevé IFFD ↔ zcrud (2026-08-26)

> **Objet** : lever les contradictions et les doubles comptages du relevé (60 fichiers,
> 22 756 l), et produire des totaux dont on puisse se servir.
> **Méthode** : chaque chiffre repris ici a été **remesuré sur disque** dans
> `/home/zakarius/DEV/iffd` (lecture seule). Un chiffre sans mesure citée est marqué
> **NON MESURÉ** et ne doit pas être annoncé.
> **Référence disque** : `iffd @ 65d1af9` — `lib/` = **549 fichiers `.dart`, 179 222 lignes**
> (`find lib -name '*.dart' -exec cat {} + | wc -l`).

---

## 1. Le code mort — les trois filtres, appliqués

La critique a établi qu'aucune des affirmations de code mort du relevé n'avait passé les trois
filtres. Ils sont appliqués ici à **chacune des sept cibles** de `etat-des-lieux.md:§2.0`
(≈ 12 250 l annoncées).

**Les trois filtres** : (a) le fichier est-il un `part` ? (b) chaque type / fonction de premier
niveau est-il consommé ailleurs, **y compris par un `part` FRÈRE de la même bibliothèque** ?
(c) l'occurrence trouvée est-elle un vrai usage, ou un **homonyme** / un commentaire / un
littéral de chaîne ?

### 1.1 Le fait structurel que trois lectures avaient manqué

`lib/` contient **64 fichiers `part of`** (`grep -rn '^part of ' --include='*.dart' lib | wc -l` → 64)
sur **21 bibliothèques**. Dans un `part`, **aucun `import` ne peut apparaître** : toute analyse de
code mort fondée sur les imports y est **structurellement aveugle**. « 0 import » n'y prouve rien.
⚠️ Balayer les **deux formes de guillemets** : `lib/workflow/workspace.dart:84-110` déclare ses
27 `part` en guillemets **doubles** et disparaît d'un `grep "^part '"`.

### 1.2 `appointment_editor.dart` (7 858 l) — verdict tranché

`lib/workflow/screens/appointment_editor.dart` est un **`part of '../workspace.dart'`**
(`:2`), déclaré par `workspace.dart:95`.

- **Aucun import ne peut y apparaître** : une analyse de code mort fondée sur les imports est
  structurellement aveugle à un `part`. « 0 import » ne prouve donc RIEN.
- Ses **26 types** ont été testés un à un : **cinq sont réellement consommés par deux `part`
  FRÈRES** de la même bibliothèque — `_EndRule` **20 fois** dans
  `lib/workflow/components/recurrence_picker.dart`, et `_DeleteDialog`, `PickerChangedDetails`,
  `_ResourcePicker` dans `lib/workflow/screens/event_editon_screen.dart` (3 occurrences). Étant
  dans la même bibliothèque, même les symboles **privés** y sont légitimement visibles.
- Un sixième usage apparent, `ListX`, est un **HOMONYME** : une extension déclarée indépendamment
  dans `lib/src/utils/extensions/native_types_extensions.dart:37`. Un grep par nom ne distingue
  pas un homonyme d'un usage.
- **Verdict** : le fichier n'est **ni mort, ni « migrable 2 500 l », ni « manque au socle »**. Ses
  points d'entrée (`AppointmentEditor`, `PopUpAppointmentEditor`, `AppointmentEditorWeb`,
  `SelectRecurrenceRuleDialog`, `CalendarColorPicker`, `CalendarTimeZonePicker`) sont morts ; son
  corps est vivant par ses frères.

Preuve de la répartition (grep unique sur les cinq symboles contestés, hors le fichier lui-même) :

```
$ grep -rn "\b_EndRule\b\|\bPickerChangedDetails\b\|\b_ResourcePicker\b\|\b_DeleteDialog\b\|\bListX\b" \
    --include='*.dart' lib | grep -v "^lib/workflow/screens/appointment_editor.dart:" \
    | awk -F: '{print $1}' | sort | uniq -c
  1 lib/src/presentation/features/flashcards/pages/multi_flashcard_editor_page.dart   ← homonyme ListX
  1 lib/src/utils/extensions/native_types_extensions.dart                             ← homonyme ListX
 20 lib/workflow/components/recurrence_picker.dart                                    ← FRÈRE, _EndRule
  3 lib/workflow/screens/event_editon_screen.dart                                     ← FRÈRE
```

**Conséquence chiffrée** : la surface consommée par les frères mesure **≈ 263 l**
(`PickerChanged`+`PickerChangedDetails` `:63-80`, `_ResourcePicker` `:813-877`, `_DeleteDialog`
`:6426-6594`, `_EndRule` `:6845-6855`). Le solde (≈ 7 595 l) n'est atteignable **que** par les six
points d'entrée morts — mais **personne n'a mené la passe de joignabilité transitive** qui
prouverait qu'aucun d'eux n'est requis par les 263 l survivantes. **Chiffre citable aujourd'hui :
0 ligne certifiée supprimable dans ce fichier.** L'unité de suppression est le **type**, pas le
fichier, et la mesure reste à faire.

### 1.3 Les six autres cibles — filtres appliqués

Filtre (a) : **aucune** des six n'est un `part`.
```
$ for f in lib/agents_screens.dart lib/data_crud/dynamic_list_screen.dart \
      lib/data_crud/categorysation_screens.dart lib/data_crud/models.dart \
      lib/src/presentation/features/flashcards/pages/white_exam_page.dart \
      lib/src/data/repositories/firebase_owner_scoped_repetition_store.dart; do
    head -8 "$f" | grep -cE "^part of"; done
  0  0  0  0  0  0
```
⚠️ **Deux chemins de `etat-des-lieux.md:§2.0` sont faux** : `agents_screens.dart` vit à
`lib/agents_screens.dart` (649 l), **pas** dans `lib/data_crud/`.

| Cible | Annoncé | Filtre (b) — usages hors du fichier | Verdict |
|---|---:|---|---|
| `dynamic_list_screen.dart` (1 753 l) | dans les 2 362 | `ListDisplayMode` **1**, `DynamicListScreen` **1** — les deux dans `agents_screens.dart:176/178` ; `ActionButtonsMode`, `DynamicSearchDelegate`, `CrudActionsButons`, `DynamicItemsNotifier`, `DynamicListScreenState` → **0** | **MORT** ✅ |
| `agents_screens.dart:113-649` (537 l) | dans les 2 362 | `AgentsScreens` **0**, `SpecialiteFilterType` **0**, `AgentsScreen` **4 occurrences, toutes commentaire ou littéral** (`agents_filter_zcrud_edition.dart:8,10,88` ; `z_qa_flags.dart:766`) — filtre (c) : **0 site de construction** | **MORT** ✅ |
| `categorysation_screens.dart` (43 l) + `models.dart:275-303` (29 l) | dans les 2 362 | — | **MORT** ✅ (repris tel quel) |
| SmartNotes : `SmartnoteActionsDialogWidget` (417) + 3 dialogues (259) + `NoteSelectorDropdown` (212) = 888 | 888 | `SmartnoteActionsDialogWidget` → 1 usage, `smartnotes_dialogs.dart:150`, **à l'intérieur de `showSmartNoteActionsDialog` qui a 0 appelant** ; `showSummaryCustomInstructionsDialig` / `showMindmapCustomInstructionsDialig` → 2 occurrences chacune, **toutes commentaire ou littéral** (`z_qa_flags.dart:573-574`, `smartnote_ai_instructions_zcrud_edition.dart:6-7`) ; `NoteSelectorDropdown` → **0** | **MORT** ✅ |
| `white_exam_page.dart` (753 l, hors `ExamAnswer` `:754-779`) | 753 | `WhiteExamPage` → 3 occurrences : 1 commentaire (`flashcard_widgets.dart:1191`) + 2 dans `app_router.gr.dart` **généré**, route absente de l'arbre du routeur | **MORT** ✅ — mais `ExamAnswer` est importé par **3** fichiers vivants, pas 2 (`white_exam_question_card`, `interactive_flashcard_repetition_card`, `learning_mode_question_card`) |
| mindmap : `MindmapActionsDialogWidget` (216) + `showMindmapActionsDialog` (35) + hooks (63) = 314 | 314 | `showMindmapActionsDialog` → **1 seule occurrence, sa définition** (`mindmap_dialogs.dart:145`) ; `MindmapActionsDialogWidget` → 1 usage, à l'intérieur d'elle | **MORT** ✅ |
| `firebase_owner_scoped_repetition_store.dart` (154 l) | 154 | `FirebaseOwnerScopedRepetitionStore` → **1 occurrence hors fichier, une dartdoc** (`z_backed_folder_document_repository.dart:285`) | **MORT** ✅ |
| 4 modules de 0 octet | 0 | `wc -c` → 0 ×4 | **MORT** ✅ (gain nul) |

### 1.4 Deux gisements morts que le relevé n'avait PAS comptés

Le filtre (b) mené sur les **jumeaux zcrud** révèle du code mort **du côté déjà migré** :

| Fichier | Lignes | Preuve |
|---|---:|---|
| `lib/agents_filter_zcrud_edition.dart` | **246** | `presentAgentsFilterEdition` → 2 occurrences hors fichier, **toutes deux dans `agents_screens.dart` (:11 import, :235 appel)**, donc dans l'écran mort. Aucun autre appelant. |
| `smartnote_ai_instructions_zcrud_edition.dart` (partiel) | ≤ **311** | son seul consommateur exécutable est `_presenterInstructionsParLeSocle` (`smartnotes_dialogs.dart:412`), appelé uniquement depuis les deux dialogues d'instructions morts (`:196`, `:310`). Reste 1 import dans `z_qa_flags.dart:82` (drapeau), à qualifier avant suppression. |

🔴 **Ces lignes sont aussi comptées dans les 19 170 l « déjà migré » de `etat-des-lieux.md:§1.2`.**
Les seaux « déjà migré » et « code mort » **se recoupent** et le relevé ne le dit nulle part.

### 1.5 Total corrigé du code mort

| Poste | Annoncé §2.0 | Corrigé | Écart |
|---|---:|---:|---:|
| `appointment_editor.dart` | 7 818 | **0** (verdict §1.2 — aucune passe transitive faite) | **−7 818** |
| `dynamic_list_screen` + `agents_screens:113-649` + `categorysation_screens` + `models:275-303` | 2 362 | **2 362** | 0 |
| SmartNotes | 888 | **888** | 0 |
| `white_exam_page.dart` | 753 | **753** | 0 |
| mindmap | 314 | **314** | 0 |
| `firebase_owner_scoped_repetition_store.dart` | 154 | **154** | 0 |
| 4 modules vides | 0 | **0** | 0 |
| *(neuf)* `agents_filter_zcrud_edition.dart` | — | **+246** | +246 |
| *(neuf, à qualifier)* `smartnote_ai_instructions_zcrud_edition.dart` | — | *(≤ 311, NON RETENU)* | — |
| **TOTAL** | **≈ 12 250** | **≈ 4 717** | **−7 533 (−61 %)** |

**À ne plus citer : « 12 250 lignes de code mort ». Remplaçant : « ≈ 4 717 lignes de code mort
certifiées, plus ≈ 7 595 lignes en attente d'une passe de joignabilité transitive dans
`appointment_editor.dart` ».**

---

## 2. `presentFormEdition` — 191 contre 582 : laquelle est fausse

**Ni l'une ni l'autre ne mesure la même chose.** Ce ne sont pas deux conventions de comptage d'une
même cible : ce sont **deux cibles de migration différentes**, dont l'une contient l'autre.

| | `confrontation-formulaires-crud.md:162-176` | `confrontation-etude-matieres-corpus.md:93-99` |
|---|---|---|
| Cible | **garder** la classe `…Screen`, remplacer son corps | **supprimer** la classe `…Screen` entière |
| Compte | `chrome build→body:` + `dispose()` + bloc `ZEditionSubmitController` | déclaration du `Screen` → EOF |
| Sur les 4 fichiers communs | **191** | **582** |
| Portée | **12** fichiers (534 l) | **4** fichiers |

**Remesure sur disque des quatre empans** — la convention « Screen → EOF » est **exacte à la ligne** :

```
ai_router_zcrud_edition.dart          class @436, EOF 685  → 250   ✅ (annoncé 250)
valuation_tool_model_zcrud_edition.dart class @232, EOF 348 → 117  ✅ (annoncé 117)
folder_document_zcrud_edition.dart    class @122, EOF 212  →  91   ✅ (annoncé  91)
subject_zcrud_edition.dart            class @605, EOF 728  → 124   ✅ (annoncé 124)
                                                     Total = 582   ✅
```

**Lecture du contenu** (`folder_document_zcrud_edition.dart:122-212`, lu en entier) : la classe ne
contient **que** l'échafaudage — `initialData`/`title`/`onSubmit`, `_fields`/`_controller`/`_submit`,
`initState`, `dispose`, `_onSave`, `IffdZcrudScope`+`Scaffold`+`AppBar`+`IconButton`, et
`body: DynamicEdition(...)`. Aucune règle métier. `presentFormEdition` couvre l'ensemble.

⇒ **582 est le bon chiffre pour ces 4 fichiers ; 191 est un sous-ensemble strict et doit être
retiré.** La convention `formulaires-crud` sous-évalue son propre gain : elle conserve une coquille
qui n'a plus de raison d'être une fois la route poussée par `presentFormEdition`.

🔴 **Un détail de `etude-matieres` est faux** : le « ≈ 160 conservés (**4 fonctions
`presentXEdition`**) ». Ces fonctions **n'existent pas** —
```
$ grep -nE "^Future<[^>]*> present" <les 4 fichiers>   → RC=1 (aucune ligne)
$ grep -c "presentFormEdition" <les 4 fichiers>        → 0  0  0  0
```
Les quatre écrans sont construits directement depuis un `*_dialogs.dart`
(`subject_model_dialogs.dart:132`, `documents_dialogs.dart:61`,
`valuation_tool_model_dialogs.dart:50`, `ai_routers_dialogs.dart:55`). Les ≈ 160 l « conservées »
sont en réalité des lignes **à réécrire au site d'appel**, pas des lignes existantes à garder. Le
net ≈ 420 reste **conservateur** (donc citable), mais sa justification est à corriger.

**Chiffre réconcilié pour le canal `presentFormEdition`** :

| Poste | Lignes | Statut |
|---|---:|---|
| 4 fichiers, coquille entière (convention B) | **582** brut | mesuré, à la ligne |
| 8 autres fichiers, fragments seuls (convention A : 534 − 191) | **343** | mesuré bloc à bloc |
| **Brut, 12 fichiers, sans recouvrement** | **925** | |
| Réécriture aux sites d'appel (estimée) | **≈ −160** | estimée |
| **NET CITABLE** | **≈ 765** | plancher — les 8 fichiers n'ont pas été mesurés en convention B |

---

## 3. Table de propriété — un périmètre, un propriétaire

Périmètres revendiqués par plus d'une carte. **Lignes remesurées sur disque.**

| Périmètre | Disque (f. / l.) | Revendiqué par | **Propriétaire attribué** | Motif |
|---|---:|---|---|---|
| `lib/workflow/` | **38 / 17 417** | `carte-socle-app.md:11` **et** `carte-taches-decouverte.md:19` | **taches-decouverte** | l'objet du dossier (listes de tâches, agenda, événements) est le domaine « tâches », pas l'administration/auth/réglages |
| `lib/src/presentation/features/flashcards/**` | **35 / 18 178** | `carte-revision-flashcards.md:13`, `carte-revision-srs-sessions.md:12`, **et** `carte-examens.md:31/708-723` (par inclusion nominative) | **revision-flashcards** | carte la plus large sur ce chemin ; `srs-sessions` et `examens` y **empruntent** des fichiers nommés — leurs gains doivent être attribués au propriétaire |
| `lib/data_crud/` | **24 / 14 980** | `carte-socle-app.md:11` (« ajout hors périmètre », **19 f.** — faux) **et** `carte-formulaires-crud.md:14` (**24 f.** — juste) | **formulaires-crud** | c'est le moteur d'édition/liste legacy, objet même de cette carte |
| `lib/src/utils/functions/forms_utils.dart` | **1 / 1 193** | `carte-socle-app.md:14` + consommé par **14 dossiers** | **socle-app** | transverse par nature ; ses gains ne se répartissent pas par domaine (cf. §4.1) |
| `lib/src/presentation/features/administration/` | 22 / 9 430 | socle-app seul | **socle-app** | — |
| `lib/src/presentation/features/tasks/` + `discovery/` | 18 / 5 252 | taches-decouverte seul | **taches-decouverte** | — |

**Règle à appliquer** : un gain mesuré sur un fichier appartient au **propriétaire du périmètre**
qui contient ce fichier. Une carte qui « inclut au-delà » (le mot est de
`carte-taches-decouverte.md:19`) **cartographie** mais **ne compte pas**.

---

## 4. Gains dédupliqués — chaque économie comptée une fois

### 4.1 `showZConfirmDialog` — 175 lignes revendiquées par neuf domaines

**Sol de vérité mesuré** : une **définition unique**, `buildConfirmDialog`
(`lib/src/utils/functions/forms_utils.dart:480`, empan `:480-662` ≈ **175-183 l**), et **36 sites
d'appel** répartis sur **14 dossiers** :

```
$ grep -rn "buildConfirmDialog(" --include='*.dart' lib | wc -l   → 36
$ grep -rn "showZConfirmDialog" --include='*.dart' lib | wc -l    → 0   (grep négatif : canal jamais adopté)
$ grep -rn "AlertDialog(" --include='*.dart' lib | wc -l          → 25
```

| Confrontation | Chiffre revendiqué | Statut |
|---|---:|---|
| `socle-app.md:73` (M5) | **175** | **RETENU** — propriétaire de `forms_utils.dart` |
| `taches-decouverte.md:317` (M8) | **175** | **RETIRÉ** (le titre reconnaît lui-même « hors périmètre ») |
| `etude-dossiers.md:138` (M3) | **175** | **RETIRÉ** |
| `examens.md:430` (2.8) | **55** (groupé avec `ZItemActionsMenu`) | **RETIRÉ pour la part confirmation** |
| `mindmap.md:460` (2.6) | **~10** | **RETIRÉ** |
| `etude-matieres-corpus.md:312` (M9) | non chiffré séparément | — |
| `formulaires-crud`, `notes-smartnotes` | canal cité, non chiffré | — |

**Sommé naïvement : ≈ 590 l. Réel : 175 l.** Sur-comptage **≈ 415 l**.
La réécriture des 36 sites d'appel (≈ 2 l chacun) est un **coût**, pas un gain.

### 4.2 `presentFormEdition` — revendiqué par dix confrontations

`grep -c presentFormEdition confrontation-*.md` : formulaires-crud **7**, examens **10**,
etude-matieres **6**, notes-smartnotes **5**, socle-app **4**, etude-dossiers **2**,
revision-flashcards **2**, taches-decouverte **2**, mindmap **1**, ia-chat-generation **1**.
**Un seul chiffrage survit** : celui du §2, **≈ 765 l net**, attribué à **formulaires-crud**
(propriétaire de `lib/data_crud/` et du motif de coquille).

### 4.3 🔴 `dynamic_list_screen.dart` (1 753 l) : gain de migration **ET** code mort

Contradiction jamais vue par le relevé :
- `confrontation-formulaires-crud.md:656` (M9) compte **1 753 l** en **gain de migration** vers
  `zcrud_list`, et en fait « la seule dépendance neuve » du dossier (`:1025`).
- `etat-des-lieux.md:§2.0` compte **les mêmes 1 753 l** dans les 2 362 l de **code mort à
  supprimer**.

**Tranché par la mesure** (§1.3) : `DynamicListScreen` a **un seul site de construction**,
`agents_screens.dart:176`, à l'intérieur de `AgentsScreen` qui en a **zéro**.
⇒ **Le code est mort. La migration M9 est sans objet et son chiffre est retiré du gain.**
⇒ **Corollaire opérationnel : la dépendance `zcrud_list` n'a plus de justification dans ce
dossier.** (`zcrud_list` figure déjà parmi les 16 paquets non déclarés, `etat-des-lieux.md:1.1`.)

### 4.4 Autres recouvrements de gain identifiés

| Poste | Revendiqué par | Attribution |
|---|---|---|
| `firebase_owner_scoped_repetition_store.dart` (154 l) | `carte-revision-flashcards.md:15` (périmètre) **et** `etat-des-lieux.md:§2.0` (code mort) | **code mort** — un fichier mort ne produit pas de gain de migration |
| `white_exam_page.dart` (753 l) | `carte-examens.md:708` (périmètre) **et** `etat-des-lieux.md:§2.0` (code mort) | **code mort** |
| `test_exam_filter_zcrud_screen.dart`, `flashcard_edition_zcrud.dart` (70 l) | `formulaires-crud.md:176` (M1) **et** périmètre `flashcards` | **formulaires-crud** (motif de coquille) |
| `ai_router_zcrud_edition.dart` (250 l) | `etude-matieres-corpus` (M1) — **fuite de périmètre**, domaine IA | **formulaires-crud** (motif de coquille), pas `etude-matieres` |
| `valuation_tool_model_zcrud_edition.dart` (117 l) | `etude-matieres-corpus` (M1) — **fuite de périmètre**, domaine examens | **formulaires-crud** |

---

## 5. Total corrigé

### 5.1 Ce que rendrait une addition naïve des confrontations

Totaux annoncés, dans l'ordre : `revision-srs-sessions.md:443` **6 776** · `formulaires-crud.md:659`
**6 234** · `socle-app.md:382` **5 114** · `etude-dossiers.md:338` **2 220** ·
`etude-matieres-corpus.md:532` **2 080** · `taches-decouverte.md:616` **1 666** ·
`ia-chat-generation.md:88` **1 050** · `examens.md:438` **990** · `mindmap.md:445` **665** ·
`notes-smartnotes.md:221` **530** · `revision-flashcards.md` **non totalisé**.
**Somme naïve : ≈ 27 325 l.**

🔴 **Ce total n'a jamais été écrit nulle part — et c'est exactement celui que produit « le premier
lecteur venu ».** Il est faux : il compte `showZConfirmDialog` jusqu'à cinq fois, la coquille de
formulaire deux fois, `dynamic_list_screen.dart` en gain alors qu'elle est morte, et il additionne
des périmètres qui se recouvrent sur 17 417 + 18 178 + 14 980 lignes.

### 5.2 Ce que `etat-des-lieux.md` a réellement retenu

`etat-des-lieux.md:§1.2` ne retient que **≈ 2 100 l établies** + **700 à 1 300 l non éprouvées**.
La synthèse a donc **déjà** filtré 27 325 → 2 100 (–92 %), en écartant tout ce qui n'avait pas
survécu à une réfutation (32 réfutations sur 33 ont mordu). **Ce filtre est le bon geste** ; ce
qui manquait, c'est de le dire — le lecteur qui ouvre les confrontations n'a aucun moyen de savoir
que leurs totaux ne s'additionnent pas.

### 5.3 Les trois totaux à utiliser

| Grandeur | **Valeur corrigée** | Annoncé auparavant | Écart |
|---|---:|---:|---:|
| **Code mort réellement mort** (certifié, trois filtres passés) | **≈ 4 717 l** | ≈ 12 250 l | **−7 533** |
| **Lignes d'hôte réellement économisables** (gains dédupliqués, propriétaire unique) | **≈ 2 100 l établies** + ≈ 765 l pour la coquille en convention B *(dont ≈ 420 déjà comptées dans les 2 100)* ⇒ **≈ 2 450 l** | ≈ 27 325 l si l'on somme les confrontations | **−24 875** |
| **En attente de mesure** (ni gain, ni dette tant que non mesuré) | **≈ 7 595 l** (`appointment_editor.dart`, passe transitive) + **≤ 311 l** (jumeau SmartNotes) + 700 à 1 300 l non éprouvées | comptées en dur des deux côtés | — |

⚠️ Les deux premières lignes **ne s'additionnent pas dans le même budget** : la première est une
**suppression** (aucun paquet, aucune API), la seconde une **migration** (adoption de canaux
existants). C'est la distinction que `etat-des-lieux.md:§2.0` avait raison de poser et que les
confrontations perdent.

---

## 6. Chiffres à ne plus citer, et leurs remplaçants

| ❌ Ne plus citer | Source | ✅ Remplaçant |
|---|---|---|
| « **12 250 l** de code mort » | `etat-des-lieux.md:37,50,282` | « **≈ 4 717 l** certifiées mortes, + ≈ 7 595 l en attente de passe transitive » |
| « `appointment_editor.dart` = **7 858 l** (ou **7 818**) de code mort » | `etat-des-lieux.md:§2.0` | « **0 l certifiée** ; ≈ 263 l vivantes par ses frères, ≈ 7 595 l à qualifier » |
| « `appointment_editor.dart` **migrable, 2 500 l** » | `confrontation-socle-app.md:~204` | **retiré** — verdict §1.2 |
| « `appointment_editor.dart` **manque au socle**, ≈ 3 200 l » | `confrontation-taches-decouverte.md` | **retiré** — verdict §1.2 |
| « **191 l** de coquille sur 4 formulaires » | `confrontation-formulaires-crud.md:162-176` | « **582 l** brut (convention *Screen → EOF*, remesurée à la ligne) » |
| « **534 l** sur 12 formulaires » | `confrontation-formulaires-crud.md:176` | « **925 l** brut, **≈ 765 l** net, 12 fichiers, sans recouvrement » |
| « ≈ 160 conservés (**4 fonctions `presentXEdition`**) » | `confrontation-etude-matieres-corpus.md:111` | « ≈ 160 l **à réécrire** aux 4 sites d'appel `*_dialogs.dart` — les fonctions `presentXEdition` **n'existent pas** (grep négatif §2) » |
| « **175 l** » répété par socle-app, taches-decouverte, etude-dossiers (+55 examens, +10 mindmap) | 5 confrontations | « **175 l, une fois**, propriétaire `socle-app` ; 36 sites d'appel à réécrire = **coût**, pas gain » |
| « **1 753 l** migrables vers `zcrud_list` » (M9) | `confrontation-formulaires-crud.md:656,1025` | « **1 753 l de code MORT** ; migration sans objet ; **`zcrud_list` n'est pas requis** » |
| « `lib/workflow/` **17 417 l** » compté deux fois | `carte-socle-app.md:11` + `carte-taches-decouverte.md:19` | « 17 417 l, propriétaire **taches-decouverte** » |
| « `features/flashcards/**` **18 178 l** » compté trois fois | `carte-revision-flashcards.md:13`, `carte-revision-srs-sessions.md:12`, `carte-examens.md:31` | « 18 178 l, propriétaire **revision-flashcards** » |
| « `lib/data_crud/` **19 fichiers** » | `carte-socle-app.md:11` | « **24 fichiers**, 14 980 l (`find` vérifié), propriétaire **formulaires-crud** » |
| « `agents_screens.dart` dans `lib/data_crud/` » | `etat-des-lieux.md:§2.0` | « `lib/agents_screens.dart` (649 l) » |
| « `ExamAnswer` importé par **2** fichiers vivants » | `etat-des-lieux.md:§2.0` | « **3** fichiers » |
| Somme des totaux de confrontation (**≈ 27 325 l**) | addition implicite | « **≈ 2 450 l** économisables, dédupliquées » |

---

## 7. Ce que je n'affirme pas

- **Aucun test lancé, rien compilé.** Tout verdict de mort repose sur des greps de symboles, filtre
  homonyme appliqué : un usage par réflexion, par chaîne de route ou par `build_runner`
  n'apparaîtrait pas.
- **La passe de joignabilité transitive dans `appointment_editor.dart` n'a pas été menée** — c'est
  pourquoi son gain est fixé à **0** et non à ≈ 7 595.
- Les **8 fichiers de coquille** non revisités en convention B sont chiffrés bas (343 l) : le net
  **≈ 765 l** est un **plancher**.
- `smartnote_ai_instructions_zcrud_edition.dart` (≤ 311 l) est **hors total** tant que l'import de
  `z_qa_flags.dart:82` n'est pas qualifié.
- Le recouvrement « déjà migré » ∩ « code mort » (§1.4) est établi sur **deux** fichiers, non
  balayé sur les 62 jumeaux `*zcrud*.dart` : **les 19 170 l « déjà migré » sont elles aussi à
  requalifier.**
