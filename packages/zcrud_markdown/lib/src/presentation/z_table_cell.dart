/// Rendu d'une cellule de tableau — chemin **HYBRIDE**.
///
/// Le rendu riche passe par `ZMarkdownReader`, qui monte un `QuillEditor`
/// complet. Un par cellule sur un tableau 10×5 ferait **50 éditeurs Quill** :
/// frontalement contraire à SM-1. Le coût est donc rendu proportionnel à la
/// RICHESSE RÉELLE, pas à la taille du tableau — une cellule qui décode en un
/// seul insert sans attribut (l'immense majorité) reste un `Text`.
///
/// Le décodage a lieu dans `initState`/`didUpdateWidget`, **jamais pendant
/// `build`** (AD-2/SM-1) : reconstruire la cellule ne redécode rien.
library;

import 'package:flutter/widgets.dart';

import '../data/z_markdown_codec.dart';
import '../domain/z_codec.dart';
import 'z_markdown_codec_scope.dart';
import 'z_markdown_reader.dart';
import 'z_table_cell_scope.dart';

/// Cellule de tableau, rendue en texte brut ou en Markdown selon le
/// [ZTableCellScope] hérité.
class ZTableCell extends StatefulWidget {
  const ZTableCell({
    required this.text,
    required this.style,
    super.key,
  });

  /// Contenu BRUT de la cellule, tel qu'il est dans la charge de l'embed.
  final String text;

  /// Style hérité du contexte d'embed (chemin texte brut).
  final TextStyle style;

  @override
  State<ZTableCell> createState() => _ZTableCellState();
}

class _ZTableCellState extends State<ZTableCell> {
  /// Ops décodées, ou `null` tant que le mode est `plainText`.
  List<Map<String, dynamic>>? _ops;

  /// Vrai si le contenu décodé mérite le chemin riche.
  bool _rich = false;

  ZTableCellContent _content = ZTableCellContent.plainText;
  ZCodec? _codec;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ZTableCellScope? scope = ZTableCellScope.maybeOf(context);
    final ZTableCellContent content =
        scope?.content ?? ZTableCellContent.plainText;
    final ZCodec codec = scope?.codec ??
        ZMarkdownCodecScope.maybeOf(context) ??
        const ZMarkdownCodec();
    if (content == _content && identical(codec, _codec)) return;
    _content = content;
    _codec = codec;
    _decode();
  }

  @override
  void didUpdateWidget(ZTableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _decode();
  }

  /// Décode UNE FOIS, hors `build`. Défensif (AD-10) : un décodage qui échoue
  /// retombe sur le texte brut plutôt que de vider la cellule.
  void _decode() {
    if (_content != ZTableCellContent.markdown) {
      _ops = null;
      _rich = false;
      return;
    }
    List<Map<String, dynamic>> ops;
    try {
      ops = _codec!.decode(widget.text);
    } on Object {
      _ops = null;
      _rich = false;
      return;
    }
    _ops = ops;
    _rich = _needsRichRendering(ops, widget.text);
  }

  /// Le chemin riche est-il nécessaire ?
  ///
  /// NON si le contenu décodé est un texte NU — aucun attribut, aucun embed, et
  /// le texte reconstitué est identique à la source. Dans ce cas `Text` rend
  /// exactement la même chose pour une fraction du coût.
  ///
  /// La comparaison au texte SOURCE est indispensable : `- a` décode en un seul
  /// insert `a` sans attribut sur l'op de texte — l'attribut de liste est porté
  /// par le saut de ligne. Sans cette comparaison, une puce serait rendue « a »,
  /// c'est-à-dire un contenu FAUX plutôt qu'un contenu brut.
  static bool _needsRichRendering(
    List<Map<String, dynamic>> ops,
    String source,
  ) {
    final buffer = StringBuffer();
    for (final Map<String, dynamic> op in ops) {
      final Object? insert = op['insert'];
      if (insert is! String) return true; // embed
      final Object? attrs = op['attributes'];
      if (attrs is Map && attrs.isNotEmpty) return true;
      buffer.write(insert);
    }
    return buffer.toString().trimRight() != source.trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>>? ops = _ops;
    if (!_rich || ops == null || ops.isEmpty) {
      return Text(widget.text, style: widget.style, textAlign: TextAlign.start);
    }
    return ZMarkdownReader(value: ops, placeholder: '');
  }
}
