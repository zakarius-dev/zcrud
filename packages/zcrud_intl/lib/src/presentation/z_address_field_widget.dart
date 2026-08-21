/// `ZAddressFieldWidget` — **champ d'édition adresse postale** (`address` /
/// `addressSearchField`), servi via `ZWidgetRegistry` (invariants AD-2,
/// AD-4, AD-13, AD-10).
///
/// Le dispatcher du cœur route `address` vers le `ZWidgetRegistry` injecté.
/// Ce champ est un **sous-formulaire structuré** (lignes, ville, région,
/// code postal, pays) émettant un [ZPostalAddress] **neutre** via
/// `ctx.onChanged`.
///
/// **Décoration thémée du cœur.** Toutes les `InputDecoration` nues du
/// champ (lignes, ville, région, code postal, aperçu formaté, saisie du
/// dialogue de recherche) passent par la fabrique centrale du cœur
/// `ZcrudTheme.inputDecoration` — jetons **existants** uniquement
/// (`fieldFillColor`, `fieldBorderColor`, `inputRadius`,
/// `inputContentPadding`), repli `ColorScheme` inchangé.
///
/// **Cas particulier assumé : l'adresse est un groupe.** Il n'existe aucune
/// saisie unique à qui accrocher un libellé flottant de groupe ; le
/// libellé du champ reste donc un **en-tête**, mais rendu par le
/// `ZFieldLabel` du cœur (style thémé + astérisque requis) et **décoratif**
/// (`ExcludeSemantics`) — le nœud conteneur l'annonce déjà. En
/// `fieldSize == large` (`bare`), l'en-tête **et** le libellé du nœud
/// conteneur disparaissent : `ZLargeFieldCard` les porte. Les
/// **sous-champs** ne sont jamais `bare` : leur libellé (« Ville », « Code
/// postal »…) n'est porté par personne d'autre.
///
/// Le `Padding(ZcrudTheme.fieldPadding)` propre au champ est retiré (le
/// groupe s'aligne ainsi sur la largeur des champs voisins du cœur).
///
/// **Invariant AD-2** : un `TextEditingController`/`FocusNode` **stable
/// par sous-champ** (créés 1× en `initState`, disposés) ; sync guardée
/// hors focus ; jamais de reconstruction globale. Le sélecteur pays est le
/// même composant inline que [ZCountryFieldWidget] (catalogue capturé par
/// closure, invariant AD-4).
///
/// **Compatibilité de schéma** : compat schéma **String legacy** via
/// [ZAddressCodec] — une valeur de tranche `String` est ingérée sans crash
/// (portée dans `formatted`). Un seam **[ZPlaceSearchProvider]** optionnel
/// (injecté par closure, invariant AD-4 ; zéro clé/endpoint/réseau dans le
/// package) active une **affordance de recherche** (loupe) dont le
/// remplissage passe par la **voie d'émission unique** `_emit()`
/// (invariant AD-2). Sans provider ⇒ comportement **strictement
/// identique** sans recherche.
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

/// `kind` canonique du champ adresse structuré.
const String addressFieldKind = 'address';

/// `kind` de recherche d'adresse — **mêmes** rendu et widget que
/// [addressFieldKind] (mapping n:1).
const String addressSearchFieldKind = 'addressSearchField';

/// Enregistre [ZAddressFieldWidget] sous les **deux** kinds
/// [addressFieldKind] (`"address"`) **et** [addressSearchFieldKind]
/// (`"addressSearchField"`) dans [registry], avec un rendu identique.
///
/// Le **même** builder (donc le même [placeSearch]/catalogues capturés par
/// closure, invariant AD-4) sert les deux kinds. Point d'enregistrement
/// **app/binding** : le cœur reste agnostique (aucune modif de
/// `zcrud_core`).
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
  /// l'adresse ; [subdivisionCatalog] (optionnel) bascule le sous-champ
  /// `region` sur un sélecteur d'état/province quand le pays a des
  /// subdivisions. [placeSearch] (optionnel) active l'affordance de
  /// recherche géo.
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

  /// Catalogue subdivisions (optionnel). `null` → le sous-champ `region`
  /// reste un `TextField` libre **identique** au comportement sans
  /// catalogue (rétro-compat stricte).
  final ZSubdivisionCatalog? subdivisionCatalog;

  /// Seam de recherche géographique (optionnel). `null` → **aucune**
  /// affordance de recherche (rétro-compat stricte). Injecté par closure
  /// (invariant AD-4) ; zéro clé/endpoint/réseau dans le package.
  final ZPlaceSearchProvider? placeSearch;

  /// Hook de test: appelé UNE FOIS en `initState`.
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test: appelé à chaque (re)build (compteur ciblé).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous un `kind` adresse. Le
  /// [catalog]/[subdivisionCatalog]/[placeSearch] sont capturés par closure
  /// (immuables/partageables) ; chaque montage crée SES contrôleurs de
  /// sous-champs (par-montage).
  static ZFieldWidgetBuilder builder({
    ZCountryCatalog? catalog,
    ZSubdivisionCatalog? subdivisionCatalog,
    ZPlaceSearchProvider? placeSearch,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) {
    // Sans `catalog` injecté, partage l'instance par défaut lazy pour que
    // les 3 kinds intl ne lisent l'asset qu'une seule fois (au lieu de 3).
    final cat = catalog ?? sharedDefaultCountryCatalog();
    // `subdivisionCatalog`/`placeSearch` restent `null` par défaut →
    // rétro-compat stricte (région = texte libre, aucune recherche). L'app
    // les injecte explicitement pour activer subdivisions / recherche géo.
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

  /// Rendu formaté courant : porté par une String legacy ingérée
  /// ([ZAddressCodec.decodeString]) OU renseigné par une sélection Places.
  /// Effacé dès qu'un sous-champ est édité **manuellement** (le rendu n'est
  /// plus autoritatif). `null` par défaut → comportement identique à
  /// l'absence de rendu formaté (rétro-compat).
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
    // Pays initial: `addr?.countryCode ?? cfg?.defaultCountryIso` (rétro-
    // compat: cfg == null → addr?.countryCode identique).
    _countryIso = addr?.countryCode ?? _config?.defaultCountryIso;
    // Rendu formaté initial (String legacy → `formatted`, sinon `null`).
    _formatted = addr?.formatted;
    _ensureSubdivisionsLoaded();
    widget.onInit?.call();
  }

  /// Config additive intl du champ (`null` → comportement par défaut,
  /// rétro-compat).
  ZIntlFieldConfig? get _config {
    final c = widget.ctx.field.config;
    return c is ZIntlFieldConfig ? c : null;
  }

  /// Charge paresseusement le catalogue subdivisions (si injecté + pays connu),
  /// puis rebuild LOCAL une fois résolu (jamais de rebuild global).
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
  /// sous-champ `region` sur un sélecteur d'état/province.
  List<ZSubdivision> get _regionSubdivisions {
    final cat = widget.subdivisionCatalog;
    final iso = _countryIso;
    if (cat == null || iso == null) return const <ZSubdivision>[];
    return cat.forCountry(iso);
  }

  @override
  void didUpdateWidget(covariant ZAddressFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SYNC GUARDÉE (AD-2): reflet d'une valeur EXTERNE hors focus uniquement.
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
    // Refléter le rendu formaté externe (String legacy ré-ingérée).
    _formatted = addr?.formatted;
  }

  static void _syncField(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  @override
  void dispose() {
    // Anti-fuite (learning E5): libérer TOUS les contrôleurs/focus.
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

  /// Route une valeur de tranche vers un [ZPostalAddress] (défensif AD-10):
  /// [ZPostalAddress] direct → tel quel; **`String` legacy** →
  /// [ZAddressCodec.decodeString] (portée dans `formatted`); `Map` →
  /// [ZPostalAddress.fromMapSafe]; sinon `null`. Ne throw jamais.
  ZPostalAddress? _addressOf(Object? value) {
    if (value is ZPostalAddress) return value;
    final decoded = ZAddressCodec.decodeString(value);
    if (decoded != null) return decoded;
    return ZPostalAddress.fromMapSafe(value);
  }

  /// Voie unique (AD-2): recompose un [ZPostalAddress] neutre et l'émet; adresse
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

  /// Édition **manuelle** d'un sous-champ: le rendu formaté n'est plus
  /// autoritatif → l'effacer, puis émettre (voie unique AD-2).
  void _onManualEdit() {
    // Rafraîchir l'aperçu via setState (comme _onCountrySelected)
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
    // Voie unique: la région porte le code ISO 3166-2 (String neutre).
    _region.text = s.code;
    _formatted = null;
    _emit();
  }

  /// Ouvre la recherche géo: `search` → sélection prédiction → `details`
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
  /// le seam, puis émet **une seule fois** (voie unique AD-2: aucun rebuild
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

  /// Rendu `bare` — dérivé de la spec **exactement comme le dispatcher du cœur**
  /// (`fieldSize == large`): la Card porte alors le libellé du GROUPE.
  bool get _bare => widget.ctx.field.fieldSize == ZFieldSize.large;

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = label(
      context,
      field.label ?? field.name,
      fallback: field.label ?? field.name,
    );
    final readOnly = field.readOnly;
    final bare = _bare;
    // L'adresse est un SOUS-FORMULAIRE: il n'existe aucune saisie unique à
    // qui accrocher un libellé flottant de groupe. Le libellé du groupe reste
    // donc porté par l'en-tête (hors `bare`) et par le nœud sémantique
    // conteneur — mais **une seule fois**: l'en-tête est décoratif
    // (`ExcludeSemantics`), sans quoi il se fondait dans le nœud conteneur et
    // le libellé était annoncé deux fois (mesuré). En `bare`, l'en-tête ET le
    // libellé sémantique disparaissent: `ZLargeFieldCard` les porte déjà.
    return Semantics(
      container: true,
      label: bare ? null : resolvedLabel,
      // Le `Padding(fieldPadding)` propre au champ est retiré (cf. dartdoc):
      // mesuré, il rendait le bloc 24 dp plus étroit que ses voisins du cœur.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!bare || widget.placeSearch != null) ...<Widget>[
            _header(field, resolvedLabel, readOnly, bare),
            SizedBox(height: theme.gapS),
          ],
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
            // Sous-champ pays du GROUPE: sa décoration porte son PROPRE
            // libellé (« Pays »), jamais celui du champ adresse — donc jamais
            // le mode `bare`, même quand le groupe est en Card.
            decoration: _subDecoration(
              theme,
              label(context, 'intl.address.country', fallback: 'Pays'),
            ),
            onSelected: _onCountrySelected,
          ),
        ],
      ),
    );
  }

  /// Décoration THÉMÉE d'un **sous-champ** du groupe adresse : la fabrique
  /// centrale du cœur
  /// (`ZcrudTheme.inputDecoration`), pilotée par les jetons **existants**
  /// (`fieldFillColor`/`fieldBorderColor`/`inputRadius`/`inputContentPadding`),
  /// avec le libellé PROPRE au sous-champ.
  ///
  /// Jamais `bare`: le mode `bare` signifie « le libellé est porté par la
  /// Card », or la Card ne porte que le libellé du GROUPE. Rendre les
  /// sous-champs nus les priverait de leur seul libellé (« Ville », « Code
  /// postal »…) — l'erreur exacte que ce lot corrige.
  InputDecoration _subDecoration(ZcrudTheme theme, String labelText) =>
      theme.inputDecoration(context, label: labelText);

  /// En-tête: libellé + affordance de recherche géo si un
  /// [ZPlaceSearchProvider] est injecté. Sans provider ⇒ **aucun** bouton
  /// (rétro-compat stricte).
  /// [bare] ⇒ le libellé est porté par `ZLargeFieldCard`: l'en-tête ne rend
  /// alors QUE l'affordance de recherche (il n'est monté que s'il y en a une).
  Widget _header(
    ZFieldSpec field,
    String resolvedLabel,
    bool readOnly,
    bool bare,
  ) {
    final hasSearch = widget.placeSearch != null;
    // Libellé enrichi du CŒUR (`ZFieldLabel`: style thémé + astérisque requis
    // décoratif) — plus de `TextStyle(color:)` monté à la main. `ExcludeSemantics`
    //: le libellé est déjà annoncé par le nœud conteneur du groupe (sans quoi
    // il l'était DEUX fois — mesuré sur l'arbre sémantique).
    final labelWidget = bare
        ? const SizedBox.shrink()
        : ExcludeSemantics(child: ZFieldLabel(field: field));
    if (!hasSearch) {
      return labelWidget;
    }
    final searchLabel = label(
      context,
      'intl.address.search',
      fallback: 'Rechercher une adresse',
    );
    return Row(
      children: <Widget>[
        Expanded(child: labelWidget),
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

  /// Aperçu **lecture seule** du rendu formaté (String legacy / Places) : la
  /// String legacy s'affiche dans un sous-champ via `formatted` sans crash.
  /// Ne participe pas à la (ré)émission structurée.
  Widget _formattedPreview(ZcrudTheme theme) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: InputDecorator(
          // Aperçu lecture seule SANS `TextEditingController` (aucune fuite,
          // non recréé au build) : rendu textuel neutre, hors voie de
          // (ré)émission.
          decoration: _subDecoration(
            theme,
            label(
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
  /// subdivisions au catalogue injecté ; sinon `TextField` libre
  /// **identique** au comportement sans catalogue (rétro-compat stricte —
  /// sans `subdivisionCatalog`, ce chemin est le seul emprunté).
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
      // Sous-champ du groupe: décoration thémée portant SON libellé — sans
      // quoi la région passerait d'encartée (TextField) à nue (sélecteur) selon
      // que le catalogue de subdivisions est injecté ou non.
      decoration: _subDecoration(theme, regionLabel),
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
          decoration: _subDecoration(ZcrudTheme.of(context), labelText),
          onChanged: readOnly ? null : (_) => _onManualEdit(),
        ),
      );

  static bool _notBlank(String? v) => v != null && v.trim().isNotEmpty;
}

/// Dialogue de recherche géo: saisie → `search` (mock/impl app-fournie)
/// → liste de prédictions → `details` → renvoie le [ZPostalAddress] résolu.
/// Aucun réseau/clé ici: tout passe par le seam [ZPlaceSearchProvider] injecté.
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
              // Même fabrique THÉMÉE du cœur que les sous-champs du groupe.
              decoration: theme.inputDecoration(
                context,
                label: title,
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
