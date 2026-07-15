# Story ES-3.0: Le registre préserve l'extension typée + immuabilité PATRON des canaux Map/List

Status: done

<!-- TÊTE BLOQUANTE de l'epic ES-3. Solde DW-ES14-2 (BLOQUANTE avant tout store) + DW-ES24-1 (patron). -->
<!-- Verdict rétro ES-2 §7 : « PRÊT SOUS CONDITION D'UNE STORY DÉDIÉE EN TÊTE (ES-3.0). » -->

## Story

As un **intégrateur qui s'apprête à câbler le premier store offline-first d'ES-3** (`ZStudyRepository`, ES-3.1/3.2/3.5),
I want que **`ZcrudRegistry` REconstruise l'`extension` TYPÉE et honore la provenance (`ZSourceRegistry`) sur la voie registre — la SEULE que le store emprunte — et que l'immuabilité PROFONDE des canaux `Map`/`List` soit INCONDITIONNELLE (tenue même sur le constructeur `const` invoqué non-const)**,
so that **câbler un store ne DÉTRUISE PAS l'`extension` typée d'une entité extensible (`ZNoteAudio` sur `ZSmartNote`) au premier `put`, et qu'aucun code applicatif (ES-4+/DODLP) ne puisse muter en place une collection interne qu'il croyait figée** — deux pertes de données irréversibles fermées AVANT qu'un store ne s'y appuie.

---

## Contexte & problème mesuré

Cette story est la **TÊTE BLOQUANTE d'ES-3**, imposée par le **verdict de la rétrospective ES-2** (§7) : *« ES-3 câble le premier store, et deux dettes 🔴 deviennent alors destructrices. »* Elle solde **deux dettes de fond** portées par ES-2, chacune un **défaut de PATRON** (donc à solder **en tête**, jamais story par story — **R11**) :

### 🔴 DW-ES14-2 (le CŒUR — BLOQUANTE) — `ZcrudRegistry` ne réinjecte NI `extension` NI `sourceRegistry`

**Une cause, deux symptômes.** `ZcrudRegistry.decode(kind, map)` reconstruit l'entité via la factory de **domaine** `Xxx.fromMap` (corrigé en ES-2.0 pour préserver `extra`), MAIS `fromMap` d'une entité extensible accepte des collaborateurs **optionnels injectables** que le registre **n'a aucun moyen de fournir** :

```dart
// packages/zcrud_note/lib/src/domain/z_smart_note.dart:154
factory ZSmartNote.fromMap(Map<String, dynamic> map, { ZSmartNoteExtensionParser? extensionParser });
```

Le registrar **généré** (`registerZSmartNote`, `zcrud_generator`) câble `fromMap: ZSmartNote.fromMap` en **tear-off nu** → `extensionParser` vaut **`null`**. Résultat MESURÉ (verrou `tool/reserved_keys_gate/test/reserved_keys_test.dart` › groupe `DW-ES14-2`, l.1368+) : sur la voie registre, `note.extension` n'est **JAMAIS** un `ZNoteAudio` — c'est **toujours** un `ZOpaqueNoteExtension` (donnée **portée verbatim** depuis la mitigation ES-2.2, mais **type PERDU** : l'app **ne peut pas lire l'audio**). Idem pour `ZSourceRegistry` : la provenance typée n'est **jamais résolue** sur la voie registre.

**La clause d'échappement n°1 de la dette est FALSIFIÉE.** `firebase_z_repository_impl.dart:204-229` écrit encore, en dartdoc, que `fromRegistry` reste utilisable *« si — et seulement si — l'entité **n'utilise pas** le slot `extension` »*. Cette condition **était** vérifiable tant qu'AUCUNE `ZExtension` concrète n'existait dans le repo. **`ZNoteAudio` (ES-2.2, 1ʳᵉ `ZExtension` concrète, portée par une entité LIVRÉE `ZSmartNote`) l'a rendue FAUSSE.** Cette dartdoc **autorise le câblage d'un store** — un faux vert de prose qui devient une perte de données au premier store d'ES-3.

**Risque si ignorée** (rétro §4) : câbler le store d'ES-3 sur un registre qui détruit `extension` = **perte de données irréversible dès la 1ʳᵉ écriture** de toute entité extensible. **Bloque ES-3.2 et ES-3.5.**

### 🔴 DW-ES24-1 (PATRON immuabilité — non bloquante pour le store, à solder avant appui applicatif)

L'immuabilité **profonde** des canaux `Map`/`List` est gardée **aux frontières `fromMap`/`copyWith`** (`Map.unmodifiable`/`List.unmodifiable` via `_guard`/`_decodeSectionOrders`/`_decodeByQuality`), **mais PAS** sur le **constructeur `const` invoqué non-const** avec une référence mutable retenue :

```dart
final mut = <int, int>{1: 2};
final i = ZDocumentLearningInfo(qualityByPage: mut); // ctor const, invoqué non-const
i.qualityByPage[0] = 99; // ⛔ NE THROW PAS — la réf mutable est retenue telle quelle
// ⇒ hashCode (une somme) change, l'instance se perd dans son propre Set,
//   page 0 (invariant 1-based) contournée, round-trip cassé.
```

**Trou de PATRON partagé par 5 canaux** :
- `ZDocumentLearningInfo.qualityByPage` (`Map<int,int>`) — `packages/zcrud_document/lib/src/domain/z_document_learning_info.dart`
- `ZDocumentReadingState.learning` (`ZDocumentLearningInfo`, compose le précédent) — `packages/zcrud_document/lib/src/domain/z_document_reading_state.dart`
- `ZSmartNote.content` (`List<Map<String,dynamic>>`) — `packages/zcrud_note/lib/src/domain/z_smart_note.dart`
- `ZFolderContentsOrder.sectionOrders` (`Map<String,List<String>>`) — `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart`
- `ZStudySessionResult.byQuality` (`Map<String,int>`) — `packages/zcrud_study_kernel/lib/src/domain/z_study_session_result.dart`

**Le MODÈLE du fix est le patron `extra` d'ES-2.2b** (`zNormalizeExtra`, `packages/zcrud_core/lib/src/domain/extension/z_extensible.dart:122`) : **slot brut privé + accesseur normalisant/immuabilisant** — *« le champ stocké reste BRUT (le ctor `const` l'exige) ; c'est la LECTURE qui est normalisée »*, **le seul point que TOUTES les voies traversent**, **sans perdre `const`, sans `assert`** (AD-10 interdit l'`assert` : le décodeur généré appelle le ctor avec des valeurs BRUTES). L'immuabilité doit devenir **INCONDITIONNELLE**.

**Priorité (rétro §4)** : DW-ES24-1 est un **hasard in-memory, PAS une perte au store** (le store passe par `fromMap` déjà gardé) ⇒ **priorité MOINDRE que DW-ES14-2**, mais à solder **avant** que du code applicatif (ES-4+/DODLP) ne s'appuie sur l'immuabilité supposée. On l'inclut **dans la même ES-3.0** (rétro §7 pt.2 : *« de préférence dans la même ES-3.0 — même code `zcrud_core`/kernel, même geste que le patron `extra` »*).

### Ce que cette story NE fait PAS
- **Pas de câblage de store** (`ZStudyRepository` = ES-3.1/3.2/3.5) : elle **précède** ces stories, elle ne les fait pas.
- **Pas de DW-ES25-1** (garde `(h)` des VO à invariant) : c'est un **spike R4 séparé, non bloquant** (rétro §7 pt.3), planifié tôt dans ES-3 **hors** de cette story.
- **Pas de DW-ES21-1** (mapping legacy IFFD 6→4 statuts) : c'est ES-3.5 (adapter).

---

## Phasage (une story, deux phases séquentielles — point de split de contingence)

> **Décision de sizing** (cf. rapport) : **une seule story ES-3.0**, structurée en **deux phases séquentielles** — car les deux dettes convergent sur la **même surface `zcrud_core`** (le registre + le patron `extra`/immuabilité) et deux stories séparées exigeraient toutes deux l'**écriture exclusive de `zcrud_core`** (forcément sérialisées, aucun gain de parallélisme — règle « une seule story touche `zcrud_core` à la fois »). **Phase A (DW-ES14-2, BLOQUANTE)** doit être **verte et auto-contenue** avant d'entamer **Phase B (DW-ES24-1, patron)** : c'est le **point de split de contingence** si le dev-story stalle (→ Phase B liftée en `ES-3.0b`, sans rework).

---

## Acceptance Criteria

> Chaque AC est **testable à POUVOIR DISCRIMINANT** (rétro ES-2 §2, R12) : le test associé doit **ROUGIR par le retrait de la garde exacte** qu'il prétend prouver — jamais par un chemin de repli, un import interne, ou une coïncidence de valeur. L'orchestrateur **rejoue chaque injection R3** (retirer la garde → ROUGE **par cette garde**).

### Phase A — DW-ES14-2 (registre ⟶ extension typée + provenance) — BLOQUANTE

**AC1 — Slot d'injection additif dans `ZcrudRegistry`, `decode(kind, map)` PRÉSERVÉ.**
`ZcrudRegistry` gagne un **seam d'injection** (contexte/résolveur de décodage) permettant à `decode`/`encode` de **fournir aux `fromMap` d'entité** un `extensionParser` et un `ZSourceRegistry`. La signature publique **`decode(String kind, Map<String,dynamic> map)` et `encode(String kind, Object value)` reste INCHANGÉE** (l'ajout est **additif** — AD-10 ; la voie `FirebaseZRepositoryImpl.fromRegistry` continue d'appeler `registry.decode(kind, map)` **sans changer son call-site**). Un `ZcrudRegistry()` construit **sans** contexte se comporte **exactement** comme aujourd'hui (rétro-compat prouvée par test).

**AC2 — Le registrar généré THREAD le contexte dans la factory de domaine.**
Le `zcrud_generator` émet, pour toute entité **`ZExtensible`**, un enregistrement **conscient du contexte** : sur la voie registre, `Xxx.fromMap(map, extensionParser: <résolu depuis le contexte>, …)` est appelé — plus jamais le tear-off **nu**. Le générateur **ne connaît pas** les sous-classes concrètes d'extension (`ZNoteAudio` vit dans l'app, AD-4) : la résolution passe **par le contexte injecté**, qui **COMPOSE avec `ZTypeRegistry`/`ZSourceRegistry`** (AD-4 pt.3 `register(kind, fromJson, toJson)`) — il ne les **duplique pas**.

**AC3 — Round-trip REGISTRE préservant l'`extension` TYPÉE (POUVOIR DISCRIMINANT).**
Un `ZSmartNote` portant un `ZNoteAudio` valide (`format_version: 1`), décodé par `registry.decode('smart_note', map)` **avec un contexte câblant `ZNoteAudio.fromJsonSafe`**, revient avec `note.extension is ZNoteAudio` **`true`** (et ses champs `url`/`path`/`textHash` corrects) — **PAS** un `ZOpaqueNoteExtension`. Le ré-encodage `registry.encode(...)` réémet le payload à l'identique. **Preuve du pouvoir** : retirer le threading de l'AC2 fait **ROUGIR** ce test (`extension` retombe à `ZOpaqueNoteExtension`).

**AC4 — La provenance `ZSourceRegistry` est honorée sur la voie registre.**
Un canal de provenance ouvert (`ZSourceRegistry`, ex. variant `article`/flashcard) enregistré dans le contexte est **résolu** par `registry.decode` sur au moins un kind portant une provenance — un test **discriminant** (la provenance revient typée, pas opaque/`null`), non un test de fumée. *(Un seul slot d'injection porte `extensionParser` ET `sourceRegistry` — critère de clôture rétro §4/DW-ES14-2.)*

**AC5 — AD-10 intact : `decode` ne throw JAMAIS, préservation verbatim d'un inconnu.**
`registry.decode(kind, {})` **ne lève pas** (déjà verrouillé, l.394 du gate — à préserver). Un payload `extension` d'une **version future/non gérée** ou **corrompu** ⇒ `ZOpaqueNoteExtension` (payload **porté verbatim**, réémis bit-pour-bit) **ou** `null` — **jamais** un throw, **jamais** une destruction. Le contexte injecté **absorbe** toute exception d'un parser app (`ZExtension.guard`).

**AC6 — La CLAUSE MENSONGÈRE est SUPPRIMÉE.**
Le bloc dartdoc `firebase_z_repository_impl.dart` (clause d'échappement n°1, ~l.201-260, *« Quand utiliser `fromRegistry` malgré tout »* + tableau « DÉTRUIT/PORTÉ VERBATIM » + condition *« l'entité n'utilise pas le slot extension »*) est **supprimé/réécrit** : la voie registre **TYPE désormais** `extension`/`source`. Aucune prose ne subsiste qui déclare la voie registre destructrice de l'`extension` typée. `fromRegistry` est documentée comme **la voie recommandée** (elle porte enfin le contexte).

**AC7 — Le VERROU de dette DW-ES14-2 est INVERSÉ en test à pouvoir POSITIF.**
Le groupe `DW-ES14-2` de `reserved_keys_test.dart` (l.1368+), aujourd'hui un **verrou d'honnêteté** figeant la perte (`extension is! ZNoteAudio`, `toJson() == payload`), est **inversé** comme le prescrit son propre commentaire (l.1410-1413) : `extension is ZNoteAudio` **`isTrue`** + égalité du payload ré-encodé, **sur le kind extensible câblé**. Les **préconditions L2** (l.1415+ : `extension` reste clé réservée, ne fuit pas dans `extra`) sont **conservées** — sinon le verrou annoncerait un **FAUX signal de clôture**. Un **rouge provoqué** (retrait du threading) prouve que l'inversion a du pouvoir (R3/R12).

**AC8 — AD-1 intact : `zcrud_core` reste le SINK, CORE OUT=0, graphe ACYCLIQUE.**
Le registre (et le nouveau type de contexte) **ne gagne AUCUNE arête sortante** : le contexte ne porte que des types **de `zcrud_core`** (`ZExtension`, `ZTypeRegistry`, `ZSourceRegistry` y vivent déjà). `graph_proof` reste **acyclique, CORE OUT=0** sur les 18 nœuds. `melos run analyze` **ET** `melos run verify` **repo-wide** verts (R9 : la vérif ciblée par package ne détecte pas une régression cross-package).

**AC9 — TOUS les registrars régénérés et committés ; gates VERTS.**
Le changement de forme du registrar régénère **les 16 `.g.dart`** portant un `register…` (repo-wide — dont les **9 entités canoniques éducatives** nommées : `z_flashcard_tag`, `z_folder_contents_order`, `z_study_document`, `z_document_reading_state`, `z_smart_note`, `z_exam`, `z_study_podcast`, `z_study_folder`, `z_study_session_config`). **Tous** sont régénérés (`melos run generate`) et **committés** (gate `codegen-distribution` : un `part` visant un `.g.dart` gitignoré ou périmé = ROUGE). Le gate `reserved-keys` (volet A comportemental + `prove_gates`) reste **VERT** : les registrars changent de forme mais restent **câblés et observés**.

**AC10 — Le PROTOTYPE R4 de l'API du registre est documenté avant figement.**
La **forme exacte du seam** (contexte comme **champ de constructeur** de `ZcrudRegistry` ? **paramètre** additif de `decode` ? **closure** de résolution stockée dans le `ZModelCodec` ?) est **prototypée (R4)** sur ≥ 1 kind réel (`smart_note`) **avant** d'être figée, et le **choix + sa justification** (rétro-compat, impact generator/`.g.dart`/firestore, AD-1) sont consignés dans les Dev Agent Record. *(Recommandation de départ, à valider par le spike : contexte injecté au **constructeur** de `ZcrudRegistry` + décodeur conscient du contexte stocké dans le `ZModelCodec` — préserve `decode(kind,map)` et le call-site firestore.)*

### Phase B — DW-ES24-1 (immuabilité PATRON, uniforme) — non bloquante pour le store

**AC11 — Patron « slot brut privé + accesseur immuabilisant PROFOND » appliqué UNIFORMÉMENT aux 5 canaux.**
Les 5 canaux (`qualityByPage`, `learning`→son `qualityByPage`, `content`, `sectionOrders`, `byQuality`) exposent leur collection via un **accesseur** qui rend une **vue `unmodifiable` PROFONDE** (map **ET** listes/maps internes), **inconditionnellement** — y compris quand l'instance vient du **ctor `const` invoqué non-const** avec une réf mutable retenue. Le fix est **UNIFORME** : corriger 1 entité et pas les 4 autres crée une **incohérence** (R11 — *« corriger une seule entité crée une incohérence et laisse le motif se répandre »*).

**AC12 — Test à pouvoir DISCRIMINANT par entité : muter une collection interne obtenue via ctor `const` non-const ⇒ `UnsupportedError`.**
Pour **CHAQUE** des 5 canaux : construire l'entité par son **constructeur nominal** (invoqué non-const) avec une collection mutable, puis tenter de muter la collection **obtenue via l'accesseur** (`.add`/`[k]=`, **et une collection interne imbriquée** pour les canaux à 2 niveaux `sectionOrders`/`content`) ⇒ **`UnsupportedError`**. Retirer l'accesseur immuabilisant fait **ROUGIR** ce test (R3/R12).

**AC13 — `const` PRÉSERVÉ, ZÉRO `assert`, AD-10 intact.**
Le constructeur nominal **reste `const`** (surface publique inchangée — `ZFlashcard`/`ZSmartNote` sont consommées par DODLP). **Aucun `assert`** n'est ajouté (AD-10 : le décodeur généré appelle le ctor avec des valeurs **brutes** ; un `assert` ferait throw la désérialisation d'une donnée corrompue). `fromMap`/`fromJson` **ne throw JAMAIS** (`decode({})` reste `returnsNormally`). L'`==`/`hashCode` **profonds** restent cohérents (une instance relue du store `==` la même en mémoire).

**AC14 — Zéro-copie sur le chemin `fromMap`/`copyWith` préservé OU explicitement justifié.**
Le patron `extra` d'ES-2.2b rend **le slot lui-même** (`identical`) quand il est déjà propre (zéro copie sur le chemin chaud, asserté par `(i.3)`). Pour l'immuabilité, l'accesseur **préserve** cette propriété (retourne la collection déjà `unmodifiable` si elle l'est, sans re-wrap coûteux) **OU** le coût d'une vue est **mesuré et justifié** par écrit (R4/spike). Aucun re-wrap silencieux sur chaque lecture non documenté.

### Transverses (les deux phases)

**AC15 — Chaque garde ajoutée/modifiée naît avec sa FIXTURE d'échec ISOLÉE (R2) + injection R3 rejouée.**
Toute nouvelle assertion machine (gate `reserved-keys`/`prove_gates`, ou test unitaire de garde) porte une **fixture d'échec isolée** (une par forme) qui la fait **rougir seule**. L'orchestrateur **rejoue** l'injection R3 (retrait de la garde exacte → ROUGE **par cette garde**, restauration par **édition ciblée**, jamais `git checkout` — **R13**). Détection par **AST**, jamais par regex (R5). **Aucun test powerless** (R12).

**AC16 — Vérif verte repo-wide.**
`melos run generate` OK → `dart/flutter analyze` (`melos run analyze` **repo-wide**) RC=0 → `flutter test` (`melos run test`) RC=0 → `melos run verify` (graph_proof + secrets + codegen-distribution + reserved-keys) **repo-wide** VERT. Rejoué **réellement sur disque** par l'orchestrateur (jamais sur la foi d'un rapport d'agent — R9).

---

## Tasks / Subtasks

- [x] **T0 — Spike R4 : prototyper la forme du seam d'injection du registre (AC1, AC2, AC10).** *(à faire AVANT de figer l'API)*
  - [x] Lire `packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart` (frozen `ZModelCodec`, `register`/`decode`/`encode`), `z_open_registry.dart` (base `ZTypeRegistry`/`ZSourceRegistry`), `z_extension.dart`, `z_extensible.dart`.
  - [x] Prototyper ≥ 2 formes sur le kind `smart_note` : (a) contexte au **constructeur** `ZcrudRegistry({ZDecodeContext? context})` + décodeur conscient du contexte dans `ZModelCodec` ; (b) **paramètre** additif `decode(kind, map, {context})`. Choisir celle qui **préserve `decode(kind,map)`** et le call-site `FirebaseZRepositoryImpl.fromRegistry`, **compose** avec `ZTypeRegistry`/`ZSourceRegistry` (AD-4, pas de duplication), et **n'ajoute aucune arête sortante** à `zcrud_core` (AD-1).
  - [x] Consigner le choix + justification (rétro-compat / impact generator+16 `.g.dart`+firestore / AD-1) dans Dev Agent Record. **Jeter le prototype** (spike jetable) avant l'implémentation propre.
- [x] **T1 — `zcrud_core` : implémenter le seam d'injection (AC1, AC5, AC8).**
  - [x] Ajouter le type de contexte/résolveur (pur `zcrud_core` — `ZExtension`/`ZTypeRegistry`/`ZSourceRegistry` uniquement ⇒ CORE OUT=0).
  - [x] Étendre `register`/`ZModelCodec` **additivement** (AD-10) pour porter le décodeur conscient du contexte ; `decode`/`encode` threadent le contexte injecté ; `ZcrudRegistry()` sans contexte = comportement **identique** (test de rétro-compat).
  - [x] Absorber toute exception de parser app en `null`/opaque (AD-10) — le parent survit toujours.
- [x] **T2 — `zcrud_generator` : émettre le registrar conscient du contexte (AC2, AC9).**
  - [x] Modifier `_emitRegister` (`zcrud_model_generator.dart:692`) pour threader le contexte dans `Xxx.fromMap(map, extensionParser: …, …)` sur la voie registre, pour toute classe `ZExtensible`. Préserver le garde exécutoire `_$zRequireExtraPreserved` (DW-ES14-1).
  - [x] Adapter les tests du générateur (`test/zcrud_model_generator_test.dart`, `test/build_failure_test.dart`, `test/dp12_dp13_projection_test.dart`) à la nouvelle forme émise.
- [x] **T3 — Régénérer et committer TOUS les `.g.dart` (AC9).**
  - [x] `melos run generate` ; vérifier que **les 16 registrars** sont régénérés (dont les 9 nommés). Committer les `packages/*/lib/**/*.g.dart` (suivis par git — dép. git ; gate `codegen-distribution`).
- [x] **T4 — `zcrud_firestore` : câbler le contexte + SUPPRIMER la clause mensongère (AC1, AC6).**
  - [x] `FirebaseZRepositoryImpl.fromRegistry` porte/transmet le contexte (call-site `registry.decode(kind, map)` inchangé si le contexte est un champ du registre).
  - [x] **Supprimer/réécrire** le bloc dartdoc de clause d'échappement (~l.201-260) ; documenter `fromRegistry` comme voie recommandée typée.
- [x] **T5 — Inverser le verrou DW-ES14-2 + preuve positive (AC3, AC4, AC7, AC15).**
  - [x] Inverser le groupe `DW-ES14-2` (`reserved_keys_test.dart:1368+`) : `extension is ZNoteAudio` `isTrue` + égalité payload ; **conserver** les préconditions L2.
  - [x] Ajouter le test discriminant `ZNoteAudio` round-trippé **typé** par le registre (AC3) + provenance `ZSourceRegistry` typée (AC4).
  - [x] Rejouer R3 : retirer le threading ⇒ ROUGE **par ces tests** ; restaurer par édition ciblée (R13).
- [x] **T6 — Phase B : appliquer le patron immuabilité aux 5 canaux (AC11, AC13, AC14).** *(après Phase A verte)*
  - [x] Prototyper (R4) l'accesseur immuabilisant **profond** (vue vs copie ; zéro-copie du chemin chaud) sur 1 canal, puis appliquer **UNIFORMÉMENT** : `qualityByPage`, `learning`, `content`, `sectionOrders`, `byQuality`. Factoriser un helper `zcrud_core` si le patron est partagé (comme `zNormalizeExtra`).
  - [x] Conserver `const`, zéro `assert`, `fromMap`/`fromJson` non-throw, `==`/`hashCode` profonds.
- [x] **T7 — Tests discriminants d'immuabilité par entité (AC12, AC15).**
  - [x] Pour chaque canal : ctor nominal non-const + mutation via accesseur (dont imbriqué) ⇒ `UnsupportedError`. Rejouer R3 (retrait de l'accesseur → ROUGE).
- [x] **T8 — Vérif verte repo-wide + gates (AC8, AC9, AC16).**
  - [x] `melos run generate` → `melos run analyze` (repo-wide) → `melos run test` → `melos run verify` (graph_proof CORE OUT=0 + secrets + codegen-distribution + reserved-keys). Rejoué réellement sur disque.

---

## Dev Notes

### Architecture & patrons à respecter (NON-NÉGOCIABLES)

- **AD-1 — `zcrud_core` = SINK, CORE OUT=0** (`architecture.md:43`). Le registre et le contexte de décodage ne portent **que** des types déjà dans `zcrud_core` (`ZExtension`, `ZTypeRegistry`, `ZSourceRegistry`, `ZModelCodec`). **Aucune arête sortante** ajoutée. Gate `graph_proof` acyclique + `melos analyze`/`verify` **repo-wide** à chaque commit d'epic (R9). *Rappel R10-R11 : « un symbole public supprimé dans un package et référencé par un autre » — `melos analyze` REPO-WIDE seul l'attrape (cf. `ZExportApi` E11a-3).*
- **AD-3 — codegen, `reflectable` banni** (`architecture.md:350`). Le `zcrud_generator` reste **la source du câblage** ; jamais de réflexion runtime. Ne **jamais** éditer un `.g.dart` à la main — mais **TOUJOURS committer** ceux de `packages/*/lib/` régénérés (gate `codegen-distribution`).
- **AD-4 — `ZExtension` + registres ouverts** (`architecture.md:46`, `:273`). La résolution typée **COMPOSE** avec `ZTypeRegistry`/`ZSourceRegistry.register(kind, fromJson, toJson)` — **jamais** un `switch` exhaustif, **jamais** une duplication de ces registres. Rejetés : héritage de classes sérialisées, `sealed` pour l'extension inter-package.
- **AD-10 — désérialisation défensive** (`architecture.md:50`, `:180`). `decode` ne throw **JAMAIS** ; un `ZExtension` inconnu/corrompu/version-future → `ZOpaqueNoteExtension` (verbatim) ou `null`, **jamais** throw, **jamais** destruction. Évolution **additive seulement** (le seam est un ajout, pas un changement de signature de `decode`).

### État ACTUEL des fichiers à modifier (lus sur disque)

- **`packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart`** — `ZModelCodec{kind, fromMap: ZFromMap, toMap}` est **`const`, sans `==`** ; `register<T>(kind, {fromMap, toMap, fieldSpecs})` ; `decode(kind, map) => codecFor(kind).fromMap(map)` ; `encode(kind, value) => codecFor(kind).toMap(value)`. Le slot `fieldSpecs` a **déjà** été ajouté additivement (précédent d'extension additive à imiter). Le seam d'extension/source doit suivre **le même geste additif**.
- **`packages/zcrud_generator/lib/src/zcrud_model_generator.dart:692`** (`_emitRegister`) — émet `registerXxx(ZcrudRegistry registry)` : pour `!extensible`, un `register<T>(...)` nu ; pour `ZExtensible`, précédé du garde `_$zRequireExtraPreserved<T>(...)` (DW-ES14-1, à **préserver**). `registerArgs` câble `fromMap: $className.fromMap` en **tear-off nu** — **c'est le point exact à threader**.
- **`packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:261`** (`fromRegistry`) — `fromMap: (map) => registry.decode(kind, map) as T`, `toMap: (value) => registry.encode(kind, value)`. La dartdoc l.158-260 contient la **clause mensongère** (l.201-229) + le tableau DÉTRUIT/VERBATIM + le renvoi à DW-ES14-2. **À supprimer/réécrire** (AC6).
- **`packages/zcrud_note/lib/src/domain/z_smart_note.dart:154`** (`fromMap(map, {extensionParser})`) + `_decodeExtension(raw, parser)` (l.395) — cas 3 (aucun parser / version future) ⇒ `ZOpaqueNoteExtension` (verbatim). `ZNoteAudio.fromJsonSafe` (`z_note_audio.dart:131`) est le parser typé. `ZOpaqueNoteExtension` (`z_opaque_note_extension.dart`) porte le payload verbatim.
- **Patron `extra` de référence** — `zNormalizeExtra`/`zSanitizeExtra` (`z_extensible.dart:77-130`) : **slot brut privé `_extra` + accesseur `get extra => zNormalizeExtra(_extra, _reservedKeys)`**, zéro-copie si déjà propre (`identical`), asserté par `(i.3)`. **C'est le MODÈLE littéral de DW-ES24-1.**
- **Cibles DW-ES24-1** — `ZDocumentLearningInfo._guard`/`qualityByPage` (`z_document_learning_info.dart:57,136`), `ZFolderContentsOrder.sectionOrders`/`_decodeSectionOrders` (`z_folder_contents_order.dart:139,189`), `ZStudySessionResult.byQuality`/`_decodeByQuality` (`z_study_session_result.dart`), `ZSmartNote.content`/`normalizeNoteContentOps` (`z_smart_note.dart:213`), `ZDocumentReadingState.learning` (compose `ZDocumentLearningInfo`). Tous ont aujourd'hui l'immuabilité **aux frontières `fromMap`/`copyWith` seulement** — le ctor `const` retient la réf **brute**.

### Le verrou de dette à inverser (mécanique exacte)

`reserved_keys_test.dart:1368-1447` boucle sur `kProbeBodies.keys \ kNonExtensibleKinds`, injecte un `extension` payload, `registry.decode` puis `registry.encode`. Aujourd'hui il **asserte la perte** (`isFalse`/`toJson()==payload`) avec les **préconditions L2** (`extension` reste réservée, ne fuit pas dans `extra`). Le commentaire l.1410-1413 **prescrit l'inversion** : `isTrue` + égalité du payload ré-encodé quand la dette est soldée. **Conserver L2** (sinon faux signal de clôture). Le pouvoir se prouve par **rouge provoqué** (retrait du threading AC2 → l'inversion rougit).

### Testing standards

- Framework : `flutter test` / `dart test` (`*_test.dart`) par package + harnais `tool/reserved_keys_gate/` (`--tags reserved-keys`, lancé par `scripts/ci/gate_reserved_keys.dart`, `exit 79` FATAL) + `scripts/ci/prove_gates.dart` (fixtures isolées).
- **R2** : chaque garde naît avec sa fixture d'échec **isolée** (une par forme). **R3** : injection de régression rejouée par l'orchestrateur (retrait garde → ROUGE par cette garde). **R5** : AST (`package:analyzer`), jamais regex. **R12** : aucun test powerless (rougit **par le retrait de la garde exacte**, pas par un import interne / repli / coïncidence). **R13** : restauration d'injection par **édition ciblée**, jamais `git checkout`.
- **Rétro-compat sérialisation** (gate E2-10) : corpus défensif, `decode({})` non-throw, enums inconnus → défaut. La voie registre **avec** contexte reste défensive.

### Références

- [Source: `_bmad-output/implementation-artifacts/stories/epic-es-2-retrospective.md` §2.3, §4 (DW-ES14-2 / DW-ES24-1), §6 (R10-R13), §7 (verdict)]
- [Source: `_bmad-output/implementation-artifacts/sprint-status.yaml` — entrée `es-3-0-registre-preserve-extension-immuabilite` + blocs « Dettes ouvertes » DW-ES14-2/DW-ES24-1]
- [Source: `packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart` (registre gelé, extension additive du slot `fieldSpecs` = précédent)]
- [Source: `packages/zcrud_generator/lib/src/zcrud_model_generator.dart:692` (`_emitRegister`, tear-off nu à threader)]
- [Source: `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:201-280` (clause mensongère + `fromRegistry`)]
- [Source: `packages/zcrud_note/lib/src/domain/{z_note_audio,z_opaque_note_extension,z_smart_note}.dart` (1ʳᵉ `ZExtension` concrète + mitigation)]
- [Source: `packages/zcrud_core/lib/src/domain/extension/z_extensible.dart:77-130` (patron `extra` = modèle DW-ES24-1)]
- [Source: `tool/reserved_keys_gate/test/reserved_keys_test.dart:1368-1447` (verrou DW-ES14-2 à inverser)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md:43,46,50,180,189-197,273` (AD-1/4/10, gate reserved-keys AST)]
- [Source: `CLAUDE.md` — AD invariants, gate codegen-distribution, cycle BMAD strict]

### Project Structure Notes

- Packages touchés : **`zcrud_core`** (registre + contexte + éventuel helper immuabilité), **`zcrud_generator`** (émission registrar), **`zcrud_firestore`** (câblage contexte + suppression clause), **`zcrud_note`/`zcrud_document`/`zcrud_study_kernel`** (5 canaux DW-ES24-1), **`tool/reserved_keys_gate`** (verrou inversé + fixtures), **`scripts/ci`** (prove_gates si fixture ajoutée). **16 `.g.dart`** régénérés repo-wide.
- **Point de contact unique `zcrud_core`** : cette story l'écrit — donc **strictement séquentielle** (aucune autre story ES-3 ne touche `zcrud_core` en parallèle). Écritures du sprint-status **sérialisées et ciblées par l'orchestrateur** ; le dev-story/code-review **ne touchent PAS** le sprint-status.
- **Variance assumée** : le sprint-status nomme **9** `.g.dart` (les entités canoniques éducatives extensibles) ; le changement de forme du registrar régénère en réalité **les 16** registrars du repo — **tous** doivent être régénérés/committés (le gate `codegen-distribution` échouerait sur un registrar périmé). Ce n'est pas un écart de périmètre mais la conséquence mécanique du changement de générateur.

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story).

### Spike T0 (R4) — forme d'API retenue

**Deux formes prototypées sur le kind `smart_note`** :
- **(a)** `ZDecodeContext` **champ du constructeur** de `ZcrudRegistry` + décodeur conscient du contexte porté par `ZModelCodec` (`fromMapWithContext`/`toMapWithContext`, additifs `null` par défaut) ;
- **(b)** paramètre additif `decode(kind, map, {context})`.

**Forme (a) RETENUE — recommandation de la story VALIDÉE (non changée).** Justification consignée : (a) **préserve la signature publique `decode(kind, map)`/`encode(kind, value)`** (AD-10 additif) ⇒ le call-site `FirebaseZRepositoryImpl.fromRegistry` (`registry.decode(kind, map)`) reste **INCHANGÉ** (contexte câblé une fois au bootstrap). (b) aurait cassé la signature de `decode` et forcé chaque call-site à threader le contexte — rejetée. Le générateur émet la variante consciente du contexte en **détectant sur l'AST** les paramètres nommés `extensionParser`/`sourceRegistry` de la factory de domaine (R5, jamais de regex) : il ne connaît AUCUNE sous-classe concrète d'extension (`ZNoteAudio` vit dans l'app, AD-4) — il thread le `ZDecodeContext`. `ZDecodeContext` ne porte que des types **déjà dans `zcrud_core`** (`ZExtension`/`ZTypeRegistry`/`ZSourceRegistry`) ⇒ **CORE OUT=0** (graph_proof acyclique confirmé). Compose avec `ZSourceRegistry` (threadé tel quel) et un résolveur d'extension **par kind** (l'app peut le brancher sur son `ZTypeRegistry`) — **aucune duplication** de ces registres.

### Debug Log References

Injections R3 rejouées (restauration par ÉDITION CIBLÉE, jamais `git checkout`) :
- **(a)** neutraliser le threading dans `ZcrudRegistry.decode` ⇒ test discriminant « smart_note : extension revient TYPÉ ZNoteAudio » **ROUGE** (`Actual: ZOpaqueNoteExtension`, RC=1) ; restauré → VERT (fichier IDENTIQUE au backup).
- **(c)** neutraliser l'accesseur immuabilisant de `ZDocumentLearningInfo.qualityByPage` ⇒ test `UnsupportedError` **ROUGE** (`Actual: <Closure: () => int>`, RC=1) ; restauré → VERT.
- **(d)** dépouiller le registrar régénéré `z_smart_note.g.dart` de `fromMapWithContext` ⇒ gate `reserved-keys` **ROUGE** (RC=1, discriminant ZNoteAudio) ; restauré par régénération → gate RC=0 (diff vs HEAD = 6 lignes additives ES-3.0).
- **(b)** clause mensongère = **dartdoc pure** (zéro comportement runtime) ⇒ « bien morte » : suppression vérifiée par absence (grep), aucun test à faire rougir.

### Completion Notes List

**Phase A (DW-ES14-2, BLOQUANTE) — SOLDÉE.** La voie registre TYPE désormais `extension`/`source` via un `ZDecodeContext` injecté (spike (a)). Preuve DISCRIMINANTE : `registry.decode('smart_note', map)` avec un contexte câblant `ZNoteAudio.fromJsonSafe` revient `extension is ZNoteAudio` (url/path/textHash corrects, round-trip payload identique) — plus un `ZOpaqueNoteExtension`. Provenance `ZSourceRegistry` honorée (AC4). Surface publique **ADDITIVE** : `ZcrudRegistry()` sans contexte = comportement identique (rétro-compat prouvée) ; `decode`/`encode`/`const` des entités inchangés. Clause mensongère de `firebase_z_repository_impl.dart` **SUPPRIMÉE**, `fromRegistry` documentée comme voie recommandée typée. Verrou DW-ES14-2 + tests source H2 **INVERSÉS** en preuve positive (préconditions L2 conservées). Gate AST `reserved-keys` étendu : un champ privé backé par un accesseur concret est keyé sur son accesseur PUBLIC (généralisation du cas `_extra`).

**Phase B (DW-ES24-1, PATRON) — SOLDÉE (UNIFORME sur les 5 canaux).** Helper cœur `zUnmodifiable*` (vue PROFONDE, idempotente/zéro-copie sur le chemin chaud — AC14) posé sur l'ACCESSEUR de chaque canal (slot brut privé + getter), patron `extra`. Preuve par entité : muter une collection interne obtenue via ctor `const` invoqué non-const ⇒ `UnsupportedError` (dont niveau imbriqué pour `content`/`sectionOrders`). `const` PRÉSERVÉ, ZÉRO `assert`, `fromMap`/`fromJson` non-throw (AD-10).

**Vérif verte REPO-WIDE rejouée sur disque** : `melos generate` OK (16 registrars, 12 context-aware régénérés+committables) → `melos analyze` RC=0 → `melos test` SUCCESS (tous packages ; core 927, document 170, note 134, kernel 273, generator 102, firestore 90…) → `gate_reserved_keys` RC=0 → `prove_gates` 41 OK/0 FAIL → `graph_proof` ACYCLIQUE + CORE OUT=0 → `melos verify` RC=0. Gate `reserved-keys` (harnais) 118 tests VERT dont discriminant ZNoteAudio.

**Décisions remises en cause / dettes** : (1) forme (a) validée, non changée. (2) `depend_on_referenced_packages` : les tests des packages pur-Dart utilisent `package:test` (pas `flutter_test`) — corrigé. (3) 2 `info` PRÉEXISTANTS dans `z_document_viewer_prefs_test.dart` (non touché) — hors périmètre, `analyze` RC=0. (4) Aucune nouvelle dette introduite.

### File List

- `packages/zcrud_core/lib/src/domain/registry/z_decode_context.dart` (NEW) — `ZDecodeContext` + `ZExtensionResolver`.
- `packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart` — `ZModelCodec.fromMapWithContext/toMapWithContext` + ctor `decodeContext` + threading `decode`/`encode` (additif).
- `packages/zcrud_core/lib/src/domain/collection/z_immutable_view.dart` (NEW) — helpers `zUnmodifiableScalarMap`/`zUnmodifiableScalarList`/`zUnmodifiableMapOfLists`/`zUnmodifiableJsonMapList`.
- `packages/zcrud_core/lib/domain.dart` — exports des deux nouveaux fichiers.
- `packages/zcrud_core/test/domain/registry/z_decode_context_test.dart` (NEW) — seam AC1/AC3/AC4/AC5 + R3.
- `packages/zcrud_generator/lib/src/zcrud_model_generator.dart` — `_ContextShape` + `_contextShapeOf` + `_emitRegister` conscient du contexte.
- `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` — clause mensongère SUPPRIMÉE, dartdoc `fromRegistry` réécrite (call-site inchangé).
- `packages/zcrud_note/lib/src/domain/z_smart_note.dart` — `content` accesseur immuable (slot `_content`).
- `packages/zcrud_note/lib/src/domain/z_note_content.dart` — `_freeze` gel PROFOND.
- `packages/zcrud_document/lib/src/domain/z_document_learning_info.dart` — `qualityByPage` accesseur immuable (slot `_qualityByPage`).
- `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart` — `sectionOrders` accesseur immuable PROFOND (slot `_sectionOrders`).
- `packages/zcrud_study_kernel/lib/src/domain/z_study_session_result.dart` — `byQuality` accesseur immuable (slot `_byQuality`).
- `packages/zcrud_{document,note,study_kernel}/test/dw_es24_1_immutability_test.dart` (NEW) — AC12/AC13/AC14 par canal.
- `tool/reserved_keys_gate/lib/src/registrars.dart` — `buildRegistry({decodeContext})`.
- `tool/reserved_keys_gate/test/reserved_keys_test.dart` — groupes DW-ES14-2 + H2 source INVERSÉS en preuve positive (import `zcrud_note`).
- `scripts/ci/gate_reserved_keys.dart` — règle (g) : canal keyé sur l'accesseur public pour un slot privé backé.
- **12 `*.g.dart`** régénérés (registrars context-aware) : `z_flashcard`, `z_repetition_info`, `z_smart_note`, `z_study_folder`, `z_study_session_config`, `z_study_podcast`, `z_flashcard_tag`, `z_folder_contents_order`, `z_study_document`, `z_document_reading_state`, `z_document_annotation`, `z_exam`.
