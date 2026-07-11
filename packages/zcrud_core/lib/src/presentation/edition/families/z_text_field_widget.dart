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
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';

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
    this.bare = false,
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

  /// Rendu **bare** (borderless, sans label) pour le mode `large` (AC4) : le
  /// décor est porté par la Card, le champ interne n'affiche aucune bordure ni
  /// label. Défaut `false` (rendu inline standard).
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final isMultiline = field.type == EditionFieldType.multiline;
    final isPassword = field.type == EditionFieldType.password;
    final resolvedLabel =
        label(context, field.label ?? field.name, fallback: field.label ?? field.name);

    // B2 (AC6/AC7) : `minLines`/`maxLines` effectifs lus depuis `ZTextConfig`
    // avec repli type-dépendant préservant le comportement historique.
    final config = field.config is ZTextConfig ? field.config! as ZTextConfig : null;
    var effectiveMinLines = config?.minLines ?? (isMultiline ? 3 : 1);
    var effectiveMaxLines = config?.maxLines ?? (isMultiline ? null : 1);
    // AC8 : garde `obscureText` — une saisie masquée multi-ligne est invalide
    // côté Flutter ; on force 1/1 (config multi-ligne ignorée sans throw).
    if (isPassword) {
      effectiveMinLines = 1;
      effectiveMaxLines = 1;
    }
    // MEDIUM-1 (DP-1) : garantir minLines <= maxLines — sinon Flutter lève une
    // assertion au build. Cas réel : `maxLines` authored < repli `minLines`
    // (ex. multiline + ZTextConfig(maxLines: 2) sans minLines → min 3 > max 2).
    final maxLines = effectiveMaxLines;
    if (maxLines != null && effectiveMinLines > maxLines) {
      effectiveMinLines = maxLines;
    }
    // AC8 : clavier multi-ligne dès que la hauteur effective dépasse une ligne.
    final keyboardType = effectiveMaxLines != 1
        ? TextInputType.multiline
        : TextInputType.text;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: isPassword,
      minLines: effectiveMinLines,
      maxLines: effectiveMaxLines,
      keyboardType: keyboardType,
      style: ZcrudTheme.of(context).inputTextStyle,
      readOnly: field.readOnly,
      // Validation CIBLÉE PAR CHAMP (AD-2) — jamais de `Form` global.
      autovalidateMode: autovalidateMode,
      validator: validator,
      decoration: ZcrudTheme.of(context).inputDecoration(
        context,
        label: bare ? null : resolvedLabel,
        bare: bare,
      ),
      onChanged: onChanged,
    );
  }
}
