/// Gardes des trois jetons CHROMATIQUES des surfaces de session d'étude :
/// fond de la carte de flashcard, ombre de cette carte, séparateur de l'écran
/// de session.
///
/// ## Ce que ces gardes mesurent — et le piège qu'elles ferment
///
/// Elles lisent la **couleur RÉELLEMENT PEINTE** dans l'arbre rendu :
///
/// * le fond de carte, sur le `Material` que `Card` construit (pas la propriété
///   `color` déclarée du `Card`, qui ne dit rien de ce qui est peint) ;
/// * l'ombre, sur la `BoxDecoration` du `DecoratedBox` qui enveloppe la carte ;
/// * le séparateur, sur la `BoxDecoration` que `Divider` construit.
///
/// Une garde qui se contenterait de vérifier qu'un jeton est **passé** à un
/// constructeur resterait verte pendant que la surface est peinte avec une
/// autre couleur : c'est la classe de défaut visée ici.
///
/// ## Inertie ABSOLUE
///
/// Chaque famille porte son pendant « sans jeton » : sans aucun de ces trois
/// jetons, la couleur peinte est **strictement** celle d'aujourd'hui (le rôle
/// `scaffoldBackgroundColor`, `shadowColor`, `outlineVariant`) — égalité
/// stricte, jamais un `contains` ni un `isNot`.
///
/// ## Chaîne de résolution
///
/// `paramètre > jeton > rôle` : chaque famille prouve aussi que le paramètre
/// PRIME le jeton. Les tests de jeton ne passent **jamais** le paramètre — le
/// passer, fût-ce à sa valeur neutre, court-circuiterait le maillon mesuré.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart' show ZSessionItem;
import 'package:zcrud_study/zcrud_study.dart';

import '../support/z_study_session_harness.dart';

/// Teintes de test — arbitraires et DISTINCTES de tout rôle du schéma, pour
/// qu'une égalité ne puisse pas être vraie par coïncidence.
const Color kTokenBackground = Color(0xFF123456);
const Color kTokenShadow = Color(0xFF654321);
const Color kTokenDivider = Color(0xFF0A0B0C);
const Color kParamBackground = Color(0xFFFE0001);
const Color kParamShadow = Color(0xFFFE0002);
const Color kParamDivider = Color(0xFFFE0003);

/// `ThemeData` clair dont les rôles visés sont EXPLICITES : les assertions
/// d'inertie comparent à ces valeurs-là, jamais à une constante recopiée.
ThemeData _base({ZcrudTheme? extension}) {
  final ThemeData base = ThemeData(
    colorScheme: const ColorScheme.light(outlineVariant: Color(0xFF445566)),
    scaffoldBackgroundColor: const Color(0xFFEEDDCC),
    shadowColor: const Color(0xFF223344),
  );
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      extension ?? ZcrudTheme.fallback(base),
    ],
  );
}

/// Monte [child] sous un `MaterialApp` portant [theme].
Widget _host(Widget child, ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(body: child),
    );

/// Couleur RÉELLEMENT peinte du fond de la carte : le `Material` que `Card`
/// construit, jamais la propriété déclarée du `Card`.
Color? _paintedCardColor(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(of: find.byType(Card), matching: find.byType(Material))
          .first,
    )
    .color;

/// Couleur RÉELLEMENT peinte de l'ombre : la première `BoxShadow` de la
/// `BoxDecoration` du `DecoratedBox` qui enveloppe la carte.
Color _paintedShadowColor(WidgetTester tester) {
  final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
    find.ancestor(of: find.byType(Card), matching: find.byType(DecoratedBox)),
  );
  final List<BoxShadow> shadows = <BoxShadow>[
    for (final DecoratedBox b in boxes)
      ...?(b.decoration as BoxDecoration).boxShadow,
  ];
  expect(shadows, hasLength(1),
      reason: 'garde VACUELLE : aucune ombre peinte autour de la carte');
  return shadows.single.color;
}

/// Couleur RÉELLEMENT peinte du séparateur : la bordure de la `BoxDecoration`
/// construite par `Divider`.
Color _paintedDividerColor(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .descendant(
            of: find.byType(Divider), matching: find.byType(DecoratedBox))
        .first,
  );
  final BoxDecoration deco = box.decoration as BoxDecoration;
  final Border border = deco.border! as Border;
  return border.bottom.color;
}

ZFlashcard _card() => const ZFlashcard(
      id: 'c1',
      question: 'Question ?',
      type: ZFlashcardType.openQuestion,
    );

/// Tranches figées de session — la vue seule, sans runtime.
ZStudySessionSlices _slices() {
  const List<ZSessionItem> queue = <ZSessionItem>[
    ZSessionItem(flashcardId: 'c0', folderId: kHarnessFolderId),
  ];
  return ZStudySessionSlices(
    phase: ValueNotifier<ZStudySessionPhase>(ZStudySessionPhase.studying),
    queue: ValueNotifier<List<ZSessionItem>>(queue),
    current: ValueNotifier<ZSessionItem?>(queue.first),
    progress: ValueNotifier<ZStudySessionProgress>(
      const ZStudySessionProgress(total: 1),
    ),
  );
}

/// Vue de session portant une zone de notation — sans elle, le `Divider`
/// n'existe pas dans l'arbre et la garde serait VACUELLE.
Widget _sessionView({Color? dividerColor}) => ZStudySessionView(
      slices: _slices(),
      passThreshold: 3,
      cardBuilder: (BuildContext context, ZSessionItem item) =>
          Text('carte ${item.flashcardId}'),
      gradingBuilder: (BuildContext context, ZSessionItem item) =>
          const Text('NOTATION'),
      dividerColor: dividerColor,
    );

void main() {
  group('🎨 fond de la carte de flashcard', () {
    testWidgets('INERTIE : sans jeton, le fond peint EST '
        '`scaffoldBackgroundColor`', (tester) async {
      final ThemeData theme = _base();
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(card: _card()), theme));
      expect(_paintedCardColor(tester), theme.scaffoldBackgroundColor);
    });

    testWidgets('le jeton `flashcardCardBackgroundColor` PEINT le fond',
        (tester) async {
      final ThemeData plain = ThemeData();
      final ThemeData theme = _base(
        extension: ZcrudTheme.fallback(plain)
            .copyWith(flashcardCardBackgroundColor: kTokenBackground),
      );
      // Le paramètre `backgroundColor` n'est PAS passé : le poser, fût-ce à sa
      // valeur neutre, court-circuiterait le maillon mesuré.
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(card: _card()), theme));
      expect(_paintedCardColor(tester), kTokenBackground);
    });

    testWidgets('le paramètre PRIME le jeton', (tester) async {
      final ThemeData plain = ThemeData();
      final ThemeData theme = _base(
        extension: ZcrudTheme.fallback(plain)
            .copyWith(flashcardCardBackgroundColor: kTokenBackground),
      );
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card(), backgroundColor: kParamBackground),
        theme,
      ));
      expect(_paintedCardColor(tester), kParamBackground);
    });
  });

  group('🎨 ombre de la carte de flashcard', () {
    testWidgets('INERTIE : sans jeton, l\'ombre peinte EST `shadowColor` à '
        'l\'opacité de référence', (tester) async {
      final ThemeData theme = _base();
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(card: _card()), theme));
      expect(
        _paintedShadowColor(tester),
        theme.shadowColor
            .withValues(alpha: ZFlashcardCardReference.shadowAlphaLight),
      );
    });

    testWidgets('le jeton `flashcardCardShadowColor` PEINT l\'ombre',
        (tester) async {
      final ThemeData plain = ThemeData();
      final ThemeData theme = _base(
        extension: ZcrudTheme.fallback(plain)
            .copyWith(flashcardCardShadowColor: kTokenShadow),
      );
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(card: _card()), theme));
      expect(
        _paintedShadowColor(tester),
        kTokenShadow
            .withValues(alpha: ZFlashcardCardReference.shadowAlphaLight),
      );
    });

    testWidgets('le paramètre PRIME le jeton', (tester) async {
      final ThemeData plain = ThemeData();
      final ThemeData theme = _base(
        extension: ZcrudTheme.fallback(plain)
            .copyWith(flashcardCardShadowColor: kTokenShadow),
      );
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card(), shadowColor: kParamShadow),
        theme,
      ));
      expect(
        _paintedShadowColor(tester),
        kParamShadow
            .withValues(alpha: ZFlashcardCardReference.shadowAlphaLight),
      );
    });

    testWidgets('l\'opacité, le flou et le décalage restent ceux de la '
        'référence — le jeton ne porte que la TEINTE', (tester) async {
      final ThemeData plain = ThemeData();
      final ThemeData theme = _base(
        extension: ZcrudTheme.fallback(plain)
            .copyWith(flashcardCardShadowColor: kTokenShadow),
      );
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(card: _card()), theme));
      final DecoratedBox box = tester.widgetList<DecoratedBox>(
        find.ancestor(
            of: find.byType(Card), matching: find.byType(DecoratedBox)),
      ).firstWhere(
        (DecoratedBox b) => (b.decoration as BoxDecoration).boxShadow != null,
      );
      final BoxShadow s =
          (box.decoration as BoxDecoration).boxShadow!.single;
      expect(s.blurRadius, ZFlashcardCardReference.shadowBlurRadius);
      expect(s.offset, ZFlashcardCardReference.shadowOffset);
    });
  });

  group('🎨 séparateur de l\'écran de session', () {
    testWidgets('INERTIE : sans jeton, le trait peint EST `outlineVariant`',
        (tester) async {
      useTallSurface(tester);
      final ThemeData theme = _base();
      await tester.pumpWidget(_host(_sessionView(), theme));
      await tester.pumpAndSettle();
      expect(_paintedDividerColor(tester), theme.colorScheme.outlineVariant);
    });

    testWidgets('le jeton `studySessionDividerColor` PEINT le trait',
        (tester) async {
      useTallSurface(tester);
      final ThemeData plain = ThemeData();
      final ThemeData theme = _base(
        extension: ZcrudTheme.fallback(plain)
            .copyWith(studySessionDividerColor: kTokenDivider),
      );
      await tester.pumpWidget(_host(_sessionView(), theme));
      await tester.pumpAndSettle();
      expect(_paintedDividerColor(tester), kTokenDivider);
    });

    testWidgets('le paramètre PRIME le jeton', (tester) async {
      useTallSurface(tester);
      final ThemeData plain = ThemeData();
      final ThemeData theme = _base(
        extension: ZcrudTheme.fallback(plain)
            .copyWith(studySessionDividerColor: kTokenDivider),
      );
      await tester
          .pumpWidget(_host(_sessionView(dividerColor: kParamDivider), theme));
      await tester.pumpAndSettle();
      expect(_paintedDividerColor(tester), kParamDivider);
    });
  });
}
