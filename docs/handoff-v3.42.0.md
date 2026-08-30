# Handoff v3.42.0 — rien à naviguer, rien à monter ; et la sélection atteint les trois onglets

> **Date** : 2026-08-30. **Portée** : `zcrud_study`. **Traite** : CR-LEX-90 et CR-LEX-91 (MAJEUR).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : 0 `.g.dart` modifié.

## 1. CR-LEX-90 — une navigation sans destination ne s'affiche plus

`ZSubfolderNav` montait sa barre **même avec zéro sous-dossier** : sa largeur était retirée au
corps, et une grille qui tenait deux colonnes à 600 dp n'en tenait plus qu'une. Mesuré avant
correction : sidebar `LTRB(0,104,300,800)`, corps réduit à `300 dp`. Aucun contournement propre
n'existait — les deux placements cités par la CR étaient mauvais dans ce cas, et la sonde en a
révélé un **troisième** que la CR ne mentionnait pas : `aboveTabBar` donnait une app-bar de 152 dp
au lieu de 104.

Livré : `zSubfolderNavHasDestinations(spec)` — **borne unique**, publique, appliquée dans
`ZSubfolderNav.build` et aux trois sites de `ZStudyFolderDetail`. La borne a été mesurée avant
d'être posée : `allSubfoldersLabel` seul n'a aucun sens de navigation (l'item racine ne désigne que
ce qui est déjà affiché), donc *rien à naviguer = `subfolders` vide*, quels que soient les libellés
et actions annexes.

⚠️ **Conséquence assumée et gardée** : le `+` « créer le premier sous-dossier » porté par la barre
disparaît avec elle. L'hôte le place en app-bar, dans le hub ou dans l'état vide. Même remarque
pour une coquille `ZSubfolderNavRendererScope` qui rendrait un état vide illustré.

## 2. CR-LEX-91 — la sélection atteint les trois onglets

`materialSectionsBuilder` recevait la sélection ; `notebookBuilder` et `progressionBuilder` non,
alors que le conteneur détient cette valeur et n'expose aucune sortie. Conséquence chez l'hôte :
deux onglets **désynchronisés** dans le même écran — les flashcards suivant la navigation, les
notes restant au périmètre initial. Défaut qui ne fait rougir aucun test : le contenu rendu est
plausible, simplement pas celui du sous-dossier affiché.

Livré : `notebookTabBuilder` et `progressionTabBuilder` (typedef `ZStudyTabBuilder`), qui
**priment** sur les anciens. Forme retenue par la mesure : Dart n'admet pas deux signatures sur un
même nom, et retoucher les paramètres existants aurait cassé les deux hôtes qui les passent. Les
trois builders sont invoqués dans la **même tranche** `ValueListenableBuilder<String?>` : trois
builders, une seule valeur. Le callback de sortie a été écarté — `nav.onSelectionChanged` existe
déjà, et la CR dit elle-même que le miroir serait incomplet.

## 3. Ce qui change pour un hôte

- **Passif : rien** — inertie gardée par des goldens de géométrie relevés **avant** correction, sur
  trois placements × deux largeurs ; les anciens builders continuent de compiler et de rendre à
  l'identique.
- **Hôte ayant contourné** : celui qui basculait en `aboveTabs` pour éviter la colonne perdue peut
  **retirer** ce contournement et revenir à `withinTab` inconditionnel ; celui qui passait une
  sélection figée doit adopter `notebookTabBuilder` (et `progressionTabBuilder` si sa progression
  est filtrée) ; celui qui garde `subfolders.isEmpty || isWideScreen` dans ses conditions peut le
  retirer — **mais s'il utilise `addPlacement: sheetOnly`, qu'il déplace d'abord son action
  « ajouter un sous-dossier »** : à zéro sous-dossier, la barre n'existe plus et le pied de feuille
  n'est plus atteignable.

## 4. Vérification

`zcrud_study` : **1 887 verts** (1 867 + 20), analyze 72 infos préexistantes, 0 neuve ·
`melos run generate` 0 `.g.dart` · `analyze` repo-wide RC=0 · `verify` RC=0 · R3 : 11 injections,
rouges **par assertion**, restaurations par copie, sha identiques, grep négatif ·
Balayage des 41 : **41/41 verts** — ce balayage couvre aussi les paquets non atteints lors de la publication anticipée de v3.41.0, dont aucun n'est rouge.

🔴 **Deux constats de méthode, à retenir** : une injection a révélé une garde **inerte**
(`_aboveTabBarHeight` : 0 rouge sous injection) — la garde manquante a été écrite avant de rejouer.
Et une garde existante **défendait le défaut** : elle affirmait qu'à zéro sous-dossier la barre
s'affiche quand même. Elle a été **reciblée** sur une destination unique — la propriété qu'elle
protégeait reste vraie et gardée —, et l'absence à zéro destination a désormais sa garde propre.
