/// Les familles de réglages rendues en **rangée de puces de choix** :
/// verbosité, biais de régénération, préréglages.
///
/// Une seule primitive ([ZChatMaterialChoiceChips]) porte la forme — puces
/// `ChoiceChip` en `Wrap`, l'option choisie teintée du rôle
/// `primaryContainer`, chaque puce tenue au plancher tactile — et les trois
/// familles ne font que la brancher sur leur tranche du contrôleur.
///
/// Chaque famille lit **sa** tranche et écrit par le geste du contrôleur qui
/// lui correspond (`setResponseLength`, `setLengthBias`, `applyPreset` /
/// `clearPreset`) : monter la tuile n'écrit rien, la première écriture est un
/// geste de l'utilisateur.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'z_chat_material_settings_reference.dart';

/// Une option d'une rangée de puces.
@immutable
class ZChatMaterialChoice<T> {
  /// Construit une option.
  const ZChatMaterialChoice({
    required this.value,
    required this.label,
    required this.selected,
    this.enabled = true,
  });

  /// La valeur rendue au geste quand l'option est choisie.
  final T value;

  /// Libellé, déjà résolu.
  final String label;

  /// `true` pour l'option choisie.
  final bool selected;

  /// `false` rend la puce présente mais non sélectionnable.
  final bool enabled;
}

/// Rangée de puces de choix : un titre, puis les options en `Wrap`.
class ZChatMaterialChoiceChips<T> extends StatelessWidget {
  /// Construit la rangée.
  const ZChatMaterialChoiceChips({
    required this.options,
    required this.onSelect,
    this.title,
    super.key,
  });

  /// Titre de la famille. `null` ⇒ aucun titre.
  final String? title;

  /// Les options, dans l'ordre de rendu.
  final List<ZChatMaterialChoice<T>> options;

  /// Geste d'une option choisie.
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? heading = title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (heading != null) ...<Widget>[
          Text(
            heading,
            textAlign: TextAlign.start,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: ZChatMaterialSettingsReference.blockGap),
        ],
        // Un `Wrap` plutôt qu'un `SegmentedButton` : les libellés viennent de
        // l'hôte, dans sa langue, sans borne de largeur. Sous un petit écran,
        // une rangée de segments déborde là où des puces passent à la ligne.
        Wrap(
          spacing: ZChatMaterialSettingsReference.chipGap,
          runSpacing: ZChatMaterialSettingsReference.chipGap,
          children: <Widget>[
            for (final ZChatMaterialChoice<T> option in options)
              ChoiceChip(
                label: Text(option.label),
                selected: option.selected,
                // Le rôle de couleur sur l'état choisi — ce que le socle
                // s'interdit, et que ce satellite a le droit de poser.
                selectedColor: theme.colorScheme.primaryContainer,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: option.enabled
                    ? (bool _) => onSelect(option.value)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

// ── Verbosité ─────────────────────────────────────────────────────────────

/// Builder prêt-à-brancher sur `ZChatSettingsSheet.responseLengthBuilder`.
ZChatSettingsTileBuilder zChatMaterialResponseLengthChips() =>
    (BuildContext context, ZChatSettingsSlot slot) =>
        ZChatMaterialResponseLengthChips(controller: slot.controller);

/// La verbosité (`ZChatResponseLength`), « automatique » compris.
class ZChatMaterialResponseLengthChips extends StatelessWidget {
  /// Construit la tuile.
  const ZChatMaterialResponseLengthChips({
    required this.controller,
    super.key,
  });

  /// Le contrôleur de réglages du socle.
  final ZChatSettingsController controller;

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
            ) => ZChatMaterialChoiceChips<ZChatResponseLength?>(
              title: zChatLabel(context, kZChatLabelResponseLength),
              options: <ZChatMaterialChoice<ZChatResponseLength?>>[
                ZChatMaterialChoice<ZChatResponseLength?>(
                  value: null,
                  label: zChatLabel(context, kZChatLabelSettingAuto),
                  selected: settings.responseLength == null,
                ),
                for (final ZChatResponseLength value
                    in ZChatResponseLength.values)
                  ZChatMaterialChoice<ZChatResponseLength?>(
                    value: value,
                    label: zChatLabel(context, _responseLengthKey(value)),
                    selected: settings.responseLength == value,
                  ),
              ],
              onSelect: controller.setResponseLength,
            ),
      );
}

// Palier → clé de libellé : un `switch` EXHAUSTIF, pour qu'un palier ajouté
// au kernel casse la compilation ici au lieu de disparaître de la feuille.
String _responseLengthKey(ZChatResponseLength value) => switch (value) {
      ZChatResponseLength.concise => kZChatLabelLengthConcise,
      ZChatResponseLength.standard => kZChatLabelLengthStandard,
      ZChatResponseLength.detailed => kZChatLabelLengthDetailed,
    };

// ── Biais de régénération ─────────────────────────────────────────────────

/// Builder prêt-à-brancher sur `ZChatSettingsSheet.lengthBiasBuilder`.
ZChatSettingsTileBuilder zChatMaterialLengthBiasChips() =>
    (BuildContext context, ZChatSettingsSlot slot) =>
        ZChatMaterialLengthBiasChips(controller: slot.controller);

/// Le biais de régénération (`ZChatLengthBias`), « automatique » compris.
class ZChatMaterialLengthBiasChips extends StatelessWidget {
  /// Construit la tuile.
  const ZChatMaterialLengthBiasChips({required this.controller, super.key});

  /// Le contrôleur de réglages du socle.
  final ZChatSettingsController controller;

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
            ) => ZChatMaterialChoiceChips<ZChatLengthBias?>(
              title: zChatLabel(context, kZChatLabelLengthBias),
              options: <ZChatMaterialChoice<ZChatLengthBias?>>[
                ZChatMaterialChoice<ZChatLengthBias?>(
                  value: null,
                  label: zChatLabel(context, kZChatLabelSettingAuto),
                  selected: settings.lengthBias == null,
                ),
                for (final ZChatLengthBias value in ZChatLengthBias.values)
                  ZChatMaterialChoice<ZChatLengthBias?>(
                    value: value,
                    label: zChatLabel(context, _lengthBiasKey(value)),
                    selected: settings.lengthBias == value,
                  ),
              ],
              onSelect: controller.setLengthBias,
            ),
      );
}

String _lengthBiasKey(ZChatLengthBias value) => switch (value) {
      ZChatLengthBias.shorter => kZChatLabelBiasShorter,
      ZChatLengthBias.asIs => kZChatLabelBiasAsIs,
      ZChatLengthBias.longer => kZChatLabelBiasLonger,
    };

// ── Préréglages ───────────────────────────────────────────────────────────

/// Builder prêt-à-brancher sur `ZChatSettingsSheet.presetsBuilder`.
///
/// Catalogue vide ⇒ le builder rend `null` : aucune tuile (invariant AD-4).
ZChatSettingsTileBuilder zChatMaterialPresetChips() =>
    (BuildContext context, ZChatSettingsSlot slot) =>
        slot.presetCatalog.isEmpty
            ? null
            : ZChatMaterialPresetChips(
                controller: slot.controller,
                catalog: slot.presetCatalog,
              );

/// Les préréglages de l'hôte, « aucun » compris.
///
/// « Aucun » restitue l'état d'avant le premier préréglage (`clearPreset`) ;
/// un préréglage s'applique avec mémoire (`applyPreset`).
class ZChatMaterialPresetChips extends StatelessWidget {
  /// Construit la tuile.
  const ZChatMaterialPresetChips({
    required this.controller,
    required this.catalog,
    super.key,
  });

  /// Le contrôleur de réglages du socle.
  final ZChatSettingsController controller;

  /// Les préréglages de l'hôte, dans l'ordre de rendu.
  final List<ZChatSettingsPreset> catalog;

  @override
  Widget build(BuildContext context) =>
      // Abonné uniquement à la tranche du préréglage actif (invariant AD-2).
      ValueListenableBuilder<String?>(
        valueListenable: controller.activePresetId,
        builder: (BuildContext context, String? active, Widget? _) =>
            ZChatMaterialChoiceChips<ZChatSettingsPreset?>(
              title: zChatLabel(context, kZChatLabelPresets),
              options: <ZChatMaterialChoice<ZChatSettingsPreset?>>[
                ZChatMaterialChoice<ZChatSettingsPreset?>(
                  value: null,
                  label: zChatLabel(context, kZChatLabelPresetNone),
                  selected: active == null,
                ),
                for (final ZChatSettingsPreset preset in catalog)
                  ZChatMaterialChoice<ZChatSettingsPreset?>(
                    value: preset,
                    label: preset.label,
                    selected: active == preset.id,
                  ),
              ],
              onSelect: (ZChatSettingsPreset? preset) => preset == null
                  ? controller.clearPreset()
                  : controller.applyPreset(
                      preset.id,
                      preset.settings,
                      preset.corpusScope,
                    ),
            ),
      );
}
