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
