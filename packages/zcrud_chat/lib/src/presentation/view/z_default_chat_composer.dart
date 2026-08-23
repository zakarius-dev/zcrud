/// L'assemblage par défaut du composer : le socle ne livre plus seulement
/// les pièces, il livre la barre, personnalisable pièce par pièce.
///
/// ## Pourquoi un widget nouveau, pas un défaut de `ZChatComposer`
///
/// L'arbre de `ZChatComposer` reste inchangé pour tout hôte qui l'utilise
/// déjà tel quel : un composer existant ne bouge pas d'un widget ;
/// l'assemblé est opt-in — strictement additif.
///
/// ## Quatre défauts d'assemblage rendus inexprimables ou détectables
///
/// | # | Le défaut évité | Ici |
/// |---|---|---|
/// | ① | une feuille de réglages montée inline dans une bande d'accessoires — débordement visuel | le créneau `tools` de l'assemblé est une bande ; le déclencheur « outils » ouvre la feuille ([onOpenTools]) — et un override qui rendrait une `ZChatSettingsSheet` inline est détecté (assertion en debug + garde d'arbre) |
/// | ② | un paramètre de réglages oublié à l'appel, silencieusement | [settings] est requis et non nullable : l'oubli ne compile pas |
/// | ③ | un badge positionné en dehors de la cible tactile du bouton, volant le tap | le badge vit dans la cible du bouton « outils » ([ZChatComposerToolsTrigger]) : le tap passe |
/// | ④ | plusieurs puces distinctes pour un même axe de réglage | la pièce par défaut est le déclencheur unique à menu ([ZChatComposerEffortSelector]) |
///
/// ## Ce que l'assemblé monte
///
/// ```
/// [ bandeau d'edition -- quand 'editing' porte une session ]
/// +------------------------------------------------+
/// | champ (1..5 lignes, placeholder anime) [stop|envoi] |
/// | [+] [reflechir.n] [internet] [outils.n]  [effort] [modele] |
/// +------------------------------------------------+ radius 12
/// ```
///
/// Sous [ZChatComposerChromeStyle.mobileBreakpoint], les libellés des pièces
/// sont masqués, les badges gardés.
///
/// ## Règle des trois cas — un slot par pièce
///
/// Chaque pièce a son builder nullable ([ZChatComposerSlotBuilder]) : absent
/// donne le défaut du socle ; fourni et rend un widget, il remplace ; fourni
/// et rend `null`, la pièce est absente (invariant AD-4). Chrome : paramètre
/// > jeton > référence partout.
///
/// ## Invariant AD-2
///
/// La bande ne s'abonne à aucune tranche de flux — sauf le bouton d'arrêt
/// (`activeRequests`), qui est précisément la pièce dont c'est l'état. Les
/// bascules n'écoutent que `settings`, le bandeau n'écoute que `editing`.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../settings/z_chat_settings_controller.dart';
import '../z_chat_assembly_contract.dart';
import '../z_chat_controller.dart';
import 'z_chat_composer.dart';
import 'z_chat_composer_band.dart';
import 'z_chat_composer_chrome.dart';
import 'z_chat_composer_keys.dart';
import 'z_chat_composer_model_selector.dart';
import 'z_chat_composer_reference.dart';
import 'z_chat_labels.dart';
import 'z_chat_settings_sheet.dart' show ZChatSettingsSheet;

/// L'assemblage par défaut du composer — opt-in, surchargeable pièce par
/// pièce, chrome paramètre > jeton > référence partout.
class ZDefaultChatComposer extends StatelessWidget {
  /// Construit l'assemblé.
  ///
  /// [settings] est requis : ce qui rend inexprimable le défaut de réglages
  /// réglés puis jetés avant l'envoi — l'assemblé câble d'office le
  /// contrôleur de réglages sur le `send()` du composer.
  const ZDefaultChatComposer({
    required this.controller,
    required this.settings,
    required this.cursorColor,
    this.chrome,
    this.backgroundColor,
    this.borderColor,
    this.activeAccent,
    this.clipBehavior = Clip.none,
    this.focusNode,
    this.hints = const <String>[],
    this.submitPolicy = ZChatComposerSubmitPolicy.standard,
    this.pickers = const <ZChatComposerPickerAction>[],
    this.onOpenTools,
    this.toolsBadge,
    this.showToolsBadge = true,
    this.modelOptions = const <ZChatModelOption>[],
    this.modelActiveId,
    this.onSelectModel,
    this.showThinkingToggle = true,
    this.showWebSearchToggle = true,
    this.showEffortSelector = true,
    this.pickerGlyph,
    this.thinkingGlyph,
    this.webSearchGlyph,
    this.toolsGlyph,
    this.effortGlyph,
    this.effortSelectionMark,
    this.modelSelectionMark,
    this.stopGlyph,
    this.sendGlyph,
    this.editingGlyph,
    this.editingCancelGlyph,
    this.hintLeading,
    this.dictation,
    this.onDictate,
    this.dictationListening,
    this.dictationGlyph,
    this.dictationListeningGlyph,
    this.dictationBuilder,
    this.editingBannerBuilder,
    this.plusBuilder,
    this.thinkingBuilder,
    this.webSearchBuilder,
    this.toolsBuilder,
    this.effortBuilder,
    this.modelBuilder,
    this.stopBuilder,
    this.sendBuilder,
    this.hintBuilder,
    super.key,
  });

  /// Le contrôleur de conversation — ni créé ni disposé ici (invariant AD-2).
  final ZChatController controller;

  /// Le contrôleur de réglages, câblé d'office sur le composer : la feuille
  /// (ouverte par [onOpenTools]) et la bande écrivent dedans, et `send()` le
  /// lit — un réglage oublié à l'appel ne compile pas ici.
  final ZChatSettingsController settings;

  /// Couleur du curseur — fournie par l'hôte, même arbitrage que
  /// `ZChatComposer.cursorColor`.
  final Color cursorColor;

  /// Réglage de chrome — `null` signifie jetons puis référence.
  final ZChatComposerChrome? chrome;

  /// Fond du conteneur. `null` signifie jeton `surfaceColor`, sinon aucun
  /// fond (le socle n'invente aucune couleur).
  final Color? backgroundColor;

  /// Couleur du filet du conteneur — un rôle de thème que l'hôte fournit.
  /// `null` signifie jeton `chatComposerBorderColor`, sinon aucun filet
  /// (invariant AD-4). L'épaisseur vient de la chaîne du chrome (référence
  /// 1).
  final Color? borderColor;

  /// Teinte d'état **ACTIF** des bascules de la bande (« réfléchir »,
  /// « internet », dictée). `null` signifie jeton `chatComposerActiveAccent`,
  /// sinon aucune teinte (invariant AD-4).
  ///
  /// Ce canal chromatique s'AJOUTE au libellé emphasé et à
  /// `Semantics(toggled:)` : il rend l'état perceptible en mode compact sans
  /// jamais devenir le seul porteur de l'information (invariant AD-13).
  final Color? activeAccent;

  /// Rognage du contenu au rayon du conteneur. `Clip.none` par défaut — cf.
  /// [ZChatComposerSurface.clipBehavior] (mesuré : aujourd'hui inutile,
  /// nécessaire dès qu'un enfant d'hôte peint jusqu'au bord).
  final Clip clipBehavior;

  /// Nœud de focus de l'hôte. `null` signifie celui du composer.
  final FocusNode? focusNode;

  /// Suggestions du placeholder animé, déjà localisées par l'hôte. Vide
  /// signifie l'invite par défaut du composer (pas d'animation).
  final List<String> hints;

  /// Ce que la touche Entrée fait — cf. [ZChatComposer.submitPolicy].
  final ZChatComposerSubmitPolicy submitPolicy;

  /// Glyphe de tête du placeholder animé.
  final Widget? hintLeading;

  /// Le catalogue du menu `+` — contrat opaque : libellés, icônes et gestes
  /// d'hôte. Vide signifie le `+` absent (invariant AD-4).
  final List<ZChatComposerPickerAction> pickers;

  /// Ouvre la feuille de réglages — modale, page, panneau : l'hôte décide.
  /// `null` signifie le bouton « outils » absent (invariant AD-4). Le
  /// créneau `tools` de l'assemblé est une bande : la feuille n'y est
  /// jamais montée inline.
  final VoidCallback? onOpenTools;

  /// Badge compteur d'HÔTE du bouton « outils » — rendu dans la cible
  /// tactile. `null` signifie le badge par défaut du socle, qui rend
  /// `ZChatSettingsController.activeCount`.
  final Widget? toolsBadge;

  /// Présence du badge par défaut (le compte des réglages actifs).
  ///
  /// `true` par défaut : le déclencheur d'outils porte le nombre de réglages
  /// actifs, rien tant qu'il vaut zéro. `false` retire ce canal — un
  /// [toolsBadge] d'hôte, lui, reste rendu quoi qu'il arrive.
  final bool showToolsBadge;

  /// Catalogue du sélecteur de modèle. Vide signifie sélecteur absent
  /// (invariant AD-4).
  final List<ZChatModelOption> modelOptions;

  /// Id du modèle actif, ou `null`.
  final String? modelActiveId;

  /// La sélection de modèle remonte ici — l'hôte la range où il veut.
  final ValueChanged<String>? onSelectModel;

  /// Présence de la bascule « réfléchir » en bande — la présence est un
  /// paramètre d'hôte ; la tuile de la feuille, elle, reste toujours
  /// disponible.
  final bool showThinkingToggle;

  /// Présence de la bascule « internet » en bande — même régime.
  final bool showWebSearchToggle;

  /// Présence du déclencheur d'effort à menu — même régime.
  final bool showEffortSelector;

  /// Glyphes d'hôte des pièces — `null` signifie libellé résolu (le socle
  /// n'invente aucun glyphe).
  final Widget? pickerGlyph;

  /// Glyphe de la bascule « réfléchir ».
  final Widget? thinkingGlyph;

  /// Glyphe de la bascule « internet ».
  final Widget? webSearchGlyph;

  /// Glyphe du bouton « outils ».
  final Widget? toolsGlyph;

  /// Glyphe du déclencheur d'effort.
  final Widget? effortGlyph;

  /// Coche du palier actif du menu d'effort.
  final Widget? effortSelectionMark;

  /// Coche du modèle actif du menu de modèle.
  final Widget? modelSelectionMark;

  /// Glyphe du bouton d'arrêt.
  final Widget? stopGlyph;

  /// Glyphe du bouton d'envoi. `null` signifie le libellé résolu (le rendu
  /// pixel-perfect d'un design system particulier est l'affaire du
  /// satellite qui le porte).
  final Widget? sendGlyph;

  /// Glyphe du bandeau d'édition (le crayon).
  final Widget? editingGlyph;

  /// Glyphe de la sortie d'édition.
  final Widget? editingCancelGlyph;

  /// Créneau libre au-dessus du champ (une bande de capture d'hôte, par
  /// exemple `ZChatCaptureBar`). `null` signifie absent (invariant AD-4).
  ///
  /// Ce n'est pas le déclencheur compact de dictée : c'est [onDictate] qui
  /// le monte, dans la bande. Ce créneau reste inchangé pour l'hôte qui s'en
  /// sert déjà.
  final ZChatComposerSlotBuilder? dictation;

  /// Le geste de dictée — démarrer/arrêter : le socle ne sait pas lequel, il
  /// n'a pas le moteur. `null` signifie le déclencheur compact absent de la
  /// bande (invariant AD-4), jamais un micro inerte.
  final VoidCallback? onDictate;

  /// La tranche d'écoute injectée par l'hôte (typiquement
  /// `ZChatCaptureController.listening`). `null` signifie toujours au repos.
  final ValueListenable<bool>? dictationListening;

  /// Glyphe d'hôte du déclencheur au repos (le micro).
  final Widget? dictationGlyph;

  /// Glyphe d'hôte du déclencheur pendant l'écoute.
  final Widget? dictationListeningGlyph;

  /// Remplace le déclencheur de dictée (règle des trois cas).
  final ZChatComposerSlotBuilder? dictationBuilder;

  /// Overrides pièce par pièce — règle des trois cas (absent donne le
  /// défaut ; widget rendu remplace ; `null` rendu donne une pièce absente,
  /// invariant AD-4).
  final ZChatComposerSlotBuilder? editingBannerBuilder;

  /// Remplace le `+` des pickers.
  final ZChatComposerSlotBuilder? plusBuilder;

  /// Remplace la bascule « réfléchir ».
  final ZChatComposerSlotBuilder? thinkingBuilder;

  /// Remplace la bascule « internet ».
  final ZChatComposerSlotBuilder? webSearchBuilder;

  /// Remplace le bouton « outils » (le déclencheur — jamais la feuille :
  /// rendre une `ZChatSettingsSheet` ici est détecté).
  final ZChatComposerSlotBuilder? toolsBuilder;

  /// Remplace le déclencheur d'effort.
  final ZChatComposerSlotBuilder? effortBuilder;

  /// Remplace le sélecteur de modèle.
  final ZChatComposerSlotBuilder? modelBuilder;

  /// Remplace le bouton d'arrêt.
  final ZChatComposerSlotBuilder? stopBuilder;

  /// Remplace la cible d'envoi.
  final ZChatComposerSlotBuilder? sendBuilder;

  /// Remplace le placeholder (créneau `hint` du composer).
  final ZChatComposerSlotBuilder? hintBuilder;

  /// Applique la règle des trois cas à une pièce — et détecte en debug
  /// l'erreur d'assemblage où une `ZChatSettingsSheet` serait rendue dans la
  /// bande (le créneau est une bande, la feuille une page).
  Widget? _piece(
    BuildContext context,
    ZChatComposerSlot slot,
    ZChatComposerSlotBuilder? override,
    Widget? Function() fallback,
  ) {
    final Widget? built = override == null
        ? fallback()
        : override(context, slot);
    // Le message vit hors des fichiers de rendu (aucun littéral porteur de
    // mot ici — cf. `z_chat_assembly_contract.dart`).
    assert(built is! ZChatSettingsSheet, kZChatBandSheetAssertMessage);
    return built;
  }

  @override
  Widget build(BuildContext context) {
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: chrome,
    );
    return ZChatComposerSurface(
      chrome: chrome,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      clipBehavior: clipBehavior,
      child: ZChatComposer(
        controller: controller,
        cursorColor: cursorColor,
        // Le contrôleur de réglages est câblé d'office — la feuille et la
        // bande écrivent dans ce contrôleur, `send()` le lit.
        settings: settings,
        focusNode: focusNode,
        minLines: ZChatComposerReference.fieldMinLines,
        maxLines: ZChatComposerReference.fieldMaxLines,
        submitPolicy: submitPolicy,
        padding: style.fieldContentPadding,
        hint: _hintSlot(),
        capture: _captureSlot(),
        trailing: _trailingSlot(),
        tools: _bandSlotOrNull(style),
      ),
    );
  }

  /// Créneau `hint` : le placeholder animé quand l'hôte fournit des
  /// suggestions — sinon l'invite par défaut du composer.
  ZChatComposerSlotBuilder? _hintSlot() {
    if (hintBuilder != null) return hintBuilder;
    if (hints.isEmpty) return null;
    return (BuildContext context, ZChatComposerSlot slot) =>
        ZChatComposerAnimatedHint(
          hints: hints,
          leading: hintLeading,
          chrome: chrome,
        );
  }

  /// Créneau `capture` (au-dessus du champ) : le bandeau d'édition — qui
  /// rend les verbes existants du contrôleur — puis l'éventuel slot de
  /// dictée d'hôte.
  ZChatComposerSlotBuilder _captureSlot() {
    return (BuildContext context, ZChatComposerSlot slot) {
      final Widget? banner = _piece(
        context,
        slot,
        editingBannerBuilder,
        () => ZChatComposerEditingBanner(
          controller: controller,
          glyph: editingGlyph,
          cancelGlyph: editingCancelGlyph,
        ),
      );
      final Widget? dictate = dictation?.call(context, slot);
      if (banner == null && dictate == null) return null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[?banner, ?dictate],
      );
    };
  }

  /// Créneau `trailing` : le bouton d'arrêt (pendant le flux — la pièce se
  /// masque seule) puis l'envoi. Le tap d'envoi reste
  /// [ZChatComposerSlot.submit] — le site unique du composer.
  ZChatComposerSlotBuilder _trailingSlot() {
    return (BuildContext context, ZChatComposerSlot slot) {
      final Widget? stop = _piece(
        context,
        slot,
        stopBuilder,
        () => ZChatComposerStopTarget(
          controller: controller,
          glyph: stopGlyph,
        ),
      );
      final Widget? send = _piece(
        context,
        slot,
        sendBuilder,
        () => ZChatComposerSendTarget(
          slot: slot,
          chrome: chrome,
          child:
              sendGlyph ??
              Text(
                zChatLabel(context, kZChatLabelSend),
                textAlign: TextAlign.start,
              ),
        ),
      );
      if (stop == null && send == null) return null;
      return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[?stop, ?send]);
    };
  }

  /// La bande d'accessoires (créneau `tools`) — `+`, bascules, outils,
  /// effort, modèle. Sous [ZChatComposerChromeStyle.mobileBreakpoint], les
  /// libellés sont masqués et les badges gardés.
  /// `true` si, sans aucun override, la bande n'aurait aucune pièce — le
  /// créneau est alors absent de l'arbre (invariant AD-4), jamais une
  /// rangée vide.
  bool get _bandStructurallyEmpty =>
      pickers.isEmpty &&
      onDictate == null &&
      dictationBuilder == null &&
      !showThinkingToggle &&
      !showWebSearchToggle &&
      !showEffortSelector &&
      onOpenTools == null &&
      (modelOptions.isEmpty || onSelectModel == null) &&
      plusBuilder == null &&
      thinkingBuilder == null &&
      webSearchBuilder == null &&
      toolsBuilder == null &&
      effortBuilder == null &&
      modelBuilder == null;

  ZChatComposerSlotBuilder? _bandSlotOrNull(ZChatComposerChromeStyle style) =>
      _bandStructurallyEmpty ? null : _bandSlot(style);

  ZChatComposerSlotBuilder _bandSlot(ZChatComposerChromeStyle style) {
    return (BuildContext context, ZChatComposerSlot slot) => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // La référence `mobileBreakpoint` est consommée par la chaîne du
        // chrome, donc réglable par l'hôte.
        final bool compact =
            constraints.hasBoundedWidth &&
            constraints.maxWidth < style.mobileBreakpoint;
        final bool labels = !compact;
        final Widget? plus = _piece(
          context,
          slot,
          plusBuilder,
          () => pickers.isEmpty
              ? null
              : ZChatComposerPickerTrigger(
                  actions: pickers,
                  glyph: pickerGlyph,
                ),
        );
        final VoidCallback? dictate = onDictate;
        final Widget? mic = _piece(
          context,
          slot,
          dictationBuilder,
          () => dictate == null
              ? null
              : ZChatComposerDictationTrigger(
                  onTap: dictate,
                  listening: dictationListening,
                  glyph: dictationGlyph,
                  listeningGlyph: dictationListeningGlyph,
                  showLabel: labels,
                  activeAccent: activeAccent,
                ),
        );
        final Widget? thinking = _piece(
          context,
          slot,
          thinkingBuilder,
          () => showThinkingToggle
              ? ZChatComposerThinkingToggle(
                  controller: settings,
                  glyph: thinkingGlyph,
                  showLabel: labels,
                  activeAccent: activeAccent,
                )
              : null,
        );
        final Widget? web = _piece(
          context,
          slot,
          webSearchBuilder,
          () => showWebSearchToggle
              ? ZChatComposerWebSearchToggle(
                  controller: settings,
                  glyph: webSearchGlyph,
                  showLabel: labels,
                  activeAccent: activeAccent,
                )
              : null,
        );
        final VoidCallback? openTools = onOpenTools;
        final Widget? tools = _piece(
          context,
          slot,
          toolsBuilder,
          () => openTools == null
              ? null
              : ZChatComposerToolsTrigger(
                  onOpen: openTools,
                  badge: toolsBadge,
                  // Le compte des réglages actifs est rendu PAR DÉFAUT : la
                  // tranche existait, elle n'était affichée nulle part. Sous
                  // le seuil compact, le badge remplace le libellé.
                  badgeCount: showToolsBadge ? settings.activeCount : null,
                  glyph: toolsGlyph,
                  showLabel: labels,
                ),
        );
        final ValueChanged<String>? selectModel = onSelectModel;
        final Widget? model = _piece(
          context,
          slot,
          modelBuilder,
          () => modelOptions.isEmpty || selectModel == null
              ? null
              : ZChatComposerModelSelector(
                  options: modelOptions,
                  activeId: modelActiveId,
                  onSelect: selectModel,
                  selectionMark: modelSelectionMark,
                ),
        );
        final Widget? effort = _piece(
          context,
          slot,
          effortBuilder,
          () => showEffortSelector
              ? ZChatComposerEffortSelector(
                  controller: settings,
                  glyph: effortGlyph,
                  selectionMark: effortSelectionMark,
                  showLabel: labels,
                )
              : null,
        );
        final List<Widget> leading = <Widget>[
          ?plus,
          ?mic,
          ?thinking,
          ?web,
          ?tools,
        ];
        final List<Widget> trailing = <Widget>[?effort, ?model];
        // Les overrides peuvent avoir tout retiré (règle des trois cas) : la
        // bande rend alors le vide le plus discret possible — le retrait
        // structurel, lui, est décidé en amont (`_bandStructurallyEmpty`).
        if (leading.isEmpty && trailing.isEmpty) {
          return const SizedBox.shrink();
        }
        // La bande défile horizontalement plutôt que de déborder : c'est
        // une rangée d'affordances, pas une page (invariant AD-10 : rien de
        // large ne la casse).
        final Widget row = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(mainAxisSize: MainAxisSize.min, children: leading),
                Row(mainAxisSize: MainAxisSize.min, children: trailing),
              ],
            ),
          ),
        );
        return row;
      },
    );
  }
}
