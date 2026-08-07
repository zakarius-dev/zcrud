/// Barrel d'API publique de `zcrud_chat_material` — lot K3 (chantier
/// composer-lex, arbitrage owner S1+S2 du 2026-08-07).
///
/// ## Ce que ce paquet est — et ce qu'il n'est PAS
///
/// C'est le **satellite de skin Material** du composer de chat : les builders
/// pixel-perfect lex_douane (FAB d'envoi, chips d'effort, badges, chips de
/// pièces jointes, slider de budget labellisé) que le socle `zcrud_chat` —
/// chromatiquement nu par construction, `material.dart` banni — ne peut pas
/// porter.
///
/// 🔴 **Des builders sur les créneaux du socle, JAMAIS une vue parallèle**
/// (motif CR-LEX-78, que ce dépôt a déjà payé : `ZSfAssistConversationView`,
/// doublon né d'une couture au mauvais niveau). Aucun composer bis, aucune
/// feuille bis : chaque widget se monte dans `ZChatComposer.trailing/tools/
/// leading` ou dans `ZChatSettingsSheet.computeBudgetBuilder`, et l'envoi passe
/// par [ZChatComposerSlot.submit] — le site unique fourni par le socle.
///
/// 🔴 **Zéro valeur recopiée.** Toute dimension, durée ou couleur d'identité
/// vient de la chaîne du chrome K2 (`zChatComposerChromeOf` : paramètre >
/// jeton > référence) ou des constantes de `ZChatComposerReference` ; les rôles
/// Material (`ColorScheme`) viennent du `Theme` de l'hôte. La garde de source
/// du paquet interdit tout littéral numérique, `Color(`, `Colors.` et
/// `Duration(` dans `lib/` — exemption ZÉRO.
///
/// 🔴 **Les défauts lex ne sont pas reproduits** : cibles ≥ 48 dp en géométrie
/// RENDUE (le retirer-PJ 20 dp de lex est inexprimable ici — la chip entière
/// retire), directionnel partout (AD-13), et ce paquet **n'anime rien
/// lui-même** (aucun `Timer`/`AnimationController` : les transitions viennent
/// des primitives K2 du socle, qui respectent Reduce-Motion — mesuré chez K2).
///
/// **AD-4** : chaque builder est indépendant — l'hôte en monte un, plusieurs ou
/// aucun ; un réglage absent (`slot.settings == null`, catalogue vide…) rend
/// `null`/rien, jamais une affordance inerte.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_chat_material_attachment_chips.dart';
export 'src/presentation/z_chat_material_badge.dart';
export 'src/presentation/z_chat_material_budget_slider.dart';
export 'src/presentation/z_chat_material_effort_chips.dart';
export 'src/presentation/z_chat_material_send_fab.dart';
