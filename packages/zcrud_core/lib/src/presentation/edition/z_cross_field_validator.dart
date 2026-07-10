/// Validateurs **inter-champs** (E3-6, report b) : `match(refKey)`,
/// `minKey(refKey)`, `maxKey(refKey)` — déférés par [ZValidatorCompiler] (E3-2)
/// car ils dépendent de l'ÉTAT RUNTIME d'un AUTRE champ.
///
/// origine: `ZValidatorCompiler` (E3-2) ne compile que les validateurs
/// **champ-locaux** et renvoie `null` pour les variantes `refKey` (frontière
/// documentée l.20-26, 78-102). E3-6 les complète ICI par des **closures
/// mémoïsées capturant le `ZFormController`**, lues à l'invocation via
/// `c.valueOf(refKey)` — jamais recompilées dans `build()`.
///
/// INVARIANTS (AD-2, NON-NÉGOCIABLES) :
/// - Les closures capturent le controller UNE FOIS (identité stable, mémoïsées
///   `late final` dans le `State` du champ) ; elles ne recompilent rien.
/// - La ré-évaluation **en direct** (quand le champ RÉFÉRENCÉ change) passe par
///   un abonnement **CIBLÉ** à `fieldListenable(refKey)` (une tranche précise) —
///   JAMAIS au `notifyListeners()` global (SM-1 préservé). Voir
///   [refKeysOf]/[ZFieldWidget].
/// - Référence **absente / non comparable** ⇒ contrat **non bloquant** : le
///   validateur `min/max` ne rejette PAS sur une référence indéterminée (AC11).
///   La comparaison `min/max` est **typée et robuste** (E3-6 MEDIUM-1) : si les
///   deux valeurs sont numériques ⇒ comparaison **numérique** ; sinon si les
///   deux se parsent en `DateTime` (ISO-8601, ou déjà `DateTime`) ⇒ comparaison
///   de **dates** (honore l'exemple normatif AC11 `dateFin.minKey('dateDebut')`,
///   qui rejette une plage inversée) ; sinon (types non comparables) ⇒ **non
///   bloquant** (référence indéterminée, cohérent avec l'ambiguïté #5), SANS
///   `throw`.
library;

import 'package:flutter/widgets.dart' show FormFieldValidator;

import '../../domain/edition/z_field_spec.dart';
import '../../domain/edition/z_validator_spec.dart';
import '../z_form_controller.dart';
import 'z_validator_compiler.dart';

/// Compilateur des validateurs **inter-champs** d'un champ, capturant le
/// [ZFormController] pour lire la valeur des champs référencés à l'invocation.
abstract final class ZCrossFieldValidator {
  /// Compile les seules specs **inter-champs** (`refKey != null`) de [specs] en
  /// un unique `FormFieldValidator<String>` **mémoïsable**, ou `null` si aucune.
  ///
  /// Chaque closure lit `c.valueOf(refKey)` à l'invocation (jamais capturée en
  /// dur). Le message d'erreur est `spec.errorText` (repli littéral minimal).
  static FormFieldValidator<String>? compile(
    List<ZValidatorSpec> specs,
    ZFormController c,
  ) {
    final validators = <FormFieldValidator<String>>[];
    for (final spec in specs) {
      final v = _compileOne(spec, c);
      if (v != null) validators.add(v);
    }
    if (validators.isEmpty) return null;
    if (validators.length == 1) return validators.first;
    return (value) {
      for (final v in validators) {
        final e = v(value);
        if (e != null) return e;
      }
      return null;
    };
  }

  /// Validateur **combiné** champ-local (E3-2) **+** inter-champs (E3-6) pour
  /// [field], ou `null` si aucun des deux ne produit de validateur. Utilisé
  /// par le widget de champ ET par la soumission agrégée (source unique).
  static FormFieldValidator<String>? compileField(
    ZFieldSpec field,
    ZFormController c,
  ) {
    final local = ZValidatorCompiler.compile(field.validators);
    final cross = compile(field.validators, c);
    if (local == null) return cross;
    if (cross == null) return local;
    return (value) => local(value) ?? cross(value);
  }

  /// Ensemble des `refKey` référencés par les specs inter-champs de [specs] —
  /// alimente l'abonnement CIBLÉ du champ dépendant (`fieldListenable(refKey)`,
  /// AC12), jamais un abonnement global.
  static Set<String> refKeysOf(List<ZValidatorSpec> specs) => <String>{
        for (final s in specs)
          if (_isCrossField(s) && s.refKey != null) s.refKey!,
      };

  static bool _isCrossField(ZValidatorSpec s) =>
      s.refKey != null &&
      (s.kind == ZValidatorKind.match ||
          s.kind == ZValidatorKind.min ||
          s.kind == ZValidatorKind.max);

  static FormFieldValidator<String>? _compileOne(
    ZValidatorSpec spec,
    ZFormController c,
  ) {
    final refKey = spec.refKey;
    if (refKey == null) return null; // littéral → géré par ZValidatorCompiler.
    final message = spec.errorText;
    // Égalité (textuelle) à la valeur du champ référencé (ex. confirm mdp).
    if (spec.kind == ZValidatorKind.match) {
      return (value) {
        final ref = _stringOf(c.valueOf(refKey));
        final self = value ?? '';
        return self == ref
            ? null
            : (message ?? 'Les valeurs ne correspondent pas');
      };
    }
    if (spec.kind == ZValidatorKind.min) {
      return (value) {
        // Comparaison typée & robuste (MEDIUM-1) : num OU DateTime ISO.
        final cmp = _compare(value, c.valueOf(refKey));
        // Référence indéterminée / types non comparables ⇒ non bloquant (AC11).
        if (cmp == null) return null;
        return cmp >= 0 ? null : (message ?? 'Valeur trop petite');
      };
    }
    if (spec.kind == ZValidatorKind.max) {
      return (value) {
        final cmp = _compare(value, c.valueOf(refKey));
        if (cmp == null) return null;
        return cmp <= 0 ? null : (message ?? 'Valeur trop grande');
      };
    }
    // Toutes les autres familles sont champ-locales (ZValidatorCompiler).
    return null;
  }

  /// Compare la valeur courante [selfRaw] (texte du champ) à la valeur du champ
  /// référencé [refRaw] de façon **typée et robuste** (E3-6 MEDIUM-1) :
  /// 1. si les DEUX sont numériques (`num`/`num.tryParse`) ⇒ comparaison
  ///    numérique ;
  /// 2. sinon si les DEUX se parsent en `DateTime` (déjà `DateTime`, ou chaîne
  ///    ISO-8601 via `DateTime.tryParse`) ⇒ comparaison de dates (honore
  ///    `dateFin.minKey('dateDebut')`, AC11) ;
  /// 3. sinon (types non comparables / référence indéterminée) ⇒ `null`
  ///    (**non bloquant**, cohérent avec l'ambiguïté #5) — jamais de `throw`.
  ///
  /// Retourne le signe de `self - ref` (`<0`, `0`, `>0`) ou `null` si non
  /// comparable. La priorité numérique évite qu'un entier ISO-ambigu bascule en
  /// date.
  static int? _compare(Object? selfRaw, Object? refRaw) {
    final selfNum = _asNum(selfRaw);
    final refNum = _asNum(refRaw);
    if (selfNum != null && refNum != null) return selfNum.compareTo(refNum);
    final selfDate = _asDate(selfRaw);
    final refDate = _asDate(refRaw);
    if (selfDate != null && refDate != null) {
      return selfDate.compareTo(refDate);
    }
    return null; // non comparable ⇒ non bloquant.
  }

  static num? _asNum(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return null;
  }

  static DateTime? _asDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }

  static String _stringOf(Object? value) => value == null ? '' : '$value';
}
