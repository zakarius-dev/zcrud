# Changelog

Toutes les modifications notables de `zcrud_chat` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.5.0 — 2026-08-22

### ⚠️ Corrigé — le libellé d'une pastille n'est plus la couleur de surface

Le premier plan d'une pastille de compte dérivait de la **surface ambiante**,
corrigée au contraste contre le fond. En thème sombre, une surface quasi noire
tenant déjà le plancher contre un rouge saturé était donc peinte **telle quelle**
— du noir sur une pastille d'alerte. Correct au sens de la mesure, faux au sens
de l'usage.

Le libellé dérive désormais du rôle **premier plan d'erreur**, avec l'ancienne
chaîne appariée en repli et le plancher 4,5:1 conservé en **garde-fou** — il
corrige un couple illisible, il ne choisit plus la couleur.

🔴 **Le rendu par défaut change**, dans le sens de la lisibilité, mesuré sur le
schéma du SDK : en clair `#D6D6D6` → `#FFFFFF`, en sombre `#535353` → `#601410`.
⚠️ Un hôte qui surcharge la couleur d'erreur **sans** surcharger son premier plan
obtient un couple désaccordé, rattrapé par le plancher : pour le rendu exact
attendu, surcharger **les deux rôles ensemble**.

### Ajouté — la présentation d'un menu d'artefact devient injectable

`menuBuilder` sur la barre d'artefacts, **relayé par la vue notebook** — sans ce
relais, la couture serait inatteignable depuis la surface que les hôtes montent.

Le rappel reçoit **exactement les verbes visibles** et un sélecteur qui passe par
le **même chemin** que le rendu par défaut : une présentation injectée ne peut ni
contourner la confirmation d'un verbe destructeur, ni faire réapparaître un verbe
écarté. Un rappel qui **lève** est relayé et le menu du socle prend la suite
(AD-10).

C'est ce qui permet de peindre ces menus avec la bibliothèque de menus qu'une
application emploie déjà ailleurs.

### ⚠️ Modifié — le menu d'artefact par défaut est une GRILLE

Trois colonnes, réglables ; **1** retrouve la disposition en colonne rendue
auparavant. Même nombre de colonnes par défaut que l'autre menu du dépôt : deux
défauts différents pour deux menus du même écran seraient un piège. Cibles
≥ 48 dp et ordre déclaré préservés.

### Ajouté — un accent d'état actif pour les bascules du composer

Chaîne `paramètre > jeton > rien`, portée au plancher de contraste des
composants.

🔴 **La teinte s'AJOUTE, elle ne remplace pas.** Le libellé emphasé et l'état
annoncé subsistent : en mode compact, l'état reste **écrit et annoncé**, jamais
porté par la seule couleur (AD-13). Sans déclaration, l'arbre est inchangé.

## 3.4.0 — 2026-08-22

### ⚠️ Modifié — le filet borne le CONTENU, plus les commandes

**Changement de rendu pour tout hôte déclarant une coquille de tuile.** Le filet
englobait la tuile entière : identité, coiffe, contenu **et** la barre d'actions
par message. Il cessait donc de délimiter *la réponse* pour délimiter *la réponse
et ses commandes*.

Le filet borne désormais le **contenu** — identité, coiffe, blocs et bouton de
dépli — et la barre d'actions est rendue **sous** la carte.

Mesuré sur un message court avec une barre de 96 dp : la hauteur du filet passe
de **132 dp à moins de 44 dp**.

Un hôte **sans** coquille déclarée rend un arbre strictement inchangé.

### Ajouté — `topicTrailing`, la place des commandes de la carte

Un créneau rendu **en fin de coiffe**, à la suite du sujet du tour : c'est la
place des commandes qui portent sur la carte elle-même, non des actions parmi
d'autres.

Le sujet occupe la place restante et **tronque** ; le créneau garde sa largeur
entière, une hauteur minimale de 48 dp et une densité de glyphe réduite
(20 dp contre 24 pour une action de message). Directionnel : « fin » se rend à
droite en écriture gauche-à-droite, à gauche en droite-à-gauche.

Strictement additif — sans créneau déclaré, la coiffe est inchangée. Un
constructeur qui **lève** perd le créneau, jamais la coiffe (AD-10).

⚠️ **Un écart délibéré** : un plancher tactile de 48 dp est non négociable
(AD-13). Une coiffe portant un créneau chargé fera donc au moins cette hauteur,
là où un rendu plus compact serait possible en le sacrifiant.

## 3.3.0 — 2026-08-21

### Ajouté — l'animation d'occupation, la table de capacités complète, la coquille de tuile

**Occupation.** Le glyphe d'un artefact en cours de génération s'anime sur la
palette du socle — **par artefact**, jamais globalement. L'animation consomme
`busyPalette`, qui n'avait jusqu'ici **aucun lecteur**. Sous « Réduire les
animations », aucun contrôleur n'est créé et le glyphe se fige sur la première
teinte : l'occupation reste perceptible par la teinte **et** par l'annonce.

Le mécanisme lui-même vit dans `zcrud_core` (`ZColorCycle`) : il ne connaît ni le
chat, ni les artefacts, et sert donc tous les modules.

**Capacités : 5 → 9 entrées** de référence (`summary`, `elaboration`, `examples`,
`poem`), avec leurs clés publiques. Ce sont des **défauts** surchargeables, pas
une liste fermée : une clé inventée par l'hôte reste servie par sa propre
déclaration.

**Coquille de tuile** — `ZChatTileShell`, déclarée par le skin : carte, filet,
coiffe par le sujet du tour (`topic`), style du bouton de dépli (alignement
directionnel, forme, remplissage par rôle de `ColorScheme`), et format
d'horodatage par résolveur d'hôte avec repli défensif.

⚠️ **`null` ⇒ arbre strictement inchangé.** Le rendu de référence est le défaut
**de la référence**, servi quand la coquille est déclarée — jamais le défaut du
paquet : plusieurs applications consomment `zcrud_chat` et aucune n'a demandé ce
rendu.

### Mesuré — le débordement à neuf artefacts : rien à ajouter

La rangée est un `Wrap`, qui répartit déjà neuf cibles sur plusieurs lignes
(6 + 3 sur 360 dp, 5 + 4 sur 320, 4 + 4 + 1 sur 240). Toutes restent à
48 × 48 dp, dans le viewport, disjointes, et répondent au tap — en LTR comme en
RTL. **Aucun mécanisme n'est ajouté** : en ajouter un déplacerait des cibles déjà
atteignables derrière une affordance de plus.

## 3.2.0 — 2026-08-21

### Ajouté — les artefacts d'un message se DÉCLARENT au lieu de se porter

`ZChatArtifactSpec` (clé **opaque**, glyphe, libellé, trois lectures d'état —
présence, compte, occupation — et une liste de verbes) et `ZChatArtifactAction`,
montés par `ZChatNotebookView(artifacts:)`.

Le socle **ne connaît ni `mindmap` ni `flashcards`** : il connaît une clé. Les
identités et le stockage restent à l'hôte.

**Ce qui est rendu** : le glyphe **teinté quand l'artefact existe**, à la couleur
ambiante sinon — *c'est un ÉTAT, pas un style* ; la pastille de compte ; le menu
au tap, ne contenant que les verbes dont la condition tient ; la confirmation
avant un verbe destructeur.

**Ce qui reste exprimable, et qui compte pour la parité** : l'**ordre** des verbes
est celui déclaré, et leur teinte est déclarable **par artefact** — un mécanisme
qui imposerait un ordre unique forcerait un hôte à choisir entre le socle et sa
parité.

**Consommation de l'existant** : `capabilityAccents` avait été livré **sans aucun
consommateur**. La chaîne `spec > skin > jeton > référence` en fait enfin son
premier lecteur, **par clé** — donc une clé inventée par l'hôte est servie aussi.

**Contraste** : la teinte respecte le plancher **même si l'hôte en déclare une qui
ne le respecte pas**. Sans surface mesurable, **aucune teinte n'est peinte**
(repli fermant) — l'état reste porté par l'annonce et la pastille.

Additif strict : sans déclaration, le rendu est identique (contre-témoin à
comptes absolus).

## 3.0.0 — 2026-08-18

### Ajouté — un créneau d'action par groupe de conversations

`ZChatConversationList` groupe les conversations par contenant, mais n'offrait
aucun endroit où poser une action **à l'échelle du groupe**. Le bouton « créer
dans CE dossier » était donc perdu au portage : restait le bouton global, qui ne
présélectionne rien — l'utilisateur devait rattacher après coup, ou découvrir sa
conversation au mauvais endroit.

`groupActionsBuilder` reçoit le **groupe exact** et rend des actions déclarées
par l'hôte. **Le socle ne fabrique aucune action** : la création — quel dossier,
quel titre, quelle persistance — reste métier, comme l'hôte le demandait.

Défaut : **aucune action**, rendu identique au pixel (contre-témoin à comptes
absolus). Un constructeur qui **lève** laisse la liste intacte (AD-10), sans
action de repli. Cible ≥ 48 dp, sémantique de bouton, activation au clavier.

**Non livré, délibérément** : le repli en accordéon, l'icône de groupe colorée et
la troncature du titre — l'hôte les qualifie de cosmétiques et ne les demande pas.

## [0.85.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu, patron
  kernel/satellite, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_chat.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, exemples compilables sur les entités
  principales, invariants d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Purge des références de story et
  d'epic, des emoji de journal et des historiques de correctifs — conservation
  des invariants, cas limites et avertissements de contrat. Aucun changement
  de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_chat/`.
