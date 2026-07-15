/// `ZAnnotationToolController` — état LOCAL et ISOLÉ de la toolbar d'annotation
/// (ES-8.2, D1/D3, AD-2/AD-15/SM-1).
///
/// **Réactivité Flutter-native, AUCUN gestionnaire d'état** (AD-2/AD-15) :
/// `ChangeNotifier` **pur-Flutter** (`package:flutter/foundation.dart`
/// uniquement) — jamais `flutter_riverpod`/`get`/`provider`, jamais un
/// `WidgetRef`/`Get.`/`Provider.of`. L'état mutable de la toolbar (le `kind`
/// sélectionné et la `colorKey` sélectionnée) est exposé **une tranche à la
/// fois** via une [ValueListenable] par champ : un widget qui n'écoute que
/// [selectedColorKey] ne se reconstruit **pas** quand [selectedKind] change, et
/// inversement (rebuild ciblé, zéro reconstruction globale — SM-1).
///
/// Patron **owned/injected** (précédent `ZMindmapOutlineController`, ES-7.1) :
/// la toolbar crée un controller en `initState` **ssi** aucun n'est injecté et
/// le `dispose` **ssi** elle le possède — **jamais** recréé au `build`.
///
/// **`colorKey` reste une `String` opaque** (AD-4) : le controller ne connaît
/// aucune `Color`, aucune palette, aucun index — la résolution
/// `colorKey → Color` est un seam de présentation (`ZcrudScope.colorKeyResolver`).
library;

import 'package:flutter/foundation.dart';

import '../domain/z_document_annotation_kind.dart';

/// Préfixe de [ValueKey] d'un bouton de `kind` (`zAnnotationKind_<name>`, AC1/R24).
const String kAnnotationKindKeyPrefix = 'zAnnotationKind_';

/// Préfixe de [ValueKey] d'une swatch de `colorKey` (`zAnnotationSwatch_<key>`,
/// AC2/R24).
const String kAnnotationSwatchKeyPrefix = 'zAnnotationSwatch_';

/// Préfixe de [ValueKey] du **fond coloré** d'une swatch
/// (`zAnnotationSwatchFill_<key>`) — permet aux tests de LIRE la `Color`
/// réellement rendue (contraste mesuré AC5, couleur injectée AC11).
const String kAnnotationSwatchFillKeyPrefix = 'zAnnotationSwatchFill_';

/// Clé de [ValueKey] du **marqueur STRUCTUREL non-coloré** de sélection (icône
/// « coché ») — présent UNIQUEMENT dans la swatch sélectionnée (AC4/R24 : la
/// sélection n'est JAMAIS signalée par la seule couleur d'un anneau).
const String kAnnotationSelectedMarkerKey = 'zAnnotationSelectedMarker';

/// Préfixe de [ValueKey] d'une entrée de `ZAnnotationPanel`
/// (`zAnnotationPanelEntry_<id|index>`, AC9).
const String kAnnotationPanelEntryKeyPrefix = 'zAnnotationPanelEntry_';

/// Controller `ChangeNotifier` **pur-Flutter** de la toolbar d'annotation.
///
/// Détient DEUX tranches indépendantes, chacune exposée par sa propre
/// [ValueListenable] : [selectedKind] et [selectedColorKey]. Muter l'une ne
/// notifie **que** ses écouteurs (rebuild ciblé, SM-1).
class ZAnnotationToolController extends ChangeNotifier {
  /// Construit le controller sur un état initial (défauts défensifs alignés sur
  /// le domaine : `kind` = 1ʳᵉ constante, `colorKey` brute vide).
  ZAnnotationToolController({
    ZDocumentAnnotationKind initialKind = ZDocumentAnnotationKind.highlight,
    String initialColorKey = '',
  })  : _selectedKind = ValueNotifier<ZDocumentAnnotationKind>(initialKind),
        _selectedColorKey = ValueNotifier<String>(initialColorKey);

  final ValueNotifier<ZDocumentAnnotationKind> _selectedKind;
  final ValueNotifier<String> _selectedColorKey;

  /// Tranche « nature de l'annotation sélectionnée » (écoute ciblée).
  ValueListenable<ZDocumentAnnotationKind> get selectedKind => _selectedKind;

  /// Tranche « `colorKey` sélectionnée » (`String` opaque, AD-4 ; écoute ciblée).
  ValueListenable<String> get selectedColorKey => _selectedColorKey;

  /// Sélectionne un [kind] — notifie **uniquement** les écouteurs de
  /// [selectedKind].
  void selectKind(ZDocumentAnnotationKind kind) => _selectedKind.value = kind;

  /// Sélectionne une [colorKey] BRUTE — notifie **uniquement** les écouteurs de
  /// [selectedColorKey]. Aucune normalisation de palette ici (D6/AD-4).
  void selectColorKey(String colorKey) => _selectedColorKey.value = colorKey;

  @override
  void dispose() {
    _selectedKind.dispose();
    _selectedColorKey.dispose();
    super.dispose();
  }
}
