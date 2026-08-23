/// Catalogue en cascade — `ZChatCascadeRouteCatalog` (invariants AD-5,
/// AD-10, AD-11).
///
/// Le catalogue que consomme une session de chat, assemblé depuis des
/// **sources** ordonnées : backend caché, dépôt local, liste embarquée…
/// Chaque identité est cherchée de la première source à la dernière ; la
/// première qui **connaît** le routeur répond.
///
/// ## Ce qui est un échec, ce qui ne l'est pas
///
/// - `Right(null)` d'une source — « absent ici » — passe à la suivante.
/// - Un `Left` **distant** (panne de backend, corps illisible) est journalisé
///   et passe à la suivante : une source en panne ne cache pas celles qui
///   suivent.
/// - Un `Left(ZCacheFailure)` — le **store local** est cassé — est repropagé
///   tel quel : c'est une panne de l'appareil, pas du réseau.
/// - Toutes les sources épuisées : `Right(repli)` si l'hôte a **déclaré** un
///   repli, sinon `Left(ZNotFoundFailure)`. Le socle n'invente jamais de
///   routeur.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_route_catalog_port.dart';
import '../z_chat_router.dart';
import 'z_chat_route_catalog_source.dart';
import 'z_chat_ttl_route_catalog.dart';

/// Fabrique le routeur de **repli** d'un hôte pour une identité épuisée.
typedef ZChatRouteFallbackBuilder = ZChatRouter Function(String id);

/// Catalogue assemblé depuis des sources ordonnées.
class ZChatCascadeRouteCatalog implements ZChatRouteCatalogPort {
  /// Construit la cascade. [fallback], s'il est déclaré, rend le routeur
  /// servi quand aucune source ne connaît l'identité.
  ZChatCascadeRouteCatalog({
    required List<ZChatRouteCatalogSource> sources,
    this.fallback,
    this.log,
  }) : sources = List<ZChatRouteCatalogSource>.unmodifiable(sources);

  /// Les sources, dans l'ordre d'interrogation.
  final List<ZChatRouteCatalogSource> sources;

  /// Repli déclaré par l'hôte, ou `null` (identité inconnue ⇒ `Left`).
  final ZChatRouteFallbackBuilder? fallback;

  /// Journal optionnel (source sautée sur panne).
  final ZChatCatalogLog? log;

  @override
  Future<ZResult<ZChatRouter>> resolveRouter(String id) async {
    for (final ZChatRouteCatalogSource source in sources) {
      final ZResult<ZChatRouter?> result = await source.fetchRouter(id);
      final ZFailure? failure = result.fold(
        (ZFailure f) => f,
        (ZChatRouter? _) => null,
      );
      if (failure != null) {
        if (failure is ZCacheFailure) {
          return Left<ZFailure, ZChatRouter>(failure);
        }
        log?.call('route catalog: source skipped for $id', cause: failure);
        continue;
      }
      final ZChatRouter? router = result.getOrElse(() => null);
      if (router != null) return Right<ZFailure, ZChatRouter>(router);
    }
    final ZChatRouteFallbackBuilder? build = fallback;
    if (build != null) return Right<ZFailure, ZChatRouter>(build(id));
    return Left<ZFailure, ZChatRouter>(
      ZNotFoundFailure('router not found', id: id, entity: kZChatRouterKind),
    );
  }

  /// La liste de la **première** source qui en rend une non vide ; une liste
  /// vide sinon. Le repli n'est **jamais** listé : il n'existe que pour une
  /// identité demandée.
  @override
  Future<ZResult<List<ZChatRouter>>> listRouters() async {
    for (final ZChatRouteCatalogSource source in sources) {
      final ZResult<List<ZChatRouter>> result = await source.fetchAll();
      final ZFailure? failure = result.fold(
        (ZFailure f) => f,
        (List<ZChatRouter> _) => null,
      );
      if (failure != null) {
        if (failure is ZCacheFailure) {
          return Left<ZFailure, List<ZChatRouter>>(failure);
        }
        log?.call('route catalog: source skipped for list', cause: failure);
        continue;
      }
      final List<ZChatRouter> list = result.getOrElse(() => const []);
      if (list.isNotEmpty) {
        return Right<ZFailure, List<ZChatRouter>>(
          List<ZChatRouter>.unmodifiable(list),
        );
      }
    }
    return const Right<ZFailure, List<ZChatRouter>>(<ZChatRouter>[]);
  }

  /// Propage l'invalidation à chaque source **cachée**
  /// (`ZChatTtlRouteCatalog`) ; les autres n'ont rien à oublier.
  @override
  Future<void> invalidate([String? id]) async {
    for (final ZChatRouteCatalogSource source in sources) {
      if (source is ZChatTtlRouteCatalog) await source.invalidate(id);
    }
  }
}
