/// 🔴 Gardes de la **réservation de la place du clavier** sous la feuille
/// modale — CR-IFFD-122 (2026-08-26).
///
/// Défaut mesuré côté hôte : formulaire présenté en feuille (le mode adaptatif
/// par défaut sur mobile), le doigt se pose sur le DERNIER champ, le clavier
/// monte — et le champ focalisé reste sous le clavier, hors de portée du
/// défilement. Reproduit ici avant correctif :
///
/// ```text
/// APRES insets: f3=Rect.fromLTRB(28.0, 736.0, 372.0, 792.0)
///               sheet=Rect.fromLTRB(0.0, 476.0, 400.0, 800.0)  visible<=500
/// ```
///
/// Les gardes MESURENT des RECTANGLES (`tester.getRect`), jamais la présence
/// d'un widget : un `ZSheetKeyboardInset` monté mais inerte doit rougir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Hauteur d'écran des montages (dp, `devicePixelRatio` = 1).
const double kScreenHeight = 800;

/// Largeur d'écran : `compact` ⇒ le mode adaptatif résout `sheet`.
const double kScreenWidth = 400;

/// Hauteur du clavier simulée.
const double kKeyboard = 300;

/// Corps de formulaire à quatre champs — le dernier (`f3`) est celui que la QA
/// touche, donc celui dont la visibilité est en jeu.
Widget fourFields() => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('TITRE'),
        ),
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              key: ValueKey<String>('f$i'),
              decoration: InputDecoration(labelText: 'champ $i'),
            ),
          ),
      ],
    );

/// Monte l'app hôte et ouvre la feuille, encarts à ZÉRO.
Future<void> openSheet(
  WidgetTester tester, {
  required Widget body,
  double? maxHeight,
  ZEditionChrome? chrome,
  ZSheetFrameSpec? sheetFrame,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding.zero;
  tester.view.physicalSize = const Size(kScreenWidth, kScreenHeight);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => presentEdition<void>(
                context,
                builder: (_) => body,
                maxHeight: maxHeight,
                chrome: chrome,
                sheetFrame: sheetFrame,
                forcedMode: ZEditionPresentation.sheet,
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

/// Fait monter le clavier PENDANT que la feuille est ouverte.
Future<void> raiseKeyboard(WidgetTester tester,
    {double height = kKeyboard}) async {
  tester.view.viewInsets = FakeViewPadding(bottom: height);
  await tester.pumpAndSettle();
}

/// Corps INSTRUMENTÉ : compte ses `initState` et ses `build`, pour mesurer ce
/// que la montée du clavier reconstruit RÉELLEMENT.
class ProbeBody extends StatefulWidget {
  const ProbeBody({super.key});

  /// Nombre de `State` créés depuis la dernière remise à zéro.
  static int inits = 0;

  /// Nombre de `build` du corps depuis la dernière remise à zéro.
  static int builds = 0;

  /// Remet les deux compteurs à zéro.
  static void reset() {
    inits = 0;
    builds = 0;
  }

  @override
  State<ProbeBody> createState() => _ProbeBodyState();
}

class _ProbeBodyState extends State<ProbeBody> {
  @override
  void initState() {
    super.initState();
    ProbeBody.inits++;
  }

  @override
  Widget build(BuildContext context) {
    ProbeBody.builds++;
    return fourFields();
  }
}

void main() {
  testWidgets(
      'KB-1 — EFFET : clavier levé, le dernier champ reste AU-DESSUS du '
      'clavier et la zone utile recule d\'exactement la hauteur du clavier',
      (WidgetTester tester) async {
    await openSheet(tester, body: fourFields());
    final Rect sheetBefore = tester.getRect(find.byType(BottomSheet));
    final Rect fieldBefore =
        tester.getRect(find.byKey(const ValueKey<String>('f3')));
    // Le défaut d'origine : sans clavier, le dernier champ touche le bas.
    expect(fieldBefore.bottom, greaterThan(kScreenHeight - kKeyboard),
        reason: 'montage non probant : sans clavier, `f3` doit déjà se '
            'trouver dans la zone que le clavier va recouvrir — sinon la '
            'garde passerait sans rien mesurer.');

    await tester.tap(find.byKey(const ValueKey<String>('f3')));
    await tester.pumpAndSettle();
    await raiseKeyboard(tester);

    final Rect fieldAfter =
        tester.getRect(find.byKey(const ValueKey<String>('f3')));
    expect(
      fieldAfter.bottom,
      lessThanOrEqualTo(kScreenHeight - kKeyboard),
      reason: '🔴 le champ focalisé est SOUS le clavier : la feuille ne '
          'réserve pas la place de l\'encart bas (`viewInsets.bottom`). '
          'Rect mesuré : $fieldAfter, bord haut du clavier : '
          '${kScreenHeight - kKeyboard}.',
    );

    // La ZONE UTILE recule d'EXACTEMENT la hauteur du clavier : le corps
    // s'arrête là où le clavier commence, alors que la feuille, elle, reste
    // ancrée au bas de l'écran (c'est le SDK qui la place).
    final Rect sheetAfter = tester.getRect(find.byType(BottomSheet));
    final Rect bodyAfter = tester.getRect(find.byType(Column).first);
    expect(sheetAfter.bottom, equals(kScreenHeight),
        reason: 'la feuille reste ancrée au bas de l\'écran (SDK).');
    expect(bodyAfter.bottom, equals(sheetAfter.bottom - kKeyboard),
        reason: '🔴 le corps de la feuille doit s\'arrêter exactement au bord '
            'haut du clavier. Corps : $bodyAfter, feuille : $sheetAfter.');
    expect(bodyAfter.height, equals(sheetBefore.height),
        reason: 'le corps garde sa hauteur intrinsèque : il est REMONTÉ, pas '
            'écrasé (le contenu tient encore dans la place restante).');
  });

  testWidgets(
      'KB-2 — INERTIE : sans clavier, la géométrie est celle d\'AVANT le lot, '
      'au pixel', (WidgetTester tester) async {
    await openSheet(tester, body: fourFields());
    // Valeurs MESURÉES sur le code d'avant le lot (aucun `viewInsets` nulle
    // part dans `zcrud_navigation/lib`), même montage, même corps :
    //   sheet = Rect.fromLTRB(0.0, 476.0, 400.0, 800.0)
    //   f3    = Rect.fromLTRB(28.0, 736.0, 372.0, 792.0)
    // Elles sont écrites en DUR : c'est tout l'objet de la garde — un
    // rembourrage qui « ne se voit pas » à encart nul doit rester
    // rigoureusement nul.
    expect(
      tester.getRect(find.byType(BottomSheet)),
      const Rect.fromLTRB(0, 476, kScreenWidth, kScreenHeight),
      reason: '🔴 la feuille SANS clavier a bougé : la réservation de la place '
          'du clavier doit être STRICTEMENT nulle quand `viewInsets.bottom` '
          'vaut zéro.',
    );
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('f3'))),
      const Rect.fromLTRB(28, 736, 372, 792),
      reason: '🔴 le dernier champ SANS clavier a bougé : un hôte qui n\'a '
          'jamais vu le défaut verrait, lui, un rendu changé.',
    );
    expect(tester.takeException(), isNull,
        reason: 'aucun débordement ne doit apparaître à encart nul.');
  });

  testWidgets(
      'KB-3 — RÉACTIVITÉ : l\'encart change PENDANT que la feuille est '
      'ouverte, dans les deux sens, et la géométrie suit',
      (WidgetTester tester) async {
    await openSheet(tester, body: fourFields());
    final Rect closed =
        tester.getRect(find.byKey(const ValueKey<String>('f3')));

    // 0 → 300 : la lecture doit être RÉACTIVE. Une capture faite au montage
    // laisserait la feuille dimensionnée pour un écran sans clavier — le
    // correctif ne marcherait alors que si le clavier était DÉJÀ levé à
    // l'ouverture, ce qui n'arrive jamais.
    await raiseKeyboard(tester);
    final Rect raised =
        tester.getRect(find.byKey(const ValueKey<String>('f3')));
    expect(raised.top, equals(closed.top - kKeyboard),
        reason: '🔴 la géométrie n\'a pas suivi la MONTÉE du clavier : '
            'l\'encart est lu une fois pour toutes, pas à chaque changement. '
            'Avant : $closed, après : $raised.');

    // 300 → 150 : une hauteur INTERMÉDIAIRE (clavier plus court, barre de
    // suggestions repliée). Ni « zéro », ni la valeur précédente.
    await raiseKeyboard(tester, height: 150);
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('f3'))).top,
      equals(closed.top - 150),
      reason: '🔴 la feuille ne suit pas un encart qui CHANGE de valeur : '
          'elle ne réagit qu\'au passage zéro / non-zéro.',
    );

    // 150 → 0 : le clavier redescend, la géométrie revient EXACTEMENT à
    // l'état d'avant — la réservation ne laisse aucun résidu.
    await raiseKeyboard(tester, height: 0);
    expect(tester.getRect(find.byKey(const ValueKey<String>('f3'))),
        equals(closed),
        reason: '🔴 clavier refermé, la géométrie ne revient pas à son état '
            'initial : la réservation laisse un résidu.');
  });

  testWidgets(
      'KB-4 — GRANULARITÉ + SAISIE : la montée du clavier ne reconstruit QUE '
      'la réservation ; le corps garde son `State` et le texte déjà tapé',
      (WidgetTester tester) async {
    ProbeBody.reset();
    await openSheet(tester, body: const ProbeBody());
    await tester.enterText(
        find.byKey(const ValueKey<String>('f3')), 'SAISIE');
    await tester.pumpAndSettle();
    final int initsBefore = ProbeBody.inits;
    final int buildsBefore = ProbeBody.builds;
    expect(find.text('SAISIE'), findsOneWidget,
        reason: 'montage non probant : le texte doit d\'abord être saisi.');

    await raiseKeyboard(tester);

    // ── Invariant de rebuild GRANULAIRE (AD-2/SM-1) ────────────────────────
    // Seule la réservation est abonnée aux encarts ; l'instance de widget
    // passée en `child` ne change pas, donc le corps n'est pas reconstruit.
    expect(ProbeBody.builds, equals(buildsBefore),
        reason: '🔴 la montée du clavier RECONSTRUIT le corps du formulaire '
            '($buildsBefore → ${ProbeBody.builds}). L\'abonnement aux '
            'encarts doit être porté par un nœud dédié, pas par le corps.');
    expect(ProbeBody.inits, equals(initsBefore),
        reason: '🔴 le `State` du corps a été RECRÉÉ à la montée du clavier '
            '($initsBefore → ${ProbeBody.inits}) : la FORME de l\'arbre a '
            'changé sous l\'utilisateur. C\'est exactement ce qu\'une '
            'réservation « seulement quand l\'encart est non nul » provoque.');

    // La conséquence VISIBLE pour l'utilisateur, mesurée et non déduite.
    expect(find.text('SAISIE'), findsOneWidget,
        reason: '🔴 le texte déjà tapé a DISPARU quand le clavier est monté.');
    expect(FocusManager.instance.primaryFocus?.context, isNotNull,
        reason: '🔴 le focus a été perdu à la montée du clavier.');
  });

  testWidgets(
      'KB-5 — COUVERTURE `maxHeight` : la borne de l\'hôte reste PRIORITAIRE '
      'et borne la feuille ENTIÈRE, réservation du clavier comprise',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      // Corps PLUS HAUT que la borne (324 dp de champs + 200 dp de marge) :
      // sans cela, la feuille se dimensionnerait sur son contenu et la borne
      // ne serait jamais atteinte — la garde ne mesurerait rien.
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[fourFields(), const SizedBox(height: 200)],
        ),
      ),
      maxHeight: 400,
    );
    final Rect sheetBefore = tester.getRect(find.byType(BottomSheet));
    expect(sheetBefore.height, equals(400),
        reason: 'montage non probant : la borne de l\'hôte doit d\'abord '
            'être honorée sans clavier.');

    await tester.tap(find.byKey(const ValueKey<String>('f3')));
    await tester.pumpAndSettle();
    await raiseKeyboard(tester);

    final Rect sheetAfter = tester.getRect(find.byType(BottomSheet));
    expect(sheetAfter.height, equals(400),
        reason: '🔴 la borne `maxHeight` de l\'hôte n\'est plus honorée quand '
            'le clavier monte : elle borne la feuille ENTIÈRE, la '
            'réservation du clavier étant prise DEDANS — jamais ajoutée '
            'par-dessus, jamais retranchée deux fois. Mesuré : $sheetAfter.');
    // Corps qui défile ⇒ il se réduit à la place restante, et le champ
    // focalisé revient dans la vue.
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('f3'))).bottom,
      lessThanOrEqualTo(kScreenHeight - kKeyboard),
      reason: '🔴 sous une borne `maxHeight` explicite, le champ focalisé '
          'reste sous le clavier.',
    );
    expect(tester.takeException(), isNull,
        reason: 'un corps qui défile doit absorber la place réservée sans '
            'déborder.');
  });

  testWidgets(
      'KB-6 — COUVERTURE voie CHROME : le corps monté par le socle '
      '(`ZEditionScaffold`) recule lui aussi devant le clavier',
      (WidgetTester tester) async {
    await openSheet(
      tester,
      body: SingleChildScrollView(child: fourFields()),
      chrome: const ZEditionChrome(title: 'Titre'),
    );
    await tester.tap(find.byKey(const ValueKey<String>('f3')));
    await tester.pumpAndSettle();
    await raiseKeyboard(tester);

    final Rect sheet = tester.getRect(find.byType(BottomSheet));
    final Rect content = tester.getRect(find.descendant(
      of: find.byType(ZSheetKeyboardInset),
      matching: find.byType(Column),
    ).first);
    expect(content.bottom, equals(sheet.bottom - kKeyboard),
        reason: '🔴 la voie CHROME ne réserve pas la place du clavier : le '
            'chrome (titre + corps + barre d\'actions) descend sous le '
            'clavier. Contenu : $content, feuille : $sheet.');
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('f3'))).bottom,
      lessThanOrEqualTo(kScreenHeight - kKeyboard),
      reason: '🔴 voie chrome : le champ focalisé reste sous le clavier.',
    );
  });

  testWidgets(
      'KB-7 — COUVERTURE voie SANS CADRE : l\'échappatoire `never` retire le '
      'cadre, JAMAIS la réservation du clavier', (WidgetTester tester) async {
    await openSheet(
      tester,
      body: fourFields(),
      sheetFrame: const ZSheetFrameSpec(mode: ZSheetFrameMode.never),
    );
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).shape, isNull,
        reason: 'montage non probant : `never` doit bien avoir retiré le '
            'cadre — sinon la garde ne mesure pas la voie annoncée.');

    await tester.tap(find.byKey(const ValueKey<String>('f3')));
    await tester.pumpAndSettle();
    await raiseKeyboard(tester);

    final Rect sheet = tester.getRect(find.byType(BottomSheet));
    final Rect content = tester.getRect(find.byType(Column).first);
    expect(content.bottom, equals(sheet.bottom - kKeyboard),
        reason: '🔴 la réservation du clavier a disparu avec le cadre : les '
            'deux réglages doivent être INDÉPENDANTS.');
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('f3'))).bottom,
      lessThanOrEqualTo(kScreenHeight - kKeyboard),
      reason: '🔴 voie sans cadre : le champ focalisé reste sous le clavier.',
    );
  });
}
