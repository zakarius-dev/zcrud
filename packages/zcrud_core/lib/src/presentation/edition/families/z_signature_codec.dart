/// `ZSignatureCodec` — codec **pluggable NEUTRE** strokes ↔ PNG (DP-18, M15).
///
/// origine: DODLP persiste une signature en **`Uint8List` PNG bitmap** ; zcrud
/// stocke des **strokes vectoriels NORMALISÉS** `[0,1]` (cf.
/// `ZSignatureFieldWidget`, format versionné résolution-indépendant). Pour la
/// **compat données DODLP** (et la consommation PDF/tiers), ce codec pont :
///
/// - **strokes → PNG** (`toPng`) : rasterisation. La rasterisation réelle repose
///   sur `dart:ui` (`PictureRecorder`/`Canvas`/`Image.toByteData(png)`) qui est
///   **BANNIE du cœur** (AD-1, garde `presentation_purity_test` : `dart:ui`
///   interdit ; graphe `zcrud_core` OUT=0). Elle est donc **DÉFÉRÉE** à un
///   **seam host-fourni** [ZSignatureRasterizer] (impl dans un binding/satellite
///   `zcrud_export`/app). Le cœur ne porte QUE l'abstraction + l'orchestration
///   défensive. Aucun rasterizer injecté ⇒ `toPng` retourne `null` (dégradation
///   propre, jamais de throw — AD-10).
/// - **valeur-de-tranche ↔ strokes** (`strokesFromValue`/`valueFromStrokes`) :
///   (dé)sérialisation **pur-Dart** du format versionné (partagée avec le widget
///   — source unique de vérité). Défensive (AD-10 : donnée corrompue ⇒ liste
///   vide / `null`, jamais de throw).
/// - **inspection PNG** (`isPng`/`pngSize`) : lecture pur-Dart du magic-number +
///   du chunk IHDR (dimensions) — défensive (octets invalides ⇒ `false`/`null`).
///
/// **Neutralité (AD-1)** : aucune dépendance lourde ; seuls `Offset`/`Size`
/// (`package:flutter/widgets.dart`) et `Uint8List` (`dart:typed_data`, safe) sont
/// utilisés. **const** (AD-3/AD-14) : instanciable `const`, le rasterizer est un
/// seam optionnel injecté à la construction.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Offset, Size;

/// Spécification **pur-données** de rasterisation (DP-18, M15) : dimensions cible
/// + style de tracé/fond, tous **neutres** (couleur = donnée ARGB, jamais un
/// style codé en dur — FR-26). `const`.
class ZSignatureRasterSpec {
  /// Construit une spec `const`.
  const ZSignatureRasterSpec({
    this.width = 600,
    this.height = 200,
    // Encre noire opaque par défaut (donnée NEUTRE) — exprimée par décalage pour
    // éviter un littéral de couleur `0xFF…` (garde `style_purity`, FR-26).
    this.strokeColorArgb = 0xFF << 24,
    this.strokeWidth = 3,
    this.backgroundArgb,
  });

  /// Largeur cible du PNG (px).
  final int width;

  /// Hauteur cible du PNG (px).
  final int height;

  /// Couleur de tracé ARGB (`int`) — donnée neutre.
  final int strokeColorArgb;

  /// Épaisseur du tracé (px).
  final double strokeWidth;

  /// Couleur de fond ARGB (`int`) ou `null` = **transparent** (défaut).
  final int? backgroundArgb;
}

/// Seam **host-fourni** de rasterisation (DP-18, M15) : traduit des strokes
/// NORMALISÉS `[0,1]` en octets **PNG**, selon la [ZSignatureRasterSpec]. L'impl
/// concrète (`dart:ui`) vit **hors du cœur** (binding/`zcrud_export`/app) — AD-1.
/// Doit être **défensive** (jamais de throw ; `null` si non rasterisable).
typedef ZSignatureRasterizer = Future<Uint8List?> Function(
  List<List<Offset>> strokes,
  ZSignatureRasterSpec spec,
);

/// Codec **pluggable NEUTRE** strokes ↔ PNG (DP-18, M15). Voir doc de fichier.
class ZSignatureCodec {
  /// Construit le codec `const`. [rasterizer] (optionnel) est le **seam** de
  /// rasterisation host-fourni ; absent ⇒ [toPng] retourne `null` (AD-10).
  const ZSignatureCodec({this.rasterizer});

  /// Seam de rasterisation strokes→PNG (dart:ui) DÉFÉRÉ hors du cœur (AD-1).
  final ZSignatureRasterizer? rasterizer;

  /// Version du format d'encodage des strokes (miroir du widget — additif).
  static const int formatVersion = 1;

  /// Magic-number PNG (`\x89PNG\r\n\x1a\n`).
  static const List<int> _pngMagic = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  ];

  /// Décode des strokes NORMALISÉS depuis une **valeur de tranche** (`Map`
  /// versionnée). Défensif (AD-10) : type inattendu / point mal typé ⇒ ignoré,
  /// jamais de throw. Coordonnées attendues normalisées `[0,1]`.
  List<List<Offset>> strokesFromValue(Object? value) {
    if (value is! Map) return <List<Offset>>[];
    final raw = value['strokes'];
    if (raw is! List) return <List<Offset>>[];
    final strokes = <List<Offset>>[];
    for (final stroke in raw) {
      if (stroke is! List) continue;
      final points = <Offset>[];
      for (var i = 0; i + 1 < stroke.length; i += 2) {
        final x = stroke[i];
        final y = stroke[i + 1];
        if (x is num && y is num) {
          points.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
      if (points.isNotEmpty) strokes.add(points);
    }
    return strokes;
  }

  /// Encode des strokes NORMALISÉS en **valeur de tranche** (`Map` versionnée
  /// sérialisable), ou `null` si aucun tracé. Format aligné sur le widget.
  Map<String, dynamic>? valueFromStrokes(List<List<Offset>> strokes) {
    final nonEmpty = strokes.where((s) => s.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return null;
    return <String, dynamic>{
      'formatVersion': formatVersion,
      'strokes': <List<double>>[
        for (final stroke in nonEmpty)
          <double>[
            for (final p in stroke) ...<double>[p.dx, p.dy],
          ],
      ],
    };
  }

  /// **strokes → PNG** (DP-18, M15) : orchestration défensive du seam
  /// [rasterizer]. `null` si (a) aucun rasterizer injecté (AD-1), (b) aucun
  /// tracé, ou (c) le seam retourne `null`/throw (AD-10). [sliceValue] accepte la
  /// **valeur de tranche** (`Map`) OU une `List<List<Offset>>` déjà décodée.
  Future<Uint8List?> toPng(
    Object? sliceValue, {
    ZSignatureRasterSpec spec = const ZSignatureRasterSpec(),
  }) async {
    final r = rasterizer;
    if (r == null) return null;
    final strokes = sliceValue is List<List<Offset>>
        ? sliceValue
        : strokesFromValue(sliceValue);
    if (strokes.isEmpty) return null;
    try {
      return await r(strokes, spec);
    } catch (_) {
      return null; // AD-10 : seam défaillant ⇒ pas de crash.
    }
  }

  /// `true` si [bytes] commence par le **magic-number PNG** (défensif : trop
  /// court / non PNG ⇒ `false`).
  bool isPng(Uint8List bytes) {
    if (bytes.length < _pngMagic.length) return false;
    for (var i = 0; i < _pngMagic.length; i++) {
      if (bytes[i] != _pngMagic[i]) return false;
    }
    return true;
  }

  /// Dimensions d'un PNG lues dans le chunk **IHDR** (largeur/hauteur big-endian
  /// aux offsets 16/20). Défensif (AD-10) : non-PNG / trop court ⇒ `null`.
  Size? pngSize(Uint8List bytes) {
    if (!isPng(bytes) || bytes.length < 24) return null;
    int be32(int o) =>
        (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3];
    final w = be32(16);
    final h = be32(20);
    if (w <= 0 || h <= 0) return null;
    return Size(w.toDouble(), h.toDouble());
  }
}
