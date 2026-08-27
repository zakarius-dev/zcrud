# Handoff v3.24.0 — le composer branché sur son moteur

> **Date** : 2026-08-27. **Portée** : `zcrud_core`, `zcrud_chat_kernel`, `zcrud_chat`.
> **Traite** : CR-IFFD-125 (le composer, palier principal) et CR-IFFD-126 (la teinte des artefacts),
> sous le mandat du propriétaire : *« prévoir et offrir toutes les fonctionnalités possibles d'un
> composer de chat avancé »*.

## 1. Le diagnostic, et la correction qu'il a fallu lui apporter

La demande de l'hôte portait un diagnostic juste : **le socle a le moteur, le composer n'a pas le
tableau de bord**. Le contrôleur portait déjà la session d'édition, les suggestions, le brouillon et
les requêtes actives — et rien ne les rendait. C'est pour cela qu'une application consommatrice a
écrit **1 231 lignes** de composer : elle a recâblé à la main un moteur qui existait.

**Mais la mesure a corrigé la demande sur cinq points.** La CR mesurait un seul fichier — le widget
bas niveau — et concluait « le composer ignore tout ». Le composer **assemblé**, livré en v3.6.0,
portait déjà le cadre, le bandeau d'édition, la bascule d'arrêt, la pastille de compte et les paliers
d'effort ; et la taille d'une pièce jointe existait. Sans ce contrôle, nous aurions livré du travail
déjà fait.

Un **contrat** a donc été établi avant tout code (`docs/analyses/composer-avance-2026-08-27.md`) : il
classe chaque manque par **nature** — jeton, créneau, branchement, type de domaine, geste — et c'est
cette classification qui a décidé du découpage en lots.

## 2. Ce que le socle livre

**Neuf rangs déclarés** dans le composer : annonces, propositions, ancre, accessoires. Le contrat
insiste sur un point que le rendu seul ne dit pas — c'est le **rang**, et le fait d'être *dans* le
cadre, qui fait qu'une vignette ajoutée pousse le champ **sans sortir de la boîte**. Créneau non
fourni ⇒ aucun nœud dans l'arbre.

**Le cadre** consomme quatre jetons de thème, à l'emplacement qu'un commentaire du code réservait
depuis une version antérieure, avec la précédence qu'il annonçait : paramètre > jeton > rien.

**Les pièces jointes de bout en bout** : aperçu et progression montés à leur rang, état de
téléversement exposé par un **compteur** (deux transferts simultanés sont nominaux), trois causes de
rejet distinguées, geste de relecture sur une vignette.

**Les suggestions**, agrégées **par conversation** — l'étanchéité est gardée — et **le brouillon**,
délégué au port du noyau : le socle ne persiste rien lui-même.

**Le vocabulaire d'outils** : puce à libellé escamotable et badge, puce à paliers, description et
badge d'option de modèle. La pièce est **offerte, jamais imposée** — le créneau reste libre.

**Le vocabulaire de contexte** dans le noyau : mentions, commandes, port de mesure, port de
brouillon. Et la teinte d'artefact peut désormais dire la **nature** plutôt que l'**existence**.

## 3. Ce que le socle a refusé de faire, et pourquoi

C'est la partie la plus importante de cette version.

- **Il ne résout pas.** Aucune commande exécutée, aucun candidat de mention résolu, aucun filtrage ni
  tri — *filtrer, c'est résoudre*. Un plafond de candidats est **transporté, jamais appliqué**.
- **Il ne compte pas les jetons** : cela dépend du tokenizer. Il **demande** au port ; sans port, la
  mesure est **absente** — jamais zéro, qui serait pris pour une mesure.
- **Il ne devine pas une cause de rejet** : il ne distingue que ce que la plateforme lui **nomme**.
  Notamment, « fichier illisible » n'est pas inféré d'octets vides — indiscernable d'un fichier
  réellement vide.
- **Il n'arbitre pas** ce qu'une suggestion déclenche : la bande n'est montée que si l'hôte le dit.
- **Le mode de disposition demandé a été rejeté sur mesure** : le champ est un éditeur nu, et le
  mécanisme visé — envoi et outils dans la décoration du champ — est inexprimable sans rendre la
  boîte à un décorateur. Nommer « mode » ce qui n'est qu'un alignement aurait été un mensonge d'API.
- **Les bascules existantes n'ont pas été migrées** vers la puce commune : les pixels sont
  identiques, mais les deux familles n'ont pas la même source d'état — migrer aurait imposé de
  **fabriquer** une donnée que la source ne possède pas.

## 4. Ce qui change pour un hôte

- 🔴 **Le bandeau d'édition change de place** chez un hôte utilisant le composer par défaut : de
  juste au-dessus du champ vers le haut du cadre. Qui compensait par une marge ou un séparateur doit
  la **retirer**.
- 🔴 **Hôte ayant compensé le cadre** par sa propre boîte : la retirer **au moment où il pose un
  jeton**, sinon double contour et double rayon.
- **Hôte ayant compensé** par une barre de suggestions maison, ou par une sauvegarde manuelle du
  brouillon au changement de conversation : retirer — la seconde passerait outre la règle « la saisie
  en cours l'emporte ».
- **Hôte ayant compensé** la teinte des artefacts en forçant la présence : remplacer par le drapeau
  de teinte permanente, sinon son annonce continue de mentir.
- **Hôte passif** : rien ne bouge, établi par des gardes d'inertie mesurées **en absolu** — jamais
  par comparaison de deux arbres.

## 5. Vérification

Rejouée par l'orchestrateur, tous les lots au repos.

| Paquet | Tests |
|---|---|
| `zcrud_core` | **2 575** |
| `zcrud_chat` | **967** |
| `zcrud_chat_kernel` | **721** |

`melos run generate` : 0 `.g.dart` · `analyze` repo-wide : RC=0 · `verify` (12 gates) : RC=0 ·
balayage des **41 paquets** : **40 verts** (`zcrud_generator` rouge **environnemental** de signature inchangée) · résidus d'injection R3 : **0**.

**Discipline R3** : environ 110 injections sur les sept lots, toutes rouges **par assertion**.

## 6. Ce que la discipline a réellement attrapé cette semaine

- **Six gardes faibles démasquées**, en trois familles : la garde **relative** (deux arbres que
  l'injection affecte tous les deux), la garde **mal ancrée** (bonne propriété, mauvais nœud — lire
  48 dp sur un texte de 20 dp, arrivé deux fois), la garde **hors d'atteinte** (sujet piloté par un
  objet que la production ne détient pas, donc qu'aucune injection ne peut faire rougir).
- **L'une d'elles a révélé un vrai défaut d'accessibilité** : une annotation qui fusionnait dans le
  nœud parent au lieu de former un nœud de bouton — un lecteur d'écran ne l'aurait pas annoncé.
- **Un lot a détruit le travail d'un lot antérieur** en restaurant une injection par `git checkout`
  dans un arbre à lots non commités : la commande ne restaure pas l'état d'avant l'injection, elle
  ramène au dernier tag. Le fichier a été réparé par copie, et **l'identité à l'octet a pu être
  prouvée** parce que les deux lots précédents avaient publié son empreinte. La règle est désormais
  explicite : restauration **par copie exclusivement**, et publication du sha256 de chaque fichier
  modifié en fin de lot.

## 7. Le critère d'acceptation, et où il en est

La demande fixait un critère mesurable : que les **1 231 lignes** du composer d'une application
consommatrice deviennent supprimables au profit d'un montage du composer du socle, **sans perte**.
Le contrat estimait que trois lots — les rangs, le cadre, les pièces jointes — y suffisaient pour
l'essentiel ; les sept livrés ici vont au-delà.

**Ce palier ne clôt pas la demande** : restent les gestes d'entrée (coller une image, glisser-déposer
un fichier), le panneau de candidats pour les mentions et les commandes, la boucle vocale continue,
et le relais des créneaux par l'écran assemblé. Ils sont décrits, dimensionnés et ordonnés dans le
contrat. Tant que le diff de suppression n'est pas fait chez le consommateur, la demande reste
ouverte — et c'est à lui de le mesurer, pas à nous de le déclarer.
