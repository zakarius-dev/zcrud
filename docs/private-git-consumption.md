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

Utiliser un **tag de release** (ex. `v0.1.0`) comme `ref`, jamais `main` (stabilité
et reproductibilité). Le versionnage se fait **par tag git**, pas par contrainte
`^0.1.0`.

## Ajouter les packages

⚠️ **Règle importante** : les dépendances **inter-`zcrud_*`** du monorepo sont des
contraintes hosted (`zcrud_core: ^0.1.0`). Un consommateur qui tire `zcrud_flashcard`
en git doit donc déclarer **chaque package `zcrud_*` transitivement requis** comme
dépendance git (même `url` + même `ref`) — sinon pub tenterait de les résoudre
depuis pub.dev (où ils ne sont pas publiés).

Exemple (`pubspec.yaml` de l'app) — flashcard tire core + markdown + export +
annotations :

```yaml
dependencies:
  zcrud_core:
    git:
      url: git@github.com:zakarius-dev/zcrud.git
      ref: v0.1.0
      path: packages/zcrud_core
  zcrud_annotations:
    git:
      url: git@github.com:zakarius-dev/zcrud.git
      ref: v0.1.0
      path: packages/zcrud_annotations
  zcrud_markdown:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.1.0, path: packages/zcrud_markdown }
  zcrud_export:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.1.0, path: packages/zcrud_export }
  zcrud_flashcard:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.1.0, path: packages/zcrud_flashcard }
```

Les versions déclarées dans chaque package (toutes `0.1.0`) satisfont les
contraintes inter-`zcrud_*` (`^0.1.0`), donc la résolution passe.

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
