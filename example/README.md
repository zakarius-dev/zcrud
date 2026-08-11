# zcrud_example — application de démonstration

Vitrine exécutable de l'écosystème **zcrud** : chaque écran illustre une capacité du
monorepo, branchée sur les vrais paquets (aucun mock du moteur). C'est aussi le banc de
mesure des invariants de réactivité — l'indicateur de rebuilds (`lib/support/
rebuild_indicator.dart`) matérialise la promesse « taper ne reconstruit que le champ
courant ».

## Lancer

```bash
cd example
flutter run          # mobile/desktop
flutter run -d chrome
```

Le sélecteur de binding (`lib/binding/binding_selector.dart`) permet de rejouer les mêmes
écrans sous `ZcrudScope` natif, Riverpod, GetX ou provider — la démonstration que le cœur
est agnostique au gestionnaire d'état.

## Les écrans (`lib/demos/`)

| Écran | Ce qu'il démontre |
|---|---|
| `edition_demo_screen` | Formulaire complet généré depuis un `ZFieldSpec[]` — rebuilds granulaires |
| `edition_stepper_demo` | Édition multi-étapes (`ZStepperEdition`) |
| `stepper_sub_list_demo_screen` | Sous-listes imbriquées dans un stepper |
| `list_demo_screen` (+ `list_demo_data`) | `DynamicList` : tri, recherche sans accents, sélection, pagination |
| `markdown_demo_screen` | Éditeur/lecteur Markdown riche (Quill, LaTeX, tables, plein écran) |
| `geo_demo_screen` | Champs géo : point, tracé, cercle, aperçu en flux, plein écran |
| `intl_demo_screen` | Téléphone, pays, devise, état/région |
| `study_session_demo_screen` | Session de révision (flashcards, planification SRS) |
| `export_demo_screen` | Export PDF/Excel depuis une projection de liste |
| `offline_demo_screen` | Offline-first : store local source de vérité, sync différée |
| `ship_documents_demo_screen` | Cas métier composé (documents + médias) |
| `reference_form` | Le formulaire de référence des mesures de performance |
| `iffd_visual_preset` | Préset visuel d'un hôte réel appliqué par thème (zéro fork de widget) |
| `showcase/` | Galeries ciblées par famille de champs |

Le registre central (`lib/demos/demo_registry.dart`) est le point d'entrée : ajouter un
écran = une entrée dans le registre.

## Rôle dans le dépôt

- **Vitrine**, pas spécification : les contrats vivent dans les tests des paquets ; la démo
  les illustre.
- `example/` est **hors** du bloc `workspace:` (frontière volontaire) — il est analysé par
  `melos run analyze:example` et testé par `cd example && flutter test`.

Voir la [documentation du monorepo](../docs/site/index.md).
