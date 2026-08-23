/// La **projection** d'une session de routage vers les entrées déclaratives
/// de la feuille de réglages : un choix de repli par tâche.
///
/// Une route qui déclare au moins **deux** candidats (son modèle et ses
/// replis, `ZChatRouteResolution.modelCandidates`) devient une entrée de
/// choix, liée à `ZChatRouteSession.overrideOf` / `setModelOverride`. Une
/// route à candidat unique n'offre aucun choix : elle n'est pas projetée.
///
/// ## Aucun libellé inventé
///
/// Le socle ne connaît ni nom de modèle ni nom de tâche. Le libellé d'un
/// candidat vient de l'hôte (`modelLabelOf`) ; celui d'une tâche est une
/// clé de libellé de l'hôte (`taskLabelKeyOf`), résolue par le registre au
/// rendu. Un candidat sans libellé est **absent** de l'entrée ; une tâche
/// sans clé, ou dont moins de deux candidats sont libellés, est **absente**
/// de la feuille. Jamais une clé technique à l'écran.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import '../view/z_chat_settings_entry.dart';
import 'z_chat_route_session.dart';

/// Libellé déjà localisé d'un modèle, ou `null` (candidat non proposé).
typedef ZChatModelLabelResolver = String? Function(ZChatModelRef ref);

/// Clé de libellé d'une tâche, ou `null` (tâche non projetée).
typedef ZChatTaskLabelKeyResolver = String? Function(String taskKey);

/// Préfixe des identifiants d'entrée projetés (`<préfixe><clé de tâche>`).
const String kZChatRouteEntryIdPrefix = 'zchat.route.';

/// Projette les routes à choix du routeur chargé en entrées de feuille.
///
/// [sectionId] place les entrées dans une section déclarée par l'hôte ;
/// `null` les laisse dans la section de génération du socle.
List<ZChatSettingsEntry> zChatRouteSettingsEntries(
  ZChatRouteSession session, {
  required ZChatModelLabelResolver modelLabelOf,
  required ZChatTaskLabelKeyResolver taskLabelKeyOf,
  String? sectionId,
}) {
  final ZChatRouter? router = session.router.value;
  if (router == null) return const <ZChatSettingsEntry>[];
  final List<ZChatSettingsEntry> out = <ZChatSettingsEntry>[];
  for (final String taskKey in router.routes.keys) {
    final ZChatSettingsEntry? entry = _project(
      session,
      router,
      taskKey,
      modelLabelOf,
      taskLabelKeyOf,
      sectionId,
    );
    if (entry != null) out.add(entry);
  }
  return out;
}

ZChatSettingsEntry? _project(
  ZChatRouteSession session,
  ZChatRouter router,
  String taskKey,
  ZChatModelLabelResolver modelLabelOf,
  ZChatTaskLabelKeyResolver taskLabelKeyOf,
  String? sectionId,
) {
  final ZChatRouteResolution res = ZChatRouteResolution.from(router, taskKey);
  final List<ZChatModelRef> candidates = res.modelCandidates;
  if (candidates.length < 2) return null;
  final String? titleKey = taskLabelKeyOf(taskKey);
  if (titleKey == null) return null;
  final ZChatModelRef? override = session.overrideOf(taskKey).value;
  // Sans repli choisi, le candidat actif est le modèle de la route — le
  // premier de la liste — et c'est lui que la feuille coche.
  final ZChatModelRef active = override ?? candidates.first;
  final List<ZChatSettingsChoice> choices = <ZChatSettingsChoice>[];
  for (final ZChatModelRef candidate in candidates) {
    final String? label = modelLabelOf(candidate);
    if (label == null) continue;
    choices.add(
      ZChatSettingsChoice(
        label: ZChatSettingsLabel.text(label),
        selected: candidate == active,
        // Choisir le modèle de la route, c'est ne plus rien forcer.
        onTap: () => session.setModelOverride(
          taskKey,
          candidate == candidates.first ? null : candidate,
        ),
      ),
    );
  }
  if (choices.length < 2) return null;
  return ZChatSettingsEntry(
    id: '$kZChatRouteEntryIdPrefix$taskKey',
    title: ZChatSettingsLabel.key(titleKey),
    control: ZChatSelectControl(choices: choices),
    sectionId: sectionId,
  );
}
