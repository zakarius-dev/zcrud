/// Relais d'échec d'un seam d'hôte, sans faire tomber le rendu.
///
/// Quand un seam fourni par l'application (`ZChatRenderer`,
/// `ZChatShellRenderer`, ou un créneau d'identité/actions par message) lève,
/// l'exception n'interrompt jamais la conversation : le rendu neutre prend le
/// relais (invariant AD-10). L'exception reste néanmoins observable : elle
/// est relayée à `FlutterError.onError`, donc à la console et aux rapports de
/// crash de l'hôte, avec sa pile complète — de quoi déboguer le seam fautif
/// sans jamais faire disparaître la conversation affichée.
library;

import 'package:flutter/foundation.dart';

/// Nom du seam de **bloc** — identifiant de diagnostic, jamais un texte affiché.
const String kZChatSeamBlock = 'ZChatRenderer.buildBlock';

/// Nom du seam de **coquille** — idem.
const String kZChatSeamShell = 'ZChatShellRenderer.buildShell';

/// Nom du seam d'**identité par message** — idem.
const String kZChatSeamIdentitySlot = 'ZChatMessageTile.identityBuilder';

/// Nom du seam d'**actions par message** — idem.
const String kZChatSeamActionsSlot = 'ZChatMessageTile.actionsBuilder';

/// Nom du seam des **lectures d'état d'un artefact déclaré** — idem.
///
/// Une seule constante pour les quatre lectures (`presence`, `count`, `busy`,
/// la condition d'un verbe) : elles partagent le même repli **fermant**, et
/// la pile relayée désigne déjà la closure fautive de l'hôte.
const String kZChatSeamArtifactSpec = 'ZChatArtifactSpec state reading';

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
