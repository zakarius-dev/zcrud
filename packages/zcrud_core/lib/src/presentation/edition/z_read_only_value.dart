/// Formatage **défensif** de valeur + politique de familles « fiche-ables » pour
/// le **mode lecture** (DP-13, M4). Helpers `src`-privés à l'API (non exportés) :
/// consommés par `ZFieldWidget` (dispatch `readMode`) et `ZReadOnlyFieldCard`.
///
/// AD-10 : [zReadOnlyValueOf] ne lit **aucune tranche de formulaire**, ne porte
/// **aucun état** et **ne lève jamais** — toute valeur inconnue/corrompue
/// retombe sur une représentation textuelle sûre ou un placeholder. AD-2 :
/// aucune allocation de contrôleur, aucun objet coûteux construit par appel.
///
/// ⚠️ La fonction n'est PAS *pure* au sens Flutter : elle lit deux seams du
/// `ZcrudScope` (l10n via `label`, et le port de dates
/// `ZcrudScope.dateDisplayFormatter`). Sans port injecté, la voie date rend la
/// **chaîne brute** — l'affichage d'un hôte passif est strictement inchangé.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/edition_field_type.dart';
import '../../domain/edition/z_field_choice.dart';
import '../../domain/edition/z_field_config.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/ports/z_date_display_formatter.dart';
import '../l10n/z_localizations.dart';
import '../zcrud_scope.dart';
import 'edition_field_family.dart';
import 'z_orphan_choice.dart';
import 'z_value_emptiness.dart';

/// Résultat de formatage d'une valeur en mode lecture : soit un **texte**
/// (copiable), soit un **placeholder** non copiable (« — »), soit un **Widget**
/// non copiable (parité DODLP `value is Widget → onLongPress no-op`).
@immutable
class ReadOnlyValue {
  const ReadOnlyValue._({this.text, this.widget, required this.copyable});

  /// Valeur **textuelle** copiable.
  const ReadOnlyValue.text(String text)
      : this._(text: text, widget: null, copyable: true);

  /// **Placeholder** non copiable (valeur vide « — » ou masquée « •••• »).
  const ReadOnlyValue.placeholder(String text)
      : this._(text: text, widget: null, copyable: false);

  /// **Widget** de valeur non copiable (ex. pastille couleur — DODLP passe-plat).
  const ReadOnlyValue.widget(Widget widget)
      : this._(text: null, widget: widget, copyable: false);

  /// Représentation textuelle (`null` si [widget] est fourni).
  final String? text;

  /// Widget de valeur (`null` si [text] est fourni).
  final Widget? widget;

  /// `true` si [text] est copiable dans le presse-papier (texte non vide, non
  /// placeholder, non masqué).
  final bool copyable;
}

/// `true` si une valeur compte comme **vide** (miroir de
/// `DynamicEdition._isEmptyValue`) : `null` / chaîne / collection / map vide.
/// `false`/`0` NE sont PAS vides.
bool _isEmpty(Object? v) => zIsEmptyValue(v);

/// Longueur maximale d'une représentation `Map`/objet complexe (borne AD-10 :
/// jamais un dump illisible non borné).
const int _maxComplexLen = 200;

/// Formate [value] pour le [field] en mode lecture (AD-10, jamais de throw).
///
/// [choices] **surcharge** `field.choices` pour la résolution des libellés des
/// familles à choix. C'est le canal par lequel un appelant qui a déjà résolu les
/// options **effectives** (source dynamique `ZChoicesSource`, `choicesFromKey`,
/// options dérivées) évite qu'une valeur légitime soit vue comme orpheline.
/// `null` (défaut) ⇒ `field.choices` — comportement d'origine inchangé.
ReadOnlyValue zReadOnlyValueOf(
  BuildContext context,
  ZFieldSpec field,
  Object? value, {
  List<ZFieldChoice>? choices,
}) {
  String emptyPlaceholder() => label(context, 'emptyValue', fallback: '—');

  // `password` : jamais la valeur en clair (masquée si présente, « — » sinon).
  if (field.type == EditionFieldType.password) {
    final empty = value == null || (value is String && value.isEmpty);
    return ReadOnlyValue.placeholder(empty ? emptyPlaceholder() : '••••');
  }

  if (_isEmpty(value)) return ReadOnlyValue.placeholder(emptyPlaceholder());

  switch (field.type) {
    case EditionFieldType.boolean:
      final b = value == true;
      return ReadOnlyValue.text(
        label(context, b ? 'yes' : 'no', fallback: b ? 'Oui' : 'Non'),
      );

    case EditionFieldType.select:
    case EditionFieldType.radio:
    case EditionFieldType.checkbox:
    case EditionFieldType.relation:
    case EditionFieldType.rowChips:
      return ReadOnlyValue.text(
        _choiceLabels(context, choices ?? field.choices, value),
      );

    case EditionFieldType.dateTime:
    case EditionFieldType.time:
      // CR-DODLP-GAP3BIS : projection d'AFFICHAGE d'une date via le port neutre
      // `ZDateDisplayFormatter`. Port absent / valeur non parsable / port en
      // erreur ⇒ chaîne BRUTE, soit exactement le rendu d'avant (AD-10).
      return ReadOnlyValue.text(zDateDisplayText(context, field, value));

    case EditionFieldType.number:
    case EditionFieldType.integer:
    case EditionFieldType.float:
      // DP-17 (M17) : formatage LECTURE devise/pourcentage NEUTRE (donnée, jamais
      // un style FR-26). Sans config ⇒ représentation brute (rétro-compat).
      return ReadOnlyValue.text(_numberText(context, field, value));

    case EditionFieldType.color:
      // Pastille + code (parité DODLP `value is Widget` → copie désactivée).
      return _colorValue(value);

    case EditionFieldType.tags:
      return ReadOnlyValue.text(_joinList(value));

    // ignore: no_default_cases
    default:
      if (value is Iterable) return ReadOnlyValue.text(_joinList(value));
      if (value is Map) return ReadOnlyValue.text(_safeMap(value));
      return ReadOnlyValue.text('$value');
  }
}

/// DP-17 (M17) : rend un nombre en lecture avec suffixe/préfixe NEUTRE selon
/// `ZNumberConfig` (défensif AD-10 : config absente ⇒ `'$value'`). Pourcentage →
/// `« 42 % »` ; devise → `« 42 $ »` (symbole config/`currencySuffix`, jamais
/// codé en dur — FR-26/AD-1).
String _numberText(BuildContext context, ZFieldSpec field, Object? value) {
  final cfg = field.config;
  if (cfg is! ZNumberConfig) return '$value';
  if (cfg.isPercentage) {
    return '$value ${label(context, 'percentSuffix', fallback: '%')}';
  }
  if (cfg.isCurrency) {
    final symbol =
        cfg.currencySymbol ?? label(context, 'currencySuffix', fallback: r'$');
    return '$value $symbol';
  }
  return '$value';
}

/// Texte d'affichage d'une valeur de date (CR-DODLP-GAP3BIS).
///
/// **Repli DÉFINI (AD-10) = la chaîne brute**, dans TOUS les chemins dégradés :
/// port absent, valeur non parsable en `DateTime` (dont le mode `time`, stocké
/// `HH:mm`), port retournant `null`/vide, port qui lève. ⇒ un hôte qui n'injecte
/// rien voit **exactement** l'affichage d'avant ce port.
///
/// AD-2 : aucune allocation coûteuse — un `DateTime.tryParse` et un appel de
/// port ; l'instance du formateur appartient à l'hôte (jamais construite ici).
/// CR-LIST-LABELS : le corps de la règle (repli AD-10 compris) vit désormais
/// dans `zDateDisplayTextOf` (pur-Dart, port de dates). Cette fonction ne fait
/// plus que **lire les seams du scope** ; la voie sans `BuildContext`
/// (`ZListColumn.format`) consomme la MÊME règle avec un port déjà capturé.
String zDateDisplayText(BuildContext context, ZFieldSpec field, Object? value) =>
    zDateDisplayTextOf(
      ZcrudScope.maybeOf(context)?.dateDisplayFormatter,
      value,
      mode: zDateModeOf(
        field.config,
        isTimeType: field.type == EditionFieldType.time,
      ),
      localeTag: _localeTag(context),
    );

/// BCP-47 de la locale ambiante, ou `null` si l'arbre n'en porte pas
/// (`maybeLocaleOf` — jamais `localeOf`, qui lève sans `Localizations`).
String? _localeTag(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.toLanguageTag();

/// Libellé(s) résolus depuis [choices] ; valeur **orpheline** (absente des
/// options) → libellé l10n d'indisponibilité, **jamais la clé technique**
/// (CR-ORPHAN) ; liste/`multiple` → libellés joints « , ».
///
/// 🔴 La fiche de lecture (`ZReadOnlyFieldCard`) ne passe que les choix
/// **statiques** de la spec : une valeur alimentée par une source dynamique y
/// est donc structurellement orpheline. (Le résumé de sous-liste compact, lui,
/// passe les choix **effectifs** résolus par `zResolveSelectChoices` — voir le
/// paramètre `choices` de [zReadOnlyValueOf].)
/// Elle rendait auparavant son **identifiant brut** — c'est le défaut
/// que ce paquet proscrit ailleurs (`fileRefUnresolved`). Elle rend désormais le
/// même libellé que les huit voies d'édition. La valeur n'est pas altérée : le
/// mode lecture n'écrit rien.
String _choiceLabels(
  BuildContext context,
  List<ZFieldChoice> choices,
  Object? value,
) {
  String labelOf(Object? v) {
    for (final c in choices) {
      if (c.value == v) return label(context, c.label, fallback: c.label);
    }
    return zOrphanChoiceLabel(context);
  }

  if (value is Iterable) {
    return value.map(labelOf).join(', ');
  }
  return labelOf(value);
}

/// Éléments d'une collection joints « , » (représentation sûre).
String _joinList(Object? value) {
  if (value is Iterable) return value.map((e) => '$e').join(', ');
  return '$value';
}

/// Représentation textuelle **bornée** d'une `Map`/objet complexe (AD-10).
String _safeMap(Map<dynamic, dynamic> value) {
  final s = value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  if (s.length <= _maxComplexLen) return s;
  return '${s.substring(0, _maxComplexLen)}…';
}

/// Fiche couleur : pastille (couleur = **donnée** ARGB, pas un style codé en dur)
/// + code hexadécimal. Copie désactivée (Widget passe-plat — parité DODLP).
///
/// FP-4.4 : une valeur `List` (mode `ZColorConfig.multiple`) rend **N pastilles**
/// (parse défensif AD-10 : seules les entrées `int` sont pastillées) ; le rendu
/// simple `int` reste inchangé (rétro-compat).
ReadOnlyValue _colorValue(Object? value) {
  if (value is List) {
    final argbs = <int>[for (final e in value) if (e is int) e];
    if (argbs.isEmpty) return ReadOnlyValue.text('$value');
    return ReadOnlyValue.widget(
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[for (final argb in argbs) _colorChip(argb)],
      ),
    );
  }
  if (value is! int) return ReadOnlyValue.text('$value');
  return ReadOnlyValue.widget(_colorChip(value, withHex: true));
}

/// Pastille couleur (donnée ARGB — FR-26) + code hex optionnel. Directionnel.
Widget _colorChip(int argb, {bool withHex = false}) {
  final hex = '#${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          // Couleur issue de la DONNÉE (ARGB), non un style codé en dur (FR-26).
          color: Color(argb),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
      if (withHex) ...<Widget>[
        const SizedBox(width: 8),
        Text(hex, textAlign: TextAlign.start),
      ],
    ],
  );
}

/// **Politique** de familles fiche-ables en mode lecture (DP-13, AC6).
///
/// Fiche-ables (rendues via `ZReadOnlyFieldCard`) : `text`, `number`, `date`,
/// `boolean`, `select`, `relation`, `tags`, `rowChips`, `rating`, `slider`,
/// `color`. NON fiche-ables (conservent leur rendu `readOnly` existant, jamais
/// régressé) : `subList`, `dynamicItem`, `signature`, `file`, `freeWidget`,
/// `registryOrFallback`, `hidden`, `unsupported` (un reader dédié relève de leurs
/// stories). Référence DODLP `readOnlyWidget` (`edition_screen.dart:974-1040`).
bool zReadModeCardable(EditionFamily family) {
  switch (family) {
    case EditionFamily.text:
    case EditionFamily.number:
    case EditionFamily.date:
    case EditionFamily.boolean:
    case EditionFamily.select:
    case EditionFamily.relation:
    case EditionFamily.tags:
    case EditionFamily.rowChips:
    case EditionFamily.rating:
    case EditionFamily.slider:
    case EditionFamily.color:
      return true;
    case EditionFamily.dateRange:
    // `dateRange` (AD-47) : NON fiche-able ici — en mode lecture, le widget natif
    // rend son déclencheur `readOnly` (plage affichée, désactivée). Un reader
    // dédié relèvera d'une story ultérieure (patron des familles récentes).
    case EditionFamily.subList:
    case EditionFamily.dynamicItem:
    case EditionFamily.signature:
    case EditionFamily.file:
    case EditionFamily.freeWidget:
    case EditionFamily.registryOrFallback:
    case EditionFamily.hidden:
    case EditionFamily.unsupported:
      return false;
  }
}
