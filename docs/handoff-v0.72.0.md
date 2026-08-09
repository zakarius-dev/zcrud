# Handoff **v0.72.0** — le gabarit navires, et **deux plantages** qu'il a fait sortir

> **Tag à épingler : `v0.72.0`** · additif — aucune signature cassée, aucun paquet nouveau (38).
> 🔴 **Deux corrections d'exception** : un sous-stepper dont **toutes** les sous-étapes sont filtrées
> **plantait**. Si vous n'avez pas ce cas, rien ne change pour vous.

---

## 1. Votre CR « prise en charge navire » — la réponse, et sa mesure

Vous demandiez un **gabarit de référence**, pas un correctif. Bien vu : **aucune capacité nouvelle
n'était requise**.

**Le point qui décidait de tout est vérifié** : la condition d'une étape **imbriquée** est bien
honorée **et recalculée**, comme celle d'une étape racine. Un sous-stepper est un stepper complet —
il a son propre recalcul et ses propres abonnements de condition, dans **tous** les modes. Le montage
que vous décrivez — racine **tout-affiché** contenant un sous-stepper **paginé** — fonctionne, et il
est désormais **gardé**.

⇒ Votre besoin est **énumérable** : les documents exigés pour un type de navire sont un
**sous-ensemble d'un ensemble connu**. La réponse déclarative est donc **« déclarer toutes les
sous-étapes possibles, les filtrer par condition »** — et elles se recalculent quand la valeur amont
arrive, même **en asynchrone**.

Livré : `example/lib/demos/ship_documents_demo_screen.dart` — racine dépliée, sous-stepper paginé,
six sous-étapes filtrées sur un type chargé **de façon asynchrone** depuis un dépôt (jeton de course
inclus), `rowChips` de statut **avec sous-titre par choix**, et les **trois seams fichier câblés
ensemble**, avec une tranche qui démarre sur un identifiant opaque — le vôtre — résolu à l'écran.

**Vos deux questions annexes, tranchées** : le sous-titre par choix est **atteignable** ; pour les
seams fichier, **rien ne manque**. Et l'aplatissage/ré-agrégation de vos cartes est reproduit à la
clôture.

## 2. 🔴 Deux plantages, sortis en écrivant le gabarit

Le gabarit a trouvé ce qu'aucune relecture n'avait vu — et ce ne sont pas des défauts silencieux
cette fois, ce sont des **exceptions**.

> **Un sous-stepper dont TOUTES les sous-étapes sont filtrées levait.** Au montage **et** en vol.

**Ce sont deux défauts distincts, sur deux chemins distincts**, et il a fallu deux corrections :

| | Où | Ce qui levait |
|---|---|---|
| **① au montage** | le calcul de contribution indexait la liste d'étapes **sans garde de vacuité** — alors que les **deux autres** sites qui l'indexent la portaient | `RangeError` |
| **② en vol** | la garde de vacuité en tête de la construction **ne protège pas la fermeture** qui la suit : celle-ci est capturée une fois et **rejouée à chaque notification**, donc la liste peut se vider **après** le dernier passage | `ArgumentError` |

🔵 Deux détails qui rendaient le second difficile à lire : l'exception n'était **pas** de la même
famille que la première, et son message nomme la borne **basse** — donc « argument 0 » pour un
écrêtage dont la borne haute valait −1.

**Chaque correction est prouvée mordante séparément** : retirer la première rend un `RangeError` sur
les **deux** sens ; retirer la seconde rend un `ArgumentError` sur le **seul** chemin en vol.

## 3. Ce que le gabarit démontre, et ce qu'il refuse de démontrer

* choisir une valeur amont **change réellement** les sous-étapes montées ;
* pendant le chargement, une seule sous-étape d'attente est montée — 🔵 **et elle n'est pas
  décorative** : elle garantit que l'ensemble effectif n'est **jamais vide**, donc que les deux
  défauts ci-dessus restent inatteignables dans ce gabarit. C'est documenté sur place ;
* 🔴 **la valeur d'une sous-étape qui disparaît est CONSERVÉE** — aucune divergence avec la doctrine
  posée en v0.65.0 pour les choix orphelins. Rendue visible par un compteur, plutôt que laissée
  implicite.

**Non démontré, avec le motif** : un ensemble de sous-étapes **ouvert** (servi par un backend) —
inexprimable avec ce motif, l'hôte devrait recomposer sa liste ; le sous-stepper vide, **délibérément
inatteignable** ; un téléversement réel.

**Aucun contournement du socle** : pas de constructeur de champ, pas de remontage forcé, pas de
recomposition de liste. La seule part impérative est l'orchestration asynchrone **chez l'hôte** —
structurelle, le socle n'ayant pas de canal de dérivation asynchrone.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — sauf si vous filtrez **toutes** les sous-étapes d'un sous-stepper, auquel cas vous ne plantez plus |
| **DODLP** | le gabarit répond à votre CR : déclarez vos six documents comme sous-étapes conditionnées sur le type de navire, il n'y a **rien à ajouter au socle** |

## 5. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1606** (+2) · `example` **108** (+6) · `zcrud_study` 1521 · `zcrud_firestore` 770 ·
`zcrud_markdown` 516 · `zcrud_intl` 202 · `zcrud_select` 135. **0 erreur, 0 avertissement.**

**R3 — 7 injections côté gabarit, 2 côté correctif**, sha avant **et** après chacune, restauration
par copie, résidus : greps négatifs montrés.

🟢 **Ma propre garde est restée VERTE au premier essai — et c'était elle le problème, pas le
correctif.** Je l'avais écrite avec un stepper racine **paginé** : dans ce mode, seule l'étape
courante est montée, donc l'étape portant le sous-stepper ne l'était pas, l'enfant ne publiait jamais
sa fenêtre, et le défaut restait **inatteignable**. Racine **dépliée**, elle mord. C'est le cinquième
jour consécutif où une injection verte est mesurée au lieu d'être forcée — et cette fois elle a
révélé une garde **de moi**.

🔵 **Et le second défaut n'a été trouvé que parce que la garde corrigée a continué de rougir** après
le premier correctif. Une sonde temporaire a été posée pour obtenir le site réel du lancer — la pile
étant effacée par la capture d'exception — puis retirée.

🟡 Deux assertions de ma garde comptaient **un** stepper là où le montage en produit **deux** (racine
et enfant) : elles rougissaient pour une raison **étrangère** au défaut mesuré. Corrigées.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 6. Le piège de vitrine, encore

🔴 À 7 500 dp de surface de test, le dernier champ **cessait d'être construit** une fois le
sous-stepper monté. Porté à 12 000 dp, et une garde le vérifie **dans l'état le plus chargé**. C'est
le piège qui rend un test vert **en ayant cessé d'observer** — déjà rencontré, et il revient dès
qu'une page grossit.

## 7. Non couvert

* Un ensemble de sous-étapes **dérivé d'un backend** (§ 3) — le socle n'a pas de canal de dérivation
  asynchrone de la **liste** d'étapes, seulement du **filtrage**.
* La voie `relation` dans ce gabarit, et un téléversement réel.
* Dettes antérieures : cf. v0.71.0 et les handoffs précédents.
