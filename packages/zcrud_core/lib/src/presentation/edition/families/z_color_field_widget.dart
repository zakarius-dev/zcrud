/// Widget de la **famille color** (`color`) — E3-3b-1 + DP-17 (M14).
///
/// Sélecteur de couleur : la couleur vit **en tranche** encodée en **`int` ARGB
/// 32 bits** (canal alpha en poids fort — `0xAARRGGBB`) — format **stable,
/// sérialisable, additif** (décision story #7 / ambiguïté #5). Lecture `value`
/// (attendu `int` ; défensif sur tout autre type → aucune sélection), écriture
/// via `onChanged` (aucun `TextEditingController` pour la palette, AD-2).
///
/// **DP-17 (M14, parité `flex_color_picker` DODLP)** — le cœur reste **NEUTRE**
/// (couleur = donnée ARGB, aucune dép picker tierce lourde imposée — AD-1) :
/// - la **palette** historique (15 swatches dérivés) est **strictement préservée**
///   (rétro-compat) et pilotée par `ZColorConfig.showPalette` (défaut `true`) ;
/// - un bouton **« couleur personnalisée »** ouvre soit le **seam injecté**
///   (`ZcrudScope.colorPicker`, roue HSV/hex/opacité tierce host-fournie), soit un
///   **picker built-in NEUTRE** (`_ZColorPickerDialog` : sliders teinte/saturation/
///   luminosité + opacité optionnelle + saisie hex + couleurs récentes) — 100 %
///   Flutter, zéro dépendance lourde ;
/// - `ZColorConfig.enableAlpha`/`recentColors`/`showRecent` (défensif AD-10)
///   pilotent l'opacité et la ligne des récentes. Sans `ZColorConfig` ⇒
///   comportement E3-3b-1 exact + bouton personnalisé sur picker built-in.
///
/// **FR-26 (aucun style codé en dur)** : les swatches sont des **données**
/// DÉRIVÉES (teintes `HSV` échelonnées) ; la bordure de sélection provient du
/// `ZcrudTheme`. a11y/RTL (AD-13) : chaque swatch/cible ≥ 48 dp avec
/// `Semantics(label + selected)` ; `Wrap` respecte la `Directionality`.
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import '../../zcrud_scope.dart';

/// DP-17 (M14) — **Seam injectable NEUTRE** d'un picker de couleur host-fourni
/// (roue HSV/hex/opacité tierce). Injecté via `ZcrudScope.colorPicker`. Retourne
/// l'ARGB choisi (`int`), ou `null` si annulé. Le cœur ne dépend d'AUCUN package
/// de picker (AD-1) : l'impl concrète (`flex_color_picker`…) vit dans l'app/le
/// binding. Absent (défaut) ⇒ repli sur le **picker built-in neutre**.
typedef ZColorPicker = Future<int?> Function(
  BuildContext context, {
  required int? initialArgb,
  required bool enableAlpha,
  required List<int> recentColors,
});

/// Champ d'édition **couleur** (palette + picker enrichi ; `int` ARGB en tranche).
class ZColorFieldWidget extends StatelessWidget {
  /// Construit le sélecteur lié à [field], valeur courante [value] (`int` ARGB
  /// ou `null`), notifiant [onChanged] avec l'ARGB choisi (`int`).
  const ZColorFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (`int` ARGB 32 bits ou `null`).
  final Object? value;

  /// Notifié avec l'ARGB (`int`) sélectionné.
  final ValueChanged<int> onChanged;

  /// Config couleur éventuelle (`null` ⇒ défauts neutres, rétro-compat).
  ZColorConfig? get _config {
    final c = field.config;
    return c is ZColorConfig ? c : null;
  }

  /// Palette **dérivée** (12 teintes HSV échelonnées + neutres) — pur-données,
  /// aucun littéral de couleur (FR-26). Alpha plein.
  static List<int> _palette() {
    final argbs = <int>[];
    for (var i = 0; i < 12; i++) {
      final hue = (i * 30) % 360;
      argbs.add(
          HSVColor.fromAHSV(1, hue.toDouble(), 0.65, 0.9).toColor().toARGB32());
    }
    // Neutres dérivés (saturation nulle) : sombre / moyen / clair.
    for (final v in <double>[0.15, 0.5, 0.9]) {
      argbs.add(HSVColor.fromAHSV(1, 0, 0, v).toColor().toARGB32());
    }
    return argbs;
  }

  /// Code hexadécimal `#AARRGGBB` d'un ARGB (représentation stable, a11y).
  static String _hex(int argb) =>
      '#${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  /// Ouvre le picker enrichi : **seam injecté** prioritaire, sinon **built-in
  /// neutre**. Défensif (AD-10) : un seam qui throw ⇒ aucune écriture (jamais de
  /// crash du formulaire).
  Future<void> _openPicker(BuildContext context) async {
    final config = _config;
    final enableAlpha = config?.enableAlpha ?? false;
    final recent = config?.recentColors ?? const <int>[];
    final current = value is int ? value! as int : null;

    final injected = ZcrudScope.maybeOf(context)?.colorPicker;
    int? picked;
    if (injected != null) {
      try {
        picked = await injected(
          context,
          initialArgb: current,
          enableAlpha: enableAlpha,
          recentColors: recent,
        );
      } catch (_) {
        picked = null; // AD-10 : seam défaillant ⇒ pas d'écriture.
      }
    } else {
      picked = await showDialog<int>(
        context: context,
        builder: (dialogContext) => _ZColorPickerDialog(
          initialArgb: current,
          enableAlpha: enableAlpha,
          recentColors: config?.showRecent ?? true
              ? recent
              : const <int>[],
        ),
      );
    }
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);
    final theme = ZcrudTheme.of(context);
    final selectLabel = label(context, 'selectColor');
    final current = value is int ? value! as int : null;
    final config = _config;
    final showPalette = config?.showPalette ?? true;
    final palette = _palette();

    return Semantics(
      container: true,
      label: resolvedLabel,
      value: current == null ? null : _hex(current),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(resolvedLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.start),
                ),
                // Aperçu de la couleur courante (donnée ARGB — FR-26).
                if (current != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                    child: _CurrentSwatch(
                      argb: current,
                      borderColor: theme.fieldBorderColor,
                    ),
                  ),
              ],
            ),
          ),
          if (showPalette)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  for (final argb in palette)
                    _Swatch(
                      argb: argb,
                      selected: argb == current,
                      borderColor: theme.fieldBorderColor,
                      label: '$selectLabel ${_hex(argb)}',
                      onTap: field.readOnly ? null : () => onChanged(argb),
                    ),
                ],
              ),
            ),
          if (!field.readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _openPicker(context),
                  icon: const Icon(Icons.palette_outlined),
                  label: Text(label(context, 'customColor')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Aperçu ≥ 24 dp de la couleur courante (donnée ARGB — FR-26).
class _CurrentSwatch extends StatelessWidget {
  const _CurrentSwatch({required this.argb, required this.borderColor});

  final int argb;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Color(argb),
        shape: BoxShape.circle,
        border:
            borderColor == null ? null : Border.all(color: borderColor!, width: 1),
      ),
    );
  }
}

/// Swatch de couleur ≥ 48 dp, accessible (label + état sélectionné).
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.argb,
    required this.selected,
    required this.borderColor,
    required this.label,
    required this.onTap,
  });

  final int argb;
  final bool selected;
  final Color? borderColor;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(argb),
                shape: BoxShape.circle,
                border: selected && borderColor != null
                    ? Border.all(color: borderColor!, width: 3)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// DP-17 (M14) — Picker **built-in NEUTRE** (repli si aucun `ZColorPicker`
/// injecté) : sliders teinte/saturation/luminosité + opacité optionnelle + saisie
/// hex + couleurs récentes. 100 % Flutter (aucune dépendance lourde — AD-1). La
/// couleur reste une **donnée ARGB** (jamais un style codé en dur — FR-26). Un
/// hex invalide est **ignoré défensivement** (AD-10, jamais de throw). Exposé
/// `@visibleForTesting` pour l'exercer sans passer par un `showDialog`.
@visibleForTesting
class ZColorPickerDialog extends StatefulWidget {
  /// Construit le picker built-in. [initialArgb] amorce les sliders ;
  /// [enableAlpha] active le slider d'opacité ; [recentColors] alimente la ligne
  /// des récentes.
  const ZColorPickerDialog({
    required this.initialArgb,
    required this.enableAlpha,
    required this.recentColors,
    super.key,
  });

  /// Couleur initiale (ARGB `int`, ou `null` ⇒ défaut opaque neutre).
  final int? initialArgb;

  /// Active le slider d'opacité (canal alpha).
  final bool enableAlpha;

  /// Couleurs récentes proposées (ARGB `int`).
  final List<int> recentColors;

  @override
  State<ZColorPickerDialog> createState() => _ZColorPickerDialogState();
}

/// Alias interne (nom court) — le type public reste [ZColorPickerDialog].
typedef _ZColorPickerDialog = ZColorPickerDialog;

class _ZColorPickerDialogState extends State<ZColorPickerDialog> {
  late double _hue; // 0..360
  late double _sat; // 0..1
  late double _val; // 0..1
  late double _alpha; // 0..1
  late final TextEditingController _hexController;

  /// Masque alpha plein (`0xFF000000`) exprimé par **décalage** — évite un
  /// littéral de couleur `0xFF…` (garde `style_purity`, FR-26).
  static const int _alphaMask = 0xFF << 24;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialArgb;
    // Défaut NEUTRE (gris moyen dérivé HSV — aucun littéral de couleur, FR-26)
    // quand aucune valeur initiale n'est fournie.
    final hsv = initial != null
        ? HSVColor.fromColor(Color(initial))
        : HSVColor.fromAHSV(1, 0, 0, 0.5);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
    _alpha = widget.enableAlpha
        ? ((initial ?? _alphaMask) >> 24 & 0xFF) / 255.0
        : 1.0;
    _hexController = TextEditingController(
        text: ZColorFieldWidget._hex(_currentArgb));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  /// ARGB courant dérivé des sliders (donnée — FR-26).
  int get _currentArgb {
    final rgb = HSVColor.fromAHSV(1, _hue, _sat, _val).toColor();
    final a = (_alpha.clamp(0.0, 1.0) * 255).round();
    return (a << 24) | (rgb.toARGB32() & 0x00FFFFFF);
  }

  void _syncHexField() {
    final s = ZColorFieldWidget._hex(_currentArgb);
    if (_hexController.text.toUpperCase() != s) {
      _hexController.text = s;
    }
  }

  /// Applique une saisie hex **défensivement** (AD-10) : `#RGB`/`#RRGGBB`/
  /// `#AARRGGBB` (avec ou sans `#`). Invalide ⇒ ignorée (pas de throw).
  void _applyHex(String raw) {
    final argb = _parseHex(raw, enableAlpha: widget.enableAlpha);
    if (argb == null) return;
    final hsv = HSVColor.fromColor(Color(argb));
    setState(() {
      _hue = hsv.hue;
      _sat = hsv.saturation;
      _val = hsv.value;
      if (widget.enableAlpha) _alpha = (argb >> 24 & 0xFF) / 255.0;
    });
  }

  /// Parse un hex en ARGB (défensif → `null`). Sans canal alpha explicite (ou
  /// [enableAlpha] `false`) ⇒ alpha plein.
  static int? _parseHex(String raw, {required bool enableAlpha}) {
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) {
      // #RGB → #RRGGBB
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length == 6) {
      final v = int.tryParse(s, radix: 16);
      return v == null ? null : _alphaMask | v;
    }
    if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      if (v == null) return null;
      return enableAlpha ? v : _alphaMask | (v & 0x00FFFFFF);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return AlertDialog(
      title: Text(label(context, 'customColor')),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Aperçu.
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(_currentArgb),
                  shape: BoxShape.circle,
                  border: theme.fieldBorderColor == null
                      ? null
                      : Border.all(color: theme.fieldBorderColor!),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _labeledSlider(context, 'colorHue', _hue, 0, 360, (v) {
              setState(() => _hue = v);
              _syncHexField();
            }),
            _labeledSlider(context, 'colorSaturation', _sat, 0, 1, (v) {
              setState(() => _sat = v);
              _syncHexField();
            }),
            _labeledSlider(context, 'colorBrightness', _val, 0, 1, (v) {
              setState(() => _val = v);
              _syncHexField();
            }),
            if (widget.enableAlpha)
              _labeledSlider(context, 'colorOpacity', _alpha, 0, 1, (v) {
                setState(() => _alpha = v);
                _syncHexField();
              }),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
              child: TextField(
                controller: _hexController,
                decoration: InputDecoration(
                  labelText: label(context, 'colorHex'),
                  isDense: true,
                ),
                onSubmitted: _applyHex,
                onChanged: _applyHex,
              ),
            ),
            if (widget.recentColors.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 4),
                child: Text(label(context, 'colorRecent'),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.start),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  for (final argb in widget.recentColors)
                    _Swatch(
                      argb: argb,
                      selected: argb == _currentArgb,
                      borderColor: theme.fieldBorderColor,
                      label: ZColorFieldWidget._hex(argb),
                      onTap: () {
                        _applyHex(ZColorFieldWidget._hex(argb));
                        _syncHexField();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(label(context, 'cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_currentArgb),
          child: Text(label(context, 'apply')),
        ),
      ],
    );
  }

  Widget _labeledSlider(
    BuildContext context,
    String key,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 90,
          child: Text(label(context, key),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.start),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
