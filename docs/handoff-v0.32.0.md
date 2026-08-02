# Handoff **v0.32.0** — CR-IFFD-38 & 39

> **Tag à épingler : `v0.32.0`** · livraison **additive**, aucune rupture d'API.
> Vos deux demandes sont servies — **et toutes deux sous-estimaient votre propre besoin**. Le § 1 et
> le § 3 disent en quoi, mesures à l'appui.

---

## 1. CR-38 — un patron, pas un correctif

`ZFlashcardReviewCard` accepte désormais un `revealController` **optionnel**. Sans lui, comportement
**strictement inchangé** — c'est le défaut que vous demandiez, et il reste le bon.

### Ce que nous avons trouvé en vérifiant votre CR

1. 🔴 **Vous avez omis un quatrième site de commande, vif** : le bouton **« Masquer la réponse »**
   (`flashcard_repetition_widgets.dart:261-270`), posé sur la **face arrière**, dans un `Stack` du
   **parent** — donc hors de la carte. Un correctif limité à la carte ne l'aurait pas servi.
   Le nôtre le sert : le contrôleur est détenu **hors** du widget, donc n'importe lequel de vos
   widgets le commande.
2. 🔴 **Un de vos trois sites passe le contrôleur dans le vide** : `flashcard_widgets.dart` déclare
   `flipCardController` et ne l'utilise **jamais** dans son corps (2 occurrences, toutes deux
   déclaratives). Vous avez aujourd'hui un paramètre inerte que rien ne signale.
3. 🔴 **Votre garde ne mord pas.** `test/w8m/review_card_reveal_command_test.dart:49` compte les
   occurrences du texte `flipCardController:` sur tout `lib/`, **déclarations comprises** : elle
   resterait **verte avec zéro passage réel**. Une mesure valable ne compte que les arguments nommés
   aux **sites d'appel** — ou mieux, monte le widget et vérifie que la commande **agit**.

### Le motif est général : 7 instances vives chez vous, 5 familles d'état

révélation (**deux** boutons) · carte courante d'un carrousel piloté par des flèches externes ·
**onglet actif** (sommaire en tiroir, barre d'outils, barre d'onglets parallèle) · page d'un
visionneur commandée par un champ « aller à la page » · déplié/replié (en-tête **et** chevron).

Nous avons donc livré **`ZDisplayState`** dans `zcrud_core` — contrôleurs de bascule et d'index,
jeton de possession, liaison. Deux propriétés qui comptent :

* **le contrôleur est la source de vérité, pas un miroir** : la liaison ne stocke aucune copie.
  Deux états ne peuvent pas diverger *parce qu'il n'y en a qu'un* ;
* **un contrôleur accepté mais jamais consommé lève une assertion** — votre cas n°2 devient visible.

### ⚠️ Ceci vous concerne si vous avez contourné — lisez avant de migrer

**Trois de vos contrôleurs sont créés dans `build`** (`menu_item_widget.dart:114,248`,
`ai_assistant/widgets/folder_conversations_widget.dart:201`), donc **écrasés au rebuild suivant**.
Notre mixin **refusera** ces créations, avec une erreur nommant le contrôleur fautif.

**Ce n'est pas une rupture de notre part : c'est votre bug rendu visible.** Nous avons délibérément
choisi de l'imposer plutôt que de l'accepter — sinon nous industrialisions le défaut.
Le remède : posséder le contrôleur dans un champ de `State` via `ZDisplayStateOwnerMixin`.

🟢 Et votre garde **rougira** quand vous brancherez votre portage. C'est son rôle, pas un incident.

---

## 2. CR-39 — la liste, et les huit opérations qu'elle rend enfin atteignables

Vous demandiez une tuile. Nous avons vérifié que notre socle portait **déjà huit opérations de
conversation** — recherche (avec extraits de messages **et curseur**), épinglage, partage, retrait,
restauration, troncature, retrait **par lot** — et **aucune surface pour les déclencher**.
Elles sont désormais toutes câblables.

### Trois capacités que **ni vous ni lex** n'avez

| Capacité | lex | vous |
|---|---|---|
| **sélection multiple / lot** | route serveur prête, **aucun appel client** | absente |
| **pagination par curseur** | serveur prêt, méthode client **sans appelant** (code mort) | absente, liste non paresseuse |
| **restauration** | soft-delete en base, **aucun chemin d'interface** | aucune |

### Ce que nous n'imposons pas — et c'était votre demande la plus juste

`pinned`, `pinnedAt`, `messageCount` (les nôtres) et `isArchived` (le vôtre) sont **optionnels et non
rendus par défaut, dans les deux sens**. Gardé par machine.

Nous avons aussi refusé de modéliser en **champs** ce qui n'en est pas chez vous : votre « nouveau »
vient d'un **préfixe `[NEW] ` dans le titre**, votre permission d'un `userId != null`. Ce sont des
**prédicats injectables**, pas des colonnes.

🔴 **Le slot qui décide de votre adoption** : `itemWrapper`. Chacune de vos lignes **pulse** tant que
sa génération IA n'est pas finie — un contrôleur d'animation **par ligne**. Ni portable, ni
exprimable en champ. Sans ce slot vous réécriviez la tuile, et notre livraison n'aurait servi à rien.

### Ce que votre liste actuelle ne fait pas, et que la nôtre fait

* **état de chargement distinct de l'état vide** — chez vous l'état vide s'affiche au premier frame
  *à la place* d'un indicateur ;
* **état d'erreur** — inexistant chez vous : une erreur donne un écran vide **indistinguable** de
  « aucune conversation ». Nous testons l'erreur **avant** le chargement (idée reprise de lex, dont
  un flux en échec pendant un rechargement bloquerait sinon l'écran sur le squelette *pour toujours*) ;
* **tri appliqué à la liste réellement rendue** — le vôtre trie une liste, en affiche une autre
  (`conversation_list_widget.dart:176-195`) : vos conversations racine **ne sont pas triées** ;
* **`Semantics` de ligne, ≥ 48 dp garanti, `EdgeInsetsDirectional`** — vous avez **zéro** des trois
  sur tout `lib/ai_assistant/` (greps négatifs). Votre indentation de sous-dossier casse en RTL.

### Ce que nous avons refusé de porter

La suppression **sans confirmation ni recours** de lex — dont la documentation promet un *undo* qui
**n'existe pas**. Notre retrait est **soft**, et `onRestore` le défait : l'annulation est **triviale
sans être forcée**, et nous ne promettons rien que le code ne tienne.

---

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| hôte **passif** | ajouter les paquets à vos `dependency_overrides`. Rien d'autre — aucune rupture. |
| **IFFD, pour CR-38** | ⚠️ déplacer vos **trois** contrôleurs créés dans `build` vers un champ de `State` ; brancher le 4ᵉ site (« Masquer la réponse ») ; retirer le paramètre inerte de `flashcard_widgets.dart` ; **retendre votre garde** (compter les sites d'appel, pas les déclarations). |
| **IFFD, pour CR-39** | remplacer vos ≈ 980 lignes (et non 600 : vous oubliez `folder_conversations_widget.dart` et `conversation_actions_menu.dart`) ; votre `ConversationSearchBar` est **morte** — aucun appelant, la recherche passe ailleurs. |

## 4. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, **36 paquets**, tous gates) ·
`zcrud_core` **1131** · `zcrud_flashcard` **586** · `zcrud_chat` **269**.

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications **locales**.

## 5. Ce que nous savons ne pas avoir couvert

* **5 des 7 instances** du patron ne sont pas raccordées : carrousel, onglets, visionneur,
  déplié/replié vivent dans d'autres paquets. Le patron les couvre ; aucun composant ne l'accepte
  encore. Lot suivant.
* **Pas de balayage latéral** dans la liste : obtenable par `itemWrapper`, non fourni.
* **Le prédicat de recherche par défaut ne cherche que le titre** — le défaut même que nous
  reprochons à lex. Rendu **injectable**, pas corrigé : le socle n'a pas les corps de messages.
* **Aucune garde de rebuild** sur la liste : la virtualisation est prouvée, le coût de la frappe
  dans la recherche ne l'est pas.
* **`ZChatConversationHit` n'a pas de pont typé** vers la liste : le mapping est une recette
  documentée, pas du code testé.
