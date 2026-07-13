# Code Review — Story ES-1.3 « Réconciliation des métadonnées de sync — `ZSyncMeta` hors-entité (OQ #3) »

- **Date** : 2026-07-13
- **Reviewer** : `bmad-code-review` (skill RÉEL invoqué via le tool `Skill` — pas de fallback disque), effort `high`, revue adversariale
- **Story** : `_bmad-output/implementation-artifacts/stories/es-1-3-reconciliation-zsyncmeta.md` (statut `review`)
- **Architecture de référence** : `architecture-zcrud-study-2026-07-12/architecture.md` — **AD-19 + AD-19.1 / AD-19.2** (écrites par cette story) ; AD-9 / AD-10 / AD-16 / AD-4 / AD-1 hérités
- **Méthode** : lecture du code RÉEL sur disque (aucune simulation) + **sondes empiriques exécutées** (tests jetables `zz_probe_review_test.dart` dans `zcrud_flashcard` et `zcrud_study_kernel`, supprimés après usage) + inspection des `*.g.dart` régénérés.
- **Vérif verte** (rejouée par l'orchestrateur, NON re-vérifiée ici) : analyze repo-wide SUCCESS ; kernel 102 VM / 92 JS ; flashcard 180 ; core 911 ; `graph_proof` ACYCLIQUE + core OUT=0 ; `melos verify` RC=0.

---

## VERDICT : **CHANGES REQUESTED** (2 HIGH / 5 MEDIUM / 5 LOW)

La story fait **bien** ce qu'elle promet sur son périmètre déclaré (`ZStudyFolder`, `ZFlashcard`, `ZSyncMeta`, doc) : la correction est **correcte**, le test STAR est **honnête** (vrai chemin de production, aucune tautologie), la rétro-compat des corps est **auto-cicatrisante**.

Mais l'enjeu annoncé — **verrouiller la convention canonique AVANT qu'ES-2 ne fige les entités** — n'est **pas atteint** :

1. la règle normative AD-19.1 (« *toute entité annotée dérive ses clés réservées de `ZSyncMeta.reservedKeys`* ») est **violée par 2 entités du repo le jour même où elle est écrite** — dont **`ZRepetitionInfo`, que la doc désigne comme « exemplaire de référence »** (fuite **prouvée empiriquement**) ;
2. le cœur `zcrud_core` conserve un **contrat public (`ZSyncable`) dont le dartdoc prescrit l'inverse d'AD-19** ;
3. la règle n'a **aucune application machine** (rien ne casse si ES-2 l'oublie — c'est exactement ce qui a laissé passer le point 1).

Ces trois points se corrigent en **~5 lignes de code + 1 dartdoc + 2 tests**, tous dans des packages déjà ouverts par la story. Ils doivent l'être **avant `done`**, sinon la convention part en ES-2 avec deux contre-exemples vivants.

---

## Findings HIGH / MAJEUR (correction obligatoire avant `done`)

### H1 — `ZRepetitionInfo` porte le MÊME défaut D4, NON corrigé — et c'est l'entité que AD-19.1 érige en « exemplaire de référence »

- **Fichier** : `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart:222-227`
- **Code** :
  ```dart
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZRepetitionInfoFieldSpecs) spec.name,
    'extension',
  };   // ← PAS de ...ZSyncMeta.reservedKeys
  ```
- **Preuve EMPIRIQUE** (sonde exécutée, `flutter test`) :
  ```
  ZRepetitionInfo.fromMap({flashcard_id, updated_at, is_deleted, unknown_key})
    → extra   = {updated_at: 2026-01-01…, is_deleted: false, unknown_key: gardee}   ← POLLUTION
    → toMap() = [updated_at, is_deleted, unknown_key, flashcard_id, …]              ← RÉÉMISSION
    → toMap().containsKey('is_deleted') == true
  ```
  C'est **exactement** le défaut D4 que la story documente, corrige sur `ZStudyFolder`/`ZFlashcard`… et laisse intact ici. Pire : `ZRepetitionInfo` n'ayant **aucun** champ `updatedAt` déclaré, elle capture **les DEUX** clés réservées (là où `ZStudyFolder` n'en capturait qu'une).
- **Contexte aggravant** :
  - `ZRepetitionInfo` est un document **persisté top-level** (`study_repetitions/{cardId}`, `z_repetition_store.dart:1-8`) et le contrat du port stipule explicitement que `put()` « **estampille la méta LWW hors-entité** » (`z_repetition_store.dart:52-56`). Dès que l'adaptateur concret (déféré E9-5/composition root) écrira la méta **dans le corps** — ce que font **les deux** adaptateurs existants (`hive_z_local_store.dart:180-187`, `firebase_z_repository_impl.dart:229-236`) — la fuite est **active en production**.
  - **AD-19.1 la désigne comme « exemplaire de référence » de la convention** et affirme « *toute entité annotée dérive ses clés réservées de `ZSyncMeta.reservedKeys`* ». L'exemplaire est **non conforme à la règle qu'il illustre**.
- **Impact AD** : **AD-16** (soft-delete hors-entité qui fuit dans le domaine), **AD-4** (`extra` = clés *inconnues du domaine* ; les clés de sync ne le sont pas), **AD-19/AD-19.1** (règle contredite par son propre exemplaire), `==` cassée entre un état SRS en mémoire et le même relu du store (impact direct sur les comparaisons de session SRS).
- **Recommandation** : ajouter `...ZSyncMeta.reservedKeys` à `_reservedKeys` (le fichier importe déjà `package:zcrud_core/domain.dart`) + le test miroir du groupe « AD-19 — clés de sync hors-entité » déjà écrit pour `ZFlashcard`. **1 ligne + 1 groupe de test, même package que la story.**

### H2 — `ZStudySessionConfig` (noyau) porte le MÊME défaut, NON corrigé

- **Fichier** : `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart:182-187`
- **Preuve EMPIRIQUE** (sonde exécutée, `dart test`) :
  ```
  ZStudySessionConfig.fromMap({mode, updated_at, is_deleted, unknown})
    → extra = {updated_at: …, is_deleted: false, unknown: 1}     ← POLLUTION
    → toMap().containsKey('is_deleted') == true                  ← RÉÉMISSION
  ```
- **Contexte aggravant** : entité **`@ZcrudModel(kind: 'study_session_config')`** ⇒ enregistrable/persistable au `ZcrudRegistry` comme document autonome ; et surtout, c'est une entité **du noyau `zcrud_study_kernel`** — le package que les développeurs d'**ES-2 vont ouvrir en premier et copier comme patron**. Le contre-exemple est placé exactement sur le chemin de propagation que la story existe pour fermer.
- **Impact AD** : identique à H1 (AD-16 / AD-4 / AD-19.1).
- **Recommandation** : `...ZSyncMeta.reservedKeys` (ajouter l'import `package:zcrud_core/domain.dart` — déjà présent l. 38) + test miroir.

> **Note de périmètre.** La story n'avait pas *déclaré* ces deux entités dans ses ACs. Le finding n'est donc pas un défaut d'exécution des tâches, mais un **défaut de complétude de la convention verrouillée** : ES-1.3 écrit une règle normative repo-wide (AD-19.1) que le repo viole en 2 endroits à l'instant même de son écriture, dont son exemplaire canonique. Corriger maintenant coûte 2 lignes ; corriger après ES-2 coûtera N entités.

---

## Findings MEDIUM (à corriger dans le périmètre, ou justifier par écrit)

### M1 — `ZSyncable` (cœur) documente **explicitement l'inverse** d'AD-19

- **Fichier** : `packages/zcrud_core/lib/src/domain/contracts/z_syncable.dart:9-13`
- **Code (dartdoc du contrat PUBLIC du cœur)** :
  > « Ce contrat est **agnostique** quant à l'emplacement de la métadonnée : la valeur peut vivre **dans** l'entité (comme `StudyFolder.updatedAt`) ou **hors-entité** via `ZSyncMeta` (comme `Mindmap`). »
- **Défaut** : AD-19.1 vient de trancher que la valeur LWW vit **TOUJOURS** hors-entité et que le merge ne lit **JAMAIS** un `T.updatedAt`. `ZSyncable` — exporté par `zcrud_core`, sans aucun implémenteur de production (grep : seul un `_Doc` de test) — reste le **document d'accueil** d'un développeur ES-2 qui cherche « comment déclarer la clé LWW de mon entité ». Il lui répond, noir sur blanc, que l'in-entité est légitime, et cite `StudyFolder.updatedAt` (désormais **déprécié**) comme modèle.
- **Impact AD** : AD-19/AD-19.1 (deux sources de vérité contradictoires dans le même package `zcrud_core` que la story vient d'éditer). C'est précisément le « chemin de re-branchement » que le test STAR est censé fermer — le test ferme le **code**, pas la **doctrine**.
- **Recommandation** : réécrire le dartdoc de `ZSyncable` (renvoi à AD-19 : la valeur vit hors-entité ; un `T.updatedAt` n'est qu'un miroir de compat sans autorité), ou déprécier le contrat s'il n'a plus d'usage. **Coût : 1 dartdoc, dans un fichier du package déjà ouvert par la story.**

### M2 — `_timestampFields ∩ ZSyncMeta.reservedKeys` : exclusion documentée mais **non gardée** — vecteur de neutralisation SILENCIEUSE de la clé LWW

- **Fichier** : `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:148-157` (+ `_encode` l. 229-238, `_mergedMap` l. 738-746, `_applyTimestampHints`)
- **Défaut** : le dartdoc affirme « `is_deleted`/`updated_at` (`ZSyncMeta`) sont **exclus** — jamais dans cet ensemble ». Ce n'est qu'une **convention en commentaire** : rien ne l'empêche. Or `ZStudyFolder.updatedAt` **reste un `@ZcrudField` `DateTime`** (miroir conservé par D5) : il suffit qu'un dev de la migration DODLP l'annote `@ZcrudField(persistAs: ZPersistAs.timestamp)` — geste **parfaitement plausible**, c'est tout l'objet du gap B14 — pour que `updated_at` entre dans `$ZStudyFolderTimestampFields`, et alors `_applyTimestampHints` convertit **l'estampille du store** en `Timestamp` natif. Au relire : `ZSyncMeta.fromJson` → `_parseIso(Timestamp)` → **`null`** (`z_sync_meta.dart:78-81` : `if (value is! String) return null`). **Toutes les métas deviennent `null`** ⇒ `ZLwwResolver` dégénère (« jamais synchronisé », le local gagne toujours) ⇒ **perte d'écritures distantes, sans aucun test rouge**.
- **Impact AD** : AD-9 (LWW), AD-19 (l'autorité de la méta est *neutralisée*, pas seulement contournée), AD-10.
- **Recommandation** : garde machine dans le constructeur (`assert(timestampFields.intersection(ZSyncMeta.reservedKeys).isEmpty)`) **et/ou** interdiction normative explicite dans AD-19.1 (« aucune clé réservée ne peut être annotée `persistAs: timestamp` »). Si `zcrud_firestore` reste hors périmètre : consigner en **dette bloquante d'ES-1.4**, pas en LOW.

### M3 — Rétro-compat legacy **DODLP** (`updated_at` en `Timestamp` natif) : la clé d'autorité tombe à `null` — non documenté par AC5

- **Fichiers** : `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:208-215` (`_inject`) + `packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart:78-81` (`_parseIso`) + `z_study_folder.g.dart:35-39` (`_$asDateTime`)
- **Défaut** : `_inject` ne normalise `Timestamp → String ISO` **que** pour les clés de `_timestampFields` — dont `updated_at` est **volontairement exclu**. Donc un document **legacy réellement écrit par DODLP** (qui persiste ses dates en `Timestamp` Firestore) est relu avec `updated_at` = `Timestamp` → `ZSyncMeta.fromJson` renvoie `updatedAt: null` **ET** le miroir `_$asDateTime(Timestamp)` renvoie `null` (le helper ne connaît que `DateTime`/`String`). **La clé d'autorité de merge est perdue sur toute la donnée legacy Timestamp.**
- **Pourquoi c'est un finding d'ES-1.3** : l'AC5 affirme « **aucune donnée existante ne devient illisible** » et AD-19.2 prétend documenter **toutes** les divergences résiduelles. C'est vrai pour le **corps** de l'entité (prouvé), c'est **faux pour la clé d'autorité** sur le format legacy le plus probable du consommateur n°1. Le round-trip legacy testé (`z_study_folder_test.dart:118-142`) n'exerce qu'une map **ISO-8601 propre** — il ne voit pas ce cas.
- **Impact AD** : AD-10 (évolution additive/lecture des données antérieures), AD-9, AD-19.2 (divergence non documentée).
- **Recommandation** : au minimum **documenter** ce cas dans AD-19.2 + ouvrir une dette (`DW-ES13-3`) ; idéalement normaliser les `ZSyncMeta.reservedKeys` dans `_inject` (bi-format `Timestamp`|`String`, comme pour les `timestampFields`) — cohérent avec la tolérance bi-format déjà revendiquée pour B14.

### M4 — AD-19.1 ne dit rien du cas « entité avec un besoin métier légitime d'un horodatage propre » → **collision de clé = perte de donnée silencieuse**

- **Fichier** : `architecture.md` § AD-19.1
- **Défaut** : la règle interdit `T.updatedAt` **sans fournir l'alternative**. Un dev ES-2 ayant besoin d'un « dernière édition par l'utilisateur » sur `ZSmartNote` fera le geste naturel : déclarer un champ `updatedAt` → clé persistée `updated_at` → **écrasée inconditionnellement par le store à chaque `put`** (`_encode` écrit la méta APRÈS le corps). Sa donnée métier disparaît, **sans erreur**, exactement comme le miroir de `ZStudyFolder` — sauf que là ce n'est pas un miroir, c'est une **valeur métier**.
- **Impact AD** : AD-19.1 (ambiguïté normative), AD-9.
- **Recommandation** : ajouter une clause explicite : « les clés persistées `updated_at`/`is_deleted` sont **réservées au store** ; aucun champ métier ne peut les porter. Un horodatage métier doit utiliser une clé **distincte** (`edited_at`, `content_updated_at`…). » C'est **la** phrase que la story devait écrire pour être « appliquable sans ambiguïté par un dev d'ES-2 ».

### M5 — La règle AD-19.1 n'a **aucune application machine** : rien ne casse si ES-2 l'oublie

- **Défaut** : `ZSyncMeta.reservedKeys` est la « définition machine » de la convention… mais **aucun gate** ne vérifie qu'une entité l'a bien consommée. La preuve : **H1 et H2** sont passés sous les 1193 tests verts. Le test STAR prouve l'autorité du **résolveur** ; **rien** ne prouve la propreté des **entités**.
- **Impact AD** : AD-19.1, et la leçon `ZExportApi` de `CLAUDE.md` (« la vérif verte par package ne voit pas la régression transverse »).
- **Recommandation** : gate repo-wide (à la manière de `verify:serialization`) : pour **chaque `kind` enregistré** au `ZcrudRegistry`, `registry.decode(kind, {...réservées})` doit produire une entité dont `extra` ne contient aucune clé réservée et dont `encode()` ne réémet pas `is_deleted`. À câbler en **ES-1.4 (gates)** — et à mentionner nommément dans AD-19.1 comme le moyen d'exécution de la règle.

---

## Findings LOW

- **L1** — `architecture.md` § AD-19.1 : chemin **erroné** pour l'exemplaire. `ZRepetitionInfo` est déclarée dans `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart`, pas dans `.../lib/src/data/z_repetition_store.dart` (qui est le port). À corriger (et l'exemplaire lui-même à rendre conforme, cf. H1).
- **L2** — **Asymétrie `@Deprecated`** `ZStudyFolder.updatedAt` (déprécié) vs `ZFlashcard.updatedAt` (non déprécié) : défendable et **documentée** (D5 / AD-19.2 pt.3 / DW-ES13-2), mais elle laisse **deux conventions visibles simultanément** à la veille d'ES-2. Acceptée en l'état ; à re-statuer en ES-2/ES-11 comme prévu.
- **L3** — Les `*.g.dart` **lisent** le membre déprécié (`z_study_folder.g.dart:87, 111, 150-152`). Aucun diagnostic aujourd'hui (`analysis_options.yaml` exclut `**/*.g.dart`, et le CFE n'émet pas de warning de dépréciation) — mais l'invisibilité est **conditionnelle** : si l'exclusion saute ou si la CI passe un jour `--fatal-infos`, l'analyse devient rouge sur du code **non éditable**. Piste : faire émettre `// ignore_for_file: deprecated_member_use` par `zcrud_generator`. À consigner en dette.
- **L4** — `ZSyncMeta.stripReserved` (`z_sync_meta.dart:52-56`) n'a **aucun appelant de production** (grep repo-wide : définition + tests uniquement). API ajoutée « au cas où » (léger YAGNI) — elle trouvera son usage en soldant DW-ES13-1 (adapters + mindmap) ; sinon, la retirer.
- **L5** — Le test STAR ne couvre pas l'**asymétrie de `null`** (`meta` locale `null` / `meta` distante non-`null`, miroirs contradictoires). Le cas « les deux `null` » est couvert. Complément trivial (`ZLwwResolver` a ses propres tests dans le cœur) — nit.

---

## Réponses explicites aux 3 axes critiques

### Axe 1 — La correction de la fuite `is_deleted` est-elle COMPLÈTE et CORRECTE ?

**CORRECTE, mais INCOMPLÈTE.**

- **(a) Toutes les clés de sync écrites dans le corps par les stores sont-elles couvertes ?** **OUI.** Inspection réelle : `hive_z_local_store.dart` `_encode` (l. 180-187) et `applyMerged` (l. 426-431) écrivent **`id`**, **`updated_at`**, **`is_deleted`** — rien d'autre. `firebase_z_repository_impl.dart` `_encode` (l. 229-238) et `_mergedMap` (l. 738-746) : **idem**. Aucun `created_at`, `deleted_at` ni marqueur de version côté store. `id` est un champ **déclaré** de toutes les entités concernées ⇒ déjà réservé par les field-specs. ⇒ `{updated_at, is_deleted}` est **exhaustif** vis-à-vis des stores.
- **(b) `reservedKeys` est-il exhaustif vs `ZSyncMeta.toJson()` ?** **OUI**, et c'est **verrouillé structurellement** : `toJson` n'émet que `kUpdatedAt`/`kIsDeleted`, et le test `z_sync_meta_test.dart` ajouté par la story asserte `json.keys.toSet() == ZSyncMeta.reservedKeys` — si quelqu'un ajoute un champ à la méta sans l'ajouter aux clés réservées, **ce test tombe**. Bon travail.
- **(c) D'autres entités portent-elles le même défaut, non corrigées ?** **OUI — DEUX, prouvées empiriquement** :
  - **`ZRepetitionInfo`** (`zcrud_flashcard`) → **H1** — et c'est **l'exemplaire de référence d'AD-19.1**. Capture **les deux** clés dans `extra`, les **réémet** dans `toMap()`.
  - **`ZStudySessionConfig`** (`zcrud_study_kernel`) → **H2** — entité du **noyau**, patron naturel d'ES-2.
  - `ZMindmap` / `ZMindmapNode` : **conformes** (via `_reservedSyncKeys` en littéraux durs — dette DW-ES13-1, pas une fuite). `ZChoice` : sous-modèle sans échappatoire `extra` ⇒ non concerné.

### Axe 2 — Rétro-compatibilité des données existantes (AD-10)

- **(a) Une entité relue reste-t-elle lisible ?** **OUI** (prouvé : map legacy + map de store + map corrompue ⇒ aucun throw, corps intact, miroir peuplé).
- **(b) Que devient un `extra` legacy DÉJÀ pollué par l'ancien `toMap` buggé ?** **Il est nettoyé — la correction est AUTO-CICATRISANTE.** `extra` **n'est jamais persisté comme sous-map** : `toMap()` l'aplatit dans le corps, et `fromMap()` le **re-dérive** intégralement du corps plat à chaque lecture. Une clé `is_deleted` héritée du corps est donc **filtrée dès la première relecture** post-correction. Sonde exécutée sur une map **SALE** (`is_deleted: true` + `updated_at` + `related_topics`) : `extra == {related_topics: [t]}`, `toMap()` sans `is_deleted`. **Aucune pollution permanente ; rien à migrer.**
- **(c) Le round-trip legacy testé couvre-t-il les données SALES ?** **OUI** pour la saleté visée (map de store avec `is_deleted: true`, map corrompue `is_deleted: 'oui'` / `updated_at: 42`). **NON** pour le cas legacy **le plus probable du consommateur n°1** : `updated_at` persisté en **`Timestamp` Firestore natif** (DODLP) ⇒ **méta ET miroir tombent à `null`**, la clé d'autorité de merge est perdue → **M3**. L'affirmation d'AC5 « aucune donnée existante ne devient illisible » est vraie pour le **corps**, mais **incomplète pour la clé de merge**.

### Axe 3 — L'autorité de merge est-elle vraiment la méta ?

- **Le test STAR est HONNÊTE.** Il n'y a **aucune** reconstitution locale : il instancie le **vrai** `ZSyncEntry<ZStudyFolder>` et appelle le **vrai** `const ZLwwResolver().resolve<ZStudyFolder>(local, remote)` de `zcrud_core` — le chemin de production exact utilisé par `ZOfflineFirstRepository`. Le pouvoir discriminant est réel : les miroirs **contredisent frontalement** la méta (2030/2020 vs 1990/2026), donc un moteur lisant `T.updatedAt` prendrait **systématiquement la décision inverse** dans les deux cas et **échouerait**. Ce n'est **pas** une tautologie. `ZSyncEntry.updatedAt` étant un **getter dérivé de `meta`**, le miroir est **structurellement hors du chemin**.
- **Aucun chemin de production ne fait gagner `T.updatedAt` aujourd'hui.** Grep exhaustif de `.updatedAt` hors tests/`*.g.dart` : les seules occurrences sont **internes aux entités** (constructeur / `copyWith` / `==` / `hashCode`) et les deux `_encode` des stores qui **construisent** la méta avec `DateTime.now()`. Les **quatre** voies d'écriture (`hive._encode`, `hive.applyMerged`, `firestore._encode`, `firestore._mergedMap`) écrivent la clé méta **APRÈS** le corps ⇒ le miroir est **systématiquement écrasé**. AC5-bis reproduit fidèlement cet ordre.
- **MAIS deux vecteurs restent ouverts** :
  1. **doctrinal** — `ZSyncable` (cœur, public) prescrit encore l'option in-entité et cite `StudyFolder.updatedAt` en exemple (**M1**) ;
  2. **opérationnel** — la méta peut être **neutralisée** (`null`) plutôt que contournée, via `persistAs: timestamp` sur une clé réservée (**M2**) ou via une donnée legacy `Timestamp` (**M3**). Le merge dégénère alors en « le local gagne toujours » — un **échec de l'autorité de la méta**, invisible aux tests actuels. Le test STAR prouve que la méta **prime** ; il ne prouve pas qu'elle **survit au décodage**.

---

## Complétude des ACs (satisfaction par le CODE, pas par les commandes vertes)

| AC | Statut | Vérification |
|---|---|---|
| **AC1** — AD-19 matérialisé (doc + memlog) | ✅ **avec réserves** | AD-19.1/AD-19.2 présentes, entités ES-2 nommées, memlog daté. Réserves : **M4** (règle incomplète), **M5** (non outillée), **L1** (chemin erroné), et l'« exemplaire » cité est **non conforme** (**H1**). |
| **AC2** — merge n'utilise jamais `T.updatedAt`, prouvé par test qui casse | ✅ | Test STAR sur le **vrai** `ZLwwResolver`/`ZSyncEntry`, miroirs mensongers, cas symétrique + `null` + tombstone. Nit **L5**. |
| **AC3** — statiques `ZSyncMeta` + iso-comportement | ✅ | `kUpdatedAt`/`kIsDeleted`/`reservedKeys`/`stripReserved` en **membres statiques** (zéro symbole top-level). `fromJson`/`toJson` consomment les constantes — **plus aucun littéral** dans le fichier. `stripReserved` pure/non-mutante (tests). Nit **L4** (aucun appelant de prod). |
| **AC4** — `is_deleted` ne pollue plus `extra` | ⚠️ **partiel** | ✅ **prouvé** pour `ZStudyFolder` **et** `ZFlashcard` (sondes). ❌ **faux repo-wide** : `ZRepetitionInfo` (**H1**) et `ZStudySessionConfig` (**H2**) polluent toujours. |
| **AC5** — miroir déprécié + divergences documentées | ⚠️ **partiel** | `@Deprecated` + `@ZcrudField` coexistent (spec `updated_at` toujours émis l. 185 du `.g.dart` — **vérifié sur disque**). Round-trip legacy ✅. **AC5-bis** ✅ (l'estampille du store écrase le miroir 2030). ❌ La divergence **M3** (legacy `Timestamp`) n'est **pas** documentée alors qu'AD-19.2 prétend l'exhaustivité. |
| **AC6** — surface publique inchangée, garde vert sans modification | ✅ | `git diff` : **aucune** modification du barrel `zcrud_study_kernel.dart` ; le diff du barrel `zcrud_flashcard.dart` est **l'héritage non committé d'ES-1.1/ES-1.2** (bloc `export … hide` + retrait des exports remontés), **rien d'ES-1.3** ; ni `_flashcardAllowlist` ni les tests de garde touchés. |
| **AC7** — vérif verte repo-wide | ✅ | Rejouée par l'orchestrateur (analyze SUCCESS, kernel 102/92, flashcard 180, core 911, `verify` RC=0). Non re-vérifiée ici. **Réserve de fond** : les tests verts **ne voient pas** H1/H2/M2/M3 — c'est l'objet de **M5**. |

---

## Points forts (à conserver)

- **D3 (statiques sur `ZSyncMeta`) est le bon tranchage** : zéro symbole public nouveau, garde de surface ES-1.2 vert **sans dérogation**, définition machine unique. Élégant.
- Le test `json.keys.toSet() == reservedKeys` est un **vrai verrou structurel** (une évolution de `ZSyncMeta` ne peut plus désynchroniser `reservedKeys`).
- **AC5-bis** est un excellent test : il prouve le *contrat d'ordre d'écriture* du store **sans** créer d'arête `kernel → zcrud_firestore` (AD-1 respecté), avec un commentaire pointant la ligne réelle.
- La discipline « **vérifier empiriquement, pas raisonner** » a été réellement appliquée (piège n°1 sur `@Deprecated` + codegen levé sur disque).

---

## Actions requises avant `done`

1. **[H1]** `...ZSyncMeta.reservedKeys` dans `ZRepetitionInfo._reservedKeys` + test miroir du groupe AD-19.
2. **[H2]** `...ZSyncMeta.reservedKeys` dans `ZStudySessionConfig._reservedKeys` + test miroir (kernel **et** copie flashcard si applicable).
3. **[M1]** Corriger le dartdoc de `ZSyncable` (`zcrud_core`) — il ne peut pas prescrire l'inverse d'AD-19.
4. **[M4]** Ajouter à AD-19.1 la clause « clés persistées réservées — aucun champ métier ne peut porter `updated_at`/`is_deleted` ; horodatage métier ⇒ clé distincte ».
5. **[M3]** Documenter la divergence `Timestamp` legacy dans AD-19.2 + dette `DW-ES13-3`.
6. **[M2]** Garde `timestampFields ∩ reservedKeys == {}` (ou dette **bloquante ES-1.4**, explicitement justifiée par écrit).
7. **[M5]** Consigner le gate repo-wide « clés réservées » comme livrable **ES-1.4** et le référencer dans AD-19.1.
8. **[L1]** Corriger le chemin de `ZRepetitionInfo` dans AD-19.1.

---

## Disposition orchestrateur (2026-07-12)

Verdict initial : **CHANGES REQUESTED** (2 HIGH · 5 MEDIUM · 5 LOW). **Remédiation appliquée** (Opus), puis **vérif verte rejouée sur disque par l'orchestrateur**.

### Traitement des findings

- **H1 (`ZRepetitionInfo`) et H2 (`ZStudySessionConfig`) → CORRIGÉS + PROUVÉS.** La correction initiale d'ES-1.3 était **incomplète** : elle avait corrigé 2 entités sur 4. Ironie instructive — l'entité oubliée H1 était précisément **l'« exemplaire de référence » désigné par AD-19.1** : l'exemplaire violait la règle qu'il illustre. Sondes exécutées : 8 tests rouges (flashcard) et 4 (kernel) **sans** les correctifs.
- **M1 (le contrat `ZSyncable` prescrivait l'inverse d'AD-19.1) → CORRIGÉ.** Dartdoc réécrit (la clé LWW vit TOUJOURS hors-entité ; un `T.updatedAt` n'est qu'un miroir **sans autorité**). Grep repo-wide : plus aucun dartdoc ne prescrit l'in-entité.
- **M2 + M3 (la méta pouvait être NEUTRALISÉE à `null` au décodage ⇒ le LWW dégénérait en « le local gagne toujours ») → CORRIGÉS DANS L'ADAPTER (AD-5 préservé).** `zcrud_core` ne connaît toujours PAS `Timestamp`. `FirebaseZRepositoryImpl._inject` normalise inconditionnellement les clés réservées (`Timestamp` natif / `DateTime` / forme sérialisée `{_seconds,_nanoseconds}`) → ISO-8601, **avant** `fromMap`. Garde **effective en release** (pas seulement un `assert`) : `_timestampFields.difference(ZSyncMeta.reservedKeys)`. La méta **survit** désormais au décodage d'un document legacy DODLP.
  Formulation clé de la revue, à retenir : *« le test STAR prouve que la méta PRIME ; il ne prouve pas qu'elle SURVIT au décodage. »*
- **M4 → CORRIGÉ (AD-19.1.a).** Clause + **table de décision** sans ambiguïté pour ES-2 : les clés `updated_at`/`is_deleted` appartiennent au STORE ; un horodatage **métier** doit utiliser une clé distincte (`edited_at`, `published_at`, `reviewed_at`…), sinon le store l'écrase silencieusement à chaque `put`.
- **L1, L5 → CORRIGÉS.** L5 couvre désormais l'asymétrie `null` — c'est-à-dire **le scénario exact de la faille M2/M3 rejoué au niveau du résolveur**.
- **BONUS — DW-ES13-1 SOLDÉE** (n'était pas demandée) : les 4 sites à littéraux durs (`zcrud_firestore` ×2, `zcrud_mindmap` ×2) consomment désormais `ZSyncMeta`. **Plus aucun littéral `'updated_at'`/`'is_deleted'` en code dans tout `lib/`** (vérifié par l'orchestrateur). La définition machine d'AD-19 est enfin RÉELLEMENT unique — le dernier vecteur de dérive (une 3ᵉ clé réservée future divergeant silencieusement) est supprimé.

### Scan d'exhaustivité (exigé pour ne pas refaire l'erreur)

**6 classes** dans tout le repo portent `extra`/`_reservedKeys` — **toutes conformes** après remédiation : `ZStudyFolder`, `ZStudySessionConfig` (H2), `ZFlashcard`, `ZRepetitionInfo` (H1), `ZMindmap`, `ZMindmapNode`. Non concernés (vérifié) : `ZChoice`, `ZExtension`, `ZSyncMeta`.

### MEDIUM reporté — justification écrite (obligatoire, CLAUDE.md)

- **M5 — aucune application MACHINE d'AD-19.1 → REPORTÉ à ES-1.4.** Justification : ES-1.4 est **la story des gates CI** — c'est littéralement sa raison d'être, et l'y implémenter est mieux que de bricoler un gate isolé ici. **La spécification complète du gate est figée dans `architecture.md` § AD-19.1.c** (volet comportemental via `ZcrudRegistry` + volet statique), donc ES-1.4 n'a plus qu'à l'implémenter. **Ce report est le finding le plus important de la story** : M5 dit « rien ne casse si une entité oublie la règle » — et c'est **exactement ce qui a laissé passer H1/H2 sous 1193 tests verts**. Une règle d'architecture qu'aucune machine ne vérifie n'est pas une règle, c'est un vœu. **ES-1.4 ne peut pas être clôturée sans ce gate.**
- **L2** (asymétrie `@Deprecated` `ZStudyFolder`/`ZFlashcard` — DW-ES13-2), **L3** (`.g.dart` lit le membre déprécié), **L4** (`stripReserved` sans appelant) : consignés, non traités.

### Vérif verte finale (rejouée par l'orchestrateur, pas sur la foi de l'agent)

`melos run analyze` repo-wide SUCCESS · kernel **108** VM / **98** JS(node) · flashcard **189** · core **911** · firestore **90** · mindmap **110** · `graph_proof` ACYCLIQUE OK / CORE OUT=0 OK · `melos run verify` repo-wide **RC=0** (gate:web inclus) · **zéro littéral de clé de sync résiduel** hors définition.

**Conclusion : story ES-1.3 → `done`.** 2 HIGH et 4 MEDIUM corrigés et prouvés par sonde ; M5 reporté à ES-1.4 avec spécification figée et justification ; L2/L3/L4 consignés.
