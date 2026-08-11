/// **Lot 4** — gardes de `ZDailyTasksView`.
///
/// Ce que ces gardes MESURENT :
///
/// 1. le **`default` obligatoire** : une variante inconnue est **ABSENTE** sans
///    `unknownTaskBuilder`, **rendue** avec — et **jamais** un throw, y compris
///    pour une variante **hostile** qui usurpe un `kind` connu ;
/// 2. l'**horloge injectée** : aucun `DateTime.now()` dans les deux fichiers du
///    lot (garde de source à contre-preuve) ;
/// 3. la **géométrie RENDUE** des cibles de jour ≥ 48 dp, à 360 dp comme à
///    800 dp — mesurée par `tester.getSize`, jamais par la présence d'un
///    `ConstrainedBox` ;
/// 4. le **contenu** de l'état vide injecté, pas sa seule présence ;
/// 5. la **divergence ②** de la référence : l'appariement du legacy
///    (`primary` sur `primaryContainer`) est mesuré SOUS le plancher texte, et
///    celui du socle au-dessus, dans les DEUX luminosités ;
/// 6. `dueCount` reste la source unique du kernel (`<= 0` ⇒ aucune ligne).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsFlag, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import '../support/z_sources.dart' show stripped;

// Libellés INJECTÉS de test.
const String kDuePrefix = 'DUE_';
const String kExamPrefix = 'EXAM_';
const String kUnknownPrefix = 'UNKNOWN_';
const String kEmptyMarker = 'EMPTY_STATE_CONTENT';

final DateTime kNow = DateTime.utc(2026, 8, 6, 10, 30); // jeudi

/// Examen de test — implémente le PORT NEUTRE (aucune dépendance à `zcrud_exam`).
class FakeExam implements ZApproachingExam {
  const FakeExam(this.id, this.date, {this.approaching = true});

  final String id;
  @override
  final DateTime? date;
  final bool approaching;

  @override
  bool isApproaching(DateTime now) => approaching;

  @override
  int? daysUntil(DateTime now) => date?.difference(now).inDays;
}

/// 🔴 Variante **INCONNUE** de la famille ouverte — exactement ce qu'un
/// satellite futur produirait, sans toucher au kernel (AD-4).
class PodcastTask implements ZDailyStudyTask {
  const PodcastTask();
  @override
  String get kind => 'podcast';
}

/// 🔴 Variante **HOSTILE** : elle usurpe un `kind` connu sans en avoir le type.
/// Un dispatch qui ferait confiance au seul `kind` lèverait ici.
class ImpostorExamTask implements ZDailyStudyTask {
  const ImpostorExamTask();
  @override
  String get kind => 'exam';
}

/// Monte la vue avec des builders qui rendent un texte OBSERVABLE.
Future<void> pumpView(
  WidgetTester tester, {
  int dueCount = 0,
  List<ZApproachingExam> exams = const <ZApproachingExam>[],
  DateTime? selectedDay,
  ValueChanged<DateTime>? onDaySelected,
  ZUnknownTaskBuilder? unknownTaskBuilder,
  Widget? emptyState,
  ZDailyDayLabelBuilder? monthLabelBuilder,
  bool withDueBuilder = true,
  bool withExamBuilder = true,
  double width = 800,
  ThemeData? theme,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: ZDailyTasksView(
            now: kNow,
            dueCount: dueCount,
            exams: exams,
            selectedDay: selectedDay,
            onDaySelected: onDaySelected,
            weekdayLabelBuilder: (_, DateTime d) => 'W${d.weekday}',
            dayLabelBuilder: (_, DateTime d) => '${d.day}',
            monthLabelBuilder: monthLabelBuilder,
            dueCardsBuilder: withDueBuilder
                ? (_, ZDueCardsTask t) => Text('$kDuePrefix${t.count}')
                : null,
            examBuilder: withExamBuilder
                ? (_, ZExamTask t) => Text('$kExamPrefix${t.daysUntil}')
                : null,
            unknownTaskBuilder: unknownTaskBuilder,
            emptyState: emptyState,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('① zStudyWeekDays — PURE, TOTALE, DÉTERMINISTE', () {
    test('7 jours croissants, lundi en tête, contenant le jour donné', () {
      final List<DateTime> days = zStudyWeekDays(kNow);
      expect(days, hasLength(7));
      expect(days.first.weekday, DateTime.monday);
      expect(days.last.weekday, DateTime.sunday);
      for (int i = 1; i < days.length; i++) {
        expect(days[i].difference(days[i - 1]).inHours, 24);
      }
      expect(days.any((DateTime d) => zStudyIsSameDay(d, kNow)), isTrue);
      expect(days.every((DateTime d) => d.isUtc), isTrue);
    });

    test('weekStart réglable — dimanche en tête', () {
      final List<DateTime> days = zStudyWeekDays(
        kNow,
        weekStart: DateTime.sunday,
      );
      expect(days.first.weekday, DateTime.sunday);
      expect(days, hasLength(7));
      expect(days.any((DateTime d) => zStudyIsSameDay(d, kNow)), isTrue);
    });

    test('🔴 traverse mois ET année sans trou (débordement normalisé)', () {
      // 1ᵉʳ janvier 2027 est un vendredi : sa semaine commence en 2026.
      final List<DateTime> days = zStudyWeekDays(DateTime.utc(2027, 1, 1));
      expect(days.first, DateTime.utc(2026, 12, 28));
      expect(days.last, DateTime.utc(2027, 1, 3));
      for (int i = 1; i < days.length; i++) {
        expect(days[i].difference(days[i - 1]).inHours, 24);
      }
    });

    test('la semaine d\'un instant de bascule d\'heure fait 7 × 24 h et sort en '
        'UTC', () {
      // ⚠️ **PORTÉE DÉCLARÉE HONNÊTEMENT.** Fin mars : bascule d'heure d'été en
      // Europe. Ce test ne peut PAS distinguer une arithmétique locale d'une
      // arithmétique UTC **sur un hôte dont le fuseau est UTC** — et c'est le
      // cas de cette machine (`date` ⇒ « GMT »). Mesuré : l'injection R3
      // « horloge locale » laissait ce test VERT.
      //
      // Il vérifie donc la FORME (7 jours UTC, pas de trou, 24 h d'écart), et
      // la propriété DST elle-même est portée par la garde de SOURCE du
      // groupe ⑦ (`DateTime(` nu banni), qui, elle, mord. Une garde qui ne peut
      // pas rougir n'est pas gardée : elle est déclarée.
      final List<DateTime> days = zStudyWeekDays(DateTime(2026, 3, 30, 12));
      expect(days, hasLength(7));
      expect(days.map((DateTime d) => d.day).toSet(), hasLength(7));
      expect(days.every((DateTime d) => d.isUtc), isTrue);
      for (int i = 1; i < days.length; i++) {
        expect(
          days[i].difference(days[i - 1]).inHours,
          24,
          reason: '🔴 dérive de calendrier entre ${days[i - 1]} et ${days[i]}',
        );
      }
    });

    test('idempotence — la semaine de chacun de ses jours est la même', () {
      final List<DateTime> days = zStudyWeekDays(kNow);
      for (final DateTime d in days) {
        expect(zStudyWeekDays(d), days);
      }
    });
  });

  group('② dispatch `kind` + `default` OBLIGATOIRE', () {
    test('🔴 les discriminants sont LIÉS au kernel (jamais recopiés à l\'aveugle)',
        () {
      expect(
        const ZDueCardsTask(1).kind,
        ZDailyTasksView.dueCardsKind,
        reason: '🔴 le kernel a renommé `kind` : le dispatch tomberait dans le '
            '`default` et la ligne dues disparaîtrait SILENCIEUSEMENT.',
      );
      expect(
        ZExamTask(const FakeExam('e', null), 0).kind,
        ZDailyTasksView.examKind,
      );
    });

    testWidgets('les deux variantes connues sont rendues par LEUR builder', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        dueCount: 7,
        exams: <ZApproachingExam>[FakeExam('e1', kNow.add(const Duration(days: 3)))],
      );
      expect(find.text('${kDuePrefix}7'), findsOneWidget);
      expect(find.text('${kExamPrefix}3'), findsOneWidget);
    });

    testWidgets('un builder ABSENT ⇒ la variante est ABSENTE (AD-4), '
        'jamais un placeholder', (WidgetTester tester) async {
      await pumpView(
        tester,
        dueCount: 7,
        exams: <ZApproachingExam>[FakeExam('e1', kNow.add(const Duration(days: 3)))],
        withDueBuilder: false,
      );
      expect(find.textContaining(kDuePrefix), findsNothing);
      expect(find.text('${kExamPrefix}3'), findsOneWidget);
      // …et la liste ne réserve AUCUNE place pour la ligne absente.
      expect(
        tester.widget<ListView>(find.byKey(ZDailyTasksView.listKey)).semanticChildCount,
        1,
        reason: '🔴 la liste compte encore la variante non rendue.',
      );
    });

    test('🔴 une variante INCONNUE : absente sans builder, rendue avec — '
        'et JAMAIS un throw', () {
      const PodcastTask podcast = PodcastTask();
      const ImpostorExamTask impostor = ImpostorExamTask();

      for (final ZDailyStudyTask task in <ZDailyStudyTask>[podcast, impostor]) {
        expect(
          () => zDailyTaskTileBuilder(task),
          returnsNormally,
          reason: '🔴 la variante `${task.kind}` a levé — le `default` '
              'obligatoire n\'est pas là, ou un cast fuit (AD-10).',
        );
        expect(
          zDailyTaskTileBuilder(
            task,
            // Les DEUX builders connus sont fournis : si le dispatch se fiait
            // au seul `kind`, l'imposteur passerait par `examBuilder`.
            dueCardsBuilder: (_, _) => const SizedBox.shrink(),
            examBuilder: (_, _) => const SizedBox.shrink(),
          ),
          isNull,
          reason: '🔴 sans `unknownTaskBuilder`, la variante `${task.kind}` '
              'doit être ABSENTE.',
        );
        expect(
          zDailyTaskTileBuilder(
            task,
            unknownTaskBuilder: (_, _) => const SizedBox.shrink(),
          ),
          isNotNull,
          reason: '🔴 avec `unknownTaskBuilder`, la variante `${task.kind}` '
              'doit être rendue.',
        );
      }

      // 🔴 CONTRE-PREUVE de non-vacuité (structurelle) : une variante CONNUE
      // dont SEUL `unknownTaskBuilder` est fourni reste ABSENTE — preuve que le
      // `default` ne ramasse pas tout. Un dispatch dégénéré (« tout au
      // `default` ») rendrait ici un constructeur non nul.
      expect(
        zDailyTaskTileBuilder(
          const ZDueCardsTask(3),
          unknownTaskBuilder: (_, _) => const SizedBox.shrink(),
        ),
        isNull,
        reason: '🔴 une variante CONNUE est passée par le `default` — le '
            'dispatch ne discrimine rien.',
      );
      expect(
        zDailyTaskTileBuilder(
          ZExamTask(const FakeExam('e', null), 0),
          unknownTaskBuilder: (_, _) => const SizedBox.shrink(),
        ),
        isNull,
      );
    });

    testWidgets('🔴 une variante HOSTILE (kind usurpé) est RENDUE par `unknown`, '
        'sous un vrai BuildContext, sans exception', (WidgetTester tester) async {
      // 🔴 Première rédaction VACANTE, démasquée par l'injection R3
      // « cast sans vérification » : elle montait `ZDailyTasksView` avec un
      // `exams` ORDINAIRE, donc l'imposteur n'entrait JAMAIS dans l'arbre (la
      // vue agrège elle-même : aucune porte ne laisse passer une tâche forgée).
      // Le test restait vert avec un `task as ZExamTask` nu. On exerce donc le
      // site de dispatch LUI-MÊME, sous un vrai contexte : c'est là que le cast
      // lèverait.
      const ImpostorExamTask impostor = ImpostorExamTask();
      final Widget? Function(BuildContext)? builder = zDailyTaskTileBuilder(
        impostor,
        // Le builder d'examen EST fourni : si le dispatch se fiait au seul
        // `kind`, l'imposteur passerait par lui et le cast lèverait.
        examBuilder: (_, ZExamTask t) => Text('$kExamPrefix${t.daysUntil}'),
        unknownTaskBuilder: (_, ZDailyStudyTask t) =>
            Text('$kUnknownPrefix${t.kind}'),
      );
      expect(builder, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (BuildContext c) => builder!(c)!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // …et c'est bien la branche INCONNUE qui a rendu, pas celle d'examen.
      expect(find.text('${kUnknownPrefix}exam'), findsOneWidget);
      expect(find.textContaining(kExamPrefix), findsNothing);
    });

    testWidgets('CONTRE-PREUVE — un VRAI ZExamTask, lui, passe par `examBuilder`',
        (WidgetTester tester) async {
      final Widget? Function(BuildContext)? builder = zDailyTaskTileBuilder(
        ZExamTask(const FakeExam('e', null), 5),
        examBuilder: (_, ZExamTask t) => Text('$kExamPrefix${t.daysUntil}'),
        unknownTaskBuilder: (_, ZDailyStudyTask t) =>
            Text('$kUnknownPrefix${t.kind}'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (BuildContext c) => builder!(c)!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('${kExamPrefix}5'), findsOneWidget);
      expect(find.textContaining(kUnknownPrefix), findsNothing);
    });
  });

  group('③ `dueCount` est la source UNIQUE (règle du kernel, non refaite)', () {
    testWidgets('0 et négatif ⇒ aucune ligne dues', (WidgetTester tester) async {
      for (final int n in <int>[0, -5]) {
        await pumpView(tester, dueCount: n);
        expect(
          find.textContaining(kDuePrefix),
          findsNothing,
          reason: '🔴 une ligne dues est rendue pour dueCount=$n',
        );
      }
      // Contre-preuve : 1 en produit une.
      await pumpView(tester, dueCount: 1);
      expect(find.text('${kDuePrefix}1'), findsOneWidget);
    });

    testWidgets('le compte affiché est EXACTEMENT celui de l\'hôte '
        '(jamais recalculé)', (WidgetTester tester) async {
      await pumpView(
        tester,
        dueCount: 42,
        exams: <ZApproachingExam>[
          FakeExam('a', kNow.add(const Duration(days: 1))),
          FakeExam('b', kNow.add(const Duration(days: 2))),
        ],
      );
      expect(find.text('${kDuePrefix}42'), findsOneWidget);
    });
  });

  group('④ état vide INJECTÉ — le CONTENU, pas la présence', () {
    testWidgets('fourni ⇒ rendu et observable ; absent ⇒ aucun nœud', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, emptyState: const Text(kEmptyMarker));
      expect(find.byKey(ZDailyTasksView.emptyKey), findsOneWidget);
      expect(
        find.text(kEmptyMarker),
        findsOneWidget,
        reason: '🔴 la clé est là mais le CONTENU injecté ne l\'est pas — '
            'exactement la garde vacante à ne pas écrire.',
      );
      expect(find.byKey(ZDailyTasksView.listKey), findsNothing);

      await pumpView(tester);
      expect(find.byKey(ZDailyTasksView.emptyKey), findsNothing);
      expect(find.text(kEmptyMarker), findsNothing);
    });

    testWidgets('dès qu\'une ligne existe, l\'état vide DISPARAÎT', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        dueCount: 3,
        emptyState: const Text(kEmptyMarker),
      );
      expect(find.text(kEmptyMarker), findsNothing);
      expect(find.text('${kDuePrefix}3'), findsOneWidget);
      expect(find.byKey(ZDailyTasksView.listKey), findsOneWidget);
    });
  });

  group('⑤ bandeau — sélection, a11y, géométrie RENDUE', () {
    testWidgets('7 cellules ; UNE SEULE est annoncée sélectionnée, et c\'est '
        'la bonne', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpView(tester, onDaySelected: (_) {});
      final List<DateTime> days = zStudyWeekDays(kNow);
      expect(days, hasLength(7));

      final List<DateTime> announcedSelected = <DateTime>[];
      for (final DateTime d in days) {
        final String iso = d.toIso8601String().substring(0, 10);
        final Finder cell = find.byKey(
          ValueKey<String>('${ZDailyTasksView.dayKeyPrefix}$iso'),
        );
        expect(cell, findsOneWidget);
        final SemanticsNode node = tester.getSemantics(cell);
        // Contenu : l'annonce porte les DEUX libellés injectés, jamais un mot
        // ajouté par le socle.
        expect(node.label, 'W${d.weekday} ${d.day}');
        expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
        if (node.hasFlag(SemanticsFlag.isSelected)) announcedSelected.add(d);
      }
      handle.dispose();

      expect(announcedSelected, hasLength(1));
      expect(zStudyIsSameDay(announcedSelected.single, kNow), isTrue);
    });

    testWidgets('l\'annonce accessible INJECTÉE prime sur la composition', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZDailyTasksView(
              now: kNow,
              dueCount: 0,
              weekdayLabelBuilder: (_, DateTime d) => 'W${d.weekday}',
              dayLabelBuilder: (_, DateTime d) => '${d.day}',
              daySemanticLabelBuilder: (_, DateTime d) => 'ANNOUNCE_${d.day}',
              onDaySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final DateTime first = zStudyWeekDays(kNow).first;
      final String iso = first.toIso8601String().substring(0, 10);
      final SemanticsNode node = tester.getSemantics(
        find.byKey(ValueKey<String>('${ZDailyTasksView.dayKeyPrefix}$iso')),
      );
      handle.dispose();
      expect(node.label, 'ANNOUNCE_${first.day}');
    });

    testWidgets('un tap renvoie le JOUR exact (UTC, normalisé)', (
      WidgetTester tester,
    ) async {
      final List<DateTime> received = <DateTime>[];
      await pumpView(tester, onDaySelected: received.add);
      final DateTime target = zStudyWeekDays(kNow).first;
      final String iso = target.toIso8601String().substring(0, 10);
      await tester.tap(
        find.byKey(ValueKey<String>('${ZDailyTasksView.dayKeyPrefix}$iso')),
      );
      await tester.pumpAndSettle();
      expect(received, <DateTime>[target]);
      expect(received.single.isUtc, isTrue);
    });

    testWidgets('🔴 AD-4 — sans `onDaySelected`, AUCUN InkWell (jamais un tap '
        'mort)', (WidgetTester tester) async {
      await pumpView(tester);
      expect(
        find.descendant(
          of: find.byKey(ZDailyTasksView.bandKey),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      // Contre-preuve : avec callback, ils sont là — les 7.
      await pumpView(tester, onDaySelected: (_) {});
      expect(
        find.descendant(
          of: find.byKey(ZDailyTasksView.bandKey),
          matching: find.byType(InkWell),
        ),
        findsNWidgets(7),
      );
    });

    // 320 dp = iPhone SE / petit Android : la largeur où sept cellules au
    // plancher NE TIENNENT PAS, donc celle où la compression du legacy mordrait.
    // Son absence rendait la garde inerte face à l'injection R3.
    for (final double width in <double>[320, 360, 500, 800, 1200]) {
      testWidgets('🔴 AD-13 — cible ≥ 48 dp en GÉOMÉTRIE RENDUE à $width dp', (
        WidgetTester tester,
      ) async {
        await pumpView(tester, width: width, onDaySelected: (_) {});
        final List<DateTime> days = zStudyWeekDays(kNow);
        for (final DateTime d in days) {
          final String iso = d.toIso8601String().substring(0, 10);
          // 🔴 On mesure le `Container` — la surface RÉELLEMENT peinte et
          // RÉELLEMENT tappable (enfant de l'`InkWell`) — et surtout PAS le
          // `KeyedSubtree` externe, qui inclut la marge : la marge n'est pas
          // une cible. Mesuré : à 360 dp, l'écart entre les deux nœuds est de
          // 49.1 dp contre 45.1 dp — la garde posée sur le nœud externe restait
          // VERTE alors que la cible réelle était sous le plancher (démasqué
          // par l'injection R3 « pas de défilement en étroit »).
          final Finder cell = find.descendant(
            of: find.byKey(
              ValueKey<String>('${ZDailyTasksView.dayKeyPrefix}$iso'),
            ),
            matching: find.byType(Container),
          );
          expect(cell, findsOneWidget);
          final Size size = tester.getSize(cell);
          expect(
            size.width,
            greaterThanOrEqualTo(48.0),
            reason: '🔴 cible de ${size.width} dp de large à $width dp — le '
                'legacy comprime, le socle doit défiler.',
          );
          expect(
            size.height,
            greaterThanOrEqualTo(48.0),
            reason: '🔴 cible de ${size.height} dp de haut à $width dp.',
          );
        }
      });
    }

    testWidgets('🔴 le défilement horizontal n\'apparaît QUE quand il le faut', (
      WidgetTester tester,
    ) async {
      Finder bandScroll() => find.descendant(
        of: find.byKey(ZDailyTasksView.bandKey),
        matching: find.byType(SingleChildScrollView),
      );
      await pumpView(tester, width: 1200, onDaySelected: (_) {});
      expect(
        bandScroll(),
        findsNothing,
        reason: '🔴 un `Scrollable` est interposé à largeur suffisante — le '
            'rendu diverge du legacy sans raison.',
      );
      await pumpView(tester, width: 360, onDaySelected: (_) {});
      expect(bandScroll(), findsOneWidget);
    });

    testWidgets('le mois n\'est rendu qu\'au-delà de la bascule, et seulement '
        'si son builder est fourni', (WidgetTester tester) async {
      await pumpView(
        tester,
        width: 800,
        monthLabelBuilder: (_, DateTime d) => 'M${d.month}',
      );
      expect(find.text('M8'), findsWidgets);

      await pumpView(
        tester,
        width: 360,
        monthLabelBuilder: (_, DateTime d) => 'M${d.month}',
      );
      expect(find.text('M8'), findsNothing);

      // Sans builder : absent même en large (AD-4).
      await pumpView(tester, width: 800);
      expect(find.text('M8'), findsNothing);
    });

    testWidgets('🔴 la sélection a un SECOND canal : l\'épaisseur du liseré', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, onDaySelected: (_) {});
      final DateTime selectedDay = zStudyDayOf(kNow);
      final List<DateTime> days = zStudyWeekDays(kNow);
      final Set<double> selectedWidths = <double>{};
      final Set<double> otherWidths = <double>{};
      for (final DateTime d in days) {
        final String iso = d.toIso8601String().substring(0, 10);
        final Container box = tester.widget<Container>(
          find.descendant(
            of: find.byKey(ValueKey<String>('${ZDailyTasksView.dayKeyPrefix}$iso')),
            matching: find.byType(Container),
          ),
        );
        final double w =
            (box.decoration! as BoxDecoration).border!.top.width;
        (zStudyIsSameDay(d, selectedDay) ? selectedWidths : otherWidths).add(w);
      }
      expect(selectedWidths, <double>{ZDailyTasksReference.selectedBorderWidth});
      expect(otherWidths, <double>{ZDailyTasksReference.borderWidth});
      expect(
        ZDailyTasksReference.selectedBorderWidth,
        isNot(ZDailyTasksReference.borderWidth),
        reason: '🔴 sonde MOLLE : les deux épaisseurs sont égales, le second '
            'canal n\'existe pas.',
      );
    });
  });

  group('⑥ contraste — MESURÉ sur le rendu, jamais supposé', () {
    // 🔴 Historique consigné : une première rédaction SUPPOSAIT que
    // l'appariement du legacy (`primary` sur `primaryContainer`) passait sous
    // le plancher AA, et faisait diverger le socle « pour le corriger ». La
    // mesure ci-dessous l'a INFIRMÉ (pire cas 4.97 ≥ 4.5) : la divergence a été
    // RETIRÉE, et il ne reste que cette garde. Elle mesure la propriété qui
    // compte — le contraste RÉELLEMENT rendu — au lieu de défendre une
    // conclusion que personne n'avait vérifiée.
    const List<int> seeds = <int>[
      0xFF6750A4, 0xFF2196F3, 0xFF4CAF50, 0xFFFF9800, 0xFFF44336, 0xFF009688,
      0xFF9C27B0, 0xFF000000, 0xFFFFFFFF, 0xFF888888, 0xFFFFEB3B, 0xFF3F51B5,
    ];

    testWidgets('🔴 le premier plan RENDU de la cellule sélectionnée tient le '
        'plancher AA sur 12 graines × 2 luminosités', (
      WidgetTester tester,
    ) async {
      final DateTime selectedDay = zStudyDayOf(kNow);
      final String iso = selectedDay.toIso8601String().substring(0, 10);
      double worst = double.infinity;

      for (final int seed in seeds) {
        for (final Brightness b in Brightness.values) {
          final ColorScheme scheme = ColorScheme.fromSeed(
            seedColor: Color(seed),
            brightness: b,
          );
          await pumpView(
            tester,
            theme: ThemeData(colorScheme: scheme),
            onDaySelected: (_) {},
          );
          final Finder cell = find.byKey(
            ValueKey<String>('${ZDailyTasksView.dayKeyPrefix}$iso'),
          );
          // On lit les couleurs RÉELLEMENT peintes — le fond de la décoration
          // et la couleur du style du texte — jamais des rôles re-dérivés à
          // côté du rendu (sinon la garde mesurerait sa propre hypothèse).
          final Container box = tester.widget<Container>(
            find.descendant(of: cell, matching: find.byType(Container)),
          );
          final Color background =
              (box.decoration! as BoxDecoration).color!;
          final Text number = tester.widget<Text>(
            find.descendant(
              of: cell,
              matching: find.text('${selectedDay.day}'),
            ),
          );
          final double ratio = zContrastRatio(number.style!.color!, background);
          if (ratio < worst) worst = ratio;
          expect(
            ratio,
            greaterThanOrEqualTo(ZDailyTasksReference.textMinContrast),
            reason: '🔴 contraste rendu de ${ratio.toStringAsFixed(2)}:1 pour '
                'la graine ${seed.toRadixString(16)} en $b.',
          );
        }
      }
      // Non-vacuité : la sonde a vraiment mesuré (et pas un ratio infini d'un
      // couple identique, ni une valeur laissée à son initialisation).
      expect(worst, lessThan(21.0));
      expect(worst, greaterThan(1.0));
    });

    testWidgets('🔴 PARITÉ — le socle peint le MÊME rôle que le legacy '
        '(`primary`), pas le rôle nominal M3', (WidgetTester tester) async {
      final ColorScheme scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
      );
      await pumpView(
        tester,
        theme: ThemeData(colorScheme: scheme),
        onDaySelected: (_) {},
      );
      final DateTime selectedDay = zStudyDayOf(kNow);
      final String iso = selectedDay.toIso8601String().substring(0, 10);
      final Text number = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey<String>('${ZDailyTasksView.dayKeyPrefix}$iso')),
          matching: find.text('${selectedDay.day}'),
        ),
      );
      expect(number.style!.color, scheme.primary);
      // Sonde MORDANTE : les deux rôles sont bien distincts dans ce schéma —
      // sans quoi l'assertion ci-dessus serait vraie quoi qu'on peigne.
      expect(scheme.primary, isNot(scheme.onPrimaryContainer));
    });
  });

  group('⑦ pureté de source du lot', () {
    const List<String> lotFiles = <String>[
      'lib/src/presentation/z_daily_tasks_view.dart',
      'lib/src/presentation/z_daily_tasks_reference.dart',
    ];

    /// Scanner RÉEL — partagé avec sa contre-preuve.
    List<String> scanClock(List<String> lines, String path) {
      final List<RegExp> banned = <RegExp>[
        RegExp(r'DateTime\.now\('),
        RegExp(r'\.toLocal\('),
        RegExp(r'\bclock\.now\b'),
        // 🔴 Le constructeur NU `DateTime(…)` construit en heure LOCALE : une
        // semaine bâtie ainsi dérive de 23/25 h à chaque changement d'heure.
        // C'est cette règle-ci qui porte réellement la propriété DST — la
        // garde comportementale, elle, ne peut pas rougir sur un hôte en UTC
        // (mesuré : injection R3 « horloge locale » verte).
        // `DateTime.utc(`/`DateTime.now(`/`DateTime.parse(` ne matchent pas :
        // le motif exige une parenthèse IMMÉDIATEMENT après le type.
        RegExp(r'\bDateTime\('),
      ];
      final List<String> hits = <String>[];
      for (int i = 0; i < lines.length; i++) {
        final String raw = lines[i];
        final String t = raw.trimLeft();
        if (t.startsWith('///') || t.startsWith('//')) continue;
        for (final RegExp p in banned) {
          if (p.hasMatch(raw)) hits.add('$path:${i + 1} → ${raw.trim()}');
        }
      }
      return hits;
    }

    test('🔴 aucune horloge interne (R5) — `now` est le seul référentiel', () {
      final List<String> hits = <String>[];
      for (final String path in lotFiles) {
        final File f = File(path);
        expect(f.existsSync(), isTrue, reason: 'sonde cassée : $path');
        // 🔴 DÉPOUILLÉ (campagne dartdoc P0A) : `stripped` retire aussi les
        // commentaires de fin de ligne et les blocs `/* … */`.
        hits.addAll(scanClock(stripped(f), path));
      }
      expect(hits, isEmpty, reason: '🔴 horloge interne :\n${hits.join('\n')}');
    });

    test('🔴 CONTRE-PREUVE — le scanner n\'est pas aveugle', () {
      expect(
        scanClock(<String>['  final d = DateTime.now();'], 'f.dart'),
        isNotEmpty,
      );
      expect(scanClock(<String>['  final d = x.toLocal();'], 'f.dart'), isNotEmpty);
      // 🔴 Le constructeur NU est attrapé — c'est la règle qui porte la
      // propriété DST à la place de la garde comportementale, inatteignable
      // sur un hôte en UTC.
      expect(
        scanClock(<String>['  return DateTime(m.year, m.month, m.day);'], 'f.dart'),
        isNotEmpty,
      );
      // …mais `DateTime.utc(` et `DateTime.parse(` ne sont PAS des faux
      // positifs (une garde qui crie au loup est une garde qu'on désactive).
      expect(
        scanClock(
          <String>[
            '  return DateTime.utc(m.year, m.month, m.day);',
            '  final d = DateTime.parse(s);',
          ],
          'f.dart',
        ),
        isEmpty,
      );
      // …et la prose peut NOMMER ce qu'elle interdit.
      expect(
        scanClock(<String>['/// aucun `DateTime.now()` ici (R5).'], 'f.dart'),
        isEmpty,
      );
    });

    test('🔴 le fichier de référence ne demande AUCUNE exemption FR-26', () {
      final File guard = File(
        'test/presentation/z_widgets_hardcode_scan_test.dart',
      );
      expect(guard.existsSync(), isTrue);
      final String src = guard.readAsStringSync();
      expect(
        src.contains('z_daily_tasks_reference.dart'),
        isFalse,
        reason: '🔴 le lot 4 a demandé une exemption couleur — il n\'en a pas '
            'besoin : toutes ses couleurs sont des rôles.',
      );
    });
  });

  group('⑧ 🔗 le maillon JETON — branché, et gardé branché', () {
    // 🔬 Le lot 4 avait été livré avec DEUX maillons (`paramètre > référence`),
    // faute de jetons dans `zcrud_core`. Les sept `ZcrudTheme.dailyTasks*` sont
    // désormais posés (4 sites chacun) et intercalés dans `zDailyTasksChromeOf`.
    // Ces gardes tiennent la propriété par les DEUX bouts : la SOURCE (le
    // maillon est écrit) et le COMPORTEMENT (le maillon est entendu). Une garde
    // de source seule serait verte sur un `theme.dailyTasksX` mort ; une garde
    // comportementale seule ne dirait pas OÙ le maillon a sauté.
    //
    // 🔴 Chaque valeur de sonde ci-dessous DIFFÈRE de la référence ET de
    // l'ambiant : sans quoi l'attendu serait déjà vrai avant la mesure, et la
    // garde serait vacante.

    /// Résout le chrome sous un `ZcrudTheme` (extension) et des paramètres.
    Future<ZDailyTasksChrome> resolve(
      WidgetTester tester, {
      ZcrudTheme? token,
      EdgeInsetsGeometry? bandPadding,
      EdgeInsetsGeometry? dayCellMargin,
      EdgeInsetsGeometry? dayCellPadding,
      Radius? dayCellRadius,
      double? minTapTarget,
      double? monthBreakpoint,
      EdgeInsetsGeometry? itemPadding,
    }) async {
      late ZDailyTasksChrome chrome;
      await tester.pumpWidget(
        MaterialApp(
          theme: token == null
              ? null
              : ThemeData(extensions: <ThemeExtension<dynamic>>[token]),
          home: Builder(
            builder: (BuildContext context) {
              chrome = zDailyTasksChromeOf(
                context,
                bandPadding: bandPadding,
                dayCellMargin: dayCellMargin,
                dayCellPadding: dayCellPadding,
                dayCellRadius: dayCellRadius,
                minTapTarget: minTapTarget,
                monthBreakpoint: monthBreakpoint,
                itemPadding: itemPadding,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return chrome;
    }

    /// Jeton de sonde : sept valeurs qu'AUCUNE référence ne porte.
    const ZcrudTheme probe = ZcrudTheme(
      dailyTasksBandPadding: EdgeInsetsDirectional.symmetric(
        horizontal: 33,
        vertical: 17,
      ),
      dailyTasksDayCellMargin: EdgeInsetsDirectional.symmetric(horizontal: 9),
      dailyTasksDayCellPadding: EdgeInsetsDirectional.symmetric(vertical: 21),
      dailyTasksDayCellRadius: Radius.circular(3),
      dailyTasksMinTapTarget: 61,
      dailyTasksMonthBreakpoint: 777,
      dailyTasksItemPadding: EdgeInsetsDirectional.symmetric(
        horizontal: 5,
        vertical: 29,
      ),
    );

    test('🔴 les valeurs de sonde DIFFÈRENT toutes de la référence', () {
      // Sans ce contrôle, une sonde qui vaudrait par accident la référence
      // rendrait les deux gardes suivantes VERTES sur un maillon débranché.
      expect(probe.dailyTasksBandPadding,
          isNot(ZDailyTasksReference.bandPadding));
      expect(probe.dailyTasksDayCellMargin,
          isNot(ZDailyTasksReference.dayCellMargin));
      expect(probe.dailyTasksDayCellPadding,
          isNot(ZDailyTasksReference.dayCellPadding));
      expect(probe.dailyTasksDayCellRadius,
          isNot(ZDailyTasksReference.dayCellRadius));
      expect(probe.dailyTasksMinTapTarget,
          isNot(ZDailyTasksReference.minTapTarget));
      expect(probe.dailyTasksMonthBreakpoint,
          isNot(ZDailyTasksReference.monthBreakpoint));
      expect(probe.dailyTasksItemPadding,
          isNot(ZDailyTasksReference.itemPadding));
    });

    testWidgets('sans jeton ni paramètre ⇒ la RÉFÉRENCE, inchangée (additif)',
        (tester) async {
      final ZDailyTasksChrome c = await resolve(tester);
      expect(c.bandPadding, ZDailyTasksReference.bandPadding);
      expect(c.dayCellMargin, ZDailyTasksReference.dayCellMargin);
      expect(c.dayCellPadding, ZDailyTasksReference.dayCellPadding);
      expect(c.dayCellRadius, ZDailyTasksReference.dayCellRadius);
      expect(c.minTapTarget, ZDailyTasksReference.minTapTarget);
      expect(c.monthBreakpoint, ZDailyTasksReference.monthBreakpoint);
      expect(c.itemPadding, ZDailyTasksReference.itemPadding);
    });

    testWidgets('le JETON bat la référence, champ par champ', (tester) async {
      final ZDailyTasksChrome c = await resolve(tester, token: probe);
      expect(c.bandPadding, probe.dailyTasksBandPadding,
          reason: '🔴 maillon jeton débranché sur `bandPadding`');
      expect(c.dayCellMargin, probe.dailyTasksDayCellMargin,
          reason: '🔴 maillon jeton débranché sur `dayCellMargin`');
      expect(c.dayCellPadding, probe.dailyTasksDayCellPadding,
          reason: '🔴 maillon jeton débranché sur `dayCellPadding`');
      expect(c.dayCellRadius, probe.dailyTasksDayCellRadius,
          reason: '🔴 maillon jeton débranché sur `dayCellRadius`');
      expect(c.minTapTarget, probe.dailyTasksMinTapTarget,
          reason: '🔴 maillon jeton débranché sur `minTapTarget`');
      expect(c.monthBreakpoint, probe.dailyTasksMonthBreakpoint,
          reason: '🔴 maillon jeton débranché sur `monthBreakpoint`');
      expect(c.itemPadding, probe.dailyTasksItemPadding,
          reason: '🔴 maillon jeton débranché sur `itemPadding`');
    });

    testWidgets('le PARAMÈTRE bat le jeton (ordre des trois maillons)',
        (tester) async {
      const EdgeInsetsGeometry pBand = EdgeInsetsDirectional.symmetric(
        horizontal: 41,
        vertical: 13,
      );
      const EdgeInsetsGeometry pMargin = EdgeInsetsDirectional.symmetric(
        horizontal: 7,
      );
      const EdgeInsetsGeometry pPad = EdgeInsetsDirectional.symmetric(
        vertical: 19,
      );
      const Radius pRadius = Radius.circular(5);
      const double pTarget = 72;
      const double pBreak = 911;
      const EdgeInsetsGeometry pItem = EdgeInsetsDirectional.symmetric(
        horizontal: 3,
        vertical: 23,
      );
      final ZDailyTasksChrome c = await resolve(
        tester,
        token: probe,
        bandPadding: pBand,
        dayCellMargin: pMargin,
        dayCellPadding: pPad,
        dayCellRadius: pRadius,
        minTapTarget: pTarget,
        monthBreakpoint: pBreak,
        itemPadding: pItem,
      );
      // Les paramètres diffèrent AUSSI du jeton : un `paramètre ?? jeton`
      // inversé rendrait les valeurs de sonde, pas celles-ci.
      expect(c.bandPadding, pBand);
      expect(c.dayCellMargin, pMargin);
      expect(c.dayCellPadding, pPad);
      expect(c.dayCellRadius, pRadius);
      expect(c.minTapTarget, pTarget);
      expect(c.monthBreakpoint, pBreak);
      expect(c.itemPadding, pItem);
    });

    test('les 7 jetons existent dans `ZcrudTheme`, aux 4 sites', () {
      final File theme = File(
        '../zcrud_core/lib/src/presentation/theme/z_theme.dart',
      );
      expect(theme.existsSync(), isTrue,
          reason: 'sonde cassée : thème introuvable depuis '
              '${Directory.current.path}');
      // 🔴 DÉPOUILLÉ (campagne dartdoc P0A) : le câblage RÉEL, pas sa mention
      // en dartdoc.
      final String src = stripped(theme).join('\n');
      for (final String token in kDailyTasksTokens) {
        expect(src, contains('dailyTasks$token'),
            reason: '🔴 le jeton `dailyTasks$token` a disparu de `ZcrudTheme` : '
                'le maillon du milieu ne résout plus rien.');
      }
    });

    test('`zDailyTasksChromeOf` intercale CHAQUE jeton entre paramètre et '
        'référence', () {
      final File src = File(
        'lib/src/presentation/z_daily_tasks_reference.dart',
      );
      expect(src.existsSync(), isTrue, reason: 'sonde cassée');
      // 🔴 DÉPOUILLÉ (campagne dartdoc P0A) : idem.
      final String body = stripped(src).join('\n');
      for (final String token in kDailyTasksTokens) {
        expect(body, contains('theme.dailyTasks$token'),
            reason: '🔴 le maillon JETON de `dailyTasks$token` a sauté : la '
                'chaîne retomberait à `paramètre > référence`, et un hôte qui '
                'thématise sa vue des tâches du jour ne serait plus entendu.');
      }
    });

    test('🚫 AUCUN jeton générique n\'est ridé par le résolveur (CR-IFFD-61)',
        () {
      // 🔴 DÉPOUILLÉ (campagne dartdoc P0A) : une dartdoc pourrait citer un
      // jeton générique en contre-exemple sans que ce soit du CODE réel.
      final String body = stripped(File(
        'lib/src/presentation/z_daily_tasks_reference.dart',
      )).join('\n');
      for (final String generic in <String>[
        'theme.gapS',
        'theme.gapM',
        'theme.gapL',
        'theme.radiusS',
        'theme.radiusM',
        'theme.badgeRadius',
        'theme.fieldPadding',
        'theme.formPadding',
      ]) {
        expect(body.contains(generic), isFalse,
            reason: '🔴 `$generic` est ridé par la vue des tâches du jour : un '
                'jeton générique porte déjà d\'autres valeurs de référence, '
                'donc aucune ne peut les satisfaire toutes (CR-IFFD-61).');
      }
    });
  });
}

/// Les sept jetons de la vue des tâches du jour, **suffixe seul** (le préfixe
/// `dailyTasks` est ajouté par les gardes). Source unique : toute évolution de
/// la famille se déclare ICI, et les gardes suivent.
const List<String> kDailyTasksTokens = <String>[
  'BandPadding',
  'DayCellMargin',
  'DayCellPadding',
  'DayCellRadius',
  'MinTapTarget',
  'MonthBreakpoint',
  'ItemPadding',
];
