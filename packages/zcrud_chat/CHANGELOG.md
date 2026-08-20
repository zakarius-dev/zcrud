# Changelog

Toutes les modifications notables de `zcrud_chat` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.0.0 — 2026-08-18

### Ajouté — un créneau d'action par groupe de conversations

`ZChatConversationList` groupe les conversations par contenant, mais n'offrait
aucun endroit où poser une action **à l'échelle du groupe**. Le bouton « créer
dans CE dossier » était donc perdu au portage : restait le bouton global, qui ne
présélectionne rien — l'utilisateur devait rattacher après coup, ou découvrir sa
conversation au mauvais endroit.

`groupActionsBuilder` reçoit le **groupe exact** et rend des actions déclarées
par l'hôte. **Le socle ne fabrique aucune action** : la création — quel dossier,
quel titre, quelle persistance — reste métier, comme l'hôte le demandait.

Défaut : **aucune action**, rendu identique au pixel (contre-témoin à comptes
absolus). Un constructeur qui **lève** laisse la liste intacte (AD-10), sans
action de repli. Cible ≥ 48 dp, sémantique de bouton, activation au clavier.

**Non livré, délibérément** : le repli en accordéon, l'icône de groupe colorée et
la troncature du titre — l'hôte les qualifie de cosmétiques et ne les demande pas.

## [0.85.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu, patron
  kernel/satellite, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_chat.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, exemples compilables sur les entités
  principales, invariants d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Purge des références de story et
  d'epic, des emoji de journal et des historiques de correctifs — conservation
  des invariants, cas limites et avertissements de contrat. Aucun changement
  de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_chat/`.
