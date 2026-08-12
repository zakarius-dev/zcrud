# Site zcrud (Docusaurus 3)

Site de documentation du monorepo zcrud, généré par [Docusaurus 3](https://docusaurus.io/).
Le contenu Markdown n'habite **pas** ce dossier : il est lu directement depuis
`../docs/site/` (voir `docs.path` dans `docusaurus.config.js`) — la charte documentaire
(`../docs/site/charte.md`) régit ce contenu, pas ce paquet.

## Commandes courantes (depuis la racine du monorepo, via melos)

```bash
melos run doc:api     # dart doc sur chaque paquet -> website/static/api/
melos run doc:site    # doc:api puis build Docusaurus -> website/build/
melos run doc:deploy  # publie website/build/ sur la branche gh-pages (build local, pas de CI)
```

Équivalents directs (depuis `website/`) :

```bash
pnpm install
pnpm run start   # serveur de dev local
pnpm run build   # build de production dans build/
pnpm run serve   # sert le build de production en local
```

## Versionnement des docs

Le versionnement Docusaurus est **activé** (`docs.includeCurrentVersion: true`) — les hôtes
qui épinglent un tag du dépôt peuvent consulter la documentation figée à cette version.

**Aucune version n'a encore été coupée.** Couper une version fige une copie complète des
pages de `docs/site/` sous `website/versioned_docs/` et `website/versioned_sidebars/`,
et ajoute l'entrée à `website/versions.json` — c'est un geste délibéré, pas un effet de
bord d'un build. La commande (à lancer manuellement, depuis `website/`, quand une version
stable de la documentation doit être gelée — typiquement en même temps qu'un tag de
release) :

```bash
pnpm run docusaurus docs:version 0.87.0
```

Remplacer `0.87.0` par le numéro de version réellement publié. Committer ensuite
`website/versioned_docs/`, `website/versioned_sidebars/` et `website/versions.json`.

## Recherche

Recherche **locale** (aucun service tiers, aucune clé) via
[`@easyops-cn/docusaurus-search-local`](https://github.com/easyops-cn/docusaurus-search-local).
L'index est généré au moment du `build` — rien à configurer côté hébergement.

## Référence d'API (`/api`)

Le lien « Référence d'API » de la barre de navigation pointe vers `/zcrud/api/`, un
dossier statique (`website/static/api/`, gitignoré) peuplé par `melos run doc:api`
(`dart doc` sur chaque paquet). Ce dossier est **hors du périmètre de ce lot** : tant
qu'il n'a pas été généré, le lien renvoie une page 404 sur le site publié — attendu,
documenté, pas un bug de ce site.

## Déploiement

`melos run doc:deploy` (→ `dart run scripts/doc/deploy_site.dart`) publie `website/build/`
sur la branche `gh-pages` depuis le poste, sans GitHub Actions (la CI du dépôt est à
l'arrêt). Configuration GitHub Pages associée dans `docusaurus.config.js` :
`organizationName: "zakarius-dev"`, `projectName: "zcrud"`,
`deploymentBranch: "gh-pages"`, `url`/`baseUrl` en conséquence.
