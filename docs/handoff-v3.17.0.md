# Handoff v3.17.0 — le glisser-déposer, l'ordre des champs libres, l'aération de la sous-liste

> **Date** : 2026-08-24. **Portée** : `zcrud_core`. **Traite** : CR-IFFD-108, CR-IFFD-109 et
> CR-IFFD-110, émises le même jour sur constats à l'écran du propriétaire, publiées en une vague.

## 1. Les défauts

**108** — la sous-liste réordonne par **deux flèches** là où le legacy a une **poignée de
glisser-déposer**. Ce n'est pas un manque du monorepo : le port `ZReorderRenderer` existe
(injectable par `ZcrudScope`), `zcrud_responsive` en donne un défaut, `zcrud_reorder` une
implémentation — la sous-liste ne le consulte nulle part et code ses flèches en dur, au nom d'une
incompatibilité de `Table` que le legacy réfute (`buildDefaultDragHandles: false` + poignées
propres). Les quatre contrôles de fin de ligne coupent en outre les noms de modèles en plein mot.

🔴 **Décision du propriétaire, prise après avoir vu le rendu** : *supprimer définitivement les
flèches pour ne garder que le glisser-déposer, partout* — un remplacement, pas un ajout, dans les
deux modes. La contrepartie exigée par la CR : des **actions sémantiques de déplacement** par ligne,
pour que la disparition du chemin non gestuel ne soit pas une régression d'accessibilité.

**109** — en voie groupée (la seule qui décore), un champ **sans section** ne peut pas être placé
après une section : `_buildGrouped` rend tous les champs libres en bloc de tête, l'ordre déclaré de
`fields` étant ignoré. Et une section à **titre vide** paie quand même son en-tête (~44 dp d'espace
mort + un nœud sémantique vide) — le contournement actuel est « un groupe qui ment ».

**110** — l'espacement vertical **interne** de la sous-liste n'est réglable par aucun jeton. Le
propriétaire l'a mesuré avant d'accuser le mauvais réglage : `ZcrudTheme.fieldGap` porté de 12 dp à
0 ne retire que ~12 px sur les ~105 px qui séparent deux groupes consécutifs ; le reste est produit
à l'intérieur du widget de sous-liste, sans canal. Vérifié : `ZcrudTheme` porte 205 jetons, dont
neuf pour la sous-liste (largeur de colonne, taille d'icône, trois couleurs d'action, cinq du
contrôle d'ajout) — **aucun** d'espacement vertical, et le widget écrit ses paddings en `const`.

## 2. Ce que le socle livre

**108 — glisser-déposer, plus aucune flèche.** La sous-liste consulte désormais
`ZReorderRenderer` : celui injecté par `ZcrudScope.reorderRenderer`, sinon un **repli interne**
zéro-configuration (`zcrud_core` ne peut pas dépendre de `zcrud_responsive`, AD-1 ; c'est la forme
de résolution déjà employée par l'unique autre consommateur du port). Chaque ligne porte une
**poignée ≥ 48 dp** en tête et des **actions sémantiques de déplacement**, dans les deux modes.
`grep -ac 'arrow_upward|arrow_downward'` sur le widget = **0** ; le canal structurel unique est
`_moveTo`.

La contrainte `Table` invoquée jusqu'ici est réelle (une `Table` fige ses `TableRow`) mais mal
conclue : rien n'obligeait à garder la table quand l'ordre est éditable. Tranché comme le legacy —
le rendu tabulaire ne s'applique plus que si l'ordre n'est **pas** réordonnable, les en-têtes de
colonnes étant conservés par une réserve de tête. Le repli interne réconcilie ses lignes **par
clé**, et non par le châssis du SDK dont l'identité d'item inclut l'index : ce dernier reconstruirait
l'élément déplacé à neuf, avec perte de focus, contraire à AD-2.

**109 — l'ordre déclaré fait loi, un titre vide ne coûte plus rien.** ① `_buildGrouped`
(`dynamic_edition.dart:1082`) suit l'ordre de `fields` : une section est émise **à la position de
son premier membre visible** (`:1112`), les champs libres forment des blocs intercalés, et un filet
de couverture rattrape les sections jamais rencontrées. ② `hasHeader` vaut « titre non vide **ou**
icône » (`:1147`) : sinon ni chrome, ni padding, ni nœud sémantique (`:1153`) ; une section
repliable sans titre n'a plus de déclencheur et **reste dépliée** (`:1149`). La règle est propagée à
la voie plate et au chrome — plus de `Text` vide sous une icône seule.

**110 — l'aération de la sous-liste devient pilotable, et le relevé corrige la CR sur deux
points.** Le relevé a été refait sur le code **après 108** (la CR décrivait le rendu d'avant), par
mesure des rectangles sur deux sous-listes consécutives. Le blanc entre la dernière ligne et le
libellé du bloc suivant vaut **32 dp** en résumé tabulaire (8 cellule + 4 marge de table + 12
`fieldGap` + 8 libellé), **38 dp** en lignes libres, **84 dp** en `inline` (dont 48 pour le bouton
d'ajout).

Deux corrections utiles à l'hôte : ① le `fromSTEB(0, 8, 0, 24)` que la CR désignait comme suspect
n°1 est le rembourrage de la **page d'édition d'un item**, une route à part — hors cause ; ② en mode
réordonnable, le poste dominant n'est **pas un padding** mais les **14 dp de jeu** dans la cible
tactile de 48 dp de la poignée née de 108. Ce poste-là n'est **délibérément pas tokenisé** : c'est
un plancher d'accessibilité (AD-13), et offrir de le régler reviendrait à offrir de le casser.
L'échappatoire est `reorderable: false`, qui bascule sur le tabulaire — plus compact *et* plus
réglable.

Six jetons nullables, tous inertes par défaut, patron `subListAddControl*` (constructeur, champ,
`copyWith`, `lerp`), consommés par six résolveurs `?? <littéral d'avant>` sur dix sites :
`subListCaptionTopPadding` (8) · `subListHeaderTopPadding` (8) · `subListRowVerticalPadding` (4) ·
`subListCellVerticalPadding` (8) · `subListTableVerticalMargin` (4) · `subListBlockEndPadding` (8).
La recette compacte complète retire **52 dp par sous-liste** en tabulaire, 32 en lignes libres, 32
en `inline`.

## 3. Ce qui change pour un hôte

- **⚠️ 108 est un CHANGEMENT DE RENDU voulu** (décision du propriétaire) : les flèches disparaissent
  partout au profit de la poignée — y compris celles livrées en v3.13.0 pour le mode `compact`. Un
  hôte qui posait des gardes sur les flèches les adapte ; l'équivalent accessible est sémantique.
- **108, hôte ayant compensé** : celui qui rendait ses **propres flèches à côté** des nôtres doit les
  retirer, sinon elles s'ajoutent à la poignée. Celui qui compensait l'absence de glisser-déposer par
  un `listViewBuilder`/`onReorder` **garde son conteneur** : les lignes servies à un seam n'emportent
  pas de poignée (propriété sous garde). Hôte passif : le rendu change, aucun code à toucher.
- **109** : l'ordre déclaré devient la vérité en voie groupée — un hôte qui comptait sur le
  regroupement forcé des champs libres en tête voit l'ordre suivre sa déclaration ; une section à
  titre vide cesse de rendre un en-tête (espace et sémantique).
- **IFFD** : peut supprimer sa **section-mensonge** à titre vide — le champ indépendant se déclare
  simplement après la section, et une section vide résiduelle devient inoffensive. Ses tripwires
  `test/m0/parite_visuelle_champs_test.dart` rougissent : c'est leur travail.
- **110, hôte passif : rien ne change — prouvé, pas affirmé.** Quatre gardes d'inertie figent les
  rectangles des quatre rendus aux valeurs d'avant-lot, et l'injection R3 d'un seul repli faussé
  (`?? 8` → `?? 0`) les fait rougir (`<156>` attendu contre `<148.0>` obtenu).
- 🔴 **110, hôte ayant compensé** : un `Padding` négatif, un `Transform.translate` ou un conteneur
  maison posé autour d'un champ `subItems` pour rattraper l'aération **s'additionnerait** aux
  jetons. Retirer la compensation d'abord, poser les jetons ensuite. Chez IFFD, l'écran du routeur
  IA est le site concerné.
- **110, recette** : `ZcrudScope(theme: ZcrudTheme(subListCaptionTopPadding: 0,
  subListHeaderTopPadding: 0, subListRowVerticalPadding: 0, subListCellVerticalPadding: 2,
  subListTableVerticalMargin: 0, subListBlockEndPadding: 0), child: …)` — soit 384 à 624 dp gagnés
  sur les douze groupes du routeur IA, `fieldGap` non compris.

## 4. Vérification

Rejouée par l'orchestrateur, tous les lots au repos — jamais sur la foi d'un rapport d'agent.

| Contrôle | Résultat |
|---|---|
| `zcrud_core`, depuis son dossier | **2 506 tests verts** (2 491 après 108/109, + 15 gardes de 110) |
| `melos run generate` | SUCCESS — **0 `.g.dart` modifié** |
| `melos run analyze` repo-wide | **RC=0** (4 `info` préexistants, aucun sur les fichiers du lot) |
| `melos run verify` (12 gates) | **RC=0**, avant **et** après le bump |
| Balayage des **41 paquets**, chacun depuis son dossier | **40 verts** |
| `zcrud_generator` | rouge **environnemental qualifié** : les 41 échecs sont tous `Unsupported operation: Isolate.packageConfig` (via `build_test`), aucun rouge de code |
| Résidus d'injection R3 | **0** — `ZR3-110-INJECT` absent du dépôt (les deux occurrences de `R3INJ` sont des commentaires d'une campagne antérieure dans `zcrud_study*`) |
| Dartdoc | **0** numéro de CR, version ou récit de lot dans les `///` des fichiers touchés |

**Discipline R3** : 12 injections pour 108/109, 4 pour 110 — toutes rouges **par assertion** (jamais
par erreur de compilation), restauration **par copie de fichier**, sha256 avant/après identiques,
grep négatif du marqueur montré. Deux constats honnêtes portés par les lots eux-mêmes : une
injection de 109 est d'abord restée **verte** (la garde n'atteignait pas le seul chemin vivant —
icône avec titre vide), garde manquante ajoutée puis rouge ; et les **verts témoins** de 110
prouvent qu'un jeton mort est **invisible** à une garde d'inertie seule, ce qui justifie la garde
d'effet.
