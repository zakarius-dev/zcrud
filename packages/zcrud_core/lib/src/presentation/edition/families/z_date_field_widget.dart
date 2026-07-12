/// Widget de la **famille date** (E3-3a) : `dateTime` / `time`.
///
/// Déclencheur de picker (`showDatePicker`/`showTimePicker`) — pickers Material
/// **directionnels** par construction (respectent la `Directionality` ambiante,
/// AD-13). Ces familles ne s'éditent PAS au clavier : elles lisent `value`
/// depuis la tranche et écrivent la valeur choisie via `onChanged` (aucun
/// `TextEditingController` — AD-2). La valeur stockée est **ISO-8601** (date/
/// heure) — conventions dates (`created_at`…).
///
/// a11y (AD-13/FR-23) : déclencheur ≥ 48 dp (`minimumSize`), `Semantics`
/// bouton + libellé (état = valeur courante ou placeholder l10n). Aucune
/// couleur codée en dur (thème hérité — FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

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
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (chaîne ISO-8601 ou `null`).
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
    final current = value is String ? value! as String : '';
    final placeholderKey = switch (_mode) {
      ZDateMode.time => 'selectTime',
      ZDateMode.dateTime => 'selectDateTime',
      ZDateMode.date => 'selectDate',
    };
    // Repli défensif (AC10) : `selectDateTime` absent ⇒ retombe sur `selectDate`.
    final placeholder =
        label(context, placeholderKey, fallback: label(context, 'selectDate'));
    final display = current.isEmpty ? placeholder : current;

    // MIN-2 : croix d'effacement rendue seulement si un callback est fourni
    // (champ non requis + éditable) ET qu'une valeur existe (rien à effacer sinon).
    final showClear =
        onCleared != null && !field.readOnly && current.isNotEmpty;

    // UN SEUL nœud sémantique cohérent (L-1) : le wrapper porte rôle bouton +
    // libellé + valeur + action de tap, et EXCLUT la sémantique descendante
    // (bouton Material + Text) pour éviter la double annonce du lecteur d'écran.
    final trigger = Semantics(
      button: true,
      enabled: !field.readOnly,
      label: resolvedLabel,
      value: display,
      excludeSemantics: true,
      onTap: field.readOnly ? null : () => _pick(context, current),
      child: OutlinedButton(
        // Cible tactile ≥ 48 dp (AD-13) — les boutons Material sont ~40 dp par
        // défaut, on force la hauteur minimale.
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          alignment: AlignmentDirectional.centerStart,
        ),
        onPressed: field.readOnly ? null : () => _pick(context, current),
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
      if (picked != null) {
        final h = picked.hour.toString().padLeft(2, '0');
        final m = picked.minute.toString().padLeft(2, '0');
        onChanged('$h:$m');
      }
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
