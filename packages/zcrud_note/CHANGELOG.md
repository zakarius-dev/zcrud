# Changelog

Toutes les modifications notables de `zcrud_note` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.29.0 — 2026-08-28

### Ajouté

- `ZNoteAudioPlayer` : mini-lecteur de l'audio **déjà existant** d'une note,
  branché sur le `ZAudioPlaybackPort` de `zcrud_core`. Il **lit**, il ne
  **produit** jamais — aucune génération, aucun plugin natif tiré par le paquet
  (le moteur est apporté par l'hôte). Contrôles : bascule lecture/pause (cible
  ≥ 48 dp, `Semantics` étiquetée), horodatage `position / durée`, curseur de
  déplacement (`seek`), état d'échec affiché.
- `ZSmartNoteReader.audioPort` et `ZSmartNoteEditor.audioPort`
  (`ZAudioPlaybackPort?`, `null` par défaut) : le mini-lecteur n'est monté que
  si les **trois** conditions sont réunies — port fourni, `isAvailable == true`,
  et note portant une source audio **typée** (`ZNoteAudio` avec `path` ou `url`
  non vide, le chemin local primant sur l'URL). Sans port, l'arbre rendu est
  **strictement** celui d'avant (garde d'inertie par égalité de sous-arbre).
- `z_note_audio_labels.dart` : fichier de **référence unique** des libellés du
  lecteur — clés, défauts français, résolution
  `ZcrudScope(labels:)` → `ZcrudLocalizations` → défaut, et formatage neutre
  `zFormatNoteAudioTime` (`m:ss`, `h:mm:ss` au-delà d'une heure).

### Notes de conception

- Le port **appartient à l'appelant** : le widget ne l'ouvre ni ne le ferme, il
  ne rappelle jamais `dispose()` (tenu par une garde de source). Ce qui est
  libéré au démontage, ce sont ses seuls abonnements aux flux.
- `load()` est appelé **une fois** au montage — jamais depuis `build` — puis à
  nouveau seulement si la source ou le moteur change d'identité. Un `Left` au
  chargement bascule l'affichage sur l'état d'échec ; il ne lève jamais (AD-10).
- Rebuild granulaire (AD-2) : un événement du flux `position` ne reconstruit que
  l'horodatage et le curseur — le bouton et le corps de la note restent les
  mêmes instances (mesuré par identité de widget, pas par apparence).
- Aucune couleur ni aucun texte codés en dur dans le widget (FR-26) : rôles M3
  (`colorScheme.error`) et libellés résolus ; les défauts vivent dans le fichier
  de référence, exempté nominativement par la garde de source.

### Impact hôte

- Hôte **passif** (aucun `audioPort` passé) : **rien ne change** — arbre de
  rendu identique, prouvé par égalité stricte de sous-arbre.
- Hôte ayant **compensé** en superposant son **propre** lecteur audio au-dessus
  ou au-dessous de `ZSmartNoteReader` / `ZSmartNoteEditor` : dès qu'il fournit
  `audioPort`, il obtiendra **deux** lecteurs. Retirer la compensation, ou ne
  pas passer le port.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (absent jusqu'ici), au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_note.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, invariants d'architecture cités par leur
  nom stable (`docs/site/concepts/invariants.md`). Purge des références de
  story et d'epic, des emoji de journal, des codenames de remédiation internes
  et des noms d'applications legacy utilisés comme justification —
  conservation des invariants, cas limites et avertissements de contrat.
  Aucun changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_note/`.
