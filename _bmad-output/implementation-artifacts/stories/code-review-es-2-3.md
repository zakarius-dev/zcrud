# Code Review — Story ES-2.3 : Tags de flashcard first-class (`ZFlashcardTag` / `ZSuggestedTag`)

- **Skill réel invoqué** : `bmad-code-review` (via le tool `Skill`, succès — **pas** de fallback disque).
- **Cible** : working-tree ES-2.3 (baseline `709406d`), fichiers listés dans la File List de la story.
- **Date** : 2026-07-14
- **Revue menée** : lecture intégrale des 4 fichiers domaine + 2 `.g.dart` + barrel + registrars + surface-guard + 2 fichiers de test ; **re-jeu réel** de 2 des 5 injections R3 ; confrontation de la décision D7 au **code réel du gate**.

## Verdict global : ✅ **APPROUVÉ — 0 HIGH · 0 MAJEUR · 0 MEDIUM · 1 LOW**

Implémentation d'une qualité remarquable. Le patron `extra` ES-2.2b est copié **intégralement** du jumeau `ZStudySessionConfig`/`ZStudyFolder` (ctor `const` brut, accesseur normalisant seul point traversé, garde partagée `fromMap`/`copyWith`, `toMap` étalant l'accesseur, égalité profonde). `remapColorKey` **compose** `ZColorPalette.resolveKey` sans dupliquer le hash. `colorKey` est brut (D4). Les filets ont un **pouvoir discriminant observé** (les 2 injections rejouées rougissent avec le bon message). La décision D7 (dérogation `hide` sur `ZSuggestedTag`) est **CORRECTE**, confirmée sur le code réel du gate.

---

## Ce que j'ai OBSERVÉ (rejoué sur disque)

### Injection R3 (j) — retrait de la voie `ctor` de `kExtraWriters['flashcard_tag']` ⇒ **RC=1**
Sortie brute :
```
[gate:reserved-keys] ÉCHEC : (j) VOIE D'ÉCRITURE NON SONDÉE : `ZFlashcardTag.ctor`
(packages/zcrud_study_kernel/lib/src/domain/z_flashcard_tag.dart) prend un paramètre
`extra` — c'est une **voie d'écriture PUBLIQUE** du slot AD-4 — mais elle n'est PAS
câblée dans le harnais (`kExtraWriters['flashcard_tag']` / `ZManualProbe.writes`).
```
✅ Filet **porteur** : la voie `ctor` (polluante, `const`, celle que le harnais ne sondait pas historiquement — HIGH-1/HIGH-2 d'ES-2.2b) est bien couverte et son retrait est détecté par la règle AST dérivée du disque. Restauration → gate VERT (diff vide).

### Injection R3 (h) — retrait de `hide ZFlashcardTagZcrud` du barrel kernel ⇒ **RC=1**
Sortie brute :
```
[gate:reserved-keys] ÉCHEC : (h) EXTENSION GÉNÉRÉE EXPORTÉE : `ZFlashcardTagZcrud`
est exposée par le point d'entrée public
`packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart`
(`export 'src/domain/z_flashcard_tag.dart';` sans `hide`), alors que `ZFlashcardTag`
est `ZExtensible`.
    ZFlashcardTagZcrud(e).copyWith(...)   ⇒ extra / extension / canaux DÉTRUITS
```
✅ Filet **porteur** : la politique `hide` de l'extension générée d'une entité `ZExtensible` est tenue par machine (règle (h)). Restauration → gate VERT.

> ⚠️ **Note de procédure (honnêteté R9)** : pour restaurer entre injections j'ai d'abord utilisé `git checkout <fichier>`, qui a reverté **l'intégralité** des modifications ES-2.3 non committées de `registrars.dart` et du barrel (elles vivent dans le working-tree, pas dans HEAD). J'ai immédiatement **reconstruit** les deux fichiers à leur état ES-2.3 exact (re-jeu ciblé des 6 ajouts). Vérification de non-régression : `git diff --stat` rend `barrel +16 / registrars +40` (**identique** aux deltas d'origine, 0 suppression) et `gate:reserved-keys` **VERT** (100 tests) + surface-guard vert. Aucun code de production n'a été laissé altéré.

### Baseline & couverture
- `gate:reserved-keys` **VERT** — 100 tests, message final `[gate:reserved-keys] OK`, couverture « 11 registrars sur disque / 11 câblés / 17 voies (j)/(k) ».
- Absence de `crypto`/`Color`/palette-en-dur : `grep` sur `packages/zcrud_study_kernel/lib/` ⇒ **toutes** les occurrences `crypto`/`sha256`/`Color`/`flutter` sont en **dartdoc explicatif** (rejets documentés) ; `pubspec.yaml` du kernel = **`{zcrud_core, zcrud_annotations}`** uniquement.

---

## Ce que j'ai LU (revue statique confirmée)

### D7 remis en cause par le dev — **JUSTIFIÉ** (dérogation correcte, pas un finding)
Le dev a exporté `ZSuggestedTag` **sans** `hide ZSuggestedTagZcrud` (contre la prescription littérale D7/AC10). J'ai confronté son raisonnement au **code réel** :
- **(a)** `ZSuggestedTag` (`z_suggested_tag.dart` l.37) n'a **ni `extra` ni `extension`** : `class ZSuggestedTag` — pas `ZEntity`, pas `ZExtensible`, deux champs `String` scalaires. ✅
- **(b)** Son `copyWith`/`toMap` généré (`z_suggested_tag.g.dart` l.180-197) couvre **tous** les champs (`title`, `color_key`) — rien à détruire. ✅
- **(c)** La règle (h) du gate (`scripts/ci/gate_reserved_keys.dart` `_checkGeneratedExtensionsHidden`) itère **exclusivement** les déclarations vérifiant `index.isExtensibleDecl(d)` (`continue` sinon). `ZSuggestedTag` n'étant pas `ZExtensible`, elle est **hors** du périmètre de (h). ✅ **Confirmé par l'injection (h) elle-même** : elle ne rougit que sur `ZFlashcardTagZcrud`, jamais sur `ZSuggestedTagZcrud`.
- **Précédent** : `ZChoice` (value object jumeau) est exporté sans `hide` dans le barrel flashcard — cohérence du corpus.

⇒ Dérogation **fondée et documentée** (barrel l.68-77, Completion Notes). Le `hide` prescrit aurait inutilement amputé le `toMap`/`copyWith` publics du DTO.

### AC7 anti-vacuité — RÉEL (pas un « passe » en vidant `extra`)
`z_flashcard_tag_test.dart` l.163-190 : la sonde de store `{...,'updated_at','is_deleted','zz_cle_inconnue':'gardee'}` donne `extra['zz_cle_inconnue']=='gardee'` **et** `toMap()['zz_cle_inconnue']=='gardee'`, `extra.keys ∩ ZSyncMeta.reservedKeys == {}`, `toMap()` ne réémet **ni** `updated_at` **ni** `is_deleted`. La clé métier survit — anti-vacuité tenue.

### AC8 pollution ctor — NEUTRALISÉE
`ZFlashcardTag(title:'t', extra:{'is_deleted':true,'ok':1}).extra` ⇒ pas de `is_deleted`, `ok==1` (l.202-212), et `f == fromMap(f.toMap())`. L'accesseur `extra => zNormalizeExtra(_extra, _reservedKeys)` (`z_flashcard_tag.dart` l.143) est bien **le seul point traversé** ; `_extra` n'est lu nulle part ailleurs (vérifié : `toMap`, `==`, `hashCode` passent tous par l'accesseur `extra`). Aucun `assert` dans le ctor `const` (AD-10 respecté).

### D3/AC3 `remapColorKey` — délègue, jamais de hash dupliqué
`remap_color_key.dart` l.56-61 : clé connue → identité ; sinon `palette.resolveKey(seed)` — **aucun** hash/modulo local (R6). `remap_color_key_test.dart` : vecteurs golden figés (`'Droit Douanier'→tertiary`), matrice `∀(raw,seed)` ⇒ résultat ∈ `keys`, jamais de throw, deux palettes → mappings distincts (palette injectée), test dédié R3 n°5 (`hash: zFnv1a32` cible). Solide.

### AC6/AD-19 — zéro clé de sync, prouvé par machine
`_reservedKeys` (l.215-219) inclut `...ZSyncMeta.reservedKeys` ; tests l.242-262 : `$ZFlashcardTagFieldSpecs ∩ ZSyncMeta.reservedKeys == {}`, idem `$ZSuggestedTagFieldSpecs` (l.307-310), `$…TimestampFields ∩ reservedKeys == {}`. `kLegacyUpdatedAtMirrors` **inchangé** (`{study_folder, flashcard}`, registrars l.245).

### AC5 `orphanTagIds` — pur, neutre, total
`tag_referential_integrity.dart` : `LinkedHashSet` (ordre préservé), dédoublonné, `existingTagIds.toSet()` pour l'appartenance, aucun import satellite, aucun throw. Correct.

### AC15 périmètre
`git diff --stat` : seuls `zcrud_study_kernel/` (domaine + `.g.dart` + barrel + tests), `zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (+7, allowlist), `tool/reserved_keys_gate/lib/src/registrars.dart` (+40). **Aucune** ligne de `zcrud_core`/`zcrud_document`/`zcrud_note`/`zcrud_mindmap`/`zcrud_firestore`. `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` **non modifié** (nouveaux symboles en allowlist, non hidden — cohérent avec la surface-guard l.34-50). lex/iffd intouchés.

---

## Findings

### LOW-1 — `remapColorKey` normalise la casse à l'entrée mais `resolveKey` ne la normalise pas (asymétrie théorique)
- **Fichier** : `packages/zcrud_study_kernel/lib/src/domain/remap_color_key.dart:54-56`
- **Observation** : `remapColorKey` fait `raw = (rawColorKey ?? '').trim().toLowerCase()` puis `palette.keys.contains(raw)`. `ZColorPalette.resolveKey` (fallback) compare en **casse exacte**. Pour une palette dont les clés ne sont **pas** en minuscules (ex. `keys: ['Blue']`), une `rawColorKey: 'Blue'` ne satisfait pas le `contains(raw='blue')` en tête de `remapColorKey` et transite par la voie de remap — où `resolveKey('blue')` re-teste en casse exacte, échoue aussi, et **remappe par hash** au lieu de rendre l'identité.
- **Scénario d'échec concret** : `remapColorKey(palette: ZColorPalette(keys:['Alpha','Beta'], fallbackKey:'Alpha'), rawColorKey:'Alpha')` ⇒ ne rend **pas** `'Alpha'` par identité mais une clé hashée (toujours ∈ `keys`, donc **pas** de bug de contrat — le résultat reste valide, seulement contre-intuitif).
- **Impact réel** : **nul** en pratique — la convention du corpus (et `ZColorPalette.defaultStudy`) est **clés minuscules symboliques** ; l'invariant « résultat ∈ `keys`, déterministe, jamais de throw » est **préservé** dans tous les cas.
- **Recommandation** : soit documenter en dartdoc que **les clés de palette sont supposées minuscules** (le `toLowerCase()` d'entrée en fait une pré-condition implicite), soit retirer le `toLowerCase()` pour aligner strictement le test d'identité sur celui de `resolveKey`. **Non bloquant** — à consigner, correction optionnelle.

### Nit (non compté) — helper `_asStringMap` dupliqué
`z_flashcard_tag.dart:253` définit un `_asStringMap` privé (utilisé par `_decodeExtension`) alors que le `.g.dart` porte déjà `_$asStringMap`. Duplication **conforme au patron de référence** (`ZStudyFolder`/`ZFlashcard` font de même — le domaine ne peut pas voir les helpers privés du part au niveau top-level sans collision). Harmless, aucun geste requis.

---

## Conformité AD (rappel des 16, celles qui mordent ici)
- **AD-3** codegen : ✅ `@ZcrudModel/@ZcrudField/@ZcrudId`, `fieldRename: snake`, tous champs codegen-able (pas de canal hors-codegen).
- **AD-4** extensibilité : ✅ `extra` (slot brut + accesseur) + `extension` versionné ; `remapColorKey` = extension par injection (`ZKeyHash`).
- **AD-10** défensif : ✅ zéro throw, zéro `assert` au ctor `const`, `fromMap(const {})` sûr pour les deux entités.
- **AD-13/NFR-S7** : ✅ zéro couleur/hex/`Color` ; `colorKey` symbolique ; palette injectée.
- **AD-16/AD-19 (+.1.b)** : ✅ `updated_at`/`is_deleted` = store ; `_reservedKeys ⊇ ZSyncMeta.reservedKeys` ; `$FieldSpecs ∩ reservedKeys == {}` (2 entités) ; gate câblé (R8), **2 voies** pour `flashcard_tag`.
- **AD-1/AD-17** : ✅ kernel sans arête satellite ; `orphanTagIds` sur `String` neutres ; `graph_proof` reste ACYCLIQUE (rapport orchestrateur, cohérent avec pubspec `{core, annotations}`).

## Décision de statut recommandée
Story **prête pour `done`** dès la vérif verte repo-wide rejouée par l'orchestrateur (déjà verte au moment de la revue). Aucun finding bloquant. LOW-1 optionnel (documentation d'une pré-condition) — peut être corrigé dans le périmètre ou consigné.

---

## Remédiation orchestrateur (post-revue)

### LOW-1 — ✅ CORRIGÉ (correction structurelle, pas documentation)
`remap_color_key.dart` teste désormais la clé en **casse exacte d'abord** (`palette.keys.contains(rawTrimmed)` → identité stricte verbatim, cohérente avec `resolveKey`), **puis** la forme minuscule (tolérance de casse pour la convention `defaultStudy`), avant de remapper. Le dartdoc reflète ce contrat à deux niveaux.

**Pouvoir discriminant du test PROUVÉ par l'orchestrateur (motif dominant §7)** : un premier test golden (palette `{'Blue','Green','Red'}` sans hash injecté) **passait par coïncidence de hash** sur l'ancien code — donc SANS pouvoir discriminant, exactement le faux vert que ce projet traque. Réécrit avec un **hash CONSTANT injecté** (`(_) => 1` ⇒ remap(inconnu) → `keys[1] == 'Green'`) et des clés testées hors index-1 (`'Blue'`@0, `'Red'`@2) : sur l'ancien code `toLowerCase`-only, le test **ROUGIT** (`Expected: 'Blue' / Actual: 'Green'`) ; avec le fix, il **passe**. Séquence rejouée par l'orchestrateur, restauration à l'octet près.

**Vérif verte re-scellée après correction** : `analyze` kernel = No issues · tests kernel = **161** (+1 test LOW-1) · `gate:reserved-keys` RC=0 · `prove_gates` **41 OK / 0 FAIL**.

**Verdict final : ✅ 0 finding ouvert.** LOW-1 fermé par correction (non reporté).
