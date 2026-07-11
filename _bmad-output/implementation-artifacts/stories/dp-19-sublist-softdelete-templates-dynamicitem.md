# Story DP.19: Sous-liste soft-delete/gabarits + item dynamique gabarits (parité DODLP — M18 + M19)

Status: review

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want que la **sous-liste** (`subItems`, mode compact DP-6) offre **soft-delete/restore** + **gabarits de création** (`popUpMenuOptions`) et que l'**item dynamique** (`dynamicItem`) offre `defaultNewItem`/`createNewText` + un **builder de champs dynamique** `subItemsFormFieldsBuilder(state)`,
so that les mini-CRUD imbriqués DODLP migrent fidèlement, **sans casser** DP-6 (compact/ACL/dialog) ni l'inline E3-3b-2.

Périmètre : **`zcrud_core` uniquement** (+ tests). Gaps : **M18** (`subItems` confirmation/soft-delete/restore/`popUpMenuOptions`), **M19** (`dynamicItem` gabarits). Réf : `docs/dodlp-edition-parity-gap.md` §2.4 (M18/M19), §3 MAJOR.

## Acceptance Criteria

### M18 — sous-liste (compact)

1. **AC1** — `ZSubListConfig` gagne `softDelete` (défaut `false`), `creationTemplates: List<ZSubListItemTemplate>` (défaut `[]`), `defaultNewItem: Map<String,Object?>` (défaut `{}`), `createNewTextKey: String?`. Nouvelle classe `const` `ZSubListItemTemplate {labelKey, defaults}`. `==`/`hashCode` (égalité profonde map/liste, AD-1). Rétro-compat `const` stricte. *(IMPLÉMENTÉ : `z_sub_list_config.dart`.)*
2. **AC2** — Confirmation de suppression : **déjà livrée** (DP-6/AC13) — conservée intacte.
3. **AC3** — `softDelete=true` : la suppression **marque l'item supprimé** (exclu de l'agrégation parent `onChanged`) **sans le retirer** ; ligne rendue barrée + badge `(deleted)` + action **restaurer** ; restaurer réintègre l'agrégation. `softDelete=false` (défaut) ⇒ suppression **définitive** (rétro-compat DP-6). *(IMPLÉMENTÉ : `z_sub_list_field_widget.dart`.)*
4. **AC4** — `creationTemplates` non vide ⇒ le bouton « ajouter » (compact) devient un **PopupMenu** de gabarits (parité `popUpMenuOptions`) ; chaque gabarit pré-remplit le dialog de création avec `defaults` (fusionnés par-dessus `defaultNewItem`, les `defaults` priment). Vide ⇒ bouton `+` simple (rétro-compat). *(IMPLÉMENTÉ.)*

### M19 — item dynamique (+ sous-liste)

5. **AC5** — `defaultNewItem` amorce le `ZFormController` d'un item créé (sous-liste inline/compact **et** `dynamicItem`). `createNewTextKey` personnalise le libellé du bouton de création (repli `addItem`). *(IMPLÉMENTÉ : les deux widgets.)*
6. **AC6** — `dynamicItem` : seam **présentation** `ZDynamicItemFieldsResolver` (`subItemsFormFieldsBuilder(state)`) calcule les sous-champs **à RENDRE** depuis l'état courant, **intersecté défensivement** avec `itemFields` (aucune tranche orpheline, SM-1) ; `null` (défaut) ⇒ tous les `itemFields` (rétro-compat). Résolveur défaillant ⇒ repli config (AD-10). *(IMPLÉMENTÉ : `z_dynamic_item_field_widget.dart`.)*
7. **AC7** — AD-2/SM-1 imbriqué préservé : le conteneur écoute un canal **structurel** (add/remove/restore/reseed) ; taper dans un sous-champ ne reconstruit que ce champ. AD-3/AD-14 : aucune closure dans le domaine (le seam de champs vit en présentation).

## Tests (implémentés, verts)

- `dp19_sub_list_dynamic_item_test.dart` (7 tests) : soft-delete/restore + exclusion agrégation, softDelete=false définitif, menu de gabarits + pré-remplissage, `defaultNewItem`/`createNewText` (inline + dynamicItem), `fieldsResolver` sous-ensemble + repli défensif.

## Vérif verte (rejouée sur disque)

`dart analyze packages/zcrud_core` RC=0 · `flutter test` RC=0 (857) · `graph_proof` CORE OUT=0 · non-régression DP-6 (`z_sub_list_compact_test.dart`) verte.

## Seams / impls déférés

- **Soft-delete de session** : les items supprimés sont conservés **en session** (restaurables) et exclus de l'agrégation ; la persistance `is_deleted` (soft-delete stockage, AD-9) relève de la couche données/app (hors champ d'édition).
- **`subItemsFormFieldsBuilder` live** : la ré-évaluation du résolveur est faite au build **structurel** du conteneur (add/clear/reseed) ; une ré-évaluation live sur frappe d'un champ pilote est **déférée** (préserve SM-1 — pas d'abonnement du conteneur aux valeurs des sous-champs).
