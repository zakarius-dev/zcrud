/// Widget de la **famille dateRange** : `dateRange`.
///
/// Déclencheur de picker de **plage** (`showDateRangePicker`) — picker Material
/// **directionnel** par construction (respecte la `Directionality` ambiante,
/// invariant AD-13). Cette famille ne s'édite PAS au clavier : elle lit
/// `value` depuis la tranche (une [ZDateRange] ou `null`) et écrit la plage
/// choisie via `onChanged` (aucun `TextEditingController` — invariant AD-2).
/// La valeur stockée est un [ZDateRange] pur-Dart (sérialisé `{start, end}`
/// ISO-8601 côté persistance).
///
/// Comme la famille date sœur, le déclencheur est un **champ décoré**
/// (`ZDecoratedFieldTrigger`) ; un rendu `OutlinedButton` plus simple reste
/// atteignable par [ZDateRangeFieldWidget.decorated] ou le jeton
/// `ZcrudTheme.dateFieldDecorated`.
///
/// Miroir exact de la famille date sœur : ce champ accepte [ZDateRange], le
/// type que SON sélecteur écrit, **et** la forme **persistée** d'un champ
/// `ZDateRange`, une Map `{start, end}` (`toMap()` généré ⇒
/// `ZDateRange.toJson()`). Les deux conventions d'amorçage d'un formulaire —
/// depuis les champs du modèle, ou depuis son `toMap()` — sont donc lues.
///
/// a11y (invariant AD-13/FR-23) : déclencheur ≥ 48 dp (contrainte liante),
/// `Semantics` bouton + libellé + valeur + `isRequired` (`excludeSemantics`
/// sur le wrapper → un seul nœud, pas de double annonce). Aucune couleur en
/// dur (invariant FR-26).
///
/// Patron **strict** de `z_date_field_widget.dart` (croix d'effacement,
/// bornes paresseuses `firstDate`/`lastDate` évaluées au tap — invariant AD-2).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;

import '../../../domain/edition/z_date_range.dart';
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../z_decorated_field_trigger.dart';
import '../z_read_only_value.dart';

/// Message de **refus d'amplitude** d'une plage, ou `null` si la période est
/// admise.
///
/// Confronte l'amplitude de [range] — son nombre de **jours couverts, bornes
/// incluses** ([ZDateRange.spanDays]) — aux contraintes déclarées par le champ
/// ([ZDateConfig.maxDays]/[ZDateConfig.minDays]). `config` à `null`, ou sans
/// amplitude déclarée, rend toujours `null` : un champ qui ne déclare pas
/// d'amplitude n'est jamais refusé.
///
/// Le message **nomme le nombre autorisé et son unité** — « La période ne doit
/// pas dépasser 7 jours (bornes incluses) ». Le nombre affiché est exactement
/// la valeur déclarée dans la config : aucun décalage entre ce que l'hôte écrit
/// et ce que l'utilisateur lit. Libellés résolus par la chaîne l10n habituelle
/// (`ZcrudScope.labels` → delegate → repli `en`), jamais un texte codé en dur.
String? zDateSpanRefusalMessage(
  BuildContext context,
  ZDateConfig? config,
  ZDateRange range,
) {
  if (config == null) return null;
  switch (config.checkSpanDays(range.spanDays)) {
    case ZDateSpanVerdict.accepted:
      return null;
    case ZDateSpanVerdict.tooLong:
      return '${label(context, 'dateRangeTooLong')} '
          '${config.effectiveMaxDays} ${label(context, 'daysInclusive')}';
    case ZDateSpanVerdict.tooShort:
      return '${label(context, 'dateRangeTooShort')} '
          '${config.effectiveMinDays} ${label(context, 'daysInclusive')}';
  }
}

/// Présente le refus d'amplitude [message] à l'utilisateur, **au moment de la
/// sélection**.
///
/// Deux canaux, jamais le seul visuel (invariant AD-13) : une **annonce**
/// lecteur d'écran immédiate (`SemanticsService`), puis une boîte de dialogue
/// dont le texte est une **région vivante** (`liveRegion`) — la période refusée
/// est donc énoncée, pas seulement montrée.
///
/// N'écrit rien : c'est l'appelant qui, en ne propageant pas la plage, laisse
/// le champ **sur sa valeur précédente**.
void zShowDateSpanRefusal(BuildContext context, String message) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(label(dialogContext, 'invalidValue')),
      content: Semantics(
        liveRegion: true,
        container: true,
        child: Text(message),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(label(dialogContext, 'close')),
        ),
      ],
    ),
  );
}

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
  /// L'ÉCRITURE reste un [ZDateRange], mais la LECTURE accepte
  /// aussi la **Map `{start, end}` réellement persistée** (ce que le `toMap()`
  /// généré émet), décodée par le décodeur défensif du paquet. Toute autre
  /// valeur non nulle est rendue par son `toString()` — jamais effacée.
  final Object? value;

  /// Notifié avec la [ZDateRange] choisie.
  ///
  /// **Amplitude** ([ZDateConfig.maxDays]/[ZDateConfig.minDays]) : comme les
  /// bornes, la contrainte est honorée par le **dispatcher** de champ
  /// (`ZFieldWidget`), seul point qui détient la déclaration ET l'écriture de
  /// la tranche. Une période trop large ou trop courte n'est **pas écrite** —
  /// le champ garde sa valeur précédente — et [zShowDateSpanRefusal] l'annonce.
  /// Un hôte qui monte ce widget à la main garde donc la main sur ce qu'il
  /// accepte : [zDateSpanRefusalMessage] lui rend le même verdict.
  final ValueChanged<ZDateRange> onChanged;

  /// Résolveur **paresseux** de la borne basse, évalué au tap. `null` ou retour
  /// `null` ⇒ repli `DateTime(1900)`.
  final ValueGetter<DateTime?>? firstDate;

  /// Résolveur **paresseux** de la borne haute, évalué au tap. `null` ou retour
  /// `null` ⇒ repli `DateTime(2100)`.
  final ValueGetter<DateTime?>? lastDate;

  /// Callback d'**effacement** (retour à `null`). Le
  /// dispatcher ne le fournit que pour un champ **non requis** et éditable ; une
  /// croix accessible n'est rendue que si [onCleared] est non `null` ET qu'une
  /// plage est présente. `null` (défaut) ⇒ aucune croix.
  final VoidCallback? onCleared;

  /// **Échappatoire d'apparence**, identique à
  /// `ZDateFieldWidget.decorated` : `true` ⇒ champ décoré ; `false` ⇒ rendu
  /// plus simple `OutlinedButton` ; `null` (défaut) ⇒ jeton de thème
  /// `ZcrudTheme.dateFieldDecorated`, lui-même à défaut `true`.
  final bool? decorated;

  /// Plage courante typée, ou `null` si la graine n'est pas décodable.
  ///
  /// Ce champ accepte le type que SON sélecteur écrit ([ZDateRange]), mais
  /// aussi la forme **réellement persistée** d'un champ `ZDateRange` : une
  /// **Map** `{start, end}` (le `toMap()` généré émet `ZDateRange.toJson()`).
  /// Un hôte qui sème son formulaire depuis `toMap()` porte donc une Map, et
  /// le champ doit rendre sa **présence** au lieu d'un vide alors que la
  /// valeur serait resoumise intacte.
  ///
  /// Le décodage passe par [ZDateRange.fromJsonSafe], le décodeur **défensif**
  /// déjà utilisé par la voie de persistance : `null` sur TOUTE anomalie,
  /// jamais de throw (invariant AD-10). Aucune seconde convention de
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
    // (jamais un littéral codé en dur — invariant FR-26).
    final placeholder = label(context, 'selectDateRange',
        fallback: label(context, 'selectDate'));
    // Projection calculée UNE FOIS par build (invariant AD-2 : le port de
    // l'hôte n'est pas appelé deux fois pour la même plage — `display` et
    // `valueText` partagent la même chaîne).
    //
    // Hors contrat : une graine non nulle que le décodeur défensif n'a pas su
    // lire retombe sur `'$value'`, le **repli déjà défini par le paquet**
    // (`zDateDisplayTextOf`) — aucune invention de format. La taire
    // produirait un « contrôle qui paraît vide alors que la donnée sera
    // soumise » : la valeur est bien là et sera resoumise. Présence et
    // identité restent dissociées.
    final rangeText = range != null
        ? _formatRange(context, range)
        : value == null
            ? ''
            : '$value';
    final hasValue = rangeText.isNotEmpty;
    final display = hasValue ? rangeText : placeholder;

    // Croix rendue seulement si un callback est fourni (champ non requis
    // + éditable) ET qu'une valeur existe (rien à effacer sinon). C'est bien
    // la PRÉSENCE qui pilote la croix — une graine hors contrat est
    // effaçable, sinon elle serait resoumise sans recours.
    final showClear = onCleared != null && !field.readOnly && hasValue;

    final onTap = field.readOnly ? null : () => _pick(context, range);

    // Champ DÉCORÉ par défaut (même traitement que la famille date sœur :
    // les deux familles partagent le même déclencheur — le corriger d'un
    // seul côté recréerait une incohérence entre elles).
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
  /// `ZDateDisplayFormatter` en mode [ZDateMode.date].
  ///
  /// **Pourquoi `dateRange` est traité ici alors qu'il n'a pas de voie de
  /// lecture séparée** : `dateRange` n'est ni tabulaire (il n'apparaît jamais
  /// dans une `DynamicList`) ni fiche-able (`zReadModeCardable` → `false` :
  /// en lecture c'est CE widget, `readOnly`, qui rend). Sans cette projection,
  /// un formulaire afficherait `Dim. 9 août 2026` pour un `dateTime` et
  /// `2026-08-09 → …` pour la plage juste à côté sous un port injecté — une
  /// incohérence entre deux familles voisines.
  ///
  /// Hôte passif STRICTEMENT immobile (invariant AD-10) : la borne entre dans
  /// la règle partagée **déjà normalisée en `YYYY-MM-DD`** — le repli de
  /// `zDateDisplayTextOf` étant `'$value'`, port absent / port rendant
  /// `null`/vide / port qui lève redonnent **exactement** l'ISO d'avant. (Passer
  /// le `DateTime` nu ferait replier sur `DateTime.toString()`, qui n'est pas
  /// l'ISO.) Aucune **couleur** codée en dur (thème hérité — invariant FR-26).
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
