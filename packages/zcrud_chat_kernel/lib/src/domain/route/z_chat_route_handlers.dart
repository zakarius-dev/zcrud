/// Gestionnaires de route — `ZChatRouteHandlers` (invariants AD-4, AD-12).
///
/// Une route peut nommer un **gestionnaire** (`ZChatRouteSpec.handlerId`,
/// opaque) : le port qui exécute effectivement la requête. Ce contrat
/// retrouve un port de streaming ou de génération par cette identité ; il ne
/// résout ni ne gate — il répartit.
///
/// Le socle fournit un annuaire **inerte** (aucun gestionnaire) et un
/// annuaire **mémoire** immuable.
library;

import '../ai/z_chat_generation_port.dart';

/// Annuaire des ports exécutant les routes.
abstract interface class ZChatRouteHandlers {
  /// Port de streaming d'identité [id], ou `null` s'il est inconnu.
  ZChatStreamPort? streamPortFor(String id);

  /// Port de génération d'identité [id], ou `null` s'il est inconnu.
  ZChatGenerationPort? generationPortFor(String id);
}

/// Annuaire **inerte** : aucun gestionnaire.
class ZChatInertRouteHandlers implements ZChatRouteHandlers {
  /// Construit l'annuaire inerte.
  const ZChatInertRouteHandlers();

  @override
  ZChatStreamPort? streamPortFor(String id) => null;

  @override
  ZChatGenerationPort? generationPortFor(String id) => null;
}

/// Annuaire **mémoire**, immuable : [withStreamPort] et [withGenerationPort]
/// rendent un **nouvel** annuaire.
class ZChatMapRouteHandlers implements ZChatRouteHandlers {
  /// Construit un annuaire depuis deux tables `identité → port`.
  const ZChatMapRouteHandlers({
    Map<String, ZChatStreamPort> streamPorts =
        const <String, ZChatStreamPort>{},
    Map<String, ZChatGenerationPort> generationPorts =
        const <String, ZChatGenerationPort>{},
    // ignore: prefer_initializing_formals
  }) : _streamPorts = streamPorts,
       // ignore: prefer_initializing_formals
       _generationPorts = generationPorts;

  final Map<String, ZChatStreamPort> _streamPorts;
  final Map<String, ZChatGenerationPort> _generationPorts;

  /// Identités des ports de streaming connus.
  List<String> get streamIds => List<String>.unmodifiable(_streamPorts.keys);

  /// Identités des ports de génération connus.
  List<String> get generationIds =>
      List<String>.unmodifiable(_generationPorts.keys);

  /// Nouvel annuaire où [id] désigne [port] en streaming.
  ZChatMapRouteHandlers withStreamPort(String id, ZChatStreamPort port) =>
      ZChatMapRouteHandlers(
        streamPorts: Map<String, ZChatStreamPort>.unmodifiable(
          <String, ZChatStreamPort>{..._streamPorts, id: port},
        ),
        generationPorts: _generationPorts,
      );

  /// Nouvel annuaire où [id] désigne [port] en génération.
  ZChatMapRouteHandlers withGenerationPort(
    String id,
    ZChatGenerationPort port,
  ) => ZChatMapRouteHandlers(
    streamPorts: _streamPorts,
    generationPorts: Map<String, ZChatGenerationPort>.unmodifiable(
      <String, ZChatGenerationPort>{..._generationPorts, id: port},
    ),
  );

  @override
  ZChatStreamPort? streamPortFor(String id) => _streamPorts[id];

  @override
  ZChatGenerationPort? generationPortFor(String id) => _generationPorts[id];
}
