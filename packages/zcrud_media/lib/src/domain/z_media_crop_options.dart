/// `ZMediaCropOptions` — options **neutres** de recadrage d'image (fp-4-2, AC2).
///
/// 🔴 **API NEUTRE (AD-40)** : ce value object pur-Dart ne référence **AUCUN**
/// type `image_cropper` (`CropAspectRatio`/`AndroidUiSettings`/…). Il exprime le
/// recadrage en données neutres ; la traduction vers `image_cropper` vit dans le
/// seam par défaut `ZPluginImageCropSeam` (couche `data`, confinée).
///
/// Le recadrage est **désactivé par défaut** ([disabled]) : sans opt-in
/// explicite, le flux d'acquisition d'image de `ZMediaFilePicker` est
/// **strictement inchangé** (rétro-compat AC2).
library;

/// Options `const` de recadrage post-pick (neutres, AD-40).
class ZMediaCropOptions {
  /// Construit des options de recadrage.
  ///
  /// [enabled] pilote l'activation : `false` (défaut) ⇒ aucun recadrage (flux
  /// d'AC1 inchangé). [aspectRatioX]/[aspectRatioY] fixent un ratio verrouillé
  /// optionnel (tous deux `> 0`) ; [lockAspectRatio] empêche l'utilisateur de le
  /// modifier. [maxWidth]/[maxHeight] bornent la sortie (pixels) ;
  /// [compressQuality] est un pourcentage `0..100` (défaut `100`).
  const ZMediaCropOptions({
    this.enabled = false,
    this.aspectRatioX,
    this.aspectRatioY,
    this.lockAspectRatio = false,
    this.maxWidth,
    this.maxHeight,
    this.compressQuality = 100,
  });

  /// Options **désactivées** (défaut) : le recadrage n'est jamais tenté.
  const ZMediaCropOptions.disabled() : this();

  /// Options **activées** avec réglages neutres optionnels.
  const ZMediaCropOptions.on({
    int? aspectRatioX,
    int? aspectRatioY,
    bool lockAspectRatio = false,
    int? maxWidth,
    int? maxHeight,
    int compressQuality = 100,
  }) : this(
          enabled: true,
          aspectRatioX: aspectRatioX,
          aspectRatioY: aspectRatioY,
          lockAspectRatio: lockAspectRatio,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          compressQuality: compressQuality,
        );

  /// `true` ⇒ le recadrage est tenté après un pick image (sinon jamais).
  final bool enabled;

  /// Composante horizontale d'un ratio verrouillé optionnel (`> 0`).
  final int? aspectRatioX;

  /// Composante verticale d'un ratio verrouillé optionnel (`> 0`).
  final int? aspectRatioY;

  /// Verrouille le ratio [aspectRatioX]/[aspectRatioY] côté UI native.
  final bool lockAspectRatio;

  /// Largeur maximale de sortie en pixels (`null` = non bornée).
  final int? maxWidth;

  /// Hauteur maximale de sortie en pixels (`null` = non bornée).
  final int? maxHeight;

  /// Qualité de compression `0..100` (`100` = maximale, défaut).
  final int compressQuality;

  /// `true` si un ratio verrouillé exploitable est fourni (deux composantes
  /// strictement positives).
  bool get hasAspectRatio =>
      aspectRatioX != null &&
      aspectRatioY != null &&
      aspectRatioX! > 0 &&
      aspectRatioY! > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZMediaCropOptions &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          aspectRatioX == other.aspectRatioX &&
          aspectRatioY == other.aspectRatioY &&
          lockAspectRatio == other.lockAspectRatio &&
          maxWidth == other.maxWidth &&
          maxHeight == other.maxHeight &&
          compressQuality == other.compressQuality;

  @override
  int get hashCode => Object.hash(runtimeType, enabled, aspectRatioX,
      aspectRatioY, lockAspectRatio, maxWidth, maxHeight, compressQuality);
}
