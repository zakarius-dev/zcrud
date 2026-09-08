/// La bande de verdict du résumé de session est-elle PILOTABLE par l'hôte ?
///
/// Le socle expose une chaîne unique de résolution des dégradés,
/// `zResolveGradient`, qui consulte dans l'ordre : le seam `gradientResolver`
/// de `ZcrudScope`, le jeton `ZcrudTheme.signaturePalette`, puis — sous le
/// profil `legacy` seulement — la référence auditée. Ce fichier mesure que la
/// bande de verdict emprunte bien cette chaîne, et que le rendu par défaut
/// (ni seam, ni jeton) n'a pas bougé d'un cran sous AUCUN des deux profils.
///
/// Ce qui est mesuré, et à quel étage :
///
/// * la DÉCORATION du `RenderDecoratedBox` réellement monté — l'objet que la
///   phase de peinture consomme, un cran sous la déclaration du widget ;
/// * les APPELS DE PEINTURE eux-mêmes, via le matcher `paints` de
///   `flutter_test`, qui rejoue `paint()` sur un canvas d'enregistrement : on
///   y lit le `Paint` réel — sa couleur pour un aplat, la présence d'un shader
///   pour un dégradé.
///
/// Ce qui n'est PAS mesuré : les pixels rasterisés. `RenderRepaintBoundary
/// .toImage()` ne rend jamais la main sous ce harnais (`flutter_tester` en
/// rendu logiciel déterministe) — mesuré, un run resté 9 min sans verdict sur
/// un `Container` de 40x40. Le `Paint` enregistré est donc l'étage le plus bas
/// atteignable ici.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult;

const ZStudySessionResult _result = ZStudySessionResult(
  total: 10,
  correct: 7,
  byQuality: <String, int>{'0': 1, '2': 2, '3': 3, '4': 3, '5': 1},
);

const ZWhiteExamVerdict _passed = ZWhiteExamVerdict(
  passed: true,
  ratio: 0.7,
  correct: 7,
  total: 10,
);

const Color _seed = Color(0xFF3355AA);

ColorScheme _scheme() => ColorScheme.fromSeed(seedColor: _seed);

/// Clé attendue par le seam, écrite À LA MAIN : jamais lue de la constante du
/// widget ni recomposée par `zSignatureKey`. C'est le contrat côté hôte, et un
/// test qui le dérive du code ne l'attrape pas quand il change.
const String _expectedGradientKey =
    'zcrud.signature.zcrud.session.summary.verdict';

/// Dégradé de l'HÔTE : des couleurs qu'aucune palette du socle ne contient.
const ZGradientSpec _hostSpec = ZGradientSpec(
  gradient: LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: <Color>[Color(0xFF00FF7F), Color(0xFF7F00FF)],
  ),
  onGradient: Color(0xFF101010),
);

/// Dégradé posé par le JETON de thème — distinct de celui de l'hôte, pour que
/// la priorité seam > jeton soit discernable.
const ZGradientSpec _tokenSpec = ZGradientSpec(
  gradient: LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: <Color>[Color(0xFFFFC800), Color(0xFFFF3200)],
  ),
  onGradient: Color(0xFF202020),
);

/// Seam de l'hôte : répond à la clé de la bande de verdict, `null` ailleurs.
ZGradientSpec? _hostResolver(ColorScheme scheme, String gradientKey) =>
    gradientKey == _expectedGradientKey ? _hostSpec : null;

Future<void> _pump(
  WidgetTester tester, {
  ZcrudTheme? theme,
  ZGradientResolver? resolver,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme()),
      home: Scaffold(
        body: ZcrudScope(
          theme: theme,
          gradientResolver: resolver,
          child: ZSessionSummaryView(
            result: _result,
            duration: const Duration(minutes: 3, seconds: 25),
            config: const ZSrsConfig(),
            onFinish: () {},
            verdict: _passed,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// La décoration RÉELLEMENT montée sous la clé de verdict.
BoxDecoration _painted(WidgetTester tester) =>
    tester.renderObject<RenderDecoratedBox>(
          find.descendant(
            of: find.byKey(ZSessionSummaryView.verdictKey),
            matching: find.byType(DecoratedBox),
          ),
        ).decoration
        as BoxDecoration;

RenderObject _verdictBox(WidgetTester tester) => tester.renderObject(
  find.descendant(
    of: find.byKey(ZSessionSummaryView.verdictKey),
    matching: find.byType(DecoratedBox),
  ),
);

Color _verdictTextColor(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(ZSessionSummaryView.verdictKey),
        matching: find.byType(Text),
      ),
    )
    .style!
    .color!;

/// Vrai si la bande a été peinte avec un SHADER (donc un dégradé).
PaintPattern _paintsAShadedBand() => paints
  ..something((Symbol method, List<dynamic> arguments) {
    if (method != #drawRRect && method != #drawRect) return false;
    final Paint paint = arguments.last as Paint;
    return paint.shader != null;
  });

/// Vrai si la bande a été peinte en APLAT de la couleur [color], sans shader.
PaintPattern _paintsAFlatBand(Color color) => paints
  ..something((Symbol method, List<dynamic> arguments) {
    if (method != #drawRRect && method != #drawRect) return false;
    final Paint paint = arguments.last as Paint;
    return paint.shader == null &&
        paint.color.toARGB32() == color.toARGB32();
  });

void main() {
  group('🔴 La bande de verdict emprunte la chaîne de résolution du socle', () {
    testWidgets(
      'S1 — seam de l\'hôte sous `legacy` : c\'est le dégradé de l\'HÔTE qui '
      'est peint, pas la référence',
      (tester) async {
        await _pump(
          tester,
          theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.legacy),
          resolver: _hostResolver,
        );

        expect(
          _painted(tester).gradient,
          _hostSpec.gradient,
          reason:
              'ATTRAPE : le site court-circuite `zResolveGradient` et peint la '
              'référence auditée — le seam de l\'hôte n\'atteint pas la bande',
        );
        expect(_painted(tester).color, isNull);
        expect(_verdictTextColor(tester), _hostSpec.onGradient);
        expect(_verdictBox(tester), _paintsAShadedBand());
      },
    );

    testWidgets(
      'S2 — seam de l\'hôte sous le profil PAR DÉFAUT : la décision de l\'hôte '
      'l\'emporte, le profil ne l\'annule pas',
      (tester) async {
        // Aucun profil déclaré ⇒ `neutral`. Le seam n'est pas une valeur de
        // référence : le profil ne le gouverne pas, il gouverne la référence.
        await _pump(tester, resolver: _hostResolver);

        expect(
          _painted(tester).gradient,
          _hostSpec.gradient,
          reason:
              'ATTRAPE : le seam étouffé par le profil neutre — l\'hôte ne '
              'peut alors PLUS teinter cette bande, seulement l\'éteindre',
        );
        expect(_verdictTextColor(tester), _hostSpec.onGradient);
        expect(_verdictBox(tester), _paintsAShadedBand());
      },
    );

    testWidgets(
      'S3 — jeton `signaturePalette` (sans seam) sous `legacy` : la bande '
      'porte la palette du THÈME',
      (tester) async {
        // Palette à une seule entrée : l\'index vaut 0 quelle que soit la
        // stratégie, la garde ne dépend donc pas du hachage de l\'identité.
        await _pump(
          tester,
          theme: const ZcrudTheme(
            referenceProfile: ZReferenceProfile.legacy,
            signaturePalette: <ZGradientSpec>[_tokenSpec],
          ),
        );

        expect(
          _painted(tester).gradient,
          _tokenSpec.gradient,
          reason:
              'ATTRAPE : le jeton de thème ignoré — la bande reste sur la '
              'référence auditée et l\'hôte ne peut pas la thémer',
        );
        expect(_verdictTextColor(tester), _tokenSpec.onGradient);
      },
    );

    testWidgets(
      'S4 — seam ET jeton posés : le seam gagne (paramètre > jeton > '
      'référence)',
      (tester) async {
        await _pump(
          tester,
          theme: const ZcrudTheme(
            referenceProfile: ZReferenceProfile.legacy,
            signaturePalette: <ZGradientSpec>[_tokenSpec],
          ),
          resolver: _hostResolver,
        );

        expect(
          _painted(tester).gradient,
          _hostSpec.gradient,
          reason: 'ATTRAPE : l\'ordre de la chaîne inversé entre seam et jeton',
        );
      },
    );

    testWidgets(
      'S5 — un seam qui répond `null` pour cette clé ne détourne RIEN : la '
      'référence reprend la main sous `legacy`',
      (tester) async {
        // `null` est une valeur FONCTIONNELLE du seam : « je ne me prononce
        // pas ». Elle ne doit pas éteindre la bande.
        await _pump(
          tester,
          theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.legacy),
          resolver: (ColorScheme scheme, String key) => null,
        );

        final ZGradientSpec? reference = zSignatureGradientFor(
          'zcrud.session.summary.verdict',
        );
        expect(reference, isNotNull);
        expect(
          _painted(tester).gradient,
          reference!.gradient,
          reason:
              'ATTRAPE : un seam muet interprété comme « pas de dégradé » — la '
              'bande s\'éteindrait chez tout hôte qui pose un résolveur partiel',
        );
      },
    );
  });

  group('🧊 Inertie : le rendu par DÉFAUT n\'a pas bougé', () {
    testWidgets(
      'I1 — `legacy`, ni seam ni jeton : dégradé PEINT strictement égal à la '
      'référence auditée',
      (tester) async {
        await _pump(
          tester,
          theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.legacy),
        );

        // Identité écrite à la main, palette et stratégie par défaut : c'est
        // exactement ce que le site calculait avant d'être rebranché.
        final ZGradientSpec? reference = zSignatureGradientFor(
          'zcrud.session.summary.verdict',
        );
        expect(reference, isNotNull);

        expect(
          _painted(tester).gradient,
          reference!.gradient,
          reason:
              'RÉGRESSION D\'INERTIE : le rendu legacy par défaut a changé de '
              'dégradé',
        );
        expect(_painted(tester).color, isNull);
        expect(_verdictTextColor(tester), reference.onGradient);
        expect(_verdictBox(tester), _paintsAShadedBand());
      },
    );

    testWidgets(
      'I2 — `neutral` EXPLICITE, ni seam ni jeton : aplat `primaryContainer` '
      'EXACT, aucun dégradé',
      (tester) async {
        await _pump(
          tester,
          theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
        );

        expect(_painted(tester).gradient, isNull);
        expect(_painted(tester).color, _scheme().primaryContainer);
        expect(_verdictTextColor(tester), _scheme().onPrimaryContainer);
        expect(
          _verdictBox(tester),
          _paintsAFlatBand(_scheme().primaryContainer),
          reason:
              'RÉGRESSION D\'INERTIE : la COULEUR RÉELLEMENT PEINTE sous '
              '`neutral` n\'est plus le rôle `primaryContainer` du thème monté',
        );
      },
    );

    testWidgets(
      'I3 — AUCUN profil déclaré (le défaut du socle) : indiscernable de I2',
      (tester) async {
        await _pump(tester);

        expect(
          _painted(tester).gradient,
          isNull,
          reason:
              'RÉGRESSION D\'INERTIE : la référence auditée est peinte sans '
              'profil déclaré — le défaut du socle a dérivé vers `legacy`',
        );
        expect(_painted(tester).color, _scheme().primaryContainer);
        expect(_verdictTextColor(tester), _scheme().onPrimaryContainer);
        expect(
          _verdictBox(tester),
          _paintsAFlatBand(_scheme().primaryContainer),
        );
      },
    );
  });
}
