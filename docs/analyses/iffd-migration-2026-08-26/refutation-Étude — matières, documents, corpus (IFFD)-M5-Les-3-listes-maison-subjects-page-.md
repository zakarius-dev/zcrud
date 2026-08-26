# Réfutation — M5 « Les 3 listes maison » (Étude — matières, documents, corpus, IFFD)

**Date** : 2026-08-26
**Affirmation attaquée** : « le socle sait déjà le faire, par `ZCrudScreen<T extends ZEntity>` (54 paramètres) + `ZCrudSource.items(...)` + `ZListTab(acl:, countOf:, baseFilters:, canCreate:, titles:)` »
**Gain annoncé** : ~1 100 lignes d'hôte supprimées sur 2 089.

## VERDICT : **RÉFUTÉE**

Les canaux cités **existent** et sont **atteignables** — cette partie de l'affirmation est exacte et je l'ai vérifiée plus solidement qu'elle ne le faisait. Mais la migration annoncée **ne compile pas aujourd'hui** (deux préconditions d'hôte non mentionnées), **un tiers du périmètre est structurellement hors d'atteinte**, et le calcul de gain repose sur un moteur de dérivation qui est **inerte chez IFFD**.

---

## 1. Ce qui RÉSISTE (vérifié, à créditer)

| Point | Preuve |
|---|---|
| `ZCrudScreen<T extends ZEntity>` existe | `packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart:180` |
| « 54 paramètres » | ctor `:182-242` — **53** paramètres `this.` + `super.key` = 54. Compte juste. |
| `ZCrudSource.items(List<T>, {onSave, onSoftDelete, onRestore, onPurge, isDeleted})` | `z_crud_source.dart:109-117`, signature **exacte** |
| `ZListTab.acl` / `countOf: ValueListenable<int>` | `packages/zcrud_core/lib/src/presentation/list/z_list_tab.dart:186` et `:218` |
| Exportés par les barrels | `zcrud_screen.dart` exporte `z_crud_screen.dart` + `z_crud_source.dart` ; `zcrud_core.dart:216` exporte `z_list_tab.dart` |
| `zcrud_screen` est bien une dépendance déclarée d'IFFD | `iffd/pubspec.yaml:524` (`dependencies:` = l. 10-532), `ref: v3.21.0`, + override `:695` |
| Mesure hôte « `ZCrudScreen` → 0 fichier » | **confirmée** : `grep -rn "ZCrudScreen" --include='*.dart' lib` → **0 ligne** |
| **Aucune conversion `DataState→Either` requise** | **confirmé, et par le corps** : `_buildItemsBody` lit `widget.source.items` (`:3271`) et `_resolveTrashCount` aussi (`:3394`) — lecture **depuis le widget**, jamais un snapshot d'`initState`. Un rebuild piloté par `StreamBuilder` atterrit donc bien. |
| **items + tabs fonctionne** | **preuve positive**, meilleure que celle avancée : l'argument « une seule assertion dans le fichier » est un argument d'absence, sans valeur. Le vrai constat est `_buildItemsBody(BuildContext, {ZListTab? tab})` `:3269`, dont la dartdoc `:3263-3268` décrit explicitement le « corps d'un **onglet assemblé** », avec `_tabPolicy(tab)` qui compose `baseFilters`. |
| Lecture de `ZListTab.acl` (conjonction, « retire seulement ») | dartdoc `:160-186` — exacte. IFFD compose bien par `.or()`. |
| Le filtre d'onglet `arrayContains` est exprimable | `ZFilterOp.contains` = « appartenance d'élément à un champ collection », `zcrud_core/lib/src/domain/data/z_data_request.dart:33-34` |

⚠️ **Erreur de citation** : le `.or()` d'IFFD n'est **pas** en `subjects_page.dart:396-398` (ces lignes sont la garde `userId == null`). Les deux sites réels sont **`:433`** et **`:464`**. Le fond est juste, la référence est fausse de ~37 lignes.

---

## 2. BLOQUANT A — `T extends ZEntity` n'est satisfait par **aucun** des trois modèles

C'est la borne du type paramètre de `ZCrudScreen` (`:180`) et de `ZCrudSource` (`z_crud_source.dart:45`). Elle n'est mentionnée nulle part dans l'affirmation.

Or, chez IFFD :

```
lib/src/domain/models/subject_model.dart:17          class SubjectModel extends DynamicModel
lib/src/domain/models/ai/ai_models.dart:190          class IffdAiRouterModel extends DynamicModel
lib/src/domain/models/valuation/valuation_tool_model.dart:5  class ValuationToolModel extends DynamicModel
lib/src/domain/models/dynamic_model.dart:3           abstract class DynamicModel        ← AUCUN supertype
```

**GREP NÉGATIF MONTRÉ** :

```
$ grep -rn "extends ZEntity\|implements ZEntity\|with ZEntity" --include='*.dart' lib
(0 ligne)

$ grep -rn "ZEntity" --include='*.dart' lib      →  3 lignes, toutes dans UN fichier :
lib/.../ai_routers/zcrud/ai_router_zcrud_edition.dart:31   (commentaire)
lib/.../ai_routers/zcrud/ai_router_zcrud_edition.dart:58   (clause show d'import)
lib/.../ai_routers/zcrud/ai_router_zcrud_edition.dart:245  bool can(ZCrudAction action, {ZEntity? target, ...})
```

`ZEntity` n'apparaît chez IFFD **que comme type de paramètre d'une ACL**, jamais comme supertype d'un modèle. `ZCrudScreen<SubjectModel>` **ne compile pas** aujourd'hui.

**Coût réel** : `DynamicModel` porte déjà `final String? id` et un ctor `const`, donc `abstract class DynamicModel extends ZEntity` compilerait. Mais cela fait basculer **24 classes** (`grep -c "extends DynamicModel" lib` → **24**) dans la hiérarchie `zcrud_core` d'un coup — ce n'est pas un geste local à M5, et ce n'est pas chiffré dans le gain annoncé.

---

## 3. BLOQUANT B — IFFD n'a **aucun** `ZcrudRegistry` : le moteur de dérivation est inerte

C'est la réfutation la plus lourde, parce qu'elle attaque directement le **chiffre du gain**.

**GREP NÉGATIF MONTRÉ** :

```
$ grep -rn "ZcrudRegistry\|registerKind\|register<" --include='*.dart' lib
(0 ligne)
```

Zéro enregistrement dans tout `lib/` d'IFFD.

Or la dartdoc de `ZCrudScreen.registry` (`:253-254`) l'énonce : *« `null` ⇒ `listFields` + `cellsOf` deviennent requis, et l'édition exige `editionBuilder` »*. **Et le corps le confirme — ce n'est pas une promesse de dartdoc** :

- `_cellsOf` (`:1361-1373`) : `if (registry == null || kind == null) throw ZScopeError('ZCrudScreen<$T> : aucune projection en cellules...')`
- `_buildEdition` (`:1647-1655`) : `if (registry == null || kind == null || fields == null) throw ZScopeError('ZCrudScreen<$T> : aucune voie d\'édition...')`

Conséquence : pour chacune des trois listes, l'hôte doit **écrire à la main** `listFields` (les `ZFieldSpec`), `cellsOf` (la projection) **et** `editionBuilder` (le formulaire entier).

Le « principe directeur » revendiqué par le paquet (`z_crud_screen.dart:12-16` — *« tout ce qui est dérivable d'une déclaration existante ne se redemande jamais »*) **ne s'applique pas à IFFD**, faute de déclaration. Les ~1 100 lignes annoncées sont calculées contre une dérivation qui n'a ici aucune prise. Le solde net n'est pas établi — il est peut-être positif, mais l'affirmation ne l'a pas mesuré.

**Corroboration indirecte** : 16 fichiers d'IFFD importent `zcrud_screen`, et les **seuls** symboles tirés sont `presentFormEdition` (15 occurrences) et `ZFormOnly` (10). Jamais `ZCrudScreen`, jamais `ZCrudSource`. IFFD consomme ce paquet comme un **présentateur de formulaire**, pas comme un assembleur d'écran — ce qui est cohérent avec l'absence de registre.

---

## 4. BLOQUANT C — la 3ᵉ liste (345 l.) n'est **pas un écran** : incompatibilité structurelle

`ValuationToolsGridView` (`valuation_tool_model_actions_dialog_widget.dart:271-615` = **345 lignes**, le compte de l'affirmation est exact) ne rend pas une page. Son `build` retourne :

- soit un `GridView.count(shrinkWrap: !isInHome, physics: NeverScrollableScrollPhysics())` (`:576-590`) ;
- soit, si `isInFolderDetails`, ce grid enveloppé dans un **`ExpandablePanel`** avec en-tête + pastille de comptage (`:594-612`).

C'est une **section rétractable, shrink-wrappée, non défilante**, conçue pour être **empilée**. Et elle l'est : `ValuationToolsWidgets` (`:616`) en instancie **10** — une par sous-type (`ArticleGATT`, `ArticleCodeDuGATT`, `Annexe`, `NoteInterpretative`, `Decision`, `AvisConsultatif`, `Commentaire`, `NoteExplicative`, `EtudeDeCas`, `Etude`, aux lignes `:658, 674, 690, 706, 722, 738, 754, 770, 786, 802`) — **dans un unique `Column`** (`:655`).

En face, `ZCrudScreen` rend **toujours** un `Scaffold` :

```
$ grep -c "ZPageScaffold(" packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart
2                       ← :3686 (accès refusé) et :3818 (chemin nominal). Aucun autre.

$ grep -rn "embedded\|withoutScaffold\|bodyOnly\|noScaffold" packages/zcrud_screen/lib/
(0 ligne)               ← GREP NÉGATIF : aucune échappatoire « corps seul »
```

Aucune des trois valeurs de `ZScreenMode` (`z_screen_mode.dart:27-55` — `full`/`details`/`locked`) n'évite le `Scaffold` : elles gouvernent les **gestes**, pas la coquille. Empiler 10 `Scaffold` dans un `Column` n'est pas une migration.

**345 des 2 089 lignes (16,5 %) sont hors d'atteinte structurellement**, pas par un manque de fonctionnalité.

---

## 5. MANQUE D — aucun canal pour le bouton flottant (FAB)

**GREP NÉGATIF MONTRÉ** :

```
$ grep -n "floatingActionButton\|FloatingActionButton" packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart
(0 ligne, RC=1)
```

Le canal existe **un cran plus bas** — `ZPageScaffold.floatingActionButton` (`packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:67`) et `floatingActionButtonLocation` (`:68`) — mais `ZCrudScreen` **ne le relaie jamais** et n'expose **aucun paramètre** pour lui. Le contraste est net : `drawer`/`endDrawer` sont, eux, explicitement relayés (`:3833-3834`), avec une dartdoc qui justifie ce relais (`:789`, `:829`).

Chez l'hôte, c'est le geste de création principal des deux pages, gouverné par l'ACL :

- `subjects_page.dart` : `:337` (fabrique), `:357` (`FloatingActionButton.extended`), `:444` et `:498` (`floatingActionButton: !acl.create ? null : ...`)
- `ai_routers_page.dart` : `:616`, `:765`, `:786`

Migrer, c'est **perdre les deux FAB** — soit ~48 lignes de subjects_page et ~35 d'ai_routers_page qui ne se « suppriment » pas : elles **disparaissent du produit**.

---

## 6. MANQUE E — aucun groupement : `ai_routers_page` regroupe par `WorkflowEffort`

**GREP NÉGATIF MONTRÉ** :

```
$ grep -ic "groupBy\|groupOf\|ZListGroup" packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart
0
$ grep -rn "groupBy\|ZListGroup" packages/zcrud_core/lib/src/presentation/list/
(0 ligne)
```

Chez l'hôte (`ai_routers_page.dart:571-610`) :

```dart
Map<WorkflowEffort, List<IffdAiRouterModel>> effortsRouters = {};
for (final router in aiRouters) { effortsRouters.putIfAbsent(...).add(router); }
...
for (final entry in effortsRouters.entries)
  _buildEffortSection(effort: entry.key, routers: entry.value,
                      isExpanded: currentValues[entry.key] ?? true,
                      onExpansionChanged: ...)
```

C'est une liste **sectionnée par groupe, avec état de repli par groupe** piloté par un `ValueNotifier<Map<WorkflowEffort,bool>>` (`:41`). `ZCrudScreen` sait faire des **onglets** (`tabs`), pas des **sections empilées repliables**. Ce n'est pas la même forme : les onglets montrent un groupe à la fois, ici les trois sont visibles et repliables ensemble.

---

## 7. MANQUE F — la coquille d'application d'IFFD n'est pas un `Scaffold`

`AppScaffold.build` (`lib/src/presentation/app_scaffold.dart:161-176`) retourne un **`Row`** :

```dart
return Row(children: [
  if (!isMobile) sideMenuDrawer,          // rail latéral PERMANENT en desktop
  Expanded(child: scaffold(isMobile, ...)),
]);
```

et son `scaffold()` (`:109-145`) enveloppe le tout dans un `PopScope(canPop: false)`, avec `BackButtonInterceptor.add/remove` (`:87`, `:99`) et un « appuyez encore une fois pour quitter » (`:148-160`).

`ZCrudScreen` ne relaie que `drawer`/`endDrawer` vers un `Scaffold` unique : **pas de `Row`, pas de rail permanent, pas d'interception du retour, pas d'overlay `isLoading`, pas de `bottomNavigationBar`, pas de `persistentFooterButtons`**. Imbriquer `ZCrudScreen` comme `AppScaffold.body` donnerait **deux `Scaffold` et deux `AppBar`** empilées.

---

## 8. Ce que l'affirmation concédait déjà

Le conditionnement G3 (état vide) est **honnête et exact** : `subjects_page.dart:128-282` est bien ~155 lignes d'illustration sur mesure (cercles concentriques, `ShaderMask` sur dégradé, CTA à dégradé gouverné par `acl.create`), et `ai_routers_page.dart` en porte **deux** équivalents (accès refusé `:75-140` et liste vide `:160-285`). L'affirmation n'en compte qu'un.

---

## Synthèse chiffrée

| Périmètre | Lignes | Statut |
|---|---:|---|
| `subjects_page.dart` | 941 | Bloqué par A + B ; perd FAB (D) et coquille (F) ; -155 l. concédées (G3) |
| `ai_routers_page.dart` | 803 | Bloqué par A + B ; perd FAB (D), **groupement (E)**, coquille (F) ; 2 états vides |
| `ValuationToolsGridView` | 345 | **Structurellement hors d'atteinte** (C) |
| **Total** | **2 089** | — |

**Préconditions non chiffrées par l'affirmation** : faire entrer 24 classes dans `ZEntity` ; écrire de zéro `listFields` + `cellsOf` + `editionBuilder` × 3 ; écrire un adaptateur `RessourceACL → ZAcl` (il n'en existe **qu'un** dans IFFD, `IffdMinimumOneAcl`, `ai_router_zcrud_edition.dart:235` — `RessourceACL` est un simple sac de 11 booléens, `ressource_acl.dart:1-12`, dont la correspondance avec `ZCrudAction` est heureusement totale).

**Le gain de ~1 100 lignes n'est pas établi.** Il est calculé contre une dérivation par registre qui n'existe pas chez IFFD, sur un périmètre dont 16,5 % est inatteignable, et sans déduire les fonctionnalités perdues (FAB × 2, groupement, rail latéral, interception du retour).

## Correction proposée

L'affirmation tenable serait :

> Le socle offre les **briques** (`ZCrudScreen`, `ZCrudSource.items`, `ZListTab`), et la voie `items` évite bien toute conversion `DataState→Either`. Mais M5 n'est **pas** une migration à coût nul : elle exige d'IFFD (1) que ses modèles deviennent des `ZEntity` (24 classes), (2) qu'il déclare un `ZcrudRegistry` — sans quoi `cellsOf`/`listFields`/`editionBuilder` sont à écrire à la main et le gain s'évapore. Elle **exclut** `ValuationToolsGridView` (345 l., section empilée ×10, alors que `ZCrudScreen` rend toujours un `Scaffold`), et elle **perd** trois choses que le socle ne sait pas rendre : le bouton flottant (aucun paramètre, alors que `ZPageScaffold` l'a), le groupement en sections repliables d'`ai_routers_page`, et l'état vide illustré (G3).
