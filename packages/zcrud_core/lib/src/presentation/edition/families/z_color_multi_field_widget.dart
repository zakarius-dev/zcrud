/// Widget de la **famille color** en mode **multiple** — FP-4.4 (Epic 4 / AD-52).
///
/// Variante **multi-sélection** native du champ `color` : la valeur vit **en
/// tranche** sous forme de **`List<int>` ARGB 32 bits** (canal alpha en poids
/// fort — `0xAARRGGBB`) — format stable, sérialisable, additif. Couvre la variante
/// `color` **multiple** de DODLP (`color_picker_field`) **sans forker** un package
/// tiers peu maintenu ni introduire de dépendance lourde au cœur (AD-1, CORE OUT=0)
/// : 100 % Flutter/Material.
///
/// Activé par `ZColorConfig.multiple(...)` (dispatch dans `z_field_widget.dart`) ;
/// le mode mono (`int` ARGB, [ZColorFieldWidget]) reste **strictement intact** par
/// défaut (rétro-compat). Réutilise **tel quel** le picker built-in NEUTRE public
/// [ZColorPickerDialog] et le seam injecté [ZColorPicker] (`ZcrudScope.colorPicker`)
/// du champ simple — **zéro duplication** du picker (la roue HSV riche reste côté
/// binding, AD-52).
///
/// **AD-10 (parse défensif)** : la lecture de la tranche passe par
/// [_parseArgbList] — toute entrée non-liste retombe sur `const <int>[]`, et dans
/// une liste **seules** les entrées `int` valides sont conservées (les `String`/
/// `double`/`null`… sont ignorées silencieusement). Le formulaire **ne throw
/// jamais** ; le parent survit à une valeur corrompue.
///
/// **FR-26 (aucun style codé en dur)** : les swatches sont des **données**
/// DÉRIVÉES (teintes `HSV` échelonnées) ; la bordure de sélection provient du
/// `ZcrudTheme`. **AD-13 (a11y/RTL)** : chaque cible interactive ≥ 48 dp avec
/// `Semantics(button + selected + label hex)` ; `Wrap`/`EdgeInsetsDirectional`/
/// `AlignmentDirectional` respectent la `Directionality` (aucun `EdgeInsets.only`
/// gauche/droite, aucun `Alignment.centerLeft/Right`, aucun `TextAlign.left/right`).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import '../../zcrud_scope.dart';
import 'z_color_field_widget.dart';

/// Champ d'édition **couleur multiple** (palette à cases + picker enrichi ;
/// `List<int>` ARGB en tranche). Complémentaire de [ZColorFieldWidget] (mono).
class ZColorMultiFieldWidget extends StatelessWidget {
  /// Construit le sélecteur multi lié à [field], valeur courante [value]
  /// (attendu `List<int>` ARGB ; défensif sur toute autre forme — AD-10),
  /// notifiant [onChanged] avec la **nouvelle liste** ARGB sélectionnée.
  const ZColorMultiFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (attendu `List<int>` ARGB ; défensif).
  final Object? value;

  /// Notifié avec la **`List<int>` ARGB** sélectionnée (jamais un `int` seul).
  final ValueChanged<List<int>> onChanged;

  /// Config couleur éventuelle (`null` ⇒ défauts neutres).
  ZColorConfig? get _config {
    final c = field.config;
    return c is ZColorConfig ? c : null;
  }

  /// AD-10 — Parse **défensif** de la tranche en `List<int>` ARGB : une `List`
  /// est filtrée pour ne conserver **que** ses entrées `int` (les autres —
  /// `String`/`double`/`null`… — sont ignorées) ; toute entrée non-liste (`null`,
  /// scalaire, `Map`…) retombe sur `const <int>[]`. **Jamais** de throw : un cast
  /// direct `value as List<int>` cracherait sur une entrée mêlée (test R3).
  static List<int> _parseArgbList(Object? value) {
    if (value is! List) return const <int>[];
    final out = <int>[];
    for (final e in value) {
      if (e is int) out.add(e);
    }
    return out;
  }

  /// Palette **dérivée** (12 teintes HSV échelonnées + 3 neutres) — pur-données,
  /// aucun littéral de couleur (FR-26). Alpha plein. Miroir de la palette du champ
  /// mono ([ZColorFieldWidget]) — données dérivées, dupliquées proprement.
  static List<int> _palette() {
    final argbs = <int>[];
    for (var i = 0; i < 12; i++) {
      final hue = (i * 30) % 360;
      argbs.add(
          HSVColor.fromAHSV(1, hue.toDouble(), 0.65, 0.9).toColor().toARGB32());
    }
    for (final v in <double>[0.15, 0.5, 0.9]) {
      argbs.add(HSVColor.fromAHSV(1, 0, 0, v).toColor().toARGB32());
    }
    return argbs;
  }

  /// Code hexadécimal `#AARRGGBB` d'un ARGB (représentation stable, a11y).
  static String _hex(int argb) =>
      '#${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  /// Bascule d'un swatch : présent ⇒ retiré ; absent ⇒ ajouté (append). Émet la
  /// nouvelle liste.
  void _toggle(List<int> current, int argb) {
    final next = List<int>.of(current);
    if (next.contains(argb)) {
      next.removeWhere((c) => c == argb);
    } else {
      next.add(argb);
    }
    onChanged(next);
  }

  /// Retire une couleur sélectionnée (chip removable).
  void _remove(List<int> current, int argb) {
    final next = List<int>.of(current)..removeWhere((c) => c == argb);
    onChanged(next);
  }

  /// Ouvre le picker enrichi (seam injecté prioritaire, sinon built-in neutre) et
  /// **ajoute** la couleur retournée à la liste (dédup). Défensif (AD-10) : un seam
  /// qui throw ⇒ aucune écriture (jamais de crash du formulaire).
  Future<void> _addColor(BuildContext context, List<int> current) async {
    final config = _config;
    final enableAlpha = config?.enableAlpha ?? false;
    final recent = config?.recentColors ?? const <int>[];

    final injected = ZcrudScope.maybeOf(context)?.colorPicker;
    int? picked;
    if (injected != null) {
      try {
        picked = await injected(
          context,
          initialArgb: current.isNotEmpty ? current.last : null,
          enableAlpha: enableAlpha,
          recentColors: recent,
        );
      } catch (_) {
        picked = null; // AD-10 : seam défaillant ⇒ pas d'écriture.
      }
    } else {
      picked = await showDialog<int>(
        context: context,
        builder: (dialogContext) => ZColorPickerDialog(
          initialArgb: current.isNotEmpty ? current.last : null,
          enableAlpha: enableAlpha,
          recentColors:
              (config?.showRecent ?? true) ? recent : const <int>[],
        ),
      );
    }
    if (picked != null && !current.contains(picked)) {
      onChanged(<int>[...current, picked]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);
    final theme = ZcrudTheme.of(context);
    final selectLabel = label(context, 'selectColor');
    final removeLabel = label(context, 'removeColor');
    final selected = _parseArgbList(value);
    final config = _config;
    final showPalette = config?.showPalette ?? true;
    final palette = _palette();

    return Semantics(
      container: true,
      // Pas de `label:` ici : le `Text(resolvedLabel)` visible ci-dessous fournit
      // déjà le nom accessible du conteneur — le dupliquer sur le Semantics
      // provoquerait une DOUBLE annonce (cf. correctif fp-5-1).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(resolvedLabel,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.start),
          ),
          // Couleurs sélectionnées : chips retirables (donnée ARGB — FR-26).
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  for (final argb in selected)
                    _RemovableSwatch(
                      argb: argb,
                      borderColor: theme.fieldBorderColor,
                      label: '$removeLabel ${_hex(argb)}',
                      onRemove:
                          field.readOnly ? null : () => _remove(selected, argb),
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
                    _CheckSwatch(
                      argb: argb,
                      selected: selected.contains(argb),
                      borderColor: theme.fieldBorderColor,
                      label: '$selectLabel ${_hex(argb)}',
                      onTap: field.readOnly
                          ? null
                          : () => _toggle(selected, argb),
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
                  onPressed: () => _addColor(context, selected),
                  icon: const Icon(Icons.add),
                  label: Text(label(context, 'colorAddColor')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// MED-1 — Couleur du glyphe (coche/croix) peint SUR la pastille [argb] :
/// contraste piloté par la luminosité de la **PASTILLE** (la donnée), PAS par le
/// thème de l'app (axe indépendant — en `ThemeData.dark()`, `onSurface`/`onPrimary`
/// s'inversent ⇒ glyphe sombre-sur-pastille-sombre, quasi invisible). Retourne un
/// **blanc/noir DÉRIVÉS par HSV** (pur-données, miroir de la palette neutre —
/// aucun littéral de couleur, FR-26) garantissant le contraste quel que soit le
/// thème.
Color _glyphOn(int argb) =>
    ThemeData.estimateBrightnessForColor(Color(argb)) == Brightness.dark
        ? HSVColor.fromAHSV(1, 0, 0, 1).toColor() // blanc dérivé
        : HSVColor.fromAHSV(1, 0, 0, 0).toColor(); // noir dérivé

/// Swatch de palette **à case** ≥ 48 dp (multi-sélection) : coche visible quand
/// [selected]. Couleur = donnée ARGB (FR-26) ; bordure = thème.
class _CheckSwatch extends StatelessWidget {
  const _CheckSwatch({
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
              child: selected
                  ? Icon(Icons.check, size: 18, color: _glyphOn(argb))
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Couleur **sélectionnée** retirable ≥ 48 dp : pastille + croix de retrait,
/// `Semantics(button + selected + label hex)`.
class _RemovableSwatch extends StatelessWidget {
  const _RemovableSwatch({
    required this.argb,
    required this.borderColor,
    required this.label,
    required this.onRemove,
  });

  final int argb;
  final Color? borderColor;
  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: true,
      label: label,
      child: InkWell(
        onTap: onRemove,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(argb),
                    shape: BoxShape.circle,
                    border: borderColor == null
                        ? null
                        : Border.all(color: borderColor!, width: 1),
                  ),
                ),
                if (onRemove != null)
                  Icon(Icons.close, size: 18, color: _glyphOn(argb)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
