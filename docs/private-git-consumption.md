# Consommation privée des packages zcrud via dépendances git

Les packages zcrud sont distribués **en privé** depuis ce monorepo GitHub
(`zakarius-dev/zcrud`) — **pas** sur pub.dev. Les apps consommatrices (DODLP,
lex_douane, …) les référencent via des **dépendances git** épinglées sur un tag.

> Artifact Registry ne propose pas de format Dart/pub natif ; les dépendances git
> sont l'option privée sans infrastructure ni coût.

## Prérequis

L'environnement qui fait `dart pub get` (poste dev **et** CI) doit avoir accès au
repo privé `zakarius-dev/zcrud` :

- **SSH** (recommandé) : clé SSH ajoutée à GitHub → utiliser l'URL
  `git@github.com:zakarius-dev/zcrud.git`.
- **HTTPS + token** : un Personal Access Token avec accès `repo` →
  `https://<TOKEN>@github.com/zakarius-dev/zcrud.git` (ne jamais committer le token).

## Épinglage

Utiliser un **tag de release** (ex. `v0.4.5`) comme `ref`, jamais `main` (stabilité
et reproductibilité). Le versionnage se fait **par tag git**, pas par contrainte
`^0.4.5`.

## Ajouter les packages

> 🔴 **CORRECTION 2026-07-20 (CR-1, remontée par la session lex_douane).** La recette
> décrite ici auparavant — « déclarer chaque `zcrud_*` transitif en dépendance `git`
> dans `dependencies:` » — **NE RÉSOUT PAS**. Elle a été reproduite et corrigée ;
> `dependency_overrides` est **obligatoire**. Détail ci-dessous.

⚠️ **Règle importante** : les dépendances **inter-`zcrud_*`** du monorepo sont des
contraintes **hosted** (`zcrud_core: ^0.4.5`). Or **pub exige que la SOURCE d'une
dépendance soit identique dans tout le graphe** : déclarer `zcrud_core` en `git` côté
app ne satisfait pas une arête interne qui l'attend en `hosted`. La résolution échoue :

```
Because every version of zcrud_exam from git depends on zcrud_core from hosted
and probe depends on zcrud_core from git, zcrud_exam from git is forbidden.
So, because probe depends on zcrud_exam from git, version solving failed.
```

**Seul `dependency_overrides` peut changer la source d'une dépendance transitive.**
Il faut donc déclarer chaque package `zcrud_*` requis **DEUX FOIS** : dans
`dependencies:` (pour l'utiliser) **et** dans `dependency_overrides:` (pour imposer la
source git à tout le graphe).

Exemple vérifié (`pubspec.yaml` de l'app) — `zcrud_flashcard` tire core + markdown +
export + annotations :

```yaml
dependencies:
  zcrud_flashcard:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.4.5, path: packages/zcrud_flashcard }
  # … les autres packages RÉELLEMENT importés par ton code

# OBLIGATOIRE : impose la source git à TOUTE la fermeture transitive `zcrud_*`.
# Doit lister les packages transitifs même si tu ne les importes jamais toi-même.
dependency_overrides:
  zcrud_core:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.4.5, path: packages/zcrud_core }
  zcrud_annotations:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.4.5, path: packages/zcrud_annotations }
  zcrud_study_kernel:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.4.5, path: packages/zcrud_study_kernel }
  zcrud_markdown:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.4.5, path: packages/zcrud_markdown }
  zcrud_export:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.4.5, path: packages/zcrud_export }
```

### Où placer le bloc — deux cas, à ne pas confondre (CR-LEX-5)

> 🔴 **CORRECTION 2026-07-21.** Ce document prescrivait « répéter le bloc dans chaque
> `pubspec.yaml` d'application ». C'est correct pour un consommateur **mono-package**, et
> **faux et bloquant** pour un consommateur en **pub workspace**.

**Cas 1 — consommateur MONO-PACKAGE (une app, un `pubspec.yaml`)**
Un seul bloc, dans le `pubspec.yaml` de l'app. `dependency_overrides` n'est honoré que dans
le package **racine** : un bloc placé dans un package intermédiaire est ignoré en silence.

**Cas 2 — consommateur en PUB WORKSPACE (monorepo : lex_douane, IFFD…)**
**Un bloc UNIQUE dans le `pubspec.yaml` RACINE du workspace**, qui lie tous les membres via
le lock partagé. **Ne le répétez pas dans les apps** : pub refuse un même override déclaré
par deux membres, *même si les deux blocs sont strictement identiques* —

```
The package `collection` is overridden in both:
package `app_a` at `./apps/a` and 'app_b' at `./apps/b`.
Consider removing one of the overrides.
```

Ce n'est pas un conflit de valeurs mais une règle d'unicité de l'override dans un workspace.
Mesuré côté lex_douane (racine + 4 packages + 2 apps) : le bloc racine est honoré et lie
bien tous les membres.

La sortie de fond (supprimer la duplication entre apps mono-package) serait de publier les
packages sur un registre privé ; non retenu à ce jour (cf. en-tête de ce document).

### Graphe de dépendances (à déclarer selon ce qu'on utilise)

Tout dépend de `zcrud_core` (puits du graphe). Arêtes utiles :

| Package | Dépend de (`zcrud_*`) |
|---|---|
| `zcrud_core` | — |
| `zcrud_annotations` | zcrud_core |
| `zcrud_generator` (dev) | zcrud_core, zcrud_annotations |
| `zcrud_markdown`, `zcrud_list`, `zcrud_firestore`, `zcrud_geo`, `zcrud_intl`, `zcrud_export`, `zcrud_riverpod`, `zcrud_get`, `zcrud_provider` | zcrud_core |
| `zcrud_mindmap` | zcrud_core, zcrud_markdown |
| `zcrud_flashcard` | zcrud_core, zcrud_markdown, zcrud_export, zcrud_annotations |

### ⚠️ Les packages d'ENTITÉ ne sont tirés par AUCUN binding (CR-IFFD-9)

Les entités study concrètes — **`zcrud_document`** (`ZStudyDocument`), **`zcrud_note`**
(`ZSmartNote`), **`zcrud_exam`** (`ZExam`) — ne sont dépendues par **aucun** package du
graphe : ni par les bindings (`zcrud_riverpod`/`zcrud_get`/`zcrud_provider`), ni par
`zcrud_flashcard`, ni par `zcrud_study_kernel`.

**C'est un invariant d'architecture délibéré (AD-24), pas un oubli.** Le binding générique
reste **thin** : il expose les seams et fabriques (`zStudyRepositoryProvider<T>`,
`zStudyWatchAllProvider<T>`) mais **ignore** les types concrets, que l'app injecte. Un
binding qui dépendrait de `zcrud_document` imposerait cette entité — et toutes les autres —
à tout consommateur, y compris ceux qui ne s'en servent pas.

**Conséquence pour l'app** : dès que ton code écrit `import 'package:zcrud_document/...'`
(pour mapper vers `ZStudyDocument.fromMap`, typer un `ZStudyRepository<ZStudyDocument>`,
etc.), tu **dois déclarer `zcrud_document` toi-même** — en `dependencies:` **et** en
`dependency_overrides:` (même règle de source git que tout `zcrud_*`, cf. § « Ajouter les
packages »). Idem pour `zcrud_note`, `zcrud_exam`.

⚠️ **Ne mappe pas vers le schéma `*.g.dart` figé pour éviter d'importer l'entité.** C'est
possible (le `toMap`/`fromMap` généré est stable dans un tag donné), mais le mapping
**diverge alors en silence** si l'entité change de schéma dans un tag ultérieur — rien ne
le détecte, le type concret n'étant pas importé. Importer réellement l'entité fait de tout
changement de schéma une **erreur de compilation**, pas une corruption de données
silencieuse. Préfère l'import dès que l'entité est au cœur du flux.

## ⚠️ Overrides tiers OBLIGATOIRES selon la cible

Deux dépendances tierces imposent un `dependency_overrides` **côté app**. Ce ne sont pas
des défauts de zcrud : les chaînes amont sont **déjà à leur dernière version publiée** et
il n'existe, à ce jour, aucun correctif possible côté zcrud.

### `win32` — requis dès que l'hôte est en `file_picker` ≥ 11 (CR-2)

Chaîne en cause :

```
zcrud_markdown → flutter_quill 11.5.1 (DERNIÈRE version publiée)
               → quill_native_bridge 11.1.0 (DERNIÈRE)
               → quill_native_bridge_windows ^0.0.1 → résout 0.0.2 → win32 ^5.5.0
app hôte       → file_picker ≥ 11                                  → win32 ^6.2.0
```

**Portée large** : `zcrud_markdown` est tiré par `zcrud_mindmap`, `zcrud_note`,
`zcrud_flashcard` et `zcrud_get`. Le conflit frappe donc mindmaps, notes et flashcards —
pas seulement les champs média/HTML.

**Aucun correctif zcrud possible** : toute la chaîne est en bout de course. La seule
version acceptant `win32 ^6.2.0` est **`quill_native_bridge_windows 0.1.0-beta.1`**
(prerelease publiée le 2026-06-29), et la contrainte `^0.0.1` de `quill_native_bridge` ne
l'accepterait pas sans override.

```yaml
dependency_overrides:
  quill_native_bridge_windows: 0.1.0-beta.1
```

⚠️ **Fragilité assumée** : c'est une prerelease d'un plugin tiers, forcée par override.
Le risque est **circonscrit à la cible Windows**. À retirer dès qu'une version stable de
la chaîne accepte `win32 ^6`.

### `file_picker` — `zcrud_html` et `zcrud_media` sont HORS PÉRIMÈTRE (CR-3)

`html_editor_enhanced` 2.7.1 (dernière version, projet abandonné) épingle
`file_picker ^10.2.0`, et `file_picker` 11 a **supprimé `FilePicker.platform`** : la
contrainte traduit une vraie rupture d'API, **non contournable par override** (testé — la
résolution passe, la compilation casse).

Ces deux packages sont des **feuilles** (aucun autre `zcrud_*` n'en dépend) : ne pas les
consommer suffit à éviter le problème. Décision owner du 2026-07-20 : ils sont hors
périmètre d'intégration tant que `html_editor_enhanced` n'est pas remplacé par un éditeur
rich-text unique servant markdown ET html.

## Riverpod 3 — deux pièges au câblage des seams

Depuis `v0.3.0`, `zcrud_riverpod` est en **Riverpod 3.3.x**. Deux comportements
surprennent au premier branchement :

**1. Les exceptions de provider sont ENCAPSULÉES.** Un seam non surchargé
(`zStudyRepositoryProvider<T>`) lève bien un `ZScopeError`, mais Riverpod 3 le remonte
enveloppé dans un `ProviderException`. Il faut le déballer :

```dart
try {
  container.read(zStudyRepositoryProvider<ZStudyDocument>());
} on ProviderException catch (e) {
  if (e.exception is ZScopeError) { /* seam non fourni */ }
}
```

`ZScopeError` est **ré-exporté par le barrel du binding** (CR-4) : inutile d'importer
`zcrud_core` juste pour l'attraper.

**2. La surface publique de Riverpod 3 est resserrée.** `ProviderException`,
`ProviderListenable`, `Override` et `ProviderBase` ne sont **pas** exportés par
`package:flutter_riverpod/flutter_riverpod.dart` — ils vivent dans
`package:flutter_riverpod/misc.dart`. Ce n'est pas un accès à du privé, c'est un
entrypoint public distinct.

## Codegen

`zcrud_flashcard` utilise `@ZcrudModel` (`part '*.g.dart'`). Son **code généré est
versionné** dans le repo (exception `.gitignore` ciblée) : un consommateur git le
reçoit tel quel — **rien à régénérer** côté app pour les dépendances.

L'app consommatrice n'a besoin de `zcrud_generator`/`build_runner` que si **elle**
annote ses **propres** modèles avec `@ZcrudModel`.

## Mettre à jour une version

1. Bumper les `version:` concernées + `CHANGELOG.md`.
2. Committer, puis **taguer** (`git tag v0.1.1 && git push origin v0.1.1`).
3. Côté app : passer les `ref:` au nouveau tag, `dart pub get`.
