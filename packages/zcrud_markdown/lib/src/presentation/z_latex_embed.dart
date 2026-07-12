/// Embed **LaTeX** (E6-3 + MIN-1) de `zcrud_markdown` : embeds Quill CUSTOM
/// **inline** (`latex`, `MathStyle.text`) ET **bloc/display** (`latexBlock`,
/// `MathStyle.display` centré), leurs `EmbedBuilder`s de rendu DÉFENSIF
/// (`flutter_math_fork`), et le dialogue de saisie/édition de formule (aperçu
/// live + exemples + bascule inline/bloc).
///
/// ISOLATION (AD-1) : ce fichier vit sous `lib/src/` et consomme `flutter_quill`
/// + `flutter_math_fork`. AUCUN de ces types n'est ré-exporté par le barrel
/// (`ZLatexEmbed`/`ZLatexBlockEmbed`/leurs builders NE SONT PAS publics). La
/// représentation portée par la tranche `ZFormController` reste une VALEUR
/// NEUTRE : l'op Delta `{"insert": {"latex": "<source>"}}` (inline) ou
/// `{"insert": {"latexBlock": "<source>"}}` (bloc) — `Map` opaque JSON-safe,
/// jamais un type Quill/math.
///
/// RÉTRO-COMPAT (MIN-1) : le type `latex` (inline, `MathStyle.text`) est
/// INCHANGÉ. Le mode display n'est qu'un type d'embed ADDITIF (`latexBlock`) —
/// les documents existants (ops `latex`) ne sont pas touchés.
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

/// Clé/type Delta de l'embed LaTeX **inline** — op `{"insert": {"latex": "<src>"}}`.
///
/// C'est aussi le `type` capté GÉNÉRIQUEMENT par `DeltaNeutralOps._embedPlaceholder`
/// (1re clé de la `Map` `insert`) → `ZMarkdownCodec` produit `[embed:latex]` SANS
/// modification (cohérence E6-2, HIGH-1 perte bornée).
const String kLatexEmbedType = 'latex';

/// Clé/type Delta de l'embed LaTeX **bloc/display** (MIN-1) — op
/// `{"insert": {"latexBlock": "<src>"}}`. ADDITIF : ne remplace jamais `latex`.
const String kLatexBlockEmbedType = 'latexBlock';

/// Libellé a11y (AD-13) du placeholder d'erreur — lisible par lecteur d'écran.
@visibleForTesting
const String kLatexInvalidLabel = 'formule invalide';

/// Exemples de formules proposés dans le dialogue (MIN-1) — aucun texte codé en
/// dur dans le rendu, juste des raccourcis de saisie.
@visibleForTesting
const List<String> kLatexExamples = <String>[
  'E = mc^2',
  r'\frac{a}{b}',
  r'\sqrt{x}',
  r'\sum_{i=1}^{n} i',
  r'\int_0^1 x\,dx',
];

/// Embed Quill CUSTOM **inline** de type `latex` (`MathStyle.text`).
///
/// `data` = la `String` source LaTeX. `toJson()` (hérité d'[Embeddable]) produit
/// exactement `{"latex": "<source>"}`, d'où l'op Delta
/// `{"insert": {"latex": "<source>"}}` (JSON-safe, opaque — traverse le round-trip
/// d'E6-2 à l'identique via `ZDeltaCodec`).
class ZLatexEmbed extends Embeddable {
  /// Construit l'embed LaTeX inline portant la [source] (chaîne LaTeX brute).
  const ZLatexEmbed(String source) : super(kLatexEmbedType, source);
}

/// Embed Quill CUSTOM **bloc/display** de type `latexBlock` (`MathStyle.display`,
/// rendu centré). MIN-1 : parité DODLP `FormulaBlockEmbed`.
class ZLatexBlockEmbed extends Embeddable {
  /// Construit l'embed LaTeX bloc portant la [source] (chaîne LaTeX brute).
  const ZLatexBlockEmbed(String source) : super(kLatexBlockEmbedType, source);
}

/// Placeholder d'erreur INLINE thémé (AD-13/FR-26) : icône `error_outline`
/// colorée par `ZcrudTheme.errorColor` (repli `Theme.colorScheme.error`),
/// enveloppée d'un [Semantics] lisible ([kLatexInvalidLabel]). Insets
/// DIRECTIONNELS. Zéro couleur codée en dur. PARTAGÉ par les deux builders.
Widget _latexErrorPlaceholder(BuildContext context) {
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

/// Rendu DÉFENSIF (AD-10) commun d'une formule LaTeX avec un [mathStyle] donné.
/// Donnée absente / non-`String` / vide → placeholder ; formule malformée →
/// `onErrorFallback` (jamais de throw).
Widget _buildMath(
  BuildContext context,
  EmbedContext embedContext,
  MathStyle mathStyle,
) {
  final Object? data = embedContext.node.value.data;
  if (data is! String || data.trim().isEmpty) {
    return _latexErrorPlaceholder(context);
  }
  return Math.tex(
    data,
    mathStyle: mathStyle,
    textStyle: embedContext.textStyle,
    onErrorFallback: (FlutterMathException _) => _latexErrorPlaceholder(context),
  );
}

/// `EmbedBuilder` de rendu DÉFENSIF (AD-10) de l'embed `latex` **inline** via
/// `flutter_math_fork` (`MathStyle.text`).
///
/// `expanded == false` : la formule est rendue **inline** (dans le flux du
/// paragraphe) via `buildWidgetSpan`. Sans état ⇒ instance `const` STABLE
/// (SM-1/AD-2 : aucune allocation par (re)build de tranche).
class ZLatexEmbedBuilder extends EmbedBuilder {
  /// Builder `const` (sans état, aucune ressource à disposer).
  const ZLatexEmbedBuilder();

  @override
  String get key => kLatexEmbedType;

  /// Rendu INLINE (jamais bloc).
  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) =>
      _buildMath(context, embedContext, MathStyle.text);
}

/// `EmbedBuilder` de rendu DÉFENSIF (AD-10) de l'embed `latexBlock`
/// **bloc/display** (`MathStyle.display`), rendu **centré** sur sa propre ligne.
///
/// `expanded == true` : occupe sa ligne (bloc). Le rendu est enveloppé d'un
/// [Center] directionnel (parité DODLP `_CenteredMathWidget`). Sans état ⇒
/// instance `const` STABLE (SM-1/AD-2).
class ZLatexBlockEmbedBuilder extends EmbedBuilder {
  /// Builder `const` (sans état).
  const ZLatexBlockEmbedBuilder();

  @override
  String get key => kLatexBlockEmbedType;

  /// Rendu BLOC : la formule occupe sa propre ligne (display centré).
  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return Align(
      alignment: AlignmentDirectional.center,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
        child: _buildMath(context, embedContext, MathStyle.display),
      ),
    );
  }
}

/// Saisie validée du dialogue LaTeX (MIN-1) : la [source] et le mode [block]
/// (display centré) vs inline. NEUTRE (aucun type Quill/math).
@immutable
class ZLatexInput {
  /// Construit une saisie LaTeX.
  const ZLatexInput({required this.source, required this.block});

  /// Source LaTeX brute (non-blanche).
  final String source;

  /// `true` ⇒ formule en bloc (display centré, embed `latexBlock`) ; `false` ⇒
  /// inline (embed `latex`).
  final bool block;
}

/// Ouvre le dialogue de saisie/édition d'une formule LaTeX (AC3, AD-13, MIN-1).
///
/// Retourne la [ZLatexInput] saisie (source non-blanche + mode), ou `null` si
/// l'utilisateur annule (y compris OK sur une source vide/blanche). [initial]
/// pré-remplit le champ, [initialBlock] la bascule inline/bloc (édition d'un
/// embed existant). Cibles ≥ 48 dp, [Semantics] explicites, insets DIRECTIONNELS.
Future<ZLatexInput?> showZLatexDialog(
  BuildContext context, {
  String initial = '',
  bool initialBlock = false,
}) {
  return showDialog<ZLatexInput>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _ZLatexDialog(initial: initial, initialBlock: initialBlock),
  );
}

class _ZLatexDialog extends StatefulWidget {
  const _ZLatexDialog({required this.initial, required this.initialBlock});

  final String initial;
  final bool initialBlock;

  @override
  State<_ZLatexDialog> createState() => _ZLatexDialogState();
}

class _ZLatexDialogState extends State<_ZLatexDialog> {
  late final TextEditingController _text;
  late bool _block;

  /// Cible de tap minimale (AD-13).
  static const double _kMinTapTarget = 48;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initial);
    _block = widget.initialBlock;
    // Aperçu live : re-rend à chaque frappe (hors chemin chaud de l'éditeur —
    // ce dialog est éphémère, AD-2/SM-1 non concernés).
    _text.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    super.dispose();
  }

  /// Valide la saisie (AC3). Une entrée VIDE ou BLANCHE est traitée comme une
  /// ANNULATION (`pop(null)`) : on n'insère JAMAIS un embed vide (qui ne rendrait
  /// qu'un placeholder d'erreur persistant — F2).
  void _submit() {
    final String source = _text.text;
    if (source.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(ZLatexInput(source: source, block: _block));
  }

  void _cancel() => Navigator.of(context).pop();

  /// Aperçu live DÉFENSIF : formule vide → indication discrète ; formule
  /// malformée → `onErrorFallback` (jamais de throw pendant la frappe).
  Widget _preview() {
    final String source = _text.text.trim();
    final TextStyle? bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final Widget child = source.isEmpty
        ? Text(
            'Aperçu',
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall,
          )
        : Math.tex(
            source,
            mathStyle: _block ? MathStyle.display : MathStyle.text,
            textStyle: bodyStyle,
            onErrorFallback: (FlutterMathException _) => Text(
              'Aperçu indisponible',
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
    return Semantics(
      label: 'Aperçu de la formule',
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        alignment:
            _block ? AlignmentDirectional.center : AlignmentDirectional.centerStart,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final Color borderColor = ZcrudTheme.of(context).fieldBorderColor ??
        Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: Semantics(
        header: true,
        child: const Text('Formule LaTeX'),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
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
              const SizedBox(height: 8),
              // Exemples cliquables (MIN-1) — pré-remplissent le champ.
              Semantics(
                container: true,
                label: 'Exemples de formules',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final String example in kLatexExamples)
                      ActionChip(
                        key: ValueKey<String>('zlatex-example-$example'),
                        label: Text(example, textDirection: TextDirection.ltr),
                        onPressed: () {
                          _text.text = example;
                          _text.selection = TextSelection.collapsed(
                            offset: example.length,
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Bascule inline / bloc (MIN-1, parité display DODLP).
              SwitchListTile(
                key: const Key('zlatex-block-toggle'),
                contentPadding: EdgeInsetsDirectional.zero,
                title: const Text('Formule en bloc (centrée)',
                    textAlign: TextAlign.start),
                value: _block,
                onChanged: (bool v) => setState(() => _block = v),
              ),
              const SizedBox(height: 8),
              // Aperçu live.
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius:
                      BorderRadius.all(ZcrudTheme.of(context).radiusM),
                ),
                child: _preview(),
              ),
            ],
          ),
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
