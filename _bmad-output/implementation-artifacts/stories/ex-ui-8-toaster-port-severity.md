---
baseline_commit: 9e405a09bf25c136a8bdfb94d1d383d7c98452b5
---

# Story EX-UI.8 : Port `ZToaster` + `enum ZToastSeverity` + implémentation par défaut pur-Flutter `ZScaffoldMessengerToaster` + seam `ZToasterScope`

Status: review

- **Clé sprint-status** : `ex-ui-8-toaster-port-severity`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit)
- **Taille** : **M** (package DÉJÀ livré `zcrud_ui_kit` : +1 enum domaine + 1 port abstrait + 1 impl défaut pur-Flutter + 1 seam `InheritedWidget` + helper `zToast` ; 0 codegen, 0 entité persistée)
- **Parallélisation** : **PARALLÉLISABLE (P3 ∥ P2, ≤ 3 avec EX-UI.9/10)** — package `zcrud_ui_kit`, fichiers **neufs** disjoints ; **indépendant de P1**. ⚠️ **Étend le barrel/pubspec** partagé avec EX-UI.7 (livré) / EX-UI.9 / EX-UI.10 ⇒ ces stories **sérialisées entre elles** (barrel séquentiel), même si le package est parallélisable vis-à-vis de P2. **Précède EX-UI.11** (le binding `zcrud_get` implémente le port `ZToaster`).
- **Package écrit (disjoint)** : `packages/zcrud_ui_kit/` **UNIQUEMENT** (fichiers neufs + 4 lignes d'`export` dans le barrel `lib/zcrud_ui_kit.dart`). ⛔ **N'ÉCRIT PAS `zcrud_core`** (ni aucun autre `zcrud_*`) — il **le CONSOMME** (`ZcrudScope`/`ZcrudTheme` injectés). ⛔ **NE TOUCHE PAS** `pubspec.yaml` (dépendances déjà OK depuis EX-UI.7), ni `pubspec.yaml` racine (package déjà déclaré au `workspace:`), ni `melos.yaml`.
- **AD delta** : **AD-32** (patterns génériques UI — **toast par PORT** : `ZToaster` défini dans `zcrud_ui_kit`, impls concrètes GetX/`toastification`/`ScaffoldMessenger` dans les bindings ou fournies par l'app via seam AD-6/AD-15), **AD-29** (paquet UI pur — dépend de `zcrud_core` + flutter). **AD hérités** : **AD-1** (acyclique, `CORE OUT=0` — l'arête `zcrud_ui_kit → zcrud_core` est **ENTRANTE au cœur**, licite), **AD-4** (port extensible, **jamais `sealed`**), **AD-6** (résolution du toaster effectif par **seam**, défaut sûr), **AD-2/AD-15** (Flutter-native, **AUCUN gestionnaire d'état**), **AD-13** (RTL / a11y / thème & couleurs injectés : `SnackBarAction` ≥ 48 dp, `Semantics`, couleur jamais seul canal), **AD-10** (défauts sûrs), **AD-12** (zéro secret). **Consigne transverse NFR-U7** : *enums > booléens* (`ZToastSeverity` remplace un `bool isError`/`String` libre).

---

## Story

**As a** développeur intégrateur consommant `zcrud` (dodlp, iffd, lex, …),
**I want** un **port de notification** `ZToaster` typé par un **`enum ZToastSeverity { info, success, warning, error }`**, une **implémentation par défaut pur-Flutter** `ZScaffoldMessengerToaster` (mappe la sévérité sur une `SnackBar` dont la couleur est **dérivée du `ColorScheme`**), et un **seam** (`ZToasterScope` `InheritedWidget` local + helper `zToast(...)`) permettant à une app de substituer son propre toaster,
**so that** j'affiche un toast **sans coupler un package pur à GetX / `toastification`** — la sévérité étant un **enum nommé** (jamais un `bool isError` ni un `String` libre), le port restant **pluggable et non `sealed`** (les impls manager vivent dans les bindings/app), et la couleur **jamais codée en dur** (toujours dérivée du `ColorScheme` courant, dark-mode-aware).

---

## Contexte — vérifié sur disque (pas sur la seule foi de l'épic)

### État réel du package `zcrud_ui_kit` (livré en EX-UI.7, `review`)

Vérifié sur disque :
- `packages/zcrud_ui_kit/pubspec.yaml` : `name: zcrud_ui_kit`, `version: 0.2.0`, `publish_to: none`, `resolution: workspace`, `sdk: ^3.12.2`, `dependencies` = **`zcrud_core: ^0.2.0` + `flutter`** UNIQUEMENT, `dev_dependencies` = `flutter_test`. ⛔ **AUCUNE modification requise** (le port et l'impl par défaut n'ajoutent aucune dépendance — pas de `toastification`, pas de manager).
- Barrel `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (`library;`) : exporte déjà `z_confirm_tone.dart`, `z_content_state.dart`, `z_confirm_dialog.dart`, `z_state_widgets.dart`. ⇒ EX-UI.8 **ajoute** les `export` de ses 4 nouveaux fichiers (ordre alphabétique, comme l'existant) et **complète le dartdoc de barrel** d'un paragraphe EX-UI.8. ⛔ Ne PAS ré-exporter `zcrud_core` (règle D7 d'EX-UI.7 conservée).
- Arbo existante : `lib/src/domain/` (`z_confirm_tone.dart`, `z_content_state.dart`) + `lib/src/presentation/` (`z_confirm_dialog.dart`, `z_state_widgets.dart`). EX-UI.8 y **ajoute** ses fichiers.
- Le package est **déjà déclaré** au bloc `workspace:` du `pubspec.yaml` racine (ligne ajoutée par EX-UI.7) ⇒ **rien à ajouter** ; `melos list` reste à sa valeur courante (pas de N→N+1 ici : aucun nouveau package).

### Ce que `zcrud_core` EXPOSE DÉJÀ (à CONSOMMER, jamais redéclarer)

Vérifié dans `packages/zcrud_core/lib/zcrud_core.dart` (barrel) et sur disque :

| Symbole `zcrud_core` | Fichier | Usage EX-UI.8 |
|---|---|---|
| `ZcrudTheme.of(context)` (`ThemeExtension`, `z_theme.dart:295`) | `src/presentation/theme/z_theme.dart` | Résout les couleurs sémantiques : `ZcrudScope.theme` → repli `ZcrudTheme.fallback(Theme.of(context))`. Expose `errorColor` (`:90`), `surfaceColor` (`:96`), `labelColor`, `fieldBorderColor` — **tous `Color?`** dérivés du `ColorScheme`, **aucun hex**. |
| `ZcrudScope` / `ZcrudScope.maybeOf(context)` | `src/presentation/zcrud_scope.dart` | Seam d'injection thème/labels (lecture optionnelle). |
| `ZcrudLocalizations.maybeOf(context)` | `src/presentation/l10n/z_localizations.dart` | l10n injectée (repli défensif, cf. `ZLoadingState`). |

⚠️ **`ZcrudTheme` n'a PAS de slot `successColor`/`warningColor`/`infoColor`** (vérifié : seuls `errorColor`/`surfaceColor`/`labelColor`/`fieldBorderColor`). ⇒ le mapping sévérité→couleur doit **dériver** `info`/`success`/`warning` de **rôles `ColorScheme`** existants (cf. D3), jamais inventer un hex.

### Patrons internes DÉJÀ établis (EX-UI.7, à réutiliser — cohérence)

- **Couleur d'erreur dérivée** (`z_state_widgets.dart:156`) : `ZcrudTheme.of(context).errorColor ?? Theme.of(context).colorScheme.error`. ⇒ **même idiome** pour la sévérité `error` du toaster.
- **A11y défensif** (`z_state_widgets.dart:89-92`) : libellé via `maybeOf`/`maybeResolve` en cascade, jamais `.of()` qui lève, jamais `Semantics.label` nul.
- **Cible tactile ≥ 48 dp** (`_kMinTouchTarget = 48`, `z_confirm_dialog.dart:15`, `z_state_widgets.dart:17`) : appliquer à `SnackBarAction` (via `minimumSize`/padding, cf. D3).
- **Enum UI-pur non sérialisé** (`z_confirm_tone.dart`, `z_content_state.dart`) : valeurs camelCase, **aucun `@JsonKey`/`.g.dart`**, dartdoc « enums > booléens ». ⇒ `ZToastSeverity` suit exactement ce patron.
- **Barrel** exporte `src/...`, ne ré-exporte pas `zcrud_core`.

### Best-of-breed à NEUTRALISER (LECTURE SEULE — apps hors périmètre, ne PAS copier)

- **dodlp** `lib/src/utils/services/toast_service.dart` (~75 LOC) : `ToastService.showErrorToast` / `showSuccessToast` / `showInfoToast`. **Couplage GetX fort** (`Get.showSnackbar` / `GetSnackBar`). **À neutraliser** : (1) remplacer les 3 méthodes ad hoc par **1 méthode `show(...)` paramétrée par `ZToastSeverity`** (les 3 méthodes = 3 valeurs d'un enum — cas d'école « enums > booléens ») ; (2) remplacer `Get.showSnackbar` par `ScaffoldMessenger.of(context).showSnackBar` (Flutter vanilla) ; (3) couleurs dérivées du `ColorScheme` (jamais les constantes d'app). La variante **GetX** (`Get.showSnackbar`) deviendra une **impl de port dans `zcrud_get`** — **EX-UI.11, HORS PÉRIMÈTRE ICI**.

### ⛔ Hors périmètre (défini par d'autres stories — NE PAS implémenter ici)

- **EX-UI.9** — `ZDiscardChangesGuard` (garde dirty du `ZFormController`).
- **EX-UI.10** — `ZAlphabetIndexBar` (index alphabétique cliquable) + transitions de route RTL-aware.
- **EX-UI.11** — impls **GetX** du port (`ZGetToaster` via `Get.showSnackbar`) dans `zcrud_get`, et présentateur GetX. Le task d'EX-UI.8 mentionne « guard=EX-UI.9, index/transitions=EX-UI.10 hors périmètre » et « impls GetX/toastification vivent dans les bindings/app ». **Cette story livre le PORT + le SEAM + l'impl PAR DÉFAUT pur-Flutter uniquement.**

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — Aucune nouvelle dépendance (AD-29 ; AUCUN manager, AUCUN tiers)

`pubspec.yaml` **inchangé** : `zcrud_core: ^0.2.0` + `flutter` suffisent. ⛔ **AUCUN** `toastification`, `get`, `flutter_riverpod`, `provider`, `go_router`, `dartz`. Le port + l'impl `ScaffoldMessenger` + le seam sont du **Flutter pur**. L'arête reste `zcrud_ui_kit → zcrud_core` (entrante au cœur, `CORE OUT=0` intact, `graph_proof.py` ACYCLIQUE — **inchangé** par EX-UI.8).

### D2 — `enum ZToastSeverity { info, success, warning, error }` (domaine, camelCase, NON sérialisé)

Fichier `lib/src/domain/z_toast_severity.dart`. Valeurs **camelCase** (`info`, `success`, `warning`, `error`). C'est l'**unique** modélisation de la sévérité d'un toast — elle **remplace** les 3 méthodes ad hoc de dodlp (`showError`/`showSuccess`/`showInfo`) et tout `bool isError`/`String` libre (NFR-U7 « enums > booléens », AD-32). **UI-pure, non persistée** ⇒ **aucun `@ZcrudModel`/`@JsonSerializable`/`@JsonKey`, aucun `.g.dart`** (D6). Dartdoc calqué sur `z_confirm_tone.dart` (intention nommée, couleur dérivée par le widget). Ordre proposé : `info, success, warning, error` (sévérité croissante — dartdoc peut le noter, mais **aucune** dépendance à l'`index` n'est requise).

### D3 — PORT `ZToaster` : `abstract interface class`, JAMAIS `sealed` (AD-4)

Fichier `lib/src/domain/z_toaster.dart`. **`abstract interface class ZToaster`** (⛔ **jamais `sealed`** — AD-4/NFR-U9 : une app/binding doit pouvoir l'implémenter **sans modifier** `zcrud_ui_kit`). Contrat (signature de référence — le dev ajuste si le code l'impose, en gardant `severity` un `ZToastSeverity` et **aucun** `bool` multi-état) :

```dart
abstract interface class ZToaster {
  void show(
    BuildContext context, {
    required String message,
    ZToastSeverity severity = ZToastSeverity.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  });
}
```

- `severity` par défaut `info` (défaut sûr, AD-10). `duration` optionnel → l'impl choisit un défaut sûr (ex. `SnackBar` par défaut). `actionLabel` + `onAction` optionnels (action facultative). Le port **prend un `BuildContext`** (les impls `ScaffoldMessenger`/GetX en ont besoin) — c'est un **port de présentation**, pas un pur domaine (contrairement à `ZPresentationPolicy`) : il vit sous `domain/` comme **contrat** (comme il est classé dans le Structural Seed « `domain/ : port ZToaster` »), l'impl sous `presentation/`.
- ⛔ **Le port ne fait AUCUNE hypothèse manager** (pas de `Get.context`, pas de `ScaffoldMessengerState` en champ) : il reçoit le `context` à l'appel.

### D4 — IMPL PAR DÉFAUT `ZScaffoldMessengerToaster implements ZToaster` (pur-Flutter, couleur dérivée)

Fichier `lib/src/presentation/z_scaffold_messenger_toaster.dart`. **`class ZScaffoldMessengerToaster implements ZToaster`** — `const` constructeur (immuable, AD-13). `show(...)` → `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` — **Flutter vanilla, AUCUN gestionnaire d'état** (AD-2/AD-15), aucun `Get.showSnackbar`.

**Mapping sévérité → (couleur, icône) — couleur TOUJOURS dérivée du `ColorScheme`, JAMAIS de hex :**

- `error` → `ZcrudTheme.of(context).errorColor ?? scheme.error` (même idiome qu'EX-UI.7) ; icône `Icons.error_outline`.
- `info` → rôle `ColorScheme` (proposition : `scheme.primary` ou `scheme.inverseSurface`) ; icône `Icons.info_outline`.
- `success` → rôle `ColorScheme` (proposition : `scheme.tertiary` ; à défaut `scheme.primary`) ; icône `Icons.check_circle_outline`.
- `warning` → rôle `ColorScheme` (proposition : `scheme.secondary` ou `scheme.tertiary`) ; icône `Icons.warning_amber_outlined`.

⚠️ **Justification obligatoire** : `ZcrudTheme`/M3 n'ont **pas** de slot `success`/`warning`/`info` (vérifié D-contexte). Le dev **choisit un mapping déterministe et documenté** sur des rôles `ColorScheme` existants (ci-dessus = proposition), le consigne dans le dartdoc, et **n'introduit AUCUN littéral hex ni `Colors.<x>`**. La couleur teinte soit le fond de la `SnackBar` (avec texte/icône lisibles via le rôle `on*` correspondant), soit un accent (icône + éventuel `SnackBarThemeData`) — le dev tranche la lisibilité (contraste on-color) et le teste (light + dark).

**A11y / directionnel (AD-13, NON-NÉGOCIABLES) :**
- **Couleur jamais seul canal** : la `SnackBar` porte **une icône de sévérité + le texte** (`content` = `Row`/`Text` directionnel). La sévérité est perceptible sans la couleur.
- **`Semantics`** : le contenu de la `SnackBar` annonce le message (repli défensif si besoin, jamais un label nul).
- **`SnackBarAction`** (si `actionLabel` + `onAction` fournis) : cible tactile **≥ 48 dp** (réutiliser l'idiome `_kMinTouchTarget = 48`).
- **Directionnel** : `EdgeInsetsDirectional`, pas de `EdgeInsets.only(left:/right:)` ; `TextAlign.start`.
- Couleurs/labels **injectés** (l10n : les textes viennent de l'appelant ; `SnackBarAction.label` = `actionLabel` fourni) — aucune chaîne métier en dur.

### D5 — SEAM : `ZToasterScope` (`InheritedWidget` local) + helper `zToast(...)` (AD-6)

Fichier `lib/src/presentation/z_toaster_scope.dart`. Permet à une app de **substituer** son toaster (GetX/`toastification`) **sans** que `zcrud_ui_kit` ne les importe (AD-6/AD-15).

- **`class ZToasterScope extends InheritedWidget`** : champ `final ZToaster toaster;` ; `static ZToaster? maybeOf(BuildContext)` (lecture optionnelle) ; `static ZToaster of(BuildContext)` → `maybeOf(context) ?? const ZScaffoldMessengerToaster()` (**défaut sûr** — jamais de throw, AD-10 : si aucun scope monté, on retombe sur l'impl pur-Flutter). `updateShouldNotify` = `oldWidget.toaster != toaster`.
- **`void zToast(BuildContext context, String message, { ZToastSeverity severity = ZToastSeverity.info, Duration? duration, String? actionLabel, VoidCallback? onAction })`** : helper de convenance qui **résout** le toaster via `ZToasterScope.of(context)` puis délègue à `toaster.show(context, message: message, severity: severity, ...)`. C'est le point d'entrée « une ligne » pour les écrans.
- ⛔ Le seam est **local** (`InheritedWidget` de `zcrud_ui_kit`), zéro-dépendance manager. Il ne remplace pas `ZcrudScope` (thème) — il porte spécifiquement le toaster.

### D6 — Aucun codegen, aucune sérialisation (NFR-U11)

`ZToastSeverity`, `ZToaster`, `ZScaffoldMessengerToaster`, `ZToasterScope`, `zToast` sont **UI-pure**, **non persistés** → **aucun `@ZcrudModel`/`@JsonSerializable`/`part`** ⇒ pas de `*.g.dart`, `melos run generate` **no-op** pour ce package, gate `codegen-distribution` **non concernée**. **Confirmer** le no-op au 1er `melos run generate` (AC7).

### D7 — Barrel = SEULE API publique (extension de l'existant)

`lib/zcrud_ui_kit.dart` **ajoute** (ordre alphabétique parmi les exports existants) : `export 'src/domain/z_toast_severity.dart';`, `export 'src/domain/z_toaster.dart';`, `export 'src/presentation/z_scaffold_messenger_toaster.dart';`, `export 'src/presentation/z_toaster_scope.dart';` + un paragraphe dartdoc EX-UI.8. ⛔ **Ne PAS** ré-exporter `zcrud_core`. ⛔ **Ne PAS** retirer/réordonner les exports EX-UI.7.

---

## Acceptance Criteria

### AC1 — `enum ZToastSeverity { info, success, warning, error }` (camelCase) — remplace bool/String
**Given** le besoin de qualifier un toast,
**When** on définit `enum ZToastSeverity { info, success, warning, error }` (`lib/src/domain/z_toast_severity.dart`, valeurs **camelCase**),
**Then** c'est l'**unique** modélisation de sévérité exposée — **aucun** `bool isError` ni `String` libre dans l'API publique (NFR-U7 « enums > booléens », AD-32),
**And** l'enum est **UI-pure**, **non sérialisé** (D2/D6) ⇒ **pas de `@JsonKey`**, pas de `.g.dart`, dartdoc « enums > booléens ».

### AC2 — PORT `ZToaster` : `abstract interface class`, JAMAIS `sealed` (AD-4)
**Given** le besoin d'abstraire la notification,
**When** on définit `ZToaster` (`lib/src/domain/z_toaster.dart`) avec `void show(BuildContext context, {required String message, ZToastSeverity severity = ZToastSeverity.info, Duration? duration, String? actionLabel, VoidCallback? onAction})` (ou signature équivalente gardant `severity` en `ZToastSeverity`),
**Then** c'est une **interface abstraite** (`abstract interface class`) **jamais `sealed`** (AD-4/NFR-U9) — une impl **externe** au package compile sans modifier `zcrud_ui_kit`,
**And** la sévérité par défaut est `ZToastSeverity.info` (défaut sûr, AD-10), et **aucun** `bool` multi-état n'apparaît dans la signature.

### AC3 — IMPL PAR DÉFAUT `ZScaffoldMessengerToaster` : `ScaffoldMessenger`, couleur dérivée, sans manager
**Given** aucun toaster fourni par l'app,
**When** on appelle `ZScaffoldMessengerToaster().show(context, message:..., severity:...)` (`lib/src/presentation/z_scaffold_messenger_toaster.dart`),
**Then** il affiche une `SnackBar` via **`ScaffoldMessenger.of(context).showSnackBar`** — **Flutter vanilla, AUCUN gestionnaire d'état** (AD-2/AD-15), aucun `Get.showSnackbar`,
**And** la couleur de chaque sévérité est **dérivée du `ColorScheme`** courant (`error` → `ZcrudTheme.of(context).errorColor ?? scheme.error` ; `info`/`success`/`warning` → rôles `ColorScheme` documentés) — ⛔ **AUCUN** littéral hex, ⛔ **AUCUN** `Colors.<sémantique>`, dark-mode-aware (s'adapte au `Brightness`),
**And** la sévérité est portée par **une icône + le texte** (couleur **jamais** seul canal, WCAG/AD-13/NFR-U4) ; le message (texte) est toujours présent.

### AC4 — Action + a11y sur la `SnackBar` (AD-13)
**Given** un `actionLabel` + `onAction` fournis,
**When** la `SnackBar` s'affiche,
**Then** elle expose un **`SnackBarAction`** (label = `actionLabel`) déclenchant `onAction`, avec une cible tactile **≥ 48 dp**,
**And** la `SnackBar` porte des `Semantics` annonçant le message ; le rendu est **directionnel** (`EdgeInsetsDirectional`/`TextAlign.start`, ⛔ jamais `left`/`right`) et correct sous `Directionality.rtl`,
**And** sans `actionLabel`/`onAction`, aucune action n'est ajoutée (repli sûr).

### AC5 — SEAM `ZToasterScope` + `zToast(...)` : substitution sans import manager, défaut sûr (AD-6)
**Given** une app voulant son propre toaster (GetX/`toastification`),
**When** elle monte `ZToasterScope(toaster: MonToasterCustom(), child: ...)` et qu'un descendant appelle `zToast(context, 'msg', severity: ...)`,
**Then** `zToast` résout le toaster via **`ZToasterScope.of(context)`** et délègue à `toaster.show(...)` — le toaster **custom** est appelé, **sans** que `zcrud_ui_kit` n'importe aucun manager/tiers (AD-6/AD-15),
**And** **sans** `ZToasterScope` monté, `ZToasterScope.of(context)` retombe sur **`const ZScaffoldMessengerToaster()`** (défaut sûr — **jamais de throw**, AD-10),
**And** `ZToasterScope.updateShouldNotify` ne notifie que si le `toaster` change.

### AC6 — Pluggabilité prouvée : un `ZToaster` factice externe (AD-4/NFR-U9)
**Given** le port non-`sealed`,
**When** un test définit un `class _FakeToaster implements ZToaster` (hors des fichiers du port) enregistrant les appels,
**Then** il **compile et fonctionne** substitué via `ZToasterScope` — prouvant que le port est **injectable** et **non `sealed`** (AD-4/NFR-U9).

### AC7 — Graphe inchangé, gates verts repo-wide, codegen no-op (AD-1/NFR-U1/NFR-U11)
**Given** l'extension `zcrud_ui_kit`,
**When** on inspecte le graphe et rejoue les gates,
**Then** `zcrud_ui_kit` conserve **exactement une** arête `zcrud_*` **sortante** (`→ zcrud_core`) et **zéro** entrante ; `CORE OUT=0` intact ; `graph_proof.py` reste **ACYCLIQUE** (EX-UI.8 n'ajoute **aucune** dépendance — D1),
**And** `melos run generate` est un **no-op** pour ce package (aucun `@ZcrudModel` — NFR-U11), gate `codegen-distribution` **non concernée** (aucun `part`/`*.g.dart`),
**And** `dart analyze packages/zcrud_ui_kit` **RC=0** ; `melos run analyze` **ET** `melos run verify` **repo-wide** délégués au gate de commit d'epic de l'orchestrateur,
**And** `gate:secrets` reste vert (zéro secret — AD-12) ; `melos list` **inchangé** (aucun nouveau package).

---

## Tasks / Subtasks

- [x] **T1 — Domaine : enum de sévérité** (AC1, D2, D6) — `lib/src/domain/z_toast_severity.dart`
  - [x] T1.1 `enum ZToastSeverity { info, success, warning, error }` (camelCase) + dartdoc « enums > booléens ». Aucun `@JsonKey`.

- [x] **T2 — Domaine : port** (AC2, D3) — `lib/src/domain/z_toaster.dart`
  - [x] T2.1 `abstract interface class ZToaster` avec `void show(...)`. Jamais `sealed`. Dartdoc : contrat, défaut `info`, impls concrètes dans bindings/app.

- [x] **T3 — Présentation : impl par défaut** (AC3, AC4, D4) — `lib/src/presentation/z_scaffold_messenger_toaster.dart`
  - [x] T3.1 `class ZScaffoldMessengerToaster implements ZToaster` (`const`) ; `show(...)` → `ScaffoldMessenger.of(context).showSnackBar(...)`.
  - [x] T3.2 Mapping sévérité → (couleur dérivée `ColorScheme`/`ZcrudTheme.of`, icône) — aucun hex ; `error` via `ZcrudTheme.of(context).errorColor ?? scheme.error`.
  - [x] T3.3 Contenu `SnackBar` : icône + texte (couleur jamais seul canal), `Semantics` (liveRegion + ExcludeSemantics visuel), directionnel (`TextAlign.start`).
  - [x] T3.4 `SnackBarAction` conditionnel (si `actionLabel` + `onAction`), cible ≥ 48 dp (tap target Material) ; `duration` appliqué si fourni (sinon 4 s).

- [x] **T4 — Présentation : seam + helper** (AC5, D5) — `lib/src/presentation/z_toaster_scope.dart`
  - [x] T4.1 `class ZToasterScope extends InheritedWidget` (champ `ZToaster toaster`) + `maybeOf` + `of` (repli `const ZScaffoldMessengerToaster()`) + `updateShouldNotify`.
  - [x] T4.2 `void zToast(BuildContext context, String message, {...})` → résout via `ZToasterScope.of(context)` puis délègue.

- [x] **T5 — Barrel** (AC1..AC5, D7) — `lib/zcrud_ui_kit.dart`
  - [x] T5.1 Ajout des 4 `export` (ordre alphabétique) + paragraphe dartdoc EX-UI.8. Pas de ré-export `zcrud_core` ; exports EX-UI.7 intacts.

- [x] **T6 — Tests** (AC1..AC6)
  - [x] T6.1 `test/z_toast_severity_test.dart` (pur-Dart) : 4 valeurs ; `.name` camelCase ; ordre croissant.
  - [x] T6.2 `test/z_scaffold_messenger_toaster_test.dart` (widget) : chaque sévérité → `SnackBar.backgroundColor` = bon rôle `ColorScheme` (light ET dark) ; icône + texte présents.
  - [x] T6.3 `test/z_toaster_action_test.dart` (widget) : `SnackBarAction` présent + tap → callback ; hauteur tap target ≥ 48 dp ; sans action → aucune `SnackBarAction`.
  - [x] T6.4 `test/z_toaster_scope_test.dart` (widget) : `zToast` sans scope → `ZScaffoldMessengerToaster` ; avec `ZToasterScope(_FakeToaster())` → fake appelé (substitution + port non-`sealed`) ; `of`/`maybeOf`/`updateShouldNotify`.
  - [x] T6.5 `test/z_toaster_rtl_test.dart` (widget) : SnackBar sous `Directionality.rtl` sans exception ; `Semantics` du message présent.

- [x] **T7 — Vérif verte + graphe** (AC7)
  - [x] T7.1 `dart run melos run generate` → SUCCESS (no-op : 0 `.g.dart` ajouté).
  - [x] T7.2 `dart analyze packages/zcrud_ui_kit` RC=0 (No issues found). `melos analyze`/`verify` repo-wide → orchestrateur.
  - [x] T7.3 `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK / CORE OUT=0 OK (`zcrud_ui_kit -> zcrud_core` seule arête).
  - [x] T7.4 `flutter test` → 52 tests verts (30 EX-UI.7 + 22 EX-UI.8).

---

## Dev Notes

### Fichiers à créer / modifier (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_ui_kit/lib/src/domain/z_toast_severity.dart` | NEW — `enum ZToastSeverity` |
| `packages/zcrud_ui_kit/lib/src/domain/z_toaster.dart` | NEW — `abstract interface class ZToaster` |
| `packages/zcrud_ui_kit/lib/src/presentation/z_scaffold_messenger_toaster.dart` | NEW — impl défaut pur-Flutter |
| `packages/zcrud_ui_kit/lib/src/presentation/z_toaster_scope.dart` | NEW — `ZToasterScope` + `zToast` |
| `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` | **UPDATE** — +4 `export` + dartdoc EX-UI.8 |
| `packages/zcrud_ui_kit/test/z_toast_severity_test.dart` | NEW — pur-Dart |
| `packages/zcrud_ui_kit/test/z_scaffold_messenger_toaster_test.dart` | NEW — widget |
| `packages/zcrud_ui_kit/test/z_toaster_action_test.dart` | NEW — widget |
| `packages/zcrud_ui_kit/test/z_toaster_scope_test.dart` | NEW — widget |
| `packages/zcrud_ui_kit/test/z_toaster_rtl_test.dart` | NEW — widget |

⛔ **NE PAS TOUCHER** : `packages/zcrud_ui_kit/pubspec.yaml` (dépendances déjà OK), `pubspec.yaml` racine (package déjà au `workspace:`), `melos.yaml`, les fichiers EX-UI.7 (`z_confirm_*`, `z_content_state`, `z_state_widgets`), `packages/zcrud_core/**` (consommé, jamais réécrit), `packages/zcrud_responsive/**`, `packages/zcrud_navigation/**`.

### Références de code (LECTURE SEULE)

- **`zcrud_core`** `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:90,295` — `ZcrudTheme.of(context).errorColor` (dérivé du `ColorScheme`, aucun hex). ⛔ Rien à redéclarer.
- **`zcrud_ui_kit`** (EX-UI.7, patrons à réutiliser) : `z_state_widgets.dart:156` (idiome couleur d'erreur), `:89-92` (a11y défensif `maybeOf`), `:17`/`z_confirm_dialog.dart:15` (`_kMinTouchTarget = 48`), `z_confirm_tone.dart` (patron d'enum UI-pur non sérialisé).
- **dodlp** `lib/src/utils/services/toast_service.dart` (LECTURE SEULE — GetX) : source best-of-breed à **neutraliser** (3 méthodes → 1 `show(severity:)`, `Get.showSnackbar` → `ScaffoldMessenger`). ⛔ La variante GetX = **EX-UI.11** (`zcrud_get`), pas ici.

### Invariants AD applicables (rappel ciblé)

- **AD-32** : `zcrud_ui_kit` fournit le **PORT** `ZToaster` (défini ici) ; les impls concrètes GetX/`toastification`/`ScaffoldMessenger`-app vivent dans les bindings/app via seam. L'impl **par défaut** `ScaffoldMessenger` est pur-Flutter et licite dans le package.
- **AD-4 / NFR-U9** : `ZToaster` **pluggable, jamais `sealed`** — impl externe compile (AC6).
- **AD-6 / AD-15** : résolution du toaster par **seam** (`ZToasterScope`), défaut = `ZScaffoldMessengerToaster` ; ⛔ aucun `Get.find`/`WidgetRef`/`Provider.of`.
- **AD-2 / NFR-U2** : `ScaffoldMessenger.of(context)` uniquement ; ⛔ aucun gestionnaire d'état.
- **AD-13 / NFR-U4/U5** : couleur **dérivée** du `ColorScheme` (jamais hex), **jamais seul canal** (icône + texte), `SnackBarAction` ≥ 48 dp, `Semantics`, directionnel — testé LTR/RTL + light/dark.
- **AD-10 / NFR-U10** : `severity` défaut `info` ; `ZToasterScope.of` défaut `ZScaffoldMessengerToaster` ; **jamais de throw**.
- **AD-1 / NFR-U1** : arête `zcrud_ui_kit → zcrud_core` **inchangée** (EX-UI.8 n'ajoute aucune dépendance) ; `CORE OUT=0` ; `graph_proof.py` ACYCLIQUE.
- **AD-12 / NFR-U8** : zéro secret.
- **NFR-U7 (enums > booléens)** : `ZToastSeverity` remplace `bool isError`/`String` libre.
- **NFR-U11** : pas de codegen — confirmer le no-op de `melos run generate`.

### Project Structure Notes

- Le port `ZToaster` est classé sous `domain/` (contrat, conforme au Structural Seed « `domain/ : port ZToaster` ») bien qu'il prenne un `BuildContext` : c'est un **port de présentation** (comme `ZFormPresenter`), pas un pur domaine sans contexte. L'impl et le seam vivent sous `presentation/`.
- `zcrud_ui_kit` reste `→ zcrud_core` + flutter (arête entrante au cœur, `CORE OUT=0` intact).
- Barrel = seule API publique ; EX-UI.8 **étend** l'existant EX-UI.7 (barrel séquentiel — EX-UI.9/10 étendront encore).

### Dépendances aval (ce que cette story débloque)

`done` sur EX-UI.8 débloque **EX-UI.11** (le binding `zcrud_get` implémente `ZToaster` via `Get.showSnackbar` — `ZGetToaster`) et permet aux apps de fournir leur `toastification`/GetX toaster via le seam. Séquentiellement (même barrel/pubspec) : **EX-UI.9** puis **EX-UI.10** étendent encore ce package.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.8 (l.330-352), § Séquencement P3∥P2 (l.94-99), § NFR-U2/U7/U9/U11 (l.47-56), § Traçabilité AD-32 (l.69), § EX-UI.11 binding (l.408-434)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § AD-32 (l.104-107 : **toast = port** `ZToaster`, impls concrètes dans bindings/app via seam), § AD-4/AD-6/AD-15 (l.56-57), § AD-29 (l.89-92), § Enums>booléens + `ZToastSeverity` (l.118), § Consistency `ZToaster` (l.115), § Structural Seed `domain/ : port ZToaster` (l.154), § Capability Map toast (l.193), § Notes migration dodlp `ToastService` (l.202)]
- [Source: `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:90,295` (`ZcrudTheme.of` / `errorColor` dérivé du `ColorScheme`) ; barrel `packages/zcrud_core/lib/zcrud_core.dart` (`ZcrudTheme`/`ZcrudScope`/`ZcrudLocalizations`)]
- [Source: `packages/zcrud_ui_kit/{pubspec.yaml,lib/zcrud_ui_kit.dart}` (état livré EX-UI.7) ; `lib/src/presentation/z_state_widgets.dart:17,89-92,156` + `z_confirm_dialog.dart:15` (idiomes couleur/a11y/≥48dp) ; `lib/src/domain/z_confirm_tone.dart` (patron enum UI-pur)]
- [Source: `_bmad-output/implementation-artifacts/stories/ex-ui-7-content-state-confirm-dialog.md` (story modèle : scaffolding, no-op codegen, `graph_proof`, barrel séquentiel)]
- [Source: best-of-breed LECTURE SEULE — dodlp `lib/src/utils/services/toast_service.dart` (GetX `showError/Success/Info` → port + impl neutre) (`explore/dodlp.md` §4)]
- [Source: `CLAUDE.md` — Key Don'ts (AD-2/AD-13 : jamais de manager dans un paquet pur, primitives directionnelles, `const`, `Semantics` ≥48dp, couleur injectée), naming préfixe `Z`, gates CI (secrets/anti-reflectable/codegen)]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Domaine pur** (sans `BuildContext`) | `ZToastSeverity.values.length == 4`, `.name` camelCase | AC1, D2 |
| **Widget** (light + dark) | Chaque sévérité → `SnackBar` colorée par le **bon rôle `ColorScheme`** (`error`=`colorScheme.error`…) ; icône + texte présents | AC3, AD-13 |
| **Widget** | `SnackBarAction` (label/callback) présent + tap → callback + ≥ 48 dp ; sans action → absent | AC4 |
| **Widget** | `zToast` sans scope → `ZScaffoldMessengerToaster` ; avec `ZToasterScope(_FakeToaster())` → fake appelé (substitution) ; `of` sans scope = défaut, jamais throw | AC5, AC6 |
| **Widget** (RTL) | `SnackBar` sous `Directionality.rtl` (aucune exception, directionnel) ; `Semantics` du message | AC4, AD-13 |
| **Graphe / gates** | `graph_proof` ACYCLIQUE / CORE OUT=0 (inchangé) ; `dart analyze` RC=0 ; `generate` no-op ; `melos list` inchangé ; `gate:secrets` vert | AC7, NFR-U1/U11 |

**Definition of Done** : AC1→AC7 verts · `pubspec.yaml` **inchangé** (`zcrud_core` + flutter uniquement, aucun toaster tiers/manager) · `ZToastSeverity` = enum 4 valeurs (aucun `bool`/`String` libre) · `ZToaster` = `abstract interface class` (jamais `sealed`, impl externe compile) · `ZScaffoldMessengerToaster` = `ScaffoldMessenger` pur-Flutter, couleur **dérivée du `ColorScheme`** (aucun hex, dark-mode-aware), icône + texte (couleur jamais seul canal) · `SnackBarAction` ≥ 48 dp · seam `ZToasterScope` + `zToast` (défaut sûr, substitution prouvée) · RTL + a11y testés (light/dark, LTR/RTL) · `melos run generate` (no-op) + `dart analyze` RC=0 ; `melos run analyze`/`verify` **repo-wide** délégués à l'orchestrateur · `graph_proof` ACYCLIQUE/CORE OUT=0 · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

- 1 échec initial : `z_toaster_action_test.dart` (tap sur `SnackBarAction` n'incrémentait pas le callback — SnackBar encore en animation d'entrée). Corrigé en remplaçant `pump()` par `pumpAndSettle()` avant le tap. Tous verts ensuite.

### Completion Notes List

- **Mapping couleur (Q1)** : `info→primary/onPrimary`, `success→tertiary/onTertiary`, `warning→secondary/onSecondary`, `error→(ZcrudTheme.errorColor ?? scheme.error)/onError`. Rôles `ColorScheme` existants (M3 n'a pas de slot `success/warning/info`) — aucun littéral hex ni `Colors.<x>`. Vérifié light ET dark.
- **Lisibilité (Q2)** : fond de `SnackBar` teinté par la couleur de sévérité + texte/icône via le rôle `on*` correspondant (contraste garanti), testé light/dark.
- **≥48 dp** : `SnackBarAction` n'expose pas `minimumSize` ; la cible ≥48 dp est portée par le tap target Material (`materialTapTargetSize.padded` par défaut) — mesuré `height ≥ 48` sur le `TextButton` interne. La constante `_kMinTouchTarget` a été retirée (inutilisable/inutilisée → aurait cassé `analyze` zéro-warning).
- **A11y** : `Semantics(container, liveRegion, label: message)` + `ExcludeSemantics` sur le visuel (évite la double annonce, idiome EX-UI.7). Couleur jamais seul canal (icône + texte). `TextAlign.start` (directionnel).
- **Seam** : `ZToasterScope.of` retombe sur `const ZScaffoldMessengerToaster()` (jamais de throw). Substitution prouvée par `_FakeToaster implements ZToaster` défini hors des fichiers du port (port non-`sealed`, injectable).
- **Périmètre** : aucune dépendance ajoutée (`pubspec.yaml` du package inchangé), aucun import manager/tiers (`get`/`riverpod`/`provider`/`toastification`/`go_router`/`dartz`), aucun `zcrud_core`/`melos.yaml`/pubspec racine écrit, aucun `sprint-status.yaml` touché (délégué à l'orchestrateur). Graphe inchangé.

### File List

- `packages/zcrud_ui_kit/lib/src/domain/z_toast_severity.dart` (NEW)
- `packages/zcrud_ui_kit/lib/src/domain/z_toaster.dart` (NEW)
- `packages/zcrud_ui_kit/lib/src/presentation/z_scaffold_messenger_toaster.dart` (NEW)
- `packages/zcrud_ui_kit/lib/src/presentation/z_toaster_scope.dart` (NEW)
- `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (MODIFIED — +4 exports + dartdoc EX-UI.8)
- `packages/zcrud_ui_kit/test/z_toast_severity_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_scaffold_messenger_toaster_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_toaster_action_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_toaster_scope_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_toaster_rtl_test.dart` (NEW)

### Questions pour l'orchestrateur (à remonter si besoin)

1. **Mapping couleur `info`/`success`/`warning`** : `ZcrudTheme`/M3 n'ont pas de slot dédié. La story propose `info→primary`, `success→tertiary`, `warning→secondary` (dérivés du `ColorScheme`, jamais hex) — le dev peut ajuster les rôles pour la lisibilité (contraste `on*`) tant qu'**aucun** littéral n'est introduit. À confirmer si un enrichissement de `ZcrudTheme` (slots sémantiques `successColor`/`warningColor`) est souhaité ultérieurement (hors périmètre EX-UI.8).
2. **`SnackBar` : fond teinté vs accent** : teinter le fond de la `SnackBar` (avec `on*` lisible) ou n'utiliser la couleur que sur l'icône d'accent — décision de lisibilité laissée au dev, testée light/dark.
