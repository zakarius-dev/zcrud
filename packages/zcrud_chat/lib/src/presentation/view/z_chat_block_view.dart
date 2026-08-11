/// Rendu neutre, zéro dépendance, d'un `ZContentBlock`.
///
/// ## L'ordre de résolution, et pourquoi il est dans ce widget
///
/// Seam de l'hôte (`zResolveChatBlock`) d'abord, rendu neutre ensuite. Le
/// seam est interrogé bloc par bloc, jamais message par message : c'est ce
/// qui permet à un hôte de rendre son `kind` personnalisé sans réimplémenter
/// les variantes fermées du kernel, et c'est ce qui rend la neutralité
/// vérifiable — un renderer qui décline tout laisse un arbre strictement
/// identique à l'absence de renderer.
///
/// ## Ce que ce fichier ne fait pas, volontairement
///
/// Il ne rend ni Markdown, ni LaTeX, ni diagramme. Un rendu riche de ce type
/// tire typiquement un éditeur riche complet, et l'invariant AD-1 interdit
/// d'imposer ce poids à tout consommateur du chat. Le rendu riche n'est donc
/// pas réécrit ici : il est atteignable par [ZChatRenderer], et le défaut se
/// contente d'un rendu fonctionnel mais dégradé (le texte source, lisible et
/// sélectionnable), jamais absent — la définition même d'un défaut
/// zéro-dépendance.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../render/z_chat_render_request.dart';
import '../render/z_chat_renderer_scope.dart';
import 'z_chat_labels.dart';

/// Rend un bloc : seam de l'hôte d'abord, rendu neutre ensuite.
class ZChatBlockView extends StatelessWidget {
  /// Construit la vue d'un bloc.
  const ZChatBlockView({required this.request, super.key});

  /// La requête neutre décrivant le bloc à rendre.
  final ZChatBlockRenderRequest request;

  @override
  Widget build(BuildContext context) {
    // Chaîne totale : `null` signifie rendu neutre — y compris quand le
    // renderer de l'hôte lève (invariant AD-10 ; l'exception est relayée à
    // `FlutterError`, cf. `zResolveChatBlock`).
    final Widget? fromHost = zResolveChatBlock(context, request);
    if (fromHost != null) return fromHost;
    return _ZNeutralBlock(request: request);
  }
}

/// Le rendu neutre proprement dit — séparé pour que la garde de neutralité
/// puisse l'identifier dans l'arbre sans dépendre du seam.
class _ZNeutralBlock extends StatelessWidget {
  const _ZNeutralBlock({required this.request});

  final ZChatBlockRenderRequest request;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZContentBlock block = request.block;
    // Le texte en cours de rédaction traverse la couture. Le rendu neutre
    // prend l'abonnement ici, au plus près du `Text` : un jeton ne
    // reconstruit que ce `builder`, ni la tuile, ni la liste (invariant AD-2).
    final ValueListenable<String>? live = request.streamingText;
    if (live != null && block is ZTextBlock) {
      return ValueListenableBuilder<String>(
        valueListenable: live,
        builder: (BuildContext context, String value, Widget? child) =>
            _text(context, value),
      );
    }
    // `switch` EXHAUSTIF sur une union scellée : ajouter une variante au kernel
    // casse la COMPILATION ici plutôt que de rendre du vide silencieux.
    return switch (block) {
      ZTextBlock() => _text(context, block.text),
      ZTableBlock() => _ZNeutralTable(
        title: block.title,
        headers: block.headers,
        rows: block.rows,
        theme: theme,
      ),
      ZKeyDefinitionBlock() => _ZNeutralStack(
        theme: theme,
        children: <Widget>[
          _strong(context, block.term),
          _text(context, block.definition),
          if (block.source != null) _text(context, block.source!),
        ],
      ),
      ZComparisonTableBlock() => _ZNeutralTable(
        title: block.title,
        headers: <String>[
          for (final ZComparisonColumn c in block.columns) c.header,
        ],
        rows: _transpose(block.columns),
        theme: theme,
      ),
      ZTimelineBlock() => _ZNeutralStack(
        theme: theme,
        children: <Widget>[
          if (block.title != null) _strong(context, block.title!),
          for (final ZTimelineEvent e in block.events)
            _ZNeutralStack(
              theme: theme,
              children: <Widget>[
                _strong(context, '${e.date} — ${e.title}'),
                if (e.description != null) _text(context, e.description!),
              ],
            ),
        ],
      ),
      ZAlertBlock() => Semantics(
        // Le NIVEAU est une donnée de l'hôte (`String` ouverte), pas un libellé
        // du socle : il est annoncé tel quel, jamais traduit ni colorisé selon
        // une table que le socle inventerait.
        label: block.level,
        child: _ZNeutralBox(
          theme: theme,
          children: <Widget>[
            if (block.title != null) _strong(context, block.title!),
            _text(context, block.message),
          ],
        ),
      ),
      ZMermaidDiagramBlock() => _ZNeutralBox(
        theme: theme,
        children: <Widget>[
          _strong(context, zChatLabel(context, kZChatLabelDiagram)),
          if (block.title != null) _text(context, block.title!),
          // Code source **non interprété** : le rendu graphique est le rôle
          // d'un renderer injecté, pas du défaut zéro-dépendance.
          _text(context, block.code),
        ],
      ),
      ZSourcesBlock() => _ZNeutralStack(
        theme: theme,
        children: <Widget>[
          _strong(context, zChatLabel(context, kZChatLabelSources)),
          for (final ZChatSource s in block.sources)
            _text(context, _sourceLine(s)),
        ],
      ),
      ZSuggestionsBlock() => _ZNeutralStack(
        theme: theme,
        children: <Widget>[
          _strong(context, zChatLabel(context, kZChatLabelSuggestions)),
          for (final ZChatSuggestion s in block.suggestions)
            _text(context, s.content),
        ],
      ),
      // Un `kind` inconnu n'est pas transformé en texte brut affiché : le
      // kernel a délibérément préservé son payload verbatim, et le dumper à
      // l'écran perdrait cette distinction. Le socle signale sa présence —
      // l'hôte le rend via `ZChatRenderer`.
      ZCustomContentBlock() => Semantics(
        label: zChatLabel(context, kZChatLabelUnsupportedBlock),
        child: _text(context, block.kind),
      ),
    };
  }

  /// Colonnes → lignes. Une colonne plus courte que la plus longue est
  /// complétée par des cellules vides : une comparaison déséquilibrée reste
  /// affichable (invariant AD-10), elle ne fait pas planter le tableau.
  static List<List<String>> _transpose(List<ZComparisonColumn> columns) {
    int height = 0;
    for (final ZComparisonColumn c in columns) {
      if (c.values.length > height) height = c.values.length;
    }
    return <List<String>>[
      for (int r = 0; r < height; r++)
        <String>[
          for (final ZComparisonColumn c in columns)
            r < c.values.length ? c.values[r] : '',
        ],
    ];
  }

  /// Un renvoi de source lisible : le texte d'affichage porté par la donnée, à
  /// défaut son type. Aucun libellé du socle n'est fabriqué ici.
  static String _sourceLine(ZChatSource source) =>
      source.displayText.isEmpty ? source.sourceType : source.displayText;

  static Widget _text(BuildContext context, String value) =>
      Text(value, textAlign: TextAlign.start);

  /// Emphase **sans style codé en dur** : la graisse est dérivée du style
  /// courant (`DefaultTextStyle`), jamais d'un `TextStyle(...)` littéral.
  static Widget _strong(BuildContext context, String value) => Text(
    value,
    textAlign: TextAlign.start,
    style: DefaultTextStyle.of(
      context,
    ).style.copyWith(fontWeight: FontWeight.w600),
  );
}

/// Empilement vertical espacé par le token `gapS` du thème injecté.
class _ZNeutralStack extends StatelessWidget {
  const _ZNeutralStack({required this.theme, required this.children});

  final ZcrudTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: theme.gapS),
          children[i],
        ],
      ],
    );
  }
}

/// Encadré neutre : bordure et rayon issus du thème injecté, aucune couleur
/// littérale.
class _ZNeutralBox extends StatelessWidget {
  const _ZNeutralBox({required this.theme, required this.children});

  final ZcrudTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Aucune couleur de repli littérale : si le thème injecté ne fournit
    // pas de couleur de bordure, l'encadré n'en dessine pas — plutôt que
    // d'inventer un noir ou un transparent codés en dur. Le contenu reste
    // rendu dans tous les cas.
    final Color? border = theme.fieldBorderColor;
    return Container(
      padding: theme.fieldPadding,
      decoration: BoxDecoration(
        border: border == null
            ? null
            : Border.fromBorderSide(BorderSide(color: border)),
        borderRadius: BorderRadius.all(theme.radiusM),
      ),
      child: _ZNeutralStack(theme: theme, children: children),
    );
  }
}

/// Tableau neutre bâti sur le `Table` du SDK — aucune grille tierce.
class _ZNeutralTable extends StatelessWidget {
  const _ZNeutralTable({
    required this.title,
    required this.headers,
    required this.rows,
    required this.theme,
  });

  final String? title;
  final List<String> headers;
  final List<List<String>> rows;
  final ZcrudTheme theme;

  @override
  Widget build(BuildContext context) {
    final Color? borderColor = theme.fieldBorderColor;
    final int width = _width();
    if (width == 0) {
      return title == null
          ? const SizedBox.shrink()
          : _ZNeutralBlock._strong(context, title!);
    }
    return _ZNeutralStack(
      theme: theme,
      children: <Widget>[
        if (title != null) _ZNeutralBlock._strong(context, title!),
        Table(
          // Invariant AD-13 : la direction du tableau suit celle du texte —
          // un tableau figé en LTR est illisible en RTL.
          textDirection: Directionality.of(context),
          border: borderColor == null
              ? null
              : TableBorder.all(color: borderColor),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: <TableRow>[
            if (headers.isNotEmpty)
              TableRow(
                children: <Widget>[
                  for (int c = 0; c < width; c++)
                    Padding(
                      padding: theme.fieldPadding,
                      child: _ZNeutralBlock._strong(
                        context,
                        c < headers.length ? headers[c] : '',
                      ),
                    ),
                ],
              ),
            for (final List<String> row in rows)
              TableRow(
                children: <Widget>[
                  for (int c = 0; c < width; c++)
                    Padding(
                      padding: theme.fieldPadding,
                      child: _ZNeutralBlock._text(
                        context,
                        c < row.length ? row[c] : '',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// Largeur = la plus grande des largeurs observées. `Table` exige des
  /// lignes de même longueur : une donnée irrégulière (fréquente en sortie de
  /// modèle génératif) ferait autrement lever une assertion du SDK au lieu de
  /// s'afficher dégradée (invariant AD-10).
  int _width() {
    int w = headers.length;
    for (final List<String> r in rows) {
      if (r.length > w) w = r.length;
    }
    return w;
  }
}
