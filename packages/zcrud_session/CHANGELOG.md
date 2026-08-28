# Changelog

Toutes les modifications notables de `zcrud_session` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.28.0 — 2026-08-28

### Ajouté

- `ZFlashcardAnswerInput` devient **contrôlable et pluggable**, par cinq
  contrats strictement optionnels :
  - `choiceContentBuilder` — remplace le `Text` brut d'un choix de QCM, sans
    toucher à la sélection, aux sémantiques ni à la cible tactile. Un hôte qui
    rendait ses choix en markdown avait dû **cloner le widget entier** pour y
    parvenir ; il peut revenir au socle.
  - `writtenAnswerFieldBuilder` — remplace le `TextFormField` de la réponse
    rédigée. Le builder reçoit le `controller` et le `focusNode` **détenus par
    la surface** : le texte saisi dans le champ injecté part au barème sans
    câblage supplémentaire.
  - `initialAnswer` — préremplit la réponse rédigée, **une seule fois, au
    montage**. Jamais réinjectée : une valeur repoussée à chaque build
    écraserait la sélection et le curseur en pleine frappe (invariant AD-2).
  - `onAnswerChanged` — observe la réponse courante
    (`ZFlashcardAnswerDraft` : texte, positions cochées, réponse Vrai/Faux).
    Passe par un écouteur, jamais par un `setState` : observer la saisie ne
    reconstruit aucun frère.
  - `isSubmitted` — impose le verrou de soumission (`null` : la correction
    locale décide seule). `true` rend inertes les choix, les boutons
    Vrai/Faux, le champ rédigé, « Indice » et « Je ne sais pas », **sans
    peindre de correction** : la surface n'en fabrique pas. `false` ne rouvre
    pas une soumission déjà consommée.
- `ZFlashcardAnswerDraft` et les typedefs `ZFlashcardChoiceContentBuilder` /
  `ZFlashcardWrittenAnswerFieldBuilder`.

### Corrigé

- L'observation de la réponse rédigée ne suit plus les notifications de
  **sélection** du `TextEditingController` : poser le focus dans le champ
  (l'offset passe de `-1` à `0`) émettait une « saisie » vide avant la
  première frappe. Défaut trouvé par la garde de granularité pendant sa
  propre mise au point, avant toute publication.

### Inertie

- Sans aucun de ces paramètres, l'arbre de widgets des trois variantes (QCM,
  Vrai/Faux, rédaction) est **strictement identique** à celui de la 3.27.0 —
  garde d'égalité stricte sur la séquence complète des types descendants,
  jamais un `contains`.

## [Non publié] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas
  limites et invariants.
- Fiche `docs/site/paquets/zcrud_session.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel (trois moteurs de runtime, surface de saisie, boutons de notation,
  pile swipeable, sélecteur de session, écran de fin, dialog de filtres) :
  première phrase autonome, exemples compilables sur les entités
  principales, invariants d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Purge des références de story et
  d'epic, des emoji de journal et des historiques de correctifs — conservation
  des invariants, cas limites et avertissements de contrat (notamment la
  voie d'écriture SRS unique, l'arène des gestes de la surface de saisie et
  la correspondance carte ↔ réponse de l'examen blanc en liste). Aucun
  changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_session/`.
