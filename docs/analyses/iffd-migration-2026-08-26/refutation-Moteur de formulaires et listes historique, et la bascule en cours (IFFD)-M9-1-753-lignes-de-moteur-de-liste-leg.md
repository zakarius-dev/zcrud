# Réfutation — M9 : « 1 753 lignes de moteur de liste legacy qui ne servent QU'UN SEUL écran »

**Domaine** : Moteur de formulaires et listes historique, et la bascule en cours (IFFD)
**Affirmation attaquée** : « le socle sait déjà le faire, par `ZCrudScreen<T extends ZEntity>` +
`ZCrudSource.items` + `ZCrudTitles` + `ZListDataGridLayout` + `ZSfDataGridRenderer` injecté par
`ZcrudScope.listRenderer` » — **gain annoncé ≈ 1 753 lignes d'hôte supprimées**.

**Date de la mesure** : 2026-08-26.
**IFFD** : `65d1af948dd070fcee963bed71dfceb873f5ae1a` (2026-08-26 07:04:44 +0000), **lecture seule**.
**zcrud** : `main` @ `cc276c154` (v3.21.0).

---

## VERDICT : **DÉMENTIE** (couverture partielle présentée comme totale, et besoin inexistant)

Le **canal existe**, il **fait** ce qu'on lui prête, et il est **atteignable** : sur ces trois
points, l'affirmation résiste, et je le documente en détail au § 1. Elle tombe sur les deux autres :

1. La « **correspondance paramètre par paramètre du seul appelant** » est établie sur
   `agents_screens.dart:176-201`. **Le site d'appel s'étend en réalité de 176 à 647** — mesuré par
   équilibrage de parenthèses — soit **472 lignes et 14 paramètres nommés**. Le tableau en couvre
   **8**. Les **6 paramètres omis pèsent 343 lignes**, dont un `crudActionsButtionsBuilder` de
   **185 lignes** et un `formFields` de **123 lignes** portant un champ-widget custom. (§ 2)
2. **L'écran cible est INATTEIGNABLE.** `AgentsScreen` — le seul widget qui instancie
   `DynamicListScreen` — **n'est instancié nulle part** dans `lib/`. Les 1 753 lignes ne servent
   donc pas « un seul écran » : elles servent **zéro écran atteignable**. Le gain annoncé s'obtient
   par `git rm`, **sans `zcrud_list`, sans Syncfusion, sans toucher aux 24 modèles**. (§ 3)

S'y ajoutent deux erreurs de fait dans la matière de M9 :

3. `dynamic_list_field.dart`, déclaré supprimable avec M9, est une **dépendance vivante du moteur
   d'ÉDITION** : **9 sites d'usage** hors du périmètre M9, dans **4 fichiers**. (§ 4)
4. `DynamicModel` n'est pas la classe de 4 lignes que la preuve cite : c'est une **base abstraite de
   77 lignes** dont `extends ZEntity` change la signature de **24 modèles**. Le portage est
   *compatible* (§ 1.4), il n'est pas « à un mot-clé » en termes de rayon d'action. (§ 5)

---

## § 1 — Ce qui RÉSISTE (vérifié dans les corps, pas dans les dartdocs)

### 1.1 Les cinq symboles cités existent, aux lignes citées

| Symbole | `fichier:ligne` mesuré | Verdict |
|---|---|---|
| `class ZCrudScreen<T extends ZEntity>` | `zcrud_screen/lib/src/presentation/z_crud_screen.dart:180` | ✅ exact |
| `const ZCrudSource.items(` | `zcrud_screen/lib/src/presentation/z_crud_source.dart:109` | ✅ exact |
| `class ZCrudTitles` | `zcrud_core/lib/src/presentation/z_crud_titles.dart:24` | ✅ exact |
| `final class ZListDataGridLayout` | `zcrud_core/lib/src/presentation/list/z_list_layout.dart:98` | ✅ exact |
| `class ZSfDataGridRenderer implements ZListRenderer` | `zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart:133` | ✅ exact |
| `final ZListRenderer? listRenderer;` | `zcrud_core/lib/src/presentation/zcrud_scope.dart:208` | ✅ exact |

Exports vérifiés : `zcrud_screen/lib/zcrud_screen.dart:27` exporte `z_crud_screen.dart` ;
`zcrud_list/lib/zcrud_list.dart:28` exporte `z_sf_data_grid_renderer.dart` ;
`zcrud_core/lib/zcrud_core.dart:211` exporte `z_list_layout.dart`.
`ZCrudTitles` a **4 champs, un pour un** avec `CrudTitles` de l'hôte :
`create`/`copy`/`update`/`read` (`z_crud_titles.dart:27-42`). ✅

### 1.2 Le piège `_formPathAvailable` est cité EXACTEMENT

```dart
// zcrud_screen/lib/src/presentation/z_crud_screen.dart:1401-1407
bool get _formPathAvailable {
    if (widget.editionBuilder != null) return true;
    return widget.registry != null &&
        _registryKind != null &&
        _formFields != null;
}
```
Et les deux corps complémentaires confirment la voie sans registre :
`_listFields` accepte `widget.listFields` seul (`:1334`), `_cellsOf` accepte `widget.cellsOf` seul
(`:1362-1366`), la voie `editionBuilder` est prise à `:1622-1645`. ✅ **La conclusion « pour IFFD,
`editionBuilder` est obligatoire » est exacte.**

⚠️ Précision non dite : la signature remise à l'hôte est
`builder(context, T? initial, Future<void> Function(T entity) save)` (`:1639`) — **la sauvegarde
prend une ENTITÉ typée**, pas la `Map<String, dynamic>` sur laquelle vit tout le moteur legacy
(`onFormSubmit(item, editionState, [metadata])`, `agents_screens.dart:323-329`). La conversion
map → `AuditeurIffd` est à la charge de l'hôte.

### 1.3 Les onglets couvrent PLUS que ce que le tableau annonce

Le tableau réduit `tabs:` à « `ZCrudScreen.tabs` (+ `tabsStore`) ». Les deux besoins réels du site
d'appel — **ACL par onglet** et **prédicat Dart arbitraire par onglet** — sont couverts, et je l'ai
vérifié dans les corps :

* `ZListTab.acl` (`zcrud_core/…/z_list_tab.dart:85`) + cascade **restrictive**
  (`z_crud_screen.dart:1502`, `zRestrictAcl`) → couvre `DynamicTab.acl`
  (`agents_screens.dart:154`, `:161-167`).
* `ZListTab.itemFilter` (`z_list_tab.dart:288`, type `ZItemFilter`) → couvre
  `DynamicTab.filter: (item) => AuditeurIffd.fromMap(item).estPresentAu(date)`
  (`agents_screens.dart:153`), qui n'est **pas** exprimable en `ZFilter`.
* Et surtout : **la voie `items` l'HONORE** — `_buildItemsBody` compose `_tabPolicy(tab)` puis
  filtre `if (itemFilter == null || itemFilter.keeps(item))` (`z_crud_screen.dart:3277-3281`), la
  même composition que la voie dépôt (`_tabPolicy`, `:2991-3013`). Ce n'est donc pas une dartdoc
  qui promet : c'est le corps qui applique.
* `ZListTab.defaultItemBuilder` (`z_list_tab.dart`, consommé `z_crud_screen.dart:1740-1742`) →
  couvre `DynamicTab.defaultItem`.

### 1.4 Le rendu DataGrid REND bien les actions de ligne

C'est le point que j'ai cru pouvoir réfuter et qui a tenu. Un grep naïf est trompeur :

```
$ grep -rn "rowActions\|ZRowAction" packages/zcrud_list/lib/
GREP_RC=1          ← AUCUN résultat : le symbole n'est pas celui-là
```
Le renderer consomme le type **résolu**, `ZResolvedRowAction`, via `interaction.actionsFor` :
`z_sf_data_grid_renderer.dart:464` (`_hasActions`), `:497`, `:693-695`, `:975-998`. Le contrat
`ZListRenderer.build(context, request, {interaction})` (`zcrud_core/…/z_list_renderer.dart:37-40`)
porte l'interaction **à côté** de `ZListRenderRequest` — lequel ne transporte, lui, que
`columns`/`rows`/`ordinal` (`z_list_render_request.dart:162-173`). `DynamicList` la construit et la
passe au backend (`dynamic_list.dart:282-283`, `:355-356`). ✅ **La colonne d'actions existe en mode
DataGrid.** Le `ZListOrdinal` couvre au passage la colonne `#` du legacy
(`dynamic_list_screen.dart:692-706`).

### 1.5 Le blocage Syncfusion est bien PÉRIMÉ, et `zcrud_list` est la seule arête neuve

* `pubspec.yaml:292` : « `zcrud_list` / `zcrud_export` : exigent Syncfusion ^34, IFFD est en ^32 ».
* `pubspec.yaml:141-149` : **les 9 paquets Syncfusion d'IFFD sont en `^34.1.31`**, dont
  `syncfusion_flutter_datagrid: ^34.1.31` (`:144`).
* `zcrud_list/pubspec.yaml` : `syncfusion_flutter_datagrid: ^34.1.31`, `zcrud_core: ^3.21.0`,
  `zcrud_ui_kit: ^3.21.0` — **rien d'autre**.
* `zcrud_core` (`:572`, `:572` overrides), `zcrud_ui_kit` (`:440`, `:700`) et `zcrud_screen`
  (`:524`, `:695`) sont **déjà déclarés**. `zcrud_navigation` (`ZPresentationPolicy`) aussi (`:498`).
* Grep négatif montré : `grep -n "zcrud_list" pubspec.yaml` ne rend que des **commentaires**
  (`:292`, `:463`) — aucune entrée de dépendance ; `grep -rn "zcrud_list" lib test` ne rend **rien**.

✅ **`zcrud_list` est bien la seule dépendance neuve, et sa fermeture est déjà couverte.**

### 1.6 `extends ZEntity` est structurellement possible

`ZEntity` (`zcrud_core/lib/src/domain/contracts/z_entity.dart`) : `abstract class` (`:17`),
`const ZEntity();` (`:19`), `String? get id;` (`:23`), `bool get isEphemeral => id == null;` (`:26`).
*(La preuve avancée cite `:25` et `:28` — dérive de 2 lignes, sans conséquence.)*
`DynamicModel` porte `final String? id;` + `const DynamicModel({this.id});` : le champ satisfait le
getter, le ctor `const` appelle `super()` implicitement.
`grep -rn "isEphemeral" lib` → **RC=1, aucun résultat** : aucun conflit de nom dans l'hôte.
`grep -rn "extends DynamicModel" lib | wc -l` → **24**. `AuditeurIffd extends AppUser`
(`app_user.dart:434`) `extends DynamicModel` (`:37`). ✅

---

## § 2 — RÉFUTATION 1 : la correspondance est donnée pour totale sur 5 % du site d'appel

Le tableau de M9 s'annonce « **Correspondance paramètre par paramètre du seul appelant**
(`agents_screens.dart:176-201`) ».

**Mesure du site d'appel réel** (équilibrage de `([{ … }])` depuis la ligne 176) :

```
call ends at line 647          →  176-647 = 472 lignes
```

**Les 14 paramètres nommés effectivement passés**, avec leur empan mesuré :

| # | Paramètre | lignes | empan | Dans le tableau M9 ? |
|---|---|---:|---:|---|
| 1 | `title` | 177 | 1 | ✅ |
| 2 | `listDisplayMode` | 178 | 1 | ✅ |
| 3 | `acl` | 179-181 | 3 | ✅ |
| 4 | `crudTitles` | 182-189 | 8 | ✅ |
| 5 | `items` | 190-198 | 9 | ✅ |
| 6 | `tabs` | 199-200 | 2 | ✅ |
| 7 | `dialog` | 201 | 1 | ✅ |
| 8 | `actionButtons` | 202-304 | **103** | ✅ (mais le tableau s'arrête à `:201`) |
| 9 | **`initEditionState`** | 305-318 | 14 | ❌ |
| 10 | **`itemTransformer`** | 319-322 | 4 | ❌ |
| 11 | **`onFormSubmit`** | 323-329 | 7 | ❌ |
| 12 | **`crudActionsButtionsBuilder`** | 330-514 | **185** | ❌ |
| 13 | **`fields`** | 515-524 | 10 | ❌ |
| 14 | **`formFields`** | 525-647 | **123** | ❌ |

**8 paramètres sur 14 ; 25 lignes citées sur 472 (5,3 %) ; 343 lignes omises.**

Ce que les 6 omis exigent réellement du socle :

* **`crudActionsButtionsBuilder` (185 l.)** — remplace **toute la cellule d'actions** par un
  `SingleChildScrollView(Row([...]))` composé conditionnellement :
  `if (item["userId"] != null)` bouton « compte » (édition de compte + `updateUserAccount`),
  `if (item["userId"] == null)` bouton « ajouter un compte »,
  `if (screen != userAccounts) crudActionsButons` (les actions par défaut, **imbriquées**),
  `if (screen == userAccounts)` bouton éditer, puis bouton supprimer-le-compte avec confirmation
  (`agents_screens.dart:330-514`).
  Le socle n'a **aucun** canal de widget arbitraire pour cette cellule en mode DataGrid :
  `ZListDataGridLayout` **n'override pas** `withEntityTiles` — la base rend `this`
  (`z_list_layout.dart:89-93`, la dartdoc l'écrit : « une variante qui ne rend **pas** de tuiles
  (`dataGrid`, `custom`) retourne `this` ») — donc `ZCrudScreen.itemBuilder` est **inerte** dans le
  layout que M9 propose. Le seul canal restant est `rowActions: List<ZRowAction<T>>`
  (`z_crud_screen.dart:694`), dont la gouvernance par ligne **désactive mais ne masque jamais** :
  « **Action inapplicable** | `ZRowAction.enabledFor` | **toujours** rendue inerte »
  (`z_row_governance.dart:44`, appliqué `:207-214`). Le **basculement** d'icône du legacy
  (`userId != null` ? compte : ajouter-compte) devient donc **deux actions toujours visibles, l'une
  inerte**. Divergence de rendu assumée par le socle, mais **non signalée** par M9.
* **`formFields` (123 l.)** — porte un `DynamicFormField(type: EditionFieldTypes.widget)` dont le
  `choiceBuilder` rend, par permission, un `SwitchListTile` + un `FormBuilderFilterChips` écrivant
  dans `editionState["permissions"]` (`:551-640`). C'est la matrice d'autorisations. Elle ne se
  « pose » pas : elle se réécrit, ou se délègue au moteur legacy via `editionBuilder`.
* **`initEditionState` (14 l.)** + **`onFormSubmit` (7 l.)** — dérivent `appUserRoles`,
  `permissionsIds`, et recopient `permissions` à la soumission. Sur la voie socle, le pendant est
  `beforeSubmit`/`onSave`, mais **sur une entité typée** (§ 1.2), pas sur la map.
* **`fields` (10 l.)** — **schéma de liste DYNAMIQUE** : trois des cinq colonnes n'existent que sous
  condition d'état (`if (_filter.genres.length != 1)`, `if (_filter.filiereIFFD.isNotEmpty)`,
  `if (_filter.cycleIFFD.isNotEmpty)`). Le socle le supporte (le getter `_listFields` relit
  `widget.listFields` à chaque build, `z_crud_screen.dart:1334`) — mais c'est une propriété qu'il
  fallait vérifier, et que M9 n'énonce pas.

**Une couverture de 8/14 présentée comme « paramètre par paramètre » est une couverture partielle
présentée comme totale.** C'est la réfutation demandée par la consigne 4.

---

## § 3 — RÉFUTATION 2 (décisive) : l'écran cible n'est atteignable par AUCUN chemin

M9 titre : « 1 753 lignes de moteur de liste legacy servent **un** écran ». La mesure dit moins que
cela.

```
$ grep -rn "\bAgentsScreen\b" lib | grep -v "AgentsScreens"
lib/agents_filter_zcrud_edition.dart:8:   // ① L'ÉCRAN QUI OUVRE CE FORMULAIRE EST INATTEIGNABLE...
lib/agents_filter_zcrud_edition.dart:10:  //    du dépôt sur « AgentsScreen » ne rend que sa propre déclaration...
lib/agents_filter_zcrud_edition.dart:88:  /// `AgentsScreen` sera rebranché — et si la décision est de le supprimer...
lib/agents_screens.dart:113:class AgentsScreen extends ConsumerStatefulWidget {      ← déclaration
lib/agents_screens.dart:118:  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
lib/agents_screens.dart:121:class _AgentsScreenState extends ConsumerState<AgentsScreen> {
lib/src/presentation/shared/zcrud/z_qa_flags.dart:766:  '(2026-08-25) : `AgentsScreen` (`agents_screens.dart:113`) n\'est '   ← littéral de chaîne
```

**7 occurrences : 3 en commentaire, 1 dans un littéral de chaîne, 3 dans sa propre déclaration.
ZÉRO site de construction `AgentsScreen(...)`.** L'hôte l'a lui-même mesuré et écrit deux fois
(`agents_filter_zcrud_edition.dart:8-10`, `test/m0/agents_filter_zcrud_test.dart:16`).

Conséquences, toutes contre la thèse de M9 :

1. **Le « besoin » n'existe pas.** Migrer `AgentsScreen` vers `ZCrudScreen` ne rend, ne corrige et
   n'accélère **rien pour un utilisateur** : aucun utilisateur n'atteint cet écran.
2. **Le gain annoncé s'obtient sans le socle.** `AgentsScreen` (`agents_screens.dart:113-649`,
   **537 lignes**) + `dynamic_list_screen.dart` (**1 753**) + `categorysation_screens.dart` (**43**,
   dont `DynamicTabsState` n'a plus d'autre consommateur — vérifié :
   `grep -rn "DynamicTabsState" lib` ne rend que sa déclaration, `dynamic_list_screen.dart:450/573/580`
   et **un appel commenté** `agents_screens.dart:173`) = **2 333 lignes**, par suppression.
   Contre le chemin M9 : **1 753 lignes** supprimées, **une dépendance neuve**, un renderer à câbler
   dans `IffdZcrudScope`, `DynamicModel` modifié pour **24 modèles**, et 343 lignes de déclaration à
   réécrire.
3. ⚠️ **`agents_screens.dart` ne se supprime PAS en entier** : `app_user.dart:8` l'importe, et
   `app_user.dart:522` appelle `ordonnerLesAuditeurs` ; `AuditeursFilter` est consommé par
   `agents_filter_zcrud_edition.dart` et `test/m0/agents_filter_zcrud_test.dart:35`. Ce sont les
   lignes **1-112** du fichier. Seul le **widget mort (113-649)** part.
4. Le tripwire de l'hôte a **déjà tranché** ce point et laissé la porte ouverte dans les deux sens :
   « la grappe … deviendra supprimable le jour où `agents_screens.dart` sera porté au socle »
   (`test/s1/mort_confirme_test.dart:22-38`). Le portage n'est **pas** la seule sortie ; l'hôte a
   explicitement refusé de verrouiller la grappe pour cette raison.

**Un plan qui dépense une dépendance neuve et une modification de la racine de 24 modèles pour
réécrire un écran que personne n'ouvre n'est pas un gain de 1 753 lignes : c'est le chemin le plus
cher vers un `git rm`.**

---

## § 4 — RÉFUTATION 3 : `dynamic_list_field.dart` n'est pas supprimable

M9 écrit : « **Lignes supprimées : 1 753** …, **plus `dynamic_list_field.dart`** et la part
`DynamicTab`/`DynamicListField` de `data_crud/models.dart` (`:275-303`) ».

`dynamic_list_field.dart` (37 l.) déclare `DynamicListField` — **une seule déclaration dans tout le
dépôt** (`grep -rn "class DynamicListField" lib` → `lib/data_crud/dynamic_list_field.dart:6`, ligne
unique). Ses référents **hors** du périmètre M9 :

| Fichier | Lignes | Nature |
|---|---|---|
| `lib/data_crud/edition_field.dart` | `:15` (import), `:200` | **moteur d'ÉDITION** : `subItemsFieldsBuilder` est typé `List<DynamicListField> Function(Map)` |
| `lib/data_crud/sub_list_screen.dart` | `:9` (import), `:20`, `:428`, `:487` | **moteur de SOUS-LISTE** (555 l.) : champ `fields`, `buildDataCell`, boucle de rendu |
| `lib/src/presentation/features/ai_routers/dialogs/ai_routers_dialogs.dart` | `:4` (import), `:386`, `:700`, `:704` | écran de fonctionnalité, sans rapport avec les agents |
| `lib/src/presentation/features/flashcards/widgets/flashcard_edition_screen.dart` | `:6` (import), `:754`, `:758` | écran de fonctionnalité, sans rapport avec les agents |

**9 sites d'usage dans 4 fichiers, dont 2 sont le cœur du moteur d'édition/sous-liste que M9 ne
touche pas.** Supprimer `dynamic_list_field.dart` avec M9 casse la compilation d'IFFD.

*(La part `models.dart:275-303` — `DynamicTab` — est, elle, réellement libérable : ses seuls
référents hors `dynamic_list_screen.dart` sont `agents_screens.dart:150,157` et
`categorysation_screens.dart:10`, tous deux dans la grappe morte.)*

---

## § 5 — RÉFUTATION 4 : `DynamicModel` n'est pas la classe de 4 lignes citée

La preuve avancée écrit : « `iffd/lib/src/domain/models/dynamic_model.dart:3-6` déclare déjà
`abstract class DynamicModel { final String? id; const DynamicModel({this.id}); }` ».

Les lignes 3-6 disent bien cela. **Le fichier fait 77 lignes** et la classe porte, au-delà :
`Map<String, dynamic> toMap();` (abstrait), `dynamic toJson()`, `DynamicModel copyWith({String? id});`
(abstrait), `List<Object?> get props;` (abstrait), `static String get runtimeTypeString`,
`operator ==` + `hashCode` + `toString` redéfinis, deux helpers statiques de comparaison profonde
(`_listEquals`, `_deepEquals`), et une `extension DynamicModelExtension<T extends DynamicModel>`.

Aucun de ces membres **n'entre en collision** avec `ZEntity` — le portage compile (§ 1.6). Mais la
citation tronquée fait passer pour un changement local (« à un mot-clé ») une modification de la
**racine d'héritage de 24 modèles de domaine**, dont le graphe d'usage traverse toute l'application
(`app_user.dart` seul est consommé par une vingtaine de fichiers, cf. `mort_confirme_test.dart:27-28`).
Le coût réel n'est pas le mot-clé : c'est la surface de régression qu'il ouvre, pour un écran mort.

---

## § 6 — Correction : ce qu'il faut écrire à la place

> **M9 — 1 753 lignes de moteur de liste legacy qui ne servent AUCUN écran atteignable.**
>
> `DynamicListScreen` (`iffd/lib/data_crud/dynamic_list_screen.dart`, 1 753 l.) n'a qu'un appelant,
> `agents_screens.dart:176` — et **cet appelant est lui-même mort** : `AgentsScreen`
> (`agents_screens.dart:113`) n'est construit nulle part (`grep -rn "\bAgentsScreen\b" lib` :
> 3 commentaires, 1 littéral, 3 lignes de sa propre déclaration, **0 site de construction**).
>
> **Action recommandée : suppression, pas portage.** Retirer le widget mort
> (`agents_screens.dart:113-649`, 537 l. — en **conservant** `:1-112`, qui portent
> `AuditeursFilter` et `ordonnerLesAuditeurs`, consommés par `app_user.dart:8,522`,
> `agents_filter_zcrud_edition.dart` et `test/m0/`), `dynamic_list_screen.dart` (1 753 l.),
> `categorysation_screens.dart` (43 l.) et la part `DynamicTab` de `models.dart:275-303` (29 l.).
> **≈ 2 362 lignes, zéro dépendance neuve, zéro modification de `DynamicModel`.**
> `dynamic_list_field.dart` **RESTE** : 9 sites d'usage dans 4 fichiers vivants, dont
> `edition_field.dart:200` et `sub_list_screen.dart:20,428,487`.
>
> **Le socle sait effectivement faire cet écran** — et c'est vrai indépendamment de M9 :
> `ZCrudScreen<T extends ZEntity>` (`z_crud_screen.dart:180`) + `ZCrudSource.items`
> (`z_crud_source.dart:109`) + `ZCrudTitles` 4 champs pour 4 (`z_crud_titles.dart:27-42`) +
> `ZListTab.acl`/`ZListTab.itemFilter` honorés sur la voie `items` (`z_crud_screen.dart:3277-3281`,
> `:2991-3013`) + colonne d'actions rendue par le backend Syncfusion via `interaction.actionsFor`
> (`z_sf_data_grid_renderer.dart:464,497,693-695`). Le blocage Syncfusion de `pubspec:292` est
> **périmé** (IFFD en `^34.1.31`, `pubspec:141-149`) et `zcrud_list` serait bien la **seule** arête
> neuve (fermeture `{zcrud_core, zcrud_ui_kit}`, tous deux déjà déclarés).
> **Mais cette capacité doit servir un écran VIVANT** : si `AgentsScreen` est un jour rebranché,
> le portage réclamera alors — et pas avant — `listFields`, `cellsOf`, `editionBuilder`,
> `rowActions`, la conversion map → entité, et l'acceptation que la cellule d'actions custom
> (185 l.) devienne une liste de `ZRowAction` où l'inapplicable est **inerte, jamais masqué**
> (`z_row_governance.dart:44`).

---

## Annexe — Journal des mesures (tout est rejouable en lecture seule)

| # | Commande | Résultat retenu |
|---|---|---|
| 1 | `grep -n "class ZCrudScreen" …/z_crud_screen.dart` | `180` ✅ |
| 2 | `grep -n "" …/z_entity.dart \| sed -n '15,30p'` | ctor `:19`, `id` `:23`, `isEphemeral` `:26` (cité `:25`/`:28`) |
| 3 | `grep -rn 'DynamicListScreen' lib test` | 1 appelant (`agents_screens.dart:176`), 5 lignes de définition, 1 commentaire de test |
| 4 | équilibrage de parenthèses depuis `agents_screens.dart:176` | **fin à `:647`** → 472 l. |
| 5 | extraction des paramètres à profondeur 1 | **14** paramètres (voir § 2) |
| 6 | `grep -rn "\bAgentsScreen\b" lib \| grep -v AgentsScreens` | **0 site de construction** |
| 7 | `grep -rn "\bDynamicListField\b" lib` moins les 2 fichiers du périmètre | **14 sites** ; **9** hors `agents_screens.dart` |
| 8 | `grep -rn "class DynamicListField" lib` | **1** déclaration (`dynamic_list_field.dart:6`) |
| 9 | `grep -rn "isEphemeral" lib` | **RC=1**, aucun résultat (grep négatif) |
| 10 | `grep -rn "extends DynamicModel" lib \| wc -l` | **24** |
| 11 | `grep -rn "zcrud_list" lib test` | **aucun résultat** (grep négatif) ; dans `pubspec.yaml` : commentaires `:292`, `:463` seulement |
| 12 | `grep -n "^  syncfusion" pubspec.yaml` | `141-149`, tous `^34.1.31` |
| 13 | `grep -rn "rowActions\|ZRowAction" packages/zcrud_list/lib/` | **RC=1** — le symbole réel est `ZResolvedRowAction` (piège de grep, § 1.4) |
| 14 | `wc -l lib/data_crud/*.dart` | `dynamic_list_screen.dart` = **1 753** ✅ ; `dynamic_list_field.dart` = 37 ; `sub_list_screen.dart` = 555 |
| 15 | `grep -rn "DynamicTabsState" lib` | déclaration + `dynamic_list_screen.dart:450,573,580` + 1 **commentaire** `agents_screens.dart:173` |
| 16 | `grep -rn "import.*agents_screens" lib test` | `app_user.dart:8`, `test/m0/agents_filter_zcrud_test.dart:35` |

**Aucune écriture n'a été faite hors de ce fichier. Aucun test n'a été lancé, dans aucun dépôt.
Aucune clé ni secret n'a été lu ni cité.**
