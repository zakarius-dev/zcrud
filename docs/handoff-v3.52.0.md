# Handoff v3.52.0 — un QCM ne montre plus ses choix deux fois

Origine : à l'adoption de v3.51.0, une application a mesuré à l'écran ce qu'aucune séance
précédente n'avait montré — toutes étaient des questions ouvertes. Sur un **QCM**, la
session assemblée rend les choix **deux fois** : dans la carte, sous l'énoncé, en radios
non interactives (c'est l'usage de la carte **seule**, en consultation), et dans la
surface de saisie, en tuiles interactives. L'utilisateur lit deux listes identiques, dont
une qui ne répond pas au tap.

## Clés de schéma ajoutées

**Aucune.** Aucune entité persistée n'est touchée ; aucune migration n'est requise.

## Constats vérifiés sur disque avant tout travail

| # | Constat de l'hôte | Vérification | Verdict |
|---|---|---|---|
| 1 | La face question d'un QCM rend les choix, non interactifs, sans réglage pour l'éteindre | `z_flashcard_review_card.dart:602` (`_choices(context, marked: false)`), `grep showChoices\|questionFaceChoices` ⇒ 0 | réel |
| 2 | Le host monte cette carte **et** la surface de saisie, qui rend les mêmes choix | `z_study_session_host.dart:1345` et `:1521` | réel |
| 3 | Depuis le correctif de la pile, la bande de débord laisse voir le **texte** de la carte suivante ; la référence montre des bords vides | le host connaît `isFront` par slot (`:1393`, `:1408`) : une carte arrière peut être rendue à face vide sans toucher la pile | réel, traité |

Sur le point 1, l'hôte demande que **le host pose `hidden` lui-même** dès qu'il monte une
saisie interactive, et il a raison : ce n'est pas un choix de design, c'est le retrait d'un
doublon que seul l'assemblage crée. La carte **seule** garde ses choix — c'est son usage en
consultation.

## Deux réglages d'instance sur la carte de révision

`ZFlashcardReviewCard` gagne deux réglages, **non nullables**, à défaut égal au rendu
d'aujourd'hui :

- **`questionFaceChoices`** (`shown` \| `hidden`) — `hidden` : la face question rend
  l'**énoncé seul** ; la face réponse est **strictement inchangée** (ses choix marqués
  sont la correction). Inerte hors QCM, prouvé sur une question ouverte et un vrai/faux.
- **`faceContent`** (`full` \| `blank`) — `blank` : la carte rend son **chrome** — fond,
  rayon, ombre, liseré et son dégradé — **sans aucun contenu** : ni énoncé, ni choix, ni
  badge, ni consigne, ni rangée d'actions. C'est ce qui permet à une carte de rang > 0 dans
  une pile de montrer des bords vides.

Ce sont des réglages d'**instance**, pas des jetons de thème — et c'est mesuré : la même
application rend la carte **seule** avec ses choix (consultation) et **en session** sans, et
empile des cartes dont seule celle de devant porte du contenu. Un jeton, global, ne peut pas
exprimer cela ; la place de l'instance le peut.

**Une face vide est vraiment muette.** Un constat de conception s'est révélé faux à la
mesure : les cartes arrière de la pile ne sont **pas** non interactives par construction —
le paquet de pile les monte sans `IgnorePointer` ni `ExcludeSemantics`, et seule la carte de
devant porte un détecteur de geste, sur son propre rect. La bande de débord en est hors. Le
mode `blank` retire donc lui-même le geste (aucun `InkWell`, un tap ne notifie jamais la
révélation) et la sémantique (le nœud « Afficher la réponse » n'est pas construit), sans
toucher à l'état de révélation.

- **Application passive** : rien ne change — les défauts sont le rendu d'aujourd'hui, arbre
  identique à l'octet sur quatre scènes.
- **Application qui remplaçait la carte par `cardBuilder`** pour masquer les choix en QCM :
  elle peut retirer ce remplacement — et récupère révélation, liseré, badge, consigne et
  ombre que `cardBuilder` emportait. Le test qui doit rougir : « mon `cardBuilder` est appelé ».

## L'assemblage retire lui-même le doublon

`ZStudySessionHost` pose désormais `hidden` sur la carte **dès qu'il monte sa propre
surface de saisie** — c'est-à-dire toujours, sauf si vous fournissez `gradingBuilder`
(votre saisie, vos choix : la carte garde les siens). La règle est écrite et gardée : *la
carte ne rend pas ses choix quand la saisie du host les rend.* Elle vaut pour les six modes
de session — la surface de saisie monte les choix d'un QCM sans aucun aiguillage sur le mode.

Et il vide les cartes de rang > 0 de la pile : la bande de débord montre des **bords
vides**, comme la référence, au lieu du texte de la carte suivante. Le basculement
`blank → full` quand une carte passe devant est gardé par le **geste réel** de la pile.

**Échappatoires**, nullables (`null` = décision de l'assemblage) : `questionFaceChoices`
et `backCardsContent` sur le host et le scaffold, à plat comme en `.wired`. Classés
cosmétiques. **Pas dans le preset**, et c'est justifié : un preset décrit une identité
partagée entre écrans ; ces décisions dépendent de ce que *cet* écran monte à côté de la
carte.

⚠️ **Deux ruptures visibles pour une application passive** — c'est le retrait d'un doublon
et d'un débord, pas un choix de design, mais elles se voient :
- en QCM assemblé, les **choix quittent la carte** ; ils restent dans la saisie, interactifs ;
- les **cartes arrière perdent leur contenu** ; leur chrome — fond, rayon, ombre, liseré —
  reste.
Pour retrouver l'ancien rendu : `questionFaceChoices: ZFlashcardQuestionFaceChoices.shown`
et `backCardsContent: ZFlashcardFaceContent.full` sur l'écran.

**Un défaut trouvé en chemin, et corrigé.** Le cache de la pile, indexé par rang et
position, **n'invalide pas sur changement de mode** : une carte de devant montée en
`spaced` survivait au passage en `learn` ; son contrôleur de révélation, créé mais jamais
consommé, faisait **lever** le socle à la destruction. Une garde existante l'a attrapé. La
carte de devant reçoit désormais son contrôleur sans condition de mode.

- **Application ayant compensé** le doublon par un `cardBuilder` : retirez-le, il
  s'additionne — et privait la carte du contrôleur de révélation. Le test qui doit rougir
  chez vous : « mon `cardBuilder` est appelé ».

## Si vous n'adoptez rien

Une application **passive** voit **deux changements**, tous deux correctifs : en QCM
assemblé, les choix ne sont plus rendus sur la carte (ils le sont dans la saisie, où ils
répondent au tap) ; les cartes arrière d'une pile ne montrent plus leur texte dans la
bande de débord. Tout le reste — questions ouvertes, vrai/faux, carte seule hors session,
carte fournie par `cardBuilder` — est identique à l'octet.

Une application qui **compensait** le doublon ou le débord doit retirer sa compensation :
elle s'additionne au comportement natif.

## Les tripwires à écrire chez vous

| Vous compensiez… | Le test qui doit rougir |
|---|---|
| un `cardBuilder` fourni pour masquer les choix en QCM | « mon `cardBuilder` est appelé » |
| un masquage des cartes arrière (opacité, `Visibility`) | « ma couche de masquage est montée » |
| un `gradingBuilder` fourni pour être seul à rendre les choix | « les choix ne sont rendus qu'une fois » — désormais vrai **sans** lui ; le test reste vert, mais votre `gradingBuilder` prive la carte de `hidden` automatique : elle garde ses choix, à dessein |

## Vérification, rejouée au repos

- `melos run generate` → RC=0, **0 fichier généré modifié** ;
- `melos run analyze` **repo-wide** → RC=0 ;
- `melos run verify` (gates, dont `web`, `reserved-keys`, graphe acyclique et recette de
  consommation) → RC=0 ;
- balayage des **42 paquets**, `flutter test --no-pub -j 4` lancé **depuis le dossier de
  chaque paquet** → **41 verts**. `zcrud_generator` est rouge pour une raison
  d'environnement, qualifiée et non imputable au code : son `lib` et son `test` sont
  **identiques à l'octet** à la version précédente ;
- comptes mesurés à la clôture des lots : `zcrud_flashcard` 685, `zcrud_study` 2366 ;
- aucun résidu d'injection R3, aucun `if (false` en production.

Vingt-trois injections R3, toutes rouges par assertion ; aucune garde verte sous injection.
Un constat de conception de l'orchestrateur — « les cartes arrière ne sont pas interactives
par construction » — a été **démenti à la mesure** par l'agent chargé de s'y appuyer, qui a
corrigé en conséquence plutôt que de livrer sur une prémisse fausse.
