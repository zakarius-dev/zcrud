/// Habillage « carte » OPT-IN du champ rich-text (GAP-6, CR parité 2026-08-11)
/// — en-tête icône + libellé, bordure/ombre, pilule d'action « Rédiger /
/// Modifier / Valider ».
///
/// MESURE legacy (`mef:141-310`) : carte rayon 14 à bordure colorée par
/// contenu + ombre ; en-tête à fond dégradé (icône `article_rounded` dans une
/// puce dégradée + libellé `titleMedium` w600, `labelBuilder` optionnel) ;
/// pilule dégradée « Rédiger » (vide) / « Modifier » (contenu) en mode block,
/// « Valider » (save) en mode inline. Articulation save legacy MESURÉE
/// (`mef:93-101`) : le listener `changes` est COMMENTÉ — l'inline n'écrit que
/// sur PERTE DE FOCUS ou sur « Valider », jamais à la frappe.
///
/// ## Chaîne de couleurs (FR-26) — paramètre > jeton/seam > rôle
///
/// AUCUNE couleur legacy n'entre dans le paquet : le dégradé signature DODLP
/// (`[Colors.blue, Colors.purple]` / `0xFF667EEA→0xFF764BA2`) reste CHEZ
/// L'HÔTE, qui le passe par [gradient] (voie « injection par l'hôte » —
/// suffisante, donc préférée au fichier de référence de couleurs). À défaut :
/// le seam `zResolveGradient` de `ZcrudScope` (jeton injecté, [gradientKey]),
/// puis les rôles `primaryContainer → tertiaryContainer` du `ColorScheme`
/// (même paire mesurée que `zDerivedGradientResolver` du cœur). Le fichier de
/// référence [ZMarkdownChromeReference] ne fige que des DIMENSIONS et des
/// scalaires d'opacité (patron `ZStudyCardReference` : « AUCUNE couleur ici »).
///
/// ## Opt-in strict (AD-57 / AD-4)
///
/// `chrome: null` (défaut) ⇒ rendu actuel STRICTEMENT inchangé (boîte bordée +
/// libellé texte). [deferWrites] est un SECOND opt-in : par défaut l'auto-save
/// actuel (écriture de tranche à chaque mutation) est CONSERVÉ — la pilule
/// « Valider » ne fait alors que committer/défocaliser explicitement. Un hôte
/// qui veut l'articulation legacy exacte (écriture sur blur/Valider SEULEMENT)
/// pose `deferWrites: true`.
library;

import 'package:flutter/widgets.dart';

/// Dimensions et scalaires de RÉFÉRENCE du chrome carte (mesurés `mef:141-310`)
/// — patron `ZStudyCardReference` : point d'audit UNIQUE, **aucune couleur**
/// (les couleurs suivent la chaîne paramètre > seam > rôle, cf. en-tête).
abstract final class ZMarkdownChromeReference {
  /// Rayon de la carte (**14** — `mef:145`).
  static const Radius cardRadius = Radius.circular(14);

  /// Rayon intérieur de l'en-tête (**13** — `mef:174`, rayon carte − bordure).
  static const Radius headerRadius = Radius.circular(13);

  /// Rayon des puces (icône, pilule d'action — **8**, `mef:188,223`).
  static const Radius chipRadius = Radius.circular(8);

  /// Padding de l'en-tête (**12** — `mef:166`).
  static const EdgeInsetsGeometry headerPadding = EdgeInsetsDirectional.all(12);

  /// Padding de la puce d'icône (**8** — `mef:181`).
  static const EdgeInsetsGeometry iconChipPadding = EdgeInsetsDirectional.all(8);

  /// Taille de l'icône d'en-tête (**18** — `mef:192`).
  static const double headerIconSize = 18;

  /// Largeur de bordure de carte : contenu présent (**1.5**) / vide (**1**)
  /// (`mef:150`).
  static const double borderWidthFilled = 1.5;

  /// Voir [borderWidthFilled].
  static const double borderWidthEmpty = 1;

  /// Opacité de la bordure colorée par contenu (**80/255** — `mef:148`).
  static const double borderOpacity = 80 / 255;

  /// Opacité du fond dégradé de l'en-tête (**15/255** — `mef:170`, thème clair).
  static const double headerGradientOpacity = 15 / 255;

  /// Opacité du dégradé de la puce d'icône (**40/255** — `mef:185`, thème clair).
  static const double iconChipGradientOpacity = 40 / 255;

  /// Ombre de carte : rayon de flou (**8**) et décalage (**0, 2**) (`mef:157-158`).
  static const double shadowBlurRadius = 8;

  /// Voir [shadowBlurRadius].
  static const Offset shadowOffset = Offset(0, 2);

  /// Opacité de l'ombre colorée par contenu (**10/255** — `mef:155`, thème clair).
  static const double shadowOpacity = 10 / 255;

  /// Padding de la pilule d'action (**12×6** — `mef:249-251`).
  static const EdgeInsetsGeometry actionPillPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6);
}

/// Configuration OPT-IN de l'habillage carte d'un champ rich-text (GAP-6).
///
/// Passée à `ZMarkdownField(chrome: …)` — `null` (défaut) ⇒ rendu historique
/// STRICTEMENT inchangé.
@immutable
class ZMarkdownFieldChrome {
  /// Construit un chrome carte — tout est optionnel.
  const ZMarkdownFieldChrome({
    this.icon,
    this.gradient,
    this.onGradient,
    this.gradientKey,
    this.labelBuilder,
    this.showActionButton = true,
    this.deferWrites = false,
  });

  /// Icône d'en-tête. `null` ⇒ `Icons.article_rounded` (parité `mef:191`).
  final IconData? icon;

  /// Dégradé signature de l'hôte (≥ 1 couleur ; la 1ʳᵉ teinte bordure/ombre).
  /// PRIORITAIRE sur [gradientKey] et sur les rôles du thème.
  final List<Color>? gradient;

  /// Premier plan LISIBLE sur [gradient] (icône/texte de la pilule). Un
  /// dégradé seul ne permet pas d'en déduire un contraste fiable (même contrat
  /// que `ZGradientSpec.onGradient` du cœur) — le legacy posait `Colors.white`
  /// en dur, REFUSÉ ici (FR-26) : chaîne paramètre > seam (`onGradient` du
  /// `ZGradientSpec` résolu) > rôle `onPrimaryContainer`.
  final Color? onGradient;

  /// Clé passée au seam `zResolveGradient` de `ZcrudScope` quand [gradient]
  /// est absent. `null` ⇒ nom du champ.
  final String? gradientKey;

  /// Remplace le libellé d'en-tête par un widget de l'hôte (parité
  /// `fieldLabelBuilder`, `mef:29`). Reçoit le libellé résolu du champ.
  final Widget Function(BuildContext context, String label)? labelBuilder;

  /// Affiche la pilule d'action (« Rédiger / Modifier » en mode block,
  /// « Valider » en mode inline). Sans objet en lecture seule.
  final bool showActionButton;

  /// **Articulation legacy de l'écriture** (inline uniquement, OPT-IN) :
  /// `true` ⇒ la tranche n'est écrite QUE sur « Valider » ou sur perte de
  /// focus (mesuré `mef:93-101`) — plus d'écriture à la frappe. `false`
  /// (défaut) ⇒ l'auto-save actuel des hôtes existants est CONSERVÉ.
  final bool deferWrites;
}
