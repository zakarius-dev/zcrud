/// La **projection** d'un catalogue d'outils vers les entrées déclaratives de
/// la feuille de réglages.
///
/// Un `ZChatToolCatalog` et une `ZChatSettingsEntry` ne répondent pas à la
/// même question : le premier sait **où en est** un outil, la seconde sait
/// **comment une tuile se rend**. Ce fichier joint les deux sans que l'un
/// remplace l'autre — les familles standard de la feuille restent intactes, et
/// les outils déclarés par l'hôte s'injectent dans les **mêmes** sections.
///
/// ## Les règles que la projection tient
///
/// * une entrée **grisée** est projetée, avec sa raison en sous-titre — elle
///   n'est **jamais** retirée ;
/// * le sous-titre décrit **l'état courant** (`describeState()`), jamais la
///   fonction de l'outil ;
/// * un cran de cycle passe par `advance` : la projection ne calcule jamais
///   le cran suivant ;
/// * un `kind` inconnu devient un [ZChatToolCustomControl] — jamais un
///   `throw` (invariants AD-4/AD-10) ;
/// * aucune valeur textuelle n'est inventée ici : tout libellé vient de
///   l'hôte (`label`, `stateLabels`) ou de son résolveur de jetons (FR-26).
///   Une entrée **sans libellé d'hôte** n'est pas projetée : la feuille de
///   réglages exige un titre, et afficher la clé technique à sa place serait
///   pire que l'absence.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import '../view/z_chat_settings_entry.dart';
import 'z_chat_tool_controller.dart';

/// Résout un jeton opaque (raison de grisage, indisponibilité) en texte déjà
/// localisé. Rendre `null` ⇒ aucun texte affiché pour ce jeton.
typedef ZChatToolTokenResolver = String? Function(String token);

/// Kind d'un contrôle porté par une **nature d'hôte** — la valeur exacte du
/// `kind` déclaré, de sorte qu'un hôte le cible par `kindBuilders`.
class ZChatToolCustomControl implements ZChatSettingsControl {
  /// Construit le contrôle d'échappatoire.
  const ZChatToolCustomControl(this.entry);

  /// L'entrée résolue, telle que le domaine la donne.
  final ZChatToolResolvedEntry entry;

  @override
  String get kind => entry.entry.state.kind;
}

/// Les sections de la feuille de réglages correspondant aux sections du
/// catalogue. Une section sans libellé d'hôte reste **sans en-tête**.
List<ZChatSettingsSection> zChatToolSettingsSections(
  ZChatToolController controller,
) => <ZChatSettingsSection>[
      for (final ZChatToolSection s in controller.catalog.sections)
        ZChatSettingsSection(
          id: s.key,
          title: s.label == null ? null : ZChatSettingsLabel.text(s.label!),
        ),
    ];

/// Projette les outils **visibles sur la feuille** en entrées déclaratives.
///
/// [query] filtre le rendu (jamais le comptage) ; [reasonOf] résout les jetons
/// de raison ; [onCommand] reçoit le geste d'une action ponctuelle — sans lui,
/// une action n'est pas projetée (jamais une affordance inerte).
List<ZChatSettingsEntry> zChatToolSettingsEntries(
  ZChatToolController controller, {
  String query = '',
  ZChatToolTokenResolver? reasonOf,
  void Function(String key)? onCommand,
}) {
  final ZChatToolResolution resolution = controller.catalog.resolve(
    query: query,
  );
  final List<ZChatSettingsEntry> out = <ZChatSettingsEntry>[];
  for (final ZChatToolResolvedEntry resolved in resolution.entries) {
    final ZChatSettingsEntry? projected = _project(
      controller,
      resolved,
      reasonOf,
      onCommand,
    );
    if (projected != null) out.add(projected);
  }
  return out;
}

ZChatSettingsEntry? _project(
  ZChatToolController controller,
  ZChatToolResolvedEntry resolved,
  ZChatToolTokenResolver? reasonOf,
  void Function(String key)? onCommand,
) {
  final ZChatToolEntry entry = resolved.entry;
  final String? title = entry.label;
  if (title == null) return null;
  final ZChatSettingsControl? control = _control(
    controller,
    resolved,
    onCommand,
  );
  if (control == null) return null;
  final String? subtitle = _subtitle(resolved, reasonOf);
  return ZChatSettingsEntry(
    id: entry.key,
    title: ZChatSettingsLabel.text(title),
    control: control,
    sectionId: entry.sectionKey,
    subtitle: subtitle == null ? null : ZChatSettingsLabel.text(subtitle),
  );
}

/// Le sous-titre : la **raison** quand l'entrée est grisée (l'utilisateur a
/// besoin de savoir pourquoi il ne peut pas), sinon la description de l'état.
String? _subtitle(
  ZChatToolResolvedEntry resolved,
  ZChatToolTokenResolver? reasonOf,
) {
  final String? token = resolved.disabledReasonToken;
  if (token != null) {
    final String? reason = reasonOf?.call(token);
    if (reason != null) return reason;
  }
  return resolved.entry.describeState();
}

ZChatSettingsControl? _control(
  ZChatToolController controller,
  ZChatToolResolvedEntry resolved,
  void Function(String key)? onCommand,
) {
  final ZChatToolEntry entry = resolved.entry;
  final String key = entry.key;
  final ZChatToolState state = entry.state;
  switch (state) {
    case ZChatToggleState():
      return ZChatToggleControl(
        value: state.value,
        // Le refus d'une entrée grisée arrive du domaine sous forme de `Left`
        // et est absorbé ici : un tap sur une tuile grisée est inerte, jamais
        // une exception.
        onChanged: (bool next) => controller.setEntryState(
          key,
          ZChatToggleState(value: next),
        ),
      );
    case ZChatCycleState():
      // Un cran = un appel à `advance`. La projection ne calcule jamais le
      // cran suivant : le retour à zéro appartient au domaine.
      return ZChatNavigationControl(
        onTap: () => controller.advance(key),
        value: _stateLabel(entry),
      );
    case ZChatChoiceState():
      final List<ZChatSettingsChoice> choices = <ZChatSettingsChoice>[
        for (final String option in state.optionKeys)
          if (entry.stateLabels[option] != null)
            ZChatSettingsChoice(
              label: ZChatSettingsLabel.text(entry.stateLabels[option]!),
              selected: state.selectedKey == option,
              enabled: resolved.isEnabled,
              onTap: () => controller.setEntryState(key, state.select(option)),
            ),
      ];
      if (choices.isEmpty) return null;
      return ZChatSelectControl(choices: choices);
    case ZChatScaleState():
      final List<ZChatSettingsChoice> choices = <ZChatSettingsChoice>[
        for (int i = 0; i < state.marks.length; i++)
          if (entry.stateLabels['mark.$i'] != null)
            ZChatSettingsChoice(
              label: ZChatSettingsLabel.text(entry.stateLabels['mark.$i']!),
              selected: state.nearestMarkIndex == i,
              enabled: resolved.isEnabled,
              onTap: () => controller.setEntryState(
                key,
                state.withValue(state.marks[i]),
              ),
            ),
      ];
      if (choices.isEmpty) return null;
      return ZChatScaleControl(choices: choices);
    case ZChatCatalogState():
      final List<ZChatSettingsChoice> choices = <ZChatSettingsChoice>[
        for (final String item in state.itemKeys)
          if (entry.stateLabels[item] != null)
            ZChatSettingsChoice(
              label: ZChatSettingsLabel.text(entry.stateLabels[item]!),
              selected: state.selectedKeys.contains(item),
              // Une entrée indisponible reste RENDUE et non sélectionnable :
              // la masquer poserait la question sans réponse « pourquoi la
              // mienne n'est-elle pas là ? ».
              enabled: resolved.isEnabled && state.isAvailable(item),
              onTap: () => controller.setEntryState(
                key,
                state.select(_toggled(state.selectedKeys, item)),
              ),
            ),
      ];
      if (choices.isEmpty) return null;
      return ZChatSelectControl(choices: choices);
    case ZChatCommandState():
      if (onCommand == null) return null;
      return ZChatNavigationControl(onTap: () => onCommand(key));
    case ZChatCustomToolState():
      return ZChatToolCustomControl(resolved);
  }
}

ZChatSettingsLabel? _stateLabel(ZChatToolEntry entry) {
  final String? described = entry.describeState();
  return described == null ? null : ZChatSettingsLabel.text(described);
}

List<String> _toggled(List<String> current, String key) => <String>[
      for (final String k in current)
        if (k != key) k,
      if (!current.contains(key)) key,
    ];
