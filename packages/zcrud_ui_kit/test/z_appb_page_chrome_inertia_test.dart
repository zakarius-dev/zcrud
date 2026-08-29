/// Inertie ABSOLUE du chrome de page par DÉFAUT — et sous
/// `ZReferenceProfile.neutral`, qui doit lui être indiscernable.
///
/// La signature figée plus bas a été relevée par une sonde jetable **AVANT**
/// le lot « chrome de page » (app-bar teintée par défaut). Elle est comparée
/// par **égalité de chaîne**, pas par `contains` ni par `<=` : un nœud ajouté,
/// un rectangle déplacé d'un dixième de point ou une décoration apparue font
/// rougir la garde.
///
/// Le filtre ne retient que les types que ce lot peut poser ou déplacer
/// (`Container`, `DecoratedBox`, `ColoredBox`, `Column`, `Center`, `SizedBox`)
/// plus les porteurs de chrome (`AppBar`, `SliverAppBar`) et le contenu visible
/// (`Text`, `Icon`). La plomberie interne du SDK (`Focus`, `InkWell`,
/// `MouseRegion`…) est délibérément hors filtre : la geler rendrait la garde
/// rouge à chaque montée de Flutter, donc ignorée.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

String _fmt(double v) => v.toStringAsFixed(1);

String _describe(Element e) {
  final Widget w = e.widget;
  final buf = StringBuffer(w.runtimeType.toString());
  final RenderObject? ro = e.renderObject;
  if (ro is RenderBox && ro.hasSize && ro.attached) {
    final Offset o = ro.localToGlobal(Offset.zero);
    buf.write(
      '@${_fmt(o.dx)},${_fmt(o.dy)}'
      ' ${_fmt(ro.size.width)}x${_fmt(ro.size.height)}',
    );
  }
  if (w is Container) buf.write(' deco=${w.decoration}');
  if (w is DecoratedBox) buf.write(' deco=${w.decoration}');
  if (w is ColoredBox) buf.write(' color=${w.color}');
  if (w is AppBar) {
    buf.write(
      ' fg=${w.foregroundColor} bg=${w.backgroundColor}'
      ' elev=${w.elevation} flex=${w.flexibleSpace?.runtimeType}',
    );
  }
  if (w is SliverAppBar) {
    buf.write(
      ' fg=${w.foregroundColor} bg=${w.backgroundColor}'
      ' flex=${w.flexibleSpace?.runtimeType}',
    );
  }
  if (w is Text) buf.write(' text=${w.data}');
  if (w is Icon) buf.write(' icon=${w.icon?.codePoint}');
  if (w is SizedBox) buf.write(' h=${w.height} w=${w.width}');
  return buf.toString();
}

const Set<String> _keep = <String>{
  'AppBar',
  'SliverAppBar',
  'Container',
  'DecoratedBox',
  'ColoredBox',
  'Column',
  'Center',
  'Text',
  'Icon',
  'SizedBox',
};

String signatureOf(WidgetTester tester, Finder root) {
  final out = <String>[];
  void visit(Element e) {
    if (_keep.contains(e.widget.runtimeType.toString())) out.add(_describe(e));
    e.visitChildren(visit);
  }

  visit(tester.element(root));
  return out.join('\n');
}

/// Enveloppe d'hôte. [profile] nul ⇒ **aucun** `ZcrudScope` monté : c'est le
/// cas d'un hôte qui n'a jamais entendu parler de ce paquet.
Widget host(Widget child, {ZReferenceProfile? profile}) {
  final Widget app = MaterialApp(home: child, debugShowCheckedModeBanner: false);
  if (profile == null) return app;
  return ZcrudScope(theme: ZcrudTheme(referenceProfile: profile), child: app);
}

// ── Signatures relevées AVANT le lot (sonde jetable, écran 480×800) ─────────

const String _avantTitreSeul =
    'AppBar@0.0,0.0 480.0x56.0 fg=null bg=null elev=null flex=null\n'
    'Text@16.0,14.0 110.0x28.0 text=Alpha';

const String _avantTitreActions =
    'AppBar@0.0,0.0 480.0x56.0 fg=null bg=null elev=null flex=null\n'
    'Text@16.0,14.0 110.0x28.0 text=Alpha\n'
    'Icon@444.0,16.0 24.0x24.0 icon=57415\n'
    'SizedBox@444.0,16.0 24.0x24.0 h=24.0 w=24.0\n'
    'Center@444.0,16.0 24.0x24.0';

const String _avantAppBarNue =
    'AppBar@0.0,0.0 480.0x56.0 fg=null bg=null elev=null flex=null\n'
    'Text@16.0,14.0 110.0x28.0 text=Alpha';

const String _avantSliver =
    'SliverAppBar fg=null bg=null flex=null\n'
    'AppBar@0.0,0.0 480.0x56.0 fg=null bg=null elev=0.0 flex=null\n'
    'Text@16.0,14.0 110.0x28.0 text=Alpha';

const List<ZAppBarAction> _actions = <ZAppBarAction>[
  ZAppBarAction(icon: Icons.add, semanticLabel: 'Ajouter', tooltip: 'Ajouter'),
];

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
  }

  group('Apparence B — inertie absolue sous ZReferenceProfile.neutral', () {
    testWidgets('ZPageScaffold, titre seul : arbre identique à avant le lot', (
      tester,
    ) async {
      await pumpAt(
        tester,
        host(
          const ZPageScaffold(title: 'Alpha'),
          profile: ZReferenceProfile.neutral,
        ),
      );
      expect(
        signatureOf(tester, find.byType(AppBar)),
        _avantTitreSeul,
        reason:
            'Sous le profil neutre, le chrome de page doit être STRICTEMENT '
            'celui d\'avant le lot.',
      );
    });

    testWidgets('ZPageScaffold, titre + action : arbre identique', (
      tester,
    ) async {
      await pumpAt(
        tester,
        host(
          const ZPageScaffold(title: 'Alpha', actions: _actions),
          profile: ZReferenceProfile.neutral,
        ),
      );
      expect(signatureOf(tester, find.byType(AppBar)), _avantTitreActions);
    });

    testWidgets('ZSearchableAppBar nue : arbre identique', (tester) async {
      await pumpAt(
        tester,
        host(
          const Scaffold(appBar: ZSearchableAppBar(title: 'Alpha')),
          profile: ZReferenceProfile.neutral,
        ),
      );
      expect(signatureOf(tester, find.byType(AppBar)), _avantAppBarNue);
    });

    testWidgets('mode sliver : arbre identique', (tester) async {
      await pumpAt(
        tester,
        host(
          const ZPageScaffold(
            title: 'Alpha',
            mode: ZPageAppBarMode.floatingPinned,
            body: SizedBox(height: 2000),
          ),
          profile: ZReferenceProfile.neutral,
        ),
      );
      expect(signatureOf(tester, find.byType(SliverAppBar)), _avantSliver);
    });

    testWidgets(
      'gradientKey vide : arbre identique MÊME sous le profil legacy '
      '(échappatoire par site)',
      (tester) async {
        await pumpAt(
          tester,
          host(
            const ZPageScaffold(title: 'Alpha', gradientKey: ''),
            profile: ZReferenceProfile.legacy,
          ),
        );
        expect(signatureOf(tester, find.byType(AppBar)), _avantTitreSeul);
      },
    );

    testWidgets(
      'titre WIDGET sans signatureKey : aucune identité dérivable, arbre '
      'identique MÊME sous legacy (aucun ZcrudScope monté)',
      (tester) async {
        await pumpAt(
          tester,
          host(const Scaffold(appBar: ZSearchableAppBar(title: Text('Alpha')))),
        );
        expect(signatureOf(tester, find.byType(AppBar)), _avantAppBarNue);
      },
    );

    testWidgets('signatureKey VIDE : aucune identité, arbre identique', (
      tester,
    ) async {
      await pumpAt(
        tester,
        host(
          const Scaffold(
            appBar: ZSearchableAppBar(title: Text('Alpha'), signatureKey: ''),
          ),
        ),
      );
      expect(signatureOf(tester, find.byType(AppBar)), _avantAppBarNue);
    });

    testWidgets(
      'CONTRE-PREUVE : sous le profil legacy EXPLICITE, la MÊME page rend '
      'une signature DIFFÉRENTE — la garde ne serait pas vacante',
      (tester) async {
        await pumpAt(
          tester,
          host(
            const ZPageScaffold(title: 'Alpha'),
            profile: ZReferenceProfile.legacy,
          ),
        );
        expect(
          signatureOf(tester, find.byType(AppBar)),
          isNot(_avantTitreSeul),
          reason:
              'Si legacy rendait la même chose que neutral, les tests '
              'd\'inertie ci-dessus ne mesureraient rien.',
        );
      },
    );
  });

  group('Apparence B — le DÉFAUT du socle est le rendu d\'avant le lot', () {
    // Le profil n'est plus déclaré nulle part : c'est le cas de l'hôte qui n'a
    // rien fait. Mesurer les DEUX formes muettes — aucun `ZcrudScope` et un
    // `ZcrudScope` sans jeton de profil — parce qu'un repli qui divergerait
    // entre les deux ne se verrait dans aucune des deux prises isolément.
    testWidgets('🔴 aucun ZcrudScope : chrome STRICTEMENT celui d\'avant',
        (tester) async {
      await pumpAt(tester, host(const ZPageScaffold(title: 'Alpha')));
      expect(
        signatureOf(tester, find.byType(AppBar)),
        _avantTitreSeul,
        reason: '🔴 un hôte qui n\'a rien déclaré reçoit le lavis '
            'd\'identité : le défaut du socle a dérivé vers `legacy`',
      );
    });

    testWidgets('🔴 ZcrudScope MUET (aucun jeton de profil) : idem',
        (tester) async {
      await pumpAt(
        tester,
        ZcrudScope(
          theme: const ZcrudTheme(),
          child: const MaterialApp(
            home: ZPageScaffold(title: 'Alpha'),
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
      expect(signatureOf(tester, find.byType(AppBar)), _avantTitreSeul);
    });

    testWidgets('🔴 le mode sliver suit le même défaut', (tester) async {
      await pumpAt(
        tester,
        host(
          const ZPageScaffold(
            title: 'Alpha',
            mode: ZPageAppBarMode.floatingPinned,
            body: SizedBox(height: 2000),
          ),
        ),
      );
      expect(signatureOf(tester, find.byType(SliverAppBar)), _avantSliver);
    });

    testWidgets('🔴 ZSearchableAppBar nue suit le même défaut', (tester) async {
      await pumpAt(
        tester,
        host(const Scaffold(appBar: ZSearchableAppBar(title: 'Alpha'))),
      );
      expect(signatureOf(tester, find.byType(AppBar)), _avantAppBarNue);
    });
  });
}
