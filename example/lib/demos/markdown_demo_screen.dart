import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Écran de démo MARKDOWN (EX-3, AC3). Monte un [ZMarkdownField] (E6) sur un
/// `ZFormController` **stable** (créé en `initState`, `dispose`é) portant un
/// champ `EditionFieldType.markdown`, avec :
///  - la **toolbar** riche (embeds LaTeX + tableau, boutons E6-3/E6-4) ;
///  - un **sélecteur de `ZCodec`** segmenté (Delta / Markdown) — le codec est
///    résolu 1× au montage du champ, donc un changement de codec **re-monte** le
///    champ via une `Key` (décision : paramètre `codec:` du champ, pas de
///    `ZMarkdownCodecScope`, plus explicite pour la démo) ;
///  - une zone **read-only** affichant la valeur PERSISTÉE courante
///    (`ZMarkdownField.persistedValueOf` — Delta JSON ou String Markdown selon
///    le codec), pour matérialiser l'encodage.
///
/// Ambiguïté #3 tranchée : Markdown monté DIRECTEMENT (contrôleur isolé AD-7),
/// **pas** via le `ZWidgetRegistry` (`ZFieldWidgetContext` n'expose pas de
/// `ZFormController`). Aucune parité binding ici (contrôleur isolé, AC10 : la
/// parité est optionnelle pour Markdown — non exposée, documenté).
class MarkdownDemoScreen extends StatefulWidget {
  /// Construit l'écran de démo Markdown.
  const MarkdownDemoScreen({super.key});

  @override
  State<MarkdownDemoScreen> createState() => _MarkdownDemoScreenState();
}

/// Choix de codec persisté exposé par le sélecteur (AC3).
enum _CodecChoice {
  /// Delta JSON natif Quill (`ZDeltaCodec`).
  delta('Delta', ZDeltaCodec()),

  /// Markdown round-trip défensif (`ZMarkdownCodec`).
  markdown('Markdown', ZMarkdownCodec());

  const _CodecChoice(this.label, this.codec);

  final String label;
  final ZCodec codec;
}

class _MarkdownDemoScreenState extends State<MarkdownDemoScreen> {
  /// Champ rich-text démontré (place stable `field.name`, AD-2).
  static const ZFieldSpec _field = ZFieldSpec(
    name: 'body',
    type: EditionFieldType.markdown,
    label: 'Contenu Markdown',
  );

  late final ZFormController _controller;
  _CodecChoice _codecChoice = _CodecChoice.delta;

  @override
  void initState() {
    super.initState();
    _controller = ZFormController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeCodec(_CodecChoice next) {
    if (next == _codecChoice) return;
    setState(() => _codecChoice = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Démo Markdown (E6)')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.all(12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Format persisté',
                    textAlign: TextAlign.start,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                SegmentedButton<_CodecChoice>(
                  segments: <ButtonSegment<_CodecChoice>>[
                    for (final c in _CodecChoice.values)
                      ButtonSegment<_CodecChoice>(
                        value: c,
                        label: Text(c.label),
                      ),
                  ],
                  selected: <_CodecChoice>{_codecChoice},
                  onSelectionChanged: (s) => _changeCodec(s.first),
                  showSelectedIcon: false,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
              // Le codec est résolu 1× au montage : `Key` sur le codec → re-montage
              // propre du champ au switch (stabilité E6, cf. ZMarkdownCodecScope).
              child: ZMarkdownField(
                key: ValueKey<_CodecChoice>(_codecChoice),
                controller: _controller,
                field: _field,
                codec: _codecChoice.codec,
              ),
            ),
          ),
          const Divider(height: 1),
          _PersistedValueView(
            controller: _controller,
            fieldName: _field.name,
            codec: _codecChoice.codec,
          ),
        ],
      ),
    );
  }
}

/// Zone **read-only** affichant la valeur PERSISTÉE courante de la tranche
/// (`ZMarkdownField.persistedValueOf`), n'écoutant QUE la tranche `field.name`
/// du `ZFormController` (rebuild ciblé, AD-2). Matérialise l'encodage du codec
/// choisi (Delta JSON vs String Markdown).
class _PersistedValueView extends StatelessWidget {
  const _PersistedValueView({
    required this.controller,
    required this.fieldName,
    required this.codec,
  });

  final ZFormController controller;
  final String fieldName;
  final ZCodec codec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<Object?>(
      valueListenable: controller.fieldListenable(fieldName),
      builder: (context, _, __) {
        final persisted =
            ZMarkdownField.persistedValueOf(controller, fieldName, codec: codec);
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 140),
          color: theme.colorScheme.surfaceContainerHighest,
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            child: Semantics(
              readOnly: true,
              label: 'Valeur persistée',
              child: Text(
                'Valeur persistée :\n${persisted ?? '(vide)'}',
                textAlign: TextAlign.start,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        );
      },
    );
  }
}
