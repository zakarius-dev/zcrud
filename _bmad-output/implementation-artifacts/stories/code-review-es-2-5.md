# Code-review adversariale — Story ES-2.5 (`ZDocumentAnnotation` / `ZAnnotationBounds`)

- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (PAS de fallback disque — le skill s'est chargé normalement).
- **Cible** : working-tree non committé (fichiers ES-2.5), restaurations par **édition ciblée** (jamais `git checkout`).
- **Date** : 2026-07-15. **Statut story** : `review`.
- **Effort** : high. **Modèle** : claude-opus-4-8.

## Verdict

**APPROUVÉ AVEC RÉSERVE** — aucun finding HIGH/MAJEUR. Les 15 ACs sont implémentés avec **pouvoir discriminant OBSERVÉ** (clamp `[0,1]`, AD-19, défensif AD-10, round-trip zéro-perte, gate volets A/B/(g)/(h)/(j)/(k)). **Une réserve MEDIUM** : la protection de l'invariant `[0,1]` du VO `ZAnnotationBounds` repose sur la **CONVENTION** (`hide` + promotion d'instance), sans **aucune machine** (ni gate, ni test) qui rougisse si elle est retirée — le motif dominant (« filet déclaré valide sur son existence, pas sur son pouvoir discriminant observé »), ici DANS le filet AC13 lui-même, pour le VO.

Baseline vérifiée sur disque : `dart test` (zcrud_document) **166 OK** ; gate `reserved-keys` **RC=0** ; `graph_proof` **ACYCLIQUE + CORE OUT=0** (30 arêtes) ; domaine `zcrud_document` **zéro** import `dart:ui`/`flutter` (les occurrences sont en dartdoc). Après toutes les injections, tree **restauré à l'identique** (`git diff --stat` : barrel +8, registrars +150, rien d'autre ; aucune sonde résiduelle).

---

## Findings

### MEDIUM-1 — L'invariant `[0,1]` du VO `ZAnnotationBounds` n'est tenu par AUCUNE machine ; le filet AC13 est POWERLESS pour le VO (motif dominant, DANS le filet)

- **Fichiers** : `packages/zcrud_document/lib/zcrud_document.dart:65` (`hide ZAnnotationBoundsZcrud`) ; `packages/zcrud_document/test/z_annotation_bounds_test.dart:156-164` (groupe « AC13 ») ; `scripts/ci/gate_reserved_keys.dart:1110-1180` (règle (h), scopée `ZExtensible`).
- **Catégorie** : `false-net` / verification-power (motif récidivant 11×).

**Ce qui est PROMIS (AC13)** : « Un test prouve que `ZDocumentAnnotationZcrud`/`ZAnnotationBoundsZcrud` **ne sont pas exportés** par le barrel ». Raison d'être : le `copyWith`/`toMap` GÉNÉRÉ, atteignable **explicitement** depuis l'API publique, **CONTOURNE** `sanitizeCoord` (leçon exacte `ZDocumentViewerPrefs`/M2).

**Ce qui est LIVRÉ** :
- Pour `ZDocumentAnnotation` (**`ZExtensible`**) : la règle **(h)** du gate PROTÈGE réellement (observé ci-dessous, RC=1). Le test AC13 per-entité, lui, ne prouve que l'accessibilité INTERNE — mais le gate couvre.
- Pour `ZAnnotationBounds` (**VO NON-`ZExtensible`**) : **NI la règle (h)** (scopée aux seules classes `ZExtensible` — `if (!index.isExtensibleDecl(d)) continue;`) **NI aucun test** n'exige le `hide`. Le seul test AC13 du VO (`z_annotation_bounds_test.dart:157`) importe l'extension par le chemin **interne** (`show ZAnnotationBoundsZcrud`) et prouve qu'elle reste accessible EN INTERNE — il ne peut structurellement PAS échouer si le barrel cesse de la masquer.

**Scénario d'échec concret (régression future silencieuse)** : un développeur retire `hide ZAnnotationBoundsZcrud` du barrel. Aucun signal rouge. Un consommateur écrit alors, via l'API **publique** :
```dart
ZAnnotationBoundsZcrud(const ZAnnotationBounds(x: 0.5)).copyWith(x: 5.0, y: -3.0)
// ⇒ x == 5.0, y == -3.0 : invariant [0,1] CONTOURNÉ, et toMap() réémet 5.0
```

**PREUVE OBSERVÉE (rejouée, restaurée par édition ciblée)** :
1. Retrait réel de `hide ZAnnotationBoundsZcrud` → `dart run scripts/ci/gate_reserved_keys.dart` = **RC=0 (VERT)** ; `[gate:reserved-keys] OK`. Le VO exporté ne rougit RIEN.
   - Contraste : retrait de `hide ZDocumentAnnotationZcrud` (l'entité `ZExtensible`) → **RC=1**, `[gate:reserved-keys] ÉCHEC : (h) EXTENSION GÉNÉRÉE EXPORTÉE : ZDocumentAnnotationZcrud … alors que ZDocumentAnnotation est ZExtensible`. La machine existe pour l'entité, PAS pour le VO.
2. Sonde publique (barrel seul, `hide` retiré) : `ZAnnotationBoundsZcrud(b).copyWith(x: 5.0, y: -3.0)` → **`x==5.0`, `y==-3.0`**, `toMap()['x']==5.0` — test **PASSE** (donc le contournement est réel et atteignable publiquement).

**Classification** : **dette de PATRON pré-existante**, identique à `ZDocumentViewerPrefs` (ES-2.1/M2), **PAS introduite** par ES-2.5 sur le plan de la règle (h). MAIS ES-2.5 (a) **instancie un nouveau** VO à invariant non protégé par machine, et (b) **a formulé en AC13 une promesse de test** que le livrable ne tient pas pour le VO. C'est donc à la fois une dette de patron ET un trou de filet local.

**Recommandation** (argumentée) :
- Une **garde in-story en `dart test` pur n'est PAS proprement faisable** : un test ne peut pas asserter l'ABSENCE d'un symbole d'un barrel (importer `show ZAnnotationBoundsZcrud` depuis le barrel masqué **ne compile pas** — l'échec est un échec de build, pas un rouge de test observable/portable). La bonne machine est **statique/AST**, i.e. **étendre la règle (h)**.
- Étendre (h) à **tout** `@ZcrudModel` NON-`ZExtensible` serait FAUX (`ZChoice`, `ZSuggestedTag` sont des VO SANS invariant — leur `copyWith` généré n'a rien à contourner ; les masquer n'a aucune valeur). Le signal machine correct d'« invariant à protéger » = **l'entité déclare son propre `copyWith`/`toMap` d'INSTANCE** (promotion), ce que font `ZAnnotationBounds` ET `ZDocumentViewerPrefs`, et que ne font PAS `ZChoice`/`ZSuggestedTag`. (h) étendue = « NON-`ZExtensible` `@ZcrudModel` déclarant un `copyWith`/`toMap` d'instance ⇒ son extension générée doit être `hide` ».
- Comme le correctif touche **la machinerie de gate partagée** ET **ferme du même geste le trou pré-existant `ZDocumentViewerPrefs`**, il relève d'une **décision transverse** → **entrée au ledger DW (proposé `DW-ES25-1`) et STATUÉ EN RÉTRO ES-2**, pas d'un patch isolé dans la seule story ES-2.5. **MEDIUM reporté, justifié par écrit** (présent document), conformément à la règle « un MEDIUM reporté doit être justifié ». L'état LIVRÉ reste correct (le `hide` EST présent : l'invariant tient aujourd'hui) — le risque est une régression future non détectée, d'où MEDIUM et non HIGH.

### LOW-1 — Helper `_asStringMap` du domaine dupliqué avec `_$asStringMap` généré

- **Fichier** : `packages/zcrud_document/lib/src/domain/z_document_annotation.dart:388-399`.
- La factory `_decodeExtension` utilise un top-level `_asStringMap` **réécrit à la main**, alors que le part généré (`z_document_annotation.g.dart:149`) fournit un `_$asStringMap` **identique**, accessible depuis la même bibliothèque (`part of`). Duplication inoffensive (comportement identique), mais code mort évitable. Précédent identique probable dans les sœurs ES-2.1. **Nit** — consignable, non bloquant.

---

## Vérifications adversariales menées (OBSERVÉ, sortie brute rejouée)

| # | Injection R3 (édition ciblée) | Attendu | Observé | RC |
|---|---|---|---|---|
| A | `hide ZDocumentAnnotationZcrud` retiré (barrel) | gate ROUGE (h) | `ÉCHEC : (h) EXTENSION GÉNÉRÉE EXPORTÉE : ZDocumentAnnotationZcrud … ZExtensible` | **1** |
| B | `sanitizeCoord => raw` (clamp neutralisé) | tests ROUGES, 2 frontières + per-rect | fromMap `x:5→Expected 1.0/Actual 5.0` ; `Inf→Expected 0.0/Actual Infinity` ; copyWith `x:5→1.0/5.0` ; `sanitizeCoord(5.0)` direct `1.0/5.0` ; **rects per-élément** `Expected (1.0,0.0,…)/Actual (2.0,-1.0,…)` | **1** |
| C | `...ZSyncMeta.reservedKeys` retiré (`_reservedKeys`) | gate ROUGE (volet B) + test ROUGE | gate `ÉCHEC : ajoutez ...ZSyncMeta.reservedKeys à _reservedKeys (AD-19.1)` ; test `Actual: {'updated_at': …, 'is_deleted': false}` fuit dans `extra` | **1** |
| D | voie `ctor` retirée de `kExtraWriters['document_annotation']` | gate ROUGE (j) | `ÉCHEC : (j) VOIE D'ÉCRITURE NON SONDÉE : ZDocumentAnnotation.ctor … n'est PAS câblée` | **1** |
| — | **DETTE (h) sur le VO** : `hide ZAnnotationBoundsZcrud` retiré | gate ? | **RC=0 VERT** (dette confirmée, cf. MEDIUM-1) | **0** |

Après chaque injection : `git diff --stat` reramené à la délivrance (barrel +8, registrars +150), aucune sonde résiduelle.

**Clamp `[0,1]` à pouvoir discriminant** : PROUVÉ sur les DEUX frontières (`fromMap` ET `copyWith`) et **à travers `rects` per-élément** (chemin `listModel` → `ZAnnotationBounds.fromMap`), écarts observés 5.0→1.0, -3.0→0.0, NaN/Inf→0.0. Pas un golden fortuit.

**AD-19 (cœur FR)** — LU + OBSERVÉ : `ZDocumentAnnotation` ne déclare NI `updatedAt`/`isDeleted` NI `updated_at`/`is_deleted` inline (rejet du piège lex le plus aigu — `updatedAt` = clé LWW) ; `$FieldSpecs ∩ ZSyncMeta.reservedKeys == {}` (test AC6, vert) ; `createdAt` sous `created_at` (clé distincte non réservée) ; `kLegacyUpdatedAtMirrors` **inchangé** (`{study_folder, flashcard}`, `document_annotation` absent).

**AD-10 défensif** — OBSERVÉ (tests baseline verts) : `fromMap(const {})` sûr (2 entités) ; map polluée (`kind:'zzz'`, `bounds:'not-a-map'`, `rects:[{x:2},'garbage']`, `page:-4`) → `highlight`, `(0,0,0,0)`, `page 1`, 1 rect survivant clampé `(1.0,0.0,0.3,0.4)`, jamais de throw ; map intégralement corrompue → défauts sûrs partout.

**AC7 anti-vacuité / ctor pollué** — OBSERVÉ : `ZDocumentAnnotation(..., extra:{'updated_at','is_deleted','zz_ok'}).extra` STRIPPE les réservées, conserve `zz_ok` ; clé inconnue survit `fromMap+toMap` ; `x == fromMap(x.toMap())` (round-trip profond, ≥2 rects distincts + clé inconnue + extension typée).

**Domaine pur / graphe** — OBSERVÉ : `graph_proof` ACYCLIQUE + CORE OUT=0 ; imports réels de `z_annotation_bounds.dart` / `z_document_annotation.dart` / `_kind.dart` = uniquement `zcrud_annotations`, `zcrud_core/{domain,edition}.dart`, fichiers locaux. Zéro `dart:ui`/`flutter`.

**Périmètre** — OBSERVÉ : `git diff --stat HEAD` ne touche que `packages/zcrud_document/**` et `tool/reserved_keys_gate/lib/src/registrars.dart` ; aucun widget, aucun repository, aucune écriture `zcrud_core`, `sprint-status` non touché.

---

## Décision de triage

- **HIGH/MAJEUR** : 0.
- **MEDIUM** : 1 (MEDIUM-1) — **reporté et justifié par écrit** en dette de patron transverse `DW-ES25-1` (statuer en rétro ES-2 ; correctif = étendre la règle (h) aux `@ZcrudModel` NON-`ZExtensible` déclarant un `copyWith`/`toMap` d'instance, fermant du même geste le trou pré-existant `ZDocumentViewerPrefs`). L'état livré reste correct (`hide` présent).
- **LOW** : 1 (LOW-1, duplication `_asStringMap`) — consigné, non bloquant.

La story peut passer `done` : aucun finding bloquant, MEDIUM justifié en dette, tree vert restauré. **Ne PAS toucher** le code de production ni le sprint-status depuis cette revue.

---

## Remédiation orchestrateur (post-revue)

**MEDIUM-1 — le vrai correctif (machine) est REPORTÉ, le faux-vert LOCAL est CORRIGÉ.**

1. **Correctif machine reporté en `DW-ES25-1`** (consigné au sprint-status) : étendre la règle (h) aux VO à invariant est **transverse et exige un design R4**. Le signal naïf « déclare un `toMap`/`copyWith` d'instance » mange les VO **exportables SANS invariant** (`ZChoice`, `ZSuggestedTag` — exportés sans `hide`, validé ES-2.3), produisant un faux positif. Distinguer un VO-à-invariant d'un VO-exportable par AST n'est pas trivial ⇒ prototyper avant de figer, en rétro ES-2. Conforme CLAUDE.md (MEDIUM reporté, justifié par écrit).
2. **Faux-vert LOCAL corrigé dans le périmètre** (`z_annotation_bounds_test.dart`, groupe AC13) : le test PRÉTENDAIT prouver le masquage du barrel (« Ce test PROUVE justement ce masquage ») alors qu'il utilise un import INTERNE et passerait même sans le `hide`. Réécrit pour être **honnête** : il ne revendique plus la garde de surface, explicite que la garde MACHINE fait défaut (règle (h) scopée `ZExtensible`) et pointe vers `DW-ES25-1`. Le mensonge de l'artefact de vérification (motif dominant) est retiré ; l'assertion comportementale reste verte (14 tests bounds passent).

**Vérif re-scellée** : test bounds 14 OK · analyze `zcrud_document` = 2 `info` PRÉ-EXISTANTS d'ES-2.1 (`z_document_viewer_prefs_test.dart`, non touché), `melos analyze` RC=0.

**LOW-1** (`_asStringMap` dupliqué) : nit conforme au patron, consigné, non corrigé.

**Verdict final : ✅ 0 finding bloquant.** MEDIUM-1 → dette machine `DW-ES25-1` + faux-vert local neutralisé ; LOW-1 consigné.
