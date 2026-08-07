/// **CR-IFFD-76** — le contrat d'assemblage du composer par défaut : messages
/// de DIAGNOSTIC (debug, jamais rendus ni annoncés) du widget
/// `ZDefaultChatComposer`.
///
/// 🔴 Ce fichier vit HORS des répertoires de rendu (`view/`, `render/`) parce
/// que la garde G-R10 y interdit — à raison — tout littéral porteur de mot :
/// une chaîne d'un fichier de rendu finit tôt ou tard affichée. Un message
/// d'`assert`, lui, n'atteint jamais l'écran d'un utilisateur : il s'adresse
/// au développeur qui vient de réintroduire le défaut ① d'IFFD, en debug
/// seulement. Le séparer rend la distinction STRUCTURELLE au lieu de demander
/// une exemption à la garde.
library;

/// Message de l'assertion « défaut ① » : la bande d'accessoires du composer
/// est une BANDE — la feuille de réglages (`ZChatSettingsSheet`) ne s'y monte
/// jamais inline. Mesuré chez IFFD : débordement de 149 px, fil masqué,
/// trouvé par la QA à l'écran. Le remède est [ZDefaultChatComposer.onOpenTools]
/// (la feuille appartient à l'hôte — F11).
const String kZChatBandSheetAssertMessage =
    'CR-IFFD-76 (defaut 1) : la bande du composer est une BANDE - la feuille '
    'de reglages ne s\'y monte jamais inline (deborde de 149 px mesure chez '
    'IFFD). Fournir onOpenTools pour OUVRIR la feuille.';
