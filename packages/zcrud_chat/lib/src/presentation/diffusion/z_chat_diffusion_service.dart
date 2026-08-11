/// Diffusion d'une conversation : export, partage, lecture à voix haute.
///
/// « Diffuser » signifie sortir la conversation de l'application : l'exporter,
/// la partager, ou la lire à voix haute.
///
/// ## Ce service étend `ZChatExportService`, il ne le double pas
///
/// L'export textuel couvre déjà quatre formats (`markdown`, `plainText`,
/// `html`, `references`) plus le PDF par couture. Ce service :
///
/// * n'ajoute aucun format ;
/// * n'écrit aucun rendu — le texte lu à voix haute est celui que
///   [ZChatExportService.exportConversation] produit déjà en
///   [ZChatExportFormat.plainText], y compris son aplatissement Markdown
///   (`**gras**` devient `*gras*`, en-têtes retirés, liens aplatis), qui est
///   exactement ce qu'il faut à un moteur de synthèse ;
/// * n'écrit aucun partage — [ZChatExportService.shareConversation] et sa
///   couture `ZChatExportSink` existent déjà et sont réutilisées telles
///   quelles.
///
/// ## Pourquoi la narration passe par l'export plutôt que par les blocs
///
/// Les deux voies existent et ne servent pas la même chose :
///
/// | Voie | Ce qu'elle produit | Quand |
/// |---|---|---|
/// | [narrateMessage] → `ZChatSpeechRequest.ofMessage` → `zChatAccessibleTextOf` | le résumé annonçable d'un message | lecture d'une réponse |
/// | [narrateConversation] → `exportConversation(plainText)` | le document complet, rôles compris | lecture de toute la conversation |
///
/// Aucune des deux n'aplatit les blocs pour son compte : la première réutilise
/// le `switch` exhaustif du kernel, la seconde le rendu de l'export. C'est ce
/// qui garantit qu'un nouveau variant de bloc devient audible sans intervention
/// supplémentaire.
///
/// ## Invariant AD-2 — Flutter-native, aucun gestionnaire d'état
///
/// [ZChatDiffusionService.speaking] est une `ValueListenable<bool>` : un
/// bouton n'écoute que cette tranche, et rien d'autre du service ne
/// reconstruit quoi que ce soit.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import '../export/z_chat_export_format.dart';
import '../export/z_chat_export_result.dart';
import '../export/z_chat_export_service.dart';

/// Diffuse une conversation : export (délégué), partage (délégué), voix.
class ZChatDiffusionService {
  /// Construit le service.
  ///
  /// [exportService] est obligatoire et injecté : en construire un en
  /// interne donnerait deux vocabulaires d'export dans une même application
  /// (celui de l'hôte, celui du service), et le document lu ne serait pas le
  /// document exporté.
  ZChatDiffusionService({required this.exportService, this.speech});

  /// Le service d'export existant — jamais redéfini.
  final ZChatExportService exportService;

  /// La chaîne de diffusion vocale, ou `null` si l'hôte n'en branche aucune.
  ///
  /// `null` n'est pas une panne : c'est une capacité absente, signalée par un
  /// `Left(ZUnsupportedOperationFailure)` au moment de l'usage — jamais par une
  /// exception, jamais par un silence.
  final ZChatSpeechPort? speech;

  /// `true` tant qu'une lecture est en cours — tranche granulaire (invariant
  /// AD-2).
  ValueListenable<bool> get speaking => _speaking;
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);

  /// Lit **toute** la conversation à voix haute.
  ///
  /// Le texte est celui de l'export `plainText` : aucun second rendu.
  Future<ZResult<ZChatSpeechDelivery>> narrateConversation({
    required String title,
    required List<ZChatMessage> messages,
    ZChatExportSelection selection = ZChatExportSelection.all,
    DateTime? exportDate,
    String? languageTag,
    double rate = kZChatSpeechDefaultRate,
  }) async {
    final ZResult<ZChatExportResult> document = await exportService
        .exportConversation(
          title: title,
          messages: messages,
          format: ZChatExportFormat.plainText,
          selection: selection,
          exportDate: exportDate,
        );
    return document.fold(Left<ZFailure, ZChatSpeechDelivery>.new, (
      ZChatExportResult result,
    ) async {
      // L'export `plainText` est TEXTUEL par construction ; la branche binaire
      // n'est pas atteignable, mais un `as` la rendrait fatale si elle l'était.
      if (result is! ZChatTextExport) {
        return Left<ZFailure, ZChatSpeechDelivery>(
          ZDomainFailure('unexpected binary export for narration'),
        );
      }
      return _speak(
        ZChatSpeechRequest(
          text: result.text,
          languageTag: languageTag,
          rate: rate,
        ),
      );
    });
  }

  /// Lit **un** message à voix haute, blocs structurés compris.
  ///
  /// [resolver] est le seam d'annonce du kernel : ce qu'un lecteur d'écran
  /// entend et ce que la synthèse lit sont ainsi la **même** chaîne, résolue au
  /// même endroit.
  Future<ZResult<ZChatSpeechDelivery>> narrateMessage(
    ZChatMessage message, {
    String? languageTag,
    double rate = kZChatSpeechDefaultRate,
    ZAccessibleTextResolver? resolver,
  }) => _speak(
    ZChatSpeechRequest.ofMessage(
      message,
      languageTag: languageTag,
      rate: rate,
      resolver: resolver,
    ),
  );

  /// Arrête la lecture — best-effort, ne lève jamais (invariant AD-10).
  Future<void> stopNarration() async {
    final ZChatSpeechPort? port = speech;
    if (port != null) {
      try {
        await port.stop();
      } catch (_) {
        // Un moteur d'hôte qui lève à l'arrêt ne doit pas laisser l'interface
        // bloquée sur « lecture en cours ».
      }
    }
    _speaking.value = false;
  }

  /// Libère la tranche réactive. C'est l'hôte qui appelle ceci — le service
  /// ne possède ni l'export ni la chaîne vocale, qu'il ne dispose donc pas.
  void dispose() => _speaking.dispose();

  Future<ZResult<ZChatSpeechDelivery>> _speak(
    ZChatSpeechRequest request,
  ) async {
    final ZChatSpeechPort? port = speech;
    if (port == null) {
      return const Left<ZFailure, ZChatSpeechDelivery>(
        ZUnsupportedOperationFailure(
          'no ZChatSpeechPort wired',
          operation: 'narrate',
        ),
      );
    }
    _speaking.value = true;
    try {
      return await port.speak(request);
    } catch (error) {
      return Left<ZFailure, ZChatSpeechDelivery>(ZDomainFailure('$error'));
    } finally {
      // Un port qui lève laisserait sinon le bouton figé sur « arrêter »
      // pour une lecture qui n'a jamais commencé.
      _speaking.value = false;
    }
  }
}
