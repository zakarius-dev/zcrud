# Handoff **v0.58.0** — CR-IFFD-75 + 76 : les actions se séparent, le composer s'assemble

> **Tag à épingler : `v0.58.0`** · strictement additif, aucune rupture d'API.
> 🔴 **IFFD : vous avez 64 lignes d'assemblage à retirer** (§ 3) — c'est le cœur de ce lot.

---

## 1. CR-75 — « RéinitialiserFermer »

Votre analyse était juste, y compris sur la raison pour laquelle nos gardes ne pouvaient pas
le voir : **le plancher de 48 dp est une borne BASSE**. Il garantit qu'une cible est
atteignable, rien sur la lisibilité quand un libellé long fait grandir la boîte au-delà. Et le
défaut est **invisible dans la langue de développement** (`Reset`/`Close` restent sous 48 dp).

**Corrigé dans la primitive**, pas seulement dans cet en-tête — vous le pressentiez :
dégagement directionnel de 8 dp de chaque côté du libellé, actions `Flexible`. Réglable par
`ZChatSettingsSheet.actionSpacing` ; jeton `chatSettingsActionGap` listé pour `zcrud_core`.

**La règle que vous proposiez est inscrite** au dartdoc, à côté de celle de CR-74 :
*deux cibles adjacentes restent visuellement distinctes indépendamment de la longueur de leur
libellé*.

### Vos trois « non mesuré », mesurés
* **RTL** : ordre inversé prouvé, écart tenu.
* **Petit écran (280 dp)** : aucun débordement — et 🔵 **découverte d'un débordement
  PRÉEXISTANT de 58 px** dans la rangée Rapide/Équilibré/Profond du budget, corrigé au passage.
* **Autres surfaces** : grep négatif montré — la primitive ne sert nulle part ailleurs, et une
  garde le verrouille désormais.

## 2. CR-76 — les six pièces et l'assemblage

Votre démonstration a emporté la décision : vous avez introduit **quatre défauts** en
assemblant des pièces correctes, et aucun n'était une inattention. **Vos quatre défauts sont
devenus les tests d'acceptation du lot.**

### Les six pièces absentes, livrées
`ZChatComposerSurface` (conteneur — il consomme les constantes que **vos deux références
faisaient déjà converger**), `ZChatComposerPickerTrigger` + contrat opaque, bascule
« Réfléchir » + badge d'effort, bascule « Internet » (sur `kZChatCapabilityWebSearch`),
« Outils » + compteur, **STOP** et **bandeau d'édition**.

🔵 **Le STOP n'a demandé aucun arbitrage** : le verbe existait déjà —
`runAction(ZChatCancelAction(requestId:))`. Le bouton le câble ; **G-CH1 reste intacte**,
aucun membre ajouté au contrôleur.

### `ZDefaultChatComposer` — vos quatre défauts, neutralisés
| Votre défaut | Ce que fait l'assemblé |
|---|---|
| ① feuille montée dans le créneau `tools` (débordement 149 px) | **détectable** : assertion debug — le créneau est une *bande*, le déclencheur ouvre la feuille |
| ② `settings:` oublié ⇒ portée non transmise | **inexprimable** : paramètre requis non-nullable, plus une preuve comportementale (la requête part avec réglages **et** portée) |
| ③ badge en `Positioned` volant le tap | badge **dans** le hit-test de la cible — tap mesuré sur le rect du badge, socle et Material |
| ④ 3 chips d'effort | **déclencheur unique à menu** — la forme lex |

Breakpoint mobile consommé (libellés masqués, badges gardés sous 400 dp), seuil réglable.
`ZChatComposer` reste **intact** : l'assemblé est un widget nouveau, opt-in — un hôte passif ne
bouge pas.

Le rendu Material des nouvelles pièces vit dans `zcrud_chat_material` (`ZChatMaterialComposer`),
cohérent avec le FAB et les chips.

### Votre troisième question, tranchée
Bascules **en bande ET en feuille** : les deux lisent et écrivent le **même**
`ZChatSettingsController`. Deux surfaces, **un seul état** — gardé dans les deux sens. C'est
l'inverse du « deux sites pour un réglage » que vous redoutiez.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| 🔴 **IFFD** | **retirez vos 64 lignes** : feuille inline, câblage manuel, badge en `Stack`, 3 chips — `ZDefaultChatComposer` (ou `ZChatMaterialComposer`) les remplace, et rend vos quatre défauts inexprimables ou détectables |
| **lex_douane** | l'assemblé reprend la forme de votre bande ; vos pièces restent surchargeables une par une |
| **hôte passif** | rien — `ZChatComposer` et l'arbre de la feuille inchangés (étalon rejoué), assemblé opt-in |

🟢 **Tripwire recommandé** (IFFD) : un test qui affirme votre montage manuel — il rougira à la
migration et vous désignera les lignes à supprimer.

## 4. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (38 paquets) · `melos generate` RC=0, aucun
`.g.dart` modifié · `zcrud_chat` **531** (+21) · `zcrud_chat_material` **43** (+4) · jumelles
inchangées : kernel 411, syncfusion 65, markdown 504 · **0 erreur, 0 avertissement**.

**R3 — 7 injections + étalon, toutes ROUGE-ASSERTION** ; restaurations par copie, `sha256`
identiques, aucun résidu (grep montré). Les injections portent sur les propriétés qui comptent :
le collage CR-75, un second état de bascule (bande ≠ feuille), le badge voleur de tap,
`settings: null`, le seuil ignoré, le STOP décoratif.

⚠️ Notre CI reste à l'arrêt (facturation) : vérifications locales, état commité re-mesuré après
commit.

## 5. Non couvert

* Jeton `chatSettingsActionGap` à poser dans `zcrud_core` (chaîne paramètre > référence en
  attendant).
* 🔵 Motif d'ancrage marginal **signalé, non modifié** dans `ZChatComposerModelSelector`
  (le menu retombe de justesse dans le viewport) : corrigé dans les deux nouveaux menus, laissé
  tel quel dans l'existant — arbre protégé, aucun défaut mesuré. Dites-nous si vous le voyez.
* Dictée compacte = slot d'hôte ; **composers DODLP/DLCFTI non inventoriés** — votre « non
  mesuré » reste ouvert de leur côté.
* Dettes antérieures : cf. v0.57.0.
