---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.8 : l10n, thème & RTL injectables (`ZcrudLocalizations` / `ZcrudLabels` / `ZcrudTheme`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du cœur `zcrud_core`**,
je veux **poser les seams CONCRETS de localisation et de thème du chrome CRUD — un `LocalizationsDelegate` générique (`ZcrudLocalizations`) qui ne porte AUCUNE ressource métier, un registre de libellés immuable et injectable (`ZcrudLabels`, sans singleton statique mutable), et un `ZcrudTheme` (`ThemeExtension`) résolu via `ZcrudScope` avec repli sur `Theme.of(context)` — le tout SANS aucun style codé en dur, en variantes directionnelles (RTL) exclusivement, et SANS aucune dépendance à `lex_localizations`/`go_router`**,
afin que **le moteur `DynamicEdition` (E3) et la liste (E4) rendent des libellés surchargés par l'app et un thème injecté par l'app hôte (FR-23, FR-26), soient RTL-safe et accessibles (AD-13), et que ces seams se branchent sur le `ZcrudScope` (AD-6/AD-15) posé en E2-7 — sans jamais coupler le cœur à la l10n/routing d'une app particulière.**

## Contexte & valeur — FR-23 + FR-26 + AD-13

**E2-7 a posé le PATTERN de seam** (`ZcrudScope` InheritedWidget, `ZDependencyResolver` throwing, `ZScopeError`, réutilisation de `ZAcl`/`ZAllowAllAcl`). E2-7 a explicitement **différé à E2-8** les seams l10n/thème concrets (cf. e2-7 §Périmètre : « ❌ PAS de seam l10n/libellés ni de seam thème `ZcrudTheme`/`ThemeExtension` concret (→ E2-8) »). **Cette story matérialise ces deux seams** et branche leur résolution sur `ZcrudScope`.

**FR-23 (l10n injectable + RTL/a11y)** — conséquences testables (PRD §4.9) :
- Le delegate l10n générique **n'énumère PAS de ressource métier** ; les libellés métier sont fournis par l'app/feature via un **registre**.
- **Pas de singleton statique mutable** de localisation ; accès via `of(context)`/scope.
- Widgets `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`, `Semantics` explicites, cibles ≥ 48 dp.

**FR-26 (thème & design-tokens injectables)** — conséquences testables (PRD §4.9) :
- Le style (couleurs, décorations d'input, rayons) est fourni via un **`ZcrudTheme`/`ThemeExtension` injecté par `ZcrudScope`** ; **AUCUN** style codé en dur dans le package (pas de `kNavyColor`/`kFormInputDecorationTheme`).
- En l'absence de thème fourni, le moteur **hérite du `Theme.of(context)`** de l'app (aucune couleur en dur). Gouverné par AD-6, AD-13.

**AD-13 (RTL/a11y/l10n injectable sur toute surface UI)** — règle : widgets `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`PositionedDirectional` ; `Semantics` explicites, cibles ≥ 48 dp ; **l10n via delegate générique + registre de libellés (pas de singleton statique mutable)** ; **zéro dépendance** de zcrud à `lex_localizations`/`go_router`.

**Ce qui débloque :** E3-3a/E3-3b (widgets de champ : `Semantics`, ≥48 dp, insets directionnels — consomment `ZcrudLocalizations`/`ZcrudTheme`), E4 (liste), E7-1 (binding `zcrud_get` : « l10n branché »), E8-2 (rich forms lex_douane : RTL/a11y sans régression, SM-3). E2-8 fournit la **plomberie** l10n/thème ; les widgets concrets qui la consomment arrivent en E3.

**Ce qui rendra la story vérifiable :** (1) `ZcrudLocalizationsDelegate` charge des libellés **génériques** (boutons/validations/états) pour une locale, sans terme métier ; (2) un `ZcrudLabels` injecté via `ZcrudScope` **surcharge** un libellé sans aucun état statique mutable ; (3) `ZcrudTheme.of(context)` retourne le thème injecté dans le scope, sinon l'extension du `Theme.of`, sinon un repli **dérivé** de `Theme.of(context)` (zéro couleur en dur) ; (4) un **test/grep de pureté de style** prouve « aucun style codé en dur » et « variantes directionnelles uniquement » ; (5) un **grep** prouve **0** `lex_localizations`/`go_router` ; (6) un **widget test sous `Directionality.rtl`** prouve le rendu RTL d'un widget de référence consommant libellé + thème.

## ⚠️ INFLEXION CADRÉE — `presentation/` acquiert `package:flutter/material.dart`

E2-7 a **volontairement** interdit `flutter/material.dart` sous `presentation/` (garde `presentation_purity_test.dart`), avec le marqueur explicite « (E2-7) » — c.-à-d. « interdit *pour l'instant*, décision Material différée ». **E2-8 est le point où Material entre légitimement dans le cœur**, parce que :
- **`ThemeExtension<T>`** (mécanisme FR-26 « `ZcrudTheme`/`ThemeExtension` ») est déclaré dans `package:flutter/material.dart`.
- **`Theme.of(context)`** (repli FR-26 « hérite du `Theme.of(context)` ») est déclaré dans `package:flutter/material.dart`.

Sans Material, FR-26 (ThemeExtension + repli `Theme.of`) est **inatteignable** dans le cœur. La story **relâche donc la garde `presentation/` pour autoriser `package:flutter/material.dart`** (AC1). Restent interdits sous `presentation/` : `flutter/cupertino.dart` (Material par défaut, AD-8), `flutter/services.dart`, tout gestionnaire d'état, toute dep lourde, `dart:ui` en import direct. La couche `domain/` reste **STRICTEMENT pur-Dart** (garde inchangée). Cette relaxation est une **décision d'architecture à valider explicitement en code-review** (voir §Ambiguïtés).

> **l10n ≠ Material** : `Localizations`, `LocalizationsDelegate`, `Locale` vivent dans `package:flutter/widgets.dart` (déjà autorisé). **`flutter_localizations` n'est PAS requis** (delegate custom générique). Seul le seam **thème** exige Material.

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ **`ZcrudLocalizations`** (couche `presentation/l10n`) : porteur immuable des **libellés génériques du chrome CRUD** (boutons : enregistrer/annuler/supprimer/éditer/ajouter/confirmer/rechercher ; validations : champ requis/valeur invalide ; états : chargement/vide/réessayer ; oui/non/sélectionner…). **AUCUN** libellé métier (pas de nom d'entité douanière/étude/flashcard). `resolve(String key)` + accès `static ZcrudLocalizations of(BuildContext)` via `Localizations.of<ZcrudLocalizations>(context, ZcrudLocalizations)`.
- ✅ **`ZcrudLocalizationsDelegate extends LocalizationsDelegate<ZcrudLocalizations>`** : delegate **générique** ; `isSupported(locale)` (baseline `en` + `fr` au minimum, extensible) ; `load(locale)` → `ZcrudLocalizations` de la locale (tables `en`/`fr` intégrées **génériques**) ; `shouldReload` = false. **Aucune ressource métier énumérée.**
- ✅ **`ZcrudLabels`** (couche `presentation/l10n`) : **registre de libellés IMMUABLE et injectable** (`Map<String,String>` non modifiable, constructeur `const`-compatible). Surface : `String? maybeResolve(String key)` / `String resolve(String key, {String fallback})`. **PAS de champ statique mutable** ni de setter global — c'est une instance passée à `ZcrudScope`. Sert (a) à **surcharger** un libellé générique, (b) à fournir des **libellés métier par clé** côté app/feature.
- ✅ **Composition de résolution** : un helper documenté résout une clé dans l'ordre **`ZcrudScope.maybeOf(context)?.labels?.maybeResolve(key)` → `ZcrudLocalizations.of(context).resolve(key)` → `key`** (jamais de crash sur clé absente). Décision de forme (méthode statique vs extension sur `BuildContext`) laissée au dev, documentée.
- ✅ **`ZcrudTheme extends ThemeExtension<ZcrudTheme>`** (couche `presentation/theme`) : **design-tokens** sémantiques — couleurs sémantiques (bordure de champ, erreur, libellé, surface), **espacements** (échelle `gap*`), **rayons**, décoration d'input abstraite — exprimés en types `widgets`/`material` (jamais de hex métier). `copyWith` + `lerp` (contrat `ThemeExtension`). Repli `ZcrudTheme.fallback(ThemeData)` **dérivé** de `ColorScheme`/`TextTheme` (AUCUNE couleur en dur). `static ZcrudTheme of(BuildContext)` : `scope.theme ?? Theme.of(context).extension<ZcrudTheme>() ?? ZcrudTheme.fallback(Theme.of(context))`.
- ✅ **Extension de `ZcrudScope`** (UPDATE `zcrud_scope.dart`) : le bundle immuable gagne `ZcrudLabels? labels` et `ZcrudTheme? theme` (tous deux **optionnels**, défaut `null` → chemin zéro-config préservé) ; `updateShouldNotify` prend en compte leur identité ; `of`/`maybeOf`/`resolver`/`acl` (E2-7) **inchangés**.
- ✅ **Helpers directionnels / RTL** : les insets de `ZcrudTheme` sont des `EdgeInsetsDirectional` ; a minima un widget de référence + son test sous `Directionality(textDirection: TextDirection.rtl)`. (Les `ZFieldWidget` concrets `Semantics`/≥48 dp = **E3-3a/E3-3b**, pas ici.)
- ✅ **Garde de pureté ÉTENDUE** (UPDATE `presentation_purity_test.dart` + NEW garde de style) : autoriser `flutter/material.dart` sous `presentation/` ; NOUVELLE garde « aucun style codé en dur » (0 littéral couleur `Color(0x…)`/`Colors.`/`0xFF…` hors repli dérivé) + « directionnel uniquement » (0 `EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`, `TextAlign.left/right`, `Positioned(left/right`) + « 0 `lex_localizations`/`go_router` ».
- ✅ **Barrel** : exporter `ZcrudLocalizations`, `ZcrudLocalizationsDelegate`, `ZcrudLabels`, `ZcrudTheme` (ordre alpha, `directives_ordering`).
- ❌ **PAS** de `ZFieldWidget` concret par type ni dispatcher (→ **E3-3a/E3-3b** : `Semantics`, cibles ≥48 dp par widget).
- ❌ **PAS** de `flutter_localizations` (delegate custom générique suffit ; `Localizations`/`LocalizationsDelegate` sont dans `widgets.dart`).
- ❌ **PAS** de tables de traduction exhaustives multi-locales (baseline `en`+`fr` générique ; l'app étend via `ZcrudLabels`/son propre delegate).
- ❌ **PAS** de binding manager (`zcrud_riverpod`/`zcrud_get`/`zcrud_provider` → **E2-9**) ; E2-8 ne touche qu'au cœur + `ZcrudScope`.
- ❌ **PAS** de `flutter/cupertino.dart`, `flutter/services.dart`, `dart:ui` en import direct, ni gestionnaire d'état, ni dep lourde, sous `presentation/`.
- ❌ **NE PAS** affaiblir la garde `domain/` (reste strict pur-Dart) ; **NE PAS** ajouter de `zcrud_*`/manager/backend au pubspec (`CORE OUT=0` préservé). **NE PAS** toucher `sprint-status.yaml` (orchestrateur). **NE PAS** committer de `*.g.dart`.

## Acceptance Criteria

1. **Frontière de pureté MISE À JOUR — Material autorisé sous `presentation/` UNIQUEMENT (AD-14, AD-15, AD-1).**
   - **`lib/src/domain/**` (et `lib/src/data/**`) reste STRICTEMENT pur-Dart** : garde `domain_purity_test.dart` **inchangée et verte** (0 `package:flutter/*`, `dart:ui`, backend, manager ; seul externe `package:dartz`).
   - **`presentation/` autorise désormais** `package:flutter/foundation.dart`, `package:flutter/widgets.dart` **et `package:flutter/material.dart`** (+ internes `package:zcrud_core/...`/relatifs + `dartz`). **INTERDITS maintenus sous `presentation/`** : `flutter/cupertino.dart`, `flutter/services.dart`, `dart:ui` (import direct), tout gestionnaire d'état (`flutter_riverpod`/`riverpod`/`get`/`provider`), toute dep lourde (`cloud_firestore`/`firebase`/`hive`/`syncfusion`/`flutter_quill`/`google_maps`).
   - **Transverse à TOUT `zcrud_core/lib`** : **0** occurrence textuelle (hors commentaires) de `WidgetRef`, `Get.find`, `Get.put`, `Provider.of` (AD-6), **et 0** de `lex_localizations`, `go_router`, `GoRouter` (AD-13, AC8).
   - `pubspec.yaml` n'ajoute **aucun** `zcrud_*`/manager/backend/`flutter_localizations` ; `graph_proof.py` : `CORE OUT=0 OK` + `ACYCLIQUE OK` (Material est SDK, aucune arête `zcrud_*`).

2. **Nommage 100 % préfixé `Z` + emplacement `presentation`.** Types publics introduits : `ZcrudLocalizations`, `ZcrudLocalizationsDelegate`, `ZcrudLabels`, `ZcrudTheme` (et helper de résolution s'il est public). Ils vivent sous `packages/zcrud_core/lib/src/presentation/l10n/` et `.../presentation/theme/` ; l'API publique passe **uniquement** par le barrel `lib/zcrud_core.dart` (exports en ordre alphabétique, `directives_ordering`). Aucun type public non préfixé `Z`/`Zcrud`.

3. **Delegate l10n générique — AUCUNE ressource métier (FR-23, AD-13).**
   - `ZcrudLocalizationsDelegate extends LocalizationsDelegate<ZcrudLocalizations>`. `isSupported(Locale('fr'))` et `isSupported(Locale('en'))` = `true` ; `shouldReload(old)` = `false`.
   - `delegate.load(Locale('fr'))` retourne un `ZcrudLocalizations` dont les libellés **génériques** (`save`/`cancel`/`delete`/`required`/`invalidValue`/`loading`/`empty`…) sont des chaînes FR **non vides** ; idem `en` en anglais.
   - **Zéro terme métier** : un test scanne les valeurs/keys du delegate et échoue si un libellé métier interdit apparaît (liste sentinelle : ex. `douane`/`étude`/`flashcard`/`mindmap`/nom d'entité applicative). Les clés sont **génériques** (verbes/états d'UI CRUD).

4. **Registre de libellés injectable, surchargeable, SANS singleton statique mutable (FR-23, AD-13).**
   - `ZcrudLabels` est **immuable** : constructeur `const`-compatible, map interne **non modifiable** (`Map.unmodifiable` ou `const`) ; **aucun** champ `static` mutable ni setter global (grep : 0 `static ... = <mutable>` de libellés ; pas de variable de librairie mutable).
   - App/feature construit `ZcrudLabels({'save': 'Valider', 'myBusinessKey': '…'})` et l'injecte via `ZcrudScope(labels: …)`. Résolution : `label(context, 'save')` retourne **la surcharge** injectée quand elle existe, sinon le libellé générique du delegate, sinon la clé (jamais de crash).
   - **Isolation (preuve d'absence d'état global)** : deux `ZcrudScope` distincts avec deux `ZcrudLabels` différents dans deux sous-arbres résolvent **indépendamment** la même clé (aucune contamination croisée).

5. **`ZcrudTheme` (ThemeExtension) résolu via `ZcrudScope`, repli `Theme.of` (FR-26, AD-6).**
   - `ZcrudTheme extends ThemeExtension<ZcrudTheme>` avec `copyWith(...)` et `lerp(other, t)` conformes (round-trip `copyWith` identité ; `lerp(a,b,0)==a` en tokens clés).
   - `ZcrudTheme.of(context)` applique l'ordre : (a) `ZcrudScope.maybeOf(context)?.theme` si fourni ; sinon (b) `Theme.of(context).extension<ZcrudTheme>()` si présent ; sinon (c) `ZcrudTheme.fallback(Theme.of(context))`.
   - **Tests** : (a) `ZcrudScope(theme: custom)` ⇒ `of()` retourne `custom` ; (b) pas de scope-theme mais `ThemeData(extensions:[ext])` ⇒ `of()` retourne `ext` ; (c) ni l'un ni l'autre ⇒ `of()` retourne un repli dont **tous** les tokens couleur sont **dérivés** du `ColorScheme` courant (change avec `ThemeData.light()` vs `.dark()`), **aucune** valeur hex constante.

6. **AUCUN style codé en dur — prouvé par grep/lint (FR-26, NON-NÉGOCIABLE).** Un test de pureté de style scanne `lib/src/presentation/**` et **échoue** sur tout littéral de couleur (`Color(0x…)`, `Colors.<x>`, littéral hexadécimal `0x[fF]{2}…` utilisé comme couleur) **hors** le repli `ZcrudTheme.fallback` (qui ne fait que **lire/dériver** `ColorScheme`/`TextTheme`, sans littéral). **Interdits explicites** (FR-26) : toute constante de style type `kNavyColor`/`kFormInputDecorationTheme`. Les **tokens d'espacement/rayon** (échelle `gap*`/`radius*`) sont des `const` nommés **dans `ZcrudTheme`** (ils SONT la source de tokens injectable) et sont exemptés de la garde couleur.

7. **RTL — variantes directionnelles UNIQUEMENT + rendu RTL prouvé (AD-13).**
   - Garde directionnelle sur `lib/src/presentation/**` : **0** `EdgeInsets.only(` avec `left:`/`right:`, **0** `Alignment.centerLeft`/`Alignment.centerRight`/`Alignment.topLeft`/`…Right`, **0** `TextAlign.left`/`TextAlign.right`, **0** `Positioned(` avec `left:`/`right:`. Les insets de `ZcrudTheme` sont des `EdgeInsetsDirectional`.
   - **Widget test RTL** : un widget de référence minimal (consommant `ZcrudLocalizations` **et** `ZcrudTheme.of`) monté sous `Directionality(textDirection: TextDirection.rtl)` **rend sans exception** ; un `EdgeInsetsDirectional.only(start: X)` produit un padding **à droite** en RTL (résolution `.resolve(TextDirection.rtl)` vérifiée) ; le même sous `TextDirection.ltr` produit un padding **à gauche**.

8. **Zéro dépendance `lex_localizations`/`go_router` (AD-13, FR-23).** Ni `lib/**` ni `pubspec.yaml` ne référencent/déclarent `lex_localizations`, `go_router`. Grep = 0 pour les tokens `lex_localizations`, `go_router`, `GoRouter`, `context.l10n` (l10n app-spécifique). L'accès l10n passe **exclusivement** par `ZcrudLocalizations`/`ZcrudLabels`/`ZcrudScope`.

9. **`ZcrudScope` étendu proprement — non-régression E2-7 (AD-6, AD-15).**
   - `ZcrudScope` porte désormais `ZcrudLabels? labels` et `ZcrudTheme? theme` (optionnels, défaut `null`) **en plus** de `resolver`/`acl` (E2-7, inchangés). Le constructeur **zéro-config** reste valide (aucun manager, `labels`/`theme` non requis).
   - `updateShouldNotify(old)` renvoie `true` **ssi** un élément du bundle change (identité de `resolver`/`acl`/`labels`/`theme`), pas à chaque rebuild.
   - `of`/`maybeOf` et les 12 tests `zcrud_scope_test.dart` (E2-7) restent **verts** ; les seams `resolver`/`acl` ne sont ni déplacés ni affaiblis.

10. **Barrel & non-régression E2-1..E2-7.** Le barrel `lib/zcrud_core.dart` exporte les 4 nouveaux types (ordre alpha) et **conserve** tous les exports E2-1..E2-7 (contrats, ports, registres, extension, presentation E2-7, `ZCoreApi`, re-export curaté dartz). Les tests E2-1..E2-7 restent **verts** (sous `flutter test`). `melos list` = **14** ; `git ls-files '*.g.dart'` = **0**.

11. **Vérif verte finale (rejouée réellement sur disque).** `dart run melos run generate` OK (no-op, 0 modèle annoté) → `dart run melos run analyze` RC=0 (0 warning) → **`flutter test` sur `zcrud_core` RC=0** (nouveaux tests l10n/thème/RTL/pureté verts + non-régression E2-*) → `dart run melos run test` RC=0 global → `dart run melos run verify` RC=0 (`graph_proof` `CORE OUT=0 OK`/`ACYCLIQUE OK`, gates reflectable/secrets/codegen/melos/compat OK) ; `prove_gates.dart` 0 FAIL. Greps de pureté (style/directionnel/l10n-app/tokens managers) = **0** violation.

## Tasks / Subtasks

- [x] **Tâche 1 — `ZcrudLabels` : registre immuable injectable (AC: 2, 4)**
  - [x] `lib/src/presentation/l10n/z_labels.dart` : classe immuable (`const` si possible, `Map.unmodifiable` interne) ; `maybeResolve`/`resolve` ; docstring « pas de singleton statique mutable, instance injectée via ZcrudScope ». Import minimal (`foundation.dart` si `@immutable`/`mapEquals`).
  - [x] `==`/`hashCode` par contenu (permettre à `updateShouldNotify` un comparatif d'identité/valeur cohérent) — `Equatable` INTERDIT (canonique), comparaison manuelle via `mapEquals`.

- [x] **Tâche 2 — `ZcrudLocalizations` + delegate générique (AC: 2, 3)**
  - [x] `lib/src/presentation/l10n/z_localizations.dart` : `ZcrudLocalizations` (tables `en`/`fr` **génériques** ; `resolve(key)` ; `static of(context)` via `Localizations.of`). `ZcrudLocalizationsDelegate extends LocalizationsDelegate<ZcrudLocalizations>` (`isSupported` en/fr, `load`, `shouldReload=false`). Import `widgets.dart` (PAS `flutter_localizations`).
  - [x] Clés génériques figées (boutons/validations/états) ; **aucun** terme métier. Documenter la convention de clés.

- [x] **Tâche 3 — Composition de résolution de libellé (AC: 4)**
  - [x] Helper `label(BuildContext, String key, {String? fallback})` (méthode statique OU extension sur `BuildContext` — décision documentée) : ordre `scope.labels?.maybeResolve → ZcrudLocalizations.of().resolve → key`. Jamais de throw sur clé absente.

- [x] **Tâche 4 — `ZcrudTheme` (ThemeExtension) + résolution/repli (AC: 2, 5, 6)**
  - [x] `lib/src/presentation/theme/z_theme.dart` : `ZcrudTheme extends ThemeExtension<ZcrudTheme>` ; tokens (couleurs sémantiques nullable, espacements/rayons `EdgeInsetsDirectional`/`double`/`BorderRadius`) ; `copyWith`/`lerp`. `static of(context)` (scope → Theme.extension → fallback). `ZcrudTheme.fallback(ThemeData)` **dérive** tout de `ColorScheme`/`TextTheme` (0 hex). Import `material.dart` (ThemeExtension/Theme/ThemeData/ColorScheme).

- [x] **Tâche 5 — Extension de `ZcrudScope` (AC: 5, 9)**
  - [x] UPDATE `lib/src/presentation/zcrud_scope.dart` : + `ZcrudLabels? labels` + `ZcrudTheme? theme` (défaut `null`) ; `updateShouldNotify` étendu (identité des 4 seams) ; `resolver`/`acl`/`of`/`maybeOf` inchangés. Docstring mise à jour.

- [x] **Tâche 6 — Barrel (AC: 2, 10)**
  - [x] UPDATE `lib/zcrud_core.dart` : +4 exports presentation (ordre alpha) ; E2-1..E2-7 + `ZCoreApi` + dartz curaté conservés.

- [x] **Tâche 7 — Gardes de pureté ÉTENDUES (AC: 1, 6, 7, 8)**
  - [x] UPDATE `test/purity/presentation_purity_test.dart` : ajouter `package:flutter/material.dart` à la whitelist ; conserver cupertino/services/dart:ui-direct/managers/deps lourdes interdits ; ajouter tokens `lex_localizations`/`go_router`/`GoRouter`/`context.l10n` interdits transverses.
  - [x] NEW `test/purity/style_purity_test.dart` : (a) 0 littéral couleur sous `presentation/` (hors `z_theme.dart#fallback` documenté) ; (b) 0 variante non-directionnelle (`EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`/`topLeft/Right`, `TextAlign.left/right`, `Positioned(left/right`) ; (c) 0 constante style `kNavyColor`/`kFormInputDecorationTheme`.
  - [x] `domain_purity_test.dart` : **inchangé**, re-vérifié vert (Material ne fuit pas sous `domain/`).

- [x] **Tâche 8 — Tests l10n / thème / RTL (AC: 3, 4, 5, 7)**
  - [x] `test/presentation/z_localizations_test.dart` : `isSupported` en/fr ; `load('fr')`/`load('en')` libellés génériques non vides ; scan anti-terme-métier ; `resolve(clé inconnue)` défini.
  - [x] `test/presentation/z_labels_test.dart` : immuabilité (map non modifiable) ; surcharge via scope ; fallback delegate ; **isolation** deux scopes/labels indépendants ; `==`/`hashCode` par contenu.
  - [x] `test/presentation/z_theme_test.dart` : ordre de résolution (scope > extension > fallback) ; repli dérivé de `ColorScheme` (light≠dark, 0 hex) ; `copyWith`/`lerp`.
  - [x] `test/presentation/rtl_reference_test.dart` : widget de référence (libellé + thème) sous `Directionality.rtl` **et** `.ltr` ; `EdgeInsetsDirectional.only(start:).resolve(rtl)` → droite, `.resolve(ltr)` → gauche.

- [x] **Tâche 9 — Vérif verte & non-régression (AC: 1, 9, 10, 11)**
  - [x] `generate` OK ; `analyze` RC=0 (14 pkgs) ; `flutter test` zcrud_core RC=0 ; `melos run test` RC=0 ; `melos run verify` RC=0 (`CORE OUT=0 OK`, `ACYCLIQUE OK`, gates OK) ; `prove_gates.dart` 0 FAIL.
  - [x] Non-régression : 12 tests `zcrud_scope_test` E2-7 verts ; tests E2-1..E2-7 verts ; `melos list`=14 ; `git ls-files '*.g.dart'`=0 ; greps pureté 0 violation ; 0 token manager / `lex_localizations` / `go_router`.

## Dev Notes

### Décision d'architecture : Material entre dans `presentation/` (à valider en code-review)

E2-7 a interdit `flutter/material.dart` sous `presentation/` avec le marqueur « (E2-7) » = décision différée. **E2-8 l'autorise** parce que FR-26 impose `ThemeExtension` (dans `material.dart`) + repli `Theme.of(context)` (dans `material.dart`). Il n'existe **pas** de chemin material-free qui satisfasse la conséquence testable FR-26 « en l'absence de thème fourni, le moteur hérite du `Theme.of(context)` » **dans le cœur**. Deux options ont été pesées :
- **(Retenue) `ZcrudTheme = ThemeExtension<ZcrudTheme>`, résolution via `Theme.of` + scope, Material autorisé sous `presentation/`.** Fidèle à FR-26 mot pour mot ; Material était de toute façon requis en E3 (widgets de champ Material par défaut, AD-8). Coût : relaxation d'une garde de pureté (bornée : cupertino/services restent interdits).
- **(Rejetée) `ZcrudTheme` porté uniquement par `ZcrudScope`, repli délégué à un binding.** Garde le cœur material-free mais **ne satisfait pas** la conséquence testable « hérite du `Theme.of` » dans le cœur (le repli devient externe/non testable ici) ; complique E3 qui devra quand même tirer Material.

⚠️ **Le code-review DOIT statuer** sur cette relaxation (cohérence AD-14 « `zcrud_core` autorise Flutter — c'est `domain/` qui est pur-Dart, pas tout le package » ⇒ autoriser Material sous `presentation/` est conforme). `cupertino.dart`/`services.dart`/`dart:ui`-direct/managers/deps lourdes **restent interdits**.

### Frontière de pureté PAR COUCHE — état après E2-8

| Couche | Flutter ? | Autorisé | Interdit |
|---|---|---|---|
| `lib/src/domain/**` | **NON** | `dartz`, Dart pur | **tout** `package:flutter/*`, `dart:ui`, backend, managers |
| `lib/src/data/**` | **NON** | `dartz`, Dart pur | idem domain |
| `lib/src/presentation/**` | **OUI (restreint)** | `flutter/foundation.dart`, `flutter/widgets.dart`, **`flutter/material.dart` (E2-8)**, internes, `dartz` | `dart:ui` direct, `flutter/cupertino.dart`, `flutter/services.dart`, managers, deps lourdes, **littéraux de couleur**, **variantes non-directionnelles**, `lex_localizations`/`go_router` |
| **Transverse tout `zcrud_core/lib`** | — | — | tokens `WidgetRef`/`Get.find`/`Get.put`/`Provider.of`, `lex_localizations`/`go_router`/`GoRouter`/`context.l10n` |

### Conception l10n (delegate générique + registre) — le point à ne pas rater

- **`ZcrudLocalizations`/`ZcrudLocalizationsDelegate` ⇒ `package:flutter/widgets.dart`** (`Localizations`, `LocalizationsDelegate`, `Locale`). **NE PAS** ajouter `flutter_localizations` (inutile pour un delegate custom ; l'ajouter tirerait GlobalMaterialLocalizations et n'est pas requis par FR-23).
- **Générique = zéro ressource métier** : les clés sont des **actions/états d'UI CRUD** (`save`, `cancel`, `delete`, `edit`, `add`, `confirm`, `search`, `required`, `invalidValue`, `loading`, `empty`, `retry`, `yes`, `no`, `selectDate`…). Un test à liste sentinelle échoue si un terme métier (nom d'entité applicative) apparaît. Les libellés **métier** sont du ressort de `ZcrudLabels`, injecté par l'app.
- **`ZcrudLabels` = registre injectable SANS singleton statique mutable** : instance immuable passée à `ZcrudScope(labels:)`. Interdit formel (AD-13/FR-23) : `static Map ... ` mutable, variable de librairie mutable, setter global. Preuve : test d'immuabilité (`expect(() => labels.map[...] = ..., throwsUnsupportedError)` ou map `const`) + test d'isolation deux-scopes.
- **Composition** : `label(context, key)` = `scope.labels?.maybeResolve(key)` ?? `ZcrudLocalizations.of(context).resolve(key)` ?? `key`. Le delegate donne le défaut **locale-aware** ; le registre donne la **surcharge/extension app**. Cette séparation matérialise « delegate générique + registre de libellés » (AD-13).

### Conception thème (ThemeExtension injectable + repli dérivé)

- `ZcrudTheme extends ThemeExtension<ZcrudTheme>` : implémenter `copyWith` **et** `lerp` (contrat obligatoire ; `analyze` échoue sinon). Tokens couleur **nullable** (résolus au repli) ; espacements/rayons = tokens `const` nommés (échelle `gapS/M/L`, `radiusS/M`) exprimés en `EdgeInsetsDirectional`/`double`/`BorderRadius`.
- **`of(context)`** : `ZcrudScope.maybeOf(context)?.theme` (surcharge app injectée dans le scope) ?? `Theme.of(context).extension<ZcrudTheme>()` (extension posée dans `ThemeData`) ?? `ZcrudTheme.fallback(Theme.of(context))`.
- **`fallback(ThemeData t)`** : **dérive** chaque couleur de `t.colorScheme`/`t.textTheme` (ex. bordure = `t.colorScheme.outline`, erreur = `t.colorScheme.error`, libellé = `t.textTheme.bodyMedium?.color`). **AUCUN** `Color(0x…)` littéral ⇒ « aucune couleur en dur » (FR-26) prouvé par la garde de style + le test light≠dark.

### Preuve « aucun style codé en dur » & « directionnel uniquement »

Deux mécanismes cumulés :
1. **Garde de style (`test/purity/style_purity_test.dart`)** — scan des fichiers `lib/src/presentation/**` :
   - **Couleurs** : échoue si `Color(0x`, `Colors.`, ou littéral `0x[fF]{6,8}` apparaît (hors bloc `fallback` documenté qui ne fait que lire `ColorScheme`). Échoue aussi sur `kNavyColor`/`kFormInputDecorationTheme` (FR-26).
   - **Directionnel** : échoue si `EdgeInsets.only(` avec `left:`/`right:`, `Alignment.centerLeft`/`centerRight`/`topLeft`/`topRight`/`bottomLeft`/`bottomRight`, `TextAlign.left`/`TextAlign.right`, `Positioned(` avec `left:`/`right:`.
   - Réutiliser le squelette `_stripComment`/`_containsWord` de `domain_purity_test.dart` (scan hors commentaires).
2. **Test de comportement RTL (`rtl_reference_test.dart`)** — `EdgeInsetsDirectional.only(start:X).resolve(TextDirection.rtl)` = padding droite ; `.resolve(ltr)` = padding gauche ; widget de référence monté sous `Directionality.rtl` sans exception.

*(Le lint statique Dart n'a pas de règle « use_directional_edge_insets » intégrée dans la baseline `lints/recommended` — d'où la garde de test maison, cohérente avec le pattern E2-7 des purity-tests.)*

### Branchement sur `ZcrudScope` (E2-7)

`ZcrudScope` (E2-7) porte déjà `resolver` (throwing) + `acl` (`ZAllowAllAcl`). E2-8 **ajoute deux champs optionnels** au même bundle immuable : `ZcrudLabels? labels` et `ZcrudTheme? theme` (défaut `null`). `updateShouldNotify` compare l'identité des 4. Le chemin **zéro-config** (`const ZcrudScope(child: …)`) reste valide : sans `labels`, la résolution retombe sur le delegate ; sans `theme`, `ZcrudTheme.of` retombe sur `Theme.of`. Les libellés/thème sont ainsi résolus « via `ZcrudScope` ou un binding » (AD-6/AD-15) — le binding E2-9 fournira ces champs selon son idiome, sans modifier le cœur.

> **Décision `labels` : scope vs delegate.** Le delegate (`ZcrudLocalizations`) fournit les **défauts génériques locale-aware** ; le registre (`ZcrudLabels`, dans le scope) fournit les **surcharges + libellés métier**. Les deux coexistent : le delegate est monté dans `MaterialApp.localizationsDelegates` par l'app ; le registre est monté dans `ZcrudScope`. `label(context, key)` compose les deux. Ce choix satisfait « delegate générique + registre » (AD-13) sans dupliquer les responsabilités.

### Conventions de code (canonique §5, cohérence E2-1..E2-7)

- Types publics **préfixés `Z`/`Zcrud`** ; fichiers `snake_case` ; API via barrel ; `directives_ordering` (ordre alpha des exports).
- **`Equatable` jamais** ; `==`/`hashCode` manuels (`mapEquals` pour `ZcrudLabels`).
- **`freezed`/`@JsonSerializable` non requis** (aucun modèle sérialisé ; 0 `.g.dart`).
- `analysis_options` hérité (`include: ../../analysis_options.yaml`) ; `public_member_api_docs` satisfait (docstrings sur tout public).
- Tests `presentation/` : **`flutter_test`** (`testWidgets`/`WidgetTester`, `pump` — pas de `pumpAndSettle` inutile) ; tests de pureté : `package:test` (tournent sous `flutter test`, package désormais Flutter — cf. E2-7 AC9).

### Emplacements décidés (sous `packages/zcrud_core/lib/src/presentation/`)

| Type | Fichier |
|---|---|
| `ZcrudLocalizations` (+ `ZcrudLocalizationsDelegate`) | `presentation/l10n/z_localizations.dart` |
| `ZcrudLabels` | `presentation/l10n/z_labels.dart` |
| helper `label(context, key)` (si public) | `presentation/l10n/z_localizations.dart` (ou extension dédiée) |
| `ZcrudTheme` (+ `of`/`fallback`) | `presentation/theme/z_theme.dart` |

### Source tree à toucher

```
packages/zcrud_core/
  pubspec.yaml                                     # INCHANGÉ (Material = SDK déjà présent ; PAS de flutter_localizations)
  lib/zcrud_core.dart                              # UPDATE : +4 exports presentation (ordre alpha) ; E2-1..E2-7 conservés
  lib/src/presentation/
    zcrud_scope.dart                               # UPDATE : + labels? + theme? au bundle ; updateShouldNotify étendu
    l10n/
      z_localizations.dart                         # NEW (ZcrudLocalizations + delegate générique + helper label)
      z_labels.dart                                # NEW (ZcrudLabels : registre immuable injectable)
    theme/
      z_theme.dart                                 # NEW (ZcrudTheme ThemeExtension + of/fallback)
  test/presentation/
    z_localizations_test.dart                      # NEW (delegate générique, anti-terme-métier)
    z_labels_test.dart                             # NEW (immuabilité, surcharge, isolation)
    z_theme_test.dart                              # NEW (ordre résolution, repli dérivé, copyWith/lerp)
    rtl_reference_test.dart                        # NEW (Directionality.rtl/ltr, EdgeInsetsDirectional)
    zcrud_scope_test.dart                          # (E2-7) — reste vert ; éventuel ajout labels/theme
  test/purity/
    presentation_purity_test.dart                  # UPDATE : + material.dart whitelist ; + lex_localizations/go_router interdits
    style_purity_test.dart                         # NEW : aucune couleur en dur + directionnel uniquement
    domain_purity_test.dart                        # INCHANGÉ (re-vérifié vert)
```

### Project Structure Notes

- `pubspec.yaml` **inchangé** : Material est fourni par le SDK Flutter déjà présent (E2-7) ; `flutter_localizations` **non ajouté** → `CORE OUT=0` préservé (`graph_proof.py`).
- Nouveaux sous-dossiers `presentation/l10n/` et `presentation/theme/` (organisation ; couverts par la garde `presentation/`).
- Réutiliser `ZcrudScope` (E2-7) — **étendre** son bundle, ne pas le réécrire ni déplacer `resolver`/`acl`.
- Réutiliser le squelette de scan (`_stripComment`/`_containsWord`) des purity-tests E2-7 pour la garde de style/directionnel.
- Aucun `*.g.dart` (aucun modèle annoté).

### References

- [Source: epics.md#E2 (Story E2-8)] — delegate générique sans ressources métier ; registre de libellés ; pas de singleton statique mutable ; zéro dépendance `lex_localizations`/`go_router` (AD-13, FR-23) ; thème injectable `ZcrudTheme`/`ThemeExtension` via `ZcrudScope`, aucun style codé en dur, repli `Theme.of(context)` (FR-26).
- [Source: architecture.md#AD-13] — RTL/a11y/l10n injectable : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`PositionedDirectional` ; `Semantics` ≥48 dp ; l10n via delegate générique + registre de libellés (pas de singleton statique mutable) ; zéro dépendance `lex_localizations`/`go_router`.
- [Source: architecture.md#AD-6] — seams (resolver, permissions, toast, config, **l10n**, codecs) résolus par binding/`ZcrudScope` ; accès via `ZcrudScope.of(context)`.
- [Source: architecture.md#AD-14] — `domain/` pur-Dart ; `zcrud_core` **autorise Flutter** (widgets du moteur) — fonde la relaxation Material sous `presentation/`.
- [Source: architecture.md#AD-15] — aucun manager dans le cœur ; bindings optionnels ; `ZcrudScope` défaut ; ajouter un manager = nouveau binding.
- [Source: prd.md#FR-23] — delegate générique sans ressource métier ; libellés métier via registre ; pas de singleton statique mutable, accès `of(context)` ; widgets directionnels, `Semantics`, ≥48 dp.
- [Source: prd.md#FR-26] — style via `ZcrudTheme`/`ThemeExtension` injecté par `ZcrudScope` ; aucun style codé en dur (pas de `kNavyColor`/`kFormInputDecorationTheme`) ; repli `Theme.of(context)` (dérivé, aucune couleur en dur).
- [Source: CLAUDE.md#Critical Patterns + Key Don'ts] — thème injecté via `ZcrudScope`/`ThemeExtension` (FR-26), repli `Theme.of(context)` ; jamais `EdgeInsets.only(left/right)`/`Alignment.centerLeft/Right`/`TextAlign.left/right`/`Positioned(left/right)` → variantes directionnelles ; jamais de style/couleur codé en dur dans un package.
- [Source: e2-7-reactivite-flutter-native.md] — `ZcrudScope` (InheritedWidget) + seams throw par défaut ; garde `presentation_purity_test.dart` (material interdit « (E2-7) », à relaxer ici) ; pattern purity-test (`_stripComment`/`_containsWord`).
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart] — bundle `resolver`+`acl` à **étendre** (`labels?`/`theme?`) ; `of`/`maybeOf`/`updateShouldNotify`.
- [Source: packages/zcrud_core/lib/src/domain/ports/z_acl.dart] — `ZAllowAllAcl` défaut (modèle du « défaut zéro-config sûr » à répliquer pour labels/theme = `null` + repli).
- [Source: packages/zcrud_core/test/purity/presentation_purity_test.dart] — whitelist `_allowedFlutter` (+material), `_forbiddenPresentation` (garder cupertino/services/managers), `_forbiddenTokens` (+`lex_localizations`/`go_router`).
- [Source: analysis_options.yaml] — baseline `lints/recommended` (pas de règle directionnelle intégrée → garde de test maison) ; `directives_ordering` actif.

## Stratégie de tests

- **`ZcrudLocalizations`/delegate (`z_localizations_test.dart`, flutter_test)** : `isSupported(en/fr)` = true ; `load('fr')`/`load('en')` → libellés génériques non vides et localisés ; `resolve(clé inconnue)` = comportement défini (retour clé/fallback) ; **scan anti-terme-métier** (aucune valeur/clé métier).
- **`ZcrudLabels` (`z_labels_test.dart`, flutter_test)** : immuabilité (mutation ⇒ `UnsupportedError` ou map `const`) ; `ZcrudScope(labels:).of → maybeResolve` surcharge un générique ; clé non surchargée ⇒ fallback delegate ; **isolation** : deux sous-arbres avec deux `ZcrudLabels` distincts résolvent indépendamment ; `==`/`hashCode` par contenu (`mapEquals`).
- **`ZcrudTheme` (`z_theme_test.dart`, flutter_test)** : `of()` ordre scope > `Theme.extension` > `fallback` (3 cas montés) ; `fallback(ThemeData.light())` ≠ `fallback(ThemeData.dark())` sur les couleurs (dérivation prouvée, 0 hex) ; `copyWith` identité ; `lerp(a,b,0)==a` sur tokens clés.
- **RTL (`rtl_reference_test.dart`, flutter_test)** : widget de référence (libellé + `ZcrudTheme.of`) monté sous `Directionality.rtl` **et** `.ltr` rend sans exception ; `EdgeInsetsDirectional.only(start:X).resolve(rtl)` → `right==X`, `.resolve(ltr)` → `left==X`.
- **Pureté (`test/purity/*`, flutter_test)** : `presentation_purity_test.dart` — material.dart autorisé, cupertino/services/dart:ui-direct/managers/deps lourdes interdits, +`lex_localizations`/`go_router` interdits transverses ; `style_purity_test.dart` — 0 littéral couleur (hors `fallback`), 0 variante non-directionnelle, 0 `kNavyColor`/`kFormInputDecorationTheme` ; `domain_purity_test.dart` — inchangé, vert (Material ne fuit pas sous `domain/`).
- **Non-régression** : `zcrud_scope_test.dart` (12 tests E2-7) verts ; tests E2-1..E2-7 verts sous `flutter test` ; barrel exporte tout E2-1..E2-7 + 4 nouveaux.
- **Vérif verte finale** : `melos run generate` OK → `analyze` RC=0 → `flutter test` zcrud_core RC=0 → `melos run test` RC=0 → `melos run verify` RC=0 (`CORE OUT=0`, ACYCLIQUE, gates) ; greps pureté 0 violation.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story).

### Debug Log References

#### Passe de durcissement des findings LOW du code-review (L-1..L-4) — statut reste `review`

Durcissement des 4 findings LOW de `code-review-e2-8.md` (aucune violation active ; robustesse de garde / cohérence de repli). Rejoué réellement sur disque :

- **L-1 (comportement `label()`)** — `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart:143-160`. `label()` honore désormais le **même repli `en`** que `ZcrudLocalizations.of` : ordre `scope.labels?.maybeResolve` → `ZcrudLocalizations.of(context).maybeResolve` (retombe sur la table `en` si le delegate n'est pas monté) → **table `en` intégrée** (`_enLabels`, pour le cas delegate monté mais clé absente de sa locale) → `fallback ?? key`. Preuve : nouveau test `label(context,key) SANS delegate monté → repli 'en' intégré, pas la clé brute (L-1)` — `label(context,'save') == 'Save'` (et `isNot('save')`), clé inconnue → `fallback`.
- **L-2 (garde couleur)** — `packages/zcrud_core/test/purity/style_purity_test.dart:_colorPatterns`. Ajout de `Color\.fromARGB\(` et `Color\.fromRGBO\(` aux motifs interdits. Preuve : test d'auto-vérif `L-2 : la garde couleur détecte Color.fromARGB / Color.fromRGBO` (échantillons en chaînes de test, jamais au top-level d'un fichier lib scanné).
- **L-3 (garde directionnelle)** — `style_purity_test.dart` : le scan directionnel opère désormais sur le **contenu entier du fichier** (lignes jointes hors commentaires, `[^)]*` traverse les `\n`) → attrape les appels multi-lignes (`EdgeInsets.only(\n left:…)`, `Positioned(\n left:…)`). Ajout de `EdgeInsets\.fromLTRB\(`, `BorderRadius\.only\(`, `BorderRadius\.horizontal\(` aux motifs non-directionnels. Preuve : test d'auto-vérif `L-3 : … détecte le multi-ligne et fromLTRB/BorderRadius non-directionnels` (5 échantillons détectés + contre-preuve : les variantes `*Directional` ne déclenchent pas la garde).
- **L-4 (sentinelle métier)** — `z_localizations.dart` : nouvelle API `Iterable<String> ZcrudLocalizations.keys` (clés réellement livrées). `packages/zcrud_core/test/presentation/z_localizations_test.dart` : le scan anti-terme-métier itère désormais `loc.keys` (table réelle en/fr du delegate) au lieu d'une liste de 21 clés dupliquée → toute future clé métier ajoutée à `_enLabels`/`_frLabels` reste couverte.

Vérif verte rejouée : `flutter test` zcrud_core RC=0 — **198** tests (195 avant → +3 : test L-1 + 2 auto-vérifs de gardes L-2/L-3 ; L-4 modifie un test existant). `melos run analyze` RC=0 (14 pkgs « No issues found »). `melos run test` RC=0 (14 pkgs SUCCESS, parité bindings verte). `melos run verify` RC=0 — `ACYCLIQUE OK`, `CORE OUT=0 OK`, gates melos/reflectable/secrets/codegen/compat OK. `prove_gates` **22 OK, 0 FAIL** (inchangé). `melos list`=14 ; `git ls-files '*.g.dart'`=0. Pureté par couche inchangée (material confiné à `theme/z_theme.dart`). Aucun littéral interdit non échappé réintroduit dans un fichier lib scanné.

#### Passe initiale

- `melos run generate` RC=0 (no-op propre : 1 modèle @ZcrudModel, 0 .g.dart manquant).
- `melos run analyze` RC=0 — 14 packages « No issues found ».
- `flutter test` (zcrud_core) RC=0 — **195** tests (25 nouveaux E2-8 + 170 non-régression E2-1..E2-7, dont SM-1 `sm1_granular_rebuild_test`).
- `melos run test` RC=0 — global vert, dont bindings parité ×3 (`zcrud_get` +17, `zcrud_riverpod` +8, `zcrud_provider` +8) + bare, malgré l'extension du bundle `ZcrudScope`.
- `melos run verify` RC=0 — `out-degree(zcrud_core)=0`, `CORE OUT=0 OK`, `ACYCLIQUE OK`, gates melos/reflectable/secrets/codegen/compat OK.
- `scripts/ci/prove_gates.dart` RC=0 — **22 OK, 0 FAIL**.
- Greps de pureté (sur `packages/zcrud_core/lib`) : `lex_localizations|go_router|GoRouter|context.l10n` = **0** ; `WidgetRef|Get.find|Get.put|Provider.of` = **0** ; littéraux couleur sous `presentation/` (`Color(0x`/`Colors.`/`0xFF…`) = **0**. `material.dart` importé UNIQUEMENT par `theme/z_theme.dart`. `git ls-files '*.g.dart'` = 0 ; `melos list` = 14.

### Completion Notes List

- **Seams l10n concrets** : `ZcrudLocalizations` + `ZcrudLocalizationsDelegate` (delegate custom générique via `flutter/widgets.dart`, PAS `flutter_localizations`), tables `en`/`fr` de libellés d'UI CRUD (21 clés génériques : save/cancel/delete/edit/add/confirm/search/required/invalidValue/loading/empty/retry/yes/no/select/selectDate/close/reset/remove/next/previous). Test à liste sentinelle prouve **zéro terme métier** (douane/étude/flashcard/mindmap/déclaration/tarif/facture…).
- **Registre injectable** : `ZcrudLabels` immuable (`Map.unmodifiable`, `const ZcrudLabels.empty`), `maybeResolve`/`resolve`, `==`/`hashCode` par contenu (`mapEquals`, `Equatable` banni). Aucun champ statique mutable ; test d'**isolation** deux-scopes prouve l'absence d'état global.
- **Composition `label(context, key, {fallback})`** : fonction top-level (décision ambiguïté #3, cf. ci-dessous). Ordre `scope.labels?.maybeResolve` → `ZcrudLocalizations.maybeOf().maybeResolve` → `fallback ?? key`. Jamais de throw sur clé absente.
- **Thème injectable** : `ZcrudTheme extends ThemeExtension<ZcrudTheme>` (couleurs sémantiques nullable + tokens `gapS/M/L`, `radiusS/M`, `fieldPadding` `EdgeInsetsDirectional`), `copyWith`/`lerp` conformes, `of()` = scope → `Theme.extension` → `fallback`. `ZcrudTheme.fallback(ThemeData)` **dérive** toutes les couleurs de `ColorScheme`/`TextTheme` (0 hex ; test light≠dark).
- **`ZcrudScope` étendu** : +`ZcrudLabels? labels` +`ZcrudTheme? theme` (optionnels, défaut `null` → zéro-config préservé) ; `updateShouldNotify` sur l'identité des **4** seams ; `resolver`/`acl`/`of`/`maybeOf` E2-7 inchangés (tous verts).
- **Gardes de pureté** : `presentation_purity_test.dart` MAJ (material.dart whitelisté ; cupertino/services/dart:ui-direct/managers/deps lourdes maintenus interdits ; +tokens `lex_localizations`/`go_router`/`GoRouter`/`context.l10n` transverses). NEW `style_purity_test.dart` (0 littéral couleur hors `fallback` exempté par comptage d'accolades ; 0 variante non directionnelle `EdgeInsets.only(left/right`/`Alignment.center*Left/Right`/`TextAlign.left/right`/`Positioned(left/right`). `domain_purity_test.dart` inchangé, vert (Material ne fuit pas sous `domain/`).
- **RTL** : test `rtl_reference_test.dart` — widget de référence (libellé + `ZcrudTheme.of`) rend sous `Directionality.rtl` **et** `.ltr` sans exception ; `EdgeInsetsDirectional.only(start:24).resolve(rtl).right==24` / `.resolve(ltr).left==24`.

**Décisions tranchées (ambiguïtés) :**
- **#1 (validée par l'orchestrateur)** : garde `presentation/` relâchée pour autoriser `package:flutter/material.dart` (requis par `ThemeExtension`/`Theme.of`, FR-26). Confiné à `theme/z_theme.dart`. `cupertino`/`services`/`dart:ui`-direct/managers/deps lourdes restent interdits ; `domain/`+`data/` restent pur-Dart strict. **À statuer en code-review** (conforme AD-14).
- **#3 (forme du helper)** : **fonction top-level** `label(BuildContext, String, {String? fallback})` plutôt qu'extension sur `BuildContext` — évite de polluer l'espace des méthodes de `BuildContext`, reste explicitement importable via le barrel, testable directement.
- **#4 (comportement sur clé absente / repli thème)** : résolution **jamais throw** — `resolve(cléInconnue)` renvoie la clé (delegate) ; `label(...)` renvoie `fallback ?? key` ; `ZcrudLocalizations.of` retombe sur la table `en` intégrée si le delegate n'est pas monté (rendu sans crash). Repli thème `ZcrudTheme.fallback` **dérivé** (aucun hex), jamais un thème constant codé en dur.

### File List

**NEW**
- `packages/zcrud_core/lib/src/presentation/l10n/z_labels.dart`
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart`
- `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart`
- `packages/zcrud_core/test/presentation/z_localizations_test.dart`
- `packages/zcrud_core/test/presentation/z_labels_test.dart`
- `packages/zcrud_core/test/presentation/z_theme_test.dart`
- `packages/zcrud_core/test/presentation/rtl_reference_test.dart`
- `packages/zcrud_core/test/purity/style_purity_test.dart`

**MODIFIED**
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (+`labels?`/`theme?`, `updateShouldNotify` étendu)
- `packages/zcrud_core/lib/zcrud_core.dart` (barrel : +4 exports presentation, ordre alpha)
- `packages/zcrud_core/test/purity/presentation_purity_test.dart` (material whitelisté ; +tokens l10n-app interdits)
- `packages/zcrud_core/test/presentation/zcrud_scope_test.dart` (+3 tests non-régression labels/theme E2-8)
