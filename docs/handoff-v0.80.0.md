# Handoff **v0.80.0** — les trois finitions, et deux chiffres qui n'étaient pas les bons

> **Tag à épingler : `v0.80.0`** — répond aux **3 points** de `cr-boolean-label-weight-and-field-paddings`.
> 🔴 **Changement d'arbre visible** : hauteur du booléen encarté (§ 2) et retrait du drapeau du
> téléphone (§ 3). Le libellé gras (§ 1) est **opt-in par votre jeton**, hôte passif immobile.
> **Aucun jeton nouveau** — votre contrainte de v0.76.0 tient. Aucune arête, 38 paquets.

---

## 1. Libellé booléen en gras — voie A, sans jeton nouveau

Le titre du booléen reprend le **seul `fontWeight`** de votre jeton `labelTextStyle` existant, sur
les trois rendus (pilule, tuile, tuile + état).

🔵 **Le style entier n'est PAS fusionné, et c'est délibéré** : reprendre couleur et taille aurait
changé le titre chez **tout** hôte posant déjà le jeton — dont vous, qui y mettez votre marine.
Garde de non-contamination dédiée. Hôte passif : immobile au pixel, y compris s'il pose
`labelTextStyle` **sans** `fontWeight` — c'est votre cas actuel.

**Votre note sur le canal commun : mesurée, et la réponse est non.** Les deux canaux divergent bien
aujourd'hui (titre booléen ⇒ `bodyLarge` du `ListTile` ; libellés des autres familles ⇒
`labelTextStyle ?? bodyMedium`). Après ce lot ils partagent le **poids seulement**. La convergence
complète ferait passer le titre d'un hôte passif de **16 à 14 sp** — un changement de pixel non
opt-in, sur toutes les familles. Non fait : c'est votre arbitrage, pas le nôtre.

## 2. Hauteur du booléen encarté — **votre chiffre était juste**

Mesuré : encart **88 dp → 56 dp**, contre un champ texte voisin **réellement monté** à **56 dp**.
Votre « ~56 + 32 » était exact. Le rendu non encarté reste à 56 dp, inchangé.

Correctif : l'enveloppe retire la seule composante **verticale** du padding de contenu (la ligne
porte déjà sa hauteur) ; `start`/`end` restent relus sur le jeton.

🔵 **La piste `dense`/`compact` que vous proposiez a été écartée AVEC sa mesure** : elle donne
ligne 56→48 et encart 88→80 — **jamais 56**, donc jamais la parité demandée. Et elle poserait la
ligne exactement **au plancher tactile** de 48 dp, sans marge.

⚠️ **Un piège de mesure, consigné pour vous comme pour nous** : la première mesure donnait 96/64,
parce que le libellé « Boat Service actif » **passe à la ligne** dans la police de test. Toute garde
de hauteur doit utiliser un libellé court — sans quoi elle mesure le retour à la ligne, pas la marge.

## 3. Drapeau du téléphone — 🔴 **votre chiffre, lui, était faux**

Mesuré, deux rendus confrontés dans le même thème :

| | Avant | Après |
|---|---|---|
| contenu du champ texte voisin | 32.0 | 32.0 |
| drapeau `🇹🇬` | **12.0** — le **ras exact** du cadre, 0 dp | **32.0** |

> **L'écart valait 20 dp, pas 16.** Le retrait des voisins est `contentPadding.start` (16) **plus**
> l'espacement de bordure du SDK (4).

Corriger « ≈ `inputContentPadding.start` » comme la CR le demandait aurait donc laissé **4 dp de
décalage résiduel** — et ce n'est pas une opinion : l'injection correspondante rend `16.0` face à un
voisin à `20.0`.

Le levier réel est un paramètre du paquet tiers, alimenté par une valeur **dérivée de la décoration
déjà construite par le cœur** (jamais recalculée, jamais court-circuitée) — chaîne FR-26 *config par
champ > paramètre de registre > jeton*. **Aucune constante de style n'est écrite.**

🔵 **Quatre voies refusées avec leur mesure** : envelopper le `prefixIcon` (le tiers l'écrase par
`copyWith` — l'impasse déjà rencontrée en v0.76.0) ; contraindre l'icône (le SDK la **centre**,
l'espace irait des deux côtés) ; sortir le bouton du cadre ; recopier une constante privée du SDK.

🟡 **Un résidu assumé et documenté, non corrigé** : le paquet tiers ajoute 8 dp de tête par un
padding **non directionnel** — donc faux en RTL. Mesuré **constant** sous deux valeurs de jeton
différentes, donc indépendant de nos jetons et **non corrigeable depuis le satellite**. La garde
affirme cette invariance **sans coder le 8** : elle documente la perte au lieu de la défendre.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | 🟢 rien sur le § 1 ; les § 2 et 3 sont des corrections visibles attendues |
| 🔴 **hôte qui COMPENSAIT la hauteur** du booléen encarté (marge négative, cale, espacement réduit) | **retirez-le** — il s'additionne et rendrait le booléen **plus court** que ses voisins |
| 🔴 **hôte qui COMPENSAIT le retrait du drapeau** (marge externe, enveloppe) | **retirez-le** — même addition |
| **hôte posant un `fontWeight`** dans `labelTextStyle` | le titre booléen le prend automatiquement — **y compris un poids léger** |

🟢 **Tripwire recommandé** (votre pratique, que nous propageons) : une garde de parité de hauteur
booléen ↔ champ texte chez vous. Si un jour le socle régresse, elle rougit et vous le dit — au lieu
de vous laisser croire un handoff sur parole.

## 5. Vérification

`melos generate` **RC=0**, **0** `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1744** (+13) · `zcrud_intl` **286** (+6) · `example` 108. **0 erreur, 0 avertissement**
(11 `info` préexistants sur le cœur, identiques à la ligne de base).

**R3 — 8 injections au total, toutes rouges par ASSERTION** (aucune compilation, aucun `StateError`,
aucune erreur de type), sha avant **et** après chacune, restauration par copie, résidus prouvés par
greps négatifs montrés.
**Ligne de base mesurée dans les deux sens** des deux côtés : les états d'origine **sont** le code de
`v0.79.0`, et ils rendent rouge (6 gardes côté booléen, 5 côté téléphone).

⚠️ **Notre CI reste à l'arrêt (facturation)** — vérifications locales uniquement, et c'est la seule
ligne de défense.

## 6. Signalé, non fait

* 🟡 L'aide de test partagée de `zcrud_intl` qui mesure la cible tactile par la taille rendue
  (l'anti-patron AD-13) : **deux fichiers l'appellent encore**, nommés dans le rapport. Lot à part,
  qui commencera par compter ses appelants — inchangé depuis `v0.77.0`.
* La convergence complète des libellés (§ 1), qui vous appartient.
* Dettes antérieures : cf. `v0.79.0` et les handoffs précédents.
