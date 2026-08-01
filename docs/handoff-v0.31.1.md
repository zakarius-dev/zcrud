# Handoff **v0.31.1** — cible tactile de la bande de pièces jointes (AD-13)

> **Tag à épingler : `v0.31.1`** · correctif ciblé, **un seul widget** : `ZChatAttachmentStrip`.

---

## 🔴 Lisez d'abord votre ligne

| Vous êtes… | Ce qui change |
|---|---|
| vous n'utilisez pas `ZChatAttachmentStrip` | **rien** |
| vous l'utilisez **sans** passer `height` | **rien** — le défaut est identique, le rendu inchangé |
| vous passez `height:` **≥ 48 dp** | **rien** — votre valeur est honorée à l'identique (contrôle négatif gardé) |
| 🔴 vous passez `height:` **< 48 dp** | **votre bande grandit jusqu'à 48 dp** — et c'est le correctif : votre cible tactile n'était **pas conforme** |

---

## Ce qui était cassé

Un hôte passant `ZChatAttachmentStrip(height: 30)` obtenait une **cible tactile de 30 dp** —
sous le plancher de 48 dp exigé par **AD-13**, et **silencieusement** : aucune exception, aucun
avertissement, aucun test rouge.

Le bouton portait pourtant un `ConstrainedBox(minHeight: 48)`. **Il ne protégeait de rien** : sous une
contrainte de hauteur **serrée** venue du parent, un enfant ne peut pas être plus grand que la place
imposée — c'est le protocole de Flutter, pas un défaut de code.

C'est le **quatrième** cas du même motif dans ce socle — une contrainte **déclarée** que le parent
écrase en silence — après CR-IFFD-37 et deux occurrences trouvées par notre revue de fin d'epic.

## Le correctif

**Le plancher passe de l'enfant au conteneur** : c'est la bande qui décide de sa hauteur, et elle ne
descend jamais sous la cible tactile. Même remède que `ZMenuEntryTile.gridDelegate` en `v0.30.0`.

Mesuré : `height: 30` rendait **30 dp**, rend désormais **48 dp**. `height: 80` rend toujours 80 dp.

## Ce que le correctif dit de nos tests

**La garde « cible ≥ 48 dp » existait, et elle était aveugle.** Mesuré : en retirant notre plancher,
elle restait **verte** — la taille qu'elle observait venait du parent et du texte, jamais de la
contrainte qu'elle prétendait défendre.

La nouvelle garde vise ce qui protège réellement l'utilisateur — *une hauteur d'hôte sous le plancher
n'écrase pas la cible* — avec deux précautions :
* une **borne haute**, sans quoi un widget occupant tout l'écran passerait pour conforme (nous avons
  mesuré ce cas ailleurs : une cible de **600 dp**, verte) ;
* un **contrôle négatif** : une hauteur valide doit rester **honorée**, pour que le plancher ne
  devienne pas un écrasement dans l'autre sens.

Elle est prouvée mordante par injection de la régression exacte.

## 🟢 Tripwire recommandé

Si vous passiez une hauteur inférieure à 48 dp, gardez un test qui **affirme la hauteur que vous
obteniez**. Il rougira à l'adoption de `v0.31.1` et vous désignera l'ajustement de mise en page à
faire — au lieu de découvrir le décalage à l'œil.

## Vérification

`melos analyze` **RC=0, 0 erreur** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_chat` **216** tests.

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications locales rejouées à la main.
