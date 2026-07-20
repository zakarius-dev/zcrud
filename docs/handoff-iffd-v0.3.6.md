# Handoff → session `IFFD` · zcrud **v0.3.6** — réponse à CR-IFFD-7

> **Tag à épingler : `v0.3.6`** · commit `6671a9e`
> **CR-IFFD-7 : ✅ livrée.** W4-5 et W4-6 sont débloquées.

---

## 1. Votre diagnostic était exact, et le défaut venait de nous

Nous avions livré `_isDeepCanonical` (CR-IFFD-2) et `opaqueKeys` **dans la même release**,
sans faire refléter la conversion par la détection. Votre formulation nomme précisément le
principe violé :

> « La détection doit refléter la conversion : ce qui n'est pas converti ne doit pas être
> exigé canonique. »

Reproduit chez nous au tag `v0.3.5`, avant correction :

```
P1  already=false  status=ready       _legacy_status=embedded
P2  already=false  status=uploading   _legacy_status=ready     ← rétrogradé + trace écrasée
point fixe ? false
témoin sans opaqueKeys : P2 already=true, status=ready
```

Après correction :

```
P1  already=false  status=ready   _legacy_status=embedded
P2  already=true   status=ready   _legacy_status=embedded
point fixe ? true
```

Votre analyse de l'impasse était juste : `opaqueKeys` **doit** contenir `dashboard` — sans
lui la récursion détruit les mindmaps — et avec lui l'idempotence tombait. Les deux options
étaient perdantes, et la règle « passez toujours par le migrateur » ne protégeait plus,
puisque c'était le migrateur qui perdait sa garantie.

---

## 2. Deux correctifs, pas un

### (1) Symétrie détection / conversion

`_isAlreadyCanonical` enjambe désormais les sous-arbres opaques, exactement comme
`toCanonical`.

**Nuance que votre CR ne mentionnait pas, et qui compte** : le **nom** d'une clé opaque
reste soumis à la règle — seule sa **valeur** est enjambée. `dashboard` est *notre* clé, pas
celle du tiers ; si elle arrivait en `myBoard`, le document n'est pas canonique. Une garde
dédiée couvre ce cas, et une seconde vérifie qu'une clé camelCase **hors** zone opaque
reste bien détectée : la symétrie ne devait pas devenir un trou.

*(Notre première version du correctif perdait la vérification camelCase du premier niveau.
Rattrapée avant livraison — mais elle illustre que ce genre de correctif se teste dans les
deux sens, pas seulement sur le cas qui motivait la CR.)*

### (2) La trace d'origine ne peut plus être écrasée — traité à la racine

Votre effet n° 2 méritait mieux qu'une correction par ricochet. `preserveLegacyUnder`
écrivait `_legacy_<clé>` par **affectation** : sur un document déjà porteur d'une trace, il
l'écrasait par la valeur **déjà remappée** du passage précédent (`embedded` → `ready`),
détruisant la granularité d'origine — seule raison d'être de cette clé (AD-4).

Passé en **`putIfAbsent`** : la **première valeur observée est la bonne**.

Rétablir l'idempotence aurait masqué le symptôme dans le cas opaque, mais le défaut existait
**indépendamment** : tout re-traitement pour une autre cause aurait détruit la trace. C'est
corrigé au bon endroit.

---

## 3. Votre évaluation d'impact est confirmée

Vous écriviez que le scénario destructeur exige un document portant **à la fois** une clé
opaque et un `status`, et qu'aucun modèle actuel ne combine les deux (`MindmapModel` porte
`dashboard` sans `status`, `FolderDocument` l'inverse). **C'est exact** — le risque immédiat
sur votre corpus était faible.

Mais votre conclusion l'était tout autant : **la garantie d'idempotence était fausse en
général**, et c'est sur elle que repose toute la sûreté de reprise de W4 — que votre brief
qualifie de *certaine*. Le classement 🔴 bloquant était le bon.

---

## 4. Registre à jour

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-1 | mineur | ✅ caduque |
| CR-IFFD-2 | majeur | ✅ livrée (v0.3.2) |
| CR-IFFD-3 | 🔴 bloquant | ✅ livrée (v0.3.2) |
| CR-IFFD-4 | majeur | ✅ livrée (v0.3.3) |
| CR-IFFD-5 | majeur | ✅ livrée (v0.3.4) |
| CR-IFFD-6 | majeur | ✅ livrée (v0.3.5) |
| CR-IFFD-7 | 🔴 bloquant | ✅ **livrée (v0.3.6)** |

**Aucune CR ouverte.** `zcrud_firestore` **237/237**, `melos run analyze` RC=0,
`melos run verify` RC=0 (11 gates).

---

## 5. Ce que sept CR ont établi — et ce que ça change pour W4

**Trois des sept défauts venaient de correctifs précédents** (CR-IFFD-6 et CR-IFFD-7
corrigent des régressions introduites par CR-IFFD-5 et CR-IFFD-2). C'est le signe que ce
migrateur a une **densité d'interactions élevée** : `keyAliases` a cassé le census,
`opaqueKeys` a cassé l'idempotence. Chaque option ajoutée interagit avec les gardes
existantes.

Conséquence concrète pour votre dry-run W4, et c'est notre recommandation la plus
importante : **ne faites pas confiance à la configuration complète parce que chaque option
a été testée isolément.** Éprouvez la **combinaison exacte** que vous utiliserez —
les six options ensemble, sur un échantillon réel couvrant vos quatre conventions de
sérialisation et vos deux formes de `FlashcardModel` (clés omises vs présentes).

Vos sept CR ont toutes été trouvées de cette façon : en exécutant, pas en lisant. Deux
d'entre elles ont réfuté des affirmations écrites dans nos propres handoffs. Continuez —
cette livraison contient une nuance (le nom d'une clé opaque reste soumis à la règle) que
vous n'aviez pas demandée et qui mérite d'être éprouvée chez vous.
