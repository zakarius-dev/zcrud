/// `ZAutocompleteFieldWidget` — champ **texte auto-complété** (fp-5-2, FR-35)
/// servi via `ZWidgetRegistry` sous le `kind` [autocompleteFieldKind] (aligné sur
/// `EditionFieldType.autocomplete.name`).
///
/// 🔴 **Zéro dépendance lourde (AC-B3)** : implémenté avec le widget **natif
/// Flutter `Autocomplete<String>`** — l'étude REJETTE `autocomplete_textfield`
/// (non-portable) et confirme que DODLP utilise `Autocomplete` natif. Aucune
/// arête ajoutée au graph_proof (CORE OUT=0 préservé).
///
/// **Dispatch cœur** : `EditionFieldType.autocomplete` → famille
/// `registryOrFallback` → `registry.tryBuilderFor('autocomplete')`. Repli
/// `ZUnsupportedFieldWidget` tant que non enregistré (AD-10).
///
/// **AD-2 / SM-1** : value-in-slice — lit `ctx.value` (`String`), écrit via
/// `ctx.onChanged`. Le `TextEditingController`/`FocusNode` sont détenus par
/// l'état (alloués **une seule fois** en `initState`, jamais recréés au rebuild
/// — aucune perte de focus) et fournis à `RawAutocomplete`. Une **ré-injection
/// externe** de `ctx.value` (reset / rechargement d'entité) est re-synchronisée
/// via [didUpdateWidget] (patron mirroir du PIN) — `initialValue` ne s'appliquant
/// qu'à la création, il ne suffisait pas (LOW fp-5-2). Un champ voisin qui change
/// ne reconstruit pas ce champ.
///
/// **AD-13 / FR-26** : champ texte ≥ 48 dp, options **directionnelles** (RTL),
/// `Semantics` **sans double annonce** (`excludeSemantics: true` sur l'option —
/// le label du bouton suffit, le `Text` enfant ne ré-émet pas de nœud), thème
/// injecté (`ZcrudTheme`/`Theme.of`).
///
/// **AD-10** : valeur externe non-`String`/`null`/corrompue ⇒ champ vide, jamais
/// un crash.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// `kind` du champ **autocomplétion**, ALIGNÉ sur
/// `EditionFieldType.autocomplete.name == 'autocomplete'`.
final String autocompleteFieldKind = EditionFieldType.autocomplete.name;

/// Champ auto-complété (value-in-slice, `RawAutocomplete` natif Flutter).
class ZAutocompleteFieldWidget extends StatefulWidget {
  /// Construit le champ auto-complété pour [ctx].
  const ZAutocompleteFieldWidget({required this.ctx, this.onBuild, super.key});

  /// Contexte du champ (`ctx.value` = `String`, `ctx.onChanged` = écriture).
  final ZFieldWidgetContext ctx;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous [autocompleteFieldKind].
  static ZFieldWidgetBuilder builder({VoidCallback? onBuild}) =>
      (BuildContext context, ZFieldWidgetContext ctx) =>
          ZAutocompleteFieldWidget(ctx: ctx, onBuild: onBuild);

  @override
  State<ZAutocompleteFieldWidget> createState() =>
      _ZAutocompleteFieldWidgetState();
}

class _ZAutocompleteFieldWidgetState extends State<ZAutocompleteFieldWidget> {
  /// Contrôleur/focus alloués **une seule fois** (AD-2) — jamais recréés.
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Valeur `String` défensive de la tranche (AD-10).
  String get _sliceValue {
    final v = widget.ctx.value;
    return v is String ? v : '';
  }

  /// Options **stables** dérivées de `field.choices` (libellés). Dé-dupliquées,
  /// ordre préservé.
  List<String> get _options {
    final seen = <String>{};
    final out = <String>[];
    for (final c in widget.ctx.field.choices) {
      if (seen.add(c.label)) out.add(c.label);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _sliceValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ZAutocompleteFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ré-injection externe : aligner le texte affiché sur la tranche SANS écraser
    // la sélection (n'écrit que si le texte diffère réellement — jamais à chaque
    // frappe). Mirroir du patron PIN.
    final slice = _sliceValue;
    if (_controller.text != slice) {
      _controller.value = TextEditingValue(
        text: slice,
        selection: TextSelection.collapsed(offset: slice.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final options = _options;

    return Padding(
      padding: theme.fieldPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(resolvedLabel, style: TextStyle(color: theme.labelColor)),
          SizedBox(height: theme.gapS),
          RawAutocomplete<String>(
            key: const Key('z-autocomplete'),
            textEditingController: _controller,
            focusNode: _focusNode,
            optionsBuilder: (TextEditingValue value) {
              final q = value.text.trim().toLowerCase();
              if (q.isEmpty) return options;
              return options.where(
                (o) => o.toLowerCase().contains(q),
              );
            },
            onSelected: widget.ctx.onChanged,
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
              return TextField(
                controller: textController,
                focusNode: focusNode,
                enabled: !field.readOnly,
                textDirection: Directionality.of(context),
                decoration: theme.inputDecoration(
                  context,
                  hintText: field.hintText,
                ),
                onChanged: widget.ctx.onChanged,
                onSubmitted: (_) => onFieldSubmitted(),
              );
            },
            optionsViewBuilder: (context, onSelected, iterable) {
              final opts = iterable.toList(growable: false);
              return Align(
                alignment: AlignmentDirectional.topStart,
                child: Material(
                  elevation: 2,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.builder(
                      key: const Key('z-autocomplete-options'),
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: opts.length,
                      itemBuilder: (context, i) {
                        final option = opts[i];
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Semantics(
                            button: true,
                            label: option,
                            // Le label du bouton porte déjà l'option ; on exclut
                            // la sémantique du Text enfant pour éviter la DOUBLE
                            // annonce (« Apple Apple ») — MED-3 fp-5-2.
                            excludeSemantics: true,
                            child: Container(
                              constraints:
                                  const BoxConstraints(minHeight: 48),
                              alignment: AlignmentDirectional.centerStart,
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(option, textAlign: TextAlign.start),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
