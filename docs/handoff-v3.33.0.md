# Handoff v3.33.0 — le mixin qui débloque les hiérarchies, les ports compagnons du partage

> **Date** : 2026-08-29. **Portée** : `zcrud_generator` (+ 40 `.g.dart` régénérés dans le dépôt),
> `zcrud_study`.

## 1. Ce que le socle livre

| Lot | Paquet | Livré |
|---|---|---|
| **P2-G-2** | `zcrud_generator` | le générateur émet, **en plus** de l'`extension` Dart existante (intacte), un **mixin `_$XxxZcrud`** portant les mêmes `toMap()`/`copyWith()` en **membres d'instance** + un getter abstrait par champ. Application côté hôte, facultative, en une ligne : `class Facture extends DynamicModel with _$FactureZcrud` — un membre d'extension ne satisfaisant jamais un membre abstrait hérité, **84,6 % des lignes visées par l'adoption du codegen étaient structurellement inatteignables** ; elles ne le sont plus. Les corps des deux blocs sortent d'une seule source de texte (identiques par construction, gardé). Le slot `ZExtension` (AD-4) reste hors-codegen par contrat — non touché |
| **Partage v2** | `zcrud_study` | ports **compagnons** additifs — `ZStudySharingPort` inchangé à l'octet : `ZStudySharingReadPort` (`watchPublicFolders` paginé par `ZDataRequest`, `publicFolderById` — `Right(null)` = non publié) et `ZStudySharingAdminPort` (`revokeMembership`, `setJoinableByLink`, `setMembersCanInvite`) + inertes const ; `ZPublicGalleryView.readPort` (le flux-paramètre **prime** — compat), `ZFolderSharingSheet.adminPort` (le callback **prime**) ; tout reste sous le portail fail-closed |

## 2. Ce qui change pour un hôte

- **Les 40 `.g.dart` réécrits sont un diff de FORME, pas de fond** : `git diff` montre 2 097
  insertions et **0 suppression** ; le JSON émis est identique à l'octet ; les 1 926 tests des
  cinq paquets consommateurs passent **tels quels**. Un hôte en dépendance git verra un diff
  bruyant au bump — rien à faire.
- Ce qui **s'ouvre** : les hiérarchies à `toMap()`/`copyWith()` abstraits peuvent adopter le
  codegen (le cas qui bloquait l'essentiel de l'adoption chez un hôte). Contrepartie : les champs
  de la classe qui applique le mixin deviennent des `@override` (lint `annotate_overrides`, info).
- **Implémenteur du port de partage v1 : rien à changer.** Fournir un compagnon débloque la
  surface correspondante. Un changement de détail : les interrupteurs de la feuille de partage
  gagnent un verrou d'occupation (une double bascule rapide n'émet plus deux appels).

## 3. Vérification

| Paquet | Avant | Après |
|---|---|---|
| `zcrud_generator` (`dart test`) | 168 | **176** |
| `zcrud_study` | 1 806 | **1 828** (analyze 72 infos préexistantes) |
| Consommateurs des `.g.dart` (kernel 698, flashcard 621, document 331, note 197, exam 79) | — | **verts tels quels, 0 test modifié** |

`melos run generate` ×2 : idempotent (0 diff au second) · `analyze` RC=0 · `verify` RC=0 · R3 :
17 injections (14 partage + 3 générateur), toutes rouges par assertion, restauration par copie,
sha identiques, grep négatif. Balayage des 41 : **41/41 verts**.
