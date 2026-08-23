# Handoff v3.8.0 — Transport par route : routeurs IA, gouvernance par plan, fournisseur et modèle par tâche

> **Date** : 2026-08-23 (brouillon écrit avant les lots ; complété lot par lot). **Portée prévue** :
> `zcrud_chat_kernel`, `zcrud_chat`, nouveau satellite `zcrud_chat_firestore`, `tool/reserved_keys_gate`.
> **Traite** : la décision du propriétaire du 2026-08-23 (transport par route de première classe) et la
> moitié « routage » du relevé des backends (`docs/analyses/backends-lex-iffd-2026-08-23.md`,
> `docs/analyses/routage-par-route-2026-08-23.md`).

## 1. Pourquoi

Deux modes de transport coexistent chez les hôtes : **un endpoint unique à corps riche** (Lex, `POST /`)
et **une route par intention** (IFFD, `generate_subject_explanation`, `summarize_explanation`…). Le
propriétaire a tranché : le mode par route est de première classe au socle. Il porte la **gouvernance**
(route ↔ plan d'abonnement), permet à l'app de déclarer **par tâche** le **fournisseur**, le modèle par
défaut, ses replis et ses callbacks, et le catalogue doit être **récupérable depuis le backend**. Lex
migrera vers ce mode à terme. Aujourd'hui tout passe par OpenRouter ; demain certaines tâches iront à
d'autres fournisseurs — le socle transporte le fournisseur par tâche et par repli, sans l'interpréter.

Ce que le relevé a mesuré :
- **IFFD** a déjà l'entité côté client (`IffdAiRouterModel` : douze paires `<tâche>Model`/`*FallbackModels`,
  `workflowEffort`, `questionsCounts`, identifiant par défaut `"free"`), une page d'administration maison
  (803 + 700 lignes) et une **édition zcrud déjà écrite mais désactivée** (`kAiRouterEditionUseZcrudDefault = false`).
  **22 sites** recopient `"model": aiRouter?.aiModel` ; trois dropdowns de repli sont dupliqués ; un bug
  réel : `folder_explanation_page.dart:213` envoie l'**identifiant du routeur** comme nom de modèle.
- **Lex** a l'entité côté serveur (`AiRouterConfig` : modèles par agent avec `provider`, replis
  `"provider:model"`, paramètres de pipeline, `workflow_effort`, `is_active`), servie par
  `GET /v1/admin/ai-routers`, cachée 300 s, repliée sur un défaut codé, et un gate **403 `UPGRADE_REQUIRED`**.
- 🔴 **Sécurité, à la main du propriétaire** : sur le backend IFFD, `check_app_check`/`check_authentication`
  existent mais leur unique appel est **commenté** (`iffd/v2/router.py:887-888`) ; les routes v2 acceptent
  les en-têtes d'auth et ne les vérifient jamais. Un transport gouverné par plan n'a de sens que si le
  serveur vérifie qui appelle.

## 2. Ce que le socle livre (à compléter lot par lot)

### K1 — noyau (`zcrud_chat_kernel`, `domain/route/`)
- **`ZChatRouter extends ZEntity with ZExtensible`** écrite à la main (le noyau refuse le codegen par garde) : `id`, `name`, `description`, `isActive`, `tier` opaque, `model`/`fallbacks` racine, `computeEffort`, `routes` (liste sur le fil, objet toléré en lecture, dernière déclaration gagnante), `params`, `extension`, `extra` filtré (AD-19.1). **`$ZChatRouterFieldSpecs`** et **`registerZChatRouter(registry)`** manuels ⇒ le formulaire d'administration vient de `DynamicEdition`/`ZCrudScreen` sans code hôte ; `routes` en `subItems`, replis en jetons `provider:model` (l'imbrication de `subItems` n'est pas mesurée dans le cœur — repli assumé).
- **`ZChatModelRef {providerId?, modelId}`** partout où un modèle est nommé ; lecture tolérante de `"provider:model"` (coupé au premier `:`) et d'une chaîne nue ; jamais interprété.
- **`ZChatRouteSpec`** par tâche : `taskKey` (= `style.kind`), `routeName?`, `model`, `fallbacks`, `computeEffort?`, `params`, `requiredAccessTokens`, `handlerId?`.
- **`ZChatRouteResolution.from(router, taskKey)`** : repli tâche → racine, le couple (modèle, replis) replie **ensemble** ; `toRequest(base, {settings})` : le modèle/fournisseur de la route sauf choix explicite de l'appelant, `computeEffort = réglage ?? route ?? racine`, `extra = {...params, ...base.extra}`.
- Ports : **`ZChatRouteCatalogPort`** (`resolveRouter`, `listRouters`, `invalidate`) + `Inert` + `InMemory` ; **`ZChatRouteGate`** (`canRoute(taskKey, {tier, requiredAccessTokens})`) + **`ZDenyAllChatRouteGate` par défaut** + `ZAllowAllChatRouteGate` ; **`ZChatRouteHandlers`** (`streamPortFor`, `generationPortFor`) + `Inert` + `Map`.
- **`ZChatGenerationRequest.providerId`** (additif, opaque) ; `ZChatFailureCodes.upgradeRequired` (`UPGRADE_REQUIRED` absorbé à l'entrée).
- Sonde `ZChatRouter` dans `tool/reserved_keys_gate` (sans elle, vert par paquet et rouge à `verify`).

### K2 — catalogue composable (`domain/route/catalog/`)
- **Sources** : statique, sur repository (`ZReadOnlyRepository<ZChatRouter>` — filtre `is_active` serveur **et** mémoire ; « non trouvé » = `Right(null)`), distante HTTP-agnostique (`ZChatRemoteRouteCatalogSource(open:, decode:)` — l'hôte ouvre et authentifie, le socle décode).
- **Décodeur défensif** + formes de catalogue : `canonical`, **`lex`** (enveloppe `{routers}`, clés camelCase et snake_case, `agentModels` → routes par agent, `fallbackModels "p:m"`, `pipelineParams` → `params`, `workflowEffort` → `tier`), **`suffixPairs(...)`** à clés d'hôte (la forme IFFD, sans qu'aucune clé IFFD ne soit écrite au socle). Un routeur corrompu est compté dans `rejected`, jamais la liste perdue.
- **`ZChatTtlRouteCatalog`** (TTL, cache négatif, service périmé sur panne distante, invalidation ciblée) et **`ZChatCascadeRouteCatalog`** : les sources dans l'ordre déclaré ; `ZServerFailure` ⇒ source suivante ; `ZCacheFailure` ⇒ repropagé ; épuisement ⇒ le repli **déclaré par l'hôte**, sinon `Left(ZNotFoundFailure)` — le socle n'invente jamais `"free"`.
- `ZChatInMemoryRouterRepository` (sémantique alignée Firestore) et `ZChatInvalidatingRouterRepository` (invalide le catalogue après `save`/`softDelete`/`restore` — miroir de l'invalidation de cache du backend Lex).

### A — assemblage (`zcrud_chat`)
- **`ZChatRouteSession`** possédée par l'hôte : tranches granulaires, `selectRouter`/`refresh`/`setModelOverride`, résolveurs purs — **aucun membre n'envoie**.
- **Le câblage vit dans les pièces partagées par le Chat et le Notebook** : `ZChatController(routeResolver:)` résout dans le cycle unique d'envoi, **avant** l'état, le message optimiste et tout appel de port ; un refus du gate publie `lastFailure` (`upgradeRequired`) et laisse la saisie intacte. `ZChatNotebookController` relaie pour les artefacts, avant le marquage d'occupation.
- **Ports routés** : répartition `handlerId → providerId → routeName → fallback` ; ils ne résolvent ni ne gatent.
- **`ZChatConversationScreen`** (nouveau) et `ZChatNotebookScreen(routeSession:, routerOptions:, modelLabelOf:, taskLabelKeyOf:)` partagent le même assembleur : session → sélecteur de routeur du composer partagé + choix du repli par tâche dans la feuille.
- Arbitrages : un effort posé par le builder de l'hôte prime sur celui de la route ; pour un artefact, `providerId` voyage dans `extra['provider_id']` (besoin signalé au noyau : un champ typé) ; un `Left` du catalogue laisse `router = null` et rend tout envoi refusé jusqu'à `refresh`.
_K2 — catalogue : sources, décodeur, TTL, cascade, dépôts._
_A — assemblage : session, seams partagés Chat/Notebook, ports routés, écran de conversation._
### F — `zcrud_chat_firestore` (nouveau, 41e paquet, puits du graphe)
- **`buildChatRouterFirestoreRepository({firestore, collectionPath, toCanonical?, toLegacy?, deletionSemantics, legacyDeletedKey?, extensionParser?, logger?})`** sur le repository Firestore générique — **aucune ligne spécifique** n'était nécessaire côté `zcrud_firestore`, qui ne dépend toujours pas du chat.
- Tri de forme défensif avant décodage : un document étranger n'est jamais lu comme un routeur vide actif.
- ⚠️ **Sur une collection legacy sans `is_deleted` (IFFD), déclarer `ZDeletionSemantics.absentMeansAlive`** — en `strict`, zéro routeur n'est lu (gardé par un test). Basculer en `strict` une fois les documents réécrits par `save`.
- Garde de graphe : aucune arête `zcrud_firestore → zcrud_chat*`, aucun `.g.dart`, imports bornés.

## 3. Ce qui change pour un hôte

### Ce que l'onglet Chat écrit désormais (exemple minimal, 19 lignes)

```dart
final session = ZChatRouteSession(                                     // 1  (hors build, dispose par l'hôte)
  catalog: catalogue, gate: monGate, initialRouterId: idPersiste);    // 2
final port = ZChatRoutedStreamPort(                                    // 3
  routeOf: (k) => session.routeOf(k).value,                            // 4
  handlers: ZChatMapRouteHandlers(streamPorts: {'openrouter': p1}),    // 5
  fallback: portParDefaut);                                            // 6
// …dans l'onglet :
ZChatConversationScreen(                                               // 7
  streamPort: port,                                                    // 8
  conversationId: id,                                                  // 9
  cursorColor: Theme.of(context).colorScheme.primary,                  // 10
  routeSession: session,                                               // 11
  routerOptions: [for (final r in routeurs) ZChatModelOption(id: r.id, label: r.name)], // 12
  modelLabelOf: (m) => libelles[m.modelId],                            // 13
  taskLabelKeyOf: (k) => 'app.task.$k',                                // 14
  confirm: monDialogue,                                                // 15
  presentTools: (ctx, sheet) => showModalBottomSheet(context: ctx, builder: sheet), // 16
  failureBuilder: (ctx, f) => MonBandeau(f),                           // 17
);                                                                     // 18
```


### Hôte passif
Rien : sans catalogue déclaré, la requête reçue par le port est identique à celle du builder, les arbres
des écrans sont inchangés.

### Hôte qui déclare un catalogue SANS gate
**Toute route est refusée** (`ZDenyAllChatRouteGate`, posture `ZDenyAllAcl`). Déclarer explicitement
`const ZAllowAllChatRouteGate()` tant qu'aucune gouvernance n'existe.

### Hôte ayant compensé — IFFD (mesuré le 2026-08-23)
À **retirer**, sinon la compensation s'additionne au socle :
- **22** sites `"model": aiRouter?.aiModel` (`iffd_ai_repository_impl.dart`) → `request.modelId`/`request.providerId` posés par la résolution ;
- **3** dropdowns de repli (`smartnotes_dialogs.dart` ×2, `flashcard_edition_screen.dart`) → `zChatRouteSettingsEntries` ;
- **25** sites `aiRouterId`/`setAiRouterId` → `session.routerId`/`selectRouter` (la persistance en préférences reste hôte, branchée sur la tranche) ;
- **9** sites `aiHasAccessToAiRouter` → un seul `ZChatRouteGate` ;
- `endpoint: 'chat'` codé en dur et **`defaultModelId: aiRouterId`** (`folder_explanation_page.dart:184,213-215` — l'identifiant du routeur envoyé comme nom de modèle : corrigé mécaniquement par la résolution) → port routé + opener par `routeName` ;
- la page d'administration maison (803 + 700 l.) et `ai_router_zcrud_edition.dart` sous drapeau → `kAiRouterEditionUseZcrudDefault = true`, puis `ZCrudScreen<ZChatRouter>` (≈ 8 lignes) ;
- `FirebaseAiRouterRepositoryImpl` → `buildChatRouterFirestoreRepository(collectionPath: 'IffdAiRouterModel', deletionSemantics: absentMeansAlive, toCanonical:, toLegacy:)` ; le codec (12 paires → `routes[]`, `workflowEffort` → `tier`, `questionsCounts` → `routes['flashcards'].params`, `aiProvider` → `model_provider_id`) reste hôte — gabarit dans le test e2e du satellite.
**Tripwire recommandé** : un test qui affirme aujourd'hui que le corps POST du Notebook porte `aiRouterId` comme `model` — il rougira à l'adoption et désignera le doublon.

### Lex — à terme
`ZChatRemoteRouteCatalogSource(open: GET /v1/admin/ai-routers…, decode: ZChatRouteCatalogDecoder(ZChatRouteCatalogShape.lex))` enveloppée d'un `ZChatTtlRouteCatalog(ttl: 300 s)` et d'une cascade au repli client de `get_default_router` ; transport **inchangé** (une seule route HTTP, `routeName` non consommé — le catalogue ne pilote que fournisseur, modèle, effort, paramètres) ; le gate client miroir de `_EFFORT_ORDER` reste un **pré-check UX**, le 403 serveur l'autorité. Zéro ligne backend.

## 4. Partie I — parité `ZCrudScreen` (lots groupés dans cette version)

- **A1** : le défaut visé par le plan (« `itemBuilder` ignoré dès qu'un `layout` est fourni ») était **déjà corrigé depuis v0.93.0** ; restait `ZListCustomLayout`, dernier layout sans `entityFor`. Livré : `ZEntityResolver<T>`, `ZEntityListViewBuilder<T>`, `ZListCustomLayout.entityView` / `.forEntity<T>` (résolveur qui ne lève jamais) ; `entityFor` passé à la vue entière **hors** `ZListRenderRequest` (mémoïsation intacte). Nuance : `ZListCustomLayout.customView` devient nullable (0 lecteur dans le monorepo et chez DODLP). DODLP : l'index maison par `identityHashCode` est **déjà retiré** ; une vue entière se déclare désormais `ZListCustomLayout.forEntity<T>(…)`.
- **Les onze autres lots (A2–A5, B1–B5, C1–C2) et la Phase D étaient déjà livrés** depuis `7f3026e06` (v0.93.0, 2026-08-13), vérifiés lot par lot sur disque le 2026-08-23 : rien à livrer, rien à retirer côté hôte au-delà de ce que le handoff v0.93.0 annonçait. Le plan de parité est clos.

## 5. Vérification

Rejouée par l'orchestrateur, workstreams au repos, depuis le dossier de chaque paquet :
- `melos run generate` : **0 `.g.dart` modifié**. `melos run analyze` repo-wide : **0 erreur**. `melos run verify` : **RC=0** — douze gates, dont `reserved-keys` (sonde `ZChatRouter`), `web` (déterminisme sous Node), graphe `ACYCLIQUE OK` / `CORE OUT=0`, `consumption-recipe` à **41 paquets**.
- Balayage des **41 paquets** : 40 verts ; `zcrud_generator` rouge **environnemental** (`Isolate.packageConfig` via `build_test`, identique aux versions précédentes).
- Comptes : `zcrud_chat_kernel` **635** VM / **472** Node (541 → 587 → 635) ; `zcrud_chat` **828 en 26 s** (788 → 828) ; `zcrud_chat_firestore` **20** ; `zcrud_core` **2 383** ; `zcrud_screen` **354**.
- Campagnes R3 : K1 20 · K2 35 · A 16 · F 4 · P1-A1 12 — **87 injections, 87 rouges par assertion**, restauration par copie, empreintes identiques, résidus zéro (grep montré).
