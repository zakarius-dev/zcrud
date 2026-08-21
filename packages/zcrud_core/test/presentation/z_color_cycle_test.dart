/// `ZColorCycle` — la primitive « teinte qui parcourt une palette », testée
/// **SEULE**.
///
/// 🔴 Ce fichier ne monte rien du chat, ni artefact, ni notebook : c'est la
/// preuve que la primitive est réutilisable par n'importe quel module. Si une
/// garde d'ici avait besoin d'un artefact pour s'écrire, c'est que l'API
/// serait restée couplée à son module d'origine.
///
/// Ce qui est prouvé :
/// * **CC1** — la fonction pure de cycle : bornes, boucle, palette vide,
///   avancement hors bornes, avancement non fini.
/// * **CC2** — active ⇒ la teinte CHANGE dans le temps, et l'animation tourne.
/// * **CC3** — `active: false` ⇒ la teinte de repos, et **aucun** contrôleur.
/// * **CC4** — « Réduire les animations » ⇒ aucune animation **et** l'état
///   reste VISIBLE (les deux assertions).
/// * **CC5** — granularité AD-2 : l'appelant n'est pas reconstruit, et le
///   `child` traverse le cycle **à l'identique**.
/// * **CC6** — cycle de vie : passer au repos libère le contrôleur ; démonter
///   aussi (fuite de ticker détectée par `flutter_test`).
/// * **CC7** — contraste : avec une surface, la teinte rendue tient le
///   plancher, mesuré par une implémentation INDÉPENDANTE ; sans surface,
///   elle est rendue INCHANGÉE.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const Color _blue = Color(0xFF2196F3);
const Color _red = Color(0xFFF44336);
const Color _yellow = Color(0xFFFFEB3B);
const Color _idle = Color(0xFF37474F);
const Color _white = Color(0xFFFFFFFF);

const Duration _period = Duration(seconds: 2);

/// Luminance relative WCAG 2.x — implémentation **indépendante** de celle du
/// socle : sans elle, CC7 rappellerait la fonction qu'elle prétend mesurer.
double _luminance(Color c) {
  double lin(double channel) => channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _ratio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Hôte minimal : aucune surface stylée, juste un `MediaQuery` (le chemin
/// exact qu'emprunte un vrai réglage d'accessibilité) et la direction.
Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

/// Un hôte qui COMPTE ses reconstructions — la sonde de granularité.
class _CountingHost extends StatefulWidget {
  const _CountingHost({required this.child, super.key});

  final Widget child;

  @override
  State<_CountingHost> createState() => _CountingHostState();
}

class _CountingHostState extends State<_CountingHost> {
  int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return widget.child;
  }
}

void main() {
  group('🔴 CC1 — `zColorCycleAt` : la fonction pure du cycle', () {
    test('palette vide ⇒ `null` (chaîne totale, AD-10)', () {
      expect(zColorCycleAt(const <Color>[], 0.4), isNull);
    });

    test('une seule teinte ⇒ elle-même, quel que soit l\'avancement', () {
      expect(zColorCycleAt(const <Color>[_blue], 0), _blue);
      expect(zColorCycleAt(const <Color>[_blue], 0.73), _blue);
    });

    test('les BORNES de segment rendent EXACTEMENT les teintes déclarées', () {
      const List<Color> palette = <Color>[_blue, _red, _yellow];
      expect(zColorCycleAt(palette, 0), _blue);
      expect(zColorCycleAt(palette, 1 / 3), _red);
      expect(zColorCycleAt(palette, 2 / 3), _yellow);
    });

    test('le DERNIER segment revient à la première teinte — sinon le tour '
        'ferait un saut visible', () {
      const List<Color> palette = <Color>[_blue, _red, _yellow];
      final Color? milieu = zColorCycleAt(palette, 2 / 3 + 1 / 6);
      expect(milieu, isNotNull);
      expect(
        milieu,
        isNot(_yellow),
        reason: '🔴 le cycle s\'est arrêté sur la dernière teinte : il ne '
            'boucle pas',
      );
      expect(
        milieu,
        Color.lerp(_yellow, _blue, 0.5),
        reason: '🔴 le segment de retour ne vise pas la PREMIÈRE teinte',
      );
    });

    test('un avancement hors de [0,1[ est ramené par modulo, négatifs '
        'compris', () {
      const List<Color> palette = <Color>[_blue, _red];
      expect(zColorCycleAt(palette, 1), _blue);
      expect(zColorCycleAt(palette, 2.5), _red);
      expect(zColorCycleAt(palette, -0.5), _red);
    });

    test('un avancement NON FINI ne lève pas', () {
      const List<Color> palette = <Color>[_blue, _red];
      expect(zColorCycleAt(palette, double.nan), _blue);
      expect(zColorCycleAt(palette, double.infinity), _blue);
    });
  });

  group('🔴 CC2 — actif : la teinte change, et l\'animation TOURNE', () {
    testWidgets('la teinte parcourt la palette au fil du temps', (
      WidgetTester tester,
    ) async {
      Color? seen;
      await tester.pumpWidget(
        _host(
          ZColorCycle(
            palette: const <Color>[_blue, _red],
            period: _period,
            builder: (BuildContext context, Color? color, Widget? _) {
              seen = color;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        seen,
        _blue,
        reason: '🔴 le cycle ne démarre pas sur la PREMIÈRE teinte',
      );
      expect(
        tester.hasRunningAnimations,
        isTrue,
        reason: '🔴 aucune animation n\'a été armée',
      );
      await tester.pump(const Duration(milliseconds: 500));
      final Color? milieu = seen;
      expect(milieu, isNot(_blue), reason: '🔴 la teinte est FIGÉE');
      await tester.pump(const Duration(milliseconds: 500));
      expect(seen, _red, reason: '🔴 la mi-cycle ne rend pas la 2e teinte');
      // Démontage explicite : une animation infinie laissée en vol ferait
      // échouer le test sur une fuite de ticker — et `pumpAndSettle` ne
      // rendrait JAMAIS la main.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('🔴 CC3 — au repos : la teinte de repos, AUCUN contrôleur', () {
    testWidgets('`active: false` ⇒ `idle`, et rien ne tourne', (
      WidgetTester tester,
    ) async {
      Color? seen;
      await tester.pumpWidget(
        _host(
          ZColorCycle(
            palette: const <Color>[_blue, _red],
            period: _period,
            active: false,
            idle: _idle,
            builder: (BuildContext context, Color? color, Widget? _) {
              seen = color;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, _idle);
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: '🔴 un contrôleur tourne alors que RIEN n\'est en cours : '
            'c\'est un défaut de batterie que rien ne signalerait',
      );
    });

    testWidgets('une palette d\'UNE seule teinte n\'arme aucun contrôleur', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZColorCycle(
            palette: const <Color>[_blue],
            period: _period,
            builder: (BuildContext context, Color? color, Widget? _) =>
                const SizedBox.shrink(),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('un tempo NUL n\'arme aucun contrôleur (repli fermant)', (
      WidgetTester tester,
    ) async {
      Color? seen;
      await tester.pumpWidget(
        _host(
          ZColorCycle(
            palette: const <Color>[_blue, _red],
            period: Duration.zero,
            builder: (BuildContext context, Color? color, Widget? _) {
              seen = color;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        seen,
        _blue,
        reason: '🔴 sans tempo, l\'état a DISPARU au lieu de se figer',
      );
    });
  });

  group('🔴 CC4 — « Réduire les animations » : aucune animation, mais '
      'l\'état RESTE', () {
    testWidgets('aucun contrôleur n\'est créé ET la teinte reste peinte', (
      WidgetTester tester,
    ) async {
      Color? seen;
      await tester.pumpWidget(
        _host(
          ZColorCycle(
            palette: const <Color>[_blue, _red],
            period: _period,
            builder: (BuildContext context, Color? color, Widget? _) {
              seen = color;
              return const SizedBox.shrink();
            },
          ),
          reduceMotion: true,
        ),
      );
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: '🔴 « Réduire les animations » est actif et une animation '
            'tourne quand même',
      );
      expect(
        seen,
        _blue,
        reason: '🔴 l\'ÉTAT a disparu avec l\'animation : un état qui '
            's\'efface quand on réduit les animations est un défaut '
            'd\'accessibilité, pas une simplification',
      );
      // Et il reste figé : ce n'est pas une animation de durée nulle qui
      // continuerait de battre.
      await tester.pump(const Duration(seconds: 1));
      expect(seen, _blue);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('l\'état de repos reste DISTINCT de la teinte inactive', (
      WidgetTester tester,
    ) async {
      Color? seen;
      Widget build({required bool active}) => _host(
        ZColorCycle(
          palette: const <Color>[_blue, _red],
          period: _period,
          active: active,
          idle: _idle,
          builder: (BuildContext context, Color? color, Widget? _) {
            seen = color;
            return const SizedBox.shrink();
          },
        ),
        reduceMotion: true,
      );
      await tester.pumpWidget(build(active: false));
      expect(seen, _idle);
      await tester.pumpWidget(build(active: true));
      expect(
        seen,
        _blue,
        reason: '🔴 sous « Réduire les animations », l\'état actif est '
            'INDISCERNABLE du repos : le signal est perdu pour tout le monde, '
            'pas seulement pour qui a réduit les animations',
      );
    });
  });

  group('🔴 CC5 — AD-2 : l\'animation ne reconstruit QUE la teinte', () {
    testWidgets('l\'appelant n\'est pas reconstruit, et le `child` traverse '
        'le cycle À L\'IDENTIQUE', (WidgetTester tester) async {
      const Widget stable = SizedBox.shrink(key: ValueKey<String>('stable'));
      final GlobalKey<_CountingHostState> key =
          GlobalKey<_CountingHostState>();
      final List<Widget?> passed = <Widget?>[];
      int builderCalls = 0;
      await tester.pumpWidget(
        _host(
          _CountingHost(
            key: key,
            child: ZColorCycle(
              palette: const <Color>[_blue, _red],
              period: _period,
              child: stable,
              builder: (BuildContext context, Color? color, Widget? child) {
                builderCalls++;
                passed.add(child);
                return child ?? const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final int hostBuilds = key.currentState!.builds;
      final int callsAtStart = builderCalls;
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(
        builderCalls - callsAtStart,
        10,
        reason: '🔴 la teinte n\'est pas rejouée à chaque frame — ou elle '
            'l\'est plusieurs fois',
      );
      expect(
        key.currentState!.builds,
        hostBuilds,
        reason: '🔴 COMPTE ABSOLU : l\'appelant a été reconstruit par '
            'l\'animation — c\'est exactement l\'inverse de SM-1',
      );
      expect(
        passed.every((Widget? w) => identical(w, stable)),
        isTrue,
        reason: '🔴 le sous-arbre stable est RECONSTRUIT à chaque frame',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('🔴 CC6 — cycle de vie du contrôleur', () {
    testWidgets('repasser au repos LIBÈRE le contrôleur', (
      WidgetTester tester,
    ) async {
      Widget build({required bool active}) => _host(
        ZColorCycle(
          palette: const <Color>[_blue, _red],
          period: _period,
          active: active,
          builder: (BuildContext context, Color? color, Widget? _) =>
              const SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(build(active: true));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(build(active: false));
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: '🔴 le contrôleur tourne encore alors que la tâche est finie',
      );
    });

    testWidgets('démonter libère le contrôleur (aucune fuite de ticker)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZColorCycle(
            palette: const <Color>[_blue, _red],
            period: _period,
            builder: (BuildContext context, Color? color, Widget? _) =>
                const SizedBox.shrink(),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isTrue);
      // 🔴 Si `dispose` ne libérait pas le contrôleur, `flutter_test`
      // échouerait ici sur « A Ticker was started and never stopped ».
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('🔴 CC7 — contraste : la surface décide, jamais la palette', () {
    testWidgets('avec une surface, la teinte rendue tient le plancher — '
        'mesuré par une implémentation INDÉPENDANTE', (
      WidgetTester tester,
    ) async {
      final List<Color?> seen = <Color?>[];
      await tester.pumpWidget(
        _host(
          ZColorCycle(
            // Le jaune du legacy mesure ~1,07:1 sur blanc : livré brut, il
            // reproduirait le défaut ④ de CR-IFFD-84.
            palette: const <Color>[_yellow, _blue],
            period: _period,
            surface: _white,
            builder: (BuildContext context, Color? color, Widget? _) {
              seen.add(color);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        _ratio(_yellow, _white),
        lessThan(kZNonTextMinContrast),
        reason: '🔴 GARDE VACUELLE : la teinte témoin tient déjà le plancher, '
            'la correction ne prouve plus rien',
      );
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(seen.length, greaterThan(10));
      for (final Color? color in seen) {
        expect(color, isNotNull);
        expect(
          _ratio(color!, _white),
          greaterThanOrEqualTo(kZNonTextMinContrast - 0.01),
          reason: '🔴 une teinte du cycle est peinte SOUS le plancher de '
              'contraste : $color',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('sans surface, la teinte est rendue INCHANGÉE', (
      WidgetTester tester,
    ) async {
      Color? seen;
      await tester.pumpWidget(
        _host(
          ZColorCycle(
            palette: const <Color>[_yellow, _blue],
            period: _period,
            builder: (BuildContext context, Color? color, Widget? _) {
              seen = color;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        seen,
        _yellow,
        reason: '🔴 une correction a été appliquée sans surface de référence — '
            'contre quoi aurait-elle été mesurée ?',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('la teinte de REPOS passe elle aussi par le plancher', (
      WidgetTester tester,
    ) async {
      Color? seen;
      await tester.pumpWidget(
        _host(
          ZColorCycle(
            palette: const <Color>[_blue, _red],
            period: _period,
            active: false,
            idle: _yellow,
            surface: _white,
            builder: (BuildContext context, Color? color, Widget? _) {
              seen = color;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, isNotNull);
      expect(
        _ratio(seen!, _white),
        greaterThanOrEqualTo(kZNonTextMinContrast - 0.01),
        reason: '🔴 la teinte de repos échappe au plancher',
      );
    });
  });
}
