/// Chaîne de résolution du **chrome** de la carte de révision : fond, ombre
/// portée et rayon des coins.
///
/// Ce que ces gardes mesurent : la **couleur réellement peinte**
/// (`Material.color`), l'**ombre réellement montée** (la `BoxDecoration` du
/// render object) et le **rayon réellement monté** — jamais le seul passage
/// d'un paramètre au constructeur.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

const ZFlashcard _card = ZFlashcard(
  question: 'Q',
  answer: 'A',
  type: ZFlashcardType.openQuestion,
);

Widget _host({
  ZcrudTheme theme = const ZcrudTheme(),
  Color? backgroundColor,
  Color? shadowColor,
  Radius? radius,
  Brightness brightness = Brightness.light,
  Color? materialShadowColor,
  Color? cardThemeShadowColor,
}) {
  ThemeData data = ThemeData(brightness: brightness);
  if (materialShadowColor != null) {
    data = data.copyWith(shadowColor: materialShadowColor);
  }
  if (cardThemeShadowColor != null) {
    data = data.copyWith(
      cardTheme: data.cardTheme.copyWith(shadowColor: cardThemeShadowColor),
    );
  }
  return MaterialApp(
    theme: data,
    home: ZcrudScope(
      theme: theme,
      child: Scaffold(
        body: SizedBox(
          width: 300,
          child: ZFlashcardReviewCard(
            card: _card,
            backgroundColor: backgroundColor,
            shadowColor: shadowColor,
            radius: radius,
          ),
        ),
      ),
    ),
  );
}

/// La couleur réellement peinte par le `Material` de la carte.
int _paintedSurface(WidgetTester tester) => tester
    .widgetList<Material>(
      find.descendant(
        of: find.byType(ZFlashcardReviewCard),
        matching: find.byType(Material),
      ),
    )
    .first
    .color!
    .toARGB32();

/// Le rayon réellement monté par le `Material` de la carte (`borderRadius`,
/// pas l'argument du constructeur de la carte).
BorderRadiusGeometry? _paintedCorner(WidgetTester tester) => tester
    .widgetList<Material>(
      find.descendant(
        of: find.byType(ZFlashcardReviewCard),
        matching: find.byType(Material),
      ),
    )
    .first
    .borderRadius;

/// Le rayon réellement monté par l'`InkWell` de la carte — le SECOND site de
/// coin. Un coin qui divergerait de l'autre se verrait à l'écran.
BorderRadius? _inkCorner(WidgetTester tester) => tester
    .widgetList<InkWell>(
      find.descendant(
        of: find.byType(ZFlashcardReviewCard),
        matching: find.byType(InkWell),
      ),
    )
    .first
    .borderRadius;

/// Rayon attendu, sous la forme réellement montée.
BorderRadius _all(double r) => BorderRadius.all(Radius.circular(r));

/// L'ombre réellement MONTÉE sous la clé d'ombre (render object).
BoxDecoration? _mountedShadow(WidgetTester tester) {
  final Finder finder = find.byKey(ZFlashcardReviewCard.shadowKey);
  if (finder.evaluate().isEmpty) return null;
  final RenderDecoratedBox box = tester.renderObject<RenderDecoratedBox>(
    find.descendant(
      of: finder,
      matching: find.byType(DecoratedBox),
      matchRoot: true,
    ),
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('fond — paramètre > jeton dédié > jeton de surface > rôle', () {
    testWidgets('le jeton `flashcardCardBackgroundColor` PEINT la carte', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          theme: const ZcrudTheme(
            flashcardCardBackgroundColor: Color(0xFF0A0B0C),
          ),
        ),
      );

      expect(
        _paintedSurface(tester),
        0xFF0A0B0C,
        reason:
            'LE défaut visé : un hôte qui pose ce jeton croit teinter ses '
            'cartes de session, et ne teignait rien',
      );
    });

    testWidgets('le jeton dédié PRIME le jeton générique `surfaceColor`', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          theme: const ZcrudTheme(
            surfaceColor: Color(0xFF111111),
            flashcardCardBackgroundColor: Color(0xFF222222),
          ),
        ),
      );

      expect(_paintedSurface(tester), 0xFF222222);
    });

    testWidgets('le paramètre PRIME le jeton dédié', (tester) async {
      await tester.pumpWidget(
        _host(
          backgroundColor: const Color(0xFF333333),
          theme: const ZcrudTheme(
            flashcardCardBackgroundColor: Color(0xFF222222),
          ),
        ),
      );

      expect(_paintedSurface(tester), 0xFF333333);
    });

    testWidgets('sans jeton dédié, `surfaceColor` gouverne encore', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(theme: const ZcrudTheme(surfaceColor: Color(0xFF444444))),
      );

      expect(_paintedSurface(tester), 0xFF444444);
    });
  });

  group('rayon — paramètre > jeton > `radiusM`', () {
    testWidgets('le jeton `flashcardCardRadius` ARRONDIT les DEUX coins', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          theme: const ZcrudTheme(
            radiusM: Radius.circular(12),
            flashcardCardRadius: Radius.circular(20),
          ),
        ),
      );

      expect(_paintedCorner(tester), _all(20));
      expect(
        _inkCorner(tester),
        _all(20),
        reason:
            'les deux sites de coin de la carte suivent la MÊME résolution — '
            'un coin resté sur `radiusM` se verrait à l\'écran',
      );
    });

    testWidgets('le paramètre `radius` PRIME le jeton', (tester) async {
      await tester.pumpWidget(
        _host(
          radius: const Radius.circular(28),
          theme: const ZcrudTheme(
            radiusM: Radius.circular(12),
            flashcardCardRadius: Radius.circular(20),
          ),
        ),
      );

      expect(_paintedCorner(tester), _all(28));
      expect(_inkCorner(tester), _all(28));
    });

    testWidgets('sans paramètre ni jeton, `radiusM` gouverne encore', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(theme: const ZcrudTheme(radiusM: Radius.circular(9))),
      );

      expect(_paintedCorner(tester), _all(9));
      expect(_inkCorner(tester), _all(9));
    });

    testWidgets(
      'le rayon de carte NE DÉPLACE PAS le pourtour des boutons d\'action — '
      'un bouton n\'est pas un coin de carte',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ZcrudScope(
              theme: const ZcrudTheme(
                radiusM: Radius.circular(12),
                flashcardCardRadius: Radius.circular(20),
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 300,
                  child: ZFlashcardReviewCard(
                    card: _card,
                    onEdit: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        final InkWell action = tester.widget<InkWell>(
          find.descendant(
            of: find.byKey(ZFlashcardReviewCard.editActionKey),
            matching: find.byType(InkWell),
          ),
        );
        expect(
          action.borderRadius,
          _all(12),
          reason:
              'le pourtour de l\'onde d\'un bouton d\'action suit le rayon '
              'des contrôles, pas celui de la carte qui les porte',
        );
      },
    );
  });

  group('ombre — jetons `cardShadow*` > teinte de référence > aucune ombre', () {
    testWidgets('le jeton `flashcardCardShadowColor` PORTE une ombre', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          theme: const ZcrudTheme(
            flashcardCardShadowColor: Color(0xFF00FF00),
          ),
        ),
      );

      final BoxDecoration? deco = _mountedShadow(tester);
      expect(deco, isNotNull, reason: 'aucune ombre montée');
      final BoxShadow shadow = deco!.boxShadow!.single;
      expect(shadow.color.toARGB32() & 0x00FFFFFF, 0x0000FF00);
      // Opacité de référence en thème CLAIR.
      expect((shadow.color.a * 255).round(), closeTo(0.06 * 255, 1));
      expect(shadow.blurRadius, 8);
      expect(shadow.offset, const Offset(0, 2));
    });

    testWidgets('l\'opacité de référence SUIT la luminosité', (tester) async {
      await tester.pumpWidget(
        _host(
          brightness: Brightness.dark,
          theme: const ZcrudTheme(
            flashcardCardShadowColor: Color(0xFF00FF00),
          ),
        ),
      );

      final BoxShadow shadow = _mountedShadow(tester)!.boxShadow!.single;
      expect((shadow.color.a * 255).round(), closeTo(0.2 * 255, 1));
    });

    testWidgets('le paramètre `shadowColor` PRIME le jeton', (tester) async {
      await tester.pumpWidget(
        _host(
          shadowColor: const Color(0xFFFF0000),
          theme: const ZcrudTheme(
            flashcardCardShadowColor: Color(0xFF00FF00),
          ),
        ),
      );

      final BoxShadow shadow = _mountedShadow(tester)!.boxShadow!.single;
      expect(shadow.color.toARGB32() & 0x00FFFFFF, 0x00FF0000);
    });

    testWidgets(
      'les jetons `cardShadow*` PRIMENT l\'ombre de référence — et leur '
      'couleur vient du rôle, comme sur la carte de liste',
      (tester) async {
        await tester.pumpWidget(
          _host(
            materialShadowColor: const Color(0xFF0000FF),
            theme: const ZcrudTheme(
              flashcardCardShadowColor: Color(0xFF00FF00),
              cardShadowBlurRadius: 20,
              cardShadowOffset: Offset(0, 8),
              cardShadowAlpha: 0.5,
            ),
          ),
        );

        final BoxShadow shadow = _mountedShadow(tester)!.boxShadow!.single;
        expect(shadow.blurRadius, 20);
        expect(shadow.offset, const Offset(0, 8));
        expect((shadow.color.a * 255).round(), closeTo(0.5 * 255, 1));
        expect(shadow.color.toARGB32() & 0x00FFFFFF, 0x000000FF);
      },
    );

    testWidgets(
      'un SEUL jeton `cardShadow*` suffit à activer le canal — les deux '
      'autres retombent sur les scalaires de référence',
      (tester) async {
        await tester.pumpWidget(
          _host(theme: const ZcrudTheme(cardShadowAlpha: 0.5)),
        );

        final BoxShadow shadow = _mountedShadow(tester)!.boxShadow!.single;
        expect(shadow.blurRadius, 8);
        expect(shadow.offset, const Offset(0, 2));
        expect((shadow.color.a * 255).round(), closeTo(0.5 * 255, 1));
      },
    );

    testWidgets('l\'ombre ÉPOUSE le rayon résolu de la carte', (tester) async {
      await tester.pumpWidget(
        _host(
          theme: const ZcrudTheme(
            radiusM: Radius.circular(12),
            flashcardCardRadius: Radius.circular(20),
            flashcardCardShadowColor: Color(0xFF00FF00),
          ),
        ),
      );

      expect(
        _mountedShadow(tester)!.borderRadius,
        _all(20),
        reason: 'une ombre au rayon des champs déborderait des coins',
      );
    });

    testWidgets(
      '🧊 rien de posé, AUCUNE ombre — ni boîte décorée, ni élévation',
      (tester) async {
        await tester.pumpWidget(_host());

        expect(find.byKey(ZFlashcardReviewCard.shadowKey), findsNothing);
        final Material material = tester
            .widgetList<Material>(
              find.descendant(
                of: find.byType(ZFlashcardReviewCard),
                matching: find.byType(Material),
              ),
            )
            .first;
        expect(material.elevation, 0);
      },
    );
  });
}
