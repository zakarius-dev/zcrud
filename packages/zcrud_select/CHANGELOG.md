# Changelog

Toutes les modifications notables de `zcrud_select` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.20.0 — 2026-08-25

### Ajouté
- **Coupure du résumé d'un déclencheur multiple** : au-delà du palier, une ligne « +N … » remplace les valeurs restantes. Géométrie et forme réglables par jetons et par paramètre ; couleurs par rôles du thème.

### Modifié
- Le résumé n'est plus rendu par une puce Material mais par une **étiquette compacte** : une étiquette de résumé n'est pas actionnable, elle n'a donc pas à porter le plancher tactile de 48 dp qu'imposait la puce — treize valeurs occupaient 268 dp de hauteur.

### Corrigé
- `chipRunSpacing` de la référence valait **4** là où la valeur de référence est **6** ; les deux gardes qui assertaient l'ancienne valeur ont été relevées.

### Garde
- **L'annonce accessible du déclencheur porte toujours la TOTALITÉ des valeurs**, coupure ou non : la coupure est une accommodation de hauteur, dont une annonce audio ne consomme aucune. Figé par garde, et prouvé mordant par injection.

## 3.16.0 — 2026-08-24

### Ajouté
- La tête de tuile de `ZSmartSelectPresenter` porte la teinte normalisée et la pastille du cœur dès qu'un résolveur et des jetons existent — sans duplication de la normalisation ni de la résolution d'icône ; sans déclaration, tuile inchangée au pixel. L'orphelin, le chargement et la lecture seule gardent leurs signaux.
## 3.13.0 — 2026-08-24

### Corrigé
- `ZSmartSelectPresenter` honore le contrat d'orphelin du rendu natif : une valeur persistée absente du catalogue est **signalée** (option synthétique désactivée, clé l10n `choiceUnresolved` surchargeable) — jamais rendue comme un champ vide qui soumettrait quand même. Tuile, modal, multi-sélection et chemin asynchrone (`optionsLoader`).

## 2.1.0 — 2026-08-17

### Ajouté

#### Le présentateur riche gouverne lui aussi les trois gestes séparément

Pendant exact du correctif livré dans `zcrud_core` : `ZSmartSelectPresenter`
portait la **même** garde tout-ou-rien. Un hôte enrôlant ce présentateur
globalement n'atteignait jamais le rendu natif du cœur — le correctif du cœur
seul ne l'aurait donc pas débloqué.

Les trois gestes suivent désormais `offersCreate` / `offersEdit` / `offersCopy`,
avec le même repli **fermant** et la même doctrine : un geste refusé est
**absent**, jamais inerte.

Le site qui gouverne le slot d'actions des options a été tranché après mesure :
un gestionnaire n'offrant aucun geste n'ajoute aucune surface — le ré-activer
ouvrirait une feuille sans action.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_select.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`fp-1-2`, `fp-4-1`, codes
  `CR-SELECT-*`, `CR-REQUIRED-INDICATOR`, `DP-15`) et des comparatifs
  nominatifs à des applications legacy, conservation des invariants citables
  (`AD-1`, `AD-2`, `AD-4`, `AD-10`, `AD-13`) et de la substance technique
  (chaîne de résolution, apparence de référence, correspondance couleur →
  rôle). Aucun changement de code — la revue ne porte que sur des
  commentaires.

## [0.2.1]

Substrat initial du satellite sélection.

- Arbre `pubspec`, barrel, `lib/src/{domain,data,presentation}`, garde de
  confinement.
- Ne dépend que de `zcrud_core` parmi les paquets zcrud.
- Déclare le fork vendorisé privé `awesome_select` comme dépendance feuille,
  gardée comme déclarée par ce seul paquet.
- Publié sous licence MIT.

Historique antérieur : voir `git log` sur `packages/zcrud_select/`.
