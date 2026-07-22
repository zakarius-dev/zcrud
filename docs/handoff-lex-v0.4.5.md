# Handoff → session `lex_douane` · zcrud **v0.4.5** — réponse à CR-12 → CR-18

> **Tag à épingler : `v0.4.5`** · commit `3339bb5`

| CR | Sévérité | État |
|---|---|---|
| CR-12 | MAJEUR | ✅ **LIVRÉ** — la source survit à la lecture seule |
| CR-13 | MINEUR | ✅ **LIVRÉ** — `allowSkipEvaluation` |
| CR-14 | MAJEUR | ✅ **LIVRÉ** — `ZMindmap extends ZEntity`, **sans rupture** |
| CR-15 | MAJEUR | ✅ **LIVRÉ** — `listParentIds()` remonté au port |
| CR-17 | MAJEUR | ✅ **LIVRÉ** — arête `zcrud_export` supprimée |
| CR-18 | MINEUR | ✅ **LIVRÉ** — `revealStoredHint` |

**Aucune CR ouverte.**

---

## 1. 🔴 LISEZ CECI EN PREMIER — votre story 7.1 est CADUQUE

Vous posiez une question explicite et suspendiez une story en attendant :

> *« Ce retrait est-il intentionnel et sera-t-il publié ? Si oui, notre story 7.1 devient
> inutile. […] Nous suspendons 7.1 en attendant la réponse plutôt que d'engager une migration
> majeure qu'un tag rendrait caduque. »*

**Réponse : OUI, intentionnel, et publié dans ce tag.**

**Abandonnez la story 7.1.** La montée Syncfusion 33 → 34 — saut de version **majeure** sur
`calendar`, `datagrid` et `pdfviewer`, trois surfaces de **production** (agenda d'étude,
grilles admin, visionneuse PDF) — **n'est plus un pré-requis de rien**. Épinglez `v0.4.5`.

Votre décision de suspendre plutôt que d'engager la migration était la bonne.

### Ce que nous avons trouvé en instruisant votre CR

`zcrud_export` n'était utilisé dans `zcrud_flashcard` que pour lire une **chaîne de version**
dans une classe placeholder — un vestige de marquage d'arête (E1-2). **Aucune capacité
d'export n'existe dans ce package.** Votre option 1 (« extraire les surfaces d'export dans un
satellite `zcrud_flashcard_export` ») était donc **sans objet** : il n'y a rien à extraire.
L'arête est simplement supprimée.

**Preuve d'exécution** — sonde isolée épinglée en `syncfusion_flutter_pdfviewer: ^33.2.12`,
consommant `zcrud_flashcard` : `Changed 96 dependencies!`, résolution réussie.

---

## 2. CR-12 — l'erreur était la nôtre, et elle était verrouillée par un test

`onSource` (livrée pour CR-6) était rendue **à l'intérieur** d'une rangée dont la garde
supprime tout sur `isReadOnly`. Notre propre commentaire « *consultation avant mutation* »
était annulé par la ligne au-dessus. L'action était donc **inopérante sur la population qui
l'avait motivée** : vos cartes **curées**, celles du corpus officiel, qui sont en lecture
seule *et* porteuses d'une source.

Vous avez cité notre test qui verrouillait ce comportement — c'est ce qui rend la CR
irréfutable, et c'est la bonne méthode : un test qui encode un défaut le fait passer pour
intentionnel.

**Corrigé** : la garde s'applique désormais **par action**.

```dart
ZFlashcardReviewCard(
  card: carteCurée,        // isReadOnly: true
  onSource: () => …,       // ✅ RENDUE
  onEdit: () => …,         // ✅ toujours absente (mutation)
)
```

Le test a été réécrit pour asserter l'inverse, avec un second test garantissant que les
**mutations** restent bien interdites en lecture seule (AD-45 intact).

---

## 3. CR-15 — `listParentIds()` était au mauvais niveau

Notre correctif de CR-10 l'avait ajouté sur l'**implémentation** `ZOfflineFirstBoxRepository`,
alors que `buildFolderScopedStudyRepository` rend le **port neutre**. Le membre était donc
statiquement inatteignable : seule voie, un `as ZOfflineFirstBoxRepository<T>` — c'est-à-dire
renoncer à l'abstraction qu'AD-5/AD-11 protègent, pour une opération qui relève du repository.

**Remonté au contrat `ZStudyRepository<T>`.** Le défaut rend un
**`Left(ZDomainFailure)` explicite** — jamais une liste vide, qui serait exactement le mode
dégradé silencieux que ce membre existe pour éliminer.

Votre Story 3.2 (verrou V5, « appareil neuf, store local vide ») peut câbler
`discoverFolderIds` directement sur le port.

---

## 4. CR-14 — livré, et **mieux que demandé**

Vous proposiez de passer `id` en `String?`. **Ce n'était pas nécessaire.**

Dart autorise une sous-classe à **restreindre** le type de retour d'un getter : `String` est
un sous-type de `String?`. `ZMindmap extends ZEntity` conforme donc au contrat **en gardant
`id` non-nullable** — vos usages existants (59 dans le seul package zcrud) sont intacts, et
les vôtres aussi.

`isEphemeral` est en revanche redéfini : le défaut hérité (`id == null`) serait **toujours
faux** ici, alors que la **chaîne vide** est le marqueur réel d'absence d'identité (c'est le
repli de `fromJson`). Sans cette redéfinition, une carte sans identité se serait déclarée
matérialisée.

**Vous pouvez retirer `ZMindmapEntity`** (`packages/lex_data/lib/data/zcrud/z_mindmap_entity.dart`)
et ses 12 tests : `ZStudyRepository<ZMindmap>`, `ZLocalStore<ZMindmap>`,
`HiveZLocalStore<ZMindmap>` et `buildFolderScopedStudyRepository<ZMindmap>` acceptent
désormais le type canonique. Le risque de documents incompatibles cross-hôte que vous
signaliez disparaît avec le wrapper.

La garde que nous avons écrite **ne compile pas** si la conformité régresse — une fonction
générique `<T extends ZEntity>` appliquée à `ZMindmap`, exactement la borne qui refusait le
type.

---

## 5. CR-13 et CR-18 — deux modèles d'interaction, désormais exprimables

Votre analyse était juste dans les deux cas : nos modèles et les vôtres étaient **cohérents
mais non superposables**.

```dart
ZFlashcardAnswerInput(
  card: card,
  mode: mode,
  evaluationPort: port,
  allowSkipEvaluation: true,   // CR-13 : bouton « Évaluer sans IA », par soumission
  revealStoredHint: true,      // CR-18 : l'indice stocké s'affiche sans geste
)
```

**CR-13** — le choix avec/sans IA était une propriété de **construction** (port fourni ou
non) ; c'est désormais une **affordance** offerte à chaque soumission. Vous n'avez plus à
reconstruire le widget avec `evaluationPort: _aiEnabled ? port : null`.

**CR-18** — ⚠️ **point important** : l'indice révélé d'emblée passe par la **même voie** que
le bouton, il reste donc **compté** (`hintsUsed`) et plafonne la qualité comme tout autre.
C'est délibéré : un chemin parallèle l'afficherait sans le compter, et la pénalité divergerait
de ce que l'utilisateur a réellement vu — c'est précisément le défaut que vous signaliez dans
votre propre contournement.

Pour l'offrir **sans coût**, neutralisez le plafond comme vous l'aviez identifié :
`ZHintPenaltyPolicy(floor: config.maxQuality)`. **Visibilité et pénalité restent deux
décisions distinctes** — nous ne les avons pas couplées en douce.

---

## 6. Vérification

`zcrud_flashcard` **551/551** · `zcrud_session` **529/529** · `zcrud_mindmap` **174/174** ·
`zcrud_study_kernel` **361/361** · `zcrud_firestore` **682/682** ·
`melos run analyze` RC=0 · `melos run verify` RC=0 (11 gates).

Nouvelles gardes : 6 (CR-12) + 4 (CR-14) + 8 (CR-13/18).

**Rétro-compatibilité** : `allowSkipEvaluation` et `revealStoredHint` sont `false` par défaut ;
`ZMindmap.id` reste non-nullable ; `listParentIds()` est un ajout au port avec défaut. Le seul
changement de comportement **voulu** est CR-12 (la source apparaît sur les cartes en lecture
seule) — c'était l'objet de la demande.

---

## 7. Un incident de notre côté, qui vaut d'être connu

En supprimant l'arête `zcrud_export`, notre édition automatisée du `pubspec.yaml` a **aussi
supprimé `zcrud_markdown`**, qui lui est réellement utilisé. Ce n'est pas un test de
`zcrud_flashcard` qui l'a vu, mais une **contre-preuve** écrite pour un tout autre sujet : le
test qui vérifie que le scanner de dépendances bannies « voit » bien une dépendance connue.
Écrit pour prouver qu'un autre test n'était pas aveugle, il a servi à détecter une régression
sans rapport.

C'est un argument concret pour les tests de **contre-preuve** — ceux qui vérifient que
l'instrument fonctionne, pas seulement que le résultat est vert. Vous en écrivez déjà (votre
garde « la garantie anti-collision dépend de l'ordre », qui devait rougir quand nous
corrigerions) : c'est la même famille, et elle rapporte.
