---
title: "Concept : routage par tâche"
description: Un catalogue de routeurs IA déclaré — fournisseur et modèle par tâche, gouvernance par plan refusant par défaut, catalogue récupérable avec TTL et cascade.
sidebar_position: 8
---

# Routage par tâche

Une application de chat IA ne parle pas à « un modèle » : elle exécute des
**tâches** — répondre, résumer, générer des flashcards — et chaque tâche
peut appeler un fournisseur, un modèle, des replis et des paramètres
différents. Deux modes de transport coexistent dans la nature : un endpoint
unique à corps riche, et **une route par intention**. zcrud fait du second
un citoyen de première classe, parce qu'il porte naturellement la
**gouvernance** (une route se rattache à un plan d'abonnement) et la
**déclaration par tâche** — sans jamais interpréter les identifiants de
fournisseur ou de modèle, qui restent opaques.

Tout le domaine vit dans [zcrud_chat_kernel](../paquets/zcrud_chat_kernel.md#routeurs) ;
la moitié écran dans [zcrud_chat](../paquets/zcrud_chat.md#routage) ; la
persistance Firestore dans
[zcrud_chat_firestore](../paquets/zcrud_chat_firestore.md).

## L'entité : `ZChatRouter` {#entite}

Un **routeur** est une entité canonique : identité, activation, `tier`
opaque (le plan requis), un modèle et des replis **racine**, et des
`routes` — une par tâche (`ZChatRouteSpec`). Chaque modèle est nommé par un
`ZChatModelRef {providerId?, modelId}` : le fournisseur voyage **par tâche
et par repli**, jamais interprété par le socle.

L'entité est **éditable par l'éditeur zcrud sans code hôte** : ses
`ZFieldSpec` et son enregistrement au registre sont fournis — un écran
d'administration des routeurs est un `ZCrudScreen<ZChatRouter>` de quelques
lignes, routes en sous-listes et replis en sous-listes imbriquées.

## La résolution : par `style.kind` {#resolution}

La clé de tâche d'une requête est le **`kind` de son style** : la résolution
(`ZChatRouteResolution.from(router, taskKey)`) cherche la route de cette
tâche et replie sur la racine — le couple (modèle, replis) replie
**ensemble**, jamais le modèle d'une route avec les replis d'une autre.
Appliquée à une requête, la résolution ne recouvre jamais un choix explicite
de l'appelant : l'effort suit `requête ?? route ?? racine`, et un réglage
utilisateur reste un remplacement.

La résolution s'exécute **dans le cycle d'envoi** du contrôleur — avant
l'état, le message optimiste et tout appel de port : la requête qui part est
déjà routée, et aucun site d'appel ne recopie « le modèle courant ».

## La gouvernance : refus par défaut {#gouvernance}

`ZChatRouteGate` répond à une seule question : cette tâche est-elle
autorisée pour ce plan ? Le défaut est **`ZDenyAllChatRouteGate`** — un
catalogue déclaré **sans** gate refuse tout envoi, avec le code
`upgradeRequired`, le même qu'un backend émettrait ; l'ouverture se déclare
(`const ZAllowAllChatRouteGate()`), elle n'est jamais un défaut silencieux
(même posture que l'ACL de l'écran CRUD,
[AD-16](invariants.md#ad-16)). Un refus laisse la saisie **intacte** :
l'échec est publié, rien n'est perdu.

Le gate client reste un **pré-check UX** — éviter d'envoyer une requête
condamnée, griser une entrée avec sa raison. **L'autorité est le serveur** :
son refus (403) est absorbé sous le même code d'échec, et l'interface le
présente identiquement.

## Le catalogue : récupérable, avec repli déclaré {#catalogue}

Les routeurs viennent d'où l'application décide, par **sources composables** :

| Source | Rôle |
|---|---|
| statique | des routeurs déclarés dans le code |
| sur dépôt | un `ZReadOnlyRepository<ZChatRouter>` — Firestore via [zcrud_chat_firestore](../paquets/zcrud_chat_firestore.md), ou tout autre |
| distante | `ZChatRemoteRouteCatalogSource(open:, decode:)` — l'hôte ouvre et authentifie le HTTP, le socle décode |

Le **décodeur est défensif** ([AD-10](invariants.md#ad-10)) : un routeur
corrompu est compté et écarté, jamais la liste perdue. Les formes de
document se **déclarent** (canonique, enveloppe à routes nommées, paires à
suffixe `<tâche>Model`/`<tâche>FallbackModels`), et `taskAliases` traduit
les noms de tâche historiques d'un document vers les clés de style réelles —
un unique point de traduction, à la place d'une table recopiée chez chaque
consommateur.

Au-dessus des sources : `ZChatTtlRouteCatalog` (TTL, cache négatif, service
du **périmé** plutôt que rien sur panne distante, invalidation ciblée) et
`ZChatCascadeRouteCatalog` (les sources dans l'ordre déclaré ; une panne
distante passe à la suivante ; l'épuisement rend le repli **déclaré par
l'hôte**, sinon un échec — le socle n'invente jamais un routeur par défaut).

## La session : partagée par le Chat et le Notebook {#session}

Côté écran, `ZChatRouteSession` (possédée par l'hôte) expose des tranches
granulaires — le routeur choisi, et **la route de chaque tâche** : seule la
route qui change notifie ([AD-2](invariants.md#ad-2)). Aucun membre de la
session n'envoie quoi que ce soit ; l'envoi reste au contrôleur, la
répartition aux **ports routés** (`handlerId → providerId → routeName →
repli`).

Les deux écrans assemblés — conversation et Notebook — partagent le même
assembleur : la même session alimente le sélecteur de routeur du composer et
le choix du repli par tâche dans la feuille de réglages. Sans session ni
résolveur déclarés, rien ne change : la requête reçue par le port est
identique à celle du builder.

## Voir aussi

- [zcrud_chat_kernel](../paquets/zcrud_chat_kernel.md#routeurs) — l'entité, la résolution, le gate et les sources.
- [zcrud_chat](../paquets/zcrud_chat.md#routage) — la session, les ports routés et le câblage dans le cycle d'envoi.
- [zcrud_chat_firestore](../paquets/zcrud_chat_firestore.md) — la persistance du catalogue.
- [Invariants d'architecture](invariants.md) — AD-2, AD-10 et AD-16, à l'œuvre ci-dessus.
