/// Le **slider Material labellisé** du budget de calcul — lot K3.
///
/// C'est le pixel-perfect de la tuile « Réflexion » de lex : `Slider` 1..5 à
/// divisions, étiquette de palier (Rapide/Équilibré/Profond) et échelle sous le
/// rail (`tools_sheet.dart:322-392`). Le socle, lui, garde ses **chips** par
/// défaut (verdict F4 de l'étude, verrouillé par SET-S1/CR-74) — ce slider est
/// l'ÉCART ASSUMÉ du satellite, à brancher explicitement :
///
/// ```dart
/// ZChatSettingsSheet(
///   controller: settings,
///   computeBudgetBuilder: zChatMaterialBudgetSlider(),
/// )
/// ```
///
/// * bornes et divisions viennent de [ZChatComputeEffort.min]/[max] — jamais
///   des littéraux ; l'écriture passe par `setComputeEffort` (voie unique) ;
/// * les repères Rapide/Équilibré/Profond sont les libellés du registre du
///   socle (les mêmes clés que l'échelle des chips K2) ; l'échelle visuelle est
///   `ExcludeSemantics` — le `Slider` porte déjà la valeur pour un lecteur
///   d'écran ([Slider.semanticFormatterCallback]) ;
/// * budget ABSENT (`computeEffort == null` = « l'hôte décide ») : le rail se
///   pose au palier médian SANS écrire — la première écriture est un geste
///   utilisateur, jamais un effet de montage (le montage d'une feuille ne
///   change pas la requête).
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
    // 🔴 LA tranche des réglages, et elle seule (SM-1).
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
                  // AD-13 : jamais `TextAlign.left`.
                  textAlign: TextAlign.start,
                ),
                // 🔴 AD-13 : la cible du pouce est tenue ≥ 48 dp en géométrie
                // RENDUE par la contrainte plancher — pas par une promesse de
                // thème.
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
                // L'échelle lex (Rapide/Équilibré/Profond) sous le rail —
                // décorative : le `Slider` annonce déjà le palier.
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

/// Palier → repère, par PROJECTION des bornes du kernel (`low`/`high` sont les
/// projections IFFD 1/5) : jamais un seuil littéral.
String _tierLabel(BuildContext context, int level) {
  if (level <= ZChatComputeEffort.low.level) {
    return zChatLabel(context, kZChatLabelComputeBudgetFast);
  }
  if (level >= ZChatComputeEffort.high.level) {
    return zChatLabel(context, kZChatLabelComputeBudgetDeep);
  }
  return zChatLabel(context, kZChatLabelComputeBudgetBalanced);
}
