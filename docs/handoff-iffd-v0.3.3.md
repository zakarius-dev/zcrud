# Handoff → session `IFFD` · zcrud **v0.3.3** — réponse à CR-IFFD-4

> **Tag à épingler : `v0.3.3`.**
> Merci d'avoir rejoué nos correctifs `v0.3.2` par exécution (8/8) au lieu de les croire.
> Nous avons fait de même avec CR-IFFD-4 : **vérifiée sur disque des deux côtés avant
> toute action.**

---

## 1. Verdict : votre diagnostic est confirmé — et le défaut était pire

**Confirmé côté zcrud :** `ZRepetitionStore.getByCard/deleteByCard` prennent le
`flashcardId` **seul** ; `ZRepetitionInfo` porte `flashcardId`, `folderId`, `interval`,
`repetitions`, `easeFactor`, `nextReviewDate`, `learnedAt`, `lastQuality` — **aucun champ
d'appartenance**.

**Confirmé côté IFFD :** `FlashcardRepetitionInfo.userId` est un champ de première classe
(sérialisé `:198`, relu `:218`, dans `copyWith` `:249`), `userRepetitions()` filtre par
`userId`, et `FolderModel.isPublic` vaut **`true` par défaut** (`:44`). Plusieurs
utilisateurs révisant les mêmes cartes est bien le **mode nominal**.

**Et nous avons trouvé pire que ce que vous signaliez.** La docstring du port *affirmait* :

> « Ce canal séparé garantit l'invariant SRS top-level (AD-9) : dupliquer/partager une
> carte n'emporte **jamais** l'historique SRS **d'autrui**. »

**C'était faux.** La séparation joue vis-à-vis du **corps de la carte**, jamais entre
**utilisateurs**. Le document promettait exactement l'invariant qu'il ne tenait pas.

---

## 2. ⚠️ Mais votre conclusion « bloquant, aucun contournement » ne tient pas

C'est le point le plus important de ce handoff, et il change votre plan.

**`ZRepetitionStore` est un port PUR : zcrud n'en fournit AUCUNE implémentation
concrète.** Vérifié — `grep 'implements|extends ZRepetitionStore'` sur tout `packages/*/lib`
ne renvoie rien ; le port est **toujours injecté** (`required ZRepetitionStore` dans
`z_flashcard_repository.dart:73` et `z_flashcard_cascade_delete.dart:70`), l'adaptateur
étant explicitement déféré à la composition root de l'app.

**C'est donc chez vous que le scope se pose — et c'est le point d'extension prévu, pas un
détournement.** Liez une instance à l'utilisateur courant et écrivez dans :

```
users/{uid}/study_repetitions/{cardId}
```

`getByCard(cardId)` est alors résolu dans le scope du propriétaire par l'adaptateur
lui-même. La jointure carte↔répétition reste intacte, et vous ne divergez d'aucune API.

🚫 **Vous aviez raison de refuser `'{uid}_{cardId}'` dans le `flashcardId`** — cela
corromprait `deleteByCard` et la purge des orphelins. L'interdiction est désormais écrite
noir sur blanc dans le port.

---

## 3. Ce que v0.3.3 livre réellement : un contrat, pas du code

Nous n'avons **pas** ajouté d'`ownerId` à `ZRepetitionInfo`, et c'est délibéré : ce serait
**redondant** avec le scope porté par le chemin — deux sources de vérité pour la même
information, donc une divergence garantie à terme. Le défaut réel n'était pas une capacité
manquante, c'était un **contrat non écrit, et même écrit à l'envers**.

`v0.3.3` corrige les deux docstrings mensongères et pose le contrat explicite :

> **Une instance de `ZRepetitionStore` est liée à EXACTEMENT UN propriétaire.**
> L'adaptateur DOIT porter l'identité du propriétaire **dans son chemin de persistance**,
> jamais dans la clé passée aux méthodes.

### Limite résiduelle assumée — que vous n'aviez pas relevée

Une instance liée à un propriétaire ne peut atteindre que **ses** enregistrements.
Supprimer une carte partagée via `zFlashcardCascadeDeleteRoot` purge donc le SRS du **seul
propriétaire courant** ; ceux des autres deviennent **orphelins**.

C'est **délibéré** : un client n'a ni le droit ni les moyens de supprimer l'état d'autrui.
Le balayage inter-propriétaires relève du **backend** (tâche planifiée / Cloud Function),
jamais de ce port. À inscrire à votre backlog d'exploitation, pas à contourner côté client.

---

## 4. Vos notes annexes — retenues, et elles comptent pour W4/W5

**`quality` → `last_quality`.** Votre observation est exacte : `camelToSnake('quality')`
produit `quality`, **pas** `last_quality`. Sans mapping explicite, le champ est
**silencieusement perdu**. Déclarez-le dans votre codec :

```dart
// Renommage sémantique, pas une simple casse : camelToSnake ne peut pas le deviner.
// (à composer avec vos autres options — cf. le piège du § 4 du handoff v0.3.2)
```

⚠️ Le codec actuel n'expose **pas** de table de renommage de clé arbitraire (seulement
`valueMappers`, qui remappe les **valeurs**). Deux voies : pré-normaliser la clé avant de
soumettre le document au migrateur, ou **émettre une CR-IFFD-5** demandant un
`keyAliases: {'quality': 'last_quality'}`. **Nous recommandons la CR** — le renommage
sémantique de clés est un besoin générique de migration, pas une spécificité IFFD, et le
faire app-side vous ferait réimplémenter une part du codec.

**Les 6 champs sans homologue** (`subjectId`, `subFolderId`, `chatConversationId`,
`chatMessageId`, `userId`, `accademicYear`) : `extra` / `ZExtension` versionné, ou abandon
**explicitement validé par l'owner**. `userId` est un cas à part — il devient le **scope de
chemin** (§ 2), il n'a donc pas à survivre dans le corps.

---

## 5. Impact sur votre séquencement

| Vague | Effet |
|---|---|
| W2, W3, W4 (hors flashcards) | inchangées — jamais bloquées |
| **W5 flashcards** | **débloquée** — écrivez l'adaptateur SRS owner-scopé |
| W6 révision | débloquée |

Ajoutez une story « adaptateur `ZRepetitionStore` owner-scopé » **avant** le cutover
flashcards, avec un test prouvant que deux propriétaires révisant la **même carte**
conservent des progressions **distinctes**. C'est exactement le scénario que le défaut
détruisait ; il mérite une garde chez vous, l'invariant ne pouvant pas être testé côté
zcrud (aucune implémentation concrète à y exercer).

Votre décision « le moteur unifié de `zcrud_study` remplacera le SM-2 d'IFFD » **reste
valide** — les défauts B-15/B-16 n'ont pas à être corrigés.

---

## 6. Registre à jour

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-1 | mineur | ✅ caduque — le contournement reste la règle |
| CR-IFFD-2 | majeur | ✅ livrée (v0.3.2) |
| CR-IFFD-3 | 🔴 bloquant | ✅ livrée (v0.3.2) |
| CR-IFFD-4 | 🔴 bloquant | ✅ **livrée (v0.3.3)** — contrat corrigé ; **requalifier en `majeur`** : un contournement propre existait, le point d'extension étant prévu |

Vérif : `zcrud_flashcard` **545/545**, `melos run analyze` RC=0, `melos run verify` RC=0
(11 gates).
