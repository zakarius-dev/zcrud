/// Bande des pièces jointes en attente — `ZChatAttachmentStrip` (CHAT-5).
///
/// Rendu **neutre, zéro dépendance tierce** de `ZChatAttachmentController.pending`
/// (patron strict de `ZChatConversationView` : `ListView.builder`, `Semantics`,
/// tokens de `ZcrudTheme`, libellés résolus par `zChatLabel(context, clé)`).
///
/// ## 🔴 Trois contraintes AD-13 que la bande d'IFFD ne tient pas
///
/// * **cible tactile** : le retrait est un `ConstrainedBox` à
///   [kZChatMinTapTarget] (48 dp), jamais une icône de 16 dp posée en coin ;
/// * **directionnalité** : `EdgeInsetsDirectional` / `AlignmentDirectional` /
///   `TextAlign.start` — jamais `left`/`right`, sans quoi la bande est à
///   l'envers en RTL ;
/// * **sémantique** : chaque vignette est un nœud annoncé, chaque retrait est un
///   `Semantics(button: true)`. IFFD : 0 `Semantics` sur 5153 lignes.
///
/// ## 🔴 Aucune image n'est décodée ici
///
/// `ZPendingAttachment.thumbnailBytes` porte les octets, mais cette bande ne les
/// rend pas : `Image.memory` décoderait un bitmap de 10 Mio **dans le composer**,
/// à chaque rebuild, pour une vignette de 48 dp — l'exact opposé de SM-1. Le
/// nom du fichier est rendu ; l'aperçu riche appartient à l'hôte, qui a le
/// budget et le cache pour le faire (et peut le brancher par [thumbnailBuilder]).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../attachment/z_chat_attachment_controller.dart';
import '../attachment/z_pending_attachment.dart';
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

  /// Le contrôleur écouté. Il n'est **ni créé ni disposé** ici : son cycle de
  /// vie appartient à l'hôte (AD-2).
  final ZChatAttachmentController controller;

  /// Couture d'aperçu, ou `null` (aucune vignette).
  final ZChatAttachmentThumbnailBuilder? thumbnailBuilder;

  /// Hauteur de la bande **demandée** par l'hôte.
  ///
  /// 🔴 Lire [effectiveHeight], jamais ce champ, pour dimensionner : une
  /// hauteur inférieure à `kZChatMinTapTarget` **écraserait la cible tactile**
  /// (AD-13). Le `ConstrainedBox` du bouton ne protège de rien ici : sous une
  /// contrainte de hauteur **serrée** venue du parent, il est écrasé en
  /// silence — mesuré, `height: 30` rendait une cible de **30 dp** sans
  /// exception ni avertissement.
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
                  // 🔴 `.builder` — JAMAIS `ListView(children: [...])`.
                  scrollDirection: Axis.horizontal,
                  // 🔴 DÉFAUT TROUVÉ PAR LA GARDE ≥ 48 dp, et corrigé ici. Avec
                  // `theme.formPadding` (12 dp sur les QUATRE côtés), la hauteur
                  // utile tombait à 64 − 24 = **40 dp** : la contrainte
                  // `minHeight: 48` du bouton était écrasée par le parent, et la
                  // cible AD-13 violée alors que le code la déclarait. Une marge
                  // de bande est HORIZONTALE — la verticale, ici, ne sépare rien.
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: theme.gapM,
                  ),
                  itemCount: pending.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ZPendingAttachment attachment = pending[index];
                    return Padding(
                      // AD-13 : marge DIRECTIONNELLE.
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
          // 🔴 **Correction de fin d'epic (MAJEUR — double annonce).** Ce nœud
          // portait `label: fileName` **sans** `excludeSemantics`, et son enfant
          // `Text` porte le même nom : mesuré `<rapport.pdf\nrapport.pdf>` sur
          // l'arbre fusionné — le lecteur d'écran énonçait le fichier DEUX fois.
          // Le correctif jumeau est documenté dans
          // `zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart:73-76`, et
          // il rappelle l'erreur à ne PAS commettre : retirer le `label:` à la
          // place rend le nœud **muet**.
          //
          // 🔴 Le bouton de retrait est passé **HORS** de ce nœud. Le sortir
          // n'est pas cosmétique : `excludeSemantics: true` aurait sinon
          // supprimé sa sémantique de bouton — on aurait échangé un doublon
          // contre une action inatteignable au lecteur d'écran.
          child: Semantics(
            container: true,
            // Le nom du fichier est une DONNÉE de l'utilisateur, pas un libellé
            // d'interface : il n'a rien à faire dans `ZcrudLabels`.
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
                    // AD-13 : jamais `TextAlign.left`.
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          ),
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
            minHeight: kZChatMinTapTarget,
            minWidth: kZChatMinTapTarget,
          ),
          child: Align(
            // AD-13 : alignement DIRECTIONNEL.
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
