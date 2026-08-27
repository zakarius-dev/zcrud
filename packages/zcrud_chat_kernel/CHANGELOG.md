# Changelog

Toutes les modifications notables de `zcrud_chat_kernel` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.24.0 — 2026-08-27

### Ajouté
- **Vocabulaire de contexte du composer** : candidat, déclencheur et source de **mention** ; **commande** et son catalogue ; **port de mesure de texte** ; **port de brouillon** (implémentations inerte et en mémoire).
- Le drapeau de teinte permanente sur la **déclaration** d'artefact, relayé jusqu'à sa spec.

### Attention
- 🔴 **Le socle transporte, il ne résout pas.** Il n'exécute aucune commande, ne résout aucun candidat, ne filtre ni ne trie — filtrer, c'est résoudre. Un plafond de candidats est **transporté, jamais appliqué**.
- **Compter des jetons dépend du tokenizer** : le socle ne compte pas, il **demande** au port. Sans port, la mesure est absente — jamais zéro, qui serait pris pour une mesure.

## 3.10.0 — 2026-08-23

### Ajouté
- `ZChatRouteCatalogShape.taskAliases` (constructeur général et `suffixPairs`) : les noms de tâche lus dans un document — préfixe d'une paire à suffixe, ou clé d'objet d'une route nommée — sont traduits **après** extraction, par une table fournie par l'hôte. Sans alias, le nom lu est la clé. Deux noms traduits vers la même clé : la dernière déclaration gagne ; un alias vers une clé vide écarte la route sans exception.

## 3.9.0 — 2026-08-23

### Ajouté
- `ZChatArtifactGenerationRequest.providerId` (opaque) ; `ZChatGenerationRequest.copyWith` — `withSettings`, `withCorpusScope` et `ZChatRouteResolution.toRequest` en sont des appelants (un seul site de recopie).

### Changé
- Précédence de l'effort dans `ZChatRouteResolution.toRequest` : sans réglages, `base.computeEffort ?? route ?? racine` — la route ne recouvre plus un budget explicite ; avec réglages, la feuille reste un remplacement.
- Les **replis** d'une route et de la racine sont déclarés en `subItems` imbriqué (`$ZChatModelRefFieldSpecs`) à la place de jetons, et émis sur le fil en **liste de maps** `{provider_id, model_id}` ; la lecture reste tolérante (maps, `"p:m"`, chaînes nues).

## 3.8.0 — 2026-08-23

### Ajouté
- **Catalogue de routeurs IA** (`domain/route/`) : `ZChatRouter` — entité `ZEntity` extensible écrite à la main (routes par tâche, modèle et replis racine, `tier` opaque, `computeEffort`, `params`, `extension`, `extra` filtré) avec **`$ZChatRouterFieldSpecs`** et **`registerZChatRouter(registry)`** : le formulaire et la liste d'administration viennent de l'éditeur zcrud sans code hôte (`routes` en `subItems`, replis en jetons `provider:model`). `ZChatRouteSpec` (par tâche : route, fournisseur, modèle, replis, effort, paramètres, jetons d'accès, handler). **`ZChatModelRef {providerId?, modelId}`** partout où un modèle est nommé — le fournisseur voyage par tâche et par repli, jamais interprété.
- **`ZChatRouteResolution.from(router, taskKey)`** : repli tâche → racine, le couple (modèle, replis) replie ensemble ; `toRequest(base, {settings})` applique la route sans jamais l'emporter sur un choix explicite de l'appelant.
- Ports : `ZChatRouteCatalogPort` (`resolveRouter`, `listRouters`, `invalidate`) + `ZChatInertRouteCatalog` + `ZChatInMemoryRouteCatalog` ; **`ZChatRouteGate`** + **`ZDenyAllChatRouteGate` par défaut** + `ZAllowAllChatRouteGate` ; `ZChatRouteHandlers` (`streamPortFor`, `generationPortFor`) + `Inert` + `Map`.
- **Catalogue composable** (`domain/route/catalog/`) : sources (`ZChatStaticRouteCatalogSource`, `ZChatRepositoryRouteCatalogSource` sur tout `ZReadOnlyRepository<ZChatRouter>`, `ZChatRemoteRouteCatalogSource` HTTP-agnostique — l'hôte ouvre, le socle décode), décodeur défensif `ZChatRouteCatalogDecoder` + formes `ZChatRouteCatalogShape` (`canonical`, `lex`, `suffixPairs` à clés d'hôte ; un routeur corrompu est compté, jamais la liste perdue), cache `ZChatTtlRouteCatalog` (TTL, cache négatif, service périmé sur panne distante, invalidation ciblée), `ZChatCascadeRouteCatalog` (repli **déclaré** par l'hôte seulement, sinon `Left(ZNotFoundFailure)`), `ZChatInMemoryRouterRepository`, `ZChatInvalidatingRouterRepository`.
- `ZChatGenerationRequest.providerId` (opaque, additif) ; `ZChatFailureCodes.upgradeRequired` (`UPGRADE_REQUIRED` absorbé à l'entrée).

### Garde
- Un alias d'effort d'une forme de catalogue ne peut viser que `tier` (contre-preuve : toute autre cible rougit) ; la règle « aucun symbole `*Effort*` hors `computeEffort` » est inchangée.

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
