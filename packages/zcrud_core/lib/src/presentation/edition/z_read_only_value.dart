/// Formatage **défensif** de valeur + politique de familles « fiche-ables » pour
/// le **mode lecture** (DP-13, M4). Helpers `src`-privés à l'API (non exportés) :
/// consommés par `ZFieldWidget` (dispatch `readMode`) et `ZReadOnlyFieldCard`.
///
/// AD-10 : [zReadOnlyValueOf] est **pur** (aucune tranche, aucun état) et **ne
/// lève jamais** — toute valeur inconnue/corrompue retombe sur une représentation
/// textuelle sûre ou un placeholder. AD-2 : aucune allocation de contrôleur.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/edition_field_type.dart';
import '../../domain/edition/z_field_config.dart';
import '../../domain/edition/z_field_spec.dart';
import '../l10n/z_localizations.dart';
import 'edition_field_family.dart';

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
bool _isEmpty(Object? v) {
  if (v == null) return true;
  if (v is String) return v.isEmpty;
  if (v is Iterable) return v.isEmpty;
  if (v is Map) return v.isEmpty;
  return false;
}

/// Longueur maximale d'une représentation `Map`/objet complexe (borne AD-10 :
/// jamais un dump illisible non borné).
const int _maxComplexLen = 200;

/// Formate [value] pour le [field] en mode lecture (AD-10, jamais de throw).
ReadOnlyValue zReadOnlyValueOf(
  BuildContext context,
  ZFieldSpec field,
  Object? value,
) {
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
      return ReadOnlyValue.text(_choiceLabels(context, field, value));

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

/// Libellé(s) résolus depuis `field.choices` ; valeur inconnue → représentation
/// brute ; liste/`multiple` → libellés joints « , ».
String _choiceLabels(BuildContext context, ZFieldSpec field, Object? value) {
  String labelOf(Object? v) {
    for (final c in field.choices) {
      if (c.value == v) return label(context, c.label, fallback: c.label);
    }
    return '$v';
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
ReadOnlyValue _colorValue(Object? value) {
  if (value is! int) return ReadOnlyValue.text('$value');
  final hex =
      '#${value.toRadixString(16).toUpperCase().padLeft(8, '0')}';
  return ReadOnlyValue.widget(
    Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            // Couleur issue de la DONNÉE (ARGB), non un style codé en dur (FR-26).
            color: Color(value),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ),
        const SizedBox(width: 8),
        Text(hex, textAlign: TextAlign.start),
      ],
    ),
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
