/// L'**en-tête** et les **titres de section** de la feuille de réglages, en
/// Material.
///
/// L'en-tête reprend la forme de celui du socle — titre, badge du comptage,
/// « réinitialiser », « fermer » — avec la typographie et les rôles de
/// couleur de l'hôte. Comme dans le socle, il n'existe que lorsque l'hôte
/// fournit le geste de fermeture : c'est lui qui possède le conteneur de la
/// feuille, donc la fermeture ; sans ce geste, aucun bouton inerte n'est
/// rendu.
///
/// Un titre de section est hiérarchisé sous le titre de la feuille
/// (`titleSmall`, teinté du rôle `primary`) et, quand il ouvre une section qui
/// en suit une autre, un séparateur en retrait le précède.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'z_chat_material_badge.dart';
import 'z_chat_material_settings_labels.dart';
import 'z_chat_material_settings_reference.dart';

/// Builder prêt-à-brancher sur `ZChatSettingsSheet.headerBuilder`.
///
/// [onClose] `null` ⇒ le builder rend `null` : aucun en-tête, comme le
/// défaut du socle.
ZChatSettingsTileBuilder zChatMaterialSettingsHeader({
  ZChatMaterialSettingsLabels labels = const ZChatMaterialSettingsLabels(),
  VoidCallback? onClose,
}) =>
    (BuildContext context, ZChatSettingsSlot slot) => onClose == null
        ? null
        : ZChatMaterialSettingsHeader(
            controller: slot.controller,
            labels: labels,
            onClose: onClose,
          );

/// L'en-tête de la feuille : titre, comptage, remise à zéro, fermeture.
class ZChatMaterialSettingsHeader extends StatelessWidget {
  /// Construit l'en-tête.
  const ZChatMaterialSettingsHeader({
    required this.controller,
    required this.onClose,
    this.labels = const ZChatMaterialSettingsLabels(),
    super.key,
  });

  /// Le contrôleur de réglages — la remise à zéro est son geste `reset`.
  final ZChatSettingsController controller;

  /// Ferme la feuille.
  final VoidCallback onClose;

  /// Les canaux de libellé de l'hôte.
  final ZChatMaterialSettingsLabels labels;

  @override
  Widget build(BuildContext context) {
    final String title = labels.title ?? zChatLabel(context, kZChatLabelSettings);
    final String reset =
        labels.reset ?? zChatLabel(context, kZChatLabelSettingsReset);
    final String close =
        labels.close ?? zChatLabel(context, kZChatLabelSettingsClose);
    const Size floor = Size(0, ZChatMaterialSettingsReference.minTapTarget);
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        // Le comptage est celui du domaine (`activeCount`) : le même nombre
        // que le badge du composer, jamais un second calcul.
        ZChatMaterialToolsBadge(controller: controller),
        TextButton(
          // Plancher tactile tenu PAR LE WIDGET (invariant AD-13) : un hôte
          // qui compacte ses cibles (`materialTapTargetSize.shrinkWrap`) ne
          // le fait pas descendre.
          style: TextButton.styleFrom(minimumSize: floor),
          onPressed: controller.reset,
          child: Text(reset),
        ),
        IconButton(
          constraints: const BoxConstraints(
            minWidth: ZChatMaterialSettingsReference.minTapTarget,
            minHeight: ZChatMaterialSettingsReference.minTapTarget,
          ),
          onPressed: onClose,
          tooltip: close,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

/// Le titre d'une section, hiérarchisé sous celui de la feuille.
class ZChatMaterialSettingsSectionHeader extends StatelessWidget {
  /// Construit le titre. [separated] pose un séparateur au-dessus : la
  /// section en suit une autre.
  const ZChatMaterialSettingsSectionHeader({
    required this.title,
    this.separated = false,
    super.key,
  });

  /// Le titre, déjà résolu.
  final String title;

  /// `true` quand la section en suit une autre.
  final bool separated;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (separated)
          const Divider(indent: ZChatMaterialSettingsReference.dividerIndent),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.start,
            // Le rôle `primary` sur un `TextTheme` : la couleur est posée sur
            // le style même du texte, jamais par une enveloppe d'héritage.
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
