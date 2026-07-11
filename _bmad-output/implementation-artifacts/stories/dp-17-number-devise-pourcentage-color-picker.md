# Story DP.17: Nombre devise/% + picker couleur enrichi (parité DODLP — M17 + M14)

Status: review

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want que le champ **nombre** honore réellement `ZNumberConfig.isCurrency/isPercentage` (formatage lecture + suffixe « % »/devise) et que le champ **couleur** offre un picker enrichi (roue/hex/opacité/récentes) via un **seam neutre injectable** ou un **picker built-in NEUTRE**,
so that les formulaires monétaires/pourcentages et le choix de couleur arbitraire DODLP migrent sans config morte ni régression, en gardant le cœur **neutre** (couleur = `int` ARGB, aucune dépendance picker tierce imposée — AD-1/FR-26).

Périmètre : **`zcrud_core` uniquement** (+ tests). Gaps : **M17** (`number` devise/%, `ZNumberConfig` jamais lu), **M14** (`color` picker riche). Réf : `docs/dodlp-edition-parity-gap.md` §2.5 (M14/M17), §3 MAJOR.

## Acceptance Criteria

### M17 — `number` devise / pourcentage

1. **AC1** — `ZNumberConfig` gagne un champ additif `currencySymbol` (`String?`, défaut `null`), **NEUTRE** (donnée, jamais un style — FR-26/AD-1). `==`/`hashCode` mis à jour ; rétro-compat `const` stricte. *(IMPLÉMENTÉ : `z_field_config.dart`.)*
2. **AC2** — `ZNumberFieldWidget` lit `ZNumberConfig` de `field.config` et affiche un **suffixe d'édition** : `%` si `isPercentage` (l10n `percentSuffix`), sinon le symbole `currencySymbol` (ou repli l10n `currencySuffix`) si `isCurrency`. Sans config ⇒ **aucun suffixe** (rétro-compat E3-3a). Le suffixe coexiste avec un `suffix`/`suffixIcon` déclaratif DP-12 (`InputDecoration.suffixText`). *(IMPLÉMENTÉ : `z_number_field_widget.dart` + `zFieldDecoration`/`ZcrudTheme.inputDecoration` gagnent `suffixText`.)*
3. **AC3** — Formatage **lecture** (`readMode`) : `zReadOnlyValueOf` rend « 42 % » / « 42 <symbole> » pour un `number/integer/float` porteur d'une `ZNumberConfig` monétaire/pourcentage ; sans config ⇒ `'$value'` (rétro-compat DP-13). *(IMPLÉMENTÉ : `z_read_only_value.dart`.)*
4. **AC4** — AD-2/SM-1 : le formatage est **statique** (hors chemin chaud de frappe), aucun contrôleur additionnel, aucune régression de rebuild ciblé.

### M14 — `color` picker enrichi (neutre)

5. **AC5** — `ZColorConfig` additif `const` (`enableAlpha`, `showPalette`, `showRecent`, `recentColors: List<int>`), pur-données neutre (parité `flex_color_picker`/`recentColors` DODLP). *(IMPLÉMENTÉ : `z_field_config.dart`.)*
6. **AC6** — Seam **injectable NEUTRE** `ZColorPicker` (`ZcrudScope.colorPicker`, défaut `null`) : le cœur ne dépend d'AUCUN package de picker (AD-1) ; un binding/app peut fournir une roue HSV tierce. *(IMPLÉMENTÉ : `z_color_field_widget.dart` + `zcrud_scope.dart`.)*
7. **AC7** — Repli **built-in NEUTRE** (`ZColorPickerDialog`, 100 % Flutter, zéro dép lourde) : sliders teinte/saturation/luminosité + opacité optionnelle (`enableAlpha`) + saisie **hex** défensive + ligne **couleurs récentes**. La palette historique (15 swatches dérivés) est **strictement préservée** et pilotée par `showPalette` (défaut `true`). *(IMPLÉMENTÉ.)*
8. **AC8** — Défensif (AD-10) : hex invalide **ignoré** (jamais de throw, aucune écriture avant Apply) ; seam qui throw ⇒ aucune écriture. La couleur reste une **donnée** ARGB (jamais un style codé en dur — FR-26 ; masques alpha exprimés par décalage `0xFF << 24`).
9. **AC9** — a11y (AD-13) : swatches/cibles ≥ 48 dp, `Semantics(label + selected)`, insets directionnels.

## Tests (implémentés, verts)

- `dp17_number_currency_percent_test.dart` (10 tests) : suffixe %/devise édition, repli l10n, sans-config, formatage lecture.
- `dp17_color_picker_test.dart` (6 tests) : palette préservée, seam injecté prioritaire, built-in hex→Apply, hex invalide défensif, couleurs récentes, `showPalette=false`.

## Vérif verte (rejouée sur disque)

`dart analyze packages/zcrud_core` RC=0 · `flutter test` RC=0 (857) · `graph_proof` CORE OUT=0 · `style_purity` vert.

## Seams / impls déférés

- Roue HSV/hex tierce (`flex_color_picker`) : **déférée binding** via `ZcrudScope.colorPicker` (AD-1) ; le cœur fournit un picker built-in neutre suffisant.
- Symbole monétaire exact (€/$/FCFA) : **fourni par l'app** via `currencySymbol` (jamais codé en dur — FR-26).
