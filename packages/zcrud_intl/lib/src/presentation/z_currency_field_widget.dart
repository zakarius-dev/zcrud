/// `ZCurrencyField` — **champ d'édition devise** (E11b-2, AD-2/AD-4/AD-13/AD-10).
///
/// origine: FR-21 demande un champ **devise**. Comme il n'existe **aucune** valeur
/// `EditionFieldType.currency` (cœur figé, AD-1), ce champ est **composable** :
/// une app le fournit dans ses formulaires via [ZCurrencyField.builder]
/// (`ZFieldWidgetBuilder`), enregistrable sous un `kind` de son choix. Il émet
/// soit le **code devise ISO 4217 `String`** (mode par défaut), soit un [ZMoney]
/// (couple montant+devise) quand un montant est saisi ([showAmount]).
///
/// *Le montant **seul** reste servi par le champ `number` du cœur +
/// `ZNumberConfig(isCurrency: true)` ; ce champ fournit le **sélecteur de code
/// devise** qui le complète.*
///
/// **AD-2** : le contrôleur de montant est créé **1×** (`initState`), disposé,
/// jamais recréé ni ré-injecté pendant la frappe (sync guardée hors focus). Le
/// sélecteur de code réutilise le picker inline générique (a11y/RTL factorisés).
///
/// **AD-4** : catalogue capturé par closure ; défaut de devise lu **par champ**
/// via `ctx.field.config` ([ZIntlFieldConfig.defaultCurrencyCode]).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_currency_catalog.dart';
import '../domain/z_currency_info.dart';
import '../domain/z_intl_field_config.dart';
import '../domain/z_money.dart';
import 'z_option_picker_field.dart';

/// Champ d'édition devise (sélecteur de code ISO 4217 + montant optionnel).
class ZCurrencyField extends StatefulWidget {
  /// Construit le champ pour [ctx]. [catalog] alimente le sélecteur de code
  /// (injecté par closure de [builder]). [showAmount] active le champ montant
  /// (émet alors un [ZMoney] plutôt qu'un code `String`).
  const ZCurrencyField({
    required this.ctx,
    required this.catalog,
    this.showAmount = false,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = code devise `String` OU [ZMoney] courant,
  /// `ctx.onChanged` = écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Catalogue devise (paresseux + caché) capturé par closure (AD-4).
  final ZCurrencyCatalog catalog;

  /// Affiche un champ montant → émet un [ZMoney] (sinon code `String` seul).
  final bool showAmount;

  /// Hook de test : appelé UNE FOIS en `initState` (preuve SM-1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous un `kind` au choix de
  /// l'app. Le [catalog] est capturé par closure (immuable, partageable) ; chaque
  /// montage crée SON contrôleur de montant (par-montage, MAJEUR-1).
  static ZFieldWidgetBuilder builder({
    ZCurrencyCatalog? catalog,
    bool showAmount = false,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) {
    final cat = catalog ?? sharedDefaultCurrencyCatalog();
    return (BuildContext context, ZFieldWidgetContext ctx) => ZCurrencyField(
          ctx: ctx,
          catalog: cat,
          showAmount: showAmount,
          onInit: onInit,
          onBuild: onBuild,
        );
  }

  @override
  State<ZCurrencyField> createState() => _ZCurrencyFieldState();
}

class _ZCurrencyFieldState extends State<ZCurrencyField> {
  /// Contrôleur du montant — créé 1× (`initState`), jamais recréé (AD-2).
  late final TextEditingController _amountController;

  /// Focus du montant — oracle de la sync guardée.
  late final FocusNode _amountFocus;

  /// Code devise sélectionné (état local possédé).
  String? _code;

  bool get _hasAmountFocus => _amountFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _amountFocus = FocusNode();
    final cfg = _config;
    _code = _codeOf(widget.ctx.value) ?? cfg?.defaultCurrencyCode;
    final amount = _amountOf(widget.ctx.value);
    if (amount != null) _amountController.text = _fmt(amount);
    // Chargement paresseux du catalogue : rebuild LOCAL une fois résolu (SM-1).
    if (!widget.catalog.isLoaded) {
      widget.catalog.load().then((_) {
        if (mounted) setState(() {});
      });
    }
    widget.onInit?.call();
  }

  @override
  void didUpdateWidget(covariant ZCurrencyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SYNC GUARDÉE (AD-2) : reflet d'une valeur EXTERNE hors focus uniquement.
    if (_hasAmountFocus) return;
    final code = _codeOf(widget.ctx.value);
    if (code != null && code != _code) _code = code;
    final amount = _amountOf(widget.ctx.value);
    final external = amount == null ? '' : _fmt(amount);
    if (widget.showAmount && _amountController.text != external) {
      _amountController.text = external;
    }
  }

  @override
  void dispose() {
    // Anti-fuite (learning E5).
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  ZIntlFieldConfig? get _config {
    final c = widget.ctx.field.config;
    return c is ZIntlFieldConfig ? c : null;
  }

  /// Lecture défensive (AD-10) : code depuis un `String`, un [ZMoney] ou une map.
  String? _codeOf(Object? value) {
    if (value is String) return value.isEmpty ? null : value;
    if (value is ZMoney) return value.currencyCode;
    return ZMoney.fromMapSafe(value)?.currencyCode;
  }

  num? _amountOf(Object? value) {
    if (value is ZMoney) return value.amount;
    return ZMoney.fromMapSafe(value)?.amount;
  }

  static String _fmt(num v) => v == v.roundToDouble() && v.abs() < 1e15
      ? v.toInt().toString()
      : v.toString();

  /// Voie unique (AD-2) : émet le code devise (ou un [ZMoney] si [showAmount]).
  void _emit() {
    final code = _code;
    if (widget.showAmount) {
      final parsed = num.tryParse(_amountController.text.trim());
      final amount = (parsed != null && parsed.isFinite) ? parsed : null;
      final money = ZMoney(currencyCode: code, amount: amount);
      widget.ctx.onChanged(money.isEmpty ? null : money);
    } else {
      widget.ctx.onChanged((code == null || code.isEmpty) ? null : code);
    }
  }

  void _onCurrencySelected(ZCurrencyInfo info) {
    setState(() => _code = info.code);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final cfg = _config;
    final selected = _code == null ? null : widget.catalog.byCode(_code!);
    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Padding(
        padding: theme.fieldPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(resolvedLabel, style: TextStyle(color: theme.labelColor)),
            SizedBox(height: theme.gapS),
            ZOptionPickerField<ZCurrencyInfo>(
              keyPrefix: 'z-currency',
              readOnly: field.readOnly,
              searchable: cfg?.searchable ?? true,
              semanticLabel:
                  label(context, 'intl.currency', fallback: 'Devise'),
              selectedTitle: _triggerText(selected),
              selectedLeading: selected?.symbol,
              search: (q) => widget.catalog.search(q),
              itemKey: (c) => c.code,
              itemTitle: (c) => c.name ?? c.code,
              itemLeading: (c) => c.symbol,
              itemTrailing: (c) => c.code,
              onSelected: _onCurrencySelected,
            ),
            if (widget.showAmount) ...<Widget>[
              SizedBox(height: theme.gapS),
              _amountField(field.readOnly),
            ],
          ],
        ),
      ),
    );
  }

  String? _triggerText(ZCurrencyInfo? selected) {
    if (selected != null) return selected.name ?? selected.code;
    return _code; // code brut si hors catalogue (ex. défaut non résolu).
  }

  Widget _amountField(bool readOnly) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: TextField(
          key: const Key('z-currency-amount'),
          controller: _amountController,
          focusNode: _amountFocus,
          readOnly: readOnly,
          textAlign: TextAlign.start,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            isDense: true,
            labelText: label(context, 'intl.currency.amount', fallback: 'Montant'),
          ),
          onChanged: readOnly ? null : (_) => _emit(),
        ),
      );
}
