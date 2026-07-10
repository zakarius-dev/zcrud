/// `ZPhoneFieldWidget` — **champ d'édition téléphone international**
/// (`phoneNumber`), servi via `ZWidgetRegistry` (E11a-2, AD-2/AD-4/AD-13/AD-10).
///
/// origine: le dispatcher du cœur route `phoneNumber` vers le `ZWidgetRegistry`
/// injecté et appelle le builder **dans** la frontière de rebuild de la tranche.
/// Ce champ combine un **sélecteur d'indicatif/pays** (compact) et un **champ
/// numéro** ; il émet un [ZPhoneNumber] **neutre** (E.164 canonique) via
/// `ctx.onChanged`. La (dé)normalisation E.164 est confinée à [ZPhoneCodec]
/// (seul point d'entrée de `phone_numbers_parser`, AD-1).
///
/// **AD-2** : `TextEditingController`/`FocusNode` du numéro créés **1×**
/// (`initState`), disposés, jamais recréés ni ré-injectés pendant la frappe
/// (sync guardée hors focus). Changer le pays met à jour l'indicatif et
/// re-normalise l'E.164 (AC4).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_country_catalog.dart';
import '../domain/z_country_info.dart';
import '../domain/z_phone_number.dart';
import 'z_country_picker_field.dart';
import 'z_phone_codec.dart';

/// Champ d'édition téléphone (patron AD-2 : contrôleur stable, rebuild ciblé).
class ZPhoneFieldWidget extends StatefulWidget {
  /// Construit le champ pour [ctx]. [catalog] alimente le sélecteur d'indicatif ;
  /// [defaultIsoCode] (surchargeable, jamais codé en dur non surchargeable —
  /// AD-12) amorce le pays quand la valeur initiale n'en fournit pas.
  const ZPhoneFieldWidget({
    required this.ctx,
    required this.catalog,
    this.defaultIsoCode,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = [ZPhoneNumber] courant, `ctx.onChanged` =
  /// écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Catalogue pays (paresseux + caché) capturé par closure (AD-4).
  final ZCountryCatalog catalog;

  /// Pays d'amorçage optionnel (code ISO alpha-2), **surchargeable** ; `null` par
  /// défaut (aucun défaut national imposé, AD-12).
  final String? defaultIsoCode;

  /// Hook de test : appelé UNE FOIS en `initState` (preuve SM-1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous le `kind`
  /// `"phoneNumber"`. Le [catalog] est capturé par closure (immuable,
  /// partageable) ; chaque montage crée SON contrôleur de numéro (par-montage,
  /// MAJEUR-1). Exemple :
  /// `registry.register('phoneNumber', ZPhoneFieldWidget.builder(catalog: cat))`.
  static ZFieldWidgetBuilder builder({
    ZCountryCatalog? catalog,
    String? defaultIsoCode,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) {
    // LOW-1 : sans `catalog` injecté, partage l'instance par défaut lazy pour
    // que les 3 kinds intl ne lisent l'asset qu'une seule fois (au lieu de 3).
    final cat = catalog ?? sharedDefaultCountryCatalog();
    return (BuildContext context, ZFieldWidgetContext ctx) => ZPhoneFieldWidget(
          ctx: ctx,
          catalog: cat,
          defaultIsoCode: defaultIsoCode,
          onInit: onInit,
          onBuild: onBuild,
        );
  }

  @override
  State<ZPhoneFieldWidget> createState() => _ZPhoneFieldWidgetState();
}

class _ZPhoneFieldWidgetState extends State<ZPhoneFieldWidget> {
  /// Contrôleur du numéro — créé 1× (`initState`), jamais recréé (AD-2).
  late final TextEditingController _numberController;

  /// Focus du numéro — oracle de la sync guardée.
  late final FocusNode _numberFocus;

  /// Code ISO du pays sélectionné (état local possédé) — amorce l'indicatif et
  /// la normalisation E.164. Mis à jour par le sélecteur (setState local).
  String? _iso;

  bool get _hasNumberFocus => _numberFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController();
    _numberFocus = FocusNode();
    final phone = _phoneOf(widget.ctx.value);
    _iso = phone?.isoCode ?? widget.defaultIsoCode;
    // Nit E11a-2 : l'affichage du champ numéro est amorcé depuis `nationalNumber`.
    // [ZPhoneCodec.parse] renseigne toujours `nationalNumber` pour tout numéro
    // parsé, donc une valeur persistée par ce champ l'expose. Un `ZPhoneNumber`
    // interop « e164 seul » (sans `nationalNumber`) resterait affiché vide — cas
    // marginal assumé : on ne dé-normalise pas l'E.164 au montage (éviterait un
    // aller-retour codec qui ré-émettrait l'indicatif dans le national).
    if (phone?.nationalNumber != null && phone!.nationalNumber!.isNotEmpty) {
      _numberController.text = phone.nationalNumber!;
    }
    widget.onInit?.call();
  }

  @override
  void didUpdateWidget(covariant ZPhoneFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SYNC GUARDÉE (AD-2) : refléter une valeur EXTERNE dans le champ numéro
    // UNIQUEMENT hors focus. Pendant la frappe, priorité absolue au curseur.
    if (_hasNumberFocus) return;
    final phone = _phoneOf(widget.ctx.value);
    final external = phone?.nationalNumber ?? '';
    if (_numberController.text != external) _numberController.text = external;
    final iso = phone?.isoCode;
    if (iso != null && iso != _iso) _iso = iso;
  }

  @override
  void dispose() {
    // Anti-fuite (learning E5).
    _numberController.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  /// Lecture défensive (AD-10) : accepte un [ZPhoneNumber] déjà neutre OU une map
  /// sérialisée ; tout autre type → `null`.
  ZPhoneNumber? _phoneOf(Object? value) => value is ZPhoneNumber
      ? value
      : ZPhoneNumber.fromMapSafe(value);

  /// Voie unique (AD-2) : (re)compose le [ZPhoneNumber] neutre depuis le numéro
  /// saisi et le pays courant via [ZPhoneCodec] (E.164 si valide) et l'émet.
  void _emit() {
    final raw = _numberController.text;
    if (raw.trim().isEmpty && _iso == null) {
      widget.ctx.onChanged(null);
      return;
    }
    final phone = ZPhoneCodec.parse(raw, iso: _iso);
    widget.ctx.onChanged(phone.isEmpty && _iso == null ? null : phone);
  }

  void _onCountrySelected(ZCountryInfo country) {
    setState(() => _iso = country.isoCode);
    // Re-normalise l'E.164/indicatif avec le nouveau pays (AC4).
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Sélecteur d'indicatif compact (drapeau + dialCode).
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 96, maxWidth: 160),
                  child: ZCountryPickerField(
                    catalog: widget.catalog,
                    selectedIso: _iso,
                    readOnly: field.readOnly,
                    compact: true,
                    semanticLabel: label(
                      context,
                      'intl.phone.country',
                      fallback: 'Indicatif',
                    ),
                    onSelected: _onCountrySelected,
                  ),
                ),
                SizedBox(width: theme.gapM),
                Expanded(child: _numberField(field.readOnly)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // MEDIUM-2 (AD-13 opérabilité) : PAS de `Semantics(textField:true)` +
  // `ExcludeSemantics` englobant — cela masquait les sémantiques éditables
  // natives du `TextField` (valeur/curseur/édition inopérables au lecteur
  // d'écran). Le `TextField` porte sa propre sémantique de champ éditable ; son
  // libellé accessible provient de `InputDecoration.labelText`.
  Widget _numberField(bool readOnly) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: TextField(
          key: const Key('z-phone-number'),
          controller: _numberController,
          focusNode: _numberFocus,
          readOnly: readOnly,
          textAlign: TextAlign.start,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            isDense: true,
            labelText: label(context, 'intl.phone.number', fallback: 'Numéro'),
          ),
          // Voie SENS UNIQUE (AD-2) : la frappe écrit la tranche, jamais de
          // ré-injection pendant le focus.
          onChanged: readOnly ? null : (_) => _emit(),
        ),
      );
}
