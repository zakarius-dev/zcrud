/// Barre de saisie assistée — dictée et reconnaissance de texte.
///
/// Rendu neutre, zéro dépendance tierce, de [ZChatCaptureController] : suit
/// le même patron que `ZChatAttachmentStrip` (`Semantics`, cible tactile
/// [kZChatMinTapTarget], variantes directionnelles, libellés résolus par
/// `zChatLabel`, jetons de `ZcrudTheme`).
///
/// ## L'écoute est annoncée, pas seulement affichée
///
/// Un utilisateur non-voyant doit savoir que le micro écoute — c'est-à-dire
/// que ce qu'il dit part dans un moteur de reconnaissance — sans dépendre
/// d'un indice purement visuel. L'état de capture est donc porté par une
/// région live (`Semantics(liveRegion: true)`, invariant AD-13), sur le
/// patron exact de la région live de `ZChatConversationView`.
///
/// ## Deux boutons, et l'affordance disparaît sans moteur disponible
///
/// Un port absent signifie que le bouton correspondant n'est pas rendu,
/// plutôt que grisé : promettre un geste qui ne viendra jamais dégrade la
/// confiance dans toute l'interface.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../capture/z_chat_capture_controller.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// Rend les affordances de saisie assistée d'un [ZChatCaptureController].
class ZChatCaptureBar extends StatelessWidget {
  /// Construit la barre.
  const ZChatCaptureBar({
    required this.controller,
    required this.onDictate,
    required this.onScan,
    super.key,
  });

  /// Le contrôleur écouté. Il n'est ni créé ni disposé ici : son cycle de vie
  /// appartient à l'hôte (invariant AD-2).
  final ZChatCaptureController controller;

  /// Bascule de dictée — démarrer si au repos, arrêter si à l'écoute.
  final VoidCallback onDictate;

  /// Déclenche un cycle d'OCR (c'est l'hôte qui choisit capture ou octets).
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return ValueListenableBuilder<ZChatCaptureActivity>(
      valueListenable: controller.activity,
      builder:
          (BuildContext context, ZChatCaptureActivity activity, Widget? child) {
            final bool listening = activity == ZChatCaptureActivity.listening;
            return Semantics(
              container: true,
              // Région live : le changement d'état est annoncé. Au repos, le
              // nœud porte le libellé neutre de la barre — jamais une phrase
              // codée en dur.
              liveRegion: true,
              label: switch (activity) {
                ZChatCaptureActivity.listening =>
                  zChatLabel(context, kZChatLabelListening),
                ZChatCaptureActivity.recognizing =>
                  zChatLabel(context, kZChatLabelRecognizing),
                ZChatCaptureActivity.idle =>
                  zChatLabel(context, kZChatLabelAssistedInput),
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (controller.dictation != null)
                    ZChatCaptureAction(
                      label: listening
                          ? zChatLabel(context, kZChatLabelStopDictation)
                          : zChatLabel(context, kZChatLabelDictate),
                      onTap: onDictate,
                    ),
                  if (controller.dictation != null && controller.ocr != null)
                    SizedBox(width: theme.gapS),
                  if (controller.ocr != null)
                    ZChatCaptureAction(
                      label: zChatLabel(context, kZChatLabelScanText),
                      onTap: onScan,
                    ),
                ],
              ),
            );
          },
    );
  }
}

/// Une action de capture — cible tactile ≥ 48 dp et bornée par le haut.
///
/// `Align` porte `widthFactor`/`heightFactor`. Sans eux, `Align` prendrait
/// toute la place que son parent lui donne, et la cible pourrait mesurer une
/// hauteur bien supérieure à 48 dp sans que cela révèle un défaut. Avec les
/// facteurs, `Align` s'ajuste à son enfant, et la contrainte minimale du
/// [ConstrainedBox] donne la taille — bornée des deux côtés.
class ZChatCaptureAction extends StatelessWidget {
  /// Construit une action de capture.
  const ZChatCaptureAction({
    required this.label,
    required this.onTap,
    super.key,
  });

  /// Libellé déjà résolu (l'unique site de résolution est `zChatLabel`).
  final String label;

  /// Ce que le geste déclenche.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kZChatMinTapTarget,
            minWidth: kZChatMinTapTarget,
          ),
          child: Align(
            // Invariant AD-13 : alignement directionnel.
            alignment: AlignmentDirectional.center,
            // Les facteurs : la cible est bornée par le haut.
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: Padding(
              // Invariant AD-13 : marge directionnelle.
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
              child: Text(label, textAlign: TextAlign.start),
            ),
          ),
        ),
      ),
    );
  }
}
