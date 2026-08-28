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
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart' show ZChatSuggestion;

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
    this.attachments,
    this.onScanAttachment,
    this.onSelectSuggestion,
    this.plusBuilder,
    this.thinkingBuilder,
    this.webSearchBuilder,
    this.toolsBuilder,
    this.effortBuilder,
    this.modelBuilder,
    this.stopBuilder,
    this.sendBuilder,
    this.hintBuilder,
    this.attachmentsBuilder,
    this.attachmentThumbnailBuilder,
    this.dictationBuilder,
    this.draftNoticeBuilder,
    this.editingBannerBuilder,
    this.progressBuilder,
    this.suggestionsBuilder,
    this.suggestionGlyphBuilder,
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

  /// Le contrôleur de pièces jointes — ni créé ni disposé ici. `null` ⇒
  /// aucune pièce de pièce jointe dans l'arbre (aperçu, progression).
  final ZChatAttachmentController? attachments;

  /// Le geste de relecture de texte offert sur une vignette d'image.
  /// `null` ⇒ aucune affordance.
  final ZChatAttachmentScanCallback? onScanAttachment;

  /// Ce que taper une proposition déclenche. `null` ⇒ le rang des
  /// propositions n'est pas monté.
  final void Function(ZChatSuggestion suggestion)? onSelectSuggestion;

  /// Les créneaux de remplacement de `ZDefaultChatComposer`, relayés tels
  /// quels. Chacun vaut `null` par défaut : la pièce Material correspondante
  /// (glyphe, rôle, disque d'envoi, badge) est alors rendue. Fourni, le
  /// builder de l'hôte **remplace la pièce entière** — glyphe compris — et
  /// les autres pièces gardent leur habillage Material. Règle des trois cas
  /// du socle : absent ⇒ défaut ; widget rendu ⇒ remplace ; `null` rendu ⇒
  /// pièce absente.
  ///
  /// Remplace le `+` des pickers.
  final ZChatComposerSlotBuilder? plusBuilder;

  /// Remplace la bascule « réfléchir ».
  final ZChatComposerSlotBuilder? thinkingBuilder;

  /// Remplace la bascule « recherche web ».
  final ZChatComposerSlotBuilder? webSearchBuilder;

  /// Remplace le déclencheur « outils » (jamais la feuille) — badge compris.
  final ZChatComposerSlotBuilder? toolsBuilder;

  /// Remplace le déclencheur d'effort.
  final ZChatComposerSlotBuilder? effortBuilder;

  /// Remplace le sélecteur de modèle.
  final ZChatComposerSlotBuilder? modelBuilder;

  /// Remplace le bouton d'arrêt.
  final ZChatComposerSlotBuilder? stopBuilder;

  /// Remplace la cible d'envoi — à la place du disque Material
  /// [ZChatMaterialSendFab].
  final ZChatComposerSlotBuilder? sendBuilder;

  /// Remplace le placeholder du champ.
  final ZChatComposerSlotBuilder? hintBuilder;

  /// Remplace l'aperçu des pièces jointes.
  final ZChatComposerSlotBuilder? attachmentsBuilder;

  /// Couture d'aperçu des vignettes, passée telle quelle au socle.
  final ZChatAttachmentThumbnailBuilder? attachmentThumbnailBuilder;

  /// Remplace le déclencheur de dictée.
  final ZChatComposerSlotBuilder? dictationBuilder;

  /// Remplace l'indicateur de brouillon restitué.
  final ZChatComposerSlotBuilder? draftNoticeBuilder;

  /// Remplace le bandeau d'édition.
  final ZChatComposerSlotBuilder? editingBannerBuilder;

  /// Remplace la progression de téléversement.
  final ZChatComposerSlotBuilder? progressBuilder;

  /// Remplace le rang des propositions.
  final ZChatComposerSlotBuilder? suggestionsBuilder;

  /// Glyphe d'hôte par proposition, passé tel quel au socle.
  final Widget? Function(BuildContext context, ZChatSuggestion suggestion)?
      suggestionGlyphBuilder;

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
      // Précédence : le builder de l'hôte prime sur le disque Material —
      // l'hôte remplace UNE pièce et garde toutes les autres. Pour les seize
      // autres créneaux, le socle applique lui-même cette précédence : un
      // builder fourni rend la pièce entière, le glyphe Material posé
      // ci-dessus n'est alors pas consommé.
      sendBuilder:
          sendBuilder ??
          (BuildContext context, ZChatComposerSlot slot) =>
              ZChatMaterialSendFab(slot: slot, chrome: chrome),
      attachments: attachments,
      onScanAttachment: onScanAttachment,
      onSelectSuggestion: onSelectSuggestion,
      plusBuilder: plusBuilder,
      thinkingBuilder: thinkingBuilder,
      webSearchBuilder: webSearchBuilder,
      toolsBuilder: toolsBuilder,
      effortBuilder: effortBuilder,
      modelBuilder: modelBuilder,
      stopBuilder: stopBuilder,
      hintBuilder: hintBuilder,
      attachmentsBuilder: attachmentsBuilder,
      attachmentThumbnailBuilder: attachmentThumbnailBuilder,
      dictationBuilder: dictationBuilder,
      draftNoticeBuilder: draftNoticeBuilder,
      editingBannerBuilder: editingBannerBuilder,
      progressBuilder: progressBuilder,
      suggestionsBuilder: suggestionsBuilder,
      suggestionGlyphBuilder: suggestionGlyphBuilder,
    );
  }
}
