---
title: "Product Brief — zcrud"
status: draft
created: 2026-07-09
updated: 2026-07-09
owner: Zakarius
project: zcrud
grounding: docs/technical-inventory.md
language: fr
---

# Product Brief : zcrud

## Résumé exécutif

`zcrud` est un **monorepo Flutter (melos) de packages CRUD riches réutilisables**, extrait et consolidé à partir d'un même moteur déclaratif (~11 000 lignes) aujourd'hui **cloné à l'identique dans trois applications** — DODLP, IFFD et DLCFTI — à trois stades d'évolution divergents. Ce moteur, piloté par une liste de `DynamicFormField`, génère à la fois les **formulaires d'édition** et les **tableaux de liste**. Chaque amélioration ou correction faite dans un projet doit aujourd'hui être re-portée manuellement dans les autres : le copier-coller est la source première de dette et de régressions.

zcrud remplace ce code dupliqué par des packages importables directement dans les projets existants. Il vise deux consommateurs : **DODLP en priorité** (à la fois source la plus riche et premier banc d'essai) puis **lex_douane** (projet le plus récent, à équiper d'édition de formulaires riches, de flashcards et de cartes mentales). Il **corrige par conception** le défaut le plus visible et jamais résolu des trois apps — le rafraîchissement complet du formulaire à chaque frappe (jank, perte de focus, saut de curseur) — grâce à des **rebuilds réactifs granulaires** via Riverpod. Il assied la sérialisation sur **100 % de génération de code** (freezed + json_serializable), en **abandonnant `reflectable`**.

L'ambition n'est pas seulement de dédupliquer : c'est de faire d'un **modèle annoté la source unique de vérité** dont dérivent la (dé)sérialisation, le schéma de formulaire et le rendu en liste — de sorte qu'une nouvelle application démarre en important quelques packages, et qu'une correction faite une fois profite à tout l'écosystème.

## Le problème

- **Duplication structurelle.** Le moteur (`DynamicEditionScreen`, `DynamicListScreen`, `DynamicFormField`) est copié dans 3 apps. Les écrans dépassent 1 750–4 450 lignes chacun ; toute évolution exige un re-portage manuel qui dérive au fil du temps.
- **Un bug critique partagé, jamais corrigé.** Le formulaire entier est une seule `State` ; chaque frappe déclenche un `setState(() {})` vide qui **reconstruit récursivement tout l'arbre** de champs. Faute de `key` stables et de `TextEditingController` stables, la réconciliation des `Element`s échoue → **jank, perte de focus, curseur qui saute**. Le défaut est présent à l'identique dans les trois projets (compteurs de `setState` : DODLP 35, DLCFTI 24, IFFD 18) — même IFFD, pourtant sous Riverpod 3, n'a jamais migré son écran d'édition.
- **Dette technique lourde.** Registres de sérialisation écrits à la main (God-functions de 50 à 80 entrées à éditer pour chaque modèle) ; `reflectable` imposant une initialisation par point d'entrée ; **clé API Google Maps commitée en clair** ; fausses traductions (`class En extends Fr {}`) ; pagination cosmétique buggée ; code mort.
- **Incohérence fonctionnelle entre les copies.** DODLP implémente ~37 types de champs (le catalogue de référence : géo, signature, rating, slider, tags, stepper, fichiers…) quand IFFD n'en rend réellement que ~19 (les types `file`/`image`/`phoneNumber`… tombent en `default` silencieux). Une même fonctionnalité peut exister, être buggée ou avoir disparu selon le projet.

## La solution

Un ensemble de packages Dart/Flutter modulaires, chacun importable indépendamment :

- **`zcrud_core`** — le moteur d'édition et de liste **réécrit** (rebuilds granulaires), le catalogue de champs de référence (repris de DODLP), les contrats de données neutres (`CrudRepository`, `DataRequest`, `DataState`), le champ fichier générique, le stepper, la grille responsive et une l10n générique. Aucun modèle métier, aucun Firebase.
- **`zcrud_annotations` + `zcrud_generator`** — annotations (`@ZcrudModel`, `@ZcrudField`, `@ZcrudId`) et builder `build_runner` générant la (dé)sérialisation, le schéma de formulaire **et** l'enregistrement dans un registre typé.
- **`zcrud_markdown`** — éditeur et lecteur riches (Quill ↔ Delta ↔ Markdown) avec embeds **LaTeX** et **tableaux** (source de référence : IFFD).
- **`zcrud_mindmap`**, **`zcrud_flashcard`** — affichage et édition de cartes mentales et de flashcards (répétition espacée SM-2), exposés comme widgets **paramétrables par l'entité de l'app hôte**.
- **`zcrud_firestore`**, **`zcrud_geo`**, **`zcrud_export`**, **`zcrud_intl`** — adaptateurs et champs spécialisés isolant les dépendances lourdes (cloud_firestore, Google Maps, Syncfusion, téléphonie internationale).

Au cœur du moteur : **un champ = un widget qui n'écoute que sa propre tranche d'état** via une primitive **Flutter native** (`ZFormController`/`ValueListenableBuilder`, aucun gestionnaire d'état dans le cœur), avec `TextEditingController` et `key` stables. Un champ modifié ne reconstruit **que lui-même** — le bug de rafraîchissement disparaît par construction.

## Ce qui le distingue

- **Il règle le bug que personne n'a réglé.** La correction du rebuild de formulaire est l'objectif produit n°1, absent des trois apps sources.
- **Modèle = source unique de vérité.** Les annotations génèrent à la fois la sérialisation et le schéma de formulaire, éliminant toute une classe de bugs de correspondance `name` ↔ propriété (aujourd'hui reliés par des clés `String`).
- **Schéma canonique + extensible.** Les modèles partagés de zcrud sont **dérivés des entités les plus avancées de lex_douane** (module « Étude ») ; chaque application consommatrice **étend** ensuite librement modèles et fonctionnalités (champs, types, comportements) tout en bénéficiant du socle commun — un canonique verrouillé, ouvert à l'extension.
- **Injection & état multi-gestionnaire.** La réactivité du moteur est **Flutter-native** (aucun gestionnaire d'état dans le cœur) ; des bindings minces branchent **Riverpod** (lex_douane / IFFD), **GetX** (DODLP, sans jamais ajouter Riverpod) ou **provider** — un même cœur, plusieurs modes d'injection (dont `ZcrudScope`, sans dépendance).
- **Backend-agnostique.** `cloud_firestore` est isolé dans `zcrud_firestore` ; le contrat `CrudRepository` reste exprimable ailleurs (l'intention multi-backend / Supabase d'IFFD devient tenable).
- **Modularité melos.** Un projet n'importe que ce dont il a besoin : pas de Quill, Syncfusion ou Google Maps imposés à qui n'en veut pas.

## Qui cela sert

- **DODLP — consommateur prioritaire (n°1).** Source la plus riche fonctionnellement et premier banc d'essai. `data_crud` y est importé depuis **180 fichiers** (couplage entrant sain). Objectif : une PR où ne changent que (a) les imports des consommateurs et (b) une fine couche adaptateur — `reflectable`, les repos Firebase et le bootstrap restant inchangés, prouvant la rétro-compatibilité.
- **lex_douane — consommateur n°2 _et_ source du schéma canonique.** Monorepo Melos (Clean Arch : `lex_core`/`lex_data`/`lex_ui` + apps), **stack identique à IFFD** (Riverpod 3, freezed, json_serializable). Son **vrai besoin de remplacement, ce sont les formulaires riches** (~87 écrans « hand-rolled » `TextEditingController` + `setState`). Décision structurante : son module « Étude » — **en développement actif**, portant les modèles flashcards / mindmaps / révision les plus avancés de l'écosystème — fournit les **modèles de référence portés dans zcrud pour verrouiller le schéma canonique** ; chaque application consommatrice (à commencer par DODLP) **étend** ensuite ces modèles à sa guise. L'intégration flashcards/mindmaps dans lex_douane reste **additive** (widgets paramétrés par ses entités), sans remplacer son module.
- **IFFD et DLCFTI** — sources du code ; consommateurs ultérieurs une fois DODLP et lex_douane stabilisés.

## Critères de succès

- **Le bug de rebuild disparaît** : aucune perte de focus ni saut de curseur, aucun `setState` global, un champ modifié ne reconstruit que lui-même — vérifié par test widget + profiling.
- **DODLP tourne sur zcrud** : compile et fonctionne (reflectable + 2 apps Firebase préservés), code dupliqué de `src/` supprimé, 180 imports re-pointés, **parité fonctionnelle** (catalogue de ~37 types de champs).
- **lex_douane édite via zcrud** : au moins 3 écrans d'édition riche (`lex_douane_admin`) migrés vers zcrud sans régression de résolution de dépendances.
- **Markdown fiable** : round-trip Delta ↔ Markdown testé (listes imbriquées, formules multi-lignes, tableaux, entités HTML).
- **Hygiène** : zéro `reflectable` dans le moteur, modèles 100 % codegen, **zéro secret commité**.
- **Modularité prouvée** : un nouveau projet importe un sous-package isolé (ex. `zcrud_markdown`) **sans** tirer Firebase / Syncfusion / Google Maps.

## Périmètre

**Dans la V1 :**
- `zcrud_core` : moteur d'édition (rebuilds granulaires, catalogue de référence), moteur liste/table, contrats de données neutres, champ fichier, stepper, responsive, l10n générique.
- `zcrud_annotations` + `zcrud_generator` : codegen sérialisation + schéma + registre.
- `zcrud_markdown` : éditeur/lecteur riche + embeds LaTeX + tableaux (source IFFD).
- `zcrud_firestore` : adaptateur Firestore débogué (bugs `limit`, batch, `catch(_){}`, pagination curseur).
- **Intégration DODLP** (banc d'essai) et **formulaires riches de `lex_douane_admin`**.

**Séquencé après la V1 (inclus, mais plus tard) :** `zcrud_mindmap`, `zcrud_flashcard` (adaptateurs lex_douane), `zcrud_geo`, `zcrud_export`, `zcrud_intl`.

**Explicitement hors périmètre (V1) :**
- Implémentation multi-backend réelle (Supabase) — le contrat reste exprimable, sans implémentation.
- Mode *flowchart* des mindmaps (décision : `zcrud_flowchart` séparé ou abandon).
- `flutter_tex` / `html_editor_enhanced` — rendus optionnels ou différés (WebView / CDN fragiles).
- Toute refonte du module « Étudier » de lex_douane — on s'y **adapte**, on ne le remplace pas.

## Vision

À 2–3 ans, zcrud est **la fondation CRUD commune de tout l'écosystème** (douane / ERP) : un modèle annoté suffit à obtenir liste, formulaire riche, sérialisation, export et champs spécialisés, sur n'importe quel backend. Les nouvelles applications démarrent en important quelques packages ; une correction se fait une fois et profite à toutes. Le monorepo est publiable (registre privé ou pub.dev), avec une suite de tests de round-trip garantissant la non-régression à chaque extraction.

---

## Décisions verrouillées (session d'initialisation)

- **Sources d'extraction** : les 3 modules `data_crud` — IFFD, DODLP, DLCFTI.
- **Gestion d'état** : réactivité **Flutter-native** (`ChangeNotifier`/`ValueListenable`) dans le cœur, **rebuilds granulaires** ; support **multi-gestionnaire** via bindings optionnels (Riverpod, GetX, provider) — le cœur n'impose aucun manager.
- **Sérialisation** : **génération de code** (annotations zcrud) ; **`freezed` non imposé** ; `reflectable` banni (sauf adaptateur `ReflectableCodec` pour DODLP).
- **Monorepo** : melos.
- **Ordre des consommateurs** : DODLP (n°1), puis lex_douane (n°2).
- **Catalogue de champs de référence** : celui de DODLP (~37 types).
- **Schéma canonique** : porté des modèles les plus avancés de lex_douane (module « Étude », en développement actif) ; il verrouille le socle partagé de zcrud.
- **Extensibilité de premier ordre** : chaque application consommatrice peut étendre modèles et fonctionnalités tout en profitant du socle partagé (exigence architecturale non négociable).

## Questions ouvertes à trancher en phase Architecture

Détaillées dans `docs/technical-inventory.md` (§9). Les plus structurantes :
1. **Format canonique du rich-text** : Delta JSON (source de vérité) vs Markdown pur (aujourd'hui incohérent — un champ `markdown` persiste en réalité du Delta JSON).
2. **Mécanisme d'extension** : comment une app consommatrice étend un modèle canonique zcrud (composition, `sealed`/sous-classes, mixins, champs additionnels via registre) en conservant la (dé)sérialisation et le schéma de formulaire générés — et en restant compatible avec les entités `@JsonSerializable` de lex_douane, source du canonique ?
3. **Mécanisme d'injection unique** satisfaisant Riverpod (lex_douane/IFFD) *et* locator/`InheritedWidget` (DODLP).
4. **Constantes lourdes** (mccmnc 843 Ko, pays 1,1 Mo) : assets JSON paresseux vs package de données séparé.
5. **Rendu liste vs édition** : dériver `DynamicListField` du même type que `DynamicFormField` ou garder disjoints.
6. **Licence Syncfusion** (`zcrud_export`, DataGrid) : acter la contrainte ou prévoir un backend Material alternatif.

> Sécurité — action immédiate recommandée hors périmètre produit : la **clé API Google Maps est commitée en clair** dans DODLP et DLCFTI (`google_maps.dart`). À révoquer / restreindre et sortir vers la config plateforme lors de l'extraction de `zcrud_geo`.
