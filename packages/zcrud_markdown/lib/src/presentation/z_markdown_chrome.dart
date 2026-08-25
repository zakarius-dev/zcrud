/// Habillage « carte » du champ rich-text — en-tête icône + libellé,
/// bordure/ombre teintées par le contenu, pilule d'action.
///
/// Carte de rayon 14 dont la bordure et l'ombre se teintent quand le champ
/// porte du contenu ; en-tête à fond dégradé (icône dans une puce dégradée +
/// libellé `titleMedium` w600, [labelBuilder] optionnel) ; pilule dégradée
/// portant l'affordance d'édition — « rédiger »/« modifier » en mode `block`,
/// « valider » en mode `inline`, libellés résolus par le système l10n injecté.
///
/// ## Chaîne de couleurs — paramètre > jeton/seam > rôle
///
/// AUCUNE couleur n'est codée dans le paquet. Le dégradé signature de l'hôte
/// se passe par [gradient] ; à défaut, le seam `zResolveGradient` de
/// `ZcrudScope` (jeton injecté, [gradientKey]) ; à défaut encore, les rôles
/// `primaryContainer → tertiaryContainer` du `ColorScheme`. Le fichier de
/// référence [ZMarkdownChromeReference] ne fige que des DIMENSIONS et des
/// scalaires d'opacité — jamais une couleur.
///
/// ## Quand la carte s'applique
///
/// Elle est le rendu PAR DÉFAUT du champ rich-text **compact** servi par le
/// registre (`inlineMarkdown`), en édition comme en lecture seule : un hôte
/// n'a rien à déclarer pour l'obtenir. La voie `ZMarkdownField(controller:)`
/// et le mode `block` gardent leur rendu sans carte — leur chrome reste un
/// paramètre. Passer un [ZMarkdownFieldChrome] REMPLACE le défaut trait par
/// trait ; il n'existe pas de valeur pour retirer la carte d'un champ compact
/// (poser son propre libellé ou masquer la pilule s'obtient par [labelBuilder]
/// et [showActionButton]).
///
/// [deferWrites] reste un OPT-IN et vaut `false` par défaut : l'écriture de
/// tranche à chaque mutation est conservée, la pilule ne faisant que
/// committer/défocaliser explicitement. Un hôte qui veut l'écriture différée
/// (sur blur ou sur pilule SEULEMENT) la demande — cf. l'avertissement porté
/// par [ZMarkdownFieldChrome.deferWrites].
library;

import 'package:flutter/widgets.dart';

/// Dimensions et scalaires de RÉFÉRENCE du chrome carte (mesuré sur le legacy)
/// — patron `ZStudyCardReference` : point d'audit UNIQUE, **aucune couleur**
/// (les couleurs suivent la chaîne paramètre > seam > rôle, cf. en-tête).
abstract final class ZMarkdownChromeReference {
  /// Rayon de la carte (**14**).
  static const Radius cardRadius = Radius.circular(14);

  /// Rayon intérieur de l'en-tête (**13**, rayon carte − bordure).
  static const Radius headerRadius = Radius.circular(13);

  /// Rayon des puces (icône, pilule d'action — **8**).
  static const Radius chipRadius = Radius.circular(8);

  /// Padding de l'en-tête (**12**).
  static const EdgeInsetsGeometry headerPadding = EdgeInsetsDirectional.all(12);

  /// Padding de la puce d'icône (**8**).
  static const EdgeInsetsGeometry iconChipPadding = EdgeInsetsDirectional.all(8);

  /// Taille de l'icône d'en-tête (**18**).
  static const double headerIconSize = 18;

  /// Largeur de bordure de carte : contenu présent (**1.5**) / vide (**1**).
  static const double borderWidthFilled = 1.5;

  /// Voir [borderWidthFilled].
  static const double borderWidthEmpty = 1;

  /// Opacité de la bordure colorée par contenu (**80/255**).
  static const double borderOpacity = 80 / 255;

  /// Opacité du fond dégradé de l'en-tête (**15/255**, thème clair).
  static const double headerGradientOpacity = 15 / 255;

  /// Opacité du dégradé de la puce d'icône (**40/255**, thème clair).
  static const double iconChipGradientOpacity = 40 / 255;

  /// Ombre de carte : rayon de flou (**8**) et décalage (**0, 2**).
  static const double shadowBlurRadius = 8;

  /// Voir [shadowBlurRadius].
  static const Offset shadowOffset = Offset(0, 2);

  /// Opacité de l'ombre colorée par contenu (**10/255**, thème clair).
  static const double shadowOpacity = 10 / 255;

  /// Padding de la pilule d'action (**12×6**).
  static const EdgeInsetsGeometry actionPillPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6);
}

/// Configuration de l'habillage carte d'un champ rich-text.
///
/// Passée à `ZMarkdownField(chrome: …)`. `null` ⇒ le champ applique le chrome
/// par DÉFAUT de son mode (carte pour le champ compact du registre, aucune
/// carte pour la voie `controller` et le mode `block`).
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

  /// Icône d'en-tête. `null` ⇒ `Icons.article_rounded` (parité legacy).
  final IconData? icon;

  /// Dégradé signature de l'hôte (≥ 1 couleur ; la 1ʳᵉ teinte bordure/ombre).
  /// PRIORITAIRE sur [gradientKey] et sur les rôles du thème.
  final List<Color>? gradient;

  /// Premier plan LISIBLE sur [gradient] (icône/texte de la pilule). Un
  /// dégradé seul ne permet pas d'en déduire un contraste fiable (même contrat
  /// que `ZGradientSpec.onGradient` du cœur) — le legacy posait `Colors.white`
  /// en dur, REFUSÉ ici : chaîne paramètre > seam (`onGradient` du
  /// `ZGradientSpec` résolu) > rôle `onPrimaryContainer`.
  final Color? onGradient;

  /// Clé passée au seam `zResolveGradient` de `ZcrudScope` quand [gradient]
  /// est absent. `null` ⇒ nom du champ.
  final String? gradientKey;

  /// Remplace le libellé d'en-tête par un widget de l'hôte (parité
  /// `fieldLabelBuilder`). Reçoit le libellé résolu du champ.
  final Widget Function(BuildContext context, String label)? labelBuilder;

  /// Affiche la pilule d'action (« Rédiger / Modifier » en mode block,
  /// « Valider » en mode inline). Sans objet en lecture seule.
  final bool showActionButton;

  /// **Écriture DIFFÉRÉE** (mode compact uniquement, opt-in).
  ///
  /// `true` ⇒ la tranche n'est écrite QUE sur la pilule d'action ou sur perte
  /// de focus — plus rien à la frappe. `false` (DÉFAUT) ⇒ chaque mutation
  /// écrit la tranche.
  ///
  /// ⚠️ Le différé n'est sûr que si la soumission du formulaire est PRÉCÉDÉE
  /// d'une perte de focus du champ. Un écran qui soumet directement depuis un
  /// bouton n'ayant pas défocalisé l'éditeur enregistre la tranche telle
  /// qu'elle était avant la saisie : l'utilisateur perd son texte, sans aucun
  /// message. C'est pourquoi le défaut ne l'active pas.
  final bool deferWrites;
}
