# Réfutation — « Tâches et découverte (IFFD) » / M4 « transport PAR ROUTE »

> ⚠️ **Nom de fichier.** Le nom demandé par l'orchestrateur fait **381 octets** et contient
> trois `/` (`22 778 lignes / …`, `lib/workflow`, `TTS/podcast`) : il est **impossible** sur
> ext4 (limite 255 octets, `/` illégal — mesuré : `len=365 chars / 381 bytes`). Nom retenu selon
> la convention du dossier (`carte-taches-decouverte.md`, `confrontation-taches-decouverte.md`) :
> `refutation-taches-decouverte-M4.md`.

- **Domaine** : Tâches et découverte (IFFD) — 59 fichiers / 22 778 lignes.
- **Besoin M4** : « Le transport PAR ROUTE réduit les 29 emballages `callApi` à leur seul prompt
  et remplace les 7 blocs `onComplete/_onAiCompletion` par un chemin d'envoi unique ».
- **Gain annoncé** : ~600 lignes d'hôte supprimées (196 domaine + ≈460 couche IA partagée).

## VERDICT : **RÉFUTÉE**

Les huit canaux nommés **existent**, aux lignes citées, avec les corps annoncés, et sont
**atteignables** depuis IFFD. Mais le mécanisme sur lequel repose l'affirmation —
**`routeName` = l'endpoint** — est **faux dans le socle** (aucun consommateur de transport) et
**null chez l'hôte** (le pont cité ne peut pas le produire). Le lien route → endpoint reste une
**table écrite à la main chez l'hôte**. S'y ajoutent quatre écarts mesurés : la répartition est
structurellement inerte pour le catalogue IFFD, la tâche la plus utilisée du domaine tombe à côté
de sa route, la tâche phare du domaine n'a aucune cible, et **84 % des lignes du domaine revendiqué
ne contiennent pas une seule ligne de transport IA**.

---

## 1. Ce qui TIENT (vérifié corps par corps)

### 1.1 Les canaux existent aux lignes citées

| Symbole | Chemin:ligne | Corps lu — vérifié |
|---|---|---|
| `zChatTaskKeyOf` | `packages/zcrud_chat/lib/src/presentation/routing/z_chat_route_session.dart:53` | `String zChatTaskKeyOf(ZChatGenerationRequest request) => request.style.kind;` — exact |
| `zChatApplyRoute` | idem `:65` | fonction pure ; `_resolution` → `gate.canRoute` → `res.toRequest(base, settings: _settingsOf(base))` |
| gate par défaut | idem `:202` | `ZChatRouteGate gate = const ZDenyAllChatRouteGate()` |
| `ZChatRouteSession.resolve` | idem `:294` | `ZResult<ZChatGenerationRequest> resolve(...)` → `zChatApplyRoute(...)` |
| `ZChatRouteResolution.from` | `packages/zcrud_chat_kernel/lib/src/domain/route/z_chat_route_resolution.dart:43` | repli route→racine **confirmé** aux `:52-56` (`routeOwnsModels` prend modèle+replis ensemble) |
| `routeName` (champ) | idem `:79-80` | `final String? routeName;` — alimenté par `route?.routeName` (`:52`) |
| `toRequest` | idem `:130-144` | `explicitModel = base.modelId != null` → un modèle explicite n'est **jamais** recouvert. Exact. |
| `ZChatRoutedStreamPort` | `packages/zcrud_chat/lib/src/presentation/routing/z_chat_routed_stream_port.dart:31` | classe présente, `stream()` répartit puis délègue |
| `ZChatGenerationRequest` | `packages/zcrud_chat_kernel/lib/src/domain/ai/z_chat_generation_port.dart:61` | présent |
| `ZChatGenerationStyle` | `.../z_chat_generation_style.dart:49` | présent (`kind` ouvert) |
| `ZChatStreamEvent` | `.../z_chat_stream_event.dart:49` | `sealed class` présente |

`ZDenyAllChatRouteGate` refuse bien par défaut (`z_chat_route_gate.dart:31-46`,
`Left(ZChatProviderFailure('route denied: …', code: upgradeRequired))`) : le **piège signalé est
réel**, et l'hôte le contourne bien à `discovry_page_controller.dart:649`
(`gate: const ZAllowAllChatRouteGate()`).

### 1.2 Atteignabilité — OK

- Barrel `zcrud_chat` : `lib/zcrud_chat.dart:112-115` exporte `z_chat_route_session.dart`,
  `z_chat_routed_stream_port.dart`, `z_chat_routed_artifact_port.dart`.
- Barrel `zcrud_chat_kernel` : `lib/zcrud_chat_kernel.dart:112-126` exporte les 8 fichiers `route/`
  + les 8 fichiers `route/catalog/`.
- `iffd/pubspec.yaml` déclare `zcrud_chat` (`:455-459`) et `zcrud_chat_kernel` (`:445-449`) en
  dépendance git, plus les `dependency_overrides` correspondants (`:589-603`).

### 1.3 Les chiffres de l'hôte — confirmés

| Constat du CR | Mesuré | Verdict |
|---|---|---|
| `grep -c 'return callApi(' iffd_ai_repository_impl.dart` | **29** | ✅ exact |
| `grep -c 'endpoint: aiRouter'` | **19** | ✅ exact |
| `ai_repository.dart` 494 l. | **494** | ✅ exact |
| « recopie 27× la signature `onComplete` » | **28** occurrences exactes de `void Function(AiResponse result, bool completed, {bool hasError})` sur 34 méthodes déclarées | ⚠️ 28, pas 27 (écart mineur) |
| 7 sites `_onAiCompletion` | `:1264, :1320, :2061, :2131, :2253, :2303, :2356` (+ déclaration `:1089`, + 1 commenté `:1928`) | ✅ exact |
| `:2231-2379` = 3 blocs identiques | lus intégralement : **oui**, hors le nom de méthode, l'enum `ChatbotMessageTransformer`, et — non signalé — `explainSubjectWithStyle` remplace `explanation:` par `style:` | ✅ quasi exact |
| pont `notebook_route_catalog_iffd.dart` 106 l. | **106** | ✅ exact |

---

## 2. RÉFUTATION 1 — `routeName` n'est PAS un endpoint, ni dans le socle, ni chez l'hôte

### 2.1 Dans le socle : un seul consommateur, et ce n'est pas un transport

```
$ grep -rn "routeName" packages/*/lib | sort
packages/zcrud_chat_kernel/.../z_chat_route_resolution.dart:33,52,79   (déclaration + affectation)
packages/zcrud_chat_kernel/.../z_chat_route_spec.dart:25,48,68,106,127,138 (champ + (dé)sérialisation)
packages/zcrud_chat/.../z_chat_routed_stream_port.dart:8,28            (le SEUL usage réel)
```

L'unique usage effectif est `z_chat_routed_stream_port.dart:28` :

```dart
List<String> zChatRouteDispatchIds({required ZChatRouteSpec? route, required String? providerId})
    => <String>[?route?.handlerId, ?providerId, ?route?.routeName];
```

puis `:61-64` : `port = handlers.streamPortFor(id)`. `routeName` est une **clé d'annuaire de ports
en mémoire**, pas un chemin HTTP. **Aucune ligne du socle ne construit d'URL à partir de
`routeName`.** L'affirmation « `:80 routeName = l'endpoint` » lit la dartdoc (« Nom de route
opaque ») comme une promesse de transport que le code ne tient pas — exactement le mode d'échec
que ce dépôt a déjà rencontré (drapeau de thème sans pixel, jeton sans consommateur).

### 2.2 Chez l'hôte : le pont cité ne peut PAS produire de `routeName`

`notebook_route_catalog_iffd.dart:42-59` déclare `ZChatRouteCatalogShape.suffixPairs(...)`. Le
décodeur, pour cette forme, n'écrit **que deux clés par route** :

- `z_chat_route_catalog_decoder.dart:185-188` → `_mergeRoute(derived, task, {'fallbacks': …})`
- `z_chat_route_catalog_decoder.dart:190-198` → `_mergeRoute(derived, task, {'model': value})`

Grep négatif **montré** :

```
$ grep -n "route_name" packages/zcrud_chat_kernel/lib/src/domain/route/catalog/z_chat_route_catalog_decoder.dart ; echo RC=$?
RC=1
$ grep -n "routeName"  packages/zcrud_chat_kernel/lib/src/domain/route/catalog/z_chat_route_catalog_decoder.dart ; echo RC=$?
RC=1
```

⇒ Pour **toutes** les routes IFFD, `ZChatRouteResolution.routeName == null`.

### 2.3 Où vit réellement l'endpoint : une table d'hôte de 10 entrées

`iffd/lib/ai_assistant/zcrud/notebook_byte_opener_iffd.dart:198-210` :

```dart
const Map<String, String> kIffdEndpointByKind = <String, String>{
  'converse': 'chat_with_assistant_v2', 'mindmap': 'generate_mindmap_with_ai',
  'flashcards': 'generate_subject_flashcards', 'summarize': 'summarize_explanation',
  'elaborate': 'elaborate_explanation', 'examples': 'explain_with_examples',
  'poem': 'explain_as_poem', 'story': 'explain_as_story',
  'humor': 'explain_with_humor', 'classroom': 'explain_as_classroom',
};
```

Le seul canal socle vers un endpoint est `route.params['endpoint']` → `extra['endpoint']`
(`:173-179`, `:214-218`). Or `suffixPairs` **n'émet aucun `params` de route** (§2.2), et
`IffdAiRouterModel.toMap()` (`ai_models.dart:355-390`) ne porte que 13 paires
`<tâche>Model`/`<tâche>FallbackModels` + `name`/`description`/`workflowEffort`/`questionsCounts` —
**aucun champ d'endpoint**. Le canal existe donc mais est **inerte pour IFFD**.

**Conclusion R1** : le « transport PAR ROUTE » que M4 promet est porté par une **table écrite à la
main dans l'hôte**, pas par la résolution du socle. Le socle apporte la clé de tâche, le modèle,
les replis, le palier et les params — pas la cible du POST.

### 2.4 Bonus : les 19 `endpoint: aiRouter…` ne sont pas des routes, c'est un bug d'hôte

L'hôte l'a lui-même mesuré et écrit (`notebook_byte_opener_iffd.dart:186-193`) :

> « MESURÉ EN PRODUCTION (2026-08-23) : `chat` → 404, `chat_with_assistant_v2` → 200. Le legacy
> appelait `aiRouter?.chatModel ?? "chat"` — or `chatModel` porte un NOM DE MODÈLE
> (`google/gemini-2.5-flash-lite`), et `/iffd/v3/google/gemini-2.5-flash-lite` → 404. »

Les 19 sites passent donc un **identifiant de modèle en guise d'endpoint**. Les compter comme
« 19 sélections de route à remplacer » surestime la couverture : ce sont 19 sites **déjà cassés**,
dont la correction est un choix d'hôte (quelle route pour quelle tâche), pas une capacité du socle.

---

## 3. RÉFUTATION 2 — la répartition par route est structurellement INERTE pour IFFD

`zChatRouteDispatchIds` = `[handlerId, providerId, routeName]`. Pour le catalogue IFFD :

| Identité | Valeur pour IFFD | Preuve |
|---|---|---|
| `handlerId` | **null** | `suffixPairs` n'émet jamais `handler_id` (grep négatif §2.2 vaut aussi : le décodeur n'écrit que `model`/`fallbacks`) |
| `providerId` | **null** | `notebook_route_catalog_iffd.dart:52` → `providerKey: null` ; et `ZChatModelRef._fromToken` (`z_chat_model_ref.dart:128-140`) coupe sur `:`, **pas** sur `/` ⇒ `"google/gemini-2.5-flash-lite"` donne `providerId == null` |
| `routeName` | **null** | §2.2 |

⇒ `ids` est la **liste vide** pour chaque tâche IFFD ⇒ `port ??= fallback` (`:65`) : **toutes** les
tâches partiraient sur le port de repli, la répartition ne discriminant rien.

Greps négatifs **montrés** côté hôte :

```
$ grep -rn "ZChatRouteHandlers\|streamPortFor" /home/zakarius/DEV/iffd/lib ; echo RC=$?
RC=1
$ grep -rn "ZChatRoutedStreamPort\|zChatApplyRoute\|zChatTaskKeyOf\|ZChatRouteResolution" /home/zakarius/DEV/iffd/lib ; echo RC=$?
RC=1
$ grep -rn "kIffdProviderOpenRouter" /home/zakarius/DEV/iffd/lib
notebook_route_catalog_iffd.dart:78:const String kIffdProviderOpenRouter = 'openrouter';   # 1 hit = sa propre déclaration, ZÉRO consommateur
```

Cinq des huit symboles cités par l'affirmation (`ZChatRoutedStreamPort`, `zChatApplyRoute`,
`zChatTaskKeyOf`, `ZChatRouteResolution`, et l'annuaire `ZChatRouteHandlers`) n'ont **aucun site
d'appel dans IFFD**. Seuls `ZChatRouteSession` (`:7, :636, :647`) et `ZAllowAllChatRouteGate`
(`:9, :649`) sont posés — et la session n'y sert qu'à être **transmise au Notebook**
(`routeResolver: widget.routeSession?.resolve`, `notebook_page_zcrud.dart:168, :176`), pas à
router les 16 appels `aiRepository.` du contrôleur de Découverte.

---

## 4. RÉFUTATION 3 — la tâche la plus utilisée du domaine tombe à côté de sa route

- Un tour de conversation porte `style.kind == 'converse'`
  (`zcrud_chat/lib/src/presentation/z_chat_conversation_controller.dart:76` et
  `.../notebook/z_chat_notebook_controller.dart:288` : `style: ZChatGenerationStyle.converse`).
- Le catalogue IFFD décode `chatModel` en clé de tâche **`'chat'`**, et
  `kIffdRouteTaskAliases` (`notebook_route_catalog_iffd.dart:67-72`) ne contient que
  `{summary→summarize, elaboration→elaborate, history→story, chatStyle→classroom}` — **pas**
  `chat → converse`.

⇒ `resolve()` sur un tour de conversation cherche `routeOf('converse')` → `null` → `declared:false`,
`res.isEmpty == false` (la racine `aiModel` a une valeur par défaut,
`ai_models.dart:244 : aiModel = 'nvidia/nemotron-3-nano-30b-a3b'`) ⇒ **passe silencieusement sur le
modèle racine**. `chatModel` / `chatFallbackModels` ne sont **jamais** consultés. Ce n'est pas une
erreur remontée : c'est un manque silencieux, sur la tâche la plus fréquente du domaine.

Le commentaire d'hôte qui justifie ce choix (`:66`, « la requête de conversation n'a pas de style »)
est **démenti par le socle** : `ZChatGenerationRequest.style` est `required`
(`z_chat_generation_port.dart:64`) et vaut `converse` pour un tour nu.

---

## 5. RÉFUTATION 4 — la tâche PHARE du domaine n'a aucune cible

`explainSubject` (`discovry_page_controller.dart:1277`) → `aiRepository.generateSubjectExplanation`
(`iffd_ai_repository_impl.dart:709`) → `endpoint: aiRouter?.explanationModel ?? "explain"` (`:749`).

`kIffdEndpointByKind` **n'a aucune clé `explain` / `explanation`** — les cinq occurrences de
« explain » dans la table sont des **valeurs** (`explain_with_examples`, `explain_as_poem`,
`explain_as_story`, `explain_with_humor`, `explain_as_classroom`), jamais des clés (table lue
intégralement, `:198-210`).

⇒ Migrée telle quelle, l'explication de sujet — le cœur de la Découverte — produirait
`Stream.error(StateError('aucun endpoint IFFD pour le style « … »'))` (`:228-236`).

Même situation pour : `generate_related_topics` (×2), `generate_conversation_summary`,
`generate_summary` (×2), `generate_subject_tags`, `generate_flashcard_explanation`,
`evaluate_flashcard_answer`, `generate_flashcard_hint`, `generateAiExpertInstructions`,
`generate_speech`. **Sur les 14 emballages de génération de texte, la table existante en couvre 4
méthodes** (`chatWithAssistant`, `summarizeExplanation`, `elaborateExplanation`,
`explainSubjectWithStyle` — cette dernière couvrant 5 styles).

---

## 6. RÉFUTATION 5 — les 29 emballages ne sont pas homogènes (6 hors périmètre, 9 sur un autre port)

Appariement exact méthode ↔ site `return callApi(` (29 sites, `iffd_ai_repository_impl.dart`) :

| Catégorie | Nb | Sites |
|---|---|---|
| **Pas une génération** (objets OpenAI, ingestion, TTS) | **6** | `retreiveOpenAiAssistant` :506, `retreiveOpenAiVectorStore` :539, `setOpenAiAssistant` :569, `retrieveOpenAiAssistant` :596, `generateSpeechFromTextWithAi` :651, `ingestAiExpertDocuments` :1355 |
| **Artefacts JSON** (flashcards / mindmap / tags) | **9** | :616, :635, :1069, :1098, :1195, :1228, :1259, :1290, :1317 |
| **Génération de texte** | **14** | :690, :749, :781, :810, :827, :867, :913, :940, :968, :997, :1034, :1128, :1157, :1334 |

- Les **6** premiers parsent `AssistantObject` / `VectorStoreObject` (`:511-517`, `:544-548`) ou
  poussent de l'audio — **rien de tout cela n'est modélisé par `ZChatStreamEvent`** (union scellée :
  `thinking`, `retrievalProgress`, `sourcesPreview`, `token`, `contentBlock`, `suggestions`, …
  `z_chat_stream_event.dart:95-140`). ⚠️ **`generateSpeechFromTextWithAi` (TTS/podcast) est
  explicitement nommé dans la description du domaine** : le canal invoqué ne le couvre pas.
- Les **9** artefacts relèvent de `ZChatArtifactGenerationRequest` / `resolveArtifact` /
  `zChatApplyArtifactRoute` / `ZChatRoutedArtifactPort` — **une autre paire de ports**, que
  l'affirmation ne nomme pas. « Le socle sait le faire » reste vrai, mais **pas par les huit
  symboles avancés**.

⇒ « réduit les **29** emballages à leur seul prompt » est faux pour au moins 6, et exige un second
canal non nommé pour 9 de plus.

### 6.1 « à leur seul prompt » — l'emballage n'est pas fait que d'un prompt

`generateSubjectExplanation` (`:709-760`) : **25 paramètres nommés**, dont 8 (`enableCDNTogo`,
`enableCDNNiger`, `enableCDCCedeao`, `enableCGITogo`, `enableTecCedeao`, `enableCodeGATT`,
`niveauIFFD`, `thinkingEffort`, `maxWebSearchResults`, `maxWebThinkingTokens`, `scrapeWebResults`,
`enableThinking`, `aiExpertRagModel`) **acceptés puis silencieusement jetés** — le `data:` envoyé
(`:752-756`) ne porte que `message`, `model`, `enableWebSearch`. Le volume de l'emballage est cette
liste de paramètres, pas le prompt ; migrer la déplace dans `extra`, elle ne disparaît pas.

---

## 7. RÉFUTATION 6 — le gain annoncé est HORS du domaine revendiqué (84 % des lignes non concernées)

Grep négatif **montré** :

```
$ grep -rn "callApi" /home/zakarius/DEV/iffd/lib/src/presentation/features/discovery \
                     /home/zakarius/DEV/iffd/lib/workflow \
                     /home/zakarius/DEV/iffd/lib/src/presentation/features/tasks | wc -l
0
```

Mesure du domaine revendiqué (59 fichiers / 22 778 lignes) :

| Zone | Fichiers | Lignes | `callApi\|onComplete\|_onAiCompletion` |
|---|---:|---:|---:|
| `lib/workflow` (espace de travail) | 38 | 17 417 | **0** |
| `lib/src/presentation/features/discovery` | 8 | 3 729 | 50 |
| `lib/src/presentation/features/tasks` | 4 | 1 218 | **0** |
| `lib/src/features/tasks` | 3 | 228 | **0** |
| `lib/src/domain/repositories/workflow` | 3 | 109 | **0** |
| **Total** | **56** | **22 701** | **50** |

(56 f. / 22 701 l. ≈ les 59 f. / 22 778 l. annoncés — l'écart tient à 3 fichiers non identifiés,
sans incidence.)

⇒ M4 ne touche que **`features/discovery` : 8 fichiers sur ~59 (14 %), 3 729 lignes sur 22 778
(16 %)**. Les deux tiers du domaine (tâches quotidiennes, `lib/workflow` : listes, tâches, agenda,
événements, récurrence — 45 fichiers / 19 049 lignes) **ne contiennent aucun transport IA**.

Et les ~600 lignes promises vivent **ailleurs que dans le domaine** :

- `lib/src/data/repositories/iffd_ai_repository_impl.dart` — **1 377 l.**
- `lib/src/domain/repositories/ai_repository.dart` — **494 l.**

Ces deux fichiers sont **partagés** : `ai_repository.dart` est importé par **28 fichiers**, et
`aiRepository.` est appelé depuis 10 fichiers hors Découverte (notebook `ai_assistant/`,
`features/flashcards`, `features/documents`, `features/smartnotes`, `features/administration`,
`features/explain_ai`, `features/folders`). L'affirmation le concède à demi (« ≈460 l. couche IA
partagée » = 70 % du gain), mais l'impute quand même au domaine. **Elle attribue à « Tâches et
découverte » un gain qui appartient à la couche IA transverse.**

---

## 8. Écart mineur — « un chemin d'envoi unique » couvre 7 des 18 fermetures

Le contrôleur de Découverte porte **18** fermetures `onComplete:` (`:447, :480, :1263, :1319,
:1354, :1420, :1449, :1610, :1640, :1647, :1752, :2037, :2058, :2128, :2252, :2302, :2355`), dont
**7** passent par `_onAiCompletion`. Les 11 autres font un travail **différent** et ne se replient
pas sur un chemin unique — vérifié en lisant deux d'entre elles :

- `:1354` et `:1420` : `relatedSubjects = (json.decode(result.data ?? '[]') as List? ?? []).cast()`
  — parsing d'une liste JSON, pas un flux de tokens ;
- `:1449` : accumulation de résumé **avec surcharge de modèle en dur**
  (`aiRouter?.copyWith(aiModel: "openai/gpt-oss-20b")`, `:1447`).

La formulation du besoin (« les 7 blocs ») est donc **exacte**, mais elle ne décrit que 39 % des
fermetures du fichier. (Le socle **couvre bien** la surcharge de modèle : `setModelOverride` /
`request.modelId` explicite, `z_chat_route_session.dart:283-288` et `z_chat_route_resolution.dart:134`.)

---

## 9. Ce qui est VRAI à la place

1. Le socle sait **résoudre par clé de tâche** : `style.kind` → route → `(modèle, replis, palier,
   budget, params)`, avec gate de gouvernance et priorité correcte (paramètre > repli > route >
   racine). C'est réel, testé au corps, exporté, et **déjà en service** pour le Notebook d'IFFD
   (`notebook_page_zcrud.dart:168`).
2. Le socle sait **répartir vers un port** par `handlerId` / `providerId` / `routeName` — mais
   uniquement vers des ports que l'hôte a **enregistrés en mémoire**, et à condition que le
   catalogue produise l'une de ces trois identités. **Le catalogue IFFD n'en produit aucune.**
3. Le socle **ne porte pas** la cible du POST. Pour la porter, il faudrait soit
   (a) un `route_name` / `handler_id` / `params.endpoint` par route — que la forme `suffixPairs`
   n'émet pas et qu'`IffdAiRouterModel` ne déclare pas ; soit
   (b) un `providerKey` dans la forme + un annuaire `ZChatRouteHandlers` côté hôte — les deux
   absents (grep §3).
4. Le gain réel de M4, s'il était mené, porterait sur **`features/discovery` (8 f. / 3 729 l.)** et
   sur **la couche IA partagée (2 f. / 1 871 l.)**, pas sur les 45 fichiers / 19 049 lignes de
   tâches et de `lib/workflow` — qui n'ont aucun transport IA.
5. Le préalable réel à M4 n'est pas socle mais **hôte** : compléter `kIffdEndpointByKind` (10
   entrées aujourd'hui, ≥10 tâches sans cible), aliaser `chat → converse`, et décider si l'endpoint
   descend dans le document de routeur (nouveau champ `IffdAiRouterModel`) ou reste une table Dart.

## 10. Ce que je n'ai PAS pu vérifier

- Le **contenu réel en base** des champs `<tâche>Model` des documents `aiRouters` (Firestore) : je
  n'ai lu que le modèle Dart et le relevé de production cité par l'hôte
  (`notebook_byte_opener_iffd.dart:186-193`). Je m'appuie sur ce relevé, pas sur une mesure propre.
- Le **catalogue de routes servi par le backend** (`iffd/v3/router.py`) : hors des dépôts lisibles.
- Le décompte exact **59 fichiers / 22 778 lignes** du domaine : j'obtiens 56 / 22 701 sur les cinq
  répertoires identifiés ; 3 fichiers restent non attribués.
- **Aucun test n'a été lancé** (consigne).
