/// Dépôt de routeurs qui **invalide le catalogue** après chaque écriture —
/// `ZChatInvalidatingRouterRepository` (invariants AD-5, AD-11).
///
/// Quand un hôte administre ses routeurs (écran CRUD) **et** les consomme par
/// un catalogue caché, une écriture doit se voir sans attendre l'expiration
/// du cache. Ce décorateur enveloppe n'importe quel `ZRepository<ZChatRouter>`
/// et, après un `save`, un `softDelete` ou un `restore` **réussis**, invalide
/// l'identité écrite sur le `ZChatRouteCatalogPort` déclaré. Une écriture en
/// échec n'invalide rien. Les lectures passent telles quelles.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_route_catalog_port.dart';
import '../z_chat_router.dart';

/// Décorateur d'invalidation d'un dépôt de routeurs.
///
/// Sa capacité de recherche est celle de [inner] : si [inner] délègue la
/// recherche (`ZDelegatesSearch`), le décorateur la délègue aussi.
class ZChatInvalidatingRouterRepository implements ZRepository<ZChatRouter> {
  /// Enveloppe [inner] ; chaque écriture réussie invalide [catalog].
  factory ZChatInvalidatingRouterRepository(
    ZRepository<ZChatRouter> inner,
    ZChatRouteCatalogPort catalog,
  ) => inner is ZDelegatesSearch
      ? _Delegating(inner, catalog)
      : ZChatInvalidatingRouterRepository._(inner, catalog);

  ZChatInvalidatingRouterRepository._(this.inner, this.catalog);

  /// Le dépôt enveloppé.
  final ZRepository<ZChatRouter> inner;

  /// Le catalogue invalidé après écriture.
  final ZChatRouteCatalogPort catalog;

  @override
  Stream<List<ZChatRouter>> watchAll() => inner.watchAll();

  @override
  Stream<List<ZChatRouter>> watch(ZDataRequest request) => inner.watch(request);

  @override
  Future<ZResult<List<ZChatRouter>>> getAll({ZDataRequest? request}) =>
      inner.getAll(request: request);

  @override
  Future<ZResult<ZChatRouter>> getById(String id) => inner.getById(id);

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) =>
      inner.count(request: request);

  @override
  Future<ZResult<ZChatRouter>> save(
    ZChatRouter item, {
    String? collectionId,
  }) async {
    final ZResult<ZChatRouter> result = await inner.save(
      item,
      collectionId: collectionId,
    );
    final ZChatRouter? saved = result.fold(
      (ZFailure _) => null,
      (ZChatRouter r) => r,
    );
    if (saved != null) await catalog.invalidate(saved.id);
    return result;
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    final ZResult<Unit> result = await inner.softDelete(id);
    if (result.isRight()) await catalog.invalidate(id);
    return result;
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    final ZResult<Unit> result = await inner.restore(id);
    if (result.isRight()) await catalog.invalidate(id);
    return result;
  }

  @override
  void dispose() => inner.dispose();
}

/// Variante portant `ZDelegatesSearch`, rendue quand [inner] la porte.
class _Delegating extends ZChatInvalidatingRouterRepository
    with ZDelegatesSearch<ZChatRouter> {
  _Delegating(super.inner, super.catalog) : super._();
}
