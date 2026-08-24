/// Validateurs **inter-champs** : `match(refKey)`, `minKey(refKey)`,
/// `maxKey(refKey)`, `requiredIf(condition)` — déférés par [ZValidatorCompiler]
/// car ils dépendent de l'ÉTAT RUNTIME d'un AUTRE champ.
///
/// `ZValidatorCompiler` ne compile que les validateurs **champ-locaux** et
/// renvoie `null` pour les variantes `refKey`. Ce fichier les complète par
/// des **closures mémoïsées capturant le `ZFormController`**, lues à
/// l'invocation via `c.valueOf(refKey)` — jamais recompilées dans `build()`.
///
/// INVARIANTS (invariant AD-2, NON-NÉGOCIABLES) :
/// - Les closures capturent le controller UNE FOIS (identité stable, mémoïsées
///   `late final` dans le `State` du champ) ; elles ne recompilent rien.
/// - La ré-évaluation **en direct** (quand le champ RÉFÉRENCÉ change) passe par
///   un abonnement **CIBLÉ** à `fieldListenable(refKey)` (une tranche précise) —
///   JAMAIS au `notifyListeners()` global (invariant AD-2 préservé). Voir
///   [refKeysOf]/[ZFieldWidget].
/// - Référence **absente / non comparable** ⇒ contrat **non bloquant** : le
///   validateur `min/max` ne rejette PAS sur une référence indéterminée.
///   La comparaison `min/max` est **typée et robuste** : si les
///   deux valeurs sont numériques ⇒ comparaison **numérique** ; sinon si les
///   deux se parsent en `DateTime` (ISO-8601, ou déjà `DateTime`) ⇒ comparaison
///   de **dates** (couvre l'exemple normatif `dateFin.minKey('dateDebut')`,
///   qui rejette une plage inversée) ; sinon (types non comparables) ⇒ **non
///   bloquant** (référence indéterminée), SANS `throw`.
/// - `requiredIf` exige la **présence** quand sa condition tient, et rien du
///   tout quand elle ne tient pas : le vide reste alors accepté, comme pour
///   tout champ qui ne déclare pas `required`. La condition est évaluée par
///   [evaluateZCondition] contre l'état courant du controller capturé
///   (`valueOf`) et sa baseline (`baselineValueOf`).
library;

import 'package:flutter/widgets.dart' show FormFieldValidator;
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../domain/edition/z_condition.dart';
import '../../domain/edition/z_condition_evaluator.dart';
import '../../domain/edition/z_field_config.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/edition/z_validator_spec.dart';
import '../z_form_controller.dart';
import 'z_validator_compiler.dart';

/// Compilateur des validateurs **inter-champs** d'un champ, capturant le
/// [ZFormController] pour lire la valeur des champs référencés à l'invocation.
abstract final class ZCrossFieldValidator {
  /// Compile les seules specs **inter-champs** de [specs] — celles qui
  /// référencent un autre champ (`refKey`) et celles qui portent une condition
  /// (`requiredIf`) — en un unique `FormFieldValidator<String>` **mémoïsable**,
  /// ou `null` si aucune.
  ///
  /// Chaque closure lit l'état du formulaire à l'invocation (jamais capturé en
  /// dur). Le message d'erreur est `spec.errorText` (repli littéral minimal,
  /// ou message localisé de `required` pour `requiredIf`).
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

  /// Validateur **combiné** champ-local **+** inter-champs pour
  /// [field], ou `null` si aucun des deux ne produit de validateur. Utilisé
  /// par le widget de champ ET par la soumission agrégée (source unique).
  static FormFieldValidator<String>? compileField(
    ZFieldSpec field,
    ZFormController c,
  ) {
    final local = ZValidatorCompiler.compile(field.validators);
    final cross = compile(field.validators, c);
    final bounds = _compileNumberBounds(field, c);
    final all = <FormFieldValidator<String>>[?local, ?cross, ?bounds];
    if (all.isEmpty) return null;
    if (all.length == 1) return all.single;
    return (value) {
      for (final v in all) {
        final e = v(value);
        if (e != null) return e;
      }
      return null;
    };
  }

  /// Bornes **dynamiques** de la famille nombre
  /// (`ZNumberConfig.minValueKey`/`maxValueKey`) : même mécanique que les
  /// validateurs `minKey`/`maxKey` — la borne est lue dans la tranche du champ
  /// référencé à l'invocation, comparaison typée et **non bloquante** sur
  /// référence indéterminée. La ré-évaluation en direct passe par
  /// [zNumberBoundKeysOf] + l'abonnement CIBLÉ du dispatcher (invariant AD-2).
  static FormFieldValidator<String>? _compileNumberBounds(
    ZFieldSpec field,
    ZFormController c,
  ) {
    final cfg = field.config;
    if (cfg is! ZNumberConfig) return null;
    final minKey = cfg.minValueKey;
    final maxKey = cfg.maxValueKey;
    if (minKey == null && maxKey == null) return null;
    return (value) {
      if (minKey != null) {
        final cmp = _compare(value, c.valueOf(minKey));
        if (cmp != null && cmp < 0) return 'Valeur trop petite';
      }
      if (maxKey != null) {
        final cmp = _compare(value, c.valueOf(maxKey));
        if (cmp != null && cmp > 0) return 'Valeur trop grande';
      }
      return null;
    };
  }

  /// Ensemble des **champs observés** par les specs inter-champs de [specs] —
  /// alimente l'abonnement CIBLÉ du champ dépendant (`fieldListenable(nom)`),
  /// jamais un abonnement global.
  ///
  /// Réunit les `refKey` (`match`/`minKey`/`maxKey`) et les champs de garde des
  /// conditions de `requiredIf` (les feuilles de source `state`, seules
  /// susceptibles de changer sous une frappe) : sans eux, le message « requis »
  /// n'apparaîtrait ni ne disparaîtrait tant que l'usager n'aurait pas
  /// retouché le champ lui-même.
  static Set<String> refKeysOf(List<ZValidatorSpec> specs) => <String>{
        for (final s in specs)
          if (_isCrossField(s) && s.refKey != null) s.refKey!,
        ...zGuardFieldsOf(<ZCondition?>[
          for (final s in specs)
            if (s.kind == ZValidatorKind.requiredIf) s.condition,
        ]),
      };

  /// Champs référencés par les **bornes dynamiques** d'une config nombre
  /// (`minValueKey`/`maxValueKey`) — alimente l'abonnement CIBLÉ du champ
  /// borné, comme [refKeysOf] pour les validateurs inter-champs.
  static Set<String> zNumberBoundKeysOf(ZFieldSpec field) {
    final cfg = field.config;
    if (cfg is! ZNumberConfig) return const <String>{};
    return <String>{
      if (cfg.minValueKey != null) cfg.minValueKey!,
      if (cfg.maxValueKey != null) cfg.maxValueKey!,
    };
  }

  static bool _isCrossField(ZValidatorSpec s) =>
      s.refKey != null &&
      (s.kind == ZValidatorKind.match ||
          s.kind == ZValidatorKind.min ||
          s.kind == ZValidatorKind.max);

  static FormFieldValidator<String>? _compileOne(
    ZValidatorSpec spec,
    ZFormController c,
  ) {
    // Présence exigée SOUS CONDITION : la condition est lue à l'invocation,
    // contre l'état courant du controller capturé — jamais figée à la
    // compilation. Condition satisfaite ⇒ exactement `required` (même règle de
    // vacuité, même message localisé) ; sinon ⇒ aucun verrou, le vide passe.
    if (spec.kind == ZValidatorKind.requiredIf) {
      final condition = spec.condition;
      // Spec incomplète (non atteignable par le constructeur public) ⇒ inerte.
      if (condition == null) return null;
      final required =
          FormBuilderValidators.required<String>(errorText: spec.errorText);
      return (value) => evaluateZCondition(
            condition,
            c.valueOf,
            persistedValueOf: c.baselineValueOf,
          )
              ? required(value)
              : null;
    }
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
        // Comparaison typée & robuste : num OU DateTime ISO.
        final cmp = _compare(value, c.valueOf(refKey));
        // Référence indéterminée / types non comparables ⇒ non bloquant.
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
  /// référencé [refRaw] de façon **typée et robuste** :
  /// 1. si les DEUX sont numériques (`num`/`num.tryParse`) ⇒ comparaison
  ///    numérique ;
  /// 2. sinon si les DEUX se parsent en `DateTime` (déjà `DateTime`, ou chaîne
  ///    ISO-8601 via `DateTime.tryParse`) ⇒ comparaison de dates (couvre
  ///    `dateFin.minKey('dateDebut')`) ;
  /// 3. sinon (types non comparables / référence indéterminée) ⇒ `null`
  ///    (**non bloquant**) — jamais de `throw`.
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
