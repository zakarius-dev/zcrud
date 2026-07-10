# Code Review — E3-3b-2 · Sous-listes (`subItems`/`dynamicItem`, mini-CRUD imbriqué)

- **Skill invoqué** : `bmad-code-review` (tool `Skill`, chargé avec succès ; step-files suivis
  depuis `.claude/skills/bmad-code-review/steps/`).
- **Spec partagée** : `_bmad-output/implementation-artifacts/stories/e3-3b-familles-avancees-sous-listes.md` (ACs `[→ -2]` : 8, 9, 13-enrichi, 14-subList/dynamicItem, 15-SM-1 imbriqué, 16).
- **Mode** : full (spec + diff). Baseline `acc6a21` (HEAD = E1+E2) ; tout E3 en working tree.
- **Périmètre STRICT -2** : `subItems`/`dynamicItem`. Registre + feuilles simples (-1) et
  signature/widget libre (-3) **hors périmètre** (non revus ici).
- **Date** : 2026-07-10.

## Fichiers revus (diff -2)

| Fichier | Nature |
|---|---|
| `packages/zcrud_core/lib/src/domain/edition/z_sub_list_config.dart` | NOUVEAU — config `const` pur-données `ZSubListConfig{itemFields, reorderable}` (AD-4) |
| `.../presentation/edition/families/z_sub_list_field_widget.dart` | NOUVEAU — mini-CRUD imbriqué (add/remove/reorder) |
| `.../presentation/edition/families/z_dynamic_item_field_widget.dart` | NOUVEAU — item unique (add/edit/clear) |
| `.../presentation/edition/edition_field_family.dart` | MODIFIÉ — `EditionFamily.subList`/`dynamicItem` + cases `familyOf` |
| `.../presentation/edition/z_field_widget.dart` | MODIFIÉ — dispatch **pré-slice** subList/dynamicItem |
| `.../presentation/l10n/z_localizations.dart` | MODIFIÉ — `addItem/removeItem/moveItemUp/moveItemDown/clearItem` (en+fr) |
| `.../lib/zcrud_core.dart` | MODIFIÉ — exports barrel |
| `test/presentation/edition/z_sub_list_test.dart` | NOUVEAU — AC8/9/15 |
| `test/presentation/edition/z_field_dispatch_test.dart` | MODIFIÉ — partition 39 (feuilles=7), exhaustivité |
| `test/presentation/edition/catalogue_a11y_test.dart` | MODIFIÉ — subList/dynamicItem au catalogue |

## Résultats de vérification RÉELLEMENT rejoués (sur disque)

| Vérif | Résultat |
|---|---|
| `flutter analyze lib test` (zcrud_core) | **No issues found — RC=0** |
| `flutter test` (zcrud_core) | **All tests passed — 297 tests — RC=0** |
| `melos run verify` | **RC=0** (graph_proof · gate_melos · gate_reflectable · gate_secret_scan · gate_codegen · gate_compat · verify_serialization) |
| `graph_proof.py` | **out-degree(zcrud_core)=0 · ACYCLIQUE OK · CORE OUT=0 OK · 14 nœuds** |
| `melos list` | **14 packages** |
| `.g.dart`/`.freezed.dart` suivis par git | **0** |

## Analyse adversariale des points de vigilance

### 1. SM-1 IMBRIQUÉ (le cœur du risque) — CONFORME

Vérifié par lecture du code **et** ré-exécution des tests à compteurs.

- **Le conteneur écoute-t-il par erreur la VALEUR de chaque item ?** NON. `ZSubListFieldWidget`
  ne se souscrit à **aucune** tranche de valeur. Le seul `setState` local est déclenché par des
  mutations **structurelles** (`_addItem`/`_removeAt`/`_move`). La valeur des sous-champs remonte
  par un **listener d'agrégation** (`_syncToParent`) attaché à chaque slice imbriqué, qui écrit la
  `List` agrégée via `onChanged` **sans jamais** appeler `setState` sur le conteneur.
- **L'agrégation de la tranche parente est-elle HORS de la voie de rebuild ?** OUI, par
  construction. Le dispatch `ZFieldWidget.build` traite `subList`/`dynamicItem` **AVANT** le
  `ZFieldListenableBuilder` (comme `hidden`/`unsupported`), lignes 150-167 de `z_field_widget.dart`.
  L'hôte subList n'est donc **pas** souscrit à la tranche parente → `setValue(parent, list)` ne le
  reconstruit pas.
- **Un ancêtre (root form) se reconstruit-il sur une frappe imbriquée ?** NON. `ZFormController.setValue`
  ne notifie **que** le `ValueNotifier` de la tranche visée — **jamais** `notifyListeners()` global
  (réservé à `setVisibleFields`, canal structurel). `DynamicEdition` n'observe **que**
  `controller.visibleFields`. Donc écrire la `List` agrégée dans le slice parent ne ré-exécute ni
  `DynamicEdition` (build structurel), ni le sibling, ni l'hôte subList.
- **Compteurs rejoués (RÉELS, `z_sub_list_test.dart`)** :
  - Test « frappe dans un sous-champ » : sur **30 frappes**, **exactement 1** clé de sous-champ a
    bougé (+30 rebuilds ≈ 1/frappe) ; les 3 autres sous-champs (même item + autre item) **inchangés**.
  - Test « host/sibling/racine » : sur **20 frappes** imbriquées, `subListHostBuilds`,
    `siblingHostBuilds` et `structuralBuilds` **strictement inchangés** ; valeur bien agrégée dans
    `controller.valueOf('items')`. Focus imbriqué conservé à chaque frappe.

  → **SM-1 imbriqué NON cassé.** Aucun rebuild de liste/parent/racine sur frappe imbriquée.

### 2. FUITES de controllers — AUCUNE

- **removeAt** (`_removeAt`, l.193-201) : `_detach(removed)` (retire les listeners d'agrégation)
  **puis** `removed.controller.dispose()`. ✓
- **dispose du parent** (`ZSubListFieldWidget.dispose`, l.116-122) : itère **tous** les `_items`,
  `_detach` + `dispose` chacun. ✓ Idem `ZDynamicItemFieldWidget.dispose` → `_disposeController()`.
- **clear (dynamicItem)** (`_clearItem`, l.136-139) : `setState(_disposeController)` → listeners
  retirés + `dispose`. ✓
- **reorder** (`_move`) : ne dispose rien (identité préservée) — correct. ✓
- **Ordre removeAt** : `setState` (marque dirty) puis `dispose` synchrone avant le rebuild ; le
  sous-arbre retiré est démonté au frame suivant ; `ChangeNotifier.removeListener` est autorisé
  après `dispose` (contrat Flutter) → **pas d'exception au démontage**. Confirmé : test retrait +
  `tester.takeException() isNull`.
- **Parent non disposé** : les widgets ne disposent **jamais** le contrôleur parent (possédé par
  l'hôte). ✓

  → **Aucune fuite** au removeAt **ni** au dispose parent. Le retrait du milieu ne casse pas les
  autres (test « retrait item milieu » : restent `[A,a,C,c]`, textes intacts).

### 3. Réordonnancement + identité stable — CONFORME

- `itemId` = `'item_${_seq++}'`, compteur **monotone jamais réutilisé** (PAS l'index).
- Place stable : `KeyedSubtree(key: ValueKey(_items[i].id))` au niveau item **et**
  `ValueKey('${id}/${f.name}')` au niveau sous-champ.
- `_move` déplace le **même** objet `_SubItem` (même `controller`) → l'`Element`/`State` du sous-champ
  est réutilisé via la clé stable. Test « réordonner PRÉSERVE focus/état » : après descente, le champ
  déplacé conserve **texte `'A'` + focus**. ✓

### 4. Exhaustivité 0-default (AC14) — PRÉSERVÉE

- `familyOf` reste un `switch` **sans `default:`** ; `subItems→subList`, `dynamicItem→dynamicItem`
  quittent `unsupported`. Le `_dispatch` interne conserve les cases `subList`/`dynamicItem`/`hidden`/
  `unsupported` (→ `SizedBox.shrink`, jamais atteints car traités pré-slice) : exhaustif sans default.
- Partition **39** re-vérifiée par test : base(13)+hidden(1)+**feuilles(7)**+registre(12)+unsupported(6)
  = 39, ensemble = `EditionFieldType.values`, sans doublon. `signature`/`widget`/`stepper`/`file`/
  `image`/`document` **restent** en repli. ✓

### 5. Frontière E4-5 (`ZSubListScreen`) — PROPRE

E3-3b-2 livre le **champ d'édition imbriqué** (dans un formulaire), pas l'écran autonome. La
frontière est documentée (docstrings + `z_sub_list_config.dart`) ; le sous-schéma `const`
(`ZSubListConfig.itemFields`) est désigné comme brique commune réutilisable côté E4-5. Aucune
duplication de `ZSubListScreen`. ✓

### 6. Encodage / round-trip défensif — CONFORME

- Valeur subList = `List<Map<String, dynamic>>` ; dynamicItem = `Map<String, dynamic>?` — sérialisables.
- Lecture **défensive** : `_readList` filtre les entrées non-`Map` (→ `[]`), `_readMap` (`null`/
  type inattendu → `null`) — aligné AD-10 (`fromJsonSafe→null`, jamais d'échec parent).
- `ZSubListConfig` : `const`, additif (sous-classe `ZFieldConfig`, jamais `sealed`), `==`/`hashCode`
  profonds via helper pur-Dart (pas de `package:collection` → OUT=0). ✓

### 7. a11y / RTL — CONFORME

- add/remove/monter/descendre = `IconButton` (cible ≥ 48 dp via `kMinInteractiveDimension`) +
  `tooltip` (→ label sémantique) ; add = `TextButton.icon` (tap-target 48 dp via
  `MaterialTapTargetSize.padded`). `Semantics(container, label)` sur le conteneur.
- Insets **directionnels** exclusifs (`EdgeInsetsDirectional.fromSTEB`, `AlignmentDirectional`) ;
  bordure dérivée de `ZcrudTheme.fieldBorderColor`/`radiusM` (aucune couleur en dur — FR-26).
- Test RTL `meetsGuideline(androidTapTargetGuideline)` + `takeException isNull` — **vert** ;
  `style_purity_test` inchangé et vert (dans la suite 297). ✓
- Catalogue a11y (AC13) enrichi : `subItems` + `dynamicItem` présents (`findsOneWidget` chacun). ✓

## Triage des findings

**HIGH / MAJEUR : 0**
**MEDIUM : 0**
**LOW / informational : 4** (aucune correction bloquante ; consignées)

### LOW-1 — Pas de re-souscription à la tranche parente (divergence avec les feuilles simples)
`ZSubListFieldWidget`/`ZDynamicItemFieldWidget` lisent `initialValue` **une seule fois** et ne se
re-souscrivent pas au slice parent (choix délibéré, documenté, indispensable à SM-1 imbriqué). Les
feuilles E3-3a/-1 (date/bool/select) **reflètent** un `setValue` externe ; le mini-CRUD imbriqué,
lui, **ignore** une réécriture programmatique externe de la liste entière (ex. reset/chargement
tardif). Hors périmètre fonctionnel E3 actuel (pas de reset externe câblé), mais à **tracer pour
E3-4/E7** : si un flux introduit un rechargement externe du slice parent, le mini-CRUD ne se
rafraîchira pas. → informational.

### LOW-2 — Agrégation O(N×M) par frappe imbriquée
`_syncToParent` reconstruit intégralement `List<Map>` (tous items × tous champs) à **chaque**
changement de sous-champ. Correct fonctionnellement et sans impact rebuild (SM-1 préservé), mais
coût d'agrégation croissant sur grandes sous-listes. Optimisation possible (mutation ciblée). → LOW.

### LOW-3 — `_addItem` (dynamicItem) sans garde de dispose
`ZDynamicItemFieldWidget._addItem` réaffecte `_controller` sans disposer un éventuel contrôleur
existant. **Non déclenchable** en l'état (le bouton add n'est rendu que si `controller == null`),
donc pas de fuite réelle ; robustesse défensive uniquement (une future refonte du rendu pourrait
briser l'invariant). → informational.

### LOW-4 — Trous de couverture de test
Non couverts (défensivement gérés, mais non prouvés) :
- **Imbrication 2 niveaux** (`subItems` dont un `itemField` est lui-même `subItems`) — la
  composition remonte correctement à la lecture du code (chaînage `setValue`→listener→`_syncToParent`),
  mais **aucun test** ne l'exerce (SM-1 sur 2 niveaux, dispose en cascade).
- **Sous-liste vide** (`itemFields` vide / config absente) — `_itemFields` → `[]`, add crée un item
  sans champ (pas de crash), non testé.
- **Item ajouté puis focus immédiat** / **reorder pendant saisie active (mid-composition)** — le
  test focus+reorder existe mais pas la frappe en cours pendant le déplacement.
→ LOW ; recommandé d'ajouter au moins le cas **2 niveaux** (surface AD-2 la plus à risque) en dette.

## Vérification des invariants AD (échantillon -2)

- **AD-2** : rebuilds granulaires imbriqués prouvés (cf. §1) ; aucun `setState` de niveau
  formulaire ; aucun `Form`/`FormBuilder` global (`find.byType(Form) → findsNothing`, testé). ✓
- **AD-4** : `ZSubListConfig` instanciable `const` additive, jamais `sealed`, pur-données. ✓
- **AD-1/AD-15** : `zcrud_core` OUT=0 inchangé, 14 nœuds, acyclique ; aucun gestionnaire d'état ni
  package satellite importé. ✓
- **AD-13 / FR-26** : directionnel exclusif, Semantics + ≥ 48 dp, thème injecté (0 couleur en dur). ✓
- **AD-10** : désérialisation défensive (`_readList`/`_readMap`). ✓

## VERDICT : ✅ APPROVED

Le périmètre -2 est **conforme et vert**. Le point de vigilance AD-2 n°1 (slices imbriqués) est
traité par conception **et** prouvé par compteurs réels : une frappe dans un sous-champ ne
reconstruit **que** ce sous-champ ; l'hôte subList, le sibling et le formulaire racine restent
strictement inchangés ; aucune fuite de contrôleur (removeAt **et** dispose parent) ; le
réordonnancement préserve état/focus via `itemId` stable. `analyze`/`test`(297)/`verify` RC=0,
graphe CORE OUT=0, 14 packages, 0 `.g.dart`. **Aucun finding HIGH/MAJEUR/MEDIUM.** Les 4 LOW sont
consignés (aucun bloquant) ; l'ajout d'un test **d'imbrication 2 niveaux** est recommandé en dette
avant les stories qui composeront des sous-schémas profonds (E7/E8).
