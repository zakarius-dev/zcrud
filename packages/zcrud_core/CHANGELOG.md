# Changelog

Toutes les modifications notables de `zcrud_core` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 0.89.0 — 2026-08-12

### Ajouté

- `ZcrudScope.copyWith(...)` : dérivation sûre d'un scope — tout seam omis
  hérite de la valeur du scope courant (les 21 seams couverts) ; pour un seam
  nullable, un `null` explicite le remet à son repli par défaut (sentinelle,
  même patron que le `copyWith` généré par `zcrud_generator`).
- `ZcrudScope.derive(context, ...)` : dérive le scope **ambiant** en ne
  remplaçant que les seams nommés — la forme recommandée pour une surcharge
  par écran (par exemple une ACL propre à la ressource affichée). Sans scope
  ambiant, la dérivation part du scope zéro-config.
- Garde de non-oubli (`z_scope_copywith_parity_test.dart`) : tout seam déclaré
  sur `ZcrudScope` doit être couvert par `copyWith` **et** `derive` — un
  nouveau seam absent de la dérivation rougit par assertion au lieu d'être
  perdu silencieusement par les scopes dérivés.

### Modifié

- `ZListRow.id` : la dartdoc explicite le contrat face à `ZEntity.id` nullable —
  une entité éphémère (`id == null`) n'a pas de clé de ligne naturelle ; le
  projecteur `T → ZListRow` fabrique une clé stable (clé positionnelle stable
  ou identité locale) jusqu'à la persistance. Aucun changement de code.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu des
  couches domaine/présentation, installation, démarrage rapide, concepts clés,
  API principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_core.md` (rôle, quand l'utiliser, types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc du barrel (`zcrud_core.dart`, `domain.dart`,
  `edition.dart`) et du schéma déclaratif (`lib/src/domain/edition/`) :
  première phrase autonome, invariants d'architecture cités par leur nom
  stable (`docs/site/concepts/invariants.md`). Purge des références de story
  et d'epic, des comparatifs legacy nominatifs et des emoji de journal —
  conservation des invariants, cas limites et avertissements de contrat. Aucun
  changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_core/`.
