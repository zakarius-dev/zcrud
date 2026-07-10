/// Widget de la **famille nombre** (E3-3a) : `number` / `integer` / `float`.
///
/// `TextFormField` numérique autonome (aucun `Form` global — AD-2) sur un
/// `TextEditingController`/`FocusNode` **stables** détenus par l'hôte
/// (`ZFieldWidget`) — STATELESS, comme la famille texte (stabilité E3-2 non
/// dupliquée). Le clavier numérique (`keyboardType`) oriente la saisie ;
/// l'`onChanged` remonte une **valeur TYPÉE** (`int`/`num`, `null` si vide/
/// incomplet/non numérique) — décision story #5 (« valeur typée en tranche ») :
/// une saisie non numérique n'atteint donc jamais la tranche (elle y écrit
/// `null`), et le validateur numérique mémoïsé la signale.
///
/// RELÂCHEMENT L-2 (E3-3b-1, code-review E3-3a §3) : `inputFormatters`/
/// `FilteringTextInputFormatter` (transformateurs **purs, sans état** — vivant
/// dans `package:flutter/services.dart`) sont désormais autorisés sous
/// `presentation/` via une clause `show` **restreinte** (garde de pureté
/// relâchée par symbole ; `services.dart` nu/hors-allowlist reste banni). Ils
/// **filtrent la saisie non numérique** au clavier (plus de caractère non
/// numérique transitoire), EN PLUS du parsing typé défensif (`tryParse → null`)
/// et du validateur mémoïsé — jamais en remplacement.
///
/// a11y/RTL (AD-13) : `labelText` sémantique ; aucune couleur/inset non
/// directionnel en dur (FR-26). Validateur mémoïsé réutilisé (E3-2, AC11).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;

import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition **numérique** (générique / entier / décimal).
class ZNumberFieldWidget extends StatelessWidget {
  /// Construit le champ numérique lié au [controller]/[focusNode] **stables**.
  const ZNumberFieldWidget({
    required this.field,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// `TextEditingController` **stable** (détenu par l'hôte).
  final TextEditingController controller;

  /// `FocusNode` **stable** (détenu par l'hôte).
  final FocusNode focusNode;

  /// Validateur **mémoïsé** (identité stable ; `null` si aucun).
  final FormFieldValidator<String>? validator;

  /// Notifié avec la valeur **typée** parsée (`int`/`num`/`null`).
  final ValueChanged<Object?> onChanged;

  /// Mode d'autovalidation (E3-5, additif ; défaut `onUserInteraction`). Le
  /// stepper le bascule en `always` pour révéler les erreurs d'étape (AD-2, sans
  /// `Form` global).
  final AutovalidateMode autovalidateMode;

  bool get _isInteger => field.type == EditionFieldType.integer;

  /// Formatters PURS filtrant la saisie non numérique (L-2) : entiers →
  /// chiffres seuls ; décimaux → chiffres + `.` + signe `-`.
  List<TextInputFormatter> get _formatters => _isInteger
      ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
      : <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
        ];

  @override
  Widget build(BuildContext context) {
    final resolvedLabel =
        label(context, field.label ?? field.name, fallback: field.label ?? field.name);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: field.readOnly,
      keyboardType: _isInteger
          ? const TextInputType.numberWithOptions(signed: true)
          : const TextInputType.numberWithOptions(signed: true, decimal: true),
      inputFormatters: _formatters,
      autovalidateMode: autovalidateMode,
      validator: validator,
      decoration: InputDecoration(labelText: resolvedLabel),
      onChanged: (raw) => onChanged(_parse(raw)),
    );
  }

  /// Projette la saisie brute en valeur **typée** (`int`/`num`), `null` si vide
  /// ou incomplète (p. ex. `"3."`) — pas de throw, la tranche reçoit `null`.
  Object? _parse(String raw) {
    if (raw.isEmpty) return null;
    return _isInteger ? int.tryParse(raw) : num.tryParse(raw);
  }
}
