---
title: zcrud — CRUD riche, déclaratif et modulaire pour Flutter
description: Un schéma de champs unique génère formulaires et listes, avec rebuilds granulaires, offline-first et champs riches.
sidebar_position: 1
---

# zcrud

**zcrud** est un écosystème de 39 paquets Flutter qui transforme un **schéma déclaratif de
champs** (`ZFieldSpec`) en applications CRUD complètes : formulaires d'édition, tableaux de
liste, export PDF/Excel, synchronisation offline-first — avec des champs riches (Markdown,
géo, téléphone, sous-listes, flashcards, mindmaps, chat).

## Pourquoi zcrud

- **Un schéma, deux surfaces.** Annotez votre modèle (`@ZcrudModel`) : la sérialisation,
  le `ZFieldSpec[]` et l'enregistrement au registre sont générés. Le formulaire
  (`DynamicEdition`) et la liste (`DynamicList`) en découlent — zéro duplication.
- **Des rebuilds granulaires, mesurés.** Taper 100 caractères ne reconstruit que le champ
  courant ; pas de perte de focus, pas de jank. C'est l'objectif produit n°1, vérifié par
  test ([invariant AD-2](concepts/invariants.md#ad-2)).
- **Aucun gestionnaire d'état imposé.** Le cœur est Flutter-natif ; Riverpod, GetX et
  provider ont chacun leur paquet de binding ([AD-15](concepts/invariants.md#ad-15)).
- **Offline-first par contrat.** Store local source de vérité, sync différée,
  Last-Write-Wins, soft-delete ([AD-9](concepts/invariants.md#ad-9)).
- **Modulaire par construction.** Le graphe de dépendances est acyclique et vérifié :
  vous n'embarquez que ce que vous importez ([AD-1](concepts/invariants.md#ad-1)).

## Par où commencer

| Vous voulez… | Allez à |
|---|---|
| Monter un premier écran CRUD | [Démarrage rapide](demarrage-rapide.md) |
| Comprendre le schéma de champs | [Concept : ZFieldSpec](concepts/zfieldspec.md) |
| Comprendre le découpage en paquets | [Concept : architecture hexagonale](concepts/architecture-hexagonale.md) |
| Consommer le monorepo en dépendance git | [Recette de consommation](https://github.com/zakarius-dev/zcrud/blob/main/docs/private-git-consumption.md) |
| La fiche d'un paquet précis | [Catalogue des paquets](paquets/index.md) |
| Les règles qui bornent tout le code | [Invariants AD-1…AD-16](concepts/invariants.md) |

## L'écosystème en un coup d'œil

```
                    zcrud_annotations ── zcrud_generator (build_runner)
                                │
                          zcrud_core  ← schéma, moteur d'édition, ports, thème, l10n
        ┌──────────┬──────────┼──────────────┬─────────────┐
   bindings     liste      rich-text      champs        étude & chat
 riverpod/get/  zcrud_list zcrud_markdown zcrud_geo     zcrud_study/…
 provider       (Syncfusion) zcrud_html   zcrud_intl    zcrud_chat/…
        │                                 zcrud_media
   zcrud_firestore (offline-first)        zcrud_select
```

Chaque paquet expose son API par un barrel unique (`lib/<pkg>.dart`) ; l'implémentation
vit sous `lib/src/` et n'est pas un contrat.

## Documentation

- [Concepts](concepts/invariants.md) — les modèles mentaux : schéma, couches, réactivité,
  offline, invariants.
- [Guides](guides/index.md) — migration depuis un moteur legacy, recettes (cookbook).
- [Catalogue des paquets](paquets/index.md) — une fiche par paquet : rôle, quand l'utiliser,
  liens.
- [Charte documentaire](charte.md) — comment cette documentation est écrite et vérifiée.
