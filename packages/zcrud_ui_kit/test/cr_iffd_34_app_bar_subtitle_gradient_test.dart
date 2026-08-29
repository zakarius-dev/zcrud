/// CR-IFFD-34 — sous-titre d'app-bar + dégradé d'identité (`ZSearchableAppBar`,
/// `ZPageScaffold`, `ZPageShellBody`).
///
/// Deux invariants gouvernent ce fichier :
/// * **défaut inchangé** : slots nuls ⇒ l'arbre est STRICTEMENT celui d'avant la
///   CR (titre nu, aucun `flexibleSpace`, aucun `foregroundColor`) ;
/// * **neutralité de la clé EXPLICITE** : quand `gradientKey` est déclarée, le
///   dégradé n'existe QUE si l'hôte a injecté un `ZcrudScope.gradientResolver`
///   ET que celui-ci rend une spec pour cette clé-là. Aucun repli dérivé n'est
///   réintroduit sur ce chemin.
///
/// ⚠️ Ce second invariant ne vaut PLUS pour une clé **nulle**. Le chrome de
/// page dérive alors une identité du titre (ou de `signatureKey`) et résout
/// `zcrud.signature.<identité>`, qui porte une valeur de référence sous le
/// profil `legacy`. Le seam de l'hôte reste consulté en premier — dans les deux
/// profils — et `ZReferenceProfile.neutral` ramène le rendu à l'état d'avant.
/// Les tests de ce groupe distinguent explicitement les deux chemins.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Clés RÉELLEMENT reçues par le résolveur (dans l'ordre) : sans ce journal, on
/// ne pourrait pas distinguer « resolver non appelé » de « resolver appelé avec
/// une clé inattendue ».
final List<String> _clesRecues = <String>[];

const Color _kStart = Color(0xFF102030);
const Color _kEnd = Color(0xFF405060);
const Color _kOn = Color(0xFFFEDCBA);

/// Résolveur hôte témoin : rend une spec pour `'dossier-42'`, `null` pour toute
/// autre clé (c'est la façon dont un hôte dit « accent uni pour celle-ci »).
ZGradientSpec? _resolver(ColorScheme scheme, String key) {
  _clesRecues.add(key);
  if (key != 'dossier-42') return null;
  return const ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[_kStart, _kEnd]),
    onGradient: _kOn,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ZGradientResolver? resolver,
}) async {
  _clesRecues.clear();
  await tester.pumpWidget(
    MaterialApp(
      home: ZcrudScope(gradientResolver: resolver, child: child),
    ),
  );
  await tester.pumpAndSettle();
}

AppBar _appBar(WidgetTester tester) => tester.widget<AppBar>(
  find.byType(AppBar).first,
);

SliverAppBar _sliverAppBar(WidgetTester tester) =>
    tester.widget<SliverAppBar>(find.byType(SliverAppBar).first);

void main() {
  group('G1/G2 — slot `subtitle` (ZSearchableAppBar)', () {
    testWidgets('null ⇒ titre NU : aucune Column interposée', (tester) async {
      await _pump(
        tester,
        const Scaffold(appBar: ZSearchableAppBar(title: 'Titre')),
      );
      // Garde structurelle : le slot `title` de l'AppBar est le titre lui-même,
      // pas un bloc. Emballer inconditionnellement dans une Column la ferait
      // rougir (c'est l'injection R3-1).
      expect(_appBar(tester).title, isA<Text>());
      expect(find.text('SOUS-TITRE'), findsNothing);
    });

    testWidgets('fourni ⇒ rendu ET annonçable par un lecteur d\'écran', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        const Scaffold(
          appBar: ZSearchableAppBar(
            title: 'Titre',
            subtitle: Text('SOUS-TITRE'),
          ),
        ),
      );
      expect(find.text('SOUS-TITRE'), findsOneWidget);
      // Présence dans l'arbre ≠ annonçable : on exige un NŒUD SÉMANTIQUE qui
      // porte le sous-titre. MESURÉ : `AppBar` fusionne la zone titre en UN
      // nœud `isHeader`/`namesRoute` dont le label vaut « Titre\nSOUS-TITRE » —
      // le lecteur d'écran annonce donc les deux. D'où la recherche par motif
      // (une égalité stricte échouerait sur la fusion, sans rien prouver).
      expect(find.bySemanticsLabel(RegExp('SOUS-TITRE')), findsOneWidget);
      expect(_appBar(tester).title, isA<Column>());
      // Aucun débordement de la zone titre (56 dp) : le bloc doit tenir.
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('mode recherche ⇒ sous-titre ABSENT de l\'arbre', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          appBar: ZSearchableAppBar(
            title: 'Titre',
            subtitle: const Text('SOUS-TITRE'),
            search: ZAppBarSearchConfig(onQueryChanged: (_) {}),
          ),
        ),
      );
      expect(find.text('SOUS-TITRE'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('SOUS-TITRE'), findsNothing);
    });
  });

  group('G3 — dégradé d\'identité : neutralité par défaut', () {
    testWidgets('AUCUN resolver hôte ⇒ app-bar strictement inchangée', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          appBar: ZSearchableAppBar(title: 'Titre', gradientKey: 'dossier-42'),
        ),
      );
      final AppBar bar = _appBar(tester);
      expect(bar.flexibleSpace, isNull);
      expect(bar.foregroundColor, isNull);
    });

    testWidgets(
      'clé nulle : le resolver est consulté sur la clé DÉRIVÉE du titre, et '
      'sur elle seule',
      (tester) async {
        await _pump(
          tester,
          const Scaffold(appBar: ZSearchableAppBar(title: 'Titre')),
          resolver: _resolver,
        );
        // Le chrome d'identité par défaut consulte le seam AVANT la
        // référence: l'hôte garde donc la main, y compris sans clé explicite.
        expect(_clesRecues, <String>['zcrud.signature.Titre']);
      },
    );

    testWidgets(
      'clé nulle + titre WIDGET : aucune identité dérivable ⇒ resolver JAMAIS '
      'appelé, app-bar strictement inchangée',
      (tester) async {
        await _pump(
          tester,
          const Scaffold(appBar: ZSearchableAppBar(title: Text('Titre'))),
          resolver: _resolver,
        );
        expect(_clesRecues, isEmpty);
        expect(_appBar(tester).flexibleSpace, isNull);
        expect(_appBar(tester).foregroundColor, isNull);
      },
    );

    testWidgets(
      'clé nulle + profil neutre : le seam reste consulté (il prime dans les '
      'DEUX profils), mais son refus laisse l\'app-bar inchangée',
      (tester) async {
        _clesRecues.clear();
        await tester.pumpWidget(
          MaterialApp(
            home: ZcrudScope(
              gradientResolver: _resolver,
              theme: const ZcrudTheme(
                referenceProfile: ZReferenceProfile.neutral,
              ),
              child: const Scaffold(
                appBar: ZSearchableAppBar(title: 'Titre'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_clesRecues, <String>['zcrud.signature.Titre']);
        expect(_appBar(tester).flexibleSpace, isNull);
        expect(_appBar(tester).foregroundColor, isNull);
      },
    );

    testWidgets('resolver injecté, clé VIDE ⇒ jamais appelé', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          appBar: ZSearchableAppBar(title: 'Titre', gradientKey: ''),
        ),
        resolver: _resolver,
      );
      expect(_clesRecues, isEmpty);
      expect(_appBar(tester).flexibleSpace, isNull);
    });

    testWidgets('resolver rendant `null` ⇒ décision de l\'hôte RESPECTÉE', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          appBar: ZSearchableAppBar(title: 'Titre', gradientKey: 'inconnu'),
        ),
        resolver: _resolver,
      );
      expect(_clesRecues, <String>['inconnu']);
      final AppBar bar = _appBar(tester);
      expect(bar.flexibleSpace, isNull);
      expect(bar.foregroundColor, isNull);
    });
  });

  group('G4 — dégradé appliqué quand l\'hôte le fournit', () {
    testWidgets('fond dégradé + premier plan contrasté (mode fixe)', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          appBar: ZSearchableAppBar(title: 'Titre', gradientKey: 'dossier-42'),
        ),
        resolver: _resolver,
      );
      expect(_clesRecues, contains('dossier-42'));
      final AppBar bar = _appBar(tester);
      expect(bar.foregroundColor, _kOn);
      final Container space = bar.flexibleSpace! as Container;
      final BoxDecoration deco = space.decoration! as BoxDecoration;
      expect(
        (deco.gradient! as LinearGradient).colors,
        <Color>[_kStart, _kEnd],
      );
    });
  });

  group('G5 — propagation par ZPageScaffold (fixe ET sliver)', () {
    testWidgets('mode fixe : subtitle + gradient traversent le shell', (
      tester,
    ) async {
      await _pump(
        tester,
        const ZPageScaffold(
          title: 'Titre',
          subtitle: Text('SOUS-TITRE'),
          gradientKey: 'dossier-42',
        ),
        resolver: _resolver,
      );
      expect(find.text('SOUS-TITRE'), findsOneWidget);
      expect(_appBar(tester).foregroundColor, _kOn);
      expect(_appBar(tester).flexibleSpace, isA<Container>());
    });

    testWidgets('mode sliver : subtitle + gradient sur le SliverAppBar', (
      tester,
    ) async {
      await _pump(
        tester,
        const ZPageScaffold(
          title: 'Titre',
          subtitle: Text('SOUS-TITRE'),
          gradientKey: 'dossier-42',
          mode: ZPageAppBarMode.pinned,
        ),
        resolver: _resolver,
      );
      expect(find.text('SOUS-TITRE'), findsOneWidget);
      final SliverAppBar bar = _sliverAppBar(tester);
      expect(bar.foregroundColor, _kOn);
      expect(bar.flexibleSpace, isA<Container>());
      expect(bar.title, isA<Column>());
    });

    testWidgets('mode sliver SANS resolver ⇒ sliver inchangé', (tester) async {
      await _pump(
        tester,
        const ZPageScaffold(
          title: 'Titre',
          gradientKey: 'dossier-42',
          mode: ZPageAppBarMode.pinned,
        ),
      );
      final SliverAppBar bar = _sliverAppBar(tester);
      expect(bar.flexibleSpace, isNull);
      expect(bar.foregroundColor, isNull);
      expect(bar.title, isA<Text>());
    });

    testWidgets('ZPageShellBody expose les mêmes slots', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: ZPageShellBody(
            title: 'Titre',
            subtitle: Text('SOUS-TITRE'),
            gradientKey: 'dossier-42',
          ),
        ),
        resolver: _resolver,
      );
      expect(find.text('SOUS-TITRE'), findsOneWidget);
      expect(_sliverAppBar(tester).foregroundColor, _kOn);
    });
  });
}
