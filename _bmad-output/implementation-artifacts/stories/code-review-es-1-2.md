# Code Review — Story ES-1.2 : Utilitaires domaine purs (`ZColorPalette`, `applyOrder<T>`, `normalizeTagTitle`)

- **Mode** : skill `bmad-code-review` **réellement invoqué** via le tool `Skill` (pas de fallback disque).
- **Date** : 2026-07-13
- **Reviewer** : revue adversariale (lecture du code réel sur disque + vérification empirique).
- **Périmètre** : diff ES-1.2 — 4 nouveaux fichiers de production, 5 nouveaux fichiers de test, 4 barrels/fichiers modifiés.
- **Verdict** : ⚠️ **CHANGES REQUESTED** — **0 HIGH/MAJEUR**, **4 MEDIUM**, **4 LOW**.

> **Synthèse.** L'implémentation est **fonctionnellement saine** : les trois utilitaires sont purs, corrects et bien testés ; la liste `hide` est **exactement exhaustive** ; la pureté du kernel est structurellement garantie. **Aucun défaut de correction n'a été trouvé** — y compris sur l'axe le plus suspecté (le hash web), que j'ai **prouvé correct par compilation dart2js réelle**. Les 4 MEDIUM portent sur des **filets de sécurité manquants** et une **complétude de seam** : (1) la suite de tests n'a **aucun pouvoir** de détecter la régression que la décomposition FNV existe pour prévenir ; (2) le seam couleur est un **jumeau incomplet** d'`iconResolver` (la chaîne de repli documentée n'a **aucun appelant**) ; (3) la liste des 8 clés par défaut est **dupliquée** entre deux packages qui ne peuvent pas se référencer, sans test de cohérence ; (4) le mapping sémantique par défaut mélange les niveaux d'emphase M3 et n'expose **aucune couleur `on-*`** (risque de contraste, AD-13).

---

## Axe 1 (PRIORITAIRE) — Déterminisme web de `zFnv1a32` : **VÉRIFIÉ EMPIRIQUEMENT, PAS SEULEMENT RAISONNÉ**

L'orchestrateur a identifié un angle mort réel : les vecteurs golden tournent sous `dart test` = **VM uniquement**, donc ils ne prouvent pas la propriété web qu'ils sont censés garantir. **Je n'ai pas raisonné de mémoire : j'ai compilé l'implémentation en JS (`dart compile js -O2`) et je l'ai exécutée sous Node**, en la comparant à la variante naïve.

### Résultat de la sonde (VM vs dart2js/Node)

| Entrée | Impl. **décomposée** (ES-1.2) — VM | Impl. **décomposée** — **dart2js** | Impl. **naïve** — VM | Impl. **naïve** — **dart2js** |
|---|---|---|---|---|
| `''` | `0x811C9DC5` | ✅ `0x811C9DC5` | `0x811C9DC5` | `0x811C9DC5` |
| `'a'` | `0xE40C292C` | ✅ `0xE40C292C` | `0xE40C292C` | ❌ **`0xE40C2930`** |
| `'foobar'` | `0xBF9CF968` | ✅ `0xBF9CF968` | `0xBF9CF968` | ❌ **`0x06610426`** |
| `'legacyRed'` | `0xFC7A0555` | ✅ `0xFC7A0555` | `0xFC7A0555` | ❌ `0xBFA9860C` |
| `'course-de-droit'` | `0x642F0703` | ✅ `0x642F0703` | `0x642F0703` | ❌ `0x3FDB7040` |

Sondes de sémantique dart2js : `0xFFFF << 16` → **`4294901760`** (positif, **non signé**) ; `1099521261165 & 0xFFFFFFFF` → **`9633389`** (identique VM et JS).

### Réponses aux sous-questions

- **(a) La décomposition est-elle mathématiquement correcte mod 2^32 ?** ✅ **Oui.** Avec `h = hi·2^16 + lo`, on a `h·P mod 2^32 = (lo·P + ((hi·P) mod 2^16)·2^16) mod 2^32` — exactement ce qu'écrit le code. Magnitudes : `lo ≤ 0xFFFF × 16777619 ≈ 1,0995e12` et `hi<<16 ≤ 4,295e9`, somme `≈ 1,0995e12 < 2^53` → **exactement représentable en double**, aucune perte de précision.
- **(b) Sémantique de `<<` en dart2js (signé → négatif ?)** ✅ **Non signé.** dart2js compile `int << int` en `(a << b) >>> 0` : le `>>> 0` final reconvertit en **entier non signé 32 bits**. Mesuré : `0xFFFF << 16 == 4294901760` (et non `-65536`). **`lo + (hi << 16)` ne casse pas.**
- **(c) Sémantique du masque `& 0xFFFFFFFF` sur ~1,1e12 (> 2^32) ?** ✅ **Correcte.** JS applique `ToInt32` (modulo 2^32) aux deux opérandes puis dart2js applique `>>> 0` → le résultat est **exactement `x mod 2^32`**. Mesuré identique sur VM et Node (`9633389`).
- **(d) Peut-on PROUVER la propriété ?** ✅ **Oui, et c'est quasi gratuit.** J'ai lancé `dart test -p node` sur le kernel : **17 tests sur 18 passent, vecteurs FNV inclus**. Le **seul** échec est le garde SM-S5 anti-`Color`, qui utilise `dart:io` (indisponible hors VM). Il suffit donc d'**isoler ce garde** (`@TestOn('vm')` ou fichier dédié) pour que toute la suite kernel devienne **exécutable sur plateforme JS**, transformant la propriété web de « commentaire » en « test ».

### Conclusion de l'axe 1

> **L'implémentation n'est PAS défectueuse — elle est PROUVÉE correcte sur VM et sur dart2js.** La décomposition 16/16 n'est **pas** du zèle : la variante naïve **passe les 3 vecteurs golden sur la VM** tout en **divergeant sur le web** (`'a'` → `0xE40C2930` au lieu de `0xE40C292C`). C'est exactement le scénario que la dartdoc interdit (« NE PAS simplifier »).
>
> **Le vrai défaut est donc dans le FILET, pas dans le code** : la suite de tests actuelle a un **pouvoir de détection nul** face à cette régression précise. Un futur agent « simplificateur » qui remplace la décomposition par `hash = (hash * 0x01000193) & 0xFFFFFFFF` verrait **100 % des tests rester verts** et casserait silencieusement le web. Le garde-fou est un **commentaire**, pas un test.
>
> **Sévérité : MEDIUM** (→ finding **M1**), et non HIGH — conformément à l'analyse d'impact de l'orchestrateur : une divergence VM/web ne choisirait qu'un **slot d'affichage** différent pour une `colorKey` **inconnue** ; la clé brute reste persistée telle quelle. L'impact serait **cosmétique**, jamais une corruption de données. La correction est **cheap et déjà validée** (cf. M1).

---

## Findings HIGH / MAJEUR

**Aucun.** Aucun défaut de correction, aucune violation d'AD bloquante, aucun chemin de crash, aucune régression de surface publique.

---

## Findings MEDIUM

### M1 — Le filet de test ne prouve pas la propriété web de `zFnv1a32` (le seul motif d'existence de la décomposition 16/16)

- **Fichiers** : `packages/zcrud_study_kernel/test/z_color_palette_test.dart:37-63` ; `melos.yaml:34-36` (`test:dart` → `dart test`, VM uniquement).
- **Description** : les 3 vecteurs golden ne s'exécutent que sur la VM, où **une multiplication naïve passerait aussi** (prouvé ci-dessus). La suite ne peut donc pas détecter la régression que la dartdoc de `z_color_palette.dart:39-42` interdit explicitement. Le garde est narratif, pas outillé — alors que le reste du repo privilégie les gardes **outillés** (`gate_reflectable.dart`, `z_kernel_resolution_test.dart`).
- **Impact AD** : **AC2** (« stable cross-plateforme, y compris web/dart2js ») est **affirmé mais non vérifié** ; NFR-S10/SM-S7 (déterminisme cross-device). Pas d'impact données (remap cosmétique).
- **Recommandation** (validée empiriquement, ~15 min) :
  1. Sortir le test SM-S5 (qui utilise `dart:io`) dans `test/z_kernel_purity_test.dart` annoté `@TestOn('vm')` — c'est **l'unique blocage** : sans lui, `dart test -p node` passe déjà 17/17.
  2. Ajouter la plateforme JS à la suite kernel : `dart test -p vm -p node` (ou `-p chrome`), câblé dans `melos.yaml` (`test:dart` ou un script `test:web` dédié) et dans `verify`.
  3. Optionnel : commentaire de renvoi vers ce rapport dans la dartdoc de `zFnv1a32`.

### M2 — Le seam couleur est un jumeau **incomplet** d'`iconResolver` : la chaîne de repli documentée n'a **aucun appelant**

- **Fichiers** : `packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart:23,35` ; `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:146`.
- **Description** : le précédent icône expose **trois** pièces — le `typedef`, la table par défaut **privée** (`_defaultIconTable`), et surtout **la fonction de chaîne publique** :
  ```dart
  // z_field_adornment_view.dart:74-75
  IconData? zResolveAdornmentIcon(BuildContext context, String key) =>
      ZcrudScope.maybeOf(context)?.iconResolver?.call(key) ?? _defaultIconTable[key];
  ```
  Le jumeau couleur n'a **que** le `typedef` et un défaut **public** — **il manque la fonction de chaîne**. `grep` confirme : `zDefaultColorKeyResolver` a **zéro appelant** dans tout `packages/` (hors sa définition et son test). Pourtant la dartdoc affirme deux fois « le cœur **retombe sur** `zDefaultColorKeyResolver` » (`zcrud_scope.dart:146`, `z_color_key_resolver.dart:23`) : **rien n'implémente ce repli**. Pire, les signatures **ne composent pas** : `ZColorKeyResolver = Color? Function(String)` ne porte pas de `ColorScheme`, alors que le défaut en exige un → un consommateur **ne peut pas** écrire la chaîne de façon uniforme.
- **Impact AD** : **FR-S2** (l'objectif même de la story : supprimer la duplication) — chaque consommateur ES-5/ES-8 devra **réécrire à la main** `scope?.colorKeyResolver?.call(k) ?? zDefaultColorKeyResolver(Theme.of(context).colorScheme, k)`, soit exactement la duplication que FR-S2 élimine. **AC3** n'est satisfait que **documentairement** sur ce point. Encapsulation **inversée** vs le précédent (défaut public, chaîne absente).
- **Recommandation** : ajouter dans `z_color_key_resolver.dart` le point d'entrée unique, strict miroir du précédent :
  ```dart
  Color? zResolveColorKey(BuildContext context, String colorKey) =>
      ZcrudScope.maybeOf(context)?.colorKeyResolver?.call(colorKey) ??
      zDefaultColorKeyResolver(Theme.of(context).colorScheme, colorKey);
  ```
  + un test de la chaîne (injecté prioritaire → défaut → `null`). Aligner la dartdoc sur le comportement réel.

### M3 — Les 8 clés par défaut sont **dupliquées** entre `zcrud_study_kernel` et `zcrud_core`, sans test de cohérence possible (et 4 clés sur 8 non testées)

- **Fichiers** : `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart:88-100` (liste des 8 clés) ; `packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart:36-55` (switch sur les 8 mêmes clés) ; `packages/zcrud_core/test/presentation/z_color_key_resolver_test.dart:27-33`.
- **Description** : la liste canonique existe **en deux exemplaires**, dans deux packages qui **ne peuvent structurellement pas se référencer** (AD-1 interdit `zcrud_core → kernel`). Le couplage est donc **purement conventionnel**, et **aucun test ne peut l'assurer** dans le graphe actuel. Si ES-1.3/ES-2 ajoute une clé à `defaultStudy()`, `zDefaultColorKeyResolver` renverra **silencieusement `null`** pour elle. Aggravant : le test du cœur ne couvre que `primary`/`secondary`/`tertiary`/`danger` — **`success`, `warning`, `info`, `neutral` (4/8) ne sont jamais assertés non-`null`**.
- **Impact AD** : AD-1 (le couplage ne peut pas être testé sans créer une arête interdite) ; AD-10 (dégradation silencieuse) ; FR-S2.
- **Recommandation** : rendre le couplage **structurel** plutôt que conventionnel — `zcrud_core` est le **seul package que les deux voient**. Déclarer la liste canonique dans la surface **pur-Dart** de `zcrud_core` (ce ne sont que des `String`, aucune fuite Flutter) :
  ```dart
  // zcrud_core (domain, pur-Dart)
  const List<String> zDefaultColorKeys = ['primary', 'secondary', ..., 'neutral'];
  ```
  puis `ZColorPalette.defaultStudy()` la réutilise (kernel → core est **légal**) et le switch du cœur l'itère. Source unique de vérité, et le test « toute clé de `zDefaultColorKeys` résout non-`null` » devient **écrivable dans `zcrud_core`**. À défaut : au minimum ajouter le test des 4 clés manquantes + un renvoi croisé explicite dans les deux fichiers.

### M4 — Le mapping sémantique par défaut mélange les niveaux d'emphase M3 et n'expose aucune couleur `on-*` → contraste non garanti (AD-13)

- **Fichier** : `packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart:36-55`.
- **Description** : le switch mélange **deux catégories de rôles Material 3** incompatibles en usage :
  - rôles **principaux** (saturés, conçus pour porter un texte `onX`) : `primary`→`scheme.primary`, `secondary`→`scheme.secondary`, `tertiary`→`scheme.tertiary`, `danger`→`scheme.error` ;
  - rôles **Container** (pâles, conçus comme **fonds**) : `success`→`tertiaryContainer`, `warning`→`secondaryContainer`, `info`→`primaryContainer` ; plus `neutral`→`surfaceContainerHighest` (rôle **surface**).

  Conséquence : **aucun usage unique n'est cohérent**. En fond de puce de tag, 4 clés donnent un fond **saturé** (texte clair requis) et 4 un fond **pâle** (texte foncé requis). En avant-plan, `warning` (`secondaryContainer`) est **quasi invisible** sur une surface. Et **aucun companion `onColor` n'est exposé** → le consommateur ne peut **pas** calculer un premier plan lisible. Enfin, M3 n'ayant **pas** de rôle `success`/`warning`, ces clés ne rendront **jamais** vert/ambre sous un seed quelconque : la sémantique de la clé est **trompeuse**.
- **Impact AD** : **AD-13** (a11y — contraste non garanti) ; NFR-S7/FR-26 (la contrainte « zéro couleur en dur » est respectée à la lettre, mais l'esprit — un défaut *utilisable* — ne l'est pas) ; fige de fait un design system par accident.
- **Recommandation** (au choix, non bloquant pour la story mais à trancher avant ES-8) :
  1. **Restreindre** les clés par défaut à celles que le `ColorScheme` exprime réellement (`primary`/`secondary`/`tertiary`/`danger`/`neutral`), et laisser `success`/`warning`/`info` à l'injection hôte ; **ou**
  2. **Homogénéiser** l'emphase (tout en `*Container`, usage « fond » assumé) **et** exposer le companion `Color? zDefaultOnColorKeyResolver(ColorScheme, String)` (→ `onPrimaryContainer`, …) pour garantir le contraste ;
  3. dans tous les cas, **documenter explicitement** que `success`/`warning`/`info` sont des **approximations** et que l'hôte **DOIT** injecter un resolver pour une sémantique correcte.

---

## Findings LOW

### L1 — `resolveKey` : ordre des gardes trompeur, et violation possible de l'invariant AC2 en **release**

- **Fichier** : `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart:123-137`.
- **Analyse de l'ordre des gardes (question de l'orchestrateur)** : ✅ **l'ordre est fonctionnellement correct.** `keys.contains(raw)` sur une liste vide renvoie `false` (pas de throw), puis `if (keys.isEmpty) return fallbackKey;` court-circuite **avant** le modulo → **aucune `IntegerDivisionByZeroException`**. C'est simplement **trompeur à la lecture** (un `contains` inutile sur une liste vide).
- **Défaut réel** : si `keys` est **non vide** mais que `fallbackKey ∉ keys` (erreur de programmation), l'`assert` du constructeur (`z_color_palette.dart:81-84`) **est retiré en release** → `resolveKey(null)` renvoie une clé **hors de `keys`**, violant l'invariant AC2 (« le résultat appartient **toujours** à `palette.keys` »), et `indexOf` renvoie **`-1`** → un consommateur UI faisant `colors[palette.indexOf(raw)]` lèverait un **`RangeError`** (contraire à l'esprit AD-10).
- **Recommandation** : hisser `if (keys.isEmpty) return fallbackKey;` **en tête**, et rendre le repli défensif en release : `return keys.contains(fallbackKey) ? fallbackKey : keys.first;`.

### L2 — `keys` exposée **mutable** alors que la classe se déclare « Immuable » avec `==`/`hashCode` structurels

- **Fichier** : `packages/zcrud_study_kernel/lib/src/domain/z_color_palette.dart:76-84,103`.
- **Description** : le constructeur non-const accepte n'importe quelle `List<String>` (y compris *growable*) et la stocke telle quelle. `palette.keys.add('x')` **mute la palette** après construction, invalide l'invariant validé par l'`assert` et **casse le contrat `hashCode`** si la palette sert un jour de clé de `Map`/`Set`. Le `const defaultStudy()` n'est pas concerné (liste `const`, immuable).
- **Atténuation** : `grep` confirme qu'**aucune** convention `List.unmodifiable`/`UnmodifiableListView` n'existe ailleurs dans `zcrud_core`/`zcrud_flashcard`/`zcrud_study_kernel` → le code est **cohérent avec l'existant**, d'où LOW et non MEDIUM.
- **Recommandation** : `keys = List.unmodifiable(keys)` dans le constructeur non-const (coût nul, aucun risque).

### L3 — Le garde SM-S5 anti-`Color` : portée partielle, redondant, et **bloque la plateforme JS**

- **Fichier** : `packages/zcrud_study_kernel/test/z_color_palette_test.dart:184-200` ; `melos.yaml:74-82` (script `verify`).
- **Réponse à la question « l'ajustement anti-commentaires affaiblit-il le garde ? »** : ✅ **Non.** Le filtre `!line.trimLeft().startsWith('//')` retire les lignes `//` **et** `///` (une dartdoc commence bien par `//`), mais **ne peut pas masquer un vrai `Color(` en code** : une ligne de code contenant `Color(` ne commence pas par `//`. Le garde reste donc **efficace** dans le sens qui compte (faux négatif impossible sur du code) ; il tolère seulement les mentions en commentaire (faux positif éliminé). Ajustement **légitime**.
- **Défauts résiduels** : (a) il ne scanne **qu'un seul fichier** (`z_color_palette.dart`) sur les 3 nouveaux ; (b) il est **redondant** avec une garantie bien plus forte — le `pubspec.yaml` du kernel (`packages/zcrud_study_kernel/pubspec.yaml:31-33`) ne dépend **pas** de Flutter, donc `package:flutter`/`dart:ui` sont **littéralement inimportables** (échec d'`analyze`), ce qui rend `Color`/`IconData` impossibles par construction ; (c) il utilise **`dart:io`**, ce qui **empêche la suite kernel de tourner sur plateforme JS** (→ **cause racine du blocage de M1**) ; (d) SM-S5 parle d'un « **scan CI** », or `melos verify` n'a **aucun** gate de ce type (gates présents : `graph_proof`, `melos_divergence`, `reflectable`, `secret_scan`, `codegen`, `compat_resolution`, `verify_serialization`).
- **Recommandation** : déplacer ce test dans `test/z_kernel_purity_test.dart` avec `@TestOn('vm')` (débloque M1) et, à terme, promouvoir le scan en **gate CI repo-wide** sur `packages/zcrud_study*` (sur le modèle de `scripts/ci/gate_reflectable.dart`).

### L4 — La règle de maintenance du `hide` est **une convention non outillée** : insuffisante pour ES-1.3/ES-2

- **Fichiers** : `packages/zcrud_flashcard/lib/zcrud_flashcard.dart:48-60` ; `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart:35-42` ; `packages/zcrud_flashcard/test/z_public_surface_test.dart`.
- **Description** : la règle (« tout nouveau symbole kernel hors périmètre flashcard **DOIT** être ajouté au `hide` ») n'est qu'un **commentaire**. Le test de surface `z_public_surface_test.dart` est **positif uniquement** : il prouve que les symboles historiques sont **présents**, mais il est **structurellement incapable de détecter une fuite**. Si ES-1.3 ajoute `ZSyncMeta` au barrel kernel et oublie le `hide`, **rien ne casse** — le symbole fuite silencieusement dans la surface publique de `zcrud_flashcard`, exactement le défaut que D3 était censé clore (LOW-1 d'ES-1.1).
- **Recommandation** : ajouter un **garde négatif outillé** (même technique de lecture de fichier que le test SM-S5, déjà éprouvée dans ce repo) : parser les deux barrels et asserter que **tout symbole public exporté par le barrel kernel** est soit dans la liste `hide` de `zcrud_flashcard`, soit sur une **allowlist explicite** de symboles « pertinents flashcard » (les 6 d'ES-1.1 + les générés). Une nouvelle entrée non classée fait **échouer le test**, forçant la décision. Coût : ~30 lignes.

---

## Points vérifiés et **non défectueux** (levée d'alertes de la demande de revue)

| Point suspecté | Verdict |
|---|---|
| **Correction de `zFnv1a32` sur web** | ✅ **Prouvé correct** (dart2js + Node) — décomposition mathématiquement exacte mod 2^32, `<<` non signé, masque correct. **Le code n'est pas en cause** (seul le filet l'est → M1). |
| **Exhaustivité de la liste `hide` (D3, solde LOW-1)** | ✅ **Exactement exhaustive.** Symboles publics ES-1.2 du barrel kernel = `ZColorPalette`, `ZKeyHash`, `zFnv1a32`, `ZUnorderedPlacement`, `applyOrder`, `normalizeTagTitle`, `dedupeByNormalizedTitle` (**7**) ; liste `hide` = **les mêmes 7**, ni plus ni moins. `_Indexed` est privé (non exporté). **Aucun symbole historique E9 masqué** ; les symboles **générés** (`registerZStudyFolder`, `registerZStudySessionConfig`, field-specs) restent exportés — jamais énumérés, donc jamais oubliés : l'objection de LOW-1 tombe. **LOW-1 est bien soldé.** (Sa pérennité, elle, reste non outillée → L4.) |
| **Pureté du kernel (D1/SM-S5/AD-17)** | ✅ **Aucun** import Flutter/`dart:ui` dans tout `packages/zcrud_study_kernel/lib/` ; aucun `Color`/`IconData`/littéral hex. Fermeture transitive **inchangée** : `pubspec.yaml` → `{zcrud_core, zcrud_annotations}` seulement, **aucune dépendance runtime ajoutée** (pas de `crypto` — D2 tenu). Pureté **structurellement garantie** par le pubspec (cf. L3). |
| **Garde anti-`Color` affaibli par le filtre commentaires ?** | ✅ **Non** — faux négatif impossible sur du code (cf. L3). |
| **`ZcrudScope.colorKeyResolver` : câblage** | ✅ Champ nullable additif, paramètre de constructeur, **ligne présente dans `updateShouldNotify`** (`zcrud_scope.dart:189`), testée. Ajout **non-cassant** (890 tests `zcrud_core` verts). Seule la **chaîne de repli** manque → M2. |
| **Absence de littéral hex dans le repli** | ✅ **Confirmé** — `zDefaultColorKeyResolver` ne contient **aucun** `0x…`/`Colors.*` (la seule occurrence de `0x…` est dans la **dartdoc** qui interdit la pratique). Le test light≠dark prouve la dérivation réelle du `ColorScheme`. |
| **`applyOrder<T>` : stabilité / pureté / complexité** | ✅ Tri **réellement stable** — la clé secondaire `entryIndex` départage les ex-aequo, donc la stabilité **ne dépend pas** de celle (non garantie) de `List.sort`. **Non-mutant** (`items.toList(growable: false)`, `order` en lecture seule). Complexité **O(n + k·log k)** : la `Map` de positions évite tout `indexOf` dans le comparateur → **aucun O(n²) caché**. Cas dégradés tous couverts et testés. |
| **`normalizeTagTitle` / `dedupeByNormalizedTitle`** | ✅ Conformes. `\s` en Dart couvre bien **NBSP (U+00A0)** — testé explicitement. Pures, totales, locale-indépendantes ; dédoublonnage stable, 1re occurrence conservée. |
| **`==`/`hashCode` incluant le champ **fonction** `hash`** | ✅ **Sain.** Le tear-off d'une fonction top-level est **canonicalisé** en Dart → `defaultStudy() == defaultStudy()` est vrai (testé). C'est de surcroît **sémantiquement correct** : un hash différent = un remap différent = une palette différente. Seul effet de bord (bénin) : deux palettes construites avec des **closures inline** identiques ne seront jamais `==`. `hashCode` n'est jamais persisté. **Aucune action.** |
| **Garde palette vide (`% keys.length`)** | ✅ **Pas de division par zéro** (cf. L1 pour la nuance sur `fallbackKey ∉ keys`). |

---

## Complétude des 7 ACs (satisfaction par le **CODE**, pas par les commandes vertes)

| AC | Statut | Justification |
|---|---|---|
| **AC1** — `ZColorPalette`, zéro couleur, fermeture inchangée | ✅ **Satisfait** | Palette injectable + `const defaultStudy()` ; zéro import Flutter (vérifié sur tout `lib/`) ; `pubspec.yaml` inchangé côté `dependencies` → `z_kernel_resolution_test.dart` reste vert sans modification. |
| **AC2** — Remap déterministe, jamais de crash | ✅ **Satisfait** (⚠️ L1 en release) | Clé connue → identité ; `null`/`''` → fallback ; inconnue → clé ∈ `keys` ; vecteurs FNV **prouvés VM *et* dart2js** ; `ZKeyHash` injectable ; `String.hashCode` non utilisé. Réserve : `fallbackKey ∉ keys` en release (L1). Le déterminisme web est **vrai** mais **non gardé par un test** (M1). |
| **AC3** — Résolution injectée via `ZcrudScope` | ⚠️ **Partiel** | `typedef` ✅, champ nullable ✅, `updateShouldNotify` ✅, dérivation `ColorScheme` sans hex ✅, clé inconnue → `null` ✅, non-cassant ✅. **Mais** « le cœur **retombe sur** `zDefaultColorKeyResolver` » est **documenté et non implémenté** (0 appelant) → **M2**. Et 4 des 8 clés ne sont jamais testées → **M3**. |
| **AC4** — `applyOrder<T>` stable et déterministe | ✅ **Satisfait** | Stabilité par clé composite (indépendante du SDK), pureté, généricité, tous les cas dégradés testés. |
| **AC5** — `normalizeTagTitle` + dédoublonnage | ✅ **Satisfait** | Collapse `\s+` (NBSP inclus, testé), `toLowerCase`, totalité ; dédoublonnage stable 1re-occurrence testé. |
| **AC6** — Narrowing `hide` sans régression | ✅ **Satisfait** | Liste `hide` **exactement** les 7 symboles ES-1.2 ; surface E9 intacte (générés inclus), prouvée par `z_public_surface_test.dart` ; règle de maintenance présente dans **les deux** barrels ; 166 tests ≥ 165 baseline. Réserve de **pérennité** : règle non outillée → **L4**. |
| **AC7** — Vérif verte repo-wide | ✅ **Satisfait** | `analyze` repo-wide SUCCESS ; `melos verify` RC=0 ; `graph_proof` ACYCLIQUE / CORE OUT=0 (aucune arête ajoutée — `zcrud_core` **ne dépend pas** du kernel) ; kernel toujours sous `dart test` ; aucune écriture dev dans `sprint-status.yaml`. |

---

## Disposition recommandée à l'orchestrateur

Conformément à la politique CLAUDE.md (« **MEDIUM** : correction **par défaut** si possible dans le périmètre de la story sans régression ») :

| Finding | Disposition recommandée | Coût |
|---|---|---|
| **M1** (filet web `zFnv1a32`) | ✅ **Corriger dans ES-1.2** — c'est la contre-mesure directe de l'angle mort ; la voie est **déjà validée empiriquement** (`-p node` passe 17/17 une fois le test `dart:io` isolé). Corrige **L3(c)** au passage. | ~15-30 min |
| **M2** (chaîne `zResolveColorKey`) | ✅ **Corriger dans ES-1.2** — ~6 lignes + 1 test ; sans elle, AC3 n'est satisfait que sur le papier et ES-5/ES-8 dupliqueront la chaîne (anti-FR-S2). | ~20 min |
| **M3** (clés dupliquées core/kernel) | ✅ **Corriger dans ES-1.2** au moins partiellement (tester les 4 clés manquantes + renvoi croisé). La **source unique** dans `zcrud_core` est la vraie correction : à arbitrer (touche le kernel **et** le cœur, mais la story est déjà SÉQUENTIELLE sur ces deux packages → **pas de risque de concurrence**). | 20 min → 1 h |
| **M4** (mapping sémantique / `on-*`) | 🟡 **Reporter à ES-8 avec justification écrite** — c'est une **décision de design** (quelles clés par défaut, quel usage fond/avant-plan) qui appelle le premier consommateur UI réel. **Mais consigner la réserve a11y (AD-13) dès maintenant** dans la dartdoc pour ne pas la perdre. |
| **L1, L2** | 🟡 Correction triviale recommandée (quelques lignes, zéro risque). |
| **L3** (gate CI SM-S5) | 🟡 Partie (c) traitée par M1 ; le **gate CI repo-wide** est un chantier `scripts/ci/` → reporter (backlog E1/CI). |
| **L4** (garde négatif du `hide`) | 🟡 Reporter à **ES-1.3** (première story qui ajoutera un symbole kernel → moment naturel pour outiller la règle), ou traiter ici si le budget le permet. |

**Une fois M1, M2, M3 corrigés et la vérif verte rejouée (`melos run generate` + `analyze` + `verify` repo-wide + `dart test -p vm -p node` kernel + `flutter test` core/flashcard), la story peut passer `done`.**

---

## Disposition orchestrateur (2026-07-12)

Verdict initial de la revue : **CHANGES REQUESTED** (0 HIGH · 4 MEDIUM · 4 LOW). **Remédiation appliquée** (agent Opus), puis **vérif verte rejouée sur disque par l'orchestrateur** (indépendamment de l'agent).

### Traitement des findings

- **M1 + L3 — filet de test aveugle au web → CORRIGÉ.** Cause racine : `dart:io` dans le garde SM-S5 rendait toute la suite kernel non compilable en JS. Gardes VM-only isolés (`@TestOn('vm')` : `z_kernel_purity_test.dart`, `z_kernel_resolution_test.dart`) ; garde de pureté **rendu exhaustif** (scan de tout `lib/**` du kernel). Nouveau gate **`melos run test:js`** (`scripts/ci/gate_web_determinism.dart` → `dart test -p node`), **enchaîné dans `melos run verify`**, avec dégradation propre et **bruyante** si Node est absent (RC=0 + bannière SKIP : un échec d'environnement n'est pas un échec de code). Avertissement fort ajouté au-dessus de `zFnv1a32`.
  **Preuve que le filet mord** (variante naïve injectée temporairement, puis restaurée) : VM = `+90 All tests passed` (**totalement aveugle**) ; node = **ÉCHEC** (`'a'` → 3826002224 au lieu de 3826002220 ; `'foobar'` → 107021350 au lieu de 3214735720).
- **M2 + M3 + M4 — seam couleur re-conçu → CORRIGÉ.** `zResolveColorKey(BuildContext, String)` = jumeau réel de `zResolveAdornmentIcon` (resolver injecté prioritaire → repli `ColorScheme` → `null`, AD-10) + variante totale `zResolveColorKeyOrSlot`. Signatures qui **composent** : `typedef ZColorKeyResolver = ZColorPair? Function(ColorScheme, String)`. **Duplication des 8 clés éliminée structurellement** : `zcrud_core` (puits AD-1) ne connaît plus AUCUNE clé study — son vocabulaire est l'enum `ZColorSlot` (rôles Material 3) ; le pont kernel↔cœur est un **entier** (`ZColorPalette.indexOf` → `zColorSlotPair`), pas une liste de `String` répliquée. **Contraste garanti** (M4/AD-13) : `ZColorPair {color, onColor}` — toute résolution rend une paire fond + `on-` ; le cœur **ne prétend plus** fournir `success`/`warning`/`info`/`danger` (les inventer exigerait une couleur en dur) : ils rendent `null` et relèvent du resolver **injecté par l'app**. Zéro littéral hex / `Colors.*` dans `zcrud_core`.
- **L1 — robustesse release → CORRIGÉ.** `keys.isEmpty` hissé en tête de `resolveKey` ; `ZColorPalette.effectiveFallbackKey` (statique, pure) garantit un élément de `keys` (repli `keys.first` si `fallbackKey ∉ keys`) ; `indexOf` ne peut plus induire un `RangeError`. Aucun nouveau symbole public (donc rien à ajouter au `hide`).
- **L4 — garde négatif → CORRIGÉ.** `z_kernel_surface_guard_test.dart` croise les symboles publics **réels** du barrel kernel avec la liste `hide` **parsée** du barrel flashcard + une allowlist explicite ES-1.1 ; tout symbole non classé ⇒ **échec**. **Preuve que le filet mord** : `normalizeTagTitle` retiré du `hide` ⇒ test ROUGE (« FUITE POTENTIELLE »), puis barrel restauré. **`ZSyncMeta` (ES-1.3) ne pourra plus fuiter en silence** — la règle de maintenance du `hide` est désormais OUTILLÉE, plus conventionnelle.
- **L2 — `keys` exposée mutable → CONSIGNÉ, non corrigé.** Aucune convention `List.unmodifiable` n'existe ailleurs dans le repo ; corriger ici seul créerait une incohérence locale. À traiter globalement si une convention est adoptée.

### Vérif verte finale (rejouée par l'orchestrateur, pas sur la foi de l'agent)

`melos run analyze` repo-wide SUCCESS · kernel VM **90** · **kernel JS (`-p node`) 80 — vecteurs FNV verts en web** · `melos run test:js` **[gate:web] OK** · flashcard **171** (≥166, surface E9 intacte) · core **905** (≥890) · `graph_proof` **ACYCLIQUE OK / CORE OUT=0 OK** · `melos run verify` repo-wide **RC=0** (14 scripts, gate:web inclus).

**Conclusion : story ES-1.2 → `done`.** 0 finding bloquant résiduel ; les 4 MEDIUM et 2 des 4 LOW corrigés et **prouvés par injection de régression** ; L2 consigné avec justification.

### Note de processus (RETEX)

ES-1.2 a été la seule story développée en **Sonnet** (politique « tiered »). Les 4 MEDIUM proviennent tous du fait que **la story elle-même** portait le défaut de conception (signature de seam qui ne compose pas ; vecteurs golden sans exécution web) — Sonnet l'a implémentée **fidèlement, failles comprises**. Coût réel : **deux passes de dev au lieu d'une**. → **Politique révisée : tout-Opus pour le cycle BMAD** (cf. `docs/study-integration-inventory.md` §0, décision 5). Sonnet reste réservé à l'exploration read-only hors BMAD.
