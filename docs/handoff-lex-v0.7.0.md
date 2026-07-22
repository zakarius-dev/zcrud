# Handoff → session `lex_douane` · zcrud **v0.7.0** — parité Markdown

> **Tag à épingler : `v0.7.0`**
> **Aucune CR lex ouverte.** Ce tag corrige des pertes de données sur la persistance Markdown.
> Si vous persistez du rich-text en Markdown, **lisez le §1** — il concerne vos données.

---

## 1. ⚠️ Si vous utilisez `ZMarkdownCodec`, vous perdiez des données

Quatre pertes mesurées, toutes corrigées, **aucune action requise de votre part** (le défaut du
codec les corrige) :

| Contenu | v0.6.0 | v0.7.0 |
|---|---|---|
| **Image** | détruite au **premier** enregistrement, **URL comprise** | `![](src)` — survit |
| Séparateur `---` | `[embed:divider]` | `- - -` — survit |
| Titres **H4–H6** | ramenés en texte nu | conservés |
| **Barré** `~~x~~` | tildes affichées littéralement | conservé |
| **Cases à cocher** | `[x]` réinjecté **dans le texte** de la puce | conservées |

Le cas de l'image est le plus grave : `encode` remplaçait l'embed par un placeholder **sans
conserver l'adresse nulle part**. Un utilisateur insérait une image, enregistrait, rouvrait — elle
avait disparu, irrécupérablement.

**Si vous avez un corpus déjà persisté en Markdown par la v0.6.0**, les images qu'il contenait
sont perdues et ce tag ne les restaure pas — il empêche la prochaine perte.

---

## 2. Un corpus Quill legacy est maintenant lisible

`ZMarkdownCodec.decode` tolère désormais un Delta stocké sous la forme
`jsonEncode(document.toDelta().toJson())` — c'est-à-dire une **`String`**, la forme réelle en base.
Elle était auparavant interprétée comme du Markdown et **affichée littéralement**
(`[{"insert":"…"}]` à l'écran), en perdant tout le document.

La règle de détection est délibérément étroite : **0 faux positif** mesuré sur un corpus piège de
10 entrées (`[Un lien](url)`, `[1, 2, 3]`, `[]`, `- [x] fait`, JSON tronqué…). Une détection naïve
par `jsonDecode` aurait **vidé** des documents Markdown parfaitement légitimes.

---

## 3. Le Markdown persisté est nettement plus lisible

L'échappement était **position-aveugle** : 18 caractères échappés partout, d'où
`Qu'est\-ce que la valeur en douane ?`. Il est désormais **contextuel** — les ouvreurs de bloc ne
sont échappés qu'en tête de ligne, et seulement quand ils ouvrent réellement un bloc.

```
avant : Qu'est\-ce que la valeur en douane ?   ·   a\-b\-c\. 1\. un   ·   12\.05.2024
après : Qu'est-ce que la valeur en douane ?    ·   a-b-c. 1. un      ·   12.05.2024
```

Cela compte si vous alimentez une chaîne IA depuis ces champs : un corpus criblé de `\` dessert
exactement l'objectif de la persistance Markdown.

---

## 4. Nouveau : ponter votre propre syntaxe vers un embed (opt-in)

```dart
ZMarkdownCodec(bridges: ZMarkdownBridges.latex)   // $…$, $$…$$, \(…\), \[…\], \ce{}, \pu{}
```

Un embed était un **aller simple** : on insérait une formule, on enregistrait, on rouvrait — on
trouvait `[embed:latex]`. Vous pouvez aussi déclarer vos propres syntaxes
(`ZMarkdownEmbedBridge`) — utile si vous portez des références d'articles ou des renvois normatifs
dans du texte riche.

**Le défaut ne change pas** : sans déclaration, le comportement est exactement celui d'avant.

---

## 5. ⚠️ Six limites, déclarées

1. **Le pont TABLEAU n'est pas livré** — la couture est inline ; un tableau est un bloc multi-ligne.
2. Un **tableau Markdown reste du texte littéral** (choix délibéré : l'agréger via GFM le mutilait
   en `ab12` — mesuré).
3. `<sup>`/`<sub>` **littéraux** tapés par un utilisateur sont absorbés comme attributs.
4. Une formule LaTeX **multi-ligne** n'est pas reconnue.
5. `<u>` dans un **bloc de code** est encore absorbé.
6. Une chaîne littérale `[{"insert":"x"}]` est interprétée comme un Delta — ambiguïté irréductible.

---

## 6. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 · `zcrud_markdown` **361/361** ·
`zcrud_core` **1063/1063** · `zcrud_study` **540/540**. **19 gardes R3** prouvées mordantes.

---

## 7. Si vous voyez une affirmation invérifiable, dites-le

Neuf affirmations écrites de notre côté sans avoir été exécutées ont été corrigées par les CR
d'IFFD — dont, sur ce tag, une table des pertes qui promettait « titres H1–H6 » et « barré
conservé » alors que ni l'un ni l'autre n'était vrai, et qu'aucun test n'exécutait.

Nouveauté de ce tag : **six défauts supplémentaires ont été trouvés par notre propre revue
adversariale**, avant livraison, et non par un consommateur. C'est la première fois de la série.
Le réflexe de nous le prouver par exécution reste néanmoins ce qui marche le mieux.
