# Handoff **v0.44.0** — CR-IFFD-49 + CR-IFFD-50 + CR-IFFD-52 : le rail tient, l'en-tête s'ouvre, l'ordre revient

> **Tag à épingler : `v0.44.0`** · additif, aucune rupture d'API, tous les défauts conservés.
> CR-IFFD-51 : **retirée par vous** — son constat a nourri CR-52, traitée ici.
> 🔴 Un seul point pour l'hôte qui compensait — § 5.

---

# Partie A — CR-IFFD-49 : le rail par défaut

## 1. ① Confirmé, et pire que votre formulation

Reproduit indépendamment avant d'écrire : `.flashcards(axis: horizontal)` à travers
`ZSectionedStudyLayout` ne « peint rien » qu'en release — en debug, c'est une **rafale** de
`RenderFlex … unbounded width`. Votre réserve de CR-47 était au bon endroit ; notre limite déclarée
(« la voie typée n'est pas testée à travers le layout ») était exactement là où le défaut vivait.

**Forme retenue** : un bornage par le socle, largeur résolue `paramètre > jeton de thème
(`ZcrudTheme.railItemWidth`) > repli 280 dp`. Votre 300 dp n'est **pas** devenu la constante du
socle : c'est votre valeur, posez-la dans votre thème ou par paramètre. Le correctif vaut pour les
**trois** voies typées (`.flashcards`, `.mindmaps`, `.exams`) ; un `itemBuilder` d'hôte en axe
horizontal reste sous sa responsabilité, strictement inchangé — gardé.

## 2. ② Le couplage « rail des N premiers → grille complète » est une capacité

`railPreviewCount` sur les voies typées : borne l'affichage à `min(N, total)`, force le badge au
**TOTAL réel** (le défaut invisible que vous décriviez — « 10 » pour 60 — a sa garde dédiée), et
l'action passe par `secondaryAction`/`secondaryActionLabel` existants — vos libellés, votre
navigation (frontière CR-48). La grille d'arrivée n'est pas un widget de plus : **c'est la même voie
typée en `axis: vertical`** — c'est la moitié de la valeur du couplage.

**Votre cas non mesuré (total ≤ N), tranché** : l'action « afficher tout » est **retirée de l'arbre**
(AD-4 : absent plutôt que présent-et-inutile) — le rail et la grille montreraient la même chose.

# Partie B — CR-IFFD-50 : l'en-tête de section

| # | Livré | Défaut |
|---|---|---|
| ① | `ZcrudTheme.studySectionTitleStyle` (`TextStyle?`) | `null` ⇒ `titleMedium`, rendu antérieur exact |
| ② | `studySectionCountShape { rounded, pill }` + `studySectionCountRole` (5 couples de rôles `ColorScheme` — `primary` = votre « accent, texte inversé ») | rectangle neutre actuel |
| ③ | `secondaryActionLabel` (spec, relayé par les 3 voies typées) | `null` ⇒ icône seule |
| ④ | `studySectionCollapsePlacement { belowTitle, inHeaderRow }` | `belowTitle` (position actuelle) |

Notes de vérification qui vous concernent :
* **③** : une **seule** annonce au lecteur d'écran — le libellé visible, ou `secondaryActionSemanticLabel`
  qui **prime** s'il est fourni (mesuré, jamais deux annonces) ;
* **④** : votre réserve sur les cibles tactiles est **mesurée** — titre long à 320 dp, chevron
  `inHeaderRow` : **≥ 48×48 conservé** (seul le titre est flexible), verrouillé par garde, en LTR et RTL ;
* **②** : nous n'avons **pas** réutilisé `ZCountBadge` (`zcrud_core`) — contrat différent (icône
  exigée, zéro refusé, 48 dp imposés là où un compteur de section affiche « 0 » en 20 dp) ; ce n'est
  pas un doublon divergent, la justification est dans le code ;
* ⚠️ un détail de votre CR est **inexact sur pièces** : `badgeRadius` ne gouverne PAS le rayon du
  compteur de section — c'est `radiusM`. Conservé tel quel ; `pill` est là si vous voulez la forme ronde.
* 🔴 **Trouvé en route, pas dans votre CR** : les replis `'Replier'`/`'Déplier'`/`'Déplacer avant/après'`
  sont des chaînes **françaises en dur** dans le package (héritage CR-IFFD-11, antérieur à la
  discipline FR-26). Défauts **inchangés** (rétro-compat) ; un hôte non francophone doit fournir
  `collapseSemanticLabel`/`expandSemanticLabel` — désormais documenté explicitement.

# Partie C — CR-IFFD-52 : l'étude, et sa réponse implémentée

Votre question : *rendu par défaut ET ordre utilisateur, sans affaiblir l'invariant ?*

**Réponse — la garde change de nature sans changer de force** : sur le constructeur principal,
l'identité stable est **déclarée** par l'hôte (`itemIds` + assert). Sur les voies typées, le socle
**détient les données** : il dérive `itemIds` de `cards[i].id` lui-même et vérifie **sur pièces**.
Vous ne fournissez plus une preuve — le socle la constate. C'est *plus* fort, pas moins.

* `onReorder` (+ libellés/glyphes de réordonnancement) sur les **trois** voies typées ;
* `itemIds` **dérivé en interne** — l'hôte ne peut pas le fournir sur la voie typée (garde de
  source) : le lui permettre recréerait l'espace de divergence que la voie typée élimine ;
* carte **éphémère** (`id == null`) avec `onReorder` : **assert à la construction** nommant l'index
  et le remède ; en release (AD-10), `onReorder` et `itemIds` retombent à `null` **ensemble** — la
  capacité disparaît, jamais la mauvaise carte ne bouge ;
* 🔵 **renforcement trouvé par la mesure** : le rendu mappe id→index par `indexOf`, donc un id
  **dupliqué** est la même classe de défaut que l'éphémère — **refusé aussi**. Votre CR ne le
  demandait pas ; l'invariant, si ;
* `railPreviewCount` × `onReorder` : **refusé par assert** — un rail tronqué réordonnable fait
  diverger l'espace visible de l'espace persistable, c'est le défaut original ;
* l'étude complète : `docs/etude-cr-iffd-52.md` (options considérées, mesures, refus délibérés).

**La preuve centrale n'est pas « l'API accepte `onReorder` »** : elle est un **drag réel depuis la
poignée**, géométrie avant/après — la carte saisie est celle qui bouge, sur les trois voies.

⇒ Votre voie provisoire (« widget seul dans notre `itemBuilder` ») reste valable, mais n'est plus
nécessaire : la promesse de CR-47/48 est désormais tenue **aussi** pour les listes ordonnées.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — tous les défauts conservés, y compris la position du chevron |
| **vous, IFFD** | `railItemWidth: 300` dans votre thème ; `railPreviewCount: 10` + `secondaryActionLabel` ; les 4 jetons d'en-tête ; basculez vos 3 sections ordonnées sur les voies typées avec `onReorder` — et **retirez** votre assemblage manuel (troncature de liste, `headerCount` forcé, builder) |
| 🔴 **hôte ayant COMPENSÉ le rail** | si vous enveloppiez chaque item dans votre propre `SizedBox(width: …)` **à l'intérieur d'une voie typée**, retirez-le : la largeur du socle et la vôtre s'empileraient. (Un `SizedBox` dans votre propre `itemBuilder` du constructeur principal reste correct et inchangé) |

🟢 **Tripwire recommandé** : sur la bascule des sections ordonnées, gardez un test qui affirme votre
assemblage manuel (troncature + `headerCount` forcé). Il rougira à l'adoption et listera les doublons.

## 6. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **1103** (+63 depuis v0.43.0) · `zcrud_core` **1178** (+9) · **0 error, 0 warning,
0 info neuf** · voisins rejoués verts : flashcard 586, session 565, mindmap 207, ui_kit 193, exam 79, get 74.

**R3 — 19 injections mordantes** (8 CR-49 + 11 CR-50/52), motif unique asserté, restauration par
copie, aucun résidu (greps montrés).

🔴 **Une qualification à part, dite franchement** : l'injection I2 de CR-49 (« repli de largeur
remplacé par une constante fausse ») fait échouer la suite **par crash au chargement**
(`AssertionError`) suivi d'un coincement du harnais `flutter_tools` (*« Cannot close sink while
adding stream »*) — reproduit trois fois, y compris sur environnement purgé. La garde mord (la suite
n'est jamais verte sous l'injection), mais par **crash**, pas par assertion propre. C'est aussi ce
coincement — un hang à 0 % CPU — qui a coûté une campagne R3 interrompue et sa reprise par
l'orchestrateur, avec timeout par run désormais systématique. Les 18 autres injections rougissent
proprement.

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 7. Ce que nous savons ne pas avoir couvert

* Le **repli release** de la dérivation d'`itemIds` (éphémère ⇒ capacité retirée) est inatteignable
  sous test (asserts actifs en mode test) — chemin documenté, garde délibérément refusée plutôt que
  simulée.
* Le chevron `inHeaderRow` n'est pas mesuré en mode **sliver**.
* Les replis français en dur (§ Partie B) restent en place — les retirer serait cassant ; c'est un
  candidat pour une évolution majeure de version, pas pour une CR.
* Toujours aucun golden ; le RTL des nouvelles surfaces est mesuré pour ④ mais pas pour le badge ②.
