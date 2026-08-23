/// La **portée documentaire** en puces filtrantes (`FilterChip`).
///
/// Une puce par corpus du catalogue de l'hôte, précédée — quand l'hôte l'a
/// nommée — d'une puce « tous » qui lit l'état vide (aucune restriction).
/// Une entrée indisponible reste **rendue et grisée**, porteuse de sa raison
/// quand l'hôte la fournit : masquer une affordance pose à l'utilisateur une
/// question sans réponse.
///
/// **Filtres à deux niveaux** : une entrée sélectionnée dont le catalogue
/// porte des enfants déroule sa propre rangée (« tous » + une puce par
/// enfant). Désélectionner l'entrée retire aussi ses clés d'enfants : une
/// portée ne garde jamais de clé orpheline.
///
/// La tuile lit la tranche de la portée et écrit par `toggleCorpusKey` /
/// `setCorpusScope` — les gestes du contrôleur, jamais un canal parallèle.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'z_chat_material_settings_labels.dart';
import 'z_chat_material_settings_reference.dart';

/// Builder prêt-à-brancher sur `ZChatSettingsSheet.corpusBuilder`.
///
/// Catalogue vide ⇒ le builder rend `null` : aucune tuile (invariant AD-4).
ZChatSettingsTileBuilder zChatMaterialCorpusChips({
  ZChatMaterialSettingsLabels labels = const ZChatMaterialSettingsLabels(),
}) =>
    (BuildContext context, ZChatSettingsSlot slot) =>
        slot.corpusCatalog.isEmpty
            ? null
            : ZChatMaterialCorpusChips(
                controller: slot.controller,
                catalog: slot.corpusCatalog,
                labels: labels,
              );

/// La portée documentaire, en puces filtrantes.
class ZChatMaterialCorpusChips extends StatelessWidget {
  /// Construit la tuile.
  const ZChatMaterialCorpusChips({
    required this.controller,
    required this.catalog,
    this.labels = const ZChatMaterialSettingsLabels(),
    super.key,
  });

  /// Le contrôleur de réglages du socle.
  final ZChatSettingsController controller;

  /// Le catalogue de corpus de l'hôte.
  final List<ZChatCorpusOption> catalog;

  /// Les canaux de libellé de l'hôte.
  final ZChatMaterialSettingsLabels labels;

  @override
  Widget build(BuildContext context) =>
      // Abonné uniquement à la tranche de la portée (invariant AD-2) : régler
      // la verbosité ne reconstruit pas ces puces.
      ValueListenableBuilder<ZChatCorpusScope?>(
        valueListenable: controller.corpusScope,
        builder: (BuildContext context, ZChatCorpusScope? scope, Widget? _) =>
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  zChatLabel(context, kZChatLabelCorpusScope),
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(
                  height: ZChatMaterialSettingsReference.blockGap,
                ),
                _row(
                  context,
                  options: catalog,
                  allSelected: scope == null,
                  onAll: () => controller.setCorpusScope(null),
                ),
                for (final ZChatCorpusOption option in catalog)
                  if (option.children.isNotEmpty &&
                      controller.selectsCorpusKey(option.key))
                    Padding(
                      // Indentation DIRECTIONNELLE du second niveau (AD-13).
                      padding: const EdgeInsetsDirectional.only(
                        start: ZChatMaterialSettingsReference.childIndent,
                        top: ZChatMaterialSettingsReference.chipGap,
                      ),
                      child: _row(
                        context,
                        options: option.children,
                        allSelected: !option.children.any(
                          (ZChatCorpusOption c) =>
                              controller.selectsCorpusKey(c.key),
                        ),
                        onAll: () => _removeKeys(
                          option.children.map((ZChatCorpusOption c) => c.key),
                        ),
                      ),
                    ),
              ],
            ),
      );

  Widget _row(
    BuildContext context, {
    required List<ZChatCorpusOption> options,
    required bool allSelected,
    required VoidCallback onAll,
  }) {
    final String? all = labels.all;
    return Wrap(
      spacing: ZChatMaterialSettingsReference.chipGap,
      runSpacing: ZChatMaterialSettingsReference.chipGap,
      children: <Widget>[
        // La puce « tous » n'est pas un corpus de plus : c'est la lecture de
        // l'état vide. Elle n'existe que si l'hôte l'a nommée.
        if (all != null)
          FilterChip(
            label: Text(all),
            selected: allSelected,
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (bool _) => onAll(),
          ),
        for (final ZChatCorpusOption option in options) _chip(context, option),
      ],
    );
  }

  Widget _chip(BuildContext context, ZChatCorpusOption option) {
    final bool selected = controller.selectsCorpusKey(option.key);
    // Une entrée indisponible reste RENDUE : grisée, et porteuse de sa raison.
    final String? reason =
        option.enabled ? null : labels.reasonOf?.call(option.key);
    final Widget chip = FilterChip(
      key: ValueKey<String>(option.key),
      label: Text(option.label),
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: option.enabled
          ? (bool _) => selected && option.children.isNotEmpty
              // Désélection d'un parent : ses enfants sortent AVEC lui.
              ? _removeKeys(<String>[
                  option.key,
                  ...option.children.map((ZChatCorpusOption c) => c.key),
                ])
              : controller.toggleCorpusKey(option.key)
          : null,
    );
    return reason == null ? chip : Tooltip(message: reason, child: chip);
  }

  /// Retire [keys] de la portée courante par `setCorpusScope`.
  void _removeKeys(Iterable<String> keys) {
    final Set<String> removed = keys.toSet();
    final List<String> next = <String>[
      for (final String k
          in controller.corpusScope.value?.corpusKeys ?? const <String>[])
        if (!removed.contains(k)) k,
    ];
    controller.setCorpusScope(
      next.isEmpty ? null : ZChatCorpusScope.ofKeys(next),
    );
  }
}
