/// Câblage du port de génération **EXISTANT** sur la conversation (CHAT-8).
///
/// 🔴 `ZFlashcardGenerationPort` (`zcrud_study`) EXISTE et n'avait **aucun
/// consommateur**. Ce fichier le **CÂBLE**. Il n'en déclare pas un second : un
/// port « chat » maison serait plus pauvre (il perdrait `typesDistribution`,
/// `modelId`, `instructions`, `provenance`) et le dépôt porterait deux contrats
/// de génération divergents — le piège CR-LEX-78.
///
/// ## Ce que la classe ajoute au port (et rien de plus)
///
/// 1. la **projection** conversation → requête (déléguée au mapper) ;
/// 2. l'**estampillage défensif** (AD-10) des cartes rendues : provenance et
///    dossier d'accueil. L'implémentation app-side *devrait* estamper
///    `request.provenance` — la doc du port le demande. « Devrait » n'est pas
///    une garantie : une impl qui l'oublie produirait des cartes **sans
///    provenance**, indistinguables de cartes saisies à la main, et la
///    fonctionnalité « cartes issues de la conversation » deviendrait muette.
///    On ne réécrit JAMAIS une provenance déjà posée (l'impl peut être plus
///    précise que nous) : on ne remplit que le trou.
///
/// ## AD-5 / AD-10
///
/// Retourne `ZResult<List<ZFlashcard>>`. Une impl d'hôte qui **lève** au lieu de
/// rendre un `Left` (c'est du code d'application, hors de notre contrôle) est
/// convertie en `Left(ZDomainFailure)` : le bouton « Commencer à apprendre » ne
/// doit jamais faire remonter une exception nue jusqu'à l'UI.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'z_chat_flashcard_mapper.dart';

/// Générateur de flashcards **depuis une conversation**, composant le port.
class ZChatFlashcardGenerator {
  /// Construit un générateur au-dessus du [port] fourni par l'hôte.
  const ZChatFlashcardGenerator(this.port);

  /// Port de génération **existant** (`zcrud_study`), implémenté par l'app.
  final ZFlashcardGenerationPort port;

  /// Génère des cartes depuis un **message** précis.
  ///
  /// [folderId]/[subFolderId] : dossier d'accueil des cartes produites (comme
  /// IFFD, qui rattache au dossier depuis lequel la conversation a été ouverte).
  /// `null` = cartes non rattachées — elles restent utilisables dans le pool de
  /// session (cf. `zBuildStudyPool`), sans aller-retour par le dossier.
  Future<ZResult<List<ZFlashcard>>> generateFromMessage(
    ZChatMessage message, {
    String? folderId,
    String? subFolderId,
    int? count,
    String? languageTag,
    Map<ZFlashcardType, int>? typesDistribution,
    List<ZFlashcardType> types = ZFlashcardType.values,
    String? instructions,
    String? modelId,
    Map<String, dynamic> extra = const <String, dynamic>{},
    ZAccessibleTextResolver? resolver,
  }) =>
      _generate(
        zChatMessageGenerationRequest(
          message,
          count: count,
          languageTag: languageTag,
          typesDistribution: typesDistribution,
          types: types,
          instructions: instructions,
          modelId: modelId,
          extra: extra,
          resolver: resolver,
        ),
        folderId: folderId,
        subFolderId: subFolderId,
      );

  /// Génère des cartes depuis une **conversation entière**.
  Future<ZResult<List<ZFlashcard>>> generateFromConversation(
    ZChatConversation conversation,
    Iterable<ZChatMessage> messages, {
    String? folderId,
    String? subFolderId,
    int? count,
    String? languageTag,
    Map<ZFlashcardType, int>? typesDistribution,
    List<ZFlashcardType> types = ZFlashcardType.values,
    String? instructions,
    String? modelId,
    Set<ZChatRole> roles = kZChatStudyDefaultRoles,
    Map<String, dynamic> extra = const <String, dynamic>{},
    ZAccessibleTextResolver? resolver,
  }) =>
      _generate(
        zChatConversationGenerationRequest(
          conversation,
          messages,
          count: count,
          languageTag: languageTag,
          typesDistribution: typesDistribution,
          types: types,
          instructions: instructions,
          modelId: modelId,
          roles: roles,
          extra: extra,
          resolver: resolver,
        ),
        folderId: folderId,
        subFolderId: subFolderId,
      );

  /// Appel du port + estampillage — **site unique** (aucun verbe dupliqué).
  Future<ZResult<List<ZFlashcard>>> _generate(
    ZFlashcardGenerationRequest request, {
    required String? folderId,
    required String? subFolderId,
  }) async {
    final ZResult<List<ZFlashcard>> result;
    try {
      result = await port.generateFlashcards(request);
    } catch (error) {
      // AD-10/AD-5 : une impl d'hôte qui lève ne doit pas traverser le socle.
      return Left<ZFailure, List<ZFlashcard>>(
        ZDomainFailure('generateFlashcards a levé : $error'),
      );
    }
    return result.map(
      (List<ZFlashcard> cards) => <ZFlashcard>[
        for (final ZFlashcard card in cards)
          zStampChatProvenance(
            card,
            provenance: request.provenance,
            folderId: folderId,
            subFolderId: subFolderId,
          ),
      ],
    );
  }
}

/// Estampille **défensivement** une carte produite (fonction PURE).
///
/// - `source` : posée **seulement si absente** (jamais écrasée) ;
/// - `folderId`/`subFolderId` : posés **seulement si absents**, pour ne pas
///   déplacer une carte que l'impl aurait déjà rangée ailleurs.
///
/// Aucun champ SRS n'est touché : l'état de répétition vit dans une entité
/// séparée (AD-9) — une carte fraîchement générée n'en a simplement pas.
ZFlashcard zStampChatProvenance(
  ZFlashcard card, {
  ZFlashcardSource? provenance,
  String? folderId,
  String? subFolderId,
}) {
  final ZFlashcardSource? source = card.source ?? provenance;
  final String? folder = card.folderId ?? folderId;
  final String? subFolder = card.subFolderId ?? subFolderId;
  if (identical(source, card.source) &&
      folder == card.folderId &&
      subFolder == card.subFolderId) {
    return card;
  }
  return card.copyWith(
    source: source,
    folderId: folder,
    subFolderId: subFolder,
  );
}
