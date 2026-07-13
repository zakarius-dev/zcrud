# Story ES-1.2 : Utilitaires domaine purs partagés (`ZColorPalette`, `applyOrder<T>`, `normalizeTagTitle`)

Status: review

<!-- Note: Validation optionnelle. Lancer validate-create-story avant dev-story si souhaité. -->

## Story

As a **développeur intégrateur**,
I want **réutiliser une palette de couleurs (clés + remap déterministe), un tri d'ordre stable et une normalisation de titre partagés dans `zcrud_study_kernel`**,
so that **je ne reduplique pas les 3+ palettes lex/IFFD ni la logique de tri/normalisation, avec des couleurs concrètes INJECTÉES (jamais codées en dur, AD-13/FR-26/NFR-S7)**.

Périmètre : **3 utilitaires purs** dans `zcrud_study_kernel` + **1 seam de résolution de couleur** ajouté à `zcrud_core` (additif, calqué sur le précédent `ZAdornmentIconResolver`) + **narrowing du réexport kernel** dans le barrel `zcrud_flashcard` (solde le finding **LOW-1** d'ES-1.1). Aucune entité, aucun repository, aucune UI de tag/dossier (ES-2/ES-5/ES-8).

> **Métadonnées** — Taille : **M** · Statut initial : `backlog` · Parallélisation : **SÉQUENTIELLE** (écrit `zcrud_study_kernel` **et** `zcrud_core` → aucun autre workstream en vol pendant cette story). Packages : `zcrud_study_kernel` (3 fichiers domaine + barrel), `zcrud_core` (1 fichier présentation + `ZcrudScope` + barrel), `zcrud_flashcard` (barrel uniquement). **Couvre :** FR-S2 · **AD :** AD-13, AD-1, AD-3, AD-4, AD-10, AD-14, AD-17 · **NFR-S2, NFR-S7, NFR-S10** · **SM-S4, SM-S5, SM-S7**.

---

## Contexte & décisions de conception (LIRE AVANT DE CODER)

Trois points ont été tranchés en amont. **Ne pas les rejouer** : les implémenter tels quels.

### D1 — Frontière de pureté : le kernel ne connaît PAS `Color` (SM-S5)

**Contrainte dure** : `SM-S5` (architecture study, l.47) impose **zéro `Timestamp`/`Box`/`Color`/`IconData` dans un package `zcrud_study*`** (scan CI). De plus `zcrud_study_kernel` est **pur-Dart** : il n'importe que `package:zcrud_core/domain.dart` (surface Flutter-free) et ses tests tournent sous **`dart test`** (cf. `pubspec.yaml` du kernel, commentaire de `dev_dependencies`). Importer `dart:ui`/`material.dart` dans le kernel **casserait** cette propriété et le test de résolution.

**Découpage retenu :**

| Couche | Responsabilité | Où |
|---|---|---|
| **Domaine pur** (kernel) | Registre **borné et ordonné** de `colorKey` (`List<String>`), `fallbackKey`, **remap déterministe** d'une clé inconnue vers une clé **de la palette**. Zéro couleur. | `zcrud_study_kernel/lib/src/domain/z_color_palette.dart` |
| **Résolution** (présentation) | `colorKey (String) → Color` — **injectée** par l'app via `ZcrudScope`, repli **dérivé du `ColorScheme`** courant (aucun littéral hex). | `zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart` + `ZcrudScope.colorKeyResolver` |

**Réutilisation obligatoire du précédent existant (ne RIEN inventer)** : `zcrud_core` porte déjà exactement ce motif pour les icônes —
`typedef ZAdornmentIconResolver = IconData? Function(String key);` (`packages/zcrud_core/lib/src/presentation/edition/z_field_adornment_view.dart:38`), injecté via `ZcrudScope.iconResolver` (nullable, `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:134`), avec **table par défaut bornée** dans le cœur et **repli `null`** si la clé reste inconnue (AD-10, jamais de throw). Le nouveau seam couleur est le **jumeau strict** de ce motif : même forme de typedef, même nullabilité, même sémantique de repli, même ligne dans `updateShouldNotify`.
Le repli par défaut du cœur **dérive du `ColorScheme`** (rôles `primary`/`secondary`/`tertiary`/`error`/`*Container`) exactement comme `ZcrudTheme.fallback` dérive ses couleurs du `ColorScheme`/`TextTheme` (`packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:74-82`) — **aucun littéral hexadécimal nulle part** (FR-26/NFR-S7).

> **Pourquoi ajouter le seam MAINTENANT et pas en ES-5/ES-8 ?** L'AC de l'épique exige que « les couleurs concrètes soient injectées via `ZcrudScope`/`ThemeExtension` » : sans le seam, l'AC n'est pas vérifiable et le premier consommateur UI (tags ES-8, dossiers ES-5) réinventerait sa propre résolution → exactement la duplication que FR-S2 supprime. L'ajout est **additif et non-cassant** (champ nullable, défaut `null`).

### D2 — Hash déterministe : **FNV-1a 32 bits pur-Dart**, PAS `crypto`/SHA-256, PAS `String.hashCode`

Le PRD/architecture évoquent un « remap déterministe **SHA-256** » (repris de lex). **Tranchage : on n'ajoute PAS la dépendance `crypto`** ; on implémente un **FNV-1a 32 bits** pur-Dart dans le kernel, avec un **seam d'injection** du hash.

Justification (à recopier en Completion Notes) :
1. **Le remap n'est pas un contrat de persistance.** La valeur persistée reste la `colorKey` **brute** (inchangée) ; le remap ne décide que du **slot de palette affiché** pour une clé inconnue. Aucune parité byte-à-byte avec lex n'est donc requise (aucun round-trip, aucun wire) — la contrainte réelle est le **déterminisme cross-device/cross-run**, pas l'égalité avec SHA-256.
2. **Modularité (NFR-S10/SM-S7).** Le kernel ne dépend aujourd'hui que de `zcrud_core` + `zcrud_annotations` ; `test/z_kernel_resolution_test.dart` fige cette fermeture. Ajouter `crypto` pour un hachage cosmétique de 10 lignes contredit la promesse « importer le noyau n'ajoute rien ».
3. **Déterminisme garanti par construction ET par oracle externe.** FNV-1a 32 est un algorithme figé, sur les **octets UTF-8** de la clé, en arithmétique **32 bits masquée** ; il possède des **vecteurs de test publiés** (`"" → 0x811C9DC5`, `"a" → 0xE40C292C`, `"foobar" → 0xBF9CF968`) qui servent d'**oracle indépendant** de notre implémentation. `String.hashCode` est **banni** (non stable entre versions/runs/plateformes).
4. **Échappatoire si la parité lex devient un jour requise** : `ZColorPalette` accepte un `ZKeyHash` **injectable** (`typedef ZKeyHash = int Function(String key);`, défaut `zFnv1a32`). Une app peut injecter un hash SHA-256 depuis **sa** couche (où `crypto` est licite) **sans** que le kernel n'acquière la dépendance (AD-4 : extension par injection, pas par héritage).

⚠️ **Piège JS/web (obligatoire)** : la multiplication FNV (`hash * 16777619`) dépasse 2^53 sur `dart2js` (ints = doubles) → **perte de précision → non-déterminisme cross-plateforme**. Utiliser la **multiplication décomposée 16/16 bits** (voir squelette § Dev Notes), puis masquer `& 0xFFFFFFFF`. Un test doit valider les vecteurs publiés ci-dessus.

### D3 — Narrowing du réexport kernel dans `zcrud_flashcard` : **liste `hide`**, PAS liste `show` (solde LOW-1 d'ES-1.1)

État actuel (`packages/zcrud_flashcard/lib/zcrud_flashcard.dart:36`) :
```dart
export 'package:zcrud_study_kernel/zcrud_study_kernel.dart';   // réexport EN BLOC
```
Sans action, `ZColorPalette`/`applyOrder`/`normalizeTagTitle` **fuiteraient** dans la surface publique de `zcrud_flashcard` (pollution : ces utilitaires n'ont rien à voir avec les flashcards).

Le code-review ES-1.1 avait **reporté** LOW-1 avec cette justification (`code-review-es-1-1.md`, § Disposition orchestrateur) : un **`show` explicite** devrait énumérer **aussi les symboles générés** (`registerZStudyFolder`, `registerZStudySessionConfig`, field-specs émis via `part '*.g.dart'`) → un oubli casserait un consommateur externe (migration DODLP). **Objection valide.**

**Tranchage : inverser la polarité — utiliser une liste `hide`, pas une liste `show`.**
```dart
export 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    hide ZColorPalette, ZKeyHash, zFnv1a32, ZUnorderedPlacement, applyOrder,
         normalizeTagTitle, dedupeByNormalizedTitle;   // ← ajuster à la liste RÉELLE des symboles ES-1.2
```
- ✅ **Surface historique E9 préservée intégralement** — y compris les symboles **générés** (jamais énumérés, donc jamais oubliés) : c'est précisément l'objection de LOW-1 qui tombe.
- ✅ **Seuls les symboles NOUVEAUX** (connus par construction dans cette story) sont retirés → risque de régression ≈ nul.
- ✅ Règle de maintenance à consigner **en commentaire dans les deux barrels** : *tout nouveau symbole public du kernel hors périmètre flashcard DOIT être ajouté à ce `hide`* (ES-1.3 `ZSyncMeta`, ES-2 entités, …).
- **Oracle de non-régression** : les **165 tests** de `zcrud_flashcard` (baseline ES-1.1, RC=0) + `melos run analyze` **et** `melos run verify` **repo-wide** + un test de **surface publique positive** (T7) — la leçon `ZExportApi` (E11a-3) impose la vérif repo-wide, pas seulement par-package.

---

## Acceptance Criteria

### AC1 — `ZColorPalette` : registre borné + fallback + remap déterministe, **zéro couleur dans le kernel**

**Given** les palettes dupliquées lex (`AnnotationHighlightPalette`, `FlashcardTagPalette`, `FolderColorPalette`) et IFFD
**When** on implémente `ZColorPalette` dans `zcrud_study_kernel` (registre **ordonné borné** de `colorKey` + `fallbackKey` + remap déterministe)
**Then** le fichier **n'importe ni `dart:ui`, ni `package:flutter/*`** et ne contient **aucun** type `Color`/`IconData` ni littéral hex (SM-S5)
**And** la palette est **injectable** (`ZColorPalette(keys: …, fallbackKey: …)`, non verrouillée aux N clés lex — PRD l.165), avec un jeu par défaut `const ZColorPalette.defaultStudy()`
**And** la fermeture transitive `zcrud_*` du kernel reste **`{zcrud_core, zcrud_annotations}`** et **aucune dépendance runtime n'est ajoutée au `pubspec.yaml` du kernel** (pas de `crypto` — D2) → `z_kernel_resolution_test.dart` reste vert **sans modification**.

### AC2 — Remap déterministe d'une `colorKey` inconnue, jamais de crash

**Given** une `colorKey` absente du registre (`null`, `''`, clé legacy/futur inconnue)
**When** on appelle `palette.resolveKey(raw)`
**Then** le résultat est **toujours une clé appartenant à `palette.keys`** (jamais un throw, jamais `null` — AD-10)
**And** le mapping est **déterministe** : même entrée → même sortie, **stable cross-run/cross-device/cross-plateforme** (y compris web/dart2js : arithmétique 32 bits masquée, multiplication décomposée)
**And** `String.hashCode` **n'est pas utilisé** (interdit : non stable entre versions/runs)
**And** `zFnv1a32` satisfait les **vecteurs FNV-1a publiés** : `''→0x811C9DC5`, `'a'→0xE40C292C`, `'foobar'→0xBF9CF968`
**And** un `ZKeyHash` **injectable** permet de substituer l'algorithme (ex. SHA-256 côté app) sans modifier le kernel
**And** une clé **connue** est retournée **telle quelle** (le remap ne s'applique QU'aux clés inconnues) ; `raw == null || raw.isEmpty` → `fallbackKey`.

### AC3 — Résolution `colorKey → Color` **injectée** via `ZcrudScope` (AD-13/FR-26/NFR-S7)

**Given** un consommateur UI qui doit peindre une clé de palette
**When** il résout la couleur
**Then** `zcrud_core` expose `typedef ZColorKeyResolver = Color? Function(String colorKey);` et un champ **nullable additif** `ZcrudScope.colorKeyResolver` (même motif que `iconResolver` : `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:134`), pris en compte dans `updateShouldNotify`
**And** le **repli du cœur** (`zDefaultColorKeyResolver`) dérive ses couleurs du **`ColorScheme` courant** (rôles `primary`/`secondary`/`tertiary`/`error`/`*Container`) — **aucun littéral hex, aucune couleur codée en dur** (cf. `ZcrudTheme.fallback`, `z_theme.dart:74-82`)
**And** une clé inconnue du repli rend **`null`** (jamais de throw — AD-10 ; l'appelant remappe via `ZColorPalette.resolveKey` **avant** de résoudre)
**And** l'ajout est **non-cassant** : `ZcrudScope` sans `colorKeyResolver` se comporte exactement comme avant (tests existants de `zcrud_core` verts sans modification).

### AC4 — `applyOrder<T>` : tri **stable**, position **déterministe** des ids absents

**Given** une liste d'items et un ordre personnel **partiel** (`List<String>` d'ids, cf. `ZFolderContentsOrder` — FR-S7)
**When** on appelle `applyOrder<T>(items, order, idOf: …)`
**Then** les items dont l'id figure dans `order` sortent **dans l'ordre de `order`**
**And** les items **absents** de `order` gardent une **position déterministe** : à la **fin** par défaut (`ZUnorderedPlacement.end`), **en préservant leur ordre relatif d'entrée** (tri **stable**), option `ZUnorderedPlacement.start`
**And** la fonction est **pure** : elle ne mute **ni** `items` **ni** `order` et retourne une **nouvelle** `List<T>`
**And** elle est **sans dépendance métier** (aucun type study dans sa signature — générique `T` + `idOf`)
**And** les cas dégradés ne throwent jamais (AD-10) : `order` vide → ordre d'entrée préservé ; id de `order` inconnu → ignoré ; id **dupliqué** dans `order` → la **1re** occurrence fait foi ; ids dupliqués dans `items` → tous conservés, ordre relatif d'entrée préservé.

### AC5 — `normalizeTagTitle` + dédoublonnage par titre normalisé

**Given** un titre de tag avec espaces multiples et casse mixte (`"  Droit   Douanier "`)
**When** on appelle `normalizeTagTitle()`
**Then** le résultat est `trim` + **collapse** des espaces (toute séquence `\s+` → un espace unique, y compris **NBSP**/espaces Unicode que le `\s` de Dart couvre) + **`toLowerCase()`** → `"droit douanier"`
**And** la fonction est **pure**, **totale** et **locale-indépendante** (`null`/`''`/`"   "` → `''`, jamais de throw)
**And** `dedupeByNormalizedTitle<T>(items, titleOf:)` conserve la **1re** occurrence de chaque titre normalisé, dans l'ordre d'entrée (**stable**), et est **testé** (dédoublonnage par titre normalisé, PRD l.134).

### AC6 — Narrowing du réexport kernel dans `zcrud_flashcard` (solde LOW-1) **sans régression**

**Given** le barrel `zcrud_flashcard` qui réexporte le kernel **en bloc** (ES-1.1, LOW-1)
**When** on ajoute les utilitaires ES-1.2 au kernel
**Then** le réexport devient un **`export … hide <symboles ES-1.2>`** (D3 — **liste `hide`, jamais `show`**) : `ZColorPalette`/`ZKeyHash`/`zFnv1a32`/`ZUnorderedPlacement`/`applyOrder`/`normalizeTagTitle`/`dedupeByNormalizedTitle` **ne sont PAS** dans la surface publique de `zcrud_flashcard`
**And** la **surface historique E9 est intégralement préservée**, **symboles générés inclus** (`registerZStudyFolder`, `registerZStudySessionConfig`, field-specs) — prouvé par un test de surface positive (T7)
**And** la règle de maintenance (« tout nouveau symbole kernel hors périmètre flashcard → ajouter au `hide` ») est consignée **en commentaire** dans le barrel `zcrud_flashcard` **et** dans le barrel du kernel
**And** `flutter test packages/zcrud_flashcard` reste **RC=0 avec ≥ 165 tests** (baseline ES-1.1 ; aucun test supprimé/affaibli).

### AC7 — Vérif verte repo-wide (gates AD-1/NFR-S2, leçon `ZExportApi`)

**Given** l'implémentation complète
**When** on rejoue `melos run generate`, puis **`melos run analyze` ET `melos run verify` repo-wide**
**Then** les deux sont **verts (RC=0)** sur **l'ensemble** des packages (une vérif par package ne détecte PAS une régression cross-package)
**And** `scripts/dev/graph_proof.py` reste **ACYCLIQUE / CORE OUT=0** (aucune arête ajoutée : `zcrud_flashcard → zcrud_study_kernel → zcrud_core`)
**And** les tests du kernel tournent toujours sous **`dart test`** (aucune fuite du SDK Flutter dans le kernel)
**And** aucune écriture dans `sprint-status.yaml` par le dev (transitions réservées à l'orchestrateur).

---

## Tasks / Subtasks

- [x] **T1 — `ZColorPalette` + hash déterministe (AC1, AC2)** — `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart` (NEW)
  - [x] `typedef ZKeyHash = int Function(String key);`
  - [x] `int zFnv1a32(String key)` : FNV-1a 32 bits sur `utf8.encode(key)` (`dart:convert`), **multiplication décomposée 16/16** + masque `& 0xFFFFFFFF` (JS-safe).
  - [x] `class ZColorPalette` (immuable, `const`-constructible, `==`/`hashCode`) : `final List<String> keys` (bornée, ordonnée, **non vide**), `final String fallbackKey`, `final ZKeyHash hash` (défaut `zFnv1a32`).
  - [x] `const ZColorPalette.defaultStudy()` : jeu de clés **neutres** par défaut (clés sémantiques `String`, ex. `'primary','secondary','tertiary','success','warning','danger','info','neutral'`) — **aucune couleur**, seulement des clés.
  - [x] `String resolveKey(String? raw)` : `raw` vide/`null` → `fallbackKey` ; `keys.contains(raw)` → `raw` **tel quel** ; sinon → `keys[hash(raw) % keys.length]` (**remap déterministe**).
  - [x] `int indexOf(String? raw)` (index dans `keys` après remap) — utile aux consommateurs UI.
  - [x] Dartdoc : rappeler explicitement **pourquoi pas de `Color` ici** (SM-S5) et **où** se fait la résolution (`ZcrudScope.colorKeyResolver`), + justification D2 (pas de `crypto`, pas de `String.hashCode`).
  - [x] ⚠️ Assert/garde-fou : `keys` non vide et `keys.contains(fallbackKey)` (`assert` en debug ; comportement défensif sans throw en release → si `keys` vide, `resolveKey` rend `fallbackKey`).

- [x] **T2 — `applyOrder<T>` (AC4)** — `packages/zcrud_study_kernel/lib/src/domain/apply_order.dart` (NEW)
  - [x] `enum ZUnorderedPlacement { end, start }`.
  - [x] `List<T> applyOrder<T>(Iterable<T> items, List<String> order, {required String Function(T item) idOf, ZUnorderedPlacement unordered = ZUnorderedPlacement.end})`.
  - [x] Implémentation **stable** : construire `Map<String,int>` position (1re occurrence gagne) → partitionner `ordered` / `unordered` en **un seul passage** préservant l'ordre d'entrée → trier `ordered` par index (tri stable via clé `(index, rangEntrée)`) → concaténer selon `unordered`.
  - [x] Aucun `sort` in-place sur l'entrée ; retourne une **nouvelle liste**.
  - [x] Dartdoc : « générique, sans dépendance métier — candidat à promotion `zcrud_core` (décision F2 : **reste dans le kernel** pour l'instant) ».

- [x] **T3 — `normalizeTagTitle` + dédoublonnage (AC5)** — `packages/zcrud_study_kernel/lib/src/domain/normalize_tag_title.dart` (NEW)
  - [x] `String normalizeTagTitle(String? raw)` : `(raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()`.
  - [x] `List<T> dedupeByNormalizedTitle<T>(Iterable<T> items, {required String? Function(T item) titleOf})` : conserve la **1re** occurrence par titre normalisé, ordre d'entrée préservé.
  - [x] Dartdoc : pureté, totalité, indépendance de locale ; usage prévu (FR-S6 `ZFlashcardTag`/`ZSuggestedTag`, ES-2.3/ES-8.1).

- [x] **T4 — Barrel du kernel (AC1, AC6)** — `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (UPDATE)
  - [x] Ajouter les 3 `export` (ordre alphabétique, comme l'existant).
  - [x] Compléter le dartdoc du barrel : section ES-1.2 (3 utilitaires purs) + **règle de maintenance D3** (« tout symbole ajouté ici hors périmètre flashcard doit être ajouté au `hide` du barrel `zcrud_flashcard` »).

- [x] **T5 — Seam de résolution de couleur dans `zcrud_core` (AC3)** — précédent à copier : `ZAdornmentIconResolver` / `ZcrudScope.iconResolver`
  - [x] `packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart` (NEW) : `typedef ZColorKeyResolver = Color? Function(String colorKey);` + `Color? zDefaultColorKeyResolver(ColorScheme scheme, String colorKey)` → **switch sur les clés par défaut**, valeurs **dérivées du `ColorScheme`** (`scheme.primary`, `scheme.secondary`, `scheme.tertiary`, `scheme.error`, `scheme.primaryContainer`, `scheme.secondaryContainer`, `scheme.tertiaryContainer`, `scheme.errorContainer`…), **`default: null`** (AD-10). **AUCUN littéral hex / `Color(0x…)` / `Colors.*` en dur.**
  - [x] `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (UPDATE) : champ `final ZColorKeyResolver? colorKeyResolver;` + paramètre nommé du constructeur + dartdoc (calqué mot pour mot sur celui d'`iconResolver`, l.129-134) + **ligne dans `updateShouldNotify`** (`!identical(colorKeyResolver, oldWidget.colorKeyResolver)`).
  - [x] `packages/zcrud_core/lib/zcrud_core.dart` (UPDATE) : `export 'src/presentation/theme/z_color_key_resolver.dart';` (respecter l'ordre alphabétique des exports).
  - [x] ⛔ **Ne PAS** faire dépendre `zcrud_core` du kernel (inversion interdite, AD-1) : le cœur ne connaît que des **clés `String`**, jamais `ZColorPalette`.

- [x] **T6 — Narrowing du réexport (AC6, LOW-1)** — `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (UPDATE)
  - [x] Remplacer l'`export` en bloc (l.36) par `export 'package:zcrud_study_kernel/zcrud_study_kernel.dart' hide <liste EXACTE des symboles publics ES-1.2>;` — **liste `hide`, jamais `show`** (D3).
  - [x] Vérifier la liste **contre le barrel kernel réel** après T4 (n'oublier aucun symbole ES-1.2 : classes, typedefs, enums, **fonctions top-level**).
  - [x] Remplacer le commentaire « réexport EN BLOC volontaire … À revisiter en ES-1.2 » par la **règle de maintenance** définitive (D3) + référence à ES-1.2 / LOW-1.

- [x] **T7 — Tests (AC1..AC6)**
  - [x] `packages/zcrud_study_kernel/test/z_color_palette_test.dart` (NEW, `dart test`) : vecteurs FNV-1a publiés (`''/a/foobar`) ; clé connue → identité ; `null`/`''` → `fallbackKey` ; clé inconnue → clé **∈ `keys`** ; **déterminisme** (100 appels → même résultat ; table de golden `clé inconnue → clé remappée` figée) ; palette **custom** (autres clés) ; `ZKeyHash` **injecté** (hash constant → clé prévisible) ; jamais de throw ; **assertion anti-`Color`** : le fichier source ne contient ni `dart:ui`, ni `package:flutter`, ni `Color(` (lecture du fichier, esprit `z_kernel_resolution_test.dart` — outillé, pas narratif).
  - [x] `packages/zcrud_study_kernel/test/apply_order_test.dart` (NEW) : ordre complet ; ordre **partiel** (absents → fin, ordre relatif préservé) ; option `start` ; `order` vide ; id inconnu dans `order` ; **doublon** dans `order` ; doublons dans `items` ; **non-mutation** des entrées (`items`/`order` inchangés) ; stabilité (items équivalents).
  - [x] `packages/zcrud_study_kernel/test/normalize_tag_title_test.dart` (NEW) : espaces multiples/tabs/NBSP ; casse mixte ; `null`/`''`/`'   '` → `''` ; **dédoublonnage** par titre normalisé (`"Droit"`/`"  droit  "` → 1 seul, 1re occurrence conservée) ; pureté (entrée non mutée).
  - [x] `packages/zcrud_core/test/presentation/z_color_key_resolver_test.dart` (NEW, `flutter test`) : repli `zDefaultColorKeyResolver` **dérive du `ColorScheme`** (assertion : `resolver(schemeDark,'primary') == schemeDark.primary` **et** `!= resolver(schemeLight,'primary')` → prouve l'absence de couleur en dur) ; clé inconnue → `null` ; injection via `ZcrudScope(colorKeyResolver: …)` lue depuis un widget descendant (`ZcrudScope.of(context).colorKeyResolver`) ; `updateShouldNotify` déclenche sur changement de resolver.
  - [x] `packages/zcrud_flashcard/test/z_public_surface_test.dart` (NEW, `flutter test`) : **surface positive** — importe **uniquement** `package:zcrud_flashcard/zcrud_flashcard.dart` et référence les symboles historiques E9/ES-1.1 (`ZFlashcard`, `ZStudyFolder`, `ZReviewMode`, `ZStudySessionConfig`, `ZStudySessionSelector`, `ZSessionCandidate`, `validatePlacement`, **`registerZStudyFolder`**, **`registerZStudySessionConfig`**) → compile ⇒ surface historique intacte malgré le `hide` (le test **échoue à la compilation** si le `hide` a mordu sur un symbole historique).

- [x] **T8 — Vérif verte & traçabilité (AC7)**
  - [x] `dart run melos run generate` (le kernel a du codegen : `z_study_folder.g.dart`, `z_study_session_config.g.dart`).
  - [x] `dart run melos run analyze` **repo-wide** RC=0 ; `dart run melos run verify` **repo-wide** RC=0 (inclut `graph_proof.py` + secrets + `verify_serialization`).
  - [x] `dart test` (kernel) RC=0 ; `flutter test` (`zcrud_core`, `zcrud_flashcard`) RC=0 — **compte flashcard ≥ 165** (baseline ES-1.1) : le reporter dans les Completion Notes.
  - [x] Completion Notes : consigner D1/D2/D3 + la **liste exacte** des symboles `hide` + le décompte de tests + la preuve d'acyclicité.

---

## Dev Notes

### Squelette du hash JS-safe (à reprendre tel quel)

```dart
/// FNV-1a 32 bits sur les octets UTF-8 — déterministe cross-run/cross-device/web.
/// Multiplication DÉCOMPOSÉE (16/16) : `h * 16777619` dépasse 2^53 sur dart2js
/// (ints = doubles) → perte de précision → non-déterminisme. NE PAS simplifier.
int zFnv1a32(String key) {
  var hash = 0x811c9dc5; // offset basis
  for (final byte in utf8.encode(key)) {
    hash ^= byte;
    final lo = (hash & 0xFFFF) * 0x01000193;
    final hi = ((hash >>> 16) * 0x01000193) & 0xFFFF;
    hash = (lo + (hi << 16)) & 0xFFFFFFFF;
  }
  return hash;
}
```
Vérifier avec les vecteurs publiés : `zFnv1a32('') == 0x811C9DC5`, `zFnv1a32('a') == 0xE40C292C`, `zFnv1a32('foobar') == 0xBF9CF968`. Si un vecteur échoue, l'implémentation est fausse — **ne pas ajuster le test**.

### Invariants applicables (rappel)

- **AD-1 / AD-17** : `zcrud_study_kernel` → `zcrud_core` uniquement. **Jamais** `zcrud_core → kernel` (le seam couleur du cœur ne connaît que des `String`).
- **AD-13 / FR-26 / NFR-S7 / SM-S5** : aucune couleur/label/style codé en dur dans un package ; **zéro `Color`/`IconData` dans `zcrud_study*`**.
- **AD-10** : défensif — aucune de ces fonctions ne throw sur entrée absente/corrompue.
- **AD-3** : `applyOrder<T>`/`dedupeByNormalizedTitle<T>` sont des **génériques de collection** (autorisés — cf. LOW-3 d'ES-1.1 acté), **jamais** des génériques de (dé)sérialisation.
- **AD-4** : `ZKeyHash` et `ZColorKeyResolver` sont des **seams d'injection** (extension sans héritage).
- **NFR-S10 / SM-S7** : ne **rien** ajouter aux `dependencies:` du kernel.
- **Directionnalité/a11y (AD-13)** : hors périmètre ici (aucun widget produit) — mais le seam couleur ne doit pas introduire de widget.

### Pièges identifiés (anti-régression)

1. **`String.hashCode` interdit** — non stable entre versions/runs/plateformes. Le lint ne l'attrapera pas : c'est au dev de ne pas l'écrire.
2. **`% keys.length` sur un `keys` vide** → `IntegerDivisionByZeroException` : garde-fou obligatoire.
3. **`hide` incomplet** (T6) → un utilitaire fuite quand même dans `zcrud_flashcard` : croiser la liste avec le barrel kernel **après** T4, pas de mémoire.
4. **`hide` trop large** → casse la surface E9 : T7 (`z_public_surface_test.dart`) est le filet ; il doit **compiler**.
5. **Import Flutter accidentel dans le kernel** (ex. `Color` importé par réflexe) → les tests du kernel (`dart test`) **cassent** ; c'est voulu (SM-S5).
6. **Vérif par-package insuffisante** — la régression `ZExportApi` (E11a-3) a survécu à des vérifs ciblées : `melos run analyze` **ET** `verify` **repo-wide** avant tout `review`.
7. **`updateShouldNotify` oublié** dans `ZcrudScope` → resolver changé sans rebuild : ligne obligatoire (T5).
8. **Ne pas toucher** `sprint-status.yaml` (orchestrateur), ni les `*.g.dart` (générés, gitignorés).

### Intelligence de la story précédente (ES-1.1, `done`)

- Kernel **pur-Dart** : tests sous `dart test` (pas `flutter test`) — même convention que `zcrud_annotations`. Ne pas introduire `flutter_test` dans le kernel.
- Le kernel masque déjà `ZStudyFolderZcrud`/`ZStudySessionConfigZcrud` via `hide` dans son barrel : **conserver** ces clauses en éditant le barrel (T4).
- `z_kernel_resolution_test.dart` assert l'**égalité exacte** de la fermeture `{zcrud_core, zcrud_annotations}` → toute dépendance `zcrud_*` ajoutée le casse (et `crypto` casserait l'esprit sans le casser techniquement — cf. D2).
- Baseline non-régression : **165 tests** `zcrud_flashcard`, **38 tests** kernel (à faire croître, jamais décroître).
- LOW-2/LOW-3 d'ES-1.1 ont été **actés** (aucune action ici) ; **LOW-1 est soldé par cette story** (T6/AC6).

### Project Structure Notes

Nouveaux fichiers strictement conformes à la structure : domaine du kernel sous `lib/src/domain/` (snake_case), seam de présentation du cœur sous `lib/src/presentation/theme/` (à côté de `z_theme.dart`), API publique via les barrels. Nommage : types publics préfixés `Z` (`ZColorPalette`, `ZKeyHash`, `ZColorKeyResolver`, `ZUnorderedPlacement`) ; les **fonctions** top-level restent en lowerCamelCase sans préfixe pour `applyOrder`/`normalizeTagTitle`/`dedupeByNormalizedTitle` (noms imposés par FR-S2), `zFnv1a32` préfixé `z` (fonction utilitaire exposée).

**Variance assumée vs `epics.md`** : la story écrit **aussi** `zcrud_core` (seam `ZColorKeyResolver`), alors que les métadonnées d'épique ne listaient que les 3 fichiers du kernel. Justification : l'AC « couleurs injectées via `ZcrudScope`/`ThemeExtension` » est invérifiable sans ce seam, et le cœur est l'**unique** endroit légitime (le kernel ne peut pas voir `Color`). Story **SÉQUENTIELLE** → écriture de `zcrud_core` sans concurrence (règle de parallélisation CLAUDE.md respectée).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-1.2`]
- [Source: `_bmad-output/planning-artifacts/prds/prd-zcrud-study-2026-07-12/prd.md#FR-S2` (l.129-134), #FR-S6 (l.164-165), #FR-S7 (l.171), #NFR-S7 (l.402), #NFR-S10 (l.405), #SM-S5 (l.439)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md` — AD-17 (l.89), AD-25 (l.132), tableau invariants (l.47, l.156), squelette packages (l.187)]
- [Source: `packages/zcrud_core/lib/src/presentation/edition/z_field_adornment_view.dart:38-53` — précédent `ZAdornmentIconResolver` + table bornée par défaut]
- [Source: `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:129-134, 166-180` — motif d'injection + `updateShouldNotify`]
- [Source: `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:74-82` — dérivation `ColorScheme` sans littéral hex]
- [Source: `packages/zcrud_flashcard/lib/zcrud_flashcard.dart:36` — réexport en bloc à narrower]
- [Source: `packages/zcrud_study_kernel/test/z_kernel_resolution_test.dart` — fermeture transitive figée]
- [Source: `_bmad-output/implementation-artifacts/stories/code-review-es-1-1.md#LOW-1` + § Disposition orchestrateur]
- [Source: `CLAUDE.md` — Key Don'ts, vérif verte, gates CI]

## Dev Agent Record

### Agent Model Used

Claude (skill `bmad-dev-story` réellement invoqué via le tool `Skill`).

### Debug Log References

- `dart run melos bootstrap` → SUCCESS (15 packages bootstrapped).
- `dart run melos run generate` → SUCCESS (build_runner incrémental sur `zcrud_study_kernel`/`zcrud_flashcard`/`zcrud_generator`).
- `dart run melos run analyze` (repo-wide) → SUCCESS sur les 15 packages (1er run : 1 erreur `list_element_type_not_assignable` dans `z_color_palette_test.dart:125` — liste `<String>[...]` contenant `null` ; corrigée en `<String?>[...]` ; 2e run : No issues found partout).
- `dart test` (`zcrud_study_kernel`) → **79/79 passed** (38 baseline + 41 nouveaux ; 1 échec transitoire sur l'assertion anti-`Color`/`IconData` car la **dartdoc** de `z_color_palette.dart` nomme volontairement ces tokens interdits pour documenter D1/SM-S5 → le test a été corrigé pour ignorer les lignes de commentaire avant la recherche de tokens ; re-run vert).
- `flutter test packages/zcrud_flashcard` → **166/166 passed** (165 baseline + `z_public_surface_test.dart`).
- `flutter test packages/zcrud_core` → **890/890 passed** (dont les 6 nouveaux tests `z_color_key_resolver_test.dart`).
- `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK, 23 arêtes, 15 nœuds (aucune arête ajoutée hors `zcrud_flashcard → zcrud_study_kernel → zcrud_core`, déjà présente depuis ES-1.1).
- `dart run melos run verify` (repo-wide, foreground) → **RC=0**, tous les gates verts (`graph_proof`, `gate_melos_divergence`, `gate_reflectable`, `gate_secret_scan`, `gate_codegen`, `gate_compat_resolution`, `verify_serialization`).

### Completion Notes List

- **D1 (frontière de pureté)** — `ZColorPalette`/`zFnv1a32` (kernel, `z_color_palette.dart`) ne portent que des `colorKey` `String` ; zéro `Color`/`IconData`, zéro import `dart:ui`/`package:flutter`. Le seam de résolution `colorKey → Color` a été ajouté dans `zcrud_core` : `typedef ZColorKeyResolver` + `zDefaultColorKeyResolver(ColorScheme, String)` (repli **dérivé** du `ColorScheme` courant — `primary`/`secondary`/`tertiary`/`error`/`*Container`/`surfaceContainerHighest` — aucun littéral hex) + champ nullable additif `ZcrudScope.colorKeyResolver`, calqué mot pour mot sur `iconResolver`/`ZAdornmentIconResolver`, avec sa ligne dans `updateShouldNotify`. `zcrud_core` ne dépend PAS du kernel (AD-1 respecté : aucune arête retour).
- **D2 (hash déterministe)** — `zFnv1a32` implémenté en pur-Dart avec la multiplication **décomposée 16/16 bits** (JS-safe), validé par les 3 vecteurs publiés (`''→0x811C9DC5`, `'a'→0xE40C292C`, `'foobar'→0xBF9CF968`). Aucune dépendance `crypto` ajoutée ; `String.hashCode` non utilisé. `ZKeyHash` injectable (typedef) pour échappatoire SHA-256 côté app (AD-4). Garde-fou palette vide → `resolveKey` retombe sur `fallbackKey` sans modulo (pas d'`IntegerDivisionByZeroException`) ; le constructeur principal (non-const) porte des `assert` debug (`keys.isNotEmpty` + `keys.contains(fallbackKey)`) — `ZColorPalette.defaultStudy()` reste `const` (asserts distincts, pas de contrainte de constante compilée sur `.contains`).
- **D3 (narrowing du réexport, solde LOW-1 d'ES-1.1)** — le barrel `zcrud_flashcard` réexporte désormais le kernel via `export ... hide ZColorPalette, ZKeyHash, zFnv1a32, ZUnorderedPlacement, applyOrder, normalizeTagTitle, dedupeByNormalizedTitle;` (liste `hide`, jamais `show`) — liste croisée avec le barrel kernel réel après T4. Surface historique E9 préservée intégralement, **symboles générés inclus** (`registerZStudyFolder`, `registerZStudySessionConfig`), prouvé par `test/z_public_surface_test.dart` (test de surface positive — échoue à la compilation si un symbole historique est mordu). Commentaires de règle de maintenance mis à jour dans les DEUX barrels (kernel + flashcard) : tout nouveau symbole kernel hors périmètre flashcard doit être ajouté à ce `hide`.
- **Déviation mineure vs le squelette T1 de la story** : le constructeur principal `ZColorPalette(...)` n'est **pas** `const` (contrairement à la formulation générale « const-constructible » du texte introductif de T1) — nécessaire pour porter l'`assert(keys.contains(fallbackKey))` (non évaluable en expression constante). Seul `ZColorPalette.defaultStudy()` est `const`, ce qui satisfait l'AC1 explicite (« avec un jeu par défaut `const ZColorPalette.defaultStudy()` »). Aucun impact sur les ACs : tous les tests utilisent soit le const `.defaultStudy()`, soit le constructeur nommé non-const pour les palettes personnalisées.
- **Oracles de non-régression** : `zcrud_flashcard` = 166 tests (≥ 165 baseline) ; `zcrud_study_kernel` = 79 tests (≥ 38 baseline) ; `z_kernel_resolution_test.dart` toujours vert **sans modification** (fermeture `{zcrud_core, zcrud_annotations}` inchangée — aucune dépendance runtime ajoutée au `pubspec.yaml` du kernel) ; `zcrud_core` = 890 tests, tous verts (ajout non-cassant confirmé).
- Aucune écriture dans `sprint-status.yaml` (réservé à l'orchestrateur, conforme à la consigne CLAUDE.md).

### File List

**Nouveaux fichiers**
- `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart`
- `packages/zcrud_study_kernel/lib/src/domain/apply_order.dart`
- `packages/zcrud_study_kernel/lib/src/domain/normalize_tag_title.dart`
- `packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart`
- `packages/zcrud_study_kernel/test/z_color_palette_test.dart`
- `packages/zcrud_study_kernel/test/apply_order_test.dart`
- `packages/zcrud_study_kernel/test/normalize_tag_title_test.dart`
- `packages/zcrud_core/test/presentation/z_color_key_resolver_test.dart`
- `packages/zcrud_flashcard/test/z_public_surface_test.dart`

**Fichiers modifiés**
- `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (3 nouveaux `export` + dartdoc ES-1.2 + règle de maintenance D3)
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (import, champ `colorKeyResolver`, paramètre constructeur, `updateShouldNotify`)
- `packages/zcrud_core/lib/zcrud_core.dart` (export `z_color_key_resolver.dart`, ordre alphabétique)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (réexport kernel : bloc → `hide` ciblé + commentaire de règle de maintenance définitif)
