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

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_core/README.md) — installation, démarrage rapide, API complète.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Artefacts de message déclarés](../concepts/artefacts-de-message.md) — un consommateur de `ZColorCycle` et `zReadableTintOn`.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — couches et ports.
- [Offline-first](../concepts/offline-first.md) — AD-9 en pratique.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
