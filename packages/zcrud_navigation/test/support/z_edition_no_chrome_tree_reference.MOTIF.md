# Motifs de réalignement de `z_edition_no_chrome_tree_reference.txt`

Cet étalon épingle l'arbre rendu par `presentEdition(chrome: null)` pour les
trois modes. **Il ne se recale JAMAIS « parce qu'il est rouge »** : chaque
réalignement porte ici sa date, sa cause, et le diff exact constaté.

---

## 2026-08-09 — CR-IFFD-SHEET (feuille contrainte et encadrée)

**Décision propriétaire** : la bottom-sheet du socle n'occupe plus toute la
largeur de l'écran et porte un cadre, **par défaut**. C'est donc un changement
de rendu **voulu**, visible pour tout hôte passif.

**Preuve que l'étalon rougissait pour la BONNE raison** — `diff` de l'étalon
d'avant contre l'arbre réel, avant recalage : **exactement 2 lignes, toutes deux
dans la section `=== sheet ===`**, aucune ligne des sections `dialog` et `page` :

```
208c208
<   BottomSheet
---
>   BottomSheet shape=RoundedRectangleBorder(BorderSide(color: Color(alpha: 1.0000,
>     red: 0.7922, green: 0.7686, blue: 0.8157, colorSpace: ColorSpace.sRGB)),
>     BorderRadius.only(topLeft: Radius.circular(28.0), topRight: Radius.circular(28.0)))
213c213
<   ConstrainedBox c=BoxConstraints(0.0<=w<=Infinity, 0.0<=h<=720.0)
---
>   ConstrainedBox c=BoxConstraints(0.0<=w<=360.0,      0.0<=h<=720.0)
```

* **l. 213** — la largeur passe de `Infinity` à `360.0` sur l'écran de 400 dp du
  montage : `min(400 × 0,9 ; 640) = 360`. C'est **la** marge demandée.
* **l. 208** — la `shape` du `BottomSheet` porte désormais un `BorderSide` : le
  cadre. La couleur relevée est le rôle `ColorScheme.outlineVariant` du thème
  `MaterialApp` par défaut du montage — **résolue**, jamais écrite en dur (cf.
  `lib/src/presentation/z_sheet_frame.dart`, qui ne contient aucune couleur).
  Le rayon `28` est celui du thème ambiant : la CR **ajoute un côté** à la forme
  ambiante, elle ne la remplace pas.

**Le sérialiseur a été étendu au même moment** (`z_edition_tree_serializer.dart`,
ligne `if (w is BottomSheet) line.write(' shape=…')`). Sans cette extension,
l'étalon aurait été **aveugle au cadre** : la bordure aurait pu disparaître sans
qu'ID-1 ne rougisse. C'est cette ligne qui rend la l. 208 observable.

**Ce qui n'a PAS bougé** : les sections `dialog` (700 dp) et `page` (1000 dp,
heavy) sont **identiques au caractère près**. La CR ne touche que la branche
`sheet`.
