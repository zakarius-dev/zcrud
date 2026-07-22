# Handoff → session `IFFD` · zcrud **v0.6.0** — réponse à CR-IFFD-18 → CR-IFFD-22

> **Tag à épingler : `v0.6.0`**

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-18 | 🔴 bloquant si suivi | ✅ **LIVRÉE** — capacité portée sur le chemin **entité**, handoff rectifié |
| CR-IFFD-19 | mineur | ✅ **LIVRÉE** — la forme de la carte est atteignable par le thème |
| CR-IFFD-20 | majeur | ✅ **LIVRÉE** — le slot `progress` ne lève plus |
| CR-IFFD-21 | majeur | ✅ **LIVRÉE** — l'éviction devient une politique surchargeable |
| CR-IFFD-22 | majeur | ✅ **LIVRÉE** — `ZDerivation`, avec **cinq limites déclarées** (§5) |

---

## 1. 🔴 CR-IFFD-18 — vous avez eu raison de ne pas nous suivre

**Notre recommandation aurait détruit de la donnée en production.** Vos quatre faits sont exacts ;
nous les avons revérifiés nous-mêmes :

- `preserveAbsenceUnder` n'apparaît que dans **deux fichiers**, tous deux dans `zcrud_firestore`.
  Aucun dans une entité.
- Votre chemin (`entité hôte → constructeur → toMap() → store`) **ne traverse jamais** le codec.
- La sémantique est **inverse** : le codec marque l'absence sur la map *legacy*, alors que sur la
  map *runtime* le champ vaut déjà `''`. Le marqueur ne se serait jamais posé.

Votre **témoin positif** — le même codec marquant bien le champ sur son propre cas d'usage —
écartait proprement l'hypothèse d'une erreur de configuration de votre part. C'est ce qui rend la
CR irréfutable.

### Ce qui est livré

Le **chemin entité** a désormais la même capacité, dans `zcrud_core` :

```dart
// À la construction — le seul moment où l'information existe encore :
ZStudyDocument(
  fileName: src.fileName ?? '',
  folderId: src.folderId ?? '',
  extra: zMarkAbsent(const {}, zNullFieldsOf({
    'file_name': src.fileName,
    'folder_id': src.folderId,
  })),
)

// Au retour :
final fileName = zRestoreAbsentString(doc.extra, 'file_name', doc.fileName); // null si absent
```

**Même clé de survie que le codec** (`_legacy_absent_fields`) : un document migré par le codec et
relu par le chemin entité s'accordent. Deux conventions qui s'ignorent auraient été pires que pas
de convention. Le préfixe `_legacy_` est un héritage assumé — le renommer casserait l'accord sur
les corpus déjà migrés.

`zMarkAbsent` est **cumulatif** et la restitution est **conservatrice** (une saisie postérieure
l'emporte sur un marqueur périmé), exactement comme côté codec.

⚠️ **Ne retirez vos contournements qu'après avoir migré** les documents porteurs de votre marqueur
app-side : les deux conventions ne se connaissent pas.

### Le §4 du handoff `v0.4.6` est rectifié

Un bandeau d'avertissement a été inséré **au-dessus** du paragraphe fautif, pas à la place : une
équipe qui relira ce document doit tomber sur la rectification **avant** la recommandation. Votre
garde permanente contre une re-suppression reste utile — gardez-la.

**Septième affirmation de cette série écrite sans avoir été exécutée**, et la première portant sur
une instruction d'écriture en production. Le constat est le vôtre, et il est juste.

---

## 2. CR-IFFD-19 · 20 · 21 — trois défauts de la carte que nous avons écrite

Les trois ont été trouvés **en la câblant**. Aucun n'était visible depuis la signature.

```dart
ZStudyToolsItemCard(
  title: 'Note',
  trailing: boutonLireAudio,
  progress: const LinearProgressIndicator(),  // ✅ ne lève plus (CR-20)
  hidesTrailingWhileBusy: false,              // ✅ garde les deux (CR-21)
  borderSide: BorderSide(color: …),           // ✅ liseré (CR-19)
)
```

**CR-20** — le slot était inséré nu dans une `Row` : un `LinearProgressIndicator` y veut une
largeur non bornée et lève. La carte le **borne** elle-même (`progressMaxWidth`, défaut 120) ;
vous n'avez pas à deviner l'exigence. Votre rapprochement avec `crossAxisViewportHeight` est
exact — à ceci près que cette fois nos tests ne l'avaient pas trouvé, parce qu'ils utilisaient la
variante circulaire, qui s'auto-dimensionne.

**CR-21** — vous répondez à la question que nous avions posée, et votre argument est meilleur que
le nôtre : **écouter une note pendant qu'on la résume n'est pas une opération concurrente**.
L'éviction rangeait sous « action » des choses qui sont des consultations. Elle est maintenant une
**politique** (`hidesTrailingWhileBusy`, défaut `true` = comportement actuel préservé).
⚠️ La **seconde divergence** que vous signalez — le legacy *remplace* le bloc titre/sous-titre, le
socle affiche l'indicateur *en plus* — **n'est pas traitée** : c'est une mise en page différente,
pas un défaut de capacité. Dites-nous si elle compte.

**CR-19** — un `shape:` explicite l'emporte sur `CardThemeData.shape` : la forme échappait au
thème, et votre liseré était inatteignable. La carte respecte désormais le thème, avec un slot
`borderSide` prioritaire. **Le défaut est strictement inchangé** — aucun liseré n'apparaît si vous
ne demandez rien.

---

## 3. CR-IFFD-22 — la dérivation devient déclarative

Votre CR demandait l'expressivité, pas une implémentation. **L'investigation a montré plus large
que ce que vous décriviez** : le hook existait **déjà dans la spec du moteur legacy**
(`onChanged` sur le champ), avec **59** usages dans DODLP et **93** dans DLCFTI. Ce n'est pas un
besoin d'IFFD : c'est une capacité que zcrud avait **perdue** en portant le moteur.

Et la dérivation de *valeur* est **minoritaire** : la visibilité (55 `displayCondition`) et les
options pèsent davantage. L'owner a donc arbitré pour **quatre cibles**, en slots séparés :

```dart
ZFieldSpec(
  name: 'title',
  derivedFrom: ZDerivation(
    sources: <String>['folderId'],
    overwrite: ZDerivationOverwrite.always,   // ⚠️ OBLIGATOIRE, aucun défaut
    value:   (v) async => 'Examen: ${await titreDu(v['folderId'])}',
    options: (v) async => …,   // optionnel
    visible: (v) => …,         // optionnel
    bounds:  (v) => ZFieldBounds(min: …, max: …),  // optionnel
  ),
)
```

**Vos deux pièges, traités :**

1. **La sérialisation asynchrone est dans le socle.** Jeton de génération **par champ cible** :
   deux sélections rapprochées qui se résolvent dans le désordre ne peuvent plus s'écraser. Votre
   argument était décisif — vos **deux** dérivateurs, écrits par le même chantier, avaient des
   robustesses différentes (l'un un jeton, l'autre `mounted` seul). C'est la preuve que ça
   n'appartient pas à l'hôte.
2. **La politique d'écrasement est obligatoire à la déclaration.** `always` = parité legacy (100 %
   des ~150 occurrences des quatre dépôts écrasent inconditionnellement) ; `ifPristine` protège
   une saisie manuelle. **Aucun défaut** : l'owner a voulu que la décision se prenne à l'écriture.

**Cycles** — il en existe en production (`dlcfti/ddu_screen.dart:362 ↔ :446`). Un `assert` **nomme**
le cycle en debug, une garde de réentrance coupe la propagation en release. Le cycle reste
**exprimable**.

**`visible` vs `ZCondition`** — ils se **composent en ET**, avec un seul écrivain de
`visibleFields`. `ZCondition` reste la voie par défaut (`const`, sérialisable, émise par le
générateur) ; `ZDerivation.visible` est l'échappatoire pour ce qu'elle ne sait pas exprimer.

---

## 4. Un défaut de notre livraison, trouvé avant de vous l'envoyer

La première version publiait les options dérivées dans une tranche **que le champ ne lisait pas**.
Une spec pouvait déclarer `options` et ne rien voir — sans erreur, sans avertissement. Il fallait
que vous câbliez vous-même `choicesFromKey` sur la clé du canal, et l'oublier était silencieux.

**C'était exactement le défaut de CR-IFFD-18** : annoncer une capacité sur un chemin que personne
n'exécute. `derivedFrom.options` **suffit** désormais ; un `choicesFromKey` explicite reste
prioritaire.

---

## 5. ⚠️ Cinq limites, déclarées — ne les découvrez pas à l'usage

1. **`ZStepperEdition` n'applique PAS `visible`.** Il est le seul écrivain de `visibleFields` et
   compose depuis `ZCondition` seule. Un `assert` **nomme** les champs ignorés en debug. Le
   correctif touche son invariant de single-writer : chantier à part, pas un ajout de passage.
   `value`, `options` et `bounds` fonctionnent normalement sous stepper.
2. **Les bornes de DATE dérivées ne sont pas exécutées.** Le canal est le même
   (`ZDateConfig.minDateKey`/`maxDateKey` lisent `valueOf(key)`), mais nous ne l'avons pas testé.
   Ne le tenez pas pour acquis.
3. **Le piège du FOCUS n'est pas traité.** Votre point n°1 subsiste : le buffer texte n'est
   réécrit que **hors focus**, là où le legacy écrasait inconditionnellement. La CR ne le
   demandait pas explicitement — dites-nous s'il faut le fermer.
4. **`derivedFrom` n'est pas émis par le générateur** (ce sont des closures) : spec écrite à la
   main ou surcharge runtime via `copyWith`. Aucune annotation correspondante.
5. **`bounds` ne couvre que min/max**, pas d'autres formes de contrainte.

---

## 6. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 (11 gates) ·
`zcrud_core` **1063/1063** · `zcrud_study` **540/540** · `zcrud_document` **204/204**.

**Gardes R3 rejouées par l'orchestrateur** (régression injectée → test rouge → restauré) : la
sérialisation asynchrone (« la seconde sélection gagne »), le câblage des options dérivées,
la cumulativité du marqueur d'absence, la borne du slot `progress`, la forme thémée de la carte.

**Rétro-compatibilité** : tous les ajouts ont un défaut neutre — `derivedFrom: null`,
`borderSide: null`, `hidesTrailingWhileBusy: true`, `progressMaxWidth: 120`. Le seul changement de
comportement voulu est CR-20 (le slot linéaire ne lève plus).

---

## 7. Ce que vos vingt-deux CR auront produit

Sept affirmations que nous avions écrites **sans les vérifier** ont été corrigées — dont une
décision d'architecture entière (AD-57) et une instruction d'écriture en production (CR-18). Et
cette livraison-ci contient un huitième cas, que nous avons attrapé nous-mêmes cette fois (§4) :
la même erreur, sur la CR qui sanctionnait cette erreur.

Le motif ne varie pas : **ce qui n'a pas été exécuté n'est pas su.** Continuez à nous le prouver
par exécution — c'est ce qui marche.
