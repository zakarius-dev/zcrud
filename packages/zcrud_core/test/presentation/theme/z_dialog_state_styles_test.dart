// GARDE de RÉSOLUTION des styles `ZConfirmDialogStyle` / `ZEmptyStateStyle`.
//
// Ce que la garde ferme : un résolveur qui LIT le thème mais n'applique pas le
// repli que la dartdoc du jeton PROMET — ou qui matérialise une valeur là où le
// contrat exige de laisser décider `AlertDialog`. Les deux défauts rendent un
// écran plausible à l'œil et faux au contrat ; aucune garde structurelle ne les
// voit, puisque le jeton est bien lu.
//
// Deux régimes de nullité, VOLONTAIREMENT différents, et c'est là tout l'enjeu :
//   * dialogue de confirmation — `shape`/`titleStyle`/`contentStyle`/
//     `actionsPadding` sont transportés TELS QUELS, `null` compris (le `null`
//     est l'instruction « suis le `DialogTheme` ») ; seule la couleur
//     destructive est résolue, faute de repli Material ;
//   * état vide — TOUT est résolu, parce qu'aucun composant Material ne porte
//     de repli derrière un état vide.
//
// Chaque jeton reçoit une valeur DISCRIMINANTE : un croisement de champs entre
// deux jetons du même type serait détecté par l'égalité stricte.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Monte [child] sous un `ThemeData` portant [tokens] (ou aucune extension) et
/// rend le `BuildContext` de rendu.
Future<BuildContext> _contexteAvec(
  WidgetTester tester, {
  ZcrudTheme? tokens,
  ZcrudTheme? viaScope,
}) async {
  late BuildContext capture;
  Widget arbre = Builder(
    builder: (BuildContext context) {
      capture = context;
      return const SizedBox.shrink();
    },
  );
  if (viaScope != null) arbre = ZcrudScope(theme: viaScope, child: arbre);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: tokens == null
            ? const <ThemeExtension<dynamic>>[]
            : <ThemeExtension<dynamic>>[tokens],
      ),
      home: arbre,
    ),
  );
  return capture;
}

void main() {
  group('ZConfirmDialogStyle.resolve', () {
    testWidgets('sans jeton : nullité TRANSPORTÉE, seule l\'action '
        'destructive est résolue', (WidgetTester tester) async {
      final BuildContext context = await _contexteAvec(tester);
      final ZConfirmDialogStyle style = ZConfirmDialogStyle.resolve(context);

      expect(style.shape, isNull,
          reason: '🔴 une forme matérialisée EMPÊCHE `AlertDialog` de suivre '
              'le `DialogTheme` de l\'hôte');
      expect(style.titleStyle, isNull);
      expect(style.contentStyle, isNull);
      expect(style.actionsPadding, isNull);
      expect(style.destructiveColor, Theme.of(context).colorScheme.error,
          reason: 'repli documenté de `confirmDialogDestructiveColor`');
    });

    testWidgets('avec jetons : chacun transporté à l\'identique',
        (WidgetTester tester) async {
      const RoundedRectangleBorder forme = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(21)),
      );
      final BuildContext context = await _contexteAvec(
        tester,
        tokens: ZcrudTheme.fallback(ThemeData.light()).copyWith(
          confirmDialogShape: forme,
          confirmDialogTitleStyle: const TextStyle(fontSize: 22),
          confirmDialogContentStyle: const TextStyle(fontSize: 23),
          confirmDialogActionsPadding: const EdgeInsetsDirectional.all(24),
          confirmDialogDestructiveColor: const Color(0xFF112233),
        ),
      );
      final ZConfirmDialogStyle style = ZConfirmDialogStyle.resolve(context);

      expect(style.shape, forme);
      expect(style.titleStyle, const TextStyle(fontSize: 22));
      expect(style.contentStyle, const TextStyle(fontSize: 23));
      expect(style.actionsPadding, const EdgeInsetsDirectional.all(24));
      expect(style.destructiveColor, const Color(0xFF112233));
      expect(style.destructiveColor,
          isNot(Theme.of(context).colorScheme.error),
          reason: 'le jeton doit PRIMER sur le repli — sinon il est décoratif');
    });
  });

  group('ZEmptyStateStyle.resolve', () {
    testWidgets('sans jeton : les cinq replis documentés sont appliqués',
        (WidgetTester tester) async {
      final BuildContext context = await _contexteAvec(tester);
      final ThemeData theme = Theme.of(context);
      final ZEmptyStateStyle style = ZEmptyStateStyle.resolve(context);

      expect(style.iconSize, ZEmptyStateStyle.defaultIconSize);
      expect(style.iconSize, 48.0, reason: 'mesure de référence du glyphe');
      expect(style.iconColor, theme.colorScheme.onSurfaceVariant);
      expect(style.titleStyle, theme.textTheme.titleMedium);
      expect(style.messageStyle, theme.textTheme.bodyMedium);
      expect(style.spacing, ZcrudTheme.of(context).gapL,
          reason: 'le rythme suit `gapL` du socle, pas une constante privée');
      // Le repli n'est pas dégénéré : un `gapL` nul rendrait la garde vacuelle.
      expect(style.spacing, greaterThan(0));
    });

    testWidgets('avec jetons : chacun PRIME sur son repli',
        (WidgetTester tester) async {
      final BuildContext context = await _contexteAvec(
        tester,
        tokens: ZcrudTheme.fallback(ThemeData.light()).copyWith(
          emptyStateIconSize: 41,
          emptyStateIconColor: const Color(0xFF445566),
          emptyStateTitleStyle: const TextStyle(fontSize: 42),
          emptyStateMessageStyle: const TextStyle(fontSize: 43),
          emptyStateSpacing: 44,
        ),
      );
      final ThemeData theme = Theme.of(context);
      final ZEmptyStateStyle style = ZEmptyStateStyle.resolve(context);

      expect(style.iconSize, 41.0);
      expect(style.iconColor, const Color(0xFF445566));
      expect(style.titleStyle, const TextStyle(fontSize: 42));
      expect(style.messageStyle, const TextStyle(fontSize: 43));
      expect(style.spacing, 44.0);
      // …et aucune de ces valeurs n'est le repli, sans quoi le test serait
      // vert par coïncidence.
      expect(style.iconColor, isNot(theme.colorScheme.onSurfaceVariant));
      expect(style.titleStyle, isNot(theme.textTheme.titleMedium));
      expect(style.spacing, isNot(ZcrudTheme.fallback(theme).gapL));
    });

    testWidgets('le thème posé par `ZcrudScope` est lu comme celui de '
        '`ThemeData`', (WidgetTester tester) async {
      final BuildContext context = await _contexteAvec(
        tester,
        viaScope: ZcrudTheme.fallback(ThemeData.light()).copyWith(
          emptyStateIconSize: 61,
          emptyStateSpacing: 62,
        ),
      );
      final ZEmptyStateStyle style = ZEmptyStateStyle.resolve(context);

      expect(style.iconSize, 61.0,
          reason: '🔴 le résolveur ignore le thème du scope — un hôte qui '
              'passe par `ZcrudScope` verrait ses jetons sans effet');
      expect(style.spacing, 62.0);
    });
  });

  group('valeur', () {
    test('égalité structurelle des deux styles', () {
      const ZConfirmDialogStyle c1 = ZConfirmDialogStyle(
        destructiveColor: Color(0xFF010203),
        titleStyle: TextStyle(fontSize: 9),
      );
      const ZConfirmDialogStyle c2 = ZConfirmDialogStyle(
        destructiveColor: Color(0xFF010203),
        titleStyle: TextStyle(fontSize: 9),
      );
      const ZConfirmDialogStyle c3 = ZConfirmDialogStyle(
        destructiveColor: Color(0xFF010203),
        titleStyle: TextStyle(fontSize: 10),
      );
      expect(c1, c2);
      expect(c1.hashCode, c2.hashCode);
      expect(c1, isNot(c3));

      const ZEmptyStateStyle e1 = ZEmptyStateStyle(
        iconSize: 8,
        iconColor: Color(0xFF040506),
        spacing: 7,
      );
      const ZEmptyStateStyle e2 = ZEmptyStateStyle(
        iconSize: 8,
        iconColor: Color(0xFF040506),
        spacing: 7,
      );
      const ZEmptyStateStyle e3 = ZEmptyStateStyle(
        iconSize: 8,
        iconColor: Color(0xFF040506),
        spacing: 6,
      );
      expect(e1, e2);
      expect(e1.hashCode, e2.hashCode);
      expect(e1, isNot(e3));
    });
  });
}
