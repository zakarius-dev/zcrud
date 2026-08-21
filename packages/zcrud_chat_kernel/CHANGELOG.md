# Changelog

Toutes les modifications notables de `zcrud_chat_kernel` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.2.0 — 2026-08-21

### Corrigé — une garde de contrat attrapait une déclaration pour un appel

La garde « un verbe = un seul site d'appel » cherchait le nom d'un membre d'effet
**partout**, et attrapait donc un **constructeur nommé** homonyme — une
déclaration, jamais une invocation.

**La propriété protégée est inchangée** ; seul le proxy qui la mesure a été
resserré, par une exclusion exigeant les trois traits simultanés d'une
déclaration : début de ligne, récepteur commençant par une **majuscule**, et
parenthèse immédiate. La position seule ne distingue rien — un appel réel peut
aussi commencer une ligne.

Prouvé dans les deux sens : trois formes d'appel injectées la font rougir, et le
constructeur nommé ne la fait plus rougir. Perte de couverture assumée et écrite
dans la garde : un appel **statique** en tête de ligne échapperait — impossible
ici, les huit membres d'effet étant des membres d'instance.

## [0.85.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu, patron
  kernel/satellite, installation, démarrage rapide, API principale, cas
  limites et invariants.
- Fiche `docs/site/paquets/zcrud_chat_kernel.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, exemples compilables sur les entités
  principales, invariants d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Aucun changement de code — la revue
  ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_chat_kernel/`.
