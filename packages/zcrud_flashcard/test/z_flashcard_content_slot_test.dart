/// Slot de rendu de contenu de carte — contrat + défaut (SU-1, AC4 — AD-40).
///
/// PROUVE : (1) sans injection, un contenu **riche** s'affiche en **texte brut**
/// (le défaut n'atteint AUCUN rendu riche) ; (2) le tear-off du défaut et un
/// builder d'app satisfont indifféremment le typedef — la **FORME** du contrat
/// d'injection ; (3) le défaut est exposé en tear-off **statique**
/// const-compatible (AD-2/SM-1) ; (4) le défaut est **thématisé** (aucune
/// couleur en dur — FR-26/NFR-SU4), repli inclus.
///
/// ⚠️ **NE prouve PAS** — et ne le peut pas en su-1 : que le slot est réellement
/// **branché** (pas décoratif), et qu'aucune closure n'est réallouée à chaque
/// build. Les deux sont des propriétés du **call-site**, et su-1 n'en livre
/// aucun (le câblage est le périmètre de **su-2**, qui doit porter ces preuves).
///
/// Injection R3-I4 : rendre le riche en dur dans le défaut ⇒ la garde de source
/// `z_flashcard_rich_type_leak_test.dart` ROUGIT (Quill dans une signature).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: ZcrudScope(child: Scaffold(body: Center(child: child))),
    );

/// Contenu **riche** (markdown + LaTeX) : le défaut doit le rendre VERBATIM,
/// sans jamais l'interpréter.
const String _richContent = r'**gras** et $\frac{a}{b}$';

void main() {
  group('AC4 — défaut : texte BRUT, aucun rendu riche (AD-40)', () {
    testWidgets('un contenu riche s\'affiche VERBATIM, non interprété',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const ZFlashcardDefaultContent(content: _richContent)),
      );

      // Le markdown/LaTeX n'est PAS interprété : le texte source apparaît tel
      // quel. Un défaut qui rendrait du riche ne trouverait PAS cette chaîne.
      expect(find.text(_richContent), findsOneWidget);

      // Et le rendu est bien un simple `Text` (aucun widget d'éditeur riche).
      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(texts, hasLength(1),
          reason: 'le défaut doit rendre UN Text nu, rien de plus');
    });

    testWidgets('le sous-arbre du défaut ne contient AUCUN widget Quill',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const ZFlashcardDefaultContent(content: _richContent)),
      );

      // Preuve structurelle : on inspecte le type de CHAQUE widget du
      // sous-arbre. Aucun ne doit provenir de flutter_quill / flutter_math.
      final types = <String>[
        for (final w in tester.allWidgets) w.runtimeType.toString(),
      ];
      expect(types, isNotEmpty, reason: 'arbre vide — rien inspecté (R12)');

      for (final type in types) {
        expect(type.toLowerCase().contains('quill'), isFalse,
            reason: 'widget Quill « $type » atteint par le chemin PAR DÉFAUT — '
                'le rendu riche doit être une INJECTION (AD-40)');
        expect(type.toLowerCase().contains('math'), isFalse,
            reason: 'widget math « $type » atteint par le chemin PAR DÉFAUT');
      }
    });

    testWidgets('un contenu vide ne casse pas le défaut (défensif, AD-10)',
        (tester) async {
      await tester.pumpWidget(_wrap(const ZFlashcardDefaultContent(content: '')));
      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  // **FORME du contrat d'injection — PAS son branchement effectif.**
  //
  // ⚠️ Portée honnête (R3) : ce groupe prouve que le **typedef** accepte
  // indifféremment le tear-off du défaut et un builder d'app hôte, et que ces
  // derniers rendent bien ce qu'ils promettent. Il ne prouve **PAS** qu'un
  // widget de production arbitre entre « builder injecté » et « défaut » — et
  // il ne le peut pas : **aucun consommateur de production du slot n'existe en
  // su-1** (grep négatif : `ZFlashcardContentBuilder` n'a que sa déclaration et
  // sa dartdoc en `lib/`). su-1 livre volontairement *le contrat + le défaut,
  // rien de plus* ; le câblage appartient à **su-2**.
  //
  // 👉 **La preuve du branchement effectif incombe à su-2** : c'est là
  // qu'existera le call-site (`builder ?? ZFlashcardDefaultContent.builder`) et
  // que le discriminant « slot décoratif » — un `contentBuilder` accepté puis
  // jamais lu — deviendra falsifiable. Ne pas compter ce groupe comme cette
  // preuve, et ne pas fabriquer ici un faux consommateur de production dans le
  // seul but de verdir un test.
  group('AC4 — FORME du contrat d\'injection (branchement effectif : su-2)', () {
    testWidgets(
      'le typedef accepte le tear-off du défaut ET un builder d\'app : les deux '
      'sont interchangeables (contrat honoré)',
      (tester) async {
        // Compile-time : si le tear-off ne satisfaisait pas le typedef, ceci ne
        // compilerait pas. Le contrat est donc vérifié par le type-checker.
        const ZFlashcardContentBuilder defaultBuilder =
            ZFlashcardDefaultContent.builder;
        Widget appBuilder(BuildContext context, String content) =>
            Text('APP:$content');

        await tester.pumpWidget(_wrap(
          Column(
            children: <Widget>[
              Builder(builder: (c) => defaultBuilder(c, 'defaut')),
              Builder(builder: (c) => appBuilder(c, 'app')),
            ],
          ),
        ));

        expect(find.text('defaut'), findsOneWidget);
        expect(find.text('APP:app'), findsOneWidget);
      },
    );
  });

  group('AC4 — le défaut est exposé en tear-off STATIQUE (AD-2/SM-1)', () {
    test('le défaut est lisible en contexte `const` et se canonicalise', () {
      // Portée honnête : `identical` sur deux tear-offs `const` d'une même
      // méthode statique est vrai PAR DÉFINITION du langage — l'assertion
      // runtime ne peut pas échouer. Le pouvoir réel de ce test est À LA
      // COMPILATION : si `builder` devenait un getter renvoyant une closure, le
      // `const` ci-dessous CESSERAIT DE COMPILER. C'est cette forme-là qu'on
      // verrouille, et rien de plus.
      //
      // La vraie garde SM-1 (« aucune closure réallouée à chaque build ») est
      // une propriété du CALL-SITE : elle appartient à su-2, où le widget
      // résoudra `builder ?? ZFlashcardDefaultContent.builder` et où deux
      // `pump()` successifs pourront comparer l'identité effectivement résolue.
      const ZFlashcardContentBuilder a = ZFlashcardDefaultContent.builder;
      const ZFlashcardContentBuilder b = ZFlashcardDefaultContent.builder;
      expect(identical(a, b), isTrue,
          reason: 'le défaut doit rester un tear-off STATIQUE const-compatible');
    });
  });

  group('AC4 — défaut THÉMATISÉ, aucune couleur en dur (FR-26/NFR-SU4)', () {
    testWidgets('la couleur du texte suit ZcrudTheme.labelColor injecté',
        (tester) async {
      const injectedColor = Color(0xFF00FF00);
      await tester.pumpWidget(MaterialApp(
        home: ZcrudScope(
          theme: const ZcrudTheme(labelColor: injectedColor),
          child: const Scaffold(
            body: ZFlashcardDefaultContent(content: 'bonjour'),
          ),
        ),
      ));

      final text = tester.widget<Text>(find.byType(Text));
      // Une couleur en dur ne serait PAS surchargeable ⇒ ce test ROUGIT.
      expect(text.style?.color, injectedColor,
          reason: 'le défaut doit lire ZcrudTheme (jamais une couleur en dur)');
    });

    testWidgets(
        'sans ZcrudTheme injecté, la couleur vient du ThemeData ambiant via '
        'ZcrudTheme.fallback (jamais un Color brut)', (tester) async {
      // Portée honnête : sans `ZcrudScope(theme:)`, `ZcrudTheme.of` retombe sur
      // `ZcrudTheme.fallback(Theme.of(context))`, qui remplit TOUJOURS
      // `labelColor` (= `textTheme.bodyMedium.color`). La branche droite du `??`
      // du widget n'est donc PAS empruntée ici — c'est le test suivant qui
      // l'exerce. Comparer à `colorScheme.onSurface` (comme le faisait la
      // version précédente) ne passait que par COÏNCIDENCE : dans le ThemeData
      // par défaut `bodyMedium.color == onSurface`, mais un hôte qui adoucit sa
      // typographie (`bodyColor: 0xFF333333` — thème parfaitement sain) les
      // rend différents et faisait rougir un comportement CORRECT.
      await tester.pumpWidget(_wrap(
        const ZFlashcardDefaultContent(content: 'bonjour'),
      ));
      final context = tester.element(find.byType(Text));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, ZcrudTheme.fallback(Theme.of(context)).labelColor,
          reason: 'la couleur doit être RÉSOLUE par la chaîne ZcrudTheme '
              '(scope → extension → fallback dérivé du ThemeData), FR-26');
    });

    testWidgets(
        'DISCRIMINANT — quand ZcrudTheme.labelColor est null, le widget replie '
        'sur Theme.of(...).colorScheme.onSurface (branche `??` réellement '
        'exercée)', (tester) async {
      // `const ZcrudTheme()` a un `labelColor` NULL : c'est le SEUL moyen
      // d'atteindre la branche droite du `??` — un thème injecté incomplet.
      // Le ColorScheme est forcé pour que `onSurface` DIFFÈRE de
      // `bodyMedium.color` : sans cela le test passerait quelle que soit la
      // branche prise, et ne discriminerait rien.
      const distinctOnSurface = Color(0xFF0000FF);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(onSurface: distinctOnSurface),
          textTheme: const TextTheme(bodyMedium: TextStyle(color: Color(0xFF333333))),
        ),
        home: const ZcrudScope(
          theme: ZcrudTheme(),
          child: Scaffold(body: ZFlashcardDefaultContent(content: 'bonjour')),
        ),
      ));

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, distinctOnSurface,
          reason: 'labelColor étant null, le repli DOIT venir de '
              'colorScheme.onSurface — et jamais d\'une couleur en dur');
    });

    testWidgets('TextAlign.start — directionnel, RTL-safe (AD-13)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ZFlashcardDefaultContent(content: 'bonjour'),
      ));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textAlign, TextAlign.start,
          reason: 'jamais TextAlign.left/right (AD-13)');
    });
  });
}
