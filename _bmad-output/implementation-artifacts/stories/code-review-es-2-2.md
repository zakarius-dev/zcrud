# Code Review — ES-2.2 : Note intelligente à contenu typé (`ZSmartNote`, `zcrud_note`)

- **Story** : `_bmad-output/implementation-artifacts/stories/es-2-2-note-intelligente-contenu-type.md` (14 ACs, D1..D11)
- **Skill** : `bmad-code-review` (invoqué via le tool `Skill` — **pas** de fallback disque)
- **Date** : 2026-07-13 · **Reviewer** : revue adversariale (Blind Hunter / Edge Case Hunter / Acceptance Auditor)
- **Diff** : working tree non committé, cadré sur le périmètre ES-2.2
  (`packages/zcrud_note/**` [NOUVEAU], root `pubspec.yaml`, `tool/reserved_keys_gate/{pubspec.yaml,lib/src/registrars.dart}`)
- **Verdict initial** : ⛔ **CHANGES REQUESTED** — 1 HIGH, 3 MAJEURS, 1 MEDIUM, 4 LOW.
- **Méthode** : **toutes** les assertions ci-dessous sont **MESURÉES EN MACHINE**
  (sondes Dart exécutées contre le package réel via
  `dart --packages=.dart_tool/package_config.json`), jamais déduites de la lecture.

---

## ✅ REMÉDIATION (2026-07-13) — statut de CHAQUE finding

**Les 5 findings ont d'abord été REPRODUITS en machine** (sonde `/tmp/zp/before.dart` exécutée
contre le package réel), puis corrigés, puis **chaque filet ajouté a été PROUVÉ PAR INJECTION DE
RÉGRESSION** (casse ⇒ ROUGE observé ⇒ restauration ⇒ VERT) — **R3**.

| # | Sévérité | Statut | Preuve |
|---|---|---|---|
| **HIGH-1** — `List` partiellement valide ⇒ `[]` (perte totale du corps) | 🔴 | ✅ **CORRIGÉ** | `_deltaOpsStrict` (décision, **tout-ou-rien**) **≠** `_coerceOpsPreserving` (branche `List` native, **préservante**). **Le test qui ENTÉRINAIT la perte est SUPPRIMÉ et INVERSÉ.** Injection ① : tout-ou-rien restauré ⇒ **3 ROUGES** (dont l'invariant absolu). |
| **MAJEUR-1** — `ZNoteAudio` détruite par la voie registre (DW-ES14-2) | 🟠 | ✅ **CORRIGÉ (donnée) + ESCALADÉ + ÉPINGLÉ (type)** | `ZOpaqueNoteExtension` : le payload non typé est **réémis VERBATIM** (avant : **effacé du store**). Le **TYPE** reste perdu (⇒ `zcrud_core`, **D9**) : verrou local + verrou harnais **bi-régime** + **escalade DW-ES14-2** (clause n°1 **FALSIFIÉE**). Injection ③ ⇒ **5 ROUGES** (package) **+ 1 ROUGE** (gate). |
| **MAJEUR-2** — `format_version` future ⇒ payload détruit | 🟠 | ✅ **CORRIGÉ** | Même canal : un parser qui rend `null` (version inconnue) **ne détruit plus rien**. Test : une app **v1** relit une note **v2**, en change le **titre**, réécrit ⇒ **le slot v2 est INTACT**. |
| **MAJEUR-3** — `copyWith(extra:)` rouvre le filtre réservé | 🟠 | ✅ **CORRIGÉ** (+ **SYSTÉMIQUE ESCALADÉ**) | Garde **nommée UNIQUE** `_sanitizeExtra`, appelée par **`fromMap` ET `copyWith` ET `toMap`**. Injections ② et ②-bis ⇒ **3 ROUGES** puis **1 ROUGE**. ⚠️ **Le même défaut est MESURÉ sur `ZStudyDocument`, `ZDocumentReadingState`, `ZStudyFolder`** ⇒ dette **DW-ES22-3**. |
| **MEDIUM-1** — `==`/`hashCode` superficiels sur `extra` | 🟡 | ✅ **CORRIGÉ** (+ **SYSTÉMIQUE ESCALADÉ**) | `noteJsonEquals`/`noteJsonHash` (profonds). Injection ④ ⇒ **1 ROUGE**. ⚠️ Mesuré cassé sur `ZStudyDocument`/`ZStudyFolder` ⇒ dette **DW-ES22-4**. |
| **L1** — mutabilité incohérente | 🔵 | ✅ **CORRIGÉ** | `_freeze` : **vide COMME plein** non modifiable (test `throwsUnsupportedError`). |
| **L2** — `'{"ops":[…]}'` traité comme du texte | 🔵 | 🟡 **CONSIGNÉ** (aucune perte : le texte survit) — à statuer en **ES-6.2** (acceptation d'un `Map` portant une clé `ops`). |
| **L3** — `try/catch` mort | 🔵 | ✅ **CORRIGÉ** | 3 sites supprimés (`z_note_content`, `z_smart_note`, `z_note_audio`) — **R6** : aucun filet décoratif. |
| **L4** — harnais = point de contact structurel (process) | 🔵 | ⏭️ **POUR L'ORCHESTRATEUR** (rétro ES-2). Non traité ici (délibérément). |
| **DW-ES22-1** — divergence sous-évaluée | 🔴 | ✅ **ÉPINGLÉE EN MACHINE** + **RÉÉVALUÉE en architecture** | Verrou `source_policy_test.dart` › `DW-ES22-1`. ⚠️ **RÉFUTATION PARTIELLE du geste demandé** : un verrou **exécutant les deux** fonctions est **impossible** (`DeltaNeutralOps` **privé, non exporté** + `zcrud_markdown` est **Flutter**) ⇒ le verrou **exécute** le côté `zcrud_note` et **fige le côté `zcrud_markdown` par sa SOURCE**. |

**Vérif verte rejouée (repo-wide)** : `generate` RC=0 · `analyze` RC=0 · `verify` RC=0 ·
`prove_gates` **41 OK / 0 FAIL** · `gate:web` OK · `graph_proof` **ACYCLIQUE / CORE OUT=0** ·
`melos list` = **17**.
**Tests** : `zcrud_note` **130** (+26) · harnais **49** (inchangé) · `zcrud_document` **129** ·
`zcrud_generator` **102** · `zcrud_flashcard` **189** · `zcrud_study_kernel` **108** ·
`zcrud_core` **911** · `zcrud_firestore` **90** · `zcrud_mindmap` **110** — **aucune régression**.

**Périmètre tenu** : **aucune** ligne de `zcrud_core`, `zcrud_study_kernel`, `zcrud_markdown`,
`zcrud_document`, `zcrud_flashcard` écrite (D9). ⚠️ **RESTE DÛ (hors périmètre)** :
`packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:207-212` — la **clause
d'échappement n°1** de DW-ES14-2 (*« si et seulement si l'entité n'utilise pas le slot
`extension` »*) est désormais **FACTUELLEMENT FAUSSE** (`ZNoteAudio` la falsifie) et **autorise
encore** le câblage d'un store. **À corriger par la story qui solde DW-ES14-2**, ou par un geste
dédié de l'orchestrateur.

---

---

## 0. Ce qui est SOLIDE (à ne pas défaire)

Cette story est, sur la forme, la mieux instrumentée de l'epic. Le crédit est réel :

- ✅ **Les 4 injections R3 ont été VUES ROUGIR** (rejouées par l'orchestrateur : `kContentKey` retiré ⇒ gate **RC=1**, rouge par **(g1)** [AST] **et** **(f)** [comportemental]). Les règles **(f)/(g1)/(g2)/(h)** — nées du finding H1 d'ES-2.1 — **mordent sur une entité que le gate n'avait jamais vue**, et le harnais passe 46 → 49 tests **sans un seul test écrit à la main**. C'est exactement le contraire du motif dominant.
- ✅ **AC8 observe le POUVOIR, pas l'absence d'exception** (`z_smart_note_test.dart:503-507`) : le round-trip **par le registre** exige que la **valeur** de `content` survive **identique** (`encoded['content'].single == {'insert':'sonde\n'}`), pas seulement qu'aucune exception ne soit levée. **Non vacuous.**
- ✅ **R5 tenu, et vérifié au-delà du grep du dev.** J'ai grepé `lib/` moi-même (`startsWith|contains(|RegExp|indexOf|substring`) : les **seules** occurrences sont (a) dans des **commentaires** citant le code d'IFFD, (b) `_reservedKeys.contains(key)` — un lookup de `Set`, pas une heuristique textuelle. La détection Delta est **structurellement** faite (`jsonDecode` + forme). Le test-piège `'[ceci "insert" n\'est pas du JSON'` (`z_note_content_test.dart:256`) prouve la **discrimination** face à l'heuristique d'IFFD.
- ✅ **AD-19 / R-C** : zéro `updatedAt`/`isDeleted` ; `$ZSmartNoteFieldSpecs ∩ ZSyncMeta.reservedKeys == {}` **assertée explicitement** (`z_smart_note_test.dart:23`) — le M1 d'ES-2.1 **n'est pas rejoué**.
- ✅ **AD-1 / D4 / D7** : `zcrud_note` est **pur-Dart** (`zcrud_core` + `zcrud_annotations` **seuls**). L'invalidation de la prescription de l'epic (`zcrud_note → zcrud_markdown`) est **argumentée sur trois constats de disque** et **correcte** (`zcrud_markdown` est Flutter/Quill ; `DeltaNeutralOps` y est privé). **AD-28 est vérifié PAR MACHINE** (`source_policy_test.dart:61` : aucune classe `implements ZCodec`).
- ✅ **`gate:web` découvert par le dev, pas par la story** — et traité par le **bon geste** (`@TestOn('vm')` + **isolation**), ce qui a pour effet **non prévu** de faire rejouer la matrice D5 **en JS**. Bonne remontée pour ES-2.6.
- ✅ `hide ZSmartNoteZcrud` présent, **doublé** par le gate (h) et par un test de package. Aucun autre symbole généré ne fuit du barrel.

Les findings ci-dessous portent **tous** sur le **fond** : la **préservation des données**.

---

## 🔴 HIGH-1 — `normalizeNoteContentOps` : une `List` **partiellement valide** rend `[]` ⇒ **PERTE TOTALE du corps de la note**

> **La fermeture du piège D5 n'est PAS totale : elle est fermée sur la branche `String`, et GRANDE OUVERTE sur la branche `List`.**

**Fichier** : `packages/zcrud_note/lib/src/domain/z_note_content.dart:82` (branche `List`) → `:122-139` (`_opsFromList`)

`_opsFromList` est **tout-ou-rien** : au **premier** élément invalide, il rend `null`, et l'appelant (l. 82) retombe sur `kEmptyNoteContent`. **Toutes les ops valides qui précèdent sont détruites.**

### Scénario d'échec REPRODUCTIBLE (mesuré)

```dart
normalizeNoteContentOps(<Object?>[
  {'insert': 'Le corps entier de la note, 5000 mots...\n'},   // ← contenu RÉEL
  {'retain': 1},                                              // ← 1 élément parasite
]);
// MESURÉ ⇒ []      ⛔ PERTE TOTALE, silencieuse, irréversible au premier `put`.

normalizeNoteContentOps(<Object?>[
  {'insert': 'corps preservé ?\n'},
  null,                    // ← un `null` en queue de tableau JSON (écriture partielle)
]);
// MESURÉ ⇒ []      ⛔ idem.
```

### L'ASYMÉTRIE est la preuve que c'est un bug, pas un choix

Le **même payload**, présenté en `String`, est **intégralement préservé** :

```dart
normalizeNoteContentOps('[{"insert":"Le corps entier..."},{"retain":1}]');
// MESURÉ ⇒ [{insert: [{"insert":"Le corps entier..."},{"retain":1}]\n}]   ✅ préservé
```

Deux voies, **deux politiques opposées**, sur la **même donnée**. Une seule des deux peut être correcte, et D5 dit laquelle : *« si ce n'est pas du Delta, c'est du texte » — jamais `[]`.*

### La justification écrite est FAUSSE

`z_note_content.dart:74-76` :

> *« ⚠️ Une **`List` malformée** rend `[]` (et **non** du texte) : une liste n'est pas du texte — il n'y a **rien à préserver verbatim**. »*

**C'est faux.** Une liste malformée peut porter **des `insert` parfaitement valides** — c'est-à-dire **exactement** le corps de la note. La prémisse (« rien à préserver ») ne tient que pour `[1,2]` ; elle **ne tient pas** pour `[{insert:…}, {retain:1}]`. La fonction généralise à partir du cas dégénéré.

### Le test ÉPINGLE la perte (motif dominant, dixième instance)

`z_note_content_test.dart:120-126` **asserte** le comportement destructeur — sur une liste qui **contient une op valide** :

```dart
expect(
  normalizeNoteContentOps(<Object?>[
    <String, dynamic>{'insert': 'ok\n'},   // ← contenu RÉEL
    'pas une op',
  ]),
  isEmpty,                                  // ⛔ « vert » = la donnée est détruite
);
```

La matrice D5 a été validée sur son **EXISTENCE** (12 lignes, toutes vertes) — jamais sur son **POUVOIR** : personne n'a demandé *« cette ligne-là respecte-t-elle la règle que la fonction dit appliquer ? »*. **C'est le motif de la rétro ES-1, à l'intérieur même de l'artefact censé le combattre.**

### Atteignabilité

- `note.copyWith(content: ops)` depuis l'app (**ES-6.1**, l'éditeur) : un `Delta` ayant transité par `compose`/`transform`/`diff` porte des `retain`/`delete` ⇒ **wipe**.
- Toute écriture partielle / tronquée / fusionnée (LWW) laissant un `null` ou un scalaire dans le tableau ⇒ **wipe**.
- Tout écrivain tiers (migration ES-11.2, script d'import) ⇒ **wipe**.

### ⚠️ Le correctif n'est PAS trivial — piège à signaler au dev

Rendre `_opsFromList` **tolérant** (ignorer les éléments invalides, garder les `insert`) **casserait la DÉTECTION** sur la branche `String` : `'[1,2]'` deviendrait *« une liste d'ops valide… vide »* ⇒ `[]` ⇒ **le texte `'[1,2]'` serait détruit** (la ligne `z_note_content_test.dart:190-200` deviendrait rouge, à raison).

⇒ **Il faut DEUX fonctions distinctes**, pas une :
1. **`_isDeltaOps(List)` — STRICTE** (tout-ou-rien) : sert **uniquement** à *décider* si une `String` décodée est du Delta. Comportement actuel, **conservé**.
2. **`_coerceOps(List)` — TOLÉRANTE/PRÉSERVANTE** : sert à la branche **`List` native**. Garde les ops portant `insert`, **écarte** les éléments invalides, ne rend `[]` **que** si **aucune** op valide n'existe.

Et **ajouter la ligne manquante à la matrice** : *« `List` partiellement valide ⇒ les ops valides SURVIVENT »*, avec son test — et l'idempotence associée.

---

## 🟠 MAJEUR-1 — `ZNoteAudio` est la **PREMIÈRE `ZExtension` concrète**, et la **voie registre la DÉTRUIT** (DW-ES14-2). La story ne l'escalade **nulle part**.

**Fichiers** : `packages/zcrud_note/lib/src/domain/z_smart_note.dart:292-300` (`_decodeExtension`) · `:236-238` (`toMap`) · `z_smart_note.g.dart:235-240` (`registerZSmartNote` câble `fromMap: ZSmartNote.fromMap` **sans `extensionParser`**)

### Mesuré

```dart
final map = {'id':'n1','title':'t','content':[{'insert':'a\n'}],
             'extension': {'format_version':1,'url':'https://x/a.mp3','text_hash':'abc'}};
final n = ZSmartNote.fromMap(map);          // ← la voie du REGISTRE (aucun parser injectable)
// MESURÉ : n.extension                      == null
// MESURÉ : n.toMap().containsKey('extension') == false   ⛔ PAYLOAD PERDU
```

`'extension'` étant une clé **réservée**, elle **ne tombe pas non plus dans `extra`** : au prochain `put`, **le slot audio est effacé du store. Irréversible.**

### Pourquoi c'est un finding d'ES-2.2, alors que DW-ES14-2 est une dette CONNUE

DW-ES14-2 (`firebase_z_repository_impl.dart:207-212`) écrit **noir sur blanc** la condition sous laquelle `fromRegistry` reste utilisable :

> *« Si — et seulement si — **les trois** conditions tiennent : **1. l'entité n'utilise pas le slot `extension`** (aucun `ZExtension` typé dans ses documents) ; … »*

**ES-2.2 FALSIFIE cette condition n°1** : elle crée le **premier `ZExtension` typé du repo**. La dette passe de **théorique** à **atteignable**, sur l'entité même que la story livre — et **rien** ne le dit :

- ❌ La story ne mentionne **jamais** DW-ES14-2 (grep : 0 occurrence dans la story **et** dans `packages/zcrud_note/`).
- ❌ La dartdoc de `ZNoteAudio` vante le slot (« *premier cas réel* ») **sans un mot** sur sa destruction par la voie registre.
- ❌ **AC5 (« VOIE TYPÉE : `ZNoteAudio` round-trippe via `extension` »)** est **vert sur une voie qu'aucun câblage de production n'emprunte** : `z_smart_note_test.dart:218-232` appelle `ZSmartNote.fromMap(map, extensionParser: …)` — or `ZcrudRegistry` appelle `ZXxx.fromMap(map)` **tout court**. **AC5 est donc SATISFAIT EN APPARENCE.**
- ❌ Les dettes déclarées sont **DW-ES22-1** et **DW-ES22-2**. La seule qui compte pour la donnée de l'utilisateur est **absente**.

**Le verrou d'honnêteté du harnais** (`reserved_keys_test.dart:580+`) couvre bien `smart_note` (c'est un des +3 tests) — **le repo reste honnête en machine**. Mais aucun signal ne relie *« une entité vient d'acquérir une `ZExtension` concrète »* à *« la clause d'échappement de DW-ES14-2 vient de tomber »*.

**Exigé avant `done`** (aucun code de `zcrud_core` à écrire — **D9 respecté**) :
1. Escalader **DW-ES14-2** : la marquer **BLOQUANTE pour ES-3.x sur `smart_note`** (et non plus seulement « à solder avant ES-3.2/ES-3.5 »), en nommant `ZNoteAudio` comme le **falsificateur** de sa clause n°1.
2. **Dartdoc de `ZNoteAudio` + du barrel** : avertissement explicite — *« ⛔ ce slot est DÉTRUIT par `ZcrudRegistry`/`FirebaseZRepositoryImpl.fromRegistry` (DW-ES14-2) ; câbler l'entité par le constructeur nominal avec `extensionParser: ZNoteAudio.fromJsonSafe` »*.
3. **Un test dans `zcrud_note`** qui **épingle la perte** par le registre (verrou d'honnêteté local, à INVERSER quand DW-ES14-2 sera soldée) — pour que le package ne puisse pas prétendre le contraire.

---

## 🟠 MAJEUR-2 — `format_version` **future** ⇒ payload **DÉTRUIT** à la réécriture. AD-4 pt.1 (« évolution additive ») est de la **prose**.

**Fichier** : `packages/zcrud_note/lib/src/domain/z_note_audio.dart:101-103` (version ≠ 1 ⇒ `null`) + `z_smart_note.dart:236-238` (`toMap` n'émet `extension` **que si non-`null`**)

### Mesuré

```dart
final map = {'id':'n1','title':'t',
             'extension': {'format_version': 2, 'url':'u', 'nouveau_champ':'x'}};
final n = ZSmartNote.fromMap(map, extensionParser: ZNoteAudio.fromJsonSafe);
// MESURÉ : n.extension                        == null
// MESURÉ : n.toMap().containsKey('extension') == false   ⛔ le payload v2 est PERDU
```

**Scénario réel** : l'app v2 écrit un `ZNoteAudio` v2 ; l'app v1 (ou un client resté en arrière) **lit** la note, **la réécrit** (n'importe quelle édition du titre) ⇒ **le slot audio v2 est effacé du store**. La version **suivante** ne le retrouvera jamais.

`ZExtension`'s dartdoc (`zcrud_core/.../z_extension.dart`) promet une extension *« **riche, rétro-compatible**, versionnée indépendamment du parent »* et une *« évolution additive (AD-10) »*. **Le mécanisme livré ne sait faire qu'une chose de la version : la JETER.** `formatVersion` a une **EXISTENCE**, aucun **POUVOIR** de préservation.

### Le test est vert pour une MAUVAISE raison

`z_note_audio_test.dart:56` (« `format_version: 99` ⇒ `null` ») **n'observe que l'absence de throw**. Il ne demande **jamais** ce qu'il advient du payload à la réécriture. C'est **littéralement** le finding H2 d'ES-2.0 (« un canal affirmé "préservé" que rien n'observe »), rejoué sur le slot `extension`.

**Recommandation** (le fix de fond touche `ZExtensible`/`ZcrudRegistry` ⇒ **D9 : ARRÊTER et SIGNALER**, ne pas écrire le cœur ici) :
- **Signaler la dette** (elle est la **jumelle** de DW-ES14-2 : même cause racine — le payload non parsé n'a **aucun** canal de survie) ;
- **piste** à statuer avec DW-ES14-2 : conserver le payload brut non parsé (p. ex. `extensionRaw`, réémis tel quel quand `extension == null`), de sorte qu'une version **inconnue** soit **PRÉSERVÉE** au lieu d'être détruite — c'est **la seule** lecture d'AD-4 qui rende le mot « additive » vrai ;
- **a minima** : un test-verrou d'honnêteté qui **épingle la destruction**, et la dartdoc corrigée (« la note survit, **mais son slot est effacé à la réécriture** » — aujourd'hui elle dit seulement *« la note survit, sans son slot audio »*, ce qui laisse croire à une simple non-lecture).

---

## 🟠 MAJEUR-3 — La leçon **H2** n'a été appliquée qu'à `content`. La **voie oubliée**, c'est `extra` : `copyWith` **rouvre** le filtre des clés réservées, et `toMap()` **réémet `updated_at`/`is_deleted`**.

**Fichiers** : `z_smart_note.dart:285-287` (`copyWith(extra:)` — **aucune** normalisation) · `:105-114` (constructeur — `extra` brut) · `:230-240` (`toMap` : `{...extra, …}`)

La story a **parfaitement** appliqué H2 à `content` (`fromMap` **et** `copyWith` appellent **la même** `normalizeNoteContentOps`) — et a **oublié l'autre garde du même `fromMap`** : `_extraFrom(map)`, qui **filtre les clés réservées** (`_reservedKeys`, dont `ZSyncMeta.reservedKeys`). `copyWith(extra:)` et le constructeur **ne la traversent pas**.

### Mesuré

```dart
final n = ZSmartNote.fromMap({'id':'n1','title':'t'});
final pollue = n.copyWith(extra: {'updated_at':'1999-01-01T00:00:00.000Z', 'is_deleted': true});

pollue.toMap();
// MESURÉ ⇒ {updated_at: 1999-01-01T00:00:00.000Z, is_deleted: true, id: n1, ...}
// MESURÉ : toMap().containsKey('updated_at') == true
// MESURÉ : toMap().containsKey('is_deleted') == true
```

### La dartdoc PROMET l'inverse — sans condition

`z_smart_note.dart:223-224` :

> *« ⛔ **Ne réémet NI `updated_at` NI `is_deleted`** : ces clés appartiennent au store (`ZSyncMeta`), pas au domaine (AD-16/AD-19). »*

**C'est faux dès qu'on passe par `copyWith`/le constructeur.** C'est **exactement** la forme du finding **H2 d'ES-2.1** (*« `copyWith` contournait une garde que la dartdoc PROMETTAIT »*), sur la même entité, dans le même fichier, sous la même story qui cite ce finding comme sa leçon.

**AC7** (« `toMap()` ne réémet NI `updated_at` NI `is_deleted` ») n'est vérifié que sur la voie `fromMap` (`z_smart_note_test.dart:83-94`) : **il ne discrimine pas** la voie `copyWith`.

**Impact réel** : un `put` écrit un `updated_at` **métier** dans le corps ; le store le réécrit **après** le corps (AD-19) ⇒ écrasement silencieux, ou pire, corruption de l'autorité LWW selon l'ordre. **C'est précisément le piège R-C que la story dit fermer.**

**Correctif attendu** : une fonction nommée **unique** (`_sanitizeExtra` / `normalizeNoteExtra`) qui filtre `_reservedKeys`, **appelée par `fromMap` ET par `copyWith`** — le patron **exact** que la story a réussi pour `content`. + le test discriminant sur la voie `copyWith`.

---

## 🟡 MEDIUM-1 — `==`/`hashCode` : égalité **PROFONDE** sur `content`, **SUPERFICIELLE** sur `extra` ⇒ `fromMap(m) != fromMap(m)`

**Fichiers** : `z_smart_note.dart:348` (`_mapEquals(extra, …)`) · `:376-390` (`_mapEquals`/`_mapHash`, **shallow**)

Le dev a écrit `noteContentEquals`/`noteContentHash` (profonds) **avec l'argument juste** (`z_note_content.dart:141-147`) :

> *« `==` de `Map`/`List` est une égalité d'**identité** en Dart : sans cette fonction, deux notes au contenu identique mais décodées séparément seraient **différentes**, et l'`==` entre une note en mémoire et la même relue du store **casserait**. »*

**Cet argument s'applique mot pour mot à `extra`** — dont la raison d'être (AD-4 pt.2) est de porter du **JSON arbitraire, donc IMBRIQUÉ** (maps/listes legacy IFFD, documents Firestore). Il n'y a **pas** été appliqué.

### Mesuré — deux décodages séparés du **même document**

```dart
const json = '{"id":"n1","title":"t","content":[{"insert":"a\\n"}],'
             '"legacy_meta":{"a":1},"tags":["x","y"]}';
final a = ZSmartNote.fromMap(jsonDecode(json));
final b = ZSmartNote.fromMap(jsonDecode(json));

// MESURÉ : a == b                    ⇒ false   ⛔ (attendu : true)
// MESURÉ : a.hashCode == b.hashCode  ⇒ false
// MESURÉ : <ZSmartNote>{a, b}.length ⇒ 2       ⛔ (attendu : 1)
// (contrôle : sans clé imbriquée dans `extra`, a == b ⇒ true — c'est bien `extra` le fautif)
```

⇒ Toute déduplication (`Set`), tout cache mémoïsé, tout `expect(relu, original)` sur une note **portant une clé legacy imbriquée** est **cassé**.

### Vert pour une mauvaise raison

Les sondes des tests n'utilisent **que des scalaires** (`'zz_cle_inconnue': 'gardee'`, `z_smart_note_test.dart:51-80` et `:487-511`). **Aucun** test ne met une **map** ou une **liste** dans `extra` — le seul cas qui casse. Le filet a une **existence**, pas de **pouvoir discriminant**.

**Systémique** : `_mapEquals`/`_mapHash` superficiels sont **copiés à l'identique** dans `zcrud_document`, `zcrud_flashcard` et `zcrud_study_kernel`. ⇒ correctif **local** ici (réutiliser la profondeur déjà écrite dans `z_note_content.dart`), + **dette cross-cutting** à ouvrir (le fix global touche d'autres packages ⇒ hors périmètre, **D9**).

---

## 🔵 LOW

| # | Fichier:ligne | Finding |
|---|---|---|
| **L1** | `z_note_content.dart:60, 78-113` | **Mutabilité incohérente de `content`.** `normalizeNoteContentOps(null)` rend `kEmptyNoteContent` (`const []` ⇒ **non modifiable**), alors que la branche ops rend une liste **growable**. **MESURÉ** : `plein.add(op)` → OK ; `vide.add(op)` → **`UnsupportedError`**. Une note vide et une note pleine n'ont pas le même contrat. Rendre les **deux** non-modifiables (`List.unmodifiable`, cohérent avec `_extraFrom` qui, lui, fait `Map.unmodifiable`). |
| **L2** | `z_note_content.dart:97-100` | **Variante `{"ops":[…]}` du wire-format Delta traitée comme du TEXTE.** **MESURÉ** : `'{"ops":[{"insert":"corps riche\n"}]}'` ⇒ `[{insert: '{"ops":[…]}\n'}]`. Aucune **perte** (le texte survit — D5 tient), mais la note **s'afficherait comme du JSON brut**. Ni lex ni IFFD ne persistent cette forme (leur corpus Delta est un **tableau**) ⇒ **LOW**, mais à **consigner** pour ES-6.2 (un `Map` portant une clé `ops` qui est une `List` d'ops valides pourrait être accepté). |
| **L3** | `z_note_content.dart:127-134` | **`try/catch` mort.** `'${e.key}'` (interpolation d'un `Object?`) **ne peut pas** lever. Le `catch (_) => null` n'est jamais atteint : bruit défensif qui suggère une protection inexistante. (Idem `z_smart_note.dart:367-371`, `z_note_audio.dart:126-131`.) |
| **L4** | *(process)* `tool/reserved_keys_gate/lib/src/registrars.dart`, `tool/reserved_keys_gate/pubspec.yaml`, root `pubspec.yaml` | **Garde-fou de parallélisation contourné.** ES-2.1 **et** ES-2.2 ont écrit **les mêmes trois fichiers**. CLAUDE.md n'autorise **qu'un** point de contact (`zcrud_core`) et exige de **re-séquencer** tout fichier partagé entre deux stories en vol. Le résultat est vert (ajouts disjoints, gate RC=0), mais la règle a bien été enfreinte — et c'est **le seul fichier** où une collision aurait été silencieuse. À **nommer** en rétro ES-2 : *le harnais du gate est un point de contact structurel de TOUTE story ES-2* ⇒ soit il est sérialisé, soit il est éclaté par package. |

---

## Audit d'acceptation (14 ACs)

| AC | Verdict | Note |
|---|---|---|
| AC1 — package pur-Dart, acyclique, déclaré | ✅ | deps = `zcrud_core` + `zcrud_annotations` **seuls** (vérifié) ; `melos list` = 17 ; graph ACYCLIQUE / CORE OUT=0. |
| AC2 — (h) `hide ZSmartNoteZcrud` | ✅ | gate (h) + test de package ; injection ④ **vue rougir**. |
| AC3 — `content` typé, hors-codegen, AD-28 | ✅ | `content ∉ $ZSmartNoteFieldSpecs` (assertion machine) ; aucun `implements ZCodec` (machine). |
| AC4 — coercition D5, aucun texte détruit | ⛔ **NON SATISFAIT** | **HIGH-1** : la branche **`List` partiellement valide** rend `[]` sur un contenu **non vide**. La matrice est **incomplète** (la ligne manquante est celle qui perd la donnée). Idempotence : ✅ vérifiée sur toutes les formes sondées. R5 : ✅. |
| AC5 — audio hors-schéma (`extra` **et** `ZNoteAudio`) | ⚠️ **APPARENT** | Voie `extra` : ✅ (round-trip réel). Voie **typée** : verte **uniquement hors registre** — **MAJEUR-1**. `fromJsonSafe` défensif : ✅ (sauf **MAJEUR-2** : la version future est **détruite**, pas préservée). |
| AC6 — AD-19 dès la naissance | ✅ | zéro clé de sync ; `kLegacyUpdatedAtMirrors` inchangé (verrou vert). |
| AC7 — R-A prouvé comportementalement | ⚠️ | ✅ sur la voie `fromMap` ; ⛔ **la promesse de `toMap()` est fausse via `copyWith`** — **MAJEUR-3**. |
| AC8 — patron ES-2.0 observé par le registre | ✅ | **observe le POUVOIR** (la valeur de `content` survit), pas l'absence d'exception. |
| AC9 — garde partagée `fromMap`/`copyWith` | ⚠️ | ✅ **pour `content`** (exemplaire). ⛔ **oubliée pour `extra`** — **MAJEUR-3**. Constructeur sans `assert` : ✅ (AD-10 respecté). |
| AC10 — harnais câblé dans la même story | ✅ | `kProbeBodies['smart_note']` porte un `content` **non vide** (g2) ; injections ②③ **vues rougir**. |
| AC11 — invariant + cas corrompu | ⚠️ | ✅ sauf la ligne « `List` partiellement valide » (**HIGH-1**) et la préservation de version (**MAJEUR-2**). |
| AC12 — injections R3 | ✅ | **4/4 rouges**, rejouées par l'orchestrateur. |
| AC13 — vérif verte repo-wide | ✅ | `generate`/`analyze`/`verify` RC=0 · `prove_gates` 41 OK / 0 FAIL · `.g.dart` suivi par git. |
| AC14 — périmètre | ⚠️ | Aucune ligne de `zcrud_core`/`zcrud_study_kernel` écrite (✅, **D9 respecté**). Mais **L4** : fichiers du harnais partagés avec ES-2.1. |

---

## DW-ES22-1 (recouvrement `normalizeNoteContentOps` ↔ `DeltaNeutralOps.asDeltaOps`) — la décision d'ARRÊT était-elle la bonne ?

**Oui.** Hisser la primitive dans `zcrud_core` **écrirait le cœur** ⇒ resérialiserait ES-2.1/ES-2.6 en vol : **D9 s'applique, le dev a eu raison de s'arrêter et de le dire.**

**Mais le risque est SOUS-ÉVALUÉ, et HIGH-1 en est la démonstration.** Les deux coercitions ne sont pas seulement « recouvrantes » : elles **DIVERGENT DÉJÀ**, et **en sens opposé sur la donnée** —

| Entrée | `DeltaNeutralOps.asDeltaOps` (`zcrud_markdown`) | `normalizeNoteContentOps` (`zcrud_note`) |
|---|---|---|
| `String` markdown | `[]` (**détruit**) | texte **verbatim** (**préserve**) |
| `List` partiellement valide | `[]` | `[]` — *(HIGH-1 : devrait préserver)* |

En **ES-6.1**, `note.content` (préservé) traversera l'éditeur (`ZMarkdownField` → `asDeltaOps`, **destructeur**). **Un aller-retour domaine → éditeur → domaine peut donc effacer ce que le domaine avait sauvé.** La dette est écrite comme une **duplication** (« ~20 lignes ») ; c'est en réalité une **divergence sémantique sur la préservation des données**, et elle est **déjà là**.

**Rendre la divergence VISIBLE avant ES-6.1 (sans écrire `zcrud_core`) — geste minimal recommandé :**
un **test-verrou** (dans `zcrud_markdown`, ou un test cross-package du harnais) qui **épingle EN MACHINE** que `asDeltaOps('# T') == []` **tandis que** `normalizeNoteContentOps('# T') == [{'insert':'# T\n'}]`, avec le commentaire : *« ces deux fonctions DIVERGENT sur la préservation ; ES-6.1 DOIT les réconcilier avant de brancher `note.content` sur l'éditeur — sinon l'aller-retour détruit le corpus legacy. »* Le verrou coûte 10 lignes et **empêche que la divergence soit découverte par une perte de données en production**.

---

## Décision

| Sévérité | # | Obligation (CLAUDE.md) |
|---|---|---|
| 🔴 **HIGH** | 1 | **Correction OBLIGATOIRE avant `done`** |
| 🟠 **MAJEUR** | 3 | **Correction OBLIGATOIRE avant `done`** (MAJEUR-2 : le fix de fond touche le cœur ⇒ **escalade + verrou + dartdoc**, pas de code cœur) |
| 🟡 **MEDIUM** | 1 | Correction **par défaut** (locale, sans régression) ; report **justifié par écrit** sinon |
| 🔵 **LOW** | 4 | Optionnels (L1/L3 triviaux) ; **L4 à porter en rétro ES-2** |

**La story NE PEUT PAS passer `done` en l'état.** Les quatre findings bloquants ont tous la **même** signature — celle que la rétro ES-1 a nommée, et que cette story a combattue avec succès **partout ailleurs** :

> *un artefact de vérification déclaré valide sur son **EXISTENCE**, jamais sur son **POUVOIR DISCRIMINANT** observé.*

- La **matrice D5** existe — mais sa ligne « `List` partiellement valide » **entérine la perte** qu'elle prétend interdire (**HIGH-1**).
- La **garde partagée `fromMap`/`copyWith`** existe — pour `content`. Pour `extra`, la dartdoc **promet** ce que le code **ne tient pas** (**MAJEUR-3**).
- Le **slot `ZExtension` versionné** existe — la version ne sait que **jeter** le payload (**MAJEUR-2**), et la seule voie que le store emprunte l'**efface** (**MAJEUR-1**).

**Dixième instance trouvée. Et cette fois, elle est à l'intérieur du filet.**
