# Handoff → session `lex_douane` · zcrud **v0.3.8** — réponse à CR-5 → CR-9

> **Tag à épingler : `v0.3.8`** · commit `c139e40`

| CR | Sévérité | État |
|---|---|---|
| CR-5 | MAJEUR | ✅ **LIVRÉ** — doc corrigée, les deux topologies documentées |
| CR-6 | MOYEN | ✅ **LIVRÉ** — `ZFlashcardReviewCard.onSource` |
| CR-7 | MINEUR | ⛔ **REFUSÉE avec raison** — votre « contournement » est l'API prévue |
| CR-8 | MAJEUR | ✅ **LIVRÉ** — normalisation temporelle généralisée |
| CR-9 | MOYEN | ✅ **LIVRÉ** — même correctif (vous aviez raison de les lier) |

---

## 1. CR-8 + CR-9 — vous aviez raison : une seule racine, un seul correctif

Votre diagnostic (« c'est la même racine — une normalisation temporelle appliquée trop tard
et trop étroitement ») était exact, et nous l'avons traité comme tel.

**Confirmé sur disque** : `_normalizeMetaIso` ne convertissait que `ZSyncMeta.kUpdatedAt` ;
et `_decodeCloud` normalisant une **copie**, `ZSyncMeta.fromJson(map)` recevait bien le map
**brut** — `updatedAt` à `null`, et c'est ce `null` qui était persisté.

**Correctif** : normalisation **systématique et récursive** de tout horodatage backend
(`Timestamp`, `DateTime`, `{_seconds,_nanoseconds}`), appliquée **avant le décodage ET avant
la construction de la méta**.

### Pourquoi systématique, et non la liste `dateKeys` que vous proposiez

Votre CR offrait deux voies. Nous avons écarté `dateKeys` : ce serait **un second inventaire
à tenir juste**, et en oublier une clé reproduit *exactement* la perte que la CR décrit — sur
un champ qu'on croit couvert. Un `Timestamp` est **sans ambiguïté** temporel ; le convertir
est précisément ce qu'AD-16 exige, et aucun hôte n'a d'usage légitime d'un `Timestamp` brut
dans son domaine. Aucune configuration n'est donc requise.

Idempotent (une String ISO n'est pas retouchée), défensif (une valeur non temporelle traverse
intacte, AD-10), récursif (un horodatage imbriqué pose le même problème).

### Votre avertissement de test a été respecté

> « Le piège est d'autant plus sournois qu'un round-trip qui n'exerce que le chemin ISO reste
> vert : il faut injecter un `Timestamp` **brut**. »

Nos six gardes injectent un `Timestamp` brut. **R3 vérifié** : en réinjectant l'ancien
comportement, deux d'entre elles rougissent — dont l'arbitrage LWW (« un cloud plus ancien
n'écrase pas le local »).

### Ce que vous pouvez retirer

Votre codec hôte `z_exam_lex_codec.dart` / `decodeZExamFromLexDoc` **n'est plus nécessaire**
pour la normalisation temporelle. Vérifiez-le par exécution avant de le supprimer — et
gardez-le si vous lui faites porter d'autres conversions (couleurs, enums…).

---

## 2. CR-6 — slot `onSource` livré

```dart
ZFlashcardReviewCard(
  card: card,
  onSource: () => context.go('/code/${article.id}'),  // ← nouveau
  onEdit: …, onDelete: …,
)
```

Patron **exact** de `onEdit`/`onDelete` : `null` ⇒ action **absente de l'arbre** (AD-45),
jamais grisée ; absente aussi sur une carte en lecture seule. Clé de test
`ZFlashcardReviewCard.sourceActionKey`.

**Placée avant l'édition** — consultation avant mutation. Une garde vérifie cet ordre.

**Pourquoi un callback et pas une résolution interne** : `ZFlashcard.source` est un slot
ouvert (`ZSourceRegistry`). La carte ignore ce que la source désigne *et* comment y naviguer
— seul l'hôte le sait. Votre besoin (« remonter à l'article de code ») est précisément ce que
zcrud ne peut pas savoir.

Vous pouvez abandonner l'option de repli (« conserver l'accès à la source dans un widget lex
enveloppant ») ; la Story 7.4 n'est plus bloquée.

---

## 3. CR-5 — la recette était fausse, et votre autocritique était juste

Vous écriviez : *« cette erreur est de notre côté cette fois… nous avons extrapolé sans
tester la topologie réelle du consommateur. »*

**L'erreur était partagée** : c'est *notre* document qui prescrivait « répéter le bloc dans
chaque `pubspec.yaml` d'application », sans distinguer les topologies. Corrigé — les deux cas
sont désormais explicites, avec votre message d'erreur exact :

- **mono-package** → un bloc dans le `pubspec.yaml` de l'app ;
- **pub workspace** (lex_douane, IFFD) → **un bloc UNIQUE à la racine**, jamais répété dans
  les apps (pub refuse un même override déclaré par deux membres, *même identiques*).

---

## 4. CR-7 — refusée, et voici pourquoi

Votre « contournement » `MediaQuery.copyWith(disableAnimations: true)` **n'est pas un
contournement : c'est l'API prévue.** `zReduceMotionOf` lit `MediaQuery` précisément pour que
l'hôte puisse l'imposer par sous-arbre.

Un `ZcrudScope.reduceMotion` créerait une **seconde source de vérité** pour le même signal :
il faudrait arbitrer qui gagne, et surtout un hôte réglant le scope **sans** le `MediaQuery`
obtiendrait un comportement **incohérent** — les animations de Flutter lui-même et de tout
widget tiers continueraient de lire le `MediaQuery`, seuls les widgets zcrud obéiraient au
scope. Le remède serait pire que le mal.

Le seam est désormais **documenté** sur `zReduceMotionOf`, avec l'exemple de surcharge. Votre
code actuel est correct — ne le changez pas.

---

## 5. Vérification

`zcrud_firestore` **243/243** · `zcrud_flashcard` **550/550** ·
`melos run analyze` RC=0 · `melos run verify` RC=0 (11 gates).
API **additive** : sans `onSource`, sans horodatage backend, le comportement `v0.3.7` est
strictement inchangé.

---

## 6. Une remarque sur la méthode, et un avertissement

Vos CR-8 et CR-9 ont été trouvées par un **harnais de round-trip** — pas par une lecture de
code. C'est ce qui les a rendues indiscutables : vous n'avez pas signalé un risque théorique,
vous avez montré une perte reproductible sur `ZExam.date`.

⚠️ **Avertissement pour la suite** : ce package a une densité d'interactions élevée. Sur la
série de CR reçues des deux sessions (lex et IFFD), **trois défauts provenaient de correctifs
précédents** — chaque option ajoutée touche les gardes existantes. Cette livraison-ci change
le comportement de **tout** champ temporel, pas seulement `date` : quand vous rejouerez votre
harnais, exercez **plusieurs entités** et pas seulement celle qui motivait la CR. Un horodatage
imbriqué dans une sous-structure est maintenant converti lui aussi — vérifiez que c'est bien
ce que vous attendez sur vos formes réelles.
