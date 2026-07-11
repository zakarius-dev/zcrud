/// Widget de la **famille signature** (`signature`) — E3-3b-3.
///
/// Capture de signature **gestuelle** rendue avec un `GestureDetector` +
/// `CustomPaint` **Flutter natif** — AUCUNE dépendance lourde (pas de package
/// `signature` externe ; graphe `zcrud_core` OUT=0 inchangé, AD-1/AD-15).
///
/// ## Encodage en tranche (format STABLE documenté — AD-3/AD-10)
///
/// La valeur du champ = les **strokes** (tracés) encodés en `Map` VERSIONNÉE,
/// **sérialisable** et **résolution-indépendante** — jamais de bytes image
/// lourds :
///
/// ```jsonc
/// {
///   "formatVersion": 1,
///   "strokes": [
///     [x0, y0, x1, y1, ...],   // 1 stroke = liste PLATE de points (x,y)
///     [x0, y0, ...]            // coordonnées NORMALISÉES dans [0,1]
///   ]
/// }
/// ```
///
/// Les coordonnées sont **normalisées** `[0,1]` relativement à la boîte de
/// capture → indépendantes de la taille/densité d'écran, stables à la
/// (dé)sérialisation. Champ **vide/effacé** ⇒ valeur `null` (jamais `{}`).
/// Lecture **défensive** (AD-10) : `value` absent/mal typé ⇒ aucun stroke,
/// jamais de throw.
///
/// ## Réactivité (AD-2)
///
/// Value-in-slice : le tracé courant vit dans le `State` local (source de vérité
/// pendant le geste, amorcé **une fois** depuis `initialValue`) et est **agrégé**
/// vers la tranche parente via `onChanged` à la **fin** de chaque trait / sur
/// `clear`/`undo` — hors de la voie de rebuild du geste. Le widget est rendu
/// **sous** l'unique `ZFieldListenableBuilder` du dispatcher : écrire la tranche
/// ne reconstruit que ce champ.
///
/// ## a11y / RTL (AD-13)
///
/// - `Semantics(container, label: « zone de signature », value: signé/vide)` :
///   alternative NON gestuelle = le label décrit la zone et son état (une
///   personne non-voyante sait qu'un champ signature existe et s'il est rempli).
/// - Boutons **effacer**/**annuler** = `IconButton` (cible ≥ 48 dp garantie) avec
///   tooltip l10n.
/// - Insets **directionnels**, `Row` suivant la `Directionality` ; couleur de
///   tracé/bordure **dérivée du thème** (aucun littéral — FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import 'z_signature_codec.dart';

/// Codec `const` partagé (DP-18) — source unique de vérité (dé)sérialisation
/// strokes ↔ valeur de tranche. Le widget délègue `decode`/`encode` ici.
const ZSignatureCodec _kSignatureCodec = ZSignatureCodec();

/// Hauteur de la zone de capture (token de mise en page, PAS une couleur).
const double _kCanvasHeight = 160;

/// Champ d'édition **signature** (strokes normalisés encodés en tranche).
class ZSignatureFieldWidget extends StatefulWidget {
  /// Construit la zone de capture pour [field], valeur INITIALE [initialValue]
  /// (`Map` encodée ou `null`, lue **une fois**), agrégeant le tracé vers le
  /// parent via [onChanged] (`Map` encodée, ou `null` si vide).
  const ZSignatureFieldWidget({
    required this.field,
    required this.initialValue,
    required this.onChanged,
    super.key,
  });

  /// Clé de la **boîte de capture** (seam de test : cible du geste de tracé).
  @visibleForTesting
  static const Key canvasKey = ValueKey<String>('z_signature_canvas');

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur INITIALE de la tranche (`Map` encodée ou `null`) — amorce le tracé
  /// local **une seule fois** (value-in-slice à propriété locale, AD-2).
  final Object? initialValue;

  /// Notifié avec le tracé encodé (`Map<String, dynamic>`), ou `null` si vide.
  final ValueChanged<Map<String, dynamic>?> onChanged;

  /// Décode des strokes NORMALISÉS depuis une valeur de tranche (défensif —
  /// AD-10 : type inattendu ⇒ liste vide, jamais de throw). Exposé pour les
  /// tests (round-trip encode/decode).
  @visibleForTesting
  static List<List<Offset>> decode(Object? value) =>
      _kSignatureCodec.strokesFromValue(value);

  /// Encode des strokes NORMALISÉS en `Map` versionnée sérialisable, ou `null`
  /// si vide. Exposé pour les tests. Format documenté ci-dessus (DP-18 : délègue
  /// au `ZSignatureCodec` — source unique de vérité).
  @visibleForTesting
  static Map<String, dynamic>? encode(List<List<Offset>> strokes) =>
      _kSignatureCodec.valueFromStrokes(strokes);

  @override
  State<ZSignatureFieldWidget> createState() => _ZSignatureFieldWidgetState();
}

class _ZSignatureFieldWidgetState extends State<ZSignatureFieldWidget> {
  /// Strokes committés (coordonnées NORMALISÉES `[0,1]`) — source de vérité
  /// locale, amorcée **une fois** depuis `initialValue`.
  late final List<List<Offset>> _strokes;

  /// Trait EN COURS (pendant le geste) ; `null` hors geste.
  List<Offset>? _current;

  /// Dernière taille connue de la boîte de capture (pour normaliser les points).
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _strokes = ZSignatureFieldWidget.decode(widget.initialValue);
  }

  /// `true` si un tracé existe (au moins un stroke committé).
  bool get _hasSignature => _strokes.any((s) => s.isNotEmpty);

  /// Convertit une position locale en coordonnées normalisées bornées `[0,1]`.
  Offset _normalize(Offset local) {
    final w = _canvasSize.width;
    final h = _canvasSize.height;
    final nx = w <= 0 ? 0.0 : (local.dx / w).clamp(0.0, 1.0);
    final ny = h <= 0 ? 0.0 : (local.dy / h).clamp(0.0, 1.0);
    return Offset(nx, ny);
  }

  void _panStart(DragStartDetails d) {
    setState(() => _current = <Offset>[_normalize(d.localPosition)]);
  }

  void _panUpdate(DragUpdateDetails d) {
    final stroke = _current;
    if (stroke == null) return;
    setState(() => stroke.add(_normalize(d.localPosition)));
  }

  void _panEnd(DragEndDetails d) {
    final stroke = _current;
    setState(() {
      if (stroke != null && stroke.isNotEmpty) _strokes.add(stroke);
      _current = null;
    });
    _emit();
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _current = null;
    });
    _emit();
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(_strokes.removeLast);
    _emit();
  }

  /// Agrège le tracé committé et écrit la tranche parente (handler d'évènement,
  /// JAMAIS pendant un `build`).
  void _emit() => widget.onChanged(ZSignatureFieldWidget.encode(_strokes));

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final colors = Theme.of(context).colorScheme;
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final readOnly = widget.field.readOnly;
    final stateLabel =
        label(context, _hasSignature ? 'signatureSigned' : 'signatureEmpty');

    final border = theme.fieldBorderColor ?? colors.outline;

    return Semantics(
      container: true,
      label: '$resolvedLabel: ${label(context, 'signatureArea')}',
      value: stateLabel,
      readOnly: readOnly,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(resolvedLabel,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = Size(
                  constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
                  _kCanvasHeight,
                );
                final canvas = DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.all(theme.radiusM),
                  ),
                  child: SizedBox(
                    key: ZSignatureFieldWidget.canvasKey,
                    height: _kCanvasHeight,
                    width: double.infinity,
                    child: ClipRect(
                      child: CustomPaint(
                        painter: _SignaturePainter(
                          strokes: _strokes,
                          current: _current,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
                if (readOnly) return canvas;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _panStart,
                  onPanUpdate: _panUpdate,
                  onPanEnd: _panEnd,
                  child: canvas,
                );
              },
            ),
          ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: label(context, 'undoSignature'),
                    onPressed: _strokes.isEmpty ? null : _undo,
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: label(context, 'clearSignature'),
                    onPressed: _hasSignature ? _clear : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Peintre des strokes NORMALISÉS (dénormalisés vers `size` au rendu). Couleur
/// de tracé **injectée** (thème — FR-26), jamais un littéral.
class _SignaturePainter extends CustomPainter {
  _SignaturePainter({
    required this.strokes,
    required this.current,
    required this.color,
  });

  final List<List<Offset>> strokes;
  final List<Offset>? current;
  final Color color;

  Offset _denorm(Offset n, Size size) =>
      Offset(n.dx * size.width, n.dy * size.height);

  void _paintStroke(Canvas canvas, Size size, List<Offset> stroke, Paint paint) {
    if (stroke.isEmpty) return;
    if (stroke.length == 1) {
      // Point isolé : petit disque (évite `PointMode`/`dart:ui` direct — la
      // garde de pureté `presentation/` bannit l'import `dart:ui`).
      final dot = Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(_denorm(stroke.first, size), paint.strokeWidth / 2, dot);
      return;
    }
    final start = _denorm(stroke.first, size);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 1; i < stroke.length; i++) {
      final p = _denorm(stroke[i], size);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      _paintStroke(canvas, size, stroke, paint);
    }
    final inProgress = current;
    if (inProgress != null) _paintStroke(canvas, size, inProgress, paint);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes != strokes ||
      old.current != current ||
      old.color != color;
}
