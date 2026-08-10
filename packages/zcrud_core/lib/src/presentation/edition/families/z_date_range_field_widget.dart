/// Widget de la **famille dateRange** (AD-47) : `dateRange`.
///
/// Déclencheur de picker de **plage** (`showDateRangePicker`) — picker Material
/// **directionnel** par construction (respecte la `Directionality` ambiante,
/// AD-13). Cette famille ne s'édite PAS au clavier : elle lit `value` depuis la
/// tranche (une [ZDateRange] ou `null`) et écrit la plage choisie via
/// `onChanged` (aucun `TextEditingController` — AD-2). La valeur stockée est un
/// [ZDateRange] pur-Dart (sérialisé `{start, end}` ISO-8601 côté persistance).
///
/// **CR-DODLP-DATE-FIELD** — comme la famille date sœur, le déclencheur est un
/// **champ décoré** (`ZDecoratedFieldTrigger`) ; l'ancien `OutlinedButton` reste
/// atteignable par [ZDateRangeFieldWidget.decorated] ou le jeton
/// `ZcrudTheme.dateFieldDecorated`.
///
/// **CR-IFFD-79** — miroir exact du défaut de la famille date sœur : ce champ
/// n'acceptait que [ZDateRange], le type que SON sélecteur écrit, alors que la
/// forme **persistée** d'un champ `ZDateRange` est une Map `{start, end}`
/// (`toMap()` généré ⇒ `ZDateRange.toJson()`). Les deux conventions d'amorçage
/// d'un formulaire — depuis les champs du modèle, ou depuis son `toMap()` —
/// cassaient donc chacune UNE des deux familles. Les deux sont désormais lues.
///
/// a11y (AD-13/FR-23) : déclencheur ≥ 48 dp (contrainte liante), `Semantics`
/// bouton + libellé + valeur + `isRequired` (`excludeSemantics` sur le wrapper →
/// un seul nœud, pas de double annonce). Aucune couleur en dur (FR-26).
///
/// Patron **strict** de `z_date_field_widget.dart` (MIN-2 croix d'effacement,
/// bornes paresseuses `firstDate`/`lastDate` évaluées au tap — AD-2).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_date_range.dart';
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../z_decorated_field_trigger.dart';
import '../z_read_only_value.dart';

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
    this.decorated,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche.
  ///
  /// CR-IFFD-79 — l'ÉCRITURE reste un [ZDateRange], mais la LECTURE accepte
  /// aussi la **Map `{start, end}` réellement persistée** (ce que le `toMap()`
  /// généré émet), décodée par le décodeur défensif du paquet. Toute autre
  /// valeur non nulle est rendue par son `toString()` — jamais effacée.
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

  /// CR-DODLP-DATE-FIELD — **échappatoire d'apparence**, identique à
  /// `ZDateFieldWidget.decorated` : `true` ⇒ champ décoré ; `false` ⇒ rendu
  /// historique `OutlinedButton` ; `null` (défaut) ⇒ jeton de thème
  /// `ZcrudTheme.dateFieldDecorated`, lui-même à défaut `true`.
  final bool? decorated;

  /// Plage courante typée, ou `null` si la graine n'est pas décodable.
  ///
  /// CR-IFFD-79 — le champ n'acceptait que le type que SON sélecteur écrit
  /// ([ZDateRange]). Or la forme **réellement persistée** d'un champ
  /// `ZDateRange` est une **Map** `{start, end}` : le `toMap()` généré émet
  /// `ZDateRange.toJson()` (`_toMapExpr`, catégorie `dateRangeType`). Un hôte
  /// qui sème son formulaire depuis `toMap()` — la convention symétrique de
  /// celle qui casse la famille date sœur — portait donc une Map, et le champ
  /// rendait **vide** une plage qui serait resoumise intacte.
  ///
  /// Le décodage passe par [ZDateRange.fromJsonSafe], le décodeur **défensif**
  /// déjà utilisé par la voie de persistance (`_$asDateRange`) : `null` sur
  /// TOUTE anomalie, jamais de throw (AD-10). Aucune seconde convention de
  /// décodage n'entre ici.
  ZDateRange? get _range {
    final v = value;
    if (v is ZDateRange) return v;
    if (v is Map) return ZDateRange.fromJsonSafe(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);
    final range = _range;
    // Placeholder l10n : `selectDateRange` si fourni, sinon repli sur `selectDate`
    // (jamais un littéral codé en dur — FR-26).
    final placeholder = label(context, 'selectDateRange',
        fallback: label(context, 'selectDate'));
    // Projection calculée UNE FOIS par build (AD-2 : le port de l'hôte n'est
    // pas appelé deux fois pour la même plage — `display` et `valueText`
    // partagent la même chaîne).
    //
    // CR-IFFD-79 — hors contrat : une graine non nulle que le décodeur défensif
    // n'a pas su lire retombe sur `'$value'`, le **repli déjà défini par le
    // paquet** (`zDateDisplayTextOf`) — aucune invention de format. La taire
    // produirait le « contrôle qui paraît vide alors que la donnée sera
    // soumise » proscrit par CR-IFFD-77 : la valeur est bien là et sera
    // resoumise. Présence et identité restent dissociées (`v0.65.0`).
    final rangeText = range != null
        ? _formatRange(context, range)
        : value == null
            ? ''
            : '$value';
    final hasValue = rangeText.isNotEmpty;
    final display = hasValue ? rangeText : placeholder;

    // MIN-2 : croix rendue seulement si un callback est fourni (champ non requis
    // + éditable) ET qu'une valeur existe (rien à effacer sinon). CR-IFFD-79 :
    // c'est bien la PRÉSENCE qui pilote la croix — une graine hors contrat est
    // effaçable, sinon elle serait resoumise sans recours.
    final showClear = onCleared != null && !field.readOnly && hasValue;

    final onTap = field.readOnly ? null : () => _pick(context, range);

    // CR-DODLP-DATE-FIELD — champ DÉCORÉ par défaut (même traitement que la
    // famille date sœur : la CR ne nomme que `dateTime`, mais `dateRange`
    // portait le MÊME `OutlinedButton` — le corriger d'un seul côté recréerait
    // l'incohérence que la CR ferme).
    final Widget trigger = zResolveDateFieldDecorated(context, decorated)
        ? ZDecoratedFieldTrigger(
            field: field,
            semanticsLabel: resolvedLabel,
            placeholder: placeholder,
            valueText: rangeText,
            hasValue: hasValue,
            onTap: onTap,
            trailingIcon: const Icon(Icons.date_range_outlined),
          )
        // ── Échappatoire : rendu historique `OutlinedButton` ────────────────
        // UN SEUL nœud sémantique cohérent : le wrapper porte rôle bouton +
        // libellé + valeur + tap, et EXCLUT la sémantique descendante.
        : Semantics(
            button: true,
            enabled: !field.readOnly,
            label: resolvedLabel,
            value: display,
            excludeSemantics: true,
            onTap: onTap,
            child: OutlinedButton(
              // Cible tactile ≥ 48 dp (AD-13).
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

  /// Affichage d'une plage : `start → end`, chaque borne projetée par le port
  /// `ZDateDisplayFormatter` en mode [ZDateMode.date] (CR-DODLP-DATE-DISPLAY).
  ///
  /// **Pourquoi `dateRange` est traité ici alors qu'il n'a pas de voie de
  /// lecture séparée** : `dateRange` n'est ni tabulaire (absent de
  /// `_tabularTypes`, il n'apparaît jamais dans une `DynamicList`) ni
  /// fiche-able (`zReadModeCardable` → `false` : en lecture c'est CE widget,
  /// `readOnly`, qui rend). Il ne porte donc PAS l'incohérence *inter-surfaces*
  /// de la famille date. Il porte l'autre moitié du même défaut : sous un port
  /// injecté, un formulaire afficherait `Dim. 9 août 2026` pour un `dateTime`
  /// et `2026-08-09 → …` pour la plage juste à côté. Corriger une famille sur
  /// deux recréerait l'incohérence qu'on ferme.
  ///
  /// 🔴 Hôte passif STRICTEMENT immobile (AD-10) : la borne entre dans la règle
  /// partagée **déjà normalisée en `YYYY-MM-DD`** — le repli de
  /// `zDateDisplayTextOf` étant `'$value'`, port absent / port rendant
  /// `null`/vide / port qui lève redonnent **exactement** l'ISO d'avant. (Passer
  /// le `DateTime` nu ferait replier sur `DateTime.toString()`, qui n'est pas
  /// l'ISO — le piège déjà relevé côté `ZListColumn`.) Aucune **couleur** codée
  /// en dur (thème hérité — FR-26).
  static String _formatRange(BuildContext context, ZDateRange r) =>
      '${_boundText(context, r.start)} → ${_boundText(context, r.end)}';

  /// Projette UNE borne : ISO `YYYY-MM-DD` → port (mode `date`) → repli ISO.
  static String _boundText(BuildContext context, DateTime d) =>
      zDateDisplayTextForMode(context, _isoDate(d), mode: ZDateMode.date);

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
