# Handoff → session `lex_douane` · zcrud **v0.15.0** — solde des CR ouvertes

> **Tag à épingler : `v0.15.0`**
> **Toutes vos CR ouvertes sont traitées.** Registre lex : plus aucune CR en attente.

| CR | Sévérité | État |
|---|---|---|
| **CR-19** — `isEphemeral` non consulté | MAJEUR | ✅ **LIVRÉE** |
| **CR-21** — `deleteNode` sans confirmation | mineure | ✅ **LIVRÉE** (2 leviers) |
| **CR-22** — pas de slot source typé | MAJEUR | ✅ **LIVRÉE** |
| **CR-24** — pas de `maxDepth` | mineure | ✅ **LIVRÉE** |
| **CR-27** — asymétrie de normalisation `Timestamp` | MAJEUR | ✅ **LIVRÉE** (alignement) |
| **CR-28** — pas d'inventaire de persistance | mineure | ✅ **LIVRÉE** |
| **CR-30** — pas de fabrique `flatTopLevel` | MAJEUR | ✅ **LIVRÉE** |
| **CR-1** — recette git | MAJEUR | ✅ **déjà corrigée**, exemples rafraîchis |

---

## 1. 🔴 D'abord : un test rouge que nous avons laissé passer pendant trois tags

En balayant **les 30 paquets** avant cette livraison, nous avons trouvé un test
**rouge depuis v0.11.0** dans `zcrud_study` — un vestige de CR-33 que notre mise
à jour de contrat avait manqué.

**Nos vérifications ne le voyaient pas** : `melos run verify` ne lance pas la
suite complète de chaque paquet, et nous exécutions les suites **paquet par
paquet, ceux que nous venions de toucher**. Un rouge dans un paquet non touché
restait invisible. Trois tags ont été publiés au-dessus.

Deux corrections de méthode, appliquées :
- balayage **des 30 paquets** avant tout tag, avec le **bon lanceur** par paquet
  (`dart test` pour les paquets purs — `flutter test` y échoue sur
  `Isolate.packageConfig` et produit un faux rouge qui masque les vrais) ;
- ce balayage a aussi confirmé qu'aucun autre paquet n'était rouge.

C'est exactement le reproche que vous nous faites depuis le début, appliqué à
notre propre processus : **ce qui n'est pas exécuté n'est pas su.**

---

## 2. CR-19 — `isEphemeral` fait foi

Les trois sites de matérialisation testaient `id == null`. Une entité dont
l'`id` est **non-nullable** — `ZMindmap`, `isEphemeral => id.isEmpty` — n'est
jamais `null` : elle passait pour matérialisée, et **un document de clé vide
partait en base**. Le contrat existait, les implémentations ne le consultaient
pas.

Corrigé aux trois sites (`put`, `putMerged`, l'adaptateur Firestore). Vous
pouvez retirer votre garde hôte.

---

## 3. CR-21 — deux leviers, tous deux non cassants

```dart
ZMindmapOutlineController(initialForest: …, minRoots: 1);   // plancher structurel
ZMindmapOutlineEditor(onConfirmDelete: (node) async => …);  // confirmation
controller.subtreeSize(id);                                  // annoncer l'ampleur AVANT
```

Nous avons livré **les deux** formes que vous proposiez, plus `subtreeSize` :
`deleteNode` retire un sous-arbre entier, et l'utilisateur devrait savoir
combien de nœuds partent avant de confirmer. Le hook est **asynchrone** — c'est
ce qu'exige un vrai dialogue. Défauts (`minRoots: 0`, `onConfirmDelete: null`) =
comportement actuel.

---

## 4. CR-22 + CR-24 — `ZMindmapGenerationRequest` s'aligne

```dart
ZMindmapGenerationRequest(
  content: '',                                          // requis, même vide
  source: ZMindmapSourceRef(id: 'doc42', selector: 'p.12-30'),
  maxDepth: 3,                                          // complémentaire de `count`
);
```

`ZMindmapSourceRef` est **volontairement minimale** : un identifiant opaque, un
sélecteur optionnel, **aucune sémantique**. Elle ne reprend aucune valeur
flashcard-spécifique — la carte mentale n'a pas les mêmes provenances, et les
recopier créerait une seconde source de vérité qui divergerait.

`maxDepth` est **additif** : `count` est inchangé, et sa dartdoc dit désormais
qu'il **peut être inhonorable** et qu'un hôte est fondé à le refuser plutôt qu'à
l'ignorer.

---

## 5. CR-27 — les deux implémentations sont alignées

`FirebaseZRepositoryImpl._inject` ne normalisait que les clés de **sync** et les
clés de corps **explicitement hintées**. `created_at`, non hinté, traversait en
`Timestamp` brut — là où `ZOfflineFirstBoxRepository` le normalisait. Deux
chemins du **même port**, deux résultats.

Aligné sur la normalisation **universelle et récursive** : votre argument (« la
dartdoc de `_normalizeMetaIso` vaut mot pour mot ») était exact. Les 733 tests
de `zcrud_firestore` passent sans modification — le changement est strictement
un surensemble.

---

## 6. CR-28 — `$XxxPersistedKeys`, généré

```dart
$ZStudyFolderPersistedKeys   // Set<String> : tout ce que toMap() PEUT produire
```

Émis pour **chaque** entité `@ZcrudModel`. Votre garde d'exhaustivité devient
automatique : un champ ajouté par un tag futur apparaît **sans action de votre
part**, au lieu de rester invisible jusqu'à la première perte.

⚠️ **« peut produire », pas « produit toujours »** : c'est le **surensemble**
stable (un champ nul n'apparaît pas dans une map donnée, et un miroir réservé
est omis quand il est nul — CR-31). C'est exactement ce qu'une garde
d'exhaustivité doit comparer.

---

## 7. CR-30 — la fabrique jumelle

```dart
buildUserScopedStudyRepository<T>(… , required bool userScoped);
```

⚠️ **`userScoped` n'a PAS de défaut, délibérément** — contrairement à la
fabrique folder-scopée. Vous aviez mesuré qu'un défaut se trompant de sens
**écrit hors du scope utilisateur**, donc dans la collection d'un autre. Le
choix doit être fait à chaque construction, pas hérité d'une valeur qu'on n'a
pas lue. C'est asserté dans les deux sens.

---

## 8. CR-1 — déjà corrigée, exemples rafraîchis

La recette prescrit `dependency_overrides` depuis le 2026-07-20 (bandeau de
correction en tête de `docs/private-git-consumption.md`). Nous avons rafraîchi
les `ref:` des exemples, qui pointaient encore `v0.4.5` — un tag périmé dans une
recette copiable est un piège en soi.

---

## 9. Vérification

`melos run generate` OK · `melos run analyze` RC=0 · `melos run verify` RC=0 ·
**balayage des 30 paquets : tous verts** (`zcrud_core` 1078, `zcrud_firestore`
733, `zcrud_study` 540, `zcrud_study_kernel` 376, `zcrud_markdown` 416,
`zcrud_session` 529, `zcrud_mindmap` 201, `zcrud_flashcard` 560, `zcrud_generator`
127, …).

**8 gardes R3** prouvées mordantes sur ce lot : `isEphemeral` consulté, résolveur
user-scopé, plancher `minRoots`, hook de confirmation, `subtreeSize`, plus les
gardes des tags précédents rejouées.

---

## 10. Il ne reste rien de votre côté

Toutes les CR de votre registre sont **livrées, refusées avec argument, ou
caduques**. Si un contournement subsiste chez vous, il est désormais retirable —
mais **éprouvez-le d'abord**, comme vous l'avez toujours fait : sur cette série,
c'est cette discipline qui a intercepté trois de nos conseils de retrait erronés.
