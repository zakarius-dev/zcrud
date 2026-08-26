# Confrontation socle ⇄ IFFD — domaine « Socle applicatif »
### Administration · authentification · réglages · accueil · workflow · navigation

Relevé du **2026-08-26**. Socle **v3.21.0** (41 paquets, `/home/zakarius/DEV/zcrud/packages/`).
Hôte `/home/zakarius/DEV/iffd` en **lecture seule**, épinglé `ref: v3.21.0` sur ses 23 paquets zcrud.
Aucun test lancé, dans aucun dépôt. Tout constat repris de la carte ou d'un catalogue a été **remesuré**.

**Convention** : un `fichier:ligne` sans préfixe est relatif à `/home/zakarius/DEV/zcrud/packages/` ;
les chemins hôtes sont préfixés `iffd/`.

## 0. Périmètre remesuré

| | Fich. | Lignes |
|---|---:|---:|
| 9 dossiers du domaine | **109** | **34 684** |
| dont `lib/workflow/` | 38 | 17 417 |
| dont `.../features/administration/` | 22 | 9 430 |
| dont `lib/accounting/` + `lib/cotation/` | 29 | 3 407 |
| dont les 4 dossiers d'auth (2 chemins) | 11 | 2 693 |
| dont `features/{home,admin,settings}` | 9 | 1 737 |

Empreinte zcrud **dans le périmètre** : **12 fichiers** (23 imports `package:zcrud`) —
`zcrud_core` 11, `zcrud_screen` 8, `zcrud_navigation` 2, `zcrud_markdown` 1.
**0** dans `accounting/`, `cotation/`, `features/{home,admin,settings,auth}`.

Densité mesurée sur les 9 dossiers : `setState(` **185**/15 f. · `EdgeInsets.only` **103**/9 f. (⚠️ AD-13) ·
`ListTile(` 76/23 · `IconButton(` 58/21 · `ElevatedButton` 53/8 · `AppUserPermissions` 33/12 ·
`Scaffold(` 29/20 · `showDialog` 26/6 · `ListenableBuilder(` 21/14 · `Divider(` 21/6 · `AppBar(` 20/13 ·
`Timestamp` 19 · `try {` 17/10 · `catch (` 15/8 · `ExpandableFab` 14/3 · `PopScope(` 13/2 ·
`CircularProgressIndicator` 11/8 · `randomString()` 10/8 · `AlertDialog` 9/6 · `AutoRouterMixin` 8/7 ·
`isWebOrDesktop` 8/3 · `buildConfirmDialog` 7/5 · `PopupMenuButton` 6/5 · `DynamicSearcheableAppBar` 6/6 ·
`unaccentedText(` 6/4 · `StreamBuilder(` 5/4 · `Get.put(` 5/4 · `StatelessAccessControlledView` 5/5 ·
`SmartRefresher` 1/1. **`ScaffoldMessenger` = 0** · **`.when(` = 0**.

---

## 1. DÉJÀ MIGRÉ — ce que l'hôte consomme, mesuré chez lui

| Canal du socle | Site chez l'hôte | Volume |
|---|---|---|
| `presentEdition` + `ZSheetFrameSpec` + `ZSheetFrameMode.unlessChrome` | `iffd/lib/src/utils/functions/forms_utils.dart:775-784` (corps de `showPushedDialog`) | **108 appels / 42 f.** au total, **21 / 8 f.** dans le périmètre |
| `presentFormEdition` | 12 fichiers du périmètre, dont `annee_accademique_zcrud_edition.dart:245`, `auditeur_iffd_zcrud_edition.dart:196`, `auditeur_account_zcrud_edition.dart:149`, `task_list_zcrud_edition.dart:111`, `auditeurs_filter_zcrud_edition.dart:210` | **24 occ. / 12 f.** (60 / 29 f. au dépôt) |
| `ZFormOnly` + `ZFormOnlyController` | corps composés des jumeaux portés | **17 occ. / 8 f.** |
| `ZStepperEdition` | 3 fichiers du périmètre | **6 occ. / 3 f.** |
| `ZFieldSpec` (schéma déclaratif) | les 11 jumeaux du domaine | **113 occ. / 9 f.** |
| `ZcrudScope` — **12 seams sur 25** | `iffd/lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart:345-407` : `widgetRegistry`, `theme`, `gradientResolver`, `iconResolver`, `colorKeyResolver`, `selectPresenter`, `defaultTextConfig`, `numberDisplayFormatter`, `dateDisplayFormatter`, `subListSeamRegistry`, `relationSourceRegistry`, `acl` | `IffdZcrudScope` : **73 occ. / 28 f.** |
| `ZWidgetRegistry.register` (seam d'extension de champ) | `z_iffd_field_registry.dart:188` (`phoneNumber`), `:199` (booléen IFFD) ; champs maison servis par ce seam : `z_iffd_acl_matrix_field.dart` (262 l), `z_questions_counts_field.dart` (169 l) | registre 461 l |
| `ZcrudTheme` — **~30 jetons sur 220** | `z_iffd_form_theme.dart` (281 l), posé par luminosité | — |
| `ZNumberDisplayFormatter` / `ZDateDisplayFormatter` (ports 3.14) | impls hôtes `z_iffd_field_registry.dart:418` et `:447` | 2 classes |
| `ZcrudLocalizationsDelegate` | `iffd/lib/main.dart:45,312` | monté |
| `ZAcl` (port) | `iffd/lib/src/presentation/features/ai_routers/zcrud/ai_router_zcrud_edition.dart:235` (`IffdMinimumOneAcl implements ZAcl`, `can` `:245`) | hors périmètre mais preuve que le pont ACL est écrit |
| Paquets déclarés | `iffd/pubspec.yaml` : `zcrud_screen:524`, `zcrud_ui_kit:440`, `zcrud_navigation:498`, `zcrud_menu:340`, `zcrud_riverpod:315` | 23 paquets, tous `v3.21.0` |

**11 jumeaux portés dans le périmètre**, tous derrière une bascule QA
(`iffd/lib/src/presentation/shared/zcrud/z_qa_flags.dart`, 985 l, `grep -c "^    id: '"` = **52**) :
`aiExpert` (534 l) · `exam` (513) · `anneeAccademique` (300) · `firstLogin` (257) ·
`auditeursFilter` (226) · `auditeurIffd` (221) · `workflowNotes` (214) · `appUserRole` (198) ·
`auditeurAccount` (162) · `taskList` (117) · `agentsFilter` (246). **Aucun actif par défaut**.

---

## 2. 🔴 MIGRABLE AUJOURD'HUI — le socle sait déjà le faire, l'hôte l'ignore

> Chaque ligne nomme l'API exacte, son `fichier:ligne` dans `packages/`, et le **corps lu** —
> pas la dartdoc seule. Les lignes économisées sont **conservatrices** et justifiées en §2.x.

| # | Besoin de l'hôte | API socle exacte | `fichier:ligne` | L. hôte |
|---|---|---|---|---:|
| M1 | Écran de liste « chercher / filtrer / trier / agir » réécrit 5 fois en `administration/` | `ZCrudScreen` **sans registre** : `listFields` + `cellsOf` + `editionBuilder` | `zcrud_screen/lib/src/presentation/z_crud_screen.dart:187`, `:189`, `:219` — getters `_listFields:1334`, `_cellsOf:1361`, `_formPathAvailable:1401` | **900** |
| M2 | Alimenter cet écran depuis un `StreamBuilder` existant, sans dépôt zcrud | `ZCrudSource.items(List<T>, {onSave, onSoftDelete, onRestore, onPurge, isDeleted})` | `z_crud_source.dart:109` — corps de rendu `z_crud_screen.dart:3270-3315` | (inclus M1) |
| M3 | Les 3 surfaces de l'éditeur de rendez-vous, écrites séparément | `ZFieldSpec[]` + `presentFormEdition(policy:)` + `ZPresentationPolicy.resolve` (compact→`sheet`, medium→`dialog`, expanded→`dialog`\|`page`) | `zcrud_navigation/lib/src/domain/z_presentation_policy.dart:72-84` ; catalogue de 46 types `zcrud_core/…/edition_field_type.dart:38-213` | **2 500** |
| M4 | Recherche sans accents + sans espaces | `zFoldDiacritics(input, folding:)` / `ZSearchFolding.diacriticsAndSpaces` | `zcrud_core/lib/src/domain/data/z_search_text.dart:116-133` (table `_foldTable:61`, exportée par `zcrud_core/lib/domain.dart:47`) | **40** |
| M5 | Dialogue de confirmation `Future<bool>` | `showZConfirmDialog(context, message:, tone:)` | `zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:129-147` | **175** |
| M6 | États chargement / vide / erreur / « aucun résultat » | `ZContentStateView` + `ZEmptyState` / `ZLoadingState` / `ZErrorState` ; côté écran assemblé `ZListEmpty` vs `ZListNoResults` | `zcrud_ui_kit/…/z_state_widgets.dart:180`, `:31`, `:75`, `:127` ; `z_crud_screen.dart:3303-3310` | **300** |
| M7 | App-bar recherchable + onglets + tous les créneaux `Scaffold` | `ZPageScaffold` (29 champs) / `ZPageShellBody` (19) / `ZSearchableAppBar` / `ZAppBarAction` | `zcrud_ui_kit/…/z_page_scaffold.dart:46`, `z_page_shell_body.dart:36`, `z_searchable_app_bar.dart:14`, `domain/z_app_bar_action.dart:15` | **372** |
| M8 | Toast, sans dépendre d'un gestionnaire d'état | `ZScaffoldMessengerToaster` + `zToast` + `ZToasterScope` — **pur-Flutter** (`zcrud_ui_kit/pubspec.yaml` : `zcrud_core` + `flutter`, rien d'autre) | `zcrud_ui_kit/…/z_scaffold_messenger_toaster.dart:31-90`, `z_toaster_scope.dart:23`, `:59` | **30** |
| M9 | « Ne pas perdre la saisie » | `ZDiscardChangesGuard(isDirty:, child:)` — reconstruit **le seul `PopScope`**, jamais le `child` | `zcrud_ui_kit/…/z_discard_changes_guard.dart:50-110` | **60** |
| M10 | Menus de sélection d'une valeur (échéance, rappel, récurrence, agenda) | `ZActionMenu(trigger:, entries:)` + `ZMenuEntry` (règle d'absence : `permitted: false` ⇒ **absente**) + `ZMenuTrigger.semanticLabel` **requis** + `ZMenuEntryTile` ≥ 48 dp | `zcrud_menu/…/presentation/z_action_menu.dart:18`, `domain/z_menu_entry.dart:36,:99`, `domain/z_menu_trigger.dart:57`, `presentation/z_menu_entry_tile.dart:31` | **80** |
| M11 | Poser une ACL/un thème par écran **sans reperdre** les 12 seams déjà posés | `ZcrudScope.derive(context, {…})` — sentinelle `_zScopeUndefined:46` distingue « omis » de `null` | `zcrud_core/lib/src/presentation/zcrud_scope.dart:478` | **40** |
| M12 | Renommer un libellé du socle / porter un libellé métier par clé | `ZcrudLabels(Map<String,String>)` + `label(context, key, {fallback})` | `zcrud_core/…/l10n/z_labels.dart:20`, `z_localizations.dart:449-457` | **56** |
| M13 | Grille de données Syncfusion pour les listes tabulaires | `ZSfDataGridRenderer` (17 réglages) injecté par `ZcrudScope.listRenderer` | `zcrud_list/…/z_sf_data_grid_renderer.dart:133` ; seam `zcrud_scope.dart:208` | **0** (capacité neuve) |
| M14 | Réordonnancement **intra-liste** à poignée (footer de cotation) | `ZReorderableAdaptiveGrid` + `ZDefaultReorderRenderer` (honore la poignée, 3.19.0) ; `ZAdaptiveGrid.builder` **virtualisé, public** | `zcrud_responsive/…/z_reorderable_adaptive_grid.dart:96`, `z_default_reorder_renderer.dart:36`, `z_adaptive_grid.dart:89` | **60** |
| M15 | Les 4 tables de dégradés de carte recopiées | `ZGradientResolver` / `ZGradientSpec` + `zResolveGradient` — **déjà posé par l'hôte** pour les champs (`iffdFieldTintResolver`), jamais pour les cartes | `zcrud_core/…/theme/z_gradient_resolver.dart:63`, `:40`, `:129` | **60** |
| M16 | ACL par ligne et par action sur un écran de liste | `ZCrudScreen.rowAcl` (`ZRowAclResolver`) + `actionAclMode` (`hide`\|`disable`) + `ZRestrictedAcl` (intersection) | `z_crud_screen.dart:866`, `:874` ; `zcrud_core/…/ports/z_acl.dart:210` | **80** |

**Total conservateur : ≈ 4 750 lignes d'hôte** (détail §2.9).

### 2.1 🔴 M1/M2 — le blocage que l'hôte s'est écrit à lui-même n'existe pas

L'hôte a tranché le contraire, noir sur blanc, le 2026-08-24 :

> `iffd/docs/migration-data-crud/04-navigation-et-pages.md:139-141`
> « 🔴 **BLOQUANT : `T extends ZEntity`** … `ZcrudRegistry` : **0 occurrence** »
> « 🔴 **Paquet non déclaré** — `zcrud_screen` absent de `dependencies:` **et** de
> `dependency_overrides:` du `pubspec.yaml` »

**Les deux moitiés sont fausses aujourd'hui, et je le montre :**

**① `zcrud_screen` EST déclaré.** `iffd/pubspec.yaml:524` (dépendance) et `:695` (override).
Et il est **importé 8 fois dans mon seul périmètre** (`presentFormEdition`, `ZFormOnly`).

**② Le registre n'est PAS requis.** Corps lu, pas dartdoc :

```dart
// zcrud_screen/lib/src/presentation/z_crud_screen.dart:1334
List<ZFieldSpec> get _listFields {
  final fields = widget.listFields ?? _derivedSpecs;   // ← paramètre D'ABORD
  if (fields == null) { throw ZScopeError('… Fournissez `listFields`, ou un `registry` …'); }
```
```dart
// :1361
Map<String, Object?> Function(T item) get _cellsOf {
  final explicit = widget.cellsOf;
  if (explicit != null) return explicit;              // ← paramètre D'ABORD
```
```dart
// :1401
bool get _formPathAvailable {
  if (widget.editionBuilder != null) return true;     // ← formulaire fourni par l'hôte
  return widget.registry != null && _registryKind != null && _formFields != null;
}
```
⇒ `registry` (`:185`) est une **commodité de dérivation**. `listFields:187` + `cellsOf:189` +
`editionBuilder:219` la remplacent intégralement. Aucune annotation, aucun `build_runner`.

**③ `ZEntity` coûte UNE ligne, dans UN fichier.** Le contrat entier :

```dart
// zcrud_core/lib/src/domain/contracts/z_entity.dart:17
abstract class ZEntity {
  const ZEntity();
  String? get id;
  bool get isEphemeral => id == null;
}
```

Or l'hôte porte déjà exactement cette forme, à la racine de sa hiérarchie :

```dart
// iffd/lib/src/domain/models/dynamic_model.dart:3
abstract class DynamicModel {
  final String? id;
  const DynamicModel({this.id});
```

`abstract class DynamicModel extends ZEntity` (+ 1 import) fait conformer d'un coup les **16**
classes `extends DynamicModel` — et donc `AppUser`, `AuditeurIffd extends AppUser`, `AppUserRole`,
`AnneeAccademique`, `ExamModel`. Les **9** classes `implements DynamicModel`
(`ai_expert.dart:12`, `task.dart:14,:124`, `event.dart:5`, `time_slice.dart:4`,
`ai_expert_responses_example.dart:7`, `chatbot_conversation.dart:14`, `ai_expert_knowledge.dart:8`,
`chatbot_message.dart:122`) ajoutent chacune `bool get isEphemeral => id == null;` — **9 lignes**.
Toutes portent déjà `String? id` (vérifié fichier par fichier).

**Coût total de conformité : 1 fichier + 10 lignes.** Ce n'est pas un blocage, c'est une ligne.

**④ La voie `items` existe, et elle est faite pour ce cas.** Le patron d'IFFD est
`StreamBuilder(repo.streamAll(request:))` → `snapshot.data ?? <T>[]` → `.where(…)` → `.sort(…)`.
`ZCrudSource.items(List<T>, {onSave, onSoftDelete, onRestore, onPurge, isDeleted})`
(`z_crud_source.dart:109`) prend exactement ce `snapshot.data`. Corps de rendu **lu** :

```dart
// z_crud_screen.dart:3270-3305 — _buildItemsBody
final page = zApplyListRequest(rows, ZDataRequest(
  filters: policy.filtersWith(_userFilters),
  sorts: policy.sortFor(_userSort),
  search: (!searched || _search.isEmpty) ? null : _search,
  searchScope: policy.searchScope,
  searchFolding: policy.searchFolding,
), schema: _listFields);
if (rows.isEmpty)          { state = const ZListEmpty(); }
else if (page.rows.isEmpty){ state = const ZListNoResults(); }
else                       { state = ZListReady(page.rows); }
```

⇒ recherche, filtres, tri **et** la distinction *vide* / *aucun résultat* — que le patron actuel
d'IFFD confond (`snapshot.data ?? []` puis un seul `if (assistants.isEmpty)`).

🔴 **Bonus : la migration corrige un défaut de recherche mesuré.**
`iffd/…/administration/pages/ai_experts_page.dart:97-113` écrit
`if (!titre.contains(q) || !description.contains(q) || !pseudo.contains(q)) return false;` —
soit une **conjonction** : le terme doit être présent dans les **trois** champs à la fois.
Le socle cherche en **disjonction**, première correspondance gagnante :

```dart
// zcrud_core/lib/src/presentation/list/z_list_query.dart:90-98
for (final field in schema) {
  if (!all && !field.searchable) continue;
  if (zFoldDiacritics(_coerceText(row.cells[field.name]), folding: folding).contains(folded)) return true;
}
return false;
```

**Chiffrage de M1.** Mesuré sur `ai_experts_page.dart` : `:36-129` = **94 l** de plomberie
(`Get.put(AiExpertListController())`, `ValueNotifier valueKey = randomString()`, `RefreshController`,
`SmartRefresher`, `ListenableBuilder`×2, `StreamBuilder`, `.where(unaccentedText…)`, `.sort`,
`isLoading`) puis `:130-287` = **158 l** d'état vide bâti à la main — **252 l sur une seule page**.
Les 5 pages de `administration/` totalisent **4 268 l**
(`ai_experts_page` 1 330 · `auditeurs_pages` 1 281 · `accademic_years_page` 692 ·
`user_role_page` 632 · `exams_page` 333). Retenu : **900 l**, soit ~21 % — la plomberie répétée
cinq fois, sans compter les cartes métier qui restent à l'hôte.
Les 4 écrans de `accounting/screens/` (**647 l**) relèvent du même patron (`accounting_system_screen.dart:22-41`
= `Get.put`×2 + `FutureBuilder` + `CircularProgressIndicator` + `AppScaffold` + `AppBar`) : **250 l** de plus.

### 2.2 M3 — l'éditeur de rendez-vous : trois surfaces, une déclaration

`iffd/lib/workflow/screens/appointment_editor.dart` = **7 858 l, 21 classes, un fichier**, dont
**trois éditeurs du même objet** : `PopUpAppointmentEditorState` `:1006` (657 l),
`AppointmentEditorWebState` `:1708` (**3 507 l**), `AppointmentEditorState` `:5261` (927 l) —
**5 091 l pour un seul formulaire**. Mesuré dans ce fichier : `_isAllDay` **31 fois**,
`_updateAppointmentProperties` **14**, `_getResourceEditor` **6**, `String _subject` **3**.

Le socle rend les trois surfaces d'**une** déclaration, sans `if (isWebOrDesktop)` :

```dart
// zcrud_navigation/lib/src/domain/z_presentation_policy.dart:72-84
ZEditionPresentation resolve(ZWindowSizeClass sizeClass, {ZFormWeight formWeight = ZFormWeight.light}) =>
  switch (sizeClass) {
    ZWindowSizeClass.compact  => ZEditionPresentation.sheet,
    ZWindowSizeClass.medium   => ZEditionPresentation.dialog,
    ZWindowSizeClass.expanded => switch (formWeight) {
        ZFormWeight.light => ZEditionPresentation.dialog,
        ZFormWeight.heavy => ZEditionPresentation.page,
      },
  };
```
`ZPresentationPolicy.from(resolver)` (`:65`) permet un autre mapping sans sous-classer.

Couverture des champs du rendez-vous par les **46 types** de
`zcrud_core/lib/src/domain/edition/edition_field_type.dart:38-213` :

| Champ IFFD | Type socle | Preuve |
|---|---|---|
| sujet, lieu | `text` | `:40` |
| notes | `multiline` | idem enum |
| plage début→fin | **`dateRange`** + `ZDateConfig.mode`/amplitudes min-max | `z_field_config.dart:852`, `:878`, `:880`, `:914` |
| journée entière | `boolean` | enum |
| couleur | **`color`** | enum |
| ressources | `select` (multiple) / `relation` | enum + seam `relationSourceRegistry` (`zcrud_scope.dart:152`) |
| rappels | **`subItems`** (mini-CRUD imbriqué, 15 paramètres) | `z_sub_list_config.dart:154` |
| masquer l'heure si « journée entière » | `ZDerivation` cible `visible` | `z_derivation.dart:228` |
| **règle de récurrence** | `EditionFieldType.custom` → `EditionFamily.registryOrFallback` → `ZcrudScope.widgetRegistry` | `edition_field_family.dart:220-222` |

Le dernier point est le seam **que l'hôte exerce déjà** pour sa matrice d'ACL
(`z_iffd_acl_matrix_field.dart`, 262 l, servie par `ZWidgetRegistry`). Le sélecteur de récurrence
(`recurrence_picker.dart`, 1 721 l, + `SelectRecurrenceRuleDialog` `:6189-7858`) y entre **inchangé**
et **reste propriété de l'hôte** (§3, R1).

**Chiffrage retenu : 2 500 l.** Justification conservatrice : les deux surfaces secondaires
(657 + 927 = **1 584 l**) disparaissent entièrement, et la moitié seulement de la plomberie de champs
de la surface web (3 507 l) est comptée. Les ~3 391 l du couple récurrence ne sont **pas** comptées.

### 2.3 M4 — `zFoldDiacritics` couvre strictement plus que `unaccentedText`

Hôte (`iffd/lib/src/utils/functions/data_functions.dart:55-70`) : une table
`withDia`/`withoutDia` de **61 caractères**, caractère-pour-caractère, appliquée par 61
`replaceAll` successifs. Les appelants ajoutent tous `.replaceAll(" ", "").toLowerCase()`
(`dynamic_searcheable_app_bar.dart:163`, `ai_experts_page.dart:97`, `user_role_page.dart:90`).

Socle (`z_search_text.dart:61-104` pour la table, `:116-133` pour la fonction) : même couverture
**plus** les ligatures multi-caractères — `œ→oe`, `æ→ae`, `ß→ss`, `ĳ→ij` — que la table hôte,
de longueur fixe, **ne peut pas** exprimer. Et `ZSearchFolding.diacriticsAndSpaces` (`:49`)
fait le `.replaceAll(" ","")` par déclaration, avec la définition Unicode du blanc
(`ch.trim().isEmpty`, `:128-131`) au lieu du seul U+0020.

⚠️ **Différence honnête** : `zFoldDiacritics` abaisse **toujours** la casse (`:121`), là où
`unaccentedText` la conserve (`normalizedText(text, toLowerCase: false)`, `:118`). Les 6 sites du
périmètre rabaissent la casse juste après, donc l'équivalence tient **pour eux** ; un appelant qui
voudrait plier sans abaisser n'a pas de canal.

### 2.4 M5 — la confirmation : équivalence fonctionnelle, régression visuelle assumée

`iffd/…/forms_utils.dart:480-654` = **175 l** : `AlertDialog` à icône en dégradé, deux `InkWell`
peints à la main, couleurs `Color(0xFF…)` en dur et libellés **« Confirmation » / « Non » / « Oui »
codés en français**. Retour `Future<bool>`, 38 appels / 20 fichiers (7 / 5 dans le périmètre).

`showZConfirmDialog` (`z_confirm_dialog.dart:129-147`) rend le même `Future<bool>`, avec
`?? false` en repli sûr, libellés par `MaterialLocalizations`, `FilledButton`/`TextButton` à
`minimumSize` ≥ cible tactile, `Semantics(scopesRoute, namesRoute)` quand le titre est absent,
et un `tone` (`neutral`/`destructive`) dérivé du `ColorScheme`.

🔴 **Ce que l'hôte perdrait, et il faut le dire** : l'icône en dégradé et le chrome maison.
`ZConfirmDialog` n'a **aucun jeton de thème** — grep négatif montré : `grep -n "confirm"
zcrud_core/lib/src/presentation/theme/z_theme.dart` → **RC=1**, aucune ligne sur 220 jetons.
C'est un manque du socle, consigné en §4 (G8). L'adoption reste nette : 175 l de couleurs en dur
et de libellés non traduits contre 1 appel.

### 2.5 M8 — « rien pour Riverpod » est un cadrage, pas un fait

`iffd/docs/migration-data-crud/04-navigation-et-pages.md:255` écrit : *« le socle livre une impl de
`ZToaster` pour **GetX** … mais **aucune pour Riverpod** »*. Grep négatif confirmé de mon côté :
`grep -rn "ZToaster" packages/zcrud_riverpod/lib packages/zcrud_provider/lib` → **RC=1**.

Mais le port **a** une implémentation par défaut qui ne dépend d'aucun gestionnaire d'état :
`ZScaffoldMessengerToaster implements ZToaster` (`zcrud_ui_kit/…/z_scaffold_messenger_toaster.dart:31`),
corps lu `:35-90` — `Theme.of(context).colorScheme` + `SnackBar` + `Semantics(liveRegion)` +
**icône ET texte** (la couleur n'est jamais le seul canal, AD-13). Fermeture du paquet, mesurée :

```
$ sed -n '/^dependencies:/,/^dev_dependencies:/p' packages/zcrud_ui_kit/pubspec.yaml
dependencies:
  zcrud_core: ^3.21.0
  flutter: {sdk: flutter}
```

`zcrud_ui_kit` est **déjà déclaré** par l'hôte (`iffd/pubspec.yaml:440`). Le toaster est donc
disponible sans une ligne de pubspec — il suffit de `ZToasterScope` (`z_toaster_scope.dart:23`)
et de `zToast(context, …)` (`:59`). Mesure hôte : **`ScaffoldMessenger` = 0 sur les 9 dossiers**,
8 occurrences au dépôt entier ; le périmètre notifie aujourd'hui par `toastification`
(`iffd/lib/src/presentation/app_scaffold.dart:6`).

### 2.6 M11 — `derive` complète, `ZcrudScope(` masque

```
$ grep -rn 'ZcrudScope(' iffd/lib --include='*.dart' | wc -l      → 28   (24 fichiers)
$ grep -rn 'ZcrudScope.derive' iffd/lib --include='*.dart' | wc -l → 0
```

`ZcrudScope.derive` (`zcrud_scope.dart:478`) lit le scope **ambiant** et ne remplace que les seams
nommés ; la sentinelle `_zScopeUndefined` (`:46`) distingue « omis » (hérite) de `null` explicite
(remise au repli). Un `ZcrudScope(` imbriqué, lui, **masque** son parent — donc les 12 seams
d'`IffdZcrudScope` (registre, thème, résolveurs de teinte/icône/couleur, présentateur de sélection,
`defaultTextConfig`, formateurs de date et de nombre) tombent au repli sous chaque scope local.
C'est aussi la voie propre pour poser l'ACL d'un écran (`derive(context, acl: …)`) sans réinjecter
douze seams à la main — le geste que les 4 copies de `_presenterParLeSocle` approchent sans l'avoir.

### 2.7 M13 — le blocage Syncfusion a disparu, le commentaire est resté

```
$ grep -n "syncfusion" iffd/pubspec.yaml
141:  syncfusion_flutter_core: ^34.1.31        …  149:  syncfusion_localizations: ^34.1.31
$ grep -n "syncfusion" packages/zcrud_list/pubspec.yaml
36:  syncfusion_flutter_datagrid: ^34.1.31
```

`iffd/pubspec.yaml:292` déclare pourtant : *« `zcrud_list` / `zcrud_export` : exigent Syncfusion ^34,
IFFD est en ^32 (W2) »*. **La contrainte est identique des deux côtés** : le motif écrit ne
correspond plus à l'état mesuré. `grep -n "^  zcrud_list:" iffd/pubspec.yaml` → **0 ligne**.

⚠️ **Portée honnête pour MON domaine** : nulle à court terme. Grep négatif montré sur les 9 dossiers —
`DataTable`, `DataColumn`, `DataRow`, `SfDataGrid`, `PaginatedDataTable` : **0 occurrence chacun**.
Aucune liste du domaine n'est tabulaire aujourd'hui. Je consigne M13 comme **capacité débloquée**
(0 ligne économisée), pas comme portage dû.

### 2.8 M14 — deux constats d'absence de l'hôte que la mesure contredit

`iffd/lib/src/presentation/features/folders/zcrud/study_tools_zcrud_adapter.dart:68-69` écrit
que `ZAdaptiveGrid.builder` (virtualisé) *« n'est pas exposé »*. Il l'est :
`zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart:89`, constructeur public d'une classe
exportée par le barrel. Ce fichier est hors de mon périmètre ; je le vérifie et le relaie parce que
la même erreur gouverne le pied de page de cotation (`iffd/lib/cotation/darg_and_drop_list_footer.dart`,
253 l) et son `DragAndDropLists(listDragOnLongPress: false)`
(`page_de_cotation_generique.dart:68`).

⚠️ **M14 est PARTIEL, et la limite est nette.** `ZReorderableAdaptiveGrid` et `ZDefaultReorderRenderer`
réordonnent **à l'intérieur** d'une liste. La cotation déplace un auditeur **d'une liste vers une
autre** (`onItemReorder(oldItemIndex, oldListIndex, newItemIndex, newListIndex)`,
`page_de_cotation_generique.dart:76`). Ce cas n'existe pas au socle — grep négatif §4 (G4).
Seuls le réordonnancement interne d'un poste et la grille virtualisée sont migrables : **60 l**.

### 2.9 Récapitulatif du chiffrage

| # | Poste | L. |
|---|---|---:|
| M3 | éditeur de rendez-vous : 3 surfaces → 1 déclaration | 2 500 |
| M1 | 5 pages de liste `administration/` | 900 |
| M7 | `DynamicSearcheableAppBar` (372 l, 25 sites / 16 f.) | 372 |
| M6 | états vides/chargement bâtis à la main | 300 |
| M1b | 4 écrans `accounting/screens/` | 250 |
| M5 | `buildConfirmDialog` | 175 |
| M10 | 5 `PopupMenuButton` de `workflow/` | 80 |
| M16 | ACL par ligne / par action | 80 |
| M12 | 14 fichiers l10n vides (4 l chacun) → `ZcrudLabels` | 56 |
| — | `dynamic_list_search_controller.dart` (13 sous-classes vides) | 71 |
| M9 | 13 `PopScope(` de 2 fichiers | 60 |
| M14 | réordonnancement interne + grille virtualisée (cotation) | 60 |
| M15 | 3 tables de dégradés du périmètre → 1 résolveur | 60 |
| M4 | plomberie `unaccentedText` + `replaceAll` + `toLowerCase` | 40 |
| M11 | `ZcrudScope.derive` dans les 4 `_presenterParLeSocle` | 40 |
| M8 | `zToast` / `ZToasterScope` | 30 |
| — | `loading_indicators.dart` (partiel — l'overlay reste, §4 G3) | 40 |
| M2/M13 | `ZCrudSource.items` (inclus M1) / `zcrud_list` (capacité) | 0 |
| | **TOTAL** | **≈ 5 114** |

Retenu comme chiffre publiable : **≈ 4 750 l**, après retrait d'une marge de 7 % pour les cartes
métier enchevêtrées dans la plomberie des pages de liste.

---

## 3. RESTE À L'HÔTE — règle métier IFFD, pas une préférence

| # | Ce qui reste | Preuve / volume |
|---|---|---|
| R1 | **La matrice d'autorisations CRUD par ressource.** Un rôle ou une promotion porte une matrice par objet délégable, éditée **par douze d'un coup** pour une année. `RessourceACL` (163 l) + `Crud` (173) + `AppUserPermissions` (256) + `PermissionHelpers.generateCrudableObjects` | `iffd/lib/src/domain/security/` 4 f., 902 l ; **33 lectures d'`AppUserPermissions` / 12 f.** dans le périmètre. Déjà exprimé au socle **par le bon seam** : champ maison `z_iffd_acl_matrix_field.dart` (262 l) servi par `ZWidgetRegistry` |
| R2 | **Le formulaire bimodal auditeur** — écrit *soit* l'identité pédagogique *soit* le compte — et le **provisionnement d'un compte Firebase** depuis un écran d'administration | `z_qa_flags.dart:715-723` (`auditeurIffd`), `:678-688` (`auditeurAccount`, 162 l). Un formulaire qui crée une identité n'est pas un CRUD |
| R3 | **Le parcours d'entrée en quatre barrières** : version → connexion → mot de passe forcé + profil → année académique. Porté par les écrans eux-mêmes | `force_update_screen` 223 l · `login_page` 727 · `first_login_screen` 451 · `accademic_year_selection_page` 452. `grep -rn "AutoRouteGuard" iffd/lib` → **0 ligne** |
| R4 | **Le routage** : 26 routes, 3 arbres imbriqués, `meta: SideMenuItem(...).toMap()` qui **génère le menu latéral depuis les routes**, `checkAccess: [Type…]` | `app_router.dart` 270 l + `app_router.gr.dart` **2 601 l générées**. Hors périmètre du socle **par conception** : `zcrud_navigation/pubspec.yaml:16` déclare « AUCUN routeur (go_router) », et deux gardes de source en interdisent l'import (`zcrud_ui_kit/test/z_page_shell_source_guard_test.dart:73`) |
| R5 | **Le chrome de marque des écrans d'auth** : logo, fonds animés (`AnimationController`/`FadeTransition`/`LinearGradient`/`Tween` — 10 occ. dans `login_page`, 9 dans `accademic_year_selection_page`, 6 dans `first_login_screen`, 5 dans `force_update_screen`) | Grep négatif montré : `grep -rn "class Z.*Login\|class Z.*Auth\|class Z.*SignIn\|class Z.*Splash\|class Z.*Onboard" packages/*/lib` → **RC=1**. ⚠️ La **duplication** reste un défaut d'hôte : `login_page.dart:403-435` et `accademic_year_selection_page.dart:227-259` sont **identiques à l'octet** (`diff` vide, 33 l) |
| R6 | **L'année académique comme portée globale** et `FiliereEtCycleIFFD` (filière × cycle) comme axe de découpe jusque dans les formulaires | `auditeur_iffd_zcrud_edition.dart:45` |
| R7 | **Le plan comptable SYSCOHADA**, journaux, écritures, taxes | `lib/accounting/model/` 9 classes, 1 472 l. Le socle ne porte pas de référentiel comptable |
| R8 | **La cotation** — répartition d'auditeurs par poste, par filière | `lib/cotation/` 3 f., 624 l |
| R9 | **Les 52 bascules QA** et les 14 fichiers d'adaptation (3 234 l) | `z_qa_flags.dart` (985 l). **C'est un état de migration, pas une architecture** : tout portage passe par ce registre, jamais par substitution directe |
| R10 | **Le vocabulaire métier** de l'agenda et de la comptabilité | `workflow/l10n/` + `accounting/l10n/` = 22 f., 1 163 l — dont **14 fichiers de 4 lignes, vides** (56 l mortes : l'app ne déclare que `Locale("fr")`, `iffd/lib/main.dart:51`) |

---

## 4. MANQUE AU SOCLE — avec grep négatif montré

| # | Manque | Forme du canal | Paquet | Pourquoi l'hôte ne peut s'en passer | Bloque l'étude/révision ? |
|---|---|---|---|---|---|
| **G1** | **Règle de récurrence de calendrier** (quotidien / hebdo / mensuel / annuel, intervalle, `count`, `until`, jours de semaine, jour du mois) | **entité** de domaine pur + **champ** déclaratif (`EditionFieldType.recurrence`) + éditeur par défaut | `zcrud_core` (entité) + un satellite pour l'éditeur | `appointment_editor.dart` écrit les règles **deux fois sous deux noms** (`_neverRule/_dailyRule/…` `:1844-1926` vs `_dayRule/_weekRule/…`) et `recurrence_picker.dart` (**1 721 l**) est la **cinquième** écriture. Sans canal socle, ~3 391 l restent hors de toute déclaration | **Non** |
| **G2** | **Rafraîchissement manuel d'une liste** (tirer pour rafraîchir, bouton de rechargement) sur l'écran assemblé | **paramètre** `onRefresh` sur `ZCrudScreen` / `ZPageScaffold` | `zcrud_screen` + `zcrud_ui_kit` | IFFD contourne par une **clé de re-souscription forcée** : `randomString()` **70 occ. / 46 f.** au dépôt, **10 / 8 f.** dans le périmètre, plus `SmartRefresher` + `RefreshController`. Sans canal, ce contournement survit à `ZCrudScreen` | **Non** |
| **G3** | **Voile de chargement de page** au-dessus du contenu déjà peint | **paramètres** `isBusy` / `busyOverlay` sur `ZPageScaffold` et `ZPageShellBody` | `zcrud_ui_kit` | `AppScaffold` porte `isLoading` **et** `isFetching` (`iffd/lib/src/presentation/app_scaffold.dart:11-12`), 25 sites / 14 f. `ZContentStateView` couvre l'état **du contenu**, jamais un voile **par-dessus** un contenu peint (`WrapInProgressIndication`, `loading_indicators.dart:4-41`) | **Non** |
| **G4** | **Glisser-déposer ENTRE listes** (tableau à colonnes / Kanban) | **port** `ZCrossListReorderRenderer` + **paramètre** `onItemReorder(item, fromList, toList, index)` | `zcrud_responsive` (repli natif) + `zcrud_dnd` (impl tierce) | La cotation déplace un auditeur d'un poste vers un autre (`page_de_cotation_generique.dart:76`). `zcrud_dnd` **exclut explicitement** ce cas : « Ce paquet n'a **rien** à voir avec le réordonnancement interne d'une collection » (`zcrud_dnd/lib/zcrud_dnd.dart:9-13`) et `ZReorderRenderer` ne connaît qu'une liste | **Non** |
| **G5** | **Menu latéral / rail de navigation / fil d'Ariane** | **assemblage** `ZNavigationShell` + **entité** `ZNavDestination` | un satellite dédié (jamais `zcrud_core`, AD-1) | Le menu latéral d'IFFD est **généré depuis les routes** (`app_router.dart:30-45`, `meta: SideMenuItem(...).toMap()` + `checkAccess`). ⚠️ Fortement couplé au routeur : à instruire avant d'y répondre — un socle qui n'a pas de routeur ne peut pas générer un menu de routes | **Non** |
| **G6** | **Bouton d'action flottant expansible** (speed-dial) | **widget** `ZExpandableFab` + **entité** `ZFabAction` | `zcrud_ui_kit` | `ExpandableFab` + `ExpandableFabItem` (`iffd/lib/workflow/utils.dart:28`, `:206`), **14 occ. / 3 f.** dans le périmètre. Le socle n'offre que les créneaux `floatingActionButton` / `floatingActionButtonLocation` (`z_page_scaffold.dart:166`) — grep : aucun `SpeedDial`/`ExpandableFab` dans les 41 `*/lib` | **Non** |
| **G7** | **Fusion de la map partielle sur la map de départ**, à la sortie d'un formulaire | **paramètre** `mergeWithInitialValues: bool` (ou un crochet `onValues`) sur `presentFormEdition` | `zcrud_screen` | Corps lu (`present_form_edition.dart:284-296`) : `Navigator.of(ctx).pop(values)` où `values = controller.submit()` — **seuls les champs déclarés**. Un formulaire partiel sur une entité complète est la norme : IFFD écrit `{...depart, ...saisie}` **4 fois** (`annee_accademique_modal_dialogs.dart:305`, `auditeurs_iffd_modal_dialogs.dart:437`, `app_user_role_dialogs.dart:373`, `ai_experts_dialogs.dart:1084`). **Oublier la fusion est une perte de données silencieuse** — c'est cette classe de défaut que le canal fermerait | **Non** |
| **G8** | **Jetons de thème du dialogue de confirmation** (icône d'en-tête, forme, rayon, dégradé) | **jetons** `confirmDialog*` de `ZcrudTheme` (nullables ⇒ rendu inchangé si absents) | `zcrud_core` + lecture dans `zcrud_ui_kit` | Grep négatif montré : `grep -n "confirm" packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` → **RC=1** — aucun des 220 jetons ne touche `ZConfirmDialog`, dont le seul réglage est `tone` (`z_confirm_dialog.dart:63`). Sans eux, l'adoption de `showZConfirmDialog` (§2.4) est une régression visuelle assumée sur **38 appels / 20 fichiers** | **Non** |

### Greps négatifs — commandes et résultats

| Affirmation d'absence | Commande (depuis `/home/zakarius/DEV/zcrud`) | Résultat |
|---|---|---|
| G1 — aucune règle de récurrence de calendrier | `grep -rn "RecurrenceRule\|RecurrenceType\|recurrenceRule" --include="*.dart" packages/*/lib` | **RC=1** |
| G1bis — `recurrence` n'existe qu'en rappel d'examen | `grep -rn "recurrence" --include="*.dart" packages/*/lib` | 6 lignes, **toutes** dans `zcrud_exam` (`z_reminder_recurrence.dart` = jours-avant + jours de semaine, `:42-59`) |
| G2 — aucun rafraîchissement manuel | `grep -rn "RefreshIndicator\|SmartRefresher\|onRefresh\|pullToRefresh" --include="*.dart" packages/*/lib \| wc -l` | **0** |
| G3 — aucun `isLoading` sur le page-shell | `grep -n "isLoading\|isFetching\|canPop" packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart` | 1 ligne, et c'est une **dartdoc** (`z_page_scaffold.dart:42`) |
| G4 — aucun glisser entre listes | `grep -rn "onItemReorder\|crossList\|kanban\|Kanban\|DragAndDropLists\|betweenLists" --include="*.dart" packages/*/lib` | **RC=1** |
| G5 — aucun menu latéral / rail / fil d'Ariane | `grep -rn "NavigationRail\|NavigationDrawer\|Breadcrumb\|SideMenu\|ZDrawer" --include="*.dart" packages/*/lib` | **RC=1** |
| G6 — aucun FAB expansible | `grep -rn "ExpandableFab\|SpeedDial\|FloatingActionButton" --include="*.dart" packages/*/lib` | 3 lignes, **toutes** `final FloatingActionButtonLocation?` (créneaux de relais) |
| G8 — aucun jeton de confirmation | `grep -n "confirm" packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` | **RC=1** |
| R5 — aucun écran d'auth au socle | `grep -rn "class Z.*Login\|class Z.*Auth\|class Z.*SignIn\|class Z.*Splash\|class Z.*Onboard" --include="*.dart" packages/*/lib` | **RC=1** |
| M8 — aucun `ZToaster` côté Riverpod/Provider | `grep -rn "ZToaster" packages/zcrud_riverpod/lib packages/zcrud_provider/lib` | **RC=1** (mais `ZScaffoldMessengerToaster` est pur-Flutter — §2.5) |
| Périmètre — aucune grille de données | `grep -rnF "<motif>" <9 dossiers> --include="*.dart"` pour `DataTable`, `DataColumn`, `DataRow`, `SfDataGrid`, `PaginatedDataTable` | **0 occ. chacun** |
| Périmètre — aucun `ScaffoldMessenger`, aucun `.when(` | idem | **0 occ. / 0 f.** chacun |
| Périmètre — aucun accès Firestore direct | `grep -rnF "FirebaseFirestore.instance"` et `".collection("` sur les 9 dossiers | **0 occ.** chacun (⚠️ mais `Timestamp` = **19 occ.**, `package:cloud_firestore` importé par **5 fichiers** du périmètre) |
| Hôte — `ZcrudLabels` jamais utilisé | `grep -rn "ZcrudLabels" iffd/lib --include="*.dart"` | **RC=1** |
| Hôte — `ZcrudScope.derive` jamais utilisé | `grep -rn "ZcrudScope.derive" iffd/lib --include="*.dart" \| wc -l` | **0** (contre **28** `ZcrudScope(` / 24 f.) |
| Hôte — `zcrud_list` non déclaré | `grep -n "^  zcrud_list:" iffd/pubspec.yaml` | **0 ligne** |

---

## 5. Trois affirmations de l'hôte que la mesure contredit aujourd'hui

Elles produiront du « migrable » **sans qu'aucun canal neuf ne soit en cause**. Ce sont les plus
coûteuses, parce qu'elles gouvernent des absences durables.

| Écrit chez l'hôte | Mesuré le 2026-08-26 |
|---|---|
| `docs/migration-data-crud/04-navigation-et-pages.md:141` — « `zcrud_screen` **absent** de `dependencies:` **et** de `dependency_overrides:` » | Déclaré **deux fois** (`pubspec.yaml:524`, `:695`) et **importé par 8 fichiers du seul périmètre** |
| `docs/migration-data-crud/04-navigation-et-pages.md:139` — « 🔴 **BLOQUANT : `T extends ZEntity`** … `ZcrudRegistry` : **0 occurrence** » | Le registre est **nullable** et chacune de ses trois dérivations a son paramètre de remplacement (§2.1). `ZEntity` = 2 membres, dont un à corps par défaut ; conformité = **1 fichier + 10 lignes** |
| `pubspec.yaml:292` — « `zcrud_list` / `zcrud_export` exigent Syncfusion ^34, IFFD est en ^32 » | IFFD est en **`^34.1.31`** (`pubspec.yaml:141-149`) ; `zcrud_list` demande **`^34.1.31`**. Contrainte identique des deux côtés |

⚠️ Symétriquement, **une affirmation du socle est imprécise** et il faut le dire : la fenêtre
3.13 → 3.21 n'a **rien** livré aux paquets de ce domaine. `git diff --name-only v3.12.0..HEAD --
'packages/*/lib/*'` rend 42 fichiers, dont **1 seul** dans `zcrud_screen`, **0** dans
`zcrud_ui_kit`, `zcrud_menu`, `zcrud_navigation`, `zcrud_list`. Le vrai corpus inconnu de l'hôte
est celui du **13 → 23 août** — 17 releases de `zcrud_screen` en 12 jours, presque toutes issues de
CR DODLP, que l'hôte n'a jamais lues. Présenter ces canaux comme « livrés récemment » serait exact
au calendrier des versions et faux au calendrier du code.

---

## 6. Ce que ce relevé n'a PAS établi

À ne pas combler par déduction :

1. **Aucun test n'a été lancé**, dans aucun dépôt (consigne). Les comportements cités viennent des
   **corps lus**, pas d'une exécution.
2. **Le rendu visuel** de `ZPageScaffold`/`ZSearchableAppBar` contre `AppScaffold`/
   `DynamicSearcheableAppBar` : non comparé — cela demande une exécution. Les 372 l de M7 sont un
   volume de code, pas une promesse de parité au pixel.
3. **La matrice d'inertie paramètre × surface** de `ZAdaptivePresenter`
   (`zcrud_navigation/doc/parameter-matrix-z-adaptive-presenter.md`) : non ouverte. M3 suppose que
   les surfaces `sheet`/`dialog`/`page` honorent les réglages du rendez-vous ; à vérifier avant lot.
4. **`AppScaffold` n'est PAS un `ZPageScaffold`** : il porte le tiroir de menu latéral
   (`MenuStateMixin`, `SideMenuDrawer`), un `BackButtonInterceptor` (double-appui pour quitter) et
   `toastification`. M7 ne remplace que l'app-bar recherchable ; le reste bute sur G3 et G5.
5. **Le sort de `data_crud`** (19 f., **14 980 l**) : hors de mon périmètre. Les 10 jumeaux du
   domaine vivent **à côté** de leur original, pas à sa place.
6. **`popup_menu_helpers.dart`** (1 016 l, 5 constructeurs) : les 5 menus servent dossiers, notes,
   cartes mentales, flashcards et documents — **d'autres domaines**. Je ne le revendique pas ;
   M10 ne porte que les **5 `PopupMenuButton` de `lib/workflow/`**.
7. **Le coût de conformité `ZEntity` a été lu, pas compilé.** Les 9 classes `implements
   DynamicModel` portent bien `String? id` (vérifié une par une) ; qu'aucune n'entre en collision
   avec `isEphemeral` n'a pas été prouvé par une analyse.
