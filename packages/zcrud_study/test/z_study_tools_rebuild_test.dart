// Tests DISCRIMINANTS ES-5.2 — `ZStudyToolsPage` : scoping réactif ISOLÉ (SM-1),
// action d'ajout branchée + icône/label INJECTÉS, état vide GLOBAL, orientation.
//
// AC2 (CENTRAL / SM-1 / objectif produit n°1) : taper 100 caractères dans un
// champ scopé ne reconstruit QUE ce champ (rebuild ciblé via
// `ZFieldListenableBuilder`) — le champ voisin ET l'observateur structurel de
// page restent à 1, focus/curseur préservés. Reproduit le pattern de référence
// `zcrud_core/test/presentation/sm1_granular_rebuild_test.dart` sur la surface
// study-tools réelle. Pouvoir discriminant : cf. injections R3-I1..I4 (story).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Icône INJECTÉE distinctive (jamais `Icons.add` : prouve le solde MEDIUM-1).
const IconData kInjectedAddIcon = Icons.star;

/// Label sémantique INJECTÉ distinctif (jamais `spec.title`, jamais hardcodé).
const String kInjectedAddLabel = 'AJOUTER-UN-ELEMENT-XYZ';

/// Enveloppe déterministe (thème via `MaterialApp`, direction fixe, `ZcrudScope`
/// pour l'injection zéro-config AD-15).
Widget _wrap(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: dir,
      child: ZcrudScope(child: Scaffold(body: child)),
    ),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // AC2 — SM-1 (CENTRAL) : rebuild ciblé du seul champ courant.
  // ---------------------------------------------------------------------------
  testWidgets(
      'AC2 SM-1 : taper 100 caractères ne reconstruit QUE le champ courant',
      (tester) async {
    final controller = ZFormController(initialValues: {'a': '', 'b': ''});
    final teA = TextEditingController();
    final fnA = FocusNode();
    var buildsA = 0;
    var buildsB = 0;
    var buildsPage = 0;

    // Section A : [champ éditable 'a' scopé] + [observateur STRUCTUREL de page].
    ZStudyToolsSectionSpec sectionA() => ZStudyToolsSectionSpec(
          id: 'A',
          title: 'Section A',
          itemCount: 2,
          emptyState: const SizedBox.shrink(),
          itemBuilder: (context, index) {
            final c = ZStudyToolsPage.of(context);
            if (index == 0) {
              return ZFieldListenableBuilder(
                controller: c,
                name: 'a',
                builder: (context, value, child) {
                  buildsA++;
                  return EditableText(
                    controller: teA,
                    focusNode: fnA,
                    style: const TextStyle(),
                    cursorColor: const Color(0xFF000000),
                    backgroundCursorColor: const Color(0xFF000000),
                    // Sens unique : onChanged → setValue (JAMAIS .text=).
                    onChanged: (v) => c.setValue('a', v),
                  );
                },
              );
            }
            // Observateur STRUCTUREL non field-scoped : reste à 1 tant qu'aucun
            // rebuild global n'a lieu (croît sous R3-I1).
            buildsPage++;
            return const SizedBox(key: ValueKey('page-observer'));
          },
        );

    // Section B : un champ voisin 'b' scopé (autre section — jamais reconstruit).
    ZStudyToolsSectionSpec sectionB() => ZStudyToolsSectionSpec(
          id: 'B',
          title: 'Section B',
          itemCount: 1,
          emptyState: const SizedBox.shrink(),
          itemBuilder: (context, index) => ZFieldListenableBuilder(
            controller: ZStudyToolsPage.of(context),
            name: 'b',
            builder: (context, value, child) {
              buildsB++;
              return const SizedBox(key: ValueKey('field-b'));
            },
          ),
        );

    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        formController: controller,
        sections: [sectionA(), sectionB()],
      )),
    );

    // Montage initial : chaque builder a construit exactement une fois.
    expect(buildsA, 1);
    expect(buildsB, 1);
    expect(buildsPage, 1);

    fnA.requestFocus();
    await tester.pump();

    const total = 100;
    final buffer = StringBuffer();
    for (var i = 1; i <= total; i++) {
      buffer.write('x');
      await tester.enterText(find.byType(EditableText), buffer.toString());
      await tester.pump();
      // Focus jamais perdu pendant la saisie (AC3, contrôle continu).
      expect(fnA.hasFocus, isTrue);
    }

    // AC2 — seul le champ courant reconstruit ; voisin ET page inchangés.
    expect(buildsA, 1 + total,
        reason: 'le champ courant reconstruit à chaque frappe');
    expect(buildsB, 1, reason: 'le champ voisin (autre section) JAMAIS reconstruit');
    expect(buildsPage, 1, reason: 'aucun rebuild global de la page');

    controller.dispose();
    teA.dispose();
    fnA.dispose();
  });

  // ---------------------------------------------------------------------------
  // AC3 — focus et sélection préservés (controller stable, pas de ré-injection).
  // ---------------------------------------------------------------------------
  testWidgets('AC3 : focus conservé et curseur en fin après 100 frappes',
      (tester) async {
    final controller = ZFormController(initialValues: {'a': ''});
    final teA = TextEditingController();
    final fnA = FocusNode();

    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        formController: controller,
        sections: [
          ZStudyToolsSectionSpec(
            id: 'A',
            title: 'Section A',
            itemCount: 1,
            emptyState: const SizedBox.shrink(),
            itemBuilder: (context, index) {
              final c = ZStudyToolsPage.of(context);
              return ZFieldListenableBuilder(
                controller: c,
                name: 'a',
                builder: (context, value, child) => EditableText(
                  controller: teA,
                  focusNode: fnA,
                  style: const TextStyle(),
                  cursorColor: const Color(0xFF000000),
                  backgroundCursorColor: const Color(0xFF000000),
                  onChanged: (v) => c.setValue('a', v),
                ),
              );
            },
          ),
        ],
      )),
    );

    fnA.requestFocus();
    await tester.pump();
    expect(fnA.hasFocus, isTrue);

    final buffer = StringBuffer();
    for (var i = 1; i <= 100; i++) {
      buffer.write('a');
      await tester.enterText(find.byType(EditableText), buffer.toString());
      await tester.pump();
      expect(fnA.hasFocus, isTrue);
    }

    expect(controller.valueOf('a'), 'a' * 100);
    expect(teA.selection.baseOffset, 100,
        reason: 'curseur en fin de texte, jamais réinitialisé à 0');
    expect(fnA.hasFocus, isTrue);

    controller.dispose();
    teA.dispose();
    fnA.dispose();
  });

  // ---------------------------------------------------------------------------
  // AC1 — composition : exactement UN ZSectionedStudyLayout, N frontières keyées.
  // ---------------------------------------------------------------------------
  testWidgets('AC1 : la page COMPOSE un unique ZSectionedStudyLayout (N sections)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        sections: [
          _plainSection('A', 'Section A', 2),
          _plainSection('B', 'Section B', 0),
          _plainSection('C', 'Section C', 1),
        ],
      )),
    );

    expect(find.byType(ZSectionedStudyLayout), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.startsWith('section:');
      }),
      findsNWidgets(3),
    );
  });

  // ---------------------------------------------------------------------------
  // AC4 — action d'ajout branchée + icône/label INJECTÉS (solde DW-ES51-1).
  // ---------------------------------------------------------------------------
  testWidgets('AC4 : le bouton + invoque le callback injecté (une seule fois)',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        sections: [
          ZStudyToolsSectionSpec(
            id: 'A',
            title: 'Flashcards',
            itemCount: 1,
            emptyState: const SizedBox.shrink(),
            itemBuilder: (context, index) => const SizedBox(height: 10),
            addAction: () => taps++,
            addActionIcon: kInjectedAddIcon,
            addActionSemanticLabel: kInjectedAddLabel,
          ),
        ],
      )),
    );

    await tester.tap(find.byIcon(kInjectedAddIcon));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('AC4 : icône INJECTÉE rendue, jamais Icons.add codée en dur',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        sections: [
          ZStudyToolsSectionSpec(
            id: 'A',
            title: 'Flashcards',
            itemCount: 0,
            emptyState: const SizedBox.shrink(),
            itemBuilder: (context, index) => const SizedBox.shrink(),
            addAction: () {},
            addActionIcon: kInjectedAddIcon,
            addActionSemanticLabel: kInjectedAddLabel,
          ),
        ],
      )),
    );

    expect(find.byIcon(kInjectedAddIcon), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('AC4 : le label sémantique INJECTÉ prime sur le titre de section',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        sections: [
          ZStudyToolsSectionSpec(
            id: 'A',
            title: 'Flashcards',
            itemCount: 0,
            emptyState: const SizedBox.shrink(),
            itemBuilder: (context, index) => const SizedBox.shrink(),
            addAction: () {},
            addActionIcon: kInjectedAddIcon,
            addActionSemanticLabel: kInjectedAddLabel,
          ),
        ],
      )),
    );

    // Le label INJECTÉ est annoncé (via tooltip → semantics).
    expect(find.bySemanticsLabel(kInjectedAddLabel), findsOneWidget);
    handle.dispose();
  });

  testWidgets('AC4 : addAction null ⇒ AUCUN bouton d\'ajout rendu (AD-4)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        sections: [
          ZStudyToolsSectionSpec(
            id: 'A',
            title: 'Flashcards',
            itemCount: 0,
            emptyState: const SizedBox.shrink(),
            itemBuilder: (context, index) => const SizedBox.shrink(),
            addActionIcon: kInjectedAddIcon,
          ),
        ],
      )),
    );

    expect(find.byType(IconButton), findsNothing);
    expect(find.byIcon(kInjectedAddIcon), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // AC5 — état vide GLOBAL injecté.
  // ---------------------------------------------------------------------------
  testWidgets('AC5 : toutes sections vides + globalEmptyState ⇒ état global rendu',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        globalEmptyState: const SizedBox(key: ValueKey('global-empty')),
        sections: [
          _plainSection('A', 'A', 0),
          _plainSection('B', 'B', 0),
        ],
      )),
    );

    expect(find.byKey(const ValueKey('global-empty')), findsOneWidget);
    expect(find.byType(ZSectionedStudyLayout), findsNothing);
  });

  testWidgets('AC5 : au moins une section peuplée ⇒ pas de globalEmptyState',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        globalEmptyState: const SizedBox(key: ValueKey('global-empty')),
        sections: [
          _plainSection('A', 'A', 0),
          _plainSection('B', 'B', 1),
        ],
      )),
    );

    expect(find.byKey(const ValueKey('global-empty')), findsNothing);
    expect(find.byType(ZSectionedStudyLayout), findsOneWidget);
  });

  testWidgets('AC5 : globalEmptyState null + toutes vides ⇒ sections rendues',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        sections: [
          _plainSection('A', 'A', 0),
          _plainSection('B', 'B', 0),
        ],
      )),
    );

    expect(find.byType(ZSectionedStudyLayout), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // AC6 — orientation injectable : rail horizontal vs grille verticale.
  // ---------------------------------------------------------------------------
  testWidgets('AC6 : section horizontale ⇒ scroller horizontal (rail)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        sections: [
          ZStudyToolsSectionSpec(
            id: 'rail',
            title: 'Flashcards',
            itemCount: 3,
            axis: Axis.horizontal,
            emptyState: const SizedBox.shrink(),
            itemBuilder: (context, index) =>
                SizedBox(width: 40, height: 40, key: ValueKey('rail-$index')),
          ),
        ],
      )),
    );

    final scrollers = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((s) => s.scrollDirection == Axis.horizontal);
    expect(scrollers.length, 1,
        reason: 'la section horizontale rend un scroller horizontal');
  });

  testWidgets('AC6 : section verticale (défaut) ⇒ aucun scroller horizontal',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        sections: [
          ZStudyToolsSectionSpec(
            id: 'grid',
            title: 'Documents',
            itemCount: 3,
            emptyState: const SizedBox.shrink(),
            itemBuilder: (context, index) =>
                SizedBox(width: 40, height: 40, key: ValueKey('grid-$index')),
          ),
        ],
      )),
    );

    final horizontal = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((s) => s.scrollDirection == Axis.horizontal);
    expect(horizontal, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // Cycle de vie du controller : possédé disposé, injecté préservé.
  // ---------------------------------------------------------------------------
  testWidgets('controller INJECTÉ non disposé au démontage de la page',
      (tester) async {
    final injected = ZFormController(initialValues: {'a': ''});

    await tester.pumpWidget(
      _wrap(ZStudyToolsPage(
        formController: injected,
        sections: [_plainSection('A', 'A', 1)],
      )),
    );
    await tester.pumpWidget(_wrap(const SizedBox.shrink()));

    // Non disposé : setValue reste opérant (aucune exception « used after dispose »).
    injected.setValue('a', 'ok');
    expect(injected.valueOf('a'), 'ok');
    injected.dispose();
  });
}

/// Section « nue » CONSTANTE (sans champ éditable) pour les ACs structurels.
ZStudyToolsSectionSpec _plainSection(String id, String title, int count) {
  return ZStudyToolsSectionSpec(
    id: id,
    title: title,
    itemCount: count,
    emptyState: SizedBox(key: ValueKey('empty:$id')),
    itemBuilder: (context, index) =>
        SizedBox(height: 10, key: ValueKey('item:$id:$index')),
  );
}
