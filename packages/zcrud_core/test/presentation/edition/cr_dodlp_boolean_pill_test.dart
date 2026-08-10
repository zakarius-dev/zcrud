// CR-DODLP-BOOL-PILL (2026-08-10) — Famille `boolean` : rendu « pilule »
// (voie A, peint nativement) + ouverture du seam de registre (voie B).
//
// Ce que ces gardes défendent, et comment elles rougissent :
//
//  * ACTIVATION — `ZBooleanConfig.style` défaut `switchTile`. Rendre la pilule
//    inconditionnelle rougit les gardes d'IMMOBILITÉ de l'hôte passif (le
//    `SwitchListTile` doit rester monté, la pilule ABSENTE).
//  * MESURES LEGACY — 65 × 30, pouce 20, rayon 20, lues sur le `RenderBox` et
//    la `BoxDecoration` réels, pas sur les constantes du code.
//  * CHAÎNE DE COULEUR — paramètre (clé sémantique) > jeton > rôle, jouée aux
//    TROIS étages ET dans les DEUX états. Court-circuiter un étage rougit.
//  * CONTRASTE — le premier plan est DÉRIVÉ de la piste. La garde est jouée sur
//    une piste CLAIRE **et** sur une piste SOMBRE : un blanc en dur passerait le
//    cas sombre et rougirait le cas clair (c'est exactement le défaut legacy).
//  * DOUBLE ANNONCE — le texte interne est DÉCORATIF : 0 occurrence dans les
//    `label` sémantiques, alors que `toggled` est présent et discriminant. On
//    compte les OCCURRENCES de sous-chaîne (les conteneurs fusionnent leurs
//    descendants : compter les NŒUDS ne mordrait pas).
//  * CIBLE TACTILE — mesurée sur la CONTRAINTE LIANTE (`constraints.minHeight`
//    de la boîte de cible) : la pilule PEINTE ne fait que 30 dp, donc une garde
//    sur `getSize()` du `Container` serait fausse, et une garde sur la ligne
//    entière serait VACANTE (un `ListTile` dépasse déjà 48 dp tout seul).
//  * RTL — position du pouce prouvée par COORDONNÉES, dans les deux directions
//    et dans les deux états.
//  * PRIORITÉ DU REGISTRE (voie B) — dans les DEUX sens : builder enregistré ⇒
//    il gagne ; aucun builder (ou builder d'un AUTRE `kind`) ⇒ natif.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const String _fieldLabel = 'Magasin du bord visité ?';

ZFieldSpec _spec({ZFieldConfig? config, bool readOnly = false}) => ZFieldSpec(
      name: 'visited',
      type: EditionFieldType.boolean,
      label: _fieldLabel,
      readOnly: readOnly,
      config: config,
    );

/// Applique la locale zcrud SANS la déclarer au `MaterialApp` (le cœur ne
/// dépend pas de `flutter_localizations`) — même harnais que la garde v0.74.
Widget _withLocale(Locale? locale, Widget child) => locale == null
    ? child
    : Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: locale,
          delegates: const <LocalizationsDelegate<Object?>>[
            ZcrudLocalizationsDelegate(),
          ],
          child: child,
        ),
      );

/// Monte le champ booléen seul (la famille sous test), avec thème et seams
/// optionnels.
Widget _app(
  ZFieldSpec field,
  Object? value, {
  TextDirection textDirection = TextDirection.ltr,
  Locale? locale,
  double width = 360,
  ZcrudTheme? tokens,
  ZColorKeyResolver? colorKeyResolver,
  ColorScheme? scheme,
  ValueChanged<bool>? onChanged,
}) {
  final ColorScheme effective =
      scheme ?? ColorScheme.fromSeed(seedColor: const Color(0xFF00477D));
  return MaterialApp(
    theme: ThemeData(
      colorScheme: effective,
      extensions: <ThemeExtension<Object?>>[?tokens],
    ),
    home: ZcrudScope(
      colorKeyResolver: colorKeyResolver,
      child: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: _withLocale(
                locale,
                ZBooleanFieldWidget(
                  field: field,
                  value: value,
                  onChanged: onChanged ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Nombre total d'OCCURRENCES de [needle] dans les `label` de TOUS les nœuds
/// sémantiques rendus — le canal réellement lu par un lecteur d'écran.
int _labelOccurrences(WidgetTester tester, String needle) {
  // `rootPipelineOwner` (le remplaçant annoncé par la dépréciation) n'expose
  // PAS de `semanticsOwner` en test : les gardes deviendraient un `_TypeError`
  // au lieu d'une assertion (mesuré en v0.74). On lit l'owner effectif.
  // ignore: deprecated_member_use
  final owner = tester.binding.pipelineOwner.semanticsOwner!;
  var count = 0;
  void walk(SemanticsNode n) {
    count += needle.allMatches(n.getSemanticsData().label).length;
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return count;
}

/// `true` si un nœud sémantique porte le drapeau `isToggled` demandé.
bool _hasToggled(WidgetTester tester, {required bool expected}) {
  // ignore: deprecated_member_use
  final owner = tester.binding.pipelineOwner.semanticsOwner!;
  var found = false;
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    // `SemanticsFlags.isToggled` (le remplaçant) est un `Tristate` non
    // comparable à un `bool` : `hasFlag` reste la lecture exacte de l'état.
    // ignore: deprecated_member_use
    final hasToggle = d.hasFlag(SemanticsFlag.hasToggledState);
    // ignore: deprecated_member_use
    final isToggled = d.hasFlag(SemanticsFlag.isToggled);
    if (hasToggle && isToggled == expected) found = true;
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return found;
}

/// Taille RENDUE du widget de [key], présence ASSERTÉE d'abord (même raison
/// que [_paintedColor] : sinon une pilule absente rendrait un `StateError` au
/// lieu d'une assertion).
Size _sizeOf(WidgetTester tester, Key key) {
  expect(find.byKey(key), findsOneWidget, reason: 'widget attendu : $key');
  return tester.getSize(find.byKey(key));
}

/// Lit la teinte peinte du `Container` de [key].
///
/// 🔴 L'`expect` de présence n'est pas décoratif : sans lui, une injection qui
/// SUPPRIME la pilule ferait échouer ces gardes sur un `StateError` de `find`
/// (« no element ») et non sur une ASSERTION — un rouge de la mauvaise nature,
/// exactement le piège qualifié en v0.74 sur `rootPipelineOwner`. Mesuré : 10
/// des 15 rouges de l'injection « jamais de pilule » étaient des `StateError`
/// avant cet ajout.
Color _paintedColor(WidgetTester tester, Key key) {
  expect(find.byKey(key), findsOneWidget, reason: 'pilule attendue : $key');
  return (tester.widget<Container>(find.byKey(key)).decoration!
          as BoxDecoration)
      .color!;
}

/// Teinte peinte de la piste.
Color _trackColor(WidgetTester tester) =>
    _paintedColor(tester, zBooleanPillKey);

/// Teinte peinte du pouce.
Color _thumbColor(WidgetTester tester) =>
    _paintedColor(tester, zBooleanPillThumbKey);

/// Couleur EFFECTIVE du texte interne (celle que voit l'utilisateur).
Color _stateTextColor(WidgetTester tester, String text) {
  expect(find.text(text), findsOneWidget, reason: 'texte d\'état attendu : $text');
  return tester.widget<Text>(find.text(text)).style!.color!;
}

void main() {
  // ══ 1. DOMAINE — surface additive ═══════════════════════════════════════

  group('ZBooleanConfig — style & clés de couleur (domaine)', () {
    test('défauts : style switchTile, aucune clé (rétro-compat stricte)', () {
      const cfg = ZBooleanConfig();
      expect(cfg.style, ZBooleanStyle.switchTile);
      expect(cfg.activeColorKey, isNull);
      expect(cfg.inactiveColorKey, isNull);
    });

    test('R3 : égalité/hash discriminent style et CHAQUE clé', () {
      const base = ZBooleanConfig();
      expect(base, equals(const ZBooleanConfig()));
      expect(base.hashCode, equals(const ZBooleanConfig().hashCode));

      expect(base, isNot(const ZBooleanConfig(style: ZBooleanStyle.pill)));
      expect(base, isNot(const ZBooleanConfig(activeColorKey: 'success')));
      expect(base, isNot(const ZBooleanConfig(inactiveColorKey: 'neutral')));

      expect(
        const ZBooleanConfig(activeColorKey: 'success').hashCode,
        isNot(const ZBooleanConfig(activeColorKey: 'other').hashCode),
      );
    });
  });

  // ══ 2. IMMOBILITÉ DE L'HÔTE PASSIF ══════════════════════════════════════

  group('Hôte passif — rendu v0.74 strictement inchangé', () {
    testWidgets('sans config : SwitchListTile monté, AUCUNE pilule', (t) async {
      await t.pumpWidget(_app(_spec(), true));
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.byKey(zBooleanPillKey), findsNothing);
      expect(find.byKey(zBooleanPillTargetKey), findsNothing);
    });

    testWidgets('config SANS style (texte d\'état v0.74) : toujours le switch',
        (t) async {
      await t.pumpWidget(
        _app(_spec(config: const ZBooleanConfig(showStateLabel: true)), false),
      );
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.byKey(zBooleanPillKey), findsNothing);
      // Le texte d'état v0.74 (fin de titre) est bien là, inchangé.
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('style switchTile EXPLICITE : identique au défaut', (t) async {
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.switchTile)),
          true,
        ),
      );
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.byKey(zBooleanPillKey), findsNothing);
    });
  });

  // ══ 3. VOIE A — LE RENDU PILULE ═════════════════════════════════════════

  group('Pilule — structure et mesures legacy', () {
    testWidgets('style pill : plus de SwitchListTile, pilule + texte INTERNE',
        (t) async {
      for (final checked in <bool>[true, false]) {
        await t.pumpWidget(
          _app(
            _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
            checked,
          ),
        );
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.byKey(zBooleanPillKey), findsOneWidget);
        // Texte d'état DANS la pilule (descendant de la piste peinte).
        expect(
          find.descendant(
            of: find.byKey(zBooleanPillKey),
            matching: find.text(checked ? 'Yes' : 'No'),
          ),
          findsOneWidget,
          reason: 'état $checked : le texte doit être À L\'INTÉRIEUR',
        );
        // L'état OPPOSÉ n'est PAS construit (pas d'`Opacity` fantôme, que
        // `find.text` trouverait quand même).
        expect(find.text(checked ? 'No' : 'Yes'), findsNothing);
        // Libellé du champ à gauche, hors de la pilule.
        expect(find.text(_fieldLabel), findsOneWidget);
      }
    });

    testWidgets('mesures : 65 × 30, pouce 20, rayon 20 (relevés du legacy)',
        (t) async {
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
          true,
        ),
      );
      final Size track = _sizeOf(t, zBooleanPillKey);
      expect(track.width, 65);
      expect(track.height, 30);
      expect(_sizeOf(t, zBooleanPillThumbKey), const Size(20, 20));

      final BoxDecoration deco = t
          .widget<Container>(find.byKey(zBooleanPillKey))
          .decoration! as BoxDecoration;
      expect(
        deco.borderRadius,
        const BorderRadius.all(Radius.circular(20)),
      );
    });

    testWidgets('les mesures sont surchargeables par jeton', (t) async {
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
          true,
          tokens: const ZcrudTheme(
            booleanPillWidth: 90,
            booleanPillHeight: 40,
            booleanPillThumbSize: 28,
            booleanPillRadius: Radius.circular(6),
          ),
        ),
      );
      expect(_sizeOf(t, zBooleanPillKey), const Size(90, 40));
      expect(_sizeOf(t, zBooleanPillThumbKey), const Size(28, 28));
      final BoxDecoration deco = t
          .widget<Container>(find.byKey(zBooleanPillKey))
          .decoration! as BoxDecoration;
      expect(deco.borderRadius, const BorderRadius.all(Radius.circular(6)));
    });

    testWidgets('libellés d\'état surchargés et locale fr respectés', (t) async {
      await t.pumpWidget(
        _app(
          _spec(
            config: const ZBooleanConfig(
              style: ZBooleanStyle.pill,
              trueLabel: 'ACTIVÉ',
            ),
          ),
          true,
        ),
      );
      expect(find.text('ACTIVÉ'), findsOneWidget);

      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
          false,
          locale: const Locale('fr'),
        ),
      );
      expect(find.text('Non'), findsOneWidget);
    });

    testWidgets('showStateLabel + pill : l\'état n\'est PAS écrit DEUX fois',
        (t) async {
      await t.pumpWidget(
        _app(
          _spec(
            config: const ZBooleanConfig(
              style: ZBooleanStyle.pill,
              showStateLabel: true,
            ),
          ),
          true,
        ),
      );
      // Un seul `Text` « Yes » : celui DE LA PILULE. Le texte de fin de titre
      // (v0.74) ne doit pas s'y ajouter.
      expect(find.text('Yes'), findsOneWidget);
    });
  });

  // ══ 4. CHAÎNE DE COULEUR (FR-26) ════════════════════════════════════════

  group('Couleur — paramètre > jeton > rôle, dans les DEUX états', () {
    const ColorScheme scheme = ColorScheme.light(
      primary: Color(0xFF123456),
      outline: Color(0xFF789ABC),
    );

    testWidgets('sans réglage : rôles primary (ON) / outline (OFF)', (t) async {
      for (final checked in <bool>[true, false]) {
        await t.pumpWidget(
          _app(
            _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
            checked,
            scheme: scheme,
          ),
        );
        expect(
          _trackColor(t),
          checked ? scheme.primary : scheme.outline,
          reason: 'état $checked : le rôle du ColorScheme doit s\'appliquer',
        );
      }
    });

    testWidgets('le JETON bat le rôle, dans les deux états', (t) async {
      const Color on = Color(0xFF0A0B0C);
      const Color off = Color(0xFFE0E1E2);
      for (final checked in <bool>[true, false]) {
        await t.pumpWidget(
          _app(
            _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
            checked,
            scheme: scheme,
            tokens: const ZcrudTheme(
              booleanPillActiveColor: on,
              booleanPillInactiveColor: off,
            ),
          ),
        );
        expect(_trackColor(t), checked ? on : off);
        expect(_trackColor(t), isNot(checked ? scheme.primary : scheme.outline));
      }
    });

    testWidgets('le PARAMÈTRE (clé sémantique) bat le jeton, deux états',
        (t) async {
      // C'est la voie EXACTE du vert legacy `kSuccessColorLight` : le cœur ne
      // connaît que le nom, l'hôte fournit la couleur.
      const Color success = Color(0xFF2E7D32);
      const Color neutral = Color(0xFFBDBDBD);
      ZColorPair? resolver(ColorScheme s, String key) => switch (key) {
            'success' => const ZColorPair(color: success, onColor: Colors.white),
            'neutral' => const ZColorPair(color: neutral, onColor: Colors.black),
            _ => null,
          };

      for (final checked in <bool>[true, false]) {
        await t.pumpWidget(
          _app(
            _spec(
              config: const ZBooleanConfig(
                style: ZBooleanStyle.pill,
                activeColorKey: 'success',
                inactiveColorKey: 'neutral',
              ),
            ),
            checked,
            scheme: scheme,
            colorKeyResolver: resolver,
            tokens: const ZcrudTheme(
              booleanPillActiveColor: Color(0xFF0A0B0C),
              booleanPillInactiveColor: Color(0xFFE0E1E2),
            ),
          ),
        );
        expect(_trackColor(t), checked ? success : neutral);
        // Le `onColor` de la paire sert de premier plan (texte ET pouce).
        expect(
          _thumbColor(t),
          checked ? Colors.white : Colors.black,
        );
      }
    });

    testWidgets('clé INCONNUE du resolver ⇒ repli silencieux (AD-10)',
        (t) async {
      ZColorPair? resolver(ColorScheme s, String key) => null;
      await t.pumpWidget(
        _app(
          _spec(
            config: const ZBooleanConfig(
              style: ZBooleanStyle.pill,
              activeColorKey: 'inexistante',
            ),
          ),
          true,
          scheme: scheme,
          colorKeyResolver: resolver,
        ),
      );
      expect(_trackColor(t), scheme.primary);
    });
  });

  // ══ 5. CONTRASTE — le défaut legacy corrigé ═════════════════════════════

  group('Contraste du texte interne (AD-13)', () {
    testWidgets('piste SOMBRE ⇒ premier plan clair ; piste CLAIRE ⇒ foncé',
        (t) async {
      const ColorScheme scheme = ColorScheme.light(
        surface: Color(0xFFFFFFFE),
        onSurface: Color(0xFF111111),
      );

      // Piste SOMBRE (le vert legacy) : un blanc en dur passerait ici.
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
          true,
          scheme: scheme,
          tokens: const ZcrudTheme(booleanPillActiveColor: Color(0xFF2E7D32)),
        ),
      );
      expect(_stateTextColor(t, 'Yes'), scheme.surface);
      expect(_thumbColor(t), scheme.surface);

      // `MaterialApp` ANIME le changement de thème (`AnimatedTheme`) : sans
      // `pumpAndSettle`, la seconde mesure lirait encore le thème précédent —
      // la garde passerait pour la mauvaise raison.
      await t.pumpAndSettle();

      // Piste CLAIRE : c'est ICI que le blanc en dur du legacy devient
      // illisible — le premier plan doit basculer.
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
          true,
          scheme: scheme,
          tokens: const ZcrudTheme(booleanPillActiveColor: Color(0xFFFFF176)),
        ),
      );
      await t.pumpAndSettle();
      expect(_stateTextColor(t, 'Yes'), scheme.onSurface);
      expect(_thumbColor(t), scheme.onSurface);
    });

    testWidgets('un jeton de premier plan EXPLICITE gagne sur la dérivation',
        (t) async {
      const Color fg = Color(0xFFFF00FF);
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
          false,
          tokens: const ZcrudTheme(booleanPillInactiveForegroundColor: fg),
        ),
      );
      expect(_stateTextColor(t, 'No'), fg);
    });

    testWidgets('un jeton de STYLE ne peut pas casser le contraste', (t) async {
      // La couleur portée par `booleanPillTextStyle` est délibérément écrasée
      // par le premier plan résolu : sinon un hôte pourrait écrire du texte
      // invisible sur sa propre piste.
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
          true,
          tokens: const ZcrudTheme(
            booleanPillTextStyle: TextStyle(color: Color(0xFF00FF00), fontSize: 9),
          ),
        ),
      );
      expect(_stateTextColor(t, 'Yes'), isNot(const Color(0xFF00FF00)));
      // …mais le RESTE du style passe bien.
      expect(t.widget<Text>(find.text('Yes')).style!.fontSize, 9);
    });
  });

  // ══ 6. A11Y / RTL ═══════════════════════════════════════════════════════

  group('A11y (AD-13)', () {
    testWidgets('cible ≥ 48 dp mesurée sur la CONTRAINTE LIANTE', (t) async {
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
          true,
        ),
      );
      // La pilule PEINTE ne fait que 30 dp : la cible vient de la contrainte.
      expect(_sizeOf(t, zBooleanPillKey).height, 30);
      // 🔴 On lit la contrainte POSÉE par la boîte (`ConstrainedBox.constraints`
      // du widget), pas `RenderBox.constraints` — cette dernière rend les
      // contraintes REÇUES du parent, qui ici plancheraient à 0 et rendraient
      // la garde vacante (mesuré).
      final BoxConstraints posed =
          t.widget<ConstrainedBox>(find.byKey(zBooleanPillTargetKey)).constraints;
      expect(posed.minHeight, greaterThanOrEqualTo(48));
      expect(posed.minWidth, greaterThanOrEqualTo(48));
      // …et la contrainte est LIANTE : la cible RENDUE dépasse la pilule peinte.
      final Size target = _sizeOf(t, zBooleanPillTargetKey);
      expect(target.height, greaterThanOrEqualTo(48));
      expect(target.width, greaterThanOrEqualTo(48));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('le texte interne est DÉCORATIF (0 occurrence), `toggled` porte '
        'l\'état — les deux sens', (t) async {
      for (final checked in <bool>[true, false]) {
        final SemanticsHandle handle = t.ensureSemantics();
        await t.pumpWidget(
          _app(
            _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
            checked,
          ),
        );
        expect(
          _labelOccurrences(t, checked ? 'Yes' : 'No'),
          0,
          reason: 'état $checked : l\'état serait annoncé DEUX fois',
        );
        expect(_labelOccurrences(t, _fieldLabel), 1);
        expect(_hasToggled(t, expected: checked), isTrue);
        // Non-vacuité : le drapeau est DISCRIMINANT.
        expect(_hasToggled(t, expected: !checked), isFalse);
        handle.dispose();
      }
    });

    testWidgets('RTL : le pouce suit la direction, dans les deux états',
        (t) async {
      for (final dir in TextDirection.values) {
        for (final checked in <bool>[true, false]) {
          await t.pumpWidget(
            _app(
              _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
              checked,
              textDirection: dir,
            ),
          );
          // Présence ASSERTÉE avant toute mesure de coordonnées : sans elle,
          // une pilule absente rendrait une assertion du FRAMEWORK
          // (`getTopLeft` sans cible), pas la nôtre.
          expect(find.byKey(zBooleanPillKey), findsOneWidget);
          final double trackStart =
              t.getTopLeft(find.byKey(zBooleanPillKey)).dx;
          final double trackEnd =
              t.getBottomRight(find.byKey(zBooleanPillKey)).dx;
          final double thumbCentre =
              t.getCenter(find.byKey(zBooleanPillThumbKey)).dx;
          final double middle = (trackStart + trackEnd) / 2;
          // `checked` ⇒ pouce du côté END logique : à droite en LTR, à GAUCHE
          // en RTL. Un `Alignment` physique figerait le sens et rougirait ici.
          final bool towardsRight =
              dir == TextDirection.ltr ? checked : !checked;
          expect(
            thumbCentre > middle,
            towardsRight,
            reason: '$dir / état $checked : pouce du mauvais côté',
          );
        }
      }
    });
  });

  // ══ 7. INTERACTION ══════════════════════════════════════════════════════

  group('Interaction', () {
    testWidgets('un tap sur la PILULE bascule, une seule fois, les deux sens',
        (t) async {
      for (final checked in <bool>[true, false]) {
        final List<bool> written = <bool>[];
        await t.pumpWidget(
          _app(
            _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
            checked,
            onChanged: written.add,
          ),
        );
        expect(find.byKey(zBooleanPillKey), findsOneWidget);
        await t.tap(find.byKey(zBooleanPillKey));
        await t.pump();
        // Une SEULE écriture : le geste de la pilule et l'`onTap` de ligne ne
        // doivent pas se déclencher tous les deux.
        expect(written, <bool>[!checked], reason: 'état initial $checked');
      }
    });

    testWidgets('un tap sur le LIBELLÉ bascule aussi (ligne entière)',
        (t) async {
      final List<bool> written = <bool>[];
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
          false,
          onChanged: written.add,
        ),
      );
      await t.tap(find.text(_fieldLabel));
      await t.pump();
      expect(written, <bool>[true]);
    });

    testWidgets('readOnly : aucune écriture, mais l\'état reste LISIBLE',
        (t) async {
      for (final checked in <bool>[true, false]) {
        final List<bool> written = <bool>[];
        await t.pumpWidget(
          _app(
            _spec(
              config: const ZBooleanConfig(style: ZBooleanStyle.pill),
              readOnly: true,
            ),
            checked,
            onChanged: written.add,
          ),
        );
        expect(find.byKey(zBooleanPillKey), findsOneWidget);
        await t.tap(find.byKey(zBooleanPillKey));
        await t.pump();
        expect(written, isEmpty, reason: 'readOnly / état $checked');
        // L'état n'est jamais porté par la seule couleur : le TEXTE demeure.
        expect(find.text(checked ? 'Yes' : 'No'), findsOneWidget);
      }
    });
  });

  // ══ 8. JETONS — copyWith / lerp ═════════════════════════════════════════

  group('ZcrudTheme — les 9 jetons booleanPill*', () {
    const ZcrudTheme full = ZcrudTheme(
      booleanPillActiveColor: Color(0xFF010203),
      booleanPillInactiveColor: Color(0xFF040506),
      booleanPillActiveForegroundColor: Color(0xFF070809),
      booleanPillInactiveForegroundColor: Color(0xFF0A0B0C),
      booleanPillWidth: 65,
      booleanPillHeight: 30,
      booleanPillThumbSize: 20,
      booleanPillRadius: Radius.circular(20),
      booleanPillTextStyle: TextStyle(fontSize: 12),
    );

    test('absents du repli : `fallback` ne matérialise AUCUN d\'eux', () {
      final ZcrudTheme fb = ZcrudTheme.fallback(ThemeData.light());
      expect(fb.booleanPillActiveColor, isNull);
      expect(fb.booleanPillInactiveColor, isNull);
      expect(fb.booleanPillActiveForegroundColor, isNull);
      expect(fb.booleanPillInactiveForegroundColor, isNull);
      expect(fb.booleanPillWidth, isNull);
      expect(fb.booleanPillHeight, isNull);
      expect(fb.booleanPillThumbSize, isNull);
      expect(fb.booleanPillRadius, isNull);
      expect(fb.booleanPillTextStyle, isNull);
    });

    test('copyWith transporte CHAQUE jeton (aucun oubli de câblage)', () {
      final ZcrudTheme copied = const ZcrudTheme().copyWith(
        booleanPillActiveColor: full.booleanPillActiveColor,
        booleanPillInactiveColor: full.booleanPillInactiveColor,
        booleanPillActiveForegroundColor:
            full.booleanPillActiveForegroundColor,
        booleanPillInactiveForegroundColor:
            full.booleanPillInactiveForegroundColor,
        booleanPillWidth: full.booleanPillWidth,
        booleanPillHeight: full.booleanPillHeight,
        booleanPillThumbSize: full.booleanPillThumbSize,
        booleanPillRadius: full.booleanPillRadius,
        booleanPillTextStyle: full.booleanPillTextStyle,
      );
      expect(copied.booleanPillActiveColor, full.booleanPillActiveColor);
      expect(copied.booleanPillInactiveColor, full.booleanPillInactiveColor);
      expect(
        copied.booleanPillActiveForegroundColor,
        full.booleanPillActiveForegroundColor,
      );
      expect(
        copied.booleanPillInactiveForegroundColor,
        full.booleanPillInactiveForegroundColor,
      );
      expect(copied.booleanPillWidth, 65);
      expect(copied.booleanPillHeight, 30);
      expect(copied.booleanPillThumbSize, 20);
      expect(copied.booleanPillRadius, const Radius.circular(20));
      expect(copied.booleanPillTextStyle?.fontSize, 12);
      // …et copier SANS argument conserve (pas d'effacement silencieux).
      expect(full.copyWith().booleanPillActiveColor,
          full.booleanPillActiveColor);
    });

    test('lerp : un côté `null` ne MATÉRIALISE ni teinte ni zéro', () {
      // 🔴 Le point de `_lerpNullableColor`/`_lerpNullableFloor` : à mi-course,
      // un jeton absent d'un côté ne doit pas peindre une teinte par-dessus le
      // rôle du consommateur, ni écraser la pilule à 0 dp.
      final ZcrudTheme mid = const ZcrudTheme().lerp(full, 0.5);
      expect(mid.booleanPillActiveColor, full.booleanPillActiveColor);
      expect(mid.booleanPillWidth, 65);
      expect(mid.booleanPillHeight, 30);
      expect(mid.booleanPillThumbSize, 20);

      final ZcrudTheme back = full.lerp(const ZcrudTheme(), 0.5);
      expect(back.booleanPillActiveColor, full.booleanPillActiveColor);
      expect(back.booleanPillWidth, 65);

      // Deux côtés `null` ⇒ reste `null` (aucune matérialisation).
      final ZcrudTheme none = const ZcrudTheme().lerp(const ZcrudTheme(), 0.5);
      expect(none.booleanPillActiveColor, isNull);
      expect(none.booleanPillRadius, isNull);
      expect(none.booleanPillTextStyle, isNull);
    });

    test('lerp : deux côtés POSÉS interpolent bien (jeton non inerte)', () {
      const ZcrudTheme other = ZcrudTheme(
        booleanPillWidth: 85,
        booleanPillRadius: Radius.circular(10),
      );
      final ZcrudTheme mid = full.lerp(other, 0.5);
      expect(mid.booleanPillWidth, 75);
      expect(mid.booleanPillRadius, const Radius.circular(15));
    });
  });

  // ══ 8. VOIE B — LE SEAM DE REGISTRE ═════════════════════════════════════

  group('Voie B — `boolean` routé par le ZWidgetRegistry', () {
    ZFormController controller() => ZFormController(
          initialValues: <String, Object?>{'visited': false},
          visibleFields: <String>['visited'],
        );

    Widget mount(ZFormController c, {ZWidgetRegistry? registry}) => MaterialApp(
          home: ZcrudScope(
            widgetRegistry: registry,
            child: Scaffold(
              body: DynamicEdition(
                controller: c,
                fields: <ZFieldSpec>[_spec()],
              ),
            ),
          ),
        );

    testWidgets('AUCUN registre ⇒ rendu NATIF (immobilité prouvée)', (t) async {
      final c = controller();
      addTearDown(c.dispose);
      await t.pumpWidget(mount(c));
      expect(find.byType(ZBooleanFieldWidget), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('registre d\'un AUTRE kind ⇒ toujours NATIF (2ᵉ sens)',
        (t) async {
      final c = controller();
      addTearDown(c.dispose);
      final registry = ZWidgetRegistry()
        ..register('text', (ctx, f) => const Text('HOST'));
      await t.pumpWidget(mount(c, registry: registry));
      expect(find.byType(ZBooleanFieldWidget), findsOneWidget);
      expect(find.text('HOST'), findsNothing);
    });

    testWidgets('kind `boolean` enregistré ⇒ le widget HÔTE gagne et ÉCRIT',
        (t) async {
      final c = controller();
      addTearDown(c.dispose);
      final registry = ZWidgetRegistry()
        ..register(
          'boolean',
          (ctx, f) => SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => f.onChanged(!(f.value == true)),
              child: Text('HOST:${f.value}'),
            ),
          ),
        );
      await t.pumpWidget(mount(c, registry: registry));

      // Le natif a cédé la place.
      expect(find.byType(ZBooleanFieldWidget), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('HOST:false'), findsOneWidget);

      // …et l'écriture atteint bien la tranche (value-in-slice, AD-2).
      await t.tap(find.byType(ElevatedButton));
      await t.pump();
      expect(c.valueOf('visited'), isTrue);
      expect(find.text('HOST:true'), findsOneWidget);
    });
  });
}
