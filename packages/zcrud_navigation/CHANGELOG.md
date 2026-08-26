# Changelog

Toutes les modifications notables de `zcrud_navigation` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.23.0 — 2026-08-26

### Corrigé
- 🔴 **La feuille d'édition réserve la place du clavier.** Elle est présentée en mode contrôlé — le réglage qui transfère à l'appelant la charge des encarts — et ne les appliquait nulle part : le champ qui prenait le focus passait **sous le clavier**, invisible, sans que le défilement le ramène. On saisissait à l'aveugle, et le message de validation était invisible lui aussi.

### Ajouté
- `ZSheetKeyboardInset` — nœud **inconditionnel** qui retranche l'encart clavier du corps de la feuille, exporté pour un assemblage maison.

### Attention
- **Le nœud est inconditionnel à dessein.** Ne l'insérer que lorsque l'encart n'est pas nul est géométriquement correct **et détruit la saisie** : le champ est reconstruit et le texte déjà tapé disparaît. Le prix est de deux lignes dans l'arbre de la seule voie feuille ; les voies page et dialogue sont inchangées à l'octet.
- **Retrancher l'encart de la hauteur maximale ne résout rien** : la feuille est ancrée au bas de l'écran entier, donc une feuille plus courte reste sous le clavier — et cumuler les deux voies compte l'encart **deux fois**.
- Un `maxHeight` posé par l'hôte reste prioritaire et borne la feuille entière : un corps défilable est recommandé.
- 🔴 **Hôte qui compensait par son propre rembourrage : le retirer**, sinon la réservation est double.

## 0.93.0 — 2026-08-13

### Corrigé

- `ZEditionScaffold` : les actions de `ZEditionChrome.extraActions` étaient
  rendues **deux fois** en modes `dialog` et `sheet` — une fois dans l'en-tête,
  une fois dans la barre d'actions en pied. Tout bouton supplémentaire
  apparaissait donc en double, sans aucune erreur pour le signaler. Elles ne
  sont désormais rendues qu'à **un seul endroit**, celui qui était déjà le seul
  actif en mode `page` : la rangée des actions positives, juste **avant**
  l'enregistrement (en-tête repliable en `page`, barre d'actions en pied en
  `dialog` et en `sheet`). L'en-tête compacte de `dialog`/`sheet` ne porte plus
  que le titre.

### Documenté

- L'emplacement d'écran des actions supplémentaires est désormais tabulé par
  mode, à la fois sur `ZEditionChrome.extraActions` et sur `ZEditionScaffold` :
  le contrat « exactement une fois, avant l'enregistrement » est lisible au
  point d'usage.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_navigation.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références de story/epic (`EX-UI.*`, codes `AC`/`NFR`),
  des comparatifs nominatifs à des applications legacy et des dates de
  correctif, conservation des invariants citables (`AD-1` à `AD-15`) et de
  la substance technique (chaîne de résolution paramètre/jeton/référence,
  inertie déclarée par mode, garde d'identité d'arbre). Aucun changement de
  code — la revue ne porte que sur des commentaires.

### Inchangé

- `doc/parameter-matrix-z-adaptive-presenter.md` — comparé byte à byte par
  des tests, jamais touché dans ce chantier.

Historique antérieur : voir `git log` sur `packages/zcrud_navigation/`.
