/// La **session de routage** — `ZChatRouteSession`.
///
/// ## Ce qu'elle tient
///
/// Une session est possédée par l'hôte (créée hors de `build`, libérée par
/// [ZChatRouteSession.dispose]) et partagée par toutes les surfaces de
/// conversation : le routeur **choisi**, tel que le catalogue le rend, les
/// **choix de repli** par tâche, et l'échec du catalogue. Elle publie ces
/// états en tranches `ValueListenable` indépendantes (invariant AD-2) :
///
/// | Tranche | Change quand |
/// |---|---|
/// | [routerId] | l'hôte ou l'utilisateur choisit un autre routeur |
/// | [router] | le catalogue rend un routeur **différent** |
/// | [routeOf] | **cette route-là** change (`==`), jamais les autres |
/// | [overrideOf] | le repli choisi pour **cette tâche-là** change |
/// | [catalogFailure] | le catalogue répond `Left`, puis `Right` |
///
/// Le canal global de `ChangeNotifier` signale un changement de **structure**
/// (routeur remplacé, repli posé ou retiré) : c'est lui qu'une projection de
/// feuille écoute.
///
/// ## Ce qu'elle ne fait pas
///
/// Elle n'**envoie rien**. [resolve] et [resolveArtifact] sont des fonctions
/// **pures** : elles rendent la requête routée, ou le refus typé, et c'est le
/// contrôleur de conversation qui décide, avant tout message optimiste et
/// tout appel de port. La répartition vers un port appartient aux ports
/// routés ; le transport au port de l'hôte.
///
/// ## Règles de résolution
///
/// - aucun routeur chargé ⇒ `Left(ZDomainFailure)` — le socle ne fabrique
///   jamais un modèle ;
/// - route non déclarée **et** racine vide ⇒ `Left(ZDomainFailure)` ;
/// - le gate refuse ⇒ son `Left`, rendu tel quel ;
/// - un repli choisi pour la tâche ([setModelOverride]) prime le modèle de
///   la route ; un modèle déjà nommé par la requête prime tout ;
/// - le budget de calcul déjà porté par la requête prime celui de la route ;
/// - les paramètres de la route rejoignent `extra`, **sous** ceux de l'hôte.
///
/// Le gate **refuse** par défaut : déclarer un catalogue sans gate, c'est
/// refuser toute route tant que la gouvernance n'est pas branchée.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Clé d'`extra` sous laquelle une requête d'artefact transporte le
/// **fournisseur** résolu par la route, verbatim (`ZChatModelRef.providerId`).
/// Une valeur déjà présente sous cette clé chez l'hôte prime.
const String kZChatArtifactProviderIdKey = 'provider_id';

/// Clé de tâche d'une requête de conversation : le `kind` de son style.
String zChatTaskKeyOf(ZChatGenerationRequest request) => request.style.kind;

/// Clé de tâche d'une requête d'artefact : le `kind` de son style, sinon la
/// clé de l'artefact.
String zChatArtifactTaskKeyOf(ZChatArtifactGenerationRequest request) =>
    request.style?.kind ?? request.artifactKey;

/// Projette une route sur une requête de conversation — **fonction pure**.
///
/// Rend la requête routée, ou un refus typé (voir les règles de résolution
/// de [ZChatRouteSession]). [override] est le repli choisi pour la tâche ;
/// il prime le modèle de la route, jamais un modèle déjà nommé par [request].
ZResult<ZChatGenerationRequest> zChatApplyRoute({
  required ZChatRouter? router,
  required ZChatRouteGate gate,
  required ZChatGenerationRequest request,
  ZChatModelRef? override,
}) {
  final String taskKey = zChatTaskKeyOf(request);
  final ZResult<ZChatRouteResolution> resolved = _resolution(
    router: router,
    gate: gate,
    taskKey: taskKey,
  );
  return resolved.map((ZChatRouteResolution res) {
    final ZChatGenerationRequest base = request.modelId != null
        ? request
        : _withModel(request, override);
    // Le budget déjà porté par la requête est un choix de l'appelant
    // (réglage de la feuille ou builder de l'hôte) : il prime la route.
    // `toRequest` n'applique la route qu'en repli quand `settings` le dit ;
    // on lui repasse donc les réglages de la requête elle-même.
    return res.toRequest(base, settings: _settingsOf(base));
  });
}

/// Projette une route sur une requête d'artefact — **fonction pure**.
///
/// Même règles que [zChatApplyRoute] ; la requête d'artefact n'ayant ni
/// fournisseur ni budget typés, le fournisseur résolu rejoint `extra` sous
/// [kZChatArtifactProviderIdKey] et les paramètres de la route s'y placent
/// **sous** ceux de l'hôte.
ZResult<ZChatArtifactGenerationRequest> zChatApplyArtifactRoute({
  required ZChatRouter? router,
  required ZChatRouteGate gate,
  required ZChatArtifactGenerationRequest request,
  ZChatModelRef? override,
}) {
  final String taskKey = zChatArtifactTaskKeyOf(request);
  final ZResult<ZChatRouteResolution> resolved = _resolution(
    router: router,
    gate: gate,
    taskKey: taskKey,
  );
  return resolved.map((ZChatRouteResolution res) {
    final bool explicitModel = request.modelId != null;
    final ZChatModelRef? chosen = explicitModel
        ? null
        : (override ?? res.model);
    final Map<String, dynamic> extra = <String, dynamic>{
      ...res.params,
      if (chosen?.providerId != null)
        kZChatArtifactProviderIdKey: chosen!.providerId,
      ...request.extra,
    };
    return request.copyWith(
      modelId: explicitModel ? request.modelId : chosen?.modelId,
      extra: extra,
    );
  });
}

ZResult<ZChatRouteResolution> _resolution({
  required ZChatRouter? router,
  required ZChatRouteGate gate,
  required String taskKey,
}) {
  if (router == null) {
    return Left<ZFailure, ZChatRouteResolution>(
      ZDomainFailure('chat route: no router is loaded for task $taskKey'),
    );
  }
  final ZChatRouteResolution res = ZChatRouteResolution.from(router, taskKey);
  if (!res.declared && res.isEmpty) {
    return Left<ZFailure, ZChatRouteResolution>(
      ZDomainFailure(
        'chat route: task $taskKey is not declared on router ${router.id}',
      ),
    );
  }
  final ZResult<Unit> allowed = gate.canRoute(
    taskKey,
    tier: res.tier,
    requiredAccessTokens: res.requiredAccessTokens,
  );
  return allowed.map((Unit _) => res);
}

ZChatGenerationSettings _settingsOf(ZChatGenerationRequest r) =>
    ZChatGenerationSettings(
      responseLength: r.responseLength,
      lengthBias: r.lengthBias,
      computeEffort: r.computeEffort,
      revealThinkingSteps: r.revealThinkingSteps,
      webSearch: r.webSearch,
      capabilities: r.capabilities,
    );

ZChatGenerationRequest _withModel(
  ZChatGenerationRequest r,
  ZChatModelRef? model,
) {
  if (model == null) return r;
  return ZChatGenerationRequest(
    style: r.style,
    subject: r.subject,
    notes: r.notes,
    conversationId: r.conversationId,
    sourceMessageId: r.sourceMessageId,
    context: r.context,
    attachmentIds: r.attachmentIds,
    responseLength: r.responseLength,
    lengthBias: r.lengthBias,
    computeEffort: r.computeEffort,
    revealThinkingSteps: r.revealThinkingSteps,
    webSearch: r.webSearch,
    capabilities: r.capabilities,
    corpusScope: r.corpusScope,
    languageTag: r.languageTag,
    instructions: r.instructions,
    modelId: model.modelId,
    providerId: model.providerId,
    extra: r.extra,
  );
}

/// L'état réactif du routage d'une application : routeur choisi, replis par
/// tâche, résolution pure.
class ZChatRouteSession extends ChangeNotifier {
  /// Construit une session sur [catalog].
  ///
  /// [gate] gouverne les routes ; son défaut **refuse** tout. [initialRouterId]
  /// est chargé immédiatement (le résultat arrive sur [router] ou sur
  /// [catalogFailure]).
  ZChatRouteSession({
    required ZChatRouteCatalogPort catalog,
    ZChatRouteGate gate = const ZDenyAllChatRouteGate(),
    String? initialRouterId,
    // Les formels privés sont interdits en Dart ; rendre ces champs publics
    // élargirait la surface de la session. Même arbitrage que le contrôleur.
    // ignore: prefer_initializing_formals
  }) : _catalog = catalog,
       // ignore: prefer_initializing_formals
       _gate = gate,
       _routerId = ValueNotifier<String?>(initialRouterId) {
    if (initialRouterId != null) unawaited(_load(initialRouterId));
  }

  final ZChatRouteCatalogPort _catalog;
  final ZChatRouteGate _gate;

  final ValueNotifier<String?> _routerId;
  final ValueNotifier<ZChatRouter?> _router = ValueNotifier<ZChatRouter?>(null);
  final ValueNotifier<ZFailure?> _catalogFailure = ValueNotifier<ZFailure?>(
    null,
  );
  final Map<String, ValueNotifier<ZChatRouteSpec?>> _routes =
      <String, ValueNotifier<ZChatRouteSpec?>>{};
  final Map<String, ValueNotifier<ZChatModelRef?>> _overrides =
      <String, ValueNotifier<ZChatModelRef?>>{};

  /// Numéro de la dernière demande au catalogue : seule la plus récente
  /// publie — deux sélections rapprochées ne se dépassent jamais.
  int _generation = 0;
  bool _disposed = false;

  // ── Tranches ──────────────────────────────────────────────────────────────

  /// Identité du routeur **choisi**, ou `null`. Change dès la sélection,
  /// avant la réponse du catalogue.
  ValueListenable<String?> get routerId => _routerId;

  /// Le routeur **chargé**, ou `null` (aucun choix, ou catalogue en échec).
  ValueListenable<ZChatRouter?> get router => _router;

  /// Dernier échec du catalogue, ou `null` après une résolution réussie.
  ValueListenable<ZFailure?> get catalogFailure => _catalogFailure;

  /// La route déclarée pour [taskKey] sur le routeur chargé, ou `null` —
  /// **instance stable** par clé, qui ne signale que si cette route change.
  ValueListenable<ZChatRouteSpec?> routeOf(String taskKey) =>
      _routes.putIfAbsent(
        taskKey,
        () => ValueNotifier<ZChatRouteSpec?>(_router.value?.routeOf(taskKey)),
      );

  /// Le repli choisi pour [taskKey], ou `null` (le modèle de la route) —
  /// instance stable par clé.
  ValueListenable<ZChatModelRef?> overrideOf(String taskKey) =>
      _overrideOf(taskKey);

  // ── Écriture ──────────────────────────────────────────────────────────────

  /// Choisit le routeur [id] : [routerId] change immédiatement, [router] et
  /// les [routeOf] concernées quand le catalogue a répondu. Un `Left` du
  /// catalogue va dans [catalogFailure] et **retire** le routeur chargé —
  /// une identité choisie et un routeur différent ne coexistent jamais.
  Future<void> selectRouter(String id) {
    _routerId.value = id;
    return _load(id);
  }

  /// Recharge le routeur choisi après invalidation du catalogue. Sans choix,
  /// sans effet.
  Future<void> refresh() async {
    final String? id = _routerId.value;
    if (id == null) return;
    try {
      await _catalog.invalidate(id);
    } catch (_) {
      // Un catalogue sans invalidation ne doit pas empêcher le rechargement.
    }
    await _load(id);
  }

  /// Pose ([ref]) ou retire (`null`) le repli choisi pour [taskKey]. Seule la
  /// tranche [overrideOf] de cette tâche signale, puis le canal global.
  void setModelOverride(String taskKey, ZChatModelRef? ref) {
    final ValueNotifier<ZChatModelRef?> slot = _overrideOf(taskKey);
    if (slot.value == ref) return;
    slot.value = ref;
    notifyListeners();
  }

  // ── Résolution PURE ───────────────────────────────────────────────────────

  /// Rend [request] routée par le routeur chargé, ou le refus typé. Ne lève
  /// jamais, n'envoie rien.
  ZResult<ZChatGenerationRequest> resolve(ZChatGenerationRequest request) =>
      zChatApplyRoute(
        router: _router.value,
        gate: _gate,
        request: request,
        override: _overrides[zChatTaskKeyOf(request)]?.value,
      );

  /// Rend [request] routée, ou le refus typé — pendant de [resolve] pour les
  /// artefacts.
  ZResult<ZChatArtifactGenerationRequest> resolveArtifact(
    ZChatArtifactGenerationRequest request,
  ) => zChatApplyArtifactRoute(
    router: _router.value,
    gate: _gate,
    request: request,
    override: _overrides[zChatArtifactTaskKeyOf(request)]?.value,
  );

  // ── Interne ───────────────────────────────────────────────────────────────

  ValueNotifier<ZChatModelRef?> _overrideOf(String taskKey) => _overrides
      .putIfAbsent(taskKey, () => ValueNotifier<ZChatModelRef?>(null));

  Future<void> _load(String id) async {
    final int mine = ++_generation;
    ZResult<ZChatRouter> outcome;
    try {
      outcome = await _catalog.resolveRouter(id);
    } catch (error) {
      // Un catalogue qui lève est un catalogue en échec (AD-10) — jamais une
      // exception qui remonte jusqu'à un geste d'interface.
      outcome = Left<ZFailure, ZChatRouter>(
        ZDomainFailure('route catalog threw ${error.runtimeType}'),
      );
    }
    if (_disposed || mine != _generation) return;
    outcome.fold(
      (ZFailure f) {
        _catalogFailure.value = f;
        _publishRouter(null);
      },
      (ZChatRouter r) {
        _catalogFailure.value = null;
        _publishRouter(r);
      },
    );
  }

  void _publishRouter(ZChatRouter? next) {
    if (identical(_router.value, next)) return;
    _router.value = next;
    // Seules les routes qui CHANGENT signalent : une tranche écoutée par une
    // tuile de la feuille ne se reconstruit pas parce qu'une autre route a
    // bougé.
    for (final MapEntry<String, ValueNotifier<ZChatRouteSpec?>> e
        in _routes.entries) {
      final ZChatRouteSpec? spec = next?.routeOf(e.key);
      if (e.value.value == spec) continue;
      e.value.value = spec;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _routerId.dispose();
    _router.dispose();
    _catalogFailure.dispose();
    for (final ValueNotifier<ZChatRouteSpec?> n in _routes.values) {
      n.dispose();
    }
    _routes.clear();
    for (final ValueNotifier<ZChatModelRef?> n in _overrides.values) {
      n.dispose();
    }
    _overrides.clear();
    super.dispose();
  }
}
