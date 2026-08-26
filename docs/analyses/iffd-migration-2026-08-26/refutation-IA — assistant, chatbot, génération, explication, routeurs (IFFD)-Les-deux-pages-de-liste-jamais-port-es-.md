# Réfutation — IA (IFFD) / « Les deux pages de liste jamais portées »

**Domaine** : IA — assistant, chatbot, génération, explication, routeurs (IFFD)
**Besoin hôte** : les deux pages de liste jamais portées (experts IA, routeurs IA)
**Affirmation attaquée** : « le socle sait déjà le faire, par `ZCrudScreen<T extends ZEntity>` +
`ZCrudSource.repository/.items` » — gain annoncé **~1 700 lignes d'hôte supprimées**.

## VERDICT : **DÉMENTIE**

Le canal **existe**, est **exporté**, est **atteignable** — et ne couvre pas le besoin.
Mesuré : **81 %** des lignes des deux pages relèvent de trois choses que `ZCrudScreen` **n'a pas
de socle pour recevoir** (regroupement en sections, état vide illustré, FAB). Le gain réel
plafonne à **~405 lignes brutes**, contre lesquelles il faut écrire **deux adaptateurs
`ZRepository` de 9 membres**, **deux `listFields` + deux `cellsOf`** (l'hôte n'a **aucun**
`ZcrudRegistry`) et un pont `ZAcl`. Le solde est au mieux nul.

---

## 1. Ce qui RÉSISTE (vérifié sur disque)

| Point | Mesure |
|---|---|
| La classe existe à l'endroit cité | `packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart:180` → `class ZCrudScreen<T extends ZEntity> extends StatefulWidget`. Fichier **4 428 l**, corps de la classe widget :180→:1007. |
| Exportée par le barrel | `packages/zcrud_screen/lib/zcrud_screen.dart:27` (`export 'src/presentation/z_crud_screen.dart';`) et `:30` pour `z_crud_source.dart`. |
| Dépendance déclarée d'IFFD | `iffd/pubspec.yaml:524-528` (`dependencies: zcrud_screen: git …/packages/zcrud_screen`) + override `:695-699`. **Atteignable sans toucher au pubspec.** |
| `ZCrudSource` a bien 3 fabriques à corps réel | `z_crud_source.dart:45` (`class ZCrudSource<T extends ZEntity>`), `:53` `.repository`, `:93` `.readOnlyRepository`, `:109` `.items`. Corps lus : `_writable`, `writeRepository`, `canWrite`, `supportsTrash`, `supportsPurge` sont de vrais getters, pas de la dartdoc. |
| Aucune contagion Syncfusion | `DynamicList` vit dans **`zcrud_core`** (`packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart:61`), pas dans `zcrud_list`. `packages/zcrud_screen/pubspec.yaml:46-50` : deps = `zcrud_core`, `zcrud_menu`, `zcrud_navigation`, `zcrud_ui_kit`, `flutter`. Le blocage IFFD sur Syncfusion ^32 vs ^34 (`iffd/pubspec.yaml:292`) **ne s'oppose pas** à `zcrud_screen`. |
| Le grep négatif hôte tient (et plus large encore) | `grep -rnE "\bZCrudScreen\b\|\bDynamicList\b\|\bZListRenderer\b\|\bZCrudSource\b\|\bZListTab\b\|\bZListLayout\b" /home/zakarius/DEV/iffd/lib/` → **RC=1, 0 ligne**. |
| Les onglets « filière » des experts sont exprimables | `packages/zcrud_core/lib/src/presentation/list/z_list_tab.dart` : `:242 baseFilters`, `:288 itemFilter`, `:186 acl`, `:397 defaultItemBuilder`, `:218 countOf`. `ZFilterOp.contains` (`z_data_request.dart:33`) couvre l'`arrayContains` de `DataRequest`. C'est un vrai point d'appui. |

---

## 2. Ce qui est FAUX DANS LA PREUVE ELLE-MÊME

1. **Le chemin de `ZEntity` cité n'existe pas.**
   `sed packages/zcrud_core/lib/src/domain/entity/z_entity.dart` → *« Aucun fichier ou dossier de
   ce nom »*. Le vrai fichier est `packages/zcrud_core/lib/src/domain/contracts/z_entity.dart`
   (**27 l**).

2. **`ZEntity` ne déclare pas « que » `String? get id`.** Corps lu, `:17-27` :
   ```
   abstract class ZEntity {
     const ZEntity();
     String? get id;                          // :23
     bool get isEphemeral => id == null;      // :26
   }
   ```
   Or les deux modèles hôtes **portent déjà** `id` : `AiExpert implements DynamicModel` avec
   `@override final String? id;` (`iffd/lib/ai_assistant/models/ai_expert.dart:12-14`), et
   `IffdAiRouterModel extends DynamicModel` (`iffd/lib/src/domain/models/ai/ai_models.dart:190`,
   `super.id` :243) hérite `final String? id` de
   `iffd/lib/src/domain/models/dynamic_model.dart:4`. Les deux `extends`/`implements` déjà autre
   chose : la seule voie est `implements ZEntity`, qui **n'hérite d'aucun corps** — le membre
   réellement à écrire est donc **`isEphemeral`**, pas `id`. « Un getter » survit par accident,
   sur le mauvais membre.

3. **« 64 paramètres » : mesuré 54.** Constructeur `:182-242` → 53 lignes `this.`/`required this.`
   + `super.key` = **54**. La classe déclare **57** champs `final`.

4. **« 10 sites » de `ZFormOnly/ZFormOnlyController` : mesuré 16 sites d'import.**
   `grep -c "package:zcrud_screen" iffd/lib` → **16**, dominés par `presentFormEdition` et non par
   `ZFormOnly`.

Aucun de ces quatre points ne suffit à démentir. Ils indiquent seulement que la preuve n'a pas été
relue sur disque.

---

## 3. Ce qui DÉMENT

### R1 — L'hôte n'a **aucun** `ZRepository`. `ZCrudSource.repository` est hors de portée en l'état.

```
grep -rn "ZRepository" /home/zakarius/DEV/iffd/lib/   → 0 ligne
```

Les deux dépôts IA sont des `CrudRepository<T>` :
`iffd/lib/src/domain/repositories/datacrud_repository.dart:20`, contrat en
`DataState<String, Exception>` (`:26`, `:48`, `:56-60`) et `Stream<List<T>>` (`:29-31`).
`ZRepository<T extends ZEntity>` (`packages/zcrud_core/lib/src/domain/ports/z_repository.dart:114`,
étendant `ZReadOnlyRepository` `:58`) exige **9 membres** en `Either<ZFailure,T>` :
`watchAll` `:125`, `watch` `:134`, `getAll` `:142`, `getById` `:151`, `save` `:180`,
`softDelete` `:186`, `restore` `:191`, `count` `:198`, `dispose` `:201`.

⇒ **Deux adaptateurs de 9 membres à écrire avant qu'une seule ligne d'hôte ne disparaisse.**
La voie `.items` esquive l'adaptateur — mais rend alors à l'hôte la pagination, la recherche
serveur et les trois écritures de corbeille sous forme de callbacks (`z_crud_source.dart:105-116`).

### R2 — L'hôte n'a **aucun** `ZcrudRegistry`. La dérivation — le cœur de l'argument « déclaratif » — ne s'applique pas.

```
grep -rn "ZcrudRegistry" /home/zakarius/DEV/iffd/lib/   → 0 ligne
```

Conséquences lues dans le code, pas dans la dartdoc :
- `z_crud_screen.dart:251-255` : « `null` ⇒ [listFields] + [cellsOf] deviennent **requis**, et
  l'édition exige [editionBuilder] » ;
- `z_crud_screen.dart:1648-1653` : sans registre + kind + fields, le chemin d'édition lève avec
  « `editionBuilder`, ou un `registry` où $T est enregistré avec ses … » ;
- `z_crud_screen.dart:1912-1913` / `:212` : la **duplication** disparaît sans registre.

Or `AiExpert` déclare **34 champs** (`ai_expert.dart:13-46`) et `IffdAiRouterModel` **27+**
(`ai_models.dart:191-234`). Leurs `listFields` et `cellsOf` sont du **code hôte net-nouveau**, à
écrire à la main, à maintenir en phase avec les modèles.

*(À décharge : l'édition des deux entités est déjà portée —
`iffd/lib/src/presentation/features/administration/zcrud/ai_expert_zcrud_edition.dart`
(flag `kAiExpertEditionUseZcrudDefault = false`, `:87`) et
`.../ai_routers/zcrud/ai_router_zcrud_edition.dart` (`kAiRouterEditionUseZcrudDefault = true`,
`:104`). Mais elle l'est via `ZFormOnly` + specs écrites à la main, pas via un registre.)*

### R3 — `ZCrudScreen` n'a **aucun** passe-plat FAB. Les deux pages y accrochent leur geste principal.

```
grep -rn "floatingActionButton\|FloatingActionButton" packages/zcrud_screen/lib/   → 0 ligne
grep -c  "floatingActionButton"  packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart → 0
```

`ZPageScaffold` **sait** le faire (`packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:67`,
`:163`, câblé au `Scaffold` `:280-283`). `ZCrudScreen` l'appelle **deux fois** — `:3686`
(accès refusé) et `:3818` (écran normal) — en ne passant que
`title / leading / drawer / endDrawer / actions / search / body`. Le FAB n'est jamais relayé.

Côté hôte :
- `ai_routers_page.dart:765-802` — FAB dégradé « Nouveau Fournisseur » (**38 l**) ;
- `ai_experts_page.dart:1119-1205` — FAB **à état** (**87 l**) : `ListenableBuilder` sur
  `instructionsGenerating`, `FlashcardGenerationIndicator`, spinner + libellé « Génération… » +
  `onPressed: null` pendant la génération ; positionné par `ExpandableFab.location` (`:1290`).

⇒ Récupérer le FAB impose d'envelopper `ZCrudScreen` — qui construit **déjà** un `Scaffold`
(`z_page_scaffold.dart:280`) — dans un **second** `Scaffold` de l'hôte. Ce n'est pas une migration,
c'est une superposition.

### R4 — Aucun **regroupement en sections** dans la liste. C'est pourtant le principe d'organisation des deux pages.

`ZListLayout` est **`sealed`** (`packages/zcrud_core/lib/src/presentation/list/z_list_layout.dart:70`)
avec exactement **4** variantes : `ZListDataGridLayout` `:98`, `ZListBuilderLayout` `:116`,
`ZListGridLayout` `:175`, `ZListCustomLayout` `:306`. Aucune n'est sectionnée.

```
grep -rniE "ZListGroup|groupBy|sticky|sectionHeader|ZSection" \
     packages/zcrud_core/lib/src/presentation/list/ packages/zcrud_screen/lib/
```
→ **8 lignes, toutes de FORMULAIRE** : `ZSectionCollapseStore` dans `present_form_edition.dart`
(`:31`, `:194`, `:197`, `:255`), `z_form_only.dart` (`:25`, `:253`, `:258`) et un commentaire de
`z_list_tabs_store.dart:19`. **Zéro** pour le regroupement de liste.

Or c'est exactement ce que font les deux pages :
- `ai_experts_page.dart:930-1117` (**188 l**) — sections A→Z, en-tête à pastille de compte, une
  `GridView.count` par lettre ;
- `ai_routers_page.dart:571-636` + `:637-763` (**193 l**) — regroupement par `WorkflowEffort`,
  accordéons `AnimatedCrossFade` + `AnimatedRotation`, état d'expansion dans un `ValueNotifier`.

Les `tabs` ne s'y substituent pas : un accordéon montre **tous** les groupes à la fois, un onglet
un seul — et 26 onglets pour A→Z n'est pas une migration.

### R5 — La seule échappatoire (`ZListCustomLayout`) **perd les actions de ligne**.

Dispatch lu dans `dynamic_list.dart:354-397` :
- branche `ZListBuilderLayout` `:357-374` → reçoit `actionsFor: interaction?.actionsFor` (`:369`) ;
- branche `ZListGridLayout` `:375-389` → reçoit `actionsFor: interaction?.actionsFor` (`:388`) ;
- branche `ZListCustomLayout` `:392-396` → `entityView(context, request, (row) => entityFor?.call(row))`
  — **aucun `interaction`, aucun `actionsFor`, aucun `selectedIds`**.

⇒ Dès que l'hôte prend la vue personnalisée pour retrouver ses sections (R4), il perd les actions
de ligne, leur filtrage `ZAcl` et la sélection — c'est-à-dire précisément ce que `ZCrudScreen`
devait lui apporter. Le socle offre soit le regroupement **sans** les actions, soit les actions
**sans** le regroupement.

### R6 — Aucun **état vide** injectable.

`dynamic_list.dart:186-189` : `ZListEmpty()` → `_ZListMessageView(messageKey: 'list.empty')`, en
dur, non paramétrable.
```
grep -n "emptyBuilder\|emptyState\|ZEmptyState" \
     packages/zcrud_core/lib/src/presentation/list/dynamic_list.dart packages/zcrud_screen/lib/  → 0 ligne
```
Côté hôte, deux blocs illustration + CTA : `ai_routers_page.dart:140-286` (**147 l**) et
`ai_experts_page.dart:130-296` (**167 l**). Aucune prise pour les recevoir.

### R7 — Aucun **pull-to-refresh**.

```
grep -rniE "RefreshIndicator|onRefresh|pullToRefresh" \
     packages/zcrud_core/lib/src/presentation/list/ packages/zcrud_screen/lib/   → RC=1, 0 ligne
```
`ai_experts_page.dart:69-76` enveloppe son corps dans `SmartRefresher` (paquet `pull_to_refresh`),
avec régénération de `valueKey` au refresh.

---

## 4. L'arithmétique du gain

Bornes de blocs relevées par `grep -n` sur les deux fichiers.

**`ai_routers_page.dart` — 803 l**

| Bloc | Lignes | Sort |
|---|---:|---|
| `buildCard` :296-570 | 275 | **conservé** (part en `itemBuilder`) |
| état vide :140-286 | 147 | **conservé** (R6, aucune prise) |
| regroupement par effort :571-636 | 66 | **conservé** (R4) |
| `_buildEffortSection` :637-763 | 127 | **conservé** (R4) |
| `_buildFloatingActionButton` :765-802 | 38 | **conservé** (R3, non branchable) |
| **total conservé** | **653** | **81 %** |
| supprimable (app-bar :43-74, accès refusé :75-139, `StreamBuilder`/tri) | **~150** | |

**`ai_experts_page.dart` — 1 330 l**

| Bloc | Lignes | Sort |
|---|---:|---|
| `buildAssistantCard` :297-929 | 633 | **conservé** |
| état vide :130-296 | 167 | **conservé** (R6) |
| sections A→Z :930-1117 | 188 | **conservé** (R4) |
| `buildFloatingActionButton` :1119-1205 | 87 | **conservé** (R3) |
| **total conservé** | **1 075** | **81 %** |
| supprimable (app-bar :52-67, `requestBody`/`SmartRefresher` :68-129, câblage onglets/ACL :1206-1330 partiellement) | **~255** | |

**Gain brut plafond ≈ 150 + 255 = ~405 lignes**, contre **~1 700 annoncées** — soit **24 %** de
l'annonce, et 19 % des 2 133 lignes des deux fichiers.

**À porter au débit du même bilan** (code hôte **net-nouveau**, sans lequel rien ne compile) :
2 × adaptateur `ZRepository` (9 membres), 2 × `listFields` (34 et 27+ champs), 2 × `cellsOf`,
2 × `editionBuilder`, 1 pont `ZAcl` depuis `RessourceACL`/`AppUserPermissions`
(`iffd/lib/.../ressource_acl.dart`, 6 occurrences seulement de `ZAcl` dans tout `iffd/lib`).

Le solde net est, au mieux, nul.

---

## 5. Ce qui serait vrai à la place

> `ZCrudScreen` couvre la **coquille** de ces deux pages — `Scaffold`, app-bar, recherche
> intégrée, garde d'accès (`_buildAccessDenied` :3686), bouton de création, corbeille, et — pour
> les experts — les **onglets par filière** avec leur ACL, leur filtre serveur et leur graine de
> création par onglet (`ZListTab.baseFilters/itemFilter/acl/defaultItemBuilder`). C'est réel et
> c'est utile.
>
> Il ne couvre **pas la substance** : 81 % des lignes des deux pages sont des cartes sur mesure,
> des **sections regroupées** (A→Z ; accordéons par effort), des **états vides illustrés** et un
> **FAB à état**. Trois prises manquent au socle — passe-plat `floatingActionButton`, layout de
> liste **groupé**, `emptyBuilder` — et la seule échappatoire existante (`ZListCustomLayout`)
> perd les actions de ligne. Gain réaliste : **~400 lignes brutes**, absorbées par les deux
> adaptateurs `ZRepository`, les `listFields`/`cellsOf` écrits à la main (aucun `ZcrudRegistry`
> chez l'hôte) et le pont `ZAcl`.

**Ce que le socle devrait gagner pour rendre l'affirmation vraie** : (1) `floatingActionButton` +
`floatingActionButtonLocation` en passe-plat sur `ZCrudScreen` vers `ZPageScaffold` (les deux
champs existent déjà côté `zcrud_ui_kit`) ; (2) une variante `ZListLayout` **groupée**
(`groupOf` + en-tête de groupe + repli persistable, sur le patron de `ZSectionCollapseStore`) ;
(3) un `emptyBuilder`/`ZEmptyState` injectable sur `DynamicList` ; (4) le passage de
`interaction` à `ZListCustomLayout`.

---

*Aucune écriture hors de ce répertoire. Aucun test lancé. Aucun secret cité.*
