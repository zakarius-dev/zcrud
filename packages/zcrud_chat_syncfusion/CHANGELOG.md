# Changelog

Toutes les modifications notables de `zcrud_chat_syncfusion` sont
documentées dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.32.0 — 2026-08-29

### Renforcé — la garde FR-26 voit désormais les couleurs qu'elle laissait passer

La garde de pureté du paquet interdisait la couleur codée en dur avec deux
motifs : `Color(0x` et `Colors.[a-z]`. Mesuré par injection dans `lib/` : huit
formes de couleur parfaitement banales passaient **vertes** — l'entier décimal
(`Color(4280391411)`, la même couleur écrite en base 10), le `Color.from(` à
composantes littérales, l'hexadécimal de couleur écrit hors de `Color(`
(`0x2196F3`, `0x80112233`), le grand entier décimal nu, l'espace après la
parenthèse (`Color( 0xFF0000FF)`), et les deux formes multi-lignes.

Le scan porte maintenant sur le contenu entier de la source (commentaires
retirés), donc les formes coupées par un saut de ligne sont atteignables, et
chaque faute nomme le motif qui a mordu plutôt que le seul fichier.

Deux renoncements sont **documentés** dans la garde plutôt que laissés
implicites : un hexadécimal de 8 chiffres à octet de tête quelconque n'est pas
distinguable d'un masque de bits ou d'une graine de hachage, et le
`Color.from(` à composantes **calculées** reste permis — c'est la voie légitime
de composition d'une couleur de thème. Six contre-preuves de non-faux-positif
figent ce périmètre.

Aucune couleur codée en dur n'est exhumée dans `lib/` : le durcissement n'a
rien à corriger ici, c'est une garde pour l'avenir. **Aucun impact
consommateur** — rien de `lib/` ne change.

## 3.0.0 — 2026-08-18

### 🔴 Corrigé — sous la coquille, le message de REQUÊTE n'était jamais peint

Un hôte dont le renderer rend `null` pour le rôle utilisateur — **le comportement
recommandé**, pour ne pas manger les astérisques de ce qu'il a tapé — voyait un
vide d'environ 180 px à la place de sa question. La réponse, elle, s'affichait.

**Mécanisme établi**, après que l'hôte eut éliminé trois hypothèses par mesure :
la référence de skin fournissait à la **requête seule** une bordure portant un
rayon **directionnel** ; le rendu de Syncfusion appelle `getOuterPath(bounds)`
**sans transmettre de `TextDirection`** ; Flutter ne peut donc pas résoudre le
rayon et **lève** ; le paint s'interrompt **avant** de peindre l'enfant.

La trace le dit : géométrie valide, `RenderParagraph … NEEDS-PAINT`. Le texte
était **construit, mesuré, jamais peint** — ce qui explique pourquoi la sonde de
l'hôte, un cadre jaune vif, restait elle aussi invisible.

La bordure directionnelle est désormais **résolue** avec la direction du contexte
avant d'être transmise à Syncfusion. Le rendu RTL est conservé, le contrat
`null → rendu neutre` n'est pas touché, et **aucune dépendance Syncfusion**
n'entre dans `zcrud_chat` (garde de graphe verte, `CORE OUT = 0`).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas limites
  et invariants.
- Fiche `docs/site/paquets/zcrud_chat_syncfusion.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, invariants d'architecture cités par leur
  nom stable (`docs/site/concepts/invariants.md`). Purge des références de
  lot et de correctif, des citations de fichiers/lignes d'un backend legacy,
  des emoji de journal — conservation des invariants, cas limites et
  avertissements de contrat (classement en canal des balises du fil
  textuel, absence d'identifiant de séquence, caractère strictement additif
  du skin de notebook, rôle non-annonçable de `AssistMessage.data`). Aucun
  changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_chat_syncfusion/`.
