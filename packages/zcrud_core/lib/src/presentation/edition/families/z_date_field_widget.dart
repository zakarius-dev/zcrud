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
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition **date/heure** (déclencheur de picker directionnel).
class ZDateFieldWidget extends StatelessWidget {
  /// Construit le champ date lié à [field], valeur courante [value] (ISO-8601
  /// ou `null`), notifiant [onChanged] avec la nouvelle valeur ISO.
  const ZDateFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (chaîne ISO-8601 ou `null`).
  final Object? value;

  /// Notifié avec la valeur **ISO-8601** choisie (`String`).
  final ValueChanged<String> onChanged;

  bool get _isTime => field.type == EditionFieldType.time;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel =
        label(context, field.label ?? field.name, fallback: field.label ?? field.name);
    final current = value is String ? value! as String : '';
    final placeholder =
        label(context, _isTime ? 'selectTime' : 'selectDate');
    final display = current.isEmpty ? placeholder : current;

    // UN SEUL nœud sémantique cohérent (L-1) : le wrapper porte rôle bouton +
    // libellé + valeur + action de tap, et EXCLUT la sémantique descendante
    // (bouton Material + Text) pour éviter la double annonce du lecteur d'écran.
    return Semantics(
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
  }

  Future<void> _pick(BuildContext context, String current) async {
    if (_isTime) {
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
    final initial = DateTime.tryParse(current) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(picked.toIso8601String());
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
