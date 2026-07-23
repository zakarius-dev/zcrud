# Handoff → session `lex_douane` · zcrud **v0.12.0** — CR-LEX-34, 36, 35

> **Tag à épingler : `v0.12.0`**

| CR | Sévérité | État |
|---|---|---|
| **CR-34** — `save()` remplace, aucune écriture préservante | **MAJEUR** | ✅ **LIVRÉE** — `saveMerging`/`putMerged` |
| **CR-36** — clé LWW estampillée à l'horloge client | **MAJEUR** | ✅ **LEVIER LIVRÉ** — `ZClock` injectable (§3) |
| **CR-35** — pas de purge par `id` | mineur | ✅ **LIVRÉE** — `purge(id)` |

Traité dans l'ordre que nous vous avons recommandé : **CR-34 d'abord** (elle solde la famille de
défauts que nous avions rustinée entité par entité en v0.11.0), puis CR-36, puis CR-35.

---

## 1. CR-34 — l'écriture préservante que vous demandiez, au PORT

C'était **la cause racine** de CR-29 et CR-33. Vous l'aviez dit : le défaut « a été payé trois
fois » (ZMindmap, ZExam, ZStudyDocument/Folder). Nos correctifs v0.11.0 traitaient le **symptôme**
par entité ; ceci ferme le **mécanisme**.

Nous avons retenu votre **option 1** — une écriture préservante au port qui relit-et-fusionne côté
zcrud :

```dart
await repo.saveMerging(entity);   // fusionne, ne remplace pas
```

| | `save` (inchangé) | `saveMerging` (nouveau) |
|---|---|---|
| Clés de l'entité | écrivent | écrivent |
| Clés présentes **uniquement** en base (autre hôte, champ hors-codegen) | **détruites** | **préservées** |

La fusion vit dans le **store** (`ZLocalStore.putMerged`) — seule couche qui voit les clés non
mappées. Le port `ZStudyRepository` gagne `saveMerging` (Template Method, **même garantie
`validate`-avant-écriture** que `save`, `@nonVirtual`) et `persistMerging` (point d'extension,
**défaut `Left` explicite** comme `listParentIds` — jamais un repli silencieux sur l'écrasement).

### ⚠️ La limite, dite franchement

**Le merge est ADDITIF : il ne peut pas EFFACER une clé.** Un champ que l'entité omet — y compris
un nullable remis à `null`, que `toMap` omet — est **préservé stale**, pas supprimé. Depuis la
seule map de l'entité, « non mappé » et « volontairement vidé » sont indiscernables. Pour un
effacement, utilisez `save` (remplacement). **Le choix de la voie est par appel** : vous décidez,
site par site, si vous préservez ou remplacez.

### Ce qui n'est PAS couvert

Le push **distant** reste un `set` écrasant : `saveMerging` protège le document **local** (source
de vérité offline-first). Un hôte qui écrirait des clés **uniquement au cloud** sans passer par le
store local n'est pas couvert — hors périmètre offline-first.

> Votre contournement (mapping aller `{required Z? base}` + relire-avant-écrire) peut être retiré
> là où `saveMerging` suffit. Gardez-le là où vous voulez un **remplacement** contrôlé.

---

## 2. CR-35 — `purge(id)`, sans tombstone

```dart
await store.purge(id);   // box.delete(id) — aucune trace, rien à propager
```

Votre analyse était exacte : `softDelete` pose un tombstone (nécessaire pour **propager** une
suppression utilisateur), mais une **annulation d'écriture** (carte refusée, création échouée) n'a
pas à être propagée. `purge` supprime physiquement, **sans** tombstone, et est **idempotent** (un
`id` absent → `Right(unit)`, pas un `NotFound`).

`discardRejected` peut maintenant être migré à l'identique : votre box cesse de croître sans borne
sur les refus, et aucun tombstone de rattrapage ne part au cloud.

---

## 3. CR-36 — le LEVIER qui manquait, pas l'autorité temporelle

Vous aviez raison sur toute la ligne : `updated_at` estampillé à `DateTime.now()` client aux **3
sites** (`hive_z_local_store.dart:194,495`, `z_offline_first_box_repository.dart:361`), et l'hôte
**sans aucun levier** parce que la clé est réservée et strippée.

**Nous vous rendons le levier** — une source de temps injectable, `ZClock` :

```dart
HiveZLocalStore(..., clock: ZSystemClock.offset(monOffsetServeurMesuré));
// ou une horloge NTP-corrigée, ou ZSystemClock.utc (défaut = comportement d'avant)
```

Un hôte qui mesure son décalage serveur à la connexion peut désormais injecter une horloge
**corrigée** — ce qui atténue directement le skew, sans changer la sémantique offline-first (la clé
LWW reste lisible localement, contrairement à un `FieldValue.serverTimestamp()` qui exigerait un
aller-retour serveur).

### ⚠️ Ce que ce n'est PAS, dit clairement

**`ZClock` n'est pas une autorité temporelle commune.** Sans horloge corrigée injectée, le défaut
de convergence **subsiste** — la couture rend le skew **atténuable et testable**, elle ne
l'élimine pas par elle-même. Le remède complet (estampille serveur-autoritaire) reste **une
décision d'architecture** : il échange la lisibilité locale immédiate de la clé LWW contre la
convergence, et mérite l'arbitrage de l'owner avant d'être défaulté. Nous n'avons **pas** changé le
défaut — c'est votre garde-fou contre une régression silencieuse de la sémantique.

Ce que la couture vous donne concrètement, et que vous n'aviez pas : le skew est maintenant
**reproductible dans un test** (deux stores, deux horloges figées — `z_study_convergence_lww_test`
peut cesser de dépendre d'un vrai `DateTime.now()`), et le levier de correction **existe**.

---

## 4. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 (gate `reserved-keys` compris) · dépôt entier
vert.

**14 gardes R3** prouvées mordantes :
- CR-34 : merge additif, préservation de l'existant, `saveMerging`→`persistMerging`, défaut `Left`,
  `validate` bloque l'écriture préservante ;
- CR-35 : `purge` = `box.delete` (contraste tombstone), idempotence ;
- CR-36 : clock aux 3 sites, skew reproductible, défaut système inchangé.

Les gardes CR-34 reproduisent d'abord la **destruction** (contrôle négatif : `put` détruit la clé
de l'autre hôte) avant de prouver la préservation — un test qui ne mordrait pas sur le défaut ne
prouverait rien.

---

## 5. Ce qui reste OUVERT

CR-19, 20, 21, 22, 23, 24, 26, 27, 28, 30, 31, 32 ne sont pas traitées par ce tag. Rappel des deux
points d'information de v0.11.0 : **CR-25 est déjà satisfaite** (`zcrud_study_kernel`), et **CR-12,
13, 18 sont livrées** — vos contournements y sont retirables (CR-18 sous le nom `revealStoredHint`).
