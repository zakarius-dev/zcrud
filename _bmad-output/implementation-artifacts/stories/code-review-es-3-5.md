# Code Review — ES-3.5 (Compat sérialisation camelCase↔snake + ZSyncMeta additif + gate ENFORCED)

Revue ADVERSARIALE (effort high) — skill `bmad-code-review`. Axe n°1 : PROUVER le pouvoir discriminant du gate modifié (`scripts/ci/verify_serialization.dart`).

**VERDICT : APPROUVÉ (`review` → prêt pour `done`).** Aucun finding HIGH/MAJEUR. Gate discriminant PROUVÉ par réexécution réelle. Vérif verte rejouée sur disque, RC=0 partout.

---

## 1. Preuve REJOUÉE que le gate peut ÉCHOUER (cœur anti-faux-vert)

Toutes les mesures via `OUT=$(...); RC=$?` (jamais de pipe qui masquerait le RC).

| Scénario | Attendu | Mesuré | Verdict |
|---|---|---|---|
| Env var posée, corpus en place | RC=0 + « corpus vert sur tous les packages » | **RC=0** | ✅ |
| Packages exécutés | {generator, kernel, firestore}, firestore via `flutter` | firestore=`flutter`, generator/kernel=`dart` | ✅ |
| **R3-7** corpus firestore détaggé + env var | RC=1, bannière `❌ ÉCHEC … packages/zcrud_firestore` | **RC=1** + bannière exacte | ✅ **le gate MORD** |
| R3-7 même état SANS env var | RC=0 + bannière `⚠️ SKIP` (warning préservé) | **RC=0** | ✅ |
| Restauration (édition ciblée @Tags) | RC=0 | **RC=0** | ✅ |
| **R3-8** tag déclaré dans `zcrud_geo` sans corpus + env var | RC=1, `❌ ÉCHEC … packages/zcrud_geo` | **RC=1** | ✅ scoping piloté par la déclaration |
| R3-8 restauration (rm geo/dart_test.yaml) | RC=0 | **RC=0** | ✅ |

Conclusion : la population redevable n'est **pas** trivialement toujours-verte. Un tag-declarer sans corpus vert donne bien RC=1 sous l'interrupteur. Le corpus firestore n'est **pas** POWERLESS (son retrait fait échouer le gate).

## 2. Micro-ajustement du gate — squelette inchangé (audit du diff)

`git diff scripts/ci/verify_serialization.dart` = **exactement** (1) ajout du helper `_declaresCompatTag(Directory)` (parse textuel du bloc `tags:`, strip des commentaires) + (2) un conjoint `&& _declaresCompatTag(ent)` dans la construction de `withTests`. **INCHANGÉS** : itération, choix runner `flutter`/`dart`, `exit 79 → skipped`, bannière bruyante, interrupteur `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 → failed`. Le chemin d'échec d'un corpus rouge (exitCode ∉ {0,79} → `failed=true`) est intact. Restriction légitime : les 9 packages sans entité persistée seraient POWERLESS (interdit R12) ; `dart_test.yaml` est le marqueur d'opt-in déjà en place (kernel/generator). ✅

Miroir `melos.yaml` ↔ `pubspec.yaml` : les deux préfixent la **dernière** commande de l'agrégat `verify` avec l'env var, à l'identique (`gate:melos-divergence` satisfait). ✅

## 3. Codec `ZStudyLegacyCodec` — audit par AC

- **AC1 (casse, R3-1)** : `camelToSnake`/`snakeToCamel` génériques + idempotents ; clé inconnue transformée+conservée ; round-trip restitue camelCase (modulo `is_deleted:false` additif). Fixtures = docs camelCase réels. Discriminant. ✅
- **AC2 (6→4, R3-2)** : `mapDocumentStatus` conforme à la table (uploading→uploading ; converting/embedding→validating ; uploaded/converted/embedded→ready ; null/inconnu/non-String→uploading). 4 sorties, jamais `rejected`. Granularité préservée dans `_legacy_status` (AD-4). Les 6 + null/inconnu/non-String testés individuellement. ✅
- **AC3 (défensif, R3-3)** : `toCanonical`/`toLegacy` sans chemin de throw ; `_millisToIsoOrNull` try/catch + bornes. Fixture `document_corrupt` (`status:42`, `createdAt:"pas-une-date"`, `contentLength:"beaucoup"`) → dégrade, ne throw jamais. ✅
- **AC4 (ZSyncMeta additif, R3-4)** : `putIfAbsent(kIsDeleted,false)` — jamais d'écrasement (fixture `with_sync_meta` `is_deleted:true` préservé) ; `updated_at` laissé absent → `updatedAt:null`. E2E `getAll` via `FakeFirebaseFirestore` prouve la visibilité (`_isVisible`). Clés réservées passées telles quelles (non remappées). ✅
- **AC5 (FlashcardSource)** : voir finding LOW-1.
- **AC6 (dates, R3-6)** : `int` millis sur clé `_at` → ISO UTC ; hors bornes / non-`_at` → intact. E2E prouve Timestamp (adaptateur) et int (codec) convergent. ✅
- **AC7 (enforcement)** : prouvé §1. ✅
- **AC8 (scoping)** : prouvé §1 (R3-8). ✅
- **AC9 (confinement)** : `ZStudyLegacyCodec`/`camelToSnake`/`mapDocumentStatus` UNIQUEMENT dans `zcrud_firestore/lib`. Aucune clé camelCase de **persistance** dans core/kernel/document (les occurrences grep sont des identifiants Dart / dartdoc, pas des `@JsonKey`/`toMap`). Signature nue `Map<String,dynamic>` (aucun type `cloud_firestore`, AD-5). `graph_proof` ACYCLIQUE + CORE OUT=0. ✅

## 4. Vérif verte rejouée réellement (disque)

| Vérif | RC |
|---|---|
| `dart analyze` firestore / kernel / script | 0 / 0 / 0 |
| `flutter test` firestore FULL (173) | 0 |
| `dart test` kernel FULL (302) | 0 |
| gate SANS env var (warning) | 0 |
| **gate AVEC `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1`** | **0** |
| `graph_proof.py` (ACYCLIQUE, CORE OUT=0) | 0 |

Toutes les injections R3 restaurées par **édition ciblée** ; working-tree propre (test @Tags = `serialization-compat`, `packages/zcrud_geo/dart_test.yaml` absent, script = seul le diff D7 légitime). Aucun `git checkout/restore` utilisé.

---

## Findings

### LOW-1 — AC5 est une réplication de contrat (double de test), pas un pinning du lib réel
`_decodeSourceLikeFlashcard` (test firestore) ré-implémente le contrat `ZFlashcardSource.fromJson` ; il ne teste PAS le lib `zcrud_flashcard` réel. Un drift futur de `ZFlashcardSource.fromJson` (ex. réintroduction d'un `FormatException`) laisserait ce test VERT.
- **Atténuation confirmée** : le comportement réel (unknown→`ZCustomSource`, guard app-codec, jamais throw) EST couvert de façon exhaustive dans `packages/zcrud_flashcard/test/z_flashcard_test.dart` (l.200-235, 311+). Aucune lacune de couverture réelle.
- **Justification** : `zcrud_firestore` n'a AUCUNE arête vers `zcrud_flashcard` (AD-1) — la réplication est la seule option confinée. Tradeoff documenté (D8/Completion Notes).
- **Verdict** : accepté (documenté). Aucune action requise.

### LOW-2 — Scoping opt-in : un package « redevable » non déclaré est silencieusement invisible au gate
Le filtre `_declaresCompatTag` fait qu'un package qui DEVRAIT porter un corpus mais dont le `dart_test.yaml` ne déclare pas le tag (ou est supprimé) sort silencieusement de la population — sans RC=1. Vecteur de faux-vert résiduel (supprimer `packages/zcrud_firestore/dart_test.yaml` retirerait le corpus firestore de l'enforcement sans échec).
- **Atténuation** : une telle suppression apparaîtrait dans un diff/review ; l'alternative allowlist a été explicitement pesée et rejetée (D7) pour l'évolutivité. Le corpus + la déclaration sont commités ensemble.
- **Suggestion (non bloquante, defense-in-depth)** : un « plancher » `const _floorRequired = {'zcrud_firestore','zcrud_generator','zcrud_study_kernel'}` échouant si un de ces packages sort de la population — combine évolutivité (opt-in) et garde anti-suppression. À consigner comme dette LOW si non retenu.
- **Verdict** : tradeoff documenté, non bloquant.

### LOW-3 (nit) — `_normalizeValue` ne comble que `int`, pas `double`/`num` millis
Un `_at` portant un `double` millis (certains décodeurs JSON, ou `num` Firestore) traverserait sans conversion → date `null` au décode. Non présent dans le corpus IFFD (`createdAt` = `int`). Défensif (pas de throw). Optionnel.

---

## Décision
Story ES-3.5 **APPROUVÉE** — le gate `verify:serialization` conserve son pouvoir discriminant (RC=1 prouvé sous l'interrupteur pour firestore détaggé ET geo redevable sans corpus), squelette préservé, codec défensif et confiné (AD-27/AD-5/AD-10/AD-4), DW-ES21-1 soldée, DW-ES32-1 partielle. 0 HIGH, 0 MAJEUR, 0 MEDIUM. 3 LOW (tous documentés/atténués, aucun bloquant). Transition `review → done` autorisée (édition ciblée du sprint-status par l'orchestrateur).
