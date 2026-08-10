// CR « boolean label weight & field paddings » (2026-08-10), points 1 et 2 —
// famille `boolean` de `zcrud_core`.
//
// Ce que ces gardes défendent, et COMMENT elles rougissent :
//
//  * POIDS DU LIBELLÉ (point 1, voie A) — le titre reprend le `fontWeight` du
//    jeton EXISTANT `ZcrudTheme.labelTextStyle`. Les gardes lisent le style
//    RÉELLEMENT PEINT (`RenderParagraph.text.style`), pas le `Text` du widget :
//    le style effectif naît de la fusion avec le `DefaultTextStyle` du
//    `ListTile`, qu'un `expect` sur `Text.style` ne verrait pas. Les DEUX sens
//    sont mesurés : sans jeton (ou jeton sans poids) le poids peint est
//    EXACTEMENT celui de l'hôte passif ; avec le jeton, il est celui du jeton.
//  * NON-CONTAMINATION — le jeton porte souvent une couleur et une taille (le
//    pilote y met une marine). Seul le POIDS doit passer : les gardes comparent
//    couleur et taille peintes à celles de l'hôte passif. Fusionner le style
//    entier les ferait rougir — c'est la décision documentée dans `_titleStyle`.
//  * HAUTEUR DE L'ENCART (point 2) — la cible n'est PAS une constante : chaque
//    garde monte un **vrai champ `text` voisin** dans le MÊME thème et confronte
//    les deux hauteurs rendues. Une garde contre `56.0` en dur serait
//    tautologique (elle passerait même si le voisin changeait de hauteur).
//    Le libellé de mesure est volontairement COURT : la police de test rend
//    chaque glyphe à `fontSize` de large, et un libellé long passe à la ligne —
//    la ligne mesurerait alors le retour à la ligne, pas la marge.
//  * DÉRIVÉ DU JETON — la marge horizontale conservée vient de
//    `inputContentPadding` (7/11 posés ⇒ 7/11 rendus), la verticale est nulle.
//  * AD-13 — la ligne garde son plancher tactile ET la ligne directrice Android.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Libellé COURT : ne peut pas passer à la ligne dans la police de test.
const String _label = 'Actif';

ZFieldSpec _spec({
  ZFieldConfig? config,
  bool readOnly = false,
  String label = _label,
}) =>
    ZFieldSpec(
      name: 'actif',
      type: EditionFieldType.boolean,
      label: label,
      readOnly: readOnly,
      config: config,
    );

/// Monte le booléen SEUL (thème optionnel).
Widget _app(ZFieldSpec field, {ZcrudTheme? tokens, bool value = true}) =>
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00477D)),
        extensions: <ThemeExtension<Object?>>[?tokens],
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: ZBooleanFieldWidget(
              field: field,
              value: value,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

/// Monte le booléen **et un vrai champ `text`** dans le MÊME thème : c'est la
/// référence de hauteur (jamais une constante).
Widget _appWithNeighbour(ZFieldSpec field, {ZcrudTheme? tokens}) {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00477D)),
      extensions: <ThemeExtension<Object?>>[?tokens],
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ZBooleanFieldWidget(
                field: field,
                value: true,
                onChanged: (_) {},
              ),
              ZTextFieldWidget(
                field: const ZFieldSpec(
                  name: 'nom',
                  type: EditionFieldType.text,
                  label: 'Nom',
                ),
                controller: controller,
                focusNode: focusNode,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Monte un `ListTile` **de Material**, non décoré, dans le MÊME thème : c'est
/// la référence de style du titre (jamais une constante de police recopiée).
Widget _materialReference({ZcrudTheme? tokens}) => MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00477D)),
        extensions: <ThemeExtension<Object?>>[?tokens],
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: ListTile(
              title: const Text(_label),
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );

/// Pompe [widget] **et laisse le thème se stabiliser**.
///
/// 🔴 `MaterialApp` interpole `ThemeData` (`AnimatedTheme`) : un simple
/// `pumpWidget` après un CHANGEMENT de thème lit le thème à mi-course, donc un
/// `fontWeight` lerpé — mesuré : `FontWeight.lerp(null, bold, ~0)` rend `w400`
/// et la garde passerait pour un défaut qui n'existe pas.
Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

/// Style RÉELLEMENT PEINT du libellé (fusion `DefaultTextStyle` + `Text.style`).
/// La présence est assertée d'abord : sans cet `expect`, une injection qui ferait
/// disparaître le libellé rendrait un `StateError` de `find`, pas une assertion.
TextStyle _paintedLabelStyle(WidgetTester tester, {String text = _label}) {
  expect(find.text(text), findsOneWidget, reason: 'libellé attendu à l\'écran');
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final style = paragraph.text.style;
  expect(style, isNotNull, reason: 'le paragraphe doit porter un style effectif');
  return style!;
}

/// Hauteur RENDUE de l'encart (présence assertée d'abord).
double _boxHeight(WidgetTester tester) {
  expect(find.byKey(zBooleanBoxKey), findsOneWidget, reason: 'encart attendu');
  return tester.getSize(find.byKey(zBooleanBoxKey)).height;
}

/// Hauteur RENDUE du champ `text` voisin réellement monté.
double _neighbourHeight(WidgetTester tester) {
  expect(find.byType(TextField), findsOneWidget, reason: 'voisin text attendu');
  return tester.getSize(find.byType(TextField)).height;
}

/// Hauteur RENDUE de la ligne.
double _tileHeight(WidgetTester tester) {
  expect(find.byType(ListTile), findsOneWidget, reason: 'ListTile attendu');
  return tester.getSize(find.byType(ListTile)).height;
}

/// Décoration réellement posée sur l'encart.
InputDecoration _boxDecoration(WidgetTester tester) {
  expect(find.byKey(zBooleanBoxKey), findsOneWidget, reason: 'encart attendu');
  return tester.widget<InputDecorator>(find.byKey(zBooleanBoxKey)).decoration;
}

void main() {
  // ══ POINT 1 — POIDS DU LIBELLÉ (jeton EXISTANT `labelTextStyle`) ══════════

  group('CR point 1 — poids du libellé booléen', () {
    testWidgets(
        'hôte PASSIF : le `Text` du titre est construit SANS style, et le style '
        'peint est exactement celui de Material', (t) async {
      await _pump(t, _app(_spec()));
      // Structurel : littéralement l'expression de v0.79.
      expect(t.widget<Text>(find.text(_label)).style, isNull);
      final passive = _paintedLabelStyle(t);

      // Référence : un `ListTile` de Material monté dans le MÊME thème. Le
      // style peint doit lui être IDENTIQUE — poids, taille et couleur.
      await _pump(t, _materialReference());
      final material = _paintedLabelStyle(t);
      expect(passive.fontWeight, material.fontWeight);
      expect(passive.fontSize, material.fontSize);
      expect(passive.color, material.color);
    });

    testWidgets(
        'jeton posé SANS fontWeight (le cas du pilote : couleur seule) ⇒ rendu '
        'inchangé — ni le poids, ni la couleur du jeton ne passent', (t) async {
      await _pump(t, _app(_spec()));
      final passive = _paintedLabelStyle(t);

      await _pump(
        t,
        _app(
          _spec(),
          tokens: const ZcrudTheme(labelTextStyle: TextStyle(color: Color(0xFF00477D))),
        ),
      );
      expect(t.widget<Text>(find.text(_label)).style, isNull);
      final withColorOnly = _paintedLabelStyle(t);
      expect(withColorOnly.fontWeight, passive.fontWeight);
      expect(withColorOnly.color, passive.color,
          reason: 'la COULEUR du jeton ne doit pas contaminer le titre');
      expect(withColorOnly.fontSize, passive.fontSize);
    });

    testWidgets('jeton avec fontWeight ⇒ le titre est PEINT dans ce poids',
        (t) async {
      await _pump(t, _app(_spec()));
      final passive = _paintedLabelStyle(t);

      for (final weight in <FontWeight>[FontWeight.bold, FontWeight.w300]) {
        await _pump(
          t,
          _app(_spec(), tokens: ZcrudTheme(labelTextStyle: TextStyle(fontWeight: weight))),
        );
        expect(_paintedLabelStyle(t).fontWeight, weight,
            reason: 'poids demandé : $weight');
      }
      // Discrimination : le poids obtenu n'est pas celui de l'hôte passif.
      expect(passive.fontWeight, isNot(FontWeight.bold));
    });

    testWidgets(
        'SEUL le poids passe : couleur et taille du jeton ne contaminent pas le '
        'titre (décision documentée dans `_titleStyle`)', (t) async {
      await _pump(t, _app(_spec()));
      final passive = _paintedLabelStyle(t);

      await _pump(
        t,
        _app(
          _spec(),
          tokens: const ZcrudTheme(
            labelTextStyle: TextStyle(
              color: Color(0xFFAB1234),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      final painted = _paintedLabelStyle(t);
      expect(painted.fontWeight, FontWeight.bold);
      expect(painted.color, passive.color);
      expect(painted.fontSize, passive.fontSize);
      expect(painted.color, isNot(const Color(0xFFAB1234)));
      expect(painted.fontSize, isNot(9.0));
    });

    testWidgets('les TROIS rendus du titre reçoivent le poids', (t) async {
      const tokens = ZcrudTheme(labelTextStyle: TextStyle(fontWeight: FontWeight.bold));
      for (final config in const <ZBooleanConfig?>[
        null, // switchTile nu
        ZBooleanConfig(showStateLabel: true), // switchTile + texte d'état
        ZBooleanConfig(style: ZBooleanStyle.pill), // pilule
        ZBooleanConfig(boxed: true), // encarté
      ]) {
        await _pump(t, _app(_spec(config: config), tokens: tokens));
        expect(_paintedLabelStyle(t).fontWeight, FontWeight.bold,
            reason: 'config = $config');
      }
    });

    testWidgets('lecture seule : le poids s\'applique aussi', (t) async {
      await _pump(
        t,
        _app(
          _spec(readOnly: true),
          tokens: const ZcrudTheme(labelTextStyle: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
      expect(_paintedLabelStyle(t).fontWeight, FontWeight.bold);
    });
  });

  // ══ POINT 2 — HAUTEUR DE L'ENCART, COMPARÉE AU VOISIN RÉEL ════════════════

  group('CR point 2 — hauteur de l\'encart', () {
    testWidgets(
        'PARITÉ DE HAUTEUR : l\'encart mesure EXACTEMENT la hauteur du champ '
        '`text` voisin monté dans le même thème', (t) async {
      await _pump(
        t,
        _appWithNeighbour(_spec(config: const ZBooleanConfig(boxed: true))),
      );
      final box = _boxHeight(t);
      final neighbour = _neighbourHeight(t);
      expect(box, neighbour,
          reason: 'encart=$box dp, voisin text=$neighbour dp — le double '
              'comptage vertical est revenu');
      // La garde n'est pas vacante : la référence est un vrai rendu, non nulle.
      expect(neighbour, greaterThan(0));
    });

    testWidgets('PARITÉ DE HAUTEUR : même mesure en forme pilule', (t) async {
      await _pump(
        t,
        _appWithNeighbour(
          _spec(
            config: const ZBooleanConfig(boxed: true, style: ZBooleanStyle.pill),
          ),
        ),
      );
      expect(_boxHeight(t), _neighbourHeight(t));
    });

    testWidgets(
        'INVARIANT GÉNÉRAL : quel que soit le jeton de marge, l\'encart n\'ajoute '
        'AUCUNE hauteur à la ligne', (t) async {
      // 🔴 Pourquoi cet invariant, et pas la parité exacte, pour les marges non
      // standard : la parité exacte est **impossible** hors du voisinage du
      // défaut, et AD-13 est la contrainte qui prime. Mesuré — avec 4 dp de
      // marge verticale le champ `text` voisin ne fait que 32 dp, sous le
      // plancher tactile de 48 dp ; une ligne de booléen ne peut pas descendre
      // l'y rejoindre sans violer AD-13. Ce qui doit tenir partout, c'est
      // l'absence de DOUBLE COMPTAGE : la hauteur de l'encart est celle de la
      // ligne, et rien de plus. Avant correction elle valait ligne + 2 × marge.
      for (final vertical in <double>[4, 8, 16, 24, 40]) {
        final tokens = ZcrudTheme(
          inputContentPadding: EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: vertical,
          ),
        );
        await _pump(t, _app(_spec(), tokens: tokens));
        final plainLine = _tileHeight(t);

        await _pump(
          t,
          _app(_spec(config: const ZBooleanConfig(boxed: true)), tokens: tokens),
        );
        expect(_boxHeight(t), plainLine,
            reason: 'marge verticale du jeton = $vertical dp : l\'encart doit '
                'mesurer la LIGNE, pas la ligne + 2 × $vertical');
      }
    });

    testWidgets(
        'la marge HORIZONTALE du jeton est conservée, la VERTICALE est nulle',
        (t) async {
      const tokens = ZcrudTheme(
        inputContentPadding: EdgeInsetsDirectional.fromSTEB(7, 9, 11, 13),
      );
      await _pump(
        t,
        _app(_spec(config: const ZBooleanConfig(boxed: true)), tokens: tokens),
      );
      expect(
        _boxDecoration(t).contentPadding,
        const EdgeInsetsDirectional.fromSTEB(7, 0, 11, 0),
        reason: 'start/end DÉRIVÉS du jeton (jamais une constante), top/bottom nuls',
      );
      // AD-13 : marge DIRECTIONNELLE (jamais `EdgeInsets.only(left:)`).
      expect(_boxDecoration(t).contentPadding, isA<EdgeInsetsDirectional>());
    });

    testWidgets(
        'AD-13 : la ligne garde son plancher tactile et la ligne directrice '
        'Android sous l\'encart raccourci', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, _app(_spec(config: const ZBooleanConfig(boxed: true))));
      expect(_tileHeight(t), greaterThanOrEqualTo(48.0));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets(
        'la ligne n\'est PAS comprimée par la correction : sa hauteur est celle '
        'du même champ SANS encart', (t) async {
      await _pump(t, _app(_spec()));
      final plain = _tileHeight(t);
      await _pump(t, _app(_spec(config: const ZBooleanConfig(boxed: true))));
      expect(_tileHeight(t), plain,
          reason: 'la correction retire une marge de l\'ENVELOPPE, elle ne '
              'touche pas la ligne');
    });

    testWidgets('hôte passif (sans encart) : aucune décoration, donc rien à réduire',
        (t) async {
      await _pump(t, _app(_spec()));
      expect(find.byType(InputDecorator), findsNothing);
    });
  });
}
