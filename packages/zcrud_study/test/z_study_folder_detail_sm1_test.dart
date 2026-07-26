/// SUF-3 AC14 (SM-1/AD-2) — rebuilds GRANULAIRES par tranche.
///
/// ## Ce que ces gardes prouvent — et ce qu'elles NE prouvent PAS (honnêteté)
///
/// Elles observent des tranches **RÉELLEMENT MONTÉES** :
/// - le corps « Matériel » (compteur d'invocations de `materialSectionsBuilder`) ;
/// - la **structure de la sidebar** (identité de l'instance `ZSubfolderSidebar`
///   dans l'arbre : une reconstruction de la page en fabrique forcément une
///   NOUVELLE, cf. le CONTRÔLE de falsifiabilité ci-dessous).
///
/// ⚠️ Elles ne disent **RIEN** de l'onglet « Progression » : `TabBarView` ne
/// monte pas l'onglet hors écran, donc tout compteur posé dans
/// `progressStatCards` resterait figé **par construction** — une assertion
/// « Progression n'a pas rebâti » serait TAUTOLOGIQUE (elle ne peut pas rougir).
/// Elle a donc été SUPPRIMÉE plutôt que maquillée : aucune promesse de
/// couverture non tenue dans ce fichier.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

/// Instance de sidebar actuellement dans l'arbre (sonde d'identité).
ZSubfolderSidebar _sidebar(WidgetTester t) =>
    t.widget<ZSubfolderSidebar>(find.byType(ZSubfolderSidebar));

void main() {
  testWidgets(
      'changer la sélection 10× re-fournit le corps Matériel SANS reconstruire '
      'la structure de la sidebar', (tester) async {
    await setScreen(tester, 900, 800);
    var matCalls = 0;
    await pumpDetail(
      tester,
      materialSectionsBuilder: (id) {
        matCalls++;
        return defaultSections(id);
      },
    );

    final matBaseline = matCalls;
    final sidebarBefore = _sidebar(tester);

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text(i.isEven ? 'Sous-dossier 1' : kAllLabel));
      await tester.pump();
    }

    // Tranche LIVE : le corps Matériel a bien été re-fourni (builder ré-invoqué).
    expect(matCalls, greaterThan(matBaseline));

    // GARDE MORDANTE (tranche FIGÉE, réellement montée) : porter la sélection
    // par un `setState` de page — ou par un notifier écouté au-dessus de
    // `_materialTab` — rejouerait `build()` et fabriquerait une NOUVELLE
    // instance de `ZSubfolderSidebar` ⇒ `identical` devient faux (rouge).
    // Falsifiabilité de cette sonde : cf. test CONTRÔLE ci-dessous.
    expect(identical(_sidebar(tester), sidebarBefore), isTrue);
  });

  testWidgets('replier/déplier 10× NE reconstruit PAS le corps Matériel',
      (tester) async {
    await setScreen(tester, 900, 800);
    var matCalls = 0;
    await pumpDetail(
      tester,
      materialSectionsBuilder: (id) {
        matCalls++;
        return defaultSections(id);
      },
    );
    final baseline = matCalls;

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(ZSubfolderSidebar.collapseToggleKey));
      await tester.pumpAndSettle();
    }

    // GARDE MORDANTE : porter le repli via un `setState` de page rebâtirait le
    // corps Matériel (matCalls monterait). Le repli est scopé à la sidebar.
    expect(matCalls, baseline);
  });

  testWidgets(
      'CONTRÔLE de falsifiabilité — la sonde d\'identité DÉTECTE bien une '
      'reconstruction de la sidebar', (tester) async {
    await setScreen(tester, 900, 800);
    await pumpDetail(tester);
    final before = _sidebar(tester);

    // Replier PUIS déplier repasse RÉELLEMENT par le builder de la région
    // sidebar (`ValueListenableBuilder<bool>` sur `_collapsed`) : une nouvelle
    // instance est construite.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(ZSubfolderSidebar.collapseToggleKey));
      await tester.pumpAndSettle();
    }

    // La sonde utilisée par la 1re garde n'est donc PAS vraie par construction :
    // dès qu'une reconstruction a lieu, `identical` bascule à faux.
    expect(identical(_sidebar(tester), before), isFalse);
  });
}
