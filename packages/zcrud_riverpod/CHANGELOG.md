# Changelog

All notable changes to `zcrud_riverpod` are documented in this file.

## 3.1.0 — 2026-08-18

### Modifié — le binding COMPLÈTE le scope ambiant au lieu de le masquer

Le binding construisait un `ZcrudScope` **à neuf**, avec le résolveur et l'ACL
seuls. Or le constructeur **n'hérite pas** de l'ambiant : un scope imbriqué
**masque** son parent. Un hôte qui posait son propre `ZcrudScope` — thème,
registres, canaux de rendu déclaratif — **au-dessus** du binding perdait donc
**21 seams sur 23**, en silence, sous ce binding.

Le binding **dérive** désormais du scope ambiant : ce qu'il déclare (résolveur,
ACL) prime, **tout le reste est hérité**.

**Sans scope ambiant, rien ne change** — le cas le plus courant est gardé par un
contre-témoin, repli d'ACL compris. Le cycle de vie du contrôleur est intact.

## 0.1.0

Initial public release.

- The optional Riverpod state and injection binding for zcrud (targets the lex_douane / IFFD host apps).
- Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo (14 packages, one declarative CRUD engine).
- Published under the MIT license.
