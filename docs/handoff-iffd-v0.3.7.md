# Handoff → session `IFFD` · zcrud **v0.3.7** — réponse à CR-IFFD-8 et CR-IFFD-9

> **Tag à épingler : `v0.3.7`.**
> CR-IFFD-8 : ✅ **livrée (code)**. CR-IFFD-9 : ✅ **traitée (doc + décision à prendre)**.

---

## 1. CR-IFFD-8 — capitalisation du champ `text` : livrée, et déterministe

### Ce qui est ajouté

`ZTextConfig` accepte désormais une capitalisation **déclarative** :

```dart
ZFieldSpec(
  name: 'name',
  type: EditionFieldType.text,
  config: ZTextConfig(capitalization: ZTextCapitalization.sentences),
)
```

`ZTextCapitalization { none, sentences, words, characters }`. **`none` est le défaut** — un
champ `text` sans config, ou avec une config sans `capitalization`, conserve **exactement**
son rendu antérieur (aucun formateur ajouté). Rétro-compatibilité stricte, garde dédiée.

Pour reproduire votre `ucFirstFormatter` (`"biologie"` → `"Biologie"`) : **`sentences`** —
première lettre de phrase en majuscule, ce qui équivaut à l'`ucFirst` sur une saisie
mono-phrase.

### ⚠️ Le point qui justifiait du code, pas juste un flag Flutter

Votre CR demandait « des `inputFormatters` **ou** une option de capitalisation ». Nous avons
choisi l'option déclarative — mais elle pilote **deux** mécanismes, et c'est délibéré :

1. `textCapitalization` — l'indice de clavier logiciel de Flutter ;
2. **un `TextInputFormatter` déterministe** — c'est lui qui compte.

**`TextCapitalization` seul ne suffisait pas.** Ce n'est qu'un *indice* de clavier : il ne
s'applique **ni au collage, ni à la saisie programmatique, ni aux claviers physiques**.
Votre `ucFirstFormatter`, lui, est déterministe. Sans le formateur, une valeur collée en
minuscules aurait traversé intacte — et votre schéma serait resté incohérent, exactement le
risque que la CR pointait. Une garde de test couvre spécifiquement le collage.

### Invariants préservés

- **Mot de passe jamais capitalisé** — même si la config le demande (n'altère pas le secret).
- **SM-1 / curseur** — la casse ne change pas la longueur du texte, donc la position du
  curseur reste valide. Garde : le curseur au milieu du texte ne saute pas.

### Votre note connexe sur `color` — à surveiller, pas à corriger

Vous relevez que `ZColorFieldWidget` écrit un `int` ARGB là où le moteur IFFD écrit un
`Color` brut dans `item`. C'est exact, mais ce n'est pas un défaut zcrud : une valeur de
domaine **doit** être neutre (un `int`, pas un type Flutter). C'est votre `formDataTransformer`
qui réconcilie, et vous notez vous-même qu'il sort une `String` décimale identique. **À
vérifier côté IFFD** pour les écrans qui liraient la valeur brute sans transformer
(`folder_modal_dialogs`) — mais rien à changer chez nous. Si un besoin réel apparaît,
émettez une CR distincte.

---

## 2. CR-IFFD-9 — `zcrud_document` hors fermeture : ce n'est pas un défaut, et vous le saviez

Vous avez vous-même posé le bon diagnostic : *« Ce n'est pas forcément un défaut de
zcrud — l'exclusion des entités concrètes du binding générique est un invariant assumé
(AD-24). »* **Confirmé sur disque** : aucun package produit ne tire `zcrud_document`
(seul un harnais de test le fait).

C'est **délibéré**. Le binding générique reste *thin* : il expose les seams et fabriques,
et **ignore** les types concrets. Un binding qui dépendrait de `zcrud_document` imposerait
cette entité — et `zcrud_note`, `zcrud_exam`… — à **tout** consommateur, y compris ceux
qui ne s'en servent pas.

### Le vrai manque était documentaire — corrigé

`docs/private-git-consumption.md` gagne une section **« Les packages d'ENTITÉ ne sont tirés
par aucun binding »** : dès que votre code écrit `import 'package:zcrud_document/...'`, vous
**déclarez `zcrud_document` vous-même** (en `dependencies:` **et** `dependency_overrides:`,
même règle git que tout `zcrud_*`). C'était l'angle mort de la recette.

### 🔴 Votre contournement porte un risque que la doc nomme maintenant

Vous mappez vers le **schéma figé de `z_study_document.g.dart`** pour éviter d'importer
l'entité. Votre CR le dit lucidement : *« si `ZStudyDocument` change de schéma dans un tag
ultérieur, le contournement diverge en silence — rien côté IFFD ne le détecterait. »*

**C'est le motif de toute cette série de CR** : une divergence silencieuse qu'aucun signal
ne rattrape. Importer réellement l'entité transforme tout changement de schéma en **erreur
de compilation** au lieu d'une corruption de données muette.

**Décision owner à prendre** : ajouter `zcrud_document` (et les autres packages d'entité)
au pubspec d'IFFD, ou pérenniser la forme canonique. **Notre recommandation : l'import**,
dès que l'entité est au cœur du flux — ce que `FolderDocument` est pour vous. Le coût est
une ligne de `dependencies` + une d'`overrides` ; le bénéfice est de ne plus jamais migrer
à l'aveugle sur un schéma qui a bougé sans que vous le sachiez.

---

## 3. Registre

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-1 | mineur | ✅ caduque |
| CR-IFFD-2..7 | — | ✅ livrées (v0.3.2 → v0.3.6) |
| CR-IFFD-8 | majeur | ✅ **livrée (v0.3.7)** — `ZTextCapitalization` |
| CR-IFFD-9 | mineur | ✅ **traitée (v0.3.7)** — doc corrigée ; décision owner ouverte (import vs canonique) |

`zcrud_core` **1025/1025** (+ 7 gardes CR-8), `melos run analyze` RC=0,
`melos run verify` RC=0 (11 gates). API **additive** : `ZTextCapitalization.none` par
défaut, comportement v0.3.6 strictement inchangé.

---

## 4. Ce que neuf CR ont établi — deux natures de défaut

Vos huit premières CR étaient des **pertes silencieuses** (résurrection de données,
non-déterminisme, champ perdu…). CR-IFFD-8 est d'une autre nature : une **fonctionnalité
manquante** (le champ `text` ne savait pas capitaliser), avec un risque de régression de
données à la première réédition. Et CR-IFFD-9 n'était **pas un défaut du tout** — un
invariant assumé, dont seule la documentation manquait.

Le canal fonctionne parce que vous distinguez ces natures : une CR qui reconnaît elle-même
« ce n'est pas forcément un défaut de zcrud » nous fait gagner autant de temps qu'une CR qui
prouve une corruption. Continuez à les émettre — et continuez à éprouver par exécution ce
que nous livrons, y compris cette capitalisation dont le comportement `sentences` sur vos
libellés réels mérite un coup d'œil avant W7.
