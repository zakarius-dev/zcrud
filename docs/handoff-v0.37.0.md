# Handoff **v0.37.0** — CR-IFFD-42 : l'inversion atteint enfin `Theme.textTheme`

> **Tag à épingler : `v0.37.0`** · additif, aucune rupture d'API.
> 🟢 **Vous pouvez retirer votre contournement** — voir le § 3.

---

## 1. Pourquoi votre texte était illisible — la cause exacte, mesurée

Vous aviez raison sur le symptôme, et votre formulation était la bonne :

> *« Le défaut punit la bonne pratique. »*

La cause est plus profonde qu'un simple oubli d'enveloppe : **les rôles de `TextTheme` issus de
la typographie Material sont construits avec `inherit: false`**. Un `Text` auquel on passe
`textTheme.titleSmall` **court-circuite donc entièrement** le `DefaultTextStyle` ambiant.

⇒ **Aucune enveloppe d'héritage ne pouvait l'atteindre.** Seule la réécriture du `TextTheme`
lui-même le fait. Votre contournement (reprendre la couleur du `DefaultTextStyle`) fonctionnait
précisément parce qu'il court-circuitait le court-circuit.

## 2. La forme retenue, et **ce qu'elle ne couvre pas**

Un `Theme` qui réécrit **uniquement** `textTheme` et `iconTheme` — pas un `ThemeData` entier.

**Effets de bord mesurés, pas supposés :**
* le `ColorScheme` **traverse intact** (asserté par égalité) ;
* **la couleur d'un `TextButton` n'est pas détournée** — mesurée identique dedans et dehors.
  Substituer un `ColorScheme` entier l'aurait détournée : une injection le démontre en faisant
  rougir ces gardes.

⚠️ **Ce que la forme ne couvre PAS, et qui vous concerne** : tout composant qui résout son premier
plan depuis le **`ColorScheme`** — boutons, `IconButton`, `Chip`, `InputDecorator`, `Switch`.
**Si vous placez un bouton dans une zone inversée, vous devez le styler vous-même.**

Le choix est délibéré : les recolorer supposerait de promouvoir `inverseSurface` en `surface`, ce
qui détournerait aussi vos cartes, vos séparateurs et vos états d'erreur, **sans annulation locale
possible**.

## 3. 🟢 Votre ligne — vous pouvez retirer votre contournement

| Vous êtes… | Geste |
|---|---|
| **vous, IFFD** | **retirez** `color: DefaultTextStyle.of(context).style.color` de votre `itemBuilder` — il est désormais redondant. Le garder n'est pas cassant, mais c'est une couche morte |
| **hôte passif** | **rien** — sans emphase inversée, rendu strictement inchangé |
| vous placez un **bouton** dans une zone inversée | stylez-le : le `ColorScheme` n'est délibérément pas détourné |

## 4. 🔵 Au-delà de votre demande — l'enveloppe est réutilisable

Vous écriviez que le motif dépasse la fratrie et *« vaudra pour toute surface d'inversion que le
socle introduira »*. Nous en avons tiré la conséquence : l'enveloppe est extraite en
**`ZInvertedSurface`**, dans `zcrud_core`.

La prochaine surface inversée l'obtient **gratuitement**, au lieu de rejouer ce défaut une
troisième fois. Aucune couleur littérale : uniquement le couple de rôles `inverseSurface` /
`onInverseSurface`.

## 5. 🔴 Ce que la vérification a établi, et qui donne raison à votre CR

Sous l'injection du défaut exact que vous rapportiez, **toute la suite CR-IFFD-41 est restée
VERTE — 30 tests sur 30**, y compris ses deux gardes « inversion » et « contraste mesuré ».

Elles montaient un `Text` **nu** et une `Icon` **nue** — deux chemins qui, eux, héritent. **Elles
mesuraient bien, mais à côté.** C'est exactement l'angle mort qui a laissé passer le défaut.

La nouvelle garde monte l'`itemBuilder` **tel que vous l'écrivez** — stylé depuis
`Theme.of(context).textTheme.titleSmall` — et mesure la **couleur réellement peinte**, avec un
contrôle négatif sur l'élément non courant et un contrôle de non-vacuité.

## 6. Autres expositions de même classe — **signalées, non corrigées**

Grep sur tout le dépôt : 6 sites posant `DefaultTextStyle`/`IconTheme`. Quatre sont sans risque
(poids, taille, ou couleur délibérément non touchée). **Deux** ont la même limite :
`ZSubfolderItemChrome` et `ZFlashcardListView`, autour de leurs slots injectés.

Nous ne les avons **pas** corrigés : ces deux-là **teintent** un contenu sur fond normal, ils ne
**retournent** pas une surface. Y appliquer l'enveloppe serait faux, et réécrire leur `TextTheme`
changerait le rendu d'hôtes existants hors du périmètre de votre CR. Ce sont des candidats pour une
CR de suivi **si vous constatez le symptôme**.

## 7. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_core` **1145** (+9) · `zcrud_study` **866** (+5) · **0 error, 0 warning** ·
`ZInvertedSurface` : **un seul import**, **zéro couleur littérale** (vérifié).

**6 injections R3**, toutes rouges d'assertion, aucune de compilation.

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications **locales**.

## 8. Ce que nous savons ne pas avoir couvert

* **Rien ne verrouille** le fait qu'une **future** surface d'inversion passe par `ZInvertedSurface` :
  un auteur pourrait recopier le duo d'enveloppes et rejouer le défaut. Une garde de source serait le
  vrai verrou — nous ne l'avons pas écrite, car elle aurait rougi sur les **deux sites légitimes**
  du § 6. C'est la limite honnête de ce lot.
* `primaryTextTheme` n'est pas réécrit.
* Un contenu qui code sa couleur **en dur** reste hors de portée de toute enveloppe.
* Le contraste est mesuré en **écart de luminance**, pas en ratio WCAG 4.5:1.
