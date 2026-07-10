# Code Review — E9-3 : Dossiers & sessions d'étude (`zcrud_flashcard`)

- **Skill** : `bmad-code-review` (invoqué réellement via le tool `Skill`, workflow step-file). Couches adversariales (Blind Hunter / Edge Case Hunter / Acceptance Auditor) exécutées par le reviewer (sous-agents parallèles indisponibles dans ce contexte d'orchestration — mono-reviewer, signalé).
- **Story** : `_bmad-output/implementation-artifacts/stories/e9-3-dossiers-sessions-etude.md` (11 ACs, baseline `04aaaf0`).
- **Périmètre** : E9-3 uniquement (`z_review_mode.dart`, `z_study_folder.dart`, `z_study_session_config.dart`, `z_study_session_selector.dart`, `z_study_folder_hierarchy.dart`, barrel, 4 tests). E9-1/E9-2 (done) et workstreams E5/E10/E11b hors périmètre.
- **Date** : 2026-07-10.

## Vérif verte rejouée réellement sur disque

| Étape | Commande | RC | Résultat |
|---|---|---|---|
| generate | `dart run build_runner build --delete-conflicting-outputs` | **0** | 22 inputs, `z_study_folder.g.dart` + `z_study_session_config.g.dart` régénérés |
| analyze | `dart analyze .` (packages/zcrud_flashcard) | **0** | `No issues found!` |
| test | `flutter test` | **0** | `All tests passed!` — **117 tests** (59 baseline E9-1/E9-2 + 58 E9-3) |

Conforme au Dev Agent Record.

## Findings

Aucun finding **HIGH / MAJEUR / MEDIUM**. Findings LOW/nits ci-dessous (non bloquants).

### LOW-1 — Égalité superficielle de `extra` à valeurs collection
- **Fichiers** : `lib/src/domain/z_study_folder.dart:363` (`_mapEquals`), `z_study_session_config.dart:237`.
- **Impact** : `_mapEquals` compare `b[e.key] != e.value`. Pour une valeur de `extra` qui est elle-même une `List`/`Map` (ex. `related_topics: ['tva']`), deux instances structurellement égales sont jugées **différentes** (comparaison par référence). Les champs first-class listés (`sharedWith`/`tagIds`/`types`) restent corrects (comparés élément par élément, éléments `String`/enum). L'anomalie ne concerne **que** les valeurs collection nichées dans le sac `extra` non typé.
- **Reco** : introduire un helper d'égalité profonde partagé. **Non corrigé dans E9-3** : ce patron est repris à l'identique d'`z_flashcard.dart` (E9-1, done et revu) — la story impose explicitement « calquer exactement z_flashcard.dart ». Corriger ici divergerait du cœur du package ; à traiter en décision transverse (retro E9), pas au niveau story.

### LOW-2 — `toMap()` expose des références de listes internes
- **Fichiers** : `z_study_folder.g.dart` (`'shared_with': this.sharedWith`), `z_study_session_config.g.dart` (`'tag_ids': this.tagIds`).
- **Impact** : la map retournée par `toMap()` partage la référence de la liste interne ; une mutation externe du contenu de la map muterait l'état de l'entité immuable. Faible en pratique (défauts `const []`, code généré). Non éditable à la main (gitignoré, régénéré).
- **Reco** : évolution possible du générateur (copie défensive des listes) — hors périmètre E9-3.

### LOW-3 — `extra` fourni au constructeur non rendu non-modifiable
- **Fichier** : `z_study_folder.dart:88`, `z_study_session_config.dart:59`.
- **Impact** : `_extraFrom` (voie `fromMap`) rend `extra` non-modifiable (AC3 satisfait pour la désérialisation, testé). Une instance construite directement avec un `Map` mutable conserve ce map modifiable. Consistant avec E9-1.
- **Reco** : envelopper `extra` en `Map.unmodifiable` dans le constructeur si l'on veut l'invariant universel. Cosmétique.

### NIT-1 — Duplication `_asStringMap`
- `z_study_folder.dart:341` / `z_study_session_config.dart:214` déclarent un `_asStringMap` manuel alors que le `.g.dart` fournit `_$asStringMap` (noms distincts, pas de collision). Duplication mineure.

### NIT-2 — Double réexport de `ZReviewMode`
- Le barrel exporte `z_review_mode.dart` **et** `z_study_session_config.dart` (qui réexporte lui-même `z_review_mode.dart`). Même symbole, même origine → aucun conflit Dart. Redondance sans effet.

## Note cross-workstream (isolation AC11)
`git status` montre `packages/zcrud_core/**` modifié, **mais** provenant du workstream parallèle E5 (`z_local_store`, `z_remote_store`, `sync/*`, barrel core), **pas** de E9-3. La `File List` de E9-3 ne touche que `packages/zcrud_flashcard/**`, et les imports E9-3 n'utilisent que des APIs cœur préexistantes (`ZEntity`, `ZExtensible`, `ZExtension`, `ZResult`, `DomainFailure`, `unit`). AC11 satisfait pour le périmètre propre de la story. À confirmer par l'orchestrateur au gate d'epic (aucune régression cross-package : `analyze` E9-3 vert).

## Audit d'acceptation (11/11 ACs)
- **AC1** ✓ 6 modes camelCase, repli `spaced` (`defaultValue`), note SRS documentée. Testé (round-trip + inconnu + absent).
- **AC2** ✓ `@ZcrudModel(kind:'study_folder')`, tous champs + snake_case (`.g.dart`), `isEphemeral` hérité de `ZEntity`, rattachement inverse documenté, round-trip zéro-perte.
- **AC3** ✓ `extra` + `extension?` câblés hors-codegen sur les deux entités (sentinelle `_$undefined`, `_reservedKeys` dérivées des `$…FieldSpecs`+`'extension'`, `_extraFrom` non-modifiable, `_decodeExtension` guardé).
- **AC4** ✓ V2c inerte (défauts sûrs, round-trip) ; `relatedTopics`/`countryCode` via `extra` (testé).
- **AC5** ✓ `isArchived` getter, réversibilité par sentinelle `copyWith(archivedAt:null)`, **aucune** clé `is_deleted`/`isDeleted` (testé).
- **AC6** ✓ `updatedAt` DANS l'entité (LWW), round-trip, divergence documentée.
- **AC7** ✓ config `mode`/`folderId`/`tagIds`/`types`/`count`, `types` en `listEnum` **natif** défensif (élément inconnu ignoré via `whereType`), snake_case.
- **AC8** ✓ sélecteur pur : dossier couvre sous-dossier (`folderId==` ou `subFolderId==`), tags intersection non vide, types appartenance, composition ET, `count` (null illimité / `<=0` vide / troncature ordre-préservé). Bornes exactes vérifiées. Déterministe, sans I/O.
- **AC9** ✓ `validatePlacement` : auto-parent→Left (prime), racine→Right, parent manquant→Left, `parent.parentId!=null`→Left (niveau 3), parent racine→Right (niveau 2). Réutilise `ZResult`/`DomainFailure`/`unit`. Entité sans assert/throw (AD-14, testé `returnsNormally`).
- **AC10** ✓ désérialisation défensive réelle (maps `{}`, valeurs corrompues, `extension` non-map, `types` non-liste, `mode` non-String) → jamais de throw parent.
- **AC11** ✓ domaine pur-Dart, barrel exporte l'API + `hide ZStudyFolderZcrud`/`ZStudySessionConfigZcrud`, vérif verte RC=0×3.

## Conformité AD
AD-1 (isolation, réutilisation cœur) ✓ · AD-3 (codegen source unique, camelCase, snake persistance) ✓ · AD-4 (composition + `ZExtension?` + `extra`) ✓ · AD-5/AD-11 (`Either<ZFailure,Unit>`, `DomainFailure`) ✓ · AD-10 (additif + défensif, jamais de throw) ✓ · AD-14 (invariant en primitive pure, entité = données) ✓.

## Verdict

**PRÊT POUR `done`.** Zéro finding critique/majeur/MEDIUM. Vérif verte réelle : generate RC=0, analyze RC=0, test RC=0 (117). Les 3 LOW + 2 nits sont non bloquants et hérités du patron E9-1 (à traiter éventuellement en rétrospective d'epic, pas au niveau story). Isolation E9-3 propre (la modif `zcrud_core` visible en `git status` relève du workstream parallèle E5).

---

## Résolution (orchestrateur)

Vérif verte : `dart analyze packages/zcrud_flashcard` RC=0, `flutter test packages/zcrud_flashcard` **117 tests** RC=0 (codegen RC=0).

- **0 HIGH / 0 MAJEUR / 0 MEDIUM.**
- **LOW-1 (égalité profonde de `extra`), LOW-2 (toMap généré), LOW-3 (extra constructeur non non-modifiable), NIT-1/2 — CONSIGNÉS.** Hérités du patron E9-1/E9-2 (calqué sur `z_flashcard.dart`), non bloquants (AC3 satisfait+testé via `fromMap`). LOW-1 = **décision transverse à trancher en rétrospective epic-9** (helper d'égalité profonde partagé pour tous les slots `extra`), car corriger ici seul introduirait une divergence de patron entre les entités flashcard.

**Verdict final : `done`.**
