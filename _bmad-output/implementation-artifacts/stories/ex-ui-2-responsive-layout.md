# Story EX-UI.2 : `ZResponsiveLayout` — trois builders (compact / medium / expanded) avec repli en cascade, piloté par `ZWindowSizeClass` mesurée LOCALEMENT

Status: review

- **Clé sprint-status** : `ex-ui-2-responsive-layout`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit)
- **Taille** : **S** (1 fichier `presentation` NEUF + tests ; 0 codegen, 0 entité persistée, 0 nouveau package)
- **Parallélisation** : **PARALLÉLISABLE intra-P1 après EX-UI.1** (fichier disjoint dans le **même** package `zcrud_responsive` — cohabite avec EX-UI.3 `ZAdaptiveGrid`). ⛔ **SÉQUENTIELLE vis-à-vis d'EX-UI.3** au niveau du **barrel** `lib/zcrud_responsive.dart` (seul point de contact partagé — deux stories qui ajoutent une ligne d'export : sérialiser l'édition du barrel, ne jamais l'écrire en parallèle). Dépend de **EX-UI.1** (`done`/`review` — consomme `ZWindowSizeClass`).
- **Package écrit (disjoint)** : `packages/zcrud_responsive/` uniquement — 1 fichier `presentation` neuf + 1 ligne d'export au barrel + tests. ⛔ **N'ÉCRIT PAS `zcrud_core`** (ni aucun autre `zcrud_*`). ⛔ **Ne touche PAS** `z_window_size_class.dart` / `z_breakpoint_value.dart` (livrés en EX-UI.1, consommés en lecture).
- **AD delta** : **AD-29 (AMENDÉ)** (paquet UI pur `zcrud_responsive` dépendant de `zcrud_core`, `presentation/`), **AD-13** (RTL/a11y — le widget est directionnellement neutre). **AD hérités** : **AD-1** (acyclique, `CORE OUT=0` — aucune nouvelle arête `zcrud_*` : le fichier n'importe que `flutter` + les primitives déjà livrées du package), **AD-2/AD-15** (Flutter-native, **aucun** gestionnaire d'état — neutralisation du `ConsumerWidget`/`ref` mort de lex), **AD-5/AD-14** (la sélection de builder repose sur la fonction pure `ZWindowSizeClass.fromWidth`), **AD-10** (défaut sûr : jamais d'écran vide, cascade toujours résolue), **AD-12** (zéro secret), **NFR-U7** (enums > booléens : piloté par `ZWindowSizeClass`, jamais `isMobile/isTablet/isDesktop`).

---

## Story

**As a** développeur intégrateur composant des écrans adaptatifs,
**I want** un widget `ZResponsiveLayout` exposant **trois builders** (`compact` requis + `medium?` + `expanded?`) avec **repli en cascade descendante**, dont la classe d'écran est dérivée d'un `ZWindowSizeClass` **résolu localement** sur la largeur du **conteneur** (`LayoutBuilder`, jamais la largeur d'écran globale),
**so that** je choisisse une disposition selon la classe d'écran **sans recoder de seuils ni de ternaires largeur**, sans jamais tomber sur un écran vide quand un palier n'a pas de builder dédié, et en obtenant le **bon** rendu même en split-view / panneau réduit / bottom-sheet partiel (où la largeur du conteneur ≠ largeur écran) — avec le `ConsumerWidget` mort de lex retiré.

---

## Contexte — vérifié sur disque (pas sur la seule foi de l'épic)

### Ce que `zcrud_responsive` EXPOSE DÉJÀ (livré en EX-UI.1 — base consommée en lecture)

Lu sur disque (`packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart`, barrel `lib/zcrud_responsive.dart`) :

| Symbole (EX-UI.1) | Nature | Détail (lu) |
|---|---|---|
| **`ZWindowSizeClass`** | `enum { compact, medium, expanded }` | Valeurs **camelCase**. **← PILOTE la sélection de builder** |
| **`ZWindowSizeClass.fromWidth(double)`** | méthode statique **PURE** | `width < 600 → compact` ; `600 ≤ width < 840 → medium` ; `width ≥ 840 → expanded`. Défaut sûr `compact` (`0`/négatif/`NaN`), `expanded` pour `infinity`. **← À APPELER sur `constraints.maxWidth`** |
| **`ZWindowSizeClass.of(BuildContext)`** | méthode statique | `fromWidth(MediaQuery.sizeOf(context).width)`. **← NON utilisée par défaut ici** (le layout mesure le **conteneur**, pas l'écran — cf. D1) |
| `ZWindowSizeThresholds.{mediumMinWidth=600, expandedMinWidth=840}` | constantes M3 | Seuils centralisés — **jamais** redéclarés ailleurs |

⛔ **Aucun de ces symboles n'est redéclaré ni modifié.** `z_responsive_layout.dart` fait `import '../domain/z_window_size_class.dart';` (import relatif interne au package) et **réutilise** `ZWindowSizeClass.fromWidth`.

### Base best-of-breed (LECTURE SEULE — à neutraliser, pas copier)

- **lex** `packages/lex_ui/lib/core/utils/breakpoints.dart` — `ResponsiveLayout` (~39 LOC) : builder `mobile/tablet/desktop`. **À neutraliser** : (1) `ConsumerWidget → StatelessWidget` (le `ref` est **mort**, jamais lu) ; (2) piloter par `ZWindowSizeClass` (enum) au lieu de bools `isMobile/isTablet/isDesktop` ; (3) mesurer la **largeur locale** (`LayoutBuilder.constraints.maxWidth`) au lieu de `MediaQuery.of(context).size.width` **écran global** (architecture EX-UI § « À neutraliser » l.199 : *remplacer `Get.width`/écran par `MediaQuery.sizeOf`/`LayoutBuilder`*).
- **iffd** `AdaptiveShell` (pattern M3) — inspiration pour la sémantique 3 classes ; ne pas tirer le tiers `responsive_builder` (interdit, archi § Stack l.133).

### Nom `ZResponsiveLayout` — vérifié LIBRE

`grep` sur `packages/` : `zcrud_core` déclare `ZResponsiveBreakpoints` / `ZResponsiveSpan` / `ZResponsiveGrid` (`z_responsive_grid.dart`) mais **PAS** `ZResponsiveLayout`. ⇒ **aucune collision** — `ZResponsiveLayout` est le nom retenu (archi § Consistency l.115 le liste explicitement). *(Rappel : la grille d'items EX-UI.3 s'appelle `ZAdaptiveGrid`, jamais `ZResponsiveGrid`, réservé au cœur — hors périmètre ici.)*

### État du dossier `presentation/` (vérifié)

`packages/zcrud_responsive/lib/src/presentation/` contient **seulement** `.gitkeep` (créé vide en EX-UI.1). ⇒ `z_responsive_layout.dart` est le **premier** fichier réel du dossier. *(Le `.gitkeep` peut rester ; sa suppression est optionnelle et non requise par cette story.)*

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — Mesure LOCALE via `LayoutBuilder` sur `constraints.maxWidth` (PAS `MediaQuery` écran global)

C'est **le** choix de conception structurant de cette story (et la raison de sa valeur ajoutée vs le `ResponsiveLayout` de lex). `ZResponsiveLayout` enveloppe son contenu dans un **`LayoutBuilder`** et dérive la classe d'écran de **`ZWindowSizeClass.fromWidth(constraints.maxWidth)`** — la largeur du **conteneur** dans lequel le widget est placé, **non** `MediaQuery.sizeOf(context).width` (largeur de la fenêtre entière). Justification : en **split-view**, **master-detail**, **bottom-sheet partiel** ou toute colonne d'une `Row`, la largeur allouée au widget ≠ largeur écran ; mesurer l'écran donnerait `expanded` alors que le conteneur est étroit → mauvaise disposition. `ZWindowSizeClass.of(context)` (écran) reste disponible pour d'autres usages mais **n'est pas** le chemin par défaut de ce widget. **Testé** explicitement via des `LayoutBuilder` imbriqués / contraintes forcées.

### D2 — API : `compactBuilder` REQUIS + `mediumBuilder?`/`expandedBuilder?` optionnels ; cascade descendante

Signature retenue :

```dart
class ZResponsiveLayout extends StatelessWidget {
  const ZResponsiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  /// Builder du palier compact (`< 600` dp). **REQUIS** — garantit qu'aucun
  /// palier ne peut retomber sur du vide (défaut sûr, AD-10).
  final WidgetBuilder compact;

  /// Builder du palier medium (`600 ≤ w < 840`). Optionnel → **retombe** sur
  /// [compact] si absent (cascade descendante).
  final WidgetBuilder? medium;

  /// Builder du palier expanded (`w ≥ 840`). Optionnel → **retombe** sur
  /// [medium] s'il est fourni, sinon sur [compact] (cascade descendante).
  final WidgetBuilder? expanded;
}
```

**Type = `WidgetBuilder`** (`Widget Function(BuildContext)`, typedef Flutter standard) — jamais un `Widget` déjà construit (un `Widget` figé casserait le rebuild ciblé quand la contrainte change ; le builder n'est appelé que pour le palier retenu). **`compact` requis** est le **choix de sûreté** (AD-10) : la cascade a **toujours** un plancher, donc **jamais** d'écran vide. La cascade est **strictement descendante** : `expanded → medium → compact`, `medium → compact`. Elle ne « remonte » jamais (un `compact` fourni sans `medium`/`expanded` sert les trois paliers). Fonction de résolution pure et interne (ex. `_builderFor(ZWindowSizeClass)`).

### D3 — Aucun gestionnaire d'état ; `StatelessWidget` (neutralisation du `ConsumerWidget`/`ref` mort de lex)

`ZResponsiveLayout extends StatelessWidget`. **Aucun** `ConsumerWidget`/`WidgetRef`, **aucun** import `get`/`flutter_riverpod`/`provider`/`go_router` (AD-2/AD-15/NFR-U2). **Aucun** `setState` (le widget est immuable ; `LayoutBuilder` gère lui-même la re-mesure sur changement de contrainte). Constructeur `const`.

### D4 — Directionnellement neutre / RTL-safe (AD-13)

Le widget **ne pose aucun `EdgeInsets`/`Alignment`/`Positioned` directionnel** par lui-même (il ne fait que router vers un builder) — il est donc **trivialement RTL-safe** : la mesure de largeur (`constraints.maxWidth`) est directionnellement neutre, identique sous `Directionality.ltr` et `.rtl`. **Testé** sous `Directionality.rtl` (même palier sélectionné à largeur égale). Aucune couleur/label en dur, aucune cible tactile propre (le widget est un routeur de disposition, pas un contrôle interactif) ⇒ pas de `Semantics`/48 dp à sa charge — c'est le contenu des builders qui les porte.

### D5 — Enums > booléens (NFR-U7)

La sélection est pilotée **exclusivement** par `ZWindowSizeClass` (enum). **Aucun** `bool isMobile/isTablet/isDesktop` ni flag positionnel dans l'API publique. Le point de bascule (largeur → classe) délègue **entièrement** à `ZWindowSizeClass.fromWidth` — **aucun** seuil `600`/`840` n'est redéclaré dans `z_responsive_layout.dart`.

### D6 — Aucun codegen, aucune sérialisation (NFR-U11)

Widget pur-UI, **non** persisté, **aucun** `@ZcrudModel`/`@JsonSerializable`/`part`. ⇒ pas de `*.g.dart`, `melos run generate` **no-op** pour ce fichier, gate `codegen-distribution` **non concerné**.

---

## Acceptance Criteria

### AC1 — `ZResponsiveLayout` : API 3 builders, `compact` requis, `medium`/`expanded` optionnels
**Given** le besoin de choisir une disposition par classe d'écran,
**When** on définit `ZResponsiveLayout` (`packages/zcrud_responsive/lib/src/presentation/z_responsive_layout.dart`) `extends StatelessWidget`, constructeur `const`,
**Then** l'API expose exactement trois builders `WidgetBuilder` : **`compact` REQUIS**, `medium` et `expanded` **optionnels** (`WidgetBuilder?`),
**And** le type est `WidgetBuilder` (`Widget Function(BuildContext)`) — **jamais** un `Widget` pré-construit — et **seul** le builder du palier retenu est invoqué (les autres ne sont pas appelés),
**And** **aucun** `bool` multi-état (`isMobile`/`isTablet`/`isDesktop`) ni flag positionnel n'est exposé (NFR-U7).

### AC2 — Sélection par `ZWindowSizeClass` dérivée de la largeur LOCALE (`LayoutBuilder`), jamais l'écran global
**Given** un `ZResponsiveLayout` placé dans un conteneur de largeur `w`,
**When** il se construit,
**Then** il enveloppe son rendu dans un **`LayoutBuilder`** et dérive la classe via **`ZWindowSizeClass.fromWidth(constraints.maxWidth)`** — la largeur du **conteneur**, **jamais** `MediaQuery.sizeOf(context).width` / `MediaQuery.of(context).size` (écran global), **jamais** `Get.width` (AD-31/NFR-U2/D1),
**And** aux frontières : `constraints.maxWidth == 599 → compact`, `600 → medium`, `839 → medium`, `840 → expanded` (hérité de `fromWidth`, non recodé),
**And** **aucun** seuil `600`/`840` n'est redéclaré dans ce fichier (délégation totale à `ZWindowSizeClass.fromWidth`).

### AC3 — Repli en cascade descendante, jamais d'écran vide (défaut sûr AD-10)
**Given** la largeur locale correspond à un palier **sans** builder dédié,
**When** `ZResponsiveLayout` build,
**Then** le repli est **strictement descendant et déterministe** : `expanded` absent → `medium` si fourni, sinon `compact` ; `medium` absent → `compact`,
**And** parce que **`compact` est requis**, il **existe toujours** un builder à invoquer — **jamais** d'écran vide / `SizedBox.shrink` fantôme / `null` rendu (AD-10/NFR-U10),
**And** la cascade **ne remonte jamais** (un `compact` seul fourni sert les trois paliers ; un `medium` fourni ne « prête » jamais à `compact`).

### AC4 — Aucun gestionnaire d'état ; `StatelessWidget` (ConsumerWidget/ref mort retiré)
**Given** la base lex `ResponsiveLayout` (`ConsumerWidget` avec `ref` inutilisé),
**When** on porte le widget,
**Then** `ZResponsiveLayout` est un **`StatelessWidget`** pur — **aucun** `ConsumerWidget`/`WidgetRef`/`ref`, **aucun** `import` de `get`/`flutter_riverpod`/`provider`/`go_router` (AD-2/AD-15/NFR-U2), **aucun** `setState`,
**And** le fichier n'importe que `package:flutter/widgets.dart` (ou `material.dart` si strictement requis) + l'import relatif de `ZWindowSizeClass` — **aucune** nouvelle arête `zcrud_*` (CORE OUT=0 intact, AD-1/NFR-U1).

### AC5 — RTL-safe / directionnellement neutre (AD-13), comportement correct sous `LayoutBuilder` imbriqué / split
**Given** le widget placé sous `Directionality.rtl` et/ou imbriqué dans un autre `LayoutBuilder` (colonne d'un split-view),
**When** il build,
**Then** le palier sélectionné dépend **uniquement** de `constraints.maxWidth` du conteneur immédiat — **identique** en LTR et RTL à largeur égale (mesure directionnellement neutre, AD-13/NFR-U4),
**And** dans un split-view (widget dans une `SizedBox`/`Expanded` étroit alors que l'écran est large), c'est bien la **largeur du panneau** qui décide (ex. panneau de 500 dp sous un écran de 1200 dp → `compact`), prouvant l'indépendance vis-à-vis de `MediaQuery` écran (D1).

### AC6 — Export au barrel + gates verts repo-wide, codegen no-op (AD-1/NFR-U1/NFR-U11)
**Given** le nouveau widget,
**When** on met à jour le barrel et rejoue les gates,
**Then** `lib/zcrud_responsive.dart` **exporte** `src/presentation/z_responsive_layout.dart` (ajout **ciblé** d'une ligne d'`export`, sans réordonner/altérer les exports existants ni les ré-exports de confort `zcrud_core` ; respecter `directives_ordering` — les `export 'src/...'` groupés après les ré-exports `package:`),
**And** `melos run generate` est un **no-op** pour ce fichier (aucun `@ZcrudModel`, NFR-U11) ; gate `codegen-distribution` **non concerné** (aucun `part`/`*.g.dart`),
**And** `graph_proof.py` reste **ACYCLIQUE / CORE OUT=0** (aucune nouvelle arête `zcrud_*` ; `melos list` **inchangé** — aucun nouveau package),
**And** `dart analyze packages/zcrud_responsive` **RC=0** ; `melos run analyze` **ET** `melos run verify` **repo-wide** RC=0 (délégués au **gate de commit d'epic de l'orchestrateur** ; le dev consigne son `analyze` ciblé vert).

---

## Tasks / Subtasks

- [x] **T1 — Widget `ZResponsiveLayout`** (AC1, AC2, AC3, AC4, AC5, D1–D5) — `packages/zcrud_responsive/lib/src/presentation/z_responsive_layout.dart`
  - [x] T1.1 `import 'package:flutter/widgets.dart';` + `import '../domain/z_window_size_class.dart';` (⛔ aucun import de gestionnaire d'état/routeur ; ⛔ pas de `MediaQuery` écran pour la sélection).
  - [x] T1.2 `class ZResponsiveLayout extends StatelessWidget` : ctor `const` avec `required WidgetBuilder compact`, `WidgetBuilder? medium`, `WidgetBuilder? expanded`, `super.key`. Dartdoc de chaque champ (rôle + comportement de cascade) + dartdoc de classe (mesure LOCALE, cascade descendante, RTL-neutre, « enums > bools »).
  - [x] T1.3 `build` : retourner `LayoutBuilder(builder: (context, constraints) { final cls = ZWindowSizeClass.fromWidth(constraints.maxWidth); return _builderFor(cls)(context); })`. ⛔ **Aucun** seuil `600`/`840` codé ici.
  - [x] T1.4 Résolution pure interne `WidgetBuilder _builderFor(ZWindowSizeClass cls)` : `expanded → expanded ?? medium ?? compact` ; `medium → medium ?? compact` ; `compact → compact`. (Cascade descendante, jamais de remontée, jamais `null`.)
- [x] **T2 — Barrel** (AC6, D2) — `packages/zcrud_responsive/lib/zcrud_responsive.dart`
  - [x] T2.1 Ajouter `export 'src/presentation/z_responsive_layout.dart';` à sa place logique (avec les exports `src/...` ; respecter `directives_ordering`). ⛔ Édition **ciblée** — ne pas toucher les ré-exports `package:zcrud_core/...` ni les 2 exports domaine existants. ⚠️ **Sérialiser** avec EX-UI.3 si elle édite le même barrel (jamais deux écritures concurrentes du barrel).
- [x] **T3 — Tests widget** (AC1, AC2, AC3, AC5)
  - [x] T3.1 `test/z_responsive_layout_test.dart` :
    - **Sélection par palier** : conteneur forcé (`SizedBox(width: ...)` + `Center`/`Align`, ou `MediaQuery`+`ConstrainedBox`) aux largeurs **599 → compact**, **600 → medium**, **839 → medium**, **840 → expanded** ; vérifier via un `find` d'un widget-marqueur distinct par builder que **seul** le bon builder est rendu.
    - **Non-invocation des autres builders** : instrumenter chaque builder (ex. incrément d'un compteur) → seul le palier retenu est appelé.
    - **Cascade** : (a) seul `compact` fourni, largeur 700 (medium) **et** 1000 (expanded) → rend `compact` ; (b) `compact`+`medium` (sans `expanded`), largeur 1000 → rend `medium` ; (c) `compact`+`expanded` (sans `medium`), largeur 700 → rend `compact` (medium absent redescend directement au plancher requis).
    - **Largeur LOCALE (split-view / LayoutBuilder imbriqué)** : placer le widget dans un `Row(children: [SizedBox(width: 500, child: ZResponsiveLayout(...)), Spacer()])` sous une fenêtre large (`MediaQuery` 1200) → rend **compact** (prouve qu'on lit le conteneur, pas l'écran — D1/AC5) ; idem sous un `LayoutBuilder` parent imbriqué.
    - **RTL** : le même conteneur sous `Directionality(textDirection: TextDirection.rtl, ...)` → **même** palier qu'en LTR à largeur égale (AC5/AD-13).
  - [x] T3.2 (Optionnel, si trivial) test statique/grep d'absence d'import gestionnaire d'état dans le fichier (sinon couvert par l'analyse repo `no_get_in_core`-style + revue). — couvert par revue : le fichier n'importe que `flutter/widgets.dart` + l'import relatif de `ZWindowSizeClass`.
- [x] **T4 — Vérif verte ciblée + graphe** (AC6)
  - [x] T4.1 `dart analyze packages/zcrud_responsive` → RC=0 (0 issue).
  - [x] T4.2 `flutter test packages/zcrud_responsive` → tous verts (les tests EX-UI.1 restent verts + les neufs) — **49 tests**.
  - [x] T4.3 `dart run melos run generate` → SUCCESS (no-op pour ce package, 0 `.g.dart`).
  - [x] T4.4 `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE / CORE OUT=0** (aucune nouvelle arête) ; `melos list` **inchangé** (aucun nouveau package). `melos run analyze`/`verify` **repo-wide** → **délégués à l'orchestrateur** (gate de commit d'epic).

---

## Dev Notes

### Fichiers (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_responsive/lib/src/presentation/z_responsive_layout.dart` | **NEW** — widget `ZResponsiveLayout` |
| `packages/zcrud_responsive/lib/zcrud_responsive.dart` | **UPDATE** — 1 ligne `export 'src/presentation/z_responsive_layout.dart';` |
| `packages/zcrud_responsive/test/z_responsive_layout_test.dart` | **NEW** — tests widget |

⛔ **NE PAS TOUCHER** : `packages/zcrud_core/**` (aucune écriture du cœur) ; `z_window_size_class.dart` / `z_breakpoint_value.dart` (livrés EX-UI.1, **consommés** en lecture) ; `pubspec.yaml` (racine ou package — aucune nouvelle dépendance) ; `melos.yaml`. **Coordination** : si EX-UI.3 est en vol en parallèle, **sérialiser** l'édition du barrel (une seule story écrit `lib/zcrud_responsive.dart` à la fois).

### Références de code (best-of-breed, LECTURE SEULE — à neutraliser, pas copier)

- **`zcrud_responsive`** (EX-UI.1) `packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart` — **source RÉUTILISÉE** : `ZWindowSizeClass.fromWidth(double)` (sélection pure) ; `ZWindowSizeClass.of(context)` existe mais **n'est pas** le chemin par défaut (le layout mesure le conteneur, pas l'écran — D1).
- **lex** `packages/lex_ui/lib/core/utils/breakpoints.dart` — patron `ResponsiveLayout` 3 builders. **Neutraliser** : `ConsumerWidget → StatelessWidget` (ref mort supprimé), bools → `ZWindowSizeClass`, `MediaQuery` écran → `LayoutBuilder.constraints.maxWidth`.

### Invariants AD applicables (rappel ciblé)

- **AD-1 / NFR-U1** : aucune nouvelle arête `zcrud_*` (le fichier n'importe que `flutter` + une primitive **interne** au package) ; `CORE OUT=0` intact ; `graph_proof.py` ACYCLIQUE ; `melos list` inchangé.
- **AD-29 (AMENDÉ)** : `zcrud_responsive` (dépend de `zcrud_core`) — `z_responsive_layout.dart` vit sous `lib/src/presentation/`, exposé par le barrel. Réutilise `ZWindowSizeClass` (EX-UI.1), ne redéclare rien.
- **AD-2 / AD-15 / NFR-U2** : `StatelessWidget`, **aucun** gestionnaire d'état/routeur, **aucun** `setState`.
- **AD-5 / AD-14** : sélection déléguée à la fonction **pure** `ZWindowSizeClass.fromWidth` (testable sans `BuildContext` au niveau domaine ; le widget la teste sous `LayoutBuilder`).
- **AD-10 / NFR-U10** : **défaut sûr** — `compact` requis ⇒ la cascade a toujours un plancher ⇒ **jamais** d'écran vide.
- **AD-13 / NFR-U4** : directionnellement neutre (RTL-safe) — testé.
- **AD-31** : mesure **locale** (`LayoutBuilder`), **jamais** `Get.width` ni largeur écran figée.
- **AD-12 / NFR-U8** : zéro secret. **NFR-U7** : piloté par enum, jamais `bool` de classe d'écran. **NFR-U11** : pas de codegen.

### Project Structure Notes

- Le fichier respecte `lib/src/presentation/` (impl) exposée par le barrel `lib/<pkg>.dart` — convention du monorepo.
- `WidgetBuilder` est le typedef Flutter standard (`Widget Function(BuildContext)`) — pas de typedef maison à créer.
- Choix `WidgetBuilder` (lazy) plutôt que `Widget` (eager) : évite de construire les 3 sous-arbres à chaque frame ; seul le palier retenu est instancié (aligné SM-1 / rebuild ciblé, AD-25).

### Dépendances aval (ce que cette story débloque)

Aucune story EX-UI n'a `ZResponsiveLayout` en dépendance dure. La story est **feuille** dans le graphe EX-UI (parallélisable intra-P1 avec EX-UI.3). L'adoption réelle in-app est **déférée** (DW-EXUI-1).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.2 (3 builders, cascade, `ConsumerWidget` mort retiré) ; § Séquencement (parallélisable intra-P1 après EX-UI.1)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § Amendement de réconciliation E3-4 (l.86-87 — `ZResponsiveLayout` liste des types neufs de `zcrud_responsive`) ; § AD-29 amendé (l.89-92) ; § AD-13 (l.58) ; § Consistency (l.115-116) ; § À neutraliser (l.199 — `MediaQuery.sizeOf`/`LayoutBuilder` au lieu de `Get.width`/écran) ; § Stack interdits (l.133)]
- [Source: `packages/zcrud_responsive/lib/src/domain/z_window_size_class.dart` (EX-UI.1 — `ZWindowSizeClass.fromWidth`/`of`, seuils 600/840) ; `packages/zcrud_responsive/lib/zcrud_responsive.dart` (barrel à mettre à jour)]
- [Source: `_bmad-output/implementation-artifacts/stories/ex-ui-1-scaffolding-responsive-breakpoints.md` (modèle de format ; primitives livrées)]
- [Source: `CLAUDE.md` — Key Don'ts (AD-1/AD-2/AD-13 : `ListView.builder`, variantes directionnelles, pas de gestionnaire d'état dans les packages purs), naming préfixe `Z`, gates CI, vérif verte]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Widget** | Palier par largeur de conteneur forcée (599/600/839/840) → bon builder rendu ; autres builders non invoqués | AC1, AC2 |
| **Widget** | Cascade : `compact` seul (700/1000 → compact) ; `compact`+`medium` (1000 → medium) ; `compact`+`expanded` (700 → compact) | AC3 |
| **Widget** | Largeur LOCALE : `SizedBox(width:500)` sous `MediaQuery` 1200 → compact ; `LayoutBuilder` imbriqué / split-view | AC5, D1 |
| **Widget** | `Directionality.rtl` → même palier qu'en LTR à largeur égale | AC5, AD-13 |
| **Statique / revue** | Aucun import `get`/`flutter_riverpod`/`provider`/`go_router` ; `StatelessWidget` ; aucun seuil 600/840 recodé | AC4, D5 |
| **Graphe / gates** | `graph_proof` ACYCLIQUE / CORE OUT=0 (aucune arête neuve) ; `analyze` RC=0 ; `generate` no-op ; `melos list` inchangé | AC6, NFR-U1/U11 |

**Definition of Done** : AC1→AC6 verts · `ZResponsiveLayout` = `StatelessWidget` piloté par `ZWindowSizeClass` sur **largeur locale** (`LayoutBuilder`), `compact` requis + cascade descendante (jamais d'écran vide) · **aucun** gestionnaire d'état/routeur, **aucun** seuil 600/840 recodé, **aucune** nouvelle arête `zcrud_*` · barrel mis à jour (édition ciblée, sérialisée avec EX-UI.3) · RTL testé · `dart analyze` ciblé RC=0 + `flutter test` verts + `melos generate` no-op + `graph_proof` ACYCLIQUE/CORE OUT=0 · `melos run analyze`/`verify` repo-wide RC=0 (gate de commit d'epic orchestrateur) · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- Échec initial des 3 cas `expanded` (largeur ≥ 840) : la surface de test par défaut fait 800×600, donc `ConstrainedBox.tightFor(width)` était **bridé** à 800 par les contraintes entrantes → palier medium au lieu d'expanded. Corrigé en remplaçant le harness par un `OverflowBox` (min=max=width) qui impose une contrainte de largeur locale tight indépendante de la surface et autorise le dépassement sans erreur d'overflow. Après correction : 49/49 verts.

### Completion Notes List

- `ZResponsiveLayout` = `StatelessWidget` `const`, 3 builders `WidgetBuilder` (`compact` requis + `medium?`/`expanded?`), sélection via `LayoutBuilder` → `ZWindowSizeClass.fromWidth(constraints.maxWidth)` (largeur **locale**, jamais l'écran) + `_builderFor` (cascade descendante `expanded ?? medium ?? compact`).
- **Aucun** seuil 600/840 recodé (délégation totale à `fromWidth`) ; **aucun** gestionnaire d'état/routeur ; **aucun** import hors `flutter/widgets.dart` + `../domain/z_window_size_class.dart` → **aucune** nouvelle arête `zcrud_*`.
- D1–D6 respectées ; `ConsumerWidget`/`ref` mort de lex neutralisé.
- Vérifs rejouées : `dart pub get` RC=0 ; `melos run generate` RC=0 (no-op, 0 `.g.dart`) ; `dart analyze packages/zcrud_responsive` RC=0 (No issues found) ; `flutter test packages/zcrud_responsive` = **49 tests** verts (anciens EX-UI.1 + neufs) ; `graph_proof.py` **ACYCLIQUE / CORE OUT=0**.
- Barrel étendu par **une seule ligne** d'`export` (aucun ré-export `zcrud_core`/domaine altéré). `.gitkeep` de `presentation/` laissé en place (cosmétique, non requis).
- ⛔ Aucune écriture de `zcrud_core/**`, `melos.yaml`, `pubspec.yaml`, ni des primitives EX-UI.1.
- `melos run analyze`/`verify` **repo-wide** délégués au gate de commit d'epic de l'orchestrateur.

### File List

- `packages/zcrud_responsive/lib/src/presentation/z_responsive_layout.dart` (NEW)
- `packages/zcrud_responsive/lib/zcrud_responsive.dart` (UPDATE — 1 ligne export)
- `packages/zcrud_responsive/test/z_responsive_layout_test.dart` (NEW)

### Questions pour l'orchestrateur (remontées, non bloquantes)

1. **Sérialisation du barrel avec EX-UI.3** : EX-UI.2 et EX-UI.3 ajoutent chacune une ligne d'`export` à `lib/zcrud_responsive.dart`. Si les deux sont en vol, l'orchestrateur doit **sérialiser** l'édition du barrel (une story écrit, l'autre rebase). **Recommandation : traiter EX-UI.2 puis EX-UI.3** (ou l'inverse) sur le barrel, jamais en parallèle sur ce fichier.
2. **Sort du `.gitkeep`** : `lib/src/presentation/.gitkeep` devient superflu dès qu'un vrai fichier peuple le dossier. Le supprimer est cosmétique — laissé au choix du dev (non requis par un AC).
