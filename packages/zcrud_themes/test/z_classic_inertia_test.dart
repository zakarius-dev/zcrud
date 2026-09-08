library;

// INERTIE ABSOLUE. Brancher les résolveurs de ce paquet ne doit RIEN changer
// tant qu'aucune clé du thème n'est demandée : un écran du socle rend le même
// arbre et les mêmes couleurs peintes, avec ou sans eux.
//
// La garde mesure les COULEURS RÉELLEMENT PEINTES (décorations, `Material`,
// `ColoredBox`, glyphes, styles de texte), pas le passage d'un jeton : un
// jeton peut transiter sans jamais atteindre un pixel, et une garde qui le
// suivrait resterait verte sur une régression de rendu.
//
// L'égalité est STRICTE — jamais `contains`, jamais `<=` : une inertie
// « au moins autant de couleurs qu'avant » n'est pas une inertie.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_themes/zcrud_themes.dart';

/// Toutes les couleurs peintes sous [root], dans l'ordre de l'arbre.
List<String> _paintedColors(Element root) {
  final List<String> out = <String>[];
  void visit(Element element) {
    final Widget w = element.widget;
    if (w is DecoratedBox) {
      final Decoration d = w.decoration;
      if (d is BoxDecoration) {
        if (d.color != null) out.add('box:${d.color}');
        final Gradient? g = d.gradient;
        if (g != null) out.add('grad:${g.colors}');
        final BoxBorder? b = d.border;
        if (b != null) out.add('border:$b');
      }
    } else if (w is ColoredBox) {
      out.add('colored:${w.color}');
    } else if (w is Material) {
      out.add('material:${w.color}/${w.shadowColor}/${w.surfaceTintColor}');
    } else if (w is Icon) {
      out.add('icon:${w.icon?.codePoint}/${w.color}');
    } else if (w is IconTheme) {
      out.add('iconTheme:${w.data.color}');
    } else if (w is RichText) {
      out.add('text:${w.text.style?.color}');
    } else if (w is DefaultTextStyle) {
      out.add('defaultText:${w.style.color}');
    }
    element.visitChildren(visit);
  }

  visit(root);
  return out;
}

/// Les types de widgets sous [root], dans l'ordre de l'arbre.
List<String> _treeShape(Element root) {
  final List<String> out = <String>[];
  void visit(Element element) {
    out.add(element.widget.runtimeType.toString());
    element.visitChildren(visit);
  }

  visit(root);
  return out;
}

Widget _screen({ZColorKeyResolver? colorKeys, ZGradientResolver? gradients}) {
  final Widget subject = ZSrsQualityButtons(
    scale: ZQualityScale.fromConfig(const ZSrsConfig()),
    onQualitySelected: _noop,
    passThreshold: 3,
    selectedQuality: 4,
  );
  return MaterialApp(
    home: Scaffold(
      body: colorKeys == null && gradients == null
          ? subject
          : ZcrudScope(
              colorKeyResolver: colorKeys,
              gradientResolver: gradients,
              child: subject,
            ),
    ),
  );
}

void _noop(int quality) {}

void main() {
  testWidgets(
      'brancher les résolveurs Classic ne change NI l\'arbre NI les couleurs',
      (WidgetTester tester) async {
    // Référence : l'écran du socle, sans aucun `ZcrudScope`.
    await tester.pumpWidget(_screen());
    final Element bareRoot =
        tester.element(find.byType(ZSrsQualityButtons));
    final List<String> bareShape = _treeShape(bareRoot);
    final List<String> bareColors = _paintedColors(bareRoot);

    // La garde ne mesure rien si le sujet n'est pas monté : on l'exige.
    expect(bareShape.length, greaterThan(10),
        reason: 'sujet non monté : la garde serait verte pour rien.');
    expect(bareColors, isNotEmpty,
        reason: 'aucune couleur peinte : la garde serait verte pour rien.');

    // Le même écran, avec les deux résolveurs du thème branchés. Les crans
    // demandent les clés `primary`/`error` du socle, qu'aucun résolveur
    // Classic ne connaît : le rendu doit être identique, à l'octet.
    await tester.pumpWidget(_screen(
      colorKeys: ZClassicTheme.colorKeys,
      gradients: ZClassicTheme.gradients,
    ));
    final Element wiredRoot =
        tester.element(find.byType(ZSrsQualityButtons));

    expect(_treeShape(wiredRoot), bareShape);
    expect(_paintedColors(wiredRoot), bareColors);
  });

  testWidgets('les résolveurs se taisent sur toute clé étrangère au thème',
      (WidgetTester tester) async {
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    for (final String key in <String>[
      'primary',
      'error',
      'neutral',
      '',
      'zcrud.signature.Analyse',
      'zcrud.fieldType.text',
      'success',
    ]) {
      expect(ZClassicTheme.colorKeys(scheme, key), isNull, reason: key);
      expect(ZClassicTheme.gradients(scheme, key), isNull, reason: key);
    }
  });

  testWidgets('les résolveurs répondent, eux, aux clés du thème',
      (WidgetTester tester) async {
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final ZColorPair? pair =
        ZClassicTheme.colorKeys(scheme, ZClassicTheme.qualityColorKeyFor(1));
    expect(pair, isNotNull);
    expect(pair!.color, ZClassicSrsPaletteReference.fail.color);

    expect(
      ZClassicTheme.gradients(scheme, 'flashcard.type.multipleChoice'),
      ZClassicCardGradientsReference.multipleChoice,
    );
    expect(
      ZClassicTheme.gradients(
          scheme, ZClassicCelebrationReference.badgeGradientKey),
      ZClassicCelebrationReference.badgeGradient,
    );
  });
}
