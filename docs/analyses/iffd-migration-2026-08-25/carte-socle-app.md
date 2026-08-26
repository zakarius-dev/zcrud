# Carte du domaine « Socle applicatif » d'IFFD
## Administration · Authentification · Réglages · Accueil · Navigation

> **Dépôt cartographié** : `/home/zakarius/DEV/iffd` — **lecture seule**, aucune écriture.
> **Date du relevé** : 2026-08-25. **Méthode** : lecture de fichiers, `grep`, `find`, `wc`.
> Aucun test lancé. Toute affirmation d'ABSENCE porte son grep négatif, montré en §9.

---

## 1. Périmètre mesuré

### 1.1 Chemins de départ (donnés par l'orchestrateur)

| Chemin | Fichiers `.dart` | Lignes |
|---|---:|---:|
| `lib/src/presentation/features/administration/` | 21 | 9 150 |
| `lib/workflow/` | 36 | 16 821 |
| `lib/src/presentation/features/auth/` | 5 | 1 741 |
| `lib/src/presentation/features/home/` | 4 | 941 |
| `lib/src/features/home/` (providers) | 3 | 933 |
| `lib/src/features/auth/` (providers) | 5 | 580 |
| `lib/src/features/admin/` (providers) | 3 | 436 |
| `lib/src/features/settings/` (providers) | 3 | 368 |
| **Sous-total noyau** | **80** | **30 970** |

### 1.2 Ce que j'ai INCLUS au-delà, en suivant les dépendances réelles

Les huit chemins de départ ne compilent pas seuls : la navigation, le thème, la garde
d'accès, le pont zcrud et les modèles vivent ailleurs. Inclus :

| Chemin ajouté | Pourquoi | Fichiers | Lignes |
|---|---|---:|---:|
| `lib/src/config/router/` | `AppRouter` + routes générées : la navigation EST le domaine | 3 | 2 899 |
| `lib/src/presentation/core/` | tiroir latéral, `AppBar` recherchable, menus contextuels | 20 | 2 885 |
| `lib/src/presentation/shared/` | **pont zcrud** (registre, thème, palette, matrice ACL, flags QA) — partagé avec les autres domaines | 16 | 2 642 |
| `lib/src/presentation/features/ai_routers/` | enfant direct de la route `/administration` | 5 | 2 544 |
| `lib/src/domain/security/` | `AppUserPermissions`, `RessourceACL`, `Crud`, gardes d'écran | 8 | 1 582 |
| `lib/src/core/` | providers d'app, erreurs, constantes Firestore, toasts | 17 | 1 443 |
| `lib/src/config/themes/` | `AppTheme`, `IFFDTokens`, typographie | 4 | 621 |
| modèles + dépôts du domaine (voir §4) | `AppUser`/`AuditeurIffd`, `AnneeAccademique`, `ExamModel`, `AppUserRole`, impl Firestore | 15 | 2 564 |
| `lib/main.dart`, `lib/app.settings.dart`, `lib/src/config/env_config.dart`, `lib/src/presentation/app_scaffold.dart` | amorçage, réglages persistés, secrets, coquille d'écran | 4 | 661 |
| **Sous-total étendu** | | **92** | **17 841** |

### 1.3 Total

| | Fichiers | Lignes |
|---|---:|---:|
| **Domaine « socle applicatif »** | **172** | **48 811** |

### 1.4 Ce que j'ai VOLONTAIREMENT laissé dehors (mais qui pèse sur la migration)

| Chemin | Lignes | Raison |
|---|---:|---|
| `lib/data_crud/` | **16 889** | Moteur CRUD déclaratif legacy (`DynamicEditionScreen`, `DynamicListScreen`, éditeur riche Quill, embeds LaTeX/tables). **Commun à TOUS les domaines** — mais 6 écrans du mien en dépendent directement. C'est l'ancêtre de zcrud. |
| `lib/src/presentation/features/subjects/` | 3 706 | « Matières » : enfant de la route `/administration`, mais domaine métier « étude ». Signalé, non compté. |
| `lib/src/presentation/features/tasks/` | 1 218 | `DailyTasksPage` (1 101 l) est montée par `HomePage` et `DashboardPage`. Frontière poreuse. |
| `lib/agents_screens.dart` | 535 | Écran d'administration **MORT** (cf. §9, grep 5). |
| `lib/cotation/` | 772 | Module **orphelin**, aucun référencement (cf. §9, grep 6). |

---

## 2. Ce que le domaine SAIT FAIRE (capacités visibles par l'utilisateur)

### 2.1 Entrer dans l'application

1. **Se connecter par e-mail et mot de passe** (`login_page.dart:68-90`), avec messages
   d'erreur traduits par code Firebase (`:133-151`).
2. **Se connecter avec un compte Google** (`login_page.dart:92-125`).
3. **Demander la réinitialisation de son mot de passe** — validation de l'adresse par
   expression régulière, puis dialogue de confirmation détaillant les 4 étapes à suivre
   (`login_page.dart:158-284`).
4. **Être obligé de changer son mot de passe à la première connexion**, avec possibilité
   de reporter (`first_login_screen.dart`, champ `ignorePasswordChangeUntil` de
   `AuditeurIffd`).
5. **Être bloqué par une version obsolète** : l'app compare sa version à
   `APP_SETTINGS/required_version` en base et affiche un écran de mise à jour forcée avec
   lien de téléchargement (`access_controlled_view.dart:72-90`, `force_update_screen.dart`).
6. **Voir une présentation en 4 volets à la première ouverture** (`presentation_page.dart`).
7. **Choisir son année académique** avant d'accéder à l'app — bloquant tant qu'aucune
   n'est choisie (`access_controlled_view.dart:117-121`, `accademic_year_selection_page.dart`).
8. **Se déconnecter** depuis le pied du tiroir, avec confirmation
   (`side_menu_drawer.dart:383-396`).

> Ces 5 gardes s'enchaînent dans un ordre **strict et unique** :
> mise à jour forcée → présentation → connexion → mot de passe → année académique
> (`access_controlled_view.dart:66-124`).

### 2.2 Naviguer

9. **Parcourir un tiroir latéral construit AUTOMATIQUEMENT depuis les routes** : chaque
   `AutoRoute` porte un `SideMenuItem` en métadonnée (titre, icône, ressources requises),
   et le tiroir s'auto-génère par récursion (`side_menu_drawer.dart:70-100`).
10. **Ne voir que les entrées auxquelles on a droit** : chaque entrée déclare
    `checkAccess: [Type…]`, filtré contre les permissions (`app_router.dart:32-46`).
11. **Basculer entre tiroir permanent (≥ 800 dp) et tiroir escamotable** (`app_scaffold.dart:164-186`).
12. **Changer d'année académique depuis le tiroir**, avec un sélecteur à recherche
    (`side_menu_drawer.dart:205-297`).
13. **Voir sa version d'application** et, si administrateur, **changer l'URL du service d'IA**
    (`side_menu_drawer.dart:346-374`).
14. **Quitter l'app par double-appui sur retour**, avec toast d'avertissement
    (`app_scaffold.dart:148-161`).

### 2.3 Administrer

15. **Gérer les promotions IFFD** (années académiques) : créer, lire, modifier. Nom,
    interne/externe, date de rentrée et de fin **qui se bornent mutuellement**, et
    **douze matrices d'autorisations** (6 filières × 2 cycles)
    (`accademic_years_page.dart`, `annee_accademique_modal_dialogs.dart`).
16. **Affecter des auditeurs à une promotion**, par filière et par cycle
    (`annee_accademique_modal_dialogs.dart:231`).
17. **Gérer les groupes d'utilisateurs** (rôles) : nom, membres, matrice d'autorisations
    (`user_role_page.dart`, `app_user_role_dialogs.dart`).
18. **Gérer les auditeurs IFFD** : identité (nom, prénom, genre, pays d'origine,
    administration d'origine, téléphone), filières et cycles, autorisations individuelles
    (`auditeurs_pages.dart`, `auditeurs_iffd_modal_dialogs.dart`).
19. **Créer le COMPTE d'un auditeur** (e-mail + mot de passe transmis à l'authentification)
    — parcours distinct de l'édition d'identité (`auditeurs_pages.dart:452-481`).
20. **Filtrer les auditeurs** par pays d'origine, promotion et genre, via un formulaire de
    filtre ouvert en dialogue (`auditeurs_pages.dart:84-152`).
21. **Rechercher un auditeur / un groupe / un expert IA** par texte désaccentué
    (`auditeurs_pages.dart:212-217`, `user_role_page.dart:88-96`).
22. **Naviguer les auditeurs et les experts IA par onglets de filière×cycle**, avec une ACL
    par onglet et un bouton de création qui n'apparaît que si le droit existe
    (`auditeurs_pages.dart:1112-1220`).
23. **Gérer les assistants IA experts** : objectif, instructions, base de connaissance,
    questions/réponses types, bibliothèque de documents, outils, six documents légaux,
    portée par filière (`ai_experts_page.dart`, `ai_experts_dialogs.dart`).
24. **Régénérer les instructions d'un expert par l'IA** et **indexer ses documents** —
    deux actions offertes **en lecture seule uniquement** (`ai_experts_dialogs.dart:172`, `:591`).
25. **Gérer les fournisseurs d'IA** (routeurs) : modèles, repli, effort
    (`ai_routers_page.dart`, `ai_router_zcrud_edition.dart`).
26. **Gérer les matières** — écran monté par l'administration mais relevant du domaine « étude ».
27. **Voir un écran « Accès restreint » explicite** quand la lecture est refusée
    (`accademic_years_page.dart:77-125`, `ai_routers_page.dart:75-123`).

### 2.4 Accueil et tableau de bord

28. **Ouvrir directement le tableau de bord** (route initiale `/dashboard`).
29. **Basculer entre trois espaces par onglets** : Accueil, Dossiers d'étude, Assistant IA
    (`dashbord_page.dart:174-243`).
30. **Voir ses tâches quotidiennes et ses examens** en deux onglets (`home_page.dart:28-59`).
31. **Configurer un examen depuis l'accueil ou le tableau de bord** (`dashbord_page.dart:121-136`).
32. **Voir les examens groupés** (par période) avec actions modifier/supprimer (`exams_page.dart`).
33. **Voir un contenu filtré par sa filière et son cycle** : les matières visibles sont
    dérivées de la promotion de l'auditeur, sauf pour un administrateur (`dashbord_page.dart:83-116`).

### 2.5 Espace de travail (module `workflow/`)

34. **Consulter un agenda** (vues jour/semaine/mois/planning, glisser-déposer, ressources,
    fuseaux horaires) — `agenda_screen.dart`, sur `SfCalendar`.
35. **Créer et modifier un rendez-vous** : sujet, notes, lieu, journée entière, couleur,
    fuseau, **règles de récurrence complètes** (jamais / quotidien / hebdo / mensuel / annuel,
    exceptions, série) — `appointment_editor.dart`, `event_editon_screen.dart`.
36. **Gérer des listes de tâches** : créer une liste, ajouter/cocher/supprimer une tâche,
    échéance, rappel, sous-tâches (`tasks_screen.dart`, `task_edition_screen.dart`).
37. **Basculer entre Agenda et Gestion des tâches** depuis le tiroir (`workspace_page.dart`).

### 2.6 Réglages

38. **Choisir le thème clair / sombre / système**, persisté (`app.settings.dart:37-59`).
39. **Mémoriser l'année académique, le routeur d'IA et l'URL du service** en préférences
    locales (`settings_providers.dart:24-95`).

> ⚠️ **Il n'existe AUCUN écran de réglages** dans IFFD (cf. §9, grep 4). Les « réglages »
> sont trois providers persistés en `SharedPreferences` et deux tuiles dans le pied du
> tiroir. C'est un **manque fonctionnel**, pas un écran à migrer.

---

## 3. Les écrans

### 3.1 Écrans routés (`@RoutePage()`) — 14

| Écran | Chemin | Lignes | Rôle | Formulaire | Liste | Navigation | Rendu riche |
|---|---|---:|---|:---:|:---:|:---:|:---:|
| `LoginPage` | `presentation/features/auth/pages/login_page.dart` | 727 | connexion e-mail/Google + réinit. mdp | ✅ | — | — | — |
| `PresentationPage` | `presentation/features/home/pages/presentation_page.dart` | 171 | carrousel d'accueil (4 volets) | — | — | ✅ | — |
| `DashboardPage` | `presentation/features/home/pages/dashbord_page.dart` | 620 | coquille à onglets + FAB + barre basse | — | — | ✅ | — |
| `HomePage` | `presentation/features/home/pages/home_page.dart` | 147 | 2 onglets (tâches / examens) | — | — | ✅ | — |
| `AppAdministrationPage` | `…/administration/pages/app_administration_page.dart` | 70 | aiguilleur des 6 sous-pages d'admin | — | — | ✅ | — |
| `AccademicYearsPage` | `…/administration/pages/accademic_years_page.dart` | 692 | liste de promotions en cartes-dégradé | — | ✅ | — | — |
| `UserRolePage` | `…/administration/pages/user_role_page.dart` | 632 | liste des groupes + recherche | — | ✅ | — | — |
| `AuditeursPages` | `…/administration/pages/auditeurs_pages.dart` | **1 227** | liste + recherche + filtres + onglets/filière | ✅ (filtre) | ✅ | ✅ | — |
| `AiExpertsPage` | `…/administration/pages/ai_experts_page.dart` | **1 330** | liste d'assistants + recherche + onglets | — | ✅ | ✅ | — |
| `ExamsPage` | `…/administration/pages/exams_page.dart` | 333 | examens groupés par période | — | ✅ | — | — |
| `AiRoutersPage` | `…/ai_routers/pages/ai_routers_page.dart` | 803 | liste des fournisseurs d'IA | — | ✅ | — | — |
| `WorkspacePage` | `workflow/screens/workspace_page.dart` | 38 | aiguilleur agenda/tâches | — | — | ✅ | — |
| `CalenderScreen` | `workflow/screens/agenda_screen.dart` | 737 | agenda Syncfusion | — | ✅ | ✅ | — |
| `TasksScreen` | `workflow/screens/tasks_screen.dart` | 749 | listes de tâches | ✅ (en ligne) | ✅ | ✅ | — |

### 3.2 Écrans NON routés, montés par la garde d'accès — 3

| Écran | Chemin | Lignes | Rôle | Formulaire |
|---|---|---:|---|:---:|
| `FirstLoginScreen` | `…/auth/pages/first_login_screen.dart` | 336 | changement de mot de passe obligatoire | ✅ |
| `ForceUpdateScreen` | `…/auth/pages/force_update_screen.dart` | 223 | blocage version obsolète | — |
| `AccademicYearSelectionPage` | `…/auth/pages/accademic_year_selection_page.dart` | 452 | choix de l'année académique | ✅ |

### 3.3 Écrans d'édition (poussés en dialogue / feuille / page)

| Écran | Chemin | Lignes | Nature |
|---|---|---:|---|
| `AiExpertdEditionScreen` | `…/administration/dialogs/ai_experts_dialogs.dart` | 1 200 (fichier) | formulaire legacy, **40 `DynamicFormField`** |
| `AuditeurIffdEditionScreen` | `…/administration/dialogs/auditeurs_iffd_modal_dialogs.dart` | 438 | formulaire legacy, 9 champs |
| `AppUserRoleEditionScreen` | `…/administration/dialogs/app_user_role_dialogs.dart` | 374 | formulaire legacy, 5 champs |
| `PromotionEditionScreen` | `…/administration/dialogs/annee_accademique_modal_dialogs.dart` | 306 | formulaire legacy, 5 champs |
| `showExamEditonDialog` | `…/administration/dialogs/exames_dialogs.dart` | 282 | formulaire legacy, 4 champs |
| `ExamZcrudEditionScreen` | `…/administration/dialogs/exam_zcrud_edition.dart` | 513 | **jumeau zcrud** |
| `AppointmentEditionScreen` | `workflow/screens/event_editon_screen.dart` | 1 192 | éditeur d'événement |
| `TaskEditionScreen` | `workflow/screens/task_edition_screen.dart` | 524 | éditeur de tâche |
| `AppointmentEditorWeb` / `AppointmentEditor` / `PopUpAppointmentEditor` | `workflow/screens/appointment_editor.dart` | **7 858** | **trois variantes du MÊME éditeur** (cf. §5.1) |

### 3.4 Composants de navigation

| Composant | Chemin | Lignes |
|---|---|---:|
| `SidemenuDrawer` | `presentation/core/side_menu/side_menu_drawer.dart` | 415 |
| `ModuleMenu` / `MenuItemWidget` | `presentation/core/side_menu/menu_item_widget.dart` | 359 |
| `SideMenuState` (`ChangeNotifier`) | `presentation/core/side_menu/side_menu_state.dart` | 147 |
| `SideMenuItem` (modèle, `toMap`/`fromRoute`) | `presentation/core/side_menu/menu_item_model.dart` | 90 |
| `AppScaffold` | `presentation/app_scaffold.dart` | 186 |
| `AppRouter` (routes déclarées) | `config/router/app_router.dart` | 270 |
| `app_router.gr.dart` (généré) | `config/router/app_router.gr.dart` | **2 601** |
| `DynamicSearcheableAppBar` | `presentation/core/widgets/dynamic_searcheable_app_bar.dart` | 372 |
| `popup_menu_helpers.dart` | `presentation/core/widgets/popup_menu_helpers.dart` | **1 016** |

---

## 4. Modèles de domaine, sérialisation et persistance

### 4.1 Les entités

| Entité | Chemin | Lignes | Rôle |
|---|---|---:|---|
| `AppUser` | `domain/models/app_user.dart:37` | 589 (fichier) | identité de base : uid, e-mail, nom, genre, `permissions`, `passwordChanged`, `ignorePasswordChangeUntil` |
| `AppUserData` | `domain/models/app_user.dart:269` | — | `AppUser` + dossiers archivés, cycle, filière, série d'étude |
| `AuditeurIffd` | `domain/models/app_user.dart:434` | — | `AppUser` + pays d'origine, administration, `filieresEtCycles` |
| `AnneeAccademique` | `domain/models/annee_accademique.dart` | 483 | promotion : nom, interne/externe, dates, auditeurs par filière/cycle, **12 cartes d'autorisations** |
| `AppUserRole` | `domain/security/app_user_role.dart` | 77 | groupe : nom, `usersIds`, `permissions` |
| `ExamModel` | `domain/models/exam_model.dart` | 168 | examen : titre, date, dossier, matière, année |
| `RessourceACL` | `domain/security/ressource_acl.dart` | 163 | 11 booléens (read/create/update/delete/copy/restore/archive/publish/clear/validate/history) + `or`/`and`/`copyWith` |
| `AppUserPermissions` | `domain/security/app_user_permissions.dart` | 256 | agrégateur : permissions directes + rôles + postes ; `can<R>()`, `hasAccessTo<R>()`, `getACL<R>()` |
| `Crud` (enum) | `domain/security/crud.dart` | 173 | 11 opérations classiques + **6 opérations d'IA** (`aiGenerate`, `aiSummary`, `aiMindMap`, `aiFlashCard`, `aiExplain`, `aiChat`) |
| `SideMenuItem` | `presentation/core/side_menu/menu_item_model.dart` | 90 | entrée de menu dérivée d'une route |
| `RequiredVersion` | `domain/security/access_controlled_view.dart:30` | 30 | version minimale exigée |
| workflow : `Task`, `TaskList`, `Event`, `Appointment`, `TimeSlice`, `Note` | `workflow/models/` | 1 672 | agenda et tâches |

### 4.2 Sérialisation — manuelle, sans codegen, dispatchée par une TABLE de types

- Chaque modèle écrit **à la main** `toMap()`, `fromMap()`, `toJson()`, `fromJson()`,
  `copyWith()`, `props`, `==`, `hashCode`, `toString()`.
  `AppUser` seul : `toMap` `:107`, `fromMap` `:124`, `copyWith` `:163` — ~160 lignes de
  plomberie pour 11 champs.
- Le dispatch générique passe par **deux tables `Map<Type, Function>` écrites à la main** :
  - `fromMap<T>()` — `utils/functions/data_functions.dart:314-414` : **44 entrées**
    (`AnneeAccademique: () => AnneeAccademique.fromMap(map)`, …). Un type absent de la table
    provoque un `null` casté en `T` (`:412` : `createInstance?.call() as T`) — **crash silencieux**.
  - `createInstanceOf<T>()` — `data_functions.dart:202-219` : 4 entrées seulement.
  - `toMap<T>()` — `data_functions.dart:223-247` : essaie `.toMap()`, puis `.toJson()`,
    **dans un `try/catch` vide** (`:242`). Un modèle sans `toMap` rend `{}` sans erreur.
- **`reflectable` est mort** : le seul fichier qui le mentionne est commenté
  (`domain/models/reflector.dart:1`).

### 4.3 Persistance — Firestore, collections nommées par le nom du TYPE Dart

- `getFirebaseCollectionName<T>()` (`utils/functions/databases_functions.dart:8`) rend
  `FIREBASE_COLLECTION_NAMES[T] ?? T.toString()`.
- **`FIREBASE_COLLECTION_NAMES` est VIDE** (`utils/constants/databases.dart:3`).
  ⇒ Les collections s'appellent littéralement `AuditeurIffd`, `AnneeAccademique`,
  `AppUserRole`, `ExamModel`, `AiExpert`, `IffdAiRouterModel` — **à la racine** de Firestore.
  Renommer une classe Dart renomme la collection.
- `FirestorePaths` (`core/constants/firestore_paths.dart`, 36 l) décrit une arborescence
  **multi-tenant** (`institutions/{id}/users/…`) qui n'est **pas** celle qu'utilisent les dépôts.
  Deux schémas de chemins coexistent, un seul est branché.
- Dépôt générique : `FirebaseCrudRepositoryImpl<T>` (`data/repositories/firebase_crud_repository_impl.dart`,
  499 l) — `create`/`mapCreate`/`update`/`mapUpdate`/`delete`/`softDelete`/`restore`/
  `batchSet`/`batchUpdate`/`batchDelete`/`streamAll`/`streamOne`/`streamByIds`/`count`.
- 36 dépôts concrets, presque tous vides, dans un **seul fichier** de 434 lignes
  (`data/repositories/firebase_models_repositories_impls.dart`) — ils ne surchargent que
  `crudableObjects` (le catalogue d'opérations autorisées).
- **Aucun cache local, aucune synchronisation hors ligne** : pas de Hive, pas de
  `persistenceEnabled`, pas de `connectivity` (cf. §9, grep 3). Tout passe par les
  `snapshots()` de Firestore.

### 4.4 Traitement des erreurs — le point faible

- Le contrat `CrudRepository` rend un `DataState<T, Exception>`
  (`utils/resources/data_state.dart`) — l'équivalent maison d'`Either<ZFailure, T>`.
- **Mais les flux de lecture ne le portent pas** : `streamAll()`, `streamOne()`,
  `streamByIds()` rendent des `Stream<List<T>>` **nus** (`domain/repositories/datacrud_repository.dart:27-29`).
- Conséquence mesurée : sur les **26 `StreamBuilder`** du périmètre,
  **0 ne teste `snapshot.hasError`**, et **0 ne traite un `DataFailed`** (§9, greps 1 et 2).
  Le motif universel est `snapshot.data ?? []` — une erreur Firestore rend donc une liste
  vide, indiscernable d'une base vide.
- Le fichier `pubspec.yaml:29-55` documente un incident exactement de cette nature :
  un décalage de codec Pigeon faisait échouer toute requête `snapshots()`, l'exception
  était **avalée avant d'atteindre les providers**, et les écrans restaient en chargement
  éternel « sans erreur, sans PERMISSION_DENIED ».
- Il existe bien un `failures.dart` + `failures.freezed.dart` (637 l générées) dans
  `core/errors/` — **aucun écran du périmètre ne les consomme**.

### 4.5 Sécurité — à signaler tel quel

| Constat | Où | Nature |
|---|---|---|
| Les règles Firestore autorisent **lecture et écriture sur tout document** pour tout utilisateur authentifié | `firestore.rules:5-7` | **toute l'ACL est côté client** ; les 11 booléens de `RessourceACL` sont décoratifs vis-à-vis du serveur |
| Une **adresse e-mail codée en dur** accorde le statut administrateur | `domain/security/app_user_permissions.dart:19` | porte dérobée permanente (valeur non citée ici) |
| **Identifiant client OAuth Google en dur** dans l'écran de connexion | `presentation/features/auth/pages/login_page.dart:99-101` | valeur non citée ici |
| **Deux valeurs de repli codées en dur** (jeton de débogage App Check, clé de site reCAPTCHA) | `config/env_config.dart:9` et `:16` | repli quand `.env` est absent ; valeurs non citées ici |
| Le fichier `.env` existe et **est bien ignoré par git** | `.gitignore:46` | ✅ conforme |

---

## 5. LE CODE RÉPÉTÉ — le cœur du relevé

> Convention : « sites » = nombre d'endroits distincts où le bloc est réécrit ;
> « lignes » = total cumulé mesuré.

### 5.1 Trois éditeurs de rendez-vous pour un seul modèle — **5 228 lignes**

`workflow/screens/appointment_editor.dart` (7 858 l) contient **trois classes qui éditent
exactement le même objet**, avec le même jeu de champs :

| Classe | Lignes | Étendue | `_subject` | `_notes` | `_location` | `_isAllDay` | `_startDate` | `_selectedColor` | `_recurrenceProperties` |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| `PopUpAppointmentEditor` | 703 | `:961-1663` | 8 | 6 | 6 | 5 | 33 | 11 | 0 |
| `AppointmentEditorWeb` | **3 552** | `:1664-5215` | 12 | 8 | 8 | 15 | 59 | 13 | 102 |
| `AppointmentEditor` | 973 | `:5216-6188` | 13 | 8 | 5 | 11 | 36 | 12 | 17 |
| **Total** | **5 228** | | | | | | | | |

S'y ajoutent trois sélecteurs maison (`CalendarColorPicker` `:732`, `_ResourcePicker` `:813`,
`CalendarTimeZonePicker` `:878`) et quatre dialogues de récurrence
(`SelectRecurrenceRuleDialog` `:6189`, `_DeleteDialog` `:6426`, `_EditDialog` `:6595`,
`_CustomRule` `:6856`).

C'est **le plus gros gisement du domaine** : 7 858 lignes pour éditer un objet de 403 lignes
(`workflow/models/appointment.dart`). Signature d'un exemple de démonstration Syncfusion
vendu tel quel (`isWebFullView` `:8`, `_repeatOption` `:11`, `_weekDay` `:20`).

### 5.2 L'état vide « premium » — 6 sites, **~897 lignes**

Le même bloc : cercle de 180 dp à dégradé, deux anneaux, `ShaderMask` sur une icône, titre,
sous-titre, puis bouton d'ajout à dégradé plein et ombre portée.

| Site | Étendue | Lignes |
|---|---|---:|
| `…/administration/pages/accademic_years_page.dart` | `:154-297` | 144 |
| `…/administration/pages/user_role_page.dart` | `:104-250` | 147 |
| `…/administration/pages/auditeurs_pages.dart` | `:237-387` | 151 |
| `…/administration/pages/ai_experts_page.dart` | `:131-286` | 156 |
| `…/ai_routers/pages/ai_routers_page.dart` | `:141-285` | 145 |
| `…/subjects/pages/subjects_page.dart` (adjacent) | `:130-283` | 154 |
| **Total** | | **897** |

`ShaderMask` apparaît **17 fois** dans `lib/`, dont 9 dans ces écrans.

### 5.3 La palette de dégradés de cartes — 4 sites, **40 lignes, valeurs identiques**

`static const List<List<Color>> …Gradients` déclarée quatre fois, avec **les six premières
paires identiques à l'octet** :

| Site | Nom | Entrées |
|---|---|---:|
| `…/administration/pages/accademic_years_page.dart:28` | `promotionGradients` | 6 |
| `…/administration/pages/user_role_page.dart:31` | `roleGradients` | 8 |
| `…/administration/pages/auditeurs_pages.dart:44` | `auditeurGradients` | 8 |
| `…/subjects/pages/subjects_page.dart:49` | `subjectGradients` | 8 |

Le seul littéral `0xFF667eea` apparaît **38 fois** dans `lib/`, réparti sur 8 fichiers.

### 5.4 Les onglets par filière + ACL par onglet + FAB conditionnel — 3 sites, **~330 lignes**

Bloc identique : construire `accessibleFilereEtCycles`, en dériver
`Map<String, DataRequest<T>> tabsRequests`, un cas « aucun accès », un cas « un seul onglet »,
puis `DefaultTabController` + `TabBarView` + FAB gouverné par `acl.create`.

| Site | Étendue | Lignes |
|---|---|---:|
| `…/administration/pages/auditeurs_pages.dart` | `:1112-1220` | 109 |
| `…/administration/pages/ai_experts_page.dart` | `:1214-1330` | ~117 |
| `…/subjects/pages/subjects_page.dart` (adjacent) | `:397-500` | ~104 |

### 5.5 Le post-traitement CRUD d'un dialogue d'édition — **14 sites, ~266 lignes**

```
if (result != null) {
  if (crud == Crud.create || crud == Crud.copy) result["id"] = randomString();
  final x = fromMap<T>(result);
  switch (crud) {
    case Crud.create: await repo.create(x); break;
    case Crud.update: await repo.update(x); break;
    default:
  }
  return x;
} else { return null; }
```

`case Crud.create:` : **15 occurrences** dans 14 fichiers.
`["id"] = randomString()` : **13 occurrences**.
Sites du périmètre : `annee_accademique_modal_dialogs.dart:70-88`,
`auditeurs_iffd_modal_dialogs.dart:354-372`, `app_user_role_dialogs.dart:267-285`,
`exames_dialogs.dart:245-259`, `ai_experts_dialogs.dart:909-927`.

⚠️ **Le bloc DIVERGE d'un site à l'autre** : `exames_dialogs.dart` n'attribue **pas**
d'identifiant en création (pas de `randomString()`), et `annee_accademique_modal_dialogs.dart:79`
passe `merge: false` là où les autres n'en passent pas. Douze copies, deux comportements.

### 5.6 L'enveloppe `show<Entité>EditionDialog` — 15 fonctions, dont 5 au périmètre

Même signature (`item`, `crud`, `dialog`, `fullscreenDialog`, `repository`, `userPermissions`),
même corps : dépôt par défaut `??=`, lecture du flag de bascule, branche legacy ou socle,
puis le bloc §5.5.

| Fonction | Chemin |
|---|---|
| `showPromotionEditionDialog` | `…/administration/dialogs/annee_accademique_modal_dialogs.dart:34` |
| `showAuditeurEditionDialog` | `…/administration/dialogs/auditeurs_iffd_modal_dialogs.dart:316` |
| `showSAppUserRoleEditonDialog` | `…/administration/dialogs/app_user_role_dialogs.dart:233` |
| `showExamEditonDialog` | `…/administration/dialogs/exames_dialogs.dart:29` |
| `showAiExpertEditionDialog` | `…/administration/dialogs/ai_experts_dialogs.dart:850` |
| + 10 hors périmètre | `folders`, `flashcards`, `mindmap`, `smartnotes`, `documents`, `subjects`, `ai_routers`, `valuation_tools` |

### 5.7 Le pont `_presenterParLeSocle` — 4 sites, **219 lignes**

Fonction privée **réécrite dans chaque fichier de dialogue** : récupérer le contexte,
lire le conteneur Riverpod, lire les libellés, résoudre le catalogue des ressources
délégables, calculer `withPermissions`, appeler le présentateur zcrud, fusionner le résultat.

| Site | Lignes |
|---|---:|
| `…/administration/dialogs/ai_experts_dialogs.dart:1010-1087` | 78 |
| `…/administration/dialogs/auditeurs_iffd_modal_dialogs.dart:387-438` | 52 |
| `…/administration/dialogs/annee_accademique_modal_dialogs.dart:260-306` | 47 |
| `…/administration/dialogs/app_user_role_dialogs.dart:333-374` | 42 |
| **Total** | **219** |

Trois d'entre eux contiennent **le même appel exact** à
`PermissionHelpers.generateCrudableObjects(accademicYears:…, aiRouters:…, tr:…, baseCrudableObjects:…)`,
précédé des mêmes deux lectures de flux `.streamAll().first`.

### 5.8 Le calcul de grille responsive à la main — **16 fichiers, dont 6 au périmètre**

```
final isMobileScreen = Get.width < 800;
final drawerWidth = isMobileScreen ? 0.0 : 300.0;
final screenWidth = Get.width - drawerWidth;
final itemMinWidth = Get.width >= 840 ? 350.0 : 300.0;
final crossAxisCount = screenWidth ~/ itemMinWidth;
final itemWidth = screenWidth / crossAxisCount;
```

Sites du périmètre : `accademic_years_page.dart:302`, `user_role_page.dart:258`,
`auditeurs_pages.dart:396`, `ai_experts_page.dart:290`, `exams_page.dart`,
`ai_routers_page.dart:290`. Dix autres ailleurs dans `lib/`.
⚠️ Deux variantes coexistent : les unes mesurent `Get.width` (largeur d'écran),
les autres `constraints.maxWidth` (largeur du conteneur). Le résultat diffère quand le
tiroir est permanent.

### 5.9 La feuille d'actions « Modifier / Supprimer » — **8 fichiers, 3 554 lignes**

Tous héritent de `StatelessItemDialogWidget<T>` (`presentation/core/widgets/dialog_widgets.dart:10`)
et réécrivent le même couple de `ListTile`.

| Fichier | Lignes |
|---|---:|
| `…/documents/widgets/folder_documents_actions_dialog_widget.dart` | 1 804 |
| `…/valuation_tools/widgets/valuation_tool_model_actions_dialog_widget.dart` | 823 |
| `…/smartnotes/widgets/smartnote_actions_dialog_widget.dart` | 417 |
| `…/folders/dialogs/folder_actions_dialog_widget.dart` | 186 |
| `…/flashcards/widgets/flashcard_actions_dialog_widget.dart` | 126 |
| **`…/administration/widgets/exam_actions_dialog_widget.dart`** | **76** |
| `…/subjects/widgets/subject_actions_dialog_widget.dart` | 66 |
| **`…/administration/widgets/app_user_role_actions_dialog_widget.dart`** | **56** |

⚠️ **Divergence de comportement entre deux copies du MÊME domaine** :
`exam_actions_dialog_widget.dart:64` demande une confirmation avant de supprimer
(`buildConfirmDialog`) et ferme par `Get.back()` ;
`app_user_role_actions_dialog_widget.dart:44-48` **supprime sans confirmation** et ferme par
`Navigator.pop`. Supprimer un groupe d'utilisateurs est irréversible et non confirmé.

### 5.10 Le contrôleur de recherche — **14 sous-classes VIDES**

`dynamic_list_search_controller.dart:35-71` déclare quatorze classes dont le corps est `{}`,
uniquement pour servir de clé de type à `Get.put` :
`FoldersListController`, `AiAssistantsListController`, `AuditeursIffdSearchController`,
`AiExpertListController`, `SubjetcsListController`, `PublicFoldersListController`,
`CodeDesDouanesListController`, `CodeDesImpotsListController`, `TectCedeaoListController`,
`ValuationToolsListController`, `AppUserRolesListController`, `HomePageListController`,
`AccountingPlanSearchController`, `PublicFoldersDetailsSearchController`.

Le filtre associé (`unaccentedText(x).replaceAll(" ","").toLowerCase().contains(q)`) est
réécrit **22 fois** dans 12 fichiers.

### 5.11 L'en-tête à pastille dégradée — 5 sites, **~140 lignes**

`PreferredSizeWidget buildAppBar()` / `PreferredSize buildAppbar({List<String> tabs})`
déclarée localement dans le `build()` de cinq écrans :
`accademic_years_page.dart:46`, `auditeurs_pages.dart:72`, `ai_experts_page.dart:52`,
`ai_routers_page.dart:43`, `subjects_page.dart:70`.

### 5.12 Le boîtier d'animation d'entrée — 3 sites, **~60 lignes**

`AnimationController(800 ms)` + `CurvedAnimation(easeOut)` + `Tween<Offset>(Offset(0,0.1) → zero,
easeOutCubic)` + `forward()` + `dispose()` :
`login_page.dart:41-58`, `first_login_screen.dart:36-53`, `accademic_year_selection_page.dart:37-54`.
Ces trois écrans redéclarent aussi `kPrimaryColor = Color(0xFF6C63FF)`
(`login_page.dart:37`, `accademic_year_selection_page.dart:34`, `presentation_page.dart:55`).

### 5.13 Le bloc « Accès restreint » — 2 sites, ~50 lignes chacun

`accademic_years_page.dart:77-125` et `ai_routers_page.dart:75-123` : cercle rouge/orange,
cadenas, titre, sous-titre. Écrit deux fois **et absent des quatre autres écrans
d'administration**, qui ne rendent rien de particulier quand la lecture est refusée.

### 5.14 Récapitulatif chiffré

| # | Motif répété | Sites | Lignes cumulées |
|---:|---|---:|---:|
| 5.1 | Trois éditeurs de rendez-vous identiques | 3 | **5 228** |
| 5.2 | État vide « premium » | 6 | **897** |
| 5.4 | Onglets par filière + ACL + FAB | 3 | ~330 |
| 5.5 | Post-traitement CRUD d'un dialogue | 14 | ~266 |
| 5.7 | Pont `_presenterParLeSocle` | 4 | 219 |
| 5.11 | En-tête à pastille dégradée | 5 | ~140 |
| 5.13 | Bloc « Accès restreint » | 2 | ~100 |
| 5.12 | Boîtier d'animation d'entrée | 3 | ~60 |
| 5.3 | Palette de dégradés | 4 | 40 |
| 5.10 | Sous-classes de contrôleur vides | 14 | 14 |
| 5.8 | Calcul de grille responsive | 6 (16 au total) | ~40 |
| **Total mesuré** | | | **≈ 7 334 lignes** |

Soit **15 % des 48 811 lignes du domaine** en blocs strictement redondants — et 5.1 à lui
seul en représente les deux tiers.

---

## 6. Ce qui est DÉJÀ branché sur zcrud

### 6.1 Vue d'ensemble

- **91 fichiers** de `lib/` importent au moins un `package:zcrud_*`.
- **22 paquets zcrud** consommés, répartis ainsi (nombre d'imports) :
  `zcrud_core` 55 · `zcrud_chat_kernel` 19 · `zcrud_study` 17 · `zcrud_chat` 15 ·
  `zcrud_flashcard` 11 · `zcrud_study_kernel` 8 · `zcrud_mindmap` 6 ·
  **`zcrud_screen` 5** · `zcrud_firestore` 5 · `zcrud_ui_kit` 3 · `zcrud_session` 3 ·
  `zcrud_note` 3 · `zcrud_navigation` 3 · `zcrud_markdown` 3 · `zcrud_exam` 3 ·
  `zcrud_document` 3 · `zcrud_chat_syncfusion` 3 · `zcrud_chat_material` 3 ·
  `zcrud_intl` 2 · `zcrud_chat_markdown` 2 · `zcrud_select` 1 · `zcrud_menu` 1.

### 6.2 Dans MON périmètre : l'administration est la tête de pont de `zcrud_screen`

**Les 5 imports de `zcrud_screen` (`presentFormEdition`) du dépôt entier sont tous dans
`features/administration/`** :

| Fichier | Lignes | Importe |
|---|---:|---|
| `…/administration/zcrud/ai_expert_zcrud_edition.dart` | 534 | `zcrud_core`, `zcrud_navigation`, `zcrud_screen` |
| `…/administration/dialogs/exam_zcrud_edition.dart` | 513 | `zcrud_core` |
| `…/administration/dialogs/annee_accademique_zcrud_edition.dart` | 300 | `zcrud_core`, `zcrud_navigation`, `zcrud_screen` |
| `…/administration/dialogs/auditeur_iffd_zcrud_edition.dart` | 221 | `zcrud_core`, `zcrud_screen` |
| `…/administration/dialogs/app_user_role_zcrud_edition.dart` | 198 | `zcrud_core`, `zcrud_screen` |
| `…/administration/zcrud/ai_expert_documents_field.dart` | 193 | `zcrud_core` |
| `…/administration/dialogs/auditeur_account_zcrud_edition.dart` | 162 | `zcrud_core`, `zcrud_screen`, `zcrud_intl` |
| `…/administration/dialogs/auditeurs_iffd_modal_dialogs.dart` | 438 | `zcrud_core` (`ZFieldChoice` seul) |
| **Total portage admin** | **2 559** | |

Symboles zcrud consommés : `EditionFieldType`, `ZFieldSpec`, `ZValidatorSpec`, `ZFieldChoice`,
`ZDateConfig`/`ZDateMode`, `ZTextConfig`, `ZTextCapitalization`, `ZSubListConfig`,
`ZEditionStep`, `ZStepperEdition`, `ZFieldWidgetBuilder`, `ZFieldWidgetContext`,
`ZSelectFieldWidget`, `ZSelectChoiceContext`, `ZRelationSourceRegistry`,
`ZEditionPresentation`, `ZEditionBodyFit`, `ZFormOnly`, `ZFormOnlyController`,
`presentFormEdition`, `ZIntlFieldConfig`.

**53 `ZFieldSpec`** sont déclarées dans l'administration (28 pour l'expert IA seul), contre
**70 `DynamicFormField`** legacy encore en place dans les mêmes écrans (40 pour l'expert IA,
9 pour l'auditeur, 7 dans le filtre de la page auditeurs, 5 pour le groupe, 5 pour l'année,
4 pour l'examen).

### 6.3 Ce qui est enregistré au registre de widgets

Registre unique, construit par `buildIffdWidgetRegistry()`
(`presentation/shared/zcrud/z_iffd_field_registry.dart:78-207`), monté **une seule fois**
au-dessus de toute l'app par `IffdZcrudScope` dans `main.dart:270` :

| Enregistrement | Origine | Rôle |
|---|---|---|
| `registerZMarkdownFields(registry, codec: IffdRichTextCodec(), styleSet: …, chrome: …)` | `zcrud_markdown` | champs riches — **le codec évite la destruction de ~11 400 valeurs markdown** (`:19-23`) |
| `registerZFlashcardEditors(registry, trueLabel:'Vrai', …)` | `zcrud_flashcard` | sélecteur de type, éditeur QCM, vrai/faux |
| `registry.register('phoneNumber', ZPhoneFieldWidget.builder())` | `zcrud_intl` | téléphone — **le legacy déclarait le type sans jamais le rendre** (`:159-165`) |
| `registry.register(kIffdBooleanKind, iffdBooleanBuilder())` | maison | booléen `FlutterSwitch`, sert **tous** les booléens de l'app |

Ports et résolveurs posés au `ZcrudScope` (`z_iffd_field_registry.dart:290-345`) :
`theme` (mémoïsé par luminosité), `gradientResolver`, `iconResolver`, `colorKeyResolver`,
`selectPresenter: ZSmartSelectPresenter()`, `defaultTextConfig` (majuscule initiale),
`numberDisplayFormatter`, `dateDisplayFormatter`, `subListSeamRegistry`,
`relationSourceRegistry`, `acl`.

Registres **locaux à un formulaire** (registre enfant, via `IffdZcrudScope.extraWidgets`) :

| `widgetKind` | Fichier | Consommateurs |
|---|---|---|
| `kIffdAclMatrixKind` | `presentation/shared/zcrud/z_iffd_acl_matrix_field.dart` (262 l) | **3 formulaires** : année académique, auditeur, groupe d'utilisateurs |
| `kAiExpertDocumentsKind` | `…/administration/zcrud/ai_expert_documents_field.dart` (193 l) | expert IA |
| `kExamFolderRelationSourceKey` | `…/administration/dialogs/exam_zcrud_edition.dart:278` | examen |
| `kAppUserRoleUsersSourceKey` | `…/administration/dialogs/app_user_role_zcrud_edition.dart:117` | groupe d'utilisateurs |

### 6.4 État réel de la bascule : **34 portages sur 35 sont ÉTEINTS**

Le dépôt compte **35 constantes `k…UseZcrudDefault`**. **Une seule vaut `true`** :
`kAiRouterEditionUseZcrudDefault` (`…/ai_routers/zcrud/ai_router_zcrud_edition.dart:91`).
Les **34 autres valent `false`** — le chemin legacy reste actif.

Bascules du périmètre, toutes à `false` :

| Bascule | Fichier | Jumeau legacy encore actif |
|---|---|---|
| `anneeAccademique` | `annee_accademique_zcrud_edition.dart:74` | `annee_accademique_modal_dialogs.dart` (306 l) |
| `appUserRole` | `app_user_role_zcrud_edition.dart:61` | `app_user_role_dialogs.dart` (374 l) |
| `auditeurIffd` | `auditeur_iffd_zcrud_edition.dart:61` | `auditeurs_iffd_modal_dialogs.dart` (438 l) |
| `auditeurAccount` | `auditeur_account_zcrud_edition.dart:58` | `auditeurs_pages.dart:452-481` |
| `exam` | `exam_zcrud_edition.dart:77` | `exames_dialogs.dart` (282 l) |
| `aiExpert` | `ai_expert_zcrud_edition.dart:87` | `ai_experts_dialogs.dart` (1 200 l) |

Le registre de QA (`presentation/shared/zcrud/z_qa_flags.dart`, 467 l) rassemble ces bascules,
les classe en trois familles (`rendu` / `comportement` / `données`) et documente que **douze
d'entre elles changent la DONNÉE écrite**. Il note aussi le défaut d'origine : les bascules
étaient des `const`, donc résolues à la compilation — **la QA « basculer les flags » n'était
pas exécutable** avant que les providers ne soient câblés (2026-08-01).

**Conclusion mesurée : dans mon domaine, zcrud est écrit mais pas allumé.**
2 559 lignes de jumeaux portés cohabitent avec 2 600 lignes de legacy actif.
Rien de ce qui est visible à l'écran, en administration, ne passe aujourd'hui par le socle.

### 6.5 Zones du périmètre à ZÉRO zcrud

| Zone | Lignes | Grep négatif |
|---|---:|---|
| `lib/workflow/` (agenda, tâches, rendez-vous) | 16 821 | §9 grep 7 |
| `lib/src/presentation/features/auth/` | 1 741 | §9 grep 8 |
| `lib/src/presentation/features/home/` | 941 | §9 grep 9 |
| `lib/src/features/{admin,auth,settings}/` | 1 384 | §9 grep 10 |
| **Total non touché** | **20 887** | |

---

## 7. Les widgets maison qui refont ce que zcrud fait probablement

| Widget maison | Chemin | Lignes | Ce qu'il refait |
|---|---|---:|---|
| **`DynamicEditionScreen`** | `data_crud/edition_screen.dart` | **4 038** | le moteur d'édition déclaratif entier — l'ancêtre de `DynamicEdition` |
| **`DynamicListScreen`** | `data_crud/dynamic_list_screen.dart` | **1 753** | la liste déclarative — l'ancêtre de `ZListRenderer` ; **n'est plus utilisée que 2 fois**, et jamais dans l'administration |
| `DynamicFormField<T>` | `data_crud/edition_field.dart:80` | 444 | `ZFieldSpec` — **65 propriétés**, dont validateurs, sources de choix, sous-listes, bornes de dates croisées, conditions d'affichage |
| `SubListScreen` | `data_crud/sub_list_screen.dart` | 565 | `ZSubListField` |
| `RichTextEditorScreen` + `markdown_edition_field` | `data_crud/rich_text_editor*` | 2 940 | `zcrud_markdown` |
| `popup_menu_helpers.dart` | `presentation/core/widgets/popup_menu_helpers.dart` | **1 016** | `zcrud_menu` / `ZMenuEntryTile` (importé une seule fois dans tout le dépôt) |
| `DynamicSearcheableAppBar<C>` | `presentation/core/widgets/dynamic_searcheable_app_bar.dart` | 372 | barre de titre à recherche + onglets — équivalent d'un en-tête de `ZCrudScreen` |
| `SidemenuDrawer` + `MenuItemWidget` + `SideMenuState` + `SideMenuItem` | `presentation/core/side_menu/` | 1 011 | `zcrud_menu` / `zcrud_navigation` |
| `AppScaffold` | `presentation/app_scaffold.dart` | 186 | coquille responsive à tiroir — équivalent d'une coquille `zcrud_screen` |
| `AccessControlledWrapper` + les 4 classes de garde | `domain/security/access_controlled_view.dart` | 310 | chaîne de gardes d'accès (aucun équivalent zcrud connu — **candidat d'assemblage**) |
| `RessourceACL` + `AppUserPermissions` | `domain/security/` | 419 | `ZAcl` — 11 opérations contre les 4 du socle |
| `DynamicListSearchController` (+ 14 sous-classes) | `presentation/shared/controllers/` | 71 | état de recherche/filtre d'une liste |
| `StatelessItemDialogWidget<T>` + 8 feuilles d'actions | `presentation/core/widgets/dialog_widgets.dart` + 8 fichiers | 3 602 | menu d'actions d'un élément de liste |
| `buildConfirmDialog` / `buildDeleteConfirmation` / `showPushedDialog` / `showErpDialog` / `scaffoldDialog` | `utils/functions/forms_utils.dart` | 1 193 | présentation de dialogue/feuille responsive — équivalent de `presentFormEdition` |
| `fromMap<T>` / `toMap<T>` / `createInstanceOf<T>` | `utils/functions/data_functions.dart:202-420` | ~220 | le registre de fabriques que génère `zcrud_generator` |
| `IffdRichTextCodec` | `presentation/shared/zcrud/z_iffd_rich_text_codec.dart` | 193 | `ZCodec` (déjà branché sur zcrud) |
| `iffdFormTheme` + `z_iffd_field_palette` | `presentation/shared/zcrud/` | 446 | `ZcrudTheme` (déjà branché) |
| trois éditeurs de rendez-vous + 4 dialogues de récurrence | `workflow/screens/appointment_editor.dart` | **7 858** | aucun équivalent socle connu — **plus gros bloc sans repreneur** |

**Point positif à souligner** : `buildConfirmDialog` est un helper **partagé** (38 sites) —
les confirmations ne sont donc *pas* dupliquées à la main. C'est l'exception, pas la règle.

---

## 8. Signaux pour la migration

1. **L'administration est la seule tête de pont de `zcrud_screen`** — tout le savoir-faire
   `presentFormEdition` du dépôt vit dans mes 5 fichiers. C'est un actif, pas une dette.
2. **Le socle est écrit mais éteint** : 34 bascules sur 35 valent `false`. Le coût de
   migration déjà payé (2 559 lignes de jumeaux) ne produit aucun bénéfice tant que la QA
   n'a pas eu lieu. **Douze bascules changent la donnée écrite** — elles ne peuvent pas être
   groupées.
3. **`lib/workflow/` (16 821 l, 34 % du domaine) n'a aucun contact avec zcrud** et contient
   la plus grosse duplication du dépôt (5 228 lignes pour trois éditeurs jumeaux). C'est le
   gisement le plus rentable **et** le plus risqué : c'est du code vendu (démo Syncfusion).
4. **Les listes d'administration n'utilisent PAS le moteur de liste legacy** : elles
   composent `StreamBuilder` + `Wrap` + cartes à la main. Elles n'ont donc rien à
   « débrancher » — elles sont à **écrire** contre `ZListRenderer`, pas à porter.
5. **Aucune gestion d'erreur de flux** (0/26 `StreamBuilder`) : la migration doit décider si
   le socle fait apparaître les erreurs que le legacy avale. C'est un **changement de
   comportement visible**, pas un portage.
6. **Toute l'ACL est côté client** (`firestore.rules:5-7`). Migrer `RessourceACL` (11 opérations)
   vers `ZAcl` (4 opérations) demande un arbitrage : `archive`, `publish`, `clear`, `validate`,
   `history`, `copy`, `restore` n'ont pas d'équivalent connu.
7. **La sérialisation est une table de 44 entrées écrite à la main** qui `null`-crashe sur
   un type absent. C'est exactement ce que `@ZcrudModel` supprime.
8. **Deux schémas de chemins Firestore coexistent** — le multi-tenant `FirestorePaths` n'est
   branché nulle part. À trancher avant toute migration de dépôt.
9. **Code mort à ne PAS migrer** : `lib/agents_screens.dart` (535 l, non routé — §9 grep 5),
   `lib/cotation/` (772 l, non référencé — §9 grep 6),
   `workflow/screens/time_management_page.dart` (**1 octet**, fichier vide) et
   `lib/src/domain/models/reflector.dart` (entièrement commenté — §9 grep 11).
   S'y ajoutent, dans `app_router.dart`, **61 lignes commentées sur 270** (dont 43 dans la
   seule plage `:126-183`) décrivant des routes retirées : `DailyTasksPageRoute`,
   `ExamsPageRoute`, `PublicFoldersPageRoute`, `CommunityFoldersPageRoute`,
   `DiscovryAiPageRoute`.
10. **22 fichiers de test** touchent le périmètre (dont `test/m0/` : navigation
    d'administration, jumeaux zcrud d'année académique / groupe / auditeur / compte,
    steppers, parité visuelle des champs, tripwires de formulaires). Ce sont les garde-fous
    de la migration — à ne pas perdre de vue.

---

## 9. Greps négatifs — les preuves d'absence

**1. Aucun `StreamBuilder` du périmètre ne teste `snapshot.hasError`.**
```
$ grep -rn "snapshot.hasError" lib/src/presentation/features/administration \
    lib/src/presentation/features/auth lib/src/presentation/features/home \
    lib/workflow lib/src/presentation/features/ai_routers --include='*.dart'
(aucune sortie)   RC=1
```
Repo-wide, seuls 4 sites testent `snapshot.hasError`, tous hors périmètre
(`documents_dialogs.dart:251`, `folder_document_pages_selection_dialog.dart:315`,
`conversation_list_widget.dart:225` et `:231`).

**2. Aucun `DataFailed` traité dans le périmètre.**
```
$ grep -rn "DataFailed\|is DataSuccess" <périmètre> --include='*.dart'
(aucune sortie)   RC=1
```

**3. Aucun cache local ni synchronisation hors ligne.**
```
$ grep -rn "package:hive" lib --include='*.dart' | wc -l
0
$ grep -rn "connectivity" lib --include='*.dart' | head -5
(aucune sortie)
$ grep -rn "persistenceEnabled\|cacheSizeBytes\|Source.cache" lib --include='*.dart'
(aucune sortie)
```

**4. Il n'existe aucun écran de réglages.**
```
$ find lib -iname '*setting*' -o -iname '*preference*' -o -iname '*parametre*'
lib/ai_assistant/zcrud/notebook_settings_iffd.dart
lib/app.settings.dart
lib/src/features/settings/providers/settings_providers.dart
lib/src/features/settings/providers/settings_providers.g.dart
lib/src/features/settings/settings_module.dart
lib/src/presentation/features/mindmap/widgets/element_settings_menu.dart
$ grep -rn "SettingsPage\|SettingsScreen\|ParametresPage" lib --include='*.dart'
(aucune sortie)
```
Aucun widget d'écran ; `lib/src/features/settings/` ne contient que 3 fichiers de providers.

**5. `lib/agents_screens.dart` (535 l) est mort.**
```
$ grep -rn "AgentsScreen" lib/src/config/router/
(aucune sortie)   RC=1
$ grep -rn "AgentsScreen(" lib --include='*.dart' | grep -v "^lib/agents_screens.dart"
(aucune sortie)   RC=1
```
Seule référence au fichier : un `import` inutilisé dans `lib/src/domain/models/app_user.dart:8`.

**6. `lib/cotation/` (772 l) est orphelin.**
```
$ grep -rn "cotations_screen\|CotationsScreen" lib --include='*.dart' | grep -v "^lib/cotation/"
(aucune sortie)   RC=1
```

**7. `lib/workflow/` n'a aucun contact avec zcrud.**
```
$ grep -rn "zcrud" lib/workflow --include='*.dart'
(aucune sortie)   RC=1
```

**8. `lib/src/presentation/features/auth/` n'a aucun contact avec zcrud.**
```
$ grep -rn "zcrud" lib/src/presentation/features/auth --include='*.dart'
(aucune sortie)   RC=1
```

**9. `lib/src/presentation/features/home/` n'importe aucun paquet zcrud.**
```
$ grep -rn "package:zcrud" lib/src/presentation/features/home --include='*.dart'
(aucune sortie)   RC=1
```

**10. `lib/src/features/{admin,auth,settings}/` n'importent aucun paquet zcrud.**
```
$ grep -rn "package:zcrud" lib/src/features/admin lib/src/features/auth \
    lib/src/features/settings --include='*.dart'
(aucune sortie)   RC=1
```
(Les seules occurrences de la chaîne « zcrud » sous `lib/src/features/` sont des
commentaires de `folder_providers.dart`, qui décrivent les bascules du domaine « dossiers ».)

**11. `reflectable` n'est pas utilisé.**
```
$ grep -rn "reflectable" lib --include='*.dart'
lib/src/domain/models/reflector.dart:1:// import 'package:reflectable/reflectable.dart';
```
Unique occurrence, en commentaire.

**12. `FIREBASE_COLLECTION_NAMES` est vide.**
```
$ sed -n '3p' lib/src/utils/constants/databases.dart
const Map<Type, String> FIREBASE_COLLECTION_NAMES = {};
```
⇒ Toutes les collections tombent sur le repli `T.toString()`.

---

*Relevé produit sans exécuter de test, sans écrire une ligne dans `/home/zakarius/DEV/iffd`.*
