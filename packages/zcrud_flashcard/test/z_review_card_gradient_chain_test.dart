/// Chaîne de résolution du liseré de la carte de révision, et échappatoires
/// par instance (hauteur, clé de dégradé, fond).
///
/// Ce que ces gardes mesurent : la **couleur réellement peinte** et la
/// décoration réellement **montée**, jamais le seul passage d'un paramètre.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Signature d'arbre : suite ORDONNÉE de `(type, clé)`, hachages d'instance
/// neutralisés. Patron partagé avec les gardes d'inertie de `zcrud_session`.
List<String> _treeSignature(WidgetTester tester) => tester.allWidgets
    .map(
      (w) =>
          '${w.runtimeType}|${w.key}'.replaceAll(RegExp(r'#[0-9a-f]{5}'), '#…'),
    )
    .toList();

const ZGradientSpec _tokenSpec = ZGradientSpec(
  gradient: LinearGradient(colors: <Color>[Color(0xFF112233), Color(0xFF445566)]),
  onGradient: Color(0xFFFFFFFF),
);
const ZGradientSpec _prefixedSpec = ZGradientSpec(
  gradient: LinearGradient(colors: <Color>[Color(0xFF778899), Color(0xFFAABBCC)]),
  onGradient: Color(0xFF000000),
);
const ZGradientSpec _bareSpec = ZGradientSpec(
  gradient: LinearGradient(colors: <Color>[Color(0xFFDDEEFF), Color(0xFF102030)]),
  onGradient: Color(0xFF000000),
);
const ZGradientSpec _customSpec = ZGradientSpec(
  gradient: LinearGradient(colors: <Color>[Color(0xFF010203), Color(0xFF040506)]),
  onGradient: Color(0xFFFFFFFF),
);

const ZFlashcard _card = ZFlashcard(
  question: 'Q',
  answer: 'A',
  type: ZFlashcardType.openQuestion,
);

/// Le préfixe que le socle de liste FORME vraiment — recopié ici, et gardé
/// par `z_review_card_gradient_prefix_parity_test.dart`.
const String _prefix = kZFlashcardReviewTypeGradientKeyPrefix;

/// Résolveur répondant à une table de clés EXACTES, et consignant tout ce
/// qu'on lui soumet (l'ordre des soumissions est une mesure de la chaîne).
ZGradientResolver _resolver(
  Map<String, ZGradientSpec> table, {
  List<String>? received,
}) => (ColorScheme _, String key) {
  received?.add(key);
  return table[key];
};

/// Hôte VOLONTAIREMENT sans jetons `gradientBegin`/`gradientEnd` : c'est la
/// situation d'une application qui branche un résolveur sans rien d'autre.
Widget _host({
  ZGradientResolver? resolver,
  Map<String, ZGradientSpec>? typeGradients,
  double? accentBarHeight,
  double? accentHeight,
  String? typeGradientKey,
  Color? backgroundColor,
  Color? surfaceColor,
  AlignmentGeometry? gradientBegin,
  AlignmentGeometry? gradientEnd,
}) => MaterialApp(
  home: ZcrudScope(
    theme: ZcrudTheme(
      accentBarHeight: accentBarHeight,
      flashcardTypeGradients: typeGradients,
      surfaceColor: surfaceColor,
      gradientBegin: gradientBegin,
      gradientEnd: gradientEnd,
    ),
    gradientResolver: resolver,
    child: Scaffold(
      body: SizedBox(
        width: 300,
        child: ZFlashcardReviewCard(
          card: _card,
          accentHeight: accentHeight,
          typeGradientKey: typeGradientKey,
          backgroundColor: backgroundColor,
        ),
      ),
    ),
  ),
);

/// La décoration réellement MONTÉE sous la clé du liseré (render object, pas
/// l'argument du constructeur).
BoxDecoration _mountedAccentDecoration(WidgetTester tester) {
  final RenderDecoratedBox box = tester.renderObject<RenderDecoratedBox>(
    find.descendant(
      of: find.byKey(ZFlashcardReviewCard.gradientAccentKey),
      matching: find.byType(DecoratedBox),
      matchRoot: true,
    ),
  );
  return box.decoration as BoxDecoration;
}

/// Les arrêts du dégradé réellement monté.
List<int> _mountedAccentColors(WidgetTester tester) =>
    ((_mountedAccentDecoration(tester).gradient! as LinearGradient).colors)
        .map((Color c) => c.toARGB32())
        .toList();

/// Le liseré émet-il un appel de peinture à SHADER (un dégradé, pas une
/// couleur plate) ?
PaintPattern get _paintsAShader => paints
  ..something((Symbol method, List<dynamic> arguments) {
    if (method != #drawRect && method != #drawRRect && method != #drawPath) {
      return false;
    }
    return arguments.whereType<Paint>().any((Paint p) => p.shader != null);
  });

/// La couleur de la surface RÉELLEMENT montée par la carte.
int _mountedSurface(WidgetTester tester) => tester
    .widgetList<Material>(
      find.descendant(
        of: find.byType(ZFlashcardReviewCard),
        matching: find.byType(Material),
      ),
    )
    .first
    .color!
    .toARGB32();

void main() {
  group('chaîne de résolution du liseré — les trois maillons', () {
    testWidgets(
      'un résolveur qui ne répond QU\'AU FORMAT PRÉFIXÉ peint le liseré',
      (tester) async {
        final received = <String>[];
        await tester.pumpWidget(
          _host(
            resolver: _resolver(<String, ZGradientSpec>{
              '${_prefix}openQuestion': _prefixedSpec,
            }, received: received),
            accentHeight: 4,
          ),
        );

        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          findsOneWidget,
          reason: 'la clé documentée doit atteindre le seam',
        );
        expect(received, contains('${_prefix}openQuestion'));
        expect(_mountedAccentColors(tester), <int>[0xFF778899, 0xFFAABBCC]);
        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          _paintsAShader,
        );
        expect(
          tester
              .getSize(find.byKey(ZFlashcardReviewCard.gradientAccentKey))
              .height,
          4,
        );
      },
    );

    testWidgets(
      'ÉCHAPPATOIRE — un résolveur qui ne répond QU\'AU FORMAT NU peint '
      'encore le liseré',
      (tester) async {
        await tester.pumpWidget(
          _host(
            resolver: _resolver(<String, ZGradientSpec>{
              'openQuestion': _bareSpec,
            }),
            accentHeight: 4,
          ),
        );

        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          findsOneWidget,
        );
        expect(_mountedAccentColors(tester), <int>[0xFFDDEEFF, 0xFF102030]);
        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          _paintsAShader,
        );
      },
    );

    testWidgets(
      'le jeton `flashcardTypeGradients` SEUL — aucun résolveur — peint le '
      'liseré',
      (tester) async {
        await tester.pumpWidget(
          _host(
            typeGradients: const <String, ZGradientSpec>{
              'openQuestion': _tokenSpec,
            },
            accentHeight: 4,
          ),
        );

        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          findsOneWidget,
          reason: 'un thème posant la table doit teindre la carte de session',
        );
        expect(_mountedAccentColors(tester), <int>[0xFF112233, 0xFF445566]);
        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          _paintsAShader,
        );
      },
    );

    testWidgets('🔴 PRÉSÉANCE — le seam PRÉFIXÉ l\'emporte sur le jeton', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          typeGradients: const <String, ZGradientSpec>{
            'openQuestion': _tokenSpec,
          },
          resolver: _resolver(<String, ZGradientSpec>{
            '${_prefix}openQuestion': _prefixedSpec,
            'openQuestion': _bareSpec,
          }),
          accentHeight: 4,
        ),
      );

      expect(
        _mountedAccentColors(tester),
        <int>[0xFF778899, 0xFFAABBCC],
        reason:
            'seam > jeton, comme partout ailleurs dans le socle : un hôte qui '
            'branche un résolveur ne doit jamais le voir ignoré par un jeton '
            'que son thème pose à sa place',
      );
      expect(
        find.byKey(ZFlashcardReviewCard.gradientAccentKey),
        _paintsAShader,
      );
    });

    testWidgets(
      '🔴 PRÉSÉANCE — le seam NU aussi l\'emporte sur le jeton : le seam '
      'n\'est jamais coupé en deux par le jeton',
      (tester) async {
        await tester.pumpWidget(
          _host(
            typeGradients: const <String, ZGradientSpec>{
              'openQuestion': _tokenSpec,
            },
            resolver: _resolver(<String, ZGradientSpec>{
              'openQuestion': _bareSpec,
            }),
            accentHeight: 4,
          ),
        );

        expect(
          _mountedAccentColors(tester),
          <int>[0xFFDDEEFF, 0xFF102030],
          reason:
              'LE cas du défaut : un thème du socle pose la table par type, '
              'l\'hôte pose un résolveur au format historique — le résolveur '
              'gagne, sinon la règle « seam > jeton » dépendrait du FORMAT de '
              'clé auquel l\'hôte répond',
        );
        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          _paintsAShader,
        );
      },
    );

    testWidgets(
      '🔴 ORDRE des soumissions : les DEUX clés du seam sont soumises AVANT '
      'toute lecture du jeton',
      (tester) async {
        final received = <String>[];
        await tester.pumpWidget(
          _host(
            typeGradients: const <String, ZGradientSpec>{
              'openQuestion': _tokenSpec,
            },
            // Résolveur MUET : il consigne ce qu'on lui soumet, ne répond
            // rien. Avec le jeton consulté en premier, il ne recevrait RIEN —
            // c'est ce qui rend cette garde discriminante.
            resolver: _resolver(
              const <String, ZGradientSpec>{},
              received: received,
            ),
            accentHeight: 4,
          ),
        );

        expect(
          received,
          <String>['${_prefix}openQuestion', 'openQuestion'],
          reason:
              'l\'ordre des soumissions EST la mesure de la chaîne : le jeton '
              'ne doit court-circuiter aucune des deux clés',
        );
        expect(
          _mountedAccentColors(tester),
          <int>[0xFF112233, 0xFF445566],
          reason: 'le jeton reste le repli quand le seam se tait',
        );
      },
    );

    testWidgets(
      'PRÉSÉANCE — sans jeton, la clé PRÉFIXÉE l\'emporte sur la clé nue',
      (tester) async {
        await tester.pumpWidget(
          _host(
            resolver: _resolver(<String, ZGradientSpec>{
              '${_prefix}openQuestion': _prefixedSpec,
              'openQuestion': _bareSpec,
            }),
            accentHeight: 4,
          ),
        );

        expect(_mountedAccentColors(tester), <int>[0xFF778899, 0xFFAABBCC]);
      },
    );

    testWidgets(
      '`typeGradientKey` COURT-CIRCUITE le jeton ET les deux clés dérivées',
      (tester) async {
        final received = <String>[];
        await tester.pumpWidget(
          _host(
            typeGradients: const <String, ZGradientSpec>{
              'openQuestion': _tokenSpec,
            },
            resolver: _resolver(<String, ZGradientSpec>{
              '${_prefix}openQuestion': _prefixedSpec,
              'openQuestion': _bareSpec,
              'maison.libre': _customSpec,
            }, received: received),
            accentHeight: 4,
            typeGradientKey: 'maison.libre',
          ),
        );

        expect(_mountedAccentColors(tester), <int>[0xFF010203, 0xFF040506]);
        expect(
          received,
          <String>['maison.libre'],
          reason: 'aucune autre clé ne doit être soumise au seam',
        );
      },
    );
  });

  group('hauteur du liseré — paramètre > jeton', () {
    testWidgets('`accentHeight: 6` l\'emporte sur le jeton `4`', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          typeGradients: const <String, ZGradientSpec>{
            'openQuestion': _tokenSpec,
          },
          accentBarHeight: 4,
          accentHeight: 6,
        ),
      );

      expect(
        tester
            .getSize(find.byKey(ZFlashcardReviewCard.gradientAccentKey))
            .height,
        6,
      );
    });

    testWidgets('sans paramètre, le jeton `4` gouverne encore', (tester) async {
      await tester.pumpWidget(
        _host(
          typeGradients: const <String, ZGradientSpec>{
            'openQuestion': _tokenSpec,
          },
          accentBarHeight: 4,
        ),
      );

      expect(
        tester
            .getSize(find.byKey(ZFlashcardReviewCard.gradientAccentKey))
            .height,
        4,
      );
    });
  });

  group('fond de carte — paramètre > jeton > rôle Material', () {
    testWidgets('`backgroundColor` posé EST la couleur du Material', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(backgroundColor: const Color(0xFF203040)),
      );
      expect(_mountedSurface(tester), 0xFF203040);
    });

    testWidgets(
      'sans paramètre, le jeton `surfaceColor` gouverne, bit à bit',
      (tester) async {
        await tester.pumpWidget(_host(surfaceColor: const Color(0xFF506070)));
        expect(_mountedSurface(tester), 0xFF506070);
      },
    );

    testWidgets(
      'sans paramètre ni jeton, le rôle `colorScheme.surface` gouverne, '
      'bit à bit',
      (tester) async {
        await tester.pumpWidget(_host());
        final BuildContext context = tester.element(
          find.byType(ZFlashcardReviewCard),
        );
        expect(
          _mountedSurface(tester),
          Theme.of(context).colorScheme.surface.toARGB32(),
        );
      },
    );
  });

  group('🧊 inertie — rien de posé, rien de peint', () {
    testWidgets(
      'sans `accentHeight` ni jeton `accentBarHeight`, AUCUN liseré — même '
      'avec un dégradé résolu',
      (tester) async {
        await tester.pumpWidget(
          _host(
            resolver: _resolver(<String, ZGradientSpec>{
              '${_prefix}openQuestion': _prefixedSpec,
              'openQuestion': _bareSpec,
            }),
            typeGradients: const <String, ZGradientSpec>{
              'openQuestion': _tokenSpec,
            },
          ),
        );

        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          findsNothing,
          reason: 'la hauteur nulle reste le seul interrupteur du liseré',
        );
      },
    );

    testWidgets(
      'l\'arbre nu est IDENTIQUE au dump figé d\'avant le lot, et la surface '
      'peinte aussi',
      (tester) async {
        await tester.pumpWidget(_host());

        final List<String> expected =
            File('test/support/z_review_card_tree_before_lotd1.txt')
                .readAsLinesSync()
                .where((String l) => l.isNotEmpty)
                .toList();
        expect(expected, isNotEmpty, reason: 'dump figé absent');
        expect(
          _treeSignature(tester),
          expected,
          reason:
              'égalité STRICTE de la suite (widget, clé) — jamais un '
              '`contains`, jamais un `length >=`',
        );

        final BuildContext context = tester.element(
          find.byType(ZFlashcardReviewCard),
        );
        expect(
          _mountedSurface(tester),
          Theme.of(context).colorScheme.surface.toARGB32(),
        );
      },
    );
  });
}
