# Handoff **v0.35.0** — le patron de commande externe atteint les quatre derniers états

> **Tag à épingler : `v0.35.0`** · livraison **additive**, aucune rupture d'API.
> Achève ce qui a commencé avec CR-IFFD-38 : le patron était livré, quatre états du socle ne
> l'acceptaient toujours pas.

---

## 1. Ce qui devient commandable

| Composant | Nouveau paramètre | Ce que vous ne pouviez pas faire |
|---|---|---|
| `ZChatMessageTile` | `expandController` | poser un bouton **« tout déplier »**, ou déplier le message ciblé par une recherche |
| `ZChatConversationSelection` | `activeController` | **sortir** du mode sélection — l'entrée se fait par appui long, la sortie n'était commandable que de l'intérieur |
| `ZCountryFieldWidget`, `ZCurrencyField`, `ZStateField` | `openController` | ouvrir le sélecteur au retour d'une validation qui pointe le champ fautif, ou le fermer quand l'utilisateur navigue ailleurs |

**Sans contrôleur, comportement strictement inchangé.** Tous les paramètres sont optionnels.

🔵 **Le dépli d'un message boucle la boucle** : c'est le cas d'origine de votre CR-38. Nous avions
corrigé son bug de shadowing en `v0.30.0` — mais **sans jamais le rendre commandable**. Le socle
refaisait donc, sous une autre forme, exactement ce que votre CR reprochait.

## 2. Deux arbitrages, et pourquoi

**Le contrôleur de sélection commande le MODE, jamais le contenu.** L'invariant *« sortir du mode
vide la sélection »* a été déplacé là où le mode change, **quel que soit le chemin**. Le laisser à
son ancien emplacement l'aurait rendu **inapplicable à votre commande** : la barre aurait disparu en
laissant des identités cochées derrière elle, qu'une réouverture aurait ressuscitées.

**Les sélecteurs `intl` sont internes** — y poser le contrôleur seul aurait donné un **paramètre
mort**, inatteignable depuis chez vous. Il est relayé depuis les trois champs exportés, **en
constructeur uniquement** : la fabrique par registre sert *toutes* les instances d'un même type et
partagerait donc un contrôleur unique entre plusieurs champs.

⚠️ **`readOnly` prime sur la commande** : un champ en lecture seule ne déplie jamais, **et le refus
est réécrit dans votre contrôleur** — sans quoi vous le croiriez ouvert alors qu'il est fermé.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — aucun paramètre requis, aucun rendu changé |
| vous voulez commander l'un de ces états | posséder le contrôleur dans un champ de `State` (via `ZDisplayStateOwnerMixin`) et le passer |

⚠️ **Rappel toujours valable** : vos **trois** contrôleurs créés dans `build`
(`menu_item_widget.dart:114,248`, `ai_assistant/widgets/folder_conversations_widget.dart:201`)
seront **refusés** par le mixin. Ce n'est pas une rupture de notre part — c'est votre bug rendu
visible, et nous avons choisi de l'imposer plutôt que de l'industrialiser.

## 4. 🟢 Ce que la vérification croisée a établi — et qui aurait pu mal tourner

Un lot a découvert que **lier au montage avec une valeur nulle est un no-op silencieux** : la liaison
sort tôt sur identité, et le **premier rebuild la répare**. Ses gardes commandaient après
stabilisation : elles mesuraient donc la liaison **d'après-rebuild**, jamais celle du **montage**.
La fenêtre non couverte était exactement le cas **« restauration d'état »**.

Nous avons alors testé les **gardes jumelles** des autres paquets, par injection :

| Paquet | Verdict |
|---|---|
| `zcrud_flashcard` | 🔴 attrape (8 tests) |
| `zcrud_study` | 🔴 attrape |
| `zcrud_chat` | 🔴 attrape |
| `zcrud_intl` | 🟢 **était aveugle** — retendue |

**L'angle mort était local, pas systémique.** Nous le disons parce que nous aurions volontiers cru
l'inverse : c'est le genre de conclusion qui ne vaut que mesurée.

Deux autres gardes de nous **trouvées inertes** : un compteur qui ne pouvait pas dépasser 1 (donc
vert sur *tout* défaut), et deux clauses d'exemption **inatteignables** qui masquaient un vrai défaut
de motif — il prenait une **signature de fonction** pour une construction.

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_chat` **286** (+17) · `zcrud_intl` **183** (+14).
**22 injections R3**, toutes qualifiées.

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications **locales**.

## 6. Ce que nous savons ne pas avoir couvert

* 🔴 **Une cinquième famille d'état échappe au patron** : le dépli de groupe du chat porte une
  **table** de booléens, que ni le contrôleur de bascule ni celui d'index ne modélisent. C'est la
  prochaine limite connue.
* **`ZPhoneFieldWidget` et `ZAddressFieldWidget` ne relaient pas la commande** : ce sont des champs
  **composés** (deux sélecteurs chacun), un paramètre unique y serait ambigu. Leurs sélecteurs
  acceptent déjà le paramètre — il ne manque que le nommage. Nous n'avons pas tranché seuls.
* **La fabrique par registre n'expose pas la commande** : un hôte qui construit ses champs par ce
  chemin doit passer par le constructeur direct.
* **Un contrôleur de dépli accepté sans hauteur de repli configurée est sans effet visible**, et
  **rien ne le signale** — vous auriez un bouton mort. À connaître.
* **Aucune notification sortante ajoutée** : qui veut *savoir* sans *commander* doit quand même
  créer un contrôleur. Asymétrie assumée avec `ZFlashcardReviewCard`, qui offre les deux.
