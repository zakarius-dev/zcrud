---
baseline_commit: 9e405a09bf25c136a8bdfb94d1d383d7c98452b5
---

# Story EX-UI.7 : [SCAFFOLDING `zcrud_ui_kit`] États de contenu (`enum ZContentState`) + `ZEmptyState`/`ZLoadingState`/`ZErrorState` (+ aiguilleur `ZContentStateView`) + `ZConfirmDialog`/`showZConfirmDialog`

Status: review

- **Clé sprint-status** : `ex-ui-7-content-state-confirm-dialog`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit)
- **Taille** : **M** (1 package NEUF `zcrud_ui_kit` : scaffolding + 1 enum domaine + 3 widgets d'état + 1 aiguilleur + 1 dialog + 1 helper ; 0 codegen, 0 entité persistée)
- **Parallélisation** : **PARALLÉLISABLE (P3 ∥ P2)** — package `zcrud_ui_kit` **disjoint** de `zcrud_responsive` (P2) et `zcrud_navigation`. **Indépendant de P1.** Ici traitée **séquentiellement** (P2 en finition), mais fichiers disjoints de toute façon. ⚠️ **Tête de série du package** : EX-UI.7 **crée** `zcrud_ui_kit` et son barrel ; **précède** EX-UI.8 (port `ZToaster`), EX-UI.9 (`ZDiscardChangesGuard`), EX-UI.10 (`ZAlphabetIndexBar` + transitions) — mêmes fichiers barrel/pubspec ⇒ ces 4 stories **sérialisées entre elles** (barrel séquentiel), même si le package est parallélisable vis-à-vis de P2.
- **Package écrit (disjoint)** : `packages/zcrud_ui_kit/` (NEW) + **1 ligne** dans le bloc `workspace:` du **`pubspec.yaml` racine**. ⛔ **N'ÉCRIT PAS `zcrud_core`** (ni aucun autre `zcrud_*`) — il **le CONSOMME** (`ZcrudScope`/thème/l10n injectés). ⛔ **NE TOUCHE PAS `melos.yaml`** (glob `packages/**`).
- **AD delta** : **AD-32** (patterns génériques UI : états Empty/Loading/Error + `ZConfirmDialog` à thème injecté), **AD-29** (paquets UI purs — `zcrud_ui_kit` dépend de `zcrud_core` + flutter). **AD hérités** : **AD-1** (acyclique, `CORE OUT=0` — l'arête `zcrud_ui_kit → zcrud_core` est **ENTRANTE au cœur**, licite), **AD-2/AD-15** (Flutter-native, **aucun gestionnaire d'état**), **AD-13** (RTL / a11y / thème & l10n injectés : `EdgeInsetsDirectional`, `Semantics`, cibles ≥ 48 dp, couleur jamais seul canal), **AD-10** (défauts sûrs), **AD-12** (zéro secret). **Consigne transverse NFR-U7** : *enums > booléens*.

---

## Story

**As a** développeur d'écrans (dodlp, iffd, lex, …) consommant `zcrud`,
**I want** des **widgets d'état génériques** (`ZEmptyState` / `ZLoadingState` / `ZErrorState`) pilotables par un **`enum ZContentState { idle, loading, empty, error, success }`** via un aiguilleur, et un **`ZConfirmDialog`** de confirmation à **thème injecté** (dark-mode-aware) exposé par un helper `showZConfirmDialog(...) → Future<bool>`,
**so that** je cesse de **redupliquer** les états Empty/Loading/Error (dodlp `state_widgets.dart`, iffd `empty_*` × N) et le dialog de confirmation (dodlp/iffd `buildConfirmDialog`), en **modélisant l'état par un enum** plutôt que par des combinaisons de `bool` (`isLoading`/`hasError`/`isEmpty`), et sans jamais coder une couleur en dur ni coupler un gestionnaire d'état.

---

## Contexte — vérifié sur disque (pas sur la seule foi de l'épic)

### Ce que `zcrud_core` EXPOSE DÉJÀ (à CONSOMMER pour l'injection thème/l10n — jamais redéclarer)

Vérifié dans `packages/zcrud_core/lib/zcrud_core.dart` (barrel) :

| Symbole `zcrud_core` | Provenance (export) | Usage EX-UI.7 |
|---|---|---|
| `ZcrudScope` (`InheritedWidget`) + `ZcrudScope.of(context)` / `maybeOf` | `:161` `src/presentation/zcrud_scope.dart` | Seam d'injection ; expose `theme` (`ZcrudTheme?`), `labels` (`ZcrudLabels?`). Lecture **optionnelle** (`maybeOf`) — repli `Theme.of` si absent. |
| `ZcrudTheme` + `ZcrudTheme.fallback(ThemeData)` | `:156` `src/presentation/theme/z_theme.dart` | Couleurs sémantiques **dérivées du `ColorScheme`** (`errorColor`→`scheme.error`, `surfaceColor`→`scheme.surface`, …) — **aucun littéral hex**. Base pour teinter `ZErrorState`/`ZConfirmDialog` sans couleur en dur. |
| `ZcrudLocalizations.of(context)` | `:109` `src/presentation/l10n/z_localizations.dart` | l10n injectée du cœur (si le consommateur la fournit). |

⛔ **Aucun de ces symboles n'est redéclaré.** `zcrud_ui_kit` `import 'package:zcrud_core/zcrud_core.dart';` et **consomme** `ZcrudScope`/`ZcrudTheme`/`ZcrudLocalizations` en **lecture** (repli systématique sur `Theme.of(context)` / `MaterialLocalizations.of(context)` quand le scope n'est pas monté).

### Best-of-breed à NEUTRALISER (LECTURE SEULE — apps hors périmètre, ne PAS copier tel quel)

- **dodlp** `lib/src/presentation/widgets/state_widgets.dart` (~415 LOC) : `EmptyStateWidget` / `LoadingStateWidget` / `ErrorStateWidget` / `SuccessStateWidget`. **Couplage ≈ nul** (uniquement `Theme.of(context)`) — patron direct des 3 widgets d'état, **déjà** conforme « thème via `Theme.of` ». À neutraliser : icône + message + CTA optionnel paramétrables ; ajouter `Semantics`, cibles ≥ 48 dp, directionnel.
- **dodlp** `lib/modules/data_crud/forms_utils.dart:271` `buildConfirmDialog()` : dialog Oui/Non, **dark-mode-aware** (`Theme.of(context).brightness`), MAIS tire 2 couleurs globales de l'app (`kSuccessColorLight/Dark`, `kErrorColorLight/Dark`) → **à neutraliser** : remplacer par des couleurs **dérivées du `ColorScheme`** (jamais un littéral importé de l'app).
- **iffd** `lib/src/utils/functions/forms_utils.dart:455` `buildConfirmDialog(context, {message, onConfirm})` : même patron (couplage faible, `Theme.of(context).brightness`) ; + empty-states **dupliqués** (`EmptyTasksWidget`, `empty_conversations_state.dart`, `empty_folder_content.dart`, `first_folder_widget.dart`) tous du même style (icône + titre + sous-titre + CTA) → **justifie** le `ZEmptyState` générique unique.

### Patron de scaffolding (VÉRIFIÉ) — `zcrud_responsive` (EX-UI.1, sur disque)

- `packages/zcrud_responsive/pubspec.yaml` : `name` + `publish_to: none` + `resolution: workspace` + `environment.sdk: ^3.12.2` + `dependencies: { zcrud_core: ^0.2.0, flutter: {sdk: flutter} }` + `dev_dependencies: { flutter_test: {sdk: flutter} }` + `homepage`/`repository`/`issue_tracker`/`topics`. **Calquer** (adapter `name`/`description`/`topics`).
- `packages/zcrud_responsive/analysis_options.yaml` : **une** ligne `include: ../../analysis_options.yaml`.
- `packages/zcrud_responsive/lib/zcrud_responsive.dart` : barrel `library;` avec dartdoc d'API + exports relatifs `src/...`.
- Arbo : `lib/src/{domain,presentation}` + `README.md`.

### Point de déclaration du package dans le workspace (VÉRIFIÉ)

- **`pubspec.yaml` racine → bloc `workspace:`** = **SEUL** point de déclaration d'un nouveau package produit (commentaire du fichier). Le bloc liste actuellement jusqu'à `- packages/zcrud_responsive` (EX-UI.1, l.55-60). ⇒ **ajouter `- packages/zcrud_ui_kit`** (avec un commentaire bref décrivant EX-UI.7, à la place logique ; ne pas réordonner le reste).
- **`melos.yaml`** = glob `packages/**` → **rien à ajouter** ; il picore le nouveau dossier. ⛔ **Ne PAS toucher son bloc `scripts:`** (le gate `gate:melos` compare `pubspec.yaml`↔`melos.yaml` — n'y touche pas si tu ne touches pas l'autre).
- **`melos list`** passe de **N** à **N+1** (les harnais `tool/` restent ignorés). Le dev **mesure N sur disque** avant/après (`melos list`) et consigne le chiffre exact — **ne PAS coder en dur** (le commentaire du root pubspec peut être périmé ; EX-UI.1 a mesuré 21).

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — `zcrud_ui_kit` DÉPEND de `zcrud_core:^0.2.0` + flutter (AD-29 ; AUCUN manager)

`pubspec.yaml` déclare `dependencies: { flutter: {sdk: flutter}, zcrud_core: ^0.2.0 }`. Version **`0.2.0`** confirmée sur disque (`packages/zcrud_core/pubspec.yaml`, réutilisée par `zcrud_responsive`). ⛔ **AUCUN gestionnaire d'état** (`get`/`flutter_riverpod`/`provider`), **AUCUN routeur** (`go_router`), **AUCUN tiers** (`toastification`/`responsive_builder`/`dotted_border`/spinkit — le toaster est EX-UI.8, en **port** ; ici widgets purs), **AUCUN `dartz`**. L'arête `zcrud_ui_kit → zcrud_core` est **ENTRANTE au cœur** ⇒ **`CORE OUT=0` reste intact** ; `graph_proof.py` doit rester **ACYCLIQUE**.

### D2 — `enum ZContentState { idle, loading, empty, error, success }` (domaine, camelCase, NON sérialisé)

Fichier `lib/src/domain/z_content_state.dart`. Valeurs **camelCase** (`idle`, `loading`, `empty`, `error`, `success`). C'est l'**unique** modélisation d'état de contenu — il **remplace** les combinaisons de `bool` (`isLoading`/`hasError`/`isEmpty`) des apps (NFR-U7 « enums > booléens », AD-32). **UI-pure, non persisté** ⇒ **aucun `@ZcrudModel`/`@JsonSerializable`, aucun `@JsonKey`** (D6). `idle` = état neutre initial (avant tout chargement) ; `success` = contenu prêt (rendu délégué au consommateur, cf. D4).

### D3 — 3 widgets d'état : `StatelessWidget const`, thème/l10n **INJECTÉS**, a11y AD-13

Fichier `lib/src/presentation/z_state_widgets.dart`. Chaque widget est un **`StatelessWidget`** à **constructeur `const`** (AD-13 « `const` pour widgets immuables »). API (proposée — le dev ajuste si le code l'impose) :

- **`ZEmptyState`** : `{ required String message, IconData? icon, String? title, String? actionLabel, VoidCallback? onAction }`. Rend icône (optionnelle) + titre/message (**texte toujours présent — l'icône n'est JAMAIS le seul canal**, AD-13/NFR-U4) + CTA optionnel (`onAction`+`actionLabel`).
- **`ZLoadingState`** : `{ String? message }`. `CircularProgressIndicator` + message optionnel + `Semantics(label:)` explicite.
- **`ZErrorState`** : `{ required String message, IconData? icon, String? title, String? retryLabel, VoidCallback? onRetry }`. Teinte d'erreur **dérivée** de `ZcrudScope.maybeOf(context)?.theme?.errorColor ?? ZcrudTheme.fallback(Theme.of(context)).errorColor` (= `ColorScheme.error`) — **jamais** un hex en dur. CTA « réessayer » optionnel.

**Règles communes (AD-13, NON-NÉGOCIABLES) :**
- **Couleurs / labels / l10n INJECTÉS** : couleurs via `Theme.of(context).colorScheme` / `ZcrudScope` (repli `Theme.of`) — **AUCUN littéral hex/`Colors.xxx` sémantique** ; les **textes** (`message`/`title`/`actionLabel`/`retryLabel`) sont **fournis par l'appelant** (l10n injectée) — le package ne code **aucune** chaîne métier en dur.
- **`Semantics`** explicites (rôle/état) sur chaque widget ; **couleur jamais seul canal** (toujours icône **+ texte**).
- **Cibles tactiles ≥ 48 dp** pour tout bouton/CTA (`minimumSize`/`constraints`).
- **Directionnel** : `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/center` — ⛔ **jamais** `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`.

### D4 — Aiguilleur `ZContentStateView` (rend le bon widget selon `ZContentState`)

Fichier `lib/src/presentation/z_state_widgets.dart` (ou co-localisé). `StatelessWidget` :
`ZContentStateView({ required ZContentState state, required WidgetBuilder successBuilder, Widget? idle, Widget? loading, Widget? empty, Widget? error })`.
- `switch (state)` **exhaustif** sur les 5 valeurs → rend la tranche correspondante ; `success` → `successBuilder(context)`.
- Slots `idle`/`loading`/`empty`/`error` **optionnels** avec **repli sûr** : `loading` absent → `ZLoadingState()` ; `empty`/`error`/`idle` absents → `SizedBox.shrink()` (défaut sûr, jamais de throw — AD-10). Le dev documente les replis.
- ⚠️ Le `switch` doit être **exhaustif sans `default`** (l'enum étant scellé, un nouveau membre casserait la compilation → détection à froid, conforme « enums > booléens »).

### D5 — `ZConfirmDialog` + `showZConfirmDialog(...) → Future<bool>` (dark-mode-aware, RTL, sans manager)

Fichier `lib/src/presentation/z_confirm_dialog.dart`.
- **`ZConfirmDialog`** : `StatelessWidget const` — `AlertDialog` (`title`/`content`/`actions`). Params : `{ required String title, required String message, String? confirmLabel, String? cancelLabel, ZConfirmTone tone = ZConfirmTone.neutral }`.
- **`showZConfirmDialog(BuildContext context, { required String title, required String message, String? confirmLabel, String? cancelLabel, ZConfirmTone tone = ZConfirmTone.neutral }) → Future<bool>`** : `showDialog<bool>(...)` puis **`?? false`** (barrier dismiss / pop sans valeur = **false**, défaut sûr — AD-10). **Confirmer** → `Navigator.pop(context, true)` ; **Annuler** → `Navigator.pop(context, false)`.
- **Labels par défaut = l10n Flutter injectée, jamais codée** : `confirmLabel ??= MaterialLocalizations.of(context).okButtonLabel` ; `cancelLabel ??= MaterialLocalizations.of(context).cancelButtonLabel`. ⛔ **Aucune** chaîne « Confirmer »/« Annuler » en dur dans le package.
- **`enum ZConfirmTone { neutral, destructive }`** (domaine, `lib/src/domain/z_confirm_tone.dart`) — modélise la tonalité **par un enum** (NFR-U7), **pas** un `bool isDestructive`. `destructive` → bouton de confirmation teinté `ColorScheme.error` (dérivé, jamais hex) ; `neutral` → teinte primaire par défaut. Ce choix honore explicitement « enums > booléens » là où dodlp/iffd utilisaient un flag/couleur ad hoc.
- **Dark-mode-aware** : toutes les couleurs proviennent du `Theme.of(context)`/`ColorScheme` courant (donc s'adaptent au `Brightness`) — **aucune** dépendance à `kSuccessColor*`/`kErrorColor*` de l'app.
- **Directionnel / a11y** : `actions` en `TextButton`/`FilledButton` avec cibles ≥ 48 dp, `Semantics`, disposition directionnelle ; le dialog reste correct sous `Directionality.rtl`.
- ⛔ **Aucun** `Get.dialog`/`Get.context!`/manager — uniquement `showDialog` + `Navigator.pop` (Flutter pur, AD-2/NFR-U2).

### D6 — Aucun codegen, aucune sérialisation (NFR-U11)

`ZContentState`, `ZConfirmTone` et tous les widgets sont **UI-pure**, **non persistés** → **aucun `@ZcrudModel`/`@JsonSerializable`/`part`** ⇒ pas de `*.g.dart`, `melos run generate` **no-op** pour ce package, gate `codegen-distribution` **non concernée**, anti-`reflectable` sans objet. **Confirmer** le no-op au 1er `melos run generate` (AC8).

### D7 — Barrel = SEULE API publique

`lib/zcrud_ui_kit.dart` (`library;`) exporte **uniquement** : `z_content_state.dart`, `z_confirm_tone.dart`, `z_state_widgets.dart`, `z_confirm_dialog.dart`. ⛔ **Ne PAS** ré-exporter `zcrud_core` (le consommateur l'importe directement au besoin ; contrairement à EX-UI.1 il n'y a pas de type du cœur central à la surface d'API de ce package). Impl sous `lib/src/{domain,presentation}`.

---

## Acceptance Criteria

### AC1 — Scaffolding du package `zcrud_ui_kit` (dépend de `zcrud_core` + flutter)
**Given** l'absence du package,
**When** on crée `packages/zcrud_ui_kit/`,
**Then** il contient :
- `pubspec.yaml` : `name: zcrud_ui_kit`, **`version: 0.2.0`**, `publish_to: none`, `resolution: workspace`, `environment.sdk: ^3.12.2` (aligné sur `zcrud_core`/`zcrud_responsive`), `dependencies` = **`flutter: {sdk: flutter}` + `zcrud_core: ^0.2.0`** (⛔ **aucun autre `zcrud_*`**, ⛔ **aucun gestionnaire d'état** `get`/`flutter_riverpod`/`provider`, ⛔ **aucun routeur** `go_router`, ⛔ **aucun tiers** `toastification`/`responsive_builder`/`dotted_border`/spinkit, ⛔ **aucun** `dartz`), `dev_dependencies` = `flutter_test: {sdk: flutter}`, plus `homepage`/`repository`/`issue_tracker`/`topics` calqués sur `zcrud_responsive`/`zcrud_core` ;
- `analysis_options.yaml` : `include: ../../analysis_options.yaml` (baseline de lint partagée) ;
- barrel `lib/zcrud_ui_kit.dart` (`library;` + dartdoc d'API + exports des 4 fichiers, D7) ;
- arbo `lib/src/domain/` + `lib/src/presentation/` (peuplées par cette story) ;
- `README.md` minimal (rôle « ui-kit transverse », dépendance à `zcrud_core`, 1 exemple `showZConfirmDialog`/`ZContentStateView`, mention monorepo, patron `zcrud_responsive/README.md`).
**And** `- packages/zcrud_ui_kit` est ajouté au bloc **`workspace:` du `pubspec.yaml` racine** (à sa place logique + commentaire bref ; ne pas réordonner le reste) ; **`melos.yaml` inchangé** (glob `packages/**`).
**And** `dart pub get` racine (bootstrap workspace) résout OK.

### AC2 — `enum ZContentState` (5 paliers, camelCase) — remplace les bools multi-état
**Given** le besoin de représenter l'état d'un contenu,
**When** on définit `enum ZContentState { idle, loading, empty, error, success }` (`lib/src/domain/z_content_state.dart`, valeurs **camelCase**),
**Then** c'est l'**unique** modélisation d'état de contenu exposée — **aucun** `bool` multi-état (`isLoading`/`hasError`/`isEmpty`) dans l'API publique (NFR-U7 « enums > booléens », AD-32),
**And** l'enum est **UI-pure**, **non sérialisé** (D2/D6) ⇒ **pas de `@JsonKey`**, pas de `.g.dart`.

### AC3 — `ZEmptyState` / `ZLoadingState` / `ZErrorState` : `const`, thème/l10n injectés, a11y
**Given** les états à afficher,
**When** on rend `ZEmptyState` / `ZLoadingState` / `ZErrorState` (`lib/src/presentation/z_state_widgets.dart`, chacun `StatelessWidget` à constructeur **`const`**),
**Then** chacun rend **une icône (optionnelle) + un texte toujours présent + un CTA optionnel** — l'icône/couleur n'est **JAMAIS** le seul canal d'information (texte + `Semantics`, WCAG/AD-13/NFR-U4),
**And** les **couleurs** proviennent du `Theme.of(context).colorScheme` / `ZcrudScope.maybeOf(context)?.theme` (repli `ZcrudTheme.fallback(Theme.of(context))`) — **AUCUN** littéral hex ni `Colors.<sémantique>` en dur (AD-13/NFR-U5) ; les **textes** sont **fournis par l'appelant** (l10n injectée, aucune chaîne métier en dur),
**And** tout CTA/bouton a une **cible ≥ 48 dp**, et la mise en page est **directionnelle** (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start|center` — ⛔ jamais `left`/`right`).

### AC4 — Aiguilleur `ZContentStateView` : `switch` exhaustif sur l'enum, replis sûrs
**Given** un `ZContentState` + un `successBuilder`,
**When** on rend `ZContentStateView(state:..., successBuilder:..., {idle?, loading?, empty?, error?})`,
**Then** un `switch` **exhaustif sans `default`** sur les 5 valeurs sélectionne la tranche : `success` → `successBuilder(context)` ; `loading` absent → `ZLoadingState()` ; `idle`/`empty`/`error` absents → `SizedBox.shrink()` (défaut sûr, **jamais de throw** — AD-10),
**And** aucune tranche non fournie ne fait planter le rendu (repli déterministe documenté).

### AC5 — `ZConfirmDialog` + `showZConfirmDialog(...) → Future<bool>` : thème injecté, dark-mode-aware
**Given** un besoin de confirmation,
**When** on appelle `showZConfirmDialog(context, title:..., message:..., {confirmLabel?, cancelLabel?, tone})` (`lib/src/presentation/z_confirm_dialog.dart`),
**Then** il affiche un `ZConfirmDialog` (`AlertDialog`) exposant **titre / message / action confirmer / action annuler** paramétrables,
**And** il **retourne `true`** quand l'utilisateur confirme (`Navigator.pop(context, true)`), **`false`** quand il annule **ou** ferme par barrier/pop sans valeur (`showDialog<bool>(...) ?? false`, défaut sûr AD-10),
**And** les labels par défaut proviennent de **`MaterialLocalizations.of(context)`** (`okButtonLabel`/`cancelButtonLabel`) — ⛔ **aucune** chaîne « Confirmer »/« Annuler » en dur,
**And** toutes les couleurs proviennent du `Theme.of(context)`/`ColorScheme` courant (**dark-mode-aware**, s'adapte au `Brightness`) — ⛔ **aucun** `kSuccessColor*`/`kErrorColor*` ni hex en dur,
**And** il ne dépend **d'aucun** gestionnaire d'état (`showDialog` + `Navigator.pop` uniquement — NFR-U2/AD-2).

### AC6 — Tonalité par enum (`ZConfirmTone`), jamais un `bool isDestructive`
**Given** le besoin d'une confirmation « destructive » (suppression) vs neutre,
**When** on modélise la tonalité,
**Then** elle est portée par **`enum ZConfirmTone { neutral, destructive }`** (`lib/src/domain/z_confirm_tone.dart`, camelCase) — **jamais** un `bool isDestructive` (NFR-U7),
**And** `destructive` teinte le bouton de confirmation avec `ColorScheme.error` (dérivé, jamais hex) ; `neutral` = teinte par défaut.

### AC7 — RTL / a11y (AD-13) sur toute surface
**Given** l'ensemble des widgets/dialog,
**When** on les rend sous `Directionality.rtl` et avec un lecteur d'écran,
**Then** ils restent **corrects en RTL** (aucune primitive directionnelle « left/right » codée en dur ; usage `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional`/`TextAlign.start|end`),
**And** chaque état/dialog porte des **`Semantics`** explicites, la **couleur n'est jamais le seul canal** (icône **+** texte), et les cibles interactives sont **≥ 48 dp** — **testé** (light **et** dark, LTR **et** RTL).

### AC8 — Graphe, gates verts repo-wide, codegen no-op (AD-1/NFR-U1/NFR-U11)
**Given** le package `zcrud_ui_kit`,
**When** on inspecte le graphe et rejoue les gates,
**Then** `zcrud_ui_kit` a **exactement une** arête `zcrud_*` **sortante** (`→ zcrud_core`) et **zéro** entrante ; `zcrud_core` **n'a aucune arête vers lui** (`CORE OUT=0` intact) ; `graph_proof.py` reste **ACYCLIQUE / CORE OUT=0**,
**And** `melos run generate` est un **no-op** pour ce package (aucun `@ZcrudModel` — NFR-U11 confirmée), gate `codegen-distribution` **non concernée** (aucun `part`/`*.g.dart`),
**And** `melos run analyze` **RC=0** et `melos run verify` **RC=0** **repo-wide** (délégués au gate de commit d'epic de l'orchestrateur ; le dev fournit au minimum `dart analyze packages/zcrud_ui_kit` RC=0),
**And** `melos list` = **N+1** (valeur N **mesurée sur disque** avant/après et consignée ; harnais `tool/` ignorés),
**And** `gate:secrets` reste vert (zéro secret — AD-12).

---

## Tasks / Subtasks

- [x] **T1 — Scaffolding du package** (AC1, AC8) — `packages/zcrud_ui_kit/`
  - [x] T1.1 `pubspec.yaml` : `name: zcrud_ui_kit`, `version: 0.2.0`, `flutter` + **`zcrud_core: ^0.2.0`** (+ `flutter_test` dev) ; `publish_to: none` ; `resolution: workspace` ; `sdk: ^3.12.2` ; `homepage`/`repository`/`issue_tracker`/`topics` calqués sur `zcrud_responsive`.
  - [x] T1.2 `analysis_options.yaml` (`include: ../../analysis_options.yaml`).
  - [x] T1.3 Arbo `lib/src/domain/` + `lib/src/presentation/`.
  - [x] T1.4 Ajouter `- packages/zcrud_ui_kit` (+ commentaire bref) au bloc **`workspace:` du `pubspec.yaml` racine**. ⛔ **Ne PAS toucher `melos.yaml`.**
  - [x] T1.5 `README.md` minimal (rôle, dépendance à `zcrud_core`, exemple `showZConfirmDialog`/`ZContentStateView`).
  - [x] T1.6 `dart pub get` racine (bootstrap workspace) → résolution OK.

- [x] **T2 — Domaine pur : les 2 enums** (AC2, AC6, D2, D6)
  - [x] T2.1 `z_content_state.dart` : `enum ZContentState { idle, loading, empty, error, success }` + dartdoc « enums > bools » (remplace `isLoading`/`hasError`/`isEmpty`). Aucun `@JsonKey`.
  - [x] T2.2 `z_confirm_tone.dart` : `enum ZConfirmTone { neutral, destructive }` + dartdoc (remplace un `bool isDestructive`).

- [x] **T3 — Widgets d'état + aiguilleur** (AC3, AC4, AC7, D3, D4) — `lib/src/presentation/z_state_widgets.dart`
  - [x] T3.1 `ZEmptyState` (`const` ; icône?/titre?/message requis/CTA optionnel ; `Semantics` ; ≥48dp ; directionnel).
  - [x] T3.2 `ZLoadingState` (`const` ; indicateur + message optionnel + `Semantics(label:)`).
  - [x] T3.3 `ZErrorState` (`const` ; teinte `errorColor` dérivée du `ColorScheme` ; CTA « réessayer » optionnel ; `Semantics` ; ≥48dp ; directionnel).
  - [x] T3.4 `ZContentStateView` (`switch` **exhaustif sans `default`** ; replis sûrs `ZLoadingState()`/`SizedBox.shrink()`).

- [x] **T4 — Dialog de confirmation** (AC5, AC6, AC7, D5) — `lib/src/presentation/z_confirm_dialog.dart`
  - [x] T4.1 `ZConfirmDialog` (`const` ; `AlertDialog` ; labels par défaut via `MaterialLocalizations.of(context)` ; teinte confirm selon `ZConfirmTone` ; couleurs `ColorScheme` ; directionnel ; ≥48dp ; `Semantics`).
  - [x] T4.2 `showZConfirmDialog(context, {...}) → Future<bool>` (`showDialog<bool>(...) ?? false` ; `Navigator.pop(true/false)`).

- [x] **T5 — Barrel + documentation d'API** (AC1, D7)
  - [x] T5.1 `lib/zcrud_ui_kit.dart` : `library;` + dartdoc de barrel (rôle, **dépend de `zcrud_core`**, AD-32) + exports des 4 fichiers `src/...`. ⛔ Ne PAS ré-exporter `zcrud_core`.

- [x] **T6 — Tests** (AC2..AC7)
  - [x] T6.1 `test/z_content_state_test.dart` (**pur-Dart**, sans `BuildContext`) : les 5 valeurs de l'enum existent/`.name` camelCase ; `ZContentState.values.length == 5`.
  - [x] T6.2 `test/z_state_widgets_test.dart` (**widget**) : chaque état rend **icône + message + CTA** (quand fournis) ; le texte est présent même sans icône (couleur/icône jamais seul canal) ; `Semantics` présents ; rendu **light et dark** (`ThemeData.light()`/`.dark()`).
  - [x] T6.3 `test/z_content_state_view_test.dart` (**widget**) : `ZContentStateView` **aiguille correctement** selon l'enum (chaque valeur → la bonne tranche ; `success` → `successBuilder` ; `loading` absent → `ZLoadingState` ; `empty`/`error`/`idle` absents → `SizedBox.shrink`).
  - [x] T6.4 `test/z_confirm_dialog_test.dart` (**widget**) : rend **titre + message + 2 actions** ; **confirmer → `Future` complète `true`** ; **annuler → `false`** ; **barrier dismiss / pop sans valeur → `false`** ; labels par défaut = `MaterialLocalizations` ; rendu **dark** (`ThemeData.dark()`) ; **`ZConfirmTone.destructive`** teinte le bouton via `ColorScheme.error`.
  - [x] T6.5 `test/z_rtl_a11y_test.dart` (**widget**) : les widgets d'état **et** le dialog rendus sous `Directionality.rtl` (aucune exception, disposition directionnelle) ; vérif `Semantics` + cibles ≥ 48 dp.

- [x] **T7 — Vérif verte + graphe** (AC8)
  - [x] T7.1 `dart run melos run generate` → SUCCESS (no-op : aucun `build_runner`, 0 `.g.dart`).
  - [x] T7.2 `dart analyze packages/zcrud_ui_kit` RC=0. `melos run analyze`/`verify` **repo-wide** → délégués à l'orchestrateur (gate de commit d'epic).
  - [x] T7.3 `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE / CORE OUT=0** (arête `zcrud_ui_kit→zcrud_core` entrante au cœur).
  - [x] T7.4 `flutter test packages/zcrud_ui_kit` → tous verts ; `melos list` = **N+1** (N mesuré).

---

## Dev Notes

### Fichiers à créer (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_ui_kit/pubspec.yaml` | NEW — `flutter` + `zcrud_core: ^0.2.0`, `version: 0.2.0` |
| `packages/zcrud_ui_kit/analysis_options.yaml` | NEW — `include: ../../analysis_options.yaml` |
| `packages/zcrud_ui_kit/README.md` | NEW — minimal |
| `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` | NEW — barrel (`library;`) |
| `packages/zcrud_ui_kit/lib/src/domain/z_content_state.dart` | NEW — `enum ZContentState` |
| `packages/zcrud_ui_kit/lib/src/domain/z_confirm_tone.dart` | NEW — `enum ZConfirmTone` |
| `packages/zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart` | NEW — `ZEmptyState`/`ZLoadingState`/`ZErrorState`/`ZContentStateView` |
| `packages/zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart` | NEW — `ZConfirmDialog` + `showZConfirmDialog` |
| `packages/zcrud_ui_kit/test/z_content_state_test.dart` | NEW — pur-Dart |
| `packages/zcrud_ui_kit/test/z_state_widgets_test.dart` | NEW — widget |
| `packages/zcrud_ui_kit/test/z_content_state_view_test.dart` | NEW — widget |
| `packages/zcrud_ui_kit/test/z_confirm_dialog_test.dart` | NEW — widget |
| `packages/zcrud_ui_kit/test/z_rtl_a11y_test.dart` | NEW — widget |
| `pubspec.yaml` (racine) | **UPDATE** — 1 ligne (`- packages/zcrud_ui_kit`) + commentaire dans le bloc `workspace:` |

⛔ **NE PAS TOUCHER** : `packages/zcrud_core/**` (consommé, jamais réécrit ni redéclaré), `packages/zcrud_responsive/**`, `packages/zcrud_navigation/**` (autres workstreams), `melos.yaml` (glob `packages/**` ; `gate:melos` compare son `scripts:` à `pubspec.yaml`).

### Références de code (best-of-breed, LECTURE SEULE — à NEUTRALISER, pas copier)

- **`zcrud_core`** `packages/zcrud_core/lib/zcrud_core.dart` — barrel à **importer** (`ZcrudScope`/`ZcrudTheme`/`ZcrudTheme.fallback`/`ZcrudLocalizations`). ⛔ Rien à redéclarer.
- **`zcrud_responsive`** `packages/zcrud_responsive/{pubspec.yaml,analysis_options.yaml,README.md,lib/zcrud_responsive.dart}` — **patron de scaffolding** (adapter `name`/`topics`/dartdoc).
- **dodlp** `lib/src/presentation/widgets/state_widgets.dart` — patron des 3 widgets d'état (`Theme.of` seul). **Neutraliser** : paramétrer icône/texte/CTA ; ajouter `Semantics`/≥48dp/directionnel.
- **dodlp** `lib/modules/data_crud/forms_utils.dart:271` + **iffd** `lib/src/utils/functions/forms_utils.dart:455` — patron `buildConfirmDialog` (dark-mode-aware). **Neutraliser** : remplacer `k*Color*` de l'app par des couleurs **dérivées du `ColorScheme`** ; enum `ZConfirmTone` au lieu d'un flag.

### Invariants AD applicables (rappel ciblé)

- **AD-32** : `zcrud_ui_kit` fournit `ZEmptyState`/`ZLoadingState`/`ZErrorState` + `ZConfirmDialog` (dark-mode/thème injecté) ; thème/couleurs/l10n injectés, directionnels, ≥48dp, `Semantics`.
- **AD-29** : paquet UI pur dépendant de `zcrud_core` + flutter ; aucun manager ; aucun secret ; RTL/a11y/thème injectés sur **toute** surface ; barrel + `lib/src/{domain,presentation}` ; `publish_to: none`.
- **AD-1 / NFR-U1** : `zcrud_ui_kit` a **1 arête sortante** (`→ zcrud_core`), **0 entrante** ; `CORE OUT=0` intact (arête **entrante** au cœur). `graph_proof.py` ACYCLIQUE ; `flutter` n'ajoute aucune arête `zcrud_*`.
- **AD-2 / AD-15 / NFR-U2** : **aucun** gestionnaire d'état / routeur importé ; `showDialog` + `Navigator.pop` uniquement.
- **AD-13 / NFR-U4/U5** : RTL (`*Directional`, `TextAlign.start/end`), `Semantics`, ≥48dp, couleur jamais seul canal, thème & l10n injectés — testé LTR/RTL + light/dark.
- **AD-10 / NFR-U10** : défauts sûrs (`ZContentStateView` replis `SizedBox.shrink()` ; `showZConfirmDialog` `?? false`), **jamais de throw**.
- **AD-12 / NFR-U8** : zéro secret (`gate:secrets` vert).
- **NFR-U7 (enums > booléens)** : `ZContentState` remplace les combinaisons de bools ; `ZConfirmTone` remplace un `bool isDestructive`.
- **NFR-U11** : pas de codegen — confirmer le no-op de `melos run generate`.

### Project Structure Notes

- Le package suit `lib/<pkg>.dart` (barrel) + `lib/src/{domain,presentation}` comme tous les packages du monorepo.
- `zcrud_ui_kit` **dépend de `zcrud_core`** (comme `zcrud_responsive` depuis l'Amendement E3-4) — arête entrante au cœur, `CORE OUT=0` intact.
- `melos.yaml` glob `packages/**` : **seul** ajout de déclaration = 1 ligne dans `pubspec.yaml` racine (`workspace:`).

### Dépendances aval (ce que cette story débloque / précède)

`done` sur EX-UI.7 **crée `zcrud_ui_kit`** et débloque, **séquentiellement** (même barrel/pubspec) : **EX-UI.8** (port `ZToaster` + `ZToastSeverity` + impl `ScaffoldMessenger`), **EX-UI.9** (`ZDiscardChangesGuard` lié au dirty du `ZFormController`), **EX-UI.10** (`ZAlphabetIndexBar` + transitions RTL-aware). Ces 3 stories **étendent** le barrel/pubspec de ce package ⇒ non parallélisables entre elles.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.7 (l.304-328), § Séquencement P3∥P2 (l.94-99), § NFR-U2/U7/U11 (l.47-56), § Traçabilité AD-32 (l.68), § Deferred/Assumptions (l.446-461)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § AD-32 (l.104-107 : états + `ZConfirmDialog` dark-mode/thème injecté, toast=port), § AD-29 (l.89-92), § AD-1/AD-2/AD-13 (l.55-58), § Amendement E3-4/CORE OUT=0 (l.83-87), § Enums>booléens (l.118), § Interdits (l.133), § Traçabilité ui-kit (l.190-193, l.202)]
- [Source: `packages/zcrud_core/lib/zcrud_core.dart:109,156,160,161` (exports `ZcrudScope`/`ZcrudTheme`/`ZcrudLocalizations`) ; `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:74-96` (`ZcrudTheme.fallback` dérive du `ColorScheme`, aucun hex) ; `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:48,81,168` (`ZcrudScope`/`theme`/`of`)]
- [Source: `packages/zcrud_responsive/{pubspec.yaml,analysis_options.yaml,lib/zcrud_responsive.dart}` (patron de scaffolding, EX-UI.1)]
- [Source: `_bmad-output/implementation-artifacts/stories/ex-ui-1-scaffolding-responsive-breakpoints.md` (modèle de story de scaffolding : point de déclaration `workspace:`, `graph_proof`, no-op codegen)]
- [Source: best-of-breed LECTURE SEULE — dodlp `state_widgets.dart` / `forms_utils.dart:271` `buildConfirmDialog` ; iffd `forms_utils.dart:455` `buildConfirmDialog` + empty-states dupliqués (`explore/dodlp.md`, `explore/iffd.md`)]
- [Source: `CLAUDE.md` — Key Don'ts (AD-1/AD-2/AD-13 : jamais de manager dans un paquet pur, primitives directionnelles, `const`, `Semantics` ≥48dp), naming préfixe `Z`, gates CI (secrets/anti-reflectable/codegen)]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Domaine pur** (sans `BuildContext`) | `ZContentState.values.length == 5`, `.name` camelCase | AC2, D2 |
| **Widget** (light + dark) | Chaque état rend icône + message + CTA ; texte présent même sans icône ; `Semantics` | AC3, AC7 |
| **Widget** | `ZContentStateView` aiguille chaque valeur → bonne tranche ; `success`→builder ; replis `ZLoadingState`/`SizedBox.shrink` | AC4, D4 |
| **Widget** (dark) | `ZConfirmDialog` rend titre/message/2 actions ; confirm→`true`, cancel→`false`, barrier→`false` ; labels `MaterialLocalizations` ; `destructive`→`ColorScheme.error` | AC5, AC6, D5 |
| **Widget** (RTL) | États + dialog sous `Directionality.rtl` (aucune exception, directionnel) ; `Semantics` ; ≥48dp | AC7, AD-13 |
| **Graphe / gates** | `graph_proof` ACYCLIQUE / CORE OUT=0 ; `dart analyze` RC=0 ; `generate` no-op ; `melos list` = N+1 ; `gate:secrets` vert | AC8, NFR-U1/U11 |

**Definition of Done** : AC1→AC8 verts · `pubspec.yaml` = `flutter` + `zcrud_core: ^0.2.0` **uniquement** (aucun autre `zcrud_*`, aucun manager/routeur/tiers) · **aucun symbole `zcrud_core` redéclaré** · `ZContentState`/`ZConfirmTone` = enums (aucun `bool` multi-état) · couleurs **dérivées du `ColorScheme`** (aucun hex/`k*Color*`) · textes injectés (aucune chaîne métier en dur ; labels dialog via `MaterialLocalizations`) · RTL + a11y (`Semantics`, ≥48dp, directionnel) testés · `showZConfirmDialog` retourne `true`/`false` (barrier→`false`) · `melos run generate` (no-op) + `dart analyze` RC=0 ; `melos run analyze`/`verify` **repo-wide** délégués à l'orchestrateur · `graph_proof` ACYCLIQUE/CORE OUT=0 · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

- 1 échec test initial `z_rtl_a11y_test.dart` : `find.bySemanticsLabel('Vide. Aucun élément')` (String, égalité stricte) renvoyait 0 car le `Semantics(container:true, label:)` fusionnait les libellés des `Text` enfants dans le nœud → label pollué (diagnostiqué par dump du semantics tree ; RegExp `contains` matchait, String exact non). **Correction** (meilleur a11y, pas un contournement de test) : le bloc informationnel (icône+titre+message) est enveloppé dans `ExcludeSemantics`, le `Semantics(label:)` explicite porte alors SEUL l'annonce (évite la double lecture), le CTA restant HORS de l'exclusion (garde sa sémantique cliquable). Test re-vert.

### Completion Notes List

- Package NEUF `zcrud_ui_kit` (17e produit) : scaffolding calqué sur `zcrud_responsive` (`publish_to:none`, `resolution:workspace`, `sdk ^3.12.2`, `zcrud_core:^0.2.0` + `flutter` uniquement — AUCUN gestionnaire d'état/routeur/tiers/dartz).
- Domaine : `ZContentState { idle, loading, empty, error, success }` + `ZConfirmTone { neutral, destructive }` — enums camelCase, non sérialisés (pas de `@JsonKey`/`.g.dart`), honorant NFR-U7 (« enums > booléens », remplacent `isLoading`/`hasError`/`isEmpty` et `bool isDestructive`).
- Présentation : `ZEmptyState`/`ZLoadingState`/`ZErrorState` (`const`, couleurs dérivées du `ColorScheme`/`ZcrudTheme.of` — AUCUN hex, textes injectés, `Semantics`, cibles ≥48dp, `EdgeInsetsDirectional`) ; `ZContentStateView` (`switch` exhaustif SANS `default`, replis sûrs `ZLoadingState()`/`SizedBox.shrink()`, jamais de throw) ; `ZConfirmDialog` + `showZConfirmDialog → Future<bool>` (`?? false` défaut sûr, labels par défaut via `MaterialLocalizations`, teinte confirm `ColorScheme.error` en `destructive`/`primary` en `neutral`, `showDialog`+`Navigator.pop` — aucun manager).
- Barrel exporte les 4 fichiers `src/` ; NE ré-exporte PAS `zcrud_core` (D7).
- Décisions D1..D7 confrontées au code réel : aucune contredite. Q1 (enum `ZConfirmTone`) et Q2 (pas de ré-export) tranchées conformément à la recommandation de la story.
- **Vérifs rejouées (RC réels)** : `dart pub get` RC=0 ; `melos run generate` SUCCESS (no-op pour ui_kit, 0 `.g.dart`) ; `dart analyze packages/zcrud_ui_kit` « No issues found! » (RC=0, zéro warning) ; `flutter test` 28 tests PASS (RC=0) ; `graph_proof.py` ACYCLIQUE + CORE OUT=0 (`zcrud_ui_kit → zcrud_core`, 1 sortante, 0 entrante) ; `melos list` 22 → 23 (N+1). Zéro couleur codée en dur, zéro import manager/routeur/tiers (grep), zéro écriture hors `packages/zcrud_ui_kit/` + 1 ligne `workspace:` du pubspec racine.
- `melos run analyze`/`verify` REPO-WIDE délégués au gate de commit d'epic de l'orchestrateur (hors périmètre dev).

### File List

- `packages/zcrud_ui_kit/pubspec.yaml` (NEW)
- `packages/zcrud_ui_kit/analysis_options.yaml` (NEW)
- `packages/zcrud_ui_kit/README.md` (NEW)
- `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (NEW)
- `packages/zcrud_ui_kit/lib/src/domain/z_content_state.dart` (NEW)
- `packages/zcrud_ui_kit/lib/src/domain/z_confirm_tone.dart` (NEW)
- `packages/zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart` (NEW)
- `packages/zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_content_state_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_state_widgets_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_content_state_view_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_confirm_dialog_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_rtl_a11y_test.dart` (NEW)
- `pubspec.yaml` (racine, UPDATE — 1 ligne `- packages/zcrud_ui_kit` + commentaire dans `workspace:`)

### Questions pour l'orchestrateur (remontées, non bloquantes pour le dev)

1. **`ZConfirmTone` (AC6)** : ajout d'un enum `{ neutral, destructive }` (non nommé dans l'épic) pour honorer NFR-U7 « enums > booléens » là où dodlp/iffd utilisaient un flag/couleur ad hoc. À confirmer, ou repli sur un `bool isDestructive` (prédicat strictement binaire, exception NFR-U7 documentée comme `isDirty`). **Recommandation : enum.**
2. **Ré-export `zcrud_core` (D7)** : contrairement à EX-UI.1, ce barrel **ne ré-exporte pas** `zcrud_core` (aucun type du cœur central à la surface d'API). À valider si un confort de ré-export (`ZcrudScope`) est souhaité pour les consommateurs.
