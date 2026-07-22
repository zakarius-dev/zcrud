/// Implémentation NATIVE du port `ZDropRegionRenderer` (`zcrud_core`), adossée
/// à `super_drag_and_drop` (AD-57).
///
/// C'est le SEUL fichier du paquet qui importe le tiers. Tout le reste — les
/// règles de traduction, de filtrage et de robustesse — vit dans
/// `domain/z_drop_kind_mapping.dart`, sans engine ni plateforme, donc
/// réellement exécutable en test.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_drop_kind_mapping.dart';
import '../domain/z_drop_read_failure.dart';

/// Zone de dépôt **native** : reçoit fichiers, images, textes et adresses
/// venus du système ou d'une autre application.
///
/// À NE PAS confondre avec le réordonnancement interne (`ZReorderRenderer` /
/// `zcrud_reorder`) : ce sont deux capacités distinctes, et seule celle-ci
/// impose une chaîne de compilation native.
///
/// ```dart
/// ZcrudScope(
///   dropRegionRenderer: const ZNativeDropRegionRenderer(),
///   child: MyApp(),
/// )
/// ```
///
/// **Aucune affordance visuelle n'est rendue** : `request.child` est passé tel
/// quel au `DropRegion` (contrat 1 du port). Le survol est signalé par
/// `request.onHoverChanged`, à charge de l'hôte de le peindre avec SON thème —
/// c'est ce qui garantit qu'aucune couleur n'est codée en dur ici, et que la
/// zone reste correcte en RTL (aucune géométrie directionnelle n'est
/// introduite).
class ZNativeDropRegionRenderer extends ZDropRegionRenderer {
  /// Construit le renderer natif.
  const ZNativeDropRegionRenderer();

  @override
  Widget build(BuildContext context, ZDropRegionRequest request) =>
      _ZNativeDropRegion(request: request);
}

/// Widget interne portant l'état de survol.
///
/// `StatefulWidget` **sans `setState`** : l'état de survol ne change RIEN au
/// rendu (le child est rendu inchangé), il n'est mémorisé que pour ne notifier
/// `onHoverChanged` qu'aux vraies transitions entrée/sortie. Reconstruire ici
/// serait une régression SM-1 gratuite à chaque déplacement du curseur.
class _ZNativeDropRegion extends StatefulWidget {
  const _ZNativeDropRegion({required this.request});

  final ZDropRegionRequest request;

  @override
  State<_ZNativeDropRegion> createState() => _ZNativeDropRegionState();
}

class _ZNativeDropRegionState extends State<_ZNativeDropRegion> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (_hovering == value) return;
    _hovering = value;
    // AD-10 — un hôte qui lève dans son affordance ne doit pas casser la
    // session de glissement en cours.
    try {
      widget.request.onHoverChanged?.call(value);
    } catch (_) {
      // ignoré volontairement
    }
  }

  /// Natures candidates d'un élément, sans jamais lever (AD-10).
  Set<ZDropKind> _candidates(DropItem item) {
    try {
      final reader = item.dataReader;
      return zCandidateDropKinds(
        reader != null ? reader.platformFormats : item.platformFormats,
      );
    } catch (_) {
      return const <ZDropKind>{ZDropKind.unknown};
    }
  }

  bool _sessionIsAcceptable(DropSession session) {
    final Set<ZDropKind> accepts = widget.request.accepts;
    for (final DropItem item in session.items) {
      if (zSelectDropKind(_candidates(item), accepts) != null) return true;
    }
    return false;
  }

  DropOperation _onDropOver(DropOverEvent event) {
    try {
      if (!_sessionIsAcceptable(event.session)) {
        // Contrat 5 : pas d'affordance pour un glissement non acceptable.
        _setHovering(false);
        return DropOperation.none;
      }
      _setHovering(true);
      final Set<DropOperation> allowed = event.session.allowedOperations;
      if (allowed.contains(DropOperation.copy)) return DropOperation.copy;
      for (final DropOperation op in allowed) {
        if (op != DropOperation.none) return op;
      }
      return DropOperation.none;
    } catch (_) {
      // AD-10 — refuser plutôt que faire remonter une exception au natif.
      return DropOperation.none;
    }
  }

  void _onDropLeave(DropEvent event) => _setHovering(false);

  void _onDropEnded(DropEvent event) => _setHovering(false);

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    _setHovering(false);
    try {
      final List<ZDropItemSource> sources = event.session.items
          .map<ZDropItemSource>(_SuperDropItemSource.new)
          .toList(growable: false);
      final List<ZDroppedItem> items = await zBuildDroppedItems(
        sources,
        widget.request.accepts,
      );
      // Contrat 2 : un dépôt entièrement hors `accepts` est ignoré en silence.
      if (items.isEmpty) return;
      widget.request.onDrop(items);
    } catch (_) {
      // AD-10 — un dépôt corrompu n'est jamais une erreur remontée au natif.
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: _formatsFor(widget.request.accepts),
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: _onDropOver,
      onDropLeave: _onDropLeave,
      onDropEnded: _onDropEnded,
      onPerformDrop: _onPerformDrop,
      // Contrat 1 : le contenu est rendu INCHANGÉ. Aucune décoration, aucune
      // couleur, aucune géométrie ajoutée.
      child: widget.request.child,
    );
  }
}

/// Formats natifs déclarés au `DropRegion`, dérivés des natures acceptées.
///
/// Ne déclarer que le nécessaire évite que la zone s'active (et notifie un
/// survol) pour un contenu que l'hôte rejetterait de toute façon.
List<DataFormat<Object>> _formatsFor(Set<ZDropKind> accepts) {
  // `file` et `unknown` sont des natures « attrape-tout » : il faut écouter
  // large, le tri se fera sur les formats réellement annoncés.
  if (accepts.contains(ZDropKind.file) || accepts.contains(ZDropKind.unknown)) {
    return Formats.standardFormats;
  }
  final List<DataFormat<Object>> out = <DataFormat<Object>>[];
  if (accepts.contains(ZDropKind.image)) {
    out.addAll(const <DataFormat<Object>>[
      Formats.png,
      Formats.jpeg,
      Formats.gif,
      Formats.webp,
      Formats.tiff,
      Formats.bmp,
      Formats.svg,
      Formats.heic,
      Formats.heif,
      Formats.ico,
    ]);
  }
  if (accepts.contains(ZDropKind.uri)) {
    out.addAll(const <DataFormat<Object>>[Formats.uri, Formats.fileUri]);
  }
  if (accepts.contains(ZDropKind.text)) {
    out.addAll(const <DataFormat<Object>>[
      Formats.plainText,
      Formats.htmlText,
      Formats.plainTextFile,
    ]);
  }
  return out.isEmpty ? Formats.standardFormats : out;
}

/// Adaptateur `super_drag_and_drop` -> [ZDropItemSource].
///
/// C'est ici, et nulle part ailleurs, que le tiers est converti en vocabulaire
/// neutre. Cette classe est privée : aucun type tiers ne peut donc fuir dans
/// une signature publique du paquet (AD-57, condition 2).
class _SuperDropItemSource extends ZDropItemSource {
  _SuperDropItemSource(this._item);

  final DropItem _item;

  // Types volontairement inférés : `DataReader`, `ReadProgress` et
  // `DataReaderFile` appartiennent à `super_clipboard`, que
  // `super_drag_and_drop` ne réexporte pas. Ne pas les nommer évite d'ajouter
  // une seconde dépendance tierce pour de simples annotations.
  @override
  List<String> get platformFormats {
    final reader = _item.dataReader;
    return reader != null
        ? reader.platformFormats
        : _item.platformFormats;
  }

  @override
  Future<String?> readSuggestedName() async {
    final reader = _item.dataReader;
    if (reader == null) return null;
    return reader.getSuggestedName();
  }

  @override
  Future<String?> readText() {
    final reader = _item.dataReader;
    if (reader == null) return Future<String?>.value();

    final Completer<String?> completer = Completer<String?>();
    void complete(String? value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    Object? progress;
    if (reader.canProvide(Formats.plainText)) {
      progress = reader.getValue<String>(
        Formats.plainText,
        complete,
        onError: (_) => complete(null),
      );
    } else if (reader.canProvide(Formats.uri)) {
      progress = reader.getValue<NamedUri>(
        Formats.uri,
        (NamedUri? value) => complete(value?.uri.toString()),
        onError: (_) => complete(null),
      );
    } else if (reader.canProvide(Formats.fileUri)) {
      progress = reader.getValue<Uri>(
        Formats.fileUri,
        (Uri? value) => complete(value?.toString()),
        onError: (_) => complete(null),
      );
    }
    // `null` ⇒ la valeur n'est finalement pas disponible et `onValue` ne sera
    // jamais appelé : sans cela la future resterait pendante à jamais.
    if (progress == null) complete(null);
    return completer.future;
  }

  @override
  Future<Uint8List> readBytes() {
    final reader = _item.dataReader;
    if (reader == null) {
      return Future<Uint8List>.error(
        const ZDropReadFailure('aucun lecteur disponible pour cet élément'),
      );
    }

    final Completer<Uint8List> completer = Completer<Uint8List>();
    void fail(Object error) {
      if (!completer.isCompleted) {
        completer.completeError(ZDropReadFailure('$error'));
      }
    }

    // `format: null` laisse `super_clipboard` choisir : fichier virtuel,
    // fichier synthétisé depuis une URI, ou format natif le plus prioritaire.
    // C'est ce qui rend la lecture correcte pour les fichiers « virtuels »
    // (contenu produit à la demande) sans traitement particulier ici.
    final progress = reader.getFile(
      null,
      (file) async {
        try {
          final Uint8List data = await file.readAll();
          if (!completer.isCompleted) completer.complete(data);
        } catch (error) {
          fail(error);
        }
      },
      onError: fail,
    );
    if (progress == null) {
      fail('contenu binaire indisponible pour cet élément');
    }
    return completer.future;
  }
}
