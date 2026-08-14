// CR DODLP — « Une plage de dates ne peut pas déclarer son amplitude maximale ».
//
// `ZDateConfig` savait borner OÙ une plage se situe (`minDateIso`/`maxDateIso`,
// `firstDateKey`/`lastDateKey`), jamais QUELLE LARGEUR elle peut avoir. La
// contrainte protège la requête (lectures et exports) : migrée sans elle, elle
// disparaîtrait SILENCIEUSEMENT — rien n'échoue, rien n'avertit, l'utilisateur
// choisit trois ans et le premier symptôme est une lenteur.
//
// Ces gardes figent les DEUX points de sémantique tranchés :
//   1. COMPTAGE — `maxDays` compte les JOURS COUVERTS, bornes incluses. Le
//      nombre déclaré et le nombre affiché sont le MÊME. `maxDays: 7` accepte
//      une plage de 7 jours et refuse celle de 8.
//   2. MOMENT DU REFUS — à la SÉLECTION : la plage n'est pas écrite, le champ
//      conserve sa valeur précédente, le motif est présenté ET annoncé.
//
// Le refus est asserté sur la VALEUR DE LA TRANCHE (`controller.valueOf`),
// jamais sur l'affichage : un champ qui montrerait l'ancienne période tout en
// ayant écrit la nouvelle serait vert à tort.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Repères de dates (janvier 2026) ────────────────────────────────────────
ZDateRange _range(int startDay, int endDay) => ZDateRange(
      start: DateTime(2026, 1, startDay),
      end: DateTime(2026, 1, endDay),
    );

/// Plage antérieure semée dans la tranche — c'est ELLE que le champ doit
/// conserver quand une sélection est refusée.
final ZDateRange _seed = _range(10, 12);

Widget _mount({
  required ZFormController controller,
  required List<ZFieldSpec> fields,
}) =>
    MaterialApp(
      // Locale par défaut (`en`) : le delegate générique du paquet est monté,
      // et `MaterialLocalizations` reste disponible pour la boîte de dialogue.
      // La table `fr` est éprouvée à part, sur le delegate lui-même.
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
      ],
      home: Scaffold(
        body: ZcrudScope(
          child: DynamicEdition(controller: controller, fields: fields),
        ),
      ),
    );

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

ZFieldSpec _spec({ZDateConfig? config, String name = 'p'}) => ZFieldSpec(
      name: name,
      type: EditionFieldType.dateRange,
      label: 'Période',
      config: config,
    );

/// Rejoue la SÉLECTION : la fermeture `onChanged` montée par le dispatcher est
/// exactement celle que `showDateRangePicker` déclenche en rendant une plage
/// (cf. `z_date_range_field_widget.dart#_pick`). C'est donc bien le chemin de
/// sélection qui est éprouvé, pas une écriture externe de la tranche.
Future<void> _select(WidgetTester tester, ZDateRange picked) async {
  tester
      .widget<ZDateRangeFieldWidget>(find.byType(ZDateRangeFieldWidget))
      .onChanged(picked);
  await tester.pumpAndSettle();
}

/// Ferme la boîte de refus si elle est ouverte (hygiène entre deux gestes).
Future<void> _dismiss(WidgetTester tester) async {
  if (find.text('Close').evaluate().isNotEmpty) {
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  }
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // 1. LE COMPTAGE — domaine pur, aucun widget.
  // ══════════════════════════════════════════════════════════════════════════
  group('amplitude : le comptage porte sur les JOURS COUVERTS, bornes incluses',
      () {
    test('une plage d\'un seul jour couvre 1 jour (et non 0)', () {
      expect(_range(1, 1).spanDays, 1);
    });

    test('du 1er au 7 janvier : 7 jours (et non 6 intervalles)', () {
      expect(_range(1, 7).spanDays, 7);
    });

    test('du 1er au 8 janvier : 8 jours', () {
      expect(_range(1, 8).spanDays, 8);
    });

    test('l\'heure des bornes est ignorée : deux journées civiles = 2 jours',
        () {
      // 🔴 Falsifiable : `end.difference(start).inDays` vaut ici 0 (2 heures
      // d'écart) — un comptage sur la durée brute rendrait 1 jour au lieu de 2.
      final ZDateRange r = ZDateRange(
        start: DateTime(2026, 1, 1, 23),
        end: DateTime(2026, 1, 2, 1),
      );
      expect(r.end.difference(r.start).inDays, 0);
      expect(r.spanDays, 2);
    });

    test('maxDays : la limite EXACTE est acceptée, un jour de plus refusé', () {
      const ZDateConfig cfg = ZDateConfig(maxDays: 7);
      expect(cfg.checkSpanDays(1), ZDateSpanVerdict.accepted);
      expect(cfg.checkSpanDays(7), ZDateSpanVerdict.accepted);
      expect(cfg.checkSpanDays(8), ZDateSpanVerdict.tooLong);
    });

    test('minDays : la limite EXACTE est acceptée, un jour de moins refusé',
        () {
      const ZDateConfig cfg = ZDateConfig(minDays: 3);
      expect(cfg.checkSpanDays(2), ZDateSpanVerdict.tooShort);
      expect(cfg.checkSpanDays(3), ZDateSpanVerdict.accepted);
      expect(cfg.checkSpanDays(90), ZDateSpanVerdict.accepted);
    });

    test('aucune amplitude déclarée : tout est accepté', () {
      const ZDateConfig cfg = ZDateConfig(minDateIso: '2026-01-01');
      expect(cfg.effectiveMaxDays, isNull);
      expect(cfg.effectiveMinDays, isNull);
      expect(cfg.checkSpanDays(10000), ZDateSpanVerdict.accepted);
    });

    test('défensif : une amplitude < 1 est IGNORÉE, jamais un champ bloqué',
        () {
      const ZDateConfig zero = ZDateConfig(maxDays: 0, minDays: 0);
      expect(zero.effectiveMaxDays, isNull);
      expect(zero.effectiveMinDays, isNull);
      expect(zero.checkSpanDays(1), ZDateSpanVerdict.accepted);
      const ZDateConfig negative = ZDateConfig(maxDays: -3);
      expect(negative.effectiveMaxDays, isNull);
      expect(negative.checkSpanDays(365), ZDateSpanVerdict.accepted);
    });

    test('défensif : minDays > maxDays ⇒ minDays ignoré, maxDays s\'applique',
        () {
      const ZDateConfig cfg = ZDateConfig(maxDays: 5, minDays: 10);
      expect(cfg.effectiveMaxDays, 5);
      expect(cfg.effectiveMinDays, isNull);
      // Aucune plage n'est prisonnière d'une déclaration contradictoire.
      expect(cfg.checkSpanDays(1), ZDateSpanVerdict.accepted);
      expect(cfg.checkSpanDays(5), ZDateSpanVerdict.accepted);
      expect(cfg.checkSpanDays(6), ZDateSpanVerdict.tooLong);
    });

    test('== / hashCode intègrent maxDays et minDays', () {
      const ZDateConfig a = ZDateConfig(maxDays: 7, minDays: 2);
      const ZDateConfig b = ZDateConfig(maxDays: 7, minDays: 2);
      const ZDateConfig otherMax = ZDateConfig(maxDays: 8, minDays: 2);
      const ZDateConfig otherMin = ZDateConfig(maxDays: 7, minDays: 3);
      const ZDateConfig none = ZDateConfig();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(otherMax)));
      expect(a, isNot(equals(otherMin)));
      expect(a, isNot(equals(none)));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. LE REFUS A LIEU À LA SÉLECTION — la tranche ne bouge pas.
  // ══════════════════════════════════════════════════════════════════════════
  group('refus à la sélection', () {
    testWidgets(
        'une plage TROP LARGE est refusée : la tranche garde la valeur '
        'antérieure', (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec(config: const ZDateConfig(maxDays: 7))],
      ));
      await tester.pump();

      // 8 jours couverts (1er → 8) pour une amplitude de 7.
      await _select(tester, _range(1, 8));

      // 🔴 L'assertion porte sur la VALEUR, pas sur l'affichage.
      expect(controller.valueOf('p'), _seed,
          reason: 'la plage refusée ne doit pas remplacer la valeur du champ');
      await _dismiss(tester);
    });

    testWidgets('la limite EXACTE est acceptée (borne incluse)',
        (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec(config: const ZDateConfig(maxDays: 7))],
      ));
      await tester.pump();

      // 7 jours couverts (1er → 7) pour une amplitude de 7.
      await _select(tester, _range(1, 7));

      expect(controller.valueOf('p'), _range(1, 7));
      expect(find.text('Close'), findsNothing,
          reason: 'aucune boîte de refus pour une plage conforme');
    });

    testWidgets('le message nomme l\'amplitude autorisée ET son comptage',
        (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec(config: const ZDateConfig(maxDays: 7))],
      ));
      await tester.pump();
      await _select(tester, _range(1, 8));

      // Le nombre affiché est celui DÉCLARÉ (7), et l'unité lève toute
      // ambiguïté : ce sont des jours, bornes incluses — pas des intervalles.
      expect(
        find.text('The period must not exceed 7 days (both bounds included)'),
        findsOneWidget,
      );
      await _dismiss(tester);
    });

    testWidgets('une plage TROP COURTE est refusée, avec son propre message',
        (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec(config: const ZDateConfig(minDays: 3))],
      ));
      await tester.pump();

      await _select(tester, _range(1, 2)); // 2 jours couverts
      expect(controller.valueOf('p'), _seed);
      expect(
        find.text('The period must cover at least 3 days (both bounds included)'),
        findsOneWidget,
      );
      await _dismiss(tester);

      await _select(tester, _range(1, 3)); // 3 jours : la limite exacte
      expect(controller.valueOf('p'), _range(1, 3));
    });

    testWidgets('le refus est ANNONCÉ, pas seulement montré (a11y)',
        (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec(config: const ZDateConfig(maxDays: 7))],
      ));
      await tester.pump();
      await _select(tester, _range(1, 8));

      // Le motif du refus est une RÉGION VIVANTE : un lecteur d'écran l'énonce
      // sans que l'utilisateur ait à aller le chercher. L'assertion cible le
      // `Semantics` qui ENVELOPPE CE message — une `liveRegion` posée ailleurs
      // dans l'arbre ne suffirait pas à la rendre verte.
      final Iterable<Semantics> live = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.text(
                  'The period must not exceed 7 days (both bounds included)'),
              matching: find.byType(Semantics),
            ),
          )
          .where((Semantics s) => s.properties.liveRegion ?? false);
      expect(live, isNotEmpty,
          reason: 'le refus doit être annoncé, pas seulement visuel');
      await _dismiss(tester);
    });

    testWidgets('la boîte de refus se referme et laisse le champ intact',
        (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec(config: const ZDateConfig(maxDays: 7))],
      ));
      await tester.pump();
      await _select(tester, _range(1, 8));

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsNothing);
      expect(controller.valueOf('p'), _seed);
      // Le champ affiche toujours la période d'avant.
      expect(find.textContaining('2026-01-10'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. CONTRE-TÉMOIN — sans amplitude déclarée, rien ne change.
  // ══════════════════════════════════════════════════════════════════════════
  group('contre-témoin : un champ SANS amplitude se comporte comme avant', () {
    testWidgets('aucune config : une plage de 3 ans est écrite sans un mot',
        (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec()],
      ));
      await tester.pump();

      final ZDateRange wide = ZDateRange(
        start: DateTime(2023, 1, 1),
        end: DateTime(2026, 1, 1),
      );
      await _select(tester, wide);
      expect(controller.valueOf('p'), wide);
      expect(find.text('Close'), findsNothing);
    });

    testWidgets('config SANS amplitude (bornes seules) : aucun refus',
        (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec(
            config: const ZDateConfig(
              minDateIso: '2020-01-01',
              maxDateIso: '2030-12-31',
            ),
          ),
        ],
      ));
      await tester.pump();

      await _select(tester, _range(1, 31)); // 31 jours
      expect(controller.valueOf('p'), _range(1, 31));
      expect(find.text('Close'), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4. COMPOSITION — les bornes continuent de jouer et se CUMULENT.
  // ══════════════════════════════════════════════════════════════════════════
  group('composition avec les bornes existantes', () {
    testWidgets('les bornes LITTÉRALES sont câblées au sélecteur',
        (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': null});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec(
            config: const ZDateConfig(
              minDateIso: '2026-01-05',
              maxDateIso: '2026-02-10',
              maxDays: 7,
            ),
          ),
        ],
      ));
      await tester.pump();

      // 🔴 Ce sont les résolveurs qui interdisent au sélecteur de proposer une
      // date hors bornes. S'ils n'étaient pas montés, le champ retomberait sur
      // 1900/2100 et la borne déclarée ne jouerait plus.
      final ZDateRangeFieldWidget w =
          tester.widget<ZDateRangeFieldWidget>(find.byType(ZDateRangeFieldWidget));
      expect(w.firstDate!(), DateTime(2026, 1, 5));
      expect(w.lastDate!(), DateTime(2026, 2, 10));
    });

    testWidgets('les bornes CROSS-CHAMP sont résolues au moment du geste',
        (tester) async {
      final ZFormController controller = _controller(<String, Object?>{
        'p': null,
        'from': DateTime(2026, 3, 2),
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec(config: const ZDateConfig(firstDateKey: 'from', maxDays: 7)),
          const ZFieldSpec(name: 'from', type: EditionFieldType.dateTime),
        ],
      ));
      await tester.pump();

      ZDateRangeFieldWidget widgetOf() => tester
          .widget<ZDateRangeFieldWidget>(find.byType(ZDateRangeFieldWidget));
      expect(widgetOf().firstDate!(), DateTime(2026, 3, 2));

      // La borne est PARESSEUSE : elle suit le champ source sans rebuild global.
      controller.setValue('from', DateTime(2026, 4, 9));
      await tester.pump();
      expect(widgetOf().firstDate!(), DateTime(2026, 4, 9));
    });

    testWidgets(
        'conforme aux bornes mais TROP LARGE : refusée — les deux contraintes '
        'se cumulent', (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec(
            config: const ZDateConfig(
              minDateIso: '2026-01-01',
              maxDateIso: '2026-12-31',
              maxDays: 7,
            ),
          ),
        ],
      ));
      await tester.pump();

      // 1er → 20 janvier : PARFAITEMENT dans les bornes du calendrier, mais
      // 20 jours de large.
      await _select(tester, _range(1, 20));
      expect(controller.valueOf('p'), _seed);
      expect(
        find.text('The period must not exceed 7 days (both bounds included)'),
        findsOneWidget,
      );
      await _dismiss(tester);

      // Réciproquement : la même amplitude, mais À L'INTÉRIEUR des bornes, passe.
      await _select(tester, _range(1, 7));
      expect(controller.valueOf('p'), _range(1, 7));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5. LE MESSAGE SUIT LA LOCALE (aucun texte codé en dur), et le NOMBRE
  //    ANNONCÉ est celui déclaré — la fenêtre de 45 jours des demandes de
  //    dépotage s'écrit `maxDays: 45` et se lit « 45 jours ».
  // ══════════════════════════════════════════════════════════════════════════
  group('le message est localisé et annonce le nombre DÉCLARÉ', () {
    testWidgets('45 jours déclarés ⇒ 45 jours annoncés', (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec(config: const ZDateConfig(maxDays: 45))],
      ));
      await tester.pump();

      // 20 jours tiennent dans 45 : aucun refus.
      await _select(tester, _range(1, 20));
      expect(controller.valueOf('p'), _range(1, 20));
      expect(find.text('Close'), findsNothing);

      // Du 1er janvier au 1er mars : 60 jours couverts.
      final ZDateRange tooWide = ZDateRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 3, 1),
      );
      expect(tooWide.spanDays, 60);
      await _select(tester, tooWide);
      expect(
        find.text('The period must not exceed 45 days (both bounds included)'),
        findsOneWidget,
      );
      expect(controller.valueOf('p'), _range(1, 20));
      await _dismiss(tester);
    });

    test('les DEUX tables composent la phrase, comptage explicite (l10n)',
        () async {
      const ZcrudLocalizationsDelegate delegate = ZcrudLocalizationsDelegate();
      final ZcrudLocalizations fr = await delegate.load(const Locale('fr'));
      final ZcrudLocalizations en = await delegate.load(const Locale('en'));
      // 🔴 Le libellé d'unité PORTE le comptage : sans « bornes incluses », un
      // hôte ne saurait pas si 7 désigne 7 jours ou 7 intervalles.
      expect(
        '${fr.resolve('dateRangeTooLong')} 7 ${fr.resolve('daysInclusive')}',
        'La période ne doit pas dépasser 7 jours (bornes incluses)',
      );
      expect(
        '${fr.resolve('dateRangeTooShort')} 3 ${fr.resolve('daysInclusive')}',
        'La période doit couvrir au moins 3 jours (bornes incluses)',
      );
      expect(
        '${en.resolve('dateRangeTooLong')} 7 ${en.resolve('daysInclusive')}',
        'The period must not exceed 7 days (both bounds included)',
      );
      // Aucune des trois clés ne retombe sur elle-même (clé absente d'une table).
      for (final String key in <String>[
        'dateRangeTooLong',
        'dateRangeTooShort',
        'daysInclusive',
      ]) {
        expect(fr.maybeResolve(key), isNotNull, reason: '$key absent de `fr`');
        expect(en.maybeResolve(key), isNotNull, reason: '$key absent de `en`');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 6. BOUT EN BOUT — le SÉLECTEUR RÉEL, piloté jusqu'à la confirmation.
  //    Aucune fermeture invoquée à la main : c'est `showDateRangePicker` qui
  //    rend la plage, donc bien le geste de SÉLECTION qui est éprouvé.
  // ══════════════════════════════════════════════════════════════════════════
  group('bout en bout : le sélecteur Material réel', () {
    /// Ouvre le sélecteur, bascule sur sa SAISIE CLAVIER (le pilotage jour par
    /// jour du calendrier est instable en test), inscrit les deux bornes au
    /// format du sélecteur (`mm/dd/yyyy`) et confirme.
    Future<void> pick(WidgetTester tester, String start, String end) async {
      await tester.tap(find.byType(ZDateRangeFieldWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), start);
      await tester.enterText(find.byType(TextField).at(1), end);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'une période trop large confirmée dans le sélecteur est REFUSÉE : le '
        'champ garde sa valeur antérieure', (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec(config: const ZDateConfig(maxDays: 7))],
      ));
      await tester.pump();

      // 1er → 8 janvier : 8 jours couverts pour une amplitude de 7.
      await pick(tester, '01/01/2026', '01/08/2026');

      expect(controller.valueOf('p'), _seed,
          reason: 'la sélection refusée ne remplace pas la valeur du champ');
      expect(
        find.text('The period must not exceed 7 days (both bounds included)'),
        findsOneWidget,
      );
      await _dismiss(tester);
      // Et le champ montre toujours la période d'avant.
      expect(find.textContaining('2026-01-10'), findsOneWidget);
    });

    testWidgets(
        'la même sélection à la limite EXACTE est confirmée et écrite',
        (tester) async {
      final ZFormController controller =
          _controller(<String, Object?>{'p': _seed});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: <ZFieldSpec>[_spec(config: const ZDateConfig(maxDays: 7))],
      ));
      await tester.pump();

      // 1er → 7 janvier : 7 jours couverts, la limite exacte.
      await pick(tester, '01/01/2026', '01/07/2026');

      expect(controller.valueOf('p'), _range(1, 7));
      expect(find.text('Close'), findsNothing,
          reason: 'aucune boîte de refus pour une période conforme');
    });
  });
}
