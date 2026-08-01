/// Garde de **NEUTRALITÉ** (CHAT-4) — sans renderer injecté, rendu utilisable et
/// inchangé, et la règle d'absence (AD-4) appliquée AVANT tout rendu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_menu/zcrud_menu.dart';

const IconData _glyphe = Icons.circle;

Widget _hote(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets(
      'sans injection, le repli rend un menu ouvrable et la sélection porte',
      (tester) async {
    var ouvert = 0;
    await tester.pumpWidget(
      _hote(
        ZActionMenu(
          trigger: const ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
          entries: [
            ZMenuEntry(
              id: ZMenuEntryIds.open,
              label: 'LBL-OUVRIR',
              icon: _glyphe,
              onSelected: () => ouvert++,
            ),
          ],
        ),
      ),
    );

    // Aucun scope : le repli est bien celui qui rend.
    expect(find.byType(PopupMenuButton<ZMenuEntry>), findsOneWidget);
    expect(find.text('LBL-OUVRIR'), findsNothing, reason: 'menu fermé au repos');

    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();
    expect(find.text('LBL-OUVRIR'), findsOneWidget);

    await tester.tap(find.text('LBL-OUVRIR'));
    await tester.pumpAndSettle();
    // Exactement UNE invocation : ni zéro (callback mort — défaut IFFD
    // `onTap: () {}`), ni deux (double détecteur de geste).
    expect(ouvert, 1);
    expect(find.text('LBL-OUVRIR'), findsNothing, reason: 'menu refermé');
  });

  testWidgets('AD-4 — les TROIS états, dont celui que le socle ne savait pas dire',
      (tester) async {
    await tester.pumpWidget(
      _hote(
        ZActionMenu(
          trigger: const ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
          entries: [
            ZMenuEntry(
              id: ZMenuEntryIds.open,
              label: 'LBL-ACTIONNABLE',
              onSelected: () {},
            ),
            const ZMenuEntry(
              id: ZMenuEntryIds.edit,
              label: 'LBL-DESACTIVEE',
              disabledReason: 'MOTIF-BIENTOT',
            ),
            const ZMenuEntry(id: ZMenuEntryIds.share, label: 'LBL-ABSENTE'),
            ZMenuEntry(
              id: ZMenuEntryIds.delete,
              label: 'LBL-NON-PERMISE',
              permitted: false,
              onSelected: () {},
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();

    expect(find.text('LBL-ACTIONNABLE'), findsOneWidget);
    // 🔴 Présente ET inerte ET motivée — inexprimable avec ZItemAction.
    expect(find.text('LBL-DESACTIVEE'), findsOneWidget);
    expect(find.text('MOTIF-BIENTOT'), findsOneWidget);
    // Règle d'absence PRÉSERVÉE (jamais un item grisé SILENCIEUX).
    expect(find.text('LBL-ABSENTE'), findsNothing);
    // Droit refusé ⇒ absente, sans traduction à la charge de l'appelant.
    expect(find.text('LBL-NON-PERMISE'), findsNothing);
  });

  testWidgets('une entrée désactivée ne peut pas être exécutée', (tester) async {
    var appels = 0;
    await tester.pumpWidget(
      _hote(
        ZActionMenu(
          trigger: const ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
          entries: [
            const ZMenuEntry(
              id: ZMenuEntryIds.edit,
              label: 'LBL-DESACTIVEE',
              disabledReason: 'MOTIF',
            ),
            ZMenuEntry(
              id: ZMenuEntryIds.open,
              label: 'LBL-ACTIVE',
              onSelected: () => appels++,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LBL-DESACTIVEE'));
    await tester.pumpAndSettle();
    expect(appels, 0);
    // Le menu reste OUVERT : un tap sur une entrée inerte ne doit pas non plus
    // fermer la surface (sinon l'utilisateur perd son menu sans rien obtenir).
    expect(find.text('LBL-ACTIVE'), findsOneWidget);
  });

  testWidgets('AD-10 — aucune entrée et aucun contenu : déclencheur INERTE',
      (tester) async {
    await tester.pumpWidget(
      _hote(
        const ZActionMenu(
          trigger: ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
          entries: [],
        ),
      ),
    );
    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();
    // Ni surface fantôme, ni exception.
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<PopupMenuButton<ZMenuEntry>>(
        find.byType(PopupMenuButton<ZMenuEntry>),
      ).enabled,
      isFalse,
    );
  });

  testWidgets(
      'menu SÉLECTEUR : aucune entrée mais un contenu injecté reste ouvrable',
      (tester) async {
    // Forme des sélecteurs d'IFFD (task_due_date_picker, recurrence_picker…) :
    // le contenu du menu n'est pas une liste d'actions.
    await tester.pumpWidget(
      _hote(
        ZActionMenu(
          trigger: const ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
          entries: const [],
          contentBuilder: (context, entries, select) =>
              const Text('CONTENU-SELECTEUR'),
        ),
      ),
    );
    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();
    expect(find.text('CONTENU-SELECTEUR'), findsOneWidget);
  });

  testWidgets('contenu injecté : liste DÉJÀ filtrée et sélection par le socle',
      (tester) async {
    var appels = 0;
    List<ZMenuEntry>? recues;
    await tester.pumpWidget(
      _hote(
        ZActionMenu(
          trigger: const ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
          entries: [
            ZMenuEntry(
              id: ZMenuEntryIds.open,
              label: 'LBL-A',
              onSelected: () => appels++,
            ),
            const ZMenuEntry(id: ZMenuEntryIds.share, label: 'LBL-ABSENTE'),
          ],
          contentBuilder: (context, entries, select) {
            recues = entries;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in entries)
                  ZMenuEntryTile(
                    entry: e,
                    direction: Axis.vertical,
                    onSelected: () => select(e),
                  ),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();

    // La règle d'absence est INOPPOSABLE à l'hôte : il ne reçoit jamais l'entrée
    // absente, donc il ne peut pas la rendre par inadvertance.
    expect(recues!.map((e) => e.label), ['LBL-A']);

    await tester.tap(find.text('LBL-A'));
    await tester.pumpAndSettle();
    expect(appels, 1, reason: 'même chemin de sortie que le rendu par défaut');
    expect(find.text('LBL-A'), findsNothing, reason: 'surface refermée');
  });
}
