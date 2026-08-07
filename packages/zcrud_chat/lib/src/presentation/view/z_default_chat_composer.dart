/// **CR-IFFD-76 — `ZDefaultChatComposer`, l'ASSEMBLAGE par défaut** du
/// composer — le pendant exact de ce que `ZDefaultFolderCard` a été pour les
/// cartes de dossier : le socle ne livre plus seulement les pièces, il livre
/// **la barre**, personnalisable pièce par pièce.
///
/// ## 🔴 Pourquoi un widget NOUVEAU, pas un défaut de `ZChatComposer`
///
/// La CR laissait le choix ; la doctrine du dépôt tranche : l'arbre de
/// `ZChatComposer` est protégé par étalon sérialisé et par la règle « hôte
/// passif inchangé ». Un composer existant ne bouge pas d'un widget ;
/// l'assemblé est **opt-in** — strictement additif.
///
/// ## 🔴 Les quatre défauts d'assemblage d'IFFD, rendus INEXPRIMABLES ou
/// DÉTECTABLES
///
/// | # | le défaut mesuré chez IFFD | ici |
/// |---|---|---|
/// | ① | la feuille de réglages montée dans le créneau `tools` (débordement 149 px) | le créneau `tools` de l'assemblé est **une bande** ; le déclencheur « outils » **OUVRE** la feuille ([onOpenTools]) — et un override qui rendrait une `ZChatSettingsSheet` est **détecté** (assertion en debug + garde d'arbre) |
/// | ② | `settings:` oublié sur `ZChatComposer` — la portée documentaire ne partait pas (B-58) | [settings] est **requis et non nullable** : l'oubli ne compile pas |
/// | ③ | badge posé en `PositionedDirectional` sur un `Stack` — détaché, volant le tap | le badge vit **dans la cible** du bouton « outils » ([ZChatComposerToolsTrigger]) : le tap passe (garde de hit-test) |
/// | ④ | trois chips d'effort (`zChatMaterialEffortChips`) | la pièce par défaut est le **déclencheur unique à menu** ([ZChatComposerEffortSelector], la forme lex/f011) |
///
/// ## Ce que l'assemblé monte (relevé lex f003/f011)
///
/// ```
/// [ bandeau d'édition — quand `editing` porte une session ]
/// ╭──────────────────────────────────────────────╮
/// │ champ (1..5 lignes, placeholder animé) [stop|envoi] │
/// │ [+] [réfléchir·n] [internet] [outils·n]  [✦ effort] [modèle] │
/// ╰──────────────────────────────────────────────╯ radius 12
/// ```
///
/// Conteneur : les constantes que les DEUX relevés publient déjà et qui
/// convergent (radius 12, 1..5 lignes — le fait §① de la CR) ; sous
/// [ZChatComposerChromeStyle.mobileBreakpoint] (< 400 dp, lex/f011), les
/// libellés des pièces sont masqués, les badges gardés.
///
/// ## Règle des trois cas — un slot PAR pièce
///
/// Chaque pièce a son builder nullable ([ZChatComposerSlotBuilder]) : absent ⇒
/// défaut du socle ; fourni et rend un widget ⇒ remplace ; fourni et rend
/// `null` ⇒ pièce ABSENTE (AD-4). Chrome : paramètre > jeton > référence
/// partout (chaîne K2).
///
/// ## SM-1
///
/// La bande ne s'abonne à AUCUNE tranche de flux — sauf le STOP
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
import 'z_chat_composer_model_selector.dart';
import 'z_chat_composer_reference.dart';
import 'z_chat_labels.dart';
import 'z_chat_settings_sheet.dart' show ZChatSettingsSheet;

/// L'assemblage PAR DÉFAUT du composer (CR-IFFD-76) — opt-in, surchargeable
/// pièce par pièce, chrome **paramètre > jeton > référence** partout.
class ZDefaultChatComposer extends StatelessWidget {
  /// Construit l'assemblé.
  ///
  /// 🔴 [settings] est **requis** : c'est le défaut ② d'IFFD (réglages réglés
  /// puis jetés) rendu inexprimable — l'assemblé câble d'office le contrôleur
  /// de réglages sur le `send()` du composer.
  const ZDefaultChatComposer({
    required this.controller,
    required this.settings,
    required this.cursorColor,
    this.chrome,
    this.backgroundColor,
    this.borderColor,
    this.clipBehavior = Clip.none,
    this.focusNode,
    this.hints = const <String>[],
    this.pickers = const <ZChatComposerPickerAction>[],
    this.onOpenTools,
    this.toolsBadge,
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

  /// Le contrôleur de conversation — ni créé ni disposé ici (AD-2).
  final ZChatController controller;

  /// 🔴 Le contrôleur de réglages, **câblé d'office** sur le composer : la
  /// feuille (ouverte par [onOpenTools]) et la bande écrivent dedans, et
  /// `send()` le lit — l'oubli d'IFFD (défaut ②/B-58) ne compile pas ici.
  final ZChatSettingsController settings;

  /// Couleur du curseur — fournie par l'hôte (FR-26, même arbitrage que
  /// `ZChatComposer.cursorColor`).
  final Color cursorColor;

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex (chaîne K2).
  final ZChatComposerChrome? chrome;

  /// Fond du conteneur. `null` ⇒ jeton `surfaceColor`, sinon aucun fond
  /// (le socle n'invente aucune couleur).
  final Color? backgroundColor;

  /// Couleur du FILET du conteneur (CR-IFFD-77 ③) — le `dividerColor` de lex,
  /// un **rôle** que l'hôte fournit. `null` ⇒ jeton demandé
  /// `chatComposerBorderColor`, sinon aucun filet (FR-26/AD-4). L'épaisseur
  /// vient de la chaîne du chrome (référence 1).
  final Color? borderColor;

  /// Rognage du contenu au rayon du conteneur. `Clip.none` par défaut — cf.
  /// [ZChatComposerSurface.clipBehavior] (mesuré : aujourd'hui inutile,
  /// nécessaire dès qu'un enfant d'hôte peint jusqu'au bord).
  final Clip clipBehavior;

  /// Nœud de focus de l'hôte. `null` ⇒ celui du composer.
  final FocusNode? focusNode;

  /// Suggestions du placeholder animé, déjà localisées par l'hôte. Vide ⇒
  /// l'invite par défaut du composer (pas d'animation).
  final List<String> hints;

  /// Glyphe de tête du placeholder animé (l'« étincelle » de lex).
  final Widget? hintLeading;

  /// Le catalogue du menu `+` (pièce 2) — contrat OPAQUE : libellés, icônes
  /// et gestes d'hôte. Vide ⇒ le `+` est absent (AD-4).
  final List<ZChatComposerPickerAction> pickers;

  /// OUVRE la feuille de réglages (pièce 5) — modale, page, panneau : l'hôte
  /// décide (F11). `null` ⇒ le bouton « outils » est absent (AD-4). Le
  /// créneau `tools` de l'assemblé est une **bande** : la feuille n'y est
  /// jamais montée inline (défaut ① d'IFFD).
  final VoidCallback? onOpenTools;

  /// Badge compteur du bouton « outils » (`ZChatMaterialToolsBadge` ou tout
  /// widget d'hôte) — rendu DANS la cible (défaut ③ inexprimable).
  final Widget? toolsBadge;

  /// Catalogue du sélecteur de modèle (arbitrage « créneau + tuile par
  /// défaut »). Vide ⇒ sélecteur absent (AD-4).
  final List<ZChatModelOption> modelOptions;

  /// Id du modèle actif, ou `null`.
  final String? modelActiveId;

  /// La sélection de modèle REMONTE ici — l'hôte la range où il veut.
  final ValueChanged<String>? onSelectModel;

  /// Présence de la bascule « réfléchir » en bande (arbitrage 3 : la présence
  /// est un paramètre d'hôte ; la TUILE de la feuille, elle, reste).
  final bool showThinkingToggle;

  /// Présence de la bascule « internet » en bande — même régime.
  final bool showWebSearchToggle;

  /// Présence du déclencheur d'effort à menu — même régime.
  final bool showEffortSelector;

  /// Glyphes d'HÔTE des pièces — `null` ⇒ libellé résolu (le socle n'invente
  /// aucun glyphe : `material` banni, FR-26).
  final Widget? pickerGlyph;

  /// Glyphe de la bascule « réfléchir ».
  final Widget? thinkingGlyph;

  /// Glyphe de la bascule « internet ».
  final Widget? webSearchGlyph;

  /// Glyphe du bouton « outils ».
  final Widget? toolsGlyph;

  /// Glyphe du déclencheur d'effort (le « ✦ »).
  final Widget? effortGlyph;

  /// Coche du palier actif du menu d'effort.
  final Widget? effortSelectionMark;

  /// Coche du modèle actif du menu de modèle.
  final Widget? modelSelectionMark;

  /// Glyphe du bouton STOP.
  final Widget? stopGlyph;

  /// Glyphe du bouton d'envoi. `null` ⇒ le libellé résolu (le disque Material
  /// est l'affaire du satellite : `zChatMaterialSendFab`).
  final Widget? sendGlyph;

  /// Glyphe du bandeau d'édition (le crayon).
  final Widget? editingGlyph;

  /// Glyphe de la sortie d'édition.
  final Widget? editingCancelGlyph;

  /// Créneau LIBRE au-dessus du champ (une bande de capture d'hôte, par
  /// exemple `ZChatCaptureBar`). `null` ⇒ absent (AD-4).
  ///
  /// ⚠️ Ce n'est **pas** le déclencheur compact : CR-IFFD-76 comptait celui-ci
  /// parmi ses six pièces alors qu'il n'existait pas — c'est [onDictate] qui
  /// le monte, dans la BANDE (CR-IFFD-77 ④). Ce créneau reste inchangé pour
  /// l'hôte qui s'en sert déjà.
  final ZChatComposerSlotBuilder? dictation;

  /// 🔴 Le GESTE de dictée (CR-IFFD-77 ④) — démarrer/arrêter : le socle ne
  /// sait pas lequel, il n'a pas le moteur. `null` ⇒ le déclencheur compact
  /// est **absent** de la bande (AD-4), jamais un micro inerte.
  final VoidCallback? onDictate;

  /// La tranche d'écoute **injectée** par l'hôte (typiquement
  /// `ZChatCaptureController.listening`). `null` ⇒ toujours au repos.
  final ValueListenable<bool>? dictationListening;

  /// Glyphe d'HÔTE du déclencheur au repos (le micro).
  final Widget? dictationGlyph;

  /// Glyphe d'HÔTE du déclencheur **pendant l'écoute**.
  final Widget? dictationListeningGlyph;

  /// Remplace le déclencheur de dictée (règle des trois cas).
  final ZChatComposerSlotBuilder? dictationBuilder;

  /// Overrides pièce par pièce — règle des trois cas (absent ⇒ défaut ;
  /// widget ⇒ remplace ; `null` rendu ⇒ pièce absente, AD-4).
  final ZChatComposerSlotBuilder? editingBannerBuilder;

  /// Remplace le `+` des pickers.
  final ZChatComposerSlotBuilder? plusBuilder;

  /// Remplace la bascule « réfléchir ».
  final ZChatComposerSlotBuilder? thinkingBuilder;

  /// Remplace la bascule « internet ».
  final ZChatComposerSlotBuilder? webSearchBuilder;

  /// Remplace le bouton « outils » (le déclencheur — JAMAIS la feuille :
  /// rendre une `ZChatSettingsSheet` ici est détecté, cf. défaut ①).
  final ZChatComposerSlotBuilder? toolsBuilder;

  /// Remplace le déclencheur d'effort.
  final ZChatComposerSlotBuilder? effortBuilder;

  /// Remplace le sélecteur de modèle.
  final ZChatComposerSlotBuilder? modelBuilder;

  /// Remplace le bouton STOP.
  final ZChatComposerSlotBuilder? stopBuilder;

  /// Remplace la cible d'envoi.
  final ZChatComposerSlotBuilder? sendBuilder;

  /// Remplace le placeholder (créneau `hint` du composer).
  final ZChatComposerSlotBuilder? hintBuilder;

  /// Applique la règle des trois cas à une pièce — et DÉTECTE le défaut ① en
  /// debug : une `ZChatSettingsSheet` rendue dans la bande est l'erreur
  /// d'assemblage d'IFFD (le créneau est une bande, la feuille une page).
  Widget? _piece(
    BuildContext context,
    ZChatComposerSlot slot,
    ZChatComposerSlotBuilder? override,
    Widget? Function() fallback,
  ) {
    final Widget? built = override == null
        ? fallback()
        : override(context, slot);
    // Le message vit HORS des fichiers de rendu (G-R10 : aucun littéral
    // porteur de mot ici — cf. `z_chat_assembly_contract.dart`).
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
        // 🔴 Défaut ② : le contrôleur de réglages est câblé D'OFFICE — la
        // feuille et la bande écrivent dans CE contrôleur, `send()` le lit.
        settings: settings,
        focusNode: focusNode,
        // Le fait §① de la CR : les deux relevés convergent (1..5 lignes).
        minLines: ZChatComposerReference.fieldMinLines,
        maxLines: ZChatComposerReference.fieldMaxLines,
        padding: style.fieldContentPadding,
        hint: _hintSlot(),
        capture: _captureSlot(),
        trailing: _trailingSlot(),
        tools: _bandSlotOrNull(style),
      ),
    );
  }

  /// Créneau `hint` : le placeholder animé de lex quand l'hôte fournit des
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

  /// Créneau `capture` (au-dessus du champ) : le bandeau d'édition — qui rend
  /// les verbes K2 existants — puis l'éventuel slot de dictée d'hôte.
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

  /// Créneau `trailing` : STOP (pendant le flux — la pièce se masque seule)
  /// puis l'envoi. Le tap d'envoi reste [ZChatComposerSlot.submit] — le site
  /// unique du composer.
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

  /// La BANDE d'accessoires (créneau `tools`) — `+`, bascules, outils,
  /// effort, modèle. Sous [ZChatComposerChromeStyle.mobileBreakpoint], les
  /// libellés sont masqués et les badges gardés (lex/f011).
  /// `true` si, sans aucun override, la bande n'aurait AUCUNE pièce — le
  /// créneau est alors absent de l'arbre (AD-4), jamais une rangée vide.
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
        // 🔴 La référence `mobileBreakpoint` est CONSOMMÉE (le « non
        // mesuré » de la CR) — par la chaîne du chrome, donc réglable.
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
        // STRUCTUREL, lui, est décidé en amont (`_bandStructurallyEmpty`).
        if (leading.isEmpty && trailing.isEmpty) {
          return const SizedBox.shrink();
        }
        // 🔴 La bande DÉFILE horizontalement plutôt que de déborder : c'est
        // une rangée d'affordances, pas une page (défaut ① : rien de haut ne
        // s'y monte ; et rien de large ne la casse — AD-10).
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
