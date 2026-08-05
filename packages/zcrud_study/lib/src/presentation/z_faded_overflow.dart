/// `ZFadedOverflow` — **borne de hauteur qui SIGNALE la coupure**
/// (**CR-IFFD-62 ③**).
///
/// ## Le grief, et pourquoi une ellipse ne suffisait pas
///
/// L'énoncé d'une carte de flashcard est borné en hauteur (legacy
/// `kToolbarHeight × 0.65`) et **absorbé** par un défileur inerte : le texte
/// est donc coupé **en plein milieu d'une ligne**, sans qu'aucun signe ne dise
/// qu'il continue. Le grief est fondé — *absorber n'est pas signaler*.
///
/// 🔴 **`TextOverflow.ellipsis` n'est PAS atteignable sur ce contenu**, et
/// c'est structurel, pas un manque de volonté : le rendu par défaut de
/// l'énoncé est **RICHE** (`ZFlashcardMarkdownContent` → Quill), c'est-à-dire
/// une **colonne de blocs** (paragraphes, listes, blocs de code), pas un
/// `RenderParagraph`. `TextOverflow` est une propriété de *paragraphe* : elle
/// n'a aucune prise sur un empilement de blocs, et il n'existe pas de « dernier
/// paragraphe visible » connu avant le layout. La coupure se produit **entre
/// blocs ou dans un bloc**, à un endroit que seul le layout connaît.
///
/// ⇒ Le signal livré ici est donc un **FONDU de continuation** : les dernières
/// [ZFadedOverflow.fadeExtent] dp du contenu s'effacent progressivement quand —
/// et **seulement quand** — le contenu déborde réellement. C'est le signal
/// visuel standard pour un contenu tronqué non textuel.
///
/// ♿ **Le fondu n'est pas le seul canal** (AD-13) : le texte INTÉGRAL de
/// l'énoncé reste porté par le `label` sémantique de la carte
/// (`ZStudyToolsItemCard.semanticLabel`, repli `title`) — un lecteur d'écran
/// n'entend donc AUCUNE troncature. Le fondu est un indice visuel qui s'ajoute
/// à une information déjà complète, jamais une information qui se perd.
///
/// ## Ce que le widget garantit
///
/// * **hauteur** : `min(hauteur naturelle du contenu, maxHeight reçu)` —
///   exactement ce que faisait le `SingleChildScrollView` inerte qu'il
///   remplace (il **shrink-wrappe** son enfant) ; aucun changement de layout ;
/// * **fondu conditionnel** : peint **uniquement** si le contenu dépasse, et
///   mesuré sur la hauteur RÉELLE de l'enfant (jamais une supposition) ;
/// * **écrêtage** : le débordement est toujours clippé, jamais peint dehors ;
/// * **aucune couleur** (FR-26) : le masque n'utilise que le canal ALPHA
///   (`BlendMode.dstIn`) — ses deux bornes sont DÉRIVÉES d'une couleur du
///   thème passée par l'appelant, elles ne peignent aucune matière.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Étendue par défaut du fondu de continuation (dp).
const double kZFadedOverflowExtent = 12;

/// Borne en hauteur son [child] et **signale** la coupure par un fondu bas
/// quand le contenu déborde réellement (**CR-IFFD-62 ③**).
class ZFadedOverflow extends SingleChildRenderObjectWidget {
  /// Construit la borne. [opaque] et [clear] sont les deux bornes du masque
  /// (seul leur **alpha** compte : opaque = contenu intact, clear = effacé).
  const ZFadedOverflow({
    required this.opaque,
    required this.clear,
    required Widget super.child,
    this.fadeExtent = kZFadedOverflowExtent,
    super.key,
  });

  /// Hauteur du fondu de continuation. `0` (ou moins) ⇒ aucun fondu : le
  /// contenu est simplement écrêté (repli AD-10, jamais une contrainte
  /// invalide).
  final double fadeExtent;

  /// Borne OPAQUE du masque (alpha plein) — DÉRIVÉE d'une couleur de thème.
  final Color opaque;

  /// Borne EFFACÉE du masque (alpha nul) — DÉRIVÉE de la même couleur.
  final Color clear;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      ZRenderFadedOverflow(
        fadeExtent: fadeExtent,
        opaque: opaque,
        clear: clear,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    ZRenderFadedOverflow renderObject,
  ) {
    renderObject
      ..fadeExtent = fadeExtent
      ..opaque = opaque
      ..clear = clear;
  }
}

/// Rendu de [ZFadedOverflow] — expose [isTruncated], **mesuré** au layout.
class ZRenderFadedOverflow extends RenderProxyBox {
  /// Construit le rendu.
  ZRenderFadedOverflow({
    required double fadeExtent,
    required Color opaque,
    required Color clear,
  })  : _fadeExtent = fadeExtent,
        _opaque = opaque,
        _clear = clear;

  double _fadeExtent;

  /// Hauteur du fondu.
  double get fadeExtent => _fadeExtent;
  set fadeExtent(double value) {
    if (_fadeExtent == value) return;
    _fadeExtent = value;
    markNeedsPaint();
  }

  Color _opaque;

  /// Borne opaque du masque.
  Color get opaque => _opaque;
  set opaque(Color value) {
    if (_opaque == value) return;
    _opaque = value;
    markNeedsPaint();
  }

  Color _clear;

  /// Borne effacée du masque.
  Color get clear => _clear;
  set clear(Color value) {
    if (_clear == value) return;
    _clear = value;
    markNeedsPaint();
  }

  bool _truncated = false;

  /// `true` si le contenu DÉPASSE réellement la borne reçue — donc si le fondu
  /// est peint. Mesuré sur la hauteur de l'enfant, jamais déclaré.
  bool get isTruncated => _truncated;

  // Le fondu exige une couche de composition (`ShaderMaskLayer`) ; il ne la
  // demande QUE lorsqu'il peint réellement — un contenu qui tient garde le
  // chemin de peinture direct (aucun coût de couche par carte).
  @override
  bool get alwaysNeedsCompositing => _truncated;

  BoxConstraints _childConstraints(BoxConstraints constraints) => BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
        // Le contenu est mesuré LIBREMENT en hauteur : c'est cette mesure qui
        // dit s'il déborde (le clipper d'abord la rendrait indétectable).
        maxHeight: double.infinity,
      );

  @override
  void performLayout() {
    final RenderBox? c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(c.size);
    final bool truncated = c.size.height > size.height + precisionErrorTolerance;
    if (truncated != _truncated) {
      _truncated = truncated;
      // La présence de la couche change : le bit de composition doit être
      // recalculé (il l'est APRÈS la passe de layout, `flushCompositingBits`).
      markNeedsCompositingBitsUpdate();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? c = child;
    if (c == null) return constraints.smallest;
    return constraints.constrain(c.getDryLayout(_childConstraints(constraints)));
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();
  final LayerHandle<ShaderMaskLayer> _maskLayer = LayerHandle<ShaderMaskLayer>();

  @override
  void dispose() {
    _clipLayer.layer = null;
    _maskLayer.layer = null;
    super.dispose();
  }

  Shader _shader(Size box) {
    final double extent = _fadeExtent <= 0
        ? 0
        : (_fadeExtent >= box.height ? box.height : _fadeExtent);
    final double start =
        box.height <= 0 ? 0.0 : (box.height - extent) / box.height;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[_opaque, _opaque, _clear],
      stops: <double>[0, start, 1],
    ).createShader(Offset.zero & box);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? c = child;
    if (c == null) return;
    if (!_truncated) {
      // Contenu qui TIENT : peinture directe, aucun écrêtage, aucune couche —
      // rendu strictement identique à l'absence de ce widget.
      _clipLayer.layer = null;
      _maskLayer.layer = null;
      context.paintChild(c, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      true,
      offset,
      Offset.zero & size,
      (PaintingContext inner, Offset innerOffset) {
        if (_fadeExtent <= 0) {
          inner.paintChild(c, innerOffset);
          return;
        }
        final ShaderMaskLayer layer = _maskLayer.layer ?? ShaderMaskLayer();
        layer
          ..shader = _shader(size)
          ..maskRect = innerOffset & size
          // dstIn : SEUL l'alpha du masque compte — aucune matière ajoutée.
          ..blendMode = BlendMode.dstIn;
        _maskLayer.layer = layer;
        inner.pushLayer(
          layer,
          (PaintingContext ctx, Offset off) => ctx.paintChild(c, off),
          innerOffset,
        );
      },
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('isTruncated',
        value: _truncated, ifTrue: 'contenu TRONQUÉ (fondu peint)'));
    properties.add(DoubleProperty('fadeExtent', _fadeExtent));
  }
}
