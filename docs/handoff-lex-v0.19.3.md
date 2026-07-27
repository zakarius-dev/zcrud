# Handoff → session `lex_douane` · zcrud **v0.19.3** — CR-61, CR-62

> **Tag à épingler : `v0.19.3`**
> Petit lot. **Rien à changer chez vous** : les deux défauts préservent
> strictement le rendu actuel, et le golden est inchangé.

| CR | État |
|---|---|
| **CR-61** — la bordure du `CardTheme` de l'hôte est inexprimable | ✅ **LIVRÉE** |
| **CR-62** — carte et badge « Archivé » partagent le même rayon | ✅ **LIVRÉE** |

Merci pour la façon dont vous les avez remontées : vous avez **adopté**
`ZFolderCard` malgré les deux écarts, en les qualifiant de bénins et en
**documentant le décalage dans votre pont plutôt qu'en le masquant**. C'est la
première adoption confirmée d'un widget de l'epic SUF, et l'écart assumé par
écrit vaut mieux qu'un contournement invisible.

---

## 1. CR-61 — votre option (2) retenue

`ZFolderCard` **lit** désormais le `shape` de votre `CardTheme` quand vous en
fournissez un, au lieu de le reconstruire par-dessus :

```dart
Theme(
  data: theme.copyWith(
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.borderLight, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  ),
  child: ZFolderCard(title: …, colorKey: …),
);
```

**Pourquoi (2) plutôt que (1)** : un `BorderSide? side` vous aurait rendu la
bordure, mais le widget aurait continué d'imposer *son* rayon — vous auriez eu à
déclarer deux fois la même décision. Lire le `CardTheme` respecte la vôtre en
entier (rayon **et** bordure) et supprime la source de divergence.

⚠️ Point d'implémentation qui vous concerne : le même objet `shape` sert à
`Card.shape` **et** à `InkWell.customBorder`. Contour et effet d'encre ne peuvent
donc pas diverger — y compris quand c'est votre `CardTheme` qui pilote.

**Aucune API publique ajoutée.** Si vous ne définissez pas de `CardTheme.shape`,
le rendu est identique à `v0.19.2`.

---

## 2. CR-62 — `badgeRadius`, avec le défaut qui ne bouge rien

```dart
ZcrudTheme(radiusM: Radius.circular(16), badgeRadius: Radius.circular(6))
```

`Radius? badgeRadius` sur `ZcrudTheme`, **défaut `null` ⇒ retombe sur `radiusM`**.
Vous pouvez donc rétablir le rayon du badge sans toucher à celui de la carte —
l'arbitrage que vous aviez dû faire (« carte visuellement dominante, décalage du
badge accepté ») n'est plus nécessaire.

🔵 **`radiusS` a été écarté**, alors que vous le proposiez en alternative : sa
valeur par défaut est `4` là où `radiusM` vaut `8`. L'utiliser aurait changé le
rendu par défaut de tous les badges existants — exactement ce que votre CR
interdisait.

---

## 3. Un défaut que nous avons trouvé en vérifiant, et qui vous aurait mordus tard

Le premier jet interpolait `badgeRadius` via `badgeRadius ?? radiusM` des deux
côtés dans `ZcrudTheme.lerp`. Mesuré par sonde : un `lerp` de deux thèmes **par
défaut** rendait `Radius.circular(8.0)` **au lieu de `null`**.

Conséquence, et c'est ce qui la rendait vicieuse : l'héritage déclaré
(« `badgeRadius` nul ⇒ suit `radiusM` ») était **gelé dès la première transition
de thème** — or Flutter interpole à chaque changement. Le rendu immédiat restait
identique ; la divergence ne serait apparue qu'au changement **suivant** de
`radiusM`, très loin de sa cause, et aurait ressemblé à un bug de votre côté.

Corrigé : `null` des deux côtés reste `null`. Si vous laissez `badgeRadius` à
`null`, votre badge suit `radiusM` **durablement**, y compris à travers les
animations de thème.

---

## 4. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (11 gates) · `graph_proof`
**ACYCLIQUE + CORE OUT=0** · `zcrud_core` **1078** · `zcrud_study` **633** ·
**golden inchangé** (preuve que les deux défauts sont réellement neutres).

Gardes prouvées mordantes : neutraliser la lecture de `CardTheme.shape` rend le
test rouge ; un `badgeRadius` à 16 au lieu de 8 aussi.
