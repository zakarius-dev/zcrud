// EX-UI.11 AC3 — substitution au seam prouvée SANS modifier les paquets purs :
// `ZFormPresenterScope.of(context)` devient un `ZGetFormPresenter` (défaut
// `ZAdaptivePresenter` écarté) ; `ZToasterScope.of(context)` devient un
// `ZGetToaster` (défaut `ZScaffoldMessengerToaster` écarté). Le helper
// `ZcrudGetUiScope` monte les deux d'un coup.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

void main() {
  testWidgets('défauts pur-Flutter en place sans scope', (tester) async {
    late final ZFormPresenter presenter;
    late final ZToaster toaster;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          presenter = ZFormPresenterScope.of(context);
          toaster = ZToasterScope.of(context);
          return const SizedBox.shrink();
        },
      ),
    );
    // Sans scope monté : les défauts pur-Flutter (jamais les impls GetX).
    expect(presenter, isA<ZAdaptivePresenter>());
    expect(presenter, isNot(isA<ZGetFormPresenter>()));
    expect(toaster, isA<ZScaffoldMessengerToaster>());
    expect(toaster, isNot(isA<ZGetToaster>()));
  });

  testWidgets('scopes directs → impls GetX résolues (AC3)', (tester) async {
    late final ZFormPresenter presenter;
    late final ZToaster toaster;
    await tester.pumpWidget(
      ZFormPresenterScope(
        presenter: const ZGetFormPresenter(),
        child: ZToasterScope(
          toaster: const ZGetToaster(),
          child: Builder(
            builder: (context) {
              presenter = ZFormPresenterScope.of(context);
              toaster = ZToasterScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(presenter, isA<ZGetFormPresenter>());
    expect(toaster, isA<ZGetToaster>());
  });

  testWidgets('ZcrudGetUiScope monte les deux seams d\'un coup (AC3)',
      (tester) async {
    late final ZFormPresenter presenter;
    late final ZToaster toaster;
    await tester.pumpWidget(
      ZcrudGetUiScope(
        child: Builder(
          builder: (context) {
            presenter = ZFormPresenterScope.of(context);
            toaster = ZToasterScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(presenter, isA<ZGetFormPresenter>());
    expect(toaster, isA<ZGetToaster>());
  });
}
