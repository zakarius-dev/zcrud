# Handoff → session `lex_douane` · zcrud **v0.4.0** — réponse à CR-10 et CR-11

> **Tag à épingler : `v0.4.0`** · commit `1e4ba5e`
> **Version MINEURE** (et non patch) : CR-11 déprécie 4 symboles publics.

| CR | Sévérité | État |
|---|---|---|
| CR-10 | MAJEUR | ✅ **LIVRÉ** — `listParentIds()` + `resolveParentCollection()` |
| CR-11 | MOYEN | ✅ **LIVRÉ** — préfixe `Z`, anciens noms dépréciés (rien ne casse) |

---

## 1. CR-11 — le préfixe `Z` s'arrêtait aux `Failure`, et vous en payiez le prix

Votre relevé était sans appel : **4 collisions sur 4**, et ce ne sont pas des noms
exotiques — `ServerFailure`/`CacheFailure`/`NotFoundFailure`/`DomainFailure` sont *la*
nomenclature Clean Architecture + `dartz`.

Votre remarque la plus juste est celle qu'on aurait pu manquer : **nos deux conseils se
contredisaient.** CR-4 recommandait l'import **nu** du barrel (pour lever l'ambiguïté
`Right`/`dartz`) ; la collision imposait un `show` restreint, qui annule l'intérêt du barrel
et doit être maintenu **à la main** à chaque nouveau symbole zcrud utilisé.

### Ce qui change

Renommage en **`ZDomainFailure`**, **`ZCacheFailure`**, **`ZNotFoundFailure`**,
**`ZServerFailure`** (316 usages, 74 fichiers). **Les anciens noms survivent en `typedef`
dépréciés** : votre code compile sans modification.

### Votre sortie, maintenant

```dart
import 'package:zcrud_core/zcrud_core.dart'
    hide DomainFailure, CacheFailure, NotFoundFailure, ServerFailure;
```

**Une liste `hide` FIXE de 4 noms**, qui ne grandira jamais — au lieu d'un `show` à étendre
à chaque symbole. Vous retrouvez l'import nu recommandé par CR-4, sans collision. Les
`ZFailure` que vous manipulez prennent leur nom préfixé.

Les alias seront retirés dans une **majeure** ultérieure ; la collision disparaîtra alors
d'elle-même, et le `hide` deviendra inutile.

---

## 2. CR-10 — « succès silencieux » : votre formulation était la bonne

C'est ce qui rendait le défaut grave, plus que le no-op lui-même : `sync()` rend
`Right(unit)`, aucun log, l'utilisateur voit une liste vide — **indiscernable de « il n'a
rien »** alors que ses données sont intactes au cloud. Et la découverte était bien
**circulaire** : seule source côté hôte = le store local, donc un appareil neuf ne
redescendait jamais rien.

### Ce qui est ajouté

**Deux pièces, séparées selon la nature des composants** :

```dart
// 1) Le RÉSOLVEUR reste PUR — il rend un chemin, n'interroge rien (AD-5).
ZResult<String> resolveParentCollection({required String kind, String? userId});
//    → 'users/{uid}/study_folders'

// 2) Le REPOSITORY exécute la requête — c'est lui qui possède Firestore.
Future<ZResult<List<String>>> listParentIds();
//    → Right(['f1', 'f2'])
```

Signature **nue** : aucun type `cloud_firestore`. **`Left` explicite** si la topologie n'est
pas *nested* ou si le `userId` manque, **`Left(ZServerFailure)`** sur panne réseau — **jamais
une liste vide silencieuse**, précisément le mode que cette API existe pour éliminer.

### Vous pouvez retirer votre contournement

`packages/lex_data/lib/data/zcrud/z_exam_seam.dart` → `discoverStudyFolderIds()` n'a plus
lieu d'être. Vous signaliez vous-même qu'il **perçait l'isolation backend AD-5/AD-11** en
manipulant `FirebaseFirestore` côté hôte pour une opération relevant du repository — c'était
exact, et c'est refermé.

⚠️ **Gardez votre repli**, en revanche : sur panne réseau, `listParentIds()` rend un `Left`
plutôt qu'une liste vide. Votre union « découverte cloud ∪ dossiers locaux » reste la bonne
stratégie — elle a maintenant une source cloud propre au lieu d'un accès direct.

### Ce que nous n'avons PAS fait, et pourquoi

Votre CR offrait une seconde voie : « un `ZStudyRepository` **multi-dossiers** dont `sync()`
itère lui-même les parents ». Écartée pour l'instant — cela changerait la **sémantique** d'un
repository (aujourd'hui : une instance = une portée), et un `sync()` qui itère N dossiers
soulève des questions que la CR ne tranche pas : ordre, échec partiel, volumétrie, quota.
`listParentIds()` vous donne la brique sans figer ces décisions. Si le câblage manuel s'avère
répétitif à l'usage, ré-émettez une CR avec le comportement attendu sur l'échec partiel —
c'est le point qui décidera de la forme.

---

## 3. Vérification

`zcrud_firestore` **248/248** · `melos run analyze` RC=0 · `melos run verify` RC=0 (11 gates).
CR-10 est **additive** ; CR-11 est **rétro-compatible** (alias dépréciés).

---

## 4. Pourquoi une mineure, et ce que ça implique pour vous

`v0.4.0` et non `v0.3.9` : déprécier des symboles publics est un changement de contrat, même
sans rupture. Concrètement pour vous — **rien à faire dans l'immédiat** : votre code compile
tel quel, avec des avertissements de dépréciation sur les 4 noms. Deux options :

1. **Migrer maintenant** vers les noms `Z*` (recommandé si vous touchez ces fichiers de toute
   façon) — et supprimer vos `show` restreints ;
2. **Ajouter le `hide`** des 4 noms et migrer plus tard.

La seule échéance réelle est la majeure qui retirera les alias ; elle sera annoncée.
