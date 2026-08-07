/// Les **chips d'effort** (paliers de verbosité) pixel-perfect lex — lot K3.
///
/// lex rend ses paliers Mini/Plus/Pro en `ChoiceChip` à avatar 24 dp et radius
/// 12 (`chat_input.dart:768-833`, `effort_chips.dart`), chaque palier portant
/// sa teinte d'IDENTITÉ (vert/bleu/violet — exception FR-26 encadrée de K2).
///
/// 🔴 **Les trois teintes ne vivent PAS ici** : elles sont lues par
/// [ZChatComposerChromeStyle.responseLengthAccent] — la chaîne paramètre >
/// (jeton demandé) > `ZChatComposerReference.responseLengthAccents`. Un hôte
/// qui règle `ZChatComposerChrome.responseLengthAccents` (ou, demain, le jeton
/// `chatResponseLengthAccents`) est suivi ici sans qu'une ligne change.
///
/// 🔴 La teinte n'est **jamais porteuse seule** : l'état choisi reste dit par
/// la coche du `ChoiceChip` (canal non chromatique) et par `selected:` en
/// sémantique — leçon CR-74.
///
/// L'axe est celui du **kernel** ([ZChatResponseLength]), les libellés ceux du
/// registre du socle (`zchat.lengthConcise/Standard/Detailed`) — jamais un
/// libellé métier en dur.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Builder prêt-à-brancher (créneau `tools` de `ZChatComposer`, ou toute
/// rangée d'outils de l'hôte). Règle des trois cas : sans
/// [ZChatComposerSlot.settings], il rend `null` — l'affordance est ABSENTE
/// (AD-4), jamais une rangée de chips inertes.
ZChatComposerSlotBuilder zChatMaterialEffortChips({
  ZChatComposerChrome? chrome,
}) =>
    (BuildContext context, ZChatComposerSlot slot) {
      final ZChatSettingsController? settings = slot.settings;
      if (settings == null) return null;
      return ZChatMaterialEffortChips(controller: settings, chrome: chrome);
    };

/// La rangée des trois paliers — montable directement avec le
/// [ZChatSettingsController] de l'hôte.
class ZChatMaterialEffortChips extends StatelessWidget {
  /// Construit la rangée de paliers.
  const ZChatMaterialEffortChips({
    required this.controller,
    this.chrome,
    super.key,
  });

  /// Le contrôleur de réglages du socle — l'écriture passe par son verbe
  /// `setResponseLength`, jamais par un second canal.
  final ZChatSettingsController controller;

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex (chaîne K2).
  final ZChatComposerChrome? chrome;

  @override
  Widget build(BuildContext context) {
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: chrome,
    );
    // 🔴 LA tranche des réglages, et elle seule : cocher un corpus ailleurs ne
    // reconstruit pas cette rangée (SM-1).
    return ValueListenableBuilder<ZChatGenerationSettings>(
      valueListenable: controller.settings,
      builder:
          (
            BuildContext context,
            ZChatGenerationSettings settings,
            Widget? _,
          ) => Wrap(
            spacing: ZChatComposerReference.badgeStartGap,
            children: <Widget>[
              for (final ZChatResponseLength length
                  in ZChatResponseLength.values)
                _chip(context, style, settings, length),
            ],
          ),
    );
  }

  Widget _chip(
    BuildContext context,
    ZChatComposerChromeStyle style,
    ZChatGenerationSettings settings,
    ZChatResponseLength length,
  ) {
    final bool selected = settings.responseLength == length;
    // 🔴 AD-13 : la cible est imposée en GÉOMÉTRIE RENDUE — un `ChoiceChip` nu
    // rend ~32 dp de haut (le `materialTapTargetSize` n'agrandit que la zone
    // de hit, pas la boîte) ; la contrainte plancher rend la boîte elle-même
    // ≥ 48 dp, mesurable.
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: kZChatMinTapTarget,
        minHeight: kZChatMinTapTarget,
      ),
      child: ChoiceChip(
        avatar: SizedBox(
          width: ZChatComposerReference.chipAvatarSize,
          height: ZChatComposerReference.chipAvatarSize,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              // 🔴 LA chaîne du chrome — jamais un hex ici (FR-26 : les trois
              // teintes vivent dans la référence K2, exception encadrée).
              color: style.responseLengthAccent(length),
            ),
          ),
        ),
        label: Text(zChatLabel(context, _labelKey(length))),
        // La coche par défaut RESTE : c'est le canal non chromatique du choix
        // (leçon CR-74) — la supprimer laisserait la teinte porter seule.
        selected: selected,
        onSelected: (bool now) =>
            controller.setResponseLength(now ? length : null),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(ZChatComposerReference.chipRadius),
        ),
      ),
    );
  }
}

/// Clé de libellé du registre du socle pour un palier — l'axe kernel, jamais
/// une chaîne métier (« Mini »/« Plus »/« Pro » restent des libellés d'hôte,
/// posables via `ZcrudScope.labels`).
String _labelKey(ZChatResponseLength length) => switch (length) {
  ZChatResponseLength.concise => kZChatLabelLengthConcise,
  ZChatResponseLength.standard => kZChatLabelLengthStandard,
  ZChatResponseLength.detailed => kZChatLabelLengthDetailed,
};
