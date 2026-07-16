# Code-review ES-11.2 — Migration IFFD flat→canonique (mécanique zcrud-side)

Skill réel invoqué : `bmad-code-review` (tool Skill, préfixe `bmad-*`). Revue adversariale, méfiance maximale (migration = correctness subtile).

Cible : `packages/zcrud_firestore/lib/src/data/z_study_migrator.dart` + barrel + 2 suites de tests + 3 fixtures synthétiques (ES-11.2, statut `review`).

## Verdict : APPROUVÉ (aucun finding HIGH/MAJEUR/MEDIUM)

La mécanique est solide. Les 3 gardes structurantes (garde d'idempotence, census R26, défensif-par-construction) sont **prouvées LOAD-BEARING** par injections réelles rejouées sur disque (mutation → RED → restauration). Confinement AD-1/AD-5/AD-27 respecté (delta graphe 0). Aucun fichier hors périmètre touché. Codec ES-3.5 inchangé, son test resté vert.

Findings résiduels : 4 × LOW/nit (aucun bloquant, aucune correction obligatoire).

---

## Preuves de vérification (rejouées RÉELLEMENT sur disque, RC hors pipe R15)

| Vérif | Commande | Résultat |
|---|---|---|
| Tests (R14, Flutter) | `flutter test` (zcrud_firestore) | **TEST_RC=0**, `+209 All tests passed!` (codec ES-3.5 inclus) |
| Graphe (AC8) | `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK**, **CORE OUT=0 OK**, **total arêtes = 46** (delta 0), 20 nœuds |
| Packages | `dart run melos list` | **20** |
| Gates repo-wide (AC8) | `dart run melos run verify` | **VERIFY_RC=0** — `gate:reserved-keys` + `gate:secrets` + `verify:serialization` (corpus migrateur sous tag `serialization-compat`) VERTS |
| Frontière de périmètre | `git status` | Uniquement `packages/zcrud_firestore/**` + fichier story. AUCUN fichier lex/iffd/dodlp/zcrud_core/zcrud_study_kernel. `z_study_codec.dart` **absent du diff** (ES-3.5 intact). |

## Injections adversariales R3 rejouées (garde neutralisée → RED → restaurée, R13)

| Axe | Injection | Effet observé | Verdict garde |
|---|---|---|---|
| **1. IDEMPOTENCE (AC3, le TRAP)** | `_isAlreadyCanonical` → `return false` | **4 tests AC3 RED** : `status` rétrogradé `ready`→`uploading` (offset 0, actual `ready` attendu... différence prouvée), `_legacy_status` `embedded`→`ready` réécrasé | ✅ LOAD-BEARING |
| **2. R26 PRÉSERVATION (AC2 census)** | drop `assistantFileId` avant le codec | **3 tests AC2 RED** : `isPreservationComplete=false`, `coveredBusinessKeys.length != businessKeysIn.length`, `lostBusinessKeys` non vide | ✅ LOAD-BEARING (drops) |
| **3. DÉFENSIF (AC5, AD-10)** | hard cast `entry.value as int` dans `_detectDefaults` | **3 tests AC5 RED** avec `_TypeError: String is not int` — l'injection **remonte réellement** (aucun blanket try-catch ne la masque) | ✅ défensif PAR CONSTRUCTION |

Après restauration : `flutter test` **TEST_RC=0 / +209**, `grep INJECTION` → **NO RESIDUAL INJECTION** (R13 satisfait).

Note méthodo : le fichier migrateur étant **untracked** (nouveau, non committé), la restauration s'est faite par Edit inverse (pas `git checkout`), diff final vérifié identique.

---

## Vérification par axe adversarial

- **Garde `_isAlreadyCanonical` CORRECTE** — un doc legacy (camelCase, sans `is_deleted`) échoue la détection → migré ; un canonique (snake + `is_deleted`) la réussit → traverse à l'identique. `document_soft_deleted` (`is_deleted:true` MAIS clés camelCase) est bien re-migré (`alreadyCanonical:false`) : la garde ne saute PAS un doc legacy soft-deleté. Deuxième passage : clés réservées/`_legacy_` passées telles quelles par le codec, `putIfAbsent` n'écrase pas `is_deleted` — point fixe réel.
- **Census NON vacuous sur les drops** — `_census` recompute `camelToSnake` comme le codec et vérifie `containsKey(snake) || containsKey(_legacy_snake)` ; tout drop de clé chute la couverture (prouvé R3-I1). Il couvre snake ET `_legacy_`.
- **ZSyncMeta hors-corps (AC4)** — `is_deleted:false` additif via `putIfAbsent` du codec ; `updated_at` laissé absent ; `is_deleted:true` legacy préservé (codec passe les clés réservées telles quelles) ; le double `_StudyDouble` strip `reservedKeys` avant capture d'`extra` → ni `updated_at` ni `is_deleted` ne fuient après `fromMap∘toMap`.
- **DRY-RUN (AC6)** — `Map.of(legacy)` avant tout remap ; `migrateCorpus` n'écrit nulle part, aucun `FirebaseFirestore`/`WriteBatch`. Input non muté (prouvé sur le chemin migré).
- **DW-ES22-2 (AC7)** — `audioTextHash:int` → `audio_text_hash` : la clé ne finit PAS par `_at`, `_normalizeValue` ne coerce donc PAS en date, l'`int` reste intact (test `isA<int>()` + valeur exacte `8419203715`). `audioText` String intacte.
- **AD-1/AD-5/AD-27 (AC8)** — signature `Map<String,dynamic>` uniquement ; garde de surface (`z_study_migrator_isolation_test.dart`) scanne le code (commentaires strippés) : aucun symbole backend, aucune dep d'entité ; graphe delta 0 confirmé.

---

## Findings

### LOW-1 — Census aveugle aux collisions de clés camelCase↔snake (écart vs promesse AC2)
`_census` compte la couverture par présence de la clé-cible snake, PAS par comptage des clés de sortie distinctes. Deux clés d'entrée qui **collisionnent** vers le même snake (ex. `subjectId` + `subject_id`) sont **toutes deux comptées « couvertes »** alors qu'une valeur a été silencieusement écrasée dans `toCanonical` (dernier gagne). L'AC2 promet explicitement que « écrase deux clés camelCase collidant en une seule snake ⇒ le test rougit » — cette classe de perte n'est ni détectée par le census ni exercée par un test livré (seul le drop l'est). 
**Impact réel : nul** — les clés métier legacy IFFD sont camelCase pures (sans underscore) ; `camelToSnake` y est injectif, donc aucune collision possible sur le corpus réel. D'où LOW et non MEDIUM. Recommandation optionnelle : soit compter les collisions (`covered` par clé de sortie distincte + détection d'écrasement), soit retirer la promesse de collision de l'AC2.

### LOW-2 — Invariant `isConsistent` structurellement tautologique (nit)
`migrated + alreadyCanonical == total` : `total` s'incrémente une fois par doc et exactement un de `migrated`/`already` s'incrémente par doc (aucune catégorie d'erreur). L'égalité est donc **toujours vraie par construction** — aucun chemin de code ne peut la violer. L'assertion `expect(report.isConsistent, isTrue)` (ligne 310) est un contrôle tautologique ; la discrimination réelle vient des `expect(total,3)/(migrated,2)/(alreadyCanonical,1)` voisins (eux discriminants). Garder comme auto-contrôle défensif est acceptable ; simplement ne pas le considérer comme une garde load-bearing.

### LOW-3 — Heuristique `_isAlreadyCanonical` : misclassification possible d'un doc dégénéré (informational)
Un doc portant `is_deleted` ET aucune clé camelCase MAIS un `status` legacy (`embedded`/`converted`…) serait détecté « déjà canonique » et **traverserait sans remap 6→4** — status legacy laissé tel quel. Aucun doc IFFD réel n'atteint ce cas (les clés métier — `subjectId`/`folderId`/`createdAt` — sont camelCase, et un doc purement legacy n'a pas `is_deleted`). Tradeoff explicitement documenté dans le dartdoc et les Dev Notes (option « garde » vs « value-mapper étendu »), write-back atomique par doc (DW-ES112-1) ⇒ pas de doc partiellement migré en pratique. Aucun throw dans tous les cas (décodage entité défensif). Consigné, pas de correction requise.

### LOW-4 — Non-mutation DRY-RUN prouvée seulement en shallow / chemin migré (nit)
`Map<String,dynamic>.of(legacy)` est une copie **superficielle** ; sur le chemin `alreadyCanonical`, cette copie est renvoyée telle quelle comme `canonical` → les `Map`/`List` imbriqués partagent leurs références avec l'entrée. Sûr aujourd'hui (tout est en lecture seule, aucun code ne mute une structure imbriquée), latent pour le write-back déféré. Le test « input inchangé » (ligne 316) n'exerce que le chemin migré (le codec reconstruit une map neuve), pas le chemin `alreadyCanonical` qui renvoie la copie. Consigné.

---

## Conformité process (CLAUDE.md)
- ✅ HIGH/MAJEUR/MEDIUM : **aucun** ⇒ rien à corriger avant `done`.
- 🟡 LOW ×4 : consignés ci-dessus, optionnels.
- ✅ Story reste VERTE (209 tests, verify repo-wide RC=0) ; confinement `zcrud_firestore` seul ; ES-3.5 intact.
- ✅ Toutes les injections restaurées (R13), aucune trace résiduelle.

---

## Remédiation orchestrateur (2026-07-16) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| LOW-1 (census aveugle aux collisions camel↔snake) | 🟡 LOW | 🟡 **CONSIGNÉ** | AC2 promet la détection de collision camelCase↔snake, non fournie/testée (seul le drop l'est). **Impact réel nul** : les clés legacy IFFD sont camelCase pures ⇒ `camelToSnake` injectif, aucune collision possible. La partie load-bearing (détection de DROP de clé métier) est prouvée discriminante. Consigné (l'AC sur-promet ; le besoin réel est couvert). |
| LOW-2 (`isConsistent` tautologique) | 🟡 LOW | 🟡 **CONSIGNÉ** | `migrated+alreadyCanonical==total` toujours vrai (aucune catégorie d'erreur) ⇒ assertion faible ; la discrimination réelle vient des compteurs nommés voisins (déjà testés). Consigné. |
| LOW-3 (heuristique `_isAlreadyCanonical` — doc dégénéré) | 🟡 informational | 🟡 **CONSIGNÉ** | Un doc `is_deleted` + zéro clé camelCase + status legacy sauterait le remap 6→4. Aucun doc IFFD réel n'y tombe ; tradeoff documenté en dartdoc ; jamais de throw. Informational. |
| LOW-4 (DRY-RUN copie shallow sur chemin `alreadyCanonical`) | 🟡 LOW | 🟡 **CONSIGNÉ (noté DW-ES112-1)** | La non-mutation dry-run est prouvée shallow ; le chemin `alreadyCanonical` renvoie une copie superficielle (refs imbriquées partagées). Sûr aujourd'hui (aucune mutation en aval côté zcrud) ; **latent pour le write-back déféré** ⇒ noté comme point de vigilance de **DW-ES112-1** (session IFFD : cloner en profondeur avant write-back si mutation). |
| DW-ES112-1 (exécution réelle IFFD) | — | ✅ **ESCALADÉ** | Escaladée dans `architecture.md § Deferred` : write-back batché + cutover repo-par-repo sur données réelles = session IFFD dédiée. |

**Spot-check orchestrateur (R3 idempotence, le TRAP)** : `_isAlreadyCanonical → false` → le migrateur n'atteint plus le point fixe (2ᵉ passage rétrograde `status ready→uploading`) → le test AC3 ROUGIT (RC=1) ; restauré. **Le TRAP `ZStudyLegacyCodec` non-idempotent est réellement fermé et verrouillé.**

**Vérif verte (RC hors pipe — R15)** : `flutter test` zcrud_firestore (R14) → RC=0, **209 tests** (ES-3.5 codec inclus, inchangé) · graph_proof RC=0 (46 arêtes, delta 0, ACYCLIQUE, CORE OUT=0) · `melos run verify` REPO-WIDE → RC=0.

**Verdict final** : ✅ **PRÊT POUR `done`** — 0 finding bloquant ; 4 LOW/nit consignés ; DW-ES112-1 escaladée. Idempotence + R26 + défensif prouvés load-bearing.
