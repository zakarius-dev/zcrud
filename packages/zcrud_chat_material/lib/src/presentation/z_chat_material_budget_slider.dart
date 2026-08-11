/// Un slider Material labellisé pour le budget de calcul, alternative aux
/// chips par défaut de la feuille de réglages du socle.
///
/// Le socle rend le budget de calcul sous forme de chips par défaut ; ce
/// widget est l'écart assumé de ce satellite, à brancher explicitement :
///
/// ```dart
/// ZChatSettingsSheet(
///   controller: settings,
///   computeBudgetBuilder: zChatMaterialBudgetSlider(),
/// )
/// ```
///
/// Les bornes et le nombre de divisions viennent de
/// [ZChatComputeEffort.min]/[ZChatComputeEffort.max] — jamais d'un littéral
/// local — et l'écriture passe par `setComputeEffort`, la seule voie
/// d'écriture du contrôleur. Les repères textuels (rapide/équilibré/profond)
/// sont les libellés du registre du socle ; l'échelle visuelle sous le rail
/// est exclue de la sémantique, car le `Slider` porte déjà la valeur pour un
/// lecteur d'écran via `Slider.semanticFormatterCallback`.
///
/// Quand aucun budget n'est encore choisi (`computeEffort == null`,
/// signifiant « l'hôte décide »), le rail se positionne au palier médian
/// sans écrire dans le contrôleur : la première écriture reste un geste de
/// l'utilisateur, jamais un effet de bord du montage de la feuille.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Builder prêt-à-brancher sur `ZChatSettingsSheet.computeBudgetBuilder`.
ZChatSettingsTileBuilder zChatMaterialBudgetSlider() =>
    (BuildContext context, ZChatSettingsSlot slot) =>
        ZChatMaterialBudgetSlider(controller: slot.controller);

/// Le widget du slider — montable directement.
class ZChatMaterialBudgetSlider extends StatelessWidget {
  /// Construit la tuile.
  const ZChatMaterialBudgetSlider({required this.controller, super.key});

  /// Le contrôleur de réglages du socle.
  final ZChatSettingsController controller;

  @override
  Widget build(BuildContext context) {
    // Abonné uniquement à la tranche des réglages (invariant AD-2).
    return ValueListenableBuilder<ZChatGenerationSettings>(
      valueListenable: controller.settings,
      builder:
          (
            BuildContext context,
            ZChatGenerationSettings settings,
            Widget? _,
          ) {
            final int level =
                settings.computeEffort?.level ?? ZChatComputeEffort.medium.level;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  zChatLabel(context, kZChatLabelComputeBudget),
                  // Invariant AD-13 : jamais `TextAlign.left`.
                  textAlign: TextAlign.start,
                ),
                // Invariant AD-13 : la cible du pouce est tenue ≥ 48 dp en
                // géométrie rendue par la contrainte plancher.
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: kZChatMinTapTarget,
                  ),
                  child: Slider(
                    value: level.toDouble(),
                    min: ZChatComputeEffort.min.toDouble(),
                    max: ZChatComputeEffort.max.toDouble(),
                    // 1..5 ⇒ 4 pas — dérivé des bornes du kernel, jamais un
                    // littéral.
                    divisions: ZChatComputeEffort.max - ZChatComputeEffort.min,
                    label: _tierLabel(context, level),
                    semanticFormatterCallback: (double value) =>
                        _tierLabel(context, value.round()),
                    onChanged: (double value) => controller.setComputeEffort(
                      ZChatComputeEffort(value.round()),
                    ),
                  ),
                ),
                // Échelle décorative sous le rail : le `Slider` annonce déjà
                // le palier à l'accessibilité.
                ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(zChatLabel(context, kZChatLabelComputeBudgetFast)),
                      Text(
                        zChatLabel(context, kZChatLabelComputeBudgetBalanced),
                      ),
                      Text(zChatLabel(context, kZChatLabelComputeBudgetDeep)),
                    ],
                  ),
                ),
              ],
            );
          },
    );
  }
}

/// Palier → repère textuel, dérivé des bornes du kernel — jamais un seuil
/// littéral local.
String _tierLabel(BuildContext context, int level) {
  if (level <= ZChatComputeEffort.low.level) {
    return zChatLabel(context, kZChatLabelComputeBudgetFast);
  }
  if (level >= ZChatComputeEffort.high.level) {
    return zChatLabel(context, kZChatLabelComputeBudgetDeep);
  }
  return zChatLabel(context, kZChatLabelComputeBudgetBalanced);
}
