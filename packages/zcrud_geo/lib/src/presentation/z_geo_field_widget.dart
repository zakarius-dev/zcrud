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
import '../domain/z_geo_field_config.dart';
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
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) =>
      (BuildContext context, ZFieldWidgetContext ctx) => ZGeoFieldWidget(
            ctx: ctx,
            adapterFactory: adapterFactory,
            geometry: geometry,
            mapHeight: mapHeight,
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
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
