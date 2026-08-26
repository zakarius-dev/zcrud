# Carte du domaine — moteur de formulaires et listes historique, et la bascule en cours (IFFD)

> Relevé du **2026-08-26**, mesuré en lecture seule sur `/home/zakarius/DEV/iffd`
> à `65d1af948dd070fcee963bed71dfceb873f5ae1a` (Wed Aug 26 07:04:44 2026 +0000).
> zcrud consommé : **tag `v3.21.0`** (48 occurrences de `ref: v3.21.0` dans `pubspec.yaml`).
> Le relevé `iffd-migration-2026-08-25/` est périmé : rien n'en est repris. Tout chiffre ci-dessous
> est remesuré.

## 0. Chiffres d'entrée

| Périmètre | Fichiers | Lignes |
|---|---:|---:|
| `lib/` entier | 549 | 179 222 |
| `lib/data_crud/` (moteur legacy) | 24 `.dart` (24 fichiers au total) | **14 980** |
| `lib/src/presentation/shared/zcrud/` (socle d'accueil zcrud) | 14 | **3 234** |
| `*_zcrud_edition.dart` (jumeaux portés) | **27** | **9 053** |
| `lib/src/domain/` | 71 | 11 004 |
| `*repository*.dart` | 25 | 10 297 |
| Écrans (`*_page.dart` + `*_screen.dart`) | 54 | 43 334 |
| Dialogues (`*dialog*.dart`) | 38 | 16 028 |
| **Périmètre cartographié** (`data_crud/` + `shared/zcrud/` + jumeaux portés + `*_dialogs.dart` + `*actions_dialog_widget.dart` + `*repository*.dart` + `domain/models/` + `core/widgets/` + `forms_utils.dart` + `data_functions.dart`, dédoublonné) | **167** | **57 558** |

Moteur legacy, pièces maîtresses : `lib/data_crud/edition_screen.dart` **4 073 l**,
`dynamic_list_screen.dart` **1 753 l**, `rich_text_editor_screen.dart` 773 l,
`sub_list_screen.dart` 555 l, `edition_field.dart` 444 l, `models.dart` 304 l,
`embeds/` (formule LaTeX + tableaux) **3 766 l sur 7 fichiers**,
`rich_text_editor/` (Quill/Markdown/HTML) **3 106 l sur 7 fichiers**.

Surface d'appel du moteur legacy : `EditionFieldTypes` **525 occurrences / 63 fichiers**,
`EditionScreen` 289 occ / 57 fichiers (dont `EditionScreen(` **63 instanciations**),
`DynamicFormField(` **215 déclarations / 43 fichiers**,
`DynamicListScreen` 8 occ / 2 fichiers, `SubListScreen` 7 occ / 2 fichiers.
26 valeurs dans l'énum `EditionFieldTypes` (`edition_field.dart:18-45`). 38 `case` dans
le `switch` de rendu (`edition_screen.dart`).

---

## 1. 🔴 Le code répété

Classé par coût. « Sites » = fichiers distincts portant le bloc ; « lignes » = mesure réelle,
pas une estimation.

| # | Bloc répété | Sites | Lignes | Où le voir | Ce qui manque au socle |
|---|---|---:|---:|---|---|
| D1 | **Sérialisation manuelle** `toMap` / `fromMap` / `copyWith` — 64 + 62 + 63 blocs | **53** | **3 479** (996 + 1 725 + 758) | `lib/src/domain/models/*.dart` (`folder_model.dart:…`, `flashcard_model.dart:…`, `app_user.dart:589 l`) | codegen `@ZcrudModel` (`zcrud_generator` v3.21.0, **non importé**) |
| D2 | **Adaptateurs dépôt zcrud → `CrudRepository` legacy** : la **même** surface de 18 méthodes (`all, asyncCount, batchDelete, batchSet, batchUpdate, count, create, delete, find, hardDelete, mapCreate, put, restore, softDelete, streamAll, streamByIds, streamOne, update`) réécrite entité par entité | **6** | **4 648** | `lib/src/data/repositories/z_backed_{exam,folder,flashcard,smart_note,folder_document,mindmap}_repository.dart` (912/772/797/663/698/806 l ; 35-36 `Future<>`/`Stream<>` chacun) | un `ZLegacyCrudAdapter<TLegacy, TZ>` générique — l'assemblage le plus coûteux du dépôt |
| D3 | **Fig étrangleuse** : `zcrudFlagValue(...)` + `if (useZcrud ?? …) return XxxZcrudEditionScreen(…)` + branche legacy inchangée, dans chaque point d'entrée | **43** (`zcrudFlagValue`, 80 occ) | — | `subject_model_dialogs.dart:44-48` (résolution) et `:126-147` (les deux branches) ; `useZcrud` 87 occ / 21 fichiers | rien : mécanique de migration, à retirer après bascule |
| D4 | **Déclaration du drapeau de bascule** : `const bool kXUseZcrudDefault` + `Provider<bool> xUseZcrudProvider` + dartdoc, **50 fois**, un par écran | **50** | ~200 (4 l de code utile ×50) | `valuation_tool_model_zcrud_edition.dart:94-97` ; `UseZcrudProvider` 229 occ / 92 fichiers ; `UseZcrudDefault` 196 occ / 90 fichiers | idem : échafaudage de migration |
| D5 | **Déclaration des champs** : une fonction `List<ZFieldSpec> xxxFields(...)` par écran (côté porté) **plus** une liste `DynamicFormField(...)` par écran (côté legacy) — les deux coexistent | 48 fns `List<ZFieldSpec>` + 43 fichiers `DynamicFormField(` | 331 occ `ZFieldSpec` / 215 `DynamicFormField(` | `ai_experts_dialogs.dart` **40** `DynamicFormField(`, `flashcard_edition_screen.dart` 22, `multi_flashcard_editor_page.dart` 15, `agents_screens.dart` 14 | dérivation du `ZFieldSpec[]` depuis le modèle annoté (objectif produit n°2) |
| D6 | **Adaptateur d'état de formulaire** `Map<String, dynamic> adaptXxxZcrudOutput(...)` (+2 `…Input`) — pont entre l'état du `ZFormController` et la persistance | **17** | **115** | `adaptAiRouterZcrudInput` 24 l, `adaptFolderFlashcardsFilterOutput` 18 l, 15 autres de 4 à 9 l | contrat de sortie typé côté socle (le `toMap` du modèle généré) |
| D7 | **Cycle de vie du formulaire porté** : `late final ZFormController` + `ZFormController(...)` + `ZEditionSubmitController` + `dispose()` + `_onSave() => _submit.submit()` | **10-11** | ~40 par fichier | `folder_zcrud_edition.dart:439/461/504/515` ; `ZEditionSubmitController` 24 occ / 11 fichiers ; `_onSave(` **9** fichiers | un assemblage « écran d'édition » qui possède son controller |
| D8 | **Montage du scope** `IffdZcrudScope(...)` autour de **chaque** formulaire porté | **24** (62 occ) | — | `folder_zcrud_edition.dart:519-525` ; commentaire « ✅ TOUT FORMULAIRE ZCRUD D'IFFD SOUS `IffdZcrudScope` » | scope posé une fois haut dans l'arbre |
| D9 | **Dialogue d'actions par entité** — `ListTile "Modifier"` + `ListTile "Supprimer …"` rouge, `Navigator.pop` puis appel dépôt : structure **identique** d'un fichier à l'autre | **8** | **3 554** | `subject_actions_dialog_widget.dart` (66 l) et `app_user_role_actions_dialog_widget.dart` (56 l) sont quasi ligne à ligne ; `folder_documents_actions_dialog_widget.dart` 1 804 l ; `valuation_tool_model_…` 823 l ; `smartnote_…` 417 l ; `folder_…` 186 l ; `flashcard_…` 126 l ; `exam_…` 76 l | menu d'actions CRUD dérivé de l'ACL (`Icons.edit_outlined` 17 sites, `Icons.delete_outline` 15 occ, `Text("Modifier")` 11 sites) |
| D10 | **Confirmation destructive** : 38 appels `buildConfirmDialog` sur **20** fichiers, plus 25 `AlertDialog` bruts sur 18 fichiers, plus 21 fichiers portant un libellé « Voulez-vous / Êtes-vous » écrit à la main | **20 + 18** | — | `forms_utils.dart:480` (`buildConfirmDialog`), `:363` (`buildDeleteConfirmation`, seulement 2 sites) | confirmation standard du socle |
| D11 | **Enveloppe de dialogue** `showPushedDialog(dialog:, fullscreenDialog:, bottomSheetHeightRation:, builder:)` | **42** (108 occ) | déf. `forms_utils.dart:727` | + `showErpDialog:788`, `scaffoldDialog:804`, `buildDialog:391` | présentation d'écran d'édition (dialogue / plein écran / feuille) |
| D12 | **Fonctions `show…EditonDialog`** : **49** fonctions `show*` top-level, dont ~14 « éditer une entité » à la structure identique (résoudre le flag → `showPushedDialog` → `fromMap<T>` → `create`/`update` selon `Crud`) | 13 fichiers `*_dialogs.dart` | **6 438** | `subject_model_dialogs.dart:28-84` en est le patron exact | assemblage « écran CRUD complet » |
| D13 | **Registre type → fabrique écrit à la main** : `T fromMap<T>(Map)` avec **23 entrées** `Type: () => X.fromMap(map)` | 1 | 515 (fichier) | `lib/src/utils/functions/data_functions.dart:314-…` | `ZcrudRegistry` produit par `zcrud_generator` |
| D14 | **États chargement / vide / erreur** : `StreamBuilder` **133 occ / 51 fichiers**, `CircularProgressIndicator` **49 occ / 30 fichiers**, mais seulement **5** `snapshot.hasError` (4 fichiers) et **3** `snapshot.hasData` | 51 | — | `lib/src/presentation/core/widgets/loading_indicators.dart` (100 l) | un `ZAsyncSlot` chargement/vide/erreur — l'écart 133 → 5 dit que l'erreur n'est presque jamais rendue |
| D15 | **Tuiles de liste** `ListTile(` **269 occ / 72 fichiers** ; `Card(` 67 occ / 30 fichiers ; `ListView.builder` 28 occ / 20 fichiers ; `GridView` 40 occ / 20 fichiers ; `ReorderableListView` 7 | 72 | — | — | tuiles/cartes d'entité du socle |
| D16 | **Sortie de dialogue** `Get.back()` **85 occ / 26 fichiers** + `Navigator.of(context).pop` 19 occ / 10 fichiers + `Navigator.pop(context);` 72 occ / 13 fichiers | 40+ | — | — | contrat de retour d'un écran d'édition |
| D17 | **Résolution d'injection** `ProviderScope.containerOf(context).read(...)` **180 occ / 55 fichiers** | 55 | — | `subject_actions_dialog_widget.dart:46,58` | `ZcrudScope` / binding `zcrud_riverpod` (**déclaré mais jamais importé**, cf. §3) |
| D18 | **`try` / `catch` nus** : `try {` **300 occ / 110 fichiers**, `catch (e` 123 occ / 44 fichiers, pour **1 seul** `Either<` dans tout `lib` | 110 | — | grep : `Either<` sites=1 | contrat `Either<ZFailure, T>` (AD-5) |

**Lecture.** Les trois postes qui pèsent réellement en lignes sont **D2 (4 648)**, **D1 (3 479)** et
**D9 (3 554)** : plus de **11 600 lignes** de code écrit une fois par entité. D3+D4 (~250 l) sont de
l'échafaudage de migration, destiné à disparaître ; D5/D6/D7/D8 sont le prix actuel d'un formulaire
porté (**9 053 l pour 27 écrans, soit 335 l par écran**) — c'est ce chiffre que l'objectif produit n°2
doit faire tomber.

---

## 2. Ce que le domaine sait faire (en termes d'utilisateur)

- **Saisir une fiche** de n'importe quelle entité à partir d'une seule déclaration de champs :
  texte, nombre entier/décimal, oui-non, heure, date, date-heure, icône, horodatage, liste de choix,
  choix pioché dans une autre collection, puces cliquables, case, radio, fichier, image, couleur,
  mot de passe, champ caché, widget libre, **sous-liste d'éléments**, markdown (bloc et en ligne),
  HTML (bloc et en ligne), numéro de téléphone international — 26 types (`edition_field.dart:18-45`).
- **Écrire du texte riche** : éditeur Quill avec formules LaTeX (`embeds/formula_embed.dart` 1 157 l,
  `formula_edit_dialog.dart` 225 l, `latex_html_part.dart` 191 l) et **tableaux éditables**
  (`table_editor_screen.dart` 988 l, `table_edit_dialog.dart` 387 l, `syncfusion_table_widget.dart`
  485 l, `table_view_embed.dart` 333 l) ; conversion Delta ↔ Markdown dans les deux sens
  (`delta_to_markdown_helper.dart` 613 l, `markdown_to_delta_helper.dart` 383 l) ; variante HTML
  (`html_editor_wrapper.dart` 370 l).
- **Gérer les droits ligne à ligne** : `RessourceACL` porté par le champ *et* par l'écran
  (`acl:` 41 occ), `aclBuilder`, et une **matrice de permissions** éditable
  (`z_iffd_acl_matrix_field.dart` 262 l).
- **Créer / copier / lire / modifier / supprimer** avec le même écran, piloté par l'énum `Crud`
  (`crud:` 146 occ) — dont un mode **copie** distinct de la création.
- **Sous-listes imbriquées** dans un formulaire (`subItems`, `sub_list_screen.dart` 555 l,
  `subitem_menu_option.dart` 46 l) avec menu contextuel par ligne.
- **Listes dynamiques** : tableau déclaré par `DynamicListField` (largeur, devise, traducteur,
  suffixe calculé, colonne masquée) et onglets filtrés `DynamicTab` (`models.dart:275-303`).
  Usage réel **faible** : 11 déclarations sur 4 fichiers seulement.
- **Journal de la dernière opération** : `LastCrudOperation` (`models.dart:24-121`) sérialisé,
  pour rejouer/annuler.
- **Métier IFFD** : dossiers d'étude et sous-dossiers, matières/filières/cycles, années académiques,
  auditeurs et comptes, rôles applicatifs, examens et examens blancs, flashcards + révision espacée,
  cartes mentales, notes intelligentes, documents de dossier, outils d'évaluation, agents IA experts,
  routeurs IA, conversations de chatbot, tâches et agenda (`lib/workflow/`).

---

## 3. Ce qui est déjà branché sur zcrud

**Dépendances.** 23 paquets `zcrud_*` déclarés en `dependencies` + **25** en `dependency_overrides`
(`pubspec.yaml:305-729`), tous épinglés `ref: v3.21.0`. **22** paquets sont réellement importés par
du code :

| Paquet | imports | Paquet | imports |
|---|---:|---|---:|
| `zcrud_core` | 67 | `zcrud_firestore` | 5 |
| `zcrud_chat_kernel` | 19 | `zcrud_ui_kit` / `zcrud_session` / `zcrud_note` / `zcrud_exam` / `zcrud_document` / `zcrud_chat_syncfusion` / `zcrud_chat_material` | 3 chacun |
| `zcrud_study` | 17 | `zcrud_select` / `zcrud_intl` / `zcrud_chat_markdown` | 2 chacun |
| `zcrud_screen` | 16 | `zcrud_menu` | 1 |
| `zcrud_chat` | 15 | | |
| `zcrud_markdown` / `zcrud_flashcard` | 11 chacun | | |
| `zcrud_study_kernel` | 8 | | |
| `zcrud_navigation` / `zcrud_mindmap` | 6 chacun | | |

**19 paquets sur 41 ne sont jamais importés** (grep négatif exécuté paquet par paquet sur
`iffd/lib`) : `zcrud_annotations`, `zcrud_chat_firestore`, `zcrud_chat_study`, `zcrud_dnd`,
`zcrud_export`, `zcrud_export_pdf`, `zcrud_export_ui`, `zcrud_field_extras`, `zcrud_generator`,
`zcrud_geo`, `zcrud_geo_location`, `zcrud_get`, `zcrud_html`, `zcrud_list`, `zcrud_media`,
`zcrud_provider`, `zcrud_reorder`, `zcrud_responsive`, **`zcrud_riverpod`**.

> `grep -rq --include='*.dart' 'package:zcrud_riverpod' /home/zakarius/DEV/iffd/lib` → **aucun résultat**
> `grep -rq --include='*.dart' 'package:zcrud_list'    /home/zakarius/DEV/iffd/lib` → **aucun résultat**

Deux conséquences directes : (a) **`zcrud_riverpod` est déclaré mais jamais utilisé** — l'injection
passe par 180 `ProviderScope.containerOf(...).read(...)` écrits à la main (D17) ; (b) **aucune liste
n'est portée** : `zcrud_list` (1 652 l, v3.21.0) est absent, et le `DynamicListScreen` legacy
(1 753 l) n'a pas de jumeau. La bascule en cours est **une bascule d'ÉDITION, pas de LISTE**.

**Enregistrement au registre.** Un seul point de montage, `IffdZcrudScope`
(`lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart:227-345`, 461 l) :
`registerZMarkdownFields` (6 occ), `registerZFlashcardEditors` (3), `registerZHtmlFields` (1),
et **deux** enregistrements maison — `registry.register('phoneNumber', ZPhoneFieldWidget.builder())`
(`:188`) et `registry.register(kIffdBooleanKind, iffdBooleanBuilder())` (`:199`). Le scope injecte
aussi `iffdFormTheme` (`z_iffd_form_theme.dart` 281 l), un `ZSmartSelectPresenter` (`:339`),
`IffdNumberDisplayFormatter` (`:418`) et `IffdDateDisplayFormatter` (`:446`).

**Jumeaux portés et drapeaux.** `lib/src/presentation/shared/zcrud/z_qa_flags.dart` (985 l) tient
**52 bascules** (`ZQaFlag`, 52 `provider:`), classées :

| Famille | Nombre | Méthode imposée par le fichier |
|---|---:|---|
| `rendu` | **10** | par lots de 3 à 5, QA visuelle |
| `comportement` | **28** | une par story, QA du parcours |
| `donnees` | **14** | une par story, relevé avant/après sur compte de test (`changesData: true`) |

Une assertion du constructeur (`z_qa_flags.dart:122-130`) force `famille == donnees` et
`changesData` à varier ensemble — j'ai vérifié la cohérence : 14 `famille: ZQaFamille.donnees`
et 14 `changesData: true` réels (2 des 16 correspondances brutes sont dans des commentaires,
`:867` et `:909`).

Les **27** fichiers `*_zcrud_edition.dart` (9 053 l) couvrent : dossier, filtre dossiers, filtre
flashcards de dossier, comptage de questions, étiquette de flashcard, export PDF, matière, examen,
année académique, auditeur IFFD, compte auditeur, rôle applicatif, filtre auditeurs, filtre agents,
agent IA expert, routeur IA, URL de base IA, conversation chatbot, note intelligente, instructions IA
de note, carte mentale, texte d'élément de carte mentale, document de dossier, outil d'évaluation,
première connexion, notes de workflow, liste de tâches.

Documentation d'accompagnement de l'hôte : `docs/qa-plan-comparaison-legacy-zcrud.md` (**651 l**),
une entrée `###` par bascule.

**Change requests.** `docs/zcrud-change-requests.md` : **7 899 l**, **76** CR. Le lot le plus récent
n'est pas de sept CR émises : **CR-IFFD-114, 115 et 116 sont émises** ; **117, 118, 119 et 120 portent
« RETIRÉE AVANT ÉMISSION »** dans leur titre même (`:7787`, `:7825`, `:7859`, `:7879`) — l'hôte a
retrouvé le canal existant avant de demander quoi que ce soit. Sujets des trois émises : géométrie du
tableau markdown rendu (`:7589`), retour à la ligne souple recollé en espace (`:7675`), absence de
sous-titre sur le dialogue d'édition plein écran (`:7734`).

---

## 4. Widgets maison qui refont ce que le socle fait probablement

| Widget / helper | Chemin | Lignes | Équivalent socle plausible |
|---|---|---:|---|
| Boîte à outils de dialogues de formulaire (`showPushedDialog`, `buildDialog`, `scaffoldDialog`, `buildConfirmDialog`, `buildDeleteConfirmation`, `buildDialogFormActions`, `buildAddButton`, `showResourceBottomModalDialog`, `listenToScrool`) | `lib/src/utils/functions/forms_utils.dart` | **1 193** | `zcrud_screen` (v3.14.0) + confirmations du socle |
| Moteur d'édition legacy | `lib/data_crud/edition_screen.dart` | **4 073** | `zcrud_core` `DynamicEdition` |
| Moteur de liste legacy | `lib/data_crud/dynamic_list_screen.dart` | **1 753** | `zcrud_list` (**non importé**) |
| Éditeur riche legacy + embeds LaTeX/tableaux | `lib/data_crud/rich_text_editor_screen.dart` + `rich_text_editor/` + `embeds/` | **773 + 3 106 + 3 766** | `zcrud_markdown` (importé 11 fois — cohabite) |
| Aides de menu contextuel | `lib/src/presentation/core/widgets/popup_menu_helpers.dart` | **1 016** | `zcrud_menu` (importé **1** fois) |
| Barre d'app avec recherche | `lib/src/presentation/core/widgets/dynamic_searcheable_app_bar.dart` | 372 | `zcrud_ui_kit` `ZAppBarAction` |
| Menu latéral + i18n dédiée (10 langues) | `lib/src/presentation/core/side_menu/` | **1 346** (15 fichiers) | `zcrud_menu` / `zcrud_navigation` |
| Indicateurs de chargement | `lib/src/presentation/core/widgets/loading_indicators.dart` | 100 | état chargement/vide/erreur du socle |
| Base de dialogue d'item | `lib/src/presentation/core/widgets/dialog_widgets.dart` (`StatelessItemDialogWidget`, 13 sites) | 48 | menu d'actions CRUD |
| Champ matrice d'ACL | `lib/src/presentation/shared/zcrud/z_iffd_acl_matrix_field.dart` | 262 | aucun connu — cf. §7 |
| Champ comptage de questions | `.../z_questions_counts_field.dart` | 169 | aucun connu — cf. §7 |
| Champ booléen `FlutterSwitch` | `.../z_iffd_boolean_field.dart` | 140 | jeton de rendu booléen du socle |
| Codec markdown IFFD | `.../z_iffd_rich_text_codec.dart` | 193 | `ZCodec` de `zcrud_markdown` |
| Palette / thème de formulaire | `.../z_iffd_field_palette.dart` 225 + `z_iffd_form_theme.dart` 281 + `z_iffd_markdown_style.dart` 153 | 659 | `ZcrudTheme` / `ThemeExtension` (FR-26) |
| Passerelle de drapeaux | `.../z_flag_gateway.dart` | 86 | échafaudage de migration |

---

## 5. Écrans et dialogues

Les vingt plus gros fichiers de présentation (hors code généré) :

| Fichier | Lignes | Rôle | Ce qu'il porte |
|---|---:|---|---|
| `lib/workflow/screens/appointment_editor.dart` | **7 858** | Éditeur de rendez-vous/agenda | 4 `AlertDialog`, 6 `EditionScreen(` dans `agenda_screen.dart` voisin |
| `lib/ai_assistant/screens/chatbot_conversation_screen.dart` | **5 356** | Conversation chatbot | 7 confirmations, socle `zcrud_chat` en parallèle |
| `lib/data_crud/edition_screen.dart` | **4 073** | Moteur d'édition legacy | 38 `case EditionFieldTypes.`, `MyInheritedForm`, `DynamicEditionScreenState` |
| `lib/src/presentation/features/folders/pages/folder_study_tools_page.dart` | 2 265 | Outils d'étude d'un dossier | drapeau `studyTools` |
| `.../folders/pages/folder_details_page.dart` | 2 037 | Détail d'un dossier | drapeau `folderDetail` |
| `.../documents/widgets/folder_documents_actions_dialog_widget.dart` | **1 804** | Actions sur un document | 3 confirmations ; le plus gros des 8 dialogues d'actions (D9) |
| `lib/data_crud/dynamic_list_screen.dart` | 1 753 | Moteur de liste legacy | 7 `EditionScreen(`, 8 confirmations |
| `lib/workflow/components/recurrence_picker.dart` | 1 721 | Récurrence d'événement | 1 confirmation |
| `.../folders/pages/folders_page.dart` | 1 542 | Liste des dossiers | drapeaux `folderCard`, `folderCardDefault` |
| `.../administration/pages/ai_experts_page.dart` | 1 330 | Agents IA experts | — |
| `.../flashcards/pages/multi_flashcard_editor_page.dart` | 1 319 | Édition multiple de flashcards | 15 `DynamicFormField(`, 2 confirmations, drapeau `multiEditor` |
| `lib/workflow/screens/event_editon_screen.dart` | 1 308 | Édition d'événement | 1 `EditionScreen(` |
| `.../administration/pages/auditeurs_pages.dart` | 1 281 | Auditeurs | 6 `DynamicFormField(` |
| `.../flashcards/widgets/flashcard_widgets.dart` | 1 250 | Cartes de flashcard | — |
| `.../flashcards/widgets/ai_flashcards_generator_dialog_widget.dart` | 1 238 | Génération IA de flashcards | — |
| `.../flashcards/widgets/interactive_flashcard_repetition_card.dart` | 1 205 | Carte de révision | drapeau `reviewSession` |
| `.../flashcards/pages/folder_flashcards_repetitions_page.dart` | 1 202 | Session de révision | — |
| `.../administration/dialogs/ai_experts_dialogs.dart` | **1 200** | Dialogues agents IA | **40** `DynamicFormField(`, 3 `EditionScreen(` — record du dépôt |
| `lib/src/utils/functions/forms_utils.dart` | 1 193 | Enveloppes de dialogues | 3 confirmations, 9 helpers publics |
| `.../flashcards/pages/folder_flashcards_list_page.dart` | 1 139 | Liste des flashcards | 4 `DynamicFormField(`, drapeau `flashcardList` |

Familles de dialogues : **13** `*_dialogs.dart` (**6 438 l**), **8** `*_actions_dialog_widget.dart`
(**3 554 l**), **49** fonctions `show*` top-level.

---

## 6. Modèles et persistance

**Entités.** `lib/src/domain/models/` : 6 758 l. Les plus grosses : `app_user.dart` 589,
`valuation/valuation_tool_model.dart` 581, `ai/ai_models.dart` 581, `folder_model.dart` 489,
`flashcard_repetition_info.dart` 489, `annee_accademique.dart` 483, `cgi/cgi.dart` 466,
`mindmap_model.dart` 415, `flashcard_model.dart` 410. Toutes descendent d'un `DynamicModel`
(40 occ / 29 fichiers). **La sérialisation est intégralement manuelle** : 64 `toMap()`, 62
`factory …fromMap`, 63 `copyWith`, 91 `toJson`/`fromJson`, 50 `operator ==` — soit **3 479 lignes**
de code que le générateur produirait (D1). Grep négatif : `JsonSerializable` **0 occurrence** dans
`lib` ; `reflectable` n'apparaît que **commenté**, dans `lib/src/domain/models/reflector.dart:1-3`.
Le routage type → fabrique est un `switch` de 23 entrées écrit à la main
(`lib/src/utils/functions/data_functions.dart:314`, fichier de 515 l).

**Dépôts et source.** 25 fichiers `*repository*` (**10 297 l**). Contrat legacy `CrudRepository`
(139 occ / 53 fichiers) avec `DataRequest` neutre (236 occ / 59 fichiers). Implémentations :
`firebase_crud_repository_impl.dart` (499 l), `supabase_crud_repository_impl.dart` (377 l),
`firebase_cloud_storage_repository_impl.dart` (129 l), trois dépôts IA
(`iffd_ai_repository_impl.dart` 1 377, `openai_…` 672, `cloud_functions_…` 499). Firestore n'est pas
isolé : `cloud_firestore` est importé par **51 fichiers** (103 occ), `FirebaseFirestore` par 14.
Six dépôts `z_backed_*` (**4 648 l**) réimplémentent chacun la même surface de 18 méthodes pour
adosser une entité zcrud au contrat legacy (D2) ; `ZSyncMeta` y apparaît 84 fois sur 10 fichiers.

**Erreurs.** `ZFailure` est présent (50 occ / 18 fichiers) mais le style `Either<ZFailure, T>` ne
l'est pas : **1 seule** occurrence de `Either<` dans tout `lib`, contre **300** `try {` sur 110
fichiers et 123 `catch (e`. Le rendu d'erreur asynchrone est quasi absent : 133 `StreamBuilder`
pour **5** `snapshot.hasError`.

---

## 7. Ce qui est particulier à IFFD

1. **La matrice d'ACL par ressource.** `RessourceACL` traverse champ, écran et dialogue d'actions
   (`acl:` 41 occ ; `aclBuilder` sur `DynamicFormField`) et se rend comme un champ à part entière
   (`z_iffd_acl_matrix_field.dart`, 262 l). Aucun équivalent importé du socle.
2. **Le comptage de questions par type.** `z_questions_counts_field.dart` (169 l) — un champ dont
   la valeur est une répartition (QCM / question ouverte / …) alimentant la génération d'examens.
3. **Filières, cycles et année académique** comme axes de filtrage transverses : `subjectFiliereChoices`
   dépend de `accademicYearProvider`, ce qui rend la source de choix d'un champ **dépendante du
   contexte applicatif**, pas seulement de l'état du formulaire.
4. **Le mode `Crud.copy`**, distinct de `create`, avec réattribution d'identifiant
   (`result["id"] = randomString()`, `subject_model_dialogs.dart:70`).
5. **Les embeds LaTeX et tableaux dans le texte riche** (3 766 l sur 7 fichiers) : formules éditables et tableaux
   Syncfusion inclus dans le Delta, avec aller-retour Markdown maison (996 l de conversion).
6. **Le module `lib/workflow/`** (agenda, tâches, récurrences, rappels — `appointment_editor.dart`
   7 858 l, `recurrence_picker.dart` 1 721 l) avec sa **propre l10n** (`workflow/l10n.dart`,
   `workflow/l10n/messages/fr.dart`) : un sous-domaine calendaire complet, sans rapport avec le CRUD.
7. **Le menu latéral avec sa i18n en 10 langues** (`side_menu/l10n/messages/{fr,en,de,es,it,ja,ko,pt,zh}.dart` — 1 346 l sur 15 fichiers)
   alors que l'application est francophone — vestige d'un composant tiers absorbé.
8. **Syncfusion en `^32`** côté hôte contre `^34` exigé par `zcrud_list`/`zcrud_export`
   (`pubspec.yaml:292`) : c'est la raison écrite pour laquelle la **liste** n'est pas portée.
9. **Le registre de drapeaux comme artefact de produit.** `z_qa_flags.dart` porte une assertion qui
   interdit au classement de se contredire, et son dartdoc raconte que le registre **s'est déjà
   contredit** (annonçait cinq bascules de données, en marquait sept). C'est une pratique d'hôte
   à propager, pas une particularité à généraliser.

---

## Ce que j'ai inclus au-delà du périmètre demandé

`lib/src/domain/models/` et `lib/src/data/repositories/` (§1 D1/D2/D13, §6) — les six
`z_backed_*_repository.dart` sont la plus grosse duplication du dépôt et sont invisibles depuis
`lib/data_crud/` ; `lib/src/utils/functions/forms_utils.dart` et `data_functions.dart` (les helpers
que tout dialogue appelle) ; `lib/src/presentation/core/widgets/` et `core/side_menu/` (§4) ;
`lib/workflow/` (§5, §7) ; `docs/zcrud-change-requests.md` par `git log` sur le registre, jamais
relu en entier.
