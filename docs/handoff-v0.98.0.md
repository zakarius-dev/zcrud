# Handoff **v0.98.0** — les écritures ne partent plus dans une collection fantôme

> **Tag à épingler : `v0.98.0`** — corrige une **perte de données silencieuse** sur la voie
> dépôt. Paquets porteurs : **`zcrud_screen`** (correction), **`zcrud_core`** et
> **`zcrud_firestore`** (documentation). Aucune signature ne change.
>
> 🔴 **Si vous déclarez un `collectionId` sur un `ZCrudScreen` branché sur un dépôt Firestore,
> lisez le §4 : des documents vous attendent peut-être dans une collection que rien ne relit.**

---

## 1. Le défaut

`ZCrudScreen` transmettait son `collectionId` à `repository.save`. Or l'adaptateur Firestore
interprète ce paramètre comme un **chemin de collection de remplacement**. Un écran qui
déclarait `collectionId: 'ships'` **pour gouverner ses droits** — l'usage naturel, celui que
le nom suggère — sur un dépôt configuré `collectionPath: 'bmd_ships'`, écrivait dans `ships`.

Le mot portait **deux sémantiques** : une clé d'autorisation et un chemin de collection. Elles
ne demandent pas la même valeur, et rien ne le signalait.

**Pourquoi c'était critique** : l'écriture **réussit** — `save` rend un `Right`, aucune erreur,
aucun avertissement. Et les lectures (`getAll`, `watch`) restent ancrées sur le
`collectionPath` du dépôt : la liste continue d'afficher les documents attendus, elle ne montre
simplement jamais ceux qu'on vient d'écrire. Pour l'usager, cela se présente comme « ma saisie
n'a pas été enregistrée ». En réalité elle l'a été, ailleurs. Firestore crée toute collection
nommée : le backend ne protège pas de cette confusion.

## 2. La correction

**`ZCrudScreen.collectionId` ne gouverne plus que l'ACL.** Il n'est plus transmis à l'écriture —
le dépôt sait déjà où il écrit, c'est sa raison d'être.

Inventaire fait avant de modifier : sur les 14 occurrences du paramètre dans l'écran assemblé,
**une seule** était une écriture ; elle est retirée. Les neuf autres sont des appels d'ACL,
laissés intacts. La corbeille, la restauration et la purge n'étaient pas concernées — le port
ne leur expose pas ce paramètre.

**Le paramètre reste sur le port** `ZRepository.save({String? collectionId})` : la redirection
vers une collection paramétrée est un usage légitime, et un appel direct la conserve
(contre-témoin dédié). Le décorateur interne de corbeille reste transparent : un décorateur ne
réinterprète pas le contrat qu'il décore.

**Documentation corrigée aux quatre points d'usage** : la dartdoc de `ZCrudScreen.collectionId`
dit désormais qu'il gouverne l'ACL **uniquement** ; celle de `ZRepository.save` explique ce que
`collectionId` signifie réellement pour un adaptateur — une **redirection d'écriture** — et
avertit de la confusion avec une clé d'autorisation.

## 3. Sur le refus bruyant côté Firestore — non implémenté, et pourquoi

Vous proposiez, à défaut, que l'adaptateur refuse un `collectionId` inconnu. Nous ne l'avons pas
fait, et la raison mérite d'être dite : **l'adaptateur n'a aucune définition de « collection
valide »**. Le SDK client Firestore n'énumère pas les collections, et une collection légitime
vide est indistinguable d'une faute de frappe — une collection n'existe que par ses documents.
La seule règle mécanisable serait de refuser tout `collectionId` différent du `collectionPath`,
ce qui supprimerait la redirection que nous conservons au port.

Votre CR posait lui-même la condition : « **si** le paramètre doit rester transmis ». Il ne
l'est plus — le chemin par lequel la faute survenait est supprimé à la source.

## 4. ⚠️ Que faire des documents déjà écrits au mauvais endroit

**Comment reconnaître le cas** : une collection Firestore portant **exactement le nom de votre
clé d'autorisation**, invisible de toutes vos vues. Sont concernés les écrans déclarant un
`collectionId` **et** une `ZCrudSource.repository` sur un adaptateur honorant le paramètre,
**sans** détour par `onSave`. Les voies `items` et `onSave` n'ont jamais été touchées.

**Marche à suivre** :

1. relever la collection homonyme — elle n'apparaît dans aucune de vos listes ;
2. rapatrier les documents vers le `collectionPath` du dépôt **en conservant les
   identifiants** : les corps portent déjà leur `id` logique et leurs métadonnées de
   synchronisation, ils seront relus tels quels au bon endroit ;
3. arbitrer les collisions selon votre propre politique de fusion (un même identifiant peut
   exister des deux côtés si l'élément a été créé avant la bascule puis modifié après) ;
4. **supprimer la collection fantôme** — sans quoi une reprise ultérieure pourrait la relire
   comme une source légitime.

**Hôte ayant compensé** : si vous appeliez `save` sans `collectionId` via un rappel
`ZCrudScreen.onSave`, votre contournement reste **correct et prioritaire** — vous pouvez le
retirer, ou le garder sans risque.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `melos run analyze` repo-wide RC=0.
Tests : `zcrud_core` **1959**, `zcrud_screen` **230** (+5), `zcrud_firestore` **812** (+2).

Le rouge initial de la garde décisive est cité tel quel : `Expected: <0> / Actual: <1>` sur le
comptage de la collection fantôme — l'assertion porte sur le **contenu réel des deux
collections**, pas sur l'absence d'erreur, puisque c'est précisément l'absence d'erreur qui
rendait le défaut invisible. Quatre injections R3, toutes rouges par assertion ; l'une d'elles,
jugée **ambiguë** (elle rougissait sur le résultat de l'écriture et non sur la redirection), a
été rejetée et refaite.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.
