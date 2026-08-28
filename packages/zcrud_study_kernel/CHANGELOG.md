# Changelog

Toutes les modifications notables de `zcrud_study_kernel` sont documentées
dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.28.0 — 2026-08-28

### Ajouté

- `ZStudyFolder.subjectId` : lien typé, optionnel, vers la matière d'un
  dossier. Identifiant opaque résolu par l'application — le noyau n'introduit
  ni entité matière ni port de résolution. Champ `@ZcrudField(label: 'Matière')`
  : il apparaît donc dans `$ZStudyFolderFieldSpecs` (et dans le formulaire
  dérivé) sans action du consommateur.
- `ZStudySubjectRef` : référence d'affichage légère (`id` opaque + `label` et
  `colorKey` optionnels), exportée par le barrel. Décodage défensif (AD-10) :
  tout champ d'un type inattendu retombe sur `null` (`id` sur `''`) sans lever ;
  `toMap()` omet les métadonnées absentes. Égalité structurelle sur les trois
  champs.

### Inertie (hôte n'utilisant pas la matière)

- `subject_id` est ABSENT de `toMap()` tant que `subjectId` est `null` : la map
  persistée d'un dossier existant est strictement identique à celle d'avant ce
  lot, clé pour clé. Garde d'égalité stricte à la map littérale complète.
- `subject_id` entre dans `_reservedKeys` (dérivées du schéma généré) : elle ne
  peut plus atterrir dans `extra` par aucune voie — y compris le constructeur
  `const`, seule voie incapable de filtrer, dont l'accesseur `extra` porte la
  garde. Un hôte qui rangeait sa propre matière sous la clé `subject_id` dans
  `extra` la voit désormais promue en champ first-class : elle est lue par
  `fromMap` et n'est plus rendue par `extra`.

### Tests

- 9 gardes neuves, chacune prouvée par une injection de la régression exacte
  qu'elle surveille (rouge par assertion, restauration par copie, SHA-256
  identique avant/après) : inertie absolue de `toMap()`, round-trip et identité
  structurelle de `subjectId`, type invalide retombant sur `null` sans polluer
  `extra`, sentinelle de `copyWith` (omis ≠ `null` explicite), filtrage de la
  clé réservée depuis `extra`, égalité STRICTE entre les noms du schéma et les
  clés de `toMap()` (mord dans les deux sens), puis round-trip, décodage
  défensif et égalité discriminante de `ZStudySubjectRef`.

## 3.6.0 — 2026-08-23

### Corrigé
- Octet NUL brut dans un littéral Dart remplacé par `\u0000` (un `grep` sans `-a` voyait un fichier binaire ; `git diff` aussi).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (absent jusqu'ici), au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_study_kernel.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, invariants d'architecture cités par leur
  nom stable (`docs/site/concepts/invariants.md`). Purge des références de
  story et d'epic, des emoji de journal, des codenames de remédiation internes
  et des comparatifs à des applications legacy utilisés comme justification —
  conservation des invariants, cas limites et avertissements de contrat.
  Aucun changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_study_kernel/`.
