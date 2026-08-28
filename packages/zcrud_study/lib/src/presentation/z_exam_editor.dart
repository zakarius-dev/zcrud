/// `ZExamEditor` — éditeur d'examen daté avec rappels.
/// ADAPTATEUR MINCE de PRÉSENTATION : il **COMPOSE** l'entité `ZExam`
/// (`zcrud_exam`, pur-Dart) — il ne réimplémente NI sa (dé)sérialisation NI
/// sa validation (même patron que `ZTagEditor`, `ZStudyMindmapSection`).
///
/// Ce que l'éditeur POSSÈDE et PROUVE (lignes de prod PROPRES au widget) :
/// - **PRÉSERVATION EXACTE de la saisie** : `onSubmit` reçoit un `ZExam` dont
///   CHAQUE champ saisi survit à l'identique (titre, date, `reminderEnabled`,
///   `reminderDaysBefore` ordre EXACT, `reminderTime`) — jamais un `ZExam` défaut,
///   jamais un champ perdu. En création, `id == null` : matérialisé au
///   repository, jamais par le widget.
/// - **Heure TYPÉE `ZReminderTime`** : l'heure vit dans un
///   `ValueNotifier<ZReminderTime?>` — jamais une `String` `'HH:mm'` flottante. Le
///   round-trip persistance (`ZExam.toMap` → `'08:05'`) est celui de `ZExam` (non
///   réimplémenté). Champ heure **EXPLICITE** (hors-codegen ⇒ aucun `ZFieldSpec`
///   généré pour ce champ).
/// - **Seuils ordre + doublons PRÉSERVÉS** : `reminderDaysBefore` est édité
///   dans un `ValueNotifier<List<int>>` — l'ajout APPEND (aucun `sort`, aucun
///   `toSet`), la sémantique `ZExam` est ordre-sensible.
/// - **Réactivité Flutter-native (invariant AD-2/AD-15)** : le
///   `TextEditingController` du titre POSSÉDÉ est créé en `initState` (jamais
///   dans `build`) et disposé au `dispose` ; un controller INJECTÉ est utilisé
///   tel quel et JAMAIS disposé. Chaque champ est une frontière de rebuild
///   (`ValueListenableBuilder` + `ValueKey`) — aucun `setState` de page,
///   aucun gestionnaire d'état importé (objectif produit n°1).
/// - **Récurrence hebdomadaire OPT-IN** : `showWeeklyReminders` (défaut
///   `false`) ajoute une section de jours de semaine autour de la ligne
///   d'heure. Tant qu'elle est absente, `reminderRecurrence` n'est pas touché —
///   une valeur portée par l'examen édité SURVIT à la soumission, sans être
///   affichée ni effacée.
/// - **Seam horloge/pickers INJECTÉS** : le widget ne fait NI `DateTime.now()`
///   NI `showDatePicker`/`showTimePicker` en dur — la date et l'heure sont choisies
///   via les callbacks INJECTÉS [onPickDate]/[onPickTime] (l'app fournit son picker,
///   avec SON horloge). Aucun plugin de notification / `Timer`.
///
/// Invariant AD-13/FR-26 : `Semantics` non vides INJECTÉS (replis neutres
/// documentés), cibles ≥ 48 dp, widgets DIRECTIONNELS
/// (`EdgeInsetsDirectional`/`TextAlign.start`), thème via
/// `ZcrudScope`/`ZcrudTheme` — aucune `Color`/label métier codé en dur.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_exam/zcrud_exam.dart';

/// Cible de taille interactive minimale (invariant AD-13).
const double _kMinTapTarget = 48.0;

/// Icône de REPLI du bouton d'ajout de seuil (défaut neutre documenté ; INJECTABLE).
const IconData _kAddThresholdFallbackIcon = Icons.add;

/// Icône de REPLI du bouton de suppression de seuil (INJECTABLE).
const IconData _kRemoveThresholdFallbackIcon = Icons.close;

/// Index Material (0 = dimanche … 6 = samedi) → jour ISO-8601 (1 = lundi …
/// 7 = dimanche), la convention de `DateTime.weekday` et de
/// `ZReminderRecurrence.weekdays`. Seul dimanche diffère.
int _isoWeekdayOf(int materialIndex) =>
    materialIndex == 0 ? DateTime.sunday : materialIndex;

/// Sélectionne une date d'examen (picker INJECTÉ — l'app apporte SON horloge, AC5).
///
/// Reçoit la date COURANTE (`null` si non planifiée) et rend la date choisie, ou
/// `null` si l'utilisateur annule / efface (défensif, AD-10). Le widget ne fait
/// JAMAIS `DateTime.now()` ni `showDatePicker` avec horloge implicite (R5/AC5).
typedef ZExamDatePicker = Future<DateTime?> Function(DateTime? current);

/// Sélectionne une heure de rappel TYPÉE (picker INJECTÉ, AC2/AC5).
///
/// Reçoit l'heure COURANTE et rend la [ZReminderTime] choisie, ou `null` si annulé/
/// vidé (⇒ `reminderTime == null`, défensif AD-10). Le TYPE porte le format — jamais
/// une `String` `'HH:mm'` ambiguë (AD-28).
typedef ZExamTimePicker = Future<ZReminderTime?> Function(ZReminderTime? current);

/// Formate une date pour l'affichage (INJECTÉ, i18n — AD-13/FR-23).
typedef ZExamDateLabeler = String Function(DateTime date);

/// Rend le libellé d'un jour de la semaine, en convention **ISO-8601** :
/// `1` = lundi … `7` = dimanche (celle de `DateTime.weekday` et de
/// `ZReminderRecurrence.weekdays`).
///
/// Injecté par l'hôte quand il dispose d'un catalogue de noms complets. Le
/// repli du widget est `MaterialLocalizations.narrowWeekdays`, qui rend une
/// abréviation d'une ou deux lettres : suffisant à l'affichage, pauvre au
/// lecteur d'écran. Un hôte soucieux d'accessibilité injecte donc un labeler
/// rendant le **nom complet** — c'est cette même chaîne qui devient le
/// `Semantics.label` de la puce.
typedef ZExamWeekdayLabeler = String Function(int weekday);

/// Éditeur d'examen — composition d'un `ZExam` à saisie PRÉSERVÉE (AC1).
///
/// `StatefulWidget` **uniquement** pour (a) le cycle de vie des controllers POSSÉDÉS
/// (titre + saisie de seuil) et (b) les `ValueNotifier` LOCAUX par champ. JAMAIS pour
/// l'état de l'entité (composée à la soumission).
class ZExamEditor extends StatefulWidget {
  /// Construit l'éditeur. Tous les libellés/icônes sont INJECTÉS (replis neutres
  /// documentés — AD-13/FR-26).
  const ZExamEditor({
    required this.onSubmit,
    this.initialExam,
    this.folderId,
    this.onPickDate,
    this.onPickTime,
    this.titleController,
    this.thresholdController,
    this.titleLabel = 'Intitulé de l\'examen',
    this.titleHint = 'Examen',
    this.dateLabel = 'Date de l\'examen',
    this.dateNotSetLabel = 'Choisir une date',
    this.dateSemanticLabel = 'Choisir la date de l\'examen',
    this.dateLabeler = _defaultDateLabeler,
    this.reminderToggleLabel = 'Activer les rappels',
    this.thresholdLabel = 'Jours avant',
    this.thresholdHint = 'Ajouter un seuil (jours)',
    this.addThresholdSemanticLabel = 'Ajouter un seuil de rappel',
    this.removeThresholdSemanticLabel = _defaultRemoveThresholdLabel,
    this.timeLabel = 'Heure du rappel',
    this.timeNotSetLabel = 'Choisir une heure',
    this.timeSemanticLabel = 'Choisir l\'heure du rappel',
    this.showWeeklyReminders = false,
    this.weeklyRemindersLabel = 'Rappels hebdomadaires',
    this.weekdayLabeler,
    this.submitLabel = 'Enregistrer',
    this.submitSemanticLabel = 'Enregistrer l\'examen',
    this.addThresholdIcon,
    this.removeThresholdIcon,
    super.key,
  });

  /// Émis à la validation avec le `ZExam` COMPOSÉ (saisie PRÉSERVÉE, AC1). En
  /// création (`initialExam == null`), l'`id` émis est `null` (AD-14).
  final void Function(ZExam exam) onSubmit;

  /// Examen initial (édition). `null` ⇒ création (champs vides, `id == null`).
  final ZExam? initialExam;

  /// Dossier d'appartenance (clé NEUTRE `String`, AD-4). `null` ⇒ préserve le
  /// `folderId` de [initialExam] (ou `''` en création).
  final String? folderId;

  /// Picker de date INJECTÉ (AC5). `null` ⇒ le champ date est en lecture seule (le
  /// widget ne choisit JAMAIS une date lui-même, jamais `DateTime.now()`).
  final ZExamDatePicker? onPickDate;

  /// Picker d'heure INJECTÉ (AC2/AC5). `null` ⇒ champ heure en lecture seule.
  final ZExamTimePicker? onPickTime;

  /// Controller du titre INJECTÉ (optionnel). `null` ⇒ l'éditeur en crée/possède un
  /// (disposé au `dispose`). Non-`null` ⇒ UTILISÉ tel quel, JAMAIS disposé (AC6).
  final TextEditingController? titleController;

  /// Controller de saisie de seuil INJECTÉ (optionnel, même contrat owned/injected).
  final TextEditingController? thresholdController;

  /// Libellé INJECTÉ du champ titre (i18n).
  final String titleLabel;

  /// Indice INJECTÉ du champ titre (i18n).
  final String titleHint;

  /// Libellé INJECTÉ de la ligne date (i18n).
  final String dateLabel;

  /// Libellé INJECTÉ quand aucune date n'est choisie (i18n).
  final String dateNotSetLabel;

  /// Libellé sémantique INJECTÉ du bouton de date (lecteur d'écran).
  final String dateSemanticLabel;

  /// Formateur INJECTÉ de la date affichée (i18n — défaut ISO-8601 neutre).
  final ZExamDateLabeler dateLabeler;

  /// Libellé INJECTÉ du toggle de rappels (i18n).
  final String reminderToggleLabel;

  /// Libellé INJECTÉ du champ de seuil (i18n).
  final String thresholdLabel;

  /// Indice INJECTÉ du champ de seuil (i18n).
  final String thresholdHint;

  /// Libellé sémantique INJECTÉ du bouton d'ajout de seuil.
  final String addThresholdSemanticLabel;

  /// Libellé sémantique INJECTÉ du bouton de suppression d'un seuil (défaut documenté).
  final String Function(int threshold) removeThresholdSemanticLabel;

  /// Libellé INJECTÉ de la ligne heure (i18n).
  final String timeLabel;

  /// Libellé INJECTÉ quand aucune heure n'est choisie (i18n).
  final String timeNotSetLabel;

  /// Libellé sémantique INJECTÉ du bouton d'heure (lecteur d'écran).
  final String timeSemanticLabel;

  /// Affiche la section de **récurrence hebdomadaire** (`false` par défaut).
  ///
  /// `false` — le rendu et la valeur émise sont ceux d'un éditeur sans cette
  /// notion : aucune section supplémentaire, et
  /// [ZExam.reminderRecurrence] **n'est pas touché**. Une récurrence déjà
  /// portée par [initialExam] est donc **préservée à l'identique** à la
  /// soumission ; elle n'est ni affichée, ni éditable, ni effacée.
  ///
  /// `true` — une section remplace la ligne d'heure historique et la
  /// **contient** : les sept jours de la semaine, puis cette même ligne
  /// d'heure. L'heure passe toujours par [onPickTime] — le widget n'ouvre
  /// aucun sélecteur lui-même.
  ///
  /// Règle de composition quand la section est affichée :
  /// - jours cochés ⇒ `reminderRecurrence.weekdays` vaut EXACTEMENT
  ///   l'ensemble coché (convention ISO-8601, 1 = lundi … 7 = dimanche) ;
  /// - `reminderRecurrence.daysBefore` de [initialExam] est **reporté tel
  ///   quel** — cette section n'édite que les jours de semaine, et n'a donc
  ///   aucun titre à effacer l'autre famille ;
  /// - tout décoché **et** aucun `daysBefore` de récurrence à reporter ⇒
  ///   `reminderRecurrence == null` (emplacement ABSENT, jamais une récurrence
  ///   vide persistée). [ZExam.reminderDaysBefore], lui, reste intact : c'est
  ///   un champ distinct, édité par la liste de seuils.
  final bool showWeeklyReminders;

  /// Libellé INJECTÉ de la section hebdomadaire (i18n). Utilisé seulement
  /// quand [showWeeklyReminders] vaut `true`.
  final String weeklyRemindersLabel;

  /// Libellé INJECTÉ d'un jour de semaine (i18n). `null` ⇒ repli
  /// `MaterialLocalizations.narrowWeekdays` (abréviation LOCALISÉE de l'hôte
  /// Material) — aucun nom de jour n'est codé en dur dans ce widget.
  ///
  /// Le libellé rendu sert à la fois de texte de la puce et de
  /// `Semantics.label` : injecter un labeler de noms complets améliore
  /// directement la restitution au lecteur d'écran.
  final ZExamWeekdayLabeler? weekdayLabeler;

  /// Libellé INJECTÉ du bouton d'enregistrement (i18n).
  final String submitLabel;

  /// Libellé sémantique INJECTÉ du bouton d'enregistrement (lecteur d'écran).
  final String submitSemanticLabel;

  /// Icône INJECTÉE du bouton d'ajout de seuil (repli neutre documenté).
  final IconData? addThresholdIcon;

  /// Icône INJECTÉE du bouton de suppression de seuil (repli neutre documenté).
  final IconData? removeThresholdIcon;

  static String _defaultDateLabeler(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _defaultRemoveThresholdLabel(int threshold) =>
      'Retirer le seuil de $threshold jour(s)';

  @override
  State<ZExamEditor> createState() => _ZExamEditorState();
}

class _ZExamEditorState extends State<ZExamEditor> {
  /// Controller du titre POSSÉDÉ (créé ici) — `null` si l'appelant en a injecté un.
  TextEditingController? _ownedTitle;

  /// Controller de saisie de seuil POSSÉDÉ — `null` si injecté.
  TextEditingController? _ownedThreshold;

  /// Controller de titre effectif : injecté prioritaire, sinon le possédé.
  TextEditingController get _titleController =>
      widget.titleController ?? _ownedTitle!;

  /// Controller de saisie de seuil effectif : injecté prioritaire, sinon le possédé.
  TextEditingController get _thresholdController =>
      widget.thresholdController ?? _ownedThreshold!;

  /// Date choisie — état LOCAL par champ (AD-2/AD-15). Frontière de rebuild isolée.
  late final ValueNotifier<DateTime?> _date;

  /// Rappels activés — état LOCAL par champ.
  late final ValueNotifier<bool> _reminderEnabled;

  /// Seuils de rappel — état LOCAL, **ordre + doublons PRÉSERVÉS** (AC3, aucun
  /// `sort`/`toSet`).
  late final ValueNotifier<List<int>> _thresholds;

  /// Heure de rappel **TYPÉE** — état LOCAL (AC2/AD-28, jamais une `String`).
  late final ValueNotifier<ZReminderTime?> _time;

  /// Jours de semaine cochés (ISO-8601, 1 = lundi … 7 = dimanche) — état LOCAL.
  ///
  /// Toujours initialisé, même quand la section est masquée : l'état ne coûte
  /// rien et son absence obligerait à un `late` conditionnel. Il n'est LU à la
  /// soumission que si `widget.showWeeklyReminders` est vrai — c'est ce qui
  /// garantit l'inertie du mode par défaut.
  late final ValueNotifier<Set<int>> _weekdays;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExam;
    // Controllers STABLES créés UNE fois (jamais dans build()) — AD-2/AC6.
    if (widget.titleController == null) {
      _ownedTitle = TextEditingController(text: initial?.title ?? '');
    }
    if (widget.thresholdController == null) {
      _ownedThreshold = TextEditingController();
    }
    _date = ValueNotifier<DateTime?>(initial?.date);
    _reminderEnabled = ValueNotifier<bool>(initial?.reminderEnabled ?? false);
    // Copie DÉFENSIVE préservant l'ordre + les doublons (aucune normalisation, AC3).
    _thresholds = ValueNotifier<List<int>>(
      List<int>.of(initial?.reminderDaysBefore ?? const <int>[]),
    );
    _time = ValueNotifier<ZReminderTime?>(initial?.reminderTime);
    // Copie DÉFENSIVE : l'ensemble du domaine n'est jamais muté sur place.
    _weekdays = ValueNotifier<Set<int>>(
      Set<int>.of(initial?.reminderRecurrence?.weekdays ?? const <int>{}),
    );
  }

  @override
  void didUpdateWidget(covariant ZExamEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Transition possédé ↔ injecté (défensif ; jamais recréé pour un rebuild
    // ordinaire — seule une bascule de propriété reconstruit le controller, AC6).
    if (widget.titleController != null && _ownedTitle != null) {
      _ownedTitle!.dispose();
      _ownedTitle = null;
    } else if (widget.titleController == null && _ownedTitle == null) {
      _ownedTitle = TextEditingController(text: widget.initialExam?.title ?? '');
    }
    if (widget.thresholdController != null && _ownedThreshold != null) {
      _ownedThreshold!.dispose();
      _ownedThreshold = null;
    } else if (widget.thresholdController == null && _ownedThreshold == null) {
      _ownedThreshold = TextEditingController();
    }
  }

  @override
  void dispose() {
    // Ne disposer QUE les controllers POSSÉDÉS (jamais un controller injecté — AC6).
    _ownedTitle?.dispose();
    _ownedThreshold?.dispose();
    _date.dispose();
    _reminderEnabled.dispose();
    _thresholds.dispose();
    _time.dispose();
    _weekdays.dispose();
    super.dispose();
  }

  // ── Édition des seuils (AC3 — ordre + doublons PRÉSERVÉS) ─────────────────────

  /// Ajoute le seuil saisi en QUEUE — **APPEND**, aucun `sort`, aucune dédup (AC3).
  ///
  /// Un texte non entier / négatif est IGNORÉ (AD-10). L'ordre de saisie et
  /// les doublons sont significatifs : ni `..sort()` ni `.toSet().toList()`
  /// n'ont leur place ici.
  void _addThreshold() {
    final raw = _thresholdController.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) return;
    // Nouvelle liste (immutabilité de la valeur du notifier) préservant l'ordre.
    _thresholds.value = <int>[..._thresholds.value, parsed];
    _thresholdController.clear();
  }

  /// Retire le seuil à [index] (les autres conservent leur ordre relatif, AC3).
  void _removeThresholdAt(int index) {
    final current = _thresholds.value;
    if (index < 0 || index >= current.length) return;
    _thresholds.value = <int>[
      for (var i = 0; i < current.length; i++)
        if (i != index) current[i],
    ];
  }

  // ── Pickers INJECTÉS (AC5 — aucune horloge implicite dans le widget) ──────────

  Future<void> _pickDate() async {
    final picker = widget.onPickDate;
    if (picker == null) return;
    final chosen = await picker(_date.value);
    _date.value = chosen; // `null` = date effacée (défensif AD-10).
  }

  Future<void> _pickTime() async {
    final picker = widget.onPickTime;
    if (picker == null) return;
    final chosen = await picker(_time.value);
    _time.value = chosen; // `null` = heure vidée ⇒ reminderTime == null (AC2/AD-10).
  }

  // ── Émission : COMPOSE le ZExam à saisie PRÉSERVÉE (AC1) ──────────────────────

  /// Compose et émet le `ZExam` — CHAQUE champ saisi survit à l'identique (AC1).
  ///
  /// Part de [ZExamEditor.initialExam] (ou d'un `ZExam` vide en création) et applique
  /// la saisie via `copyWith` (préserve `extension`/`extra`/`id` de l'examen édité ;
  /// `id == null` en création — AD-14). `reminderDaysBefore` copié DÉFENSIVEMENT
  /// dans l'ordre EXACT (aucune normalisation, AC3). `reminderTime` reste TYPÉ (AC2).
  void _submit() {
    final base = widget.initialExam ?? const ZExam();
    var exam = base.copyWith(
      folderId: widget.folderId ?? base.folderId,
      title: _titleController.text,
      date: _date.value,
      reminderEnabled: _reminderEnabled.value,
      reminderDaysBefore: List<int>.of(_thresholds.value),
      reminderTime: _time.value,
    );
    // Second `copyWith` DÉLIBÉRÉMENT conditionnel : `ZExam.copyWith` distingue
    // « omis » de « null » par sentinelle, mais un argument nommé ne peut pas
    // être omis dynamiquement. Ne pas entrer ici est donc la SEULE façon de
    // laisser `reminderRecurrence` intact — passer `base.reminderRecurrence`
    // « à l'identique » ferait entrer la valeur dans le filtre de copie, et
    // n'aurait plus rien d'une omission.
    if (widget.showWeeklyReminders) {
      exam = exam.copyWith(reminderRecurrence: _composeRecurrence(base));
    }
    widget.onSubmit(exam);
  }

  /// Compose la récurrence à émettre depuis les jours cochés.
  ///
  /// Reporte `daysBefore` de la récurrence initiale : la section n'édite que
  /// les jours de semaine et n'a aucun titre à effacer l'autre famille. Rend
  /// `null` quand les deux familles seraient vides — un emplacement ABSENT,
  /// jamais une récurrence vide (`ZReminderRecurrence.fromJsonSafe` tient la
  /// même règle au retour de persistance).
  ZReminderRecurrence? _composeRecurrence(ZExam base) {
    final carried = base.reminderRecurrence?.daysBefore ?? const <int>[];
    final selected = _weekdays.value;
    if (carried.isEmpty && selected.isEmpty) return null;
    return ZReminderRecurrence(
      daysBefore: List<int>.of(carried),
      weekdays: Set<int>.of(selected),
    );
  }

  /// Coche / décoche un jour ISO — nouvelle valeur d'ensemble (immutabilité).
  void _toggleWeekday(int isoWeekday) {
    final next = Set<int>.of(_weekdays.value);
    if (!next.remove(isoWeekday)) next.add(isoWeekday);
    _weekdays.value = next;
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Column(
      key: const ValueKey<String>('z-exam-editor'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildTitleField(theme),
        SizedBox(height: theme.gapM),
        _buildDateRow(theme),
        SizedBox(height: theme.gapM),
        _buildReminderToggle(theme),
        SizedBox(height: theme.gapM),
        _buildThresholdsField(theme),
        SizedBox(height: theme.gapM),
        // La section CONTIENT la ligne d'heure (jamais un doublon) ; sans elle,
        // c'est la ligne historique qui est construite, au MÊME rang.
        if (widget.showWeeklyReminders)
          _buildWeeklySection(theme)
        else
          _buildTimeRow(theme),
        SizedBox(height: theme.gapL),
        _buildSubmit(theme),
      ],
    );
  }

  Widget _buildTitleField(ZcrudTheme theme) {
    return TextField(
      key: const ValueKey<String>('z-exam-title'),
      controller: _titleController,
      textAlign: TextAlign.start,
      decoration: InputDecoration(
        labelText: widget.titleLabel,
        hintText: widget.titleHint,
      ),
    );
  }

  Widget _buildDateRow(ZcrudTheme theme) {
    return ValueListenableBuilder<DateTime?>(
      key: const ValueKey<String>('z-exam-date'),
      valueListenable: _date,
      builder: (context, date, _) {
        final text =
            date == null ? widget.dateNotSetLabel : widget.dateLabeler(date);
        return Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${widget.dateLabel} : $text',
                textAlign: TextAlign.start,
              ),
            ),
            SizedBox(width: theme.gapS),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: TextButton(
                onPressed: widget.onPickDate == null ? null : _pickDate,
                child: Semantics(
                  label: widget.dateSemanticLabel,
                  button: true,
                  child: Text(text, textAlign: TextAlign.start),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReminderToggle(ZcrudTheme theme) {
    return ValueListenableBuilder<bool>(
      key: const ValueKey<String>('z-exam-reminder-toggle'),
      valueListenable: _reminderEnabled,
      builder: (context, enabled, _) {
        return Row(
          children: <Widget>[
            Expanded(
              child: Text(widget.reminderToggleLabel, textAlign: TextAlign.start),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: Semantics(
                label: widget.reminderToggleLabel,
                toggled: enabled,
                child: Switch(
                  value: enabled,
                  onChanged: (v) => _reminderEnabled.value = v,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThresholdsField(ZcrudTheme theme) {
    return ValueListenableBuilder<List<int>>(
      key: const ValueKey<String>('z-exam-thresholds'),
      valueListenable: _thresholds,
      builder: (context, thresholds, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _thresholdController,
                    textAlign: TextAlign.start,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.thresholdLabel,
                      hintText: widget.thresholdHint,
                    ),
                    onSubmitted: (_) => _addThreshold(),
                  ),
                ),
                SizedBox(width: theme.gapS),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: _kMinTapTarget,
                    minHeight: _kMinTapTarget,
                  ),
                  child: IconButton(
                    onPressed: _addThreshold,
                    tooltip: widget.addThresholdSemanticLabel,
                    icon: Icon(
                      widget.addThresholdIcon ?? _kAddThresholdFallbackIcon,
                      semanticLabel: widget.addThresholdSemanticLabel,
                    ),
                  ),
                ),
              ],
            ),
            if (thresholds.isNotEmpty) SizedBox(height: theme.gapS),
            // Puces des seuils dans l'ORDRE EXACT de saisie (doublons inclus, AC3).
            Wrap(
              spacing: theme.gapS,
              runSpacing: theme.gapS,
              children: <Widget>[
                for (var i = 0; i < thresholds.length; i++)
                  _buildThresholdChip(theme, i, thresholds[i]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildThresholdChip(ZcrudTheme theme, int index, int threshold) {
    final removeLabel = widget.removeThresholdSemanticLabel(threshold);
    return DecoratedBox(
      // Clé indexée : deux seuils ÉGAUX (doublon, AC3) restent des puces DISTINCTES.
      key: ValueKey<String>('z-exam-threshold:$index'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(theme.radiusM),
        border: Border.all(
          color: theme.fieldBorderColor ??
              theme.labelColor ??
              Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: theme.gapM),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('$threshold', textAlign: TextAlign.start),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: IconButton(
                onPressed: () => _removeThresholdAt(index),
                tooltip: removeLabel,
                icon: Icon(
                  widget.removeThresholdIcon ?? _kRemoveThresholdFallbackIcon,
                  semanticLabel: removeLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow(ZcrudTheme theme) {
    return ValueListenableBuilder<ZReminderTime?>(
      key: const ValueKey<String>('z-exam-time'),
      valueListenable: _time,
      builder: (context, time, _) {
        // Le TYPE porte le format : on n'affiche `'HH:mm'` que via `toHhmm()` (AD-28).
        final text = time == null ? widget.timeNotSetLabel : time.toHhmm();
        return Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${widget.timeLabel} : $text',
                textAlign: TextAlign.start,
              ),
            ),
            SizedBox(width: theme.gapS),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: TextButton(
                onPressed: widget.onPickTime == null ? null : _pickTime,
                child: Semantics(
                  label: widget.timeSemanticLabel,
                  button: true,
                  child: Text(text, textAlign: TextAlign.start),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Section hebdomadaire (opt-in) ─────────────────────────────────────────────

  /// Section « jours de semaine + heure », rendue seulement en mode opt-in.
  Widget _buildWeeklySection(ZcrudTheme theme) {
    return Column(
      key: const ValueKey<String>('z-exam-weekly-reminders'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.weeklyRemindersLabel, textAlign: TextAlign.start),
        SizedBox(height: theme.gapS),
        _buildWeekdayChips(theme),
        SizedBox(height: theme.gapM),
        _buildTimeRow(theme),
      ],
    );
  }

  /// Les sept puces de jour, dans l'ordre de la LOCALE (le premier jour de
  /// semaine varie : lundi ici, dimanche ailleurs).
  Widget _buildWeekdayChips(ZcrudTheme theme) {
    // `MaterialLocalizations` indexe les jours à partir de DIMANCHE (0) ;
    // `ZReminderRecurrence` parle ISO (1 = lundi … 7 = dimanche). La
    // conversion est faite ici, une fois, plutôt qu'à chaque site d'usage.
    final l10n = MaterialLocalizations.of(context);
    final first = l10n.firstDayOfWeekIndex;
    return ValueListenableBuilder<Set<int>>(
      key: const ValueKey<String>('z-exam-weekdays'),
      valueListenable: _weekdays,
      builder: (context, selected, _) {
        return Wrap(
          spacing: theme.gapS,
          runSpacing: theme.gapS,
          children: <Widget>[
            for (var i = 0; i < DateTime.daysPerWeek; i++)
              _buildWeekdayChip(
                theme,
                l10n,
                (first + i) % DateTime.daysPerWeek,
                selected,
              ),
          ],
        );
      },
    );
  }

  /// Puce d'un jour. [materialIndex] est l'index Material (0 = dimanche).
  Widget _buildWeekdayChip(
    ZcrudTheme theme,
    MaterialLocalizations l10n,
    int materialIndex,
    Set<int> selected,
  ) {
    final iso = _isoWeekdayOf(materialIndex);
    final label = widget.weekdayLabeler?.call(iso) ??
        // Repli LOCALISÉ : jamais un nom de jour écrit dans ce fichier.
        l10n.narrowWeekdays[materialIndex];
    final isSelected = selected.contains(iso);
    return Semantics(
      // Clé portée par la SÉMANTIQUE : c'est le nœud que mesure la garde de
      // cible tactile, et celui que lit le test d'accessibilité.
      key: ValueKey<String>('z-exam-weekday:$iso'),
      label: label,
      selected: isSelected,
      button: true,
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _kMinTapTarget,
          minHeight: _kMinTapTarget,
        ),
        child: TextButton(
          onPressed: () => _toggleWeekday(iso),
          style: TextButton.styleFrom(
            side: BorderSide(
              color: isSelected
                  ? theme.selectTileSelectedBorderColor ??
                      Theme.of(context).colorScheme.primary
                  : theme.selectTileBorderColor ??
                      theme.fieldBorderColor ??
                      Theme.of(context).colorScheme.outline,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(theme.radiusM),
            ),
          ),
          child: Text(label, textAlign: TextAlign.start),
        ),
      ),
    );
  }

  Widget _buildSubmit(ZcrudTheme theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinTapTarget,
        minHeight: _kMinTapTarget,
      ),
      child: ElevatedButton(
        onPressed: _submit,
        child: Semantics(
          label: widget.submitSemanticLabel,
          button: true,
          child: Text(widget.submitLabel, textAlign: TextAlign.start),
        ),
      ),
    );
  }
}
