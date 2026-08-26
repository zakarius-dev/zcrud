# Carte du domaine « Notes intelligentes » (SmartNotes) — IFFD

> Relevé du **2026-08-26**, en **lecture seule** sur `/home/zakarius/DEV/iffd`, HEAD
> `65d1af948` (« feat(zcrud): les étiquettes de résumé d'un select reprennent la teinte du legacy »).
> Socle de référence : **zcrud v3.21.0**, 41 paquets.
> Le relevé `iffd-migration-2026-08-25/` est PÉRIMÉ — aucun de ses constats n'est repris ici sans remesure.
>
> **Contrôle de second passage (2026-08-26)** : 24 valeurs resondées sur disque — 21 confirmées,
> **3 corrigées** (fichiers du périmètre 5 → **6**, entrées `zcrud_*` du `pubspec` 27 → **23 + 25**,
> `fromMapList<FlashcardModel>` 12 → **13**). Le §3.3 est ajouté au second passage.
---

## 0. Périmètre mesuré

Le périmètre nominal est **minuscule** ; le domaine réel est **éclaté dans tout le dépôt**.

| Zone | Fichiers | Lignes | Remarque |
|---|---:|---:|---|
| `lib/src/presentation/features/smartnotes/**` | **6** | **1 718** | dossiers `controllers/` et `pages/` **VIDES** (0 fichier) |
| `lib/src/features/smartnotes/` | 1 | **0** | `smartnotes_module.dart` fait **0 octet** (`wc -c` = 0) — coquille vide, dossiers `pages/`, `providers/`, `widgets/` vides |
| Domaine + données (suivi de dépendance) | 3 | 823 | `smart_note_model.dart` 109, `smart_note_repository.dart` 51, `z_backed_smart_note_repository.dart` 663 |
| **Total du « cœur » notes** | **10** | **2 541** | |
| Fichiers `lib/` citant `smartnote`/`SmartNote` | **47** | — | **339 occurrences** (`grep -ri`) |
| Tests citant `smartnote` | **19** | **6 925** | dont `test/w7m/` (3 fichiers), `test/w5b/` (4), `test/qa-w2/note_faith_channel_guard_test.dart` |

**Inclus au-delà du périmètre** (suivi parce que les dépendances y mènent) :
`popup_menu_helpers.dart` (1 016 l., 10 occurrences), `folder_study_tools_page.dart` (2 265 l., 23),
`content_hub_zcrud.dart` (458 l.), `study_tools_zcrud_adapter.dart` (962 l.),
`folder_documents_actions_dialog_widget.dart` (1 804 l.), `explain_ai_page.dart` (812 l.),
`folder_providers.dart` (123 l.), `z_qa_flags.dart` (985 l.), `chatbot_conversation_screen.dart` (5 356 l.).

---

## 1. 🔴 LE CODE RÉPÉTÉ

### 1.1 Le bloc le plus dupliqué du domaine : « générer depuis une note »

Le **même** enchaînement — appel IA → `normalizedJsonString(result.data)` → `json.decode` →
`fromMapList<T>` → remap → persistance/ouverture → `callback(false)` — est réécrit **en ligne**,
imbriqué à 8-15 niveaux d'indentation, à chaque site.

| Bloc | Sites | Lignes/site (mesuré) | Total ≈ | `fichier:ligne` |
|---|---:|---:|---:|---|
| **Flashcards depuis une note** (`generateFlashcardsFromNotes` + post-traitement) | **8** | 45-70 | **~440** | `smartnote_actions_dialog_widget.dart:100-164` (65 l.) · `popup_menu_helpers.dart:292-345` · `popup_menu_helpers.dart:707-760` · `explain_ai_page.dart:661` · `folder_documents_actions_dialog_widget.dart:706-750` · `valuation_tool_model_actions_dialog_widget.dart:108-133` · `ai_flashcards_generator_dialog_widget.dart:1032/1074/1154` · `chatbot_conversation_screen.dart:807` |
| **Carte mentale depuis une note** (`generateMindmapFromNotes` + `MindmapNode.fromMap`/`fromMapList<MindmapNode>` + `showFolderMindmapViewer`) | **8** | 55-90 | **~520** | `smartnote_actions_dialog_widget.dart:184-260` (77 l.) · `popup_menu_helpers.dart:346-395` · `popup_menu_helpers.dart:791-820` · `explain_ai_page.dart:496-556` · `folder_documents_actions_dialog_widget.dart:784-810` · `valuation_tool_model_actions_dialog_widget.dart:159-200` · `chatbot_conversation_screen.dart:607-700` · `notebook_capabilities_iffd.dart:488` |
| `normalizedJsonString(` (décodage défensif de la réponse IA) | **22 sites / 10 fichiers** | 1-8 | — | liste par `grep -rln` |
| `showFolderMindmapViewer(` | **17 sites / 12 fichiers** | 6-20 | ~200 | dont 3 dans `folder_study_tools_page.dart` seul (`:613`, `:1983`, `:2161`) |
| `fromMapList<FlashcardModel>(` | **13 sites / 9 fichiers** | — | — | dont 4 dans `ai_flashcards_generator_dialog_widget.dart`, 2 dans `popup_menu_helpers.dart` |
| `saveFolderFlashcards(` | **11 sites d'appel** | 5-15 | — | |

➡️ **Assemblage manquant au socle** : un port « générer X depuis un corps de note »
(requête + décodage défensif + matérialisation) — le socle a déjà `ZNoteSummaryPort`
(`packages/zcrud_study/lib/src/domain/z_note_summary_port.dart`, 71 l.) mais **rien pour
flashcards/mindmap depuis une note**, et IFFD ne le consomme nulle part.

### 1.2 « Déplacer un contenu vers un dossier » — écrit 7 fois

Séquence identique : `showFolderSelectionModelDialog` → `isSubFolder ? parentId : id` →
`batchUpdate(DataRequest(where:{"id":…}), data:{"folderId":…, "subFolderId":…})`.

| Site | Lignes | Type déplacé |
|---|---:|---|
| `smartnote_actions_dialog_widget.dart:319-378` | **60** | note |
| `mindmap_dialog_widgets.dart:~140-200` | ~60 | carte mentale |
| `folder_documents_actions_dialog_widget.dart:~590-650` | ~60 | document |
| `folder_flashcards_list_page.dart:~700-740` | ~40 | flashcard |
| `popup_menu_helpers.dart:438` / `:561` / `:946` | 3 × ~25 | note / mindmap / document |

**Sites : 7 · lignes : ~320.** `showFolderSelectionModelDialog(` compte **10 appels / 8 fichiers**.
La règle `isSubFolder ? parentId : id` est réécrite à chaque fois (aussi dans
`smartnote_actions_dialog_widget.dart:212-219` pour la création de mindmap).

### 1.3 La tuile d'action d'un menu de contenu

Motif `Material(child: Opacity(opacity: <perm> ? 1 : 0.7, child: ListTile(leading: Icon(...),
title: Text(...), enabled: <perm>, onTap: <perm> ? () async {...} : null)))`.

| Fichier | Occurrences du ternaire `? 1 : 0.7` |
|---|---:|
| `folder_documents_actions_dialog_widget.dart` | 6 |
| `smartnote_actions_dialog_widget.dart` | **5** |
| `mindmap_dialog_widgets.dart` | 4 |

**15 tuiles** écrites à l'identique, ~12 lignes chacune ⇒ **~180 lignes**. Plus largement,
`child: ListTile(` compte **94 sites** dans `lib/`, et **12 classes** étendent
`StatelessItemDialogWidget<T>` — un embryon d'assemblage local qui ne factorise que le
constructeur, jamais les tuiles.

### 1.4 Déclaration de champs de formulaire

| Mesure | Valeur |
|---|---:|
| `DynamicFormField(` (legacy) | **215 sites / 35 fichiers** |
| `DynamicEditionScreen<` monté | **45 sites** |
| `showPushedDialog(` | **33 sites** |
| `buildConfirmDialog(` | **36 sites** |

Dans le seul `smartnotes_dialogs.dart` : **11 `DynamicFormField`** pour 3 formulaires, dont
**4 champs strictement identiques dupliqués** entre `showSummaryCustomInstructionsDialig`
(`:214-260`) et `showMindmapCustomInstructionsDialig` (`:328-365`) — `aiModel`,
`wholeDocument`, `aResumer` (même `displayCondition`), `instructions`.
**Sites : 2 · lignes dupliquées : ~46.** Le portage zcrud a déjà refermé cette duplication
en **un seul** composant paramétré (`smartnote_ai_instructions_zcrud_edition.dart:185-255`).

### 1.5 Confirmation de suppression

`buildConfirmDialog(context, message: "Voulez-vous vraiment supprimer …", onConfirm: …)` —
**36 sites**, dont `smartnote_actions_dialog_widget.dart:398-407` (10 l.). Message, bouton,
et appel `repository.delete(item?.id)` réécrits partout.

### 1.6 Code MORT mesuré (duplication devenue résidu)

| Résidu | Lignes | Preuve (grep négatif MONTRÉ) |
|---|---:|---|
| `SmartnoteActionsDialogWidget` (fichier entier) | **417** | `grep -rn "SmartnoteActionsDialogWidget" lib test` → 4 résultats, **tous** dans le fichier lui-même + son unique constructeur en `smartnotes_dialogs.dart:150` |
| `showSmartNoteActionsDialog` (son seul appelant) | **39** (`:129-167`) | `grep -rn "showSmartNoteActionsDialog" lib test` → **1 résultat : sa propre déclaration** |
| `showSummaryCustomInstructionsDialig` | **120** (`:169-288`) | `grep -rn "CustomInstructionsDialig" lib test` → aucun site d'appel (déclarations, commentaires et tests de garde seulement) |
| `showMindmapCustomInstructionsDialig` | **100** (`:290-389`) | idem |
| `NoteSelectorDropdown` + `NoteSelectorState` | **212** | `grep -rn "NoteSelectorDropdown\|NoteSelectorState" lib test` (hors son fichier) → **0 résultat** |
| `smartnotes_module.dart` | 0 (fichier vide) | `wc -c` = 0 |

➡️ **~888 lignes sur 2 135 du périmètre présentation+dialogues sont inatteignables** (41 %).
Le menu réellement utilisé est `buildSmartNotePopupMenu` (`popup_menu_helpers.dart:269-491`,
**223 l.**, 2 sites d'appel, tous deux dans `folder_study_tools_page.dart:781` et `:1780`) —
il **redéclare** les mêmes 5 actions que le widget mort.

---

## 2. Ce que le domaine SAIT FAIRE (en termes d'utilisateur)

| # | Capacité | Preuve (`fichier:ligne`) |
|---|---|---|
| 1 | **Écrire une note riche** dans un dossier, un sous-dossier **ou** une matière : titre (1-3 l., majuscule initiale auto) + corps texte riche/Markdown (7-15 l.) | `smartnote_zcrud_edition.dart` (2 `ZFieldSpec`) |
| 2 | **Relire** une note en lecture seule (`Crud.read`) | `folder_study_tools_page.dart:598-604` |
| 3 | **Créer une note depuis 6 points d'entrée** — feuille « Ajouter du contenu », hub porté, menu `⋮`, page outils d'étude, menu d'un **document** (« transformer un document en note »), assistant IA (« Enregistrer dans les notes ») ⇒ **10 sites d'appel** de `showSmartNoteEditonDialog` | `folder_content_add_dialog_widget.dart:305` · `content_hub_zcrud.dart:320` · `popup_menu_helpers.dart:399`, `:873` · `folder_study_tools_page.dart:598`, `:1623`, `:1851` · `folder_documents_actions_dialog_widget.dart:845` · `notebook_zcrud.dart:906` · `chatbot_conversation_screen.dart:4199` |
| 4 | **Générer des flashcards** depuis le corps (JSON rendu par l'IA, cartes rattachées par `noteId`) | §1.1, 8 sites |
| 5 | **Générer une carte mentale** depuis le corps, l'ouvrir dans le visualiseur, l'enregistrer | §1.1, 8 sites |
| 6 | **Résumer** avec instructions complémentaires (type, modèle d'IA, tout/partie, consignes libres) — **présent mais INATTEIGNABLE** | cf. §1.6 |
| 7 | **Déplacer** vers un autre dossier/sous-dossier, ou vers une autre matière | `smartnote_actions_dialog_widget.dart:319-378` |
| 8 | **Supprimer** sous confirmation | `smartnote_actions_dialog_widget.dart:398-407` |
| 9 | **Chercher** par titre ou contenu | `folder_study_tools_page.dart:441-452`, `:909-915` |
| 10 | **Réordonner** les notes d'un dossier (ordre persisté `folderContentsOrders.notesIds`/`subNotesIds`) | `folder_study_tools_page.dart:245-247` |
| 11 | **Contrôler qui peut quoi** — 5 permissions (créer/lire/modifier/déplacer/supprimer/générer) | `folder_resource_access_service.dart` (364 l.), `…Context.forNote(…)` |
| 12 | **Attacher un audio** (`audioText`, `audioUrl`, `audioPath`, `audioTextHash`) — schéma persisté et transporté, **UI commentée** (27 l. mortes) | `smartnote_actions_dialog_widget.dart:267-293` |

---

## 3. Ce qui est DÉJÀ branché sur zcrud

### 3.1 Paquets zcrud consommés par le domaine notes

| Paquet | Ce qui en est importé, où |
|---|---|
| `zcrud_note` | `ZSmartNote`, `normalizeNoteContentOps`, `kContentKey` → `z_backed_smart_note_repository.dart:52-54` |
| `zcrud_core` | `ZFieldSpec`, `ZFormController`, `ZEditionSubmitController`, `DynamicEdition`, `ZSyncMeta`, `ZCondition`, `ZSelectConfig`, `ZTextConfig`, `ZValidatorSpec` |
| `zcrud_screen` | `presentFormEdition` → `smartnote_ai_instructions_zcrud_edition.dart:110` |
| `zcrud_navigation` | `ZEditionPresentation` → idem `:108` |
| `zcrud_study` | `ZDefaultNoteCard` → `study_tools_zcrud_adapter.dart:759` (carte de note du hub d'étude) |
| `zcrud_markdown` | via `IffdRichTextCodec` (`z_iffd_rich_text_codec.dart`, 193 l.) |

`pubspec.yaml` déclare **23 entrées `zcrud_*`** en `dependencies` (dépendance git, tag épinglé)
et **25** en `dependency_overrides` — les deux ensembles ne coïncident donc pas.

### 3.2 Écrans à jumeau porté et drapeau de bascule

`lib/src/presentation/shared/zcrud/z_qa_flags.dart` (985 l.) recense **53 `ZQaFlag`**.
Deux concernent les notes :

| `id` du drapeau | Provider | Défaut | Jumeau porté | Écran |
|---|---|---|---|---|
| `smartNote` | `smartNoteEditionUseZcrudProvider` (`smartnote_zcrud_edition.dart:109`) | **`false` (legacy)** | `SmartNoteZcrudEditionScreen` (`smartnote_zcrud_edition.dart`, 342 l.) | Créer / modifier une note |
| `smartNoteAiInstructions` | `smartNoteAiInstructionsUseZcrudProvider` (`smartnote_ai_instructions_zcrud_edition.dart:128`) | **`false` (legacy)** | `presentSmartNoteAiInstructionsEdition` (311 l.) | Instructions complémentaires — **marqué 🔕 INOBSERVABLE** dans `z_qa_flags.dart:571-577` et `docs/qa-plan-comparaison-legacy-zcrud.md:340-344` |

Un **troisième** drapeau, côté données : `useZcrudSmartNoteRepositoryProvider`
(`folder_providers.dart:64-78`), défaut **`false`** ⇒ `FirebaseFolderNoteRepositoryImpl` ;
à `true` ⇒ `ZBackedSmartNoteRepository`. Le provider `folderNoteRepositoryProvider` est lu
en **26 sites**.

### 3.3 Canaux du socle NON consommés (mesuré le 2026-08-26)

IFFD importe **22 des 41 paquets** zcrud (`grep -rho "package:zcrud_[a-z_]*" lib | sort -u | wc -l`
→ **22**). Les canaux qui refermeraient précisément les duplications du §1 sont ceux qui **ne sont
pas branchés** :

| Paquet du socle | Sites d'import dans `lib/` | Ce qu'il ferait ici |
|---|---:|---|
| `zcrud_menu` (12 fichiers, **1 448 l.** : `ZActionMenu`, `ZMenuEntryTile`, `ZGridMenuRenderer`, `ZMenuRequest`, `ZContextMenuRegion`) | **1** — `folder_actions_menu_zcrud.dart:36`, et seulement `show ZMenuEntryTile` | les **15 tuiles** du §1.3 et le menu `⋮` de 223 l. du §1.6 |
| `zcrud_chat_study` (dont `z_chat_flashcard_generator.dart`, `z_chat_flashcard_mapper.dart`) | **0** | les **8 sites / ~440 l.** de « flashcards depuis une note » (§1.1) |
| `zcrud_note` (10 fichiers, **2 052 l.** ; `ZNoteAudio`, `ZNoteContent`, `ZNoteFaithChannel`, `ZOpaqueNoteExtension`) | **3**, tous dans `z_backed_smart_note_repository.dart` (`:13`, `:52`, `:68`) | le slot audio typé du §7.3 reste inutilisé |

**Grep négatif MONTRÉ** — `grep -rn "zcrud_chat_study" lib test --include='*.dart'` ne rend
**qu'une** ligne, et c'est une **chaîne de message** dans un test de parité
(`test/qa-w2/notebook_parity_test.dart:148`), jamais un import : le paquet n'est consommé nulle part.

➡️ La conclusion du §1 se reformule : sur les trois assemblages « manquants », **deux existent déjà
au socle** (`zcrud_menu`, `zcrud_chat_study`) et ne sont simplement **pas branchés** ; seul le
« déplacer un contenu vers un dossier » (§1.2) est réellement absent.

### 3.4 Registre et plomberie partagée

`lib/src/presentation/shared/zcrud/` — **14 fichiers, 3 234 lignes** — dont
`z_iffd_field_registry.dart` (461 l., monte `IffdZcrudScope` au-dessus de toute l'app,
`main.dart:269-270`), `z_iffd_rich_text_codec.dart` (193 l., `iffdPersistedRichTextValue`),
`z_text_transforms.dart` (40 l., `ucFirstLegacy`), `z_flag_gateway.dart` (86 l.,
`zcrudFlagValue` + `iffdPresentationContext`).
Le champ `inlineMarkdown` n'est **résolu** que sous `IffdZcrudScope` — sans lui le champ
ne se rend pas du tout (`smartnote_zcrud_edition.dart:218-221`).

---

## 4. Widgets maison qui refont ce que le socle fait probablement

| Widget / fonction maison | Chemin | Lignes | Équivalent socle plausible |
|---|---|---:|---|
| `SmartnoteActionsDialogWidget` | `…/smartnotes/widgets/smartnote_actions_dialog_widget.dart` | **417** (mort) | menu d'actions d'un contenu — `zcrud_menu` / `ZStudyToolsSection.addAction` |
| `buildSmartNotePopupMenu` | `…/core/widgets/popup_menu_helpers.dart:269-491` | **223** | idem |
| `NoteSelectorDropdown` | `…/smartnotes/widgets/note_selector_dropdown.dart` | **212** (mort) | `EditionFieldType.select` + `ZSelectConfig(searchable:true)` (`zcrud_select`), ou `ZFieldSpec` de relation |
| `_getContentPreview` (strip Markdown, 50 car.) | même fichier, `:201-211` | 11 | extrait de note — `ZDefaultNoteCard` le fait déjà (`study_tools_zcrud_adapter.dart:756-762`) |
| `showSmartNoteEditonDialog` (aiguillage + post-traitement) | `smartnotes_dialogs.dart:29-127` | 99 | `presentFormEdition` / `ZCrudScreen` |
| `_presenterInstructionsParLeSocle` (fusion carte de départ ⊕ saisie) | `smartnotes_dialogs.dart:412-434` | 23 | **manque au socle** : `presentFormEdition` ne rend que les champs **visibles** ; l'hôte refait la fusion à la main |
| `smartNoteAiInstructionsForcedMode` | `smartnote_ai_instructions_zcrud_edition.dart:269-277` | 9 | **manque au socle** : `showPushedDialog` dérive le mode mais ne l'expose pas ; la règle est reposée dans l'hôte (commentaire `:259-263`) |
| `adaptSmartNoteZcrudOutput` (purge des clés nulles, `createdAt`/`updatedAt`) | `smartnote_zcrud_edition.dart:192-211` | 20 | **manque au socle** : horodatage de soumission |
| `ZBackedSmartNoteMapper` | `z_backed_smart_note_repository.dart:108-238` | **131** | pont `SmartNoteModel ↔ ZSmartNote` — spécifique, à garder |
| `FirestoreZNoteDataPath` | même fichier, `:272-408` | **137** | `zcrud_firestore` (`FirebaseZRepositoryImpl`) — réécrit à la main |

---

## 5. Écrans et dialogues

| Chemin | Lignes | Rôle | Ce qu'il porte |
|---|---:|---|---|
| `…/smartnotes/dialogs/smartnotes_dialogs.dart` | **434** | 4 fonctions de dialogue | aiguillage legacy/zcrud du formulaire ; post-traitement (id aléatoire, purge `subjectId` **ou** `folderId`+`subFolderId`, `fromMap`, appel repo) ; 2 dialogues d'instructions IA **orphelins** |
| `…/smartnotes/dialogs/smartnote_zcrud_edition.dart` | **342** | jumeau zcrud du formulaire de note | 2 `ZFieldSpec` (`title` multiline 1-3 + `ucFirstLegacy` ; `content` `inlineMarkdown` 7-15) ; 86 lignes d'en-tête documentant **4 divergences assumées** |
| `…/smartnotes/dialogs/smartnote_ai_instructions_zcrud_edition.dart` | **311** | jumeau zcrud des instructions IA, **un** composant pour **deux** dialogues | 5 `ZFieldSpec` (`summaryType`, `aiModel`, `wholeDocument`, `aResumer` conditionnel, `instructions`) ; 95 lignes d'en-tête, 5 équivalences mesurées sur le moteur legacy |
| `…/smartnotes/widgets/smartnote_actions_dialog_widget.dart` | **417** | menu d'actions d'une note — **MORT** | 5 actions (flashcards, mindmap, modifier, déplacer, supprimer) + 27 l. d'audio commenté |
| `…/smartnotes/widgets/note_selector_dropdown.dart` | **212** | sélecteur de note — **MORT** | `DropdownButton<SmartNoteModel?>` + 3 états (`idle`/`loading`/`error`) + bouton « Saisir un nouveau texte » |
| `…/smartnotes/smartnotes.dart` | 2 | barrel | 2 exports (dont le widget mort) |
| `…/core/widgets/popup_menu_helpers.dart:269-491` | 223 | menu `⋮` d'une note — **le chemin réel** | mêmes 5 actions, en `PopupMenu` grille 2 colonnes |
| `…/folders/pages/folder_study_tools_page.dart` | 2 265 | page outils d'étude, **hôte des notes** | grille de notes, recherche, tri, réordonnancement, menu `⋮` (`:759-790`) |
| `…/folders/zcrud/study_tools_zcrud_adapter.dart` | 962 | adaptateur porté du hub d'étude | section `notes` (`:748-778`), `ZDefaultNoteCard`, dépliage initial si `< 3` notes |
| `…/folders/zcrud/content_hub_zcrud.dart` | 458 | feuille « Ajouter du contenu » portée | entrée « Créer une note » (`:319-330`, teinte `kTeinteNote = Colors.green`) |

**Aucun écran « liste de notes » dédié** : les notes ne s'affichent que comme une **section**
du hub d'étude d'un dossier ou d'une matière.

---

## 6. Modèles et persistance

**Entité.** `SmartNoteModel` (`lib/src/domain/models/smart_note_model.dart`, **109 l.**) étend
`FolderContentModel` (`id`, `subjectId`, `folderId`, `subFolderId`, `creatorId`, `createdAt`) et
ajoute 6 champs : `title`, `content`, `audioText`, `audioUrl`, `audioPath`, `audioTextHash`.
Sérialisation **manuelle** — `toMap`/`fromMap`/`copyWith`/`props` écrits à la main, **aucun
codegen** ; `content` est une `String?` qui peut contenir **soit** du Markdown, **soit** un
Delta Quill JSON selon que l'utilisateur a édité ou non (défaut legacy documenté
`smartnote_zcrud_edition.dart:39-54` ; corpus de production mesuré : **127 valeurs `content`,
0 Delta**). `fromMap` tolère `Timestamp` **et** `int` pour `createdAt`, avec repli
`DateTime.now()` — désérialisation défensive, mais **`cloud_firestore` fuit dans le domaine**
(`import 'package:cloud_firestore/cloud_firestore.dart'` en tête du modèle).

**Dépôts.** Port `FolderNoteRepository implements CrudRepository<SmartNoteModel>`
(`smart_note_repository.dart`, **51 l.**) + 4 extensions de flux (`folderNotes`,
`countFolderNotes`, `subjectNotes`, `countSubjectNotes`), déléguées à des helpers statiques
génériques de `FoldersRepository`/`SubjectRepository`. Deux implémentations coexistent derrière
`folderNoteRepositoryProvider` : `FirebaseFolderNoteRepositoryImpl` (défaut) et
`ZBackedSmartNoteRepository` (`z_backed_smart_note_repository.dart`, **663 l.**, drapeau à
`false`). Ce dernier est structuré en 3 couches : `ZBackedSmartNoteMapper` (131 l., table de
correspondance de **12 champs** vers `ZSmartNote` — 6 au schéma, 6 en `extra` préfixé `iffd_`),
le port `ZNoteDataPath` (11 méthodes) et `FirestoreZNoteDataPath` (137 l.). Trois marqueurs de
fidélité (`iffd_folder_id`, `iffd_title`, `iffd_content`) compensent la non-nullabilité de
`ZSmartNote.folderId`/`title` et le fait que le corps zcrud soit une `List<Map>` d'ops ; la
`String` d'origine **fait foi** au retour. **Erreurs** : `FirestoreDataState<T>` maison, pas
d'`Either<ZFailure, T>` ; les échecs sont fabriqués en `FirebaseException` (`_err`, `:465`).
Soft-delete et `updatedAt` passent par `ZSyncMeta` (hors-entité, AD-19).

---

## 7. Ce qui est PARTICULIER à IFFD

| # | Particularité | Mesure / preuve | Généralisable ? |
|---|---|---|---|
| 1 | **Double format de `content`** : Markdown **ou** Delta JSON selon l'historique d'édition | corpus de prod : **127 valeurs, 0 Delta** ; pont `normalizeNoteContentOps` + `ZNoteContentFaithChannel`, `iffd_content` faisant foi | non — **dette IFFD** |
| 2 | **Double appartenance dossier OU matière** : `folderId`/`subFolderId` **ou** `subjectId`, jamais les deux ; booléen `subjectToolPage` propagé dans **toutes** les signatures | purge de clés `smartnotes_dialogs.dart:105-111` ; `subjectId` en `extra['iffd_subject_id']` | partiellement — le socle ne connaît que `folderId`/`subFolderId` |
| 3 | **Audio de note** : 4 champs persistés, **aucune UI active** | `smartnote_actions_dialog_widget.dart:267-293` (27 l. commentées) ; slot `ZNoteAudio` du socle **non utilisé** (§3.3) | oui — le socle a déjà le slot typé |
| 4 | **`ucFirstLegacy` partout** : le moteur legacy capitalise **tout** champ texte et **tout** libellé d'option de `select` (sauf `country`) | `edition_screen.dart:1015-1020`, `:1745` ; à reposer champ par champ dès qu'une `ZTextConfig` est déclarée (remplacement en bloc, jamais fusion membre à membre) | non — contrainte de **parité**, pas un besoin durable |
| 5 | **`IffdAiRouterModel`** : chaque type de génération (résumé, carte mentale, flashcards) a son modèle principal **+ sa liste de replis**, exposés au formulaire | — | **oui, et à généraliser** : c'est le mode « transport PAR ROUTE » décidé au socle le 2026-08-23 |
| 6 | **`SummaryType` + composition d'instructions en français codées en dur**, non localisées | `smartnotes_dialogs.dart:277-285`, `:381-387` | non |
| 7 | **ACL par ressource de dossier** croisant créateur, propriétaire, **année académique** et `AppUserPermissions` | `folder_resource_access_service.dart` (364 l.), contexte `forNote` lisant `accademicYear` | non — modèle maison |

---

## Les trois gisements, dans l'ordre du gain mesuré

⚠️ Corrigé au second passage (§3.3) : **deux des trois existent déjà au socle** et ne sont pas branchés.

| # | Assemblage | Ce qu'il refermerait chez IFFD |
|---|---|---:|
| 1 | **Port « générer depuis un corps de note »** (flashcards / carte mentale / résumé) — `zcrud_chat_study` couvre déjà les flashcards, **0 import** chez IFFD | **16 sites, ~960 l.** |
| 2 | **Action « déplacer un contenu vers un dossier/sous-dossier »** (sélecteur + `isSubFolder ? parentId : id` + écriture) — **réellement absente du socle** | **7 sites, ~320 l.** |
| 3 | **Menu d'actions d'un contenu piloté par permissions** (tuile à 0,7 d'opacité, confirmation incluse) — `zcrud_menu` existe (1 448 l.), **1 seul import** chez IFFD | **15 tuiles + 36 confirmations, ~400 l.** |
