# Handoff v3.47.0 — la session d'étude atteint le niveau fonctionnel attendu par l'hôte

Origine : six demandes déposées par l'application IFFD après le portage de sa page de
session de révision sur `ZStudySessionHost`, chacune **mesurée** — à l'appareil pour
les surfaces, en base Firestore pour la note écrite. Les six constats ont été
**vérifiés sur disque** avant tout travail : aucun n'était périmé.

## Table des écarts

| # | Écart | Verdict | Paquet |
|---|---|---|---|
| 1 | En mode `learn`, la réponse est inatteignable | **livré** ⚠️ `learn` : un tour = deux gestes | `zcrud_study` |
| 2 | Le constructeur de carte ne dit pas laquelle est devant | **livré** | `zcrud_session` |
| 3 | Question rendue deux fois sur écran étroit | **livré** ⚠️ rendu par défaut modifié | `zcrud_study` |
| 4 | `minQuality: 0` écrit une note hors de l'échelle de l'hôte | **documenté, contrat inchangé** | `zcrud_flashcard` |
| 5 | Le port d'indices laisse croire qu'un hôte sans port perd les indices | **livré** | `zcrud_flashcard` |
| 6 | Zones tactiles sous la barre de navigation système | **livré** (session) / _en cours_ (étude) | `zcrud_session`, `zcrud_study` |

## Clés de schéma ajoutées

**Aucune.** Aucune entité persistée n'est touchée par cette version ; aucune
migration n'est requise, et aucun document existant ne change de forme.

## Écart 2 — le constructeur de carte sait désormais laquelle est devant

La pile rend plusieurs cartes à la fois. `ZSessionCardBuilder` ne recevait que
`(BuildContext, ZSessionItem)` : un contrôle composé par une application — un bouton
« voir la réponse », un chronomètre — était rendu **autant de fois qu'il y a de
cartes visibles**, sans que rien ne le signale.

Livré, de façon **additive** : `ZSessionCardSlot {item, index, isFront}` et un second
slot de construction qui le reçoit. L'ancien constructeur est **inchangé** et reste
prioritairement servi quand il est seul.

- **Application passive** : rien à faire, arbre identique.
- **Application ayant compensé** : celle qui possédait un contrôleur d'index pour
  comparer le rang de la carte et ne pas dédoubler son contrôle **doit retirer cette
  compensation** et lire `slot.isFront`. Le moyen de le vérifier soi-même : la garde
  locale qui affirmait « le contrôle n'est rendu qu'une fois » reste **verte** après
  retrait — si elle rougit, la compensation portait autre chose et doit rester.

## Écart 5 — ce qu'un hôte sans port d'indices conserve

Le contrat était respecté ; sa documentation ne disait pas ce qu'on **garde** sans
port. Elle le dit maintenant, au contrat comme au point d'appel : sans implémentation,
l'indice **stocké** sur la carte reste servi ; seule la **génération** des indices
suivants est perdue. Aucun changement de code.

## Écart 4 — pourquoi le socle ne peut pas refuser cette note, et ce que l'hôte doit faire

La demande était : « `ZSrsConfig` est propriétaire de l'échelle — n'est-ce pas au socle
de refuser une note hors de l'échelle qu'il a reçue ? »

**Il ne le peut pas, et une assertion serait fausse.** `ZSrsConfig(minQuality: 0)` *est*
l'échelle déclarée par l'application : du point de vue du socle, `0` est une note
parfaitement légale. Ce que le socle ignore, c'est que l'échelle **persistée** de
l'application, elle, commence à `1`. Une assertion `minQuality >= 1` serait arbitraire
et casserait toute application restée au défaut.

Ce qui est livré à la place : le champ documente désormais qu'il n'est pas seulement
une borne de clamp mais **une note réellement écrite** — celle que le geste « je ne sais
pas » pose sur la répétition — et porte la consigne explicite : **déclarez
`minQuality: 1` si votre échelle persistée n'a pas de `0`.**

⚠️ **Et ce passage n'est pas gratuit** — point que la demande supposait neutre :
`interval` et `repetitions` sont bien inchangés (les deux valeurs sont sous le seuil de
réussite, même branche de lapse), **mais le facteur de facilité diffère**. La formule
SM-2 est en `(5 − q)` : `−0,80` pour `0` contre `−0,54` pour `1`. L'écart se reporte sur
**toutes les échéances ultérieures** de la carte. C'est un arbitrage de produit.

- **Application passive** : aucun changement de comportement.
- **Application dont l'échelle commence à 1** : poser `minQuality: 1`. Les gardes qui
  **gèlent délibérément** l'écart d'échelle (« on borne sur ce que SM-2 accepte, pas sur
  ce que l'interface offre ») sont des décisions, **pas** des compensations : les
  retirer n'est pas demandé. Le moyen de vérifier : ces gardes rougissent au passage —
  c'est le signal de l'arbitrage à trancher, pas d'un défaut.

## Écart 6 — l'inset du bas, et la gouttière double que personne n'avait vue

Les surfaces basses d'une session — la saisie de réponse et la rangée des cinq
paliers — ne réservaient pas l'inset système : en portrait, leurs commandes tombaient
sous la barre de navigation.

Livré : un paramètre `bottomInset` (`double?`) sur `ZFlashcardAnswerInput` et
`ZSrsQualityButtons`.

- `null` (défaut) : l'inset système du bas. Il vaut **déjà zéro** sous un `SafeArea`
  ancêtre, qui l'a consommé — aucune seconde gouttière ne peut donc apparaître ;
- une valeur explicite : celle-là, pour une application qui gouverne son propre inset ;
  `0` retire toute réserve ;
- **aucune réserve n'est rendue** quand la valeur effective est nulle : l'arbre est alors
  exactement celui d'avant l'existence du paramètre.

⚠️ **Ce que la mesure a révélé au-delà de la demande** : les deux surfaces empilées
réservaient **chacune** l'inset, soit **96 dp au lieu de 48**. La surface de saisie
consomme désormais l'inset pour son sous-arbre, comme le ferait un `SafeArea`. La garde
qui affirmait « une seule fois » était **verte avant la livraison, pour la mauvaise
raison** — seule une seule des deux surfaces réservait quoi que ce soit ; seule
l'injection de la régression l'a qualifiée.

- **Application passive** : rien à faire.
- **Application ayant CONTOURNÉ** par un `Padding` maison calé sur
  `MediaQuery.padding.bottom` autour de ces surfaces : **retirez-le** — il s'ajoute
  désormais à la réserve native et rend 96 dp. Le moyen de le vérifier soi-même : le
  test local qui affirmait la perte (« le dernier contrôle touche le bas », ou la
  hauteur exacte de la surface) doit maintenant **rougir**. S'il reste vert, la
  compensation est encore en place.
- Un `SafeArea` d'application reste **sans effet cumulatif** : à garder.
- Une application qui **DÉCIDE** un inset propre le conserve — mais le déclare
  par `bottomInset:` plutôt que par une gouttière externe.

## Écart 3 — le rappel de question s'abrège sur écran étroit

⚠️ **C'est la seule rupture visible de cette version. Lisez-la même si vous n'avez
rien demandé.**

Le contenu d'une question était rendu **deux fois** : une fois sur la carte, une fois
en rappel au-dessus de la surface de saisie. Sur un large écran, ce rappel est utile.
Sur un téléphone en portrait, avec une question longue, les deux occupaient l'écran
entier et les commandes passaient sous la ligne de flottaison.

Livré : un réglage `questionRecall` — `auto` (défaut), `full`, `compact`, `hidden`.

**Changement de rendu par défaut** : sous **600 dp de large**, le rappel devient abrégé
(hauteur plafonnée, dégradé de coupure). Au-dessus, rien ne change. Aucune donnée, aucun
contrat, aucune clé de schéma n'est touchée : c'est un changement de mise en page.

- **Échappatoire exacte**, si vous voulez le rendu d'avant sur toutes les largeurs :
  `questionRecall: ZStudySessionQuestionRecall.full`.
- **Application ayant compensé** en masquant elle-même son rappel sur écran étroit :
  votre masquage **s'ajoute** au nôtre — le rappel disparaîtra entièrement au lieu de
  s'abréger. Retirez-le, ou déclarez `hidden` pour l'assumer. Le moyen de le vérifier
  soi-même : votre test affirmant « le rappel est absent en portrait » reste vert dans
  les deux cas — c'est donc **la hauteur rendue** qu'il faut mesurer, pas l'absence.

## Écart 1 — atteindre la réponse en mode `learn`

⚠️ **Deuxième rupture de cette version, limitée au mode `learn`.** Les modes notés
(`spaced`, `list`, `test`, `whiteExam`, `cramming`) sont **inchangés au widget près**.

Une précision de fait, d'abord : la réponse n'était pas *inatteignable* au sens strict —
`ZFlashcardReviewCard` porte déjà un dévoilement au toucher. Ce qui manquait, c'est une
**affordance nommée** et, surtout, le fait que la carte s'en aille avant qu'on ait pu
lire quoi que ce soit.

Deux choses sont livrées.

**1. Une affordance de révélation portée par la session elle-même.** Réglage
`revealPolicy` (`auto` — mode `learn` seul —, `always`, `never`), libellés
`ZStudySessionLabels.revealAction` / `.hideAction`, placement par
`ZStudySessionReference.revealActionPadding`, cible ≥ 48 dp. Elle se referme quand la
carte de devant change — sans quoi l'apprenant verrait la réponse **avant** la question.

**2. Une retenue après la soumission.** Réglage `postSubmitPolicy` (`auto` ⇒ `learn`
seul), plus une action « Continuer ». En `learn`, un tour demande donc désormais
**deux gestes** : répondre, puis continuer. C'est ce qui rend la réponse lisible.

🔒 **La voie d'écriture SRS est intacte** (AD-9/AD-33) : la note part au même endroit, au
même moment, avec la même valeur — une seule écriture, vérifiée par compteur avant toute
continuation. Seul change le moment où la carte s'en va.

- **Échappatoire** pour retrouver l'avance immédiate : `postSubmitPolicy: advance`.
- **Application passive en modes notés** : strictement rien à faire.

### Composer sa propre carte sans rien réimplémenter

Une application qui fournit son propre constructeur de carte ne voyait **aucune** de ces
affordances : elle devait les refabriquer. Nouveau créneau `cardSlotBuilder`, qui lui
remet ce qu'elle devait posséder : `isFront`, l'état `revealed`, et la commande
`toggleReveal`. Strictement additif — l'ancien constructeur reste inchangé et supporté ;
quand le créneau est fourni, l'affordance native s'efface pour ne pas doubler la sienne.

**Ce qui CONTOURNAIT le défaut, et se retire** :
- le contrôleur (ou booléen) de révélation et le `setState` qui le portait ;
- le contrôleur d'index, ou tout calcul maison de « quelle carte est devant », s'il ne
  servait qu'à cela ;
- le bouton « voir la réponse » — sauf si vous préférez garder le vôtre, auquel cas
  câblez-le sur `slot.toggleReveal` ;
- toute compensation de l'avance immédiate en `learn` (délai, écran de correction
  intercalaire, blocage de la soumission) : elle **s'additionnerait** à la retenue
  native. La retirer, ou l'assumer par `postSubmitPolicy: advance`.

**Ce qui DÉCIDE, et se garde** : votre carte composée — badge de type, bandeau de
consigne, mise en page propre. Elle passe simplement de `cardBuilder` à
`cardSlotBuilder`.

**Comment le vérifier vous-même** : votre tripwire sur la révélation — celui qui affirme
que le socle n'offre aucun bouton, ou que la carte notée disparaît immédiatement en
`learn` — doit **rougir** après la montée de version. Tant qu'il reste vert, la migration
n'a pas eu lieu et votre compensation est encore en place.

## Vérification, rejouée au repos

- `melos run generate` → RC=0, **0 fichier généré modifié** ;
- `melos run analyze` **repo-wide** → RC=0 ;
- `melos run verify` (12 gates, dont `web`, `reserved-keys`, graphe acyclique et
  recette de consommation) → RC=0 ;
- balayage des **41 paquets**, `flutter test --no-pub` lancé **depuis le dossier de
  chaque paquet** → **40 verts**. `zcrud_generator` est rouge pour une raison
  d'environnement, qualifiée et non imputable au code (`Unsupported operation:
  Isolate.packageConfig` via `build_test`, 75 occurrences) ;
- aucun résidu d'injection R3 (`grep -rn "ZR3-"` ⇒ RC=1), aucun `if (false` en
  production.

Les gardes ajoutées par cette version l'ont été sous discipline R3 : rouge **par
assertion**, restauration **par copie de fichier**, sha256 publiés avant/après, résidus
prouvés par grep négatif. Onze injections sur le seul lot de session d'étude, dont
**cinq gardes vertes au premier passage** — toutes reformulées sur la propriété réelle
plutôt que déclarées solides. Une garde verte sous injection ne mesure pas ce qu'on
croit ; c'est le troisième cas de la semaine.

## Si vous n'adoptez rien

Une application **passive** — qui ne pose aucun des nouveaux réglages et n'utilise pas
le mode `learn` — ne voit aucun changement, sauf sur écran étroit où le rappel de
question s'abrège (écart 3, échappatoire `questionRecall: full`).

Une application qui **compensait** l'un des défauts corrigés doit retirer sa
compensation : elle **s'additionne** désormais au comportement natif. Les sections
ci-dessus disent, pour chaque écart, quoi retirer, quoi garder, et quel test doit
rougir chez vous pour que vous le vérifiiez vous-même plutôt que de nous croire sur
parole.
