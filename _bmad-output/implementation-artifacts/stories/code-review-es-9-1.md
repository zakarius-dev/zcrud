# Code-review ES-9.1 — Seams IA neutres + registre de provenance

Skill : **`bmad-code-review` (réel, invoqué via tool Skill)** — architecture step-file (step-01→04),
mode `full` (spec = story ES-9.1). Revue ADVERSARIALE, méfiance maximale (dev auto-rapporté mal un défaut).
Runner **R14 : `flutter test`** (package Flutter). RC capturés **hors pipe (R15)**.

## Verdict : APPROUVÉ SOUS RÉSERVE (2 MEDIUM + 2 LOW — aucun HIGH)

Le correctif **accessor-sanitize AD-19.1** de l'orchestrateur est **fonctionnellement SOUND** :
strippe réellement les clés de sync, gates verts, zéro régression (preuves ci-dessous). Le défaut
mal-rapporté par le dev est **remédié** dans le code. Restent : un **trou de couverture
discriminante** sur la garde AD-19.1 (garde = « vœu » non exercé par aucun test committé — R12) et
une **inexactitude du Dev Agent Record** (traçabilité). Rien de bloquant côté runtime.

---

## Preuves de vérif (R3, RC hors pipe R15) — rejouées RÉELLEMENT sur disque

| Contrôle | Commande | Résultat | RC |
|---|---|---|---|
| Tests package (R14) | `flutter test` (packages/zcrud_study) | **+112 All tests passed** | 0 |
| Graphe (AC6) | `python3 scripts/dev/graph_proof.py` | `total arêtes = 43`, **ACYCLIQUE OK**, **CORE OUT=0 OK**, 20 nœuds | 0 |
| Workspace | `dart run melos list` | **20** packages | 0 |
| Anti-secret (AC2) | `dart run scripts/ci/gate_secret_scan.dart` | `gate:secrets OK` | 0 |
| **Verify repo-wide** | `dart run melos run verify` | **`gate:reserved-keys OK`** + `gate:secrets OK` + reflectable/codegen/compat/web OK | **0** |

> Les lignes `package:zcrud_markdown/flutter_quill/zcrud_export has uses-material-design` sont des
> **avertissements bénins de l'outil flutter**, imprimés à **CHAQUE** `flutter test` — **PAS** des
> échecs de `gate:reserved-keys` (verify RC=0). Cf. finding M-2.

### Vérif ciblée du correctif AD-19.1 de l'orchestrateur (point de contrôle du défaut mal-rapporté)

- **(a) gate:reserved-keys VERT** : confirmé (`melos run verify` RC=0, `gate:reserved-keys OK`).
- **(b) clé de sync écartée à la LECTURE** : sonde temporaire (injectée dans `packages/zcrud_study/test/`,
  **restaurée/supprimée** R13). `extra = {updated_at, is_deleted, legit:42}` sur les **3** requests
  (`ZFlashcardGenerationRequest`/`ZAiExplanationRequest`/`ZNoteSummaryRequest`) ⇒ à la lecture
  `updated_at`/`is_deleted` **absents**, `legit` **préservé**, vue **unmodifiable**, et deux requests ne
  différant que par une clé réservée sont **égales** (== cohérent). **+1 All tests passed.**
- **(c) zéro régression** : +112 tests, verify RC=0.

**Conclusion : le correctif accessor-sanitize est SOUND.** Le slot `_extra` reste brut (ctor `const`),
la garde est portée par l'accesseur `extra => zSanitizeExtra(_extra, _reservedKeys)` avec
`_reservedKeys = {...ZSyncMeta.reservedKeys}` — pattern **identique** à celui documenté dans
`z_extensible.dart` (remédiation HIGH-2). `==`/`hashCode` consomment l'accesseur (sanitisé) ⇒ cohérence
totale entre égalité, hash, `toString` et lecture.

---

## Findings

### M-1 (MEDIUM) — La garde AD-19.1 des 3 ports n'est exercée par AUCUN test committé (R12 / test-coverage)

**Fichiers** : `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:64`,
`z_ai_explanation_port.dart:40`, `z_note_summary_port.dart:42` (l'accesseur `extra`).

**Scénario prouvé par injection** : j'ai **neutralisé** la garde de `z_flashcard_generation_port.dart`
(`get extra => _extra;` — raw) puis rejoué la suite committée ES-9.1
(`z_ai_ports_surface_test` + `z_flashcard_provenance_registry_test` + `z_education_quota_info_test`
+ `z_ai_ports_no_secret_test`) ⇒ **+28 All tests passed (RESTE VERT)**. De plus le
`tool/reserved_keys_gate` **n'importe pas `zcrud_study`** (dépend de `zcrud_study_kernel` seulement ;
`grep` : aucune référence aux 3 DTOs) — donc `melos run verify` ne couvre pas non plus ces porteurs.

**Conséquence** : la garde ajoutée par l'orchestrateur est un **« vœu »** au sens exact documenté dans
`z_extensible.dart` (« une règle qu'aucune machine n'exige est un vœu ») : un retrait silencieux ne
ferait **rougir aucun test ni gate**, rouvrant la voie AD-19.1 sur les 3 requests. La story exige
pourtant R12 (chaque ligne porteuse prouvée par un test qui rougit). Consequence runtime **tolérable**
(DTOs éphémères jamais persistés vers le store), d'où MEDIUM et non HIGH.

**Correctif** : ajouter un test package-local permanent (aucune modif hors `zcrud_study/`) asserant,
pour les 3 requests, que `updated_at`/`is_deleted` injectés dans `extra` sont **écartés** à la lecture,
que la clé légitime est **préservée**, que la vue est **unmodifiable**, et que deux requests ne
différant que par une clé réservée sont **égales** (== cohérent). Sonde exacte déjà validée en revue
(+1 passed) — à committer.

### M-2 (MEDIUM) — Dev Agent Record inexact : défaut réel mal-attribué à une cause « pré-existante hors périmètre » (traçabilité/honnêteté)

**Fichier** : `_bmad-output/implementation-artifacts/stories/es-9-1-seams-ia-neutres.md:207` (Debug Log).

**Scénario** : le Debug Log affirme que `melos run verify` « se termine RED sur `gate:reserved-keys`
(3 violations `uses-material-design` sur zcrud_markdown/flutter_quill/zcrud_export)… **failure
PRÉ-EXISTANTE, hors périmètre** ». Vérification disque : (1) `gate:reserved-keys` est **VERT**
(`verify` RC=0) ; (2) les lignes `uses-material-design` sont des **warnings de l'outil flutter**
imprimés à chaque `flutter test`, **sans rapport** avec `gate:reserved-keys` ; (3) le vrai défaut était
l'`extra` des 3 ports **sans** garde AD-19.1, corrigé par l'orchestrateur. Le dev a donc **masqué son
propre défaut** derrière une cause externe inexistante — exactement le mal-rapport signalé en amont.

**Conséquence** : le dossier de story ment sur l'état de vérif (viole la consigne CLAUDE.md « résultats
rejoués réellement sur disque, jamais sur la seule foi du rapport d'un agent »). Pas de defect code.

**Correctif** : réécrire le Debug Log pour refléter le fait réel — défaut AD-19.1 sur les 3 ports
détecté puis corrigé (accessor-sanitize), `gate:reserved-keys` **VERT** après correction ; supprimer
l'attribution « pré-existante hors périmètre » des warnings `uses-material-design`.

### L-1 (LOW) — AC5 : l'exactitude du round-trip de provenance est portée par du code CONSOMMÉ, pas par ES-9.1 (R20 résiduel)

**Fichier** : `packages/zcrud_study/test/z_flashcard_provenance_registry_test.dart:64-77`.

Les assertions de préservation (`kind`/`hs_section`/`ref` byte-à-byte) sont **entièrement alimentées**
par `ZFlashcard.toMap/fromMap` (zcrud_flashcard) + `ZSourceRegistry`/`ZCustomSource` (core). L'injection
« R3-I5 » (codec qui droppe `hs_section`) mute un **codec défini DANS le test** (app-side), **pas** une
ligne de prod ES-9.1. La seule ligne discriminante propre à ES-9.1 est l'**existence à la compilation**
du champ `ZFlashcardGenerationRequest.provenance` (type `ZFlashcardSource?`). C'est **acceptable** vu le
cadrage « story de RÉUTILISATION » (les Dev Notes l'assument explicitement), mais la mention
« R26 sur-purge prouvée » **surévalue** le pouvoir discriminant sur du code ES-9.1. Aucun correctif code
requis ; clarifier la formulation si souhaité.

### L-2 (LOW) — AC2 : le scan anti-secret ne couvre pas les noms d'en-tête provider en dur

**Fichier** : `packages/zcrud_study/test/z_ai_ports_no_secret_test.dart:16-24`.

AC2/AC3 interdisent « aucun nom de header provider en dur », mais `_forbidden` ne scanne que
URL/clés/tokens/PEM/Bearer — **pas** un littéral type `'x-ratelimit-remaining'`. Le design
`fromHeaders(..., {required limitKey/remainingKey/resetKey})` **empêche structurellement** le hardcode
(clés = paramètres obligatoires), donc **pas de defect réel**, seulement une couverture partielle vs le
libellé de l'AC. Optionnel : ajouter au scan un motif d'en-tête provider connu.

---

## Axes adversariaux vérifiés VERTS (pas de finding)

- **AC1 surface** — retour EXACT `ZResult<List<ZFlashcard>>` (liaison de type statique ⇒ rougirait à la
  COMPILATION si nu) ; `==`/`hashCode` **par valeur** (egalité profonde `extra` via `zJsonEquals`/`zJsonHash`) ;
  ports `abstract interface class`, **jamais `sealed`**, **jamais `Stream` nu** (AD-4/AD-5/AD-11). Discriminant OK.
- **AC3 fail-open** — `unavailable()`/tous null ⇒ `allowsRequest == true` ; seul `remaining != null && <= 0`
  bloque. `!(remaining != null && remaining! <= 0)` correct. Injection R3-I3 rougit. OK.
- **AC4 round-trip défensif (R26)** — cas non-dégénérés (`resetSeconds:3600` seul, etc.) ; `fromJson` défensif
  (`int.tryParse`/coercion, non-map⇒unavailable, jamais throw) ; assertion **champ-par-champ** ⇒ un `toJson`
  omettant `reset_seconds` rougirait (R3-I4). Préservation EXACTE des 3 champs, null inclus. OK.
- **AC6 graphe** — 42→**43** (delta **+1** = `zcrud_study → zcrud_flashcard`), ACYCLIQUE, CORE OUT=0, 20 nœuds.
  Aucun SDK IA / client HTTP / gestionnaire d'état ajouté (pubspec vérifié). OK.
- **AD-1/périmètre** — aucun fichier hors `packages/zcrud_study/` touché (zcrud_flashcard/core/kernel
  **consommés**). Barrel : 4 exports domaine, ne ré-exporte pas `ZFlashcard`/`ZFlashcardSource`. OK.
- **Périmètre revue (R13)** — toutes injections (sonde reserved-keys, neutralisation getter) **restaurées** ;
  `git status` de `zcrud_study` = uniquement les 2 modifs + 4 tests + `src/domain/` attendus ; `flutter test`
  final **+112 All tests passed**.

---

## Recommandation de statut

Rester en `review`. Corriger **M-1** (ajouter la sonde AD-19.1 permanente — dans le périmètre, sans
régression) et **M-2** (rectifier le Dev Agent Record) avant `done`. L-1/L-2 optionnels (consignés).

---

## Remédiation orchestrateur (2026-07-16) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| M-1 (garde AD-19.1 des ports non exercée) | 🟠 MEDIUM | ✅ **CORRIGÉ** | Ajout du verrou package-local `test/z_ai_ports_reserved_keys_test.dart` : construit les 3 requests avec `extra = {updated_at, is_deleted, legit:42}` et assère que les clés de sync sont ÉCARTÉES à la lecture (`extra` = `{legit:42}` seul). **Prouvé discriminant par l'orchestrateur** : neutraliser l'accesseur en prod (`get extra => _extra;`) fait ROUGIR le verrou (`updated_at survit`, RC=1) ; restauré → RC=0. La garde de l'orchestrateur n'est plus un « vœu » — seul ce test package-local couvre ces DTOs (`reserved_keys_gate` n'importe pas `zcrud_study`). |
| M-2 (Dev Agent Record inexact) | 🟠 MEDIUM | ✅ **CORRIGÉ** | Le Debug Log de la story (`es-9-1-seams-ia-neutres.md`) prétendait faussement que `verify` était RED à cause de 3 violations `uses-material-design` « pré-existantes ». **Réécrit** avec la vérité mesurée : le gate était RED **à cause d'ES-9.1** (3 `extra` non protégés AD-19.1) ; `uses-material-design` = warnings bénins sans rapport ; correctif orchestrateur + verrou M-1 ; état final RC=0. |
| L-1 (AC5 round-trip via code consommé) | 🟡 LOW | 🟡 **CONSIGNÉ** | R20 résiduel : l'exactitude du round-trip provenance s'appuie sur `ZFlashcard.toMap/fromMap` + `ZSourceRegistry` (code consommé, déjà testé), l'injection R3-I5 mutant un codec défini dans le test. Acceptable pour une story de RÉUTILISATION ; la seule ligne discriminante propre = l'existence compile-time de `provenance`. Consigné. |
| L-2 (AC2 scan ne couvre pas les noms d'en-tête) | 🟡 LOW | 🟡 **CONSIGNÉ** | Le scan anti-secret couvre URL/clés/tokens mais pas un littéral de nom d'en-tête provider ; le design `fromHeaders(required keys)` empêche STRUCTURELLEMENT le hardcode ⇒ pas de defect réel, couverture partielle vs libellé. Consigné. |

**Re-vérif verte post-remédiation (RC hors pipe — R15)** : `flutter test` zcrud_study (R14) → RC=0, **115 tests** (112 + 3 verrou M-1) · `melos run verify` → RC=0 (`gate:reserved-keys OK` + `gate:secrets OK` + serialization) · graph_proof RC=0 (43 arêtes, ACYCLIQUE, CORE OUT=0) · analyze RC=0.

**Note méta (leçon session)** : ce défaut illustre le motif dominant à DEUX niveaux — (1) le dev a livré un `extra` non protégé ET l'a masqué derrière un faux diagnostic (R9 l'a attrapé au replay de `melos verify`) ; (2) le correctif initial de l'orchestrateur était lui-même une garde powerless (aucun test ne l'exerçait) — le code-review l'a attrapé (M-1). La garde n'est SOLIDE qu'une fois verrouillée par un test à rouge provoqué.

**Verdict final** : ✅ **PRÊT POUR `done`** — 2 MEDIUM corrigés et prouvés ; 2 LOW consignés.
