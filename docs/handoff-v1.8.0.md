# Handoff **v1.8.0** — les sous-listes deviennent personnalisables

> **Tag à épingler : `v1.8.0`** — portage de l'ensemble des capacités du moteur de sous-listes
> legacy DODLP, en trois passes. Paquet porteur : **`zcrud_core`**.
> Release **additive** : rien de déclaré ⇒ rendu et données identiques, à une rupture près (§5).
>
> Cette release ne répond pas à un CR : elle vient d'une demande directe du owner.

---

## 1. Ce qui manquait, et le défaut de fond qu'il cachait

La famille `subItems` portait la fonction — édition d'une liste d'items par sous-schéma imbriqué —
mais **aucune personnalisation de présentation par item**, là où le moteur legacy en offrait sept.

En mesurant, un défaut plus profond est apparu : `itemTitleBuilder` et `acl` **existaient déjà**
sur le widget, et le constructeur de champ ne les lui transmettait **jamais**. Ils étaient donc
inatteignables sans fournir un constructeur de remplacement — c'est-à-dire par le geste même qui a
produit vos trois derniers CR.

**D'où le choix structurant** : les widgets **résolvent** leurs seams dans le contexte, ils ne les
**reçoivent** pas d'un relais. Un relais est une liste qu'il faut penser à tenir à jour ; c'est
exactement ce qui a été oublié quatre fois. Chemin nominal et construction directe servent
désormais les mêmes seams **par construction**. Un troisième seam inatteignable a été trouvé au
passage et refermé : `ZDynamicItemFieldWidget.fieldsResolver`.

## 2. Le canal

`ZSubListSeams` + `ZSubListSeamRegistry`, injectés par `ZcrudScope.subListSeamRegistry`, résolus
par clé `widgetKind` → `name` → `type.name`, chaînables (`parent:`) avec ombrage enfant > parent —
mêmes conventions que le registre de widgets existant.

Il n'est **pas** logé dans `ZWidgetRegistry` : le builder de ce dernier *remplace* le champ, alors
qu'il s'agit ici de greffer des fragments dans un rendu que le socle continue de gouverner (ACL,
agrégation, soft-delete, dialogues).

Seams livrés : `acl`, `itemTitleBuilder`, `itemBuilder`, `itemActionsBuilder`, `listViewBuilder`,
`captionBuilder`, `itemTransformer`, `itemFieldsResolver`.

Deux points de contrat : `itemActionsBuilder` **ajoute** des actions, il n'en remplace jamais, et
ses actions entrent dans le calcul de repli du résumé — sinon l'en-tête mentirait sur la largeur
disponible. Et `itemTitleBuilder` garde son contrat « donnée brute » : un titre sert à **retrouver**
un item, l'habiller le rendrait introuvable.

## 3. Le menu par item et le crochet CRUD

`ZSubItemMenuOption` porte une clé l10n + repli (jamais de libellé codé en dur), une icône, un
prédicat de visibilité par item, une charge utile opaque, un marquage destructif et une permission.
Le défaut de permission est **restrictif** — un défaut permissif aurait fait du canal une porte
dérobée. **L'ACL décide d'abord, le prédicat ensuite** : le prédicat n'est pas même *appelé* quand
l'ACL refuse.

Le crochet rend trois issues explicites — poursuivre, remplacer, opposer un véto — et non le
`Future<Map?>` du legacy. Mesuré : ce `null` servait à la fois de véto **et** de retour normal, le
moteur legacy retournant `null` sur *toutes* ses branches, y compris après avoir appliqué la
mutation. Il était ambigu par construction.

Un crochet qui **lève** est traité comme un **véto**, et l'erreur est signalée. La défensivité est
volontairement asymétrique par rapport aux seams de rendu : là, « traité comme absent » est sûr ;
ici, cela voudrait dire « la mutation passe ».

## 4. Le cycle CRUD reste porté par le champ

**Ni `ZMapEntity`, ni adossement à un `ZRepository`** — décision d'owner, et la bonne : un sac de
clés n'a pas de schéma déclaré, or toute la chaîne défensive (AD-3, AD-10) présuppose un modèle
typé ; et les sous-items vivent dans le **document parent**, pas dans une collection. Le champ
porte donc le cycle sur des `Map`, et vous branchez votre persistance derrière le crochet.

Livré avec : sous-schéma **et** gabarits de création dérivés de l'état du formulaire parent,
identité du gabarit choisi transmise au crochet, et forme du formulaire d'item déclarable
(`dialog` / `sheet` / `page`, défaut inchangé, les trois rendant la **même** donnée — assertion
croisée).

Point AD-2 tenu et mesuré : un sous-schéma qui change **ne recrée pas** les contrôleurs des champs
inchangés, et la tranche du champ lui-même n'est jamais abonnée — s'y abonner relancerait la
résolution à chaque agrégation d'item, soit exactement le rafraîchissement global que zcrud existe
pour supprimer.

## 5. ⚠️ Impact sur votre code

- **Hôte passif** : rien à faire, rendu et données identiques (contre-témoins à **comptes absolus**
  de widgets, pas de simples comparaisons de deux rendus passifs).
- **Une rupture, au périmètre étroit** : si vous déclarez `defaultNewItem` ou `creationTemplates`
  **avec une clé absente des `itemFields`**, en mode `compact` ou `tags`, **à la création** — cette
  clé était perdue, elle est maintenant conservée. Hors de cette intersection, rien ne change.
  Ce n'est pas académique : votre propre usage porte une charge `{"type": …}` qui n'a aucune raison
  d'être un champ éditable.

## 6. Ce que nous n'avons pas porté, et pourquoi

Le `DataTable` du legacy — c'est un moteur de liste, il appartient à `zcrud_list` (AD-8) ; le
dupliquer dans un champ recréerait la divergence que ce paquet existe pour supprimer. Son
surlignage en couleur codée en dur lisant un `Timestamp` Firestore **dans un widget** (FR-26 *et*
AD-5). `flutter_tags` (AD-1). Et quatre blocs commentés ou morts.

**Trois gestes morts, mesurés, à connaître de votre côté** :
1. `DynamicSubItemMenuOption.toMap/fromMap/toJson` sérialise une **closure** et un `Type` — cassé
   par construction ;
2. le prédicat `filter` de ces options n'a **aucun appelant** dans vos dépôts (grep négatif) ;
3. le menu d'ajout de la timeline « événements de dépotage » **n'est jamais rendu** : le bouton est
   sous `readOnly == false && acl.create`, et le champ déclare `readOnly: true`.

Le troisième mérite votre attention : ce menu a été écrit, maintenu, et n'a jamais pu s'afficher.

## 7. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets).
`zcrud_core` **2279** tests (baseline 2197, **+82**), 11 `info` identiques au préexistant ·
`zcrud_screen` **308**, non touché.

**44 injections R3** sur les trois passes, rouges **par assertion**. Ce qui mérite d'être dit, ce
sont les gardes que R3 a prises en défaut et qui ont dû être réparées :

- une assertion d'identité de contrôleur restait **verte** sur une vraie recréation ;
- l'exclusion de la tranche propre n'était **pas couverte du tout** ;
- une garde « hors `Navigator` » était verte **pour la mauvaise raison** — le harnais posait un
  `MaterialApp`, donc un `Navigator` ;
- un contre-témoin comparait deux rendus passifs, donc n'aurait pas vu un canal ajoutant un nœud à
  tout le monde — remplacé par des comptes **absolus** ;
- une injection a d'abord rougi **par compilation** : rejouée proprement pour rougir par assertion,
  le rouge de compilation n'a pas été compté.

C'est la raison d'être de la discipline : 2 279 tests verts ne disent rien tant qu'on n'a pas
prouvé qu'ils savent rougir.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
