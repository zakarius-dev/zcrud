# Handoff **v0.45.0** — CR-IFFD-54 + CR-IFFD-56 : les gestes s'ouvrent, les cartes reprennent le dessin legacy

> **Tag à épingler : `v0.45.0`** · aucune rupture d'API.
> 🔴 **CR-56 change le DESSIN PAR DÉFAUT** des trois cartes document/note/mindmap — c'est
> la demande, assumée telle quelle (« un défaut se juge à ce qu'il donne sans aucun réglage »).
> L'ancien rendu v0.43.0 reste atteignable par réglage, restitution **exacte** gardée par test.
> CR-IFFD-55 : absorbée par CR-56 — ses deux demandes (`formatColors`, hiérarchie) sont livrées ici.

---

# Partie A — CR-IFFD-54 : deux gestes réglables

| # | Livré | Où | Défaut |
|---|---|---|---|
| ① | `collapseOnHeaderTap: bool` | **spec** | `false` — chevron seul, actuel |
| ② | `ZStudyReorderHandleMode { visible, hiddenLongPress }` | **spec** | `visible` — actuel |

**Pourquoi la spec et non le thème** : la validité de chaque geste dépend du **contenu** que
seule la spec connaît — actions injectées dans l'en-tête pour ①, `onCardLongPress` pour ②.
C'est ce qui permet le refus à la construction.

**① La priorité tactile, mesurée** (LTR + RTL + `inHeaderRow`) : titre / badge / espace ⇒
bascule ; `secondaryAction` (icône ET libellé), `addAction` ⇒ leur action, **jamais** de
bascule ; chevron ⇒ **une** bascule exactement. Sémantique : la ligne est **exclue**
(`excludeFromSemantics`) — l'annonce reste portée par le seul chevron, jamais deux annonces.
SM-1 tenu : 4 bascules par la ligne ⇒ **0** `itemBuilder` ré-invoqué (sections voisine ET propre).

**② Le conflit d'appui long, mesuré et non supposé** : l'`InkWell` d'une carte qui consomme
`onCardLongPress` **gagne l'arène** contre le drag (grille ET liste) — le glisser ne démarre
jamais depuis l'item. ⇒ sur les voies typées, `hiddenLongPress` + `onReorder` +
`onCardLongPress` est **refusé à la construction** (assert ; release AD-10 : repli `visible`).
Le mode masqué **conserve la sémantique, prouvé** : les actions `moveBefore`/`moveAfter`
**réordonnent réellement** via `performAction`, et l'appui long déplace **la carte saisie**
(drag réel, géométrie avant/après). Un renderer de grille **injecté par l'hôte** reste sous
sa responsabilité — documenté sur l'enum, pas simulé.

# Partie B — CR-IFFD-56 : le dessin par défaut EST la référence legacy

**Directive du propriétaire, appliquée à la lettre** : *tous les réglages prévus et
surchargeables (thème et paramètres), avec les valeurs de l'ancien IFFD comme défauts.*

## 1. Ce que rendent désormais les trois cartes SANS AUCUN réglage

La structure `ZStudyToolsItemCard`, avec : tuile d'icône **neutre** 48 dp (`surface`,
rayon 12), **glyphe 28 dp**, titre `titleMedium`/w600/15 une ligne, sous-titre
`bodySmall`/`onSurfaceVariant`, rayon de carte 16, padding 12, marge 4, liseré
`outlineVariant` à 50 %. Document : glyphe **teinté par le format** + **badge d'extension**
au coin du glyphe (fond = couleur du format, texte apparié, rayon 4, fonte 8 bold).
Note / mindmap : glyphe neutre (`note_outlined` / `hub_outlined`) ; extrait, balises et
compteur de nœuds deviennent des **options** (absents de l'arbre par défaut, AD-4).

🔴 **Vérifié contre votre code legacy, pas contre votre CR.** Votre CR disait « badge en
surimpression bas-droite » ; votre legacy (`_buildGridItemCard` + `_iconeDocumentLegacy`)
dit plus précis : badge épinglé au coin du **glyphe de 28 centré** — donc **dans** la tuile,
à 10 dp du bord — fonte **8 bold**, padding 4/2. Quatre micro-divergences ont été trouvées
par cette confrontation (taille de glyphe 24→28, ancrage débordant→coin du glyphe, padding
vertical 1→2, fonte 11→8) et **corrigées, chacune verrouillée par une garde vue rouge**.
La couleur du texte du badge reste un **rôle apparié** (votre `Colors.white` legacy en dur
n'entre pas dans un paquet — FR-26 ; sur vos couleurs saturées, le rendu est identique).

## 2. Tout est surchargeable — priorité paramètre > jeton > référence

11 jetons `ZcrudTheme` (`studyCardHierarchy`, `studyCardRadius`, `studyCardContentPadding`,
`studyCardMargin`, `studyCardIconTileSize`, `studyCardIconTileRadius`, `studyCardTitleStyle`,
`studyCardSubtitleStyle`, `studyCardBorderSide`, `studyCardBadgeRadius`,
`studyCardGlyphSize`) + les paramètres ponctuels des cartes. Les valeurs de référence vivent
en **un point d'audit unique** (`ZStudyCardReference`) — pas de constantes éparpillées.
Leçon CR-LEX-73 : la marge du `CardTheme` de l'hôte reste atteignable (elle s'intercale
entre le jeton et la référence).

**`formatColors`** (héritage CR-55) : symétrique de `formatIcons` — votre convention
« PDF rouge, tableur vert » s'exprime enfin ; sans elle, le tirage de palette stable
demeure. **Hiérarchie** : `ZStudyCardHierarchy { tintedGlyph (défaut = référence),
tintedTile (le rendu v0.43.0) }`.

## 3. Le slot `progress` (votre « non mesuré » n°2)

Il existait sur la carte de base et n'était **pas relayé** par les trois cartes — motif
CR-LEX-78 exactement. **Relayé** ; votre repli par item n'est plus nécessaire.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **vous, IFFD** | adoptez les trois cartes ; **supprimez `_iconeDocumentLegacy`** et le retour au wrapper des trois sections ; posez `formatColors` avec vos couleurs par format ; câblez `collapseOnHeaderTap: true` et `hiddenLongPress` là où vos cartes n'ont pas d'appui long propre |
| **hôte passif ayant adopté les cartes v0.43.0** | 🔴 **le dessin par défaut change** — posez `studyCardHierarchy: ZStudyCardHierarchy.tintedTile` (une ligne de thème) pour retrouver l'ancien rendu **à l'identique** (restitution exacte gardée par test aux valeurs pompées de v0.43.0) |
| **hôte passif n'ayant pas adopté** | rien — `itemBuilder` requis inchangé, ces cartes ne s'invitent nulle part |
| 🔴 **hôte ayant compensé** | si vous recopiiez le glyphe teinté + badge (l'équivalent de `_iconeDocumentLegacy`), **retirez la recopie** : elle s'empilerait sur le rendu natif |

🟢 **Tripwire recommandé** : gardez un test qui affirme votre recopie (`_iconeDocumentLegacy`
présent dans l'arbre). Il rougira à l'adoption et vous donnera la liste des écrans touchés.

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **1150** (+47 depuis v0.44.0) · `zcrud_core` **1182** (+4) · **0 error,
0 warning, 0 info neuf** (57/10).

**R3 — 22 injections mordantes** : 8 (CR-54) + 10 (CR-56, campagne reprise et rejouée par
l'orchestrateur après la mort de l'agent rédacteur — verdicts produits sous timeout, aucun
résidu, fichiers identiques bit à bit aux sauvegardes) + 4 de l'orchestrateur sur les
correctifs legacy — dont une garde trouvée **verte-pour-rien** (aucune garde ne mesurait la
fonte du badge : l'injection « 8→11 » restait verte ; garde ajoutée, injection rejouée rouge).

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 6. Ce que nous savons ne pas avoir couvert

* **Aucun golden** — la fidélité au legacy est mesurée en géométrie, rôles et métriques de
  fonte, jamais au pixel. Votre QA sur appareil reste la preuve visuelle finale.
* Le RTL des nouvelles cartes n'est mesuré que sur l'ancrage du badge (directionnel), pas
  sur l'ensemble du chrome.
* La restitution v0.43.0 est gardée pour la hiérarchie `tintedTile` ; les **options**
  redevenues absentes par défaut (extrait, balises, compteur) doivent être re-demandées
  explicitement par l'hôte qui les veut — c'est le sens de la CR, mais un hôte v0.43.0 qui
  y tenait doit les rallumer.
* Le geste d'un renderer de réordonnancement **injecté** reste hors garantie du socle.
* `secondaryAction` dans la ligne d'en-tête cliquable : l'ordre de priorité est mesuré en
  tap ; le **survol/focus clavier** n'est pas couvert.
