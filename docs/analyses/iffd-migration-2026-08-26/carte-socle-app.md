# Carte IFFD — domaine « Socle applicatif »
### Administration · authentification · réglages · accueil · workflow · navigation

Relevé du **2026-08-26** · `/home/zakarius/DEV/iffd` en **lecture seule** · socle zcrud **v3.21.0**
(`pubspec.yaml:308`, 23 paquets zcrud déclarés). Tout est remesuré ; le relevé du 2026-08-25 n'a servi de rien.

## 0. Périmètre mesuré

| Dossier | Fich. | Lignes | | Ajout hors périmètre (suivi des dépendances) | Lignes |
|---|---:|---:|---|---|---:|
| `lib/workflow/` | 38 | **17 417** | | `lib/data_crud/` — moteur legacy, 19 f. | **14 980** |
| `.../features/administration/` | 22 | **9 430** | | `config/router/app_router.dart` + `.gr.dart` | 270 + 2 601 |
| `lib/accounting/` | 26 | 2 783 | | `shared/zcrud/**` — adaptation IFFD↔zcrud, 14 f. | **3 234** |
| `.../features/auth/` | 6 | 2 113 | | `utils/functions/forms_utils.dart` | 1 193 |
| `src/features/home/` | 3 | 933 | | `core/widgets/popup_menu_helpers.dart` | 1 016 |
| `lib/cotation/` | 3 | 624 | | `domain/security/` (4 f.) | 902 |
| `src/features/auth/` | 5 | 580 | | `core/widgets/dynamic_searcheable_app_bar.dart` | 372 |
| `src/features/admin/` | 3 | 436 | | `presentation/app_scaffold.dart` | 186 |
| `src/features/settings/` | 3 | 368 | | `lib/main.dart` | 316 |
| **Total périmètre** | **109** | **34 684** | | **Total ajouts** | **25 070** |

## 1. 🔴 LE CODE RÉPÉTÉ

### 1.1 L'éditeur de rendez-vous écrit quatre fois — le plus gros bloc dupliqué du dépôt

`lib/workflow/screens/appointment_editor.dart` = **7 858 l, 21 classes, un fichier**.

Il contient **quatre éditeurs du même objet**, écrits séparément : `PopUpAppointmentEditorState`
`:1006–1663` (657 l) · `AppointmentEditorWebState` `:1708–5209` (**3 501 l**) ·
`AppointmentEditorState` mobile `:5261–6188` (927 l) · `SelectRecurrenceRuleDialog` `:6189–7858` (1 669 l).

Mesuré dans ce seul fichier : `_updateAppointmentProperties` déclaré **5 fois**, `_getResourceEditor`
**3 fois**, `_isAllDay` **3 fois**, `String _subject` **3 fois** ; les règles de récurrence écrites deux
fois sous deux noms (`_neverRule/_dailyRule/_weeklyRule/_monthlyRule/_yearlyRule` `:1844–1926` vs
`_dayRule/_weekRule/_monthRule/_yearRule`). `workflow/components/recurrence_picker.dart` (**1 721 l**)
en est la **cinquième** écriture.
⇒ **~9 580 lignes** pour un formulaire déclaratif (sujet, notes, lieu, plage, journée entière, couleur,
ressources, rappels, récurrence) rendu sur trois surfaces.

### 1.2 La page de liste « chercher / filtrer / rafraîchir / agir » — 16 réécritures

Occurrences / fichiers : `AppUserPermissions` 178/**65** · `ListenableBuilder(` 93/45 ·
`RessourceACL` 72/22 · `randomString()` (clé de re-souscription forcée) 70/**46** · `AutoRouterMixin` 36/29 ·
`StreamBuilder(` 28/19 · `DynamicSearcheableAppBar` 25/**16** · `unaccentedText(` (filtre texte) 22/**12** ·
`ExpandableFab` 19/4 · `Get.put(` 17/14 · `StatelessAccessControlledView` 11/10.

Patron intégral lisible en `administration/pages/ai_experts_page.dart:36–200` :
`Get.put(<X>ListController())` → `ValueNotifier valueKey = randomString()` → `SmartRefresher` →
`ListenableBuilder(valueKey)` → `StreamBuilder(repo.streamAll(request:))` →
`ListenableBuilder(searchController)` → `.where(unaccentedText(…).contains(query))` → `.sort(…)` →
carte à dégradé → `ExpandableFab`.
Repris au mot près dans `auditeurs_pages.dart:62`, `user_role_page.dart:43`,
`accademic_years_page.dart:38`, `exams_page.dart:52`, `subjects_page.dart:66`, `folders_page.dart`,
`public_folders_page.dart`, `folder_details_page.dart`, `accounting_system_screen.dart:23`.
**Les 5 pages de `administration/` = 4 268 lignes** ; `ai_experts_page.dart` déclare **1 classe pour
1 330 lignes** (un seul `build()`).

### 1.3 Quinze sous-classes vides de contrôleur de recherche

`shared/controllers/dynamic_list_search_controller.dart` (71 l) déclare **15 classes**, dont **13 à
corps strictement vide** (`:35,37,39,41,43,45,47,49,51,53,55,57,71`), plus une 16ᵉ ailleurs
(`folder_flashcards_list_page.dart:43`). Le type ne sert que d'**étiquette GetX**. Aucune n'ajoute de comportement.

### 1.4 Les dégradés de carte recopiés

`static const List<List<Color>> …Gradients = [` déclaré **4 fois** : `subjects_page.dart:49`,
`user_role_page.dart:31`, `auditeurs_pages.dart:50`, `accademic_years_page.dart:28`.

### 1.5 Le pont IFFD→zcrud recopié dans chaque dialogue d'admin

`Future<Map<String, dynamic>?> _presenterParLeSocle({…})` **réécrit dans 4 fichiers** :
`auditeurs_iffd_modal_dialogs.dart:387`, `annee_accademique_modal_dialogs.dart:260`,
`app_user_role_dialogs.dart:333`, `ai_experts_dialogs.dart:1010` (9 occurrences du symbole).
Corps commun mesuré (`annee_accademique_modal_dialogs.dart:260–306`, **47 l**) : contexte de
présentation → `ProviderScope.containerOf` → `DataCrudLocalizations.current.labels` → calcul de
`withPermissions` depuis `Crud` → chargement des ressources ACL →
`PermissionHelpers.generateCrudableObjects` → `toMap()` de départ → présentateur →
**fusion `{...depart, ...saisie}`**. ⇒ **~190 lignes**, quatre fois, dont la fusion qui *est* le contrat.

### 1.6 Confirmations, dialogues, présentation

Helpers de `forms_utils.dart`, appels / fichiers : **`showPushedDialog<T>` `:727` → 108 / 42** ·
**`buildConfirmDialog` `:480` → 38 / 20** · `buildDialog` `:391`, `scaffoldDialog` `:804`,
`buildDialogFormActions` `:242` → 8 / 5 · `buildAddButton` `:1032` → 5/3 ·
`showResourceBottomModalDialog` `:1064` → 2/2 · `buildDeleteConfirmation` `:363` → 2/2 · `showErpDialog` `:788` → 1/1.

`showPushedDialog` est **déjà porté** sur `ZAdaptivePresenter` (`zcrud_navigation`) : le corps lit
`ZSheetFrameSpec` / `ZSheetFrameMode.unlessChrome` (`:781–784`) et son dartdoc `:676–726` documente le
retrait de **trois compensations** (largeur forcée, `Card.outlined`, heuristique
`endsWith("EditionScreen")`). C'est le modèle à répliquer sur les six autres helpers.
⚠️ `Get.context` reste le repli de contexte (`:747`) et `ZPresentationPolicy` **n'est pas branchée** —
arbitrage écrit `:683–690` (« toucherait d'un coup les ~52 sites qui ouvrent une feuille »).

### 1.7 États chargement / erreur / vide

Occurrences / fichiers sur le périmètre : `setState(` **185**/15 · `EdgeInsets.only` **103**/9
(⚠️ non directionnel, AD-13) · `ListTile(` 76/23 · `onChanged:` 71/10 · `IconButton(` 58/21 ·
`ElevatedButton` 53/8 · `TextField(` 33/7 · `Scaffold(` 29/20 · `showDialog` 26/6 · `Divider(` 21/6 ·
`AppBar(` 20/13 · `try {` 17/10 · `catch (` 15/8 · `CircularProgressIndicator` 11/8 · `AlertDialog` 9/6.

Deux absences mesurées : **`.when(` = 0** et **`ScaffoldMessenger` = 0** sur les 9 dossiers.
L'état asynchrone n'est jamais projeté en trois branches — il est reconstruit par
`StreamBuilder` + `snapshot.data ?? <T>[]`, qui **confond erreur, chargement et vide**.

### 1.8 L'écran d'authentification recopié

`_buildLogo()` de `auth/pages/login_page.dart:403–435` et de
`auth/pages/accademic_year_selection_page.dart:227–259` sont **identiques à l'octet** (`diff` vide,
**33 l**). Chacun des 4 écrans d'auth réimplémente son fond animé
(`AnimationController`/`FadeTransition`/`LinearGradient`/`Tween`) : 10 occ. dans `login_page`,
9 dans `accademic_year_selection_page`, 6 dans `first_login_screen`, 5 dans `force_update_screen`.

### 1.9 Le double jeu de déclarations de champs

Chaque écran porté existe **deux fois** : la déclaration legacy (moteur `data_crud`) et son jumeau
zcrud. Sur le périmètre, **10 jumeaux = 2 742 l** vivent **à côté** de leur original, pas à sa place (§3.1).
Repo entier : `DynamicEdition` **128 occ. / 55 f.**, `EditionFieldType` **525 occ. / 63 f.**

## 2. Ce que le domaine sait faire
**Administration** — gérer les *assistants IA experts* (fiche, pseudo, instructions **générées par le
modèle**, documents **indexés**) ; gérer les *auditeurs IFFD* (identité, filière × cycle, genre, pays,
promotion) et **créer leur compte** (e-mail + mot de passe) ; gérer les *rôles applicatifs* et leurs
**matrices d'autorisations** ressource par ressource ; gérer les *années académiques / promotions*
(dont **douze matrices d'un coup**) et le rattachement des auditeurs ; gérer les *examens* (création,
actions, regroupement) ; filtrer chaque liste par recherche insensible aux accents ; chaque geste
précédé d'un contrôle de droit.

**Authentification** — se connecter par e-mail/mot de passe ou par Google ; demander la
réinitialisation d'un mot de passe et voir sa confirmation ; à la **première connexion**, être forcé
de changer son mot de passe et de compléter son profil ; **choisir son année académique** avant
d'entrer ; être **bloqué par un écran de mise à jour obligatoire**.

**Réglages / accueil / admin** — ces trois dossiers ne portent **aucun écran** : **14 fichiers dont 5
générés**, `*.g.dart` = **1 892 des 2 317 lignes (81,7 %)**. Ce sont des *providers* Riverpod
(préférences, dossiers d'accueil, droits d'admin) consommés ailleurs.

**Workflow** — tenir un *agenda* ; créer/éditer un **rendez-vous récurrent** complet ; tenir des
**tâches** avec échéance et rappel, et des **notes** ; le tout en lecture seule quand le droit manque
(`workflow/components/is_read_only.dart`, 92 l).

**Comptabilité / cotation** — consulter un *plan comptable* (par classe, par groupe), sélectionner un
compte, décrire journaux, écritures, taxes ; une page de **cotation générique** avec liste glisser-déposer.

**Navigation** — 26 routes (`app_router.dart`), 30 fichiers `@RoutePage`, `app_router.gr.dart` = 2 601 l
générées. ⚠️ **Aucun garde de route** (`AutoRouteGuard` : 0 occ.). L'autorisation est portée par les
widgets (`StatelessAccessControlledView`, 11 sites) et par `AppUserPermissions` (178 lectures / 65 f.).

## 3. Ce qui est DÉJÀ branché sur zcrud

**23 paquets déclarés**, tous `ref: v3.21.0`. Imports réels, dépôt entier :
`zcrud_core` **67** · `zcrud_chat_kernel` 19 · `zcrud_study` 17 · `zcrud_screen` 16 · `zcrud_chat` 15 ·
`zcrud_markdown` 11 · `zcrud_flashcard` 11 · `zcrud_study_kernel` 8 · `zcrud_navigation` 6 ·
`zcrud_mindmap` 6 · `zcrud_firestore` 5 · `zcrud_ui_kit`/`zcrud_session`/`zcrud_note`/`zcrud_exam`/
`zcrud_document`/`zcrud_chat_syncfusion`/`zcrud_chat_material` 3 chacun ·
`zcrud_select`/`zcrud_intl`/`zcrud_chat_markdown` 2 chacun · **`zcrud_menu` 1**.

⚠️ **Dans ce périmètre, l'empreinte zcrud est de 11 fichiers** : 9 dans `administration/`, 1 dans
`auth/`, 2 dans `workflow/screens/zcrud/` — et **0** dans `features/admin`, `features/auth`,
`features/settings`, `features/home`, `accounting/`, `cotation/`.

### 3.1 Jumeaux portés du périmètre et leur drapeau

Registre : `shared/zcrud/z_qa_flags.dart` (985 l) — **52 bascules** (`grep -c "^    id: '"` = 52).
Celles de ce domaine :

| `id` | Jumeau | L. | Écrit des données ? |
|---|---|---:|---|
| `aiExpert` | `administration/zcrud/ai_expert_zcrud_edition.dart` | 534 | **oui** (`:734`) — instructions au modèle |
| `exam` | `administration/dialogs/exam_zcrud_edition.dart` | 513 | non (`:673`) |
| `anneeAccademique` | `administration/dialogs/annee_accademique_zcrud_edition.dart` | 300 | **oui** (`:710`) — 12 matrices |
| `firstLogin` | `auth/pages/first_login_zcrud_edition.dart` | 257 | non (`:789`) |
| `auditeursFilter` | `administration/dialogs/auditeurs_filter_zcrud_edition.dart` | 226 | non (`:744`) |
| `auditeurIffd` | `administration/dialogs/auditeur_iffd_zcrud_edition.dart` | 221 | **oui** (`:722`) — bimodal |
| `workflowNotes` | `workflow/screens/zcrud/workflow_notes_zcrud_edition.dart` | 214 | **oui** (`:885`) |
| `appUserRole` | `administration/dialogs/app_user_role_zcrud_edition.dart` | 198 | **oui** (`:699`) — écrit des droits |
| `auditeurAccount` | `administration/dialogs/auditeur_account_zcrud_edition.dart` | 162 | **oui** (`:687`) — **crée des comptes** |
| `taskList` | `workflow/screens/zcrud/task_list_zcrud_edition.dart` | 117 | non (`:852`) |
| `agentsFilter` | `lib/agents_filter_zcrud_edition.dart` | 246 | non (`:763`) |

Aucun n'est actif par défaut : il faut injecter `zcrudQaOverrides({…})` dans le `ProviderScope` de
`main.dart` (mode d'emploi `z_qa_flags.dart:14–28`).

### 3.2 Couche d'adaptation déjà écrite — `shared/zcrud/`, **14 fichiers, 3 234 l**

`z_qa_flags` 985 · `z_iffd_field_registry` 461 (`IffdZcrudScope`) · `z_iffd_form_theme` 281 ·
**`z_iffd_acl_matrix_field` 262** · `z_iffd_field_palette` 225 · `z_iffd_rich_text_codec` 193 (`ZCodec`) ·
`z_questions_counts_field` 169 · `z_iffd_markdown_style` 153 · `z_iffd_relation_source` 140 ·
`z_iffd_boolean_field` 140 · `z_flag_gateway` 86 · `z_iffd_stepper` 60 · `z_text_transforms` 40 ·
`z_iffd_value_adapters` 39.

### 3.3 Ce qui n'est PAS branché et devrait l'être

- **`zcrud_navigation`** : 6 imports, dont 2 dans le périmètre (`annee_accademique_zcrud_edition.dart:48`,
  `ai_expert_zcrud_edition.dart:66`). `ZPresentationPolicy` disponible, **non branchée** par arbitrage.
- **`zcrud_menu`** : **1 import** dans tout le dépôt (`folder_actions_menu_zcrud.dart:36`, `ZMenuEntryTile`)
  face à **5 constructeurs de menus** dans `popup_menu_helpers.dart` (1 016 l).
- **`zcrud_list`** : **aucune entrée** dans `pubspec.yaml` (`grep -n "^  zcrud_list:"` → rien).
  Motif écrit `:292` : « exigent Syncfusion ^34, IFFD est en ^32 ». Corollaire mesuré :
  `DataTable`/`DataColumn`/`DataRow`/`SfDataGrid`/`PaginatedDataTable` → **0 occ.** dans le périmètre.
- **`workflow` entier** : 2 fichiers portés sur 38 = **331 l sur 17 417 (1,9 %)**.
- **`accounting/` et `cotation/`** : **0 ligne** zcrud.

## 4. Widgets maison qui refont ce que le socle fait

| Maison | Chemin | L. | Sites | Équivalent socle |
|---|---|---:|---:|---|
| Moteur legacy `data_crud` | `lib/data_crud/**` (19 f.) — `edition_screen` **4 073**, `dynamic_list_screen` **1 753**, `rich_text_editor_screen` 773, `sub_list_screen` 555, embeds 3 191 | **14 980** | `DynamicEdition` 128/55 f. | `zcrud_core` + `zcrud_screen` + `zcrud_list` + `zcrud_markdown` |
| `recurrence_picker.dart` | `workflow/components/` | **1 721** | 1 | — (aucun équivalent connu) |
| `popup_menu_helpers.dart` | `core/widgets/` `:186,269,492,612,667` | **1 016** | 5 menus | `zcrud_menu` |
| `forms_utils.dart` (7 helpers de dialogue) | `utils/functions/` | 1 193 | **164 appels** | `zcrud_navigation` (1 des 7 porté) |
| `DynamicSearcheableAppBar` | `core/widgets/` | 372 | **25 / 16 f.** | en-tête de liste + recherche |
| l10n maison `workflow/l10n/` + `accounting/l10n/` | 22 fichiers | **1 163** | — | l10n `zcrud_core` |
| `domain/security/` (ACL) | 4 fichiers | 902 | 178 lectures | *(métier — §7)* |
| `workflow/components/` (rappels, échéance, lieu, couleur, journée entière) | 5 fichiers | **807** | — | champs déclaratifs `ZFieldSpec` |
| `AppScaffold` | `presentation/app_scaffold.dart` | 186 | 29 `Scaffold(` | châssis d'écran |
| `loading_indicators.dart` | `core/widgets/` | 100 | — | états chargement/vide |
| `data_controller.dart` + `dynamic_list_search_controller.dart` | `shared/controllers/` | 169 | 17 `Get.put` | état de liste du socle |

## 5. Écrans et dialogues

**Administration** (22 f., 9 430 l) : `pages/ai_experts_page` **1 330** (liste assistants ; 1 classe) ·
`pages/auditeurs_pages` **1 281** (liste auditeurs ; 4 `showPushedDialog`) · `dialogs/ai_experts_dialogs`
**1 200** (`AiExpertdEditionScreen:42–868` = 827 l ; `runWithGoalAndInstructions:869` ;
`_BoutonRegenererInstructions:1088` ; `_BoutonIndexerDocuments:1157`) · `pages/accademic_years_page` 692
(FAB `:654`) · `pages/user_role_page` 632 (`AppUserRoleItemWidget:343`) · `zcrud/ai_expert_zcrud_edition`
534 · `dialogs/exam_zcrud_edition` 513 · `dialogs/auditeurs_iffd_modal_dialogs` 438
(`AuditeurIffdEditionScreen:137`, `showAuditeurEditionDialog:316`) · `dialogs/app_user_role_dialogs` 374
(`AppUserRoleEditionScreen:34`) · `pages/exams_page` 333 (`ExamsGrouper:28`, `ExamsListItemBuilder:255`) ·
`dialogs/annee_accademique_modal_dialogs` 306 (`PromotionEditionScreen:91`, auditeurs `:231`) ·
`dialogs/annee_accademique_zcrud_edition` 300 · `dialogs/exames_dialogs` 282 ·
`dialogs/auditeurs_filter_zcrud_edition` 226 · `dialogs/auditeur_iffd_zcrud_edition` 221 ·
`dialogs/app_user_role_zcrud_edition` 198 · `zcrud/ai_expert_documents_field` 193 ·
`dialogs/auditeur_account_zcrud_edition` 162 · `widgets/exam_actions_dialog_widget` 76 ·
**`pages/app_administration_page` 70 — le hub d'administration** · `widgets/app_user_role_actions_dialog_widget`
56 · `administration.dart` 13.

**Authentification** (6 f., 2 113 l) : `login_page` **727** (e-mail `:69`, Google `:95`, mot de passe
oublié `:159`, dialogue de succès `:187`, `_buildLogo:403`, `_buildTextField:581`, `_buildPrimaryButton:642`,
`_buildGoogleButton:692`) · `accademic_year_selection_page` 452 (`_onYearSelected:63`, `_buildLogo:227`
**identique**, `_buildEmptyState:420`) · `first_login_screen` 451 (`_changerMotDePasse:104`, 4
`DynamicEdition`) · `first_login_zcrud_edition` 257 (**jumeau**) · `force_update_screen` 223
(`_buildVersionInfo:198`) · `auth.dart` 3.

**Workflow** (38 f., 17 417 l) : `screens/appointment_editor` **7 858** (§1.1) ·
`components/recurrence_picker` **1 721** · `screens/event_editon_screen` 1 308 · `screens/tasks_screen`
816 · `screens/agenda_screen` 737 · `screens/task_edition_screen` 589 · modèles `task` 584 / `event` 500 /
`appointment` 403 / `time_slice` 104 / `note` 81 · l10n (`l10n/` 616 + `l10n.dart` 239) 855 · `utils.dart` 241 ·
`components/` (7 autres f.) **1 026** · **jumeaux portés** `workflow_notes_zcrud_edition` 214 +
`task_list_zcrud_edition` 117 · assemblage (`workspace` 112, `source` 79, `edition_forms` 33,
`workspace_page` 38, `time_management_page` 1).

**Comptabilité / cotation** (29 f., 3 407 l) : modèles `accounting_plan` 359, `taxe` 325, `journal` 226,
`journal_entry` 199, `journal_entry_item` 138, `account` 87, `config` 64, `journal_type` 56,
`account_selection` 18 · écrans `select_accounting_account_screen` 220, `accounting_system_screen` 182,
`accounts_by_group_screen` 123, `accounts_by_classe_screen` 122 · `accounts_list_item_builder` 81 ·
l10n maison 547 · `cotation/darg_and_drop_list_footer` 253 *(orthographe du dépôt)*,
`page_de_cotation_generique` 241, `cotation_edition_screen` 130.

## 6. Modèles et persistance

**Entités.** Le domaine ne définit d'entités que dans `workflow/models/` (5 classes, 1 672 l) et
`accounting/model/` (9 classes, 1 472 l). Tout le reste — `AiExpert`, `AuditeurIffd`, `AppUserRole`,
`AnneeAccademique`, `ExamModel`, `FiliereEtCycleIFFD`, `AppUser` — vit hors périmètre
(`src/domain/models/iffd_models.dart`, `app_user.dart`, `lib/ai_assistant/models/ai_expert.dart`).
La sérialisation passe par `toMap()` : c'est ce que `_presenterParLeSocle` consomme et refusionne
(`{...depart, ...saisie}`). **La `Map<String,dynamic>` est le contrat d'échange legacy↔socle** — donc
le point exact où une régression de données se produirait lors d'une bascule.

**Accès aux données et erreurs.** Aucun accès direct : `FirebaseFirestore.instance` → **0 occ.**,
`.collection(` → **0 occ.** sur le périmètre. Tout passe par des *repositories* exposés en providers
Riverpod (`aiExpertRepositoryProvider`, `anneeAccademiqueRepositoryProvider`, `aiRouterRepositoryProvider`,
`crudableObjectsProvider`…) via `ref.read(…).streamAll(request: DataRequest<T>)` — `DataRequest<T>`
(`domain/models/requests/data_request.dart`) étant la requête neutre de l'hôte. Les providers du
périmètre sont **générés à 81,7 %** (1 892 l générées / 2 317). Côté erreurs : **aucun type de
résultat**, 17 `try {` / 15 `catch (` sur 34 684 lignes, et le seul traitement explicite est
`FirebaseAuthException` (`login_page.dart:84,178` ; `first_login_screen.dart:129`).

## 7. Ce qui est PARTICULIER à IFFD

1. **La matrice d'autorisations par ressource.** `RessourceACL` (163) + `Crud` (173) +
   `AppUserPermissions` (256) + `AccessControlledView` (310) + `PermissionHelpers.generateCrudableObjects`.
   Un rôle ou une promotion porte **une matrice CRUD par objet délégable**, éditée en bloc (**douze
   d'un coup** pour une année, `z_qa_flags.dart:704`). Déjà exprimé côté socle comme champ maison :
   `z_iffd_acl_matrix_field.dart` (262 l). C'est le cœur métier — rien de généralisable tel quel.
2. **Le formulaire bimodal auditeur.** `auditeurIffd` écrit *soit* l'identité pédagogique *soit* le
   compte (`z_qa_flags.dart:715–723`) ; `auditeurAccount` **provisionne un compte Firebase** depuis un
   écran d'administration (`:678–688`). Un formulaire qui crée une identité n'est pas un CRUD ordinaire.
3. **Le parcours d'entrée en quatre barrières, sans garde de route.** `force_update_screen` (version) →
   `login_page` → `first_login_screen` (mot de passe forcé + profil) → `accademic_year_selection_page`
   (année obligatoire). La séquence est portée par les écrans eux-mêmes — `AutoRouteGuard` : 0 occurrence.
4. **L'année académique comme portée globale**, et `FiliereEtCycleIFFD` (filière × cycle) comme axe de
   découpe jusque dans les formulaires d'auditeur (`auditeur_iffd_zcrud_edition.dart:45`).
5. **L'assistant IA « expert » qui produit son propre contenu** : `ai_experts_dialogs.dart:869`
   (`runWithGoalAndInstructions`), `:1088` (régénérer les instructions), `:1157` (indexer les documents).
6. **Le double moteur assumé.** `data_crud` (14 980 l) et zcrud coexistent, réconciliés par 52 bascules
   runtime et 14 fichiers d'adaptation. **C'est un état de migration, pas une architecture** — mais tout
   portage doit passer par ce registre, jamais par une substitution directe.
7. **L'éditeur de rendez-vous Syncfusion.** Les 7 858 l de `appointment_editor.dart` sont structurées
   comme l'exemple officiel Syncfusion Calendar (`CalendarResource`, `CalendarColorPicker`,
   `CalendarTimeZonePicker`, trois surfaces). Ce n'est **pas** du métier IFFD : c'est du code d'exemple
   adopté puis étendu — donc le meilleur candidat à une reprise par le socle, et le plus gros gain.
8. **Deux jeux de traductions maison** (22 fichiers, 1 163 l), 8 langues déclarées dont **7 vides**
   (fichiers de 4 lignes), indépendants du l10n de l'application.

## Annexe — greps négatifs montrés

| Affirmation d'absence | Commande | Résultat |
|---|---|---|
| Aucun garde de route | `grep -rn "AutoRouteGuard" lib` | 0 ligne |
| Aucun accès Firestore direct dans le périmètre | `grep -rF "FirebaseFirestore.instance" <9 dossiers>` | `occ=0 fichiers=0` |
| Idem `.collection(` | `grep -rF ".collection(" <9 dossiers>` | `occ=0 fichiers=0` |
| Aucun `AsyncValue.when` | `grep -rF ".when(" <9 dossiers>` | `occ=0 fichiers=0` |
| Aucun `ScaffoldMessenger` | `grep -rF "ScaffoldMessenger" <9 dossiers>` | `occ=0 fichiers=0` |
| Aucune grille de données | `grep -rF` sur `DataTable`, `DataColumn`, `DataRow`, `SfDataGrid`, `PaginatedDataTable` | `occ=0` chacun |
| Aucun zcrud dans admin/auth-providers/settings/home/accounting/cotation | `grep -rn "package:zcrud" <6 dossiers>` | 0 ligne |
| `zcrud_list` non déclaré | `grep -n "^  zcrud_list:" pubspec.yaml` | 0 ligne (seul le commentaire `:292` en parle) |
