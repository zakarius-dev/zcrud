/// Les chips de pièces jointes en attente, en Material pixel-perfect.
///
/// La cible de retrait est la chip entière — jamais un petit bouton posé en
/// coin — pour tenir la cible tactile minimale en géométrie rendue et rester
/// directionnel (invariant AD-13). Les dimensions d'identité (taille de
/// l'avatar, rayon) viennent de `ZChatComposerReference`, jamais d'un
/// littéral local.
///
/// L'état vit dans le [ZChatAttachmentController] du socle (tranche
/// `pending`) ; le retrait passe par son verbe `remove(index)` — ce widget
/// ne détient aucun état propre (invariant AD-2).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

/// Builder prêt-à-brancher sur le créneau `leading` (ou `capture`) de
/// `ZChatComposer`, avec le contrôleur de pièces jointes de l'hôte.
///
/// Le widget rendu est toujours présent (réactif sur la tranche `pending`) :
/// rendre `null` figerait son absence, car le composer ne re-résout pas ses
/// créneaux à l'arrivée d'une pièce. La rangée se replie d'elle-même quand il
/// n'y a rien à afficher.
ZChatComposerSlotBuilder zChatMaterialAttachmentChips(
  ZChatAttachmentController attachments, {
  ZChatComposerChrome? chrome,
}) =>
    (BuildContext context, ZChatComposerSlot slot) =>
        ZChatMaterialAttachmentChips(attachments: attachments, chrome: chrome);

/// La rangée de chips — montable directement.
class ZChatMaterialAttachmentChips extends StatelessWidget {
  /// Construit la rangée.
  const ZChatMaterialAttachmentChips({
    required this.attachments,
    this.chrome,
    super.key,
  });

  /// Le contrôleur de pièces jointes du socle — source de vérité et voie de
  /// retrait uniques.
  final ZChatAttachmentController attachments;

  /// {@macro zcrud.chat_material.chrome_param}
  final ZChatComposerChrome? chrome;

  @override
  Widget build(BuildContext context) {
    // Abonné uniquement à la tranche `pending` (invariant AD-2) : la frappe
    // dans le champ de saisie ne reconstruit jamais cette rangée.
    return ValueListenableBuilder<List<ZPendingAttachment>>(
      valueListenable: attachments.pending,
      builder:
          (
            BuildContext context,
            List<ZPendingAttachment> pending,
            Widget? _,
          ) => pending.isEmpty
          ? const SizedBox.shrink()
          : Wrap(
              spacing: ZChatComposerReference.attachmentEndGap,
              children: <Widget>[
                for (int i = 0; i < pending.length; i++)
                  _chip(context, pending[i], i),
              ],
            ),
    );
  }

  Widget _chip(BuildContext context, ZPendingAttachment attachment, int index) {
    final Uint8List? thumb = attachment.thumbnailBytes;
    final double avatarSide = ZChatComposerReference.chipAvatarSize;
    // La cible de retrait est la chip entière ; le `Tooltip` porte le verbe
    // pour le survol et pour la sémantique.
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: kZChatMinTapTarget,
        minHeight: kZChatMinTapTarget,
      ),
      child: Tooltip(
        message: zChatLabel(context, kZChatLabelRemoveAttachment),
        child: InputChip(
          avatar: thumb == null
              ? Icon(Icons.insert_drive_file_outlined, size: avatarSide)
              : CircleAvatar(
                  radius: avatarSide / _kDiameterToRadius,
                  foregroundImage: MemoryImage(thumb),
                ),
          label: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
          onPressed: () => attachments.remove(index),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(ZChatComposerReference.chipRadius),
          ),
        ),
      ),
    );
  }
}

/// Un diamètre fait deux rayons.
const double _kDiameterToRadius = 2;
