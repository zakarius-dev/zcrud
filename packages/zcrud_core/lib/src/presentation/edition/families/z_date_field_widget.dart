/// Widget de la **famille date** (E3-3a) : `dateTime` / `time`.
///
/// Déclencheur de picker (`showDatePicker`/`showTimePicker`) — pickers Material
/// **directionnels** par construction (respectent la `Directionality` ambiante,
/// AD-13). Ces familles ne s'éditent PAS au clavier : elles lisent `value`
/// depuis la tranche et écrivent la valeur choisie via `onChanged` (aucun
/// `TextEditingController` — AD-2). La valeur stockée est **ISO-8601** (date/
/// heure) — conventions dates (`created_at`…).
///
/// **CR-DODLP-DATE-FIELD** — le déclencheur est désormais un **champ décoré**
/// (`ZDecoratedFieldTrigger` : `InputDecorator` + `zFieldDecoration`), donc
/// libellé flottant, astérisque « requis », bordure et remplissage pilotés par
/// les mêmes jetons que `text`/`number`/`select`. L'ancien `OutlinedButton`
/// reste atteignable par [ZDateFieldWidget.decorated] `= false` ou par le jeton
/// `ZcrudTheme.dateFieldDecorated`.
///
/// **CR-DODLP-DATE-DISPLAY** — la valeur SAISIE est désormais projetée par le
/// port `ZDateDisplayFormatter` (le même que la fiche de lecture, le résumé de
/// sous-liste et la liste), via la règle de repli partagée. Sans port injecté,
/// l'affichage est **strictement** l'ISO brut d'avant (AD-10).
///
/// **CR-IFFD-79** — le champ n'affichait sa valeur que si elle avait le type que
/// son propre sélecteur ÉCRIT (`String`). Une valeur SEMÉE depuis la
/// persistance (`DateTime`, ou `TimeOfDay` en mode `time`) rendait un champ
/// **vide** alors qu'elle serait resoumise intacte. La graine est désormais
/// normalisée par `_seedText` vers la convention d'écriture de son mode, et une
/// graine hors contrat rend sa **présence** au lieu du vide silencieux.
///
/// a11y (AD-13/FR-23) : déclencheur ≥ 48 dp (contrainte liante), `Semantics`
/// bouton + libellé + valeur + `isRequired` (état = valeur courante ou
/// placeholder l10n). Aucune couleur codée en dur (thème hérité — FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../z_decorated_field_trigger.dart';
import '../z_read_only_value.dart';

/// Champ d'édition **date/heure** (déclencheur de picker directionnel).
///
/// Mode effectif (D2) : [ZDateConfig.mode] s'il est fourni ; sinon dérivé du
/// type (`time` → `time` ; sinon → `dateTime` combiné date+heure, fix B13).
///
/// Bornes (D3/D4) : le widget reste **pur et testable** — il n'accède JAMAIS au
/// `ZFormController`. Le dispatcher lui injecte deux **résolveurs**
/// [firstDate]/[lastDate] (`ValueGetter<DateTime?>?`, fermetures pur-Dart)
/// appelés **au tap** (`_pick`) pour lire des bornes cross-champ **fraîches**
/// sans abonnement réactif ni rebuild global (AD-2). `null` ⇒ repli 1900/2100.
class ZDateFieldWidget extends StatelessWidget {
  /// Construit le champ date lié à [field], valeur courante [value] (ISO-8601
  /// ou `null`), notifiant [onChanged] avec la nouvelle valeur ISO.
  const ZDateFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.onCleared,
    this.decorated,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche.
  ///
  /// CR-IFFD-79 — l'ÉCRITURE reste la chaîne ISO-8601 (`HH:mm` en mode `time`),
  /// mais la LECTURE accepte aussi les types qu'une persistance rend
  /// naturellement : `DateTime` (tous modes) et `TimeOfDay` (mode `time`). Tout
  /// autre type non nul est rendu par son `toString()` — jamais effacé.
  final Object? value;

  /// Notifié avec la valeur **ISO-8601** choisie (`String`).
  final ValueChanged<String> onChanged;

  /// Résolveur **paresseux** de la borne basse (littéral > cross-champ), évalué
  /// au tap. `null` ou retour `null` ⇒ repli `DateTime(1900)`.
  final ValueGetter<DateTime?>? firstDate;

  /// Résolveur **paresseux** de la borne haute (littéral > cross-champ), évalué
  /// au tap. `null` ou retour `null` ⇒ repli `DateTime(2100)`.
  final ValueGetter<DateTime?>? lastDate;

  /// MIN-2 (parité DODLP « croix d'effacement ») — callback d'**effacement** de la
  /// valeur (retour à `null`). Le dispatcher ne le fournit que pour un champ **non
  /// requis** et éditable ; une **croix** accessible n'est rendue que si
  /// [onCleared] est non `null` ET qu'une valeur est présente. `null` (défaut) ⇒
  /// aucune croix (rendu antérieur strictement inchangé).
  final VoidCallback? onCleared;

  /// CR-DODLP-DATE-FIELD — **échappatoire d'apparence**. `true` ⇒ champ décoré
  /// (`InputDecorator` + `zFieldDecoration`) ; `false` ⇒ rendu historique
  /// `OutlinedButton` « Libellé : valeur ». `null` (défaut) ⇒ jeton de thème
  /// `ZcrudTheme.dateFieldDecorated`, lui-même à défaut `true`.
  ///
  /// Chaîne **paramètre > jeton > référence** (référence du paquet = décoré).
  final bool? decorated;

  /// Mode d'édition effectif (D2) — jamais `null`.
  ZDateMode get _mode {
    final cfg = field.config;
    if (cfg is ZDateConfig && cfg.mode != null) return cfg.mode!;
    if (field.type == EditionFieldType.time) return ZDateMode.time;
    return ZDateMode.dateTime;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel =
        label(context, field.label ?? field.name, fallback: field.label ?? field.name);
    // CR-IFFD-79 — la graine est LUE quel que soit le type que l'hôte porte,
    // pas seulement celui que le sélecteur de ce champ ÉCRIT (cf. `_seedText`).
    final current = _seedText(value, _mode);
    final placeholderKey = switch (_mode) {
      ZDateMode.time => 'selectTime',
      ZDateMode.dateTime => 'selectDateTime',
      ZDateMode.date => 'selectDate',
    };
    // Repli défensif (AC10) : `selectDateTime` absent ⇒ retombe sur `selectDate`.
    final placeholder =
        label(context, placeholderKey, fallback: label(context, 'selectDate'));
    // CR-DODLP-DATE-DISPLAY — projection d'AFFICHAGE de la valeur SAISIE par le
    // même port `ZDateDisplayFormatter` que la fiche de lecture, le résumé de
    // sous-liste et la liste (v0.69.0/v0.70.0). Le champ écrivait jusqu'ici
    // l'ISO brut : le MÊME champ rendait `Dim. 9 août 2026` en liste et
    // `2026-08-09T00:00:00.000` dans le formulaire.
    //
    // 🔴 Hôte passif STRICTEMENT immobile (AD-10) : la règle de repli est
    // partagée (`zDateDisplayTextOf`, via `zDateDisplayText` qui lit le scope
    // et la locale) et vaut **la chaîne brute** dans TOUS les chemins dégradés
    // — port absent, mode `time` (jamais routé), valeur non parsable, port
    // rendant `null`/vide, port qui lève. Le mode est lu par `zDateModeOf` :
    // la MÊME source que `_mode` et que les voies de lecture (jamais recopiée).
    //
    // ⚠️ Seul l'AFFICHAGE passe par le port : `current` (ISO brut) reste la
    // valeur pilotant `hasValue`, la croix d'effacement et `_pick`.
    final valueDisplay =
        current.isEmpty ? '' : zDateDisplayText(context, field, current);
    final display = current.isEmpty ? placeholder : valueDisplay;

    // MIN-2 : croix d'effacement rendue seulement si un callback est fourni
    // (champ non requis + éditable) ET qu'une valeur existe (rien à effacer sinon).
    final showClear =
        onCleared != null && !field.readOnly && current.isNotEmpty;

    final onTap = field.readOnly ? null : () => _pick(context, current);

    // CR-DODLP-DATE-FIELD — champ DÉCORÉ par défaut (même chaîne
    // `zFieldDecoration` que `text`/`number`/`select` : libellé flottant,
    // astérisque requis, jetons `fieldFillColor`/`fieldBorderColor`).
    // `decorated: false` (ou le jeton de thème) restitue le rendu bouton.
    final Widget trigger = zResolveDateFieldDecorated(context, decorated)
        ? ZDecoratedFieldTrigger(
            field: field,
            semanticsLabel: resolvedLabel,
            placeholder: placeholder,
            valueText: valueDisplay,
            hasValue: current.isNotEmpty,
            onTap: onTap,
            trailingIcon: Icon(
              _mode == ZDateMode.time
                  ? Icons.access_time_outlined
                  : Icons.calendar_today_outlined,
            ),
          )
        // ── Échappatoire : rendu historique `OutlinedButton` ────────────────
        // UN SEUL nœud sémantique cohérent (L-1) : le wrapper porte rôle bouton
        // + libellé + valeur + action de tap, et EXCLUT la sémantique
        // descendante (bouton Material + Text) — pas de double annonce.
        : Semantics(
            button: true,
            enabled: !field.readOnly,
            label: resolvedLabel,
            value: display,
            excludeSemantics: true,
            onTap: onTap,
            child: OutlinedButton(
              // Cible tactile ≥ 48 dp (AD-13) — les boutons Material sont ~40 dp
              // par défaut, on force la hauteur minimale.
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                alignment: AlignmentDirectional.centerStart,
              ),
              onPressed: onTap,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('$resolvedLabel : $display'),
              ),
            ),
          );

    if (!showClear) return trigger;

    // La croix vit HORS du nœud `excludeSemantics` du déclencheur → son propre
    // rôle bouton + libellé (`clear`), cible ≥ 48 dp (AD-13), directionnel.
    return Row(
      children: <Widget>[
        Expanded(child: trigger),
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: label(context, 'clear'),
          onPressed: onCleared,
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, String current) async {
    // --- Heure seule (comportement historique strictement préservé, AC7) ---
    if (_mode == ZDateMode.time) {
      final initial = _parseTime(current) ?? TimeOfDay.now();
      final picked =
          await showTimePicker(context: context, initialTime: initial);
      // CR-IFFD-79 : `_hhmm` est la source UNIQUE de la convention `HH:mm` —
      // la lecture d'une graine (`_seedText`) et l'écriture du sélecteur ne
      // peuvent plus diverger.
      if (picked != null) onChanged(_hhmm(picked.hour, picked.minute));
      return;
    }

    // --- Étape date (mode `date` ET `dateTime`), bornée (B12/AC4/AC8) ---
    final currentDt = DateTime.tryParse(current);
    // Bornes résolues (littéral > cross-champ, via résolveurs) puis repli.
    var first = firstDate?.call() ?? DateTime(1900);
    var last = lastDate?.call() ?? DateTime(2100);
    // Défensif (AC8) : `firstDate > lastDate` déclencherait l'assertion Material
    // ⇒ replier la borne basse sur la borne haute.
    if (first.isAfter(last)) first = last;
    // Date initiale = valeur courante sinon maintenant, clampée dans l'intervalle
    // (parité DODLP `edition_screen.dart:3600` — jamais d'`initialDate` hors bornes).
    var initialDate = currentDt ?? DateTime.now();
    if (initialDate.isBefore(first)) initialDate = first;
    if (initialDate.isAfter(last)) initialDate = last;

    if (!context.mounted) return;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
    );
    // Annulation de l'étape date ⇒ abandon complet (aucun `onChanged`).
    if (pickedDate == null) return;

    // Mode `date` seul ⇒ date à minuit, pas d'heure demandée (AC7).
    if (_mode == ZDateMode.date) {
      onChanged(pickedDate.toIso8601String());
      return;
    }

    // --- Étape heure (mode `dateTime` combiné, B13/AC6) ---
    // Heure préexistante conservée si présente, sinon minuit.
    final preexistingTime =
        currentDt != null ? TimeOfDay.fromDateTime(currentDt) : const TimeOfDay(hour: 0, minute: 0);
    if (!context.mounted) return;
    final pickedTime =
        await showTimePicker(context: context, initialTime: preexistingTime);
    // Annulation de l'étape heure ⇒ conserver la date choisie AVEC l'heure
    // préexistante (jamais écrasée à minuit par erreur).
    final effectiveTime = pickedTime ?? preexistingTime;
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      effectiveTime.hour,
      effectiveTime.minute,
    );
    onChanged(combined.toIso8601String());
  }

  /// CR-IFFD-79 — normalise la **graine** en la chaîne que le sélecteur de ce
  /// [mode] écrit lui-même. C'est le seul point d'entrée de `value` : tout le
  /// reste du widget (affichage, `hasValue`, croix d'effacement, `_pick`)
  /// consomme cette chaîne.
  ///
  /// ## Le défaut fermé ici
  ///
  /// Le champ ne lisait `value` que si elle était une `String` — le type que
  /// SON sélecteur produit. Une valeur venue de la persistance (`DateTime`,
  /// `TimeOfDay`) rendait donc un champ **VIDE** alors qu'elle serait
  /// **resoumise intacte** : un mensonge d'affichage. La règle appliquée était
  /// « j'accepte ce que j'écris » ; la règle utile est « j'accepte ce qu'on
  /// peut me donner ».
  ///
  /// ## Pourquoi la normalisation, et pas un passage direct au port
  ///
  /// Chaque type reconnu est projeté vers **exactement la convention d'écriture
  /// de son mode** (`toIso8601String()` pour date/dateTime, `HH:mm` pour
  /// `time` — cf. `_pick`). Rien n'est inventé : aucun format nouveau n'entre
  /// dans le paquet. C'est ce qui permet à la valeur d'ATTEINDRE le port
  /// `ZDateDisplayFormatter` par le chemin déjà en place (v0.69.0/v0.71.0), et
  /// de garder un **repli AD-10 identique à l'ISO d'avant** : passer le
  /// `DateTime` nu ferait replier sur `DateTime.toString()`, qui n'est PAS
  /// l'ISO (le piège déjà relevé sur `ZListColumn` et `dateRange`).
  ///
  /// ## Hors contrat : la présence, jamais le vide
  ///
  /// Une valeur non nulle d'un type non reconnu retombe sur `'$value'` — le
  /// **repli déjà défini par le paquet** (`zDateDisplayTextOf`), donc aucune
  /// invention de format. Elle sera resoumise : la taire produirait le
  /// « contrôle qui paraît vide alors que la donnée sera soumise » proscrit par
  /// CR-IFFD-77, et rejouerait le choix déjà tranché en `v0.65.0` (dissocier
  /// **présence** et **identité** plutôt qu'effacer). L'affichage peut être
  /// laid ; il ne ment pas.
  ///
  /// `null` ⇒ chaîne vide ⇒ placeholder (hôte passif strictement immobile).
  static String _seedText(Object? value, ZDateMode mode) {
    if (value == null) return '';
    // Convention d'écriture du champ — inchangée, aucun hôte ne bouge.
    if (value is String) return value;
    if (mode == ZDateMode.time) {
      // `time` écrit `HH:mm` (cf. `_pick`) : c'est la seule forme que
      // `_parseTime` relit et que le port n'a jamais à projeter.
      if (value is TimeOfDay) return _hhmm(value.hour, value.minute);
      if (value is DateTime) return _hhmm(value.hour, value.minute);
    } else if (value is DateTime) {
      // `date`/`dateTime` écrivent l'ISO-8601 (cf. `_pick`).
      return value.toIso8601String();
    }
    return '$value';
  }

  /// Heure au format `HH:mm` — la MÊME composition que celle écrite par `_pick`
  /// en mode `time` (jamais une seconde convention).
  static String _hhmm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Parse une heure `HH:mm` en `TimeOfDay`, ou `null`.
  static TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}
