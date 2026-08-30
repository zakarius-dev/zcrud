# Handoff v3.41.0 — l'alignement des onglets se relaie aussi sur la seconde surface

> **Date** : 2026-08-30. **Portée** : `zcrud_core`, `zcrud_screen`. **Origine** : report explicite
> du handoff v3.40.0 (le motif traité pour `zcrud_study` subsistait ailleurs).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : 0 `.g.dart` modifié.

## 1. Ce que le socle livre

- `ZTabbedList.tabAlignment: TabAlignment?` — relayé au `TabBar`. Le widget ne décide rien : il
  transmet, et la dartdoc dit ce qui reste à l'appelant.
- `ZCrudScreen.tabsAlignment: TabAlignment?` — nommé d'après `tabsScrollable` (convention mesurée
  du fichier), relayé à `ZTabbedList`. Un seul site de construction dans le paquet (grep).

`null` ⇒ rendu strictement inchangé, prouvé par des signatures d'arbre **capturées avant le seam**
(la copie de sauvegarde du source a été remise en place pour la mesure, puis le fichier modifié
restauré : la constante gelée n'est donc pas une auto-photographie).

**Correction d'un constat de v3.40.0** : l'assertion du SDK interdit **deux** combinaisons, pas
une — `fill` + scrollable, et `start`/`startOffset` + non-scrollable. `center` est valide dans les
deux modes. Les deux sens sont désormais portés par la dartdoc.

## 2. Le symptôme, mesuré

Viewport 600 dp, trois libellés longs, barre défilante : par défaut (`startOffset`) le troisième
onglet finit à `right = 739,6` pour un bord à `700` — **39,6 dp de débordement** ; sous
`TabAlignment.start`, `right = 687,6`, soit **12,4 dp de marge** et un décrochage de tête ramené de
68 à 16 dp (les 52 dp récupérés, comme sur l'autre surface).

## 3. Ce qui change pour un hôte

- **Passif : rien** — `tabAlignment` reste `null` sur le `TabBar`, inertie assertée par signature
  gelée dans les deux paquets, `isScrollable`/`tabsScrollable` non altérés.
- **Hôte ayant contourné** : celui qui posait une barre d'onglets maison au-dessus de `ZCrudScreen`,
  ou forçait un `TabBarTheme.tabAlignment` global pour récupérer ces 52 dp, peut retirer sa
  compensation et déclarer `tabsAlignment: TabAlignment.start`. ⚠️ Un `TabBarTheme.tabAlignment`
  global laissé en place **reste prioritaire là où le paramètre est nul** : c'est le cumul à
  surveiller.

**Aucune troisième surface non couverte** : les deux seuls `TabBar(` de `*/lib` sont celui de ce
lot et celui du shell, qui exposait déjà l'alignement.

## 4. Vérification

`zcrud_core` : **2 696 verts** (2 690 + 6), analyze 13 infos préexistantes ·
`zcrud_screen` : **394 verts** (390 + 4), analyze propre · `melos run generate` 0 `.g.dart` ·
`analyze` repo-wide RC=0 · `verify` RC=0 · R3 : 4 injections (relais supprimé, défaut non nul —
sur chaque paquet), toutes rouges **par assertion**, restaurations par copie, sha identiques, grep
négatif sur tout le dépôt · Balayage des 41 : **publication anticipée à la demande du propriétaire** — 18/41 paquets balayés au moment du tag, **0 rouge**, le reste du balayage se poursuivait. Les deux paquets touchés, `generate`, `analyze` et `verify` étaient verts (mesures ci-dessus).

**Limites dites** : les signatures d'inertie sont couplées au rendu Material du SDK local (une
montée de Flutter les fera rougir en désignant un changement de structure — voulu, mais demandera
un regel explicite) ; les bornes en dp dépendent de la police de test et sont figées avec une
tolérance, les assertions d'ordre portant le sens ; les combinaisons interdites par le SDK ne sont
pas exercées par un test (elles planteraient sur une assertion Flutter, pas la nôtre) — le contrat
est tenu par la dartdoc, et c'est écrit en tête des fichiers de gardes.
