# Handoff **v0.79.0** — une perte de données silencieuse dans les sous-listes

> **Tag à épingler : `v0.79.0`**
> 🔴 **Correction de PERTE DE DONNÉES, active aujourd'hui chez IFFD et DODLP.** Ce n'est pas un
> défaut d'affichage : des clés étaient **détruites**.
> ⚠️ **Deux widgets concernés**, pas un — le second est une extension de notre initiative,
> invisible depuis l'énoncé qui a déclenché ce lot (§ 3).
> Aucun jeton nouveau, aucune arête, aucun paquet nouveau (38).

---

## 1. Le défaut

Le champ de sous-liste **recomposait** chaque item à partir des seuls champs déclarés dans son
sous-schéma :

```dart
for (final f in _itemFields) f.name: item.controller.valueOf(f.name),
```

Conséquence : **toute clé portée par la graine mais absente du sous-schéma disparaissait dès la
première frappe** dans n'importe quel sous-champ. `id` en premier.

Mesuré chez vous :

| Hôte | Perte |
|---|---|
| **IFFD** | l'`id` de chaque **choix de QCM** — et **aucune compensation** : votre `{...rawSeed, ...values}` au niveau racine ne restaure rien, puisque la perte est déjà **dans** `values` |
| **DODLP** | **6 clés** par mobilité, dont `id` et la liste d'identifiants d'agents |

🔴 **Un aggravant qui n'apparaissait dans aucun rapport** : côté IFFD, l'`id` perdu était ensuite
**regénéré aléatoirement** au retour. L'identité d'un choix ne survivait donc pas à une édition —
un enregistrement modifié revenait avec de **nouveaux** identifiants.

## 2. Ce qui a été fait — et le piège qui commandait la conception

Le résidu hors schéma est conservé **sur l'objet item lui-même**, et c'est le point de tout le lot :

> **l'appariement graine ↔ item est fait par IDENTITÉ, jamais par index.** Réordonner, retirer ou
> soft-supprimer déplace l'objet, et le résidu voyage avec lui.

Une conservation appariée **par index** aurait recollé la graine d'un item **sur un autre** après un
retrait au milieu — **pire que la perte d'origine**. Ce n'est pas une inquiétude théorique : elle a
été injectée, et la garde a rendu `Expected: ['B','A','C'] / Actual: ['A','B','C']`.

Trois garanties, chacune gardée :
* le résidu ne contient **jamais** une clé déclarée, et il est fusionné **avant** les tranches : un
  champ que l'utilisateur **efface** reste effacé, il ne ressuscite pas depuis la graine ;
* il n'est peuplé qu'au **seul** point d'entrée d'une graine : un item **ajouté** est strictement
  inchangé ;
* le soft-delete (DP-19) est intact.

## 3. ⚠️ Deux widgets, pas un

Le même défaut a été **mesuré et corrigé** sur le champ d'**item dynamique**. Il n'était pas dans
l'énoncé : c'est une extension de notre initiative, donc précisément celle que vous ne pouvez pas
déduire — nous la signalons le plus fort.

🟢 **Et le troisième suspect est SAIN, prouvé** : la table éditable n'a aucun schéma contre lequel
filtrer (ses colonnes sont l'**union** des clés, ses émissions repartent de la ligne complète).
Recherche négative montrée. Rien n'y a été touché.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif (IFFD, DODLP)** | 🟢 **rien** — gain direct, vos `id` survivent à l'édition |
| 🔴 **hôte qui réinjectait les `id` PAR POSITION** | **retirez-le** : il entre désormais en conflit avec le socle |
| 🔴 **hôte qui refusionnait la graine au niveau ITEM** | **retirez-le** : il ré-impose des champs que l'utilisateur avait volontairement effacés |
| **IFFD** | votre fusion **racine** `{...rawSeed, ...values}` est inoffensive et peut rester |

## 5. Vérification

`melos generate` **RC=0**, **0** `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1731** (+10). `dart analyze` RC=0, sortie **identique à la ligne de base** (11 `info`
préexistants, aucun sur les fichiers touchés).

**R3 — 4 injections, tous les rouges par ASSERTION** (aucune compilation, aucun `StateError`, aucune
erreur de type), sha changé à chaque injection, résidus prouvés par grep négatif montré.
**Ligne de base inverse mesurée** : jouées sur le code d'origine, **9 gardes sur 10** rougissent
(`Expected: 'choice-1' / Actual: <null>`).

🟢 **La dixième est verte dès la base, et son auteur le dit** : elle défend un mode de défaillance
introduit **par le correctif lui-même**, pas le défaut d'origine ; sa morsure vient d'une autre
injection. C'est exactement le genre d'aveu qu'un compte flatteur ferait disparaître.

⚠️ **Notre CI reste à l'arrêt (facturation)** — vérifications locales uniquement.

## 6. Ce qui reste sur cette lignée

L'arpentage qui a révélé ce défaut en a classé d'autres, à traiter ensuite :
🟡 des familles qui ne se taisent pas mais **mentent** — une graine `"3"` sur une notation affiche
`0 / 5`, `"7"` sur un curseur affiche `0`, `"true"` sur un booléen affiche **faux**. Le vide se voit ;
un zéro plausible se signe.

* Dettes antérieures : cf. `v0.78.0` et les handoffs précédents.
