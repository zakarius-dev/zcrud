/// **La superposition de candidats** — un seul panneau pour les mentions et
/// pour les commandes.
///
/// Deux panneaux jumeaux divergeraient : l'un gagnerait la navigation au
/// clavier, l'autre l'annonce sémantique, et personne ne saurait lequel fait
/// foi. Il n'y en a donc qu'un, alimenté par la projection commune du
/// contrôleur.
///
/// ## Ce que le panneau garantit (invariant AD-13)
///
/// * chaque candidat est une cible d'au moins [kZChatMinTapTarget] ;
/// * la liste est annoncée comme telle, et chaque ligne dit si elle est mise
///   en avant et si elle est disponible ;
/// * elle se ferme **sans rien choisir** ;
/// * elle est virtualisée (`ListView.builder`), jamais construite d'un bloc.
///
/// ## Ce qu'il ne peint pas
///
/// Ni couleur, ni fond, ni glyphe : le socle n'impose aucun système de design
/// (invariant FR-26). La mise en avant est portée par la **sémantique**, et le
/// rendu d'une ligne est remplaçable par [itemBuilder] — c'est là que l'hôte
/// met sa surbrillance, son icône et sa typographie.
library;

import 'package:flutter/widgets.dart';

import 'z_chat_composer_affordance.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// Rendu d'hôte d'une ligne. Rendre `null` rend la ligne par défaut.
typedef ZChatComposerAffordanceItemBuilder =
    Widget? Function(
      BuildContext context,
      ZChatComposerAffordanceEntry entry,
      bool isSelected,
    );

/// Le panneau de candidats.
class ZChatComposerAffordanceOverlay extends StatelessWidget {
  /// Construit le panneau.
  const ZChatComposerAffordanceOverlay({
    super.key,
    required this.controller,
    this.itemBuilder,
    this.maxHeight = 240,
  });

  /// Le contrôleur dont l'état est rendu.
  final ZChatComposerAffordanceController controller;

  /// Rendu d'hôte d'une ligne, ou `null` pour le rendu par défaut.
  final ZChatComposerAffordanceItemBuilder? itemBuilder;

  /// Hauteur maximale du panneau. Au-delà, la liste défile.
  final double maxHeight;

  /// La clé de la cible tactile du candidat [key] — le point de mesure d'une
  /// garde de cible, et le point d'ancrage d'un test d'hôte.
  static ValueKey<String> targetKey(String key) =>
      ValueKey<String>('zchat.affordance.$key');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZChatComposerAffordanceState>(
      valueListenable: controller.state,
      builder: (
        BuildContext context,
        ZChatComposerAffordanceState state,
        Widget? _,
      ) {
        if (!state.isOpen || state.entries.isEmpty) {
          return const SizedBox.shrink();
        }
        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: zChatLabel(context, kZChatLabelAffordanceCandidates),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.entries.length,
              itemBuilder: (BuildContext context, int index) {
                final ZChatComposerAffordanceEntry e = state.entries[index];
                return _ZChatAffordanceLine(
                  key: targetKey(e.key),
                  entry: e,
                  isSelected: index == state.selectedIndex,
                  onTap: () {
                    controller.select(index);
                    controller.commit();
                  },
                  itemBuilder: itemBuilder,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Une ligne — cible tactile conforme, annoncée, et jamais peinte.
class _ZChatAffordanceLine extends StatelessWidget {
  const _ZChatAffordanceLine({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onTap,
    this.itemBuilder,
  });

  final ZChatComposerAffordanceEntry entry;
  final bool isSelected;
  final VoidCallback onTap;
  final ZChatComposerAffordanceItemBuilder? itemBuilder;

  @override
  Widget build(BuildContext context) {
    final Widget corps =
        itemBuilder?.call(context, entry, isSelected) ??
        Column(
          mainAxisSize: MainAxisSize.min,
          // Invariant AD-13 : alignement directionnel.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Le libellé d'hôte, ou la clé — le socle n'invente pas de texte
            // (invariant FR-26).
            Text(entry.label ?? entry.key, textAlign: TextAlign.start),
            if (entry.sublabel != null)
              Text(entry.sublabel!, textAlign: TextAlign.start),
          ],
        );
    return Semantics(
      button: true,
      enabled: entry.isEnabled,
      selected: isSelected,
      label: entry.label ?? entry.key,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: entry.isEnabled ? onTap : null,
        child: ConstrainedBox(
          // La cible est portée par CETTE boîte — celle qui reçoit le geste —
          // et non par le texte qu'elle contient.
          constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
          child: Align(
            // Invariant AD-13 : alignement directionnel.
            alignment: AlignmentDirectional.centerStart,
            heightFactor: 1,
            child: corps,
          ),
        ),
      ),
    );
  }
}
