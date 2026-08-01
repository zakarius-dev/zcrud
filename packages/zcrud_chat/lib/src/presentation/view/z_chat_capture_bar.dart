/// Barre de **saisie assistée** — dictée et OCR (CHAT-10).
///
/// Rendu **neutre, zéro dépendance tierce** de [ZChatCaptureController]
/// (patron strict de `ZChatAttachmentStrip` : `Semantics`, cible tactile
/// [kZChatMinTapTarget], variantes directionnelles, libellés résolus par
/// `zChatLabel`, tokens de `ZcrudTheme`).
///
/// ## 🔴 L'écoute est ANNONCÉE, pas seulement affichée (AD-13)
///
/// Chez lex, `_isListening` ne pilote qu'une icône (`chat_input.dart`). Un
/// utilisateur non-voyant ne sait donc pas que le micro écoute — c'est-à-dire
/// qu'il ne sait pas que ce qu'il dit part dans un moteur. Ici, l'état de
/// capture est porté par une **région live** (`Semantics(liveRegion: true)`),
/// sur le patron exact de la région live de `ZChatConversationView`.
///
/// ## 🔴 Deux boutons, et l'affordance DISPARAÎT sans moteur
///
/// Un port absent ⇒ le bouton n'est pas rendu, plutôt que grisé : promettre un
/// geste qui ne viendra jamais est le défaut mesuré du menu `+` d'IFFD
/// (`chatbot_conversation_screen.dart:2707-2713`, trois options dont le `case`
/// est un `break;` nu).
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

  /// Le contrôleur écouté. Il n'est **ni créé ni disposé** ici : son cycle de
  /// vie appartient à l'hôte (AD-2).
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
              // 🔴 Région LIVE : le changement d'état est ANNONCÉ. Au repos, le
              // nœud porte le libellé neutre de la barre — jamais une phrase
              // codée en dur (FR-26).
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

/// Une action de capture — cible tactile **≥ 48 dp et BORNÉE PAR LE HAUT**.
///
/// 🔴 `Align` porte `widthFactor`/`heightFactor`. Sans eux, `Align` prend
/// **toute** la place que son parent lui donne : la cible passe alors la garde
/// « ≥ 48 dp » pour la mauvaise raison (mesuré ailleurs dans ce dépôt : une
/// cible de 600 dp de haut, verte à la garde, absurde à l'usage). Avec les
/// facteurs, `Align` s'ajuste à son enfant, et la contrainte minimale du
/// [ConstrainedBox] donne la taille — bornée des DEUX côtés, ce que la garde
/// jumelle asserte.
class ZChatCaptureAction extends StatelessWidget {
  /// Construit une action de capture.
  const ZChatCaptureAction({
    required this.label,
    required this.onTap,
    super.key,
  });

  /// Libellé **déjà résolu** (l'unique site de résolution est `zChatLabel`).
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
            // AD-13 : alignement DIRECTIONNEL.
            alignment: AlignmentDirectional.center,
            // 🔴 Les facteurs : la cible est bornée par le HAUT.
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: Padding(
              // AD-13 : marge DIRECTIONNELLE.
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
              child: Text(label, textAlign: TextAlign.start),
            ),
          ),
        ),
      ),
    );
  }
}
