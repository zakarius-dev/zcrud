---
title: zcrud_core
description: Domaine pur et moteur d'édition/liste Flutter-natif — le pivot de l'écosystème zcrud.
---

# zcrud_core

## Rôle

`zcrud_core` est le **puits du graphe de dépendances** de l'écosystème zcrud
(invariant [AD-1](../concepts/invariants.md#ad-1)) : il porte le schéma
déclaratif `ZFieldSpec`, le moteur d'édition `DynamicEdition`, le moteur de
liste `DynamicList`, les ports de domaine (`ZRepository`, `ZLocalStore`,
`ZAcl`…) et la réactivité Flutter-native (`ZFormController`,
`ChangeNotifier`/`ValueListenable`). Il n'importe aucun autre paquet
`zcrud_*`, aucun gestionnaire d'état, aucun backend lourd — tous les autres
paquets du dépôt en dépendent.

Sa couche `domain/` est pur-Dart et exposée seule par
`package:zcrud_core/domain.dart`, pour les satellites dont seuls les modèles
ont besoin de rester transitivement pur-Dart.

## Quand l'utiliser

- Pour tout **formulaire d'édition** ou **tableau de liste** de l'écosystème
  zcrud : `ZFieldSpec` pilote les deux depuis une seule déclaration.
- Pour un état de formulaire qui ne reconstruit **jamais** l'écran entier à la
  frappe (invariant [AD-2](../concepts/invariants.md#ad-2)) — l'objectif
  produit historique de l'extraction du moteur.
- Pour un **contrat repository backend-agnostique** (`ZRepository<T>`) que
  n'importe quel adaptateur (`zcrud_firestore` ou un autre) peut implémenter.

## Quand ne pas l'utiliser

- Pour du rendu Markdown/LaTeX riche : c'est `zcrud_markdown`, qui dépend de
  `zcrud_core` et se branche via `ZWidgetRegistry`.
- Pour une grille de données `SfDataGrid` : c'est `zcrud_list`, qui implémente
  le port neutre `ZListRenderer` exposé ici.
- Pour la persistance Firestore/Hive concrète : ce sont les adaptateurs de
  `zcrud_firestore`, qui implémentent les ports neutres `ZRepository`/
  `ZLocalStore`/`ZRemoteStore`.
- Pour brancher un gestionnaire d'état particulier (Riverpod/GetX/provider) :
  ce sont les paquets de binding (`zcrud_riverpod`/`zcrud_get`/`zcrud_provider`),
  qui injectent le cycle de vie sans que le cœur en dépende.

## Le thème et la couleur {#theme-couleur}

Au-delà des jetons de `ZcrudTheme`, le cœur porte les **primitives de couleur**
partagées par tous les satellites. Elles vivent ici — et pas dans le paquet qui
les a fait naître — parce qu'un calculateur de contraste est unique par
construction : deux copies finissent toujours par diverger, et une arête
`zcrud_chat → zcrud_study` violerait l'invariant
[AD-1](../concepts/invariants.md#ad-1). `zcrud_study` continue de les exposer
**sous les mêmes noms** par ré-export : un hôte qui les importait de là n'a rien
à changer.

### Une teinte lisible sur la surface courante

`zReadableTintOn(base, surface:, minContrast:)` rend une teinte dérivée de
`base`, garantie à au moins `minContrast` contre `surface` — pour une couleur
d'entrée **arbitraire** (choisie par un utilisateur, déclarée par un hôte), en
clair comme en sombre.

- Si `base` satisfait **déjà** le plancher, elle est rendue **inchangée** : le
  choix de l'utilisateur n'est jamais réécrit sans nécessité.
- Sinon, la teinte est déplacée du plus petit écart suffisant, en **luminance
  linéaire** et non en clarté HSL : la chromaticité est préservée à
  l'assombrissement, une couleur achromatique le reste, et un quasi-blanc
  s'assombrit en gris — trois résultats hors de portée d'un ajustement HSL.
- La chaîne est **totale** ([AD-10](../concepts/invariants.md#ad-10)) : elle ne
  lève jamais et ne rend jamais `null`. Si aucune luminance n'atteint le
  plancher, la meilleure des deux extrémités est rendue.
- L'alpha de `base` est préservé ; la mesure porte sur l'opaque.

Deux planchers sont fournis, et le choix n'est pas cosmétique :

| Constante | Valeur | S'applique à |
|---|---|---|
| `kZNonTextMinContrast` | **3,0:1** (WCAG 2.2 §1.4.11) | bande d'accent, liseré, pastille, glyphe — tout objet graphique. C'est le **défaut**. |
| `kZTextMinContrast` | **4,5:1** (WCAG 2.2 §1.4.3 AA) | tout ce qui porte du texte au corps courant. |

`zRelativeLuminance` et `zContrastRatio` sont exposés pour mesurer soi-même, et
`zCompositeOver(foreground, background)` compose un aplat semi-transparent en la
couleur opaque réellement peinte.

### Sur quelle surface la mesure porte-t-elle ?

**Un rapport de contraste n'existe pas dans l'absolu : il n'existe que
relativement à une surface.** `zReadableTintOn` ne devine aucune surface — elle
mesure **exclusivement** contre celle passée en `surface`, ramenée à son opaque.

Cette précision est la règle qu'un appelant doit connaître, parce que deux
chiffres différents circulent pour la **même** couleur, et que **tous deux sont
exacts** :

| Teinte | Surface de mesure | Contraste |
|---|---|---|
| `#FF9800` | blanc pur (`#FFFFFF`) | **2,155** |
| `#FF9800` | `surface` Material 3 clair (`#FEF7FF`) | **2,049** |

Les tables de référence de la bibliothèque sont exprimées sur **blanc pur**,
borne haute du cas clair. La surface réelle d'un thème clair n'étant jamais
blanche, le contraste obtenu à l'écran est légèrement **plus faible** que le
chiffre de référence — sans conséquence sur la garantie rendue, qui porte
toujours sur la surface **réellement passée**.

Corollaire : passez la surface **réellement peinte** — composée par
`zCompositeOver` si elle est semi-transparente — et jamais un blanc supposé.

### La teinte par type de champ {#teinte-de-champ}

Un formulaire peut colorer ses champs **par type** : bordure de focus, libellé flottant,
glyphes d'ornement et pastille de fond prennent la même teinte, celle du type du champ.
La chaîne est **strictement opt-in** — sans résolveur injecté, la décoration est celle
d'un formulaire non teinté, au pixel près.

Le canal est le résolveur de dégradé du scope (`ZcrudScope.gradientResolver`), interrogé
sous deux familles de clés :

| Clé | Construite par | Ce qu'elle colore |
|---|---|---|
| `zcrud.fieldType.<type>` | `zFieldTypeTintKey(EditionFieldType)` | la teinte du champ : bordure de focus, libellé flottant, ornements `leading`/`prefix`/`suffix` en icône, pastille |
| `zcrud.fieldAccent.<nom>` | `zFieldAccentKey(String)` | l'accent d'un champ **nommé** (voir ci-dessous) |

Un résolveur répond aux clés qu'il connaît et rend `null` pour les autres. `null` est une
valeur fonctionnelle — « aucune teinte ici » — et rien n'est peint.

**Aucune couleur servie n'est peinte telle quelle.** Elle passe par `zReadableTintOn`,
mesurée contre la surface du champ (`ZcrudTheme.fieldFillColor`, à défaut
`ColorScheme.surfaceContainerHighest`) au plancher non-texte `kZNonTextMinContrast`, en
clair comme en sombre. Une teinte trop pâle pour son fond est donc corrigée avant
d'atteindre l'écran, sans que l'appelant ait à s'en occuper.

Trois fonctions publiques exposent cette chaîne à qui compose un rendu lui-même :

| Fonction | Ce qu'elle rend |
|---|---|
| `zResolveFieldTint(context, field)` | la teinte du **type** de `field`, normalisée — `null` si rien n'est servi. |
| `zResolveFieldAccent(context, field)` | la couleur d'accent : la clé **par champ** d'abord, à défaut la teinte de type. |
| `zResolveTintedAdornment(context, adornment, field:, valueOf:)` | un `ZTintedAdornment` (`tint` + `child`) : la teinte normalisée et l'ornement prêt à poser, glyphe teinté et pastille comprise. |

`zResolveTintedAdornment` est le point d'entrée des **présentateurs riches** — une tuile
de sélection, une carte — qui composent leur propre en-tête au lieu de passer par la
décoration native. Il leur évite de dupliquer la résolution de clé d'icône, la
normalisation de contraste et la gouvernance des jetons. Ce qui leur reste : poser le
widget, choisir leurs surfaces, et ne **pas** re-teinter le `child` rendu — il porte déjà
sa couleur.

La **pastille** — l'aplat arrondi peint sous un glyphe d'ornement décoratif — se déclare
par trois jetons : `adornmentIconBackgroundAlpha` (l'opacité, seul jeton déclencheur),
`adornmentIconBackgroundRadius` et `adornmentIconSize`. Sans l'alpha, aucun conteneur
n'est ajouté à l'arbre ; sans teinte résolue non plus, car le fond d'une pastille n'a pas
d'autre source de couleur qu'elle, et le paquet n'en invente aucune (FR-26). Un ornement
**interactif** (`ZFieldAdornment.onTap`) n'est jamais pastillé : il garde sa cible de
48 dp et son affordance de bouton.

Deux limites à connaître. Le rendu `bare` — celui d'un champ en carte large, dont le décor
appartient à la carte — ne teinte rien. Et `ZFieldTintPresets.classic` est une **table de
données copiable**, une teinte par grande famille de champ : le paquet ne la lit jamais.
Elle sert de point de départ à recopier ou référencer dans votre propre résolveur, pas de
défaut actif.

### L'accent supérieur d'un champ {#accent-de-champ}

Un champ peut porter une fine barre colorée à son sommet, dans la même grammaire que le
filet supérieur d'une section (`ZEditionSectionStyle.topAccent`). Elle est gouvernée par
un **double opt-in**, et aucun des deux termes ne peint seul :

1. `ZcrudTheme.accentBarHeight` fixe sa hauteur — `null` ou valeur ≤ 0 : aucune barre ;
2. une couleur doit se résoudre pour le champ via `zResolveFieldAccent` — sinon, aucune
   barre non plus.

La barre est purement décorative : elle n'ajoute ni ne réduit aucune cible tactile, et
s'étend sur toute la largeur, à l'identique dans les deux sens de lecture.

**`accentBarHeight` est un jeton partagé** : les chromes de carte de `zcrud_study` et de
`zcrud_flashcard` le lisent aussi. Le poser pour vos cartes alors qu'un résolveur de
teinte de type est en place fera donc apparaître la barre **sur vos champs** — l'effet
conjoint de deux déclarations, chacune correcte prise seule. Si ce n'est pas l'effet
voulu, retirez l'une des deux.

### `ZColorCycle` — le signal « tâche en cours »

`ZColorCycle` fait parcourir une palette en boucle et confie la teinte courante
à un `builder`. C'est une primitive de présentation **sans domaine** : elle ne
connaît ni le chat, ni les flashcards, ni la carte mentale, si bien que le même
signal sert partout où quelque chose se génère.

`palette` et `period` sont **requis, par principe** : le cœur n'invente ni
couleur ni tempo (FR-26). Les deux appartiennent à la table de référence du
module appelant, elle-même remplaçable par jeton et par paramètre.

| Paramètre | Rôle et défaut |
|---|---|
| `palette` | Les teintes parcourues, en boucle. Vide ⇒ `idle` (ou `null`). Une seule teinte ⇒ teinte fixe, aucun contrôleur. |
| `period` | Durée d'un **tour complet** — jamais d'un segment : une palette courte défile au même rythme d'ensemble qu'une longue au lieu de clignoter. Durée nulle ou négative ⇒ animation désactivée, sans rien casser. |
| `active` | `false` rend `idle` **sans créer le moindre contrôleur** ; repasser à `false` libère celui qui tournait. |
| `idle` | Teinte rendue hors cycle. `null` ⇒ couleur ambiante. |
| `surface` | Non nulle, chaque teinte rendue — celles de `palette` **comme** `idle` — passe par `zReadableTintOn` avant d'atteindre le `builder`. `null` rend les teintes inchangées. |
| `minContrast` | Plancher appliqué quand `surface` est fournie (défaut `kZNonTextMinContrast`). |
| `child` | Sous-arbre **stable** transmis tel quel au `builder` — ce qui ne dépend pas de la teinte n'est pas reconstruit à chaque frame. |

Sous `MediaQuery.disableAnimations`, **aucun `AnimationController` n'est créé**
— pas même un contrôleur de durée nulle qui continuerait de battre — et le
`builder` reçoit la **première teinte de la palette**, fixe. Un état qui
disparaîtrait quand on réduit les animations serait un défaut d'accessibilité,
pas une simplification.

Ce que la primitive **ne fait pas** : annoncer l'état. Une couleur qui bouge
n'est lisible ni au lecteur d'écran, ni pour qui ne distingue pas les teintes :
le canal textuel reste à la charge de l'appelant
([AD-13](../concepts/invariants.md#ad-13)). La fonction pure `zColorCycleAt`
donne la teinte à un avancement donné, sans jamais lever.

## CRUD inline d'une entité liée : trois gestes, trois droits {#relation-crud}

Depuis un sélecteur de champ `relation`, un utilisateur peut **créer**,
**modifier** ou **copier** l'entité liée sans quitter le formulaire ; l'option
résultante est **auto-sélectionnée**. Le cœur ne connaît ni formulaire
d'édition, ni repository : il rend les affordances et appelle le port
`ZRelationCrudHandler`, que l'application ou un binding implémente et enregistre
dans un `ZRelationCrudRegistry`, injecté par
`ZcrudScope(relationCrudRegistry: …)` et résolu par `ZRelationConfig.crudKey`.
Sans clé, sans registre ou sans handler : **aucun** bouton — le rendu est celui
d'une sélection ordinaire.

Chaque opération rend un `Future<ZFieldChoice?>` : l'option à sélectionner, ou
`null` si l'utilisateur annule ou si l'opération échoue. Un `Future` en erreur
est capté défensivement — aucune écriture, aucun crash
([AD-10](../concepts/invariants.md#ad-10)).

**Les trois gestes se gouvernent séparément.** `canCreate`, `canEdit` et
`canCopy` valent `true` par défaut : un handler écrit avant cette capacité se
comporte exactement comme avant. Enregistrer un handler n'ouvre donc plus
forcément les trois boutons — un utilisateur peut avoir le droit de *modifier*
sans avoir celui de *créer*.

| Point du contrat | Ce qu'un appelant doit savoir |
|---|---|
| **Frontière ACL** | Les trois booléens sont **calculés par l'implémentation du port**, seule à connaître les permissions de l'application ; le socle ne fait que les lire ([AD-16](../concepts/invariants.md#ad-16)). |
| **Absent, pas inerte** | Un geste refusé n'est **pas rendu** : ni bouton, ni icône, ni action sémantique. Un bouton laissé en place qui ne fait rien est pire qu'un bouton absent — l'usager clique, rien ne se passe, et rien ne lui dit pourquoi. |
| **Repli fermant** | Le socle ne lit jamais `canCreate`/`canEdit`/`canCopy` en direct : il passe par `ZRelationCrudOffer` (`offersCreate`/`offersEdit`/`offersCopy`/`offersAnyGesture`), qui capte un getter qui **lève** et **ferme** le geste. Retomber sur `true` transformerait un incident d'ACL en autorisation silencieuse. |
| **Getters, pas méthodes** | Le droit se décide au grain du couple utilisateur × ressource liée, et un handler est résolu **par ressource**. La valeur est lue une fois à la construction du rendu — aucun code d'ACL n'entre dans le chemin de défilement de la liste d'options ([AD-2](../concepts/invariants.md#ad-2)). |
| **Non réactif** | Les droits d'un utilisateur ne changent pas pendant qu'un sélecteur est ouvert : aucun abonnement, aucune invalidation. |

`copy` **crée** une entité : une ACL qui refuse la création refuse en général
aussi la copie. Les deux restent néanmoins distincts — le socle n'en déduit
rien, il lit ce que l'hôte déclare.

Cette gouvernance vaut à l'identique pour le rendu natif du cœur et pour tout
présentateur riche enrôlé via `ZcrudScope.selectPresenter`, dont
[zcrud_select](zcrud_select.md).

## Le formulaire groupé : sections, ordre et en-têtes {#formulaire-groupe}

`DynamicEdition` dispose de deux voies de rendu. La voie **plate** aligne les champs les
uns sous les autres, dans l'ordre de `fields`. La voie **groupée** — la seule qui décore —
s'active dès qu'une mise en page responsive est déclarée (`layout`) ou qu'une des
`sections` est `collapsible`, porte une `icon` ou un `style`.

**L'ordre déclaré de `fields` fait loi.** Une section est émise à la position de son
**premier membre visible** ; les champs qui n'appartiennent à aucune section forment des
blocs intercalés, à leur place. Un champ indépendant peut donc suivre une section décorée
sans avoir à être enveloppé dans une section factice pour trouver sa place. À l'intérieur
d'une section, les membres suivent l'ordre de la déclaration de la section.

**Une section sans titre ni icône ne rend aucun en-tête** : ni chrome, ni rembourrage, ni
nœud sémantique. C'est la règle générale du paquet — rien de déclaré, rien d'ajouté à
l'arbre. Le corollaire mérite d'être connu : une section `collapsible` sans en-tête n'a
aucun déclencheur de repli, et **reste dépliée**.

`ZEditionSection` porte deux canaux d'habillage, `null` par défaut l'un comme l'autre :
`icon`, le glyphe de préfixe rendu avant le titre, et `style`, un `ZEditionSectionStyle`.

Ce style est un objet `const` à dix propriétés, **toutes nullables** : une propriété non
déclarée conserve le rendu natif. `background`, `topAccent`, `radius`, `titleStyle`,
`headerPadding` et `iconColor` habillent l'en-tête ; `collapsedIcon` et `expandedIcon`
remplacent les chevrons d'une section repliable ; `startRailColor` et `startRailWidth`
tracent un **filet vertical côté début**, courant sur toute la hauteur des champs de la
section. Ce filet est directionnel : il passe de l'autre côté en écriture de droite à
gauche (invariant [AD-13](../concepts/invariants.md#ad-13)). Sans `startRailColor`, aucun
filet — l'épaisseur seule ne trace rien.

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

const section = ZEditionSection(
  title: 'Identité',
  fields: <String>['firstName', 'lastName'],
  icon: Icons.person_outline,
  style: ZEditionSectionStyle(
    topAccent: BorderSide(color: Color(0xFF667EEA), width: 2),
    startRailColor: Color(0xFF667EEA),
  ),
);
```

## La sous-liste : ordre, actions et aération {#sous-liste}

Un champ `subItems` rend un mini-CRUD imbriqué à partir d'un sous-schéma déclaré
(`ZSubListConfig.itemFields` — voir [ZFieldSpec](../concepts/zfieldspec.md#sous-schemas)).
Quatre familles de canaux gouvernent sa présentation : le geste d'ordre, les actions de
ligne, l'en-tête et l'aération verticale.

### Réordonner : une poignée, jamais des flèches

Quand l'ordre est éditable, chaque ligne porte une **poignée de glissement** (cible ≥ 48
dp, libellée) et la collection est rendue par le port `ZReorderRenderer` : celui injecté
par `ZcrudScope(reorderRenderer: …)`, sinon un **repli interne** qui ne demande aucune
injection. Contrairement au port de liste, l'absence d'injection ne lève pas — la capacité
reste fonctionnelle, seulement non spécialisée.

Le contrat du port impose une **voie non gestuelle** : chaque ligne expose des actions
sémantiques « déplacer avant » et « déplacer après », la première ligne sans « avant », la
dernière sans « après ». C'est l'équivalent accessible du glissement ; il n'existe aucun
bouton de déplacement en fin de ligne.

`ZSubListConfig.reorderable` est **tri-état** :

| Valeur | Effet |
|---|---|
| `null` (défaut) | L'ordre n'est éditable qu'en mode `inline`. Les modes `compact` et `tags` ne rendent aucun contrôle d'ordre. |
| `true` | L'ordre est éditable en `inline` **et** en `compact`. En `tags`, la déclaration n'a pas de sens — une puce n'a ni rangée ni poignée — et elle est signalée par une assertion de debug, jamais ignorée en silence. |
| `false` | Aucun réordonnancement, dans aucun mode, même avec un renderer injecté au scope. |

Conséquence de présentation à connaître : **le résumé tabulaire et l'ordre éditable
s'excluent**. Une `Table` fige ses lignes, aucun glissement n'y est possible ; quand
l'ordre est éditable, le mode `compact` rend donc une liste de lignes à poignée, ses
en-têtes de colonnes conservés par une réserve de tête. Si la compacité de la table compte
plus que le réordonnancement, `reorderable: false` la rétablit.

Un hôte qui fournit son propre conteneur de liste (`ZSubListSeams.listViewBuilder`) garde
la main : les lignes qui lui sont servies **n'emportent pas de poignée**, et il reçoit le
rappel `ZSubListViewData.onReorder` — `null` quand l'ordre n'est pas éditable. Le socle
n'ajoute aucun contrôle du seul fait qu'un conteneur est déclaré.

### Ce qui est montré, et ce qui est permis

Trois préférences gouvernent les actions de fin de ligne du mode `compact` :
`showViewAction`, `showEditAction` et `showDeleteAction`, toutes `true` par défaut.

Elles ne sont **pas** un canal de droits. Une action n'est rendue que si elle est
**permise** (`ZAcl`) **et** préférée : une préférence ne peut jamais faire apparaître un
geste que l'ACL refuse, seulement retirer un geste qu'elle autorise. L'action
« restaurer » d'une ligne en soft-delete échappe à `showDeleteAction` — sans elle, la ligne
serait un cul-de-sac.

### L'en-tête

`ZSubListSeams.headerBuilder` reçoit une `ZSubListHeaderView` : le `field` conteneur, le
`itemCount` réellement agrégé (items en soft-delete exclus), le `addControl` natif
déjà filtré par l'ACL, et `onAdd` — le rappel qui ouvre le formulaire de création natif,
`null` quand la création n'est pas autorisée. C'est ce rappel qui permet d'**habiller**
l'ajout, et pas seulement de le positionner, sans renoncer à la machinerie native.

`headerBuilder` prime sur `captionBuilder` quand les deux sont déclarés ; `captionBuilder`
reste honoré à l'identique pour un seam déjà écrit.

### Six jetons pour l'aération verticale

L'espacement vertical **interne** d'une sous-liste se règle par six jetons de `ZcrudTheme`,
tous nullables et **inertes par défaut** : tant qu'aucun n'est posé, la géométrie est
exactement celle du rendu natif.

| Jeton | Ce qu'il règle | Valeur appliquée à défaut |
|---|---|---|
| `subListCaptionTopPadding` | réserve au-dessus du libellé du bloc, dans les trois modes | 8 |
| `subListHeaderTopPadding` | réserve au-dessus de la ligne d'en-têtes d'un résumé **non tabulaire** | 8 |
| `subListRowVerticalPadding` | de part et d'autre de chaque ligne (résumé non tabulaire, carte `inline`) | 4 |
| `subListCellVerticalPadding` | à l'intérieur d'une cellule du résumé **tabulaire** | 8 |
| `subListTableVerticalMargin` | au-dessus et au-dessous de la table de résumé | 4 |
| `subListBlockEndPadding` | fin de bloc, sous le contrôle d'ajout des modes `inline` et `tags` | 8 |

La recette la plus compacte pose les six à la fois :

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget compactSubLists(Widget child) => ZcrudScope(
      theme: const ZcrudTheme(
        subListCaptionTopPadding: 0,
        subListHeaderTopPadding: 0,
        subListRowVerticalPadding: 0,
        subListCellVerticalPadding: 2,
        subListTableVerticalMargin: 0,
        subListBlockEndPadding: 0,
      ),
      child: child,
    );
```

Un poste **n'est délibérément pas réglable** : le jeu qui porte la cible tactile de 48 dp
d'une poignée de réordonnancement. C'est un plancher d'accessibilité
([AD-13](../concepts/invariants.md#ad-13)), et offrir de le régler reviendrait à offrir de
le casser. Sur une sous-liste réordonnable, c'est pourtant le poste dominant ;
l'échappatoire est `reorderable: false`, qui bascule sur le résumé tabulaire — plus compact
et plus réglable.

## Ce qu'un champ déclare {#champs-declares}

### Le clavier

`ZTextConfig.keyboardType` est une **chaîne neutre**, jamais un `TextInputType` — celui-ci
ferait entrer Flutter dans le domaine pur. La table de correspondance est **fermée** :

| Valeur | Clavier |
|---|---|
| `'text'` | alphabétique standard |
| `'multiline'` | multi-ligne (touche retour) |
| `'email'` | e-mail |
| `'url'` | URL |
| `'phone'` | téléphone |
| `'number'` | numérique signé |
| `'decimal'` | numérique signé, séparateur décimal |
| `'name'` | nom de personne |
| `'address'` | adresse postale |
| `'datetime'` | date et heure |
| `'none'` | aucun clavier logiciel |

`null` ou une chaîne hors table : le clavier est dérivé du rendu — multi-ligne pour un
champ multi-ligne, texte sinon — jamais une exception. Et un champ **rendu** multi-ligne
garde le clavier multi-ligne quelle que soit la déclaration : la touche retour lui est
nécessaire, la déclaration ne porte que sur les champs mono-ligne.

### Une règle de texte pour tout un formulaire

`ZcrudScope(defaultTextConfig: …)` pose une `ZTextConfig` **par défaut**, appliquée à tout
champ `text`, `multiline` ou `password` qui ne déclare **aucune** config. La précédence est
simple et joue **en bloc** : une config déclarée par le champ l'emporte entièrement, sans
fusion membre à membre. C'est le canal qui évite de re-déclarer la même capitalisation ou
le même clavier champ par champ sur un formulaire entier.

`ZTextCapitalization` compte un mode `lowercase` en plus des trois modes conventionnels.
Comme les autres, la garantie est portée par un formateur déterministe : elle tient au
collage, à la saisie programmatique et au clavier physique, là où l'indice de clavier
logiciel du système ne dit rien. `ZTextConfig.textTransform` couvre le reste — une fonction
pure et totale, appliquée **après** la capitalisation, donc le dernier mot revient à l'hôte.

### Le formatage d'affichage des nombres

`ZNumberDisplayFormatter` est le port de **projection** d'un nombre, jumeau du port de
dates : injecté par `ZcrudScope(numberDisplayFormatter: …)`, consommé par la fiche de
lecture d'un champ numérique et par le résumé d'une sous-liste. Le paquet n'invente aucun
format — un rendu localisé exige `intl`, dont le cœur ne dépend pas
([AD-1](../concepts/invariants.md#ad-1)).

Le repli est **défini et total** ([AD-10](../concepts/invariants.md#ad-10)) : la chaîne
brute, dans tous les chemins dégradés — aucun port injecté, valeur non numérique, port qui
rend `null` ou une chaîne vide, port qui lève. Le formatage n'est donc visible que pour qui
injecte le port. Les suffixes neutres de `ZNumberConfig` (pourcentage, symbole monétaire)
restent apposés **après** ce formatage : le port n'a pas à les connaître.

### Des bornes lues dans un autre champ

`ZNumberConfig.minValueKey` et `maxValueKey` nomment un autre champ dont la valeur fixe la
borne. Elle est lue **à la validation**, et le champ borné est **revalidé quand le champ
référencé change** — par un abonnement ciblé à sa tranche, jamais par un rebuild du
formulaire ([AD-2](../concepts/invariants.md#ad-2)). Une référence absente ou non numérique
est non bloquante, jamais une exception. `ZDateConfig.firstDateKey`/`lastDateKey` suivent
exactement la même mécanique.

### La lecture seule conditionnelle

`ZDerivation` porte cinq cibles : `value`, `options`, `visible`, `bounds` et `readOnly`.
La cinquième dérive la **lecture seule** d'un champ depuis la valeur d'autres champs.
Synchrone comme `visible`, elle se propage exactement comme le `readOnly` statique de la
spec — toutes familles comprises, champs servis par un registre inclus.

Une règle à retenir : **le statique prime**. Une dérivation qui rend `false`, ou qui lève,
laisse le `readOnly` déclaré sur la spec reprendre seul la main ; elle ne rend jamais
éditable un champ déclaré `readOnly: true`.

### L'œil du mot de passe, et l'ornement qui répond au tap

Un champ `password` éditable porte nativement une bascule **afficher/masquer** dans son
slot suffixe : cible ≥ 48 dp, sémantique à état, masqué à chaque montage. Elle prime sur un
ornement `suffix` en icône que le champ déclarerait — le geste de la famille n'est jamais
évincé par un décor. Un champ `password` en lecture seule n'en reçoit pas.

`ZFieldAdornment.onTap` rend un ornement **interactif**. `null` (le défaut) le laisse
purement décoratif ; non nul, la présentation l'enveloppe dans une cible accessible (≥ 48
dp, sémantique de bouton) et appelle la fonction au tap. C'est le seul membre de
`ZFieldAdornment` à porter une closure : il n'est donc pas émissible par le générateur, et
il est volontairement **exclu de l'égalité de valeur** — deux ornements ne diffèrent jamais
par l'identité d'une closure.

### La valeur par défaut, réellement appliquée

`ZFieldSpec.defaultValue` est amorcé par le moteur d'édition sur toute tranche que les
valeurs initiales n'ont **pas** fournie. Le discriminant est la **présence de la clé**,
jamais la valeur : une clé fournie à `null` **explicite** est autoritaire et n'est pas
remplacée par le défaut. Sont également préservées une tranche déjà saisie et une tranche
déjà écrite à une valeur non nulle.

L'amorçage écrit la tranche **et** la ligne de base : un défaut appliqué n'est pas une
modification, le champ reste vierge. Seuls les écouteurs de la tranche amorcée sont
notifiés, jamais un canal global ([AD-2](../concepts/invariants.md#ad-2)). Le point
d'entrée est `ZFormController.seedDefaultValue(name, value)`, idempotent.

## Types clés

| Type | Rôle |
|---|---|
| `ZFieldSpec` / `EditionFieldType` | Schéma déclaratif `const` d'un champ, source unique pour l'édition et la liste. |
| `ZFormController` | Contrôleur `ChangeNotifier` du formulaire — une `ValueListenable` par champ (invariant [AD-2](../concepts/invariants.md#ad-2)). |
| `DynamicEdition` / `DynamicList` | Formulaire et liste de référence, dispatchés par type de champ / mise en page. |
| `ZRelationCrudHandler` / `ZRelationCrudOffer` | Port du CRUD inline d'une entité liée, et la lecture **défensive et fermante** des trois droits (`offersCreate`/`offersEdit`/`offersCopy`). |
| `ZRepository<T>` / `ZFailure` | Contrat repository backend-agnostique et hiérarchie d'erreurs maison (invariant [AD-5](../concepts/invariants.md#ad-5)/[AD-11](../concepts/invariants.md#ad-11)). |
| `ZcrudScope` / `ZcrudTheme` | Injection zéro-dépendance (resolver, l10n, thème) et jetons visuels thémés. |
| `zReadableTintOn` / `ZColorCycle` | Teinte portée à un plancher de contraste **mesuré sur la surface passée**, et cycle de teintes « tâche en cours » (palette et tempo requis). |
| `zResolveFieldTint` / `zResolveFieldAccent` / `zResolveTintedAdornment` | Chaîne publique de la teinte par type de champ : teinte normalisée, couleur d'accent, ornement prêt à poser pour un présentateur riche. |
| `ZReorderRenderer` | Port neutre de rendu réordonnable — injecté par `ZcrudScope`, repli interne zéro-injection, voie non gestuelle garantie par le contrat. |
| `ZEditionSection` / `ZEditionSectionStyle` | Section visuelle d'un formulaire et son habillage déclaré (icône, filets, chevrons) — tout nullable, rendu natif à défaut. |
| `ZNumberDisplayFormatter` | Port neutre de formatage d'affichage d'un nombre, à repli total sur la chaîne brute. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_core/README.md) — installation, démarrage rapide, API complète.
- [ZFieldSpec](../concepts/zfieldspec.md) — l'anatomie de la déclaration qui pilote tout ce qui précède.
- [Charte documentaire](../charte.md#jetons-de-theme) — la règle qui gouverne les jetons de thème.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Artefacts de message déclarés](../concepts/artefacts-de-message.md) — un consommateur de `ZColorCycle` et `zReadableTintOn`.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — couches et ports.
- [Offline-first](../concepts/offline-first.md) — AD-9 en pratique.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
