/// Rendu neutre de l'état d'une session vocale continue.
///
/// ## L'état est ANNONCÉ, pas seulement affiché
///
/// Un utilisateur qui n'entend pas doit savoir que le micro écoute — sinon
/// rien ne distingue « la session écoute » de « la session ne fait rien ».
/// L'état est donc porté par une région live (`Semantics(liveRegion: true)`,
/// invariant AD-13), sur le patron exact de [ZChatCaptureBar].
///
/// ## Deux tranches, deux abonnements
///
/// La phase et le fait qu'une session tourne sont deux `ValueListenable`
/// distinctes : passer de « à l'écoute » à « lecture de la réponse » ne
/// reconstruit que le nœud d'annonce, jamais l'affordance d'arrêt — et
/// jamais, à plus forte raison, le champ de saisie (invariant AD-2).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../capture/z_chat_voice_session_controller.dart';
import 'z_chat_capture_bar.dart' show ZChatCaptureAction;
import 'z_chat_labels.dart';

/// Rend la phase et l'affordance d'arrêt d'un [ZChatVoiceSessionController].
class ZChatVoiceSessionBanner extends StatelessWidget {
  /// Construit le bandeau.
  const ZChatVoiceSessionBanner({required this.controller, super.key});

  /// Le contrôleur écouté. Il n'est ni créé ni disposé ici : son cycle de vie
  /// appartient à l'hôte (invariant AD-2).
  final ZChatVoiceSessionController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.active,
      builder: (BuildContext context, bool active, Widget? child) {
        // Aucune session ⇒ RIEN dans l'arbre, pas même un nœud sémantique
        // vide : une région live qui annonce « mode vocal » alors que rien ne
        // tourne est du bruit pour un lecteur d'écran.
        if (!active) return const SizedBox.shrink();
        return ValueListenableBuilder<ZChatVoiceSessionPhase>(
          valueListenable: controller.phase,
          builder:
              (
                BuildContext context,
                ZChatVoiceSessionPhase phase,
                Widget? affordance,
              ) {
                return Semantics(
                  container: true,
                  // Région live : le changement de phase est annoncé, pas
                  // seulement affiché.
                  liveRegion: true,
                  label: switch (phase) {
                    ZChatVoiceSessionPhase.listening => zChatLabel(
                      context,
                      kZChatLabelListening,
                    ),
                    ZChatVoiceSessionPhase.submitting => zChatLabel(
                      context,
                      kZChatLabelVoiceSubmitting,
                    ),
                    ZChatVoiceSessionPhase.speaking => zChatLabel(
                      context,
                      kZChatLabelVoiceSpeaking,
                    ),
                    // Atteint le temps d'une transition : la session est
                    // encore active, la phase n'est pas encore posée.
                    ZChatVoiceSessionPhase.idle => zChatLabel(
                      context,
                      kZChatLabelVoiceSession,
                    ),
                  },
                  child: affordance,
                );
              },
          // Hors du builder de phase : l'affordance d'arrêt ne se reconstruit
          // pas quand la phase change.
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Cible ≥ 48 dp, bornée des deux côtés : la même que celle de la
          // barre de capture, jamais une seconde définition.
          Builder(
            builder: (BuildContext context) => ZChatCaptureAction(
              label: zChatLabel(context, kZChatLabelStopVoiceSession),
              onTap: () => unawaited(controller.stop()),
            ),
          ),
        ],
      ),
    );
  }
}
