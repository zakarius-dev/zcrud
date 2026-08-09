// CR-DODLP (2026-08-09) — trois lots issus du pilote de migration DODLP :
//  T1 `cr-select-overflow`      : `isExpanded: true` sur les dropdowns natifs.
//  T2 `cr-theme-tokens-non-cables` : `inputDecoration()` lit enfin des jetons
//     (`fieldBorderColor`, `fieldFillColor`, `fieldFocusedBorderColor`), chaque
//     défaut retombant sur le rôle `ColorScheme` d'avant ⇒ hôte passif inchangé.
//  T3 `cr-defaults-dodlp-legacy` : l'aération inter-champ a un défaut non nul
//     (`zFieldGapReference` = 12) et un jeton de thème (`ZcrudTheme.fieldGap`).
//
// Toutes les gardes de ce fichier ont été prouvées MORDANTES par injection de la
// régression exacte dans le code de production (discipline R3).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Outillage ───────────────────────────────────────────────────────────────

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

/// Couleur RÉELLEMENT rendue pour le texte [text] (résolue par le
/// `DefaultTextStyle` ambiant), et non la couleur qu'un `Text` porterait.
Color? _paintedColor(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style?.color;

InputDecoration _deco(BuildContext context, {ZcrudTheme? theme}) =>
    (theme ?? ZcrudTheme.of(context)).inputDecoration(context, label: 'L');

Color _enabledBorderColor(InputDecoration d) =>
    (d.enabledBorder! as OutlineInputBorder).borderSide.color;
Color _borderColor(InputDecoration d) =>
    (d.border! as OutlineInputBorder).borderSide.color;
Color _focusedBorderColor(InputDecoration d) =>
    (d.focusedBorder! as OutlineInputBorder).borderSide.color;

Future<void> _pumpDeco(
  WidgetTester tester,
  void Function(BuildContext context, InputDecoration deco, ColorScheme scheme)
      body, {
  ZcrudTheme? extension,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        extensions: extension == null
            ? const <ThemeExtension<dynamic>>[]
            : <ThemeExtension<dynamic>>[extension],
      ),
      home: Builder(
        builder: (context) {
          body(context, _deco(context), Theme.of(context).colorScheme);
          return const SizedBox();
        },
      ),
    ),
  );
}

void main() {
  // ══ T1 — CR select-overflow ═══════════════════════════════════════════════
  group('CR select-overflow — `isExpanded` sur les dropdowns natifs', () {
    // 🔴 Propriété MESURÉE, pas déclarative : sans `isExpanded`, `DropdownButton`
    // se dimensionne sur son option la plus LARGE et sa `Row` interne déborde du
    // champ (`RenderFlex overflowed`, bandeau jaune/noir en debug). On rend donc
    // le champ dans une largeur volontairement insuffisante pour l'option longue
    // et on affirme (a) qu'AUCUNE exception de rendu n'est levée, (b) que le
    // bouton ne dépasse pas la largeur disponible.
    const longLabel =
        'Société Générale de Transit et de Consignation Internationale SARL';

    Future<void> pumpNarrowSelect(WidgetTester tester, ZFieldSpec field) async {
      final controller = _controller(<String, Object?>{field.name: 'a'});
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: DynamicEdition(
                  controller: controller,
                  fields: <ZFieldSpec>[field],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('select mono : option longue dans 200 dp ⇒ aucun débordement',
        (tester) async {
      const field = ZFieldSpec(
        name: 's',
        type: EditionFieldType.select,
        label: 'S',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: longLabel),
          ZFieldChoice(value: 'b', label: 'B'),
        ],
      );
      await pumpNarrowSelect(tester, field);

      expect(
        tester.takeException(),
        isNull,
        reason: 'un `RenderFlex overflowed` ici signifie que le bouton se '
            'dimensionne encore sur son option la plus large (isExpanded absent)',
      );
      final button = tester.widget<DropdownButton<Object?>>(
        find.byType(DropdownButton<Object?>),
      );
      expect(button.isExpanded, isTrue);
      expect(tester.getSize(find.byType(DropdownButton<Object?>)).width,
          lessThanOrEqualTo(200));
    });

    testWidgets('relation mono : même piège, même garde', (tester) async {
      const field = ZFieldSpec(
        name: 'r',
        type: EditionFieldType.relation,
        label: 'R',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: longLabel),
          ZFieldChoice(value: 'b', label: 'B'),
        ],
      );
      await pumpNarrowSelect(tester, field);

      expect(tester.takeException(), isNull);
      final button = tester.widget<DropdownButton<Object?>>(
        find.byType(DropdownButton<Object?>),
      );
      expect(button.isExpanded, isTrue);
      expect(tester.getSize(find.byType(DropdownButton<Object?>)).width,
          lessThanOrEqualTo(200));
    });
  });

  // ══ T2 — CR theme-tokens-non-cables ═══════════════════════════════════════
  group('CR theme-tokens — `inputDecoration()` lit les jetons', () {
    testWidgets(
        'hôte PASSIF inchangé : le remplissage reste `surfaceContainerHighest` '
        'et NON `surfaceColor` (que le repli pose pourtant non-null)',
        (tester) async {
      // 🔴 C'est la garde anti-régression du correctif naïf proposé par la CR
      // (`fillColor: surfaceColor ?? surfaceContainerHighest`). `fallback()`
      // pose `surfaceColor: scheme.surface` — non-null sur le chemin par défaut
      // — donc ce correctif ferait basculer TOUT hôte passif de
      // `surfaceContainerHighest` à `surface`. Les deux rôles sont ici
      // explicitement affirmés DIFFÉRENTS pour que la garde ait un sens.
      await _pumpDeco(tester, (context, deco, scheme) {
        expect(scheme.surface, isNot(scheme.surfaceContainerHighest),
            reason: 'sans cela la garde suivante serait vacante');
        expect(ZcrudTheme.of(context).surfaceColor, scheme.surface);
        expect(deco.fillColor, scheme.surfaceContainerHighest);
        expect(_borderColor(deco), scheme.outline);
        expect(_enabledBorderColor(deco), scheme.outline);
        expect(_focusedBorderColor(deco), scheme.primary);
      });
    });

    testWidgets('`fieldFillColor` pilote le remplissage', (tester) async {
      const custom = Color(0xFF102030);
      await _pumpDeco(
        tester,
        (context, deco, scheme) {
          expect(deco.fillColor, custom);
          // le jeton de remplissage ne déborde pas sur les bordures
          expect(_enabledBorderColor(deco), scheme.outline);
        },
        extension: const ZcrudTheme(fieldFillColor: custom),
      );
    });

    testWidgets(
        '`fieldBorderColor` pilote la bordure de REPOS sans teindre le focus',
        (tester) async {
      const custom = Color(0xFF204060);
      await _pumpDeco(
        tester,
        (context, deco, scheme) {
          expect(_borderColor(deco), custom);
          expect(_enabledBorderColor(deco), custom);
          // 🔴 canal d'ÉTAT préservé : le focus garde `primary`, sinon
          // repos et focus deviendraient indiscernables.
          expect(_focusedBorderColor(deco), scheme.primary);
          expect(_focusedBorderColor(deco), isNot(custom));
          expect(
            (deco.errorBorder! as OutlineInputBorder).borderSide.color,
            scheme.error,
          );
        },
        extension: const ZcrudTheme(fieldBorderColor: custom),
      );
    });

    testWidgets('`fieldFocusedBorderColor` pilote le focus seul', (tester) async {
      const custom = Color(0xFF00AA55);
      await _pumpDeco(
        tester,
        (context, deco, scheme) {
          expect(_focusedBorderColor(deco), custom);
          expect(_enabledBorderColor(deco), scheme.outline);
        },
        extension: const ZcrudTheme(fieldFocusedBorderColor: custom),
      );
    });

    testWidgets(
        '`labelColor` n\'est PAS câblé : le label flottant garde son canal de '
        'focus (`onSurfaceVariant` au repos → `primary` au focus)',
        (tester) async {
      // 🔴 Mesuré : appliquer `labelColor` au `floatingLabelStyle` écrase la
      // couleur d'état résolue par Material (`defaut.merge(floatingLabelStyle)`)
      // et le label reste à la couleur imposée MÊME AU FOCUS — un canal visible
      // perdu (classe de défaut CR-IFFD-74/CR-IFFD-63).
      const loud = Color(0xFFDD0000);
      late ColorScheme scheme;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              ZcrudTheme(labelColor: loud),
            ],
          ),
          home: Builder(builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return Scaffold(
              body: TextField(
                focusNode: node,
                decoration:
                    ZcrudTheme.of(context).inputDecoration(context, label: 'L'),
              ),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(_paintedColor(tester, 'L'), scheme.onSurfaceVariant);
      expect(_paintedColor(tester, 'L'), isNot(loud));

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(_paintedColor(tester, 'L'), scheme.primary,
          reason: 'le canal de focus du label doit survivre au thème');
      expect(_paintedColor(tester, 'L'), isNot(loud));
      // et la distinction repos/focus est bien EFFECTIVE
      expect(scheme.primary, isNot(scheme.onSurfaceVariant));
    });

    test('lerp : un côté `null` ne matérialise pas de couleur TRANSPARENTE', () {
      // 🔴 `Color.lerp(null, c, 0)` rend `c` à alpha 0 — une couleur fantôme
      // substituée au rôle de repli, qui ferait clignoter le fond/la bordure de
      // tous les champs pendant une transition de thème.
      const custom = Color(0xFF123456);
      const empty = ZcrudTheme();
      const filled = ZcrudTheme(
        fieldFillColor: custom,
        fieldFocusedBorderColor: custom,
      );
      for (final t in <double>[0, 0.5, 1]) {
        final r = empty.lerp(filled, t);
        expect(r.fieldFillColor, custom, reason: 't=$t');
        expect(r.fieldFocusedBorderColor, custom, reason: 't=$t');
        expect(r.fieldFillColor!.a, 1.0, reason: 't=$t (jamais transparent)');
      }
      // null des DEUX côtés ⇒ reste null (le consommateur applique son rôle).
      expect(empty.lerp(const ZcrudTheme(), 0.5).fieldFillColor, isNull);
    });

    test('copyWith propage les trois jetons', () {
      const a = Color(0xFF111111);
      const b = Color(0xFF222222);
      const c = Color(0xFF333333);
      final t = const ZcrudTheme().copyWith(
        fieldFillColor: a,
        fieldFocusedBorderColor: b,
        fieldBorderColor: c,
      );
      expect(t.fieldFillColor, a);
      expect(t.fieldFocusedBorderColor, b);
      expect(t.fieldBorderColor, c);
    });
  });

  // ══ T3 — CR defaults (aération inter-champ) ═══════════════════════════════
  group('CR defaults — aération inter-champ', () {
    // Champs : un `multiline` (type « bloc » ⇒ reçoit la base) suivi d'un
    // `text` (compact ⇒ n'en reçoit pas). On MESURE l'écart vertical réel entre
    // le bas du premier champ et le haut du second : c'est notre espace, pas un
    // padding ambiant du SDK (une valeur de 0 le distingue sans ambiguïté).
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'm', type: EditionFieldType.multiline, label: 'M'),
      ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'T'),
    ];

    Future<double> measureGap(
      WidgetTester tester, {
      double? interFieldGap,
      ZcrudTheme? extension,
    }) async {
      final controller =
          _controller(<String, Object?>{'m': 'aa', 't': 'bb'});
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: extension == null
                ? const <ThemeExtension<dynamic>>[]
                : <ThemeExtension<dynamic>>[extension],
          ),
          home: Scaffold(
            body: DynamicEdition(
              controller: controller,
              fields: fields,
              // 🔴 L'aération n'existe que dans la voie GROUPÉE
              // (`_membersLayout`), atteinte par une grille ou une section
              // REPLIABLE — la voie plate (`_buildFlat`, `ListView.builder`)
              // n'insère aucun espace. `collapsible: true` est donc
              // indispensable ici, et ce n'est pas un détail de montage : c'est
              // la portée réelle du défaut (cf. rapport CR).
              sections: const <ZEditionSection>[
                ZEditionSection(
                  title: 'S',
                  fields: <String>['m', 't'],
                  collapsible: true,
                ),
              ],
              interFieldGap: interFieldGap,
            ),
          ),
        ),
      );
      await tester.pump();
      final first = find.byKey(const ValueKey<String>('m'));
      final second = find.byKey(const ValueKey<String>('t'));
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      return tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy;
    }

    testWidgets('DÉFAUT (ni paramètre ni jeton) ⇒ la référence, 12 dp',
        (tester) async {
      expect(zFieldGapReference, 12);
      expect(await measureGap(tester), zFieldGapReference);
    });

    testWidgets('jeton de thème `fieldGap` ⇒ atteignable SANS paramètre',
        (tester) async {
      expect(
        await measureGap(tester, extension: const ZcrudTheme(fieldGap: 30)),
        30,
      );
    });

    testWidgets('le paramètre PRIME sur le jeton', (tester) async {
      expect(
        await measureGap(
          tester,
          interFieldGap: 4,
          extension: const ZcrudTheme(fieldGap: 30),
        ),
        4,
      );
    });

    testWidgets('`interFieldGap: 0` reste l\'échappatoire (rendu d\'avant)',
        (tester) async {
      expect(
        await measureGap(
          tester,
          interFieldGap: 0,
          extension: const ZcrudTheme(fieldGap: 30),
        ),
        0,
      );
    });

    test('table effective de `zFieldGapAfter` avec la référence', () {
      // Documente NOIR SUR BLANC ce que le défaut produit : l'espace n'est pas
      // uniforme — seuls les types « blocs » le reçoivent.
      const blocks = <EditionFieldType>[
        EditionFieldType.multiline,
        EditionFieldType.subItems,
        EditionFieldType.dynamicItem,
        EditionFieldType.signature,
        EditionFieldType.file,
        EditionFieldType.image,
        EditionFieldType.document,
        EditionFieldType.markdown,
      ];
      for (final t in EditionFieldType.values) {
        expect(
          zFieldGapAfter(t, base: zFieldGapReference),
          blocks.contains(t) ? zFieldGapReference : 0,
          reason: '$t',
        );
      }
    });
  });
}
