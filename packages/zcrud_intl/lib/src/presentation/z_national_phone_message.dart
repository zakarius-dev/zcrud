/// Helper de **présentation** — mappe un [ZNationalPhoneError] vers un message
/// **l10n** résolu (DP-20, AC4, AD-1/AD-13).
///
/// origine: le discriminant d'erreur du domaine ([ZNationalPhoneError]) est
/// **neutre** (sans message, AD-1). La traduction vit ici, dans la couche
/// présentation, via `label(context, key, fallback:)` de `zcrud_core` — repli
/// **français** fidèle à DODLP (`edition_screen.dart:679/682/696`), surchargeable
/// via `ZcrudScope(labels:)` (**aucune** table ajoutée au cœur).
///
/// Le message renvoyé est destiné à `InputDecoration.errorText` : il est **annoncé
/// par le lecteur d'écran** via la sémantique native du `TextField` (AD-13).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_national_phone_validator.dart';

/// Résout le message d'erreur du validateur national. `null` (aucune erreur) →
/// `null` (aucun `errorText`, rétro-compat opt-in).
///
/// Clés l10n (repli français, surchargeables via le scope) :
/// - `intl.phone.national.required` → « Numéro de téléphone requis » ;
/// - `intl.phone.national.invalidLength` → « Numéro de téléphone incomplet » ;
/// - `intl.phone.national.invalidPrefix` → « Numéro de téléphone invalide ».
String? nationalPhoneErrorText(
  BuildContext context,
  ZNationalPhoneError? error,
) {
  switch (error) {
    case null:
      return null;
    case ZNationalPhoneError.required:
      return label(
        context,
        'intl.phone.national.required',
        fallback: 'Numéro de téléphone requis',
      );
    case ZNationalPhoneError.invalidLength:
      return label(
        context,
        'intl.phone.national.invalidLength',
        fallback: 'Numéro de téléphone incomplet',
      );
    case ZNationalPhoneError.invalidPrefix:
      return label(
        context,
        'intl.phone.national.invalidPrefix',
        fallback: 'Numéro de téléphone invalide',
      );
  }
}
