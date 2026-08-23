/// Source de routeurs — `ZChatRouteCatalogSource` (invariants AD-5, AD-10,
/// AD-11).
///
/// Une **source** est un endroit où des routeurs peuvent se trouver : un
/// backend, un dépôt local, une liste statique. Elle se distingue du port de
/// catalogue (`ZChatRouteCatalogPort`) par son contrat de **non-trouvé** : une
/// source répond `Right(null)` quand elle ne connaît pas l'identité demandée,
/// et réserve le `Left` aux **pannes**. C'est ce qui permet de les enchaîner
/// en cascade (`ZChatCascadeRouteCatalog`) : « absent ici » n'est pas une
/// erreur, c'est l'invitation à interroger la source suivante.
///
/// Une source ne rend que des routeurs **actifs** : un routeur inactif est
/// « absent » pour elle.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_router.dart';

/// Journal **optionnel** des sources et du cache : reçoit un [message]
/// technique et, le cas échéant, la [cause] (échec typé ou exception).
///
/// Le socle n'imprime jamais rien : sans journal, les pannes absorbées
/// (source sautée, entrée périmée servie) sont silencieuses.
typedef ZChatCatalogLog = void Function(String message, {Object? cause});

/// Une source de routeurs, enchaînable en cascade.
abstract interface class ZChatRouteCatalogSource {
  /// Le routeur **actif** d'identité [id] s'il est connu ici, `Right(null)`
  /// sinon (absent **ou** inactif). Un `Left` signale une **panne**, jamais
  /// une absence.
  Future<ZResult<ZChatRouter?>> fetchRouter(String id);

  /// Tous les routeurs **actifs** connus ici (liste vide si aucun).
  Future<ZResult<List<ZChatRouter>>> fetchAll();
}

/// Source **statique** : une liste figée de routeurs, typiquement le repli
/// embarqué d'un hôte ou le jeu d'un test.
///
/// Les routeurs éphémères (sans `id`) sont ignorés ; deux routeurs de même
/// identité : le dernier gagne. Les inactifs sont conservés mais jamais
/// rendus.
class ZChatStaticRouteCatalogSource implements ZChatRouteCatalogSource {
  /// Construit la source depuis [routers].
  ZChatStaticRouteCatalogSource(Iterable<ZChatRouter> routers)
    : _routers = Map<String, ZChatRouter>.unmodifiable(<String, ZChatRouter>{
        for (final ZChatRouter r in routers)
          if (r.id != null) r.id!: r,
      });

  final Map<String, ZChatRouter> _routers;

  /// Identités portées, actives ou non, dans l'ordre d'insertion.
  List<String> get ids => List<String>.unmodifiable(_routers.keys);

  @override
  Future<ZResult<ZChatRouter?>> fetchRouter(String id) async {
    final ZChatRouter? router = _routers[id];
    return Right<ZFailure, ZChatRouter?>(
      router == null || !router.isActive ? null : router,
    );
  }

  @override
  Future<ZResult<List<ZChatRouter>>> fetchAll() async =>
      Right<ZFailure, List<ZChatRouter>>(
        List<ZChatRouter>.unmodifiable(<ZChatRouter>[
          for (final ZChatRouter r in _routers.values)
            if (r.isActive) r,
        ]),
      );
}
