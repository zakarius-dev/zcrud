/// Les chips d'effort (paliers de longueur de réponse), en Material
/// pixel-perfect.
///
/// Chaque palier porte une teinte d'identité (une exception encadrée à
/// l'interdiction générale des couleurs codées en dur, réservée aux teintes
/// de repère d'un palier). Ces teintes ne sont pas codées ici : elles sont
/// lues par [ZChatComposerChromeStyle.responseLengthAccent], au bout de la
/// même chaîne de résolution que le reste du chrome (paramètre, puis jeton
/// de thème, puis référence intégrée). La teinte n'est jamais le seul canal
/// qui porte l'état sélectionné : la coche du `ChoiceChip` (canal non
/// chromatique) et l'attribut `selected` en sémantique portent l'information
/// indépendamment de la couleur.
///
/// L'axe est celui du kernel ([ZChatResponseLength]) ; les libellés viennent
/// du registre de libellés du socle, jamais d'un texte métier codé en dur.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Builder prêt-à-brancher (créneau `tools` de `ZChatComposer`, ou toute
/// rangée d'outils de l'hôte). Sans [ZChatComposerSlot.settings], il rend
/// `null` — l'affordance est absente (invariant AD-4), jamais une rangée de
/// chips inertes.
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

  /// {@macro zcrud.chat_material.chrome_param}
  final ZChatComposerChrome? chrome;

  @override
  Widget build(BuildContext context) {
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: chrome,
    );
    // Abonné uniquement à la tranche des réglages (invariant AD-2) : cocher
    // un corpus ailleurs ne reconstruit pas cette rangée.
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
    // Invariant AD-13 : la cible est imposée en géométrie rendue — un
    // `ChoiceChip` nu rend une boîte plus petite que la cible tactile
    // minimale (l'agrandissement de la zone de hit ne suffit pas), la
    // contrainte plancher rend donc la boîte elle-même conforme.
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
              // La chaîne du chrome, jamais une valeur hexadécimale locale.
              color: style.responseLengthAccent(length),
            ),
          ),
        ),
        label: Text(zChatLabel(context, _labelKey(length))),
        // La coche par défaut reste affichée : c'est le canal non
        // chromatique du choix — la supprimer laisserait la teinte seule
        // porter l'information de sélection.
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
