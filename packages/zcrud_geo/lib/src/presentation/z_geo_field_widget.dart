/// `ZGeoFieldWidget` — **champ d'édition géo** (`point`/`polygone`/`cercle`),
/// servi via `ZWidgetRegistry`.
///
/// Le dispatcher du cœur (`ZFieldWidget`) route `location`/`geoArea` vers le
/// `ZWidgetRegistry` injecté et appelle le builder **dans** la frontière de
/// rebuild de la tranche. Ce widget respecte l'invariant AD-2 en interne :
/// `TextEditingController`(s) et `FocusNode`(s) créés **une fois**
/// (`initState`), jamais recréés ni ré-injectés dans la voie de frappe ;
/// synchronisation guardée hors focus ; écriture via `ctx.onChanged`
/// uniquement. La frontière de rebuild n'est **jamais** élargie.
///
/// **Géométrie résolue par config (invariant AD-4)** : la géométrie du champ
/// est résolue dans l'ordre — valeur initiale (champs **multi-géométries**
/// seulement) → `ZGeoFieldConfig.geometry` → `allowedGeometries.first` →
/// [ZGeoFieldWidget.geometry] (défaut du builder) → inférence par nom de type
/// (`location`→point, `geoArea`→polygon). Un champ multi-géométries expose un
/// **sélecteur de mode** dans la barre d'outils.
///
/// Sans `toolbarConfig`, le champ rend la barre d'outils **`standard`** —
/// l'opt-out est `ZGeoEditorToolbarConfig.none`.
///
/// **Valeur de tranche = modèle neutre** : `ZGeoPoint` (point) / `ZGeoShape`
/// (polygone) / `ZGeoCircle` (cercle) — jamais un type SDK carte (invariant
/// AD-1). La carte est rendue via un [ZMapAdapter] créé par une **fabrique**
/// ([ZMapAdapterFactory]) injectée par closure ([builder]) ; le champ appelle
/// la fabrique **une fois en `initState`** pour créer son instance possédée
/// (jamais aliasée entre deux champs) et la dispose en fin de vie. Si aucune
/// fabrique n'est fournie, le champ dégrade proprement (saisie coordonnées
/// seule), sans crash.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_geo_chrome_reference.dart';
import '../domain/z_geo_circle.dart';
import '../domain/z_geo_editor_toolbar_config.dart';
import '../domain/z_geo_field_config.dart';
import '../domain/z_geo_legacy_codec.dart';
import '../domain/z_geo_map_options.dart';
import '../domain/z_geo_metrics.dart';
import '../domain/z_geo_point.dart';
import '../domain/z_geo_shape.dart';
import '../domain/z_geo_shape_style.dart';
import '../domain/z_geo_value.dart';
import 'z_geo_shape_style_picker.dart';
import 'z_map_adapter.dart';

/// Champ d'édition géo (invariant AD-2 : contrôleurs stables, rebuild ciblé).
class ZGeoFieldWidget extends StatefulWidget {
  /// Construit le champ pour [ctx] (spec + valeur de tranche + `onChanged`).
  /// [adapterFactory] optionnelle : fabrique de carte via le port neutre ;
  /// `null` → repli coordonnées-seules. [geometry] : géométrie **par défaut
  /// du builder**, utilisée si `ZGeoFieldConfig.geometry` est absent ; `null`
  /// → inférence par nom de type. [mapHeight] : hauteur de la surface carte
  /// (injectable ; défaut [_defaultMapHeight] ; surchargée par
  /// `ZGeoFieldConfig.mapHeight`).
  const ZGeoFieldWidget({
    required this.ctx,
    this.adapterFactory,
    this.adapterFactories,
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
  /// [builder]. Appelée **une fois en `initState`** pour créer l'instance
  /// **possédée** par ce champ (une instance par montage, jamais partagée),
  /// disposée en fin de vie.
  final ZMapAdapterFactory? adapterFactory;

  /// Registre de fabriques d'adaptateur **nommées** : la clé est choisie
  /// **par champ** via `ZGeoFieldConfig.adapterKey`. `null`, clé absente de
  /// la config ou clé inconnue du registre → repli sur [adapterFactory]
  /// (l'hôte mono-factory existant est inchangé ; jamais de crash — invariant
  /// AD-10).
  final Map<String, ZMapAdapterFactory>? adapterFactories;

  /// Géométrie **par défaut du builder** : sert de repli quand la config
  /// `ZGeoFieldConfig.geometry` est absente, avant l'inférence par nom de
  /// type. `null` → résolution par config puis inférence type-name.
  final ZGeoGeometry? geometry;

  /// Hauteur de la surface carte (dimension injectable). Surchargée par
  /// `ZGeoFieldConfig.mapHeight` quand présente.
  final double mapHeight;

  /// Seam **neutre** « ma position », capturé par la closure de [builder].
  /// `null` → le bouton « ma position » de la barre d'outils est **masqué**
  /// même si `showMyLocationButton == true`. **Aucun** SDK de
  /// géolocalisation n'est embarqué : l'application hôte injecte son
  /// implémentation (voir le paquet compagnon `zcrud_geo_location`).
  final ZGeoLocationResolver? locationResolver;

  /// Hauteur de carte par défaut (injectable via [mapHeight]).
  static const double _defaultMapHeight = 200;

  /// Hook de test : appelé une seule fois en [State.initState].
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build.
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable dans un `ZWidgetRegistry`
  /// sous le `kind` `"location"` et/ou `"geoArea"`. L'[adapterFactory] est
  /// **capturée par closure** → aucun nouveau slot dans `zcrud_core`, aucun
  /// `ZcrudScope` étendu (invariant AD-4). [geometry] permet d'imposer une
  /// géométrie (ex. `circle`) même pour un type `location`, sans config
  /// par-champ. Chaque **montage** de champ appelle la fabrique une fois →
  /// **une instance d'adaptateur par champ** (jamais aliasée entre deux
  /// champs, jamais réutilisée après dispose). Exemple :
  /// `registry.register('location', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new))`.
  static ZFieldWidgetBuilder builder({
    ZMapAdapterFactory? adapterFactory,
    Map<String, ZMapAdapterFactory>? adapterFactories,
    ZGeoGeometry? geometry,
    double mapHeight = _defaultMapHeight,
    ZGeoLocationResolver? locationResolver,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) =>
      (BuildContext context, ZFieldWidgetContext ctx) => ZGeoFieldWidget(
            ctx: ctx,
            adapterFactory: adapterFactory,
            adapterFactories: adapterFactories,
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

  /// Géométrie **courante** du champ. Résolue en `initState` (valeur initiale →
  /// config → défaut builder → inférence type-name : la géométrie portée par
  /// la valeur initiale PRIME sur les autres sources). Mutable UNIQUEMENT via
  /// le sélecteur de mode — action **discrète** (`setState`), jamais sur la
  /// voie de frappe (AD-2) ; la frontière de rebuild reste la tranche.
  ZGeoGeometry _geometry = ZGeoGeometry.point;

  /// Config géo lue depuis `ctx.field.config` (si présente) — défauts
  /// surchargeables (centre/zoom/hauteur/tuiles/style).
  late final ZGeoFieldConfig? _config;

  /// Instance d'adaptateur carte **possédée** par ce montage. Créée 1× en
  /// [initState] via `widget.adapterFactory`, disposée en [dispose]. Jamais
  /// partagée avec un autre champ, jamais réutilisée après dispose.
  ZMapAdapter? _mapAdapter;

  /// Valeur d'aire courante « au fil de l'eau ». Source atomique des
  /// ajouts/retraits de sommet : évite la perte de mise à jour quand deux
  /// événements surviennent dans la même frame avant tout rebuild. `null` hors
  /// mode `polygon`.
  ZGeoShape? _workingShape;

  /// Machine « cercle 2 taps » : `true` entre le 1er tap (centre posé) et le
  /// 2e (rayon = distance haversine). Tant que le rayon n'est pas fixé, la
  /// carte affiche un **aperçu 10 m**.
  bool _awaitingRadiusTap = false;

  /// Mode « Déplacer » : la carte devient non interactive, le tap est désarmé
  /// et l'adaptateur (s'il est [ZMapGesturesCapable]) rend le marqueur de
  /// déplacement au centroïde.
  bool _isMoveMode = false;

  /// Style **brouillon** du picker : le style est PERSISTÉ dans la valeur à
  /// chaque émission. Amorcé depuis la valeur initiale quand `showStylePicker`
  /// est actif ; `null` (picker absent ou aucun style choisi) ⇒ émissions
  /// strictement inchangées (AD-4).
  ZGeoShapeStyle? _draftStyle;

  /// Options de carte **neutres** pilotées par la barre d'outils. `null`
  /// quand il n'y a **aucune** barre d'outils (`buildMap` reçoit alors
  /// `mapOptions: null`). Mutable via des actions **discrètes** de la barre
  /// (type de carte / toggles features) — JAMAIS sur la voie de frappe (AD-2).
  ZGeoMapOptions? _mapOptions;

  /// Config de barre d'outils : `toolbarConfig` absent (`null`, config
  /// présente ou non) → barre **`standard`** par défaut. L'opt-out explicite
  /// est `ZGeoEditorToolbarConfig.none` (`disabled: true`).
  ZGeoEditorToolbarConfig get _toolbarConfig =>
      _config?.toolbarConfig ?? ZGeoEditorToolbarConfig.standard;

  /// Géométries proposées par le sélecteur de mode. `null` → champ
  /// mono-géométrie (aucun sélecteur).
  List<ZGeoGeometry>? get _allowedGeometries => _config?.allowedGeometries;

  bool get _isArea => _geometry == ZGeoGeometry.polygon;
  bool get _isCircle => _geometry == ZGeoGeometry.circle;

  /// Polyligne (tracé ouvert). Même collecte de sommets que le polygone :
  /// seule la géométrie de rendu (ouverte) diffère côté adaptateur.
  bool get _isPolyline => _geometry == ZGeoGeometry.polyline;

  /// `true` pour les géométries qui **collectent une liste de sommets**
  /// (polygone fermé OU polyligne ouverte) : elles partagent la même UI d'ajout/
  /// retrait de sommet et le même état `ZGeoShape` « au fil de l'eau ».
  bool get _collectsVertices => _isArea || _isPolyline;

  bool get _hasFieldFocus =>
      _latFocus.hasFocus || _lngFocus.hasFocus || _radiusFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    final Object? cfg = widget.ctx.field.config;
    _config = cfg is ZGeoFieldConfig ? cfg : null;
    _geometry = _resolveGeometry();
    // Une barre d'outils existe par défaut (`standard`) → l'état d'options de
    // carte est toujours amorcé (type `hybrid`, etc.).
    _mapOptions = const ZGeoMapOptions();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _radiusController = TextEditingController();
    _latFocus = FocusNode();
    _lngFocus = FocusNode();
    _radiusFocus = FocusNode();
    // Créer l'instance d'adaptateur possédée UNE FOIS par montage. La clé
    // par-champ (`ZGeoFieldConfig.adapterKey`) sélectionne une fabrique
    // NOMMÉE du registre du builder ; clé absente/inconnue → repli sur la
    // fabrique unique (hôte mono-factory, AD-10).
    final String? adapterKey = _config?.adapterKey;
    final ZMapAdapterFactory? factory =
        (adapterKey == null ? null : widget.adapterFactories?[adapterKey]) ??
            widget.adapterFactory;
    _mapAdapter = factory?.call();
    // Amorcer le style brouillon depuis la valeur initiale (une fois),
    // uniquement quand le picker est câblé (sinon aucune incidence — AD-4).
    if (_config?.showStylePicker ?? false) {
      _draftStyle = switch (ZGeoValue.fromMapSafe(widget.ctx.value)) {
        final ZGeoPoint p => p.style,
        final ZGeoCircle c => c.style,
        final ZGeoShape s => s.style,
        _ => null,
      };
    }
    switch (_geometry) {
      case ZGeoGeometry.polygon:
      case ZGeoGeometry.polyline:
        // Champs texte = sommet CANDIDAT transitoire → pas d'amorçage depuis la
        // tranche ; on amorce l'état de forme « au fil de l'eau ».
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

  /// Résout la géométrie initiale du champ. Sur un champ **multi-géométries**
  /// (`allowedGeometries` non-`null`) :
  /// 1. **la géométrie portée par la valeur initiale PRIME** — même si elle
  ///    est absente d'`allowedGeometries` (la donnée gagne toujours).
  /// Puis, pour tous les champs : 2. `config.geometry` ;
  /// 3. `config.allowedGeometries.first` ;
  /// 4. `widget.geometry` (défaut builder) ; 5. inférence par nom de type
  /// (`geoArea`→polygon, sinon point). Un champ **mono-géométrie** (sans
  /// `allowedGeometries`) garde la résolution STRICTE par cette chaîne (la
  /// valeur ne prime pas : aucune bascule surprise sur une valeur
  /// structurellement ambiguë).
  ZGeoGeometry _resolveGeometry() {
    if (_config?.allowedGeometries != null) {
      final ZGeoGeometry? fromValue = _geometryOfValue(widget.ctx.value);
      if (fromValue != null) return fromValue;
    }
    final ZGeoGeometry? fromConfig = _config?.geometry;
    if (fromConfig != null) return fromConfig;
    final List<ZGeoGeometry>? allowed = _config?.allowedGeometries;
    if (allowed != null && allowed.isNotEmpty) return allowed.first;
    final ZGeoGeometry? fromBuilder = widget.geometry;
    if (fromBuilder != null) return fromBuilder;
    return widget.ctx.field.type.name == 'geoArea'
        ? ZGeoGeometry.polygon
        : ZGeoGeometry.point;
  }

  /// Géométrie portée par la valeur initiale, via le routeur discriminé
  /// [ZGeoValue.fromMapSafe]. `null` si la valeur est absente/vide/
  /// inexploitable (AD-10 — on retombe alors sur la chaîne config/builder).
  /// Une `ZGeoShape` non discriminée compte pour `polygon`, SAUF si la chaîne
  /// config/builder aurait résolu `polyline` (une forme nue ne distingue pas
  /// tracé ouvert/fermé — seule la config le sait) ; une valeur qui porte un
  /// discriminant `type: 'polyline'` explicite, elle, tranche pour `polyline`.
  ZGeoGeometry? _geometryOfValue(Object? raw) {
    if (raw == null) return null;
    // Discriminant explicite auto-descriptif (enveloppe compatible legacy).
    final Object? decoded = zGeoDecodeLegacyEnvelope(raw);
    if (decoded is Map && decoded['type'] == 'polyline') {
      return ZGeoGeometry.polyline;
    }
    final Object? value = ZGeoValue.fromMapSafe(raw);
    return switch (value) {
      ZGeoPoint() => ZGeoGeometry.point,
      ZGeoCircle() => ZGeoGeometry.circle,
      ZGeoShape(isNotEmpty: true) => _configuredGeometry() ==
              ZGeoGeometry.polyline
          ? ZGeoGeometry.polyline
          : ZGeoGeometry.polygon,
      _ => null, // forme vide / valeur inexploitable → chaîne config/builder
    };
  }

  /// Géométrie qu'aurait résolue la chaîne config/builder/inférence SANS la
  /// valeur (sert d'oracle polygone-vs-polyligne à [_geometryOfValue]).
  ZGeoGeometry _configuredGeometry() =>
      _config?.geometry ??
      widget.geometry ??
      (widget.ctx.field.type.name == 'geoArea'
          ? ZGeoGeometry.polygon
          : ZGeoGeometry.point);

  @override
  void didUpdateWidget(covariant ZGeoFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    switch (_geometry) {
      case ZGeoGeometry.polygon:
      case ZGeoGeometry.polyline:
        // Adopter une valeur de forme EXTERNE (≠ celle qu'on a émise) ;
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
    // Anti-fuite : libérer contrôleurs/focus ET le contrôleur natif de
    // l'adaptateur carte possédé par ce champ.
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
    // Le style brouillon voyage avec la valeur.
    final point = ZGeoPoint(lat: lat, lng: lng, style: _draftStyle);
    widget.ctx.onChanged(point.isValid ? point : null);
  }

  /// Mode `point` : fixe le point depuis un tap carte (coordonnées neutres).
  void _setPointFromTap(ZGeoPoint point) {
    _latController.text = _fmt(point.lat);
    _lngController.text = _fmt(point.lng);
    // Style brouillon persisté dans la valeur (aucun effet si `null`).
    widget.ctx.onChanged(
      _draftStyle == null ? point : point.copyWith(style: _draftStyle),
    );
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
      // Le style brouillon voyage avec la valeur.
      style: _draftStyle,
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

  /// Aire courante « au fil de l'eau » : l'état local possédé prime sur
  /// `widget.ctx.value` (rafraîchi seulement au rebuild) pour sérialiser les
  /// mutations survenant dans la même frame. Repli défensif sur la tranche.
  ZGeoShape get _currentShape => _workingShape ?? _shapeOf(widget.ctx.value);

  /// Mode `polygon` : ajoute [point] (tap carte ou candidat) à l'aire courante,
  /// de façon **atomique** : on part de l'aire « au fil de l'eau », on la met
  /// à jour AVANT d'émettre → deux ajouts rapprochés ne se perdent pas.
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

  // --- Actions de la barre d'outils (voie unique `ctx.onChanged`) ------------

  /// **sélecteur de mode** : bascule la géométrie courante.
  ///
  /// ## Politique d'effacement au changement de mode (EXPLICITE, gardée)
  ///
  /// Le changement de mode **efface les sommets** (rayon compris), sans
  /// confirmation, et le rend **visible dans la tranche** : il vide l'état de
  /// travail (contrôleurs texte, forme « au fil de l'eau ») **et émet
  /// `null`** — la tranche ne porte jamais une valeur d'une géométrie
  /// incompatible avec le mode affiché. Ce n'est PAS une destruction
  /// silencieuse de données persistées : l'enregistrement n'a lieu qu'à la
  /// sauvegarde du formulaire par l'utilisateur ; tant qu'il ne sauve pas, la
  /// donnée stockée est intacte. Aucune émission ni effacement si [mode] est
  /// déjà la géométrie courante (no-op strict). Action **discrète**
  /// (`setState`), jamais la voie de frappe (AD-2) ; contrôleurs/focus jamais
  /// recréés.
  void _setGeometry(ZGeoGeometry mode) {
    if (mode == _geometry) return; // no-op strict : rien n'est effacé
    setState(() {
      _geometry = mode;
      _latController.clear();
      _lngController.clear();
      _radiusController.clear();
      _workingShape = _collectsVertices ? ZGeoShape() : null;
      _awaitingRadiusTap = false; // machine 2-taps réarmée
      _isMoveMode = false; // le mode Déplacer ne survit pas au changement
    });
    widget.ctx.onChanged(null);
  }

  /// **clear** : remet la valeur de tranche à `null`, vide les contrôleurs
  /// texte et réinitialise l'aire « au fil de l'eau ». Ne recrée ni contrôleurs
  /// ni focus (AD-2) ; l'émission `null` déclenche le rebuild ciblé de la tranche.
  void _clearAll() {
    _latController.clear();
    _lngController.clear();
    _radiusController.clear();
    if (_collectsVertices) _workingShape = ZGeoShape();
    if (_awaitingRadiusTap) {
      // Réarmer la machine 2-taps (retire aussi l'aperçu 10 m).
      setState(() => _awaitingRadiusTap = false);
    }
    widget.ctx.onChanged(null);
  }

  /// **undo** : polygone → retire le dernier sommet (réutilise l'écriture
  /// atomique [_removeVertex]) ; point/cercle → efface la dernière saisie (un
  /// seul état → équivaut à [_clearAll]). Aucune exception si rien à annuler
  /// (AD-10).
  void _undo() {
    switch (_geometry) {
      case ZGeoGeometry.polygon:
      case ZGeoGeometry.polyline:
        final shape = _currentShape;
        if (shape.vertices.isEmpty) return; // rien à annuler → no-op silencieux
        _removeVertex(shape.vertices.length - 1);
      case ZGeoGeometry.circle:
      case ZGeoGeometry.point:
        _clearAll();
    }
  }

  /// Zoom du recentrage « ma position ».
  static const double _myLocationZoom = 16;

  /// **ma-position** : appelle le [ZGeoLocationResolver] injecté.
  /// `null`/erreur → no-op silencieux (AD-10, jamais de crash) ; garde
  /// `mounted` après l'`await`.
  ///
  /// En polygone/polyligne, la position résolue **RECENTRE la caméra
  /// (zoom 16)** — elle n'ajoute **JAMAIS** un sommet : « ma position » est
  /// une commande de NAVIGATION, pas un point de tracé. En point/cercle, la
  /// valeur est fixée **et** la caméra est recentrée. Le recentrage n'est
  /// effectif que si l'adaptateur est [ZMapCameraCapable] (honoré-si-supporté)
  /// — sinon no-op sans crash.
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
      case ZGeoGeometry.polyline:
        break; // Recentrage SEULEMENT — aucun sommet ajouté
      case ZGeoGeometry.circle:
        _setCircleCenterFromTap(point);
      case ZGeoGeometry.point:
        _setPointFromTap(point);
    }
    await _moveCameraTo(point, zoom: _myLocationZoom);
  }

  /// Recentrage caméra **honoré-si-supporté** : no-op silencieux si
  /// l'adaptateur n'est pas [ZMapCameraCapable] ou si l'appel échoue (AD-10).
  Future<void> _moveCameraTo(ZGeoPoint point, {double? zoom}) async {
    // `Object?` : permet la promotion vers la capacité (interface disjointe du
    // port pur — un `ZMapAdapter?` ne se promeut pas vers `ZMapCameraCapable`).
    final Object? adapter = _mapAdapter;
    if (adapter is! ZMapCameraCapable) return;
    try {
      await adapter.moveCamera(point, zoom: zoom);
    } catch (_) {
      // AD-10 : un adaptateur défaillant ne crashe jamais le champ.
    }
  }

  /// Tap carte en mode cercle, machine « 2 taps » : 1er tap = **centre**
  /// (aperçu 10 m tant que le rayon n'est pas fixé), 2e tap = **rayon**
  /// (distance haversine centre→tap, arrondie au décimètre pour le champ
  /// texte — qui RESTE éditable). Un tap suivant repart sur un nouveau
  /// centre. Distance nulle (double tap au même point) → le tap est traité
  /// comme un nouveau centre (un rayon 0 est invalide).
  void _handleCircleTap(ZGeoPoint point) {
    if (_awaitingRadiusTap) {
      final double? lat = _parse(_latController.text);
      final double? lng = _parse(_lngController.text);
      if (lat != null && lng != null) {
        final ZGeoPoint center = ZGeoPoint(lat: lat, lng: lng);
        final double radius = center.distanceMetersTo(point);
        if (radius.isFinite && radius > 0) {
          _radiusController.text = _fmt((radius * 10).roundToDouble() / 10);
          setState(() => _awaitingRadiusTap = false);
          _emitCircleFromFields();
          return;
        }
      }
      // Centre illisible ou distance nulle → retomber sur « nouveau centre ».
    }
    _latController.text = _fmt(point.lat);
    _lngController.text = _fmt(point.lng);
    setState(() => _awaitingRadiusTap = true);
    _emitCircleFromFields();
  }

  // --- Gestes d'édition carte (honorés-si-supportés) --------------------------

  /// Fin de drag d'un sommet : remplace le sommet [index] (écriture
  /// atomique sur l'aire « au fil de l'eau », cf. [_appendVertex]). Index
  /// hors-bornes ou point invalide → no-op (AD-10).
  void _handleVertexDragEnd(int index, ZGeoPoint position) {
    if (!position.isValid) return;
    final ZGeoShape shape = _currentShape;
    if (index < 0 || index >= shape.vertices.length) return;
    final List<ZGeoPoint> vertices = <ZGeoPoint>[...shape.vertices];
    vertices[index] = position;
    final ZGeoShape next = shape.copyWith(vertices: vertices);
    _workingShape = next;
    widget.ctx.onChanged(next);
  }

  /// Fin de déplacement de forme (marqueur au centroïde) : translate TOUS les
  /// sommets du delta, trous compris. Si un sommet translaté sort des bornes
  /// géographiques, le déplacement est abandonné en bloc (AD-10 : jamais une
  /// forme partiellement déplacée ni hors-bornes).
  void _handleShapeDragEnd(double deltaLat, double deltaLng) {
    if (!deltaLat.isFinite || !deltaLng.isFinite) return;
    final ZGeoShape shape = _currentShape;
    if (shape.vertices.isEmpty) return;
    List<ZGeoPoint>? shift(List<ZGeoPoint> points) {
      final List<ZGeoPoint> out = <ZGeoPoint>[];
      for (final ZGeoPoint p in points) {
        final ZGeoPoint moved =
            p.copyWith(lat: p.lat + deltaLat, lng: p.lng + deltaLng);
        if (!moved.isValid) return null;
        out.add(moved);
      }
      return out;
    }

    final List<ZGeoPoint>? vertices = shift(shape.vertices);
    if (vertices == null) return;
    List<List<ZGeoPoint>>? holes;
    if (shape.holes != null) {
      holes = <List<ZGeoPoint>>[];
      for (final List<ZGeoPoint> hole in shape.holes!) {
        final List<ZGeoPoint>? moved = shift(hole);
        if (moved == null) return;
        holes.add(moved);
      }
    }
    final ZGeoShape next =
        shape.copyWith(vertices: vertices, holes: holes);
    _workingShape = next;
    widget.ctx.onChanged(next);
  }

  /// Fin de drag de la poignée de rayon : nouveau rayon en mètres (arrondi au
  /// décimètre, reflété dans le champ texte). Rayon non fini/≤0 → no-op
  /// (AD-10).
  void _handleRadiusDragEnd(double radiusMeters) {
    if (!radiusMeters.isFinite || radiusMeters <= 0) return;
    _radiusController.text = _fmt((radiusMeters * 10).roundToDouble() / 10);
    if (_awaitingRadiusTap) setState(() => _awaitingRadiusTap = false);
    _emitCircleFromFields();
  }

  /// Bascule du mode « Déplacer » (action discrète, AD-2).
  void _toggleMoveMode() => setState(() => _isMoveMode = !_isMoveMode);

  /// Applique un style choisi au picker : mémorise le brouillon ET le
  /// **persiste dans la valeur courante** si elle existe (le style de la
  /// forme est porté par la valeur). Sans valeur, le brouillon sera attaché
  /// à la prochaine émission. Action discrète (`setState` pour rafraîchir
  /// l'aperçu), jamais la voie de frappe (AD-2).
  void _applyStyle(ZGeoShapeStyle style) {
    setState(() => _draftStyle = style);
    switch (_geometry) {
      case ZGeoGeometry.polygon:
      case ZGeoGeometry.polyline:
        final ZGeoShape shape = _currentShape;
        final ZGeoShape next = shape.copyWith(style: style);
        _workingShape = next;
        if (shape.isNotEmpty) widget.ctx.onChanged(next);
      case ZGeoGeometry.circle:
        final ZGeoCircle? circle = _circleOf(widget.ctx.value);
        if (circle != null) {
          widget.ctx.onChanged(circle.copyWith(style: style));
        }
      case ZGeoGeometry.point:
        final ZGeoPoint? point = _pointOf(widget.ctx.value);
        if (point != null) {
          widget.ctx.onChanged(point.copyWith(style: style));
        }
    }
  }

  /// **Optimisation de polygone** (flag `showOptimizeButton`) : réordonne les
  /// sommets par angle autour du centroïde contre l'auto-intersection (tri
  /// `atan2` — la géométrie pure vit dans
  /// `ZGeoShapeMetrics.sortedByAngleAroundCentroid`). `< 3` sommets → no-op.
  /// SnackBar **localisée** (texte via l10n injectée).
  void _optimizePolygon() {
    final ZGeoShape shape = _currentShape;
    if (shape.vertices.length < 3) return;
    final ZGeoShape next = shape.sortedByAngleAroundCentroid();
    _workingShape = next;
    widget.ctx.onChanged(next);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          label(
            context,
            'geo.optimized',
            fallback: 'Tracé optimisé et réordonné',
          ),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Types de carte disponibles selon `showExtendedMapTypes` (Normal/Hybride, +
  /// Satellite/Terrain en étendu).
  List<ZGeoMapType> get _availableMapTypes =>
      _toolbarConfig.showExtendedMapTypes
          ? const <ZGeoMapType>[
              ZGeoMapType.normal,
              ZGeoMapType.hybrid,
              ZGeoMapType.satellite,
              ZGeoMapType.terrain,
            ]
          : const <ZGeoMapType>[ZGeoMapType.normal, ZGeoMapType.hybrid];

  /// **type-de-carte** : cycle vers le type suivant (action **discrète** —
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

  // Ne pas faire confiance à un `ZGeoPoint` déjà en tranche que s'il est
  // dans les bornes (le constructeur n'a pas d'`assert`) ; sinon le re-parser
  // défensivement (AD-10) → jamais de coordonnée hors-bornes envoyée à la carte.
  ZGeoPoint? _pointOf(Object? value) => value is ZGeoPoint
      ? (value.isValid ? value : null)
      : ZGeoPoint.fromMapSafe(value);

  ZGeoShape _shapeOf(Object? value) => value is ZGeoShape
      ? value
      : (ZGeoShape.fromMapSafe(value) ?? ZGeoShape());

  // Même défiance pour le cercle : ne faire confiance qu'à un `ZGeoCircle` valide.
  ZGeoCircle? _circleOf(Object? value) => value is ZGeoCircle
      ? (value.isValid ? value : null)
      : ZGeoCircle.fromMapSafe(value);

  static double? _parse(String raw) {
    final d = double.tryParse(raw.trim());
    return (d != null && d.isFinite) ? d : null;
  }

  static String _fmt(double v) => v.toString();

  /// Hauteur de carte résolue. Une hauteur de builder **infinie** (mode
  /// immersif du plein écran) PRIME sur `config.mapHeight` — sinon un champ
  /// configuré à hauteur fixe ne serait jamais immersif en plein écran. En
  /// mode chrome, si NI la config NI le builder ne surchargent la hauteur, le
  /// défaut est `ZGeoChromeReference.chromeMapHeight` (**300**, le look du
  /// chrome) ; le défaut hors chrome reste 200.
  double get _resolvedMapHeight {
    if (widget.mapHeight.isInfinite) return widget.mapHeight;
    final double? fromConfig = _config?.mapHeight;
    if (fromConfig != null) return fromConfig;
    if ((_config?.showChrome ?? false) &&
        widget.mapHeight == ZGeoFieldWidget._defaultMapHeight) {
      return ZGeoChromeReference.chromeMapHeight;
    }
    return widget.mapHeight;
  }

  /// Mode immersif (rendu DANS la route plein écran) : la carte remplit
  /// l'espace et le bouton plein écran n'est pas re-rendu.
  bool get _isImmersive => _resolvedMapHeight.isInfinite;

  /// `true` quand le champ est rendu en **aperçu de flux**
  /// (`presentation: previewWithFullscreen`) : carte lecture seule (pan/zoom
  /// conservés, tap/drags désarmés), aucune saisie, aucune barre. **Jamais
  /// `true` en mode immersif** (`!_isImmersive`) : la route plein écran rend
  /// le MÊME champ avec la MÊME config — la restriction porte sur la
  /// présentation en flux, PAS sur la config.
  bool get _isPreview =>
      (_config?.presentation ?? ZGeoPresentation.inlineEditor) ==
          ZGeoPresentation.previewWithFullscreen &&
      !_isImmersive;

  /// Le bouton plein écran est rendu si la config l'autorise (défaut `true`)
  /// ET qu'une carte existe (adaptateur injecté) ET qu'on n'est pas déjà en
  /// plein écran. Visible aussi en lecture seule (consultation immersive).
  /// **Exception aperçu** : en `previewWithFullscreen`, l'icône n'est rendue
  /// que si le champ est **éditable** — un champ en lecture seule montre
  /// l'aperçu, sans porte d'entrée.
  bool get _showFullscreenButton =>
      (_config?.allowFullscreen ?? true) &&
      _mapAdapter != null &&
      !_isImmersive &&
      (!_isPreview || !widget.ctx.field.readOnly);

  /// Callback de frappe des champs centre selon la géométrie (voie SENS UNIQUE
  /// AD-2 : la frappe écrit la tranche, jamais de ré-injection pendant le focus).
  ValueChanged<String>? get _coordOnChanged => switch (_geometry) {
        ZGeoGeometry.point => (_) => _emitPointFromFields(),
        ZGeoGeometry.circle => (_) => _emitCircleFromFields(),
        // Polygone/polyligne : les champs texte sont des sommets CANDIDATS
        // (ajoutés via bouton), jamais réémis à la frappe (AD-2).
        ZGeoGeometry.polygon || ZGeoGeometry.polyline => null,
      };

  // --- Rendu ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;

    // Chrome opt-in (jamais en mode immersif — la route plein écran a son
    // propre chrome AppBar).
    final bool chrome = (_config?.showChrome ?? false) && !_isImmersive;

    // Aperçu de flux — quand `false` (défaut `inlineEditor`), les conditions
    // ci-dessous sont STRICTEMENT celles du rendu par défaut (arbre identique).
    final bool preview = _isPreview;

    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // En mode immersif, la colonne occupe la hauteur disponible et la
      // carte s'étend (`Expanded`) — hors immersif, rien ne change.
      mainAxisSize: _isImmersive ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        // En-tête = libellé + bouton plein écran (bouton d'en-tête ouvrant
        // la route immersive). En mode chrome, l'en-tête devient le bandeau
        // dégradé + icône.
        if (chrome)
          _chromeHeader(context, theme, resolvedLabel)
        else
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  resolvedLabel,
                  style: TextStyle(color: theme.labelColor),
                ),
              ),
              if (_showFullscreenButton) _fullscreenButton(context),
            ],
          ),
        SizedBox(height: theme.gapS),
        // En aperçu (`previewWithFullscreen`), AUCUN bloc d'édition en flux
        // — ni saisie lat/lng, ni liste de sommets, ni barre d'outils, ni
        // picker.
        if (!preview) _coordinateRow(theme),
        if (!preview && _isCircle) ...<Widget>[
          SizedBox(height: theme.gapS),
          _radiusField(context),
        ],
        if (!preview && _collectsVertices) ...<Widget>[
          SizedBox(height: theme.gapS),
          _addVertexButton(context),
          SizedBox(height: theme.gapS),
          _vertexList(context, theme),
        ],
        // Barre d'outils d'éditeur, rendue par défaut (config `standard`)
        // sauf opt-out explicite (`ZGeoEditorToolbarConfig.none` /
        // `disabled: true`). Placée AU-DESSUS de la carte.
        if (!preview && !_toolbarConfig.disabled) ...<Widget>[
          SizedBox(height: theme.gapM),
          _toolbar(context, theme),
        ],
        // Picker de style câblé (opt-in `showStylePicker`), style persisté
        // dans la valeur via [_applyStyle].
        if (!preview && (_config?.showStylePicker ?? false)) ...<Widget>[
          SizedBox(height: theme.gapS),
          ZGeoShapeStylePicker(
            key: const Key('z-geo-style-picker'),
            style: _draftStyle,
            onChanged: _applyStyle,
            readOnly: widget.ctx.field.readOnly,
          ),
        ],
        SizedBox(height: theme.gapM),
        if (_isImmersive)
          Expanded(child: _mapSurface(context))
        else
          _mapSurface(context),
        // Chip de métriques opt-in (aire | périmètre + compteur, unités via
        // l10n injectée). Hors aperçu : le flux d'aperçu ne rend que
        // en-tête + carte + pied.
        if (!preview && (_config?.showMetrics ?? false))
          _metricsBar(context, theme),
        // Pied de carte LOCALISÉ (`geo.pointsDefined`), rendu seulement en
        // édition, hors plein écran. En aperçu, le pied « N points » est
        // TOUJOURS rendu (chrome ou non, readOnly compris — l'aperçu se
        // décrit) ; hors aperçu, condition STRICTE (édition + chrome).
        if (preview || (chrome && !widget.ctx.field.readOnly))
          _chromeFooter(context, theme),
      ],
    );

    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Padding(
        padding: theme.fieldPadding,
        child: chrome ? _chromeCard(context, child: column) : column,
      ),
    );
  }

  /// Couleur d'accent du chrome : **paramètre > référence** — le dégradé
  /// violet de référence n'est pas dérivable du `ColorScheme` ; ses ARGB
  /// vivent UNIQUEMENT dans `ZGeoChromeReference`.
  List<Color> get _chromeGradient => const <Color>[
        Color(ZGeoChromeReference.headerGradientStartArgb),
        Color(ZGeoChromeReference.headerGradientEndArgb),
      ];

  /// Encart carte : rayon 14, bordure teintée 1.5/1 selon contenu, ombre
  /// blur 8 offset (0,2). Fond par rôle de thème (`surface`) ; seules les
  /// valeurs non dérivables viennent de la référence auditée.
  Widget _chromeCard(BuildContext context, {required Widget child}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasContent = _hasAnyContent;
    final Color accent = _chromeGradient.first;
    return Container(
      key: const Key('z-geo-chrome'),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(ZGeoChromeReference.cardRadius),
        border: Border.all(
          color: hasContent ? accent.withAlpha(80) : scheme.outlineVariant,
          width: hasContent
              ? ZGeoChromeReference.borderWidthWithContent
              : ZGeoChromeReference.borderWidthEmpty,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (hasContent ? accent : scheme.shadow).withAlpha(10),
            blurRadius: ZGeoChromeReference.shadowBlurRadius,
            offset: const Offset(0, ZGeoChromeReference.shadowOffsetY),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Bandeau d'en-tête dégradé + icône carte + libellé + bouton plein écran
  /// (libellé du champ, thème pour le texte, dégradé de référence pour
  /// l'accent).
  Widget _chromeHeader(
    BuildContext context,
    ZcrudTheme theme,
    String resolvedLabel,
  ) {
    final List<Color> gradient = _chromeGradient;
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    return Container(
      key: const Key('z-geo-chrome-header'),
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient
              .map((Color c) => c.withAlpha(isDark ? 30 : 15))
              .toList(growable: false),
        ),
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(ZGeoChromeReference.headerRadius),
          topEnd: Radius.circular(ZGeoChromeReference.headerRadius),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsetsDirectional.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient
                    .map((Color c) => c.withAlpha(isDark ? 60 : 40))
                    .toList(growable: false),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.map,
              size: 18,
              color: isDark
                  ? Theme.of(context).colorScheme.onSurface
                  : gradient.first,
            ),
          ),
          SizedBox(width: theme.gapM),
          Expanded(
            child: Text(
              resolvedLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (_showFullscreenButton) _fullscreenButton(context),
        ],
      ),
    );
  }

  /// `true` si le champ porte une valeur exploitable (pilote la bordure du
  /// chrome).
  bool get _hasAnyContent => switch (_geometry) {
        ZGeoGeometry.polygon ||
        ZGeoGeometry.polyline =>
          _currentShape.isNotEmpty,
        ZGeoGeometry.circle => _circleOf(widget.ctx.value) != null,
        ZGeoGeometry.point => _pointOf(widget.ctx.value) != null,
      };

  /// Nombre de points « définis » (pied de carte + compteur de métriques).
  int get _definedPointCount => switch (_geometry) {
        ZGeoGeometry.polygon ||
        ZGeoGeometry.polyline =>
          _currentShape.vertices.length,
        ZGeoGeometry.circle => _circleOf(widget.ctx.value) == null ? 0 : 1,
        ZGeoGeometry.point => _pointOf(widget.ctx.value) == null ? 0 : 1,
      };

  /// Pied de carte **localisé** (clé `geo.pointsDefined`) : jamais de texte
  /// figé, toujours routé par la l10n injectée. Couleurs par rôles de thème.
  Widget _chromeFooter(BuildContext context, ZcrudTheme theme) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String suffix = label(
      context,
      'geo.pointsDefined',
      fallback: 'point(s) défini(s) — touchez la carte pour ajouter',
    );
    return Container(
      key: const Key('z-geo-footer'),
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: 8,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Text(
        '$_definedPointCount $suffix',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Formats des métriques (≥ 1 000 000 m² → km² à 2 décimales ; ≥ 1 000 m →
  /// km à 2 décimales), **unités via la l10n injectée** (`geo.unit.*` — aucun
  /// « m² » figé hors repli de dernier recours).
  String _formatArea(BuildContext context, double m2) => m2 >= 1000000
      ? '${(m2 / 1000000).toStringAsFixed(2)} '
          '${label(context, 'geo.unit.km2', fallback: 'km²')}'
      : '${m2.toStringAsFixed(0)} '
          '${label(context, 'geo.unit.m2', fallback: 'm²')}';

  String _formatLength(BuildContext context, double m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(2)} '
          '${label(context, 'geo.unit.km', fallback: 'km')}'
      : '${m.toStringAsFixed(0)} ${label(context, 'geo.unit.m', fallback: 'm')}'
  ;

  /// Barre de métriques opt-in : compteur de points en gras + chip « aire |
  /// périmètre » quand l'aire est > 0. Couleurs par rôles de thème (aucune
  /// couleur en dur). Calculs = extensions pures de `z_geo_metrics.dart`
  /// (aire sphérique pour le polygone, π·r² planaire pour le cercle — nature
  /// documentée dans la bibliothèque de métriques).
  Widget _metricsBar(BuildContext context, ZcrudTheme theme) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    double? area;
    double? perimeter;
    switch (_geometry) {
      case ZGeoGeometry.polygon:
        final ZGeoShape shape = _currentShape;
        area = shape.areaSquareMeters;
        perimeter = shape.perimeterMeters;
      case ZGeoGeometry.polyline:
        // Tracé ouvert : aucune aire, longueur SANS segment de fermeture.
        perimeter = _currentShape.lengthMeters;
      case ZGeoGeometry.circle:
        final ZGeoCircle? circle = _circleOf(widget.ctx.value);
        area = circle?.areaSquareMeters;
        perimeter = circle?.perimeterMeters;
      case ZGeoGeometry.point:
        break; // aucun chiffre à porter en mode point
    }
    final bool hasChip = (area ?? 0) > 0 || (perimeter ?? 0) > 0;
    final String chipText = <String>[
      if (area != null && area > 0) _formatArea(context, area),
      if (perimeter != null && perimeter > 0)
        _formatLength(context, perimeter),
    ].join(' | ');
    return Padding(
      padding: EdgeInsetsDirectional.only(top: theme.gapS),
      child: Row(
        children: <Widget>[
          if (_collectsVertices)
            Text(
              '$_definedPointCount '
              '${label(context, 'geo.points', fallback: 'points')}',
              key: const Key('z-geo-metrics-count'),
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.start,
            ),
          const Spacer(),
          if (hasChip)
            Container(
              key: const Key('z-geo-metrics'),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                chipText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
                textAlign: TextAlign.start,
              ),
            ),
        ],
      ),
    );
  }

  /// Bouton d'en-tête « plein écran » (≥48dp, `Semantics`, l10n injectée —
  /// invariant AD-13 : aucune couleur ni libellé en dur).
  Widget _fullscreenButton(BuildContext context) {
    final String text =
        label(context, 'geo.fullscreen', fallback: 'Plein écran');
    return ConstrainedBox(
      key: const Key('z-geo-fullscreen'),
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Semantics(
        container: true,
        button: true,
        label: text,
        child: ExcludeSemantics(
          child: IconButton(
            onPressed: _openFullscreen,
            icon: const Icon(Icons.fullscreen),
            tooltip: text,
          ),
        ),
      ),
    );
  }

  /// Ouvre la route d'édition **immersive** : le MÊME champ y est rendu
  /// (`mapHeight` infini) sur un **brouillon** — la tranche n'est écrite qu'au
  /// retour « Enregistrer » (fermeture sans enregistrer → tranche intacte ;
  /// l'abandon d'un brouillon modifié demande confirmation — jamais de perte
  /// silencieuse).
  Future<void> _openFullscreen() async {
    final _ZGeoFullscreenResult? result =
        await Navigator.of(context).push<_ZGeoFullscreenResult>(
      MaterialPageRoute<_ZGeoFullscreenResult>(
        fullscreenDialog: true,
        builder: (BuildContext _) => _ZGeoFullscreenPage(
          field: widget.ctx.field,
          initialValue: widget.ctx.value,
          adapterFactory: widget.adapterFactory,
          adapterFactories: widget.adapterFactories,
          geometry: widget.geometry,
          locationResolver: widget.locationResolver,
        ),
      ),
    );
    if (result == null || !mounted) return;
    // Adoption du résultat (mode + points + rayon repris de la forme
    // retournée) — action discrète, hors voie de frappe (AD-2) ;
    // contrôleurs/focus jamais recréés.
    setState(() {
      _geometry = result.geometry;
      _awaitingRadiusTap = false;
      _isMoveMode = false;
      switch (_geometry) {
        case ZGeoGeometry.polygon:
        case ZGeoGeometry.polyline:
          _workingShape = _shapeOf(result.value);
          _latController.clear();
          _lngController.clear();
        case ZGeoGeometry.circle:
          _workingShape = null;
          final ZGeoCircle? circle = _circleOf(result.value);
          _latController.text = circle == null ? '' : _fmt(circle.center.lat);
          _lngController.text = circle == null ? '' : _fmt(circle.center.lng);
          _radiusController.text =
              circle == null ? '' : _fmt(circle.radiusMeters);
        case ZGeoGeometry.point:
          _workingShape = null;
          final ZGeoPoint? point = _pointOf(result.value);
          _latController.text = point == null ? '' : _fmt(point.lat);
          _lngController.text = point == null ? '' : _fmt(point.lng);
      }
    });
    widget.ctx.onChanged(result.value);
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
                // Libellé routé via l10n injectée (`ZcrudScope.labels` →
                // delegate → repli `en`), repli littéral français en dernier
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

  /// Surface carte via l'adaptateur **possédé** ; repli propre si aucune
  /// fabrique n'a été fournie.
  Widget _mapSurface(BuildContext context) {
    final adapter = _mapAdapter;
    if (adapter == null) {
      // Repli AD-1 : aucun adaptateur → coordonnées-seules, jamais de crash.
      return const SizedBox.shrink();
    }
    final bool readOnly = widget.ctx.field.readOnly;
    // En aperçu, les GESTES D'ÉDITION sont désarmés (tap d'ajout, drags)
    // mais la carte reste manipulable (pan/zoom) — désarmer LE TAP, jamais
    // la carte.
    final bool preview = _isPreview;
    final bool editable = !preview && !readOnly && (_config?.interactive ?? true);
    final ZGeoShape? areaShape = _collectsVertices ? _currentShape : null;
    ZGeoCircle? circle = _isCircle ? _circleOf(widget.ctx.value) : null;
    // Aperçu 10 m entre le 1er tap (centre) et le 2e (rayon). Rendu avec
    // les couleurs de repli du thème injecté — zcrud ne code aucune couleur.
    if (_isCircle && _awaitingRadiusTap && circle == null) {
      final double? lat = _parse(_latController.text);
      final double? lng = _parse(_lngController.text);
      if (lat != null && lng != null) {
        final ZGeoPoint previewCenter = ZGeoPoint(lat: lat, lng: lng);
        if (previewCenter.isValid) {
          circle = ZGeoCircle(center: previewCenter, radiusMeters: 10);
        }
      }
    }
    // (Dé)poser les handlers de gestes si l'adaptateur les supporte
    // (honoré-si-supporté ; `null` ⇒ poignées non rendues — AD-4).
    final Object gestures = adapter; // promotion vers la capacité disjointe
    if (gestures is ZMapGesturesCapable) {
      gestures.onVertexDragEnd =
          (editable && _collectsVertices) ? _handleVertexDragEnd : null;
      gestures.onShapeDragEnd = (editable && _collectsVertices && _isMoveMode)
          ? _handleShapeDragEnd
          : null;
      gestures.onCircleRadiusDragEnd =
          (editable && _isCircle && circle != null && circle.isValid)
              ? _handleRadiusDragEnd
              : null;
    }
    // Centre de carte : valeur courante, sinon repli sur le défaut surchargeable
    // de la config (neutre ; AD-12), sinon choix de l'adaptateur.
    final ZGeoPoint? center = switch (_geometry) {
      ZGeoGeometry.polygon || ZGeoGeometry.polyline =>
        areaShape!.vertices.firstOrNull ?? _config?.defaultCenter,
      ZGeoGeometry.circle => circle?.center ?? _config?.defaultCenter,
      ZGeoGeometry.point =>
        _pointOf(widget.ctx.value) ?? _config?.defaultCenter,
    };
    final Widget map = adapter.buildMap(
      context,
      center: center,
      shape: areaShape,
      circle: circle,
      // En mode « Déplacer », la carte n'est plus interactive — seul le
      // marqueur au centroïde se manipule. L'aperçu garde le pan/zoom
      // (`interactive: true`) — c'est le TAP qui est désarmé (`onTap: null`),
      // pas la carte.
      interactive: preview || (editable && !_isMoveMode),
      // Surcharges par-champ plombées à l'adaptateur (chaque adaptateur
      // honore celles qui le concernent).
      tileUrlTemplate: _config?.tileUrlTemplate,
      // Gabarits de tuiles par type de carte (honorés par OSM ; Google a
      // ses types natifs). `null` → défauts audités ZGeoTileReference.
      tileUrlTemplates: _config?.tileUrlTemplates,
      mapStyleJson: _config?.mapStyleJson,
      defaultZoom: _config?.defaultZoom,
      // Bornes de zoom par-champ (honorées-si-supportées ; `zoomStep` reste
      // une donnée de config sans consommateur SDK — documenté).
      minZoom: _config?.minZoom,
      maxZoom: _config?.maxZoom,
      // Options de carte neutres pilotées par la barre (`null` si aucune
      // barre → comportement inchangé). Honoré-si-supporté par l'adaptateur.
      mapOptions: _mapOptions,
      // Signal neutre « rendre la forme en tracé ouvert » ; `true` seulement
      // en géométrie polyligne (honoré-si-supporté par l'adaptateur).
      renderShapeAsPolyline: _isPolyline,
      onTap: (preview || readOnly || _isMoveMode)
          ? null // Tap désarmé en mode Déplacer ET en aperçu
          : (ZGeoPoint point) {
              switch (_geometry) {
                case ZGeoGeometry.polygon:
                case ZGeoGeometry.polyline:
                  _appendVertex(point);
                case ZGeoGeometry.circle:
                  _handleCircleTap(point); // Machine 2-taps
                case ZGeoGeometry.point:
                  _setPointFromTap(point);
              }
            },
    );
    // Hauteur infinie = mode immersif (plein écran) → la surface remplit
    // l'espace donné par le parent (`Expanded` dans [build]) au lieu d'une
    // hauteur fixe.
    if (_resolvedMapHeight.isInfinite) return map;
    return SizedBox(height: _resolvedMapHeight, child: map);
  }

  // --- Barre d'outils ----------------------------------------------------

  /// Barre d'outils d'éditeur (clé `z-geo-toolbar`). Boutons **gated par leurs
  /// toggles** (undo/clear/ma-position/type-de-carte + toggles d'options carte).
  /// Layout **directionnel** (`Wrap`), cibles ≥48dp, `Semantics`/tooltip, thème
  /// injecté — aucune couleur en dur (AD-13).
  Widget _toolbar(BuildContext context, ZcrudTheme theme) {
    final ZGeoEditorToolbarConfig cfg = _toolbarConfig;
    final bool readOnly = widget.ctx.field.readOnly;
    // Compaction RESPONSIVE : largeur d'écran < seuil ⇒ compact. Seuil :
    // config > référence auditée (600) ; `0` ⇒ opt-out de la compaction
    // automatique.
    final double breakpoint =
        cfg.compactBreakpointDp ?? ZGeoChromeReference.compactBreakpointDp;
    final bool compact = cfg.compactMode ||
        (breakpoint > 0 && MediaQuery.sizeOf(context).width < breakpoint);
    // Libellés textuels seulement hors mode compact (icônes seules).
    final bool showLabels = cfg.showButtonLabels && !compact;
    final bool hasResolver = widget.locationResolver != null;
    // Sélecteur de mode fonctionnel — rendu seulement si le champ est
    // multi-géométries ET que la config l'affiche.
    final List<ZGeoGeometry> modes = _allowedGeometries ?? const <ZGeoGeometry>[];

    final List<Widget> buttons = <Widget>[
      if (modes.length > 1 && cfg.showModeSelector)
        for (final ZGeoGeometry mode in modes)
          _mapOptionToggle(
            context: context,
            key: Key('z-geo-mode-${mode.name}'),
            icon: _modeIcon(mode),
            l10nKey: 'geo.mode.${mode.name}',
            fallback: _modeFallbackLabel(mode),
            selected: _geometry == mode,
            showLabels: showLabels,
            onPressed: readOnly ? null : () => _setGeometry(mode),
          ),
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
      // Bouton d'optimisation (tri anti-auto-intersection) — rendu pour les
      // géométries à sommets uniquement.
      if (cfg.showOptimizeButton && _collectsVertices)
        _toolbarButton(
          context: context,
          key: const Key('z-geo-optimize'),
          icon: Icons.auto_fix_high_outlined,
          l10nKey: 'geo.optimize',
          fallback: 'Optimiser',
          showLabels: showLabels,
          onPressed: readOnly ? null : _optimizePolygon,
        ),
      // « ma position » : présent seulement si le seam est injecté.
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
      // Mode « Déplacer » — rendu seulement si l'adaptateur supporte les
      // gestes ([ZMapGesturesCapable], honoré-si-supporté) et que la
      // géométrie collecte des sommets. Pas de flag de config : le bouton
      // est toujours rendu quand supporté.
      if (_collectsVertices && _mapAdapter is ZMapGesturesCapable)
        _mapOptionToggle(
          context: context,
          key: const Key('z-geo-move'),
          icon: Icons.open_with,
          l10nKey: 'geo.move',
          fallback: 'Déplacer',
          selected: _isMoveMode,
          showLabels: showLabels,
          onPressed: readOnly ? null : _toggleMoveMode,
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
      // `useMapOptionsDropdown` regroupe ces toggles dans un menu déroulant
      // (libellé `cfg.mapOptionsLabel`, surchargeable) au lieu du `Wrap` plat.
      if (cfg.useMapOptionsDropdown && _optionToggleSpecs(cfg).isNotEmpty)
        _mapOptionsDropdown(context, cfg, readOnly)
      else
        for (final _ZGeoOptionToggleSpec spec in _optionToggleSpecs(cfg))
          _mapOptionToggle(
            context: context,
            key: spec.key,
            icon: spec.icon,
            l10nKey: spec.l10nKey,
            fallback: spec.fallback,
            selected: spec.selected,
            showLabels: showLabels,
            onPressed: readOnly ? null : spec.toggle,
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

  /// Specs des toggles d'options carte activés par [cfg] (source UNIQUE du
  /// `Wrap` plat ET du menu déroulant — même liste, deux rendus).
  List<_ZGeoOptionToggleSpec> _optionToggleSpecs(
    ZGeoEditorToolbarConfig cfg,
  ) =>
      <_ZGeoOptionToggleSpec>[
        if (cfg.showTrafficToggle)
          _ZGeoOptionToggleSpec(
            key: const Key('z-geo-traffic'),
            icon: Icons.traffic_outlined,
            l10nKey: 'geo.traffic',
            fallback: 'Trafic',
            selected: _mapOptions?.trafficEnabled ?? false,
            toggle: () => _updateMapOptions(
                (o) => o.copyWith(trafficEnabled: !o.trafficEnabled)),
          ),
        if (cfg.showBuildingsToggle)
          _ZGeoOptionToggleSpec(
            key: const Key('z-geo-buildings'),
            icon: Icons.apartment_outlined,
            l10nKey: 'geo.buildings',
            fallback: 'Bâtiments',
            selected: _mapOptions?.buildingsEnabled ?? false,
            toggle: () => _updateMapOptions(
                (o) => o.copyWith(buildingsEnabled: !o.buildingsEnabled)),
          ),
        if (cfg.showIndoorViewToggle)
          _ZGeoOptionToggleSpec(
            key: const Key('z-geo-indoor'),
            icon: Icons.meeting_room_outlined,
            l10nKey: 'geo.indoor',
            fallback: 'Intérieur',
            selected: _mapOptions?.indoorViewEnabled ?? false,
            toggle: () => _updateMapOptions(
                (o) => o.copyWith(indoorViewEnabled: !o.indoorViewEnabled)),
          ),
        if (cfg.showRotationToggle)
          _ZGeoOptionToggleSpec(
            key: const Key('z-geo-rotation'),
            icon: Icons.rotate_left_outlined,
            l10nKey: 'geo.rotation',
            fallback: 'Rotation',
            selected: _mapOptions?.rotateGesturesEnabled ?? false,
            toggle: () => _updateMapOptions((o) =>
                o.copyWith(rotateGesturesEnabled: !o.rotateGesturesEnabled)),
          ),
        if (cfg.showTiltToggle)
          _ZGeoOptionToggleSpec(
            key: const Key('z-geo-tilt'),
            icon: Icons.threed_rotation_outlined,
            l10nKey: 'geo.tilt',
            fallback: 'Inclinaison',
            selected: _mapOptions?.tiltGesturesEnabled ?? false,
            toggle: () => _updateMapOptions((o) =>
                o.copyWith(tiltGesturesEnabled: !o.tiltGesturesEnabled)),
          ),
        if (cfg.showZoomControlsToggle)
          _ZGeoOptionToggleSpec(
            key: const Key('z-geo-zoom-controls'),
            icon: Icons.zoom_in_outlined,
            l10nKey: 'geo.zoomControls',
            fallback: 'Zoom',
            selected: _mapOptions?.zoomControlsEnabled ?? false,
            toggle: () => _updateMapOptions((o) =>
                o.copyWith(zoomControlsEnabled: !o.zoomControlsEnabled)),
          ),
        if (cfg.showCompassToggle)
          _ZGeoOptionToggleSpec(
            key: const Key('z-geo-compass'),
            icon: Icons.explore_outlined,
            l10nKey: 'geo.compass',
            fallback: 'Boussole',
            selected: _mapOptions?.compassEnabled ?? false,
            toggle: () => _updateMapOptions(
                (o) => o.copyWith(compassEnabled: !o.compassEnabled)),
          ),
        if (cfg.showMapToolbarToggle)
          _ZGeoOptionToggleSpec(
            key: const Key('z-geo-map-toolbar'),
            icon: Icons.build_outlined,
            l10nKey: 'geo.mapToolbar',
            fallback: 'Outils carte',
            selected: _mapOptions?.mapToolbarEnabled ?? false,
            toggle: () => _updateMapOptions(
                (o) => o.copyWith(mapToolbarEnabled: !o.mapToolbarEnabled)),
          ),
      ];

  /// Menu déroulant des options de carte (`useMapOptionsDropdown`). Chaque
  /// entrée cochée reflète l'état du toggle ; libellé du bouton =
  /// `cfg.mapOptionsLabel` (donnée surchargeable). ≥48dp, `Semantics`
  /// porteur (AD-13).
  Widget _mapOptionsDropdown(
    BuildContext context,
    ZGeoEditorToolbarConfig cfg,
    bool readOnly,
  ) {
    final List<_ZGeoOptionToggleSpec> specs = _optionToggleSpecs(cfg);
    return ConstrainedBox(
      key: const Key('z-geo-map-options-dropdown'),
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Semantics(
        container: true,
        button: true,
        enabled: !readOnly,
        label: cfg.mapOptionsLabel,
        child: ExcludeSemantics(
          child: PopupMenuButton<int>(
            enabled: !readOnly,
            tooltip: cfg.mapOptionsLabel,
            onSelected: (int index) {
              if (index >= 0 && index < specs.length) specs[index].toggle();
            },
            itemBuilder: (BuildContext menuContext) =>
                <PopupMenuEntry<int>>[
              for (int i = 0; i < specs.length; i++)
                CheckedPopupMenuItem<int>(
                  key: specs[i].key,
                  value: i,
                  checked: specs[i].selected,
                  child: Text(
                    label(
                      menuContext,
                      specs[i].l10nKey,
                      fallback: specs[i].fallback,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.tune_outlined),
                  SizedBox(width: ZcrudTheme.of(context).gapS),
                  Text(cfg.mapOptionsLabel, textAlign: TextAlign.start),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Icône du sélecteur de mode.
  IconData _modeIcon(ZGeoGeometry mode) => switch (mode) {
        ZGeoGeometry.point => Icons.place_rounded,
        ZGeoGeometry.circle => Icons.radio_button_unchecked_rounded,
        ZGeoGeometry.polygon => Icons.pentagon_rounded,
        ZGeoGeometry.polyline => Icons.timeline_rounded,
      };

  /// Libellé de repli du sélecteur de mode (le libellé effectif passe par
  /// la l10n injectée `geo.mode.*`).
  String _modeFallbackLabel(ZGeoGeometry mode) => switch (mode) {
        ZGeoGeometry.point => 'Point',
        ZGeoGeometry.circle => 'Cercle',
        ZGeoGeometry.polygon => 'Polygone',
        ZGeoGeometry.polyline => 'Ligne',
      };

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

/// Spec d'un toggle d'option de carte : une seule source pour le rendu
/// `Wrap` plat ET le menu déroulant.
class _ZGeoOptionToggleSpec {
  const _ZGeoOptionToggleSpec({
    required this.key,
    required this.icon,
    required this.l10nKey,
    required this.fallback,
    required this.selected,
    required this.toggle,
  });

  final Key key;
  final IconData icon;
  final String l10nKey;
  final String fallback;
  final bool selected;
  final VoidCallback toggle;
}

/// Résultat d'un « Enregistrer » de la route plein écran : valeur validée +
/// géométrie courante de l'éditeur immersif (le sélecteur de mode peut y
/// avoir changé la géométrie).
class _ZGeoFullscreenResult {
  const _ZGeoFullscreenResult({required this.value, required this.geometry});

  /// Valeur neutre validée (jamais un type SDK).
  final Object? value;

  /// Géométrie de l'éditeur immersif au moment de l'enregistrement.
  final ZGeoGeometry geometry;
}

/// Route d'édition **immersive** du champ géo : rend LE MÊME champ
/// ([ZGeoFieldWidget], `mapHeight` infini) sur un **brouillon local** — la
/// tranche du formulaire n'est JAMAIS écrite par cette page ; seul le retour
/// « Enregistrer » (validé par géométrie) remonte une valeur au champ
/// parent, qui écrit alors la tranche (voie unique `ctx.onChanged`).
///
/// Fermeture sans enregistrer : la tranche reste intacte MAIS un brouillon
/// **modifié** demande confirmation avant d'être abandonné — jamais de perte
/// silencieuse (esprit de l'invariant AD-10).
///
/// L'éditeur immersif possède SA PROPRE instance d'adaptateur (la fabrique
/// est rappelée à son montage) : jamais d'instance partagée avec le champ
/// encarté.
class _ZGeoFullscreenPage extends StatefulWidget {
  const _ZGeoFullscreenPage({
    required this.field,
    required this.initialValue,
    this.adapterFactory,
    this.adapterFactories,
    this.geometry,
    this.locationResolver,
  });

  /// Spec du champ (libellé/readOnly/config — la même que le champ encarté).
  final ZFieldSpec field;

  /// Valeur de tranche au moment de l'ouverture (graine du brouillon).
  final Object? initialValue;

  /// Fabrique d'adaptateur carte (rappelée par l'éditeur immersif).
  final ZMapAdapterFactory? adapterFactory;

  /// Registre de fabriques nommées, transmis tel quel.
  final Map<String, ZMapAdapterFactory>? adapterFactories;

  /// Géométrie par défaut du builder, transmise telle quelle.
  final ZGeoGeometry? geometry;

  /// Seam « ma position », transmis tel quel.
  final ZGeoLocationResolver? locationResolver;

  @override
  State<_ZGeoFullscreenPage> createState() => _ZGeoFullscreenPageState();
}

class _ZGeoFullscreenPageState extends State<_ZGeoFullscreenPage> {
  /// Brouillon local : reçoit les émissions de l'éditeur immersif. La tranche
  /// du formulaire n'est jamais touchée par cette page.
  late Object? _draft = widget.initialValue;

  /// `true` dès la première émission de l'éditeur immersif (garde d'abandon).
  bool _dirty = false;

  /// Accès à l'état de l'éditeur immersif (géométrie courante + saisie
  /// partielle), possible car même bibliothèque.
  final GlobalKey _fieldKey = GlobalKey();

  _ZGeoFieldWidgetState? get _fieldState {
    final State<StatefulWidget>? s = _fieldKey.currentState;
    return s is _ZGeoFieldWidgetState ? s : null;
  }

  /// Géométrie courante de l'éditeur immersif (repli : même chaîne de
  /// résolution config/builder/inférence que le champ).
  ZGeoGeometry get _geometry {
    final _ZGeoFieldWidgetState? s = _fieldState;
    if (s != null) return s._geometry;
    final Object? cfg = widget.field.config;
    final ZGeoFieldConfig? config = cfg is ZGeoFieldConfig ? cfg : null;
    return config?.geometry ??
        widget.geometry ??
        (widget.field.type.name == 'geoArea'
            ? ZGeoGeometry.polygon
            : ZGeoGeometry.point);
  }

  /// Validation par géométrie : point → 1 point ; cercle → centre + rayon
  /// (un `ZGeoCircle` valide) ; polygone → ≥3 sommets ; polyligne → ≥2
  /// sommets. Valide → pop(résultat) ; invalide → SnackBar localisée (y
  /// compris le message « aucune donnée » quand le brouillon est vide hors
  /// mode point).
  void _save() {
    final ZGeoGeometry g = _geometry;
    final Object? v = _draft;
    final bool valid;
    final String invalidKey;
    final String invalidFallback;
    switch (g) {
      case ZGeoGeometry.point:
        final ZGeoPoint? p = v is ZGeoPoint
            ? (v.isValid ? v : null)
            : ZGeoPoint.fromMapSafe(v);
        valid = p != null;
        invalidKey = 'geo.fullscreen.invalid.point';
        invalidFallback = 'Veuillez sélectionner un point.';
      case ZGeoGeometry.circle:
        final ZGeoCircle? c = v is ZGeoCircle
            ? (v.isValid ? v : null)
            : ZGeoCircle.fromMapSafe(v);
        valid = c != null;
        invalidKey = 'geo.fullscreen.invalid.circle';
        invalidFallback = 'Veuillez définir un rayon pour le cercle.';
      case ZGeoGeometry.polygon:
        final ZGeoShape? s =
            v is ZGeoShape ? v : ZGeoShape.fromMapSafe(v);
        valid = (s?.vertices.length ?? 0) >= 3;
        invalidKey = 'geo.fullscreen.invalid.polygon';
        invalidFallback = 'Le polygone doit avoir au moins 3 points.';
      case ZGeoGeometry.polyline:
        final ZGeoShape? s =
            v is ZGeoShape ? v : ZGeoShape.fromMapSafe(v);
        valid = (s?.vertices.length ?? 0) >= 2;
        invalidKey = 'geo.fullscreen.invalid.polyline';
        invalidFallback = 'La ligne doit avoir au moins 2 points.';
    }
    if (valid) {
      Navigator.of(context)
          .pop(_ZGeoFullscreenResult(value: v, geometry: g));
      return;
    }
    // Contenu partiel (ou mode point) → message d'erreur de la géométrie ;
    // brouillon vide hors point → « aucune donnée ».
    final String msg = (_hasPartialContent(v) || g == ZGeoGeometry.point)
        ? label(context, invalidKey, fallback: invalidFallback)
        : label(
            context,
            'geo.fullscreen.empty',
            fallback: 'Aucune donnée géographique à enregistrer.',
          );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// Contenu partiel : brouillon non vide, OU saisie en cours dans l'éditeur
  /// immersif (ex. cercle au centre posé sans rayon — la tranche vaut `null`
  /// car zcrud n'émet que du valide).
  bool _hasPartialContent(Object? v) {
    if (v != null && !(v is ZGeoShape && v.isEmpty)) return true;
    final _ZGeoFieldWidgetState? s = _fieldState;
    return s != null &&
        (s._latController.text.trim().isNotEmpty ||
            s._lngController.text.trim().isNotEmpty);
  }

  /// Garde d'abandon (fermeture avec brouillon modifié) : confirmation
  /// localisée — jamais de perte silencieuse.
  Future<void> _confirmDiscard() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        content: Text(
          label(
            dialogContext,
            'geo.fullscreen.discard',
            fallback: 'Abandonner les modifications non enregistrées ?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('z-geo-fullscreen-keep'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              label(
                dialogContext,
                'geo.fullscreen.keepEditing',
                fallback: "Continuer l'édition",
              ),
            ),
          ),
          TextButton(
            key: const Key('z-geo-fullscreen-discard'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              label(
                dialogContext,
                'geo.fullscreen.discardConfirm',
                fallback: 'Abandonner',
              ),
            ),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.field.label ?? widget.field.name;
    final bool readOnly = widget.field.readOnly;
    final String saveText = label(context, 'geo.save', fallback: 'Enregistrer');
    return PopScope(
      // Brouillon intact → fermeture directe ; modifié → garde.
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          // Leading auto : bouton de fermeture (route `fullscreenDialog`).
          title: Text(title),
          actions: <Widget>[
            if (!readOnly)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ConstrainedBox(
                  key: const Key('z-geo-fullscreen-save'),
                  constraints:
                      const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: Semantics(
                    container: true,
                    button: true,
                    label: saveText,
                    child: ExcludeSemantics(
                      child: TextButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: Text(saveText),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: ZGeoFieldWidget(
          key: _fieldKey,
          ctx: ZFieldWidgetContext(
            field: widget.field,
            value: _draft,
            // Voie brouillon : l'éditeur immersif écrit ICI, jamais la
            // tranche. Rebuild UNIQUEMENT sur changement de VALEUR : une
            // ré-émission identique (ex. 1er tap cercle : centre posé mais
            // rayon manquant → `null` alors que le brouillon est déjà `null`)
            // ne doit pas re-parenter l'éditeur — sa sync guardée relirait le
            // brouillon inchangé et EFFACERAIT la saisie de centre en cours
            // (même sémantique que la tranche réelle : un `setValue` sans
            // changement ne notifie pas).
            onChanged: (Object? v) {
              if (v == _draft) return;
              setState(() {
                _draft = v;
                _dirty = true;
              });
            },
          ),
          adapterFactory: widget.adapterFactory,
          adapterFactories: widget.adapterFactories,
          geometry: widget.geometry,
          // Mode immersif — la carte remplit la page.
          mapHeight: double.infinity,
          locationResolver: widget.locationResolver,
        ),
      ),
    );
  }
}
