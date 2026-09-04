# Handoff v3.45.0 — le multi-éditeur de cartes reçoit un créneau de champ

> **Date** : 2026-09-04. **Portée** : `zcrud_study`. **Traite** : CR-IFFD-134 (`MINEUR`).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : **0 `.g.dart` modifié**. Aucune entité, aucun `toMap()`
touché — la livraison est entièrement présentationnelle.

## 1. Le défaut, tel que l'hôte l'a mesuré

`ZMultiFlashcardEditor` rendait la question, la réponse, l'explication et l'indice de chaque
carte avec un champ de texte simple, construit par une méthode **privée** — donc sans aucun
point d'injection : ni le widget ni ses `labels` n'exposaient de fabrique. L'écran legacy que
ce multi-éditeur remplace déclarait pourtant question et réponse en édition riche (formules,
tableaux). Ce n'est pas une simplification : c'est une **capacité absente**, et l'hôte gardait
son écran legacy allumé plutôt que de perdre la saisie riche.

Le pilote signale un effet de bord instructif : faute de barre d'outils, une carte de test avait
été créée en **tapant** `$x^2$` et `| --- |` au clavier — produisant une forme de contenu qu'une
conversion aval a ensuite détruite. Le manque d'un écran a fabriqué la matière du défaut d'un
autre.

## 2. Ce que le socle livre

Un **créneau, pas un éditeur**. Aucune dépendance d'édition riche n'entre dans `zcrud_study` :
le paquet garde son champ de texte simple par défaut, l'application y branche le sien.

```dart
enum ZFlashcardEditorField { question, answer, explanation, hint }

class ZFlashcardFieldSlot {
  final ZFlashcardEditorField field;
  final TextEditingController controller;
  final String label;
  final VoidCallback onEditingComplete;
}

typedef ZFlashcardFieldBuilder = Widget Function(BuildContext, ZFlashcardFieldSlot);

// sur ZMultiFlashcardEditor :
final Map<ZFlashcardEditorField, ZFlashcardFieldBuilder>? fieldBuilders;
```

Champ absent de la table (ou table absente) ⇒ le champ de texte actuel, **rendu inchangé**.

**Trois écarts assumés par rapport au texte de la CR**, chacun mesuré avant décision :

1. **Un discriminant, `slot.field`.** La signature proposée — `(BuildContext,
   TextEditingController, String label)` — obligeait une application qui partage une fabrique
   entre plusieurs champs à comparer des **libellés localisés** pour savoir quel champ elle rend.
2. **`onEditingComplete` exposée.** Le champ par défaut publiait la valeur **puis** rafraîchissait
   l'aperçu de la carte ; sans cette voie, un widget injecté aurait perdu le rafraîchissement.
3. **Une table par champ**, non une fabrique unique : l'état sait dès son initialisation quels
   controllers écouter, sans muter son état pendant la construction.

**Un défaut que la CR ne voyait pas, corrigé dans le même lot.** La publication du brouillon ne
passait que par les rappels du champ de texte. Un éditeur injecté aurait écrit dans le controller
sans que la carte n'en sache rien : **la saisie de l'utilisateur aurait été perdue en silence** au
commit groupé — exactement le genre de défaut que le créneau était censé éviter. L'éditeur écoute
désormais le controller de chaque champ **rendu par un slot**, et lui seul (écouter aussi le
chemin par défaut doublerait la notification à chaque frappe) ; l'écoute est réalignée quand la
table change et retirée à la destruction.

## 3. Ce qui change pour un hôte

- **Passif : rien.** Sans `fieldBuilders`, le formulaire de carte est rendu à l'identique — liste
  figée des enfants de sa colonne, quatre champs aux mêmes clés, mêmes libellés et alignements, et
  **aucune écoute** posée sur leurs controllers. La garde d'inertie l'établit par égalité stricte,
  et une injection l'a prouvée mordante.
- **Hôte qui compensait** — ici, l'hôte qui a **gardé son écran legacy allumé** pour ne pas perdre
  la saisie riche : la compensation n'est plus nécessaire. Le geste vérifiable de son côté :
  basculer son drapeau de multi-éditeur, poser une entrée `fieldBuilders` sur `question` et
  `answer`, et **constater que son écran legacy n'est plus atteint** (un test qui affirme la perte
  de la saisie riche sur le chemin socle doit désormais rougir — c'est lui qui désigne le doublon à
  retirer, pas cette phrase).
- ⚠️ **Le contrat que le widget injecté doit respecter** : alimenter le controller **reçu**, ne pas
  le remplacer par le sien. C'est la seule voie de publication ; un éditeur qui tient son propre
  controller n'écrira jamais dans la carte. La dartdoc du slot le dit au point d'usage.

```dart
ZMultiFlashcardEditor(
  onCommit: _commit,
  labels: _labels,
  fieldBuilders: {
    ZFlashcardEditorField.question: (context, slot) => MonEditeurRiche(
          controller: slot.controller,
          label: slot.label,
          onEditingComplete: slot.onEditingComplete,
        ),
  },
)
```

## 4. Ce qui n'est PAS traité, et pourquoi c'est dit ici

La CR pose, en marge, une question de conception que ce créneau **ne ferme pas** : l'hôte a deux
chemins pour la même donnée — la carte unique montée sur le moteur d'édition (donc riche par
déclaration de champ), et la création groupée montée sur un widget clé en main (donc simple).
Reconstruire le multi-éditeur sur le moteur d'édition rendrait la richesse **par déclaration**,
sans créneau ; mais l'hôte devrait alors réécrire chez lui l'ossature de lot que ce widget fournit
(liste, sélection, suppression groupée, champs communs, génération). Le créneau ferme le manque
immédiat au coût le plus bas. Une variante du multi-éditeur montée sur le moteur reste un lot
**ouvert et non engagé** : elle ne se décidera que sur une demande explicite.

## 5. Vérification

| Paquet | Avant | Après |
|---|---|---|
| `zcrud_study` | 1 903 | **1 912** |

`melos run generate` : SUCCESS, **0 `.g.dart` modifié** · `analyze` repo-wide RC=0 ·
`verify` RC=0 (12 gates) · R3 : 8 injections, **7 rouges par assertion** (une variante rougissant
par erreur de compilation a été écartée et refaite), restauration par copie, sha256
`4828cff3f7f5048d6a6e249ffc018210cd44e80d41acc0f1540061fb327688b2` identique avant et après,
grep négatif du marqueur montré (0 occurrence sur `lib/` et `test/`).

🟢 **Une garde a été retirée plutôt que gardée verte** : la protection contre une publication
inutile au simple déplacement du curseur n'est **pas observable** depuis la surface publique (une
publication à vide repose la même carte et ne change rien). Le test qui prétendait la couvrir était
tautologique ; il a été retiré et son absence consignée dans le fichier de test. Le garde-fou reste
dans le code, où il a sa place.
