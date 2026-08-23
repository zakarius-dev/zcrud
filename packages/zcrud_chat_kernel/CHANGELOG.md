# Changelog

Toutes les modifications notables de `zcrud_chat_kernel` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.6.0 — 2026-08-23

### Ajouté
- **Vocabulaire déclaratif de la feuille d'outils** (`domain/tools/`) : `ZChatToolEntry` (bascule, cycle 0..N, choix, échelle à repères, catalogue filtrable, action ponctuelle ; proéminence `auto`/bande/feuille ; révélation conditionnelle ; règles d'exclusion et de désactivation **avec raison** ; `iconKey` et `itemLabels` opaques), `ZChatToolSection`, `ZChatToolCatalog` immuable (`setState`/`advance`/`reset` en `Either`) et `resolve()` — visibilité, grisage, ordre, comptage, liste des actifs et recherche calculés **une fois**, pour les deux surfaces.
- **Ports du Notebook** (`domain/notebook/`) : `ZChatArtifactRegistry`/`ZChatArtifactDeclaration` (artefacts et verbes déclarés par jetons, `subjectRequired`, `style`), `ZChatArtifactStatus.resolve` (occupation > existence), `ZChatArtifactStatePort`, `ZChatArtifactGenerationPort` + `zChatRunArtifactGeneration` (refus sur vide → marquer → générer → écrire si non vide → **démarquer dans un `finally`**, échecs typés jamais avalés), `ZChatArtifactStorePort` (`delete` atomique, anti-résurrection, toutes représentations), `ZChatTranscriptPort` lecture **et** écriture + `zChatTranscriptOrEmpty` (erreur ⇒ fil vierge), `ZChatUnsupportedActionExecutor`, `ZChatDraftRequestBuilder` (copie `attachmentIds`), `ZChatSequentialRequestIds`, `zChatConfirmWithoutDialog`.
- **Transport SSE** (`data/sse/`) : `zChatSseLines` (octets → lignes, `data:` retiré une fois, lignes vides conservées, `id:` ⇒ reprise, `[DONE]`, annulation par jeton **immédiate**) et `ZChatSseStreamPort` (l'hôte fournit l'ouverture authentifiée et le décodeur de ligne ; le socle ne connaît ni URL, ni auth, ni JSON). Aucune dépendance HTTP.
- `copyWith` sur `ZChatArtifactGenerationRequest`.

### Corrigé
- `zChatTranscriptOrEmpty` propageait l'annulation avec un événement de retard : l'écouteur distant survivait au `dispose`. Désabonnement immédiat.
- Trois octets NUL bruts dans des littéraux Dart remplacés par `\u0000` (un `grep` sans `-a` voyait un binaire).
- Les trois types à `extra` concret (`ZChatArtifactDeclaration`, `ZChatArtifactGenerationRequest`, `ZChatToolEntry`) filtrent désormais les clés réservées de synchronisation et leurs clés propres (`_reservedKeys` ∋ `ZSyncMeta.reservedKeys`, AD-19.1) — une clé `updated_at` glissée dans `extra` n'est plus réémise.
- Les gardes de source du Notebook déclarent `@TestOn('vm')` (elles lisent le disque ; la gate web les compilait vers Node).

## 3.3.1 — 2026-08-21

### Corrigé — un faux VERT refermé dans la garde de contrat des verbes

Le test « aucun verbe mort » cherchait un appel dans la source du répartiteur
sans distinguer un **appel** d'une **déclaration de constructeur nommé**. Un
constructeur homonyme d'un verbe suffisait donc à le faire passer pour routé
alors qu'il aurait été mort — sans que rien ne le signale.

C'est le même angle mort que celui corrigé sur le test jumeau, mais **en sens
inverse** : là un faux rouge, bruyant donc corrigible ; ici un faux vert,
silencieux.

Ce scénario avait été jugé **inatteignable**. Mesure faite : c'est faux — la
garde censée l'interdire exige un blanc devant le nom du membre, or un
constructeur nommé y porte un point. Les trois formes lui échappaient. La dette
était donc un défaut réel, pas un durcissement de précaution.

L'exclusion a désormais une **définition unique**, partagée par les deux sens de
la garde. Un aiguillage réel reste compté, un verbe non routé reste signalé.
Test seul — aucun changement de code de production.

## 3.2.0 — 2026-08-21

### Corrigé — une garde de contrat attrapait une déclaration pour un appel

La garde « un verbe = un seul site d'appel » cherchait le nom d'un membre d'effet
**partout**, et attrapait donc un **constructeur nommé** homonyme — une
déclaration, jamais une invocation.

**La propriété protégée est inchangée** ; seul le proxy qui la mesure a été
resserré, par une exclusion exigeant les trois traits simultanés d'une
déclaration : début de ligne, récepteur commençant par une **majuscule**, et
parenthèse immédiate. La position seule ne distingue rien — un appel réel peut
aussi commencer une ligne.

Prouvé dans les deux sens : trois formes d'appel injectées la font rougir, et le
constructeur nommé ne la fait plus rougir. Perte de couverture assumée et écrite
dans la garde : un appel **statique** en tête de ligne échapperait — impossible
ici, les huit membres d'effet étant des membres d'instance.

## [0.85.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu, patron
  kernel/satellite, installation, démarrage rapide, API principale, cas
  limites et invariants.
- Fiche `docs/site/paquets/zcrud_chat_kernel.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, exemples compilables sur les entités
  principales, invariants d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Aucun changement de code — la revue
  ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_chat_kernel/`.
