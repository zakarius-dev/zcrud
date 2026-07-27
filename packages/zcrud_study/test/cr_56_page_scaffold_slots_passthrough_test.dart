import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/suf3_harness.dart';

void main() {
  testWidgets('CR-56 — ZStudyFolderDetail relaie les 11 slots du Scaffold', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      persistentFooterButtons: const <Widget>[Text('PIED_DETAIL')],
      drawer: const Drawer(child: Text('DRAWER_DETAIL')),
      endDrawer: const Drawer(child: Text('END_DRAWER_DETAIL')),
      bottomNavigationBar: const SizedBox(
        height: 40,
        child: Text('NAV_DETAIL'),
      ),
      bottomSheet: const SizedBox(height: 30, child: Text('SHEET_DETAIL')),
      backgroundColor: const Color(0xFF123456),
      resizeToAvoidBottomInset: false,
      extendBody: true,
      extendBodyBehindAppBar: true,
    );

    // GARDE MORDANTE : retirer un pass-through dans la composition laisse la
    // propriété correspondante à son défaut et fait rougir ce test.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.floatingActionButton, isNotNull);
    expect(
      scaffold.floatingActionButtonLocation,
      FloatingActionButtonLocation.startFloat,
    );
    expect(scaffold.persistentFooterButtons, isNotNull);
    expect(scaffold.drawer, isNotNull);
    expect(scaffold.endDrawer, isNotNull);
    expect(scaffold.bottomNavigationBar, isNotNull);
    expect(scaffold.bottomSheet, isNotNull);
    expect(scaffold.backgroundColor, const Color(0xFF123456));
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
    expect(scaffold.extendBody, isTrue);
    expect(scaffold.extendBodyBehindAppBar, isTrue);
    expect(find.text('NAV_DETAIL'), findsOneWidget);
    expect(find.text('PIED_DETAIL'), findsOneWidget);
  });
}
