/// `ZAddressFieldWidget` — **champ d'édition adresse postale** (`address` /
/// `addressSearchField`), servi via `ZWidgetRegistry` (E11a-2 + gap B10/DP-8,
/// AD-2/AD-4/AD-13/AD-10).
///
/// origine: le dispatcher du cœur route `address` vers le `ZWidgetRegistry`
/// injecté. Ce champ est un **sous-formulaire structuré** (lignes, ville, région,
/// code postal, pays) émettant un [ZPostalAddress] **neutre** via `ctx.onChanged`.
///
/// **AD-2** : un `TextEditingController`/`FocusNode` **stable par sous-champ**
/// (créés 1× en `initState`, disposés) ; sync guardée hors focus ; jamais de
/// reconstruction globale. Le sélecteur pays est le même composant inline que
/// [ZCountryFieldWidget] (catalogue capturé par closure, AD-4).
///
/// **DP-8 (gap B10)** : compat schéma **String legacy** (DODLP) via
/// [ZAddressCodec] — une valeur de tranche `String` est ingérée sans crash
/// (portée dans `formatted`). Un seam **[ZPlaceSearchProvider]** optionnel
/// (injecté par closure, AD-4 ; ZÉRO clé/endpoint/réseau dans le package) active
/// une **affordance de recherche** (loupe) dont le remplissage passe par la
/// **voie d'émission UNIQUE** `_emit()` (AD-2). Sans provider ⇒ comportement
/// **strictement identique** à E11a-2/E11b-2 (rétro-compat).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_country_catalog.dart';
import '../data/z_subdivision_catalog.dart';
import '../domain/z_address_codec.dart';
import '../domain/z_country_info.dart';
import '../domain/z_intl_field_config.dart';
import '../domain/z_place_search_provider.dart';
import '../domain/z_postal_address.dart';
import '../domain/z_subdivision.dart';
import 'z_country_picker_field.dart';
import 'z_option_picker_field.dart';

/// `kind` canonique du champ adresse structuré (parité DODLP `address`).
const String addressFieldKind = 'address';

/// `kind` de recherche d'adresse (parité DODLP `addressSearchField`) — **mêmes**
/// rendu et widget que [addressFieldKind] (mapping n:1).
const String addressSearchFieldKind = 'addressSearchField';

/// Enregistre [ZAddressFieldWidget] sous les **deux** kinds [addressFieldKind]
/// (`"address"`) **et** [addressSearchFieldKind] (`"addressSearchField"`) dans
/// [registry] (parité DODLP, rendu identique — gap B10/DP-8).
///
/// Le **même** builder (donc le même [placeSearch]/catalogues capturés par
/// closure, AD-4) sert les deux kinds. Point d'enregistrement **app/binding** :
/// le cœur reste agnostique (aucune modif de `zcrud_core`).
void registerZAddressFieldWidgets(
  ZWidgetRegistry registry, {
  ZCountryCatalog? catalog,
  ZSubdivisionCatalog? subdivisionCatalog,
  ZPlaceSearchProvider? placeSearch,
  VoidCallback? onInit,
  VoidCallback? onBuild,
}) {
  final builder = ZAddressFieldWidget.builder(
    catalog: catalog,
    subdivisionCatalog: subdivisionCatalog,
    placeSearch: placeSearch,
    onInit: onInit,
    onBuild: onBuild,
  );
  registry.register(addressFieldKind, builder);
  registry.register(addressSearchFieldKind, builder);
}

/// Champ d'édition adresse (sous-formulaire structuré, patron AD-2).
class ZAddressFieldWidget extends StatefulWidget {
  /// Construit le champ pour [ctx]. [catalog] alimente le sélecteur pays de
  /// l'adresse ; [subdivisionCatalog] (optionnel) bascule le sous-champ `region`
  /// sur un sélecteur d'état/province quand le pays a des subdivisions (E11b-2).
  /// [placeSearch] (optionnel, DP-8) active l'affordance de recherche géo.
  const ZAddressFieldWidget({
    required this.ctx,
    required this.catalog,
    this.subdivisionCatalog,
    this.placeSearch,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = [ZPostalAddress]/`Map`/`String` legacy
  /// courant, `ctx.onChanged` = écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Catalogue pays (paresseux + caché) capturé par closure (AD-4).
  final ZCountryCatalog catalog;

  /// Catalogue subdivisions (optionnel). `null` → le sous-champ `region` reste un
  /// `TextField` libre **identique** à E11a-2 (rétro-compat stricte).
  final ZSubdivisionCatalog? subdivisionCatalog;

  /// Seam de recherche géographique (optionnel, DP-8). `null` → **aucune**
  /// affordance de recherche (rétro-compat stricte E11a-2/E11b-2). Injecté par
  /// closure (AD-4) ; ZÉRO clé/endpoint/réseau dans le package.
  final ZPlaceSearchProvider? placeSearch;

  /// Hook de test : appelé UNE FOIS en `initState` (preuve SM-1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous un `kind` adresse. Le
  /// [catalog]/[subdivisionCatalog]/[placeSearch] sont capturés par closure
  /// (immuables/partageables) ; chaque montage crée SES contrôleurs de
  /// sous-champs (par-montage, MAJEUR-1).
  static ZFieldWidgetBuilder builder({
    ZCountryCatalog? catalog,
    ZSubdivisionCatalog? subdivisionCatalog,
    ZPlaceSearchProvider? placeSearch,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) {
    // LOW-1 : sans `catalog` injecté, partage l'instance par défaut lazy pour
    // que les 3 kinds intl ne lisent l'asset qu'une seule fois (au lieu de 3).
    final cat = catalog ?? sharedDefaultCountryCatalog();
    // `subdivisionCatalog`/`placeSearch` restent `null` par défaut → rétro-compat
    // E11a-2/E11b-2 stricte (région = texte libre, aucune recherche). L'app les
    // injecte explicitement pour activer subdivisions / recherche géo.
    return (BuildContext context, ZFieldWidgetContext ctx) => ZAddressFieldWidget(
          ctx: ctx,
          catalog: cat,
          subdivisionCatalog: subdivisionCatalog,
          placeSearch: placeSearch,
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

  /// Rendu formaté courant (DP-8) : porté par une String legacy ingérée
  /// ([ZAddressCodec.decodeString]) OU renseigné par une sélection Places. Effacé
  /// dès qu'un sous-champ est édité **manuellement** (le rendu n'est plus
  /// autoritatif). `null` par défaut → chemin E11a-2 identique (rétro-compat).
  String? _formatted;

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
    // DP-8 : rendu formaté initial (String legacy → `formatted`, sinon `null`).
    _formatted = addr?.formatted;
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
    // DP-8 : refléter le rendu formaté externe (String legacy ré-ingérée).
    _formatted = addr?.formatted;
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

  /// Route une valeur de tranche vers un [ZPostalAddress] (défensif AD-10) :
  /// [ZPostalAddress] direct → tel quel ; **`String` legacy** (DP-8) →
  /// [ZAddressCodec.decodeString] (portée dans `formatted`) ; `Map` →
  /// [ZPostalAddress.fromMapSafe] ; sinon `null`. Ne throw jamais.
  ZPostalAddress? _addressOf(Object? value) {
    if (value is ZPostalAddress) return value;
    final decoded = ZAddressCodec.decodeString(value);
    if (decoded != null) return decoded;
    return ZPostalAddress.fromMapSafe(value);
  }

  /// Voie unique (AD-2) : recompose un [ZPostalAddress] neutre et l'émet ; adresse
  /// entièrement vide → `null` (état neutre). Le rendu [_formatted] courant est
  /// conservé (String legacy / Places), `null` en édition structurée native.
  void _emit() {
    final addr = ZPostalAddress(
      line1: _nullable(_line1.text),
      line2: _nullable(_line2.text),
      city: _nullable(_city.text),
      region: _nullable(_region.text),
      postalCode: _nullable(_postal.text),
      countryCode: _countryIso,
      formatted: _nullable(_formatted ?? ''),
    );
    widget.ctx.onChanged(addr.isEmpty ? null : addr);
  }

  /// Édition **manuelle** d'un sous-champ : le rendu formaté n'est plus
  /// autoritatif → l'effacer, puis émettre (voie unique AD-2).
  void _onManualEdit() {
    // LOW-1 (DP-8) : rafraîchir l'aperçu via setState (comme _onCountrySelected)
    // pour que le rendu formaté disparaisse immédiatement à l'édition manuelle.
    if (_formatted != null) {
      setState(() => _formatted = null);
    }
    _emit();
  }

  void _onCountrySelected(ZCountryInfo country) {
    setState(() {
      _countryIso = country.isoCode;
      _formatted = null;
    });
    // Le pays a changé → recharger/rafraîchir les subdivisions disponibles.
    _ensureSubdivisionsLoaded();
    _emit();
  }

  void _onSubdivisionSelected(ZSubdivision s) {
    // Voie unique : la région porte le code ISO 3166-2 (String neutre).
    _region.text = s.code;
    _formatted = null;
    _emit();
  }

  /// Ouvre la recherche géo (DP-8) : `search` → sélection prédiction → `details`
  /// → remplissage via la **voie d'émission UNIQUE** [_fillFromPlace]. No-op si
  /// aucun [ZPlaceSearchProvider] injecté (rétro-compat).
  Future<void> _openPlaceSearch() async {
    final provider = widget.placeSearch;
    if (provider == null) return;
    final iso = _countryIso;
    final selected = await showDialog<ZPostalAddress>(
      context: context,
      builder: (dialogContext) => _PlaceSearchDialog(
        provider: provider,
        countryIso: iso,
      ),
    );
    if (!mounted || selected == null) return;
    _fillFromPlace(selected);
  }

  /// Remplit les sous-champs + `formatted` depuis un [ZPostalAddress] résolu par
  /// le seam, puis émet **une seule fois** (voie unique AD-2 : aucun rebuild
  /// global, un seul `ctx.onChanged`).
  void _fillFromPlace(ZPostalAddress a) {
    setState(() {
      _line1.text = a.line1 ?? '';
      _line2.text = a.line2 ?? '';
      _city.text = a.city ?? '';
      _region.text = a.region ?? '';
      _postal.text = a.postalCode ?? '';
      if (a.countryCode != null && a.countryCode!.isNotEmpty) {
        _countryIso = a.countryCode;
      }
      _formatted = _nullable(a.formatted ?? '');
    });
    _ensureSubdivisionsLoaded();
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
            _header(resolvedLabel, readOnly, theme),
            SizedBox(height: theme.gapS),
            if (_notBlank(_formatted)) ...<Widget>[
              _formattedPreview(theme),
              SizedBox(height: theme.gapS),
            ],
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

  /// En-tête : libellé + (DP-8) affordance de recherche géo si un
  /// [ZPlaceSearchProvider] est injecté. Sans provider ⇒ **aucun** bouton
  /// (rétro-compat stricte).
  Widget _header(String resolvedLabel, bool readOnly, ZcrudTheme theme) {
    final hasSearch = widget.placeSearch != null;
    if (!hasSearch) {
      return Text(resolvedLabel, style: TextStyle(color: theme.labelColor));
    }
    final searchLabel = label(
      context,
      'intl.address.search',
      fallback: 'Rechercher une adresse',
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(resolvedLabel, style: TextStyle(color: theme.labelColor)),
        ),
        Semantics(
          button: true,
          label: searchLabel,
          child: IconButton(
            key: const Key('z-address-search-button'),
            icon: const Icon(Icons.search),
            tooltip: searchLabel,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: readOnly ? null : _openPlaceSearch,
          ),
        ),
      ],
    );
  }

  /// Aperçu **lecture seule** du rendu formaté (String legacy / Places) — DP-8 :
  /// « la String legacy s'affiche dans un sous-champ via `formatted` » sans
  /// crash. Ne participe PAS à la (ré)émission structurée.
  Widget _formattedPreview(ZcrudTheme theme) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: InputDecorator(
          // Aperçu lecture seule SANS `TextEditingController` (aucune fuite, non
          // recréé au build) : rendu textuel neutre, hors voie de (ré)émission.
          decoration: InputDecoration(
            isDense: true,
            labelText: label(
              context,
              'intl.address.formatted',
              fallback: 'Adresse (rendu)',
            ),
          ),
          child: Text(
            _formatted ?? '',
            key: const Key('z-address-formatted'),
            textAlign: TextAlign.start,
          ),
        ),
      );

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
          onChanged: readOnly ? null : (_) => _onManualEdit(),
        ),
      );

  static bool _notBlank(String? v) => v != null && v.trim().isNotEmpty;
}

/// Dialogue de recherche géo (DP-8) : saisie → `search` (mock/impl app-fournie)
/// → liste de prédictions → `details` → renvoie le [ZPostalAddress] résolu.
/// Aucun réseau/clé ici : tout passe par le seam [ZPlaceSearchProvider] injecté.
class _PlaceSearchDialog extends StatefulWidget {
  const _PlaceSearchDialog({required this.provider, this.countryIso});

  final ZPlaceSearchProvider provider;
  final String? countryIso;

  @override
  State<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<_PlaceSearchDialog> {
  List<ZPlacePrediction> _predictions = const <ZPlacePrediction>[];
  bool _searching = false;

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _predictions = const <ZPlacePrediction>[]);
      return;
    }
    setState(() => _searching = true);
    final result =
        await widget.provider.search(query, countryIso: widget.countryIso);
    if (!mounted) return;
    setState(() {
      _predictions = result;
      _searching = false;
    });
  }

  Future<void> _pick(ZPlacePrediction prediction) async {
    final address = await widget.provider.details(prediction.placeId);
    if (!mounted) return;
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final title =
        label(context, 'intl.address.search', fallback: 'Rechercher une adresse');
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.start),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const Key('z-address-search-input'),
              autofocus: true,
              textAlign: TextAlign.start,
              decoration: InputDecoration(
                isDense: true,
                labelText: title,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _runSearch,
              onSubmitted: _runSearch,
            ),
            SizedBox(height: theme.gapS),
            if (_searching)
              const Padding(
                padding: EdgeInsetsDirectional.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return ListTile(
                    key: Key('z-address-prediction-${prediction.placeId}'),
                    title: Text(prediction.description, textAlign: TextAlign.start),
                    onTap: () => _pick(prediction),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('z-address-search-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            label(context, 'intl.address.searchCancel', fallback: 'Annuler'),
          ),
        ),
      ],
    );
  }
}
