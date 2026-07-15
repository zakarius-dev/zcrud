/// État de vue **local** et libellés a11y des contrôles de `ZMindmapView`
/// (Story ES-7.2, AD-2/AD-15/AD-13/FR-26).
///
/// [ZMindmapViewController] est un **détenteur d'état pur-Flutter** (agrégat de
/// `ValueNotifier`) — **AUCUN** gestionnaire d'état tiers (`flutter_riverpod`,
/// `get`, `provider`), **AUCUN** `setState` global : chaque tranche (zoom,
/// compact, plein-écran, super-racine) est une `ValueNotifier` isolée pilotant un
/// `ValueListenableBuilder` ciblé (rebuild granulaire, SM-1). Le zoom est
/// **CLAMPÉ** à `[minScale, maxScale]` **dans le contrôleur** (la garde de
/// bornage vit ici, pas dans le widget) : le retirer laisse la valeur d'échelle
/// dépasser `maxScale` (INJ-1, AC2).
///
/// **ADDITIF STRICT (AC6/D8)** : `ZMindmapView` n'expose ce contrôleur qu'en
/// paramètre **optionnel** ; `null` ⇒ comportement E10 inchangé (aucune barre de
/// contrôle, aucune enveloppe de zoom). Instancier/`dispose` du contrôleur est à
/// la charge de l'app hôte (cycle de vie stable, AD-2).
library;

import 'package:flutter/foundation.dart';

/// Détenteur d'état de vue **local** des contrôles de carte mentale.
///
/// Pur-Flutter (`ValueNotifier`), **sans** dépendance à un gestionnaire d'état.
/// Chaque affordance est une tranche indépendante : muter l'une ne notifie **que**
/// ses propres écouteurs (rebuild ciblé, AD-2/AD-15/SM-1).
class ZMindmapViewController {
  /// Construit un contrôleur de vue.
  ///
  /// - [initialScale] : échelle de départ (clampée à `[minScale, maxScale]`) ;
  /// - [minScale]/[maxScale] : bornes **dures** du zoom (garde AC2) ;
  /// - [zoomStep] : pas d'un zoom-in/out (> 0) ;
  /// - [compact]/[fullscreen]/[showSuperRoot] : états initiaux des toggles.
  ZMindmapViewController({
    double initialScale = 1.0,
    double minScale = 0.25,
    double maxScale = 2.5,
    double zoomStep = 0.25,
    bool compact = false,
    bool fullscreen = false,
    bool showSuperRoot = false,
  })  : assert(minScale > 0 && minScale <= maxScale,
            'minScale doit être > 0 et ≤ maxScale'),
        assert(zoomStep > 0, 'zoomStep doit être > 0'),
        _minScale = minScale,
        _maxScale = maxScale,
        _zoomStep = zoomStep,
        _initialScale = initialScale.clamp(minScale, maxScale),
        scale = ValueNotifier<double>(initialScale.clamp(minScale, maxScale)),
        compact = ValueNotifier<bool>(compact),
        fullscreen = ValueNotifier<bool>(fullscreen),
        showSuperRoot = ValueNotifier<bool>(showSuperRoot);

  final double _minScale;
  final double _maxScale;
  final double _zoomStep;
  final double _initialScale;

  /// Tranche « échelle de zoom courante » (toujours dans `[minScale, maxScale]`).
  final ValueNotifier<double> scale;

  /// Tranche « mode compact » (rendu condensé label-seul).
  final ValueNotifier<bool> compact;

  /// Tranche « plein-écran » (surface mindmap dédiée ; défaut off).
  final ValueNotifier<bool> fullscreen;

  /// Tranche « super-racine multi-forêt affichée » (opt-in, réutilise le
  /// `usesVirtualRoot` du mapper de graphe — aucun 2e mécanisme).
  final ValueNotifier<bool> showSuperRoot;

  /// Borne inférieure de zoom (lecture pour l'UI / les tests).
  double get minScale => _minScale;

  /// Borne supérieure de zoom (lecture pour l'UI / les tests).
  double get maxScale => _maxScale;

  /// Zoom avant d'un pas, **clampé** à `maxScale` (AC2, garde INJ-1).
  void zoomIn() => scale.value = _clampScale(scale.value + _zoomStep);

  /// Zoom arrière d'un pas, **clampé** à `minScale` (AC2, garde INJ-1).
  void zoomOut() => scale.value = _clampScale(scale.value - _zoomStep);

  /// Restaure l'échelle initiale (déjà bornée à la construction).
  void resetZoom() => scale.value = _initialScale;

  /// Fixe une échelle arbitraire, **clampée** aux bornes (AC2).
  void setScale(double value) => scale.value = _clampScale(value);

  /// Bascule le mode compact.
  void toggleCompact() => compact.value = !compact.value;

  /// Bascule le plein-écran.
  void toggleFullscreen() => fullscreen.value = !fullscreen.value;

  /// Bascule l'affichage de la super-racine multi-forêt.
  void toggleSuperRoot() => showSuperRoot.value = !showSuperRoot.value;

  /// 🔴 **LA GARDE DE BORNAGE DU ZOOM** (AC2/INJ-1). Toute mutation d'échelle
  /// passe par ici : l'échelle appliquée ne **dépasse jamais** `[min, max]`.
  /// La retirer (renvoyer `value` brut) laisse N zoom-in dépasser `maxScale`
  /// ⇒ test « échelle ≤ maxScale » ROUGE.
  double _clampScale(double value) => value.clamp(_minScale, _maxScale);

  /// Libère les `ValueNotifier` (cycle de vie porté par l'app hôte, AD-2).
  void dispose() {
    scale.dispose();
    compact.dispose();
    fullscreen.dispose();
    showSuperRoot.dispose();
  }
}

/// Bundle **immuable** de libellés a11y **externalisés** des contrôles de
/// `ZMindmapView` (AD-13/FR-26). Chaque champ a un **repli neutre non-nul** : la
/// vue ne code **aucune** chaîne d'action en dur ; l'app peut tout surcharger
/// (localisation) sans configuration obligatoire.
@immutable
class ZMindmapViewLabels {
  /// Construit un bundle de libellés. Toutes les valeurs ont un repli neutre.
  const ZMindmapViewLabels({
    this.zoomIn = 'Zoom avant',
    this.zoomOut = 'Zoom arrière',
    this.resetZoom = 'Réinitialiser le zoom',
    this.compact = 'Affichage compact',
    this.expand = 'Affichage détaillé',
    this.enterFullscreen = 'Plein écran',
    this.exitFullscreen = 'Quitter le plein écran',
    this.showSuperRoot = 'Afficher la racine commune',
    this.hideSuperRoot = 'Masquer la racine commune',
    this.superRootLabel = 'Toutes les cartes',
  });

  /// Libellé a11y du bouton « zoom avant ».
  final String zoomIn;

  /// Libellé a11y du bouton « zoom arrière ».
  final String zoomOut;

  /// Libellé a11y du bouton « réinitialiser le zoom ».
  final String resetZoom;

  /// Libellé a11y du bouton « activer l'affichage compact ».
  final String compact;

  /// Libellé a11y du bouton « revenir à l'affichage détaillé ».
  final String expand;

  /// Libellé a11y du bouton « entrer en plein écran ».
  final String enterFullscreen;

  /// Libellé a11y du bouton « quitter le plein écran ».
  final String exitFullscreen;

  /// Libellé a11y du bouton « afficher la super-racine ».
  final String showSuperRoot;

  /// Libellé a11y du bouton « masquer la super-racine ».
  final String hideSuperRoot;

  /// Étiquette affichée de la super-racine multi-forêt (nœud groupant).
  final String superRootLabel;
}
