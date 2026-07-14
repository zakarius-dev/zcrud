# Code Review — Story ES-2.0 : `registry.decode` préserve `extra` (DW-ES14-1)

- **Skill** : `bmad-code-review` (**réellement invoqué** via le tool `Skill` — aucun fallback disque).
- **Date** : 2026-07-13 · **Reviewer** : Claude Opus 4.8 (revue adversariale)
- **Story** : `_bmad-output/implementation-artifacts/stories/es-2-0-registry-decode-preserve-extra.md` (10 ACs, D1..D5)
- **Diff revu** : non committé — `git diff HEAD` (18 fichiers, +730/-142), périmètre `zcrud_generator`, `zcrud_firestore`, `tool/reserved_keys_gate`, `scripts/ci`, 5 `*.g.dart`, architecture.
- **Vérifs vertes** : rejouées par l'orchestrateur (`melos analyze` RC=0, `melos verify` RC=0 / 10 gates, `prove_gates` 35 OK / 0 FAIL, `graph_proof` ACYCLIQUE + CORE OUT=0, `melos list` = 15). **Non rejouées ici** — exploitées comme acquis.
- **Verdict initial** : ⛔ **NON DONE EN L'ÉTAT** — **1 HIGH + 1 MAJEUR** à traiter (correction ou justification écrite) avant `done`.
- 🟢 **VERDICT APRÈS REMÉDIATION (2026-07-13)** : **H1, H2, M1, M2, M3, M4 CORRIGÉS** · **L2 CORRIGÉ** · **L1 sans objet (résorbé par H1)** · **L3 tranché**. **0 finding reporté.** Chaque filet ajouté ou modifié est **prouvé par injection de régression réellement exécutée** (§ *Statut de remédiation*).

---

## Synthèse

| Sévérité | # | Titre | Statut |
|---|---|---|---|
| 🔴 **HIGH** | **H1** | `_requireDomainFromMap` valide l'**EXISTENCE** d'une signature, jamais le **POUVOIR** de préserver `extra` — et son message d'erreur **prescrit littéralement la forme impotente**. Hors de ce repo, le filet (e) n'existe pas. | ✅ **CORRIGÉ** (3 filets) |
| 🟠 **MAJEUR** | **H2** | « `source` ✅ **PRÉSERVÉ** » : affirmation publique dans une dartdoc qui **invite à câbler un store** — **zéro observation machine** (la sonde `flashcard` ne porte aucune clé `source`). Et la voie registre **bypasse silencieusement le `ZSourceRegistry` de l'app**. | ✅ **CORRIGÉ** (+ perte **aggravée** découverte à la mesure) |
| 🟡 MEDIUM | M1 | Validation de signature par **comparaison de chaîne d'affichage** (`getDisplayString() == 'Map<String, dynamic>'`) → faux échecs de build sur des signatures légales et assignables. | ✅ **CORRIGÉ** |
| 🟡 MEDIUM | M2 | Un `fromMap` déclaré en **méthode statique** (tear-off valide) est rejeté avec un message qui affirme qu'aucun `fromMap` n'existe. | ✅ **CORRIGÉ** |
| 🟡 MEDIUM | M3 | **Changement cassant publié** sans note de migration : ni CHANGELOG, ni README, ni **dartdoc de `@ZcrudModel`** (le contrat public de l'annotation). | ✅ **CORRIGÉ** |
| 🟡 MEDIUM | M4 | Le filet de couverture reste **aveugle à un `ZExtensible` transitif** (super-type indirect) — pré-existant, mais **désormais porteur de tout le filet DW-ES14-1**. | ✅ **CORRIGÉ** (non reporté) |
| 🟢 LOW | L1 | (e) n'est **jamais observée seule sur la voie réelle** ((b) tombe avant) ; sa preuve isolée était une sonde jetable, supprimée. | ✅ **SANS OBJET** (résorbé par H1) |
| 🟢 LOW | L2 | Le verrou DW-ES14-2 peut rougir pour une raison qui **n'est pas** la clôture de la dette (faux signal de succès). | ✅ **CORRIGÉ** |
| 🟢 LOW | L3 | Hygiène de commit : `pubspec.lock` racine + `example/pubspec.lock` dans l'arbre ; contradiction `*.g.dart` suivis par git vs CLAUDE.md (constat du dev, exact). | 🔵 **TRANCHÉ** (décision orchestrateur) |

**Ce qui est solide et doit être dit** : le cœur de la story tient. Le swap D1 est correct, le contrat est machine (modèle d'éléments analyzer, **zéro regex** — R5), la déviation `kDomainDecoders` est proprement purgée (aucune référence morte hors notes historiques assumées), `_ExtraDroppingEntity` est une fixture **réellement isolée par règle** (R2, confirmé par l'injection B de l'orchestrateur : exactement 2 rouges, tous deux gardes de (e)), les 4 verrous DW-ES14-2 sont **sains** (ils rougiront le jour de la clôture, et ne cimentent pas le bug), et D5/L3 est tranchée **par la mesure**, pas par un artefact décoratif. Le dev a en outre **remis la story en cause** là où elle était fausse (D2 vs les 3 modèles in-memory) **sans affaiblir le contrat**.

---

## 🔴 H1 — HIGH : le contrat vérifie la SIGNATURE, pas le COMPORTEMENT — et son message prescrit le défaut

**Fichier** : `packages/zcrud_generator/lib/src/zcrud_model_generator.dart:131-176` (`_requireDomainFromMap`), message d'échec **l. 142-147**.

Le message d'erreur du contrat dit textuellement :

```
'via `registry.decode`. Déclarez : '
'factory $className.fromMap(Map<String, dynamic> map) => '
'_\$${className}FromMap(map);  '
```

Pour une classe **`ZExtensible`**, ce geste **est exactement DW-ES14-1** : `_$XxxFromMap` ne peuple ni `extra`, ni `extension`, ni `source`. Le contrat l'**accepte** (la signature est conforme), le build est **VERT**, et `registry.decode` détruit à nouveau les clés inconnues.

Le test d'acceptation ajouté le prouve à son insu — `build_failure_test.dart:180-192` accepte `OkModel.fromMap` dont le corps **ignore complètement `map`** (`=> OkModel(title: tenant ?? '')`). Le générateur certifie donc une factory qui ne décode **rien**.

C'est **la septième occurrence du motif dominant du projet** : un artefact de vérification (`_requireDomainFromMap`) déclaré valide sur son **existence** (« une factory `fromMap` d'arité correcte existe »), jamais sur son **pouvoir discriminant observé** (« cette factory peuple-t-elle `extra` ? »). La story affirme (D2, dartdoc l. 105-129) transformer « une hypothèse implicite en contrat vérifié par machine » — le contrat vérifie une **orthographe**, pas une **garantie**.

**Scénario d'échec reproductible**
1. Dans `zcrud_flashcard`, ajouter une entité ES-2 : `@ZcrudModel(kind: 'z_note') class ZNote with ZExtensible { … }`.
2. Le build échoue → le mainteneur applique **le geste dicté par le message** : `factory ZNote.fromMap(Map<String, dynamic> map) => _$ZNoteFromMap(map);`.
3. `melos run generate` → **VERT**. `registry.decode('z_note', {...,'zz_cle':'v'}).extra` → **`{}`** ⇒ DW-ES14-1 **restauré**, cycle read/write destructeur.

**Le filet, et ses limites**
- **Dans ce repo** : `gate:reserved-keys` rougit (couverture (1)/(4) force le câblage, puis (b) puis (e) tombent). ✅ Le filet ferme… **mais il désigne le mauvais coupable** : le message de (e) (`assertions.dart:172-181`) accuse le **générateur** (« le registrar généré câble `fromMap: _$ZXxxFromMap` … corriger `zcrud_generator` ») alors que le registrar est **correct** et que la faute est **dans la factory de domaine**. Le mainteneur est envoyé au mauvais endroit.
- **Hors de ce repo** : `zcrud_generator` / `zcrud_annotations` sont **publiés** (0.1.0). Un consommateur (DODLP, lex_douane) a le générateur **et pas le harnais** : pour lui, la garantie centrale de la story **n'est enforcée par rien**, et le message d'erreur le **guide vers le défaut**.

**Correction attendue** (le générateur importe déjà `zcrud_core` et la story elle-même prévoyait un `TypeChecker` sur `ZExtensible` en D2) :
1. Détecter si la classe est `ZExtensible` ; si oui, **prescrire dans le message la forme qui peuple `extra`** (`extra: _extraFrom(map)`) et **jamais** `=> _$XxxFromMap(map)` nu (correct, lui, pour une classe non-extensible type `ZChoice`).
2. Reformuler le `reason` de (e) pour citer **les deux causes dans le bon ordre** : (1) la factory de **domaine** ne peuple pas `extra` ; (2) le registrar est mal câblé.
3. À défaut de vérifier le comportement statiquement (impossible), **le documenter comme tel** : le contrat borne la signature, la garantie de comportement vient de (e) — donc **tout consommateur externe doit porter son propre équivalent de (e)**. À écrire là où il sera lu (dartdoc `@ZcrudModel` + README du générateur), pas seulement en Completion Notes.

---

## 🟠 H2 — MAJEUR : « `source` ✅ PRÉSERVÉ » — une affirmation de prose, dans la dartdoc qui autorise le câblage d'un store

**Fichiers** : `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:146-148` et **:165-168** · `tool/reserved_keys_gate/lib/src/registrars.dart:56-60` · `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart:77-88`.

La dartdoc reformulée (AC7/D4) publie un tableau **canal par canal** et s'en sert pour **autoriser explicitement l'usage** de `fromRegistry` :

```
extra      -> ✅ PRÉSERVÉ
source     -> ✅ PRÉSERVÉ  (kind inconnu -> ZCustomSource : payload brut conservé)
extension  -> ⛔ DÉTRUIT
```
> « **Quand utiliser `fromRegistry` malgré tout** : si — et seulement si — l'entité n'utilise pas le slot `extension`. L'échappatoire `extra` (AD-4) et le `source`, eux, sont **intégralement préservés**. »

**Deux problèmes.**

**(1) Zéro machine derrière la ligne `source`.** `kProbeBodies['flashcard']` (`registrars.dart:56-60`) = `{'id','folder_id','question'}` — **aucune clé `source`**. Aucune des assertions (a)(b)(c)(d)(e) n'exerce **jamais** ce canal. `extra` a l'assertion (e) ; `extension` a **4 tests de verrou** ; `source` a **une phrase**. C'est très exactement le motif que la story déclare combattre (« déclarer la voie sûre après n'avoir corrigé qu'`extra` serait exactement le motif d'ES-1 ») — appliqué à `extra`, oublié sur `source`.

**(2) L'affirmation est partiellement FAUSSE.** `registry.decode` appelle `ZFlashcard.fromMap(map)` **sans `sourceRegistry`** ⇒ `ZFlashcardSource.fromJson(raw, registry: null)` (`z_flashcard_source.dart:77-88`) : pour tout `kind` **custom enregistré dans le `ZSourceRegistry` de l'app**, le branchement `registry?.tryCodecFor(kind)` est `null` ⇒ le **codec de l'app est purement ignoré** et l'on obtient `ZCustomSource(kind, body BRUT)` au lieu du payload décodé. La **même cause racine que DW-ES14-2** (aucun slot d'injection dans `ZcrudRegistry`) frappe `sourceRegistry` — mais elle n'est **ni tracée comme dette, ni épinglée, ni signalée** : elle est présentée comme un ✅.

**Scénario d'échec reproductible**
1. Une app enregistre un codec de provenance (`ZSourceRegistry.register('article', …)`).
2. Elle lit ses cartes via `FirebaseZRepositoryImpl.fromRegistry` (autorisée à le faire par la dartdoc : elle n'utilise pas `extension`).
3. `card.source` est un `ZCustomSource` dont le `payload` est le **corps persisté brut**, jamais passé au codec — le contrat de `ZSourceRegistry` est rompu **en silence**.
4. Si la carte est ensuite réécrite par une voie qui **fournit** le registry (le constructeur nominal, recommandé ailleurs dans la même dartdoc), `ZCustomSource.toJson(registry:)` applique `codec.toJson(payloadBrut)` — **double transformation** sur une donnée qui n'a jamais été décodée.

*(Le round-trip strictement `fromRegistry`→`fromRegistry` reste, lui, fidèle en persistance : `decode` et `encode` sont symétriquement sans registry. La perte est **sémantique** — le codec de l'app est court-circuité — et **asymétrique dès qu'on mélange les voies**.)*

**Correction attendue** — au choix, mais **pas la prose seule** :
- ajouter `'source': {'kind': 'zz_source_test', …}` à la sonde `flashcard` + une assertion de round-trip du payload (ce qui **ferait exister en machine** le ✅ revendiqué) ; **et**
- corriger la dartdoc : `source` → « payload **round-trippé**, mais **`ZSourceRegistry` NON appliqué** (codec de l'app ignoré) » ; **et**
- **élargir DW-ES14-2** (architecture § Deferred) : le défaut n'est pas « `extension` est détruit », c'est « **`ZcrudRegistry` n'offre aucun slot d'injection** » — il frappe `extensionParser` **et** `sourceRegistry`. Le critère de clôture doit couvrir les deux.

---

## 🟡 M1 — MEDIUM : validation de signature par comparaison de chaîne d'affichage

**Fichier** : `zcrud_model_generator.dart:158-161`.

```dart
final signatureOk = positionalRequired.length == 1 &&
    surplusRequired.isEmpty &&
    positionalRequired.first.type.getDisplayString() == 'Map<String, dynamic>';
```

Le type est validé sur son **rendu textuel**. Sont donc **rejetés (échec de build)** des `fromMap` parfaitement légaux et **assignables** à `T Function(Map<String, dynamic>)` :
- `factory Xxx.fromMap(Map<String, Object?> map)` — `Map<String,Object?>` et `Map<String,dynamic>` sont **mutuellement sous-types** en Dart ;
- `typedef JsonMap = Map<String, dynamic>;` puis `factory Xxx.fromMap(JsonMap map)` — `getDisplayString()` rend l'**alias** (`JsonMap`) dès que `type.alias != null` ;
- une forme préfixée par un import.

Ironie du contrat : la vérification est **stricte là où ça ne compte pas** (l'orthographe du type) et **absente là où tout se joue** (le comportement — H1). C'est aussi le dernier résidu de contrôle **textuel** sur du Dart dans une story qui interdit la regex (R5, respectée partout ailleurs).

**Attendu** : contrôler le `DartType` (`type.isDartCoreMap` + arguments `String`/`dynamic|Object?`), ou l'assignabilité via le `TypeSystem` — pas la chaîne.

---

## 🟡 M2 — MEDIUM : un `fromMap` statique est rejeté avec un message qui nie son existence

**Fichier** : `zcrud_model_generator.dart:134`.

```dart
element.constructors.where((c) => c.name == 'fromMap')
```

Seuls les **constructeurs** sont inspectés. Or `static Xxx fromMap(Map<String, dynamic> map)` est un tear-off **valide** (`Xxx.fromMap` compile et s'assigne au registre) et peut parfaitement peupler `extra`. Le build échoue alors sur : « *`Xxx` … ne déclare **AUCUNE** factory de domaine `fromMap`* » — affirmation **fausse** pour le mainteneur qui en a bien une sous les yeux. La direction est sûre (échec, pas repli), mais le diagnostic est trompeur : soit accepter la forme statique, soit dire « **factory ou méthode statique** `fromMap` requise ».

---

## 🟡 M3 — MEDIUM : changement cassant publié, sans aucune note de migration

`zcrud_generator` et `zcrud_annotations` sont **publiés en 0.1.0** (cf. `packages/zcrud_generator/CHANGELOG.md`, commit `9ada9d0` « REL-1 — 12 packages publiables pub.dev »). Le contrat introduit ici **casse le build** de **toute** classe `@ZcrudModel` en aval qui ne déclare pas de `fromMap`.

Or :
- `packages/zcrud_generator/CHANGELOG.md` — **non modifié** ;
- `packages/zcrud_generator/README.md` — **non modifié** ;
- **`packages/zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart:1-16`** — la dartdoc de `@ZcrudModel`, **contrat public de l'annotation**, ne mentionne **pas** l'exigence.

Le contrat n'existe donc **nulle part** en dehors du message d'erreur qui le fait échouer — et, cf. H1, ce message prescrit le mauvais geste. C'est l'endroit exact où la règle doit être écrite pour être lue.

---

## 🟡 M4 — MEDIUM : le filet de couverture reste aveugle à un `ZExtensible` **transitif**

**Fichier** : `scripts/ci/gate_reserved_keys.dart:194-224` (`_superTypeNames`) et `:248-266` (`_declaresConcreteExtra`).

Le contrôle `E_disk \ E_covered` (règle 3) ne lit que les super-types **directement cités** par la déclaration (AST **syntaxique**, sans résolution). Une entité **écrite à la main** (sans `@ZcrudModel`, donc **hors `R_disk`**) qui hérite `ZExtensible` **indirectement** —

```dart
// z_base_study_entity.dart
abstract class ZBaseStudyEntity with ZExtensible { … }
// z_smart_note.dart
class ZSmartNote extends ZBaseStudyEntity { … }   // ni ZExtensible cité, ni `extra` déclaré
```

— n'entre **ni** dans `E_disk` (super-type direct = `ZBaseStudyEntity`, `extra` **hérité** donc non « concret » ici), **ni** dans `R_disk` (aucun `registerZ…`). Elle **échappe intégralement** au gate : ni sondée, ni signalée.

Le trou est **pré-existant** (conception ES-1.4) — mais ES-2.0 le rend **porteur** : depuis cette story, **tout** le filet DW-ES14-1 repose sur ce contrôle de couverture. À **tracer comme dette** au minimum (le périmètre de la story ne la force pas à la solder), avec le geste : résolution des super-types (`analyzer` avec résolution) ou allowlist explicite des classes de base `ZExtensible`.

---

## 🟢 LOW

**L1 — (e) n'est jamais observée SEULE sur la voie réelle.** Dans `assertReservedKeysClean` (`assertions.dart:243-265`), l'ordre est (a)(b) → (c)(d) → (e) : sur une régression du registrar, **(b) tombe avant (e)**. Le pouvoir propre de (e) sur les 4 kinds réels (encode amnésique) n'est observé que sur la fixture synthétique. Le dev le reconnaît honnêtement (Completion Notes §1) et a exécuté une sonde jetable appelant (e) seule sur la voie registre — mais **cette sonde a été supprimée** : la preuve a une durée de vie nulle. L'injection B de l'orchestrateur (2 rouges, tous deux gardes de (e)) confirme l'isolation ; rien à corriger, à connaître.

**L2 — le verrou DW-ES14-2 peut rougir pour la mauvaise raison.** `reserved_keys_test.dart`, groupe `DW-ES14-2` : `expect(encoded.containsKey('extension'), isFalse)`. Si `'extension'` cessait un jour d'être une clé **réservée**, elle tomberait dans `extra` et serait réémise via `...extra` ⇒ le verrou rougirait en annonçant « **la dette est soldée — INVERSER ce verrou** », alors que le payload **ne serait pas** décodé en `ZExtension` typé : **faux signal de succès**. Ajouter `expect(entity.extension, isNotNull)` (ou une assertion de forme sur `encoded['extension']`) fermerait la porte.

**L3 — hygiène de commit.** `pubspec.lock` racine (+106) et `example/pubspec.lock` (non suivi) sont dans l'arbre : CLAUDE.md proscrit les `pubspec.lock` de package au commit d'epic — à arbitrer. Par ailleurs le constat du dev (Completion Notes §3 pt.4) est **exact** : les `*.g.dart` de `packages/**` **sont suivis par git**, en contradiction avec CLAUDE.md ; les 5 régénérés **doivent** donc être committés, sinon `HEAD` conserve des registrars câblant `_$ZXxxFromMap`. Décision orchestrateur (hors périmètre story).

---

## Axes de revue demandés — réponses

| Axe | Verdict |
|---|---|
| **1. Vacuité de (a)..(e)** | (a) **cesse d'être vacuelle** — c'est le gain, constaté. (b)/(e) mordent (injection A). (e) est **isolée par règle** (injection B : 2 rouges, tous deux gardes de (e), 30 verts). La sonde `zz_cle_inconnue` est bien inconnue de chaque schéma. **Une seule vacuité résiduelle : `source`, jamais sondé → H2.** |
| **2. Couverture `R_disk \ R_wired`** | Attrape **vraiment** une entité ES-2 future `@ZcrudModel` non câblée (AST des `.g.dart` de `packages/*/lib`, + règle (4) sur les kinds + règle (2) anti-câblage mort — un `.g.dart` manquant ne produit pas un vert vacuel, il déclenche (2)). **Trou résiduel** : entité écrite à la main **héritant `ZExtensible` indirectement** → **M4**. |
| **3. `_requireDomainFromMap` : signature vs comportement** | **Il ne vérifie QUE la signature** — et son message **prescrit** la forme qui détruit `extra`. Couvert par (e) **dans ce repo uniquement** ; **rien** en aval (packages publiés). → **H1 (HIGH)**. |
| **4. D2 / fixtures `dp12_dp13_projection_test`** | **Aucun test affaibli.** Les 3 factories ajoutées (l. 44-48, 76-80, 109-112) sont des constructeurs de domaine ; elles n'ajoutent aucun champ, ne touchent ni `_collectFields` ni les assertions (qui portent sur les `ZFieldSpec` émis). Le repli borné autorisé par la story **n'a pas été utilisé** : D2 tient **sans exception**. ✅ |
| **5. Verrous DW-ES14-2** | **Sains** : ils **rougiront** le jour de la clôture (`containsKey('extension')` devient `true`) et le commentaire interdit explicitement de « réparer » en supprimant l'assertion. Ils **ne cimentent pas** le bug. Ils gardent aussi l'anti-aggravation (`extra` régressé ⇒ rouge). Réserve mineure : **L2**. |
| **6. Régressions cross-package** | **Aucun symbole public supprimé hors du harnais** (`kDomainDecoders`/`ZDomainDecoder` ne vivaient que dans `tool/reserved_keys_gate`, dans `melos.ignore`) ; zéro référence morte (les 2 restantes — `registrars.dart:10`, `reserved_keys_test.dart:95` — sont des **notes historiques** assumées, pas des pointeurs). Les **5** factories de domaine délèguent toutes à `_$ZXxxFromMap` pour les champs du schéma (`z_flashcard.dart:105`, `z_repetition_info.dart:105`, `z_study_folder.dart:115`, `z_study_session_config.dart:78`, `z_choice.dart:31`) ⇒ **aucune régression de décodage**. Seule différence : `ZRepetitionInfo` **clampe** désormais `interval`/`repetitions` négatifs sur la voie registre — **durcissement** (AD-10), pas régression. ✅ |
| **7. AD** | **AD-3** ✅ (zéro `reflectable`) · **AD-4** ✅ sur `extra` — ⚠️ **incomplet sur `source`** (H2) · **AD-5** ✅ (aucun type `cloud_firestore` dans le domaine) · **AD-10** ✅ : le throw de `_requireDomainFromMap` est au **BUILD** (voulu, R6) ; la désérialisation **runtime** reste défensive et c'est désormais **testé** (`registry.decode(kind, {})` non-throw pour les 5 kinds) · **R5** ✅ pour la détection (modèle d'éléments) — ⚠️ dernier résidu textuel : **M1**. |

---

## Décision

- **HIGH H1** et **MAJEUR H2** : **correction obligatoire** avant `done` (ou justification écrite, mais H1 laisse un consommateur publié sans filet et guidé vers le défaut — la justification sera difficile).
- **MEDIUM M1..M4** : à corriger par défaut dans le périmètre (M1/M2/M3 sont dans les fichiers déjà touchés ; **M4** peut légitimement être **reporté en dette tracée** — il est pré-existant et son correctif touche le gate en profondeur — mais **il doit alors être écrit** dans `architecture.md` § Deferred).
- **LOW L1..L3** : consignés ; L2 est trivial à fermer.
- **AC1..AC10** : atteints sur la lettre. **AC7 est atteint sur `extension` mais pris en défaut sur `source`** (H2) : le tableau publié affirme un ✅ que rien n'observe.

---
---

# 🔧 STATUT DE REMÉDIATION (2026-07-13) — agent `bmad-dev-story` (remédiation)

**0 finding reporté.** H1, H2, M1, M2, M3, M4, L2 corrigés. Chaque filet **ajouté ou modifié** est prouvé par **injection de régression réellement exécutée** (R3 : casser → **ROUGE observé** → restaurer à l'octet près → **VERT observé**).

## 🔴 H1 — ✅ CORRIGÉ · le contrat a gagné du **POUVOIR**, pas seulement de la prose

Le diagnostic de la revue est **entièrement confirmé sur le code réel**. Trois filets, tous par machine.

### (1) Le message prescrit désormais la forme QUI MARCHE

`_prescription(className, extensible:)` est **différenciée** : une classe **non**-`ZExtensible` (patron `ZChoice`) se voit toujours prescrire la délégation nue — **légitime pour elle** ; une classe **`ZExtensible`** se voit prescrire le patron **réel du repo** (lu sur `ZFlashcard.fromMap`/`ZStudyFolder.fromMap`), avec `_reservedKeys` dérivé de `$XxxFieldSpecs` + `...ZSyncMeta.reservedKeys`, `_extraFrom(map)`, **et** le `toMap()` d'instance. Le message se termine par : *« ⛔ NE PAS écrire `=> _$XxxFromMap(map);` nu : le build le REFUSE »*.

### (2) BUILD ROUGE sur la délégation nue depuis une classe `ZExtensible` — AST, zéro regex (R5)

Détection sur l'**AST du corps** du décodeur (`ParsedLibraryResult.getFragmentDeclaration(...).node`), forme `=> …` **et** bloc à `return` unique. `ZExtensible` est résolu **transitivement** (`TypeChecker.isAssignableFrom` — le motif `class ZSmartNote extends ZBaseStudyEntity` d'ES-2 est couvert).

### (3) 🔴 GARDE RUNTIME émis dans le `.g.dart` — **le filet qui suit les packages PUBLIÉS**

C'est la réponse au cœur de H1 : *« un consommateur externe est GUIDÉ VERS LE DÉFAUT, sans aucun filet »*. `_$zRequireExtraPreserved` est émis dans le `registerXxx` de **toute** classe `ZExtensible` : il **décode une sonde** portant une clé hors-schéma et exige qu'elle **survive au ROUND-TRIP COMPLET**. Il **OBSERVE le POUVOIR** au lieu de juger une forme — donc il attrape **toute** factory impotente, y compris celles que (2) ne peut pas voir.

- **Pas sous `assert`** (R6) : un `assert` s'évapore en release — le filet disparaîtrait là précisément où la perte est définitive.
- **REFUTATION DE LA DIRECTION DONNÉE** — *« garde émis au runtime … pour les `ZExtensible` »* supposait **une** jambe (`fromMap`). **L'exécution a montré que c'était insuffisant** : le `toMap()` **GÉNÉRÉ** (extension `XxxZcrud`) **n'étale PAS `extra`**. Une entité `ZExtensible` qui ne déclare pas son propre `toMap()` d'instance décode `extra` correctement **et le détruit à l'encodage** — le garde à une jambe l'aurait **certifiée conforme**. Le garde vérifie donc les **DEUX jambes** (entrée `fromMap` **et** sortie `toMap`). *Ce défaut n'était pas trouvable par raisonnement : il est apparu en faisant tourner le témoin.*

### Fixtures permanentes, **isolées par règle** (R2) — `packages/zcrud_generator/test/models/extensible_probe.dart`

| Fixture | Jambe fautive | Conforme sur | Résultat attendu |
|---|---|---|---|
| `ProbeKeeper` | — (témoin) | les deux | `register…` **PASSE** |
| `ProbeDropper` | **entrée** (`fromMap` sans `extra:`) | sortie (`toMap` étale `...extra`) | `register…` **LÈVE** |
| `ProbeEncodeDropper` | **sortie** (pas de `toMap()` d'instance) | entrée (`fromMap` peuple `extra`) | `register…` **LÈVE** |

⚠️ `ProbeDropper` n'est **pas** une délégation nue (corps ré-écrit à la main) : le contrat de **build** la laisse passer — **c'est voulu**, sinon la fixture prouverait la mauvaise règle.

### (4) Le `reason` de l'assertion (e) désignait le mauvais coupable — ✅ CORRIGÉ

`assertions.dart` liste désormais les causes **dans le bon ordre** : (1) **la factory de DOMAINE** (la plus probable), (2) le `toMap()` d'instance, (3) **le registrar généré** — *« la MOINS probable des trois »*. Il signale en outre que si (e) rougit **seule**, c'est que les deux filets amont ont été contournés — et qu'il faut le dire.

### Injections R3 — **SORTIES RÉELLES**

**Injection C — le geste que l'ANCIEN MESSAGE DICTAIT, appliqué à `ZFlashcard` :**
```
### casse: ZFlashcard.fromMap => _$ZFlashcardFromMap(map);  (délégation NUE) ###
[zcrud_flashcard]:   `ZFlashcard.fromMap` DÉLÈGUE NUEMENT à `_$ZFlashcardFromMap` alors que ZFlashcard
  est `ZExtensible` (slot `extra`, AD-4) — c'est EXACTEMENT DW-ES14-1 : `_$ZFlashcardFromMap` ne connaît
  QUE les champs `@ZcrudField` et laisse `extra` VIDE. Le build serait vert et `registry.decode`
  DÉTRUIRAIT toute clé métier inconnue du schéma, à chaque cycle lecture→écriture — irréversible.
[zcrud_flashcard]:           extra: _extraFrom(map),                  // ✅ clés HORS-schéma
[zcrud_flashcard]:   Failed to build with build_runner in 2s; wrote 0 outputs.
RC GENERATE = 1
=== RESTAURATION ===  IDENTIQUE (octet près)
RC GENERATE (restauré) = 0
```
> **C'est LA preuve de H1** : le geste que le message prescrivait **casse maintenant le build**, et le nouveau message prescrit `extra: _extraFrom(map)`.

**Injection A — garde runtime, jambe ENTRÉE** (`ZFlashcard.fromMap` : `extra: const {}`) :
```
00:00 +0 -1: loading .../reserved_keys_test.dart [E]
  Bad state: zcrud/DW-ES14-1 (AD-4) : `ZFlashcard` est `ZExtensible`, mais son décodeur de domaine
  `ZFlashcard.fromMap` NE PEUPLE PAS `extra` — la clé hors-schéma de la sonde a été DÉTRUITE au DÉCODAGE.
[gate:reserved-keys] 1 violation(s) — AD-19.1.
```
> Le garde lève **à l'ENREGISTREMENT** — avant même qu'un test tourne. Un consommateur externe l'obtiendrait **identiquement**, sans harnais.

**Injection B — garde runtime, jambe SORTIE** (`ZFlashcard.toMap` : `...extra` retiré) :
```
  Bad state: zcrud/DW-ES14-1 (AD-4) : `ZFlashcard.fromMap` préserve bien `extra`, mais
  `ZFlashcard.toMap()` NE LE RÉÉMET PAS — la clé hors-schéma est DÉTRUITE à l'ENCODAGE.
  Le round-trip d'un store est donc amnésique malgré un décodage correct.
[gate:reserved-keys] 1 violation(s) — AD-19.1.      RC GATE = 1
=== RESTAURATION ===  IDENTIQUE (octet près)
```

---

## 🟠 H2 — ✅ CORRIGÉ · et **la perte est PIRE que ce que la revue décrivait**

**Vérifié sur le code réel (spike exécuté), puis épinglé.** La revue annonçait une « double transformation » sur une donnée jamais décodée. **La mesure montre une PERTE DE VALEURS SÈCHE** :

```
(1) registry.decode (sans app-registry) -> ZCustomSource, payload={article_id: A-42, chapitre: 3}
    ENCODE source={article_id: A-42, chapitre: 3, kind: article}   ⇒ round-trip registre→registre FIDÈLE ✅
(2) ZFlashcard.fromMap(sourceRegistry:)  -> payload={id: A-42, ch: 3}      (codec appliqué ✅)
(3) registry.decode                       -> codec appliqué ? FALSE         (codec IGNORÉ ⚠️)
(4) decode(REGISTRE) -> toMap(sourceRegistry:) =>
    source={article_id: null, chapitre: null, kind: article}                 ⛔ VALEURS NULLIFIÉES
(5) decode(domaine+reg) -> toMap(reg) =>
    source={article_id: A-42, chapitre: 3, kind: article}                    (témoin ✅)
```

Le scénario (4) est **exactement celui que la dartdoc autorisait** (« `source` intégralement préservé » ⇒ `fromRegistry` est sûr, + « sinon, utilisez le constructeur nominal » ailleurs dans la même dartdoc). Une app qui **lit** par `fromRegistry` et **écrit** par la voie nominale **nullifie ses données**.

**Corrections :**
1. **La sonde porte enfin `source`** — `kProbeBodies['flashcard']` porte `{'kind': 'zz_source_test', 'zz_payload': 'brut'}` (kind **inconnu** des variants génériques ⇒ exerce la voie `ZCustomSource`, celle qu'un consommateur ouvre via `ZSourceRegistry`).
2. **3 verrous** (`reserved_keys_test.dart` › groupe « H2 — canal `source` ») : (a) le payload brut **survit** au round-trip registre→registre — *le seul point que la dartdoc pouvait légitimement revendiquer, désormais OBSERVÉ* ; (b) le **`ZSourceRegistry` de l'app est IGNORÉ** ; (c) **mélanger les voies CORROMPT les valeurs**.
3. **La dartdoc dit la vérité MESURÉE** : `source` passe de « ✅ PRÉSERVÉ » à « ⚠️ payload round-trippé BRUT, mais `ZSourceRegistry` NON APPLIQUÉ », avec le tableau de corruption. Les **3 conditions** d'usage de `fromRegistry` sont explicitées (pas d'`extension`, **pas de codec de source**, **pas de mélange de voies**).
4. **DW-ES14-2 élargie à sa VRAIE cause racine** (`architecture.md` § Deferred) : la dette n'est pas « `extension` est détruit », c'est **« `ZcrudRegistry` n'offre AUCUN SLOT D'INJECTION »** — **UNE cause, DEUX symptômes** (`extensionParser` **et** `sourceRegistry`). Le **critère de clôture couvre désormais les deux** : *« une clôture qui ne traiterait qu'`extension` laisserait `source` cassé en silence — c'est exactement la façon dont ce second symptôme a échappé à ES-2.0 »*.

### Injection R3 (E) — **SORTIE RÉELLE** (`ZFlashcardSource.fromJson` : `default:` → `null`)
```
00:00 +32 -1: H2 … ✅ le PAYLOAD BRUT survit au round-trip registre → registre [E]
  Expected: {'kind': 'zz_source_test', 'zz_payload': 'brut'}
    Actual: <null>
00:00 +32 -2: H2 … ⚠️ le `ZSourceRegistry` de l'app est IGNORÉ (codec JAMAIS appliqué) [E]
00:00 +32 -3: H2 … ⛔ MÉLANGER LES VOIES CORROMPT LES VALEURS [E]
  Expected: {'zz_payload': null, 'kind': 'zz_source_test'}
    Actual: <null>
=== RESTAURATION ===  IDENTIQUE (octet près)
```
> Les 3 verrous **MORDENT**. Le ✅ revendiqué **existe enfin en machine**.

---

## 🟡 M1 — ✅ CORRIGÉ · signature jugée sur les **TYPES**, plus sur une chaîne

`_requireCompatibleSignature` compare via le **`TypeSystem`** de l'analyzer : `typeSystem.isAssignableTo(Map<String,dynamic>, paramType)` — c'est **exactement** le critère que le tear-off exige. Les 3 formes que la v1 **rejetait à tort** sont désormais **acceptées et testées** : `Map<String, Object?>`, un **typedef alias**, une forme préfixée par un import. (Prouvé d'abord par spike, puis figé en test.)

## 🟡 M2 — ✅ CORRIGÉ · un `fromMap` **statique** est accepté

`element.methods.where((m) => m.isStatic && m.name == 'fromMap')` est consulté en repli de `element.constructors`. Le message d'absence dit désormais la vérité : *« ne déclare AUCUN décodeur de domaine `fromMap` (ni factory, ni méthode statique) »*. Test : `M2 : static fromMap (tear-off valide) → ACCEPTÉE`.

## 🟡 M3 — ✅ CORRIGÉ · le contrat est écrit **là où un consommateur le lira AVANT de se cogner**

- **`@ZcrudModel` dartdoc** (`zcrud_annotations`) — le contrat public de l'annotation : les **deux** formes (avec / sans `extra`), les **trois filets machine**, et l'avertissement **CHANGEMENT CASSANT**.
- **`zcrud_generator/CHANGELOG.md`** — section `Unreleased` : *what changed / why / migration*, avec les deux patrons de code.
- **`zcrud_generator/README.md`** — section « Required: a domain `fromMap` on every `@ZcrudModel` ».
- **`zcrud_annotations/CHANGELOG.md`** — renvoi au CHANGELOG du générateur.

> ⚠️ **Pas de bump de version** : `pubspec.yaml` reste en `0.1.0` (publier est un acte de release, hors périmètre d'une remédiation). Les notes vivent sous **`## Unreleased`** — la dartdoc dit *« BREAKING — cf. CHANGELOG »* et **ne prétend aucun numéro de version qui n'existe pas**.

## 🟡 M4 — ✅ CORRIGÉ (**non reporté**) · couverture `ZExtensible` **TRANSITIVE**

`gate_reserved_keys.dart` construit un **`_TypeIndex`** depuis l'AST (arêtes `extends` / `with` / `implements` / **`on`** — cette dernière était **totalement ignorée**) et calcule la **fermeture transitive** (mémoïsation + garde-fou de cycle). Un seul parcours de disque alimente l'index, le volet (B) et la règle (3). **Zéro regex** (R5) : les arêtes viennent de l'AST ; seule la **résolution par nom** est faite (le gate parse sans résolution sémantique, par conception).

**2 fixtures permanentes isolées** (`prove_gates.dart`) — chacune **verte au volet (B)**, sans `*.g.dart` ni harnais, donc **seule la règle (3) peut la faire rougir** :
- `couverture-transitif-super-type-indirect` — `ZSmartNote extends ZBaseStudyEntity`, **cross-fichier** (le cas exact du finding) ;
- `couverture-transitif-chaine-et-mixin-on` — chaîne à 3 niveaux + `mixin ZAudioSlot on ZExtensible`.

### Injection R3 (D′) — **SORTIE RÉELLE** (prédicat **v1 exact** restauré : super-type DIRECT nommé `ZExtensible`)
```
  [OK]   reserved-keys/couverture-forme-1-une-ligne                   … volet (B) MUET: true
  [OK]   reserved-keys/couverture-forme-2-entete-enroulee             … volet (B) MUET: true
  [OK]   reserved-keys/couverture-forme-3-final-class                 … volet (B) MUET: true
  [OK]   reserved-keys/couverture-forme-4-base-sealed-interface       … volet (B) MUET: true
  [OK]   reserved-keys/couverture-forme-5-alias-de-classe             … volet (B) MUET: true
  [FAIL] reserved-keys/couverture-transitif-super-type-indirect — règle (3) nomme
         ZBaseStudyEntity+ZSmartNote: false
  [FAIL] reserved-keys/couverture-transitif-chaine-et-mixin-on — règle (3) nomme
         ZDeepNote+ZOnMixinNote: false
RESULTAT: 35 OK, 2 FAIL.
=== RESTAURATION ===  IDENTIQUE (octet près)   →   RESULTAT: 37 OK, 0 FAIL.
```
> **EXACTEMENT les 2 nouvelles fixtures rougissent**, les 5 pré-existantes restent vertes ⇒ **isolation par règle prouvée (R2)**.

> 🔍 **Note de méthode (honnêteté)** : ma **première** injection (D) neutralisait la *récursion* et non le *prédicat v1* — elle ne faisait rougir **qu'une** fixture sur deux, ce qui aurait laissé croire que la fixture « super-type indirect » ne prouvait rien. **C'est le protocole R3 lui-même qui a attrapé mon injection trop faible.** Refaite avec le prédicat v1 exact. *Illustration directe de la leçon de la rétro : un rouge non provoqué au bon endroit ne prouve rien.*

## 🟢 L1 — ✅ SANS OBJET (résorbé par H1)

« (e) n'est jamais observée SEULE sur la voie réelle ((b) tombe avant) ; sa preuve isolée était une sonde **jetable**, supprimée. » La preuve a désormais une **durée de vie permanente**, et **en amont de (e)** : les fixtures `ProbeDropper` / `ProbeEncodeDropper` (garde runtime, **isolées par jambe**) et `_ExtraDroppingEntity` (assertion (e)) vivent dans l'arbre. Le mode de destruction est épinglé **à trois étages** (build, enregistrement, gate).

## 🟢 L2 — ✅ CORRIGÉ · le verrou DW-ES14-2 ne peut plus annoncer un **faux succès**

Deux **préconditions** ajoutées **avant** l'assertion de verrou : (i) `extension` est **toujours une clé réservée** (elle n'a pas fuité dans `extra`) ; (ii) le **slot typé est bien `null`** (aucun parser injecté — c'est *cela* que DW-ES14-2 décrit).

### Injection R3 (F) — **SORTIE RÉELLE** (`'extension'` **retirée** de `ZFlashcard._reservedKeys`)
```
  Expected: false
    Actual: <true>
  [flashcard] L2 : `extension` n'est PLUS une clé réservée de l'entité — elle a FUITÉ dans `extra`.
  Le verrou DW-ES14-2 ci-dessous n'est plus interprétable (il rougirait en annonçant à tort la clôture
  de la dette). Ce n'est PAS la clôture : c'est une régression de `_reservedKeys`.
=== RESTAURATION ===  IDENTIQUE (octet près)   →   RC GATE = 0
```
> La précondition mord **la première**, avec la **VRAIE** raison. Le faux signal de succès est **fermé**.

## 🟢 L3 — 🔵 TRANCHÉ (hors périmètre de la remédiation)

Le constat du dev est **exact** et vérifié : `.gitignore:30` ignore `*.g.dart` **partout**, **sauf** `packages/*/lib/**` (négation explicite). Les `.g.dart` de `packages/*/lib/` **doivent** donc être committés (distribution en dépendance git — gate `codegen-distribution`), ceux de `test/models/` **non** (`article.g.dart` n'est pas suivi ; ma nouvelle fixture `extensible_probe.g.dart` suit **exactement** le même régime — vérifié par `git check-ignore`). Les `pubspec.lock` restent une **décision d'orchestrateur** au gate de commit. **Aucune écriture de ma part.**

---

## Vérif verte finale — **rejouée intégralement** (RC réels)

| Commande | Résultat |
|---|---|
| `dart run melos run generate` | **SUCCESS** |
| `dart run melos run analyze` (repo-wide) | **RC=0** |
| `dart run melos run verify` (repo-wide, **avant-plan**) | **RC=0** |
| `dart run scripts/ci/prove_gates.dart` | **37 OK / 0 FAIL** (baseline 35 → **+2**, jamais moins) |
| `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK** (15 nœuds) |
| `dart run melos list` | **15** |

**Compteurs de tests (avant remédiation → après)**

| Suite | Avant | Après |
|---|---|---|
| `zcrud_generator` | 91 | **102** (+11) |
| `reserved_keys_gate` (harnais) | 32 | **35** (+3) |
| `zcrud_flashcard` | 189 | **189** |
| `zcrud_study_kernel` | 108 | **108** |
| `zcrud_core` | 911 | **911** |
| `zcrud_firestore` | 90 | **90** |
| `zcrud_mindmap` | 110 | **110** |

**Périmètre respecté** : aucune écriture dans `zcrud_core` ni `zcrud_study_kernel` (hors `*.g.dart` **régénérés**). `zcrud_flashcard`/`z_flashcard_source.dart` n'ont été touchés **que** par les injections R3, **restaurées à l'octet près** (`git status` : seuls les `*.g.dart` régénérés apparaissent ; `grep -r "INJECTION R3"` → **aucune trace résiduelle**). `melos list` = **15**. **Aucun commit, aucune écriture du `sprint-status.yaml`.**

## Points où j'ai dû REFUTER la direction donnée

1. **Le garde runtime devait avoir DEUX jambes, pas une.** La direction (H1 pt. 2) évoquait un garde observant `fromMap`. **Le témoin `ProbeKeeper` a rougi** en le montrant : le `toMap()` **GÉNÉRÉ** n'étale **pas** `extra`, donc une entité qui décode correctement peut **détruire `extra` à l'encodage** — et un garde à une jambe l'aurait **certifiée conforme**. Le garde vérifie le **round-trip complet**, et une **3ᵉ fixture** (`ProbeEncodeDropper`) isole cette jambe.
2. **La détection AST de la délégation nue n'était PAS intenable** — la direction demandait de le prouver ou de proposer un repli. Elle est **implémentée** (`getParsedLibraryByElement` + `getFragmentDeclaration`). Mais elle **ne suffit pas** : c'est un filet de **FORME** (un corps ré-écrit à la main qui « oublie » `extra:` lui échappe). Le filet de **POUVOIR** est le garde runtime. **Les deux sont livrés** — le second n'est pas un repli du premier, il est **strictement plus fort**.
3. **H2 est plus grave que décrit** : pas une « double transformation », une **nullification des valeurs** (mesurée). La dartdoc et l'architecture le disent maintenant en ces termes.
4. **Ma propre injection M4 était trop faible** et le protocole R3 l'a attrapée (cf. § M4). Consigné plutôt que masqué.
