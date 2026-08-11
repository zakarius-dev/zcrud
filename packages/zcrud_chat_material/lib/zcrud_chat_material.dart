/// Barrel d'API publique de `zcrud_chat_material`.
///
/// ## Ce que ce paquet est
///
/// C'est le satellite de **skin Material** du composer de chat : des
/// builders pixel-perfect (FAB d'envoi, chips d'effort, badges, chips de
/// pièces jointes, slider de budget labellisé) que le socle `zcrud_chat` —
/// chromatiquement nu par construction — ne porte pas lui-même.
///
/// Chaque widget se branche sur un créneau existant du socle
/// (`ZChatComposer.trailing`/`tools`/`leading`, ou
/// `ZChatSettingsSheet.computeBudgetBuilder`) : ce paquet ne construit ni
/// composer ni feuille de réglages parallèles, et l'envoi passe toujours par
/// `ZChatComposerSlot.submit`, le site unique fourni par le socle.
///
/// ## Ce que ce paquet ne fait pas
///
/// Aucune dimension, durée ou couleur d'identité n'est codée en dur ici :
/// tout passe par la chaîne de résolution du chrome (`zChatComposerChromeOf`,
/// priorité paramètre > jeton de thème > référence) ou par les constantes de
/// `ZChatComposerReference` ; les rôles Material viennent du `Theme` de
/// l'hôte. Toute cible tactile est tenue ≥ 48 dp en géométrie rendue et reste
/// directionnelle (invariant AD-13, RTL) ; ce paquet n'anime rien par
/// lui-même — les transitions viennent des primitives du socle, qui
/// respectent déjà le réglage de réduction des animations de la plateforme.
///
/// Chaque builder est indépendant (invariant AD-4) : l'hôte en monte un,
/// plusieurs ou aucun ; un réglage absent (contrôleur non fourni, catalogue
/// vide…) fait rendre `null`, jamais une affordance inerte.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_chat_material_attachment_chips.dart';
export 'src/presentation/z_chat_material_badge.dart';
export 'src/presentation/z_chat_material_budget_slider.dart';
export 'src/presentation/z_chat_material_composer.dart';
export 'src/presentation/z_chat_material_effort_chips.dart';
export 'src/presentation/z_chat_material_send_fab.dart';
