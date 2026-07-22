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

---

# Addendum v0.9.0 — mode « cellule = Markdown » (chemin hybride)

## 7. ⚠️ Deux limites du §5 étaient FAUSSES

Le §5 déclarait « une cellule ne porte que du TEXTE » et « inline seulement ».
**Les deux sont démenties par la mesure**, et je les avais écrites sans les exécuter.

Round-trip **20 cas sur 20 fidèles**, avec et sans pont : liste à puces, liste **imbriquée**,
liste ordonnée, cases à cocher, bloc de code (langage compris), citation, titre, **deux
paragraphes**, liste **avec formules**, et tout mélangé. Idem pour les blocs LaTeX `$$…$$`,
y compris **multi-ligne** et avec un `|` interne.

La raison est structurelle : **la chaîne d'une cellule est un document Markdown complet à elle
seule**, décodée pour son propre compte — pas de l'inline inséré dans le document extérieur.

Corollaire : la limite « LaTeX multi-ligne non reconnu » du handoff `v0.7.0` est elle aussi mal
énoncée. Mesuré, les motifs ne sont pas bornés à la **ligne** mais au **paragraphe** — seule une
ligne **blanche** casse la reconnaissance :

```
sauts SIMPLES                 -> reconnu = true
ligne BLANCHE au milieu       -> reconnu = false
ligne BLANCHE après ouverture -> reconnu = false
```

## 8. Ce qui est livré

```dart
ZTableCellScope(
  content: ZTableCellContent.markdown,                    // défaut : plainText
  codec: ZMarkdownCodec(bridges: ZMarkdownBridges.latex),  // porte les ponts
  child: monSousArbre,
)
```

**Le format persisté ne change pas d'un octet.** Ce mode change la LECTURE d'une cellule, pas son
stockage — donc rien à migrer, et la bascule est réversible dans les deux sens.

⚠️ **C'est un pont : le sens d'un texte ordinaire change.** Une cellule contenant `- a` devient une
puce, `*x*` de l'italique. Sur un corpus écrit à l'époque du texte brut, l'apparence peut bouger.
D'où l'opt-in, et le défaut `plainText` qui préserve exactement le rendu historique.

## 9. Chemin HYBRIDE — le coût suit la richesse, pas la taille

Le rendu riche passe par `ZMarkdownReader`, qui monte un `QuillEditor` complet. Un par cellule sur
un tableau 10×5 ferait **50 éditeurs Quill** — frontalement contraire à SM-1.

Une cellule qui décode en texte NU (aucun attribut, aucun embed, texte identique à la source) reste
un `Text`. **Garde mesurée : un tableau 10×5 de texte nu monte 0 éditeur ; une seule cellule riche
en monte 1.**

Piège traité : `- a` décode en un insert `a` **sans attribut** — l'attribut de liste est porté par
le saut de ligne. Un aiguillage naïf sur « aucun attribut » aurait affiché `a`, c'est-à-dire un
contenu **faux** plutôt qu'un contenu brut. D'où la comparaison au texte source.

## 10. 🔴 Défaut PRÉEXISTANT révélé, et corrigé

Une op construite par `zTableEmbedOp` et passée à `ZMarkdownReader`/`ZMarkdownField` **vidait le
document**. La charge gelée (`zUnmodifiableJsonMapList`) faisait lever `Document.fromJson`, le
filet AD-10 attrapait, et le contenu disparaissait — sans erreur visible, hors de tout tableau.
Mesuré : `document vide ? true`. Le dégel est désormais fait à la racine, dans
`DeltaNeutralOps.asDeltaOps`.

## 11. Ce qui reste ouvert

- **L'édition** : `showZTableDialog` édite du texte brut. En mode Markdown, l'utilisateur tape de la
  source. Acceptable en première étape — mais c'est une décision d'UX à prendre, pas à découvrir.
- **L'alignement** d'un tableau externe reste perdu (la charge ne le porte pas).
- Un `<br>` littéral en cellule déclenche toujours le repli sans perte.

## 12. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 · `zcrud_markdown` **407/407** ·
`zcrud_core` **1063/1063** · `zcrud_study` **540/540** · `zcrud_session` **529/529**.
**7 gardes R3** prouvées mordantes sur le mode cellule.
