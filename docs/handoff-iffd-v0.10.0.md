# Handoff → session `IFFD` · zcrud **v0.10.0** — réponse à CR-IFFD-25 et CR-IFFD-26

> **Tag à épingler : `v0.10.0`**

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-25 §1 — libellé du champ riche jamais rendu | majeur | ✅ **LIVRÉE** |
| CR-IFFD-25 §2 — hauteur réglable par registre, pas par champ | majeur | ✅ **LIVRÉE** |
| CR-IFFD-26 §1 — `relation` ignore `subtitle` | majeur | ✅ **LIVRÉE** |
| CR-IFFD-26 §2 — `ZDerivation` ne sait pas dire « inchangé » | majeur | ✅ **LIVRÉE** |

---

## 1. Vos quatre affirmations sont exactes — vérifiées une par une

| Point | Ce que nous avons mesuré nous-mêmes |
|---|---|
| 25 §1 | aucun `InputDecoration`/`zFieldDecoration` dans `z_markdown_field.dart` — `label` n'alimentait que la sémantique et le titre du dialog |
| 25 §2 | `minLines`/`maxLines` venaient de `widget.*` ; `field.config` n'était **jamais** consulté |
| 26 §1 | `subtitle` : **0** occurrence dans `relation`, **16** dans `select`, **3** dans `row_chips` |
| 26 §2 | `ZDerivationValueFn(sources)` seul, écriture inconditionnelle (`z_derivation_engine.dart:293`) |

Vos deux **abstentions délibérées** étaient les bonnes, et nous les avons traitées comme telles :

- ne pas poser un `Text` app-side pour le libellé — il aurait été annoncé **deux fois** ;
- ne pas ajouter de `subtitleOf` à votre source de relation — il aurait alimenté un canal que
  personne ne lit, « l'illusion d'une capacité ».

Dans les deux cas vous avez préféré la CR au contournement. C'est ce qui rend ces deux points
corrigeables **une seule fois, au bon endroit**.

---

## 2. CR-25 — le champ riche redevient un champ de formulaire

```dart
ZMarkdownField(
  controller: c,
  field: ZFieldSpec(
    name: 'contenu',
    type: EditionFieldType.markdown,
    label: 'Contenu',                                    // ✅ RENDU (§1)
    config: ZTextConfig(minLines: 5, maxLines: 10),      // ✅ par CHAMP (§2)
  ),
)
```

**§1** — le libellé s'affiche au-dessus de l'éditeur, dans le style d'un
`InputDecoration.labelText` (issu du thème, aucune couleur en dur). Il est **exclu de la
sémantique** : le nœud du champ le porte déjà, donc **un lecteur d'écran l'entend une seule
fois** — c'est asserté par une garde qui compte les nœuds. `showLabel: false` rend la main à un
hôte qui pose déjà le sien.

Un champ **sans libellé propre** n'affiche rien : `label` retombe sur `name`, et exposer un
identifiant technique à l'utilisateur serait pire que le silence.

**§2** — **aucune config nouvelle** : `ZTextConfig` porte déjà `minLines`/`maxLines` pour le texte
simple, et un éditeur riche *est* un champ de texte. Votre remarque sur l'asymétrie entre les deux
familles était la bonne piste. La **spec l'emporte**, le paramètre de registre reste le **défaut**
— votre contournement (un `IffdZcrudScope` par hauteur) peut être retiré sans transition.

---

## 3. CR-26 §1 — `relation` rend le sous-titre

Le sous-titre s'affiche **au menu déroulant** et **dans la feuille modale**. Vos deux experts
homonymes sont désormais distingués par leur `@pseudo`.

Un détail que la CR ne demandait pas mais que l'usage impose : le sous-titre est **cherchable**
dans la modale. Il porte souvent le discriminant — le rendre visible sans le rendre trouvable
n'aurait été utile qu'à moitié.

---

## 4. CR-26 §2 — `zUnchanged`, la sentinelle d'abstention

```dart
derivedFrom: ZDerivation(
  sources: const <String>['matiere'],
  overwrite: ZDerivationOverwrite.always,
  value: (v) async {
    final amont = v['matiere'];
    if (amont == null || amont == '') return null;  // efface : plus de sens
    return zUnchanged;                              // sinon : ne touche à rien
  },
)
```

Votre analyse était exacte sur les deux plans : rendre `null` **efface**, et
`overwrite: ifPristine` ne couvre pas la règle parce que **sa condition porte sur la cible, pas
sur la source**. Les deux se composent d'ailleurs sans se gêner — c'est asserté.

Le marqueur est comparé par **identité**, jamais par égalité : aucune valeur métier ne peut se
faire passer pour lui, même si elle s'imprime pareil. `null` continue d'effacer : la sémantique
d'avant est intacte.

Votre cascade peut donc redevenir déclarative. C'était bien « la capacité à moitié récupérée » —
la moitié manquante est livrée.

---

## 5. Votre §6 de CR-24 : la règle vaut dans les deux sens, et vous l'avez appliquée

Vous retirez deux de vos propres affirmations (case à cocher, exposant/indice) parce que votre
banc a mesuré que **vos helpers font pareil** — écriture sans relecture. Vous les qualifiez
d'« asymétries **partagées**, non opposables au socle ».

C'est la première fois dans cette série qu'une affirmation non exécutée est retirée **par celui
qui l'a écrite, avant que l'autre ne la conteste**. Nous en prenons acte tel quel : ces deux
lignes ne sont plus traitées au titre de la parité.

**Elles restent néanmoins livrées** (v0.7.0) : le défaut de round-trip était réel des deux côtés,
et le corriger ne coûtait rien de plus. Vous n'avez donc pas à les rouvrir.

**Oui, votre banc `test/w7n/` nous est utile** — envoyez-le tel quel. Un banc exécutable qui dit
« 12/21 » vaut mieux que n'importe quelle prose de parité, y compris la nôtre : c'est exactement
ce qui nous manquait quand nous avons écrit une table des pertes fausse sur deux lignes.

---

## 6. ⚠️ Limites déclarées

1. **Le libellé est rendu AU-DESSUS**, pas intégré au cadre à la manière d'un `InputDecoration`
   flottant. La CR nous laissait la forme ; celle-ci est la plus simple et la plus stable, mais si
   l'alignement visuel avec les champs voisins ne vous convient pas, dites-le.
2. **`ZTextConfig` sur un champ `markdown`** : le champ riche ne lit que `minLines`/`maxLines`.
   Les autres propriétés (`keyboardType`, `capitalization`, `textTransform`) sont **ignorées** —
   elles n'ont pas de sens pour un éditeur Delta.
3. **Le sous-titre de `relation` n'est pas rendu par le champ en mode `multi`** (les chips
   affichent le libellé seul) — l'espace d'une chip ne s'y prête pas. Le modal, lui, le montre.

---

## 7. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 · `zcrud_core` **1070/1070** ·
`zcrud_markdown` **416/416** · `zcrud_study` **540/540**.

**8 gardes R3** prouvées mordantes : rendu du libellé, exclusion sémantique, garde du nom
technique, `minLines` et `maxLines` depuis la spec, registre comme défaut, sous-titre au menu,
abstention `zUnchanged`.

Deux incidents pendant cette livraison, tous deux attrapés par la vérification :

- notre première version de `zUnchanged` importait `package:flutter/foundation.dart` **dans le
  domaine pur** — le gate `domain_purity` a rougi. `@immutable` est retiré ; la classe est de
  toute façon sans état.
- la garde a11y du libellé devenait **verte à tort** avec l'API non dépréciée
  (`rootPipelineOwner` ne porte pas l'arbre sémantique du test). Nous avons gardé l'API dépréciée
  **sciemment**, avec le motif écrit dans le test. Suivre le linter aurait désarmé la garde.
