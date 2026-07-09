# Code-review — Story E2-8 : l10n, thème & RTL injectables

- **Skill** : `bmad-code-review` (invoqué via le tool `Skill`, chemin normal — pas de fallback disque).
- **Story** : `_bmad-output/implementation-artifacts/stories/e2-8-l10n-theme-rtl-injectables.md` (11 ACs, statut `review`).
- **Baseline** : `8f2875559aee498774eca8590744e816f8a5c93f`. NB : `packages/` est **untracked** vs baseline (le monorepo n'est pas encore committé) → revue sur le **contenu réel des fichiers sur disque** (File List de la story).
- **Mode** : full (spec + diff). Couches lancées : Blind Hunter + Edge Case Hunter + Acceptance Auditor (analyse consolidée).
- **Verdict** : ✅ **APPROVED** (0 HIGH, 0 MAJEUR, 0 MEDIUM ; 4 LOW de durcissement optionnel).

---

## Décision d'architecture — inflexion Material (à statuer, §Ambiguïté #1)

**STATUT : ACCEPTÉE — confinée et justifiée.**

- `package:flutter/material.dart` est importé **par un seul fichier** : `lib/src/presentation/theme/z_theme.dart` (grep transverse `packages/zcrud_core/lib` = 1 seul importeur, ligne 16). Aucune fuite dans le reste de `presentation/`, ni dans `l10n/`, ni dans `zcrud_scope.dart` (qui reste sur `widgets.dart`).
- **Justifié par FR-26** : `ThemeExtension<T>`, `Theme.of`, `ThemeData`, `ColorScheme` vivent dans `material.dart` — il n'existe pas de chemin material-free satisfaisant « le moteur hérite du `Theme.of(context)` » dans le cœur. Cohérent avec **AD-14** (`domain/` pur-Dart ; `zcrud_core` autorise Flutter côté présentation).
- **Confinement prouvé côté couches** : `grep package:flutter` sous `lib/src/domain` et `lib/src/data` = **0** (les deux restent strictement pur-Dart). `l10n/` reste sur `foundation.dart`/`widgets.dart` (l10n ≠ Material, correct).
- **Garde correctement recalibrée** : `presentation_purity_test.dart` whiteliste `foundation`/`widgets`/`material` UNIQUEMENT, et maintient interdits `dart:ui` (import direct), `cupertino.dart`, `services.dart`, tous les managers (`riverpod`/`get`/`provider`) et deps lourdes (firestore/firebase/hive/syncfusion/quill/maps). Approche whitelist ⇒ `rendering`/`painting`/`gestures`/`animation` seraient rejetés (bien).

**Conclusion** : la relaxation est bornée, mono-fichier, mandatée par FR-26 et conforme AD-14. Pas de finding.

---

## Résultats RÉELS rejoués sur disque

| Vérification | Commande | Résultat |
|---|---|---|
| Analyze | `melos run analyze` | **RC=0**, 14 pkgs « No issues found », `dart analyze → SUCCESS` |
| Tests zcrud_core | `flutter test` (pkg) | **RC=0 — 195 tests** (25 E2-8 + 170 non-régression E2-1..E2-7) |
| Tests globaux | `melos run test` | **RC=0 — melos exec → SUCCESS** (14 pkgs) |
| Verify | `melos run verify` | **RC=0** — `ACYCLIQUE OK`, `CORE OUT=0 OK`, gates melos/reflectable/secrets/codegen/compat **OK** |
| prove_gates | `dart run scripts/ci/prove_gates.dart` | **22 OK, 0 FAIL** |
| Parité bindings | `flutter test` get/riverpod/provider | **verts** (get +17, riverpod +8, provider +8) ; « 0 rebuild superflu, stabilité du resolver » |
| melos list | `melos list` | **14** |
| `.g.dart` suivis | `git ls-files '*.g.dart'` | **0** |

### Greps adversariaux (0 violation active)

| Grep | Cible | Résultat |
|---|---|---|
| `package:flutter/material.dart` | `zcrud_core/lib` | **1** (uniquement `theme/z_theme.dart`) |
| `cupertino.dart` / `services.dart` / `import 'dart:ui'` | `lib` | **0** |
| `WidgetRef` / `Get.find` / `Get.put` / `Provider.of` | `lib` | **0** |
| `lex_localizations` / `go_router` / `GoRouter` / `context.l10n` | `lib` + `pubspec.yaml` | **0** |
| `Color(0x` / `Colors.` / `Color.fromARGB` / `Color.fromRGBO` | `lib/src/presentation` | **0** |
| non-directionnel (`EdgeInsets.only`, `Alignment.*Left/Right`, `TextAlign.left/right`, `fromLTRB`, `Positioned(left`, `BorderRadius.only/horizontal`) | `lib/src/presentation` | **0** |
| `package:flutter` | `domain/` + `data/` | **0** |

---

## Couverture des ACs

| AC | Sujet | Statut |
|---|---|---|
| 1 | Frontière de pureté MAJ (material sous presentation/ ; domain/data pur ; CORE OUT=0) | ✅ (gardes + graph_proof rejoués) |
| 2 | Nommage `Z`/`Zcrud`, emplacement, barrel ordre alpha | ✅ (barrel L77-84 : l10n < theme < z_* ; analyze `directives_ordering` vert) |
| 3 | Delegate générique, 0 terme métier | ✅ (sentinelle 9 termes × 21 clés × en/fr) |
| 4 | Registre immuable, surcharge, isolation, 0 singleton mutable | ✅ (immuabilité + 2-scopes + == par contenu) |
| 5 | `ZcrudTheme` ThemeExtension, of() ordre scope>ext>fallback, copyWith/lerp | ✅ (3 cas montés) |
| 6 | Aucun style codé en dur (garde style) | ✅ (grep + test verts) |
| 7 | Directionnel uniquement + rendu RTL prouvé | ✅ (`EdgeInsetsDirectional.resolve(rtl/ltr)` + widget RTL/LTR) |
| 8 | 0 `lex_localizations`/`go_router` | ✅ |
| 9 | `ZcrudScope` étendu, non-régression E2-7, updateShouldNotify 4 seams | ✅ (parité bindings verte, identité `null` stable) |
| 10 | Barrel + non-régression E2-1..E2-7, melos=14, g.dart=0 | ✅ |
| 11 | Vérif verte finale | ✅ (voir tableau ci-dessus) |

---

## Findings (triage par sévérité)

### HIGH / MAJEUR — aucun
### MEDIUM — aucun

> Note adversariale : aucun style codé en dur ni usage non-directionnel **actif** n'échappe aux gardes (greps ci-dessus = 0). Les gaps ci-dessous sont de la **robustesse de garde** (aucune violation présente), donc LOW et non MEDIUM.

### LOW (durcissement optionnel)

**L-1 — `label()` court-circuite le repli `en` intégré de `ZcrudLocalizations.of`.**
`z_localizations.dart:146` — `label()` utilise `ZcrudLocalizations.maybeOf(context)?.maybeResolve(key)` ; si le delegate **n'est pas monté**, `maybeOf` → `null` et `label()` retourne `fallback ?? key` (donc `'save'` brut, pas `'Save'`). Or `ZcrudLocalizations.of` (L105-106) est explicitement conçu pour retomber sur la table `en` intégrée « garantit un rendu sans crash ». La composition décrite en Dev Notes/AC4 énonce `… → ZcrudLocalizations.of(context).resolve(key) → key`. Écart mineur (dégradé, pas de crash ; le delegate est normalement monté — non couvert par test). Envisager d'utiliser `of()` plutôt que `maybeOf()` dans `label()` pour honorer le repli `en`, OU documenter que `label()` renvoie la clé sans delegate.

**L-2 — La garde couleur ne couvre pas `Color.fromARGB`/`Color.fromRGBO`.**
`style_purity_test.dart:21-27` — `_colorPatterns` attrape `Color(0x…`, `Colors.`, `0x[fF]{6,8}`, `kNavyColor`, `kFormInputDecorationTheme`, mais **pas** un littéral `Color.fromARGB(255, …)`/`Color.fromRGBO(…)`. Aucune occurrence aujourd'hui (grep = 0), mais un futur codage en dur ARGB passerait la garde. Ajouter `Color\.fromARGB\(` / `Color\.fromRGBO\(` aux motifs.

**L-3 — La garde directionnelle est ligne-locale et incomplète.**
`style_purity_test.dart:30-35` — `EdgeInsets\.only\([^)]*\b(left|right)` et `Positioned\([^)]*` ne matchent que si les arguments sont sur **la même ligne** ; un `EdgeInsets.only(\n  left: 8,\n)` multi-ligne échappe (scan `readAsLinesSync`). De plus `EdgeInsets.fromLTRB(...)` (non-directionnel L/R), `BorderRadius.only(...)`/`BorderRadius.horizontal` (non-directionnels) ne sont pas couverts. Aucune occurrence active (grep = 0). Durcir : scan multi-ligne (joindre le corps) et ajouter `fromLTRB`/`BorderRadius.only`/`.horizontal`.

**L-4 — La sentinelle anti-terme-métier itère une liste de clés en dur, pas la table réelle du delegate.**
`z_localizations_test.dart:58-61` — le scan parcourt une liste **codée en dur** de 21 clés au lieu de refléter les entrées réelles de `_tables`/`supportedLocales`. Une future clé à terme métier (ex. `douaneLabel`) ajoutée à `_enLabels` échapperait à la sentinelle si absente de la liste du test. Scanner directement `loc` sur toutes ses entrées (exposer les clés) plutôt qu'une liste dupliquée.

---

## Trous de couverture (non bloquants)

- `label()` **sans delegate monté** (chemin dégradé L-1) non testé — tous les tests montent le delegate.
- Injection du **thème via un binding** (get/riverpod/provider) non testée ici — hors périmètre (→ E2-9) ; la parité bindings reste verte.
- RTL prouvé sur un **widget de référence** minimal, pas sur un vrai `ZFieldWidget` (`Semantics`/≥48 dp) — hors périmètre (→ E3-3a/E3-3b), conforme à l'anti-empiètement de la story.
- `ZcrudLocalizations.of` retombant sur `en` sans delegate — comportement défini mais non couvert par un test dédié.

---

## Conclusion

Story E2-8 **APPROVED**. Les 11 ACs sont satisfaits, toutes les vérifs vertes rejouées réellement sur disque (analyze RC=0, 195 tests zcrud_core, `melos test`/`verify` RC=0, `prove_gates` 22/0, parité ×3 verte, `CORE OUT=0 OK`, `ACYCLIQUE OK`, melos=14, g.dart=0). L'**inflexion Material est confinée à `theme/z_theme.dart`, justifiée par FR-26 et conforme AD-14**. Les 4 findings sont **LOW** (durcissement de gardes / cohérence de repli) sans violation active — corrigeables opportunément, non bloquants pour `done`.
