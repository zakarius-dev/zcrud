// AD-57 — le rendu réordonnable passe par un PORT, pas par une implémentation
// figée dans le socle.
//
// Contexte : la grille réordonnable avait été écrite à la main au motif — erroné
// — qu'un paquet tiers serait « refusé par AD-1 ». AD-1 ne contraint que
// `zcrud_core`. Ces gardes vérifient les deux moitiés de la règle :
//   (1) un hôte PEUT substituer l'implémentation (donc un satellite adossé à un
//       paquet de l'écosystème est branchable sans toucher le socle) ;
//   (2) sans injection, un repli ZÉRO-DÉPENDANCE fonctionne — la capacité n'est
//       jamais absente.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Renderer d'essai : ne rend RIEN de réordonnable, seulement un marqueur —
/// c'est ce qui rend la substitution observable sans ambiguïté.
class _SpyRenderer extends ZReorderRenderer {
  const _SpyRenderer(this.seen);

  final List<ZReorderRenderRequest> seen;

  @override
  Widget build(BuildContext context, ZReorderRenderRequest request) {
    seen.add(request);
    return const Text('RENDU-SUBSTITUE');
  }
}

ZStudyToolsSectionSpec _reorderableSection() => ZStudyToolsSectionSpec(
      id: 'outils',
      title: 'Outils',
      itemCount: 4,
      itemIds: const <String>['a', 'b', 'c', 'd'],
      onReorder: (_, __) {},
      crossAxisMinItemWidth: 200,
      itemBuilder: (context, i) => SizedBox(
        key: ValueKey<String>('item-$i'),
        height: 40,
        child: Text('item $i'),
      ),
      emptyState: const SizedBox.shrink(),
    );

Widget _app({ZReorderRenderer? renderer}) {
  final layout = ZSectionedStudyLayout(sections: <ZStudyToolsSectionSpec>[
    _reorderableSection(),
  ]);
  final body = SizedBox(width: 800, height: 600, child: layout);
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: renderer == null
            ? body
            : ZcrudScope(reorderRenderer: renderer, child: body),
      ),
    ),
  );
}

void main() {
  group('AD-57 — le port est réellement substituable', () {
    testWidgets('🔴 un renderer INJECTÉ remplace le rendu du socle',
        (tester) async {
      // Discriminant : si le layout construisait la grille maison en dur, ce
      // marqueur serait absent et le socle serait non extensible — exactement
      // l'état qu'AD-57 corrige.
      final seen = <ZReorderRenderRequest>[];
      await tester.pumpWidget(_app(renderer: _SpyRenderer(seen)));
      await tester.pump();

      expect(find.text('RENDU-SUBSTITUE'), findsOneWidget);
      expect(seen, hasLength(1));
    });

    testWidgets('la requête transmise est NEUTRE et complète', (tester) async {
      // Un satellite tiers doit pouvoir tout reconstruire depuis la requête
      // seule : si un champ manquait, l'implémentation alternative serait
      // dégradée par construction.
      final seen = <ZReorderRenderRequest>[];
      await tester.pumpWidget(_app(renderer: _SpyRenderer(seen)));
      await tester.pump();

      final req = seen.single;
      expect(req.itemIds, <String>['a', 'b', 'c', 'd']);
      expect(req.minItemWidth, 200);
      expect(req.moveBeforeSemanticLabel, isNotNull);
      expect(req.moveAfterSemanticLabel, isNotNull);
    });

    testWidgets('🔴 aucun type de rendu concret ne fuit dans la requête',
        (tester) async {
      // Garde de frontière AD-57 : la requête ne porte que des types Flutter et
      // zcrud_core. Si un jour un type de paquet tiers y entrait, les
      // implémentations cesseraient d'être interchangeables.
      final seen = <ZReorderRenderRequest>[];
      await tester.pumpWidget(_app(renderer: _SpyRenderer(seen)));
      await tester.pump();
      expect(seen.single, isA<ZReorderRenderRequest>());
      expect(seen.single, isNot(isA<Widget>()));
    });
  });

  group('AD-57 — défaut ZÉRO-DÉPENDANCE (la capacité n\'est jamais absente)',
      () {
    testWidgets('🔴 sans injection, la grille réordonnable rend quand même',
        (tester) async {
      // C'est l'exigence qui distingue ce port de `ZListRenderer` : ce dernier
      // lève une `ZScopeError` s'il n'est pas injecté (aucun repli possible
      // sans backend de grille). Ici l'absence d'injection DOIT rester
      // fonctionnelle.
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('item 0'), findsOneWidget);
      expect(find.text('item 3'), findsOneWidget);
      expect(find.text('RENDU-SUBSTITUE'), findsNothing);
    });

    testWidgets('le repli est bien celui de zcrud_responsive', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.byType(ZReorderableAdaptiveGrid), findsOneWidget);
    });

    testWidgets('un ZcrudScope SANS reorderRenderer retombe sur le repli',
        (tester) async {
      // Cas réel : l'hôte injecte un thème ou un ACL mais rien pour le
      // réordonnancement. Le `?? const ZDefaultReorderRenderer()` doit mordre
      // sur le champ `null`, pas seulement sur l'absence de scope.
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: ZcrudScope(
              child: SizedBox(
                width: 800,
                height: 600,
                child: ZSectionedStudyLayout(
                  sections: <ZStudyToolsSectionSpec>[_reorderableSection()],
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ZReorderableAdaptiveGrid), findsOneWidget);
    });
  });
}
