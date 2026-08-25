// SURFACE de l'aperçu flottant d'un réordonnancement de sous-liste.
//
// Le défaut mesuré : un aperçu de glisser-déposer est monté dans l'`Overlay`,
// donc SIBLING de la route, jamais dessous. Ce qu'un contenu de ligne trouvait
// par héritage — au premier chef la feuille `Material` du `Scaffold` — n'y est
// plus, et un sous-champ Material (`TextField`…) re-rendu dans l'aperçu lève
// « No Material widget found » : écran rouge en debug, silence en release.
//
// Le cœur pose donc UNE surface de transparence (`_zSubListDragPreviewSurface`)
// et la sert aux deux extrémités : son repli interne l'applique lui-même, et
// ses requêtes la transportent jusqu'à un renderer injecté via
// `ZReorderRenderRequest.dragPreviewWrapper`.
//
// Ce fichier mesure QUATRE propriétés, toutes sur le comportement rendu :
//  (a) repli interne — la surface existe pendant le glissement, UNE seule fois,
//      et uniquement dans l'overlay ;
//  (b) canal — les DEUX sites de requête du champ (cartes, lignes de résumé) le
//      remplissent, et ce qu'il porte SUFFIT réellement à un widget qui exige
//      un ancêtre Material (mesure bidirectionnelle : sans lui ça lève) ;
//  (c) l'habillage ne touche que l'APERÇU — la ligne rendue en place n'en porte
//      aucune trace ;
//  (d) inertie du contrat — une requête qui ne remplit pas le canal le laisse à
//      `null`, c'est-à-dire à l'identité.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

const _seed = <Map<String, dynamic>>[
  <String, dynamic>{'f1': 'A'},
  <String, dynamic>{'f1': 'B'},
  <String, dynamic>{'f1': 'C'},
];

/// Champ de sous-liste réordonnable dans le mode d'affichage voulu.
///
/// Le champ pousse une requête au renderer depuis DEUX endroits distincts,
/// un par mode : `inline` empile des CARTES de sous-formulaire, `compact` rend
/// des LIGNES de résumé. Les deux doivent remplir le canal — mesurer un seul
/// mode laisserait l'autre sans garde (c'est ce qu'une première version de ce
/// fichier faisait, les deux cas retombant sur `compact`).
ZFieldSpec _field(ZSubListDisplayMode mode) => ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: _itemFields,
        reorderable: true,
        displayMode: mode,
        summaryFields: const <String>['f1'],
      ),
    );

/// Les deux modes qui poussent une requête réordonnable.
const List<ZSubListDisplayMode> _modes = <ZSubListDisplayMode>[
  ZSubListDisplayMode.inline,
  ZSubListDisplayMode.compact,
];

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Finder get _handles => find.byIcon(Icons.drag_indicator_rounded);

/// Feuilles de **transparence structurelle** actuellement montées, séparées
/// selon qu'elles vivent sous l'écran ou dans l'`Overlay`.
///
/// La mesure porte sur une PROPRIÉTÉ du rendu — une feuille qui ne peint rien —
/// et non sur un nom de classe privée : n'importe quelle autre façon d'obtenir
/// la même surface serait comptée pareil.
({int enPlace, int dansOverlay}) _surfaces(WidgetTester tester) {
  int enPlace = 0;
  int dansOverlay = 0;
  for (final element in find.byType(Material).evaluate()) {
    final Material material = element.widget as Material;
    if (material.type != MaterialType.transparency) continue;
    // Un aperçu de glissement est monté hors de la route : aucun `Scaffold`
    // au-dessus de lui. C'est le seul discriminant fiable — la position à
    // l'écran, elle, se confond avec celle de la ligne d'origine.
    if (element.findAncestorWidgetOfExactType<Scaffold>() == null) {
      dansOverlay++;
    } else {
      enPlace++;
    }
  }
  return (enPlace: enPlace, dansOverlay: dansOverlay);
}

/// Widget qui exige une feuille Material, par le prédicat même dont
/// `TextField` se sert (`debugCheckHasMaterial`) — il lève le `FlutterError`
/// « No Material widget found » quand l'ancêtre manque.
///
/// Il tient lieu de `TextField` ici parce qu'il isole LA propriété mesurée :
/// un vrai `TextField` exige en plus des `MaterialLocalizations`, et un rouge
/// causé par les localisations ne dirait rien de la surface. La reproduction
/// de bout en bout avec un vrai `TextField` vit côté renderer, là où l'hôte de
/// test fournit les deux.
class _ExigeUneFeuille extends StatelessWidget {
  const _ExigeUneFeuille();

  @override
  Widget build(BuildContext context) {
    debugCheckHasMaterial(context);
    return const SizedBox(width: 10, height: 10);
  }
}

/// Monte [child] SANS aucune feuille Material au-dessus et retourne ce qui a
/// levé, ou `null`. Reproduit exactement la condition de l'`Overlay`.
Future<Object?> _sansFeuille(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(child: SizedBox(width: 200, height: 60, child: child)),
      ),
    ),
  );
  await tester.pump();
  return tester.takeException();
}

/// Renderer injecté qui se contente de CAPTURER la requête reçue.
class _CapturingRenderer extends ZReorderRenderer {
  _CapturingRenderer({this.monteLaSentinelle = false});

  /// Monte, À CÔTÉ des lignes, une sentinelle passée par le canal. Elle sert de
  /// contrepoint positif : dans le MÊME arbre, on compte alors ce que le canal
  /// ajoute et ce que les lignes, elles, ne portent pas.
  final bool monteLaSentinelle;

  ZReorderRenderRequest? request;

  @override
  Widget build(BuildContext context, ZReorderRenderRequest request) {
    this.request = request;
    final wrapper = request.dragPreviewWrapper;
    return Column(
      children: <Widget>[
        for (var i = 0; i < request.itemIds.length; i++)
          request.itemBuilder(context, i),
        if (monteLaSentinelle && wrapper != null)
          wrapper(const SizedBox(width: 10, height: 10)),
      ],
    );
  }
}

/// Capture la requête que le champ pousse au renderer injecté.
Future<ZReorderRenderRequest> _capture(
  WidgetTester tester,
  ZSubListDisplayMode mode, {
  bool monteLaSentinelle = false,
}) async {
  final renderer = _CapturingRenderer(monteLaSentinelle: monteLaSentinelle);
  await tester.pumpWidget(_host(ZcrudScope(
    reorderRenderer: renderer,
    child: ZSubListFieldWidget(
      field: _field(mode),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (_) {},
    ),
  )));
  await tester.pump();
  final ZReorderRenderRequest? captured = renderer.request;
  expect(captured, isNotNull, reason: 'le renderer injecté n\'a pas été appelé');
  return captured!;
}

void main() {
  testWidgets(
      '(a) repli interne — la surface de transparence n\'existe QUE pendant le '
      'glissement, une seule fois, et uniquement dans l\'overlay',
      (tester) async {
    for (final mode in _modes) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _field(mode),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (_) {},
    )));
    await tester.pump();

    expect(_surfaces(tester), (enPlace: 0, dansOverlay: 0),
        reason: '$mode : au repos, aucune surface d\'aperçu ne doit être montée');

    final gesture =
        await tester.startGesture(tester.getCenter(_handles.first));
    // Glissement IMMÉDIAT depuis la poignée : pas de seuil d'appui long.
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      _surfaces(tester),
      (enPlace: 0, dansOverlay: 1),
      reason: '$mode : exactement UNE surface, portée par le seul aperçu',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_surfaces(tester), (enPlace: 0, dansOverlay: 0),
        reason: '$mode : le glissement fini, la surface disparaît avec l\'aperçu');
    }
  });

  testWidgets(
      '(b) canal — les DEUX sites de requête le remplissent, et ce qu\'il porte '
      'suffit à un widget privé de feuille (mesure bidirectionnelle)',
      (tester) async {
    for (final mode in _modes) {
      final ZReorderRenderRequest request = await _capture(tester, mode);

      final ZReorderDragPreviewWrapper? wrapper = request.dragPreviewWrapper;
      expect(wrapper, isNotNull,
          reason: 'site mode=$mode : canal laissé vide');

      // Sens 1 — le contrôle NÉGATIF : sans la surface, ça lève vraiment.
      // Sans lui, le sens 2 pourrait être vert pour n'importe quelle raison.
      expect(
        await _sansFeuille(tester, const _ExigeUneFeuille()),
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('No Material widget found'),
        ),
        reason: 'le contrôle négatif doit lever, sinon la mesure ne dit rien',
      );

      // Sens 2 — ce que le canal porte SUFFIT, dans la même condition.
      expect(
        await _sansFeuille(tester, wrapper!(const _ExigeUneFeuille())),
        isNull,
        reason: 'site mode=$mode : la surface ne suffit pas',
      );
    }
  });

  testWidgets(
      '(c) l\'habillage ne touche QUE l\'aperçu — les lignes bâties par '
      'itemBuilder n\'en portent aucune trace, la sentinelle du canal si',
      (tester) async {
    for (final mode in _modes) {
      // Un SEUL arbre porte les deux : les trois lignes rendues en place, et
      // une sentinelle passée par le canal. Compter dans le même arbre écarte
      // l'explication « il n'y a de surface nulle part ».
      await _capture(tester, mode, monteLaSentinelle: true);
      expect(
        _surfaces(tester),
        (enPlace: 1, dansOverlay: 0),
        reason: 'site mode=$mode : la surface comptée doit '
            'être celle de la seule sentinelle — une ligne en place habillée '
            'en ajouterait trois de plus',
      );

      // Le même arbre SANS la sentinelle : plus aucune surface. C'est ce qui
      // prouve que l'unique surface ci-dessus venait bien du canal.
      await _capture(tester, mode);
      expect(
        _surfaces(tester),
        (enPlace: 0, dansOverlay: 0),
        reason: 'site mode=$mode : ligne en place habillée',
      );
    }
  });

  test(
      '(d) inertie du contrat — une requête qui ne remplit pas le canal le '
      'laisse à null, c\'est-à-dire à l\'identité', () {
    final request = ZReorderRenderRequest(
      itemIds: const <String>['a'],
      itemBuilder: (_, _) => const SizedBox.shrink(),
      onReorder: (_, _) {},
      minItemWidth: 100,
    );
    expect(request.dragPreviewWrapper, isNull);
  });
}
