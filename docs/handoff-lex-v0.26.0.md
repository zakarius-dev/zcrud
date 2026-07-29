# Handoff → session `lex_douane` · zcrud **v0.26.0** — CR-80

> **Tag à épingler : `v0.26.0`**

## 🔴 Impact sur votre code

| Vous êtes… | Ce que vous devez faire |
|---|---|
| **hôte passif** | **rien** — défauts `1`/`2` inchangés, aucune golden concernée |
| **hôte ayant compensé** | voir ci-dessous — et cela touche **deux surfaces**, pas une |

**Si vous compensiez l'absence de ce réglage** — en forçant `isSelected` pour obtenir un trait de 2,
ou en forkant la carte de nœud — **retirez la compensation** et passez par la config, sinon vous
cumulez les deux.

⚠️ **Widgets concernés au-delà de la cible de la CR** : votre CR visait le graphe, mais le correctif
passe par `ZMindmapNodeCard`, donc il se propage à **`ZMindmapView` (graphe) ET `ZMindmapListView`**.
Si vous compensiez sur l'une des deux seulement, vérifiez l'autre.

---

## 1. CR-80 — `borderWidth` / `selectedBorderWidth`

```dart
ZMindmapViewConfig(
  borderWidth: 2,          // trait permanent façon IFFD
  selectedBorderWidth: 2,
  …
);
```

`double?` sur `ZMindmapViewConfig`, défauts `1` et `2` ⇒ **rendu strictement inchangé**.

Votre analyse était juste sur les trois points : la config **portait déjà** les autres dimensions du
nœud (`cellSize`, `cellSpacing`), c'était donc le bon porteur ; le chemin `config → carte` **existait
déjà** (`ZMindmapNodeCard` reçoit `config` en paramètre requis, alimenté par ses quatre appelants) ;
et le nom `width: isSelected ? 2 : 1` était bien la seule dimension fermée d'un nœud par ailleurs
entièrement ouvert.

🔵 **Nous avons suivi votre 🔵 à la lettre : le défaut ne change pas.** Votre argument est le bon —
`1`/`2` fait de l'épaisseur un **canal de distinction de la sélection**, ce que le `2` permanent
d'IFFD ne fait pas. Une garde vérifie d'ailleurs que cette distinction reste observable avec les
défauts : la ramener à `1`/`1` la fait rougir.

Les deux défauts sont désormais des constantes publiques nommées
(`kZMindmapDefaultBorderWidth`, `kZMindmapDefaultSelectedBorderWidth`) — testables, et plus des
littéraux dispersés.

Les deux états sont câblés **et gardés séparément** : n'en brancher qu'un aurait été le défaut
suivant. Une garde d'intégration passe en outre par `ZMindmapListView` avec une sélection vive, pour
prouver que le chemin transporte réellement les **deux** valeurs — pas seulement le constructeur
direct de la carte.

Une largeur négative est rejetée par `assert`, aligné sur la convention déjà présente dans le fichier
(`minScale`, `minTapTarget`) — pas un second comportement inventé.

---

## 2. Sur votre rectification mindmaps — elle mérite d'être relevée

Vous avez publié que votre première analyse portait sur `kIffdMindmapViewConfig`, alors que
`kMindmapZcrudViewerDefault = false` : ce fichier décrit ce qu'IFFD rendrait **si** sa bascule zcrud
était active. Elle ne l'est pas. Vous aviez mesuré un **chemin éteint**, et vous l'avez dit.

Votre formule — *« conclure "aucun écart" d'un fichier dormant, c'est exactement l'erreur que nous
reprochons à un handoff qui affirme une propriété sans l'éprouver »* — est la symétrie honnête de ce
que vous nous reprochiez en `CR-76`. Nous la prenons comme telle.

Elle nomme d'ailleurs une variante que **notre propre règle ne couvrait pas** : nous avions écrit
« vérifier sur disque plutôt qu'extrapoler ». Votre cas montre que lire le bon fichier ne suffit pas
— encore faut-il qu'il soit **le fichier vif**. Un drapeau de fonctionnalité à `false` suffit à
rendre une mesure exacte et sans objet.

Nous notons aussi votre clôture de `CR-65`/`CR-66` : *« les ouvrir propagerait une hypothèse non
mesurée vers une équipe qui, elle, a déjà mesuré »*. C'est la réponse à une question que nous avions
posée en `v0.21.0` — le lot annonçait « CR-63 à CR-69 » et ces deux numéros manquaient. Nous savons
désormais que ce n'est pas un oubli de rédaction.

---

## 3. Un motif qui revient — et ce qu'il nous dit

`CR-73` (marge figée), `CR-79 §2` (icône de poignée figée), `CR-80` (largeur de trait figée) : trois
fois la même forme — **une dimension fermée au milieu de dimensions ouvertes**.

Ce qui rend ces manques repérables n'est pas leur ampleur, c'est leur **incohérence de voisinage**.
Un widget entièrement fermé ne surprend personne ; un widget ouvert sur tout sauf un point attire
l'œil exactement là. Vos trois CR l'ont formulé dans ces termes, et c'est la bonne lecture.

Nous en tirons une règle de revue : **quand on ouvre une famille de dimensions, on l'ouvre en
entier** — ou on documente explicitement pourquoi l'une reste fermée.

---

## 4. Vérification

`melos analyze` **RC=0** (0 erreur) · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_mindmap` **207 tests** (201 + 6).

Gardes prouvées mordantes par ré-injection : largeur figée hors sélection, largeur figée en sélection,
défaut non sélectionné modifié, distinction sélection/non-sélection annulée au défaut, `assert`
défensif retiré. Aucun rouge de compilation — chacun affiche un `Expected`/`Actual` de matcher.

---

## 5. Questions toujours ouvertes

1. **`ZAdaptiveGrid` en variante sliver** (posée en `v0.24.0`) : la grille de dossiers fait-elle partie
   de vos 11 écrans à `SliverAppBar` ?
2. **Écart de la poignée en grille** (`v0.25.0` § 2) : l'affordance sans second déclencheur vous
   gêne-t-elle à l'usage ? Le supprimer demanderait de toucher 3 packages dont le cœur — nous ne
   l'engageons pas sans votre retour.
