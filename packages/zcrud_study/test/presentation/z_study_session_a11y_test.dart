/// **Lot 1 « étude »** — AD-13 : géométrie RENDUE, `Semantics`, RTL.
///
/// 🔴 **On mesure `tester.getSize`, jamais des `constraints`.** Une contrainte
/// déclarée est une intention ; seule la taille rendue est un fait. Un
/// `ConstrainedBox(minHeight: 48)` dont le parent impose `maxHeight: 40` rend
/// 40 dp — et une garde qui lirait la contrainte resterait verte sur une cible
/// inatteignable au doigt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart' show ZSessionItem;
import 'package:zcrud_study/zcrud_study.dart';

import '../support/z_study_session_harness.dart';

void main() {
  Widget emptyView({
    VoidCallback? onExit,
    double? minTarget,
    TextDirection? textDirection,
    ZStudySessionLabels? labels,
  }) =>
      wrapForTest(
        ZStudySessionView(
          slices: ZStudySessionSlices(
            phase: ValueNotifier<ZStudySessionPhase>(ZStudySessionPhase.empty),
            queue: ValueNotifier<List<ZSessionItem>>(const <ZSessionItem>[]),
            current: ValueNotifier<ZSessionItem?>(null),
            progress: ValueNotifier<ZStudySessionProgress>(
              const ZStudySessionProgress(),
            ),
          ),
          passThreshold: 3,
          cardBuilder: (BuildContext c, ZSessionItem i) => const SizedBox(),
          onExit: onExit ?? () {},
          minTarget: minTarget,
          labels: labels,
        ),
        textDirection: textDirection,
      );

  group('🔴 AD-13 — cible ≥ 48 dp en GÉOMÉTRIE RENDUE', () {
    testWidgets('l\'issue de sortie mesure au moins 48 × 48 dp à l\'écran',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(emptyView());
      await tester.pumpAndSettle();

      final Size size = tester.getSize(
        find.byKey(ZStudySessionView.exitButtonKey),
      );
      expect(size.height, greaterThanOrEqualTo(48.0),
          reason: '🔴 hauteur RENDUE de ${size.height} dp — sous la cible '
              'Material/AD-13. Le `ButtonStyle` M3 pose 40 dp par défaut : '
              'sans relèvement explicite, cette cible est inatteignable.');
      expect(size.width, greaterThanOrEqualTo(48.0),
          reason: 'largeur RENDUE de ${size.width} dp');
    });

    testWidgets(
        '🔬 CONTRE-PREUVE — la mesure suit RÉELLEMENT le jeton : `minTarget: '
        '80` rend une cible de 80 dp (la garde ne lit pas une constante)',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(emptyView(minTarget: 80));
      await tester.pumpAndSettle();
      final Size size = tester.getSize(
        find.byKey(ZStudySessionView.exitButtonKey),
      );
      expect(size.height, greaterThanOrEqualTo(80.0),
          reason: '🔴 si la mesure ne suivait pas le paramètre, elle serait '
              'vraie pour de mauvaises raisons — et un abaissement du jeton '
              'passerait inaperçu');
    });
  });

  group('🔴 AD-13 — `Semantics` explicite', () {
    testWidgets('l\'issue de sortie est annoncée comme BOUTON, une seule fois',
        (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      useTallSurface(tester);
      await tester.pumpWidget(
        emptyView(
          labels: const ZStudySessionLabels(exitAction: 'Sortir de la session'),
        ),
      );
      await tester.pumpAndSettle();

      // 🔴 EXACTEMENT une annonce : un `Semantics(label:)` posé sur un bouton
      // qui porte DÉJÀ son texte produirait une double lecture au lecteur
      // d'écran (« Sortir de la session, Sortir de la session »).
      expect(
        find.bySemanticsLabel('Sortir de la session'),
        findsOneWidget,
        reason: '🔴 l\'annonce doit être UNIQUE — le libellé interne du bouton '
            'est exclu de l\'arbre sémantique (`ExcludeSemantics`)',
      );
      handle.dispose();
    });
  });

  group('🔴 AD-13 — RTL', () {
    testWidgets(
        'le repli se monte en arabe sans exception et garde sa cible '
        '(aucune API non-directionnelle)', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(emptyView(textDirection: TextDirection.rtl));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Size size = tester.getSize(
        find.byKey(ZStudySessionView.exitButtonKey),
      );
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
        '🔬 le padding est DIRECTIONNEL : LTR et RTL ne posent pas le même '
        'bord physique', (tester) async {
      useTallSurface(tester);
      // Padding volontairement asymétrique : si le socle utilisait
      // `EdgeInsets.only(left:)`, les deux directions rendraient la MÊME
      // géométrie — et la garde de source ne pourrait pas le voir ici.
      Widget withPadding(TextDirection d) => wrapForTest(
            ZStudySessionView(
              slices: ZStudySessionSlices(
                phase: ValueNotifier<ZStudySessionPhase>(
                    ZStudySessionPhase.empty),
                queue:
                    ValueNotifier<List<ZSessionItem>>(const <ZSessionItem>[]),
                current: ValueNotifier<ZSessionItem?>(null),
                progress: ValueNotifier<ZStudySessionProgress>(
                  const ZStudySessionProgress(),
                ),
              ),
              passThreshold: 3,
              cardBuilder: (BuildContext c, ZSessionItem i) => const SizedBox(),
              onExit: () {},
              contentPadding:
                  const EdgeInsetsDirectional.only(start: 120, end: 0),
            ),
            textDirection: d,
          );

      // 🔴 On mesure le CONTENU, pas le `Center` : le `Center` occupe toute la
      // surface dans les deux directions (dx = 0 partout), et une garde posée
      // sur lui serait VERTE quelle que soit la direction — une garde vacante.
      // (Premier jet de ce test : exactement ce défaut, démasqué par un rouge
      // `Expected: not <0.0> / Actual: <0.0>`.)
      Finder content() => find.descendant(
            of: find.byKey(ZStudySessionView.emptyKey),
            matching: find.byType(Column),
          );

      await tester.pumpWidget(withPadding(TextDirection.ltr));
      await tester.pumpAndSettle();
      final double ltrLeft = tester.getTopLeft(content()).dx;

      await tester.pumpWidget(withPadding(TextDirection.rtl));
      await tester.pumpAndSettle();
      final double rtlLeft = tester.getTopLeft(content()).dx;

      expect(ltrLeft, isNot(rtlLeft),
          reason: '🔴 `start` doit basculer de bord physique entre LTR et RTL '
              '— une géométrie identique prouverait un `left:` en dur');
    });
  });
}
