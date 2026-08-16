/// Compilateur **mémoïsable** `List<ZValidatorSpec> → FormFieldValidator<String>?`
/// (invariant AD-2). Projette la donnée déclarative `ZValidatorSpec` (pur-
/// données) en un validateur EXÉCUTABLE de champ (`String? Function(String?)`),
/// composé une seule fois via `FormBuilderValidators.compose`.
///
/// La composition en `FormBuilderValidators` est attachée au
/// `ZFormController`, jamais au schéma statique — ce fichier est ce lieu.
///
/// INVARIANTS (invariant AD-2, NON-NÉGOCIABLES) :
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
/// l'ÉTAT RUNTIME d'un AUTRE champ, hors du contrat champ-local de ce
/// compilateur. Ils sont **DÉFÉRÉS** au niveau formulaire (closures mémoïsées
/// capturant le `ZFormController`, lisant `valueOf(refKey)` à l'invocation).
/// Ici ils sont **ignorés** (le compilateur ne produit aucun validateur pour
/// eux). Ce fichier ne couvre que les validateurs **locaux au champ**.
///
/// FRONTIÈRE — **forme** et **présence** sont deux exigences distinctes. Un
/// validateur de forme (motif, e-mail, longueur, borne, égalité…) décrit ce à
/// quoi une valeur doit ressembler **quand il y en a une** ; il n'exige jamais
/// qu'il y en ait une. L'exigence de présence est portée par un seul
/// validateur — `ZValidatorKind.required` — et un champ qui la veut le déclare.
/// C'est ce qui rend exprimable la forme la plus courante d'un champ de
/// contact : *facultatif, mais valide s'il est rempli*.
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
  ///
  /// Toutes les familles de **forme** sont compilées avec
  /// `checkNullOrEmpty: false` : une saisie vide les traverse sans erreur, la
  /// présence n'étant exigée que par [ZValidatorKind.required] (voir la
  /// frontière *forme / présence* en tête de fichier).
  static FormFieldValidator<String>? _compileOne(ZValidatorSpec spec) {
    final e = spec.errorText;
    switch (spec.kind) {
      case ZValidatorKind.required:
        // SEULE famille qui porte la présence : ici, et seulement ici, une
        // valeur vide ou absente est une erreur.
        return FormBuilderValidators.required<String>(errorText: e);
      case ZValidatorKind.minLength:
        final n = spec.length;
        return n == null
            ? null
            : FormBuilderValidators.minLength<String>(
                n,
                checkNullOrEmpty: false,
                errorText: e,
              );
      case ZValidatorKind.maxLength:
        final n = spec.length;
        return n == null
            ? null
            : FormBuilderValidators.maxLength<String>(
                n,
                checkNullOrEmpty: false,
                errorText: e,
              );
      case ZValidatorKind.min:
        // Littérale seulement ; `refKey` (inter-champs) ⇒ déféré au niveau
        // formulaire.
        final b = spec.bound;
        return b == null
            ? null
            : FormBuilderValidators.min<String>(
                b,
                checkNullOrEmpty: false,
                errorText: e,
              );
      case ZValidatorKind.max:
        final b = spec.bound;
        return b == null
            ? null
            : FormBuilderValidators.max<String>(
                b,
                checkNullOrEmpty: false,
                errorText: e,
              );
      case ZValidatorKind.equal:
        final v = spec.value;
        return v == null
            ? null
            : FormBuilderValidators.equal<String>(
                v,
                checkNullOrEmpty: false,
                errorText: e,
              );
      case ZValidatorKind.notEqual:
        final v = spec.value;
        return v == null
            ? null
            : FormBuilderValidators.notEqual<String>(
                v,
                checkNullOrEmpty: false,
                errorText: e,
              );
      case ZValidatorKind.match:
        // `match` = égalité à la valeur d'un AUTRE champ (`refKey`) ⇒ inter-
        // champs, déféré au niveau formulaire. (Le `pattern` regex, lui, est
        // `pattern`.)
        return null;
      case ZValidatorKind.email:
        return FormBuilderValidators.email(checkNullOrEmpty: false, errorText: e);
      case ZValidatorKind.url:
        return FormBuilderValidators.url(checkNullOrEmpty: false, errorText: e);
      case ZValidatorKind.ip:
        return FormBuilderValidators.ip(checkNullOrEmpty: false, errorText: e);
      case ZValidatorKind.creditCard:
        return FormBuilderValidators.creditCard(
          checkNullOrEmpty: false,
          errorText: e,
        );
      case ZValidatorKind.phone:
        return FormBuilderValidators.phoneNumber(
          checkNullOrEmpty: false,
          errorText: e,
        );
      case ZValidatorKind.numeric:
        return FormBuilderValidators.numeric<String>(
          checkNullOrEmpty: false,
          errorText: e,
        );
      case ZValidatorKind.integer:
        return FormBuilderValidators.integer(
          checkNullOrEmpty: false,
          errorText: e,
        );
      case ZValidatorKind.dateString:
        return FormBuilderValidators.date(checkNullOrEmpty: false, errorText: e);
      case ZValidatorKind.address:
        // **no-op par défaut** (rôle indice de clavier ; aucune surcharge de
        // format). Format vérifié UNIQUEMENT en opt-in (`enforceFormat: true`
        // ⇒ `street`, comportement historique).
        return (spec.enforceFormat ?? false)
            ? FormBuilderValidators.street(
                checkNullOrEmpty: false,
                errorText: e,
              )
            : null;
      case ZValidatorKind.percentage:
        // **no-op par défaut** (saisie numérique libre). Plage vérifiée
        // UNIQUEMENT en opt-in (`enforceRange: true` ⇒ `between`, défaut
        // 0–100 surchargeable). Non numérique ⇒ invalide (contrat between).
        if (!(spec.enforceRange ?? false)) return null;
        return FormBuilderValidators.between<String>(
          spec.rangeMin ?? 0,
          spec.rangeMax ?? 100,
          checkNullOrEmpty: false,
          errorText: e,
        );
      case ZValidatorKind.password:
        // Politique paramétrable, défaut permissif. Un compte à 0 désactive
        // l'exigence correspondante (`PasswordValidator` fbv-11.3).
        // `checkNullOrEmpty: false` : la VACUITÉ ne rend PAS le champ
        // invalide — un password NON requis laissé vide reste valide
        // (« vide + non requis ⇒ null »). La contrainte de présence est
        // portée séparément par `ZValidatorKind.required`, jamais
        // implicitement ici.
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
        // `checkNullOrEmpty: false` : un motif décrit la FORME d'une valeur,
        // jamais son existence — un champ de contact facultatif reste
        // soumissible à vide, et garde son verrou dès qu'il est rempli.
        return p == null
            ? null
            : FormBuilderValidators.match(
                RegExp(p),
                checkNullOrEmpty: false,
                errorText: e,
              );
    }
  }
}
