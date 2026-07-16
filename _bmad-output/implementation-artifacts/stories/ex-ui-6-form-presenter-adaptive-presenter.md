# Story EX-UI.6 : Port `ZFormPresenter` (non-`sealed`) + présentateur par défaut pur-Flutter `ZAdaptivePresenter` + seam local + helper `presentEdition`

Status: ready-for-dev

- **Clé sprint-status** : `ex-ui-6-form-presenter-adaptive-presenter`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit)
- **Taille** : **L** (port + présentateur 3 surfaces modales + seam `InheritedWidget` + helper de câblage responsivité→présentation ; réécriture GetX→Flutter vanilla de `showPushedDialog` ; tests **widget** des surfaces modales)
- **Parallélisation** : ⛔ **SÉQUENTIELLE dans P2 (nav).** Dépend d'**EX-UI.5** (`review`/`done` — fournit `ZEditionPresentation`, `ZFormWeight`, `ZPresentationPolicy`). **MÊME PACKAGE** `zcrud_navigation` (peuple `lib/src/presentation/`, vide en EX-UI.5) ⇒ séquentiel après EX-UI.5, jamais en parallèle avec elle. **Précède EX-UI.11** (binding GetX, qui implémentera ce même port). Parallélisable avec le workstream **P3** (`zcrud_ui_kit`, EX-UI.7..10) — packages disjoints.
- **Package écrit (disjoint)** : `packages/zcrud_navigation/lib/src/presentation/` (NEW — 4 fichiers) + barrel `lib/zcrud_navigation.dart` (UPDATE — 4 exports). ⛔ **N'ÉCRIT NI `zcrud_core` NI `zcrud_responsive`** — il les **consomme**. ⛔ **NE TOUCHE PAS** `lib/src/domain/` (enums + politique livrés en EX-UI.5, intacts). ⛔ **NE TOUCHE PAS** le `pubspec.yaml` racine (aucun nouveau package ⇒ `melos list` inchangé).
- **AD delta** : **AD-30** (présentateur par défaut **pur-Flutter** exécutant le mode `ZEditionPresentation` via `Navigator.push(MaterialPageRoute(fullscreenDialog:))` / `showModalBottomSheet` / `showDialog` — **Flutter vanilla, form-agnostique** ; port `ZFormPresenter` **pluggable, jamais `sealed`** ; présentateurs manager GetX/go_router = **bindings**, hors périmètre ; résolution via **seam**, défaut = présentateur pur-Flutter). **AD hérités** : AD-4 (port **jamais `sealed`** — impl externe compile), AD-6 (résolution du présentateur effectif par **seam**, défaut sûr), AD-2/AD-15 (Flutter-native, **aucun** gestionnaire d'état **ni routeur** : ni `get`, ni `go_router`, ni `flutter_riverpod`, ni `provider`), AD-13 (RTL/a11y : directionnel, `Semantics`, cibles ≥ 48 dp), AD-10 (défauts sûrs, jamais de throw sur le mode), AD-1 (acyclique, `CORE OUT=0` intact — les arêtes du package restent sortantes), AD-12 (zéro secret).

---

## ⚠️ Périmètre — CE QUI EST DANS / HORS de cette story

> **DANS EX-UI.6** — peuple `lib/src/presentation/` de `zcrud_navigation` (4 fichiers NEUFS) :
> - le **port `ZFormPresenter`** : interface **ABSTRAITE, jamais `sealed`** (AD-4), `Future<T?> present<T>(BuildContext, {required WidgetBuilder builder, required ZEditionPresentation mode, double? maxWidth, double? maxHeight, ...})` — **form-agnostique** (prend un `WidgetBuilder`, aucune détection interne du type de formulaire) ;
> - le **présentateur par défaut pur-Flutter `ZAdaptivePresenter implements ZFormPresenter`** : exécute chaque mode en **Flutter VANILLA** — `page` → `Navigator.push(MaterialPageRoute(fullscreenDialog: true))` ; `sheet` → `showModalBottomSheet(isScrollControlled: true, constraints…)` ; `dialog` → `showDialog(→ Dialog contraint aux tailles max)`. **Aucun** `Get.to`/`Get.bottomSheet`/`Get.dialog`, **aucun** `Get.width`/`Get.height` ;
> - le **seam** `ZFormPresenterScope` (`InheritedWidget` **local à `zcrud_navigation`**) : résout le présentateur effectif dans l'arbre de widgets, **défaut = `const ZAdaptivePresenter()`** (AD-6) ; c'est le point d'injection qu'un binding (EX-UI.11) surchargera ;
> - le **helper `presentEdition`** : **matérialise le maillon manquant responsivité→présentation** — résout `ZWindowSizeClass.of(context)` (via `zcrud_responsive`), dérive le mode par `ZPresentationPolicy.resolve(...)` (EX-UI.5), puis délègue au présentateur effectif (résolu par le seam). C'est le câblage complet `largeur → breakpoint → politique → mode → surface`.
>
> **HORS EX-UI.6** :
> - ⛔ **présentateurs manager GetX** (`zcrud_get`) **et go_router** (`zcrud_riverpod`) → **EX-UI.11 / bindings** (ils implémenteront **ce même port** `ZFormPresenter`) ;
> - ⛔ **toute modification de `ZcrudScope` de `zcrud_core`** (cf. D8 — l'y ajouter casserait `CORE OUT=0`) ;
> - ⛔ **toute adaptation d'app** (dodlp/iffd/lex/dlcfti) → DW-EXUI-1 ;
> - ⛔ **toute réécriture du domaine EX-UI.5** (`ZEditionPresentation`/`ZFormWeight`/`ZPresentationPolicy` restent **intacts**, consommés tels quels).

---

## Story

**As a** développeur intégrateur qui doit présenter un formulaire d'édition (page pleine / bottom-sheet / dialog) **sans coupler l'app à un gestionnaire d'état ni à un routeur**,
**I want** un **port pluggable `ZFormPresenter`** et un **présentateur par défaut pur-Flutter `ZAdaptivePresenter`** qui exécute le mode `ZEditionPresentation` (fourni par la politique EX-UI.5) via **`Navigator.push(MaterialPageRoute(fullscreenDialog:))` / `showModalBottomSheet` / `showDialog`** en **Flutter vanilla**, plus un **seam** de résolution et un **helper `presentEdition`** qui relie enfin la responsivité à la présentation,
**so that** le mode d'édition **calculé à partir du breakpoint** (EX-UI.5) soit **effectivement exécuté** à l'écran sur la bonne surface modale — la réécriture neutre du `showPushedDialog` GetX des apps — tout en laissant les variantes manager (GetX/go_router) aux **bindings** comme **impls du même port**.

---

## Contexte — vérifié sur disque (pas sur la seule foi de l'épic)

### Ce qu'EX-UI.5 (`review`) FOURNIT DÉJÀ et que cette story CONSOMME

`packages/zcrud_navigation/lib/src/domain/` (exporté par le barrel) déclare **publiquement** :

| Symbole `zcrud_navigation` (EX-UI.5) | Nature | Rôle en EX-UI.6 |
|---|---|---|
| **`ZEditionPresentation`** | `enum { page, sheet, dialog }` (camelCase) | **ENTRÉE** de `present()` — le mode à **exécuter** (page/sheet/dialog) |
| **`ZFormWeight`** | `enum { light, heavy }` | passé au helper `presentEdition` → transmis à `policy.resolve` |
| **`ZPresentationPolicy`** | classe non-`sealed`, `resolve(ZWindowSizeClass, {ZFormWeight}) → ZEditionPresentation` ; défaut `const ZPresentationPolicy()` / `.material()` ; fabrique `.from(resolver)` | dérive le mode dans le helper `presentEdition` |

⛔ **Ces trois types ne sont PAS redéclarés** : ils sont déjà exportés par `lib/zcrud_navigation.dart` — les importer via `../domain/…` (imports internes du package) ou consommer depuis le barrel.

### Ce que `zcrud_responsive` (EX-UI.1, `done`) fournit et que le helper CONSOMME

`packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart` (vérifié) déclare `ZWindowSizeClass.of(BuildContext) → ZWindowSizeClass` : lit la largeur **toujours** via `MediaQuery.sizeOf(context).width` (jamais `Get.width`), délègue à `fromWidth` (défaut sûr `compact`, jamais de throw). ⇒ Le helper `presentEdition` obtient la classe d'écran par **`ZWindowSizeClass.of(context)`** — c'est **le** point de mesure du contexte (la politique EX-UI.5 reste pure, sans `BuildContext`). `zcrud_navigation` **dépend déjà** de `zcrud_responsive` (pubspec vérifié : `zcrud_responsive: ^0.2.0`), aucune arête nouvelle.

### `ZcrudScope` de `zcrud_core` (vérifié) — POURQUOI on NE l'utilise PAS pour le présentateur

`packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` : `ZcrudScope extends InheritedWidget` porte un **bundle fixe** de seams (`resolver`, `acl`, `labels`, `theme`, `widgetRegistry`, `listRenderer`, `filePicker`…). Il **n'a aucun slot présentateur** et vit dans **`zcrud_core`** — y ajouter un `ZFormPresenter` (défini dans `zcrud_navigation`) forcerait `zcrud_core → zcrud_navigation`, **cassant `CORE OUT=0` (AD-1)**. ⇒ **D8 : le seam présentateur est un `InheritedWidget` LOCAL à `zcrud_navigation`** (`ZFormPresenterScope`), jamais une modification de `ZcrudScope`. C'est la lecture correcte de « seam `ZcrudScope`/binding » de l'épic sous la contrainte AD-1 : le mécanisme de seam (un `InheritedWidget` zéro-dépendance, comme `ZcrudScope`) est **répliqué localement** pour le type propre à ce package.

### Best-of-breed apps (LECTURE SEULE — à RÉÉCRIRE en Flutter vanilla, PAS copier)

- **dodlp** `lib/modules/data_crud/forms_utils.dart` `showPushedDialog<T>()` (~331-394) & **iffd** `lib/src/utils/functions/forms_utils.dart:631-739` — **3 branches** : `fullscreenDialog` → `Get.to(…, fullscreenDialog: true)` (route pleine page) ; `dialog` → `Get.dialog`/`showDialog(context: Get.context!, barrierDismissible: true, barrierColor: …)` ; sinon `Get.bottomSheet(BoxConstraints(maxHeight: ~90 % × ratio, maxWidth: ~90 %), isScrollControlled: …)`. **Tailles en fraction d'écran** (dialog ~75 %, sheet ~90 %). **iffd contient déjà un essai commenté (l.684-737) vers `showModalBottomSheet` natif** — la cible. **À NEUTRALISER INTÉGRALEMENT** : (1) `Get.to`/`Get.dialog`/`Get.bottomSheet` → `Navigator.push(MaterialPageRoute(fullscreenDialog: true))` / `showDialog` / `showModalBottomSheet` **natifs** ; (2) `Get.height`/`Get.width`/`Get.context!` → `MediaQuery.sizeOf(context)` + `BuildContext` **explicite** ; (3) les 2 bools `fullscreenDialog`/`dialog` → l'**enum `ZEditionPresentation`** (déjà livré EX-UI.5) ; (4) l'heuristique `builder.runtimeType…endsWith("EditionScreen")` (double-`Card`) → **supprimée** (le port est form-agnostique ; le contenu s'auto-enrobe côté appelant). **Aucune** de ces sources ne dérive le mode du breakpoint — c'est le helper `presentEdition` qui pose ce câblage.

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — Le port et le présentateur vivent sous `presentation/` (PAS `domain/`) — pureté du domaine préservée

Le **Structural Seed** de l'archi place `port ZFormPresenter` sous `domain/`. **Écart assumé et justifié** : le port prend un **`BuildContext`** et un **`WidgetBuilder`** ⇒ il **importe `package:flutter/widgets.dart`**, il **ne peut donc PAS être pur-Dart**. Or EX-UI.5 a codifié (D7) que `lib/src/domain/` de ce package est **pur-Dart, sans aucun `import flutter`** (la politique `resolve()` testable sans `BuildContext`, AD-5/AD-14). Placer un port qui exige `BuildContext` dans `domain/` **contredirait cet invariant**. ⇒ **Le port, le présentateur, le seam et le helper vivent tous sous `lib/src/presentation/`** (couche UI, `import flutter` légitime). `domain/` **reste 100 % pur** (enums + politique EX-UI.5, intacts). Documenter cet écart dans les Completion Notes.

### D2 — Port `ZFormPresenter` : `abstract interface class`, jamais `sealed` (AD-4/NFR-U9)

`lib/src/presentation/z_form_presenter.dart` :

```dart
import 'package:flutter/widgets.dart';
import '../domain/z_edition_presentation.dart';

/// Port PLUGGABLE de présentation d'un formulaire d'édition (jamais `sealed`, AD-4).
abstract interface class ZFormPresenter {
  Future<T?> present<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required ZEditionPresentation mode,
    double? maxWidth,
    double? maxHeight,
    bool useSafeArea = true,
    bool barrierDismissible = true,
  });
}
```

- **`abstract interface class`** (Dart 3) exprime un **contrat d'implémentation pur** — **jamais `sealed`** : une impl **hors package** (`ZGetFormPresenter` d'EX-UI.11, un fake de test) **compile et se substitue** (AD-4/NFR-U9). Le dev peut retenir `abstract class` **à condition** que le type reste implémentable hors package (non-`sealed`, non-`final`) ; documenter le choix.
- **Form-agnostique** : le port prend un `WidgetBuilder` opaque et un `ZEditionPresentation` — **aucune** détection du type de formulaire (l'heuristique `is EditionScreen` des apps est **abandonnée**).
- **Enums > bools (NFR-U7)** : le mode est **toujours** `ZEditionPresentation` — **aucun** `bool fullscreenDialog`/`dialog` dans la signature. `useSafeArea`/`barrierDismissible` restent des **prédicats binaires stricts** (options de `showDialog`/`showModalBottomSheet`, non multi-état) — exception NFR-U7 admise (comme `isDirty`).
- **Tailles max** = paramètres **explicites** `maxWidth`/`maxHeight` (dp), **jamais** `Get.width`/`Get.height` ; `null` ⇒ le présentateur calcule un défaut à partir de `MediaQuery.sizeOf(context)` (cf. D4).

### D3 — `ZAdaptivePresenter implements ZFormPresenter` : Flutter VANILLA, `const`, 3 surfaces (AD-30/AD-2)

`lib/src/presentation/z_adaptive_presenter.dart` — `class ZAdaptivePresenter implements ZFormPresenter { const ZAdaptivePresenter(); … }`. `present()` **switch exhaustif** sur `mode` :

| `mode` | Primitive Flutter **vanilla** | Détail |
|---|---|---|
| `page` | `Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: builder, fullscreenDialog: true))` | route pleine page ; tailles max **ignorées** (documenté) |
| `sheet` | `showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: useSafeArea, constraints: …, builder: builder)` | contraintes `maxHeight`/`maxWidth` appliquées via `BoxConstraints` |
| `dialog` | `showDialog<T>(context: context, useSafeArea: useSafeArea, barrierDismissible: barrierDismissible, builder: (ctx) => Dialog(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: …, maxHeight: …), child: builder(ctx))))` | `Dialog` **contraint** aux tailles max |

⛔ **Aucun** `Get.to`/`Get.bottomSheet`/`Get.dialog`, **aucun** `Get.width`/`Get.height`/`Get.context!`, **aucun** gestionnaire d'état ni routeur (`go_router`). **Aucun** `import 'package:get/…'`/`go_router`. Le `switch` est **exhaustif** (les 3 valeurs de l'enum) ⇒ **jamais de throw** (AD-10). La valeur de retour `T?` provient naturellement de `Navigator.pop(value)` / de la fermeture de la modale (le `Future` des 3 primitives).

### D4 — Tailles max : explicites, sinon défaut dérivé de `MediaQuery.sizeOf` (jamais `Get.width`)

Quand `maxWidth`/`maxHeight` sont `null`, le présentateur dérive un défaut **raisonnable** de `MediaQuery.sizeOf(context)` (reproduit l'intention des apps sans coupler à une largeur globale) — proposition : `dialog` `maxWidth ≈ min(screenW, 560)` ; `sheet` `maxHeight ≈ screenH × 0.9`. **Toujours** `MediaQuery.sizeOf(context)` (se réabonne à la seule taille), **jamais** `Get.width`/`MediaQueryData` figée (AD-2/AD-15/NFR-U2). Les fractions restent des **constantes nommées** internes (pas de littéral magique épars). Le dev peut ajuster les défauts s'ils divergent d'un rendu correct — documenter.

### D5 — Seam `ZFormPresenterScope` : `InheritedWidget` LOCAL, défaut `const ZAdaptivePresenter()` (AD-6/D8)

`lib/src/presentation/z_form_presenter_scope.dart` — `class ZFormPresenterScope extends InheritedWidget { final ZFormPresenter presenter; … }` avec :
- `static ZFormPresenter of(BuildContext context)` → renvoie le présentateur injecté **ou** `const ZAdaptivePresenter()` **par défaut** (jamais de throw : défaut sûr AD-6/AD-10) ;
- `static ZFormPresenterScope? maybeOf(BuildContext context)` (lookup brut) ;
- `updateShouldNotify` = `presenter != oldWidget.presenter`.

C'est le point d'injection qu'un **binding** (EX-UI.11) surcharge en enveloppant l'app dans `ZFormPresenterScope(presenter: ZGetFormPresenter(), child: …)`. ⛔ **Ne modifie PAS `ZcrudScope`** de `zcrud_core` (D8 — casserait `CORE OUT=0`).

### D6 — Helper `presentEdition` : le câblage responsivité→présentation (le maillon rendu vivant)

`lib/src/presentation/present_edition.dart` — fonction top-level :

```dart
Future<T?> presentEdition<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  ZFormWeight formWeight = ZFormWeight.light,
  ZPresentationPolicy policy = const ZPresentationPolicy(),
  ZFormPresenter? presenter,        // null → résolu par le seam (défaut ZAdaptivePresenter)
  double? maxWidth,
  double? maxHeight,
  bool useSafeArea = true,
}) {
  final sizeClass = ZWindowSizeClass.of(context);              // zcrud_responsive (EX-UI.1)
  final mode = policy.resolve(sizeClass, formWeight: formWeight); // zcrud_navigation (EX-UI.5)
  final effective = presenter ?? ZFormPresenterScope.of(context); // seam (D5), défaut ZAdaptivePresenter
  return effective.present<T>(context, builder: builder, mode: mode,
      maxWidth: maxWidth, maxHeight: maxHeight, useSafeArea: useSafeArea);
}
```

C'est **exactement** la chaîne AD-30 (`largeur → ZWindowSizeClass → ZPresentationPolicy.resolve → ZEditionPresentation → ZFormPresenter → surface`) — le câblage **qu'aucune app ne fait**. `policy` et `presenter` restent **injectables** (défaut M3 + défaut pur-Flutter). Le helper est le **seul** endroit qui lie `context → largeur` **côté présentation** ; la politique reste pure.

### D7 — RTL / a11y (AD-13/NFR-U4)

Le présentateur n'introduit **aucun** `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`, `Positioned(left:/right:)` : il ne fait qu'ouvrir la surface — le contenu (`builder`) est directionnel par construction. Le `Dialog`/la bottom-sheet héritent de la `Directionality` ambiante (correct sous `TextDirection.rtl`). Cibles ≥ 48 dp et `Semantics` : à la charge du `builder`, mais **aucune** régression introduite. **Barrière** de dialog/sheet : `barrierDismissible`/`useSafeArea` exposés (a11y). Aucun secret (AD-12).

### D8 — `CORE OUT=0` intact : le seam est LOCAL, `ZcrudScope` inchangé

Voir Contexte + D5. Le présentateur/seam vit dans `zcrud_navigation` ; **aucune** écriture de `zcrud_core`/`zcrud_responsive`. Le graphe garde ses **2 arêtes sortantes** (`zcrud_navigation → zcrud_core`, `→ zcrud_responsive`), **0 entrante** ; `graph_proof.py` reste **ACYCLIQUE / CORE OUT=0**. **Aucun** nouveau package ⇒ **`pubspec.yaml` racine inchangé**, `melos list` **inchangé** (N stable — mesuré sur disque).

### D9 — Aucun codegen, aucune sérialisation (NFR-U11)

Widgets + fonctions purement présentationnels — **aucun** `@ZcrudModel`/`@JsonSerializable`. `melos run generate` reste **no-op** pour ce package, gate `codegen-distribution` **non concernée**.

---

## Acceptance Criteria

### AC1 — Port `ZFormPresenter` : abstrait, pluggable, jamais `sealed`, form-agnostique (D1/D2, AD-4/AD-30)
**Given** le besoin d'abstraire la présentation d'un formulaire,
**When** on définit `ZFormPresenter` dans `packages/zcrud_navigation/lib/src/presentation/z_form_presenter.dart`,
**Then** c'est un type **abstrait pluggable, JAMAIS `sealed`** (ni `final`) — une implémentation définie **hors du package** compile et se substitue (AD-4/NFR-U9),
**And** sa méthode est `Future<T?> present<T>(BuildContext context, {required WidgetBuilder builder, required ZEditionPresentation mode, double? maxWidth, double? maxHeight, bool useSafeArea, bool barrierDismissible})` — **form-agnostique** (aucune détection du type de formulaire ; l'heuristique `is EditionScreen` des apps est **supprimée**),
**And** le mode est **toujours** l'`enum ZEditionPresentation` (EX-UI.5) — **aucun** `bool fullscreenDialog`/`dialog` dans la signature (NFR-U7),
**And** le port vit sous **`presentation/`** (pas `domain/`) : `domain/` reste **100 % pur-Dart** (enums + politique EX-UI.5 **non modifiés**, aucun `import flutter` ajouté).

### AC2 — `ZAdaptivePresenter` : 3 surfaces en Flutter VANILLA, sans manager (D3, AD-30/AD-2/AD-15)
**Given** `class ZAdaptivePresenter implements ZFormPresenter` (`const` constructeur),
**When** `present()` reçoit `mode == page` / `sheet` / `dialog`,
**Then** il appelle **respectivement** `Navigator.of(context).push(MaterialPageRoute(builder: builder, fullscreenDialog: true))` / `showModalBottomSheet(context: context, isScrollControlled: true, …, builder: builder)` / `showDialog(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: …, child: builder(_))))` — **Flutter vanilla**,
**And** il n'importe **NI** `package:get/…` **NI** `go_router` **NI** aucun gestionnaire d'état ; **aucun** `Get.to`/`Get.bottomSheet`/`Get.dialog`, **aucun** `Get.width`/`Get.height`/`Get.context!` (NFR-U2/AD-15),
**And** le `switch` sur `mode` est **exhaustif** (3 branches) ⇒ **jamais de throw** (AD-10).

### AC3 — Tailles max explicites + retour de valeur via `Navigator.pop` (D2/D3/D4)
**Given** `maxWidth`/`maxHeight` fournis,
**When** le mode est `sheet` ou `dialog`,
**Then** ils sont appliqués via `BoxConstraints`/`ConstrainedBox` (le contenu ne dépasse pas ces bornes) ; s'ils sont `null`, un défaut est **dérivé de `MediaQuery.sizeOf(context)`** — **jamais** de `Get.width`/`Get.height` (NFR-U2) ; en mode `page` les tailles max sont **ignorées** (documenté),
**And** la valeur de retour `T?` remonte via `Navigator.pop(value)` (route/dialog) ou la fermeture de la bottom-sheet — `present()` **complète** son `Future` avec cette valeur (prouvé pour les 3 modes).

### AC4 — Seam `ZFormPresenterScope` local, défaut `ZAdaptivePresenter`, `ZcrudScope` intact (D5/D8, AD-6/AD-1)
**Given** le besoin de résoudre le présentateur effectif dans l'arbre,
**When** on définit `ZFormPresenterScope extends InheritedWidget` **dans `zcrud_navigation`** (`lib/src/presentation/`),
**Then** `ZFormPresenterScope.of(context)` renvoie le présentateur injecté **ou**, à défaut, `const ZAdaptivePresenter()` (défaut sûr, **jamais de throw**, AD-6/AD-10) ; `maybeOf` expose le lookup brut ; `updateShouldNotify` compare `presenter`,
**And** ⛔ **`ZcrudScope` de `zcrud_core` n'est PAS modifié** (aucun slot présentateur ajouté) — `zcrud_core` **ne gagne aucune** arête sortante (`CORE OUT=0` intact, AD-1) ; le seam présentateur est **local** au package de navigation.

### AC5 — Helper `presentEdition` : câble responsivité → politique → présentation (D6, AD-30 — le maillon vivant)
**Given** un `BuildContext` et un `WidgetBuilder`,
**When** on appelle `presentEdition<T>(context, builder: …, {formWeight, policy, presenter, maxWidth, maxHeight})`,
**Then** il (1) résout `ZWindowSizeClass.of(context)` via `zcrud_responsive`, (2) dérive `mode = policy.resolve(sizeClass, formWeight: formWeight)` via `ZPresentationPolicy` (EX-UI.5, défaut `const ZPresentationPolicy()`), (3) résout le présentateur effectif = `presenter ?? ZFormPresenterScope.of(context)`, (4) délègue à `present<T>(…, mode: mode, …)`,
**And** `policy` **et** `presenter` sont **injectables** (défauts fournis) — le helper est le **seul** point qui lie `context → largeur` côté présentation (la politique reste pure), matérialisant le câblage `largeur → breakpoint → mode → surface` qu'aucune app ne réalise (AD-30).

### AC6 — RTL / a11y / pas de manager (D7, AD-13/AD-2)
**Given** une présentation en `sheet` ou `dialog`,
**When** elle s'affiche sous `Directionality.rtl`,
**Then** la surface s'ouvre correctement, sans exception, directionnellement neutre (aucun `EdgeInsets.only(left:/right:)`/`Alignment.centerLeft/Right`/`TextAlign.left/right` introduit par le présentateur — AD-13/NFR-U4) ; `useSafeArea`/`barrierDismissible` exposés (a11y),
**And** `zcrud_navigation` n'importe toujours **NI `get` NI `go_router` NI `flutter_riverpod` NI `provider`** (grep négatif, NFR-U2/AD-15).

### AC7 — Barrel + graphe + gates verts, codegen no-op (AD-1/NFR-U1/NFR-U11)
**Given** le package `zcrud_navigation` après EX-UI.6,
**When** on met à jour le barrel et on rejoue les gates,
**Then** `lib/zcrud_navigation.dart` **exporte** les 4 fichiers neufs (`z_form_presenter.dart`, `z_adaptive_presenter.dart`, `z_form_presenter_scope.dart`, `present_edition.dart`) — en **plus** des 3 exports domaine EX-UI.5 (intacts) ; l'API publique reste centrée sur l'**enum** `ZEditionPresentation` (enums > bools, NFR-U7),
**And** le graphe garde **exactement 2 arêtes `zcrud_*` sortantes** (`→ zcrud_core`, `→ zcrud_responsive`) et **0 entrante** ; `graph_proof.py` reste **ACYCLIQUE / CORE OUT=0** ; **aucun** nouveau package ⇒ `pubspec.yaml` racine **inchangé**, `melos list` **inchangé** (N mesuré/consigné),
**And** `melos run generate` est un **no-op** pour ce package (aucun `@ZcrudModel`, NFR-U11), gate `codegen-distribution` **non concernée** ; `dart analyze packages/zcrud_navigation` **RC=0** (le dev fournit ce minimum ; `melos run analyze` **ET** `melos run verify` **repo-wide** délégués au gate de commit d'epic de l'orchestrateur).

---

## Tasks / Subtasks

- [ ] **T1 — Port `ZFormPresenter`** (AC1) — `lib/src/presentation/z_form_presenter.dart`
  - [ ] T1.1 `abstract interface class ZFormPresenter` (ou `abstract class` non-`sealed`/non-`final`) ; `import 'package:flutter/widgets.dart'` + `import '../domain/z_edition_presentation.dart'`.
  - [ ] T1.2 Méthode `Future<T?> present<T>(BuildContext context, {required WidgetBuilder builder, required ZEditionPresentation mode, double? maxWidth, double? maxHeight, bool useSafeArea = true, bool barrierDismissible = true})` + dartdoc (form-agnostique, jamais `sealed`, tailles explicites, mode = enum).

- [ ] **T2 — `ZAdaptivePresenter` (défaut pur-Flutter)** (AC2, AC3, AC6) — `lib/src/presentation/z_adaptive_presenter.dart`
  - [ ] T2.1 `class ZAdaptivePresenter implements ZFormPresenter { const ZAdaptivePresenter(); }`.
  - [ ] T2.2 `present()` : **switch exhaustif** sur `mode` → `page`/`sheet`/`dialog` via `Navigator.push(MaterialPageRoute(fullscreenDialog: true))` / `showModalBottomSheet` / `showDialog(Dialog+ConstrainedBox)`. **Aucun** `Get.*`, aucun routeur.
  - [ ] T2.3 Tailles max : appliquer `maxWidth`/`maxHeight` via `BoxConstraints`/`ConstrainedBox` ; défauts dérivés de `MediaQuery.sizeOf(context)` (fractions en **constantes nommées** internes). `page` ignore les tailles (dartdoc).
  - [ ] T2.4 Vérifier directionnalité (AD-13) : aucun helper non-directionnel introduit.

- [ ] **T3 — Seam `ZFormPresenterScope`** (AC4) — `lib/src/presentation/z_form_presenter_scope.dart`
  - [ ] T3.1 `class ZFormPresenterScope extends InheritedWidget { final ZFormPresenter presenter; … }`.
  - [ ] T3.2 `static ZFormPresenter of(BuildContext)` (défaut `const ZAdaptivePresenter()` si absent, jamais de throw) + `static ZFormPresenterScope? maybeOf(BuildContext)` + `updateShouldNotify`.
  - [ ] T3.3 ⛔ **Ne PAS** toucher `ZcrudScope`/`zcrud_core` (D8).

- [ ] **T4 — Helper `presentEdition`** (AC5) — `lib/src/presentation/present_edition.dart`
  - [ ] T4.1 `Future<T?> presentEdition<T>(BuildContext context, {required WidgetBuilder builder, ZFormWeight formWeight = ZFormWeight.light, ZPresentationPolicy policy = const ZPresentationPolicy(), ZFormPresenter? presenter, double? maxWidth, double? maxHeight, bool useSafeArea = true})`.
  - [ ] T4.2 Corps : `ZWindowSizeClass.of(context)` (zcrud_responsive) → `policy.resolve(sizeClass, formWeight:)` → `presenter ?? ZFormPresenterScope.of(context)` → `present<T>(…)`. Imports internes des enums/politique domaine + `zcrud_responsive`.

- [ ] **T5 — Barrel** (AC7) — `lib/zcrud_navigation.dart`
  - [ ] T5.1 Ajouter `export 'src/presentation/z_form_presenter.dart';`, `z_adaptive_presenter.dart`, `z_form_presenter_scope.dart`, `present_edition.dart` (après les 3 exports domaine EX-UI.5, **sans** les réordonner). Mettre à jour le dartdoc de barrel (EX-UI.6 : port + présentateur pur-Flutter + seam + helper).

- [ ] **T6 — Tests widget** (AC1..AC6) — `packages/zcrud_navigation/test/`
  - [ ] T6.1 `z_adaptive_presenter_test.dart` : sous `MaterialApp`, un bouton déclenche `const ZAdaptivePresenter().present(context, builder: …, mode: X)` — **3 cas** :
    - `page` → une **nouvelle route** est poussée (`find` le widget du builder sur une route distincte ; vérifier via `Navigator`/pump que l'écran d'accueil n'est plus au sommet) ;
    - `sheet` → `find.byType(BottomSheet)` (ou le contenu du builder dans une modale) **présent** ;
    - `dialog` → `find.byType(Dialog)` **présent** + contenu du builder trouvé.
  - [ ] T6.2 **Retour de valeur** : pour chaque mode, `Navigator.pop(ctx, valeur)` (ou close de la sheet) → le `Future` de `present()` **complète** avec la valeur attendue.
  - [ ] T6.3 **Contraintes de taille** : `dialog` avec `maxWidth: 400` → `find` un `ConstrainedBox`/`BoxConstraints` portant `maxWidth == 400` (ou la largeur rendue ≤ 400) ; `sheet` avec `maxHeight` → contrainte appliquée.
  - [ ] T6.4 **RTL** : rejouer un mode (`dialog`/`sheet`) sous `Directionality(textDirection: TextDirection.rtl, …)` / locale RTL → la surface s'ouvre sans exception.
  - [ ] T6.5 `z_form_presenter_scope_test.dart` : (a) `ZFormPresenterScope.of` **sans** scope → renvoie un `ZAdaptivePresenter` (défaut) ; (b) avec un `_RecordingPresenter` (impl **externe** du port — prouve **non-`sealed`**, AC1) injecté via `ZFormPresenterScope(presenter: …)`, `presentEdition` l'utilise (le fake enregistre le `mode` reçu).
  - [ ] T6.6 `present_edition_test.dart` : le helper **dérive le bon mode selon la largeur** — sous `MediaQuery` de largeur `< 600` → `sheet` ouverte ; `600..839` → `dialog` ; `≥ 840` + `formWeight: light` → `dialog` ; `≥ 840` + `heavy` → `page`. (Utiliser un `_RecordingPresenter` injecté pour **capter le `mode`** sans dépendre du rendu, **et/ou** asserter la surface réelle.)
  - [ ] T6.7 (garde-fou) test/analyse : aucun `import 'package:get/…'`/`go_router` dans le package (grep négatif — peut être un simple test de convention ou vérifié à l'analyse).

- [ ] **T7 — Vérif verte + graphe** (AC7)
  - [ ] T7.1 `melos run generate` → SUCCESS (no-op pour `zcrud_navigation`).
  - [ ] T7.2 `dart analyze packages/zcrud_navigation` **RC=0** (0 issue). `melos run analyze`/`verify` **repo-wide** délégués à l'orchestrateur.
  - [ ] T7.3 `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE / CORE OUT=0** (2 arêtes sortantes inchangées).
  - [ ] T7.4 `flutter test packages/zcrud_navigation` → tous verts (nb consigné ; inclut les tests EX-UI.5 + les nouveaux widget tests).
  - [ ] T7.5 `dart run melos list` = **N inchangé** (aucun nouveau package ; consigner N).

---

## Dev Notes

### Fichiers à créer / modifier (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_navigation/lib/src/presentation/z_form_presenter.dart` | **NEW** — port abstrait non-`sealed` (importe flutter + `ZEditionPresentation`) |
| `packages/zcrud_navigation/lib/src/presentation/z_adaptive_presenter.dart` | **NEW** — défaut pur-Flutter (Navigator/showModalBottomSheet/showDialog) |
| `packages/zcrud_navigation/lib/src/presentation/z_form_presenter_scope.dart` | **NEW** — seam `InheritedWidget` local, défaut `ZAdaptivePresenter` |
| `packages/zcrud_navigation/lib/src/presentation/present_edition.dart` | **NEW** — helper câblage responsivité→politique→présentation |
| `packages/zcrud_navigation/lib/zcrud_navigation.dart` | **UPDATE** — +4 exports `src/presentation/…` (dartdoc EX-UI.6) |
| `packages/zcrud_navigation/test/z_adaptive_presenter_test.dart` | **NEW** — 3 surfaces + retour valeur + tailles + RTL |
| `packages/zcrud_navigation/test/z_form_presenter_scope_test.dart` | **NEW** — défaut + substitution (impl externe = non-`sealed`) |
| `packages/zcrud_navigation/test/present_edition_test.dart` | **NEW** — dérivation du mode par la largeur |

⛔ **NE PAS TOUCHER** : `packages/zcrud_core/**` (surtout **PAS** `ZcrudScope` — D8/AD-1), `packages/zcrud_responsive/**` (consommés), `lib/src/domain/**` de `zcrud_navigation` (enums + politique EX-UI.5 **intacts**), `pubspec.yaml` racine (aucun nouveau package), `melos.yaml`. ⛔ **NE PAS CRÉER** ici de présentateur GetX/go_router (= EX-UI.11 / bindings).

### Invariants AD applicables (rappel ciblé)

- **AD-30 (delta)** : présentateur par défaut **pur-Flutter** (`Navigator`/`showModalBottomSheet`/`showDialog`), **form-agnostique** ; port **pluggable jamais `sealed`** ; présentateurs manager = **bindings** ; résolution par **seam**, défaut = pur-Flutter. Le helper `presentEdition` **matérialise** `breakpoint → mode → surface`.
- **AD-4 / NFR-U9** : `ZFormPresenter` **jamais `sealed`** — prouvé par une impl **externe** (fake de test) qui compile et se substitue.
- **AD-6** : présentateur effectif résolu par **seam** (`ZFormPresenterScope` local), **défaut sûr** `ZAdaptivePresenter` (jamais de throw).
- **AD-2 / AD-15 / NFR-U2** : **aucun** `get`/`go_router`/`flutter_riverpod`/`provider` ; aucun `Get.width`/`Get.height` — mesure via `MediaQuery.sizeOf`/`BuildContext` explicite.
- **AD-1 / NFR-U1** : `ZcrudScope` de `zcrud_core` **inchangé** ; 2 arêtes sortantes, 0 entrante ; `CORE OUT=0` ; graphe acyclique ; `pubspec` racine et `melos list` inchangés.
- **AD-13 / NFR-U4** : directionnel (RTL), `Semantics`/≥ 48 dp côté contenu, aucun helper non-directionnel introduit par le présentateur.
- **AD-10 / NFR-U10** : `switch` exhaustif sur `mode` (jamais de throw) ; seam à défaut sûr.
- **AD-5 / AD-14** : `domain/` **reste pur** (D1) — le port/présentateur (qui exigent `BuildContext`) vivent sous `presentation/`.
- **AD-12 / NFR-U8** : zéro secret ; jamais `badCertificateCallback => true`.
- **NFR-U7 (enums > bools)** : le mode reste `ZEditionPresentation` ; seuls `useSafeArea`/`barrierDismissible` (prédicats binaires stricts, options natives) subsistent en `bool` — exception admise.
- **NFR-U11** : pas de codegen — `melos run generate` no-op.

### Project Structure Notes

- EX-UI.6 **peuple `lib/src/presentation/`** (créé vide/absent en EX-UI.5). Le package suit `lib/<pkg>.dart` (barrel) + `lib/src/{domain,presentation}` : `domain/` (pur, EX-UI.5) + `presentation/` (UI, EX-UI.6).
- **Écart assumé vs Structural Seed** (D1) : le seed place `port ZFormPresenter` sous `domain/` ; il est placé sous `presentation/` car il exige `BuildContext`/`WidgetBuilder` (impossible en domaine pur — AD-5/AD-14, D7 d'EX-UI.5). À signaler en Completion Notes.
- **Aucun** ajout de déclaration hors package (pas de nouveau package → `pubspec.yaml` racine et `melos.yaml` intacts).

### Dépendances aval (ce que cette story débloque)

`done` sur EX-UI.6 débloque **EX-UI.11** (binding GetX) : `ZGetFormPresenter implements ZFormPresenter` (`Get.to`/`Get.bottomSheet`/`Get.dialog`) dans `zcrud_get`, enregistré via un scope de binding — prouvant la **pluggabilité** du port (AD-4/AD-30). Le présentateur go_router (`zcrud_riverpod`) reste **déféré** (DW-EXUI-2).

### References

- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § **AD-30** (l.94-97 : présentateur par défaut pur-Flutter `Navigator.push(MaterialPageRoute(fullscreenDialog:))`/`showModalBottomSheet`/`showDialog`, form-agnostique, port `ZFormPresenter` jamais `sealed`, présentateurs manager dans les bindings, résolution par seam défaut pur-Flutter) ; § Consistency Conventions « Présentation » (l.117), « Enums > booléens » (l.118), « Pureté & seams » (l.119), « RTL / a11y » (l.120) ; § Structural Seed (l.146-150 : `zcrud_navigation` presentation = `ZAdaptivePresenter`) ; § Câblage mermaid (l.161-169 : `ZEditionPresentation → ZFormPresenter (seam) → défaut ZAdaptivePresenter / binding manager`) ; § Notes migration Présentation (l.201)]
- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.6 (l.270-300) — ACs, réécriture GetX→Flutter, sources `showPushedDialog` ; § Capability→Story Map (l.67, EX-UI.6 = port + présentateur) ; § Séquencement (l.84-85, l.99-100 : EX-UI.5 précède EX-UI.6 précède EX-UI.11)]
- [Source: `packages/zcrud_navigation/lib/src/domain/z_edition_presentation.dart` (enum `{ page, sheet, dialog }`, ENTRÉE de `present`), `z_form_weight.dart` (enum `{ light, heavy }`), `z_presentation_policy.dart` (`resolve(ZWindowSizeClass, {ZFormWeight}) → ZEditionPresentation`, défaut `const ZPresentationPolicy()`) ; `packages/zcrud_navigation/lib/zcrud_navigation.dart` (barrel — 3 exports domaine EX-UI.5 à préserver)]
- [Source: `packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart` (`ZWindowSizeClass.of(BuildContext)` via `MediaQuery.sizeOf` — mesure du contexte pour le helper `presentEdition`)]
- [Source: `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (`ZcrudScope extends InheritedWidget`, bundle fixe de seams, AUCUN slot présentateur — **modèle** d'`InheritedWidget` zéro-dépendance à répliquer localement ; **NE PAS** y ajouter le présentateur → `CORE OUT=0`, D8)]
- [Source: `packages/zcrud_navigation/pubspec.yaml` (`zcrud_core: ^0.2.0` + `zcrud_responsive: ^0.2.0` + `flutter` — dépendances suffisantes, aucun ajout requis)]
- [Source (LECTURE SEULE, best-of-breed à réécrire) : `scratchpad/explore/dodlp.md` §Capacité 1 (`showPushedDialog` ~331-394, 3 modes, couplage GetX fort) ; `scratchpad/explore/iffd.md` §Capacité 2 (`forms_utils.dart:631-739`, essai commenté `showModalBottomSheet` natif l.684-737, `dialog: AppPlatform.isWebOrDesktop` au call-site)]
- [Source: `_bmad-output/implementation-artifacts/stories/ex-ui-5-edition-presentation-policy.md` (D7 : `domain/` pur-Dart sans `import flutter` — fonde D1 ; symboles domaine consommés) ; `CLAUDE.md` — Key Don'ts (AD-1/AD-2/AD-4/AD-13), variantes directionnelles, `ListView.builder`]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Widget** (`MaterialApp`) | `present(mode: page)` → nouvelle route ; `sheet` → `BottomSheet` présent ; `dialog` → `Dialog` présent | AC2 |
| **Widget** | `Navigator.pop(value)` / close sheet → `Future` de `present()` complète avec la valeur (3 modes) | AC3 |
| **Widget** | `maxWidth`/`maxHeight` → `ConstrainedBox`/`BoxConstraints` appliqués ; défaut via `MediaQuery.sizeOf` | AC3 |
| **Widget (RTL)** | `dialog`/`sheet` sous `Directionality.rtl` → surface ouverte sans exception | AC6 |
| **Widget** | seam absent → `of()` = `ZAdaptivePresenter` ; impl **externe** injectée via scope → utilisée (non-`sealed`) | AC1, AC4 |
| **Widget** | `presentEdition` : largeur `<600`→`sheet`, `600..839`→`dialog`, `≥840`+`light`→`dialog`, `≥840`+`heavy`→`page` | AC5 |
| **Convention / analyse** | grep négatif `get`/`go_router` ; `graph_proof` ACYCLIQUE / CORE OUT=0 ; `generate` no-op ; `melos list` inchangé | AC6, AC7 |

**Definition of Done** : AC1→AC7 verts · port `ZFormPresenter` **abstrait non-`sealed`** (impl externe de test compile et se substitue) · `ZAdaptivePresenter` **Flutter vanilla** (Navigator/showModalBottomSheet/showDialog, **aucun** `Get.*`/routeur) · tailles max explicites + retour de valeur via `Navigator.pop` prouvés (3 modes) · seam `ZFormPresenterScope` **local** à défaut `ZAdaptivePresenter`, **`ZcrudScope` inchangé** (`CORE OUT=0`) · helper `presentEdition` dérive le mode par la largeur (4 cas) · **RTL** vérifié · `lib/src/domain/**` (EX-UI.5) **non modifié** · barrel +4 exports · `melos run generate` no-op + `dart analyze` RC=0 (repo-wide délégué à l'orchestrateur) · `graph_proof` ACYCLIQUE/CORE OUT=0 · `pubspec` racine + `melos list` inchangés · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
