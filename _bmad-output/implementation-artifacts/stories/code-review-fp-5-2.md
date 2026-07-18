# Code-review — fp-5-2 (champs extras : PIN / autocomplete / table éditable)

Remédiation du 2026-07-18. Périmètre STRICT : `packages/zcrud_field_extras/` uniquement. Aucun autre package touché, API publique inchangée (kinds, `builder`, `registerZFieldExtrasFields` identiques).

## Findings × statut × preuve

| # | Sévérité | Finding | Statut | Preuve (rouge-avant → vert-après) |
|---|----------|---------|--------|-----------------------------------|
| MED-1 | MEDIUM (vrai bug) | Table : cellules `TextFormField(initialValue:, key stable)` non re-synchronisées sur ré-injection externe (`setValue`/reset d'une ligne existante silencieusement ignoré). | **CORRIGÉ** | Contrôleurs de cellule **gérés** (`Map<String,TextEditingController>` par `cell-<rowKey>-<col>`, `putIfAbsent`, jamais recréés au rebuild — SM-1), re-sync `didUpdateWidget` (positionnel, borné, n'écrit que si `text != slice`, préserve la sélection — mirroir PIN), élagage+dispose des orphelins en build, dispose global. Test porteur `ré-injection externe d'une cellule EXISTANTE re-synchronise l'affichage (MED-1)` : ROUGE avant (`Found 0 widgets with text "bar"`) → VERT après. |
| MED-2 | MEDIUM (test tautologique) | Test « valeur externe non-String ⇒ champ vide » n'assérait que `findsOneWidget` + `takeException isNull`, jamais que le champ est VIDE (repli AD-10). | **RENFORCÉ** | Test asserte désormais la **progression « 0 / 4 »** (via `ensureSemantics` + `bySemanticsLabel`), l'absence de « 2 / 4 », et `find.text('4'/'2')` findsNothing. Falsifiabilité **prouvée par mutation** `: ''` → `: v.toString()` du repli `_sliceValue` : le test rougit (`Found 0 widgets with a semantics label matching '0 / 4'`, filled=2). Mutation revert. Code produit inchangé (déjà correct). |
| MED-3 | MEDIUM (double annonce a11y) | Options autocomplete : `Semantics(button:true, label:option)` sans `excludeSemantics` + `Text(option)` enfant ⇒ deux nœuds / annonce « Apple Apple ». | **CORRIGÉ** | Ajout `excludeSemantics: true` sur le `Semantics` de l'option (le label du bouton suffit). Test porteur `options — label sémantique annoncé UNE seule fois (MED-3)` : ROUGE avant (`Found 0 widgets with a semantics label named "Apple"` — label combiné « Apple\nApple ») → VERT après (`findsOneWidget`). |
| LOW | LOW (même classe que MED-1) | Autocomplete : `Autocomplete(initialValue: ...)` one-shot ; ré-injection `ctx.value` post-montage non affichée alors que le doc-comment affirme « lit ctx.value ». | **CORRIGÉ (fix, pas bornage)** | Passage StatelessWidget→StatefulWidget avec `RawAutocomplete<String>` alimenté par un `TextEditingController`/`FocusNode` **détenus par l'état** (alloués 1× en `initState`, disposés), re-sync `didUpdateWidget` (mirroir PIN). Doc-comment mis à jour (plus honnête que le bornage). Test porteur `ré-injection externe ctx.value post-montage s'affiche (LOW)` : ROUGE avant (`Found 0 widgets with text "X"`) → VERT après (`findsOneWidget`). |

## Invariants préservés

- **AD-2 / SM-1** : aucun contrôleur recréé au rebuild (table : `putIfAbsent` + re-sync conditionnel ; autocomplete : `late final` en `initState`). Re-sync `didUpdateWidget` n'écrit que si `text != slice` — pas de fight avec la frappe, pas de perte de sélection.
- **AD-10** : replis défensifs inchangés (PIN non-`String` ⇒ vide, désormais asséré ; table `zParseTableRows`).
- **AD-13 / FR-26** : cibles ≥ 48 dp, variantes directionnelles, thème injecté — intacts. MED-3 améliore la sémantique (annonce unique).
- **AD-1 / CORE OUT=0** : `RawAutocomplete` est SDK Flutter (aucune nouvelle dép lourde ; `pinput` reste la seule). `graph_proof` ACYCLIQUE, CORE OUT=0.

## Vérif verte rejouée (RC réels, 2026-07-18)

- `flutter test packages/zcrud_field_extras` → **RC=0, 26 tests** (23 initiaux + 3 red-before, MED-2 renforcé in place).
- `dart analyze packages/zcrud_field_extras` → **RC=0** (« No issues found! »).
- `python3 scripts/dev/graph_proof.py` → **RC=0**, ACYCLIQUE OK, CORE OUT=0 OK.
- Mutation MED-2 (`: v.toString()`) → test renforcé ROUGE → revert appliqué et re-vérifié VERT.

## Triage

Tous les MEDIUM (MED-1, MED-2, MED-3) corrigés/renforcés ; le LOW corrigé par fix (préféré au bornage). Aucun finding reporté. Story reste **verte** après remédiation.
