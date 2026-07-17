/// Impl CONCRÈTE du port pur `ZLatexRasterizer` (su-11, AC4/AC9, AD-42).
///
/// origine: su-11 (E-STUDY-UI). C'est le maillon PLATEFORME que `zcrud_export`
/// (pur) ne peut pas porter : rasteriser une formule LaTeX exige un **rendu
/// Flutter hors écran** (`flutter_math_fork` → `dart:ui` `toImage`), incompatible
/// avec la pureté d'`zcrud_export` (AD-42). Le port `ZLatexRasterizer`
/// (abstraction) vit dans `zcrud_export` ; cette impl vit ici.
///
/// 🔴 **SEUL fichier de `lib/` autorisé à importer `flutter_math_fork`** (2ᵉ site
/// du repo après `zcrud_markdown/z_latex_embed.dart`). Aucun type
/// `Math`/`MathStyle`/… n'apparaît en signature publique ni n'est réexporté par
/// le barrel : la sortie est en **bytes PNG neutres** (`Uint8List?`). Gardé par
/// `test/z_export_ui_confinement_test.dart`.
///
/// **Polices KaTeX** : `flutter_math_fork` embarque ses fontes (déclarées dans
/// SON pubspec) ; elles sont bundlées automatiquement par l'app hôte qui dépend
/// (transitivement) de ce package — aucun asset à re-déclarer ici.
///
/// **Défensif (AD-10, AC9)** : LaTeX vide/invalide, ou toute erreur de rendu →
/// `null` (JAMAIS de throw) ⇒ le gabarit `ZFlashcardPdfTemplate` retombe sur le
/// **texte brut** de la formule.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:zcrud_export/zcrud_export.dart';

/// Rasteriseur LaTeX concret : rend une formule hors écran en PNG.
class ZFlutterMathLatexRasterizer implements ZLatexRasterizer {
  /// Construit le rasteriseur.
  ///
  /// [pixelRatio] : densité de capture (défaut 3.0 → formule nette à l'échelle
  /// du PDF). [textColor] : couleur du glyphe (défaut noir, lisible à
  /// l'impression). [fontSize] : taille logique de rendu de la formule.
  const ZFlutterMathLatexRasterizer({
    this.pixelRatio = 3.0,
    this.textColor = const Color(0xFF000000),
    this.fontSize = 20.0,
  });

  /// Densité de capture (physique / logique).
  final double pixelRatio;

  /// Couleur du glyphe rendu.
  final Color textColor;

  /// Taille logique de la formule.
  final double fontSize;

  @override
  Future<Uint8List?> rasterize(String latex, {double? logicalWidth}) async {
    if (latex.trim().isEmpty) return null;
    try {
      var hadError = false;
      final Widget formula = Math.tex(
        latex,
        mathStyle: MathStyle.text,
        textStyle: TextStyle(color: textColor, fontSize: fontSize),
        // AD-10 : LaTeX invalide ⇒ on note l'erreur et on rend un widget vide ;
        // rasterize renverra `null` (repli texte brut côté gabarit).
        onErrorFallback: (Object error) {
          hadError = true;
          return const SizedBox.shrink();
        },
      );
      final bytes = await _renderToPng(
        formula,
        maxWidth: logicalWidth ?? 2000.0,
      );
      if (hadError) return null;
      return bytes;
    } catch (_) {
      return null; // AD-10 : jamais de throw vers l'appelant.
    }
  }

  /// Rend [child] dans un arbre de rendu HORS ÉCRAN et renvoie son PNG.
  ///
  /// Recette standard « widget → image » (BuildOwner + PipelineOwner + RenderView
  /// + RenderRepaintBoundary.toImage), fonctionnant en runtime app ET sous
  /// `flutter test` (golden). Aucun pixel n'est affiché à l'écran.
  Future<Uint8List?> _renderToPng(
    Widget child, {
    required double maxWidth,
  }) async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    final ui.FlutterView view = binding.platformDispatcher.implicitView ??
        binding.platformDispatcher.views.first;

    final RenderRepaintBoundary boundary = RenderRepaintBoundary();
    final RenderPositionedBox root = RenderPositionedBox(
      alignment: Alignment.topLeft,
      child: boundary,
    );
    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());
    final RenderView renderView = RenderView(
      view: view,
      child: root,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 4000),
        physicalConstraints: BoxConstraints(
          maxWidth: maxWidth * pixelRatio,
          maxHeight: 4000 * pixelRatio,
        ),
        devicePixelRatio: pixelRatio,
      ),
    );

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> element =
        RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: child,
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner
      ..buildScope(element)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    try {
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } finally {
      // Démonte l'arbre hors écran (anti-fuite de cycle de vie).
      buildOwner.finalizeTree();
    }
  }
}
