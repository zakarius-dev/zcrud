# Réfutation — IA (IFFD) / « Sérialisation manuelle des 5 modèles + les 16 `Timestamp` »

**Date** : 2026-08-26 · **Rôle** : réfutateur · **Dépôts hôtes lus en LECTURE SEULE.**

## Verdict : **RÉFUTÉE**

Le canal existe et fait ce qu'on lui prête. Il est **hors de portée de l'hôte** et il ne **couvre
qu'une moitié du besoin**. Les deux chiffres avancés (677 l, 65 %) sont **surévalués d'un facteur 2**.

| # | Attaque | Résultat |
|---|---|---|
| 1 | Le canal existe à l'endroit cité | ✅ **tient** |
| 2 | Le corps fait ce que la dartdoc promet | ✅ **tient** |
| 3 | Atteignable depuis l'hôte | ❌ **RÉFUTÉ** — 0 consommateur, 2 dépendances non déclarées |
| 4 | Couvre le besoin réel | ❌ **RÉFUTÉ** — `fromMap` refusé au build ; 12 des 16 `Timestamp` y vivent |
| 5 | Condition cachée | ❌ **RÉFUTÉ** — 3 changements de format sur disque en production |

---

## 1–2. Ce qui TIENT (vérifié dans les corps, pas dans les dartdoc)

Je confirme, ligne à ligne :

* `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart:151` → `class ZcrudModel`
  (ctor `:153`, `kind`, `fieldRename`). `zcrud_field.dart:52` → `class ZcrudField`, **18 paramètres**
  comptés (`label`…`helperText`). `z_persist_as.dart:16` → `enum ZPersistAs { iso8601, timestamp }`.
  `zcrud_id.dart:16` → `class ZcrudId`. **Les quatre sont exportés** par le barrel
  `packages/zcrud_annotations/lib/zcrud_annotations.dart` (lignes 15-19).
* Générateur : `toMap`/`copyWith` émis en extension (`zcrud_model_generator.dart:978-988`),
  registrar (`:1184`), `$XxxTimestampFields` (`:1230-1238`).
* **Le canal `Timestamp` n'est pas décoratif** — corps lu :
  `firebase_z_repository_impl.dart:206` (`_timestampFields = timestampFields.difference(...)`) →
  `:542-555` `_applyTimestampHints` remplace bien la String ISO par `Timestamp.fromDate(...toUtc())` →
  appelé depuis `_encode` (`:505`). Décodage symétrique `_normalizeTemporalDeep` (`:463-488`).
* `ZFieldRename.none` **existe** (`packages/zcrud_core/lib/src/domain/edition/z_field_rename.dart:17`) —
  l'attaque « zcrud imposerait snake_case aux clés camelCase d'IFFD » **échoue**, je la retire.
* Les chiffres d'hôte du dénominateur sont **exacts** : 325+96+89+144+390 = **1 044 l** ;
  8+4+4 = **16 `Timestamp`** ; `import 'package:cloud_firestore/cloud_firestore.dart'` en
  `chatbot_conversation.dart:4`, `chatbot_message.dart:3`, `ai_expert.dart:3`.
* Le **grep négatif de l'affirmation est correct**, revérifié :
  `grep -rn "@ZcrudModel\|@ZcrudField\|@ZcrudId" lib/ai_assistant lib/src/domain/models/ai` → **RC=1**.

---

## 3. RÉFUTATION — le canal qui retire `Timestamp` du domaine a **ZÉRO** consommateur dans IFFD

C'est le cœur de la preuve avancée (« CORPS LU : … c'est le canal qui retire `Timestamp` du domaine »).

**GREP NÉGATIF MONTRÉ** (dans `/home/zakarius/DEV/iffd`) :

```
$ grep -rn "FirebaseZRepositoryImpl" lib
RC=1        (0 ligne)

$ grep -rn "FirebaseZRepositoryImpl" lib test | wc -l
0
```

IFFD ne persiste **rien** par `FirebaseZRepositoryImpl`. Ses cinq modèles passent par son propre
générique :

* `lib/src/data/repositories/firebase_models_repositories_impls.dart:225-232` —
  `FirebaseChatbotConversationRepositoryImpl extends FirebaseCrudRepositoryImpl<ChatbotConversation>`,
  idem `ChatbotMessage`.
* `lib/src/data/repositories/firebase_crud_repository_impl.dart:18` —
  `class FirebaseCrudRepositoryImpl<T extends DynamicModel>`, dont le chemin d'écriture est
  `collectionReferenceWithConverter<T>` (`:47`, `:191`).
* `lib/src/utils/functions/databases_functions.dart:25-31` :
  `toFirestore: (model, options) => toMap<T>(model)…` — **appel DIRECT de `toMap()`**.

Or `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart` (§ « Le `toMap()` généré
n'est pas destiné à une écriture directe ») nomme **exactement** ce cas : *« Un moteur de persistance
qui appellerait `toMap()` directement, sans passer par le repository, écrirait donc des `String` là
où le parc attend le type natif »*. **IFFD est littéralement dans ce cas.** Annoter les modèles sans
remplacer la couche repository convertirait `createdAt` de `Timestamp` en **String ISO-8601 sur le
disque de production**, cassant tout `orderBy`/plage temporelle. Le remède (`timestampFields`) est
inaccessible tant que `FirebaseZRepositoryImpl` n'est pas adopté — c'est-à-dire tant que la couche
data d'IFFD n'est pas réécrite. **Ce n'est pas la migration annoncée.**

Contrainte annexe : `FirebaseZRepositoryImpl<T extends ZEntity>` (`:156`) exige `ZEntity`
(`packages/zcrud_core/lib/src/domain/contracts/z_entity.dart:17`). Les 5 modèles implémentent
`DynamicModel` (`lib/src/domain/models/dynamic_model.dart:3`), pas `ZEntity`.

**Dépendances non déclarées** (`/home/zakarius/DEV/iffd/pubspec.yaml`, blocs :
`dependencies:10`, `dev_dependencies:533`, `dependency_overrides:552`, `flutter:734`) :

```
$ awk 'NR>=10 && NR<=532' pubspec.yaml | grep -n "zcrud_annotations"   → RC=1
$ awk 'NR>=533 && NR<=551' pubspec.yaml | grep -n "zcrud"              → RC=1
```

`zcrud_annotations` n'apparaît qu'en **`dependency_overrides` (:577)** — arrivé par fermeture
transitive (`zcrud_study_kernel → zcrud_annotations`, commentaire :569), jamais déclaré.
`zcrud_generator` est **totalement absent** du pubspec. Deux ajouts obligatoires avant la première
ligne d'annotation (`build_runner ^2.15.1` et `build.yaml` sont, eux, déjà présents).

---

## 4. RÉFUTATION — `@ZcrudModel` **REFUSE** de générer `fromMap`, où vivent 12 des 16 `Timestamp`

`packages/zcrud_generator/lib/src/zcrud_model_generator.dart:196-198` : *« Contrat — factory de
DOMAINE `Xxx.fromMap` **obligatoire** »*. `_requireDomainFromMap` (`:245`) lève un
`InvalidGenerationSourceError` (`:262-268`) : *« `$className` est annotée `@ZcrudModel` mais ne
déclare AUCUN décodeur de domaine `fromMap` »*. **Build ROUGE.** Et `_rejectNakedCodegenDelegation`
(`:411-427`) refuse même le talon `=> _$XxxFromMap(map)`.

⇒ **Le `fromMap` reste écrit à la main, dans son intégralité.** Or c'est lui qui porte les
`Timestamp`. Répartition **mesurée** des 16 occurrences :

| Fichier | dans `toMap()` (part) | dans `fromMap()` (**reste**) |
|---|---|---|
| `chatbot_conversation.dart` | 84, 86 → **2** | 95, 96, 97, 100, 101, 102 → **6** |
| `chatbot_message.dart` | 259 → **1** | 286, 287, 288 → **3** |
| `ai_expert.dart` | 187 → **1** | 216, 217, 218 → **3** |
| **Total** | **4 (25 %)** | **12 (75 %)** |

**L'`import 'package:cloud_firestore/cloud_firestore.dart'` reste donc dans les trois fichiers de
domaine après annotation.** Le besoin énoncé — « les 16 `Timestamp` qui fuient dans le domaine » —
est couvert **au quart**.

### Le compte de lignes : **315**, pas 677

Bornes relevées à la ligne (`sed`/`grep -n` sur chaque fichier) :

| Fichier | `copyWith` | `toMap` | **Supprimé** | `fromMap` (**RESTE**) | Total fichier |
|---|---|---|---|---|---|
| `ai_expert.dart` | 87–169 (83) | 171–212 (42) | **125** | 214–279 (**66**) | 325 |
| `chatbot_message.dart` | 189–249 (61) | 251–282 (32) | **93** | 284–352 (**69**) | 390 |
| `chatbot_conversation.dart` | 43–72 (30) | 74–91 (18) | **48** | 93–118 (**26**) | 144 |
| `ai_expert_knowledge.dart` | 23–38 (16) | 40–49 (10) | **26** | 51–61 (**11**) | 96 |
| `ai_expert_responses_example.dart` | 20–33 (14) | 35–43 (9) | **23** | 45–54 (**10**) | 89 |
| **TOTAL** | 204 | 111 | **315 (30,2 %)** | **182** | **1 044** |

Restent aussi **hors codegen**, non émis par le générateur : `List<Object?> get props`
(ex. `ai_expert.dart:281-316` = 36 l ; `chatbot_message.dart:354-383` = 30 l ; ~84 l au total —
socle de l'`==`/`hashCode` de `DynamicModel`, `dynamic_model.dart:18-25`), `stringify`,
`toJson()`/`fromJson()`. Et il faut **ajouter** `@ZcrudModel`, `part '….g.dart'`, `@ZcrudId`, plus un
`@ZcrudField(persistAs: ZPersistAs.timestamp)` par champ date.

**315 l brutes, moins les annotations ajoutées — contre 677 annoncées. Écart : facteur ≈ 2,2.**

---

## 5. RÉFUTATION — trois changements de format **sur disque** que l'affirmation dit absents

L'affirmation promet « SANS changer le format persisté ». Trois contre-exemples mesurés :

1. **Deux clés neuves sur chaque document.** `_encode` (`firebase_z_repository_impl.dart:505-511`)
   écrit **inconditionnellement** `updated_at` (ISO) et `is_deleted: false`.
   GREP NÉGATIF : `grep -rn "updated_at\|is_deleted" lib/ai_assistant lib/src/data/repositories/firebase_crud_repository_impl.dart` → **RC=1**.
   Ces clés n'existent nulle part aujourd'hui côté IFFD ; elles apparaîtraient sur tout le parc.
   Pire, elles **cohabiteraient** avec le `updatedAt` camelCase existant (deux dates concurrentes).

2. **`int` millisecondes : perte silencieuse.** `_normalizeTemporalDeep` (`:463-488`) reconnaît
   `Timestamp`, `DateTime` et `{_seconds,_nanoseconds}` — **pas l'`int`**. Vérifié : le seul `is int`
   du corps porte sur `_seconds`/`_nanoseconds` (`:473`, `:476`), jamais sur la valeur elle-même.
   Or IFFD gère explicitement ce format legacy en **6 sites** :
   `chatbot_conversation.dart:94,99`, `chatbot_message.dart:285`, `ai_expert.dart:215`
   (`map['createdAt'] is int ? Timestamp.fromMillisecondsSinceEpoch(...)`). Basculer la lecture sur
   le socle laisse l'`int` **inchangé** → date nulle ou cast rouge sur les documents anciens.

3. **`updatedAt == null → Timestamp.now()`** (`chatbot_conversation.dart:85-86`) et
   **`updatedAt` absent → `DateTime.now()`** en lecture (`:103`) : deux **défauts calculés au
   runtime**. Le `toMap` généré émet `null` ; `ZcrudField.defaultValue` est lu par `ConstantReader`
   et n'accepte qu'une constante — `DateTime.now()` n'en est pas une. **Inreproductible.**

**Bonus, non signalé par l'affirmation — inversion silencieuse de `copyWith` :** l'hôte utilise
`id ?? this.id` (un `null` **préserve**) ; le générateur émet une **sentinelle**
(`zcrud_model_generator.dart:986-988` : *« un argument omis préserve la valeur, `null` explicite la
remet à `null` »*). Tout appelant passant une variable nullable qui vaut `null` **efface** désormais
le champ au lieu de le conserver. `grep -rn "\.copyWith(" lib | wc -l` → **256** sites dans
`iffd/lib` ; migration à auditer un par un, aucun test ne rougirait.

---

## 6. Condition cachée de conception : l'hôte a choisi le contraire, et l'a gardé

`iffd/test/w9b/chatbot_conversation_adapter_test.dart:3-6` (en-tête) :
*« la garde la plus importante n'est pas une garde de conversion : c'est celle de
l'**UNIDIRECTIONNALITÉ**. L'option B ne tient que tant qu'**aucune entité du socle n'est
persistée**. »* Idem `test/w9a/chatbot_message_adapter_test.dart`.

IFFD **projette** déjà ses modèles vers `ZChatConversation`/`ZChatMessage`
(`lib/src/presentation/features/chatbot/zcrud/chatbot_conversation_adapter.dart`,
`chatbot_message_adapter.dart`) **pour l'affichage seulement**, et a posé une garde explicite contre
la persistance par le socle. L'affirmation propose précisément ce que cette garde interdit. Ce n'est
pas un obstacle technique — c'est un **arbitrage d'hôte documenté** que la migration devrait
d'abord renverser, avec les 41 fichiers de `iffd/lib` qui citent ces deux modèles.

---

## Ce qu'il faut écrire à la place

> `@ZcrudModel`/`@ZcrudField`/`@ZcrudId` + `ZPersistAs.timestamp` + `$XxxTimestampFields`
> **existent et fonctionnent**, mais couvrent **~315 l / 1 044 (30 %)** — `toMap` et `copyWith`
> seuls. Le générateur **exige un `fromMap` écrit à la main** (build rouge sinon,
> `zcrud_model_generator.dart:262-268`) : les **182 l** de `fromMap` restent, et avec elles
> **12 des 16 `Timestamp` (75 %)** et l'`import cloud_firestore` des trois fichiers.
> Le canal de retrait du `Timestamp` (`FirebaseZRepositoryImpl.timestampFields`) a **0 usage**
> dans IFFD (`grep -rn "FirebaseZRepositoryImpl" lib test` → 0) : il suppose de remplacer
> `FirebaseCrudRepositoryImpl<T extends DynamicModel>` par
> `FirebaseZRepositoryImpl<T extends ZEntity>`, donc de réécrire la couche data et de faire
> implémenter `ZEntity` aux modèles. À défaut, le `toMap()` généré part **directement** dans
> `withConverter` (`databases_functions.dart:29`) et écrit des **String là où le parc attend des
> `Timestamp`** — le cas que la dartdoc du socle nomme elle-même.
> `zcrud_annotations` n'est pas une dépendance déclarée (override seul, :577), `zcrud_generator`
> est absent du pubspec.

**Gain réel plausible : ~250–315 l (24–30 %), au prix d'une réécriture de la couche data et d'une
migration de données Firestore.** Pas 677 l, et pas « sans changer le format persisté ».
