# zcrud

**Écosystème Flutter de CRUD riche, déclaratif et modulaire.** Un même schéma de champs
(`ZFieldSpec`) génère les formulaires d'édition (`DynamicEdition`) et les tableaux de liste
(`DynamicList`) — avec des rebuilds **granulaires** (taper 100 caractères ne reconstruit que
le champ courant), une couche data **offline-first** et des familles de champs riches :
Markdown (Quill + LaTeX/tables), géo, téléphone/pays/devise, sous-listes, stepper…

Le monorepo compte **39 paquets** consommés en dépendance git par plusieurs applications de
production. La documentation complète vit dans [`docs/site/`](docs/site/index.md).

## Les piliers

- **Un schéma, deux surfaces** — le modèle annoté (`@ZcrudModel`) génère sérialisation,
  `ZFieldSpec[]` et enregistrement au registre ; formulaires et listes en découlent.
- **Réactivité Flutter-native** — aucun gestionnaire d'état dans le cœur (`ChangeNotifier` /
  `ValueListenable`) ; l'intégration Riverpod/GetX/provider vit dans des paquets de binding.
- **Architecture hexagonale** — domaine pur, ports neutres (`ZRepository`, `Either<ZFailure,T>`),
  adaptateurs isolés (Firestore/Hive, Syncfusion, Quill, cartes). Le graphe de dépendances
  est **acyclique et vérifié par gate**.
- **Défensif par contrat** — un champ absent ou corrompu ne fait jamais échouer le parent ;
  évolution de schéma additive seulement.
- **RTL, a11y, thème** — variantes directionnelles, cibles ≥ 48 dp, zéro couleur codée en dur.

## Carte des paquets

| Capacité | Paquets |
|---|---|
| **Cœur** | `zcrud_core` (schéma, moteur d'édition, ports, thème, l10n) · `zcrud_annotations` · `zcrud_generator` |
| **Bindings d'état** | `zcrud_riverpod` · `zcrud_get` · `zcrud_provider` |
| **Liste & données** | `zcrud_list` (Syncfusion) · `zcrud_firestore` (offline-first) · `zcrud_select` |
| **Rich-text** | `zcrud_markdown` (Quill, LaTeX, tables) · `zcrud_html` |
| **Étude** | `zcrud_study` · `zcrud_study_kernel` · `zcrud_session` · `zcrud_flashcard` · `zcrud_exam` · `zcrud_mindmap` · `zcrud_note` · `zcrud_document` |
| **Chat** | `zcrud_chat` · `zcrud_chat_kernel` · `zcrud_chat_markdown` · `zcrud_chat_material` · `zcrud_chat_study` · `zcrud_chat_syncfusion` |
| **Champs spécialisés** | `zcrud_geo` · `zcrud_geo_location` · `zcrud_intl` (téléphone/pays/devise) · `zcrud_media` · `zcrud_field_extras` |
| **Export** | `zcrud_export` · `zcrud_export_pdf` · `zcrud_export_ui` |
| **UI & navigation** | `zcrud_ui_kit` · `zcrud_responsive` · `zcrud_menu` · `zcrud_navigation` · `zcrud_dnd` · `zcrud_reorder` |

Chaque paquet expose son API par un barrel unique (`lib/<pkg>.dart`) et porte son README.

## Démarrer

- [Démarrage rapide](docs/site/demarrage-rapide.md) — de zéro à un écran CRUD.
- [Consommer en dépendance git](docs/private-git-consumption.md) — la recette exacte
  (`dependency_overrides` sur la fermeture des paquets internes).
- [Concepts](docs/site/concepts/) — `ZFieldSpec`, architecture hexagonale, réactivité
  granulaire, offline-first, invariants d'architecture.
- Application de démonstration : [`example/`](example/README.md).

## Développer dans le monorepo

```bash
dart pub get                 # bootstrap (pub workspaces)
dart run melos run generate  # codegen (build_runner)
dart run melos run analyze   # analyse complète (packages + scripts + example)
cd packages/<pkg> && flutter test   # tests — toujours depuis le dossier du paquet
dart run melos run verify    # gates de merge (graphe acyclique, secrets, codegen…)
```

La [charte documentaire](docs/site/charte.md) régit README, dartdoc et pages du site.

## Licence

MIT.
