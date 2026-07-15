# Code Review — ES-3.0 (registre préserve l'extension typée + immuabilité PATRON)

- **Story** : `es-3-0-registre-preserve-extension-immuabilite.md` — 16 ACs, Phase A (DW-ES14-2) / Phase B (DW-ES24-1).
- **Statut entrant** : `review`. Vérif verte repo-wide déjà rejouée par l'orchestrateur (generate/analyze/test/verify/gate/graph_proof).
- **Skill** : `bmad-code-review` (invoqué via le tool `Skill` — PAS de fallback disque ; skill chargé et suivi). Revue conduite par l'agent lui-même sur les 3 lentilles (Blind Hunter / Edge Case Hunter / Acceptance Auditor) — sous-agents imbriqués non lancés (contexte subagent), substance couverte directement.
- **Périmètre diff** : 26 fichiers, +672/−400. Packages : `zcrud_core` (registre + `ZDecodeContext` + helper immuabilité), `zcrud_generator`, `zcrud_firestore`, `zcrud_note`/`zcrud_document`/`zcrud_study_kernel` (5 canaux), `zcrud_exam`/`zcrud_flashcard` (registrars régénérés), `tool/reserved_keys_gate`, `scripts/ci`. Aucune écriture lex/iffd.

## VERDICT : **APPROVED** — aucun finding HIGH / MAJEUR / MEDIUM. 2 LOW (nit + hygiène de commit).

Les deux dettes de fond sont soldées avec **pouvoir discriminant OBSERVÉ** (rouge provoqué réel), la surface publique est strictement **additive**, `CORE OUT=0` tient, et l'immuabilité est inconditionnelle et couverte par entité.

---

## Injections R3 rejouées RÉELLEMENT (restauration par édition ciblée — R13, jamais `git checkout`)

### Injection #1 — neutraliser le threading du contexte dans `ZcrudRegistry.decode`
`zcrud_registry.dart:189-195` → remplacé le corps par `return codec.fromMap(map);` (tear-off nu).

- **Core** `z_decode_context_test.dart` : **ROUGE** — `AC3` (le slot revient TYPÉ) et `AC4` (sourceRegistry honoré) échouent (`Actual: _OpaqueExt`). `+3 -2`.
- **Gate** `reserved_keys_test.dart --plain-name DW-ES14-2` : **ROUGE** — `smart_note : extension revient TYPÉ ZNoteAudio (DISCRIMINANT)` échoue, plus les 2 tests du canal `source` (`Actual: {zz_payload: null}` = la perte ES-2.0 revient). `+4 -3`.
- **Restauration** : édition ciblée à l'identique → `z_decode_context_test.dart` **+5 All tests passed**, groupe DW-ES14-2 **+7 All tests passed**. `grep R3-INJECTION` = 0.

**⇒ Le typage registre de l'extension est un test à POUVOIR DISCRIMINANT réel, pas un faux vert.**

### Injection #2 — neutraliser l'accesseur immuabilisant de `ZDocumentLearningInfo.qualityByPage`
`z_document_learning_info.dart:181` → `get qualityByPage => _qualityByPage;` (slot brut).

- **Document** `dw_es24_1_immutability_test.dart` : **ROUGE** — `#1 qualityByPage ⇒ UnsupportedError` échoue (`Actual: returned 9`) **ET** `#2 ZDocumentReadingState.learning (compose #1)` échoue aussi. `+2 -2`.
- **Restauration** : édition ciblée → grep résidu = 0.

**⇒ Non seulement l'accesseur mord, mais la preuve de COMPOSITION (`learning` → son `qualityByPage`) est réellement transitive, pas un doublon décoratif.**

---

## Vérification des axes prioritaires (OBSERVÉ vs LU)

### (1) Extension TYPÉE préservée — le cœur DW-ES14-2 — **[OBSERVÉ, discriminant]**
`registry.decode('smart_note', {extension: audioPayload})` avec contexte câblant `ZNoteAudio.fromJsonSafe` rend `extension is ZNoteAudio == true` (url/path/textHash corrects) et `encode` réémet le payload à l'identique (`encoded['extension'] == audioPayload`). Le retrait du threading fait retomber `ZOpaqueNoteExtension` (injection #1). Chemin défensif (LU + core OBSERVÉ) : parser `null`/inconnu → opaque verbatim ; parser qui **throw** → absorbé par `ZExtension.guard` **au niveau de la vraie entité** (`z_smart_note.dart:_decodeExtension`, `ZExtension.guard<ZExtension?>(() => parser(map))`) — jamais de throw (AD-10). Core `AC5` OBSERVÉ vert avec un parser levant `StateError`.

### (2) Surface publique ADDITIVE — non cassée — **[OBSERVÉ + LU]**
- `decode(String, Map)` / `encode(String, Object)` : **signatures INCHANGÉES** (`zcrud_registry.dart:189,202`). Threading interne conditionnel (`fromMapWithContext != null`).
- `ZcrudRegistry()` **sans** contexte : `_decodeContext == null` → codec sans variante contexte → `fromMap`/`toMap` nus. Core `AC1` OBSERVÉ vert (« decode identique à la voie historique, opaque »).
- `ZModelCodec.fromMapWithContext`/`toMapWithContext` : ajouts `null` par défaut, `const` préservé.
- Entités : le champ public `content`/`qualityByPage`/`sectionOrders`/`byQuality` devient un **getter** de même type — source-compatible en Dart ; ctor **`const` préservé** (paramètre nommé conservé, slot brut privé assigné en liste d'initialisation). `AC13` OBSERVÉ (`const ZSmartNote()` compile, `const note` dans les tests).
- Call-site firestore `registry.decode(kind, map)` **INCHANGÉ** (`firebase_z_repository_impl.dart:194`).
- `==`/`hashCode` : **tous lus via l'accesseur public** (LU — `z_smart_note.dart:483,493`, `z_document_learning_info.dart:252,268`, `z_folder_contents_order.dart:397,404`, `z_study_session_result.dart:180,184`), donc une instance née du ctor `const` et une relue du store comparent la **même vue logique** — cohérence `==`/`hashCode` profonde préservée (AC13).

**⇒ Un consommateur (DODLP/lex) qui clone au tag sans régénérer compile et se comporte à l'identique s'il ne câble pas de contexte. Risque #1 de la story : NEUTRALISÉ.**

### (3) AD-1 — CORE OUT=0 — **[OBSERVÉ]**
`z_decode_context.dart` importe **uniquement** `z_extension.dart` + `z_source_registry.dart` (cœur). `z_immutable_view.dart` importe **uniquement** `dart:collection`. Aucun import satellite/Firebase. Les 4 entités satellites importent `package:zcrud_core/domain.dart` — **sens de dépendance autorisé** (satellite→cœur). Aucune arête sortante ajoutée au cœur.

### (4) Immuabilité inconditionnelle par entité — **[OBSERVÉ]**
Les 5 canaux ont un test discriminant vert (document #1/#2, note #3, kernel #4/#5), y compris le niveau imbriqué (`content[0]['insert']=…`, `sectionOrders`). Injection #2 confirme le pouvoir. Patron uniforme (slot brut privé + accesseur `zUnmodifiable*`), `const` préservé, zéro `assert`, `fromMap` non-throw. Zéro-copie chemin chaud OBSERVÉ (`AC14` : `identical(relu.content, relu.content)` vert).

### (5) Clause mensongère — **[OBSERVÉ]**
Supprimée de `firebase_z_repository_impl.dart` (grep : plus de « n'utilise pas le slot extension » / tableau « DÉTRUIT »). La dartdoc réécrite documente `fromRegistry` comme **voie recommandée** (l.136-147) et décrit correctement la survie verbatim `ZOpaqueNoteExtension`. Clause = dartdoc pure (aucun comportement runtime retiré) ; round-trip registre marche sans elle (tests firestore verts par l'orchestrateur). Aucune régression.

### (6) Gate AST étendu — **[LU]**
`gate_reserved_keys.dart` généralise le cas `_extra` → tout slot privé backé par un accesseur concret, keyé sur la **surface publique** (`content`/`section_orders`), portée minimale préservée (`_extra`/`_extension` exclus ; champ privé sans getter reste keyé sur `_x`). Logique correcte. `prove_gates` 41 OK / 0 FAIL rejoué par l'orchestrateur. (Non re-provoqué en rouge par moi — les 2 injections R3 exigées ont porté sur les canaux à plus fort risque.)

### (8) Générateur context-aware — **[OBSERVÉ sur les .g.dart]**
`_contextShapeOf` détecte sur l'AST (R5, jamais regex) les params nommés `extensionParser`/`sourceRegistry` de `fromMap`/`toMap`. Émissions cohérentes vérifiées : `ZFlashcard` → `fromMapWithContext` (source+extension) **+** `toMapWithContext` (source) ; `ZSmartNote`/`ZDocumentReadingState` → `fromMapWithContext` (extension seule). Closure `context!.extensionParser!('$kind', json)` correctement gardée par le ternaire `context?.extensionParser == null`. 12 registrars extensibles régénérés (les 4 non-extensibles restent identiques = à jour, pas périmés → `codegen-distribution` OK).

### (9) Périmètre — **[OBSERVÉ]**
Diff limité aux packages cœur/generator/firestore/note/document/kernel/exam/flashcard + gate + scripts. Aucune écriture lex/iffd.

---

## Findings

### LOW-1 (nit, correctness théorique) — `zUnmodifiableJsonMapList` / `zUnmodifiableMapOfLists` : le raccourci d'idempotence fait confiance à « top-level gelé ⟹ profond gelé »
`z_immutable_view.dart:68` — l'idempotence ne vérifie que les ops de 1er niveau sont `UnmodifiableMapView`, pas que leurs valeurs imbriquées le sont. **Scénario** : `ZSmartNote(content: [UnmodifiableMapView(op) with a mutable nested List])` construit non-const → l'accesseur renverrait cette liste telle quelle sans re-geler le niveau imbriqué. **Non atteignable via les producteurs réels** : le seul chemin qui stocke des ops `UnmodifiableMapView` est `_freeze`→`_deepJsonMap` (qui gèle en profondeur), et un ctor appelé avec des littéraux plats passe par le chemin de gel profond (non-idempotent). Défaut purement théorique (entrée forgée). **Statut : consigné, non bloquant** (corriger exigerait un scan profond à chaque lecture — coût non justifié vs risque nul en pratique ; AC14 privilégie le zéro-copie).

### LOW-2 (hygiène de commit — rappel orchestrateur, PAS un défaut de code) — `pubspec.lock` racine + `example/pubspec.lock` modifiés dans l'arbre de travail
Le CLAUDE.md impose d'**exclure** les `pubspec.lock` du commit d'epic. `sprint-status.yaml` apparaît aussi modifié (territoire orchestrateur — le dev ne l'a pas touché dans le code). À vérifier au `git add` sélectif du commit d'epic. Aucune action sur le code de production.

---

## Conclusion

Story **ES-3.0** : **APPROVED pour `done`** après vérif verte repo-wide (déjà rejouée). Les deux dettes 🔴 (DW-ES14-2 destructrice avant store, DW-ES24-1 patron d'immuabilité) sont soldées avec pouvoir discriminant réel et OBSERVÉ. Aucun finding HIGH/MAJEUR/MEDIUM à corriger avant `done`. Les 2 LOW sont consignés (LOW-1 non atteignable, LOW-2 = hygiène de commit à appliquer par l'orchestrateur).
