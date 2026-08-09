// CR-DODLP « Gap 0 » — seam de rendu du SOUS-TITRE d'étape (`ZRichTextRenderer`).
//
// Le legacy DODLP rend le sous-titre en Markdown via `GptMarkdown` importé dans
// le widget (`dynamic_stepper.dart` l. 406 et l. 790). AD-1 interdit cette arête
// à `zcrud_core` : le moteur est injecté par l'hôte via `ZcrudScope`.
//
// Ce que ces gardes affirment, et pourquoi aucune n'est vacante :
//  * l'HÔTE PASSIF (aucun renderer) rend EXACTEMENT ce qu'il rendait — la garde
//    interroge l'arbre de widgets, pas la présence du seam ;
//  * les deux voies (simple / riche) annoncent EXACTEMENT UNE FOIS — on compte
//    les nœuds sémantiques portant le libellé, ce qui rougit aussi bien sur une
//    annonce PERDUE que sur une annonce DOUBLÉE ;
//  * un renderer qui LÈVE ne casse rien (AD-10) ;
//  * `showSubtitles` gouverne les DEUX modes, dans les DEUX sens.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Renderer d'hôte : marque le rendu par un widget identifiable, et porte
/// lui-même son propre `Text` (donc sa propre sémantique) — c'est la situation
/// qui DOUBLERAIT l'annonce si le socle superposait naïvement un `Semantics`.
class _FakeRichRenderer extends ZRichTextRenderer {
  const _FakeRichRenderer();

  @override
  Widget? build(BuildContext context, String source, {TextStyle? baseStyle}) =>
      Container(
        key: const ValueKey<String>('rich'),
        child: Text('RICHE:$source', style: baseStyle),
      );
}

/// Renderer qui **décline** (contrat propre) ⇒ repli texte simple.
class _DecliningRenderer extends ZRichTextRenderer {
  const _DecliningRenderer();

  @override
  Widget? build(BuildContext context, String source, {TextStyle? baseStyle}) =>
      null;
}

/// Renderer **fautif** ⇒ AD-10 : repli, jamais d'exception propagée.
class _ThrowingRenderer extends ZRichTextRenderer {
  const _ThrowingRenderer();

  @override
  Widget? build(BuildContext context, String source, {TextStyle? baseStyle}) =>
      throw StateError('moteur de rendu cassé');
}

/// Renderer qui ne produit **aucune sémantique** ⇒ l'annonce ne doit pas être
/// perdue pour autant.
class _MuteRenderer extends ZRichTextRenderer {
  const _MuteRenderer();

  @override
  Widget? build(BuildContext context, String source, {TextStyle? baseStyle}) =>
      const SizedBox(width: 10, height: 10);
}

const String _sub = 'Informations personnelles';

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _host({
  required ZFormController controller,
  ZRichTextRenderer? renderer,
  required ZStepperConfig config,
  Widget? subtitleWidget,
  String? subtitle = _sub,
}) {
  final Widget stepper = ZStepperEdition(
    controller: controller,
    fields: const <ZFieldSpec>[
      ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
    ],
    steps: <ZEditionStep>[
      ZEditionStep(
        title: 'Identité',
        subtitle: subtitle,
        subtitleWidget: subtitleWidget,
        fields: const <String>['a'],
      ),
    ],
    config: config,
  );
  return MaterialApp(
    home: Scaffold(
      body: renderer == null
          ? stepper
          : ZcrudScope(richTextRenderer: renderer, child: stepper),
    ),
  );
}

ZFormController _controller() => ZFormController(
      initialValues: const <String, Object?>{'a': ''},
      visibleFields: const <String>['a'],
    );

/// Compte les **OCCURRENCES** de [needle] dans l'ensemble des libellés
/// sémantiques de l'arbre.
///
/// 🔴 Des OCCURRENCES, et non des NŒUDS. Mesuré : `Semantics(label:)` posé sur
/// un rendu qui porte déjà son texte ne crée PAS un second nœud — il **fusionne**
/// dans le même, dont le libellé contient alors la phrase DEUX FOIS. Une garde
/// qui compte les nœuds reste verte sur ce doublement précis : c'est exactement
/// le doublement que ce dépôt a déjà rencontré. Compter les occurrences rougit
/// sur l'annonce perdue (0) COMME sur l'annonce doublée (2).
int _semanticsWith(WidgetTester tester, String needle) {
  int n = 0;
  void walk(SemanticsNode node) {
    n += needle.allMatches(node.label).length;
    node.visitChildren((SemanticsNode c) {
      walk(c);
      return true;
    });
  }

  walk(tester.binding.rootElement!
      .findRenderObject()!
      .debugSemantics!);
  return n;
}

void main() {
  for (final ZStepperConfig base in <ZStepperConfig>[
    const ZStepperConfig(showSubtitles: true),
    ZStepperConfig.allStepsVertical,
  ]) {
    final String mode =
        base.showAllSteps ? 'mode « tout affiché »' : 'mode paginé';

    group('$mode — seam de sous-titre', () {
      testWidgets('HÔTE PASSIF : sous-titre en Text simple, aucun rendu riche',
          (tester) async {
        _bigView(tester);
        final ZFormController c = _controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(_host(controller: c, config: base));
        await tester.pumpAndSettle();

        expect(find.text(_sub), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('rich')), findsNothing);
        expect(find.text('RICHE:$_sub'), findsNothing);
      });

      testWidgets('renderer branché : le rendu RICHE remplace le texte simple',
          (tester) async {
        _bigView(tester);
        final ZFormController c = _controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(_host(
          controller: c,
          config: base,
          renderer: const _FakeRichRenderer(),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('rich')), findsOneWidget);
        expect(find.text('RICHE:$_sub'), findsOneWidget,
            reason: 'la CHAÎNE est passée au renderer, pas un widget à déballer');
        expect(find.text(_sub), findsNothing,
            reason: 'le repli texte simple ne doit pas coexister avec le riche');
      });

      testWidgets('renderer qui DÉCLINE (null) : repli texte simple',
          (tester) async {
        _bigView(tester);
        final ZFormController c = _controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(_host(
          controller: c,
          config: base,
          renderer: const _DecliningRenderer(),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(_sub), findsOneWidget);
      });

      testWidgets('AD-10 — renderer qui LÈVE : repli, jamais d\'exception',
          (tester) async {
        _bigView(tester);
        final ZFormController c = _controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(_host(
          controller: c,
          config: base,
          renderer: const _ThrowingRenderer(),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'un seam d\'hôte fautif ne fait pas tomber le formulaire');
        expect(find.text(_sub), findsOneWidget, reason: 'repli texte simple');
      });

      testWidgets(
          'AD-13 — EXACTEMENT une annonce, voie simple comme voie riche',
          (tester) async {
        _bigView(tester);
        final SemanticsHandle handle = tester.ensureSemantics();

        // Voie simple.
        final ZFormController c1 = _controller();
        addTearDown(c1.dispose);
        await tester.pumpWidget(_host(controller: c1, config: base));
        await tester.pumpAndSettle();
        expect(_semanticsWith(tester, _sub), 1,
            reason: 'voie SIMPLE : ni perdue, ni doublée');

        // Voie riche — le renderer porte DÉJÀ son propre texte.
        final ZFormController c2 = _controller();
        addTearDown(c2.dispose);
        await tester.pumpWidget(_host(
          controller: c2,
          config: base,
          renderer: const _FakeRichRenderer(),
        ));
        await tester.pumpAndSettle();
        expect(_semanticsWith(tester, _sub), 1,
            reason: 'voie RICHE : le rendu porte son texte — l\'annonce ne doit '
                'PAS être doublée');

        // Voie riche MUETTE — le renderer ne produit aucune sémantique.
        final ZFormController c3 = _controller();
        addTearDown(c3.dispose);
        await tester.pumpWidget(_host(
          controller: c3,
          config: base,
          renderer: const _MuteRenderer(),
        ));
        await tester.pumpAndSettle();
        expect(_semanticsWith(tester, _sub), 1,
            reason: 'voie RICHE MUETTE : l\'annonce ne doit PAS être perdue');

        // Voie WIDGET FOURNI — l'hôte porte sa propre annonce ; le socle n'a
        // aucune chaîne à annoncer et ne doit RIEN surajouter.
        final ZFormController c4 = _controller();
        addTearDown(c4.dispose);
        await tester.pumpWidget(_host(
          controller: c4,
          config: base,
          subtitle: null,
          subtitleWidget: Semantics(
            label: 'ANNONCE HOTE',
            child: const SizedBox(width: 10, height: 10),
          ),
        ));
        await tester.pumpAndSettle();
        expect(_semanticsWith(tester, 'ANNONCE HOTE'), 1,
            reason: 'voie WIDGET : l\'annonce de l\'hôte passe UNE fois, '
                'ni perdue ni doublée');
        handle.dispose();
      });

      testWidgets(
          'VOIE WIDGET : rendu TEL QUE REÇU, le seam n\'est PAS consulté',
          (tester) async {
        _bigView(tester);
        final ZFormController c = _controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(_host(
          controller: c,
          config: base,
          // Un renderer est branché : s'il était consulté, on verrait 'RICHE:'.
          renderer: const _FakeRichRenderer(),
          subtitle: null,
          subtitleWidget: const Icon(Icons.info, key: ValueKey<String>('given')),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('given')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('rich')), findsNothing,
            reason: 'un widget fourni ne passe JAMAIS par le seam de rendu');
      });

      testWidgets(
          'les DEUX entrées fournies : le WIDGET prime (patron label/labelText)',
          (tester) async {
        _bigView(tester);
        final ZFormController c = _controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(_host(
          controller: c,
          config: base,
          renderer: const _FakeRichRenderer(),
          subtitle: _sub,
          subtitleWidget: const Icon(Icons.info, key: ValueKey<String>('given')),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('given')), findsOneWidget);
        expect(find.text(_sub), findsNothing,
            reason: 'la chaîne ne doit PAS coexister avec le widget');
        expect(find.text('RICHE:$_sub'), findsNothing);
      });

      testWidgets('showSubtitles gouverne AUSSI le widget fourni',
          (tester) async {
        _bigView(tester);
        final ZFormController c = _controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(_host(
          controller: c,
          config: base.copyWith(showSubtitles: false),
          subtitle: null,
          subtitleWidget: const Icon(Icons.info, key: ValueKey<String>('given')),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('given')), findsNothing,
            reason: 'le drapeau dit « cette présentation montre des '
                'sous-titres » — il ne distingue pas le TYPE de l\'entrée');
      });

      testWidgets('showSubtitles: false ⇒ aucun sous-titre, riche ou non',
          (tester) async {
        _bigView(tester);
        final ZStepperConfig off = base.copyWith(showSubtitles: false);
        for (final ZRichTextRenderer? r
            in <ZRichTextRenderer?>[null, const _FakeRichRenderer()]) {
          final ZFormController c = _controller();
          addTearDown(c.dispose);
          await tester.pumpWidget(
              _host(controller: c, config: off, renderer: r));
          await tester.pumpAndSettle();
          expect(find.text(_sub), findsNothing, reason: 'renderer=$r');
          expect(find.text('RICHE:$_sub'), findsNothing, reason: 'renderer=$r');
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    });
  }

  testWidgets('ZEditionStep.subtitle est une String (aucun déballage de widget)',
      (tester) async {
    // Garde de CONTRAT : la donnée reste une chaîne de bout en bout — c'est ce
    // qui fait disparaître le `(step.subtitle as Text).data` du legacy.
    const ZEditionStep s = ZEditionStep(
      title: 'T',
      subtitle: _sub,
      fields: <String>['a'],
    );
    expect(s.subtitle, isA<String>());
    expect(s.subtitle, _sub);
  });
}
