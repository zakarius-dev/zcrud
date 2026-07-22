# Handoff → sessions `IFFD` **et** `lex_douane` · zcrud **v0.8.0** — le tableau ne se perd plus

> **Tag à épingler : `v0.8.0`**
> Un seul document pour les deux sessions : le changement est identique des deux côtés et ne
> répond à aucune CR spécifique.

---

## 1. 🔴 Correction d'une affirmation du handoff `v0.7.0`

Le §6 de `handoff-iffd-v0.7.0.md` rangeait le pont tableau dans les « limites déclarées ».
**C'était une qualification fausse.** Mesuré :

```
encode(embed tableau) = "avant \[embed:table\] après"
  contient "Bénin" ? false     contient "20 %" ? false
```

Un tableau créé dans l'éditeur et persisté en Markdown perdait **toutes ses cellules au premier
enregistrement**. Ce n'était pas une dégradation documentée, c'était **la même destruction que
celle de l'image** — celle que CR-IFFD-24 §1 qualifie de « perte la plus grave, parce qu'elle
DÉTRUIT ». Elle est corrigée.

---

## 2. Ce qui est livré

Rien à faire de votre côté : `const ZMarkdownCodec()` suffit.

| Sens | Comportement |
|---|---|
| **encode** | tableau GFM lisible (`\| Pays \| Taux \|`) quand ce rendu **se relit à l'identique**, bloc clôturé ```` ```zcrud-table ```` portant la charge JSON exacte sinon |
| **decode** | un tableau Markdown bien formé devient un embed tableau rendu |

**La garantie de fidélité s'EXÉCUTE, elle ne se raisonne pas** : à chaque tableau écrit, le rendu
est relu immédiatement et comparé à la matrice source. Identique → forme lisible. Différent →
repli sans perte. Une relecture par sauvegarde, ce qui transforme « sept cas testés » en
« vérifié sur le tableau réel ».

Corpus vérifié fidèle : ordinaire, cellule contenant `|`, cellule multi-ligne, cellules vides,
une seule colonne, RTL + emoji, `---` dans une cellule, ligne unique, tableau inline, LaTeX en
cellule. **Stable sur trois cycles.**

### ⚠️ Changement de contrat

Un tableau Markdown **n'est plus du texte inerte** : il devient un embed rendu. Deux tests
préexistants ont dû être mis à jour, dont un qui **verrouillait la destruction** (`E6-4 … jamais
ressuscité`). Un test peut figer un défaut aussi solidement qu'une capacité — celui-ci l'a fait
pendant sept versions.

---

## 3. Le piège qui rendait le correctif « évident » catastrophique

```
charge GELÉE  : THROW -> UnmodifiableMapView<Object?, Object?> is not a subtype of Map<String, dynamic>
charge dégelée: OK
```

`zTableEmbedOp` gèle sa charge en profondeur ; `Document.fromDelta` la caste et **lève** ; le filet
AD-10 attrape et persiste `''`. Ajouter naïvement `'table'` aux types natifs n'aurait pas dégradé
le tableau — cela aurait **vidé le document entier**. Les charges préservées sont désormais
dégelées avant conversion, et une garde le verrouille.

---

## 4. Deux choses trouvées EN MESURANT, pas en raisonnant

1. **`EmbeddableTableSyntax` de `markdown_quill` a été écartée.** Elle ne reconnaît pas une cellule
   contenant un `|` échappé — or c'est exactement ce que notre encodeur produit. Un parseur
   incapable de relire notre propre écriture rouvrait l'asymétrie que CR-IFFD-24 dénonce. Les deux
   moitiés sont donc écrites face à face, symétriques par construction.
2. **🔴 Une régression que le pont introduisait, corrigée avant livraison** : un `|` NON échappé
   dans une cellule d'un tableau écrit à la main — typiquement `$\left| x \right|$` — était lu
   comme un séparateur et **découpait la ligne** (4 colonnes au lieu de 2). GFM est normatif :
   en-tête et délimiteur doivent avoir le même nombre de colonnes. Un bloc qui ne le respecte pas
   reste **du texte intact**. Refuser de structurer vaut mieux que structurer de travers — c'est
   ce qui avait fait écarter `gitHubFlavored`.

---

## 5. ⚠️ Limites déclarées

1. **Une cellule ne porte que du TEXTE.** La charge de l'embed est `List<List<String>>`. Du LaTeX
   écrit dans une cellule **survit intégralement** au round-trip (`\ce{}`, `\pu{}`, `|` interne),
   mais reste du **texte** : il n'est pas rendu comme formule. C'est une limite de **modèle**, pas
   de codec — la fermer suppose des cellules en rich-text et un rendu récursif.
2. **L'alignement** d'un tableau externe (`|:--|--:|`) est perdu : la charge ne le porte pas.
3. **Un tableau INLINE devient un bloc à part.** Un tableau Markdown occupe forcément son propre
   bloc ; écrit au milieu d'une ligne il ne serait pas relu. La mise en page bouge, le contenu est
   intégralement préservé.
4. **Un `<br>` littéral** dans une cellule déclenche le repli (et survit) — sans quoi il serait
   relu comme un saut de ligne.
5. **Pas d'en-tête distinct** : la première ligne fait office d'en-tête, seule forme qu'un tableau
   GFM admet.

---

## 6. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 · `zcrud_markdown` **386/386** ·
`zcrud_core` **1063/1063** · `zcrud_study` **540/540**.

**10 gardes R3 prouvées mordantes** sur le seul pont tableau. Une onzième — l'échappement du `|`
en cellule — ne mord **pas** sur la fidélité, et c'est instructif : l'auto-vérification la
rattrape en basculant sur le repli. L'échappement n'est donc pas une exigence de **correction**
mais de **lisibilité**, et c'est cette propriété-là qui est assertée. Le dire plutôt que de
compter une garde de plus.
