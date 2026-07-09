# zcrud

**Monorepo Flutter unifié pour les fonctionnalités CRUD riches** — affichage et édition de données, extrait et consolidé à partir des applications existantes (DODLP, IFFD, DLCFTI) pour éliminer le code dupliqué copié-collé d'un projet à l'autre.

> ⚠️ Projet en cours de conception (phase de planification BMAD). L'architecture et le découpage des packages sont en cours de définition.

## Objectif

Fournir un ensemble de packages Dart/Flutter réutilisables, importables directement dans les projets existants en remplacement du code redondant, avec :

- **Listes dynamiques** (`DynamicList`) : affichage tableau/liste, recherche, filtres, tri, pagination, export.
- **Édition dynamique** (`DynamicEdition`) : formulaires générés à partir d'un schéma, prenant en charge **tous les types de champs** (texte, nombre, date, booléen, énumération, relation, listes imbriquées, fichier/image, géo/carte, téléphone, pays/devise, richtext, formule, table…).
- **Éditeur & lecteur Markdown** riche, pleinement pris en charge (base Quill, conversion Delta ↔ Markdown, embeds tables et formules LaTeX).
- **Cartes mentales** (mindmaps) : affichage et édition.
- **Flashcards** : édition, apprentissage, répétition espacée.

## Principes de conception

- **Riverpod** pour la gestion d'état, avec **rebuilds réactifs granulaires** (résolution du bug historique de « rafraîchissement complet du formulaire » à chaque frappe).
- **Génération de code maximale** pour la sérialisation : `freezed` + `json_serializable` (abandon de `reflectable`).
- **Monorepo modulaire** (melos) : chaque projet consommateur importe uniquement les sous-packages dont il a besoin.

## Découpage prévu des packages (provisoire)

| Package | Responsabilité |
|---|---|
| `zcrud_core` | Schéma de champs, moteur liste + édition, data layer, l10n |
| `zcrud_markdown` | Éditeur/lecteur Markdown riche + embeds (tables, LaTeX) |
| `zcrud_mindmap` | Cartes mentales (affichage + édition) |
| `zcrud_flashcard` | Flashcards (édition, apprentissage, répétition espacée) |

> Le découpage définitif sera arrêté en phase d'architecture.

## Consommateurs cibles

1. **DODLP** (prioritaire) — source et premier consommateur.
2. **lex_douane** — projet le plus récent, à équiper d'édition de formulaires riches, flashcards et mindmaps.

## Méthodologie

Ce dépôt est piloté avec [BMAD-METHOD](https://github.com/bmad-code-org). Les artefacts de planification vivent dans `_bmad-output/planning-artifacts/`.
