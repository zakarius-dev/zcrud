# Code-review — Story `fp-1-1` (seams + types cœur MVP)

Périmètre : `packages/zcrud_core` uniquement. Code de PRODUCTION jugé correct (0 bug de
correctness) — findings = **tests porteurs** à renforcer (falsifiabilité R3) + **1 dartdoc**.

## Findings × sévérité × statut × preuve de falsifiabilité

| # | Sévérité | Finding | Statut | Test / dartdoc | Injection sous laquelle il ROUGIT (rejouée) |
|---|----------|---------|--------|----------------|---------------------------------------------|
| MED-1 | MEDIUM | Chemin picker→setValue (AC-A4) jamais exercé — `OutlinedButton` jamais tapé, `onChanged` (z_field_widget.dart:473) jamais couvert | **corrigé** | `test/presentation/edition/z_date_range_field_widget_test.dart` — nouveau test `AC-A4 : tap ouvre le picker ; le câblage picker→onChanged écrit un ZDateRange dans la tranche` : tap `OutlinedButton` → `showDateRangePicker` ouvert (`find.text('Save')`) → invoque la **fermeture réelle** montée par le dispatcher (`ZDateRangeFieldWidget.onChanged`, càd z_field_widget.dart:473) avec une plage → `expect(valueOf('p'), isA<ZDateRange>())` + égalité | `z_field_widget.dart:473` → `onChanged: (range) => <void>{}` ⇒ **RED** (la tranche reste `null`). Rejoué : `+0 -1`. |
| MED-3 | MEDIUM | Test « DynamicEdition consomme formPadding » tautologique (assied `all(12)` = défaut, ne distingue pas token vs littéral) | **corrigé** | `test/presentation/edition/aeration_tokens_test.dart` — test monte `ZcrudScope(theme: ZcrudTheme(formPadding: EdgeInsetsDirectional.all(29)))` (valeur NON-défaut) et asserte `list.padding == all(29)` | `dynamic_edition.dart:576` → `widget.padding ?? const EdgeInsetsDirectional.all(12)` (token sévré) ⇒ padding retombe sur `all(12)` ≠ `all(29)` ⇒ **RED**. Rejoué : `+0 -1`. |
| MED-4 | MEDIUM | Éviction du natif non vérifiée pour `relation` (asymétrie avec `select`) | **corrigé** | `test/presentation/edition/z_select_presenter_test.dart` — bloc relation : ajout `expect(find.byType(DropdownButtonFormField<Object?>), findsNothing)` | `z_relation_field_widget.dart:169` : retrait du `return` → double rendu presenter+natif (Column) ⇒ le dropdown natif réapparaît ⇒ **RED**. Rejoué : `+0 -1`. |
| LOW-5 | LOW | SM-1 unilatéral : le champ frappé jamais prouvé reconstruit (seul le voisin est pincé) | **corrigé** | `test/presentation/edition/z_date_range_field_widget_test.dart` — capture `tBefore = builds['t']!` avant `enterText` puis `expect(builds['t']!, greaterThan(tBefore))` (pince les DEUX côtés) | `z_form_controller.dart:setValue` → propagation morte (retrait de `_slice(name).value = value`) ⇒ `builds['t']` ne croît pas ⇒ **RED** (ligne 204). Rejoué : `+0 -1`. |
| LOW-2 | LOW | Dartdoc sur-affirme le format l10n (« sans format codé en dur ») alors que `_formatRange` émet un ISO littéral (choix délibéré cohérent avec la famille date sœur, AC-A2) | **corrigé** | `lib/src/presentation/edition/families/z_date_range_field_widget.dart` (dartdoc de `_formatRange`) — prose atténuée : format ISO-8601 **délibéré assumé**, cohérent `z_date_field_widget.dart`, PAS localisé ; ne reste affirmée que l'absence de **couleur** codée en dur. **Comportement inchangé.** | N/A (correction de prose — pas de comportement, ne change pas le graphe). |

## Triage

- **HIGH / MAJEUR** : aucun.
- **MEDIUM** (MED-1, MED-3, MED-4) : **tous corrigés** dans le périmètre de la story, sans régression.
- **LOW** (LOW-5, LOW-2) : corrigés (triviaux).

Aucun finding reporté.

## Vérif verte rejouée (réelle, sur disque, après corrections et reverts d'injection)

- `flutter test packages/zcrud_core` → **+987 All tests passed**, RC=0 (baseline 986 ; +1 test net MED-1 ; MED-3/MED-4/LOW-5 renforcés en place).
- `dart test` (CWD `packages/zcrud_generator`) → **+117 All tests passed**, RC=0.
- `dart analyze packages/zcrud_core` → RC=0 (2 infos `deprecated_member_use` PRÉ-EXISTANTES dans `z_batch_action_test.dart`, hors périmètre).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK**, RC=0 (le dartdoc ne change pas le graphe).

## Fichiers modifiés (tous sous `packages/zcrud_core/`)

- `test/presentation/edition/z_date_range_field_widget_test.dart` (MED-1 nouveau test + LOW-5 renforcé)
- `test/presentation/edition/aeration_tokens_test.dart` (MED-3 renforcé, token NON-défaut all(29))
- `test/presentation/edition/z_select_presenter_test.dart` (MED-4 éviction natif relation)
- `lib/src/presentation/edition/families/z_date_range_field_widget.dart` (LOW-2 dartdoc)
