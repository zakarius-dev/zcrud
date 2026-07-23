// CR-IFFD-25 — le champ riche ne se comportait pas comme un champ de formulaire.
//
// §1 Le libellé n'était RENDU nulle part : il n'alimentait que la sémantique et
//    le titre du dialog plein écran. Dans un même formulaire, « Titre »
//    s'affichait au-dessus de son champ et « Contenu » non — une incohérence
//    INTERNE au socle, pas une préférence d'hôte.
// §2 La hauteur venait du REGISTRE, donc d'un sous-arbre : un formulaire portant
//    deux éditeurs de hauteurs différentes n'était pas portable.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

ZFormController _ctl() => ZFormController(
      initialValues: <String, Object?>{'contenu': null},
      visibleFields: const <String>['contenu'],
    );

void main() {
  group('CR-IFFD-25 §1 — le libellé est RENDU', () {
    testWidgets('🔴 le libellé apparaît à l\'écran', (tester) async {
      final c = _ctl();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(ZMarkdownField(
        controller: c,
        field: const ZFieldSpec(
          name: 'contenu',
          type: EditionFieldType.markdown,
          label: 'Contenu',
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Contenu'), findsOneWidget,
          reason: 'le champ riche doit afficher son libellé comme ses voisins');
    });

    testWidgets('🔴 mais il n\'est PAS annoncé deux fois', (tester) async {
      // C'est pour cette raison exacte qu'IFFD s'est délibérément abstenue de
      // contourner app-side : un `Text` posé par l'hôte aurait fait annoncer le
      // libellé DEUX fois, le défaut corrigé sur `ZStudyToolsItemCard`.
      final SemanticsHandle handle = tester.ensureSemantics();
      final c = _ctl();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(ZMarkdownField(
        controller: c,
        field: const ZFieldSpec(
          name: 'contenu',
          type: EditionFieldType.markdown,
          label: 'Contenu',
        ),
      )));
      await tester.pumpAndSettle();

      // Le nœud sémantique du champ porte le libellé ; le `Text` visuel en est
      // EXCLU. On compte donc les nœuds qui l'annoncent, pas les widgets.
      // Libellé EXACT : le nœud de la barre d'outils s'appelle « Contenu
      // toolbar », c'est un AUTRE élément et non une double annonce du champ.
      final Iterable<SemanticsNode> annonces =
          _semanticsWithExactLabel(tester, 'Contenu');
      expect(annonces.length, 1,
          reason: 'un lecteur d\'écran ne doit entendre « Contenu » qu\'UNE fois');
      handle.dispose();
    });

    testWidgets('`showLabel: false` rend la main à l\'hôte', (tester) async {
      final c = _ctl();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(ZMarkdownField(
        controller: c,
        showLabel: false,
        field: const ZFieldSpec(
          name: 'contenu',
          type: EditionFieldType.markdown,
          label: 'Contenu',
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Contenu'), findsNothing);
    });

    testWidgets('un champ SANS libellé n\'affiche pas son nom technique',
        (tester) async {
      // `label` retombe sur `name` pour la sémantique ; l'AFFICHER exposerait un
      // identifiant technique à l'utilisateur.
      final c = _ctl();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(ZMarkdownField(
        controller: c,
        field: const ZFieldSpec(
          name: 'contenu',
          type: EditionFieldType.markdown,
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('contenu'), findsNothing);
    });
  });

  group('CR-IFFD-25 §2 — la hauteur vient de la SPEC', () {
    /// Hauteur maximale contrainte appliquée à l'éditeur.
    double? maxHeight(WidgetTester tester) {
      // Cibler l'ANCÊTRE de l'éditeur : la barre d'outils porte elle aussi un
      // `ConstrainedBox` (`kZMinTapTarget`), qu'un balayage global capterait.
      final Iterable<ConstrainedBox> boxes = tester.widgetList<ConstrainedBox>(
        find.ancestor(
          of: find.byType(QuillEditor),
          matching: find.byType(ConstrainedBox),
        ),
      );
      for (final ConstrainedBox b in boxes) {
        if (b.constraints.maxHeight.isFinite) return b.constraints.maxHeight;
      }
      return null;
    }

    /// Hauteur MINIMALE contrainte — `minLines` n'était gardé par rien tant que
    /// seule la borne max était assertée.
    double? minHeight(WidgetTester tester) {
      final Iterable<ConstrainedBox> boxes = tester.widgetList<ConstrainedBox>(
        find.ancestor(
          of: find.byType(QuillEditor),
          matching: find.byType(ConstrainedBox),
        ),
      );
      for (final ConstrainedBox b in boxes) {
        if (b.constraints.minHeight > 0) return b.constraints.minHeight;
      }
      return null;
    }

    Future<double?> pumpWith(
      WidgetTester tester, {
      ZFieldConfig? config,
      int? registryMin,
      int? registryMax,
    }) async {
      final c = _ctl();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(ZMarkdownField(
        controller: c,
        minLines: registryMin,
        maxLines: registryMax,
        field: ZFieldSpec(
          name: 'contenu',
          type: EditionFieldType.markdown,
          label: 'Contenu',
          config: config,
        ),
      )));
      await tester.pumpAndSettle();
      return maxHeight(tester);
    }

    testWidgets('🔴 deux hauteurs DIFFÉRENTES sont exprimables', (tester) async {
      // Cas réel rencontré (formulaire de matière) : deux éditeurs déclarés
      // 3/5 et 5/10 lignes. Aucune valeur de registre ne satisfaisait les deux.
      final double? petit = await pumpWith(
        tester,
        config: const ZTextConfig(minLines: 3, maxLines: 5),
      );
      final double? grand = await pumpWith(
        tester,
        config: const ZTextConfig(minLines: 5, maxLines: 10),
      );
      expect(petit, isNotNull);
      expect(grand, isNotNull);
      expect(grand! > petit!, isTrue,
          reason: 'la spec doit produire deux hauteurs distinctes');
    });

    testWidgets('🔴 `minLines` vient AUSSI de la spec', (tester) async {
      final c = _ctl();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(ZMarkdownField(
        controller: c,
        minLines: 2,
        maxLines: 20,
        field: const ZFieldSpec(
          name: 'contenu',
          type: EditionFieldType.markdown,
          label: 'Contenu',
          config: ZTextConfig(minLines: 8, maxLines: 20),
        ),
      )));
      await tester.pumpAndSettle();
      final double? min2 = minHeight(tester);

      final c2 = _ctl();
      addTearDown(c2.dispose);
      await tester.pumpWidget(_app(ZMarkdownField(
        controller: c2,
        minLines: 2,
        maxLines: 20,
        field: const ZFieldSpec(
          name: 'contenu',
          type: EditionFieldType.markdown,
          label: 'Contenu',
          config: ZTextConfig(minLines: 2, maxLines: 20),
        ),
      )));
      await tester.pumpAndSettle();
      expect(min2, isNotNull);
      expect(min2! > minHeight(tester)!, isTrue,
          reason: 'la hauteur MINIMALE doit suivre la spec, pas le registre');
    });

    testWidgets('la spec l\'emporte sur le registre', (tester) async {
      final double? registreSeul =
          await pumpWith(tester, registryMin: 3, registryMax: 5);
      final double? specGagne = await pumpWith(
        tester,
        registryMin: 3,
        registryMax: 5,
        config: const ZTextConfig(minLines: 5, maxLines: 10),
      );
      expect(specGagne! > registreSeul!, isTrue);
    });

    testWidgets('sans spec, le REGISTRE reste le défaut (rien ne casse)',
        (tester) async {
      final double? h = await pumpWith(tester, registryMin: 3, registryMax: 5);
      expect(h, isNotNull,
          reason: 'le paramètre de registre doit continuer de fonctionner');
    });

    testWidgets('sans spec NI registre : hauteur intrinsèque (E6-1)',
        (tester) async {
      expect(await pumpWith(tester), isNull);
    });
  });
}

/// Nœuds sémantiques dont le libellé est EXACTEMENT [needle].
Iterable<SemanticsNode> _semanticsWithExactLabel(
  WidgetTester tester,
  String needle,
) {
  final List<SemanticsNode> found = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.label == needle) found.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  // `rootPipelineOwner` ne porte pas l'arbre sémantique du test : mesuré, la
  // garde devient verte à tort. On garde donc l'API dépréciée, sciemment.
  // ignore: deprecated_member_use
  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return found;
}
