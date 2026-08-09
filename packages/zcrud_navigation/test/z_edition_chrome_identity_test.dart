/// 🔴 Garde d'**IDENTITÉ D'ARBRE** — `presentEdition(chrome: null)` rend
/// EXACTEMENT l'arbre d'avant la CR chrome-presentation-aware.
///
/// L'exigence n'est pas « équivalent » : **identique**. La garde reprend le
/// patron `z_chat_settings_reexpression_guard_test.dart` (CR-LEX-78) :
///
/// 1. L'arbre des **trois** modes (`sheet`/`dialog`/`page`) a été sérialisé
///    ([zSerializeTree]) sur le code **restauré depuis `HEAD`** (copie des
///    fichiers `lib/` d'origine, jamais `git checkout`), puis versionné dans
///    [kIdentityReferencePath].
/// 2. Après la CR, le même montage doit produire **le même texte**, nœud pour
///    nœud, marge pour marge.
/// 3. **NON-VACUITÉ** : un second volet prouve que le sérialiseur DISTINGUE —
///    un seul `SizedBox` de plus dans le corps change la sérialisation. Sans ce
///    volet, la garde n° 1 pourrait tout accepter.
///
/// ⚠️ Chemin RELATIF au dossier du package (convention du dépôt : `flutter
/// test` se lance depuis `packages/zcrud_navigation`).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

import 'support/z_edition_tree_serializer.dart';

/// Étalon versionné de l'arbre rendu SANS chrome, pour les trois modes.
const String kIdentityReferencePath =
    'test/support/z_edition_no_chrome_tree_reference.txt';

/// Les trois montages de référence : largeur d'écran → mode attendu.
const List<(String, double, ZFormWeight)> kReferenceCases =
    <(String, double, ZFormWeight)>[
  ('sheet', 400, ZFormWeight.light),
  ('dialog', 700, ZFormWeight.light),
  ('page', 1000, ZFormWeight.heavy),
];

/// Monte l'app hôte, ouvre la surface via `presentEdition`, et sérialise
/// l'arbre du `Navigator` (qui porte la page hôte ET la surface présentée).
Future<String> captureTree(
  WidgetTester tester, {
  required double width,
  required ZFormWeight formWeight,
  required String hostKey,
  ZEditionChrome? chrome,
  Widget body = const Text('CORPS'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding.zero;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<String>(hostKey),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => presentEdition<void>(
                context,
                builder: (_) => body,
                formWeight: formWeight,
                chrome: chrome,
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return zSerializeTree(tester, find.byType(Navigator));
}

Future<String> captureAll(
  WidgetTester tester, {
  ZEditionChrome? chrome,
  Widget body = const Text('CORPS'),
  String runId = 'a',
}) async {
  final StringBuffer out = StringBuffer();
  for (final (String name, double width, ZFormWeight weight)
      in kReferenceCases) {
    out.writeln('=== $name ===');
    out.write(
      await captureTree(
        tester,
        width: width,
        formWeight: weight,
        // Clé DISTINCTE par montage : sans elle, `pumpWidget` réutiliserait
        // l'élément `MaterialApp` — donc la pile de routes du montage
        // précédent, et la surface suivante ne s'ouvrirait jamais.
        hostKey: '$runId-$name',
        chrome: chrome,
        body: body,
      ),
    );
  }
  return out.toString();
}

void main() {
  testWidgets(
      'ID-1 — sans chrome, l\'arbre des 3 modes est celui d\'AVANT la CR, '
      'à l\'identique', (WidgetTester tester) async {
    final String actual = await captureAll(tester);
    final File reference = File(kIdentityReferencePath);
    expect(reference.existsSync(), isTrue,
        reason: '🔴 l\'étalon d\'arbre SANS chrome a disparu : la garde ID-1 '
            'n\'a plus de référence.');
    if (actual != reference.readAsStringSync()) {
      final File dump = File(
        '${Directory.systemTemp.path}/z_edition_no_chrome_tree_actual.txt',
      )..writeAsStringSync(actual);
      fail(
        '🔴 `presentEdition(chrome: null)` ne rend PLUS l\'arbre d\'avant la '
        'CR. L\'opt-in n\'est donc plus strict. Étalon : '
        '${reference.path} — arbre réel : ${dump.path}.',
      );
    }
  });

  testWidgets(
      'ID-2 — NON-VACUITÉ : le sérialiseur distingue un SizedBox de plus dans '
      'le corps', (WidgetTester tester) async {
    final String base = await captureAll(tester, runId: 'b1');
    final String altered = await captureAll(
      tester,
      runId: 'b2',
      body: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[SizedBox(height: 1), Text('CORPS')],
      ),
    );
    expect(base == altered, isFalse,
        reason: '🔴 le sérialiseur n\'a pas vu un widget de plus : la garde '
            'ID-1 serait VACANTE.');
  });

  testWidgets(
      'ID-3 — avec chrome, l\'arbre DIFFÈRE (l\'opt-in a bien un effet)',
      (WidgetTester tester) async {
    final String base = await captureAll(tester, runId: 'c1');
    final String withChrome = await captureAll(tester,
        runId: 'c2', chrome: const ZEditionChrome(title: 'Titre'));
    expect(base == withChrome, isFalse,
        reason: '🔴 fournir un chrome ne change rien à l\'arbre : le chrome '
            'n\'est pas monté.');
  });
}
