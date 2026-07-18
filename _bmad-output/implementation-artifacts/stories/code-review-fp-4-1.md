# Code-review — fp-4-1 (Sélections riches `awesome_select`)

Périmètre remédié : `packages/zcrud_select/` (+ lecture du fork `packages/awesome_select/`).
Aucun autre package touché (fp-5-1 / fp-4-2 en review ailleurs).

## Vérif verte (rejouée réellement sur disque)

| Vérif | Commande | Résultat |
|---|---|---|
| Tests | `flutter test packages/zcrud_select` | **RC=0 — 29/29** (9 confinement + 20 présentateur/porteurs) |
| Analyse | `dart analyze packages/zcrud_select` | **RC=0** (1 `info` `containsSemantics` deprecation, pré-existant côté test) |
| Graphe | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK**, **CORE OUT=0 OK** |

## Findings × statut × preuve

| # | Sévérité | Finding | Statut | Preuve |
|---|---|---|---|---|
| MAJ-1 | MAJEUR | « Reflet EXTERNE de la tranche non reflété » (déclencheur figé sur l'ancienne valeur) | **RÉFUTÉ (R3)** — aucun correctif de prod | Le fork re-résout `selectedValue` via `didUpdateWidget` ⇒ AD-2 tenu. Verrouillé par le test FIX-3 (voir ci-dessous) qui PASSE avec le code de prod inchangé. |
| MED-1 | MEDIUM (FR-26) | Placeholder ANGLAIS codé en dur du fork (`'Select one'` / `'Select one or more'`, `state/selected.dart:200/319`) visible à l'état vide — le présentateur ne passait aucun `placeholder:` localisé | **CORRIGÉ** | `z_smart_select_presenter.dart` : `placeholder = label(context, 'select')` (clé l10n existante, `Select`/`Sélectionner`) passé à `SmartSelect.single/.multiple` ET employé dans le déclencheur (`valueText = …isResolved/isNotEmpty ? … : placeholder`). Test porteur ROUGISSAIT avant : contre le code original (sans `placeholder:`), `find.text('Select one') findsNothing` échouait (`Found 1 widget with text "Select one"`). Vert après fix. |
| MED-2 | MEDIUM (la prose ment) | `README.md:3-9` : « État : squelette de substrat (fp-1-2) », « le présentateur … sera écrit en fp-4-1 » (FUTUR), variantes `page`/`dialog`/`chips` non implémentées | **CORRIGÉ** | README réécrit : présentateur LIVRÉ, modes réels (bottom-sheet + radios/checkboxes, recherche, placeholder l10n, a11y/RTL) ; note explicite que `page`/`dialog`/`chips` NE sont PAS exposées. |
| FIX-3 | test-gap (ex-MAJ-1) | Le reflet externe fonctionne mais AUCUN test permanent ne le verrouille | **CORRIGÉ (test)** | Nouveau test AD-2 : `pumpWidget(value:'a')` → `find.text('Alpha') findsOneWidget` ; re-`pumpWidget(value:'c')` + `pumpAndSettle` → `find.text('Charlie') findsOneWidget`, `find.text('Alpha') findsNothing`. PASSE avec la prod inchangée (protège la parité réactive). |
| LOW-3 | LOW | Garde volet 4 : `_exportedShownIds` prenait `.last` ⇒ `show S2Choice as ZFoo` enregistré sous `ZFoo`, échappant à `_isS2Leak` | **CORRIGÉ** | `.split(RegExp(r'\s+')).first` (identifiant SOURCE avant `as`). Contre-preuve R12 ajoutée : `show S2Choice as ZFoo` ⇒ `_isS2Leak` == `{S2Choice}` (rougit). Le barrel légitime (`show ZSmartSelectPresenter`) reste vert. |

### Triage

- **MAJEUR** : 1 réfuté (R3), verrouillé par un test permanent (FIX-3).
- **MEDIUM** : 2 corrigés (MED-1 code+test, MED-2 doc).
- **LOW** : 1 corrigé (LOW-3 durcissement de garde + contre-preuve).
- Aucun finding reporté.

## Notes

- MED-1 : la clé l10n `select` existe déjà (`z_localizations.dart` en/fr) — aucun
  littéral introduit ; réutilisation conforme à l'esprit `selectDate`/`selectDateRange`.
- Le `placeholder:` passé à `SmartSelect` suffit à lui seul (le fork le câble dans
  `state.selected.toString()`) ; l'override au niveau du déclencheur est une ceinture
  supplémentaire garantissant l'absence du littéral fork quel que soit le chemin de rendu.
- Confinement AD-40/AD-49 inchangé : aucun type `SmartSelect`/`S2*` au barrel
  (volet 4 vert, R12 renforcé).
