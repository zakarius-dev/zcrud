# Story DP.6: `subItems` mode compact + dialog d'édition par item (parité DODLP — B8)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want que le champ **sous-liste** (`subItems`) offre, **en plus** du rendu inline existant, un **mode compact** — une liste résumé/tabulaire d'items où chaque item s'édite dans un **dialog dédié** (ajouter / consulter / modifier / supprimer avec confirmation), chaque action étant **filtrée par `ZAcl`**,
so that un formulaire DODLP qui affiche ses sous-éléments en **liste condensée + dialog par item** (UX `DynamicSubListScreen`) rende **structurellement à l'identique** sous zcrud, sans imposer le déballage inline de tous les sous-champs de tous les items, tout en **préservant** le mode inline actuel et les invariants SM-1/AD-2.

Périmètre : **`zcrud_core` uniquement** (+ ses tests). Gap couvert : **B8** (`subItems` inline vs liste compacte + dialog + ACL par action). Réf : `docs/dodlp-edition-parity-gap.md` §1 (B8), §2.4 (ligne `subItems` **blocking**), §3 (B8) ; épic `E-DP` story **DP-6**. Référence DODLP (lecture seule) : `dodlp-otr/lib/modules/data_crud/presentation/views/dynamic_list_viewer.dart` (`DynamicSubListScreen`) + `edition_screen.dart:3770-3852` (câblage) + `models.dart:580-669` (props).

**Changement d'UX fondamental (raison du classement blocking) :** aujourd'hui `ZSubListFieldWidget` rend **TOUS les sous-champs de TOUS les items en ligne** (mini-CRUD inline, E3-3b-2). DODLP rend une **liste résumé** (colonnes/titre par item) + un **dialog d'édition par item** avec **actions ACL** (view/create/update/delete, + copy côté DODLP). DP-6 ajoute ce mode **sans supprimer** l'inline.

---

## Contexte DODLP retenu (source de vérité comportementale)

UX réelle de `DynamicSubListScreen` (`dynamic_list_viewer.dart`) — ce que DP-6 reproduit fidèlement :

1. **En-tête (caption)** : icône optionnelle + titre (`titleLarge`) + **bouton d'ajout** rendu **uniquement si** `!readOnly && acl.create`. (`getCaption`, l.128-148)
2. **Bouton d'ajout** : `IconButton(Icons.add)` simple (le `PopupMenuButton` multi-gabarits `popUpMenuOptions` est **hors périmètre DP-6** → M18/M19, à noter comme non couvert). (`_buildAddButton`, l.89-126)
3. **Corps** : si liste vide → rien (en readOnly) / en-tête seul ; sinon **table résumé** — une **colonne par champ résumé** (`fields`, libellé capitalisé) + une **colonne d'actions** en fin de ligne. (`_buildPaginatedDatatable` + `dataColumns`, l.235-430) — le mode `itemsAreTags` et le `listViewBuilder` custom sont **hors périmètre DP-6**.
4. **Cellule** : valeur du champ affichée en lecture (formatage devise/suffixe/traducteur côté DODLP — zcrud rend la valeur via son propre rendu de cellule, sans logique métier). (`buildDataCell`, l.313-349)
5. **Actions de ligne** (`_buildCrudActionsbuttons`, l.189-233), **chacune gated par ACL** :
   - **view** (`acl.read`) → ouvre le dialog en lecture ;
   - **edit** (`!readOnly && acl.update`) → ouvre le dialog d'édition ;
   - **copy** (`!readOnly && acl.copy`) → duplique — **hors périmètre DP-6** (ACL `copy` = M7, à noter) ;
   - **delete** (`!readOnly && (acl.delete || acl.clear)`) → **dialog de confirmation** puis suppression ; désactivé si `item["canBeDeleted"] == false`.
6. **Édition par item** : `onCrud(item, Crud.*)` ouvre un écran/dialog d'édition (`showResourceBottomModalDialog` / `EditionScreen`) sur le **sous-schéma** de l'item et **retourne l'item modifié** ; `create/copy` → **append**, `update` → **remplace à l'index** (fallback par `id`), `delete` → **retire**. (`edition_screen.dart:3793-3846`)
7. **Titre d'item** : `itemTitleBuilder(item)` produit un titre/résumé (en-tête du dialog, item builder). Côté zcrud : dérivé des champs résumé (domaine pur) + **seam** de présentation optionnel.

**Distinction NON-NÉGOCIABLE (ne pas confondre — cf. `z_sub_list_screen.dart` doc-comment) :** DP-6 modifie le **CHAMP d'édition embarqué** `ZSubListFieldWidget` (value-objects `List<Map>` dans le document parent, couche `presentation/edition/families/`). Il **ne modifie PAS** `ZSubListScreen<T>` (E4-5), qui est l'**écran-liste d'entités DISTINCTES reliées** via `ZRepository` (couche `presentation/list/`). `ZSubListScreen` sert seulement de **précédent d'implémentation** pour le filtrage d'actions par `ZAcl` (E4-4, `ZActionAclMode`, `ZRowAction`) — à **imiter**, pas à importer.

---

## Acceptance Criteria

### Bloc A — Config additive `displayMode` + résumé (domaine, rétro-compat)

1. **Enum `ZSubListDisplayMode`.** Un enum public `ZSubListDisplayMode { inline, compact }` existe dans la couche `domain` de `zcrud_core` (`z_sub_list_config.dart`, pur-Dart `const`, **aucune** dépendance Flutter — AD-1), documenté et exporté par le barrel `domain.dart` (là où `ZSubListConfig` est déjà exporté, ligne 46). Valeurs en camelCase (canonique §5). `inline` = comportement E3-3b-2 actuel ; `compact` = liste résumé + dialog (parité DODLP).

2. **`ZSubListConfig.displayMode` additif, défaut `inline`.** `ZSubListConfig` porte `final ZSubListDisplayMode displayMode`, **défaut `ZSubListDisplayMode.inline`**, intégré au constructeur `const`, à `==` et à `hashCode`. Une `ZSubListConfig` construite sans `displayMode` conserve **exactement** l'égalité de valeur et le rendu inline actuels (aucune régression sur `z_sub_list_test.dart`).

3. **Champs résumé `summaryFields` (pur-données).** `ZSubListConfig` porte `final List<String> summaryFields` (défaut `const []`) — la liste **ordonnée** des `name` de sous-champs affichés comme **colonnes/valeurs de résumé** en mode `compact` (miroir des `fields` de `DynamicSubListScreen`). Contrainte de pureté domaine (garde `domain_purity_test.dart`) : **aucune closure ni widget** dans la config — un titre/rendu personnalisé passe par un **seam de présentation** (AC12), pas par le domaine. Intégré au constructeur `const`, `==`, `hashCode` (égalité profonde de liste, réutiliser `_listEquals`). Défaut vide → repli documenté en AC8.

### Bloc B — Rendu du mode compact (liste résumé)

4. **Dispatch par `displayMode`.** `ZSubListFieldWidget` lit `config.displayMode`. `inline` → branche existante **inchangée** (cartes empilées, sous-formulaires inline). `compact` → nouvelle branche « liste résumé + dialog » (AC5-AC13). Le choix est fait **une fois** au `build` du conteneur (pas de rebuild par frappe — l'édition vit dans le dialog, AC10).

5. **En-tête compact.** En mode `compact`, un en-tête affiche le **libellé du champ** (`field.label ?? field.name`, via le seam l10n `label`) et, **si `!readOnly && acl.can(create)`**, un **bouton d'ajout** accessible (`IconButton`/`TextButton.icon`, cible ≥ 48 dp, `Semantics`/tooltip, libellé l10n `addItem`). Aucun bouton d'ajout si `readOnly` **ou** ACL `create` refusée.

6. **Liste résumé par item.** En mode `compact`, chaque item est rendu comme **une ligne résumé** (pas ses sous-champs éditables inline) : les valeurs des `summaryFields` (dans l'ordre), rendues en **lecture** (texte dérivé de la valeur brute ; `null`/absent → chaîne vide, AD-10). L'implémentation peut utiliser un `DataTable`/`Table` (colonnes = `summaryFields`) **ou** une liste de `ListTile`/lignes résumé — au choix du dev, tant que : (a) le contenu large **défile horizontalement** dans son propre conteneur (`overflow`/scroll) sans déborder ; (b) chaque ligne porte ses **actions de fin de ligne** (AC7).

7. **Actions de fin de ligne (gated ACL).** Chaque ligne résumé porte des actions accessibles (`IconButton` ≥ 48 dp, `Semantics`/tooltip l10n), **rendues conditionnellement** :
   - **consulter** (icône `visibility`/`remove_red_eye`) si `acl.can(view)` → ouvre le dialog en **lecture seule** (AC11) ;
   - **modifier** (icône `edit`) si `!readOnly && acl.can(update)` → ouvre le dialog d'édition (AC10) ;
   - **supprimer** (icône `delete_outline`) si `!readOnly && acl.can(delete)` → **confirmation** puis retrait (AC9).
   Aucune action non autorisée n'est rendue (mode `hide`, aligné `ZActionAclMode.hide` d'E4-4).

8. **Repli `summaryFields` vide.** Si `summaryFields` est vide, le résumé de ligne dérive d'un **titre par défaut** : concaténation lisible des valeurs non nulles des `itemFields` (ordre du sous-schéma), tronquée proprement — **jamais** un déballage de tous les champs éditables. Documenté ; couvert par test.

### Bloc C — Dialog d'édition par item (add / edit / delete)

9. **Ajout via dialog.** Le bouton d'ajout ouvre le **dialog d'édition d'un item** (AC10) amorcé sur un item **vide** (`const {}`). À la **validation** du dialog : un nouvel item est **ajouté** à la sous-liste (append), la ligne résumé apparaît, et la `List<Map>` agrégée est écrite au parent via `onChanged` (`_syncToParent`). À l'**annulation** : aucun item ajouté, aucun effet de bord.

10. **Édition via dialog.** Le dialog d'édition (`showDialog`/`Dialog`, **pas** un `Form` global) héberge un **`ZFormController` PROPRE** amorcé depuis le `Map` de l'item, et rend les `itemFields` via le **dispatcher `ZFieldWidget`** (réutilisation intégrale de la machinerie E3 — **ne pas réinventer** un moteur d'édition). Il expose **Enregistrer** (l10n `save`) et **Annuler** (l10n `cancel`). À **Enregistrer** : le `Map` agrégé de l'item remplace l'item d'origine **à sa place** (index/id stable), la ligne résumé se met à jour, la sous-liste agrégée est réécrite au parent. Le `ZFormController` du dialog est **`dispose`** à sa fermeture (aucune fuite). **SM-1 préservé dans le dialog** : taper dans un sous-champ ne reconstruit que ce champ (via `ZFieldWidget`/`ZFieldListenableBuilder`), jamais le dialog entier ni la liste résumé sous-jacente.

11. **Consultation (lecture seule).** L'action « consulter » ouvre le **même dialog** avec les `itemFields` rendus en **`readOnly`** (chaque spec `copyWith(readOnly: true)`, patron existant) : pas de bouton Enregistrer, seul **Fermer** (l10n `cancel`/`close`). Aucune mutation possible.

12. **Seam de titre d'item (présentation, optionnel).** `ZSubListFieldWidget` accepte un paramètre **optionnel** `itemTitleBuilder` (typedef `String Function(Map<String,dynamic> item)`, défaut `null`) — équivalent présentation de l'`itemTitleBuilder` DODLP — utilisé comme **titre du dialog** et **repli de résumé** de ligne quand fourni. `null` → titre dérivé (`summaryFields`/AC8) + libellé du champ. Ce seam vit en **présentation** (jamais dans la config domaine — AC3). (Alternative acceptable : exposer ce builder via `ZWidgetRegistry` sous une convention `kind`, si le dev juge l'injection par registre plus cohérente ; sinon paramètre widget direct.)

13. **Suppression avec confirmation.** L'action « supprimer » ouvre un **dialog de confirmation** (`AlertDialog`, message l10n dédié, boutons **Supprimer**/**Annuler**) ; à la confirmation : l'item est retiré, son sous-contrôleur (le cas échéant) `dispose`, la sous-liste agrégée réécrite au parent. À l'annulation : aucun retrait. (Parité `buildConfirmDialog` DODLP — le soft-delete/restore reste M18, **hors périmètre**.)

### Bloc D — ACL par action (`ZAcl`)

14. **Injection ACL additive.** `ZSubListFieldWidget` accepte des paramètres **optionnels additifs** `ZAcl? acl` (défaut → **`const ZAllowAllAcl()`** = permissif, zéro régression) et `String? collectionId` (transmis à `ZAcl.can(..., collectionId:)`). Le mode `inline` **ignore** l'ACL (comportement E3-3b-2 inchangé) ; le mode `compact` la **consomme** pour chaque action (AC5/AC7). Réutiliser l'enum **existant** `ZCrudAction` (`view`/`create`/`update`/`delete`/`restore`) — **ne pas** étendre l'enum dans DP-6.

15. **Filtrage réel par action.** Pour chaque action compact, la décision est `acl.can(action, target: ..., collectionId: collectionId)` : `create` gate le bouton d'ajout ; `view` gate « consulter » ; `update` gate « modifier » ; `delete` gate « supprimer ». Une ACL refusant une action **masque** le contrôle correspondant (aucun bouton mort). `target` : passer l'entité si un `ZEntity` est dérivable de l'item, sinon `null` (l'item embarqué est un `Map`, pas nécessairement un `ZEntity` — décision documentée, `collectionId` reste le discriminant principal).

### Bloc E — Invariants AD (SM-1 / a11y / défensif)

16. **AD-2 / SM-1 (objectif produit n°1) — place & rebuild.** En mode `compact` : le conteneur écoute un **canal STRUCTUREL** (add/edit/delete committés → `setState` local), **jamais** la valeur des sous-champs (l'édition est confinée au dialog). Chaque ligne résumé est **keyée** par une **identité stable** d'item (`ValueKey(itemId)`, jamais l'index ni le hash de contenu) → un retrait/ajout ne vole/perd pas l'état des voisines. L'agrégation vers le parent (`onChanged`/`_syncToParent`) **ne reconstruit pas** le conteneur (patron E3-3b-2 conservé). Aucun `setState` de niveau formulaire, **aucun `Form`/`FormBuilder` global** (dialog inclus).

17. **a11y / RTL (AD-13).** Tous les contrôles (add/view/edit/delete, boutons du dialog) = cibles ≥ 48 dp avec `Semantics`/tooltips explicites (libellés l10n) ; **tous** les insets/alignements introduits sont **directionnels** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`, `PositionedDirectional`) — **aucun** `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`. Le dialog est navigable/fermable au clavier ; le focus initial est raisonnable.

18. **Défensif (AD-10) & thème (FR-26).** Lecture défensive : `initialValue`/item non conforme, champ absent/corrompu → repli sûr (`[]`, chaîne vide) **sans throw**, jamais d'échec du parent (réutiliser `_readList`). **Aucune** couleur ni style codé en dur (bordures/fonds dérivés de `ZcrudTheme.of(context)`/`Theme.of(context)` — la garde `style_purity_test.dart` reste verte). `ListView.builder` (pas `ListView(children:)`) si une liste scrollable est utilisée. `const` sur les widgets immuables.

### Bloc F — Non-régression & couverture de tests

19. **Mode inline strictement préservé.** Les tests existants `test/presentation/edition/z_sub_list_test.dart` (add/remove/reorder inline, SM-1 imbriqué, `dynamicItem`, `Form → findsNothing`) restent **verts sans modification** (hors ajout éventuel de cas). Aucune régression d'API publique de `ZSubListFieldWidget`/`ZSubListConfig` (ajouts uniquement additifs, defaults rétro-compatibles).

20. **Tests du mode compact.** Nouveaux tests widget couvrant : (a) `compact` rend une **liste résumé** (N lignes pour N items, `summaryFields` visibles) et **non** les sous-champs éditables inline (`TextFormField` absents hors dialog) ; (b) **ajout** via dialog → nouvel item + `onChanged` reçoit la `List<Map>` allongée ; (c) **édition** via dialog → item modifié **à sa place**, `onChanged` reflète la valeur ; (d) **suppression** → dialog de confirmation, confirmation retire l'item / annulation le conserve ; (e) **consultation** = dialog `readOnly` sans bouton Enregistrer.

21. **Tests ACL.** Cas couvrant chaque action : une `ZAcl` de test refusant `create`/`update`/`delete`/`view` **masque** le contrôle correspondant ; une ACL permissive (défaut) les affiche tous. Vérifier que `collectionId` est bien transmis à `can(...)`.

22. **Test SM-1 dialog.** Un test prouve qu'une saisie dans un sous-champ du **dialog** ne reconstruit que ce champ (compteur de rebuild via le seam `itemFieldBuilder`/instrumentation), et **jamais** le conteneur de liste résumé ni les autres lignes. `Form → findsNothing` dans le dialog.

23. **Vérif verte.** `melos run generate` (le cas échéant) → `dart analyze` RC=0 → `flutter test` (package `zcrud_core`) RC=0. Gardes `domain_purity_test.dart`, `style_purity_test.dart`, `directionality`/a11y (si présentes) **vertes**.

---

## Tasks / Subtasks

- [x] **T1 — Config domaine additive** (AC1-AC3)
  - [x] Ajouter `enum ZSubListDisplayMode { inline, compact }` dans `z_sub_list_config.dart` (doc-comment, camelCase).
  - [x] Ajouter `final ZSubListDisplayMode displayMode` (défaut `inline`) + `final List<String> summaryFields` (défaut `const []`) au constructeur `const`, `==`, `hashCode` (réutiliser `_listEquals` pour `summaryFields`).
  - [x] Vérifier l'export via `domain.dart` (déjà exporté ligne 46). `domain_purity_test.dart` vert.
- [x] **T2 — Seams & ACL sur le widget** (AC12, AC14)
  - [x] Ajouter au constructeur de `ZSubListFieldWidget` : `ZAcl acl` (défaut `const ZAllowAllAcl()`), `String? collectionId`, `ZSubItemTitleBuilder? itemTitleBuilder` — **tous additifs**, defaults rétro-compatibles.
  - [x] Importer `z_acl.dart` (domaine) dans le widget de présentation.
- [x] **T3 — Branche de rendu compact** (AC4-AC8, AC16-AC18)
  - [x] Dispatch `displayMode` au `build` (inline = `_buildInline` intact ; compact = `_buildCompact`).
  - [x] En-tête compact + bouton d'ajout gated `create`.
  - [x] Liste résumé keyée par `ValueKey(itemId)` (`ListView.builder` shrinkWrap) : lecture des `summaryFields` (repli titre AC8) + actions gated ACL (view/update/delete) ; scroll horizontal encapsulé.
- [x] **T4 — Dialog d'édition par item** (AC9-AC13)
  - [x] `_ZSubItemEditDialog` : `ZFormController` propre amorcé du `Map`, rendu des `itemFields` via `ZFieldWidget`, boutons Enregistrer/Annuler, `dispose` à la fermeture. **Aucun `Form` global.**
  - [x] Câbler add (item vide → append), edit (remplace à sa place via réécriture des tranches, identité stable), view (`readOnly:true`, sans Enregistrer).
  - [x] Dialog de confirmation de suppression (`AlertDialog`) + retrait + `_syncToParent` (via `_removeAt`).
  - [x] Titre du dialog via `itemTitleBuilder`/repli.
- [x] **T5 — l10n** (AC5, AC7, AC10, AC11, AC13)
  - [x] Ajout à `z_localizations.dart` (en + fr) : `viewItem`, `editItem`, `deleteItem`, `confirmDeleteItem`, `noItems` (`close`/`addItem`/`save`/`cancel`/`delete` déjà présents). **Additif** (aucune clé existante modifiée).
- [x] **T6 — Tests** (AC19-AC23)
  - [x] Nouveau fichier `test/presentation/edition/z_sub_list_compact_test.dart` (18 tests) : rendu compact, CRUD dialog, ACL par action, SM-1 dialog, défensif, RTL, inline préservé.
  - [x] `z_sub_list_test.dart` (inline) inchangé et vert.
  - [x] Rejoué analyze + test `zcrud_core` (+ gardes purity/style/a11y) — verts.

---

## Dev Notes

### Fichiers à toucher (couche & rôle)

| Fichier | Couche | Action | Contact partagé |
|---|---|---|---|
| `packages/zcrud_core/lib/src/domain/edition/z_sub_list_config.dart` | domain | **UPDATE** — enum `ZSubListDisplayMode` + `displayMode` + `summaryFields` (additifs) | **Oui** (exporté par `domain.dart:46`) — **additif strict**, defaults rétro-compat |
| `packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart` | presentation | **UPDATE** — branche compact + dialog + ACL/seams (constructeur additif) | **Oui** (exporté par `zcrud_core.dart:49`) — **API additive only** |
| `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` | presentation | **UPDATE** — clés l10n additives (en+fr) | **Oui** (fichier l10n partagé) — **ajouts uniquement** |
| `packages/zcrud_core/lib/src/domain/ports/z_acl.dart` | domain | **READ-ONLY** — réutiliser `ZCrudAction`/`ZAcl`/`ZAllowAllAcl` | **Ne PAS étendre l'enum** (copy/archive… = M7, hors périmètre) |
| `packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart` | presentation | **READ-ONLY** (sauf si `itemTitleBuilder` exposé via registre — option AC12) | Contact possible **seulement** si le seam passe par le registre ; sinon intact |
| `packages/zcrud_core/lib/src/presentation/list/z_sub_list_screen.dart` (`ZSubListScreen`) | presentation | **READ-ONLY** — **précédent** ACL/actions (E4-4), **PAS** la cible de DP-6 | Ne pas modifier ; ne pas confondre avec le champ embarqué |
| `packages/zcrud_core/test/presentation/edition/z_sub_list_compact_test.dart` | test | **NEW** | — |
| `packages/zcrud_core/test/presentation/edition/z_sub_list_test.dart` | test | **READ-ONLY** (doit rester vert ; ajouts éventuels seulement) | — |

> ⚠️ **Points de contact `zcrud_core` partagés à traiter en additif strict** : `z_sub_list_config.dart` (domaine exporté), `z_sub_list_field_widget.dart` (widget exporté), `z_localizations.dart` (l10n). Aucune signature/valeur existante ne change ; uniquement des ajouts avec defaults rétro-compatibles. **Ne pas** modifier `z_acl.dart` (enum figé pour DP-6). Comme la story reste **dans un seul package** et touche des fichiers `zcrud_core` partagés, elle ne doit **pas** être parallélisée avec une autre story écrivant `zcrud_core` (règle de parallélisation CLAUDE.md).

### État actuel des fichiers UPDATE (à préserver)

- **`z_sub_list_field_widget.dart`** (E3-3b-2) : mini-CRUD **inline**. Source de vérité en édition = `List<_SubItem>` (`id` monotone `item_${_seq++}` + `ZFormController` par item). Agrégation vers parent par **listener sur chaque slice imbriqué** (`_attach`/`_syncToParent`) — le conteneur n'est **jamais** souscrit à la tranche parente (monté avant la souscription parente par `ZFieldWidget`). `dispose` propre des sous-contrôleurs. Cartes keyées `ValueKey(itemId)`, sous-champs keyés `${itemId}/${field.name}`. **À préserver intégralement pour `displayMode == inline`.** La branche compact **réutilise** `_items`/`_makeItem`/`_readList`/`_syncToParent`/`_removeAt` autant que possible ; l'édition d'un item en compact peut soit muter le `ZFormController` de l'item existant via le dialog, soit reconstruire le `Map` — garder l'agrégation `_syncToParent` comme **unique voie d'écriture** vers le parent.
- **`z_sub_list_config.dart`** : config `const` pur-données (garde `domain_purity_test.dart`). `itemFields` (sous-schéma), `reorderable`. Égalité profonde via `_listEquals` (évite `package:collection`, AD-1 out-degree 0). **Le réordonnancement reste une notion inline** — le mode compact n'offre pas de réordonnancement (parité DODLP : table sans reorder) ; `reorderable` sans effet en compact (documenter).
- **`z_acl.dart`** : `ZCrudAction {view, create, update, delete, restore}` ; `ZAcl.can(action, {target, collectionId})` **synchrone** ; `ZAllowAllAcl` permissif `const`. Suffisant pour DP-6 (view/create/update/delete). `copy` **absent** → l'action « copier » DODLP est **hors périmètre** (M7).
- **`z_localizations.dart`** : possède déjà `save/cancel/delete/edit/add/addItem/removeItem/moveItemUp/moveItemDown` (en+fr). **Manquent** : `viewItem`, `editItem`, `deleteItem`, `confirmDeleteItem`, `noItems`, `close` → à ajouter (en+fr), additif.

### Contraintes d'architecture (AD applicables)

- **AD-1** : `zcrud_core` reste out-degree 0 (aucun gestionnaire d'état, aucun backend). Le dialog n'introduit aucune dépendance ; `showDialog` = `package:flutter/material.dart` déjà importé.
- **AD-2 / SM-1 (objectif n°1)** : rebuild ciblé. En compact, l'édition est **confinée au dialog** (son propre `ZFormController`, ses `ZFieldWidget`) → la liste résumé n'est reconstruite que sur mutation **structurelle committée** (add/edit/delete), pas par frappe. Controllers stables (create/dispose), clés stables `ValueKey(itemId)`, aucun `Form` global (dialog inclus).
- **AD-4** : extensions additives (`displayMode`/`summaryFields` = ajouts `const`, jamais `sealed`). Le seam `itemTitleBuilder` (présentation) ou l'injection registre respectent l'extensibilité sans polluer le domaine.
- **AD-10** : désérialisation/lecture défensive (item non conforme → repli sûr, jamais d'échec parent).
- **AD-13** : a11y (≥ 48 dp, `Semantics`, clavier) + RTL (directionnel only).
- **AD-16 / FR-26** : `ZAcl` app-supplied (aucune règle métier dans le cœur) ; thème injecté (`ZcrudTheme`), aucun style/couleur en dur.
- **AD-15 / SM-5** : neutralité — imports limités à `package:flutter/material.dart` + types `zcrud_core` ; aucun Syncfusion/firebase/hive/gestionnaire d'état.

### Précédent d'implémentation à imiter (E4-4)

`ZSubListScreen` + `DynamicList` filtrent déjà les **actions de ligne** par `ZAcl` avec `ZActionAclMode {hide, disable}` (`z_row_action.dart`, `dynamic_list_actions_acl_test.dart`). DP-6 reproduit la **même intention** (mode `hide` par défaut) sur le **champ embarqué** — regarder `test/presentation/list/dynamic_list_actions_acl_test.dart` pour le patron de test ACL (fausse `ZAcl` refusant des actions ciblées).

### Testing standards

- `flutter_test` ; `MaterialApp > Directionality > Scaffold > SingleChildScrollView` (patron `_host` de `z_sub_list_test.dart`, tester aussi `TextDirection.rtl`).
- Preuve SM-1 : instrumenter via le seam `itemFieldBuilder` (déjà `@visibleForTesting`) pour compter les rebuilds des sous-champs **dans le dialog**.
- Dialog : `tester.tap` sur l'icône d'action → `await tester.pumpAndSettle()` → interagir avec les champs du dialog → tap Enregistrer/Annuler → asserter la `List<Map>` capturée via `onChanged`.
- ACL : injecter une `ZAcl` de test (par action) et asserter la présence/absence des `IconButton` (`find.byIcon` / `find.byTooltip`).
- Gardes : `domain_purity_test.dart` (config sans closure), `style_purity_test.dart` (zéro couleur en dur) doivent rester vertes.

### Hors périmètre DP-6 (à ne PAS implémenter — noter pour stories ultérieures)

- **ACL `copy`/`archive`/`publish`/`clear`/`validate`/`history`** et consommation côté `DynamicEdition` → **M7**.
- **`popUpMenuOptions`** (gabarits de création multiples), **soft-delete/restore**, **`captionBuilder`**, `itemsAreTags`, `listViewBuilder`/`itemBuilder` custom, `dynamicSubItemTransformer`, `crudRepository` inline → **M18/M19**.
- **`ZSubListScreen<T>`** (écran-liste d'entités reliées, E4-5) : **inchangé**.

### Project Structure Notes

- Story mono-package (`zcrud_core`) ; respecte la frontière `domain`/`presentation` (config en domaine, widgets/dialog/l10n en présentation).
- Nommage : types publics préfixe `Z` (`ZSubListDisplayMode`) ; fichiers snake_case ; enum camelCase.
- Variance : le seam `itemTitleBuilder` **doit** rester en présentation (couche widget) — l'introduire dans `ZSubListConfig` (domaine) casserait `domain_purity_test.dart`. C'est la raison du choix « colonnes `summaryFields` en domaine (pur-données) + builder de titre en présentation ».

### References

- [Source: docs/dodlp-edition-parity-gap.md#1 — gap B8 (blocking)]
- [Source: docs/dodlp-edition-parity-gap.md#2.4 — ligne `subItems (liste compacte + dialog)`]
- [Source: docs/dodlp-edition-parity-gap.md#3 — action B8]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E-DP — DP-6]
- [Source: dodlp-otr/lib/modules/data_crud/presentation/views/dynamic_list_viewer.dart — `DynamicSubListScreen` (caption/table/actions/dialog)]
- [Source: dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart#3770-3852 — câblage `subItems` (onCrud create/update/delete/copy)]
- [Source: dodlp-otr/lib/modules/data_crud/models.dart#580-669 — props `subItems` (itemTitleBuilder/itemActionsBuilder/popUpMenuOptions/aclBuilder/acl)]
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart — état actuel inline (E3-3b-2)]
- [Source: packages/zcrud_core/lib/src/domain/edition/z_sub_list_config.dart — config additive]
- [Source: packages/zcrud_core/lib/src/domain/ports/z_acl.dart — `ZCrudAction`/`ZAcl`/`ZAllowAllAcl`]
- [Source: packages/zcrud_core/lib/src/presentation/list/z_sub_list_screen.dart — distinction E4-5 + précédent ACL E4-4]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md — AD-1/2/4/10/13/15/16]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story` réel).

### Debug Log References

- `dart analyze packages/zcrud_core` → RC=0 (No issues found).
- `flutter test` (package `zcrud_core`) → 701 tests, All tests passed.
- `flutter test z_sub_list_compact_test.dart` → 18/18.
- `flutter test z_sub_list_test.dart` (inline) → inchangé, vert.
- Gardes `domain_purity_test.dart` / `style_purity_test.dart` / `domain_entrypoint_dart_test.dart` → vertes.
- `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK.
- Codegen : **sans objet** (aucune annotation `@ZcrudModel`/`@ZcrudField`/`@JsonSerializable` ajoutée/modifiée — `ZSubListConfig` n'est pas annotée).

### Completion Notes List

- **Mode compact additif** : `ZSubListConfig.displayMode` (défaut `inline`, rétro-compat strict) + `summaryFields` (pur-données `const`). Le mode `inline` (E3-3b-2) est dispatché vers `_buildInline` **inchangé** ; `compact` vers `_buildCompact` (nouveau).
- **Dialog par item** (`_ZSubItemEditDialog`) : `ZFormController` PROPRE amorcé du `Map`, sous-champs via `ZFieldWidget` (réutilisation E3), `dispose` à la fermeture, **aucun `Form` global**. add=append via `_makeItem`, edit=réécriture des tranches du contrôleur de l'item (identité `ValueKey(itemId)` stable, remplace à sa place), view=`copyWith(readOnly:true)` sans Enregistrer, delete=`AlertDialog` de confirmation → `_removeAt` (dispose + `_syncToParent`, unique voie d'écriture parent).
- **ACL** : injection additive `acl` (défaut `const ZAllowAllAcl()`) + `collectionId` ; chaque action `can(action, collectionId:)` en mode `hide` (contrôle non rendu si refusé). `ZCrudAction` NON étendu. `inline` ignore l'ACL.
- **SM-1 (AD-2)** : édition confinée au dialog (controller séparé) → taper ne reconstruit ni la liste résumé ni les autres lignes ; canal structurel (`setState`) pour add/edit/delete committés ; test compteur prouve un seul sous-champ reconstruit dans le dialog + `Form` findsNothing.
- **Défensif (AD-10)** : `_readList` filtre les entrées non-`Map` ; `itemTitleBuilder` appliqué via `_safeTitle` (try/catch → repli). **FR-26** : bordures dérivées de `ZcrudTheme`, zéro couleur en dur. **AD-13** : IconButtons ≥ 48 dp + tooltips l10n + directionnel (guideline a11y verte, RTL testé).
- **Seam de titre** : `itemTitleBuilder` en **présentation** (typedef `ZSubItemTitleBuilder`), jamais dans la config domaine (garde purity).
- **Écartés (hors périmètre, documentés)** : ACL `copy`/`archive`/`clear` = M7 ; `popUpMenuOptions`, soft-delete/restore, `captionBuilder`, `itemsAreTags`, `listViewBuilder`/`itemBuilder` custom, `crudRepository` = M18/M19 ; `ZSubListScreen<T>` (E4-5) inchangé ; `reorderable` sans effet en compact (parité DODLP : table sans reorder).
- **Points de contact core partagés (additif strict)** : `z_sub_list_config.dart` (domaine, +enum/+2 champs, `==`/`hashCode` étendus) ; `z_sub_list_field_widget.dart` (widget, +3 params constructeur, +branche compact) ; `z_localizations.dart` (+5 clés en+fr). Aucune signature/valeur existante modifiée. `z_acl.dart` NON modifié.

### File List

- `packages/zcrud_core/lib/src/domain/edition/z_sub_list_config.dart` (MODIFIÉ — enum `ZSubListDisplayMode` + `displayMode`/`summaryFields`, `==`/`hashCode`).
- `packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart` (MODIFIÉ — constructeur additif, dispatch, `_buildCompact`, `_CompactRow`, `_ZSubItemEditDialog`).
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (MODIFIÉ — 5 clés l10n en+fr).
- `packages/zcrud_core/test/presentation/edition/z_sub_list_compact_test.dart` (NOUVEAU — 18 tests).
