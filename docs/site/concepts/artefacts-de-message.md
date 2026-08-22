---
title: "Concept : artefacts de message déclarés"
description: Déclarer par message ce qu'une réponse a produit — clé opaque, lectures d'état, verbes ordonnés, teinte et occupation.
sidebar_position: 6
---

# Artefacts de message déclarés

Dans un usage **notebook**, une réponse n'est pas seulement du texte : elle a produit — ou
peut produire — une carte mentale, un jeu de flashcards, un résumé, une note. Ces
**artefacts** s'affichent sous le message : un glyphe par artefact, teinté quand le
contenu existe, avec un compte et un menu de verbes.

zcrud rend cette rangée à partir d'une **déclaration** (`ZChatArtifactSpec`) et
n'introduit ni modèle d'artefact, ni chemin d'exécution : l'hôte dit *quoi* montrer et
*comment lire l'état sur son propre message* ; le socle rend, teinte, annonce, confirme.

## Une clé opaque, jamais une identité {#cle-opaque}

`ZChatArtifactSpec.key` est un `String` que le socle **n'interprète pas**. Il ne connaît
ni « carte mentale » ni « flashcards » : la clé ne sert qu'à deux choses — retrouver un
accent dans la chaîne de teinte, et distinguer deux entrées dans l'arbre de widgets
(`ValueKey(spec.key)`).

C'est la même discipline que `ZChatCustomAction.verb` : les identités, le stockage et le
vocabulaire métier restent chez l'hôte. Une clé `classroom` peut parfaitement désigner
une entité stockée sous un tout autre nom.

```dart
ZChatArtifactSpec(
  key: 'mindmap',                       // opaque, choisie par l'hôte
  icon: Icons.map_outlined,
  label: l10n.mindmap,                  // DÉJÀ localisé par l'hôte
  presence: (m) => m.mindmapId != null,
  count: (m) => compterNoeuds(m),        // null ⇒ aucune pastille
  busy: (m) => generationEnCours(m.id),
  actions: <ZChatArtifactAction>[
    ZChatArtifactAction.create(onSelected: creer),
    ZChatArtifactAction.open(onSelected: ouvrir),
    ZChatArtifactAction.regenerate(onSelected: regenerer),
    ZChatArtifactAction.delete(onSelected: supprimer),
  ],
)
```

`key`, `icon`, `label` et `presence` sont les seuls champs requis : un artefact **sans
aucun verbe** est un indicateur d'état, et c'est une déclaration légitime.

## Trois lectures d'état, sur le message brut {#lectures-etat}

Les trois lectures reçoivent le `ZChatMessage` **tel que l'hôte le connaît**. Le socle
n'en dérive aucun modèle : un artefact peut donc vivre dans un champ, dans une collection
annexe ou dans une paire de messages, sans que le socle ait à le savoir.

| Lecture | Signature | Ce que le socle en fait |
|---|---|---|
| `presence` | `bool Function(ZChatMessage)` | décide si le glyphe est **teinté** et quels verbes sont visibles |
| `count` | `int? Function(ZChatMessage)` | pastille de compte ; `null` **et** toute valeur `<= 0` ⇒ aucune pastille |
| `busy` | `bool Function(ZChatMessage)` | anime **ce** glyphe pendant une génération |

Chaque lecture est appelée **dans un `try`** par le rendu. Une lecture qui lève retombe
sur un repli **fermant** (invariant [AD-10](invariants.md#ad-10)) : artefact traité comme
absent, compte nul, occupation fausse, verbe masqué — et l'échec est relayé à
`FlutterError`. Jamais l'inverse : un repli ouvrant offrirait un verbe destructeur sur un
état qu'on n'a pas pu lire.

Les méthodes publiques `isPresent`, `countOf`, `isBusy` et `visibleActions` exposent
exactement ces replis, et sont testables sans monter de widget.

### Un artefact n'est rendu que s'il a quelque chose à dire

Une entrée n'apparaît que si l'artefact est **présent**, **occupé**, ou porte **au moins
un verbe visible**. Conséquence utile : un hôte déclare ses artefacts **une fois pour
tout le fil** — sur un message d'utilisateur, aucune condition ne tient, donc aucun
glyphe n'apparaît. Aucune affordance inerte n'est jamais rendue
([AD-4](invariants.md#ad-4)).

## Des verbes ordonnés, avec leurs conditions {#verbes}

`ZChatArtifactAction` porte un rappel, une condition de visibilité, un glyphe facultatif
et une teinte propre. Les verbes sont rendus **dans l'ordre déclaré** : le socle ne les
réordonne pas, parce qu'une application rend couramment « Régénérer » à une place
différente selon l'artefact.

| Constructeur | Visible quand | Destructeur |
|---|---|---|
| `ZChatArtifactAction.create` | l'artefact est **absent** | non |
| `ZChatArtifactAction.open` | l'artefact est **présent** | non |
| `ZChatArtifactAction.regenerate` | l'artefact est présent | non |
| `ZChatArtifactAction.edit` | l'artefact est présent | non |
| `ZChatArtifactAction.delete` | l'artefact est présent | **oui** |
| `ZChatArtifactAction(...)` | `visible` (`null` ⇒ toujours) | `destructive` au choix |

La condition reçoit `(message, present)` où `present` est le résultat **déjà résolu** de
`presence` : la même lecture n'est jamais réécrite deux fois. Les prédicats
`zChatArtifactWhenAbsent` et `zChatArtifactWhenPresent` sont publics et réutilisables.

Le libellé vient soit de `label` (texte **déjà localisé** par l'hôte, prioritaire), soit
de `labelKey`, résolu par les libellés injectés au `ZcrudScope` puis par la table de
repli du socle. Les cinq constructeurs nommés posent la clé correspondante : un hôte
obtient un menu libellé sans rien alimenter.

**Toucher le glyphe ouvre un menu** — jamais une régénération silencieuse. C'est le rôle
du verbe `open`.

### Confirmation d'un verbe destructeur

`destructive: true` fait demander une confirmation **avant** d'appeler `onSelected`.
Deux chemins :

- sans couture, le socle confirme **en place**, dans le menu lui-même — il ne dépend
  d'aucune surface stylée et ne peut donc pas pousser un dialogue Material ;
- avec `ZChatArtifactConfirm` (passé en `confirm` / `confirmArtifactAction`), l'hôte rend
  sa propre confirmation. Elle reçoit un `ZChatArtifactConfirmRequest` (message, artefact,
  verbe) et rend `Future<bool>` ; `false` n'exécute rien.

`confirmMessage` porte un texte **déjà localisé** ; `null` laisse le socle poser sa
question générique.

## La chaîne de résolution de l'accent {#accent}

La teinte d'un artefact est cherchée dans cet ordre, **par clé**, et le premier niveau
renseigné gagne :

```
ZChatArtifactSpec.accent              ← paramètre, ici et maintenant
      ↓ (si null)
ZChatNotebookSkin.capabilityAccents   ← paramètre de surface, table clé → couleur
      ↓ (si null)
ZcrudTheme.chatCapabilityAccents      ← jeton, pour toute l'application
      ↓ (si null)
ZChatNotebookReference                ← valeurs de référence auditées
```

Les deux tables du milieu sont lues **par clé** : un accent déclaré pour une clé que la
référence ne connaît pas est honoré — c'est ainsi qu'un hôte teinte un artefact qu'il
invente.

Deux règles à connaître avant de choisir une couleur :

1. **La teinte n'est peinte que si l'artefact existe.** Un glyphe teinté en permanence
   est une décoration ; un glyphe qui se teint quand le contenu arrive est une
   information. Un artefact absent garde la couleur ambiante.
2. **La teinte déclarée est portée au plancher de contraste avant d'être peinte**, par
   `zReadableTintOn` (voir [le thème et la couleur dans zcrud_core](../paquets/zcrud_core.md#theme-couleur)).
   Une couleur qui satisfait déjà le plancher est rendue **inchangée**. Si aucune surface
   n'est résolvable, **aucune** teinte n'est peinte — repli fermant, là encore.

L'information ne repose donc jamais sur la seule couleur : `Semantics.value` porte
« déjà généré » / « aucun contenu », l'occupation et le compte
([AD-13](invariants.md#ad-13)).

## L'occupation : animée par artefact {#occupation}

Quand `busy` rend `true`, **le glyphe de cet artefact** parcourt une palette en boucle.
L'animation est déléguée à `ZColorCycle`, la primitive de `zcrud_core` — elle ne connaît
ni le chat ni les artefacts.

Trois propriétés structurelles :

- **Indexée par artefact, par construction.** Le cycle est monté *dans* le bouton d'un
  artefact et alimenté par la lecture `busy` de *sa* spec. Il n'existe aucun endroit où
  écrire « tout est occupé » : une occupation qui animerait tous les glyphes à la fois
  est inexprimable.
- **L'animation prime sur la teinte de présence**, et la teinte d'état revient dès que
  l'occupation retombe (elle est passée en `idle` au cycle).
- **Additif strict.** Le cycle n'est monté que si la spec **déclare** une lecture `busy`.
  Sans elle : aucun `ZColorCycle`, aucun contrôleur, aucune animation — l'arbre est
  exactement celui d'un hôte qui n'a rien déclaré.

La palette vient de la même chaîne à trois niveaux (`ZChatNotebookSkin.busyPalette` >
`ZcrudTheme.chatBusyPalette` > `ZChatNotebookReference.busyPalette`, sept teintes), et le
tempo de `ZChatNotebookReference.busyCycleDuration` — la durée d'un **tour complet**, pas
d'un segment.

### Sous « Réduire les animations »

Avec `MediaQuery.disableAnimations`, `ZColorCycle` **n'arme aucun contrôleur** — pas même
un contrôleur de durée nulle qui continuerait de battre — et fige la **première teinte de
la palette**. L'occupation reste donc perceptible sur deux canaux : cette teinte, et
l'annonce sémantique qui la portait déjà. Un état qui disparaîtrait avec l'animation
serait un défaut d'accessibilité, pas une simplification
([AD-13](invariants.md#ad-13)).

## Où la rangée se monte {#montage}

Deux points d'entrée, selon la surface :

| Surface | Déclaration |
|---|---|
| `ZChatNotebookView` | paramètre `artifacts` (+ `skin`, `confirmArtifactAction`) — le socle monte la rangée lui-même |
| `ZChatConversationView` | `ZChatArtifactBar.slot(artifacts: …, host: …)` passé en `actionsBuilder` |

Dans les deux cas, le créneau d'actions que l'hôte avait déjà **cohabite** avec la
rangée : son contenu est rendu au-dessus, jamais remplacé. Avec `artifacts` vide — le
défaut — le créneau de l'hôte est relayé **à l'identique** (même référence, `null`
compris) : l'ajout est strictement additif.

Les glyphes sont disposés en `Wrap`, pas en `Row` : quel que soit le nombre d'artefacts,
chaque cible garde ses 48 dp et reste dans l'écran — la rangée passe à la ligne au lieu
de rétrécir ou de déborder. Un appelant n'a donc **aucun mécanisme de débordement à
prévoir**, et ne devrait pas en ajouter : cela déplacerait des cibles déjà atteignables
derrière une affordance de plus. `spacing` règle l'écartement dans les deux axes.

## Coiffer une réponse de sa question {#coquille}

`ZChatTileShell` est la **coquille déclarée** d'une tuile : carte, filet, coiffe, style du
bouton de dépli, format d'horodatage. Elle est un **interrupteur**, pas un réglage de
plus : tant qu'aucune coquille n'est déclarée, la tuile rend exactement l'arbre qu'elle
rendait sans elle — aucun conteneur, aucun filet, aucune coiffe, aucun horodatage.
Déclarer `const ZChatTileShell()` demande le rendu **de référence** ; chaque champ
renseigné le corrige.

`topicOf` (`ZChatTurnTopicResolver`) choisit le **sujet du tour** qui coiffe un message.
Ce n'est **pas** l'identité de l'interlocuteur — celle-ci a son propre créneau
(`ZChatMessageTile.identityBuilder`) et reste structurellement absente de la surface
notebook. Le résolveur prêt à l'emploi `zChatPrecedingRequestTopic` coiffe une réponse du
texte de la question qui l'a produite ; rendre `null` (ou une chaîne vide) signifie
« aucune coiffe pour ce message ».

`timestampFormatter` (`ZChatTimestampFormatter`) est l'échappatoire du format : le socle
n'a aucune dépendance de date et ne connaît donc ni locale ni calendrier. Un formateur
qui **lève** ne casse rien — l'horodatage retombe sur `zChatReferenceTimestamp` et
l'échec est relayé à `FlutterError`.

La coquille se déclare sur `ZChatNotebookSkin.tile`, qui la fait traverser la racine
commune jusqu'à la fabrique de tuile unique : les deux surfaces ne peuvent donc pas
diverger.

## Actions par groupe dans la liste de conversations {#actions-de-groupe}

Le pendant côté liste : `ZChatConversationList.groupActionsBuilder`
(`ZChatGroupActionsBuilder`) déclare les actions rendues **dans l'en-tête d'un groupe**.
Le builder reçoit un `ZChatConversationGroup` — la **clé opaque** produite par
`groupKeyOf` et le **compte** du groupe — et rend des `ZChatGroupAction` (icône, libellé
d'accessibilité, info-bulle, rappel), tous fournis par l'hôte : le socle ne fabrique ni
glyphe, ni libellé.

Quatre conditions font que rien ne bouge pour un hôte passif :

- `groupActionsBuilder` nul ⇒ rendu historique, sans conteneur ni action ;
- sans `groupKeyOf`, sans `groupHeaderBuilder`, ou quand l'en-tête rend `null`, le builder
  **n'est pas appelé** ;
- une liste vide rend l'en-tête tel quel ;
- un builder qui **lève** replie ce **seul** groupe sur aucune action — la liste n'est
  jamais cassée ([AD-10](invariants.md#ad-10)).

Chaque bouton est neutre et complet : `Semantics(button:)`, cible de 48 dp, activation au
clavier.

## Voir aussi

- [zcrud_chat](../paquets/zcrud_chat.md) — le paquet qui porte ces types.
- [zcrud_core](../paquets/zcrud_core.md#theme-couleur) — `ZColorCycle` et `zReadableTintOn`.
- [Réactivité granulaire](reactivite-granulaire.md) — pourquoi le menu et l'animation ne reconstruisent pas la tuile.
- [Invariants d'architecture](invariants.md) — définitions canoniques AD-1 à AD-16.
