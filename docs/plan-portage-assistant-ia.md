# Plan — Portage de l'Assistant IA et du Notebook vers zcrud

> Issu de **23 agents d'exploration** (2 workflows, 0 erreur) sur IFFD, lex_douane et zcrud.
> Rapports bruts : `/tmp/zcrud-explore/*.md`. Toutes les affirmations structurantes ci-dessous ont été
> **re-vérifiées sur disque par l'orchestrateur** — un rapport d'agent n'est pas une preuve.

---

## 0. Le constat qui reformule la demande

**L'onglet « Notebook » d'IFFD *est* la surface de conversation IA.** Ce n'est pas un bloc-notes.

Chaîne vérifiée : `folder_details_page.dart:1104` (`TabBarView`) → deuxième enfant =
`FolderExplanationPage` → qui importe `chatbot_controller.dart`, `chatbot_conversation.dart`,
`chatbot_conversation_screen.dart` et porte un `chatContext`.

⇒ **Il n'y a pas deux chantiers mais un seul.** La demande « porter l'onglet IA » et « reproduire le
Notebook » désignent le même objet.

🔴 **Arbitrage produit à trancher AVANT tout code** : veux-tu *en plus* un vrai notebook à cellules
(mêlant notes rédigées et échanges IA) — que **ni IFFD ni lex ne possèdent** ? C'est une conception
neuve, pas un portage. Les deux options sont légitimes ; elles n'ont pas le même coût.

---

## 1. Le point qui rend l'abstraction possible

Les deux synthèses se contredisaient : l'une concluait « incompatibles au niveau widget », l'autre
« convergents en pratique ». **Tranché sur disque : la seconde a raison.**

`chatbot_conversation_screen.dart:3423-3436` — IFFD consomme de `SfAIAssistView` :
`messages:`, `composer: AssistComposer.builder(builder: _buildComposer)`, `placeholderBehavior`,
`placeholderBuilder`.

⇒ **IFFD ne consomme que le SQUELETTE de liste.** Tout le contenu passe par ses propres builders.
La surface Syncfusion réellement dépendue est mince — donc un `ZChatRenderer` neutre peut couvrir
IFFD **et** lex sans que le socle connaisse Syncfusion.

C'est exactement le patron `ZListRenderer` (Syncfusion isolé dans `zcrud_list`) déjà éprouvé.

---

## 2. Généalogie — et ce qu'elle change

**lex descend d'IFFD** (repris de ses fonctionnalités, pas de son code). Conséquence sur la lecture :

| Observation | Lecture naïve | Lecture corrigée |
|---|---|---|
| Ressemblance lex/IFFD | convergence, fort signal | **héritage — attendu, peu informatif** |
| Divergence lex/IFFD | à réconcilier à mi-chemin | **lex a jugé nécessaire de faire autrement** |
| Capacité chez lex seul | spécificité à laisser app-side | **évolution postérieure — souvent générique** |

⇒ Personas, réponses hors ligne, TTS, pièces jointes, sources, feedback, thinking structuré,
export multi-format n'existent pas chez IFFD **parce qu'ils sont venus après**. Ce sont des candidats
sérieux au socle, pas des particularités douanières.

⚠️ **Mais lex est en développement actif.** Une API publique zcrud est un engagement **irréversible**.
Ne remonter que ce qui est **stabilisé** ; pour le reste, poser un seam large plutôt qu'un modèle figé.
(Précédent : CR-67 → CR-70..75 — une façade livrée sur une cible qui a bougé ensuite.)

---

## 3. Architecture proposée

### 3.1 Packages (AD-1, graphe acyclique, CORE OUT = 0)

| Package | Rôle | Dépendances tierces |
|---|---|---|
| `zcrud_chat` | domaine + ports + rendu neutre par défaut | **aucune** |
| `zcrud_chat_syncfusion` | adapter optionnel (IFFD) | Syncfusion |
| `zcrud_menu` | menus contextuels découplés trigger/contenu | aucune (adapters à part) |

🔴 Ni Syncfusion ni package de menus dans `zcrud_core` ou `zcrud_chat` — AD-57.

### 3.2 Les seams — le cœur

Sur le patron **exact** de `ZListRenderer` / `ZReorderRenderer` / `ZGradientResolver` déjà en place :

- **`ZChatRenderer`** — l'app fournit son moteur de rendu de conversation (Syncfusion, fait maison…) ;
- **`ZMenuRenderer`** — l'app fournit son package de menus ;
- **`ZChatTransformPort`** — les transformations (résumer, expliquer, reformuler…) ;
- **`ZChatStreamEvent`** — événements de flux, modèle scellé porté de lex.
  🔵 Plus robuste que les sentinelles textuelles d'IFFD (`<RAG_THINKING>` dans le corps du message).

### 3.3 Modèle de domaine

`ZChatMessage` avec `contentBlocks: List<ZContentBlock>` — **noyau fermé minimal** + extension ouverte
par `ZTypeRegistry` (AD-4), plutôt que de figer les 12 variantes scellées de lex.
`ZChatSource` réutilise le `ZSourceRegistry` **déjà existant** — pas de doublon.

### 3.4 Optionnalité

Ports et callbacks **nullables** sur une configuration d'actions — même patron que
`ZFlashcardAnswerInput.evaluationPort` / `hintPort`, déjà en production. Une app porte ce qu'elle veut.

### 3.5 Alignement visuel (FR-26)

Tokens **incolores** + resolver dans le socle ; palette déclarée **app-side**. C'est la décision déjà
actée et éprouvée par l'epic VIS — rien de neuf à inventer.

---

## 4. Lots

**Séquentiels (écrivent `zcrud_core` — jamais deux à la fois) :**

| Lot | Contenu |
|---|---|
| **L0** | modèle de chat neutre ⚠️ *trancher scellé-contre-registre AVANT* |
| **L1** | ports IA du chat |
| **L2** | `ZChatController` (`ChangeNotifier` pur — AD-2) |

**Parallélisables ensuite (packages disjoints) :** `zcrud_chat` (rendu neutre) · pièces jointes ·
export · menu contextuel découplé.

**Orthogonal :** Notebook — **bloqué sur l'arbitrage du § 0**.

---

## 5. Risques

### 🔴 Risque n°1 — ce portage ne sera **PAS** additif pour IFFD

IFFD devra migrer son couplage par callbacks **et ses données de message** (champs plats → blocs
typés, donc migration Firestore). Annoncer « additif » serait **la quatrième occurrence** de l'erreur
déjà documentée trois fois dans `CLAUDE.md` : affirmer une propriété sur *l'hôte* en n'ayant vérifié
qu'une propriété sur *notre code*.

### ⚠️ Faux-ami vérifié — `WorkflowEffort`

Même nom, sémantiques **incompatibles** :

| | valeurs | sens |
|---|---|---|
| lex (`chat_enums.dart:20-26`) | `concis`, `standard`, `detaille` | **longueur de réponse** |
| IFFD (`ai_routers_page.dart:24-28`) | `low`, `medium`, `high` | **effort de calcul** |

Les fusionner naïvement produirait un enum qui ne veut rien dire. Ce sont **deux concepts distincts**.

### ⚠️ L'embedding hors ligne de lex est un **STUB**

Le patron est portable, **le code ne l'est pas**, et il ne doit jamais être présenté comme prouvé.

### ⚠️ IFFD n'a **aucun** `Semantics` sur son chat

Vérifié : **0 occurrence** dans `chatbot_conversation_screen.dart` et `discovry_ai_page.dart`.
Dette à **ne pas reproduire** — une réponse qui arrive en streaming doit être annonçable.

### ⚠️ Précédent direct — `ZSmartNoteEditor`

Livré, puis **jugé inutilisable : IFFD en a réécrit 343 lignes**. Même motif que CR-IFFD-37
(`belowSubtitle` correct mais inutilisable à leur densité). Tout futur widget de notebook y est exposé.

---

## 6. Ce qu'une garde R3 devra vérifier — et qu'un test naïf ne verrait pas

Leçons accumulées, applicables telles quelles :

1. **Le coût** d'une surface, pas seulement son rendu (précédent CR-37 : 130-210 dp invisibles) ;
2. **l'absence d'exception de layout** à largeur et hauteur contraintes réelles (800 dp, 210 dp) ;
3. **la virtualisation par son mécanisme**, pas par comptage — le viewport culle des deux côtés ;
4. **l'annonce** d'un contenu qui arrive progressivement (live region), pas sa seule présence ;
5. **la neutralité par défaut** : sans renderer injecté, rendu strictement inchangé ;
6. **l'absence de fuite** d'un type Syncfusion hors de son adapter (grep négatif prouvé).

---

## 7. À trancher avant de lancer quoi que ce soit

1. **Notebook** : conversation IA seule (portage) ou notebook à cellules (conception neuve) ?
2. **Modèle de blocs** : scellé fermé (sûr, rigide) ou registre extensible (souple, AD-4) ?
3. **Périmètre du premier lot** : viser la parité IFFD, ou la maturité lex (plus riche mais mouvante) ?
