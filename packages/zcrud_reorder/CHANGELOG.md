# Changelog

Toutes les modifications notables de `zcrud_reorder` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.19.0 — 2026-08-24

### Modifié
- **Le contrat de poignée n'est pas honoré, et c'est mesuré.** Le châssis tiers n'expose aucun déclencheur par poignée : son écouteur, posé autour de la cellule entière, réinstalle son propre reconnaisseur après tout déclencheur externe. La seule configuration qui fonctionnerait exige de désactiver le glissement de l'item — donc de **confisquer** son geste, ce que le contrat interdit. Le défaut identité est conservé : la poignée reste une **affordance visible**, le glissement s'amorce par l'appui long, et la voie non gestuelle reste offerte. Pour une poignée qui amorce le geste, utiliser le renderer par défaut de `zcrud_responsive`.

### Garde
- **Tripwire d'héritage du défaut** : il rougira le jour où le châssis tiers exposera un déclencheur par poignée, ou le jour où quelqu'un croira l'avoir honoré sans l'avoir prouvé.
- **Tripwire sur la feuille de l'aperçu** : le châssis tiers habille lui-même son aperçu d'un `Material`. Le point d'extension public qui aurait permis de relayer l'habillage de l'appelant **remplace** ce proxy au lieu de l'envelopper — le relayer aurait retiré cette feuille chez tous les hôtes. Rien n'est relayé ; la garde fige la propriété dont ce choix dépend.

## 3.3.1 — 2026-08-21

### Corrigé — des libellés de repli annoncés « localisés » ne le sont pas

Les deux libellés de repli des actions de réordonnancement sont des constantes
**en français**, non traduites. Leur dartdoc les disait localisées.

Elle dit désormais ce qu'ils sont, et avertit qu'une application multilingue doit
fournir les siens.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas limites
  et invariants.
- Fiche `docs/site/paquets/zcrud_reorder.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : purge des références internes de décision d'architecture non
  canoniques et des emoji de journal, conservation des invariants citables
  (`AD-2`, `AD-10`, `AD-13`). Aucun changement de code — la revue ne porte que
  sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_reorder/`.
