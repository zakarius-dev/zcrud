/// **Lot 4 « étude »** — [ZDailyTasksView] : le CORPS COMPOSABLE de la vue des
/// tâches du jour (bandeau de semaine + liste).
///
/// 🚫 **Aucun `Scaffold`, aucune `AppBar`, aucune route** — cohérence stricte
/// avec `ZStudySessionView` (lot 1). C'est ce qu'un hôte pose en page, en onglet
/// ou en feuille.
///
/// ## Le manque, MESURÉ avant écriture
///
/// Le kernel est ENTIER depuis ES-2.7 : `aggregateDailyStudyTasks`,
/// `ZDailyStudyTask`, `ZDueCardsTask`, `ZExamTask`, port neutre
/// `ZApproachingExam`. Grep exécuté sur disque :
///
/// ```
/// $ grep -rln "ZDailyStudyTask\|ZDueCardsTask\|aggregateDailyStudyTasks" packages/*/lib
/// packages/zcrud_study_kernel/lib/src/domain/aggregate_daily_study_tasks.dart
/// packages/zcrud_study_kernel/lib/src/domain/z_daily_study_task.dart
/// packages/zcrud_study/lib/src/presentation/z_exam_reminders.dart
/// packages/zcrud_study/lib/src/presentation/z_exam_reminders_section.dart
/// ```
///
/// Les deux seuls consommateurs de présentation appellent l'agrégation avec
/// **`dueCount: 0`** (`z_exam_reminders.dart:131`) et ne rendent **que** les
/// examens : la ligne « cartes dues », elle, n'était rendue **nulle part**.
///
/// ## 🔴 Le `default` est OBLIGATOIRE — c'est le kernel qui l'exige
///
/// `ZDailyStudyTask` est une **famille OUVERTE** (`abstract interface class` +
/// discriminant `String kind`), délibérément **jamais `sealed`** : « un satellite
/// futur peut AJOUTER une variante sans modifier le kernel » (AD-4). Le dispatch
/// de cette vue se fait donc sur `task.kind` **avec un `default`** :
///
/// | Variante | Rendu |
/// |---|---|
/// | `'dueCards'` | [ZDailyTasksView.dueCardsBuilder] |
/// | `'exam'` | [ZDailyTasksView.examBuilder] |
/// | **toute autre** | [ZDailyTasksView.unknownTaskBuilder] |
/// | autre **sans** `unknownTaskBuilder` | **ABSENTE de la liste** (AD-4) |
///
/// 🔴 Une variante inconnue n'est **jamais** un throw, **jamais** un placeholder
/// inerte : elle n'occupe **aucune** ligne. Une garde monte une variante forgée
/// (`kind: 'podcast'`) et vérifie les deux branches.
///
/// 🔒 **Le `kind` ne suffit pas** : rien n'empêche une variante hostile
/// d'annoncer `kind == 'exam'` sans être un `ZExamTask`. Chaque branche
/// **re-vérifie le type** et retombe sur `unknownTaskBuilder` sinon (AD-10 —
/// aucun cast qui puisse lever).
///
/// ## 🔴 Horloge INJECTÉE
///
/// [ZDailyTasksView.now] est le **SEUL** référentiel temporel : aucun
/// `DateTime.now()`, aucun `DateTime()` sans argument, aucun `.toLocal()` dans
/// ce fichier ni dans son fichier de référence. Le kernel porte déjà cette
/// propriété (`zcrud_study_kernel/test/no_datetime_now_test.dart`) ; une garde
/// de source l'**étend à ces widgets**.
///
/// L'arithmétique de semaine est faite en **UTC normalisé à la date**
/// ([zStudyWeekDays]) : aucune dérive DST, exactement la discipline D4 du
/// kernel.
///
/// ⚠️ **Comment cette propriété est RÉELLEMENT gardée, et pourquoi.** Le test
/// comportemental ne peut **pas** distinguer une arithmétique locale d'une
/// arithmétique UTC lorsque l'hôte de test est lui-même en UTC — mesuré :
/// remplacer `DateTime.utc(...)` par `DateTime(...)` laissait la garde de
/// semaine **verte** sur cette machine (`date` ⇒ `GMT`). La propriété est donc
/// portée par une garde de **SOURCE** (constructeur `DateTime(` nu banni dans ce
/// fichier et son fichier de référence), qui, elle, mord. Le test
/// comportemental garde la **forme** (7 jours UTC, 24 h d'écart, aucun trou) et
/// **déclare sa limite** — une garde qui ne peut pas rougir n'est pas gardée.
///
/// ## 🔴 `dueCount` vient de l'HÔTE
///
/// Le kernel le dit : `dueCount` est la « source unique, jamais recalculée ». La
/// vue ne compte **rien**, ne filtre **rien**, ne consulte **aucun** store. Elle
/// reçoit un entier et une liste d'examens, et les passe au kernel.
///
/// De même, **la sélection de jour est un CONSTAT transmis à l'hôte**
/// ([ZDailyTasksView.onDaySelected]) : c'est lui qui refournit
/// `dueCount`/`exams` pour le jour choisi. La vue ne filtre aucune donnée
/// (même contrat que `ZStudyFolderDetail.materialSectionsBuilder(id)`).
///
/// ## Ce que le legacy porte et que ce lot NE PORTE PAS
///
/// Les quatre « actions rapides » (`daily_tasks_page.dart:900-1050`) : **trois
/// sur quatre** y sont `enabled: false` (l.917 / l.925 / l.933). Porter une
/// commande morte serait porter un défaut — AD-4 : une capacité absente est
/// absente de l'arbre, pas grisée.
///
/// ## FR-26 / AD-13
///
/// Aucun libellé en dur : chaque texte du bandeau vient d'un **builder injecté**
/// (le socle ne connaît ni `DateFormat`, ni locale). Aucune couleur littérale :
/// tout est rôle du `ColorScheme`, résolu par `zDailyTasksChromeOf`. Insets
/// **directionnels**, `Semantics(button:, selected:)` explicites, cible ≥ 48 dp
/// **en géométrie rendue** — et le bandeau **défile horizontalement** quand la
/// largeur ne permet pas 7 cibles au plancher (le legacy, lui, les comprime).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show
        ZApproachingExam,
        ZDailyStudyTask,
        ZDueCardsTask,
        ZExamTask,
        aggregateDailyStudyTasks;

import 'z_daily_tasks_reference.dart';

/// Rend le libellé d'un jour du bandeau (intitulé, numéro, mois) — **INJECTÉ**.
///
/// Le socle ne formate **aucune** date : le format court/long, la locale et la
/// casse sont des décisions d'i18n qui appartiennent à l'hôte (FR-26). Le [day]
/// fourni est **normalisé à la date en UTC** (cf. [zStudyWeekDays]).
typedef ZDailyDayLabelBuilder = String Function(BuildContext context, DateTime day);

/// Construit la ligne d'une tâche « cartes dues » — **INJECTÉE**.
///
/// `null` ⇒ la ligne dues est **ABSENTE** de la liste (AD-4), jamais un
/// placeholder. Retourner `null` depuis le builder a le même effet.
typedef ZDueCardsTaskBuilder =
    Widget? Function(BuildContext context, ZDueCardsTask task);

/// Construit la ligne d'une tâche « examen approchant » — **INJECTÉE**.
typedef ZExamTaskBuilder =
    Widget? Function(BuildContext context, ZExamTask task);

/// Construit la ligne d'une variante **INCONNUE** de la famille ouverte
/// `ZDailyStudyTask` (AD-4).
///
/// `null` ⇒ la variante est **ABSENTE** de la liste — jamais un throw, jamais un
/// « type non supporté » affiché à l'utilisateur.
typedef ZUnknownTaskBuilder =
    Widget? Function(BuildContext context, ZDailyStudyTask task);

/// Normalise [moment] à sa **date**, en UTC — PURE / TOTALE / DÉTERMINISTE.
///
/// L'UTC n'est pas un détail : c'est le seul calendrier où « ajouter un jour »
/// ajoute exactement 24 h. En heure locale, une semaine qui traverse un
/// changement d'heure produit deux jours identiques ou un jour manquant.
/// Discipline héritée du kernel (D4).
DateTime zStudyDayOf(DateTime moment) =>
    DateTime.utc(moment.year, moment.month, moment.day);

/// Les 7 jours de la semaine contenant [around] — PURE / TOTALE / DÉTERMINISTE.
///
/// [weekStart] est un `DateTime.monday`…`DateTime.sunday`. Le résultat est
/// toujours de longueur 7, croissant, normalisé à la date en UTC.
///
/// 🔴 **Aucune horloge interne** : la semaine est une fonction de son seul
/// argument. C'est ce qui rend le bandeau testable sans figer le temps.
List<DateTime> zStudyWeekDays(
  DateTime around, {
  int weekStart = ZDailyTasksReference.weekStart,
}) {
  final DateTime day = zStudyDayOf(around);
  // `%` sur un diviseur positif rend TOUJOURS un reste positif en Dart : le
  // décalage est dans 0..6 même quand `weekStart` est postérieur au jour (par
  // exemple semaine commençant le dimanche, jour = lundi).
  final int shift = (day.weekday - weekStart) % DateTime.daysPerWeek;
  final DateTime start = day.subtract(Duration(days: shift));
  return List<DateTime>.generate(
    ZDailyTasksReference.daysPerBand,
    // `DateTime.utc(y, m, d + i)` normalise le débordement de mois/année.
    (int i) => DateTime.utc(start.year, start.month, start.day + i),
    growable: false,
  );
}

/// `true` ssi [a] et [b] désignent le même jour calendaire (comparaison de
/// date pure — jamais une égalité d'instants).
bool zStudyIsSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Le **SITE UNIQUE** de dispatch de la famille ouverte `ZDailyStudyTask` —
/// `switch (task.kind)` avec `default` **OBLIGATOIRE** (exigence explicite de la
/// dartdoc du kernel : « aucune exhaustivité figée »).
///
/// Retourne le **constructeur** de la ligne, ou `null` quand la variante n'est
/// pas rendue. C'est un constructeur et non un `Widget` pour deux raisons :
///
/// * la liste peut **filtrer** sans construire un seul widget, donc rester
///   virtualisée ;
/// * la construction se fait sous le `BuildContext` de l'item, pas sous celui
///   de la vue.
///
/// 🔴 **PURE, TOTALE, DÉTERMINISTE — ne lève JAMAIS.** Le `kind` est déclaratif :
/// une variante tierce peut annoncer `'exam'` sans être un [ZExamTask]. Chaque
/// branche **re-vérifie le type** et retombe sur [unknownTaskBuilder] sinon
/// (AD-10 — aucun `as` qui puisse échouer).
///
/// Fonction de premier ordre (et non une méthode privée) parce qu'elle est la
/// propriété la plus importante de ce fichier : elle doit être **éprouvable
/// directement**, sur des variantes forgées qu'aucun rendu ne saurait produire.
Widget? Function(BuildContext)? zDailyTaskTileBuilder(
  ZDailyStudyTask task, {
  ZDueCardsTaskBuilder? dueCardsBuilder,
  ZExamTaskBuilder? examBuilder,
  ZUnknownTaskBuilder? unknownTaskBuilder,
}) {
  Widget? Function(BuildContext)? unknown() {
    final ZUnknownTaskBuilder? builder = unknownTaskBuilder;
    if (builder == null) return null;
    return (BuildContext context) => builder(context, task);
  }

  switch (task.kind) {
    case ZDailyTasksView.dueCardsKind:
      if (task is! ZDueCardsTask) return unknown();
      final ZDueCardsTaskBuilder? builder = dueCardsBuilder;
      if (builder == null) return null;
      return (BuildContext context) => builder(context, task);
    case ZDailyTasksView.examKind:
      if (task is! ZExamTask) return unknown();
      final ZExamTaskBuilder? builder = examBuilder;
      if (builder == null) return null;
      return (BuildContext context) => builder(context, task);
    default:
      // 🔴 OBLIGATOIRE — une variante ajoutée par un satellite futur passe ICI,
      // jamais par une exception, jamais par le régime d'une variante voisine.
      return unknown();
  }
}

/// Corps composable de la vue des tâches du jour.
///
/// Voir la dartdoc de bibliothèque pour le dispatch ouvert, l'horloge injectée
/// et les invariants. Ce type est un `StatelessWidget` **par construction** :
/// la sélection est détenue par l'hôte (AD-2 — un seul propriétaire d'état).
class ZDailyTasksView extends StatelessWidget {
  /// Assemble la vue.
  ///
  /// [now] est l'horloge **injectée** ; [dueCount] la **source unique** du
  /// compte de cartes dues (jamais recalculé) ; [weekdayLabelBuilder] et
  /// [dayLabelBuilder] sont requis parce que le socle ne formate aucune date.
  const ZDailyTasksView({
    required this.now,
    required this.dueCount,
    required this.weekdayLabelBuilder,
    required this.dayLabelBuilder,
    this.exams = const <ZApproachingExam>[],
    this.selectedDay,
    this.onDaySelected,
    this.monthLabelBuilder,
    this.daySemanticLabelBuilder,
    this.dueCardsBuilder,
    this.examBuilder,
    this.unknownTaskBuilder,
    this.emptyState,
    this.weekStart = ZDailyTasksReference.weekStart,
    this.bandPadding,
    this.dayCellMargin,
    this.dayCellPadding,
    this.dayCellRadius,
    this.minTapTarget,
    this.monthBreakpoint,
    this.itemPadding,
    super.key,
  });

  /// Clé du bandeau de semaine (testabilité).
  static const ValueKey<String> bandKey = ValueKey<String>('zDailyTasksBand');

  /// Clé de la liste des tâches (testabilité).
  static const ValueKey<String> listKey = ValueKey<String>('zDailyTasksList');

  /// Clé de l'état vide **INJECTÉ**, présente uniquement quand il est fourni ET
  /// rendu — un test doit pouvoir distinguer « état vide rendu » de « rien ».
  static const ValueKey<String> emptyKey = ValueKey<String>('zDailyTasksEmpty');

  /// Préfixe de la `key` d'une cellule de jour, suffixé de sa date ISO
  /// (`zDailyTasksDay_2026-08-06`) — identité STABLE, jamais un index.
  static const String dayKeyPrefix = 'zDailyTasksDay_';

  /// Préfixe de la `key` d'une ligne de tâche, suffixé du `kind` et de l'index
  /// de rendu.
  static const String taskKeyPrefix = 'zDailyTasksTask_';

  /// Discriminant de la variante « cartes dues » de la famille ouverte.
  ///
  /// 🔴 Constante **liée au kernel par garde** (`ZDueCardsTask(1).kind` doit lui
  /// être égal) : sans cette garde, un renommage côté kernel laisserait ce
  /// dispatch tomber silencieusement dans le `default`, et la ligne dues
  /// disparaîtrait sans qu'aucun test ne rougisse.
  static const String dueCardsKind = 'dueCards';

  /// Discriminant de la variante « examen approchant » — même garde.
  static const String examKind = 'exam';

  /// Horloge **INJECTÉE** — seul référentiel temporel (aucun `DateTime.now()`).
  final DateTime now;

  /// Compte de cartes dues, **fourni par l'hôte** (source unique du kernel).
  /// `<= 0` ⇒ aucune ligne dues (règle du kernel, jamais réimplémentée ici).
  final int dueCount;

  /// Examens candidats, consommés via le port **neutre** `ZApproachingExam`
  /// (aucune dépendance à `zcrud_exam` depuis cette vue).
  final Iterable<ZApproachingExam> exams;

  /// Jour sélectionné. `null` ⇒ le jour de [now].
  final DateTime? selectedDay;

  /// Constat de sélection vers l'hôte. `null` ⇒ le bandeau n'est **pas
  /// actionnable** (AD-4 — aucune cellule n'est un bouton, jamais un tap mort).
  final ValueChanged<DateTime>? onDaySelected;

  /// Intitulé de jour **INJECTÉ** (« LUN », « lundi »… — le socle ne formate
  /// rien).
  final ZDailyDayLabelBuilder weekdayLabelBuilder;

  /// Numéro de jour **INJECTÉ**.
  final ZDailyDayLabelBuilder dayLabelBuilder;

  /// Libellé de mois **INJECTÉ**, rendu seulement au-delà de la largeur de
  /// bascule. `null` ⇒ **absent** de l'arbre à toute largeur (AD-4).
  final ZDailyDayLabelBuilder? monthLabelBuilder;

  /// Annonce accessible d'une cellule de jour. `null` ⇒ composition de
  /// l'intitulé et du numéro déjà injectés (aucun mot ajouté par le socle).
  final ZDailyDayLabelBuilder? daySemanticLabelBuilder;

  /// Ligne « cartes dues ». `null` ⇒ variante ABSENTE de la liste.
  final ZDueCardsTaskBuilder? dueCardsBuilder;

  /// Ligne « examen approchant ». `null` ⇒ variante ABSENTE de la liste.
  final ZExamTaskBuilder? examBuilder;

  /// Ligne d'une variante **INCONNUE** (AD-4). `null` ⇒ variante ABSENTE.
  final ZUnknownTaskBuilder? unknownTaskBuilder;

  /// État vide **INJECTÉ**, rendu quand aucune ligne n'est rendue. `null` ⇒
  /// absent de l'arbre (le bandeau reste, donc l'utilisateur garde une issue :
  /// changer de jour).
  final Widget? emptyState;

  /// Premier jour de la semaine (`DateTime.monday` par défaut — référence).
  final int weekStart;

  /// Surcharge du padding du bandeau (défaut : référence).
  final EdgeInsetsGeometry? bandPadding;

  /// Surcharge de la marge d'une cellule (défaut : référence).
  final EdgeInsetsGeometry? dayCellMargin;

  /// Surcharge du padding d'une cellule (défaut : référence).
  final EdgeInsetsGeometry? dayCellPadding;

  /// Surcharge du rayon d'une cellule (défaut : référence).
  final Radius? dayCellRadius;

  /// Surcharge de la cible tactile minimale (défaut : référence, 48 dp).
  final double? minTapTarget;

  /// Surcharge de la largeur de bascule du mois (défaut : référence, 600).
  final double? monthBreakpoint;

  /// Surcharge du padding d'une ligne de tâche (défaut : référence).
  final EdgeInsetsGeometry? itemPadding;

  /// Résout le constructeur de la ligne d'une tâche — DÉLÉGUÉ au site unique
  /// [zDailyTaskTileBuilder] (jamais un second `switch` parallèle).
  Widget? Function(BuildContext)? _tileBuilderFor(ZDailyStudyTask task) =>
      zDailyTaskTileBuilder(
        task,
        dueCardsBuilder: dueCardsBuilder,
        examBuilder: examBuilder,
        unknownTaskBuilder: unknownTaskBuilder,
      );

  @override
  Widget build(BuildContext context) {
    final ZDailyTasksChrome chrome = zDailyTasksChromeOf(
      context,
      bandPadding: bandPadding,
      dayCellMargin: dayCellMargin,
      dayCellPadding: dayCellPadding,
      dayCellRadius: dayCellRadius,
      minTapTarget: minTapTarget,
      monthBreakpoint: monthBreakpoint,
      itemPadding: itemPadding,
    );
    final DateTime selected = zStudyDayOf(selectedDay ?? now);

    // Agrégation DÉLÉGUÉE au kernel — aucun filtre, aucun tri, aucun compte
    // refait ici (R21/R26 ; `dueCount` est la source unique).
    final List<ZDailyStudyTask> tasks = aggregateDailyStudyTasks(
      dueCount: dueCount,
      exams: exams,
      now: now,
    );
    // Filtrage SANS construction : `_tileBuilderFor` ne rend qu'une closure.
    final List<_ZResolvedTask> rendered = <_ZResolvedTask>[
      for (final ZDailyStudyTask task in tasks)
        if (_tileBuilderFor(task) != null)
          _ZResolvedTask(task, _tileBuilderFor(task)!),
    ];

    final Widget? empty = emptyState;
    return Column(
      children: <Widget>[
        _ZDayBand(
          days: zStudyWeekDays(selected, weekStart: weekStart),
          selected: selected,
          chrome: chrome,
          onDaySelected: onDaySelected,
          weekdayLabelBuilder: weekdayLabelBuilder,
          dayLabelBuilder: dayLabelBuilder,
          monthLabelBuilder: monthLabelBuilder,
          daySemanticLabelBuilder: daySemanticLabelBuilder,
        ),
        Expanded(
          child: rendered.isEmpty
              // AD-4 — état vide non fourni ⇒ AUCUN nœud à sa place (le
              // bandeau reste l'issue). Fourni ⇒ rendu, et OBSERVABLE par clé.
              ? (empty == null
                    ? const SizedBox.shrink()
                    : KeyedSubtree(key: emptyKey, child: empty))
              : ListView.builder(
                  key: listKey,
                  padding: chrome.itemPadding,
                  itemCount: rendered.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _ZResolvedTask resolved = rendered[index];
                    final Widget? tile = resolved.builder(context);
                    // AD-4 — un builder qui rend `null` laisse la ligne ABSENTE
                    // (jamais un `SizedBox` qui occuperait une place dans la
                    // liste et fausserait le défilement).
                    if (tile == null) return const SizedBox.shrink();
                    return KeyedSubtree(
                      key: ValueKey<String>(
                        '$taskKeyPrefix${resolved.task.kind}_$index',
                      ),
                      child: tile,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Une tâche dont le constructeur de ligne est **déjà résolu** — porte le couple
/// (tâche, closure) pour que la liste n'ait plus à redispatcher au défilement.
@immutable
class _ZResolvedTask {
  const _ZResolvedTask(this.task, this.builder);

  final ZDailyStudyTask task;
  final Widget? Function(BuildContext) builder;
}

/// Le bandeau de 7 jours.
///
/// 🔴 **Cible ≥ 48 dp en GÉOMÉTRIE RENDUE.** Sept cellules au plancher ne
/// tiennent pas côte à côte sous ~380 dp de large ; le legacy les comprime
/// silencieusement (`Expanded` sans contrainte de hauteur ni de largeur,
/// `daily_tasks_page.dart:158`). Ici, dès que la largeur disponible ne permet
/// plus 7 × [ZDailyTasksChrome.minTapTarget], le bandeau **défile
/// horizontalement** et chaque cellule garde sa cible. La sélection reste
/// atteignable ; c'est la largeur qui cède, jamais l'accessibilité.
class _ZDayBand extends StatelessWidget {
  const _ZDayBand({
    required this.days,
    required this.selected,
    required this.chrome,
    required this.onDaySelected,
    required this.weekdayLabelBuilder,
    required this.dayLabelBuilder,
    required this.monthLabelBuilder,
    required this.daySemanticLabelBuilder,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ZDailyTasksChrome chrome;
  final ValueChanged<DateTime>? onDaySelected;
  final ZDailyDayLabelBuilder weekdayLabelBuilder;
  final ZDailyDayLabelBuilder dayLabelBuilder;
  final ZDailyDayLabelBuilder? monthLabelBuilder;
  final ZDailyDayLabelBuilder? daySemanticLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final TextDirection direction = Directionality.of(context);
    return Padding(
      key: ZDailyTasksView.bandKey,
      padding: chrome.bandPadding,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double margin = chrome.dayCellMargin
              .resolve(direction)
              .horizontal;
          final double perCell = chrome.minTapTarget + margin;
          final double needed = perCell * days.length;
          final bool fits =
              constraints.maxWidth.isFinite && constraints.maxWidth >= needed;
          final bool showMonth =
              constraints.maxWidth >= chrome.monthBreakpoint &&
              monthLabelBuilder != null;

          final List<Widget> cells = <Widget>[
            for (final DateTime day in days)
              _cell(context, day, showMonth: showMonth, flexible: fits),
          ];
          final Widget row = Row(
            mainAxisSize: fits ? MainAxisSize.max : MainAxisSize.min,
            children: cells,
          );
          // Défilement SEULEMENT quand la largeur ne permet plus le plancher :
          // à largeur suffisante, le rendu est celui du legacy (7 colonnes
          // égales), sans aucun `Scrollable` interposé.
          return fits
              ? row
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: row,
                );
        },
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime day, {
    required bool showMonth,
    required bool flexible,
  }) {
    final bool isSelected = zStudyIsSameDay(day, selected);
    final ValueChanged<DateTime>? onSelected = onDaySelected;
    final String weekday = weekdayLabelBuilder(context, day);
    final String number = dayLabelBuilder(context, day);
    // Aucun mot ajouté par le socle : à défaut d'annonce injectée, on compose
    // les DEUX libellés que l'hôte a déjà fournis.
    final String announce =
        daySemanticLabelBuilder?.call(context, day) ?? '$weekday $number';
    final String iso = day.toIso8601String().substring(0, 10);

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          weekday,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: isSelected ? chrome.selectedWeekdayStyle : chrome.weekdayStyle,
        ),
        SizedBox(height: chrome.weekdayGap),
        Text(
          number,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: isSelected ? chrome.selectedDayStyle : chrome.dayStyle,
        ),
        // AD-4 — hors bascule (ou sans builder), le mois est ABSENT de l'arbre.
        if (showMonth) ...<Widget>[
          SizedBox(height: chrome.monthGap),
          Text(
            monthLabelBuilder!(context, day),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: chrome.monthStyle,
          ),
        ],
      ],
    );

    // 🔴 **La marge est HORS de la cible**, et c'est load-bearing (démasqué par
    // l'injection R3 « pas de défilement en étroit »). Première rédaction : la
    // marge vivait DANS le `Container`, donc DANS l'`InkWell` — la cible tactile
    // englobait 4 dp de vide et mesurait 49.1 dp là où la cellule VISIBLE n'en
    // faisait que 45.1. La garde des 48 dp restait verte sur une cellule
    // visiblement écrasée : elle mesurait une zone que l'utilisateur ne voit
    // pas. Marge à l'extérieur ⇒ **cible = cellule visible**, une seule
    // grandeur, et la garde mesure ce qu'elle prétend mesurer.
    final Widget cell = Container(
      constraints: BoxConstraints(
        minWidth: chrome.minTapTarget,
        minHeight: chrome.minTapTarget,
      ),
      decoration: BoxDecoration(
        color: isSelected ? chrome.selectedCellColor : chrome.cellColor,
        borderRadius: BorderRadius.all(chrome.dayCellRadius),
        border: Border.all(
          color: isSelected ? chrome.selectedBorderColor : chrome.borderColor,
          // AD-13 — second canal de la sélection : l'épaisseur, pas seulement
          // la teinte.
          width: isSelected
              ? chrome.selectedBorderWidth
              : chrome.borderWidth,
        ),
      ),
      child: Padding(
        padding: chrome.dayCellPadding,
        child: Center(child: content),
      ),
    );

    final Widget interactive = Semantics(
      // AD-4 — sans callback, la cellule n'est PAS annoncée comme un bouton :
      // elle reste lisible, mais rien ne promet une action qui n'existe pas.
      button: onSelected != null,
      selected: isSelected,
      label: announce,
      excludeSemantics: true,
      child: onSelected == null
          ? cell
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => onSelected(day),
                borderRadius: BorderRadius.all(chrome.dayCellRadius),
                child: cell,
              ),
            ),
    );

    // La `key` reste posée DIRECTEMENT sur le sous-arbre interactif : c'est par
    // elle qu'une garde atteint le nœud de sémantique de la cellule. La marge,
    // elle, est posée AU-DESSUS de la clé — donc hors de la cible ET hors de ce
    // que la garde mesure.
    final Widget keyed = KeyedSubtree(
      key: ValueKey<String>('${ZDailyTasksView.dayKeyPrefix}$iso'),
      child: interactive,
    );
    final Widget spaced = Padding(
      padding: chrome.dayCellMargin,
      child: keyed,
    );
    return flexible ? Expanded(child: spaced) : spaced;
  }
}
