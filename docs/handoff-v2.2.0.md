# Handoff **v2.2.0** — le journal d'une entité devient consultable

> **Tag à épingler : `v2.2.0`** — release **strictement additive** : sans source déclarée, rien
> n'est payé. Paquets porteurs : **`zcrud_core`** (le port) et **`zcrud_screen`** (le geste et le
> rendu).

---

## 1. Notre réponse à votre alternative

Vous demandiez une livraison **ou** un refus argumenté, pour pouvoir retirer la relecture qui vous
coûte 24 % du temps d'une sauvegarde. **Nous livrons** — et nous vous déconseillons l'échange
inverse : supprimer une piste d'audit des mutations dans une application des douanes pour gagner un
quart de seconde est le mauvais troc.

⚠️ **Mais votre diagnostic mérite une correction, et elle vous rend ces 24 % tout de suite** : dans
un flux d'édition, **l'état d'avant est déjà en main** — votre formulaire en a été amorcé. Relire
l'entité juste avant de l'écrire revient à redemander au serveur ce que vous détenez déjà. Vous
pouvez donc récupérer cette latence **sans renoncer au journal**, et indépendamment de cette
livraison.

Votre honnêteté sur l'antécédent a été retenue telle quelle : votre écran legacy était **commenté**
et n'a jamais servi, donc zcrud n'a rien cassé. C'est une capacité **neuve**, et le CHANGELOG le dit.

## 2. Ce qui est livré

**Le port** `ZEntityHistorySource` : un **flux nu** (AD-5), fourni par vous. **zcrud ne lit jamais
votre backend.** La forme du journal, la résolution de l'agent et l'écriture restent chez vous, et
aucun type `cloud_firestore` n'approche le domaine.

**Une découverte qui simplifie** : `ZCrudAction.history` **existait déjà** dans l'énum ACL, et y
était déjà classé comme action de **lecture**. La gouvernance était en place ; seule la capacité
manquait. L'énum n'a pas été touchée.

**L'opération est typée**, donc localisable par le socle, avec un libellé libre en échappatoire pour
vos opérations métier. Votre croquis proposait un libellé `String` brut : il n'aurait pas pu être
traduit.

## 3. 🔴 Le contrat de diff — lisez ce paragraphe

Un diff qui apparie mal affiche des changements **faux**, ce qui est pire que pas de diff du tout.
Le contrat est donc explicite :

- la **première** entrée est comparée à l'**état courant** ;
- chaque autre entrée est comparée au `previousValue` de l'entrée **plus récente** ;
- clés **modifiées**, **ajoutées** et **retirées** sont rendues ;
- les structures **imbriquées** sont traitées comme **atomiques**.

⚠️ **Le socle ne trie pas.** L'ordre **antichronologique** du flux est une obligation de votre
implémentation. Un flux dans le mauvais ordre produirait des paires fausses — c'est le seul piège
de cette livraison, et il est chez vous.

## 4. Impact sur votre code

- **Hôte passif** : rien à faire, et c'est gardé — sans source déclarée, **exactement zéro** action
  de ligne ajoutée (compte absolu, pas une comparaison entre deux rendus passifs).
- **Vous** : implémentez le port, déclarez-le, et l'action apparaît là où votre ACL accorde
  `history`.
- Défensif (AD-10) : une source qui **lève** laisse l'arbre intact ; une entrée sans date est
  **ignorée**, jamais datée de l'instant courant.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets).
`zcrud_core` **2337** tests, 11 `info` inchangés · `zcrud_screen` **345** tests, analyse **propre**.

Sept injections R3, **toutes rouges par assertion**. La plus importante fausse volontairement
l'appariement du diff — sans elle, rien ne garantirait que les paires affichées sont les bonnes.

🟢 **Un rouge légitime trouvé en vérifiant** : une garde **préexistante** de gouvernance de ligne
assertait le texte **brut** `history`, c'est-à-dire la **clé non traduite**. Elle ne passait que
tant que cette clé n'était pas au catalogue — elle mesurait donc l'absence de traduction autant que
la gouvernance. La traduction ajoutée l'a fait rougir. Corrigée pour asserter le libellé **rendu**,
puis **re-prouvée mordante** par injection : privée de sa règle, elle rougit
`Expected: exactly 2 / Actual: Found 1 widget with text "History"`.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
