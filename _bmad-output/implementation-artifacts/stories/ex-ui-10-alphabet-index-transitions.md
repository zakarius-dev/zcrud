---
baseline_commit: 709406d
---

# Story EX-UI.10 : `ZAlphabetIndexBar` (index A→Z) + transitions de route **RTL-aware** — DERNIÈRE story `zcrud_ui_kit`

Status: review

- **Clé sprint-status** : `ex-ui-10-alphabet-index-transitions`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit)
- **Taille** : **S** (package DÉJÀ livré `zcrud_ui_kit` : 2 fichiers **NEUFS** disjoints + 1 enum de sens de transition + 2 `export` dans le barrel ; 0 codegen, 0 entité persistée, **0 nouvelle dépendance**, **0 écriture de `zcrud_core`**).
- **Parallélisation** : **PARALLÉLISABLE (P3 ∥ P2, ≤ 3)** — package `zcrud_ui_kit`, fichiers **neufs** disjoints (`z_alphabet_index_bar.dart`, `z_transitions.dart`). ⚠️ **Étend le barrel** partagé avec EX-UI.7/8/9 (tous livrés) ⇒ **barrel séquentiel** vis-à-vis d'eux (ici plus de contention : EX-UI.10 est la **dernière** story du package, elle **clôt** le barrel). Aucun contact avec `zcrud_core` (ni lecture ni écriture) : pur Flutter + thème injecté.
- **Package écrit (disjoint)** : `packages/zcrud_ui_kit/` **UNIQUEMENT** (2 fichiers neufs + 2 lignes d'`export` dans le barrel `lib/zcrud_ui_kit.dart` + paragraphe dartdoc EX-UI.10). ⛔ **N'ÉCRIT PAS `zcrud_core`** ni aucun autre `zcrud_*`. ⛔ **NE TOUCHE PAS** `pubspec.yaml` (dépendances déjà OK : `zcrud_core` + `flutter`), ni `pubspec.yaml` racine, ni `melos.yaml`.
- **AD delta** : **AD-32** (patterns génériques UI — `ZAlphabetIndexBar` + transitions RTL-aware fournis par `zcrud_ui_kit`, thème/couleurs/durées **injectés**, jamais un routeur, jamais un manager) + **AD-13** (RTL/a11y : le **sens du slide dépend de `Directionality.of(context)`** — LTR entre par la fin/droite, RTL par la fin/gauche ; index en primitives directionnelles, `Semantics` par lettre, cibles ≥ 48 dp, couleur jamais seul canal). **AD hérités** : **AD-1** (acyclique, `CORE OUT=0` — l'arête `zcrud_ui_kit → zcrud_core` reste **ENTRANTE au cœur** ; EX-UI.10 n'ajoute **aucune** arête), **AD-2/AD-15/NFR-U2** (Flutter-native, **AUCUN gestionnaire d'état**, **AUCUN routeur** — le `ConsumerWidget`/`ref` mort de lex est **retiré**, le couplage `go_router` de `transitions.dart` est **découplé**), **AD-10/NFR-U10** (défauts sûrs : jamais de throw, ensemble de lettres par défaut A→Z), **NFR-U6** (fonction **pure testable sans `BuildContext`** : le calcul de l'offset de début du slide en fonction de la `TextDirection`), **NFR-U7** (**enums > booléens** : `ZRouteTransition { slide, fade }` — un **enum** de type de transition, jamais un `bool isSlide`/`bool fade`).

---

## Story

**As a** utilisateur parcourant une longue liste alphabétique (répertoire de codes, pays, tags),
**I want** un **index vertical A→Z cliquable** (`ZAlphabetIndexBar`) qui notifie la lettre choisie au tap (et au scrub), avec les lettres inertes visuellement distinctes **par un canal non-couleur**, **et** des **transitions de route dont le sens du slide s'inverse en RTL** (`z_transitions.dart`), **sans** dépendre d'aucun routeur (`go_router`) ni d'aucun gestionnaire d'état,
**so that** je navigue rapidement dans une grande liste **et** que les transitions respectent la direction de lecture (AD-13), le tout thème-injecté, directionnel et accessible — clôturant la surface `zcrud_ui_kit` (EX-UI.7..10).

---

## Contexte — vérifié sur disque (pas sur la seule foi de l'épic)

### État réel du package `zcrud_ui_kit` (EX-UI.7 + EX-UI.8 + EX-UI.9 livrés)

Vérifié sur disque :
- `packages/zcrud_ui_kit/pubspec.yaml` : `dependencies` = **`zcrud_core: ^0.2.0` + `flutter`** UNIQUEMENT ; `dev_dependencies` = `flutter_test`. ⛔ **AUCUNE modification requise** (aucune dépendance ajoutée — pur Flutter + thème). `version: 0.2.0`, `resolution: workspace`, `publish_to: none`, `environment.sdk: ^3.12.2`.
- Barrel `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (`library;`) : exporte déjà, par **bloc** (`domain/` puis `presentation/`), en **ordre alphabétique** :
  - `src/domain/` : `z_confirm_tone.dart`, `z_content_state.dart`, `z_toast_severity.dart`, `z_toaster.dart`
  - `src/presentation/` : `z_confirm_dialog.dart`, `z_discard_changes_guard.dart`, `z_scaffold_messenger_toaster.dart`, `z_state_widgets.dart`, `z_toaster_scope.dart`
  ⇒ EX-UI.10 **ajoute** : `export 'src/domain/z_route_transition.dart';` (au bloc `domain`, place alpha : **après** `z_content_state.dart`, avant `z_toast_severity.dart`) + `export 'src/presentation/z_alphabet_index_bar.dart';` (au bloc `presentation`, place alpha : **avant** `z_confirm_dialog.dart`) + `export 'src/presentation/z_transitions.dart';` (place alpha : **après** `z_toaster_scope.dart`) + **paragraphe dartdoc EX-UI.10**. ⛔ Ne PAS ré-exporter `zcrud_core` ; ⛔ ne PAS retirer/réordonner les exports EX-UI.7/8/9.
- Le package est **déjà déclaré** au bloc `workspace:` du `pubspec.yaml` racine ⇒ **rien à ajouter** ; `melos list` **inchangé**.

### Patrons internes DÉJÀ établis (EX-UI.7/8/9, à réutiliser — cohérence stricte)

Vérifié dans les sources livrées :
- **Couleurs DÉRIVÉES du `ColorScheme`, jamais de hex** (`z_state_widgets.dart`, `z_scaffold_messenger_toaster.dart`) : `Theme.of(context).colorScheme.primary` / `onSurfaceVariant` / etc. ⇒ `ZAlphabetIndexBar` dérive **couleur active** de `colorScheme.primary` (ou seam `ZcrudTheme` si monté, repli `Theme.of(context)`), **atténuation inerte** via `withValues(alpha:)` sur `onSurfaceVariant`.
- **Textes/labels INJECTÉS, jamais de chaîne métier en dur** : l'appelant fournit le jeu de lettres (`letters`) ; défaut A→Z neutre (pas une chaîne métier). Voir D2.
- **`Semantics` explicites + cibles ≥ 48 dp + directionnel** (`z_state_widgets.dart` : `EdgeInsetsDirectional`, `Semantics(button: true, ...)`). ⇒ chaque lettre est une cible d'au moins 48 dp avec `Semantics(button: true, enabled: active, label: ...)`.
- **Seam thème** : `zcrud_core` expose `ZcrudScope`/`ZcrudTheme`/`ZcrudLocalizations` consommés **en lecture** avec repli `Theme.of(context)` / `MaterialLocalizations`. ⚠️ EX-UI.10 est **UI-pur** et **n'a pas besoin de `zcrud_core`** au niveau import (couleurs via `Theme.of(context)` suffisent) — **ne pas** ajouter d'import `zcrud_core` sauf si un seam thème précis est réellement consommé (le dev tranche ; par défaut, `Theme.of(context)` comme dans lex, ce qui **n'ajoute aucune arête**).
- **Barrel** exporte `src/...`, ne ré-exporte pas `zcrud_core`.

### Best-of-breed à NEUTRALISER (LECTURE SEULE — apps hors périmètre, ne PAS copier tel quel)

- **lex** `packages/lex_ui/lib/presentation/widgets/alphabet_index_bar.dart` (56 LOC) : bon squelette (A→Z via `String.fromCharCode(65+i)`, `activeLetters: Set<String>`, `onLetterSelected: ValueChanged<String>`, `GestureDetector(behavior: opaque, onTap: active ? … : null)`, `EdgeInsetsDirectional.symmetric`, couleur active `colorScheme.primary` vs inerte `onSurfaceVariant.withValues(alpha: 0.3)`). **À neutraliser** :
  1. ⛔ **`ConsumerWidget` + `WidgetRef ref` MORTS** (`import 'package:flutter_riverpod/flutter_riverpod.dart';`, `build(context, ref)` où `ref` est **inutilisé**) → **`StatelessWidget` pur `const`** (AD-2/AD-15/NFR-U2 : **aucun** import manager).
  2. ⛔ **Distinction active/inerte par la SEULE couleur** (`alpha: 0.3` + `FontWeight`) → conserver l'atténuation **mais ajouter un canal non-couleur** : `Semantics(enabled:)` + `onTap: null` (inerte non focalisable/non tappable) — la couleur **n'est jamais le seul canal** (AD-13/NFR-U4). Le `FontWeight.bold` sur actif est un second canal typographique acceptable ; l'état **courant** (`currentLetter`) ajoute un 3ᵉ canal (soulignement/pastille) — cf. D2.
  3. ⛔ **Jeu de lettres A→Z figé en `static`** → **injectable** (`List<String> letters` param, défaut A→Z) pour supporter d'autres alphabets/segments (AD-13/NFR-U5).
  4. ⛔ **Cibles trop petites** (`vertical: 1.5`, `fontSize: 11` → hauteur < 48 dp) → garantir une **cible ≥ 48 dp** par lettre (ou une **zone de scrub** globale accessible ≥ 48 dp de large), sans casser la densité visuelle (padding/`constraints`), `Semantics` explicites.
- **lex** `packages/lex_ui/lib/core/utils/transitions.dart` (37 LOC) : `buildSlideTransitionPage`/`buildFadeTransitionPage` **RTL-aware** — `final isRtl = Directionality.of(context) == TextDirection.rtl; final begin = Offset(isRtl ? -1.0 : 1.0, 0.0);` puis `SlideTransition(position: animation.drive(Tween(begin, Offset.zero).chain(CurveTween(curve))))`. **À neutraliser** :
  1. ⛔ **Couplage `go_router`** (`import 'package:go_router/go_router.dart';`, retour `CustomTransitionPage<void>`, `GoRouterState state`, `state.pageKey`) → **découplé du routeur** : renvoyer un **`PageRoute<T>` NEUTRE** (`PageRouteBuilder<T>`) et/ou exposer un **`PageTransitionsBuilder`** enregistrable dans `PageTransitionsTheme` — **aucun** import `go_router` (NFR-U2, interdit AD architecture l.133).
  2. ⛔ **Deux fonctions libres non typées** (`slide`/`fade` implicites) → **enum `ZRouteTransition { slide, fade }`** (NFR-U7 : un **enum** de type de transition, jamais un `bool`) piloté par un unique point d'entrée.
  3. ✅ **Conserver** la logique RTL (le sens du slide dépend de `Directionality.of(context)`) — c'est **exactement** l'exigence AD-13 ; l'**extraire en fonction pure** testable sans `BuildContext` (D3, NFR-U6).

### ⛔ Hors périmètre (défini par d'autres stories — NE PAS implémenter ici)

- **EX-UI.11** — présentateur/toaster **manager** (GetX) dans `zcrud_get`. Ici : **pur-Flutter**, aucun manager, aucun binding.
- **Tout routeur** : EX-UI.10 fournit des **primitives de transition neutres** (`PageRoute`/`PageTransitionsBuilder`) ; le **câblage** dans un `GoRouter`/`Navigator` réel appartient à l'app/binding, **pas** à `zcrud_ui_kit`.
- **Toute écriture de `zcrud_core`** : EX-UI.10 ne consomme (au plus) que `Theme.of(context)` ; il n'ajoute **rien** au cœur.
- **Logique de scroll/liste** (`ScrollController`, `Scrollable.ensureVisible`, jump vers l'offset d'une section) : `ZAlphabetIndexBar` **émet la lettre** via `onLetter` ; c'est l'**appelant** qui scrolle. Le widget ne possède **aucun** `ScrollController` ni état de liste (pureté, testabilité, réutilisation).

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — Aucune nouvelle dépendance, aucun routeur, aucun manager (AD-1/AD-2/AD-15/NFR-U2)

`pubspec.yaml` **inchangé** : `zcrud_core` + `flutter` suffisent. ⛔ **AUCUN** `flutter_riverpod`/`get`/`provider`/**`go_router`**/tiers UI. Les transitions renvoient des types **`package:flutter/*` natifs** (`PageRouteBuilder`, `PageTransitionsBuilder`, `SlideTransition`, `FadeTransition`). L'arête reste `zcrud_ui_kit → zcrud_core` (entrante au cœur, `CORE OUT=0` intact, `graph_proof.py` ACYCLIQUE — **inchangé** par EX-UI.10, y compris si l'index n'importe même pas `zcrud_core`).

### D2 — `ZAlphabetIndexBar` : `StatelessWidget const`, lettres injectables, actif/inerte/courant multi-canal, ≥ 48 dp

Fichier `lib/src/presentation/z_alphabet_index_bar.dart`. Signature de référence (le dev ajuste, en **gardant** : `StatelessWidget`, aucun manager, `onLetter: ValueChanged<String>`, lettres injectables, distinction non-couleur) :

```dart
class ZAlphabetIndexBar extends StatelessWidget {
  const ZAlphabetIndexBar({
    super.key,
    required this.onLetter,          // notifie la lettre au tap (et au scrub)
    this.activeLetters,             // null ⇒ toutes actives ; sinon set des lettres cliquables
    this.currentLetter,             // lettre courante mise en évidence (canal supplémentaire)
    this.letters = kZDefaultAlphabet, // défaut A→Z (injectable : autres alphabets/segments)
    this.enableScrub = true,        // scrub vertical → onLetter (zone accessible)
  });

  final ValueChanged<String> onLetter;
  final Set<String>? activeLetters;
  final String? currentLetter;
  final List<String> letters;
  final bool enableScrub;           // prédicat binaire non extensible (exception NFR-U7, cf. note)
  // ...
}
```

- **`letters` injectable, défaut A→Z** : `const kZDefaultAlphabet` = `['A'..'Z']` (26, `String.fromCharCode(65+i)`). Défaut **neutre** (pas une chaîne métier — conforme NFR-U5). Un jeu vide ⇒ `SizedBox.shrink()` (défaut sûr AD-10, cf. `ZResponsiveGrid`).
- **actif vs inerte** : `activeLetters == null` ⇒ **toutes** actives ; sinon une lettre est active ssi `activeLetters.contains(letter)`. Inerte ⇒ `onTap: null` (**non tappable, non focalisable**) + `Semantics(enabled: false)` + atténuation `withValues(alpha:)` — la couleur **n'est jamais le seul canal** (AD-13/NFR-U4 : l'état a11y `enabled` + l'inactivité du geste sont des canaux non-couleur).
- **lettre courante** (`currentLetter`) : **mise en évidence** par un canal **non-couleur additionnel** (ex. `FontWeight.bold` + pastille/fond `colorScheme.primaryContainer` ou soulignement) **en plus** de `colorScheme.primary`, et `Semantics(selected: true)`. Distinct de « actif » (cliquable) et « inerte ».
- **couleurs** : dérivées de `Theme.of(context).colorScheme` (`primary` pour actif/courant, `onSurfaceVariant` atténué pour inerte) — **jamais** de hex (AD-13/NFR-U5). Personnalisation fine du thème via `ZcrudTheme`/`ThemeExtension` déléguée au repli `Theme.of(context)` (pas de nouveau champ de couleur en dur).
- **≥ 48 dp & Semantics** : chaque lettre est enveloppée d'une cible `≥ 48 dp` (via `ConstrainedBox`/`SizedBox`/`minimumSize`) **ou** l'index expose une **zone de scrub** continue ≥ 48 dp de large ; `Semantics(button: true, enabled: active, selected: current, label: <lettre>)`. Directionnel : `EdgeInsetsDirectional`, `AlignmentDirectional` — ⛔ **jamais** `EdgeInsets.only(left:/right:)` / `Alignment.centerLeft/Right` / `TextAlign.left/right`.
- **scrub** (`enableScrub`) : `GestureDetector(onVerticalDragUpdate:)` → hit-test de la position verticale sur la liste des lettres → `onLetter(lettreCourante)` (dé-dupliqué : n'émet qu'au changement de lettre). C'est la « zone de scrub accessible » du périmètre. `enableScrub` est un **prédicat strictement binaire non extensible** (activer/désactiver le geste) — **seule** exception `bool` tolérée (NFR-U7), documentée ; **pas** un enum de mode.
- **Layout** : `Column(mainAxisSize: min)` de lettres (petit ensemble borné A→Z = 26) — le `ListView.builder` (AD-13) n'est **pas** requis pour un index fixe borné ≤ 26 non défilant ; **documenter** ce choix (l'index n'est pas une longue liste défilante — c'est la *liste* indexée qui l'est, hors périmètre). Si le dev préfère `ListView.builder` pour homogénéité AD-13, acceptable.

### D3 — Transitions RTL-aware : enum `ZRouteTransition` + fonction PURE d'offset + `PageRoute`/`PageTransitionsBuilder` neutres (AD-13/NFR-U6/U7)

Fichiers `lib/src/domain/z_route_transition.dart` (enum) + `lib/src/presentation/z_transitions.dart` (primitives).

- **`enum ZRouteTransition { slide, fade }`** (NFR-U7). ⚠️ enum **public** ⇒ `@JsonKey(unknownEnumValue:)`/`unknownEnumValue` **non requis** ici (l'enum n'est **pas** sérialisé/persisté — c'est un paramètre d'UI runtime ; NFR-U11 : pas de codegen). Documenter qu'il n'est pas destiné à la persistance.
- **Fonction PURE testable sans `BuildContext`** (NFR-U6) — cœur de l'inversion RTL, isolée pour un test unitaire déterministe :

  ```dart
  /// Offset de DÉBUT du slide entrant, selon la direction de lecture.
  /// LTR : entre depuis la fin (droite) → Offset(1, 0).
  /// RTL : entre depuis la fin (gauche) → Offset(-1, 0).
  Offset zSlideBeginOffset(TextDirection direction) =>
      Offset(direction == TextDirection.rtl ? -1.0 : 1.0, 0.0);
  ```

  ⚠️ **Sémantique directionnelle** : le slide entre **par le côté “fin” (end)** de la direction de lecture. En LTR le “end” est à droite (`+1`), en RTL à gauche (`-1`). C'est l'**inversion** exigée par AD-13 (lex fait `isRtl ? -1 : 1`, identique). Cette fonction est **le point testé** de l'AC « offset s'inverse LTR vs RTL ».
- **Primitive de route neutre** (découplée du routeur) :

  ```dart
  PageRouteBuilder<T> zPageRoute<T>({
    required WidgetBuilder builder,
    ZRouteTransition transition = ZRouteTransition.slide,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    RouteSettings? settings,
  }) { … }
  ```

  - `slide` : `transitionsBuilder` lit `Directionality.of(context)`, calcule `zSlideBeginOffset(dir)`, construit `SlideTransition(position: animation.drive(Tween(begin, Offset.zero).chain(CurveTween(curve: curve))), child: child)`.
  - `fade` : `FadeTransition(opacity: animation, child: child)` (pas de direction — insensible RTL, documenté).
  - `duration`/`curve` **injectés** (jamais en dur non surchargeable — AD-13/NFR-U5). ⛔ **Aucun** `CustomTransitionPage`, **aucun** `GoRouterState`, **aucun** `go_router`.
- **(optionnel, si trivial) `ZPageTransitionsBuilder extends PageTransitionsBuilder`** enregistrable dans `PageTransitionsTheme(builders: {TargetPlatform.x: ZPageTransitionsBuilder()})` — même logique RTL (réutilise `zSlideBeginOffset`). À ajouter **seulement** si cela ne gonfle pas la story (S) ; sinon consigné comme extension future. Le `PageRouteBuilder` neutre est le **livrable minimal** requis.

### D4 — Défauts sûrs, jamais de throw (AD-10/NFR-U10)

- `letters` vide ⇒ `SizedBox.shrink()` (pas de throw, cf. `ZResponsiveGrid`).
- `activeLetters == null` ⇒ toutes actives (défaut permissif sûr).
- `currentLetter` hors de `letters` ⇒ **ignoré** (aucune mise en évidence), pas de throw.
- `zSlideBeginOffset` : total sur `TextDirection` (2 cas), jamais de throw.

### D5 — Aucun codegen, aucune sérialisation (NFR-U11)

`ZAlphabetIndexBar`, `z_transitions.dart`, `ZRouteTransition` sont **UI-pur / valeur runtime**, **non persistés** → **aucun `@ZcrudModel`/`@JsonSerializable`/`part`** ⇒ pas de `*.g.dart`, `melos run generate` **no-op** pour ce package, gate `codegen-distribution` **non concernée**. Confirmer le no-op (AC7).

### D6 — Barrel = SEULE API publique ; clôture EX-UI.10 (D7 EX-UI.9 étendu)

`lib/zcrud_ui_kit.dart` **ajoute** (places alphabétiques dans les blocs `domain`/`presentation`) : `export 'src/domain/z_route_transition.dart';` + `export 'src/presentation/z_alphabet_index_bar.dart';` + `export 'src/presentation/z_transitions.dart';` + un **paragraphe dartdoc EX-UI.10** (clôture de la surface `zcrud_ui_kit`). ⛔ **Ne PAS** ré-exporter `zcrud_core`. ⛔ **Ne PAS** retirer/réordonner les exports EX-UI.7/8/9.

---

## Acceptance Criteria

### AC1 — `ZAlphabetIndexBar` rend les lettres, `StatelessWidget` sans manager (AD-32/AD-2/NFR-U2)
**Given** `ZAlphabetIndexBar(onLetter: ..., letters: kZDefaultAlphabet)` (défaut A→Z),
**When** le widget s'affiche,
**Then** les **26 lettres A→Z** sont rendues (ou le jeu `letters` injecté), le widget est un **`StatelessWidget`** `const` (le `ConsumerWidget`/`WidgetRef` mort de lex est **retiré**), et le fichier n'importe que `package:flutter/*` (+ au plus `zcrud_ui_kit` interne) — **aucun** `flutter_riverpod`/`get`/`provider`, **aucun** `WidgetRef`/`Get.find`/`Provider.of`, **aucun** `go_router`.

### AC2 — Tap d'une lettre active → `onLetter` avec la BONNE lettre (AD-32)
**Given** un index où la lettre « M » est active,
**When** l'utilisateur **tape** « M »,
**Then** `onLetter('M')` est invoqué **exactement une fois** avec la valeur `'M'`,
**And** un tap sur une **lettre inerte** (`activeLetters` fourni, ne la contenant pas) **n'invoque PAS** `onLetter` (`onTap: null`, non tappable).

### AC3 — Lettre courante mise en évidence par un canal NON-COULEUR (AD-13/NFR-U4)
**Given** `currentLetter: 'C'` (et « C » présent dans `letters`),
**When** l'index s'affiche,
**Then** « C » est **mise en évidence** par un canal **non-couleur** (ex. `FontWeight.bold` + pastille/soulignement) **en plus** de la couleur dérivée du `ColorScheme`, et son nœud `Semantics` porte `selected: true` — la mise en évidence **ne repose pas sur la seule couleur**.

### AC4 — Distinction actif/inerte multi-canal + cibles ≥ 48 dp + Semantics (AD-13/NFR-U4)
**Given** un `activeLetters` où certaines lettres sont inertes,
**When** on inspecte l'a11y et le layout,
**Then** chaque lettre expose un `Semantics(button: true, enabled: <active>, label: <lettre>)`, les inertes sont **non focalisables/non tappables** (canal non-couleur, pas seulement l'`alpha`), et chaque lettre (ou la zone de scrub) offre une **cible d'au moins 48 dp**,
**And** l'index est **directionnel** (⛔ aucun `EdgeInsets.only(left:/right:)`/`Alignment.centerLeft/Right`/`TextAlign.left/right`) et se rend sous `Directionality.rtl` **sans exception**.

### AC5 — Transition slide : le sens/offset s'INVERSE LTR vs RTL (AD-13/NFR-U6) — AC PIVOT
**Given** la fonction pure `zSlideBeginOffset(TextDirection)` et `zPageRoute(transition: ZRouteTransition.slide)`,
**When** on l'évalue,
**Then** `zSlideBeginOffset(TextDirection.ltr) == const Offset(1.0, 0.0)` **et** `zSlideBeginOffset(TextDirection.rtl) == const Offset(-1.0, 0.0)` — l'offset horizontal de début **change de signe** entre LTR et RTL (le slide entre par le côté « fin » de la direction de lecture),
**And** la route `slide` construite lit `Directionality.of(context)` et applique cet offset via `SlideTransition`/`Tween(begin → Offset.zero)` avec `curve`/`duration` **injectés**,
**And** `ZRouteTransition.fade` produit un `FadeTransition` **insensible à la direction** (documenté).

### AC6 — Transitions découplées de tout routeur ; enum > bool (AD-32/NFR-U2/NFR-U7)
**Given** `z_transitions.dart` + `z_route_transition.dart`,
**When** on inspecte les imports et l'API,
**Then** `zPageRoute` retourne un **`PageRouteBuilder<T>` neutre** (pas de `CustomTransitionPage`, pas de `GoRouterState`), le fichier **n'importe aucun** `go_router`/routeur, et le **type** de transition est un **enum `ZRouteTransition { slide, fade }`** (jamais un `bool isSlide`/`fade`),
**And** (si livré) `ZPageTransitionsBuilder` est un `PageTransitionsBuilder` natif enregistrable dans `PageTransitionsTheme`.

### AC7 — Graphe inchangé, gates verts, barrel clôturé, codegen no-op (AD-1/NFR-U1/U11)
**Given** l'extension `zcrud_ui_kit`,
**When** on inspecte le graphe, le barrel et rejoue les gates,
**Then** `zcrud_ui_kit` conserve **au plus une** arête `zcrud_*` **sortante** (`→ zcrud_core`, **inchangée**) et **zéro** entrante ; `CORE OUT=0` intact ; `graph_proof.py` reste **ACYCLIQUE** (EX-UI.10 n'ajoute **aucune** dépendance — D1),
**And** le barrel `lib/zcrud_ui_kit.dart` **exporte** les 3 nouveaux fichiers (places alphabétiques, blocs `domain`/`presentation`) + dartdoc EX-UI.10, **sans** retirer/réordonner EX-UI.7/8/9 ni ré-exporter `zcrud_core`,
**And** `melos run generate` est **no-op** (aucun `@ZcrudModel` — NFR-U11), gate `codegen-distribution` **non concernée** ; `dart analyze packages/zcrud_ui_kit` **RC=0** ; `flutter test` (package) **tous verts** (EX-UI.7/8/9 + nouveaux) ; `gate:secrets` vert (zéro secret — AD-12) ; `melos list` **inchangé** ; `melos run analyze`/`verify` **repo-wide** délégués au gate de commit d'epic de l'orchestrateur.

---

## Tasks / Subtasks

- [x] **T1 — Domaine : enum de transition** (AC6, D3) — `lib/src/domain/z_route_transition.dart`
  - [x] T1.1 `enum ZRouteTransition { slide, fade }` + dartdoc (type de transition ; non sérialisé/persisté ; NFR-U7).

- [x] **T2 — Présentation : `ZAlphabetIndexBar`** (AC1..AC4, D2, D4) — `lib/src/presentation/z_alphabet_index_bar.dart`
  - [x] T2.1 `kZDefaultAlphabet` (A→Z, 26 lettres, `List.unmodifiable`). `class ZAlphabetIndexBar extends StatelessWidget` (`const` ctor) : `ValueChanged<String> onLetter`, `Set<String>? activeLetters`, `String? currentLetter`, `List<String>? letters` (repli `kZDefaultAlphabet` via getter — un `final List` généré ne peut pas être défaut const), `bool enableScrub = true`. ⛔ Aucun import manager/routeur.
  - [x] T2.2 `build` : `letters` vide → `SizedBox.shrink()` (D4). Sinon `Column(mainAxisSize: min)` de lettres ; par lettre : cible **≥ 48 dp en largeur** (`ConstrainedBox(minWidth: 48)` — 26 lettres à 48 dp de haut dépasseraient tout écran, AD-13 admet la zone de scrub ≥ 48 dp de large), `GestureDetector(onTap: active ? () => onLetter(l) : null)`, couleur dérivée `colorScheme` (primary actif/courant, `onSurfaceVariant.withValues(alpha:.38)` inerte), canal non-couleur `currentLetter` (bold + pastille `primaryContainer`), `Semantics(button: true, enabled: active, selected: l == currentLetter, label: l)`. Directionnel (`EdgeInsetsDirectional`).
  - [x] T2.3 (si `enableScrub`) `_ZAlphabetScrubDetector` (`onVerticalDragStart/Update`) → hit-test vertical (fraction × longueur) → `onLetter(lettre)` dé-dupliqué au changement (zone de scrub accessible).
  - [x] T2.4 dartdoc : lettres injectables, actif/inerte/courant multi-canal, ≥48dp largeur, le widget **émet la lettre** (l'appelant scrolle — pas de `ScrollController` interne).

- [x] **T3 — Présentation : transitions RTL-aware** (AC5, AC6, D3, D4) — `lib/src/presentation/z_transitions.dart`
  - [x] T3.1 `Offset zSlideBeginOffset(TextDirection direction)` — **fonction pure** (`rtl ? Offset(-1,0) : Offset(1,0)`), dartdoc « entre par le côté fin de la lecture ». (NFR-U6, point testé AC5.)
  - [x] T3.2 `PageRouteBuilder<T> zPageRoute<T>({required WidgetBuilder builder, ZRouteTransition transition = slide, Duration duration = 300ms, Curve curve = easeInOut, RouteSettings? settings})` : `slide` → `SlideTransition` via `Directionality.of(context)` + `zSlideBeginOffset` + `Tween(begin→Offset.zero).chain(CurveTween(curve))` ; `fade` → `FadeTransition`. ⛔ Aucun `go_router`/`CustomTransitionPage`.
  - [x] T3.3 `class ZPageTransitionsBuilder extends PageTransitionsBuilder` réutilisant `_buildZTransition`/`zSlideBeginOffset` (enregistrable `PageTransitionsTheme`) — livré (trivial).

- [x] **T4 — Barrel** (AC7, D6) — `lib/zcrud_ui_kit.dart`
  - [x] T4.1 Ajout de `export 'src/domain/z_route_transition.dart';` (bloc domain, après `z_content_state.dart`), `export 'src/presentation/z_alphabet_index_bar.dart';` (bloc presentation, avant `z_confirm_dialog.dart`), `export 'src/presentation/z_transitions.dart';` (après `z_toaster_scope.dart`) + paragraphe dartdoc EX-UI.10 (clôture du package). Pas de ré-export `zcrud_core` ; exports EX-UI.7/8/9 intacts.

- [x] **T5 — Tests** (AC1..AC6) — `packages/zcrud_ui_kit/test/`
  - [x] T5.1 `test/z_alphabet_index_bar_test.dart` (widget) : rend A→Z + jeu injecté (AC1) ; `StatelessWidget` ; tap actif → `onLetter` 1× bonne lettre + tap inerte non appelé + `activeLetters==null` toutes actives (AC2) ; `currentLetter` → `isSemantics(isSelected: true)` + bold (AC3) ; `isSemantics(isButton/isEnabled)` par lettre + cible ≥ 48 dp largeur + RTL sans exception (AC4) ; `letters: []` → `SizedBox.shrink()` + `currentLetter` hors jeu ignoré (D4).
  - [x] T5.2 `test/z_transitions_test.dart` (unitaire **pur**, sans `BuildContext`) : `zSlideBeginOffset(ltr)==Offset(1,0)` & `(rtl)==Offset(-1,0)` + inversion de signe prouvée (AC5, PIVOT) ; `ZRouteTransition.values` == [slide, fade] ; `zPageRoute` slide/fade → `PageRouteBuilder` neutre + durée injectée ; `ZPageTransitionsBuilder` enregistrable (AC6).
  - [x] T5.3 `test/z_transitions_widget_test.dart` (widget) : route `slide` sous `Directionality.ltr` (dx>0) vs `.rtl` (dx<0) via `builder:` MaterialApp (la direction doit envelopper le Navigator/Overlay) → **signe opposé** (AC5 en contexte) ; route `fade` → `FadeTransition` sans `SlideTransition`.
  - [x] T5.4 RTL/statique : `ZAlphabetIndexBar` sous `Directionality.rtl` sans exception ; scan des **directives `import` uniquement** (aucun manager/routeur) + scan des lignes de **code** (hors dartdoc) pour `CustomTransitionPage`/`GoRouterState` — dette EX-UI.9 respectée.

- [x] **T6 — Vérif verte + graphe** (AC7)
  - [x] T6.1 `dart run melos run generate` → SUCCESS (no-op : 0 `.g.dart` ajouté dans `zcrud_ui_kit`).
  - [x] T6.2 `dart analyze packages/zcrud_ui_kit` RC=0 (No issues found). `melos analyze`/`verify` repo-wide → orchestrateur.
  - [x] T6.3 `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK / CORE OUT=0 OK (arête `zcrud_ui_kit → zcrud_core` inchangée ; EX-UI.10 n'ajoute aucune arête).
  - [x] T6.4 `flutter test` (package) → 85 verts (62 EX-UI.7/8/9 + 23 nouveaux EX-UI.10).

---

## Dev Notes

### Fichiers à créer / modifier (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_ui_kit/lib/src/domain/z_route_transition.dart` | NEW — `enum ZRouteTransition { slide, fade }` |
| `packages/zcrud_ui_kit/lib/src/presentation/z_alphabet_index_bar.dart` | NEW — `ZAlphabetIndexBar` (`StatelessWidget` const) + `kZDefaultAlphabet` |
| `packages/zcrud_ui_kit/lib/src/presentation/z_transitions.dart` | NEW — `zSlideBeginOffset` (pure) + `zPageRoute<T>` (+ `ZPageTransitionsBuilder` opt.) |
| `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` | **UPDATE** — +3 `export` + dartdoc EX-UI.10 (clôture) |
| `packages/zcrud_ui_kit/test/z_alphabet_index_bar_test.dart` | NEW — widget (rend, tap actif/inerte, courant, a11y/≥48dp, RTL) |
| `packages/zcrud_ui_kit/test/z_transitions_test.dart` | NEW — unitaire pur (inversion offset LTR/RTL, types neutres) |
| `packages/zcrud_ui_kit/test/z_transitions_widget_test.dart` | NEW (opt.) — widget (offset inversé en contexte LTR vs RTL) |

⛔ **NE PAS TOUCHER** : `packages/zcrud_ui_kit/pubspec.yaml` (dépendances déjà OK), `pubspec.yaml` racine, `melos.yaml`, les fichiers EX-UI.7/8/9 (`z_confirm_*`, `z_content_state`, `z_state_widgets`, `z_toast*`, `z_discard_changes_guard`), **`packages/zcrud_core/**`**, `packages/zcrud_responsive/**`, `packages/zcrud_navigation/**`.

### Références de code (LECTURE SEULE)

- **`zcrud_ui_kit`** (EX-UI.7/8/9, cohérence à suivre) : `z_state_widgets.dart` (couleurs `colorScheme`, `Semantics`, `EdgeInsetsDirectional`, ≥48dp, textes injectés) ; barrel `lib/zcrud_ui_kit.dart` (blocs `domain`/`presentation`, ordre alpha).
- **lex** (LECTURE SEULE, à **neutraliser**) : `packages/lex_ui/lib/presentation/widgets/alphabet_index_bar.dart` (`ConsumerWidget` mort ; `activeLetters: Set<String>` ; A→Z `String.fromCharCode(65+i)` ; couleur `primary`/`onSurfaceVariant.withValues(alpha:0.3)` ; cibles trop petites) ; `packages/lex_ui/lib/core/utils/transitions.dart` (`go_router` `CustomTransitionPage` ; RTL `isRtl ? -1 : 1` — logique à **conserver**, routeur à **retirer**).

### Invariants AD applicables (rappel ciblé)

- **AD-32** : `zcrud_ui_kit` fournit `ZAlphabetIndexBar` + transitions **RTL-aware** ; thème/couleurs/durées **injectés** ; **jamais** un routeur, **jamais** un manager.
- **AD-13 / NFR-U4/U5** : le **sens du slide dépend de `Directionality.of(context)`** ; primitives directionnelles (⛔ jamais `left`/`right` positionnels) ; `Semantics`, cibles ≥ 48 dp ; couleur **jamais seul canal** (actif/inerte/courant multi-canal) ; couleurs dérivées du `ColorScheme` (jamais hex).
- **AD-2 / AD-15 / NFR-U2** : **aucun** manager / import routeur ; le `ConsumerWidget`/`WidgetRef` mort de lex **retiré** ; `StatelessWidget` pur.
- **AD-10 / NFR-U10** : défauts sûrs — `letters` vide → `SizedBox.shrink()` ; `activeLetters == null` → toutes actives ; `zSlideBeginOffset` total ; jamais de throw.
- **AD-1 / NFR-U1** : arête `zcrud_ui_kit → zcrud_core` **inchangée** (aucune dépendance ajoutée) ; `CORE OUT=0` ; `graph_proof.py` ACYCLIQUE.
- **AD-12 / NFR-U8** : zéro secret. **NFR-U6** : `zSlideBeginOffset` **pure**, testable sans `BuildContext`.
- **NFR-U7 (enums > booléens)** : `ZRouteTransition { slide, fade }` **enum** (jamais `bool isSlide`) ; `enableScrub` = **seul `bool` toléré** (prédicat binaire non extensible : activer/désactiver le geste), documenté.
- **NFR-U11** : pas de codegen — confirmer le no-op de `melos run generate`.

### Project Structure Notes

- `ZRouteTransition` sous `domain/` (valeur/enum), `ZAlphabetIndexBar` + transitions sous `presentation/` (widgets/primitives UI). Aucun contact fonctionnel avec `zcrud_core` (couleurs via `Theme.of(context)`), donc **aucun import `zcrud_core` requis** — l'arête du graphe reste celle du pubspec (inchangée).
- Barrel = seule API publique ; EX-UI.10 **clôt** la surface `zcrud_ui_kit` (EX-UI.7/8/9/10). Plus aucune story n'étendra ce barrel après.

### Dépendances aval (ce que cette story débloque)

`done` sur EX-UI.10 **complète le workstream P3 `zcrud_ui_kit`** (dernière story) ⇒ **rétrospective EX-UI** consommable une fois P1/P2/P3 terminés. `ZAlphabetIndexBar` sert les vues « liste groupée A→Z » (E4 liste / intégration DODLP E7) ; les transitions RTL-aware servent tout binding routeur ultérieur (l'app câble `zPageRoute`/`ZPageTransitionsBuilder` dans son `GoRouter`/`Navigator`).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.10 (AC1-3 : lettres actives/inertes canal non-couleur ≥48dp `StatelessWidget` ; transition slide sens inversé RTL découplée `go_router` ; couleurs/durées injectées ; tests : tap→callback, inerte non cliquable, Semantics, slide LTR vs RTL, absence import `go_router`), § Capability→Story Map (`ZAlphabetIndexBar` + transitions RTL-aware → `zcrud_ui_kit/presentation`, AD-32/AD-13), § NFR-U1/U2/U4/U5/U6/U7/U10/U11, § Fenêtres de parallélisation (P3 ∥ P2, EX-UI.10 file-disjoint, barrel séquentiel)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § AD-32 (l.104-107 : `ZAlphabetIndexBar` + transitions RTL-aware, sens du slide selon `Directionality.of(context)`, thème/l10n injectés, jamais routeur/manager), § AD-13 (l.58, l.120 : transitions dont le sens dépend de `Directionality`, primitives directionnelles, `Semantics` ≥48dp, couleur jamais seul canal), § Interdits phase (l.133 : aucun routeur `go_router` dans `zcrud_ui_kit`, jamais `EdgeInsets.only(left/right)`), § Consistency (l.115 : type `ZAlphabetIndexBar`), § Structural Seed (l.153), § Capability Map (l.192 : lex `AlphabetIndexBar`/`transitions.dart` à découpler de `go_router`), § Notes migration (l.202)]
- [Source: `packages/zcrud_ui_kit/{lib/zcrud_ui_kit.dart, pubspec.yaml, lib/src/presentation/z_state_widgets.dart}` (état livré EX-UI.7/8/9 : barrel blocs domain/presentation ordre alpha ; deps `zcrud_core`+flutter ; patrons `colorScheme`/`Semantics`/`EdgeInsetsDirectional`/≥48dp/textes injectés)]
- [Source: `_bmad-output/implementation-artifacts/stories/ex-ui-9-discard-changes-guard.md` (story modèle : structure ACs/Tasks/Dev Notes, no-op codegen, `graph_proof`, barrel séquentiel, dette scan d'`import` vs prose, neutralisation `ConsumerWidget` mort)]
- [Source: best-of-breed LECTURE SEULE — lex `packages/lex_ui/lib/presentation/widgets/alphabet_index_bar.dart` (`ConsumerWidget` mort → neutraliser) + `packages/lex_ui/lib/core/utils/transitions.dart` (`go_router` `CustomTransitionPage` + RTL `isRtl ? -1 : 1` → découpler) (`explore/lex.md` § Autres patterns 1 & 2)]
- [Source: `CLAUDE.md` — Key Don'ts (AD-2 : jamais de manager ; AD-13 : primitives directionnelles, `Semantics`, ≥48dp, `ListView.builder`, couleur jamais seul canal ; naming préfixe `Z` ; gates CI secrets/anti-reflectable/codegen ; enums > booléens)]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Widget** | index rend A→Z (défaut) ; `StatelessWidget` | AC1 |
| **Widget** | tap lettre active → `onLetter` (bonne lettre, 1×) ; tap lettre inerte → non appelé | AC2 |
| **Widget** | `currentLetter` → mise en évidence non-couleur + `Semantics(selected:)` | AC3 |
| **Widget** | `Semantics(enabled:)` par lettre + cible ≥ 48 dp ; RTL sans exception ; primitives directionnelles | AC4 |
| **Unitaire (pur)** | `zSlideBeginOffset(ltr)==Offset(1,0)` & `(rtl)==Offset(-1,0)` — **inversion du signe** (sans `BuildContext`) | AC5 (PIVOT) |
| **Widget (opt.)** | route `slide` : offset de `SlideTransition` de signe opposé LTR vs RTL en contexte | AC5 |
| **Statique** | `zPageRoute` → `PageRouteBuilder` neutre ; **aucun** import `go_router`/manager ; `ZRouteTransition` enum (pas de `bool`) | AC6 |
| **Graphe / gates** | `graph_proof` ACYCLIQUE / CORE OUT=0 (inchangé) ; `dart analyze` RC=0 ; `generate` no-op ; barrel +3 exports ; `melos list` inchangé ; `gate:secrets` vert | AC7, NFR-U1/U11 |

**Definition of Done** : AC1→AC7 verts · `pubspec.yaml` **inchangé** (`zcrud_core` + flutter, aucun manager/routeur) · `ZAlphabetIndexBar` = `StatelessWidget const` (lex `ConsumerWidget`/`ref` mort **retiré**), lettres **injectables** (défaut A→Z), actif/inerte/**courant** multi-canal (couleur jamais seul canal), cibles ≥ 48 dp + `Semantics`, `onLetter` au tap/scrub · transitions **découplées de `go_router`** : `ZRouteTransition { slide, fade }` (enum), `zSlideBeginOffset` **pure** (inversion RTL prouvée), `zPageRoute<T>` → `PageRouteBuilder` neutre, durées/courbes injectées · directionnel + RTL + a11y OK · `zcrud_core` **jamais écrit** ; **aucune** arête ajoutée (`graph_proof` ACYCLIQUE/CORE OUT=0) · barrel **clôturé** (+3 exports, EX-UI.7/8/9 intacts, pas de ré-export `zcrud_core`) · `melos run generate` (no-op) + `dart analyze` RC=0 + `flutter test` verts ; `melos run analyze`/`verify` **repo-wide** délégués à l'orchestrateur · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`, effort high).

### Debug Log References

- **Overflow A→Z 48 dp** : un `Column` de 26 lettres à `minHeight: 48` = 1248 px > tout écran (test 800×600 → RenderFlex overflow, 12 tests rouges). Résolu par le design standard (style iOS) admis par la story D2/AC4 : lettres **compactes** verticalement, cible tactile **≥ 48 dp en LARGEUR** (`ConstrainedBox(minWidth: 48)`) + zone de scrub continue accessible. Test AC4 ajusté (largeur ≥ 48, pas hauteur).
- **Directionality des routes poussées** : `Directionality.rtl` placé dans `home` **n'affecte pas** les routes de `zPageRoute` (le Navigator/Overlay est au-dessus de `home`) → `Directionality.of(context)` = LTR par défaut, offset RTL non inversé. Résolu en imposant la direction via `MaterialApp(builder:)` qui enveloppe le Navigator. Clé unique par direction pour éviter la réutilisation de la pile de routes entre les deux passes.
- **Scan d'import (dette EX-UI.9)** : le scan `source.contains('CustomTransitionPage'/'GoRouterState')` attrapait la **prose** du dartdoc (qui cite ces types pour documenter leur neutralisation). Corrigé : scan des directives `import` uniquement pour les packages, et scan des lignes de **code** (hors `///`/`//`/`*`) pour les identifiants routeur. Lecture source robuste au cwd (racine repo ou package).

### Completion Notes List

- 3 fichiers source **neufs** + barrel étendu (3 exports + dartdoc EX-UI.10, clôture du package). Exports EX-UI.7/8/9 **intacts**, pas de ré-export `zcrud_core`.
- `ZAlphabetIndexBar` : `StatelessWidget` pur `const` (le `ConsumerWidget`/`WidgetRef` mort de lex **retiré**) — aucun import manager/routeur (n'importe que `package:flutter/material.dart`). Lettres injectables (`kZDefaultAlphabet` A→Z par défaut), actif/inerte/courant **multi-canal** (couleur `ColorScheme` jamais seul canal : `enabled`/`selected` a11y + geste inactif + graisse bold + pastille), directionnel, émet la lettre au tap et au scrub (dé-dupliqué), défauts sûrs (jamais de throw).
- Transitions **découplées de tout routeur** : `zSlideBeginOffset` **pure** (inversion RTL), `zPageRoute<T>` → `PageRouteBuilder` neutre (aucun `go_router`/`CustomTransitionPage`), durée/courbe injectées, `ZRouteTransition` **enum** (jamais `bool`). `ZPageTransitionsBuilder` livré (question 1 tranchée : inclus car trivial).
- **Décisions Q2/Q3 tranchées** : `enableScrub` conservé (seul `bool` toléré NFR-U7, prédicat binaire) ; aucun import `zcrud_core` (couleurs via `Theme.of(context)`) → arête pubspec **inchangée**, `CORE OUT=0` intact.
- Vérifs rejouées : `dart pub get` RC=0 ; `melos run generate` RC=0 (no-op, 0 `.g.dart`) ; `dart analyze packages/zcrud_ui_kit` **No issues found** ; `flutter test` **85 passed** (62 + 23) ; `graph_proof.py` **ACYCLIQUE OK / CORE OUT=0 OK** (seule arête `zcrud_ui_kit → zcrud_core`).

### File List

- `packages/zcrud_ui_kit/lib/src/domain/z_route_transition.dart` (NEW)
- `packages/zcrud_ui_kit/lib/src/presentation/z_alphabet_index_bar.dart` (NEW)
- `packages/zcrud_ui_kit/lib/src/presentation/z_transitions.dart` (NEW)
- `packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart` (UPDATE — +3 exports + dartdoc EX-UI.10)
- `packages/zcrud_ui_kit/test/z_alphabet_index_bar_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_transitions_test.dart` (NEW)
- `packages/zcrud_ui_kit/test/z_transitions_widget_test.dart` (NEW)

### Questions pour l'orchestrateur (à remonter si besoin)

1. **`ZPageTransitionsBuilder`** : la story le rend **optionnel** (livrable minimal = `zPageRoute` neutre). À confirmer s'il faut l'imposer dès EX-UI.10 (enregistrable dans `PageTransitionsTheme`) ou le différer en extension future.
2. **Scrub** : `enableScrub` (défaut `true`) est le **seul `bool` toléré** (prédicat binaire, exception NFR-U7). Alternative : le retirer et ne garder que le tap (l'AC épic ne mentionne que le tap ; le scrub est un enrichissement « zone de scrub accessible » du périmètre). Le dev tranche si le hit-test de scrub alourdit la story S.
3. **Import `zcrud_core`** : l'index n'en a **pas besoin** (couleurs via `Theme.of(context)`). Confirmer qu'on ne tire pas le seam `ZcrudTheme` ici (garderait l'arête pubspec inchangée mais ajouterait un import) — par défaut : `Theme.of(context)` pur, comme lex.
