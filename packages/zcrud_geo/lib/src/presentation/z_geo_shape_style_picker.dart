/// `ZGeoShapeStylePicker` — **toolbar de style fill/stroke** d'une forme géo
/// (`geoArea` polygone/cercle), FR-28/AD-8/AD-52 (story 5.3).
///
/// origine: DODLP stylise ses geofences via `flex_color_picker`. Ce picker en
/// est le **portage neutre** : il laisse l'utilisateur choisir couleur de
/// remplissage, couleur de trait et épaisseur de trait, et notifie un
/// [ZGeoShapeStyle] pur-données. **Aucune dépendance couleur lourde n'est tirée
/// dans `zcrud_geo`** (CORE OUT=0, AD-1) : la sélection de couleur **réutilise le
/// seam couleur du cœur** (`ZcrudScope.colorPicker`), avec repli sur le picker
/// built-in neutre du cœur [ZColorPickerDialog] — exactement le chemin du champ
/// `color` (`z_color_field_widget.dart`).
///
/// **AD-2 / SM-1** : `StatelessWidget` piloté par `style + onChanged` (aucun état
/// de formulaire interne, aucun `TextEditingController` — la couleur est une
/// **donnée ARGB**). Le parent porte la tranche et rebuild granulaire.
///
/// **Défensif (AD-10)** : un `style` `null`/incohérent part de
/// `const ZGeoShapeStyle()` sans throw ; un seam couleur qui lève une exception
/// n'écrit **rien** (`catch (_) → picked = null`), jamais de crash du formulaire ;
/// l'épaisseur est bornée avant d'atteindre le modèle.
///
/// **FR-26 (aucun style codé en dur)** : les couleurs affichées dérivent des
/// données ARGB (`Color(argb)` local à la couche presentation, comme
/// l'adaptateur OSM) ; bordures/accents/défauts proviennent du `ZcrudTheme`/
/// `Theme.of(context)`, jamais d'un littéral de couleur.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_geo_shape_style.dart';

/// Épaisseur de trait minimale acceptée par le contrôle (bornée, AD-10).
const int _kMinStrokeWidth = 0;

/// Épaisseur de trait maximale acceptée par le contrôle (borne raisonnable).
const int _kMaxStrokeWidth = 20;

/// Épaisseur maximale **rendue** dans l'aperçu (garde l'aperçu lisible même si
/// le modèle porte une valeur haute — donnée, pas style en dur).
const double _kPreviewStrokeCap = 10;

/// Toolbar de style d'une forme géo : remplissage / trait / épaisseur.
///
/// Prend le [style] courant (`null`/corrompu → `const ZGeoShapeStyle()`, AD-10)
/// et notifie [onChanged] à chaque modification avec un [ZGeoShapeStyle] dont le
/// **seul champ ciblé** est modifié (via `copyWith`, champs voisins préservés).
class ZGeoShapeStylePicker extends StatelessWidget {
  /// Construit le picker de style.
  const ZGeoShapeStylePicker({
    required this.style,
    required this.onChanged,
    this.readOnly = false,
    super.key,
  });

  /// Style courant. `null` ⇒ défaut sûr `const ZGeoShapeStyle()` (AD-10).
  final ZGeoShapeStyle? style;

  /// Notifié à chaque modification avec le style mis à jour.
  final ValueChanged<ZGeoShapeStyle> onChanged;

  /// Mode lecture seule : les contrôles sont désactivés (aucune écriture).
  final bool readOnly;

  /// Style effectif (jamais `null`) — défaut sûr AD-10.
  ZGeoShapeStyle get _effective => style ?? const ZGeoShapeStyle();

  /// Ouvre le picker couleur : **seam injecté** prioritaire (dans un
  /// `try/catch (_) → null`, AD-10), sinon repli **built-in neutre** du cœur
  /// [ZColorPickerDialog]. Calqué sur `z_color_field_widget.dart:97-129`.
  Future<int?> _pickColor(BuildContext context, int? initialArgb) async {
    final injected = ZcrudScope.maybeOf(context)?.colorPicker;
    if (injected != null) {
      try {
        return await injected(
          context,
          initialArgb: initialArgb,
          enableAlpha: true,
          recentColors: const <int>[],
        );
      } catch (_) {
        // AD-10 : seam défaillant ⇒ aucune écriture, jamais de crash.
        return null;
      }
    }
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => ZColorPickerDialog(
        initialArgb: initialArgb,
        enableAlpha: true,
        recentColors: const <int>[],
      ),
    );
  }

  /// Sélection de la couleur de **remplissage** → `copyWith(fillColorArgb:)`.
  Future<void> _pickFill(BuildContext context) async {
    final effective = _effective;
    final picked = await _pickColor(context, effective.fillColorArgb);
    if (picked != null) {
      onChanged(effective.copyWith(fillColorArgb: picked));
    }
  }

  /// Sélection de la couleur de **trait** → `copyWith(strokeColorArgb:)`.
  Future<void> _pickStroke(BuildContext context) async {
    final effective = _effective;
    final picked = await _pickColor(context, effective.strokeColorArgb);
    if (picked != null) {
      onChanged(effective.copyWith(strokeColorArgb: picked));
    }
  }

  /// Applique une épaisseur bornée `[min,max]` → `copyWith(strokeWidth:)`.
  /// Défensif : aucune valeur hors plage n'atteint le modèle (AD-10).
  void _setStrokeWidth(int value) {
    final effective = _effective;
    final clamped = value.clamp(_kMinStrokeWidth, _kMaxStrokeWidth);
    if (clamped == effective.strokeWidth) return;
    onChanged(effective.copyWith(strokeWidth: clamped));
  }

  @override
  Widget build(BuildContext context) {
    final effective = _effective;
    final scheme = Theme.of(context).colorScheme;
    final zTheme = ZcrudTheme.of(context);
    // Défauts NEUTRES issus du thème (FR-26), jamais un littéral de couleur.
    final Color borderColor = zTheme.fieldBorderColor ?? scheme.outline;
    final Color fillPreview = effective.fillColorArgb != null
        ? Color(effective.fillColorArgb!)
        : scheme.surface;
    final Color strokePreview = effective.strokeColorArgb != null
        ? Color(effective.strokeColorArgb!)
        : borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
          child: Text(
            label(context, 'geo.style.title', fallback: 'Style de la zone'),
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.start,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          child: _StylePreview(
            fill: fillPreview,
            stroke: strokePreview,
            strokeWidth: effective.strokeWidth,
            borderColor: borderColor,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _ColorButton(
                label:
                    label(context, 'geo.style.fill', fallback: 'Remplissage'),
                swatch: fillPreview,
                borderColor: borderColor,
                onTap: readOnly ? null : () => _pickFill(context),
              ),
              _ColorButton(
                label: label(context, 'geo.style.stroke', fallback: 'Trait'),
                swatch: strokePreview,
                borderColor: borderColor,
                onTap: readOnly ? null : () => _pickStroke(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
          child: _StrokeWidthStepper(
            label: label(context, 'geo.style.strokeWidth',
                fallback: 'Épaisseur du trait'),
            decreaseLabel: label(context, 'geo.style.strokeWidthDecrease',
                fallback: 'Diminuer l\'épaisseur du trait'),
            increaseLabel: label(context, 'geo.style.strokeWidthIncrease',
                fallback: 'Augmenter l\'épaisseur du trait'),
            value: effective.strokeWidth,
            min: _kMinStrokeWidth,
            max: _kMaxStrokeWidth,
            onChanged: readOnly ? null : _setStrokeWidth,
          ),
        ),
      ],
    );
  }
}

/// Aperçu de style piloté **données** (FR-26) : remplissage + trait + épaisseur.
///
/// **AC5** — délimitation garantie de la vignette : un **cadre EXTÉRIEUR neutre**
/// issu du thème ([borderColor], toujours visible) sépare la vignette du fond,
/// tandis que le **liseré INTÉRIEUR** rend le trait choisi ([stroke], la donnée).
/// Ainsi, même si l'utilisateur choisit `strokeColor ≈ couleur de fond`, la
/// vignette conserve un cadre neutre visible (contraste garanti).
class _StylePreview extends StatelessWidget {
  const _StylePreview({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.borderColor,
  });

  /// Clé du **cadre extérieur neutre** (thème), testable indépendamment du trait.
  static const Key outerFrameKey = ValueKey('z_geo_style_preview_frame');

  /// Clé de la **vignette intérieure** (remplissage + liseré du trait, donnée).
  static const Key innerSwatchKey = ValueKey('z_geo_style_preview_swatch');

  final Color fill;
  final Color stroke;
  final int strokeWidth;

  /// Couleur du **cadre extérieur neutre** (thème, FR-26) — délimite la vignette
  /// du fond indépendamment de la couleur de [stroke] (AC5).
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    // Épaisseur rendue bornée pour rester lisible (donnée, jamais style en dur).
    final double renderedWidth =
        strokeWidth.clamp(0, _kPreviewStrokeCap.toInt()).toDouble();
    return Semantics(
      // Aperçu non interactif : décrit l'état, ne double-annonce aucune cible.
      label: label(context, 'geo.style.preview', fallback: 'Aperçu du style'),
      readOnly: true,
      // Cadre EXTÉRIEUR neutre issu du thème (AC5) : toujours visible, il
      // délimite la vignette du fond quel que soit le trait choisi.
      child: Container(
        key: outerFrameKey,
        width: 64,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: borderColor, width: 1),
        ),
        padding: const EdgeInsets.all(3),
        // Vignette INTÉRIEURE : remplissage + liseré du trait choisi (donnée).
        child: DecoratedBox(
          key: innerSwatchKey,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            border: Border.all(
              color: stroke,
              // `max(1)` garde un trait visible même à épaisseur 0 (aperçu).
              width: renderedWidth < 1 ? 1 : renderedWidth,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton de sélection couleur (≥ 48 dp, un seul `Semantics` porteur — AD-13).
///
/// Le [swatch] est une **donnée ARGB** rendue localement (FR-26). `onTap == null`
/// ⇒ désactivé (lecture seule).
class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.label,
    required this.swatch,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final Color swatch;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      // Un seul nœud porteur : on masque les sémantiques descendantes (le
      // libellé visuel + le swatch) pour éviter la double annonce (AC6).
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: borderColor == null
                        ? null
                        : Border.all(color: borderColor!, width: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stepper d'épaisseur `int` borné (deux cibles ≥ 48 dp, labels distincts).
///
/// Déterministe et testable (contrairement à un `Slider`) : chaque tap émet
/// exactement `±1` borné à `[min,max]`. `onChanged == null` ⇒ désactivé.
class _StrokeWidthStepper extends StatelessWidget {
  const _StrokeWidthStepper({
    required this.label,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String decreaseLabel;
  final String increaseLabel;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bool canDecrease = onChanged != null && value > min;
    final bool canIncrease = onChanged != null && value < max;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.start,
          ),
        ),
        _StepButton(
          icon: Icons.remove,
          label: decreaseLabel,
          onTap: canDecrease ? () => onChanged!(value - 1) : null,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
          child: Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.start,
          ),
        ),
        _StepButton(
          icon: Icons.add,
          label: increaseLabel,
          onTap: canIncrease ? () => onChanged!(value + 1) : null,
        ),
      ],
    );
  }
}

/// Bouton d'incrément/décrément ≥ 48 dp, un seul `Semantics` porteur (AD-13).
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon),
        ),
      ),
    );
  }
}
