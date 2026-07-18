/// `ZPinFieldWidget` — champ **PIN / OTP** segmenté (fp-5-2, FR-34) servi via
/// `ZWidgetRegistry` sous le `kind` [pinFieldKind] (aligné sur
/// `EditionFieldType.pin.name`). S'appuie sur `pinput` (BSD-3), **confiné** à ce
/// satellite (AD-1, CORE OUT=0 — le cœur ne tire aucune dépendance lourde).
///
/// 🔴 **Dispatch cœur (fp-5-1/fp-4-2)** : le cœur route `EditionFieldType.pin`
/// vers la famille `registryOrFallback` → `registry.tryBuilderFor('pin')`. Un
/// champ `ZFieldSpec(type: EditionFieldType.pin)` atteint donc CE builder dès que
/// [registerZFieldExtrasFields] a peuplé le `ZWidgetRegistry` injecté au
/// `ZcrudScope` ; sinon repli propre `ZUnsupportedFieldWidget` (AD-10).
///
/// **AD-2 / SM-1** : value-in-slice — le builder lit `ctx.value` (`String`) et
/// écrit via `ctx.onChanged` **dans** la frontière de rebuild du dispatcher ;
/// aucune souscription élargie, aucun `ZFormController` capturé. Le
/// `TextEditingController` interne est alloué **une seule fois** (`initState`) et
/// disposé — jamais recréé au rebuild.
///
/// **AD-13 / FR-26** : chaque cellule ≥ 48 dp ([kZPinCellMinSize]), `Semantics`
/// de **progression UNIQUE** (« n / N ») sans répéter le label, couleurs
/// **dérivées** du `ThemeData`/`ZcrudTheme` injecté (aucune couleur codée en
/// dur), Reduce Motion honoré (`PinAnimationType.none` si
/// `MediaQuery.disableAnimations`).
///
/// **AD-10** : une valeur externe non-`String`/`null`/corrompue ne crashe jamais
/// (repli : champ vide).
library;

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// `kind` du champ **PIN/OTP**, ALIGNÉ sur le nom d'`EditionFieldType` que le
/// dispatcher cœur route vers le registre : `EditionFieldType.pin.name == 'pin'`.
/// Un champ `ZFieldSpec(type: EditionFieldType.pin)` atteint ce builder dès que
/// [registerZFieldExtrasFields] a peuplé le `ZWidgetRegistry` (sinon repli
/// `ZUnsupportedFieldWidget`, AD-10).
final String pinFieldKind = EditionFieldType.pin.name;

/// Longueur PIN par défaut si le champ n'en spécifie pas.
const int kZPinDefaultLength = 4;

/// Cible tactile minimale d'une cellule PIN (AD-13, ≥ 48 dp).
const double kZPinCellMinSize = 48;

/// Extrait défensivement (AD-10) la longueur du PIN depuis un [ZFieldSpec] : lit
/// `hintText` s'il encode un entier, sinon [kZPinDefaultLength]. Valeur bornée
/// `[1, 12]` (garde-fou UI).
int zPinLengthOf(ZFieldSpec field) {
  final parsed = int.tryParse(field.hintText ?? '');
  if (parsed == null) return kZPinDefaultLength;
  return parsed.clamp(1, 12);
}

/// Champ PIN segmenté (value-in-slice, patron AD-2).
class ZPinFieldWidget extends StatefulWidget {
  /// Construit le champ PIN pour [ctx].
  const ZPinFieldWidget({required this.ctx, this.onBuild, super.key});

  /// Contexte du champ (`ctx.value` = `String` courant, `ctx.onChanged` =
  /// écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous [pinFieldKind].
  static ZFieldWidgetBuilder builder({VoidCallback? onBuild}) =>
      (BuildContext context, ZFieldWidgetContext ctx) =>
          ZPinFieldWidget(ctx: ctx, onBuild: onBuild);

  @override
  State<ZPinFieldWidget> createState() => _ZPinFieldWidgetState();
}

class _ZPinFieldWidgetState extends State<ZPinFieldWidget> {
  /// Controller alloué **une seule fois** (AD-2) — jamais recréé au rebuild.
  late final TextEditingController _controller;

  /// Valeur `String` défensive de la tranche (AD-10) : non-`String`/`null` ⇒ ''.
  String get _sliceValue {
    final v = widget.ctx.value;
    return v is String ? v : '';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _sliceValue);
  }

  @override
  void didUpdateWidget(covariant ZPinFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync SANS écraser la sélection : n'aligne le texte que s'il diffère
    // réellement de la tranche (ré-injection externe), jamais à chaque frappe.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final length = zPinLengthOf(field);
    final filled = _sliceValue.length.clamp(0, length);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // PinTheme aux couleurs DÉRIVÉES du ColorScheme (FR-26 — aucune couleur en
    // dur) et à la cible ≥ 48 dp (AD-13).
    final pinTheme = PinTheme(
      width: kZPinCellMinSize,
      height: kZPinCellMinSize,
      textStyle: (theme.inputTextStyle ?? const TextStyle())
          .copyWith(color: scheme.onSurface),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.all(theme.inputRadius),
        border: Border.all(color: scheme.outline, width: theme.inputBorderWidth),
      ),
    );
    final focusedTheme = pinTheme.copyDecorationWith(
      border:
          Border.all(color: scheme.primary, width: theme.inputFocusedBorderWidth),
    );

    // Progression localisable (« saisis » = libellé ; les nombres n'en sont pas).
    final progressWord =
        label(context, 'fieldExtras.pin.progress', fallback: 'chiffres saisis');
    final progressLabel = '$filled / $length $progressWord';

    return Padding(
      padding: theme.fieldPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Label rendu UNE fois (son propre nœud sémantique).
          Text(resolvedLabel, style: TextStyle(color: theme.labelColor)),
          SizedBox(height: theme.gapS),
          // Nœud de PROGRESSION UNIQUE (AD-13) : ne répète PAS le label.
          Semantics(
            label: progressLabel,
            child: Pinput(
              key: const Key('z-pin-input'),
              length: length,
              controller: _controller,
              defaultPinTheme: pinTheme,
              focusedPinTheme: focusedTheme,
              readOnly: field.readOnly,
              enabled: !field.readOnly,
              mainAxisAlignment: MainAxisAlignment.start,
              separatorBuilder: (_) => SizedBox(width: theme.gapM),
              pinAnimationType:
                  reduceMotion ? PinAnimationType.none : PinAnimationType.scale,
              keyboardType: TextInputType.number,
              onChanged: widget.ctx.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
