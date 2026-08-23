/// Bande des pièces jointes en attente.
///
/// Rendu neutre, zéro dépendance tierce, de
/// `ZChatAttachmentController.pending` — suit le même patron que
/// `ZChatConversationView` : `ListView.builder`, `Semantics`, jetons de
/// `ZcrudTheme`, libellés résolus par `zChatLabel(context, clé)`.
///
/// ## Invariant AD-13, en pratique
///
/// * cible tactile : le retrait est un `ConstrainedBox` à
///   [kZChatMinTapTarget] (48 dp), jamais une icône minuscule posée en coin ;
/// * directionnalité : `EdgeInsetsDirectional` / `AlignmentDirectional` /
///   `TextAlign.start` — jamais `left`/`right`, sans quoi la bande est à
///   l'envers en RTL ;
/// * sémantique : chaque vignette est un nœud annoncé, chaque retrait est un
///   `Semantics(button: true)`.
///
/// ## Aucune image n'est décodée ici
///
/// `ZPendingAttachment.thumbnailBytes` porte les octets, mais cette bande ne
/// les rend pas : décoder un bitmap volumineux dans le composer, à chaque
/// rebuild, pour une vignette de 48 dp, contredirait l'invariant AD-2. Le nom
/// du fichier est rendu ; l'aperçu riche appartient à l'hôte, qui a le budget
/// et le cache pour le faire (et peut le brancher par [thumbnailBuilder]).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../attachment/z_chat_attachment_controller.dart';
import '../attachment/z_pending_attachment.dart';
import 'z_chat_composer_reference.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// Construit l'aperçu d'une pièce jointe — couture d'hôte.
///
/// `null` ⇒ aucune vignette, seul le nom du fichier est rendu. Sémantique de
/// `ZChatRenderer` : `null` est une réponse valide et fonctionnelle.
typedef ZChatAttachmentThumbnailBuilder =
    Widget? Function(BuildContext context, ZPendingAttachment attachment);

/// Rend les pièces jointes **en attente** d'un [ZChatAttachmentController].
class ZChatAttachmentStrip extends StatelessWidget {
  /// Construit la bande.
  const ZChatAttachmentStrip({
    required this.controller,
    this.thumbnailBuilder,
    this.height = _kStripHeight,
    super.key,
  });

  /// Le contrôleur écouté. Il n'est ni créé ni disposé ici : son cycle de vie
  /// appartient à l'hôte (invariant AD-2).
  final ZChatAttachmentController controller;

  /// Couture d'aperçu, ou `null` (aucune vignette).
  final ZChatAttachmentThumbnailBuilder? thumbnailBuilder;

  /// Hauteur de la bande demandée par l'hôte.
  ///
  /// Lire [effectiveHeight], jamais ce champ, pour dimensionner : une hauteur
  /// inférieure à `kZChatMinTapTarget` écraserait la cible tactile (invariant
  /// AD-13). Le `ConstrainedBox` du bouton ne protège pas contre cela : sous
  /// une contrainte de hauteur serrée venue du parent, il peut être écrasé
  /// en silence, sans exception ni avertissement.
  final double height;

  /// Hauteur réellement appliquée : jamais sous le plancher tactile.
  ///
  /// Le plancher passe ainsi de l'ENFANT (qui ne peut pas être plus grand que
  /// la place imposée — protocole de Flutter) au CONTENEUR, qui la décide.
  /// Même remède que `ZMenuEntryTile.gridDelegate`.
  double get effectiveHeight => math.max(height, kZChatMinTapTarget);

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return ValueListenableBuilder<List<ZPendingAttachment>>(
      valueListenable: controller.pending,
      builder:
          (
            BuildContext context,
            List<ZPendingAttachment> pending,
            Widget? child,
          ) {
            // Aucune pièce ⇒ la bande DISPARAÎT (elle ne réserve pas de place
            // pour rien dans un composer déjà à l'étroit).
            if (pending.isEmpty) return const SizedBox.shrink();
            return Semantics(
              container: true,
              label: zChatLabel(context, kZChatLabelAttachments),
              child: SizedBox(
                height: effectiveHeight,
                child: ListView.builder(
                  // `.builder` — jamais `ListView(children: [...])`.
                  scrollDirection: Axis.horizontal,
                  // Une marge verticale réduirait la hauteur utile disponible
                  // pour la cible tactile de 48 dp en dessous du plancher :
                  // la marge de bande reste donc strictement horizontale.
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: theme.gapM,
                  ),
                  itemCount: pending.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ZPendingAttachment attachment = pending[index];
                    return Padding(
                      // Invariant AD-13 : marge directionnelle.
                      padding: EdgeInsetsDirectional.only(end: theme.gapS),
                      child: _ZAttachmentChip(
                        key: ValueKey<String>(
                          '${attachment.fileName}#$index',
                        ),
                        attachment: attachment,
                        thumbnail: thumbnailBuilder?.call(context, attachment),
                        onRemove: () => controller.remove(index),
                      ),
                    );
                  },
                ),
              ),
            );
          },
    );
  }
}

/// Une vignette : aperçu optionnel, nom du fichier, bouton de retrait ≥ 48 dp.
class _ZAttachmentChip extends StatelessWidget {
  const _ZAttachmentChip({
    required this.attachment,
    required this.onRemove,
    this.thumbnail,
    super.key,
  });

  final ZPendingAttachment attachment;
  final Widget? thumbnail;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          // Ce nœud porte `label: fileName` avec `excludeSemantics`, alors
          // que son enfant `Text` porte le même nom : sans cette exclusion,
          // l'arbre fusionné ferait énoncer le fichier deux fois par un
          // lecteur d'écran. Retirer le `label:` à la place rendrait le nœud
          // muet — ce n'est pas non plus la bonne correction.
          //
          // Le bouton de retrait est rendu hors de ce nœud : `excludeSemantics:
          // true` aurait sinon supprimé sa sémantique de bouton, échangeant un
          // doublon contre une action inatteignable au lecteur d'écran.
          child: Semantics(
            container: true,
            // Le nom du fichier est une donnée de l'utilisateur, pas un
            // libellé d'interface : il n'a rien à faire dans `ZcrudLabels`.
            label: attachment.fileName,
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (thumbnail != null) ...<Widget>[
                  thumbnail!,
                  SizedBox(width: theme.gapS),
                ],
                Flexible(
                  child: Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Invariant AD-13 : jamais `TextAlign.left`.
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Écart directionnel par construction : la cible suit le nom dans le
        // sens de lecture, elle n'est pas posée à un décalage `left`/`right`.
        const SizedBox(
          width: ZChatComposerReference.attachmentRemoveStartGap,
        ),
        _ZRemoveButton(onRemove: onRemove),
      ],
    );
  }
}

/// Le retrait — cible tactile ≥ 48 dp, sémantique de bouton, libellé résolu.
class _ZRemoveButton extends StatelessWidget {
  const _ZRemoveButton({required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTap: onRemove,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRemove,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            // La valeur de référence, elle-même au plancher : une cible de
            // retrait compacte est inexprimable des deux côtés.
            minHeight: ZChatComposerReference.attachmentRemoveTargetSize,
            minWidth: ZChatComposerReference.attachmentRemoveTargetSize,
          ),
          child: Align(
            // Invariant AD-13 : alignement directionnel.
            alignment: AlignmentDirectional.center,
            child: Text(
              zChatLabel(context, kZChatLabelRemoveAttachment),
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hauteur par défaut de la bande — la cible tactile, plus la respiration.
const double _kStripHeight = kZChatMinTapTarget + 16.0;
