---
title: Charte documentaire zcrud
description: La loi du chantier documentation — gabarits, conventions, anti-pièges.
sidebar_position: 99
---

# Charte documentaire zcrud

Cette charte régit **tout** contenu documentaire du monorepo : README de paquets, dartdoc,
pages de `docs/site/`. Elle est appliquée par les rédacteurs (humains ou agents) et vérifiée
par le gate `melos run doc:diff-gate` (aucune modification de code) et par les greps de
propreté du gate final.

## Principes

1. **Français uniquement.** Identifiants de code, noms de fichiers et ancres en anglais.
   Orthographe et diacritiques complets.
2. **Orientée consommateur externe.** Le lecteur est un développeur qui intègre un paquet,
   pas un archéologue du dépôt : **bannir** les références de story (`E3-3a`, `ES-5.1`,
   `CHAT-0b`), les numéros d'AC (`AC2`, `INVARIANT AC-11`), les emoji de journal (🔴/⚠️/🟢),
   les mentions `origine:` et les noms d'applications legacy comme justification. Les
   invariants d'architecture restent cités **par nom stable** (« invariant AD-13 (RTL) »)
   avec pour cible unique leur définition canonique : `docs/site/concepts/invariants.md`.
3. **Exemples compilables.** Tout bloc ```dart d'un README ou d'une dartdoc doit compiler
   tel quel contre l'API publique du paquet (imports du barrel uniquement).
4. **Markdown pur, générateur-agnostique.** Front-matter YAML minimal (`title`,
   `description`, `sidebar_position`), ancres kebab-case, liens **relatifs** intra-dépôt,
   pas d'HTML brut, tableaux GFM.

## Gabarit README de paquet

Sections dans cet ordre exact (ancres stables) :

```markdown
# zcrud_<nom>

<pitch : 1-2 phrases — le rôle, et l'invariant d'architecture qui le borne.>

## Aperçu {#apercu}
<rôle dans l'écosystème, schéma des dépendances internes (vers zcrud_core, kernels…),
 quand utiliser ce paquet — et quand NE PAS l'utiliser.>

## Installation {#installation}
<dépendance git + dependency_overrides, renvoi vers docs/private-git-consumption.md.>

## Démarrage rapide {#demarrage-rapide}
<UN exemple minimal complet et compilable.>

## Concepts clés {#concepts-cles}
<2-4 concepts propres au paquet, chacun avec lien vers docs/site/concepts/ si transverse.>

## API principale {#api-principale}
<tableau : type public → une ligne de rôle. Exhaustif sur les types du barrel.>

## Cas limites et invariants {#cas-limites}
<comportements défensifs, valeurs nulles, RTL, thème, offline… ce qui surprendrait.>

## Voir aussi {#voir-aussi}
<paquets liés, fiche docs/site/paquets/<nom>.md, guides transverses.>

## Licence {#licence}
MIT — voir la racine du dépôt.
```

## Gabarit dartdoc

- **1re phrase autonome** (c'est elle qu'affichent les index) : verbe au présent, rôle du
  symbole, sans « Cette classe… ».
- Puis, selon la richesse du symbole : rôle détaillé, **un exemple** en bloc ```dart,
  `## Cas limites`, invariants (« invariant AD-10 : la désérialisation ne jette jamais »),
  `Voir aussi : [AutreType]`.
- Textes répétés entre symboles : `{@template zcrud.<sujet>}` / `{@macro zcrud.<sujet>}` —
  jamais de copier-coller divergent.
- Les moteurs internes (`lib/src/**` non exportés) reçoivent au minimum un **en-tête de
  module** : dartdoc de `library;` expliquant le rôle du fichier, ses collaborations et ses
  invariants.
- Ce qui est **retiré** lors de la normalisation : références de story/AC, emoji de journal,
  historique des correctifs (« depuis la v0.63… »), débats d'implémentation. Ce qui est
  **conservé** : les invariants, les cas limites, les avertissements de contrat.

## Anti-pièges (dérivés de la sécurisation des gardes)

1. **Secrets : bannis MÊME en commentaire.** Les motifs de vrais secrets (`AIza…`, `AKIA…`,
   `sk-…`, blocs PEM, `Bearer` + littéral, `xox…`) restent scannés commentaires inclus.
   N'écrivez jamais un exemple contenant une clé plausible — utilisez `<VOTRE_CLE>`.
2. **URLs en dartdoc** : autorisées (les gardes anti-URL scannent le source strippé), mais
   uniquement vers des cibles stables (pub.dev, dart.dev, api.flutter.dev). Pas d'endpoints.
3. **Fichiers gelés** : la liste des fichiers `lib/` où l'insertion de dartdoc est interdite
   (gardes positionnelles non durcies) est tenue ci-dessous — vide par défaut, complétée en
   sortie de Phase 0 :
   - _(aucun à ce jour)_
4. **Matrices de paramètres** : `packages/zcrud_get/doc/parameter-matrix-z-get-form-presenter.md`
   et `packages/zcrud_navigation/doc/parameter-matrix-z-adaptive-presenter.md` sont comparées
   **byte à byte** par des tests (mesuré en Phase 0 — aucune tolérance). **Interdiction
   totale d'y toucher** dans un lot de rédaction : pas de front-matter, pas de reformulation.
   Le site les référencera par lien, jamais par copie.
5. **Jamais** éditer un `*.g.dart`, un `pubspec.yaml`, ni un fichier de `test/` dans un lot
   de rédaction — le gate `doc:diff-gate` échoue sinon.

## Vérification d'un lot de rédaction

Depuis la racine : `melos run doc:diff-gate` (RC=0) puis `melos run analyze` (RC=0) puis
`flutter test` **depuis le dossier** de chaque paquet touché. `public_member_api_docs` est
activé dans l'`analysis_options.yaml` du paquet en fin de lot — l'exhaustivité dartdoc
devient alors un invariant vérifié par l'analyse.

## Publication du site

Le site (contenu de `docs/site/` + référence d'API) est un **Docusaurus 3** construit et
publié **depuis le poste**, sans aucun GitHub Actions : la CI du dépôt est à l'arrêt pour
facturation (cf. `CLAUDE.md`), donc la publication n'est déclenchée par personne d'autre que
la personne qui exécute le cycle ci-dessous.

### Cycle de publication

Depuis la racine, dans l'ordre, chaque étape devant réussir avant la suivante :

```bash
melos run doc:api     # dart doc sur chaque paquet -> website/static/api/<pkg>/
melos run doc:site    # doc:api puis build Docusaurus -> website/build/
melos run doc:deploy  # publie website/build sur la branche gh-pages (git worktree dédié)
```

`melos run doc:deploy` (`scripts/doc/deploy_site.dart`) refuse de publier si l'arbre de
travail principal est sale (hors `pubspec.lock` racine) ou si `website/build` est absent ou
vide, et n'exécute jamais `git checkout`/`git stash` sur l'arbre principal — seulement sur un
`git worktree` temporaire dédié à `gh-pages`, nettoyé en fin d'exécution y compris en cas
d'échec. Un `--dry-run` exécute tout le cycle sauf le push final, pour vérifier ce qui serait
publié avant de le décider réellement.

### Coupe de version

Le versionnement de la documentation est **activé** (les hôtes épinglent des tags — un
lecteur venu d'un tag ancien doit retrouver la doc de ce tag, pas la doc `main`). À
**chaque tag publié** du dépôt, avant de reconstruire et publier le site, couper une
nouvelle version depuis `website/` :

```bash
cd website
pnpm run docusaurus docs:version <version>   # ex. 3.3.0 — le tag publié, sans le « v »
```

Cette commande fige l'état courant de `docs/site/` sous `website/versioned_docs/` et
`website/versioned_sidebars/`, et ajoute l'entrée correspondante à
`website/versions.json`. Elle se fait **après** que le contenu de `docs/site/` pour ce tag
est stabilisé et **avant** `melos run doc:site` de ce cycle de publication — sinon la
version coupée capture un contenu déjà en avance sur le tag qu'elle est censée figer.

### Artefacts non commités

`website/node_modules/`, `website/build/`, `website/.docusaurus/` et `website/static/api/`
sont **gitignorés** : ce sont des artefacts régénérés par le cycle ci-dessus (toolchain Node,
build Docusaurus, cache, référence d'API `dart doc`), jamais une source à committer. Seuls
`website/versioned_docs/`, `website/versioned_sidebars/` et `website/versions.json` (produits
par la coupe de version) sont des sources et suivent le dépôt normalement.
