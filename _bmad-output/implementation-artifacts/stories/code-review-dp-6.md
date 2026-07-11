# Code Review — DP-6 : `subItems` mode compact + dialog d'édition par item (parité DODLP, gap B8)

- **Skill** : `bmad-code-review` (skill BMAD réel, invoqué via le tool `Skill` ; PAS de fallback disque).
- **Story** : `_bmad-output/implementation-artifacts/stories/dp-6-subitems-compact-dialog.md` (23 ACs, blocs A-F).
- **Périmètre revu** (zcrud_core uniquement) :
  - `packages/zcrud_core/lib/src/domain/edition/z_sub_list_config.dart`
  - `packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart`
  - `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart`
  - `packages/zcrud_core/test/presentation/edition/z_sub_list_compact_test.dart`
- **Date** : 2026-07-11
- **Reviewer** : agent BMAD code-review (adversarial, ciblé)

---

## Verdict : **APPROVED**

Les 23 ACs sont couverts, les invariants AD ciblés sont respectés, et toutes les vérifications sont vertes.
Aucun finding HIGH/MAJEUR ni MEDIUM. Seulement 2 nits LOW (non bloquants). La story peut passer à `done`.

---

## Vérifications rejouées réellement (RC réels sur disque)

| Commande | Résultat | RC |
|---|---|---|
| `dart analyze packages/zcrud_core` | No issues found! | **0** |
| `flutter test packages/zcrud_core` | **701 tests, All tests passed!** | **0** |
| `python3 scripts/dev/graph_proof.py` | ACYCLIQUE OK · out-degree(zcrud_core)=0 (runtime) · CORE OUT=0 OK | **0** |
| `dart test packages/zcrud_core/test/purity/domain_entrypoint_dart_test.dart` | domain.dart surface les 4 APIs pur-Dart — All tests passed! | **0** |

- `z_sub_list_compact_test.dart` : **18 tests** verts (inclus dans les 701).
- `z_sub_list_test.dart` (inline) : inchangé et vert (non-régression E3-3b-2).
- Codegen : sans objet (aucune annotation `@ZcrudModel`/`@JsonSerializable` ajoutée ; `ZSubListConfig` n'est pas annotée).

---

## Analyse adversariale par axe (8 points imposés)

### (1) Mode inline STRICTEMENT préservé — RÉTRO-COMPAT ✅
- `ZSubListConfig.displayMode` défaut `ZSubListDisplayMode.inline` (l.65). Une config existante sans `displayMode` conserve l'égalité de valeur (`==`/`hashCode` étendus additivement, l.84-101) et le rendu inline.
- Dispatch au `build` (l.272-276) : `compact → _buildCompact`, sinon `_buildInline` **inchangé** (branche E3-3b-2 intégrale, l.279-344).
- `_displayMode` retombe défensivement sur `inline` si config absente/non conforme (l.170-176).
- Test AC19 (l.477-496) : config sans `displayMode` → 2 `TextFormField` inline. Vert.

### (2) AD-2 / SM-1 dans le dialog — controller propre + dispose + confinement ✅
- **`_ZSubItemEditDialog`** héberge un `ZFormController` **PROPRE** (l.681-692), amorcé du `Map` de l'item, rendu des `itemFields` via le dispatcher `ZFieldWidget` (l.700-707) — aucune ré-implémentation d'un moteur d'édition.
- **DISPOSE VÉRIFIÉ (pas de fuite)** : `_ZSubItemEditDialogState.dispose()` appelle `_controller.dispose()` (l.694-698). Le controller du dialog est local à l'état du dialog et libéré à sa fermeture. Aucune fuite.
- **AUCUN `Form` global** : le dialog est un `AlertDialog` + `Column` de `KeyedSubtree(ValueKey('dialog/<name>'))` (l.716-745), pas de `Form`/`FormBuilder`. Test AC22 asserte `find.byType(Form) findsNothing` (l.341).
- **Confinement** : l'édition vit dans le controller du dialog, SÉPARÉ des controllers d'items du conteneur. Le dispatcher monte `subList` hors de la tranche de valeur parente (`z_field_widget.dart` l.221-231, `_reseedable`, pas de `ZFieldListenableBuilder` de valeur) → écrire au parent ne reconstruit pas l'hôte. Test AC22 (compteur via seam `itemFieldBuilder`, l.309-364) : 20 frappes dans `f1` → `f2` inchangé, seul `f1` reconstruit.
- Lignes résumé keyées `ValueKey(item.id)` (identité stable, l.554-555) → un retrait/ajout ne vole pas l'état voisin (AC16).

### (3) AD-4 / ACL — injection défaut + gating réel par action ✅
- Injection additive `ZAcl acl = const ZAllowAllAcl()` + `String? collectionId` au constructeur (l.85-94). Défaut permissif → zéro régression.
- **Gating RÉEL par action** (l.504-510) : `canCreate = !readOnly && acl.can(create, collectionId)`, `canView = acl.can(view, collectionId)`, `canUpdate = !readOnly && acl.can(update, collectionId)`, `canDelete = !readOnly && acl.can(delete, collectionId)`. Mode **`hide`** : chaque contrôle rendu conditionnellement (`if (canCreate)` l.529, `if (canView/canUpdate/canDelete)` dans `_CompactRow` l.625-642). Aucun bouton mort.
- **`collectionId` transmis** à `can(...)` pour chaque action. Test AC21 (l.293-305) asserte `lastCollectionId == 'coll-42'`.
- **`ZCrudAction` NON étendu** : seuls `view/create/update/delete` (existants) sont consommés.
- **`z_acl.dart` NON modifié** : `git diff` vide sur ce fichier (vérifié).
- Le mode `inline` **ignore** l'ACL (branche `_buildInline` n'y touche pas) — conforme AC14.

### (4) AD-3 / AD-14 — pureté domaine (données `const`, aucune closure) ✅
- `ZSubListDisplayMode` : enum pur-Dart `const`, camelCase (`inline`/`compact`), documenté, exporté par `domain.dart:46`.
- `summaryFields : List<String>` (l.79-82) : pur-données ordonnées, défaut `const []`. **Aucune closure/widget** dans la config. Le seam de titre (`ZSubItemTitleBuilder`) vit en **présentation** (l.69-73), jamais dans le domaine.
- Égalité profonde via `_listEquals` réutilisé (l.91-92, 104-113), évite `package:collection` (AD-1 out-degree 0).
- Gardes vertes : `domain_entrypoint_dart_test` RC=0 ; `graph_proof` out-degree(core)=0.

### (5) AD-10 — défensif (item/summaryFields corrompus → sûr, jamais throw remontant) ✅
- `_readList` (l.185-193) filtre les entrées non-`Map` → `[]` ; entrée corrompue ignorée. Test AC18 (l.414-424) : `['pas-une-map', 42]` → aucun crash.
- **`summaryFields` référençant un `name` absent de `itemFields`** : `_summaryCells` lit `item.controller.valueOf(name)` ; `ZFormController.valueOf` = `_slices[name]?.value` (null-safe, **aucun throw**) → `_stringOf(null)` → `''`. Sûr.
- `summaryFields` vide → `_defaultTitle` : concaténation lisible des `itemFields` non nuls (l.369-381), jamais un déballage éditable. Test AC8 (l.367-389) : `Hello — World`.
- Seam de titre appliqué **défensivement** : `_safeTitle` try/catch → repli `null` (l.358-364). Test (l.426-447) : un builder qui `throw` → repli sur concat, aucun crash.

### (6) Sémantique CRUD — add=append / edit=remplace à sa place / delete=confirmation ✅
- **Add** (`_openAddDialog` l.447-452) : dialog amorcé sur `const {}` → à la validation, `_makeItem(result)` **append** + `_syncToParent`. Annulation → `result == null`, aucun effet. Tests l.101-150.
- **Edit** (`_openEditDialog` l.456-464) : remplace **à sa place** en réécrivant les tranches du controller de l'item existant (`setValue`), identité `ValueKey(item.id)` conservée. Test l.152-179 : `captured[0]='Xbis'`, voisin `captured[1]='Y'` intact.
- **Delete** (`_confirmDelete` l.472-492) : `AlertDialog` de confirmation (l10n `confirmDeleteItem`) → confirmer retire via `_removeAt` (dispose + sync), annuler garde. Test l.181-213.
- **`onChanged` émis** via `_syncToParent` (unique voie d'écriture parent) sur chaque mutation committée.

### (7) a11y ≥48 dp (AD-13) + FR-26 zéro couleur en dur ✅
- Actions = `IconButton` (cible ≥ 48 dp par défaut) + `tooltip` l10n (`addItem`/`viewItem`/`editItem`/`deleteItem`) — l.529-534, 625-642. Test AC17 `meetsGuideline(androidTapTargetGuideline)` vert (l.471), RTL (`TextDirection.rtl`).
- Insets/alignements **directionnels** : `EdgeInsetsDirectional.fromSTEB` (l.519, 540, 614, 621), `TextAlign.start` (l.413, 423, 526, 545). Aucun `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`.
- `ListView.builder` (l.548), pas `ListView(children:)`. Scroll horizontal du résumé encapsulé (`SingleChildScrollView(horizontal)` l.403).
- FR-26 : bordures via `ZcrudTheme.of(context).fieldBorderColor`/`radiusM` (l.557, 615-618), aucune couleur/style codé en dur. `Semantics(container, label)` sur le conteneur (l.512).

### (8) Non-régression DP-5/DP-10 + barrels ✅
- `z_sub_list_field_widget.dart` (champ embarqué) distinct de `z_field_widget.dart` (dispatcher) et de `z_sub_list_screen.dart` (E4-5, non touché).
- Exports intacts : `domain.dart:46` (`z_sub_list_config.dart`), `zcrud_core.dart:49` (`z_sub_list_field_widget.dart`). Aucun export existant supprimé/renommé (ajouts additifs only).
- Le dispatcher (`z_field_widget.dart` l.221-231) monte `subList` via `_reseedable` sans souscription de valeur → SM-1 préservé pour inline ET compact.
- Suite complète 701 tests verte → aucune régression cross-fichier dans zcrud_core.

---

## Findings

### HIGH / MAJEUR
_Aucun._

### MEDIUM
_Aucun._

### LOW / nits (non bloquants — consignés)

- **LOW-1 — Émissions `_syncToParent` redondantes à l'édition.**
  `z_sub_list_field_widget.dart:459-464` — dans `_openEditDialog`, chaque `item.controller.setValue(f.name, ...)` déclenche le listener attaché par `_attach` (→ `_syncToParent`), puis un `_syncToParent()` explicite est aussi appelé. Pour N `itemFields`, `onChanged` est émis N+1 fois par sauvegarde (l'état final est correct et idempotent — le dernier snapshot agrégé est cohérent). Impact : purement cosmétique/perf marginale (aucune boucle de rebuild car l'hôte n'est pas souscrit à sa tranche). Remédiation optionnelle : `_detach` pendant la réécriture batch puis `_reattach` + un seul `_syncToParent`, ou s'appuyer uniquement sur les listeners sans l'appel explicite. Non bloquant.

- **LOW-2 — Controllers d'items sous-utilisés en mode compact.**
  `z_sub_list_field_widget.dart:195-216` — en mode compact, chaque `_SubItem` conserve un `ZFormController` avec des value-listeners `_attach`és, alors que l'édition se fait dans un controller **séparé** (celui du dialog) ; ces listeners ne servent qu'à la voie redondante de LOW-1. Le controller par item reste utile comme porteur de valeurs (lu pour le résumé, écrit à la sauvegarde), donc la réutilisation de `_makeItem`/`_attach` est cohérente avec l'inline, mais l'attache de listeners est superflue en compact. Impact négligeable. Remédiation optionnelle : ne pas `_attach` en mode compact. Non bloquant.

---

## Conclusion

Implémentation propre, additive et rétro-compatible. Les deux points de vigilance signalés à la revue sont **sains** :
- **Dispose du controller du dialog** : correctement libéré dans `_ZSubItemEditDialogState.dispose()` — aucune fuite.
- **Gating ACL réel** : `acl.can(action, collectionId:)` par action en mode `hide`, `collectionId` transmis, `ZCrudAction` non étendu, `z_acl.dart` non modifié.

**Verdict : APPROVED.** Corrections requises : aucune. LOW-1/LOW-2 laissés à la discrétion (nits, non bloquants pour `done`).
