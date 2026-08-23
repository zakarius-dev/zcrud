# Relevé des backends Lex et IFFD — transmission des paramètres (2026-08-23)

> Synthèse d'un workflow de 13 agents (4 lecteurs, 2 tours de critique, 6 suivis), rejouée
> depuis les sources des deux backends et des deux clients. Les rapports détaillés par lecteur
> vivaient dans un scratchpad de session ; seule cette synthèse est durable.


Sources : `backends/{lex-backend,lex-client,iffd-backend,iffd-client}/rapport.md` (lecture
intégrale) + `backends/{suivi-1-1,suivi-1-2,suivi-1-3,suivi-2-1,suivi-2-2,suivi-2-3}/rapport.md`
(lecture intégrale) + lecture directe de
`packages/zcrud_chat_kernel/lib/src/domain/ai/{z_chat_generation_port,z_chat_generation_settings,
z_chat_compute_effort,z_chat_stream_event,z_chat_corpus_scope,z_chat_ai_failure,
z_chat_request_token}.dart` et `packages/zcrud_chat_kernel/lib/src/data/sse/*.dart`.

---

## 1. Matrice des paramètres

Légende colonne « socle » : nom du champ exact s'il existe, `capabilities['clé']`/`extra['clé']`
si le canal ouvert est la place prévue, **absent** si rien ne le porte.

| # | Origine UI | Fil Lex (JSON alias) | Fil IFFD (JSON alias) | Effet serveur | Socle zcrud |
|---|---|---|---|---|---|
| 1 | texte tapé | `message` (requis) | `message` (requis) | contenu du tour | `ZChatGenerationRequest.notes` |
| 2 | conversation courante | `conversationId` (omis si null) | `conversationId` | thread/mémoire | `conversationId` |
| 3 | toggle stream | `stream` (bool, def `true`) | `stream` (bool, def `false`) | SSE vs JSON | pas un champ requête — choix de **port** (`ZChatGenerationPort` vs `ZChatStreamPort`), cohérent avec les deux backends |
| 4 | budget "raisonnement" | `thinking_effort` (int 1..5) | `thinking_effort` (int 1..5, alias `thinkingEffort`) | lex: borne `max_iterations` ReAct par agent ; IFFD: `max_rounds` de la boucle retriever/synth/eval | `computeEffort` (`ZChatComputeEffort`, 1..5) — **mapping confirmé côté deux backends** (suivi-1-3) |
| 5 | afficher les étapes | `enable_thinking` (bool) | `enable_thinking` (bool) | lex: émission d'events `thinking` ; IFFD: **mort** dans `_answer_with_openai` (signature jamais lue) mais influence skip-retrieval ailleurs | `revealThinkingSteps` (bool?) |
| 6 | recherche web | `enable_web_search` (bool) | `enable_web_search` (bool) | active l'outil web côté modèle (les deux) | `webSearch` (bool?, champ typé + clé canonique `capabilities['web_search']`) |
| 7 | scraper les résultats web | `scrape_web_results` (bool) | `scrape_web_results` (bool) | **mort côté lex** (accepté, jamais lu, grep négatif montré) ; côté IFFD **non retrouvé** dans `coordinator.py` (probablement plus bas, non confirmé) | **absent** — candidat `capabilities['scrape_web_results']` si un jour honoré par un hôte |
| 8 | nb résultats web | — | `max_web_search_results` (int 1..5) | borne `max_results` de la recherche web par tour | **absent** — IFFD-only, → `extra` |
| 9 | tokens de "réflexion" web | — | `max_web_thinking_tokens` (int 100..5000) | borne `max_tokens` recherche web | **absent** — IFFD-only, → `extra` |
| 10 | itérations RAG internes | — | `max_rag_iterations` (int 1..5) | intensité de CHAQUE itération RAG dans un tour (≠ `thinkingEffort` = nb de tours) | **absent, volontairement** (suivi-1-3 : IFFD-only, pas de répondant lex, → `extra`) |
| 11 | pièces jointes | `attachment_ids` (list[str], max 10, omis si null) | `documents_ids`/`document_id` (list[str]/str) | résolution contenu texte/image/OCR, corpus | `attachmentIds` (List<String>) |
| 12 | pages ciblées d'un document | — | `empty_pages` (list[int]) | OCR de pages précises injecté en `role:system` de l'historique | **absent** — pas de granularité "pages" sur `attachmentIds`/`context` ; le plus proche est `ZChatContextFragment` (context) mais pas confirmé équivalent |
| 13 | expert IA / persona | `expert_id` (str, pattern, top-level) **ou** `user_context.expert_id` | `ai_expert_id` (str) | charge instructions système custom + base de connaissances + fichiers, filtre mémoire | **absent structurellement** — pas de champ `expertId`/`personaId` sur `ZChatGenerationRequest` (confirmé grep négatif iffd-client) ; le plus proche est `instructions` (texte libre, pas un identifiant résolu côté hôte) |
| 14 | modèle "rag"/orchestrateur | `rag_model`/`rag_fallback_models` | idem | pilote 4 des 6 agents (supervisor/retriever/analysis/quality) | **absent** — seul `modelId` (opaque, un seul identifiant) existe ; lex/IFFD ont chacun ≥2 rôles de modèle, non représentables sans perte |
| 15 | modèle "writer"/réponse | `ai_model`/`ai_fallback_models` | idem | pilote l'agent de rédaction (draft+final) | `modelId` (opaque, un seul canal — cf. #14, collision possible si l'hôte a besoin des deux rôles) |
| 16 | niveau de connaissance | `knowledge_level` (str validé, top-level ou `user_context.knowledge_level`) | — | adapte le ton/niveau de la réponse (prompt) | **absent** côté socle — lex-only dans l'échantillon, → `capabilities`/`extra` |
| 17 | juridiction/pays | `user_context.jurisdiction`/`default_country` | — | filtre RAG, persisté en mémoire utilisateur, anti-reclarification | **absent** — pas d'équivalent ; le plus proche conceptuellement est `corpusScope` mais ce n'est pas une portée documentaire, c'est un filtre géographique |
| 18 | locale UI | `user_context.ui_locale` | — | hiérarchie de résolution de langue de réponse | `languageTag` (String? BCP-47) — mapping direct pour lex ; IFFD n'a **aucun** champ langue (grep négatif iffd-backend §7.8 — la langue est câblée en dur dans les prompts système) |
| 19 | override langue réponse | `user_context.response_language_override` | — | prioritaire sur détection auto | `languageTag` (même champ que #18 — le socle ne distingue pas "override explicite" de "préférence UI", contrairement à lex qui a une hiérarchie à 4 niveaux) |
| 20 | biais de longueur (régén.) | `user_context.length_bias` (déclaré côté port Dart, jamais écrit côté UI — grep négatif) | — | non tracé au-delà du dict (usage réel non confirmé côté lex) | `lengthBias` (`ZChatLengthBias`, enum EXISTANT) — mapping direct si jamais câblé côté lex |
| 21 | longueur de réponse voulue | — (pas de champ direct ; proche : `workflow_effort` MAIS ce n'est PAS la verbosité, cf. §3) | — | — | `responseLength` (`ZChatResponseLength`) — **aucun des deux backends n'a de champ dédié à la verbosité pure** dans l'échantillon lu |
| 22 | tiers/palier d'autorisation+pipeline | `workflow_effort` (enum concis/standard/detaille) | `workflow_effort` (enum low/medium/high, alias `workflowEffort`) | lex: **gate 403** avant tout traitement + coût quota + config routeur ; IFFD: **choix de topologie** d'orchestrateur (nano/mini/complet 6 agents) | **absent, volontairement** (suivi-1-2 : 2 occurrences incompatibles sous le même nom → ne satisfait pas le critère "capacité partagée et vivante"), reste `extra`/`capabilities` |
| 23 | régénérer un message | `regenerate_message_id` (str) | — | supprime le message ciblé, force reload historique | `sourceMessageId` (String?) — mapping plausible, à confirmer côté binding |
| 24 | transformation (résumé/style/flashcards/mindmap) | `transform.transformType` + `transform.sourceMessageId` | — (routes séparées par intention : `summarize_explanation`, `generate_subject_flashcards`, etc.) | lex: fast-path texte→texte OU génération productive court-circuitée avant quota chat ; IFFD: endpoint dédié par intention | `style` (`ZChatGenerationStyle`, ouvert AD-4) — un seul port `generate(style:)` couvre le cas lex ; le cas IFFD (route dédiée par intention) est couvert par le **choix d'endpoint côté hôte**, pas par le socle |
| 25 | outils du corpus documentaire (codes douanes, TEC, valorisation / CDN Togo, CDN Niger, CDC CEDEAO, CGI Togo, TEC CEDEAO, GATT) | `tools_context.{enable_codes_douanes,codes_douanes_filter,enable_tec,tec_filter,enable_valuation}` | `enable_cdn_togo`, `enable_cdn_niger`, `enable_cdc_cedeao`, `enable_cgi_togo`, `enable_tec_cedeao`, `enable_code_gatt` (+ inférence regex sur le message si absent) | active/désactive des familles d'outils RAG, borne la recherche à des ID précis | `corpusScope` (`ZChatCorpusScope`, clés opaques d'hôte) — **mapping structurel correct pour les deux** ; c'est exactement le canal conçu pour ça (§3.2) |
| 26 | consigne système libre | `system_instructions` (respecté sur v2, **ignoré silencieusement sur v3** côté IFFD ; toujours pris en compte côté lex via prompt fixe d'endpoint, jamais le texte client — cf. lex §3 `systemInstructions` n'existe même pas dans `ChatRequest`) | `systemInstructions` (v2 seulement) | prompt système | `instructions` (String?, "jamais un prompt système assemblé" — AD-12) |
| 27 | filière/cycle académique | — | `filiereIFFD`/`cycleIFFD`/`niveauIFFD` | **vestigiaux** : parsés, stockés, jamais lus en aval (grep négatif iffd-backend) | **absent** — mort côté IFFD lui-même, aucune raison de le porter au socle |
| 28 | outils génériques | `use_tools`/`json_response`/`search_only` (portés par `ChatRequest` lex, jamais mentionnés comme lus dans le rapport lex — hors périmètre lex) | `use_tools`/`json_response`/`search_only` (portés, **jamais relus** sur le chemin v3 pydantic, écrasés en dur par le routeur) | — | **absent** — signal de champs déjà vestigiaux côté IFFD |
| 29 | annulation | pas de endpoint dédié (seule la déconnexion réseau déclenche un cleanup best-effort) | pas de endpoint dédié (thread détaché, **aucune** annulation même best-effort) | — | `ZChatRequestToken.cancel()`/`ZChatActionExecutor.cancelRequest` — **contrat d'identité local**, sans garantie serveur (suivi-2-1) — cohérent avec les deux backends qui n'offrent AUCUNE garantie |
| 30 | reprise de stream | `Idempotency-Key` + `Last-Event-ID` (protocole complet, replay buffer Redis) | **aucun** mécanisme de reprise (grep implicite — pas mentionné dans iffd-backend, format SSE sans `id:` de reprise documenté) | lex: rejoue depuis `Last-Event-ID` sans re-décompter ; IFFD: rien | `ZChatStreamEvent.sequenceId` + `ZChatRequestToken.resumeFrom` — **couvre le cas lex** ; pour IFFD, `sequenceId` reste `null` par construction (déjà vu et documenté par l'adaptateur `z_iffd_stream_normalizer.dart`, suivi-2-2) |
| 31 | quota / crédits | headers `X-Chat-Quota-*`, `X-Prepaid-Balance` (HTTP, pas SSE) | **aucun** mécanisme de quota (grep négatif iffd-backend) | lex: décompte pondéré par `workflow_effort`, fail-open | `ZChatQuotaEvent`/`ZChatQuotaSnapshot` (kernel) — **mapping direct pour lex** ; IFFD n'a simplement rien à mapper |
| 32 | auth | `Authorization: Bearer` + `X-Firebase-AppCheck`, **vérifiés réellement** côté serveur | mêmes en-têtes envoyés côté client, mais **non vérifiés** côté serveur (v2 no-op commenté, v3 jamais câblé) | contrôle d'accès (lex) / aucun (IFFD, en l'état) | hors du périmètre `ZChatGenerationRequest`/Port — c'est un problème de transport HTTP, porté par l'implémentation du port côté hôte, pas par le domaine |
| 33 | annuler par déco | best-effort serveur (`asyncio.shield`, cleanup partiel) | aucun (thread détaché continue) | — | non modélisé — cohérent avec l'absence de garantie du contrat `cancelRequest` (suivi-2-1) |

---

## 2. Transport comparé

| Axe | Lex | IFFD | Implication pour un port du socle servant les deux |
|---|---|---|---|
| Forme de l'API | **un seul endpoint** `POST /api/v1/chat/` à corps riche (Pydantic `ChatRequest`, ~15 champs top-level + 2 sous-objets), différencié par `stream`/`transform` | **une route par intention** (`chat_with_assistant_v2`, `generate_subject_explanation`, `summarize_explanation`, `generate_subject_flashcards`, `generate_mindmap`, …), chaque route construit sa propre map de paramètres à la main (legacy) ou via `IffdChatRequest.from_request` (v3, 2 endpoints seulement) | Le socle a bien fait de choisir `style: ZChatGenerationStyle` (ouvert) plutôt que N signatures : ça absorbe "une route par intention" comme une valeur de style résolue côté hôte au moment de choisir l'URL, sans obliger le port à connaître les URLs. |
| Format des flux | SSE typé, chaque `data:` est un JSON avec `type` discriminant explicite (`thinking`/`token`/`sources_preview`/`content_block`/`done`/`error`), `id:` croissant réattribué à la reprise | SSE **sans enveloppe JSON** : soit du texte brut token-par-token avec sentinelles (`###LINE###`, `<RAG_THINKING>`) sur le chemin legacy consommé par la majorité des endpoints, soit délégué tel quel à `sse_starlette` sans format applicatif construit à la main sur le chemin v3-orchestrateur | Le contrat `ZChatStreamPort.stream()` rend déjà `Stream<ZResult<ZChatStreamEvent>>` — un **résultat**, pas un format de transport. C'est ce qui permet à `zcrud_chat_syncfusion` d'écrire un adaptateur dédié (`ZIffdTextStreamPort` + lexeur de sentinelles) qui traduit AVANT le port, sans que le kernel n'ait jamais à connaître `###LINE###`. Déjà fait (suivi-2-2). |
| Id / reprise | `Idempotency-Key` (stable tout le tour) + `Last-Event-ID` (dernier `id:` reçu) → replay buffer Redis, ou repli sur relecture Firestore du tour persisté | aucun id, aucune reprise — un flux coupé perd tout ce qui n'a pas été rendu côté client | `sequenceId` nullable + `resumeFrom` couvrent exactement les deux cas : renseigné pour lex, toujours `null` pour IFFD (documenté explicitement côté adaptateur IFFD pour ne jamais fabriquer une fausse promesse de reprise, suivi-2-2). |
| Idempotence | réelle côté lex (retry avec même clé → même `message_id`, pas de re-décompte quota) | aucune (chaque appel relance le pipeline, aucune protection contre un double-clic réseau) | Le socle ne modélise pas l'idempotence en tant que telle — c'est un sous-produit de `requestId` + `sequenceId`. Pas de trou identifié : IFFD n'a simplement rien à garantir, lex a déjà tout côté transport hors du domaine. |
| Annulation | absente côté endpoint, best-effort sur déconnexion réseau uniquement | totalement absente, même sur déconnexion (thread détaché) | Confirme le choix du socle de ne **jamais** promettre "l'arrêt du calcul serveur" dans `cancelRequest` — mais suivi-2-1 montre que le contrat actuel ne le dit pas non plus explicitement (gap de dartdoc, pas de dysfonctionnement). |
| Auth (forme) | 2 jetons vérifiés réellement (Firebase ID token + App Check), rôle+tier lus depuis Firestore avec cache TTL, fail-open sur incident infra | mêmes en-têtes envoyés, **jamais vérifiés** côté serveur actif (v2 no-op, v3 jamais câblé) — writeup net : l'IFFD backend actuel fonctionne en pratique sans auth, malgré l'apparence de garde | Hors du domaine `ZChatGenerationRequest`/Port par construction — c'est une responsabilité de transport HTTP (headers), déjà correctement laissée à l'implémentation de port par hôte (AD-12). Pas de trou côté socle ; c'est un trou côté backend IFFD lui-même. |
| Quotas | quota chat pondéré par `workflow_effort` (fail-open Redis), quota vision séparé, quota "éducation" pour transformations productives — tous exposés en headers + `ZChatQuotaEvent` côté client | aucun mécanisme identifié (grep négatif) | `ZChatQuotaEvent`/`ZChatQuotaSnapshot` couvrent le cas lex ; IFFD n'a rien à mapper — pas de trou, juste une capacité inégalement exercée par les deux hôtes. |

---

## 3. Divergences structurantes Lex vs IFFD

1. **`workflow_effort` porte deux concepts incompatibles sous le même nom** (suivi-1-2) : chez lex
   c'est une **porte d'autorisation** (403 avant tout traitement, lié au tier d'abonnement) + coût
   en crédits ; chez IFFD c'est un **choix de topologie d'orchestrateur** (nano/mini/complet),
   sans notion de plan. Aucun des deux ne pilote la verbosité de la réponse malgré des labels qui
   y font penser (`concis/standard/detaille` chez lex évoquent `ZChatResponseLength`, mais n'en
   ont pas le rôle).
2. **`thinking_effort` converge réellement** entre les deux (suivi-1-3) : dans les deux backends
   c'est le budget d'itérations de la boucle principale de l'agent/pipeline — c'est le seul des
   deux axes numériques `1..5` qui mérite un type partagé, et c'est déjà `computeEffort`.
   `max_rag_iterations` (IFFD-only, intensité *par* itération plutôt que *nombre* d'itérations)
   n'a pas de répondant côté lex — canal ouvert, pas un second axe.
3. **Authentification** : lex vérifie réellement deux jetons ; IFFD accepte les mêmes en-têtes
   sans jamais les vérifier sur les endpoints réellement montés (v2 no-op commenté, v3 jamais
   câblé) — un écart de posture de sécurité entre les deux backends, pas un écart de contrat API.
4. **Annulation/quota** : lex a une porte d'autorisation, un quota réel et un cleanup best-effort
   sur déconnexion ; IFFD n'a **aucun** des trois. Le pipeline IFFD continue de tourner (et de
   facturer des tokens) après déconnexion du client — pas de mécanisme équivalent au
   `asyncio.shield` de lex.
5. **Transport SSE** : lex a une enveloppe JSON typée par event avec discrimination explicite ;
   IFFD (chemin réellement emprunté par la majorité des endpoints) envoie du texte brut avec
   sentinelles pseudo-XML détectées par sous-chaîne — une architecture de flux fondamentalement
   différente, déjà absorbée côté zcrud par un adaptateur dédié plutôt que par le port lui-même.
6. **`systemInstructions` client** : respecté (concaténé) côté lex-legacy/IFFD-v2 ; **absent du
   modèle Pydantic** côté lex-v3 réel (`ChatRequest` n'a même pas ce champ) et **ignoré
   silencieusement** côté IFFD-v3 (le champ existe dans `BaseChatRequest` mais `IffdChatRequest`
   ne le relit jamais du corps JSON, seul le paramètre fixé en dur par le routeur compte).
7. **Reprise de stream** : présente et robuste côté lex (Idempotency-Key + Last-Event-ID + replay
   Redis + repli Firestore) ; totalement absente côté IFFD.
8. **Modèles multi-rôles** : les deux backends distinguent en interne un modèle "RAG/retrieval"
   (pilotant 4-6 agents) d'un modèle "writer" (rédaction) — mais le socle n'a qu'un seul
   `modelId` opaque. Ni lex ni IFFD ne peuvent exprimer leurs deux rôles de modèle via ce champ
   unique sans perte (cf. matrice #14/#15).
9. **Granularité document/pages** : IFFD sait cibler des pages précises d'un document
   (`document_id` + `empty_pages` → OCR de pages, injecté en historique) ; lex ne fait que
   résoudre des `attachment_ids` entiers. Le socle (`attachmentIds: List<String>`) ne porte que
   le niveau "document entier" des deux — la granularité "pages" d'IFFD n'a pas d'équivalent.
10. **Expert/persona** : les deux backends ont un concept d'expert IA custom (instructions système
    + base de connaissances + fichiers dédiés), mais le socle n'a **aucun** champ dédié — c'est le
    trou le plus visible de la matrice (#13), confirmé structurellement absent côté portage IFFD
    (grep négatif iffd-client) et présent des deux côtés backend.

---

## 4. Contrat pour le socle

### Déjà bien couvert (confirmé, pas de changement à proposer)

- `notes`, `conversationId`, `sourceMessageId`, `attachmentIds`, `instructions`, `languageTag`,
  `webSearch`, `computeEffort`, `revealThinkingSteps`, `responseLength`, `lengthBias`,
  `corpusScope`, `style`, `modelId` (un seul rôle) — mapping direct confirmé pour au moins un
  backend, structure correcte pour l'autre.
- `ZChatStreamEvent.sequenceId` nullable + `ZChatRequestToken.resumeFrom` — couvre nativement
  "reprenable" (lex) et "non reprenable" (IFFD) sans branche spéciale.
- `ZChatCorpusScope` (clés opaques, deux niveaux famille/clé) — couvre nativement les 5 flags lex
  et les 6 flags IFFD, sans qu'aucune valeur de corpus ne soit connue du socle (AD-12 respecté).
- Adaptateur texte+sentinelles (`zcrud_chat_syncfusion/z_iffd_*`) — déjà écrit, traduit le cas
  "pas d'enveloppe JSON" vers l'union scellée sans fuite (suivi-2-2).

### Manques réels, avec forme proposée (additif, AD-4, pas d'enum fermé pour ce qui est ouvert)

1. **Gate d'entitlement typée** (suivi-1-2 §4, suivi-2-3). Le canal `zChatFailureFromWire` →
   `ZChatProviderFailure(message, code: rawCode)` couvre déjà structurellement le 403
   `UPGRADE_REQUIRED` de lex — **rien à ajouter côté type**, le vrai gap est que ce canal n'est
   câblé nulle part côté hôte (ni adaptateur lex, ni UI GetX/Riverpod) — c'est un travail
   d'intégration côté hôte, pas un manque de modélisation du socle. Suggestion de forme si le
   owner veut aller plus loin : documenter dans la dartdoc de `ZChatGenerationPort`/`Stream`
   l'exemple concret `ZChatProviderFailure(code: 'UPGRADE_REQUIRED')` pour qu'un hôte GetX/Riverpod
   sache où brancher.
2. **`cancelRequest` sans clause "best-effort"** (suivi-2-1). Trou de **dartdoc**, pas de champ :
   `ZChatActionExecutor.cancelRequest` (`z_chat_action_executor.dart:62-68`) devrait porter la même
   mention "best-effort, ne garantit pas l'arrêt du calcul serveur" que
   `ZChatSpeechPort.stop()`/`ZChatCapturePort` pour un besoin structurellement identique — confirmé
   nécessaire par les deux backends (aucun des deux n'offre de garantie d'arrêt réel).
3. **Rôle de modèle secondaire** (retrieval/RAG vs writer) — `modelId` est un champ unique opaque ;
   les deux backends ont ≥2 rôles distincts pilotés par des identifiants séparés. Forme proposée :
   PAS un second champ typé de premier niveau (ce serait imposer une taxonomie de rôles que le
   socle ne connaît pas — AD-12) mais documenter explicitement que `extra['model_roles']` (ou
   équivalent) est le canal prévu pour un hôte qui a besoin de plus d'un identifiant de modèle,
   `modelId` restant le rôle "principal/writer" par convention documentée.
4. **Expert/persona** (matière la plus visible, #13/#10) — champ candidat :
   `String? expertId` (opaque, transporté verbatim, jamais interprété — même contrat que `modelId`)
   sur `ZChatGenerationRequest`. Justification de la promotion : capacité **partagée et vivante**
   chez les deux fournisseurs rencontrés (contrairement à `workflow_effort`), même rôle
   fonctionnel dans les deux (résolution d'instructions système + base de connaissances custom
   côté serveur, à partir d'un identifiant opaque envoyé par le client) — satisfait le critère que
   le socle applique déjà (`z_chat_generation_settings.dart` L27-32). Alternative moins invasive
   si le owner préfère ne rien ajouter en champ de premier niveau : `capabilities`/`extra` ne
   suffit pas ici car ce n'est pas un booléen ni une valeur secondaire — c'est un identifiant
   structurant comme `modelId`/`conversationId`, d'où la proposition d'un vrai champ.
5. **Granularité "pages d'un document"** — candidat le plus faible du lot (un seul backend,
   IFFD, l'exerce ; pas de confirmation qu'un consommateur zcrud en a besoin aujourd'hui). Forme
   si retenue : ne pas complexifier `attachmentIds: List<String>` — passer par `extra['page_refs']`
   ou une extension de `ZChatContextFragment` (déjà le mécanisme pour "matière contextuelle
   supplémentaire") plutôt qu'un nouveau champ de premier niveau.
6. **`scrapeWebResults`** — champ mort chez lex, non confirmé utile chez IFFD (non tracé plus loin
   par manque de budget de lecture côté suivi). Ne PAS ajouter en champ typé — candidat naturel
   `capabilities['scrape_web_results']` (canal ouvert existant, aucune modification de forme
   requise) si un hôte l'honore un jour.
7. **`maxWebSearchResults`/`maxWebThinkingTokens`/`maxRagIterations`** — IFFD-only, pas de
   répondant lex dans l'échantillon (suivi-1-3 tranche explicitement contre la promotion). Place :
   `extra` (valeurs numériques, hors du canal `capabilities` qui est bool-only).
8. **Locale/juridiction fine** (`ui_locale` vs `response_language_override` vs préférence
   persistée `jurisdiction`) — `languageTag` unique ne distingue pas "préférence UI" de "override
   explicite du tour", alors que lex a une hiérarchie à 4 niveaux. Gap mineur, pas de forme
   proposée faute d'un second exemple hors lex — candidat `extra['language_override']` si besoin
   futur démontré, sans toucher `languageTag`.

### Ce qui reste délibérément côté hôte (extra/capabilities), confirmé par au moins un suivi

- `workflowEffort` (suivi-1-2 : deux concepts incompatibles, échec du critère de promotion).
- `maxRagIterations` (suivi-1-3 : IFFD-only).
- `filiereIFFD`/`cycleIFFD`/`niveauIFFD` (morts même côté IFFD lui-même — aucune raison de porter
  un champ vestigial au socle).
- `knowledgeLevel` (lex-only dans l'échantillon lu).
- `use_tools`/`json_response`/`search_only` (vestigiaux des deux côtés sur les chemins réellement
  actifs).

---

## 5. Ce que fait mieux chaque backend (preuves fichier:ligne)

### Lex "en avance" (le propriétaire le dit, mesuré)

1. **Reprise de stream complète et testée** — `Idempotency-Key` stable tout le tour +
   `Last-Event-ID` + replay buffer Redis + repli sur relecture Firestore du tour persisté
   (`lex-backend/rapport.md` §8, `routes.py:348-544`) ; aucun équivalent côté IFFD.
2. **Auth réellement appliquée** — chaîne `Depends` complète, deux jetons vérifiés
   (`app/middleware/firebase_auth.py:13-59`, `app/middleware/app_check.py:10-42`),
   fail-open contrôlé sur incident infra seulement (`subscription_check.py:21-58`).
3. **Quota réel, pondéré, avec repli prépayé** — `chat_quota_service.check_and_consume`, coût
   pondéré par `workflow_effort`, fail-open Redis, couverture prépayée en cas de refus
   (`lex-backend/rapport.md` §6.1).
4. **Clarification d'ambiguïté avec arrêt réel du graphe** — `app/services/agents/clarification.py`
   (163 lignes), détection déterministe sans LLM, routage `graph.add_edge("clarification_halt",
   END)` — le graphe LangGraph se termine réellement là (`suivi-1-1` §2, `graph.py:225`) ; pas de
   demi-mesure côté client seulement.
5. **Gate d'autorisation avant tout I/O** — le refus 403 `UPGRADE_REQUIRED` intervient **avant**
   tout traitement (`routes.py:605-614`), avant même le décompte de quota — contraste net avec
   IFFD qui n'a aucune porte d'accès de ce type.
6. **Nettoyage best-effort protégé sur déconnexion** — `asyncio.shield` autour de la tâche de
   nettoyage (checkpoint partiel, sandbox) même après annulation ASGI (`lex-backend/rapport.md`
   §9, L127) — modeste mais réel, contrairement au thread détaché IFFD qui ne nettoie rien.
7. **Format SSE typé et discriminé** — chaque event porte un `type` explicite avec schéma stable
   (`thinking`/`token`/`sources_preview`/`content_block`/`done`/`error`), contrat documenté par
   tests (`tests/api/test_chat_routes.py`, 1240 lignes).

### Ce qu'IFFD fait que Lex n'a pas

1. **Ciblage de pages précises d'un document** — `document_id` + `empty_pages` → OCR de pages
   spécifiques injecté directement dans l'historique de conversation (`presentation.py:101-121`) ;
   lex ne résout que des `attachment_ids` entiers, sans granularité intra-document.
2. **Inférence automatique des flags de corpus depuis le texte** — les 6 drapeaux de corpus
   (CDN Togo, CDN Niger, CDC CEDEAO, CGI Togo, TEC CEDEAO, GATT) sont **auto-détectés par regex**
   sur le message si le client ne les envoie pas explicitement (`iffd/schemas/request.py`, fonctions
   `check_if_*_needed`) — un flag explicite prime, mais l'absence n'est pas un défaut par défaut
   à `false` comme chez lex ; c'est un mécanisme que lex n'a pas.
3. **Séparation modèle "RAG" / modèle "writer" à granularité fine** — 4 rôles distincts
   (`supervisor_model`, `retriever_model`, `analysis_model`, `quality_model`) tous pilotables par
   `ragModel`, versus le rôle unique `draft_writer_model`/`writer_model` piloté par `aiModel`
   (`iffd/v3/router.py:101-118`) — une granularité de contrôle que lex n'expose pas côté API (lex
   a bien plusieurs rôles internes mais moins de leviers client observés dans le rapport).
4. **Topologie de pipeline sélectionnable** — trois pipelines distincts (nano/mini/complet,
   `coordinator.py:929-950`) avec un vrai delta de coût/latence/qualité, exposé comme un choix
   client explicite (`workflow_effort`) — lex a un seul pipeline, modulé par `thinking_effort`
   mais sans changement de topologie.

---

## Gaps de cette synthèse (hérités des rapports amont, non recreusés ici)

- La forme exacte du corps 403 lex (`{"code":"UPGRADE_REQUIRED"}` a-t-il un `message`/`detail` ?)
  n'a pas été revérifiée au-delà de ce que suivi-1-2/suivi-2-3 citent déjà.
- Le contenu de `retriever_executor.py`/`synthesizer_executor.py`/`stream_handler.py` (IFFD) reste
  non ouvert en détail (budget de lecture des rapports amont) — le point d'usage réel de
  `scrape_web_results` côté IFFD n'est donc pas confirmé, seulement absent des points cherchés.
- Aucune vérification faite ici sur un éventuel troisième backend zcrud (DODLP) qui porterait un
  jeu de paramètres différent — l'échantillon reste à 2 hôtes IA, ce qui limite la généralisabilité
  de toute conclusion "pas assez partagé pour être typé".
