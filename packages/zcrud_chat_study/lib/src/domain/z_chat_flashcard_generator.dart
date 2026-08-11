/// Câblage du port de génération de flashcards existant sur une conversation.
///
/// `ZFlashcardGenerationPort` (`zcrud_study`) existe déjà ; ce fichier le
/// câble plutôt que d'en déclarer un second — un port « chat » maison serait
/// plus pauvre (il perdrait `typesDistribution`, `modelId`, `instructions`,
/// `provenance`) et le dépôt porterait deux contrats de génération
/// divergents.
///
/// ## Ce que la classe ajoute au port, et rien de plus
///
/// 1. la projection conversation → requête, déléguée au mapper ;
/// 2. l'estampillage défensif (invariant AD-10) des cartes rendues :
///    provenance et dossier d'accueil. L'implémentation côté application
///    devrait estamper `request.provenance`, mais une implémentation qui
///    l'oublie produirait des cartes sans provenance, indistinguables de
///    cartes saisies à la main. Une provenance déjà posée n'est jamais
///    réécrite (l'implémentation peut être plus précise que ce module) :
///    seul le trou est comblé.
///
/// ## Contrat de retour (invariants AD-5, AD-10)
///
/// Retourne `ZResult<List<ZFlashcard>>`. Une implémentation d'hôte qui lève
/// au lieu de rendre un `Left` est convertie en `Left(ZDomainFailure)` : une
/// exception nue ne doit jamais traverser jusqu'à l'appelant.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'z_chat_flashcard_mapper.dart';

/// Générateur de flashcards depuis une conversation, composant le port de
/// génération existant.
class ZChatFlashcardGenerator {
  /// Construit un générateur au-dessus du [port] fourni par l'hôte.
  const ZChatFlashcardGenerator(this.port);

  /// Port de génération existant (`zcrud_study`), implémenté par
  /// l'application.
  final ZFlashcardGenerationPort port;

  /// Génère des cartes depuis un message précis.
  ///
  /// [folderId]/[subFolderId] : dossier d'accueil des cartes produites, par
  /// exemple le dossier depuis lequel la conversation a été ouverte. `null`
  /// signifie des cartes non rattachées — elles restent utilisables dans le
  /// pool de session (voir `zBuildStudyPool`), sans aller-retour par un
  /// dossier.
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

  /// Génère des cartes depuis une conversation entière.
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

  /// Appel du port et estampillage — site unique, aucun verbe dupliqué.
  Future<ZResult<List<ZFlashcard>>> _generate(
    ZFlashcardGenerationRequest request, {
    required String? folderId,
    required String? subFolderId,
  }) async {
    final ZResult<List<ZFlashcard>> result;
    try {
      result = await port.generateFlashcards(request);
    } catch (error) {
      // Invariants AD-5/AD-10 : une implémentation d'hôte qui lève ne doit
      // pas traverser ce module.
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

/// Estampille défensivement une carte produite (fonction pure).
///
/// - `source` : posée seulement si absente, jamais écrasée ;
/// - `folderId`/`subFolderId` : posés seulement si absents, pour ne pas
///   déplacer une carte que l'implémentation aurait déjà rangée ailleurs.
///
/// Aucun champ de répétition espacée n'est touché : cet état vit dans une
/// entité séparée (invariant AD-9) — une carte fraîchement générée n'en a
/// simplement pas encore.
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
