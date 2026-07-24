# Handoff → session `lex_douane` · zcrud **v0.13.0** — CR-LEX-35 révisée, CR-LEX-37

> **Tag à épingler : `v0.13.0`**

| CR | Sévérité | État |
|---|---|---|
| **CR-35 révisée** — `purgeLocalPropagatingTombstone` | mineure (mais piège data-loss) | ✅ **LIVRÉE** + `purge` documentée |
| **CR-37** — bonus overdue inerte | mineure | ✅ **LIVRÉE** — option 1 (câblage), défaut **opt-in** |

---

## 1. Vous aviez raison de ne pas adopter `purge` — et vous nous avez évité de propager le piège

Votre non-adoption était **la bonne décision**, et votre preuve falsifiable
(`z_study_document_discard_rejected_purge_test.dart`) est ce qui l'a établie.

**Notre handoff v0.12.0 disait : « `discardRejected` peut maintenant être migré à l'identique ».
C'était FAUX pour votre cas**, et nous l'avions écrit sans vérifier votre chemin réel : notre
cadrage n'avait retenu que la ligne 170 (`_box.delete`) et manqué la **ligne 172**
(`_softDeleteInFirestore`). Votre carte optimiste **est** poussée au cloud ; c'est le tombstone
cloud qui empêche le pull de la resynchroniser. Un `purge` pur l'aurait retiré ⇒ **résurrection**.

C'est le **troisième conseil de retrait** de notre part que votre discipline « conseil de retrait =
hypothèse à éprouver » intercepte. Elle a encore payé.

### Ce qui est livré

```dart
await repo.purgeLocalPropagatingTombstone(id);
```

| Primitive | cache ne croît pas | propage le tombstone | couvre `discardRejected` |
|---|---|---|---|
| `softDelete` | ❌ | ✅ | votre contournement actuel |
| `ZLocalStore.purge` | ✅ | ❌ | 🔴 résurrection |
| **`purgeLocalPropagatingTombstone`** | ✅ | ✅ | ✅ |

**L'ordre est la correction** : `softDelete` local → propagation **AWAITÉE** → purge locale. Vous
aviez identifié la course exactement : le push du `softDelete` public est fire-and-forget et
**relit** l'entrée locale ; une purge awaitée la retire avant cette relecture, et le tombstone n'est
jamais émis. La propagation est donc attendue **et son succès rapporté** — contrairement au
best-effort qui avale les échecs.

### ⚠️ Hors-ligne : le tombstone local est CONSERVÉ

Si la propagation n'aboutit pas (hors-ligne, chemin non résolu), **la purge est abandonnée** et le
tombstone local reste — on retombe exactement sur `softDelete`. Le retour est `Right` : la
suppression **est** effective des deux côtés du branchement, seule l'économie de place est différée
(le prochain `sync()` propagera). Purger là échangerait une entrée résiduelle contre une
résurrection — l'anti-résurrection prime.

### Second livrable : `purge` porte désormais son avertissement

Votre demande n° 2 est livrée telle quelle. Le dartdoc de `ZLocalStore.purge` porte maintenant un
bloc **🔴 PIÈGE — cette opération ne PROPAGE RIEN**, avec le mécanisme de résurrection, l'échec du
`softDelete`-puis-`purge`, et le renvoi vers la bonne primitive. Aucun autre hôte ne devrait
retomber dedans.

---

## 2. CR-37 — le bonus de retard est câblé (option 1), en **opt-in**

Votre mesure était exacte : `overdueBonusFactor` était déclaré et **jamais lu** — vérifié chez nous
par grep (zéro occurrence dans le scheduler) et par la formule (`interval * ease * modifier`, aucun
terme de retard).

Nous avons retenu **votre option 1** — le câblage, avec le bornage anti-explosion de la variante
IFFD :

```
interval = base + min(round(joursDeRetard * overdueBonusFactor), base)
```

Votre exemple de référence rend exactement **35** (base 25 + bonus 10), et votre preuve d'inertie
est levée : `overdueBonusFactor: 5` change désormais le résultat.

### ⚠️ Le défaut passe de `0.5` à `0.0` — arbitrage owner, et c'est un NON-changement

Le champ *affichait* `0.5` mais était inerte : le comportement **réel** était `0.0`. Le câbler en
gardant `0.5` aurait **allongé silencieusement les intervalles de révision de tous les
consommateurs** (IFFD, DODLP), sur des données d'apprentissage en production, via un simple tag —
sans que personne ne l'ait demandé. Mesuré : 25 → 35 sur une carte en retard de 20 jours, soit
+40 %.

L'owner a tranché pour l'**opt-in** : le défaut décrit ce qui se passe vraiment, et la correction
s'active explicitement.

**Chez vous** : `ZSrsConfig(overdueBonusFactor: 0.5)` vous donne la parité avec votre `Sm2`. Votre
contrôle négatif épinglé (le test qui rougit « si un jour `ZSm2Scheduler` appliquait le bonus »)
**va rougir** dès que vous réglerez 0.5 — c'est le signal attendu, pas une régression.

Bornes préservées, toutes assertées : régimes d'amorçage (`repetitions` 0 et 1 → intervalles fixes
1 puis 6), lapse (échec → 1, le retard ne rachète rien), carte à l'heure ou en avance → aucun bonus,
`nextReviewDate` nulle → aucun bonus, facteur négatif → aucun raccourcissement.

---

## 3. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 · dépôt entier vert — **le contrat SM-2 gelé
(`z_sm2_contract_test.dart`) est passé sans modification**, ce qui borne le changement au seul
régime multiplicatif avec retard.

**10 gardes R3** prouvées mordantes : propagation awaitée avant purge, purge conditionnée au succès,
purge locale effective, `softDelete` préalable ; bonus appliqué, bornage anti-explosion, garde
facteur ≤ 0, garde carte à l'heure, garde `nextReviewDate` nulle, **et le défaut `0.0` lui-même**
(le remettre à 0.5 fait rougir).

Les gardes CR-35 portent un **contrôle négatif** : un test prouve que `purge` seul **ne pose aucun
tombstone cloud** — le piège est épinglé en machine, pas seulement en prose.

---

## 4. Ce qui reste OUVERT

CR-19, 20, 21, 22, 23, 24, 26, 27, 28, 30, 31, 32 ne sont pas traitées. Rappels : **CR-25 est déjà
satisfaite** (`zcrud_study_kernel`) ; **CR-12, 13, 18 sont livrées** (CR-18 sous le nom
`revealStoredHint` — votre port IA reçoit encore `hintsUsed: 0` à tort tant que le contournement
tient).
