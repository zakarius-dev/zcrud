/// **Valeurs de formulaire** : la voie UNIQUE de validation agrégée et de
/// normalisation d'un jeu de saisies.
///
/// Un formulaire déclaré par des [ZFieldSpec] détient ses saisies dans un
/// [ZFormController], sous la forme la plus commode pour le **widget** qui les
/// écrit : un nombre saisi au clavier arrive parfois en texte, une date choisie
/// au sélecteur arrive parfois en `DateTime`, une valeur d'énumération arrive
/// parfois comme `enum` Dart. Ce fichier projette cet état d'édition vers la
/// forme **de persistance** attendue par le reste du socle — types coercés,
/// dates en ISO-8601, énumérations en camelCase — et écarte ce qui ne doit
/// jamais être écrit : un champ dont la condition d'affichage est fausse, et un
/// champ en lecture seule.
///
/// Deux normalisations divergentes (une par surface d'édition) rendraient la
/// forme des données tributaire de l'écran qui les a produites. C'est pourquoi
/// [zNormalizeFormValues] est la **seule** projection du dépôt, et
/// [zValidateFormFields] la **seule** validation agrégée : la soumission d'un
/// écran assemblé et celle d'un formulaire intégré à une page passent par les
/// mêmes fonctions, avec la même règle de visibilité.
///
/// Invariants : fonctions **pures** (aucun `BuildContext`, aucun widget, aucun
/// gestionnaire d'état) ; aucune exception ne remonte (invariant AD-10) — une
/// valeur qui ne se laisse pas coercer est rendue **telle quelle**.
library;

import 'package:flutter/material.dart' show TimeOfDay;

import '../../domain/edition/edition_field_type.dart';
import '../../domain/edition/z_condition_evaluator.dart';
import '../../domain/edition/z_date_range.dart';
import '../../domain/edition/z_field_config.dart';
import '../../domain/edition/z_field_spec.dart';
import '../z_form_controller.dart';
import 'edition_field_family.dart';
import 'z_cross_field_validator.dart';
import 'z_value_emptiness.dart';

/// `true` si le champ [spec] est **actif** : sa condition d'affichage est
/// absente ou satisfaite.
///
/// Un champ inactif ne bloque pas la validation et ne contribue pas aux
/// valeurs normalisées — c'est la même règle des deux côtés, évaluée ici une
/// seule fois.
///
/// [persistedValueOf] donne accès à l'état **d'origine** (`ZValueSource.persisted`)
/// et [contextValueOf] au contexte applicatif ; absents, ils résolvent `null`
/// (lecture défensive — invariant AD-10).
bool zIsFieldActive(
  ZFieldSpec spec,
  ZValueOf valueOf, {
  ZValueOf? persistedValueOf,
  ZValueOf? contextValueOf,
}) {
  final condition = spec.condition;
  if (condition == null) return true;
  return evaluateZCondition(
    condition,
    valueOf,
    persistedValueOf: persistedValueOf,
    contextValueOf: contextValueOf,
  );
}

/// Valide **tous les champs actifs** de [fields] contre l'état de [controller]
/// et retourne la table `nom du champ → message d'erreur` (vide ⇒ valide).
///
/// Voie unique de validation agrégée : elle exécute le validateur combiné
/// (champ-local + inter-champs) mémoïsé de chaque champ, contre la projection
/// de validation de sa valeur (`zValidationText`, qui fait valoir `required`
/// sur une collection vide). Un champ dont la condition d'affichage est fausse
/// est **ignoré** : il ne peut pas bloquer une soumission.
///
/// Aucune révélation d'erreur ici : la fonction est pure. C'est à l'appelant
/// d'appeler `ZFormController.revealErrors` s'il veut afficher les messages.
Map<String, String> zValidateFormFields({
  required List<ZFieldSpec> fields,
  required ZFormController controller,
  ZValueOf? persistedValueOf,
  ZValueOf? contextValueOf,
}) {
  final errors = <String, String>{};
  for (final field in fields) {
    if (!zIsFieldActive(
      field,
      controller.valueOf,
      persistedValueOf: persistedValueOf,
      contextValueOf: contextValueOf,
    )) {
      continue;
    }
    final validator = ZCrossFieldValidator.compileField(field, controller);
    if (validator == null) continue;
    final error = validator(zValidationText(controller.valueOf(field.name)));
    if (error != null) errors[field.name] = error;
  }
  return errors;
}

/// Projette la valeur brute [value] du champ [spec] vers sa forme de
/// **persistance**.
///
/// Règles appliquées, dans cet ordre :
///
/// | Déclaration | Saisie possible | Valeur rendue |
/// |---|---|---|
/// | n'importe laquelle | `enum` Dart | son `name` (camelCase) |
/// | `number` | `'12,5'` / `'12.5'` | `12.5` (`num`) |
/// | `integer` | `'12'` / `12.0` | `12` (`int`) |
/// | `float` | `'12'` | `12.0` (`double`) |
/// | `boolean` | `'true'` / `'false'` | `true` / `false` |
/// | `dateTime` (mode date/dateTime) | `DateTime` | ISO-8601 |
/// | `time` (ou mode `time`) | `DateTime` / `TimeOfDay` | `HH:mm` |
/// | `dateRange` | [ZDateRange] | `{'start', 'end'}` ISO-8601 |
/// | champ multiple | `List` | liste dont chaque élément est normalisé |
///
/// Les formats produits sont **exactement** ceux qu'écrivent déjà les familles
/// de champs correspondantes : aucune convention nouvelle n'est introduite.
/// Toute valeur qui ne relève d'aucune règle — ou qui ne se laisse pas
/// convertir (`'douze'` sur un champ numérique) — est rendue **inchangée**,
/// jamais remplacée par `null` et jamais cause d'exception (invariant AD-10) ;
/// c'est au validateur de refuser la saisie, pas à la normalisation de la
/// perdre.
Object? zNormalizeFieldValue(ZFieldSpec spec, Object? value) {
  if (value == null) return null;
  if (value is List) {
    return <Object?>[for (final item in value) _normalizeScalar(spec, item)];
  }
  return _normalizeScalar(spec, value);
}

Object? _normalizeScalar(ZFieldSpec spec, Object? value) {
  if (value == null) return null;
  // Convention de persistance du dépôt : valeurs d'énumération en camelCase,
  // donc le `name` de la constante — quelle que soit la famille du champ.
  if (value is Enum) return value.name;
  switch (spec.type) {
    case EditionFieldType.number:
    case EditionFieldType.rating:
      return _asNum(value) ?? value;
    case EditionFieldType.integer:
      final n = _asNum(value);
      return n == null ? value : n.toInt();
    case EditionFieldType.float:
      final n = _asNum(value);
      return n == null ? value : n.toDouble();
    case EditionFieldType.boolean:
      return _asBool(value) ?? value;
    case EditionFieldType.dateTime:
    case EditionFieldType.time:
      return _asDateText(spec, value) ?? value;
    case EditionFieldType.dateRange:
      return value is ZDateRange ? value.toJson() : value;
    default:
      return value;
  }
}

/// Coercition numérique **défensive** : `null` si la valeur n'est pas un
/// nombre lisible (la valeur d'origine est alors conservée par l'appelant).
/// La virgule décimale est acceptée — c'est la saisie d'un clavier
/// francophone, pas une invention de format.
num? _asNum(Object? value) {
  if (value is num) return value;
  if (value is String) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    return num.tryParse(raw) ?? num.tryParse(raw.replaceFirst(',', '.'));
  }
  return null;
}

/// Coercition booléenne **défensive** : seuls `bool` et les textes `'true'` /
/// `'false'` (casse indifférente) sont reconnus.
bool? _asBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    final raw = value.trim().toLowerCase();
    if (raw == 'true') return true;
    if (raw == 'false') return false;
  }
  return null;
}

/// Projette une date/heure vers la convention d'écriture **de son mode** —
/// la même que celle du champ date : ISO-8601 pour `date`/`dateTime`, `HH:mm`
/// pour `time`. Une valeur déjà textuelle est rendue telle quelle (elle vient
/// du champ, qui écrit déjà dans cette convention).
String? _asDateText(ZFieldSpec spec, Object? value) {
  final mode = _dateModeOf(spec);
  if (value is String) return value;
  if (mode == ZDateMode.time) {
    if (value is TimeOfDay) return _hhmm(value.hour, value.minute);
    if (value is DateTime) return _hhmm(value.hour, value.minute);
    return null;
  }
  if (value is DateTime) return value.toIso8601String();
  return null;
}

/// Mode date effectif — **même résolution** que le champ date : la config
/// prime, puis le type déclaré, et à défaut `dateTime`.
ZDateMode _dateModeOf(ZFieldSpec spec) {
  final config = spec.config;
  if (config is ZDateConfig && config.mode != null) return config.mode!;
  if (spec.type == EditionFieldType.time) return ZDateMode.time;
  return ZDateMode.dateTime;
}

String _hhmm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Clé **compagne** sous laquelle les valeurs normalisées portent les fichiers
/// que l'utilisateur a **retirés** du champ [fieldName].
///
/// Un champ fichier ne persiste que ce qui lui reste attaché ; ce que
/// l'utilisateur a détaché — une photo supprimée, un document remplacé — n'a
/// plus de place nulle part, alors que c'est justement ce qu'il faut effacer
/// pour de bon. Cette clé lui en donne une :
///
/// ```dart
/// final valeurs = formulaire.submit();
/// final retires = valeurs?[zRemovedFilesKey('photos')] as List<Object>?;
/// // → les fichiers à effacer réellement, sous la forme que le champ tenait.
/// ```
///
/// Utilisez toujours cette fonction plutôt qu'une chaîne écrite à la main : la
/// convention appartient au socle.
String zRemovedFilesKey(String fieldName) => '${fieldName}_removed';

/// Snapshot **normalisé** des valeurs de [controller], restreint aux champs
/// de [fields] qui ont le droit d'être écrits.
///
/// Sont **écartés** :
/// * les champs dont la condition d'affichage est fausse — ce que l'utilisateur
///   ne voit pas, il ne l'a pas décidé ;
/// * les champs en **lecture seule** (`ZFieldSpec.readOnly`), qu'aucune saisie
///   ne peut avoir modifiés.
///
/// Chaque valeur retenue passe par [zNormalizeFieldValue]. Le résultat est une
/// carte **immuable** de données pures, prête à être persistée ou rendue à
/// l'appelant — jamais l'état brut des contrôleurs de saisie.
///
/// **Champs fichier** — chaque champ de la famille fichier
/// (`file`/`image`/`document`) retenu ci-dessus ajoute une entrée compagne
/// [zRemovedFilesKey] portant ce que l'utilisateur a **retiré** du champ : les
/// objets fichier que le champ tenait, ou leur référence opaque quand il ne les
/// avait pas résolus. La clé est **toujours présente** pour ces champs — liste
/// **vide** quand rien n'a été retiré, jamais `null` — de sorte que l'appelant
/// n'ait pas à distinguer « rien retiré » de « pas suivi ». Un formulaire sans
/// champ fichier rend exactement les mêmes clés qu'auparavant. Une clé
/// compagne qui entrerait en collision avec un champ réellement déclaré ne
/// l'écrase jamais : le champ déclaré fait foi.
Map<String, dynamic> zNormalizeFormValues({
  required List<ZFieldSpec> fields,
  required ZFormController controller,
  ZValueOf? persistedValueOf,
  ZValueOf? contextValueOf,
}) {
  final out = <String, dynamic>{};
  final removed = <String, List<Object>>{};
  for (final field in fields) {
    if (field.readOnly) continue;
    if (!zIsFieldActive(
      field,
      controller.valueOf,
      persistedValueOf: persistedValueOf,
      contextValueOf: contextValueOf,
    )) {
      continue;
    }
    out[field.name] =
        zNormalizeFieldValue(field, controller.valueOf(field.name));
    if (familyOf(field.type) == EditionFamily.file) {
      removed[zRemovedFilesKey(field.name)] =
          controller.removedFilesOf(field.name);
    }
  }
  // Écrites APRÈS les champs : un champ réellement déclaré sous ce nom garde sa
  // valeur — une convention du socle ne recouvre pas une déclaration de l'hôte.
  removed.forEach((key, value) {
    if (!out.containsKey(key)) out[key] = value;
  });
  return Map<String, dynamic>.unmodifiable(out);
}
