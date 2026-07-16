# Code-review — ES-11.1 : Binding GetX (`zcrud_get`) — MIROIR GetX d'ES-10.1

**Skill réel** : `bmad-code-review` (tool `Skill`, préfixe `bmad-*`) — invoqué avec succès (pas de fallback disque).
**Date** : 2026-07-16 · **Reviewer** : agent BMAD code-review (adversarial) · **Statut story** : review
**Baseline** : `448616b4…` · **Périmètre écriture** : `packages/zcrud_get/` uniquement (aucune écriture effectuée — revue read-only).

---

## Verdict : ✅ APPROVE (aucun finding HIGH/MAJEUR/MEDIUM) — findings LOW seulement

Le binding study GetX est un miroir fidèle d'ES-10.1, **générique** (R28 respecté dès la conception), les gardes SM-1/tag sont **LOAD-BEARING sur le symbole public** (R27.4), et toutes les vérifs vertes sont rejouées réellement sur disque (ci-dessous). Deux findings LOW (durcissement de test + divergence de cache vs le mirror autoDispose) — optionnels.

---

## Preuves R3 (vérifs rejouées RÉELLEMENT sur disque, RC HORS pipe — R15)

| Vérif | Commande | Résultat |
|-------|----------|----------|
| Tests (R14 = **flutter test**) | `flutter test > log 2>&1; echo RC` | **RC=0** — `All tests passed!` **38 tests** (34 E2-9 + 4 suites study : égalité+tag mono-champ ×7, dedup SM-1, watch/seam/onClose, isolation backend/entité) |
| Graphe (AC6) | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK**, **CORE OUT=0 OK**, **total arêtes = 46** (delta +1 : `zcrud_get -> zcrud_study_kernel`, SORTANTE), **20 nœuds**. **AUCUNE** arête `zcrud_get -> entité` (seule arête `zcrud_*` ajoutée = kernel) |
| Sanity packages | `dart run melos list` | **20 packages**, `zcrud_get` présent |
| Analyze REPO-WIDE | `dart run melos run analyze` | **RC=0** — `melos exec … dart analyze . → SUCCESS`. `zcrud_get` : 0 issue. (8 `info` `prefer_initializing_formals` dans `zcrud_study` = **pré-existants**, hors périmètre 11.1) |
| Verify REPO-WIDE (AC7, R28/R9) | `dart run melos run verify` | **RC=0** — `gate:melos` OK, `gate:reflectable` OK (0 hors allowlist), `gate:secrets` OK, `gate:codegen` OK, `gate:codegen-distribution` OK (0 gitignoré), `gate:compat` OK (voie manifeste), `gate:web` OK, **`gate:reserved-keys` OK**, `verify:serialization` OK. **Frontière EX-3** : `example/` résout (`Got dependencies in ../../example`) — aucune entité déférée tirée |
| Résidu d'injection (R13) | `grep -rniE 'identityHashCode\|catch\(\|TODO' lib/src/study` | **Aucun résidu en CODE** — les 2 `identityHashCode` sont en **dartdoc** (anti-pattern documenté). Sources propres. |
| Périmètre | `git status --short` | Modifs = `zcrud_get/{lib/zcrud_get.dart,pubspec.yaml}` + `lib/src/study/` + `test/study/` (neufs) + story + lock. **Aucun** fichier lex/iffd/dodlp / `zcrud_core` / `zcrud_study_kernel` touché ✓ |

---

## Analyse adversariale par axe

### Axe 1 — R28 (binding GÉNÉRIQUE, aucune dep d'entité) ✅ SOLIDE
- `pubspec.yaml` deps `zcrud_*` = `zcrud_core` + `zcrud_study_kernel` **exactement** ; commentaire d'invariant à jour.
- `graph_proof` = 46 (delta +1, arête kernel seule) — aucune arête d'entité ; `melos verify` repo-wide VERT (EX-3 : `example/` résout). Le double garde-fou (graph + verify) est effectif.
- **AC8 — dépouillement des commentaires vérifié** : `_stripDartComment` (coupe à `//`, dartdoc `///` inclus) **et** `_stripYamlComment` (coupe à `#`) : un dartdoc peut NOMMER la frontière (`cloud_firestore`), le scan ne mord que le CODE. Liste noire pubspec = 4 backends + 6 entités + `zcrud_study:` (agrégat ≠ kernel). `Box` borné par `RegExp` (évite `Toolbox`). Garde effective (R3-I7 prouvé RED par le dev, sources restaurées).

### Axe 2 — R27.4 (le verrou vise le SYMBOLE PUBLIC) ✅ SOLIDE
- **Dedup SM-1** : `z_session_dedup_test.dart` exerce **`zPutStudySessionSelector`** (factory exportée au barrel), PAS `ZSessionConfigKey.tag` isolé. Injection `tag = identityHashCode` ⇒ 2ᵉ appel → tag distinct → `Get.put` → `builds` 1→2 + `identical` faux ⇒ RED. Confirmé : le `create` injectable compte les constructions ; dedup via `Get.isRegistered(tag:)`.
- **Seam throw** : `z_study_watch_controller_test.dart` exerce **`buildStudyWatchController`** (factory exportée) → `throwsA(isA<ZScopeError>().having(message, contains('_FakeEntity')))`. La factory est un one-liner `ZStudyWatchController(resolver.resolve<…>())` — impossible d'avaler le throw sans construire un repo de repli (rendrait `throwsA` RED). Assertion **sur le TYPE** ✅.

### Axe 3 — R27 (égalité profonde, chaque champ un à un) ✅ SOLIDE
- `z_session_config_key_equality_test.dart` : **7 cas mono-champ** via `copyWith` (mode, folderId, tagIds, types, count, extension, extra), chacun asserte **à la fois** `==` inégal **ET** `tag` différent. Neutraliser un champ dans `==` **ou** l'exclure du `tag` rougit le cas correspondant.
- `extra` imbriqué comparé par **`zJsonEquals`** (instances distinctes prouvées `identical(...extra) == false`) ; `tag` **canonique** (clés récursivement triées) ⇒ insensible à l'ordre des clés `extra`, sensible à la valeur profonde. `==`/`hashCode`/`tag` cohérents.
- **Cohérence `a == b ⟺ a.tag == b.tag`** vérifiée (JSON canonique complet, jamais `hashCode` seul → pas de collision). `zJsonEquals(null, [])` = `false` (chemin scalaire) ⇒ cohérent avec `tag` (`"null"` ≠ `"[]"`) : pas de discordance null/liste-vide.

### Axe LIFECYCLE — AC5 / AD-2 / AD-15 / AD-1 / AD-5 ✅ SOLIDE
- `onClose()` : `_sub?.cancel(); _sub = null; super.onClose()` — test `StreamController(onCancel:)` prouve `onCancel` appelé après `onClose` (R3-I5 : retirer `cancel()` → RED).
- AD-1 : arête SORTANTE binding → study, binding = PUITS (aucun package study ne dépend de `zcrud_get`, confirmé par le dump graph). AD-2/AD-15 : GetX confiné à `zcrud_get` (garanti structurellement — kernel/core ne dépendent pas du binding) ; garde d'idiome récursive (`test/purity`) couvre `lib/src/study/` (VERTE). AD-5 : `watchAll()` re-émis **tel quel** (`items.assignAll`, test de séquence exacte) ; écritures `Future<ZResult<T>>` non enveloppées (test `save` → `isRight`). AD-24 : égalité de clé + `tag` déterministe au binding, kernel inchangé (`git status` : `zcrud_study_kernel` non modifié).

---

## Findings

### 🟡 LOW-1 — Cache de sélecteurs GetX sans éviction (divergence avec le mirror `autoDispose` Riverpod)
**Fichier** : `packages/zcrud_get/lib/src/study/z_study_get.dart:118-130` (`zPutStudySessionSelector`).
`Get.put<ZStudySessionSelector>(…, tag: tag)` enregistre une instance par `tag` **sans jamais** de `Get.delete(tag:)` ni de tie-in lifecycle. Le miroir ES-10.1 s'appuie sur `autoDispose` (le sélecteur est libéré dès qu'aucun consommateur ne l'observe) ; ici le registre GetX **croît de façon non bornée** au fil des configs distinctes sur la durée de vie de l'app (DODLP).
**Impact** : borné en pratique (peu de configs de session distinctes ; `ZStudySessionSelector` est un objet-valeur immuable minuscule) — pas de fuite de ressource (aucun stream/handle détenu). Aucun AC ne couvre l'éviction du cache (AC5 ne vise que le controller).
**Recommandation** : consigner en dette (éviction/`Get.delete` app-side sous DW-ES111-1) OU documenter explicitement le choix « cache permanent de valeurs pures » dans la dartdoc. Non bloquant.

### 🟡 LOW-2 — La value-equality du champ `extension` n'est pas épinglée par un test à instances distinctes (durcissement R27)
**Fichier** : `packages/zcrud_get/test/study/z_session_config_key_equality_test.dart` (couverture).
Le cas « égales-mais-distinctes » utilise `const _FakeExt(1)` (canonicalisé → **même identité** partagée) ; le cas mono-champ `extension` compare `_FakeExt(1)` vs `_FakeExt(2)`. **Aucun** test n'exerce deux instances `extension` **distinctes mais `==`-égales**. Conséquence : une régression de `a.extension == b.extension` vers `identical(a.extension, b.extension)` **passerait tous les tests actuels** (la neutralisation *complète* est bien captée par le mono-champ, mais le rétrécissement identité-vs-valeur ne l'est pas). Pour `extra` ce durcissement existe (`identical(...extra) == false`), pas pour `extension`.
**Impact** : le code de PROD est correct (`extension ==`, délègue au `==` de la sous-classe `ZExtension`). C'est une lacune de **puissance de garde** (identique dans ES-10.1). Effet réel d'une éventuelle régression : incohérence `==`/`tag` (le `tag` reste value-based via `toJson`) → keying `Set`/`Map` de `ZSessionConfigKey` divergent du dedup GetX.
**Recommandation** (trivial, ~4 lignes) : ajouter un cas avec deux extensions distinctes-mais-égales (ex. `_FakeExt(1)` construit deux fois, non-const) assertant `==`/`hashCode`/`tag` identiques. Optionnel (LOW).

### 🔵 Nit — Asymétrie de robustesse `tag` vs `==` sur un `extra` non-JSON-encodable
`tag` fait `jsonEncode(config.extra)` : lèverait si `extra` portait une valeur non-JSON (ex. `DateTime` brut), alors que `==`/`zJsonEquals` tolère des objets arbitraires. Acceptable — le contrat `extra` (AD-4) est « valeurs JSON issues d'un store ». Mentionné pour traçabilité, aucune action requise.

---

## Conformité checklist (rappel CLAUDE.md)
- HIGH/MAJEUR : **0**. MEDIUM : **0**. LOW : **2** (+1 nit) — optionnels, consignés ci-dessus.
- Story reste **VERTE** : `flutter test` RC=0 (38), `melos analyze` RC=0, `melos verify` RC=0, graph 46/acyclique/CORE OUT=0.
- R28/R27.4/AD-24/AD-1/AD-2/AD-5/AD-6/AD-10/AD-15 : respectés et prouvés par tests à rouge provoqué (R3 : I2/I3/I4/I5/I6/I7 restaurés, sources propres).
- Aucun fichier hors périmètre touché ; sprint-status.yaml **non touché** par le reviewer (ressort de l'orchestrateur) ; architecture.md non touché ; dette **DW-ES111-1** à escalader (câblage DODLP app-side).

**Décision** : story prête pour `done` (findings LOW optionnels ; LOW-2 recommandé comme durcissement trivial, LOW-1 à consigner en DW-ES111-1).

---

## Remédiation orchestrateur (2026-07-16) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| LOW-2 (value-equality de `extension` non épinglée) | 🟡 LOW | ✅ **CORRIGÉ** | `z_session_config_key_equality_test.dart` : `makeBase()` utilisait `const _FakeExt(1)` partagé ⇒ `a`/`b` avaient l'instance IDENTIQUE, une régression `extension ==` → `identical(extension)` passait. Correctif : `extension: _FakeExt(1)` **non-const** (instances distinctes-mais-égales) + assertion `identical(a.extension, b.extension) isFalse`. **Prouvé par l'orchestrateur** : dégrader la prod en `identical(a.extension, b.extension)` → le cas `a == b` ROUGIT (RC=1) ; restauré → RC=0. La value-equality de `extension` est désormais épinglée (le même durcissement s'appliquerait à ES-10.1, déjà committé — noté). |
| LOW-1 (cache de sélecteurs GetX sans éviction) | 🟡 LOW | ✅ **ESCALADÉ (DW-ES111-1)** | `zPutStudySessionSelector` fait `Get.put(tag:)` sans `Get.delete` (contraste avec l'autoDispose Riverpod) ⇒ cache à croissance non bornée. Impact borné (objets-valeur immuables, aucun handle). Escaladé dans `architecture.md § Deferred › DW-ES111-1` (éviction possible app-side). |
| nit (`tag` fait `jsonEncode(extra)`) | 🔵 nit | 🟡 **CONSIGNÉ** | `tag` lèverait sur un `extra` non-JSON là où `==` tolère des objets arbitraires. Acceptable vu le contrat `extra` (AD-4 : valeurs JSON-safe). Aucune action. |
| DW-ES111-1 (câblage DODLP app-side) | — | ✅ **ESCALADÉ** | Consolidé avec DW-ES102-1 dans `architecture.md § Deferred` : câblage app-side des bindings Riverpod+GetX (spécialisation typée, enregistrement des seams, cutover) déféré aux sessions app dédiées. Aucun repo lex/iffd/dodlp touché. |

**Re-vérif verte post-remédiation (RC hors pipe — R15)** : `flutter test` zcrud_get (R14) → RC=0, **38 tests** · graph_proof RC=0 (46 arêtes, ACYCLIQUE, CORE OUT=0, aucune arête d'entité — R28) · `melos run verify` REPO-WIDE → RC=0 (reserved-keys/secrets/web/serialization OK, frontière EX-3) · analyze RC=0.

**Spot-check orchestrateur (R3 SM-1/tag)** : `tag` dégradé en `identityHashCode(config)` → le dedup casse → le test SM-1 ROUGIT (constructions 1→2, RC=1) ; restauré. **L'objectif produit n°1 est verrouillé aussi au binding GetX.**

**Verdict final** : ✅ **PRÊT POUR `done`** — 0 finding bloquant ; LOW-2 corrigé et prouvé ; LOW-1/DW-ES111-1 escaladés ; nit consigné. R28 (binding générique) + R27.4 (symbole public) + SM-1 confirmés.
