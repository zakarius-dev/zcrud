/// Widget de la **famille dateRange** (AD-47) : `dateRange`.
///
/// Déclencheur de picker de **plage** (`showDateRangePicker`) — picker Material
/// **directionnel** par construction (respecte la `Directionality` ambiante,
/// AD-13). Cette famille ne s'édite PAS au clavier : elle lit `value` depuis la
/// tranche (une [ZDateRange] ou `null`) et écrit la plage choisie via
/// `onChanged` (aucun `TextEditingController` — AD-2). La valeur stockée est un
/// [ZDateRange] pur-Dart (sérialisé `{start, end}` ISO-8601 côté persistance).
///
/// a11y (AD-13/FR-23) : déclencheur ≥ 48 dp (`minimumSize`), `Semantics` bouton
/// + libellé + valeur (`excludeSemantics` sur le wrapper → un seul nœud, pas de
/// double annonce). Aucune couleur codée en dur (thème hérité — FR-26).
///
/// Patron **strict** de `z_date_field_widget.dart` (MIN-2 croix d'effacement,
/// bornes paresseuses `firstDate`/`lastDate` évaluées au tap — AD-2).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_date_range.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition **plage de dates** (déclencheur de picker directionnel).
///
/// Bornes (patron date) : le widget reste **pur et testable** — il n'accède
/// JAMAIS au `ZFormController`. Le dispatcher lui injecte deux **résolveurs**
/// [firstDate]/[lastDate] (`ValueGetter<DateTime?>?`, fermetures pur-Dart)
/// appelés **au tap** (`_pick`). `null` ⇒ repli 1900/2100.
class ZDateRangeFieldWidget extends StatelessWidget {
  /// Construit le champ plage lié à [field], valeur courante [value] ([ZDateRange]
  /// ou `null`), notifiant [onChanged] avec la nouvelle plage.
  const ZDateRangeFieldWidget({
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

  /// Valeur courante de la tranche ([ZDateRange] ou `null`).
  final Object? value;

  /// Notifié avec la [ZDateRange] choisie.
  final ValueChanged<ZDateRange> onChanged;

  /// Résolveur **paresseux** de la borne basse, évalué au tap. `null` ou retour
  /// `null` ⇒ repli `DateTime(1900)`.
  final ValueGetter<DateTime?>? firstDate;

  /// Résolveur **paresseux** de la borne haute, évalué au tap. `null` ou retour
  /// `null` ⇒ repli `DateTime(2100)`.
  final ValueGetter<DateTime?>? lastDate;

  /// MIN-2 (croix d'effacement) — callback d'**effacement** (retour à `null`). Le
  /// dispatcher ne le fournit que pour un champ **non requis** et éditable ; une
  /// croix accessible n'est rendue que si [onCleared] est non `null` ET qu'une
  /// plage est présente. `null` (défaut) ⇒ aucune croix.
  final VoidCallback? onCleared;

  /// Plage courante typée, ou `null` si la tranche ne porte pas de [ZDateRange].
  ZDateRange? get _range => value is ZDateRange ? value! as ZDateRange : null;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);
    final range = _range;
    // Placeholder l10n : `selectDateRange` si fourni, sinon repli sur `selectDate`
    // (jamais un littéral codé en dur — FR-26).
    final placeholder = label(context, 'selectDateRange',
        fallback: label(context, 'selectDate'));
    final display = range == null ? placeholder : _formatRange(range);

    // MIN-2 : croix rendue seulement si un callback est fourni (champ non requis
    // + éditable) ET qu'une plage existe (rien à effacer sinon).
    final showClear = onCleared != null && !field.readOnly && range != null;

    // UN SEUL nœud sémantique cohérent : le wrapper porte rôle bouton + libellé +
    // valeur + tap, et EXCLUT la sémantique descendante (double annonce).
    final trigger = Semantics(
      button: true,
      enabled: !field.readOnly,
      label: resolvedLabel,
      value: display,
      excludeSemantics: true,
      onTap: field.readOnly ? null : () => _pick(context, range),
      child: OutlinedButton(
        // Cible tactile ≥ 48 dp (AD-13).
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          alignment: AlignmentDirectional.centerStart,
        ),
        onPressed: field.readOnly ? null : () => _pick(context, range),
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

  /// Affichage d'une plage : `start → end` en **dates ISO-8601** (`YYYY-MM-DD`).
  /// Le format ISO est un **choix délibéré assumé**, cohérent avec la famille
  /// date sœur (`z_date_field_widget.dart`) et l'ISO en persistance (AC-A2) —
  /// ce n'est PAS un format localisé. Aucune **couleur** codée en dur (thème
  /// hérité — FR-26).
  static String _formatRange(ZDateRange r) =>
      '${_isoDate(r.start)} → ${_isoDate(r.end)}';

  /// Partie **date** (`YYYY-MM-DD`) d'un `DateTime` en ISO-8601.
  static String _isoDate(DateTime d) => d.toIso8601String().split('T').first;

  Future<void> _pick(BuildContext context, ZDateRange? current) async {
    // Bornes résolues (littéral > cross-champ, via résolveurs) puis repli.
    var first = firstDate?.call() ?? DateTime(1900);
    var last = lastDate?.call() ?? DateTime(2100);
    // Défensif : `first > last` déclencherait l'assertion Material ⇒ replier la
    // borne basse sur la borne haute.
    if (first.isAfter(last)) first = last;

    // Plage initiale = valeur courante clampée dans l'intervalle (jamais hors
    // bornes — sinon assertion Material). Le clamp est monotone ⇒ `start <= end`
    // préservé.
    final DateTimeRange? initialRange = current == null
        ? null
        : DateTimeRange(
            start: _clamp(current.start, first, last),
            end: _clamp(current.end, first, last),
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: initialRange,
    );
    // Annulation ⇒ abandon complet (aucun `onChanged`).
    if (picked == null) return;
    onChanged(ZDateRange(start: picked.start, end: picked.end));
  }

  /// Borne [v] dans `[lo, hi]` (monotone).
  static DateTime _clamp(DateTime v, DateTime lo, DateTime hi) {
    if (v.isBefore(lo)) return lo;
    if (v.isAfter(hi)) return hi;
    return v;
  }
}
