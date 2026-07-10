/// `ZStateField` — **champ d'édition état/province dépendant du pays** (E11b-2,
/// AD-2/AD-4/AD-13/AD-10).
///
/// origine: FR-21 demande un champ **état/province**. Comme il n'existe **aucune**
/// valeur `EditionFieldType.state` (cœur figé, AD-1), ce champ est **composable**
/// (via [ZStateField.builder]) et sert aussi le sous-champ `region` de
/// `ZAddressField`. Il émet le **code ISO 3166-2 `String`** de la subdivision
/// choisie ; **si le pays n'a aucune subdivision** au catalogue (ou pays inconnu),
/// il **replie sur un champ texte libre** (jamais un champ mort ni un throw).
///
/// **AD-2** : contrôleur/focus du repli texte créés **1×** (`initState`),
/// disposés ; le sélecteur réutilise le picker inline générique (a11y/RTL
/// factorisés). Chargement paresseux du catalogue → rebuild **local**.
///
/// **AD-4** : catalogue capturé par closure ; pays résolu **par champ** via le
/// paramètre [countryIso] **ou** `ctx.field.config`
/// ([ZIntlFieldConfig.defaultCountryIso]).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_subdivision_catalog.dart';
import '../domain/z_intl_field_config.dart';
import '../domain/z_subdivision.dart';
import 'z_option_picker_field.dart';

/// Champ d'édition état/province (sélecteur dépendant du pays, repli texte libre).
class ZStateField extends StatefulWidget {
  /// Construit le champ pour [ctx]. [catalog] fournit les subdivisions ;
  /// [countryIso] fixe le pays (sinon lu depuis `ctx.field.config`).
  const ZStateField({
    required this.ctx,
    required this.catalog,
    this.countryIso,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = code ISO 3166-2 `String` OU texte libre,
  /// `ctx.onChanged` = écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Catalogue subdivisions (paresseux + caché) capturé par closure (AD-4).
  final ZSubdivisionCatalog catalog;

  /// Pays courant (code ISO alpha-2). `null` → lu depuis
  /// [ZIntlFieldConfig.defaultCountryIso].
  final String? countryIso;

  /// Hook de test : appelé UNE FOIS en `initState` (preuve SM-1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous un `kind` au choix de
  /// l'app. Le [catalog] est capturé par closure ; [countryIso] fixe le pays.
  static ZFieldWidgetBuilder builder({
    ZSubdivisionCatalog? catalog,
    String? countryIso,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) {
    final cat = catalog ?? sharedDefaultSubdivisionCatalog();
    return (BuildContext context, ZFieldWidgetContext ctx) => ZStateField(
          ctx: ctx,
          catalog: cat,
          countryIso: countryIso,
          onInit: onInit,
          onBuild: onBuild,
        );
  }

  @override
  State<ZStateField> createState() => _ZStateFieldState();
}

class _ZStateFieldState extends State<ZStateField> {
  /// Contrôleur du repli texte libre — créé 1× (`initState`), jamais recréé.
  late final TextEditingController _freeController;

  /// Focus du repli texte — oracle de la sync guardée.
  late final FocusNode _freeFocus;

  bool get _hasFreeFocus => _freeFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _freeController = TextEditingController(text: _valueOf(widget.ctx.value));
    _freeFocus = FocusNode();
    final iso = _countryIso;
    if (iso != null && !widget.catalog.isLoaded) {
      widget.catalog.load().then((_) {
        if (mounted) setState(() {});
      });
    }
    widget.onInit?.call();
  }

  @override
  void didUpdateWidget(covariant ZStateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le pays a pu changer (intégration adresse) → recharger si nécessaire.
    if (_countryIso != null && !widget.catalog.isLoaded) {
      widget.catalog.load().then((_) {
        if (mounted) setState(() {});
      });
    }
    // SYNC GUARDÉE (AD-2) : reflet d'une valeur EXTERNE hors focus uniquement.
    if (_hasFreeFocus) return;
    final external = _valueOf(widget.ctx.value);
    if (_freeController.text != external) _freeController.text = external;
  }

  @override
  void dispose() {
    // Anti-fuite (learning E5).
    _freeController.dispose();
    _freeFocus.dispose();
    super.dispose();
  }

  ZIntlFieldConfig? get _config {
    final c = widget.ctx.field.config;
    return c is ZIntlFieldConfig ? c : null;
  }

  /// Pays courant : paramètre widget prioritaire, sinon défaut de config.
  String? get _countryIso => widget.countryIso ?? _config?.defaultCountryIso;

  /// Lecture défensive (AD-10) : la tranche est un `String` (code ou texte) ;
  /// tout autre type → `''`.
  static String _valueOf(Object? value) =>
      value is String ? value : '';

  String? get _selectedCode {
    final v = widget.ctx.value;
    return v is String && v.isNotEmpty ? v : null;
  }

  void _onSubdivisionSelected(ZSubdivision s) {
    _freeController.text = s.code;
    widget.ctx.onChanged(s.code);
  }

  void _emitFree() {
    final v = _freeController.text.trim();
    widget.ctx.onChanged(v.isEmpty ? null : _freeController.text);
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final iso = _countryIso;
    final subs = iso == null
        ? const <ZSubdivision>[]
        : widget.catalog.forCountry(iso);
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
            if (subs.isNotEmpty)
              _picker(iso!, subs, resolvedLabel, field.readOnly)
            else
              _freeText(resolvedLabel, field.readOnly),
          ],
        ),
      ),
    );
  }

  Widget _picker(
    String iso,
    List<ZSubdivision> subs,
    String resolvedLabel,
    bool readOnly,
  ) {
    final selected = _selectedCode == null
        ? null
        : widget.catalog.byCode(iso, _selectedCode!);
    final cfg = _config;
    return ZOptionPickerField<ZSubdivision>(
      keyPrefix: 'z-state',
      readOnly: readOnly,
      searchable: cfg?.searchable ?? true,
      semanticLabel: label(context, 'intl.state', fallback: 'État/Province'),
      selectedTitle: selected?.name ?? _selectedCode,
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

  Widget _freeText(String resolvedLabel, bool readOnly) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: TextField(
          key: const Key('z-state-free'),
          controller: _freeController,
          focusNode: _freeFocus,
          readOnly: readOnly,
          textAlign: TextAlign.start,
          decoration: InputDecoration(
            isDense: true,
            labelText: label(context, 'intl.state', fallback: 'État/Province'),
          ),
          onChanged: readOnly ? null : (_) => _emitFree(),
        ),
      );
}
