/// Catalogue de routeurs — `ZChatRouteCatalogPort` (invariants AD-5, AD-10,
/// AD-11).
///
/// Le catalogue est la **source** des routeurs : un hôte le branche sur son
/// backend, son dépôt local ou une liste statique. Le socle n'en fournit que
/// deux implémentations : un catalogue **inerte** (aucun routeur, refus typé)
/// et un catalogue **mémoire** immuable.
///
/// Un routeur **inactif** n'existe pas pour le catalogue : il n'est ni listé
/// ni résolu. Le socle n'invente jamais de routeur par défaut — un identifiant
/// inconnu est un `ZNotFoundFailure`, que l'hôte décide de replier ou non.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_router.dart';

/// Port de lecture des routeurs.
abstract interface class ZChatRouteCatalogPort {
  /// Le routeur **actif** d'identité [id], ou un `Left` typé
  /// (`ZNotFoundFailure` si absent ou inactif).
  Future<ZResult<ZChatRouter>> resolveRouter(String id);

  /// Tous les routeurs **actifs** (liste vide si aucun).
  Future<ZResult<List<ZChatRouter>>> listRouters();

  /// Invalide une entrée ([id]) ou tout le catalogue (`null`) — sans effet
  /// sur une implémentation sans cache.
  Future<void> invalidate([String? id]);
}

/// Catalogue **inerte** : aucun routeur, refus typé
/// (`ZUnsupportedOperationFailure`, opération `resolveRouter`).
class ZChatInertRouteCatalog implements ZChatRouteCatalogPort {
  /// Construit le catalogue inerte.
  const ZChatInertRouteCatalog();

  @override
  Future<ZResult<ZChatRouter>> resolveRouter(String id) async =>
      const Left<ZFailure, ZChatRouter>(
        ZUnsupportedOperationFailure(
          'route catalog not configured',
          operation: 'resolveRouter',
        ),
      );

  @override
  Future<ZResult<List<ZChatRouter>>> listRouters() async =>
      const Right<ZFailure, List<ZChatRouter>>(<ZChatRouter>[]);

  @override
  Future<void> invalidate([String? id]) async {}
}

/// Catalogue **mémoire**, immuable : une valeur, jamais un état.
///
/// Les routeurs **éphémères** (sans `id`) sont ignorés ; deux routeurs de
/// même identité : le dernier gagne. [withRouter] et [without] rendent un
/// **nouveau** catalogue.
class ZChatInMemoryRouteCatalog implements ZChatRouteCatalogPort {
  /// Construit un catalogue depuis [routers].
  ZChatInMemoryRouteCatalog(Iterable<ZChatRouter> routers)
    : _routers = Map<String, ZChatRouter>.unmodifiable(<String, ZChatRouter>{
        for (final ZChatRouter r in routers)
          if (r.id != null) r.id!: r,
      });

  final Map<String, ZChatRouter> _routers;

  /// Identités portées, actives ou non, dans l'ordre d'insertion.
  List<String> get ids => List<String>.unmodifiable(_routers.keys);

  /// Nouveau catalogue où [router] remplace (ou ajoute) son identité ; un
  /// routeur éphémère rend le catalogue **inchangé**.
  ZChatInMemoryRouteCatalog withRouter(ZChatRouter router) {
    if (router.id == null) return this;
    return ZChatInMemoryRouteCatalog(<ZChatRouter>[
      for (final ZChatRouter r in _routers.values)
        if (r.id != router.id) r,
      router,
    ]);
  }

  /// Nouveau catalogue sans l'identité [id].
  ZChatInMemoryRouteCatalog without(String id) =>
      ZChatInMemoryRouteCatalog(<ZChatRouter>[
        for (final ZChatRouter r in _routers.values)
          if (r.id != id) r,
      ]);

  @override
  Future<ZResult<ZChatRouter>> resolveRouter(String id) async {
    final ZChatRouter? router = _routers[id];
    if (router == null || !router.isActive) {
      return Left<ZFailure, ZChatRouter>(
        ZNotFoundFailure('router not found', id: id, entity: kZChatRouterKind),
      );
    }
    return Right<ZFailure, ZChatRouter>(router);
  }

  @override
  Future<ZResult<List<ZChatRouter>>> listRouters() async =>
      Right<ZFailure, List<ZChatRouter>>(
        List<ZChatRouter>.unmodifiable(<ZChatRouter>[
          for (final ZChatRouter r in _routers.values)
            if (r.isActive) r,
        ]),
      );

  @override
  Future<void> invalidate([String? id]) async {}
}
