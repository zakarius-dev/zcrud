/// Soumission agrégée d'un formulaire d'édition + états UI accessibles (E3-6,
/// AD-11 / AD-2 / AD-15).
///
/// origine: E3 se ferme par une **voie de soumission** create/update robuste.
/// [ZEditionSubmitController] valide TOUS les champs visibles (plat + toutes les
/// étapes d'un stepper, conditionnels honorés), puis délègue à un **seam**
/// applicatif `onSubmit` retournant `Future<Either<ZFailure, T>>` (AD-11) — le
/// hook et les valeurs sont détenus **hors** du `ZFormController` (jamais dans
/// une tranche, jamais traversés par le codegen — AC3/AD-3).
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **AD-11** : `onSubmit` retourne `Either<ZFailure, T>`. Le cœur s'arrête à
///   [ZSubmissionState.failure] ; **aucun `AsyncValue`** ici. Le pont
///   `AsyncValue.error` (un provider qui déplie l'`Either` et **re-throw**
///   l'exception typée) vit dans **`zcrud_riverpod`** — jamais importé dans
///   `zcrud_core` (AD-15). Une exception jetée par `onSubmit` est **enveloppée**
///   en [ZFailure] (`ZServerFailure`), jamais un `catch(_){}` nu.
/// - **AD-2 / SM-1** : l'état de soumission est un `ValueListenable` **dédié** —
///   le bouton et la surface d'erreur n'écoutent QUE lui ; aucun rebuild global
///   sur la voie de frappe. La validation agrégée ne monte AUCUN `Form` global :
///   elle exécute les validateurs mémoïsés (champ-local E3-2 + inter-champs E3-6)
///   contre `controller.valueOf`.
library;

import 'package:flutter/foundation.dart';

import '../../domain/edition/z_condition_evaluator.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/failures/z_failure.dart';
import '../z_form_controller.dart';
import 'z_cross_field_validator.dart';

/// Échec spécifique de **validation agrégée** (distinct d'un échec applicatif —
/// AC1). Porte la table `name → message` des champs invalides.
class ZValidationFailure extends ZFailure {
  /// Construit un échec de validation avec la table [errors] (name → message).
  ZValidationFailure(this.errors)
      : super('Validation échouée (${errors.length} champ(s))');

  /// Messages d'erreur par nom de champ (au moins une entrée).
  final Map<String, String> errors;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZValidationFailure &&
          runtimeType == other.runtimeType &&
          mapEquals(errors, other.errors);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        runtimeType,
        for (final e in errors.entries) ...<Object?>[e.key, e.value],
      ]);
}

/// Statut de la soumission (AC5/AC6). `failure` couvre l'échec de **validation**
/// (via [ZValidationFailure]) ET l'échec **applicatif** (via un [ZFailure] métier).
enum ZSubmissionStatus {
  /// Aucune soumission en cours (état initial).
  idle,

  /// Soumission en attente du seam `onSubmit` (bouton désactivé + spinner).
  inProgress,

  /// Dernière soumission réussie (`onSubmit` → `Right`).
  success,

  /// Dernière soumission en échec (validation OU applicatif) — voir [ZSubmissionState.failure].
  failure,
}

/// Type-valeur **immuable** de l'état de soumission (AC5/AC6).
@immutable
class ZSubmissionState {
  /// Construit un état de soumission.
  const ZSubmissionState(this.status, [this.failure]);

  /// État initial `idle`.
  const ZSubmissionState.idle() : this(ZSubmissionStatus.idle);

  /// État `inProgress` (attente du seam).
  const ZSubmissionState.inProgress() : this(ZSubmissionStatus.inProgress);

  /// État `success`.
  const ZSubmissionState.success() : this(ZSubmissionStatus.success);

  /// État `failure` portant le [ZFailure] (validation ou applicatif).
  const ZSubmissionState.failure(ZFailure failure)
      : this(ZSubmissionStatus.failure, failure);

  /// Statut courant.
  final ZSubmissionStatus status;

  /// Échec porté quand `status == failure` (sinon `null`).
  final ZFailure? failure;

  /// `true` si l'échec est un **échec de validation** (distinct de l'applicatif).
  bool get isValidationFailure => failure is ZValidationFailure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSubmissionState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(runtimeType, status, failure);

  @override
  String toString() => 'ZSubmissionState($status'
      '${failure == null ? '' : ', $failure'})';
}

/// Résultat d'un appel à [ZEditionSubmitController.submit] (données pures).
@immutable
class ZSubmissionOutcome<T> {
  /// Construit un résultat de soumission.
  const ZSubmissionOutcome._(this.status, {this.failure, this.value});

  /// Échec de **validation** agrégée : `onSubmit` NON appelé (AC1).
  const ZSubmissionOutcome.validationFailure(ZValidationFailure failure)
      : this._(ZSubmissionStatus.failure, failure: failure);

  /// Soumission **réussie** portant la valeur [value] (`Right`).
  const ZSubmissionOutcome.success(T value)
      : this._(ZSubmissionStatus.success, value: value);

  /// Échec **applicatif** (`Left` ou exception enveloppée — AD-11).
  const ZSubmissionOutcome.failure(ZFailure failure)
      : this._(ZSubmissionStatus.failure, failure: failure);

  /// Soumission **ignorée** (ré-entrance pendant `inProgress` — AC5).
  const ZSubmissionOutcome.ignored()
      : this._(ZSubmissionStatus.inProgress);

  /// Statut résultant.
  final ZSubmissionStatus status;

  /// Échec porté (validation ou applicatif), si échec.
  final ZFailure? failure;

  /// Valeur `Right` en cas de succès.
  final T? value;

  /// `true` si l'issue est un échec de **validation** (AC1).
  bool get isValidationFailure => failure is ZValidationFailure;

  /// `true` si l'issue est un **succès**.
  bool get isSuccess => status == ZSubmissionStatus.success;
}

/// Seam applicatif de soumission (AD-11) : reçoit un **snapshot de données**
/// (`Map<String, Object?>`) et retourne `Future<Either<ZFailure, T>>`. Détenu
/// HORS du `ZFormController` (jamais sérialisé — AC3/AD-3). L'implémentation
/// réelle (repository create/update) est **E5/E7** ; E3-6 le teste avec un
/// `onSubmit` factice.
typedef ZOnSubmit<T> = Future<ZResult<T>> Function(Map<String, Object?> values);

/// Contrôleur de **soumission** consommant un [ZFormController] (AC1..AC6).
///
/// Séparé du `ZFormController` (ambiguïté #1, décision : contrôleur dédié) : le
/// *dirty*/`reseed`/`values` (état) vivent sur le `ZFormController` ; la
/// soumission (validation agrégée + seam + états) vit ici. `ChangeNotifier`
/// léger détenant un `ValueNotifier<ZSubmissionState>` — le bouton n'écoute que
/// [state] (SM-1).
///
/// Pont `AsyncValue.error` (AD-11/AD-15) : ce contrôleur s'arrête à
/// [ZSubmissionState.failure]. Un provider de **`zcrud_riverpod`** déplie l'état
/// (ou l'`Either` retourné par [submit]) et **re-throw** l'exception typée pour
/// alimenter `AsyncValue.error`. Ce pont est DOCUMENTÉ ici mais n'importe RIEN de
/// Riverpod dans le cœur.
class ZEditionSubmitController<T> {
  /// Construit le contrôleur de soumission.
  ///
  /// [controller] détient l'état ; [fields] est le **catalogue complet** (toutes
  /// les étapes) — la validation agrégée itère les champs dont la condition est
  /// satisfaite (conditionnels honorés), pas seulement `visibleFields` (qui, pour
  /// un stepper, ne reflète que l'étape courante). [onSubmit] est le seam app.
  ZEditionSubmitController({
    required this.controller,
    required this.fields,
    required this.onSubmit,
  });

  /// Contrôleur détenant l'état de formulaire (tranches/valeurs).
  final ZFormController controller;

  /// Catalogue complet des champs (source des validateurs + conditions).
  final List<ZFieldSpec> fields;

  /// Seam applicatif de soumission (jamais détenu par le `ZFormController`).
  final ZOnSubmit<T> onSubmit;

  final ValueNotifier<ZSubmissionState> _state =
      ValueNotifier<ZSubmissionState>(const ZSubmissionState.idle());

  /// État de soumission observable (AC5/AC6). Le bouton/la surface d'erreur
  /// n'écoutent QUE ce `ValueListenable` (SM-1).
  ValueListenable<ZSubmissionState> get state => _state;

  /// Libère la ressource observable. À appeler par l'hôte au dispose.
  void dispose() => _state.dispose();

  /// Valide **tous les champs visibles** (conditionnels honorés) puis, si valide,
  /// délègue à [onSubmit] avec un snapshot immuable des valeurs (AC1..AC6).
  ///
  /// - Invalide ⇒ [controller.revealErrors] (révèle TOUTES les familles, AC2),
  ///   état `failure(ZValidationFailure)`, `onSubmit` **NON** appelé.
  /// - Valide ⇒ `inProgress` (bouton désactivé), snapshot, `await onSubmit` ;
  ///   `Right` ⇒ `success` (+ [controller.markPristine]), `Left` ⇒ `failure`.
  /// - Exception jetée par `onSubmit` ⇒ **enveloppée** en `ZServerFailure` (AD-11).
  /// - Ré-entrance pendant `inProgress` ⇒ **ignorée** (pas de double soumission).
  Future<ZSubmissionOutcome<T>> submit() async {
    if (_state.value.status == ZSubmissionStatus.inProgress) {
      return ZSubmissionOutcome<T>.ignored();
    }

    final errors = _aggregateValidate();
    if (errors.isNotEmpty) {
      controller.revealErrors();
      final failure = ZValidationFailure(errors);
      _state.value = ZSubmissionState.failure(failure);
      return ZSubmissionOutcome<T>.validationFailure(failure);
    }

    _state.value = const ZSubmissionState.inProgress();
    final values = controller.values; // snapshot PUR (jamais Widget/callback).
    ZResult<T> either;
    try {
      either = await onSubmit(values);
    } catch (e) {
      // AD-11 : jamais de remontée non typée — on enveloppe en ZFailure.
      final failure = ZServerFailure('Échec de soumission : $e');
      _state.value = ZSubmissionState.failure(failure);
      return ZSubmissionOutcome<T>.failure(failure);
    }

    return either.fold(
      (f) {
        _state.value = ZSubmissionState.failure(f);
        return ZSubmissionOutcome<T>.failure(f);
      },
      (value) {
        controller.markPristine();
        _state.value = const ZSubmissionState.success();
        return ZSubmissionOutcome<T>.success(value);
      },
    );
  }

  /// Valide les champs dont la **condition** est satisfaite (conditionnels
  /// honorés — AC1), plat comme toutes-étapes. PUR : exécute le validateur
  /// combiné (champ-local + inter-champs) mémoïsé contre `_stringOf(valueOf)`.
  Map<String, String> _aggregateValidate() {
    final errors = <String, String>{};
    for (final field in fields) {
      final condition = field.condition;
      if (condition != null &&
          !evaluateZCondition(condition, controller.valueOf)) {
        continue; // champ masqué par displayCondition ⇒ ne bloque pas.
      }
      final validator =
          ZCrossFieldValidator.compileField(field, controller);
      if (validator == null) continue;
      final error = validator(_stringOf(controller.valueOf(field.name)));
      if (error != null) errors[field.name] = error;
    }
    return errors;
  }

  static String _stringOf(Object? value) => value == null ? '' : '$value';
}
