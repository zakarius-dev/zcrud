/// Compilateur **mémoïsable** `List<ZValidatorSpec> → FormFieldValidator<String>?`
/// (E3-2, AD-2). Projette la donnée déclarative `ZValidatorSpec` (E2-4, pur-
/// données) en un validateur EXÉCUTABLE de champ (`String? Function(String?)`),
/// composé une seule fois via `FormBuilderValidators.compose`.
///
/// origine: la doc de `ZValidatorSpec` renvoie explicitement la composition en
/// `FormBuilderValidators` à E3 (« attachée au `ZFormController`, jamais au
/// schéma statique »). E3-2 est ce lieu.
///
/// INVARIANTS (AD-2, NON-NÉGOCIABLES) :
/// - On tire **UNIQUEMENT** `package:form_builder_validators` (validateurs PURS,
///   `String? Function(String?)`). **JAMAIS** `flutter_form_builder` : son
///   `FormBuilder`/`FormBuilderState` serait un ÉTAT de formulaire global,
///   interdit (« pas de `FormBuilder` global comme source d'état »).
/// - Le résultat est destiné à être **mémoïsé** par l'appelant (`late final`
///   dans le `State` du champ) : compilé une fois, identité stable entre builds,
///   jamais recréé dans `build()`.
/// - Liste **vide** ⇒ `null` (aucune surcharge sur le `TextFormField`).
///
/// FRONTIÈRE — validateurs **inter-champs** (`min`/`max` référençant un autre
/// champ via `refKey`, et `match` = égalité à un autre champ) : ils dépendent de
/// l'ÉTAT RUNTIME d'un AUTRE champ, hors du contrat champ-local d'E3-2. Ils sont
/// **DÉFÉRÉS** à E3-5/E3-6 (closures mémoïsées capturant le `ZFormController`,
/// lisant `valueOf(refKey)` à l'invocation). Ici ils sont **ignorés** (le
/// compilateur ne produit aucun validateur pour eux). Le must-have E3-2 = les
/// validateurs **locaux au champ**.
library;

import 'package:flutter/widgets.dart' show FormFieldValidator;
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../domain/edition/z_validator_spec.dart';

/// Compilateur des `ZValidatorSpec` d'un champ en un `FormFieldValidator`.
///
/// Sans état (méthodes statiques pures) : l'appelant mémoïse le résultat.
abstract final class ZValidatorCompiler {
  /// Compile [specs] en un unique `FormFieldValidator<String>` **mémoïsable**.
  ///
  /// - Retourne `null` si aucun validateur **champ-local** n'est produit (liste
  ///   vide, ou uniquement des validateurs inter-champs déférés) — le
  ///   `TextFormField` n'aura alors AUCUN `validator` (aucune surcharge).
  /// - Un seul validateur ⇒ renvoyé tel quel (évite un `compose` superflu).
  /// - Plusieurs ⇒ combinés via [FormBuilderValidators.compose] (échoue au
  ///   premier validateur non satisfait, ordre des [specs] préservé).
  ///
  /// Chaque `errorText` de [ZValidatorSpec] est propagé comme message ; si
  /// `null`, `form_builder_validators` retombe sur son message localisé
  /// (`FormBuilderLocalizations`).
  static FormFieldValidator<String>? compile(List<ZValidatorSpec> specs) {
    final validators = <FormFieldValidator<String>>[];
    for (final spec in specs) {
      final v = _compileOne(spec);
      if (v != null) validators.add(v);
    }
    if (validators.isEmpty) return null;
    if (validators.length == 1) return validators.first;
    return FormBuilderValidators.compose<String>(validators);
  }

  /// Projette UNE spec en validateur, ou `null` si la famille est **déférée**
  /// (inter-champs) ou incomplète (paramètre requis absent).
  static FormFieldValidator<String>? _compileOne(ZValidatorSpec spec) {
    final e = spec.errorText;
    switch (spec.kind) {
      case ZValidatorKind.required:
        return FormBuilderValidators.required<String>(errorText: e);
      case ZValidatorKind.minLength:
        final n = spec.length;
        return n == null
            ? null
            : FormBuilderValidators.minLength<String>(n, errorText: e);
      case ZValidatorKind.maxLength:
        final n = spec.length;
        return n == null
            ? null
            : FormBuilderValidators.maxLength<String>(n, errorText: e);
      case ZValidatorKind.min:
        // Littérale seulement ; `refKey` (inter-champs) ⇒ déféré E3-5/E3-6.
        final b = spec.bound;
        return b == null
            ? null
            : FormBuilderValidators.min<String>(b, errorText: e);
      case ZValidatorKind.max:
        final b = spec.bound;
        return b == null
            ? null
            : FormBuilderValidators.max<String>(b, errorText: e);
      case ZValidatorKind.equal:
        final v = spec.value;
        return v == null
            ? null
            : FormBuilderValidators.equal<String>(v, errorText: e);
      case ZValidatorKind.notEqual:
        final v = spec.value;
        return v == null
            ? null
            : FormBuilderValidators.notEqual<String>(v, errorText: e);
      case ZValidatorKind.match:
        // `match` = égalité à la valeur d'un AUTRE champ (`refKey`) ⇒ inter-
        // champs, déféré E3-5/E3-6. (Le `pattern` regex, lui, est `pattern`.)
        return null;
      case ZValidatorKind.email:
        return FormBuilderValidators.email(errorText: e);
      case ZValidatorKind.url:
        return FormBuilderValidators.url(errorText: e);
      case ZValidatorKind.ip:
        return FormBuilderValidators.ip(errorText: e);
      case ZValidatorKind.creditCard:
        return FormBuilderValidators.creditCard(errorText: e);
      case ZValidatorKind.phone:
        return FormBuilderValidators.phoneNumber(errorText: e);
      case ZValidatorKind.numeric:
        return FormBuilderValidators.numeric<String>(errorText: e);
      case ZValidatorKind.integer:
        return FormBuilderValidators.integer(errorText: e);
      case ZValidatorKind.dateString:
        return FormBuilderValidators.date(errorText: e);
      case ZValidatorKind.address:
        // M11 (parité DODLP) : **no-op par défaut** (rôle indice de clavier ;
        // aucune surcharge de format). Format vérifié UNIQUEMENT en opt-in
        // (`enforceFormat: true` ⇒ `street`, comportement historique).
        return (spec.enforceFormat ?? false)
            ? FormBuilderValidators.street(errorText: e)
            : null;
      case ZValidatorKind.percentage:
        // M11 (parité DODLP) : **no-op par défaut** (saisie numérique libre).
        // Plage vérifiée UNIQUEMENT en opt-in (`enforceRange: true` ⇒ `between`,
        // défaut 0–100 surchargeable). Non numérique ⇒ invalide (contrat between).
        if (!(spec.enforceRange ?? false)) return null;
        return FormBuilderValidators.between<String>(
          spec.rangeMin ?? 0,
          spec.rangeMax ?? 100,
          errorText: e,
        );
      case ZValidatorKind.password:
        // M10 : politique paramétrable, défaut aligné DODLP (permissif). Un compte
        // à 0 désactive l'exigence correspondante (`PasswordValidator` fbv-11.3).
        // `checkNullOrEmpty: false` (DP-16-M1) : la VACUITÉ ne rend PAS le champ
        // invalide — un password NON requis laissé vide reste valide (parité DODLP
        // « vide + non requis ⇒ null »). La contrainte de présence est portée
        // séparément par `ZValidatorKind.required`, jamais implicitement ici.
        return FormBuilderValidators.password(
          minLength: spec.passwordMinLength ?? 8,
          maxLength: spec.passwordMaxLength ?? 20,
          minUppercaseCount: (spec.requireUppercase ?? true) ? 1 : 0,
          minLowercaseCount: (spec.requireLowercase ?? true) ? 1 : 0,
          minNumberCount: (spec.requireDigit ?? false) ? 1 : 0,
          minSpecialCharCount: (spec.requireSpecial ?? false) ? 1 : 0,
          checkNullOrEmpty: false,
          errorText: e,
        );
      case ZValidatorKind.pattern:
        final p = spec.pattern;
        // `FormBuilderValidators.match` prend un RegExp (correspondance motif).
        return p == null
            ? null
            : FormBuilderValidators.match(RegExp(p), errorText: e);
    }
  }
}
