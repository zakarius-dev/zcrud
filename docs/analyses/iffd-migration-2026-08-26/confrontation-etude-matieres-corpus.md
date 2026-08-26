# Confrontation — domaine « Étude : matières, documents, corpus » (IFFD) × socle zcrud v3.21.0

**Relevé du 2026-08-26.** Hôte `/home/zakarius/DEV/iffd`, branche `feat/migration-zcrud`,
HEAD `65d1af9`, arbre propre. Socle `/home/zakarius/DEV/zcrud/packages`, **v3.21.0**, 41 paquets.
`grep -c 'ref: v3.21.0' iffd/pubspec.yaml` → **48** : l'hôte est au dernier tag publié.

> **Aucun test n'a été lancé, dans aucun dépôt** (consigne). Tout ce qui suit vient de la lecture
> du **corps** des canaux (pas de leur seule dartdoc) et de mesures `grep`/`sed`/`wc` sur disque.
> Ce qui n'a pas été compilé est dit tel quel.

## Le chiffre qui cadre tout

| Mesure | Valeur |
|---|---:|
| Périmètre du domaine (6 répertoires) | **36 fichiers, 14 054 lignes** |
| Lignes `import 'package:zcrud_` dans ce périmètre | **5** |
| Paquets zcrud distincts qui y sont importés | **1** (`zcrud_core`) |
| Paquets zcrud déclarés au `pubspec.yaml` de l'hôte | 25 |

```
$ grep -rn "import 'package:zcrud_" lib/src/presentation/features/{subjects,documents,valuation_tools,ai_routers} lib/src/features/{subjects,corpus}
…/ai_routers/zcrud/ai_router_sub_list_seams.dart:28:import 'package:zcrud_core/zcrud_core.dart'
…/ai_routers/zcrud/ai_router_zcrud_edition.dart:47:import 'package:zcrud_core/zcrud_core.dart'
…/subjects/dialogs/subject_zcrud_edition.dart:156:import 'package:zcrud_core/zcrud_core.dart';
…/documents/dialogs/folder_document_zcrud_edition.dart:45:import 'package:zcrud_core/zcrud_core.dart';
…/valuation_tools/dialogs/valuation_tool_model_zcrud_edition.dart:75:import 'package:zcrud_core/zcrud_core.dart';
```

**Cinq lignes pour 14 054.** Aucune liste, aucun écran, aucun menu, aucune visionneuse,
aucun modèle du domaine ne touche le socle. Ce qui suit répartit ce constat en quatre verdicts.

---

## Correction apportée à la carte du domaine

La carte `carte-etude-matieres-corpus.md` compte **3** imports zcrud dans le périmètre initial
(4 répertoires) et signale le 4ᵉ hors périmètre. En incluant `valuation_tools/` et `ai_routers/`
— qu'elle intègre elle-même au domaine — le compte exact est **5** (`ai_router_sub_list_seams.dart:28`
est le cinquième, jamais cité). Ni la conclusion ni aucun verdict n'en dépendent.

---

## 1. DÉJÀ MIGRÉ — ce que l'hôte consomme vraiment

| # | Capacité | Canal du socle | Site chez l'hôte | Vérifié |
|---|---|---|---|---|
| A1 | **Déclaration de champ** (17 champs sur 4 formulaires) | `ZFieldSpec` / `EditionFieldType` / `ZValidatorSpec` / `ZTextConfig` (`zcrud_core/lib/src/domain/edition/z_field_spec.dart:47`) | les 4 jumeaux portés | `grep` des 5 imports ci-dessus |
| A2 | **Moteur d'édition granulaire** | `ZFormController` + `ZEditionSubmitController` + `DynamicEdition` (`…/presentation/edition/dynamic_edition.dart:296`) | `folder_document_zcrud_edition.dart:156,162,208` | corps lu |
| A3 | **Assistant à étapes** | `ZStepperEdition` + `ZEditionStep` | `subject_zcrud_edition.dart:718`, `ai_router_zcrud_edition.dart:554` | lignes lues |
| A4 | **Sous-listes + ACL de sous-liste** | `ZSubListConfig` / `ZSubListSeams` / `ZSubListHeaderView` | `ai_router_zcrud_edition.dart:512-531` (7 sous-listes, seams `countOf` vivant) | corps lu |
| A5 | **Relations déclaratives à cascade** | `ZRelationConfig.filterKeys` + `ZRelationSourceRegistry` (`z_field_config.dart:746,763`) | `subject_zcrud_edition.dart:288-298`, `:352-374` | — |
| A6 | **Scope d'injection unique, monté au-dessus du `Navigator`** | `ZcrudScope` (25 seams) | `iffd/lib/main.dart:270` — `MaterialApp.builder` | corps lu, cf. §2/M1 |
| A7 | 🔴 **Catalogue de routes IA — la LECTURE** | `ZChatRouteCatalogShape.suffixPairs` + `ZChatRouteCatalogDecoder` + `ZChatInMemoryRouteCatalog` + `taskAliases` (v3.10.0) | `iffd/lib/ai_assistant/zcrud/notebook_route_catalog_iffd.dart` (**106 lignes** pour 13 routes) | fichier lu en entier |
| A8 | **Document d'étude ↔ entité socle** | `ZStudyDocument` (`zcrud_document`) | `z_backed_folder_document_repository.dart` (698 l.) — **drapeau à `false`** (`folder_providers.dart:56-63`) | — |
| A9 | **Menu d'actions d'item** | `ZItemActionsMenu` / `ZItemAction` / `ZMenuEntryTile` | **1 seul fichier** : `folders/zcrud/folder_actions_menu_zcrud.dart` — **aucun du périmètre** | `grep -rlw` → 1 |
| A10 | **Carte de dossier + compteurs** | `ZDefaultFolderCard` (4 f.) / `ZFolderCardCount` (1 f.) | hors périmètre (`folders/`) | `grep -rlw` |

**A7 est le point le plus mal compris du dossier.** Le routage IA d'IFFD n'est pas « à migrer » :
il **est** migré. Ce qui reste est l'**édition** du routeur — et elle bute sur un manque réel (§3/G4).

**Trois des quatre jumeaux tournent déjà sur le socle dans le binaire courant** :
`main.dart:201-210` lève 8 bascules dont `subject`, `valuationTool`, `aiRouterEdition` ;
`folderDocument` (`z_qa_flags.dart:665`) ne l'est pas.

---

## 2. 🔴 MIGRABLE AUJOURD'HUI — le socle sait déjà, l'hôte l'ignore

Chaque ligne porte : l'**API exacte**, son `fichier:ligne` dans `packages/`, la preuve que son
**corps** fait ce qu'on lui prête, et les lignes d'hôte que l'adoption supprime.

### M1 — La coquille des 4 formulaires portés → `presentFormEdition` · **≈ 420 lignes**

**API** : `presentFormEdition(BuildContext, {required List<ZFieldSpec> fields, Map<String,Object?>? initialValues, String? title, List<ZEditionStep> steps, ZStepperConfig stepperConfig, ZFormBodyBuilder? bodyBuilder, ZFormController? formController, bool readOnly, …})`
→ `packages/zcrud_screen/lib/src/presentation/present_form_edition.dart:234` (**22 paramètres**, `:236-256`).

**Corps vérifié** : signature lue `:234-257`. Rend `Future<Map<String, dynamic>?>` — la map
**validée**, ou `null`. `steps`/`stepperConfig` sont bien présents (`:249-250`) : le mode assistant
est atteignable. `bodyBuilder` et `steps` sont exclusifs, et l'assertion `:258-262` **dicte
elle-même l'échappatoire** : « Montez le `ZStepperEdition` vous-même dans le `bodyBuilder` ».

**Le gabarit court existe DANS LA MÊME APPLICATION** :

| | `folder_document_zcrud_edition.dart` | `workflow/screens/zcrud/task_list_zcrud_edition.dart` |
|---|---:|---:|
| champs déclarés | **1** | **2** |
| lignes du fichier | **212** | **117** |
| `Scaffold(` / `AppBar(` | 1 / 1 | **0 / 0** |
| appels `presentFormEdition(` | **0** | 1 (`:105-117`) |

**Mesure des coquilles à retirer** (de la déclaration du `Screen` à EOF) :

| Jumeau | Coquille | Lignes |
|---|---|---:|
| `subject_zcrud_edition.dart` | `:605` → `:728` | **124** |
| `folder_document_zcrud_edition.dart` | `:122` → `:212` | **91** |
| `valuation_tool_model_zcrud_edition.dart` | `:232` → `:348` | **117** |
| `ai_router_zcrud_edition.dart` | `:436` → `:685` | **250** |
| **Total** | | **582** |

Chaque coquille est la même : `State` + `late final _fields/_controller/_submit` + `initState` +
`dispose` + `_onSave` + `IffdZcrudScope` + `Scaffold` + `AppBar` + `Semantics/IconButton
« Enregistrer »` + le corps. Corps lu à `folder_document_zcrud_edition.dart:146-212`.

🔴 **Le blocage historique est LEVÉ, et c'est l'hôte qui l'a levé.** `presentFormEdition` pousse
une route ; un `InheritedWidget` monté dans l'écran appelant n'est pas hérité par elle. L'hôte a
donc monté `IffdZcrudScope` **une fois, au `MaterialApp.builder`** — `iffd/lib/main.dart:270`,
avec la justification mesurée en commentaire (`:244-268` : « son champ TÉLÉPHONE cherchait
`ZPhoneFieldWidget` dans un registre absent »). Toutes les routes en héritent.

**Estimation de gain** : 582 − ≈ 160 conservés (4 fonctions `presentXEdition`, plus le
`bodyBuilder` du routeur IA qui garde son `IffdZcrudScope(subListSeams:)` local — légitime,
`main.dart:266-268` — et son `ZStepperEdition`) ⇒ **≈ 420 lignes**.

⚠️ **Ce que je n'affirme pas** : je n'ai pas compilé. Ce qui est prouvé, c'est que 12 fichiers de
`lib/` portent `ZFormOnly` et que `presentFormEdition(` est appelé sur **16 sites** — dont zéro
dans ce périmètre (`grep -c` par fichier, table §5).

---

### M2 — Les tuiles d'action → `ZItemAction` / `ZItemActionsMenu` · **≈ 370 lignes**

**API** : `ZItemAction({required ZItemActionKind kind, required String label, required IconData icon, VoidCallback? onSelected, String? id, bool permitted = true, String? disabledReason, ZItemActionState? state, String? stateSemanticLabel, int? count})`
→ `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:147` ;
menu : `:283` ; `enum ZItemActionKind` : `:70`.

**Corps vérifié** (`:147-200`) : trois assertions réelles — `onSelected`/`disabledReason`
exclusifs, `state`/`stateSemanticLabel` indissociables (« l'état ne soit jamais porté par la seule
couleur »), `count >= 0`. `permitted: false` ⇒ **action ABSENTE**, pas grisée.

**Le vocabulaire couvre le périmètre** : `open`, `rename`, `move`, `share`, `duplicate`, `delete`,
**`custom`** (`:72-96`). Les 6 actions IA d'IFFD passent par `custom` + un `id` propre — la
**présentation** n'est donc pas un obstacle (la **gouvernance** l'est : §3/G2).

**Mesure côté hôte** :

```
$ grep -rn "ZItemAction" lib/src/presentation/features/{subjects,documents,valuation_tools} ; echo RC=$?
RC=1
$ grep -c 'ListTile(' …/documents/widgets/folder_documents_actions_dialog_widget.dart   → 22
$ grep -c 'ListTile(' …/valuation_tools/widgets/valuation_tool_model_actions_dialog_widget.dart → 7
```
Plus 2 tuiles dans `subject_actions_dialog_widget.dart` ⇒ **31 tuiles** dans le périmètre, sur le
patron `Material > Opacity > ListTile(leading, title, enabled, onTap)` (≈ 12 l./tuile mesurées sur
`valuation_tool_model_actions_dialog_widget.dart:92-145`) ⇒ **≈ 370 lignes**.

Le socle est déjà consommé pour cela **ailleurs dans la même app** (`folder_actions_menu_zcrud.dart`,
241 l.) : c'est un canal connu de l'hôte, ignoré ici.

---

### M3 — `GridView.count` → `ZAdaptiveGrid.builder` · **≈ 60 lignes, et la virtualisation**

**API** : `ZAdaptiveGrid.builder({required int itemCount, required IndexedWidgetBuilder itemBuilder, required double minItemWidth, double spacing, double? runSpacing, double? itemHeight, double? aspectRatio, int minColumns, int? maxColumns, EdgeInsetsGeometry? padding})`
→ `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart:89`,
exporté par le barrel `zcrud_responsive.dart:61`.

**Corps vérifié** (`:85-100`) : constructeur **public**, `itemCount <= 0 ⇒ SizedBox.shrink()`
(AD-10), exclusivité avec le ctor `children:` **par construction**.

🔴 **L'hôte écrit le contraire, noir sur blanc** :
`iffd/lib/src/presentation/features/folders/zcrud/study_tools_zcrud_adapter.dart:68-69` —
« `ZAdaptiveGrid.builder` (virtualisé) **n'est pas exposé** ». C'est faux depuis le 2026-07-17.

**Sites du périmètre** (`grep -rn 'GridView.count'`) : **4** —
`subjects_page.dart:318` (sous `SingleChildScrollView` + `NeverScrollableScrollPhysics` : la
grille des matières est **entièrement construite** à chaque rendu),
`ai_routers_page.dart:745`, `valuation_tool_model_actions_dialog_widget.dart:569`,
`document_viewer/color_palette.dart:120`.

La valeur ici n'est pas le nombre de lignes : c'est que **quatre grilles cessent d'être
intégralement construites**.

---

### M4 — Le contrôle d'entité `ZEntity` → **UNE ligne**

**API** : `abstract class ZEntity { const ZEntity(); String? get id; bool get isEphemeral => id == null; }`
→ `packages/zcrud_core/lib/src/domain/contracts/z_entity.dart:17-27`. **Corps lu en entier :
c'est tout le contrat.**

Côté hôte, `iffd/lib/src/domain/models/dynamic_model.dart:3-6` :
```dart
abstract class DynamicModel {
  final String? id;
  const DynamicModel({this.id});
```
Le champ `final String? id` satisfait le getter abstrait ; les deux ont un constructeur `const` ;
`DynamicModel` n'étend rien. ⇒ `abstract class DynamicModel extends ZEntity` est **une ligne**,
et elle rend **les 45 entités du dispatcher** (`data_functions.dart:336-409`) éligibles à
`ZCrudSource`, `ZCrudScreen`, `ZAcl.can(target:)` et `ZRepository`.

⚠️ **Non compilé.** C'est une lecture de contrat, pas un build. Le risque résiduel nommé :
`isEphemeral` deviendrait hérité (aucun conflit trouvé — `grep -n 'isEphemeral' dynamic_model.dart`
→ RC=1).

---

### M5 — Les 3 listes maison → `ZCrudScreen` + `ZCrudSource.items` · **≈ 1 100 lignes (conditionné à G3)**

**API** : `ZCrudScreen<T extends ZEntity>` → `packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart:180`,
**54 paramètres**. `ZCrudSource.items(List<T>, {onSave, onSoftDelete, onRestore, onPurge, isDeleted})`
→ `z_crud_source.dart:109`.

**Corps vérifié** — trois points qui décident :

1. 🔴 **La voie `items` évite tout adaptateur de dépôt.** Lue à `z_crud_source.dart:104-115` : la
   liste arrive « déjà chargée (flux de l'hôte) », les écritures sont des **callbacks optionnels**.
   IFFD charge déjà ses listes par `StreamBuilder` et écrit par `CrudRepository<T>` rendant
   `DataState` : **aucune conversion vers `Either<ZFailure,T>` n'est requise sur cette voie.**
   C'est ce qui rend M5 réaliste — contrairement à la voie `repository`.
2. **`ZListTab` porte l'ACL par onglet ET le compteur.** `packages/zcrud_core/lib/src/presentation/list/z_list_tab.dart` :
   `acl` `:186`, `countOf` (`ValueListenable<int>`) `:218`, `baseFilters`, `canCreate`, `titles`.
   C'est exactement la forme de `subjects_page.dart:487` (une ACL par filière × cycle, jusqu'à 12).
   ⚠️ **Nuance mesurée** (dartdoc `:160-186`) : l'ACL d'onglet **retire seulement**, la composition
   est une **conjonction**. IFFD compose par `.or()` (`subjects_page.dart:396-398`). L'hôte doit
   donc calculer sa disjonction **avant** et poser un `ZAcl` unique par onglet — expressible, mais
   ce n'est pas le socle qui fait le `.or()`.
3. **`sort: []` (défaut) ⇒ « l'ordre est celui de la source »** (`z_list_query_policy.dart:181`) :
   le tri par identifiant segmenté d'IFFD survit **en tant qu'ordre de source** (§3/G6).

**Une seule assertion dans tout `ZCrudScreen`** (`:1122`, `actions` vs `actionsBuilder`) — rien
n'interdit `items` + `tabs`.

**Face de l'hôte** : `subjects_page.dart` **941** + `ai_routers_page.dart` **803** +
`ValuationToolsGridView` **345** = **2 089 lignes**, `ZCrudScreen` à **0 fichier**
(`grep -rlw ZCrudScreen lib` → 0).

🔴 **Conditionné** : `ZCrudScreen` n'offre **aucun créneau d'état vide** (§3/G3). L'adoption
telle quelle perd les 155 lignes d'état vide illustré de `subjects_page.dart:128-282`. Gain
retenu ≈ **1 100** (≈ 53 %), le reste étant cartes, illustrations et règles propres.

---

### M6 — Le corpus par codegen · **≈ 1 230 lignes**

**API** : `@ZcrudModel(kind:, fieldRename:)` (`packages/zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart:151`)
+ `@ZcrudField` (18 paramètres, `zcrud_field.dart:52`) + `@ZcrudId`.
Émissions (`packages/zcrud_generator/lib/src/zcrud_model_generator.dart`, en-tête `:7-59`) :
`_$XxxFromMap` **défensif**, `extension XxxZcrud` → `toMap()`/`copyWith()` **à sentinelle**,
`$XxxFieldSpecs`, `registerXxx(ZcrudRegistry)`, `$XxxTimestampFields`.

**La duplication est vérifiée au mot près** :
```
$ grep -n 'extends ValuationToolModel' lib/src/domain/models/valuation/valuation_tool_model.dart
163: Decision   205: AvisConsultatif   247: Commentaire   289: NoteExplicative
331: EtudeDeCas 373: Etude             415: ArticleGATT   457: ArticleCodeDuGATT
499: NoteInterpretative                541: Annexe
```
**10 sous-classes de 42 lignes chacune**, strictement identiques hors le nom du type (corps de
`Decision:163-201` lu et comparé à la base `:5-53`) : constructeur, `copyWith`, `fromMap`,
`toString` — **420 lignes pour zéro différence de comportement**.

| Bloc | Sites | Lignes | Preuve |
|---|---:|---:|---|
| Sous-classes | 10 | **419** | ci-dessus |
| Dépôts Firebase | 10 | **129** | `firebase_models_repositories_impls.dart:306-434` |
| Providers Riverpod (+ généré) | 10 | **48 + 650** | `corpus_providers.dart:26-89` lu |
| Dispatcher de type | 10 | **22** | `valuation_tool_model_repository.dart:46-68` |
| Table de fabriques (2ᵉ fois) | 10 | **12** | `valuation_tool_model.dart:65-79` lu |

⚠️ **Une différence réelle, à ne pas écraser** : sur les 10 dépôts, **9 déclarent
`allowedOperations: Crud.defaultFolderContentCrudOperations` et un seul — `ArticleGATT` —
`Crud.valuationToolCrudOperations`** (mesuré ligne à ligne). C'est une ACL par `kind`, pas une
raison de garder 10 types.

🔴 **Les 10 collections Firestore ne bloquent PAS.** `getFirebaseCollectionName<T>({String? collectionName})`
(`iffd/lib/src/utils/functions/databases_functions.dart:8`) rend
`collectionName ?? FIREBASE_COLLECTION_NAMES[T] ?? T.toString()` : le **paramètre d'override
existe déjà**. Un `ZValuationText { kind, identifier, title, description, content }` peut donc
adresser les 10 collections par son `kind`, **sans migration de données**.

Gain : 419 + 129 + 48 + ≈ 585 (9 providers générés sur 10) + 22 + 12 ⇒ **≈ 1 215**, arrondi
**≈ 1 230** avec les entrées de `fromMap`/`tabsTypes`/`tabsTitles`.

⚠️ Prérequis d'adoption, pas un manque du socle : `zcrud_generator` n'est pas déclaré
(`grep -n zcrud_generator iffd/pubspec.yaml` → **RC=1**) et `@ZcrudModel` n'existe nulle part
(`grep -rn '@ZcrudModel' iffd/lib` → **RC=1**).

---

### M7 — La table de 45 fabriques → `ZcrudRegistry` · couplé à M6

**API** : `ZcrudRegistry.register<T>(String kind, {required fromMap, required toMap, List<ZFieldSpec> fieldSpecs})`
→ `packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart:116` ;
résolution **par Type** : `kindOf<T>()` `:186`, `kindOfType(Type)` `:207`, table interne
`_kindsByType` `:113`.

**Corps vérifié** : c'est le `kindOfType` qui rend le remplacement possible — le dispatcher
d'IFFD (`data_functions.dart:314-413`, **45 entrées `Map<Type, Function>` réallouées à chaque
appel**, `:336`) est générique sur `T`, et `kindOf<T>()` lui donne le pont. Sans lui, le registre
(clé `String`) n'aurait pas été substituable à une table clé `Type`.

---

### M8 — L'en-tête chercheuse → `ZSearchableAppBar` · **≈ 40 lignes dans le périmètre**

**API** : `ZSearchableAppBar({required Object title, String? subtitle, Widget? leading, List<ZAppBarAction> actions, ZAppBarSearchConfig? search, PreferredSizeWidget? bottom, String? gradientKey, …})`
→ `packages/zcrud_ui_kit/lib/src/presentation/z_searchable_app_bar.dart:14`.

**Corps vérifié** (`:1-53`) : `implements PreferredSizeWidget`, **détient son propre état de
recherche** (« aucun contrôleur externe requis »), `bottom` participe à la hauteur préférée (donc
la `TabBar` des filières passe), rebuild limité à la tranche app-bar.

Côté hôte : `DynamicSearcheableAppBar<C>` (372 l.) + `DynamicListSearchController` et **16
sous-classes vides** (`dynamic_list_search_controller.dart:35-71`, 37 l.), enveloppé dans
`PreferredSize(preferredSize: Size.fromHeight(kToolbarHeight * n), …)` — **3 sites dans le
périmètre**, 21 dans l'app. `ZSearchableAppBar` à **0 fichier**.

---

### M9 — La suppression de matière sans confirmation → `showZConfirmDialog`

**API** : `showZConfirmDialog(...) → Future<bool>` (`packages/zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:129`),
`title` **optionnel** (`:51`), libellés via `MaterialLocalizations`, ton `ZConfirmTone`.
Également porté en déclaration par `ZCrudScreen.confirmDestructive` (`z_crud_screen.dart:930`,
défaut `true`).

`subject_actions_dialog_widget.dart:51-60` appelle `deleteSubject` **directement** — alors que le
document (`folder_documents_actions_dialog_widget.dart:670-687`) et le corpus confirment.
Gain en lignes : **nul**. Gain réel : un défaut de comportement corrigé — et un **avertissement de
QA à écrire**, puisque adopter `ZCrudScreen` changerait ce comportement sans qu'on le demande.

---

## 3. MANQUE AU SOCLE — preuve d'absence montrée

### G1 🔴 — `ZDocumentAnnotationKind` n'a que **2** valeurs. **BLOQUE le plus gros gisement.**

```
$ grep -rniE 'underline|strikethrough|squiggly|freehand' packages/zcrud_document/lib/
z_annotation_panel.dart:184:   child: InkWell(…)      ← "Ink"Well, pas "ink" d'annotation
z_annotation_toolbar.dart:211: child: InkWell(
z_annotation_toolbar.dart:272: child: InkWell(
$ grep -rn 'enum ZDocumentAnnotationKind' packages/*/lib/
zcrud_document/lib/src/domain/z_document_annotation_kind.dart:23   ← unique déclaration
```
Corps lu en entier : `enum ZDocumentAnnotationKind { highlight, stickyNote }` — **deux**
constantes, l'ordre étant normatif (repli défensif du générateur sur la première).

Face à cela, IFFD **utilise quatre modes de marquage de texte**, mesurés :
```
$ grep -rn 'PdfAnnotationMode\.' lib/src/presentation/features/documents/ | …
8 underline · 8 strikethrough · 8 squiggly · 8 highlight · 3 none
```
plus `stickyNote` porté par le modèle (`folder_document_annotation.dart:16-24`).

Second manque, dans le même canal : `ZAnnotationToolController`
(`packages/zcrud_document/lib/src/presentation/z_annotation_tool_controller.dart:53`) ne détient
que **deux** tranches — `selectedKind` et `selectedColorKey` (corps lu en entier, 87 lignes).
**Ni opacité, ni annuler/refaire.** IFFD porte les trois (`annotation_toolbar.dart` 837 l.,
`color_palette.dart` 483 l. avec opacité).

**Forme du canal manquant** : (1) trois valeurs d'enum **additives** — `underline`,
`strikethrough`, `squiggly` — ajoutées **après** `highlight` pour préserver le repli défensif ;
(2) deux tranches de plus sur le controller (`opacity`, et un port d'historique
`ZAnnotationHistory` — annuler/refaire n'est pas un état de barre d'outils).
**Paquet** : `zcrud_document`.
**Pourquoi l'hôte ne peut pas s'en passer** : ses 3 348 lignes de visionneuse, **gardées par zéro
test**, portent 4 modes que le socle ne sait pas nommer. Sans les nommer, l'annotation persistée
perd son type — pas son style : son **sens**.

⚠️ Ce qui **n'est pas** un manque : la palette. `ZColorPalette({required List<String> keys, …})`
(`zcrud_study_kernel/lib/src/domain/z_color_palette.dart:86`) accepte un registre de clés
**arbitraire** — les 18 couleurs de la barre et les 52 du nuancier sont exprimables en clés
sémantiques résolues par `ZcrudScope.colorKeyResolver`.

⚠️ Ce qui **n'est pas** un manque non plus : `ZDocumentAnnotation` porte déjà
`rects: List<ZAnnotationBounds>?` (`z_document_annotation.dart:180`), le pendant exact des
`textLines` d'IFFD. La coquille `ZDocumentViewerChrome` (`z_document_viewer_chrome.dart:57`,
corps lu : `Column` à 4 créneaux + `Divider` + navigation) est **honnête sur son périmètre** —
elle ne prétend pas rendre un PDF.

### G2 🔴 — `ZAcl.can` prend un **enum fermé** de 11 actions ; IFFD en gouverne 17.

```
$ grep -niE 'String action|customAction|actionKey' packages/zcrud_core/lib/src/domain/ports/z_acl.dart ; echo RC=$?
RC=1
```
Signature lue (`z_acl.dart:101`) : `bool can(ZCrudAction action, {ZEntity? target, String? collectionId})`.
`ZCrudAction` (`:28-61`) : `view, create, update, delete, restore, copy, archive, publish, clear,
validate, history` — **11**.

`iffd/lib/src/domain/entities/crud.dart:6-25` : **17** valeurs — les 11 équivalentes plus
**`move`** et **six actions IA** (`aiGenerate`, `aiSummary`, `aiMindMap`, `aiFlashCard`,
`aiExplain`, `aiChat`, toutes marquées `extended: true`). Elles sont **réellement gouvernées** :
`valuation_tool_model_actions_dialog_widget.dart:149` — `userPermissions?.can<T>(Crud.aiMindMap) == true`.

**Forme** : une **clé opaque** plutôt que sept valeurs d'enum — soit `ZCrudAction.custom(String)`,
soit un second verbe `bool canCustom(String actionKey, {ZEntity? target, String? collectionId})`
avec repli sûr (AD-10, AD-4 : nature ouverte). Sept valeurs figées referaient le même mur à la
huitième.
**Paquet** : `zcrud_core`.
**Bloque** : la gouvernance des actions IA par `ZCrudScreen.rowAcl` / `actionAclMode`. La
**présentation**, elle, passe (`ZItemAction.permitted` est un `bool` que l'hôte calcule, §2/M2) —
c'est le **port** qui n'a pas le vocabulaire, pas le widget.

### G3 🔴 — Aucun créneau d'état vide sur `ZCrudScreen` ; `ZEmptyState` n'a pas d'illustration.

```
$ grep -niE 'illustration|emptyBuilder|emptyState|emptyWidget' \
    packages/zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart \
    packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart
z_state_widgets.dart:3   /// `ZEmptyState` / `ZLoadingState` / … (dartdoc)
z_state_widgets.dart:31  class ZEmptyState extends StatelessWidget {
z_state_widgets.dart:33    const ZEmptyState({
```
**Zéro ligne dans `z_crud_screen.dart`** (4 428 lignes) : l'écran assemblé n'expose aucun créneau
d'état vide. Et `ZEmptyState` (corps lu `:31-68`) n'accepte qu'une `IconData? icon` — pas de
`Widget`.

IFFD rend un état vide **illustré** : cercle 180 dp à dégradé + deux cercles concentriques +
`ShaderMask` sur une icône 64 dp + titre + description + bouton à dégradé —
`subjects_page.dart:128-282` (**155 lignes**), répété sur **6 écrans**.

**Forme** : `ZCrudScreen.emptyBuilder` (le créneau qui manque), et/ou
`ZEmptyState.illustration: Widget?` prenant le pas sur `icon`.
**Paquet** : `zcrud_screen` / `zcrud_ui_kit`.
**Bloque** : l'adoption de `ZCrudScreen` **sans perte visuelle** (§2/M5) — donc, indirectement,
≈ 1 100 lignes.

### G4 🔴 — Pas d'encodeur inverse `ZChatRouter → suffixPairs`.

```
$ grep -rniE 'encodeTo|toSuffixPairs|encodeShape|writeShape|encodeRouter' \
    packages/zcrud_chat_kernel/lib/src/domain/route/ ; echo RC=$?
RC=1
```
`ZChatRouter.toMap()` (`z_chat_router.dart:176-195`) écrit la forme **canonique** : `out['routes']`
`:191`, `out['fallbacks']` `:185`. IFFD persiste la forme **plate** : 13 couples
`<tâche>Model` / `<tâche>FallbackModels`, et ses replis sont des **`List<String>`**
(`ai_models.dart:195,199,202,206,209,212,215,218…`) là où
`$ZChatModelRefFieldSpecs` (`z_chat_model_ref.dart:122`) décrit des maps
`{provider_id?, model_id}`.

Conséquence exacte : le socle porte **le formulaire complet du routeur sans une ligne d'hôte** —
`$ZChatRouterFieldSpecs` (`z_chat_router.dart:340-378`, **corps lu** : 10 `ZFieldSpec` dont deux
`subItems` imbriqués) + `registerZChatRouter` (`:385`, corps lu : `registry.register<ZChatRouter>`
avec `fieldSpecs`) — mais **l'adopter changerait la forme des documents Firestore**. La lecture
est symétrique (§1/A7) ; **l'écriture ne l'est pas**.

**Forme** : une méthode `encode(ZChatRouter) → Map<String,dynamic>` sur `ZChatRouteCatalogShape`,
strict pendant de `ZChatRouteCatalogDecoder`, y compris l'inversion des `taskAliases` et la
sérialisation d'un `ZChatModelRef` en jeton `"provider:model"` (le lecteur existe déjà :
`_fromToken`, `z_chat_model_ref.dart:131`).
**Paquet** : `zcrud_chat_kernel`.
**Bloque** : D7 (13 × 6 recopies de la liste des tâches dans `ai_models.dart:194-310`, ≈ 182 l.)
et D8 (**14 appels** à `buildFallbackModelsField`, `ai_routers_dialogs.dart:540-605`, 66 l.) —
soit **≈ 248 lignes**, plus le jumeau porté de 685 l. dont la moitié redéclare ce que
`$ZChatRouterFieldSpecs` porte déjà.
L'hôte l'a **anticipé** : `notebook_route_catalog_iffd.dart:22-24` — « Le jour où le modèle porte
`isActive`, `buildChatRouterFirestoreRepository` remplacera ce pont ».

### G5 — Aucune entité « matière » (**non bloquant**)

```
$ grep -rn 'class ZSubject\|class ZStudySubject\|class ZCourse\|class ZDiscipline\|class ZCurriculum' packages/*/lib/ ; echo RC=$?
RC=1
$ grep -rn 'class ZValuationText\|class ZReferenceText\|class ZCorpus\|class ZLegalText' packages/*/lib/ ; echo RC=$?
RC=1
```
`ZStudyFolder` (`zcrud_study_kernel/…/z_study_folder.dart:77`) ne porte pas de `subjectId` ;
IFFD le loge dans `extra`.

**Forme** : je **ne recommande pas** une entité `ZStudySubject` au socle — la « matière » d'IFFD
porte filières, cycles, agents IA experts et instructions personnalisées, toutes règles d'école.
Le canal juste existe déjà : `ZExtensible.extra` + `@ZcrudModel` chez l'hôte. **Non bloquant** :
`DynamicModel extends ZEntity` (§2/M4) + `ZCrudSource.items` suffisent à l'écran.

### G6 — Aucun comparateur de liste injectable (**non bloquant, dégradation ciblée**)

```
$ grep -niE 'Comparator|compareBy|sortBuilder' packages/zcrud_screen/lib/src/presentation/z_list_query_policy.dart ; echo RC=$?
RC=1
```
`ZListQueryPolicy.sort` est une `List<ZSort>` (champ + direction) — lexicographique.
Le tri d'IFFD découpe l'identifiant sur `.`, convertit chaque segment en entier et compare premier
puis dernier (`valuation_tool_model_actions_dialog_widget.dart:481-505`) : « 3.10 » après « 3.2 ».

**Ce qui sauve** : `sort: []` (défaut) ⇒ « l'ordre est celui de la source »
(`z_list_query_policy.dart:181`) — sur la voie `items`, l'ordre de l'hôte est **conservé**.
Ce qui se perd : ce tri ne peut pas être proposé comme **tri de colonne** à l'usager.
**Forme** : `ZListQueryPolicy.comparator` (`int Function(T,T)?`). **Paquet** : `zcrud_screen`.

---

## 4. RESTE À L'HÔTE — règle métier, pas préférence

| # | Règle | Preuve | Pourquoi le socle ne doit pas la porter |
|---|---|---|---|
| H1 | **Un identifiant Firestore en dur décide d'un bouton** — la matière « valeur en douane » ouvre le « Code du GATT ». **4 sites en littéral inline** | `subject_details_page.dart:307`, `folder_details_page.dart:1187`, `public_folders_details_page.dart:519`, `folder_flashcards_list_page.dart:957` | C'est une **donnée**, pas une structure. À nommer côté hôte **avant** tout portage — le porté le fait déjà (`kFolderFlashcardsFilterValuationSubjectId`, `folder_flashcards_filter_zcrud_edition.dart:163`) |
| H2 | **Le corpus est un fond de constantes Dart complété par Firestore** — les 992 lignes de `utils/constants/valuation_tools/` sont la base ; le flux ne fournit qu'un remplacement d'`id`/`title` ; un item en ligne sans jumeau local **n'apparaît jamais** | `valuation_tool_model_actions_dialog_widget.dart:337-378` | Grep négatif socle montré (`localFirst\|mergedSource\|localPriority\|overlaySource` → **RC=1**). Une source fusionnée local-prioritaire avec appariement par `identifier` est une politique éditoriale |
| H3 | **ACL par type × filière × cycle, composée par `.or()`** — jusqu'à 12 ACL pour une entité, plus l'année académique dans la clé | `subjects_page.dart:396-398` ; `subject_model_dialogs.dart:200` (`AuditeurIffd${annee}_${filiere}`) | `ZListTab.acl` **retire seulement** (dartdoc `:160-176`) : la disjonction et la fabrication de clé restent à l'hôte |
| H4 | **Les drapeaux de bascule legacy/porté** — **55** `const bool k*Default`, **67** `Provider<bool>`, **52** entrées dans `z_qa_flags.dart` | `folder_document_zcrud_edition.dart:49-67` est le gabarit | Échafaudage de migration (*strangler fig*), **temporaire par construction** — il disparaît avec le legacy |
| H5 | **La cascade de matière EFFACE** — vider « Filières et cycles » remet l'expert par défaut à `null`, et le modèle doit distinguer « non fourni » de « mis à `null` » | sentinelle `_undefined` `subject_model.dart:15,151,163` ; `preserveNullKeys` `subject_zcrud_edition.dart:673` | Le socle porte déjà le mécanisme (`copyWith` à sentinelle, `preserveNullKeys`) ; **quel champ efface quel autre** est la règle métier |
| H6 | **Le corpus est 100 % markdown, jamais Delta** | `IffdRichTextCodec` (193 l.) ; `z_iffd_field_registry.dart:20` — le défaut `ZDeltaCodec` viderait **~11 400 valeurs** | `ZCodec` est justement pluggable pour cela (AD-7) |
| H7 | **Code mort du domaine — 543 lignes** | `SubjectDetailsController` : `grep -rn` → 2 occurrences, **toutes deux dans son propre fichier** (`:9`, `:12`). `DocumentSelectorDropdown` : 5 occurrences, **toutes dans son propre fichier**, et **non exporté** par `documents.dart`. + `subject_custom_assistant_page.dart` (54 l., seul appel commenté) + `features/documents/documents_module.dart` (**0 octet**) | Ménage d'hôte |
| H8 | **6 dépôts adossés zcrud écrits, tous derrière un drapeau à `false`** (exam 912, mindmap 806, flashcard 797, folder 772, document 698, note 663 = **4 648 l.**) | `folder_providers.dart:40,56,72,88` | Décision de bascule de l'hôte, pas du socle |

---

## 5. Tableau des greps négatifs montrés

| Affirmation d'absence | Commande | RC |
|---|---|---|
| `ZAnnotationToolbar` / `ZAnnotationPanel` / `ZDocumentViewerChrome` inconnus de l'hôte | `grep -rlw <sym> iffd/lib` | **0 fichier** chacun |
| `ZCrudScreen`, `ZCrudSource`, `ZListTab`, `ZEmptyState`, `ZContentStateView`, `ZCountBadge`, `ZConfirmDialog`, `showZConfirmDialog`, `ZSearchableAppBar`, `ZcrudRegistry`, `ZRepository`, `ZDiscardChangesGuard`, `ZToaster`, `ZChatRouteGate`, `ZDocumentAnnotation` | `grep -rlw <sym> iffd/lib` | **0 fichier** chacun |
| `ZItemAction` absent du périmètre | `grep -rn ZItemAction …/{subjects,documents,valuation_tools}` | **RC=1** |
| Codegen jamais adopté | `grep -rn '@ZcrudModel' iffd/lib` ; `grep -n zcrud_generator iffd/pubspec.yaml` | **RC=1** / **RC=1** |
| Pas de mode d'annotation `underline`/`strikethrough`/`squiggly` au socle | `grep -rniE '…' packages/zcrud_document/lib/` | 3 hits, **tous `InkWell`** |
| Pas d'action ACL opaque | `grep -niE 'String action\|customAction\|actionKey' z_acl.dart` | **RC=1** |
| Pas de créneau d'état vide sur `ZCrudScreen` | `grep -niE 'illustration\|emptyBuilder\|emptyState' z_crud_screen.dart` | **0 ligne** |
| Pas d'encodeur inverse de routeur | `grep -rniE 'encodeTo\|toSuffixPairs\|encodeShape\|writeShape\|encodeRouter' route/` | **RC=1** |
| Pas d'entité matière ni corpus au socle | `grep -rn 'class ZSubject\|…\|class ZValuationText\|…' packages/*/lib/` | **RC=1** / **RC=1** |
| Pas de tri segmenté ni de source fusionnée au socle | `grep -rniE 'segmentedSort\|naturalSort\|…' ; '…localFirst\|mergedSource…'` | **RC=1** / **RC=1** |
| Pas de comparateur injectable | `grep -niE 'Comparator\|compareBy\|sortBuilder' z_list_query_policy.dart` | **RC=1** |
| `isEphemeral` ne collisionne pas chez l'hôte | `grep -n isEphemeral iffd/…/dynamic_model.dart` | **RC=1** |

---

## 6. Synthèse — par rapport « lignes supprimées / risque »

| Rang | Levier | Lignes | Risque | Prérequis |
|---:|---|---:|---|---|
| 1 | **M6** — corpus par codegen | **≈ 1 230** | **faible** — comportement déjà uniforme (9/10 dépôts identiques), **testé** (`test/w7p/`, 984 l.), override de collection déjà présent | déclarer `zcrud_generator` |
| 2 | **M1** — coquilles de formulaire → `presentFormEdition` | **≈ 420** | **très faible** — canal déjà consommé sur 16 sites, scope racine déjà monté | aucun |
| 3 | **M2** — tuiles d'action → `ZItemAction` | **≈ 370** | faible — canal déjà consommé (1 fichier) | aucun |
| 4 | **M5** — 3 listes → `ZCrudScreen` | ≈ 1 100 | **moyen** — 🔴 **conditionné à G3** | M4 (1 ligne) + G3 |
| 5 | **M3/M8/M7/M9** | ≈ 100 | faible | M6 pour M7 |
| — | **Visionneuse PDF** (3 348 l., **zéro test**) | — | 🔴 **BLOQUÉ par G1** | 3 valeurs d'enum + 2 tranches |

**Total non conditionné : ≈ 2 080 lignes** (M1 + M2 + M3 + M6 + M8).
**Avec G3 livré : ≈ 3 180.**

### Les trois choses à retenir

1. 🔴 **Le blocage `ZEntity` coûte UNE ligne**, pas un chantier. `ZEntity` = un getter
   (`z_entity.dart:17-27`, corps lu en entier) ; `DynamicModel` le satisfait déjà
   (`dynamic_model.dart:4`). Et `ZCrudSource.items` (`z_crud_source.dart:109`) évite **tout**
   adaptateur `DataState → Either`. C'est ce couple qui rend M5 réaliste.
2. 🔴 **Le routage IA est déjà migré ; c'est son ÉDITION qui manque.** 106 lignes d'hôte lisent le
   catalogue du socle. Le formulaire complet existe (`$ZChatRouterFieldSpecs`) et reste
   inatteignable faute d'**encodeur inverse** (G4). C'est le manque au socle le mieux cerné du
   dossier — et le plus court à combler.
3. 🔴 **La visionneuse est le plus gros gisement et le seul vraiment bloqué.** 3 348 lignes,
   **zéro test**, quatre modes de marquage que le socle ne sait pas nommer. Trois valeurs d'enum
   additives ouvriraient le chantier ; sans elles, aucun portage n'est honnête — et la QA d'un
   lecteur PDF annotable ne se fait pas au `grep`.

---

## 7. Limites de ce relevé

- **Aucun test lancé, aucune compilation.** `DynamicModel extends ZEntity` (M4) et l'adoption de
  `ZCrudSource.items` + `tabs` (M5) sont des lectures de **contrats et de corps**, pas des builds.
- **Les gains en lignes sont des estimations bornées**, sauf les coquilles de formulaire (§2/M1,
  mesurées ligne à ligne : 124 / 91 / 117 / 250) et les blocs du corpus (§2/M6, mesurés).
- **Je n'ai pas mesuré** le comportement à l'exécution de `ZCrudScreen` sur la voie `items` avec
  onglets — notamment si les `baseFilters` d'onglet sont ré-appliqués en mémoire. La dartdoc
  l'affirme (`z_list_query_policy.dart:200-206`) ; je ne l'ai pas vérifié au code de rendu.
- **Je n'ai pas ouvert** `test/w7o/`, `test/w7p/`, `test/w7d/`, `test/w8l/`, `test/w5/`
  (15 fichiers, 3 853 lignes) : leur existence est reprise de la carte, leur contenu non vérifié.
- **`folders/`** (36 fichiers, 18 333 lignes) est hors périmètre alors que la matière y partage sa
  page de contenus et son contrôleur. Certains verdicts M2/M5 y ont probablement des jumeaux.
