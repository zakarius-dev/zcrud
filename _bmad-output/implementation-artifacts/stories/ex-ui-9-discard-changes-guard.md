---
baseline_commit: 709406d
---

# Story EX-UI.9 : `ZDiscardChangesGuard` — garde anti-perte de saisie (`PopScope`) liée au dirty du `ZFormController`

Status: review

- **Clé sprint-status** : `ex-ui-9-discard-changes-guard`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit)
- **Taille** : **M** (package DÉJÀ livré `zcrud_ui_kit` : +1 widget `PopScope` neuf + 1 `export` dans le barrel ; réutilise `showZConfirmDialog` (EX-UI.7) ; 0 codegen, 0 entité persistée, 0 nouvelle dépendance).
- **Parallélisation** : **PARALLÉLISABLE (P3 ∥ P2, ≤ 3 avec EX-UI.7/8/10)** — package `zcrud_ui_kit`, fichier **neuf** disjoint. **Seul point de contact = `zcrud_core` en LECTURE SEULE** (API publique du `ZFormController` : le `ValueListenable<bool>` `isDirty`), **aucune écriture du cœur** → aucune contention de contact. ⚠️ **Étend le barrel** partagé avec EX-UI.7 (livré) / EX-UI.8 (livré) / EX-UI.10 ⇒ ces stories **sérialisées entre elles** (barrel séquentiel), même si le package est parallélisable vis-à-vis de P2.
- **Package écrit (disjoint)** : `packages/zcrud_ui_kit/` **UNIQUEMENT** (1 fichier neuf + 1 ligne d'`export` dans le barrel `lib/zcrud_ui_kit.dart` + 1 paragraphe dartdoc). ⛔ **N'ÉCRIT PAS `zcrud_core`** (ni aucun autre `zcrud_*`) — il **le CONSOMME** en lecture (`ZFormController.isDirty`). ⛔ **NE TOUCHE PAS** `pubspec.yaml` (dépendances déjà OK depuis EX-UI.7 : `zcrud_core` + `flutter`), ni `pubspec.yaml` racine, ni `melos.yaml`.
- **AD delta** : **AD-32** (patterns génériques UI — `ZDiscardChangesGuard` (`PopScope`) **consomme l'état dirty du `ZFormController`** via son `Listenable`/`ValueListenable`, **jamais** un manager ; **seul** point de contact fonctionnel avec le cœur, via l'**API publique** du controller). **AD hérités** : **AD-1** (acyclique, `CORE OUT=0` — l'arête `zcrud_ui_kit → zcrud_core` est **ENTRANTE au cœur**, licite ; EX-UI.9 n'ajoute **aucune** arête), **AD-2/AD-15** (Flutter-native, **AUCUN gestionnaire d'état** — le `ConsumerWidget`/`WidgetRef` mort de lex est **retiré**), **AD-25/SM-1/NFR-U3** (rebuild **ciblé** : le garde n'écoute que la **tranche `isDirty`** via `ValueListenableBuilder`, jamais un `setState` à l'échelle page), **AD-6** (composition avec le seam de dialog `showZConfirmDialog`), **AD-13** (RTL / a11y / thème & labels injectés), **AD-10** (défaut sûr : `showZConfirmDialog(...) ?? false`, jamais de throw). **Consigne transverse NFR-U7** : *enums > booléens* — `isDirty` reste le **seul `bool` toléré** (prédicat strictement binaire, exception explicitement documentée par l'epic) ; le résultat du dialog reste `bool` (discard/annuler strictement binaire).

---

## Story

**As a** utilisateur en cours d'édition d'un formulaire zcrud,
**I want** un garde (`PopScope`) `ZDiscardChangesGuard` qui **intercepte toute tentative de sortie** tant que le formulaire est « sale » (dirty) — l'état dirty étant **lu** du `ZFormController` de `zcrud_core` via son `ValueListenable<bool>` (abonnement en **écoute seule**, aucune mutation) — et **propose une confirmation** (via `showZConfirmDialog` d'EX-UI.7) avant de perdre la saisie,
**so that** je ne perde **jamais** ma saisie par une sortie accidentelle (geste retour Android, `Esc`, bouton retour d'AppBar), **sans** qu'aucun gestionnaire d'état ne soit réintroduit (contrairement au `ConsumerWidget` mort de lex), le garde ne reconstruisant **que sa tranche** au flip dirty (SM-1 intact), et étant directionnel/a11y (AD-13).

---

## Contexte — vérifié sur disque (pas sur la seule foi de l'épic)

### État réel du package `zcrud_ui_kit` (EX-UI.7 + EX-UI.8 livrés, `review`)

Vérifié sur disque :
- `packages/zcrud_ui_kit/pubspec.yaml` : `dependencies` = **`zcrud_core` + `flutter`** UNIQUEMENT ; `dev_dependencies` = `flutter_test`. ⛔ **AUCUNE modification requise** (le garde n'ajoute aucune dépendance — Flutter pur + consommation de l'API publique de `zcrud_core` déjà présente).
- Barrel `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (`library;`) : exporte déjà (ordre alphabétique) `z_confirm_tone.dart`, `z_content_state.dart`, `z_toast_severity.dart`, `z_toaster.dart`, `z_confirm_dialog.dart`, `z_scaffold_messenger_toaster.dart`, `z_state_widgets.dart`, `z_toaster_scope.dart`. ⇒ EX-UI.9 **ajoute UN** `export 'src/presentation/z_discard_changes_guard.dart';` (à sa place alphabétique dans le bloc `presentation`) + **complète le dartdoc de barrel** d'un paragraphe EX-UI.9. ⛔ Ne PAS ré-exporter `zcrud_core` ; ⛔ ne PAS retirer/réordonner les exports EX-UI.7/8.
- Le package est **déjà déclaré** au bloc `workspace:` du `pubspec.yaml` racine ⇒ **rien à ajouter** ; `melos list` **inchangé** (aucun nouveau package).

### Ce que `zcrud_core` EXPOSE DÉJÀ (à CONSOMMER en LECTURE, jamais réécrire)

Vérifié dans `packages/zcrud_core/lib/src/presentation/z_form_controller.dart` (`class ZFormController extends ChangeNotifier`, exporté par le barrel `zcrud_core.dart`) :

| Symbole `zcrud_core` | Emplacement | Usage EX-UI.9 |
|---|---|---|
| `ValueListenable<bool> get isDirty` (`z_form_controller.dart:161`) | canal *dirty* **dédié** (`ValueNotifier<bool> _isDirty`, `:79`) | **Source unique** de l'état dirty du garde. Canal **CIBLÉ** : « ne notifie JAMAIS les tranches ni le `notifyListeners()` global » (dartdoc `:76-78`) — c'est **exactement** le canal à écouter pour un rebuild granulaire (SM-1/NFR-U3). Le garde s'y **abonne en lecture seule** (`ValueListenableBuilder<bool>`), **aucune** mutation. |
| `void setValue(...)` → `_updateDirty(...)` (`:127,135`) | mécanique interne | ⛔ **NON appelée** par le garde. Le garde **lit** `isDirty`, il ne le pilote pas. |
| `markPristine()` / `reset()` (`:178,189`) | remise à `false` du dirty | Contexte : le flip `dirty→clean` (après save réussi) fait passer `isDirty.value` à `false` ⇒ le garde doit **réagir** (rebuild de sa tranche → `canPop` repasse à `true`). Testé (AC5). |

⚠️ **`isDirty` renvoie un `ValueListenable<bool>`** (pas un `bool` nu, pas un `Listenable` opaque) — l'API du garde **doit** accepter cette forme précise (cf. D2). ⛔ **Aucun** symbole `zcrud_core` n'est redéclaré/ré-exporté ; ⛔ **aucun** fichier de `zcrud_core` n'est modifié.

### Patrons internes DÉJÀ établis (EX-UI.7/8, à réutiliser — cohérence)

- **`showZConfirmDialog(context, {required title, required message, confirmLabel?, cancelLabel?, tone})`** (`z_confirm_dialog.dart:104`) : retourne `Future<bool>` (`?? false` — défaut sûr AD-10, jamais de throw), **aucun** gestionnaire d'état (`showDialog` + `Navigator.pop`). ⇒ **RÉUTILISER TEL QUEL** pour la confirmation du discard (ne PAS réinventer un `AlertDialog` comme le fait lex). `tone: ZConfirmTone.destructive` (la perte de saisie est destructive).
- **A11y défensif / labels injectés** (`z_confirm_dialog.dart`, `z_state_widgets.dart`) : labels via l'appelant / `MaterialLocalizations`, jamais de chaîne métier codée en dur non surchargeable. `Semantics` explicites, directionnel.
- **Barrel** exporte `src/...`, ne ré-exporte pas `zcrud_core`.

### Best-of-breed à NEUTRALISER (LECTURE SEULE — apps hors périmètre, ne PAS copier tel quel)

- **lex** `apps/lex_douane_admin/lib/presentation/widgets/common/discard_changes_guard.dart` (85 LOC) : bon squelette `PopScope` (`canPop: !isDirty()`, `onPopInvokedWithResult` → confirm → `navigator.pop`, `onDiscarded` avant pop, garde `navigator.mounted`). **À neutraliser** :
  1. ⛔ **`ConsumerWidget` + `WidgetRef ref` MORTS** (`import 'package:flutter_riverpod/flutter_riverpod.dart';`, `build(context, ref)` où `ref` est **inutilisé**) → **`StatelessWidget` pur** (AD-2/AD-15/NFR-U2 : **aucun** import manager).
  2. ⛔ **`AlertDialog` inline dupliqué** (`_confirmDiscard`) → **`showZConfirmDialog`** (EX-UI.7), factorisé, thémé, dark-mode-aware.
  3. ⛔ **`isDirty` = `bool Function()`** (callback ré-évalué au pop, **pas réactif**) → **`ValueListenable<bool>`** (le canal `ZFormController.isDirty`), abonnement **réactif** via `ValueListenableBuilder` : `canPop` reflète l'état **courant** ET se met à jour au flip (rebuild ciblé, SM-1).
  4. ⛔ **Labels français codés en dur** (`'Modifications non enregistrées'`, …) → **optionnels/surchargeables**, repli sur `MaterialLocalizations` / labels injectés (AD-13/NFR-U5).

### ⛔ Hors périmètre (défini par d'autres stories — NE PAS implémenter ici)

- **EX-UI.10** — `ZAlphabetIndexBar` + transitions de route **RTL-aware** (index/transitions). **Aucune** logique d'index ni de transition ici.
- **EX-UI.11** — présentateurs/toaster **manager** (GetX) dans `zcrud_get`. Le garde ici est **pur-Flutter** ; il ne connaît **aucun** manager.
- **Toute écriture de `zcrud_core`** : le garde **consomme** `isDirty` en lecture ; il n'ajoute **rien** au controller (pas de nouveau getter/canal). Si un besoin d'API cœur émergeait, **le remonter** — ne PAS écrire `zcrud_core` dans cette story.

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — Aucune nouvelle dépendance (AD-1/AD-29 ; AUCUN manager)

`pubspec.yaml` **inchangé** : `zcrud_core` + `flutter` suffisent. ⛔ **AUCUN** `flutter_riverpod`/`get`/`provider`/`go_router`/`toastification`/`dartz`. Le garde est du **Flutter pur** + la consommation en lecture de l'API publique de `zcrud_core` (déjà tirée). L'arête reste `zcrud_ui_kit → zcrud_core` (entrante au cœur, `CORE OUT=0` intact, `graph_proof.py` ACYCLIQUE — **inchangé** par EX-UI.9).

### D2 — API : `isDirty` = `ValueListenable<bool>` (le canal du `ZFormController`), abonnement RÉACTIF

Fichier `lib/src/presentation/z_discard_changes_guard.dart`. Signature de référence (le dev ajuste si le code l'impose, en **gardant** `isDirty` typé `ValueListenable<bool>` et **aucun** manager) :

```dart
class ZDiscardChangesGuard extends StatelessWidget {
  const ZDiscardChangesGuard({
    super.key,
    required this.isDirty,      // typiquement `controller.isDirty` (ZFormController, zcrud_core)
    required this.child,
    this.title,                 // optionnel — repli l10n/label injecté (AD-13)
    this.message,               // optionnel
    this.confirmLabel,          // optionnel — repli MaterialLocalizations
    this.cancelLabel,           // optionnel
    this.onDiscard,             // optionnel — appelé juste AVANT le pop effectif
  });

  final ValueListenable<bool> isDirty;
  final Widget child;
  final String? title;
  final String? message;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onDiscard;
  // ...
}
```

- **Pourquoi `ValueListenable<bool>` et pas `ZFormController` en champ** : (1) l'API cœur `ZFormController.isDirty` **est** un `ValueListenable<bool>` (vérifié `:161`) → l'appelant passe `controller.isDirty`, contact **strictement lecture seule** (le garde n'a **aucune** poignée de mutation du controller) ; (2) découplage maximal (le garde teste facilement avec un `ValueNotifier<bool>` nu) ; (3) **aucun** import de `ZFormController` requis dans le garde (le type `ValueListenable` vient de `package:flutter/foundation.dart`). ⇒ le contact avec `zcrud_core` est **prouvé lecture-seule** et **minimal**. Documenter dans le dartdoc que la source **canonique** est `ZFormController.isDirty`.
- **Pourquoi `ValueListenable` (réactif) et pas `bool Function()`** (lex) : `canPop` du `PopScope` doit refléter l'état **courant** ET se **mettre à jour** quand le dirty flippe (ex. `clean` après save réussi → sortie directe sans dialog). Un callback n'est ré-évalué qu'au pop ; un `ValueListenable` via `ValueListenableBuilder` **rebuild la tranche** au flip (SM-1/AD-25, cf. D3).

### D3 — Rebuild CIBLÉ : `ValueListenableBuilder<bool>` autour du `PopScope` (SM-1/AD-25/NFR-U3)

Le garde enveloppe **le seul `PopScope`** dans un `ValueListenableBuilder<bool>(valueListenable: isDirty, child: child, builder: ...)`, et **passe `child` par le paramètre `child` du builder** (le sous-arbre protégé **n'est PAS reconstruit** au flip dirty — seul le `PopScope` (dont `canPop`) l'est). ⛔ **AUCUN** `setState` à l'échelle page ; ⛔ **aucune** reconstruction du `child`. C'est la matérialisation de l'objectif produit n°1 (rebuild granulaire) : écouter la **tranche `isDirty` dédiée** (qui, par conception cœur `:76-78`, ne déclenche ni les tranches de champ ni le `notifyListeners()` global).

### D4 — Logique `PopScope` : intercepter si dirty, confirmer, pop si confirmé (défaut sûr)

- `canPop: !isDirty.value` (dans le `builder`, donc recalculé au flip).
- `onPopInvokedWithResult: (didPop, result) async { if (didPop) return; ... }` : si `didPop` (déjà sorti — cas non-dirty), **ne rien faire**. Sinon (bloqué car dirty) :
  1. Capturer `Navigator.of(context)` **avant** l'`await` (garde `mounted` après).
  2. `final shouldDiscard = await showZConfirmDialog(context, title: title ?? <repli>, message: message ?? <repli>, confirmLabel: confirmLabel, cancelLabel: cancelLabel, tone: ZConfirmTone.destructive);` (réutilise EX-UI.7 ; `?? false` interne → **jamais de throw**, AD-10).
  3. `if (shouldDiscard) { onDiscard?.call(); if (navigator.mounted) navigator.pop(result); }` — sinon **rester** (aucune sortie).
- **Non-dirty** : `canPop == true` ⇒ le framework **pop directement**, `onPopInvokedWithResult` reçoit `didPop == true` ⇒ **aucun dialog** (AC2/AC4). L'`onDiscard` **n'est PAS** appelé sur une sortie propre (rien à jeter).
- **`use_build_context_synchronously`** : capturer `navigator` avant l'`await` et re-tester `navigator.mounted` (idiome lex conservé) pour rester `analyze` RC=0.

### D5 — Labels : optionnels, injectés, repli sûr (AD-13/NFR-U5)

`title`/`message`/`confirmLabel`/`cancelLabel` **optionnels** (`String?`). ⛔ **Aucune** chaîne métier française codée en dur et non surchargeable (contrairement à lex). Replis sûrs : `confirmLabel`/`cancelLabel` → `showZConfirmDialog` retombe déjà sur `MaterialLocalizations` (l10n) quand `null` (vérifié EX-UI.7) ; `title`/`message` → si l'appelant ne fournit rien, fournir un **repli neutre non-nul** (ex. libellés génériques via un fallback documenté — jamais un label `null` passé au dialog, jamais une chaîne métier spécifique app). Le dev tranche le repli exact et le consigne. Directionnel : rien de positionnel ici (le garde n'a pas de layout propre — il enveloppe `child`), mais **aucun** `EdgeInsets.only(left:/right:)` / `Alignment.centerLeft/Right` ne doit apparaître (AD-13).

### D6 — Aucun codegen, aucune sérialisation (NFR-U11)

`ZDiscardChangesGuard` est **UI-pur**, **non persisté** → **aucun `@ZcrudModel`/`@JsonSerializable`/`part`** ⇒ pas de `*.g.dart`, `melos run generate` **no-op** pour ce package, gate `codegen-distribution` **non concernée**. Confirmer le no-op (AC6).

### D7 — Barrel = SEULE API publique (extension de l'existant)

`lib/zcrud_ui_kit.dart` **ajoute** (place alphabétique dans le bloc `presentation`, entre `z_confirm_dialog.dart` et `z_scaffold_messenger_toaster.dart`) : `export 'src/presentation/z_discard_changes_guard.dart';` + un paragraphe dartdoc EX-UI.9. ⛔ **Ne PAS** ré-exporter `zcrud_core`. ⛔ **Ne PAS** retirer/réordonner les exports EX-UI.7/8.

---

## Acceptance Criteria

### AC1 — Consommation LECTURE SEULE du dirty via `ValueListenable`, JAMAIS un manager (AD-32/AD-2/NFR-U2)
**Given** un `ZFormController` de `zcrud_core` exposant `ValueListenable<bool> get isDirty`,
**When** on construit `ZDiscardChangesGuard(isDirty: controller.isDirty, child: ...)`,
**Then** le garde **s'abonne en écoute seule** au `ValueListenable<bool>` (API publique du controller) — **aucune** mutation du controller, **aucun** import de gestionnaire d'état (`flutter_riverpod`/`get`/`provider`), **aucun** `WidgetRef`/`Get.find`/`Provider.of`,
**And** `ZDiscardChangesGuard` est un **`StatelessWidget`** (le `ConsumerWidget`/`WidgetRef` mort de lex est **retiré**), et le fichier n'importe que `package:flutter/*` + (au plus) `zcrud_ui_kit` interne — **aucun** import `zcrud_core` n'est requis (le type `ValueListenable` vient de `foundation.dart`).

### AC2 — Formulaire propre → sortie directe, aucun dialog (AD-10)
**Given** `isDirty.value == false`,
**When** l'utilisateur tente de sortir (pop),
**Then** `canPop == true` ⇒ le framework **pop directement**, `onPopInvokedWithResult` reçoit `didPop == true` et **ne déclenche AUCUN dialog** ni `onDiscard`,
**And** aucune saisie n'existant, la sortie est immédiate (repli sûr).

### AC3 — Formulaire dirty → `PopScope` intercepte + confirmation via `showZConfirmDialog` (AD-32/AD-6)
**Given** `isDirty.value == true`,
**When** l'utilisateur tente de sortir,
**Then** `canPop == false` ⇒ le `PopScope` **bloque** la sortie et `onPopInvokedWithResult` (`didPop == false`) **déclenche `showZConfirmDialog`** (EX-UI.7, `tone: ZConfirmTone.destructive`) — ⛔ **pas** un `AlertDialog` inline dupliqué,
**And** le dialog utilise les labels injectés (`title`/`message`/`confirm`/`cancel`) avec replis sûrs (l10n / neutres), **sans** gestionnaire d'état.

### AC4 — Confirmer → pop effectué + `onDiscard` appelé ; Annuler → reste (AD-10)
**Given** le dialog de confirmation affiché (formulaire dirty),
**When** l'utilisateur **confirme** (discard),
**Then** `onDiscard?.call()` est invoqué **puis** `Navigator.pop(result)` est exécuté (garde `navigator.mounted`) — la sortie a lieu,
**And When** l'utilisateur **annule** (ou ferme par barrier — `showZConfirmDialog(...) ?? false`),
**Then** **aucun** pop n'a lieu (on **reste** dans le formulaire) et `onDiscard` **n'est PAS** appelé.

### AC5 — Réactivité au flip `dirty→clean` : rebuild CIBLÉ de la tranche (SM-1/AD-25/NFR-U3)
**Given** le garde abonné à `isDirty` via `ValueListenableBuilder<bool>`,
**When** l'état passe de `dirty` à `clean` (ex. `controller.markPristine()` après save réussi) — et inversement,
**Then** le garde **rebuild sa seule tranche** (le `PopScope`, dont `canPop` repasse à `true`) **sans** reconstruire le `child` protégé (passé via le paramètre `child` du builder) et **sans** `setState` à l'échelle page,
**And** après flip vers `clean`, une nouvelle tentative de sortie **pop directement** (plus de dialog) — la réactivité est prouvée par test.

### AC6 — Graphe inchangé, gates verts, RTL/a11y, codegen no-op (AD-1/AD-13/NFR-U1/NFR-U11)
**Given** l'extension `zcrud_ui_kit`,
**When** on inspecte le graphe et rejoue les gates,
**Then** `zcrud_ui_kit` conserve **exactement une** arête `zcrud_*` **sortante** (`→ zcrud_core`) et **zéro** entrante ; `CORE OUT=0` intact ; `graph_proof.py` reste **ACYCLIQUE** (EX-UI.9 n'ajoute **aucune** dépendance — D1),
**And** le garde est **directionnel** (⛔ aucun `EdgeInsets.only(left:/right:)`/`Alignment.centerLeft/Right`/`TextAlign.left/right`) et fonctionne sous `Directionality.rtl` sans exception ; l'a11y du dialog est héritée de `showZConfirmDialog` (EX-UI.7),
**And** `melos run generate` est un **no-op** (aucun `@ZcrudModel` — NFR-U11), gate `codegen-distribution` **non concernée** ; `dart analyze packages/zcrud_ui_kit` **RC=0** ; `melos run analyze`/`verify` **repo-wide** délégués au gate de commit d'epic de l'orchestrateur ; `gate:secrets` vert (zéro secret — AD-12) ; `melos list` **inchangé**.

---

## Tasks / Subtasks

- [x] **T1 — Présentation : le garde** (AC1..AC5, D2, D3, D4, D5) — `lib/src/presentation/z_discard_changes_guard.dart`
  - [x] T1.1 `class ZDiscardChangesGuard extends StatelessWidget` (`const` ctor) ; champs `ValueListenable<bool> isDirty`, `Widget child`, `String? title/message/confirmLabel/cancelLabel`, `VoidCallback? onDiscard`. ⛔ Aucun import manager. Import `package:flutter/foundation.dart` pour `ValueListenable`.
  - [x] T1.2 `build` → `ValueListenableBuilder<bool>(valueListenable: isDirty, child: child, builder: (context, dirty, child) => PopScope(canPop: !dirty, onPopInvokedWithResult: ..., child: child!))` — `child` passé par le param (non reconstruit, D3).
  - [x] T1.3 `onPopInvokedWithResult` : `if (didPop) return;` ; capturer `navigator` avant `await` ; `showZConfirmDialog(..., tone: ZConfirmTone.destructive)` ; si `true` → `onDiscard?.call()` puis `if (navigator.mounted) navigator.pop(result)` (D4 ; `use_build_context_synchronously` OK).
  - [x] T1.4 Labels optionnels avec replis sûrs (jamais un label `null` au dialog, jamais une chaîne métier app codée en dur) ; dartdoc : source canonique `ZFormController.isDirty`, lecture seule, exception `bool` (NFR-U7), réutilisation `showZConfirmDialog`.

- [x] **T2 — Barrel** (AC1..AC5, D7) — `lib/zcrud_ui_kit.dart`
  - [x] T2.1 Ajout de `export 'src/presentation/z_discard_changes_guard.dart';` (place alphabétique) + paragraphe dartdoc EX-UI.9. Pas de ré-export `zcrud_core` ; exports EX-UI.7/8 intacts.

- [x] **T3 — Tests** (AC1..AC5) — chemins `packages/zcrud_ui_kit/test/`
  - [x] T3.1 `test/z_discard_changes_guard_test.dart` (widget) :
    - non-dirty (`ValueNotifier<bool>(false)`) → tentative de pop ⇒ **pop direct**, **aucun** `ZConfirmDialog`, `onDiscard` **non** appelé (AC2).
    - dirty (`true`) → tentative de pop ⇒ `PopScope` **empêche** la sortie + `showZConfirmDialog`/`ZConfirmDialog` **affiché** (AC3).
    - dirty → **confirmer** ⇒ pop **effectué** + `onDiscard` **appelé** une fois (AC4).
    - dirty → **annuler** ⇒ **reste** (pas de pop) + `onDiscard` **non** appelé (AC4).
  - [x] T3.2 `test/z_discard_changes_guard_reactivity_test.dart` (widget) : abonnement au `ValueListenable` ; flip `true→false` (via `notifier.value = false`, façon `markPristine`) ⇒ `canPop` repasse à `true` / nouvelle sortie **pop direct** sans dialog ; **le `child` n'est pas reconstruit** au flip (compteur de build du child inchangé — SM-1/AC5).
  - [x] T3.3 (optionnel, si utile) RTL : garde sous `Directionality.rtl` sans exception ; **aucun** import manager dans le fichier source (assertion statique/inspection).

- [x] **T4 — Vérif verte + graphe** (AC6)
  - [x] T4.1 `dart run melos run generate` → SUCCESS (no-op : 0 `.g.dart` ajouté).
  - [x] T4.2 `dart analyze packages/zcrud_ui_kit` RC=0 (No issues found). `melos analyze`/`verify` repo-wide → orchestrateur.
  - [x] T4.3 `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK / CORE OUT=0 OK (`zcrud_ui_kit -> zcrud_core` seule arête, inchangée).
  - [x] T4.4 `flutter test` (package) → tous verts (EX-UI.7 + EX-UI.8 + nouveaux EX-UI.9).

---

## Dev Notes

### Fichiers à créer / modifier (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_ui_kit/lib/src/presentation/z_discard_changes_guard.dart` | NEW — `ZDiscardChangesGuard` (`PopScope` + `ValueListenableBuilder`) |
| `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` | **UPDATE** — +1 `export` + dartdoc EX-UI.9 |
| `packages/zcrud_ui_kit/test/z_discard_changes_guard_test.dart` | NEW — widget (dirty/propre/confirm/annuler) |
| `packages/zcrud_ui_kit/test/z_discard_changes_guard_reactivity_test.dart` | NEW — widget (flip dirty→clean, child non reconstruit) |

⛔ **NE PAS TOUCHER** : `packages/zcrud_ui_kit/pubspec.yaml` (dépendances déjà OK), `pubspec.yaml` racine, `melos.yaml`, les fichiers EX-UI.7/8 (`z_confirm_*`, `z_content_state`, `z_state_widgets`, `z_toast*`), **`packages/zcrud_core/**`** (consommé en LECTURE, jamais réécrit), `packages/zcrud_responsive/**`, `packages/zcrud_navigation/**`.

### Références de code (LECTURE SEULE)

- **`zcrud_core`** `packages/zcrud_core/lib/src/presentation/z_form_controller.dart:161` — `ValueListenable<bool> get isDirty` (canal dirty **dédié**, `:76-79` : ne notifie ni tranches ni global — parfait pour un rebuild ciblé). ⛔ Rien à redéclarer/écrire.
- **`zcrud_ui_kit`** (EX-UI.7, à réutiliser) : `z_confirm_dialog.dart:104` (`showZConfirmDialog` → `Future<bool>`, `?? false`, `ZConfirmTone`) ; `z_confirm_tone.dart` (`ZConfirmTone.destructive`).
- **lex** `apps/lex_douane_admin/lib/presentation/widgets/common/discard_changes_guard.dart` (LECTURE SEULE) : squelette `PopScope` best-of-breed à **neutraliser** (retirer `ConsumerWidget`/`ref` mort ; `AlertDialog` inline → `showZConfirmDialog` ; `bool Function()` → `ValueListenable<bool>` réactif ; labels codés en dur → optionnels/injectés).

### Invariants AD applicables (rappel ciblé)

- **AD-32** : `ZDiscardChangesGuard` (`PopScope`) **consomme l'état dirty du `ZFormController`** via son `Listenable`/`ValueListenable` — **seul** point de contact fonctionnel avec le cœur, via l'**API publique** ; **jamais** un manager. Réutilise `showZConfirmDialog` (pas de re-duplication).
- **AD-2 / AD-15 / NFR-U2** : **aucun** gestionnaire d'état / import manager ; le `ConsumerWidget`/`WidgetRef` mort de lex est **retiré** ; `StatelessWidget` pur.
- **AD-25 / SM-1 / NFR-U3** : rebuild **ciblé** — le garde n'écoute que la tranche `isDirty` (`ValueListenableBuilder`), `child` non reconstruit, **jamais** de `setState` à l'échelle page.
- **AD-6** : composition avec le seam de dialog `showZConfirmDialog`.
- **AD-10 / NFR-U10** : défaut sûr — `showZConfirmDialog(...) ?? false`, garde `navigator.mounted`, **jamais** de throw ; non-dirty → sortie directe.
- **AD-13 / NFR-U4/U5** : directionnel (⛔ jamais `left`/`right` positionnels) ; labels injectés/l10n ; a11y du dialog héritée d'EX-UI.7 ; testé LTR/RTL.
- **AD-1 / NFR-U1** : arête `zcrud_ui_kit → zcrud_core` **inchangée** (aucune dépendance ajoutée) ; `CORE OUT=0` ; `graph_proof.py` ACYCLIQUE.
- **AD-12 / NFR-U8** : zéro secret.
- **NFR-U7 (enums > booléens)** : `isDirty` = **seul `bool` toléré** (prédicat strictement binaire, exception documentée par l'epic EX-UI.9) ; le résultat du dialog reste `bool` (discard/annuler strictement binaire) ; `tone` du dialog reste un **enum** (`ZConfirmTone`).
- **NFR-U11** : pas de codegen — confirmer le no-op de `melos run generate`.

### Project Structure Notes

- Le garde vit sous `presentation/` (widget), conforme au Structural Seed « `ZDiscardChangesGuard` (lié au dirty `ZFormController`) ». Le contact avec `zcrud_core` est **une consommation en lecture** de `ValueListenable<bool>` — pas une écriture, pas une redéclaration.
- Barrel = seule API publique ; EX-UI.9 **étend** l'existant EX-UI.7/8 (barrel séquentiel — EX-UI.10 étendra encore).
- `zcrud_ui_kit` reste `→ zcrud_core` + flutter (arête entrante au cœur, `CORE OUT=0` intact).

### Dépendances aval (ce que cette story débloque)

`done` sur EX-UI.9 complète la surface **CAP-transverse UI** (avec EX-UI.7/8) ; il ne reste qu'**EX-UI.10** (`ZAlphabetIndexBar` + transitions RTL-aware) pour clore le workstream P3 `zcrud_ui_kit`. Le garde est directement consommable par le moteur d'édition (E3) et l'intégration DODLP (E7).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.9 (AC1-3 + tests), § Capability→Story Map (`ZDiscardChangesGuard` → `zcrud_ui_kit` + `zcrud_core`, AD-32/AD-2), § NFR-U1/U2/U3/U4/U7 (`isDirty` seul `bool` toléré), § Fenêtres de parallélisation (P3 ∥ P2, contact cœur en LECTURE)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § AD-32 (l.104-107 : `ZDiscardChangesGuard` (`PopScope`) consomme le dirty du `ZFormController` via `Listenable`, seul contact cœur, API publique, jamais un manager), § AD-2/AD-6/AD-13 (l.56-58), § Pureté & seams (l.119 : garde liée au dirty consommée via `Listenable`), § Consistency `ZDiscardChangesGuard` (l.115), § Structural Seed (l.154), § Capability Map garde (l.191), § Notes migration lex `DiscardChangesGuard` `ConsumerWidget` mort (l.202)]
- [Source: `packages/zcrud_core/lib/src/presentation/z_form_controller.dart:76-79,127,161,178` (`ValueListenable<bool> get isDirty`, canal dédié ; `markPristine`) ; barrel `packages/zcrud_core/lib/zcrud_core.dart` (`ZFormController` exporté)]
- [Source: `packages/zcrud_ui_kit/{lib/zcrud_ui_kit.dart, lib/src/presentation/z_confirm_dialog.dart:104}` (état livré EX-UI.7/8 ; `showZConfirmDialog` → `Future<bool>`, `ZConfirmTone.destructive`)]
- [Source: `_bmad-output/implementation-artifacts/stories/ex-ui-8-toaster-port-severity.md` (story modèle : scaffolding, no-op codegen, `graph_proof`, barrel séquentiel, structure ACs/Tasks/Dev Notes)]
- [Source: best-of-breed LECTURE SEULE — lex `apps/lex_douane_admin/lib/presentation/widgets/common/discard_changes_guard.dart` (`PopScope` + `ConsumerWidget` mort → à neutraliser) (`explore/lex.md` § Capacité 2 / Autres patterns)]
- [Source: `CLAUDE.md` — Key Don'ts (AD-2 : jamais de manager dans un paquet pur, `PopScope` sans `setState` global ; AD-13 : primitives directionnelles, `Semantics`, ≥48dp ; naming préfixe `Z` ; gates CI secrets/anti-reflectable/codegen)]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Widget** | non-dirty → tentative de pop ⇒ pop **direct**, aucun dialog, `onDiscard` non appelé | AC2 |
| **Widget** | dirty → tentative de pop ⇒ `PopScope` **bloque** + `ZConfirmDialog` affiché (via `showZConfirmDialog`) | AC3 |
| **Widget** | dirty → **confirmer** ⇒ `onDiscard` appelé + pop effectué ; **annuler** ⇒ reste, `onDiscard` non appelé | AC4 |
| **Widget** (réactivité) | flip `dirty→clean` (`notifier.value = false`) ⇒ `canPop` repasse `true` / nouvelle sortie directe ; **child non reconstruit** (compteur de build stable) | AC5, SM-1 |
| **Statique / RTL** | fichier source **sans** import manager (`riverpod`/`get`/`provider`) ; garde sous `Directionality.rtl` sans exception | AC1, AC6, AD-13 |
| **Graphe / gates** | `graph_proof` ACYCLIQUE / CORE OUT=0 (inchangé) ; `dart analyze` RC=0 ; `generate` no-op ; `melos list` inchangé ; `gate:secrets` vert | AC6, NFR-U1/U11 |

**Definition of Done** : AC1→AC6 verts · `pubspec.yaml` **inchangé** (`zcrud_core` + flutter, aucun manager) · `ZDiscardChangesGuard` = `StatelessWidget` pur (`ConsumerWidget`/`ref` mort de lex **retiré**), `isDirty` = `ValueListenable<bool>` consommé en **lecture seule** (`controller.isDirty`), `ValueListenableBuilder` (rebuild ciblé, `child` non reconstruit) · confirmation via `showZConfirmDialog` (EX-UI.7, `ZConfirmTone.destructive`) — pas d'`AlertDialog` inline · non-dirty → sortie directe ; dirty → intercepté + confirm ; confirmer → `onDiscard` + pop ; annuler → reste · labels optionnels/injectés (repli sûr, jamais `null` au dialog) · RTL + a11y OK · `zcrud_core` **jamais écrit** · `melos run generate` (no-op) + `dart analyze` RC=0 ; `melos run analyze`/`verify` **repo-wide** délégués à l'orchestrateur · `graph_proof` ACYCLIQUE/CORE OUT=0 · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

- Échec initial `dart analyze` : `Undefined class 'ValueListenable'` — `package:flutter/material.dart` ne ré-exporte PAS `ValueListenable` (show-list de widgets.dart). Corrigé par `import 'package:flutter/foundation.dart' show ValueListenable;` (source + tests), conforme à T1.1.
- Échec initial d'un test statique : `source.contains('flutter_riverpod')` capturait la **prose du dartdoc** (qui cite les managers neutralisés). Corrigé en ne scannant que les directives `import`.

### Completion Notes List

- `ZDiscardChangesGuard` = `StatelessWidget` pur. `ValueListenableBuilder<bool>` autour d'un `PopScope<Object?>` ; `child` passé via le paramètre `child` du builder ⇒ **non reconstruit** au flip dirty (SM-1, prouvé par compteur de builds).
- Contact `zcrud_core` **inexistant à l'import** : le type `ValueListenable` vient de `foundation.dart` ; l'appelant passe `controller.isDirty` (lecture seule). Aucune mutation du contrôleur, aucun import manager.
- Confirmation via `showZConfirmDialog(tone: ZConfirmTone.destructive)` (EX-UI.7 réutilisé) — pas d'`AlertDialog` réinventé. `?? false` interne (défaut sûr AD-10). `Navigator` capturé avant l'`await` + garde `navigator.mounted` (use_build_context_synchronously OK).
- Labels `title`/`message`/`confirmLabel`/`cancelLabel` optionnels ; replis neutres non-nuls (`defaultTitle`/`defaultMessage` génériques, surchargeables) — labels de boutons retombent sur `MaterialLocalizations`.
- Vérifs rejouées : `dart pub get` RC=0 ; `melos run generate` RC=0 (no-op, 0 `.g.dart`) ; `dart analyze packages/zcrud_ui_kit` RC=0 (No issues found) ; `flutter test` RC=0 (**62** tests : 53 antérieurs + 9 neufs) ; `graph_proof.py` ACYCLIQUE + CORE OUT=0 (arête `zcrud_ui_kit → zcrud_core` inchangée). `zcrud_core`/`pubspec`/`melos` non touchés.

### File List

- `packages/zcrud_ui_kit/lib/src/presentation/z_discard_changes_guard.dart` (NEW)
- `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (UPDATE — +1 export + dartdoc EX-UI.9)
- `packages/zcrud_ui_kit/test/z_discard_changes_guard_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_discard_changes_guard_reactivity_test.dart` (NEW)

### Questions pour l'orchestrateur (à remonter si besoin)

1. **Forme de `isDirty`** : la story fixe `ValueListenable<bool>` (= `ZFormController.isDirty`, contact lecture-seule minimal, aucun import `zcrud_core` requis dans le garde). Alternative écartée : passer `ZFormController` en champ (couplage inutile + surface de mutation). À confirmer si un usage exige la seconde forme (auquel cas ajouter un ctor nommé `.fromController` sans casser l'API principale).
2. **Repli `title`/`message`** : labels neutres génériques vs exiger l'appelant à fournir (rendre `required`). La story les rend optionnels avec repli sûr non-nul ; le dev tranche le libellé exact du repli (jamais une chaîne métier app).
