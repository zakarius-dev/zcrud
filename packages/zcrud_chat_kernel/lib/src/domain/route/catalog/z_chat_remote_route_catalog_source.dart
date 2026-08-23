/// Source de routeurs **distante**, sans bibliothèque HTTP —
/// `ZChatRemoteRouteCatalogSource` (invariants AD-5, AD-10, AD-11).
///
/// Le socle ne fait aucune requête : l'hôte fournit un **ouvreur**
/// ([ZChatRouteCatalogOpener]) qui, pour une [ZChatRouteCatalogQuery], rend le
/// **corps texte** de la réponse — URL, authentification et en-têtes restent
/// chez lui. La source décode ce corps (JSON) avec un
/// `ZChatRouteCatalogDecoder`, dont la forme traduit le dialecte du backend.
library;

import 'dart:convert';

import 'package:zcrud_core/domain.dart';

import '../z_chat_router.dart';
import 'z_chat_route_catalog_decoder.dart';
import 'z_chat_route_catalog_source.dart';

/// Ce que la source demande à l'ouvreur : un routeur ([id]) ou tous
/// (`id == null`).
class ZChatRouteCatalogQuery {
  /// Construit la requête.
  const ZChatRouteCatalogQuery({this.id});

  /// Identité demandée, ou `null` pour la liste entière.
  final String? id;

  /// `true` si la liste entière est demandée.
  bool get isList => id == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatRouteCatalogQuery && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ZChatRouteCatalogQuery(id: $id)';
}

/// Ouvre la lecture d'un catalogue, telle que l'hôte sait le faire, et rend
/// le **corps texte** de la réponse (JSON). Une chaîne vide signifie « rien
/// ici » ; une exception signifie une **panne**.
typedef ZChatRouteCatalogOpener =
    Future<String> Function(ZChatRouteCatalogQuery query);

/// Source lisant un backend par l'ouvreur de l'hôte.
class ZChatRemoteRouteCatalogSource implements ZChatRouteCatalogSource {
  /// Construit la source. [open] rend le corps, [decode] le lit ; [log]
  /// reçoit les rejets du décodeur et les pannes.
  const ZChatRemoteRouteCatalogSource({
    required this.open,
    required this.decode,
    this.log,
  });

  /// L'ouvreur de l'hôte.
  final ZChatRouteCatalogOpener open;

  /// Le décodeur (forme du backend).
  final ZChatRouteCatalogDecoder decode;

  /// Journal optionnel.
  final ZChatCatalogLog? log;

  /// `Right(routeur)` si le corps porte un routeur actif d'identité [id] —
  /// un routeur reçu **sans** identité est réputé être celui demandé ;
  /// `Right(null)` si le corps est vide ou ne le porte pas ;
  /// `Left(ZServerFailure)` si l'ouvreur lève ou si le corps n'est pas du
  /// JSON.
  @override
  Future<ZResult<ZChatRouter?>> fetchRouter(String id) async {
    final ZResult<ZChatRouteCatalogDecodeReport?> read = await _read(
      ZChatRouteCatalogQuery(id: id),
    );
    return read.map((ZChatRouteCatalogDecodeReport? report) {
      final ZChatRouter? router = report?.byId(id);
      if (router == null || !router.isActive) return null;
      return router;
    });
  }

  /// Les routeurs actifs du corps (liste vide si le corps est vide) ;
  /// `Left(ZServerFailure)` si l'ouvreur lève ou si le corps n'est pas du
  /// JSON.
  @override
  Future<ZResult<List<ZChatRouter>>> fetchAll() async {
    final ZResult<ZChatRouteCatalogDecodeReport?> read = await _read(
      const ZChatRouteCatalogQuery(),
    );
    return read.map(
      (ZChatRouteCatalogDecodeReport? report) =>
          List<ZChatRouter>.unmodifiable(<ZChatRouter>[
            if (report != null)
              for (final ZChatRouter r in report.routers)
                if (r.isActive) r,
          ]),
    );
  }

  Future<ZResult<ZChatRouteCatalogDecodeReport?>> _read(
    ZChatRouteCatalogQuery query,
  ) async {
    final String body;
    try {
      body = await open(query);
    } on Object catch (e) {
      log?.call('route catalog: open failed for $query', cause: e);
      return Left<ZFailure, ZChatRouteCatalogDecodeReport?>(
        ZServerFailure('route catalog unreachable: $e'),
      );
    }
    if (body.trim().isEmpty) {
      return const Right<ZFailure, ZChatRouteCatalogDecodeReport?>(null);
    }
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException catch (e) {
      log?.call('route catalog: body is not JSON for $query', cause: e);
      return Left<ZFailure, ZChatRouteCatalogDecodeReport?>(
        ZServerFailure('route catalog body is not JSON: ${e.message}'),
      );
    }
    final ZChatRouteCatalogDecodeReport report = decode.decodeList(
      json,
      fallbackId: query.id,
    );
    for (final ZChatRouteCatalogRejection r in report.rejected) {
      log?.call('route catalog: element rejected ($r)', cause: r.raw);
    }
    return Right<ZFailure, ZChatRouteCatalogDecodeReport?>(report);
  }
}
