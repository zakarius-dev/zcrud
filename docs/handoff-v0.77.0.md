# Handoff **v0.77.0** — les deux derniers champs `intl`, et une garde qui n'atteignait jamais son sujet

> **Tag à épingler : `v0.77.0`**
> ⚠️ **Changement d'arbre visible** sur les champs **devise** et **état/province** de `zcrud_intl`
> (§ 1). **Mesuré : aucun de vos quatre dépôts ne les utilise** — impact nul aujourd'hui.
> Aucun jeton nouveau, aucune arête, aucun paquet nouveau (38).

---

## 1. Les deux champs restants — et le rapport qui les annonçait était inexact

v0.76.0 avait signalé que deux autres champs de `zcrud_intl` portaient « **exactement** le même
défaut » de décoration. **Re-mesuré : faux dans le détail**, et c'est ce qui rend ce lot intéressant.

Ces deux champs ont **quatre variantes**, pas une, et le compte d'annonces diffère selon la variante :

| Variante | Avant |
|---|---|
| sélecteur seul (devise sans montant, état avec subdivisions) | **doublon** sur le nœud **+ une catégorie concurrente** annoncée par le déclencheur ⇒ **3 libellés prononcés** |
| avec sous-champ à libellé interne (montant, repli texte) | **triplon** |
| en grande taille | **une source de plus** (la carte) ⇒ **4** |

**Après : exactement une annonce et un rendu du libellé, dans les huit cas.**
Et la géométrie rejoint celle du cœur — **752 → 776 dp**, alignée sur un champ texte : le même
espacement superflu que celui retiré en v0.76.0.

🔵 **Deux conventions réutilisées, pas une troisième** : le patron du champ « pays » pour les
variantes à sélecteur, celui du champ « adresse » pour la variante à sous-champs. La garde de source
étant écrite fichier par fichier, les deux s'y ajoutent **d'une ligne chacun** — vérifié, et fait.

## 2. 🔴 La garde vacante — la vacuité est **prouvée**, pas supposée

Elle prétendait vérifier le comportement sous une locale inconnue. Cause mesurée : sans locales
supportées déclarées, le harnais **résout toute locale vers l'anglais** — y compris `fr_FR`. La garde
n'atteignait donc **jamais** le champ.

**La preuve est faite dans les deux sens** : deux régressions exactes, injectées, laissent la garde
d'origine **verte** — et rendent la garde corrigée **rouge d'assertion**.

Corrigée avec locales déclarées, elle affirme désormais que la locale **atteint** le champ, puis le
repli réel des noms — doublée d'une **jumelle discriminante** dans l'autre langue, sans laquelle le
constat resterait vide (« Albania » et « Albanie » ne prouvent quelque chose qu'ensemble).
🟢 **Le comportement gardé s'est révélé correct** : pas de finding caché derrière la vacuité.

🟢 **Et aucune autre garde ne souffre du même motif** — recherche montrée : seuls deux harnais passent
une locale, et l'autre déclarait déjà ses locales supportées.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **tous** | 🟢 **rien** — recherche négative sur vos quatre dépôts : **aucun** n'utilise les champs devise ou état/province |
| **hôte futur de ces champs** | si vous compensiez, **retirez** votre libellé externe, toute marge de réalignement, et tout test cherchant le libellé de catégorie du déclencheur |

## 4. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_intl` **280** (+17) · `zcrud_core` 1708 · `zcrud_study` 1521 · `zcrud_get` 150 · `example` 108.
**0 erreur, 0 avertissement.** Aucune garde supprimée.

**R3 — 13 injections, toutes rouges d'ASSERTION**, sha avant **et** après chacune, empreintes finales
**identiques** aux initiales, restauration par copie, résidus : greps négatifs montrés. Zéro rouge de
compilation, de `StateError` ou d'erreur de type.

🟢 **Le piège de la ligne de base s'est présenté une fois de plus — et a été mesuré.** Une garde
écrite sur l'égalité stricte du libellé était **rouge dès la ligne de base** : un artefact de fusion
ajoute un saut de ligne au texte du nœud. Les gardes lisent désormais **l'annonce effective** et
comptent les **occurrences**. C'est la deuxième fois en deux jours que ce motif apparaît, et la
deuxième fois qu'il est attrapé **avant** de conclure quoi que ce soit.

## 5. Signalé, non fait — et il faut le lire

🟡 **Une aide de test partagée du paquet mesure la cible tactile avec `getSize()`** — précisément
l'anti-patron qu'AD-13 interdit, et celui qui a rendu des gardes vacantes **six fois cette semaine**.
Elle sert des items de liste, hors du chemin de ces deux dettes, donc elle n'a **pas** été corrigée
ici.

> ⚠️ Ce n'est pas un détail : une **aide partagée** qui mesure la mauvaise chose rend potentiellement
> vacante **toute garde qui l'appelle**. C'est un lot à part, et il devra commencer par compter qui
> l'utilise.

* Dettes antérieures : cf. v0.76.0 et les handoffs précédents.
