/// Relais d'échec d'un **seam d'hôte** — arbitrage AD-10 de fin d'epic.
///
/// 🔴 **Pourquoi ce fichier existe.** Les seams de rendu (`ZChatRenderer`,
/// `ZChatShellRenderer`) **propageaient** l'exception de l'hôte, tandis que le
/// seam d'annonce du kernel (`ZContentBlock.accessibleText`) l'**absorbait**.
/// Deux lectures d'AD-10 dans le même lot : le même défaut d'hôte dégradait une
/// annonce d'un côté et rougissait l'écran de l'autre — et une coquille tierce
/// qui lève ne retombait jamais sur la liste neutre, contredisant la promesse
/// « le défaut zéro-dépendance reste fonctionnel » (AD-57).
///
/// La lecture retenue est celle du kernel : **absorber**, et retomber sur le
/// rendu neutre. Le seul argument qui plaidait pour la propagation — « un hôte
/// doit pouvoir déboguer son renderer » — est préservé ici : l'exception est
/// relayée à `FlutterError.onError`, donc à la console et aux rapports de crash
/// de l'hôte, **avec sa pile**. Ce qu'elle ne fait plus, c'est emporter la
/// conversation.
library;

import 'package:flutter/foundation.dart';

/// Nom du seam de **bloc** — identifiant de diagnostic, jamais un texte affiché.
const String kZChatSeamBlock = 'ZChatRenderer.buildBlock';

/// Nom du seam de **coquille** — idem.
const String kZChatSeamShell = 'ZChatShellRenderer.buildShell';

/// Nom du seam d'**identité par message** (CR-IFFD-71) — idem.
const String kZChatSeamIdentitySlot = 'ZChatMessageTile.identityBuilder';

/// Nom du seam d'**actions par message** (CR-IFFD-71) — idem.
const String kZChatSeamActionsSlot = 'ZChatMessageTile.actionsBuilder';

/// Relaie l'échec d'un seam d'hôte **sans** faire tomber le rendu.
///
/// [seam] nomme le membre fautif (`'ZChatRenderer.buildBlock'`…) : sans lui,
/// l'hôte lirait une pile dans du code de socle sans savoir lequel de ses trois
/// points d'injection l'a produite.
void zChatReportSeamFailure({
  required Object error,
  required StackTrace stack,
  required String seam,
}) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'zcrud_chat',
      context: ErrorDescription(
        'levée par le seam d\'hôte $seam. Le rendu neutre a pris le relais '
        '(AD-10) : la conversation reste affichée, mais CE bloc — ou cette '
        'coquille — vient du socle et non de votre renderer.',
      ),
    ),
  );
}
