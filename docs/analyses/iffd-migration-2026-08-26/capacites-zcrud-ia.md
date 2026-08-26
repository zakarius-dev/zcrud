# Ce que le socle zcrud SAIT FAIRE aujourd'hui — aire « IA : chat, notebook, routage par tâche, artefacts »

**Mesuré le 2026-08-26** sur `/home/zakarius/DEV/zcrud` à `v3.21.0` (HEAD `cc276c154`), et sur
`/home/zakarius/DEV/iffd` en **lecture seule**.

Ce document est la référence commune de onze agents de confrontation. Il ne dit pas ce qu'il
faudrait faire : il dit **ce qui existe, où, et ce qu'un hôte en obtient**.

---

## 0. Chiffres de cadrage

| Mesure | Valeur | Comment obtenue |
|---|---|---|
| Paquets du périmètre | 6 | `zcrud_chat`, `zcrud_chat_kernel`, `zcrud_chat_firestore`, `zcrud_chat_markdown`, `zcrud_chat_material`, `zcrud_chat_syncfusion` |
| Fichiers Dart sous `lib/` | **157** | `find packages/zcrud_chat*/lib -name '*.dart' \| wc -l` |
| Lignes sous `lib/` | **42 338** | kernel 15 102 · chat 22 860 · material 2 807 · syncfusion 1 022 · markdown 301 · firestore 246 |
| **Canaux publics catalogués** | **675** | types + typedefs + enums + fonctions/consts top-level extraits des 6 `lib/src` |
| Nommés dans `iffd/lib/` | **102** (15 %) | intersection avec tous les identifiants de `iffd/lib/` |
| **Jamais nommés dans `iffd/lib/`** | **573** (85 %) | complément |
| Jetons de thème `chat*` dans `ZcrudTheme` | **20** | `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:1852-1976` |
| Jetons `chat*` posés par IFFD | **1 sur 20** | seul `chatComposerActiveAccent` (2 sites) |
| Fichiers IFFD important `package:zcrud_chat*` | **24** | `grep -rl` sur `iffd/lib/` |

Répartition des 573 canaux non nommés par l'hôte :

| Paquet | Non nommés / total |
|---|---|
| `zcrud_chat` | 319 / 361 |
| `zcrud_chat_kernel` | 195 / 248 |
| `zcrud_chat_material` | 37 / 39 |
| `zcrud_chat_syncfusion` | 18 / 22 |
| `zcrud_chat_markdown` | 2 / 3 |
| `zcrud_chat_firestore` | 2 / 2 |

⚠️ **Ce que « non nommé » veut dire, et ce qu'il ne veut pas dire.** La mesure est un
`comm` entre la liste des symboles publics et la liste des identifiants de `iffd/lib/`. Un canal
peut être **consommé sans être nommé** (créneau interne d'un widget monté, valeur par défaut). Un
canal non nommé est donc un **candidat**, pas une preuve d'absence de fonctionnalité. Chaque
constat isolé plus bas est, lui, vérifié par un `grep` ciblé montré.

---

## 1. 🔴 Correction du contexte daté — le chat n'a **rien reçu** entre 3.12.0 et 3.21.0

Le brief annonçait « beaucoup de canaux livrés entre le 13 et le 25 août (3.13 → 3.21) …
RÉCENTS et souvent inconnus de l'hôte ». **C'est faux pour cette aire.**

```
git log --oneline v3.12.0..HEAD -- packages/zcrud_chat packages/zcrud_chat_kernel \
  packages/zcrud_chat_firestore packages/zcrud_chat_markdown packages/zcrud_chat_material \
  packages/zcrud_chat_syncfusion
```
rend 9 commits — **les 9 releases v3.13.0 → v3.21.0** — et le `--stat` de chacune ne touche
que **6 `pubspec.yaml`, 22 insertions / 22 suppressions** : des bumps de version en lockstep.
Aucun `lib/`, aucun `test/`.

`git log -- packages/zcrud_chat*/lib` confirme : **le dernier commit fonctionnel du chat est
`fe0d9311d`, v3.11.0, 2026-08-23**. Les versions 3.13 → 3.21 (24-25 août) sont entièrement
consacrées aux **formulaires d'édition** (CR-IFFD-92 → 112).

⇒ **La fenêtre de récence utile pour cette aire est v3.2.0 → v3.11.0 (21-23 août)**, et non
3.13 → 3.21. C'est là que vivent le composer assemblé, la feuille d'outils, les deux
contrôleurs, le routage par tâche et le transcript partagé. Le § 8 la détaille.

⚠️ Corollaire pour les onze agents : **ne pas chercher de « nouveauté chat » dans les CHANGELOG
3.13 → 3.21** — ils n'en portent aucune. Les CHANGELOG des six paquets s'arrêtent
respectivement à 3.11.0 (`zcrud_chat`), 3.10.0 (kernel), 3.8.0 (firestore), 3.7.0 (material),
3.4.0 (markdown), 3.0.0 (syncfusion).

---

## 2. `zcrud_chat_kernel` — le domaine pur (248 canaux, 15 102 lignes)

Dart pur, dépend de `zcrud_core` seul. Aucun codegen sur ce paquet.

### 2.1 Entités et blocs de contenu

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatConversation` | `src/domain/z_chat_conversation.dart:46` | Entité `ZEntity` + `ZExtensible` : un hôte qui veut persister une conversation écrit son repo sur ce type, sans réécrire de codec. | — |
| `ZChatMessage` | `src/domain/z_chat_message.dart:54` | Idem pour un message ; porte `contentBlocks`, `sources`, `attachments`, `thinking`, `suggestions`, `agentsCalled`, `sourceFreshness`, `extra` filtré. | — |
| `ZContentBlock` (sealed) | `src/domain/z_content_block.dart:158` | La famille **ouverte** de blocs (`String kind`, jamais `sealed` à l'extension — AD-4). | `kZContentBlockUnknownKind` (`:119`) |
| `ZTextBlock` … `ZCustomContentBlock` | `z_content_block.dart:391, 417, 462, 550, 642, 682, 732, 767, 799, 837` | **Dix** formes livrées : texte, tableau, définitions clés, tableau comparatif, chronologie, alerte, diagramme Mermaid, sources, suggestions, bloc libre. Un hôte qui veut rendre une chronologie n'écrit que le rendu, pas le modèle. | — |
| `zChatAccessibleTextOf` | `z_content_block.dart:144` | Le texte lisible par lecteur d'écran d'un bloc quelconque, avec résolveur d'hôte optionnel. | séparateurs `:105`, `:111` |
| `ZChatSource` / `ZChatSourceFreshness` / `ZChatSuggestion` / `ZChatThinkingStep` / `ZChatAttachment` / `ZChatQuotaSnapshot` | `z_chat_source.dart:49`, `z_chat_source_freshness.dart:15`, `z_chat_suggestion.dart:101`, `z_chat_thinking_step.dart:13`, `z_chat_attachment.dart:11`, `z_chat_quota_snapshot.dart:11` | Les value objects de fin de réponse. | — |
| `ZChatResponseConfidence` + `ZChatConfidenceFactor` + `ZChatConfidenceThresholds` | `z_chat_response_confidence.dart:93, 38, 20` | Le verdict de confiance **déjà calculé par le serveur** traverse le socle sans être ni perdu ni réinventé. | — |
| Enums neutres (11) | `z_chat_enums.dart:25, 72, 112, 141, 168, 211, 243, 273, 307, 336, 367` | `ZChatRole`, `ZChatResponseLength`, `ZChatLengthBias`, `ZChatFeedbackRating`, `ZChatFeedbackCategory`, `ZChatSuggestionType`, `ZChatSuggestionActionType`, `ZChatSourceUsageStatus`, `ZChatDatasetFreshness`, `ZChatConfidenceLevel`, `ZChatConfidenceFactorSense`. | `@JsonKey(unknownEnumValue:)` partout |

### 2.2 Génération, streaming, échecs

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatStreamPort` | `src/domain/ai/z_chat_generation_port.dart:465` | Le port de flux : `Stream<Either<ZFailure, ZChatStreamEvent>>`. Un hôte qui veut brancher son backend implémente **cette seule interface**. | — |
| `ZChatGenerationPort` | `z_chat_generation_port.dart:411` | La variante non-streamée. | — |
| `ZChatGenerationRequest` | `z_chat_generation_port.dart:61` | La requête neutre : style, contexte, `attachmentIds`, capacités, `providerId`, `extra` filtré ; `copyWith` (`withSettings`, `withCorpusScope`) est le **site unique** de recopie. | — |
| `ZChatStreamEvent` (sealed) + 8 cas | `z_chat_stream_event.dart:49, 193, 228, 273, 313, 349, 391, 436, 471, 557` | Réflexion, progression de récupération, aperçu de sources, jeton, bloc, suggestions, quota, fin, événement libre. | alias de lecture `:185` |
| `ZChatGenerationSettings` | `z_chat_generation_settings.dart:86` | Porteur neutre transportable **sur la requête et sur `ZChatRegenerateAction`** ; `capabilities` à clés opaques (AD-4). | `kZChatCapabilityWebSearch` `:78` |
| `ZChatGenerationStyle` | `z_chat_generation_style.dart:50` | Le style **ouvert** (`kind` + `params`) — c'est lui qui porte la **clé de tâche** du routage (`zChatTaskKeyOf` lit `request.style.kind`). | — |
| `ZChatComputeEffort` | `z_chat_compute_effort.dart:37` | Le budget de calcul, valeur bornée. | — |
| `ZChatCorpusScope` + `.audit` | `z_chat_corpus_scope.dart:140`, audit `:190` | La **portée documentaire vérifiable** : la portée s'écrit en clés stables, `audit(sources)` confronte les sources rendues à la portée demandée → `ZChatCorpusAudit` (`:254`). Sans ce bouclage, une restriction ne vaudrait rien. | portée nulle ⇒ audit toujours satisfait (`:139`) |
| `ZChatCapabilityAudit` | `z_chat_capability_audit.dart:48` | Le **pendant exact** côté capacités : `settings.auditCapabilities(honored)` ferme la boucle anti-repli-muet. | — |
| `ZChatResponseMetadata` | `z_chat_response_metadata.dart:91` | La carte **ouverte** de fin de réponse : scores, garde-citations, couverture, fraîcheur. | clés connues `:59`, `:71` |
| `ZChatQuotaKeys` / `zChatQuotaFromMetadata` / `zChatRetryAfterFromMetadata` | `z_chat_quota_metadata.dart:55, 94, 102, 126` | Extraction du quota et du délai de reprise depuis les métadonnées serveur. | `kZChatQuotaKeys` |
| `ZChatRequestToken` | `z_chat_request_token.dart:64` | Jeton d'annulation **par requête**. | — |
| Échecs IA (4) | `z_chat_ai_failure.dart:49, 93, 140, 210` | `ZChatModerationFailure`, `ZChatContextLimitFailure`, `ZChatStreamInterruptedFailure`, `ZChatProviderFailure`. | — |
| `zChatFailureFromWire` | `z_chat_ai_failure.dart:306` | Traduit un code serveur en `ZFailure` typé — un hôte n'écrit pas sa table. | `ZChatFailureCodes.upgradeRequired` |
| `ZChatContextPort` / `ZChatContextFragment` / `ZChatContextRequest` | `z_chat_context_port.dart:181, 40, 133` | Le contexte d'étude injecté dans la requête. | — |

### 2.3 Transport SSE — livré v3.6.0, **jamais nommé par IFFD**

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `zChatSseLines` | `src/data/sse/z_chat_sse_line.dart:193` | Octets → lignes SSE : `data:` retiré une fois, lignes vides conservées, `id:` ⇒ reprise, sentinelle `[DONE]`, **annulation par jeton immédiate**. Un hôte qui veut du SSE n'écrit plus le découpage. | `kZChatSseDoneSentinel` `:37` |
| `ZChatSseLine` / `ZChatSseField` / `zChatClassifySseLine` | `:75`, `:40`, `:141` | La ligne typée et son classement. | — |
| `ZChatSseStreamPort` | `src/data/sse/z_chat_sse_stream_port.dart:129` | Un `ZChatStreamPort` complet **paramétré par l'ouvreur et le décodeur de l'hôte** : le socle ne connaît ni URL, ni auth, ni JSON. Aucune dépendance HTTP. | — |
| `zChatSseJsonLineDecoder` | `z_chat_sse_stream_port.dart:95` | Le décodeur JSON prêt à l'emploi. | — |
| `ZChatSseOpener` / `ZChatSseLineDecoder` | `:60`, `:81` | Les deux coutures d'hôte. | — |

> **GREP NÉGATIF MONTRÉ.** `grep -rn 'ZChatSseStreamPort\|zChatSseLines\|zChatSseJsonLineDecoder' /home/zakarius/DEV/iffd/lib/` → **aucune ligne**. IFFD passe par `ZIffdTextStreamPort` (§ 6), un fil textuel à balises, pas du SSE.

### 2.4 Actions de message

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatAction` (sealed) + 6 cas | `src/domain/action/z_chat_action.dart:129, 158, 219, 281, 328, 370, 412` | `ZChatEditAction`, `ZChatRegenerateAction`, `ZChatDeleteAction`, `ZChatCancelAction`, `ZChatCopyAction`, `ZChatCustomAction`. **Un verbe = un site d'appel.** | — |
| `ZChatActionDispatcher` | `z_chat_action_dispatcher.dart:40` | Le répartiteur **unique** : aucun membre d'effet de l'exécuteur n'est joignable autrement. | — |
| `ZChatActionPlan` / `ZChatActionImpact` / `ZChatConfirmedAction` | `z_chat_action_plan.dart:119, 74, 180` | Le plan avant exécution, avec son impact mesuré — c'est ce qui rend une confirmation **informée**. | constructeur privé |
| `ZChatActionExecutor` | `z_chat_action_executor.dart:33` | L'interface que l'hôte implémente. | — |
| `ZChatSettingsAwareActionExecutor` | `z_chat_action_executor.dart:114` | La variante qui reçoit les réglages. | — |
| `ZChatUnsupportedActionExecutor` | `z_chat_unsupported_action_executor.dart:29` | L'exécuteur **par défaut** : refuse proprement au lieu de lever. | défaut des deux écrans |
| `ZChatDraft` / `ZChatCopyFormat` | `z_chat_action.dart:84, 116` | — | — |

### 2.5 Notebook — vocabulaire et ports (livré v3.6.0)

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatArtifactRegistry` | `src/domain/notebook/z_chat_artifact_declaration.dart:477` | Le registre des artefacts **déclarés par jetons** : un hôte qui veut « carte mentale + flashcards + note » déclare trois `ZChatArtifactDeclaration`, et les verbes en sont **dérivés**. | — |
| `ZChatArtifactDeclaration` | `:290` | Un artefact : clé opaque, jetons de glyphe/libellé/accent, `subjectRequired`, `style`, `extra` filtré (AD-19.1). | — |
| `ZChatArtifactVerb` | `:116` + fabriques `:131, 140, 149, 158, 167` | Les sept verbes standard préfabriqués. | `create`/`open`/`regenerate`/`edit`/`delete`/`print`/`share` (`:32-51`) |
| `ZChatArtifactVerbAvailability` | `:59` | Quand un verbe est offert. | — |
| `ZChatArtifactStatus` + `.resolve` | `z_chat_artifact_status.dart:98` | **« occupation > existence »** : l'état dérivé une fois, pas recalculé par surface. | `ZChatArtifactPhase` `:25` |
| `ZChatArtifactStatePort` | `z_chat_artifact_status.dart:183` | La lecture d'état côté hôte. | — |
| `zChatRunArtifactGeneration` | `z_chat_artifact_generation_port.dart:379` | **La séquence gardée**, écrite une fois : refus sur vide → marquer occupé → générer → écrire **si non vide** → démarquer **dans un `finally`**. Échecs typés jamais avalés. | — |
| `ZChatArtifactGenerationRunner` | `:451` | La forme objet de la même séquence. | — |
| `ZChatArtifactGenerationPort` / `Request` / `Content` | `:360`, `:142`, `:312` | Le port de génération, sa requête (avec `providerId` opaque depuis v3.9.0) et son contenu. | — |
| Échecs d'artefact (3) | `:54`, `:84`, `:115` | `ZChatArtifactEmptyInputFailure`, `ZChatArtifactEmptyResultFailure`, `ZChatArtifactGenerationFailure`. | — |
| `ZChatArtifactStorePort` | `z_chat_artifact_store_port.dart:27` | Stockage à **suppression atomique anti-résurrection**, toutes représentations. | `kZChatArtifactPrimaryRepresentation` `:52` |
| `ZChatInMemoryArtifactStore` | `:63` | L'implémentation mémoire prête pour un test ou un brouillon. | — |
| `ZChatTranscriptPort` | `z_chat_transcript_port.dart:33` | Le fil **lu ET écrit**. | — |
| `zChatTranscriptOrEmpty` | `:56` | Erreur ⇒ fil vierge, désabonnement immédiat (AD-10). | — |
| `ZChatInMemoryTranscript` | `:102` | — | — |
| `ZChatDraftRequestBuilder` / `ZChatSequentialRequestIds` / `zChatConfirmWithoutDialog` | `z_chat_notebook_defaults.dart:31, 85, 110` | Les défauts des seams triviaux : un hôte qui ne veut pas de dialogue de confirmation ne l'écrit pas. | — |

### 2.6 Feuille d'outils déclarative (livré v3.6.0) — **aucun site chez IFFD**

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatToolCatalog` | `src/domain/tools/z_chat_tool_catalog.dart:177` | La feuille d'outils devient une **donnée** au lieu d'un aiguillage codé. `setState` (`:300`) / `advance` (`:345`) / `reset` (`:367`) rendent des `Either`. | — |
| `ZChatToolCatalog.resolve()` | `:217` | Visibilité **motivée**, grisage **avec sa raison**, ordre, comptage agrégé, liste des actifs, recherche — calculés **une fois** pour les deux surfaces (bande + feuille). | — |
| `ZChatToolResolution` / `ResolvedEntry` / `ResolvedSection` | `:141`, `:99`, `:125` | Le résultat dérivé. | `activeCount` `:165` |
| `ZChatToolEntry` | `z_chat_tool_entry.dart:215` | Un outil déclaré une fois : `iconKey`/`itemLabels` opaques, proéminence, révélation conditionnelle, règles d'exclusion. | — |
| `ZChatToolCondition` / `ZChatToolRule` | `:102`, `:169` | Les conditions et les règles de désactivation **avec raison**. | — |
| `ZChatToolProminence` / `Surface` / `HiddenReason` | `:32`, `:62`, `:74` | `auto` / bande / feuille. | `auto` |
| `ZChatToolState` (sealed) + 6 cas | `z_chat_tool_state.dart:89, 170, 212, 269, 328, 432, 523, 559` | Bascule, cycle 0..N, choix, échelle à repères, catalogue filtrable, commande, état libre. | jetons `:65-83` |
| `ZChatToolSection` | `z_chat_tool_catalog.dart:47` | — | `kZChatToolSectionUnassigned` `:40` ; recherche au-delà de 3 sections `:44` |

### 2.7 Catalogue de routes (livré v3.8.0 / v3.9.0 / v3.10.0)

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatRouter` | `src/domain/route/z_chat_router.dart:52` | L'entité de routeur, `ZEntity` + `ZExtensible`, écrite à la main : routes par tâche, modèle et replis racine, `tier` opaque, `computeEffort`, `params`, `extension`, `extra` filtré. | `kZChatRouterKind` `:46` |
| **`$ZChatRouterFieldSpecs`** | `z_chat_router.dart:340` | 🔴 **Le formulaire ET la liste d'administration d'un routeur, sans une ligne de code hôte** — `routes` en `subItems` imbriqués, replis en sous-liste `{provider_id, model_id}`. | — |
| **`registerZChatRouter(registry)`** | `z_chat_router.dart:385` | L'enregistrement au `ZcrudRegistry` : les cellules de liste viennent du registre. | — |
| `ZChatRouteSpec` + `$ZChatRouteSpecFieldSpecs` | `z_chat_route_spec.dart:20`, `:158` | Une route par tâche : route, fournisseur, modèle, replis, effort, paramètres, **jetons d'accès**, handler. | — |
| `ZChatModelRef` + `$ZChatModelRefFieldSpecs` | `z_chat_model_ref.dart:25`, `:122` | `{providerId?, modelId}` **partout où un modèle est nommé** — le fournisseur voyage par tâche et par repli, jamais interprété. | — |
| `ZChatRouteResolution.from(router, taskKey)` | `z_chat_route_resolution.dart:27` | Résolution **pure** : repli tâche → racine, le couple (modèle, replis) replie ensemble ; `toRequest(base, {settings})` **n'emporte jamais** sur un choix explicite de l'appelant. | effort : `base ?? route ?? racine` (v3.9.0) |
| `ZChatRouteCatalogPort` | `z_chat_route_catalog_port.dart:19` | `resolveRouter` / `listRouters` / `invalidate`. | `ZChatInertRouteCatalog` `:34` |
| `ZChatInMemoryRouteCatalog` | `:60` | — | — |
| **`ZChatRouteGate`** | `z_chat_route_gate.dart:19` | La **gouvernance par plan d'abonnement** : `canRoute(taskKey, {tier, requiredAccessTokens})`. | 🔴 **`ZDenyAllChatRouteGate` (`:31`) — refuse TOUT** ; `ZAllowAllChatRouteGate` `:49` |
| `ZChatRouteHandlers` | `z_chat_route_handlers.dart:15` | `streamPortFor` / `generationPortFor` — un port **par route**. | `Inert` `:24`, `Map` `:37` |
| `ZChatRouteCatalogSource` | `catalog/z_chat_route_catalog_source.dart:28` | La source d'un catalogue. `Right(null)` = absent ici, `Left` = panne — la distinction est portée. | `ZChatStaticRouteCatalogSource` `:44` |
| `ZChatRepositoryRouteCatalogSource` | `catalog/z_chat_repository_route_catalog_source.dart:17` | Un catalogue **sur tout `ZReadOnlyRepository<ZChatRouter>`**. | — |
| `ZChatRemoteRouteCatalogSource` | `catalog/z_chat_remote_route_catalog_source.dart:50` | Catalogue **servi par le backend**, HTTP-agnostique : l'hôte ouvre, le socle décode. | `ZChatRouteCatalogQuery` `:21` |
| `ZChatRouteCatalogDecoder` | `catalog/z_chat_route_catalog_decoder.dart:235` | Décodage **défensif** : un routeur corrompu est compté (`ZChatRouteCatalogRejection` `:187`, rapport `:209`), jamais la liste perdue. | — |
| `ZChatRouteCatalogShape` | `catalog/z_chat_route_catalog_decoder.dart:49` | Trois formes de document livrées : `canonical`, `lex`, `suffixPairs` à clés d'hôte — plus **`taskAliases`** (v3.10.0), la traduction des noms de tâche **après** extraction. | — |
| `ZChatTtlRouteCatalog` | `catalog/z_chat_ttl_route_catalog.dart:28` | Cache à durée de vie, **cache négatif**, service périmé sur panne distante, invalidation ciblée. | — |
| `ZChatCascadeRouteCatalog` | `catalog/z_chat_cascade_route_catalog.dart:33` | Cascade ordonnée avec repli **déclaré par l'hôte seulement** ; sinon `Left(ZNotFoundFailure)`. | — |
| `ZChatInMemoryRouterRepository` / `ZChatInvalidatingRouterRepository` | `catalog/z_chat_in_memory_router_repository.dart:34`, `catalog/z_chat_invalidating_router_repository.dart:21` | Dépôt mémoire et décorateur d'invalidation. | — |

### 2.8 Conversation, saisie assistée, diffusion vocale

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatConversationSearchPort` | `src/domain/conversation/z_chat_conversation_ports.dart:390` | `searchConversations` → `List<ZChatConversationHit>` (`:190`) avec extraits (`ZChatMessageSnippet` `:123`). | limite 20 `:54`, requête ≥ 2 car. `:60` |
| `ZChatConversationPinPort` | `:405` | `setPinned` — **un seul verbe**, pas deux. | — |
| `ZChatConversationSharePort` | `:426` | `share` → `ZChatShareLink` (`:272`) ; `sharedConversation` → `ZChatSharedConversation` (`:339`), **lecture seule**. | — |
| `ZChatConversationLifecyclePort` | `:452` | `retire` / `restore` / `trimAfter` / `retireAll`. 🔴 **La suppression définitive en lot est refusée par conception** : seul le retrait réversible est porté. | — |
| `ZChatDictationPort` | `src/domain/capture/z_chat_capture_port.dart:262` | Dictée : `isAvailable` / `listen({localeId})` / `stop`. | — |
| `ZChatOcrPort` | `:322` | OCR : `isAvailable` / `recognize`. | `ZChatOcrSource` `:287` |
| **`ZUnreviewedText`** | `:175` | 🔴 La **relecture obligatoire rendue structurelle** : ce type **n'expose aucune `String`**, son unique sortie est un dépôt `void` dans un `ZChatReviewSink` (`:151`). Un hôte ne peut pas envoyer une dictée non relue par accident. | seuil « gros texte » 20 000 `:82` |
| `ZChatSpeechPort` | `src/domain/diffusion/z_chat_speech_port.dart:144` | Synthèse vocale. | débit 1.0 `:39` |
| **`ZChatSpeechChain`** | `:174` | La **chaîne de repli devient une donnée** : site unique du repli, échecs conservés. Un hôte qui a deux moteurs TTS n'écrit pas son `try/catch` en cascade. | — |

---

## 3. `zcrud_chat` — l'état réactif et les surfaces (361 canaux, 22 860 lignes)

Flutter-natif (`ChangeNotifier` / `ValueListenable`), zéro gestionnaire d'état, zéro dépendance
tierce.

### 3.1 Contrôleurs

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatController` | `src/presentation/z_chat_controller.dart:230` | Le cœur : tranches `ValueListenable` granulaires, `composer` **instance stable** (`:~334`), `ZChatRequestToken` par requête, reprise d'un flux interrompu **sous la même identité** (aucun rejeu du tour), et **un unique point d'entrée pour tous les verbes** (`runAction`). | `maxResumeAttempts = 2` |
| ↳ seam `lifecycle:` | `z_chat_controller.dart:~259` | Présent ⇒ **édition rejouée et régénération natives** (élagage `trimAfter`, troncature locale, nouveau tour par le même cycle) ; absent ⇒ délégué à `actionExecutor`. | `null` (inerte) |
| ↳ seam `routeResolver:` | `z_chat_controller.dart:~260` | Chaque requête est soumise **après les réglages et AVANT toute trace dans le fil** — un refus publie `lastFailure` typé et laisse la saisie intacte. | `null` (inerte) |
| ↳ `previewEditImpact` | `z_chat_controller.dart` | L'impact d'une édition **avant** de la confirmer. | — |
| `ZChatNotebookController` | `src/presentation/notebook/z_chat_notebook_controller.dart:211` | **Compose** `ZChatController` ; tient l'occupation ; expose **une `ValueListenable<ZChatArtifactStatus>` par (message, artefact)** ; dérive les verbes du registre (aucun pour `role == user`, aucun en `readOnly`) ; chaque verbe passe par `runAction` ; persiste par `ZChatTranscriptPort`. | — |
| **`ZChatTranscriptBinding`** | `src/presentation/z_chat_transcript_binding.dart:46` | 🔴 v3.11.0 — « flux → messages, envoi → persistance » **écrite une fois** : abonnement unique, `attach` au premier instantané seulement, `append`/`update` quand un tour se règle, `Left` publiés, `dispose` qui annule. | — |
| **`ZChatConversationController`** | `src/presentation/z_chat_conversation_controller.dart:37` | Le symétrique du Notebook pour la conversation simple : `ZChatController` + transcript. Sans `transcript`, comportement identique sur `initialMessages`. | — |
| `ZChatSettingsController` | `src/presentation/settings/z_chat_settings_controller.dart:103` | Les réglages **hors** de `ZChatController` ; `send(settings:, corpusScope:)` les transporte **après** le builder de l'hôte — aucun hôte ne peut les perdre en silence. | `ZChatSettingsPreset` `:60` |
| `ZChatToolController` | `src/presentation/tools/z_chat_tool_controller.dart:107` | L'état réactif du `ZChatToolCatalog` en **tranches granulaires** : structure de feuille, structure de bande, **une tranche par entrée**, comptage agrégé, recherche. Une tuile n'écoute que la sienne (AD-2). | `ZChatToolSheetStructure` `:78`, `ZChatToolSectionSlice` `:39` |
| `ZChatRouteSession` | `src/presentation/routing/z_chat_route_session.dart:194` | Le routeur courant et ses routes en tranches (`routerId`, `router`, `routeOf(k)` **stable**, `overrideOf(k)`, `catalogFailure`), `selectRouter`/`refresh`/`setModelOverride`, et des résolveurs **purs** `resolve`/`resolveArtifact` — **aucun membre n'envoie**. | 🔴 `gate = ZDenyAllChatRouteGate()` (`:202`) |
| `ZChatAttachmentController` | `src/presentation/attachment/z_chat_attachment_controller.dart:64` | Cycle de vie d'une pièce jointe en tranches, `ZResult` sur chaque opération. | 5 pièces `:352`, 10 Mo `:355`, MIME `:362` |
| `ZChatCaptureController` | `src/presentation/capture/z_chat_capture_controller.dart:105` | Dictée + OCR, avec `acceptInto` rendant un `ZResult<Unit>` — **aucune `String` ne s'échappe** vers l'envoi. | `ZChatCaptureReviewBuffer` `:54` |
| `ZChatConversationSelection` / `ZChatGroupExpansion` | `conversation/z_chat_conversation_selection.dart:38`, `conversation/z_chat_group_expansion.dart:34` | Les deux contrôleurs fournis par l'hôte — **à créer hors de `build`**. | — |
| `ZChatDiffusionService` | `src/presentation/diffusion/z_chat_diffusion_service.dart:51` | La voix par la chaîne de repli du kernel ; l'export est délégué à `ZChatExportService`, jamais redéfini. | — |
| `ZChatPhase` / `ZChatStreamProgress` | `src/presentation/z_chat_stream_progress.dart:30, 52` | Progression **grossière**, volontairement séparée du texte à haute fréquence (AD-2). | — |
| `ZChatLiveLabels` | `src/presentation/z_chat_live_labels.dart:30` | Les annonces d'accessibilité, à repli **silencieux**. | `ZChatLiveLabels.none` |

### 3.2 Les deux écrans assemblés (livrés v3.6.0 / v3.8.0 / v3.11.0)

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| **`ZChatNotebookScreen`** | `src/presentation/view/z_chat_notebook_screen.dart:154` | 🔴 **L'écran de fil de travail entier, en une couche mince** : contrôleur créé dans `initState`, vue, créneau d'artefacts, composer, feuille d'outils, deux régions live, créneaux d'échec, créneau d'action globale, `readOnly`, session de routage — **58 paramètres nommés** (`:166-223`), chaque pièce remplaçable, échappatoire garantie vers `ZChatNotebookView`. | `ZChatUnsupportedActionExecutor`, `zChatConfirmWithoutDialog`, `submitPolicy.standard`, grille 3 colonnes |
| **`ZChatConversationScreen`** | `src/presentation/view/z_chat_conversation_screen.dart:96` | Le miroir pour la conversation simple : contrôleur créé une fois, vue, composer partagé, feuille, session de routage. `transcript:` fourni ⇒ le fil vient du dépôt et chaque tour y est écrit ; absent ⇒ `initialMessages` (arbre identique). | idem |
| `ZChatNotebookView` | `view/z_chat_notebook_view.dart:55` | La composition mince : identité **structurellement masquée**, actions par message exposées. | — |
| `ZChatConversationView` | `view/z_chat_conversation_view.dart:57` | La vue neutre : `ListView.builder`, région live, dépli inline. | — |
| `ZChatMessageTile` | `view/z_chat_message_tile.dart:62` | La tuile, avec créneaux `identityBuilder` / `actionsBuilder` (builders nullables, défauts inchangés). | `kZChatMinTapTarget = 48.0` `:53` |
| `zChatSettingsSheetOf` / `zChatRouteModelSlot` | `view/z_chat_route_assembly.dart:68, 39` | L'**assemblage commun du routage** sur les pièces partagées, utilisé par les deux écrans et offert à l'assemblage maison. | — |
| `ZChatNotebookLiveRegion` | `view/z_chat_notebook_screen.dart:682` | — | — |
| `zChatNotebookCollapsedMaxHeightOf` | `view/z_chat_notebook_screen.dart:90` | — | 250 dp `:80` / facteur 0,3 `:84` |

### 3.3 Composer (livré v3.6.0)

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatComposer` | `view/z_chat_composer.dart:139` | La zone de saisie partagée qui rend `ZChatController.composer` ; les deux surfaces la montent par la **même fabrique interne**. L'envoi passe **toujours** par `send()`. | créneaux nullables |
| `ZChatComposerSlot` / `SlotBuilder` | `:90`, `:131` | Les créneaux `leading` / `trailing` / `tools`, avec `submit` — le **site unique** d'envoi. | — |
| `ZDefaultChatComposer` | `view/z_default_chat_composer.dart:63` | L'**assemblage par défaut opt-in** des pièces ci-dessous. | opt-in |
| `ZChatComposerSurface` | `view/z_chat_composer_band.dart:186` | Le conteneur. | — |
| `ZChatComposerThinkingToggle` / `WebSearchToggle` | `:598`, `:705` | Les bascules réfléchir/internet **sur le même `ZChatSettingsController` que la feuille** — un état, deux surfaces. | — |
| `ZChatComposerToolsTrigger` + `CountBadge` | `:793`, `:892` | Déclencheur « outils » à badge `activeCount`. En compact le badge **remplace** le libellé. | `showToolsBadge = true` |
| `ZChatComposerStopTarget` | `:1193` | L'arrêt câblé sur le verbe existant `runAction(ZChatCancelAction)` — pas de nouveau chemin. | — |
| `ZChatComposerEditingBanner` | `:1264` | Le bandeau d'édition. | — |
| `ZChatComposerPickerTrigger` / `PickerAction` | `:297`, `:264` | Les sélecteurs à contrat opaque. | — |
| `ZChatComposerEffortSelector` | `:920` | — | — |
| `ZChatComposerDictationTrigger` | `:1371` | — | — |
| `ZChatComposerModelSelector` / `ZChatModelOption` | `view/z_chat_composer_model_selector.dart:119`, `:55` | Sélecteur de modèle à **contrat opaque**, menu par défaut, coche sur l'actif. | `ZChatModelMenuBuilder` `:107` |
| `ZChatComposerChrome` / `ChromeStyle` / `zChatComposerChromeOf` | `view/z_chat_composer_chrome.dart:55, 132, 211` | La chaîne **paramètre > jeton > référence** du chrome. | — |
| `ZChatComposerSendTarget` / `AnimatedHint` | `:290`, `:379` | — | — |
| **`ZChatComposerSubmitPolicy`** | `view/z_chat_composer_keys.dart:63` | La politique clavier déclarable, avec `resolve({platform, isWeb})` (`:96`). | 🔴 `enterSubmits` **+ `desktopAndWebOnly = true`** |
| `zChatComposerSubmitShortcuts` | `:126` | La table de raccourcis d'une politique résolue ; les combinaisons « nouvelle ligne » sont liées à `DoNothingAndStopPropagationTextIntent` — le paquet **n'écrit jamais** dans la saisie. | — |
| `ZChatComposerReference` | `view/z_chat_composer_reference.dart` | Les constantes de référence. | — |
| `kZChatBandSheetAssertMessage` | `src/presentation/z_chat_assembly_contract.dart:19` | Le contrat d'assemblage bande/feuille. | — |

### 3.4 Réglages, outils, routage — les adaptateurs déclaratifs

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatSettingsSheet` | `view/z_chat_settings_sheet.dart:322` | La feuille de réglages **utilisable telle quelle** (aucun builder requis), branchée au créneau `tools` du composer — le chemin par lequel les réglages atteignent réellement `send(settings:, corpusScope:)`. | — |
| `ZChatSettingsSlot` | `:263` | Le contexte d'une tuile : contrôleur, valeur **courante déjà lue** (le builder ne s'abonne pas), portée, catalogues. | — |
| `ZChatSettingsTileBuilder` / `EntryTileBuilder` | `:301`, `:309` | Rendre `null` ⇒ **aucun widget inséré** (AD-4). | — |
| `ZChatSettingsEntry` / `Section` | `view/z_chat_settings_entry.dart:262`, `:305` | Le **modèle d'entrées déclaratif** : nature ouverte (AD-4), une nature inconnue est simplement absente sans lever (AD-10). Les familles standard sont ré-exprimées dessus — **une seule voie de rendu**. | ids standard `:335-351` |
| `ZChatSettingsControl` + 5 cas | `:115, 122, 141, 169, 195, 218` | `Toggle`, `Scale`, `Select`, `Navigation`, `NumberBounded`. | kinds `:36-49` |
| `ZChatCorpusOption` / `ZChatSettingsHostOption` | `view/z_chat_settings_sheet.dart:214`, `:1560` | Les catalogues d'hôte. | — |
| **`zChatToolSettingsEntries` / `zChatToolSettingsSections`** | `tools/z_chat_tool_settings_adapter.dart:66`, `:51` | La projection du `ZChatToolCatalog` vers les entrées déclaratives — **aucune décision du domaine (visibilité, grisage, ordre, comptage) n'est reprise ici**. | — |
| `ZChatToolCustomControl` | `:38` | — | `ZChatToolTokenResolver` `:34` |
| **`zChatRouteSettingsEntries`** | `routing/z_chat_route_settings_adapter.dart:37` | Le choix du **modèle de repli par tâche** dans la feuille. | libellés d'hôte **obligatoires** ; préfixe `:31` |
| `ZChatRoutedStreamPort` | `routing/z_chat_routed_stream_port.dart:31` | Répartition `handlerId → providerId → routeName → fallback` ; un inconnu rend **un seul** `Left`. Ne résout ni ne gate. | — |
| `ZChatRoutedArtifactGenerationPort` | `routing/z_chat_routed_artifact_port.dart:25` | Idem pour les artefacts. | — |
| `zChatApplyRoute` / `zChatApplyArtifactRoute` | `routing/z_chat_route_session.dart:65`, `:96` | La résolution pure, réutilisable hors session. | — |
| `zChatTaskKeyOf` / `zChatArtifactTaskKeyOf` | `:53`, `:57` | 🔴 **La clé de tâche est `request.style.kind`** — c'est là que se branche le routage par route. | — |
| `zChatRouteDispatchIds` | `routing/z_chat_routed_stream_port.dart:25` | L'ordre de répartition, exposé. | — |
| `ZChatSettingsScaleTile` / `CapabilityTile` | `view/z_chat_settings_sheet.dart:1427`, `:1494` | Tuiles neutres réutilisables. | — |

### 3.5 Artefacts — de la déclaration au rendu

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatArtifactSpec` | `view/z_chat_artifact_spec.dart:239` | Clé **opaque**, glyphe, libellé **déjà localisé**, trois lectures d'état sur le message brut (présence `:70`, compte `:75`, occupation `:81`) et une liste de verbes. Le socle **ne connaît ni `mindmap` ni `flashcards`** : il connaît une clé. | — |
| `ZChatArtifactAction` | `:110` | Le verbe, sa condition de visibilité, sa **teinte propre**, son rappel — l'**ordre déclaré** est préservé. | `zChatArtifactWhenAbsent`/`WhenPresent` `:95`, `:99` |
| `ZChatArtifactBar` | `view/z_chat_artifact_bar.dart:172` | Rend l'état : glyphe **teinté si le contenu existe** (c'est un ÉTAT, pas un style), pastille **non interactive**, menu des verbes dont la condition tient, confirmation d'un verbe destructeur, état **annoncé**. Débordement géré par `Wrap` (9 artefacts → 6+3 sur 360 dp). | grille **3 colonnes** `:140` |
| `ZChatArtifactMenuBuilder` | `:160` | La **présentation** du menu est injectable, relayée par la vue notebook. Le rappel reçoit **exactement les verbes visibles** et un sélecteur qui passe par le **même chemin** que le rendu par défaut : une présentation injectée ne peut ni contourner la confirmation, ni faire réapparaître un verbe écarté. Un rappel qui lève ⇒ menu du socle (AD-10). | — |
| `zChatArtifactSpecOf` / `zChatArtifactSpecsOf` | `view/z_chat_artifact_binding.dart:129`, `:184` | La dérivation **déclaration → rendu** : lit l'état dans le contrôleur et résout les jetons par les résolveurs de l'hôte. **Jeton non résolu ⇒ glyphe/couleur absents, libellé vide** — rien d'inventé. | — |
| `zChatNotebookArtifactsSlot` | `view/z_chat_artifact_binding.dart:202` | Le créneau prêt à poser : la barre de chaque message, sous l'écouteur de **ses seules tranches**. | — |
| `ZChatArtifactResolvers` | `view/z_chat_artifact_binding.dart:51` | Les trois résolveurs de jetons (icône `:38`, libellé `:42`, accent `:46`). | `.none` |
| `ZChatArtifactVerbAction` | `notebook/z_chat_notebook_controller.dart:132` | Le verbe tel que le contrôleur le dérive. | — |
| Charge utile d'action | `notebook/z_chat_notebook_controller.dart:113-125` | `kZChatArtifactVerbPrefix` + 4 clés : les capacités notebook s'exécutent par `runAction(ZChatCustomAction(...))`, **sans nouveau chemin d'exécution**. | — |

### 3.6 Rendu, coquille, export

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatRenderer` | `render/z_chat_renderer.dart:44` | Le port de rendu de bloc, sur le patron de `ZListRenderer` (AD-8). **`null` ⇒ garder le rendu neutre.** | — |
| `ZChatRendererScope` / `zResolveChatBlock` | `render/z_chat_renderer_scope.dart:24` | L'injection et la chaîne de résolution complète (seam d'hôte puis repli neutre), **qui ne lève jamais** (AD-10). | — |
| `ZChatShellRenderer` / `Scope` / `zResolveChatShell` | `render/z_chat_shell_renderer.dart:53`, `render/z_chat_shell_renderer_scope.dart:28` | Le même patron pour le **cadre** : un backend de coquille (Syncfusion) se branche sans que `zcrud_chat` ne dépende de rien. | — |
| `zChatReportSeamFailure` + 9 constantes de seam | `render/z_chat_seam_failure.dart:50`, `:15-43` | Un seam d'hôte qui lève est **rapporté nommément** au lieu de casser l'arbre. | — |
| `ZChatAccessibleTextScope` | `render/z_chat_accessible_text_scope.dart:32` | Le résolveur de texte accessible injecté par l'arbre. | — |
| **`ZChatTileShell`** | `view/z_chat_tile_shell.dart:200` | La coquille **déclarée** d'une tuile : carte, filet, coiffe par le sujet du tour (`topicOf`), `topicTrailing` (la place des commandes de la carte), style du bouton de dépli, format d'horodatage par résolveur d'hôte. 🔴 **`null` ⇒ arbre strictement inchangé** — rien n'est peint tant qu'elle n'est pas déclarée. | `const ZChatTileShell()` = « la référence, telle quelle » |
| `ZChatTileShellStyle` / `zChatTileShellStyleOf` / `ZChatTileToggleStyle` | `:348`, `:428`, `:116` | La chaîne de résolution de la coquille. | — |
| `zChatPrecedingRequestTopic` / `zChatReferenceTimestamp` | `:85`, `:102` | Résolveurs prêts à l'emploi. | — |
| **`ZChatExportService`** | `export/z_chat_export_service.dart:129` | L'export **agrégé d'une conversation entière** dans **quatre formats textuels**, sans aucune dépendance tierce : `exportConversation` (`:149`), `shareConversation` (`:220`), `suggestedFileName` (`:260`). | — |
| `ZChatExportFormat` | `export/z_chat_export_format.dart:10` | markdown / plainText / html / **references** (les seules citations, dédupliquées) / pdf, avec `mimeType` et `fileExtension`. | — |
| `ZChatPdfComposer` / `ZChatExportSink` | `export/z_chat_export_ports.dart:37`, `:70` | Les deux coutures : le PDF et la destination système. Le service de partage n'est **jamais dupliqué** dans le socle. | — |
| `ZChatExportSelection` / `ZChatExportVocabulary` | `export/z_chat_export_service.dart:40`, `:85` | Périmètre et libellés d'hôte. | — |
| `ZChatBlockView` | `view/z_chat_block_view.dart:33` | Le rendu neutre d'un bloc. | — |
| `ZChatAttachmentStrip` | `view/z_chat_attachment_strip.dart:46` | Les pièces en attente, cibles ≥ 48 dp, positionnement directionnel. | — |
| `ZChatCaptureBar` / `CaptureAction` / `CaptureReviewField` | `view/z_chat_capture_bar.dart:31`, `:104`, `view/z_chat_capture_review_field.dart:42` | La surface de relecture obligatoire. | — |
| `ZChatDiffusionBar` | `view/z_chat_diffusion_bar.dart:35` | — | — |

### 3.7 Liste de conversations

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatConversationList` | `view/z_chat_conversation_list.dart:146` | `ListView.builder` à **trois états distincts** (l'erreur est testée **avant** le chargement), squelette annoncé, vide à deux variantes, tri exposé, **pagination par curseur**, sélection multiple, groupes à clé opaque repliés par contrôleur externe. | `zChatDefaultConversationMatcher` `:61` |
| `groupActionsBuilder` / `ZChatGroupAction` | `:131`, `:105` | Une action **à l'échelle du groupe** (« créer dans CE dossier »), recevant le groupe exact. Le socle **ne fabrique aucune action**. | **aucune action** |
| `ZChatConversationTile` | `view/z_chat_conversation_tile.dart:109` | Titre à `maxLines` paramétrable, horodatage relatif **localisable dont le champ source et le formateur sont injectables** (`:44`, `:52`, `:56`), pastille teintable, badges par prédicat (`:85`), `trailing`, description d'accessibilité complète. | — |
| `zChatConversationActions` | `view/z_chat_conversation_actions.dart:109` | Les descripteurs d'action, **absents quand leur callback est nul** — les ports de conversation du kernel deviennent câblables sans qu'aucun verbe ne soit codé en dur. | clés `:198` |
| `ZChatHighlightedText` / `zChatHighlightRanges` | `view/z_chat_highlight.dart:76`, `:55` | Le surlignage partagé par les surfaces de recherche. | — |
| `ZChatConversationTileConfig` | `view/z_chat_conversation_list.dart:398` | — | — |

### 3.8 Libellés et skin

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| ~140 clés `kZChatLabel*` | `view/z_chat_labels.dart:24-425` | Toute chaîne du socle passe par une clé résolue par `ZcrudLabels`. | `kZChatLabelFallbacks` `:539` |
| `kZChatLabelKeys` | `:429` | La **liste exhaustive** — un hôte peut vérifier sa couverture de traduction par un test. | — |
| `zChatLabel` / `zChatCountLabel` / `zChatDefaultRelativeTime` | `:706`, `:649`, `:672` | — | `{n}` `:646` |
| `ZChatNotebookSkin` / `ZChatNotebookStyle` | `view/z_chat_notebook_skin.dart:51`, `:162` | Le skin du notebook, **opt-in** : aucune vue ne le monte d'elle-même. | — |
| `ZChatNotebookCapabilityStyle` + 9 clés de capacité | `view/z_chat_notebook_reference.dart:110`, `:157-181` | **Neuf** capacités de référence (mindmap, flashcards, story, humour, classroom, summary, elaboration, examples, poem) avec leurs clés publiques — des **défauts surchargeables**, pas une liste fermée. | référence auditée (exception FR-26 encadrée) |

---

## 4. `zcrud_chat_material` — le skin Material (39 canaux, 2 807 lignes)

Puits du graphe. Chaque builder est **indépendant** : l'hôte en monte un, plusieurs ou aucun ;
un réglage absent (contrôleur non fourni, catalogue vide) fait rendre `null`, **jamais une
affordance inerte**. Aucun libellé n'est écrit ici (garde de source) — tout vient de l'hôte.

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient |
|---|---|---|
| `ZChatMaterialComposer` | `src/presentation/z_chat_material_composer.dart:32` | Le composer Material assemblé sur les créneaux du socle. |
| **`ZChatMaterialSettingsSheet`** | `z_chat_material_settings_sheet.dart:78` | 🔴 v3.7.0 — **un builder Material pour chacune des neuf familles** de `ZChatSettingsSheet` (`headerBuilder`, `presetsBuilder`, `responseLengthBuilder`, `lengthBiasBuilder`, `computeBudgetBuilder`, `revealThinkingBuilder`, `capabilitiesBuilder`, `corpusBuilder`, `unknownEntryBuilder` — `:89-97`), plus `entryBuilders` / `kindBuilders` / `sectionBuilders` par id (`:98-100`). Un builder d'hôte **gagne** sur le défaut. |
| `ZChatMaterialSettingsLabels` | `z_chat_material_settings_labels.dart` | Tous les libellés viennent de l'hôte ; **libellé absent ⇒ affordance absente**. |
| `ZChatMaterialSettingsReference` | `z_chat_material_settings_reference.dart` | La géométrie, sans littéral dans les widgets. |
| **`ZChatMaterialToolsSheet`** | `z_chat_material_tools_sheet.dart:40` | v3.6.0 — `DraggableScrollableSheet`, en-tête titre + badge + réinitialiser + fermer, en-tête **« Actifs » en puces retirables**, recherche conditionnelle, sections séparées **entre** elles (aucun index magique). |
| `ZChatMaterialToolTile` | `z_chat_material_tool_tile.dart:52` | **Une forme par nature** : `SwitchListTile` à sous-titre d'**état**, cycle à badge de cran, `SegmentedButton`, curseur à repères, `FilterChip` + puce « tout », bouton. Entrée désactivée **grisée avec sa raison**, jamais masquée. |
| `ZChatMaterialToolLabels` | `z_chat_material_tool_labels.dart:25` | Idem : absent ⇒ absent. |
| `zChatMaterialResponseLengthChips` / `LengthBiasChips` / `PresetChips` | `z_chat_material_settings_chips.dart:109, 166, 219` | `ChoiceChip` en `Wrap`. |
| `ZChatMaterialChoiceChips<T>` / `ZChatMaterialChoice<T>` | `:46`, `:23` | La primitive générique. |
| `ZChatMaterialCorpusChips` | `z_chat_material_corpus_chips.dart` | `FilterChip` avec puce « Tous » et **entrée indisponible grisée avec sa raison**. |
| `zChatMaterialSettingsHeader` / `ZChatMaterialSettingsSectionHeader` | `z_chat_material_settings_header.dart:27, 104` | Titre + réinitialiser + fermer ; titres de section `titleSmall` en couleur de rôle. |
| `ZChatMaterialSettingsSwitches` | `z_chat_material_settings_switches.dart` | `SwitchListTile` à **sous-titre d'état fourni par l'hôte**. |
| `zChatMaterialSendFab` / `ZChatMaterialSendFab` | `z_chat_material_send_fab.dart:32, 38` | Le FAB d'envoi ; l'envoi passe par `ZChatComposerSlot.submit`. |
| `zChatMaterialEffortChips` | `z_chat_material_effort_chips.dart:26` | Les chips d'effort. |
| `zChatMaterialAttachmentChips` | `z_chat_material_attachment_chips.dart:26` | Les chips de pièces jointes. |
| `ZChatMaterialBadge` / `ToolsBadge` / `ToolCatalogBadge` | `z_chat_material_badge.dart:25, 69, 104` | Les trois badges. |
| `ZChatMaterialBudgetSlider` / `LabelledSlider` | `z_chat_material_budget_slider.dart`, `z_chat_material_labelled_slider.dart` | Le curseur de budget labellisé, et sa primitive extraite. |
| `ZChatMaterialUnknownEntryTile` | `z_chat_material_settings_sheet.dart:50` | Le repli d'une entrée déclarative de nature inconnue. |

**Garde v3.7.0** : aucun `ZChatTool*` dans les builders des familles standard — un réglage
standard ne se redéclare pas comme outil d'hôte (deux états pour un même réglage, dont un seul
part dans la requête).

---

## 5. `zcrud_chat_markdown` — le rendu riche (3 canaux, 301 lignes)

Satellite **opt-in** : un consommateur qui ne le monte pas ne tire aucune dépendance riche.
Le barrel n'exporte **aucun symbole de l'éditeur sous-jacent** et le paquet ne déclare aucune
arête directe vers lui — il n'atteint Quill qu'à travers l'API neutre de `zcrud_markdown`.

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient | Défaut |
|---|---|---|---|
| `ZChatMarkdownRenderer` | `src/presentation/z_chat_markdown_renderer.dart` (classe) | Un backend de `ZChatRenderer` : Markdown + LaTeX dans les bulles. | — |
| `ZChatMarkdownStreamingMode` | idem | Le régime de rendu pendant le flux. | — |
| `kZChatMarkdownDefaultRoles` | idem | Les rôles rendus par défaut. | — |
| `styleSet:` | `:153` / champ `:195` | 🔴 v3.4.0 — **le seul canal permettant de viser séparément un titre, le gras, l'italique, la citation ou le code**. Le style global ne distingue pas ces axes ; le thème de l'app viserait tout l'écran. Un jeu **partiel** est légitime. | `null` ⇒ rendu strictement d'avant |
| `textScaleFactor:` | `:154` / champ `:205` | ⚠️ v3.4.0 — l'échelle du texte rendu. | `null` |

---

## 6. `zcrud_chat_syncfusion` — la frontière Syncfusion et le fil IFFD (22 canaux, 1 022 lignes)

`syncfusion_flutter_chat` est une arête de **ce seul paquet** du monorepo.

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient |
|---|---|---|
| `ZSfAssistShellRenderer` | `src/presentation/z_sf_assist_shell_renderer.dart:65` | Un **backend du port** `ZChatShellRenderer`, jamais une vue parallèle : il rend le cadre `SfAIAssistView` et **rappelle la fabrique de tuiles du socle** — la région live, le dépli inline et `ZChatMessageTile` sont conservés. |
| `ZSfAssistLabels` | `src/presentation/z_sf_assist_labels.dart` | Les libellés du cadre. |
| `ZIffdLexer` | `src/data/z_iffd_lexer.dart:98` | Découpe le flux brut en segments : texte décodé, balises. |
| `ZIffdSegment` (sealed) / `TextSegment` / `TagSegment` | `:38`, `:43`, `:55` | Les segments typés. |
| `ZIffdStreamNormalizer` | `src/data/z_iffd_stream_normalizer.dart:53` | Classe les segments en **canaux** et produit les événements typés du kernel. 🔴 Une erreur écrite **en clair par le serveur, dans le même canal que la réponse**, devient un `Left(ZChatProviderFailure)` — jamais un message de conversation (AD-5). |
| `ZIffdTextStreamPort` | `src/data/z_iffd_stream_port.dart:40` | Le tout exposé comme un `ZChatStreamPort`. **C'est le port qu'IFFD consomme.** |
| `ZIffdRawStreamOpener` | `:33` | La couture d'ouverture — l'hôte ouvre, le socle normalise. |
| `ZIffdChannel` / `ZIffdFailureCodes` | `src/data/z_iffd_wire.dart:38`, `:100` | Le vocabulaire du fil. |

---

## 7. `zcrud_chat_firestore` — le catalogue de routeurs persisté (2 canaux, 246 lignes)

Livré **v3.8.0**, 2026-08-23. Puits du graphe : dépend de `zcrud_core`, `zcrud_chat_kernel`,
`zcrud_firestore` ; **rien n'en dépend**, et `zcrud_firestore` ne connaît pas le chat.

| Canal | `fichier:ligne` | Ce qu'un hôte en obtient |
|---|---|---|
| **`buildChatRouterFirestoreRepository`** | `src/data/z_chat_router_firestore_repository.dart:76` | Un `ZRepository<ZChatRouter>` complet sur le repository Firestore générique — `kind: kZChatRouterKind`, **codec du noyau**, point d'accroche d'un **codec legacy** (`toCanonical` en amont du décodage, `toLegacy` en aval de l'encodage), sémantique de suppression choisie par l'hôte (`ZDeletionSemantics.absentMeansAlive` pour une collection **sans `is_deleted`**), `legacyDeletedKey`, `extensionParser`, `logger`. |
| `zChatRouterShapeIssue` | `:134` | Prédicat **défensif** appliqué avant le décodage : un document sans aucune clé du schéma, ou dont une clé porte un type illisible, est **écarté et journalisé** au lieu de devenir un routeur vide actif. |
| `ZChatRouterMapCodec` | `:30` | Le type des deux transformations d'un codec legacy. |

> **GREP NÉGATIF MONTRÉ.** `grep -rn 'zcrud_chat_firestore' /home/zakarius/DEV/iffd --include='*.yaml' --include='*.dart'` → **aucune ligne**. Une seule occurrence dans tout le dépôt, dans une liste de paquets : `docs/migration-data-crud/04-navigation-et-pages.md:6`. Le paquet n'est **ni déclaré ni surchargé** dans `iffd/pubspec.yaml`.

---

## 8. Jetons de thème `chat*` — 20 déclarés, **1 posé par l'hôte**

Tous dans `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart`, tous **nullables**
(`null` ⇒ référence).

| Jeton | Ligne | Posé par IFFD |
|---|---|---|
| `chatBubbleWidthFactor` | 1852 | non |
| `chatRequestBubbleRadius` | 1855 | non |
| `chatResponseBubbleRadius` | 1859 | non |
| `chatBubbleShowAuthorAvatar` | 1862 | non |
| `chatBubbleShowAuthorName` | 1865 | non |
| `chatBubbleShowTimestamp` | 1868 | non |
| `chatToolAccentColor` | 1871 | non |
| `chatCapabilityAccents` | 1879 | non |
| `chatBusyPalette` | 1882 | non |
| `chatComposerSendTargetSize` | 1899 | non |
| `chatComposerSendScaleIdle` | 1907 | non |
| `chatComposerSendScaleActive` | 1912 | non |
| `chatComposerSendScaleDuration` | 1916 | non |
| `chatComposerMobileBreakpoint` | 1926 | non |
| `chatComposerHintRotationPeriod` | 1930 | non |
| `chatComposerHintSwitchDuration` | 1934 | non |
| **`chatComposerActiveAccent`** | 1949 | **oui — 2 sites** |
| `chatResponseLengthAccents` | 1960 | non |
| `chatSelectedEmphasisWeight` | 1969 | non |
| `chatSelectedEmphasisDecoration` | 1976 | non |

Mesure : boucle `grep -rn "\b<jeton>\b" iffd/lib/` sur les vingt noms.

Mécanisme associé, hors périmètre mais consommé par le chat : `ZColorCycle`
(`zcrud_core/lib/src/presentation/theme/z_color_cycle.dart`) — l'animation d'occupation
**par artefact**, qui consomme `chatBusyPalette`. Sous « Réduire les animations », aucun
contrôleur n'est créé et le glyphe se fige sur la première teinte : l'occupation reste
perceptible par la teinte **et** par l'annonce.

---

## 9. Assemblages livrés que l'hôte n'a pas consommés — vérifiés un par un

| Assemblage | Livré | État chez IFFD | Preuve |
|---|---|---|---|
| **`ZChatNotebookScreen`** | v3.6.0, 2026-08-23 | 🔴 **jamais monté** | `grep -rn 'ZChatNotebookScreen' /home/zakarius/DEV/iffd --include='*.dart'` → **0 ligne**. Seule occurrence du dépôt : `docs/plan-notebook-externalisation.md:812`, où l'hôte chiffre lui-même « **~1 900 lignes à retirer** ». L'hôte assemble à la main : `lib/ai_assistant/zcrud/notebook_zcrud.dart` **926 lignes** + `notebook_page_zcrud.dart` **376 lignes**. Son portage notebook date du **2026-08-22** (`e7ab655`), soit **la veille** de la livraison de l'écran. |
| `ZChatNotebookController` | v3.6.0 | **consommé** | `notebook_ports_iffd.dart:187, 207` ; `notebook_page_zcrud.dart:30, 137`. Mais `notebook_zcrud.dart` monte encore `ZChatController` nu + `ZChatNotebookView` — **deux chemins coexistent**. |
| `ZChatConversationScreen` | v3.8.0 / v3.11.0 | **consommé** | `assistant_chat_zcrud_mount.dart:26`. |
| `ZChatTranscriptBinding` / `ZChatConversationController` | v3.11.0 | consommés **indirectement** | Nommés seulement en commentaire (`assistant_chat_zcrud_mount.dart:5-6`) ; `ZChatConversationScreen(transcript:)` les compose en interne. |
| **`$ZChatRouterFieldSpecs` + `registerZChatRouter`** | v3.8.0 | 🔴 **jamais consommés** | `grep -rn 'ZChatRouterFieldSpecs\|registerZChatRouter\|kZChatRouterKind' /home/zakarius/DEV/iffd/lib/` → **0 ligne**. L'hôte écrit à la main **1 014 lignes** de formulaire de routeur : `lib/src/presentation/features/ai_routers/zcrud/ai_router_zcrud_edition.dart` (685) + `ai_router_sub_list_seams.dart` (329). |
| `buildChatRouterFirestoreRepository` | v3.8.0 | 🔴 **paquet non déclaré** | cf. § 7. L'hôte décode ses routeurs à la main : `lib/ai_assistant/zcrud/notebook_route_catalog_iffd.dart` (106 lignes), par `ZChatRepositoryRouteCatalogSource` + forme de catalogue. |
| **`ZChatToolCatalog` / `ZChatToolController` / `zChatToolSettingsEntries` / `ZChatMaterialToolsSheet`** | v3.6.0 | 🔴 **aucun site** | `grep -rn 'ZChatToolCatalog\|ZChatToolController\|zChatToolSettingsEntries\|ZChatMaterialToolsSheet\|ZChatToolEntry' /home/zakarius/DEV/iffd/lib/` → **0 ligne**. La feuille d'outils déclarative entière est inconsommée. |
| `zChatRouteSettingsEntries` | v3.8.0 | 🔴 **aucun site** | 0 ligne. |
| `ZChatComposerSubmitPolicy` | v3.6.0 | 🔴 **aucun site** | 0 ligne — l'hôte prend donc le **défaut** (Entrée envoie sur bureau/Web). |
| `ZChatExportService` (4 formats + PDF) | antérieur | 🔴 **aucun site** | 0 ligne. |
| `ZChatAttachmentController` | antérieur | 🔴 **aucun site** | 0 ligne. |
| `ZChatCaptureController` / `ZUnreviewedText` (dictée, OCR) | antérieur | 🔴 **aucun site** | 0 ligne. |
| `ZChatSpeechChain` / `ZChatDiffusionService` | antérieur | 🔴 **aucun site** | 0 ligne. |
| `ZChatSseStreamPort` / `zChatSseLines` | v3.6.0 | 🔴 **aucun site** | 0 ligne (l'hôte est sur `ZIffdTextStreamPort`). |
| Ports de conversation (`Search` / `Pin` / `Share` / `Lifecycle`) | antérieur | 🔴 **aucun site** | `grep -rn 'ZChatConversationSearchPort\|ZChatConversationPinPort\|ZChatConversationSharePort\|ZChatConversationLifecyclePort' iffd/lib/` → 0 ligne. Sans `lifecycle`, l'édition rejouée et la régénération restent **déléguées à l'exécuteur de l'hôte** au lieu d'être natives. |
| `ZChatArtifactBar` / `zChatNotebookArtifactsSlot` | v3.2.0 / v3.6.0 | 🔴 **aucun site direct** | 0 ligne. L'hôte utilise `ZChatArtifactSpec` (14 citations) et a son propre rendu de menu : `notebook_artifact_menu_iffd.dart` (379) + `notebook_artifact_menu_render_iffd.dart` (103) + `notebook_artifact_actions_iffd.dart` (488). |

Pour cadrage : le fichier legacy `lib/ai_assistant/screens/chatbot_conversation_screen.dart`
pèse **5 356 lignes** et n'a **aucune bascule de QA** — les 52 entrées de
`z_qa_flags.dart` couvrent `chatMessageTile` (`:450`), `chatConversationList` (`:459`),
`chatConversationTile` (`:469`), `chatConversationEdition` (`:478`), `notebook` (`:496`),
mais **pas l'écran de conversation lui-même**.

---

## 10. Pièges — ce qui existe mais n'agit que sous condition

Classés **fait mesuré** vs **soupçon**.

### Faits mesurés

1. 🔴 **Le gate de route refuse par défaut.** `ZChatRouteSession({gate = ZDenyAllChatRouteGate()})`
   (`routing/z_chat_route_session.dart:202`) ; `ZDenyAllChatRouteGate.canRoute` rend toujours
   `Left(ZChatProviderFailure(code: upgradeRequired))`
   (`kernel/domain/route/z_chat_route_gate.dart:31-47`). **Déclarer un catalogue sans gate, c'est
   tout refuser** — et le refus est silencieux du point de vue de l'utilisateur (il publie
   `lastFailure`, pas une exception). Un hôte qui n'a pas de gouvernance doit passer
   `ZAllowAllChatRouteGate` explicitement.

2. ⚠️ **`ZChatMarkdownRenderer.textScaleFactor` est ABSOLU.** Il **remplace** l'échelle ambiante
   au lieu de s'y multiplier (`z_chat_markdown_renderer.dart:205`, et le CHANGELOG v3.4.0 le dit
   en toutes lettres). Un hôte qui veut composer avec l'échelle d'accessibilité du système doit
   **multiplier lui-même avant de la passer** — l'ignorer écrase le réglage d'un utilisateur
   malvoyant sans que rien ne le signale.

3. ⚠️ **`ZChatComposerSubmitPolicy` ne s'applique pas sur tactile.** `desktopAndWebOnly = true`
   par défaut (`view/z_chat_composer_keys.dart:76`) ; `resolve()` (`:96-111`) rend `none` sur
   android/iOS/fuchsia. Le filtrage porte sur la **plateforme**, jamais sur la largeur — une
   fenêtre étroite sur un bureau garde son clavier physique. Un hôte qui teste sur mobile
   conclura à tort que le canal est inerte.

4. ⚠️ **`ZChatTileShell` : `null` ⇒ rien.** « Le rendu de référence est le défaut **de la
   référence**, servi quand la coquille est déclarée — jamais le défaut du paquet »
   (CHANGELOG v3.3.0). Un hôte qui lit la dartdoc de `ZChatTileShell` peut croire à un rendu
   par défaut qu'il n'obtiendra pas sans écrire `shell: const ZChatTileShell()`.

5. ⚠️ **`borderWidth: 0` est la seule façon d'obtenir une coquille sans cadre**
   (`view/z_chat_tile_shell.dart:~226`). `null` ne signifie pas « pas de filet », mais
   « référence ».

6. ⚠️ **Défaut de rendu changé en v3.4.0** : le filet borne désormais le **contenu**, plus les
   commandes — hauteur mesurée passée de **132 dp à moins de 44 dp** sur un message court à barre
   de 96 dp. **Un hôte sans coquille déclarée rend un arbre strictement inchangé** ; un hôte qui
   en déclare une voit son rendu bouger.

7. ⚠️ **Défaut de couleur changé en v3.5.0** : le libellé d'une pastille de compte dérive
   désormais du rôle **premier plan d'erreur** (clair `#D6D6D6 → #FFFFFF`, sombre
   `#535353 → #601410`). Un hôte qui surcharge la couleur d'erreur **sans** surcharger son premier
   plan obtient un couple désaccordé, rattrapé par le plancher 4,5:1. Pour le rendu exact attendu,
   **surcharger les deux rôles ensemble**.

8. ⚠️ **Le menu d'artefact par défaut est une GRILLE depuis v3.5.0** (3 colonnes,
   `kZChatArtifactMenuCrossAxisCount = 3`, `view/z_chat_artifact_bar.dart:140`). Passer **1**
   retrouve la disposition en colonne d'avant.

9. ⚠️ **Changements de défaut v3.6.0, pour un hôte passif** : badge d'outils **visible**
   (`showToolsBadge = true`) ; Entrée **envoie** sur bureau/Web ; l'identifiant du partiel devient
   `<requestId>/reply` ; 4 dp devant la cible de retrait de pièce jointe. Un hôte qui
   **compensait** (raccourci clavier maison, comptage à côté, recherche du partiel par
   `requestId`) doit **retirer sa compensation**.

10. ⚠️ **`ZChatCorpusScope` nulle ⇒ `audit` toujours satisfait**
    (`kernel/domain/ai/z_chat_corpus_scope.dart:139`). L'audit ne prouve rien si la portée n'est
    pas déclarée — et `ZChatSource.corpus` n'est qu'un **libellé** : c'est `corpusKey` qui se
    compare (`:167`).

11. ⚠️ **Rupture compilée v3.9.0** : `kZChatArtifactProviderIdKey` **retiré** ;
    `extra['provider_id']` n'est plus ni écrit ni lu — lire `request.providerId`
    (`kernel/domain/notebook/z_chat_artifact_generation_port.dart:142`).

12. ⚠️ **Précédence d'effort changée en v3.9.0** : sans réglages,
    `base.computeEffort ?? route ?? racine` — **la route ne recouvre plus un budget explicite** ;
    avec réglages, la feuille reste un remplacement. Un hôte qui comptait sur l'ancienne
    précédence verra son effort changer sans rien avoir touché.

13. ⚠️ **`ZChatMaterial*Labels` : libellé absent ⇒ affordance absente**, jamais un libellé
    par défaut. Un hôte qui oublie une clé perd le bouton **silencieusement**.

14. ⚠️ **`zChatRouteSettingsEntries` exige des libellés d'hôte** — c'est écrit « libellés hôte
    obligatoires » dans le barrel (`zcrud_chat.dart:110`). Même conséquence.

15. ⚠️ **`zChatArtifactSpecOf` : jeton non résolu ⇒ glyphe et couleur absents, libellé vide**
    (`view/z_chat_artifact_binding.dart:129`). Le socle **refuse de fabriquer** ce que les
    résolveurs de l'hôte ne rendent pas — comportement voulu, mais qui se lit comme un bug à
    l'écran.

16. ⚠️ **Le régime `RTL` de Syncfusion a déjà cassé un rendu** : `getOuterPath(bounds)` est appelé
    **sans `TextDirection`**, donc un rayon directionnel non résolu **lève** et le paint
    s'interrompt **avant de peindre l'enfant** (CHANGELOG `zcrud_chat_syncfusion` v3.0.0).
    Corrigé dans le socle, mais c'est la classe de panne à surveiller sur tout nouveau backend de
    coquille.

17. ⚠️ **`ZChatConversationLifecyclePort` ne porte pas de suppression définitive en lot** — c'est
    un refus de conception (`kernel/domain/conversation/z_chat_conversation_ports.dart:452`,
    barrel `zcrud_chat_kernel.dart:81-84`). Un hôte qui a besoin d'un « vider la corbeille »
    devra le porter lui-même ou demander une extension.

### Soupçons (à confirmer par les agents de confrontation, non mesurés ici)

- **Soupçon A — la dartdoc de `ZChatNotebookScreen` promet une réactivité qu'elle borne.** Le
  commentaire du constructeur (`:157-165`) dit que **18 paramètres sont « lus une fois »** à la
  création du contrôleur (dont `streamPort`, `transcript`, `routeSession`, `buildRequest`), et que
  seuls `readOnly` et `toolCatalog` sont suivis. Un hôte qui change de `routeSession` ou de
  `streamPort` en cours de vie **sans changer la `key`** n'obtiendra rien, sans avertissement au
  runtime. Je n'ai pas exécuté le scénario.

- **Soupçon B — deux chemins notebook coexistent chez l'hôte.** `notebook_zcrud.dart` (926 l.)
  monte `ZChatController` + `ZChatNotebookView` ; `notebook_page_zcrud.dart` (376 l.) monte
  `ZChatNotebookController`. Le plan de l'hôte
  (`docs/plan-notebook-externalisation.md:793`) relève lui-même « je branchais `routeResolver` sur
  `ZChatController` nu, alors que `ZChatNotebookController`… ». Si les deux chemins sont vivants,
  le `routeResolver` ne s'applique **que sur l'un des deux**. Je n'ai pas tracé lequel est monté à
  l'exécution.

- **Soupçon C — `ZChatSettingsSheet` fait 2 046 lignes** (`view/z_chat_settings_sheet.dart`),
  soit le plus gros fichier de `zcrud_chat`. Le barrel affirme que les familles standard sont
  « ré-exprimées en interne sur le modèle d'entrées, une seule voie de rendu, arbre par défaut
  identique » (`zcrud_chat.dart:213-217`). La taille du fichier rend cette unicité douteuse à vue
  d'œil ; elle mérite une lentille « réalité du code ».

- **Soupçon D — la référence de skin notebook est une exception FR-26.**
  `view/z_chat_notebook_reference.dart` (586 lignes) porte des valeurs de couleur codées en dur,
  sous exemption nominative de la garde anti-couleurs. C'est encadré et documenté, mais c'est le
  seul endroit de l'aire où la règle est suspendue — à vérifier que l'exemption n'a pas dérivé
  vers d'autres fichiers.

- **Soupçon E — `ZChatCapabilityAudit` et `ZChatCorpusScope.audit` n'ont peut-être aucun
  consommateur.** Les deux sont présentés comme « le bouclage anti-repli-muet », mais aucun des 24
  fichiers IFFD ne les nomme, et je n'ai pas cherché de consommateur **interne** au socle. Un
  audit que personne n'appelle ne boucle rien.

---

## 11. « Livré récemment, probablement inconnu de l'hôte »

🔴 **La fenêtre correcte est v3.2.0 → v3.11.0 (2026-08-21 → 2026-08-23)**, pas 3.13 → 3.21 (§ 1).
IFFD est épinglé sur `ref: v3.21.0` (`iffd/pubspec.yaml:448, 452, 457, 467, 477`) : le code est
donc **disponible chez lui**. « Inconnu » veut dire **non consommé**, pas absent.

Classement par volume de code hôte qu'un canal remplacerait, du plus lourd au plus léger.

| # | Canal | Livré | `fichier:ligne` | Ce qu'un hôte qui l'ignore paye aujourd'hui |
|---|---|---|---|---|
| 1 | **`ZChatNotebookScreen`** | v3.6.0 | `zcrud_chat/…/view/z_chat_notebook_screen.dart:154` | **1 302 lignes** d'assemblage maison (`notebook_zcrud.dart` 926 + `notebook_page_zcrud.dart` 376). L'hôte chiffre lui-même **~1 900 lignes** dans `docs/plan-notebook-externalisation.md:812`. |
| 2 | **`$ZChatRouterFieldSpecs` + `registerZChatRouter`** | v3.8.0 | `zcrud_chat_kernel/…/route/z_chat_router.dart:340`, `:385` | **1 014 lignes** de formulaire de routeur écrit à la main (`ai_router_zcrud_edition.dart` 685 + `ai_router_sub_list_seams.dart` 329) — alors que le formulaire **et** la liste **et** les cellules viennent du registre, sans code hôte. |
| 3 | **La feuille d'outils déclarative** (`ZChatToolCatalog` `:177`, `resolve` `:217`, `ZChatToolEntry` `:215`, `ZChatToolController` `:107`, `zChatToolSettingsEntries` `:66`, `ZChatMaterialToolsSheet` `:40`, `ZChatMaterialToolTile` `:52`) | v3.6.0 / v3.6.0 | 6 fichiers | **Zéro site chez IFFD.** Un outil se déclare une fois, les deux surfaces le projettent ; visibilité motivée, grisage **avec sa raison**, comptage agrégé, recherche — calculés une fois. |
| 4 | **`ZChatMaterialSettingsSheet`** (9 familles) | v3.7.0 | `zcrud_chat_material/…/z_chat_material_settings_sheet.dart:78` (builders `:89-100`) | Une feuille de réglages Material **complète par défaut**, chaque famille remplaçable par paramètre nommé. |
| 5 | **`buildChatRouterFirestoreRepository` + `zChatRouterShapeIssue`** | v3.8.0 | `zcrud_chat_firestore/…/z_chat_router_firestore_repository.dart:76`, `:134` | Le paquet n'est **même pas déclaré** dans `iffd/pubspec.yaml`. L'hôte décode ses routeurs par forme de catalogue (`notebook_route_catalog_iffd.dart`, 106 l.) sans le filtre défensif anti-« routeur vide actif ». |
| 6 | **`ZChatRouteGate` + gouvernance par plan** | v3.8.0 | `zcrud_chat_kernel/…/route/z_chat_route_gate.dart:19` | La **décision d'owner du 2026-08-23** (transport par route porte la gouvernance : une route et ses accès associés à un plan d'abonnement) a son canal — et il n'est pas branché. `requiredAccessTokens` et `tier` voyagent déjà sur `ZChatRouteSpec` (`:20`). |
| 7 | **`ZChatRouteCatalogShape.taskAliases`** | **v3.10.0**, 2026-08-23 — le canal chat le plus récent | `zcrud_chat_kernel/…/catalog/z_chat_route_catalog_decoder.dart:49` | Les noms de tâche d'un document sont traduits **après** extraction, par une table d'hôte. Sans alias, le nom lu est la clé. Le plus susceptible d'être ignoré : livré 24 h avant que l'aire ne se fige. |
| 8 | **`ZChatTranscriptBinding`** | **v3.11.0**, 2026-08-23 — dernier commit fonctionnel du chat | `zcrud_chat/…/z_chat_transcript_binding.dart:46` | « flux → messages, envoi → persistance » écrite une fois. Consommée indirectement par `ZChatConversationScreen`, **jamais directement** — un hôte qui bâtit une troisième surface la réécrira. |
| 9 | **`ZChatExportService`** (4 formats textuels + couture PDF) | antérieur | `zcrud_chat/…/export/z_chat_export_service.dart:129` | **Zéro site.** markdown / plainText / html / **references** (les seules citations, dédupliquées), `shareConversation`, `suggestedFileName`. |
| 10 | **`ZChatComposerSubmitPolicy`** | v3.6.0 | `zcrud_chat/…/view/z_chat_composer_keys.dart:63` | **Zéro site** ⇒ l'hôte subit le défaut (Entrée envoie sur bureau/Web) sans l'avoir choisi. Le CHANGELOG le classe explicitement en « changement de défaut, hôte passif ». |
| 11 | **Transport SSE** (`zChatSseLines` `:193`, `ZChatSseStreamPort` `:129`, `zChatSseJsonLineDecoder` `:95`) | v3.6.0 | `zcrud_chat_kernel/…/data/sse/` | **Zéro site.** Reprise par `id:`, sentinelle `[DONE]`, annulation par jeton **immédiate**, zéro dépendance HTTP. Pertinent le jour où un backend IFFD passe au SSE. |
| 12 | **Ports de conversation** (`Search` `:390`, `Pin` `:405`, `Share` `:426`, `Lifecycle` `:452`) | antérieur | `zcrud_chat_kernel/…/conversation/z_chat_conversation_ports.dart` | **Zéro site.** Conséquence directe : sans `lifecycle`, `ZChatController` **délègue** l'édition rejouée et la régénération à l'exécuteur de l'hôte au lieu de les exécuter nativement (élagage, troncature, rollback). |
| 13 | **Saisie assistée** (`ZChatDictationPort` `:262`, `ZChatOcrPort` `:322`, **`ZUnreviewedText`** `:175`, `ZChatCaptureController` `:105`, `ZChatCaptureBar` `:31`) | antérieur | kernel `capture/` + chat `capture/`, `view/` | **Zéro site.** `ZUnreviewedText` n'expose **aucune `String`** : la relecture avant envoi est structurelle, pas conventionnelle. |
| 14 | **Diffusion vocale** (`ZChatSpeechChain` `:174`, `ZChatDiffusionService` `:51`, `ZChatDiffusionBar` `:35`) | antérieur | kernel `diffusion/` + chat | **Zéro site.** La chaîne de repli est une **donnée** : site unique du repli, échecs conservés. |
| 15 | **`ZChatAttachmentController` + `ZChatAttachmentStrip`** | antérieur | `attachment/z_chat_attachment_controller.dart:64`, `view/z_chat_attachment_strip.dart:46` | **Zéro site.** Cycle de vie en tranches, `ZResult` par opération, cibles ≥ 48 dp. |
| 16 | **`ZChatMarkdownRenderer.styleSet`** | v3.4.0, 2026-08-22 | `zcrud_chat_markdown/…/z_chat_markdown_renderer.dart:195` | Le **seul** canal permettant de viser séparément titre / gras / italique / citation / code dans les bulles. |
| 17 | **`ZChatTileShell.topicTrailing`** | v3.4.0 | `zcrud_chat/…/view/z_chat_tile_shell.dart:~212` | La place des commandes **de la carte** (fin de coiffe, largeur entière, glyphe 20 dp, hauteur ≥ 48 dp), distincte des actions parmi d'autres. |
| 18 | **`ZChatArtifactBar.menuBuilder`** | v3.5.0 | `zcrud_chat/…/view/z_chat_artifact_bar.dart:160` | Peindre le menu d'artefact avec la bibliothèque de menus que l'app emploie déjà ailleurs — **sans** pouvoir contourner la confirmation ni ressusciter un verbe écarté. L'hôte a **970 lignes** de rendu de menu maison (`notebook_artifact_menu_iffd.dart` 379 + `_render` 103 + `notebook_artifact_actions_iffd.dart` 488). |
| 19 | **`groupActionsBuilder`** de `ZChatConversationList` | v3.0.0 | `zcrud_chat/…/view/z_chat_conversation_list.dart:131` | L'action **à l'échelle du groupe** (« créer dans CE dossier »), avec le groupe exact. |
| 20 | **19 jetons `chat*` de `ZcrudTheme` sur 20** | v3.2.0-v3.6.0 | `zcrud_core/…/z_theme.dart:1852-1976` | Bulles, capacités, palette d'occupation, chrome complet du composer, accents de longueur de réponse, emphase de sélection — **tout par le thème**, aucun widget à remplacer. |
| 21 | **`ZChatCapabilityAudit` + `ZChatCorpusScope.audit`** | antérieur | `kernel/…/ai/z_chat_capability_audit.dart:48`, `z_chat_corpus_scope.dart:190` | **Zéro site.** Le bouclage lecture/écriture qui rend une restriction documentaire et une capacité **vérifiables** au lieu de déclaratives. |
| 22 | **Six blocs de contenu jamais nommés** (`ZTableBlock` `:417`, `ZKeyDefinitionBlock` `:462`, `ZComparisonTableBlock` `:550`, `ZTimelineBlock` `:642`, `ZAlertBlock` `:682`, `ZMermaidDiagramBlock` `:732`) | antérieur | `kernel/…/z_content_block.dart` | L'hôte ne nomme que `ZTextBlock` et `ZContentBlock` (2 citations chacun). Six formes de réponse structurée livrées, aucune consommée. |

---

## 12. Limites de ce relevé — à connaître avant de s'en servir comme preuve

1. **La mesure « non nommé » est un `comm` d'identifiants**, pas une analyse d'atteignabilité. Un
   canal peut être consommé par défaut sans être écrit. Les 22 lignes du § 11 sont, elles,
   confirmées par des `grep` ciblés.
2. **Je n'ai lancé aucun test**, dans aucun dépôt (consigne). Aucune affirmation ici ne repose sur
   une exécution.
3. **Je n'ai pas lu le registre de CR en entier** (440 270 octets). J'en ai isolé le neuf par
   `git log` : les sept CR du lot « lecteur riche + éditeur plein écran » sont **CR-IFFD-114 à
   120**, aux lignes 7589, 7675, 7734, 7787, 7825, 7859, 7879. 🔴 **Quatre sur sept portent la
   mention « RETIRÉE AVANT ÉMISSION » (117, 118, 119, 120)** — seules **114, 115, 116** sont
   ouvertes, et **toutes trois portent sur `zcrud_markdown`**, hors de ce périmètre. Aucune CR
   ouverte ne vise les six paquets de chat.
4. **Le relevé du 2026-08-25** (`docs/analyses/iffd-migration-2026-08-25/carte-ia-chat-generation.md`,
   43 393 octets) n'a **pas été repris comme source** — son `OBSOLETE.md` le déclare périmé et
   interrompu. Tout constat ci-dessus est remesuré sur le disque du 2026-08-26.
5. **Hors périmètre mais adjacent** : `zcrud_chat_study` existe (`packages/zcrud_chat_study`) et
   n'était pas dans le périmètre nommé — il n'est pas catalogué ici.
