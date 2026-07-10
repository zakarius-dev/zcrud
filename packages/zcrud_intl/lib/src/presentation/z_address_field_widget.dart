/// `ZAddressFieldWidget` — **champ d'édition adresse postale** (`address`), servi
/// via `ZWidgetRegistry` (E11a-2, AD-2/AD-4/AD-13/AD-10).
///
/// origine: le dispatcher du cœur route `address` vers le `ZWidgetRegistry`
/// injecté. Ce champ est un **sous-formulaire structuré** (lignes, ville, région,
/// code postal, pays) émettant un [ZPostalAddress] **neutre** via `ctx.onChanged`.
///
/// **AD-2** : un `TextEditingController`/`FocusNode` **stable par sous-champ**
/// (créés 1× en `initState`, disposés) ; sync guardée hors focus ; jamais de
/// reconstruction globale. Le sélecteur pays est le même composant inline que
/// [ZCountryFieldWidget] (catalogue capturé par closure, AD-4).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_country_catalog.dart';
import '../data/z_subdivision_catalog.dart';
import '../domain/z_country_info.dart';
import '../domain/z_intl_field_config.dart';
import '../domain/z_postal_address.dart';
import '../domain/z_subdivision.dart';
import 'z_country_picker_field.dart';
import 'z_option_picker_field.dart';

/// Champ d'édition adresse (sous-formulaire structuré, patron AD-2).
class ZAddressFieldWidget extends StatefulWidget {
  /// Construit le champ pour [ctx]. [catalog] alimente le sélecteur pays de
  /// l'adresse ; [subdivisionCatalog] (optionnel) bascule le sous-champ `region`
  /// sur un sélecteur d'état/province quand le pays a des subdivisions (E11b-2).
  const ZAddressFieldWidget({
    required this.ctx,
    required this.catalog,
    this.subdivisionCatalog,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = [ZPostalAddress] courant, `ctx.onChanged`
  /// = écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Catalogue pays (paresseux + caché) capturé par closure (AD-4).
  final ZCountryCatalog catalog;

  /// Catalogue subdivisions (optionnel). `null` → le sous-champ `region` reste un
  /// `TextField` libre **identique** à E11a-2 (rétro-compat stricte).
  final ZSubdivisionCatalog? subdivisionCatalog;

  /// Hook de test : appelé UNE FOIS en `initState` (preuve SM-1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous le `kind` `"address"`.
  /// Le [catalog] est capturé par closure (immuable, partageable) ; chaque
  /// montage crée SES contrôleurs de sous-champs (par-montage, MAJEUR-1).
  static ZFieldWidgetBuilder builder({
    ZCountryCatalog? catalog,
    ZSubdivisionCatalog? subdivisionCatalog,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) {
    // LOW-1 : sans `catalog` injecté, partage l'instance par défaut lazy pour
    // que les 3 kinds intl ne lisent l'asset qu'une seule fois (au lieu de 3).
    final cat = catalog ?? sharedDefaultCountryCatalog();
    // `subdivisionCatalog` reste `null` par défaut → rétro-compat E11a-2 stricte
    // (région = texte libre). L'app l'injecte explicitement pour activer les
    // sélecteurs d'état/province.
    return (BuildContext context, ZFieldWidgetContext ctx) => ZAddressFieldWidget(
          ctx: ctx,
          catalog: cat,
          subdivisionCatalog: subdivisionCatalog,
          onInit: onInit,
          onBuild: onBuild,
        );
  }

  @override
  State<ZAddressFieldWidget> createState() => _ZAddressFieldWidgetState();
}

class _ZAddressFieldWidgetState extends State<ZAddressFieldWidget> {
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _region;
  late final TextEditingController _postal;
  late final List<FocusNode> _focusNodes;

  /// Code ISO du pays sélectionné (état local possédé).
  String? _countryIso;

  bool get _hasFocus => _focusNodes.any((f) => f.hasFocus);

  @override
  void initState() {
    super.initState();
    final addr = _addressOf(widget.ctx.value);
    _line1 = TextEditingController(text: addr?.line1 ?? '');
    _line2 = TextEditingController(text: addr?.line2 ?? '');
    _city = TextEditingController(text: addr?.city ?? '');
    _region = TextEditingController(text: addr?.region ?? '');
    _postal = TextEditingController(text: addr?.postalCode ?? '');
    _focusNodes = List<FocusNode>.generate(5, (_) => FocusNode());
    // AC1/AC6 (E11b-2) : pays initial `addr?.countryCode ?? cfg?.defaultCountryIso`
    // (rétro-compat E11a-2 : cfg == null → addr?.countryCode identique).
    _countryIso = addr?.countryCode ?? _config?.defaultCountryIso;
    _ensureSubdivisionsLoaded();
    widget.onInit?.call();
  }

  /// Config additive intl du champ (`null` → chemin E11a-2, rétro-compat).
  ZIntlFieldConfig? get _config {
    final c = widget.ctx.field.config;
    return c is ZIntlFieldConfig ? c : null;
  }

  /// Charge paresseusement le catalogue subdivisions (si injecté + pays connu),
  /// puis rebuild LOCAL une fois résolu (SM-1, jamais de rebuild global).
  void _ensureSubdivisionsLoaded() {
    final cat = widget.subdivisionCatalog;
    if (cat != null && _countryIso != null && !cat.isLoaded) {
      cat.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Subdivisions disponibles pour le pays courant (vide si aucun catalogue
  /// injecté / pays inconnu / non chargé). Une liste non vide bascule le
  /// sous-champ `region` sur un sélecteur d'état/province (E11b-2).
  List<ZSubdivision> get _regionSubdivisions {
    final cat = widget.subdivisionCatalog;
    final iso = _countryIso;
    if (cat == null || iso == null) return const <ZSubdivision>[];
    return cat.forCountry(iso);
  }

  @override
  void didUpdateWidget(covariant ZAddressFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SYNC GUARDÉE (AD-2) : reflet d'une valeur EXTERNE hors focus uniquement.
    if (_hasFocus) return;
    final addr = _addressOf(widget.ctx.value);
    _syncField(_line1, addr?.line1 ?? '');
    _syncField(_line2, addr?.line2 ?? '');
    _syncField(_city, addr?.city ?? '');
    _syncField(_region, addr?.region ?? '');
    _syncField(_postal, addr?.postalCode ?? '');
    if (addr?.countryCode != null && addr!.countryCode != _countryIso) {
      _countryIso = addr.countryCode;
    }
  }

  static void _syncField(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  @override
  void dispose() {
    // Anti-fuite (learning E5) : libérer TOUS les contrôleurs/focus.
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _region.dispose();
    _postal.dispose();
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  ZPostalAddress? _addressOf(Object? value) => value is ZPostalAddress
      ? value
      : ZPostalAddress.fromMapSafe(value);

  /// Voie unique (AD-2) : recompose un [ZPostalAddress] neutre et l'émet ; adresse
  /// entièrement vide → `null` (état neutre).
  void _emit() {
    final addr = ZPostalAddress(
      line1: _nullable(_line1.text),
      line2: _nullable(_line2.text),
      city: _nullable(_city.text),
      region: _nullable(_region.text),
      postalCode: _nullable(_postal.text),
      countryCode: _countryIso,
    );
    widget.ctx.onChanged(addr.isEmpty ? null : addr);
  }

  void _onCountrySelected(ZCountryInfo country) {
    setState(() => _countryIso = country.isoCode);
    // Le pays a changé → recharger/rafraîchir les subdivisions disponibles.
    _ensureSubdivisionsLoaded();
    _emit();
  }

  void _onSubdivisionSelected(ZSubdivision s) {
    // Voie unique : la région porte le code ISO 3166-2 (String neutre).
    _region.text = s.code;
    _emit();
  }

  static String? _nullable(String v) => v.trim().isEmpty ? null : v;

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final readOnly = field.readOnly;
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
            _line(
              const Key('z-address-line1'),
              _line1,
              _focusNodes[0],
              label(context, 'intl.address.line1', fallback: 'Adresse'),
              readOnly,
            ),
            SizedBox(height: theme.gapS),
            _line(
              const Key('z-address-line2'),
              _line2,
              _focusNodes[1],
              label(context, 'intl.address.line2', fallback: 'Complément'),
              readOnly,
            ),
            SizedBox(height: theme.gapS),
            _line(
              const Key('z-address-city'),
              _city,
              _focusNodes[2],
              label(context, 'intl.address.city', fallback: 'Ville'),
              readOnly,
            ),
            SizedBox(height: theme.gapS),
            _regionSlot(theme, readOnly),
            SizedBox(height: theme.gapS),
            _line(
              const Key('z-address-postal'),
              _postal,
              _focusNodes[4],
              label(context, 'intl.address.postalCode', fallback: 'Code postal'),
              readOnly,
            ),
            SizedBox(height: theme.gapS),
            ZCountryPickerField(
              catalog: widget.catalog,
              selectedIso: _countryIso,
              readOnly: readOnly,
              preferredIsos: _config?.preferredCountryIsos ?? const <String>[],
              searchable: _config?.searchable ?? true,
              semanticLabel:
                  label(context, 'intl.address.country', fallback: 'Pays'),
              onSelected: _onCountrySelected,
            ),
          ],
        ),
      ),
    );
  }

  /// Sous-champ `region` : sélecteur d'état/province **si** le pays a des
  /// subdivisions au catalogue injecté ; sinon `TextField` libre **identique** à
  /// E11a-2 (rétro-compat stricte — sans `subdivisionCatalog`, ce chemin est le
  /// seul emprunté).
  Widget _regionSlot(ZcrudTheme theme, bool readOnly) {
    final subs = _regionSubdivisions;
    final regionLabel =
        label(context, 'intl.address.region', fallback: 'Région');
    if (subs.isEmpty) {
      return _line(
        const Key('z-address-region'),
        _region,
        _focusNodes[3],
        regionLabel,
        readOnly,
      );
    }
    final iso = _countryIso!;
    final currentCode = _region.text.trim();
    final selected = currentCode.isEmpty
        ? null
        : widget.subdivisionCatalog!.byCode(iso, currentCode);
    return ZOptionPickerField<ZSubdivision>(
      key: const Key('z-address-region-state'),
      keyPrefix: 'z-address-state',
      readOnly: readOnly,
      searchable: _config?.searchable ?? true,
      semanticLabel: regionLabel,
      selectedTitle: selected?.name ?? (currentCode.isEmpty ? null : currentCode),
      search: (q) {
        final query = q.trim().toLowerCase();
        if (query.isEmpty) return subs;
        return <ZSubdivision>[
          for (final s in subs)
            if (s.code.toLowerCase().contains(query) ||
                (s.name?.toLowerCase().contains(query) ?? false))
              s,
        ];
      },
      itemKey: (s) => s.code,
      itemTitle: (s) => s.name ?? s.code,
      itemTrailing: (s) => s.code,
      onSelected: _onSubdivisionSelected,
    );
  }

  Widget _line(
    Key key,
    TextEditingController controller,
    FocusNode focusNode,
    String labelText,
    bool readOnly,
  ) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: TextField(
          key: key,
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          textAlign: TextAlign.start,
          decoration: InputDecoration(isDense: true, labelText: labelText),
          onChanged: readOnly ? null : (_) => _emit(),
        ),
      );
}
