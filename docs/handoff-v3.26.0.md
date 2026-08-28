# Handoff v3.26.0 — un retrait honnête, les droits ouverts, le geste unique

> **Date** : 2026-08-28. **Portée** : `zcrud_core`, `zcrud_chat_kernel`, `zcrud_chat`.
> **Traite** : le retrait demandé après CR-IFFD-126, CR-IFFD-123 (aussi CORE-1 de notre relevé)
> et CR-IFFD-124.

## 1. Un canal retiré parce que son besoin n'existait pas

Le drapeau de teinte permanente d'artefact, livré deux versions plus tôt, est **retiré** — sur
signalement de l'hôte lui-même : l'observation qui le demandait était fausse. L'absence de
**pastille** avait été prise pour l'absence d'**artefact**, alors que le compte n'est porté que par
certains artefacts ; les glyphes non peints correspondaient à des artefacts qui n'existaient pas
encore. La règle d'origine — **la teinte dit l'état, et rien d'autre** — était juste depuis le
début, et correspond au legacy.

Le retrait suit la règle du dépôt : *jamais une option déclarée sans consommateur*. Deux précautions
l'accompagnent : la clé de sérialisation reste **filtrée** (un document écrit par une version qui la
posait ne la fait pas resurgir dans `extra`), et la règle restaurée est **gardée par un tripwire**
prouvé mordant — la leçon de l'épisode étant qu'une règle confirmée juste mérite une garde qui la
fige.

La leçon de méthode, énoncée par l'hôte et que nous reprenons à notre compte : *une capture n'est
pas une mesure — avant d'affirmer qu'un rendu contredit une règle, vérifier l'état des données qui
le produit.* Notre vérification sur disque avait prouvé que le mécanisme était bien celui décrit ;
elle ne pouvait pas prouver que son effet était un défaut.

## 2. Le vocabulaire des actions s'ouvre (CR-123 / CORE-1)

L'enum des actions était fermé à onze valeurs ; l'hôte en gouverne dix-sept, dont **six droits
d'IA** exercés par vingt-trois sites — chez lui, générer avec l'IA **est** un droit, gouverné par la
même matrice que « modifier ». Et la correspondance n'était pas un sur-ensemble : un
**recouvrement partiel**, signe qu'un enum fermé ne peut pas être le bon contrat.

**Les deux voies proposées par la demande étaient inapplicables telles quelles** — une valeur
paramétrée est impossible sur un enum, et toute méthode ajoutée au port casserait chaque hôte qui
l'implémente. La forme livrée : l'enum **intact**, une clé opaque dont les douze constantes
canoniques sont **indexées depuis l'enum lui-même** (aucune table parallèle à désynchroniser), un
port **opt-in** pour les clés libres, et `move` ajouté à l'enum.

🔴 **Le fail-closed est préservé, et prouvé dans son cas le plus contre-intuitif** : une clé libre
soumise à une ACL restée fermée est **refusée** — même si cette ACL est permissive sur l'enum. Le
refus vient du routage, pas de la bonne volonté de l'ACL. Aucune matrice écrite avant cette version
ne peut accorder un droit qu'elle ne connaît pas.

Le socle transporte des clés **opaques** : aucune clé d'hôte n'y figure (grep négatif montré), et il
n'apprend pas ce que « expliquer avec l'IA » veut dire.

## 3. La grille unique et le geste unique (CR-124)

Le créneau hôte de la rangée d'artefacts ne connaissait qu'une position : au-dessus. Il devient
**déclarable** — au-dessus (défaut inchangé), en dessous, ou **dans la même grille**, soumis alors
au même repli responsive que les artefacts.

Et le **geste d'un artefact à verbe unique devient réglable PAR ITEM**, sur décision du
propriétaire prise avant le tag : `menu` (défaut — le menu à option unique, comportement historique
strictement inchangé), `direct` (exécution au clic), ou `confirm` (exécution précédée d'un dialogue
de confirmation au message personnalisable). Le premier jet du lot faisait du clic direct une règle
globale ; le propriétaire l'a refusée comme défaut — « dans la plupart des cas, on n'est pas prêt à
lancer la génération au clic » — et la correction est passée **avant publication**, la seule fenêtre
où changer un défaut ne coûte rien. Le mode `confirm` passe par le **portail de confirmation
existant**, jamais un second dialogue, et **jamais deux questions** : un destructeur est routé vers
sa question destructrice. Les specs-verbes de l'hôte déclarent `direct` : exécution immédiate.

## 4. Ce qui change pour un hôte

- **Le geste par défaut ne change PAS** : un artefact à verbe unique sans mode déclaré garde son
  menu à option unique. `direct` et `confirm` sont des opt-in **par item** — un hôte mélange
  librement les trois modes dans la même grille.
- **Hôte qui posait ses verbes ailleurs** faute de grille (la compensation actuelle de l'émetteur) :
  il déclare ses verbes en specs-commandes, les place dans la grille, et **retire sa compensation**.
- **Hôte à matrice de droits parallèle** : il la retire en passant son ACL au port à clés. Un
  `switch` exhaustif sur l'enum doit ajouter `move`.
- 🔴 **Une clé libre sur une ACL restée fermée est refusée, jamais ouverte par défaut.** Un hôte qui
  s'en étonne passe son ACL au port à clés — il ne cherche pas de contournement.
- **Hôte qui posait le drapeau de teinte retiré** : aucun ne le pose (vérifié par l'émetteur de la
  demande initiale). Un document persisté par v3.24/v3.25 reste lisible, la clé étant filtrée.

## 5. Vérification

Rejouée par l'orchestrateur, lots au repos.

| Paquet | Tests |
|---|---|
| `zcrud_core` | **2 586** (2 575 + 11) |
| `zcrud_chat` | **1 045** (1 027 + 18) |
| `zcrud_chat_kernel` | **717** (715 + 2) |

`melos run generate` : 0 `.g.dart` · `analyze` repo-wide : RC=0 · `verify` (12 gates) : RC=0 ·
balayage des **41 paquets** : **40 verts** (`zcrud_generator` rouge **environnemental** de signature inchangée) · résidus d'injection R3 : **0**.

**Discipline R3** : 4 + 5 + 8 + 1 injections (droits, position/geste, modes d'activation, tripwire de teinte), toutes rouges
par assertion, restaurations par copie, sha256 identiques. Le premier rejeu de CR-124 a rendu
**13 rouges** : douze gardes mesuraient l'ancien menu-à-un-élément et ont été **ré-ancrées propriété
conservée**, puis reprouvées mordantes par réinjection — jamais affaiblies.
