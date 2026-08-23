/// La **tuile Material d'un outil**, une par nature déclarée.
///
/// Le socle `zcrud_chat` rend ses réglages sans couleur ni graisse d'identité :
/// c'est une contrainte de sa position (il est consommé par des applications
/// dont il ne connaît pas le thème). Ici, dans le satellite Material, une
/// couleur de **rôle** (`ColorScheme`) est légitime, et une tuile a le droit
/// d'avoir la forme que Material lui donne :
///
/// | Nature | Forme rendue |
/// |---|---|
/// | bascule | `SwitchListTile`, ligne entière cliquable |
/// | cycle | ligne cliquable + **badge du cran** ; un tap = un cran |
/// | choix | `SegmentedButton` |
/// | échelle | curseur à repères textuels |
/// | catalogue | `FilterChip`, avec une puce « tout » |
/// | action | bouton |
/// | nature d'hôte | le builder de l'hôte, sinon rien |
///
/// ## Les règles qu'une tuile tient
///
/// * une entrée **désactivée est rendue et grisée**, jamais masquée, et porte
///   sa raison — masquer une affordance pose à l'utilisateur une question sans
///   réponse ;
/// * le sous-titre décrit **l'état courant**, pas la fonction de l'outil ;
/// * un tap refusé par le domaine est **absorbé** : rien ne change, rien ne
///   lève ;
/// * un `kind` inconnu tombe sur le builder de l'hôte, puis sur rien — jamais
///   sur une exception (invariants AD-4/AD-10) ;
/// * la tuile n'écoute que **sa** tranche : régler un outil ne reconstruit pas
///   les autres tuiles (invariant AD-2).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'z_chat_material_badge.dart';
import 'z_chat_material_labelled_slider.dart';
import 'z_chat_material_tool_labels.dart';

/// Construit — ou retire — la tuile d'une entrée résolue.
///
/// Rendre `null` ⇒ **aucun widget inséré** (invariant AD-4).
typedef ZChatMaterialToolTileBuilder =
    Widget? Function(
      BuildContext context,
      ZChatToolController controller,
      ZChatToolResolvedEntry resolved,
    );

/// La tuile d'un outil, branchée sur la tranche de son entrée.
class ZChatMaterialToolTile extends StatelessWidget {
  /// Construit la tuile de [toolKey].
  const ZChatMaterialToolTile({
    required this.controller,
    required this.toolKey,
    this.labels = const ZChatMaterialToolLabels(),
    this.kindBuilders = const <String, ZChatMaterialToolTileBuilder>{},
    this.unknownBuilder,
    this.onCommand,
    super.key,
  });

  /// Le contrôleur d'outils.
  final ZChatToolController controller;

  /// La clé de l'entrée rendue.
  final String toolKey;

  /// Les canaux de libellé et de glyphe de l'hôte.
  final ZChatMaterialToolLabels labels;

  /// Rendus d'hôte par `kind` — consultés **avant** le rendu par défaut.
  final Map<String, ZChatMaterialToolTileBuilder> kindBuilders;

  /// Rendu d'une nature que personne ne sait rendre. `null` ⇒ entrée absente
  /// de l'arbre, jamais une exception.
  final ZChatMaterialToolTileBuilder? unknownBuilder;

  /// Geste d'une action ponctuelle. `null` ⇒ l'action n'est pas rendue (une
  /// affordance inerte vaut moins que pas d'affordance).
  final void Function(String key)? onCommand;

  @override
  Widget build(BuildContext context) {
    // Abonné à SA tranche, et à rien d'autre (invariant AD-2).
    return ValueListenableBuilder<ZChatToolResolvedEntry?>(
      valueListenable: controller.entryOf(toolKey),
      builder:
          (
            BuildContext context,
            ZChatToolResolvedEntry? resolved,
            Widget? _,
          ) {
            if (resolved == null) return const SizedBox.shrink();
            final Widget? body = _body(context, resolved);
            if (body == null) return const SizedBox.shrink();
            return Semantics(
              container: true,
              enabled: resolved.isEnabled,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kZChatMinTapTarget,
                ),
                child: body,
              ),
            );
          },
    );
  }

  Widget? _body(BuildContext context, ZChatToolResolvedEntry resolved) {
    final ZChatMaterialToolTileBuilder? override =
        kindBuilders[resolved.entry.state.kind];
    if (override != null) return override(context, controller, resolved);
    final ZChatToolEntry entry = resolved.entry;
    final String key = entry.key;
    final bool enabled = resolved.isEnabled;
    final ZChatToolState state = entry.state;
    switch (state) {
      case ZChatToggleState():
        return SwitchListTile(
          value: state.value,
          onChanged: enabled
              ? (bool next) => controller.setEntryState(
                  key,
                  ZChatToggleState(value: next),
                )
              : null,
          title: _title(entry),
          subtitle: _subtitle(resolved),
          secondary: labels.iconOf?.call(key),
        );
      case ZChatCycleState():
        return ListTile(
          enabled: enabled,
          // Un tap = un cran. Le cran suivant — et le retour à zéro —
          // appartiennent au domaine : jamais un incrément écrit ici.
          onTap: enabled ? () => controller.advance(key) : null,
          leading: labels.iconOf?.call(key),
          title: _title(entry),
          subtitle: _subtitle(resolved),
          trailing: ZChatMaterialBadge(count: state.step),
        );
      case ZChatChoiceState():
        final List<ButtonSegment<String>> segments = <ButtonSegment<String>>[
          for (final String option in state.optionKeys)
            if (entry.stateLabels[option] != null)
              ButtonSegment<String>(
                value: option,
                label: Text(entry.stateLabels[option]!),
              ),
        ];
        if (segments.isEmpty) return null;
        return _block(
          context,
          entry,
          resolved,
          SegmentedButton<String>(
            segments: segments,
            selected: <String>{?state.selectedKey},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: enabled
                ? (Set<String> next) => controller.setEntryState(
                    key,
                    state.select(next.isEmpty ? null : next.first),
                  )
                : null,
          ),
        );
      case ZChatScaleState():
        return ZChatMaterialLabelledSlider(
          title: entry.label,
          value: state.value ?? state.min,
          min: state.min,
          max: state.max,
          divisions: state.marks.isEmpty ? null : state.marks.length - 1,
          marks: <String>[
            for (int i = 0; i < state.marks.length; i++)
              ?entry.stateLabels['mark.$i'],
          ],
          enabled: enabled,
          onChanged: (double next) =>
              controller.setEntryState(key, state.withValue(next)),
        );
      case ZChatCatalogState():
        return _block(
          context,
          entry,
          resolved,
          _catalogChips(context, resolved, state),
        );
      case ZChatCommandState():
        final String? label = entry.label;
        final void Function(String key)? command = onCommand;
        if (label == null || command == null) return null;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            onPressed: enabled ? () => command(key) : null,
            child: Text(label),
          ),
        );
      case ZChatCustomToolState():
        return unknownBuilder?.call(context, controller, resolved);
    }
  }

  /// Un contrôle large : titre, sous-titre d'état, puis le contrôle lui-même.
  Widget _block(
    BuildContext context,
    ZChatToolEntry entry,
    ZChatToolResolvedEntry resolved,
    Widget control,
  ) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            enabled: resolved.isEnabled,
            leading: labels.iconOf?.call(entry.key),
            title: _title(entry),
            subtitle: _subtitle(resolved),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: control,
          ),
        ],
      );

  Widget _catalogChips(
    BuildContext context,
    ZChatToolResolvedEntry resolved,
    ZChatCatalogState state,
  ) {
    final ZChatToolEntry entry = resolved.entry;
    final String key = entry.key;
    final bool enabled = resolved.isEnabled;
    final String? allLabel = labels.all;
    return Wrap(
      spacing: ZChatToolSheetReference.chipGap,
      runSpacing: ZChatToolSheetReference.chipGap,
      children: <Widget>[
        // Sélection vide ⇒ tout le catalogue : la puce « tout » n'est pas un
        // item de plus, c'est la lecture de l'état vide.
        if (allLabel != null)
          FilterChip(
            label: Text(allLabel),
            selected: state.selectedKeys.isEmpty,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: enabled
                ? (bool _) => controller.setEntryState(
                    key,
                    state.select(const <String>[]),
                  )
                : null,
          ),
        for (final String item in state.itemKeys)
          ?_catalogChip(context, resolved, state, item),
      ],
    );
  }

  Widget? _catalogChip(
    BuildContext context,
    ZChatToolResolvedEntry resolved,
    ZChatCatalogState state,
    String item,
  ) {
    final ZChatToolEntry entry = resolved.entry;
    final String? label =
        entry.stateLabels[item] ?? labels.itemLabelOf?.call(entry.key, item);
    if (label == null) return null;
    final bool available = state.isAvailable(item);
    final String? token = state.unavailableReasonToken;
    // Une entrée indisponible reste RENDUE : grisée, et porteuse de sa raison.
    final String? reason =
        available || token == null ? null : labels.reasonOf?.call(token);
    final Widget chip = FilterChip(
      label: Text(label),
      selected: state.selectedKeys.contains(item),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: resolved.isEnabled && available
          ? (bool _) => controller.setEntryState(
              entry.key,
              state.select(_toggled(state.selectedKeys, item)),
            )
          : null,
    );
    return reason == null ? chip : Tooltip(message: reason, child: chip);
  }

  Widget? _title(ZChatToolEntry entry) {
    final String? label = entry.label;
    // Le socle ne titre pas une entrée que l'hôte n'a pas nommée : afficher la
    // clé technique serait pire que l'absence de titre.
    return label == null ? null : Text(label, textAlign: TextAlign.start);
  }

  /// Le sous-titre : la **raison** quand l'entrée est grisée, sinon la
  /// description de l'état courant.
  Widget? _subtitle(ZChatToolResolvedEntry resolved) {
    final String? token = resolved.disabledReasonToken;
    final String? reason = token == null ? null : labels.reasonOf?.call(token);
    final String? text = reason ?? resolved.entry.describeState();
    return text == null ? null : Text(text, textAlign: TextAlign.start);
  }
}

List<String> _toggled(List<String> current, String key) => <String>[
      for (final String k in current)
        if (k != key) k,
      if (!current.contains(key)) key,
    ];
