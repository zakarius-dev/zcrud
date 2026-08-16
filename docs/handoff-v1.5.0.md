# Handoff **v1.5.0** — l'encadré appartient à la fiche, plus à la forme

> **Tag à épingler : `v1.5.0`** — traite le CR « quatre formes de consultation sur cinq ne peuvent
> pas être encadrées ». Paquet porteur : **`zcrud_core`**.
>
> ⚠️ **Rupture ciblée** : un hôte qui déclarait déjà `readFillColor` ou `readBorderWidth` **et**
> employait une forme dense verra apparaître un encadré qu'il n'avait pas — §4.

---

## 1. Le défaut, et pourquoi votre mesure était la bonne méthode

Vous avez échantillonné les pixels plutôt que d'en juger à l'œil, *« précisément parce qu'un fond
`grey.shade50` sur un fond d'écran `#ECEFF1` est une différence qu'un regard peut manquer »*.
C'était la bonne décision : à l'œil, ce CR n'aurait pas été écrit, et l'écart serait resté.

Le constat est exact. `readFillColor` / `readBorderColor` / `readBorderWidth` n'étaient lus qu'à
**un seul endroit**, le conteneur de la forme `card`. Déclarés ailleurs, ils étaient posés,
valides, lus — et sans effet.

**La faute de documentation est de notre côté**, et elle est la cause directe de votre méprise :
la dartdoc de `readFillColor` restreignait à `card`, celles de `readBorderColor` et
`readBorderWidth` ne restreignaient rien, et le handoff v1.4.0 donnait le remède en une ligne
sans dire dans quelle forme il valait. Les quatre textes sont corrigés.

## 2. Ce qui change

Le fond et le filet sont appliqués **au niveau de l'aiguillage**, donc aux **cinq** formes. Ils ne
sont pas recopiés : `card` et les quatre autres partagent littéralement le même fond et le même
contour, si bien que déclarer les jetons donne le **même** encadré partout.

**Ce que l'encadré n'emprunte pas** : ni `readCardMinHeight` (72), ni le bouton de copie. Les
hauteurs des formes denses — 54 / 36 / 28 — **ne bougent pas** en s'encadrant, et c'est gardé.

**Le défaut reste strictement inchangé**, comme vous le demandiez au §5 : rien n'est monté tant
qu'il n'y a rien à peindre. Deux déclencheurs, et deux seulement :

| Déclaré | Conteneur |
|---|---|
| `readFillColor`, quelle que soit sa transparence | **oui** — c'est une déclaration d'intention, on la sert |
| `readBorderWidth` > 0 | **oui** |
| `readBorderColor` **seul** | **non** — sans largeur, `BorderSide.none` : le conteneur ne peindrait rien |

## 3. 🔴 Un point où votre CR se trompe — et où votre propre recette l'aurait attrapé

Vous écrivez que *« les quatre autres formes passent par `_dense` »*. **C'est faux** : `listTile`
a sa propre branche. Le remède que vous proposiez — envelopper l'enfant de `_dense` — aurait donc
laissé `listTile` sans encadré, et **échoué à votre critère de recette n°3**, celui qui exige le
filet *dans les cinq formes*.

Nous l'avons câblé à l'aiguillage pour cette raison, et l'injection qui reproduit exactement votre
erreur fait rougir la garde. Le signalement était juste ; la cause supposée ne l'était qu'aux
trois quarts.

## 4. Impact sur votre code

- **Hôte passif** : rien à faire. Sans jeton déclaré, les cinq formes rendent à l'octet ce
  qu'elles rendaient en 1.4.1.
- **Hôte ayant déclaré les jetons au thème** — le cas de rupture : si vous posiez `readFillColor`
  ou `readBorderWidth` globalement *et* employiez `definition`, `inlineRow`, `compact` ou
  `listTile`, ces fiches **s'encadrent maintenant**. C'est la correction demandée ; si vous ne la
  vouliez pas là, portez le jeton sur la surface concernée plutôt que sur le thème.
- **DODLP, hôte ayant COMPENSÉ** : votre contournement du §3 prend `card` puis en **défait** la
  hiérarchie par quatre jetons — et ces quatre jetons portent sur **toutes** les formes. Si vous
  basculez sur `definition` sans les retirer, vous obtiendrez la typographie de votre
  contournement, pas celle de `definition`. Le geste correct est :

  ```dart
  readLayout: ZReadFieldLayout.definition,
  readFillColor: …, readBorderWidth: 1,
  // et SUPPRIMER readLabelTextStyle / readValueTextStyle / readPadding / readLabelGap
  ```

  Effet de bord favorable : l'écart que vous signaliez au §6 — le bouton de copie visible, absent
  du legacy — **disparaît de lui-même**, `definition` ne l'affichant pas et gardant l'appui long.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `zcrud_core` analyze RC=0, **2191** tests (baseline 2166, +25).

Votre critère n°1 est gardé **au pixel réel** (`RenderRepaintBoundary.toImage`), pas sur la
couleur passée au conteneur — mesurer le jeton d'entrée aurait été une tautologie. Le rouge
initial reproduit votre tableau **chiffre pour chiffre** : attendu `(250,250,250)`, obtenu
`(236,239,241)`.

Cinq injections R3, toutes rouges **par assertion**. Deux méritent d'être citées : l'enrobage
rendu inconditionnel fait rougir **onze** gardes, dont les quatre de cohérence inter-familles
livrées en v1.4.0 ; et l'oubli de `listTile` à l'aiguillage — l'erreur exacte du §4 de votre CR —
rougit avec `listTile : le fond déclaré n'est pas peint`.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
