# Changelog

Format « Keep a Changelog » (sections Ajouté / Modifié / Corrigé, versions
antéchronologiques). Toutes les modifications notables de `zcrud_ui_kit`
sont documentées ici.

## 0.93.0 — 2026-08-13

### Ajouté

- **`ZCountBadge`** — pastille de comptage réutilisable : seule, ou posée sur un
  contenu (icône de barre, avatar). Le nombre est **annoncé**
  (`semanticsLabel` nomme ce qui est compté), la cible tactile passe à **48 dp**
  dès que la pastille est cliquable, le placement est **directionnel**
  (bascule en RTL) et toutes les couleurs sont dérivées du `ColorScheme` —
  aucune valeur littérale. Zéro n'affiche rien (`showZero` pour l'imposer), et
  les grands nombres sont écrêtés à l'affichage (`99+`) sans altérer l'annonce.

### Modifié

- Chantier documentation : README réécrit au gabarit du monorepo, dartdoc de
  l'API publique normalisée (orientée consommateur), fiche `docs/site/paquets/`
  ajoutée, `public_member_api_docs` activé.

Historique antérieur : voir `git log` sur `packages/zcrud_ui_kit/`.
