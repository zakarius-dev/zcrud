/// Widget de la **famille texte** : `text` / `multiline` / `password`.
///
/// Rendu d'un `TextFormField` **autonome** (aucun `Form` global — invariant
/// AD-2) branché sur un `TextEditingController` et un `FocusNode` **stables**
/// détenus par le dispatcher hôte (`ZFieldWidget`) : ce widget est
/// volontairement STATELESS — il ne crée ni ne possède aucun contrôleur (la
/// stabilité vit dans l'hôte, jamais dupliquée ici). La saisie est à **sens
/// unique** (`onChanged`) ; la synchronisation guardée hors focus est faite
/// par l'hôte avant ce build.
///
/// - `multiline` → `minLines`/`maxLines` (clavier multi-ligne) ;
/// - `password` → `obscureText: true` (masquage seul, pas de widget distinct) ;
/// - validateur **mémoïsé** (`ZValidatorCompiler`, identité stable) +
///   `AutovalidateMode.onUserInteraction` **par champ**.
///
/// a11y/RTL (invariant AD-13) : le `labelText` porte le libellé sémantique
/// (rôle champ de saisie natif) ; aucune couleur/inset non directionnel codé
/// en dur (invariant FR-26).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_condition_evaluator.dart' show ZValueOf;
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../theme/z_theme.dart';
import '../z_field_adornment_view.dart';

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
    this.valueOf,
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

  /// Mode d'autovalidation du `TextFormField` (additif). Défaut
  /// `onUserInteraction` (comportement préservé) ; le stepper le bascule
  /// ponctuellement en `always` pour **révéler** les erreurs d'une étape à
  /// une transition bloquée — SANS jamais introduire un `Form` global
  /// (invariant AD-2).
  final AutovalidateMode autovalidateMode;

  /// Rendu **bare** (borderless, sans label) pour le mode `large` : le
  /// décor est porté par la Card, le champ interne n'affiche aucune bordure ni
  /// label. Défaut `false` (rendu inline standard).
  final bool bare;

  /// Lecteur **nommé** du formulaire hôte, transmis aux ornements `.widget`
  /// (valeur du champ décoré + lecture d'un champ voisin). `null` ⇒ ornement
  /// rendu sans valeur (comportement d'une composition hors formulaire).
  final ZValueOf? valueOf;

  @override
  Widget build(BuildContext context) {
    final isMultiline = field.type == EditionFieldType.multiline;
    final isPassword = field.type == EditionFieldType.password;

    // `minLines`/`maxLines` effectifs lus depuis `ZTextConfig` avec repli
    // type-dépendant préservant le comportement historique.
    final config = field.config is ZTextConfig ? field.config! as ZTextConfig : null;
    // **Règle de mapping `text` → multiligne** : un champ `text` dont la
    // config déclare `minLines > 1` se comporte comme un champ multiligne.
    // Sans cette règle, le repli `maxLines = 1` (défaut mono-ligne)
    // écraserait silencieusement un `minLines: 2` authored (min > max →
    // clamp à 1 ligne). La règle n'affecte QUE le **défaut de `maxLines`**
    // (rendu extensible au lieu de figé à 1) ; un `maxLines` explicite est
    // toujours respecté tel quel. `password` reste mono-ligne (garde
    // ci-dessous). Un `text` sans config (ou avec `maxLines` seul) conserve
    // exactement le rendu antérieur.
    final configWantsMultiline =
        !isPassword && (config?.minLines != null && config!.minLines! > 1);
    final treatAsMultiline = isMultiline || configWantsMultiline;
    var effectiveMinLines = config?.minLines ?? (treatAsMultiline ? 3 : 1);
    var effectiveMaxLines = config?.maxLines ?? (treatAsMultiline ? null : 1);
    // Garde `obscureText` — une saisie masquée multi-ligne est invalide
    // côté Flutter ; on force 1/1 (config multi-ligne ignorée sans throw).
    if (isPassword) {
      effectiveMinLines = 1;
      effectiveMaxLines = 1;
    }
    // Garantit `minLines <= maxLines` — sinon Flutter lève une assertion au
    // build. Cas réel : `maxLines` authored < repli `minLines` (ex.
    // multiline + ZTextConfig(maxLines: 2) sans minLines → min 3 > max 2).
    final maxLines = effectiveMaxLines;
    if (maxLines != null && effectiveMinLines > maxLines) {
      effectiveMinLines = maxLines;
    }
    // Clavier multi-ligne dès que la hauteur effective dépasse une ligne.
    final keyboardType = effectiveMaxLines != 1
        ? TextInputType.multiline
        : TextInputType.text;

    // Capitalisation déclarative. Un mot de passe n'est JAMAIS capitalisé
    // (altèrerait le secret) ; sinon la config pilote (a) l'indice clavier
    // `textCapitalization` ET (b) un formateur DÉTERMINISTE couvrant collage /
    // saisie programmatique / clavier physique — ce que l'indice seul ne
    // fait pas.
    final capitalization = isPassword
        ? ZTextCapitalization.none
        : (config?.capitalization ?? ZTextCapitalization.none);
    // Transformation INJECTÉE par l'hôte, appliquée APRÈS la capitalisation
    // (l'hôte a le dernier mot). Jamais sur un mot de passe.
    final transform = isPassword ? null : config?.textTransform;
    final hasFormatter =
        capitalization != ZTextCapitalization.none || transform != null;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: isPassword,
      minLines: effectiveMinLines,
      maxLines: effectiveMaxLines,
      keyboardType: keyboardType,
      textCapitalization: _keyboardHint(capitalization),
      inputFormatters: hasFormatter
          ? <TextInputFormatter>[
              _ZTextTransformFormatter(capitalization, transform),
            ]
          : null,
      style: ZcrudTheme.of(context).inputTextStyle,
      readOnly: field.readOnly,
      // Validation CIBLÉE PAR CHAMP (invariant AD-2) — jamais de `Form` global.
      autovalidateMode: autovalidateMode,
      validator: validator,
      // Label enrichi + hint/helper + ornements leading/prefix/suffix
      // (répartis par `zFieldDecoration` selon `ZAdornmentKind`).
      decoration:
          zFieldDecoration(context, field, bare: bare, valueOf: valueOf),
      onChanged: onChanged,
    );
  }
}

/// Indice de capitalisation clavier logiciel dérivé de la config.
/// **Non fiable seul** — cf. [_ZCapitalizationFormatter] pour la garantie réelle.
TextCapitalization _keyboardHint(ZTextCapitalization c) => switch (c) {
      ZTextCapitalization.none => TextCapitalization.none,
      ZTextCapitalization.sentences => TextCapitalization.sentences,
      ZTextCapitalization.words => TextCapitalization.words,
      ZTextCapitalization.characters => TextCapitalization.characters,
    };

/// Formateur de capitalisation DÉTERMINISTE — garantit la casse à
/// chaque frappe, quelle que soit la source (collage, saisie programmatique,
/// clavier physique), là où `textCapitalization` n'est qu'un indice logiciel.
///
/// **Invariant AD-2 préservé** : toutes les transformations ne changent QUE la
/// casse, jamais la longueur — la position du curseur ([TextEditingValue.selection])
/// reste donc valide et est conservée telle quelle (aucun saut de curseur).
class _ZTextTransformFormatter extends TextInputFormatter {
  const _ZTextTransformFormatter(this.mode, this.transform);

  final ZTextCapitalization mode;

  /// Transformation injectée par l'hôte, appliquée APRÈS [mode].
  final String Function(String)? transform;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var formatted = _apply(newValue.text);
    final custom = transform;
    if (custom != null) {
      // DÉFENSIF (invariant AD-10) : une transformation d'hôte qui lève ne
      // doit pas casser la saisie — on retombe sur le texte non transformé.
      try {
        formatted = custom(formatted);
      } on Object {
        // Silencieux et total : la frappe continue.
      }
    }
    if (formatted == newValue.text) return newValue;
    // Une transformation d'hôte PEUT changer la longueur (la casse, non) : on
    // ramène l'offset dans les bornes plutôt que de lever `RangeError`.
    final offset = newValue.selection.baseOffset;
    final safe = offset < 0 || offset > formatted.length
        ? formatted.length
        : offset;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: safe),
      composing: TextRange.empty,
    );
  }

  String _apply(String s) => switch (mode) {
        ZTextCapitalization.none => s,
        ZTextCapitalization.characters => s.toUpperCase(),
        ZTextCapitalization.words => _capWords(s),
        ZTextCapitalization.sentences => _capSentences(s),
      };

  /// Première lettre de chaque mot en majuscule (séparateur = espace).
  static String _capWords(String s) {
    final buf = StringBuffer();
    var atWordStart = true;
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      final isSpace = ch.trim().isEmpty;
      buf.write(atWordStart && !isSpace ? ch.toUpperCase() : ch);
      atWordStart = isSpace;
    }
    return buf.toString();
  }

  /// Première lettre de chaque phrase en majuscule (début + après `.`/`!`/`?`).
  /// Sur une saisie mono-phrase, équivaut à un simple `ucFirst`.
  static String _capSentences(String s) {
    final buf = StringBuffer();
    var atSentenceStart = true;
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      final isSpace = ch.trim().isEmpty;
      if (atSentenceStart && !isSpace) {
        buf.write(ch.toUpperCase());
        atSentenceStart = false;
      } else {
        buf.write(ch);
        if (ch == '.' || ch == '!' || ch == '?') atSentenceStart = true;
      }
    }
    return buf.toString();
  }
}
