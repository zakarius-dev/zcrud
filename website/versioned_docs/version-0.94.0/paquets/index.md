---
title: Catalogue des paquets
description: Les 40 paquets zcrud, groupés par capacité — rôle en une ligne et fiche dédiée.
sidebar_position: 1
---

# Catalogue des paquets

zcrud compte **40 paquets**, groupés ci-dessous par capacité — le même découpage que la
carte des paquets du dépôt. Chaque paquet expose son API par un barrel unique
(`lib/<pkg>.dart`) ; l'implémentation sous `lib/src/` n'est pas un contrat. Le graphe de
dépendances entre paquets est acyclique et vérifié par gate
([invariant AD-1](../concepts/invariants.md#ad-1)) : `zcrud_core` ne dépend d'aucun
satellite, chaque satellite dépend du cœur.

Les liens ci-dessous pointent vers la fiche dédiée de chaque paquet (gabarit défini par la
[charte documentaire](../charte.md)) ; les fiches manquantes arrivent au fil de la
rédaction.

## Cœur {#coeur}

| Paquet | Rôle |
|---|---|
| [`zcrud_core`](./zcrud_core.md) | Domaine pur et moteur d'édition Flutter-natif : `ZFieldSpec`, ports, thème, l10n, `ZcrudScope`. Aucune dépendance lourde. |
| [`zcrud_annotations`](./zcrud_annotations.md) | Annotations `@ZcrudModel`/`@ZcrudField`/`@ZcrudId`, lues statiquement par le générateur. |
| [`zcrud_generator`](./zcrud_generator.md) | Générateur `build_runner` : (dé)sérialisation, `ZFieldSpec[]` et enregistrement au registre depuis un modèle annoté. |

## Bindings d'état {#bindings-etat}

| Paquet | Rôle |
|---|---|
| [`zcrud_riverpod`](./zcrud_riverpod.md) | Binding état/injection Riverpod (optionnel) — cible lex_douane/IFFD. |
| [`zcrud_get`](./zcrud_get.md) | Binding état/injection GetX + get_it (optionnel) — cible DODLP. |
| [`zcrud_provider`](./zcrud_provider.md) | Binding état/injection `provider` (optionnel). |

## Liste & données {#liste-donnees}

| Paquet | Rôle |
|---|---|
| [`zcrud_list`](./zcrud_list.md) | Backend de **rendu** Syncfusion (`SfDataGrid`) du port `ZListRenderer` — pas l'écran de liste (voir `zcrud_screen`). |
| [`zcrud_firestore`](./zcrud_firestore.md) | Adaptateurs Firestore/Hive offline-first derrière les ports neutres du cœur. |
| [`zcrud_select`](./zcrud_select.md) | Présentateur de sélection (page/dialogue/feuille) au-dessus d'un fork vendored d'`awesome_select`. |

## Rich-text {#rich-text}

| Paquet | Rôle |
|---|---|
| [`zcrud_markdown`](./zcrud_markdown.md) | Édition/lecture Markdown riche (Quill) avec `ZCodec` pluggable et embeds LaTeX/tableaux. |
| [`zcrud_html`](./zcrud_html.md) | Champ HTML riche via WebView à contrôleur isolé — exclusif de `zcrud_markdown`. |

## Étude {#etude}

| Paquet | Rôle |
|---|---|
| [`zcrud_study`](./zcrud_study.md) | Orchestration de présentation des outils d'étude (sections paramétriques, layout sectionné). |
| [`zcrud_study_kernel`](./zcrud_study_kernel.md) | Noyau bas niveau de l'étude : dossiers, hiérarchie à 2 niveaux, modes de révision, sélecteur de session. |
| [`zcrud_session`](./zcrud_session.md) | Moteur de session (`ZStudySessionEngine`) : file SRS cyclique, écriture par seam `reviewCard` unique. |
| [`zcrud_flashcard`](./zcrud_flashcard.md) | Flashcards en répétition espacée : modèle, planificateur SuperMemo-2, dossiers/sessions, repository offline-first. |
| [`zcrud_exam`](./zcrud_exam.md) | Domaine des examens datés (rappels, calcul de proximité par horloge injectée). |
| [`zcrud_mindmap`](./zcrud_mindmap.md) | Cartes mentales : arbre immuable, vue à disposition automatique, éditeur en plan. |
| [`zcrud_note`](./zcrud_note.md) | Domaine des notes intelligentes à contenu Delta typé, avec extension audio optionnelle. |
| [`zcrud_document`](./zcrud_document.md) | Domaine des documents d'étude partageables et de leur état de lecture personnel. |

## Chat {#chat}

| Paquet | Rôle |
|---|---|
| [`zcrud_chat`](./zcrud_chat.md) | Contrôleur de conversation Flutter-natif (tranches `ValueListenable`, flux reprenables). |
| [`zcrud_chat_kernel`](./zcrud_chat_kernel.md) | Noyau neutre de conversation IA (messages, blocs de contenu, sources, quotas). |
| [`zcrud_chat_markdown`](./zcrud_chat_markdown.md) | Rendu Markdown/LaTeX du chat, derrière le seam `ZChatRenderer`. |
| [`zcrud_chat_material`](./zcrud_chat_material.md) | Builders Material calqués sur la référence lex_douane pour le composeur et les réglages de chat. |
| [`zcrud_chat_study`](./zcrud_chat_study.md) | Pont chat → SRS : cartes générées depuis les conversations, pool d'étude dédupliqué. |
| [`zcrud_chat_syncfusion`](./zcrud_chat_syncfusion.md) | Coquille Syncfusion AI AssistView et normalisation de flux texte, derrière `ZChatRenderer`. |

## Champs spécialisés {#champs-specialises}

| Paquet | Rôle |
|---|---|
| [`zcrud_geo`](./zcrud_geo.md) | Champs géo (point/aire/cercle/tracé) avec adaptateur carte OpenStreetMap optionnel. |
| [`zcrud_geo_location`](./zcrud_geo_location.md) | Résolveur de position courante (`geolocator`) pour `zcrud_geo`, sans fuite de type SDK. |
| [`zcrud_intl`](./zcrud_intl.md) | Champs téléphone/pays/adresse avec métadonnées embarquées hors-ligne. |
| [`zcrud_media`](./zcrud_media.md) | Champ média (dépôt/aperçu/vignette vidéo) au-dessus du port `ZFilePicker` du cœur. |
| [`zcrud_field_extras`](./zcrud_field_extras.md) | Champs spécialisés PIN / autocomplétion / tableau éditable / icône. |

## Export {#export}

| Paquet | Rôle |
|---|---|
| [`zcrud_export`](./zcrud_export.md) | Export tabulaire Excel/PDF (Syncfusion) derrière une API neutre en octets, plus les exporteurs de liste CSV/Excel du port `ZListExporter`. |
| [`zcrud_export_pdf`](./zcrud_export_pdf.md) | Export PDF (gabarits de flashcards, documents tabulaires, exporteur de liste `ZListExporter`), sans dépendance tableur. |
| [`zcrud_export_ui`](./zcrud_export_ui.md) | Destinations d'export plateforme : aperçu/impression/partage PDF et rastérisation LaTeX. |

## UI & navigation {#ui-navigation}

| Paquet | Rôle |
|---|---|
| [`zcrud_ui_kit`](./zcrud_ui_kit.md) | Coquille de page et app-bar recherchable, états de contenu (vide/chargement/erreur), confirmation thémée, pastille de comptage. |
| [`zcrud_responsive`](./zcrud_responsive.md) | Classes de largeur de fenêtre (Material 3) et valeurs par point de rupture. |
| [`zcrud_menu`](./zcrud_menu.md) | Menus déclarés en données derrière un seam neutre : rendus liste et grille, ouverture par clic droit / appui long, repli sans dépendance tierce. |
| [`zcrud_navigation`](./zcrud_navigation.md) | Politique de présentation d'édition (page/feuille/dialogue) dérivée du point de rupture. |
| [`zcrud_screen`](./zcrud_screen.md) | Écran CRUD assemblé et déclaratif : liste, recherche, onglets, création/édition, fiche de détail, corbeille à trois gestes, gouvernance par ligne, sélection multiple et export. |
| [`zcrud_dnd`](./zcrud_dnd.md) | Glisser-déposer natif opt-in (dépôts fichiers OS, échange inter-applications). |
| [`zcrud_reorder`](./zcrud_reorder.md) | Backend de réordonnancement opt-in, avec repli zéro-dépendance si non installé. |

## Voir aussi

- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — comment ces
  capacités se répartissent en couches `domain`/`data`/`presentation`.
- [Invariants d'architecture](../concepts/invariants.md) — les règles qui bornent chaque
  paquet, dont l'acyclicité du graphe ci-dessus.
- [Guides](../guides/index.md) — recettes qui combinent plusieurs de ces paquets.
