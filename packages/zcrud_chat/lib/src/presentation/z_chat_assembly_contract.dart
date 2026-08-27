/// Contrat d'assemblage du composer par défaut : messages de diagnostic
/// (debug uniquement, jamais rendus ni annoncés) du widget
/// `ZDefaultChatComposer`.
///
/// Ce fichier vit hors des répertoires de rendu (`view/`, `render/`) parce
/// qu'une garde de source y interdit tout littéral porteur de mot : une
/// chaîne d'un fichier de rendu finit tôt ou tard affichée. Un message
/// d'`assert`, lui, n'atteint jamais l'écran d'un utilisateur — il s'adresse
/// au développeur qui vient de réintroduire l'erreur d'assemblage visée,
/// en debug seulement. Le séparer rend cette distinction structurelle au
/// lieu de demander une exemption à la garde.
library;

/// Message de l'assertion qui protège l'assemblage par défaut : la bande
/// d'accessoires du composer est une bande — la feuille de réglages
/// (`ZChatSettingsSheet`) ne s'y monte jamais inline, sous peine de
/// débordement visuel. Le remède est [ZDefaultChatComposer.onOpenTools] :
/// la feuille appartient à l'hôte, elle ne se monte pas d'elle-même.
const String kZChatBandSheetAssertMessage =
    'CR-IFFD-76 (defaut 1) : la bande du composer est une BANDE - la feuille '
    'de reglages ne s\'y monte jamais inline (deborde de 149 px mesure chez '
    'IFFD). Fournir onOpenTools pour OUVRIR la feuille.';

/// Message de l'assertion qui refuse les deux intentions contradictoires de
/// remplacement du composer sur un écran assemblé : `composerBuilder`
/// remplace le composer **entier**, `composerSlots` en habille les pièces
/// une à une. Déclarer les deux perd silencieusement l'un des deux — en
/// release, le remplacement total prime.
const String kZChatComposerSlotsExclusiveAssertMessage =
    'composerBuilder et composerSlots sont exclusifs : le premier remplace le '
    'composer ENTIER, le second en habille les pieces. Choisir l\'un des deux '
    '- le remplacement total prime, les creneaux seraient perdus.';
