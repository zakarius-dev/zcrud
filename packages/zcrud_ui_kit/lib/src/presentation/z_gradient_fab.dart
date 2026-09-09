/// Bouton d'action flottant portant l'**identité** de la page.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_page_shell_reference.dart';

/// Dégradé d'identité d'un bouton d'action, par ordre de priorité
/// **clé explicite > clé de signature > première entrée de la palette**.
///
/// Rend `null` quand rien ne résout — le profil `ZReferenceProfile.neutral`
/// en particulier — et le bouton retombe alors sur le bouton Material nu.
ZGradientSpec? _zFabGradient(
  BuildContext context,
  String? gradientKey,
  String? signatureKey,
) {
  if (gradientKey != null) {
    return gradientKey.isEmpty ? null : zResolveGradient(context, gradientKey);
  }
  if (signatureKey != null && signatureKey.isNotEmpty) {
    return zResolveGradient(context, zSignatureKey(signatureKey));
  }
  // Aucune identité déclarée : le bouton porte la teinte de TÊTE de la
  // palette — jeton d'abord, référence ensuite, et seulement sous `legacy`.
  final List<ZGradientSpec>? palette =
      ZcrudTheme.of(context).signaturePalette ??
      zLegacyOr<List<ZGradientSpec>>(
        context,
        ZSignaturePaletteReference.gradients,
      );
  if (palette == null || palette.isEmpty) return null;
  return palette.first;
}

/// Élévation du bouton posé sur son fond, par ordre **jeton
/// `ZcrudTheme.fabElevation` > référence**. Une valeur négative n'est pas une
/// élévation : elle est ignorée.
double _zFabElevation(BuildContext context) {
  final double? token = ZcrudTheme.of(context).fabElevation;
  if (token == null || token.isNaN || token < 0) {
    return ZPageShellReference.fabElevation;
  }
  return token;
}

/// Côté du glyphe, par ordre **jeton `ZcrudTheme.fabIconSize` > référence**.
/// Une taille nulle ou négative est ignorée : elle rendrait le glyphe absent.
double _zFabIconSize(BuildContext context) {
  final double? token = ZcrudTheme.of(context).fabIconSize;
  if (token == null || token.isNaN || token <= 0) {
    return ZPageShellReference.fabIconSize;
  }
  return token;
}

/// Style du libellé étendu, par ordre **jeton `ZcrudTheme.fabLabelStyle` >
/// référence** (graisse et interlettrage figés).
TextStyle _zFabLabelStyle(BuildContext context) =>
    ZcrudTheme.of(context).fabLabelStyle ??
    const TextStyle(
      fontWeight: ZPageShellReference.fabLabelWeight,
      letterSpacing: ZPageShellReference.fabLabelLetterSpacing,
    );

/// Bouton d'action flottant dont le fond est le **dégradé d'identité** de la
/// page, avec une ombre reprenant sa teinte.
///
/// ## Ce que ce widget rend
///
/// * [label] fourni ⇒ un bouton **étendu** (glyphe + libellé) posé sur un fond
///   dégradé à coins arrondis ;
/// * [label] nul ⇒ un bouton **circulaire** (glyphe seul) sur un fond dégradé
///   circulaire ;
/// * **aucun dégradé résolu** ⇒ un `FloatingActionButton` Material **nu**,
///   sans conteneur ni ombre ajoutés : le rendu est celui du SDK, à
///   l'identique.
///
/// ## D'où vient la couleur
///
/// De la couture `zResolveGradient` de `zcrud_core`, dans l'ordre
/// **[gradientKey] > [signatureKey] > tête de palette**. La palette elle-même
/// suit **jeton `ZcrudTheme.signaturePalette` > référence auditée**, cette
/// dernière n'étant lue que sous le profil `ZReferenceProfile.legacy`.
///
/// Poser `ZcrudTheme(referenceProfile: ZReferenceProfile.neutral)` à la racine
/// ramène donc ce bouton au `FloatingActionButton` nu, partout à la fois.
///
/// ## Contraste
///
/// Le premier plan est `ZGradientSpec.onGradient` — une valeur **mesurée**
/// contre la bande médiane du dégradé, jamais un blanc décrété. L'ombre reprend
/// la teinte de base du dégradé : c'est une ombre colorée, pas une ombre grise.
///
/// ## Ce que le thème peut régler
///
/// Quatre métriques du bouton **sur fond dégradé** sont remplaçables par
/// `ZcrudTheme`, chacune par ordre **jeton > référence** : `fabShape`,
/// `fabElevation`, `fabIconSize`, `fabLabelStyle`. `fabShape` gouverne les
/// DEUX faces à la fois — la forme du bouton et celle de son fond —, parce que
/// les dissocier laisserait un bouton carré dans un halo rond. Aucune des
/// quatre ne touche le bouton **sans dégradé**, qui reste celui du SDK.
///
/// ## Accessibilité
///
/// [tooltip] alimente à la fois l'info-bulle et l'étiquette du lecteur d'écran.
/// Il est **obligatoire en pratique** sur la forme circulaire : un glyphe seul
/// n'annonce rien. La cible tactile reste celle du SDK (56 dp), donc au-dessus
/// du plancher de 48 dp.
class ZGradientFab extends StatelessWidget {
  /// Construit le bouton. [onPressed] nul ⇒ bouton **désactivé** (comportement
  /// du SDK), le fond dégradé reste posé.
  const ZGradientFab({
    required this.onPressed,
    required this.icon,
    this.label,
    this.gradientKey,
    this.signatureKey,
    this.tooltip,
    this.heroTag,
    super.key,
  });

  /// Action déclenchée au tap (nul ⇒ bouton désactivé).
  final VoidCallback? onPressed;

  /// Glyphe du bouton.
  final IconData icon;

  /// Libellé du bouton **étendu**. `null` ⇒ bouton circulaire.
  final String? label;

  /// Clé de dégradé **explicite**, passée telle quelle à la couture. Vide
  /// (`''`) ⇒ aucun dégradé, donc bouton Material nu : échappatoire par site.
  final String? gradientKey;

  /// Identité alimentant la clé `zcrud.signature.<identité>` quand
  /// [gradientKey] n'est pas déclarée.
  final String? signatureKey;

  /// Info-bulle **et** étiquette d'accessibilité.
  final String? tooltip;

  /// `heroTag` du `FloatingActionButton` — à distinguer explicitement quand
  /// deux boutons coexistent dans un même `Navigator`.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final ZGradientSpec? spec = _zFabGradient(
      context,
      gradientKey,
      signatureKey,
    );
    final String? text = label;
    if (spec == null) {
      // Aucun dégradé : bouton du SDK, sans enveloppe ni ombre ajoutées.
      return text == null
          ? FloatingActionButton(
              onPressed: onPressed,
              tooltip: tooltip,
              heroTag: heroTag,
              child: Icon(icon),
            )
          : FloatingActionButton.extended(
              onPressed: onPressed,
              tooltip: tooltip,
              heroTag: heroTag,
              icon: Icon(icon),
              label: Text(text),
            );
    }
    // Résolus APRÈS l'échappatoire ci-dessus : le bouton nu est celui du SDK,
    // et ces jetons n'ont pas à le toucher.
    final OutlinedBorder? shape = ZcrudTheme.of(context).fabShape;
    final double elevation = _zFabElevation(context);
    final double iconSize = _zFabIconSize(context);
    final Color base = spec.gradient.colors.isEmpty
        ? Theme.of(context).colorScheme.primary
        : spec.gradient.colors.first;
    final List<BoxShadow> shadow = <BoxShadow>[
      BoxShadow(
        color: base.withValues(alpha: ZPageShellReference.fabShadowAlpha),
        blurRadius: ZPageShellReference.fabShadowBlurRadius,
        offset: ZPageShellReference.fabShadowOffset,
      ),
    ];
    if (text == null) {
      return DecoratedBox(
        // `shape` nul ⇒ la décoration de référence, à l'identique ; posé, le
        // fond épouse la MÊME forme que le bouton.
        decoration: shape == null
            ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: spec.gradient,
                boxShadow: shadow,
              )
            : ShapeDecoration(
                shape: shape,
                gradient: spec.gradient,
                shadows: shadow,
              ),
        child: FloatingActionButton(
          onPressed: onPressed,
          tooltip: tooltip,
          heroTag: heroTag,
          backgroundColor: Colors.transparent,
          foregroundColor: spec.onGradient,
          elevation: elevation,
          highlightElevation: elevation,
          shape: shape ?? const CircleBorder(),
          child: Icon(icon, size: iconSize),
        ),
      );
    }
    return DecoratedBox(
      decoration: shape == null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(
                ZPageShellReference.fabCornerRadius,
              ),
              gradient: spec.gradient,
              boxShadow: shadow,
            )
          : ShapeDecoration(
              shape: shape,
              gradient: spec.gradient,
              shadows: shadow,
            ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        tooltip: tooltip,
        heroTag: heroTag,
        backgroundColor: Colors.transparent,
        foregroundColor: spec.onGradient,
        elevation: elevation,
        highlightElevation: elevation,
        // Nul ⇒ la forme du SDK, exactement comme avant ce créneau.
        shape: shape,
        icon: Icon(icon, size: iconSize),
        label: Text(text, style: _zFabLabelStyle(context)),
      ),
    );
  }
}
