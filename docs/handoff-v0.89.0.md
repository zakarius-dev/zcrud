# Handoff **v0.89.0** — dérivation de scope : l'ACL par écran sans recopie

> **Tag à épingler : `v0.89.0`** — répond au CR DODLP
> `cr-scope-copywith-et-acl-par-ecran-2026-08-12.md` (chantier listes, Lot 1).
> Paquet porteur : **`zcrud_core`**. Les 38 autres paquets sont bumpés sans changement.
> Release **strictement additive** : aucune API existante modifiée, aucun comportement
> changé pour un hôte qui ne dérive pas de scope.

---

## 1. Constat 1 du CR — recopie manuelle des 21 seams : **corrigé (option 1)**

Deux ajouts sur `ZcrudScope` :

- **`copyWith(...)`** — dérivation sûre : tout seam omis **hérite par construction** de
  la valeur du scope courant ; les 21 seams sont couverts. Pour un seam nullable
  (`labels`, `theme`…), un `null` explicite le remet à son repli par défaut (sentinelle —
  même sémantique que le `copyWith` généré sur vos modèles).
- **`derive(context, ...)`** — la forme « par écran » : lit le scope **ambiant**
  (`maybeOf`) et re-pose un scope dérivé en ne remplaçant que les seams nommés. Sans
  scope ambiant, la dérivation part du scope zéro-config. Votre cas d'usage s'écrit :

```dart
ZcrudScope.derive(
  context,
  acl: aclDeLaRessource, // seule couture remplacée : les 20 autres héritent
  child: EcranListe(...),
);
```

### La dette du 22ᵉ seam est fermée chez nous, pas chez vous

Votre crainte exacte — « le jour où zcrud ajoute un 22ᵉ seam, tout écran migré le perd
silencieusement » — est traitée par une **garde de non-oubli** dans nos tests : tout seam
déclaré sur `ZcrudScope` doit être couvert par `copyWith` **et** `derive`, sinon le test
rougit **par assertion** (prouvé par injection d'un 22ᵉ seam factice). L'exhaustivité vit
désormais du côté qui connaît la liste des seams, comme votre CR le demandait.

**Hôte ayant compensé** : votre fichier de recopie manuelle
(`dodlp_zcrud_scope_overrides.dart`) devient **la dette à retirer** — remplacez chaque
re-pose complète par `ZcrudScope.derive(context, acl: …)`. La recopie n'est pas nocive en
soi (elle produit le même scope aujourd'hui), mais elle re-crée chez vous l'angle mort que
cette release ferme : tant qu'elle existe, un futur seam n'y sera pas hérité. Le tripwire
recommandé : un test qui compte les seams recopiés et rougit quand `ZcrudScope` en gagne un.

`DynamicList(acl:)` (option 2) n'a **pas** été ajouté : `derive` couvre le besoin pour la
liste **et** l'édition, sans doubler le point d'injection.

## 2. Constat 2 du CR — verbes inatteignables : **consigné, rien à faire**

Noté de votre côté : `archive`/`publish`/`history` structurellement à `false` chez vous,
`aiGenerate` en action `custom` gardée par l'hôte — le contrat le permet déjà. Nous
retenons que ces trois verbes ne sont pas exercés par votre parc.

## 3. Constat 3 du CR — « les repositories précèdent les listes » : **documenté**

Le guide de migration (`docs/site/guides/migration-legacy.md`, section dédiée) énonce
désormais la dépendance d'ordonnancement que vous avez heurtée : la corbeille
(`softDelete`/`restore`) exige un `ZRepository` ; une coquille de liste alimentée par une
simple `List<T>` ne peut pas la porter. Migrer les repositories d'abord.

## 4. Constat 4 du CR — `ZListRow.id` vs `ZEntity.id?` : **contrat écrit, pas d'alignement**

`ZListRow.id` reste non nullable — une ligne de liste a besoin d'une clé stable. La
dartdoc dit maintenant ce qui manquait : une entité éphémère (`id == null`) n'a pas de clé
naturelle, c'est au projecteur `T → ZListRow` de fabriquer une clé **stable** (clé
positionnelle stable ou identité locale) jusqu'à la persistance. Votre `__ephemere_$index`
est exactement ce que le contrat attend.

## 5. État des vérifications

`melos run analyze` RC=0, `melos run verify` RC=0 (14 gates), `flutter test` depuis
`packages/zcrud_core` : **1757 tests** verts, workstreams au repos. Garde de non-oubli
prouvée mordante par injection (rouge par assertion), restauration par copie vérifiée par
sha256, zéro résidu (grep négatif).

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification ci-dessus
a été rejouée localement et constitue la ligne de défense de cette release.
