/// Les familles de réglages rendues en **bascule à ligne entière**
/// (`SwitchListTile`) : le raisonnement exposé et les capacités.
///
/// Chaque bascule porte un glyphe, un titre, et — quand l'hôte en fournit le
/// texte — un **sous-titre d'état** qui décrit la valeur courante, jamais la
/// fonction du réglage. La ligne entière est cliquable ; une capacité
/// indisponible reste rendue, grisée, avec sa raison quand l'hôte la nomme.
///
/// Les tuiles lisent la tranche des réglages et écrivent par les gestes du
/// contrôleur (`setRevealThinkingSteps`, `toggleCapability`).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_chat_material_settings_labels.dart';
import 'z_chat_material_settings_reference.dart';

// ── Raisonnement exposé ───────────────────────────────────────────────────

/// Builder prêt-à-brancher sur `ZChatSettingsSheet.revealThinkingBuilder`.
ZChatSettingsTileBuilder zChatMaterialRevealThinkingTile({
  ZChatMaterialSettingsLabels labels = const ZChatMaterialSettingsLabels(),
}) =>
    (BuildContext context, ZChatSettingsSlot slot) =>
        ZChatMaterialRevealThinkingTile(
          controller: slot.controller,
          labels: labels,
        );

/// La bascule « exposer le raisonnement ».
///
/// L'axe du contrôleur est ternaire (`null` = « l'hôte décide », `true`,
/// `false`). La bascule rend `true` en position ouverte et tout le reste en
/// position fermée ; fermer ramène à « l'hôte décide », jamais à un refus
/// explicite — exprimer `false` reste possible par
/// `ZChatSettingsController.setRevealThinkingSteps`.
class ZChatMaterialRevealThinkingTile extends StatelessWidget {
  /// Construit la tuile.
  const ZChatMaterialRevealThinkingTile({
    required this.controller,
    this.labels = const ZChatMaterialSettingsLabels(),
    super.key,
  });

  /// Le contrôleur de réglages du socle.
  final ZChatSettingsController controller;

  /// Les canaux de libellé et de glyphe de l'hôte.
  final ZChatMaterialSettingsLabels labels;

  @override
  Widget build(BuildContext context) =>
      // Abonné uniquement à la tranche des réglages (invariant AD-2).
      ValueListenableBuilder<ZChatGenerationSettings>(
        valueListenable: controller.settings,
        builder:
            (
              BuildContext context,
              ZChatGenerationSettings settings,
              Widget? _,
            ) {
              final bool? value = settings.revealThinkingSteps;
              final bool on = value ?? false;
              final String? state = labels.revealThinkingStateOf?.call(value);
              return _ZChatMaterialSwitchTile(
                value: on,
                // Fermer = retirer la demande (« l'hôte décide »), le même
                // couple que la tuile par défaut du socle.
                onChanged: (bool next) =>
                    controller.setRevealThinkingSteps(next ? true : null),
                title: zChatLabel(context, kZChatLabelRevealThinking),
                subtitle: state,
                icon: labels.iconOf?.call(kZChatSettingsEntryRevealThinking) ??
                    const Icon(Icons.psychology),
              );
            },
      );
}

// ── Capacités ─────────────────────────────────────────────────────────────

/// Builder prêt-à-brancher sur `ZChatSettingsSheet.capabilitiesBuilder`.
ZChatSettingsTileBuilder zChatMaterialCapabilityTiles({
  ZChatMaterialSettingsLabels labels = const ZChatMaterialSettingsLabels(),
}) =>
    (BuildContext context, ZChatSettingsSlot slot) =>
        ZChatMaterialCapabilityTiles(
          controller: slot.controller,
          catalog: slot.capabilityCatalog,
          labels: labels,
        );

/// Une bascule par capacité : la recherche web — la seule que le socle nomme
/// — puis les capacités supplémentaires de l'hôte.
///
/// Un hôte qui fournit sa propre entrée pour la clé réservée
/// (`kZChatCapabilityWebSearch`) remplace celle du socle : jamais deux
/// bascules pour une même clé.
class ZChatMaterialCapabilityTiles extends StatelessWidget {
  /// Construit les bascules.
  const ZChatMaterialCapabilityTiles({
    required this.controller,
    this.catalog = const <ZChatSettingsHostOption>[],
    this.labels = const ZChatMaterialSettingsLabels(),
    super.key,
  });

  /// Le contrôleur de réglages du socle.
  final ZChatSettingsController controller;

  /// Les capacités supplémentaires de l'hôte.
  final List<ZChatSettingsHostOption> catalog;

  /// Les canaux de libellé et de glyphe de l'hôte.
  final ZChatMaterialSettingsLabels labels;

  @override
  Widget build(BuildContext context) {
    final bool hostOverridesWebSearch = catalog.any(
      (ZChatSettingsHostOption o) => o.key.trim() == kZChatCapabilityWebSearch,
    );
    final List<ZChatSettingsHostOption> options = <ZChatSettingsHostOption>[
      if (!hostOverridesWebSearch)
        ZChatSettingsHostOption(
          key: kZChatCapabilityWebSearch,
          label: zChatLabel(context, kZChatLabelCapabilityWebSearch),
        ),
      ...catalog,
    ];
    // Abonné uniquement à la tranche des réglages (invariant AD-2).
    return ValueListenableBuilder<ZChatGenerationSettings>(
      valueListenable: controller.settings,
      builder:
          (
            BuildContext context,
            ZChatGenerationSettings settings,
            Widget? _,
          ) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                zChatLabel(context, kZChatLabelCapabilities),
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final ZChatSettingsHostOption option in options)
                _capability(context, settings, option),
            ],
          ),
    );
  }

  Widget _capability(
    BuildContext context,
    ZChatGenerationSettings settings,
    ZChatSettingsHostOption option,
  ) {
    final String key = option.key;
    final bool requested = settings.capability(key) ?? false;
    // Une capacité indisponible reste RENDUE, grisée, et porte sa raison
    // quand l'hôte la nomme — jamais masquée.
    final String? subtitle = option.enabled
        ? labels.capabilityStateOf?.call(key, requested)
        : labels.reasonOf?.call(key);
    return _ZChatMaterialSwitchTile(
      key: ValueKey<String>(key),
      value: requested,
      onChanged:
          option.enabled ? (bool _) => controller.toggleCapability(key) : null,
      title: option.label,
      subtitle: subtitle,
      icon: labels.iconOf?.call(key) ??
          (key.trim() == kZChatCapabilityWebSearch
              ? const Icon(Icons.public)
              : null),
    );
  }
}

/// La forme commune des bascules : ligne entière cliquable, glyphe teinté du
/// rôle `primary` quand la bascule est ouverte, plancher tactile tenu.
class _ZChatMaterialSwitchTile extends StatelessWidget {
  const _ZChatMaterialSwitchTile({
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.icon,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String? subtitle;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final Widget? glyph = icon;
    final String? state = subtitle;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: ZChatMaterialSettingsReference.minTapTarget,
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title, textAlign: TextAlign.start),
        subtitle: state == null ? null : Text(state, textAlign: TextAlign.start),
        // La teinte du glyphe passe par la primitive du cœur, qui couvre les
        // trois chemins de style d'un glyphe d'hôte — jamais par un
        // `IconTheme.merge` local.
        secondary: glyph == null
            ? null
            : value && onChanged != null
                ? ZForegroundOverride(
                    color: Theme.of(context).colorScheme.primary,
                    child: glyph,
                  )
                : glyph,
      ),
    );
  }
}
