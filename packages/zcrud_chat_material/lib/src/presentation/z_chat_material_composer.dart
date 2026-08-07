/// Le **composer assemblé Material** — CR-IFFD-76, le rendu satellite de
/// `ZDefaultChatComposer` : les glyphes (`Icons.*`), les rôles Material
/// (`ColorScheme`) et le FAB d'envoi pixel-perfect lex, posés sur l'assemblage
/// PUR du socle.
///
/// ## Ce que ce widget est — et ce qu'il n'est PAS
///
/// C'est le pendant « Material » de la carte `ZDefaultFolderCard` : l'hôte
/// monte UN widget et obtient la barre lex complète (conteneur arrondi, `+`
/// pickers, bascules réfléchir/internet, outils + compteur, effort à menu,
/// sélecteur de modèle, FAB, STOP, bandeau d'édition, placeholder animé).
/// Ce n'est PAS une vue parallèle : chaque pièce reste celle du socle —
/// ce fichier ne fait qu'injecter des glyphes et des rôles.
///
/// * **dimensions** : `ZChatComposerReference` / chaîne du chrome K2 — rien
///   n'est recopié (garde MAT-L1) ;
/// * **couleurs** : rôles du `ColorScheme` de l'hôte — aucune teinte ici
///   (MAT-L2) ;
/// * **envoi** : [zChatMaterialSendFab] via le slot du socle —
///   `ZChatComposerSlot.submit`, le site unique (G-CH1/G-U1) ;
/// * **STOP** : la pièce du socle, câblée sur le verbe EXISTANT
///   `runAction(ZChatCancelAction)` — ce satellite n'ajoute aucun verbe.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'z_chat_material_badge.dart';
import 'z_chat_material_send_fab.dart';

/// L'assemblé Material — `ZDefaultChatComposer` + glyphes/rôles Material.
class ZChatMaterialComposer extends StatelessWidget {
  /// Construit l'assemblé Material.
  ///
  /// 🔴 [settings] est requis, comme sur l'assemblé pur : le défaut ② d'IFFD
  /// (réglages réglés puis jetés) ne compile pas.
  const ZChatMaterialComposer({
    required this.controller,
    required this.settings,
    this.chrome,
    this.cursorColor,
    this.backgroundColor,
    this.borderColor,
    this.clipBehavior = Clip.none,
    this.focusNode,
    this.hints = const <String>[],
    this.pickers = const <ZChatComposerPickerAction>[],
    this.onOpenTools,
    this.modelOptions = const <ZChatModelOption>[],
    this.modelActiveId,
    this.onSelectModel,
    this.showThinkingToggle = true,
    this.showWebSearchToggle = true,
    this.showEffortSelector = true,
    this.dictation,
    this.onDictate,
    this.dictationListening,
    super.key,
  });

  /// Le contrôleur de conversation du socle.
  final ZChatController controller;

  /// Le contrôleur de réglages — câblé d'office sur `send()` (défaut ②).
  final ZChatSettingsController settings;

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex (chaîne K2).
  final ZChatComposerChrome? chrome;

  /// Couleur du curseur. `null` ⇒ rôle `primary` de l'hôte.
  final Color? cursorColor;

  /// Fond du conteneur. `null` ⇒ rôle `surfaceContainerHighest` de l'hôte.
  final Color? backgroundColor;

  /// 🔴 Couleur du FILET du conteneur (CR-IFFD-77 ③). `null` ⇒ le
  /// **`Theme.of(context).dividerColor`** de l'hôte — le rôle exact que lex
  /// applique (`chat_input.dart:474-482`, `Border.all(color: dividerColor)`).
  ///
  /// ⚠️ **Changement visible** pour l'hôte de `ZChatMaterialComposer` : le
  /// conteneur porte désormais un filet là où il n'en avait pas. C'est ce que
  /// la CR demande ; un hôte qui n'en veut pas passe `Colors.transparent`.
  /// L'hôte qui **compensait** en enveloppant la surface d'un second conteneur
  /// doit RETIRER sa compensation, sans quoi deux filets se superposeront à
  /// deux rayons différents.
  final Color? borderColor;

  /// Rognage du contenu au rayon du conteneur — `Clip.none` par défaut.
  final Clip clipBehavior;

  /// Nœud de focus de l'hôte.
  final FocusNode? focusNode;

  /// Suggestions du placeholder animé, localisées par l'hôte.
  final List<String> hints;

  /// Catalogue du menu `+` — contrat opaque du socle.
  final List<ZChatComposerPickerAction> pickers;

  /// OUVRE la feuille de réglages (le déclencheur est dans la bande ; la
  /// feuille, elle, appartient à l'hôte — défaut ①).
  final VoidCallback? onOpenTools;

  /// Catalogue du sélecteur de modèle.
  final List<ZChatModelOption> modelOptions;

  /// Id du modèle actif.
  final String? modelActiveId;

  /// Remontée de la sélection de modèle.
  final ValueChanged<String>? onSelectModel;

  /// Présences en bande — mêmes régimes que l'assemblé pur.
  final bool showThinkingToggle;

  /// Présence de la bascule « internet ».
  final bool showWebSearchToggle;

  /// Présence du déclencheur d'effort.
  final bool showEffortSelector;

  /// Créneau libre au-dessus du champ (une bande de capture d'hôte).
  final ZChatComposerSlotBuilder? dictation;

  /// 🔴 Le GESTE de dictée (CR-IFFD-77 ④) — `null` ⇒ le déclencheur compact
  /// est absent (AD-4). Le socle ne fournit **aucun moteur** : brancher
  /// `ZChatCaptureController.startDictation()`/`stopDictation()` reste le
  /// choix de l'hôte.
  final VoidCallback? onDictate;

  /// La tranche d'écoute injectée (typiquement
  /// `ZChatCaptureController.listening`). Elle pilote ici le **glyphe** et le
  /// **rôle** : micro au repos, `stop` teinté `error` pendant l'écoute.
  final ValueListenable<bool>? dictationListening;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double glyphSide = ZChatComposerReference.toolsIconSize;
    return ZDefaultChatComposer(
      controller: controller,
      settings: settings,
      chrome: chrome,
      cursorColor: cursorColor ?? scheme.primary,
      backgroundColor: backgroundColor ?? scheme.surfaceContainerHighest,
      // 🔴 CR-IFFD-77 ③ : le rôle de lex, câblé par le point d'ancrage que le
      // socle vient d'ouvrir — plus aucun second conteneur à faire coïncider.
      borderColor: borderColor ?? Theme.of(context).dividerColor,
      clipBehavior: clipBehavior,
      focusNode: focusNode,
      hints: hints,
      hintLeading: Icon(
        Icons.auto_awesome,
        size: ZChatComposerReference.hintIconSize,
      ),
      pickers: pickers,
      pickerGlyph: Icon(Icons.add, size: glyphSide),
      onOpenTools: onOpenTools,
      toolsGlyph: Icon(Icons.settings, size: glyphSide),
      // 🔴 Le badge VIVANT du socle satellite (tranche `activeCount`), rendu
      // DANS la cible du bouton — le tap passe (défaut ③).
      toolsBadge: onOpenTools == null
          ? null
          : ZChatMaterialToolsBadge(controller: settings, chrome: chrome),
      modelOptions: modelOptions,
      modelActiveId: modelActiveId,
      onSelectModel: onSelectModel,
      modelSelectionMark: Icon(Icons.check, size: glyphSide),
      showThinkingToggle: showThinkingToggle,
      thinkingGlyph: Icon(Icons.psychology, size: glyphSide),
      showWebSearchToggle: showWebSearchToggle,
      webSearchGlyph: Icon(Icons.public, size: glyphSide),
      showEffortSelector: showEffortSelector,
      // Le « ✦ » de lex (lex/f011).
      effortGlyph: Icon(Icons.auto_awesome, size: glyphSide),
      effortSelectionMark: Icon(Icons.check, size: glyphSide),
      stopGlyph: Icon(Icons.stop, size: glyphSide),
      editingGlyph: Icon(
        Icons.edit,
        size: ZChatComposerReference.editingIconSize,
      ),
      editingCancelGlyph: Icon(Icons.close, size: glyphSide),
      dictation: dictation,
      // 🔴 CR-IFFD-77 ④ : glyphe ET rôle changent pendant l'écoute — le socle
      // n'écoute rien, il rend l'état que l'hôte lui injecte.
      onDictate: onDictate,
      dictationListening: dictationListening,
      dictationGlyph: Icon(Icons.mic, size: glyphSide),
      dictationListeningGlyph: Icon(
        Icons.stop,
        size: glyphSide,
        color: scheme.error,
      ),
      // 🔴 Le FAB lex (disque `primary`, échelle 0.7→1) — via le slot du
      // socle, donc le MÊME site d'envoi que la touche « valider ».
      sendBuilder: (BuildContext context, ZChatComposerSlot slot) =>
          ZChatMaterialSendFab(slot: slot, chrome: chrome),
    );
  }
}
