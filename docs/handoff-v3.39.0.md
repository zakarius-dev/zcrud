# Handoff v3.39.0 — la bascule des sous-dossiers sort du conteneur

> **Date** : 2026-08-30. **Portée** : `zcrud_study`. **Traite** : CR-LEX-87 (MAJEUR).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : 0 `.g.dart` modifié.

## 1. Le défaut

Le socle offrait les deux **variantes** de navigation des sous-dossiers, mais **pas la règle qui
choisit entre elles** : elle vivait enfermée dans `ZStudyFolderDetail`. Conséquence mesurée par
l'hôte, et c'est le fait qui rend la demande décisive : **les deux hôtes qui gardent leur propre
coquille ont réécrit la même règle, au même seuil** — et le second a dû ouvrir le dépôt du premier
pour retrouver la valeur que le socle connaissait déjà. Chacun a aussi réécrit la largeur de la
barre, son repli, et la garantie que les deux variantes ne coexistent jamais.

Il ne s'agissait donc pas d'écrire un comportement, mais de le **rendre atteignable**.

## 2. Ce que le socle livre

**`ZSubfolderNav`** — widget autonome qui choisit la variante selon la largeur disponible, avec
l'exclusivité garantie. Le seuil est `kZSubfolderSidebarBreakpoint` (défaut =
`ZWindowSizeThresholds.mediumMinWidth`, **inclusif** : 599 ⇒ étroit, 600 et 601 ⇒ large — borne
mesurée et figée), paramétrable par l'appelant.

**Extraction, pas duplication** : `ZStudyFolderDetail` **consomme** désormais la brique
(`ZResponsiveLayout` a quitté ce fichier), et la règle est une fonction pure unique
`zSubfolderNavPrefersSidebar(width, {breakpoint})`. Une garde de source interdit toute seconde
comparaison de largeur dans la famille `z_subfolder_*`. Le choix est argumenté par la mesure :
garder `ZResponsiveLayout` à l'intérieur aurait imposé deux chemins (défaut vs seuil personnalisé),
donc deux sites de comparaison ; l'équivalence des deux formes a été vérifiée, largeur infinie
comprise.

**Ce que le widget décide** : quelle variante est montée, l'exclusivité, l'assemblage quand un
`bodyBuilder` est fourni. **Ce qu'il ne décide pas** : la largeur, le repli et les bornes de la
barre — le refus de CR-81 (« la taille appartient à l'hôte ») a été vérifié sur disque et
**respecté** : la barre vient d'un `sidebarBuilder` de l'appelant, aucune contrainte n'est ajoutée.

## 3. Ce qui change pour un hôte

- **Passif** (celui qui utilise `ZStudyFolderDetail`) : **rendu strictement inchangé**, prouvé par
  des signatures structurelles relevées **avant** modification et figées, `SizedBox` et paramètres
  de la barre compris. Seule différence assumée : le nœud `ZResponsiveLayout` au-dessus de
  l'assemblage devient `ZSubfolderNav`.
- 🔴 **Hôtes ayant contourné** — les deux qui gardent leur coquille : en adoptant `ZSubfolderNav`,
  **retirer** leur `LayoutBuilder`, leur constante de seuil et leur assemblage. Les laisser
  **superposerait** deux bascules. Ce qu'ils **gardent** : leur largeur et leur état de repli — la
  décision de taille reste refusée côté socle, `sidebarBuilder` est le point où elle demeure chez
  eux. Tripwire recommandé : un test affirmant que leur seuil local vaut
  `kZSubfolderSidebarBreakpoint` — il rougira si le socle bouge, au lieu de croire le handoff.

**Limite dite** : `sidebarBuilder` est requis (un appelant qui ne veut que la surface étroite passe
un builder trivial) — choix assumé pour ne pas réintroduire par défaut la décision de taille que le
socle a refusée.

## 4. Vérification

`zcrud_study` : **1 855 verts** (1 842 + 13), analyze 72 infos préexistantes, 0 neuve ·
`melos run generate` 0 `.g.dart` · `analyze` repo-wide RC=0 · `verify` RC=0 · R3 : 7 injections,
toutes rouges **par assertion** (dont une garde de spécificité : le seuil personnalisé ignoré ne
fait rougir *que* son test), restaurations par copie, sha identiques, grep négatif ·
Balayage des 41 : **41/41 verts**.
