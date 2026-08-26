# Confrontation — « Moteur de formulaires et listes historique, et la bascule en cours » (IFFD × zcrud)

> **Mesuré le 2026-08-26.**
> Hôte : `/home/zakarius/DEV/iffd` à `65d1af948dd070fcee963bed71dfceb873f5ae1a`
> (*Wed Aug 26 07:04:44 2026 +0000*), **lecture seule stricte**.
> Socle : `/home/zakarius/DEV/zcrud` à `cc276c154`, tag **v3.21.0**, 41 paquets.
> IFFD épingle **48** entrées `ref: v3.21.0` (`iffd/pubspec.yaml`).
>
> **Aucun test n'a été lancé, dans aucun dépôt.** Tout `fichier:ligne` du socle est relatif à
> `/home/zakarius/DEV/zcrud/packages/` ; les chemins hôtes portent le préfixe `iffd/`.
> Le relevé `iffd-migration-2026-08-25/` n'a servi de preuve pour **aucune** ligne.
> Les deux documents d'entrée (carte + cinq catalogues) ont été **revérifiés sur disque** :
> trois de leurs chiffres sont corrigés ici (§ 0.2).
>
> 🔴 **Ce document a subi une SECONDE PASSE de vérification** (2026-08-26, après coup). Six constats
> du premier jet ont été corrigés sur mesure — ils sont signalés en place par « 🔴 Rectification »
> ou par un encadré `>` :
> ① M1 portait sur 10 fichiers, il y en a **12** (464 → **534 l.**) ; ② M4 affirmait que l'hôte
> ignorait `ZMenuEntryTile` — il l'a **déjà adopté** sur un site ; ③ M4 opposait ≈ 420 l. estimées
> à un empan réel de **1 586 l.**, la distinction est désormais explicite ; ④ M10 comptait 15 pages,
> il y en a **14**, et `ZAppBarSearchConfig` y est **déjà consommé** ; ⑤ `buildConfirmDialog` compte
> **34** sites d'appel (et non 36 ou 38, deux chiffres qui coexistaient) ; ⑥ le lot de CR le plus
> récent (**CR-IFFD-114 → 120**) était **entièrement absent** : il apporte trois manques réels
> (§ 3, L9-L11) et quatre CR retirées par l'hôte (§ 3.bis).
> Trois lignes ont été ajoutées à la § 1 (A18-A20) et A16 a été complétée. Le reste du document a été recontrôlé
> `fichier:ligne` par `fichier:ligne` et **tient**.

---

## 0. Ce qu'il faut savoir avant de lire les tableaux

### 0.1 Le fait qui commande tout : l'adoption ne coûte AUCUNE dépendance neuve

`zcrud_screen`, `zcrud_ui_kit`, `zcrud_menu`, `zcrud_navigation` sont **déjà déclarés en
`dependencies`** (`iffd/pubspec.yaml`, bloc `dependencies` — 23 paquets `zcrud_*`), résolus au tag
v3.21.0, **compilés dans le binaire**. Pourtant :

```
$ cd /home/zakarius/DEV/iffd/lib
$ for s in ZCrudScreen ZCrudSource ZListQueryPolicy ZActionMenu ZMenuEntry ZContentStateView \
           ZEmptyState ZErrorState ZLoadingState showZConfirmDialog ZDiscardChangesGuard \
           ZToaster ZPageShellBody ZSearchableAppBar ZcrudLabels ZcrudRegistry ZRowAction \
           ZSelectionPolicy ZExportPolicy showZEntityHistory ZListTabsStore ZTrashMode \
           ZSfDataGridRenderer ZListRenderer ZDelegatesSearch ; do
    echo "$s: $(grep -rlnw --include='*.dart' "$s" . | wc -l)" ; done
```
→ **0 fichier pour les 25.**

« Inconnu de l'hôte » ne veut donc pas dire « pas encore publié » : ces canaux sont **dans son
arbre, disponibles tout de suite, sans montée de tag**.

**Un seul paquet manquerait** : `zcrud_list` (absent des `dependencies` **et** des
`dependency_overrides`). Et son blocage écrit est **périmé** — voir § 0.3.

### 0.2 Trois chiffres des documents d'entrée, corrigés par remesure

| Source | Affirmation | Remesure |
|---|---|---|
| carte, D6 | « adaptateurs `adapt…Zcrud…` : 17 sites, **115** lignes » | **17 fonctions, 460 lignes** (bloc complet, mesuré par comptage d'accolades) |
| carte, D1 | « 3 479 lignes » (`toMap`+`fromMap`+`copyWith`) | **2 604 lignes** dans `lib/src/domain/` seul (39 `toMap` = 525, 38 `fromMap` = 1 128, 39 `copyWith` = 951). L'écart vient du périmètre : la carte comptait aussi `lib/src/features/` |
| carte, §3 | « `z_qa_flags.dart` tient **52** bascules » | **53** `ZQaFlag(` réels, pour **52** `provider:` — un `ZQaFlag` de plus que de providers |

Ces écarts ne changent aucun verdict ; ils sont signalés parce qu'un chiffre non remesuré n'est pas
une preuve.

### 0.3 Le blocage Syncfusion n'existe plus — preuve

`iffd/pubspec.yaml:292` écrit : « `zcrud_list` / `zcrud_export` : exigent Syncfusion ^34, **IFFD est
en ^32** ».

```
$ grep -n 'syncfusion' /home/zakarius/DEV/iffd/pubspec.yaml | head
141:  syncfusion_flutter_core: ^34.1.31
144:  syncfusion_flutter_datagrid: ^34.1.31
145:  syncfusion_flutter_pdf: ^34.1.31
$ grep -n 'syncfusion' packages/zcrud_list/pubspec.yaml
  syncfusion_flutter_datagrid: ^34.1.31
$ grep -n 'zcrud_export' packages/zcrud_flashcard/pubspec.yaml ; echo "RC=$?"
RC=1
```

IFFD est en **^34.1.31**, `zcrud_list` demande **^34.1.31** : **le commentaire décrit un état
révolu**. Et `zcrud_flashcard` ne tire plus `zcrud_export` (grep négatif, RC=1) : la chaîne citée
en `pubspec.yaml:326` n'existe plus non plus.

---

## 1. DÉJÀ MIGRÉ — l'hôte consomme déjà le canal

| # | Canal du socle | Site chez l'hôte | Volume mesuré |
|---|---|---|---|
| A1 | **`presentFormEdition`** (`zcrud_screen/lib/src/presentation/present_form_edition.dart:234`) | 29 fichiers ; **16 des 27** `*_zcrud_edition.dart` l'emploient (`agents_filter`, `chatbot_conversation`, `task_list`, `text_menu`, `first_login`, `smartnote_ai_instructions`, `folders_filter`, `auditeur_iffd`, `app_user_role`, `auditeurs_filter`, `auditeur_account`, `annee_accademique`, `ai_expert`, `folder_flashcards_filter`, `flashcards_questions_count`, `export_flashcards_to_pdf`) | 29 fichiers |
| A2 | **`ZFormOnly` / `ZFormOnlyController`** (`z_form_only.dart:178` / `:52`) | 12 / 11 fichiers | — |
| A3 | **`presentEdition` + `ZSheetFrameSpec` + `ZEditionPresentation`** (`zcrud_navigation/…/present_edition.dart:155`) | `iffd/lib/src/utils/functions/forms_utils.dart:727` — `showPushedDialog` **délègue déjà** à `presentEdition` (`forcedMode`, `maxWidth`, `maxHeight`, `sheetFrame: ZSheetFrameMode.unlessChrome`). Les 93 appelants legacy sont intacts derrière l'enveloppe | 1 enveloppe, 93 appelants |
| A4 | **`DynamicEdition` / `ZStepperEdition`** (`dynamic_edition.dart:296` / `z_stepper_edition.dart:271`) | 14 / 10 fichiers | — |
| A5 | **`ZFieldSpec`** (`z_field_spec.dart:47`) | 34 fichiers, 48 fonctions `List<ZFieldSpec>` | — |
| A6 | **`ZFormController` + `ZEditionSubmitController`** (`z_form_controller.dart:33`, `z_submission.dart:176`) | 15 / 13 fichiers | — |
| A7 | **Sous-listes 3.13→3.19** — `ZSubListConfig` (12 sites), `ZSubListSeamRegistry` (7), `ZSubListSeams` (5), `headerBuilder` (6), **`itemBorderColorKey`** (1), `creationTemplates` (2), `reorderable` (8) | `iffd/lib/src/presentation/features/ai_routers/zcrud/ai_router_sub_list_seams.dart` et voisins | **16 jetons `subList*`** posés dans `z_iffd_form_theme.dart` |
| A8 | **`ZDerivation` + `zUnchanged`** (`z_derivation.dart:201`, sentinelle `:154`) | `subject_zcrud_edition.dart:552,571` (cascade d'effacement **déclarative**, plus aucun listener) ; `flashcard_edition_zcrud.dart:383` | 2 fichiers |
| A9 | **`ZWidgetRegistry` + registre de champs** (`z_widget_registry.dart:194`) | `z_iffd_field_registry.dart` (461 l) : `registerZMarkdownFields`, `registerZFlashcardEditors`, `registerZHtmlFields`, plus `register('phoneNumber', ZPhoneFieldWidget.builder())` (`:188`) et `register(kIffdBooleanKind, …)` (`:199`) | 3 fichiers |
| A10 | **`ZCodec`** (`zcrud_markdown/lib/src/domain/z_codec.dart`) | `z_iffd_rich_text_codec.dart:66` — `final class IffdRichTextCodec implements ZCodec` | 193 l |
| A11 | **`ZSmartSelectPresenter`** (`zcrud_select`, barrel `:52`) | injecté par `IffdZcrudScope` (`z_iffd_field_registry.dart:339`) | 2 fichiers |
| A12 | **`ZcrudTheme` + `gradientResolver`** (`z_theme.dart:323`, seam `zcrud_scope.dart:276`) | `z_iffd_form_theme.dart` (281 l) — **~24 jetons distincts** posés ; `ZcrudTheme.fallback(base)` en `ThemeExtension` (`app_theme.dart:171,259`) | 12 fichiers |
| A13 | **`ZSyncMeta`** (`sync/z_sync_meta.dart:20`) — `kUpdatedAt`, `kIsDeleted` | les 6 `z_backed_*_repository.dart` (10 fichiers, 84 occurrences) | — |
| A14 | **`ZcrudLocalizationsDelegate`** (`z_localizations.dart:407`) | `iffd/lib/main.dart:45,312` | 1 fichier |
| A15 | **`ZAcl` / `ZCrudAction` / `ZAllowAllAcl`** (`ports/z_acl.dart:101`) | `ai_router_zcrud_edition.dart:245` implémente `bool can(ZCrudAction, {ZEntity? target, String? collectionId})` ; `IffdZcrudScope` pose `acl: const ZAllowAllAcl()` (`z_iffd_field_registry.dart:232`) | 2 fichiers |
| A16 | **`showZRichTextFullscreenDialog`** (`zcrud_markdown/…/z_rich_text_fullscreen_dialog.dart:44`, barrel `zcrud_markdown.dart:53-54`) | 4 fichiers, dont 2 sites d'appel réels — `notebook_artifact_actions_iffd.dart:59,392` et `workflow_notes_zcrud_edition.dart:101,205` | 2 appels |
| A17 | **`ZDefaultReorderRenderer`** (repli zéro-dépendance, `zcrud_responsive/…/z_default_reorder_renderer.dart:36`) | choix documenté `study_tools_zcrud_adapter.dart:55-57` (ni `zcrud_reorder`, ni `zcrud_dnd`) | — |
| A18 | **`ZMenuEntryTile` + `ZItemAction.toMenuEntry()`** (`zcrud_menu/…/z_menu_entry_tile.dart:31` ; `zcrud_study/…/z_item_actions_menu.dart:246`, `ZItemAction` `:147`) | `folder_actions_menu_zcrud.dart:36` (import), `:209` (`gridDelegate`), `:215` (tuile), `:239` (`isVisible`) | 1 fichier, 241 l |
| A19 | **`ZMarkdownReader` + `ZMarkdownReaderChrome.none`** (`zcrud_markdown/…/z_markdown_reader.dart:47-54`) | `mindmap_rich_reader_zcrud.dart:149,152` et `ai_explanation_zcrud_reader.dart:118,148` | 2 lecteurs portés |
| A20 | **`ZAppBarSearchConfig`** (`zcrud_ui_kit/…/domain/z_app_bar_search_config.dart:16`) | `folder_details_page.dart:52,844` ; champ déclaré `folder_detail_zcrud.dart:37,283` | 2 fichiers |

**Lecture.** La bascule d'**édition** est très avancée : 16 des 27 formulaires portés utilisent
l'assemblage du socle, la vague sous-listes 3.13→3.19 est consommée, la dérivation déclarative est
maîtrisée (`zUnchanged` compris). Ce qui n'a **pas** bougé, c'est la **liste** — § 2, ligne M9.

---

## 2. 🔴 MIGRABLE AUJOURD'HUI — le socle sait déjà le faire, l'hôte l'ignore

> Chaque ligne porte : l'**API exacte**, son `fichier:ligne` sous `packages/`, la **preuve que le
> corps fait ce qu'on lui prête** (pas seulement sa dartdoc), le site hôte, et les **lignes d'hôte
> que l'adoption supprime**. Les pièges qui bornent la promesse sont dans la colonne « ⚠️ » et
> détaillés en § 2.bis.

### M1 — 12 formulaires portés montent encore leur chrome à la main

**API** : `presentFormEdition` — `zcrud_screen/lib/src/presentation/present_form_edition.dart:234`
(22 paramètres, `:235-256`).

**Preuve de corps** (lue, pas déduite) : `present_form_edition.dart:274-279` construit un
`ZFormOnlyController` ; `:285-300` définit `submit()` qui valide, `markPristine()`, puis
`Navigator.pop(values)` ; `:305-320` appelle `presentEdition` en posant un `ZEditionChrome(title,
submitLabel, discardLabel, onSubmit, formController, onConfirmDiscard)` ; `:359` termine par
`.whenComplete(controller.dispose)`. Le contrat de retour est `Future<Map<String, dynamic>?>` —
la map **validée**, ou `null`.

**Site hôte** : **12** fichiers refont exactement cela — mesuré par croisement
`ZEditionSubmitController` × `Scaffold(` × `AppBar(` sur les 13 fichiers porteurs du contrôleur de
soumission (seul `auditeur_account_zcrud_edition.dart` est déjà passé à `presentFormEdition`) — `late final
ZFormController` + `ZEditionSubmitController` + `dispose()` + `_onSave()` + `Scaffold(appBar:
AppBar(actions: [IconButton(Icons.save_outlined)]))`. Exemple canonique :
`iffd/lib/src/presentation/features/folders/dialogs/folder_zcrud_edition.dart:436-556`.

**Ce qui rend le remplacement sûr — mesuré** : ces 10 fichiers ne passent à `DynamicEdition` que
`controller`, `fields` et `readOnly` :

```
folder_zcrud_edition.dart:548      DynamicEdition(controller:, fields:, readOnly:)
subject_zcrud_edition.dart:718     ZStepperEdition(...)
exam_zcrud_edition.dart:509        DynamicEdition(controller:, fields:)
mindmap_zcrud_edition.dart:304     DynamicEdition(controller:, fields:)
folder_document_…:208 · smartnote_…:334 · valuation_tool_model_…:340
ai_base_url_…:280 · flashcard_tag_…:237 · ai_router_…:554 (ZStepperEdition)
```
Les trois paramètres sont couverts un pour un par `ZFormOnly` (`z_form_only.dart:185-271` :
`controller`, `fields`, `readOnly`), et les steppers par `steps` + `stepperConfig`
(`present_form_edition.dart:249-250`).

**Lignes supprimées — mesurées fichier par fichier** :

| Fichier | chrome `build`→`body:` | `dispose()` | bloc `ZEditionSubmitController` | total |
|---|---:|---:|---:|---:|
| `ai_router_zcrud_edition.dart` | 41 | 5 | 12 | 58 |
| `folder_zcrud_edition.dart` | 30 | 10 | 12 | 52 |
| `exam_zcrud_edition.dart` | 30 | 6 | 12 | 48 |
| `subject_zcrud_edition.dart` | 25 | 7 | 13 | 45 |
| `valuation_tool_model_zcrud_edition.dart` | 23 | 5 | 21 | 49 |
| `smartnote_zcrud_edition.dart` | 23 | 5 | 21 | 49 |
| `folder_document_zcrud_edition.dart` | 25 | 5 | 9 | 39 |
| `ai_base_url_zcrud_edition.dart` | 25 | 5 | 9 | 39 |
| `flashcard_tag_zcrud_edition.dart` | 25 | 5 | 9 | 39 |
| `mindmap_zcrud_edition.dart` | 29 | 5 | 12 | 46 |
| `flashcard_edition_zcrud.dart` | 21 | 5 | 12 | **38** |
| `test_exam_filter_zcrud_screen.dart` | 18 | 5 | 9 | **32** |
| **Total** | **294** | **68** | **151** | **534** |

> Les deux dernières lignes (**70 l.**) manquaient au premier jet de ce document : le croisement
> avait été fait sur le suffixe `*_zcrud_edition.dart`, qui laisse échapper
> `test_exam_filter_zcrud_screen.dart` (suffixe `_screen`) et `flashcard_edition_zcrud.dart`
> (ordre inversé). Les deux portent le motif **à l'identique** —
> `flashcard_edition_zcrud.dart:449/463/478/492/493/500/511` et
> `test_exam_filter_zcrud_screen.dart:314/331/343/349/353/354/360/370`. La méthode de mesure a été
> validée en la rejouant sur `folder_zcrud_edition.dart` : elle rend 30/10/12 = 52, exactement le
> chiffre du tableau.

⚠️ **Ce qu'il faut savoir avant** : `presentFormEdition` **n'a pas de crochet de sortie**
(`beforeSubmit` n'existe que sur `ZCrudScreen` — grep négatif en § 3, L3). Les 10 fichiers devront
appliquer leur `adapt…ZcrudOutput` **au site d'appel**, sur la map rendue. C'est exactement ce que
font déjà les 16 fichiers migrés.

### M2 — 823 lignes d'adaptateur Firestore réécrites 6 fois, à 95,6 % identiques

**API** : `FirebaseZRepositoryImpl<T extends ZEntity>` —
`zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:156`, constructeur `:159`.

**Preuve de corps** : le constructeur prend `fromMap` / `toMap` **en paramètres** (`:163-164`) —
aucun `ZcrudRegistry` requis (`fromRegistry` `:261` n'est qu'une fabrique parmi deux). Il expose
aussi `omitNullFields` (`:168`, retrait récursif des nulls), `timestampFields` (`:167`, avec
soustraction **exécutoire** des clés réservées `:203-206`), `deletionSemantics` (`:169`) et
`legacyDeletedKey` (`:170`).

**Site hôte** : chacun des 6 `iffd/lib/src/data/repositories/z_backed_*_repository.dart` déclare
son propre `FirestoreZ…DataPath` :

| Fichier | bloc | lignes |
|---|---|---:|
| `z_backed_exam_repository.dart` | `:474-610` | 137 |
| `z_backed_flashcard_repository.dart` | `:373-509` | 137 |
| `z_backed_folder_document_repository.dart` | `:312-448` | 137 |
| `z_backed_folder_repository.dart` | `:379-516` | 138 |
| `z_backed_mindmap_repository.dart` | `:409-545` | 137 |
| `z_backed_smart_note_repository.dart` | `:272-408` | 137 |
| **Total** | | **823** |

**La duplication est mesurée, pas estimée** :
```
$ diff <(sed -n '474,610p' z_backed_exam_repository.dart) \
       <(sed -n '272,408p' z_backed_smart_note_repository.dart) | grep -c '^[<>]'
12          # 6 lignes changées sur 137 → 131/137 identiques = 95,6 %
```
Les 6 lignes qui diffèrent : le nom de la classe, celui du port, `kDefaultCollection`, et trois
références au `Mapper` de l'entité.

**Et ce que ces 823 lignes font est exactement ce que le socle fait déjà.** Comparaison ligne à
ligne (`z_backed_smart_note_repository.dart:363-407` contre le port `ZRepository`,
`zcrud_core/lib/src/domain/ports/z_repository.dart:114`) :

| Méthode hôte | Ligne hôte | Canal socle | Ligne socle |
|---|---|---|---|
| `streamAll()` | `:338` | `ZRepository.watchAll()` | `z_repository.dart:125` |
| `streamOne(id)` | `:346` | `ZRepository.watch(request)` | `:134` |
| `streamByIds(ids)` | `:356` | `ZDataRequest(filters: [ZFilter(op: ZFilterOp.isIn, …)])` | `z_data_request.dart:104`, `ZFilterOp.isIn` `:38` |
| `asyncCount()` | `:363` | `ZRepository.count({request})` | `:197` |
| `put(canonical, merge:)` | `:371` | `ZRepository.save(item, {collectionId})` | `:179` |
| `softDelete(id)` | `:388` | `ZRepository.softDelete(id)` | `:185` |
| `restore(id)` | `:397` | `ZRepository.restore(id)` | `:189` |
| `hardDelete(id)` | `:406` | ⚠️ **aucun** — cf. § 3, L1 | — |

**Le point décisif** : le `put` de l'hôte écrit `ZSyncMeta.kUpdatedAt` en ISO-8601 UTC et
`putIfAbsent(ZSyncMeta.kIsDeleted, () => false)` (`:376-378`) ; ses lectures filtrent
`.where(ZSyncMeta.kIsDeleted, isNotEqualTo: true)` (`:364`). C'est **mot pour mot** la sémantique
`ZDeletionSemantics.strict` du socle (`firebase_z_repository_impl.dart:63`) — le défaut. Le piège
P1 du catalogue « données-transverse » (un parc legacy non backfillé rendrait une collection vide)
**ne s'applique donc pas ici** : l'hôte backfille déjà à l'écriture. C'est ce qui rend la
substitution sûre, et il fallait le vérifier avant de la proposer.

**Type d'entité** : `zcrud_note` est déjà en `dependencies` et
`packages/zcrud_note/lib/src/domain/z_smart_note.dart:78` déclare
`class ZSmartNote extends ZEntity with ZExtensible` avec `fromMap` (`:124`) et `toMap`. Les six
mappers de l'hôte construisent **déjà** ces entités typées (dartdoc
`z_backed_smart_note_repository.dart:12-23`).

**Lignes supprimées : 823**, moins un reliquat pour `hardDelete` (§ 3, L1). Les
`ZBacked…Mapper` — la vraie valeur métier — **restent** : ce sont eux qui portent le doublage
`extra['iffd_content']` et les conversions legacy.

### M3 — 2 604 lignes de (dé)sérialisation écrites à la main

**API** : `@ZcrudModel` / `@ZcrudField` / `@ZcrudId` / `@ZcrudIgnore`
(`zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart:151`,
`zcrud_field.dart:52` — 18 paramètres, `zcrud_id.dart:16`, `zcrud_ignore.dart:62`) +
`zcrudModelBuilder` (`zcrud_generator/lib/builder.dart:19`, générateur
`src/zcrud_model_generator.dart`, 1 619 LOC).

**Preuve de corps** : le générateur émet `_$XxxFromMap` (décodage **défensif** : champ absent →
`defaultValue`, enum inconnu → repli, sous-objet corrompu → n'échoue jamais le parent —
`zcrud_model_generator.dart:7-10`), `extension XxxZcrud on Xxx` portant `toMap()` + `copyWith()` à
sentinelle (`:11-13`, émission `:978`), **`$XxxFieldSpecs`** (`:14-15`), `registerXxx(ZcrudRegistry)`
(`:16-17`, émission `:1184`/`:1208`) et `$XxxTimestampFields` (`:55-59`, émission `:1237`).

**Preuve d'absence côté hôte** :
```
$ cd /home/zakarius/DEV/iffd
$ grep -rn '@ZcrudModel' lib ; echo "RC=$?"          → RC=1
$ grep -rn 'ZcrudRegistry' lib | wc -l               → 0
$ grep -n 'zcrud_generator' pubspec.yaml ; echo "RC=$?" → RC=1
$ grep -rn 'JsonSerializable' lib | wc -l            → 0
```

**Coût actuel mesuré** (comptage par accolades sur `iffd/lib/src/domain/`) :

| Bloc | n | lignes |
|---|---:|---:|
| `Map<String, dynamic> toMap()` | 39 | **525** |
| `factory Xxx.fromMap(…)` | 38 | **1 128** |
| `copyWith(…)` | 39 | **951** |
| **Total** | **116** | **2 604** |

Plus le routage type → fabrique écrit à la main : `T fromMap<T>(Map)` avec 23 entrées,
`iffd/lib/src/utils/functions/data_functions.dart:314` (fichier de 515 l) — c'est le
`ZcrudRegistry` (`zcrud_core/lib/src/domain/registry/`).

**Ce qui rend l'adoption réaliste** :
1. `build_runner: ^2.15.1` est **déjà** au `pubspec.yaml:539` — la plomberie existe.
2. Le contrat cassant du générateur exige une factory de domaine `Xxx.fromMap(Map<String,dynamic>)`
   (`zcrud_generator/CHANGELOG.md:154-166`) : l'hôte en a **38**.
3. Cinq dépôts hôtes **recopient déjà à la main** les clés de schéma en commentaire `@ZcrudField`
   (`z_backed_folder_document_repository.dart:17,106`, `z_backed_exam_repository.dart:20,151`,
   `z_backed_flashcard_repository.dart:20,134`, `z_backed_folder_repository.dart:21,156`,
   `z_backed_smart_note_repository.dart:18,109`).

⚠️ **Bornes de la promesse.** (a) `copyWith` et `toMap` disparaissent entièrement (**1 476 l**) ;
les `fromMap` gardent une factory mince appelant `_$XxxFromMap`, le reliquat est donc inférieur à
1 128. (b) `props` / `operator ==` restent à `DynamicModel`
(`iffd/lib/src/domain/models/dynamic_model.dart:19-33`), le générateur ne les émet pas. (c) Un champ
de type `Map` sans branche de classification fait **lever le générateur**
(`zcrud_field_extras/lib/zcrud_field_extras.dart:28-35`) : les modèles à carte (`questionsCounts`,
`permissions`) sont à traiter à part.

### M4 — 8 dialogues d'actions : 53 `ListTile` réécrits — et l'hôte a **déjà** adopté le canal ailleurs

**API** : `ZMenuEntry` (`zcrud_menu/lib/src/domain/z_menu_entry.dart:36`) +
`zVisibleMenuEntries` (`:194`) + `ZMenuEntryTile` (`zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart:31`).
Les trois sont exportés par le barrel (`zcrud_menu/lib/zcrud_menu.dart:45-55`), et
**`zcrud_menu` est déjà en `dependencies`**.

🔴 **Rectification — l'hôte ne l'ignore PAS, il l'a déjà adopté sur un site.**
`iffd/lib/src/presentation/features/folders/zcrud/folder_actions_menu_zcrud.dart` importe
`ZMenuEntryTile` (`:36`), l'instancie (`:215`) et pose sa grille par
`ZMenuEntryTile.gridDelegate(crossAxisCount:, mainAxisExtent: 72)` (`:209`), en alimentant chaque
tuile par `a.toMenuEntry()` — la conversion offerte par le socle
(`zcrud_study/lib/src/presentation/z_item_actions_menu.dart:246`, sur `ZItemAction` `:147`). Il
consomme même la règle d'absence (`.toMenuEntry().isVisible`, `:239`).

Le grep de la § 0.1 rendait 0 pour `ZMenuEntry` parce qu'il cherchait le **type nu**, jamais nommé
ici : l'hôte passe par `toMenuEntry()` et `ZMenuEntryTile`. C'est une correction qui **renforce**
la ligne au lieu de l'affaiblir — le patron n'est pas une hypothèse, il tourne déjà chez l'hôte,
et son propre commentaire (`:189-198`) explique ce qu'il a corrigé au passage : libellé annoncé
deux fois, cibles sous 48 dp. **Ce qui reste à migrer, ce sont les 8 dialogues d'actions**, restés
en `ListTile` brut.

**Preuve de corps** : `ZMenuEntry` porte `id` `:80`, `label` `:81`, `icon` `:87`, `onSelected` `:90`,
`disabledReason` `:93`, `isDestructive` `:96`, `permitted` `:99` ; la règle d'absence est calculée
par `isVisible => permitted && (onSelected != null || disabledReason != null)` (`:103-104`) et
appliquée en **un seul site** (`zVisibleMenuEntries`, `:194-195`). `ZMenuEntryTile` prend
`entry`, `onSelected`, `direction` (`:44-48`), ancre `kZMenuMinTapTarget = 48.0` (`:27`) et se
monte **hors de tout menu** — `onSelected: null` ⇒ aucun détecteur posé (`:38-40`), donc utilisable
dans une `Column` de feuille modale comme le fait l'hôte.

**Site hôte** — le patron, quasi ligne à ligne dans 8 fichiers :
```dart
// iffd/…/subjects/widgets/subject_actions_dialog_widget.dart:34-48
ListTile(
  title: const Text("Modifier"),
  leading: const Icon(Icons.edit_outlined),
  onTap: acl?.update != true ? null : () async { … },
),
ListTile(
  title: const Text("Supprimer le module",
      style: TextStyle(color: Colors.red)),      // ← couleur en dur
  leading: const Icon(Icons.delete_outline, color: Colors.red),
  onTap: acl?.delete != true ? null : () { … },
),
```

| Fichier | lignes | `ListTile(` |
|---|---:|---:|
| `documents/widgets/folder_documents_actions_dialog_widget.dart` | 1 804 | 22 |
| `valuation_tools/widgets/valuation_tool_model_actions_dialog_widget.dart` | 823 | 7 |
| `smartnotes/widgets/smartnote_actions_dialog_widget.dart` | 417 | 6 |
| `folders/dialogs/folder_actions_dialog_widget.dart` | 186 | 7 |
| `flashcards/widgets/flashcard_actions_dialog_widget.dart` | 126 | 5 |
| `administration/widgets/exam_actions_dialog_widget.dart` | 76 | 2 |
| `subjects/widgets/subject_actions_dialog_widget.dart` | 66 | 2 |
| `administration/widgets/app_user_role_actions_dialog_widget.dart` | 56 | 2 |
| **Total** | **3 554** | **53** |

**Ce que l'adoption apporte, au-delà des lignes** : `isDestructive` remplace `Colors.red` en dur
(FR-26) ; `permitted: false` **retire** l'entrée là où l'hôte la laisse visible et morte
(`onTap: null` — un geste refusé reste affiché sans motif) ; `disabledReason` donne le motif
**annoncé** (AD-13) quand on veut la garder visible ; le plancher de 48 dp devient structurel.

**Lignes — mesurées, et il faut distinguer deux choses.** Les 53 blocs `ListTile(` s'étendent au
total sur **1 586 lignes** (comptage par équilibrage d'accolades, par fichier) :

| Fichier | `ListTile` | lignes de bloc |
|---|---:|---:|
| `folder_documents_actions_dialog_widget.dart` | 22 | 724 |
| `valuation_tool_model_actions_dialog_widget.dart` | 7 | 368 |
| `smartnote_actions_dialog_widget.dart` | 6 | 275 |
| `folder_actions_dialog_widget.dart` | 7 | 101 |
| `flashcard_actions_dialog_widget.dart` | 5 | 41 |
| `exam_actions_dialog_widget.dart` | 2 | 28 |
| `subject_actions_dialog_widget.dart` | 2 | 27 |
| `app_user_role_actions_dialog_widget.dart` | 2 | 22 |
| **Total** | **53** | **1 586** |

⚠️ **Ces 1 586 lignes ne sont PAS le gain.** L'essentiel est constitué des **corps de rappel**
(`onTap:`) — la logique métier, qui **reste**. Ce que `ZMenuEntryTile` absorbe, c'est
l'**échafaudage** de chaque tuile : `ListTile(`, `title: Text(...)`, `leading: Icon(...)`, la garde
`onTap: acl?.x != true ? null :` et la fermeture — soit ≈ 8 l. par tuile, **≈ 420 l.**
Le gain retenu au récapitulatif est donc **≈ 420**, et c'est bien le seul chiffre estimé de ce
document ; les 1 586 sont l'**empan mesuré**, donné pour que personne ne confonde les deux.

### M5 — 25 `AlertDialog` bruts sans contrat de retour

**API** : `showZConfirmDialog` (`zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:129`) +
`ZConfirmDialog` (`:36`) + `ZConfirmTone` (`domain/z_confirm_tone.dart:12`).
**`zcrud_ui_kit` est déjà en `dependencies`.**

**Preuve de corps** : `showZConfirmDialog` rend `Future<bool>` et **replie sur `false`** au barrier
ou à un pop sans valeur (`return result ?? false;` `:147`) ; les libellés viennent de
`MaterialLocalizations` (`:74-75`) ; la couleur de confirmation est dérivée du `ColorScheme` selon
la tonalité (`:68-72`) ; `title: null` retire le titre **et** enveloppe le tout d'un
`Semantics(scopesRoute, namesRoute)` (`:105-113`) ; aucun gestionnaire d'état (AD-2).

**Site hôte** : **25 occurrences de `AlertDialog(` sur 18 fichiers**, plus
`buildDeleteConfirmation` (`forms_utils.dart:363`, 2 sites seulement) et 21 fichiers portant un
libellé « Voulez-vous / Êtes-vous » écrit à la main.

⚠️ **Ce qui n'est PAS migrable ici, et il faut le dire** : `buildConfirmDialog`
(`forms_utils.dart:480`, **34 sites d'appel** — 38 occurrences dont la définition et les imports) est une confirmation **de marque** — pastille
64×64 à dégradé, `Icons.help_outline_rounded`, titre « Confirmation », deux boutons `InkWell`
peints. `ZConfirmDialog` n'a **aucun slot pour cela** :
```
$ grep -in 'icon\|gradient\|leading\|Widget? ' packages/zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart
RC=1                       # aucune ligne
$ grep -n 'this\.' …/z_confirm_dialog.dart
42: this.title   43: required this.message   44: this.confirmLabel
45: this.cancelLabel   46: this.tone = ZConfirmTone.neutral
```
⇒ M5 porte sur les **25 `AlertDialog` bruts**, pas sur les 36 `buildConfirmDialog`. Le slot
manquant est en § 3, L4.

### M6 — 133 `StreamBuilder`, 5 rendus d'erreur

**API** : `ZContentStateView` (`zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:180`) +
`ZContentState` (`domain/z_content_state.dart:13`) + `ZEmptyState` (`:31`) / `ZLoadingState` (`:75`) /
`ZErrorState` (`:127`).

**Preuve de corps** : `ZContentStateView.build` (`:215-229`) est un `switch` **exhaustif sans
`default`** sur les 5 états, à replis sûrs (`loading` → `const ZLoadingState()`, les autres →
`SizedBox.shrink()`) ; `successBuilder` est requis (`:186`). `ZEmptyState` exige un `message`
(`:33`) — l'icône n'est jamais le seul canal (AD-13) et les couleurs sortent du `ColorScheme`
(`:60`).

**Site hôte** — le trou est chiffré :
```
$ grep -rn 'StreamBuilder' lib | wc -l        → 133   (51 fichiers)
$ grep -rn 'snapshot.hasError' lib | wc -l    →   5   (4 fichiers)
$ grep -rn 'CircularProgressIndicator' lib | wc -l → 49 (30 fichiers)
```
**128 `StreamBuilder` sur 133 ne rendent aucune erreur.** Ce n'est pas de la duplication à
supprimer : c'est un **défaut à combler**, et le canal existe.

⚠️ `iffd/lib/src/presentation/core/widgets/loading_indicators.dart` (100 l) n'est **pas** un
doublon de `ZLoadingState` : `WrapInProgressIndication` est une surcouche d'opacité et
`FlashcardGenerationIndicator` une animation de couleur en boucle. Cette dernière a un pendant —
`ZColorCycle` (`zcrud_core/lib/src/presentation/theme/z_color_cycle.dart:107`), qui **n'anime pas
sous « Réduire les animations »**, ce que l'hôte ne fait pas.

### M7 — 23 remontages de scope qui **ombrent** le scope racine

**API** : `ZcrudScope.derive(context, {…})` —
`zcrud_core/lib/src/presentation/zcrud_scope.dart:478`.

**Preuve de corps** : `derive` lit `maybeOf(context)` puis appelle `copyWith` avec les 25 seams
(`:509-537`) ; la sentinelle `_zScopeUndefined` (`:46`) distingue « omis » (**hérite**) de `null`
explicite (**remet au repli**) — vérifié sur les 25 branches ternaires `identical(x,
_zScopeUndefined) ? this.x : x as T?` (`:400-452`). Sans scope ambiant, la dérivation part du
scope zéro-config (`:508`).

**Site hôte, et l'hôte le dit lui-même** : le scope racine est **déjà monté** —
`iffd/lib/main.dart:270`, `builder: (context, child) => IffdZcrudScope(child: …)`. Et le
commentaire juste au-dessus (`main.dart:266-268`) écrit :

> « ⚠️ LES SCOPES LOCAUX RESTENT LÉGITIMES : un écran qui déclare ses `relationSources` ou ses
> seams de sous-liste continue de monter le sien, **qui ombre celui-ci pour son sous-arbre**. »

C'est exactement la situation que `derive` supprime. Mesures :
```
$ grep -rn 'ZcrudScope('       lib | wc -l   → 28   (24 fichiers)
$ grep -rn 'ZcrudScope.derive' lib ; echo RC=$?  → RC=1   (0 site)
```
`IffdZcrudScope` construit un `ZcrudScope(` **neuf** (`z_iffd_field_registry.dart:345`) portant
`widgetRegistry`, `theme`, `gradientResolver`, `selectPresenter`, `numberDisplayFormatter`,
`dateDisplayFormatter` : **23 sous-arbres reconstruisent la totalité** pour n'ajouter, le plus
souvent, qu'un `ZRelationSourceRegistry` (`folder_zcrud_edition.dart:519-525`).

**Le correctif est d'UNE ligne** : remplacer `ZcrudScope(` par `ZcrudScope.derive(context,` à
`z_iffd_field_registry.dart:345`. Gain en lignes : quasi nul. Gain réel : les 23 mounts locaux
cessent d'être des vérités concurrentes, et un seam ajouté à la racine atteint désormais tous les
formulaires. L'hôte a **déjà payé cette classe de défaut** — `folder_zcrud_edition.dart:520-525`
consigne que « la casse `ucFirst` a régressé sur les pilotes sans scope au retrait des
re-déclarations (2026-08-24) ».

### M8 — deux effets cross-champ encore câblés en `addListener`

**API** : `ZFieldSpec.derivedFrom` (`z_field_spec.dart:200`) → `ZDerivation`
(`domain/edition/z_derivation.dart:201`).

**Preuve de corps — et elle contredit une affirmation écrite de l'hôte** :
`ZDerivationValueFn` est **`Future<Object?> Function(...)`** (`z_derivation.dart:116`), déclarée
« Toujours `Future` » (`:113`) avec **sérialisation des résolutions asynchrones** par jeton
(`:7`). `ZDerivationOverwrite.always` (`:29`) écrit « inconditionnellement, même si l'utilisateur a
déjà saisi manuellement le champ cible — **parité du comportement legacy** ».

`iffd/…/folders/dialogs/folder_zcrud_edition.dart:472-474` écrit :

> « Le socle n'a pas d'`onChange` déclaratif par champ ; il est donc câblé ICI, sur la tranche. »

La première moitié est vraie (§ 3, L2 : il n'y a pas d'`onChange`). **La conclusion ne l'est pas** :
l'effet — « choisir une matière recopie son titre dans `title` » — est un `ZDerivation` sur `title`,
`sources: ['subjectId']`, `overwrite: always`, `value: (v) async => subjectTitleOf(v['subjectId'])`.
L'hôte l'a d'ailleurs **déjà prouvé ailleurs** : `subject_zcrud_edition.dart:84-92` raconte comment
la cascade d'effacement est passée de listeners à deux `ZDerivation` grâce à la sentinelle
`zUnchanged` (`z_derivation.dart:154`).

**Sites hôtes restants** :

| Site | Ce qui est câblé à la main | lignes |
|---|---|---:|
| `folder_zcrud_edition.dart:476` + `_onSubjectChanged` `:493-503` + `removeListener` `:506-511` | titre du dossier ← titre de la matière | ~40 |
| `exam_zcrud_edition.dart:327` + `class ExamTitleDeriver` `:311-370` | titre de l'examen ← dossier | 60 |
| **Total** | | **~100** |

### M9 — la liste n'est pas portée, et elle n'a **qu'un seul appelant**

C'est la découverte structurante de cette confrontation.

```
$ grep -rn 'DynamicListScreen' lib
lib/agents_screens.dart:176:    return DynamicListScreen<AuditeurIffd>(     ← LE SEUL APPEL
lib/data_crud/dynamic_list_screen.dart:397,487,492,538,541               ← la définition
```

**1 753 lignes de moteur de liste legacy servent un écran.** (`DynamicListField`/`DynamicTab` :
14 déclarations sur 3 fichiers hors `data_crud/`.)

**API** : `ZCrudScreen<T extends ZEntity>` (`zcrud_screen/lib/src/presentation/z_crud_screen.dart:180`,
ctor `:182`, 54 paramètres) + `ZCrudSource.items` (`z_crud_source.dart:109`) +
`ZCrudTitles` (`zcrud_core/lib/src/presentation/z_crud_titles.dart:24`) +
`ZListDataGridLayout` (`zcrud_core/…/z_list_layout.dart:98`) +
`ZSfDataGridRenderer` (`zcrud_list/…/z_sf_data_grid_renderer.dart:133`) injecté par
`ZcrudScope.listRenderer` (`zcrud_scope.dart:208`).

**Correspondance paramètre par paramètre du seul appelant** (`agents_screens.dart:176-201`) :

| Paramètre hôte | Canal socle | `fichier:ligne` |
|---|---|---|
| `title:` | `ZCrudScreen.title` | `z_crud_screen.dart:246` |
| `items: toMapList<AuditeurIffd>(…)` | `ZCrudSource.items(List<T>)` | `z_crud_source.dart:109` |
| `acl:` | `ZCrudScreen.acl` | `:280` |
| `crudTitles: CrudTitles(create:, read:, update:, copy:)` | `ZCrudTitles(create, copy, update, read)` — **les 4 champs, un pour un** | `z_crud_titles.dart:24-42` |
| `tabs:` | `ZCrudScreen.tabs` (+ `tabsStore` pour l'offset par onglet) | `:348`, `:396` |
| `dialog: AppPlatform.isWebOrDesktopOrTablet` | `policy: ZPresentationPolicy` + `formWeight` | `:283`, `:286` |
| `actionButtons: [IconButton…]` | `actions: List<ZAppBarAction>` ou l'échappatoire `appBarActions: List<Widget>` | `:727`, `:782` |
| `listDisplayMode: ListDisplayMode.gridTable` | `layout: const ZListDataGridLayout()` + `ZcrudScope(listRenderer: const ZSfDataGridRenderer())` | `z_list_layout.dart:98`, `zcrud_scope.dart:208` |

**Les quatre conditions d'adoption, toutes vérifiées** :

1. **`zcrud_list` est déclarable** — le blocage Syncfusion est levé (§ 0.3). C'est **la seule
   dépendance neuve** de tout ce document.
2. **`T extends ZEntity` est à un mot-clé** : `ZEntity`
   (`zcrud_core/lib/src/domain/contracts/z_entity.dart:19`) est un **contrat pur** — `String? get id`
   (`:25`) et `bool get isEphemeral => id == null` (`:28`, corps par défaut), aucune sérialisation.
   Or `iffd/lib/src/domain/models/dynamic_model.dart:3-6` déclare déjà
   `abstract class DynamicModel { final String? id; const DynamicModel({this.id}); }`. Faire
   `extends ZEntity` satisfait `id` par le champ et hérite `isEphemeral`. **24 modèles** en
   héritent (`grep -rn 'extends DynamicModel' lib | wc -l` → 24), `AuditeurIffd extends AppUser
   extends DynamicModel` (`app_user.dart:434`, `:37`) compris. Et l'hôte **connaît déjà `ZEntity`**
   (`ai_router_zcrud_edition.dart:58,245`).
3. **Aucun `ZcrudRegistry` n'est requis** — chemin vérifié dans le corps, pas dans la dartdoc :
   `_listFields` accepte `widget.listFields` seul (`z_crud_screen.dart:1334`), `_cellsOf` accepte
   `widget.cellsOf` seul (`:1361`), et l'édition passe par `editionBuilder`
   (`:1622-1645`) — que l'hôte remplit avec ses `presentFormEdition` existants.
4. **Le renderer s'injecte au scope déjà monté** : `IffdZcrudScope` n'a qu'à passer
   `listRenderer: const ZSfDataGridRenderer()`.

⚠️ **Le piège exact, à ne pas manquer** (lu dans le corps, absent des résumés) :

```dart
// z_crud_screen.dart:1401-1407
bool get _formPathAvailable {
    if (widget.editionBuilder != null) return true;
    return widget.registry != null &&        // ← registry, PAS formFields
        _registryKind != null &&
        _formFields != null;
}
```
**Sans registre, `formFields` seul n'ouvre AUCUN formulaire.** La dartdoc du champ le dit
(`:253-254` : « `null` ⇒ `listFields` + `cellsOf` deviennent requis, et l'édition exige
`editionBuilder` »), mais le tableau récapitulatif du catalogue « listes-écrans » résume
`formFields` en « Remplace les champs de formulaire dérivés », ce qui laisse croire l'inverse.
**Pour IFFD : `editionBuilder` est obligatoire.**

**Lignes supprimées : 1 753** (`iffd/lib/data_crud/dynamic_list_screen.dart`), plus
`dynamic_list_field.dart` et la part `DynamicTab`/`DynamicListField` de `data_crud/models.dart`
(`:275-303`).

### M10 — la barre de recherche maison, 14 pages — et le slot de recherche est **déjà** consommé

**API** : `ZPageScaffold` (`zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:46`, 29 champs) ou
`ZPageShellBody` (`z_page_shell_body.dart:36`, sans posséder de `Scaffold`) +
`ZAppBarSearchConfig` (`domain/z_app_bar_search_config.dart:16`) + `ZPageTab`
(`domain/z_page_tab.dart:13`) + `ZAppBarAction` (`domain/z_app_bar_action.dart:15`).

**Site hôte** : `iffd/lib/src/presentation/core/widgets/dynamic_searcheable_app_bar.dart` (372 l),
consommé par **14 pages** — 16 fichiers citent le symbole, moins la définition elle-même et moins
`folder_detail_zcrud.dart:282`, qui ne fait que le **nommer en commentaire** (vérifié :
`grep -n 'DynamicSearcheableAppBar' folder_detail_zcrud.dart` ne rend que cette ligne de `///`).
Les 14 : `folders_page`, `folder_details_page`, `subjects_page`, `subject_details_page`,
`auditeurs_pages`, `ai_experts_page`, `user_role_page`, `dashbord_page`,
`folder_flashcards_list_page`, `public_folders_page`, `public_folders_details_page`, plus
3 écrans `accounting/` (`accounts_by_classe_screen`, `accounts_by_group_screen`,
`select_accounting_account_screen`).

🔴 **Rectification — le slot de recherche du socle est DÉJÀ posé.**
`folder_details_page.dart:844` monte `search: ZAppBarSearchConfig(hintLabel: 'Recherche',
onQueryChanged: …)`, et `folder_detail_zcrud.dart:283` en déclare le champ. Le commentaire d'hôte
qui l'accompagne (`folder_details_page.dart:840-843`) dit exactement ce que ce document soutient :
« ✅ La LOUPE, enfin — le slot `search` du socle existait **depuis le début** ; la vue ne
l'exposait pas. » M10 n'est donc pas un saut dans l'inconnu : c'est l'extension aux 14 pages
restantes d'un canal déjà éprouvé sur une page.

**Couverture mesurée, champ par champ** (`dynamic_searcheable_app_bar.dart:12-22`) :

| Champ hôte | Canal `ZPageScaffold` | Ligne |
|---|---|---|
| `title` | `title` | `:89` |
| `subTitle` | `subtitle` | `:94` |
| `tabs` + `tabsController` | `tabs` (`List<ZPageTab>`) + `tabController` | `:112`, `:157` |
| `actions` | `actions` (`List<ZAppBarAction>`) | `:106` |
| `allowSearching` | `search` (`ZAppBarSearchConfig`) — le shell **détient** l'état | `:109` |
| `baseGradientColor` | `gradientKey` + seam `ZcrudScope.gradientResolver` | `:100` |
| `backgroundColor` | `backgroundColor` | `:185` |
| `bottom` | `aboveTabBar` / `aboveTabBarHeight` | `:139`, `:147` |
| **`actionsBuilder`** | ❌ **aucun** — cf. § 3, L5 | — |
| `controller` (`ListController` hôte) | — (état de l'hôte, reste à lui) | — |

**9 champs sur 11.** ⚠️ Deux pièges avant d'adopter : la **couleur** d'un `TextStyle` passé à
`titleTextStyle`/`tabLabelStyle` est **délibérément ignorée** (`z_page_shell.dart:181` →
`_zMetricsOnly`, justification `:194-203`) ; et `ZPageScaffold` **possède** un `Scaffold` — une page
qui enveloppe déjà le sien doit prendre `ZPageShellBody`.

### M11 — deux réglages de sous-liste livrés et jamais posés

L'hôte consomme largement la vague sous-listes (§ 1, A7) mais laisse deux canaux à zéro :

| Canal | `fichier:ligne` | Sites hôte |
|---|---|---:|
| `ZSubListConfig.summaryColumns` (colonnes typées : `labelKey`, `decimals`, `suffixKey` — `ZSubListSummaryColumn` `z_sub_list_config.dart:509`) | `z_sub_list_config.dart:294` | **0** |
| `ZSubListConfig.itemFormPresentation` (`dialog`/`sheet`/`page`, `ZSubItemFormPresentation` `:130`) | `z_sub_list_config.dart:427` | **0** |

Deux paramètres `const`, sans migration : ils remplacent des `summaryFields` non typés
(arrondi et suffixe alors écrits dans un seam).

### Récapitulatif chiffré des lignes supprimables

| # | Poste | lignes | Nature du chiffre |
|---|---|---:|---|
| M2 | 6 × `FirestoreZ…DataPath` | **823** | mesuré bloc à bloc |
| M3 | `toMap`/`fromMap`/`copyWith` de `lib/src/domain/` | **2 604** | mesuré par comptage d'accolades |
| M1 | chrome + dispose + submit de **12** formulaires | **534** | mesuré bloc à bloc |
| M9 | `dynamic_list_screen.dart` | **1 753** | `wc -l` |
| M8 | 2 dérivations câblées à la main | **~100** | mesuré (60 + ~40) |
| M4 | échafaudage des 53 `ListTile` (empan mesuré : 1 586 l., dont les rappels restent) | **≈ 420** | **estimé** (8 l./tuile) |
| **Total** | | **≈ 6 234** | dont **5 814 mesurés** |

Hors décompte : M5 (25 `AlertDialog`), M6 (128 flux sans rendu d'erreur — du code **à ajouter**),
M7 (1 ligne changée), M10 (372 l. conditionnées au § 3 L5), M11.

---

## 2.bis Ce que la carte annonçait comme migrable et qui ne l'est pas

| Constat repris | Verdict après vérification |
|---|---|
| carte D11 : « `showPushedDialog` → présentation d'écran d'édition du socle » | **DÉJÀ FAIT** — `forms_utils.dart:727` délègue à `presentEdition` depuis un lot antérieur. Reliquat : le repli `Get.context` (`:748`), nommé et assumé par l'hôte |
| catalogue listes-écrans, §D : « Export PDF de flashcards → `ZFlashcardPdfTemplate` » | **NON** — la génération est **DISTANTE** : `export_flashcards_to_pdf.dart:78-88` fait `dio.post("${…baseUrl}${AiRepository.convertFlashcardsToPdfEndpoint}")` et rend des bytes. `ZFlashcardPdfTemplate` génère **localement** : le substituer serait un changement de produit. Seul `ZPdfPreview` (`zcrud_export_ui/…/z_pdf_preview.dart:26`) remplacerait le `PdfPreview` de `printing` (`:104`) — gain marginal, et il retire `printing` par une autre porte |
| catalogue listes-écrans, §C1 : « l'hôte croit `ZAdaptiveGrid.builder` absent » | **Le constat de l'hôte est faux, sa décision reste juste.** `ZAdaptiveGrid.builder` est bien un **constructeur `const` public** (`zcrud_responsive/…/z_adaptive_grid.dart:89`) d'une classe exportée (barrel `:61`). Mais `study_tools_zcrud_adapter.dart:68-71` désactive la virtualisation pour une raison indépendante — corpus ≤ 21 items, et exclusivité avec le réordonnancement. Rien à migrer, une ligne de commentaire à corriger |
| carte D17 : « 180 `ProviderScope.containerOf(...).read(...)` → binding `zcrud_riverpod` » | **NON, pas tel quel.** `ZcrudScope.resolver` sert à ce que **le socle** résolve les dépendances de l'hôte ; il ne remplace pas les lectures que l'hôte fait pour **lui-même**. `zcrud_riverpod` est déclaré et jamais importé (grep négatif ci-dessous), mais son adoption est un chantier d'injection, pas une substitution de canal. Voir § 4, R6 |
| carte D18 : « 300 `try` / 1 `Either<` → contrat AD-5 » | **RESTE À L'HÔTE.** AD-5 gouverne les dépôts **du socle**. Les dépôts d'IFFD sont à IFFD ; `ZFailure` y est déjà présent (18 fichiers) |

```
$ grep -rq --include='*.dart' 'package:zcrud_riverpod' /home/zakarius/DEV/iffd/lib ; echo "RC=$?"
RC=1
$ grep -rq --include='*.dart' 'package:zcrud_list'     /home/zakarius/DEV/iffd/lib ; echo "RC=$?"
RC=1
```

---

## 3. MANQUE AU SOCLE

> Chaque absence porte son **grep négatif montré**.

### L1 — Aucun dépôt Firestore purgeable

**Forme** : le mixin `ZPurgeable<T>` **appliqué** à `FirebaseZRepositoryImpl`, ou une fabrique
`FirebaseZRepositoryImpl.purgeable(...)`.
**Paquet** : `zcrud_firestore`.

```
$ grep -rn 'ZPurgeable' /home/zakarius/DEV/zcrud/packages/zcrud_firestore/lib ; echo "RC=$?"
RC=1
```
Le contrat existe pourtant côté cœur (`zcrud_core/lib/src/domain/ports/z_purgeable.dart`) et
`ZCrudScreen` le consulte par un `is` — sans le mixin, « supprimer définitivement » **n'est pas
construit** (dartdoc `z_purgeable.dart:59-61`).

**Pourquoi l'hôte ne peut pas s'en passer** : ses 6 `FirestoreZ…DataPath` déclarent tous
`Future<void> hardDelete(String id) => _collection.doc(id).delete()`
(ex. `z_backed_smart_note_repository.dart:406`), et le contrat legacy `CrudRepository` expose
`hardDelete` dans ses 18 méthodes. C'est le **seul** des 8 gestes de M2 qui n'a pas de pendant.
**Conséquence chiffrée** : sans ce canal, M2 laisse un reliquat par entité au lieu de supprimer les
823 lignes en bloc.
**Bloque une capacité d'étude ou de révision ?** Non.

### L2 — Aucun effet de bord déclaratif par champ (`onChange`)

**Forme** : soit un `ZFieldSpec.onChanged` (mais il logerait une closure dans une spec `const` —
interdit par AD-3/AD-14), soit, plus probablement, une **sixième cible** `ZDerivation.effect`
n'écrivant dans **aucune** tranche mais notifiant l'hôte.
**Paquet** : `zcrud_core`.

```
$ cd /home/zakarius/DEV/zcrud/packages/zcrud_core/lib/src
$ grep -n 'onChange' domain/edition/z_field_spec.dart ; echo "RC=$?"
RC=1
$ grep -rn 'onChange' domain/edition/ | grep -v 'onChanged' ; echo "RC=$?"
RC=1
```
(`onChanged` existe, mais c'est le rappel d'écriture d'un **widget** —
`z_widget_registry.dart:142` — pas une déclaration de spec.)

**Pourquoi l'hôte ne peut pas s'en passer** : nuance importante — **il le peut pour ses deux cas
actuels** (§ 2, M8 : `ZDerivation` avec `value` asynchrone les couvre). Le manque est **résiduel** :
il porte sur un effet qui n'écrit dans **aucune** tranche du formulaire (journaliser, appeler un
service, notifier un contrôleur externe). L'hôte n'en a pas d'exemple mesuré aujourd'hui — je le
consigne comme **manque de complétude**, pas comme blocage.
**Bloque une capacité d'étude ou de révision ?** Non.

### L3 — `beforeSubmit` n'existe que sur `ZCrudScreen`

**Forme** : le même paramètre `beforeSubmit` (typedef `ZCrudBeforeSubmit`) relayé par
`presentFormEdition`, appliqué à la map validée avant qu'elle ne soit rendue à l'appelant.
**Paquet** : `zcrud_screen`.

```
$ cd /home/zakarius/DEV/zcrud/packages
$ grep -rn 'beforeSubmit' --include='*.dart' */lib | grep -v '^zcrud_screen' ; echo "RC=$?"
RC=1
$ grep -n 'beforeSubmit' zcrud_screen/lib/src/presentation/present_form_edition.dart ; echo "RC=$?"
RC=1
```

**Pourquoi l'hôte ne peut pas s'en passer** : c'est le **canal dont il a le plus besoin et qu'il
n'a pas**. `presentFormEdition` est consommé par **29 fichiers** ; l'adaptation de la map de sortie
y est faite au site d'appel, en **17 fonctions `Map<String, dynamic> adapt…Zcrud…`** réparties sur
16 fichiers et **mesurées à 460 lignes** :

```
ai_router_zcrud_edition.dart:590 = 59 l.   ·  subject_zcrud_edition.dart:471 = 43 l.
ai_base_url_zcrud_edition.dart:148 = 38 l. ·  exam_zcrud_edition.dart:221 = 37 l.
folder_zcrud_edition.dart:333 = 35 l.      ·  mindmap_…:160 = 32 l.  ·  flashcard_edition_zcrud.dart:548 = 32 l.
test_exam_filter_zcrud_screen.dart:209 = 29 l. · flashcard_tag_…:117 = 27 l. · ai_router_…:662 = 24 l.
valuation_tool_model_…:202 = 20 l. · smartnote_…:192 = 20 l. · folder_flashcards_filter_…:628 = 18 l.
folder_document_…:102 = 13 l. · annee_accademique_…:218 = 12 l. · flashcards_questions_count_…:215 = 12 l.
agents_filter_zcrud_edition.dart:210 = 9 l.
```
Ces 460 lignes ne disparaîtraient pas avec `beforeSubmit` — la transformation resterait à écrire —
mais elles cesseraient d'être **répétées au site d'appel** et deviendraient une propriété de la
surface, comme elles le sont déjà sur `ZCrudScreen`. L'asymétrie est arbitraire : `ZCrudScreen`
l'a reçu en v3.14.0 (`z_crud_screen.dart:671`) et l'hôte le sait déjà
(`iffd/pubspec.yaml:512-515` le nomme comme « ce qui débloque CR-IFFD-103 »), mais il ne l'atteint
pas depuis la surface qu'il utilise réellement.
**Bloque une capacité d'étude ou de révision ?** Non.

### L4 — La confirmation du socle n'a aucun slot d'habillage

**Forme** : trois paramètres additifs sur `ZConfirmDialog` — `icon` (`IconData?`),
`iconDecoration`/`gradientKey`, et un slot `Widget? header` — tous `null` par défaut (rendu
strictement inchangé).
**Paquet** : `zcrud_ui_kit`.

```
$ grep -in 'icon\|gradient\|leading\|Widget? ' packages/zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart
RC=1
```
Les 5 seuls champs sont `title`, `message`, `confirmLabel`, `cancelLabel`, `tone` (`:42-46`).

**Pourquoi l'hôte ne peut pas s'en passer** : `buildConfirmDialog` (`forms_utils.dart:480-…`) est
appelé **36 fois sur 20 fichiers** et rend une confirmation de marque (pastille 64×64 à dégradé,
`Icons.help_outline_rounded`, titre, deux boutons peints). Sans slot, adopter
`showZConfirmDialog` **change le rendu de 36 dialogues** — l'hôte ne le fera pas, et il aura
raison. Sans ce canal, M5 reste borné aux 25 `AlertDialog` bruts au lieu de couvrir les 61 sites.
**Bloque une capacité d'étude ou de révision ?** Non.

### L5 — `ZPageScaffold` n'accepte pas d'actions dépendantes de l'état

**Forme** : un `actionsBuilder` sur `ZPageScaffold`/`ZPageShellBody`, rendant des `ZAppBarAction`
et non des widgets — le pendant de `ZAppBarActionsBuilder`
(`zcrud_screen/lib/src/presentation/z_app_bar_actions_builder.dart:55`), mais dont le contexte
serait celui du shell (recherche active, onglet courant) et non celui d'un écran CRUD.
**Paquet** : `zcrud_ui_kit`.

```
$ grep -rn 'actionsBuilder\|ZAppBarActionsBuilder' /home/zakarius/DEV/zcrud/packages/zcrud_ui_kit/lib
RC=1
```
`ZPageScaffold` n'a que `actions` (`List<ZAppBarAction>` statique, `z_page_scaffold.dart:106`).

**Pourquoi l'hôte ne peut pas s'en passer** : `DynamicSearcheableAppBar` déclare
`final List<Widget> Function(ListController controller)? actionsBuilder`
(`dynamic_searcheable_app_bar.dart:16`) — les actions de ses 15 pages dépendent de l'état de
recherche et de la sélection. Sans ce canal, M10 exige de remonter cet état chez l'appelant page
par page, et l'hôte devra passer par l'échappatoire `appBarActions` (widgets bruts), ce qui lui
fait perdre libellé, sémantique et cible tactile garantis.
**Bloque une capacité d'étude ou de révision ?** Non — mais c'est le manque qui **conditionne le
plus grand nombre d'écrans** (15).

### L6 — Une option de `select` ne peut pas porter sa propre sous-valeur

**Forme** : soit un `ZSelectChoiceContext` étendu d'un couple lecture/écriture par option
(`Object? subValue` + `ValueChanged<Object?> setSubValue`), soit un type de champ « matrice »
(`Map<clé, List<valeur>>`) déclaré au cœur.
**Paquet** : `zcrud_core`.

**Preuve** — le contexte servi au builder d'option n'a que quatre membres, et le dit :
```dart
// zcrud_core/lib/src/presentation/edition/z_select_presenter.dart:71-92
class ZSelectChoiceContext {
  const ZSelectChoiceContext({required this.choice, required this.selected,
                              required this.enabled, required this.select});
  final ZFieldChoice choice;  final bool selected;  final bool enabled;
  /// Sélectionne/désélectionne l'option. Le builder **notifie** — il n'a
  /// jamais accès au `ZFormController` (invariant AD-2).
  final ValueChanged<bool> select;
}
```

**Pourquoi l'hôte ne peut pas s'en passer** : sa matrice d'autorisations est exactement ce motif —
un select multiple de ressources où **chaque ressource cochée** porte son jeu d'opérations, valeur
`{ressource: [opérations]}`. L'hôte a dû faire **posséder la tranche à son propre widget** et monter
`ZSelectFieldWidget` à l'intérieur (`z_iffd_acl_matrix_field.dart`, 262 l — l'analyse est écrite
`:26-41`, et elle est juste). Ce n'est **pas un blocage** : la composition marche, sur des
primitives publiques. C'est un manque de **déclarativité** (objectif produit n°2) — le motif
« clé → sous-sélection » est général, pas propre à IFFD.
**Bloque une capacité d'étude ou de révision ?** Non.

### L7 — Aucune implémentation de `ZNumberDisplayFormatter`

**Forme** : `ZIntlNumberDisplayFormatter`, pendant exact de `ZIntlDateDisplayFormatter`
(`zcrud_intl/lib/src/presentation/z_intl_date_formatter.dart:125`), derrière une **entrée
séparée** comme lui (`zcrud_intl/lib/date_formatter.dart:25`) pour ne pas imposer les données CLDR.
**Paquet** : `zcrud_intl`.

```
$ grep -rn 'implements ZNumberDisplayFormatter\|extends ZNumberDisplayFormatter' \
     --include='*.dart' /home/zakarius/DEV/zcrud/packages/*/lib ; echo "RC=$?"
RC=1
```
Le port existe (`zcrud_core/lib/src/domain/ports/z_number_display_formatter.dart:43`, seam
`zcrud_scope.dart:308`) et sans injection le nombre sort **au rendu inchangé**.

**Pourquoi l'hôte ne peut pas s'en passer** : il a dû écrire le sien —
`IffdNumberDisplayFormatter` (`z_iffd_field_registry.dart:418`), à côté de
`IffdDateDisplayFormatter` (`:446`) qui, lui, doublonne un canal livré. Coût faible, mais c'est un
port livré sans sa pièce d'usage courant.
**Bloque une capacité d'étude ou de révision ?** Non.

### L8 — Pas de composeur de champs hors du binding GetX

**Forme** : `registerZcrudFormFields` remonté dans un paquet neutre (ou dupliqué côté
`zcrud_riverpod`).
**Paquet** : `zcrud_core` (ou un `zcrud_fields` neuf) — aujourd'hui `zcrud_get`.

```
$ grep -rn 'registerZ.*Fields\|FormFieldsComposer' --include='*.dart' \
     packages/zcrud_riverpod/lib packages/zcrud_provider/lib ; echo "RC=$?"
RC=1
$ grep -rn 'registerZcrudFormFields' --include='*.dart' packages/*/lib
packages/zcrud_get/lib/zcrud_get.dart:30                              (commentaire de barrel)
packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart:5,76
```
Le corps de `z_form_fields_composer.dart:76` n'utilise que `ZWidgetRegistry` + markdown/intl/geo —
rien de GetX. Un hôte Riverpod qui le voudrait paierait `get ^4.7.2`, `get_it ^9.0.0` et
`reflectable ^5.2.3`.

**Pourquoi l'hôte ne peut pas s'en passer** : IFFD, hôte **Riverpod**, écrit son propre registre —
`z_iffd_field_registry.dart` (461 l), avec `registerZMarkdownFields` (6 occ),
`registerZFlashcardEditors` (3), `registerZHtmlFields` (1) enchaînés à la main. Le point de
composition unique existe, il est simplement domicilié chez le concurrent.
**Bloque une capacité d'étude ou de révision ?** Non.

---

### L9 — Le tableau markdown rendu a une géométrie fermée (CR-IFFD-114)

**Forme** : un slot de tableau dans `ZRichTextStyleSet` (largeur de colonne + défilement
horizontal), **ou** l'ouverture de la liste d'embeds — `kZEmbedBuilders` exporté et surchargeable
par montage. La seconde forme est la plus générale ; la première suffit au besoin mesuré.
**Paquet** : `zcrud_markdown`.

```
$ cd /home/zakarius/DEV/zcrud/packages
$ grep -n 'defaultColumnWidth' zcrud_markdown/lib/src/presentation/z_table_embed.dart
187:      defaultColumnWidth: const IntrinsicColumnWidth(),      # en dur
$ grep -n 'SingleChildScrollView' zcrud_markdown/lib/src/presentation/z_table_embed.dart
544: · 572:      # les DEUX sont dans le dialogue d'ÉDITION, aucune dans le rendu
$ grep -n 'kZEmbedBuilders\|EmbedBuilder' zcrud_markdown/lib/zcrud_markdown.dart
49:// (commentaire seulement — le symbole n'est PAS exporté)
```
`kZEmbedBuilders` est une `const List<EmbedBuilder>` de `z_rich_text_core.dart:57`, câblée en dur
aux trois montages (`z_markdown_reader.dart:432`, `z_markdown_field.dart:933`,
`z_rich_text_fullscreen_dialog.dart:221`) et absente du barrel : un hôte ne peut pas substituer le
constructeur de tableau.

**Pourquoi l'hôte ne peut pas s'en passer** : le lecteur legacy pose, **par défaut**,
`MinColumnWidth(IntrinsicColumnWidth(), FlexColumnWidth())`
(`iffd/lib/data_crud/rich_text_editor_screen.dart:657-661`) — chaque colonne est flex à intrinsèque
nulle, donc la table tient la largeur offerte et le texte se replie. Avec `IntrinsicColumnWidth()`
seul et sans défilement, un tableau large **déborde**. Les quatre échappatoires d'hôte ont été
essayées et mesurées inertes par le pilote (`ZRichTextStyleSet`, `ZcrudTheme`, `ZTableCellScope`,
substitution d'`EmbedBuilder`).
**Bloque une capacité d'étude ou de révision ?** **Oui, indirectement** : le tableau est un support
de cours courant, et il est rendu par ce chemin unique dans le lecteur d'explications IA
(`ai_explanation_zcrud_reader.dart`) comme dans les notes.

### L10 — Le retour à la ligne souple n'est pas déclarable (CR-IFFD-115)

**Forme** : un `softLineBreak` (défaut `false`, comportement actuel **inchangé**) sur
`ZMarkdownCodec`, conditionnant l'enregistrement de `_ZSoftLineBreakSyntax`.
**Paquet** : `zcrud_markdown`.

```
$ grep -rn 'softLineBreak' --include='*.dart' /home/zakarius/DEV/zcrud/packages/*/lib ; echo "RC=$?"
RC=1                       # 0 occurrence dans les 41 paquets
```
`_ZSoftLineBreakSyntax` (`z_markdown_codec.dart:283-297`) fait `parser.addNode(md.Text(' '))` et est
enregistrée **inconditionnellement** (`:509`) ; le seul réglage de `ZMarkdownCodec` est `bridges`
(`:404-406`). Le sort du retour se joue au **décodage** : aucun paramètre de rendu ne le rattrape
après coup.

**Pourquoi l'hôte ne peut pas s'en passer** : son corpus n'est pas écrit par des auteurs markdown —
ce sont des saisies de champ de texte et des sorties de modèle, où Entrée sépare les lignes. Sous la
règle CommonMark, ces lignes se recollent en un pavé. Le lecteur de référence en fait une option
déclarée (`rich_text_editor_screen.dart:578`, défaut `false` `:599`, relayée `:695`).
⚠️ La CR **ne conteste pas** le défaut du socle : recoller est conforme à CommonMark, et la syntaxe
a été posée pour réparer un vrai défaut. C'est la **déclarabilité** qui manque.
**Bloque une capacité d'étude ou de révision ?** **Oui** : les explications générées par l'IA et les
notes de révision sont exactement ce corpus.

### L11 — Le dialogue d'édition plein écran n'a pas de sous-titre (CR-IFFD-116)

**Forme** : un `subtitle: String?` sur `showZRichTextFullscreenDialog` **et** sur
`ZRichTextFullscreenDialog`, rendu sous le titre dans les deux présentations.
**Paquet** : `zcrud_markdown`.

```
$ grep -rn 'subtitle' --include='*.dart' /home/zakarius/DEV/zcrud/packages/zcrud_markdown/lib ; echo "RC=$?"
RC=1                       # 0 occurrence dans tout le paquet
```
La fonction et le widget ne portent qu'un `title: String?` (`:47`, `:82`, `:96`), rendu deux fois
(`:280`/`:289` en plein écran, `:319-336` en dialogue dimensionné).

**Pourquoi l'hôte ne peut pas s'en passer** : un éditeur plein cadre **remplace** l'écran d'où l'on
vient ; il doit porter **sur quoi** on travaille et **quel** champ on édite. L'hôte contourne par
`'$titre — $sousTitre'` (`workflow_notes_zcrud_edition.dart:152-166`) : l'information est préservée,
la hiérarchie typographique perdue. C'est le motif que le socle a déjà accepté pour `ZFolderCard`
(sous-titre logé dans le créneau `counts`, CR-IFFD-28). Le pilote le compte comme la **quatrième
surface** touchée par le même manque.
**Bloque une capacité d'étude ou de révision ?** Non — mais il touche les 2 sites d'édition riche
hors formulaire déjà migrés (§ 1, A16).

---

## 3.bis Quatre CR que l'hôte a RETIRÉES lui-même — le canal existait

Le lot « lecteur riche + éditeur plein écran » (CR-IFFD-114 → 120, registre
`iffd/docs/zcrud-change-requests.md:7589-7910`) contient **sept** entrées, dont **quatre retirées
avant émission** parce que le pilote a trouvé le canal en lisant le socle. Elles appartiennent de
plein droit à la catégorie « migrable aujourd'hui » — et elles y sont déjà **résolues** :

| CR | Ce qui semblait manquer | Le canal réel, vérifié |
|---|---|---|
| **117** | l'encodage à la sortie du dialogue plein écran | le `codec` était déjà un paramètre |
| **118** | `onTapLink` du lecteur | le comportement existe ; seule l'**interception** manque (non demandée) |
| **119** | un `padding:` sur le lecteur | `chrome: ZMarkdownReaderChrome.none` + un `Padding` d'appelant sont l'**équivalence exacte** — l'enum documente cet usage (`z_markdown_reader.dart:51-53`) |
| **120** | forcer la présentation plein cadre | `fullscreen` est un paramètre **public et documenté** (`z_rich_text_fullscreen_dialog.dart:89`), et le widget est exporté par le barrel (`zcrud_markdown.dart:53-54`) — vérifié : `this.fullscreen = false` au constructeur |

**Ce que ce fait vaut pour ce document.** Quatre demandes sur sept se sont dissoutes à la lecture du
code du socle. C'est la mesure directe du coût de l'écart de connaissance que la § 0.1 chiffre à
25 symboles inconnus : le socle en sait plus que l'hôte n'en lit. Deux réserves du pilote méritent
d'être remontées telles quelles, car elles sont justes : le dartdoc de `ZRichTextFullscreenDialog`
la présente comme « exposé pour les tests widget » (`:78`) alors que son paramètre est documenté
comme un vrai réglage ; et le seuil `_kFullscreenBreakpoint` (`:36`) est **privé**, donc un hôte qui
refait le helper fige *sa* valeur au lieu de suivre celle du socle.

---

## 4. RESTE À L'HÔTE — règle métier IFFD

| # | Élément | Volume | Pourquoi le socle ne le porte pas |
|---|---|---:|---|
| R1 | **La matrice d'autorisations par ressource** — `RessourceACL` traverse champ, écran et dialogue d'actions (`acl:` 41 occ, `aclBuilder`) ; valeur `{ressource: [opérations]}` | `z_iffd_acl_matrix_field.dart` 262 l | Le **vocabulaire des ressources et des opérations** est IFFD (objets de base + un par routeur d'IA + six par année académique + une par filière). Le socle porte `ZAcl`/`ZCrudAction`, pas leur remplissage. La primitive manquante côté socle est en § 3, L6 — pas la règle |
| R2 | **Le comptage de questions par type** — répartition QCM / vrai-faux / ouverte / cas pratique alimentant la génération d'examens ; graines divergentes assumées (`ai_models.dart:272-276` vs `flashcard_edition_screen.dart:587-591`) | `z_questions_counts_field.dart` 169 l | « La graine EST une décision de produit » (dartdoc `:23-25`) — et le fichier documente que les deux copies **ont déjà divergé**. C'est une règle métier, correctement factorisée côté hôte sur des sous-listes du socle |
| R3 | **Le booléen `FlutterSwitch`** — décision d'owner du 2026-08-25, citée textuellement dans le fichier (`z_iffd_boolean_field.dart:4-6`) | 140 l | Choix d'**unifier l'application** sur un paquet tiers déjà employé ailleurs (éditeur de flashcards, dialogue de collaborateurs, éditeur multiple). Le socle offre `ZBooleanStyle.pill` peint nativement + 9 jetons `booleanPill*` (`z_theme.dart:2352-2404`) : c'est un **autre** contrôle, pas le même. Le chemin d'adoption est **déjà migré** (le registre, § 1 A9) |
| R4 | **Filières, cycles, année académique** comme axes transverses — `subjectFiliereChoices` dépend d'`accademicYearProvider` : la source de choix d'un champ dépend du **contexte applicatif**, pas de l'état du formulaire | — | Le socle offre le canal (`ZChoicesSourceRegistry`, `ZRelationSourceRegistry`, `conditionContext` de `DynamicEdition:413`) ; le contenu est IFFD |
| R5 | **Le mode `Crud.copy`** avec réattribution d'identifiant (`result["id"] = randomString()`, `subject_model_dialogs.dart:70`) | — | Le socle a la **place** (`ZCrudScreen.canDuplicate:472`, `ZCrudTitles.copy`, `beforeSubmit` avec `original == null`) ; la **politique d'identité** (chaîne aléatoire vs UUID vs compteur) est à l'app |
| R6 | **180 `ProviderScope.containerOf(context).read(...)` sur 55 fichiers** | — | C'est l'injection **de l'hôte pour l'hôte**. `ZcrudScope.resolver` sert au socle pour résoudre les dépendances de l'hôte, pas l'inverse. `ZcrudRiverpodScope` (`zcrud_riverpod/…:40`) reste un chantier d'architecture à part, hors de cette confrontation |
| R7 | **300 `try` / 123 `catch (e` pour 1 `Either<`** | 110 fichiers | AD-5 (`Either<ZFailure,T>`) gouverne les dépôts **du socle**. `ZFailure` est déjà présent chez l'hôte (18 fichiers) ; l'étendre est une décision d'architecture d'IFFD |
| R8 | **La génération PDF distante des flashcards** — `dio.post` vers `AiRepository.convertFlashcardsToPdfEndpoint` | `export_flashcards_to_pdf.dart` 390 l | Décision de produit (le rendu vit au backend). `ZFlashcardPdfTemplate` génère localement : ce serait un changement de produit, pas une migration (§ 2.bis) |
| R9 | **L'échafaudage de bascule** — `zcrudFlagValue` (80 occ / 43 fichiers), `UseZcrudProvider` (229 occ), `UseZcrudDefault` (196 occ), `z_qa_flags.dart` (985 l, **53** `ZQaFlag(` pour **52** `provider:`), `z_flag_gateway.dart` (86 l) | ~1 300 l | Mécanique de **migration**, destinée à disparaître avec elle. À ne surtout pas généraliser : le registre porte une assertion (`z_qa_flags.dart:122-130`) qui **interdit au classement de se contredire**, après s'être déjà contredit. C'est une pratique d'hôte à propager par l'exemple, pas un canal à livrer |
| R10 | **Le module `lib/workflow/`** (agenda, tâches, récurrences) avec sa propre l10n | `appointment_editor.dart` 7 858 l, `recurrence_picker.dart` 1 721 l | Sous-domaine calendaire complet, sans rapport avec le CRUD |
| R11 | **Le menu latéral et sa i18n en 10 langues** | `core/side_menu/` 1 346 l / 15 fichiers | Vestige d'un composant tiers absorbé, dans une application francophone. ⚠️ `ZcrudLocalizationsDelegate.supportedLocales` ne couvre que `en`/`fr` (`z_localizations.dart:413`) : le socle ne pourrait pas le reprendre |

---

## 5. L'ordre que la mesure suggère

Non demandé, mais il tombe des dépendances mesurées :

1. **M7** (1 ligne, `ZcrudScope.derive`) et **M11** (2 paramètres `const`) — sans risque, sans
   dépendance.
2. **M1** (534 l., 12 fichiers) — 16 fichiers frères montrent déjà le patron ; ⚠️ l'adaptateur de sortie
   remonte au site d'appel (§ 3, L3).
3. **M8** (~100 l.) — l'hôte a déjà fait la démonstration sur `subject_zcrud_edition.dart`.
4. **M5** + **M6** — 25 confirmations, et surtout **128 flux qui ne rendent aucune erreur**.
5. **M4** (≈ 420 l.) — bénéfice a11y/ACL supérieur au bénéfice en lignes, et le patron **tourne déjà** chez l'hôte (`folder_actions_menu_zcrud.dart`).
6. **M2** (823 l.) — attend **L1** (`ZPurgeable`) pour être complet.
7. **M3** (2 604 l.) — le plus gros, et le plus long : 116 blocs, 3 bornes en § 2 M3.
8. **M9** (1 753 l.) — la seule dépendance neuve (`zcrud_list`), 4 conditions toutes vérifiées,
   **1 appelant**. ⚠️ `editionBuilder` obligatoire (`z_crud_screen.dart:1401-1407`).
9. **M10** (372 l., 14 pages) — attend **L5** (`actionsBuilder`) ; le slot `search` est déjà
   consommé sur une page (§ 1, A20).

Hors de cette échelle, **L9/L10/L11** (CR-IFFD-114/115/116) ne sont pas des lignes à supprimer mais
des **canaux à livrer côté socle** : ce sont les seuls manques de ce document qui bloquent une
capacité d'étude (L9 et L10 touchent le rendu des contenus de cours et des explications IA).

---

## 6. Limites de ce document

1. **Aucun test n'a été lancé**, dans aucun dépôt. Les propriétés citées viennent des **corps lus**,
   des dartdoc et des CHANGELOG — jamais d'une exécution.
2. Les mesures hôtes portent sur `iffd/lib` seul (ni `test/`, ni `example/`), sur l'arbre de travail
   au 2026-08-26.
3. Un seul chiffre de ce document reste **estimé** : les ≈ 420 lignes d'échafaudage de M4
   (53 tuiles × ≈ 8 l.). Leur **empan** total, lui, est mesuré (1 586 l. par équilibrage
   d'accolades) — les deux ne doivent pas être confondus, l'écart étant constitué des corps de
   rappel, qui restent. Tous les autres chiffres viennent d'un `wc -l`, d'un comptage d'accolades
   ou d'un `diff`.
4. Je n'ai pas ouvert `zcrud_navigation/doc/parameter-matrix-z-adaptive-presenter.md` : la matrice
   d'inertie paramètre × surface de `ZAdaptivePresenter` n'est donc pas vérifiée ici.
5. Le comportement de `ZCrudScreen` **à l'exécution** sur la voie sans registre (M9) est établi par
   lecture de `_listFields`/`_cellsOf`/`_formPathAvailable`/`_openEdition`
   (`z_crud_screen.dart:1332-1407`, `:1615-1650`) — pas par un montage réel.
