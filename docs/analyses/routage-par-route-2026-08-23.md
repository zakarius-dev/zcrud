# Transport par route — relevé IFFD et contrat du catalogue de routes (2026-08-23)

> Workflow de 12 agents (3 lecteurs, 2 tours de critique, 6 suivis, 1 contrat). Décision d'owner : le mode par route est de première classe au socle. Seul ce document est durable.

## A. Le contrat

Rédigé à partir de : `routeur-entite/rapport.md`, `consommateurs/rapport.md`,
`serveur-gouvernance/rapport.md`, `suivi-1-{1,2,3}/rapport.md`, `suivi-2-{1,2,3}/rapport.md`,
`docs/analyses/backends-lex-iffd-2026-08-23.md`, et lecture directe de
`packages/zcrud_chat_kernel/lib/src/domain/ai/{z_chat_generation_port,z_chat_generation_style,
z_chat_ai_failure}.dart`, `.../domain/tools/z_chat_tool_catalog.dart`,
`packages/zcrud_core/lib/src/domain/ports/{z_acl,z_syncable_repository,z_local_store}.dart`.

Rien n'est proposé qui contredise un invariant déjà écrit dans ces fichiers — chaque proposition
cite la clause qu'elle respecte ou le grep négatif qui montre le vide qu'elle comble.

---

## 0. Contraintes déjà tranchées par les lectures amont (à ne pas rouvrir)

1. **Aucun champ « route »/« endpoint » sur `ZChatGenerationRequest`** — `z_chat_generation_port.dart:60`
   l'exclut littéralement (AD-12 : « ni endpoint, ni clé, ni instruction système assemblée »).
   (suivi-1-1 §1)
2. **Aucune interprétation de catalogue dans le port** — `modelId` doc (`:185-191`) : « aucun
   catalogue, aucun `switch` ». Le port reste un simple transporteur d'une requête déjà résolue.
   (suivi-1-1 §1)
3. **La résolution est une couche PURE, EN AMONT**, du même gabarit que
   `ZChatToolCatalog.resolve()` (donnée déclarée + contexte d'appel → état dérivé immuable, jamais
   consommée depuis un port). (suivi-1-1 §3, suivi-2-2)
4. **`style.kind` est déjà la clé de tâche ouverte** (`ZChatGenerationRequest.style`, obligatoire) —
   pas de second champ `taskKey` redondant : le vocabulaire IFFD (`explanation/chat/mindmap/
   flashcards/summary/elaboration/examples/poem/history/humor/chatStyle/thinking`) *est* l'espace
   des `kind` possibles, ouvert par construction (AD-4). (suivi-1-1 §2)
5. **Ni `ZAcl` ni `ZSyncableRepository`/`ZLocalStore` ne conviennent** pour porter respectivement la
   gouvernance de plan et la résolution catalogue — les deux tranches (suivi-2-1, suivi-2-3)
   établissent qu'il faut des ports **dédiés**, plus petits, taillés sur la forme réelle du besoin.
6. **`ZChatProviderFailure(message, code:)` couvre déjà structurellement `UPGRADE_REQUIRED`**
   (suivi-1-2 conclusion tranchée par suivi-2-1 : « rien à ajouter côté type ») — pas de nouvelle
   famille `ZFailure` à créer pour le motif du refus.
7. **`ZChatSseStreamPort`/`ZIffdTextStreamPort` n'ont aucun endpoint en dur** : `open`/`decode` sont
   des dépendances injectées à la construction (suivi-1-3). La substitution « route par tâche » est
   donc déjà possible **sans toucher aux ports abstraits** — c'est confirmé, pas à concevoir.

---

## 1. LE CATALOGUE

### 1.1 `ZChatRouteSpec` — une route, pour une tâche

```dart
/// Une route de génération pour une clé de tâche ouverte (invariant AD-4).
///
/// [taskKey] recouvre le même espace que [ZChatGenerationStyle.kind] — ce
/// N'EST PAS un second axe : un hôte qui déclare une route pour `'poem'`
/// répond à des requêtes dont `style.kind == 'poem'`. Aucune valeur de
/// [taskKey] n'est connue du socle (AD-12) : le catalogue IFFD porte 12 clés
/// fixes, un autre hôte peut en porter 3 ou 40, additivement.
class ZChatRouteSpec {
  const ZChatRouteSpec({
    required this.taskKey,
    required this.routeName,
    required this.defaultModelId,
    this.fallbackModelIds = const <String>[],
    this.effort,
    this.defaultParams = const <String, dynamic>{},
    this.requiredAccessTokens = const <String>{},
    this.resultHandlerId,
  });

  /// Clé de tâche ouverte (`'explanation'`, `'flashcards'`, `'poem'`…),
  /// même vocabulaire que [ZChatGenerationStyle.kind] — jamais un second
  /// espace de noms concurrent.
  final String taskKey;

  /// Nom de route **opaque**, transporté verbatim jusqu'à l'implémentation
  /// de port de l'hôte (ex. `'generate_subject_flashcards'` côté IFFD,
  /// ou vide côté Lex qui n'a qu'une seule route HTTP). Jamais interprété
  /// par le socle — même contrat que [ZChatGenerationRequest.modelId].
  final String routeName;

  /// Identifiant de modèle par défaut pour cette tâche — opaque, verbatim
  /// (même contrat que `ZChatGenerationRequest.modelId`).
  final String defaultModelId;

  /// Chaîne de repli **ordonnée**, opaque, jamais interprétée ici — voir
  /// §2 pour qui la parcourt.
  final List<String> fallbackModelIds;

  /// Effort par défaut de cette route, ou `null` (l'appelant/le réglage
  /// utilisateur décide alors).
  final ZChatComputeEffort? effort;

  /// Paramètres par défaut de la tâche (ex. `questionsCounts` IFFD) —
  /// échappatoire non typée, même statut que `ZChatGenerationRequest.extra`.
  final Map<String, dynamic> defaultParams;

  /// Jetons **opaques** de plan/accès requis pour emprunter cette route
  /// (ex. `'plan:pro'`, `'role:AiRouterfree'`) — jamais interprétés par le
  /// socle : un hôte les compare aux jetons que porte son utilisateur via
  /// [ZChatRouteGate] (§3). Vide = aucune restriction déclarée ici (la
  /// restriction peut encore venir du gate lui-même, hors catalogue).
  final Set<String> requiredAccessTokens;

  /// Identifiant **opaque** d'un gestionnaire de résultat, ou `null`.
  ///
  /// **Jamais une closure stockée sur ce type** — un `ZChatRouteSpec`
  /// est une donnée sérialisable (Firestore aujourd'hui, backend demain,
  /// AD-10 défensif) ; une `Function` ne survit à aucune des deux formes.
  /// Le port réel (`onComplete`/`ZChatStreamPort` dédié…) est résolu par
  /// l'hôte à partir de cet identifiant, au même patron que
  /// `ZTypeRegistry`/`ZSourceRegistry` résolvent un `kind` vers un codec
  /// (AD-4) — voir §1.4.
  final String? resultHandlerId;
}
```

Justification de chaque champ contre la matrice mesurée (`routeur-entite/rapport.md` §1, colonne
`Champs`) : `taskKey`↔les 12 paires `<tâche>Model`, `routeName`↔l'endpoint choisi
(`explanationModel ?? "explain"`), `defaultModelId`↔`aiModel`/`<tâche>Model`,
`fallbackModelIds`↔`aiFallbackModels`/`<tâche>FallbackModels`, `effort`↔`workflowEffort` (par
route, pas par routeur entier — IFFD n'a qu'un `workflowEffort` par *routeur*, mais rien n'empêche
un hôte plus fin de le porter par tâche ; le champ reste optionnel exprès), `defaultParams`↔
`questionsCounts`, `requiredAccessTokens`↔le rôle `"AiRouter<id>"` généralisé, `resultHandlerId`↔
le point named `onComplete` unique côté IFFD (`consommateurs/rapport.md` §2.5) — mais résolu, pas
sérialisé.

### 1.2 `ZChatRouterSpec` — un ensemble de routes + identité + palier

```dart
/// Un routeur : un ensemble de [ZChatRouteSpec] indexées par [ZChatRouteSpec.taskKey],
/// une identité opaque et un palier.
class ZChatRouterSpec {
  ZChatRouterSpec({
    required this.id,
    required Iterable<ZChatRouteSpec> routes,
    this.tier,
    this.defaultModelId,
    this.defaultFallbackModelIds = const <String>[],
  }) : routes = <String, ZChatRouteSpec>{
          for (final ZChatRouteSpec r in routes) r.taskKey: r,
        };

  /// Identifiant du routeur (`'free'`, `'pro'`…) — opaque, jamais un
  /// libellé (FR-26 : le nom d'affichage vit côté hôte, pas ici).
  final String id;

  /// Routes déclarées, une par [ZChatRouteSpec.taskKey] — dédupliquées par
  /// clé, dernière déclaration gagnante (cohérent avec le repli
  /// `modelOrDefault` d'IFFD : chaque tâche a TOUJOURS une route résolue
  /// dès lors que [defaultModelId] est renseigné).
  final Map<String, ZChatRouteSpec> routes;

  /// Palier **opaque** du routeur (`'low'`/`'medium'`/`'high'` côté IFFD,
  /// autre chose côté un futur hôte) — jamais interprété par le socle,
  /// sert au tri d'affichage et à la comparaison d'ordre côté [ZChatRouteGate].
  final String? tier;

  /// Modèle par défaut du ROUTEUR entier — repli final si une tâche n'a
  /// pas de [ZChatRouteSpec] déclarée (même rôle qu'`aiModel` racine
  /// d'`IffdAiRouterModel`, `routeur-entite/rapport.md:14-16`).
  final String? defaultModelId;

  /// Repli du modèle par défaut du routeur lui-même.
  final List<String> defaultFallbackModelIds;

  /// La route pour [taskKey], ou une route **synthétique** repliée sur
  /// [defaultModelId]/[defaultFallbackModelIds] si [taskKey] n'a pas de
  /// route dédiée — jamais `null` tant que [defaultModelId] est renseigné.
  /// Reproduit `modelOrDefault` (`routeur-entite/rapport.md:24-25`) sans
  /// dupliquer le calcul à chaque site d'appel (le défaut que
  /// `consommateurs/rapport.md` §2.1 qualifie de « deux résolutions
  /// indépendantes, non nommées comme telles »).
  ZChatRouteSpec? route(String taskKey) {
    final ZChatRouteSpec? declared = routes[taskKey];
    if (declared != null) return declared;
    final String? fallback = defaultModelId;
    if (fallback == null) return null;
    return ZChatRouteSpec(
      taskKey: taskKey,
      routeName: taskKey,
      defaultModelId: fallback,
      fallbackModelIds: defaultFallbackModelIds,
    );
  }
}
```

### 1.3 `ZChatRouteCatalogPort` — source du catalogue

```dart
/// Port de résolution du catalogue de routage — source du jour : Firestore
/// (hôte) ; source de demain : un backend dédié (patron `AiRouterService`,
/// `serveur-gouvernance/rapport.md` §5.2). Le socle ne connaît AUCUNE des
/// deux implémentations (AD-16) : seul le contrat.
///
/// Résolution **par clé** (id de routeur), jamais par flux d'entités — la
/// forme est « cache local (TTL, best-effort) → distant → repli figé »,
/// PAS une synchronisation bidirectionnelle : voir `suivi-2-3/rapport.md`
/// pour la justification du rejet de `ZSyncableRepository`/`ZLocalStore`.
/// [ZChatRouterSpec] n'a pas d'écriture locale à faire remonter — le
/// catalogue est backend-autoritaire à sens unique côté client (comme
/// `AiRouterService`, jamais muté par l'app).
abstract interface class ZChatRouteCatalogPort {
  /// Résout le routeur [routerId]. `Left` réservé aux pannes réelles
  /// (cache local corrompu…) — jamais pour « pas trouvé » : un routeur
  /// absent retombe sur l'implémentation (repli figé, jamais un échec —
  /// même contrat que `get_default_router` côté Lex, `suivi-2-3` §1).
  Future<ZResult<ZChatRouterSpec>> resolveRouter(String routerId);

  /// Invalide le cache local pour [routerId], ou tout le cache si `null` —
  /// symétrique de `invalidate_cache` (`serveur-gouvernance/rapport.md:116`).
  /// Best-effort : une implémentation sans cache local peut l'ignorer.
  Future<void> invalidate([String? routerId]);
}

/// Catalogue par défaut **inerte** — repli du socle quand aucune
/// implémentation n'est déclarée par l'hôte, même posture que
/// [ZDenyAllAcl] : ne résout jamais silencieusement un routeur inconnu
/// par un modèle arbitraire (AD-16, AD-10 : pas de valeur fabriquée).
class ZChatInertRouteCatalog implements ZChatRouteCatalogPort {
  const ZChatInertRouteCatalog();

  @override
  Future<ZResult<ZChatRouterSpec>> resolveRouter(String routerId) async =>
      Left(ZUnsupportedOperationFailure(
        'Aucun ZChatRouteCatalogPort déclaré pour résoudre "$routerId".',
      ));

  @override
  Future<void> invalidate([String? routerId]) async {}
}
```

### 1.4 Callbacks — un registre, pas une closure sur la donnée

`resultHandlerId` (§1.1) est un identifiant opaque. Le port réel (typiquement un
`ZChatGenerationPort`/`ZChatStreamPort` dédié, ou un simple `void Function(ZChatStreamEvent)`
typé côté hôte) vit dans un registre tenu par l'hôte :

```dart
/// Registre hôte, JAMAIS dans zcrud_core/zcrud_chat_kernel : résout un
/// [ZChatRouteSpec.resultHandlerId] vers le port réel. Même patron que
/// `ZTypeRegistry`/`ZSourceRegistry` (AD-4) : une Map tenue par l'app,
/// jamais sérialisée, jamais transportée par la donnée du catalogue.
abstract interface class ZChatRouteResultHandlers {
  ZChatStreamPort? streamPortFor(String handlerId);
}
```

C'est ce qui répond au point 1 de la commande : les callbacks sont des **ports**, résolus par un
registre côté hôte à partir d'un identifiant transporté verbatim — jamais une `Function` portée
par `ZChatRouteSpec` lui-même (qui doit rester une donnée pure, désérialisable défensivement,
AD-10).

---

## 2. LA RÉSOLUTION

**Chaîne** : `taskKey (= request.style.kind)` → `ZChatRouterSpec.route(taskKey)` →
`(defaultModelId, fallbackModelIds, effort, defaultParams, resultHandlerId)` →
`ZChatGenerationRequest(style: …, modelId: route.defaultModelId, computeEffort: route.effort ??
settings.computeEffort, extra: {...route.defaultParams, ...request.extra})`.

Cette étape est un **calcul pur**, du même gabarit que `ZChatToolCatalog.resolve()` (suivi-1-1
§3, suivi-2-2) : elle consomme une donnée déclarée (`ZChatRouterSpec`) et un contexte (`taskKey`)
pour rendre une valeur dérivée immuable — jamais appelée depuis l'intérieur d'un port, toujours
**avant** la construction de `ZChatGenerationRequest`. Elle n'a pas besoin de vivre dans
`zcrud_chat_kernel` en tant que méthode d'instance du port : un simple **résolveur** (fonction ou
petite classe côté kernel, `ZChatRouteResolution.from(routerSpec, taskKey)`) suffit et reste
testable isolément.

### Où vit la chaîne de repli (`fallbackModelIds`) ?

**Mesuré, IFFD (`consommateurs/rapport.md` §0)** : « Fallback client = UI manuelle, jamais un
retry automatique. » Aucun code n'essaie `aiFallbackModels[i]` après un échec ; le serveur ne
reçoit même jamais la liste — seul le modèle choisi par l'utilisateur (via un dropdown alimenté
par `fallbackModels`) part dans la requête suivante.

**Mesuré, Lex** : la relance automatique sur repli n'apparaît dans aucun rapport lu (le champ
`rag_fallback_models`/`ai_fallback_models` existe côté client mais son usage serveur n'a pas été
tracé au-delà de « transmis »).

⇒ **Le socle ne doit RIEN promettre côté relance automatique** — reproduire une garantie
qu'aucun des deux backends de référence n'honore serait une capacité fantôme. La forme correcte :

1. `fallbackModelIds` reste une **donnée dérivable**, exposée par la résolution (§ ci-dessus) —
   utilisable par un hôte pour peupler un menu (cas IFFD, manuel) **ou** pour écrire sa propre
   boucle de relance côté binding, sur un `Left` typé (`ZChatProviderFailure`/`ZQuotaExceededFailure`
   — jamais un texte parsé).
2. **Tranche** : côté **client/binding**, jamais côté port du socle. `ZChatGenerationPort.generate`/
   `ZChatStreamPort.stream` ne bouclent jamais en interne sur `fallbackModelIds` — ce serait une
   règle métier dans le cœur (AD-16) et changerait la sémantique d'annulation (« un jeton, une
   tentative », dartdoc `z_chat_generation_port.dart` sur `ZChatRequestToken`). Un hôte qui veut la
   relance automatique l'écrit comme un petit exécuteur (`ZChatRouteFallbackExecutor`, hors
   périmètre de cette CR — mentionné pour mémoire) qui reconstruit une `ZChatGenerationRequest`
   avec `modelId: fallbackModelIds[i]` sur un `Left` disqualifiant et relance avec un **nouveau**
   `ZChatRequestToken` (jamais le même — cohérent avec « deux appels concurrents portent deux
   jetons distincts »).

---

## 3. LA GOUVERNANCE

### 3.1 Ce qui manque, confirmé par grep négatif (suivi-2-1)

```
grep -rn "ZPlan\|Entitlement\|workflowEffort\|WorkflowEffort\|max_effort\|maxEffort\|UPGRADE_REQUIRED\|upgradeRequired" packages/*/lib
→ seule sortie : z_chat_compute_effort.dart:16 (citation de WorkflowEffort pour justifier de NE
  PAS l'utiliser)
```
Aucune primitive de plan/palier/plafond n'existe dans zcrud aujourd'hui.

### 3.2 Le port — `ZChatRouteGate`

Tranché par suivi-2-1 : ni extension de `ZAcl` (booléen, CRUD-local, pas de comparaison d'ordre ni
de motif structuré — dénaturerait sa signature déjà consommée par le filtrage d'actions de liste),
ni délégation totale à l'hôte (reproduirait le vide IFFD que la décision owner demande justement de
combler). Un **port dédié**, synchrone comme `ZAcl`, placé dans `zcrud_chat_kernel` (pas
`zcrud_core`) car il opère sur `taskKey`/`tier`, des concepts de routage IA que `zcrud_core` ne
connaît pas (AD-1 : acyclique, `zcrud_core` ne dépend de rien côté chat).

```dart
/// Gate d'accès **avant l'appel**, sur la paire (route/tâche, palier
/// demandé) — miroir du 403 `UPGRADE_REQUIRED` de Lex
/// (`serveur-gouvernance/rapport.md:78-97`), mais côté catalogue et
/// synchrone (pré-check local, pas un aller-retour réseau).
///
/// **Aucune règle métier ne vit ici** (AD-16) : l'implémentation réelle
/// (comparaison d'ordre de palier, table de plafonds par plan) est fournie
/// par l'hôte, exactement comme [ZAcl].
///
/// ⚠️ Ce gate est un **pré-check UX**, jamais l'autorité : le refus serveur
/// (403, ou l'équivalent côté catalogue distant) reste la seule source de
/// vérité — un hôte qui ne câble pas ce port perd seulement l'anticipation
/// locale, pas la protection réelle (portée par le transport, AD-12).
abstract interface class ZChatRouteGate {
  /// `Right(unit)` si [taskKey] au palier [requestedTier] est autorisé pour
  /// l'utilisateur courant, `Left(ZChatProviderFailure(code: 'UPGRADE_REQUIRED'))`
  /// sinon — réutilise le canal d'échec **existant** (§0.6), aucune nouvelle
  /// famille `ZFailure` n'est nécessaire : `code` est déjà un motif opaque
  /// verbatim, exactement la forme qu'exige ce refus.
  ZResult<Unit> canRoute(String taskKey, {String? requestedTier});
}

/// Repli par défaut : refuse tout, même posture que [ZDenyAllAcl] — l'oubli
/// d'un gate ne doit jamais ouvrir silencieusement toutes les routes.
class ZDenyAllChatRouteGate implements ZChatRouteGate {
  const ZDenyAllChatRouteGate();

  @override
  ZResult<Unit> canRoute(String taskKey, {String? requestedTier}) =>
      Left(ZChatProviderFailure(
        'Aucun ZChatRouteGate déclaré.',
        code: 'UPGRADE_REQUIRED',
      ));
}
```

### 3.3 Ce qui reste backend

- La **vérité du plafond par plan** (`user.max_effort` chez Lex) — jamais stockée dans zcrud,
  fournie par l'hôte au gate à chaque appel (comme aujourd'hui côté Lex, `get_user_with_subscription`).
- L'**application réelle** (le vrai 403, ou l'équivalent catalogue-distant) — le gate côté socle est
  un pré-check local, pas un remplacement de la vérification serveur.
- Le **CRUD du routeur en tant qu'entité admin** (qui peut créer/éditer un `ZChatRouterSpec`) reste
  couvert par `ZAcl`/`ZCrudAction` existant, sans rien ajouter (suivi-1-2 point 1 — c'est déjà
  exactement le rôle `"AiRouter<id>"` d'IFFD, un ACL CRUD générique, pas un problème neuf).

---

## 4. LE PORT

`ZChatStreamPort`/`ZChatGenerationPort` — **aucune signature changée** :

```dart
abstract interface class ZChatStreamPort {
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  });
}
```

Confirmé par lecture directe (suivi-1-3) que `ZChatSseStreamPort` ne câble aucun endpoint en dur :
`open`/`decode` sont des dépendances **injectées** au constructeur
(`ZChatSseOpener = Future<Stream<List<int>>> Function(ZChatGenerationRequest, ZChatRequestToken)`).
La route est donc déjà une **donnée résolue en amont**, pas un paramètre du port :

1. La résolution (§2) tourne **avant** la construction de la requête et produit `modelId` (+
   `extra` enrichi de `defaultParams`).
2. L'implémentation concrète du port côté hôte (l'`open` injecté, ou une classe dédiée comme
   `ZIffdTextStreamPort`) choisit son URL/route de transport à partir de
   `route.routeName`/`request.style.kind` — exactement comme elle choisit déjà son URL aujourd'hui
   (`consommateurs/rapport.md` §1 : `explanationModel ?? "explain"` détermine l'endpoint), sauf que
   la résolution `taskKey → routeName` est désormais **nommée et centralisée** (§1.2 `route()`) au
   lieu d'être recopiée à ~20 sites (`consommateurs/rapport.md` §2.1).
3. **Additif, rétrocompatible** : Lex n'a qu'une seule route HTTP — son `open` ignore simplement
   `routeName` (toujours `''` ou non déclaré) et continue de poster sur `/api/v1/chat/`. Rien dans
   ce contrat n'oblige un hôte à adopter le catalogue ; un hôte qui construit sa `ZChatGenerationRequest`
   à la main, sans jamais toucher `ZChatRouteCatalogPort`/`ZChatRouteGate`, garde exactement le
   comportement actuel.

---

## 5. CE QUE L'HÔTE ÉCRIT

### IFFD, après (en lignes, réduction attendue)

- **Un** adaptateur `ZChatRouteCatalogPort` lisant `IffdAiRouterModel` (Firestore, inchangé côté
  entité — le modèle CRUD existant `routeur-entite/rapport.md:190-508` se traduit en
  `ZChatRouterSpec` : les 12 paires `<tâche>Model`/`*FallbackModels` deviennent 12 `ZChatRouteSpec`
  dans `routes`, `workflowEffort` devient `tier`, `questionsCounts` devient `defaultParams` de la
  route `flashcards`) — remplace la lecture directe éparpillée du modèle à ~20 sites
  (`consommateurs/rapport.md` §2.1).
- **Un** point de résolution `route(taskKey)` remplace le calcul dupliqué
  `aiRouter?.XModel ?? "défaut_legacy"` recopié dans `iffd_ai_repository_impl.dart` (17
  occurrences mesurées) — corrige mécaniquement le défaut relevé §2.1/§2.4 du rapport
  consommateurs (`summaryModel` utilisé comme repli pour 7 tâches sans rapport, `elaborationModel`/
  `examplesModel` jamais lus) : chaque `taskKey` a désormais **sa propre** `ZChatRouteSpec`,
  impossible de la confondre avec celle d'une autre tâche par accident de nommage.
- **Un** adaptateur `ZChatRouteGate` qui, dans un premier temps, se contente de retraduire
  `aiHasAccessToAiRouter(routerId)` (ACL de rôle existant, inchangé) — pas de plan à inventer tout
  de suite ; l'entitlement réel viendra quand IFFD en aura un.
- Les **openers** de transport (déjà partiellement extraits, `notebook_ports_iffd.dart:146-158`,
  non avancés depuis suivi-1-3) choisissent leur URL depuis `route.routeName` au lieu d'un `switch`
  local — la même fonction de dispatch peut désormais servir *tous* les endpoints IFFD, legacy
  compris, au lieu d'un seul (Notebook) qui reproduit imparfaitement le comportement legacy
  (divergence `chatModel` vs `aiRouterId` déjà relevée, `consommateurs/rapport.md` ligne 51).
- Ce que IFFD **retire** : la duplication `"model": aiRouter?.aiModel` (17 sites), les 3 copies du
  calcul de dropdown de repli (`smartnotes_dialogs.dart` ×2, `flashcard_edition_screen.dart` ×1,
  `consommateurs/rapport.md` §2.3), le pattern dupliqué « liste filtrée + `firstWhere` par id »
  répété à chaque écran de sélection (`routeur-entite/rapport.md` §5, qualifié « signal
  d'assemblage manquant » par le CLAUDE.md lui-même) — remplacé par `ZChatRouteCatalogPort.resolveRouter`
  + `ZChatRouterSpec.route`.

### Lex, pour migrer (à terme, pas immédiat)

- **Un** adaptateur `ZChatRouteCatalogPort` qui **enveloppe** l'`AiRouterService` existant côté
  backend (déjà écrit : cascade Redis→Firestore→fallback, `serveur-gouvernance/rapport.md` §5.2) —
  côté client, ne fait qu'un appel HTTP vers `admin_bridge/ai_routers.py` (déjà exposé) au lieu de
  construire son propre `workflow_effort` local ; aucune migration du backend Python n'est requise
  pour cette étape, seul le **client** apprend à consommer le catalogue.
- **Un** adaptateur `ZChatRouteGate` qui reproduit `_EFFORT_ORDER`/`user.max_effort` **côté client**
  comme pré-check UX (afficher le CTA upgrade avant même de poster) — le vrai gate reste le 403
  serveur (§3.3), inchangé.
- Le transport reste **inchangé** : une seule route HTTP, `routeName` non consommé par l'`open`
  (toujours `/api/v1/chat/`) — le catalogue ne pilote alors que `modelId`/`effort`/`defaultParams`,
  pas l'URL. C'est le sens de « additif, rétrocompatible » : Lex peut adopter le catalogue pour la
  résolution de modèle sans toucher à son unique endpoint.

### Ce qui reste irréductiblement hôte

- **Libellés/icônes** (FR-26) — `name`/`description` d'un routeur, le displayName d'un modèle : ne
  vivent dans aucun type de ce contrat (`ZChatRouterSpec.id`/`ZChatRouteSpec.taskKey`/`routeName`
  sont tous des identifiants **opaques**, jamais des chaînes d'affichage).
- **URL, authentification, en-têtes** (AD-12) — portés par l'`open`/`decode` injecté à
  `ZChatSseStreamPort`, jamais par le catalogue.
- **Prix, définition d'un plan, vérité de l'entitlement** — le socle expose la **forme** du refus
  (`ZChatRouteGate`), jamais la table de plafonds ni la logique d'abonnement (AD-16, cf. §3.3).
- **Nom de collection Firestore, schéma de persistance** du catalogue lui-même — reste un choix
  d'implémentation d'adaptateur (`ZChatRouteCatalogPort`), pas du contrat.
- **La boucle de relance automatique sur repli**, si un hôte la veut — délibérément hors du port
  (§2), aucun des deux backends de référence ne l'exerce aujourd'hui.

## B. Relevé — routeur-entite

## 1. Le modèle `IffdAiRouterModel` — `lib/src/domain/models/ai/ai_models.dart:190-508`

Classe `DynamicModel` (moteur CRUD legacy IFFD), `Equatable` (`props` L513-538, `stringify=true`).

### Champs (L190-241)

| Champ | Type | Rôle | Défaut (constructeur L241-278) |
|---|---|---|---|
| `id` | `String?` (hérité `DynamicModel`) | identifiant du document Firestore | — |
| `name` | `String?` | libellé affiché (menu de sélection, admin) | `null` |
| `description` | `String?` | sous-titre admin | `null` |
| `aiModel` | `String` | **modèle par défaut du routeur**, socle de repli de TOUTES les tâches | `'nvidia/nemotron-3-nano-30b-a3b'` |
| `aiFallbackModels` | `List<String>` | repli du modèle par défaut lui-même | `[]` |
| **12 paires `<tâche>Model` / `<tâche>FallbackModels`** (`explanation`, `chat`, `mindmap`, `flashcards`, `summary`, `elaboration`, `examples`, `poem`, `history`, `humor`, `chatStyle`, `thinking`) | `String?` / `List<String>` | modèle par défaut **par tâche** + sa chaîne de repli propre | `null` / `[]` |
| `workflowEffort` | `WorkflowEffort` (`low`/`medium`/`high`, displayName Mini/Plus/Pro — L119-133) | palier d'effort du routeur, sert au tri de la UI (L67 `discovry_search_composer.dart`) et au gate serveur `403 UPGRADE_REQUIRED` déjà relevé côté §4 de l'analyse backends | `WorkflowEffort.medium` |
| `questionsCounts` | `Map<QuestionType, double>` | nombre de questions par type pour la génération de flashcards/examens | `{multipleChoice:5, trueOrFalse:4, openQuestion:3, exercise:3}` |

### `toMap()` (L358-393)
Sérialise `id`, `name`, `description`, `aiModel` + 12×2 champs de tâche, `workflowEffort.name`, `questionsCounts` reclé en `{QuestionType.name: double}`.

### `fromMap()` (L396-476) — désérialisation défensive notable
- `aiModel` : `map['aiModel'] as String? ?? 'nvidia/nemotron-3-nano-30b-a3b'` (jamais absent).
- **`modelOrDefault(dynamic model)`** (L406-412) : pour **chacun des 12 champs `<tâche>Model`**, si la valeur Firestore est absente/vide, **retombe sur `aiModel`** — donc chaque tâche a TOUJOURS un modèle résolu, même si son champ dédié n'a jamais été renseigné en base.
- `toListOfString` (L398-414) : tolère `List<String>`, `List<dynamic>`, `String` seul, ou repli sur `[]` — aucune exception possible.
- `workflowEffort` : `firstWhere(..., orElse: () => WorkflowEffort.medium)`.
- `questionsCounts` : si absent/non-Map → repli sur les 4 valeurs par défaut ; sinon parse clé par clé, entrée ignorée si le nom ne correspond à aucun `QuestionType` (`toQuestionEntry`, L426-436, `where((e) => e != null)`).
- Note : le paramètre `fallbackToAiModel` de `toListOfString` est **mort en pratique** — la ligne qui l'utilisait est commentée (L403-406, `// final _aiFallbackModels = ...`) et remplacée par `const _aiFallbackModels = <String>[]` : aucun repli en cascade des listes de fallback vers `aiFallbackModels` n'a lieu, contrairement à ce que le nom du paramètre laisse penser.

## 2. Repository — `lib/src/domain/repositories/ai_router_repository.dart` + `lib/src/data/repositories/firebase_models_repositories_impls.dart:300-303`

```dart
abstract class AiRouterRepository implements CrudRepository<IffdAiRouterModel> {}

class FirebaseAiRouterRepositoryImpl
    extends FirebaseCrudRepositoryImpl<IffdAiRouterModel>
    implements AiRouterRepository {}
```

Aucune surcharge : ni `crudableObjects` (donc `allowedOperations: Crud.defaultCrudOperations`, base `firebase_crud_repository_impl.dart:24-28`), ni requêtes spécifiques. C'est un **CRUD Firestore générique**, sans logique métier propre au routeur dans le repository.

**Collection Firestore** : `getFirebaseCollectionName<IffdAiRouterModel>()` (`databases_functions.dart:8-11`) — grep négatif montré : `grep -na "IffdAiRouterModel" lib/src/utils/constants/databases.dart` → aucune sortie, donc `FIREBASE_COLLECTION_NAMES[IffdAiRouterModel]` n'existe pas et le nom de collection retombe sur `T.toString()` = **`"IffdAiRouterModel"`** (nom de classe brut, pas de mapping snake_case dédié).

## 3. Qui peut créer / lire / modifier — ACL par rôle, PAS un abonnement

`bool aiHasAccessToAiRouter([String? id])` (`lib/src/domain/security/app_user_permissions.dart:233-236`) :
```dart
bool aiHasAccessToAiRouter([String? id]) {
  if (id == null || id.isEmpty) return false;
  return hasAccessTo("AiRouter$id");
}
```
`hasAccessTo<R>` (L117-127) délègue à `permissionHasAccessTo`, qui **court-circuite en `true` si `isAdmin`** (L100), sinon exige une clé `"AiRouter<id>"` **non vide** dans `rolePermissions` / `postesPermissions` / `permissions` de l'utilisateur — c'est donc un **droit par identifiant de routeur, porté par le système de rôles générique** (`AppUserRole`), exactement le même mécanisme que pour n'importe quelle autre ressource CRUD (`Crud.create`/`read`/...).

`isAdmin` (L16-19) : `roles.contains("admin"/"ADMIN")` OU `uid == "admin"` OU `email == "zakaribilali@gmail.com"` (bypass total, y compris création/édition de routeurs).

Grep négatif montré — **aucune notion de plan / abonnement / entitlement** liée aux routeurs :
```
grep -rna "plan\|subscription\|entitlement\|premium" lib/src/domain/security lib/src/presentation/features/ai_routers
→ seules occurrences : sous-chaîne "explanation" (faux positifs), rien d'autre.
```
La gouvernance d'accès à un routeur IFFD n'est donc **pas** un plan d'abonnement au sens zcrud (owner) : c'est une permission de rôle nommée par l'id du routeur (`"AiRouter<id>"`), à accorder manuellement via l'édition des rôles (`AppUserRole.permissions`).

**Amorçage automatique** (`lib/src/domain/security/access_controlled_view.dart:255-267`) :
```dart
if (aiRouters.isEmpty && userPermissions.isAdmin) {
  Future.microtask(() {
    ref.read(aiRouterRepositoryProvider).batchSet(items: defaultIffdModels);
  });
}
```
Si la collection est vide **et** l'utilisateur courant est admin, `defaultIffdModels` (= `[_freeRouter]`, L569) est écrit en base via `batchSet` — side-effect placé hors `build()` (commentaire "H1 fix" contre les écritures répétées à chaque rebuild).

`_freeRouter` (L548-566) : `id: 'free'`, `name: 'Polaris Lite'`, `workflowEffort: low`, `aiModel: "nvidia/nemotron-3-nano-30b-a3b:free"`, `aiFallbackModels: [nvidia..., bytedance-seed/seed-1.6-flash]`, `questionsCounts` = les 4 défauts. **Construit via `IffdAiRouterModel.fromMap(...toMap())`** (round-trip explicite), pas directement par le constructeur.

**Page admin** (`ai_routers_page.dart:74-75, 248, 621`) : gate sur `permissions.getACL<IffdAiRouterModel>()` — `acl.read == false` → écran de refus ; `crud: Crud.create` gate le bouton d'ajout (L248, L621). C'est le même ACL CRUD générique que pour toute entité (pas de rôle "admin" en dur dans ce fichier — l'admin l'obtient via `isAdmin` bypass plus haut).

## 4. Édition admin — deux chemins, un seul actif

### 4.a Chemin LEGACY actif — `ai_routers_dialogs.dart` (700 lignes)
Formulaire complet : `name` (requis), `description`, `workflowEffort` (select sur `WorkflowEffort.values`, L483-492), puis **7 groupes de modèles de repli** (`ai`/`explanation`/`conversation`/`mindmap`/`flashcards`/`summary`/`development`), chacun une sous-liste réordonnable de `{name, displayName}` où `displayName` est **dérivé** de `name` (jamais saisi, `dynamicSubItemTransformer`) et `name` est forcé en minuscules à la saisie (`lowerCaseFormatter`). Règle ACL notable : **suppression interdite si un groupe n'a qu'un seul modèle** (`delete: items.length > 1`, L104 référencé) — un routeur ne peut jamais se retrouver sans aucun modèle de repli.

### 4.b Chemin PORTÉ zcrud — `ai_router_zcrud_edition.dart` — **flag OFF par défaut**
```dart
const bool kAiRouterEditionUseZcrudDefault = false; // L77
```
Le fichier documente lui-même pourquoi il est inerte : seule la moitié « 3 champs simples + 7 sous-listes » est portée (déclarativement, via `ZFieldSpec`/`ZSubListConfig`/`IffdMinimumOneAcl` qui traduit exactement `delete: items.length > 1`), mais le flag ne peut être basculé qu'après portage complet — sinon le formulaire rendu serait amputé. `AiRouterZcrudEditionScreen` (widget réel, `DynamicEdition` + `ZFormController` + `ZEditionSubmitController`) existe et est fonctionnel mais n'est monté nulle part tant que le flag est `false` (aucun site d'appel actif trouvé — le fichier documente une correction antérieure où le screen manquait complètement avant la version W9d).

`adaptAiRouterZcrudOutput` (L397-404) : étale `rawSeed` (la map Firestore brute, préservant les clés hors-schéma : identité, horodatages, champs serveur) puis les valeurs du formulaire par-dessus — pas de perte de champs non couverts par le schéma porté.

## 5. Résolution du routeur COURANT (côté utilisateur, pas admin)

`aiRouterId` (`String`, défaut `"free"`) vit dans **plusieurs contrôleurs distincts**, pas un état central unique :
- `discovry_page_controller.dart:607,711-719` — champ mutable, `setAiRouterId` retombe sur `"free"` si `id` est `null`/vide.
- `smart_learn_controller.dart:129-198` — getter/setter avec **persistance `shared_preferences`** (`prefs.getString("aiRouterId") ?? "free"` / `prefs.setString(...)`).
- `settings_providers.dart:47-63` (module Riverpod plus récent, commentaire *"Replaces SmartLearnController.aiRouterId..."*) — même clé `prefs`, même défaut `'free'`.

**Résolution** : partout, le motif est identique — une liste `List<IffdAiRouterModel> aiRouters` (streamée depuis Firestore via `allAiRoutersProvider`) est **filtrée par accès** (`userPermissions.aiHasAccessToAiRouter(el.id)`, cf. `discovry_search_composer.dart:78-81`) puis on cherche l'élément dont `id == aiRouterId` :
```dart
final accessibleRouters = aiRouters.where((el) => userPermissions?.aiHasAccessToAiRouter(el.id) ?? false).toList()
  ..sort((a, b) => a.workflowEffort.index.compareTo(b.workflowEffort.index));
final aiRouter = accessibleRouters.firstWhere((el) => el.id == aiRouterId, orElse: () => defaultIffdModels.first);
```
(même motif répété dans `discovry_ai_page.dart:81-90`, `chatbot_conversation_screen.dart:345-372`, `smart_learn_controller.dart:564`). Le tri par `workflowEffort.index` ordonne le menu Mini→Plus→Pro. Le repli `orElse: () => defaultIffdModels.first` retombe sur `_freeRouter` **en mémoire** (pas relu de Firestore) si l'id choisi n'est plus accessible/trouvé.

Il n'existe **aucune** résolution centrale unique côté domaine : c'est un pattern dupliqué (liste filtrée + `firstWhere` par id) recopié à chaque écran de sélection — c'est la classe de duplication que le CLAUDE.md qualifie de « signal d'assemblage manquant » côté zcrud.

## 6. Codec legacy — `lib/src/data/migration/z_iffd_legacy_codec.dart:84`

Seule mention d'`IffdAiRouterModel` :
```dart
'questions_counts', // IffdAiRouterModel — QuestionType.name (camelCase !)
```
Dans la section §4.5 des « clés opaques dont les valeurs sont des noms d'enum » : la conversion générique `camelToSnake` du codec de migration doit **épargner** les clés de la map `questionsCounts` (`multipleChoice`, `trueOrFalse`, `openQuestion`, `exercise`) car ce sont des `QuestionType.name` en camelCase, pas des noms de champ à transformer. Le codec ne dit rien de plus sur l'entité routeur — pas de renommage de collection, pas de champ migré.

## Récapitulatif du cycle de vie

1. **Amorçage** : `_freeRouter` unique, id `"free"`, écrit par le premier admin qui ouvre l'app si la collection `IffdAiRouterModel` est vide.
2. **Création/édition admin** : `AiRoutersPage` (ACL `Crud.create`/`read`) → `ai_routers_dialogs.dart` (chemin actif) → `fromMap<IffdAiRouterModel>` → `FirebaseAiRouterRepositoryImpl` (CRUD Firestore générique, collection `"IffdAiRouterModel"`). Chemin zcrud porté existe mais flag OFF.
3. **Gouvernance d'accès** : permission de rôle nommée `"AiRouter<id>"`, pas de plan/abonnement ; bypass admin total.
4. **Sélection utilisateur** : `aiRouterId` (défaut `"free"`, persisté en `SharedPreferences` selon le contrôleur) filtré contre la liste streamée + permissions, résolu par `id` à chaque écran consommateur (pattern dupliqué, pas de résolveur central).
5. **Résolution modèle par tâche** : `fromMap` garantit qu'un champ `<tâche>Model` absent retombe silencieusement sur `aiModel` du même routeur — jamais de tâche sans modèle résolu.

## B. Relevé — consommateurs

Lecture seule sur `/home/zakarius/DEV/iffd`. Backend actif : `IffdAiRepositoryImpl`
(confirmé seul point d'instanciation câblé au provider —
`folder_explanation_page.dart:121-122`, `aiRepositoryProvider`). `CloudFunctionsAiRepositoryImpl`
(`lib/src/data/repositories/cloud_functions_ai_repository_impl.dart`) et
`OpenaiAiRepositoryImpl` (`lib/src/data/repositories/openai_ai_repository_impl.dart`) implémentent
la même interface `AiRepository` mais aucun site d'instanciation actif n'a été trouvé pour eux
(grep négatif : `grep -rn "CloudFunctionsAiRepositoryImpl(\|OpenaiAiRepositoryImpl("
lib/ --include="*.dart"` ne remonte que leurs déclarations de classe) — ce sont des
implémentations mortes/alternatives, pas des consommateurs à documenter.

## 0. Le modèle du routeur

`IffdAiRouterModel` (`lib/src/domain/models/ai/ai_models.dart:190-395`) : entité CRUD Firestore
(`DynamicModel`), un champ `aiModel`+`aiFallbackModels` "par défaut", puis PAR TÂCHE
`{explanation, chat, mindmap, flashcards, summary, elaboration, examples, poem, history,
humor, chatStyle, thinking}Model` + `*FallbackModels`, plus `workflowEffort` (enum
`WorkflowEffort`) et `questionsCounts: Map<QuestionType,double>`. Édité via
`AiRoutersPage`/`ai_router_zcrud_edition.dart`. Résolution d'accès :
`SmartLearnController.aiRouter()` (`smart_learn_controller.dart:555-567`) filtre par
`userPermissions.aiHasAccessToAiRouter(id)` puis cherche `el.id == aiRouterId`, repli
`defaultIffdModels.first`. `aiRouterId` par défaut = `"free"` (`discovry_page_controller.dart:607`,
setter `setAiRouterId` ligne 711-718 qui remet `"free"` si `null`/vide) — persisté aussi
dans les prefs côté `smart_learn_controller.dart:129-198`.

**Fallback client = UI manuelle, jamais un retry automatique.** `*FallbackModels` n'alimente
que des menus déroulants (`smartnotes_dialogs.dart:200-209,283-292`,
`flashcard_edition_screen.dart:645-651`, `ai_routers_dialogs.dart`) où l'utilisateur choisit à
la main un autre modèle *avant* de lancer la génération. Aucun code n'essaie automatiquement
`aiFallbackModels[i]` après un échec — grep négatif :
`grep -rn "for.*[Ff]allbackModels\|catch.*[Ff]allback" lib/src/data lib/ai_assistant lib/src/presentation/features/{discovery,flashcards,mindmap,smartnotes}` :
aucune occurrence. Le serveur n'est pas plus impliqué : la charge utile n'envoie jamais la
liste de repli, seulement `"model": aiRouter?.aiModel` (un seul identifiant, cf. tableau).

## 1. Tableau tâche par tâche (backend `IffdAiRepositoryImpl`)

| Tâche | Champ *Model du routeur ↦ endpoint | Modèle envoyé dans le corps | Repli | Callback | Effort |
|---|---|---|---|---|---|
| Chat (discovery) | `chatModel ?? "chat"` (repo `:691`, appelé par `discovry_page_controller.dart:1184` `sendMessageToChatbot`) | `"model": aiRouter?.aiModel` (repo `:697`) — **pas** `chatModel` | UI seule, jamais auto (voir §0) | `onComplete: (AiResponse, bool completed, {bool hasError})`, unique, réutilisé pour stream et non-stream ; `AiResponse.reasoning` porte le texte entre sentinelles `<RAG_THINKING>…</RAG_THINKING>` détectées côté `callApi`/`openRawByteStream` (repo `:141-158`) | `thinkingEffort` (int 0-5, contrôleur `discovry_page_controller.dart:597`) + `enableThinking` (bool dérivé) transmis en clair dans le corps ; `workflowEffort` **jamais transmis par le client** — seul `IffdAiRouterModel.workflowEffort` sert à TRIER/FILTRER les routeurs affichés à l'utilisateur (`discovry_ai_page.dart:87`, `discovry_search_composer.dart:69,226`), jamais envoyé au serveur |
| Explication de sujet | `explanationModel ?? "explain"` (repo `:750`, appelé `discovry_page_controller.dart:1240` `explainSubject`) | `"model": aiRouter?.aiModel` (repo `:755`) | idem | même `onComplete` unifié, relayé par `_onAiCompletion` | même paire `thinkingEffort`/`enableThinking` |
| Sujets liés | endpoint **fixe** `"generate_related_topics"` — `*Model` du routeur **non consulté** (repo `:782,811`) | `"model": aiRouter?.aiModel`, mais `aiRouter` est explicitement **forcé** à `aiRouter?.copyWith(aiModel: "openai/gpt-oss-20b")` par l'appelant (`discovry_page_controller.dart:1294,1395`) — seul point du code qui court-circuite le routeur choisi par l'utilisateur | — | même `onComplete` | — |
| Résumé de conversation | endpoint fixe `"generate_conversation_summary"` (repo `:828`) | `aiRouter?.aiModel` | idem | idem | — |
| Résumé de document (smartnotes) | `summaryModel ?? "generate_summary"`/`"summarize_explanation"` selon le point d'entrée (repo `:868,914,941`) — **incohérence de nommage** : `summaryModel` sert AUSSI de repli d'endpoint pour élaboration/style/flashcard-explanation/tags/subject-flashcards/évaluation/indice (repo `:969,998,1035,1070,1099,1129,1158` — 7 endpoints différents replient tous sur `aiRouter?.summaryModel`, alors que le routeur a des champs `elaborationModel`, `examplesModel` dédiés jamais utilisés à ces sites) | `aiRouter?.aiModel` partout | UI seule (menu de `smartnotes_dialogs.dart:196-210`, dropdown initialisé sur `aiRouter?.summaryModel`) | `onComplete` unifié | — |
| Développement / Exemples / Style (variantes texte) | tous replient sur `summaryModel` malgré l'existence de `elaborationModel`/`examplesModel` dans le modèle (voir ligne au-dessus) | `aiRouter?.aiModel` | — | idem | — |
| Flashcards (depuis valuation tool) | `flashcardsModel ?? "generate_flashcards"` (repo `:617`) | `aiRouter?.aiModel`, **`jsonMode: true`** | UI (dropdown `flashcard_edition_screen.dart:645-651`, défaut = `flashcardsModel`) | idem, `questionsCounts: aiRouter?.questionsCounts ?? {}` transmis séparément (repo `:614`) | — |
| Flashcards (document entier / pages / notes) | `flashcardsModel ?? "generate_flashcards"` (repo `:1196,1229,1260`) — 3 endpoints identiques pour 3 sources de matière | `aiRouter?.aiModel`, `jsonMode: true` | idem | idem | — |
| Flashcards (Notebook) | `generateFlashcardsFromNotes` → même repli `flashcardsModel ?? "generate_flashcards"` | `aiRouter?.aiModel` | idem | `onComplete` relayé par `notebook_capabilities_iffd.dart:505-510` (`wiring.aiRepository.generateFlashcardsFromNotes(aiRouter: wiring.aiRouter, …)`) | — |
| Mindmap (document/notes) | `mindmapModel ?? "generate_mindmap"` (repo `:636,1291,1318`) | `aiRouter?.aiModel`, `jsonMode: true` | idem | idem | — |
| Mindmap (Notebook) | `generateMindmapFromNotes` → même repli | `aiRouter?.aiModel` | idem | `notebook_capabilities_iffd.dart:488-493` | — |
| Notebook (`chat`, chemin zcrud porté) | endpoint **codé en dur** `'chat'` dans `folder_explanation_page.dart:184` (commentaire : « le même endpoint que `chatWithAi` : `aiRouter?.chatModel ?? 'chat'` » — mais **`aiRouter?.chatModel` n'est PAS relu ici**, seul le défaut littéral `'chat'` du legacy est reproduit) | `'model': request.modelId ?? defaultModelId` (`notebook_byte_opener_iffd.dart:133`) où **`defaultModelId` = `defaultDiscovryPageController.aiRouterId`** (`folder_explanation_page.dart:213-215`) — c'est **l'identifiant du routeur** (ex. `"free"`), **pas** `aiRouter.aiModel` (ex. `"nvidia/nemotron-3-nano-30b-a3b"`) envoyé par tous les autres chemins ci-dessus. Divergence non documentée comme telle : le corps du POST notebook porte donc une valeur de nature différente dans le champ `model` que le chemin legacy pour le même endpoint `chat` | UI (sélecteur de modèle du Notebook, `onModelSelected: defaultDiscovryPageController.setAiRouterId`) | Port `ZChatStreamPort` du socle (`ZIffdTextStreamPort`) au-dessus d'un `openRawByteStream` brut (octets non interprétés, pas de séparation reasoning/réponse faite ici — cf. commentaire `notebook_ports_iffd.dart:146-158` : l'extraction du flux legacy vers ce port n'a pas encore eu lieu, caractérisée mais pas faite) | `request.corpusScope`, `request.webSearch`, `request.revealThinkingSteps` mappés en clair (`notebook_byte_opener_iffd.dart:130-153`) ; pas de `thinkingEffort` numérique relevé dans ce payload (grep négatif : `grep -n "thinkingEffort" lib/ai_assistant/zcrud/notebook_byte_opener_iffd.dart` → vide) |
| Expert IA (instructions/documents) | endpoints fixes `AiRepository.generateAiExpertInstructionsEndpoint`/`ingestAiExpertDocumentsEndpoint` (repo `:1335,1356`) — `*Model` du routeur non consulté pour le nom d'endpoint | `aiRouter.aiModel` | — | idem | — |
| Assistant OpenAI (retrieve/set) | endpoints fixes `"retreive_openai_assistant"`, `"retreive_openai_vectorstore"`, `"set_ai_expert_openai_assistant"` (repo `:507,540,570,597`) | pas de `model` dans le corps observé pour ces trois | — | idem | — |

## 2. Ce qui est dupliqué entre fonctionnalités

1. **`"model": aiRouter?.aiModel` recopié dans ~20 sites** de `iffd_ai_repository_impl.dart`
   (grep : `grep -n '"model": aiRouter?.aiModel' lib/src/data/repositories/iffd_ai_repository_impl.dart`
   → 17 occurrences). Chaque méthode réécrit le même triplet
   `endpoint: aiRouter?.XModel ?? "défaut_legacy"` / `data: {"model": aiRouter?.aiModel, …}` —
   aucune fonction commune ne fait la résolution "champ de tâche → endpoint,
   `aiModel` → corps". Le paramètre `aiModel` du corps ignore systématiquement le champ
   de tâche (`chatModel`, `flashcardsModel`…) : celui-ci ne sert qu'à choisir l'URL, jamais
   la valeur envoyée dans `model`. Autrement dit deux résolutions indépendantes et
   non nommées comme telles : "quelle route" (par tâche) et "quel modèle" (toujours le
   champ générique `aiModel`), câblées séparément à chaque site d'appel.
2. **Le triptyque marquer/appeler/démarquer l'occupation** (`isGenerating`) est réécrit à
   la main pour chaque capacité générative — legacy (`discovry_page_controller.dart`,
   `smartnotes_dialogs.dart`, `flashcard_edition_screen.dart`) et Notebook porté
   (`notebook_capabilities_iffd.dart:30-45`, `_genererAvecOccupation`) — même motif,
   deux implémentations parallèles (une par famille de surface), sans fonction partagée
   entre les deux mondes (legacy / notebook zcrud).
3. **La résolution "dropdown de repli = `xFallbackModels` + `xModel` dédupliqué"** est
   répétée à l'identique dans `smartnotes_dialogs.dart:200-209` (résumé),
   `smartnotes_dialogs.dart:283-292` (mindmap), et `flashcard_edition_screen.dart:645-651`
   (flashcards) — trois copies du même calcul
   `[...fallbacks, if (model != null && !fallbacks.contains(model)) model]`.
4. **`summaryModel` sert de repli d'endpoint pour 7 tâches distinctes** (résumé, résumé
   whole-document, résumé explication, élaboration, style, explication de flashcard,
   tags de sujet, flashcards de sujet, évaluation de réponse, indice — repo lignes
   868-1167) alors que le modèle porte des champs dédiés `elaborationModel`,
   `examplesModel` jamais lus à ces sites (grep négatif :
   `grep -n "aiRouter?.elaborationModel\|aiRouter?.examplesModel"
   lib/src/data/repositories/iffd_ai_repository_impl.dart` → aucune occurrence). Ces deux
   champs du routeur ne sont donc consultés NULLE PART dans le repository actif — ils
   existent dans le modèle, l'édition (`ai_routers_dialogs.dart`) les propose, mais aucun
   appel ne les lit.
5. **Callback unique `onComplete(AiResponse, bool completed, {bool hasError})`** partout
   dans le chemin legacy — pas de `onToken`/`onDone`/`onError`/`onReasoning` séparés :
   un seul rappel porte les trois états (delta, fin, erreur), et le raisonnement voyage
   dans `AiResponse.reasoning` (même objet que la réponse, discriminé par un booléen
   `reasoning` local au flux, pas par un champ du type). Le chemin Notebook zcrud est le
   seul à typer séparément (`ZChatStreamEvent`, via le port), mais uniquement pour ce
   chemin — la coexistence signifie deux representations différentes du même flux serveur
   selon la surface.

## Gaps

- Le corps exact envoyé par `openRawByteStream` (utilisé par le Notebook) n'a pas été
  comparé octet-à-octet à celui de `callApi` (legacy) au-delà de la lecture de
  `iffd_ai_transport.dart` citée en commentaire — non ouvert dans cette passe.
- `explain_ai_page.dart`, `valuation_tools`, `documents` (sites listés en §"generateMindmapFrom")
  n'ont été vus que par grep de nom de fonction, pas lus en détail — probable répétition du
  même motif que smartnotes/flashcards mais non confirmé ligne à ligne.
- `AiRoutersPage`/édition zcrud (`ai_router_zcrud_edition.dart`) non ouverte en détail — la
  UI de gouvernance (qui peut créer/éditer un routeur, lien avec un plan d'abonnement) n'a
  pas été tracée ici, seule la lecture côté consommation l'a été.
- Pas de preuve trouvée d'un mécanisme d'auto-sélection de `aiFallbackModels` niveau
  serveur (smart_learn_cloudfunctions) — seul le côté client IFFD a été inspecté dans cette
  tâche, cf. `docs/analyses/backends-lex-iffd-2026-08-23.md` pour le serveur.

## B. Relevé — serveur-gouvernance

## 1. IFFD — dispatch : une fonction Python par route, pas de registre

`grep -na "^@router\.\|^def \|^async def " iffd/v2/router.py` et `iffd/v1/router.py` (sortie complète
citée dans le transcript) montrent que **chaque tâche a sa propre paire de décorateurs
`@router.post('/nom_tache')` + `@router.get('/nom_tache')`** sur une fonction `async def` dédiée.
Exemples v2 : `generate_subject_flashcards` (908-910), `generate_subject_explanation` (923-925),
`summarize_explanation` (928-930), `chat_with_assistant_v2` (1007-1011), `generate_mindmap_with_ai`
(1014-1016). **Aucun registre/table de dispatch** sur une chaîne `endpoint` reçue en payload — le
nom de route EST le nom de fonction FastAPI, câblé au niveau du décorateur, pas résolu dynamiquement
à l'exécution à partir d'un champ du corps.

Un **`iffd/v3/router.py` existe aussi** (1773 lignes non comptées dans le scope de départ) — même
patron : `@router.get`/`@router.post` par tâche (`generate_subject_tags`, `chat_with_assistant`,
`generate_subject_explanation`, etc., lignes 128-291), plus quelques tâches v2-only
(`get_sh2022_expl` à v2/router.py:1555, absent de v3 dans l'extrait vu). Trois versions de routeur
coexistent donc, chacune avec son propre jeu de fonctions par route — aucune n'introduit de
registre commun.

La plupart des fonctions de tâche (v2:891-1085 et suivantes) délèguent en interne à
`generative_ai_answer` (v2/router.py:318) qui, elle, lit tout depuis le corps JSON/query params —
c'est LÀ que vit la logique de modèle, pas dans un dispatcher de route.

## 2. Ce que le serveur fait du modèle reçu (v2/router.py:369-404)

Dans `generative_ai_answer` (v2/router.py:318-828) :
- `ai_provider = data.get("aiProvider", "openrouter")` (ligne ~387) et `ai_model = data.get("aiModel", …)`
  sont **entièrement pilotés par le client**.
- Le serveur applique un **repli de modèle PAR FOURNISSEUR** si `aiModel` est absent
  (`GOOGLE_DEFAULT_MODEL`, `DEEPSEEK_DEFAULT_MODEL`, `HYPERBOLIC_DEFAULT_MODEL`,
  `ALIBABA_DEFAULT_MODEL`, `OPENROUTER_DEFAULT_MODEL`, `GROK_DEFAULT_MODEL`, `OPENAI_DEFAULT_MODEL`
  — constantes non montrées dans l'extrait mais référencées lignes 369-404), puis **préfixe/normalise
  l'identifiant du modèle selon le fournisseur** avant de router vers `openrouter` (ex. `google` →
  `google/{model}`, `deepseek` → `deepseek:{model}`, `alibaba` → `qwen:{model}`, `xai` → `x-ai:{model}`).
  C'est un **mapping fournisseur→préfixe**, pas une politique d'accès : il ne conditionne rien à
  l'identité de l'utilisateur ni à un plan.
- `ragModel`/`webSearchModel` (lignes ~366-367) suivent le même principe : `data.get('ragModel',
  OPENROUTER_DEFAULT_MODEL)`.
- **Aucune vérification d'autorisation** sur le modèle/fournisseur demandé n'apparaît dans cette
  fonction : c'est un simple `dict.get` avec valeur par défaut serveur, jamais un rejet.
- `workflow_effort` (lignes ~356-364) est parsé depuis une chaîne libre (`_parse_workflow_effort`) et
  borné (`thinking_effort = max(1, min(thinking_effort, 5))`, ligne ~349) mais **borné en VALEUR**,
  jamais en **DROIT D'ACCÈS** (pas de comparaison à un plafond utilisateur).

## 3. Plan / quota / entitlement / premium / free côté IFFD+shared

`grep -rnaE --include="*.py" -i "\b(plan|tier|quota|entitlement|premium|free)\b" iffd shared` (sortie
complète : 44 Ko, tronquée en preview — voir échantillon ci-dessous) ne renvoie **aucune** occurrence
d'un concept de gouvernance d'accès. Les seuls matches "free" sont :
- des **identifiants de modèles OpenRouter gratuits** (`iffd/v3/agents/multilayer_agents.py:11-12` :
  `"moonshotai/kimi-k2:free"`, `"tngtech/deepseek-r1t2-chimera:free"` ; `iffd/v3/router.py:40,43-44,91` en
  commentaires) ;
- `iffd/iffd_ai/base_iffd_ai.py:820` : `free_model = "free" in model_name` — sert uniquement à
  désactiver `max_completion_tokens`/`response_format` pour les modèles OpenRouter gratuits (contrainte
  technique du fournisseur), **pas** une notion de plan utilisateur ;
- du texte français non lié (`iffd/system_instructions.py:1010-1021` : "plan détaillé" au sens
  structure de résumé ; `podcasts_ai.py:387` idem).

Les matches "plan/tier/quota/entitlement/premium" en dehors de "free" sont **tous des faux positifs
de sous-chaîne** (`SH_EXPLANATION_FILE_ID` contient "explanation" pas "plan" — en réalité aucun hit
réel hors "free" n'est apparu dans la sortie complète). ⇒ **Grep négatif confirmé : IFFD ne porte
aucune notion de plan d'abonnement, de quota ou d'entitlement associée à une route ou à un modèle**,
cohérent avec l'acquis "IFFD = aucune annulation serveur, auth non vérifiée sur v2" du contexte fourni.

## 4. Endpoint catalogue côté IFFD

`grep -na "@router.get" iffd/v2/router.py iffd/v1/router.py iffd/v3/router.py` (sortie complète citée)
et un second grep restreint aux noms `list|catalog|available|models|routes` dans les chemins de route
**ne renvoient aucun résultat** — confirmé par une sortie vide sur ce second grep. Tous les
`@router.get` recensés sont des **alias GET des mêmes handlers POST par tâche** (ex.
`@router.get('/generate_subject_flashcards')` juste après le `@router.post` homonyme), pas des
endpoints de découverte. ⇒ **Aucun endpoint IFFD ne liste les routes ou modèles disponibles** — grep
négatif montré (résultat vide sur le motif catalogue/liste/available/models/routes).

## 5. Référence de gouvernance côté Lex

### 5.1 Gate 403 UPGRADE_REQUIRED (backend/app/api/v1/chat/routes.py)

- `_EFFORT_ORDER = {"concis": 0, "standard": 1, "detaille": 2}` (ligne 555).
- Dans `POST /` (`chat`, décoré ligne 593, dépend de `get_user_with_subscription`) :
  ```
  requested_order = _EFFORT_ORDER.get(body.workflow_effort.value, 0)   # ligne 605
  allowed_order = _EFFORT_ORDER.get(user.max_effort, 0)                 # ligne 606
  if requested_order > allowed_order:                                  # ligne 607
      raise HTTPException(403, {"code": "UPGRADE_REQUIRED", ...})       # lignes 608-613
  ```
  → comparaison d'un **ordre d'effort demandé** contre un **plafond attaché à l'utilisateur**
  (`user.max_effort`, dérivé de son abonnement via `get_user_with_subscription`), AVANT tout appel
  LLM/persistance. C'est un vrai **gate d'accès par plan**, contrairement à IFFD.
- Le gate est suivi (lignes ~630-670) d'un **décompte de quota volumétrique en crédits d'effort**
  (`chat_quota_service.check_and_consume`, avec `tier=user.subscription_tier`), puis d'une réserve
  prépayée en fallback (`prepaid_service`) — double couche plan+quota, absente d'IFFD.
- `ai_router_svc.get_router(body.workflow_effort.value)` (ligne 1942, guardé par `getattr(...,
  None)` ligne 1933) résout le **router IA actif pour l'effort** APRÈS le gate d'accès — la
  gouvernance (autorisation) et la résolution du modèle par défaut sont deux étapes distinctes et
  ordonnées.

### 5.2 `AiRouterService` (backend/app/services/ai_router_service.py) — le vrai préréglage de routeur IA

(`backend/app/services/agents/sandbox/presets.py` est une fausse piste : ce sont des **presets de
consolidation arithmétique de sandbox** — FR115, story 98.2 — sans rapport avec le routage IA ; à
signaler pour éviter toute confusion future.)

Le composant pertinent est `AiRouterService` :
- Clé de résolution `f"ai_router:{workflow_effort}"` (ligne 21) — **gouvernance PAR TÂCHE
  (workflow_effort)**, pas par route brute.
- `get_router(workflow_effort)` (lignes 71-104) : **cascade Redis (TTL 300s, ligne 16) → Firestore
  (collection `ai_routers`, filtre `workflow_effort` + `is_active`, lignes 106-124) → fallback
  hardcodé `get_default_router(workflow_effort)`** (ligne 104, importé de `app.models.ai_router`).
  C'est le patron "catalogue récupérable depuis le backend, avec repli local" que la décision owner
  demande au socle.
- CRUD complet avec invalidation ciblée du cache : `create_router` (174-189), `update_router`
  (191-244, avec garde métier "impossible de désactiver le seul router actif pour un effort",
  lignes 208-222), `delete_router` (246-278, même garde symétrique lignes 262-274),
  `invalidate_cache` (284-295, par effort ou global).
- `get_all_routers()` (130-156) — **listing sans cache pour l'interface admin**, trié par
  `_EFFORT_ORDER` local (dupliqué, lignes 134-138).
- Exposé côté API par `backend/app/api/v1/admin_bridge/ai_routers.py` (routes confirmées par grep) :
  `GET list_ai_routers` (123-129), `GET get_ai_router` par id (138-144), `POST invalidate_cache`
  (166-177), `POST create_ai_router` (222-235), `PUT update_ai_router` (257-269), `DELETE
  delete_ai_router` (301-313). **C'est le catalogue récupérable depuis le backend** que IFFD n'a pas
  (§4) — Lex expose déjà, côté admin, exactement la primitive que la décision owner demande au socle
  zcrud pour le mode "une route par tâche".

## 6. Synthèse contraste (pour le socle zcrud)

| Aspect | IFFD (v1/v2/v3) | Lex |
|---|---|---|
| Dispatch route | fonction Python dédiée par tâche, décorateurs statiques — pas de registre dynamique | endpoint unique `/`, corps riche (`workflow_effort`, `transform`, …) |
| Modèle par tâche | `aiModel`/`aiProvider` du CLIENT + repli serveur par FOURNISSEUR (préfixage), aucun contrôle d'accès | `AiRouterService.get_router(workflow_effort)` — Redis→Firestore→fallback, backend fait autorité |
| Gouvernance plan/quota | **absente** (grep négatif §3) | gate 403 `UPGRADE_REQUIRED` (`user.max_effort` vs effort demandé) + quota volumétrique + réserve prépayée |
| Catalogue exposé | **absent** (grep négatif §4) | CRUD + listing admin complet (`admin_bridge/ai_routers.py`) sur `ai_routers` Firestore |

Conséquence pour le socle : le mode "route par tâche" que zcrud doit porter doit, pour égaler la
gouvernance Lex (et dépasser IFFD), séparer clairement (a) le **dispatch par route/tâche**
(patron IFFD, une route par intention), (b) la **résolution du modèle par défaut + callbacks par
tâche déclarés par l'app** (patron `AiRouterService`, catalogue Firestore + cache + fallback), et (c)
un **gate d'accès par plan** attaché à la route/tâche (patron `_EFFORT_ORDER`/`user.max_effort`),
qu'IFFD n'a jamais eu besoin d'exprimer et que Lex porte au niveau HTTP, pas au niveau du routeur IA
lui-même.
