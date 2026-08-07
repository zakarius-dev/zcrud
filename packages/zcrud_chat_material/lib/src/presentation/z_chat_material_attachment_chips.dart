/// Les **chips de pièces jointes** — lot K3, pixel lex SANS son défaut.
///
/// lex prévisualise ses pièces jointes avec un bouton « retirer » de **20 dp**
/// posé en `Positioned(top: 0, right: 0)` (`chat_input.dart:1025-1032`) — les
/// deux défauts relevés à l'étude (§A.2) : cible ≪ 48 dp ET non-directionnel.
/// **Aucun des deux n'est reproductible ici** : la chip ENTIÈRE est la cible de
/// retrait (≥ 48 dp en géométrie rendue, imposé par contrainte plancher), et il
/// n'existe aucun décalage `right:` dans ce fichier.
///
/// Le pixel repris de lex : avatar **24 dp** (vignette ronde ou glyphe de
/// fichier) et radius **12** — via `ZChatComposerReference.chipAvatarSize` /
/// `chipRadius`, jamais des littéraux.
///
/// L'état vit dans le [ZChatAttachmentController] du socle (tranche `pending`) ;
/// le retrait passe par son verbe `remove(index)` — aucun état ici (AD-2).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

/// Builder prêt-à-brancher sur le créneau `leading` (ou `capture`) de
/// `ZChatComposer`, avec le contrôleur de pièces jointes de l'hôte.
///
/// ⚠️ Il rend TOUJOURS le widget (réactif sur la tranche `pending`) : rendre
/// `null` sur `pending.value` figerait l'absence — le composer ne re-résout pas
/// ses créneaux quand une pièce arrive. La rangée se replie d'elle-même quand
/// il n'y a rien.
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

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex (chaîne K2).
  final ZChatComposerChrome? chrome;

  @override
  Widget build(BuildContext context) {
    // 🔴 LA tranche `pending`, et elle seule (SM-1) : la frappe ne reconstruit
    // jamais cette rangée.
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
    // 🔴 La cible de RETRAIT est la chip entière — le « retirer » de 20 dp de
    // lex est inexprimable ici. Le `Tooltip` porte le verbe pour le survol ET
    // pour la sémantique.
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
