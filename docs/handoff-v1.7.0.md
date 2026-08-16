# Handoff **v1.7.0** — le pli persisté des sections atteint enfin les présentateurs

> **Tag à épingler : `v1.7.0`** — traite le CR « le pli persisté des sections n'est relayé par
> aucun présentateur ». Paquets porteurs : **`zcrud_screen`** et **`zcrud_core`**.
> Release **strictement additive** : sans `collapseStore` déclaré, rien ne change.
>
> 🔴 **`ZStepperEdition` gagne un paramètre public**, au-delà de la cible du CR — §3.

---

## 1. Le manque

`DynamicEdition` portait le seam complet (`collapseStore` + `formId`, lecture et écriture). Aucun
présentateur ne l'exposait : `grep -rn "collapseStore" packages/zcrud_screen/lib/` rendait RC=1.
Le seam était donc inatteignable depuis l'application.

Vous nommez le motif pour la troisième fois — *le socle sait faire, le présentateur ne relaie
pas* — et vous précisez le signaler « parce qu'il se répète, pas pour le reprocher ». Nous
l'entendons ainsi, et nous avons élargi la règle en conséquence : **tout** présentateur montant
`DynamicEdition` relaie désormais le seam, **ou** porte au point de montage la raison de ne pas le
faire. Pas de troisième cas.

## 2. Quatre maillons, pas deux

| Site | Décision |
|---|---|
| `presentFormEdition` | relayé — aux **deux** corps qu'il monte, à plat *et* en étapes |
| `ZFormOnly` | relayé tel quel |
| **`ZStepperEdition`** *(non nommé par votre CR)* | relayé, avec **portée dérivée par étape** |
| **`ZCrudScreen`** *(non nommé)* | **non relayé**, justifié au point de montage |

**Pourquoi pas dans `ZCrudScreen`** — mesuré, pas oublié : son `DynamicEdition` ne reçoit pas de
`sections`, et l'écran n'expose nulle part de quoi en déclarer (`grep "ZEditionSection"` → RC=1).
Rien n'y est repliable ; un store n'y serait jamais lu ni écrit. Le commentaire au point de
montage porte la justification **et** la condition de réouverture.

## 3. ⚠️ La portée par étape — un défaut évité avant d'être écrit

`saveCollapsed(formId, collapsed)` **remplace la portée entière**. Deux étapes partageant un même
`formId` s'effaceraient donc mutuellement. Mesuré par un probe jeté ensuite : replier une section
de l'étape A puis une de l'étape C laisse `{C}` seul — `{A}` **effacé**.

Un relais naïf aurait donc été un défaut par construction. Chaque étape reçoit
`"<formId>/étape:<titre>"` (adressage par titre, comme le reste du seam) ; un sous-assistant dérive
par-dessus. `ZStepperEdition.collapseStore` est donc un **paramètre public neuf**, invisible à la
lecture de votre CR : nous le signalons fort, conformément à notre règle sur les extensions
décidées de notre initiative.

## 4. 🔴 Un défaut dans VOTRE store, trouvé en vérifiant le nôtre

Votre §4.b dit que la déduction des sections dépliées « marche, mais c'est une déduction ». Après
lecture de `dodlp_section_collapse_store.dart` : **c'est une déduction *et* une perte.**

`loadCollapsed` **ignore `formId`** et rend les titres de la boîte **globale**. Votre ensemble
« replis connus » reçoit donc l'état de *tous* les formulaires, et au premier repli la différence
écrit `true` pour **toutes les sections repliées de tous les autres formulaires**. Tant que le seam
était inatteignable, cela ne se voyait pas. **Dès que ce relais servira plus d'un formulaire, cela
se verra.**

Corollaire important : notre portée par étape (§3) **ne vous protège pas** — elle repose sur
`formId`, que votre store n'honore pas.

Nous n'avons **pas** touché au port, comme convenu : ajouter un paramètre à une méthode abstraite
casserait tous les implémenteurs, à commencer par vos 11 gardes. Une voie non cassante existe (une
méthode **concrète** à corps par défaut, sûre pour les `extends`) ; dites-nous si vous la voulez.

## 5. Impact sur votre code

- **Hôte passif** : rien à faire, et c'est gardé par **assertion d'absence d'appel** sur les quatre
  voies — pas seulement par une absence d'effet visible.
- **Vous** : rien à **retirer** (vous n'aviez rien compensé), seulement à brancher — puis à
  corriger le `loadCollapsed` du §4.

## 6. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets).
`zcrud_core` **2197** tests (baseline 2191, +6) · `zcrud_screen` analyze **No issues found**,
**308** tests (baseline 298, +10).

Cinq injections R3, toutes rouges **par assertion**. La plus instructive reproduit l'effacement
croisé du §3 : `Expected: Set:['Alpha'] / Actual: Set:[]`.

🟢 **Un défaut trouvé par l'auteur dans ses propres gardes**, et corrigé : la « relance » simulée
par un nouveau `MaterialApp` fait **réutiliser l'élément `Navigator`** — la fenêtre précédente
restait ouverte et la garde du critère n°1 passait **sans rien prouver**. Remplacée par une relance
qui pompe un widget d'un autre type, avec assertion que l'application précédente a bien disparu.
C'est exactement le genre de garde verte-mais-aveugle que la discipline R3 existe pour attraper.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
