# Handoff v3.18.0 — la ligne de sous-liste : poignée, cadre, marges

> **Date** : 2026-08-24. **Portée** : `zcrud_core`. **Traite** : CR-IFFD-111 (trois volets) et la
> décision du propriétaire sur le glyphe de la poignée.

## 1. Les défauts

**① La poignée n'était pas personnalisable.** Livrée en même temps que le glisser-déposer, elle
rendait un glyphe figé, sans taille ni couleur réglables. Vérifié : `Semantics > SizedBox(48, 48) >
Center > Icon(...)`, aucun jeton.

**② La bordure d'une ligne ne pouvait pas dépendre de l'item.** Les deux sites de construction de
ligne recevaient `borderColor: theme.fieldBorderColor` — la même couleur pour toutes les lignes.
Les seams pouvaient peindre le **contenu** d'une ligne, jamais son **cadre**. C'est ce qui permet à
l'œil de repérer sans lire la ligne qui compte parmi ses replis.

**③ Les marges horizontales étaient restées en dur** alors que leur pendant vertical avait été
tokenisé dans la version précédente : la même sous-liste était réglable en hauteur et figée en
largeur, sans raison qui distingue les deux axes. Le relevé de l'hôte est exact — 16 dp de marge
externe + 12 dp de marge interne + 12 dp de centrage du glyphe.

## 2. Ce que le socle livre

**Le glyphe par défaut change** : `Icons.drag_indicator_rounded`. La grille de points est
l'affordance reconnue d'un déplacement ; les deux barres se lisent comme un séparateur. Cible
tactile, libellé sémantique et déclencheur de geste inchangés.

**Cinq jetons nullables**, patron des jetons voisins, tous inertes par défaut :
`subListDragHandleIcon` · `subListDragHandleSize` · `subListDragHandleColor` ·
`subListRowHorizontalPadding` (⇒ 16) · `subListRowInnerPadding` (⇒ 12). Les deux derniers sont deux
**scalaires** et non un insets unique : les quantités vivent dans deux couches et se composent
(début = externe + interne, fin = externe seul), et les faces verticales d'un insets doubleraient le
jeton d'espacement vertical existant. Sans jeton de taille ni de couleur, la poignée reste à la
taille et à la couleur **ambiantes** — aucun littéral n'est posé à la place.

**Un seam pour la bordure par item** : `ZSubListSeams.itemBorderColorKey`, de type
`ZSubItemColorKey = String? Function(ZSubListItemView)`, jumeau exact du seam de visibilité de menu
déjà en place. Chaîne de résolution : **seam → `ZcrudScope.colorKeyResolver` → rôles Material 3 →
`fieldBorderColor`**. Sans seam déclaré, la sortie se fait **avant** toute résolution : zéro appel.

L'option que la CR proposait en premier — un paramètre sur `ZSubListItemView` — a été écartée sur
mesure, pas par préférence : cette vue n'est construite que par le cœur, en trois sites, et n'est
jamais écrite par un hôte ; le flux va du cœur vers l'hôte, jamais l'inverse.

## 3. Ce qui change pour un hôte

- **Hôte passif : aucun pixel déplacé**, prouvé par six gardes d'inertie mesurant rectangles et
  décorations, non pas affirmé. Seule exception assumée : le **glyphe** de la poignée change.
- **Hôte ayant compensé** — un `IconTheme` local pour teindre la poignée, une bordure peinte dans
  `itemBuilder`, un `Padding` externe pour resserrer la ligne : rien ne lui est retiré, mais sa
  compensation **s'additionne** dès qu'il adopte le jeton correspondant. Retirer la compensation
  d'abord, poser le jeton ensuite.
- **Deux effets qu'une lecture de la CR ne laisse pas prévoir** :
  1. `subListRowHorizontalPadding` gouverne aussi l'**en-tête de colonnes** et le **seuil
     d'empilement** du résumé compact — un résumé jusqu'ici empilé peut redevenir tabulaire. Le
     libellé du bloc garde par ailleurs sa marge propre de 16 dp : posé à 0, le jeton ne l'aligne
     pas sur le cadre.
  2. La marge avant le glyphe **ne descend pas sous 12 dp**, et **remonte à 14 dp** si l'on pose
     `subListDragHandleSize: 20` — rétrécir le glyphe élargit son centrage dans la cible de 48 dp.
     Les 28 dp demandés sont intégralement rendus ; le reste est le plancher d'accessibilité que la
     CR concédait elle-même.
- **En résumé tabulaire**, le cadre appartient à la table entière : il n'y a pas de bordure par
  ligne à teinter. Le seam vaut pour la carte d'item (`inline`) et pour la ligne hors table.

## 4. Vérification

Rejouée par l'orchestrateur, lot au repos.

| Contrôle | Résultat |
|---|---|
| `zcrud_core`, depuis son dossier | **2 528 tests verts** (2 506 + 22 gardes neuves) |
| `melos run generate` | SUCCESS — **0 `.g.dart` modifié** |
| `melos run analyze` repo-wide | **RC=0** (4 `info` préexistants) |
| `melos run verify` (12 gates) | **RC=0**, avant **et** après le bump |
| Balayage des 41 paquets, chacun depuis son dossier | **40 verts** ; `zcrud_generator` rouge **environnemental** de signature inchangée (`Isolate.packageConfig` via `build_test`) |
| Résidus d'injection R3 | **0** — marqueur absent du dépôt |

**Discipline R3** : 13 injections, 13 mordantes, rouge **par assertion** dans les treize cas (le
script refuse un verdict dont la sortie porte une erreur de compilation et exige un `Expected:`),
restauration par copie, sha256 identique, grep négatif montré par injection **et** global. Une
injection a été **abandonnée par le script lui-même** parce que son motif apparaissait deux fois —
puis rejouée avec un motif unique : c'est le comportement attendu d'une campagne honnête.
