import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Toaster factice DÉFINI HORS des fichiers du port — prouve que `ZToaster`
/// est **injectable** et **non `sealed`** (AD-4/NFR-U9). Il ne rend rien : il
/// enregistre les appels.
class _FakeToaster implements ZToaster {
  final List<({String message, ZToastSeverity severity})> calls = [];

  @override
  void show(
    BuildContext context, {
    required String message,
    ZToastSeverity severity = ZToastSeverity.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    calls.add((message: message, severity: severity));
  }
}

void main() {
  testWidgets('zToast sans scope → ZScaffoldMessengerToaster (SnackBar rendue)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => zToast(context, 'msg'),
              child: const Text('GO'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('msg'), findsOneWidget);
  });

  testWidgets('zToast avec ZToasterScope → le toaster custom est appelé',
      (tester) async {
    final fake = _FakeToaster();
    await tester.pumpWidget(
      MaterialApp(
        home: ZToasterScope(
          toaster: fake,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => zToast(
                  context,
                  'salut',
                  severity: ZToastSeverity.warning,
                ),
                child: const Text('GO'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pump();

    // Le fake a intercepté l'appel : aucune SnackBar Flutter par défaut.
    expect(fake.calls, hasLength(1));
    expect(fake.calls.single.message, 'salut');
    expect(fake.calls.single.severity, ZToastSeverity.warning);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('ZToasterScope.of sans scope → défaut sûr (jamais de throw)',
      (tester) async {
    late ZToaster resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolved = ZToasterScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(resolved, isA<ZScaffoldMessengerToaster>());
  });

  testWidgets('ZToasterScope.maybeOf sans scope → null', (tester) async {
    ZToaster? resolved = _FakeToaster();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolved = ZToasterScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(resolved, isNull);
  });

  testWidgets('ZToasterScope.of avec scope → le toaster custom', (tester) async {
    final fake = _FakeToaster();
    late ZToaster resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: ZToasterScope(
          toaster: fake,
          child: Builder(
            builder: (context) {
              resolved = ZToasterScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(identical(resolved, fake), isTrue);
  });

  testWidgets('updateShouldNotify ne notifie que si le toaster change',
      (tester) async {
    final a = _FakeToaster();
    final b = _FakeToaster();
    final child = const SizedBox();
    final scopeA = ZToasterScope(toaster: a, child: child);
    // Même toaster → pas de notification.
    expect(scopeA.updateShouldNotify(ZToasterScope(toaster: a, child: child)),
        isFalse);
    // Toaster différent → notification.
    expect(scopeA.updateShouldNotify(ZToasterScope(toaster: b, child: child)),
        isTrue);
  });
}
