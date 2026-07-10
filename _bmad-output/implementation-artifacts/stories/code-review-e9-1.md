# Code Review — Story E9-1 : `ZFlashcard` + `ZChoice` + `ZFlashcardType` + provenance registre

- **Package** : `zcrud_flashcard`
- **Mode d'exécution** : skill réel `bmad-code-review` invoqué (step-file architecture ; steps 01→02 suivis). Revue adversariale menée par le reviewer (layers Blind Hunter / Edge Case Hunter / Acceptance Auditor consolidées en un seul passage adversarial, subagents non disponibles dans ce contexte d'exécution).
- **Baseline** : `04aaaf09` (frontmatter story). Périmètre strict : `packages/zcrud_flashcard/**` uniquement.
- **Date** : 2026-07-10

## Vérification rejouée réellement sur disque

| Gate | Commande (dans `packages/zcrud_flashcard`) | Résultat |
|---|---|---|
| generate | `dart run build_runner build --delete-conflicting-outputs` | **RC=0** (`z_flashcard.g.dart` + `z_choice.g.dart` émis ; incrémental : 0 outputs au re-run) |
| analyze | `dart analyze .` | **RC=0** — `No issues found!` |
| test | `flutter test` | **RC=0** — `All tests passed!` **27 tests** |

Isolation confirmée : `git status` ne montre **aucun** fichier `packages/zcrud_core/**` modifié *par cette story*. Les modifs `zcrud_core`/`zcrud_firestore`/`zcrud_mindmap` visibles en `git status` proviennent des workstreams parallèles E5-3/E10 (fichiers disjoints), pas de E9-1.

## Couverture des ACs (Acceptance Auditor)

| AC | Statut | Preuve |
|---|---|---|
| AC1 — 6 types camelCase + repli `openQuestion` | ✅ | `z_flashcard_type.dart` (6 valeurs) ; généré `_$enumFromName(...) ?? openQuestion` ; tests round-trip + `totallyUnknownType`→openQuestion + clé absente. |
| AC2 — `ZChoice` (`is_correct`, défauts) | ✅ | `z_choice.dart` + généré ; test défauts + types corrompus (`content:42`→'', `is_correct:'yes'`→false). |
| AC3 — entité codegen snake_case | ✅ | `@ZcrudModel(kind:'flashcard')`, clés `sub_folder_id`/`is_read_only`/`created_at`/`tag_ids` vérifiées ; round-trip zéro-perte. |
| AC4 — SRS HORS carte | ✅ | Aucun champ SRS déclaré ; test assertant l'absence de 9 clés SRS dans la map. |
| AC5 — éphémère dérivé | ✅ | `extends ZEntity` (isEphemeral = id==null) ; test id null/non-null. |
| AC6 — provenance via registre, `article` jamais codé en dur | ✅ | `ZFlashcardSource` (sealed interne + `ZCustomSource` repli) ; le test **prouve la consultation** du registre via le marqueur `decoded_by_registry` présent uniquement par le codec, absent sans registre ; test `"article"` sans enregistrement → `ZCustomSource` générique. |
| AC7 — slots AD-4 (`extra` + `ZExtension?`) | ✅ | `with ZExtensible` ; `ZExtension.guard` ; test extension round-trip, formatVersion non gérée→null, extra préservé, extra défaut `{}`. |
| AC8 — désérialisation défensive bout-en-bout | ✅ | Tests map vide, choices malformés (non-map ignorés), source kind inconnu/non-map, extension corrompue, tag_ids absent — aucun throw parent. |
| AC9 — isolation + barrel + `ZFlashcardApi.version` | ✅ | Barrel exporte les 4 types ; `version='0.1.0'` ; aucune édition core. |
| AC10 — vérif verte | ✅ | generate/analyze/test verts (voir table). |

**Verdict Acceptance Auditor : 10/10 ACs satisfaits.**

## Findings

### Aucun finding HIGH / MAJEUR / MEDIUM (correctness)

L'implémentation est robuste et rigoureusement défensive. Les canaux hors-codegen (`source`/`extension`/`extra`) sont correctement câblés autour du généré, le `copyWith` manuel couvre bien les 3 canaux (le `copyWith` généré, masqué par la méthode d'instance, les aurait réinitialisés → perte silencieuse **évitée**), et l'ordre de spread `{...extra, ...généré}` garantit que les clés réservées l'emportent sur `extra`. `_reservedKeys` est dérivé de `$ZFlashcardFieldSpecs` → reste synchrone avec le codegen. Round-trip `==`/`hashCode` order-independent sur `extra`. Aucun chemin de désérialisation ne peut faire throw le parent.

### LOW-1 — Pureté AD-14 : le domaine flashcard tire Flutter au transitif (POINT À TRANCHER)

- **Fichiers** : `lib/src/domain/z_flashcard.dart:36`, `lib/src/domain/z_flashcard_source.dart:24` (`import 'package:zcrud_core/zcrud_core.dart';`).
- **Constat factuel vérifié** : `edition.dart` (surface pure de `zcrud_core`) exporte bien `ZcrudRegistry`/`ZFieldSpec`/`ZValidatorSpec`/`EditionFieldType` (d'où `z_choice.dart:19` **est** Flutter-free en important `edition.dart`), mais **n'exporte pas** `ZEntity`, `ZExtensible`, `ZExtension`, `ZSourceRegistry`. Ces 4 APIs — pourtant **elles-mêmes pur-Dart** — ne sont exposées que par le barrel principal `zcrud_core.dart`, qui ré-exporte la couche `presentation` (tire `dart:ui`). `z_flashcard.dart`/`z_flashcard_source.dart`, qui en dépendent, doivent donc importer le barrel → le domaine flashcard n'est pas Flutter-free au transitif, et les tests tournent sous `flutter test`. Écart assumé vs. la note « Testing standards » de la story (`edition.dart`, jamais le barrel).
- **Impact** : nul à l'exécution ; smell de portabilité (le domaine ne peut pas tourner sous `dart test` pur). Ne casse **ni** AD-1 (le graphe reste acyclique : flashcard→core est une arête légitime, aucun gestionnaire d'état/Firebase/Syncfusion importé) **ni** aucune fonctionnalité.
- **Verdict argumenté (trade-off acceptable, NON bloquant pour `done`)** : la déviation est **forcée par la contrainte dure de la story** (« NE MODIFIE PAS `zcrud_core` ») combinée à une **lacune de la surface pure du cœur** — les 4 types pur-Dart ne sont pas surfacés sur un point d'entrée Flutter-free. La seule correction in-scope aurait été d'éditer `zcrud_core` (interdit). Le choix retenu **réplique exactement la convention déjà livrée de `zcrud_mindmap`** (E10), donc cohérent avec le prior art du monorepo. Ce n'est donc pas une violation nouvelle imputable à E9-1 mais une **dette d'architecture du cœur**.
- **Recommandation (à router vers l'orchestrateur, hors E9-1)** : ouvrir un follow-up `zcrud_core` pour surfacer `ZEntity`/`ZExtensible`/`ZExtension`/`ZSourceRegistry` (types domaine purs) sur un point d'entrée Flutter-free (soit `edition.dart`, soit un nouveau `contracts.dart`/`domain.dart`), puis rebasculer `z_flashcard.dart`/`z_flashcard_source.dart` **et** `zcrud_mindmap` vers cet import pur + `dart test`. Sévérité **LOW** (architectural, sans impact runtime, forcé par le périmètre, précédent établi).

### LOW-2 — Les variants génériques masquent un codec de registre homonyme

- **Fichier** : `lib/src/domain/z_flashcard_source.dart:64-88` (`switch (kind)`).
- **Constat** : `note`/`conversation`/`document` sont matchés **avant** la consultation du registre (branche `default`). Une app qui enregistrerait un codec pour l'un de ces `kind` verrait son codec **ignoré** silencieusement.
- **Impact** : négligeable (les 3 kinds génériques sont réservés par conception) ; pas de perte de données.
- **Recommandation** : documenter explicitement dans le dartdoc que `note`/`conversation`/`document` sont des `kind` **réservés** non surchargeables par `ZSourceRegistry`. Optionnel.

### LOW-3 (nit) — `extra` stockée mutable alors que `ZCustomSource.payload` est `unmodifiable`

- **Fichiers** : `z_flashcard.dart:300` (`_extraFrom` renvoie une map mutable) vs `z_flashcard_source.dart:193` (`payload` = `Map.unmodifiable`).
- **Impact** : cosmétique / incohérence d'immutabilité ; l'entité `const` peut voir son `extra` muté a posteriori. Sans effet fonctionnel dans le périmètre.
- **Recommandation** : envelopper `extra` en `Map.unmodifiable` dans `_extraFrom` (et éventuellement au constructeur) pour l'homogénéité. Optionnel.

### LOW-4 (informatif, forward-looking E9-4) — La voie `registerZFlashcard.toMap` passe toujours `sourceRegistry: null`

- **Fichier** : `z_flashcard.g.dart` `registerZFlashcard` → `toMap: (value) => value.toMap()` (instance `toMap` sans registre).
- **Constat** : lors d'une (dé)sérialisation pilotée par le `ZcrudRegistry`, le registre de provenance n'est pas transmis → un codec d'app (« article ») est **court-circuité** (le `ZCustomSource` émet son `payload` tel quel). Le round-trip reste **préservé** (aucune perte : le payload est conservé), donc pas de bug ici.
- **Impact** : nul en E9-1 (le câblage du registre au dépôt est explicitement E9-4).
- **Recommandation** : s'assurer en **E9-4** que le dépôt injecte le `ZSourceRegistry` dans le chemin (dé)sérialisation (via un seam dédié plutôt que le `toMap` du `ZcrudRegistry`), afin que les codecs d'app soient effectivement consultés à la persistance. Note de suivi, pas une correction E9-1.

## Conclusion

**Verdict : PRÊT POUR `done`.**

Aucun finding critique/majeur/MEDIUM. Les 10 ACs sont satisfaits, la vérif est verte et rejouée réellement (generate RC=0, analyze RC=0, 27 tests RC=0), l'isolation AD-1 est respectée (zéro édition `zcrud_core` par la story). Les 4 findings sont tous **LOW/nit** : le seul à portée architecturale (LOW-1, pureté AD-14) est un **trade-off acceptable et cohérent** avec le précédent `zcrud_mindmap`, non corrigible in-scope, à traiter par un follow-up `zcrud_core` côté orchestrateur. Aucun MEDIUM n'est reporté (donc aucune justification de report MEDIUM requise).

---

## Résolution (orchestrateur)

Re-vérif verte : `dart analyze packages/zcrud_flashcard` RC=0, `flutter test packages/zcrud_flashcard` **27 tests** RC=0 (codegen RC=0).

- **0 HIGH / 0 MAJEUR / 0 MEDIUM** — rien à corriger de bloquant.
- **LOW-3 — CORRIGÉ** : `_extraFrom` renvoie désormais `Map.unmodifiable` (cohérence `ZExtensible`/`ZCustomSource.payload`).
- **LOW-2, LOW-4 — CONSIGNÉS** (optionnels) : `kind` génériques `note`/`conversation`/`document` documentés comme réservés (déjà noté) ; injection du `sourceRegistry` côté dépôt = **E9-4**.
- **LOW-1 — ROUTÉ EN FOLLOW-UP v1.x (cross-cutting cœur).** Smell de pureté AD-14 partagé par `zcrud_flashcard` ET `zcrud_mindmap` : les 4 APIs pur-Dart `ZEntity`/`ZExtensible`/`ZExtension`/`ZSourceRegistry` ne sont exportées que par le barrel `zcrud_core.dart` (qui tire Flutter), pas par la surface pure `edition.dart`. NON bloquant (graphe acyclique, aucun state-manager/Firebase/Syncfusion importé, CORE OUT=0). Correction = petite story `zcrud_core` (surfacer ces types sur un entrypoint Flutter-free) puis rebasculer flashcard+mindmap — à planifier hors E9-1 (l'édition de `zcrud_core` était interdite dans cette story parallélisée).

**Verdict final : `done`.**
