---
baseline_commit: 3f41d95
---

# Story CHAT-0 : modèle de conversation neutre (`zcrud_core`)

Status: review

<!-- Epic CHAT : portage de l'assistant IA. Story TÊTE, [L], SÉQUENTIELLE — seule écriture dans zcrud_core tant qu'elle n'est pas verte. -->
<!-- Sources de plan : sprint-status.yaml:560-583 (décision RÉVISÉE 2026-07-31) ; ~/.claude/plans/tingly-brewing-cake.md § « PLAN — Epic CHAT » ; docs/plan-portage-assistant-ia.md. -->
<!-- Les dépôts /home/zakarius/DEV/iffd et /home/zakarius/DEV/lex_douane sont STRICTEMENT en LECTURE SEULE : grep/read uniquement, jamais d'écriture. -->

## Story

As a **développeur d'une application hôte de zcrud (lex_douane, IFFD, DODLP)**,
I want **un modèle de domaine de conversation IA complet, neutre et défensif dans `zcrud_core`**,
so that **je puisse porter rapidement mon assistant existant sur un socle partagé — en retrouvant la richesse déjà mûre de lex (blocs typés, sources, thinking, feedback, suggestions, confiance) — sans que le cœur gagne une seule dépendance, et sans être bloqué si mes propres variantes évoluent après coup.**

**Couvre :** le lot **C0** de l'epic CHAT — le **modèle de domaine seul**, dans `zcrud_core` uniquement.
**Dépend de :** rien. **Débloque :** CHAT-1 (ports IA + `ZChatStreamEvent`), CHAT-2 (`ZChatController`), puis C3..C6.
**Hors périmètre (par conception, justifié en Dev Notes) :** tout port/repository/stream (CHAT-1), tout controller (CHAT-2), tout widget/rendu/couleur/`Semantics` (CHAT-3), les pièces jointes *au-delà du modèle* et l'export (CHAT-5), le menu découplé (CHAT-4), l'adapter Syncfusion (CHAT-6), le persona/onboarding conversationnel, la recherche hors-ligne, le TTS.

---

## 🔴 Décision owner du 2026-07-31 — le socle est RICHE, pas minimal

> **RÉVOCATION EXPLICITE.** La consigne antérieure « noyau fermé **minimal**, ne pas figer les 12 variantes de lex »
> (`docs/plan-portage-assistant-ia.md:3.3`, `plans/tingly-brewing-cake.md § Modèle`) est **RÉVOQUÉE**.
> Le socle doit être **LE PLUS COMPLET POSSIBLE**, prêt à être porté **rapidement** dans IFFD et lex.
> **Là où lex est mûr, on recopie ses fonctionnalités ET SA MANIÈRE DE FAIRE.**

**Mitigation exigée, et elle ne coûte rien** : on reprend la richesse de lex **ET** on conserve l'extension
par `ZTypeRegistry`/`ZSourceRegistry` (AD-4) **par-dessus**. Les deux ne s'excluent pas. Raison :
lex est en **développement actif** et une API publique zcrud est **irréversible** — le registre évite le
blocage si lex fait évoluer ses variantes après coup. Noyau **riche** + **porte ouverte**.

⚠️ Le dev ne doit donc **jamais** invoquer « minimalisme » pour omettre un type listé en AC. À l'inverse,
il ne doit **rien inventer** qui n'existe ni chez lex ni chez IFFD : la richesse vient du **portage**, pas de la
création. Tout ajout non porté est un finding.

---

## Décisions tranchées avant dev

### D1 — 🔴 AUCUN codegen : la sérialisation est ÉCRITE À LA MAIN, et ce n'est pas un pis-aller

**Mesuré sur disque** : `packages/zcrud_core/pubspec.yaml` ne déclare **ni** `json_annotation`, **ni**
`build_runner`, **ni** `zcrud_annotations` ; `find packages/zcrud_core/lib -name '*.g.dart'` → **0 fichier**.
Et il ne peut pas en gagner : `zcrud_annotations` est un package `zcrud_*`, donc une **arête sortante du
cœur** ⇒ **AD-1 / `graph_proof` CORE OUT=0 ROUGE**.

⇒ **Interdits dans cette story** : `@ZcrudModel`, `@ZcrudField`, `@JsonSerializable`, `part '*.g.dart'`,
`melos run generate`, toute modification de `packages/zcrud_core/pubspec.yaml`.
⇒ **Obligatoire** : `fromMap`/`toMap` **manuels**, défensifs, sur le patron **exact** de
`packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart` (union scellée interne + variant ouvert
+ registre + helpers `_coerceStringMap`/`_asString`/`_guard`).

🔵 **Convergence heureuse** : c'est **déjà la manière de faire de lex** pour ce module précis —
`chat_message.dart:91-194` et `content_block.dart:13-66` sont **manuels et défensifs** (seules
`ChatConversation`/`ChatAttachment`/`ChatThinkingStep` passent par `@JsonSerializable`). Recopier lex et
respecter zcrud ne s'opposent donc pas ici.

### D2 — Faux-ami `WorkflowEffort` : deux concepts, **jamais** fusionnés

| Dépôt | Symbole | Valeurs | Sens réel |
|---|---|---|---|
| lex | `WorkflowEffort` (`packages/lex_core/lib/domain/enums/chat_enums.dart:20-26`) | `concis` / `standard` / `detaille` | **LONGUEUR de la réponse** (labels UI Mini/Plus/Pro) |
| IFFD | `WorkflowEffort` (`lib/.../ai_routers_page.dart:24-28`) | `low` / `medium` / `high` | **EFFORT DE CALCUL** du routeur de modèles |

**Même nom, deux concepts.** Les fusionner produirait un enum vide de sens.

**Tranché** : CHAT-0 ne porte **que celui de lex**, et le **renomme par sa sémantique** →
**`ZChatResponseLength { concise, standard, detailed }`**.
Le concept IFFD (effort de calcul) **n'est pas porté ici** : ce n'est pas un champ de message, c'est un
paramètre d'appel — il appartiendra à CHAT-1 s'il est retenu, sous un nom **distinct**
(`ZChatComputeEffort`), jamais sous `Effort` seul.
🔴 **Le symbole `WorkflowEffort` (et tout symbole nommé `*Effort*` dans le chat) est INTERDIT dans
`packages/*/lib`** — garde par **grep négatif** (G16), pour que personne ne réintroduise l'ambiguïté par
copier-coller depuis l'un ou l'autre dépôt.

### D3 — 🔴 `updated_at` est la propriété de `ZSyncMeta` : la conversation ne peut PAS le porter

`ChatConversation` de lex persiste `updated_at` **dans le corps du document**
(`chat_conversation.dart:9-10`, `@JsonKey(name: 'updated_at')`). En zcrud, `updated_at` et `is_deleted`
sont **réservés hors-entité** (AD-16/AD-19) : `ZSyncMeta.reservedKeys`
(`packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart:44`). Un `updated_at` **métier** logé dans le
corps entre en collision avec l'autorité de sync — le store écrit `ZSyncMeta` **APRÈS** le corps ⇒
**le merge Last-Write-Wins est faussé, silencieusement** (c'est le dommage exact documenté en
`z_extensible.dart:36-84`).

**Tranché** : le champ métier existe (lex s'en sert pour **trier les conversations par récence**), mais il
est **renommé par son sens** → `ZChatConversation.lastMessageAt`, persisté **`last_message_at`**.
`toMap()` ne doit émettre **ni** `updated_at` **ni** `is_deleted`, **jamais**, sans aucune exception
« miroir legacy ». Garde G12.

### D4 — Le noyau fermé porte 9 des 12 variantes de blocs de lex ; les 3 autres passent par le registre — et c'est ce qui rend le registre NON décoratif

lex a **12** variantes (`content_block.dart:17-31`). Arbitrage, variante par variante :

| Variante lex | Décision CHAT-0 | Pourquoi |
|---|---|---|
| `Text` | ✅ noyau `ZTextBlock` | universel |
| `Table` | ✅ `ZTableBlock` | universel |
| `KeyDefinition` | ✅ `ZKeyDefinitionBlock` | pédagogique générique (terme/définition/source) |
| `ComparisonTable` | ✅ `ZComparisonTableBlock` | pédagogique générique |
| `Timeline` | ✅ `ZTimelineBlock` | pédagogique générique |
| `Alert` | ✅ `ZAlertBlock` | générique ; `level` reste une **`String` ouverte** (ne pas fermer un enum que lex n'a pas fermé) |
| `MermaidDiagram` | ✅ `ZMermaidDiagramBlock` | `{title?, code}` — deux chaînes, zéro dépendance |
| `Sources` | ✅ `ZSourcesBlock` | provenance = besoin de tout assistant sourcé |
| `Suggestions` | ✅ `ZSuggestionsBlock` | relances = besoin générique (IFFD a l'équivalent dégradé `List<String>`) |
| `LegalReference` | ❌ **app-side** | `{title, articles[], summary, source_type, source_id}` — « articles » est **juridique**. Trop douanier pour un socle éducatif générique. L'app le branche par `ZTypeRegistry.register('legalReference', …)`. |
| `Flashcards` | ❌ **satellite/app-side** | porte `List<Flashcard>` ⇒ `zcrud_core → zcrud_flashcard` = **arête sortante, AD-1 ROUGE**. Branché par `ZTypeRegistry` depuis `zcrud_flashcard`/l'app. |
| `Mindmap` | ❌ **satellite/app-side** | porte `LexiaMindmap` ⇒ `zcrud_core → zcrud_mindmap` = **AD-1 ROUGE**. Idem registre. |

⇒ **Les 12 variantes restent atteignables**, 9 typées dans le cœur, 3 par le registre. Le registre n'est
donc **pas une décoration** : sans lui, trois capacités réelles de lex seraient **inatteignables**. C'est
la preuve que la mitigation exigée par l'owner est **portante**.

**Enveloppe conservée à l'identique de lex** : `{'type': <kind>, 'data': {…}}` (`content_block.dart:14-15`).

**Casse du discriminant** : lex écrit `'Text'`, `'KeyDefinition'` (PascalCase). zcrud persiste ses valeurs
discriminantes en **camelCase** (convention `Naming & Consistency`). Tranché **Postel** :
- **écriture** = canonique camelCase (`text`, `keyDefinition`, `comparisonTable`, `mermaidDiagram`…) ;
- **lecture** = tolérante, les **alias PascalCase de lex sont acceptés** (interop directe avec les
  documents lex existants — condition du « portable rapidement »).

### D5 — Un `type` de bloc inconnu conserve son payload ; il ne devient PAS du texte

lex fait `_ => TextBlock(text: json.toString())` (`content_block.dart:30`) : un bloc inconnu devient une
bulle de texte contenant le **dump Dart de la map**. C'est **destructeur** (round-trip perdu) et
**visible par l'utilisateur**. zcrud fait ce que fait déjà `ZFlashcardSource` : repli sur
`ZCustomContentBlock(kind, payload)`, **payload préservé verbatim**, round-trip garanti même **sans**
codec enregistré. Garde G6.

### D6 — `created_at` absent ne doit PAS faire échouer le message

lex fait `DateTime.parse(json['created_at'] as String)` (`chat_message.dart:157`) : un document sans
`created_at`, ou avec une date corrompue, **lève** et détruit tout le message. C'est une violation
frontale d'**AD-10**. zcrud : `createdAt` est **`DateTime?`**, lu par `DateTime.tryParse`, omis du
`toMap()` s'il est `null`. Garde G11 — et l'injection consiste à **remettre le `DateTime.parse` de lex**.

### D7 — Les registres sont **injectés en paramètre**, jamais des singletons

`ZSourceRegistry` et `ZTypeRegistry` sont **instanciables** et injectés (`ZcrudScope`/binding) —
`z_type_registry.dart:21-24`, `z_source_registry.dart:23-26`. Les `fromMap`/`toMap` du chat les reçoivent
en **paramètres nommés optionnels**, exactement comme
`ZFlashcard.fromMap(map, {sourceRegistry, extensionParser})`
(`packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:104-108`).
🔴 **Ne créer AUCUN nouveau registre.** `ZSourceRegistry` existe : le réutiliser. Un second registre de
provenance serait un doublon et un finding.

### D8 — 🔴 Le gate `reserved-keys` NE VOIT PAS les entités de `zcrud_core` sans câblage explicite

`scripts/ci/gate_reserved_keys.dart` dérive sa couverture des **registrars générés**
(`packages/*/lib/**/*.g.dart`). `ZChatMessage` et `ZChatConversation` mixent `ZExtensible` **sans**
codegen (D1) ⇒ elles tombent **exactement** dans le trou que `manual_probes.dart` est fait pour boucher
(`tool/reserved_keys_gate/lib/src/manual_probes.dart:1-18`), comme `ZMindmap`/`ZMindmapNode`.

**Conséquence machine, non négociable** : la règle **(3)** du gate (`E_disk \ E_covered ≠ ∅` → ROUGE)
fera **échouer `melos run verify`** dès que ces deux classes existeront, tant qu'elles ne sont pas
déclarées dans `kManualProbes`. **Ce n'est pas optionnel et ce n'est pas « pour plus tard ».**
La règle **(B)** exige en outre que **chaque fichier déclarant un `extra` concret contienne le jeton
littéral `ZSyncMeta.reservedKeys`**.

### D9 — Ce portage n'est PAS additif pour IFFD ; le dire est une obligation du dépôt

`CLAUDE.md § Handoffs` documente **trois** occurrences de l'erreur « additif pour qui ? ». Ici, IFFD devra
migrer **champs plats → blocs typés** (`summary/poem/story/humor/…` de `chatbot_message.dart:124-156`) et
**callbacks → contrats `Either`/`Stream`**, donc une **migration de données Firestore**. La story
n'écrit rien chez IFFD (lecture seule) mais **doit consigner ce coût** dans ses Completion Notes pour que
le handoff de fin d'epic ne puisse pas l'omettre — ce serait la **4ᵉ** occurrence.

---

## Acceptance Criteria

> **Discipline R3 obligatoire.** Chaque garde du plan de tests doit être prouvée **mordante** : injecter
> précisément la régression décrite, constater le **rouge**, restaurer, constater le **vert**, et consigner
> chemin/ligne/symptôme dans le Dev Agent Record. **Une garde qui reste verte après retrait du correctif
> est rejetée.** Une garde sans sa régression nommée n'est pas une garde.

1. **AC1 — Emplacement, pureté et barrel.** Tous les types naissent sous
   `packages/zcrud_core/lib/src/domain/chat/`, en **pur Dart** : zéro `import 'package:flutter/…'`, zéro
   `dart:ui`, zéro type backend (`Timestamp`/`Filter`/`FirebaseException`…), zéro widget, zéro couleur,
   zéro libellé d'affichage codé en dur. Les types publics sont exportés depuis
   `packages/zcrud_core/lib/domain.dart` (donc automatiquement depuis le barrel principal, qui fait
   `export 'domain.dart'`), en respectant l'ordre alphabétique des directives. Le fichier de helpers
   internes n'est **pas** exporté. `packages/zcrud_core/test/purity/domain_purity_test.dart` reste vert.

2. **AC2 — Aucune arête, aucune dépendance.** `packages/zcrud_core/pubspec.yaml` est **inchangé**.
   `python3 scripts/dev/graph_proof.py` reste vert (**ACYCLIQUE**, **CORE OUT = 0**). Aucun `part`,
   aucun `*.g.dart`, aucune annotation `@ZcrudModel`/`@JsonSerializable` (D1).

3. **AC3 — Enums, valeurs camelCase, lecture tolérante, jamais de throw.** Sont livrés, chacun avec une
   valeur persistée **camelCase**, un parse **défensif documenté** et zéro libellé UI :
   `ZChatRole {user, assistant, system, unknown}` (repli `unknown`) ·
   `ZChatResponseLength {concise, standard, detailed}` (repli `standard` ; **alias de lecture** `concis`/`detaille`) ·
   `ZChatLengthBias {shorter, asIs, longer}` (repli `asIs` ; alias `as_is`) ·
   `ZChatFeedbackRating {up, down}` (repli `null`) ·
   `ZChatFeedbackCategory {inaccurate, incomplete, offTopic, wrongCitation, inappropriateTone}` (repli `null` ; alias snake) ·
   `ZChatSuggestionType {followUp, relatedTopic, deepDive}` (repli `null` ; alias snake) ·
   `ZChatSuggestionActionType {sendMessage, navigate, copy}` (repli `null` ; alias snake) ·
   `ZChatSourceUsageStatus {cited, consulted, generalKnowledge}` (alias `general_knowledge`) ·
   `ZChatDatasetFreshness {fresh, stale, unknown}` (repli `unknown`) ·
   `ZChatConfidenceLevel {high, moderate, toVerify}` ·
   `ZChatConfidenceFactorSense {positive, neutral, negative}`.
   Aucun parse ne lève ; aucun enum ne porte de `label`/`colorValue`/`iconName` (lex en a — `chat_enums.dart:34-53` — c'est de la **présentation**, elle reste app-side, FR-26/AD-13).

4. **AC4 — 🔴 Le faux-ami est neutralisé et gardé par une machine.** Aucun symbole nommé
   `WorkflowEffort` n'existe dans `packages/*/lib`. La dartdoc de `ZChatResponseLength` nomme
   explicitement les deux concepts, leurs deux fichiers d'origine et interdit la fusion. Un test de garde
   source (grep négatif prouvé) échoue si le symbole réapparaît (G16).

5. **AC5 — Blocs de contenu : 9 variantes typées + variant ouvert + registre.** `ZContentBlock` est une
   `sealed class` **interne** portant `String get kind` et
   `Map<String, dynamic> toJson({ZTypeRegistry? typeRegistry, ZSourceRegistry? sourceRegistry})`, avec les
   variants de **D4** : `ZTextBlock`, `ZTableBlock`, `ZKeyDefinitionBlock`, `ZComparisonTableBlock`
   (+ `ZComparisonColumn`), `ZTimelineBlock` (+ `ZTimelineEvent`), `ZAlertBlock`, `ZMermaidDiagramBlock`,
   `ZSourcesBlock`, `ZSuggestionsBlock`, **plus** `ZCustomContentBlock(kind, payload)`.
   `static ZContentBlock? fromJson(Object? raw, {ZTypeRegistry? typeRegistry, ZSourceRegistry? sourceRegistry})`
   est **totale et non levante** : `raw` non-map → `null` ; `type` absent/vide → `null` ; enveloppe
   `{'type','data'}` respectée ; `type` **enregistré** dans `typeRegistry` → payload reconstruit par le
   codec de l'app ; `type` inconnu **et** non enregistré → `ZCustomContentBlock` **payload verbatim**
   (D5). Chaque variant a `==`/`hashCode` structurels (`zJsonEquals`/`zJsonHash` pour les payloads).

6. **AC6 — `ZChatSource` réutilise `ZSourceRegistry`, sans créer de second registre.**
   `ZChatSource` est **une seule classe concrète** portant la **forme commune** de lex
   (`chat_source.dart:19-65`) : `sourceType` (persisté `source_type`), `displayText`, `relevanceScore`
   (défaut `0.0`), `verified` (`bool?`), `verificationStatus`, `snippet`, `breadcrumb`, `ranker`,
   `corpus`, `usageStatusRaw`, plus `payload` (reste de la map, verbatim ou reconstruit par le codec
   `ZSourceRegistry` si le `source_type` est enregistré). Dérivés **fail-safe** portés de lex :
   `isVerified` ⇔ `verificationStatus == 'verified'` **uniquement** (`null`/`not_applicable`/
   `pass-through` ⇒ `false`, jamais présumer vérifié) et `usageStatus` (parse défensif, défaut `cited`).
   Les **14 sous-types douaniers de lex ne sont PAS portés** : ils sont branchés par l'app via
   `ZSourceRegistry.register(kind, …)`. **Aucun nouveau registre n'est créé.**

7. **AC7 — Value objects mûrs portés de lex.** Sont livrés, immuables, `const` quand possible,
   `==`/`hashCode` structurels, `fromJson`/`toJson` défensifs :
   `ZChatThinkingStep {agent, content, timestamp}` ·
   `ZChatSuggestion {id, type (String brut) + typed getter, content, actions}` et
   `ZChatSuggestionAction {shortcut, title, description, actionType (String brut) + typed getter, payload?}` ·
   `ZChatAttachment {id, url, mimeType, fileName}` ·
   `ZChatResponseConfidence` (métriques de grounding + `ZChatConfidenceFactor` + `ZChatConfidenceThresholds`
   + règle dérivée `level` **fail-safe**) ·
   `ZChatSourceFreshness` (+ `isPotentiallyOutdated` fail-safe) ·
   `ZChatQuotaSnapshot {limit, remaining, resetEpoch, prepaidBalance?}` (+ `isExhausted`, `isBounded`).
   Le `type`/`actionType` sont conservés en **`String` brut** (round-trip lossless d'une valeur inconnue)
   **et** exposés typés par un getter dérivé — supérieur à lex, qui perd l'un ou l'autre.

8. **AC8 — Règles métier fail-safe portées à l'identique, seuils nommés.** `ZChatResponseConfidence.level`
   reproduit la règle déterministe de `response_confidence.dart:158-200` : dégradation dure vers
   `toVerify` (citation guard `degraded`/`all_rejected`/`error`, couverture
   `unavailable`/`partial`/`error`, sources attendues mais 0 vérifiée, scores `null` sans source
   concordante, aucun signal) ; `high` **uniquement** si guard `ok` **et** ≥ seuil de sources vérifiées
   **et** fidélité ≥ seuil **et** complétude ≥ seuil ; `moderate` sinon. **Jamais `high` par défaut.**
   Les seuils sont des constantes **nommées** (`ZChatConfidenceThresholds`), pas des littéraux épars.
   `ZChatSourceFreshness.isPotentiallyOutdated` vaut `true` **uniquement** sur `stale` **ou**
   `pendingUpdates` — `unknown` reste **neutre** (jamais marqué périmé).

9. **AC9 — `ZChatMessage` : complet, extensible, défensif.** `ZChatMessage extends ZEntity with ZExtensible`.
   Champs : `id` (`String?`, **éphémère** = message en cours de streaming non matérialisé),
   `conversationId`, `role`, `contentBlocks: List<ZContentBlock>`, `sources?`, `attachments?`,
   `createdAt: DateTime?` (**D6**), `thinking?`, `suggestions?`, `feedbackRating?`, `feedbackCategory?`,
   `feedbackComment?`, `agentsCalled: List<String>?`, `confidence?`, `sourceFreshness?`,
   `versionKey: String?`, `extension: ZExtension?`, `extra`.
   Getter `content` = concaténation des `ZTextBlock` (porté de `chat_message.dart:69-70`).
   `copyWith` avec **sentinelle** (`chat_message.dart:11,196-241`) pour distinguer « non fourni » de
   « remis à `null` » sur **tous** les champs nullables.
   `fromMap(map, {ZTypeRegistry?, ZSourceRegistry?, ZChatExtensionParser?})` ne lève **jamais** : map vide,
   `role` inconnu, bloc de type inconnu, `sources`/`thinking`/`suggestions` malformés, `created_at`
   absent/corrompu ⇒ le parent **survit**, élément par élément (un élément de liste illisible est
   **ignoré**, il n'annule pas la liste).
   Clés persistées **snake_case** : `id, conversation_id, role, content_blocks, sources, attachments,
   created_at, thinking, suggestions, feedback_rating, feedback_category, feedback_comment, agents_called,
   confidence, source_freshness, version_key, extension` + étalement d'`extra`.

10. **AC10 — `ZChatConversation` : complet, sans collision de sync.**
    `ZChatConversation extends ZEntity with ZExtensible` : `id`, `title`, `createdAt: DateTime?`,
    **`lastMessageAt: DateTime?`** persisté **`last_message_at`** (D3), `messageCount: int` (défaut `0`),
    `pinned: bool` (défaut `false`), `pinnedAt: DateTime?`, `extension`, `extra`. `copyWith` à sentinelle.
    🔴 `toMap()` **n'émet jamais** `updated_at` ni `is_deleted`, dans **aucun** cas de figure.
    Le scoping IFFD (`folderId`/`subFolderId`/`documentId`) et ses `isArchived`/`isChatSession`/
    `conversationSummary` **ne sont pas portés** : ils passent par `extra`/`ZExtension` (spécificités
    d'hôte, SYNTHESE-LEX-IA §3).

11. **AC11 — Slots AD-4 câblés, `extra` étanche aux clés réservées.** Les deux entités déclarent leur
    ensemble de clés réservées = **clés de leur schéma** ∪ `{'extension'}` ∪ **`ZSyncMeta.reservedKeys`**
    (jeton littéral présent dans le fichier — règle (B) du gate), et l'appliquent :
    `zSanitizeExtra` **eager** dans `fromMap` **et** `copyWith`, `zNormalizeExtra` **sur l'accesseur**
    `extra` (le constructeur est `const`, il ne peut rien filtrer — `z_extensible.dart:86-121`).
    `extra` est **non modifiable** et fait un **round-trip exact** des clés inconnues.
    Égalité/hachage du slot par `zJsonEquals`/`zJsonHash` (jamais un `_mapEquals` superficiel recopié).
    `extension` est parsé par le `ZChatExtensionParser` injecté, absorbé par `ZExtension.guard` ⇒
    repli `null`, jamais de throw.

12. **AC12 — 🔴 Le harnais `reserved_keys_gate` est câblé DANS CETTE STORY.**
    `tool/reserved_keys_gate/lib/src/manual_probes.dart` déclare **deux** `ZManualProbe` supplémentaires,
    `className: 'ZChatMessage'` et `className: 'ZChatConversation'` (littéraux — lus par le gate), avec
    corps de sonde minimal valide, `decode`/`encode`, et **TOUTES** les voies d'écriture publiques de
    `extra` dérivées du disque (`voie: 'ctor'` **et** `voie: 'copyWith'`), chaque writer transmettant
    `extra` **VERBATIM** (règle (k) — un writer auto-sanitisant est le finding MAJEUR-2).
    `eagerlyNormalized: false` pour le **ctor `const`** (c'est l'accesseur qui filtre) et `true` pour
    `copyWith`. `dart run scripts/ci/gate_reserved_keys.dart` **RC=0**.

13. **AC13 — Corpus de rétro-compatibilité déclaré ET fourni.**
    `packages/zcrud_core/dart_test.yaml` est **créé** et déclare le tag `serialization-compat` (même forme
    que `packages/zcrud_firestore/dart_test.yaml`), **et** la story livre au moins un fichier
    `@Tags(['serialization-compat'])` relisant des documents au **schéma antérieur/étranger** :
    document lex authentique (blocs `PascalCase`, `feedback_category: 'off_topic'`,
    `WorkflowEffort: 'detaille'`, sans `version_key`), document tronqué, document à clés inconnues.
    ⚠️ **Déclarer le tag sans corpus rend `melos run verify` ROUGE** (`verify` pose
    `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1`, `melos.yaml:119`) : les deux vont ensemble, dans cette story.

14. **AC14 — Neutralité totale.** Aucun fichier de production existant n'est modifié hors
    `packages/zcrud_core/lib/domain.dart` (ajout d'exports) et
    `tool/reserved_keys_gate/lib/src/manual_probes.dart` (ajout de sondes). Aucun comportement existant ne
    change ; aucun test existant n'est réécrit pour « passer ». Le total de tests de `zcrud_core` est
    **1093 + N** où N est le nombre exact de tests CHAT-0 ajoutés (aucune disparition).

15. **AC15 — Vérif verte.** `dart run melos run analyze` **RC=0** ; depuis `packages/zcrud_core`,
    `flutter test` **RC=0** (jamais `dart test` : faux rouge `dart:ui`) ; `dart run melos run verify`
    **RC=0** repo-wide (inclut `graph_proof`, `gate:reserved-keys`, `verify:serialization`).

---

## Tasks / Subtasks

- [x] **T0 — Lire avant d'écrire** (AC toutes)
  - [x] Lire `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart` **intégralement** : c'est le
        **patron exact** (sealed interne + variant ouvert + registre + helpers défensifs). Ne pas le
        réinventer, le **décalquer**.
  - [x] Lire `packages/zcrud_core/lib/src/domain/extension/z_extensible.dart` (garde `extra`, eager/lazy) et
        `z_extension.dart` (`guard`), `z_open_registry.dart` (`tryCodecFor`), `z_sync_meta.dart:44`.
  - [x] Lire les sources lex (LECTURE SEULE) : `content_block.dart`, `chat_message.dart`,
        `chat_source.dart:19-115`, `chat_enums.dart:1-210`, `response_confidence.dart`,
        `source_freshness.dart`, `chat_thinking_step.dart`, `lexia_suggestion.dart`,
        `chat_attachment.dart`, `chat_conversation.dart`, `chat_quota_snapshot.dart`.

- [x] **T1 — Helpers défensifs internes** (AC1, AC9)
  - [x] Créer `lib/src/domain/chat/z_chat_json.dart` : `_coerceStringMap`, `_asString`, `_asIntOrNull`,
        `_asDoubleOr`, `_asBoolOrNull`, `_asDateOrNull` (via `DateTime.tryParse`), `_asStringList`,
        `_guard`, `_decodeList<T>` (**ignore l'élément illisible, ne perd jamais la liste**).
  - [x] **Ne pas l'exporter** depuis `domain.dart`. Réutiliser `ZExtension.guard`, `zSanitizeExtra`,
        `zNormalizeExtra`, `zJsonEquals`, `zJsonHash` du cœur — ne **rien** en recopier.

- [x] **T2 — Enums** (AC3, AC4)
  - [x] Créer `z_chat_enums.dart` : les 11 enums d'AC3, chacun avec `jsonValue`, `fromJson` défensif et
        alias de lecture documentés.
  - [x] Dartdoc de `ZChatResponseLength` : tableau du faux-ami D2, deux chemins/lignes cités, interdiction
        de fusion. Aucun `label`/`Color`/`iconName`.

- [x] **T3 — Sources** (AC6)
  - [x] Créer `z_chat_source.dart` : classe unique, forme commune, `payload`, dérivés fail-safe,
        `fromJson(raw, {ZSourceRegistry? registry})` / `toJson({registry})`, `==`/`hashCode`.

- [x] **T4 — Value objects** (AC7, AC8)
  - [x] Créer `z_chat_thinking_step.dart`, `z_chat_suggestion.dart`, `z_chat_attachment.dart`,
        `z_chat_response_confidence.dart`, `z_chat_source_freshness.dart`, `z_chat_quota_snapshot.dart`.
  - [x] Porter les règles dérivées **à l'identique** (seuils nommés, fail-safe), renommer
        `pendingAmendments` → `pendingUpdates` (dé-juridicisation), lire l'ancienne clé
        `pending_amendments` en alias.

- [x] **T5 — Blocs de contenu** (AC5, D4, D5)
  - [x] Créer `z_content_block.dart` : `sealed class` + 9 variants + `ZCustomContentBlock`,
        enveloppe `{'type','data'}`, alias PascalCase en lecture, consultation de `ZTypeRegistry`,
        repli payload-verbatim.
  - [x] Dartdoc de la classe : lister explicitement les **3 variantes lex non fermées** (D4) avec la clé
        de registre recommandée (`legalReference`, `flashcards`, `mindmap`) et **pourquoi** — c'est
        l'instruction de portage que lex/IFFD liront.

- [x] **T6 — Entités** (AC9, AC10, AC11)
  - [x] Créer `z_chat_message.dart` et `z_chat_conversation.dart` : `ZEntity` + `ZExtensible`, ctor `const`,
        `fromMap`/`toMap` manuels, `copyWith` à sentinelle, `_reservedKeys` (jeton
        `ZSyncMeta.reservedKeys` littéral), `zSanitizeExtra` eager dans `fromMap`/`copyWith`,
        `zNormalizeExtra` sur l'accesseur `extra`, `==`/`hashCode` avec `zJsonEquals`/`zJsonHash`.
  - [x] `typedef ZChatExtensionParser = ZExtension? Function(Map<String, dynamic> json);`
  - [x] Vérifier ligne à ligne qu'aucune écriture de `updated_at`/`is_deleted` n'existe (D3).

- [x] **T7 — Barrel** (AC1)
  - [x] Ajouter les 11 exports publics à `packages/zcrud_core/lib/domain.dart`, dans une section commentée
        « chat », ordre alphabétique respecté (lint `directives_ordering`).

- [x] **T8 — Harnais du gate** (AC12)
  - [x] Ajouter les deux `ZManualProbe` à `tool/reserved_keys_gate/lib/src/manual_probes.dart` +
        les fonctions writer top-level (`_ctorChatMessage`, `_copyWithChatMessage`, idem conversation),
        `className` **littéral**, `extra` transmis **verbatim**.
  - [x] Lancer `dart run scripts/ci/gate_reserved_keys.dart` et **lire** ses messages : il nomme
        précisément la règle violée (1/2/3/4/(j)/(k)).

- [x] **T9 — Tests R3** (AC toutes)
  - [x] Créer `packages/zcrud_core/test/domain/chat/` : `z_chat_enums_test.dart`,
        `z_content_block_test.dart`, `z_chat_source_test.dart`, `z_chat_value_objects_test.dart`,
        `z_chat_message_test.dart`, `z_chat_conversation_test.dart`,
        `z_chat_naming_guard_test.dart`, et `z_chat_serialization_compat_test.dart`
        (`@Tags(['serialization-compat'])`).
  - [x] Créer `packages/zcrud_core/dart_test.yaml` (tag `serialization-compat`).
  - [x] Exécuter **chaque** injection du plan ci-dessous, consigner rouge→vert dans le Dev Agent Record.

- [x] **T10 — Gates de sortie** (AC15)
  - [x] `dart run melos run analyze` → RC=0.
  - [x] `packages/zcrud_core` → `flutter test` → RC=0, total **1093 + N**.
  - [x] `dart run melos run verify` → RC=0 (repo-wide, au repos).
  - [x] **Ne pas** exécuter `melos run generate` (aucun codegen dans cette story) ; **ne pas** committer
        (commit unique en fin d'epic) ; **ne pas** toucher `sprint-status.yaml`.

---

## Plan de tests détaillé — R3

> Chaque ligne nomme **la régression exacte** qui doit faire rougir la garde. Une garde dont l'injection
> laisse le vert est **rejetée** et doit être réécrite (précédent VIS-1 : première injection I2 non
> mordante — le défaut était dans la garde, pas dans le code).

| Garde | Fichier | Assertion verte | Régression à ré-injecter → rouge attendu |
|---|---|---|---|
| **G1 — round-trip par type** | tous les `*_test.dart` chat | Pour **chaque** type et **chaque** variante de bloc : `X.fromJson(x.toJson()) == x`, égalité structurelle | Retirer un champ du `toJson` d'un type (p. ex. `snippet` de `ZChatSource`, `description` de `ZTimelineEvent`) : l'égalité rougit. **Répéter par type** — un round-trip prouvé sur un seul type ne prouve rien pour les autres. |
| **G2 — round-trip des 10 kinds de blocs** | `z_content_block_test.dart` | Test **paramétré** sur les 9 kinds fermés **+** `ZCustomContentBlock` : `fromJson(toJson())` identique, `kind` conservé | Supprimer une branche du `switch` de `fromJson` : le kind retiré tombe en `ZCustomContentBlock` ⇒ type attendu rouge. |
| **G3 — enum inconnu ⇒ repli, jamais throw** | `z_chat_enums_test.dart` | `role: 'wizard'` → `ZChatRole.unknown` ; `feedback_category: 'zzz'` → `null` ; `freshness: 'zzz'` → `unknown` ; aucun `throw` | Remplacer le `switch` défensif par `values.byName(raw)` : `ArgumentError` ⇒ rouge. |
| **G4 — alias de lecture lex** | `z_chat_enums_test.dart` | `'concis'`→`concise`, `'detaille'`→`detailed`, `'off_topic'`→`offTopic`, `'as_is'`→`asIs`, `'general_knowledge'`→`generalKnowledge` | Retirer une branche d'alias : le document lex se relit en repli au lieu de la bonne valeur ⇒ rouge. |
| **G5 — alias PascalCase des blocs** | `z_content_block_test.dart` | Un document lex `{'type':'KeyDefinition','data':{…}}` produit un `ZKeyDefinitionBlock` typé | Retirer la table d'alias : le bloc devient `ZCustomContentBlock` ⇒ rouge sur le type. |
| **G6 — bloc de type inconnu : payload PRÉSERVÉ** | `z_content_block_test.dart` | `{'type':'Quantum','data':{'a':1,'b':{'c':2}}}` → `ZCustomContentBlock('Quantum', …)` **et** `toJson()` rend la map d'origine **à l'identique** | Réintroduire le comportement de lex `_ => ZTextBlock(text: json.toString())` : le type ET le round-trip rougissent tous deux. |
| **G7 — extension par registre** | `z_content_block_test.dart` | Un `ZTypeRegistry` où `'legalReference'` est enregistré décode/réencode le bloc par le codec de l'app ; **sans** registre le même document retombe sur `ZCustomContentBlock` payload intact | Ignorer le registre (`tryCodecFor` jamais appelé) : le codec de l'app n'est plus observé ⇒ rouge. Second cas : faire **lever** le codec de l'app ⇒ doit être absorbé (repli payload), pas propagé. |
| **G8 — `ZSourceRegistry` réutilisé, pas doublé** | `z_chat_source_test.dart` | Un `source_type` enregistré dans un `ZSourceRegistry` est reconstruit par son codec ; un `source_type` inconnu conserve son payload | Instancier un registre neuf à l'intérieur de `fromJson` au lieu d'utiliser celui injecté : le codec de l'app n'est plus vu ⇒ rouge. |
| **G9 — fail-safe `isVerified`/`level`** | `z_chat_source_test.dart`, `z_chat_value_objects_test.dart` | `verified: true` **sans** `verification_status` ⇒ `isVerified == false` ; aucun signal ⇒ `level == toVerify` ; guard `degraded` ⇒ `toVerify` même avec de bons scores | Remplacer `verificationStatus == 'verified'` par `verified == true` ; ou retirer la dégradation dure : un cas non ancré devient « vérifié »/`high` ⇒ rouge. **C'est la garde anti-sur-affirmation : elle doit exister pour chaque repli.** |
| **G10 — élément de liste illisible ignoré, liste préservée** | `z_chat_message_test.dart` | `content_blocks: [validBlock, 42, null, validBlock2]` ⇒ 2 blocs décodés, aucun throw ; idem `sources`, `thinking`, `suggestions`, `attachments` | Remplacer `_decodeList` par un `map(...).toList()` direct : `TypeError` ⇒ rouge. |
| **G11 — `created_at` absent/corrompu : le parent survit** | `z_chat_message_test.dart` | Map **sans** `created_at`, puis `created_at: 'pas-une-date'`, puis `created_at: 42` ⇒ message décodé, `createdAt == null`, `toMap()` n'émet pas la clé | Remettre le code de lex `DateTime.parse(json['created_at'] as String)` (`chat_message.dart:157`) ⇒ `FormatException`/`TypeError` ⇒ rouge. |
| **G12 — 🔴 aucune clé de sync émise** | `z_chat_conversation_test.dart` | `toMap()` d'une conversation **et** d'un message ne contient **ni** `updated_at` **ni** `is_deleted`, y compris quand ces clés étaient dans la map source | Renommer `last_message_at` en `updated_at` (le choix de lex) : la garde rougit. Second cas : retirer `zSanitizeExtra` de `fromMap` ⇒ la clé du store entre par `extra` et ressort par l'étalement ⇒ rouge. |
| **G13 — `extra` : round-trip exact, étanche, non modifiable** | `z_chat_message_test.dart` | Clés inconnues (y compris **JSON imbriqué**) préservées à l'identique ; `extra` ne porte **jamais** une clé réservée quelle que soit la voie (**ctor `const`**, `copyWith`, `fromMap`) ; `Map` non modifiable ; `a == b` et `Set{a,b}.length == 1` sur deux décodages du même payload imbriqué | (a) Retirer `zNormalizeExtra` de l'accesseur ⇒ la voie **ctor** laisse passer `is_deleted` ⇒ rouge ; (b) retirer `zSanitizeExtra` de `copyWith` ⇒ rouge ; (c) remplacer `zJsonEquals` par `==` natif ⇒ l'égalité sur JSON imbriqué rougit (`Set.length == 2`). **Les trois injections sont distinctes et toutes obligatoires** — c'est le défaut mesuré sur 8 entités sur 9 en ES-2.2b. |
| **G14 — slot `extension` défensif** | `z_chat_message_test.dart` | Parser injecté qui **lève** ⇒ `extension == null`, message décodé ; parser absent ⇒ `null` ; extension valide ⇒ typée et réémise | Retirer `ZExtension.guard` autour de l'appel au parser ⇒ l'exception remonte ⇒ rouge. |
| **G15 — rétro-compat / document étranger** | `z_chat_serialization_compat_test.dart` (`@Tags(['serialization-compat'])`) | Un document **lex authentique** (blocs PascalCase, `off_topic`, sans `version_key`, sans `extension`) se relit complet ; un document **tronqué** (`{}`) donne une entité valide ; un document **futur** (clés inconnues) est relu **et** ses clés inconnues survivent au round-trip | Rendre un champ `required` non nullable / retirer un défaut sûr : le document tronqué lève ⇒ rouge. Retirer l'étalement d'`extra` du `toMap` : les clés du document futur disparaissent ⇒ rouge. |
| **G16 — faux-ami interdit (grep négatif prouvé)** | `z_chat_naming_guard_test.dart` | Scan des sources de `packages/*/lib` : **0** occurrence de `WorkflowEffort` ; la dartdoc de `ZChatResponseLength` cite les deux fichiers d'origine | Déclarer `enum WorkflowEffort { low, medium, high }` dans un fichier chat : le scan rougit. **Une « absence » non prouvée par un grep négatif n'est pas une preuve** (lentille « réalité du code »). |
| **G17 — pureté & neutralité** | `test/purity/domain_purity_test.dart` (existant) + garde source | `lib/src/domain/chat/**` : 0 import Flutter/`dart:ui`/backend, 0 `Color(0x`, 0 `Colors.`, 0 `part '`, 0 `@JsonSerializable`, `pubspec.yaml` inchangé | Ajouter `import 'package:flutter/foundation.dart';` dans un fichier chat ⇒ le test de pureté existant rougit (vérifier qu'il **couvre bien** le nouveau sous-dossier — sinon c'est le test qu'il faut corriger, pas contourner). |
| **G18 — le gate voit les nouvelles entités** | `dart run scripts/ci/gate_reserved_keys.dart` | RC=0 avec les deux sondes câblées | Retirer `ZChatMessage` de `kManualProbes` ⇒ règle (3) `E_disk \ E_covered ≠ ∅` ⇒ gate **ROUGE**. Retirer la voie `'ctor'` d'un writer ⇒ règle (j) ⇒ **ROUGE**. **Prouver les deux** : c'est ce qui démontre que le câblage AC12 est porteur et non décoratif. |

**Qualifier chaque rouge** : compilation · infrastructure · **vraie assertion**. Un rouge de compilation ne
prouve rien sur la garde. Une injection non réellement appliquée sur disque ⇒ **aucune preuve**.

---

## Dev Notes

### Fichiers et état actuel VÉRIFIÉS sur disque (zcrud — modifiable)

- `packages/zcrud_core/pubspec.yaml` — deps runtime : `dartz`, `flutter` (SDK), `form_builder_validators`.
  **Aucun** `json_annotation`/`build_runner`/`zcrud_*`. `find lib -name '*.g.dart'` → **0**. ⇒ D1.
- `packages/zcrud_core/lib/domain.dart` — point d'entrée **pur-Dart** (Flutter-free), ré-exporté par le
  barrel principal (`zcrud_core.dart:14 export 'domain.dart';`). C'est **là** que vont les exports chat.
- `packages/zcrud_core/lib/src/domain/registry/z_open_registry.dart:53-85` — `ZOpenRegistry` :
  `register(kind, {fromJson, toJson})`, `isRegistered`, `kinds`, `codecFor` (**strict → throw**),
  `tryCodecFor` (**défensif → null**). 🔴 **Le chat utilise `tryCodecFor`, jamais `codecFor`** (AD-10).
- `z_source_registry.dart:23-26` / `z_type_registry.dart:21-24` — deux **espaces de noms distincts**,
  instanciables, injectés. **Réutiliser, ne rien créer.**
- `z_extension.dart:25-51` — `ZExtension` (`formatVersion`, `toJson`, `static guard<T>`).
- `z_extensible.dart:18-34` (mixin), `:77-84` (`zSanitizeExtra`, eager), `:122-130` (`zNormalizeExtra`,
  lazy sur l'accesseur, **zéro copie** quand le slot est déjà propre). Le long dartdoc `:36-121` explique
  **pourquoi** les deux existent — le lire avant de câbler AC11.
- `z_json_equality.dart` — `zJsonEquals`/`zJsonHash`, **implémentation UNIQUE du repo** pour le slot
  `extra`. Les recopier serait un finding (DW-ES22-4).
- `z_sync_meta.dart:44` — `static const Set<String> reservedKeys = {kUpdatedAt, kIsDeleted};`.
- `packages/zcrud_core/lib/src/domain/contracts/z_entity.dart:19-31` — `ZEntity` : `id` **nullable**
  (éphémère), `isEphemeral`, **aucune** sérialisation sur la base (AD-4).
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart` — **LE PATRON** (voir T0).
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:60-62,104-120` — patron
  `ZXxxExtensionParser` + `fromMap(map, {sourceRegistry, extensionParser})` + câblage manuel des canaux
  hors-codegen.
- `tool/reserved_keys_gate/lib/src/manual_probes.dart:26-101` — `ZManualProbe` (`className` **littéral**,
  `body`, `decode`, `encode`, `writes`) et les deux sondes `ZMindmap`/`ZMindmapNode` à imiter.
- `tool/reserved_keys_gate/lib/src/registrars.dart:400-457` — `ZExtraWriter` (`voie` littérale,
  `write` **verbatim**, `eagerlyNormalized`) : lire le dartdoc, il explique pourquoi le harnais ne
  choisit **plus** la voie la plus sûre.
- `scripts/ci/gate_reserved_keys.dart:61-90,150-176` — volets (A)/(B), règles de couverture (1)(2)(3)(4),
  allowlist syntaxique (n'y **rien** ajouter).
- `melos.yaml:104-119` — `verify` = `graph_proof` + gates + `gate_reserved_keys` +
  `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1 verify_serialization`.
- `packages/zcrud_firestore/dart_test.yaml` — forme exacte du `dart_test.yaml` à créer (AC13).
- `packages/zcrud_core/test/purity/domain_purity_test.dart:1-45` — la garde de pureté couvre
  `lib/src/domain/**` : vérifier explicitement qu'elle balaie bien le nouveau sous-dossier `chat/`.

### Sources lex (LECTURE SEULE — `/home/zakarius/DEV/lex_douane`)

| Fichier | Ce qu'on en prend | Ce qu'on n'en prend pas |
|---|---|---|
| `packages/lex_core/lib/domain/entities/content_block.dart` | enveloppe `{type,data}`, 9 variantes, forme des champs | `_ => TextBlock(json.toString())` (D5), `Flashcards`/`Mindmap`/`LegalReference` (D4) |
| `.../chat_message.dart` | tous les champs, `content` getter, `copyWith` à sentinelle, lecture défensive | `DateTime.parse` levant (D6), `freshnessForSource` (switch sur les sous-types douaniers) |
| `.../chat_source.dart:19-115` | la **forme commune** (10 champs), `isVerified`, `usageStatus` fail-safe | les **14 sous-types** douaniers (`CodeDesDouanesSource`, `TecSource`, `ShSource`…) → `ZSourceRegistry` |
| `.../chat_conversation.dart` | titre, compteur, épinglage | `updated_at` en corps de document (D3) |
| `.../chat_thinking_step.dart`, `lexia_suggestion.dart`, `chat_attachment.dart` | tels quels (renommés `Z*`) | leur `@JsonSerializable` (D1) |
| `.../response_confidence.dart` | métriques, seuils nommés, règle `level` fail-safe, facteurs explicables | rien — les libellés sont déjà externalisés côté UI chez lex, on garde ce choix |
| `.../source_freshness.dart` | statut + règle `isPotentiallyOutdated` | le nom `pendingAmendments` (juridique) → `pendingUpdates` |
| `.../chat_quota_snapshot.dart` | forme rate-limit générique | le vocabulaire d'abonnement (`SubscriptionTier`, packs CEDEAO) |
| `domain/enums/chat_enums.dart` | les 7 enums retenus | `label`/`colorValue`/`iconName` (présentation), `ShNodeType`/`SubscriptionTier`/`AlertLevel` (hors périmètre) |
| `domain/enums/chat_persona.dart` | **rien** | valeurs douanières (`declarant`, `transitaire`, `agentDouanes`) — hors périmètre C0 |

### Ce qui est ÉCARTÉ, et pourquoi (à ne pas « rattraper » en cours de dev)

- **`LegalReference`** — juridique (`articles[]`). App-side via `ZTypeRegistry`.
- **`Flashcards` / `Mindmap` blocks** — porteraient `zcrud_flashcard`/`zcrud_mindmap` dans le cœur ⇒
  **AD-1**. App/satellite-side via `ZTypeRegistry`.
- **Les 14 sous-types de `ChatSource`** — vocabulaire douanier. `ZSourceRegistry`.
- **`ChatPersona` / `ChatOnboardingProfile` / `UserKnowledgeLevel`** — le *concept* est générique, les
  *valeurs* de lex sont douanières, et `UserKnowledgeLevel` mélange un persona (`etudiant`) et un niveau :
  reprendre la forme importerait le défaut. **Hors périmètre C0** (profil utilisateur ≠ modèle de
  conversation) ; candidat **additif** ultérieur avec une clé de persona **opaque**.
- **Tokens / coût par message** — 🔴 **vérifié absent des DEUX dépôts** : `iffd-modele-ia.md §3`
  (grep négatif sur `tokenCount|inputTokens|outputTokens|cost|usageMetadata|promptTokens` → 0) et lex
  n'a **rien** au niveau message (seulement `ChatQuotaSnapshot`, un quota de tier). ⇒ CHAT-0
  **n'invente pas** de `ZChatUsage` ; le besoin passe par `extra`/`ZExtension` et pourra être ajouté
  **additivement**. Le dire est plus utile que le fabriquer.
- **Scoping IFFD** (`folderId`/`subFolderId`/`documentId`, `isChatSession`, `conversationSummary`) —
  spécificité d'hôte ⇒ `extra`/`ZExtension`.
- **TTS, hors-ligne, export, pièces jointes (contrôleur), `ChatStreamEvent`, repository** — autres lots.
  ⚠️ L'embedding hors-ligne de lex est un **STUB** : ne jamais le présenter comme une capacité prouvée.

### Contraintes d'architecture non négociables (rappel opérationnel)

- **AD-1** : `zcrud_core` = puits du graphe. Aucun `zcrud_*`, aucun Firebase/Syncfusion/Quill/Maps, aucun
  gestionnaire d'état. `pubspec.yaml` **intouché**.
- **AD-3** : `freezed` non imposé, `reflectable` banni ; enums en **camelCase** en persistance ;
  clés persistées en **snake_case**.
- **AD-4** : extension par **registre** (`ZTypeRegistry`/`ZSourceRegistry`) et par **slots**
  (`ZExtension?` versionné + `extra`) — **jamais** par héritage d'une classe sérialisée, jamais par
  generic de sérialisation.
- **AD-5/AD-11** : aucun contrat de repository dans cette story ; quand ils viendront (CHAT-1), ce sera
  `Either<ZFailure, T>` / `Stream` nus. **Aucun type Firestore/Hive** ne doit apparaître, même en dartdoc.
- **AD-10** : évolution **additive seulement** ; aucun `throw` sur un chemin de désérialisation ;
  champ absent/corrompu ⇒ repli.
- **AD-13/FR-26** : aucun libellé d'affichage, aucune couleur, aucune icône dans le domaine.
- **AD-16/AD-19** : `updated_at`/`is_deleted` appartiennent à `ZSyncMeta`, **hors entité**.

### Structure de projet

**Production — NEW** (`packages/zcrud_core/lib/src/domain/chat/`) :
`z_chat_json.dart` (interne, non exporté) · `z_chat_enums.dart` · `z_content_block.dart` ·
`z_chat_source.dart` · `z_chat_thinking_step.dart` · `z_chat_suggestion.dart` · `z_chat_attachment.dart` ·
`z_chat_response_confidence.dart` · `z_chat_source_freshness.dart` · `z_chat_quota_snapshot.dart` ·
`z_chat_message.dart` · `z_chat_conversation.dart`

**Production — UPDATE :**
- `packages/zcrud_core/lib/domain.dart` (exports)
- `tool/reserved_keys_gate/lib/src/manual_probes.dart` (2 sondes + writers)

**Config — NEW :** `packages/zcrud_core/dart_test.yaml`

**Tests — NEW :** `packages/zcrud_core/test/domain/chat/*_test.dart` (voir T9).

🚫 **Aucun autre fichier.** Ni `pubspec.yaml`, ni `sprint-status.yaml`, ni `melos.yaml`, ni un fichier
d'IFFD/lex (lecture seule), ni un `*.g.dart`.

### Pièges déjà payés par ce dépôt — à ne pas repayer

1. **Un test peut certifier une erreur** (VIS-1) : deux défauts de `zcrud_core` avaient une suite
   **verte parce qu'**elle encodait le défaut. Écrire l'assertion à partir de l'**invariant**, pas à partir
   de ce que le code fait.
2. **Une injection non appliquée ⇒ aucune preuve** (VIS-1 : 10 gardes sur 11 non injectées par l'agent).
3. **La voie la plus sûre masque la voie dangereuse** (ES-2.2b : 6 entités sur 9 portaient des clés de
   store dans `extra` **en mémoire** parce que seul `copyWith` était sondé). ⇒ G13 exige les **trois**
   voies.
4. **`melos analyze` par package ne voit pas une régression cross-package** — la vérif finale est
   **repo-wide**.
5. **`dart test` dans `zcrud_core` donne un faux rouge `dart:ui`** — toujours `flutter test`.

### Références

- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml:560-583] — décision RÉVISÉE, pièges vérifiés, cadence (code-review unique en fin d'epic).
- [Source: docs/plan-portage-assistant-ia.md:63-113,120-165] — architecture, lots, risques, gardes R3 attendues.
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md] — AD-1, AD-3, AD-4, AD-5, AD-10, AD-11, AD-13, AD-16.
- [Source: packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart] — patron sealed+registre+défensif à décalquer.
- [Source: packages/zcrud_core/lib/src/domain/extension/z_extensible.dart:36-130] — pourquoi eager **et** lazy, et le dommage mesuré si l'une manque.
- [Source: packages/zcrud_core/lib/src/domain/registry/z_open_registry.dart:53-85] — `tryCodecFor` vs `codecFor`.
- [Source: packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart:44] — clés réservées.
- [Source: scripts/ci/gate_reserved_keys.dart:61-90] — règles (3)/(B)/(j)/(k) qui rendront `verify` rouge sans AC12.
- [Source: tool/reserved_keys_gate/lib/src/manual_probes.dart:1-101] — forme exacte des sondes à ajouter.
- [Source: melos.yaml:104-119] — contenu réel de `verify`.
- [Source: /home/zakarius/DEV/lex_douane/packages/lex_core/lib/domain/entities/content_block.dart:13-66] — LECTURE SEULE, enveloppe + 12 variantes + repli destructeur à corriger.
- [Source: /home/zakarius/DEV/lex_douane/packages/lex_core/lib/domain/entities/chat_message.dart:11,50-70,91-241] — LECTURE SEULE, champs, sentinelle, `DateTime.parse` levant.
- [Source: /home/zakarius/DEV/lex_douane/packages/lex_core/lib/domain/entities/chat_source.dart:19-115] — LECTURE SEULE, forme commune + fail-safe.
- [Source: /home/zakarius/DEV/lex_douane/packages/lex_core/lib/domain/enums/chat_enums.dart:20-62] — LECTURE SEULE, `WorkflowEffort` = LONGUEUR.
- [Source: /home/zakarius/DEV/iffd/lib/src/presentation/.../ai_routers_page.dart:24-28] — LECTURE SEULE, `WorkflowEffort` = EFFORT DE CALCUL (le faux-ami).
- [Source: /tmp/zcrud-explore/lex-ia-domaine.md, SYNTHESE-LEX-IA.md, iffd-modele-ia.md, zcrud-invariants.md] — rapports d'exploration.
- [Source: _bmad-output/implementation-artifacts/stories/vis-1-tokens-look-couture-degrade.md] — structure de story, discipline R3, précédents mesurés.

## Dev Agent Record

### Agent Model Used

`claude-opus-5[1m]` (skill `bmad-dev-story`, exécution unique).

### Debug Log References

#### Vérif verte — RC RÉELLEMENT observés sur disque

| Commande | RC | Détail |
|---|---|---|
| `dart run melos run analyze` (repo-wide) | **0** | packages + scripts + example ; **0 erreur** introduite (les `info` restants sont pré-existants et étrangers à CHAT-0) |
| `packages/zcrud_core` → `flutter test` | **0** | **1244 tests** — baseline **1093** + **151** ajoutés par CHAT-0 (aucune disparition) |
| `dart run melos run verify` (repo-wide) | **0** | inclut `graph_proof` (**ACYCLIQUE OK**, **CORE OUT=0 OK**), `gate:reserved-keys` (**OK — volets (A)+(B)+couverture**), `verify:serialization` (**corpus `serialization-compat` vert**, `zcrud_core` désormais dans la population redevable, runner `flutter`) |
| `dart run scripts/ci/gate_reserved_keys.dart` (isolé) | **0** | AC12 : les deux sondes manuelles sont vues et exercées |

⚠️ `melos run generate` **non exécuté** (aucun codegen dans cette story — D1). Aucun commit (commit unique en fin d'epic). `sprint-status.yaml` **non touché** par le dev.

#### Injections R3 — 25 régressions, toutes appliquées SUR DISQUE, toutes MORDANTES

Protocole : injection par script (`inject.py`), **restauration depuis une copie explicite** (`cp -r`) — **jamais** `git checkout`. Le script sort en RC=2 si le motif est introuvable : **aucune injection n'a été « non appliquée »**. Vert reconfirmé après chaque restauration (`VERT_APRES_RESTAURATION_RC=0`, 25/25).

| Garde | Régression réellement appliquée (fichier) | Rouge observé | Nature |
|---|---|---|---|
| **G1** | retrait de `if (snippet != null) 'snippet': snippet` de `ZChatSource.toJson` (`z_chat_source.dart`) | RC=1 — `Expected: ZChatSource:<…> Actual: ZChatSource:<…>` (round-trip inégal) | **assertion** |
| **G2** | suppression de la branche `case 'mermaidDiagram'` du `switch` de `ZContentBlock.fromJson` | RC=1 — `Expected: Type:<ZMermaidDiagramBlock> Actual: Type:<ZCustomContentBlock>` | **assertion** |
| **G3** | `switch` défensif de `ZChatRole.fromJson` remplacé par `values.byName(raw as String)` | RC=1 — `Expected: return normally` (le parse LÈVE) | **assertion** |
| **G4** | retrait de l'alias `case 'detaille'` | RC=1 — `Expected: detailed Actual: standard` (repli au lieu de la bonne valeur) | **assertion** |
| **G5** | retrait de `'KeyDefinition': 'keyDefinition'` de la table d'alias PascalCase | RC=1 — `Expected: <ZKeyDefinitionBlock> Actual: ZCustomContentBlock(kind: KeyDefinition)` | **assertion** |
| **G6** | réintroduction du repli **destructeur de lex** : `_ => ZTextBlock(text: envelope.toString())` | RC=1 — `Expected: <ZCustomContentBlock> Actual: <ZTextBlock>` **et** round-trip perdu | **assertion** |
| **G7** | branche `default` privée de `typeRegistry?.tryCodecFor` (registre ignoré) | RC=1 — `Expected: true Actual: <null>` (codec de l'app plus observé) | **assertion** |
| **G8** | `ZChatSource.fromJson` instancie un `ZSourceRegistry()` **neuf** au lieu du registre injecté | RC=1 — `Expected: true Actual: <null>` | **assertion** |
| **G9** | `isVerified` : `verificationStatus == 'verified'` → `verified == true` | RC=1 — `Expected: false Actual: <true>` (source non ancrée dite vérifiée) | **assertion** |
| **G9b** | retrait de la dégradation dure « guard `degraded`/`all_rejected`/`error` » de `level` | RC=1 — `Expected: toVerify Actual: moderate` | **assertion** |
| **G10** | `zJsonDecodeList` remplacé par `.map((e) => …(e as Map…)!).toList()` sur `content_blocks` | RC=1 — **2 tests `[E]`** (exception non rattrapée : `TypeError` sur l'élément `42`) | **assertion (exception non rattrapée en test)** |
| **G11** | retour au code de lex : `DateTime.parse(map['created_at'] as String)` | RC=1 — `Expected: return normally` (le message entier est détruit) | **assertion** |
| **G12** | `kZChatLastMessageAtKey` : `'last_message_at'` → `'updated_at'` (le choix de lex) | RC=1 — `Expected: false Actual: <true>` + `collidingReservedKeys` non vide | **assertion** |
| **G12b** | retrait de `zSanitizeExtra` de `ZChatConversation.fromMap` | RC=1 sur la suite ; **et gate ROUGE** : `(i.3b) fromMap ne NORMALISE PLUS extra à l'ENTRÉE` | **assertion** |
| **G13a** | accesseur `extra` de `ZChatMessage` : `zNormalizeExtra(_extra, …)` → `_extra` | RC=1 — la voie **ctor `const`** laisse passer `is_deleted` | **assertion** |
| **G13b** | retrait de `zSanitizeExtra` de `ZChatMessage.copyWith` | RC=1 — `Expected: true Actual: <false>` (lecture non zéro-copie) | **assertion** |
| **G13c** | `zJsonEquals(extra, other.extra)` → `extra == other.extra` (`==` natif) | RC=1 — deux décodages du même JSON **imbriqué** dits différents | **assertion** |
| **G14** | `zDecodeExtension(...)` remplacé par un appel **nu** au parser injecté | RC=1 — `Expected: not null Actual: <null>` + `Expected: return normally` | **assertion** |
| **G15a** | `zJsonInt(map['message_count'], 0)` → `map['message_count'] as int` (défaut sûr retiré) | RC=1 — le document **tronqué** `{}` lève | **assertion** |
| **G15b** | retrait de l'étalement `...extra` du `toMap()` de `ZChatMessage` | RC=1 — `Expected: 'detaille' Actual: <null>` (document **futur** amputé) | **assertion** |
| **G16** | déclaration de `enum WorkflowEffort { low, medium, high }` dans un fichier chat | RC=1 — grep négatif : `Expected: empty` | **assertion** |
| **G17** | `import 'package:flutter/foundation.dart';` dans `z_chat_enums.dart` | RC=1 — 🔴 **le test de pureté EXISTANT** `test/purity/domain_purity_test.dart` › *« aucun import interdit sous lib/src/domain (AC1) »* rougit ⇒ **il couvre bien le nouveau sous-dossier `chat/`** (vérifié isolément) | **assertion** |
| **GJ** | `zJsonDate` : `DateTime.tryParse` → `DateTime.parse` (surface JSON **partagée**) | RC=1 — `Expected: return normally` | **assertion** |
| **G18a** | `className: 'ZChatMessage'` retiré de `kManualProbes` | RC=1 — règle **(3)** : *« `ZChatMessage` est `ZExtensible` … ni enregistrée ni sondée … faux vert par omission »* | **assertion (gate)** |
| **G18b** | voie `'ctor'` retirée des `writes` de la sonde `ZChatMessage` | RC=1 — règle **(j)** : *« VOIE D'ÉCRITURE NON SONDÉE : `ZChatMessage.ctor` prend un paramètre `extra` … pas câblée »* | **assertion (gate)** |

🟢 **Aucun rouge de COMPILATION** n'a été compté comme preuve : les 25 injections compilent et échouent sur une **assertion réelle** (ou, pour G10, sur une exception non rattrapée *par le code de production*, ce que la garde existe précisément pour empêcher). **Aucune panne d'infrastructure** (`Disk quota exceeded` ou autre) n'est survenue.

🟡 **Honnêteté sur G12b** : sur la *conversation*, retirer `zSanitizeExtra` de `fromMap` ne laisse **pas** ressortir les clés de sync (l'**accesseur** `zNormalizeExtra` les rattrape) — c'est voulu par la conception ES-2.2b. La régression est donc attrapée par (a) le test « `extra` non modifiable » et surtout (b) l'assertion **(i.3b)** du gate, qui a été **vérifiée rouge séparément**. C'est la machine qui porte cette garde, pas la suite du package : le dire évite de croire la suite plus discriminante qu'elle n'est.

### Completion Notes List

#### ⓪ 🔴 Décision owner EN COURS DE STORY — les primitives JSON ne sont PAS un helper du chat

La story prévoyait `lib/src/domain/chat/z_chat_json.dart`, **interne et non exporté** (T1/AC1). L'owner a tranché en cours d'implémentation : **le chat n'est pas le seul module à en avoir besoin**. Ces primitives sont donc devenues une **surface PARTAGÉE du cœur** :

- **`packages/zcrud_core/lib/src/domain/json/z_json_read.dart`** — 14 primitives publiques (`zJsonMap`, `zJsonString(OrNull)`, `zJsonInt(OrNull)`, `zJsonDouble(OrNull)`, `zJsonBool(OrNull)`, `zJsonDate`, `zJsonStringList`, `zJsonGuard`, `zJsonDecodeList`, `zListEquals`, `zListHash`), **exportées** depuis `lib/domain.dart`.
- C'est le **pendant, pour la LECTURE**, de ce que `zJsonEquals`/`zJsonHash` sont pour l'**ÉGALITÉ** — et le remède à la **même classe de défaut que DW-ES22-4** : six `_mapEquals` jumeaux dans trois packages, qu'aucune machine n'obligeait à rester cohérents. Le dépôt reconstruisait déjà `_coerceStringMap`/`_asString`/`_guard` à l'identique dans `ZFlashcardSource`, `AppFile`, `ZMindmap` et le chat.
- **Écart assumé à AC1** : « le fichier de helpers internes n'est **pas** exporté » est **caduc** — il n'y a plus de helpers *internes au chat*. La garde correspondante a été **réécrite, pas supprimée** : `z_chat_naming_guard_test.dart` asserte désormais (a) que `json/z_json_read.dart` **est** exporté, (b) qu'un `chat/z_chat_json.dart` **n'existe pas** — la duplication que cette décision existe pour empêcher redeviendrait rouge.
- Couverture propre : **`test/domain/json/z_json_read_test.dart`** (26 tests), dont la garde d'invariant « **aucune de ces 14 fonctions ne lève, sur aucune des 8 valeurs hostiles** », prouvée mordante par l'injection **GJ**.
- 🟡 **Dette ouverte (à traiter hors CHAT-0)** : les entités **existantes** (`ZFlashcardSource`, `AppFile`, `ZMindmap`, `ZDocumentReadingState`…) portent encore leurs copies privées. Les migrer vers cette surface unique est un **refactor transverse multi-packages**, hors périmètre d'une story qui ne doit toucher que `zcrud_core` — à inscrire au registre des dettes (**proposition : `DW-CHAT0-1`**) et à planifier. Tant qu'il reste des copies, la garde de non-duplication ne couvre que le chat.

#### ① Types REPRIS de lex — et pourquoi chacun est générique

| Type zcrud | Origine lex | Généricité |
|---|---|---|
| `ZContentBlock` + enveloppe `{type,data}` | `content_block.dart:10-66` | tout assistant structuré produit des blocs typés ; l'enveloppe est un discriminant neutre |
| `ZTextBlock`, `ZTableBlock` | `TextBlock`, `TableBlock` | universels |
| `ZKeyDefinitionBlock`, `ZComparisonTableBlock` (+ `ZComparisonColumn`), `ZTimelineBlock` (+ `ZTimelineEvent`) | idem lex | **pédagogiques génériques** (terme/définition, comparaison, frise) — le cœur de cible éducatif de DODLP/IFFD |
| `ZAlertBlock` | `AlertBlock` | encadré générique ; `level` reste une **`String` ouverte** — lex ne la ferme pas non plus |
| `ZMermaidDiagramBlock` | `MermaidDiagramBlock` | `{title?, code}` : deux chaînes, **zéro dépendance** ; le rendu est app-side |
| `ZSourcesBlock`, `ZSuggestionsBlock` | idem lex | provenance et relances = besoins de tout assistant sourcé (IFFD a l'équivalent dégradé `List<String>`) |
| `ZChatSource` | `chat_source.dart:18-89` — **forme commune** | 10 champs neutres + `payload` ; **`isVerified`/`usageStatus` fail-safe portés à l'identique** |
| `ZChatThinkingStep`, `ZChatAttachment`, `ZChatSuggestion` (+ `ZChatSuggestionAction`) | `chat_thinking_step.dart`, `chat_attachment.dart`, `lexia_suggestion.dart` | value objects sans vocabulaire métier |
| `ZChatResponseConfidence` (+ `ZChatConfidenceFactor`, `ZChatConfidenceThresholds`) | `response_confidence.dart:40-293` | métriques de grounding + **règle `level` déterministe et explicable**, seuils **nommés** |
| `ZChatSourceFreshness` | `source_freshness.dart:38-117` | fraîcheur d'un dataset + règle `isPotentiallyOutdated` fail-safe |
| `ZChatQuotaSnapshot` | `chat_quota_snapshot.dart:8-87` | rate-limit générique (le vocabulaire d'abonnement est écarté) |
| `ZChatMessage`, `ZChatConversation` | `chat_message.dart`, `chat_conversation.dart` | entités canoniques + slots AD-4 |
| 11 enums (`ZChatRole`, `ZChatResponseLength`, `ZChatLengthBias`, `ZChatFeedbackRating`, `ZChatFeedbackCategory`, `ZChatSuggestionType`, `ZChatSuggestionActionType`, `ZChatSourceUsageStatus`, `ZChatDatasetFreshness`, `ZChatConfidenceLevel`, `ZChatConfidenceFactorSense`) | `chat_enums.dart`, `response_confidence.dart`, `source_freshness.dart`, `chat_source.dart` | **sans** `label`/`colorValue`/`iconName` (présentation → app-side) |

**Trois corrections apportées à lex, assumées** (reprendre sa forme ≠ reprendre ses bugs) :
1. **repli destructeur** `_ => TextBlock(json.toString())` → `ZCustomContentBlock(kind, payload)` **verbatim** (D5/G6) ;
2. **`DateTime.parse` levant** → `DateTime?` + `tryParse` (D6/G11) ;
3. **`updated_at` en corps de document** → `lastMessageAt` / `last_message_at` (D3/G12).
Deux **améliorations** : `role` inconnu reste `unknown` (lex coerce tout en `user`, `chat_message.dart:92-93`) ; `type`/`actionType` sont **bruts ET typés** (lex perd l'un ou l'autre).

#### ② Types ÉCARTÉS — et pourquoi

- **`LegalReferenceBlock`** — `articles[]` est **juridique**, trop douanier pour un socle éducatif ⇒ `ZTypeRegistry.register('legalReference', …)`.
- **`FlashcardBlock` / `MindmapBlock`** — porteraient `zcrud_flashcard`/`zcrud_mindmap` dans le cœur ⇒ **AD-1 ROUGE** ⇒ registre (`'flashcards'`, `'mindmap'`). **Prouvé non décoratif** : sans registre, ces trois capacités seraient inatteignables ; avec, elles le sont (garde G7).
- **Les 14 sous-types douaniers de `ChatSource`** ⇒ `ZSourceRegistry` (garde G8) ; leurs champs propres survivent dans `payload` même **sans** codec.
- **`WorkflowEffort`** — faux-ami : **interdit** par grep négatif (G16). Le concept IFFD (effort de calcul) est réservé à `ZChatComputeEffort` (CHAT-1).
- **`label`/`colorValue`/`iconName`** des enums — présentation (AD-13/FR-26).
- **`ChatPersona`/`ChatOnboardingProfile`/`UserKnowledgeLevel`** — valeurs douanières ; `UserKnowledgeLevel` mélange persona et niveau : reprendre la forme importerait le défaut. Hors périmètre C0.
- **Tokens / coût par message** — 🔴 **vérifié absent des DEUX dépôts** : rien n'a été inventé. Le besoin passe par `extra`/`ZExtension` (prouvé : `token_usage` imbriqué fait un round-trip exact, `z_chat_serialization_compat_test.dart`).
- **Scoping IFFD** (`folderId`/`subFolderId`/`documentId`, `isArchived`, `isChatSession`, `conversationSummary`) ⇒ `extra`/`ZExtension` (prouvé).
- **`freshnessForSource`** de lex — `switch` sur ses sous-types douaniers : inapplicable à un socle générique.
- **`is_potentially_outdated`** — drapeau **dérivé** que lex persiste sans le relire ; ne pas le persister empêche un document de contredire la règle.
- ⚠️ **L'embedding hors-ligne de lex est un STUB** — jamais présenté comme une capacité prouvée.

#### ③ 🔴 HANDOFF — ce portage n'est **PAS additif**, et il ne l'est pas de la même façon pour tout le monde

**Pour IFFD — migration RÉELLE, à budgéter :**
- **champs plats → blocs typés** : `summary`/`poem`/`story`/`humor`/… (`chatbot_message.dart:124-156`) deviennent des `content_blocks` ⇒ **migration de données Firestore**, pas un simple recompile ;
- **callbacks → contrats** `Either`/`Stream` (CHAT-1/CHAT-2) ;
- **`WorkflowEffort` d'IFFD** (`lib/src/domain/models/ai/ai_models.dart:119-122`) **ne correspond à AUCUN type livré ici** : c'est un effort de **calcul**, `ZChatResponseLength` est une **longueur**. Les câbler l'un sur l'autre produirait un mapping silencieusement faux.

**Pour lex — additif en apparence, mais deux points de vigilance :**
- ses documents se relisent **typés** sans migration (alias PascalCase + snake_case), **sauf** `updated_at` : la conversation lex le persiste **en corps**, zcrud le **dépouille** ⇒ **le tri par récence sera vide** tant que lex n'écrit pas `last_message_at`. C'est une **perte fonctionnelle visible**, pas un détail de nommage ;
- ses blocs `LegalReference`/`Flashcards`/`Mindmap` retombent en `ZCustomContentBlock` **tant que l'app n'a pas enregistré ses codecs** : la donnée est intacte, le **type** ne revient pas.

**🔴 Pour tout hôte qui COMPENSAIT** (règle `CLAUDE.md § Handoffs`, pour ne pas répéter la 4ᵉ occurrence) : un hôte qui contournait le repli destructeur de lex (bloc inconnu affiché comme texte) — typiquement en filtrant les blocs `Text` au dump suspect, ou en pré-nettoyant `created_at` avant `fromJson` — **doit RETIRER sa compensation** : le socle traite désormais ces deux cas nativement (`ZCustomContentBlock`, `DateTime?`). Additionnées, compensation + correctif produisent des blocs **doublement filtrés** ou des dates **doublement effacées**.
🟢 **Tripwire recommandé** (pratique de lex, à propager) : garder chez l'hôte un test qui **affirme la perte** (« un bloc inconnu arrive en texte », « `created_at` absent lève ») ; il rougira au moment du portage et **désignera** le doublon, au lieu de faire confiance à ce handoff sur parole.

#### ④ Écarts au périmètre déclaré de la story

1. **`z_chat_json.dart` → `json/z_json_read.dart` exporté** (décision owner ⓪) — AC1 amendé, garde réécrite, non supprimée.
2. **`z_chat_extension_parser.dart`** : la story annonçait « 11 exports » ; il y en a **12**. Le `typedef ZChatExtensionParser` a été isolé dans son propre fichier plutôt que logé dans `z_chat_message.dart`, pour que `ZChatConversation` ne dépende pas du fichier du message. Additif, sans effet sur les ACs.
3. **`test/domain/json/`** : dossier de test hors de `test/domain/chat/` prévu par T9, conséquence directe de ⓪.

### File List

**Production — NEW**
- `packages/zcrud_core/lib/src/domain/json/z_json_read.dart` *(surface PARTAGÉE, décision owner)*
- `packages/zcrud_core/lib/src/domain/chat/z_chat_enums.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_extension_parser.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_source.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_thinking_step.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_attachment.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_suggestion.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_response_confidence.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_source_freshness.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_quota_snapshot.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_content_block.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_message.dart`
- `packages/zcrud_core/lib/src/domain/chat/z_chat_conversation.dart`

**Production — UPDATE**
- `packages/zcrud_core/lib/domain.dart` *(13 exports ajoutés : 12 chat + `json/z_json_read.dart`)*
- `tool/reserved_keys_gate/lib/src/manual_probes.dart` *(2 `ZManualProbe` + 4 writers top-level ; import `zcrud_core`)*

**Config — NEW**
- `packages/zcrud_core/dart_test.yaml` *(tag `serialization-compat`)*

**Tests — NEW**
- `packages/zcrud_core/test/domain/json/z_json_read_test.dart`
- `packages/zcrud_core/test/domain/chat/z_chat_enums_test.dart`
- `packages/zcrud_core/test/domain/chat/z_content_block_test.dart`
- `packages/zcrud_core/test/domain/chat/z_chat_source_test.dart`
- `packages/zcrud_core/test/domain/chat/z_chat_value_objects_test.dart`
- `packages/zcrud_core/test/domain/chat/z_chat_message_test.dart`
- `packages/zcrud_core/test/domain/chat/z_chat_conversation_test.dart`
- `packages/zcrud_core/test/domain/chat/z_chat_naming_guard_test.dart`
- `packages/zcrud_core/test/domain/chat/z_chat_serialization_compat_test.dart`

**NON touchés** (conformité AC14 / consigne) : `packages/zcrud_core/pubspec.yaml`, tout autre package, `melos.yaml`, `sprint-status.yaml`, `docs/`, les dépôts `iffd`/`lex_douane` (lecture seule), aucun `*.g.dart`.

### Change Log

| Date | Changement |
|---|---|
| 2026-08-01 | CHAT-0 implémentée : modèle de conversation neutre complet (12 fichiers de production), surface JSON défensive **partagée** du cœur, 2 sondes du gate `reserved-keys`, corpus `serialization-compat`, 151 tests. 25 injections R3 prouvées mordantes. Statut → `review`. |
