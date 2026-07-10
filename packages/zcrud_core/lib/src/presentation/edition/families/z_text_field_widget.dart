/// Widget de la **famille texte** (E3-3a) : `text` / `multiline` / `password`.
///
/// Rendu d'un `TextFormField` **autonome** (aucun `Form` global — AD-2) branché
/// sur un `TextEditingController` et un `FocusNode` **stables** détenus par le
/// dispatcher hôte (`ZFieldWidget`) : ce widget est volontairement STATELESS —
/// il ne crée ni ne possède aucun contrôleur (la stabilité E3-2 vit dans l'hôte,
/// jamais dupliquée ici). La saisie est à **sens unique** (`onChanged`) ; la
/// synchronisation guardée hors focus est faite par l'hôte avant ce build.
///
/// - `multiline` → `minLines`/`maxLines` (clavier multi-ligne) ;
/// - `password` → `obscureText: true` (masquage seul, pas de widget distinct) ;
/// - validateur **mémoïsé** (`ZValidatorCompiler`, identité stable) +
///   `AutovalidateMode.onUserInteraction` **par champ** (E3-2 réutilisé).
///
/// a11y/RTL (AD-13) : le `labelText` porte le libellé sémantique (rôle champ de
/// saisie natif) ; aucune couleur/inset non directionnel codé en dur (FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition **texte** (mono-ligne / multi-ligne / masqué).
class ZTextFieldWidget extends StatelessWidget {
  /// Construit le champ texte lié au [controller]/[focusNode] **stables**
  /// (détenus par l'hôte), rendant [field] avec le [validator] mémoïsé.
  const ZTextFieldWidget({
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

  /// `TextEditingController` **stable** (créé/possédé par l'hôte ; jamais ici).
  final TextEditingController controller;

  /// `FocusNode` **stable** (créé/possédé par l'hôte).
  final FocusNode focusNode;

  /// Validateur **mémoïsé** (identité stable entre builds ; `null` si aucun).
  final FormFieldValidator<String>? validator;

  /// Notifié à chaque frappe (voie sens unique `onChanged → setValue`).
  final ValueChanged<String> onChanged;

  /// Mode d'autovalidation du `TextFormField` (E3-5, additif). Défaut
  /// `onUserInteraction` (comportement E3-2/E3-3a préservé) ; le stepper le
  /// bascule ponctuellement en `always` pour **révéler** les erreurs d'une étape
  /// à une transition bloquée — SANS jamais introduire un `Form` global (AD-2).
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final isMultiline = field.type == EditionFieldType.multiline;
    final isPassword = field.type == EditionFieldType.password;
    final resolvedLabel =
        label(context, field.label ?? field.name, fallback: field.label ?? field.name);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: isPassword,
      minLines: isMultiline ? 3 : 1,
      maxLines: isMultiline ? null : 1,
      keyboardType:
          isMultiline ? TextInputType.multiline : TextInputType.text,
      readOnly: field.readOnly,
      // Validation CIBLÉE PAR CHAMP (AD-2) — jamais de `Form` global.
      autovalidateMode: autovalidateMode,
      validator: validator,
      decoration: InputDecoration(labelText: resolvedLabel),
      onChanged: onChanged,
    );
  }
}
