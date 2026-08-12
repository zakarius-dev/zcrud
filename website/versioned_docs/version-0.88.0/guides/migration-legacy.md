---
title: Migrer un moteur CRUD legacy vers zcrud
description: Pièges mesurés en migrant vers zcrud depuis un moteur maison — ordre d'affichage, graines date/plage, clés hors sous-schéma, codecs legacy, tripwire.
sidebar_position: 3
---

# Migrer un moteur CRUD legacy vers zcrud

zcrud a été extrait de trois applications qui portaient chacune leur propre moteur
CRUD déclaratif maison. Cette page rassemble les pièges **génériques** qu'une
migration fait remonter — ceux qui touchent n'importe quel modèle, pas un domaine
métier précis. Chaque affirmation ci-dessous est vérifiable dans le code public
des paquets cités.

Pour la migration d'un **champ géographique** legacy (format JSON polymorphe
`point`/`circle`/`polygon`/`polyline`), une correspondance champ à champ détaillée
existe déjà et n'est pas dupliquée ici : voir
[`packages/zcrud_geo/doc/migration-legacy-dodlp-geo.md`](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_geo/doc/migration-legacy-dodlp-geo.md).

## Le principe qui gouverne tout le reste

zcrud applique partout la désérialisation **défensive** de
[l'invariant AD-10](../concepts/invariants.md#ad-10) : un champ absent, d'un type
inattendu ou corrompu ne fait **jamais** échouer le parent, et une évolution de
schéma est **additive seulement**. Concrètement pour une migration : vous pouvez
en général **brancher les données legacy telles quelles** et laisser le moteur
lire défensivement, plutôt que d'écrire un script de conversion préalable. Le
piège symétrique — et le plus coûteux à découvrir tard — est l'**hôte qui
compense** un défaut du moteur avant que zcrud ne le corrige nativement : sa
compensation s'additionne alors au correctif au lieu de devenir redondante. La
dernière section de cette page décrit comment s'en prémunir.

## L'ordre d'affichage vient du schéma, jamais de la persistance

Un piège classique d'un moteur legacy qui itère `Map.keys()` pour décider dans
quel ordre rendre les champs : l'ordre d'un objet JSON dépend de **qui l'a
écrit**, et deux documents de la même collection écrits par des versions
différentes du code peuvent porter leurs clés dans un ordre différent. L'ordre
d'affichage devient alors **instable document par document**.

zcrud élimine structurellement ce piège : `zcrud_generator` émet le
`ZFieldSpec[]` d'un modèle dans l'**ordre de déclaration** des `@ZcrudField` sur
la classe annotée `@ZcrudModel` — une donnée `const`, figée à la génération,
totalement indépendante de l'ordre des clés d'un document donné.
`DynamicEdition` et `DynamicList` rendent tous deux les champs dans cet ordre de
schéma. En migrant, **ne portez donc jamais** une logique legacy qui déduisait
l'ordre d'affichage des données persistées : l'ordre voulu se déclare sur le
modèle (ordre des champs annotés, ou leur paramètre de tri explicite si votre
modèle en expose un), pas sur le JSON.

## Les champs date et plage lisent plusieurs formes de graine

Un modèle legacy amorce souvent un formulaire de deux façons différentes selon
le point d'entrée : depuis les **champs typés** du modèle (`DateTime`,
`TimeOfDay`) ou depuis son **`toMap()`** déjà sérialisé (chaîne ISO-8601, ou
`Map {start, end}` pour une plage). Les deux conventions sont légitimes, et un
moteur qui n'en lit qu'une **rend un champ vide** pour l'autre — silencieusement,
alors que la valeur serait resoumise intacte au prochain enregistrement.

Le champ date de zcrud (mode `date`/`dateTime`/`time`) accepte en lecture la
chaîne ISO-8601 (`String`, sa propre convention d'écriture), un `DateTime` et,
en mode `time`, un `TimeOfDay` — chacun normalisé vers la convention d'écriture
du mode. Le champ plage (`ZDateRange`) accepte de même sa chaîne persistée
**ou** la `Map {start, end}` issue de `toMap()`. Une graine d'un type non reconnu
n'est jamais tue : elle est rendue via sa représentation texte plutôt
qu'affichée vide, pour ne jamais laisser croire qu'un champ non vide en base
serait soumis vide.

**Implication migration** : si votre code hôte pré-convertissait les valeurs
date/plage avant de les passer à `DynamicEdition` (pour compenser un moteur qui
n'acceptait qu'un seul type de graine), cette conversion devient redondante —
elle reste inoffensive tant qu'elle produit une des formes ci-dessus, mais peut
être retirée.

## Les clés hors sous-schéma d'une sous-liste survivent à l'édition

Un champ de sous-liste (`subItems`) ou de sous-formulaire dynamique
(`dynamicItem`) déclare un **sous-schéma** propre (`itemFields`), distinct du
schéma racine. Une donnée legacy imbriquée porte fréquemment des clés que ce
sous-schéma ne déclare pas — le cas le plus fréquent étant l'identité de chaque
item (`id`) quand seul le sous-schéma métier a été porté vers zcrud.

zcrud préserve ces clés **par identité d'item** : à l'amorçage, chaque clé de la
graine absente du sous-schéma est capturée comme un résidu attaché à l'objet
item (jamais à sa position), réémis **avant** les tranches du sous-schéma à
chaque agrégation vers le parent. Deux conséquences directes pour une
migration :

- une clé **non déclarée** (comme un `id` legacy) traverse indemne
  l'édition — y compris un réordonnancement, un retrait ou une restauration
  après soft-delete, puisque le résidu suit l'item et non sa position ;
- une clé **déclarée** dans le sous-schéma et effacée par l'utilisateur reste
  effacée — le résidu ne la fait jamais ressusciter, il ne contient par
  construction aucune clé connue du sous-schéma.

Un item **ajouté** en session (bouton d'ajout, pas une graine du parent) n'a
par nature aucun résidu : son comportement est strictement celui d'un item créé
nativement dans zcrud.

## Les codecs legacy déjà couverts

Au-delà du géo (voir le lien en tête de page), deux familles de format legacy
sont lues **nativement**, sans script de migration :

- **Rich-text — formules et tableaux LaTeX legacy.** `zcrud_markdown` reconnaît
  en lecture les clés d'embed legacy `formula`/`formula_inline` (formule LaTeX
  hors bloc `zcrud`, en ligne dans le flux) ainsi qu'un tableau encodé en chaîne
  Markdown legacy — les trois builders de rendu correspondants sont câblés
  **automatiquement** dans les trois surfaces rich-text du paquet
  (`ZMarkdownField`, le mode inline du registre de widgets, et
  `ZRichTextFullscreenDialog`) ainsi qu'en lecture seule via `ZMarkdownReader`.
  Ils ne s'importent pas directement (implémentation interne, hors barrel) :
  vous n'avez rien à appeler, vous passez simplement le Delta legacy tel quel.
  C'est une voie de **lecture seule** — l'écriture (`toMap`/le codec de
  persistance) reste strictement au format `zcrud`, donc la première
  réédition et sauvegarde d'un contenu legacy le fait basculer au format
  courant.
- **Géo** — voir le guide dédié en tête de page.

Le principe commun : zcrud élargit ce qu'il **lit**, jamais ce qu'il **écrit**.
Un hôte passif n'a rien à faire ; un hôte qui pré-convertissait ces formats
avant de les transmettre au paquet peut retirer cette étape (cf. section
suivante).

## Stratégie de tripwire côté hôte

Une compensation legacy qu'on retire « à l'aveugle » au moment d'une migration
est un pari : si l'analyse de ce qu'elle compensait était incomplète, la
retirer réintroduit le défaut d'origine sans le signaler. La pratique
recommandée est le **tripwire** : au lieu de retirer la compensation en même
temps que vous migrez, gardez-la un temps derrière un test qui **affirme la
perte qu'elle corrige** plutôt que le comportement désiré — un test qui échoue
tant que la compensation reste nécessaire, et qui **rougit** le jour où le
comportement natif de zcrud change (une montée de version du paquet). Concrètement :
décodez la valeur legacy **sans** passer par votre compensation, et faites
échouer le test dès que ce résultat brut **rejoint** la valeur attendue — avec
un message qui pointe explicitement la compensation à retirer. Un tel test qui
**rougit** n'est jamais une régression de votre suite : c'est le signal que le
correctif amont a rattrapé la compensation, et que celle-ci peut être retirée
du code hôte sans perte.

## Checklist de migration

1. **Ne convertissez pas avant de brancher.** Essayez d'abord de passer les
   données legacy telles quelles à un modèle annoté `@ZcrudModel` ; la
   désérialisation défensive (AD-10) absorbe l'essentiel des écarts de forme.
2. **Déclarez l'ordre sur le modèle**, jamais déduit des clés persistées.
3. **Laissez les champs date/plage lire vos types existants** (`DateTime`,
   `TimeOfDay`, `Map {start, end}`) plutôt que de les pré-sérialiser.
4. **Pour les sous-listes et sous-formulaires dynamiques**, vérifiez que votre
   sous-schéma (`itemFields`) porte au minimum les champs que vous éditez —
   tout le reste (dont un `id` legacy) survit sans configuration supplémentaire.
5. **Pour le géo et le rich-text**, ne réécrivez rien avant migration : les
   formats legacy documentés se lisent nativement.
6. **Posez un tripwire** sur chaque compensation legacy que vous retirez, avant
   de la retirer — pas après.

## Voir aussi

- [Invariant AD-10](../concepts/invariants.md#ad-10) — schéma additif,
  désérialisation défensive.
- [Invariant AD-4](../concepts/invariants.md#ad-4) — extension par composition.
- [Offline-first](../concepts/offline-first.md) — la même discipline défensive
  appliquée à la synchronisation.
- Migration géo détaillée :
  [`packages/zcrud_geo/doc/migration-legacy-dodlp-geo.md`](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_geo/doc/migration-legacy-dodlp-geo.md).
