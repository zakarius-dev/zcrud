# Handoff v3.12.0 — CR-IFFD-91 : la cellule nue, la formule qui défile

> **Date** : 2026-08-24. **Portée** : `zcrud_markdown`. **Traite** : CR-IFFD-91, deux défauts de rendu
> **vus à l'écran par le propriétaire**, vivant dans du code interne qu'aucun paramètre d'hôte n'atteint.

## 1. Les défauts

① **La cellule de tableau markdown est encadrée.** Une cellule riche (gras, lien, formule) est rendue
par un `ZMarkdownReader` dont le `chrome` par défaut est `bordered` — cadre **et** padding — à
l'intérieur d'un tableau qui dessine déjà sa grille : deux bordures concentriques, lignes désalignées,
et une incohérence dans le même tableau (les cellules en texte pur restent nues). `ZTableCell` est
interne : la correction ne peut venir que du socle.

② **Une formule LaTeX bloc large déborde** (`RIGHT OVERFLOWED`) au lieu de défiler — la fin de la
formule est perdue. Le geste correct existe déjà dans l'aperçu du dialogue d'édition
(`SingleChildScrollView` horizontal) mais pas dans le lecteur.

## 2. Ce que le socle livre
- **①** `ZTableCell` rend le chemin riche avec `chrome: ZMarkdownReaderChrome.none` — aucun canal d'échappement (une cellule encadrée n'a pas de cas d'usage ; si un besoin émerge, il vivra sur `ZTableCellScope`, défaut `none`).
- **②** le rendu de lecture d'un bloc LaTeX défile horizontalement (le geste du dialogue appliqué au lecteur) ; `Align`/`Padding`/`blockScaleFactor` inchangés.
- **①×② mesuré ensemble** : une formule bloc dans une cellule `IntrinsicColumnWidth` se dimensionne sans exception, cellule nue — gardé.

## 3. Ce qui change pour un hôte
- **Passif** : rien à écrire — deux défauts de rendu corrigés. Un hôte qui **compensait** (échelle
  réduite via `blockScaleFactor` pour faire tenir une formule, ou habillage de cellule retiré à la
  main) retire sa compensation.
- **IFFD** : ses deux tripwires (`test/qa-w2/markdown_rendu_socle_test.dart`) rougissent et désignent
  les captures QA à refaire.

## 4. Vérification

Rejouée par l'orchestrateur, au repos : `zcrud_markdown` **589** (584 → +5, 22 s) ; `melos run generate` 0 `.g.dart` ; `melos run analyze` RC=0 ; `melos run verify` **RC=0** (douze gates) ; balayage des **41 paquets** : 40 verts, `zcrud_generator` rouge environnemental. Trois injections R3, trois rouges par assertion (dont un débordement de 2 140 px reproduit puis refermé), empreintes identiques, résidus zéro.
