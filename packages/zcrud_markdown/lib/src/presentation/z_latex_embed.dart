/// Embed **LaTeX** (+) de `zcrud_markdown` : embeds Quill CUSTOM
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
/// RÉTRO-COMPAT : le type `latex` (inline, `MathStyle.text`) est
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

import 'z_rich_text_style_set.dart';

/// Clé/type Delta de l'embed LaTeX **inline** — op `{"insert": {"latex": "<src>"}}`.
///
/// C'est aussi le `type` capté GÉNÉRIQUEMENT par `DeltaNeutralOps._embedPlaceholder`
/// (1re clé de la `Map` `insert`) → `ZMarkdownCodec` produit `[embed:latex]` SANS
/// modification (cohérence, perte bornée).
const String kLatexEmbedType = 'latex';

/// Clé/type Delta de l'embed LaTeX **bloc/display** — op
/// `{"insert": {"latexBlock": "<src>"}}`. ADDITIF : ne remplace jamais `latex`.
const String kLatexBlockEmbedType = 'latexBlock';

/// Clé Delta de l'embed formule **LEGACY bloc/display** — op
/// `{"insert": {"formula": "<latex nu>"}}`.
///
/// Forme legacy MESURÉE : la clé est
/// `formula`, la charge une **`String` LaTeX nue** (même forme que la nôtre —
/// seul le NOM de clé diverge), rendue `MathStyle.display`, `expanded == false`.
/// zcrud la RECONNAÎT EN LECTURE (rendu + pré-remplissage d'édition) ; toute
/// ÉCRITURE reste sur [kLatexEmbedType]/[kLatexBlockEmbedType] — migration à
/// SENS UNIQUE (le legacy ne relit pas le contenu réécrit par zcrud).
const String kLegacyFormulaEmbedType = 'formula';

/// Clé Delta de l'embed formule **LEGACY inline** — op
/// `{"insert": {"formula_inline": "<latex nu>"}}` (rendu `MathStyle.text`).
/// Même contrat de lecture seule que
/// [kLegacyFormulaEmbedType].
const String kLegacyFormulaInlineEmbedType = 'formula_inline';

/// Libellé a11y (AD-13) du placeholder d'erreur — lisible par lecteur d'écran.
@visibleForTesting
const String kLatexInvalidLabel = 'formule invalide';

/// Exemples de formules proposés dans le dialogue — aucun texte codé en
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
/// à l'identique via `ZDeltaCodec`).
class ZLatexEmbed extends Embeddable {
  /// Construit l'embed LaTeX inline portant la [source] (chaîne LaTeX brute).
  const ZLatexEmbed(String source) : super(kLatexEmbedType, source);
}

/// Embed Quill CUSTOM **bloc/display** de type `latexBlock` (`MathStyle.display`,
/// rendu centré). : parité legacy `FormulaBlockEmbed`.
class ZLatexBlockEmbed extends Embeddable {
  /// Construit l'embed LaTeX bloc portant la [source] (chaîne LaTeX brute).
  const ZLatexBlockEmbed(String source) : super(kLatexBlockEmbedType, source);
}

/// Placeholder d'erreur INLINE thémé (AD-13) : icône `error_outline`
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

/// `InheritedWidget` INTERNE fournissant la [ZRichTextFormulaSpec] par champ
/// aux builders de formule — qui sont `const` et
/// PARTAGÉS ([kZEmbedBuilders]) : la personnalisation PAR CHAMP ne peut donc
/// passer que par le contexte, jamais par le builder.
///
/// ABSENT ⇒ rendu historique STRICTEMENT inchangé (AD-57). Posé par
/// `ZMarkdownField`/`ZMarkdownReader`/le dialog plein-écran quand l'hôte
/// fournit une spec.
class ZFormulaSpecScope extends InheritedWidget {
  /// Fournit [spec] au sous-arbre [child].
  const ZFormulaSpecScope({required this.spec, required super.child, super.key});

  /// Spec de rendu des formules du champ courant.
  final ZRichTextFormulaSpec spec;

  /// Spec ambiante, ou `null` (⇒ rendu historique).
  static ZRichTextFormulaSpec? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ZFormulaSpecScope>()
      ?.spec;

  @override
  bool updateShouldNotify(ZFormulaSpecScope oldWidget) => spec != oldWidget.spec;
}

/// Rendu DÉFENSIF (AD-10) commun d'une formule LaTeX avec un [mathStyle] donné.
/// Donnée absente / non-`String` / vide → placeholder ; formule malformée →
/// `onErrorFallback` (jamais de throw).
///
/// honore la [ZRichTextFormulaSpec] ambiante ([ZFormulaSpecScope]) —
/// `textStyle` remplace le style du point d'insertion ; le facteur d'échelle
/// (`blockScaleFactor` pour `MathStyle.display`, `inlineScaleFactor` sinon)
/// multiplie la taille de police EFFECTIVE (repli défensif 14 si aucune taille
/// n'est résoluble — jamais de throw). Scope absent ⇒ rendu historique.
Widget _buildMath(
  BuildContext context,
  EmbedContext embedContext,
  MathStyle mathStyle,
) {
  final Object? data = embedContext.node.value.data;
  if (data is! String || data.trim().isEmpty) {
    return _latexErrorPlaceholder(context);
  }
  final ZRichTextFormulaSpec? spec = ZFormulaSpecScope.maybeOf(context);
  TextStyle style = spec?.textStyle ?? embedContext.textStyle;
  final double? factor = mathStyle == MathStyle.display
      ? spec?.blockScaleFactor
      : spec?.inlineScaleFactor;
  if (factor != null) {
    final double size = style.fontSize ??
        DefaultTextStyle.of(context).style.fontSize ??
        14;
    style = style.copyWith(fontSize: size * factor);
  }
  return Math.tex(
    data,
    mathStyle: mathStyle,
    textStyle: style,
    onErrorFallback: (FlutterMathException _) => _latexErrorPlaceholder(context),
  );
}

/// `EmbedBuilder` de rendu DÉFENSIF (AD-10) de l'embed `latex` **inline** via
/// `flutter_math_fork` (`MathStyle.text`).
///
/// `expanded == false` : la formule est rendue **inline** (dans le flux du
/// paragraphe) via `buildWidgetSpan`. Sans état ⇒ instance `const` STABLE
/// (AD-2 : aucune allocation par (re)build de tranche).
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
/// [Center] directionnel (parité legacy `_CenteredMathWidget`). Sans état ⇒
/// instance `const` STABLE (AD-2).
///
/// Une formule plus large que la place disponible **défile horizontalement**
/// au lieu de déborder : le début reste visible, la fin est atteignable par
/// défilement (glisser, molette, clavier — aucun geste exclusif, AD-13). Une
/// formule qui tient garde son rendu centré inchangé.
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
        // Le geste de l'aperçu du dialogue, appliqué au lecteur : `Math.tex`
        // ne se replie pas et débordait (`RIGHT OVERFLOWED`), la fin de la
        // formule perdue. Le viewport borne la largeur et rend la fin
        // atteignable. Contraintes NON bornées (cellule de tableau en
        // `IntrinsicColumnWidth`) : le viewport se dimensionne alors à la
        // formule — aucune exception de layout, la colonne s'élargit.
        // La sémantique de la formule est celle du child (le viewport
        // n'introduit aucun nœud qui la masque).
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildMath(context, embedContext, MathStyle.display),
        ),
      ),
    );
  }
}

/// `EmbedBuilder` de LECTURE de l'embed **legacy `formula`** : rendu
/// DÉFENSIF (AD-10) `MathStyle.display` via le MÊME [_buildMath] que nos
/// builders. `expanded == false` : parité EXACTE avec le legacy
/// (`FormulaEmbedBuilder.expanded => false`, la formule vit dans le flux du
/// paragraphe). LECTURE SEULE : rien dans zcrud n'ÉCRIT jamais cette clé.
class ZLegacyFormulaEmbedBuilder extends EmbedBuilder {
  /// Builder `const` (sans état).
  const ZLegacyFormulaEmbedBuilder();

  @override
  String get key => kLegacyFormulaEmbedType;

  /// Parité legacy : inline dans le flux (jamais bloc), style display.
  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) =>
      _buildMath(context, embedContext, MathStyle.display);
}

/// `EmbedBuilder` de LECTURE de l'embed **legacy `formula_inline`** :
/// rendu DÉFENSIF (AD-10) `MathStyle.text`, `expanded == false` (parité
/// `FormulaInlineEmbedBuilder`). LECTURE SEULE (cf. [kLegacyFormulaEmbedType]).
class ZLegacyFormulaInlineEmbedBuilder extends EmbedBuilder {
  /// Builder `const` (sans état).
  const ZLegacyFormulaInlineEmbedBuilder();

  @override
  String get key => kLegacyFormulaInlineEmbedType;

  /// Rendu INLINE (parité legacy).
  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) =>
      _buildMath(context, embedContext, MathStyle.text);
}

/// Saisie validée du dialogue LaTeX : la [source] et le mode [block]
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

/// Ouvre le dialogue de saisie/édition d'une formule LaTeX (AD-13).
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
    // ce dialog est éphémère, AD-2/ non concernés).
    _text.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    super.dispose();
  }

  /// Valide la saisie. Une entrée VIDE ou BLANCHE est traitée comme une
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
              // Exemples cliquables — pré-remplissent le champ.
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
              // Bascule inline bloc (parité display l'éditeur historique).
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
