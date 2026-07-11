/// `ZGeoFieldWidget` — **champ d'édition géo** (`point`/`polygone`/`cercle`),
/// servi via `ZWidgetRegistry` (E11a-1 + E11b-1, AD-2/AD-4/AD-13).
///
/// origine: le dispatcher du cœur (`ZFieldWidget`) route `location`/`geoArea`
/// vers le `ZWidgetRegistry` injecté et appelle le builder **dans** la frontière
/// de rebuild de la tranche (`ZFieldListenableBuilder`, value-in-slice). Ce
/// widget respecte AD-2 **en interne** : `TextEditingController`(s) et
/// `FocusNode`(s) créés **1×** (`initState`), jamais recréés ni ré-injectés dans
/// la voie de frappe ; sync guardée hors focus ; écriture via `ctx.onChanged`
/// uniquement (branché sur `setValue`). La frontière de rebuild n'est **jamais**
/// élargie.
///
/// **Géométrie résolue par config (E11b-1, AD-4)** : la géométrie du champ est
/// résolue dans l'ordre `ZGeoFieldConfig.geometry` (via `ctx.field.config`) →
/// [ZGeoFieldWidget.geometry] (défaut du builder) → inférence par nom de type
/// (`location`→point, `geoArea`→polygon). **Rétro-compat E11a-1 stricte** : sans
/// config ni override, `location`/`geoArea` gardent leur comportement d'origine.
///
/// **Valeur de tranche = modèle NEUTRE** : `ZGeoPoint` (point) / `ZGeoShape`
/// (polygone) / `ZGeoCircle` (cercle) — jamais un type SDK carte (AD-1). La carte
/// est rendue via un [ZMapAdapter] créé par une **fabrique** ([ZMapAdapterFactory])
/// injectée par closure de factory ([builder]) ; le champ appelle la fabrique
/// **1× en `initState`** pour créer SON instance possédée (MAJEUR-1 : une instance
/// par montage, jamais aliasée) et la dispose en fin de vie. Si aucune fabrique
/// n'est fournie, le champ dégrade proprement (saisie coordonnées seule), sans
/// crash.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_geo_circle.dart';
import '../domain/z_geo_editor_toolbar_config.dart';
import '../domain/z_geo_field_config.dart';
import '../domain/z_geo_map_options.dart';
import '../domain/z_geo_point.dart';
import '../domain/z_geo_shape.dart';
import 'z_map_adapter.dart';

/// Champ d'édition géo (patron AD-2 : contrôleurs stables, rebuild ciblé).
class ZGeoFieldWidget extends StatefulWidget {
  /// Construit le champ pour [ctx] (spec + valeur de tranche + `onChanged`).
  /// [adapterFactory] optionnelle : fabrique de carte via le port neutre ;
  /// `null` → repli coordonnées-seules. [geometry] : géométrie **par défaut du
  /// builder** (E11b-1), utilisée si `ZGeoFieldConfig.geometry` est absent ;
  /// `null` → inférence par nom de type. [mapHeight] : hauteur de la surface
  /// carte (injectable ; défaut [_defaultMapHeight] ; surchargée par
  /// `ZGeoFieldConfig.mapHeight`).
  const ZGeoFieldWidget({
    required this.ctx,
    this.adapterFactory,
    this.geometry,
    this.mapHeight = _defaultMapHeight,
    this.locationResolver,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ servi par le registre (lecture `ctx.value`, écriture
  /// `ctx.onChanged`).
  final ZFieldWidgetContext ctx;

  /// Fabrique d'adaptateur carte **optionnelle**, capturée par la closure de
  /// [builder]. Appelée **1× en `initState`** pour créer l'instance **possédée**
  /// par ce champ (MAJEUR-1 : une instance par montage, jamais partagée), disposée
  /// en fin de vie (learning E5).
  final ZMapAdapterFactory? adapterFactory;

  /// Géométrie **par défaut du builder** (E11b-1) : sert de repli quand la config
  /// `ZGeoFieldConfig.geometry` est absente, avant l'inférence par nom de type.
  /// `null` → résolution par config puis inférence type-name (rétro-compat).
  final ZGeoGeometry? geometry;

  /// Hauteur de la surface carte (dimension injectable, LOW-4). Surchargée par
  /// `ZGeoFieldConfig.mapHeight` quand présente.
  final double mapHeight;

  /// Seam **neutre** « ma position » (DP-7, gap B9), capturé par la closure de
  /// [builder]. `null` → le bouton « ma position » de la barre d'outils est
  /// **masqué** même si `showMyLocationButton == true`. **Aucun** SDK de
  /// géolocalisation n'est embarqué : l'app hôte injecte son implémentation.
  final ZGeoLocationResolver? locationResolver;

  /// Hauteur de carte par défaut (injectable via [mapHeight]).
  static const double _defaultMapHeight = 200;

  /// Hook de test : appelé UNE FOIS en [State.initState] (preuve SM-1
  /// « contrôleur/State non recréés » via compteur == 1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur de build ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable dans un `ZWidgetRegistry`
  /// sous le `kind` `"location"` et/ou `"geoArea"`. L'[adapterFactory] est
  /// **capturée par closure** → aucun nouveau slot dans `zcrud_core`, aucun
  /// `ZcrudScope` étendu (AD-4). [geometry] permet d'imposer une géométrie
  /// (ex. `circle`) même pour un type `location`, sans config par-champ. Chaque
  /// **montage** de champ appelle la fabrique une fois → **une instance
  /// d'adaptateur par champ** (MAJEUR-1 : jamais aliasée entre deux champs,
  /// jamais réutilisée après dispose). Exemple :
  /// `registry.register('location', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new))`.
  static ZFieldWidgetBuilder builder({
    ZMapAdapterFactory? adapterFactory,
    ZGeoGeometry? geometry,
    double mapHeight = _defaultMapHeight,
    ZGeoLocationResolver? locationResolver,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) =>
      (BuildContext context, ZFieldWidgetContext ctx) => ZGeoFieldWidget(
            ctx: ctx,
            adapterFactory: adapterFactory,
            geometry: geometry,
            mapHeight: mapHeight,
            locationResolver: locationResolver,
            onInit: onInit,
            onBuild: onBuild,
          );

  @override
  State<ZGeoFieldWidget> createState() => _ZGeoFieldWidgetState();
}

class _ZGeoFieldWidgetState extends State<ZGeoFieldWidget> {
  /// Contrôleur latitude (centre) — créé 1× (`initState`), jamais recréé (AD-2).
  late final TextEditingController _latController;

  /// Contrôleur longitude (centre) — créé 1×, jamais recréé (AD-2).
  late final TextEditingController _lngController;

  /// Contrôleur rayon (mode `circle`) — créé 1×, jamais recréé (AD-2).
  late final TextEditingController _radiusController;

  /// Focus latitude — oracle de la sync guardée.
  late final FocusNode _latFocus;

  /// Focus longitude — oracle de la sync guardée.
  late final FocusNode _lngFocus;

  /// Focus rayon — oracle de la sync guardée (mode `circle`).
  late final FocusNode _radiusFocus;

  /// Géométrie résolue **1×** en `initState` (config → défaut builder →
  /// inférence type-name). Immuable pour la durée de vie du montage (le mode ne
  /// change pas la frontière de rebuild).
  late final ZGeoGeometry _geometry;

  /// Config géo lue depuis `ctx.field.config` (si présente) — défauts
  /// surchargeables (centre/zoom/hauteur/tuiles/style).
  late final ZGeoFieldConfig? _config;

  /// Instance d'adaptateur carte **possédée** par ce montage (MAJEUR-1). Créée
  /// 1× en [initState] via `widget.adapterFactory`, disposée en [dispose].
  /// Jamais partagée avec un autre champ, jamais réutilisée après dispose.
  ZMapAdapter? _mapAdapter;

  /// Valeur d'aire courante « au fil de l'eau » (MEDIUM-3). Source atomique des
  /// ajouts/retraits de sommet : évite la perte de mise à jour quand deux
  /// événements surviennent dans la même frame avant tout rebuild. `null` hors
  /// mode `polygon`.
  ZGeoShape? _workingShape;

  /// Options de carte **neutres** pilotées par la barre d'outils (DP-7).
  /// `null` quand il n'y a **aucune** barre d'outils (rétro-compat stricte :
  /// `buildMap` reçoit `mapOptions: null` → comportement E11a-1/E11b-1
  /// inchangé). Mutable via des actions **discrètes** de la barre (type de
  /// carte / toggles features) — JAMAIS sur la voie de frappe (AD-2).
  ZGeoMapOptions? _mapOptions;

  /// Config de barre d'outils lue depuis `_config` (DP-7). `null` → aucune barre.
  ZGeoEditorToolbarConfig? get _toolbarConfig => _config?.toolbarConfig;

  bool get _isArea => _geometry == ZGeoGeometry.polygon;
  bool get _isCircle => _geometry == ZGeoGeometry.circle;

  bool get _hasFieldFocus =>
      _latFocus.hasFocus || _lngFocus.hasFocus || _radiusFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    final Object? cfg = widget.ctx.field.config;
    _config = cfg is ZGeoFieldConfig ? cfg : null;
    _geometry = _resolveGeometry();
    // DP-7 : n'amorcer un état d'options de carte que si une barre d'outils
    // existe → sinon `null` (rétro-compat : `mapOptions` non transmis à la carte).
    _mapOptions = _config?.toolbarConfig != null ? const ZGeoMapOptions() : null;
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _radiusController = TextEditingController();
    _latFocus = FocusNode();
    _lngFocus = FocusNode();
    _radiusFocus = FocusNode();
    // MAJEUR-1 : créer l'instance d'adaptateur possédée UNE FOIS par montage.
    _mapAdapter = widget.adapterFactory?.call();
    switch (_geometry) {
      case ZGeoGeometry.polygon:
        // Champs texte = sommet CANDIDAT transitoire → pas d'amorçage depuis la
        // tranche ; on amorce l'état d'aire « au fil de l'eau » (MEDIUM-3).
        _workingShape = _shapeOf(widget.ctx.value);
      case ZGeoGeometry.circle:
        // Amorcer centre + rayon depuis la valeur initiale (une seule fois).
        final circle = _circleOf(widget.ctx.value);
        if (circle != null) {
          _latController.text = _fmt(circle.center.lat);
          _lngController.text = _fmt(circle.center.lng);
          _radiusController.text = _fmt(circle.radiusMeters);
        }
      case ZGeoGeometry.point:
        // Amorcer les champs depuis le point initial (une seule fois).
        final point = _pointOf(widget.ctx.value);
        if (point != null) {
          _latController.text = _fmt(point.lat);
          _lngController.text = _fmt(point.lng);
        }
    }
    widget.onInit?.call();
  }

  /// Résout la géométrie du champ (E11b-1) : `config.geometry` →
  /// `widget.geometry` (défaut builder) → inférence par nom de type
  /// (`geoArea`→polygon, sinon point). Rétro-compat E11a-1 stricte.
  ZGeoGeometry _resolveGeometry() {
    final ZGeoGeometry? fromConfig = _config?.geometry;
    if (fromConfig != null) return fromConfig;
    final ZGeoGeometry? fromBuilder = widget.geometry;
    if (fromBuilder != null) return fromBuilder;
    return widget.ctx.field.type.name == 'geoArea'
        ? ZGeoGeometry.polygon
        : ZGeoGeometry.point;
  }

  @override
  void didUpdateWidget(covariant ZGeoFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    switch (_geometry) {
      case ZGeoGeometry.polygon:
        // MEDIUM-3 : adopter une valeur d'aire EXTERNE (≠ celle qu'on a émise) ;
        // notre propre écho (`ctx.value == _workingShape`) n'écrase rien.
        final external = _shapeOf(widget.ctx.value);
        if (external != _workingShape) _workingShape = external;
      case ZGeoGeometry.circle:
        // SYNC GUARDÉE (AD-2) : refléter une valeur EXTERNE hors focus seulement.
        if (_hasFieldFocus) return;
        final circle = _circleOf(widget.ctx.value);
        final lat = circle == null ? '' : _fmt(circle.center.lat);
        final lng = circle == null ? '' : _fmt(circle.center.lng);
        final rad = circle == null ? '' : _fmt(circle.radiusMeters);
        if (_latController.text != lat) _latController.text = lat;
        if (_lngController.text != lng) _lngController.text = lng;
        if (_radiusController.text != rad) _radiusController.text = rad;
      case ZGeoGeometry.point:
        // SYNC GUARDÉE (AD-2) : refléter une valeur EXTERNE dans les champs
        // clavier UNIQUEMENT hors focus. Pendant la frappe, priorité absolue au
        // curseur — aucun write-back (sinon caret sauté / focus perdu).
        if (_hasFieldFocus) return;
        final point = _pointOf(widget.ctx.value);
        final lat = point == null ? '' : _fmt(point.lat);
        final lng = point == null ? '' : _fmt(point.lng);
        if (_latController.text != lat) _latController.text = lat;
        if (_lngController.text != lng) _lngController.text = lng;
    }
  }

  @override
  void dispose() {
    // Anti-fuite (learning E5) : libérer contrôleurs/focus ET le contrôleur
    // natif de l'adaptateur carte possédé par ce champ.
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _latFocus.dispose();
    _lngFocus.dispose();
    _radiusFocus.dispose();
    _mapAdapter?.dispose();
    super.dispose();
  }

  // --- Écritures dans la tranche (voie unique `ctx.onChanged → setValue`) -----

  /// Mode `point` : (re)compose un `ZGeoPoint` neutre depuis les champs, ou
  /// `null` si incomplet/invalide/hors-bornes (AD-10). Jamais un type SDK.
  void _emitPointFromFields() {
    final lat = _parse(_latController.text);
    final lng = _parse(_lngController.text);
    if (lat == null || lng == null) {
      widget.ctx.onChanged(null);
      return;
    }
    final point = ZGeoPoint(lat: lat, lng: lng);
    widget.ctx.onChanged(point.isValid ? point : null);
  }

  /// Mode `point` : fixe le point depuis un tap carte (coordonnées neutres).
  void _setPointFromTap(ZGeoPoint point) {
    _latController.text = _fmt(point.lat);
    _lngController.text = _fmt(point.lng);
    widget.ctx.onChanged(point);
  }

  /// Mode `circle` : (re)compose un `ZGeoCircle` neutre depuis centre + rayon,
  /// ou `null` si incomplet/invalide/rayon ≤0 (AD-10). Jamais un type SDK.
  void _emitCircleFromFields() {
    final lat = _parse(_latController.text);
    final lng = _parse(_lngController.text);
    final radius = _parse(_radiusController.text);
    if (lat == null || lng == null || radius == null) {
      widget.ctx.onChanged(null);
      return;
    }
    final circle = ZGeoCircle(
      center: ZGeoPoint(lat: lat, lng: lng),
      radiusMeters: radius,
    );
    widget.ctx.onChanged(circle.isValid ? circle : null);
  }

  /// Mode `circle` : fixe le centre depuis un tap carte (rayon conservé), puis
  /// ré-émet le cercle (ou `null` si le rayon reste invalide).
  void _setCircleCenterFromTap(ZGeoPoint point) {
    _latController.text = _fmt(point.lat);
    _lngController.text = _fmt(point.lng);
    _emitCircleFromFields();
  }

  /// Mode `polygon` : ajoute le sommet candidat (champs texte) à l'aire.
  void _addCandidateVertex() {
    final lat = _parse(_latController.text);
    final lng = _parse(_lngController.text);
    if (lat == null || lng == null) return; // candidat invalide ignoré (AD-10)
    final point = ZGeoPoint(lat: lat, lng: lng);
    if (!point.isValid) return;
    _appendVertex(point);
    _latController.clear();
    _lngController.clear();
  }

  /// Aire courante « au fil de l'eau » (MEDIUM-3) : l'état local possédé prime
  /// sur `widget.ctx.value` (rafraîchi seulement au rebuild) pour sérialiser les
  /// mutations survenant dans la même frame. Repli défensif sur la tranche.
  ZGeoShape get _currentShape => _workingShape ?? _shapeOf(widget.ctx.value);

  /// Mode `polygon` : ajoute [point] (tap carte ou candidat) à l'aire courante,
  /// de façon **atomique** (MEDIUM-3) : on part de l'aire « au fil de l'eau »,
  /// on la met à jour AVANT d'émettre → deux ajouts rapprochés ne se perdent pas.
  void _appendVertex(ZGeoPoint point) {
    final next = _currentShape.addVertex(point);
    _workingShape = next;
    widget.ctx.onChanged(next);
  }

  /// Mode `polygon` : retire le sommet [index] (atomique, cf. [_appendVertex]).
  void _removeVertex(int index) {
    final shape = _currentShape;
    if (index < 0 || index >= shape.vertices.length) return;
    final next = ZGeoShape(
      vertices: <ZGeoPoint>[...shape.vertices]..removeAt(index),
      label: shape.label,
    );
    _workingShape = next;
    widget.ctx.onChanged(next);
  }

  // --- Actions de la barre d'outils (DP-7, voie unique `ctx.onChanged`) -------

  /// **clear** (B9) : remet la valeur de tranche à `null`, vide les contrôleurs
  /// texte et réinitialise l'aire « au fil de l'eau ». Ne recrée ni contrôleurs
  /// ni focus (AD-2) ; l'émission `null` déclenche le rebuild ciblé de la tranche.
  void _clearAll() {
    _latController.clear();
    _lngController.clear();
    _radiusController.clear();
    if (_isArea) _workingShape = ZGeoShape();
    widget.ctx.onChanged(null);
  }

  /// **undo** (B9) : polygone → retire le dernier sommet (réutilise l'écriture
  /// atomique [_removeVertex]) ; point/cercle → efface la dernière saisie (un
  /// seul état → équivaut à [_clearAll]). Aucune exception si rien à annuler
  /// (AD-10).
  void _undo() {
    switch (_geometry) {
      case ZGeoGeometry.polygon:
        final shape = _currentShape;
        if (shape.vertices.isEmpty) return; // rien à annuler → no-op silencieux
        _removeVertex(shape.vertices.length - 1);
      case ZGeoGeometry.circle:
      case ZGeoGeometry.point:
        _clearAll();
    }
  }

  /// **ma-position** (B9) : appelle le [ZGeoLocationResolver] injecté ; sur un
  /// point non-null **valide**, applique la même voie que le tap carte selon la
  /// géométrie. `null`/erreur → no-op silencieux (AD-10, jamais de crash) ; garde
  /// `mounted` après l'`await`.
  Future<void> _useMyLocation() async {
    final ZGeoLocationResolver? resolver = widget.locationResolver;
    if (resolver == null) return;
    ZGeoPoint? point;
    try {
      point = await resolver();
    } catch (_) {
      return; // AD-10 : avaler l'erreur du resolver, jamais de crash
    }
    if (!mounted) return;
    if (point == null || !point.isValid) return;
    switch (_geometry) {
      case ZGeoGeometry.polygon:
        _appendVertex(point);
      case ZGeoGeometry.circle:
        _setCircleCenterFromTap(point);
      case ZGeoGeometry.point:
        _setPointFromTap(point);
    }
  }

  /// Types de carte disponibles selon `showExtendedMapTypes` (Normal/Hybride, +
  /// Satellite/Terrain en étendu).
  List<ZGeoMapType> get _availableMapTypes =>
      (_toolbarConfig?.showExtendedMapTypes ?? false)
          ? const <ZGeoMapType>[
              ZGeoMapType.normal,
              ZGeoMapType.hybrid,
              ZGeoMapType.satellite,
              ZGeoMapType.terrain,
            ]
          : const <ZGeoMapType>[ZGeoMapType.normal, ZGeoMapType.hybrid];

  /// **type-de-carte** (B9) : cycle vers le type suivant (action **discrète** —
  /// `setState` sur `_mapOptions`, JAMAIS la voie de frappe, AD-2 préservé).
  void _cycleMapType() {
    final List<ZGeoMapType> types = _availableMapTypes;
    final ZGeoMapType current = _mapOptions?.mapType ?? ZGeoMapType.normal;
    final int idx = types.indexOf(current);
    final ZGeoMapType next = types[(idx + 1) % types.length];
    setState(() {
      _mapOptions = (_mapOptions ?? const ZGeoMapOptions()).copyWith(
        mapType: next,
      );
    });
  }

  /// Bascule discrète d'un flag d'options de carte (features/gestes/advanced).
  /// Action **discrète** (`setState` sur `_mapOptions`), hors voie de frappe.
  void _updateMapOptions(ZGeoMapOptions Function(ZGeoMapOptions) update) {
    setState(() {
      _mapOptions = update(_mapOptions ?? const ZGeoMapOptions());
    });
  }

  // --- Lecture défensive de la tranche ---------------------------------------

  // LOW-5 : ne faire confiance à un `ZGeoPoint` déjà en tranche que s'il est
  // dans les bornes (le constructeur n'a pas d'`assert`) ; sinon le re-parser
  // défensivement (AD-10) → jamais de coordonnée hors-bornes envoyée à la carte.
  ZGeoPoint? _pointOf(Object? value) => value is ZGeoPoint
      ? (value.isValid ? value : null)
      : ZGeoPoint.fromMapSafe(value);

  ZGeoShape _shapeOf(Object? value) => value is ZGeoShape
      ? value
      : (ZGeoShape.fromMapSafe(value) ?? ZGeoShape());

  // Idem LOW-5 pour le cercle : ne faire confiance qu'à un `ZGeoCircle` valide.
  ZGeoCircle? _circleOf(Object? value) => value is ZGeoCircle
      ? (value.isValid ? value : null)
      : ZGeoCircle.fromMapSafe(value);

  static double? _parse(String raw) {
    final d = double.tryParse(raw.trim());
    return (d != null && d.isFinite) ? d : null;
  }

  static String _fmt(double v) => v.toString();

  double get _resolvedMapHeight => _config?.mapHeight ?? widget.mapHeight;

  /// Callback de frappe des champs centre selon la géométrie (voie SENS UNIQUE
  /// AD-2 : la frappe écrit la tranche, jamais de ré-injection pendant le focus).
  ValueChanged<String>? get _coordOnChanged => switch (_geometry) {
        ZGeoGeometry.point => (_) => _emitPointFromFields(),
        ZGeoGeometry.circle => (_) => _emitCircleFromFields(),
        ZGeoGeometry.polygon => null,
      };

  // --- Rendu ------------------------------------------------------------------

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
            _coordinateRow(theme),
            if (_isCircle) ...<Widget>[
              SizedBox(height: theme.gapS),
              _radiusField(context),
            ],
            if (_isArea) ...<Widget>[
              SizedBox(height: theme.gapS),
              _addVertexButton(context),
              SizedBox(height: theme.gapS),
              _vertexList(context, theme),
            ],
            // DP-7 : barre d'outils d'éditeur, rendue UNIQUEMENT si une config
            // est fournie et non désactivée (défaut `null` → aucune barre →
            // rétro-compat E11a-1/E11b-1 stricte). Placée AU-DESSUS de la carte.
            if (_toolbarConfig != null && !_toolbarConfig!.disabled) ...<Widget>[
              SizedBox(height: theme.gapM),
              _toolbar(context, theme),
            ],
            SizedBox(height: theme.gapM),
            _mapSurface(context),
          ],
        ),
      ),
    );
  }

  Widget _coordinateRow(ZcrudTheme theme) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _coordinateField(
              controller: _latController,
              focusNode: _latFocus,
              semanticLabel: 'latitude',
              readOnly: widget.ctx.field.readOnly,
            ),
          ),
          SizedBox(width: theme.gapM),
          Expanded(
            child: _coordinateField(
              controller: _lngController,
              focusNode: _lngFocus,
              semanticLabel: 'longitude',
              readOnly: widget.ctx.field.readOnly,
            ),
          ),
        ],
      );

  Widget _coordinateField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String semanticLabel,
    required bool readOnly,
  }) =>
      TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        textAlign: TextAlign.start,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        // `labelText` porte le libellé sémantique (rôle champ de saisie natif,
        // AD-13) — aucune Semantics redondante.
        decoration: InputDecoration(
          labelText: semanticLabel,
          isDense: true,
        ),
        // Voie SENS UNIQUE (AD-2) : la frappe écrit la tranche, jamais de
        // ré-injection pendant le focus.
        onChanged: _coordOnChanged,
      );

  /// Champ rayon (mode `circle`). Libellé routé via l10n injectée
  /// (`ZcrudScope.labels` → delegate → repli `en` → littéral), jamais figé.
  Widget _radiusField(BuildContext context) => TextField(
        key: const Key('z-geo-radius'),
        controller: _radiusController,
        focusNode: _radiusFocus,
        readOnly: widget.ctx.field.readOnly,
        textAlign: TextAlign.start,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label(context, 'geo.radius', fallback: 'Rayon (m)'),
          isDense: true,
        ),
        onChanged: (_) => _emitCircleFromFields(),
      );

  Widget _addVertexButton(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          key: const Key('z-geo-add-vertex'),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          // Semantics explicite (AD-13) : node propre (`container`) portant le
          // libellé ; l'intérieur est exclu pour ne pas fragmenter l'annonce.
          child: Semantics(
            container: true,
            button: true,
            label: 'ajouter-sommet',
            child: ExcludeSemantics(
              child: TextButton.icon(
                onPressed:
                    widget.ctx.field.readOnly ? null : _addCandidateVertex,
                icon: const Icon(Icons.add_location_alt_outlined),
                // LOW-4 : libellé routé via l10n injectée (`ZcrudScope.labels`
                // → delegate → repli `en`), repli littéral français en dernier
                // recours — jamais une chaîne UI figée hors injection.
                label: Text(label(context, 'geo.addVertex', fallback: 'Ajouter')),
              ),
            ),
          ),
        ),
      );

  Widget _vertexList(BuildContext context, ZcrudTheme theme) {
    final shape = _currentShape;
    if (shape.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < shape.vertices.length; i++)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${_fmt(shape.vertices[i].lat)}, '
                    '${_fmt(shape.vertices[i].lng)}',
                    textAlign: TextAlign.start,
                  ),
                ),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: Semantics(
                    container: true,
                    button: true,
                    label: 'retirer-sommet-$i',
                    child: ExcludeSemantics(
                      child: IconButton(
                        onPressed: widget.ctx.field.readOnly
                            ? null
                            : () => _removeVertex(i),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Surface carte via l'adaptateur **possédé** (MAJEUR-1) ; repli propre si
  /// aucune fabrique n'a été fournie.
  Widget _mapSurface(BuildContext context) {
    final adapter = _mapAdapter;
    if (adapter == null) {
      // Repli AD-1 : aucun adaptateur → coordonnées-seules, jamais de crash.
      return const SizedBox.shrink();
    }
    final ZGeoShape? areaShape = _isArea ? _currentShape : null;
    final ZGeoCircle? circle = _isCircle ? _circleOf(widget.ctx.value) : null;
    // Centre de carte : valeur courante, sinon repli sur le défaut surchargeable
    // de la config (neutre ; AD-12), sinon choix de l'adaptateur.
    final ZGeoPoint? center = switch (_geometry) {
      ZGeoGeometry.polygon =>
        areaShape!.vertices.firstOrNull ?? _config?.defaultCenter,
      ZGeoGeometry.circle => circle?.center ?? _config?.defaultCenter,
      ZGeoGeometry.point =>
        _pointOf(widget.ctx.value) ?? _config?.defaultCenter,
    };
    return SizedBox(
      height: _resolvedMapHeight,
      child: adapter.buildMap(
        context,
        center: center,
        shape: areaShape,
        circle: circle,
        interactive: !widget.ctx.field.readOnly && (_config?.interactive ?? true),
        // MEDIUM-1 (E11b-1) : surcharges par-champ RÉELLEMENT plombées à
        // l'adaptateur (chaque adaptateur honore celles qui le concernent).
        tileUrlTemplate: _config?.tileUrlTemplate,
        mapStyleJson: _config?.mapStyleJson,
        defaultZoom: _config?.defaultZoom,
        // DP-7 : options de carte neutres pilotées par la barre (`null` si aucune
        // barre → comportement inchangé). Honoré-si-supporté par l'adaptateur.
        mapOptions: _mapOptions,
        onTap: widget.ctx.field.readOnly
            ? null
            : (ZGeoPoint point) {
                switch (_geometry) {
                  case ZGeoGeometry.polygon:
                    _appendVertex(point);
                  case ZGeoGeometry.circle:
                    _setCircleCenterFromTap(point);
                  case ZGeoGeometry.point:
                    _setPointFromTap(point);
                }
              },
      ),
    );
  }

  // --- Barre d'outils (DP-7, gap B9) -----------------------------------------

  /// Barre d'outils d'éditeur (clé `z-geo-toolbar`). Boutons **gated par leurs
  /// toggles** (undo/clear/ma-position/type-de-carte + toggles d'options carte).
  /// Layout **directionnel** (`Wrap`), cibles ≥48dp, `Semantics`/tooltip, thème
  /// injecté — aucune couleur en dur (AD-13).
  Widget _toolbar(BuildContext context, ZcrudTheme theme) {
    final ZGeoEditorToolbarConfig cfg = _toolbarConfig!;
    final bool readOnly = widget.ctx.field.readOnly;
    // Libellés textuels seulement hors mode compact (icônes seules).
    final bool showLabels = cfg.showButtonLabels && !cfg.compactMode;
    final bool hasResolver = widget.locationResolver != null;

    final List<Widget> buttons = <Widget>[
      if (cfg.showUndoButton)
        _toolbarButton(
          context: context,
          key: const Key('z-geo-undo'),
          icon: Icons.undo,
          l10nKey: 'geo.undo',
          fallback: 'Annuler',
          showLabels: showLabels,
          onPressed: readOnly ? null : _undo,
        ),
      if (cfg.showClearButton)
        _toolbarButton(
          context: context,
          key: const Key('z-geo-clear'),
          icon: Icons.delete_sweep_outlined,
          l10nKey: 'geo.clear',
          fallback: 'Effacer',
          showLabels: showLabels,
          onPressed: readOnly ? null : _clearAll,
        ),
      // « ma position » : présent seulement si le seam est injecté (AC7).
      if (cfg.showMyLocationButton && hasResolver)
        _toolbarButton(
          context: context,
          key: const Key('z-geo-my-location'),
          icon: Icons.my_location,
          l10nKey: 'geo.myLocation',
          fallback: 'Ma position',
          showLabels: showLabels,
          onPressed: readOnly ? null : _useMyLocation,
        ),
      if (cfg.showMapTypeToggle)
        _toolbarButton(
          context: context,
          key: const Key('z-geo-map-type'),
          icon: Icons.layers_outlined,
          l10nKey: 'geo.mapType',
          fallback: 'Type de carte',
          // Le libellé affiche le type courant (Normal/Hybride/…).
          labelText: _mapTypeLabel(context),
          showLabels: showLabels,
          onPressed: readOnly ? null : _cycleMapType,
        ),
      // Toggles d'options carte (features/gestes/advanced) — pilotent
      // `_mapOptions` (honoré-si-supporté par l'adaptateur). Action discrète.
      if (cfg.showTrafficToggle)
        _mapOptionToggle(
          context: context,
          key: const Key('z-geo-traffic'),
          icon: Icons.traffic_outlined,
          l10nKey: 'geo.traffic',
          fallback: 'Trafic',
          selected: _mapOptions?.trafficEnabled ?? false,
          showLabels: showLabels,
          onPressed: readOnly
              ? null
              : () => _updateMapOptions((o) =>
                  o.copyWith(trafficEnabled: !o.trafficEnabled)),
        ),
      if (cfg.showBuildingsToggle)
        _mapOptionToggle(
          context: context,
          key: const Key('z-geo-buildings'),
          icon: Icons.apartment_outlined,
          l10nKey: 'geo.buildings',
          fallback: 'Bâtiments',
          selected: _mapOptions?.buildingsEnabled ?? false,
          showLabels: showLabels,
          onPressed: readOnly
              ? null
              : () => _updateMapOptions((o) =>
                  o.copyWith(buildingsEnabled: !o.buildingsEnabled)),
        ),
      if (cfg.showIndoorViewToggle)
        _mapOptionToggle(
          context: context,
          key: const Key('z-geo-indoor'),
          icon: Icons.meeting_room_outlined,
          l10nKey: 'geo.indoor',
          fallback: 'Intérieur',
          selected: _mapOptions?.indoorViewEnabled ?? false,
          showLabels: showLabels,
          onPressed: readOnly
              ? null
              : () => _updateMapOptions((o) =>
                  o.copyWith(indoorViewEnabled: !o.indoorViewEnabled)),
        ),
      if (cfg.showRotationToggle)
        _mapOptionToggle(
          context: context,
          key: const Key('z-geo-rotation'),
          icon: Icons.rotate_left_outlined,
          l10nKey: 'geo.rotation',
          fallback: 'Rotation',
          selected: _mapOptions?.rotateGesturesEnabled ?? false,
          showLabels: showLabels,
          onPressed: readOnly
              ? null
              : () => _updateMapOptions((o) =>
                  o.copyWith(rotateGesturesEnabled: !o.rotateGesturesEnabled)),
        ),
      if (cfg.showTiltToggle)
        _mapOptionToggle(
          context: context,
          key: const Key('z-geo-tilt'),
          icon: Icons.threed_rotation_outlined,
          l10nKey: 'geo.tilt',
          fallback: 'Inclinaison',
          selected: _mapOptions?.tiltGesturesEnabled ?? false,
          showLabels: showLabels,
          onPressed: readOnly
              ? null
              : () => _updateMapOptions((o) =>
                  o.copyWith(tiltGesturesEnabled: !o.tiltGesturesEnabled)),
        ),
      if (cfg.showZoomControlsToggle)
        _mapOptionToggle(
          context: context,
          key: const Key('z-geo-zoom-controls'),
          icon: Icons.zoom_in_outlined,
          l10nKey: 'geo.zoomControls',
          fallback: 'Zoom',
          selected: _mapOptions?.zoomControlsEnabled ?? false,
          showLabels: showLabels,
          onPressed: readOnly
              ? null
              : () => _updateMapOptions((o) =>
                  o.copyWith(zoomControlsEnabled: !o.zoomControlsEnabled)),
        ),
      if (cfg.showCompassToggle)
        _mapOptionToggle(
          context: context,
          key: const Key('z-geo-compass'),
          icon: Icons.explore_outlined,
          l10nKey: 'geo.compass',
          fallback: 'Boussole',
          selected: _mapOptions?.compassEnabled ?? false,
          showLabels: showLabels,
          onPressed: readOnly
              ? null
              : () => _updateMapOptions((o) =>
                  o.copyWith(compassEnabled: !o.compassEnabled)),
        ),
      if (cfg.showMapToolbarToggle)
        _mapOptionToggle(
          context: context,
          key: const Key('z-geo-map-toolbar'),
          icon: Icons.build_outlined,
          l10nKey: 'geo.mapToolbar',
          fallback: 'Outils carte',
          selected: _mapOptions?.mapToolbarEnabled ?? false,
          showLabels: showLabels,
          onPressed: readOnly
              ? null
              : () => _updateMapOptions((o) =>
                  o.copyWith(mapToolbarEnabled: !o.mapToolbarEnabled)),
        ),
    ];

    return Align(
      key: const Key('z-geo-toolbar'),
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.gapS,
        runSpacing: theme.gapS,
        children: buttons,
      ),
    );
  }

  /// Libellé du type de carte courant (via l10n injectée, repli inline).
  String _mapTypeLabel(BuildContext context) {
    final ZGeoMapType type = _mapOptions?.mapType ?? ZGeoMapType.normal;
    final (String key, String fallback) = switch (type) {
      ZGeoMapType.normal => ('geo.mapType.normal', 'Normal'),
      ZGeoMapType.hybrid => ('geo.mapType.hybrid', 'Hybride'),
      ZGeoMapType.satellite => ('geo.mapType.satellite', 'Satellite'),
      ZGeoMapType.terrain => ('geo.mapType.terrain', 'Terrain'),
    };
    return label(context, key, fallback: fallback);
  }

  /// Bouton d'action de la barre (≥48dp, Semantics/tooltip, thème). [labelText]
  /// surcharge le texte affiché (ex. type de carte courant) tout en gardant la
  /// clé l10n [l10nKey] pour la sémantique/tooltip.
  Widget _toolbarButton({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String l10nKey,
    required String fallback,
    required bool showLabels,
    required VoidCallback? onPressed,
    String? labelText,
  }) {
    final String semantic = label(context, l10nKey, fallback: fallback);
    final String text = labelText ?? semantic;
    final Widget inner = showLabels
        ? TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(text, textAlign: TextAlign.start),
          )
        : IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            tooltip: text,
          );
    return ConstrainedBox(
      key: key,
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Semantics(
        container: true,
        button: true,
        enabled: onPressed != null,
        label: semantic,
        child: ExcludeSemantics(child: inner),
      ),
    );
  }

  /// Bouton **toggle** d'option de carte (état [selected] reflété via
  /// `Semantics(toggled:)` et l'état sélectionné de l'`IconButton`). ≥48dp,
  /// thème injecté (aucune couleur en dur).
  Widget _mapOptionToggle({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String l10nKey,
    required String fallback,
    required bool selected,
    required bool showLabels,
    required VoidCallback? onPressed,
  }) {
    final String text = label(context, l10nKey, fallback: fallback);
    final Widget inner = showLabels
        ? TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(text, textAlign: TextAlign.start),
          )
        : IconButton(
            onPressed: onPressed,
            isSelected: selected,
            icon: Icon(icon),
            tooltip: text,
          );
    return ConstrainedBox(
      key: key,
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Semantics(
        container: true,
        button: true,
        toggled: selected,
        enabled: onPressed != null,
        label: text,
        child: ExcludeSemantics(child: inner),
      ),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
