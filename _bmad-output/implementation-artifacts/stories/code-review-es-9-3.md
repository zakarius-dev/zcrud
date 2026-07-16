# Code-review ES-9.3 — Podcasts (seam de génération) `ZPodcastGenerationPort`

Skill : **`bmad-code-review`** invoqué via le tool `Skill` (workflow step-file chargé et suivi ; step-01 gather-context → step-02 review). Mode : `full` (spec = fichier story). Revue ADVERSARIALE, autonome (subagent) : le reviewer joue lui-même les couches Blind Hunter / Edge-Case / Acceptance Auditor et **prouve** chaque garde load-bearing par injection réelle (R3/R12).

Périmètre : `packages/zcrud_study/` uniquement. Aucune écriture hors périmètre. Toutes les injections restaurées par édition ciblée (R13). `zcrud_study_kernel`/`zcrud_core` non modifiés. Aucun `dart pub get`/bascule pubspec déclenché par le reviewer.

## Verdict

**APPROUVÉ avec 1 finding MEDIUM (test-power) + 1 LOW.** Le code de prod est correct, tous les invariants AD ciblés sont respectés, la leçon M-1 d'ES-9.1 (garde AD-19.1 accessor-sanitize **verrouillée par un test qui rougit**) est réellement appliquée. Le finding MEDIUM porte sur un **pouvoir discriminant incomplet** des tests d'égalité par valeur (pas un défaut runtime), à corriger dans le périmètre de la story.

## Preuves rejouées sur disque (RC réels)

| Vérif | Commande | Résultat |
|---|---|---|
| Baseline tests ES-9.3 | `flutter test` (4 fichiers podcast + no_secret) | **RC=0, 9 tests passés** |
| Graphe (AD-1/AC5) | `python3 scripts/dev/graph_proof.py` | **total arêtes = 44**, 20 nœuds, **ACYCLIQUE OK**, **CORE OUT=0 OK** (delta 0) |
| Workspace | `dart run melos list` | **20 packages** |
| Repo-wide | `dart run melos run verify` | **RC=0** — `gate:secrets OK`, `[gate:reserved-keys] OK`, gate:reflectable/codegen/codegen-distribution/compat/web + verify:serialization OK |

### Injections R3 — pouvoir discriminant VÉRIFIÉ (menteur = finding)

| Injection | Cible | Résultat mesuré | Verdict |
|---|---|---|---|
| **R3-I3 (AC3, LOAD-BEARING M-1)** — accesseur neutralisé `get extra => _extra;` | `z_podcast_request_reserved_keys_test.dart` | **2 tests RED** (`updated_at` survit + `==` diverge) | Verrou AD-19.1 **RÉEL** ✅ |
| **R3-I4 (AC4 anti-crypto)** — `import 'package:crypto/crypto.dart';` ajouté | `z_podcast_no_crypto_test.dart` | **RC=1 (hors pipe)** | Scan anti-crypto **RÉEL** ✅ |
| **R3-I2 (AC2 anti-secret)** — clé `AIzaSy…` insérée dans le fichier domaine | `z_ai_ports_no_secret_test.dart` **+** `gate_secret_scan.dart` | test local **RC=1** ET `gate:secrets` **RC=1** (`cle Google (AIza...)`) | Anti-secret **RÉEL** (local + gate) ✅ |
| **R3-I1 (AC1 == par valeur)** — `==` rendu inopérant (`false && …`) | `z_podcast_generation_port_test.dart` | **RC=1** (test « == par valeur ») | Surface/égalité **partiellement** couverte (cf. MEDIUM) ⚠️ |

Le motif anti-crypto `\bsha256\b` est **case-sensitive** : la prose dartdoc « SHA-256 » ne le déclenche pas (contre-exemple légitime préservé) — vérifié, baseline vert avec le dartdoc en place. Le seuil `>= 5` du scan anti-secret est cohérent (5 fichiers `lib/src/domain/`).

## Findings

### MEDIUM-1 — Les tests d'égalité par valeur ne verrouillent PAS l'inclusion positive de `extra` (ni de la plupart des champs) dans `==`/`hashCode` (R12/R26 ; anti-pattern « garde = vœu », classe de défaut dominante de l'epic)

`packages/zcrud_study/test/z_podcast_generation_port_test.dart` (bloc « == par valeur », l. 74-130) et `z_podcast_request_reserved_keys_test.dart` (l. 38-48).

**Scénario prouvé par injection (RC réel) :**
- Neutraliser la participation de `extra` à l'égalité en prod — retirer `&& zJsonEquals(extra, other.extra)` de `operator ==` (`z_podcast_generation_port.dart:107`) → **`flutter test` des DEUX fichiers reste VERT (RC=0, 7 tests passés)**. Un `==` qui **ignore totalement `extra`** n'est détecté par aucun test.
- De même, retirer `folderId == other.folderId` de `==` → **VERT (RC=0)**.

**Cause :** les cas négatifs du test ne font varier que `sourceKind` (l. 105-115) ou `sourceHash` (l. 118-128), ou changent *tous* les champs à la fois (`const ZPodcastGenerationRequest(content:'src')`, l. 102). Aucun cas ne fait varier **un seul** champ parmi `content`, `sourceId`, `folderId`, `mode`, `languageTag`, **`extra`**. Résultat : seuls `sourceKind` et `sourceHash` sont réellement discriminés ; les 6 autres champs (dont `extra`) peuvent être supprimés de `==`/`hashCode` sans qu'un test rougisse.

**Conséquence sur les ACs :** le discriminant AC1 revendiqué « **égalité profonde de `extra` via `zJsonEquals`** » et la partie AC3 « **`==`/`hashCode` consomment l'accesseur sanitisé** » sont **surévalués** : le test `== consomme l'accesseur sanitisé` (`reserved_keys_test.dart:38`) passe même si `extra` est absent de `==` — il ne distingue pas « extra sanitisé ET comparé » de « extra jamais comparé ». C'est exactement l'anti-pattern *powerless guard* que l'epic ES-9 a mandat d'éviter (leçon M-1). La garde AD-19.1 **côté sanitisation** reste, elle, correctement verrouillée (R3-I3 rougit), donc la sévérité est MEDIUM et non HIGH — le prod `==` est correct, seul le pouvoir de test manque.

**Correctif (dans le périmètre story) :** ajouter des cas négatifs **à variation d'un seul champ** :
- deux requests identiques **sauf `extra`** (ex. `{'legit':1}` vs `{'legit':2}`) ⇒ `expect(a, isNot(equals(b)))` — pin de l'inclusion profonde de `extra` ;
- idem pour `content`, `sourceId`, `folderId`, `mode`, `languageTag` (un cas chacun), pour un pouvoir discriminant par-champ complet (R12/R26).

### LOW-1 — AC4 « composition content-addressed » : pouvoir discriminant fin sur du code kernel, pas sur du prod ES-9.3

`packages/zcrud_study/test/z_podcast_generation_port_test.dart` (bloc AC4, l. 132-176).

Le test assemble un `_FakePodcastPort` (défini dans le test) qui estampille `request.sourceHash` puis asserte `isStale(...)`/`buildId(...)`/`id` — c.-à-d. il exerce surtout le **fake du test** + les helpers **kernel déjà testés** (R20). La seule surface de prod ES-9.3 réellement pincée ici est le **plumbing des champs du request VO** (`sourceId`/`mode`/`sourceHash` lus par le fake). Le finding est **LOW/informational** : la story **assume explicitement** ce R20 (« l'assertion propre à ES-9.3 est la circulation … pas que `isStale` marche ») et l'invariant fort d'AC4 (absence de crypto) est, lui, verrouillé par un scan réel (R3-I4 rougit). Aucun changement requis ; consigné pour éviter toute survalorisation du pouvoir de ce test.

## Conformité invariants (vérifiée)

- **AD-4** — `abstract interface class ZPodcastGenerationPort` (jamais `sealed`, l. 134) ; **aucun** `ZSourceRegistry`/`switch`/`kind` en dur — `sourceKind` = enum kernel FERMÉ porté tel quel. Choix cohérent (ouverture inter-package absente). ✅
- **AD-5 / AD-11 / AD-26** — retour `Future<ZResult<ZStudyPodcast>>` = `Either<ZFailure, ZStudyPodcast>`, **jamais** nu ni `Stream` ; port neutre, aucun SDK/TTS/HTTP fuité. ✅
- **AD-12 (D4) anti-crypto/anti-secret** — aucun `import package:crypto`, `sha256`, `Digest`, `Hmac`, `zFnv1a32` ; aucun endpoint/clé ; `sourceHash` transporté comme `String` OPAQUE FOURNI (défaut `''`), jamais calculé. Verrous réels (R3-I2/R3-I4). ✅
- **AD-19.1** — slot privé `_extra` brut + `get extra => zSanitizeExtra(_extra, {...ZSyncMeta.reservedKeys})` ; verrou package-local rougit sous neutralisation (R3-I3). ✅
- **AD-1 / AD-17 (AC5)** — pubspec `zcrud_study` inchangé par ES-9.3 ; **delta graphe = 0** (44 arêtes, `zcrud_study → zcrud_study_kernel` préexistante), ACYCLIQUE, CORE OUT=0, retour `ZStudyPodcast` (pas `ZFlashcard` ⇒ aucune arête flashcard). ✅
- **R21** — `ZStudyPodcast`/`buildId`/`isStale`/enums **réutilisés** du kernel, aucun modèle recréé. ✅
- **Barrel (T3)** — `export 'src/domain/z_podcast_generation_port.dart';` ajouté ; `ZStudyPodcast`/enums **non** ré-exportés (cohérent ES-9.1). ✅

## État après revue

Fichier de prod restauré à l'identique (140 l., accesseur sanitisé, `folderId`+`zJsonEquals` présents, aucun `import crypto`, aucune clé, aucun `false &&`). 9 tests podcast/no_secret VERTS (RC=0). Gates repo-wide VERTS. `sprint-status.yaml` et `architecture.md` **non touchés**. Aucun finding HIGH/MAJEUR.

---

## Remédiation orchestrateur (2026-07-16) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| MEDIUM-1 (pouvoir discriminant incomplet de `==`) | 🟠 MEDIUM | ✅ **CORRIGÉ** | `test/z_podcast_generation_port_test.dart` (AC1) : les cas négatifs ne variaient que `sourceKind`/`sourceHash` ⇒ retirer `zJsonEquals(extra,…)` ou `folderId == …` de `operator ==` laissait le test VERT. Ajout de **6 cas mono-champ** (`content`, `sourceId`, `folderId`, `mode`, `languageTag`, `extra`) via un helper `copyOf` ne variant qu'UN champ. **Prouvé par l'orchestrateur** : retirer `zJsonEquals(extra, other.extra)` de `==` fait ROUGIR le cas `extra` (`Expected: not <…>, Actual: <…>`, RC=1) ; restauré → RC=0. Chaque contribution par-champ à `==` est désormais verrouillée. |
| LOW-1 (AC4 composition R20 résiduel) | 🟡 LOW | 🟡 **CONSIGNÉ** | Le test AC4 exerce surtout le fake + `buildId`/`isStale` (kernel déjà testé) ; seule surface prod ES-9.3 pincée = le plumbing des champs du request. La story assume explicitement ce R20 et l'invariant fort (anti-crypto) est verrouillé ailleurs. Consigné, aucun changement requis. |

**Re-vérif verte post-remédiation (RC hors pipe — R15)** : `flutter test` zcrud_study (R14) → RC=0, **148 tests** · `melos run verify` → RC=0 (`gate:reserved-keys OK` + `gate:secrets OK`) · graph_proof RC=0 (44 arêtes, delta=0, ACYCLIQUE, CORE OUT=0) · analyze RC=0. Prod `==` restauré (édition inverse).

**Verdict final** : ✅ **PRÊT POUR `done`** — MEDIUM-1 corrigé et prouvé ; LOW-1 consigné. Verrous reserved-keys/anti-crypto/anti-secret confirmés réels par le code-review + spot-check orchestrateur.
