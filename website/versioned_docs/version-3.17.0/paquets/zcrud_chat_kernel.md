---
title: zcrud_chat_kernel
description: Noyau Dart pur de conversation IA — modèle neutre, contrat d'action, vocabulaire d'outils, ports du Notebook, transport SSE et catalogue de routeurs.
---

# zcrud_chat_kernel

## Rôle

`zcrud_chat_kernel` est le paquet **kernel** de la capacité chat : il porte,
en Dart pur, le modèle neutre de conversation (`ZChatConversation`,
`ZChatMessage`, la famille ouverte `ZContentBlock`) et le contrat
d'**action** de message (intentions scellées + répartiteur unique). Il
déclare aussi les **ports** — génération, gestion de conversation, saisie
assistée, diffusion vocale, transcript, artefacts du Notebook — que les
paquets satellites et les applications hôtes implémentent, le **vocabulaire
d'outils** déclaratif, un transport **SSE** prêt à brancher et le
**catalogue de routeurs IA** (fournisseur et modèle par tâche, gouvernance
par plan). Il ne dépend que de `zcrud_core` (surface pur-Dart) et n'importe
ni Flutter, ni aucun autre paquet `zcrud_*`.

## Quand l'utiliser

- Pour traiter des conversations IA **hors Flutter** : migration de données,
  traitement serveur, script, test unitaire rapide sous `dart test`.
- Pour écrire un **nouveau satellite** de rendu ou d'intégration (un backend
  de génération, un adaptateur de persistance) qui n'a besoin que du modèle
  et des contrats, sans tirer de dépendance UI.
- Pour implémenter un **port** (`ZChatGenerationPort`, `ZChatTranscriptPort`,
  `ZChatArtifactStorePort`…) côté application, en s'appuyant sur des types
  stables et testés.
- Pour déclarer les **routeurs IA** de l'application — quel fournisseur, quel
  modèle et quels replis pour quelle tâche — et récupérer ce catalogue depuis
  un backend.

## Quand ne pas l'utiliser

- Pour construire un écran de chat : passez par `zcrud_chat`, qui assemble ce
  kernel avec un contrôleur Flutter-natif à réactivité granulaire (invariant
  [AD-2](../concepts/invariants.md#ad-2)).
- Pour du rendu Markdown/LaTeX ou une intégration Syncfusion AI AssistView :
  ce sont les rôles de `zcrud_chat_markdown` et `zcrud_chat_syncfusion`, tous
  deux satellites de ce kernel.

## Le vocabulaire d'outils {#outils}

Les outils d'une application (bascules, cycles, choix) se déclarent en
**données** :

- `ZChatToolEntry` déclare un outil — clé opaque, section, conditions ;
- `ZChatToolState` porte son état, par **nature** ouverte (`kind`) : bascule
  (`toggle`), cycle à N pas (`cycle`), choix (`choice`) — et toute nature
  d'hôte, relue défensivement (un `kind` inconnu ne casse jamais la lecture,
  [AD-10](../concepts/invariants.md#ad-10)) ;
- `ZChatToolCatalog` résout l'ensemble : une entrée fermée par une exclusion
  déclarative porte son `disabledReasonToken` (grisée **avec sa raison**,
  jamais masquée — `isEnabled` en découle), et `searchRecommended` signale
  quand une recherche vaut mieux qu'un long défilement.

Les réglages **standard** de génération (longueur, budget, corpus…) ne sont
pas des outils : un même réglage ne doit exister qu'en un seul état, celui
qui part dans la requête.

## Les ports du Notebook {#notebook}

Un Notebook — un fil dont les réponses portent des artefacts générés — se
décrit entièrement par des ports neutres :

- **`ZChatArtifactRegistry`** / **`ZChatArtifactDeclaration`** /
  **`ZChatArtifactVerb`** : le registre des artefacts que l'application
  connaît — déclaration pure (clés opaques, verbes), partageable entre
  écrans.
- **`ZChatArtifactGenerationPort`** : la génération d'un artefact, avec
  `ZChatArtifactGenerationRequest` (dont `providerId` **typé** — le
  fournisseur ne voyage jamais dans `extra`).
- **`ZChatArtifactStorePort`** : le stockage, avec un contrat **impératif**
  de suppression : après `delete`, `read` rend `null`, **quel que soit
  l'ordre** des écritures concurrentes — une suppression incomplète ne fait
  jamais réapparaître l'artefact.
- **`ZChatTranscriptPort`** : le fil persistant — lecture en
  `Stream<List<ZChatMessage>>`, écriture par `append`/`update` en
  `ZResult` ([AD-5](../concepts/invariants.md#ad-5)).

## Le transport SSE {#sse}

`ZChatSseStreamPort(open:, decode:, onClose:)` transforme un flux d'octets
Server-Sent Events en flux de chat : l'**hôte ouvre et authentifie** la
requête (`open`), le socle découpe les lignes, retire le cadrage `data:` et
délègue le décodage de chaque événement (`decode`). L'annulation ferme le
flux une seule fois (`onClose`).

## Le catalogue de routeurs {#routeurs}

Le [routage par tâche](../concepts/routage-par-tache.md) repose sur une
entité et sa résolution, entièrement portées ici :

- **`ZChatRouter`** est une entité canonique (`ZEntity`, extensible) :
  identité, activation, `tier` opaque (le plan d'abonnement requis), modèle
  et replis **racine**, effort de calcul, et `routes` — une `ZChatRouteSpec`
  par tâche. Elle est **éditable par l'éditeur zcrud sans code hôte** :
  `$ZChatRouterFieldSpecs` et `registerZChatRouter(registry)` sont fournis,
  les routes s'éditent en sous-listes et les replis en sous-listes
  **imbriquées** de références de modèle.
- **`ZChatModelRef {providerId?, modelId}`** nomme un modèle partout —
  opaque, jamais interprété. La lecture tolère un jeton `"provider:model"`
  et une chaîne nue ; la forme écrite est toujours la liste de maps.
- **`ZChatRouteSpec`** décrit une tâche : `taskKey` (la clé de style de la
  requête), `routeName`, modèle, replis, effort, paramètres, jetons d'accès
  requis, `handlerId`.
- **`ZChatRouteResolution.from(router, taskKey)`** résout : repli tâche →
  racine, le couple (modèle, replis) repliant **ensemble** ; `toRequest`
  applique le résultat à une requête sans jamais recouvrir un choix
  explicite de l'appelant (effort : `base ?? route ?? racine` ; un réglage
  utilisateur reste un remplacement).
- **`ZChatRouteGate`** gouverne : le défaut est **`ZDenyAllChatRouteGate`**
  — un catalogue déclaré sans gate refuse toute route
  (`ZChatFailureCodes.upgradeRequired`, le même code qu'un backend
  émettrait). L'ouverture se **déclare** : `const ZAllowAllChatRouteGate()`.
  Côté client, le gate reste un pré-check UX ; l'autorité est le serveur.
- **Le catalogue est récupérable et composable** : sources statique, sur
  dépôt (`ZReadOnlyRepository<ZChatRouter>`) ou distante
  (`ZChatRemoteRouteCatalogSource(open:, decode:)` — l'hôte ouvre et
  authentifie, le socle décode) ; décodeur **défensif** à formes déclarées
  (`canonical`, enveloppe nommée, paires à suffixe `<tâche>Model`), dont
  `taskAliases` traduit les noms de tâche historiques d'un document vers les
  clés de style réelles ; `ZChatTtlRouteCatalog` (TTL, cache négatif,
  service du périmé sur panne distante) et `ZChatCascadeRouteCatalog` (les
  sources dans l'ordre déclaré, repli final **déclaré par l'hôte** — jamais
  inventé par le socle).
- **`ZChatRouteHandlers`** associe un identifiant de gestionnaire ou de
  fournisseur à un port concret — la répartition vit dans les ports routés
  de `zcrud_chat`.

Enfin, **`ZChatGenerationRequest.providerId`** transporte le fournisseur sur
toute requête de génération, opaque au même titre que `modelId`, et
`copyWith` est l'**unique** voie de recopie de la requête — les dérivations
(`withSettings`, résolution de route) en sont des appelants.

## Types clés

| Type | Rôle |
|---|---|
| `ZChatConversation` / `ZChatMessage` | Entités canoniques du chat, extensibles par composition (invariant [AD-4](../concepts/invariants.md#ad-4)). |
| `ZContentBlock` | Famille ouverte de blocs de contenu d'un message. |
| `ZChatAction` / `ZChatActionDispatcher` | Intentions scellées sur un message et répartiteur unique d'exécution. |
| `ZChatGenerationPort` / `ZChatStreamPort` | Ports de génération de réponse, one-shot et streaming ; la requête porte `modelId` et `providerId` opaques. |
| `ZChatSseStreamPort` | Transport SSE : ouverture et authentification par l'hôte, décadrage et annulation par le socle. |
| `ZChatToolEntry` / `ZChatToolState` / `ZChatToolCatalog` | Vocabulaire d'outils déclaratif : natures ouvertes, exclusions avec raison, seuil de recherche. |
| `ZChatArtifactRegistry` / `ZChatArtifactGenerationPort` / `ZChatArtifactStorePort` / `ZChatTranscriptPort` | Les quatre ports du Notebook : registre déclaratif, génération, stockage sans résurrection, fil persistant. |
| `ZChatRouter` / `ZChatModelRef` / `ZChatRouteSpec` | L'entité routeur — éditable par l'éditeur zcrud —, la référence de modèle et la route par tâche. |
| `ZChatRouteResolution` / `ZChatRouteGate` / `ZChatRouteCatalogPort` | Résolution par tâche, gouvernance refusant par défaut, et le port de catalogue (sources, TTL, cascade). |
| `ZChatResponseConfidence` | Palier de confiance dérivé des verdicts serveur, jamais fabriqué sans signal. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_chat_kernel/README.md) — installation, démarrage rapide, API complète.
- [Routage par tâche](../concepts/routage-par-tache.md) — pourquoi un catalogue de routeurs, et comment il se gouverne.
- [zcrud_chat_firestore](zcrud_chat_firestore.md) — le dépôt Firestore des routeurs, en une fabrique.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — le patron kernel/satellite.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
