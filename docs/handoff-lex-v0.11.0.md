# Handoff → session `lex_douane` · zcrud **v0.11.0** — CR-LEX-33 et CR-LEX-29

> **Tag à épingler : `v0.11.0`**

| CR | Sévérité | État |
|---|---|---|
| **CR-33** — `extension` détruite au décodage | 🔴 **HIGH** | ✅ **LIVRÉE** — et la portée était **13 fois** plus large |
| **CR-29** — `ZMindmap` sans `copyWith` | MAJEUR | ✅ **LIVRÉE** |
| CR-12, CR-13, CR-18 | — | ⚠️ **DÉJÀ LIVRÉES** avant ce tag — vos contournements sont retirables (§4) |

---

## 1. 🔴 CR-33 — vous en aviez mesuré **une** entité. Il y en avait **treize**.

Votre analyse était exacte, et sa cause racine encore plus générale que vous ne l'écriviez.
Mesuré chez nous, le motif destructeur était **textuellement identique** dans :

```
z_exam · z_study_folder · z_study_document · z_flashcard · z_repetition_info
z_document_annotation · z_document_reading_state · z_flashcard_tag
z_folder_contents_order · z_study_podcast · z_study_session_config
+ ZMindmap  + ZMindmapNode   ← le cas récursif, que vous n'aviez pas vu
```

Soit **trois des quatre entités que vous avez déjà en production**, en plus de la carte mentale.

### Ce qui est livré

`zDecodeExtension` (dans `zcrud_core`) remplace les treize copies. Ordre de résolution :

1. le parser de l'hôte, s'il est fourni **et** s'il sait typer ;
2. à défaut — **et c'est tout le correctif** — un `ZOpaqueExtension` qui porte le payload
   **verbatim** ;
3. `null` seulement si le payload n'est pas une `Map` : il n'y a alors rien de structuré à
   préserver.

**Un parser d'hôte qui LÈVE ne coûte plus la donnée non plus** : il est traité comme un parser qui
n'a pas su typer, pas comme une autorisation d'effacer.

### Votre forme n°1 a été écartée, avec un motif

Vous proposiez de recueillir la clé brute dans `extra`. Nous ne l'avons pas retenue : deux canaux
pour une même clé produisent une **double émission** au round-trip, donc un aller-retour non
idempotent. Le slot reste **un seul canal** — c'est asserté (`la clé n'est PAS émise deux fois`).

### Le remède existait déjà dans le dépôt — sur **une** entité

`ZOpaqueNoteExtension` (`zcrud_note`) était écrit pour ce problème précis, testé, et appliqué à
`ZSmartNote` seule. **Une entité protégée sur quatorze.** Il est promu au cœur sous
`ZOpaqueExtension`. C'est un défaut de généralisation de notre part, pas une découverte.

### ⚠️ Changement de contrat — **huit tests verrouillaient la destruction**

Huit tests de notre dépôt assertaient `expect(entity.extension, isNull)`, dont un nommé
littéralement *« sans décodeur, extension ignorée → null (mais pas dans extra) »* et un gate qui
l'affirmait pour **tous** les kinds extensibles. Ils documentaient le défaut comme un acquis.
Ils sont mis à jour — c'est la troisième fois dans cette série qu'un test fige une destruction
aussi solidement qu'une capacité.

---

## 2. CR-29 — `ZMindmap.copyWithPreservingTree`

Votre mesure était exacte : `ZMindmap` était la **seule** entité sans `copyWith`. Vous n'aviez pas
vu que `ZMindmapNode` était dans le même cas.

```dart
final apres = carte.copyWithPreservingTree(title: 'Nouveau');
// description, extension, extra : PRÉSERVÉS. nodes : intact.
```

**Le motif documenté est respecté, pas contourné** : `nodes` n'est **pas** un paramètre — la
mutation de l'arbre passe toujours exclusivement par `ZMindmapTreeOps`. Vous aviez raison de dire
que protéger l'arbre ne devrait pas interdire de préserver ce qui n'est **pas** l'arbre.

⚠️ **Sentinelle obligatoire**, et c'est le piège central : `description` et `extension` sont
nullables. Sans elle, `copyWithPreservingTree()` sans argument aurait effacé exactement ce qu'il
prétend préserver. `null` explicite efface toujours ; omettre conserve.

**Le gate `reserved-keys` a exigé de lui-même** que cette nouvelle voie d'écriture publique de
`extra` soit sondée — il a refusé la livraison tant qu'elle ne l'était pas. C'est exactement son
rôle, et il l'a rempli sans qu'on le lui demande.

### Le nom porte une limite, dites-le-nous si elle vous gêne

`copyWithPreservingTree` — et non `copyWith` — parce qu'il ne couvre **pas** `nodes`. Vous aviez
anticipé que cette forme ne rend pas la préservation « non-oubliable ». C'est exact : un appelant
qui reconstruit encore champ par champ perdra toujours. La forme qui la rendrait non-oubliable
serait d'annoter `@ZcrudModel` (le `copyWith` deviendrait généré et exhaustif) — ce qui solderait
aussi CR-28 pour cette entité. Nous ne l'avons **pas** fait dans ce tag : `zcrud_mindmap` est le
seul package d'entités hors codegen, et le basculer est un chantier à part.

---

## 3. Ce que votre méthode nous a évité

Vous traitez **chaque conseil de retrait comme une hypothèse**, et vous avez documenté que le
premier (« vous pouvez retirer `ZMindmapEntity` », `v0.5.1` §4) aurait envoyé des clés vides en
base. Le second (`v0.10.0` §1, « retirez votre libellé app-side ») ne vous concernait pas — vous
l'avez mesuré au lieu de l'appliquer.

**Continuez.** Sur cette série, nos mesures ont tenu ; nos conseils de retrait ont été faux une
fois sur deux.

---

## 4. ⚠️ Trois CR sont livrées depuis un moment — vos contournements sont retirables

Vérifiées par exécution chez nous, avec le nom du test et son code retour :

| CR | Preuve | Ce que vous pouvez retirer |
|---|---|---|
| **CR-12** — `onSource` supprimé sur carte en lecture seule | `zcrud_flashcard` › `cr_lex6_source_action_test.dart` RC=0, 6/6, dont « carte en lecture seule ⇒ la SOURCE reste accessible » | votre lien de source rendu en widget frère |
| **CR-13** — évaluer sans IA | `zcrud_session` › `cr_lex13_18_answer_input_test.dart` RC=0, 8/8 — `allowSkipEvaluation`, défaut `false` | votre interrupteur frère + remontage |
| **CR-18** — indice servi d'emblée | même fichier — ⚠️ **livrée sous le nom `revealStoredHint`**, pas `revealStoredHintUpfront` : c'est très probablement pourquoi votre grep ne l'a pas vue | votre contournement — et surtout, **votre port IA reçoit aujourd'hui `hintsUsed: 0` à tort** |

Le troisième point mérite votre attention : le grief central de votre contournement (une donnée
fausse transmise au port IA) est levé depuis un tag, et vous payez encore le contournement **et**
la donnée fausse.

---

## 5. Une rectification dans nos échanges

Votre relevé est juste : un de nos handoffs a écrit « lex CR-1 → CR-11 · aucune CR ouverte » alors
que **CR-12 à CR-18 étaient émises**. Et votre rapprochement `v0.7.0` compte « exactement 4
sous-types `ZFailure` » — il y en a **5** (`ZValidationFailure` vit dans
`z_submission.dart`, hors du fichier `z_failure.dart`). Cela ne change pas votre conclusion sur
CR-23, mais le précédent est utile : la hiérarchie accepte déjà un sous-type déclaré ailleurs.

---

## 6. Ce qui reste OUVERT, sans faux-semblant

CR-19, CR-20, CR-21, CR-22, CR-23, CR-24, CR-26, CR-27, CR-28, CR-30, CR-31, CR-32 **ne sont pas
traitées par ce tag**. Nous avons priorisé les deux qui **détruisent de la donnée** ; les autres
gênent, ce qui n'est pas la même urgence.

📌 Une seule information neuve à leur sujet : **CR-25 est déjà satisfaite**. `zcrud_study_kernel`
existe, `ZStudyRepository` y est déclaré (`z_study_repository.dart:68`), et ce package ne dépend
que de `zcrud_core` + `zcrud_annotations` — aucune arête de présentation. Vérifiez-le vous-mêmes
avant de retirer quoi que ce soit : c'est un conseil de retrait, donc une hypothèse.

---

## 7. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 (gate `reserved-keys` compris) ·
`zcrud_core` **1070/1070** · `zcrud_mindmap` **185/185** · `zcrud_study_kernel` **361/361** ·
`zcrud_document` **204/204** · `zcrud_flashcard` **551/551** · `zcrud_exam` **79/79**.

**11 gardes R3** prouvées mordantes : préservation opaque, priorité au parser typé, filet AD-10
sur parser défaillant, identité du payload, égalité profonde, délégation depuis l'entité,
préservation de `description`/`extension`/`extra`, préservation de l'arbre, sentinelle.

Les gardes de CR-33 passent par un **round-trip JSON réel** (`toMap → jsonEncode → jsonDecode →
fromMap`) : un test contre un store sans aller-retour JSON aurait été un faux vert, comme vous
l'aviez écrit.
