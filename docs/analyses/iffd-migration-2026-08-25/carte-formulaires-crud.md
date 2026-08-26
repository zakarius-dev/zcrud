# Carte du domaine — « Moteur de formulaires, listes et écrans CRUD historique » (IFFD)

> Relevé du **2026-08-25**, dépôt `/home/zakarius/DEV/iffd` (branche courante, lecture seule).
> Toutes les lignes sont comptées avec `wc -l` sur le disque le jour du relevé.
> Toute affirmation d'**absence** porte son grep négatif, montré.
>
> 🔴 **CIBLE MOUVANTE — à savoir avant de se servir de ces chiffres.** IFFD était **écrit
> pendant le relevé**, par quelqu'un d'autre. `git status` sur IFFD, pris à la fin (14:19 GMT),
> montre deux fichiers modifiés et **deux jumeaux zcrud NEUFS** apparus entre 14:17 et 14:19 :
> `.../administration/dialogs/auditeurs_filter_zcrud_edition.dart` (222 l) et
> `.../mindmap/zcrud/text_menu_zcrud_edition.dart` (126 l), avec
> `lib/src/presentation/shared/zcrud/z_qa_flags.dart` **+17 lignes** (le registre est passé de
> **34 à 35 bascules**) et `.../mindmap/widgets/text_menu.dart` **+109/−22** (une passerelle
> strangler de plus). Les comptages de ce rapport ont été pris **avant** ces quatre écritures :
> lire « 34 bascules », « 18 paires de jumeaux », « 79 fichiers de portage » comme un état à
> 14:00, pas comme un état stable. Le sens ne change pas — le portage avance dans la direction
> décrite —, les nombres exacts oui.
> Aucune de ces écritures n'est de moi : toutes mes commandes sur IFFD ont été `cat` / `grep` /
> `find` / `sed -n` / `wc` / `git status`.

---

## 0. Périmètre mesuré

Le point de départ donné était `lib/data_crud/` (32 fichiers) *et tout écran hôte déclarant des
champs ou des colonnes*. J'ai suivi les dépendances réelles et **inclus au-delà** :

| Bloc | Fichiers | Lignes | Pourquoi inclus |
|---|---:|---:|---|
| `lib/data_crud/` — le moteur | 32 | 16 889 | point de départ |
| Consommateurs déclarant champs/colonnes (`DynamicFormField`/`DynamicListField`/`DynamicListScreen`) | 40 | 20 374 | ce sont les « écrans hôtes » demandés |
| `lib/src/domain/models/` | 31 | 6 758 | le moteur circule en `Map<String,dynamic>` produites par ces modèles |
| `lib/src/domain/repositories/` (ports) | 31 | 2 067 | `CrudRepository<T>` est **un paramètre de champ** (`choiceItemsRepository`) |
| `lib/src/data/` (adapters Firestore + migration) | 22 | 10 197 | seule implémentation des ports |
| `lib/src/domain/security/` (ACL/Crud) | 8 | 1 582 | `RessourceACL` traverse formulaire ET liste |
| Socle transverse (`forms_utils`, `data_functions`, `databases_functions`, `databases`, `data_state`, `firestore_data_state`) | 6 | 1 907 | `showPushedDialog`, `scaffoldDialog`, `fromMap<T>/toMap<T>` |
| **Union dédupliquée du domaine** | **169** | **58 581** | |

À part, parce que c'est le **portage en cours** et non le domaine historique :

| Bloc | Fichiers | Lignes |
|---|---:|---:|
| Portage zcrud (`**/zcrud/**` + `*_zcrud_edition.dart` + `shared/zcrud/` + `ai_assistant/zcrud/`) | 79 | 22 181 |

Repères de contexte : `lib/` entier = **536 fichiers / 173 587 lignes** (dont 17 fichiers générés,
4 786 lignes — tous des providers `riverpod_generator`, aucun code de sérialisation).
`test/` = 204 fichiers de test / 50 671 lignes, dont **25 touchent `data_crud`**.

---

## 1. Ce que le domaine SAIT FAIRE

Formulé du point de vue de quelqu'un qui tient l'appareil, pas de quelqu'un qui lit le code.

### Saisie / édition (moteur `DynamicEditionScreen`)

1. **Saisir ou modifier n'importe quelle entité à partir d'une simple description de champs** —
   le même écran sert la création, la modification, la copie, la validation et la lecture seule
   (`edition_field.dart:18-45` déclare 26 types ; `edition_screen.dart:687-3833` en rend 19,
   cf. §6).
2. **Taper du texte** avec forçage de casse (tout en majuscules, tout en minuscules, première
   lettre) et **suggestions d'autocomplétion** (`edition_field.dart:75-78`, `:187`).
3. **Saisir des nombres** entiers, décimaux ou **des montants en devise**, avec bornes minimum et
   maximum **lues dans un autre champ du même formulaire** (`edition_field.dart:152-153`).
4. **Basculer un oui/non** (`edition_screen.dart:1131`).
5. **Choisir une couleur** dans une palette, avec mémoire des couleurs récentes
   (`edition_screen.dart:1304`, `edition_field.dart:181`).
6. **Choisir dans une liste** — en fenêtre modale, en pastilles, en boutons radio ou en cases à
   cocher, en choix unique ou multiple, avec sous-titre et rendu de ligne personnalisables
   (`edition_screen.dart:1684-1686`).
7. **Choisir un élément d'une autre collection distante** (Firestore), la liste étant filtrée en
   fonction de ce qui est déjà saisi, **et créer / modifier / copier cet élément lié sans quitter
   le formulaire** (`edition_screen.dart:1687`, `edition_field.dart:328-392`).
8. **Saisir une date, une heure, un horodatage**, avec bornes croisées (« date de fin » bornée par
   « date de début », par nom de champ) (`edition_screen.dart:2879-2938`, `edition_field.dart:157-160`).
9. **Gérer une sous-liste d'éléments à l'intérieur du formulaire** — ajouter, modifier, supprimer,
   réordonner, avec son propre formulaire et son propre menu contextuel
   (`edition_screen.dart:3352`, `sub_list_screen.dart`).
10. **Écrire du texte riche** — markdown ou HTML, en plein écran ou intégré au formulaire
    (`edition_screen.dart:3431-3432`, `:3717`).
11. **Insérer des formules mathématiques LaTeX**, en bloc ou dans le fil du texte, les voir rendues
    et les rouvrir pour les corriger (`embeds/formula_embed.dart`, 1 157 lignes).
12. **Insérer des tableaux dans le texte riche** et les éditer dans un tableur dédié (choix de la
    taille, en-têtes, redimensionnement de colonnes) (`embeds/table_editor_screen.dart`, 988 lignes ;
    `embeds/table_size_picker.dart`, 478 lignes).
13. **Ne voir un champ que quand il est pertinent** — affichage conditionnel selon l'état de saisie
    et l'opération en cours (`edition_field.dart:147-148`).
14. **Grouper des champs en sections repliables**, l'état plié/déplié étant mémorisé entre sessions
    (`edition_field.dart:110` `childreen`, `forms_utils.dart:57-66` `MySctickyHeaderState`).
15. **Être averti d'une saisie invalide champ par champ** (obligatoire, e-mail, date, bornes)
    (`edition_field.dart:109` `validators`).
16. **Ouvrir le même formulaire de quatre façons** : page pleine, dialogue, dialogue plein écran,
    feuille inférieure (`forms_utils.dart:727` `showPushedDialog`, `:804` `scaffoldDialog`).

### Consultation en liste (moteur `DynamicListScreen`)

17. **Voir n'importe quelle entité en tableau** avec colonnes déclarées, tri, filtre par colonne,
    largeur, numérotation de ligne et colonne d'identifiants (`dynamic_list_screen.dart:691-751`).
18. **Chercher en texte libre**, insensible aux accents, sur toutes les colonnes déclarées
    (`dynamic_list_screen.dart:759-770`).
19. **Basculer entre plusieurs onglets de catégorisation**, chacun avec son filtre — l'onglet actif
    et la position de défilement étant **retenus d'une session à l'autre**
    (`categorysation_screens.dart:8-42`).
20. **Utiliser une corbeille** : mise à la corbeille, consultation de la corbeille, restauration,
    purge (`dynamic_list_screen.dart:1272` `trashWidget`, `:1505` `askForDeleteConfirmation`).
21. **Agir sur une ligne** — voir en détail, modifier, faire une copie, valider, mettre à la
    corbeille — en boutons de ligne ou en menu contextuel sur appui long
    (`dynamic_list_screen.dart:73-311` `CrudActionsButons`).
22. **Sélectionner plusieurs lignes** (`dynamic_list_screen.dart:786-800`).

### Transverse

23. **Ne voir que ce à quoi on a droit** — onze permissions par ressource (lire, créer, modifier,
    copier, supprimer, restaurer, archiver, publier, vider, valider, historique) qui masquent ou
    désactivent chaque commande (`ressource_acl.dart:1-26`).
24. **Savoir qui a fait quoi et quand** — journal des opérations CRUD par élément, avec l'auteur
    (`models.dart:24-121` `LastCrudOperation`, `edition_screen.dart:67-87` `saveOperation`).
25. **Lire des titres et libellés en français corrects** — genre, pluriel, contraction (« de la »
    / « de l' »), dérivés du **type** de la ressource et de l'opération
    (`l10n/messages/abstract.dart:1-133`, `l10n/messages/fr.dart`, 298 lignes).
26. **Recevoir un retour visuel** de succès / erreur / information / avertissement
    (`notifications.dart:1-80`).
27. **Échapper au déclaratif** — poser un widget arbitraire à la place d'un champ, sans quitter le
    formulaire (`EditionFieldTypes.widget`, **23 déclarations** dans 11 fichiers hôtes).

---

## 2. Les écrans

### 2.1 Écrans du moteur (`lib/data_crud/`, 32 fichiers, 16 889 lignes)

| Écran / composant | Chemin | Lignes | Rôle | Form. | Liste | Nav. | Riche |
|---|---|---:|---|:-:|:-:|:-:|:-:|
| `DynamicEditionScreen` | `lib/data_crud/edition_screen.dart` | **4 038** | le formulaire générique — 19 types de champs rendus | ✅ | | ✅ | ✅ |
| `DynamicListScreen` | `lib/data_crud/dynamic_list_screen.dart` | **1 753** | le tableau générique (Syncfusion `SfDataGrid`), onglets, corbeille, recherche | ✅ | ✅ | ✅ | |
| `FormulaEmbed` (bloc + inline) | `lib/data_crud/embeds/formula_embed.dart` | 1 157 | rendu et édition LaTeX dans Quill et Markdown | | | | ✅ |
| `TableEditorScreen` | `lib/data_crud/embeds/table_editor_screen.dart` | 988 | tableur plein écran pour les tableaux embarqués | ✅ | ✅ | | ✅ |
| `RichTextEditorScreen` / `RichTextReaderScreen` / `HtmlEditorScreen` | `lib/data_crud/rich_text_editor_screen.dart` | 756 | éditeur et lecteur de texte riche | ✅ | | ✅ | ✅ |
| `QuillMarkdownEditorWrapper` | `lib/data_crud/rich_text_editor/editors/quill_markdown_editor_wrapper.dart` | 698 | l'éditeur Quill habillé, barre d'outils, embeds | | | | ✅ |
| `DeltaToMarkdownHelper` | `lib/data_crud/rich_text_editor/delta_to_markdown_helper.dart` | 613 | codec Delta → Markdown | | | | ✅ |
| `InlineTableEmbedBuilder` | `lib/data_crud/embeds/inline_table_embed.dart` | 586 | tableau dans le fil du texte | | ✅ | | ✅ |
| `DynamicSubListScreen` | `lib/data_crud/sub_list_screen.dart` | **565** | sous-liste éditable **dans** un formulaire | ✅ | ✅ | | |
| `SyncfusionTableWidget` | `lib/data_crud/embeds/syncfusion_table_widget.dart` | 485 | grille des tableaux embarqués | | ✅ | | |
| `TableSizePicker` (+ dialogue, tooltip) | `lib/data_crud/embeds/table_size_picker.dart` | 478 | choix de la taille d'un tableau | ✅ | | | |
| `quill_default_styles_helper` | `lib/data_crud/rich_text_editor/quill_default_styles_helper.dart` | 474 | feuille de style Quill | | | | ✅ |
| `DynamicFormField` | `lib/data_crud/edition_field.dart` | **444** | **le « ZFieldSpec » historique** : 76 paramètres nommés (`:210-297`) | | | | |
| `MarkdownEditionField` | `lib/data_crud/rich_text_editor/editors/markdown_edition_field.dart` | 440 | le champ riche tel qu'il entre dans le formulaire | ✅ | | | ✅ |
| `TableEditDialog` | `lib/data_crud/embeds/table_edit_dialog.dart` | 387 | édition d'un tableau en dialogue | ✅ | | | ✅ |
| `MarkdownToDeltaHelper` | `lib/data_crud/rich_text_editor/markdown_to_delta_helper.dart` | 383 | codec Markdown → Delta | | | | ✅ |
| `HtmlEditorWrapper` | `lib/data_crud/rich_text_editor/editors/html_editor_wrapper.dart` | 370 | éditeur HTML | ✅ | | | ✅ |
| `TableViewEmbedBuilder` | `lib/data_crud/embeds/table_view_embed.dart` | 333 | tableau en lecture | | ✅ | | ✅ |
| `LastCrudOperation`, `S2CrudButton`, `DynamicTab` | `lib/data_crud/models.dart` | 304 | journal CRUD, bouton CRUD de sélecteur, onglet | | ✅ | | |
| `fr.dart` (libellés) | `lib/data_crud/l10n/messages/fr.dart` | 298 | titres/libellés français dérivés du type | | | | |
| `TableEmbedBuilder` | `lib/data_crud/embeds/table_embed.dart` | 270 | insertion de tableau | | | | ✅ |
| `FormulaEditDialog` | `lib/data_crud/embeds/formula_edit_dialog.dart` | 225 | édition d'une formule | ✅ | | | ✅ |
| `LatexHtmlPart` | `lib/data_crud/embeds/latex_html_part.dart` | 191 | LaTeX en rendu HTML | | | | ✅ |
| `DataCrudLocalizationsData` | `lib/data_crud/l10n/messages/abstract.dart` | 133 | contrat de localisation | | | | |
| `editor_css` | `lib/data_crud/rich_text_editor/editor_css.dart` | 100 | CSS de l'éditeur HTML | | | | ✅ |
| `DataCrudLocalizations` (delegate) | `lib/data_crud/l10n/localizations_delegate.dart` | 92 | délégué l10n | | | | |
| `ToastService` | `lib/data_crud/notifications.dart` | 80 | retours succès/erreur | | | | |
| `editor_config` | `lib/data_crud/rich_text_editor/editor_config.dart` | 75 | config éditeur | | | | |
| `DynamicDataTableSource` | `lib/data_crud/dynamic_data_table_builder.dart` | 47 | source `DataTable` Material | | ✅ | | |
| `DynamicSubItemMenuOption` | `lib/data_crud/subitem_menu_option.dart` | 46 | option de menu de sous-élément | | | | |
| `DynamicTabsState` | `lib/data_crud/categorysation_screens.dart` | 43 | onglet + défilement mémorisés | | ✅ | | |
| `DynamicListField` | `lib/data_crud/dynamic_list_field.dart` | **37** | **la « colonne » historique** : 14 paramètres (`:21-36`) | | ✅ | | |

### 2.2 Écrans hôtes qui déclarent des champs ou des colonnes

**Pages** (routées ou poussées) :

| Écran | Chemin | Lignes | Rôle | Form. | Liste | Nav. | Riche |
|---|---|---:|---|:-:|:-:|:-:|:-:|
| Détail d'un dossier | `lib/src/presentation/features/folders/pages/folder_details_page.dart` | 2 037 | contenu d'un dossier + 8 dialogues d'action | ✅ | ✅ | ✅ | ✅ |
| Dossiers | `.../folders/pages/folders_page.dart` | 1 542 | grille des dossiers, filtres, création | ✅ | ✅ | ✅ | |
| Agents IA experts | `.../administration/pages/ai_experts_page.dart` | 1 330 | liste + édition des experts | ✅ | ✅ | ✅ | |
| Éditeur multi-flashcards | `.../flashcards/pages/multi_flashcard_editor_page.dart` | 1 287 | saisie en lot de cartes | ✅ | ✅ | | ✅ |
| Auditeurs | `.../administration/pages/auditeurs_pages.dart` | 1 227 | liste + fiche auditeur + compte | ✅ | ✅ | ✅ | |
| Liste de flashcards d'un dossier | `.../flashcards/pages/folder_flashcards_list_page.dart` | 1 146 | liste + filtre (10 `crudDataSelect`) | ✅ | ✅ | ✅ | ✅ |
| Matières | `.../subjects/pages/subjects_page.dart` | 941 | liste + édition des matières | ✅ | ✅ | ✅ | |
| Fournisseurs IA | `.../ai_routers/pages/ai_routers_page.dart` | 803 | liste + édition des routeurs IA | ✅ | ✅ | ✅ | |
| Examen blanc | `.../flashcards/pages/white_exam_page.dart` | 779 | passage d'examen | ✅ | ✅ | | ✅ |
| Édition d'une flashcard | `.../flashcards/widgets/flashcard_edition_screen.dart` | 770 | 23 champs, 3 sous-listes | ✅ | ✅ | | ✅ |
| Promotions / années académiques | `.../administration/pages/accademic_years_page.dart` | 692 | liste + édition (12 matrices ACL) | ✅ | ✅ | ✅ | |
| Groupes d'utilisateurs | `.../administration/pages/user_role_page.dart` | 632 | liste + édition | ✅ | ✅ | ✅ | |
| Première connexion | `.../auth/pages/first_login_screen.dart` | 336 | formulaire d'inscription | ✅ | | ✅ | |
| Examens | `.../administration/pages/exams_page.dart` | 333 | liste + édition | ✅ | ✅ | ✅ | |
| Filtre d'examen blanc | `.../flashcards/widgets/test_exam_filter_screen.dart` | 134 | 6 champs de filtre | ✅ | | | |

**Dialogues d'édition** (l'entrée réelle de tout CRUD d'IFFD) :

| Écran | Chemin | Lignes | Rôle |
|---|---|---:|---|
| Experts IA | `.../administration/dialogs/ai_experts_dialogs.dart` | **1 200** | 40 `DynamicFormField`, 1 751 lignes de déclaration de champs |
| Flashcards (7 dialogues) | `.../flashcards/dialogs/flashcards_dialogs.dart` | 779 | édition, actions, création, génération IA, tags, filtre, mode d'apprentissage |
| Routeurs IA | `.../ai_routers/dialogs/ai_routers_dialogs.dart` | 716 | 12 champs, 2 sous-listes |
| Dossiers (9 dialogues) | `.../folders/dialogs/folder_modal_dialogs.dart` | 715 | édition, actions, co-auteurs, import, ajout de contenu, tags, sélection |
| Auditeurs IFFD | `.../administration/dialogs/auditeurs_iffd_modal_dialogs.dart` | 438 | 10 champs + fabrique `permissionsField` |
| Groupes d'utilisateurs | `.../administration/dialogs/app_user_role_dialogs.dart` | 374 | 5 champs + matrice ACL |
| Notes intelligentes | `.../smartnotes/dialogs/smartnotes_dialogs.dart` | 339 | 11 champs |
| Matières | `.../subjects/dialogs/subject_model_dialogs.dart` | 333 | 10 champs |
| Documents de dossier | `.../documents/dialogs/documents_dialogs.dart` | 323 | édition, actions, visionneuse |
| Promotions | `.../administration/dialogs/annee_accademique_modal_dialogs.dart` | 306 | 4 champs + 12 matrices ACL |
| Examens | `.../administration/dialogs/exames_dialogs.dart` | 282 | 4 champs |
| Cartes mentales | `.../mindmap/dialogs/mindmap_dialogs.dart` | 179 | 2 champs |
| Outils d'évaluation | `.../valuation_tools/dialogs/valuation_tool_model_dialogs.dart` | 155 | 4 champs, générique `<T extends ValuationToolModel>` |

**Écrans hôtes MORTS** (grep négatif à l'appui) :

- `lib/agents_screens.dart` (**535 lignes**) — porte le **seul** usage réel de `DynamicListScreen`
  avec onglets (`:164`), 14 `DynamicFormField`, 5 `DynamicListField`.
  `grep -rn "\bAgentsScreen\b" lib --include='*.dart' | grep -v '^lib/agents_screens.dart'` → **0 résultat**.
  Le fichier n'est retenu que pour un tri de 15 lignes (`ordonnerLesAuditeurs`, `:23-37`) importé
  par `lib/src/domain/models/app_user.dart:8` et appelé à `:522`.
- `lib/cotation/cotations_screen.dart` (148 lignes) — second usage de `DynamicListScreen` (`:35`).
  `grep -rn "cotations_screen" lib --include='*.dart' | grep -v '^lib/cotation/cotations_screen.dart'` → **0 résultat**.

---

## 3. Modèles de domaine et persistance

### 3.1 Modèles

31 fichiers, **6 758 lignes** sous `lib/src/domain/models/`. Les plus lourds :
`app_user.dart` 589, `valuation/valuation_tool_model.dart` 581, `ai/ai_models.dart` 581,
`folder_model.dart` 489, `flashcard_repetition_info.dart` 489, `annee_accademique.dart` 483,
`cgi/cgi.dart` 466, `mindmap_model.dart` 415, `flashcard_model.dart` 410.

**Sérialisation : entièrement manuelle.**
- **64** méthodes `Map<String, dynamic> toMap()` écrites à la main dans `lib/` ;
- **66** fabriques `factory X.fromMap(...)` ;
- `grep -rn "@ZcrudModel" lib --include='*.dart'` → **0 résultat** (grep négatif : aucun modèle
  n'est annoté zcrud) ;
- `grep -n "reflectable" pubspec.yaml` → **0 résultat** ; les seules occurrences de `reflectable`
  dans `lib/` sont **deux lignes commentées** (`lib/src/domain/models/reflector.dart:1,3`) ;
- les 17 fichiers `*.g.dart` / `*.freezed.dart` (4 786 lignes) sont **tous** des providers
  `riverpod_generator` ou `failures.freezed.dart` — **aucun** ne sert la (dé)sérialisation d'entité.

**Le dispatch type → fabrique est une table écrite à la main** :
`lib/src/utils/functions/data_functions.dart:314-415` — `T fromMap<T>(Map)` contient une
`Map<Type, dynamic Function()> factories` de **46 entrées** (`AnneeAccademique`, `FolderModel`,
`SubjectModel`, … + 7 types CGI + 5 types workflow + les types d'évaluation). Le symétrique
`toMap<T>` (`:223-247`) ne connaît que `Map<String,dynamic>` et `IconData` en dur, puis tente
`item.toMap()` **dans un `try`**, puis `item.toJson()` **dans un second `try`**, et rend `{}` en
silence si les deux échouent (`:239-245`).

**Fuite Firestore dans le domaine, mesurée** : `package:cloud_firestore` est importé par
**15 des 71 fichiers** de `lib/src/domain/` (13 modèles + `requests/data_request.dart` +
2 ports) ; **92** occurrences de `Timestamp` dans `lib/src/domain/models/`.
`package:firebase_auth` est importé par `lib/src/domain/security/crud.dart`,
`app_user_permissions.dart` et `app_user.dart`. Le moteur lui-même importe `cloud_firestore`
dans 3 fichiers (`models.dart`, `edition_screen.dart`, `sub_list_screen.dart`) et
`firebase_auth` dans `edition_screen.dart`.

### 3.2 Ports

`lib/src/domain/repositories/` — 31 fichiers, 2 067 lignes.
Le contrat pivot est `CrudRepository<T>` (`datacrud_repository.dart:20-64`) : 20 méthodes,
`create` / `mapCreate` / `streamByIds` / `streamAll` / `streamOne` / `all` / `count` /
`asyncCount` / `batchDelete` / `find` / `batchSet` / `batchUpdate` / `update` / `mapUpdate` /
`softDelete` / `delete` / `restore`, plus `objectType` et `crudableObjects` pour l'ACL.

Ce port est **directement un paramètre de champ de formulaire** :
`DynamicFormField.choiceItemsRepository` (`edition_field.dart:116`) — c'est ce qui permet à un
champ `crudDataSelect` de charger ses choix (`:394-430`) et de créer/modifier l'élément lié
(`:328-392`).

### 3.3 Source de données

**Firestore, sans cache local.**
- `grep -rn "package:hive" lib --include='*.dart'` → **0 résultat** (grep négatif : pas de Hive).
- **96** `StreamBuilder<…>` dans `lib/` — la lecture est en flux temps réel `snapshots()`.
- L'implémentation générique est `FirebaseCrudRepositoryImpl<T extends DynamicModel>`
  (`lib/src/data/repositories/firebase_crud_repository_impl.dart`, 499 lignes), spécialisée par
  **36 classes vides** dans `firebase_models_repositories_impls.dart` (434 lignes) — la plupart
  du type `class FirebaseFoldersRepositoryImpl extends FirebaseCrudRepositoryImpl<FolderModel>
  implements FoldersRepository {}` (`:66-68`).
- Le nom de collection vient de `getFirebaseCollectionName<T>()` (`databases_functions.dart:8-11`),
  qui lit `FIREBASE_COLLECTION_NAMES[T]` — table **vide** (`constants/databases.dart:3`) — et se
  rabat donc **toujours** sur `T.toString()`. Le nom de collection Firestore d'IFFD est le nom
  de la classe Dart.
- La pagination par curseur, le tri et les filtres passent par `DataRequest<T>`
  (`domain/models/requests/data_request.dart`, 213 lignes), qui **importe `cloud_firestore`**.
- Un second adaptateur existe et n'est pas branché : `supabase_crud_repository_impl.dart` (377 lignes) ;
  `grep -n "supabase" pubspec.yaml` ne montre que des lignes **commentées** (`# supabase_flutter`).

### 3.4 Traitement des erreurs

- Hiérarchie maison `DataState<T, E>` (`lib/src/utils/resources/data_state.dart`, 91 lignes) :
  `DataSuccess` / `DataFailed` / `DataNotSet` / `DataCreated` / `DataUpdated` / `DataDeleted`,
  déclinée en `FirestoreDataState` (48 lignes). **Aucun `Either` de dartz** :
  `grep -rn "package:dartz" lib` → **5 résultats**, tous dans le portage zcrud
  (`Right<ZFailure, Map<String,dynamic>>`), zéro dans le moteur historique.
- **300** blocs `try {` dans `lib/`, dont **119 `catch (_) {}` strictement vides** — l'erreur est
  avalée sans trace. Exemples dans le moteur : `edition_screen.dart:87` (échec d'écriture du
  journal CRUD), `edition_field.dart:437` (échec de résolution d'un élément lié),
  `models.dart:178` (élément de choix introuvable), `data_functions.dart:239-245`
  (échec de sérialisation → `{}`).
- **11** appels de retour visuel utilisateur sur erreur
  (`ScaffoldMessenger…showSnackBar` / `Get.snackbar` / `ToastService.error`) pour 300 `try`.
- **5** `snapshot.hasError` pour 96 `StreamBuilder` : **91 flux ne traitent pas leur erreur**.

---

## 4. Le code répété — le point décisif

### 4.1 Tableau de synthèse

⚠️ **Pas de total général : les lignes D2 à D8 vivent, pour partie, DANS les fichiers comptés en
D11.** Les additionner double-compterait. Chaque ligne est mesurée séparément et se lit seule.

| # | Bloc répété | Sites | Lignes / site | Lignes totales | Lignes retirables |
|---|---|---:|---:|---:|---:|
| D1 | Adaptateur Firestore `z_backed_*_repository` (streamAll/streamOne/streamByIds/_combine/asyncCount/put/softDelete/restore/delete/mapUpdate) | **6** | ~235 signif. | ~1 410 | **~1 175** |
| D2 | Déclaration de champs `DynamicFormField(...)` | **198 blocs** dans 40 fichiers | 31,5 moy. | **6 241** | — (matière à porter) |
| D3 | Écran d'état vide « cercle dégradé 180 dp + titre + sous-titre + bouton » | **6** | ~143 | ~858 | **~715** |
| D4 | Post-traitement CRUD d'un dialogue d'édition (`id = randomString()` → `fromMap<T>` → `switch(crud)` create/update) | **14** | ~19 | ~266 | **~247** |
| D5 | Enveloppe `show<X>ActionsDialog` (mêmes 8 paramètres, même `showPushedDialog`) | **9** | ~20 | ~180 | **~160** |
| D6 | Tuiles « Modifier » / « Supprimer » + confirmation, réécrites par entité | **12** (dans 11 fichiers ; 8 `*_actions_dialog_widget.dart` dédiés) | ~30 | ~360 | **~330** |
| D7 | `Scaffold`+`AppBar`+`Semantics('Enregistrer')`+`IconButton` des écrans zcrud | **8** | ~24 | ~192 | **~168** |
| D8 | `dispose()` + `_onSave()` des écrans zcrud (`_submit.dispose(); _controller.dispose();`) | **10** | ~10 | ~100 | **~90** |
| D9 | `RichTextReaderScreen(...) + getDefaultStyleSheet(isDark:, textScaleFactor:)` | **13** | ~8 | ~104 | **~96** |
| D10 | Spécialisation vide `class FirebaseXRepositoryImpl extends FirebaseCrudRepositoryImpl<X> implements XRepository {}` | **36** | ~4 | ~144 | ~0 (déjà minimal) |
| D11 | Jumeaux legacy ↔ zcrud d'une **même** entité (double implémentation vivante) | **18 paires** | — | **23 271** (15 305 legacy + 7 966 zcrud) | **≤ 15 305** (borne haute : ces fichiers legacy portent aussi du non-formulaire) |

### 4.2 D1 — les six adaptateurs Firestore jumeaux (le plus gros)

Six fichiers, 4 648 lignes cumulées, écrits sur le même patron :

| Fichier | Lignes |
|---|---:|
| `lib/src/data/repositories/z_backed_exam_repository.dart` | 912 |
| `lib/src/data/repositories/z_backed_mindmap_repository.dart` | 806 |
| `lib/src/data/repositories/z_backed_flashcard_repository.dart` | 797 |
| `lib/src/data/repositories/z_backed_folder_repository.dart` | 772 |
| `lib/src/data/repositories/z_backed_folder_document_repository.dart` | 698 |
| `lib/src/data/repositories/z_backed_smart_note_repository.dart` | 663 |

Mesure par plus longue sous-séquence commune (lignes significatives, commentaires et lignes de
ponctuation seule exclus) :

| Paire | Lignes signif. | Communes | Plus long bloc contigu |
|---|---|---:|---|
| `exam` ↔ `folder` | 438 / 400 | **230** | 59 lignes — `exam:499-574` ↔ `folder:404-479` |
| `flashcard` ↔ `mindmap` | 441 / 417 | **247** | 59 lignes — `flashcard:398-473` ↔ `mindmap:434-509` |
| `smart_note` ↔ `folder_document` | 359 / 386 | **238** | 59 lignes — `smart_note:297-372` ↔ `folder_document:337-412` |

Le bloc de 59 lignes est identique **à l'octet** dans les six : `streamAll` → `streamOne` →
`streamByIds` (découpage en paquets de 30 pour `whereIn`) → `_combine` (fusion manuelle de
`StreamSubscription`) → `asyncCount`. Les six réimplémentent aussi `softDelete` / `restore`
avec le même corps littéral (`ZSyncMeta.kIsDeleted`, `ZSyncMeta.kUpdatedAt`,
`SetOptions(merge: true)`) — p. ex. `z_backed_exam_repository.dart:583-604` ↔
`z_backed_folder_repository.dart:489-510`.

**C'est un assemblage manquant** : `zcrud_firestore` fournit déjà un magasin ; ce que ces six
fichiers écrivent est un `ZRemoteStore` recopié six fois.

### 4.3 D2 — la déclaration de champs

198 blocs `DynamicFormField(...)`, **6 241 lignes** (le décompte inclut les blocs imbriqués
sous `widget:` — c'est une borne haute).

| Fichier | Lignes de déclaration |
|---|---:|
| `.../administration/dialogs/ai_experts_dialogs.dart` | **1 751** |
| `.../flashcards/widgets/flashcard_edition_screen.dart` | 888 |
| `.../ai_routers/dialogs/ai_routers_dialogs.dart` | 840 |
| `.../flashcards/pages/multi_flashcard_editor_page.dart` | 694 |
| `lib/agents_screens.dart` (mort) | 353 |
| `.../folders/dialogs/folder_modal_dialogs.dart` | 279 |
| `.../administration/dialogs/auditeurs_iffd_modal_dialogs.dart` | 251 |
| `.../administration/dialogs/app_user_role_dialogs.dart` | 214 |
| `.../auth/pages/first_login_screen.dart` | 206 |
| `.../subjects/dialogs/subject_model_dialogs.dart` | 185 |

Répartition par type (premier `type:` du bloc) : `select` 42, défaut implicite (texte) 31,
`text` 29, **`widget` 23**, `boolean` 22, `inlineMarkdown` 20, `subItems` 9, `timestamp` 7,
`time` 3, `phoneNumber` 2, `float`/`color`/`integer`/`crudDataSelect` 2 chacun, `number` 1,
`dateTime` 1.

Champs les plus souvent redéclarés, par `name:` : `title` **13 fois**, puis `type`, `name`,
`displayName`, `description` 5 fois chacun, `instructions`, `filieresEtCycles`, `date`,
`content` 4 fois chacun.

### 4.4 D3 — l'écran d'état vide, six fois

Un bloc de ~143 lignes brutes (48 lignes significatives contiguës strictement identiques),
qui ne diffère que par **une icône et deux chaînes** :

| Fichier | Ligne | Texte |
|---|---:|---|
| `.../administration/pages/accademic_years_page.dart` | 154 | « Aucune Promotion » |
| `.../administration/pages/user_role_page.dart` | 104 | « Aucun Groupe d'Utilisateurs » |
| `.../subjects/pages/subjects_page.dart` | 130 | « Aucune Matière Disponible » |
| `.../administration/pages/ai_experts_page.dart` | 131 | « Aucun Agent IA Expert » |
| `.../ai_routers/pages/ai_routers_page.dart` | 141 | « Aucun Fournisseur IA » |
| `.../administration/pages/auditeurs_pages.dart` | 237 | « Aucun Auditeur Enregistré » |

Le bloc contient, à chaque fois : trois `Container` circulaires concentriques (180/160/120 dp),
un `ShaderMask` sur le dégradé **codé en dur** `Color(0xFF667eea)` → `Color(0xFF764ba2)`, un
titre `headlineSmall`, un sous-titre, et un `ElevatedButton.icon` dans un `Container` à
dégradé identique. Les mêmes deux hex reviennent aussi dans
`edition_screen.dart:246-247` (palette de champ « texte » en mode clair).

### 4.5 D4 — le post-traitement d'un dialogue d'édition, quatorze fois

```
if (result != null) {
  if (crud == Crud.create || crud == Crud.copy) { result["id"] = randomString(); }
  final x = fromMap<X>(result);
  switch (crud) {
    case Crud.create: await repo.create(x); break;
    case Crud.update: await repo.update(x); break;
    default:
  }
  return x;
} else { return null; }
```

Sites (`switch (crud)` immédiatement suivi de `case Crud.create` / `case Crud.update`) :

`mindmap_dialogs.dart:110`, `ai_routers_dialogs.dart:95`, `valuation_tool_model_dialogs.dart:104`,
`smartnotes_dialogs.dart:108`, `documents_dialogs.dart:112`, `flashcards_dialogs.dart:104`,
`flashcards_dialogs.dart:310`, `subject_model_dialogs.dart:72`, `exames_dialogs.dart:247`,
`app_user_role_dialogs.dart:273`, `annee_accademique_modal_dialogs.dart:76`,
`auditeurs_iffd_modal_dialogs.dart:360`, `ai_experts_dialogs.dart:915`,
`folder_modal_dialogs.dart:274`.

Deux d'entre eux (`smartnotes_dialogs.dart:99-106`, `mindmap_dialogs.dart:101-108`) portent en
plus le **même** `try { result.remove("subjectId") } … catch (_) {}` de 8 lignes, à l'octet.

### 4.6 D5/D6 — les dialogues d'actions

Neuf fonctions `show<X>ActionsDialog` à **la même signature** (`item`, `dialog`,
`fullscreenDialog`, `onEdit`, `onDelete`, `userId`, `aiRouter`, [`acl`/`permissions`]) qui ne
font qu'appeler `showPushedDialog(builder: X ActionsDialogWidget(...))` :
`valuation_tool_model_dialogs.dart:119`, `flashcards_dialogs.dart:119`, `mindmap_dialogs.dart:145`,
`documents_dialogs.dart:127`, `smartnotes_dialogs.dart:123`, `subject_model_dialogs.dart:290`,
`exames_dialogs.dart:262`, `folder_modal_dialogs.dart:435`, `app_user_role_dialogs.dart:288`.

Derrière, **8 fichiers `*_actions_dialog_widget.dart`** (3 554 lignes cumulées) réécrivent chacun
la paire de tuiles « Modifier » / « Supprimer » avec confirmation :

| Fichier | Lignes |
|---|---:|
| `.../documents/widgets/folder_documents_actions_dialog_widget.dart` | 1 804 |
| `.../valuation_tools/widgets/valuation_tool_model_actions_dialog_widget.dart` | 823 |
| `.../smartnotes/widgets/smartnote_actions_dialog_widget.dart` | 417 |
| `.../folders/dialogs/folder_actions_dialog_widget.dart` | 186 |
| `.../flashcards/widgets/flashcard_actions_dialog_widget.dart` | 126 |
| `.../administration/widgets/exam_actions_dialog_widget.dart` | 76 |
| `.../subjects/widgets/subject_actions_dialog_widget.dart` | 66 |
| `.../administration/widgets/app_user_role_actions_dialog_widget.dart` | 56 |

`Text("Modifier")` apparaît **12 fois** dans `lib/` (11 fichiers distincts) ; la chaîne
« Voulez-vous vraiment supprimer » **28 fois** dans 15 fichiers ; `buildConfirmDialog(` est
appelé **36 fois** dans 20 fichiers.

`valuation_tool_model_actions_dialog_widget.dart:662-790` réécrit **10 fois** le même bloc de
10 paramètres (`folderDetailsController`, `sectionController`, `subject`, `subjectToolPage`,
`folder`, `userId`, `isInFolderDetails`, `permissions`, `toolFlashcardCallback`, …) — une fois
par sous-type d'outil d'évaluation.

### 4.7 D11 — les dix-huit jumeaux legacy ↔ zcrud

Chaque entité éditable d'IFFD porte aujourd'hui **deux** formulaires vivants, choisis à l'exécution
par un flag (§5.3). Les deux sont maintenus.

| Entité | Legacy | l. | Jumeau zcrud | l. |
|---|---|---:|---|---:|
| Expert IA | `administration/dialogs/ai_experts_dialogs.dart` | 1 200 | `administration/zcrud/ai_expert_zcrud_edition.dart` (+ `ai_expert_documents_field.dart` 193) | 534 |
| Flashcard | `flashcards/dialogs/flashcards_dialogs.dart` + `widgets/flashcard_edition_screen.dart` | 1 549 | `flashcards/zcrud/flashcard_edition_zcrud.dart` | 579 |
| Éditeur multi-flashcards | `flashcards/pages/multi_flashcard_editor_page.dart` | 1 287 | `flashcards/zcrud/multi_flashcard_editor_zcrud.dart` | 243 |
| Auditeur + compte | `administration/pages/auditeurs_pages.dart` + `dialogs/auditeurs_iffd_modal_dialogs.dart` | 1 665 | `auditeur_iffd_zcrud_edition.dart` 221 + `auditeur_account_zcrud_edition.dart` | 162 |
| Routeur IA | `ai_routers/dialogs/ai_routers_dialogs.dart` | 716 | `ai_routers/zcrud/ai_router_zcrud_edition.dart` (+ `ai_router_sub_list_seams.dart` 319) | 704 |
| Dossier | `folders/dialogs/folder_modal_dialogs.dart` | 715 | `folders/dialogs/folder_zcrud_edition.dart` | 556 |
| URL de base IA | `flashcards/controllers/smart_learn_controller.dart` | 568 | `flashcards/controllers/ai_base_url_zcrud_edition.dart` | 284 |
| Groupe d'utilisateurs | `administration/dialogs/app_user_role_dialogs.dart` | 374 | `app_user_role_zcrud_edition.dart` | 198 |
| Note intelligente | `smartnotes/dialogs/smartnotes_dialogs.dart` | 339 | `smartnotes/dialogs/smartnote_zcrud_edition.dart` | 342 |
| Matière | `subjects/dialogs/subject_model_dialogs.dart` | 333 | `subjects/dialogs/subject_zcrud_edition.dart` | 728 |
| Document de dossier | `documents/dialogs/documents_dialogs.dart` | 323 | `documents/dialogs/folder_document_zcrud_edition.dart` | 212 |
| Année académique | `administration/dialogs/annee_accademique_modal_dialogs.dart` | 306 | `annee_accademique_zcrud_edition.dart` | 300 |
| Examen | `administration/dialogs/exames_dialogs.dart` | 282 | `administration/dialogs/exam_zcrud_edition.dart` | 513 |
| Carte mentale | `mindmap/dialogs/mindmap_dialogs.dart` | 179 | `mindmap/dialogs/mindmap_zcrud_edition.dart` | 308 |
| Outil d'évaluation | `valuation_tools/dialogs/valuation_tool_model_dialogs.dart` | 155 | `valuation_tool_model_zcrud_edition.dart` | 348 |
| Filtre d'examen blanc | `flashcards/widgets/test_exam_filter_screen.dart` | 134 | `test_exam_filter_zcrud_screen.dart` | 376 |
| Tag de flashcard | `flashcards/dialogs/flashcards_dialogs.dart` (partiel) | — | `flashcard_tag_zcrud_edition.dart` | 241 |
| Conversation / message chatbot | `ai_assistant/screens/chatbot_conversation_screen.dart` | 5 180 | `chatbot/zcrud/*` (4 fichiers) | 605 |

⚠️ **Ce n'est PAS de la duplication textuelle** : mesuré, `annee_accademique_modal_dialogs.dart`
et son jumeau ne partagent que **8 lignes significatives** sur 237 / 145, et leur plus long bloc
commun fait **2 lignes**. C'est de la duplication **d'intention** — deux implémentations du même
besoin, à maintenir en parallèle jusqu'au retrait du legacy. C'est la duplication la plus coûteuse
du dépôt.

### 4.8 D7/D8 — le portage zcrud a déjà fabriqué sa propre répétition

Huit écrans zcrud écrivent le même `Scaffold` / `AppBar` / `Semantics(button: true, label:
'Enregistrer')` / `IconButton(tooltip: 'Enregistrer')` :
`mindmap_zcrud_edition.dart:283`, `ai_router_zcrud_edition.dart:541`,
`valuation_tool_model_zcrud_edition.dart:321`, `smartnote_zcrud_edition.dart:315`,
`flashcard_edition_zcrud.dart:492`, `subject_zcrud_edition.dart:699`,
`exam_zcrud_edition.dart:488`, `folder_zcrud_edition.dart:527`.

Dix écrivent le même `dispose()` + `_onSave()` :
`mindmap_zcrud_edition.dart:259`, `ai_router_zcrud_edition.dart:496`,
`valuation_tool_model_zcrud_edition.dart:301`, `smartnote_zcrud_edition.dart:295`,
`folder_document_zcrud_edition.dart:167`, `ai_base_url_zcrud_edition.dart:239`,
`flashcard_tag_zcrud_edition.dart:196`, `test_exam_filter_zcrud_screen.dart:336`,
`subject_zcrud_edition.dart:675`, + 1.

**Signal d'assemblage manquant côté socle** : `zcrud_screen` est déclaré en dépendance mais
n'est importé que par 5 fichiers — l'écran d'édition complet (barre + bouton Enregistrer +
`Semantics` + cycle de vie du contrôleur) est refait à la main huit fois.

---

## 5. Ce qui est DÉJÀ branché sur zcrud

### 5.1 Dépendances

`pubspec.yaml` déclare **23 paquets `zcrud_*` en `dependencies`** (lignes 305-524) et **25 en
`dependency_overrides`** (lignes 572-725), tous en dépendance git sur
`https://github.com/zakarius-dev/zcrud.git`, épinglés par tag.

`dependencies` : `zcrud_core`, `zcrud_firestore`, `zcrud_riverpod`, `zcrud_select`,
`zcrud_flashcard`, `zcrud_menu`, `zcrud_mindmap`, `zcrud_markdown`, `zcrud_intl`,
`zcrud_document`, `zcrud_note`, `zcrud_study`, `zcrud_exam`, `zcrud_session`,
`zcrud_study_kernel`, `zcrud_ui_kit`, `zcrud_chat_kernel`, `zcrud_chat_syncfusion`,
`zcrud_chat`, `zcrud_chat_markdown`, `zcrud_chat_material`, `zcrud_navigation`, `zcrud_screen`.
Les overrides ajoutent `zcrud_annotations` et `zcrud_responsive`.

**Déclarés mais jamais importés** (grep négatif, `grep -rn "package:<p>/" lib` → 0 résultat
pour chacun) : `zcrud_riverpod`, `zcrud_annotations`, `zcrud_responsive`.
Idem pour les paquets non déclarés : `zcrud_list`, `zcrud_export`, `zcrud_geo`, `zcrud_get`,
`zcrud_provider` → **0 import**. `zcrud_list` est explicitement écarté par un commentaire du
pubspec (`:292`) : « exigent Syncfusion ^34, IFFD est en ^32 ».

### 5.2 Consommation réelle

**91 fichiers** de `lib/` importent au moins un `package:zcrud_*`. Occurrences par paquet :

| Paquet | Imports |
|---|---:|
| `zcrud_core` | 53 (+2 `zcrud_core/domain.dart`) |
| `zcrud_chat_kernel` | 19 |
| `zcrud_study` | 17 |
| `zcrud_chat` | 15 |
| `zcrud_flashcard` | 9 |
| `zcrud_study_kernel` | 6 |
| `zcrud_screen` | 5 |
| `zcrud_firestore` | 5 |
| `zcrud_mindmap` | 4 |
| `zcrud_ui_kit`, `zcrud_session`, `zcrud_navigation`, `zcrud_markdown`, `zcrud_chat_syncfusion`, `zcrud_chat_material` | 3 chacun |
| `zcrud_intl`, `zcrud_chat_markdown` | 2 chacun |
| `zcrud_select`, `zcrud_note`, `zcrud_menu`, `zcrud_exam`, `zcrud_document` | 1 chacun |

Symboles `zcrud_core` les plus consommés : `EditionFieldType` (21), `ZcrudTheme` (14),
`ZFieldSpec` (11), `ZFieldWidgetBuilder` (8), `ZFailure` (8), `ZValidatorSpec` (7),
`ZFieldChoice` (7), `ZSyncMeta` (6), `ZResult` (6), `ZTextConfig` (5), `ZcrudScope` (4),
`ZFormOnlyController` / `ZFormOnly` (4), `ZFieldWidgetContext` (4),
`ZSubListConfig` / `ZStepperEdition` / `ZStepperConfig` / `ZRelationSourceRegistry` /
`ZRelationSource` / `ZRelationConfig` / `ZFormController` / `ZEditionStep` (3 chacun).

**107 `ZFieldSpec(` déclarés** dans 18 fichiers — à comparer aux 198 `DynamicFormField(` du legacy :

| Fichier | `ZFieldSpec` |
|---|---:|
| `administration/zcrud/ai_expert_zcrud_edition.dart` | 28 |
| `flashcards/zcrud/flashcard_edition_zcrud.dart` | 12 |
| `ai_routers/zcrud/ai_router_zcrud_edition.dart` | 8 |
| `administration/dialogs/auditeur_iffd_zcrud_edition.dart` | 8 |
| `subjects/dialogs/subject_zcrud_edition.dart` | 6 |
| `folders/dialogs/folder_zcrud_edition.dart` | 6 |
| `flashcards/widgets/test_exam_filter_zcrud_screen.dart` | 6 |
| `administration/dialogs/annee_accademique_zcrud_edition.dart` | 5 |
| 4 fichiers à 4, 3 fichiers à 2, 2 fichiers à 1 | 22 |

### 5.3 Le registre de widgets et le `ZcrudScope`

Le registre est construit **une seule fois** par `buildIffdWidgetRegistry()`
(`lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart`, 445 lignes) et monté par
**22 `ZcrudScope(` dans 19 fichiers**.

Ce qui y est **enregistré** :

| Enregistrement | Site | Ce qu'il apporte |
|---|---|---|
| `registerZMarkdownFields(registry, codec: IffdRichTextCodec(), styleSet: iffdMarkdownStyleSet())` | `z_iffd_field_registry.dart:101` | les champs riches, avec le **codec Markdown maison** — le fichier documente qu'un codec par défaut décoderait « ~11 400 valeurs markdown du corpus » en ops vides |
| `registerZFlashcardEditors(...)` | `z_iffd_field_registry.dart:171` | les éditeurs de flashcard du socle |
| `registry.register('phoneNumber', ZPhoneFieldWidget.builder())` | `z_iffd_field_registry.dart:188` | le champ téléphone, **que le legacy ne rend pas** (§6) |
| `registry.register(kIffdBooleanKind, iffdBooleanBuilder())` | `z_iffd_field_registry.dart:199` | l'interrupteur au rendu IFFD |
| `ZRelationSourceRegistry.register(...)` | `folder_zcrud_edition.dart:466,469`, `subject_zcrud_edition.dart:293,295`, `flashcard_edition_zcrud.dart:462`, `exam_zcrud_edition.dart:284`, `app_user_role_zcrud_edition.dart:121` | 7 sources de relation (matière d'un dossier, créateur, expert IA par défaut, tags de flashcard, …) |
| `ZSubListSeamRegistry.register(...)` | `ai_router_sub_list_seams.dart:307,314` | 2 coutures de sous-liste |

Sont aussi injectés : `iffdFormTheme` (`z_iffd_form_theme.dart`, 221 l),
`iffdFieldTintResolver` / `iffdColorKeyResolver` / `iffdAdornmentIconResolver`
(`z_iffd_field_palette.dart`, 225 l), `ucFirstLegacy` (`z_text_transforms.dart`, 40 l),
`ZNationalPhoneValidator`, `ZSmartSelectPresenter`, `ZNumberDisplayFormatter`,
`ZDateDisplayFormatter` / `ZDateMode`.

### 5.4 La bascule (strangler fig)

`lib/src/presentation/shared/zcrud/z_qa_flags.dart` (467 lignes) tient un registre de **34
bascules** (`grep -c "    id: '"` = 34 ; `grep -c "^  ZQaFlag("` = 35, dont la déclaration du
constructeur à `:97`), chacune nommant un provider Riverpod `bool` et l'écran qu'elle fait
basculer, classée en trois familles (`rendu` / `comportement` / `donnees`).
⚠️ La dartdoc du registre annonce « Les vingt-cinq bascules » (`:135`) — elle est périmée de neuf.

Identifiants : `folderCard`, `folderCardDefault`, `folderDetail`, `subfolderNav`, `studyTools`,
`folderEdition`, `folderTags`, `contentHub`, `flashcardList`, `multiEditor`, `reviewSession`,
`srsQuality`, `flashcardEdition`, `flashcardTag`, `testExamFilter`, `aiRouterEdition`,
`aiBaseUrl`, `chatMessageTile`, `chatConversationList`, `chatConversationTile`, `notebook`,
`smartNote`, `subject`, `mindmapEdition`, `mindmapOutline`, `mindmapViewer`, `folderDocument`,
`exam`, `auditeurAccount`, `appUserRole`, `anneeAccademique`, `auditeurIffd`, `aiExpert`,
`valuationTool` — 34 au total.

**Huit sont actifs** dans `lib/main.dart:203-212` : `notebook`, `aiRouterEdition`, `exam`,
`valuationTool`, `subject`, `flashcardEdition`, `anneeAccademique`, `aiExpert`.
Les **26 autres** restent sur le chemin legacy.

La lecture d'un flag depuis une fonction top-level passe par `zcrudFlagValue(...)`
(`z_flag_gateway.dart`, 86 lignes) — **32 points de bascule** dans 27 fichiers.

---

## 6. Les widgets maison qui refont ce que zcrud fait probablement

| Widget maison | Chemin | Lignes | Équivalent zcrud plausible |
|---|---|---:|---|
| `DynamicEditionScreen` | `lib/data_crud/edition_screen.dart` | **4 038** | `DynamicEdition` / `ZFormController` / `ZWidgetRegistry` (`zcrud_core`) + `zcrud_screen` |
| `DynamicListScreen` | `lib/data_crud/dynamic_list_screen.dart` | **1 753** | `ZListRenderer` / `DynamicList` (`zcrud_list`) — **écarté pour cause de Syncfusion ^32 vs ^34** (`pubspec.yaml:292`) |
| `DynamicFormField` (76 paramètres nommés) | `lib/data_crud/edition_field.dart` | 444 | `ZFieldSpec` + `ZValidatorSpec` + `ZRelationConfig` + `ZSubListConfig` |
| `DynamicListField` (14 paramètres) | `lib/data_crud/dynamic_list_field.dart` | 37 | colonne dérivée de `ZFieldSpec` par le registre |
| `DynamicSubListScreen` | `lib/data_crud/sub_list_screen.dart` | 565 | `ZSubListConfig` / `ZSubListSeamRegistry` / `ZSubListItemView` |
| `RichTextEditorScreen` / `RichTextReaderScreen` / `MarkdownEditionField` / `QuillMarkdownEditorWrapper` | `rich_text_editor*` | 2 264 | `zcrud_markdown` (`registerZMarkdownFields`, `ZMarkdownCodec`, `ZMarkdownFieldChrome`) — **déjà branché en parallèle** |
| `DeltaToMarkdownHelper` + `MarkdownToDeltaHelper` | `rich_text_editor/` | 996 | `ZCodec` / `ZMarkdownCodec` — IFFD a déjà écrit son `IffdRichTextCodec` (193 l) par-dessus |
| Embeds LaTeX + tableaux | `lib/data_crud/embeds/` (10 fichiers) | 5 100 | embeds LaTeX/tables de `zcrud_markdown` |
| `CrudActionsButons` | `dynamic_list_screen.dart:73-311` | 239 | menu d'actions CRUD dérivé du `ZAcl` |
| `RessourceACL` (11 booléens) + `Crud` (22 valeurs) | `domain/security/` | 336 | `ZAcl` / `ZAllowAllAcl` (`zcrud_core`) |
| `DataState<T,E>` + `FirestoreDataState` | `utils/resources/` | 139 | `ZResult` / `ZFailure` (`zcrud_core`) |
| `CrudRepository<T>` + `FirebaseCrudRepositoryImpl<T>` | `domain/repositories/` + `data/repositories/` | 592 | `ZRepository<T>` / `ZRemoteStore` (`zcrud_firestore`) |
| `fromMap<T>` / `toMap<T>` (table de 46 fabriques) | `utils/functions/data_functions.dart:223-415` | 193 | `@ZcrudModel` + `ZcrudRegistry` (`zcrud_generator`) |
| `DynamicTabsState` (onglet + défilement persistés) | `categorysation_screens.dart` | 43 | onglets d'un écran CRUD assemblé |
| `permissionsField(...)` (matrice ACL comme champ) | `auditeurs_iffd_modal_dialogs.dart:34-133` | 100 | déjà réécrit côté zcrud : `z_iffd_acl_matrix_field.dart` (262 l) |
| `ToastService` | `notifications.dart` | 80 | retours de `zcrud_ui_kit` |
| `showPushedDialog` / `scaffoldDialog` / `buildConfirmDialog` / `buildDialogFormActions` | `forms_utils.dart:242-1039` | ~800 | assemblages d'écran de `zcrud_screen` / `zcrud_navigation` |
| État vide « cercle dégradé » (×6) | 6 pages | ~858 | état vide d'un écran CRUD assemblé |
| `*ActionsDialogWidget` (×8) | 8 fichiers | 3 554 | menu d'actions dérivé du `ZAcl` |

---

## 7. Défauts structurels relevés au passage (mesurés, pas supposés)

1. **Le formulaire entier se reconstruit à chaque frappe.**
   `DynamicEditionScreenState.build()` va de la ligne **205 à 4 037** (3 833 lignes) ;
   `_buildFormField` est une **fonction locale déclarée à l'intérieur de `build()`**,
   lignes **462 à 3 836** (3 375 lignes). Chaque champ, chaque décoration, chaque dégradé est
   reconstruit à chaque `setState` — il y en a **17** dans le fichier. C'est exactement le bug
   historique que zcrud existe pour corriger (objectif produit n°1).
   Même patron côté liste : `DynamicListScreenState.build()` va de **640 à 1 503** (864 lignes),
   avec `buildBody` (`:787`), `trashWidget` (`:1272`), `_buildTabBar` (`:1453`) et
   `_buildScaffold` (`:1476`) tous imbriqués dedans, et **20** `setState`.

2. **Sept types de champ déclarés ne sont rendus par rien.**
   `grep -c "case EditionFieldTypes.<t>:" lib/data_crud/edition_screen.dart` = **0** pour
   `icon`, `file`, `image`, `password`, `hidden`, `inlineHtml`, `phoneNumber`.
   La branche `default:` du `switch` (`edition_screen.dart:3832-3834`) rend
   `const EmptyContainer()` — **le champ disparaît en silence**.
   Conséquence mesurée : `EditionFieldTypes.phoneNumber` est déclaré à
   `lib/agents_screens.dart:312` et `.../administration/pages/auditeurs_pages.dart:504`,
   et `grep -n "phoneNumber" lib/data_crud/edition_screen.dart` → **0 résultat**. Le champ
   téléphone du formulaire auditeur **n'apparaît pas à l'écran**. C'est précisément ce que le
   registre zcrud répare (`z_iffd_field_registry.dart:181-188`).

3. **Le moteur de liste est mort.** `DynamicListScreen` n'est instancié que dans
   `lib/agents_screens.dart:164` et `lib/cotation/cotations_screen.dart:35`, deux fichiers dont
   aucune classe n'est référencée ailleurs (grep négatifs en §2.2).
   `grep -rn "DynamicSubListScreen" lib | grep -v '^lib/data_crud/'` → **0 résultat** : la
   sous-liste n'est atteinte que **par l'intérieur**, via `EditionFieldTypes.subItems`.
   `grep -rn "CrudActionsButons" lib | grep -v '^lib/data_crud/'` → **0 résultat**.
   ⇒ **1 880 lignes** de moteur de liste (`dynamic_list_screen.dart` 1 753 +
   `dynamic_data_table_builder.dart` 47 + `categorysation_screens.dart` 43 +
   `dynamic_list_field.dart` 37) sont **inertes en production**. Toutes les listes visibles
   d'IFFD sont écrites à la main (§4.4).

4. **Un bouton CRUD toujours vide.** `S2CrudButton` (`models.dart:123-212`) commence par
   `final formFiled = getResourceEditionFormFields<T>(context)` et rend `Container()` si c'est
   `null`. Or `getResourceEditionFormFields` (`forms_utils.dart:49-55`) retourne
   `factories[T]` d'une table **vide** (`:50-52`, seul contenu : une ligne commentée).
   Le widget rend donc **toujours** un `Container()`.

5. **Deux gestionnaires d'état coexistent** : `package:get` importé 67 fois (224 appels
   `Get.find/put/back/to/dialog/context`) et `package:flutter_riverpod` 120 fois
   (293 `ref.watch/ref.read`). Le moteur historique dépend des **deux** :
   `edition_screen.dart` importe `get`, `dynamic_list_screen.dart` importe
   `flutter_riverpod` **et** `get/instance_manager.dart`.

6. **Couleurs codées en dur dans le moteur.** `edition_screen.dart:217-285` porte deux tables
   de dégradés (clair / sombre), **16 hex littéraux**, indexées par `EditionFieldTypes`.
   Les mêmes `0xFF667eea` / `0xFF764ba2` sont recopiés dans les 6 états vides (§4.4).

7. **Le nom de collection Firestore est le nom de la classe Dart.**
   `FIREBASE_COLLECTION_NAMES` est `const {}` (`constants/databases.dart:3`), donc
   `getFirebaseCollectionName<T>()` rend toujours `T.toString()`. Renommer une classe Dart
   renomme la collection.

---

## 8. Ce que je n'ai pas pu établir

- **Aucune clé d'API ni secret n'est cité dans ce document.** Le dépôt porte un fichier `.env`
  à sa racine (`/home/zakarius/DEV/iffd/.env`, 268 octets) et une configuration Firebase
  (`lib/firebase_options.dart`) ; je ne les ai pas ouverts et n'en rapporte que l'emplacement.
- Le **nombre d'entités réellement présentes en base** (les « ~11 400 valeurs markdown du corpus »
  citées par `z_iffd_field_registry.dart:20` sont une mesure de l'hôte, pas la mienne) — non
  lisible depuis le code.
- Le **comportement à l'exécution** des 27 bascules éteintes : le code des jumeaux est sur
  disque, mais rien dans le source ne dit s'ils rendent la même chose que le legacy.
- Le décompte D2 (6 241 lignes de déclaration de champs) est une **borne haute** : un
  `DynamicFormField` imbriqué sous `widget:` est compté dans le bloc parent **et** pour
  lui-même. La répartition par type y est également approximative pour les blocs imbriqués
  (le premier `type:` rencontré l'emporte) — c'est ce qui explique l'écart entre les
  « 2 `crudDataSelect` » de cette table et les 21 occurrences comptées par grep direct.
