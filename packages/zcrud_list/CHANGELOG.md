# Changelog

Toutes les modifications notables de `zcrud_list` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 0.93.0 — 2026-08-13

### Ajouté

- `rowsPerPage` : pager numéroté sous la grille, paginant côté client
  l'instantané déjà en mémoire, virtualisation conservée. `null` par défaut —
  aucun pager, arbre de widgets inchangé. Orthogonal à `onLoadMore`
  (pagination backend par curseur).
- `copyCellOnLongPress` et `copiedMessageKey` : long-press d'une cellule
  copiant sa valeur **formatée** — le texte exact affiché, jamais la valeur
  brute — avec un retour visuel par toast. `false` par défaut ; la ligne
  d'en-tête et les colonnes techniques ne copient rien. La clé de message
  n'est pas enregistrée dans `zcrud_core` : sans surcharge de l'hôte, le toast
  affiche le libellé générique « Copier ».
- `swipeToRevealActions` et `swipeMaxOffset` : swipe début→fin d'une ligne
  révélant ses actions **déjà résolues** (mêmes libellés, même état activé,
  mêmes callbacks que la colonne d'actions — aucun second canal d'actions).
  `false` par défaut ; l'offset se dérive du nombre d'actions s'il n'est pas
  fourni, au plancher tactile de 48 dp par action.
- `stackedHeaders` : lignes d'en-tête empilées au-dessus de l'en-tête normal,
  chaque groupe couvrant plusieurs colonnes désignées par leur nom. Libellés
  fournis comme clés de localisation résolues au rendu. Liste vide par défaut.
- `columnSizing` : dimensionnement par colonne (largeur fixe, minimum,
  maximum, mode de largeur spécifique, marge d'auto-ajustement) via le
  nouveau type `ZSfColumnSizing`. Map vide par défaut ; une entrée partielle
  ne touche que les champs qu'elle déclare.
- `allowColumnResizing` : redimensionnement des colonnes par l'utilisateur,
  largeurs persistées sans reconstruire la liste — source mémoïsée et
  contrôleur préservés, donc scroll et sélection intacts. `false` par défaut.
- `adaptiveRowHeight` et `maxRowHeight` : hauteur de ligne suivant la hauteur
  intrinsèque du contenu (les cellules passent alors à la ligne au lieu d'être
  tronquées), plancher de 48 dp, plafond optionnel. `false` par défaut.
- `cellStyleBuilder` et le type `ZSfCellStyle` : style conditionnel complet par
  cellule (fond, style de texte, alignement, marge, alignement du texte,
  nombre maximal de lignes), résolu depuis les types neutres de `zcrud_core`.
  Généralisation de `cellColorBuilder`, qui reste disponible ; si les deux sont
  fournis, le fond de `cellStyleBuilder` prime et retombe sur celui de
  `cellColorBuilder` quand il n'en déclare pas.
- `ZSfDataGridRenderer.responsiveColumnWidthMode(...)` : la règle de largeur
  responsive exposée comme fonction pure, rejouable et testable sans monter de
  widget.
- Dépendance sur `zcrud_ui_kit` pour le toaster injecté du retour de copie.
  Le graphe reste acyclique et `zcrud_core` sans dépendance sortante.
- Le barrel `package:zcrud_list/zcrud_list.dart` ré-exporte `ColumnWidthMode`.
  C'est le seul type Syncfusion présent dans la signature publique du paquet
  (`columnWidthMode`, `ZSfColumnSizing.widthMode`,
  `responsiveColumnWidthMode`) : l'échappatoire ci-dessous s'écrit désormais
  avec le seul import du paquet, sans déclarer de dépendance Syncfusion dans
  l'application. Aucun autre symbole Syncfusion n'est ré-exporté — le paquet
  reste la seule arête Syncfusion du graphe.

### Modifié

- **Changement de défaut — le seul de cette version.** `columnWidthMode` passe
  de non-nullable (`ColumnWidthMode.fill`) à **nullable**, `null` par défaut.
  Laissé à `null`, le mode est désormais **dérivé** de la plateforme et du
  nombre de colonnes de données : plus de 3 colonnes en web et bureau, plus de
  1 colonne en mobile, le mode devient `auto` ; en deçà, il reste `fill`.

  Un hôte **passif** (qui ne passait pas ce paramètre) obtenait `fill` en
  toute circonstance : ses tableaux de plus de 3 colonnes (plus de 1 sur
  mobile) passent maintenant en `auto`, donc dimensionnés au contenu avec
  défilement horizontal au lieu d'être répartis sur la largeur disponible.

  **Échappatoire exacte** pour retrouver l'ancien comportement :

  ```dart
  ZSfDataGridRenderer(columnWidthMode: ColumnWidthMode.fill)
  ```

  L'enum `ColumnWidthMode` est ré-exporté par le barrel du paquet :
  l'échappatoire ne demande que `import 'package:zcrud_list/zcrud_list.dart';`.

  Un hôte qui **compensait** cette répartition (largeurs forcées, enveloppe de
  défilement horizontal ajoutée à la main) doit vérifier que sa compensation
  ne s'additionne pas au nouveau comportement, ou passer la valeur explicite
  ci-dessus.

- **Corrigé — offset de swipe et pagination.** Quand le pager numéroté
  (`rowsPerPage`) et le swipe (`swipeToRevealActions`) sont utilisés ensemble
  et que l'offset est laissé à sa dérivation, changer de page recalcule
  désormais cet offset sur les lignes réellement rendues. Auparavant il
  restait figé sur la première page affichée : une page dont les lignes
  portaient davantage d'actions voyait sa révélation tronquée (mesuré : 68 dp
  au lieu de 180 dp pour trois actions). Un `swipeMaxOffset` explicite reste
  appliqué tel quel, et le rendu par défaut n'ajoute toujours aucun étage de
  reconstruction.

- `README.md` : le paquet est désormais présenté d'emblée comme le **backend
  de rendu Syncfusion** du port `ZListRenderer` et non comme « l'écran de
  liste », avec renvoi vers `zcrud_screen` pour l'écran CRUD assemblé.
  Documentation de tous les réglages, de leur défaut et de leur caractère
  opt-in.

### Corrigé

- **La numérotation peut enfin être CONTINUE sous le pager interne.** Le décalage
  ne s'obtenait que par `ZListOrdinal.pageOffset`, une valeur fixe déclarée par
  l'hôte — or l'index de page du pager (`rowsPerPage`) est privé au rendu :
  l'hôte n'apprenait jamais qu'il avait changé, et la deuxième page recommençait
  à `1`. Le rendu transmet désormais sa page à la règle du cœur ; déclarer
  `ZListOrdinal(continuousAcrossPages: true)` suffit. Sans cette déclaration,
  rien ne change : chaque page est numérotée à partir de `1`.
- **La colonne de numéro d'ordre suit désormais l'affichage.** Le numéro était
  figé au moment où la ligne était construite : il voyageait ensuite avec elle.
  Après un tri, la colonne « # » d'un tableau de cinq lignes triées à l'envers
  affichait `5, 4, 3, 2, 1` au lieu de `1, 2, 3, 4, 5` — l'utilisateur lisait
  la position d'origine de chaque ligne, jamais sa place à l'écran. Le numéro
  est maintenant calculé au moment de peindre, depuis la position d'affichage
  (tri et page appliqués), selon l'unique règle de numérotation portée par
  `ZListOrdinal` dans `zcrud_core`.

  La colonne se déclare avec le schéma —
  `ZColumnPolicy(ordinal: ZListOrdinal(enabled: true))` — ce qui lui apporte
  aussi son en-tête, sa largeur et son décalage de page. `withOrderNumber` et
  `orderColumnHeader` restent disponibles et inchangés pour l'hôte qui
  construit sa requête sans politique de colonnes ; la déclaration de la
  requête l'emporte quand elle est active.

  Avec le pager (`rowsPerPage`), chaque page est numérotée à partir de `1` —
  c'est le sens du décalage par défaut, qui numérote la page rendue. Une
  numérotation continue sur tout le jeu de données se demande par
  `ZListOrdinal(pageOffset: pageIndex * pageSize)`, côté hôte.

  La colonne technique porte enfin le nom réservé du cœur
  (`ZListOrdinal.columnName`, soit `__z_ordinal`) au lieu d'un nom interne
  propre au backend, pour qu'un export puisse la reconnaître et l'exclure. Un
  hôte qui aurait indexé `columnSizing` sur l'ancien nom interne doit reprendre
  cette clé — c'est le seul geste demandé par cette correction.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants — y compris `onLoadMore` et
  `cellColorBuilder`.
- Fiche `docs/site/paquets/zcrud_list.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`E4-1` à `E4-4`, `AC5`,
  `AC9`, `Lot 5`, `MEDIUM-1`, `L2`) et conservation des invariants citables
  (`AD-1`, `AD-8`, `AD-10`, `AD-13`). Aucun changement de code — la revue ne
  porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_list/`.
