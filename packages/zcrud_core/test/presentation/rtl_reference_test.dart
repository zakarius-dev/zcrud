// AC7 : RTL — variantes directionnelles ; widget de référence (libellé + thème)
// rend sous Directionality.rtl ET .ltr ; résolution EdgeInsetsDirectional.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Widget de référence minimal : consomme `label()` ET `ZcrudTheme.of` ; padding
/// directionnel (RTL-safe).
class _RefField extends StatelessWidget {
  const _RefField();

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Padding(
      padding: theme.fieldPadding,
      child: Text(
        label(context, 'save'),
        textAlign: TextAlign.start,
      ),
    );
  }
}

Widget _host({required TextDirection dir}) => Directionality(
      textDirection: dir,
      child: Localizations(
        locale: const Locale('fr'),
        delegates: const <LocalizationsDelegate<dynamic>>[
          ZcrudLocalizationsDelegate(),
          DefaultWidgetsLocalizations.delegate,
        ],
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Theme(
            data: ThemeData.light(),
            child: const ZcrudScope(child: _RefField()),
          ),
        ),
      ),
    );

void main() {
  testWidgets('widget de référence rend sous RTL et LTR sans exception (AC7)',
      (tester) async {
    await tester.pumpWidget(_host(dir: TextDirection.rtl));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Enregistrer'), findsOneWidget);

    await tester.pumpWidget(_host(dir: TextDirection.ltr));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Enregistrer'), findsOneWidget);
  });

  test('EdgeInsetsDirectional.only(start:) : droite en RTL, gauche en LTR (AC7)',
      () {
    const inset = EdgeInsetsDirectional.only(start: 24);
    final rtl = inset.resolve(TextDirection.rtl);
    final ltr = inset.resolve(TextDirection.ltr);
    expect(rtl.right, 24);
    expect(rtl.left, 0);
    expect(ltr.left, 24);
    expect(ltr.right, 0);
  });
}
