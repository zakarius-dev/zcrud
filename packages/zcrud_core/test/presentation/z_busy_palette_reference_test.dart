/// Gardes de la référence « indicateur d'occupation » remontée dans le socle.
///
/// Contexte : le cycle de teintes « ça génère » ne vivait que dans la table de
/// référence du chat. Les feuilles de génération d'étude n'y avaient aucun
/// accès (AD-1 : un module ne dépend pas d'un autre module). La séquence est
/// donc devenue une référence du socle, que les deux consomment.
///
/// 🔴 Ce que la première garde ferme : deux tables recopiées divergent en
/// silence. La table de référence est FIGÉE ICI, recopiée à l'octet près de
/// `packages/zcrud_chat/lib/src/presentation/view/z_chat_notebook_reference.dart:476`
/// (`ZChatNotebookReference.busyPalette`). Le test lit ses PROPRES littéraux,
/// jamais le fichier du chat : une garde qui irait relire l'autre fichier
/// serait verte le jour où les deux dériveraient ensemble, et rougirait pour
/// une raison qui n'est pas la sienne (chemin, refactor, paquet absent).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Les 7 teintes attendues, dans l'ordre — table FIGÉE.
///
/// Source de la recopie :
/// `packages/zcrud_chat/lib/src/presentation/view/z_chat_notebook_reference.dart:476`.
const List<Color> _kTableFigee = <Color>[
  Color(0xFF2196F3), // bleu
  Color(0xFFF44336), // rouge
  Color(0xFFFFEB3B), // jaune
  Color(0xFFFF9800), // orange
  Color(0xFF795548), // brun
  Color(0xFF009688), // teal
  Color(0xFF4CAF50), // vert
];

/// Monte [read] sous un thème CRUD donné et rend sa valeur.
Future<T> _pumpAndRead<T>(
  WidgetTester tester,
  ZcrudTheme? theme,
  T Function(BuildContext context) read,
) async {
  late T value;
  await tester.pumpWidget(
    MaterialApp(
      home: ZcrudScope(
        theme: theme,
        child: Builder(
          builder: (BuildContext context) {
            value = read(context);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return value;
}

void main() {
  group('référence — égalité STRICTE avec la table figée', () {
    test('les 7 teintes, dans l\'ordre, à l\'octet près', () {
      // Égalité stricte, jamais `contains`/`length >=` : une palette qui
      // gagnerait une teinte, en perdrait une, ou les permuterait doit rougir.
      expect(ZBusyPaletteReference.colors.length, 7);
      expect(ZBusyPaletteReference.colors, _kTableFigee);
      for (int i = 0; i < _kTableFigee.length; i++) {
        expect(
          ZBusyPaletteReference.colors[i].toARGB32(),
          _kTableFigee[i].toARGB32(),
          reason: 'teinte #$i divergente de la table figée',
        );
      }
    });

    test('le tempo de référence vaut 300 ms par teinte, et le tour 7 × 300 ms',
        () {
      expect(ZBusyPaletteReference.interval, const Duration(milliseconds: 300));
      // `period` est le TOUR, pas le segment : la confusion des deux ferait
      // défiler la palette sept fois trop vite.
      expect(ZBusyPaletteReference.period, const Duration(milliseconds: 2100));
    });
  });

  group('lecteur `zBusyPaletteOf` — priorité jeton > référence > neutre', () {
    testWidgets('sans jeton ni profil : la référence auditée', (tester) async {
      final List<Color>? p = await _pumpAndRead(tester, null, zBusyPaletteOf);
      expect(p, _kTableFigee);
    });

    testWidgets('jeton posé : il PRIME sur la référence', (tester) async {
      const List<Color> mien = <Color>[Color(0xFF010203), Color(0xFF040506)];
      final List<Color>? p = await _pumpAndRead(
        tester,
        const ZcrudTheme(busyPalette: mien),
        zBusyPaletteOf,
      );
      expect(p, mien);
      // …et ce n'est pas la référence qui a été rendue par hasard.
      expect(p, isNot(_kTableFigee));
    });

    testWidgets('profil neutre : `null`, aucune séquence', (tester) async {
      final List<Color>? p = await _pumpAndRead(
        tester,
        const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
        zBusyPaletteOf,
      );
      expect(p, isNull);
    });

    testWidgets('profil neutre + jeton posé : le jeton s\'applique quand même',
        (tester) async {
      const List<Color> mien = <Color>[Color(0xFF010203)];
      final List<Color>? p = await _pumpAndRead(
        tester,
        const ZcrudTheme(
          referenceProfile: ZReferenceProfile.neutral,
          busyPalette: mien,
        ),
        zBusyPaletteOf,
      );
      expect(p, mien);
    });

    testWidgets('intervalle : jeton sinon référence, dans les DEUX profils',
        (tester) async {
      final Duration parDefaut =
          await _pumpAndRead(tester, null, zBusyCycleIntervalOf);
      expect(parDefaut, const Duration(milliseconds: 300));

      final Duration pose = await _pumpAndRead(
        tester,
        const ZcrudTheme(busyCycleInterval: Duration(milliseconds: 42)),
        zBusyCycleIntervalOf,
      );
      expect(pose, const Duration(milliseconds: 42));

      // Un scalaire n'est PAS effacé par le profil neutre.
      final Duration neutre = await _pumpAndRead(
        tester,
        const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
        zBusyCycleIntervalOf,
      );
      expect(neutre, const Duration(milliseconds: 300));
    });
  });

  group('jetons `ZcrudTheme` — les 4 sites', () {
    test('`copyWith` pose et relit les deux jetons', () {
      const ZcrudTheme base = ZcrudTheme();
      expect(base.busyPalette, isNull);
      expect(base.busyCycleInterval, isNull);
      final ZcrudTheme t = base.copyWith(
        busyPalette: const <Color>[Color(0xFF010203)],
        busyCycleInterval: const Duration(milliseconds: 42),
      );
      expect(t.busyPalette, <Color>[const Color(0xFF010203)]);
      expect(t.busyCycleInterval, const Duration(milliseconds: 42));
    });

    test('un `copyWith` VIDE ne perd ni la palette ni le tempo', () {
      const ZcrudTheme t = ZcrudTheme(
        busyPalette: <Color>[Color(0xFF010203)],
        busyCycleInterval: Duration(milliseconds: 42),
      );
      final ZcrudTheme same = t.copyWith();
      expect(same.busyPalette, <Color>[const Color(0xFF010203)]);
      expect(same.busyCycleInterval, const Duration(milliseconds: 42));
    });

    test('`lerp` bascule à mi-course et ne MATÉRIALISE jamais un `null`', () {
      const ZcrudTheme a = ZcrudTheme(
        busyPalette: <Color>[Color(0xFF000000)],
        busyCycleInterval: Duration(milliseconds: 10),
      );
      const ZcrudTheme b = ZcrudTheme(
        busyPalette: <Color>[Color(0xFFFFFFFF)],
        busyCycleInterval: Duration(milliseconds: 90),
      );
      expect(a.lerp(b, 0.25).busyPalette, <Color>[const Color(0xFF000000)]);
      expect(a.lerp(b, 0.75).busyPalette, <Color>[const Color(0xFFFFFFFF)]);
      expect(a.lerp(b, 0.25).busyCycleInterval, const Duration(milliseconds: 10));
      expect(a.lerp(b, 0.75).busyCycleInterval, const Duration(milliseconds: 90));

      // Deux côtés nuls restent nuls : sinon la référence s'imposerait à tout
      // hôte à la première transition de thème.
      const ZcrudTheme vide = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final ZcrudTheme l = vide.lerp(const ZcrudTheme(), t);
        expect(l.busyPalette, isNull, reason: 't=$t');
        expect(l.busyCycleInterval, isNull, reason: 't=$t');
      }
    });
  });

  group('`ZColorCycle.busy` — additif, et branché sur le lecteur', () {
    /// Rend la palette et le tempo réellement passés au `ZColorCycle` monté.
    Future<ZColorCycle> pumpBusy(WidgetTester tester, ZcrudTheme? theme) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            theme: theme,
            child: Builder(
              builder: (BuildContext context) => ZColorCycle.busy(
                context,
                builder: (BuildContext c, Color? color, Widget? child) =>
                    const SizedBox(),
              ),
            ),
          ),
        ),
      );
      return tester.widget<ZColorCycle>(find.byType(ZColorCycle));
    }

    testWidgets('sans jeton : la référence, et le tour = 7 × 300 ms',
        (tester) async {
      final ZColorCycle w = await pumpBusy(tester, null);
      expect(w.palette, _kTableFigee);
      expect(w.period, const Duration(milliseconds: 2100));
    });

    testWidgets('jeton posé : il prime, et le tour suit sa longueur',
        (tester) async {
      const List<Color> mien = <Color>[Color(0xFF010203), Color(0xFF040506)];
      final ZColorCycle w = await pumpBusy(
        tester,
        const ZcrudTheme(
          busyPalette: mien,
          busyCycleInterval: Duration(milliseconds: 50),
        ),
      );
      expect(w.palette, mien);
      expect(w.period, const Duration(milliseconds: 100));
    });

    testWidgets('profil neutre : UNE seule teinte, `ColorScheme.primary`',
        (tester) async {
      late Color primary;
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
            child: Builder(
              builder: (BuildContext context) {
                primary = Theme.of(context).colorScheme.primary;
                return ZColorCycle.busy(
                  context,
                  builder: (BuildContext c, Color? color, Widget? child) =>
                      const SizedBox(),
                );
              },
            ),
          ),
        ),
      );
      final ZColorCycle w = tester.widget<ZColorCycle>(
        find.byType(ZColorCycle),
      );
      expect(w.palette, <Color>[primary]);
      // Une seule teinte ⇒ rien à animer : l'état reste visible, sans cycle.
      expect(w.palette.length, 1);
    });

    testWidgets('INERTIE : le constructeur ordinaire est inchangé', (
      tester,
    ) async {
      // Un appelant qui porte déjà sa palette et son tempo ne voit RIEN du
      // nouveau chemin : ni le jeton, ni la référence ne s'y invitent.
      const List<Color> sienne = <Color>[Color(0xFF111111), Color(0xFF222222)];
      final List<Color?> peintes = <Color?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            theme: const ZcrudTheme(
              busyPalette: <Color>[Color(0xFF010203)],
              busyCycleInterval: Duration(milliseconds: 50),
            ),
            child: ZColorCycle(
              palette: sienne,
              period: const Duration(milliseconds: 777),
              builder: (BuildContext c, Color? color, Widget? child) {
                peintes.add(color);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final ZColorCycle w = tester.widget<ZColorCycle>(
        find.byType(ZColorCycle),
      );
      expect(w.palette, sienne);
      expect(w.period, const Duration(milliseconds: 777));

      // …et ce n'est pas seulement la DÉCLARATION qui est inerte : la teinte
      // réellement PEINTE vient de `sienne`. Une garde qui ne lirait que le
      // champ du widget serait verte si l'état, lui, allait chercher la
      // référence.
      await tester.pump(const Duration(milliseconds: 100));
      expect(peintes, isNotEmpty);
      expect(peintes.first, sienne.first);
      for (final Color? c in peintes) {
        expect(
          _kTableFigee.contains(c),
          isFalse,
          reason: 'la référence de socle a fui dans un cycle qui portait sa '
              'propre palette : $c',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}
