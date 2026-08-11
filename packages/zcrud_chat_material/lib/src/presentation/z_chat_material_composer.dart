/// Le composer assemblé Material : les glyphes (`Icons.*`), les rôles
/// Material (`ColorScheme`) et le FAB d'envoi pixel-perfect, posés sur
/// l'assemblage neutre du socle `ZDefaultChatComposer`.
///
/// L'hôte monte un seul widget et obtient la barre complète (conteneur
/// arrondi, sélecteurs de pièces jointes, bascules réflexion/recherche web,
/// bouton d'outils avec compteur, sélecteur d'effort, sélecteur de modèle,
/// bouton d'envoi, bouton d'arrêt, bandeau d'édition, placeholder animé).
/// Ce n'est pas une vue parallèle au socle : chaque pièce reste celle du
/// socle, ce fichier ne fait qu'y injecter des glyphes et des rôles de
/// couleur.
///
/// * **dimensions** : dérivées de `ZChatComposerReference` ou de la chaîne
///   de résolution du chrome — jamais recopiées ;
/// * **couleurs** : rôles du `ColorScheme` de l'hôte, aucune teinte codée en
///   dur ;
/// * **envoi** : [zChatMaterialSendFab] passe par le créneau du socle
///   (`ZChatComposerSlot.submit`), le site d'envoi unique ;
/// * **arrêt** : la pièce du socle, câblée sur le verbe existant
///   `runAction(ZChatCancelAction)` — ce satellite n'ajoute aucun verbe.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'z_chat_material_badge.dart';
import 'z_chat_material_send_fab.dart';

/// L'assemblé Material — `ZDefaultChatComposer` avec glyphes et rôles
/// Material.
class ZChatMaterialComposer extends StatelessWidget {
  /// Construit l'assemblé Material.
  ///
  /// [settings] est requis, comme sur l'assemblé neutre : un composer sans
  /// contrôleur de réglages câblé sur l'envoi ne compile pas — un réglage
  /// choisi puis silencieusement ignoré à l'envoi est une classe de défaut
  /// que le type interdit par construction.
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

  /// Le contrôleur de réglages, câblé d'office sur l'envoi.
  final ZChatSettingsController settings;

  /// {@macro zcrud.chat_material.chrome_param}
  final ZChatComposerChrome? chrome;

  /// Couleur du curseur. `null` ⇒ rôle `primary` de l'hôte.
  final Color? cursorColor;

  /// Fond du conteneur. `null` ⇒ rôle `surfaceContainerHighest` de l'hôte.
  final Color? backgroundColor;

  /// Couleur du filet du conteneur. `null` ⇒ `Theme.of(context).dividerColor`
  /// de l'hôte.
  ///
  /// Un hôte qui avait déjà obtenu ce filet en enveloppant la surface d'un
  /// second conteneur doit retirer cette compensation en migrant vers ce
  /// paramètre : les deux filets se superposeraient sinon, à des rayons
  /// différents. Un hôte qui ne veut aucun filet passe `Colors.transparent`.
  final Color? borderColor;

  /// Rognage du contenu au rayon du conteneur — `Clip.none` par défaut.
  final Clip clipBehavior;

  /// Nœud de focus de l'hôte.
  final FocusNode? focusNode;

  /// Suggestions du placeholder animé, localisées par l'hôte.
  final List<String> hints;

  /// Catalogue du menu d'ajout de pièce jointe — contrat opaque du socle.
  final List<ZChatComposerPickerAction> pickers;

  /// Ouvre la feuille de réglages. Le déclencheur (bouton, badge) vit dans
  /// la bande du composer ; la feuille elle-même reste montée par l'hôte.
  final VoidCallback? onOpenTools;

  /// Catalogue du sélecteur de modèle.
  final List<ZChatModelOption> modelOptions;

  /// Id du modèle actif.
  final String? modelActiveId;

  /// Remontée de la sélection de modèle.
  final ValueChanged<String>? onSelectModel;

  /// Présence de la bascule « réflexion » dans la bande — mêmes régimes que
  /// l'assemblé neutre.
  final bool showThinkingToggle;

  /// Présence de la bascule « recherche web ».
  final bool showWebSearchToggle;

  /// Présence du déclencheur d'effort.
  final bool showEffortSelector;

  /// Créneau libre au-dessus du champ (une bande de capture d'hôte).
  final ZChatComposerSlotBuilder? dictation;

  /// Le geste de dictée. `null` ⇒ le déclencheur compact est absent
  /// (invariant AD-4) : ce satellite ne fournit aucun moteur de
  /// reconnaissance vocale, brancher
  /// `ZChatCaptureController.startDictation()`/`stopDictation()` reste le
  /// choix de l'hôte.
  final VoidCallback? onDictate;

  /// La tranche d'écoute injectée (typiquement
  /// `ZChatCaptureController.listening`). Elle pilote le glyphe et le rôle
  /// de couleur du déclencheur : micro au repos, glyphe d'arrêt teinté
  /// `error` pendant l'écoute.
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
      // Câblé par le point d'ancrage du socle — plus aucun second conteneur
      // à faire coïncider pour obtenir ce filet.
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
      // Le badge vivant (tranche `activeCount`), rendu à l'intérieur de la
      // cible du bouton pour que le tap continue de porter.
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
      effortGlyph: Icon(Icons.auto_awesome, size: glyphSide),
      effortSelectionMark: Icon(Icons.check, size: glyphSide),
      stopGlyph: Icon(Icons.stop, size: glyphSide),
      editingGlyph: Icon(
        Icons.edit,
        size: ZChatComposerReference.editingIconSize,
      ),
      editingCancelGlyph: Icon(Icons.close, size: glyphSide),
      dictation: dictation,
      // Le glyphe et le rôle changent pendant l'écoute ; ce widget n'écoute
      // rien lui-même, il rend l'état que l'hôte lui injecte.
      onDictate: onDictate,
      dictationListening: dictationListening,
      dictationGlyph: Icon(Icons.mic, size: glyphSide),
      dictationListeningGlyph: Icon(
        Icons.stop,
        size: glyphSide,
        color: scheme.error,
      ),
      // Via le créneau du socle : même site d'envoi que le geste « valider ».
      sendBuilder: (BuildContext context, ZChatComposerSlot slot) =>
          ZChatMaterialSendFab(slot: slot, chrome: chrome),
    );
  }
}
