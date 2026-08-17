# Handoff **v2.1.0** — quatre CR traités, dont la bloquante

> **Tag à épingler : `v2.1.0`** — release **strictement additive** : rien de déclaré ⇒ comportement
> identique. Paquets porteurs : **`zcrud_core`**, **`zcrud_screen`**, **`zcrud_select`**.
>
> 🔴 **Deux actions attendues de votre côté** — §6. Ce ne sont pas des options.

---

## 1. 🔴 La CR bloquante — et pourquoi le correctif évident n'aurait rien débloqué

`ZRelationCrudHandler` porte désormais `canCreate` / `canEdit` / `canCopy` (défaut `true`, donc
rétrocompatible par construction). Un geste refusé est **absent**, jamais inerte : l'icône n'est
pas construite, et un gestionnaire qui n'offre plus rien ne force plus l'ouverture de la feuille.

**Mais le correctif du cœur seul ne vous aurait pas débloqués.** `ZSmartSelectPresenter`, dans
`zcrud_select`, portait la **même** garde tout-ou-rien — et vous enrôlez ce présentateur
globalement (`dodlp_zcrud_scope.dart:361`). Le rendu natif du cœur n'est donc **jamais atteint chez
vous**. Nous l'avons trouvé en vérifiant au-delà du périmètre de la CR ; les deux surfaces sont
corrigées.

C'est la classe d'erreur que nous nous sommes engagés à ne plus commettre : affirmer une propriété
sur *l'hôte* en n'ayant vérifié qu'une propriété sur *notre* code. Vos huit champs BMD sont
portables.

**Deux points de doctrine, écrits en dartdoc** :
- La frontière ne bouge pas : **zcrud ne connaît pas votre ACL**. Les booléens sont calculés par
  votre implémentation du port ; le paquet ne fait que les lire — exactement comme vous le
  demandiez.
- `ZActionAclMode.disable` a été **délibérément écarté** ici. Ce mode n'est défendable que là où
  l'action porte un motif annoncé aux lecteurs d'écran ; la feuille de relation n'a aucun canal de
  motif, donc `disable` y produirait le bouton inerte et muet que votre CR refuse. La condition de
  levée est écrite : un mode inerte devra arriver **avec** sa clé de motif.

**Signature** : trois getters simples plutôt qu'une variante contextuelle. Mesuré : pour rester
symétrique de vos opérations, elle s'écrirait `canEdit(value)` — donc exécuterait votre code d'ACL
**dans le constructeur d'item, à chaque frame de défilement**. Le getter reste extensible vers le
contextuel ; l'inverse serait cassant.

## 2. Les actions d'app-bar peuvent dépendre de l'état

`ZCrudScreen.actionsBuilder` rend des `ZAppBarAction` — **jamais des widgets**. Vous obtenez la
conditionnalité **sans** reperdre ce que la déclaration en données vous avait apporté : chaque
geste garde son libellé accessible. Le contexte porte l'ACL **déjà restreinte à l'onglet actif**,
l'index d'onglet, le nombre d'éléments, l'état corbeille et la vacuité.

**Exclusif** avec `actions`, gardé par assertion. Rien n'a été ajouté pour `validatable` : comme
vous l'écriviez, ce builder le couvre.

Granularité **mesurée**, pas promise : l'abonnement est posé au-dessus de la seule coquille, le
corps passé en enfant, et **seulement si** un builder est déclaré. Sans builder, zéro abonnement
monté. Sous injection, le nombre de constructions passe de 7 à 14 — la garde mord.

## 3. L'onglet actif et son défilement survivent

Port `ZListTabsStore`, sur le patron du seam de pli des sections que vous citiez. **Un offset par
onglet**, comme vous y insistiez — « c'est la moitié qu'on oublie ». La clé de portée est
**dérivée** (type d'entité, identité d'écran, jeu d'onglets), donc jamais à fournir.

Deux corrections à votre CR, mesurées :
- `ZTabbedList` portait **déjà** `initialIndex` (avec clamp) : « aucun paramètre d'entrée » est vrai
  de `ZCrudScreen`, faux de la brique.
- Votre croquis proposait un `double` non nullable pour l'offset. Rendu **nullable** : sinon il
  aurait fallu inventer `0.0`, donc confondre « jamais enregistré » et « en haut de liste ».

Et un écart de nommage assumé : `load*`/`save*` plutôt que `read*`/`write*`, parce que vous
demandiez explicitement « la symétrique de `ZSectionCollapseStore` ».

Nos `_tabControllers` ne sont **pas** des contrôleurs de défilement mais de données, et les listes
du cœur n'acceptent aucun contrôleur de défilement (`grep` vide) : le défilement est donc observé
par notifications. Passer par le contrôleur primaire aurait explosé sur toute page à deux zones
défilantes.

## 4. Un rendu de choix personnalisé devient déclarable

Votre formule était juste : *« Il ne manque pas un widget. Il manque une porte. »*
`ZSelectChoiceBuilderRegistry` (chaînable, ombrage enfant > parent, collision locale ⇒ `throw`),
injecté par `ZcrudScope`, et une **clé** portée par `ZSelectConfig`. `choiceSecondaryBuilder`
existait bien : même clé, même registre.

Le canal **résout** plutôt qu'il ne **relaie** — un relais est une liste qu'on oublie de tenir à
jour, et c'est ce qui a produit quatre de vos signalements successifs. La spec reste `const`.

**Mesuré, et c'est votre question la plus importante** : `zcrud_select` possède **déjà** les actions
de modale et la recherche. **Aucune seconde porte n'est nécessaire** — vous retrouvez la recherche
et les actions tout/rien sans rien recoder.

Clé déclarée mais absente du registre ⇒ repli sur le rendu par défaut, jamais d'exception.

## 5. La CR « journal CRUD » : nous la livrons, et nous corrigeons votre diagnostic

Vous proposiez, à défaut de livraison, de **retirer** la relecture `lastValue` pour récupérer vos
24 % de latence. **Nous ne recommandons pas cet échange** : supprimer une piste d'audit des
mutations dans une application des douanes pour gagner un quart de seconde est le mauvais troc.
Le port et le rendu feront l'objet de leur propre lot.

⚠️ **Mais votre diagnostic mérite une correction, et elle vous rend les 24 % tout de suite** : dans
un flux d'édition, **l'état d'avant est déjà en main** — le formulaire en a été amorcé. Relire
l'entité juste avant de l'écrire revient à redemander au serveur ce que vous détenez déjà. Vous
pouvez donc récupérer cette latence **sans renoncer au journal**, et indépendamment de ce que nous
livrerons.

## 6. 🔴 Ce que vous devez faire

1. **Retirer la compensation `appBarActions`** de `bep_non_appure_screen.dart:664`. L'assertion
   d'exclusivité couvre `actions`/`actionsBuilder`, **pas** l'ancien paramètre : garder les deux
   **doublerait silencieusement** vos actions.
2. **Perte unique de préférences d'onglet à la migration** : vos clés
   `GetStorage("DynamicTabsState")` ne coïncident pas avec la clé dérivée. Une seule fois, puis la
   persistance reprend.

Hôte **passif** sur tout le reste : rien à faire.

## 7. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets).
`zcrud_core` **2336** (base 2307, +29) · `zcrud_screen` **336** (base 308, +28) ·
`zcrud_select` **142** (base 135, +7). Analyses inchangées au signalement près.

Une trentaine d'injections R3, rouges **par assertion**. Ce qui mérite d'être cité, ce sont les
**gardes trouvées inertes et réparées** : l'une mesurait le plancher que le SDK impose de toute
façon au lieu de la contrainte déclarée ; une autre employait un gestionnaire qui *déclarait* ses
droits, mesurant donc sa propre déclaration au lieu du défaut du port. Une troisième — un
contre-témoin — a été **déclarée comme telle** plutôt que maquillée en garde, faute d'injection
plausible qui la rende rouge.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
