/// Entrée « podcast » du hub d'ajout de contenu.
///
/// Le hub ne fabrique aucune entrée : il rend celles que l'hôte compose. La
/// famille « podcast » avait déjà sa clé de teinte stable
/// ([ZContentHubReference.colorKeyPodcast]) mais aucune voie pour construire
/// l'entrée — chaque hôte devait la réécrire, et rien ne garantissait que deux
/// écrans lui donnent la même identité visuelle.
///
/// [zPodcastHubEntry] est cette voie : une fonction **pure**, sans état, qui
/// rend une entrée prête à être placée dans une section, ou `null`.
///
/// ## Montée seulement si elle est câblée
///
/// L'entrée est rendue **uniquement** si les trois pièces qui la rendent utile
/// sont fournies : un glyphe, un libellé, et un geste. Il en manque une ⇒
/// `null`, donc **rien** dans l'arbre du hub (invariant AD-4 : capacité
/// absente, jamais une entrée morte ni un libellé en dur). Un hôte qui
/// n'appelle pas cette fonction, ou l'appelle sans câblage, voit un hub
/// strictement identique à avant.
///
/// ## Aucune apparence propre
///
/// L'entrée ne porte ni couleur ni dimension : seulement la **clé** de teinte
/// stable de la famille. Toute l'apparence reste résolue par la feuille selon
/// la chaîne habituelle (paramètre > jeton `ZcrudTheme.contentHub*` >
/// [ZContentHubReference]).
///
/// ```dart
/// final ZContentHubEntry? podcast = zPodcastHubEntry(
///   icon: Icons.podcasts_outlined,
///   label: l10n.generatePodcast,   // INJECTÉ — le socle ne nomme rien
///   onTap: _openPodcastSheet,
/// );
/// // …
/// entries: <ZContentHubEntry>[if (podcast != null) podcast],
/// ```
library;

import 'package:flutter/widgets.dart' show IconData, VoidCallback;

import 'z_content_hub_reference.dart';
import 'z_content_hub_sheet.dart';

/// Construit l'entrée de hub « podcast », ou `null` si elle n'est pas câblée.
///
/// Rend `null` — donc **rien dans l'arbre** — dès que [icon], [label] ou
/// [onTap] manque. La teinte est portée par
/// [ZContentHubReference.colorKeyPodcast] : c'est une **clé** stable, jamais
/// rendue, jamais traduite, et jamais une couleur littérale (FR-26).
///
/// [enabled] à `false` rend une entrée présente mais non actionnable (le hub
/// l'affiche estompée) : c'est le cas « capacité connue mais indisponible »,
/// distinct de l'absence.
ZContentHubEntry? zPodcastHubEntry({
  IconData? icon,
  String? label,
  VoidCallback? onTap,
  String? hint,
  String? badgeLabel,
  String? badgeSemanticLabel,
  bool enabled = true,
}) {
  if (icon == null || label == null || onTap == null) return null;
  return ZContentHubEntry(
    icon: icon,
    label: label,
    hint: hint,
    onTap: onTap,
    enabled: enabled,
    colorKey: ZContentHubReference.colorKeyPodcast,
    badgeLabel: badgeLabel,
    badgeSemanticLabel: badgeSemanticLabel,
  );
}
