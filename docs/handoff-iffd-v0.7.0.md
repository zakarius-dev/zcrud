# Handoff → session `IFFD` · zcrud **v0.7.0** — réponse à CR-IFFD-23 et CR-IFFD-24

> **Tag à épingler : `v0.7.0`**

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-23 §1 — Delta sérialisé en chaîne | majeur | ✅ **LIVRÉE** |
| CR-IFFD-23 §2 — sur-échappement | majeur | ✅ **LIVRÉE** |
| CR-IFFD-23 §3 / CR-IFFD-24 §2 — pont Markdown ↔ embed | majeur | ✅ **LIVRÉE** (opt-in) — **sauf le pont TABLEAU**, cf. §6 |
| CR-IFFD-24 §1 — asymétrie `encode`/`decode` | majeur | ✅ **LIVRÉE** — image, h4–h6, barré, cases à cocher |
| CR-IFFD-24 §3 — espaces dans les marqueurs | mineur | ✅ **LIVRÉE** |

---

## 1. Vos deux CR étaient exactes. Le banc de mesure l'a confirmé ligne par ligne

Nous n'avons rien pris pour acquis : cinq agents ont **mesuré par exécution** chaque cellule de
votre matrice avant qu'une ligne de code ne soit écrite. Verdict : **exacte sur 9 lignes sur 9**,
et sur trois points **vous étiez en dessous de la réalité** :

- **L'image ne dégradait pas, elle DÉTRUISAIT en un seul cycle.** `URL_PRESENTE_DANS_MD_1 : false`
  — l'adresse n'était conservée nulle part, ni en `alt`, ni en commentaire, ni dans le
  placeholder. Irrécupérable.
- **La case à cocher ne « disparaissait » pas seulement** : le marqueur `[x]` était **réinjecté
  dans le texte** de la puce (`"insert":"[x] fait"`). Le contenu se polluait à chaque cycle.
- **Un Delta sérialisé ne perdait pas « le rendu »** : il perdait **tout le document** — gras,
  embeds, structure, aplatis en une seule op de texte. La perte n'était pas bornée, contrairement
  à ce que le docstring garantissait.

**Votre remarque sur la table des pertes était juste, et il y avait pire.** La ligne « Barré —
conservé si l'app émet `~~` » était fausse **sans condition de sauvetage** (mesuré `false` sur les
deux lectures possibles). Mais la table annonçait aussi « titres **H1–H6** » alors que H4–H6
étaient écrasés, et **omettait trois pertes réelles** : exposant/indice, cases à cocher, et
l'embed image lui-même. Le groupe de tests intitulé « assertion EXPLICITE de chaque perte » n'en
couvrait que **2 sur 8**.

C'est la **neuvième** affirmation de cette série écrite sans avoir été exécutée.

---

## 2. Ce qui est corrigé, et ce qui a été refusé au passage

```dart
// Rien à faire : le défaut du codec corrige tout ceci.
const codec = ZMarkdownCodec();
```

| Capacité | v0.6.0 | v0.7.0 |
|---|---|---|
| Image | `[embed:image]`, URL perdue | `![](src)` — **survit** |
| Séparateur `---` | `[embed:divider]` | `- - -` — **survit** *(trouvé en revue, cf. §4)* |
| Vidéo | `[embed:video]`, source perdue | lien `[src](src)` — **la source survit** |
| Titres H4–H6 | texte nu | `{header: 4..6}` |
| Barré `~~x~~` | tildes littérales | `{strike: true}` |
| Cases à cocher | `bullet` + `[x]` dans le texte | `{list: checked/unchecked}` |
| Exposant / indice | avalés en silence | `<sup>`/`<sub>`, conservés |
| `Qu'est-ce que…` | `Qu'est\-ce que…` | intact |
| Delta JSON en `String` | affiché littéralement | décodé |

### 🚫 Le « correctif d'une ligne » a été refusé

Le rapport de mesure recommandait `ExtensionSet.gitHubFlavored`, qui règle barré **et** cases à
cocher d'un coup. **Mesuré : il aplatit une table Markdown en `ab12`** — séparateurs et structure
détruits, là où elle survit aujourd'hui en texte littéral. C'était **échanger une perte contre une
destruction**. Le jeu de syntaxes livré est un **surensemble strict** du défaut `commonMark`, sans
`TableSyntax`, sans autolink : rien de ce qui fonctionnait ne peut régresser de ce fait.

### Ce qui reste une perte, assumée

Un tableau Markdown reste **du texte littéral** (il n'est pas agrégé en tableau) ; une vidéo
dégrade en lien ; une entité HTML littérale (`&amp;`) est **résolue** en son caractère. Ces trois
lignes sont désormais **dans** la table des pertes, et **les 8 lignes de cette table sont
assertées par exécution** — plus 2 sur 8.

---

## 3. Le pont Markdown ↔ embed — et pourquoi il n'est PAS un satellite

Votre §4 proposait un satellite opt-in, par lecture d'AD-57. **Nous avons divergé, et voici le
motif — vérifié en revue, pas supposé** : `flutter_math_fork` est **déjà** au pubspec de
`zcrud_markdown` depuis E6-3, pour le RENDU des formules. Un satellite n'aurait donc isolé
**aucune** dépendance ; il n'aurait ajouté que de la cérémonie. Le pont n'ajoute **zéro**
dépendance (`git status` sur les pubspec est vide).

Ce qui compte dans AD-57 — le **défaut zéro-extension** — est tenu :

```dart
const ZMarkdownCodec();                                  // rien ne change
ZMarkdownCodec(bridges: ZMarkdownBridges.latex);         // $…$, $$…$$, \(…\), \[…\], \ce{}
ZMarkdownCodec(bridges: [                                // votre propre syntaxe
  ZMarkdownEmbedBridge(
    embedType: 'mention',
    pattern: RegExp(r'@\{([^}]+)\}'),
    toMarkdown: (data) => '@{$data}',
    escapedCharacters: {'@'},   // « échapper ce que le décodeur sait relire »
  ),
]);
```

> ⚠️ **Votre préoccupation de fond reste vraie et non traitée** : tout consommateur de
> `zcrud_markdown` paie `flutter_math_fork` depuis E6-3. Le chantier qui la fermerait est de
> sortir le **RENDU**, pas les ponts. Dites-nous s'il compte pour vous.

---

## 4. Ce que la revue adversariale a trouvé, et que nous n'avions pas vu

Cinq lentilles ont attaqué notre propre livraison. Elles ont trouvé **des destructions que notre
première version introduisait** — toutes corrigées avant ce tag, toutes gardées par un test :

| Trouvaille | Ce qui se passait |
|---|---|
| 🔴 `1) premier` → `premier` | CommonMark accepte `)` comme délimiteur de liste ; notre échappement contextuel l'avait perdu de vue. **La numérotation `1)` est la forme usuelle en français administratif.** |
| 🔴 `H~2~O` → `H2O` | `StrikethroughSyntax` déclare `DelimiterTag('del', 1)` : **un tilde SIMPLE suffit à barrer**. Un corpus scientifique ou tarifaire aurait été muté irréversiblement. Restreint au tilde double. |
| 🔴 `---` détruit | **le jumeau exact de l'image** — mêmes deux moitiés déjà présentes dans la lib, neutralisées au même endroit. |
| 🔴 prix `5$ … 9$` | avec le pont LaTeX actif, un prix devenait une formule. Nous avions posé la règle « échapper ce que le décodeur sait relire » pour `~`, puis l'avions oubliée pour les ponts. |
| 🔴 `<u>` non fermé | soulignait **tous les paragraphes suivants**. L'état est maintenant borné au bloc. |
| `12.05.2024` | restait échappé `12\.05.2024` — sur-échappement résiduel, alors que CommonMark exige une espace après le délimiteur. |

**Deux de ces trouvailles nous retournent nos propres arguments, à juste titre.** Nous avons refusé
`gitHubFlavored` parce qu'il mutait le contenu — puis activé `StrikethroughSyntax`, *qui mute le
contenu par la même mécanique*. Et nous avons corrigé l'image en écrivant que « le pont existait
des deux côtés, il était neutralisé en amont » — en laissant le `divider` dans exactement cette
situation, à deux lignes de là. **Corriger un cas sans chercher ses jumeaux, c'est traiter un
symptôme.**

---

## 5. Deux défauts trouvés HORS CR, corrigés au passage

1. **`[ref]: http://exemple.test` VIDAIT le document.** Une définition de lien de référence est
   une syntaxe Markdown standard, consommée comme métadonnée : le parseur ne rendait aucun nœud.
   Un texte non vide ne produit désormais **jamais** un document vide.
2. **`ZDeltaCodec` tolérait déjà** la chaîne JSON que `ZMarkdownCodec` corrompait. Le même corpus
   legacy était donc lu correctement par un codec du paquet et détruit par l'autre.

---

## 6. ⚠️ Limites déclarées — ne les découvrez pas à l'usage

1. **Le pont TABLEAU n'est PAS livré.** La couture est **inline** ; un tableau Markdown est un
   bloc multi-ligne et exige une seconde mécanique (plus la conversion vers la charge structurée
   `{rows, columns, cells}` de notre embed). Votre §2 le demande ; votre §5 mesure **0 tableau**
   sur ~11 400 valeurs. Nous avons préféré le déclarer que le livrer à moitié testé.
2. **`<sup>`/`<sub>` littéraux tapés par un utilisateur** sont absorbés comme attributs. La
   LIMITE MIN-1 existait pour `<u>` ; nous l'avons **étendue**. `H<sub>2</sub>O` écrit en toutes
   lettres perd ses balises — un cas moins marginal que `<u>`. Dites-nous s'il compte.
3. **Une formule LaTeX MULTI-LIGNE** n'est pas reconnue (les motifs de pont sont bornés à la ligne).
4. **`<u>` dans un bloc de code** est encore absorbé — l'absorbeur ne teste pas le contexte de code.
5. **Une chaîne littérale `[{"insert":"x"}]`** tapée par un utilisateur est interprétée comme un
   Delta. Ambiguïté irréductible de toute règle de détection ; la nôtre a **0 faux positif** sur
   un corpus piège de 10 entrées, mais celle-ci est indécidable.
6. **Exposant/indice ne sont pas exprimables en Markdown standard** : ils passent par `<sup>`/`<sub>`,
   comme le souligné passe par `<u>`.

---

## 7. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 · `zcrud_markdown` **361/361** ·
`zcrud_core` **1063/1063** · `zcrud_study` **540/540**.

**Gardes R3 rejouées par l'orchestrateur** (régression réinjectée → test rouge → restauré) :
**19 gardes**, toutes mordantes — préservation de l'image et du divider, mapping h4–h6, syntaxe du
barré, tilde double, cases à cocher, détection du Delta sérialisé, échappement contextuel,
délimiteur `)`, espace exigée après délimiteur, sortie des espaces hors marqueurs, marqueurs
`<sup>`/`<sub>`, échappement du `~`, échappement conscient des ponts, priorité du premier pont,
syntaxes de pont, mapping élément→embed, handlers d'encodage, types exprimables, repli
« document non vide ».

Une garde ne mord PAS, et c'est **normal** : les 4 assertions de perte ajoutées (police, taille,
fond, alignement) ne rougissent que si la perte cesse. Elles documentent par exécution plutôt
qu'elles ne gardent — c'est écrit dans le test, pas passé sous silence.

---

## 8. Ce que vos vingt-quatre CR auront produit

Neuf affirmations que nous avions écrites **sans les vérifier** ont été corrigées. Et cette
livraison-ci a failli en ajouter six de plus : c'est notre propre revue adversariale qui les a
trouvées, pas vous — **et c'est la première fois de la série.** Le dispositif que vos CR nous ont
imposé commence à attraper nos erreurs avant qu'elles ne vous atteignent.

Le motif ne varie pas : **ce qui n'a pas été exécuté n'est pas su.**
