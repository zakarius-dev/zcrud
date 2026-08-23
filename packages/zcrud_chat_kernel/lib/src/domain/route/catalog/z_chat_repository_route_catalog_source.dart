/// Source de routeurs adossée à un **dépôt** —
/// `ZChatRepositoryRouteCatalogSource` (invariants AD-5, AD-11).
///
/// Tout `ZReadOnlyRepository<ZChatRouter>` — adaptateur distant, store local
/// hors-ligne, dépôt mémoire — devient une source de catalogue sans une ligne
/// d'adaptation : la source traduit le contrat du dépôt (`Left(ZNotFoundFailure)`
/// pour un absent) vers celui des sources (`Right(null)`), et ne laisse passer
/// que les routeurs actifs.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_router.dart';
import 'z_chat_route_catalog_source.dart';

/// Source lisant un dépôt de routeurs.
class ZChatRepositoryRouteCatalogSource implements ZChatRouteCatalogSource {
  /// Construit la source au-dessus de [repository].
  const ZChatRepositoryRouteCatalogSource(this.repository);

  /// Le dépôt lu — jamais écrit.
  final ZReadOnlyRepository<ZChatRouter> repository;

  /// Clé persistée du drapeau d'activation, telle que filtrée côté source.
  static const String _isActiveKey = 'is_active';

  /// `Right(routeur)` s'il existe et est actif ; `Right(null)` s'il est
  /// absent, soft-deleted (`ZNotFoundFailure` du dépôt) ou inactif ; tout
  /// autre `Left` du dépôt est **repropagé** tel quel.
  @override
  Future<ZResult<ZChatRouter?>> fetchRouter(String id) async {
    final ZResult<ZChatRouter> result = await repository.getById(id);
    return result.fold(
      (ZFailure f) => f is ZNotFoundFailure
          ? const Right<ZFailure, ZChatRouter?>(null)
          : Left<ZFailure, ZChatRouter?>(f),
      (ZChatRouter r) => Right<ZFailure, ZChatRouter?>(r.isActive ? r : null),
    );
  }

  /// Les routeurs actifs du dépôt. Le filtre d'activation est demandé à la
  /// source **et** réappliqué en mémoire : un dépôt qui ignore les filtres ne
  /// laisse donc jamais passer un inactif.
  @override
  Future<ZResult<List<ZChatRouter>>> fetchAll() async {
    final ZResult<List<ZChatRouter>> result = await repository.getAll(
      request: const ZDataRequest(
        filters: <ZFilter>[ZFilter(_isActiveKey, ZFilterOp.eq, true)],
      ),
    );
    return result.map(
      (List<ZChatRouter> all) => List<ZChatRouter>.unmodifiable(<ZChatRouter>[
        for (final ZChatRouter r in all)
          if (r.isActive) r,
      ]),
    );
  }
}
