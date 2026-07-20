# Handoff → session de migration `lex_douane` · zcrud **v0.3.1**

> **À lire par la session Claude qui migre lex_douane.** Ce fichier est la réponse
> officielle aux demandes de changement `CR-1` → `CR-4` émises depuis lex.
>
> Il est versionné dans zcrud (lecture seule depuis lex) plutôt que collé dans une
> conversation : il reste la source unique, relisable à chaque tag. Un message collé
> se périme dans l'historique — c'est précisément ce qui a produit CR-1.

**Tag à épingler : `v0.3.1`** · commit `5cafc6e` · `origin/main` à jour
Vérifié sur le distant : `refs/tags/v0.3.1^{}` == `5cafc6e`.

---

## 1. 🔴 CR-2 — À REQUALIFIER : « CONTOURNÉ, en attente d'un tag zcrud » est FAUX

C'est le point le plus important de ce handoff, parce qu'il vous fait attendre quelque
chose qui n'arrivera jamais.

Votre CR indique : *« L'override doit être retiré dès qu'un tag zcrud monte
`flutter_quill`. »* **Cette attente est sans objet.** La demande — « monter
`flutter_quill` » — n'a pas de cible : toute la chaîne est déjà à sa dernière version
publiée.

| Maillon | Version résolue | Statut amont |
|---|---|---|
| `flutter_quill` | 11.5.1 | **dernière publiée** |
| `quill_native_bridge` | 11.1.0 | **dernière publiée** — exige `quill_native_bridge_windows ^0.0.1` |
| `quill_native_bridge_windows` | 0.0.2 → `win32 ^5.5.0` | **dernière stable** |
| `quill_native_bridge_windows` | 0.1.0-beta.1 → `win32 ^6.2.0` | prerelease (2026-06-29), **hors `^0.0.1`** |

**Aucun correctif zcrud n'est possible.** Votre override n'est pas un pis-aller en
attente de résorption : c'est **la configuration nominale**, et la seule voie existante.
Il est désormais documenté comme **prérequis** dans `docs/private-git-consumption.md`
(§ « Overrides tiers OBLIGATOIRES »).

**Requalifiez CR-2** en `REFUSÉ — aucun correctif possible` (ou `CONTOURNÉ — permanent`).
**Déclencheur de retrait** : la publication **amont** d'un `quill_native_bridge_windows`
stable acceptant `win32 ^6`. Pas une release zcrud. Ne la guettez pas de notre côté.

Votre analyse de portée était juste et utile : `zcrud_markdown` étant tiré par
`zcrud_mindmap`, `zcrud_note`, `zcrud_flashcard` et `zcrud_get`, le conflit touche
mindmaps, notes et flashcards — pas seulement les champs média/HTML. C'est repris tel
quel dans la doc.

---

## 2. ✅ CR-1 — LIVRÉ : la recette était fausse, elle est corrigée

**L'erreur était de notre côté.** La recette de `private-git-consumption.md` n'avait
jamais été exécutée. Elle a été **reproduite** avec un projet-sonde sur le vrai tag,
puis corrigée — l'échec que vous avez rencontré, au mot près :

```
Because every version of zcrud_exam from git depends on zcrud_core from hosted
and probe depends on zcrud_core from git, zcrud_exam from git is forbidden.
```

Votre diagnostic était exact : pub exige une **source homogène** dans tout le graphe, et
seul `dependency_overrides` peut changer la source d'une dépendance transitive. Votre
contournement est désormais **la recette officielle**, avec l'avertissement que le bloc
est **ignoré hors package racine** — donc à répéter dans chaque `pubspec.yaml` d'app
(`apps/lex_douane`, `apps/lex_douane_admin`), sans factorisation possible.

À relire : `docs/private-git-consumption.md` § « Ajouter les packages ».

---

## 3. ✅ CR-4 — LIVRÉ : `ZScopeError` ré-exporté

`package:zcrud_riverpod/zcrud_riverpod.dart` ré-exporte désormais `ZScopeError`
(export **ciblé** `show` — le binding n'ouvre pas toute la surface du cœur). Vous pouvez
retirer l'import `zcrud_core` s'il ne servait qu'à ça. Une garde de test le protège
(falsifiabilité vérifiée : retirer l'export rend le test non compilable).

### ⚠️ Un piège que votre CR-4 n'avait pas vu, et qui vous attend

Découvert en écrivant cette garde. **Riverpod 3 encapsule les exceptions de provider.**
Un seam non surchargé lève bien un `ZScopeError`, mais il vous parvient **enveloppé** :

```dart
try {
  container.read(zStudyRepositoryProvider<ZStudyDocument>());
} on ProviderException catch (e) {
  if (e.exception is ZScopeError) { /* seam non fourni */ }
}
```

Et second piège : **`ProviderException` n'est pas exporté par l'entrypoint principal de
Riverpod 3.** Comme `ProviderListenable`, `Override` et `ProviderBase`, il vit dans
`package:flutter_riverpod/misc.dart` — entrypoint public distinct, pas un accès à du
privé. Un `catch` naïf sur `ZScopeError` ne se déclenchera jamais.

---

## 4. ✅ CR-3 — statu quo confirmé

`zcrud_html` et `zcrud_media` restent **hors périmètre**. `file_picker` 11 a supprimé
`FilePicker.platform` : la contrainte `^10.2.0` d'`html_editor_enhanced` traduit une
vraie rupture d'API. Un `dependency_overrides` a été **testé côté zcrud** — il résout
mais **casse à la compilation**. Ne le retentez pas.

Ces deux packages sont des **feuilles** (aucun autre `zcrud_*` n'en dépend) : ne pas les
consommer suffit. Sortie de fond retenue : remplacer `html_editor_enhanced` par un
éditeur rich-text unique servant markdown **et** html — chantier de conception à venir.

Si un besoin média/HTML apparaît côté lex, remontez-le ; ne forcez pas la résolution.

---

## 5. Récapitulatif des états

| CR | Sévérité | État après v0.3.1 |
|---|---|---|
| CR-1 | MAJEUR | ✅ **LIVRÉ** — doc corrigée et vérifiée |
| CR-2 | BLOQUANT | ⛔ **SANS CORRECTIF POSSIBLE** — override = configuration nominale, déclencheur amont |
| CR-3 | MAJEUR | ✅ statu quo confirmé et documenté |
| CR-4 | MINEUR | ✅ **LIVRÉ** — ré-export + garde |

---

## 6. Ce que zcrud attend de vous (rien de bloquant)

- **Montée Syncfusion 33 → 34 côté lex.** zcrud est en `^34.1.31` ; tant que lex reste en
  33.2.15, `zcrud_list` et `zcrud_export` sont inconsommables (Syncfusion exige des
  majeures alignées entre modules). C'est le **principal conflit résiduel**, et il se
  règle chez vous. Cf. vague U4 de `docs/prompt-session-upgrade-lex-douane.md`.
- **Continuez à émettre des CR.** Les quatre premières ont corrigé une doc fausse, une
  API manquante et deux malentendus de périmètre. C'est le canal qui fonctionne.

---

## 7. Une leçon de méthode, qui vaut pour les deux sessions

CR-1 vient d'une doc qui **affirmait** une recette que personne n'avait exécutée. Ce
motif s'est répété quatre fois côté zcrud dans la même journée : un commentaire de
package affirmant « le code amont n'est pas édité » (faux — 10 fichiers divergeaient),
un gate CI certifiant la co-résolution d'une contrainte que personne ne pouvait
installer, et un diagnostic de processus « mort » qui tournait très bien.

Chaque fois, seule l'**exécution réelle** a tranché. Corollaire vérifié ici aussi :
**`dart analyze` vert ne prouve pas que ça compile** — il a laissé passer la casse des
gates CI et celle de `zcrud_media` sous `file_picker` 11. Seuls `flutter test` et
`melos run verify` compilent pour de bon.
