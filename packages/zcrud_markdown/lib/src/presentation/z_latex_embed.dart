/// Embed **LaTeX** (E6-3) de `zcrud_markdown` : embed Quill CUSTOM de type
/// `latex`, son `EmbedBuilder` de rendu DÉFENSIF (`flutter_math_fork`), et le
/// dialogue de saisie/édition de formule.
///
/// ISOLATION (AD-1) : ce fichier vit sous `lib/src/` et consomme `flutter_quill`
/// + `flutter_math_fork`. AUCUN de ces types n'est ré-exporté par le barrel
/// (`ZLatexEmbed`/`ZLatexEmbedBuilder` NE SONT PAS publics). La représentation
/// portée par la tranche `ZFormController` reste une VALEUR NEUTRE : l'op Delta
/// `{"insert": {"latex": "<source>"}}` (`Map` opaque JSON-safe) — jamais un type
/// Quill/math.
///
/// DÉFENSIF (AD-10) : le rendu ne throw JAMAIS — LaTeX malformé / vide / absent /
/// non-`String` → placeholder d'erreur inline thémé (`Math.tex(onErrorFallback:)`
/// ou court-circuit avant appel). L'éditeur reste fonctionnel.
///
/// A11Y (AD-13) : placeholder porteur d'un [Semantics] (« formule invalide »),
/// insets DIRECTIONNELS ; couleur issue du thème injecté (`ZcrudTheme`/`Theme`),
/// zéro couleur codée en dur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Clé/type Delta de l'embed LaTeX — op `{"insert": {"latex": "<source>"}}`.
///
/// C'est aussi le `type` capté GÉNÉRIQUEMENT par `DeltaNeutralOps._embedPlaceholder`
/// (1re clé de la `Map` `insert`) → `ZMarkdownCodec` produit `[embed:latex]` SANS
/// modification (cohérence E6-2, HIGH-1 perte bornée).
const String kLatexEmbedType = 'latex';

/// Libellé a11y (AD-13) du placeholder d'erreur — lisible par lecteur d'écran.
@visibleForTesting
const String kLatexInvalidLabel = 'formule invalide';

/// Embed Quill CUSTOM **inline** de type `latex`.
///
/// `data` = la `String` source LaTeX. `toJson()` (hérité d'[Embeddable]) produit
/// exactement `{"latex": "<source>"}`, d'où l'op Delta
/// `{"insert": {"latex": "<source>"}}` (JSON-safe, opaque — traverse le round-trip
/// d'E6-2 à l'identique via `ZDeltaCodec`).
class ZLatexEmbed extends Embeddable {
  /// Construit l'embed LaTeX portant la [source] (chaîne LaTeX brute).
  const ZLatexEmbed(String source) : super(kLatexEmbedType, source);
}

/// `EmbedBuilder` de rendu DÉFENSIF (AD-10) de l'embed `latex` via
/// `flutter_math_fork`.
///
/// `expanded == false` : la formule est rendue **inline** (dans le flux du
/// paragraphe) via `buildWidgetSpan`, y compris lorsqu'elle est le seul enfant
/// de sa ligne — choix conforme à la décision de conception E6-3 (inline par
/// défaut). Sans état ⇒ instance `const` STABLE (SM-1/AD-2 : aucune allocation
/// par (re)build de tranche ; n'entre jamais dans le flux `document.changes`).
///
/// ÉDITION (AC3, périmètre E6-3) : la RÉ-ÉDITION d'une formule existante passe
/// par la **voie bouton toolbar** — placer le caret sur/juste après l'embed puis
/// activer le bouton « Formule » (`_promptAndInsertLatex` détecte l'embed sous le
/// caret, pré-remplit le dialogue et REMPLACE l'op). L'édition par **tap direct**
/// sur la formule rendue (pose d'un `GestureDetector` sur le widget d'embed) est
/// HORS PÉRIMÈTRE : ce builder ne câble volontairement aucun geste, pour garder
/// l'instance `const` sans état (SM-1) et l'op de tranche opaque (F5).
class ZLatexEmbedBuilder extends EmbedBuilder {
  /// Builder `const` (sans état, aucune ressource à disposer).
  const ZLatexEmbedBuilder();

  @override
  String get key => kLatexEmbedType;

  /// Rendu INLINE (jamais bloc) : force le passage par le chemin `buildWidgetSpan`
  /// même pour une formule seule sur sa ligne.
  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final Object? data = embedContext.node.value.data;
    // DÉFENSIF (AD-10) : donnée absente / non-`String` / vide → placeholder, on
    // n'appelle JAMAIS `Math.tex` sur une entrée invalide.
    if (data is! String || data.trim().isEmpty) {
      return _errorPlaceholder(context);
    }
    // `Math.tex` capture les erreurs de parse/rendu via `onErrorFallback` : une
    // formule MALFORMÉE ne throw pas, elle dégrade en placeholder inline.
    return Math.tex(
      data,
      mathStyle: MathStyle.text,
      textStyle: embedContext.textStyle,
      onErrorFallback: (FlutterMathException _) => _errorPlaceholder(context),
    );
  }

  /// Placeholder d'erreur INLINE thémé (AD-13/FR-26) : icône `error_outline`
  /// colorée par `ZcrudTheme.errorColor` (repli `Theme.colorScheme.error`),
  /// enveloppée d'un [Semantics] lisible ([kLatexInvalidLabel]). Insets
  /// DIRECTIONNELS. Zéro couleur codée en dur.
  Widget _errorPlaceholder(BuildContext context) {
    final Color color =
        ZcrudTheme.of(context).errorColor ?? Theme.of(context).colorScheme.error;
    return Semantics(
      label: kLatexInvalidLabel,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
        child: Icon(Icons.error_outline, size: 18, color: color),
      ),
    );
  }
}

/// Ouvre le dialogue de saisie/édition d'une formule LaTeX (AC3, AD-13).
///
/// Retourne la chaîne LaTeX saisie (validée), ou `null` si l'utilisateur annule.
/// [initial] pré-remplit le champ (édition d'un embed existant). Cibles ≥ 48 dp,
/// [Semantics] explicites, insets DIRECTIONNELS.
Future<String?> showZLatexDialog(
  BuildContext context, {
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => _ZLatexDialog(initial: initial),
  );
}

class _ZLatexDialog extends StatefulWidget {
  const _ZLatexDialog({required this.initial});

  final String initial;

  @override
  State<_ZLatexDialog> createState() => _ZLatexDialogState();
}

class _ZLatexDialogState extends State<_ZLatexDialog> {
  late final TextEditingController _text;

  /// Cible de tap minimale (AD-13).
  static const double _kMinTapTarget = 48;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Valide la saisie (AC3). Une entrée VIDE ou BLANCHE est traitée comme une
  /// ANNULATION (`pop(null)`) : on n'insère JAMAIS un embed `latex` vide (qui ne
  /// rendrait qu'un placeholder d'erreur persistant — F2). Le seul cas
  /// d'insertion est donc une source non-blanche.
  void _submit() {
    final String source = _text.text;
    if (source.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(source);
  }

  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Semantics(
        header: true,
        child: const Text('Formule LaTeX'),
      ),
      content: TextField(
        controller: _text,
        autofocus: true,
        textAlign: TextAlign.start,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Formule LaTeX',
          hintText: r'ex. E = mc^2',
          hintTextDirection: TextDirection.ltr,
        ),
      ),
      actionsPadding: const EdgeInsetsDirectional.only(
        end: 12,
        bottom: 8,
        start: 12,
      ),
      actions: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMinTapTarget,
            minHeight: _kMinTapTarget,
          ),
          child: TextButton(
            onPressed: _cancel,
            child: Text(l10n.cancelButtonLabel),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMinTapTarget,
            minHeight: _kMinTapTarget,
          ),
          child: FilledButton(
            onPressed: _submit,
            child: Text(l10n.okButtonLabel),
          ),
        ),
      ],
    );
  }
}
