# Changelog

Toutes les modifications notables de `zcrud_export` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 0.93.0 — 2026-08-13

### Ajouté

- **`ZCsvListExporter`** — exporteur de liste au format CSV branché sur le port
  `ZListExporter` du cœur. Écrit en Dart pur, sans bibliothèque tierce :
  en-tête résolu, une ligne par ligne affichée, échappement RFC 4180
  (guillemets doublés), fin de ligne `\r\n`, marque d'ordre des octets UTF-8
  posée par défaut pour que les tableurs n'abîment pas les accents. Séparateur
  paramétrable (`;` pour un tableur en locale francophone).
- **`ZXlsxListExporter`** — même contrat, au format Excel : réutilise la façade
  `ZExporter` déjà offerte par ce paquet, sans en dupliquer la production.

Déclarés sur `ZCrudScreen(export:)`, ces exporteurs suffisent à offrir l'export
d'un écran. L'assemblage ne dépend d'aucun paquet d'export : il ne connaît que
le port.

### Corrigé

- **Parité écran/fichier : la cellule exportée est la cellule affichée.** La
  projection partagée (`ZExportTable.fromRequest`) lisait la valeur **brute**
  d'une cellule. Les colonnes dont l'affichage dépend de la ligne — montant et
  sa devise, format composé — étaient donc exportées **sans leur format**, sans
  erreur ni signe visible. La ligne entière est désormais passée au formateur
  du cœur : un montant suit la devise de **sa** ligne, jamais celle de la
  précédente.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_export.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`E11a-3`, `E11b-3`, `su-11`,
  `CR-LEX-40`, `AC9`, `AC10`) et des mentions `origine:`, conservation des
  invariants citables (`AD-1`, `AD-8`, `AD-10`, `AD-12`). Aucun changement de
  code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_export/`.
