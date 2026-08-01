# Handoff **v0.31.0** — CHAT-7..10 : métadonnées, SRS, blocs enrichis, saisie assistée

> **Tag à épingler : `v0.31.0`** · **1 paquet nouveau** (`zcrud_chat_study`) · **36 paquets** au total.
> Livraison **additive** pour tout hôte — aucune rupture d'API. Lisez quand même le § 4.

---

## 1. Ce que ces quatre lots ont surtout **refusé** d'écrire

C'est le fait marquant de cette livraison, et il vous concerne : **la moitié du travail a consisté à
mesurer que quelque chose existait déjà, ou n'avait pas sa place dans un socle.**

| Lot | Ce qui était planifié | Ce qui a été livré |
|---|---|---|
| **C7** — confiance | RAG, citations vérifiées, score explicable | **une carte ouverte** : votre serveur envoie des **verdicts**, le socle n'en calcule aucun |
| **C8** — SRS | portage complet | **un mapper et un filtre** — `zcrud_flashcard`/`zcrud_session` avaient déjà tout |
| **C9** — blocs | 11 types de blocs à porter | **zéro variant créé** : les 9 génériques existaient déjà, avec parité de champs vérifiée |
| **C10** — dictée/OCR | portage | les contrats ; **les moteurs restent chez vous** (AD-57) |

**Trois refus explicites, motivés :** `LegalReference` (vocabulaire juridique douanier, pas éducatif),
`Flashcards` et `Mindmap` (ils porteraient `ZFlashcard`/`ZMindmap`, donc une arête du noyau vers un
satellite — **AD-1 rouge**). Les trois traversent en bloc ouvert, **payload verbatim, round-trip exact**.

🟢 **Un tripwire posé pour vous** : une garde asserte que *nos alias de lecture ∪ nos refus = votre
catalogue*. **Un douzième type de bloc chez vous fera rougir notre suite**, au lieu de passer inaperçu.

---

## 2. 🔴 La relecture avant envoi est garantie par le TYPE, pas par la discipline

C10 porte votre dictée et votre OCR. Chez vous, le texte transcrit est une `String` publique : la
relecture tient à la rigueur de l'appelant. **Ici elle tient au type.**

* la valeur brute est **privée** ; **aucun membre public ne rend une `String`** ;
* `toString()` n'expose que la **longueur** — la fuite par journalisation est fermée ;
* l'unique sortie dépose dans le composeur et rend `void` : rien ne s'échappe ;
* et l'insertion **échoue** si rien n'observe le tampon — le raccourci « dicter puis insérer sans
  jamais rien montrer » ne réussit pas en silence.

Le texte inséré est la valeur **courante du tampon**, pas la sortie du moteur : votre correction de
« article dis » en « article 10 » est ce qui arrive au composeur.

⚠️ **Ce qui reste chez vous** : les moteurs de reconnaissance, la table `langue → locale`, et surtout
votre **normalisateur de nombres** (« huit cent cinq » → `0805` avec padding de position) — du
douanier pur. Une couture est prévue pour le rebrancher.

---

## 3. Ce que nous avons corrigé dans notre propre lecture de votre code

Trois affirmations de notre plan se sont révélées **fausses à la mesure**. Nous les corrigeons ici
parce qu'elles pourraient vous être renvoyées un jour comme des faits :

1. **Votre suppression n'est pas un hard-delete.** Toutes les voies de lex sont des **soft-delete** ;
   la conversation pose `deleted_at` et la recherche filtre dessus. Le hard-delete existe chez lex sur
   la **troncature de messages** — c'est celui-là que nous refusons, avec `restore()` en contrepartie.
2. **« 3 modes vifs, 2 morts »** est inexact : un seul est réellement mort, un autre est vivant **par
   une autre porte**, le troisième n'est pas un mode. Consigné : *non porté ≠ mort*.
3. 🔴 **Piège de portage chez IFFD** : dans votre sélecteur de mode, **libellé et énumération sont
   décalés d'un cran** — la tuile « à réviser » construit `.test`, la tuile « Test » construit
   `.whiteExam`. **Porter par le libellé échangerait deux modes**, un bug invisible hors session.
   Notre mapping est figé par test ; vérifiez le vôtre.

---

## 4. Votre ligne

**Hôte passif** : ajoutez `zcrud_chat_study` à vos `dependency_overrides` si vous voulez le pont vers
le SRS. Sinon, rien à faire — cette livraison n'a **aucune rupture d'API**.

**Hôte ayant contourné** : rien de nouveau par rapport à `v0.30.0` (dont le § 3 reste valable et
non appliqué tant que vous n'avez pas retiré vos compensations).

---

## 5. Vérification

`melos analyze` **RC=0, 0 erreur** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, **36 paquets**,
tous gates) · `zcrud_chat_kernel` **365** (`-p node` 291) · `zcrud_chat` **214** ·
`zcrud_chat_study` **67**.

🔴 **Une régression a été attrapée par un gate global, pas par un lot** : une carte de métadonnées
reversait les clés de synchronisation réservées (`updated_at`, `is_deleted`) dans le domaine — un
document relu aurait injecté ses métadonnées de store dans l'entité. Corrigée avant livraison.
Nous le signalons parce que c'est exactement le type de défaut qu'une vérification par paquet ne voit
pas, et parce que **notre CI reste à l'arrêt** (facturation) : ces chiffres sont des vérifications
locales rejouées à la main.

---

## 6. Ce que nous savons ne pas avoir couvert

* **Aucun adaptateur de transport, nulle part.** La conformité de nos contrats est **contractuelle**
  (documentation + grep négatif sur les verbes interdits) : un adaptateur qui purgerait au lieu de
  marquer supprimé **compilerait**. Le tripwire réel doit vivre chez vous.
* **C7 : la fixture de test est recopiée à la main** depuis votre code serveur. Si vous changez une
  clé de `done.metadata`, **rien chez nous ne rougira**.
* **C8 : aucune UI, aucun câblage au moteur de session.** Le pool est produit ; le dernier centimètre
  — pool → session — reste à votre charge.
* **La chaîne vocale n'a pas de disjoncteur** : vous en avez un pour ne pas marteler un backend mort.
  C'est une politique d'adaptateur, pas de domaine — mais empiler trois maillons réseau sans lui
  refera le martèlement.
* **La révocation d'un lien partagé n'existe nulle part** — ni chez vous, ni ici. Un lien n'est
  révocable que par expiration.
* **Aucun rendu riche n'est branché** : un diagramme affiche toujours son code source.
