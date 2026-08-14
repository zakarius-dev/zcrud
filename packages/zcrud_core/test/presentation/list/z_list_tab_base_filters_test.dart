// Le SOCLE DE FILTRES d'un onglet est déclaré dans le modèle.
//
// Jusqu'ici la catégorie d'un onglet ne vivait que dans la fermeture de
// `ZListTab.category` : invisible à qui héberge les onglets, donc impossible à
// composer pour lui. Elle est désormais lisible (`baseFilters`), sans rien
// retirer au chemin historique (`buildList` la reçoit toujours).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _category = <ZFilter>[ZFilter('status', ZFilterOp.eq, 'open')];
const _permanent = ZFilter('archive', ZFilterOp.eq, false);

void main() {
  test('ZListTab.category DÉCLARE sa catégorie ET la passe au buildList', () {
    List<ZFilter>? received;
    final tab = ZListTab.category(
      labelKey: 'open',
      filters: _category,
      buildList: (context, categoryFilters) {
        received = categoryFilters;
        return const SizedBox.shrink();
      },
    );

    expect(
      tab.baseFilters,
      _category,
      reason: 'la catégorie doit être LISIBLE par l\'assembleur',
    );
    tab.builder!(_FakeContext());
    expect(
      received,
      _category,
      reason: 'le chemin historique reste servi par la MÊME déclaration',
    );
  });

  test('filtersWith AJOUTE, socle en tête — il ne remplace jamais', () {
    final tab = ZListTab(
      labelKey: 'open',
      baseFilters: _category,
      builder: (_) => const SizedBox.shrink(),
    );

    expect(
      tab.filtersWith(const <ZFilter>[_permanent]),
      <ZFilter>[..._category, _permanent],
    );
    expect(tab.filtersWith(const <ZFilter>[]), _category);
  });

  test('CONTRE-TÉMOIN — un onglet sans catégorie porte un socle VIDE', () {
    final tab = ZListTab(
      labelKey: 'all',
      builder: (_) => const SizedBox.shrink(),
    );
    expect(tab.baseFilters, isEmpty);
    expect(tab.filtersWith(const <ZFilter>[_permanent]), <ZFilter>[_permanent]);
  });

  test('copyWith conserve TOUTES les déclarations non remplacées', () {
    final countOf = ValueNotifier<int>(3);
    addTearDown(countOf.dispose);
    final tab = ZListTab.category(
      labelKey: 'open',
      filters: _category,
      icon: Icons.check,
      pageKey: 'k',
      canCreate: false,
      titles: const ZCrudTitles(create: 'c'),
      countOf: countOf,
      defaultItemBuilder: () => 'seed',
      buildList: (context, filters) => const SizedBox.shrink(),
    );

    final wrapped = tab.copyWith(builder: (_) => const Placeholder());

    expect(wrapped.labelKey, 'open');
    expect(wrapped.baseFilters, _category);
    expect(wrapped.icon, Icons.check);
    expect(wrapped.pageKey, 'k');
    expect(wrapped.canCreate, isFalse);
    expect(wrapped.titles?.create, 'c');
    expect(wrapped.countOf, same(countOf));
    expect(wrapped.defaultItemBuilder?.call(), 'seed');
    expect(wrapped.builder!(_FakeContext()), isA<Placeholder>());
  });
}

/// Contexte factice : `ZListTab.category` n'en lit rien, le builder qu'elle
/// compose ne fait que retransmettre ses filtres.
class _FakeContext extends StatelessElement {
  _FakeContext() : super(const _NoWidget());
}

class _NoWidget extends StatelessWidget {
  const _NoWidget();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
