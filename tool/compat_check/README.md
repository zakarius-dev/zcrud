# `tool/compat_check` — Manifeste de compat de résolution (FR-25 / E1-4)

Package **isolé, hors workspace** dont l'unique rôle est de **prouver, avant tout
code d'intégration (E7 DODLP / E8 lex_douane), que les dépendances lourdes
d'intégration co-résolvent** aux versions cibles alignées sur le workspace
lex_douane (le plus récent) / la table Stack, sous **Dart `^3.12.2`** / Flutter cible.

Le gate **`scripts/ci/gate_compat_resolution.dart`** exécute
`flutter pub get --dry-run` dans ce dossier : succès ⇒ le triplet co-résout
(merge autorisé) ; conflit de version ⇒ échec (merge bloqué).

## Pourquoi hors workspace (isolation Flutter / pur-Dart)

Les 14 membres du workspace zcrud sont **pur-Dart** (aucun `flutter: sdk: flutter`) ;
`dart pub get` / `dart analyze` / `dart test` doivent le rester (AD-15, E1-1..E1-3).
Or **flutter_quill et awesome_select tirent le SDK Flutter**. Les déclarer dans un
membre casserait la résolution pur-Dart et le graphe AD-1. Ce package vit donc
**hors des 14 membres**, sous `tool/compat_check/` :

- **absent** du bloc `workspace:` du root `pubspec.yaml` (lockfile racine propre) ;
- **hors** du glob `packages: [packages/**]` de `melos.yaml` (non ciblé par `melos run`) ;
- **hors** du scope de `scripts/dev/graph_proof.py` (qui n'itère que `packages/*`) ;
- **pas** de `resolution: workspace` (sinon il rejoindrait la résolution racine et
  tirerait Flutter dans le lock partagé — interdit).

## Versions retenues

| Dépendance | Contrainte pinnée | Version résolue | Source | Justification |
| --- | --- | --- | --- | --- |
| `flutter_quill` | `^11.5.0` | `11.5.1` | **Table Stack** (`architecture.md#Stack` : `flutter_quill ^11.5.x`) | Rich-text E6 (éditeur Delta / `ZCodec`). Contrainte alignée sur la Stack lex_douane. |
| `awesome_select` | `^6.0.0` | `6.0.0` | **Non listé dans la table Stack** — sourcé ici | Dernière version stable publiée. Champs de sélection (E3). Co-résout avec `flutter_quill ^11.5.x` sous Flutter cible. **Divergence signalée** : à confirmer contre le workspace lex_douane réel lorsqu'il est disponible (voie opportuniste `LEX_WORKSPACE`). |
| `analyzer` | `^8.0.0` | `8.x` | **Toolchain RÉELLE du codegen** (`packages/zcrud_generator/pubspec.yaml` : `analyzer ^8`) | *Remédiation code-review E2-5 (M1).* Le générateur E2-5 s'exécute sous `analyzer ^8` (la résolution partagée du workspace — `test`/`flutter_test` → `analyzer >=8` — impose `^8`, cf. Dev Notes E2-5). L'ancienne borne `^7` prouvait un triplet **divergent** de la toolchain réelle (fausse confiance FR-25) ; on aligne le manifeste sur `^8` pour que `gate:compat` prouve la chaîne **réellement utilisée**. |
| `source_gen` | `^4.0.0` (dev) | `4.x` | **Chaîne de codegen** (E2-5) | *Remédiation M1.* Aligné sur `packages/zcrud_generator` (`source_gen ^4`). Ancre la co-résolution `analyzer ^8 ↔ source_gen ^4`. |
| `build` | `^3.0.0` (dev) | `3.x` | **Chaîne de codegen** (E2-5) | *Remédiation M1.* Aligné sur `packages/zcrud_generator` (`build ^3`). Ferme le triplet `analyzer/build/source_gen` de la toolchain réelle. |
| `build_runner` | `^2.5.0` (dev) | `2.x` | **Chaîne de codegen** (E2-5) | *Remédiation M1.* Aligné sur `packages/zcrud_generator` (`build_runner ^2.5.0`). Prouve la co-résolution `analyzer ↔ codegen` par le gate, non simplement affirmée. |
| `json_serializable` | `^6.11.0` (dev) | `6.11.x` | **Chaîne de codegen** (E2-5) | *Remédiation M1.* Conservé pour ancrer `source_gen`/`build`. La co-résolution effective (`analyzer ^8` + `build ^3` + `source_gen ^4` + `build_runner ^2.5` + `json_serializable ^6.11`) est désormais vérifiée à chaque `gate:compat`, reflétant la toolchain **réelle** du générateur. |

**Cibles SDK/Flutter** (alignées lex_douane, autorité = architecture/PRD) :
- **Dart** : `^3.12.2` (`environment.sdk`).
- **Flutter** : `>=3.24.0` (borne minimale ; le runner CI fournit `3.44.4` via
  `subosito/flutter-action@v2`, qui livre Dart `3.12.2`).

> Note de divergence SDK (documentée, non bloquante) : l'artefact `lex_douane_core`
> présent localement est un **CLI pur-Dart** (`sdk: ^3.10.4`, sans Flutter ni les 3
> dépendances). Ce n'est **pas** le « workspace lex_douane » (app Flutter) dont la
> Stack tire ses versions. **Autorité = architecture/PRD → Dart `^3.12.2`.**

## Deux voies du gate

1. **Voie manifeste (défaut, autorité de merge, BLOQUANTE)** — dry-run de CE package.
   Déterministe, hermétique, rejouable en CI (Flutter y est disponible), indépendante
   de la présence d'un workspace lex_douane. Un conflit de résolution ⇒ échec.
2. **Voie workspace réel (opportuniste, INFORMATIONNELLE, non bloquante)** — activée
   seulement si la variable d'env `LEX_WORKSPACE` pointe un workspace lex_douane
   résoluble. En son absence (cas CI par défaut) : **SKIP** propre, gate vert. Une
   indisponibilité (workspace absent/illisible) **ne fait jamais échouer** le gate ;
   seul un vrai conflit détecté par la voie manifeste est bloquant.

## Lancer le gate localement

```bash
dart run melos run gate:compat          # via melos
dart run scripts/ci/gate_compat_resolution.dart   # direct
LEX_WORKSPACE=/chemin/vers/lex_douane dart run scripts/ci/gate_compat_resolution.dart  # + voie opportuniste
```

Le gate dépend de la **toolchain Flutter** (`flutter` sur le `PATH`). Si elle est
absente localement, le gate le signale **explicitement** (message clair, exit≠0) —
jamais un faux vert silencieux. La CI la fournit toujours (subosito).
