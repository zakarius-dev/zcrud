/// L'**assemblage commun** du routage sur les pièces partagées : le sélecteur
/// de routeur dans le composer, le choix de repli par tâche dans la feuille.
///
/// Les deux écrans assemblés (`ZChatConversationScreen`,
/// `ZChatNotebookScreen`) et tout hôte qui monte lui-même
/// `ZDefaultChatComposer` + `ZChatSettingsSheet` passent par ces deux
/// fabriques : il n'existe pas de second câblage.
///
/// * [zChatRouteModelSlot] rend le créneau `modelBuilder` du composer : le
///   sélecteur de modèle existant, dont les options sont celles de l'hôte
///   (une par routeur), l'actif suit `ZChatRouteSession.routerId`, et la
///   sélection appelle `selectRouter`. Sans option, `null` — le créneau est
///   absent (invariant AD-4).
/// * [zChatSettingsSheetOf] rend la feuille projetée du catalogue d'outils
///   **et** de la session, et ne la reconstruit que quand l'un des deux
///   change de structure — jamais sur un jeton du fil (invariant AD-2). Sans
///   outils ni session, c'est la feuille nue, inchangée.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../routing/z_chat_route_session.dart';
import '../routing/z_chat_route_settings_adapter.dart';
import '../settings/z_chat_settings_controller.dart';
import '../tools/z_chat_tool_controller.dart';
import '../tools/z_chat_tool_settings_adapter.dart';
import 'z_chat_composer.dart';
import 'z_chat_composer_model_selector.dart';
import 'z_chat_settings_entry.dart';
import 'z_chat_settings_sheet.dart';

/// Le créneau du sélecteur de **routeur** pour `ZDefaultChatComposer.modelBuilder`.
///
/// [options] est le catalogue de l'hôte (un id = un routeur) ; vide ⇒ `null`.
/// L'actif suit [ZChatRouteSession.routerId] ; choisir appelle
/// [ZChatRouteSession.selectRouter]. Seul le sélecteur s'abonne.
ZChatComposerSlotBuilder? zChatRouteModelSlot({
  required ZChatRouteSession session,
  required List<ZChatModelOption> options,
  Widget? selectionMark,
  ZChatModelTriggerBuilder? triggerBuilder,
  ZChatModelMenuBuilder? menuBuilder,
}) {
  if (options.isEmpty) return null;
  return (BuildContext context, ZChatComposerSlot slot) =>
      ValueListenableBuilder<String?>(
        valueListenable: session.routerId,
        builder: (BuildContext context, String? active, Widget? _) =>
            ZChatComposerModelSelector(
              options: options,
              activeId: active,
              onSelect: (String id) => unawaited(session.selectRouter(id)),
              selectionMark: selectionMark,
              triggerBuilder: triggerBuilder,
              menuBuilder: menuBuilder,
            ),
      );
}

/// La feuille de réglages projetée des outils **et** de la session de routage.
///
/// [tools] projette ses sections et ses entrées ; [session] projette un choix
/// de repli par tâche, à condition que [modelLabelOf] et [taskLabelKeyOf]
/// soient fournis (sans libellé d'hôte, aucune entrée). La feuille suit les
/// deux contrôleurs ; sans aucun des deux, elle est rendue nue.
Widget zChatSettingsSheetOf(
  BuildContext context, {
  required ZChatSettingsController controller,
  ZChatToolController? tools,
  ZChatToolTokenResolver? toolReasonOf,
  void Function(String key)? onToolCommand,
  ZChatRouteSession? session,
  ZChatModelLabelResolver? modelLabelOf,
  ZChatTaskLabelKeyResolver? taskLabelKeyOf,
  String? routeSectionId,
  List<ZChatCorpusOption> corpusCatalog = const <ZChatCorpusOption>[],
  List<ZChatSettingsPreset> presetCatalog = const <ZChatSettingsPreset>[],
  List<ZChatSettingsHostOption> capabilityCatalog =
      const <ZChatSettingsHostOption>[],
  VoidCallback? onClose,
}) {
  Widget sheet(BuildContext context) => ZChatSettingsSheet(
    controller: controller,
    corpusCatalog: corpusCatalog,
    presetCatalog: presetCatalog,
    capabilityCatalog: capabilityCatalog,
    onClose: onClose,
    sections: tools == null
        ? const <ZChatSettingsSection>[]
        : zChatToolSettingsSections(tools),
    entries: <ZChatSettingsEntry>[
      if (tools != null)
        ...zChatToolSettingsEntries(
          tools,
          query: tools.query.value,
          reasonOf: toolReasonOf,
          onCommand: onToolCommand,
        ),
      if (session != null && modelLabelOf != null && taskLabelKeyOf != null)
        ...zChatRouteSettingsEntries(
          session,
          modelLabelOf: modelLabelOf,
          taskLabelKeyOf: taskLabelKeyOf,
          sectionId: routeSectionId,
        ),
    ],
  );
  final List<Listenable> deps = <Listenable>[?tools, ?session];
  if (deps.isEmpty) return sheet(context);
  // La feuille suit ses contrôleurs : une projection se refait quand un
  // catalogue ou un routeur change, jamais sur un jeton du fil.
  return ListenableBuilder(
    listenable: Listenable.merge(deps),
    builder: (BuildContext context, Widget? _) => sheet(context),
  );
}
